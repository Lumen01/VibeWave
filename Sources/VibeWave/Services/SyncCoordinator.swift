import Foundation
import Combine
import os

public struct ToolSyncState {
    public let toolId: String
    public var lastSyncTime: Date?
    public var syncError: Error?
    public var isSyncing: Bool = false
    
    public init(toolId: String) {
        self.toolId = toolId
    }
}

public final class SyncCoordinator: ObservableObject {
    // MARK: - Singleton
    public static let shared = SyncCoordinator()
    
    @Published public var isSyncing: Bool = false
    @Published public var syncProgress: SyncProgress?
    @Published public var lastSyncTime: Date?
    @Published public var syncError: Error?
    
    @Published public var toolSyncStates: [String: ToolSyncState] = [:]
    
    private var adapterRegistry: AIToolAdapterRegistry
    private var syncServices: [String: SyncServiceProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let fileWatcher: FileWatching
    private let scheduler: SyncScheduling
    private let syncStrategyProvider: () -> SyncStrategy
    private var isFileWatcherRunning = false
    private var isSchedulerRunning = false
    private var backupManager: BackupManager?
    private var aggregationService: AggregationService?
    private let notificationCenter: NotificationCenter
    private let toolDataDirectoryProvider: (String) -> URL
    private let fullSyncDataDirectoryProvider: (String) -> URL
    private let databaseResetter: () async throws -> Void
    private let logger = AppLogger(category: "SyncCoordinator")

    private init() {
        let backupDirectory = AppPaths.backupsDirectory
        let legacyBackupDirectory = AppPaths.legacyBackupsDirectory
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: legacyBackupDirectory, withIntermediateDirectories: true)
        backupManager = BackupManager(
            backupDirectory: backupDirectory,
            additionalSearchDirectories: [legacyBackupDirectory]
        )

        self.notificationCenter = .default
        self.fileWatcher = FileWatcher(flushInterval: 5.0)
        self.scheduler = SyncScheduler()
        self.syncStrategyProvider = {
            SyncStrategy.load(from: UserDefaults.standard)
        }
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        self.toolDataDirectoryProvider = { toolId in
            switch toolId {
            case "opencode":
                let configured = URL(fileURLWithPath: ConfigService.shared.importPath)
                return configured.deletingLastPathComponent()
            case "claude_code":
                return homeDirectory.appendingPathComponent(".claude_code")
            case "cursor":
                return homeDirectory.appendingPathComponent(".cursor")
            default:
                return homeDirectory.appendingPathComponent(".opencode")
            }
        }
        self.fullSyncDataDirectoryProvider = { toolId in
            switch toolId {
            case "opencode":
                let configured = URL(fileURLWithPath: ConfigService.shared.importPath)
                return configured.deletingLastPathComponent()
            case "claude_code":
                return homeDirectory.appendingPathComponent(".claude_code")
            case "cursor":
                return homeDirectory.appendingPathComponent(".cursor")
            default:
                return homeDirectory.appendingPathComponent(".opencode")
            }
        }
        self.databaseResetter = {
            try await DatabaseRepository.shared.dbPool().write { db in
                try db.execute(sql: "DELETE FROM messages")
                try db.execute(sql: "DELETE FROM sessions")
                try db.execute(sql: "DELETE FROM sync_metadata")
                try db.execute(sql: "DELETE FROM hourly_stats")
                try db.execute(sql: "DELETE FROM daily_stats")
                try db.execute(sql: "DELETE FROM monthly_stats")
            }
        }

        self.adapterRegistry = AIToolAdapterRegistry()
        setupDefaultTool()
        setupFileWatcherEvents()
        setupSyncSettingsObserver()
        setupDataSourceObserver()
    }

