import Foundation
import GRDB
import Combine

public final class ProjectsViewModel: ObservableObject {
  @Published public var projectStats: [ProjectStats] = []
  @Published public var selectedProject: ProjectStats?
  @Published public var projectActivity: StatisticsRepository.ProjectActivityStats?
  @Published public var projectConsumption: StatisticsRepository.ProjectConsumptionStats?
  @Published public var projectModelAgentStats: StatisticsRepository.ProjectModelAgentStats?
  @Published public var top3NetCodeLines: [StatisticsRepository.DailyTop3Stat] = []
  @Published public var top3InputTokens: [StatisticsRepository.DailyTop3Stat] = []
  @Published public var top3MessageCount: [StatisticsRepository.DailyTop3Stat] = []
  @Published public var top3Duration: [StatisticsRepository.DailyTop3Stat] = []
  @Published public var top3Cost: [StatisticsRepository.DailyTop3Stat] = []
  @Published public var isLoading: Bool = false
  @Published public var errorMessage: String?
  @Published public var selectedTimeRange: OverviewViewModel.TimeRangeOption = .today

  private let statisticsRepository: StatisticsRepository
  private let notificationCenter: NotificationCenter
  private var cancellables = Set<AnyCancellable>()
  private var hasLoadedOnce: Bool = false
  private var isVisible: Bool = false
  private var needsRefreshOnNextAppear: Bool = false
  
  public struct ProjectStats: Identifiable, Equatable {
    public let id = UUID()
    public let projectRoot: String
    public let sessionCount: Int
    public let messageCount: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheRead: Int
    public let cacheWrite: Int
    public let netCodeLines: Int
    public let fileCount: Int
    public let tokens: Int
    public let cost: Double
    public let activeDays: Int
    public let lastActiveAt: Date?

    public init(projectRoot: String, sessionCount: Int, messageCount: Int, inputTokens: Int, outputTokens: Int, cacheRead: Int, cacheWrite: Int, netCodeLines: Int, fileCount: Int, tokens: Int, cost: Double, activeDays: Int, lastActiveAt: Date?) {
      self.projectRoot = projectRoot
      self.sessionCount = sessionCount
      self.messageCount = messageCount
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
      self.cacheRead = cacheRead
      self.cacheWrite = cacheWrite
      self.netCodeLines = netCodeLines
      self.fileCount = fileCount
      self.tokens = tokens
      self.cost = cost
      self.activeDays = activeDays
      self.lastActiveAt = lastActiveAt
    }
    
    public static func == (lhs: ProjectStats, rhs: ProjectStats) -> Bool {
      lhs.id == rhs.id
    }
  }
  
  public init(dbPool: DatabasePool, notificationCenter: NotificationCenter = .default) {
    self.statisticsRepository = StatisticsRepository(dbPool: dbPool)
    self.notificationCenter = notificationCenter
    setupNotificationObserver()
  }
  
  private func setupNotificationObserver() {
    notificationCenter.publisher(for: .appDataDidUpdate)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self else { return }
        if self.isVisible {
          self.loadStats()
        } else {
          self.needsRefreshOnNextAppear = true
        }
      }
      .store(in: &cancellables)
  }
  
  public func loadStats() {
    hasLoadedOnce = true
    errorMessage = nil
    
    DispatchQueue.global(qos: .userInitiated).async {[weak self] in
      guard let self = self else { return }
      
      let stats = self.statisticsRepository.getProjectStatsFromMonthly()
      
      let projectStats = stats.map { s in
        ProjectStats(
          projectRoot: s.projectRoot,
          sessionCount: s.sessionCount,
          messageCount: s.messageCount,
          inputTokens: s.inputTokens,
          outputTokens: s.outputTokens,
          cacheRead: s.cacheRead,
          cacheWrite: s.cacheWrite,
          netCodeLines: s.netCodeLines,
          fileCount: s.fileCount,
          tokens: s.tokens,
          cost: s.cost,
          activeDays: s.activeDays,
          lastActiveAt: s.lastActiveAt
        )
      }
      
      DispatchQueue.main.async {
        self.projectStats = projectStats

        if let selected = self.selectedProject {
          self.loadProjectActivity(projectRoot: selected.projectRoot)
        }
      }
    }
  }

  public func loadIfNeeded() {
    guard !hasLoadedOnce else { return }
    loadStats()
  }

  public func setVisible(_ visible: Bool) {
    isVisible = visible
    if visible, needsRefreshOnNextAppear {
      needsRefreshOnNextAppear = false
      loadStats()
    }
  }

  public func selectProject(_ project: ProjectStats) {
    selectedProject = project
    loadProjectActivity(projectRoot: project.projectRoot)
  }
  
  public var top3AllStats: [[StatisticsRepository.DailyTop3Stat]] {
    return [
      top3NetCodeLines,
      top3InputTokens,
      top3MessageCount,
      top3Duration,
      top3Cost
    ]
  }

  private func loadProjectActivity(projectRoot: String) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }

      let activity = self.statisticsRepository.getProjectActivityStats(projectRoot: projectRoot)
      let consumption = self.statisticsRepository.getProjectConsumptionStats(projectRoot: projectRoot)
      let modelAgentStats = self.statisticsRepository.getProjectModelAgentStats(projectRoot: projectRoot)
      let netCodeLines = self.statisticsRepository.getDailyTop3Stats(projectRoot: projectRoot, orderBy: "net_code_lines")
      let inputTokens = self.statisticsRepository.getDailyTop3Stats(projectRoot: projectRoot, orderBy: "input_tokens")
      let messageCount = self.statisticsRepository.getDailyTop3Stats(projectRoot: projectRoot, orderBy: "message_count")
      let duration = self.statisticsRepository.getDailyTop3Stats(projectRoot: projectRoot, orderBy: "duration_ms")
      let cost = self.statisticsRepository.getDailyTop3Stats(projectRoot: projectRoot, orderBy: "cost")

      DispatchQueue.main.async {
        self.projectActivity = activity
        self.projectConsumption = consumption
        self.projectModelAgentStats = modelAgentStats
        self.top3NetCodeLines = netCodeLines
        self.top3InputTokens = inputTokens
        self.top3MessageCount = messageCount
        self.top3Duration = duration
        self.top3Cost = cost
      }
    }
  }
}
