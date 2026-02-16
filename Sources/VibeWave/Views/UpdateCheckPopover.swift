import SwiftUI
import AppKit

enum UpdateCheckDisplayStatus {
    case checking
    case upToDate(version: String)
    case newVersion(current: String, latest: String)
    case error(String)
}

class UpdateCheckWindowController: NSObject {
    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    var release: GitHubRelease?
    
    func show(status: UpdateCheckDisplayStatus) {
        // Close existing window first if any
        if let existingWindow = window {
            existingWindow.close()
        }
        
        let contentView = AnyView(updateCheckView(status: status))
        hostingView = NSHostingView(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.menuCheckForUpdates
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @ViewBuilder
    private func updateCheckView(status: UpdateCheckDisplayStatus) -> some View {
        VStack(spacing: 16) {
            switch status {
            case .checking:
                checkingView
            case .upToDate(let version):
                upToDateView(version: version)
            case .newVersion(let current, let latest):
                newVersionView(current: current, latest: latest)
            case .error(let message):
                errorView(message: message)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
    
    private var checkingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text(L10n.aboutCheckingForUpdates)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
    
    private func upToDateView(version: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)
            
            Text(L10n.aboutUpToDate)
                .font(.headline)
            
            Text("\(AppConfiguration.App.name) v\(version)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("OK") {
                self.close()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
    
    private func newVersionView(current: String, latest: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.blue)
            
            Text(L10n.aboutNewVersionAvailable)
                .font(.headline)
            
            HStack(spacing: 8) {
                Text("v\(current)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("→")
                    .foregroundColor(.secondary)
                
                Text("v\(latest)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 12) {
                Button(L10n.aboutLater) {
                    self.close()
                }
                .controlSize(.small)
                
                Button(L10n.aboutViewRelease) {
                    if let release = self.release {
                        Task {
                            await UpdateCheckService.shared.openReleasePage(url: release.htmlUrl)
                        }
                    }
                    self.close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            
            Text(L10n.aboutUpdateError)
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("OK") {
                self.close()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
    
    func close() {
        window?.close()
        window = nil
        hostingView = nil
    }
}
