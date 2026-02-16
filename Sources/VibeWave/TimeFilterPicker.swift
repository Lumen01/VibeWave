import SwiftUI

public struct TimeFilterPicker: View {
    @Binding var selectedTimeRange: OverviewViewModel.TimeRangeOption
    
    public init(selectedTimeRange: Binding<OverviewViewModel.TimeRangeOption>) {
        self._selectedTimeRange = selectedTimeRange
    }
    
    public var body: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(OverviewViewModel.TimeRangeOption.allCases, id: \.self) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.menu)
    }
}