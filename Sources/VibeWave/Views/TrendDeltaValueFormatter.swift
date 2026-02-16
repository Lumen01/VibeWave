import Foundation

public enum TrendDeltaValueFormatter {
    public static func formatAxisTokens(_ value: Double) -> String {
        if value >= 0 {
            return formatInputTokensCompact(value)
        }
        return "-\(formatInputTokensCompact(abs(value)))"
    }

    public static func formatAxisHours(_ value: Double) -> String {
        if value >= 0 {
            return "\(formatHours(value))h"
        }
        return "-\(formatHours(abs(value)))h"
    }

    public static func formatSignedTokens(_ value: Double) -> String {
        if value > 0 {
            return "+\(formatInputTokensCompact(value))"
        }
        if value < 0 {
            return "-\(formatInputTokensCompact(abs(value)))"
        }
        return "0"
    }

    public static func formatSignedHours(_ value: Double) -> String {
        if value > 0 {
            return "+\(formatHours(abs(value)))h"
        }
        if value < 0 {
            return "-\(formatHours(abs(value)))h"
        }
        return "0h"
    }

    public static func formatHours(_ value: Double) -> String {
        let absolute = abs(value)
        if absolute >= 100 {
            return String(format: "%.0f", absolute)
        }
        if absolute >= 10 {
            if absolute.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", absolute)
            }
            return String(format: "%.1f", absolute)
        }
        return String(format: "%.1f", absolute)
    }
}
