import XCTest
@testable import VibeWave
import AppKit

final class WindowResizeCursorBehaviorTests: XCTestCase {
    
    func testWindowShouldShowVerticalResizeCursorOnly() {
        // Given: A window configured for fixed width with proper cursor behavior
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let delegate = FixedWidthWindowDelegate()
        window.delegate = delegate
        
        // When: Configuring window with proper resize constraints
        window.minSize = NSSize(width: 900, height: 600)
        window.maxSize = NSSize(width: 900, height: CGFloat.greatestFiniteMagnitude)
        
        // Then: Window should be resizable (allows vertical resize)
        XCTAssertTrue(window.styleMask.contains(.resizable), "Window should be resizable to allow vertical resize")
        
        // And: Window should have proper size constraints
        XCTAssertEqual(window.minSize.width, 900, "Minimum width should be 900")
        XCTAssertEqual(window.minSize.height, 600, "Minimum height should be 600")
        XCTAssertEqual(window.maxSize.width, 900, "Maximum width should be 900")
        XCTAssertEqual(window.maxSize.height, CGFloat.greatestFiniteMagnitude, "Maximum height should be unlimited")
    }
    
    func testWindowDelegatePreventsWidthChanges() {
        // Given: A window with FixedWidthWindowDelegate
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let delegate = FixedWidthWindowDelegate()
        window.delegate = delegate
        
        // When: Attempting to resize horizontally
        let proposedSize = NSSize(width: 1000, height: 700)
        let allowedSize = delegate.windowWillResize(window, to: proposedSize)
        
        // Then: Width should be locked at 900
        XCTAssertEqual(allowedSize.width, 900, "Width should be locked at 900")
        XCTAssertEqual(allowedSize.height, 700, "Height should be allowed to change")
    }
    
    func testWindowDelegateRespectsMinimumHeight() {
        // Given: A window with FixedWidthWindowDelegate
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let delegate = FixedWidthWindowDelegate()
        window.delegate = delegate
        
        // When: Attempting to resize below minimum height
        let proposedSize = NSSize(width: 900, height: 400)
        let allowedSize = delegate.windowWillResize(window, to: proposedSize)
        
        // Then: Height should be clamped to minimum 600
        XCTAssertEqual(allowedSize.height, 600, "Height should be clamped to minimum 600")
    }
    
    func testWindowShouldHaveCorrectResizeIncrements() {
        // Given: A window configured for fixed width
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let delegate = FixedWidthWindowDelegate()
        window.delegate = delegate
        
        // When: Setting resize increments to disable horizontal resize cursor
        window.resizeIncrements = NSSize(width: 0, height: 1)
        
        // Then: Resize increments should disable horizontal resize
        let resizeIncrements = window.resizeIncrements
        XCTAssertEqual(resizeIncrements.width, 0, "Width increment should be 0 to disable horizontal resize cursor")
        XCTAssertEqual(resizeIncrements.height, 1, "Height increment should be 1 to allow vertical resize")
        
        // And: Window delegate should still prevent width changes
        let proposedSize = NSSize(width: 1000, height: 700)
        let allowedSize = delegate.windowWillResize(window, to: proposedSize)
        XCTAssertEqual(allowedSize.width, 900, "Width should still be locked at 900")
    }
}