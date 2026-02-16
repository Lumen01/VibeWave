import SwiftUI

// MARK: - Time Range Option
public enum HistoryTimeRangeOption: String, CaseIterable, Sendable {
    case last24Hours = "24小时"
    case last30Days = "30天"
    case allTime = "所有"

    public var displayName: String {
        switch self {
        case .last24Hours: return L10n.time24hours
        case .last30Days: return L10n.time30days
        case .allTime: return L10n.timeAllTime
        }
    }
}

// MARK: - History View
public struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel

    public init(viewModel: HistoryViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TrendDeltaSectionView(
                    inputHistoryData: viewModel.trendInputHistoryData,
                    inputDeltaData: viewModel.trendInputDeltaData,
                    durationHistoryData: viewModel.trendDurationHistoryData,
                    durationDeltaData: viewModel.trendDurationDeltaData,
                    inputAvgPerDay: viewModel.trendInputAvgPerDay,
                    durationAvgPerDayHours: viewModel.trendDurationAvgPerDayHours,
                    isLoading: viewModel.isLoading,
                    timeRange: viewModel.selectedTimeRange
                )

                UnifiedHistorySectionView(
                    inputTokensData: viewModel.inputTokensData,
                    outputReasoningData: viewModel.outputReasoningData,
                    sessionsData: viewModel.sessionsData,
                    messagesData: viewModel.messagesData,
                    isLoading: viewModel.isLoading,
                    timeRange: viewModel.selectedTimeRange,
                    tokenChartMode: $viewModel.usageSectionChartMode,
                    activityChartMode: $viewModel.activitySectionChartMode
                )

                CostChartView(
                    data: viewModel.costData,
                    isLoading: viewModel.isLoading,
                    timeRange: viewModel.selectedTimeRange,
                    mode: $viewModel.costChartMode
                )
            }
            .padding()
        }
        .navigationTitle(L10n.navHistory)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text("VibeWave")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .primaryAction) {
                Picker("", selection: $viewModel.selectedTimeRange) {
                    ForEach(HistoryTimeRangeOption.allCases, id: \.self) { option in
                        Text(option.displayName)
                            .padding(.horizontal, ToolbarSegmentedControlStyle.segmentLabelHorizontalPadding)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .background(
                    TitleBarSegmentedControlMatcher(sourceSegmentCount: ContentView.AppTab.allCases.count)
                )
            }
        }
        .onAppear {
            viewModel.setVisible(true)
            viewModel.loadIfNeeded()
        }
        .onDisappear {
            viewModel.setVisible(false)
        }
    }
}

// MARK: - Preview
#Preview {
    HistoryView(viewModel: HistoryViewModel(dbPool: DatabaseRepository.shared.dbPool()))
}
