import XCTest
import GRDB
@testable import VibeWave

final class DebugSQLTest: XCTestCase {
    func testDebug() throws {
        // DatabasePool requires WAL mode, which is not supported by :memory:
        let tempDBFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_debug_sql-\(UUID().uuidString).db")
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
        
        // Check what's in DB
        let record = messageRepo.fetch(by: "t1")
        print("Record createdAt: \(String(describing: record?.createdAt))")
        
        // Check raw value in DB
        let rawValue: Double = try dbPool.read { db in
            try Double.fetchOne(db, sql: "SELECT created_at FROM messages WHERE id = 't1'") ?? 0
        }
        print("Raw created_at in DB: \(rawValue)")
        
        // Query with Date objects
        let start = base.addingTimeInterval(-30)
        let end = base.addingTimeInterval(150)
        print("Start Date: \(start), timestamp: \(start.timeIntervalSince1970)")
        print("End Date: \(end), timestamp: \(end.timeIntervalSince1970)")
        
        // Try raw SQL with Date objects
        let count1: Int = try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE created_at >= ? AND created_at <= ?", arguments: [start, end]) ?? 0
        }
        print("Count with Date objects: \(count1)")
        
        // Try raw SQL with timestamps
        let count2: Int = try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE created_at >= ? AND created_at <= ?", arguments: [start.timeIntervalSince1970, end.timeIntervalSince1970]) ?? 0
        }
        print("Count with timestamps: \(count2)")
        
        // Try Julian day format
        let startJD = start.timeIntervalSince1970 / 86400 + 2440587.5
        let endJD = end.timeIntervalSince1970 / 86400 + 2440587.5
        let count3: Int = try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE created_at >= ? AND created_at <= ?", arguments: [startJD, endJD]) ?? 0
        }
        print("Count with Julian days: \(count3)")
        
        // With TimeInterval storage, only timestamp queries work correctly
        XCTAssertEqual(count1, 0, "Date objects no longer work - we use TimeInterval storage")
        XCTAssertEqual(count2, 1, "Timestamps should work with TimeInterval storage")
    }
}
