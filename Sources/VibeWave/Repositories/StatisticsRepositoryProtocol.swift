import Foundation

public enum MetricType: String, CaseIterable {
    case messages = "Messages"
    case tokens = "Tokens"
    case cost = "Cost"
    case sessions = "Sessions"
}

public protocol StatisticsRepositoryProtocol {
    func getHourlyBreakdown(timeRange: StatisticsRepository.TimeRange, metric: MetricType) -> [StatisticsRepository.HourlyStat]
    func getTimeClusterStats(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.TimeClusterStat]
    func getTokenDivergingData(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.TokenDivergingDataPoint]
    func getDualAxisData(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.DualAxisDataPoint]
    func getTrendData(timeRange: StatisticsRepository.TimeRange, metric: MetricType, granularity: TimeGranularity) -> [StatisticsRepository.TrendDataPoint]
    func getWeekdayVsWeekendStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.WeekdayWeekendStats
    func getMonthlyStats(timeRange: StatisticsRepository.TimeRange, metric: MetricType) -> [StatisticsRepository.MonthlyStat]
    func getActiveStreakData(year: Int) -> [StatisticsRepository.DayActivity]
    func getUserAgentMessageCounts(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.UserAgentCount]
    func getUserAgentSessionCounts(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.UserAgentSessionCounts
    func getAgentSessionDistribution(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.AgentSessionCount]
    func getNetCodeOutputStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.NetCodeOutputStats
    func getBillingCostStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.BillingCostStats
    func getUserAgentMessageTrend(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.UserAgentTrendPoint]
    func getCodeOutputCostTrend(timeRange: StatisticsRepository.TimeRange, granularity: TimeGranularity) -> [StatisticsRepository.CodeOutputCostTrendPoint]
    func getModelProcessingStats(timeRange: StatisticsRepository.TimeRange) -> [StatisticsRepository.ModelProcessingStat]
    func getRhythmInsights(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.RhythmInsights
    func getAnomalyStats(timeRange: StatisticsRepository.TimeRange) -> StatisticsRepository.AnomalyStats
    func getInputTokensByProject(timeRange: StatisticsRepository.TimeRange, topN: Int) -> [SegmentedBarDataPoint]
    func getInputTokensByModel(timeRange: StatisticsRepository.TimeRange, topN: Int) -> [SegmentedBarDataPoint]
    func getDailyActivityHeatmap(metric: InsightMetric, lastNDays: Int) -> [DailyHeatPoint]
    func getDailyActivityHeatmapBundle(lastNDays: Int) -> [InsightMetric: [DailyHeatPoint]]
    func getWeekdayWeekendIntensity(metric: InsightMetric, filter: DayTypeFilter) -> WeekdayWeekendIntensity
    func getHourlyIntensity(metric: InsightMetric, filter: DayTypeFilter) -> [HourlyIntensityPoint]
    func getModelLensStats(groupBy: ModelLensGroupBy, metric: ModelLensMetric) -> [ModelLensPoint]
    func getModelLensRows(groupBy: ModelLensGroupBy) -> [ModelLensRow]
}

public extension StatisticsRepositoryProtocol {
    func getDailyActivityHeatmap(metric: InsightMetric, lastNDays: Int) -> [DailyHeatPoint] { [] }
    func getDailyActivityHeatmapBundle(lastNDays: Int) -> [InsightMetric: [DailyHeatPoint]] {
        Dictionary(uniqueKeysWithValues: InsightMetric.allCases.map { metric in
            (metric, getDailyActivityHeatmap(metric: metric, lastNDays: lastNDays))
        })
    }
    func getWeekdayWeekendIntensity(metric: InsightMetric, filter: DayTypeFilter) -> WeekdayWeekendIntensity {
        WeekdayWeekendIntensity(weekdayTotal: 0, weekendTotal: 0, weekdayAverage: 0, weekendAverage: 0)
    }
    func getHourlyIntensity(metric: InsightMetric, filter: DayTypeFilter) -> [HourlyIntensityPoint] { [] }
    func getModelLensStats(groupBy: ModelLensGroupBy, metric: ModelLensMetric) -> [ModelLensPoint] { [] }
    func getModelLensRows(groupBy: ModelLensGroupBy) -> [ModelLensRow] { [] }
}
