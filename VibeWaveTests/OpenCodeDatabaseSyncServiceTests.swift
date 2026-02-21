import XCTest
import GRDB
@testable import VibeWave

final class OpenCodeDatabaseSyncServiceTests: XCTestCase {
    private var sourceDBPath: String!
    private var targetDBPath: String!
    private var sourceDBURL: URL!
    private var targetPool: DatabasePool!
    private var service: OpenCodeDatabaseSyncService!
    private var syncMetadataRepo: SyncMetadataRepository!
    private var messageRepo: MessageRepository!
    private var sessionService: SessionService!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        sourceDBPath = tempDir.appendingPathComponent("opencode-source-\(UUID().uuidString).db").path
        targetDBPath = tempDir.appendingPathComponent("opencode-target-\(UUID().uuidString).db").path
        sourceDBURL = URL(fileURLWithPath: sourceDBPath)

        let sourceQueue = try! DatabaseQueue(path: sourceDBPath)
        try! sourceQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE message (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    time_created INTEGER NOT NULL,
                    time_updated INTEGER NOT NULL,
                    data TEXT NOT NULL
                )
            """)
        }

        targetPool = try! DatabasePool(path: targetDBPath)
        try! targetPool.write { db in
            try DatabaseRepository.createTables(on: db)
        }

        syncMetadataRepo = SyncMetadataRepository(dbPool: targetPool)
        messageRepo = MessageRepository(dbPool: targetPool)
        sessionService = SessionService(dbPool: targetPool)

        service = OpenCodeDatabaseSyncService(
            sourceDatabaseURL: sourceDBURL,
            dbPool: targetPool,
            syncMetadataRepo: syncMetadataRepo,
            messageRepo: messageRepo,
            sessionService: sessionService,
            parser: OpenCodeMessageParser()
        )
    }

    override func tearDown() {
        if let sourceDBPath {
            try? FileManager.default.removeItem(atPath: sourceDBPath)
            try? FileManager.default.removeItem(atPath: sourceDBPath + "-wal")
            try? FileManager.default.removeItem(atPath: sourceDBPath + "-shm")
        }
        if let targetDBPath {
            try? FileManager.default.removeItem(atPath: targetDBPath)
            try? FileManager.default.removeItem(atPath: targetDBPath + "-wal")
            try? FileManager.default.removeItem(atPath: targetDBPath + "-shm")
        }
        super.tearDown()
    }

    func testSyncDirectory_ImportsMessagesFromDatabaseDataColumn() async throws {
        let sourceQueue = try DatabaseQueue(path: sourceDBPath)
        try await sourceQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO message (id, session_id, time_created, time_updated, data)
                    VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    "msg_db_1",
                    "session_db_1",
                    1_771_057_712_661 as Int64,
                    1_771_057_722_000 as Int64,
                    """
                    {"role":"assistant","time":{"created":1771057712661,"completed":1771057721546},"providerID":"opencode","modelID":"model-a"}
                    """
                ]
            )
        }

        let progress = try await service.syncDirectory(at: URL(fileURLWithPath: "/tmp"), toolId: "opencode")

        XCTAssertEqual(progress.importedFiles, 1)
        XCTAssertNotNil(messageRepo.fetch(by: "msg_db_1"))
        XCTAssertNotNil(syncMetadataRepo.fetch(filePath: sourceDBURL.path))
    }

    func testSyncDirectory_WhenSourceUnchanged_SecondSyncIsSkipped() async throws {
        let sourceQueue = try DatabaseQueue(path: sourceDBPath)
        try await sourceQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO message (id, session_id, time_created, time_updated, data)
                    VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    "msg_db_2",
                    "session_db_2",
                    1_771_057_712_661 as Int64,
                    1_771_057_722_000 as Int64,
                    """
                    {"role":"assistant","time":{"created":1771057712661,"completed":1771057721546},"providerID":"opencode","modelID":"model-b"}
                    """
                ]
            )
        }

        _ = try await service.syncDirectory(at: URL(fileURLWithPath: "/tmp"), toolId: "opencode")
        let second = try await service.syncDirectory(at: URL(fileURLWithPath: "/tmp"), toolId: "opencode")

        XCTAssertEqual(second.importedFiles, 0)
        XCTAssertEqual(second.skippedFiles, 1)
    }

    func testSyncDirectory_WhenNewRowsAdded_OnlyImportsIncrementalRows() async throws {
        let sourceQueue = try DatabaseQueue(path: sourceDBPath)
        try await sourceQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO message (id, session_id, time_created, time_updated, data)
                    VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    "msg_db_3",
                    "session_db_3",
                    1_771_057_712_000 as Int64,
                    1_771_057_713_000 as Int64,
                    """
                    {"role":"assistant","time":{"created":1771057712000,"completed":1771057713000},"providerID":"opencode","modelID":"model-c"}
                    """
                ]
            )
        }

        _ = try await service.syncDirectory(at: URL(fileURLWithPath: "/tmp"), toolId: "opencode")

        try await sourceQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO message (id, session_id, time_created, time_updated, data)
                    VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    "msg_db_4",
                    "session_db_4",
                    1_771_057_714_000 as Int64,
                    1_771_057_715_000 as Int64,
                    """
                    {"role":"assistant","time":{"created":1771057714000,"completed":1771057715000},"providerID":"opencode","modelID":"model-d"}
                    """
                ]
            )
        }

        let second = try await service.syncDirectory(at: URL(fileURLWithPath: "/tmp"), toolId: "opencode")

        XCTAssertEqual(second.importedFiles, 1)
        XCTAssertNotNil(messageRepo.fetch(by: "msg_db_3"))
        XCTAssertNotNil(messageRepo.fetch(by: "msg_db_4"))
    }

    func testSyncDirectory_BackfillsMissingAssistantProviderAndModelFromSourceDatabase() async throws {
        let sourceQueue = try DatabaseQueue(path: sourceDBPath)
        try await sourceQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO message (id, session_id, time_created, time_updated, data)
                    VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    "msg_backfill_1",
                    "session_backfill_1",
                    1_771_057_700_000 as Int64,
                    1_771_057_710_000 as Int64,
                    """
                    {"role":"assistant","time":{"created":1771057700000,"completed":1771057710000},"providerID":"openai","modelID":"gpt-4.1"}
                    """
                ]
            )
        }

        _ = try await service.syncDirectory(at: URL(fileURLWithPath: "/tmp"), toolId: "opencode")

        try await targetPool.write { db in
            try db.execute(
                sql: """
                    UPDATE messages
                    SET provider_id = NULL, model_id = NULL
                    WHERE id = 'msg_backfill_1'
                """
            )
        }

        _ = try await service.syncDirectory(at: URL(fileURLWithPath: "/tmp"), toolId: "opencode")

        let record = messageRepo.fetch(by: "msg_backfill_1")
        XCTAssertEqual(record?.providerId, "openai")
        XCTAssertEqual(record?.modelId, "gpt-4.1")
    }
}
