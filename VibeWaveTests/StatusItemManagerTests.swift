import XCTest
@testable import VibeWave
import AppKit
import SwiftUI

/// Unit tests for StatusItemManager
///
/// These tests verify that StatusItemManager correctly manages the menu bar status item,
/// including creation, click handling, and popup window interaction.
final class StatusItemManagerTests: XCTestCase {

    // MARK: - Test Helper Methods

    /// Creates a test instance of StatusItemManager
    private func makeSUT() -> StatusItemManager {
        return StatusItemManager.shared
    }

    /// Verifies that the status item exists in the menu bar
    private func assertStatusItemExists(_ statusItem: NSStatusItem?, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(statusItem, "Status item should exist", file: file, line: line)
    }

    /// Verifies that the status item has a button
    private func assertStatusItemHasButton(_ statusItem: NSStatusItem?, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(statusItem?.button, "Status item should have a button", file: file, line: line)
    }

    /// Verifies that the status item is visible
    private func assertStatusItemIsVisible(_ statusItem: NSStatusItem?, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(statusItem, "Status item should exist to check visibility", file: file, line: line)
        XCTAssertTrue(statusItem?.isVisible ?? false, "Status item should be visible", file: file, line: line)
    }

    // MARK: - Status Item Creation Tests

    func testStatusItemManagerCreatesStatusItem() {
        // Given
        let sut = makeSUT()

        // When
        let statusItem = sut.statusItem

        // Then
        assertStatusItemExists(statusItem)
        assertStatusItemHasButton(statusItem)
    }

    func testStatusItemManagerStatusItemIsVisible() {
        // Given
        let sut = makeSUT()

        // When
        let statusItem = sut.statusItem

        // Then
        assertStatusItemIsVisible(statusItem)
    }

    func testStatusItemManagerStatusItemHasCustomImage() {
        // Given
        let sut = makeSUT()

        // When
        let statusItem = sut.statusItem
        let buttonImage = statusItem?.button?.image

        // Then
        XCTAssertNotNil(buttonImage, "Status item button should have an image")
    }

    func testStatusItemManagerStatusButtonRespondsToClick() {
        // Given
        let sut = makeSUT()
        let statusItem = sut.statusItem
        let button = statusItem?.button

        // When
        // Simulate a click event (this will fail initially since we haven't implemented the handler)

        // Then
        XCTAssertNotNil(button, "Status item button should exist")
        // We'll verify the action is properly set in GREEN phase
    }

    func testStatusItemManagerOpensPopupOnButtonClick() {
        // Given
        let sut = makeSUT()

        // When
        // Simulate clicking the status item button
        sut.handleStatusItemClick()

        // Then - After implementation, popup should be visible
        // For now we'll just check that the method exists
        // This test will help design the API in GREEN phase
    }
}
