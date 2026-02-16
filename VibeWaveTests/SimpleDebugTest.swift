import XCTest
import GRDB
@testable import VibeWave

final class SimpleDebugTest: XCTestCase {
    func testSimple() throws {
        // DatabasePool requires WAL mode, which is not supported by :memory:
        let tempDBFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_simple_debug-\(UUID().uuidString).db")
        let dbPool = try DatabasePool(path: tempDBFile.path)
        defer {
            try? dbPool.close()
            try? FileManager.default.removeItem(at: tempDBFile)
            try? FileManager.default.removeItem(atPath: tempDBFile.path + "-wal")
            try? FileManager.default.removeItem(atPath: tempDBFile.path + "-shm")
        }
        let messageRepo = MessageRepository(dbPool: dbPool)
        try messageRepo.createSchemaIfNeeded()
        
        // Insert
        let base = Date(timeIntervalSince1970: 1_000_000_000)
        let df = ISO8601DateFormatter()
        let m = Message(
            id: "t1", sessionID: "s", role: "user",
            time: MessageTime(created: df.string(from: base), completed: nil),
            parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil,
            cwd: nil, root: nil,
            tokens: Tokens(input: 1, output: 1, reasoning: 1),
            cost: 0.0
        )
        try messageRepo.insert(message: m)
        
        // Verify insertion
        let allRecords = messageRepo.fetchAll()
        print("All records: \(allRecords.count)")
        if let first = allRecords.first {
            print("Record ID: \(first.id)")
            print("Record createdAt: \(String(describing: first.createdAt))")
        }
        
        // Check raw timestamp in DB
        let rawTimestamp: Double = try dbPool.read { db in
            try Double.fetchOne(db, sql: "SELECT created_at FROM messages WHERE id = 't1'") ?? 0
        }
        print("Raw timestamp in DB: \(rawTimestamp)")
        
        // Check fetchAll with time range
        let start = base.addingTimeInterval(-30)
        let end = base.addingTimeInterval(150)
        print("Start timestamp: \(start.timeIntervalSince1970)")
        print("End timestamp: \(end.timeIntervalSince1970)")
        print("Base timestamp: \(base.timeIntervalSince1970)")
        
        let recs = messageRepo.fetchAll(startTimestamp: start, endTimestamp: end)
        print("Records fetched: \(recs.count)")
        XCTAssertEqual(recs.count, 1)
        
        // Check raw SQL with timestamps (not Date objects)
        let count: Int = try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE created_at >= ? AND created_at <= ?", arguments: [start.timeIntervalSince1970, end.timeIntervalSince1970]) ?? 0
        }
        print("Raw SQL count: \(count)")
        XCTAssertEqual(count, 1)
        
        // Now test StatisticsRepository
        let statsRepo = StatisticsRepository(dbPool: dbPool)
        let stats = statsRepo.getOverviewStats(timeRange: .custom(start: start, end: end))
        print("Stats: \(String(describing: stats))")
        print("Stats totalMessages: \(stats.totalMessages)")
        XCTAssertEqual(stats.totalMessages, 1)
    }
}
