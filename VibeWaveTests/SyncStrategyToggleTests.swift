import XCTest
import Combine
@testable import VibeWave

final class SyncStrategyToggleTests: XCTestCase {
    private final class FakeFileWatcher: FileWatching {
        private let subject = PassthroughSubject<[FileSystemEvent], Never>()
        private(set) var startCount = 0
        private(set) var stopCount = 0

        var detectedEventsPublisher: AnyPublisher<[FileSystemEvent], Never> {
            subject.eraseToAnyPublisher()
        }

        func startWatching(directory url: URL) { startCount += 1 }
        func stopWatching() { stopCount += 1 }
    }

    private final class FakeScheduler: SyncScheduling {
        private(set) var startCount = 0
        private(set) var stopCount = 0
        private(set) var lastInterval: TimeInterval?

        func start(interval: TimeInterval, handler: @escaping () -> Void) {
            startCount += 1
            lastInterval = interval
        }

        func stop() { stopCount += 1 }
    }

    private final class FakeSyncService: SyncServiceProtocol {
        func syncDirectory(at url: URL, toolId: String) async throws -> SyncProgress {
            SyncProgress(totalFiles: 0, currentFile: "", importedFiles: 0, skippedFiles: 0)
        }

        func syncFile(at url: URL, toolId: String) async throws -> (Int, Set<String>, String) {
            (0, [], toolId)
        }

        func syncFiles(at urls: [URL], toolId: String) async throws -> (Int, Set<String>, String) {
            (0, [], toolId)
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

    private func makeCoordinator(
        strategy: @escaping () -> SyncStrategy,
        notificationCenter: NotificationCenter,
        fileWatcher: FakeFileWatcher,
        scheduler: FakeScheduler
    ) -> SyncCoordinator {
        var registry = AIToolAdapterRegistry()
        registry.register(adapter: FakeAdapter(toolId: "opencode"))

        return SyncCoordinator(
            adapterRegistry: registry,
            syncServices: ["opencode": FakeSyncService()],
            notificationCenter: notificationCenter,
            toolDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            fullSyncDataDirectoryProvider: { _ in URL(fileURLWithPath: "/tmp") },
            databaseResetter: {},
            fileWatcher: fileWatcher,
            scheduler: scheduler,
            syncStrategyProvider: strategy
        )
    }

    func testStart_UsesAutoModeByDefault() {
        let notificationCenter = NotificationCenter()
        let fileWatcher = FakeFileWatcher()
        let scheduler = FakeScheduler()
        let coordinator = makeCoordinator(
            strategy: { .auto },
            notificationCenter: notificationCenter,
            fileWatcher: fileWatcher,
            scheduler: scheduler
        )

        coordinator.start()

        XCTAssertEqual(fileWatcher.startCount, 1)
        XCTAssertEqual(scheduler.startCount, 0)
    }

    func testStart_UsesScheduledSyncWhenIntervalSelected() {
        let notificationCenter = NotificationCenter()
        let fileWatcher = FakeFileWatcher()
        let scheduler = FakeScheduler()
        let coordinator = makeCoordinator(
            strategy: { .minutes5 },
            notificationCenter: notificationCenter,
            fileWatcher: fileWatcher,
            scheduler: scheduler
        )

        coordinator.start()

        XCTAssertEqual(fileWatcher.startCount, 0)
        XCTAssertEqual(scheduler.startCount, 1)
        XCTAssertEqual(scheduler.lastInterval, 300)
    }

    func testNotification_TogglesBetweenAutoAndScheduled() {
        let notificationCenter = NotificationCenter()
        let fileWatcher = FakeFileWatcher()
        let scheduler = FakeScheduler()
        let coordinator = makeCoordinator(
            strategy: { .auto },
            notificationCenter: notificationCenter,
            fileWatcher: fileWatcher,
            scheduler: scheduler
        )

        coordinator.start()

        notificationCenter.post(
            name: .syncSettingsDidChange,
            object: nil,
            userInfo: ["syncStrategy": SyncStrategy.minutes1.rawValue]
        )

        XCTAssertEqual(fileWatcher.stopCount, 1)
        XCTAssertEqual(scheduler.startCount, 1)
        XCTAssertEqual(scheduler.lastInterval, 60)
    }
}
