import XCTest
@testable import VibeWave
import GRDB

final class HistoryViewModelNotificationTests: XCTestCase {
    private final class FakeStatisticsRepository: StatisticsRepositoryProtocol {
        let onHourlyBreakdown: () -> Void

        init(onHourlyBreakdown: @escaping () -> Void) {
            self.onHourlyBreakdown = onHourlyBreakdown
        }

        func getHourlyBreakdown(timeRange: StatisticsRepository.TimeRange, metric: MetricType) -> [StatisticsRepository.HourlyStat] {
            onHourlyBreakdown()
            return []
        }

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
    }

    func testAppDataDidUpdate_TriggersReload() throws {
        let expectation = XCTestExpectation(description: "loadStats triggered by appDataDidUpdate")

        let repo = FakeStatisticsRepository(onHourlyBreakdown: {
            expectation.fulfill()
        })

        let tempDir = FileManager.default.temporaryDirectory
        let tempDBFile = tempDir.appendingPathComponent("history_vm_notification.db")
        let dbPool = try DatabasePool(path: tempDBFile.path)

        let notificationCenter = NotificationCenter()
        let viewModel = HistoryViewModel(
            dbPool: dbPool,
            statisticsRepository: repo,
            notificationCenter: notificationCenter
        )

        notificationCenter.post(name: .appDataDidUpdate, object: nil)

        wait(for: [expectation], timeout: 1.0)
        _ = viewModel
    }
}
