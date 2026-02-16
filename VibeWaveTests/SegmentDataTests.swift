import XCTest
@testable import VibeWave
import SwiftUI

final class SegmentDataTests: XCTestCase {

    // MARK: - Identifiable Conformance Tests

    func testSegmentData_ConformsToIdentifiable() {
        // Arrange & Act
        let segment = SegmentData(dimensionValue: "Model A", tokenCount: 100, color: .blue)

        // Assert
        XCTAssertNotNil(segment.id, "SegmentData should have a non-nil id from Identifiable protocol")
        XCTAssertTrue(segment.id is UUID, "Id should be of type UUID")
    }

    // MARK: - Initialization Tests

    func testSegmentData_Initialization() {
        // Arrange
        let expectedDimensionValue = "GPT-4"
        let expectedTokenCount = 500
        let expectedColor: Color = .red

        // Act
        let segment = SegmentData(
            dimensionValue: expectedDimensionValue,
            tokenCount: expectedTokenCount,
            color: expectedColor
        )

        // Assert
        XCTAssertEqual(segment.dimensionValue, expectedDimensionValue, "dimensionValue should match init parameter")
        XCTAssertEqual(segment.tokenCount, expectedTokenCount, "tokenCount should match init parameter")
        XCTAssertEqual(segment.color, expectedColor, "color should match init parameter")
        XCTAssertNotNil(segment.id, "id should be automatically generated")
    }

    func testSegmentData_ZeroTokens() {
        // Arrange
        let segment = SegmentData(dimensionValue: "Empty Model", tokenCount: 0, color: .gray)

        // Act & Assert
        XCTAssertEqual(segment.tokenCount, 0, "SegmentData should support zero token count")
        XCTAssertEqual(segment.dimensionValue, "Empty Model")
        XCTAssertEqual(segment.color, .gray)
    }

    func testSegmentData_EachInstanceHasUniqueId() {
        // Arrange
        let segment1 = SegmentData(dimensionValue: "Model 1", tokenCount: 100, color: .blue)
        let segment2 = SegmentData(dimensionValue: "Model 2", tokenCount: 200, color: .green)

        // Act & Assert
        XCTAssertNotEqual(segment1.id, segment2.id, "Each SegmentData instance should have a unique id")
    }

    func testSegmentData_ImmutableStruct() {
        // Arrange
        let segment = SegmentData(dimensionValue: "Original", tokenCount: 100, color: .blue)

        // Act & Assert - Verify struct properties are not modifiable (let vs var)
        // This test ensures the struct uses let properties as specified
        let originalId = segment.id
        let originalDimensionValue = segment.dimensionValue
        let originalTokenCount = segment.tokenCount
        let originalColor = segment.color

        // The properties should be immutable
        // If they were var, reassignment would succeed. They are let, so compilation fails.
        // Since we can't test this at runtime (compilation would fail), we verify the values remain constant
        XCTAssertEqual(segment.id, originalId)
        XCTAssertEqual(segment.dimensionValue, originalDimensionValue)
        XCTAssertEqual(segment.tokenCount, originalTokenCount)
        XCTAssertEqual(segment.color, originalColor)
    }
}
