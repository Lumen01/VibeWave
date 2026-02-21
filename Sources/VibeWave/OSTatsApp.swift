import SwiftUI
import AppKit

@main
public struct VibeWave: App {
    @ObservedObject var settingsViewModel = SettingsViewModel.shared
    @State private var databaseInitialized = false
    @State private var servicesStarted = false

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
        let result = await UpdateCheckService.shared.checkForUpdates()
        
        await MainActor.run {
            switch result {
            case .upToDate:
                showUpToDateAlert()
            case .newVersionAvailable(let release):
                showUpdateAvailableAlert(release: release)
            case .error(let error):
                showUpdateErrorAlert(error: error)
            }
        }
    }
    
    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = AppConfiguration.App.name
        alert.informativeText = L10n.aboutUpToDate
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showUpdateAvailableAlert(release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = L10n.aboutNewVersionAvailable
        alert.informativeText = "\(L10n.aboutCurrentVersion) \(AppConfiguration.App.version)\n\(L10n.aboutLatestVersion) \(release.version)\n\n\(release.body ?? L10n.aboutReleaseNotes)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.aboutViewRelease)
        alert.addButton(withTitle: L10n.aboutLater)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            UpdateCheckService.shared.openReleasePage(url: release.htmlUrl)
        }
    }
    
    private func showUpdateErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = AppConfiguration.App.name
        alert.informativeText = "\(L10n.aboutUpdateError): \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
