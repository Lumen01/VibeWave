import XCTest
@testable import VibeWave

final class OutputReasoningDataPointTests: XCTestCase {
    func testInitialization() {
        let dataPoint = OutputReasoningDataPoint(
            timestamp: 1_700_000_000,
            label: "12:00",
            outputTokens: 200,
            reasoningTokens: 50,
            bucketIndex: 4,
            hasData: true,
            bucketStart: 1_700_000_000
        )

        XCTAssertEqual(dataPoint.timestamp, 1_700_000_000)
        XCTAssertEqual(dataPoint.label, "12:00")
        XCTAssertEqual(dataPoint.outputTokens, 200)
        XCTAssertEqual(dataPoint.reasoningTokens, 50)
        XCTAssertEqual(dataPoint.bucketIndex, 4)
        XCTAssertTrue(dataPoint.hasData)
        XCTAssertEqual(dataPoint.totalTokens, 250)
        XCTAssertEqual(dataPoint.id, 1_700_000_000)
    }

    func testDefaultValues() {
        let dataPoint = OutputReasoningDataPoint(
            timestamp: 1_700_000_000,
            label: "0",
            outputTokens: 0,
            reasoningTokens: 0
        )

        XCTAssertEqual(dataPoint.bucketIndex, 0)
        XCTAssertFalse(dataPoint.hasData)
        XCTAssertEqual(dataPoint.bucketStart, 1_700_000_000)
    }
}
