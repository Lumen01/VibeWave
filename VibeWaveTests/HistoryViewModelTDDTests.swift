import XCTest
@testable import VibeWave
import GRDB
import Combine

final class HistoryViewModelTDDTests: XCTestCase {
    var dbPool: DatabasePool!
    var viewModel: HistoryViewModel!
    var cancellables: Set<AnyCancellable>!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        // Create temporary file to support WAL mode ( :memory: does not support WAL )
        let tempDir = NSTemporaryDirectory()
        tempDBPath = tempDir + "test-db-\(UUID().uuidString).db"
        dbPool = try! DatabasePool(path: tempDBPath)

        try! setupTestDatabase()
        viewModel = HistoryViewModel(dbPool: dbPool)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
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

            // Insert 24 hours of data for today's stats
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date()).timeIntervalSince1970

            for hour in 0..<24 {
                let timestamp = startOfDay + Double(hour) * 3600
                try db.execute(sql: """
                    INSERT INTO messages (id, session_id, created_at, token_input, token_output, token_reasoning, cost)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    "msg-hour-\(hour)", "session-\(hour)", timestamp, 100, 50, 10, 0.01
                ])
            }

            // Insert data for last 7 days
            for day in 0..<7 {
                let dayTimestamp = startOfDay - Double(day * 86400)
                for hour in 0..<24 {
                    let timestamp = dayTimestamp + Double(hour) * 3600
                    try db.execute(sql: """
                        INSERT INTO messages (id, session_id, created_at, token_input, token_output, token_reasoning, cost)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        "msg-day-\(day)-hour-\(hour)", "session-day-\(day)", timestamp, 50, 25, 5, 0.005
                    ])
                }
            }
        }
    }

    // Test 1: Verify ViewModel initializes with correct defaults
    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false initially")
        XCTAssertEqual(viewModel.selectedTimeRange, .last24Hours, "selectedTimeRange should default to .last24Hours")
        XCTAssertEqual(viewModel.selectedMetric, .messages, "selectedMetric should default to .messages")
        XCTAssertTrue(viewModel.hourlyStats.isEmpty, "hourlyStats should be empty initially")
        XCTAssertTrue(viewModel.timeClusterStats.isEmpty, "timeClusterStats should be empty initially")
        XCTAssertTrue(viewModel.trendData.isEmpty, "trendData should be empty initially")
        XCTAssertNil(viewModel.weekdayStats, "weekdayStats should be nil initially")
    }

    // Test 2: Verify 24 hours of data loaded for today
    func testLoadTodayData_PopulatesHourlyStats() {
        let expectation = self.expectation(description: "Hourly stats populated")

        viewModel.$hourlyStats
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.loadStats()
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(viewModel.hourlyStats.count, 24, "Should populate 24 hourly stats")
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after loading")
    }

    // Test 3: Verify 4 time clusters loaded for today
    func testLoadTodayData_PopulatesTimeClusterStats() {
        let expectation = self.expectation(description: "Time cluster stats populated")

        viewModel.$timeClusterStats
            .dropFirst()
            .sink { stats in
                if stats.count == 4 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.loadStats()
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(viewModel.timeClusterStats.count, 4, "Should populate 4 time clusters")
        let clusterNames = viewModel.timeClusterStats.map { $0.cluster.rawValue }
        XCTAssertEqual(clusterNames.sorted(), ["Afternoon", "Evening", "Morning", "Night"].sorted(),
                      "Should have Morning, Afternoon, Evening, Night clusters")
    }

    // Test 4: Verify 30 days of trend data loaded
    func testLoad30DaysData_PopulatesTrendData() {
        let expectation = self.expectation(description: "Trend data populated")

        viewModel.selectedTimeRange = .last30Days

        viewModel.$trendData
            .dropFirst()
            .sink { stats in
                if !stats.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 3.0)

        XCTAssertEqual(viewModel.trendData.count, 30, "Should populate 30 days of trend data")
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after loading")
    }

    // Test 5: Verify weekday/weekend stats loaded
    func testLoad30DaysData_PopulatesWeekdayStats() {
        let expectation = self.expectation(description: "Weekday stats populated")

        viewModel.selectedTimeRange = .last30Days

        viewModel.$weekdayStats
            .dropFirst()
            .sink { stats in
                if stats != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 3.0)

        XCTAssertNotNil(viewModel.weekdayStats, "Should populate weekday/weekend stats")
        if let stats = viewModel.weekdayStats {
            XCTAssertGreaterThanOrEqual(stats.weekdayTotal + stats.weekendTotal, 0,
                                       "Should have non-zero totals")
        }
    }

    // Test 6: Verify metric change triggers reload
    func testSwitchingMetric_ReloadsData() {
        let expectation = self.expectation(description: "Metric switch triggers reload")

        var callCount = 0
        viewModel.$hourlyStats
            .dropFirst()
            .sink { _ in
                callCount += 1
                if callCount >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Initial load with .messages
        viewModel.loadStats()

        // Small delay to ensure first load completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Switch metric to .tokens, should trigger reload
            self.viewModel.selectedMetric = .tokens
        }

        wait(for: [expectation], timeout: 4.0)

        XCTAssertEqual(callCount, 2, "Should reload data twice when metric switches")
    }
}
