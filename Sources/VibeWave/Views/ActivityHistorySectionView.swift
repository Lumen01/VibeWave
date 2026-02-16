import Foundation
import SwiftUI

public struct ActivityHistorySectionView: View {
    private let sessionsData: [SingleMetricDataPoint]
    private let messagesData: [SingleMetricDataPoint]
    private let isLoading: Bool
    private let timeRange: HistoryTimeRangeOption
    @Binding private var mode: ChartDisplayMode

    private enum Constants {
        static let backgroundCornerRadius: CGFloat = 12
    }

    public init(
        sessionsData: [SingleMetricDataPoint],
        messagesData: [SingleMetricDataPoint],
        isLoading: Bool,
        timeRange: HistoryTimeRangeOption,
        mode: Binding<ChartDisplayMode>
    ) {
        self.sessionsData = sessionsData
        self.messagesData = messagesData
        self.isLoading = isLoading
        self.timeRange = timeRange
        self._mode = mode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChartHeaderView(title: L10n.historyActivity, mode: $mode)

            HStack(alignment: .top, spacing: 16) {
                chartColumn(title: L10n.chartColumnSession) {
                    SingleMetricChartContentView(
                        data: sessionsData,
                        isLoading: isLoading,
                        timeRange: timeRange,
                        mode: $mode,
                        color: .indigo,
                        valueStyle: .compact,
                        yValueName: "Sessions"
                    )
                }

                chartColumn(title: L10n.chartColumnMessage) {
                    SingleMetricChartContentView(
                        data: messagesData,
                        isLoading: isLoading,
                        timeRange: timeRange,
                        mode: $mode,
                        color: .green,
                        valueStyle: .compact,
                        yValueName: "Messages"
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
    private func chartColumn<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
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
    ActivityHistorySectionView(
        sessionsData: [],
        messagesData: [],
        isLoading: false,
        timeRange: .last24Hours,
        mode: .constant(.bar)
    )
    .padding()
}
