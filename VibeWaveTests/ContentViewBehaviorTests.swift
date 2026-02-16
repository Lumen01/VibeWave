import XCTest
@testable import VibeWave

final class ContentViewBehaviorTests: XCTestCase {
    func testContentViewDisablesTextSelection() {
        XCTAssertFalse(ContentView.textSelectionEnabled)
    }
}
