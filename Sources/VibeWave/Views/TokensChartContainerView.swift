import Foundation
import SwiftUI

public struct TokensChartContainerView: View {
    private let inputTokensData: [InputTokensDataPoint]
    private let outputReasoningData: [OutputReasoningDataPoint]
    private let isLoading: Bool
    private let timeRange: HistoryTimeRangeOption
    @Binding private var tokensChartType: TokensChartType
    @Binding private var inputTokensChartMode: ChartDisplayMode
    @Binding private var outputReasoningChartMode: ChartDisplayMode

    private enum Constants {
        static let backgroundCornerRadius: CGFloat = 12
    }

    public init(
        inputTokensData: [InputTokensDataPoint],
        outputReasoningData: [OutputReasoningDataPoint],
        isLoading: Bool,
        timeRange: HistoryTimeRangeOption,
        tokensChartType: Binding<TokensChartType>,
        inputTokensChartMode: Binding<ChartDisplayMode>,
        outputReasoningChartMode: Binding<ChartDisplayMode>
    ) {
        self.inputTokensData = inputTokensData
        self.outputReasoningData = outputReasoningData
        self.isLoading = isLoading
        self.timeRange = timeRange
        self._tokensChartType = tokensChartType
        self._inputTokensChartMode = inputTokensChartMode
        self._outputReasoningChartMode = outputReasoningChartMode
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
            Text(L10n.chartTokens)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(width: 120, alignment: .leading)

            Spacer()

            Picker("Token Type", selection: $tokensChartType) {
                ForEach(TokensChartType.allCases, id: \.self) { type in
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
            switch tokensChartType {
            case .input:
                InputTokensChartContentView(
                    data: inputTokensData,
                    isLoading: isLoading,
                    timeRange: timeRange,
                    mode: $inputTokensChartMode
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            case .output:
                OutputReasoningChartContentView(
                    data: outputReasoningData,
                    isLoading: isLoading,
                    timeRange: timeRange,
                    mode: $outputReasoningChartMode
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    private var chartModeBinding: Binding<ChartDisplayMode> {
        switch tokensChartType {
        case .input:
            return $inputTokensChartMode
        case .output:
            return $outputReasoningChartMode
        }
    }
}

// MARK: - Preview
#Preview {
    TokensChartContainerView(
        inputTokensData: [],
        outputReasoningData: [],
        isLoading: false,
        timeRange: .last24Hours,
        tokensChartType: .constant(.input),
        inputTokensChartMode: .constant(.bar),
        outputReasoningChartMode: .constant(.bar)
    )
    .frame(width: 600, height: 300)
    .padding()
}
