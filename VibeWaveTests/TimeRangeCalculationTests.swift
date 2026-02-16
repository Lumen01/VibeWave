import XCTest
@testable import VibeWave
import GRDB

/// 测试 StatisticsRepository.getTimestamps(for:) 方法使用本地时区
/// 
/// 问题背景：
/// getTimestamps 方法目前使用 UTC 时区计算时间戳，导致"今日"查询范围错误。
/// 预期行为：使用本地时区计算时间范围。
final class TimeRangeCalculationTests: XCTestCase {
    var dbPool: DatabasePool!
    var repository: StatisticsRepository!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        // 创建临时文件数据库以支持 WAL 模式（:memory: 不支持 WAL）
        let tempDir = NSTemporaryDirectory()
        tempDBPath = tempDir + "test-timerange-\(UUID().uuidString).db"
        dbPool = try! DatabasePool(path: tempDBPath)

        try! setupTestDatabase()
        repository = StatisticsRepository(dbPool: dbPool)
    }

    override func tearDown() {
        repository = nil
        try? dbPool.close()
        dbPool = nil
        // 清理临时数据库文件
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
                    token_input INTEGER DEFAULT 0,
                    token_output INTEGER DEFAULT 0,
                    token_reasoning INTEGER DEFAULT 0,
                    cost REAL DEFAULT 0,
                    project_root TEXT,
                    provider_id TEXT,
                    model_id TEXT,
                    summary_total_additions INTEGER DEFAULT 0,
                    summary_total_deletions INTEGER DEFAULT 0,
                    summary_file_count INTEGER DEFAULT 0,
                    cache_read INTEGER DEFAULT 0,
                    cache_write INTEGER DEFAULT 0
                )
            """)

            // 插入一些测试数据
            try db.execute(sql: """
                INSERT INTO messages (id, session_id, created_at, token_input, token_output, cost)
                VALUES ('test-msg-1', 'test-session-1', ?, 100, 50, 0.01)
            """, arguments: [Date().timeIntervalSince1970])
        }
    }

    // MARK: - 测试方法

    /// 测试目标：验证 getTimestamps(for: .today) 使用本地时区
    /// 
    /// 预期行为：
    /// - 返回的时间戳应该对应本地时区的今天
    /// - 不应该使用 UTC 时区
    func testTodayTimeRange_UsesLocalTimezone() {
        // 准备测试数据：在本地时区的今天 12:00 插入一条消息
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current  // 使用本地时区

        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let midday = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!

        // 插入测试数据
        try! dbPool.write { db in
            try db.execute(sql: """
                INSERT INTO messages (id, session_id, created_at, token_input, token_output, cost)
                VALUES ('test-msg-today', 'test-session', ?, 100, 50, 0.01)
            """, arguments: [midday.timeIntervalSince1970])
        }

        // 调用 getOverviewStats 查询今日数据（间接测试 getTimestamps）
        let stats = repository.getOverviewStats(timeRange: .today)

        // 验证：应该返回 2 条消息（setUp 中 1 条 + 刚插入的 1 条）
        // 如果使用 UTC 时区，且当前时区和 UTC 有时差，则可能只返回部分消息
        XCTAssertEqual(stats.totalMessages, 2,
                      "应该查询到本地时区今天的所有消息")

        // 验证：返回的消息数大于 0
        XCTAssertGreaterThan(stats.totalMessages, 0,
                             "今日时间范围应该包含本地时区今天的消息")
    }

    /// 测试目标：验证 getTimestamps(for: .today) 返回的开始时间是今天 00:00:00（本地时间）
    /// 
    /// 预期行为：
    /// - start 应该是本地时区的今天 00:00:00
    /// - 不是 UTC 的 00:00:00
    func testTodayTimeRange_StartOfDay() {
        // 准备测试数据：在本地时区的今天 00:01 插入一条消息
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current  // 使用本地时区

        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let oneMinuteAfterStart = calendar.date(byAdding: .minute, value: 1, to: startOfDay)!

        // 插入测试数据
        try! dbPool.write { db in
            try db.execute(sql: """
                INSERT INTO messages (id, session_id, created_at, token_input, token_output, cost)
                VALUES ('test-msg-00:01', 'test-session', ?, 100, 50, 0.01)
            """, arguments: [oneMinuteAfterStart.timeIntervalSince1970])
        }

        // 调用 getOverviewStats 查询今日数据
        let stats = repository.getOverviewStats(timeRange: .today)

        // 验证：应该包含 00:01 的消息
        XCTAssertEqual(stats.totalMessages, 2,
                      "时间范围应该从本地时区的今天 00:00:00 开始")

        // 额外验证：检查返回的消息数至少为 1
        XCTAssertGreaterThanOrEqual(stats.totalMessages, 1,
                                   "应该至少包含一条消息")
    }

    /// 测试目标：验证 getTimestamps(for: .today) 返回的结束时间是明天 00:00:00（本地时间）
    /// 
    /// 预期行为：
    /// - end 应该是本地时区的明天 00:00:00
    /// - 不是今天 23:59:59
    func testTodayTimeRange_EndOfDay() {
        // 准备测试数据：在本地时区的今天 23:59 插入一条消息
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current  // 使用本地时区

        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let oneMinuteBeforeTomorrow = calendar.date(byAdding: .second, value: 86399, to: startOfDay)!

        // 插入测试数据
        try! dbPool.write { db in
            try db.execute(sql: """
                INSERT INTO messages (id, session_id, created_at, token_input, token_output, cost)
                VALUES ('test-msg-23:59', 'test-session', ?, 100, 50, 0.01)
            """, arguments: [oneMinuteBeforeTomorrow.timeIntervalSince1970])
        }

        // 调用 getOverviewStats 查询今日数据
        let stats = repository.getOverviewStats(timeRange: .today)

        // 验证：应该包含 23:59 的消息
        XCTAssertEqual(stats.totalMessages, 2,
                      "时间范围应该到本地时区的明天 00:00:00 结束")
    }

    /// 测试目标：验证 getTimestamps(for: .today) 正确处理跨午夜情况
    /// 
    /// 预期行为：
    /// - 应该区分本地时区的今天和昨天
    /// - 不应该包含昨天的消息
    func testTodayTimeRange_CrossesMidnight() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current  // 使用本地时区

        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let endOfYesterday = calendar.date(byAdding: .second, value: 86399, to: startOfYesterday)!

        // 插入昨天的消息
        try! dbPool.write { db in
            try db.execute(sql: """
                INSERT INTO messages (id, session_id, created_at, token_input, token_output, cost)
                VALUES ('test-msg-yesterday', 'test-session', ?, 100, 50, 0.01)
            """, arguments: [endOfYesterday.timeIntervalSince1970])
        }

        // 插入今天的消息
        try! dbPool.write { db in
            try db.execute(sql: """
                INSERT INTO messages (id, session_id, created_at, token_input, token_output, cost)
                VALUES ('test-msg-today', 'test-session', ?, 100, 50, 0.01)
            """, arguments: [startOfToday.timeIntervalSince1970])
        }

        // 调用 getOverviewStats 查询今日数据
        let stats = repository.getOverviewStats(timeRange: .today)

        // 验证：应该只包含今天的消息，不包含昨天的
        // setUp 中插入 1 条 + 今天 1 条 = 2 条
        // 昨天的消息不应该被计入
        XCTAssertEqual(stats.totalMessages, 2,
                      "应该只包含本地时区今天的消息，不包含昨天的")
    }
}
