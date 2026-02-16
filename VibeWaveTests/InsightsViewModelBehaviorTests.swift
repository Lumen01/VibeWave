import XCTest
import GRDB
import Combine
@testable import VibeWave

@MainActor
final class InsightsViewModelBehaviorTests: XCTestCase {
    private final class DelayedInsightsRepository: StatisticsRepositoryProtocol {
        private let lock = NSLock()

        private var heatmapByMetric: [InsightMetric: [DailyHeatPoint]]
        private var lensRowsByGroup: [ModelLensGroupBy: [ModelLensRow]]
        private var delayByHeatmapMetric: [InsightMetric: TimeInterval]
        private var delayByLensGroup: [ModelLensGroupBy: TimeInterval]

        init(
            heatmapByMetric: [InsightMetric: [DailyHeatPoint]],
            lensRowsByGroup: [ModelLensGroupBy: [ModelLensRow]],
            delayByHeatmapMetric: [InsightMetric: TimeInterval] = [:],
            delayByLensGroup: [ModelLensGroupBy: TimeInterval] = [:]
        ) {
            self.heatmapByMetric = heatmapByMetric
            self.lensRowsByGroup = lensRowsByGroup
            self.delayByHeatmapMetric = delayByHeatmapMetric
            self.delayByLensGroup = delayByLensGroup
        }

        func getHourlyBreakdown(timeRange: StatisticsRepository.TimeRange, metric: MetricType) -> [StatisticsRepository.HourlyStat] { [] }
        func getTimeClusterStats(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.TimeClusterStat] { [] }
        func getTokenDivergingData(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.TokenDivergingDataPoint] { [] }
        func getDualAxisData(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.DualAxisDataPoint] { [] }
        func getTrendData(timeRange: StatisticsRepository.TimeRange, metric: MetricType, granularity: TimeGranularity) -> [StatisticsRepository.TrendDataPoint] { [] }
        func getWeekdayVsWeekendStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.WeekdayWeekendStats {
            StatisticsRepository.WeekdayWeekendStats(weekdayAvg: 0, weekendAvg: 0, weekdayTotal: 0, weekendTotal: 0)
        }
        func getMonthlyStats(timeRange: StatisticsRepository.TimeRange, metric: MetricType) -> [StatisticsRepository.MonthlyStat] { [] }
        func getActiveStreakData(year: Int) -> [StatisticsRepository.DayActivity] { [] }
        func getUserAgentMessageCounts(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.UserAgentCount] { [] }
        func getUserAgentSessionCounts(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.UserAgentSessionCounts {
            StatisticsRepository.UserAgentSessionCounts(userSessions: 0, agentSessions: 0, totalSessions: 0)
        }
        func getAgentSessionDistribution(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.AgentSessionCount] { [] }
        func getNetCodeOutputStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.NetCodeOutputStats {
            StatisticsRepository.NetCodeOutputStats(additions: 0, deletions: 0, net: 0)
        }
        func getBillingCostStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.BillingCostStats {
            StatisticsRepository.BillingCostStats(totalCost: 0, billedMessageCount: 0, totalMessageCount: 0, coverageRatio: 0)
        }
        func getUserAgentMessageTrend(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.UserAgentTrendPoint] { [] }
        func getCodeOutputCostTrend(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.CodeOutputCostTrendPoint] { [] }
        func getModelProcessingStats(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.ModelProcessingStat] { [] }
        func getRhythmInsights(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.RhythmInsights {
            StatisticsRepository.RhythmInsights(peakHour: 0, peakHourMessageCount: 0, nightOwlMessageRatio: 0, nightOwlSessionRatio: 0, weekendMessageRatio: 0, weekendSessionRatio: 0)
        }
        func getAnomalyStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.AnomalyStats {
            StatisticsRepository.AnomalyStats(
                message: StatisticsRepository.AnomalyMetric(current: 0, mean: 0, stdDev: 0),
                session: StatisticsRepository.AnomalyMetric(current: 0, mean: 0, stdDev: 0),
                cost: StatisticsRepository.AnomalyMetric(current: 0, mean: 0, stdDev: 0),
                netOutput: StatisticsRepository.AnomalyMetric(current: 0, mean: 0, stdDev: 0)
            )
        }
        func getInputTokensByProject(timeRange: StatisticsRepository.TimeRange, topN: Int) -> [SegmentedBarDataPoint] { [] }
        func getInputTokensByModel(timeRange: StatisticsRepository.TimeRange, topN: Int) -> [SegmentedBarDataPoint] { [] }

        func getDailyActivityHeatmap(metric: InsightMetric, lastNDays: Int) -> [DailyHeatPoint] {
            lock.lock()
            let delay = delayByHeatmapMetric[metric] ?? 0
            let points = heatmapByMetric[metric] ?? []
            lock.unlock()
            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }
            return points
        }

        func getWeekdayWeekendIntensity(metric: InsightMetric, filter: DayTypeFilter) -> WeekdayWeekendIntensity {
            WeekdayWeekendIntensity(weekdayTotal: 0, weekendTotal: 0, weekdayAverage: 0, weekendAverage: 0)
        }

        func getHourlyIntensity(metric: InsightMetric, filter: DayTypeFilter) -> [HourlyIntensityPoint] { [] }

        func getModelLensRows(groupBy: ModelLensGroupBy) -> [ModelLensRow] {
            lock.lock()
            let delay = delayByLensGroup[groupBy] ?? 0
            let rows = lensRowsByGroup[groupBy] ?? []
            lock.unlock()
            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }
            return rows
        }
    }

