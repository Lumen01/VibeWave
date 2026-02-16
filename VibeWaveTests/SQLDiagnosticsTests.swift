import XCTest
@testable import VibeWave
import GRDB

final class SQLDiagnosticsTests: XCTestCase {
    var dbPool: DatabasePool!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = NSTemporaryDirectory()
        tempDBPath = tempDir + "sql-diag-\(UUID().uuidString).db"
        dbPool = try! DatabasePool(path: tempDBPath)
        try! setupDatabase()
    }

    override func tearDown() {
        try? dbPool.close()
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        super.tearDown()
    }

    private func setupDatabase() throws {
        try dbPool.write { db in
            try db.execute(sql: """
                CREATE TABLE messages (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    token_input TEXT,
                    token_output TEXT,
                    cost REAL DEFAULT 0
                )
            """)
            
            var calendar = Calendar.current
            calendar.timeZone = TimeZone.current
            let startOfDay = calendar.startOfDay(for: Date()).timeIntervalSince1970
            
            print("[SQL] Start of day: \(startOfDay) = \(Date(timeIntervalSince1970: startOfDay))")
            
            for hour in 0..<3 {  // Just insert 3 hours for quick test
                let timestamp = startOfDay + Double(hour) * 3600
                print("[SQL] Inserting hour \(hour) with timestamp: \(timestamp)")
                try db.execute(sql: """
                    INSERT INTO messages (id, session_id, created_at, token_input, token_output, cost)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                    "msg-\(hour)", "session-1", timestamp, "150", "75", 0.5
                ])
            }
            
            let count = try Row.fetchOne(db, sql: "SELECT COUNT(*) as cnt FROM messages")!
            print("[SQL] Total inserted: \(count["cnt"] as? Int64 ?? 0)")
            
            // Show raw data
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM messages")
            for row in rows {
                print("[SQL] Row: id=\(row["id"] as? String ?? "nil"), created_at=\(row["created_at"] as? Double ?? 0), input=\(row["token_input"] as? String ?? "nil"), output=\(row["token_output"] as? String ?? "nil")")
            }
        }
    }

    func testDirectSQLQuery() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let startOfDay = calendar.startOfDay(for: Date())
        let start = startOfDay.timeIntervalSince1970
        let end = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.timeIntervalSince1970
        
        print("[SQL] Query range: \(start) to \(end)")
        print("[SQL] Start date: \(Date(timeIntervalSince1970: start))")
        print("[SQL] End date: \(Date(timeIntervalSince1970: end))")
        
        // Direct SQL without DateFormatter filtering
        try? dbPool.read { db in
            let sql = """
                SELECT
                    strftime('%Y-%m-%d %H', created_at, 'unixepoch') as timeGroup,
                    SUM(CAST(token_input AS INTEGER)) as inputTokens,
                    SUM(CAST(token_output AS INTEGER)) as outputTokens
                FROM messages
                WHERE created_at >= ? AND created_at <= ?
                GROUP BY timeGroup
                ORDER BY timeGroup ASC
            """
            
            print("[SQL] Executing query...")
            let rows = try Row.fetchAll(db, sql: sql, arguments: [start, end])
            
            print("[SQL] Query returned \(rows.count) rows:")
            for row in rows {
                let timeGroup = row["timeGroup"] as? String ?? "nil"
                let input = row["inputTokens"] as? Double ?? -1
                let output = row["outputTokens"] as? Double ?? -1
                print("[SQL]   timeGroup=\(timeGroup), input=\(input), output=\(output)")
            }
        }
        
        // Now test Repository method
        let repository = StatisticsRepository(dbPool: dbPool)
        let data = repository.getTokenDivergingData(timeRange: .today, granularity: .hourly)
        print("[SQL] Repository returned \(data.count) data points")
        for (i, point) in data.enumerated() {
            print("[SQL] Point \(i): label=\(point.label), input=\(point.inputTokens), output=\(point.outputTokens)")
        }
        
        XCTAssertFalse(data.isEmpty, "Should return data")
        if let first = data.first {
            XCTAssertGreaterThan(first.inputTokens, 0, "Input should be > 0")
            XCTAssertGreaterThan(first.outputTokens, 0, "Output should be > 0")
        }
    }
}
