import Foundation

public enum ChartDisplayMode: String, CaseIterable, Sendable {
    case bar
    case line

    public var iconName: String {
        switch self {
        case .bar:
            return "chart.bar.fill"
        case .line:
            return "chart.line.uptrend.xyaxis"
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .bar:
            return "柱状图"
        case .line:
            return "折线图"
        }
    }
}
