import Foundation
import SwiftUI

public struct ChartHeaderView: View {
    private let title: String
    private let mode: Binding<ChartDisplayMode>?

    public init(title: String, mode: Binding<ChartDisplayMode>? = nil) {
        self.title = title
        self.mode = mode
    }

    public var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(width: 120, alignment: .leading)

            Spacer()

            if let mode {
                Picker("图表类型", selection: mode) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
