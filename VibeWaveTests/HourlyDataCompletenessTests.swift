import XCTest
@testable import VibeWave
import GRDB

final class HourlyDataCompletenessTests: XCTestCase {
    var dbPool: DatabasePool!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = NSTemporaryDirectory()
        tempDBPath = tempDir + "hourly-test-\(UUID().uuidString).db"
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
            
            // 只插入 3 个小时的数据（测试是否能补充完整的 24 小时）
            var calendar = Calendar.current
            calendar.timeZone = TimeZone.current
            let startOfDay = calendar.startOfDay(for: Date()).timeIntervalSince1970
            
            for hour in [0, 8, 16] {  // 只插入 00:00, 08:00, 16:00
                let timestamp = startOfDay + Double(hour) * 3600
                try db.execute(sql: """
                    INSERT INTO messages (id, session_id, created_at, token_input, token_output, cost)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                    "msg-\(hour)", "session-1", timestamp, "100", "50", 0.5
                ])
            }
        }
    }

    func testTokenDataReturns24Hours() {
        let repository = StatisticsRepository(dbPool: dbPool)
        let data = repository.getTokenDivergingData(timeRange: .today, granularity: .hourly)
        
        print("[24H] Token data count: \(data.count)")
        print("[24H] Expected: 24, Actual: \(data.count)")
        
        // 验证有 24 个小时
        XCTAssertEqual(data.count, 24, "Should return exactly 24 hours of data")
        
        // 验证第 0、8、16 小时有数据
        let hour0 = data[0]
        let hour8 = data[8]
        let hour16 = data[16]
        
        print("[24H] Hour 0: input=\(hour0.inputTokens), output=\(hour0.outputTokens)")
        print("[24H] Hour 8: input=\(hour8.inputTokens), output=\(hour8.outputTokens)")
        print("[24H] Hour 16: input=\(hour16.inputTokens), output=\(hour16.outputTokens)")
        
        XCTAssertGreaterThan(hour0.inputTokens, 0, "Hour 0 should have data")
        XCTAssertGreaterThan(hour8.inputTokens, 0, "Hour 8 should have data")
        XCTAssertGreaterThan(hour16.inputTokens, 0, "Hour 16 should have data")
        
        // 验证其他小时为 0
        let hour1 = data[1]
        let hour2 = data[2]
        print("[24H] Hour 1: input=\(hour1.inputTokens), output=\(hour1.outputTokens)")
        print("[24H] Hour 2: input=\(hour2.inputTokens), output=\(hour2.outputTokens)")
        
        XCTAssertEqual(hour1.inputTokens, 0, "Hour 1 should be 0 (no data)")
        XCTAssertEqual(hour2.inputTokens, 0, "Hour 2 should be 0 (no data)")
    }
}
