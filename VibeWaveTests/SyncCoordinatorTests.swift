import XCTest
@testable import VibeWave

final class SyncCoordinatorTests: XCTestCase {
    private final class FakeSyncService: SyncServiceProtocol {
        private(set) var syncDirectoryCallCount: Int = 0
        private(set) var lastSyncDirectoryURL: URL?
        private let onSyncDirectory: ((URL, String) -> Void)?
        private var shouldThrowOnSyncDirectory = false
        private let importedFiles: Int

        init(importedFiles: Int = 0, onSyncDirectory: ((URL, String) -> Void)? = nil) {
            self.importedFiles = importedFiles
            self.onSyncDirectory = onSyncDirectory
        }

        func setThrowOnSyncDirectory(_ shouldThrow: Bool) {
            shouldThrowOnSyncDirectory = shouldThrow
        }

        func syncDirectory(at url: URL, toolId: String) async throws -> SyncProgress {
            syncDirectoryCallCount += 1
            lastSyncDirectoryURL = url
            onSyncDirectory?(url, toolId)
            if shouldThrowOnSyncDirectory {
                throw SyncError.notADirectory(url.path)
            }
            return SyncProgress(totalFiles: importedFiles, currentFile: "", importedFiles: importedFiles, skippedFiles: 0)
        }

        func syncFile(at url: URL, toolId: String) async throws -> (Int, Set<String>, String) {
            return (0, [], toolId)
        }

        func syncFiles(at urls: [URL], toolId: String) async throws -> (Int, Set<String>, String) {
            return (0, [], toolId)
        }
    }

    private final class FakeScheduler: SyncScheduling {
        private var handler: (() -> Void)?

        func start(interval: TimeInterval, handler: @escaping () -> Void) {
            self.handler = handler
        }

        func stop() {}

        func fire() {
            handler?()
        }
    }

    private struct NoopParser: MessageParsing {
        func parseMessages(from url: URL) -> ParseResult {
            ParseResult(messages: [], affectedSessionIds: [])
        }

        func parseMessages(from data: Data, sourceURL: URL) -> ParseResult {
            ParseResult(messages: [], affectedSessionIds: [])
        }
    }

    private final class FakeAdapter: AIToolAdapter {
        let toolId: String
        let toolName: String
        let parser: MessageParsing

        init(toolId: String) {
            self.toolId = toolId
            self.toolName = "Fake \(toolId)"
            self.parser = NoopParser()
        }

        func parseMessages(from url: URL) -> AIParseResult {
            let result = parser.parseMessages(from: url)
            return AIParseResult(messages: result.messages, affectedSessionIds: result.affectedSessionIds)
        }
    }

