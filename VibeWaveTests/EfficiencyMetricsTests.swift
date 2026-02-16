import XCTest
import GRDB
@testable import VibeWave

final class EfficiencyMetricsTests: XCTestCase {
    private var dbPool: DatabasePool!
    private var statsRepo: StatisticsRepository!
    private var messageRepo: MessageRepository!
    private var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBFile = tempDir.appendingPathComponent("test_efficiency_metrics-\(UUID().uuidString).db")
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

    func testUserAgentCountsAndBillingStats() throws {
        let base = Date().timeIntervalSince1970
        try dbPool.write { db in
            try db.execute(
                sql: """
                INSERT INTO messages (id, session_id, role, created_at, provider_id, model_id, agent, token_input, token_output, token_reasoning, cache_read, cache_write, cost, summary_total_additions, summary_total_deletions, summary_file_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "m1", "s1", "user", base, "openai", "gpt-4", nil, "10", "0", "0", 0, 0, 0.0, 0, 0, 0
                ]
            )
            try db.execute(
                sql: """
                INSERT INTO messages (id, session_id, role, created_at, provider_id, model_id, agent, token_input, token_output, token_reasoning, cache_read, cache_write, cost, summary_total_additions, summary_total_deletions, summary_file_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "m2", "s1", "assistant", base + 10, "openai", "gpt-4", "AgentA", "20", "30", "0", 0, 0, 0.05, 0, 0, 0
                ]
            )
        }

        let start = Date(timeIntervalSince1970: base - 60)
        let end = Date(timeIntervalSince1970: base + 60)
        let stats = statsRepo.getUserAgentMessageCounts(timeRange: .custom(start: start, end: end))
        let userCount = stats.first(where: { $0.isUser })?.count ?? 0
        XCTAssertEqual(userCount, 1)

        let billing = statsRepo.getBillingCostStats(timeRange: .custom(start: start, end: end))
        XCTAssertEqual(billing.billedMessageCount, 1)
        XCTAssertEqual(billing.totalMessageCount, 2)
        XCTAssertEqual(billing.totalCost, 0.05, accuracy: 0.0001)
    }

    func testNetCodeOutputStats() throws {
        let base = Date()
        let df = ISO8601DateFormatter()
        let message = Message(
            id: "m3",
            sessionID: "s2",
            role: "assistant",
            time: MessageTime(created: df.string(from: base), completed: nil),
            parentID: nil,
            providerID: "openai",
            modelID: "gpt-4",
            agent: "AgentB",
            mode: nil,
            variant: nil,
            cwd: "/proj",
            root: "/proj",
            tokens: Tokens(input: 5, output: 5, reasoning: 0),
            cost: 0.01,
            summary: SessionSummary(
                title: "summary",
                diffs: [
                    SessionSummary.FileDiff(file: "a.swift", additions: 10, deletions: 4)
                ]
            )
        )
        try messageRepo.insert(message: message)

        let netStats = statsRepo.getNetCodeOutputStats(timeRange: .allTime)
        XCTAssertEqual(netStats.additions, 10)
        XCTAssertEqual(netStats.deletions, 4)
        XCTAssertEqual(netStats.net, 6)
    }
}
