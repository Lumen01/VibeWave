import SwiftUI

/// A macOS-styled horizontal bar chart showing code additions and deletions
/// Centered at zero, with additions on the left (green) and deletions on the right (red)
public struct CodeImpactChart: View {
    let additions: Int
    let deletions: Int
    let fileCount: Int

    public init(additions: Int, deletions: Int, fileCount: Int) {
        self.additions = additions
        self.deletions = deletions
        self.fileCount = fileCount
    }

    public var body: some View {
        let totalChanges = additions + deletions

        VStack(spacing: 12) {
            HStack {
                Text(L10n.codeFileEdit)
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(L10n.codeFileIncludeDoc)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Horizontal bar chart - origin moves based on data
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let chartPadding: CGFloat = 10 // Reduced padding for 80% bar width
                let chartWidth = availableWidth - chartPadding * 2
                let barHeight: CGFloat = 10

                // Calculate origin position based on data proportion
                // When additions = deletions, origin is at center
                // When additions > deletions, origin shifts right
                // When additions < deletions, origin shifts left
                let originX = calculateOriginX(
                    additions: additions,
                    deletions: deletions,
                    totalChanges: totalChanges,
                    chartPadding: chartPadding,
                    chartWidth: chartWidth,
                    availableWidth: availableWidth
                )

                ZStack {
                    // Left bar - Additions (extends from left end to origin)
                    if additions > 0 {
                        let leftBarWidth = originX - chartPadding

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.8))
                            .frame(width: max(leftBarWidth, 0), height: barHeight)
                            .position(x: chartPadding + leftBarWidth/2, y: 16)
                    }

                    // Origin line (zero point) - moves based on data
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 1.5, height: 20)
                        .position(x: originX, y: 16)

                    // Right bar - Deletions (extends from origin to right end)
                    if deletions > 0 {
                        let rightBarWidth = chartPadding + chartWidth - originX

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.8))
                            .frame(width: max(rightBarWidth, 0), height: barHeight)
                            .position(x: originX + rightBarWidth/2, y: 16)
                    }
                }
            }
            .frame(height: 32)

            // Summary labels - additions, deletions, and file count in one row
            HStack(spacing: 16) {
                // Additions
                HStack(spacing: 4) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 11))
                        .foregroundColor(Color.green.opacity(0.9))
                    Text(formatNumber(additions))
                        .font(.system(size: 11))
                        .foregroundColor(Color.green.opacity(0.9))
                    Text(L10n.codeLines)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Deletions
                HStack(spacing: 4) {
                    Image(systemName: "text.badge.minus")
                        .font(.system(size: 11))
                        .foregroundColor(Color.red.opacity(0.9))
                    Text(formatNumber(deletions))
                        .font(.system(size: 11))
                        .foregroundColor(Color.red.opacity(0.9))
                    Text(L10n.codeLines)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // File count - always show label, display "-" when empty
                HStack(spacing: 4) {
                    Image(systemName: "document.on.document")
                        .font(.system(size: 10))
                        .foregroundColor(.blue.opacity(0.8))
                    Text(fileCount > 0 ? formatNumber(fileCount) : "-")
                        .font(.system(size: 11))
                        .foregroundColor(.blue.opacity(0.9))
                    Text(L10n.codeFiles)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .opacity(fileCount > 0 ? 1.0 : 0.5)
            }
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

    private func calculateOriginX(
        additions: Int,
        deletions: Int,
        totalChanges: Int,
        chartPadding: CGFloat,
        chartWidth: CGFloat,
        availableWidth: CGFloat
    ) -> CGFloat {
        if totalChanges > 0 {
            let additionRatio = CGFloat(additions) / CGFloat(totalChanges)
            // 0.5 = center, < 0.5 shifts left, > 0.5 shifts right
            return chartPadding + chartWidth * additionRatio
        } else {
            return availableWidth / 2
        }
    }

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

#if DEBUG
struct CodeImpactChart_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CodeImpactChart(additions: 1390, deletions: 396, fileCount: 31)
            CodeImpactChart(additions: 0, deletions: 0, fileCount: 0)
            CodeImpactChart(additions: 1000, deletions: 0, fileCount: 10)
        }
        .padding()
        .frame(width: 600)
    }
}
#endif
