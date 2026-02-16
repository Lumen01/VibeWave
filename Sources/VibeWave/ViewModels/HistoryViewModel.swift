import Foundation
import Combine
import GRDB

// MARK: - Tokens Chart Type
public enum TokensChartType: String, CaseIterable {
    case input = "Input"
    case output = "Output"
}

public enum ActivityChartType: String, CaseIterable {
    case sessions = "会话"
    case messages = "消息"
}

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public var selectedTimeRange: HistoryTimeRangeOption = .last24Hours {
        didSet {
            guard selectedTimeRange != oldValue else { return }
            loadInputTokensHistory()
        }
    }

    @Published public var tokensChartType: TokensChartType = .input
    @Published public var activityChartType: ActivityChartType = .sessions

    @Published public var inputTokensChartMode: ChartDisplayMode {
        didSet {
            guard inputTokensChartMode != oldValue else { return }
            UserDefaults.standard.set(inputTokensChartMode.rawValue, forKey: Self.inputTokensChartModeKey)
        }
    }

    @Published public var outputReasoningChartMode: ChartDisplayMode {
        didSet {
            guard outputReasoningChartMode != oldValue else { return }
            UserDefaults.standard.set(outputReasoningChartMode.rawValue, forKey: Self.outputReasoningChartModeKey)
        }
    }

    @Published public var costChartMode: ChartDisplayMode {
        didSet {
            guard costChartMode != oldValue else { return }
            UserDefaults.standard.set(costChartMode.rawValue, forKey: Self.costChartModeKey)
        }
    }

    @Published public var sessionsChartMode: ChartDisplayMode {
        didSet {
            guard sessionsChartMode != oldValue else { return }
            UserDefaults.standard.set(sessionsChartMode.rawValue, forKey: Self.sessionsChartModeKey)
        }
    }

    @Published public var messagesChartMode: ChartDisplayMode {
        didSet {
            guard messagesChartMode != oldValue else { return }
            UserDefaults.standard.set(messagesChartMode.rawValue, forKey: Self.messagesChartModeKey)
        }
    }

    @Published public var usageSectionChartMode: ChartDisplayMode {
        didSet {
            guard usageSectionChartMode != oldValue else { return }
            UserDefaults.standard.set(usageSectionChartMode.rawValue, forKey: Self.usageSectionChartModeKey)
        }
    }

    @Published public var activitySectionChartMode: ChartDisplayMode {
        didSet {
            guard activitySectionChartMode != oldValue else { return }
            UserDefaults.standard.set(activitySectionChartMode.rawValue, forKey: Self.activitySectionChartModeKey)
        }
    }

    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var inputTokensData: [InputTokensDataPoint] = []
    @Published public var outputReasoningData: [OutputReasoningDataPoint] = []
    @Published public var costData: [SingleMetricDataPoint] = []
    @Published public var sessionsData: [SingleMetricDataPoint] = []
    @Published public var messagesData: [SingleMetricDataPoint] = []
    @Published public var trendInputHistoryData: [SingleMetricDataPoint] = []
    @Published public var trendInputDeltaData: [SingleMetricDataPoint] = []
    @Published public var trendDurationHistoryData: [SingleMetricDataPoint] = []
    @Published public var trendDurationDeltaData: [SingleMetricDataPoint] = []
    @Published public var trendInputAvgPerDay: Double = 0
    @Published public var trendDurationAvgPerDayHours: Double = 0

    private let repository: StatisticsRepository
    private var cancellables = Set<AnyCancellable>()
    private var latestLoadRequestID: UUID?
    private var hasLoadedOnce: Bool = false
    private var isVisible: Bool = false
    private var needsRefreshOnNextAppear: Bool = false

    private static let inputTokensChartModeKey = "history.inputTokens.chartMode"
    private static let outputReasoningChartModeKey = "history.outputReasoning.chartMode"
    private static let costChartModeKey = "history.cost.chartMode"
    private static let sessionsChartModeKey = "history.sessions.chartMode"
    private static let messagesChartModeKey = "history.messages.chartMode"
    private static let usageSectionChartModeKey = "history.usageSection.chartMode"
    private static let activitySectionChartModeKey = "history.activitySection.chartMode"

    public init(dbPool: DatabasePool) {
        self.repository = StatisticsRepository(dbPool: dbPool)
        if let savedModeRaw = UserDefaults.standard.string(forKey: Self.inputTokensChartModeKey),
           let savedMode = ChartDisplayMode(rawValue: savedModeRaw) {
            self.inputTokensChartMode = savedMode
        } else {
            self.inputTokensChartMode = .bar
        }

        if let savedModeRaw = UserDefaults.standard.string(forKey: Self.outputReasoningChartModeKey),
           let savedMode = ChartDisplayMode(rawValue: savedModeRaw) {
            self.outputReasoningChartMode = savedMode
        } else {
            self.outputReasoningChartMode = .bar
        }

        if let savedModeRaw = UserDefaults.standard.string(forKey: Self.costChartModeKey),
           let savedMode = ChartDisplayMode(rawValue: savedModeRaw) {
            self.costChartMode = savedMode
        } else {
            self.costChartMode = .bar
        }

        if let savedModeRaw = UserDefaults.standard.string(forKey: Self.sessionsChartModeKey),
           let savedMode = ChartDisplayMode(rawValue: savedModeRaw) {
            self.sessionsChartMode = savedMode
        } else {
            self.sessionsChartMode = .bar
        }

        if let savedModeRaw = UserDefaults.standard.string(forKey: Self.messagesChartModeKey),
           let savedMode = ChartDisplayMode(rawValue: savedModeRaw) {
            self.messagesChartMode = savedMode
        } else {
            self.messagesChartMode = .bar
        }

        self.usageSectionChartMode = Self.loadChartMode(
            primaryKey: Self.usageSectionChartModeKey,
            fallbackKey: Self.inputTokensChartModeKey
        )
        self.activitySectionChartMode = Self.loadChartMode(
            primaryKey: Self.activitySectionChartModeKey,
            fallbackKey: Self.sessionsChartModeKey
        )
        NotificationCenter.default
            .publisher(for: .appDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.isVisible {
                    self.loadInputTokensHistory()
                } else {
                    self.needsRefreshOnNextAppear = true
                }
            }
            .store(in: &cancellables)
    }

    public func loadInputTokensHistory() {
        hasLoadedOnce = true
        isLoading = true
        errorMessage = nil

        let requestID = UUID()
        latestLoadRequestID = requestID
        let selectedTimeRange = self.selectedTimeRange
        let service = HistoryDataService(repository: repository)

        DispatchQueue.global(qos: .userInitiated).async {
            let inputResult: [InputTokensDataPoint]
            let outputReasoningResult: [OutputReasoningDataPoint]
            let costResult: [SingleMetricDataPoint]
            let sessionsResult: [SingleMetricDataPoint]
            let messagesResult: [SingleMetricDataPoint]
            let durationResult: [SingleMetricDataPoint]
            switch selectedTimeRange {
            case .last24Hours:
                inputResult = service.getHourlyInputTokensFromAggregatedTable()
                outputReasoningResult = service.getHourlyOutputReasoningFromAggregatedTable()
                costResult = service.getHourlyCostFromAggregatedTable()
                sessionsResult = service.getHourlySessionsFromAggregatedTable()
                messagesResult = service.getHourlyMessagesFromAggregatedTable()
                durationResult = service.getHourlyMessageDurationHoursFromAggregatedTable()
            case .last30Days:
                inputResult = service.getDailyInputTokensFromAggregatedTable()
                outputReasoningResult = service.getDailyOutputReasoningFromAggregatedTable()
                costResult = service.getDailyCostFromAggregatedTable()
                sessionsResult = service.getDailySessionsFromAggregatedTable()
                messagesResult = service.getDailyMessagesFromAggregatedTable()
                durationResult = service.getDailyMessageDurationHoursFromAggregatedTable()
            case .allTime:
                inputResult = service.getAllTimeInputTokensFromAggregatedTable()
                outputReasoningResult = service.getAllTimeOutputReasoningFromAggregatedTable()
                costResult = service.getAllTimeCostFromAggregatedTable()
                sessionsResult = service.getAllTimeSessionsFromAggregatedTable()
                messagesResult = service.getAllTimeMessagesFromAggregatedTable()
                durationResult = service.getAllTimeMessageDurationHoursFromAggregatedTable()
            }

            let trendInputDelta = Self.makeInputTrendDelta(from: inputResult)
            let trendInputHistory = TrendDeltaChartMath.cumulativeSeries(from: trendInputDelta)
            let trendDurationDelta = durationResult
            let trendDurationHistory = TrendDeltaChartMath.cumulativeSeries(from: trendDurationDelta)
            let trendInputTotal = trendInputHistory.last?.value ?? 0
            let trendDurationTotal = trendDurationHistory.last?.value ?? 0
            var localCalendar = Calendar.autoupdatingCurrent
            localCalendar.timeZone = .autoupdatingCurrent
            let trendInputAvg = TrendDeltaChartMath.averagePerDay(
                total: trendInputTotal,
                startBucketStart: trendInputHistory.first?.bucketStart,
                endBucketStart: trendInputHistory.last?.bucketStart,
                calendar: localCalendar
            )
            let trendDurationAvg = TrendDeltaChartMath.averagePerDay(
                total: trendDurationTotal,
                startBucketStart: trendDurationHistory.first?.bucketStart,
                endBucketStart: trendDurationHistory.last?.bucketStart,
                calendar: localCalendar
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.latestLoadRequestID == requestID else { return }
                self.inputTokensData = inputResult
                self.outputReasoningData = outputReasoningResult
                self.costData = costResult
                self.sessionsData = sessionsResult
                self.messagesData = messagesResult
                self.trendInputHistoryData = trendInputHistory
                self.trendInputDeltaData = trendInputDelta
                self.trendDurationHistoryData = trendDurationHistory
                self.trendDurationDeltaData = trendDurationDelta
                self.trendInputAvgPerDay = trendInputAvg
                self.trendDurationAvgPerDayHours = trendDurationAvg
                self.isLoading = false
            }
        }
    }

    public func loadIfNeeded() {
        guard !hasLoadedOnce else { return }
        loadInputTokensHistory()
    }

    public func setVisible(_ visible: Bool) {
        isVisible = visible
        if visible, needsRefreshOnNextAppear {
            needsRefreshOnNextAppear = false
            loadInputTokensHistory()
        }
    }

    private static func loadChartMode(primaryKey: String, fallbackKey: String) -> ChartDisplayMode {
        if let savedModeRaw = UserDefaults.standard.string(forKey: primaryKey),
           let savedMode = ChartDisplayMode(rawValue: savedModeRaw) {
            return savedMode
        }

        if let fallbackModeRaw = UserDefaults.standard.string(forKey: fallbackKey),
           let fallbackMode = ChartDisplayMode(rawValue: fallbackModeRaw) {
            return fallbackMode
        }

        return .bar
    }

    nonisolated private static func makeInputTrendDelta(from points: [InputTokensDataPoint]) -> [SingleMetricDataPoint] {
        points.map { point in
            SingleMetricDataPoint(
                timestamp: point.timestamp,
                label: point.label,
                value: Double(point.totalTokens),
                bucketIndex: point.bucketIndex,
                hasData: point.hasData,
                bucketStart: point.bucketStart
            )
        }
    }
}
