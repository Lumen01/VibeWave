import Foundation
import SwiftUI
import Charts

public struct TrendDeltaMetricChartContentView: View {
    private let historyData: [SingleMetricDataPoint]
    private let deltaData: [SingleMetricDataPoint]
    private let isLoading: Bool
    private let timeRange: HistoryTimeRangeOption
    private let historyColor: Color
    private let deltaColor: Color
    private let historyValueFormatter: (Double) -> String
    private let deltaValueFormatter: (Double) -> String
    private let axisValueFormatter: (Double) -> String

    @State private var tooltipData: TooltipData?
    @State private var tooltipPosition: CGPoint?
    @State private var plotWidth: CGFloat = 0

    private enum Constants {
        static let chartHeight: CGFloat = 150
        static let horizontalPadding: CGFloat = 20
        static let barWidthRatio: CGFloat = 0.7
    }

    public init(
        historyData: [SingleMetricDataPoint],
        deltaData: [SingleMetricDataPoint],
        isLoading: Bool,
        timeRange: HistoryTimeRangeOption,
        historyColor: Color,
        deltaColor: Color,
        historyValueFormatter: @escaping (Double) -> String,
        deltaValueFormatter: @escaping (Double) -> String,
        axisValueFormatter: @escaping (Double) -> String
    ) {
        self.historyData = historyData
        self.deltaData = deltaData
        self.isLoading = isLoading
        self.timeRange = timeRange
        self.historyColor = historyColor
        self.deltaColor = deltaColor
        self.historyValueFormatter = historyValueFormatter
        self.deltaValueFormatter = deltaValueFormatter
        self.axisValueFormatter = axisValueFormatter
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            chartView

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
            }
        }
    }

    private var chartView: some View {
        let layout = XAxisLayout(for: timeRange)
        let points = plottedPoints
        let historySeries = points.map { $0.historyDataPoint }
        let deltaSeries = points.map { $0.deltaDataPoint }
        let domain = TrendDeltaChartMath.yDomain(history: historySeries, delta: deltaSeries)
        let yGrid = yGridValues(domain: domain)
        let yLabels = yLabelValues(domain: domain)
        let xLabelBoundaries = labeledBoundaryIndices(points: points, layout: layout).map(Double.init)

        return Chart {
            chartMarks(points: points, layout: layout)
        }
        .frame(height: Constants.chartHeight)
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.bottom, 8)
        .chartXScale(domain: 0...Double(layout.barCount))
        .chartYScale(domain: domain)
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
                        if let text = xAxisLabel(boundaryIndex: boundaryIndex, points: points) {
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
                        Text(axisValueFormatter(rawValue))
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
                            points: points,
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
    private func chartMarks(points: [TrendPoint], layout: XAxisLayout) -> some ChartContent {
        ForEach(points) { point in
            BarMark(
                x: .value("Bucket", Double(point.bucketIndex) + 0.5),
                y: .value("增量", point.delta),
                width: .fixed(barMarkWidth(for: layout))
            )
            .foregroundStyle(deltaColor.opacity(0.7))
        }

        ForEach(points) { point in
            LineMark(
                x: .value("Bucket", Double(point.bucketIndex) + 0.5),
                y: .value("累计", point.history)
            )
            .foregroundStyle(historyColor)
            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Bucket", Double(point.bucketIndex) + 0.5),
                y: .value("累计", point.history)
            )
            .foregroundStyle(historyColor)
            .symbolSize(18)
        }
    }

    private var plottedPoints: [TrendPoint] {
        let baseHistory = historyData.isEmpty ? placeholderData(for: timeRange) : historyData
        let baseDelta = deltaData.isEmpty ? TrendDeltaChartMath.signedDeltaSeries(from: baseHistory) : deltaData
        let pointCount = min(baseHistory.count, baseDelta.count)

        return (0..<pointCount).map { index in
            let historyPoint = baseHistory[index]
            let deltaPoint = baseDelta[index]
            return TrendPoint(
                bucketStart: historyPoint.bucketStart,
                bucketIndex: historyPoint.bucketIndex,
                label: historyPoint.label,
                history: historyPoint.value,
                delta: deltaPoint.value
            )
        }
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

    private func yGridValues(domain: ClosedRange<Double>) -> [Double] {
        let span = domain.upperBound - domain.lowerBound
        if span <= 0 {
            return [domain.lowerBound]
        }
        return (0...4).map { step in
            domain.lowerBound + (span * Double(step) / 4.0)
        }
    }

    private func yLabelValues(domain: ClosedRange<Double>) -> [Double] {
        if domain.lowerBound < 0, domain.upperBound > 0 {
            return [domain.lowerBound, 0, domain.upperBound]
        }
        let midpoint = (domain.lowerBound + domain.upperBound) / 2
        return [midpoint, domain.upperBound]
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

    private func labeledBoundaryIndices(points: [TrendPoint], layout: XAxisLayout) -> [Int] {
        let indices = Array(0...layout.barCount).filter { boundaryIndex in
            xAxisLabel(boundaryIndex: boundaryIndex, points: points) != nil
        }
        return indices.isEmpty ? [0, layout.barCount] : indices
    }

    private func xAxisLabel(boundaryIndex: Int, points: [TrendPoint]) -> String? {
        guard let boundaryDate = boundaryDate(boundaryIndex: boundaryIndex, points: points) else {
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

    private func boundaryDate(boundaryIndex: Int, points: [TrendPoint]) -> Date? {
        guard let firstBucketStart = points.first?.bucketStart else { return nil }
        let startDate = Date(timeIntervalSince1970: firstBucketStart)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

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
        points: [TrendPoint],
        layout: XAxisLayout
    ) {
        switch phase {
        case .active(let location):
            let plotFrame = geometry[proxy.plotAreaFrame]
            let relativeX = location.x - plotFrame.origin.x

            guard relativeX >= 0, relativeX <= plotFrame.width, !points.isEmpty else {
                tooltipData = nil
                tooltipPosition = nil
                return
            }

            let bucketIndex = layout.bucketIndex(at: relativeX, plotWidth: plotFrame.width)
            guard bucketIndex >= 0, bucketIndex < points.count else {
                tooltipData = nil
                tooltipPosition = nil
                return
            }

            let point = points[bucketIndex]
            tooltipData = TooltipData(label: point.label, history: point.history, delta: point.delta)

            let bucketWidth = plotFrame.width / CGFloat(layout.barCount)
            let pointX = plotFrame.origin.x + (CGFloat(bucketIndex) + 0.5) * bucketWidth
            let clampedX = max(74, min(pointX, geometry.size.width - 74))
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
                    .fill(historyColor)
                    .frame(width: 8, height: 8)
                Text("\(L10n.chartCumulative) \(historyValueFormatter(data.history))")
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(deltaColor)
                    .frame(width: 8, height: 8)
                Text("\(L10n.chartDelta) \(deltaValueFormatter(data.delta))")
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

        init(for timeRange: HistoryTimeRangeOption) {
            switch timeRange {
            case .last24Hours:
                barCount = 24
            case .last30Days:
                barCount = 30
            case .allTime:
                barCount = 12
            }
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
        let history: Double
        let delta: Double
    }

    private struct TrendPoint: Identifiable {
        var id: TimeInterval { bucketStart }
        let bucketStart: TimeInterval
        let bucketIndex: Int
        let label: String
        let history: Double
        let delta: Double

        var historyDataPoint: SingleMetricDataPoint {
            SingleMetricDataPoint(
                timestamp: bucketStart,
                label: label,
                value: history,
                bucketIndex: bucketIndex,
                hasData: history > 0,
                bucketStart: bucketStart
            )
        }

        var deltaDataPoint: SingleMetricDataPoint {
            SingleMetricDataPoint(
                timestamp: bucketStart,
                label: label,
                value: delta,
                bucketIndex: bucketIndex,
                hasData: delta != 0,
                bucketStart: bucketStart
            )
        }
    }
}
