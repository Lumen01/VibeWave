import Foundation

public final class BackupCoordinator {
    public static let shared = BackupCoordinator()

    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let fileManager: FileManager
    private let logger = AppLogger(category: "BackupCoordinator")

    private var scheduler: BackupScheduler?
    private var isStarted: Bool = false
    private var settingsObserver: NSObjectProtocol?

    private init(
        userDefaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.fileManager = fileManager
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true

        let primaryDirectory = AppPaths.backupsDirectory
        let legacyDirectory = AppPaths.legacyBackupsDirectory

        try? fileManager.createDirectory(at: primaryDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)

        let backupManager = BackupManager(
            backupDirectory: primaryDirectory,
            additionalSearchDirectories: [legacyDirectory],
            fileManager: fileManager
        )
        let scheduler = BackupScheduler(
            backupManager: backupManager,
            userDefaults: userDefaults,
            notificationCenter: notificationCenter
        )
        self.scheduler = scheduler

        applyCurrentSettings()

        settingsObserver = notificationCenter.addObserver(
            forName: .backupSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyCurrentSettings()
        }
    }

    private func applyCurrentSettings() {
        guard let scheduler else { return }

        scheduler.stopScheduledBackups()
        guard scheduler.isEnabled else { return }

        scheduler.startScheduledBackups()

        Task {
            guard scheduler.shouldBackupNow() else { return }
            do {
                try await scheduler.performAutomaticBackupNow()
                logger.info("启动补自动备份完成: \(Date())")
            } catch {
                logger.error("启动补自动备份失败: \(error)")
            }
        }
    }
}

