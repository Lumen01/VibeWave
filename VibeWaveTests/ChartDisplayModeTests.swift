import XCTest
@testable import VibeWave

final class ChartDisplayModeTests: XCTestCase {
    func testIconNames() {
        XCTAssertEqual(ChartDisplayMode.bar.iconName, "chart.bar.fill")
        XCTAssertEqual(ChartDisplayMode.line.iconName, "chart.line.uptrend.xyaxis")
    }

    func testAccessibilityLabels() {
        XCTAssertEqual(ChartDisplayMode.bar.accessibilityLabel, "柱状图")
        XCTAssertEqual(ChartDisplayMode.line.accessibilityLabel, "折线图")
    }

    func testRawValueRoundTrip() {
        XCTAssertEqual(ChartDisplayMode(rawValue: "bar"), .bar)
        XCTAssertEqual(ChartDisplayMode(rawValue: "line"), .line)
    }
}
