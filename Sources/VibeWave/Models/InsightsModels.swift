import Foundation
import CoreGraphics

public enum InsightMetric: String, CaseIterable, Sendable {
    case inputTokens
    case messages
    case cost

    public var displayName: String {
        switch self {
        case .inputTokens:
            return L10n.insightMetricInputTokens
        case .messages:
            return L10n.insightMetricMessages
        case .cost:
            return L10n.insightMetricCost
        }
    }
}

public enum DayTypeFilter: String, CaseIterable, Sendable {
    case all
    case weekdays
    case weekends

    public var displayName: String {
        switch self {
        case .all:
            return L10n.insightDayTypeAll
        case .weekdays:
            return L10n.insightDayTypeWeekdays
        case .weekends:
            return L10n.insightDayTypeWeekends
        }
    }
}

public enum ModelLensGroupBy: String, CaseIterable, Sendable {
    case model
    case provider

    public var displayName: String {
        switch self {
        case .model:
            return L10n.insightGroupByModel
        case .provider:
            return L10n.insightGroupByProvider
        }
    }
}

public enum ModelLensMetric: String, CaseIterable, Sendable {
    case inputTokens
    case outputTPS

    public var displayName: String {
        switch self {
        case .inputTokens:
            return L10n.insightMetricInputTokens
        case .outputTPS:
            return L10n.insightOutputTPS
        }
    }
}

public enum ModelLensSortKey: String, CaseIterable, Sendable {
    case inputTokens
    case outputTPS

    public var displayName: String {
        switch self {
        case .inputTokens:
            return "Input"
        case .outputTPS:
            return "TPS"
        }
    }
}

public enum SortDirection: String, Sendable {
    case descending
    case ascending

    public mutating func toggle() {
        self = self == .descending ? .ascending : .descending
    }
}

public struct DailyHeatPoint: Identifiable, Sendable {
    public var id: Int64 { dayStartMs }
    public let date: Date
    public let dayStartMs: Int64
    public let value: Double
    public var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    public init(date: Date, dayStartMs: Int64, value: Double) {
        self.date = date
        self.dayStartMs = dayStartMs
        self.value = value
    }
}

public struct HourlyIntensityPoint: Identifiable, Sendable {
    public var id: Int { hour }
    public let hour: Int
    public let value: Double

    public init(hour: Int, value: Double) {
        self.hour = hour
        self.value = value
    }
}

public struct WeekdayWeekendIntensity: Sendable {
    public let weekdayTotal: Double
    public let weekendTotal: Double
    public let weekdayAverage: Double
    public let weekendAverage: Double

    public init(
        weekdayTotal: Double,
        weekendTotal: Double,
        weekdayAverage: Double,
        weekendAverage: Double
    ) {
        self.weekdayTotal = weekdayTotal
        self.weekendTotal = weekendTotal
        self.weekdayAverage = weekdayAverage
        self.weekendAverage = weekendAverage
    }
}

public struct ModelLensPoint: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let dimensionName: String
    public let providerId: String
    public let value: Double
    public let outputTokens: Double
    public let durationSeconds: Double
    public let validDurationMessageRatio: Double
    public var dimensionId: String { dimensionName }
    public var validDurationCoverage: Double { validDurationMessageRatio }

    public init(
        dimensionName: String,
        providerId: String = "",
        value: Double,
        outputTokens: Double = 0,
        durationSeconds: Double = 0,
        validDurationMessageRatio: Double = 0
    ) {
        self.dimensionName = dimensionName
        self.providerId = providerId
        self.value = value
        self.outputTokens = outputTokens
        self.durationSeconds = durationSeconds
        self.validDurationMessageRatio = validDurationMessageRatio
    }

    public static func == (lhs: ModelLensPoint, rhs: ModelLensPoint) -> Bool {
        lhs.dimensionName == rhs.dimensionName &&
        lhs.providerId == rhs.providerId &&
        lhs.value == rhs.value &&
        lhs.outputTokens == rhs.outputTokens &&
        lhs.durationSeconds == rhs.durationSeconds &&
        lhs.validDurationMessageRatio == rhs.validDurationMessageRatio
    }
}

public struct ModelLensRow: Identifiable, Sendable, Equatable {
    public var id: String { "\(dimensionName)|\(providerId)" }
    public let dimensionName: String
    public let providerId: String
    public let inputTokens: Double
    public let outputTPS: Double
    public let outputTokens: Double
    public let durationSeconds: Double
    public let validDurationMessageRatio: Double

    public init(
        dimensionName: String,
        providerId: String = "",
        inputTokens: Double,
        outputTPS: Double,
        outputTokens: Double = 0,
        durationSeconds: Double = 0,
        validDurationMessageRatio: Double = 0
    ) {
        self.dimensionName = dimensionName
        self.providerId = providerId
        self.inputTokens = inputTokens
        self.outputTPS = outputTPS
        self.outputTokens = outputTokens
        self.durationSeconds = durationSeconds
        self.validDurationMessageRatio = validDurationMessageRatio
    }
}

public struct HeatmapRenderModel: Sendable, Equatable {
    public static let empty = HeatmapRenderModel(
        cells: [],
        monthLabels: [],
        scaledMetrics: ContributionHeatmapLayout.ScaledMetrics(
            cellSize: ContributionHeatmapLayout.baseCellSize,
            cellSpacing: ContributionHeatmapLayout.baseCellSpacing
        ),
        availableGridWidth: 0,
        maxValue: 0
    )

    public let cells: [ContributionHeatCell]
    public let monthLabels: [ContributionHeatmapLayout.MonthLabel]
    public let scaledMetrics: ContributionHeatmapLayout.ScaledMetrics
    public let availableGridWidth: CGFloat
    public let maxValue: Double

    public var isEmpty: Bool { cells.isEmpty }

    public var gridHeight: CGFloat {
        (CGFloat(7) * scaledMetrics.cellSize) + (CGFloat(6) * scaledMetrics.cellSpacing)
    }

    public init(
        cells: [ContributionHeatCell],
        monthLabels: [ContributionHeatmapLayout.MonthLabel],
        scaledMetrics: ContributionHeatmapLayout.ScaledMetrics,
        availableGridWidth: CGFloat,
        maxValue: Double
    ) {
        self.cells = cells
        self.monthLabels = monthLabels
        self.scaledMetrics = scaledMetrics
        self.availableGridWidth = availableGridWidth
        self.maxValue = maxValue
    }
}
