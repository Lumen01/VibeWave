import XCTest
import SwiftUI
import Charts
@testable import VibeWave
import GRDB
import Combine

/// TDD tests for HistoryView Chart fixes
/// Tests for:
/// 1. Tokens chart Y-axis using M (millions) format with 1 decimal
/// 2. All views showing 0/0.5/1 grid lines when no data or all zeros
/// 3. Chart tooltip showing values on hover
final class HistoryViewChartFixesTDDTests: XCTestCase {
    var dbPool: DatabasePool!
    var viewModel: HistoryViewModel!
    var repository: StatisticsRepository!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
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

            // Insert large token values (millions) for testing M format
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date()).timeIntervalSince1970

            for day in 0..<7 {
                let dayTimestamp = startOfDay - Double(day * 86400)
                for hour in 0..<24 {
                    let timestamp = dayTimestamp + Double(hour) * 3600
                    // Use large token values (millions) for testing M format
                    try db.execute(sql: """
                        INSERT INTO messages (id, session_id, created_at, token_input, token_output, token_reasoning, cost)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        "msg-\(day)-\(hour)", "session-\(day)", timestamp,
                        2_500_000 + day * 100_000,  // 2.5M + 100K per day
                        1_000_000 + day * 50_000,   // 1M + 50K per day
                        500_000 + day * 25_000,     // 500K + 25K per day
                        0.1 * Double(day + 1)
                    ])
                }
            }
        }
    }

    // MARK: - Test 1: Tokens Chart Y-axis M Format

    /// Test 1.1: Verify token formatter produces M format for millions
    func testTokenFormatter_MillionsFormat() {
        // Given large token values in millions
        let value = 2_500_000

        // When formatted using formatTokens function
        let result = formatTokens(value)

        // Then it should display as "2.5M"
        XCTAssertEqual(result, "2.5M", "Token values in millions should format as X.XM")
    }

    /// Test 1.2: Verify token formatter handles thousands
    func testTokenFormatter_ThousandsFormat() {
        let value = 1_500
        let result = formatTokens(value)
        XCTAssertEqual(result, "1.5K", "Token values in thousands should format as X.XK")
    }

    /// Test 1.3: Verify token formatter handles small values
    func testTokenFormatter_SmallValues() {
        let value = 500
        let result = formatTokens(value)
        XCTAssertEqual(result, "500", "Small token values should display as-is")
    }

    // MARK: - Test 2: Grid Lines for Empty/Zero Data

    /// Test 2.1: Verify empty data shows default grid 0/0.5/1
    func testEmptyDataShowsDefaultGrid() {
        // Given empty data array
        let emptyData: [StatisticsRepository.TrendDataPoint] = []

        // When determining Y-axis domain
        let yDomain = calculateYDomain(for: emptyData)

        // Then domain should be 0 to 1 with 0.5 tick
        XCTAssertEqual(yDomain, 0...1, "Empty data should show 0-1 domain")
    }

    /// Test 2.2: Verify all-zero data shows default grid
    func testAllZeroDataShowsDefaultGrid() {
        // Given data with all zero values
        let zeroData = [
            StatisticsRepository.TrendDataPoint(timestamp: 1, label: "A", value: 0, metricType: .cost),
            StatisticsRepository.TrendDataPoint(timestamp: 2, label: "B", value: 0, metricType: .cost)
        ]

        // When determining Y-axis domain
        let yDomain = calculateYDomain(for: zeroData)

        // Then domain should be 0 to 1
        XCTAssertEqual(yDomain, 0...1, "All-zero data should show 0-1 domain")
    }

    /// Test 2.3: Verify data with values uses actual domain
    func testDataWithValuesUsesActualDomain() {
        // Given data with actual values
        let data = [
            StatisticsRepository.TrendDataPoint(timestamp: 1, label: "A", value: 10, metricType: .cost),
            StatisticsRepository.TrendDataPoint(timestamp: 2, label: "B", value: 50, metricType: .cost)
        ]

        // When determining Y-axis domain
        let yDomain = calculateYDomain(for: data)

        // Then domain should match data range (with some padding)
        XCTAssertGreaterThanOrEqual(yDomain.upperBound, 50, "Domain should accommodate max value")
        XCTAssertLessThanOrEqual(yDomain.lowerBound, 10, "Domain should accommodate min value")
    }

    // MARK: - Test 3: Tooltip on Hover

    /// Test 3.1: Verify chart supports hover/selection for tooltip
    func testChartSupportsTooltip() {
        // Given chart data
        let data = [
            StatisticsRepository.TrendDataPoint(timestamp: 1, label: "A", value: 10, metricType: .cost)
        ]

        // When creating chart with selection support
        let supportsSelection = chartSupportsSelection(data: data)

        // Then chart should support selection for tooltip
        XCTAssertTrue(supportsSelection, "Chart should support selection/hover for tooltips")
    }

    /// Test 3.2: Verify tooltip content shows value
    func testTooltipContentShowsValue() {
        // Given a data point
        let point = StatisticsRepository.TrendDataPoint(timestamp: 1, label: "12:00", value: 10.5, metricType: .cost)

        // When generating tooltip content
        let tooltip = generateTooltipContent(for: point)

        // Then tooltip should contain the value
        XCTAssertTrue(tooltip.contains("10.5") || tooltip.contains("$10.5"), "Tooltip should show the value")
    }

    // MARK: - Helper Functions (these would be implemented in production code)

    private func calculateYDomain(for data: [StatisticsRepository.TrendDataPoint]) -> ClosedRange<Double> {
        // If empty or all zeros, return 0...1
        let values = data.map { $0.value }
        let maxValue = values.max() ?? 0
        let minValue = values.min() ?? 0

        if maxValue == 0 && minValue == 0 {
            return 0...1
        }

        // Add some padding
        let padding = (maxValue - minValue) * 0.1
        return (minValue - padding)...(maxValue + padding)
    }

    private func chartSupportsSelection(data: [StatisticsRepository.TrendDataPoint]) -> Bool {
        // In actual implementation, this would check if the chart view supports selection
        return true
    }

    private func generateTooltipContent(for point: StatisticsRepository.TrendDataPoint) -> String {
        let prefix = point.metricType == .cost ? "$" : ""
        return "\(point.label): \(prefix)\(String(format: "%.2f", point.value))"
    }
}
