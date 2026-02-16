import XCTest
@testable import VibeWave

final class SettingsAutoSaveTests: XCTestCase {
    func testSettingsViewModel_AutoSavesOnChange() {
        let defaults = UserDefaults(suiteName: "settings-autosave-tests")!
        defaults.removePersistentDomain(forName: "settings-autosave-tests")

        let viewModel = SettingsViewModel(
            userDefaults: defaults,
            backupManager: nil,
            loadBackups: false
        )

        viewModel.logLevel = .error

        let expectation = expectation(description: "auto save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let stored = defaults.string(forKey: "log.level")
            XCTAssertEqual(stored, SettingsViewModel.LogLevel.error.rawValue)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testSettingsViewModel_DoesNotAutoSaveOnInit() {
        let defaults = UserDefaults(suiteName: "settings-autosave-init-tests")!
        defaults.removePersistentDomain(forName: "settings-autosave-init-tests")

        _ = SettingsViewModel(
            userDefaults: defaults,
            backupManager: nil,
            loadBackups: false
        )

        let expectation = expectation(description: "no auto save on init")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertNil(defaults.object(forKey: "log.level"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
