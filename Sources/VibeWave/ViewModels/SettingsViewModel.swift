import Foundation
import GRDB
import Combine
import SwiftUI
import AppKit

// 操作状态枚举
public enum OperationStatus: Equatable {
  case success(String)
  case failure(String)
}

public final class SettingsViewModel: ObservableObject {
  public static let shared = SettingsViewModel()
  
  @Published public var dataSourcePath: String = ConfigService.shared.importPath
  @Published public var syncStrategy: SyncStrategy = .auto
  @Published public var theme: AppTheme = .system {
    didSet { updateAppAppearance() }
  }
  @Published public var selectedLanguage: String = "en" {
    didSet {
      LocalizationManager.shared.setLanguage(selectedLanguage)
    }
  }
  @Published public var selectedSectionTab: SettingsViewModel.SettingsSectionTab = .general
  @Published public var logLevel: LogLevel = .debug
  @Published public var backupEnabled: Bool = true
  @Published public var backupRetentionCount: Int = 5
  @Published public var backupIntervalHours: Int = 24
  @Published public var availableBackups: [BackupInfo] = []
  @Published public var operationStatus: OperationStatus?

  private let userDefaults: UserDefaults
  private let notificationCenter: NotificationCenter
  private var backupManager: BackupManager?
  private var autoSaveCancellables = Set<AnyCancellable>()
  
