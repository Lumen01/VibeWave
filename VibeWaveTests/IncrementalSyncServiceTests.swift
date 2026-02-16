import XCTest
@testable import VibeWave
import Foundation
import GRDB

final class IncrementalSyncServiceTests: XCTestCase {
    var syncService: IncrementalSyncService!
    var syncMetadataRepo: SyncMetadataRepository!
    var messageRepo: MessageRepository!
    var sessionService: SessionService!
    var dbPool: DatabasePool!

    var testFile: URL!

    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory

        let tempDBFile = tempDir.appendingPathComponent("test_sync-\(UUID().uuidString).db")
        tempDBPath = tempDBFile.path
        dbPool = try! DatabasePool(path: tempDBFile.path)

        try! dbPool.write { db in
            try DatabaseRepository.createTables(on: db)
        }

        syncMetadataRepo = SyncMetadataRepository(dbPool: dbPool)
        messageRepo = MessageRepository(dbPool: dbPool)
        sessionService = SessionService(dbPool: dbPool)

        let parser = OpenCodeMessageParser()

        syncService = IncrementalSyncService(
            dbPool: dbPool,
            syncMetadataRepo: syncMetadataRepo,
            messageRepo: messageRepo,
            sessionService: sessionService,
            parser: parser
        )

        testFile = tempDir.appendingPathComponent("test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: testFile.path) {
            try? FileManager.default.removeItem(atPath: testFile.path)
        }
        dbPool = nil
        syncMetadataRepo = nil
        messageRepo = nil
        sessionService = nil
        syncService = nil
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: path + "-wal")
            try? FileManager.default.removeItem(atPath: path + "-shm")
        }
        super.tearDown()
    }

    func testSyncFile_WhenFileNew_ImportsMessages() async throws {
        let now = Date()
        let messageTime = MessageTime(created: ISO8601DateFormatter().string(from: now), completed: nil)
        let tokens = Tokens(input: 100, output: 200, reasoning: nil, cacheRead: 0, cacheWrite: 0)

        let message = Message(
            id: "msg1",
            sessionID: "session-1",
            role: "user",
            time: messageTime,
            parentID: nil,
            providerID: "provider1",
            modelID: "model1",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: tokens,
            cost: 0.01
        )

        let messageData = try JSONEncoder().encode(message)
        try messageData.write(to: testFile)

        let (importedCount, affectedSessionIds, toolId) = try await syncService.syncFile(at: testFile)

        XCTAssertEqual(importedCount, 1, "Should import 1 message")
        XCTAssertEqual(affectedSessionIds, ["session-1"], "Should include session-1")
        XCTAssertEqual(toolId, "opencode", "Tool ID should be opencode")
    }

    func testSyncFile_WhenFileModified_UpdatesMessagesAndMetadata() async throws {
        let now = Date()
        let messageTime = MessageTime(created: ISO8601DateFormatter().string(from: now), completed: nil)
        let tokens = Tokens(input: 200, output: 300, reasoning: nil, cacheRead: 0, cacheWrite: 0)

        let message = Message(
            id: "msg2",
            sessionID: "session-1",
            role: "user",
            time: messageTime,
            parentID: nil,
            providerID: "provider1",
            modelID: "model1",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: tokens,
            cost: 0.02
        )

        let messageData = try JSONEncoder().encode([message])
        try messageData.write(to: testFile)
        
        // Debug info
        print("📄 Written message to testFile: \(testFile.path)")
        print("📄 File exists: \(FileManager.default.fileExists(atPath: testFile.path))")
        let readData = try Data(contentsOf: testFile)
        print("📄 Read data length: \(readData.count)")
        if let jsonStr = String(data: readData, encoding: .utf8) {
            print("📄 JSON: \(jsonStr)")
        }

        let (importedCount, affectedSessionIds, toolId) = try await syncService.syncFile(at: testFile)
        
        print("🔢 Imported count: \(importedCount)")
        print("🔢 Affected session IDs: \(affectedSessionIds)")
print("🔧 Tool ID: \(toolId)")

        XCTAssertEqual(importedCount, 1, "Should import 1 message")
        
        let metadata = syncMetadataRepo.fetch(filePath: testFile.path)
        print("💾 Metadata: \(String(describing: metadata))")
        
        XCTAssertNotNil(metadata, "Metadata should exist")
        XCTAssertEqual(metadata?.messageCount, 1, "Metadata should have 1 message")
        XCTAssertEqual(metadata?.toolId, "opencode", "Tool ID should be opencode")
    }
    
    func testSyncFile_WhenFileUnchanged_SkipsImport() async throws {
        let now = Date()
        let messageTime = MessageTime(created: ISO8601DateFormatter().string(from: now), completed: nil)
        let tokens = Tokens(input: 100, output: 200, reasoning: nil, cacheRead: 0, cacheWrite: 0)

        let message = Message(
            id: "msg3",
            sessionID: "session-3",
            role: "user",
            time: messageTime,
            parentID: nil,
            providerID: "provider1",
            modelID: "model1",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: tokens,
            cost: 0.01
        )

        let messageData = try JSONEncoder().encode(message)
        try messageData.write(to: testFile)

        // First sync
        let (firstCount, firstSessions, _) = try await syncService.syncFile(at: testFile)
        XCTAssertEqual(firstCount, 1, "First import should have 1 message")
        
        // Second sync - should skip
        let (secondCount, secondSessions, _) = try await syncService.syncFile(at: testFile)
        XCTAssertEqual(secondCount, 0, "Second import should skip unchanged file")
        XCTAssertTrue(secondSessions.isEmpty, "No sessions affected for unchanged file")
    }

    func testSyncFile_WhenTimeIsMilliseconds_MetadataTimesSet() async throws {
        let timestampMs = Int(Date().timeIntervalSince1970 * 1000)
        let json = """
        {
          "id": "msg-ms-1",
          "sessionID": "session-ms",
          "role": "user",
          "time": { "created": \(timestampMs) },
          "model": { "providerID": "provider1", "modelID": "model1" }
        }
        """

        try json.data(using: .utf8)!.write(to: testFile)

        let (importedCount, _, _) = try await syncService.syncFile(at: testFile)
        XCTAssertEqual(importedCount, 1, "Should import 1 message")

        let metadata = syncMetadataRepo.fetch(filePath: testFile.path)
        XCTAssertNotNil(metadata?.firstMessageTime, "First message time should be set")
        XCTAssertNotNil(metadata?.lastMessageTime, "Last message time should be set")
        XCTAssertEqual(metadata?.firstMessageTime, metadata?.lastMessageTime, "Single message should set equal first/last time")

        if let first = metadata?.firstMessageTime {
            XCTAssertEqual(Int(first), timestampMs / 1000, "Metadata time should match millisecond timestamp")
        }
    }

    func testSyncDirectory_WhenMultipleFiles_ImportsAllMessages() async throws {
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_dir")
        try? FileManager.default.removeItem(at: testDir)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let now = Date()

        let messageTime1 = MessageTime(created: ISO8601DateFormatter().string(from: now), completed: nil)
        let tokens1 = Tokens(input: 100, output: 200, reasoning: nil, cacheRead: 0, cacheWrite: 0)

        let message1 = Message(
            id: "msg1",
            sessionID: "session-1",
            role: "user",
            time: messageTime1,
            parentID: nil,
            providerID: "provider1",
            modelID: "model1",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: tokens1,
            cost: 0.01
        )

        let messageTime2 = MessageTime(created: ISO8601DateFormatter().string(from: now.addingTimeInterval(60)), completed: nil)
        let tokens2 = Tokens(input: 150, output: 250, reasoning: nil, cacheRead: 0, cacheWrite: 0)

        let message2 = Message(
            id: "msg2",
            sessionID: "session-2",
            role: "user",
            time: messageTime2,
            parentID: nil,
            providerID: "provider1",
            modelID: "model1",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: tokens2,
            cost: 0.02
        )

        let file1 = testDir.appendingPathComponent("session1.json")
        let file2 = testDir.appendingPathComponent("session2.json")

        try JSONEncoder().encode([message1]).write(to: file1)
        try JSONEncoder().encode([message2]).write(to: file2)

        let progress = try await syncService.syncDirectory(at: testDir)

        XCTAssertEqual(progress.totalFiles, 2, "Should process 2 files")
        XCTAssertEqual(progress.importedFiles, 2, "Should import 2 files")
        XCTAssertEqual(progress.skippedFiles, 0, "Should skip 0 files")
        
        defer {
            try? FileManager.default.removeItem(at: testDir)
        }
    }
    
    func testSyncDirectory_WhenNonJsonFiles_SkipsThem() async throws {
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_dir_skip")
        try? FileManager.default.removeItem(at: testDir)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let message = Message(
            id: "msg1",
            sessionID: "session-1",
            role: "user",
            time: MessageTime(created: ISO8601DateFormatter().string(from: Date()), completed: nil),
            parentID: nil,
            providerID: "provider1",
            modelID: "model1",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: Tokens(input: 100, output: 200, reasoning: nil, cacheRead: 0, cacheWrite: 0),
            cost: 0.01
        )

        let jsonFile = testDir.appendingPathComponent("valid.json")
        let txtFile = testDir.appendingPathComponent("invalid.txt")
        
        try JSONEncoder().encode(message).write(to: jsonFile)
        try "plain text".write(to: txtFile, atomically: true, encoding: .utf8)

        let progress = try await syncService.syncDirectory(at: testDir)

        XCTAssertEqual(progress.totalFiles, 2, "Should process 2 files")
        XCTAssertEqual(progress.importedFiles, 1, "Should import 1 JSON file")
        XCTAssertEqual(progress.skippedFiles, 1, "Should skip 1 non-JSON file")
        XCTAssertEqual(progress.skippedFilePaths.count, 1, "Should track skipped file path")
        
        defer {
            try? FileManager.default.removeItem(at: testDir)
        }
    }

    func testSyncFiles_WhenMultipleFiles_ImportsMessages() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let file1 = tempDir.appendingPathComponent("batch_sync_1.json")
        let file2 = tempDir.appendingPathComponent("batch_sync_2.json")

        let now = Date()
        let messageTime1 = MessageTime(created: ISO8601DateFormatter().string(from: now), completed: nil)
        let messageTime2 = MessageTime(created: ISO8601DateFormatter().string(from: now.addingTimeInterval(60)), completed: nil)

        let message1 = Message(
            id: "batch-msg-1",
            sessionID: "batch-session-1",
            role: "user",
            time: messageTime1,
            parentID: nil,
            providerID: "provider1",
            modelID: "model1",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: Tokens(input: 10, output: 20, reasoning: nil, cacheRead: 0, cacheWrite: 0),
            cost: 0.01
        )

        let message2 = Message(
            id: "batch-msg-2",
            sessionID: "batch-session-2",
            role: "assistant",
            time: messageTime2,
            parentID: nil,
            providerID: "provider1",
            modelID: "model1",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: Tokens(input: 30, output: 40, reasoning: nil, cacheRead: 0, cacheWrite: 0),
            cost: 0.02
        )

        try JSONEncoder().encode([message1]).write(to: file1)
        try JSONEncoder().encode([message2]).write(to: file2)

        let (importedCount, affectedSessions, toolId) = try await syncService.syncFiles(at: [file1, file2])

        XCTAssertEqual(importedCount, 2)
        XCTAssertEqual(affectedSessions, ["batch-session-1", "batch-session-2"])
        XCTAssertEqual(toolId, "opencode")

        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
        }
    }

    func testSyncDirectory_UsesDataParserForBulkImport() async throws {
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_dir_bulk_data_\(UUID().uuidString)")
        try? FileManager.default.removeItem(at: testDir)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let file1 = testDir.appendingPathComponent("bulk_1.json")
        let file2 = testDir.appendingPathComponent("bulk_2.json")
        try "{}".data(using: .utf8)!.write(to: file1)
        try "{}".data(using: .utf8)!.write(to: file2)

        let parser = CountingMessageParser()
        let service = IncrementalSyncService(
            dbPool: dbPool,
            syncMetadataRepo: syncMetadataRepo,
            messageRepo: messageRepo,
            sessionService: sessionService,
            parser: parser
        )

        _ = try await service.syncDirectory(at: testDir)

        XCTAssertEqual(parser.dataCalls, 2, "Bulk import should parse from data for each file")
        XCTAssertEqual(parser.urlCalls, 0, "Bulk import should avoid URL-based parsing")

        defer {
            try? FileManager.default.removeItem(at: testDir)
        }
    }
}

private final class CountingMessageParser: MessageParsing {
    private(set) var urlCalls = 0
    private(set) var dataCalls = 0

    func parseMessages(from url: URL) -> ParseResult {
        urlCalls += 1
        return ParseResult(messages: [makeMessage(for: url)], affectedSessionIds: [makeSessionId(for: url)])
    }

    func parseMessages(from data: Data, sourceURL: URL) -> ParseResult {
        dataCalls += 1
        return ParseResult(messages: [makeMessage(for: sourceURL)], affectedSessionIds: [makeSessionId(for: sourceURL)])
    }

    private func makeSessionId(for url: URL) -> String {
        "session-\(url.lastPathComponent)"
    }

    private func makeMessage(for url: URL) -> Message {
        Message(
            id: "msg-\(url.lastPathComponent)",
            sessionID: makeSessionId(for: url),
            role: "user",
            time: MessageTime(created: ISO8601DateFormatter().string(from: Date()), completed: nil),
            parentID: nil,
            providerID: "provider1",
            modelID: "model1",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: Tokens(input: 1, output: 1, reasoning: nil, cacheRead: 0, cacheWrite: 0),
            cost: 0.0
        )
    }
}
