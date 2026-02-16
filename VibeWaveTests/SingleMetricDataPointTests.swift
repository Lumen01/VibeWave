import XCTest
@testable import VibeWave

final class SingleMetricDataPointTests: XCTestCase {
    func testInitialization() {
        let dataPoint = SingleMetricDataPoint(
            timestamp: 1_700_000_000,
            label: "12:00",
            value: 42.5,
            bucketIndex: 3,
            hasData: true,
            bucketStart: 1_700_000_000
        )

        XCTAssertEqual(dataPoint.timestamp, 1_700_000_000)
        XCTAssertEqual(dataPoint.label, "12:00")
        XCTAssertEqual(dataPoint.value, 42.5)
        XCTAssertEqual(dataPoint.bucketIndex, 3)
        XCTAssertTrue(dataPoint.hasData)
        XCTAssertEqual(dataPoint.bucketStart, 1_700_000_000)
        XCTAssertEqual(dataPoint.id, 1_700_000_000)
    }

    func testDefaultValues() {
        let dataPoint = SingleMetricDataPoint(
            timestamp: 1_700_000_000,
            label: "0",
            value: 0
        )

        XCTAssertEqual(dataPoint.bucketIndex, 0)
        XCTAssertFalse(dataPoint.hasData)
        XCTAssertEqual(dataPoint.bucketStart, 1_700_000_000)
    }
}
