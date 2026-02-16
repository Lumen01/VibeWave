import XCTest
import AppKit
@testable import VibeWave

final class MenuBarIconTests: XCTestCase {
    func testMenuBarIconIsTemplateAndSizedForMenuBar() {
        let image = MenuBarIcon.image
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, MenuBarIcon.targetSize)
    }
}
