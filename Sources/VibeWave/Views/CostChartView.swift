import Foundation
import SwiftUI

public struct CostChartView: View {
    private let data: [SingleMetricDataPoint]
    private let isLoading: Bool
    private let timeRange: HistoryTimeRangeOption
    @Binding private var mode: ChartDisplayMode

    public init(
        data: [SingleMetricDataPoint],
        isLoading: Bool,
        timeRange: HistoryTimeRangeOption,
        mode: Binding<ChartDisplayMode>
    ) {
        self.data = data
        self.isLoading = isLoading
        self.timeRange = timeRange
        self._mode = mode
    }

    public var body: some View {
        SingleMetricHistoryChartView(
            title: "Cost",
            data: data,
            isLoading: isLoading,
            timeRange: timeRange,
            mode: $mode,
            color: .green,
            valueStyle: .currency
        )
    }
}