    internal init(
        adapterRegistry: AIToolAdapterRegistry,
        syncServices: [String: SyncServiceProtocol],
        notificationCenter: NotificationCenter = .default,
        toolDataDirectoryProvider: @escaping (String) -> URL,
        fullSyncDataDirectoryProvider: @escaping (String) -> URL,
        databaseResetter: @escaping () async throws -> Void,
        fileWatcher: FileWatching = FileWatcher(),
        scheduler: SyncScheduling = SyncScheduler(),
        syncStrategyProvider: @escaping () -> SyncStrategy = {
            SyncStrategy.load(from: UserDefaults.standard)
        }
    ) {
        self.adapterRegistry = adapterRegistry
        self.syncServices = syncServices
        self.notificationCenter = notificationCenter
        self.toolDataDirectoryProvider = toolDataDirectoryProvider
        self.fullSyncDataDirectoryProvider = fullSyncDataDirectoryProvider
        self.databaseResetter = databaseResetter
        self.fileWatcher = fileWatcher
        self.scheduler = scheduler
        self.syncStrategyProvider = syncStrategyProvider
        setupFileWatcherEvents()
        setupSyncSettingsObserver()
        setupDataSourceObserver()
    }
    
    private func setupDefaultTool() {
        let opencodeParser = OpenCodeMessageParser()
        let claudeCodeParser = ClaudeCodeMessageParser()
        let cursorParser = CursorMessageParser()
        
        var mutableRegistry = adapterRegistry
        mutableRegistry.register(adapter: OpenCodeAdapter(parser: opencodeParser))
        mutableRegistry.register(adapter: ClaudeCodeAdapter(parser: claudeCodeParser))
        mutableRegistry.register(adapter: CursorAdapter(parser: cursorParser))
        adapterRegistry = mutableRegistry
        
        toolSyncStates["opencode"] = ToolSyncState(toolId: "opencode")
        toolSyncStates["claude_code"] = ToolSyncState(toolId: "claude_code")
        toolSyncStates["cursor"] = ToolSyncState(toolId: "cursor")

        let opencodeDatabaseURL = URL(fileURLWithPath: ConfigService.shared.importPath)

        syncServices["opencode"] = OpenCodeDatabaseSyncService(
            sourceDatabaseURL: opencodeDatabaseURL,
            dbPool: DatabaseRepository.shared.dbPool(),
            syncMetadataRepo: SyncMetadataRepository(dbPool: DatabaseRepository.shared.dbPool()),
            messageRepo: MessageRepository(dbPool: DatabaseRepository.shared.dbPool()),
            sessionService: SessionService(dbPool: DatabaseRepository.shared.dbPool()),
            parser: opencodeParser
        )

        syncServices["claude_code"] = IncrementalSyncService(
            dbPool: DatabaseRepository.shared.dbPool(),
            syncMetadataRepo: SyncMetadataRepository(dbPool: DatabaseRepository.shared.dbPool()),
            messageRepo: MessageRepository(dbPool: DatabaseRepository.shared.dbPool()),
            sessionService: SessionService(dbPool: DatabaseRepository.shared.dbPool()),
            parser: claudeCodeParser
        )

        syncServices["cursor"] = IncrementalSyncService(
            dbPool: DatabaseRepository.shared.dbPool(),
            syncMetadataRepo: SyncMetadataRepository(dbPool: DatabaseRepository.shared.dbPool()),
            messageRepo: MessageRepository(dbPool: DatabaseRepository.shared.dbPool()),
            sessionService: SessionService(dbPool: DatabaseRepository.shared.dbPool()),
            parser: cursorParser
        )

        // Initialize aggregation service
        self.aggregationService = AggregationService(
            dbPool: DatabaseRepository.shared.dbPool()
        )
    }
    
    private func setupFileWatcherEvents() {
        fileWatcher.detectedEventsPublisher
            .sink { [weak self] events in
                self?.handleFileWatcherEvents(events)
            }
            .store(in: &cancellables)
    }

    private func setupSyncSettingsObserver() {
        notificationCenter.publisher(for: .syncSettingsDidChange)
            .compactMap { $0.userInfo?["syncStrategy"] as? String }
            .compactMap { SyncStrategy(rawValue: $0) }
            .sink { [weak self] strategy in
                self?.applySyncStrategy(strategy)
            }
            .store(in: &cancellables)
    }

    private func setupDataSourceObserver() {
        notificationCenter.publisher(for: .dataSourceDidChange)
            .compactMap { $0.userInfo?["path"] as? String }
            .sink { [weak self] path in
                self?.updateOpenCodeDataSource(path)
            }
            .store(in: &cancellables)
    }
    
     public func start() {
        logger.debug("Sync coordinator starting")
        logger.debug("Current isSyncing state: \(self.isSyncing)")
        performInitialSync()
        applySyncStrategy(syncStrategyProvider())
        logger.debug("Sync coordinator started")
    }
     
