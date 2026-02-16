import Foundation
import GRDB
import Combine

public final class OverviewViewModel: ObservableObject {
    public static let shared = OverviewViewModel(dbPool: DatabaseRepository.shared.dbPool())

    @Published public var stats: StatisticsRepository.OverviewStats?
    @Published public var previousStats: StatisticsRepository.OverviewStats?
    @Published public var isLoading: Bool = false
    @Published public var isRefreshing: Bool = false
    @Published public var errorMessage: String?
    @Published public var showErrorAlert: Bool = false
    @Published public var selectedTimeRange: TimeRangeOption = .today
    @Published public var isSyncing: Bool = false

    @Published public var sessionDepthDistribution: (shallow: Int, medium: Int, deep: Int) = (0, 0, 0)
    @Published public var topProjects: [StatisticsRepository.ProjectStats] = []
    @Published public var topModels: [StatisticsRepository.ModelStats] = []
    @Published public var codeOutputStats: (totalAdditions: Int, totalDeletions: Int, fileCount: Int) = (0, 0, 0)
    @Published public var kpiTrends: StatisticsRepository.OverviewKPITrends = .empty(days: 7)

    private let statisticsRepository: StatisticsRepository
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedOnce: Bool = false
    private var isVisible: Bool = false
    private var needsRefreshOnNextAppear: Bool = false

    // SyncCoordinator singleton - added for consistency with previous pattern
    private let syncCoordinator = SyncCoordinator.shared

    public enum TimeRangeOption: String, CaseIterable {
        case today = "Today"
        case last30Days = "30Days"
        case allTime = "AllTime"

        public var displayName: String {
            switch self {
            case .today: return L10n.timeToday
            case .last30Days: return L10n.time30days
            case .allTime: return L10n.timeAllTime
            }
        }
    }

    private let dbPool: DatabasePool

    private init(dbPool: DatabasePool) {
        self.dbPool = dbPool
        self.statisticsRepository = StatisticsRepository(dbPool: dbPool)

        // Load stats immediately on first creation.
        loadIfNeeded()
        setupNotificationObserver()
        setupSyncStateBinding()
    }

    public func loadStats() {
        hasLoadedOnce = true
        previousStats = stats

        isRefreshing = true
        errorMessage = nil
        showErrorAlert = false

        let timeRange: StatisticsRepository.TimeRange
        switch selectedTimeRange {
        case .today:
            timeRange = .today
        case .last30Days:
            timeRange = .last30Days
        case .allTime:
            timeRange = .allTime
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let newStats = self.statisticsRepository.getOverviewStats(timeRange: timeRange)
            let newKPITrends = self.statisticsRepository.getOverviewKPITrends(lastNDays: 7)

            DispatchQueue.main.async {
                self.stats = newStats
                self.kpiTrends = newKPITrends
                self.isRefreshing = false
                self.loadExtendedStats()
            }
        }
    }

    public func loadExtendedStats() {
        let timeRange: StatisticsRepository.TimeRange
        switch selectedTimeRange {
        case .today:
            timeRange = .today
        case .last30Days:
            timeRange = .last30Days
        case .allTime:
            timeRange = .allTime
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 注意：sessions表现在由增量同步服务自动维护
            // 不需要每次查询前调用createSessionsFromMessages()
            // 这消除了200-400ms的阻塞

            let depthDistribution = self.statisticsRepository.getSessionDepthDistribution(timeRange: timeRange)
            let projects = self.statisticsRepository.getTopProjects(timeRange: timeRange, limit: 5)
            let models = self.statisticsRepository.getTopModels(timeRange: timeRange, limit: 5)
            let codeStats = self.statisticsRepository.getCodeOutputStats(timeRange: timeRange)

            DispatchQueue.main.async {
                self.sessionDepthDistribution = depthDistribution
                self.topProjects = projects
                self.topModels = models
                self.codeOutputStats = codeStats
            }
        }
    }

    public func manualRefresh() {
        // 只刷新界面显示，从DB读取最新数据
        // 不触发任何数据同步操作
        loadStats()
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

    private func setupNotificationObserver() {
        // 监听同步完成/数据更新
        NotificationCenter.default.publisher(for: .appDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSyncCompleted()
            }
            .store(in: &cancellables)
    }

    private func handleSyncCompleted() {
        if isVisible {
            loadStats()
        } else {
            needsRefreshOnNextAppear = true
        }
    }

    private func setupSyncStateBinding() {
        syncCoordinator.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSyncing in
                self?.isRefreshing = isSyncing
            }
            .store(in: &cancellables)
    }
}
