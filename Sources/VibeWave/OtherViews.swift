import SwiftUI

public struct ProjectsView: View {
  @StateObject private var viewModel: ProjectsViewModel
  
  public init(viewModel: ProjectsViewModel) {
    self._viewModel = StateObject(wrappedValue: viewModel)
  }
  
  public var body: some View {
    VStack(spacing: 0) {
      projectsContent

      if viewModel.selectedProject != nil {
        projectDetailView
          .transition(.opacity)
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.selectedProject)
    .navigationTitle(L10n.projectProjectList)
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Text("VibeWave")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.primary)
      }
    }
    .onAppear {
      viewModel.setVisible(true)
      viewModel.loadIfNeeded()
    }
    .onDisappear {
      viewModel.setVisible(false)
    }
  }

  private var projectDetailView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if viewModel.selectedProject != nil {
          ConsumptionEfficiencyView(
            consumption: viewModel.projectConsumption,
            automationLevel: viewModel.projectModelAgentStats?.automationLevel
          )

          ActivityOutputView(
            activity: viewModel.projectActivity,
            top3NetCodeLines: viewModel.top3NetCodeLines,
            top3InputTokens: viewModel.top3InputTokens,
            top3MessageCount: viewModel.top3MessageCount,
            top3Duration: viewModel.top3Duration,
            top3Cost: viewModel.top3Cost
          )

          ModelAgentView(modelAgentStats: viewModel.projectModelAgentStats)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 20)
    }
  }
  
  private var projectsContent: some View {
    Group {
      if viewModel.projectStats.isEmpty {
        emptyView
      } else {
        projectsGrid
      }
    }
  }
  
  private var projectsGrid: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        ForEach(viewModel.projectStats) { stat in
          projectCard(stat)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .frame(height: 240)
    .layoutPriority(1)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
    )
  }
  
  private func projectCard(_ stat: ProjectsViewModel.ProjectStats) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      projectNameSection(stat)
      statsSection(stat)
      costSection(stat)
    }
    .padding(12)
    .background(
      viewModel.selectedProject?.id == stat.id
        ? Color.accentColor.opacity(0.1)
        : Color(NSColor.controlBackgroundColor)
    )
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(
          viewModel.selectedProject?.id == stat.id
            ? Color.accentColor
            : Color.secondary.opacity(0.2),
          lineWidth: viewModel.selectedProject?.id == stat.id ? 2 : 1
        )
    )
    .onTapGesture {
      viewModel.selectProject(stat)
    }
  }
  
  private func projectNameSection(_ stat: ProjectsViewModel.ProjectStats) -> some View {
    HStack(spacing: 6) {
      Text(URL(fileURLWithPath: stat.projectRoot).lastPathComponent)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .lineLimit(1)
    }
  }
  
  private func directorySection(_ stat: ProjectsViewModel.ProjectStats) -> some View {
    Text(stat.projectRoot)
      .font(.system(.caption, design: .default))
      .foregroundColor(.secondary)
      .lineLimit(1)
  }
  
  private func statsSection(_ stat: ProjectsViewModel.ProjectStats) -> some View {
    HStack(spacing: 16) {
      HStack(spacing: 4) {
        Image(systemName: "cpu")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.blue)
        Text("\(L10n.projectTokens): \(formatCompact(stat.tokens))")
          .font(.system(size: 13, design: .rounded))
      }
      
      Spacer()
    }
  }
  
  private func costSection(_ stat: ProjectsViewModel.ProjectStats) -> some View {
    HStack {
      HStack(spacing: 4) {
        Image(systemName: "dollarsign.circle")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.green)
        let costText = String(format: "%.2f", stat.cost)
        Text("\(L10n.projectCost): $\(costText)")
          .font(.system(size: 13, design: .rounded))
      }
      
      Spacer()
      
      HStack(spacing: 4) {
        Image(systemName: "calendar.badge.exclamationmark")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.orange)
        Text("\(L10n.projectLastActive)\(formatLastActive(stat.lastActiveAt))")
          .font(.system(size: 13, design: .rounded))
          .foregroundColor(.secondary)
      }
    }
  }
  
  private var emptyView: some View {
    VStack(spacing: 20) {
      Image(systemName: "folder")
        .font(.system(size: 48))
        .foregroundColor(.secondary)
      Text(L10n.projectNoProjectData)
        .font(.headline)
      Text(L10n.projectImportDataHint)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(20)
  }
  
  private func formatCompact(_ value: Int) -> String {
    if value >= 1_000_000 {
      return String(format: "%.1fM", Double(value) / 1_000_000)
    } else if value >= 1_000 {
      return String(format: "%.1fK", Double(value) / 1_000)
    } else {
      return String(value)
    }
  }
  
  private func formatLastActive(_ date: Date?) -> String {
    guard let date = date else { return L10n.projectUnknown }
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current

    if LocalizationManager.shared.currentLanguage == "zh_CN" {
      formatter.dateFormat = "yyyy年M月d日 HH:mm"
    } else {
      formatter.dateFormat = "MMM d, yyyy HH:mm"
    }

    return formatter.string(from: date)
  }
}

