import Foundation
import Combine
import GRDB
import CoreGraphics

@MainActor
public final class InsightsViewModel: ObservableObject {
    private struct HeatmapRenderCacheKey: Hashable {
        let metric: InsightMetric
        let widthBucket: Int
        let pointCount: Int
        let firstDayStartMs: Int64
        let lastDayStartMs: Int64
    }

    private struct PersistedHeatPoint: Codable {
        let dayStartMs: Int64
        let value: Double
    }

    private struct PersistedHeatmapBundle: Codable {
        let dayStartMs: Int64
        let pointsByMetric: [String: [PersistedHeatPoint]]
    }

    private static let persistedHeatmapBundleKey = "insights.heatmap.bundle.v1"
    private static let heatmapWeekdayLabelWidth: CGFloat = 30
    private static let heatmapAxisSpacing: CGFloat = 8
    private static let heatmapWidthBucketSize: CGFloat = 8
    private static let heatmapWidthChangeThreshold: CGFloat = 1
    private static let heatmapMonthLocale = Locale(identifier: "en_US_POSIX")

    @Published public var userRhythmMetric: InsightMetric = .inputTokens
    @Published public var intensityMetric: InsightMetric = .inputTokens
    @Published public var dayTypeFilter: DayTypeFilter = .all
    @Published public var modelLensGroupBy: ModelLensGroupBy = .model
    @Published public var modelLensMetric: ModelLensMetric = .inputTokens
    @Published public var modelLensSortKey: ModelLensSortKey = .inputTokens
    @Published public var modelLensSortDirection: SortDirection = .descending

    @Published public var isLoading: Bool = false
    @Published public var isUserRhythmLoading: Bool = false
    @Published public var isIntensityLoading: Bool = false
    @Published public var isModelLensLoading: Bool = false
    @Published public var errorMessage: String?

    @Published public var heatmapPoints: [DailyHeatPoint] = []
    @Published public var weekdayWeekendIntensity: WeekdayWeekendIntensity = .init(
        weekdayTotal: 0,
        weekendTotal: 0,
        weekdayAverage: 0,
        weekendAverage: 0
    )
    @Published public var hourlyIntensity: [HourlyIntensityPoint] = []
    @Published public var heatmapRenderModel: HeatmapRenderModel = .empty
    @Published public var modelLensRows: [ModelLensRow] = []
    @Published public var displayedModelLensRows: [ModelLensRow] = []
    @Published public var modelLensPoints: [ModelLensPoint] = []

    private struct SendableRepositoryBox: @unchecked Sendable {
        let base: StatisticsRepositoryProtocol
    }

    private let repository: StatisticsRepositoryProtocol
    private let userDefaults: UserDefaults
    private let nowProvider: () -> Date
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedOnce: Bool = false
    private var userRhythmLoadID: Int = 0
    private var intensityLoadID: Int = 0
    private var modelLensLoadID: Int = 0
    private var heatmapContainerWidth: CGFloat = 0
    private var heatmapCache: [InsightMetric: [DailyHeatPoint]] = [:]
    private var heatmapRenderCache: [HeatmapRenderCacheKey: HeatmapRenderModel] = [:]
    private var heatmapCacheDayStartMs: Int64?
    private var modelLensRowsCache: [ModelLensGroupBy: [ModelLensRow]] = [:]

    public init(dbPool: DatabasePool) {
        self.repository = StatisticsRepository(dbPool: dbPool)
        self.userDefaults = .standard
        self.nowProvider = Date.init
        restorePersistedHeatmapCache()
        bindChanges()
    }

    init(
        statisticsRepository: StatisticsRepositoryProtocol,
        notificationCenter: NotificationCenter = .default,
        userDefaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = statisticsRepository
        self.userDefaults = userDefaults
        self.nowProvider = nowProvider
        _ = notificationCenter
        restorePersistedHeatmapCache()
        bindChanges()
    }

    public func loadIfNeeded() {
        guard !hasLoadedOnce else { return }
        load()
    }

    public func load() {
        hasLoadedOnce = true
        errorMessage = nil
        loadUserRhythmSection()
        loadIntensitySection()
        loadModelLensSection()
    }

    public func updateHeatmapContainerWidth(_ width: CGFloat) {
        let normalizedWidth = max(0, width)
        guard abs(heatmapContainerWidth - normalizedWidth) >= Self.heatmapWidthChangeThreshold else {
            return
        }
        heatmapContainerWidth = normalizedWidth
        refreshHeatmapRenderModel(metric: userRhythmMetric, points: heatmapPoints)
    }

