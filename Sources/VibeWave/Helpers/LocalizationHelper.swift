import SwiftUI

extension String {
  /// Get localized string using LocalizationManager
  public var localized: String {
    LocalizationManager.shared.localizedString(self)
  }
}

/// Helper function for dynamic localization
public func LocalizedString(_ key: String) -> String {
  LocalizationManager.shared.localizedString(key)
}
