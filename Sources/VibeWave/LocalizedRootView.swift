import SwiftUI
import AppKit

public struct LocalizedRootView: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var settingsViewModel = SettingsViewModel.shared
    @State private var servicesStarted = false

    public init() {}

    public var body: some View {
        ContentView()
            .background(WindowAccessor())
            .preferredColorScheme(settingsViewModel.theme.colorScheme)
            .environmentObject(LocalizationManager.shared)
            .environment(\.locale, Locale(identifier: localizationManager.currentLanguage))
            .onAppear {
                _ = StatusItemManager.shared
                guard !servicesStarted else { return }
                guard ConfigService.shared.ensureDataSourceReadyOnLaunch() else {
                    NSApp.terminate(nil)
                    return
                }
                settingsViewModel.refreshDataSourcePathFromConfig()
                servicesStarted = true
                SyncCoordinator.shared.start()
                BackupCoordinator.shared.start()
            }
    }
}
