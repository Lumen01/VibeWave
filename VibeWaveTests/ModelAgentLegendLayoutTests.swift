import XCTest
import GRDB
@testable import VibeWave

final class ModelAgentLegendLayoutTests: XCTestCase {
    func testRows_SplitsItemsByFourPerRow() {
        let values = Array(1...10)
        let rows = ModelAgentLegendLayout.rows(values, itemsPerRow: 4)

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], [1, 2, 3, 4])
        XCTAssertEqual(rows[1], [5, 6, 7, 8])
        XCTAssertEqual(rows[2], [9, 10])
    }

    func testRows_EmptyInput_ReturnsEmptyRows() {
        let rows: [[Int]] = ModelAgentLegendLayout.rows([], itemsPerRow: 4)
        XCTAssertTrue(rows.isEmpty)
    }

    func testChartMode_HasModelAndAgentCases() {
        let modes = ModelAgentChartMode.allCases
        XCTAssertEqual(modes, [.model, .agent])
    }

    func testChartMode_DisplayTitles() {
        XCTAssertEqual(ModelAgentChartMode.model.segmentTitle, "模型贡献率")
        XCTAssertEqual(ModelAgentChartMode.agent.segmentTitle, "Agent 使用比例")
    }

    func testAutomationLevel_UsesAssistantOverUserPlusAssistant() {
        let level = StatisticsRepository.calculateAutomationLevel(assistantCount: 3, userCount: 1)
        XCTAssertEqual(level, 75.0, accuracy: 0.0001)
    }

    func testProjectModelAgentStats_AutomationLevelComesFromMonthlyStats() throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-agent-automation-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dbPool = try DatabasePool(path: dbURL.path)
        let repository = StatisticsRepository(dbPool: dbPool)

        try dbPool.write { db in
            try DatabaseRepository.createAggregationTables(on: db)

            try db.execute(
                sql: """
                    INSERT INTO monthly_stats (
                        time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                        message_count, input_tokens
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [1_736_000_000_000, "/proj", "openai", "gpt-4", "assistant", "", "opencode", 8, 1000]
            )

            try db.execute(
                sql: """
                    INSERT INTO monthly_stats (
                        time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                        message_count, input_tokens
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [1_736_000_000_000, "/proj", "openai", "gpt-4", "user", "", "opencode", 2, 0]
            )
        }

        let stats = repository.getProjectModelAgentStats(projectRoot: "/proj")
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.automationLevel ?? 0, 80.0, accuracy: 0.0001)
    }
}
