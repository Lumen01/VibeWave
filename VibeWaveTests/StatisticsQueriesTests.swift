import XCTest
import GRDB
@testable import VibeWave

final class StatisticsQueriesTests: XCTestCase {
    var dbPool: DatabasePool!
    var statsRepo: StatisticsRepository!
    var messageRepo: MessageRepository!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBFile = tempDir.appendingPathComponent("test_statistics_queries-\(UUID().uuidString).db")
        tempDBPath = tempDBFile.path
        dbPool = try! DatabasePool(path: tempDBPath)
        statsRepo = StatisticsRepository(dbPool: dbPool)
        messageRepo = MessageRepository(dbPool: dbPool)
        try! messageRepo.createSchemaIfNeeded()
    }

    override func tearDown() {
        statsRepo = nil
        messageRepo = nil
        try? dbPool.close()
        dbPool = nil
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempDBPath = nil
        super.tearDown()
    }

    func testOverviewStats() throws {
        let base = Date(timeIntervalSince1970: 1_000_000_000)
        let df = ISO8601DateFormatter()
        let t = MessageTime(created: df.string(from: base), completed: nil)
        let m = Message(id: "m1", sessionID: "sess1", role: "user", time: t, parentID: nil, providerID: "openai", modelID: "gpt-4", agent: nil, mode: nil, variant: nil, cwd: "/proj", root: "/proj", tokens: Tokens(input: 100, output: 200, reasoning: 0), cost: 0.01)
        try messageRepo.insert(message: m)

        let start = base.addingTimeInterval(-30)
        let end = base.addingTimeInterval(150)
        let stats = statsRepo.getOverviewStats(timeRange: .custom(start: start, end: end))

        XCTAssertNotNil(stats)
        XCTAssertEqual(stats.totalSessions, 1)
        XCTAssertEqual(stats.totalMessages, 1)
    }

    func testDailyStats() throws {
        let base = Date(timeIntervalSince1970: 1_000_000_000)
        let df = ISO8601DateFormatter()
        let t = MessageTime(created: df.string(from: base), completed: nil)
        let m = Message(id: "m1", sessionID: "sess1", role: "user", time: t, parentID: nil, providerID: "openai", modelID: "gpt-4", agent: nil, mode: nil, variant: nil, cwd: "/proj", root: "/proj", tokens: Tokens(input: 100, output: 200, reasoning: 0), cost: 0.01)
        try messageRepo.insert(message: m)

        let start = base.addingTimeInterval(-30)
        let end = base.addingTimeInterval(150)
        let stats = statsRepo.getDailyStats(timeRange: .custom(start: start, end: end))

        XCTAssertEqual(stats.count, 1)
    }

    func testHourlyStats() throws {
        let base = Date(timeIntervalSince1970: 1_000_000_000)
        let df = ISO8601DateFormatter()
        let t = MessageTime(created: df.string(from: base), completed: nil)
        let m = Message(id: "m1", sessionID: "sess1", role: "user", time: t, parentID: nil, providerID: "openai", modelID: "gpt-4", agent: nil, mode: nil, variant: nil, cwd: "/proj", root: "/proj", tokens: Tokens(input: 100, output: 200, reasoning: 0), cost: 0.01)
        try messageRepo.insert(message: m)

        let start = base.addingTimeInterval(-30)
        let end = base.addingTimeInterval(150)
        let stats = statsRepo.getHourlyStats(timeRange: .custom(start: start, end: end))

        XCTAssertGreaterThan(stats.count, 0)
    }

    func testProjectStats() throws {
        let base = Date(timeIntervalSince1970: 1_000_000_000)
        let df = ISO8601DateFormatter()
        let t = MessageTime(created: df.string(from: base), completed: nil)
        let m1 = Message(id: "m1", sessionID: "sess1", role: "user", time: t, parentID: nil, providerID: "openai", modelID: "gpt-4", agent: nil, mode: nil, variant: nil, cwd: "/proj1", root: "/proj1", tokens: Tokens(input: 100, output: 200, reasoning: 0), cost: 0.01)
        try messageRepo.insert(message: m1)

        let start = base.addingTimeInterval(-30)
        let end = base.addingTimeInterval(150)
        let stats = statsRepo.getProjectStats(timeRange: .custom(start: start, end: end))

        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats.first?.projectRoot, "/proj1")
    }

    func testOverviewStats_TokenSumHandlesNulls() throws {
        let base = Date(timeIntervalSince1970: 1_000_000_000)
        let df = ISO8601DateFormatter()
        let t = MessageTime(created: df.string(from: base), completed: nil)
        let m = Message(
            id: "m-null",
            sessionID: "sess-null",
            role: "user",
            time: t,
            parentID: nil,
            providerID: "openai",
            modelID: "gpt-4",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: "/proj",
            root: "/proj",
            tokens: Tokens(input: 100, output: nil, reasoning: nil),
            cost: 0.01
        )
        try messageRepo.insert(message: m)

        let start = base.addingTimeInterval(-30)
        let end = base.addingTimeInterval(150)
        let stats = statsRepo.getOverviewStats(timeRange: .custom(start: start, end: end))

        XCTAssertEqual(stats.totalTokens, 100, "Total tokens should treat nulls as zero")
        XCTAssertEqual(stats.inputTokens, 100)
        XCTAssertEqual(stats.outputTokens, 0)
        XCTAssertEqual(stats.reasoningTokens, 0)
    }

    func testOverviewKPITrends_ReturnsSevenPointsAndFillsMissingDays() throws {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let todayStart = calendar.startOfDay(for: Date())

        let todayMessageDate = calendar.date(byAdding: .hour, value: 1, to: todayStart)!
        let twoDaysAgoStart = calendar.date(byAdding: .day, value: -2, to: todayStart)!
        let twoDaysAgoMessageDate = calendar.date(byAdding: .hour, value: 2, to: twoDaysAgoStart)!

        try insertMessage(
            id: "trend-today",
            sessionID: "session-today",
            createdAt: todayMessageDate,
            input: 100,
            output: 50,
            reasoning: 25,
            cacheRead: 10,
            cacheWrite: 5,
            cost: 1.2
        )

        try insertMessage(
            id: "trend-two-days-ago",
            sessionID: "session-two-days-ago",
            createdAt: twoDaysAgoMessageDate,
            input: 200,
            output: 0,
            reasoning: 0,
            cacheRead: 20,
            cacheWrite: 10,
            cost: 2.0
        )

        let trends = statsRepo.getOverviewKPITrends(lastNDays: 7)

        XCTAssertEqual(trends.sessions.count, 7)
        XCTAssertEqual(trends.messages.count, 7)
        XCTAssertEqual(trends.inputTokens.count, 7)
        XCTAssertEqual(trends.avgTokensPerSession.count, 7)

        // Array index is oldest -> newest. today-2 is index 4, today is index 6.
        XCTAssertEqual(trends.sessions[4], 1, accuracy: 0.001)
        XCTAssertEqual(trends.inputTokens[4], 200, accuracy: 0.001)
        XCTAssertEqual(trends.avgTokensPerSession[4], 200, accuracy: 0.001)

        XCTAssertEqual(trends.sessions[6], 1, accuracy: 0.001)
        XCTAssertEqual(trends.inputTokens[6], 100, accuracy: 0.001)
        XCTAssertEqual(trends.outputTokens[6], 50, accuracy: 0.001)
        XCTAssertEqual(trends.reasoningTokens[6], 25, accuracy: 0.001)
        XCTAssertEqual(trends.cacheRead[6], 10, accuracy: 0.001)
        XCTAssertEqual(trends.cacheWrite[6], 5, accuracy: 0.001)
        XCTAssertEqual(trends.cost[6], 1.2, accuracy: 0.001)
        XCTAssertEqual(trends.avgTokensPerSession[6], 175, accuracy: 0.001)

        // A day with no data should be zero-filled.
        XCTAssertEqual(trends.messages[5], 0, accuracy: 0.001)
        XCTAssertEqual(trends.avgTokensPerSession[5], 0, accuracy: 0.001)
    }

    func testOverviewKPITrends_AvgTokensPerSessionUsesDistinctSessions() throws {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let todayStart = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .hour, value: 3, to: todayStart)!

        try insertMessage(
            id: "avg-1",
            sessionID: "session-a",
            createdAt: date,
            input: 100,
            output: 50,
            reasoning: 0,
            cacheRead: 0,
            cacheWrite: 0,
            cost: 0
        )
        try insertMessage(
            id: "avg-2",
            sessionID: "session-b",
            createdAt: date,
            input: 100,
            output: 50,
            reasoning: 0,
            cacheRead: 0,
            cacheWrite: 0,
            cost: 0
        )

        let trends = statsRepo.getOverviewKPITrends(lastNDays: 7)

        // total tokens = 300, sessions = 2 -> avg = 150
        XCTAssertEqual(trends.avgTokensPerSession.last ?? -1, 150, accuracy: 0.001)
    }

    func testProjectConsumptionStats_WithTokensButZeroNetCodeLines_ShouldReturnStats() throws {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = calendar.startOfDay(for: Date())

        let messageDate = calendar.date(byAdding: .hour, value: 3, to: todayStart)!
        try insertMessage(
            id: "proj-consumption-1",
            sessionID: "session-1",
            createdAt: messageDate,
            input: 1000,
            output: 500,
            reasoning: 250,
            cacheRead: 10,
            cacheWrite: 5,
            cost: 0.15
        )

        try dbPool.write { db in
            try db.execute(sql: """
                INSERT OR IGNORE INTO monthly_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    session_count, message_count, input_tokens, output_tokens, reasoning_tokens,
                    cache_read, cache_write, duration_ms, cost, net_code_lines, file_count,
                    last_created_at_ms
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                Int64(messageDate.timeIntervalSince1970 * 1000),
                "/test-project",
                "openai",
                "gpt-4",
                "assistant",
                "atlas",
                "opencode",
                1 as Int64,
                1 as Int64,
                1000 as Int64,
                500 as Int64,
                250 as Int64,
                10 as Int64,
                5 as Int64,
                0 as Int64,
                0.15,
                0 as Int64,
                0 as Int64,
                Int64(messageDate.timeIntervalSince1970 * 1000)
            ])
        }

        let consumptionStats = statsRepo.getProjectConsumptionStats(projectRoot: "/test-project")

        XCTAssertNotNil(consumptionStats, "getProjectConsumptionStats should return Stats when there are tokens even if net_code_lines <= 0")

        XCTAssertEqual(consumptionStats!.cost, 0.15, accuracy: 0.001)
        XCTAssertEqual(consumptionStats!.inputTokens, 1000)
        XCTAssertEqual(consumptionStats!.outputTokens, 500)
        XCTAssertEqual(consumptionStats!.reasoningTokens, 250)
        XCTAssertEqual(consumptionStats!.netCodeLines, 0, "net_code_lines should be 0, not cause nil return")
    }

    func testProjectConsumptionStats_WithTokensButNegativeNetCodeLines_ShouldReturnStats() throws {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = calendar.startOfDay(for: Date())

        let messageDate = calendar.date(byAdding: .hour, value: 3, to: todayStart)!
        try insertMessage(
            id: "proj-consumption-neg-1",
            sessionID: "session-1",
            createdAt: messageDate,
            input: 34545870,
            output: 255332,
            reasoning: 51315,
            cacheRead: 1000,
            cacheWrite: 500,
            cost: 0.0
        )

        try dbPool.write { db in
            try db.execute(sql: """
                INSERT OR IGNORE INTO monthly_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    session_count, message_count, input_tokens, output_tokens, reasoning_tokens,
                    cache_read, cache_write, duration_ms, cost, net_code_lines, file_count,
                    last_created_at_ms
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                Int64(messageDate.timeIntervalSince1970 * 1000),
                "/k8s-homelab",
                "volcengine",
                "kimi",
                "user",
                "sisyphus",
                "opencode",
                1 as Int64,
                1 as Int64,
                34545870 as Int64,
                255332 as Int64,
                51315 as Int64,
                1000 as Int64,
                500 as Int64,
                0 as Int64,
                0.0,
                -25785 as Int64,
                0 as Int64,
                Int64(messageDate.timeIntervalSince1970 * 1000)
            ])
        }

        let consumptionStats = statsRepo.getProjectConsumptionStats(projectRoot: "/k8s-homelab")

        XCTAssertNotNil(consumptionStats, "getProjectConsumptionStats should return Stats when there are tokens even if net_code_lines is negative")

        XCTAssertEqual(consumptionStats!.cost, 0.0, accuracy: 0.001)
        XCTAssertEqual(consumptionStats!.inputTokens, 34545870)
        XCTAssertEqual(consumptionStats!.outputTokens, 255332)
        XCTAssertEqual(consumptionStats!.reasoningTokens, 51315)
        XCTAssertEqual(consumptionStats!.netCodeLines, -25785, "net_code_lines should be -25785, not cause nil return")
    }

    func testProjectConsumptionStats_NoData_ShouldReturnNil() throws {
        let consumptionStats = statsRepo.getProjectConsumptionStats(projectRoot: "/non-existent-project")

        XCTAssertNil(consumptionStats, "getProjectConsumptionStats should return nil when there is no data")
    }

    private func insertMessage(
        id: String,
        sessionID: String,
        createdAt: Date,
        input: Int,
        output: Int,
        reasoning: Int,
        cacheRead: Int,
        cacheWrite: Int,
        cost: Double
    ) throws {
        let iso = ISO8601DateFormatter().string(from: createdAt)
        let message = Message(
            id: id,
            sessionID: sessionID,
            role: "assistant",
            time: MessageTime(created: iso, completed: nil),
            parentID: nil,
            providerID: "openai",
            modelID: "gpt-4",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: "/proj",
            root: "/proj",
            tokens: Tokens(input: input, output: output, reasoning: reasoning, cacheRead: cacheRead, cacheWrite: cacheWrite),
            cost: cost
        )
        try messageRepo.insert(message: message)
    }
}
