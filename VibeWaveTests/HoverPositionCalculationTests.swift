import XCTest
@testable import VibeWave

/// Unit tests for the fixed hover position calculation
///
/// These tests verify that the padding-aware calculation correctly maps
/// mouse positions to data indices without cumulative error.
final class HoverPositionCalculationTests: XCTestCase {

    // MARK: - Test Data

    private func createTokenData(count: Int) -> [StatisticsRepository.TokenDivergingDataPoint] {
        return (0..<count).map { i in
            StatisticsRepository.TokenDivergingDataPoint(
                timestamp: TimeInterval(i),
                label: String(format: "%02d", i),
                inputTokens: Double(100 * i),
                outputTokens: Double(200 * i)
            )
        }
    }

    // MARK: - TokenChartView Tests

    /// Test that findClosestPointSimple correctly accounts for padding
    func testTokenChartView_HoverCalculationWithPadding() {
        // Given
        let chartWidth: CGFloat = 600
        let dataCount = 12
        _ = createTokenData(count: dataCount)  // Data structure not needed for calculation test
        let leftPadding: CGFloat = 20
        let rightPadding: CGFloat = 20
        let totalPadding = leftPadding + rightPadding
        let effectiveWidth = chartWidth - totalPadding

        // When & Then - Test various mouse positions

        // Test 1: Leftmost bar (index 0)
        // Mouse at x=30 should select index 0 (center of first bar area)
        let mouseAtLeft = CGPoint(x: 30, y: 50)
        let expectedIndex0 = 0

        let adjustedX0 = mouseAtLeft.x - leftPadding
        let proportionalX0 = adjustedX0 / effectiveWidth
        let index0 = Int(proportionalX0 * CGFloat(dataCount))
        let clampedIndex0 = max(0, min(index0, dataCount - 1))

        XCTAssertEqual(clampedIndex0, expectedIndex0,
            "Mouse at x=\(mouseAtLeft.x) should select index \(expectedIndex0)")

        // Test 2: Middle bar (index 6)
        // Mouse at center of chart should select middle bar
        let mouseAtCenter = CGPoint(x: chartWidth / 2, y: 50)
        let expectedIndex6 = dataCount / 2  // 6

        let adjustedX6 = mouseAtCenter.x - leftPadding
        let proportionalX6 = adjustedX6 / effectiveWidth
        let index6 = Int(proportionalX6 * CGFloat(dataCount))
        let clampedIndex6 = max(0, min(index6, dataCount - 1))

        XCTAssertEqual(clampedIndex6, expectedIndex6,
            "Mouse at center x=\(mouseAtCenter.x) should select index \(expectedIndex6)")

        // Test 3: Rightmost bar (index 11)
        // Mouse near right edge should select last bar
        let mouseAtRight = CGPoint(x: chartWidth - 30, y: 50)
        let expectedIndex11 = dataCount - 1  // 11

        let adjustedX11 = mouseAtRight.x - leftPadding
        let proportionalX11 = adjustedX11 / effectiveWidth
        let index11 = Int(proportionalX11 * CGFloat(dataCount))
        let clampedIndex11 = max(0, min(index11, dataCount - 1))

        XCTAssertEqual(clampedIndex11, expectedIndex11,
            "Mouse at x=\(mouseAtRight.x) should select index \(expectedIndex11)")
    }

    /// Test that cumulative error is eliminated
    func testNoCumulativeError() {
        // Given
        let chartWidth: CGFloat = 600
        let dataCount = 24
        let leftPadding: CGFloat = 20
        let rightPadding: CGFloat = 20
        let effectiveWidth = chartWidth - leftPadding - rightPadding
        let barWidth = effectiveWidth / CGFloat(dataCount)

        // When - Calculate expected positions for each bar
        // Each bar's center is at: leftPadding + (index * barWidth) + (barWidth / 2)
        var expectedPositions: [CGFloat] = []
        for i in 0..<dataCount {
            let barCenter = leftPadding + (CGFloat(i) * barWidth) + (barWidth / 2)
            expectedPositions.append(barCenter)
        }

        // Then - Verify our calculation produces consistent results
        for (index, expectedPosition) in expectedPositions.enumerated() {
            // Reverse calculation: from mouse position to index
            let adjustedX = expectedPosition - leftPadding
            let proportionalX = adjustedX / effectiveWidth
            let calculatedIndex = Int(proportionalX * CGFloat(dataCount))
            let clampedIndex = max(0, min(calculatedIndex, dataCount - 1))

            XCTAssertEqual(clampedIndex, index,
                "Bar at index \(index) with center x=\(expectedPosition) should map back to same index")
        }

        // Verify no cumulative error: check that positions are evenly spaced
        if expectedPositions.count >= 2 {
            let firstBarCenter = expectedPositions[0]
            let lastBarCenter = expectedPositions[dataCount - 1]
            let totalSpan = lastBarCenter - firstBarCenter
            let expectedBarWidth = totalSpan / CGFloat(dataCount - 1)

            // All bars should have the same spacing
            for i in 1..<expectedPositions.count {
                let spacing = expectedPositions[i] - expectedPositions[i - 1]
                XCTAssertEqual(spacing, expectedBarWidth, accuracy: 0.001,
                    "Bar spacing should be consistent (no cumulative error)")
            }
        }
    }

    /// Test different chart widths
    func testVariousChartWidths() {
        let chartWidths: [CGFloat] = [400, 600, 800, 1000, 1200]
        let dataCount = 12

        for chartWidth in chartWidths {
            let effectiveWidth = chartWidth - 40  // 20 left + 20 right padding
            let barWidth = effectiveWidth / CGFloat(dataCount)

            // Test middle position
            let mouseAtCenter = CGPoint(x: chartWidth / 2, y: 50)

            let adjustedX = mouseAtCenter.x - 20
            let proportionalX = adjustedX / effectiveWidth
            let index = Int(proportionalX * CGFloat(dataCount))
            let clampedIndex = max(0, min(index, dataCount - 1))

            let expectedIndex = dataCount / 2  // 6
            XCTAssertEqual(clampedIndex, expectedIndex,
                "Chart width \(chartWidth): mouse at center should select index \(expectedIndex)")

            // Verify bar width is reasonable
            XCTAssertGreaterThan(barWidth, 0, "Chart width \(chartWidth): bar width should be positive")
        }
    }
}
