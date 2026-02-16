import SwiftUI

struct MenuBarPopupView: View {
    @StateObject private var viewModel = MenuBarViewModel.shared

    var body: some View {
        VStack(spacing: 10) {
            totalUsageCard

            VStack(spacing: 10) {
                kpiGridView

                if !viewModel.topModels.isEmpty {
                    topModelsView
                }

                if !viewModel.topProjects.isEmpty {
                    topProjectsView
                }
            }

            footerView
        }
        .frame(width: 340)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var totalUsageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.gauge.chart.lefthalf.righthalf")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(L10n.menuBarTotalUsage)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary.opacity(0.7))

                        Text(viewModel.formatNumber(viewModel.totalUsageTokens))
                            .font(.system(size: 11, weight: .bold))

                        Text(L10n.chartSeparator)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary.opacity(0.7))

                        Text(viewModel.formatCost(viewModel.totalUsageCost))
                            .font(.system(size: 11, weight: .bold))
                    }

                    if let firstDate = viewModel.firstUsageDate {
                        HStack(spacing: 4) {
                            if let daysString = viewModel.usageDaysString {
                                Text(daysString)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.primary.opacity(0.7))
                            }

                            Text(L10n.menuBarSince)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(0.7))

                            Text(formatDate(firstDate))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.primary.opacity(0.7))
                        }
                    }
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 0)
    }
    
    private var totalUsageRow: some View {
        HStack {
            HStack(spacing: 4) {
                Text(L10n.menuBarTotalUsage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Text(viewModel.formatNumber(viewModel.totalUsageTokens))
                    .font(.system(size: 11, weight: .semibold))
                
                Text(L10n.chartSeparator)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Text(viewModel.formatCost(viewModel.totalUsageCost))
                    .font(.system(size: 11, weight: .semibold))
            }
            
            Spacer()
            
            if let firstDate = viewModel.firstUsageDate {
                HStack(spacing: 4) {
                    Text(L10n.menuBarSince)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    Text(formatDate(firstDate))
                        .font(.system(size: 11))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        // Use current app language to format date
        let lang = LocalizationManager.shared.currentLanguage
        if lang == "zh_CN" {
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy年M月d日"
        } else {
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        return formatter.string(from: date)
    }
    
    private var kpiGridView: some View {
        let stats = viewModel.stats ?? StatisticsRepository.OverviewStats(
            totalSessions: 0, totalMessages: 0, totalCost: 0,
            totalTokens: 0, inputTokens: 0, outputTokens: 0,
            reasoningTokens: 0, cacheRead: 0, cacheWrite: 0
        )

        let avgTokensPerSession = stats.totalSessions > 0
            ? stats.totalTokens / stats.totalSessions
            : 0

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                MenuBarKPICard(
                    title: L10n.menuBarKpiSessions,
                    value: viewModel.formatNumber(stats.totalSessions),
                    icon: "doc.text"
                )
                MenuBarKPICard(
                    title: L10n.menuBarKpiMessages,
                    value: viewModel.formatNumber(stats.totalMessages),
                    icon: "bubble.left"
                )
                MenuBarKPICard(
                    title: L10n.menuBarKpiCost,
                    value: viewModel.formatCost(stats.totalCost),
                    icon: "dollarsign.circle"
                )
            }

            HStack(spacing: 10) {
                MenuBarKPICard(
                    title: L10n.menuBarKpiInput,
                    value: viewModel.formatNumber(stats.inputTokens),
                    icon: "arrow.down"
                )
                MenuBarKPICard(
                    title: L10n.menuBarKpiOutput,
                    value: viewModel.formatNumber(stats.outputTokens),
                    icon: "arrow.up"
                )
                MenuBarKPICard(
                    title: L10n.menuBarKpiReasoning,
                    value: viewModel.formatNumber(stats.reasoningTokens),
                    icon: "brain"
                )
            }

            HStack(spacing: 10) {
                MenuBarKPICard(
                    title: L10n.menuBarKpiCacheRead,
                    value: viewModel.formatNumber(stats.cacheRead),
                    icon: "externaldrive"
                )
                MenuBarKPICard(
                    title: L10n.menuBarKpiCacheWrite,
                    value: viewModel.formatNumber(stats.cacheWrite),
                    icon: "externaldrive.badge.plus"
                )
                MenuBarKPICard(
                    title: L10n.menuBarKpiAvgPerSession,
                    value: viewModel.formatNumber(avgTokensPerSession),
                    icon: "cpu"
                )
            }
        }
    }
    
    private var topModelsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.menuBarTopModels)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                
                Spacer()
                
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 50, alignment: .trailing)

                    Image(systemName: "arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 50, alignment: .trailing)

                    Image(systemName: "bubble.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 8)

            VStack(spacing: 0) {
                ForEach(viewModel.topModels.prefix(11), id: \.modelId) { model in
                    ModelTableRow(model: model, viewModel: viewModel)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 0)
    }

    private var topProjectsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.menuBarTopProjects)
                    .font(.headline)

                Spacer()

                HStack(spacing: 12) {
                    Image(systemName: "cpu")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 50, alignment: .trailing)

                    Image(systemName: "doc.text")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 50, alignment: .trailing)

                    Image(systemName: "bubble.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 8)

            VStack(spacing: 0) {
                ForEach(viewModel.topProjects.prefix(5), id: \.projectRoot) { project in
                    ProjectTableRow(project: project, viewModel: viewModel)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 0)
    }

    private var footerView: some View {
        HStack(spacing: 16) {
            Button {
                openMainWindow()
            } label: {
                Label(L10n.menuBarOpen, systemImage: "macwindow")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label(L10n.menuBarQuit, systemImage: "power")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 0)
    }
    
    private func openMainWindow() {
        // Close the popup window first (it has .popUpMenu level)
        if let popupWindow = NSApp.windows.first(where: { $0.level == .popUpMenu }) {
            popupWindow.orderOut(nil)
        }
        
        NSApp.activate(ignoringOtherApps: true)
        if let mainWindow = NSApp.windows.first(where: { $0.level == .normal }) {
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }
    
    private func openSettings() {
        // Close the popup window first (it has .popUpMenu level)
        if let popupWindow = NSApp.windows.first(where: { $0.level == .popUpMenu }) {
            popupWindow.orderOut(nil)
        }
        
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

struct MenuBarKPICard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
            
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 0)
    }
}

struct ModelTableRow: View {
    let model: StatisticsRepository.ModelStats
    let viewModel: MenuBarViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.modelId.components(separatedBy: "/").last ?? model.modelId)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(model.providerId)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 12) {
                Text(viewModel.formatNumber(model.inputTokens))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 50, alignment: .trailing)
                
                Text(viewModel.formatNumber(model.outputTokens))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 50, alignment: .trailing)
                
                Text(viewModel.formatNumber(model.messageCount))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

struct ProjectTableRow: View {
    let project: StatisticsRepository.ProjectStats
    let viewModel: MenuBarViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: project.projectRoot).lastPathComponent)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 12) {
                Text(viewModel.formatNumber(project.tokens))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 50, alignment: .trailing)
                
                Text(viewModel.formatNumber(project.sessionCount))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 50, alignment: .trailing)
                
                Text(viewModel.formatNumber(project.messageCount))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
