import XCTest
@testable import VibeWave

final class SettingsSyncStrategyPersistenceTests: XCTestCase {
    func testDefaultsToAutoWhenUnset() {
        let defaults = UserDefaults(suiteName: "sync-strategy-default-tests")!
        defaults.removePersistentDomain(forName: "sync-strategy-default-tests")

        let viewModel = SettingsViewModel(
            userDefaults: defaults,
            backupManager: nil,
            loadBackups: false
        )

        XCTAssertEqual(viewModel.syncStrategy, .auto)
    }

    func testMigratesLegacyAutoSyncDisabledToInterval() {
        let defaults = UserDefaults(suiteName: "sync-strategy-migration-tests")!
        defaults.removePersistentDomain(forName: "sync-strategy-migration-tests")
        defaults.set(false, forKey: "autoSyncEnabled")

        let viewModel = SettingsViewModel(
            userDefaults: defaults,
            backupManager: nil,
            loadBackups: false
        )

        XCTAssertEqual(viewModel.syncStrategy, .minutes5)
    }

    func testPersistsSyncStrategyRawValue() {
        let defaults = UserDefaults(suiteName: "sync-strategy-persist-tests")!
        defaults.removePersistentDomain(forName: "sync-strategy-persist-tests")

        let viewModel = SettingsViewModel(
            userDefaults: defaults,
            backupManager: nil,
            loadBackups: false
        )

        viewModel.syncStrategy = .minutes10
        viewModel.saveSettings()

        XCTAssertEqual(defaults.string(forKey: "sync.strategy"), SyncStrategy.minutes10.rawValue)
    }

    func testPostsSyncSettingsDidChangeWithStrategy() {
        let defaults = UserDefaults(suiteName: "sync-strategy-notification-tests")!
        defaults.removePersistentDomain(forName: "sync-strategy-notification-tests")
        let notificationCenter = NotificationCenter()
        let expectation = expectation(description: "sync strategy posted")

        let observer = notificationCenter.addObserver(
            forName: .syncSettingsDidChange,
            object: nil,
            queue: .main
        ) { notification in
            let rawValue = notification.userInfo?["syncStrategy"] as? String
            XCTAssertEqual(rawValue, SyncStrategy.minutes1.rawValue)
            expectation.fulfill()
        }

        let viewModel = SettingsViewModel(
            userDefaults: defaults,
            backupManager: nil,
            loadBackups: false,
            notificationCenter: notificationCenter
        )

        viewModel.syncStrategy = .minutes1
        viewModel.saveSettings()

        wait(for: [expectation], timeout: 1.0)
        notificationCenter.removeObserver(observer)
    }
}
