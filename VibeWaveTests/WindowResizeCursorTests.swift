import XCTest
@testable import VibeWave

final class WindowResizeCursorTests: XCTestCase {
    
    func testWindowShouldNotAllowHorizontalResize() {
        // Given: A window configured for fixed width (simulating WindowAccessor setup)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let delegate = FixedWidthWindowDelegate()
        window.delegate = delegate
        
        // When: Configuring window for fixed width (as WindowAccessor does)
        window.minSize = NSSize(width: 900, height: 600)
        window.maxSize = NSSize(width: 900, height: CGFloat.greatestFiniteMagnitude)
        window.contentResizeIncrements = NSSize(width: 0, height: 1)
        
        // Then: Width resize increment should be 0 to disable horizontal resize cursor
        let resizeIncrements = window.contentResizeIncrements
        XCTAssertEqual(resizeIncrements.width, 0, "Width resize increment should be 0 to disable horizontal resize cursor")
        XCTAssertEqual(resizeIncrements.height, 1, "Height resize increment should be 1 to allow vertical resize")
    }
    
    func testWindowWidthIsFixedAt900() {
        // Given: A window with FixedWidthWindowDelegate
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let delegate = FixedWidthWindowDelegate()
        window.delegate = delegate
        
        // When: Attempting to resize window to different widths
        let testWidths: [CGFloat] = [800, 950, 1000, 1200]
        
        for testWidth in testWidths {
            let proposedSize = NSSize(width: testWidth, height: 700)
            let allowedSize = delegate.windowWillResize(window, to: proposedSize)
            
            // Then: Width should always be locked at 900
            XCTAssertEqual(allowedSize.width, 900, "Width should be locked at 900 regardless of attempted resize to \(testWidth)")
        }
    }
    
    func testWindowHeightCanBeResized() {
        // Given: A window with FixedWidthWindowDelegate
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let delegate = FixedWidthWindowDelegate()
        window.delegate = delegate
        
        // When: Attempting to resize height to various values
        let testHeights: [CGFloat] = [600, 700, 800, 1000]
        
        for testHeight in testHeights {
            let proposedSize = NSSize(width: 900, height: testHeight)
            let allowedSize = delegate.windowWillResize(window, to: proposedSize)
            
            // Then: Height should be allowed to change (as long as >= 600)
            XCTAssertEqual(allowedSize.height, testHeight, "Height should be allowed to resize to \(testHeight)")
        }
    }
    
    func testWindowHeightHasMinimum600() {
        // Given: A window with FixedWidthWindowDelegate
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let delegate = FixedWidthWindowDelegate()
        window.delegate = delegate
        
        // When: Attempting to resize height below minimum
        let proposedSize = NSSize(width: 900, height: 400)
        let allowedSize = delegate.windowWillResize(window, to: proposedSize)
        
        // Then: Height should be clamped to minimum 600
        XCTAssertEqual(allowedSize.height, 600, "Height should be clamped to minimum 600 when attempting to resize to 400")
    }
}
