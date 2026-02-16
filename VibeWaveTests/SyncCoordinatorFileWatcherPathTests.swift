import XCTest
import Combine
@testable import VibeWave

final class SyncCoordinatorFileWatcherPathTests: XCTestCase {
    func testStart_UsesFullSyncDirectoryForAutoStrategy() {
        let fileWatcher = CapturingFileWatcher()
        var registry = AIToolAdapterRegistry()
        registry.register(adapter: StubAdapter(toolId: "opencode"))

        let toolURL = URL(fileURLWithPath: "/tmp/tool")
        let fullURL = URL(fileURLWithPath: "/tmp/full")

        let coordinator = SyncCoordinator(
            adapterRegistry: registry,
            syncServices: ["opencode": NoopSyncService()],
            notificationCenter: NotificationCenter(),
            toolDataDirectoryProvider: { _ in toolURL },
            fullSyncDataDirectoryProvider: { _ in fullURL },
            databaseResetter: { },
            fileWatcher: fileWatcher,
            scheduler: NoopScheduler(),
            syncStrategyProvider: { .auto }
        )

        coordinator.start()

        XCTAssertEqual(fileWatcher.watchedDirectories, [fullURL])
    }
}

private final class CapturingFileWatcher: FileWatching {
    private let subject = PassthroughSubject<[FileSystemEvent], Never>()
    private(set) var watchedDirectories: [URL] = []

    var detectedEventsPublisher: AnyPublisher<[FileSystemEvent], Never> {
        subject.eraseToAnyPublisher()
    }

    func startWatching(directory url: URL) {
        watchedDirectories.append(url)
    }

    func stopWatching() {}
}

private struct StubAdapter: AIToolAdapter {
    let toolId: String
    let toolName = "Stub"
    let parser: MessageParsing

    init(toolId: String) {
        self.toolId = toolId
        self.parser = StubParser()
    }

    func parseMessages(from url: URL) -> AIParseResult {
        AIParseResult(messages: [], affectedSessionIds: [])
    }
}

private struct StubParser: MessageParsing {
    func parseMessages(from url: URL) -> ParseResult {
        ParseResult(messages: [], affectedSessionIds: [])
    }

    func parseMessages(from data: Data, sourceURL: URL) -> ParseResult {
        ParseResult(messages: [], affectedSessionIds: [])
    }
}

private struct NoopSyncService: SyncServiceProtocol {
    func syncDirectory(at url: URL, toolId: String) async throws -> SyncProgress {
        SyncProgress()
    }

    func syncFile(at url: URL, toolId: String) async throws -> (Int, Set<String>, String) {
        (0, [], toolId)
    }

    func syncFiles(at urls: [URL], toolId: String) async throws -> (Int, Set<String>, String) {
        (0, [], toolId)
    }
}

private struct NoopScheduler: SyncScheduling {
    func start(interval: TimeInterval, handler: @escaping () -> Void) {}
    func stop() {}
}
