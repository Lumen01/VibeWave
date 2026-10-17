import XCTest
import GRDB
@testable import VibeWave

final class IncrementalSyncServiceTests: XCTestCase {
    private final class EmptyParser: MessageParsing {
        func parseMessages(from url: URL) -> ParseResult {
            ParseResult(messages: [], affectedSessionIds: [])
        }

        func parseMessages(from data: Data, sourceURL: URL) -> ParseResult {
            ParseResult(messages: [], affectedSessionIds: [])
        }
    }

    func testSyncDirectoryCountsOnlyJSONCandidatesAndSkipsExcludedDescendants() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let excluded = root.appendingPathComponent("node_modules")
        try FileManager.default.createDirectory(at: excluded, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: root.appendingPathComponent("candidate.json"))
        try Data("text".utf8).write(to: root.appendingPathComponent("notes.txt"))
        try Data("{}".utf8).write(to: excluded.appendingPathComponent("excluded.json"))
        defer { try? FileManager.default.removeItem(at: root) }

        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("incremental-sync-\(UUID().uuidString).db")
        let dbPool = try DatabasePool(path: databaseURL.path)
        defer {
            try? dbPool.close()
            try? FileManager.default.removeItem(at: databaseURL)
        }
        try await dbPool.write { db in
            try DatabaseRepository.createTables(on: db)
        }

        let service = IncrementalSyncService(
            dbPool: dbPool,
            syncMetadataRepo: SyncMetadataRepository(dbPool: dbPool),
            messageRepo: MessageRepository(dbPool: dbPool),
            sessionService: SessionService(dbPool: dbPool),
            parser: EmptyParser()
        )

        let progress = try await service.syncDirectory(at: root)

        XCTAssertEqual(progress.totalFiles, 1)
        XCTAssertEqual(progress.skippedFiles, 1)
        XCTAssertEqual(progress.skippedFilePaths.map { URL(fileURLWithPath: $0).lastPathComponent }, ["candidate.json"])
    }
}
