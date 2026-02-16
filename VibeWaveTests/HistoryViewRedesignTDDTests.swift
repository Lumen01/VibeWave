import XCTest
@testable import VibeWave
import GRDB
import Combine

/// TDD tests for HistoryView redesign
/// These tests define expected behavior BEFORE implementation
/// Tests should FAIL initially (Red phase) until implementation is complete
final class HistoryViewRedesignTDDTests: XCTestCase {
    var dbPool: DatabasePool!
    var viewModel: HistoryViewModel!
    var repository: StatisticsRepository!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        // Create temporary file to support WAL mode ( :memory: does not support WAL )
        let tempDir = NSTemporaryDirectory()
        tempDBPath = tempDir + "test-db-\(UUID().uuidString).db"
        dbPool = try! DatabasePool(path: tempDBPath)

        try! setupTestDatabase()
        viewModel = HistoryViewModel(dbPool: dbPool)
        repository = StatisticsRepository(dbPool: dbPool)
    }

    override func tearDown() {
        viewModel = nil
        repository = nil
        try? dbPool.close()
        dbPool = nil
        // Clean up temp database file
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
                    cost REAL DEFAULT 0
                )
            """)

            // Insert test data for last 7 days
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date()).timeIntervalSince1970

            for day in 0..<7 {
                let dayTimestamp = startOfDay - Double(day * 86400)
                for hour in 0..<24 {
                    let timestamp = dayTimestamp + Double(hour) * 3600
                    try db.execute(sql: """
                        INSERT INTO messages (id, session_id, created_at, token_input, token_output, token_reasoning, cost)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        "msg-\(day)-\(hour)", "session-\(day)", timestamp, 100 + day * 10, 50 + day * 5, 10 + day, 0.01 * Double(day + 1)
                    ])
                }
            }
        }
    }

    // MARK: - ViewModel Tests

    /// Test 1: Verify ViewModel exposes the three primary chart data sources
    func testViewModel_HasThreeDataProperties() {
        // Compile-time existence check + basic default state sanity checks.
        XCTAssertTrue(viewModel.messageTrend.isEmpty)
        XCTAssertTrue(viewModel.tokenDivergingData.isEmpty)
        XCTAssertTrue(viewModel.dualAxisData.isEmpty)
    }

    /// Test 2: Verify MetricType remains available and ViewModel keeps a selectedMetric for compatibility
    func testViewModel_HasSelectedMetric() {
        // The current implementation still keeps MetricType and a selectedMetric.
        // Even if HistoryView doesn't expose a selector, the ViewModel supports metric-based queries.
        XCTAssertEqual(viewModel.selectedMetric, .messages, "Default selectedMetric should be .messages")

        // Verify MetricType enum still exists and remains stable.
        let metricTypeCases = MetricType.allCases
        XCTAssertEqual(metricTypeCases.count, 4, "MetricType enum should still have 4 cases: messages, tokens, cost, sessions")
    }

    // MARK: - Repository Tests

    /// Test 3: Verify repository method getTokenDivergingData exists and returns data
    func testRepository_getTokenDivergingData() {
        let timeRange: StatisticsRepository.TimeRange = .last7Days
        let granularity: TimeGranularity = .daily

        // This method should exist and return token diverging data
        let result = repository.getTokenDivergingData(timeRange: timeRange, granularity: granularity)

        XCTAssertFalse(result.isEmpty, "getTokenDivergingData should return non-empty array")

        // Verify data structure
        if let firstPoint = result.first {
            XCTAssertNotNil(firstPoint.timestamp, "Each data point should have timestamp")
            XCTAssertNotNil(firstPoint.label, "Each data point should have label")
            XCTAssertNotNil(firstPoint.inputTokens, "Each data point should have inputTokens")
            XCTAssertNotNil(firstPoint.outputTokens, "Each data point should have outputTokens")
        }

        // Verify we have 7 days of data
        XCTAssertEqual(result.count, 7, "Should return 7 days of token diverging data for last7Days")
    }

    /// Test 4: Verify repository method getMessagesSessionsData exists
    func testRepository_getMessagesSessionsData() {
        let timeRange: StatisticsRepository.TimeRange = .last7Days
        let granularity: TimeGranularity = .daily

        // This method should return dual-axis data (messages and sessions)
        // For now, we verify getDualAxisData exists and can be used
        let result = repository.getDualAxisData(timeRange: timeRange, granularity: granularity)

        XCTAssertFalse(result.isEmpty, "getDualAxisData should return non-empty array")

        // Verify data structure
        if let firstPoint = result.first {
            XCTAssertNotNil(firstPoint.timestamp, "Each data point should have timestamp")
            XCTAssertNotNil(firstPoint.label, "Each data point should have label")
            XCTAssertNotNil(firstPoint.messages, "Each data point should have messages count")
            XCTAssertNotNil(firstPoint.sessions, "Each data point should have sessions count")
        }

        // Verify we have 7 days of data
        XCTAssertEqual(result.count, 7, "Should return 7 days of messages/sessions data for last7Days")
    }

    /// Test 5: Verify repository method getCostData exists
    func testRepository_getCostData() {
        let timeRange: StatisticsRepository.TimeRange = .last7Days
        let granularity: TimeGranularity = .daily
        let metricType: MetricType = .cost

        // Cost data is retrieved via getTrendData with metricType = .cost
        let result = repository.getTrendData(timeRange: timeRange, metric: metricType, granularity: granularity)

        XCTAssertFalse(result.isEmpty, "getTrendData with .cost metric should return non-empty array")

        // Verify data structure
        if let firstPoint = result.first {
            XCTAssertNotNil(firstPoint.timestamp, "Each data point should have timestamp")
            XCTAssertNotNil(firstPoint.label, "Each data point should have label")
            XCTAssertNotNil(firstPoint.value, "Each data point should have value (cost)")
            XCTAssertEqual(firstPoint.metricType, .cost, "Metric type should be cost")
        }

        // Verify we have 7 days of data
        XCTAssertEqual(result.count, 7, "Should return 7 days of cost data for last7Days")
    }
}
