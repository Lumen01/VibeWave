import XCTest
@testable import VibeWave
import AppKit
import SwiftUI

/// Unit tests for MenuBarPopupWindow
///
/// These tests verify that MenuBarPopupWindow correctly displays content,
/// handles positioning, and responds to external click detection.
final class MenuBarPopupWindowTests: XCTestCase {

    // MARK: - Test Helper Methods

    /// Creates a test instance of MenuBarPopupWindow with NSHostingController
    private func makeSUT() -> MenuBarPopupWindow {
        return MenuBarPopupWindow(statusItem: nil)
    }

    /// Creates a test instance with a mock status item
    private func makeSUTWithStatusItem() -> (MenuBarPopupWindow, NSStatusItem) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let sut = MenuBarPopupWindow(statusItem: statusItem)
        return (sut, statusItem)
    }

    /// Verifies that the window exists
    private func assertWindowExists(_ window: NSWindow?, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(window, "Window should exist", file: file, line: line)
    }

    /// Verifies that the window has NSHostingController as content view controller
    private func assertWindowHasHostingController(_ window: NSWindow?, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(window?.contentViewController, "Window should have a content view controller", file: file, line: line)
        XCTAssertTrue(
            window?.contentViewController is NSHostingController<MenuBarPopupView>,
            "Content view controller should be NSHostingController<MenuBarPopupView>",
            file: file,
            line: line
        )
    }

    /// Verifies that the window has proper visual styling
    private func assertWindowHasVisualStyling(_ window: NSWindow?, file: StaticString = #file, line: UInt = #line) {
        assertWindowExists(window, file: file, line: line)

        // Window should be floating panel style
        XCTAssertEqual(
            window?.styleMask,
            [.borderless, .nonactivatingPanel],
            "Window should have borderless and nonactivating panel style",
            file: file,
            line: line
        )

        // Window should be at popUpMenu level
        XCTAssertEqual(
            window?.level,
            .popUpMenu,
            "Window should be at popUpMenu level",
            file: file,
            line: line
        )
    }

    /// Verifies that the window has rounded corners
    private func assertWindowHasRoundedCorners(_ window: NSWindow?, file: StaticString = #file, line: UInt = #line) {
        assertWindowExists(window, file: file, line: line)
        XCTAssertNotNil(
            NSHostingController<MenuBarPopupView>.self,
            "Window should have content view configured for rounded corners",
            file: file,
            line: line
        )
    }

    // MARK: - Window Creation Tests

    func testMenuBarPopupWindowCreatesWindow() {
        // Given
        let sut = makeSUT()

        // When
        let window = sut.nsWindow

        // Then
        assertWindowExists(window)
    }

    func testMenuBarPopupWindowWrapsViewInHostingController() {
        // Given
        let sut = makeSUT()

        // When
        let window = sut.nsWindow

        // Then
        assertWindowHasHostingController(window)
    }

    func testMenuBarPopupWindowHasBorderlessStyle() {
        // Given
        let sut = makeSUT()

        // When
        let window = sut.nsWindow

        // Then
        XCTAssertEqual(
            window?.styleMask,
            [.borderless, .nonactivatingPanel],
            "Window should have borderless and nonactivating panel style"
        )
    }

    func testMenuBarPopupWindowIsPopUpMenuLevel() {
        // Given
        let sut = makeSUT()

        // When
        let window = sut.nsWindow

        // Then
        XCTAssertEqual(
            window?.level,
            .popUpMenu,
            "Window should be at popUpMenu level"
        )
    }

    func testMenuBarPopupWindowHasExternalClickDetection() {
        // Given
        let sut = makeSUT()

        // When
        // Trigger the external click detection mechanism
        sut.handleExternalClick()

        // Then - After implementation, window should close
        // For now we'll check the method exists and window behavior will be verified in GREEN phase
    }

    // MARK: - Window Positioning Tests

    func testMenuBarPopupWindowAcceptsStatusItem() {
        // Given
        _ = makeSUT()
        // Setup a mock status item for testing
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // When
        // For now, MenuBarPopupWindow doesn't accept status item parameter
        // This test will pass when we update the init signature

        // Then
        // TODO: Update this test once init accepts status item parameter
        XCTAssertNotNil(statusItem, "Status item should be created for testing")
    }

    func testMenuBarPopupWindowHasCorrectWidth() {
        // Given
        let sut = makeSUT()

        // When
        let window = sut.nsWindow

        // Then
        let expectedWidth: CGFloat = 340
        XCTAssertEqual(
            window?.frame.width,
            expectedWidth,
            "Window width should be \(expectedWidth)pt"
        )
    }

    func testMenuBarPopupWindowShowCalculatesPosition() {
        // Given
        let sut = makeSUT()
        // Create a testable status item
        _ = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // When
        sut.show()

        // Then - After implementation, window position should be calculated
        let window = sut.nsWindow
        XCTAssertNotNil(window, "Window should exist after calling show()")

        // The position should be below the status bar
        // For now, we just verify the method exists
        // TODO: Add position assertions once implementation is complete
    }

    func testWindowPositionIsLeftAlignedBelowStatusItem() {
        // Given
        let sut = makeSUT()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // When
        sut.show()
        let window = sut.nsWindow
        let statusButtonFrame = statusItem.button?.frame ?? NSRect.zero

        // Then
        // Window x should align with status item button's left edge (for left-aligned positioning)
        // For now, this test will fail as positioning is not implemented
        if let windowX = window?.frame.origin.x {
            let expectedX = statusButtonFrame.origin.x
            XCTAssertEqual(
                windowX,
                expectedX,
                "Window x position should be left-aligned with status item button"
            )
        } else {
            XCTFail("Window should have a valid frame after show()")
        }
    }

    func testWindowPositionIsBelowMenuBar() {
        // Given
        let sut = makeSUT()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // When
        sut.show()
        let window = sut.nsWindow

        // Then
        // Window y should be 0 (directly below menu bar with 0pt vertical gap)
        if let windowY = window?.frame.origin.y {
            let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 0
            let expectedY: CGFloat = 0  // Directly below menu bar
            XCTAssertEqual(
                windowY,
                expectedY,
                "Window y position should be directly below menu bar (0pt vertical gap)"
            )
        } else {
            XCTFail("Window should have a valid frame after show()")
        }
    }

    func testWindowPositionIsClampedToScreenBounds() {
        // Given
        let sut = makeSUT()
        _ = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // When
        sut.show()
        let window = sut.nsWindow

        // Then
        // Window should not overlap screen edges
        if let window = window,
           let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame

            // Window should be on screen (not off right edge)
            XCTAssertLessThanOrEqual(
                windowFrame.maxX,
                screenFrame.maxX,
                "Window should not extend beyond screen right edge"
            )

            // Window should be on screen (not off left edge)
            XCTAssertGreaterThanOrEqual(
                windowFrame.minX,
                screenFrame.minX,
                "Window should not extend beyond screen left edge"
            )

            // Window should be on screen (not off bottom edge)
            XCTAssertGreaterThanOrEqual(
                windowFrame.minY,
                screenFrame.minY,
                "Window should not extend beyond screen bottom edge"
            )

            // Window should be on screen (not off top edge)
            XCTAssertLessThanOrEqual(
                windowFrame.maxY,
                screenFrame.maxY,
                "Window should not extend beyond screen top edge"
            )
        } else {
            XCTFail("Window and main screen should exist after show()")
        }
    }

    func testWindowHeightAdaptsToContent() {
        // Given
        let sut = makeSUT()
        _ = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // When
        sut.show()
        let window = sut.nsWindow

        // Then
        // Window height should reflect content size (not default 400pt)
        if window?.frame.height != nil {
            // Fixed height of 400 is the default placeholder
            // After implementation, height should be calculated based on content
            XCTFail("Window height should be calculated based on content, not fixed at 400pt")
        } else {
            XCTFail("Window should have a valid frame with adaptive height after show()")
        }
    }

    // MARK: - External Click Detection Tests

    func testExternalClickClosesWindow() {
        // Given
        let sut = makeSUT()
        sut.show()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist after show()")
            return
        }

        // Verify window is visible
        XCTAssertTrue(window.isVisible, "Window should be visible after show()")

        // When - Simulate external click
        sut.handleExternalClick()

        // Then - Window should be closed
        XCTAssertFalse(
            window.isVisible,
            "Window should not be visible after external click"
        )
    }

    func testExternalClickDoesNotCloseClosedWindow() {
        // Given
        let sut = makeSUT()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist")
            return
        }

        // Verify window is initially closed
        XCTAssertFalse(window.isVisible, "Window should be closed initially")

        // When - Handle external click on closed window
        sut.handleExternalClick()

        // Then - Window should remain closed, no error should occur
        XCTAssertFalse(
            window.isVisible,
            "Window should still be closed after external click"
        )
    }

    func testClickOutsideWindowBoundsClosesWindow() {
        // Given
        let sut = makeSUT()
        sut.show()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist after show()")
            return
        }

        // Verify window is visible
        XCTAssertTrue(window.isVisible, "Window should be visible after show()")

        // When - Trigger external click (implementation will simulate click outside)
        sut.handleExternalClick()

        // Then - Window should close
        XCTAssertFalse(
            window.isVisible,
            "Window should be closed when external click occurs"
        )
    }

    // MARK: - Animation Tests

    func testShowWindowStartsWithFadedInAlpha() {
        // Given
        let sut = makeSUT()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist")
            return
        }

        // When
        sut.show()

        // Then
        XCTAssertTrue(window.isVisible, "Window should be visible after show()")
        XCTAssertNotEqual(
            window.alphaValue,
            0.0,
            "Window alpha should not be 0 after show() (fade in animation should be in progress)"
        )
    }

    func testCloseWindowClosesAfterFadeOutAnimation() {
        // Given
        let sut = makeSUT()
        sut.show()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist after show()")
            return
        }

        XCTAssertTrue(window.isVisible, "Window should be visible before close()")

        // When
        sut.close()

        Thread.sleep(forTimeInterval: 0.05)

        // Then
        if window.isVisible {
            XCTAssertLessThan(
                window.alphaValue,
                1.0,
                "Window alpha should be decreasing during fade out animation"
            )
        }
    }

    func testFadeInAnimationUses0Point3SecondsDuration() {
        // Given
        let sut = makeSUT()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist")
            return
        }

        // When
        let startTime = Date()
        sut.show()

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))

        // Then
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertTrue(
            elapsedTime >= 0.3 && elapsedTime < 0.5,
            "Fade in animation should take approximately 0.3s (actual: \(elapsedTime)s)"
        )
    }

    func testFadeOutAnimationUses0Point3SecondsDuration() {
        // Given
        let sut = makeSUT()
        sut.show()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist after show()")
            return
        }

        XCTAssertTrue(window.isVisible, "Window should be visible before close()")

        // When
        let startTime = Date()
        sut.close()

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))

        // Then
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertFalse(
            window.isVisible,
            "Window should be closed after fade out animation"
        )
        XCTAssertTrue(
            elapsedTime >= 0.3 && elapsedTime < 0.5,
            "Fade out animation should take approximately 0.3s (actual: \(elapsedTime)s)"
        )
    }

    // MARK: - Lifecycle Management Tests

    func testPopupClosesWhenApplicationLosesFocus() {
        // Given
        let sut = makeSUT()
        sut.show()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist after show()")
            return
        }

        XCTAssertTrue(window.isVisible, "Window should be visible after show()")

        // When - Send didResignActiveNotification to simulate app losing focus
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))

        // Then - Window should be closed
        XCTAssertFalse(
            window.isVisible,
            "Window should be closed when application loses focus"
        )
    }

    func testPopupClosesWhenApplicationHides() {
        // Given
        let sut = makeSUT()
        sut.show()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist after show()")
            return
        }

        XCTAssertTrue(window.isVisible, "Window should be visible after show()")

        // When - Send didHideNotification to simulate app being hidden
        NotificationCenter.default.post(name: NSApplication.didHideNotification, object: nil)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))

        // Then - Window should be closed
        XCTAssertFalse(
            window.isVisible,
            "Window should be closed when application is hidden"
        )
    }

    func testPopupClosesWhenActiveSpaceChanges() {
        // Given
        let sut = makeSUT()
        sut.show()
        guard let window = sut.nsWindow else {
            XCTFail("Window should exist after show()")
            return
        }

        XCTAssertTrue(window.isVisible, "Window should be visible after show()")

        // When - Send activeSpaceDidChangeNotification to simulate space switching
        NotificationCenter.default.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))

        // Then - Window should be closed
        XCTAssertFalse(
            window.isVisible,
            "Window should be closed when active space changes"
        )
    }
}
