import XCTest
import SwiftUI
@testable import VibeWave

final class SettingsIconStyleTests: XCTestCase {
    func testSettingsSectionIconUsesAccentColor() {
        XCTAssertEqual(DesignTokens.Colors.settingsSectionIcon, .accentColor)
    }
}
