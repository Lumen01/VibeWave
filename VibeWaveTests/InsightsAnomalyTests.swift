import XCTest
import GRDB
@testable import VibeWave

final class InsightsAnomalyTests: XCTestCase {
    private var dbPool: DatabasePool!
    private var statsRepo: StatisticsRepository!
    private var messageRepo: MessageRepository!
    private var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBFile = tempDir.appendingPathComponent("test_insights_anomaly-\(UUID().uuidString).db")
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

    func testAnomalyDetection() throws {
        let df = ISO8601DateFormatter()
        let now = Date()

        for dayOffset in 1...29 {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: now)!
            let message = Message(
                id: "m-\(dayOffset)",
                sessionID: "s-\(dayOffset)",
                role: "user",
                time: MessageTime(created: df.string(from: date), completed: nil),
                parentID: nil,
                providerID: "openai",
                modelID: "gpt-4",
                agent: nil,
                mode: nil,
                variant: nil,
                cwd: "/proj",
                root: "/proj",
                tokens: Tokens(input: 1, output: 1, reasoning: 0),
                cost: 0.01
            )
            try messageRepo.insert(message: message)
        }

        for i in 0..<10 {
            let message = Message(
                id: "today-\(i)",
                sessionID: "today",
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
                cost: 0.5
            )
            try messageRepo.insert(message: message)
        }

        let anomalies = statsRepo.getAnomalyStats(timeRange: .allTime)
        XCTAssertTrue(anomalies.message.isAnomaly)
        XCTAssertTrue(anomalies.cost.isAnomaly)
    }
}
