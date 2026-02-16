import Foundation

public final class BackupScheduler {
    private var timer: Timer?
    private let backupManager: BackupManager
    private let logger = AppLogger(category: "BackupScheduler")
    private let enabledKey = "backup.enabled"
    private let intervalKey = "backup.interval"
    private let maxCountKey = "backup.maxCount"
    private let lastAutoBackupAtKey = "backup.lastAutoBackupAt"
    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    
    public var isEnabled: Bool {
        get {
            userDefaults.object(forKey: enabledKey) == nil ? true : userDefaults.bool(forKey: enabledKey)
        }
        set { userDefaults.set(newValue, forKey: enabledKey) }
    }
    
    public var intervalHours: Int {
        get {
            if userDefaults.object(forKey: intervalKey) == nil {
                return 24
            }
            return max(1, userDefaults.integer(forKey: intervalKey))
        }
        set { userDefaults.set(newValue, forKey: intervalKey) }
    }
    
    public init(
        backupManager: BackupManager,
        userDefaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.backupManager = backupManager
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
    }
    
    public func startScheduledBackups() {
        stopScheduledBackups()
        guard isEnabled else { return }
        
        let interval = TimeInterval(max(1, intervalHours) * 3600)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.triggerScheduledBackup()
        }
    }
    
    public func stopScheduledBackups() {
        timer?.invalidate()
        timer = nil
    }
    
    public func performAutomaticBackupNow() async throws {
        let maxCount = effectiveMaxCount()
        _ = try await backupManager.createBackup(from: DatabaseRepository.shared.dbPool(), kind: .automatic)
        try await backupManager.cleanupOldBackups(maxCount: maxCount, kind: .automatic)

        userDefaults.set(Date().timeIntervalSince1970, forKey: lastAutoBackupAtKey)
        notificationCenter.post(name: .backupDidUpdate, object: nil)
    }
    
    public func triggerScheduledBackup() {
        Task {
            do {
                try await performAutomaticBackupNow()
                logger.info("自动备份完成: \(Date())")
            } catch {
                logger.error("自动备份失败: \(error)")
            }
        }
    }
    
    public func shouldBackupNow() -> Bool {
        guard isEnabled else { return false }
        
        let lastBackupTime = userDefaults.double(forKey: lastAutoBackupAtKey)
        let timeSinceLastBackup = Date().timeIntervalSince1970 - lastBackupTime
        let interval = TimeInterval(intervalHours * 3600)
        
        return timeSinceLastBackup >= interval
    }

    private func effectiveMaxCount() -> Int {
        if userDefaults.object(forKey: maxCountKey) == nil {
            return 5
        }
        return max(1, userDefaults.integer(forKey: maxCountKey))
    }
}
