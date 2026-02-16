import Foundation
import AppKit
import SwiftUI

/// Custom NSWindow for displaying menu bar popup with visual customization
public final class MenuBarPopupWindow {

    // MARK: - Properties

    /// The underlying NSWindow instance
    public var nsWindow: NSWindow?

    /// Hosting controller for the SwiftUI content
    private let hostingController: NSHostingController<MenuBarPopupView>

    /// Reference to the menu bar status item for positioning
    private let statusItem: NSStatusItem?

    /// Fixed window width
    private let windowWidth: CGFloat = 340

    /// Local event monitor for clicks within the app
    private var localEventMonitor: Any?

    /// Global event monitor for clicks outside the app (e.g., other status bar items)
    private var globalEventMonitor: Any?

    /// Notification observers for lifecycle events
    private var notificationObservers: [AnyObject] = []

    /// Closure called when window closes
    public var onWindowClose: (() -> Void)?

    // MARK: - Initialization

    public init(statusItem: NSStatusItem?) {
        self.statusItem = statusItem

        let menuBarView = MenuBarPopupView()
        hostingController = NSHostingController(rootView: menuBarView)

        let frame = NSRect(x: 0, y: 0, width: windowWidth, height: 400)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.level = .popUpMenu
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 16
        hostingController.view.layer?.masksToBounds = true

        nsWindow = window
        setupLifecycleObservers()
    }

    // MARK: - Lifecycle Management

    private func setupLifecycleObservers() {
        let resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.close()
        }
        notificationObservers.append(resignActiveObserver)

        let didHideObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.close()
        }
        notificationObservers.append(didHideObserver)

        let spaceChangeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.close()
        }
        notificationObservers.append(spaceChangeObserver)
    }

    private func removeLifecycleObservers() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    // MARK: - Display Methods

    /// Shows the popup window positioned below the status bar icon
    public func show() {
        guard let window = nsWindow,
              let screen = NSScreen.main else {
            nsWindow?.orderFront(nil)
            return
        }

        let adaptiveHeight = hostingController.view.fittingSize.height

        var xPos: CGFloat = 0
        if let statusItem = statusItem,
           let button = statusItem.button,
           let buttonWindow = button.window {
            let buttonGlobalFrame = button.convert(button.bounds, to: nil)
            let windowFrame = buttonWindow.frame
            let buttonGlobalOrigin = NSPoint(
                x: windowFrame.origin.x + buttonGlobalFrame.origin.x,
                y: windowFrame.origin.y + buttonGlobalFrame.origin.y
            )
            xPos = buttonGlobalOrigin.x
        }

        let screenFrame = screen.visibleFrame
        
        // Calculate Y position: place window at top of screen, just below the menu bar
        // In macOS coordinate system, origin is at bottom-left, so maxY is the top
        let yPos = screenFrame.maxY - adaptiveHeight
        
        let clampedX = max(
            screenFrame.minX,
            min(xPos, screenFrame.maxX - windowWidth)
        )

        window.setFrame(
            NSRect(x: clampedX, y: yPos, width: windowWidth, height: adaptiveHeight),
            display: false
        )

        window.alphaValue = 0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1
        }

        setupEventMonitoring()
    }

    /// Closes the popup window
    public func close() {
        guard let window = nsWindow else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.removeEventMonitoring()
            self.removeLifecycleObservers()
            window.orderOut(nil)
            window.alphaValue = 1
        }
    }

    // MARK: - Deinitialization

    deinit {
        removeLifecycleObservers()
        removeEventMonitoring()
    }

    // MARK: - External Click Handling

    /// Sets up both local and global event monitoring
    private func setupEventMonitoring() {
        setupLocalEventMonitor()
        setupGlobalEventMonitor()
    }

    /// Monitors clicks within the app
    private func setupLocalEventMonitor() {
        guard localEventMonitor == nil else { return }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.nsWindow else { return event }
            if window.isVisible && self.isClickOutsideWindow(windowFrame: window.frame) {
                self.close()
            }
            return event
        }
    }

    /// Monitors clicks outside the app (e.g., other status bar items)
    private func setupGlobalEventMonitor() {
        guard globalEventMonitor == nil else { return }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let window = self.nsWindow, window.isVisible else { return }
            self.close()
        }
    }

    /// Removes all event monitoring
    private func removeEventMonitoring() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }

    /// Checks if a click location is outside the window bounds
    private func isClickOutsideWindow(windowFrame: NSRect) -> Bool {
        let mouseLocation = NSEvent.mouseLocation

        switch windowFrame.contains(mouseLocation) {
        case true:
            return false
        case false:
            return true
        }
    }

    /// Handles external click events (for testing purposes)
    public func handleExternalClick() {
        guard let window = nsWindow, window.isVisible else { return }
        close()
    }
}
