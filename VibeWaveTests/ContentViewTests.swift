import XCTest
@testable import VibeWave

final class ContentViewTests: XCTestCase {
    func testSettingsTabShouldBeChinese() {
        XCTAssertEqual(ContentView.AppTab.settings.rawValue, "设定")
    }
}
