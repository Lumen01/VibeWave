import XCTest
import SwiftUI
@testable import VibeWave

final class SegmentedBarChartModelTests: XCTestCase {

    // MARK: - AggregationDimension Tests

    func testAggregationDimensionProjectRawValue() {
        XCTAssertEqual(AggregationDimension.project.rawValue, "项目")
    }

    func testAggregationDimensionModelRawValue() {
        XCTAssertEqual(AggregationDimension.model.rawValue, "模型")
    }

    func testAggregationDimensionCaseIterableCount() {
        XCTAssertEqual(AggregationDimension.allCases.count, 2)
    }

    func testAggregationDimensionDisplayName() {
        XCTAssertEqual(AggregationDimension.project.displayName, "项目")
        XCTAssertEqual(AggregationDimension.model.displayName, "模型")
    }

    // MARK: - SegmentedBarDataPoint Tests

    func testSegmentedBarDataPointInitialization() {
        let timestamp: TimeInterval = 1700000000
        let dataPoint = SegmentedBarDataPoint(
            id: UUID(),
            timestamp: timestamp,
            label: "2024-01",
            dimension: .project,
            dimensionValue: "Project A",
            value: 100.5
        )

        XCTAssertEqual(dataPoint.timestamp, timestamp)
        XCTAssertEqual(dataPoint.label, "2024-01")
        XCTAssertEqual(dataPoint.dimension, .project)
        XCTAssertEqual(dataPoint.dimensionValue, "Project A")
        XCTAssertEqual(dataPoint.value, 100.5)
    }

    func testSegmentedBarDataPointConformsToIdentifiable() {
        let dataPoint = SegmentedBarDataPoint(
            timestamp: 1700000000,
            label: "Test",
            dimension: .model,
            dimensionValue: "GPT-4",
            value: 50.0
        )

        _ = dataPoint.id
        XCTAssertNotNil(dataPoint.id)
    }

    func testSegmentedBarDataPointEquality() {
        let timestamp: TimeInterval = 1700000000
        let id = UUID()

        let dataPoint1 = SegmentedBarDataPoint(
            id: id,
            timestamp: timestamp,
            label: "Test",
            dimension: .project,
            dimensionValue: "Project A",
            value: 100.0
        )

        let dataPoint2 = SegmentedBarDataPoint(
            id: id,
            timestamp: timestamp,
            label: "Test",
            dimension: .project,
            dimensionValue: "Project A",
            value: 100.0
        )

        XCTAssertEqual(dataPoint1, dataPoint2)
    }

    func testSegmentedBarDataPointInequality() {
        let dataPoint1 = SegmentedBarDataPoint(
            timestamp: 1700000000,
            label: "Test1",
            dimension: .project,
            dimensionValue: "Project A",
            value: 100.0
        )

        let dataPoint2 = SegmentedBarDataPoint(
            timestamp: 1700000000,
            label: "Test2",
            dimension: .project,
            dimensionValue: "Project A",
            value: 100.0
        )

        XCTAssertNotEqual(dataPoint1, dataPoint2)
    }

    // MARK: - SegmentedBarColorAssignment Tests

    func testTopColorsCount() {
        XCTAssertEqual(SegmentedBarColorAssignment.topColors.count, 6)
    }

    func testOtherColor() {
        let otherColor = SegmentedBarColorAssignment.otherColor
        XCTAssertEqual(otherColor, .gray)
    }

    func testAssignColorsWithFewerThan6Values() {
        let values = ["A", "B", "C"]
        let colors = SegmentedBarColorAssignment.assignColors(to: values)

        XCTAssertEqual(colors.count, 3)
        XCTAssertEqual(colors["A"], .blue)
        XCTAssertEqual(colors["B"], .green)
        XCTAssertEqual(colors["C"], .orange)
    }

    func testAssignColorsWithExactly6Values() {
        let values = ["A", "B", "C", "D", "E", "F"]
        let colors = SegmentedBarColorAssignment.assignColors(to: values)

        XCTAssertEqual(colors.count, 6)
        XCTAssertEqual(colors["A"], .blue)
        XCTAssertEqual(colors["B"], .green)
        XCTAssertEqual(colors["C"], .orange)
        XCTAssertEqual(colors["D"], .purple)
        XCTAssertEqual(colors["E"], .pink)
        XCTAssertEqual(colors["F"], .cyan)
    }

    func testAssignColorsWithMoreThan6Values() {
        let values = ["A", "B", "C", "D", "E", "F", "G", "H"]
        let colors = SegmentedBarColorAssignment.assignColors(to: values)

        XCTAssertEqual(colors.count, 8)
        XCTAssertEqual(colors["A"], .blue)
        XCTAssertEqual(colors["G"], .gray)
        XCTAssertEqual(colors["H"], .gray)
    }

    func testAssignColorsWithEmptyValues() {
        let values: [String] = []
        let colors = SegmentedBarColorAssignment.assignColors(to: values)

        XCTAssertTrue(colors.isEmpty)
    }

    func testColorForWithRankedValue() {
        let allValues = ["Zebra", "Apple", "Banana", "Cherry", "Date", "Fig", "Grape"]

        let zebraColor = SegmentedBarColorAssignment.colorFor(dimensionValue: "Zebra", in: allValues)
        let appleColor = SegmentedBarColorAssignment.colorFor(dimensionValue: "Apple", in: allValues)
        let grapeColor = SegmentedBarColorAssignment.colorFor(dimensionValue: "Grape", in: allValues)

        // Zebra comes after sorting (A, B, C, D, F, G, Z)
        // Apple should be .blue (index 0)
        // Grape should be .cyan (index 5)
        // Zebra should be .gray (index 6)
        XCTAssertEqual(appleColor, .blue)
        XCTAssertEqual(grapeColor, .cyan)
        XCTAssertEqual(zebraColor, .gray)
    }

    func testColorForWithUnknownValue() {
        let allValues = ["A", "B", "C"]
        let unknownColor = SegmentedBarColorAssignment.colorFor(dimensionValue: "Unknown", in: allValues)

        XCTAssertEqual(unknownColor, .gray)
    }

    func testColorAssignmentConsistentOrdering() {
        let values1 = ["Charlie", "Alpha", "Beta"]
        let values2 = ["Alpha", "Beta", "Charlie"]

        let colors1 = SegmentedBarColorAssignment.assignColors(to: values1)
        let colors2 = SegmentedBarColorAssignment.assignColors(to: values2)

        // Both should assign .blue to Alpha, .green to Beta, .orange to Charlie
        XCTAssertEqual(colors1["Alpha"], colors2["Alpha"])
        XCTAssertEqual(colors1["Beta"], colors2["Beta"])
        XCTAssertEqual(colors1["Charlie"], colors2["Charlie"])
    }
}
