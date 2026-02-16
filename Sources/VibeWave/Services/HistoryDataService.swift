import Foundation
import GRDB

public final class HistoryDataService: @unchecked Sendable {
    private enum BucketGranularity {
        case hourly
        case daily
        case monthly
    }

    private let repository: StatisticsRepository

    private var localCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    public init(repository: StatisticsRepository) {
        self.repository = repository
    }

    func getHourlyInputTokensFromAggregatedTable() -> [InputTokensDataPoint] {
        let window = TimeSeriesFiller.last24HourWindowAnchoredToCurrentHour()
        let start = window.start
        let end = window.endExclusive

        let bucketValues = queryInputTokens(
            from: "hourly_stats",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .hourly
        )

        return TimeSeriesFiller.fillHourlyData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 24
        )
    }

    func getDailyInputTokensFromAggregatedTable() -> [InputTokensDataPoint] {
        let now = Date()
        let todayStart = localCalendar.startOfDay(for: now)
        let start = localCalendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let end = localCalendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        let bucketValues = queryInputTokens(
            from: "daily_stats",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .daily
        )

        return TimeSeriesFiller.fillDailyData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 30
        )
    }

    func getAllTimeInputTokensFromAggregatedTable() -> [InputTokensDataPoint] {
        let now = Date()
        let currentMonth = startOfMonthLocal(now)
        let start = localCalendar.date(byAdding: .month, value: -11, to: currentMonth) ?? currentMonth
        let end = localCalendar.date(byAdding: .month, value: 12, to: start) ?? now

        let bucketValues = queryInputTokens(
            from: "monthly_stats",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .monthly
        )

        return TimeSeriesFiller.fillMonthlyData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 12
        )
    }

    func getHourlyOutputReasoningFromAggregatedTable() -> [OutputReasoningDataPoint] {
        let window = TimeSeriesFiller.last24HourWindowAnchoredToCurrentHour()
        let start = window.start
        let end = window.endExclusive

        let bucketValues = queryOutputReasoningTokens(
            from: "hourly_stats",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .hourly
        )

        return TimeSeriesFiller.fillHourlyOutputReasoningData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 24
        )
    }

    func getDailyOutputReasoningFromAggregatedTable() -> [OutputReasoningDataPoint] {
        let now = Date()
        let todayStart = localCalendar.startOfDay(for: now)
        let start = localCalendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let end = localCalendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        let bucketValues = queryOutputReasoningTokens(
            from: "daily_stats",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .daily
        )

        return TimeSeriesFiller.fillDailyOutputReasoningData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 30
        )
    }

    func getAllTimeOutputReasoningFromAggregatedTable() -> [OutputReasoningDataPoint] {
        let now = Date()
        let currentMonth = startOfMonthLocal(now)
        let start = localCalendar.date(byAdding: .month, value: -11, to: currentMonth) ?? currentMonth
        let end = localCalendar.date(byAdding: .month, value: 12, to: start) ?? now

        let bucketValues = queryOutputReasoningTokens(
            from: "monthly_stats",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .monthly
        )

        return TimeSeriesFiller.fillMonthlyOutputReasoningData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 12
        )
    }

    func getHourlyCostFromAggregatedTable() -> [SingleMetricDataPoint] {
        let window = TimeSeriesFiller.last24HourWindowAnchoredToCurrentHour()
        let start = window.start
        let end = window.endExclusive

        let bucketValues = querySingleMetric(
            from: "hourly_stats",
            metricColumn: "cost",
            metricAlias: "total_cost",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .hourly
        )

        return TimeSeriesFiller.fillHourlySingleMetricData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 24
        )
    }

    func getDailyCostFromAggregatedTable() -> [SingleMetricDataPoint] {
        let now = Date()
        let todayStart = localCalendar.startOfDay(for: now)
        let start = localCalendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let end = localCalendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        let bucketValues = querySingleMetric(
            from: "daily_stats",
            metricColumn: "cost",
            metricAlias: "total_cost",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .daily
        )

        return TimeSeriesFiller.fillDailySingleMetricData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 30
        )
    }

    func getAllTimeCostFromAggregatedTable() -> [SingleMetricDataPoint] {
        let now = Date()
        let currentMonth = startOfMonthLocal(now)
        let start = localCalendar.date(byAdding: .month, value: -11, to: currentMonth) ?? currentMonth
        let end = localCalendar.date(byAdding: .month, value: 12, to: start) ?? now

        let bucketValues = querySingleMetric(
            from: "monthly_stats",
            metricColumn: "cost",
            metricAlias: "total_cost",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .monthly
        )

        return TimeSeriesFiller.fillMonthlySingleMetricData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 12
        )
    }

    func getHourlySessionsFromAggregatedTable() -> [SingleMetricDataPoint] {
        let window = TimeSeriesFiller.last24HourWindowAnchoredToCurrentHour()
        let start = window.start
        let end = window.endExclusive

        let bucketValues = querySingleMetric(
            from: "hourly_stats",
            metricColumn: "session_count",
            metricAlias: "total_session_count",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .hourly
        )

        return TimeSeriesFiller.fillHourlySingleMetricData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 24
        )
    }

    func getDailySessionsFromAggregatedTable() -> [SingleMetricDataPoint] {
        let now = Date()
        let todayStart = localCalendar.startOfDay(for: now)
        let start = localCalendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let end = localCalendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        let bucketValues = querySingleMetric(
            from: "daily_stats",
            metricColumn: "session_count",
            metricAlias: "total_session_count",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .daily
        )

        return TimeSeriesFiller.fillDailySingleMetricData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 30
        )
    }

    func getAllTimeSessionsFromAggregatedTable() -> [SingleMetricDataPoint] {
        let now = Date()
        let currentMonth = startOfMonthLocal(now)
        let start = localCalendar.date(byAdding: .month, value: -11, to: currentMonth) ?? currentMonth
        let end = localCalendar.date(byAdding: .month, value: 12, to: start) ?? now

        let bucketValues = querySingleMetric(
            from: "monthly_stats",
            metricColumn: "session_count",
            metricAlias: "total_session_count",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .monthly
        )

        return TimeSeriesFiller.fillMonthlySingleMetricData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 12
        )
    }

    func getHourlyMessagesFromAggregatedTable() -> [SingleMetricDataPoint] {
        let window = TimeSeriesFiller.last24HourWindowAnchoredToCurrentHour()
        let start = window.start
        let end = window.endExclusive

        let bucketValues = querySingleMetric(
            from: "hourly_stats",
            metricColumn: "message_count",
            metricAlias: "total_message_count",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .hourly
        )

        return TimeSeriesFiller.fillHourlySingleMetricData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 24
        )
    }

    func getDailyMessagesFromAggregatedTable() -> [SingleMetricDataPoint] {
        let now = Date()
        let todayStart = localCalendar.startOfDay(for: now)
        let start = localCalendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let end = localCalendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        let bucketValues = querySingleMetric(
            from: "daily_stats",
            metricColumn: "message_count",
            metricAlias: "total_message_count",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .daily
        )

        return TimeSeriesFiller.fillDailySingleMetricData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 30
        )
    }

    func getAllTimeMessagesFromAggregatedTable() -> [SingleMetricDataPoint] {
        let now = Date()
        let currentMonth = startOfMonthLocal(now)
        let start = localCalendar.date(byAdding: .month, value: -11, to: currentMonth) ?? currentMonth
        let end = localCalendar.date(byAdding: .month, value: 12, to: start) ?? now

        let bucketValues = querySingleMetric(
            from: "monthly_stats",
            metricColumn: "message_count",
            metricAlias: "total_message_count",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .monthly
        )

        return TimeSeriesFiller.fillMonthlySingleMetricData(
            bucketValues: bucketValues,
            startTime: start,
            barCount: 12
        )
    }

    func getHourlyMessageDurationHoursFromAggregatedTable() -> [SingleMetricDataPoint] {
        let window = TimeSeriesFiller.last24HourWindowAnchoredToCurrentHour()
        let start = window.start
        let end = window.endExclusive

        let durationMsBuckets = querySingleMetric(
            from: "hourly_stats",
            metricColumn: "duration_ms",
            metricAlias: "total_duration_ms",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .hourly
        )

        let durationHoursBuckets = convertDurationMsBucketsToHours(durationMsBuckets)
        return TimeSeriesFiller.fillHourlySingleMetricData(
            bucketValues: durationHoursBuckets,
            startTime: start,
            barCount: 24
        )
    }

    func getDailyMessageDurationHoursFromAggregatedTable() -> [SingleMetricDataPoint] {
        let now = Date()
        let todayStart = localCalendar.startOfDay(for: now)
        let start = localCalendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let end = localCalendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        let durationMsBuckets = querySingleMetric(
            from: "daily_stats",
            metricColumn: "duration_ms",
            metricAlias: "total_duration_ms",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .daily
        )

        let durationHoursBuckets = convertDurationMsBucketsToHours(durationMsBuckets)
        return TimeSeriesFiller.fillDailySingleMetricData(
            bucketValues: durationHoursBuckets,
            startTime: start,
            barCount: 30
        )
    }

    func getAllTimeMessageDurationHoursFromAggregatedTable() -> [SingleMetricDataPoint] {
        let now = Date()
        let currentMonth = startOfMonthLocal(now)
        let start = localCalendar.date(byAdding: .month, value: -11, to: currentMonth) ?? currentMonth
        let end = localCalendar.date(byAdding: .month, value: 12, to: start) ?? now

        let durationMsBuckets = querySingleMetric(
            from: "monthly_stats",
            metricColumn: "duration_ms",
            metricAlias: "total_duration_ms",
            startMs: toMilliseconds(start),
            endMs: toMilliseconds(end),
            granularity: .monthly
        )

        let durationHoursBuckets = convertDurationMsBucketsToHours(durationMsBuckets)
        return TimeSeriesFiller.fillMonthlySingleMetricData(
            bucketValues: durationHoursBuckets,
            startTime: start,
            barCount: 12
        )
    }

    private func convertDurationMsBucketsToHours(_ buckets: [Int64: Double]) -> [Int64: Double] {
        buckets.reduce(into: [Int64: Double]()) { partialResult, entry in
            partialResult[entry.key] = entry.value / 3_600_000.0
        }
    }

    private func queryInputTokens(
        from tableName: String,
        startMs: Int64,
        endMs: Int64,
        granularity: BucketGranularity
    ) -> [Int64: Int] {
        let (queryStartMs, queryEndMs) = expandedQueryRange(startMs: startMs, endMs: endMs, granularity: granularity)

        let sql = """
            SELECT
                time_bucket_ms,
                SUM(input_tokens) AS total_input_tokens
            FROM \(tableName)
            WHERE time_bucket_ms >= ? AND time_bucket_ms < ?
            GROUP BY time_bucket_ms
            ORDER BY time_bucket_ms ASC
            """

        do {
            return try repository.dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: sql, arguments: [queryStartMs, queryEndMs])
                var values: [Int64: Int] = [:]

                for row in rows {
                    let rawBucketMs = row["time_bucket_ms"] as? Int64 ?? 0
                    let totalInputTokens = Int(row["total_input_tokens"] as? Int64 ?? 0)
                    let localizedBucketMs = normalizeBucketMs(rawBucketMs, granularity: granularity)

                    guard localizedBucketMs >= startMs, localizedBucketMs < endMs else { continue }
                    values[localizedBucketMs, default: 0] += totalInputTokens
                }

                return values
            }
        } catch {
            print("Error querying \(tableName): \(error)")
            return [:]
        }
    }

    private func queryOutputReasoningTokens(
        from tableName: String,
        startMs: Int64,
        endMs: Int64,
        granularity: BucketGranularity
    ) -> [Int64: (output: Int, reasoning: Int)] {
        let (queryStartMs, queryEndMs) = expandedQueryRange(startMs: startMs, endMs: endMs, granularity: granularity)

        let sql = """
            SELECT
                time_bucket_ms,
                SUM(output_tokens) AS total_output_tokens,
                SUM(reasoning_tokens) AS total_reasoning_tokens
            FROM \(tableName)
            WHERE time_bucket_ms >= ? AND time_bucket_ms < ?
            GROUP BY time_bucket_ms
            ORDER BY time_bucket_ms ASC
            """

        do {
            return try repository.dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: sql, arguments: [queryStartMs, queryEndMs])
                var values: [Int64: (output: Int, reasoning: Int)] = [:]

                for row in rows {
                    let rawBucketMs = row["time_bucket_ms"] as? Int64 ?? 0
                    let totalOutputTokens = Int(row["total_output_tokens"] as? Int64 ?? 0)
                    let totalReasoningTokens = Int(row["total_reasoning_tokens"] as? Int64 ?? 0)
                    let localizedBucketMs = normalizeBucketMs(rawBucketMs, granularity: granularity)

                    guard localizedBucketMs >= startMs, localizedBucketMs < endMs else { continue }

                    let existing = values[localizedBucketMs] ?? (output: 0, reasoning: 0)
                    values[localizedBucketMs] = (
                        output: existing.output + totalOutputTokens,
                        reasoning: existing.reasoning + totalReasoningTokens
                    )
                }

                return values
            }
        } catch {
            print("Error querying \(tableName): \(error)")
            return [:]
        }
    }

    private func querySingleMetric(
        from tableName: String,
        metricColumn: String,
        metricAlias: String,
        startMs: Int64,
        endMs: Int64,
        granularity: BucketGranularity
    ) -> [Int64: Double] {
        let (queryStartMs, queryEndMs) = expandedQueryRange(startMs: startMs, endMs: endMs, granularity: granularity)

        let sql = """
            SELECT
                time_bucket_ms,
                SUM(\(metricColumn)) AS \(metricAlias)
            FROM \(tableName)
            WHERE time_bucket_ms >= ? AND time_bucket_ms < ?
            GROUP BY time_bucket_ms
            ORDER BY time_bucket_ms ASC
            """

        do {
            return try repository.dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: sql, arguments: [queryStartMs, queryEndMs])
                var values: [Int64: Double] = [:]

                for row in rows {
                    let rawBucketMs = row["time_bucket_ms"] as? Int64 ?? 0
                    let metricValue = numericValue(from: row, key: metricAlias)
                    let localizedBucketMs = normalizeBucketMs(rawBucketMs, granularity: granularity)

                    guard localizedBucketMs >= startMs, localizedBucketMs < endMs else { continue }
                    values[localizedBucketMs, default: 0] += metricValue
                }

                return values
            }
        } catch {
            print("Error querying \(tableName): \(error)")
            return [:]
        }
    }

    private func expandedQueryRange(
        startMs: Int64,
        endMs: Int64,
        granularity: BucketGranularity
    ) -> (Int64, Int64) {
        let startDate = Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)
        let endDate = Date(timeIntervalSince1970: TimeInterval(endMs) / 1000)

        switch granularity {
        case .hourly:
            return (startMs, endMs)

        case .daily:
            let expandedStart = localCalendar.date(byAdding: .day, value: -2, to: startDate) ?? startDate
            let expandedEnd = localCalendar.date(byAdding: .day, value: 2, to: endDate) ?? endDate
            return (toMilliseconds(expandedStart), toMilliseconds(expandedEnd))

        case .monthly:
            let expandedStart = localCalendar.date(byAdding: .month, value: -1, to: startDate) ?? startDate
            let expandedEnd = localCalendar.date(byAdding: .month, value: 1, to: endDate) ?? endDate
            return (toMilliseconds(expandedStart), toMilliseconds(expandedEnd))
        }
    }

    private func normalizeBucketMs(_ rawBucketMs: Int64, granularity: BucketGranularity) -> Int64 {
        let date = Date(timeIntervalSince1970: TimeInterval(rawBucketMs) / 1000)

        switch granularity {
        case .hourly:
            let components = localCalendar.dateComponents([.year, .month, .day, .hour], from: date)
            let alignedDate = localCalendar.date(from: components) ?? date
            return toMilliseconds(alignedDate)

        case .daily:
            return toMilliseconds(localCalendar.startOfDay(for: date))

        case .monthly:
            return toMilliseconds(startOfMonthLocal(date))
        }
    }

    private func startOfMonthLocal(_ date: Date) -> Date {
        let components = localCalendar.dateComponents([.year, .month], from: date)
        return localCalendar.date(from: components) ?? date
    }

    private func toMilliseconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    private func numericValue(from row: Row, key: String) -> Double {
        if let value = row[key] as? Double {
            return value
        }
        if let value = row[key] as? Int64 {
            return Double(value)
        }
        if let value = row[key] as? Int {
            return Double(value)
        }
        return 0
    }
}
