import XCTest
@testable import VibeWave

final class SettingsViewModelExtensionsTests: XCTestCase {
    
    // MARK: - AppTheme Tests
    
    func testAppThemeDisplayName_returnsLocalizedNames() {
        let manager = LocalizationManager.shared
        let originalLanguage = manager.currentLanguage
        defer { manager.setLanguage(originalLanguage) }

        manager.setLanguage("zh_CN")
        XCTAssertEqual(SettingsViewModel.AppTheme.system.displayName, "系统")
        XCTAssertEqual(SettingsViewModel.AppTheme.light.displayName, "浅色")
        XCTAssertEqual(SettingsViewModel.AppTheme.dark.displayName, "深色")

        manager.setLanguage("en")
        XCTAssertEqual(SettingsViewModel.AppTheme.system.displayName, "System")
        XCTAssertEqual(SettingsViewModel.AppTheme.light.displayName, "Light")
        XCTAssertEqual(SettingsViewModel.AppTheme.dark.displayName, "Dark")
    }
    
    func testAppThemeIcon_returnsCorrectSFSymbols() {
        // Test all enum cases
        XCTAssertEqual(SettingsViewModel.AppTheme.system.icon, "circle.lefthalf.filled")
        XCTAssertEqual(SettingsViewModel.AppTheme.light.icon, "sun.max")
        XCTAssertEqual(SettingsViewModel.AppTheme.dark.icon, "moon")
    }
    
    // MARK: - Convenience Method Tests

    func testUpdateBackupRetention_updatesValueAndSaves() {
        // Arrange
        let viewModel = SettingsViewModel()
        let newValue = 8
        
        // Act
        viewModel.updateBackupRetention(newValue)
        
        // Assert
        XCTAssertEqual(viewModel.backupRetentionCount, newValue)
        // Verify save was called indirectly
        let savedValue = UserDefaults.standard.integer(forKey: "backup.maxCount")
        XCTAssertEqual(savedValue, newValue)
    }
    
    func testUpdateBackupInterval_updatesValueAndSaves() {
        // Arrange
        let viewModel = SettingsViewModel()
        let newValue = 12
        
        // Act
        viewModel.updateBackupInterval(newValue)
        
        // Assert
        XCTAssertEqual(viewModel.backupIntervalHours, newValue)
        // Verify save was called indirectly
        let savedValue = UserDefaults.standard.integer(forKey: "backup.interval")
        XCTAssertEqual(savedValue, newValue)
    }
    
    func testUpdateBackupRetention_clampsValues() {
        // Arrange
        let viewModel = SettingsViewModel()
        
        // Test below minimum
        viewModel.updateBackupRetention(0)
        XCTAssertGreaterThanOrEqual(viewModel.backupRetentionCount, 1)
        
        // Test above maximum
        viewModel.updateBackupRetention(100)
        XCTAssertLessThanOrEqual(viewModel.backupRetentionCount, 10)
    }
    
    func testUpdateBackupInterval_validatesValues() {
        // Arrange
        let viewModel = SettingsViewModel()
        
        // Test invalid value (should default to supported value)
        viewModel.updateBackupInterval(7)
        // Should set to one of the supported values (6, 12, 24, 48)
        let supportedValues = [6, 12, 24, 48]
        XCTAssertTrue(supportedValues.contains(viewModel.backupIntervalHours))
    }
}
