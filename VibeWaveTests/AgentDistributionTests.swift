import XCTest
import GRDB
@testable import VibeWave

final class AgentDistributionTests: XCTestCase {
    private var dbPool: DatabasePool!
    private var statsRepo: StatisticsRepository!
    private var messageRepo: MessageRepository!
    private var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBFile = tempDir.appendingPathComponent("test_agent_distribution-\(UUID().uuidString).db")
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

    func testAgentSessionDistributionIncludesUser() throws {
        let df = ISO8601DateFormatter()
        let now = Date()

        let messageA = Message(
            id: "m1",
            sessionID: "s1",
            role: "assistant",
            time: MessageTime(created: df.string(from: now), completed: nil),
            parentID: nil,
            providerID: "openai",
            modelID: "gpt-4",
            agent: "AgentA",
            mode: nil,
            variant: nil,
            cwd: "/proj",
            root: "/proj",
            tokens: Tokens(input: 1, output: 1, reasoning: 0),
            cost: 0.01
        )

        let messageUser = Message(
            id: "m2",
            sessionID: "s2",
            role: "user",
            time: MessageTime(created: df.string(from: now), completed: nil),
            parentID: nil,
            providerID: "openai",
            modelID: "gpt-4",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: "/proj",
            root: "/proj",
            tokens: Tokens(input: 1, output: 1, reasoning: 0),
            cost: 0.0
        )

        let messageB = Message(
            id: "m3",
            sessionID: "s3",
            role: "assistant",
            time: MessageTime(created: df.string(from: now), completed: nil),
            parentID: nil,
            providerID: "openai",
            modelID: "gpt-4",
            agent: "AgentB",
            mode: nil,
            variant: nil,
            cwd: "/proj",
            root: "/proj",
            tokens: Tokens(input: 1, output: 1, reasoning: 0),
            cost: 0.01
        )

        let messageC = Message(
            id: "m4",
            sessionID: "s3",
            role: "assistant",
            time: MessageTime(created: df.string(from: now), completed: nil),
            parentID: nil,
            providerID: "openai",
            modelID: "gpt-4",
            agent: "AgentC",
            mode: nil,
            variant: nil,
            cwd: "/proj",
            root: "/proj",
            tokens: Tokens(input: 1, output: 1, reasoning: 0),
            cost: 0.01
        )

        try messageRepo.insert(message: messageA)
        try messageRepo.insert(message: messageUser)
        try messageRepo.insert(message: messageB)
        try messageRepo.insert(message: messageC)

        let distribution = statsRepo.getAgentSessionDistribution(timeRange: .allTime)
        let map = Dictionary(uniqueKeysWithValues: distribution.map { ($0.name, $0.sessionCount) })

        XCTAssertEqual(map["User"], 1)
        XCTAssertEqual(map["AgentA"], 1)
        XCTAssertEqual(map["AgentB"], 1)
        XCTAssertEqual(map["AgentC"], 1)
    }
}
