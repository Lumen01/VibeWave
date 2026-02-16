import XCTest
import GRDB
@testable import VibeWave

final class TimeDebugTests: XCTestCase {
    func testTimeStorage() throws {
        // DatabasePool requires WAL mode, which is not supported by :memory:
        let tempDBFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_time_storage-\(UUID().uuidString).db")
        let dbPool = try DatabasePool(path: tempDBFile.path)
        defer {
            try? dbPool.close()
            try? FileManager.default.removeItem(at: tempDBFile)
            try? FileManager.default.removeItem(atPath: tempDBFile.path + "-wal")
            try? FileManager.default.removeItem(atPath: tempDBFile.path + "-shm")
        }
        let messageRepo = MessageRepository(dbPool: dbPool)
        try messageRepo.createSchemaIfNeeded()
        
        // Create a message with known timestamp
        let fixedDate = Date(timeIntervalSince1970: 1737048000)
        let df = ISO8601DateFormatter()
        let timeStr = df.string(from: fixedDate)
        
        let t = MessageTime(created: timeStr, completed: nil)
        let m = Message(id: "m1", sessionID: "sess1", role: "user", time: t, parentID: nil, providerID: "openai", modelID: "gpt-4", agent: nil, mode: nil, variant: nil, cwd: "/proj", root: "/proj", tokens: Tokens(input: 100, output: 200, reasoning: 0), cost: 0.01)
        
        try messageRepo.insert(message: m)
        
        // Check what's stored in the database
        let timestamp: Double = try dbPool.read { db in
            try Double.fetchOne(db, sql: "SELECT created_at FROM messages WHERE id = 'm1'") ?? 0
        }
        
        print("Expected timestamp: \(fixedDate.timeIntervalSince1970)")
        print("Stored timestamp: \(timestamp)")
        print("Difference: \(timestamp - fixedDate.timeIntervalSince1970)")
        
        // The stored value should be close to the original
        XCTAssertEqual(timestamp, fixedDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    func testTimeQuery() throws {
        // DatabasePool requires WAL mode, which is not supported by :memory:
        let tempDBFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_time_query-\(UUID().uuidString).db")
        let dbPool = try DatabasePool(path: tempDBFile.path)
        defer {
            try? dbPool.close()
            try? FileManager.default.removeItem(at: tempDBFile)
            try? FileManager.default.removeItem(atPath: tempDBFile.path + "-wal")
            try? FileManager.default.removeItem(atPath: tempDBFile.path + "-shm")
        }
        let messageRepo = MessageRepository(dbPool: dbPool)
        try messageRepo.createSchemaIfNeeded()
        
        // Insert message at known time
        let fixedDate = Date(timeIntervalSince1970: 1737048000)
        let df = ISO8601DateFormatter()
        let t = MessageTime(created: df.string(from: fixedDate), completed: nil)
        let m = Message(id: "m1", sessionID: "sess1", role: "user", time: t, parentID: nil, providerID: "openai", modelID: "gpt-4", agent: nil, mode: nil, variant: nil, cwd: "/proj", root: "/proj", tokens: Tokens(input: 100, output: 200, reasoning: 0), cost: 0.01)
        try messageRepo.insert(message: m)
        
        // Query with time range
        let start = Date(timeIntervalSince1970: 1737000000)
        let end = Date(timeIntervalSince1970: 1737100000)
        
        // Using Date objects directly
        let count1: Int = try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE created_at >= ? AND created_at <= ?", arguments: [start.timeIntervalSince1970, end.timeIntervalSince1970]) ?? 0
        }
        print("Count with Date objects: \(count1)")
        
        // Using timestamps
        let count2: Int = try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE created_at >= ? AND created_at <= ?", arguments: [start.timeIntervalSince1970, end.timeIntervalSince1970]) ?? 0
        }
        print("Count with timestamps: \(count2)")
        
        XCTAssertEqual(count1, 1, "Date objects should work")
        XCTAssertEqual(count2, 1, "Timestamps should work")
    }
}