  public enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
  }
  
  public enum Language: String, CaseIterable {
    case en = "en"
    case zh_CN = "zh_CN"

    var displayName: String {
      switch self {
      case .en:
        return LocalizationManager.shared.localizedString("lang.en")
      case .zh_CN:
        return LocalizationManager.shared.localizedString("lang.zh_CN")
      }
    }

    var code: String {
      self.rawValue
    }
  }

  public enum SettingsSectionTab: String, CaseIterable {
    case general
    case data
    case about

    func displayName(localizationManager: LocalizationManager) -> String {
      switch self {
      case .general: return localizationManager.localizedString("settings.general")
      case .data: return localizationManager.localizedString("settings.data")
      case .about: return localizationManager.localizedString("about.tab")
      }
    }
  }

  public typealias LogLevel = AppLogLevel

  public init() {
    self.userDefaults = UserDefaults.standard
    self.notificationCenter = .default
    
    // Load saved settings
    self.dataSourcePath = ConfigService.shared.importPath
    self.syncStrategy = SyncStrategy.load(from: userDefaults)
    
    if let themeRaw = userDefaults.string(forKey: "theme"),
       let theme = AppTheme(rawValue: themeRaw) {
      self.theme = theme
    }

    if let logLevelRaw = userDefaults.string(forKey: "log.level"),
       let logLevel = LogLevel(rawValue: logLevelRaw) {
      self.logLevel = logLevel
    }
    
    // Load language from LocalizationManager
    self.selectedLanguage = LocalizationManager.shared.currentLanguage

    backupEnabled = userDefaults.object(forKey: "backup.enabled") != nil ? userDefaults.bool(forKey: "backup.enabled") : true
    backupRetentionCount = userDefaults.object(forKey: "backup.maxCount") != nil ? userDefaults.integer(forKey: "backup.maxCount") : 5
    backupIntervalHours = userDefaults.object(forKey: "backup.interval") != nil ? userDefaults.integer(forKey: "backup.interval") : 24

    let backupDirectory = AppPaths.backupsDirectory
    let legacyBackupDirectory = AppPaths.legacyBackupsDirectory
    try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: legacyBackupDirectory, withIntermediateDirectories: true)
    backupManager = BackupManager(
      backupDirectory: backupDirectory,
      additionalSearchDirectories: [legacyBackupDirectory]
    )

    Task {
      await loadAvailableBackups()
    }

    notificationCenter.publisher(for: .backupDidUpdate)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        guard let self = self else { return }
        Task { await self.loadAvailableBackups() }
      }
      .store(in: &autoSaveCancellables)

    configureAutoSave()
    updateAppAppearance()
  }

  internal init(
    userDefaults: UserDefaults,
    backupManager: BackupManager?,
    loadBackups: Bool,
    notificationCenter: NotificationCenter = .default
  ) {
    self.userDefaults = userDefaults
    self.notificationCenter = notificationCenter

    self.dataSourcePath = ConfigService.shared.importPath
    self.syncStrategy = SyncStrategy.load(from: userDefaults)

    if let themeRaw = userDefaults.string(forKey: "theme"),
       let theme = AppTheme(rawValue: themeRaw) {
      self.theme = theme
    }

    if let logLevelRaw = userDefaults.string(forKey: "log.level"),
       let logLevel = LogLevel(rawValue: logLevelRaw) {
      self.logLevel = logLevel
    }

    backupEnabled = userDefaults.object(forKey: "backup.enabled") != nil ? userDefaults.bool(forKey: "backup.enabled") : true
    backupRetentionCount = userDefaults.object(forKey: "backup.maxCount") != nil ? userDefaults.integer(forKey: "backup.maxCount") : 5
    backupIntervalHours = userDefaults.object(forKey: "backup.interval") != nil ? userDefaults.integer(forKey: "backup.interval") : 24

    self.backupManager = backupManager

    if loadBackups {
      Task {
        await loadAvailableBackups()
      }
    }

    notificationCenter.publisher(for: .backupDidUpdate)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        guard let self = self else { return }
        Task { await self.loadAvailableBackups() }
      }
      .store(in: &autoSaveCancellables)

    configureAutoSave()
    updateAppAppearance()
  }

  private func configureAutoSave() {
    let triggers: [AnyPublisher<Void, Never>] = [
      $syncStrategy.dropFirst().map { _ in () }.eraseToAnyPublisher(),
      $dataSourcePath.dropFirst().map { _ in () }.eraseToAnyPublisher(),
      $theme.dropFirst().map { _ in () }.eraseToAnyPublisher(),
      $logLevel.dropFirst().map { _ in () }.eraseToAnyPublisher(),
      $backupEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
      $backupRetentionCount.dropFirst().map { _ in () }.eraseToAnyPublisher(),
      $backupIntervalHours.dropFirst().map { _ in () }.eraseToAnyPublisher()
    ]

    Publishers.MergeMany(triggers)
      .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
      .sink { [weak self] in
        self?.saveSettings()
      }
      .store(in: &autoSaveCancellables)
  }
  
  public func saveSettings() {
    let previousDataSourcePath = ConfigService.shared.importPath
    let normalizedPath = normalizeDataSourcePath(dataSourcePath)
    dataSourcePath = normalizedPath
    ConfigService.shared.importPath = normalizedPath
    ConfigService.shared.isDataSourceConfirmed = true
    userDefaults.set(syncStrategy.rawValue, forKey: "sync.strategy")
    userDefaults.set(theme.rawValue, forKey: "theme")
    userDefaults.set(logLevel.rawValue, forKey: "log.level")
    userDefaults.set(backupEnabled, forKey: "backup.enabled")
    userDefaults.set(backupRetentionCount, forKey: "backup.maxCount")
    userDefaults.set(backupIntervalHours, forKey: "backup.interval")
    userDefaults.synchronize()
    notificationCenter.post(
      name: .syncSettingsDidChange,
      object: nil,
      userInfo: ["syncStrategy": syncStrategy.rawValue]
    )
    if previousDataSourcePath != normalizedPath {
      notificationCenter.post(
        name: .dataSourceDidChange,
        object: nil,
        userInfo: ["path": normalizedPath]
      )
    }
    notificationCenter.post(
      name: .backupSettingsDidChange,
      object: nil,
      userInfo: [
        "backupEnabled": backupEnabled,
        "backupRetentionCount": backupRetentionCount,
        "backupIntervalHours": backupIntervalHours
      ]
    )
  }
  
  public func updateAppAppearance() {
    // Ensure we're on main thread and NSApp is available
    guard Thread.isMainThread, let app = NSApp else {
      DispatchQueue.main.async { [weak self] in
        self?.updateAppAppearance()
      }
      return
    }
    
    let newAppearance: NSAppearance?
    switch theme {
    case .system:
      app.appearance = nil
      newAppearance = nil
    case .light:
      app.appearance = NSAppearance(named: .aqua)
      newAppearance = NSAppearance(named: .aqua)
    case .dark:
      app.appearance = NSAppearance(named: .darkAqua)
      newAppearance = NSAppearance(named: .darkAqua)
    }
    
    for window in app.windows {
      window.appearance = newAppearance
    }
  }
  
  public   func resetToDefaults() {
    dataSourcePath = ConfigService.shared.defaultImportPath
    syncStrategy = .auto
    theme = .system
    logLevel = .debug
    backupEnabled = true
    backupRetentionCount = 5
    backupIntervalHours = 24
    saveSettings()
  }

  public func chooseDataSourcePath() {
    if let selected = ConfigService.shared.selectDataSourcePathInteractively(initialPath: dataSourcePath) {
      dataSourcePath = selected
      saveSettings()
    }
  }

  public func useDefaultDataSourcePath() {
    dataSourcePath = ConfigService.shared.defaultImportPath
    saveSettings()
  }

  public func refreshDataSourcePathFromConfig() {
    let latestPath = ConfigService.shared.importPath
    guard dataSourcePath != latestPath else { return }
    dataSourcePath = latestPath
  }

  private func normalizeDataSourcePath(_ input: String) -> String {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return ConfigService.shared.defaultImportPath
    }
    if let resolved = ConfigService.shared.resolveDatabasePath(from: URL(fileURLWithPath: trimmed)) {
      return resolved
    }
    return trimmed
  }

  public func performBackupNow() async {
    guard let backupManager = backupManager else {
      operationStatus = .failure(LocalizationManager.shared.localizedString("settings.backupNotInitialized"))
      return
    }

    do {
      _ = try await backupManager.createBackup(from: DatabaseRepository.shared.dbPool(), kind: .manual)
      await loadAvailableBackups()
      
      operationStatus = .success(LocalizationManager.shared.localizedString("settings.backupSuccess"))
      
      // 3秒后自动清除状态
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        self.operationStatus = nil
      }
    } catch {
      let errorMsg = LocalizationManager.shared.localizedString("settings.backupFailed")
      operationStatus = .failure("\(errorMsg)\(error.localizedDescription)")
      
      // 5秒后自动清除状态
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        self.operationStatus = nil
      }
    }
  }

  public func restoreBackup(_ backup: BackupInfo) async {
    guard let backupManager = backupManager else {
      operationStatus = .failure(LocalizationManager.shared.localizedString("settings.backupNotInitialized"))
      return
    }

    do {
      try await backupManager.restoreBackup(backup, to: DatabaseRepository.shared.dbPool())
      NotificationCenter.default.post(name: .appDataDidUpdate, object: nil)
      operationStatus = .success(LocalizationManager.shared.localizedString("settings.restoreSuccess"))
      
      // 3秒后自动清除状态
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        self.operationStatus = nil
      }
    } catch {
      let errorMsg = LocalizationManager.shared.localizedString("settings.restoreFailed")
      operationStatus = .failure("\(errorMsg)\(error.localizedDescription)")
      
      // 5秒后自动清除状态
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        self.operationStatus = nil
      }
    }
  }

  public func loadAvailableBackups() async {
    guard let backupManager = backupManager else {
      availableBackups = []
      return
    }

    do {
      availableBackups = try await backupManager.listBackups()
    } catch {
      availableBackups = []
    }
  }

  public func deleteBackup(_ backup: BackupInfo) async {
    guard let backupManager = backupManager else {
      operationStatus = .failure(LocalizationManager.shared.localizedString("settings.backupNotInitialized"))
      return
    }

    do {
      try await backupManager.deleteBackup(backup)
      await loadAvailableBackups()
      operationStatus = .success(LocalizationManager.shared.localizedString("settings.deleteSuccess"))
      
      // 3秒后自动清除状态
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        self.operationStatus = nil
      }
    } catch {
      let errorMsg = LocalizationManager.shared.localizedString("settings.deleteFailed")
      operationStatus = .failure("\(errorMsg)\(error.localizedDescription)")
      
      // 5秒后自动清除状态
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        self.operationStatus = nil
      }
    }
  }
}

