import XCTest
import GRDB
@testable import VibeWave

final class StatsSQLDebugTest: XCTestCase {
    func testDirectSQL() throws {
        // DatabasePool requires WAL mode, which is not supported by :memory:
        let tempDBFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_stats_sql_debug-\(UUID().uuidString).db")
        let dbPool = try DatabasePool(path: tempDBFile.path)
        defer {
            try? dbPool.close()
            try? FileManager.default.removeItem(at: tempDBFile)
            try? FileManager.default.removeItem(atPath: tempDBFile.path + "-wal")
            try? FileManager.default.removeItem(atPath: tempDBFile.path + "-shm")
        }
        let messageRepo = MessageRepository(dbPool: dbPool)
        try messageRepo.createSchemaIfNeeded()
        
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
        
        let start = base.addingTimeInterval(-30)
        let end = base.addingTimeInterval(150)
        
        let row = try dbPool.read { db in
            try Row.fetchOne(db, sql: """
                SELECT
                    COUNT(DISTINCT session_id) as totalSessions,
                    COUNT(*) as totalMessages
                FROM messages
                WHERE created_at >= ? AND created_at <= ?
            """, arguments: [start.timeIntervalSince1970, end.timeIntervalSince1970])
        }
        
        print("Row: \(String(describing: row))")
        if let row = row {
            print("Column names: \(row.columnNames)")
            let totalSessionsIdx = row[0] as? Int ?? -1
            let totalMessagesIdx = row[1] as? Int ?? -1
            let totalSessionsName = row["totalSessions"] as? Int ?? -1
            let totalMessagesName = row["totalMessages"] as? Int ?? -1
            let totalSessions64 = row["totalSessions"] as? Int64 ?? -1
            let totalMessages64 = row["totalMessages"] as? Int64 ?? -1
            print("By index [0]: \(totalSessionsIdx)")
            print("By index [1]: \(totalMessagesIdx)")
            print("By name [\"totalSessions\"] as Int: \(totalSessionsName)")
            print("By name [\"totalMessages\"] as Int: \(totalMessagesName)")
            print("By name [\"totalSessions\"] as Int64: \(totalSessions64)")
            print("By name [\"totalMessages\"] as Int64: \(totalMessages64)")
            print("Raw value: \(row["totalSessions"])")
        }
    }
}