    private final class CountingInsightsRepository: StatisticsRepositoryProtocol {
        private struct LensKey: Hashable {
            let groupBy: ModelLensGroupBy
        }

        private struct HeatmapKey: Hashable {
            let metric: InsightMetric
        }

        private struct WeekdayWeekendKey: Hashable {
            let metric: InsightMetric
        }

        private struct HourlyKey: Hashable {
            let metric: InsightMetric
            let filter: DayTypeFilter
        }

        private let lock = NSLock()
        private var lensCallCounts: [LensKey: Int] = [:]
        private var heatmapCallCounts: [HeatmapKey: Int] = [:]
        private var heatmapBundleCallCount: Int = 0
        private var weekdayWeekendCallCounts: [WeekdayWeekendKey: Int] = [:]
        private var hourlyCallCounts: [HourlyKey: Int] = [:]
        private let lensData: [LensKey: [ModelLensRow]]
        private let heatmapBundleData: [InsightMetric: [DailyHeatPoint]]

        init(
            modelRows: [ModelLensRow] = [
                ModelLensRow(
                    dimensionName: "model-row",
                    providerId: "provider-a",
                    inputTokens: 1000,
                    outputTPS: 200,
                    outputTokens: 400,
                    durationSeconds: 2,
                    validDurationMessageRatio: 1
                )
            ],
            providerRows: [ModelLensRow] = [
                ModelLensRow(
                    dimensionName: "provider-row",
                    providerId: "",
                    inputTokens: 3000,
                    outputTPS: 400,
                    outputTokens: 800,
                    durationSeconds: 2,
                    validDurationMessageRatio: 1
                )
            ],
            heatmapBundleData: [InsightMetric: [DailyHeatPoint]] = [
                .inputTokens: [],
                .messages: [],
                .cost: []
            ]
        ) {
            self.lensData = [
                LensKey(groupBy: .model): modelRows,
                LensKey(groupBy: .provider): providerRows
            ]
            self.heatmapBundleData = heatmapBundleData
        }

        func callCount(groupBy: ModelLensGroupBy) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return lensCallCounts[LensKey(groupBy: groupBy), default: 0]
        }

