import XCTest
@testable import VibeWave

final class LocalizationManagerTests: XCTestCase {
  private let languageKey = "app.language"
  private var originalLanguage: String?

  override func setUp() {
    super.setUp()
    originalLanguage = UserDefaults.standard.string(forKey: languageKey)
  }

  override func tearDown() {
    if let originalLanguage {
      UserDefaults.standard.set(originalLanguage, forKey: languageKey)
    } else {
      UserDefaults.standard.removeObject(forKey: languageKey)
    }
    super.tearDown()
  }

  func testLocalizedString_whenLanguageIsChinese_returnsChineseTranslation() {
    let manager = LocalizationManager()
    manager.setLanguage("zh_CN")

    XCTAssertEqual(manager.localizedString("nav.overview"), "总览")
  }

  func testLocalizedString_whenLanguageIsEnglish_returnsEnglishTranslation() {
    let manager = LocalizationManager()
    manager.setLanguage("en")

    XCTAssertEqual(manager.localizedString("nav.overview"), "Overview")
  }

  func testLocalizedString_whenLanguageUsesHyphenatedChineseCode_returnsChineseTranslation() {
    let manager = LocalizationManager()
    manager.setLanguage("zh-cn")

    XCTAssertEqual(manager.localizedString("nav.overview"), "总览")
  }
}
