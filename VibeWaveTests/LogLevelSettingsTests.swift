import XCTest
@testable import VibeWave

final class LogLevelSettingsTests: XCTestCase {
    func testSettingsViewModel_LoadsLogLevelFromUserDefaults() {
        let defaults = UserDefaults(suiteName: "log-level-load-tests")!
        defaults.removePersistentDomain(forName: "log-level-load-tests")
        defaults.set(SettingsViewModel.LogLevel.warn.rawValue, forKey: "log.level")

        let viewModel = SettingsViewModel(
            userDefaults: defaults,
            backupManager: nil,
            loadBackups: false
        )

        XCTAssertEqual(viewModel.logLevel, .warn)
    }

    func testSettingsViewModel_SavesLogLevelToUserDefaults() {
        let defaults = UserDefaults(suiteName: "log-level-save-tests")!
        defaults.removePersistentDomain(forName: "log-level-save-tests")

        let viewModel = SettingsViewModel(
            userDefaults: defaults,
            backupManager: nil,
            loadBackups: false
        )

        viewModel.logLevel = .debug
        viewModel.saveSettings()

        let stored = defaults.string(forKey: "log.level")
        XCTAssertEqual(stored, SettingsViewModel.LogLevel.debug.rawValue)
    }
}
