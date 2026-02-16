import Foundation
import AppKit

/// Manages the menu bar status item for VibeWave
public final class StatusItemManager {

    // MARK: - Singleton

    public static let shared = StatusItemManager()

    // MARK: - Properties

    public private(set) var statusItem: NSStatusItem?

    /// The popup window that shows when clicking the status item
    private var popupWindow: MenuBarPopupWindow?

    /// Whether the popup is currently visible
    private var isPopupVisible = false

    // MARK: - Initialization

    private init() {
        setupStatusItem()
        setupPopupWindow()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = MenuBarIcon.image
            button.action = #selector(handleStatusItemClick)
            button.target = self
        }
    }

    private func setupPopupWindow() {
        popupWindow = MenuBarPopupWindow(statusItem: statusItem)
    }

    // MARK: - Click Handling

    @objc public func handleStatusItemClick() {
        togglePopup()
    }

    /// Toggles the popup window visibility based on actual window state
    public func togglePopup() {
        // Check actual window visibility instead of relying on isPopupVisible flag
        let isActuallyVisible = popupWindow?.nsWindow?.isVisible == true
        
        if isActuallyVisible {
            popupWindow?.close()
        } else {
            popupWindow?.show()
        }
    }

    /// Callback for toggling the popup window (kept for backward compatibility)
    public var onTogglePopup: (() -> Void)? {
        didSet {
            onTogglePopup = { [weak self] in
                self?.togglePopup()
            }
        }
    }
}
