import XCTest
import GRDB
@testable import VibeWave

final class InsightsRepositoryTests: XCTestCase {
    private var dbPool: DatabasePool!
    private var repository: StatisticsRepository!
    private var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBFile = tempDir.appendingPathComponent("test_insights_repository-\(UUID().uuidString).db")
        tempDBPath = tempDBFile.path
        dbPool = try! DatabasePool(path: tempDBPath)
        repository = StatisticsRepository(dbPool: dbPool)
        try! MessageRepository(dbPool: dbPool).createSchemaIfNeeded()
    }

    override func tearDown() {
        repository = nil
        try? dbPool.close()
        dbPool = nil
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempDBPath = nil
        super.tearDown()
    }

    func testDailyActivityHeatmap_ReturnsFixed365PointsIncludingToday() throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try db.execute(
                sql: """
                INSERT INTO messages (
                    id, session_id, role, created_at, completed_at, provider_id, model_id,
                    token_input, token_output, token_reasoning, cache_read, cache_write, cost,
                    summary_total_additions, summary_total_deletions, summary_file_count
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "heat-today", "s-1", "user", nowMs, nowMs + 5_000,
                    "openai", "gpt-4",
                    "100", "50", "0",
                    0, 0, 0.5,
                    0, 0, 0
                ]
            )
        }

        let points = repository.getDailyActivityHeatmap(metric: .inputTokens, lastNDays: 365)

        XCTAssertEqual(points.count, 365)
        XCTAssertTrue(points.contains(where: {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            return formatter.string(from: $0.date) == currentDateLabel()
        }))
    }

    func testDailyActivityHeatmap_MetricMappingMatchesLabelMeaning() throws {
        let now = Date()
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try insertMessage(
                db: db,
                id: "heat-metric-1",
                createdAtMs: nowMs,
                providerId: "openai",
                modelId: "gpt-4",
                inputTokens: 200,
                outputTokens: 100
            )
            try db.execute(
                sql: "UPDATE messages SET cost = ? WHERE id = ?",
                arguments: [0.5, "heat-metric-1"]
            )

            try insertMessage(
                db: db,
                id: "heat-metric-2",
                createdAtMs: nowMs + 10_000,
                providerId: "openai",
                modelId: "gpt-4",
                inputTokens: 300,
                outputTokens: 120
            )
            try db.execute(
                sql: "UPDATE messages SET cost = ? WHERE id = ?",
                arguments: [0.2, "heat-metric-2"]
            )
        }

        let inputPoints = repository.getDailyActivityHeatmap(metric: .inputTokens, lastNDays: 1)
        let messagePoints = repository.getDailyActivityHeatmap(metric: .messages, lastNDays: 1)
        let costPoints = repository.getDailyActivityHeatmap(metric: .cost, lastNDays: 1)

        XCTAssertEqual(inputPoints.count, 1)
        XCTAssertEqual(messagePoints.count, 1)
        XCTAssertEqual(costPoints.count, 1)

        XCTAssertEqual(inputPoints[0].value, 500, accuracy: 0.0001, "Input Tokens 应该是 token_input 的日汇总")
        XCTAssertEqual(messagePoints[0].value, 2, accuracy: 0.0001, "消息 应该是消息条数 COUNT(*)")
        XCTAssertEqual(costPoints[0].value, 0.7, accuracy: 0.0001, "Cost 应该是 cost 的日汇总")
    }

    func testHourlyIntensity_Returns24BucketsAndRespectsWeekendFilter() throws {
        let weekdayDate = makeDate(year: 2026, month: 2, day: 10, hour: 10) // Tuesday
        let weekendDate = makeDate(year: 2026, month: 2, day: 8, hour: 10)  // Sunday

        try dbPool.write { db in
            try insertMessage(db: db, id: "weekday-msg", createdAtMs: toMs(weekdayDate), inputTokens: 200, outputTokens: 50)
            try insertMessage(db: db, id: "weekend-msg", createdAtMs: toMs(weekendDate), inputTokens: 300, outputTokens: 60)
        }

        let all = repository.getHourlyIntensity(metric: .messages, filter: .all)
        let weekdays = repository.getHourlyIntensity(metric: .messages, filter: .weekdays)
        let weekends = repository.getHourlyIntensity(metric: .messages, filter: .weekends)

        XCTAssertEqual(all.count, 24)
        XCTAssertEqual(weekdays.count, 24)
        XCTAssertEqual(weekends.count, 24)

        let hour10All = all.first(where: { $0.hour == 10 })?.value ?? 0
        let hour10Weekdays = weekdays.first(where: { $0.hour == 10 })?.value ?? 0
        let hour10Weekends = weekends.first(where: { $0.hour == 10 })?.value ?? 0

        XCTAssertEqual(hour10All, 2)
        XCTAssertEqual(hour10Weekdays, 1)
        XCTAssertEqual(hour10Weekends, 1)
    }

    func testModelLensGroupBy_UsesCorrectDimensionField() throws {
        let base = Int64(Date().timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try insertMessage(
                db: db,
                id: "lens-openai-gpt4",
                createdAtMs: base,
                providerId: "openai",
                modelId: "gpt-4",
                inputTokens: 100,
                outputTokens: 20
            )

            try insertMessage(
                db: db,
                id: "lens-anthropic-claude",
                createdAtMs: base + 1_000,
                providerId: "anthropic",
                modelId: "claude-3-5-sonnet",
                inputTokens: 200,
                outputTokens: 30
            )
        }

        let modelPoints = repository.getModelLensStats(groupBy: .model, metric: .inputTokens)
        let providerPoints = repository.getModelLensStats(groupBy: .provider, metric: .inputTokens)

        let modelNames = Set(modelPoints.map(\.dimensionName))
        let providerNames = Set(providerPoints.map(\.dimensionName))

        XCTAssertTrue(modelNames.contains("gpt-4"))
        XCTAssertTrue(modelNames.contains("claude-3-5-sonnet"))
        XCTAssertTrue(providerNames.contains("openai"))
        XCTAssertTrue(providerNames.contains("anthropic"))
    }

    func testModelLensRows_ProvidesInputAndTPSFromMonthlyStats() throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try DatabaseRepository.createAggregationTables(on: db)
            try db.execute(
                sql: """
                INSERT INTO monthly_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    message_count, input_tokens, output_tokens, duration_ms, cost
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    nowMs,
                    "p-1",
                    "openai",
                    "gpt-4",
                    "assistant",
                    "unknown",
                    "opencode",
                    3,
                    1234,
                    600,
                    3_000,
                    0.6
                ]
            )
        }

        let rows = repository.getModelLensRows(groupBy: .model)
        guard let gpt4 = rows.first(where: { $0.dimensionName == "gpt-4" }) else {
            return XCTFail("Expected gpt-4 row in model lens rows")
        }

        XCTAssertEqual(gpt4.inputTokens, 1234, accuracy: 0.0001)
        XCTAssertEqual(gpt4.outputTPS, 200, accuracy: 0.0001)
        XCTAssertEqual(gpt4.providerId, "openai")
    }

    func testModelLensRows_GroupByProviderAggregatesAcrossModels() throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try DatabaseRepository.createAggregationTables(on: db)

            try db.execute(
                sql: """
                INSERT INTO monthly_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    message_count, input_tokens, output_tokens, duration_ms, cost
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [nowMs, "p-1", "openai", "gpt-4", "assistant", "unknown", "opencode", 3, 100, 300, 3_000, 0.3]
            )

            try db.execute(
                sql: """
                INSERT INTO monthly_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    message_count, input_tokens, output_tokens, duration_ms, cost
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [nowMs + 1, "p-1", "openai", "gpt-4.1", "assistant", "unknown", "opencode", 3, 200, 300, 3_000, 0.3]
            )
        }

        let rows = repository.getModelLensRows(groupBy: .provider)
        guard let openai = rows.first(where: { $0.dimensionName == "openai" }) else {
            return XCTFail("Expected openai row in provider lens rows")
        }

        XCTAssertEqual(openai.inputTokens, 300, accuracy: 0.0001)
        XCTAssertEqual(openai.outputTPS, 100, accuracy: 0.0001)
    }

    func testInsightsQueries_ReadFromAggregatedTablesWhenAvailable() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        let todayStart = calendar.startOfDay(for: Date())
        let todayMs = Int64(todayStart.timeIntervalSince1970 * 1000)
        let hour10 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: todayStart) ?? todayStart
        let hour10Ms = Int64(hour10.timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try DatabaseRepository.createAggregationTables(on: db)

            try db.execute(
                sql: """
                INSERT INTO daily_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    message_count, input_tokens, cost
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    todayMs,
                    "p-1",
                    "openai",
                    "gpt-4",
                    "assistant",
                    "unknown",
                    "opencode",
                    9,
                    900,
                    1.5
                ]
            )

            try db.execute(
                sql: """
                INSERT INTO hourly_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    message_count, input_tokens, cost
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    hour10Ms,
                    "p-1",
                    "openai",
                    "gpt-4",
                    "assistant",
                    "unknown",
                    "opencode",
                    4,
                    400,
                    0.4
                ]
            )
        }

        let heatmap = repository.getDailyActivityHeatmap(metric: .messages, lastNDays: 1)
        XCTAssertEqual(heatmap.count, 1)
        XCTAssertEqual(heatmap[0].value, 9, accuracy: 0.0001)

        let weekdayWeekend = repository.getWeekdayWeekendIntensity(metric: .messages, filter: .all)
        XCTAssertEqual(weekdayWeekend.weekdayTotal + weekdayWeekend.weekendTotal, 9, accuracy: 0.0001)

        let hourly = repository.getHourlyIntensity(metric: .messages, filter: .all)
        XCTAssertEqual(hourly.first(where: { $0.hour == 10 })?.value ?? 0, 4, accuracy: 0.0001)

        let modelLens = repository.getModelLensStats(groupBy: .model, metric: .inputTokens)
        guard let gpt4 = modelLens.first(where: { $0.dimensionName == "gpt-4" }) else {
            return XCTFail("Expected gpt-4 in model lens points")
        }
        XCTAssertEqual(gpt4.value, 900, accuracy: 0.0001)
    }

    func testDailyActivityHeatmap_FallsBackToMessagesWhenDailyStatsHasNoRangeCoverage() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        let now = Date()
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let staleDay = calendar.date(byAdding: .day, value: -500, to: now) ?? now
        let staleDayStart = calendar.startOfDay(for: staleDay)
        let staleDayMs = Int64(staleDayStart.timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try DatabaseRepository.createAggregationTables(on: db)

            // Keep daily_stats non-empty but outside requested heatmap range.
            try db.execute(
                sql: """
                INSERT INTO daily_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    message_count, input_tokens, cost
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    staleDayMs,
                    "p-stale",
                    "openai",
                    "gpt-4",
                    "assistant",
                    "unknown",
                    "opencode",
                    7,
                    777,
                    0.7
                ]
            )

            try insertMessage(
                db: db,
                id: "heat-fallback-msg",
                createdAtMs: nowMs,
                providerId: "openai",
                modelId: "gpt-4",
                inputTokens: 321,
                outputTokens: 123
            )
        }

        let points = repository.getDailyActivityHeatmap(metric: .inputTokens, lastNDays: 1)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 321, accuracy: 0.0001)
    }

    func testModelLensInputTokens_UsesMonthlyStatsWhenAvailable() throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try DatabaseRepository.createAggregationTables(on: db)

            try db.execute(
                sql: """
                INSERT INTO monthly_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    message_count, input_tokens, cost
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    nowMs,
                    "p-1",
                    "openai",
                    "gpt-4",
                    "assistant",
                    "unknown",
                    "opencode",
                    3,
                    1234,
                    0.6
                ]
            )
        }

        let modelLens = repository.getModelLensStats(groupBy: .model, metric: .inputTokens)
        guard let gpt4 = modelLens.first(where: { $0.dimensionName == "gpt-4" }) else {
            return XCTFail("Expected gpt-4 in model lens points")
        }
        XCTAssertEqual(gpt4.value, 1234, accuracy: 0.0001)
    }

    func testModelLensOutputTPS_UsesMonthlyStatsWhenAvailable() throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try DatabaseRepository.createAggregationTables(on: db)

            try db.execute(
                sql: """
                INSERT INTO monthly_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    message_count, input_tokens, output_tokens, duration_ms, cost
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    nowMs,
                    "p-1",
                    "openai",
                    "gpt-4",
                    "assistant",
                    "unknown",
                    "opencode",
                    3,
                    100,
                    600,
                    3_000,
                    0.6
                ]
            )
        }

        let points = repository.getModelLensStats(groupBy: .model, metric: .outputTPS)
        guard let gpt4 = points.first(where: { $0.dimensionName == "gpt-4" }) else {
            return XCTFail("Expected gpt-4 in output tps points")
        }
        XCTAssertEqual(gpt4.value, 200, accuracy: 0.0001)
    }

    func testModelLensOutputTps_ComputesUsingValidDurationsAndCoverage() throws {
        let base = Int64(Date().timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            // Valid duration: 2s, output=100
            try insertMessage(
                db: db,
                id: "tps-valid-1",
                createdAtMs: base,
                completedAtMs: base + 2_000,
                providerId: "openai",
                modelId: "gpt-4",
                inputTokens: 50,
                outputTokens: 100
            )

            // Valid duration: 3s, output=150
            try insertMessage(
                db: db,
                id: "tps-valid-2",
                createdAtMs: base + 5_000,
                completedAtMs: base + 8_000,
                providerId: "openai",
                modelId: "gpt-4",
                inputTokens: 60,
                outputTokens: 150
            )

            // Invalid duration: no completed_at
            try insertMessage(
                db: db,
                id: "tps-invalid",
                createdAtMs: base + 10_000,
                completedAtMs: nil,
                providerId: "openai",
                modelId: "gpt-4",
                inputTokens: 70,
                outputTokens: 70
            )
        }

        let points = repository.getModelLensStats(groupBy: .model, metric: .outputTPS)
        guard let gpt4 = points.first(where: { $0.dimensionName == "gpt-4" }) else {
            return XCTFail("Expected gpt-4 point")
        }

        // TPS = (100 + 150 + 70) / (2 + 3) = 64
        XCTAssertEqual(gpt4.value, 64.0, accuracy: 0.0001)
        XCTAssertEqual(gpt4.validDurationMessageRatio, 2.0 / 3.0, accuracy: 0.0001)
    }

    private func insertMessage(
        db: Database,
        id: String,
        createdAtMs: Int64,
        completedAtMs: Int64? = nil,
        providerId: String = "openai",
        modelId: String = "gpt-4",
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
                completedAtMs,
                providerId,
                modelId,
                String(inputTokens),
                String(outputTokens),
                "0",
                0,
                0,
                0.0,
                0,
                0,
                0
            ]
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func toMs(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    private func currentDateLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
