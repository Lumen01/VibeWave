import XCTest
@testable import VibeWave
import AppKit

final class WindowConfiguratorTests: XCTestCase {
    func testConfiguratorAllowsVerticalResizeWithFixedWidth() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        FixedWidthWindowConfigurator.apply(to: window)

        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertEqual(window.minSize.width, 900)
        XCTAssertEqual(window.maxSize.width, 900)
        XCTAssertEqual(window.minSize.height, 600)
        XCTAssertEqual(window.maxSize.height, CGFloat.greatestFiniteMagnitude)
        XCTAssertGreaterThan(window.resizeIncrements.width, 0)
        XCTAssertGreaterThan(window.resizeIncrements.height, 0)
    }
}
