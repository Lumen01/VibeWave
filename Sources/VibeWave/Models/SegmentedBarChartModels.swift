import Foundation
import SwiftUI

/// Dimension for aggregating segmented bar chart data
public enum AggregationDimension: String, CaseIterable {
    case project
    case model

    public var rawValue: String {
        switch self {
        case .project: return L10n.dimensionProject
        case .model: return L10n.dimensionModel
        }
    }

    public var displayName: String {
        rawValue
    }
}

/// Data point for segmented bar chart, conforming to Identifiable for Swift Charts
public struct SegmentedBarDataPoint: Identifiable, Equatable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let label: String
    public let dimension: AggregationDimension
    public let dimensionValue: String
    public let value: Double

    public init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        label: String,
        dimension: AggregationDimension,
        dimensionValue: String,
        value: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.label = label
        self.dimension = dimension
        self.dimensionValue = dimensionValue
        self.value = value
    }
}

/// Provides colors for Top 6 + Other dimension values
public struct SegmentedBarColorAssignment {
    /// Top 6 colors for prominent dimension values
    public static let topColors: [Color] = [
        .blue,
        .green,
        .orange,
        .purple,
        .pink,
        .cyan
    ]

    /// Color for "Other" category (gray)
    public static let otherColor: Color = .gray

    /// Assigns colors to dimension values, with top 6 getting distinct colors
    /// and remaining values getting the "Other" color
    /// - Parameter dimensionValues: List of unique dimension values
    /// - Returns: Dictionary mapping dimension value to assigned Color
    public static func assignColors(to dimensionValues: [String]) -> [String: Color] {
        var result: [String: Color] = [:]

        // Sort dimension values for consistent ordering
        let sortedValues = dimensionValues.sorted()

        // Assign top 6 colors
        let topCount = min(6, sortedValues.count)
        for index in 0..<topCount {
            result[sortedValues[index]] = topColors[index]
        }

        // Assign "Other" color to remaining values
        if topCount < sortedValues.count {
            for index in topCount..<sortedValues.count {
                result[sortedValues[index]] = otherColor
            }
        }

        return result
    }

    /// Gets color for a specific dimension value based on its rank
    /// - Parameters:
    ///   - dimensionValue: The dimension value to get color for
    ///   - allValues: All dimension values to determine rank
    /// - Returns: Color assigned to the dimension value
    public static func colorFor(
        dimensionValue: String,
        in allValues: [String]
    ) -> Color {
        let sortedValues = allValues.sorted()
        guard let index = sortedValues.firstIndex(of: dimensionValue) else {
            return otherColor
        }

        if index < 6 {
            return topColors[index]
        } else {
            return otherColor
        }
    }
}
