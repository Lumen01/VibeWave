import Foundation
import SwiftUI

public struct ActivityChartContainerView: View {
    private let sessionsData: [SingleMetricDataPoint]
    private let messagesData: [SingleMetricDataPoint]
    private let isLoading: Bool
    private let timeRange: HistoryTimeRangeOption
    @Binding private var activityChartType: ActivityChartType
    @Binding private var sessionsChartMode: ChartDisplayMode
    @Binding private var messagesChartMode: ChartDisplayMode

    private enum Constants {
        static let backgroundCornerRadius: CGFloat = 12
    }

    public init(
        sessionsData: [SingleMetricDataPoint],
        messagesData: [SingleMetricDataPoint],
        isLoading: Bool,
        timeRange: HistoryTimeRangeOption,
        activityChartType: Binding<ActivityChartType>,
        sessionsChartMode: Binding<ChartDisplayMode>,
        messagesChartMode: Binding<ChartDisplayMode>
    ) {
        self.sessionsData = sessionsData
        self.messagesData = messagesData
        self.isLoading = isLoading
        self.timeRange = timeRange
        self._activityChartType = activityChartType
        self._sessionsChartMode = sessionsChartMode
        self._messagesChartMode = messagesChartMode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            chartContent
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

    private var headerView: some View {
        HStack(spacing: 0) {
            Text(L10n.chartActivity)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(width: 120, alignment: .leading)

            Spacer()

            Picker("Activity Type", selection: $activityChartType) {
                ForEach(ActivityChartType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 120)

            Picker(L10n.chartType, selection: chartModeBinding) {
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
    }

    private var chartContent: some View {
        Group {
            switch activityChartType {
            case .sessions:
                SingleMetricChartContentView(
                    data: sessionsData,
                    isLoading: isLoading,
                    timeRange: timeRange,
                    mode: $sessionsChartMode,
                    color: .indigo,
                    valueStyle: .compact,
                    yValueName: "Sessions"
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            case .messages:
                SingleMetricChartContentView(
                    data: messagesData,
                    isLoading: isLoading,
                    timeRange: timeRange,
                    mode: $messagesChartMode,
                    color: .green,
                    valueStyle: .compact,
                    yValueName: "Messages"
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    private var chartModeBinding: Binding<ChartDisplayMode> {
        switch activityChartType {
        case .sessions:
            return $sessionsChartMode
        case .messages:
            return $messagesChartMode
        }
    }
}

#Preview {
    ActivityChartContainerView(
        sessionsData: [],
        messagesData: [],
        isLoading: false,
        timeRange: .last24Hours,
        activityChartType: .constant(.sessions),
        sessionsChartMode: .constant(.bar),
        messagesChartMode: .constant(.bar)
    )
    .frame(width: 600, height: 300)
    .padding()
}
