import XCTest
import AppKit
import SwiftUI
@testable import VibeWave

final class OpenCodeConnectionPresentationTests: XCTestCase {
    @MainActor
    func testConnectionStatesRenderWithoutOpeningUserDatabase() async throws {
        _ = NSApplication.shared
        let suite = "VibeWave.StatusPresentation." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let localization = LocalizationManager(userDefaults: defaults, resourcesBundle: Bundle.module)
        for language in ["zh_CN", "en"] {
        localization.setLanguage(language)
        XCTAssertFalse(localization.localizedString("opencode.connection.viewUpdate").hasPrefix("opencode.connection."))
        let kinds: [OpenCodeSourceState.Kind] = [.connecting, .v2, .waiting, .historyIncomplete, .updateRequired, .failed]
        for kind in kinds {
            OpenCodeSourceStatus.shared.report(OpenCodeSourceState(kind: kind, completedSessions: 25,
                totalSessions: 80, missingSessions: 3, sessionUsageCount: kind == .v2 ? 2 : 0, lastSuccess: Date(timeIntervalSince1970: 1_792_100_000)))
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
            let view = NSHostingView(rootView: OpenCodeConnectionStatusView(alwaysVisible: true, localization: localization)
                .padding(16).frame(width: 740, height: 150, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.light))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 150),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.isReleasedWhenClosed = false
            window.contentView = view
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                XCTFail("Unable to render native connection state")
                return
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            XCTAssertGreaterThan(bitmap.pixelsWide, 0)
            if let path = ProcessInfo.processInfo.environment["VIBEWAVE_STATUS_CAPTURE_DIR"] {
                let directory = URL(fileURLWithPath: path)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: directory.appendingPathComponent(kind.rawValue + "-" + language + ".png"))
            }
            window.close()
        }
        }
    }
}
