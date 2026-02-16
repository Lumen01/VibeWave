import Foundation
import SwiftUI

/// Displays color-to-dimension-value mapping legend for segmented bar charts
/// Shows Top 6 colors + gray for "Other" based on SegmentedBarColorAssignment
public struct DimensionLegend: View {
    /// List of unique dimension values to display (e.g., project names or model names)
    public let dimensionValues: [String]
    /// Current aggregation dimension (.project or .model)
    public let dimension: AggregationDimension

    /// Creates legend with dimension values and current dimension
    /// - Parameters:
    ///   - dimensionValues: List of unique dimension values to display
    ///   - dimension: Current aggregation dimension
    public init(dimensionValues: [String], dimension: AggregationDimension) {
        self.dimensionValues = dimensionValues
        self.dimension = dimension
    }

    private var sortedValues: [String] {
        dimensionValues.sorted()
    }

    private var colorMapping: [String: Color] {
        SegmentedBarColorAssignment.assignColors(to: dimensionValues)
    }

    public var body: some View {
        if sortedValues.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 16) {
                ForEach(sortedValues, id: \.self) { value in
                    legendItem(for: value)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func legendItem(for value: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(colorMapping[value] ?? SegmentedBarColorAssignment.otherColor)
                .frame(width: 10, height: 10)

            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
