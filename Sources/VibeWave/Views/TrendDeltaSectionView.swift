import Foundation
import SwiftUI

public struct TrendDeltaSectionView: View {
    private let inputHistoryData: [SingleMetricDataPoint]
    private let inputDeltaData: [SingleMetricDataPoint]
    private let durationHistoryData: [SingleMetricDataPoint]
    private let durationDeltaData: [SingleMetricDataPoint]
    private let inputAvgPerDay: Double
    private let durationAvgPerDayHours: Double
    private let isLoading: Bool
    private let timeRange: HistoryTimeRangeOption

    private enum Constants {
        static let backgroundCornerRadius: CGFloat = 12
    }

    public init(
        inputHistoryData: [SingleMetricDataPoint],
        inputDeltaData: [SingleMetricDataPoint],
        durationHistoryData: [SingleMetricDataPoint],
        durationDeltaData: [SingleMetricDataPoint],
        inputAvgPerDay: Double,
        durationAvgPerDayHours: Double,
        isLoading: Bool,
        timeRange: HistoryTimeRangeOption
    ) {
        self.inputHistoryData = inputHistoryData
        self.inputDeltaData = inputDeltaData
        self.durationHistoryData = durationHistoryData
        self.durationDeltaData = durationDeltaData
        self.inputAvgPerDay = inputAvgPerDay
        self.durationAvgPerDayHours = durationAvgPerDayHours
        self.isLoading = isLoading
        self.timeRange = timeRange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChartHeaderView(title: L10n.historyTrend)

            HStack(alignment: .top, spacing: 16) {
                chartColumn(title: L10n.historyInputTokensCumulative) {
                    TrendDeltaMetricChartContentView(
                        historyData: inputHistoryData,
                        deltaData: inputDeltaData,
                        isLoading: isLoading,
                        timeRange: timeRange,
                        historyColor: .blue,
                        deltaColor: .orange,
                        historyValueFormatter: { formatInputTokensCompact($0) },
                        deltaValueFormatter: { TrendDeltaValueFormatter.formatSignedTokens($0) },
                        axisValueFormatter: { TrendDeltaValueFormatter.formatAxisTokens($0) }
                    )
                }

                chartColumn(title: L10n.historyMessageDurationCumulative) {
                    TrendDeltaMetricChartContentView(
                        historyData: durationHistoryData,
                        deltaData: durationDeltaData,
                        isLoading: isLoading,
                        timeRange: timeRange,
                        historyColor: .green,
                        deltaColor: .purple,
                        historyValueFormatter: { "\(TrendDeltaValueFormatter.formatHours($0))h" },
                        deltaValueFormatter: { TrendDeltaValueFormatter.formatSignedHours($0) },
                        axisValueFormatter: { TrendDeltaValueFormatter.formatAxisHours($0) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: Constants.backgroundCornerRadius)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.backgroundCornerRadius)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func chartColumn<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TrendDeltaSectionView(
        inputHistoryData: [],
        inputDeltaData: [],
        durationHistoryData: [],
        durationDeltaData: [],
        inputAvgPerDay: 0,
        durationAvgPerDayHours: 0,
        isLoading: false,
        timeRange: .last24Hours
    )
    .padding()
}
