import Foundation
import Combine
import SwiftUI

public final class LocalizationManager: ObservableObject {
  public static let shared = LocalizationManager()
  
  @Published public private(set) var currentLanguage: String = "en" {
    didSet {
      userDefaults.set(currentLanguage, forKey: "app.language")
      objectWillChange.send()
    }
  }
  
  private let userDefaults = UserDefaults.standard
  private let resourcesBundle = ResourceBundleLocator.resourceBundle
  private var languageBundle: Bundle?
  
  public init() {
    // Load saved language preference
    if let savedLanguage = userDefaults.string(forKey: "app.language") {
      self.currentLanguage = normalizedLanguageCode(savedLanguage)
    } else {
      // Auto-detect language from system
      let preferredLanguages = NSLocale.preferredLanguages
      if preferredLanguages.contains(where: { $0.starts(with: "zh") }) {
        self.currentLanguage = "zh_CN"
      } else {
        self.currentLanguage = "en"
      }
    }
    
    setupBundle()
  }
  
  private func normalizedLanguageCode(_ language: String) -> String {
    let normalized = language.replacingOccurrences(of: "-", with: "_")
    if normalized.hasPrefix("zh") {
      return "zh_CN"
    }
    if normalized.hasPrefix("en") {
      return "en"
    }
    return normalized
  }

  private func localizationCandidates(for languageCode: String) -> [String] {
    let normalized = languageCode.replacingOccurrences(of: "-", with: "_")
    let languageOnly = normalized.split(separator: "_").first.map(String.init) ?? normalized

    var candidates = [
      normalized,
      normalized.lowercased(),
      normalized.replacingOccurrences(of: "_", with: "-"),
      normalized.lowercased().replacingOccurrences(of: "_", with: "-"),
      languageOnly,
      languageOnly.lowercased()
    ]

    if languageOnly == "zh" {
      candidates.append(contentsOf: ["zh_CN", "zh_cn", "zh-Hans", "zh_hans"])
    }

    if languageOnly == "en" {
      candidates.append("Base")
    }

    var seen = Set<String>()
    return candidates.filter { seen.insert($0.lowercased()).inserted }
  }

  private func bundle(for languageCode: String) -> Bundle? {
    for candidate in localizationCandidates(for: languageCode) {
      guard let matched = resourcesBundle.localizations.first(where: {
        $0.caseInsensitiveCompare(candidate) == .orderedSame
      }) else {
        continue
      }

      if let path = resourcesBundle.path(forResource: matched, ofType: "lproj"),
         let bundle = Bundle(path: path)
      {
        return bundle
      }
    }
    return nil
  }

  private func setupBundle() {
    let normalizedLanguage = normalizedLanguageCode(currentLanguage)
    if let selectedBundle = bundle(for: normalizedLanguage) {
      languageBundle = selectedBundle
      return
    }

    // Fall back to language code without region, then Base localization.
    if let languageCode = normalizedLanguage.split(separator: "_").first,
       let selectedBundle = bundle(for: String(languageCode))
    {
      languageBundle = selectedBundle
      return
    }

    languageBundle = bundle(for: "Base") ?? resourcesBundle
  }
  
  public func setLanguage(_ language: String) {
    currentLanguage = normalizedLanguageCode(language)
    setupBundle()
  }
  
  public func localizedString(_ key: String) -> String {
    // First try the selected language bundle
    if let languageBundle = languageBundle {
      let result = languageBundle.localizedString(forKey: key, value: nil, table: "Localizable")
      if result != key {
        return result
      }
    }
    
    // Fallback to resources bundle (English/Base)
    let fallback = resourcesBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    return fallback == key ? key : fallback
  }
  
  public func string(forKey key: String) -> String {
    localizedString(key)
  }
}
