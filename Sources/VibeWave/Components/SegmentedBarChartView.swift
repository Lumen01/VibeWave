import Foundation
import SwiftUI
import Charts

/// Horizontal segmented stacked bar chart showing Input Tokens by dimension (project or model)
public struct SegmentedBarChartView: View {
    let data: [SegmentedBarDataPoint]
    let isLoading: Bool
    let title: String
    let dimension: AggregationDimension

    @State private var selectedLabel: String?
    @State private var chartWidth: CGFloat = 800
    @State private var tooltipPosition: CGPoint?
    @State private var tooltipData: TooltipData?

    private var uniqueLabels: [String] {
        Array(Set(data.map { $0.label })).sorted()
    }

    private var uniqueDimensionValues: [String] {
        Array(Set(data.map { $0.dimensionValue }))
    }

    private var dimensionColors: [String: Color] {
        SegmentedBarColorAssignment.assignColors(to: uniqueDimensionValues)
    }

    private var yDomain: ClosedRange<Double> {
        let allValues = data.map { $0.value }
        let maxValue = allValues.max() ?? 0

        if data.isEmpty || maxValue == 0 {
            return 0...1
        }

        let padding = maxValue * 0.1
        return 0...(maxValue + padding)
    }

    private var visibleHours: [Int] {
        [0, 3, 6, 9, 12, 15, 18, 21]
    }

    public init(data: [SegmentedBarDataPoint], isLoading: Bool, title: String = "Input Tokens", dimension: AggregationDimension) {
        self.data = data
        self.isLoading = isLoading
        self.title = title
        self.dimension = dimension
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if data.isEmpty {
                Text(L10n.commonNoData)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                chartContent
            }
        }
        .frame(height: 280)
    }

    @ViewBuilder
    private var chartContent: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Time", point.label),
                y: .value("Input Tokens", point.value)
            )
            .foregroundStyle(by: .value("Dimension", point.dimensionValue))
        }
        .frame(height: 200)
        .padding(.horizontal, 20)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic) { value in
                if let label = value.as(String.self), shouldShowTick(label: label) {
                    AxisValueLabel {
                        if let hour = extractHour(label: label) {
                            Text("\(hour)")
                                .font(.caption)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let intValue = value.as(Double.self) {
                        Text(formatTokens(Int(intValue)))
                            .font(.caption)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(Color.primary.opacity(0.2))
            }
        }
        .chartYScale(domain: yDomain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .chartBackground { proxy in
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        chartWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { newWidth in
                        chartWidth = newWidth
                    }
                    .onChange(of: selectedLabel ?? "") { _ in
                        self.updateTooltipPosition(for: selectedLabel, proxy: proxy, geometry: geometry)
                    }
                    .onChange(of: geometry.size.width) { _ in
                        self.updateTooltipPosition(for: selectedLabel, proxy: proxy, geometry: geometry)
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            if let tooltipData = tooltipData, let tooltipPosition = tooltipPosition {
                tooltipView(for: tooltipData)
                    .position(x: tooltipPosition.x, y: tooltipPosition.y)
                    .zIndex(100)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                if let closestLabel = findClosestLabel(at: location, in: uniqueLabels, chartWidth: chartWidth) {
                    selectedLabel = closestLabel
                    tooltipData = buildTooltipData(for: closestLabel)
                }
            case .ended:
                selectedLabel = nil
                tooltipData = nil
            }
        }
    }

    @ViewBuilder
    private func tooltipView(for data: TooltipData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(L10n.chartTotal) \(formatTokens(Int(data.totalValue)))")
                .font(.caption)
                .fontWeight(.medium)

            Divider()

            ForEach(data.segments, id: \.dimensionValue) { segment in
                HStack(spacing: 8) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 8, height: 8)

                    Text(segment.dimensionValue)
                        .font(.caption)

                    Spacer()

                    Text(formatTokens(Int(segment.value)))
                        .font(.caption)

                    Text("(\(segment.percentage)%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    private func findClosestLabel(at location: CGPoint, in labels: [String], chartWidth: CGFloat) -> String? {
        let padding: CGFloat = 20
        let effectiveWidth = chartWidth - (padding * 2)

        guard effectiveWidth > 0, !labels.isEmpty else { return nil }

        let relativeX = (location.x - padding) / effectiveWidth
        let index = Int(relativeX * CGFloat(labels.count))

        let clampedIndex = max(0, min(index, labels.count - 1))
        return labels[clampedIndex]
    }

    private func updateTooltipPosition(for label: String?, proxy: ChartProxy, geometry: GeometryProxy) {
        if let label = label {
            let xPosition = proxy.position(forX: label) ?? 0
            let clampedX = min(max(xPosition, 60), geometry.size.width - 60)
            let tooltipY: CGFloat = 30
            tooltipPosition = CGPoint(x: clampedX, y: tooltipY)
        } else {
            tooltipPosition = nil
        }
    }

    private func buildTooltipData(for label: String) -> TooltipData {
        let relevantData = data.filter { $0.label == label }
        let totalValue = relevantData.reduce(0) { $0 + $1.value }

        let segments = relevantData.map { point -> TooltipSegment in
            let percentage = totalValue > 0 ? Int((point.value / totalValue) * 100) : 0
            return TooltipSegment(
                dimensionValue: point.dimensionValue,
                value: point.value,
                percentage: percentage,
                color: dimensionColors[point.dimensionValue] ?? .gray
            )
        }.sorted { $0.value > $1.value }

        return TooltipData(label: label, totalValue: totalValue, segments: segments)
    }

    private func shouldShowTick(label: String) -> Bool {
        let parts = label.components(separatedBy: " ")
        guard parts.count == 2 else { return false }
        let hourStr = parts[1]
        guard let hour = Int(hourStr) else { return false }
        return visibleHours.contains(hour)
    }

    private func extractHour(label: String) -> Int? {
        let parts = label.components(separatedBy: " ")
        guard parts.count == 2 else { return nil }
        return Int(parts[1])
    }

    private func formatTokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return "\(value)"
        }
    }
}

private struct TooltipData {
    let label: String
    let totalValue: Double
    let segments: [TooltipSegment]
}

private struct TooltipSegment: Identifiable {
    let id = UUID()
    let dimensionValue: String
    let value: Double
    let percentage: Int
    let color: Color
}
