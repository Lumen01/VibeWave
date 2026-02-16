import SwiftUI

/// A macOS-styled horizontal bar chart showing session depth distribution
/// Shallow (blue), Medium (orange), Deep (purple)
public struct SessionDepthChart: View {
    let shallow: Int
    let medium: Int
    let deep: Int

    public init(shallow: Int, medium: Int, deep: Int) {
        self.shallow = shallow
        self.medium = medium
        self.deep = deep
    }

    public var body: some View {
        let total = shallow + medium + deep

        VStack(spacing: 12) {
            HStack {
                Text(L10n.sessionDepth)
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(L10n.sessionDepthDesc)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Horizontal bar chart
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let chartPadding: CGFloat = 10 // 10% padding for 80% bar width
                let chartWidth = availableWidth - chartPadding * 2
                let barHeight: CGFloat = 10

                // Calculate segment positions
                let totalWidth = chartWidth
                let shallowWidth = total > 0 ? CGFloat(shallow) / CGFloat(total) * totalWidth : 0
                let mediumWidth = total > 0 ? CGFloat(medium) / CGFloat(total) * totalWidth : 0
                let deepWidth = total > 0 ? CGFloat(deep) / CGFloat(total) * totalWidth : 0

                ZStack {
                    // Shallow segment (blue) - left
                    if shallow > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: max(shallowWidth, 0), height: barHeight)
                            .position(x: chartPadding + shallowWidth/2, y: 16)
                    }

                    // Medium segment (orange) - middle
                    if medium > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: max(mediumWidth, 0), height: barHeight)
                            .position(x: chartPadding + shallowWidth + mediumWidth/2, y: 16)
                    }

                    // Deep segment (purple) - right
                    if deep > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple.opacity(0.8))
                            .frame(width: max(deepWidth, 0), height: barHeight)
                            .position(x: chartPadding + shallowWidth + mediumWidth + deepWidth/2, y: 16)
                    }

                    // Separators between segments
                    if shallow > 0 && (medium > 0 || deep > 0) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 1.5, height: 20)
                            .position(x: chartPadding + shallowWidth, y: 16)
                    }

                    if medium > 0 && deep > 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 1.5, height: 20)
                            .position(x: chartPadding + shallowWidth + mediumWidth, y: 16)
                    }
                }
            }
            .frame(height: 32)

            // Summary labels - 始终显示，数据为空时显示占位符
            let shallowPercent = total > 0 ? Int(Double(shallow) / Double(total) * 100) : 0
            let mediumPercent = total > 0 ? Int(Double(medium) / Double(total) * 100) : 0
            let deepPercent = total > 0 ? Int(Double(deep) / Double(total) * 100) : 0

            HStack(spacing: 16) {
                // Shallow
                HStack(spacing: 2) {
                    Text(total > 0 ? "\(shallow)(\(shallowPercent)%)" : "-")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text(L10n.sessionDepthShallow)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Medium
                HStack(spacing: 2) {
                    Text(total > 0 ? "\(medium)(\(mediumPercent)%)" : "-")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(L10n.sessionDepthMedium)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Deep
                HStack(spacing: 2) {
                    Text(total > 0 ? "\(deep)(\(deepPercent)%)" : "-")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                    Text(L10n.sessionDepthDeep)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .opacity(total > 0 ? 1.0 : 0.5)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

#if DEBUG
struct SessionDepthChart_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SessionDepthChart(shallow: 45, medium: 30, deep: 15)
            SessionDepthChart(shallow: 0, medium: 0, deep: 0)
            SessionDepthChart(shallow: 100, medium: 0, deep: 0)
        }
        .padding()
        .frame(width: 600)
    }
}
#endif
