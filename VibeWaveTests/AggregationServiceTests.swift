import XCTest
import GRDB
@testable import VibeWave

final class AggregationServiceTests: XCTestCase {
    private var dbPool: DatabasePool!
    private var tempDbPath: String!
    private var aggregationService: AggregationService!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        let dbName = "vibewave-aggregation-test-\(UUID().uuidString).db"
        tempDbPath = tempDir.appendingPathComponent(dbName).path

        dbPool = try! DatabasePool(path: tempDbPath)
        try! dbPool.write { db in
            try DatabaseRepository.createTables(on: db)
        }

        aggregationService = AggregationService(dbPool: dbPool)
    }

    override func tearDown() {
        if let path = tempDbPath {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: path + "-wal")
            try? FileManager.default.removeItem(atPath: path + "-shm")
        }
        dbPool = nil
        aggregationService = nil
        super.tearDown()
    }

    func testCalculateHourlyBucket() {
        let timestamp = Int64(1705314645000)
        let bucket = AggregationService.calculateHourlyBucket(timestampMs: timestamp)

        let expectedBucket = Int64(1705312800000)
        XCTAssertEqual(bucket, expectedBucket)
    }

    func testCalculateDailyBucket() {
        let timestamp = Int64(1705314645000)
        let bucket = AggregationService.calculateDailyBucket(timestampMs: timestamp)

        let expectedBucket = Int64(1705276800000)
        XCTAssertEqual(bucket, expectedBucket)
    }

    func testCalculateMonthlyBucket() {
        let timestamp = Int64(1705314645000)
        let bucket = AggregationService.calculateMonthlyBucket(timestampMs: timestamp)

        let expectedBucket = Int64(1704067200000)
        XCTAssertEqual(bucket, expectedBucket)
    }

    func testHourlyBucketEdgeCases() {
        let hourStart = Int64(1705312800000)
        let hourEnd = Int64(1705316399000)

        XCTAssertEqual(
            AggregationService.calculateHourlyBucket(timestampMs: hourStart),
            Int64(1705312800000)
        )
        XCTAssertEqual(
            AggregationService.calculateHourlyBucket(timestampMs: hourEnd),
            Int64(1705312800000)
        )
    }

    func testTimeGranularityEnum() {
        XCTAssertEqual(TimeGranularity.hourly.tableName, "hourly_stats")
        XCTAssertEqual(TimeGranularity.daily.tableName, "daily_stats")
        XCTAssertEqual(TimeGranularity.monthly.tableName, "monthly_stats")
        XCTAssertEqual(TimeGranularity.weekly.tableName, "weekly_stats")

        XCTAssertEqual(TimeGranularity.hourly.bucketIntervalMs, 3600000)
        XCTAssertEqual(TimeGranularity.daily.bucketIntervalMs, 86400000)
        XCTAssertEqual(TimeGranularity.weekly.bucketIntervalMs, 604800000)
        XCTAssertEqual(TimeGranularity.monthly.bucketIntervalMs, 2592000000)
    }

    func testRebuildAllAggregations_WhenBucketsCrossBatchBoundary_DoesNotLoseTokens() throws {
        let sessionId = "boundary-session"
        try insertMessage(
            id: "m0",
            sessionId: sessionId,
            createdAtMs: timestampMs(year: 2026, month: 1, day: 1, hour: 16, minute: 30),
            inputTokens: 50
        )
        try insertMessage(
            id: "m1",
            sessionId: sessionId,
            createdAtMs: timestampMs(year: 2026, month: 1, day: 2, hour: 16, minute: 10),
            inputTokens: 100
        )
        try insertMessage(
            id: "m2",
            sessionId: sessionId,
            createdAtMs: timestampMs(year: 2026, month: 1, day: 2, hour: 16, minute: 40),
            inputTokens: 200
        )

        try aggregationService.rebuildAllAggregations()

        let expected = try sumMessageInputTokens()
        XCTAssertEqual(expected, 350)
        XCTAssertEqual(try sumStatInputTokens(from: "hourly_stats"), expected)
        XCTAssertEqual(try sumStatInputTokens(from: "daily_stats"), expected)
        XCTAssertEqual(try sumStatInputTokens(from: "monthly_stats"), expected)
    }

    func testRecalculateAffectedAggregations_WhenSessionSpansMonths_RebuildsAllMonths() throws {
        let sessionId = "cross-month-session"
        try insertMessage(
            id: "jan-msg",
            sessionId: sessionId,
            createdAtMs: timestampMs(year: 2026, month: 1, day: 15, hour: 12),
            inputTokens: 100
        )
        try insertMessage(
            id: "feb-msg",
            sessionId: sessionId,
            createdAtMs: timestampMs(year: 2026, month: 2, day: 15, hour: 12),
            inputTokens: 200
        )

        try aggregationService.recalculateAffectedAggregations(for: [sessionId])

        XCTAssertEqual(try sumMessageInputTokens(), 300)
        XCTAssertEqual(try sumStatInputTokens(from: "monthly_stats"), 300)
    }

    func testRebuildAllAggregations_NetCodeLinesAndFileCount_UsesMessageLevelSums() throws {
        let sessionId = "summary-session"
        let createdAt = timestampMs(year: 2026, month: 2, day: 12, hour: 1)

        try dbPool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO messages (
                        id, session_id, role, created_at,
                        token_input, token_output, token_reasoning,
                        cache_read, cache_write, cost,
                        summary_total_additions, summary_total_deletions, summary_file_count,
                        tool_id
                    )
                    VALUES
                    ('sum-1', ?, 'assistant', ?, '10', '0', '0', 0, 0, 0.0, 8, 3, 2, 'opencode'),
                    ('sum-2', ?, 'assistant', ?, '20', '0', '0', 0, 0, 0.0, 5, 1, 1, 'opencode')
                    """,
                arguments: [sessionId, createdAt, sessionId, createdAt + 60_000]
            )
        }

        // Ensure sessions table is populated so current join path is exercised.
        try SessionService(dbPool: dbPool).rebuildAllSessions()
        try aggregationService.rebuildAllAggregations()

        let expectedNet = try sumMessageNetCodeLines()
        let expectedFiles = try sumMessageFileCount()
        XCTAssertEqual(expectedNet, 9)
        XCTAssertEqual(expectedFiles, 3)

        XCTAssertEqual(try sumStatMetric(from: "hourly_stats", column: "net_code_lines"), expectedNet)
        XCTAssertEqual(try sumStatMetric(from: "daily_stats", column: "net_code_lines"), expectedNet)
        XCTAssertEqual(try sumStatMetric(from: "monthly_stats", column: "net_code_lines"), expectedNet)

        XCTAssertEqual(try sumStatMetric(from: "hourly_stats", column: "file_count"), expectedFiles)
        XCTAssertEqual(try sumStatMetric(from: "daily_stats", column: "file_count"), expectedFiles)
        XCTAssertEqual(try sumStatMetric(from: "monthly_stats", column: "file_count"), expectedFiles)
    }

    private func insertMessage(id: String, sessionId: String, createdAtMs: Int64, inputTokens: Int) throws {
        try dbPool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO messages (
                        id, session_id, role, created_at,
                        token_input, token_output, token_reasoning,
                        cache_read, cache_write, cost, tool_id
                    )
                    VALUES (?, ?, 'assistant', ?, ?, '0', '0', 0, 0, 0.0, 'opencode')
                    """,
                arguments: [id, sessionId, createdAtMs, "\(inputTokens)"]
            )
        }
    }

    private func sumMessageInputTokens() throws -> Int64 {
        try dbPool.read { db in
            try Int64.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(CAST(COALESCE(token_input, '0') AS INTEGER)), 0) FROM messages"
            ) ?? 0
        }
    }

    private func sumStatInputTokens(from tableName: String) throws -> Int64 {
        try dbPool.read { db in
            try Int64.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(input_tokens), 0) FROM \(tableName)"
            ) ?? 0
        }
    }

    private func sumMessageNetCodeLines() throws -> Int64 {
        try dbPool.read { db in
            try Int64.fetchOne(
                db,
                sql: """
                    SELECT COALESCE(
                        SUM(COALESCE(summary_total_additions, 0) - COALESCE(summary_total_deletions, 0)),
                        0
                    )
                    FROM messages
                    """
            ) ?? 0
        }
    }

    private func sumMessageFileCount() throws -> Int64 {
        try dbPool.read { db in
            try Int64.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(COALESCE(summary_file_count, 0)), 0) FROM messages"
            ) ?? 0
        }
    }

    private func sumStatMetric(from tableName: String, column: String) throws -> Int64 {
        try dbPool.read { db in
            try Int64.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(\(column)), 0) FROM \(tableName)"
            ) ?? 0
        }
    }

    private func timestampMs(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Int64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
        return Int64(date.timeIntervalSince1970 * 1000)
    }
}
