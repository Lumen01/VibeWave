import XCTest
@testable import VibeWave

final class SettingsDataSourcePathRefreshTests: XCTestCase {
    override func tearDown() {
        ConfigService.shared.resetToDefault()
        super.tearDown()
    }

    func testRefreshDataSourcePathFromConfig_UsesLatestPersistedPath() {
        let defaults = UserDefaults(suiteName: "settings-data-source-refresh-tests")!
        defaults.removePersistentDomain(forName: "settings-data-source-refresh-tests")

        let stalePath = "/tmp/stale/opencode.db"
        let latestPath = "/tmp/latest/opencode.db"

        ConfigService.shared.importPath = stalePath

        let viewModel = SettingsViewModel(
            userDefaults: defaults,
            backupManager: nil,
            loadBackups: false
        )
        XCTAssertEqual(viewModel.dataSourcePath, stalePath)

        ConfigService.shared.importPath = latestPath

        viewModel.refreshDataSourcePathFromConfig()

        XCTAssertEqual(viewModel.dataSourcePath, latestPath)
    }
}
