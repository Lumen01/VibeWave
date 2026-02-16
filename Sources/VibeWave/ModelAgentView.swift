import Foundation
import SwiftUI

enum ModelAgentLegendLayout {
    static func rows<T>(_ items: [T], itemsPerRow: Int = 4) -> [[T]] {
        guard !items.isEmpty else { return [] }
        let rowSize = max(1, itemsPerRow)
        var result: [[T]] = []
        var startIndex = 0

        while startIndex < items.count {
            let endIndex = min(startIndex + rowSize, items.count)
            result.append(Array(items[startIndex..<endIndex]))
            startIndex = endIndex
        }

        return result
    }
}

enum ModelAgentChartMode: CaseIterable, Identifiable {
    case model
    case agent

    var id: Self { self }

    var segmentTitle: String {
        switch self {
        case .model:
            return L10n.modelModel
        case .agent:
            return L10n.modelAgent
        }
    }
}

/// Model and Agent View - 模型和 Agent 统计视图
/// 显示模型贡献率和 Agent 使用比例
public struct ModelAgentView: View {
    let modelAgentStats: StatisticsRepository.ProjectModelAgentStats?
    @State private var selectedChartMode: ModelAgentChartMode = .model
    private let legendItemsPerRow = 4
    private let chartBarHeight: CGFloat = 10
    private let chartBarCornerRadius: CGFloat = 4

    public init(modelAgentStats: StatisticsRepository.ProjectModelAgentStats?) {
        self.modelAgentStats = modelAgentStats
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.modelAndAgentTitle)
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                modelAgentDistributionSection
            }
        }
    }

    // MARK: - 模型贡献率 / Agent 使用比例

    private var modelAgentDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(L10n.modelUsageRatio)
                    .font(.headline)
                
                Spacer(minLength: 8)
                
                Picker(L10n.modelStatDimension, selection: $selectedChartMode) {
                    ForEach(ModelAgentChartMode.allCases) { mode in
                        Text(mode.segmentTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }

            switch selectedChartMode {
            case .model:
                modelContributionContent
            case .agent:
                agentUsageContent
                    .frame(alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder
    private var modelContributionContent: some View {
        if let modelContributions = modelAgentStats?.modelContributions, !modelContributions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                stackedBar(
                    percentages: modelContributions.map(\.percentage),
                    color: modelColor(forIndex:)
                )
                modelContributionLegendRows(modelContributions)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            placeholderRow(title: L10n.modelNoData)
        }
    }

    @ViewBuilder
    private var agentUsageContent: some View {
        if let agentUsages = modelAgentStats?.agentUsages, !agentUsages.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                stackedBar(
                    percentages: agentUsages.map(\.percentage),
                    color: agentColor(forIndex:)
                )
                agentUsageLegendRows(agentUsages)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            placeholderRow(title: L10n.modelNoData)
        }
    }

    // MARK: - Helpers

    private var placeholderRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: chartBarCornerRadius)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: chartBarHeight)

            HStack {
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                Text(L10n.modelNoData)
                    .font(.system(.caption))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private func placeholderRow(title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: chartBarCornerRadius)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: chartBarHeight)

            HStack {
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.system(.caption))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private func stackedBar(
        percentages: [Double],
        color: @escaping (Int) -> Color
    ) -> some View {
        GeometryReader { geometry in
            let barWidth = max(0, geometry.size.width)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: chartBarCornerRadius)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: chartBarHeight)

                HStack(spacing: 0) {
                    ForEach(Array(percentages.enumerated()), id: \.offset) { index, percentage in
                        let segmentWidth = barWidth * max(0, CGFloat(percentage)) / 100
                        color(index)
                            .frame(width: segmentWidth, height: chartBarHeight)
                    }
                }
                .frame(height: chartBarHeight)
                .clipShape(RoundedRectangle(cornerRadius: chartBarCornerRadius))
            }
        }
        .frame(height: chartBarHeight)
    }

    private func modelContributionLegendRows(
        _ modelContributions: [StatisticsRepository.ProjectModelAgentStats.ModelContribution]
    ) -> some View {
        let indexed = Array(modelContributions.enumerated())
        let rows = ModelAgentLegendLayout.rows(indexed, itemsPerRow: legendItemsPerRow)
        return legendRows(rows: rows) { item in
            modelLegendItem(
                index: item.offset,
                model: item.element
            )
        }
    }

    private func agentUsageLegendRows(
        _ agentUsages: [StatisticsRepository.ProjectModelAgentStats.AgentUsage]
    ) -> some View {
        let indexed = Array(agentUsages.enumerated())
        let rows = ModelAgentLegendLayout.rows(indexed, itemsPerRow: legendItemsPerRow)
        return legendRows(rows: rows) { item in
            agentLegendItem(
                index: item.offset,
                agent: item.element
            )
        }
    }

    private func legendRows<T, Content: View>(
        rows: [[(offset: Int, element: T)]],
        @ViewBuilder content: @escaping ((offset: Int, element: T)) -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(row, id: \.offset) { item in
                        content(item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    let placeholders = max(0, legendItemsPerRow - row.count)
                    ForEach(0..<placeholders, id: \.self) { _ in
                        Color.clear
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func modelLegendItem(
        index: Int,
        model: StatisticsRepository.ProjectModelAgentStats.ModelContribution
    ) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Circle()
                .fill(modelColor(forIndex: index))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                let displayModelId = model.modelId.split(separator: "/").last.map(String.init) ?? model.modelId
                HStack(spacing: 4) {
                    Text(displayModelId)
                        .font(.system(.caption, weight: .semibold))
                        .lineLimit(1)
                    Text(formatTokens(model.inputTokens))
                        .font(.system(.caption))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !model.providerId.isEmpty {
                    Text(model.providerId)
                        .font(.system(.caption2))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func agentLegendItem(
        index: Int,
        agent: StatisticsRepository.ProjectModelAgentStats.AgentUsage
    ) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(agentColor(forIndex: index))
                .frame(width: 6, height: 6)
            Text(agent.agent)
                .font(.system(.caption, weight: .semibold))
                .lineLimit(1)
            Text(formatNumber(agent.messageCount))
                .font(.system(.caption))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private func modelColor(forIndex index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink]
        return colors[index % colors.count]
    }

    private func agentColor(forIndex index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red]
        return colors[index % colors.count]
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        } else {
            return String(tokens)
        }
    }

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

}
