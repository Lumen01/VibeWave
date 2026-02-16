

import XCTest
@testable import VibeWave

final class TimeGranularityTests: XCTestCase {
    func testFrom_last24Hours_returnsHourly() {
        let granularity = TimeGranularity.from(timeRange: .last24Hours)
        XCTAssertEqual(granularity, .hourly, "Expected .hourly for last24Hours")
    }
    
    func testFrom_last30Days_returnsDaily() {
        let granularity = TimeGranularity.from(timeRange: .last30Days)
        XCTAssertEqual(granularity, .daily, "Expected .daily for last30Days")
    }
    
    func testFrom_allTime_returnsMonthly() {
        let granularity = TimeGranularity.from(timeRange: .allTime)
        XCTAssertEqual(granularity, .monthly, "Expected .monthly for allTime")
    }
}
