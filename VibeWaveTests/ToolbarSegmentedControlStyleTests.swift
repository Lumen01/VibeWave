import XCTest
@testable import VibeWave

final class ToolbarSegmentedControlStyleTests: XCTestCase {
    func testSegmentLabelHorizontalPaddingDefaultsToCompactValue() {
        XCTAssertEqual(ToolbarSegmentedControlStyle.segmentLabelHorizontalPadding, -2)
    }
}
