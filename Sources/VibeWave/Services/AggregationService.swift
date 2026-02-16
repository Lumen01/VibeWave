import Foundation
import GRDB

public final class AggregationService {
    private let dbPool: DatabasePool
    private let logger = AppLogger(category: "AggregationService")

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func rebuildAllAggregations() throws {
        logger.info("开始重建所有聚合数据")
        let startTime = Date()

        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM hourly_stats")
            try db.execute(sql: "DELETE FROM daily_stats")
            try db.execute(sql: "DELETE FROM monthly_stats")
        }

        let timeRange = try dbPool.read { db -> (min: Int64, max: Int64)? in
            let row = try Row.fetchOne(db, sql: "SELECT MIN(created_at) as min_time, MAX(created_at) as max_time FROM messages")
            guard let minTime = row?["min_time"] as? Int64,
                  let maxTime = row?["max_time"] as? Int64 else {
                return nil
            }
            return (min: minTime, max: maxTime)
        }

        guard let range = timeRange else {
            logger.info("没有消息数据，跳过聚合")
            return
        }

        let hourlyMin = Self.calculateHourlyBucket(timestampMs: range.min)
        let hourlyMax = Self.calculateHourlyBucket(timestampMs: range.max) + TimeGranularity.hourly.bucketIntervalMs
        let dailyMin = Self.calculateDailyBucket(timestampMs: range.min)
        let dailyMax = Self.calculateDailyBucket(timestampMs: range.max) + TimeGranularity.daily.bucketIntervalMs
        let monthlyMin = Self.calculateMonthlyBucket(timestampMs: range.min)
        let monthlyMax = Self.calculateNextMonthlyBucket(timestampMs: range.max)

        try dbPool.write { db in
            try db.execute(
                sql: Self.hourlyAggregationSQL,
                arguments: [hourlyMin, hourlyMax]
            )
            try db.execute(
                sql: Self.dailyAggregationSQL,
                arguments: [dailyMin, dailyMax]
            )
            try db.execute(
                sql: Self.monthlyAggregationSQL,
                arguments: [monthlyMin, monthlyMax]
            )
        }

