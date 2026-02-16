import Foundation
import os

public enum AppLogLevel: String, CaseIterable {
    case error
    case warn
    case info
    case debug

    public var displayName: String {
        switch self {
        case .error: return L10n.settingsLogLevelError
        case .warn: return L10n.settingsLogLevelWarn
        case .info: return L10n.settingsLogLevelInfo
        case .debug: return L10n.settingsLogLevelDebug
        }
    }

    internal var rank: Int {
        switch self {
        case .error: return 0
        case .warn: return 1
        case .info: return 2
        case .debug: return 3
        }
    }

    internal var osLogType: OSLogType {
        switch self {
        case .error: return .error
        case .warn: return .default
        case .info: return .info
        case .debug: return .debug
        }
    }
}
