import XCTest
import GRDB
@testable import VibeWave

final class ModelProcessingStatsTests: XCTestCase {
    private var dbPool: DatabasePool!
    private var statsRepo: StatisticsRepository!
    private var messageRepo: MessageRepository!
    private var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBFile = tempDir.appendingPathComponent("test_model_processing-\(UUID().uuidString).db")
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

    func testModelProcessingStats() throws {
        let base = Date()
        let df = ISO8601DateFormatter()

        let message1 = Message(
            id: "m1",
            sessionID: "s1",
            role: "assistant",
            time: MessageTime(created: df.string(from: base), completed: nil),
            parentID: nil,
            providerID: "openai",
            modelID: "gpt-4",
            agent: "AgentA",
            mode: nil,
            variant: nil,
            cwd: "/proj",
            root: "/proj",
            tokens: Tokens(input: 100, output: 50, reasoning: 10),
            cost: 0.1
        )

        let message3 = Message(
            id: "m3",
            sessionID: "s3",
            role: "assistant",
            time: MessageTime(created: df.string(from: base.addingTimeInterval(10)), completed: nil),
            parentID: nil,
            providerID: "anthropic",
            modelID: "claude-3",
            agent: "AgentB",
            mode: nil,
            variant: nil,
            cwd: "/proj",
            root: "/proj",
            tokens: Tokens(input: 200, output: 100, reasoning: 20),
            cost: 0.2
        )

        try messageRepo.insert(message: message1)
        try messageRepo.insert(message: message3)

        let stats = statsRepo.getModelProcessingStats(timeRange: .allTime)
        guard let gpt4 = stats.first(where: { $0.modelId == "gpt-4" }) else {
            return XCTFail("Expected gpt-4 stats")
        }
        XCTAssertEqual(gpt4.sessionCount, 1)
        XCTAssertEqual(gpt4.inputTokens, 100)
        XCTAssertEqual(gpt4.outputTokens, 50)
        XCTAssertEqual(gpt4.reasoningTokens, 10)
        XCTAssertEqual(gpt4.inputPerSession, 100, accuracy: 0.01)
        XCTAssertEqual(gpt4.reasoningOutputRatio, 0.2, accuracy: 0.01)
    }
}
