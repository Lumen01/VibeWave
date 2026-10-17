import SwiftUI
import AppKit

struct OpenCodeConnectionStatusView: View {
    @ObservedObject private var status = OpenCodeSourceStatus.shared
    @ObservedObject private var localization: LocalizationManager
    @AppStorage("opencode.v2.connectionAcknowledged") private var acknowledged = false
    @AppStorage("opencode.lastUpgradeNotice") private var lastNotice = ""
    @State private var showUpgradeAlert = false
    var alwaysVisible = false

    init(alwaysVisible: Bool = false, localization: LocalizationManager = .shared) {
        self.alwaysVisible = alwaysVisible
        _localization = ObservedObject(wrappedValue: localization)
    }

    private var state: OpenCodeSourceState { status.state }
    private var isBusy: Bool { state.kind == .connecting || state.kind == .checking }
    private var isProblem: Bool { [.waiting, .failed, .historyIncomplete, .updateRequired].contains(state.kind) }
    private func text(_ key: String) -> String { localization.localizedString("opencode.connection." + key) }
    private var title: String { text(state.kind.rawValue + ".title") }
    private var detail: String {
        switch state.kind {
        case .connecting:
            return String(format: text("connecting.detail"), state.completedSessions, state.totalSessions)
        case .v2 where state.sessionUsageCount > 0:
            return String(format: text("v2.sessionUsageDetail"), state.sessionUsageCount)
        case .historyIncomplete:
            return String(format: text("historyIncomplete.detail"), state.missingSessions)
        default: return text(state.kind.rawValue + ".detail")
        }
    }
    private var visible: Bool {
        alwaysVisible || isProblem || state.kind == .connecting || (state.kind == .v2 && !acknowledged)
    }

    var body: some View {
        if visible {
            HStack(alignment: .top, spacing: 12) {
                if isBusy {
                    ProgressView().controlSize(.small).accessibilityLabel(title)
                } else {
                    Image(systemName: isProblem ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundStyle(isProblem ? Color.orange : Color.accentColor)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let date = state.lastSuccess {
                        Text(text("lastSuccess") + " " + date.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if state.kind == .updateRequired {
                    Button(text("viewUpdate")) { openUpdates() }.controlSize(.small)
                } else if isProblem {
                    Button(text("retry")) { SyncCoordinator.shared.performInitialSync() }.controlSize(.small)
                } else if state.kind == .v2 && !alwaysVisible {
                    Button(text("dismiss")) { acknowledged = true }.controlSize(.small)
                }
            }
            .padding(alwaysVisible ? 0 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alwaysVisible ? Color.clear : Color(nsColor: .controlBackgroundColor))
            .onAppear { presentNoticeIfNeeded() }
            .onChange(of: state.kind) { presentNoticeIfNeeded() }
            .alert(text("updateRequired.title"), isPresented: $showUpgradeAlert) {
                Button(text("viewUpdate")) { openUpdates() }
                Button(text("later"), role: .cancel) {}
            } message: { Text(text("updateRequired.detail")) }
        }
    }

    private func presentNoticeIfNeeded() {
        guard !alwaysVisible, state.kind == .updateRequired else { return }
        let notice = AppConfiguration.App.version + ":" + ConfigService.shared.importPath
        guard notice != lastNotice else { return }
        lastNotice = notice
        showUpgradeAlert = true
    }

    private func openUpdates() {
        NSWorkspace.shared.open(AppConfiguration.Links.github.appendingPathComponent("releases/latest"))
    }
}
