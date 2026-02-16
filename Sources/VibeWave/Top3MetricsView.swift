import SwiftUI

/// Top 3 Metrics View - 显示每日 Top 3 数据的表格视图
/// 包含5个维度：净增代码、Input Tokens、消息数、消息总时长、成本
public struct Top3MetricsView: View {
    let top3NetCodeLines: [StatisticsRepository.DailyTop3Stat]
    let top3InputTokens: [StatisticsRepository.DailyTop3Stat]
    let top3MessageCount: [StatisticsRepository.DailyTop3Stat]
    let top3Duration: [StatisticsRepository.DailyTop3Stat]
    let top3Cost: [StatisticsRepository.DailyTop3Stat]
    let showsBackground: Bool

    public init(
        top3NetCodeLines: [StatisticsRepository.DailyTop3Stat],
        top3InputTokens: [StatisticsRepository.DailyTop3Stat],
        top3MessageCount: [StatisticsRepository.DailyTop3Stat],
        top3Duration: [StatisticsRepository.DailyTop3Stat],
        top3Cost: [StatisticsRepository.DailyTop3Stat],
        showsBackground: Bool = true
    ) {
        self.top3NetCodeLines = top3NetCodeLines
        self.top3InputTokens = top3InputTokens
        self.top3MessageCount = top3MessageCount
        self.top3Duration = top3Duration
        self.top3Cost = top3Cost
        self.showsBackground = showsBackground
    }