        func callCount(metric: InsightMetric) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return heatmapCallCounts[HeatmapKey(metric: metric), default: 0]
        }

        func heatmapBundleCallCountValue() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return heatmapBundleCallCount
        }

        func weekdayWeekendCallCount(metric: InsightMetric) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return weekdayWeekendCallCounts[WeekdayWeekendKey(metric: metric), default: 0]
        }

        func hourlyCallCount(metric: InsightMetric, filter: DayTypeFilter) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return hourlyCallCounts[HourlyKey(metric: metric, filter: filter), default: 0]
        }

        func getHourlyBreakdown(timeRange: StatisticsRepository.TimeRange, metric: MetricType) -> [StatisticsRepository.HourlyStat] { [] }
        func getTimeClusterStats(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.TimeClusterStat] { [] }
        func getTokenDivergingData(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.TokenDivergingDataPoint] { [] }
        func getDualAxisData(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.DualAxisDataPoint] { [] }
        func getTrendData(timeRange: StatisticsRepository.TimeRange, metric: MetricType, granularity: TimeGranularity) -> [StatisticsRepository.TrendDataPoint] { [] }
        func getWeekdayVsWeekendStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.WeekdayWeekendStats {
            StatisticsRepository.WeekdayWeekendStats(weekdayAvg: 0, weekendAvg: 0, weekdayTotal: 0, weekendTotal: 0)
        }
        func getMonthlyStats(timeRange: StatisticsRepository.TimeRange, metric: MetricType) -> [StatisticsRepository.MonthlyStat] { [] }
        func getActiveStreakData(year: Int) -> [StatisticsRepository.DayActivity] { [] }
        func getUserAgentMessageCounts(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.UserAgentCount] { [] }
        func getUserAgentSessionCounts(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.UserAgentSessionCounts {
            StatisticsRepository.UserAgentSessionCounts(userSessions: 0, agentSessions: 0, totalSessions: 0)
        }
        func getAgentSessionDistribution(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.AgentSessionCount] { [] }
        func getNetCodeOutputStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.NetCodeOutputStats {
            StatisticsRepository.NetCodeOutputStats(additions: 0, deletions: 0, net: 0)
        }
        func getBillingCostStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.BillingCostStats {
            StatisticsRepository.BillingCostStats(totalCost: 0, billedMessageCount: 0, totalMessageCount: 0, coverageRatio: 0)
        }
        func getUserAgentMessageTrend(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.UserAgentTrendPoint] { [] }
        func getCodeOutputCostTrend(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.CodeOutputCostTrendPoint] { [] }
        func getModelProcessingStats(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.ModelProcessingStat] { [] }
        func getRhythmInsights(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.RhythmInsights {
            StatisticsRepository.RhythmInsights(peakHour: 0, peakHourMessageCount: 0, nightOwlMessageRatio: 0, nightOwlSessionRatio: 0, weekendMessageRatio: 0, weekendSessionRatio: 0)
        }
        func getAnomalyStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.AnomalyStats {
            StatisticsRepository.AnomalyStats(
                message: StatisticsRepository.AnomalyMetric(current: 0, mean: 0, stdDev: 0),
                session: StatisticsRepository.AnomalyMetric(current: 0, mean: 0, stdDev: 0),
                cost: StatisticsRepository.AnomalyMetric(current: 0, mean: 0, stdDev: 0),
                netOutput: StatisticsRepository.AnomalyMetric(current: 0, mean: 0, stdDev: 0)
            )
        }
        func getInputTokensByProject(timeRange: StatisticsRepository.TimeRange, topN: Int) -> [SegmentedBarDataPoint] { [] }
        func getInputTokensByModel(timeRange: StatisticsRepository.TimeRange, topN: Int) -> [SegmentedBarDataPoint] { [] }
        func getDailyActivityHeatmap(metric: InsightMetric, lastNDays: Int) -> [DailyHeatPoint] {
            lock.lock()
            heatmapCallCounts[HeatmapKey(metric: metric), default: 0] += 1
            lock.unlock()
            return []
        }

        func getDailyActivityHeatmapBundle(lastNDays: Int) -> [InsightMetric: [DailyHeatPoint]] {
            lock.lock()
            heatmapBundleCallCount += 1
            lock.unlock()
            return heatmapBundleData
        }

        func getWeekdayWeekendIntensity(metric: InsightMetric, filter: DayTypeFilter) -> WeekdayWeekendIntensity {
            lock.lock()
            weekdayWeekendCallCounts[WeekdayWeekendKey(metric: metric), default: 0] += 1
            lock.unlock()
            return WeekdayWeekendIntensity(weekdayTotal: 0, weekendTotal: 0, weekdayAverage: 0, weekendAverage: 0)
        }
        func getHourlyIntensity(metric: InsightMetric, filter: DayTypeFilter) -> [HourlyIntensityPoint] {
            lock.lock()
            hourlyCallCounts[HourlyKey(metric: metric, filter: filter), default: 0] += 1
            lock.unlock()
            return []
        }

        func getModelLensRows(groupBy: ModelLensGroupBy) -> [ModelLensRow] {
            let key = LensKey(groupBy: groupBy)
            lock.lock()
            lensCallCounts[key, default: 0] += 1
            lock.unlock()
            return lensData[key, default: []]
        }
    }

    private var dbPool: DatabasePool!
    private var tempDBPath: String!
    private var viewModel: InsightsViewModel!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBFile = tempDir.appendingPathComponent("test_insights_vm-\(UUID().uuidString).db")
        tempDBPath = tempDBFile.path
        dbPool = try! DatabasePool(path: tempDBPath)
        try! MessageRepository(dbPool: dbPool).createSchemaIfNeeded()
        seedMessages()
        viewModel = InsightsViewModel(dbPool: dbPool)
    }

    override func tearDown() {
        cancellables.removeAll()
        viewModel = nil
        try? dbPool.close()
        dbPool = nil
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempDBPath = nil
        super.tearDown()
    }

    func testDayTypeFilter_OnlyAffectsHourlyIntensity() {
        viewModel.intensityMetric = .messages
        viewModel.dayTypeFilter = .all
        waitForLoadCompletion { self.viewModel.load() }

        let allStats = viewModel.weekdayWeekendIntensity
        let hour10All = viewModel.hourlyIntensity.first(where: { $0.hour == 10 })?.value ?? 0

        waitForLoadCompletion { self.viewModel.dayTypeFilter = .weekdays }

        let weekdayStats = viewModel.weekdayWeekendIntensity
        let hour10Weekdays = viewModel.hourlyIntensity.first(where: { $0.hour == 10 })?.value ?? 0

        XCTAssertEqual(allStats.weekdayTotal, weekdayStats.weekdayTotal, accuracy: 0.0001)
        XCTAssertEqual(allStats.weekendTotal, weekdayStats.weekendTotal, accuracy: 0.0001)
        XCTAssertEqual(hour10All, 2, accuracy: 0.0001)
        XCTAssertEqual(hour10Weekdays, 1, accuracy: 0.0001)
    }

    func testModelLensSwitch_BackToVisitedCombination_UsesCache() {
        let fakeRepository = CountingInsightsRepository()
        let notificationCenter = NotificationCenter()
        let vm = InsightsViewModel(statisticsRepository: fakeRepository, notificationCenter: notificationCenter)

        waitForLoadCompletion(of: vm) { vm.load() }
        XCTAssertEqual(fakeRepository.callCount(groupBy: .model), 1)
        XCTAssertEqual(vm.modelLensPoints.first?.dimensionName, "model-row")
        XCTAssertEqual(vm.modelLensPoints.first?.value ?? 0, 1000, accuracy: 0.0001)

        waitForLoadCompletion(of: vm) { vm.modelLensMetric = .outputTPS }
        XCTAssertEqual(fakeRepository.callCount(groupBy: .model), 1)
        XCTAssertEqual(vm.modelLensPoints.first?.dimensionName, "model-row")
        XCTAssertEqual(vm.modelLensPoints.first?.value ?? 0, 200, accuracy: 0.0001)

        let inputCallCountBeforeSwitchBack = fakeRepository.callCount(groupBy: .model)
        vm.modelLensMetric = .inputTokens
        let settleExpectation = expectation(description: "Model lens switch settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            settleExpectation.fulfill()
        }
        wait(for: [settleExpectation], timeout: 1.0)
        XCTAssertEqual(vm.modelLensPoints.first?.dimensionName, "model-row")
        XCTAssertEqual(vm.modelLensPoints.first?.value ?? 0, 1000, accuracy: 0.0001)
        XCTAssertEqual(
            fakeRepository.callCount(groupBy: .model),
            inputCallCountBeforeSwitchBack
        )
    }

    func testModelLensSort_UpdatesDisplayedRowsWithoutReload() {
        let fakeRepository = CountingInsightsRepository(
            modelRows: [
                ModelLensRow(
                    dimensionName: "alpha-model",
                    providerId: "provider-a",
                    inputTokens: 400,
                    outputTPS: 20
                ),
                ModelLensRow(
                    dimensionName: "beta-model",
                    providerId: "provider-b",
                    inputTokens: 200,
                    outputTPS: 120
                )
            ]
        )
        let vm = InsightsViewModel(statisticsRepository: fakeRepository, notificationCenter: NotificationCenter())

        waitForLoadCompletion(of: vm) { vm.loadIfNeeded() }
        XCTAssertEqual(fakeRepository.callCount(groupBy: .model), 1)
        XCTAssertEqual(vm.displayedModelLensRows.first?.dimensionName, "alpha-model")

        vm.modelLensSortKey = .outputTPS
        waitForSettling(seconds: 0.1)
        XCTAssertEqual(vm.displayedModelLensRows.first?.dimensionName, "beta-model")
        XCTAssertEqual(fakeRepository.callCount(groupBy: .model), 1)

        vm.modelLensSortDirection = .ascending
        waitForSettling(seconds: 0.1)
        XCTAssertEqual(vm.displayedModelLensRows.first?.dimensionName, "alpha-model")
        XCTAssertEqual(fakeRepository.callCount(groupBy: .model), 1)
    }

    func testHeatmapRenderModel_WidthBucketCachesNearbyWidths() {
        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let dayMs = Int64(now.timeIntervalSince1970 * 1000)
        let fakeRepository = CountingInsightsRepository(
            heatmapBundleData: [
                .inputTokens: [DailyHeatPoint(date: now, dayStartMs: dayMs, value: 100)],
                .messages: [],
                .cost: []
            ]
        )
        let vm = InsightsViewModel(statisticsRepository: fakeRepository, notificationCenter: NotificationCenter())

        waitForLoadCompletion(of: vm) { vm.loadIfNeeded() }

        vm.updateHeatmapContainerWidth(360)
        let firstRender = vm.heatmapRenderModel

        vm.updateHeatmapContainerWidth(364)
        let secondRender = vm.heatmapRenderModel
        XCTAssertEqual(secondRender, firstRender)

        vm.updateHeatmapContainerWidth(388)
        let thirdRender = vm.heatmapRenderModel
        XCTAssertGreaterThan(thirdRender.availableGridWidth, firstRender.availableGridWidth)
        XCTAssertNotEqual(thirdRender.scaledMetrics.cellSize, firstRender.scaledMetrics.cellSize)
    }

    func testLoadIfNeeded_SecondCallDoesNotReload() {
        let fakeRepository = CountingInsightsRepository()
        let notificationCenter = NotificationCenter()
        let vm = InsightsViewModel(statisticsRepository: fakeRepository, notificationCenter: notificationCenter)

        waitForLoadCompletion(of: vm) { vm.loadIfNeeded() }
        waitForSettling()

        let heatmapBefore = fakeRepository.callCount(metric: .inputTokens)
        let weekdayWeekendBefore = fakeRepository.weekdayWeekendCallCount(metric: .inputTokens)
        let hourlyBefore = fakeRepository.hourlyCallCount(metric: .inputTokens, filter: .all)
        let modelLensBefore = fakeRepository.callCount(groupBy: .model)

        vm.loadIfNeeded()
        waitForSettling()

        XCTAssertEqual(fakeRepository.callCount(metric: .inputTokens), heatmapBefore)
        XCTAssertEqual(fakeRepository.weekdayWeekendCallCount(metric: .inputTokens), weekdayWeekendBefore)
        XCTAssertEqual(fakeRepository.hourlyCallCount(metric: .inputTokens, filter: .all), hourlyBefore)
        XCTAssertEqual(fakeRepository.callCount(groupBy: .model), modelLensBefore)
    }

    func testUserRhythmMetricSwitch_UsesDailyBundleCacheWithoutReload() {
        let fakeRepository = CountingInsightsRepository()
        let notificationCenter = NotificationCenter()
        let vm = InsightsViewModel(statisticsRepository: fakeRepository, notificationCenter: notificationCenter)

        waitForLoadCompletion(of: vm) { vm.loadIfNeeded() }
        waitForSettling()
        XCTAssertEqual(fakeRepository.heatmapBundleCallCountValue(), 1)

        waitForLoadCompletion(of: vm) { vm.userRhythmMetric = .messages }
        waitForSettling()
        XCTAssertEqual(fakeRepository.heatmapBundleCallCountValue(), 1)

        waitForLoadCompletion(of: vm) { vm.userRhythmMetric = .cost }
        waitForSettling()
        XCTAssertEqual(fakeRepository.heatmapBundleCallCountValue(), 1)
    }

    func testInit_RestoresHeatmapFromPersistedCacheImmediately() {
        let suiteName = "InsightsViewModelBehaviorTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let dayMs = Int64(now.timeIntervalSince1970 * 1000)
        let bundle: [InsightMetric: [DailyHeatPoint]] = [
            .inputTokens: [DailyHeatPoint(date: now, dayStartMs: dayMs, value: 123)],
            .messages: [DailyHeatPoint(date: now, dayStartMs: dayMs, value: 45)],
            .cost: [DailyHeatPoint(date: now, dayStartMs: dayMs, value: 6.7)]
        ]

        let writerRepo = CountingInsightsRepository(heatmapBundleData: bundle)
        let writerVM = InsightsViewModel(
            statisticsRepository: writerRepo,
            notificationCenter: NotificationCenter(),
            userDefaults: defaults,
            nowProvider: { now }
        )
        waitForLoadCompletion(of: writerVM) { writerVM.loadIfNeeded() }
        XCTAssertEqual(writerRepo.heatmapBundleCallCountValue(), 1)

        let readerRepo = CountingInsightsRepository()
        let readerVM = InsightsViewModel(
            statisticsRepository: readerRepo,
            notificationCenter: NotificationCenter(),
            userDefaults: defaults,
            nowProvider: { now }
        )
        XCTAssertEqual(readerVM.heatmapPoints.first?.value ?? 0, 123, accuracy: 0.0001)
        XCTAssertEqual(readerRepo.heatmapBundleCallCountValue(), 0)
    }

    func testLoadIfNeeded_OnNextDayRefreshesPersistedHeatmap() {
        let suiteName = "InsightsViewModelBehaviorTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let day1 = Date(timeIntervalSince1970: 1_770_000_000)
        let day1Ms = Int64(day1.timeIntervalSince1970 * 1000)
        let day2 = day1.addingTimeInterval(86_400)
        let day2Ms = Int64(day2.timeIntervalSince1970 * 1000)

        let day1Bundle: [InsightMetric: [DailyHeatPoint]] = [
            .inputTokens: [DailyHeatPoint(date: day1, dayStartMs: day1Ms, value: 111)],
            .messages: [],
            .cost: []
        ]
        let day2Bundle: [InsightMetric: [DailyHeatPoint]] = [
            .inputTokens: [DailyHeatPoint(date: day2, dayStartMs: day2Ms, value: 222)],
            .messages: [],
            .cost: []
        ]

        let day1Repo = CountingInsightsRepository(heatmapBundleData: day1Bundle)
        let day1VM = InsightsViewModel(
            statisticsRepository: day1Repo,
            notificationCenter: NotificationCenter(),
            userDefaults: defaults,
            nowProvider: { day1 }
        )
        waitForLoadCompletion(of: day1VM) { day1VM.loadIfNeeded() }

        let day2Repo = CountingInsightsRepository(heatmapBundleData: day2Bundle)
        let day2VM = InsightsViewModel(
            statisticsRepository: day2Repo,
            notificationCenter: NotificationCenter(),
            userDefaults: defaults,
            nowProvider: { day2 }
        )

        XCTAssertEqual(day2VM.heatmapPoints.first?.value ?? 0, 111, accuracy: 0.0001)
        waitForLoadCompletion(of: day2VM) { day2VM.loadIfNeeded() }
        XCTAssertEqual(day2Repo.heatmapBundleCallCountValue(), 1)
        XCTAssertEqual(day2VM.heatmapPoints.first?.value ?? 0, 222, accuracy: 0.0001)
    }

    func testAppDataDidUpdate_DoesNotTriggerInsightsReload() {
        let fakeRepository = CountingInsightsRepository()
        let notificationCenter = NotificationCenter()
        let vm = InsightsViewModel(statisticsRepository: fakeRepository, notificationCenter: notificationCenter)

        waitForLoadCompletion(of: vm) { vm.loadIfNeeded() }
        waitForSettling()

        let heatmapBefore = fakeRepository.callCount(metric: .inputTokens)
        let weekdayWeekendBefore = fakeRepository.weekdayWeekendCallCount(metric: .inputTokens)
        let hourlyBefore = fakeRepository.hourlyCallCount(metric: .inputTokens, filter: .all)
        let modelLensBefore = fakeRepository.callCount(groupBy: .model)

        notificationCenter.post(name: .appDataDidUpdate, object: nil)
        waitForSettling()

        XCTAssertEqual(fakeRepository.callCount(metric: .inputTokens), heatmapBefore)
        XCTAssertEqual(fakeRepository.weekdayWeekendCallCount(metric: .inputTokens), weekdayWeekendBefore)
        XCTAssertEqual(fakeRepository.hourlyCallCount(metric: .inputTokens, filter: .all), hourlyBefore)
        XCTAssertEqual(fakeRepository.callCount(groupBy: .model), modelLensBefore)
    }

    func testUserRhythmSwitch_DoesNotLagOneStepWhenTargetMetricWasPrewarming() {
        let now = Date()
        let dayMs = Int64(now.timeIntervalSince1970 * 1000)
        let repository = DelayedInsightsRepository(
            heatmapByMetric: [
                .inputTokens: [DailyHeatPoint(date: now, dayStartMs: dayMs, value: 111)],
                .messages: [DailyHeatPoint(date: now, dayStartMs: dayMs, value: 222)],
                .cost: [DailyHeatPoint(date: now, dayStartMs: dayMs, value: 333)]
            ],
            lensRowsByGroup: [:],
            delayByHeatmapMetric: [
                .messages: 0.25,
                .cost: 0.25
            ]
        )

        let vm = InsightsViewModel(statisticsRepository: repository, notificationCenter: NotificationCenter())
        waitForLoadCompletion(of: vm) { vm.loadIfNeeded() }

        vm.userRhythmMetric = .cost
        waitForSettling(seconds: 0.4)
        XCTAssertEqual(vm.heatmapPoints.first?.value ?? 0, 333, accuracy: 0.0001)

        vm.userRhythmMetric = .inputTokens
        waitForSettling(seconds: 0.2)
        XCTAssertEqual(vm.heatmapPoints.first?.value ?? 0, 111, accuracy: 0.0001)
    }

    func testModelLensSwitch_GroupByProviderUsesProviderDataImmediately() {
        let repository = DelayedInsightsRepository(
            heatmapByMetric: [:],
            lensRowsByGroup: [
                .model: [
                    ModelLensRow(
                        dimensionName: "deepseek-ai/deepseek-v3.1",
                        providerId: "deepseek",
                        inputTokens: 100,
                        outputTPS: 10
                    )
                ],
                .provider: [
                    ModelLensRow(
                        dimensionName: "deepseek",
                        providerId: "",
                        inputTokens: 200,
                        outputTPS: 20
                    )
                ]
            ],
            delayByLensGroup: [
                .provider: 0.25
            ]
        )

        let vm = InsightsViewModel(statisticsRepository: repository, notificationCenter: NotificationCenter())
        waitForLoadCompletion(of: vm) { vm.loadIfNeeded() }
        XCTAssertEqual(vm.modelLensPoints.first?.dimensionName, "deepseek-ai/deepseek-v3.1")

        vm.modelLensGroupBy = .provider
        waitForSettling(seconds: 0.4)
        XCTAssertEqual(vm.modelLensPoints.first?.dimensionName, "deepseek")
    }

    private func waitForLoadCompletion(of targetViewModel: InsightsViewModel? = nil, trigger: (() -> Void)? = nil) {
        let target = targetViewModel ?? viewModel!
        let expectation = XCTestExpectation(description: "Insights load completes")
        var sawLoading = false

        target.$isLoading
            .sink { isLoading in
                if isLoading {
                    sawLoading = true
                    return
                }
                if sawLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        trigger?()
        wait(for: [expectation], timeout: 3.0)
    }

    private func waitForSettling(seconds: TimeInterval = 0.3) {
        let expectation = XCTestExpectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: seconds + 1.0)
    }

    private func seedMessages() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 2, day: 8, hour: 10))!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 2, day: 9, hour: 10))!

        try! dbPool.write { db in
            try insertMessage(db: db, id: "vm-weekend", createdAtMs: Int64(sunday.timeIntervalSince1970 * 1000), inputTokens: 100, outputTokens: 10)
            try insertMessage(db: db, id: "vm-weekday", createdAtMs: Int64(monday.timeIntervalSince1970 * 1000), inputTokens: 100, outputTokens: 10)
        }
    }

    private func insertMessage(
        db: Database,
        id: String,
        createdAtMs: Int64,
        inputTokens: Int,
        outputTokens: Int
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO messages (
                id, session_id, role, created_at, completed_at, provider_id, model_id,
                token_input, token_output, token_reasoning, cache_read, cache_write, cost,
                summary_total_additions, summary_total_deletions, summary_file_count
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id,
                "session-\(id)",
                "assistant",
                createdAtMs,
                createdAtMs + 1_000,
                "openai",
                "gpt-4",
                String(inputTokens),
                String(outputTokens),
                "0",
                0,
                0,
                0.1,
                0,
                0,
                0
            ]
        )
    }
}
