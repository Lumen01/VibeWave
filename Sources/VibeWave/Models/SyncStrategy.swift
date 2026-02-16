import Foundation

public enum SyncStrategy: String, CaseIterable, Equatable {
    case auto = "auto"
    case minutes1 = "1m"
    case minutes5 = "5m"
    case minutes10 = "10m"
    case minutes15 = "15m"

    public var intervalSeconds: TimeInterval? {
        switch self {
        case .auto: return nil
        case .minutes1: return 60
        case .minutes5: return 300
        case .minutes10: return 600
        case .minutes15: return 900
        }
    }

    public var displayName: String {
        switch self {
        case .auto: return L10n.settingsSyncAuto
        case .minutes1: return L10n.settingsSync1Min
        case .minutes5: return L10n.settingsSync5Min
        case .minutes10: return L10n.settingsSync10Min
        case .minutes15: return L10n.settingsSync15Min
        }
    }

    public var detailDescription: String {
        switch self {
        case .auto:
            return L10n.settingsSyncAutoDesc
        case .minutes1, .minutes5, .minutes10, .minutes15:
            return L10n.settingsSyncIntervalDesc
        }
    }

    public static let sliderOptions: [SyncStrategy] = [
        .auto, .minutes1, .minutes5, .minutes10, .minutes15
    ]

    public static func index(for strategy: SyncStrategy) -> Int {
        sliderOptions.firstIndex(of: strategy) ?? 0
    }

    public static func strategy(for index: Int) -> SyncStrategy {
        let maxIndex = max(0, sliderOptions.count - 1)
        let clampedIndex = max(0, min(index, maxIndex))
        return sliderOptions[clampedIndex]
    }

    public static func load(from defaults: UserDefaults) -> SyncStrategy {
        if let raw = defaults.string(forKey: "sync.strategy"), let strategy = SyncStrategy(rawValue: raw) {
            return strategy
        }
        if defaults.object(forKey: "autoSyncEnabled") != nil {
            return defaults.bool(forKey: "autoSyncEnabled") ? .auto : .minutes5
        }
        return .auto
    }
}
