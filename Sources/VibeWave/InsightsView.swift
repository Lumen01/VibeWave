import Foundation
import SwiftUI
import Charts

public struct InsightsView: View {
    @StateObject private var viewModel: InsightsViewModel

    public init(viewModel: InsightsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                UserRhythmSectionView(viewModel: viewModel)
                ModelLensSectionView(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle(L10n.navInsights)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text("VibeWave")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .onAppear {
            viewModel.loadIfNeeded()
        }
    }
}

private struct UserRhythmSectionView: View {
    @ObservedObject var viewModel: InsightsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.insightUserRhythm)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(width: 120, alignment: .leading)

                Spacer()

                Picker("", selection: $viewModel.userRhythmMetric) {
                    ForEach(InsightMetric.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

                VStack(spacing: 16) {
                ContributionHeatmapView(
                    renderModel: viewModel.heatmapRenderModel,
                    isLoading: viewModel.isUserRhythmLoading,
                    onContainerWidthChange: viewModel.updateHeatmapContainerWidth,
                    metric: viewModel.userRhythmMetric
                )

                Divider()
                    .padding(.horizontal, 12)

                HStack(spacing: 8) {
                    Text(L10n.insightWorkIntensity)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $viewModel.intensityMetric) {
                        Text(L10n.insightFilterMetricInputTokens).tag(InsightMetric.inputTokens)
                        Text(L10n.insightFilterMetricMessages).tag(InsightMetric.messages)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    Picker("", selection: $viewModel.dayTypeFilter) {
                        ForEach(DayTypeFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 16) {
                    WeekdayWeekendComparisonView(stats: viewModel.weekdayWeekendIntensity, metric: viewModel.intensityMetric)
                    HourlyIntensityChartView(points: viewModel.hourlyIntensity, metric: viewModel.intensityMetric)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

private struct ModelLensSectionView: View {
    @ObservedObject var viewModel: InsightsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.insightModelLens)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(width: 120, alignment: .leading)

                Spacer()

                Picker("", selection: $viewModel.modelLensGroupBy) {
                    ForEach(ModelLensGroupBy.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ModelLensChartView(
                rows: viewModel.displayedModelLensRows,
                groupBy: viewModel.modelLensGroupBy,
                isLoading: viewModel.isModelLensLoading,
                sortKey: $viewModel.modelLensSortKey,
                sortDirection: $viewModel.modelLensSortDirection
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

private struct ContributionHeatmapView: View {
    let renderModel: HeatmapRenderModel
    let isLoading: Bool
    let onContainerWidthChange: (CGFloat) -> Void
    let metric: InsightMetric

    private let weekdayLabelWidth: CGFloat = 30
    private let axisSpacing: CGFloat = 8
    private let monthLabelHeight: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading && renderModel.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else if renderModel.isEmpty {
                Text(L10n.commonNoData)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: axisSpacing) {
                        Color.clear
                            .frame(width: weekdayLabelWidth, height: monthLabelHeight)

                        ZStack(alignment: .topLeading) {
                            ForEach(renderModel.monthLabels) { label in
                                Text(label.title)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .offset(x: monthLabelOffset(for: label))
                            }
                        }
                        .frame(width: renderModel.availableGridWidth, height: monthLabelHeight, alignment: .leading)
                    }

                    HStack(alignment: .top, spacing: axisSpacing) {
                        VStack(alignment: .trailing, spacing: renderModel.scaledMetrics.cellSpacing) {
                            ForEach(0..<7, id: \.self) { rowIndex in
                                let title = weekdayLabelTitle(for: rowIndex)
                                Text(title ?? " ")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .opacity(title == nil ? 0 : 1)
                                    .frame(width: weekdayLabelWidth, height: renderModel.scaledMetrics.cellSize, alignment: .trailing)
                            }
                        }
                        .frame(width: weekdayLabelWidth, height: renderModel.gridHeight, alignment: .topTrailing)

                        LazyHGrid(
                            rows: Array(repeating: GridItem(.fixed(renderModel.scaledMetrics.cellSize), spacing: renderModel.scaledMetrics.cellSpacing), count: 7),
                            spacing: renderModel.scaledMetrics.cellSpacing
                        ) {
                            ForEach(renderModel.cells) { cell in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(value: cell.value))
                                    .frame(width: renderModel.scaledMetrics.cellSize, height: renderModel.scaledMetrics.cellSize)
                            }
                        }
                        .frame(width: renderModel.availableGridWidth, height: renderModel.gridHeight, alignment: .topLeading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: monthLabelHeight + 6 + renderModel.gridHeight)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { onContainerWidthChange(proxy.size.width) }
                            .onChange(of: proxy.size.width) { newValue in
                                onContainerWidthChange(newValue)
                            }
                    }
                )

                HStack {
                    Text(L10n.insightRecent365Days)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(L10n.insightLittle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    ForEach(0..<4, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(legendColor(level: level))
                            .frame(width: 10, height: 10)
                    }
                    Text(L10n.insightMuch)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func monthLabelOffset(for label: ContributionHeatmapLayout.MonthLabel) -> CGFloat {
        let rawOffset = CGFloat(label.weekIndex) * (renderModel.scaledMetrics.cellSize + renderModel.scaledMetrics.cellSpacing)
        return min(rawOffset, max(0, renderModel.availableGridWidth - 20))
    }

    private func weekdayLabelTitle(for rowIndex: Int) -> String? {
        ContributionHeatmapLayout.weekdayLabels.first(where: { $0.rowIndex == rowIndex })?.title
    }

    private func cellColor(value: Double) -> Color {
        let maxValue = renderModel.maxValue
        guard maxValue > 0, value > 0 else {
            return Color.secondary.opacity(0.14)
        }
        let ratio = value / maxValue

        let baseColor: Color
        switch metric {
        case .messages:
            baseColor = Color.purple
        case .cost:
            baseColor = Color.accentColor
        default:
            baseColor = Color.green
        }

        if ratio < 0.25 { return baseColor.opacity(0.25) }
        if ratio < 0.5 { return baseColor.opacity(0.4) }
        if ratio < 0.75 { return baseColor.opacity(0.6) }
        return baseColor.opacity(0.85)
    }

    private func legendColor(level: Int) -> Color {
        let baseColor: Color
        switch metric {
        case .messages:
            baseColor = Color.purple
        case .cost:
            baseColor = Color.accentColor
        default:
            baseColor = Color.green
        }

        switch level {
        case 0: return Color.secondary.opacity(0.14)
        case 1: return baseColor.opacity(0.25)
        case 2: return baseColor.opacity(0.5)
        default: return baseColor.opacity(0.85)
        }
    }
}

private struct WeekdayWeekendComparisonView: View {
    let stats: WeekdayWeekendIntensity
    let metric: InsightMetric
    private let yAxisLabelWidth: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.insightWeekdayVsWeekend)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Chart {
                BarMark(
                    x: .value("类型", L10n.insightWeekday),
                    y: .value("平均值", stats.weekdayAverage)
                )
                .foregroundStyle(Color.blue)

                BarMark(
                    x: .value("类型", L10n.insightWeekend),
                    y: .value("平均值", stats.weekendAverage)
                )
                .foregroundStyle(Color.orange)
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine()
                    AxisTick(stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel {
                        if let rawValue = value.as(Double.self) {
                            Text(metric == .cost ? formatCostCompact(rawValue) : formatInputTokensCompact(rawValue))
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: yAxisLabelWidth, alignment: .trailing)
                        } else {
                            Text("")
                                .frame(width: yAxisLabelWidth, alignment: .trailing)
                        }
                    }
                }
            }
            .frame(height: 150)

            HStack(spacing: 12) {
                Text("\(L10n.insightTotal)\(L10n.insightWeekdayTotal)\(metricValueText(stats.weekdayTotal))")
                Text("\(L10n.insightWeekendTotal)\(metricValueText(stats.weekendTotal))")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricValueText(_ value: Double) -> String {
        if metric == .cost {
            return formatCostCompact(value)
        }
        return formatInputTokensCompact(value)
    }
}

private struct HourlyIntensityChartView: View {
    let points: [HourlyIntensityPoint]
    let metric: InsightMetric
    private let yAxisLabelWidth: CGFloat = 32

    var body: some View {
        let maxValue = max(points.map(\.value).max() ?? 0, 1)
        let yUpperBound = maxValue * 1.1

        return VStack(alignment: .leading, spacing: 6) {
            Text(L10n.insight24hIntensity)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Chart {
                RectangleMark(
                    xStart: .value("x0", 0),
                    xEnd: .value("x1", 8),
                    yStart: .value("y0", 0),
                    yEnd: .value("y1", yUpperBound)
                )
                .foregroundStyle(Color.purple.opacity(0.1))

                RectangleMark(
                    xStart: .value("x0", 8),
                    xEnd: .value("x1", 16),
                    yStart: .value("y0", 0),
                    yEnd: .value("y1", yUpperBound)
                )
                .foregroundStyle(Color.yellow.opacity(0.16))

                RectangleMark(
                    xStart: .value("x0", 16),
                    xEnd: .value("x1", 24),
                    yStart: .value("y0", 0),
                    yEnd: .value("y1", yUpperBound)
                )
                .foregroundStyle(Color.blue.opacity(0.1))

                RuleMark(x: .value("x", 8))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                RuleMark(x: .value("x", 16))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                ForEach(points) { point in
                    BarMark(
                        x: .value("小时", Double(point.hour) + 0.41),
                        yStart: .value("起始值", 0),
                        yEnd: .value("强度", point.value),
                        width: .automatic
                    )
                    .foregroundStyle(Color.accentColor)
                }
            }
            .chartXScale(domain: 0...24)
            .chartYScale(domain: 0...yUpperBound)
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine()
                    AxisTick(stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel {
                        if let rawValue = value.as(Double.self) {
                            Text(metric == .cost ? formatCostCompact(rawValue) : formatInputTokensCompact(rawValue))
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: yAxisLabelWidth, alignment: .trailing)
                        } else {
                            Text("")
                                .frame(width: yAxisLabelWidth, alignment: .trailing)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 4, 8, 12, 16, 20, 24]) { value in
                    AxisTick(stroke: StrokeStyle(lineWidth: 0))
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel {
                        if let raw = value.as(Int.self) {
                            Text("\(raw)")
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            .frame(height: 150)

            HStack(spacing: 8) {
                Text(L10n.insightNight)
                Text(L10n.insightDaytime)
                Text(L10n.insightEvening)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ModelLensChartView: View {
    let rows: [ModelLensRow]
    let groupBy: ModelLensGroupBy
    let isLoading: Bool
    @Binding var sortKey: ModelLensSortKey
    @Binding var sortDirection: SortDirection

    @State private var currentPage: Int = 0
    @State private var renderedRows: [ModelLensRow] = []
    private let pageSize: Int = 10
    private let rowContentHeight: CGFloat = 28
    private let rowVerticalPadding: CGFloat = 6
    private let headerContentHeight: CGFloat = 18
    private let headerVerticalPadding: CGFloat = 6
    private let columnSpacing: CGFloat = 8

    var body: some View {
        let maxInputValue: Double = max(renderedRows.map(\.inputTokens).max() ?? 0, 1)
        let maxTPSValue: Double = max(renderedRows.map(\.outputTPS).max() ?? 0, 1)
        let hasCoverageValue: Bool = renderedRows.contains(where: { $0.validDurationMessageRatio > 0 })

        return mainContent(maxInput: maxInputValue, maxTPS: maxTPSValue, hasCoverage: hasCoverageValue)
    }

    @ViewBuilder
    private func mainContent(maxInput: Double, maxTPS: Double, hasCoverage: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading && renderedRows.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if renderedRows.isEmpty {
                Text(L10n.insightNoModelData)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                tableContent(maxInput: maxInput, maxTPS: maxTPS, hasCoverage: hasCoverage)
            }
        }
        .onAppear {
            renderedRows = rows
        }
        .onChange(of: rows) { newRows in
            applyModelLensTransition(to: newRows)
        }
        .onChange(of: groupBy) { _ in
            currentPage = 0
        }
    }

    @ViewBuilder
    private func tableContent(maxInput: Double, maxTPS: Double, hasCoverage: Bool) -> some View {
        GeometryReader { proxy in
            let totalWidth: CGFloat = max(0, proxy.size.width)
            let columnWidth: CGFloat = max(0, (totalWidth - (columnSpacing * 2)) / 3)
            let rowsToDisplay: Int = rowsOnCurrentPage
            let rowsHeight: CGFloat = ((rowContentHeight + (rowVerticalPadding * 2)) * CGFloat(rowsToDisplay)) + CGFloat(max(0, rowsToDisplay - 1))
            let totalHeight: CGFloat = headerContentHeight + (headerVerticalPadding * 2) + 1 + rowsHeight

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: columnSpacing) {
                    Text(groupBy == .model ? L10n.modelModel : L10n.modelDimensionProvider)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: columnWidth, alignment: .leading)

                    sortHeaderCell(
                        title: L10n.chartColumnInput,
                        key: .inputTokens,
                        width: columnWidth
                    )

                    sortHeaderCell(
                        title: L10n.insightTPS,
                        key: .outputTPS,
                        width: columnWidth
                    )
                }
                .frame(height: headerContentHeight)
                .padding(.vertical, headerVerticalPadding)

                Divider()
                    .padding(.horizontal, 12)

                ForEach(0..<rowsToDisplay, id: \.self) { rowIndex in
                    if let row = rowAtCurrentPage(index: rowIndex) {
                    HStack(spacing: columnSpacing) {
                        modelLensNameCell(row: row)
                            .frame(width: columnWidth, alignment: .leading)

                        modelLensMetricBar(
                            value: row.inputTokens,
                            maxValue: maxInput,
                            barAreaWidth: columnWidth,
                            color: .blue,
                            valueText: formatInputTokensCompact(row.inputTokens)
                        )
                        .frame(width: columnWidth, alignment: .trailing)

                        modelLensMetricBar(
                            value: row.outputTPS,
                            maxValue: maxTPS,
                            barAreaWidth: columnWidth,
                            color: .orange,
                            valueText: String(format: "%.1f", row.outputTPS)
                        )
                        .frame(width: columnWidth, alignment: .trailing)
                    }
                    .frame(height: rowContentHeight)
                    .padding(.vertical, rowVerticalPadding)

                    if rowIndex < rowsToDisplay - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                    }
                }
            }
            .frame(height: totalHeight, alignment: .top)
        }
        .frame(height: chartHeight)

        if !renderedRows.isEmpty {
            HStack(spacing: 8) {
                if hasCoverage {
                    let avgCoverage = renderedRows.map(\.validDurationMessageRatio).reduce(0, +) / Double(renderedRows.count)
                    Text("\(L10n.insightTPSCoverage) \(Int(avgCoverage * 100))%（\(L10n.insightTpsCoverageBasedOn)）")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text(L10n.insightTPSCoverageAggregated)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if totalPages > 1 {
                    Text("\(currentPage + 1)/\(totalPages)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Button {
                        currentPage = max(0, currentPage - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(currentPage == 0)

                    Button {
                        currentPage = min(totalPages - 1, currentPage + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(currentPage >= totalPages - 1)
                }
            }
            .padding(.top, 4)
        }
    }

    private var chartHeight: CGFloat {
        let rowsToDisplay = rowsOnCurrentPage
        let rowsHeight = ((rowContentHeight + (rowVerticalPadding * 2)) * CGFloat(rowsToDisplay)) + CGFloat(max(0, rowsToDisplay - 1))
        return headerContentHeight + (headerVerticalPadding * 2) + 1 + rowsHeight
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(renderedRows.count) / Double(pageSize))))
    }

    private var rowsOnCurrentPage: Int {
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, renderedRows.count)
        return max(0, endIndex - startIndex)
    }

    private func rowAtCurrentPage(index: Int) -> ModelLensRow? {
        let rowIndex = (currentPage * pageSize) + index
        guard renderedRows.indices.contains(rowIndex) else { return nil }
        return renderedRows[rowIndex]
    }

    private func modelLensNameCell(row: ModelLensRow?) -> some View {
        Group {
            if groupBy == .model, let row {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.dimensionName.components(separatedBy: "/").last ?? row.dimensionName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !row.providerId.isEmpty {
                        Text(row.providerId)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text(row?.dimensionName ?? "-")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(row == nil ? .secondary : .primary)
                    .lineLimit(1)
            }
        }
    }

    private func modelLensMetricBar(
        value: Double,
        maxValue: Double,
        barAreaWidth: CGFloat,
        color: Color,
        valueText: String
    ) -> some View {
        let ratio = maxValue > 0 ? value / maxValue : 0
        let barWidth = max(2, barAreaWidth * ratio)
        let fillOpacity = color == .orange ? 0.75 : 0.82

        return VStack(alignment: .trailing, spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(fillOpacity))
                .frame(width: barWidth, height: 10)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(valueText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary.opacity(0.8))
        }
    }

    private func modelLensPlaceholderBar() -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 20, height: 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("-")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    private func sortHeaderCell(title: String, key: ModelLensSortKey, width: CGFloat) -> some View {
        Button {
            toggleSort(for: key)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                if sortKey == key {
                    Image(systemName: sortDirection == .descending ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleSort(for key: ModelLensSortKey) {
        currentPage = 0
        withAnimation(.easeInOut(duration: 0.15)) {
            if sortKey == key {
                sortDirection.toggle()
            } else {
                sortKey = key
                sortDirection = .descending
            }
        }
    }

    private func applyModelLensTransition(to newRows: [ModelLensRow]) {
        renderedRows = newRows
        currentPage = 0
    }
}