        let duration = Date().timeIntervalSince(startTime)
        logger.info("聚合完成: 耗时 \(String(format: "%.2f", duration))s")
    }

    public func recalculateAffectedAggregations(for sessionIds: Set<String>) throws {
        guard !sessionIds.isEmpty else { return }
        logger.debug("重新计算 \(sessionIds.count) 个会话的聚合")

        let placeholders = sessionIds.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT MIN(created_at) as min_time, MAX(created_at) as max_time
            FROM messages
            WHERE session_id IN (\(placeholders))
            """

        let timeRange = try dbPool.read { db -> (min: Int64, max: Int64)? in
            let row = try Row.fetchOne(db, sql: sql, arguments: StatementArguments(sessionIds))
            guard let minTime = row?["min_time"] as? Int64,
                  let maxTime = row?["max_time"] as? Int64 else {
                return nil
            }
            return (min: minTime, max: maxTime)
        }

        guard let range = timeRange else {
            logger.warn("无法获取受影响会话的时间范围")
            return
        }

        let expandedMin = Self.calculateHourlyBucket(timestampMs: range.min)
        let expandedMax = Self.calculateHourlyBucket(timestampMs: range.max) + TimeGranularity.hourly.bucketIntervalMs

        try dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM hourly_stats WHERE time_bucket_ms >= ? AND time_bucket_ms < ?",
                arguments: [expandedMin, expandedMax]
            )

            try db.execute(
                sql: Self.hourlyAggregationSQL,
                arguments: [expandedMin, expandedMax]
            )

            let dailyMin = Self.calculateDailyBucket(timestampMs: range.min)
            let dailyMax = Self.calculateDailyBucket(timestampMs: range.max) + TimeGranularity.daily.bucketIntervalMs

            try db.execute(
                sql: "DELETE FROM daily_stats WHERE time_bucket_ms >= ? AND time_bucket_ms < ?",
                arguments: [dailyMin, dailyMax]
            )
            try db.execute(
                sql: Self.dailyAggregationSQL,
                arguments: [dailyMin, dailyMax]
            )

            let monthlyMin = Self.calculateMonthlyBucket(timestampMs: range.min)
            let monthlyMax = Self.calculateNextMonthlyBucket(timestampMs: range.max)

            try db.execute(
                sql: "DELETE FROM monthly_stats WHERE time_bucket_ms >= ? AND time_bucket_ms < ?",
                arguments: [monthlyMin, monthlyMax]
            )
            try db.execute(
                sql: Self.monthlyAggregationSQL,
                arguments: [monthlyMin, monthlyMax]
            )
        }

        logger.debug("受影响聚合重新计算完成")
    }

    static func calculateHourlyBucket(timestampMs: Int64) -> Int64 {
        return (timestampMs / (3600 * 1000)) * (3600 * 1000)
    }

    static func calculateDailyBucket(timestampMs: Int64) -> Int64 {
        return (timestampMs / (86400 * 1000)) * (86400 * 1000)
    }

    static func calculateMonthlyBucket(timestampMs: Int64) -> Int64 {
        let date = Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month], from: date)
        let startOfMonth = calendar.date(from: components)!
        return Int64(startOfMonth.timeIntervalSince1970 * 1000)
    }

    static func calculateNextMonthlyBucket(timestampMs: Int64) -> Int64 {
        let monthStart = calculateMonthlyBucket(timestampMs: timestampMs)
        let startDate = Date(timeIntervalSince1970: TimeInterval(monthStart) / 1000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startDate)!
        return Int64(nextMonth.timeIntervalSince1970 * 1000)
    }
}

private extension AggregationService {
    static let hourlyAggregationSQL = """
        INSERT INTO hourly_stats (
            time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
            session_count, message_count, input_tokens, output_tokens, reasoning_tokens,
            cache_read, cache_write, duration_ms, cost, net_code_lines, file_count,
            last_created_at_ms
        )
        SELECT
            (m.created_at / 3600000) * 3600000 as time_bucket_ms,
            COALESCE(s.project_name, '未知项目') as project_id,
            COALESCE(m.provider_id, 'unknown') as provider_id,
            COALESCE(m.model_id, 'unknown') as model_id,
            COALESCE(m.role, 'unknown') as role,
            COALESCE(m.agent, 'unknown') as agent,
            COALESCE(m.tool_id, 'opencode') as tool_id,
            COUNT(DISTINCT m.session_id) as session_count,
            COUNT(*) as message_count,
            COALESCE(SUM(CAST(COALESCE(m.token_input, '0') AS INTEGER)), 0) as input_tokens,
            COALESCE(SUM(CAST(COALESCE(m.token_output, '0') AS INTEGER)), 0) as output_tokens,
            COALESCE(SUM(CAST(COALESCE(m.token_reasoning, '0') AS INTEGER)), 0) as reasoning_tokens,
            COALESCE(SUM(m.cache_read), 0) as cache_read,
            COALESCE(SUM(m.cache_write), 0) as cache_write,
            COALESCE(SUM(m.completed_at - m.created_at), 0) as duration_ms,
            COALESCE(SUM(m.cost), 0) as cost,
            COALESCE(
                SUM(COALESCE(m.summary_total_additions, 0) - COALESCE(m.summary_total_deletions, 0)),
                0
            ) as net_code_lines,
            COALESCE(SUM(COALESCE(m.summary_file_count, 0)), 0) as file_count,
            MAX(m.created_at) as last_created_at_ms
        FROM messages m
        LEFT JOIN sessions s ON m.session_id = s.session_id
        WHERE m.created_at >= ? AND m.created_at < ?
        GROUP BY
            (m.created_at / 3600000) * 3600000,
            COALESCE(s.project_name, '未知项目'),
            COALESCE(m.provider_id, 'unknown'),
            COALESCE(m.model_id, 'unknown'),
            COALESCE(m.role, 'unknown'),
            COALESCE(m.agent, 'unknown'),
            COALESCE(m.tool_id, 'opencode')
        ON CONFLICT(time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id) DO UPDATE SET
            session_count = excluded.session_count,
            message_count = excluded.message_count,
            input_tokens = excluded.input_tokens,
            output_tokens = excluded.output_tokens,
            reasoning_tokens = excluded.reasoning_tokens,
            cache_read = excluded.cache_read,
            cache_write = excluded.cache_write,
            duration_ms = excluded.duration_ms,
            cost = excluded.cost,
            net_code_lines = excluded.net_code_lines,
            file_count = excluded.file_count,
            last_created_at_ms = excluded.last_created_at_ms
        """

    static let dailyAggregationSQL = """
        INSERT INTO daily_stats (
            time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
            session_count, message_count, input_tokens, output_tokens, reasoning_tokens,
            cache_read, cache_write, duration_ms, cost, net_code_lines, file_count,
            last_created_at_ms
        )
        SELECT
            (m.created_at / 86400000) * 86400000 as time_bucket_ms,
            COALESCE(s.project_name, '未知项目') as project_id,
            COALESCE(m.provider_id, 'unknown') as provider_id,
            COALESCE(m.model_id, 'unknown') as model_id,
            COALESCE(m.role, 'unknown') as role,
            COALESCE(m.agent, 'unknown') as agent,
            COALESCE(m.tool_id, 'opencode') as tool_id,
            COUNT(DISTINCT m.session_id) as session_count,
            COUNT(*) as message_count,
            COALESCE(SUM(CAST(COALESCE(m.token_input, '0') AS INTEGER)), 0) as input_tokens,
            COALESCE(SUM(CAST(COALESCE(m.token_output, '0') AS INTEGER)), 0) as output_tokens,
            COALESCE(SUM(CAST(COALESCE(m.token_reasoning, '0') AS INTEGER)), 0) as reasoning_tokens,
            COALESCE(SUM(m.cache_read), 0) as cache_read,
            COALESCE(SUM(m.cache_write), 0) as cache_write,
            COALESCE(SUM(m.completed_at - m.created_at), 0) as duration_ms,
            COALESCE(SUM(m.cost), 0) as cost,
            COALESCE(
                SUM(COALESCE(m.summary_total_additions, 0) - COALESCE(m.summary_total_deletions, 0)),
                0
            ) as net_code_lines,
            COALESCE(SUM(COALESCE(m.summary_file_count, 0)), 0) as file_count,
            MAX(m.created_at) as last_created_at_ms
        FROM messages m
        LEFT JOIN sessions s ON m.session_id = s.session_id
        WHERE m.created_at >= ? AND m.created_at < ?
        GROUP BY
            (m.created_at / 86400000) * 86400000,
            COALESCE(s.project_name, '未知项目'),
            COALESCE(m.provider_id, 'unknown'),
            COALESCE(m.model_id, 'unknown'),
            COALESCE(m.role, 'unknown'),
            COALESCE(m.agent, 'unknown'),
            COALESCE(m.tool_id, 'opencode')
        ON CONFLICT(time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id) DO UPDATE SET
            session_count = excluded.session_count,
            message_count = excluded.message_count,
            input_tokens = excluded.input_tokens,
            output_tokens = excluded.output_tokens,
            reasoning_tokens = excluded.reasoning_tokens,
            cache_read = excluded.cache_read,
            cache_write = excluded.cache_write,
            duration_ms = excluded.duration_ms,
            cost = excluded.cost,
            net_code_lines = excluded.net_code_lines,
            file_count = excluded.file_count,
            last_created_at_ms = excluded.last_created_at_ms
        """

    static let monthlyAggregationSQL = """
        INSERT INTO monthly_stats (
            time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
            session_count, message_count, input_tokens, output_tokens, reasoning_tokens,
            cache_read, cache_write, duration_ms, cost, net_code_lines, file_count,
            last_created_at_ms
        )
        SELECT
            CAST(strftime('%s', datetime(m.created_at / 1000, 'unixepoch', 'start of month')) as INTEGER) * 1000 as time_bucket_ms,
            COALESCE(s.project_name, '未知项目') as project_id,
            COALESCE(m.provider_id, 'unknown') as provider_id,
            COALESCE(m.model_id, 'unknown') as model_id,
            COALESCE(m.role, 'unknown') as role,
            COALESCE(m.agent, 'unknown') as agent,
            COALESCE(m.tool_id, 'opencode') as tool_id,
            COUNT(DISTINCT m.session_id) as session_count,
            COUNT(*) as message_count,
            COALESCE(SUM(CAST(COALESCE(m.token_input, '0') AS INTEGER)), 0) as input_tokens,
            COALESCE(SUM(CAST(COALESCE(m.token_output, '0') AS INTEGER)), 0) as output_tokens,
            COALESCE(SUM(CAST(COALESCE(m.token_reasoning, '0') AS INTEGER)), 0) as reasoning_tokens,
            COALESCE(SUM(m.cache_read), 0) as cache_read,
            COALESCE(SUM(m.cache_write), 0) as cache_write,
            COALESCE(SUM(m.completed_at - m.created_at), 0) as duration_ms,
            COALESCE(SUM(m.cost), 0) as cost,
            COALESCE(
                SUM(COALESCE(m.summary_total_additions, 0) - COALESCE(m.summary_total_deletions, 0)),
                0
            ) as net_code_lines,
            COALESCE(SUM(COALESCE(m.summary_file_count, 0)), 0) as file_count,
            MAX(m.created_at) as last_created_at_ms
        FROM messages m
        LEFT JOIN sessions s ON m.session_id = s.session_id
        WHERE m.created_at >= ? AND m.created_at < ?
        GROUP BY
            CAST(strftime('%s', datetime(m.created_at / 1000, 'unixepoch', 'start of month')) as INTEGER) * 1000,
            COALESCE(s.project_name, '未知项目'),
            COALESCE(m.provider_id, 'unknown'),
            COALESCE(m.model_id, 'unknown'),
            COALESCE(m.role, 'unknown'),
            COALESCE(m.agent, 'unknown'),
            COALESCE(m.tool_id, 'opencode')
        ON CONFLICT(time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id) DO UPDATE SET
            session_count = excluded.session_count,
            message_count = excluded.message_count,
            input_tokens = excluded.input_tokens,
            output_tokens = excluded.output_tokens,
            reasoning_tokens = excluded.reasoning_tokens,
            cache_read = excluded.cache_read,
            cache_write = excluded.cache_write,
            duration_ms = excluded.duration_ms,
            cost = excluded.cost,
            net_code_lines = excluded.net_code_lines,
            file_count = excluded.file_count,
            last_created_at_ms = excluded.last_created_at_ms
        """
}
