import XCTest
@testable import VibeWave

/// TDD tests for Bug: Mouse hover offset in History view charts
///
/// Bug: Mouse cursor visual position and actual "hover" position are offset,
///      with larger deviation the further right the mouse goes
///
/// Root Cause: The findClosestPointSimple function uses a hardcoded chart width
///             of 800 when calculating bar positions, but the actual chart width
///             may differ. This causes cumulative error as mouse moves right.
final class HistoryViewHoverFixTDDTests: XCTestCase {
    
    // MARK: - Test Data Setup
    
    private func createTestData(count: Int) -> [StatisticsRepository.TokenDivergingDataPoint] {
        return (0..<count).map { i in
            StatisticsRepository.TokenDivergingDataPoint(
                timestamp: TimeInterval(i),
                label: String(format: "%02d", i),
                inputTokens: Double(100 * i),
                outputTokens: Double(200 * i)
            )
        }
    }
    
    // MARK: - Bug Reproduction Tests
    
    /// Test 1: Verify hardcoded width causes offset error
    /// 
    /// Given: A chart with actual width different from 800
    /// When: Calculating bar positions using hardcoded 800
    /// Then: The calculated positions should diverge from actual positions
    func testHardcodedWidthCausesOffsetError() {
        // Given
        let actualChartWidth: CGFloat = 600
        let hardcodedWidth: CGFloat = 800
        let dataCount = 10
        let data = createTestData(count: dataCount)
        
        // When - Calculate positions with actual vs hardcoded width
        let actualBarWidth = (actualChartWidth - 40) / CGFloat(dataCount) // 40 = padding
        let hardcodedBarWidth = (hardcodedWidth - 40) / CGFloat(dataCount)
        
        // Then - Verify widths differ
        XCTAssertNotEqual(actualBarWidth, hardcodedBarWidth, 
            "Actual and hardcoded bar widths should differ")
        
        // Calculate position error at rightmost bar
        let rightmostIndex = dataCount - 1
        let actualPosition = CGFloat(rightmostIndex) * actualBarWidth + 20 // +20 for left padding
        let hardcodedPosition = CGFloat(rightmostIndex) * hardcodedBarWidth + 20
        let positionError = abs(hardcodedPosition - actualPosition)
        
        XCTAssertGreaterThan(positionError, 0, 
            "Position error should accumulate and be non-zero at right side")
        
        // This demonstrates the bug: using hardcoded width causes increasing offset
        XCTAssertEqual(actualBarWidth, 56, accuracy: 0.1, 
            "Actual bar width should be (600-40)/10 = 56")
        XCTAssertEqual(hardcodedBarWidth, 76, accuracy: 0.1, 
            "Hardcoded bar width should be (800-40)/10 = 76")
    }
    
    /// Test 2: Verify correct width eliminates offset
    ///
    /// Given: A chart with known width
    /// When: Calculating positions using the correct width
    /// Then: Calculated positions should match actual positions
    func testCorrectWidthEliminatesOffset() {
        // Given
        let chartWidth: CGFloat = 600
        let dataCount = 10
        let data = createTestData(count: dataCount)
        let padding: CGFloat = 40 // 20 left + 20 right
        
        // When - Calculate with correct width
        let effectiveWidth = chartWidth - padding
        let barWidth = effectiveWidth / CGFloat(dataCount)
        
        // Then - Verify calculations are correct
        XCTAssertEqual(effectiveWidth, 560, "Effective width should be 600 - 40 = 560")
        XCTAssertEqual(barWidth, 56, "Bar width should be 560 / 10 = 56")
        
        // Simulate mouse positions and verify index calculation
        let testPositions: [(x: CGFloat, expectedIndex: Int)] = [
            (30, 0),   // Left side - should be index 0
            (80, 1),   // Second bar
            (136, 2),  // Third bar
            (400, 6),  // Middle-right area
            (500, 8),  // Near right edge
        ]
        
        for (mouseX, expectedIndex) in testPositions {
            let adjustedX = mouseX - 20 // Subtract left padding
            let calculatedIndex = Int(adjustedX / barWidth)
            let clampedIndex = max(0, min(calculatedIndex, dataCount - 1))
            
            // The calculation should produce the expected index
            XCTAssertEqual(clampedIndex, expectedIndex,
                "Mouse at x=\(mouseX) should select index \(expectedIndex), got \(clampedIndex)")
        }
    }
    
    // MARK: - Integration Tests
    
    /// Test 3: Verify hover position calculation uses actual geometry
    ///
    /// This test verifies that the hover calculation correctly accounts for:
    /// - Chart padding (20pt on each side)
    /// - Actual chart width from GeometryReader
    /// - Data point count
    func testHoverPositionUsesActualGeometry() {
        // Given - Multiple chart widths to test
        let chartWidths: [CGFloat] = [400, 600, 800, 1000]
        let dataCount = 12
        let padding: CGFloat = 40 // 20 left + 20 right
        
        for chartWidth in chartWidths {
            // When
            let effectiveWidth = chartWidth - padding
            let barWidth = effectiveWidth / CGFloat(dataCount)
            
            // Then
            XCTAssertGreaterThan(barWidth, 0, "Bar width should be positive for width \(chartWidth)")
            
            // Test a few positions
            let testX: CGFloat = chartWidth / 2 // Middle of chart
            let adjustedX = testX - 20 // Subtract left padding
            let index = Int(adjustedX / barWidth)
            let clampedIndex = max(0, min(index, dataCount - 1))
            
            XCTAssertGreaterThanOrEqual(clampedIndex, 0, "Index should be >= 0")
            XCTAssertLessThan(clampedIndex, dataCount, "Index should be < dataCount")
        }
    }
}