private func projectStatRow(stat: ProjectsViewModel.ProjectStats) -> some View {
  VStack(alignment: .leading, spacing: 8) {
    HStack {
      VStack(alignment: .leading) {
        Text(stat.projectRoot)
          .font(.headline)
        Text("\(stat.activeDays) \(L10n.projectActiveDaysShort)")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      Spacer()
      Text(formatCost(stat.cost))
        .font(.title3)
        .fontWeight(.bold)
    }
    
    HStack {
      Label("\(stat.sessionCount) sessions", systemImage: "doc.text")
      Label("\(stat.messageCount) messages", systemImage: "bubble.left")
      Label("\(stat.tokens) tokens", systemImage: "cpu")
    }
    .font(.caption)
    .foregroundColor(.secondary)
  }
  .padding(.vertical, 10)
}

// MARK: - Activity Output View

public struct ActivityOutputView: View {
  let activity: StatisticsRepository.ProjectActivityStats?
  let top3NetCodeLines: [StatisticsRepository.DailyTop3Stat]
  let top3InputTokens: [StatisticsRepository.DailyTop3Stat]
  let top3MessageCount: [StatisticsRepository.DailyTop3Stat]
  let top3Duration: [StatisticsRepository.DailyTop3Stat]
  let top3Cost: [StatisticsRepository.DailyTop3Stat]

  public init(
    activity: StatisticsRepository.ProjectActivityStats?,
    top3NetCodeLines: [StatisticsRepository.DailyTop3Stat] = [],
    top3InputTokens: [StatisticsRepository.DailyTop3Stat] = [],
    top3MessageCount: [StatisticsRepository.DailyTop3Stat] = [],
    top3Duration: [StatisticsRepository.DailyTop3Stat] = [],
    top3Cost: [StatisticsRepository.DailyTop3Stat] = []
  ) {
    self.activity = activity
    self.top3NetCodeLines = top3NetCodeLines
    self.top3InputTokens = top3InputTokens
    self.top3MessageCount = top3MessageCount
    self.top3Duration = top3Duration
    self.top3Cost = top3Cost
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(L10n.projectActivityOutput)
          .font(.headline)
        Spacer()
      }

      GeometryReader { geometry in
        HStack(spacing: 16) {
          netCodeLinesCard
            .frame(width: (geometry.size.width - 16) * 0.2)
          activeDaysCard
            .frame(width: (geometry.size.width - 16) * 0.8)
        }
      }
      .frame(height: 120)

      Top3MetricsView(
        top3NetCodeLines: top3NetCodeLines,
        top3InputTokens: top3InputTokens,
        top3MessageCount: top3MessageCount,
        top3Duration: top3Duration,
        top3Cost: top3Cost
      )
    }
  }

  private var netCodeLinesCard: some View {
    VStack(alignment: .center, spacing: 8) {
      let netLines = activity?.netCodeLines ?? 0

      if netLines > 0 {
        Text(formatNumber(netLines))
          .font(.system(size: 24, weight: .regular, design: .rounded))
      } else if netLines == 0 {
        Text("0")
          .font(.system(size: 24, weight: .regular, design: .rounded))
      } else {
        Text("-\(formatNumber(-netLines))")
          .font(.system(size: 24, weight: .regular, design: .rounded))
          .foregroundColor(.red)
      }

      Text(L10n.projectNetCodeLines)
        .font(.system(.caption, design: .rounded))
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

  private var activeDaysCard: some View {
    let activeDays = activity?.activeDays ?? 0
    let totalDurationMs = activity?.totalDurationMs ?? 0

    let totalDaysSpan: Int = {
      guard let first = activity?.firstActiveAt,
            let last = activity?.lastActiveAt else { return 0 }
      let calendar = Calendar.current
      let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: last))
      return (components.day ?? 0) + 1
    }()

    return VStack(spacing: 12) {
      HStack {
        Text(L10n.projectActiveDays)
          .font(.headline)
        Spacer()
        HStack(spacing: 4) {
          Image(systemName: "info.circle")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
          Text(L10n.projectActiveDaysDesc)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
      }

      GeometryReader { geometry in
        let availableWidth = geometry.size.width
        let chartPadding: CGFloat = 10
        let chartWidth = availableWidth - chartPadding * 2
        let barHeight: CGFloat = 10

        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: chartWidth, height: barHeight)
            .position(x: chartPadding + chartWidth / 2, y: 16)

          if activeDays > 0 && totalDaysSpan > 0 {
            let progressRatio = min(CGFloat(activeDays) / CGFloat(totalDaysSpan), 1.0)
            let progressWidth = chartWidth * progressRatio
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.blue.opacity(0.8))
              .frame(width: progressWidth, height: barHeight)
              .position(x: chartPadding + progressWidth / 2, y: 16)
          }
        }
      }
      .frame(height: 32)

      HStack(spacing: 16) {
        HStack(spacing: 4) {
          Image(systemName: "calendar")
            .font(.system(size: 11))
            .foregroundColor(.blue.opacity(0.9))
          if activeDays > 0 && totalDaysSpan > 0 {
            let percentage = Int(Double(activeDays) / Double(totalDaysSpan) * 100)
          Text("\(activeDays)(\(percentage)%)")
            .font(.system(size: 11))
            .foregroundColor(.blue.opacity(0.9))
          } else {
            Text("-")
              .font(.system(size: 11))
              .foregroundColor(.blue.opacity(0.9))
          }
          Text(L10n.projectDay)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }

        HStack(spacing: 4) {
          Image(systemName: "clock")
            .font(.system(size: 11))
            .foregroundColor(.green.opacity(0.9))
          Text(activeDays > 0 ? formatDurationToMinutes(totalDurationMs) : "-")
            .font(.system(size: 11))
            .foregroundColor(.green.opacity(0.9))
          Text(L10n.projectTotalDuration)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .opacity(activeDays > 0 ? 1.0 : 0.5)
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

  private func formatDurationShort(_ durationMs: Int64) -> String {
    let seconds = durationMs / 1000
    let minutes = seconds / 60
    let hours = minutes / 60
    let days = hours / 24

    if days > 0 {
      return "\(days)天\(hours % 24)小时"
    } else if hours > 0 {
      return "\(hours)小时\(minutes % 60)分钟"
    } else if minutes > 0 {
      return "\(minutes)分钟"
    } else {
      return "\(seconds)秒"
    }
  }

  private func formatDurationToMinutes(_ durationMs: Int64) -> String {
    let totalMinutes = durationMs / 1000 / 60
    let days = totalMinutes / 60 / 24
    let hours = (totalMinutes / 60) % 24
    let minutes = totalMinutes % 60

    var parts: [String] = []
    if days > 0 { parts.append("\(days) \(L10n.projectDays)") }
    if hours > 0 { parts.append("\(hours) \(L10n.projectHours)") }
    if minutes > 0 || parts.isEmpty { parts.append("\(minutes) \(L10n.projectMinutes)") }

    return LocalizationManager.shared.currentLanguage == "zh_CN"
      ? parts.joined()
      : parts.map { $0 }.joined(separator: " ")
  }

  private func formatNumber(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: value)) ?? String(value)
  }

  private func formatDuration(_ durationMs: Int64) -> String {
    let seconds = durationMs / 1000
    let minutes = seconds / 60
    let hours = minutes / 60
    let days = hours / 24

    let remainingHours = hours % 24
    let remainingMinutes = minutes % 60
    let remainingSeconds = seconds % 60

    var parts: [String] = []
    if days > 0 { parts.append("\(days)天") }
    if remainingHours > 0 { parts.append("\(remainingHours)小时") }
    if remainingMinutes > 0 { parts.append("\(remainingMinutes)分钟") }
    if remainingSeconds > 0 || parts.isEmpty { parts.append("\(remainingSeconds)秒") }

    return parts.joined(separator: "")
  }
}
