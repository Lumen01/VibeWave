import SwiftUI
import Foundation
import Combine

public struct OverviewView: View {
    @ObservedObject var viewModel: OverviewViewModel

    public init(viewModel: OverviewViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let error = viewModel.errorMessage, viewModel.stats == nil {
                    errorView(error)
                } else {
                    VStack(spacing: 20) {
                        if #available(macOS 14.0, *) {
                            statsContent(viewModel.stats ?? zeroStats)
                        }

                        // Extended metrics area (placeholders for Task 4)
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(spacing: 16) {
                                codeOutputSection
                                sessionDepthSection
                            }
                            topProjectsSection
                            topModelsSection
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(L10n.navOverview)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text("VibeWave")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .primaryAction) {
                timeRangePicker
            }
        }
        .alert(L10n.errorLoadFailed, isPresented: $viewModel.showErrorAlert) {
            Button(L10n.commonConfirm, role: .cancel) { }
            Button(L10n.commonRetry) {
                viewModel.loadStats()
            }
        } message: {
            Text(L10n.errorCannotLoadStats)
        }
        .onAppear {
            viewModel.setVisible(true)
            viewModel.loadIfNeeded()
        }
        .onDisappear {
            viewModel.setVisible(false)
        }
    }

    var timeRangePicker: some View {
        Picker("", selection: $viewModel.selectedTimeRange) {
            ForEach(OverviewViewModel.TimeRangeOption.allCases, id: \.self) { option in
                Text(option.displayName)
                    .padding(.horizontal, ToolbarSegmentedControlStyle.segmentLabelHorizontalPadding)
                    .tag(option)
                    .keyboardShortcut(
                        option == .today ? "8" :
                        option == .last30Days ? "9" : "0",
                        modifiers: .command
                    )
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .background(
            TitleBarSegmentedControlMatcher(sourceSegmentCount: ContentView.AppTab.allCases.count)
        )
        .onChange(of: viewModel.selectedTimeRange) { _ in
            viewModel.loadStats()
        }
    }

    var zeroStats: StatisticsRepository.OverviewStats {
        StatisticsRepository.OverviewStats(
            totalSessions: 0,
            totalMessages: 0,
            totalCost: 0.0,
            totalTokens: 0,
            inputTokens: 0,
            outputTokens: 0,
            reasoningTokens: 0,
            cacheRead: 0,
            cacheWrite: 0
        )
    }

    @ViewBuilder
    @available(macOS 14.0, *)
    func statsContent(_ stats: StatisticsRepository.OverviewStats) -> some View {
        VStack(spacing: 16) {
            // Row 1: Core Usage
            HStack(spacing: 16) {
                AnimatedKPICard(
                    title: L10n.kpiSessions,
                    value: stats.totalSessions,
                    icon: "doc.text",
                    format: .plain,
                    trendValues: viewModel.kpiTrends.sessions
                )
                AnimatedKPICard(
                    title: L10n.kpiMessages,
                    value: stats.totalMessages,
                    icon: "bubble.left",
                    format: .plain,
                    trendValues: viewModel.kpiTrends.messages
                )
                AnimatedKPICard(
                    title: L10n.kpiCost,
                    value: Int(stats.totalCost * 100),
                    icon: "dollarsign.circle",
                    format: .currency,
                    trendValues: viewModel.kpiTrends.cost
                )
            }

            // Row 2: Token Breakdown
            HStack(spacing: 16) {
                AnimatedKPICard(
                    title: L10n.kpiInput,
                    value: stats.inputTokens,
                    icon: "arrow.down",
                    format: .compact,
                    trendValues: viewModel.kpiTrends.inputTokens
                )
                AnimatedKPICard(
                    title: L10n.kpiOutput,
                    value: stats.outputTokens,
                    icon: "arrow.up",
                    format: .compact,
                    trendValues: viewModel.kpiTrends.outputTokens
                )
                AnimatedKPICard(
                    title: L10n.kpiReasoning,
                    value: stats.reasoningTokens,
                    icon: "brain",
                    format: .compact,
                    trendValues: viewModel.kpiTrends.reasoningTokens
                )
            }

            // Row 3: Cache and Efficiency
            HStack(spacing: 16) {
                AnimatedKPICard(
                    title: L10n.kpiCacheRead,
                    value: stats.cacheRead,
                    icon: "externaldrive",
                    format: .compact,
                    trendValues: viewModel.kpiTrends.cacheRead
                )
                AnimatedKPICard(
                    title: L10n.kpiCacheWrite,
                    value: stats.cacheWrite,
                    icon: "externaldrive.badge.plus",
                    format: .compact,
                    trendValues: viewModel.kpiTrends.cacheWrite
                )
                AnimatedKPICard(
                    title: L10n.kpiAvgPerSession,
                    value: avgTokensPerSession(stats),
                    icon: "cpu",
                    format: .compact,
                    trendValues: viewModel.kpiTrends.avgTokensPerSession
                )
            }
        }
    }

    var sessionDepthSection: some View {
        SessionDepthChart(
            shallow: viewModel.sessionDepthDistribution.shallow,
            medium: viewModel.sessionDepthDistribution.medium,
            deep: viewModel.sessionDepthDistribution.deep
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var topProjectsData: (projects: [StatisticsRepository.ProjectStats], maxInput: Int, maxNetCodeLines: Int, maxSessions: Int, maxMessages: Int, isEmpty: Bool) {
        let projects = Array(viewModel.topProjects.prefix(5))
        let maxInput = projects.map { $0.inputTokens }.max() ?? 1
        let maxNetCodeLines = projects.map { abs($0.netCodeLines) }.max() ?? 1
        let maxSessions = projects.map { $0.sessionCount }.max() ?? 1
        let maxMessages = projects.map { $0.messageCount }.max() ?? 1
        let isEmpty = projects.isEmpty
        return (projects, maxInput, maxNetCodeLines, maxSessions, maxMessages, isEmpty)
    }

    var topProjectsSection: some View {
        let data = topProjectsData
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // 表头 - 始终显示
                HStack(spacing: 0) {
                    Text(L10n.chartTopProjects)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(width: 100, alignment: .leading)

                    Spacer()

                    projectHeaderCell(icon: "arrow.down", title: L10n.chartColumnInput, color: .blue)
                        .padding(.leading, 4)

                    projectHeaderCell(icon: "plusminus", title: L10n.chartColumnNetCode, color: .green)
                        .padding(.leading, 4)

                    projectHeaderCell(icon: "text.document", title: L10n.chartColumnSession, color: .cyan)
                        .padding(.leading, 4)

                    projectHeaderCell(icon: "bubble.left", title: L10n.chartColumnMessage, color: .purple)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()
                    .padding(.horizontal, 12)

                // 数据行或占位行
                VStack(alignment: .leading, spacing: 0) {
                    if data.isEmpty {
                        // 空数据时显示1行占位
                        HStack(spacing: 4) {
                            // 占位项目名称
                            Text("-")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)

                            // 占位指标 - 显示短横线
                            projectPlaceholderMetricBar()
                            projectPlaceholderMetricBar()
                            projectPlaceholderMetricBar()
                            projectPlaceholderMetricBar()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    } else {
                        ForEach(Array(data.projects.enumerated()), id: \.element.id) { index, project in
                            VStack(spacing: 0) {
                                HStack(spacing: 4) {
                                    // 项目名称
                                    Text(basename(project.projectRoot))
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                        .frame(width: 100, alignment: .leading)

                                    // Input Tokens
                                    projectMetricBar(
                                        value: project.inputTokens,
                                        maxValue: data.maxInput,
                                        color: .blue,
                                        formatter: formatCompact
                                    )

                                    // 净增代码行
                                    projectMetricBar(
                                        value: abs(project.netCodeLines),
                                        maxValue: data.maxNetCodeLines,
                                        color: .green,
                                        formatter: formatNetCodeLines
                                    )

                                    // 会话数
                                    projectMetricBar(
                                        value: project.sessionCount,
                                        maxValue: data.maxSessions,
                                        color: .cyan,
                                        formatter: formatNumber
                                    )

                                    // 消息数
                                    projectMetricBar(
                                        value: project.messageCount,
                                        maxValue: data.maxMessages,
                                        color: .purple,
                                        formatter: formatNumber
                                    )
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)

                                if index < data.projects.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                    }
                }
            }
            .opacity(data.isEmpty ? 0.5 : 1.0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func projectHeaderCell(icon: String, title: String, color: Color) -> some View {
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

    private func projectMetricBar(
        value: Int,
        maxValue: Int,
        color: Color,
        formatter: (Int) -> String
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            GeometryReader { geo in
                let ratio = maxValue > 0 ? Double(value) / Double(maxValue) : 0
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(color == .purple ? 0.7 : 0.8))
                    .frame(width: geo.size.width * ratio, height: 10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 10)
            Text(formatter(value))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private func projectPlaceholderMetricBar() -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 20, height: 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("-")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    func headerCell(icon: String, title: String, width: CGFloat, font: Font? = nil) -> some View {
        VStack(spacing: 4) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(title)
                .font(font ?? .system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(width: width)
    }

    func dataCell(text: String, width: CGFloat, alignment: HorizontalAlignment) -> some View {
        HStack {
            if alignment == .trailing {
                Spacer()
            }
            Text(text)
                .font(.system(size: 11, weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if alignment == .leading {
                Spacer()
            }
        }
        .frame(width: width, alignment: alignment == .trailing ? .trailing : .leading)
    }

    func formatNetCodeLines(_ value: Int) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix + formatNumber(value)
    }

    private func modelHeaderCell(icon: String, title: String, color: Color) -> some View {
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

    private var topModelsData: (models: [StatisticsRepository.ModelStats], maxInput: Int, maxOutput: Int, maxReasoning: Int, maxMessages: Int, isEmpty: Bool) {
        let models = Array(viewModel.topModels.prefix(11))
        let maxInput = models.map { $0.inputTokens }.max() ?? 1
        let maxOutput = models.map { $0.outputTokens }.max() ?? 1
        let maxReasoning = models.map { $0.reasoningTokens }.max() ?? 1
        let maxMessages = models.map { $0.messageCount }.max() ?? 1
        let isEmpty = models.isEmpty
        return (models, maxInput, maxOutput, maxReasoning, maxMessages, isEmpty)
    }

    private var topModelsSectionHeader: some View {
        HStack(spacing: 0) {
            Text(L10n.chartTopModels)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(width: 100, alignment: .leading)

            Spacer()

            modelHeaderCell(icon: "arrow.down", title: L10n.chartColumnInput, color: .blue)
                .padding(.leading, 4)

            modelHeaderCell(icon: "arrow.up", title: L10n.chartColumnOutput, color: .red)
                .padding(.leading, 4)

            modelHeaderCell(icon: "brain", title: L10n.chartColumnReasoning, color: .orange)
                .padding(.leading, 4)

            modelHeaderCell(icon: "bubble.left", title: L10n.chartColumnMessage, color: .purple)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var topModelsSectionContent: some View {
        let data = topModelsData
        return VStack(alignment: .leading, spacing: 0) {
            if data.isEmpty {
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("-")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("-")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 100, alignment: .leading)

                    modelPlaceholderMetricBar()
                    modelPlaceholderMetricBar()
                    modelPlaceholderMetricBar()
                    modelPlaceholderMetricBar()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            } else {
                ForEach(Array(data.models.enumerated()), id: \.element.uniqueId) { index, model in
                    VStack(spacing: 0) {
                        HStack(spacing: 4) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.modelId.components(separatedBy: "/").last ?? model.modelId)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Text(model.providerId)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 100, alignment: .leading)

                            modelMetricBar(value: model.inputTokens, maxValue: data.maxInput, color: .blue, formatter: formatCompact)
                            modelMetricBar(value: model.outputTokens, maxValue: data.maxOutput, color: .red, formatter: formatCompact)
                            modelMetricBar(value: model.reasoningTokens, maxValue: data.maxReasoning, color: .orange, formatter: formatCompact)
                            modelMetricBar(value: model.messageCount, maxValue: data.maxMessages, color: .purple, formatter: formatNumber)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)

                        if index < data.models.count - 1 {
                            Divider()
                                .padding(.horizontal, 12)
                        }
                    }
                }
            }
        }
    }

    var topModelsSection: some View {
        let data = topModelsData
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                topModelsSectionHeader
                Divider()
                    .padding(.horizontal, 12)
                topModelsSectionContent
            }
            .opacity(data.isEmpty ? 0.5 : 1.0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func modelMetricBar(
        value: Int,
        maxValue: Int,
        color: Color,
        formatter: (Int) -> String
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            GeometryReader { geo in
                let ratio = maxValue > 0 ? Double(value) / Double(maxValue) : 0
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(color == .purple ? 0.7 : 0.8))
                    .frame(width: geo.size.width * ratio, height: 10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 10)
            Text(formatter(value))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private func modelPlaceholderMetricBar() -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 20, height: 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("-")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    var codeOutputSection: some View {
        CodeImpactChart(
            additions: viewModel.codeOutputStats.totalAdditions,
            deletions: viewModel.codeOutputStats.totalDeletions,
            fileCount: viewModel.codeOutputStats.fileCount
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func avgTokensPerSession(_ stats: StatisticsRepository.OverviewStats) -> Int {
        guard stats.totalSessions > 0 else { return 0 }
        return stats.totalTokens / stats.totalSessions
    }

    private func basename(_ path: String) -> String {
        if path == "/" {
            return "/"
        }
        let components = path.split(separator: "/")
        return String(components.last ?? "")
    }

    private func depthItem(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text(L10n.errorCannotLoadStats)
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(L10n.commonRetry, action: viewModel.manualRefresh)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
}

func formatCompact(_ value: Int) -> String {
    if value >= 1_000_000 {
        let d = Double(value) / 1_000_000.0
        if d.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%dM", Int(d))
        } else {
            return String(format: "%.1fM", d)
        }
    } else if value >= 1_000 {
        let d = Double(value) / 1_000.0
        if d.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%dK", Int(d))
        } else {
            return String(format: "%.1fK", d)
        }
    } else {
        return String(value)
    }
}

func formatCost(_ cost: Double) -> String {
    return String(format: "$%.2f", cost)
}

func formatNumber(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}
