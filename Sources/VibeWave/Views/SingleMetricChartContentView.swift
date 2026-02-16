import Foundation
import SwiftUI
import Charts

public struct SingleMetricChartContentView: View {
    private let data: [SingleMetricDataPoint]
    private let isLoading: Bool
    private let timeRange: HistoryTimeRangeOption
    private let color: Color
    private let valueStyle: SingleMetricValueStyle
    private let yValueName: String
    @Binding private var mode: ChartDisplayMode

    @State private var tooltipData: TooltipData?
    @State private var tooltipPosition: CGPoint?
    @State private var plotWidth: CGFloat = 0

    private enum Constants {
        static let chartHeight: CGFloat = 150
        static let horizontalPadding: CGFloat = 20
        static let barWidthRatio: CGFloat = 0.9
    }

    public init(
        data: [SingleMetricDataPoint],
        isLoading: Bool,
        timeRange: HistoryTimeRangeOption,
        mode: Binding<ChartDisplayMode>,
        color: Color,
        valueStyle: SingleMetricValueStyle,
        yValueName: String
    ) {
        self.data = data
        self.isLoading = isLoading
        self.timeRange = timeRange
        self._mode = mode
        self.color = color
        self.valueStyle = valueStyle
        self.yValueName = yValueName
    }

    public var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                chartView

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                }
            }

            statsView
        }
    }

    private var statsView: some View {
        let plottedData = chartData
        let maxValue = plottedData.map { $0.value }.max() ?? 0
        let avgValue = plottedData.isEmpty ? 0 : plottedData.map { $0.value }.reduce(0, +) / Double(plottedData.count)

        return HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text(L10n.chartPeak)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(formatValue(maxValue))
                    .font(.system(size: 10, weight: .medium))
            }

            HStack(spacing: 4) {
                Text(L10n.chartAverage)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(formatValue(avgValue))
                    .font(.system(size: 10, weight: .medium))
            }

            Spacer()
        }
        .padding(.horizontal, Constants.horizontalPadding)
    }

    private func formatValue(_ value: Double) -> String {
        valueStyle.format(value)
    }

    private var chartView: some View {
        let layout = XAxisLayout(for: timeRange)
        let plottedData = chartData
        let yGrid = yGridValues(for: plottedData)
        let yLabels = yLabelValues(for: plottedData)
        let xLabelBoundaries = labeledBoundaryIndices(plottedData: plottedData, layout: layout).map(Double.init)

        return Chart {
            chartMarks(plottedData: plottedData, layout: layout)
        }
        .frame(height: Constants.chartHeight)
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.bottom, 8)
        .chartXScale(domain: 0...Double(layout.barCount))
        .chartYScale(domain: yDomain(for: plottedData))
        .chartXAxis {
            AxisMarks(values: xLabelBoundaries) { value in
                if let rawValue = value.as(Double.self) {
                    let boundaryIndex = Int(rawValue)

                    AxisGridLine(
                        stroke: StrokeStyle(
                            lineWidth: 1,
                            dash: [3, 3]
                        )
                    )
                    .foregroundStyle(Color.secondary.opacity(0.5))

                    AxisTick(stroke: StrokeStyle(lineWidth: 0))

                    AxisValueLabel {
                        if let text = xAxisLabel(boundaryIndex: boundaryIndex, plottedData: plottedData) {
                            Text(text)
                                .font(.system(size: timeRange == .last30Days ? 9 : 10))
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: yGrid) { value in
                if let rawValue = value.as(Double.self),
                   let gridIndex = yGrid.firstIndex(where: { abs($0 - rawValue) < 0.0001 }) {
                    AxisGridLine(
                        stroke: yGridStroke(for: gridIndex)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    AxisTick(stroke: StrokeStyle(lineWidth: 0))
                }
            }

            AxisMarks(position: .trailing, values: yLabels) { value in
                AxisTick(stroke: StrokeStyle(lineWidth: 0))
                AxisValueLabel {
                    if let rawValue = value.as(Double.self) {
                        Text(valueStyle.format(rawValue))
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let currentPlotWidth = geometry[proxy.plotAreaFrame].width

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onAppear {
                        plotWidth = currentPlotWidth
                    }
                    .onChange(of: currentPlotWidth) { newWidth in
                        plotWidth = newWidth
                    }
                    .onContinuousHover { phase in
                        handleHover(
                            phase,
                            proxy: proxy,
                            geometry: geometry,
                            plottedData: plottedData,
                            layout: layout
                        )
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            if let tooltipData, let tooltipPosition {
                tooltipView(for: tooltipData)
                    .position(x: tooltipPosition.x, y: tooltipPosition.y)
            }
        }
    }

    @ChartContentBuilder
    private func chartMarks(plottedData: [SingleMetricDataPoint], layout: XAxisLayout) -> some ChartContent {
        if mode == .bar {
            ForEach(plottedData) { point in
                BarMark(
                    x: .value("Bucket", Double(point.bucketIndex) + 0.5),
                    y: .value(yValueName, point.value),
                    width: .fixed(barMarkWidth(for: layout))
                )
                .foregroundStyle(color)
            }
        } else {
            ForEach(plottedData) { point in
                LineMark(
                    x: .value("Bucket", Double(point.bucketIndex) + 0.5),
                    y: .value(yValueName, point.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Bucket", Double(point.bucketIndex) + 0.5),
                    y: .value(yValueName, point.value)
                )
                .foregroundStyle(color)
                .symbolSize(16)
            }
        }
    }

    private var chartData: [SingleMetricDataPoint] {
        guard !data.isEmpty else {
            return placeholderData(for: timeRange)
        }
        return data
    }

    private func placeholderData(for timeRange: HistoryTimeRangeOption) -> [SingleMetricDataPoint] {
        let now = Date()
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent

        switch timeRange {
        case .last24Hours:
            let window = TimeSeriesFiller.last24HourWindowAnchoredToCurrentHour(reference: now)
            return TimeSeriesFiller.fillHourlySingleMetricData(bucketValues: [:], startTime: window.start, barCount: 24)

        case .last30Days:
            let todayStart = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
            return TimeSeriesFiller.fillDailySingleMetricData(bucketValues: [:], startTime: start, barCount: 30)

        case .allTime:
            let components = calendar.dateComponents([.year, .month], from: now)
            let currentMonth = calendar.date(from: components) ?? now
            let start = calendar.date(byAdding: .month, value: -11, to: currentMonth) ?? currentMonth
            return TimeSeriesFiller.fillMonthlySingleMetricData(bucketValues: [:], startTime: start, barCount: 12)
        }
    }

    private func yDomain(for plottedData: [SingleMetricDataPoint]) -> ClosedRange<Double> {
        let maxValue = plottedData.map(\.value).max() ?? 0
        if maxValue <= 0 {
            return 0...1
        }
        return 0...(maxValue * 1.1)
    }

    private func yGridValues(for plottedData: [SingleMetricDataPoint]) -> [Double] {
        let maxY = yDomain(for: plottedData).upperBound
        return (0...4).map { step in
            maxY * Double(step) / 4.0
        }
    }

    private func yLabelValues(for plottedData: [SingleMetricDataPoint]) -> [Double] {
        let maxY = yDomain(for: plottedData).upperBound
        return [maxY / 2.0, maxY]
    }

    private func barMarkWidth(for layout: XAxisLayout) -> CGFloat {
        let effectivePlotWidth = max(plotWidth, 1)
        let intervalWidth = effectivePlotWidth / CGFloat(layout.barCount)
        return intervalWidth * Constants.barWidthRatio
    }

    private func yGridStroke(for gridIndex: Int) -> StrokeStyle {
        if gridIndex == 1 || gridIndex == 3 {
            return StrokeStyle(lineWidth: 0.8, dash: [4, 3])
        }
        return StrokeStyle(lineWidth: 0.8)
    }

    private func labeledBoundaryIndices(plottedData: [SingleMetricDataPoint], layout: XAxisLayout) -> [Int] {
        let indices = Array(0...layout.barCount).filter { boundaryIndex in
            xAxisLabel(boundaryIndex: boundaryIndex, plottedData: plottedData) != nil
        }
        return indices.isEmpty ? [0, layout.barCount] : indices
    }

    private func xAxisLabel(
        boundaryIndex: Int,
        plottedData: [SingleMetricDataPoint]
    ) -> String? {
        guard let boundaryDate = boundaryDate(boundaryIndex: boundaryIndex, plottedData: plottedData) else {
            return nil
        }

        switch timeRange {
        case .last24Hours:
            var localCalendar = Calendar.current
            localCalendar.timeZone = .current
            let hour = localCalendar.component(.hour, from: boundaryDate)
            guard hour % 3 == 0 else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "H:00"
            return formatter.string(from: boundaryDate)

        case .last30Days:
            var localCalendar = Calendar.current
            localCalendar.timeZone = .current
            let weekday = localCalendar.component(.weekday, from: boundaryDate)
            guard weekday == 1 else { return nil }

            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: boundaryDate)

        case .allTime:
            guard boundaryIndex % 3 == 0 else { return nil }
            var localCalendar = Calendar.current
            localCalendar.timeZone = .current
            let month = localCalendar.component(.month, from: boundaryDate)
            return "\(month)"
        }
    }

    private func boundaryDate(
        boundaryIndex: Int,
        plottedData: [SingleMetricDataPoint]
    ) -> Date? {
        guard let firstBucketStart = plottedData.first?.bucketStart else { return nil }

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let startDate = Date(timeIntervalSince1970: firstBucketStart)

        switch timeRange {
        case .last24Hours:
            return utcCalendar.date(byAdding: .hour, value: boundaryIndex, to: startDate)
        case .last30Days:
            return utcCalendar.date(byAdding: .day, value: boundaryIndex, to: startDate)
        case .allTime:
            return utcCalendar.date(byAdding: .month, value: boundaryIndex, to: startDate)
        }
    }

    private func handleHover(
        _ phase: HoverPhase,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        plottedData: [SingleMetricDataPoint],
        layout: XAxisLayout
    ) {
        switch phase {
        case .active(let location):
            let plotFrame = geometry[proxy.plotAreaFrame]
            let relativeX = location.x - plotFrame.origin.x

            guard relativeX >= 0, relativeX <= plotFrame.width, !plottedData.isEmpty else {
                tooltipData = nil
                tooltipPosition = nil
                return
            }

            let bucketIndex = layout.bucketIndex(at: relativeX, plotWidth: plotFrame.width)
            guard bucketIndex >= 0, bucketIndex < plottedData.count else {
                tooltipData = nil
                tooltipPosition = nil
                return
            }

            let point = plottedData[bucketIndex]
            tooltipData = TooltipData(label: point.label, value: point.value)

            let bucketWidth = plotFrame.width / CGFloat(layout.barCount)
            let pointX = plotFrame.origin.x + (CGFloat(bucketIndex) + 0.5) * bucketWidth
            let clampedX = max(60, min(pointX, geometry.size.width - 60))
            let tooltipY = max(16, plotFrame.origin.y + 16)
            tooltipPosition = CGPoint(x: clampedX, y: tooltipY)

        case .ended:
            tooltipData = nil
            tooltipPosition = nil
        }
    }

    @ViewBuilder
    private func tooltipView(for data: TooltipData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.label)
                .font(.system(size: 12, weight: .semibold))

            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(valueStyle.format(data.value))
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .cornerRadius(8)
        .shadow(radius: 4)
    }

    private struct XAxisLayout {
        let barCount: Int
        let boundaryValues: [Double]

        init(for timeRange: HistoryTimeRangeOption) {
            switch timeRange {
            case .last24Hours:
                self.barCount = 24
            case .last30Days:
                self.barCount = 30
            case .allTime:
                self.barCount = 12
            }
            self.boundaryValues = Array(0...barCount).map(Double.init)
        }

        func bucketIndex(at relativeX: CGFloat, plotWidth: CGFloat) -> Int {
            guard plotWidth > 0 else { return 0 }
            let bucketWidth = plotWidth / CGFloat(barCount)
            let rawIndex = Int(relativeX / bucketWidth)
            return max(0, min(rawIndex, barCount - 1))
        }
    }

    private struct TooltipData {
        let label: String
        let value: Double
    }
}
