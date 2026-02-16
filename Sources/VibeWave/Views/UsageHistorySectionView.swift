import Foundation
import SwiftUI

public struct UsageHistorySectionView: View {
    private let inputTokensData: [InputTokensDataPoint]
    private let outputReasoningData: [OutputReasoningDataPoint]
    private let isLoading: Bool
    private let timeRange: HistoryTimeRangeOption
    @Binding private var mode: ChartDisplayMode

    private enum Constants {
        static let backgroundCornerRadius: CGFloat = 12
    }

    public init(
        inputTokensData: [InputTokensDataPoint],
        outputReasoningData: [OutputReasoningDataPoint],
        isLoading: Bool,
        timeRange: HistoryTimeRangeOption,
        mode: Binding<ChartDisplayMode>
    ) {
        self.inputTokensData = inputTokensData
        self.outputReasoningData = outputReasoningData
        self.isLoading = isLoading
        self.timeRange = timeRange
        self._mode = mode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChartHeaderView(title: L10n.historyUsage, mode: $mode)

            HStack(alignment: .top, spacing: 16) {
                chartColumn(title: L10n.chartColumnInput) {
                    InputTokensChartContentView(
                        data: inputTokensData,
                        isLoading: isLoading,
                        timeRange: timeRange,
                        mode: $mode
                    )
                }

                chartColumn(title: "Output + Reasoning") {
                    OutputReasoningChartContentView(
                        data: outputReasoningData,
                        isLoading: isLoading,
                        timeRange: timeRange,
                        mode: $mode
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
    UsageHistorySectionView(
        inputTokensData: [],
        outputReasoningData: [],
        isLoading: false,
        timeRange: .last24Hours,
        mode: .constant(.bar)
    )
    .padding()
}