// MARK: - AppTheme Extensions

extension SettingsViewModel.AppTheme {
  public var displayName: String {
    switch self {
    case .system: return L10n.settingsThemeSystem
    case .light: return L10n.settingsThemeLight
    case .dark: return L10n.settingsThemeDark
    }
  }
  
  /// SF Symbol图标名称
  public var icon: String {
    switch self {
    case .system: return "circle.lefthalf.filled"
    case .light: return "sun.max"
    case .dark: return "moon"
    }
  }
  
  /// 转换为 SwiftUI ColorScheme，system 返回 nil 表示跟随系统
  public var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
  
  // MARK: - Appearance Management
}

// MARK: - Convenience Methods

extension SettingsViewModel {
  /// 更新备份保留数量并自动保存
  public func updateBackupRetention(_ count: Int) {
    // 限制在1-10之间
    backupRetentionCount = max(1, min(count, 10))
    saveSettings()
  }
  
  /// 更新备份间隔并自动保存
  public func updateBackupInterval(_ hours: Int) {
    // 只允许预设的值: 6, 12, 24, 48小时
    let supportedValues = [6, 12, 24, 48]
    // 找到最接近的预设值
    if let closest = supportedValues.min(by: { abs($0 - hours) < abs($1 - hours) }) {
      backupIntervalHours = closest
    } else {
      backupIntervalHours = 24 // 默认值
    }
    saveSettings()
  }
}