     public
func performInitialSync() {
        guard !self.isSyncing else { 
            logger.warn("Initial sync already in progress, skipping (isSyncing: \(self.isSyncing))")
            return 
        }
        isSyncing = true
        syncError = nil
        logger.debug("Starting initial sync for all tools")
        
        Task {
            var lastError: Error? = nil

            // Sync all registered tools
            for toolId in adapterRegistry.getAllToolIds() {
                guard let syncService = syncServices[toolId] else {
                    logger.warn("Sync service not found for tool: \(toolId)")
                    continue
                }

                let dataDirectory = fullSyncDataDirectoryProvider(toolId)
                logger.debug("Syncing tool: \(toolId) from \(dataDirectory.path)")

                do {
                    let progress = try await syncService.syncDirectory(at: dataDirectory, toolId: toolId)

                    DispatchQueue.main.async {
                        self.syncProgress = progress
                        self.lastSyncTime = Date()
                    }

                    logger.debug("Tool \(toolId) sync completed: \(progress.importedFiles) imported, \(progress.skippedFiles) skipped")
                    updateToolSyncState(toolId: toolId, error: nil)

                    // 聚合数据
                    if let aggregationService = self.aggregationService {
                        do {
                            try aggregationService.rebuildAllAggregations()
                            self.logger.info("数据聚合完成")
                        } catch {
                            self.logger.error("数据聚合失败: \(error)")
                            // 聚合失败不影响主流程，仅记录日志
                        }
                    }
                } catch {
                    lastError = error
                    logger.error("Tool \(toolId) initial sync failed: \(error.localizedDescription)")
                    updateToolSyncState(toolId: toolId, error: error)
                }
            }

            if let lastError = lastError {
                DispatchQueue.main.async {
                    self.syncError = lastError
                }
            }

            self.notifyDataUpdated()
            
            logger.debug("Initial sync completed")
            
            DispatchQueue.main.async {
                self.isSyncing = false
            }
        }
    }

    private func performScheduledSync() {
        guard !self.isSyncing else { return }
        isSyncing = true
        syncError = nil

        Task {
            var lastError: Error? = nil

            for toolId in adapterRegistry.getAllToolIds() {
                guard let syncService = syncServices[toolId] else {
                    continue
                }

                let dataDirectory = fullSyncDataDirectoryProvider(toolId)

                do {
                    let progress = try await syncService.syncDirectory(at: dataDirectory, toolId: toolId)

                    DispatchQueue.main.async {
                        self.syncProgress = progress
                        self.lastSyncTime = Date()
                    }

                    updateToolSyncState(toolId: toolId, error: nil)
                } catch {
                    lastError = error
                    updateToolSyncState(toolId: toolId, error: error)
                }
            }

            if let aggregationService = self.aggregationService {
                do {
                    try aggregationService.rebuildAllAggregations()
                    self.logger.info("定时同步后聚合完成")
                } catch {
                    self.logger.error("定时同步后聚合失败: \(error)")
                }
            }

            if let lastError = lastError {
                DispatchQueue.main.async {
                    self.syncError = lastError
                }
            }

            self.notifyDataUpdated()

            DispatchQueue.main.async {
                self.isSyncing = false
            }
        }
    }
    
    public func performFullSync() {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        Task {
            var tempBackup: BackupInfo? = nil
            var lastError: Error? = nil

            do {
                if let backupManager = backupManager {
                    tempBackup = try await backupManager.createBackup(from: DatabaseRepository.shared.dbPool(), kind: .system)
                }

                try await databaseResetter()

                for toolId in adapterRegistry.getAllToolIds() {
                    guard let syncService = syncServices[toolId] else { continue }

                    let dataDirectory = fullSyncDataDirectoryProvider(toolId)
                    do {
                        let progress = try await syncService.syncDirectory(at: dataDirectory, toolId: toolId)

                        DispatchQueue.main.async {
                            self.syncProgress = progress
                            self.lastSyncTime = Date()
                        }
                        updateToolSyncState(toolId: toolId, error: nil)
                    } catch {
                        lastError = error
                        logger.error("Tool \(toolId) full sync failed: \(error.localizedDescription)")
                        updateToolSyncState(toolId: toolId, error: error)
                    }
                }

                if let aggregationService = self.aggregationService {
                    do {
                        try aggregationService.rebuildAllAggregations()
                        self.logger.info("全量同步后聚合完成")
                    } catch {
                        self.logger.error("全量同步后聚合失败: \(error)")
                    }
                }

                if let backupManager = backupManager, let backup = tempBackup {
                    try await backupManager.deleteBackup(backup)
                }

            if let lastError = lastError {
                DispatchQueue.main.async {
                    self.syncError = lastError
                }
            }

            self.notifyDataUpdated()
            } catch {
                if let backupManager = backupManager, let backup = tempBackup {
                    try? await backupManager.restoreBackup(backup, to: DatabaseRepository.shared.dbPool())
                }

                DispatchQueue.main.async {
                    self.syncError = error
                }
            }

            DispatchQueue.main.async {
                self.isSyncing = false
            }
        }
    }
    
