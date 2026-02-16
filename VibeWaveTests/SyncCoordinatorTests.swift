import XCTest
@testable import VibeWave

final class SyncCoordinatorTests: XCTestCase {
    private final class FakeSyncService: SyncServiceProtocol {
        private(set) var syncDirectoryCallCount: Int = 0
        private(set) var lastSyncDirectoryURL: URL?
        private let onSyncDirectory: ((URL, String) -> Void)?
        private var shouldThrowOnSyncDirectory = false

        init(onSyncDirectory: ((URL, String) -> Void)? = nil) {
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
            return SyncProgress(totalFiles: 0, currentFile: "", importedFiles: 0, skippedFiles: 0)
        }

        func syncFile(at url: URL, toolId: String) async throws -> (Int, Set<String>, String) {
            return (0, [], toolId)
        }

        func syncFiles(at urls: [URL], toolId: String) async throws -> (Int, Set<String>, String) {
            return (0, [], toolId)
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

        wait(for: [expectation], timeout: 2.0)
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
}
