import SwiftUI
import Combine

public struct SettingsView: View {
  @ObservedObject private var settingsViewModel = SettingsViewModel.shared
  @ObservedObject private var localizationManager = LocalizationManager.shared
  @State private var settingsRestoreCandidate: BackupInfo?

  private static let settingsDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
  }()

  private static func settingsFormatFileSize(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var size = Double(bytes)
    var unitIndex = 0

    while size >= 1024 && unitIndex < units.count - 1 {
      size /= 1024
      unitIndex += 1
    }

    return String(format: "%.1f %@", size, units[unitIndex])
  }

  public init() {}

  private var settingsTabPicker: some View {
    HStack {
      Spacer()
       Picker("", selection: $settingsViewModel.selectedSectionTab) {
         ForEach(SettingsViewModel.SettingsSectionTab.allCases, id: \.self) { tab in
           Text(tab.displayName(localizationManager: localizationManager)).tag(tab)
         }
       }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: 420)
      Spacer()
    }
  }

  private func settingsGroupView(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 8) {
          Image(systemName: icon)
            .font(.headline)
            .foregroundStyle(DesignTokens.Colors.settingsSectionIcon)
          Text(title)
            .font(.headline)
            .foregroundColor(.primary)
          Spacer()
        }

        content()
      }
      .padding(16)
    }
    .cornerRadius(16)
    .padding(.horizontal, 16)
  }

  private var settingsSyncStrategySliderRange: ClosedRange<Double> {
    0...Double(max(0, SyncStrategy.sliderOptions.count - 1))
  }

  private var settingsSyncStrategySliderValue: Binding<Double> {
    Binding(
      get: {
        Double(SyncStrategy.index(for: settingsViewModel.syncStrategy))
      },
      set: { newValue in
        let index = Int(newValue.rounded())
        settingsViewModel.syncStrategy = SyncStrategy.strategy(for: index)
      }
    )
  }

  private var settingsSyncSectionContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        Text(L10n.settingsDataSource)
          .font(.subheadline)

        TextField(L10n.settingsDataSourcePath, text: $settingsViewModel.dataSourcePath)
          .textFieldStyle(.roundedBorder)
          .help(L10n.settingsDataSourceHelp)

        HStack(spacing: 10) {
          Button(L10n.settingsChoosePath) {
            settingsViewModel.chooseDataSourcePath()
          }
          .help(L10n.settingsChoosePathHelp)

          Button(L10n.settingsRestoreDefault) {
            settingsViewModel.useDefaultDataSourcePath()
          }
          .help(L10n.settingsRestoreDefaultHelp)
        }

        Text("\(L10n.settingsDefaultSource)\(ConfigService.shared.defaultImportPath)")
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text(L10n.settingsSyncStrategy)
          .font(.subheadline)
        
        Picker(L10n.settingsSyncStrategy, selection: $settingsViewModel.syncStrategy) {
          ForEach(SyncStrategy.allCases, id: \.self) { strategy in
            Text(strategy.displayName).tag(strategy)
          }
        }
        .pickerStyle(.segmented)
        .help(L10n.settingsSyncStrategyHelp)
        
        Text(settingsViewModel.syncStrategy.detailDescription)
          .font(.caption2)
          .foregroundColor(.secondary)
          .padding(.top, 4)
      }
    }
    .padding(.bottom, 8)
  }

  private var settingsBackupSectionContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Toggle(L10n.settingsEnableBackup, isOn: $settingsViewModel.backupEnabled)
          .toggleStyle(.switch)
          .help(L10n.settingsEnableBackupHelp)
        Text(L10n.settingsBackupDescription)
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      if settingsViewModel.backupEnabled {
        VStack(alignment: .leading, spacing: 4) {
          Stepper("\(L10n.settingsBackupRetention): \(settingsViewModel.backupRetentionCount)",
                  value: $settingsViewModel.backupRetentionCount,
                  in: 1...10)
          Text(L10n.settingsBackupRetentionHelp)
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 4) {
          Picker(L10n.settingsBackupInterval, selection: $settingsViewModel.backupIntervalHours) {
            Text(L10n.settingsBackupInterval6h).tag(6)
            Text(L10n.settingsBackupInterval12h).tag(12)
            Text(L10n.settingsBackupInterval24h).tag(24)
            Text(L10n.settingsBackupInterval48h).tag(48)
          }
          .pickerStyle(.segmented)
          Text(L10n.settingsBackupIntervalHelp)
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        Button {
          Task { await settingsViewModel.performBackupNow() }
        } label: {
          Label(L10n.settingsBackupNow, systemImage: "archivebox")
        }
        Text(L10n.settingsBackupNowHelp)
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      if settingsViewModel.availableBackups.count > 0 {
        VStack(alignment: .leading, spacing: 8) {
          Text(L10n.settingsBackupList)
            .font(.headline)
            .foregroundColor(.primary)

          ForEach(settingsViewModel.availableBackups) { backup in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(backup.fileURL.lastPathComponent)
                  .font(.caption2)
                  .foregroundColor(.secondary)
                Text(backup.kind.displayName)
                  .font(.caption2)
                  .foregroundColor(.secondary)
                Text("\(L10n.settingsBackupCreatedAt) \(Self.settingsDateFormatter.string(from: backup.createdAt))")
                  .font(.caption)
                  .foregroundColor(.secondary)
                Text("\(L10n.settingsBackupSize) \(Self.settingsFormatFileSize(backup.fileSize))")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }

              Spacer()

              HStack(spacing: 12) {
                Button {
                  settingsRestoreCandidate = backup
                } label: {
                  Image(systemName: "arrow.uturn.backward")
                    .foregroundColor(.accentColor)
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .help(L10n.settingsRestoreBackup)

                Button {
                  Task { await settingsViewModel.deleteBackup(backup) }
                } label: {
                  Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .help(L10n.settingsDeleteBackup)
              }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(6)
          }
        }
        .padding(.vertical, 8)
      }
    }
    .padding(.bottom, 8)
  }

  private var settingsAppearanceSectionContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      Picker(localizationManager.localizedString("settings.theme"), selection: $settingsViewModel.theme) {
        ForEach(SettingsViewModel.AppTheme.allCases, id: \.self) { theme in
          Text(theme.displayName).tag(theme)
        }
      }
      .pickerStyle(.segmented)
      .help(L10n.settingsThemeHelp)
      Text(L10n.settingsThemeHelp)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding(.bottom, 8)
  }

  private var settingsLanguageSectionContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      Picker(localizationManager.localizedString("settings.languages"), selection: $settingsViewModel.selectedLanguage) {
        ForEach(SettingsViewModel.Language.allCases, id: \.self) { language in
          Text(language.displayName).tag(language.code)
        }
      }
      .pickerStyle(.menu)

      Text(L10n.settingsLanguageRestartHint)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding(.bottom, 8)
  }

  private var settingsLogSectionContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        if SettingsViewModel.LogLevel.allCases.count <= 4 {
          Picker(L10n.settingsLogLevel, selection: $settingsViewModel.logLevel) {
            ForEach(SettingsViewModel.LogLevel.allCases, id: \.self) { level in
              Text(level.displayName).tag(level)
            }
          }
          .pickerStyle(.segmented)
          .help(L10n.settingsLogLevel)
        } else {
          Picker(L10n.settingsLogLevel, selection: $settingsViewModel.logLevel) {
            ForEach(SettingsViewModel.LogLevel.allCases, id: \.self) { level in
              Text(level.displayName).tag(level)
            }
          }
          .pickerStyle(.radioGroup)
          .help(L10n.settingsLogLevel)
        }
        Text(L10n.settingsLogLevelDesc)
          .font(.caption2)
          .foregroundColor(.secondary)
      }
    }
    .padding(.bottom, 8)
  }

  private var settingsAboutSection: some View {
    HStack {
      Spacer()
      VStack(alignment: .center, spacing: 24) {
        if let appIcon = aboutAppIcon {
          Image(nsImage: appIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 128, height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        
        Text(AppConfiguration.App.name)
          .font(.system(size: 28, weight: .bold))

        Text(L10n.aboutVersion + " " + AppConfiguration.App.version)
          .font(.system(size: 13))
          .foregroundColor(Color.secondary.opacity(0.6))

        Text(L10n.aboutDescription)
          .font(.body)
          .foregroundColor(Color.secondary.opacity(0.85))
          .multilineTextAlignment(.center)
          .frame(maxWidth: 400)
        
        Divider()
          .frame(maxWidth: 400)
        
        HStack(spacing: 12) {
          Button {
            AppConfiguration.Support.openGitHub()
          } label: {
            Label(L10n.aboutGitHub, systemImage: "link")
              .font(.callout)
          }
          .buttonStyle(.link)

          Text("|")
            .foregroundColor(.secondary)

          Button {
            AppConfiguration.Support.openTwitter()
          } label: {
            Label(L10n.aboutTwitter, systemImage: "at")
              .font(.callout)
          }
          .buttonStyle(.link)
        }
        
        Text(AppConfiguration.Developer.copyright)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(32)
      .frame(maxWidth: 500)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(NSColor.controlBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
      )
      Spacer()
    }
    .padding(.horizontal, 16)
  }
  
  private var aboutAppIcon: NSImage? {
    Bundle.module.url(forResource: "VibeWave", withExtension: "icns")
      .flatMap { NSImage(contentsOf: $0) }
  }
  
  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        if let status = settingsViewModel.operationStatus {
          HStack(spacing: 8) {
            Image(systemName: settingsStatusImage(status))
              .foregroundColor(settingsStatusColor(status))
            Text(settingsStatusMessage(status))
              .font(.caption)
              .foregroundColor(settingsStatusColor(status))
            Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(settingsStatusBackgroundColor(status))
          .cornerRadius(8)
          .transition(.opacity.combined(with: .move(edge: .top)))
          .padding(.bottom, 16)
        }

        settingsTabPicker
          .padding(.bottom, 16)

        switch settingsViewModel.selectedSectionTab {
        case .general:
          settingsGroupView(title: localizationManager.localizedString("settings.appearance"), icon: "paintbrush") {
            settingsAppearanceSectionContent
          }
          .padding(.bottom, 20)

          settingsGroupView(title: localizationManager.localizedString("settings.languages"), icon: "globe") {
            settingsLanguageSectionContent
          }
          .padding(.bottom, 20)

          settingsGroupView(title: localizationManager.localizedString("settings.log"), icon: "terminal") {
            settingsLogSectionContent
          }
        case .data:
          settingsGroupView(title: localizationManager.localizedString("settings.group.dataSync"), icon: "arrow.clockwise") {
            settingsSyncSectionContent
          }
          .padding(.bottom, 20)

          settingsGroupView(title: localizationManager.localizedString("settings.group.backupRestore"), icon: "archivebox") {
            settingsBackupSectionContent
          }
        case .about:
          settingsAboutSection
        }

        Spacer()
      }
      .frame(maxWidth: 700)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding()
    }
    .navigationTitle(L10n.navSettings)
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Text(L10n.appName)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.primary)
      }
    }
    .animation(.default, value: settingsViewModel.operationStatus)
    .animation(.default, value: settingsViewModel.backupEnabled)
    .onReceive(NotificationCenter.default.publisher(for: .showSettingsAbout)) { _ in
      settingsViewModel.selectedSectionTab = .about
    }
    .alert(
      L10n.settingsConfirmRestore,
      isPresented: Binding(
        get: { settingsRestoreCandidate != nil },
        set: { newValue in
          if !newValue { settingsRestoreCandidate = nil }
        }
      ),
      presenting: settingsRestoreCandidate
    ) { backup in
      Button(L10n.commonCancel, role: .cancel) { }
      Button(L10n.settingsRestoreBackup, role: .destructive) {
        Task { await settingsViewModel.restoreBackup(backup) }
      }
    } message: { backup in
      Text("\(L10n.settingsRestoreWarning)\n\(L10n.settingsBackupList)：\(backup.fileURL.lastPathComponent) · \(backup.kind.displayName) · \(Self.settingsDateFormatter.string(from: backup.createdAt))")
    }
  }

  private func settingsStatusImage(_ status: OperationStatus) -> String {
    switch status {
    case .success:
      return "checkmark.circle"
    case .failure:
      return "exclamationmark.triangle"
    }
  }

  private func settingsStatusColor(_ status: OperationStatus) -> Color {
    switch status {
    case .success:
      return .green
    case .failure:
      return .red
    }
  }

  private func settingsStatusMessage(_ status: OperationStatus) -> String {
    switch status {
    case .success(let message):
      return message
    case .failure(let message):
      return message
    }
  }

  private func settingsStatusBackgroundColor(_ status: OperationStatus) -> Color {
    switch status {
    case .success:
      return Color.green.opacity(0.1)
    case .failure:
      return Color.red.opacity(0.1)
    }
  }
}