    public var body: some View {
        if showsBackground {
            top3Container
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                )
        } else {
            top3Container
        }
    }

    private var top3Container: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // 表头
                top3Header()

                Divider()
                    .padding(.horizontal, 12)

                // 数据行
                top3Content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // Header

    private func top3Header() -> some View {
        HStack(spacing: 4) {
            top3HeaderCell(icon: "plusminus", title: L10n.top3NetCodeLines, color: .green)
            top3HeaderCell(icon: "arrow.down", title: L10n.insightMetricInputTokens, color: .blue)
            top3HeaderCell(icon: "text.document", title: L10n.top3Messages, color: .purple)
            top3HeaderCell(icon: "clock", title: L10n.top3TotalDuration, color: .orange)
            top3HeaderCell(icon: "dollarsign.circle", title: L10n.top3Cost, color: .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func top3HeaderCell(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // Content

    private func top3Content() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if top3NetCodeLines.isEmpty && top3InputTokens.isEmpty &&
               top3MessageCount.isEmpty && top3Duration.isEmpty && top3Cost.isEmpty {
                emptyRow()
            } else {
                ForEach(0..<3, id: \.self) { rowIndex in
                    if rowIndex < maxRowCount() {
                        VStack(spacing: 0) {
                            top3Row(rowIndex: rowIndex)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)

                            if rowIndex < 2 && rowIndex < maxRowCount() - 1 {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    private func top3Row(rowIndex: Int) -> some View {
        HStack(spacing: 4) {
            // 净增代码
            top3MetricBar(
                stats: top3NetCodeLines,
                rowIndex: rowIndex,
                valueGetter: { $0.netCodeLines },
                color: .green,
                valueFormatter: formatIntegerWithComma
            )

            // Input Tokens
            top3MetricBar(
                stats: top3InputTokens,
                rowIndex: rowIndex,
                valueGetter: { $0.inputTokens },
                color: .blue,
                valueFormatter: formatIntWithCompact
            )

            // 消息数
            top3MetricBar(
                stats: top3MessageCount,
                rowIndex: rowIndex,
                valueGetter: { $0.messageCount },
                color: .purple,
                valueFormatter: formatIntegerWithComma
            )

            // 消息总时长
            top3MetricBar(
                stats: top3Duration,
                rowIndex: rowIndex,
                valueGetter: { $0.totalDurationMs },
                color: .orange,
                valueFormatter: formatInt64ToDuration
            )

            // 成本
            top3MetricBar(
                stats: top3Cost,
                rowIndex: rowIndex,
                valueGetter: { $0.cost },
                color: .red,
                valueFormatter: formatCost
            )
        }
    }

    func top3MetricBar(
        stats: [StatisticsRepository.DailyTop3Stat],
        rowIndex: Int,
        valueGetter: (StatisticsRepository.DailyTop3Stat) -> Int,
        color: Color,
        valueFormatter: (Int) -> String
    ) -> AnyView {
        let allStats = top3NetCodeLines.isEmpty && top3InputTokens.isEmpty &&
                       top3MessageCount.isEmpty && top3Duration.isEmpty && top3Cost.isEmpty

        guard rowIndex < stats.count, !allStats else {
            return AnyView(placeholderMetricBar())
        }

        let stat = stats[rowIndex]
        let value = valueGetter(stat)
        let firstValue = stats.isEmpty ? 1 : valueGetter(stats.first!)
        let ratio = firstValue > 0 ? min(Double(value) / Double(firstValue), 1.0) : 0.0

        return AnyView(metricBarInner(
            stat: stat,
            ratio: ratio,
            color: color,
            valueFormatter: { valueFormatter(value) }
        ))
    }

    func top3MetricBar(
        stats: [StatisticsRepository.DailyTop3Stat],
        rowIndex: Int,
        valueGetter: (StatisticsRepository.DailyTop3Stat) -> Int64,
        color: Color,
        valueFormatter: (Int64) -> String
    ) -> AnyView {
        let allStats = top3NetCodeLines.isEmpty && top3InputTokens.isEmpty &&
                       top3MessageCount.isEmpty && top3Duration.isEmpty && top3Cost.isEmpty

        guard rowIndex < stats.count, !allStats else {
            return AnyView(placeholderMetricBar())
        }

        let stat = stats[rowIndex]
        let value = valueGetter(stat)
        let firstValue = stats.isEmpty ? 1 : valueGetter(stats.first!)
        let ratio = firstValue > 0 ? min(Double(value) / Double(firstValue), 1.0) : 0.0

        return AnyView(metricBarInner(
            stat: stat,
            ratio: ratio,
            color: color,
            valueFormatter: { valueFormatter(value) }
        ))
    }

    func top3MetricBar(
        stats: [StatisticsRepository.DailyTop3Stat],
        rowIndex: Int,
        valueGetter: (StatisticsRepository.DailyTop3Stat) -> Double,
        color: Color,
        valueFormatter: (Double) -> String
    ) -> AnyView {
        let allStats = top3NetCodeLines.isEmpty && top3InputTokens.isEmpty &&
                       top3MessageCount.isEmpty && top3Duration.isEmpty && top3Cost.isEmpty

        guard rowIndex < stats.count, !allStats else {
            return AnyView(placeholderMetricBar())
        }

        let stat = stats[rowIndex]
        let value = valueGetter(stat)
        let firstValue = stats.isEmpty ? 1.0 : valueGetter(stats.first!)
        let ratio = firstValue > 0 ? min(value / firstValue, 1.0) : 0.0

        return AnyView(metricBarInner(
            stat: stat,
            ratio: ratio,
            color: color,
            valueFormatter: { valueFormatter(value) }
        ))
    }

    private func metricBarInner(
        stat: StatisticsRepository.DailyTop3Stat,
        ratio: Double,
        color: Color,
        valueFormatter: () -> String
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.8))
                    .frame(width: geo.size.width * CGFloat(ratio), height: 10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 2)
            }
            .frame(height: 10)

            HStack(spacing: 4) {
                Spacer()

                Text(valueFormatter())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))

                Text(formatDate(stat.date))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func placeholderMetricBar() -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 20, height: 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 2)

            Text("-")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyRow() -> some View {
        HStack(spacing: 4) {
            placeholderMetricBar()
            placeholderMetricBar()
            placeholderMetricBar()
            placeholderMetricBar()
            placeholderMetricBar()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // Helpers

    private func maxRowCount() -> Int {
        max(
            top3NetCodeLines.count,
            top3InputTokens.count,
            top3MessageCount.count,
            top3Duration.count,
            top3Cost.count
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current

        if LocalizationManager.shared.currentLanguage == "zh_CN" {
            formatter.dateFormat = "M月d日"
        } else {
            formatter.dateFormat = "MM/dd"
        }

        return formatter.string(from: date)
    }

    private func formatIntegerWithComma(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func formatIntWithCompact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return formatIntegerWithComma(value)
        }
    }

    private func formatInt64ToDuration(_ durationMs: Int64) -> String {
        let totalMinutes = durationMs / 1000 / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if LocalizationManager.shared.currentLanguage == "zh_CN" {
            if hours > 0 {
                return "\(hours)小时\(minutes)分钟"
            } else {
                return "\(minutes)分钟"
            }
        } else {
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }

    private func formatCost(_ cost: Double) -> String {
        return String(format: "$%.2f", cost)
    }
}