    func testInitialSync_PostsDataUpdateNotification() {
        let notificationCenter = NotificationCenter()
        let expectation = XCTestExpectation(description: "appDataDidUpdate posted after initial sync")

        let observer = notificationCenter.addObserver(
            forName: .appDataDidUpdate,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        var registry = AIToolAdapterRegistry()
        registry.register(adapter: FakeAdapter(toolId: "opencode"))

        let fakeService = FakeSyncService()
        let coordinator = SyncCoordinator(
            adapterRegistry: registry,
            syncServices: ["opencode": fakeService],
            notificationCenter: notificationCenter,
            toolDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            fullSyncDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            databaseResetter: {}
        )

        coordinator.performInitialSync()

        wait(for: [expectation], timeout: 5.0)
        notificationCenter.removeObserver(observer)
    }

    func testFullSync_PostsDataUpdateNotification() {
        let notificationCenter = NotificationCenter()
        let expectation = XCTestExpectation(description: "appDataDidUpdate posted after full sync")

        let observer = notificationCenter.addObserver(
            forName: .appDataDidUpdate,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        var registry = AIToolAdapterRegistry()
        registry.register(adapter: FakeAdapter(toolId: "opencode"))

        let fakeService = FakeSyncService()
        let coordinator = SyncCoordinator(
            adapterRegistry: registry,
            syncServices: ["opencode": fakeService],
            notificationCenter: notificationCenter,
            toolDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            fullSyncDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            databaseResetter: {}
        )

        coordinator.performFullSync()

        wait(for: [expectation], timeout: 2.0)
        notificationCenter.removeObserver(observer)
    }

    func testFullSync_WhenToolFails_RestoresBackupWithoutDeletingIt() async {
        var registry = AIToolAdapterRegistry()
        registry.register(adapter: FakeAdapter(toolId: "first"))
        registry.register(adapter: FakeAdapter(toolId: "second"))
        let first = FakeSyncService()
        let second = FakeSyncService()
        second.setThrowOnSyncDirectory(true)
        var restored = false
        var deleted = false

        let coordinator = SyncCoordinator(
            adapterRegistry: registry,
            syncServices: ["first": first, "second": second],
            toolDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            fullSyncDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            databaseResetter: {},
            createFullSyncBackup: {},
            restoreFullSyncBackup: { restored = true },
            deleteFullSyncBackup: { deleted = true }
        )

        do {
            try await coordinator.executeFullSync()
            XCTFail("Expected full sync to fail")
        } catch {
            XCTAssertTrue(restored)
            XCTAssertFalse(deleted)
        }
    }

    func testInitialSync_UsesMessageDirectoryForOpenCode() {
        let notificationCenter = NotificationCenter()
        let expectation = XCTestExpectation(description: "syncDirectory called")

        var registry = AIToolAdapterRegistry()
        registry.register(adapter: FakeAdapter(toolId: "opencode"))

        let fakeService = FakeSyncService { _, _ in
            expectation.fulfill()
        }

        let coordinator = SyncCoordinator(
            adapterRegistry: registry,
            syncServices: ["opencode": fakeService],
            notificationCenter: notificationCenter,
            toolDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp/storage") },
            fullSyncDataDirectoryProvider: { toolId in
                if toolId == "opencode" {
                    return URL(fileURLWithPath: "/tmp/storage/message")
                }
                return URL(fileURLWithPath: "/tmp/storage")
            },
            databaseResetter: {}
        )

        coordinator.performInitialSync()

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(fakeService.lastSyncDirectoryURL?.path, "/tmp/storage/message")
    }

    func testInitialSync_ContinuesAfterToolFailure() {
        let notificationCenter = NotificationCenter()
        let expectation = XCTestExpectation(description: "second tool still synced")

        var registry = AIToolAdapterRegistry()
        registry.register(adapter: FakeAdapter(toolId: "a_tool"))
        registry.register(adapter: FakeAdapter(toolId: "b_tool"))

        let failingService = FakeSyncService()
        let successService = FakeSyncService { _, toolId in
            if toolId == "b_tool" {
                expectation.fulfill()
            }
        }

        let coordinator = SyncCoordinator(
            adapterRegistry: registry,
            syncServices: [
                "a_tool": failingService,
                "b_tool": successService
            ],
            notificationCenter: notificationCenter,
            toolDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            fullSyncDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            databaseResetter: {}
        )

        failingService.setThrowOnSyncDirectory(true)
        coordinator.performInitialSync()

        wait(for: [expectation], timeout: 2.0)
    }

    func testInitialSync_RunsMigrationsOnceAndRebuildsOnceForAllImports() {
        let completion = expectation(description: "initial sync completed")
        let notificationCenter = NotificationCenter()
        let observer = notificationCenter.addObserver(forName: .appDataDidUpdate, object: nil, queue: nil) { _ in
            completion.fulfill()
        }
        var registry = AIToolAdapterRegistry()
        registry.register(adapter: FakeAdapter(toolId: "first"))
        registry.register(adapter: FakeAdapter(toolId: "second"))
        var migrationCount = 0
        var rebuildCount = 0
        let coordinator = SyncCoordinator(
            adapterRegistry: registry,
            syncServices: ["first": FakeSyncService(importedFiles: 1), "second": FakeSyncService(importedFiles: 2)],
            notificationCenter: notificationCenter,
            toolDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            fullSyncDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            databaseResetter: {},
            performInitialMigrations: { migrationCount += 1; return false },
            rebuildAggregations: { rebuildCount += 1 }
        )

        coordinator.performInitialSync()

        wait(for: [completion], timeout: 2.0)
        notificationCenter.removeObserver(observer)
        XCTAssertEqual(migrationCount, 1)
        XCTAssertEqual(rebuildCount, 1)
    }

    func testInitialSync_WithZeroImportsRunsMigrationsWithoutRebuilding() {
        let completion = expectation(description: "initial sync completed")
        let notificationCenter = NotificationCenter()
        let observer = notificationCenter.addObserver(forName: .appDataDidUpdate, object: nil, queue: nil) { _ in
            completion.fulfill()
        }
        var registry = AIToolAdapterRegistry()
        registry.register(adapter: FakeAdapter(toolId: "opencode"))
        var migrationCount = 0
        var rebuildCount = 0
        let coordinator = SyncCoordinator(
            adapterRegistry: registry,
            syncServices: ["opencode": FakeSyncService()],
            notificationCenter: notificationCenter,
            toolDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            fullSyncDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            databaseResetter: {},
            performInitialMigrations: { migrationCount += 1; return false },
            rebuildAggregations: { rebuildCount += 1 }
        )

        coordinator.performInitialSync()

        wait(for: [completion], timeout: 2.0)
        notificationCenter.removeObserver(observer)
        XCTAssertEqual(migrationCount, 1)
        XCTAssertEqual(rebuildCount, 0)
    }

    func testScheduledSync_WithZeroImportsSkipsRebuildAndNotification() {
        let initialNotification = expectation(description: "initial sync notification")
        let unexpectedNotification = expectation(description: "no scheduled sync notification")
        unexpectedNotification.isInverted = true
        let notificationCenter = NotificationCenter()
        var notificationCount = 0
        let observer = notificationCenter.addObserver(forName: .appDataDidUpdate, object: nil, queue: nil) { _ in
            notificationCount += 1
            if notificationCount == 1 {
                initialNotification.fulfill()
            } else {
                unexpectedNotification.fulfill()
            }
        }
        var registry = AIToolAdapterRegistry()
        registry.register(adapter: FakeAdapter(toolId: "opencode"))
        let scheduler = FakeScheduler()
        var rebuildCount = 0
        let coordinator = SyncCoordinator(
            adapterRegistry: registry,
            syncServices: ["opencode": FakeSyncService()],
            notificationCenter: notificationCenter,
            toolDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            fullSyncDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            databaseResetter: {},
            rebuildAggregations: { rebuildCount += 1 },
            scheduler: scheduler,
            syncStrategyProvider: { .minutes1 }
        )

        coordinator.start()
        wait(for: [initialNotification], timeout: 2.0)
        XCTAssertFalse(coordinator.isSyncing)
        scheduler.fire()

        wait(for: [unexpectedNotification], timeout: 0.2)
        notificationCenter.removeObserver(observer)
        XCTAssertEqual(rebuildCount, 0)
        XCTAssertEqual(notificationCount, 1)
    }
}
