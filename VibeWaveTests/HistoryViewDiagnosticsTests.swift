import XCTest
@testable import VibeWave
import GRDB

/// 诊断测试：验证 HistoryView 数据流
final class HistoryViewDiagnosticsTests: XCTestCase {
    var dbPool: DatabasePool!
    var viewModel: HistoryViewModel!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = NSTemporaryDirectory()
        tempDBPath = tempDir + "diag-\(UUID().uuidString).db"
        dbPool = try! DatabasePool(path: tempDBPath)
        try! setupTestDatabase()
        viewModel = HistoryViewModel(dbPool: dbPool)
    }

    override func tearDown() {
        viewModel = nil
        try? dbPool.close()
        dbPool = nil
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempDBPath = nil
        super.tearDown()
    }

    private func setupTestDatabase() throws {
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
            
            // 插入今天的测试数据（24小时）
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "UTC")!
            let startOfDay = calendar.startOfDay(for: Date()).timeIntervalSince1970
            
            print("[DIAG] Inserting test data from: \(Date(timeIntervalSince1970: startOfDay))")
            
            for hour in 0..<24 {
                let timestamp = startOfDay + Double(hour) * 3600
                try db.execute(sql: """
                    INSERT INTO messages (id, session_id, created_at, token_input, token_output, cost)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                    "msg-today-\(hour)",
                    "session-\(hour/4)",
                    timestamp,
                    "\(100 + hour * 10)",  // TEXT as string
                    "\(50 + hour * 5)",    // TEXT as string
                    0.01 * Double(hour + 1)
                ])
            }
            
            // 验证插入
            let count = try Row.fetchOne(db, sql: "SELECT COUNT(*) as cnt FROM messages")!
            print("[DIAG] Inserted \(count["cnt"] as? Int64 ?? 0) messages")
        }
    }

    /// 测试1: 验证 Repository 直接查询返回数据
    func testRepositoryReturnsData() {
        let repository = StatisticsRepository(dbPool: dbPool)
        let timeRange: StatisticsRepository.TimeRange = .last24Hours
        
        let tokenData = repository.getTokenDivergingData(timeRange: timeRange, granularity: .hourly)
        print("[DIAG] Repository tokenData count: \(tokenData.count)")
        if let first = tokenData.first {
            print("[DIAG] First token point: label=\(first.label), input=\(first.inputTokens), output=\(first.outputTokens)")
        }
        
        let dualData = repository.getDualAxisData(timeRange: timeRange, granularity: .hourly)
        print("[DIAG] Repository dualAxisData count: \(dualData.count)")
        
        let trendData = repository.getTrendData(timeRange: timeRange, metric: .messages, granularity: .hourly)
        print("[DIAG] Repository trendData count: \(trendData.count)")
        
        // 断言
        XCTAssertFalse(tokenData.isEmpty, "Repository should return token data")
        XCTAssertFalse(dualData.isEmpty, "Repository should return dual axis data")
        XCTAssertFalse(trendData.isEmpty, "Repository should return trend data")
    }

    /// 测试2: 验证 ViewModel 加载后属性有值
    func testViewModelLoadsData() {
        print("[DIAG] Before load - tokenDivergingData: \(viewModel.tokenDivergingData.count)")
        print("[DIAG] Before load - dualAxisData: \(viewModel.dualAxisData.count)")
        print("[DIAG] Before load - trendData: \(viewModel.trendData.count)")
        
        // 设置为today并加载
        viewModel.selectedTimeRange = .today
        viewModel.loadStats()
        
        // 等待异步加载完成
        let expectation = XCTestExpectation(description: "Data loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("[DIAG] After load - tokenDivergingData: \(self.viewModel.tokenDivergingData.count)")
            print("[DIAG] After load - dualAxisData: \(self.viewModel.dualAxisData.count)")
            print("[DIAG] After load - trendData: \(self.viewModel.trendData.count)")
            print("[DIAG] isLoading: \(self.viewModel.isLoading)")
            
            XCTAssertFalse(self.viewModel.tokenDivergingData.isEmpty, "ViewModel should have token data")
            XCTAssertFalse(self.viewModel.dualAxisData.isEmpty, "ViewModel should have dual axis data")
            XCTAssertFalse(self.viewModel.trendData.isEmpty, "ViewModel should have trend data")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
