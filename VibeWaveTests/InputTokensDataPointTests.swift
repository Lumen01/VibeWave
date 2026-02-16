import XCTest
@testable import VibeWave

final class InputTokensDataPointTests: XCTestCase {

    // MARK: - Conformance Tests

    func testInputTokensDataPoint_ConformsToIdentifiable() {
        let dataPoint = InputTokensDataPoint(
            timestamp: 1700000000,
            label: "14",
            totalTokens: 1000,
            segments: []
        )

        XCTAssertNotNil(dataPoint.id)
    }

    // MARK: - Initialization Tests

    func testInputTokensDataPoint_Initialization() {
        let timestamp: TimeInterval = 1700000000
        let label = "14"
        let totalTokens = 1000

        let dataPoint = InputTokensDataPoint(
            timestamp: timestamp,
            label: label,
            totalTokens: totalTokens,
            segments: []
        )

        XCTAssertEqual(dataPoint.timestamp, timestamp)
        XCTAssertEqual(dataPoint.bucketStart, timestamp)
        XCTAssertEqual(dataPoint.bucketIndex, 0)
        XCTAssertEqual(dataPoint.label, label)
        XCTAssertEqual(dataPoint.totalTokens, totalTokens)
        XCTAssertFalse(dataPoint.hasData)
        XCTAssertTrue(dataPoint.segments.isEmpty)
        XCTAssertNotNil(dataPoint.id)
    }

    func testInputTokensDataPoint_InitializationWithSegments() {
        let segment1 = SegmentData(dimensionValue: "Project A", tokenCount: 600, color: .blue)
        let segment2 = SegmentData(dimensionValue: "Project B", tokenCount: 400, color: .green)
        let segments = [segment1, segment2]

        let dataPoint = InputTokensDataPoint(
            timestamp: 1700000000,
            label: "14",
            totalTokens: 1000,
            segments: segments
        )

        XCTAssertEqual(dataPoint.segments.count, 2)
        XCTAssertEqual(dataPoint.segments[0].dimensionValue, "Project A")
        XCTAssertEqual(dataPoint.segments[0].tokenCount, 600)
        XCTAssertEqual(dataPoint.segments[1].dimensionValue, "Project B")
        XCTAssertEqual(dataPoint.segments[1].tokenCount, 400)
        XCTAssertFalse(dataPoint.hasData)
    }

    // MARK: - Edge Case Tests

    func testInputTokensDataPoint_ZeroTokens() {
        let dataPoint = InputTokensDataPoint(
            timestamp: 1700000000,
            label: "0",
            totalTokens: 0,
            segments: []
        )

        XCTAssertEqual(dataPoint.totalTokens, 0)
        XCTAssertFalse(dataPoint.hasData)
        XCTAssertTrue(dataPoint.segments.isEmpty)
        XCTAssertNotNil(dataPoint.id)
    }

    func testInputTokensDataPoint_EmptySegments() {
        let dataPoint = InputTokensDataPoint(
            timestamp: 1700000000,
            label: "14",
            totalTokens: 1000,
            segments: []
        )

        XCTAssertTrue(dataPoint.segments.isEmpty)
        XCTAssertEqual(dataPoint.segments.count, 0)
    }

    func testInputTokensDataPoint_CustomBucketMetadata() {
        let dataPoint = InputTokensDataPoint(
            timestamp: 1700000000,
            label: "14",
            totalTokens: 1200,
            segments: [],
            bucketIndex: 5,
            hasData: true,
            bucketStart: 1699990000
        )

        XCTAssertEqual(dataPoint.bucketIndex, 5)
        XCTAssertTrue(dataPoint.hasData)
        XCTAssertEqual(dataPoint.bucketStart, 1699990000)
        XCTAssertEqual(dataPoint.id, 1699990000)
    }
}
