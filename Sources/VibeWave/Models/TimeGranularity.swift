import Foundation

public enum TimeGranularity: String, CaseIterable {
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var tableName: String {
        switch self {
        case .hourly: return "hourly_stats"
        case .daily: return "daily_stats"
        case .weekly: return "weekly_stats"
        case .monthly: return "monthly_stats"
        }
    }

    var bucketIntervalMs: Int64 {
        switch self {
        case .hourly: return 3600 * 1000       // 1 hour
        case .daily: return 86400 * 1000      // 1 day
        case .weekly: return 604800 * 1000    // 7 days
        case .monthly: return 2592000 * 1000  // 30 days (approximate)
        }
    }

    /// 根据时间范围确定粒度 (用于历史图表)
    public static func from(timeRange: HistoryTimeRangeOption) -> TimeGranularity {
        switch timeRange {
        case .last24Hours:
            return .hourly
        case .last30Days:
            return .daily
        case .allTime:
            return .monthly
        }
    }
}
