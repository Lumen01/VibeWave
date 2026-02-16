import XCTest
import GRDB
@testable import VibeWave
import Foundation

final class SessionServiceTests: XCTestCase {
    var sessionService: SessionService!
    var sessionRepository: SessionRepository!
    var dbPool: DatabasePool!
    var tempDbPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        let dbName = "vibewave-test-\(UUID().uuidString).db"
        tempDbPath = tempDir.appendingPathComponent(dbName).path

        dbPool = try! DatabasePool(path: tempDbPath)

        try! dbPool.write { db in
            try DatabaseRepository.createTables(on: db)
        }

        sessionRepository = SessionRepository(dbPool: dbPool)
        sessionService = SessionService(dbPool: dbPool)
    }

    override func tearDown() {
        if let path = tempDbPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        dbPool = nil
        sessionRepository = nil
        sessionService = nil
        super.tearDown()
    }

    func testRecalculateSessions_ForSingleSession_RebuildsSession() throws {
        let sessionId = "test-session-1"
        let now = Date()

        let messageTime1 = MessageTime(created: ISO8601DateFormatter().string(from: now), completed: nil)
        let messageTime2 = MessageTime(created: ISO8601DateFormatter().string(from: now.addingTimeInterval(60)), completed: nil)

        let tokens1 = Tokens(input: 100, output: 200, reasoning: nil, cacheRead: 0, cacheWrite: 0)
        let tokens2 = Tokens(input: 150, output: 250, reasoning: nil, cacheRead: 0, cacheWrite: 0)

        let message1 = Message(
            id: "msg1",
            sessionID: sessionId,
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

        let message2 = Message(
            id: "msg2",
            sessionID: sessionId,
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
            tokens: tokens2,
            cost: 0.02
        )

        try dbPool.write { db in
            let insertSQL = """
                INSERT INTO messages (id, session_id, role, created_at, provider_id, model_id, agent, mode, variant, project_root, project_cwd, token_input, token_output, token_reasoning, cache_read, cache_write, cost, summary_title, summary_total_additions, summary_total_deletions, summary_file_count, finish, diff_files)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

            let args1: StatementArguments = [
                "msg1", sessionId, "user", now.timeIntervalSince1970, "provider1", "model1", nil, nil, nil, nil, nil, "100", "200", nil, 0, 0, 0.01, nil, 0, 0, 0, nil, nil
            ]

            let args2: StatementArguments = [
                "msg2", sessionId, "assistant", now.addingTimeInterval(60).timeIntervalSince1970, "provider1", "model1", nil, nil, nil, nil, nil, "150", "250", nil, 0, 0, 0.02, nil, 0, 0, 0, nil, nil
            ]

            try db.execute(sql: insertSQL, arguments: args1)
            try db.execute(sql: insertSQL, arguments: args2)
        }

        try sessionService.recalculateSessions(for: [sessionId])

        let session = sessionRepository.fetch(by: sessionId)
        XCTAssertNotNil(session, "Session should exist after recalculation")
        let totalMsgCount = (session?.userMsgCount ?? 0) + (session?.agentMsgCount ?? 0)
        XCTAssertEqual(totalMsgCount, 2, "Session should have 2 messages")
        XCTAssertEqual(session?.totalInputTokens, 250, "Total input tokens should be 250")
        XCTAssertEqual(session?.totalOutputTokens, 450, "Total output tokens should be 450")
        XCTAssertEqual(session?.totalCost ?? 0.0, 0.03, accuracy: 0.0001, "Total cost should be 0.03")
    }

    func testRecalculateSessions_ForMultipleSessions_RebuildsOnlySpecifiedSessions() throws {
        let session1Id = "test-session-1"
        let session2Id = "test-session-2"
        let now = Date()

        let messageTime1 = MessageTime(created: ISO8601DateFormatter().string(from: now), completed: nil)
        let messageTime2 = MessageTime(created: ISO8601DateFormatter().string(from: now.addingTimeInterval(60)), completed: nil)

        let tokens1 = Tokens(input: 100, output: 200, reasoning: nil, cacheRead: 0, cacheWrite: 0)
        let tokens2 = Tokens(input: 150, output: 250, reasoning: nil, cacheRead: 0, cacheWrite: 0)

        let message1 = Message(
            id: "msg1",
            sessionID: session1Id,
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

        let message2 = Message(
            id: "msg2",
            sessionID: session2Id,
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
            tokens: tokens2,
            cost: 0.02
        )

        try dbPool.write { db in
            let insertSQL = """
                INSERT INTO messages (id, session_id, role, created_at, provider_id, model_id, agent, mode, variant, project_root, project_cwd, token_input, token_output, token_reasoning, cache_read, cache_write, cost, summary_title, summary_total_additions, summary_total_deletions, summary_file_count, finish, diff_files)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

            let args1: StatementArguments = [
                "msg1", session1Id, "user", now.timeIntervalSince1970, "provider1", "model1", nil, nil, nil, nil, nil, "100", "200", nil, 0, 0, 0.01, nil, 0, 0, 0, nil, nil
            ]

            let args2: StatementArguments = [
                "msg2", session2Id, "assistant", now.addingTimeInterval(60).timeIntervalSince1970, "provider1", "model1", nil, nil, nil, nil, nil, "150", "250", nil, 0, 0, 0.02, nil, 0, 0, 0, nil, nil
            ]

            try db.execute(sql: insertSQL, arguments: args1)
            try db.execute(sql: insertSQL, arguments: args2)
        }

        try sessionService.recalculateSessions(for: [session1Id])

        let session1 = sessionRepository.fetch(by: session1Id)
        let session2 = sessionRepository.fetch(by: session2Id)

        XCTAssertNotNil(session1, "Session1 should exist after recalculation")
        XCTAssertNil(session2, "Session2 should NOT exist (not recalculated)")
    }

    func testRebuildAllSessions_WhenMessagesExist_RebuildsAllSessions() throws {
        let session1Id = "test-session-1"
        let session2Id = "test-session-2"
        let now = Date()

        let messageTime1 = MessageTime(created: ISO8601DateFormatter().string(from: now), completed: nil)
        let messageTime2 = MessageTime(created: ISO8601DateFormatter().string(from: now.addingTimeInterval(60)), completed: nil)

        let tokens1 = Tokens(input: 100, output: 200, reasoning: nil, cacheRead: 0, cacheWrite: 0)
        let tokens2 = Tokens(input: 150, output: 250, reasoning: nil, cacheRead: 0, cacheWrite: 0)

        let message1 = Message(
            id: "msg1",
            sessionID: session1Id,
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

        let message2 = Message(
            id: "msg2",
            sessionID: session2Id,
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
            tokens: tokens2,
            cost: 0.02
        )

        try dbPool.write { db in
            let insertSQL = """
                INSERT INTO messages (id, session_id, role, created_at, provider_id, model_id, agent, mode, variant, project_root, project_cwd, token_input, token_output, token_reasoning, cache_read, cache_write, cost, summary_title, summary_total_additions, summary_total_deletions, summary_file_count, finish, diff_files)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

            let args1: StatementArguments = [
                "msg1", session1Id, "user", now.timeIntervalSince1970, "provider1", "model1", nil, nil, nil, nil, nil, "100", "200", nil, 0, 0, 0.01, nil, 0, 0, 0, nil, nil
            ]

            let args2: StatementArguments = [
                "msg2", session2Id, "assistant", now.addingTimeInterval(60).timeIntervalSince1970, "provider1", "model1", nil, nil, nil, nil, nil, "150", "250", nil, 0, 0, 0.02, nil, 0, 0, 0, nil, nil
            ]

            try db.execute(sql: insertSQL, arguments: args1)
            try db.execute(sql: insertSQL, arguments: args2)
        }

        try sessionService.rebuildAllSessions()

        let session1 = sessionRepository.fetch(by: session1Id)
        let session2 = sessionRepository.fetch(by: session2Id)
        let allSessions = sessionRepository.fetchAll()

        XCTAssertNotNil(session1, "Session1 should exist after rebuild")
        XCTAssertNotNil(session2, "Session2 should exist after rebuild")
        XCTAssertEqual(allSessions.count, 2, "Should have exactly 2 sessions")
    }

    func testDeleteSession_WhenSessionExists_DeletesMessagesAndSession() throws {
        let sessionId = "test-session-1"
        let now = Date()

        let messageTime1 = MessageTime(created: ISO8601DateFormatter().string(from: now), completed: nil)
        let messageTime2 = MessageTime(created: ISO8601DateFormatter().string(from: now.addingTimeInterval(60)), completed: nil)

        let tokens1 = Tokens(input: 100, output: 200, reasoning: nil, cacheRead: 0, cacheWrite: 0)
        let tokens2 = Tokens(input: 150, output: 250, reasoning: nil, cacheRead: 0, cacheWrite: 0)

        let message1 = Message(
            id: "msg1",
            sessionID: sessionId,
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

        let message2 = Message(
            id: "msg2",
            sessionID: sessionId,
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
            tokens: tokens2,
            cost: 0.02
        )

        try dbPool.write { db in
            let insertSQL = """
                INSERT INTO messages (id, session_id, role, created_at, provider_id, model_id, agent, mode, variant, project_root, project_cwd, token_input, token_output, token_reasoning, cache_read, cache_write, cost, summary_title, summary_total_additions, summary_total_deletions, summary_file_count, finish, diff_files)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

            let args1: StatementArguments = [
                "msg1", sessionId, "user", now.timeIntervalSince1970, "provider1", "model1", nil, nil, nil, nil, nil, "100", "200", nil, 0, 0, 0.01, nil, 0, 0, 0, nil, nil
            ]

            let args2: StatementArguments = [
                "msg2", sessionId, "assistant", now.addingTimeInterval(60).timeIntervalSince1970, "provider1", "model1", nil, nil, nil, nil, nil, "150", "250", nil, 0, 0, 0.02, nil, 0, 0, 0, nil, nil
            ]

            try db.execute(sql: insertSQL, arguments: args1)
            try db.execute(sql: insertSQL, arguments: args2)
        }

        try sessionService.recalculateSessions(for: [sessionId])

        XCTAssertNotNil(sessionRepository.fetch(by: sessionId), "Session should exist before deletion")

        try sessionService.deleteSession(sessionId: sessionId)

        let session = sessionRepository.fetch(by: sessionId)
        XCTAssertNil(session, "Session should be deleted")

        let messageCount: Int = try! dbPool.read { db in
            try! Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE session_id = ?", arguments: [sessionId]) ?? 0
        }
        XCTAssertEqual(messageCount, 0, "All messages for session should be deleted")
    }
}
