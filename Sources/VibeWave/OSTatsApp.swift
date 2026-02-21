import SwiftUI
import AppKit

@main
public struct VibeWave: App {
    @ObservedObject var settingsViewModel = SettingsViewModel.shared
    @State private var databaseInitialized = false
    @State private var servicesStarted = false
    private let updateCheckWindowController = UpdateCheckWindowController()

    public init() {
        // Single instance enforcement: Check if another instance is already running
        let currentPID = NSRunningApplication.current.processIdentifier
        let bundleID = Bundle.main.bundleIdentifier
        let apps = NSWorkspace.shared.runningApplications
        if let other = apps.first(where: {
            $0.bundleIdentifier == bundleID &&
            $0.processIdentifier != currentPID
        }) {
            other.activate(options: .activateAllWindows)
            exit(0)
        }

        DatabaseInitializer.initialize()
    }

    public var body: some Scene {
        WindowGroup {
            LocalizedRootView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Go to Overview") {
                    NotificationCenter.default.post(name: .selectTabOverview, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Go to Projects") {
                    NotificationCenter.default.post(name: .selectTabProjects, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Go to Insights") {
                    NotificationCenter.default.post(name: .selectTabInsights, object: nil)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Go to History") {
                    NotificationCenter.default.post(name: .selectTabHistory, object: nil)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Go to Settings") {
                    NotificationCenter.default.post(name: .selectTabSettings, object: nil)
                }
                .keyboardShortcut("5", modifiers: .command)
            }

            CommandGroup(replacing: .appInfo) {
                Button(L10n.menuAbout) {
                    self.openAboutSettings()
                }
                Button(L10n.menuCheckForUpdates) {
                    Task {
                        await self.checkForUpdates()
                    }
                }
            }

            CommandGroup(replacing: .help) {
            }
        }
    }
    
    private func checkForUpdates() async {
        await MainActor.run {
            updateCheckWindowController.show(status: .checking)
        }
        
        let result = await UpdateCheckService.shared.checkForUpdates()
        
        await MainActor.run {
            switch result {
            case .upToDate:
                updateCheckWindowController.show(status: .upToDate(version: AppConfiguration.App.version))
            case .newVersionAvailable(let newRelease):
                updateCheckWindowController.release = newRelease
                updateCheckWindowController.show(status: .newVersion(current: AppConfiguration.App.version, latest: newRelease.version))
            case .error(let error):
                updateCheckWindowController.show(status: .error(error.localizedDescription))
            }
        }
    }
    
    private func openAboutSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .showSettingsAbout, object: nil)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowAccessorNSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowAccessorNSView: NSView {
    private var windowDelegate: FixedWidthWindowDelegate?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        guard let window = self.window else { return }
        
        windowDelegate = FixedWidthWindowDelegate()
        window.delegate = windowDelegate
        
        window.title = "VibeWave"
        
        FixedWidthWindowConfigurator.apply(to: window)
        
        // Correct width if needed
        DispatchQueue.main.async {
            let currentFrame = window.frame
            if currentFrame.width != 900 {
                var correctedFrame = currentFrame
                correctedFrame.size.width = 900
                window.setFrame(correctedFrame, display: true)
            }
        }
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        
        // Clean up delegate from old window
        if let oldWindow = self.window {
            oldWindow.delegate = nil
        }
    }
}

class FixedWidthWindowDelegate: NSObject, NSWindowDelegate {
    private let fixedWidth: CGFloat = FixedWidthWindowConfigurator.fixedWidth
    private let minHeight: CGFloat = FixedWidthWindowConfigurator.minHeight
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        return NSSize(width: fixedWidth, height: max(minHeight, frameSize.height))
    }
}
