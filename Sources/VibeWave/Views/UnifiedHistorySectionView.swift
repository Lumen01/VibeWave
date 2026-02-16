import Foundation
import SwiftUI

public struct UnifiedHistorySectionView: View {
    private let inputTokensData: [InputTokensDataPoint]
    private let outputReasoningData: [OutputReasoningDataPoint]
    private let sessionsData: [SingleMetricDataPoint]
    private let messagesData: [SingleMetricDataPoint]
    private let isLoading: Bool
    private let timeRange: HistoryTimeRangeOption
    @Binding private var tokenChartMode: ChartDisplayMode
    @Binding private var activityChartMode: ChartDisplayMode

    private enum Constants {
        static let backgroundCornerRadius: CGFloat = 12
    }

    public init(
        inputTokensData: [InputTokensDataPoint],
        outputReasoningData: [OutputReasoningDataPoint],
        sessionsData: [SingleMetricDataPoint],
        messagesData: [SingleMetricDataPoint],
        isLoading: Bool,
        timeRange: HistoryTimeRangeOption,
        tokenChartMode: Binding<ChartDisplayMode>,
        activityChartMode: Binding<ChartDisplayMode>
    ) {
        self.inputTokensData = inputTokensData
        self.outputReasoningData = outputReasoningData
        self.sessionsData = sessionsData
        self.messagesData = messagesData
        self.isLoading = isLoading
        self.timeRange = timeRange
        self._tokenChartMode = tokenChartMode
        self._activityChartMode = activityChartMode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChartHeaderView(title: L10n.chartHistory)

            VStack(spacing: 16) {
                tokenUsageSection

                Divider()
                    .padding(.horizontal, 12)

                activitySection
            }
            .padding(.top, 8)
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

    private var tokenUsageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.chartTokenUsage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Picker(L10n.chartType, selection: $tokenChartMode) {
                    ForEach(ChartDisplayMode.allCases, id: \.self) { displayMode in
                        Image(systemName: displayMode.iconName)
                            .accessibilityLabel(displayMode.accessibilityLabel)
                            .tag(displayMode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 88)
            }
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 16) {
                chartColumn(title: L10n.chartColumnInput) {
                    InputTokensChartContentView(
                        data: inputTokensData,
                        isLoading: isLoading,
                        timeRange: timeRange,
                        mode: $tokenChartMode
                    )
                }

                chartColumn(title: "Output + Reasoning") {
                    OutputReasoningChartContentView(
                        data: outputReasoningData,
                        isLoading: isLoading,
                        timeRange: timeRange,
                        mode: $tokenChartMode
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.chartActivity)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Picker(L10n.chartType, selection: $activityChartMode) {
                    ForEach(ChartDisplayMode.allCases, id: \.self) { displayMode in
                        Image(systemName: displayMode.iconName)
                            .accessibilityLabel(displayMode.accessibilityLabel)
                            .tag(displayMode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 88)
            }
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 16) {
                chartColumn(title: L10n.chartColumnSession) {
                    SingleMetricChartContentView(
                        data: sessionsData,
                        isLoading: isLoading,
                        timeRange: timeRange,
                        mode: $activityChartMode,
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
                        mode: $activityChartMode,
                        color: .green,
                        valueStyle: .compact,
                        yValueName: "Messages"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
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
    UnifiedHistorySectionView(
        inputTokensData: [],
        outputReasoningData: [],
        sessionsData: [],
        messagesData: [],
        isLoading: false,
        timeRange: .last24Hours,
        tokenChartMode: .constant(.bar),
        activityChartMode: .constant(.bar)
    )
    .padding()
}