    private func startFileWatcher() {
        guard !isFileWatcherRunning else { return }
        // Watch directories for all registered tools
        for toolId in adapterRegistry.getAllToolIds() {
            let dataDirectory = fullSyncDataDirectoryProvider(toolId)
            fileWatcher.startWatching(directory: dataDirectory)
        }
        isFileWatcherRunning = true
    }

    private func stopFileWatcher() {
        guard isFileWatcherRunning else { return }
        fileWatcher.stopWatching()
        isFileWatcherRunning = false
    }

    private func startScheduledSync(interval: TimeInterval) {
        scheduler.start(interval: interval) { [weak self] in
            self?.performScheduledSync()
        }
        isSchedulerRunning = true
    }

    private func stopScheduledSync() {
        guard isSchedulerRunning else { return }
        scheduler.stop()
        isSchedulerRunning = false
    }

    private func applySyncStrategy(_ strategy: SyncStrategy) {
        switch strategy {
        case .auto:
            stopScheduledSync()
            startFileWatcher()
        default:
            stopFileWatcher()
            if let interval = strategy.intervalSeconds {
                startScheduledSync(interval: interval)
            }
        }
    }
    
     private func defaultDataDirectory() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".opencode")
    }
    
    private func toolDataDirectory(for toolId: String) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch toolId {
        case "opencode":
            return URL(fileURLWithPath: ConfigService.shared.importPath).deletingLastPathComponent()
        case "claude_code":
            return home.appendingPathComponent(".claude_code")
        case "cursor":
            return home.appendingPathComponent(".cursor")
        default:
            return defaultDataDirectory()
        }
    }
    
    public func handleFileWatcherEvents(_ events: [FileSystemEvent]) {
        guard !events.isEmpty else { return }
        Task {
            let groupedEvents = Dictionary(grouping: events) { event in
                detectToolFromFile(event.filePath)
            }

            var hasDataChanged = false

            for (toolId, grouped) in groupedEvents {
                guard let syncService = syncServices[toolId] else { continue }
                let urls = grouped.map { URL(fileURLWithPath: $0.filePath) }

                do {
                    let (importedCount, affectedSessionIds, _) = try await syncService.syncFiles(at: urls, toolId: toolId)
                    if importedCount > 0 {
                        hasDataChanged = true

                        if !affectedSessionIds.isEmpty {
                            try sessionService(for: toolId).recalculateSessions(for: affectedSessionIds)

                            // 增量聚合更新
                            if let aggregationService = self.aggregationService {
                                do {
                                    try aggregationService.recalculateAffectedAggregations(for: affectedSessionIds)
                                    self.logger.debug("增量聚合完成: \(affectedSessionIds.count) 个会话")
                                } catch {
                                    self.logger.error("增量聚合失败: \(error)")
                                    // 聚合失败不影响主流程
                                }
                            }
                        }
                    }

                    updateToolSyncState(toolId: toolId, error: nil)
                } catch {
                    updateToolSyncState(toolId: toolId, error: error)
                }
            }

            if hasDataChanged {
                notifyDataUpdated()
            }
        }
    }
    
    public func syncSingleFile(_ url: URL, using adapter: AIToolAdapter) async throws {
        guard !isSyncing else { return }
        isSyncing = true
        
        defer {
            DispatchQueue.main.async {
                self.isSyncing = false
            }
        }
        
        let toolId = adapter.toolId
        let parser = adapter.parser
        let syncService = syncServices[toolId] ?? createSyncService(for: toolId, parser: parser)
        let (importedCount, affectedSessionIds, _) = try await syncService.syncFile(at: url, toolId: toolId)

        if importedCount > 0 && !affectedSessionIds.isEmpty {
            try sessionService(for: toolId).recalculateSessions(for: affectedSessionIds)

            // 增量聚合更新
            if let aggregationService = self.aggregationService {
                do {
                    try aggregationService.recalculateAffectedAggregations(for: affectedSessionIds)
                    self.logger.debug("增量聚合完成: \(affectedSessionIds.count) 个会话")
                } catch {
                    self.logger.error("增量聚合失败: \(error)")
                    // 聚合失败不影响主流程
                }
            }
        }

        updateToolSyncState(toolId: toolId, error: nil)
    }
    
    public func registerTool(toolId: String, parser: MessageParsing) {
        let syncService = IncrementalSyncService(
            dbPool: DatabaseRepository.shared.dbPool(),
            syncMetadataRepo: SyncMetadataRepository(dbPool: DatabaseRepository.shared.dbPool()),
            messageRepo: MessageRepository(dbPool: DatabaseRepository.shared.dbPool()),
            sessionService: SessionService(dbPool: DatabaseRepository.shared.dbPool()),
            parser: parser
        )
        syncServices[toolId] = syncService
        toolSyncStates[toolId] = ToolSyncState(toolId: toolId)
    }
    
    private func createSyncService(for toolId: String, parser: MessageParsing) -> IncrementalSyncService {
        let service = IncrementalSyncService(
            dbPool: DatabaseRepository.shared.dbPool(),
            syncMetadataRepo: SyncMetadataRepository(dbPool: DatabaseRepository.shared.dbPool()),
            messageRepo: MessageRepository(dbPool: DatabaseRepository.shared.dbPool()),
            sessionService: SessionService(dbPool: DatabaseRepository.shared.dbPool()),
            parser: parser
        )
        syncServices[toolId] = service
        return service
    }
    
    private func sessionService(for toolId: String) -> SessionService {
        return SessionService(dbPool: DatabaseRepository.shared.dbPool())
    }
    
    private func updateToolSyncState(toolId: String, error: Error?) {
        DispatchQueue.main.async {
            var state = self.toolSyncStates[toolId] ?? ToolSyncState(toolId: toolId)
            state.lastSyncTime = Date()
            state.syncError = error
            state.isSyncing = false
            self.toolSyncStates[toolId] = state
        }
    }
    
    private func detectToolFromFile(_ filePath: String) -> String {
        if filePath.contains("/opencode/") {
            return "opencode"
        } else if filePath.contains("/claude_code/") {
            return "claude_code"
        } else if filePath.contains("/cursor/") {
            return "cursor"
        } else {
            return "opencode"
        }
    }
    
    private func notifyDataUpdated() {
        notificationCenter.post(name: .appDataDidUpdate, object: nil)
    }

    private func updateOpenCodeDataSource(_ path: String) {
        let dbURL = URL(fileURLWithPath: path)
        syncServices["opencode"] = OpenCodeDatabaseSyncService(
            sourceDatabaseURL: dbURL,
            dbPool: DatabaseRepository.shared.dbPool(),
            syncMetadataRepo: SyncMetadataRepository(dbPool: DatabaseRepository.shared.dbPool()),
            messageRepo: MessageRepository(dbPool: DatabaseRepository.shared.dbPool()),
            sessionService: SessionService(dbPool: DatabaseRepository.shared.dbPool()),
            parser: OpenCodeMessageParser()
        )
        applySyncStrategy(syncStrategyProvider())
    }
}

extension Notification.Name {
    public static let appDataDidUpdate = Notification.Name("appDataDidUpdate")
    public static let syncSettingsDidChange = Notification.Name("syncSettingsDidChange")
    public static let dataSourceDidChange = Notification.Name("dataSourceDidChange")
    public static let backupSettingsDidChange = Notification.Name("backupSettingsDidChange")
    public static let backupDidUpdate = Notification.Name("backupDidUpdate")
    public static let showSettingsAbout = Notification.Name("showSettingsAbout")
}
