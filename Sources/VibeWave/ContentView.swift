import SwiftUI

public struct ContentView: View {
  @State private var selectedTab: AppTab = .usage
  @StateObject private var historyViewModel: HistoryViewModel
  @StateObject private var insightsViewModel: InsightsViewModel
  @StateObject private var projectsViewModel: ProjectsViewModel
  @ObservedObject private var localizationManager = LocalizationManager.shared
  
  public enum AppTab: String, CaseIterable, Identifiable {
    case usage
    case projects
    case insights
    case history
    case settings
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .usage: return L10n.navOverview
        case .history: return L10n.navHistory
        case .insights: return L10n.navInsights
        case .projects: return L10n.navProjects
        case .settings: return L10n.navSettings
        }
    }
  }

  public static let textSelectionEnabled = false
  
  public init() {
    let dbPool = DatabaseRepository.shared.dbPool()
    _historyViewModel = StateObject(wrappedValue: HistoryViewModel(dbPool: dbPool))
    _insightsViewModel = StateObject(wrappedValue: InsightsViewModel(dbPool: dbPool))
    _projectsViewModel = StateObject(wrappedValue: ProjectsViewModel(dbPool: dbPool))
  }
  
  private var tabContent: some View {
    TabView(selection: $selectedTab) {
      OverviewView(viewModel: OverviewViewModel.shared)
        .tabItem {
          Label(L10n.navOverview, systemImage: "chart.bar.fill")
        }
        .tag(AppTab.usage)
        .keyboardShortcut("1", modifiers: .command)
      
      ProjectsView(viewModel: projectsViewModel)
        .tabItem {
          Label(L10n.navProjects, systemImage: "folder.fill")
        }
        .tag(AppTab.projects)
        .keyboardShortcut("2", modifiers: .command)

      InsightsView(viewModel: insightsViewModel)
        .tabItem {
          Label(L10n.navInsights, systemImage: "sparkles")
        }
        .tag(AppTab.insights)
        .keyboardShortcut("3", modifiers: .command)
      
      HistoryView(viewModel: historyViewModel)
        .tabItem {
          Label(L10n.navHistory, systemImage: "clock.arrow.circlepath")
        }
        .tag(AppTab.history)
        .keyboardShortcut("4", modifiers: .command)
      
      SettingsView()
        .tabItem {
          Label(L10n.navSettings, systemImage: "gearshape.fill")
        }
        .tag(AppTab.settings)
        .keyboardShortcut("5", modifiers: .command)
    }
  }

  public var body: some View {
    Group {
      if Self.textSelectionEnabled {
        tabContent.textSelection(.enabled)
      } else {
        tabContent.textSelection(.disabled)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .showSettingsAbout)) { _ in
      selectedTab = .settings
    }
  }
}