    private func loadUserRhythmSection(metric overrideMetric: InsightMetric? = nil) {
        userRhythmLoadID += 1
        let requestLoadID = userRhythmLoadID
        let userMetric = overrideMetric ?? userRhythmMetric
        let todayDayStartMs = Self.currentLocalDayStartMs(now: nowProvider())

        if heatmapCacheDayStartMs != todayDayStartMs {
            heatmapCache.removeAll()
            heatmapRenderCache.removeAll()
            heatmapCacheDayStartMs = nil
        }

        if let cached = heatmapCache[userMetric] {
            heatmapPoints = cached
            refreshHeatmapRenderModel(metric: userMetric, points: cached)
            isUserRhythmLoading = false
            updateOverallLoading()
            return
        }

        let repository = SendableRepositoryBox(base: self.repository)
        isUserRhythmLoading = true
        updateOverallLoading()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let bundle = repository.base.getDailyActivityHeatmapBundle(lastNDays: 365)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard requestLoadID == self.userRhythmLoadID else {
                    return
                }
                for metric in InsightMetric.allCases {
                    self.heatmapCache[metric] = bundle[metric] ?? []
                }
                self.heatmapCacheDayStartMs = todayDayStartMs
                self.persistHeatmapCache(dayStartMs: todayDayStartMs)
                self.heatmapPoints = self.heatmapCache[userMetric] ?? []
                self.refreshHeatmapRenderModel(metric: userMetric, points: self.heatmapPoints)
                self.isUserRhythmLoading = false
                self.updateOverallLoading()
            }
        }
    }

    private func loadIntensitySection(
        metric overrideMetric: InsightMetric? = nil,
        filter overrideFilter: DayTypeFilter? = nil
    ) {
        intensityLoadID += 1
        let requestLoadID = intensityLoadID
        let dayMetric = overrideMetric ?? intensityMetric
        let dayFilter = overrideFilter ?? dayTypeFilter
        let repository = SendableRepositoryBox(base: self.repository)
        isIntensityLoading = true
        updateOverallLoading()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let weekdayWeekend = repository.base.getWeekdayWeekendIntensity(metric: dayMetric, filter: .all)
            let hourly = repository.base.getHourlyIntensity(metric: dayMetric, filter: dayFilter)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard requestLoadID == self.intensityLoadID else {
                    return
                }
                self.weekdayWeekendIntensity = weekdayWeekend
                self.hourlyIntensity = hourly
                self.isIntensityLoading = false
                self.updateOverallLoading()
            }
        }
    }

    private func loadModelLensSection(
        groupBy overrideGroupBy: ModelLensGroupBy? = nil
    ) {
        modelLensLoadID += 1
        let requestLoadID = modelLensLoadID
        let lensGroupBy = overrideGroupBy ?? modelLensGroupBy

        if let cachedRows = modelLensRowsCache[lensGroupBy] {
            modelLensRows = cachedRows
            updateDisplayedModelLensRows()
            modelLensPoints = mapModelLensPoints(from: cachedRows, metric: modelLensMetric)
            isModelLensLoading = false
            updateOverallLoading()
            return
        }

        let repository = SendableRepositoryBox(base: self.repository)
        isModelLensLoading = true
        updateOverallLoading()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let rows = repository.base.getModelLensRows(groupBy: lensGroupBy)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard requestLoadID == self.modelLensLoadID else {
                    return
                }
                self.modelLensRowsCache[lensGroupBy] = rows
                self.modelLensRows = rows
                self.updateDisplayedModelLensRows()
                self.modelLensPoints = self.mapModelLensPoints(from: rows, metric: self.modelLensMetric)
                self.isModelLensLoading = false
                self.updateOverallLoading()
            }
        }
    }

    private func updateOverallLoading() {
        isLoading = isUserRhythmLoading || isIntensityLoading || isModelLensLoading
    }

    private func bindChanges() {
        $userRhythmMetric
            .dropFirst()
            .sink { [weak self] metric in
                self?.loadUserRhythmSection(metric: metric)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($intensityMetric, $dayTypeFilter)
            .dropFirst()
            .sink { [weak self] metric, filter in
                self?.loadIntensitySection(metric: metric, filter: filter)
            }
            .store(in: &cancellables)

        $modelLensGroupBy
            .dropFirst()
            .sink { [weak self] groupBy in
                self?.loadModelLensSection(groupBy: groupBy)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($modelLensSortKey, $modelLensSortDirection)
            .dropFirst()
            .debounce(for: .milliseconds(10), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.updateDisplayedModelLensRows()
            }
            .store(in: &cancellables)

        $modelLensMetric
            .dropFirst()
            .sink { [weak self] metric in
                guard let self = self else { return }
                self.modelLensPoints = self.mapModelLensPoints(from: self.modelLensRows, metric: metric)
            }
            .store(in: &cancellables)
    }

    private func updateDisplayedModelLensRows() {
        let sorted = sortModelLensRows(
            modelLensRows,
            key: modelLensSortKey,
            direction: modelLensSortDirection
        )
        guard sorted != displayedModelLensRows else { return }
        displayedModelLensRows = sorted
    }

    private func sortModelLensRows(
        _ rows: [ModelLensRow],
        key: ModelLensSortKey,
        direction: SortDirection
    ) -> [ModelLensRow] {
        rows.sorted { lhs, rhs in
            let lhsValue: Double
            let rhsValue: Double
            switch key {
            case .inputTokens:
                lhsValue = lhs.inputTokens
                rhsValue = rhs.inputTokens
            case .outputTPS:
                lhsValue = lhs.outputTPS
                rhsValue = rhs.outputTPS
            }

            if lhsValue != rhsValue {
                return direction == .descending ? lhsValue > rhsValue : lhsValue < rhsValue
            }
            return lhs.dimensionName.localizedCaseInsensitiveCompare(rhs.dimensionName) == .orderedAscending
        }
    }

    private func refreshHeatmapRenderModel(metric: InsightMetric, points: [DailyHeatPoint]) {
        guard !points.isEmpty else {
            guard heatmapRenderModel != .empty else { return }
            heatmapRenderModel = .empty
            return
        }

        let availableGridWidth = max(0, heatmapContainerWidth - Self.heatmapWeekdayLabelWidth - Self.heatmapAxisSpacing)
        let widthBucket = Int(floor(availableGridWidth / Self.heatmapWidthBucketSize))
        let quantizedGridWidth = CGFloat(max(0, widthBucket)) * Self.heatmapWidthBucketSize
        let firstDayStartMs = points.map(\.dayStartMs).min() ?? 0
        let lastDayStartMs = points.map(\.dayStartMs).max() ?? 0
        let cacheKey = HeatmapRenderCacheKey(
            metric: metric,
            widthBucket: widthBucket,
            pointCount: points.count,
            firstDayStartMs: firstDayStartMs,
            lastDayStartMs: lastDayStartMs
        )

        if let cached = heatmapRenderCache[cacheKey] {
            guard heatmapRenderModel != cached else { return }
            heatmapRenderModel = cached
            return
        }

        let computed = makeHeatmapRenderModel(points: points, availableGridWidth: quantizedGridWidth)
        heatmapRenderCache[cacheKey] = computed
        guard heatmapRenderModel != computed else { return }
        heatmapRenderModel = computed
    }

    private func makeHeatmapRenderModel(
        points: [DailyHeatPoint],
        availableGridWidth: CGFloat
    ) -> HeatmapRenderModel {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        let cells = ContributionHeatmapLayout.buildHeatCells(points: points, calendar: calendar)
        let columnCount = ContributionHeatmapLayout.weekColumnCount(cellCount: cells.count)
        let scaledMetrics = ContributionHeatmapLayout.scaledMetrics(
            availableWidth: availableGridWidth,
            columnCount: columnCount
        )
        let monthLabels = ContributionHeatmapLayout.monthLabels(
            from: cells,
            calendar: calendar,
            locale: Self.heatmapMonthLocale,
            limit: 12
        )
        let maxValue = points.map(\.value).max() ?? 0

        return HeatmapRenderModel(
            cells: cells,
            monthLabels: monthLabels,
            scaledMetrics: scaledMetrics,
            availableGridWidth: availableGridWidth,
            maxValue: maxValue
        )
    }

    private func mapModelLensPoints(from rows: [ModelLensRow], metric: ModelLensMetric) -> [ModelLensPoint] {
        var points = rows.map { row in
            ModelLensPoint(
                dimensionName: row.dimensionName,
                providerId: row.providerId,
                value: metric == .inputTokens ? row.inputTokens : row.outputTPS,
                outputTokens: row.outputTokens,
                durationSeconds: row.durationSeconds,
                validDurationMessageRatio: row.validDurationMessageRatio
            )
        }
        points.sort(by: { $0.value > $1.value })
        return points
    }

    private static func currentLocalDayStartMs(now: Date = Date()) -> Int64 {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let dayStart = calendar.startOfDay(for: now)
        return Int64(dayStart.timeIntervalSince1970 * 1000)
    }

    private func restorePersistedHeatmapCache() {
        guard let data = userDefaults.data(forKey: Self.persistedHeatmapBundleKey) else { return }
        guard let payload = try? JSONDecoder().decode(PersistedHeatmapBundle.self, from: data) else { return }

        var restored: [InsightMetric: [DailyHeatPoint]] = [:]
        for metric in InsightMetric.allCases {
            let persistedPoints = payload.pointsByMetric[metric.rawValue] ?? []
            restored[metric] = persistedPoints.map { point in
                DailyHeatPoint(
                    date: Date(timeIntervalSince1970: Double(point.dayStartMs) / 1000.0),
                    dayStartMs: point.dayStartMs,
                    value: point.value
                )
            }
        }

        heatmapCache = restored
        heatmapCacheDayStartMs = payload.dayStartMs
        heatmapPoints = restored[userRhythmMetric] ?? []
        refreshHeatmapRenderModel(metric: userRhythmMetric, points: heatmapPoints)
    }

    private func persistHeatmapCache(dayStartMs: Int64) {
        var serialized: [String: [PersistedHeatPoint]] = [:]
        for metric in InsightMetric.allCases {
            let points = heatmapCache[metric] ?? []
            serialized[metric.rawValue] = points.map { point in
                PersistedHeatPoint(dayStartMs: point.dayStartMs, value: point.value)
            }
        }

        let payload = PersistedHeatmapBundle(dayStartMs: dayStartMs, pointsByMetric: serialized)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        userDefaults.set(data, forKey: Self.persistedHeatmapBundleKey)
    }
}
