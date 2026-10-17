import XCTest
import GRDB
@testable import VibeWave

final class OpenCodeV2SyncTests: XCTestCase {
    private var source: DatabaseQueue!
    private var target: DatabasePool!
    private var directory: URL!
    private var url: URL!
    private var service: OpenCodeDatabaseSyncService!
    private var states: [OpenCodeSourceState] = []
    private let time: Int64 = 1_792_100_000_000

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("custom-opencode.db")
        source = try DatabaseQueue(path: url.path)
        target = try DatabasePool(path: directory.appendingPathComponent("target.db").path)
        try writeTarget { try DatabaseRepository.bootstrapSchema(on: $0) }
        service = OpenCodeDatabaseSyncService(sourceDatabaseURL: url, dbPool: target,
            syncMetadataRepo: SyncMetadataRepository(dbPool: target), messageRepo: MessageRepository(dbPool: target),
            sessionService: SessionService(dbPool: target), parser: OpenCodeMessageParser(),
            report: { [weak self] in self?.states.append($0) })
    }

    override func tearDownWithError() throws {
        service = nil
        try source.close()
        try target.close()
        source = nil
        target = nil
        try FileManager.default.removeItem(at: directory)
    }

    private func writeSource(_ body: (Database) throws -> Void) throws {
        try source.write(body)
    }
    private func writeTarget(_ body: (Database) throws -> Void) throws {
        try target.write(body)
    }

    private func schema() throws {
        try writeSource { db in
            try db.execute(sql: """
                CREATE TABLE project(id TEXT PRIMARY KEY, worktree TEXT);
                INSERT INTO project VALUES ('project', '/projects/TestProject');
                CREATE TABLE session_v2(id TEXT PRIMARY KEY, project_id TEXT, directory TEXT, title TEXT,
                    fork_session_id TEXT, time_created INTEGER, time_updated INTEGER, cost REAL,
                    tokens_input INTEGER, tokens_output INTEGER, tokens_reasoning INTEGER,
                    tokens_cache_read INTEGER, tokens_cache_write INTEGER,
                    summary_additions INTEGER DEFAULT 4, summary_deletions INTEGER DEFAULT 2,
                    summary_files INTEGER DEFAULT 1, summary_diffs TEXT);
                CREATE TABLE session_message(id TEXT PRIMARY KEY, session_id TEXT, type TEXT, seq INTEGER,
                    time_created INTEGER, time_updated INTEGER, data TEXT);
                CREATE TABLE event(id TEXT PRIMARY KEY, aggregate_id TEXT, seq INTEGER, created INTEGER, type TEXT, data TEXT);
                CREATE TABLE event_sequence(aggregate_id TEXT PRIMARY KEY, seq INTEGER);
                CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT);
                """)
        }
    }

    private func session(_ id: String = "session", cost: Double = 1, input: Int = 100, fork: String? = nil) throws {
        try writeSource { db in
            try db.execute(sql: """
                INSERT INTO session_v2 (id, project_id, directory, title, fork_session_id, time_created, time_updated,
                    cost, tokens_input, tokens_output, tokens_reasoning, tokens_cache_read, tokens_cache_write)
                VALUES (?, 'project', '/projects/TestProject/subdir', 'Example session', ?, ?, ?, ?, ?, 20, 3, 5, 2)
                """, arguments: [id, fork, time, time + 1000, cost, input])
            try db.execute(sql: "INSERT INTO event_sequence VALUES (?, 0)", arguments: [id])
        }
    }

    private func json(_ object: [String: Any]) throws -> String {
        String(data: try JSONSerialization.data(withJSONObject: object, options: .sortedKeys), encoding: .utf8)!
    }
    private var model: [String: Any] { ["id": "model-v2", "providerID": "provider", "variant": "high"] }
    private func usage(_ input: Int = 100) -> [String: Any] {
        ["input": input, "output": 20, "reasoning": 3, "cache": ["read": 5, "write": 2]]
    }
    private func message(_ id: String, type: String = "assistant", session: String = "session", seq: Int = 1, extra: [String: Any] = [:]) throws {
        var object: [String: Any] = ["time": ["created": time, "streamed": time + 500, "completed": time + 1000]]
        if type == "assistant" { object.merge(["agent": "build", "model": model, "tokens": usage(), "cost": 1.0, "finish": "stop"]) { _, v in v } }
        object.merge(extra) { _, v in v }
        let data = try json(object)
        try writeSource { db in
            try db.execute(sql: "INSERT INTO session_message VALUES (?, ?, ?, ?, ?, ?, ?)", arguments: [id, session, type, seq, time, time, data])
        }
    }
    private func event(_ id: String, type: String, seq: Int, session: String = "session", data: [String: Any]) throws {
        let encoded = try json(data)
        try writeSource { db in
            try db.execute(sql: "INSERT INTO event VALUES (?, ?, ?, ?, ?, ?)", arguments: [id, session, seq, time + Int64(seq), type + (type == "session.forked" ? ".2" : ".1"), encoded])
            try db.execute(sql: "UPDATE event_sequence SET seq = ? WHERE aggregate_id = ?", arguments: [seq, session])
        }
    }
    private func step(_ id: String = "msg_native", session: String = "session", base: Int = 1, input: Int = 100, cost: Double = 1) throws {
        try event("evt_start_" + id, type: "session.step.started", seq: base, session: session,
                  data: ["assistantMessageID": id, "agent": "build", "model": model, "started": time])
        try event("evt_end_" + id, type: "session.step.ended", seq: base + 1, session: session,
                  data: ["assistantMessageID": id, "tokens": usage(input), "cost": cost, "finish": "stop"])
    }
    private func sync() async throws -> SyncProgress { try await service.syncDirectory(at: directory, toolId: "opencode") }
    private func scalar<T: DatabaseValueConvertible>(_ sql: String, as: T.Type = T.self) throws -> T? {
        try target.read { try T.fetchOne($0, sql: sql) }
    }

    func testDormantV2TableDoesNotMisidentifyV1() throws {
        try writeSource { db in
            try db.execute(sql: "CREATE TABLE message(id TEXT, session_id TEXT, data TEXT, time_updated INTEGER); CREATE TABLE session_message(id TEXT)")
        }
        XCTAssertEqual(try source.read { try OpenCodeDatabaseFormat.detect(in: $0) }, .v1)
    }

    func testImportsNativeFieldsAndCountsAccountingOnlyOnce() async throws {
        try schema()
        try session(cost: 1.2, input: 120)
        try message("msg_user", type: "user", seq: 0)
        try message("msg_native")
        try message("msg_idle", type: "idle", seq: 2)
        try message("msg_compaction", type: "compaction", seq: 3, extra: ["tokens": usage(20), "cost": 0.2])
        try step()
        // Title/compaction usage need not be visible transcript messages.
        try event("evt_usage", type: "session.usage.recorded", seq: 3,
                  data: ["source": "compaction", "tokens": ["input": 20, "output": 0, "reasoning": 0, "cache": ["read": 0, "write": 0]], "cost": 0.2])
        let first = try await sync()
        XCTAssertEqual(first.importedFiles, 1)
        XCTAssertEqual(states.last?.kind, .v2)
        let record = MessageRepository(dbPool: target).fetch(by: "msg_native")
        XCTAssertEqual(record?.modelId, "model-v2")
        XCTAssertEqual(record?.providerId, "provider")
        XCTAssertEqual(record?.variant, "high")
        XCTAssertEqual(record?.completedAt, time + 500)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM messages", as: Double.self), 1.2)
        XCTAssertEqual(try scalar("SELECT SUM(message_count) FROM daily_stats", as: Int.self), 2)
        XCTAssertEqual(try scalar("SELECT SUM(input_tokens) FROM daily_stats", as: Int.self), 120)
        XCTAssertEqual(try scalar("SELECT user_msg_count + agent_msg_count FROM sessions", as: Int.self), 2)
        XCTAssertEqual(try scalar("SELECT project_name FROM sessions", as: String.self), "TestProject")
        XCTAssertEqual(try scalar("SELECT SUM(net_code_lines) FROM daily_stats", as: Int.self), 2)
        let second = try await sync()
        XCTAssertEqual(second.importedFiles, 0)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM messages", as: Double.self), 1.2)
    }

    func testForkDoesNotCountCopiedHistoryAsNewUsageOrActivity() async throws {
        try schema()
        try session("fork", fork: "parent")
        try message("msg_fork_0", type: "user", session: "fork", seq: 0)
        try message("msg_fork_1", session: "fork", seq: 1)
        try message("msg_new", session: "fork", seq: 2)
        try event("evt_fork", type: "session.forked", seq: 0, session: "fork", data: [:])
        try step("msg_new", session: "fork", base: 2)
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM messages", as: Int.self), 1)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1)
    }

    func testRevertedMessageKeepsSpendButRemovesMessageCount() async throws {
        try schema(); try session(); try message("msg_native"); try step()
        _ = try await sync()
        try writeSource { db in
            try db.execute(sql: "DELETE FROM session_message; UPDATE event_sequence SET seq = 3; UPDATE session_v2 SET time_updated = time_updated + 1")
        }
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1)
        XCTAssertEqual(try scalar("SELECT SUM(message_count) FROM daily_stats", as: Int.self), 0)
        XCTAssertEqual(try scalar("SELECT role FROM messages", as: String.self), "usage")
    }

    func testStreamingSettlementUpdatesPreviouslySeenMessage() async throws {
        try schema(); try session(cost: 0, input: 0)
        try writeSource { try $0.execute(sql: "UPDATE session_v2 SET tokens_output = 0, tokens_reasoning = 0, tokens_cache_read = 0, tokens_cache_write = 0") }
        try message("msg_native", extra: ["cost": 0, "tokens": ["input": 0, "output": 0, "reasoning": 0], "time": ["created": time]])
        _ = try await sync()
        try step()
        try writeSource { try $0.execute(sql: "UPDATE session_v2 SET cost = 1, tokens_input = 100, tokens_output = 20, tokens_reasoning = 3, tokens_cache_read = 5, tokens_cache_write = 2") }
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(try scalar("SELECT SUM(input_tokens) FROM daily_stats", as: Int.self), 100)
    }

    func testUnknownMessageTypePausesWithoutAdvancingCheckpoint() async throws {
        try schema(); try session(); try message("msg_native"); try step()
        _ = try await sync()
        let timestamp: Int64? = try scalar("SELECT last_imported_at FROM sync_metadata WHERE file_path LIKE '%#v2'", as: Int64.self)
        try message("msg_future", type: "future-accounting-event", seq: 4)
        do { _ = try await sync(); XCTFail("Must pause on unknown data") } catch {}
        XCTAssertEqual(states.last?.kind, .updateRequired)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM messages", as: Double.self), 1)
        XCTAssertEqual(try scalar("SELECT last_imported_at FROM sync_metadata WHERE file_path LIKE '%#v2'", as: Int64.self), timestamp)
    }

    func testConversionInProgressDoesNotClearExistingStatistics() async throws {
        try schema()
        try writeSource { try $0.execute(sql: "INSERT INTO kv VALUES ('migration.v1-v2', '{\"phase\":\"sessions\"}')") }
        try writeTarget { try $0.execute(sql: "INSERT INTO messages(id, session_id, role, cost) VALUES ('old', 'old-session', 'assistant', 4)") }
        do { _ = try await sync(); XCTFail("Must wait for conversion") } catch {}
        XCTAssertEqual(states.last?.kind, .waiting)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM messages", as: Double.self), 4)
    }

    func testIncompleteAccountingPreservesExistingSessionAndReportsGap() async throws {
        try schema(); try session(cost: 0.5); try message("msg_native")
        try writeTarget { try $0.execute(sql: "INSERT INTO messages(id, session_id, role, cost) VALUES ('old', 'session', 'assistant', 2)") }
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .historyIncomplete)
        XCTAssertEqual(states.last?.missingSessions, 1)
        XCTAssertNil(states.last?.lastSuccess)
        XCTAssertNil(service.lastCompleteSync)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM messages", as: Double.self), 2)
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM sync_metadata", as: Int.self), 0)
    }

    func testUnconvertedV1SessionsRemainVisibleAsIncompleteHistory() async throws {
        try schema(); try session(); try message("msg_native")
        try writeSource { try $0.execute(sql: "CREATE TABLE session(id TEXT); INSERT INTO session VALUES ('v1-only')") }
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .historyIncomplete)
        XCTAssertEqual(states.last?.missingSessions, 1)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM messages", as: Double.self), 1)
    }

    func testMalformedSessionDoesNotPartiallyReplaceOtherSessions() async throws {
        try schema(); try session(); try message("msg_native")
        _ = try await sync()
        try session("second")
        try writeSource { try $0.execute(sql: "INSERT INTO session_message VALUES ('bad', 'second', 'assistant', 0, 1, 1, 'invalid JSON')") }
        do { _ = try await sync(); XCTFail("Malformed source must fail atomically") } catch {}
        XCTAssertEqual(states.last?.kind, .updateRequired)
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM sessions", as: Int.self), 1)
    }

    func testAggregationFailureRollsBackMessagesAndCheckpointsTogether() async throws {
        try schema(); try session(); try message("msg_native")
        try writeTarget { try $0.execute(sql: "CREATE TRIGGER fail_aggregation BEFORE INSERT ON daily_stats BEGIN SELECT RAISE(ABORT, 'test failure'); END") }
        do { _ = try await sync(); XCTFail("Expected aggregate write failure") } catch {}
        XCTAssertEqual(states.last?.kind, .failed)
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM messages", as: Int.self), 0)
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM sync_metadata", as: Int.self), 0)
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM sessions", as: Int.self), 0)
    }

    func testFullResyncRepairsDerivedDataWithoutClearingUnconvertedHistory() async throws {
        try schema(); try session(); try message("msg_native"); try step()
        _ = try await sync()
        try writeTarget { db in
            try db.execute(sql: "DELETE FROM daily_stats; UPDATE messages SET cost = 2")
            try db.execute(sql: "INSERT INTO messages(id, session_id, role, cost) VALUES ('historic', 'v1-only', 'assistant', 3)")
        }
        _ = try await service.resynchronize()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(MessageRepository(dbPool: target).fetch(by: "msg_native")?.cost, 1)
        XCTAssertNotNil(MessageRepository(dbPool: target).fetch(by: "historic"))
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1)
    }

    func testProjectMetadataChangesUpdateExistingStatistics() async throws {
        try schema(); try session(); try message("msg_native")
        _ = try await sync()
        try writeSource { try $0.execute(sql: "UPDATE project SET worktree = '/projects/Renamed'; UPDATE session_v2 SET summary_additions = 10") }
        _ = try await sync()
        XCTAssertEqual(try scalar("SELECT project_name FROM sessions", as: String.self), "Renamed")
        XCTAssertEqual(try scalar("SELECT SUM(net_code_lines) FROM daily_stats", as: Int.self), 8)
    }

    func testHistoryConversionRetainsKnownHiddenV1ConsumptionWithoutDuplication() async throws {
        try schema(); try session(cost: 1.5, input: 105); try message("msg_native")
        try writeTarget { db in
            try db.execute(sql: "INSERT INTO messages(id, session_id, role, created_at, cost, token_input, token_output, token_reasoning, cache_read, cache_write) VALUES ('old-summary', 'session', 'assistant', ?, 0.5, 5, 0, 0, 0, 0)", arguments: [time])
        }
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1.5)
        XCTAssertEqual(try scalar("SELECT SUM(message_count) FROM daily_stats", as: Int.self), 1)
        _ = try await service.resynchronize()
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1.5)
    }

    func testPartialV2ImportKeepsLastSuccessfulV1Timestamp() async throws {
        try schema(); try session(cost: 0.5); try message("msg_native")
        try SyncMetadataRepository(dbPool: target).upsert(SyncMetadataRecord(filePath: url.path, fileHash: "old-cursor", lastImportedAt: time))
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .historyIncomplete)
        XCTAssertEqual(states.last?.lastSuccess, Date(timeIntervalSince1970: Double(time) / 1000))
        XCTAssertEqual(service.lastCompleteSync, states.last?.lastSuccess)
    }

    func testStaleLocalMessagesDoNotBlockConvertedSourceSession() async throws {
        try schema(); try session(); try message("msg_native")
        try writeTarget { db in
            try db.execute(sql: "INSERT INTO messages(id, session_id, role, created_at, cost, token_input, token_output) VALUES ('removed-v1-message', 'session', 'assistant', ?, 0, 535, 17)", arguments: [time])
        }
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertNil(MessageRepository(dbPool: target).fetch(by: "removed-v1-message"))
        XCTAssertEqual(try scalar("SELECT SUM(input_tokens) FROM daily_stats", as: Int.self), 100)
    }

    func testUnpersistedSessionUsageIsReconciledWithoutInventingModelOrMessageCount() async throws {
        try schema(); try session(cost: 1.2, input: 120); try message("msg_native")
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1.2)
        XCTAssertEqual(try scalar("SELECT SUM(input_tokens) FROM daily_stats", as: Int.self), 120)
        XCTAssertEqual(try scalar("SELECT SUM(message_count) FROM daily_stats", as: Int.self), 1)
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM messages WHERE role = 'usage' AND model_id IS NULL AND created_at = \(time)", as: Int.self), 1)
        _ = try await service.resynchronize()
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1.2)
    }

    func testCompactionConsumptionWorksWithoutPersistedEventJournal() async throws {
        try schema(); try session(cost: 1.2, input: 120); try message("msg_native")
        try message("msg_compaction", type: "compaction", seq: 2, extra: ["status": "completed", "cost": 0.2, "model": model,
            "tokens": ["input": 20, "output": 0, "reasoning": 0, "cache": ["read": 0, "write": 0]]])
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM messages WHERE role = 'usage' AND model_id = 'model-v2'", as: Int.self), 1)
        XCTAssertEqual(try scalar("SELECT SUM(input_tokens) FROM daily_stats", as: Int.self), 120)
    }

    func testForkCanBeReadWhenEventJournalIsNotPersisted() async throws {
        try schema(); try session("fork", fork: "parent")
        try message("msg_copied_0", type: "user", session: "fork", seq: 0)
        try message("msg_copied_1", session: "fork", seq: 1)
        try message("msg_own", session: "fork", seq: 3)
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(try scalar("SELECT SUM(message_count) FROM daily_stats", as: Int.self), 1)
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1)
    }

    func testConvertedHiddenUsageComesFromSourceInsteadOfStaleLocalCache() async throws {
        try schema(); try session(cost: 1.5, input: 105); try message("msg_native")
        let summary = try json(["role": "assistant", "providerID": "provider", "modelID": "summary-model",
            "cost": 0.5, "tokens": ["input": 5, "output": 0, "reasoning": 0]])
        try writeSource { db in
            try db.execute(sql: "CREATE TABLE message(id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, data TEXT)")
            try db.execute(sql: "INSERT INTO message VALUES ('source-summary', 'session', ?, ?)", arguments: [time, summary])
        }
        try writeTarget { db in
            try db.execute(sql: "INSERT INTO messages(id, session_id, role, created_at, cost, token_input) VALUES ('stale-cache', 'session', 'assistant', ?, 9, 900)", arguments: [time])
        }
        _ = try await sync()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(states.last?.sessionUsageCount, 0)
        XCTAssertNil(MessageRepository(dbPool: target).fetch(by: "stale-cache"))
        XCTAssertEqual(MessageRepository(dbPool: target).fetch(by: "source-summary")?.modelId, "summary-model")
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1.5)
        XCTAssertEqual(try scalar("SELECT SUM(input_tokens) FROM daily_stats", as: Int.self), 105)
        _ = try await service.resynchronize()
        XCTAssertEqual(try scalar("SELECT SUM(cost) FROM daily_stats", as: Double.self), 1.5)
    }

    /// 仅在显式指定数据源时运行；读取真实源，所有写入均落在测试临时目录。
    func testActualReadOnlySourceReconcilesAllSessionsAndRepeatedSync() async throws {
        guard let sourcePath = ProcessInfo.processInfo.environment["VIBEWAVE_READONLY_V2_SOURCE"] else {
            throw XCTSkip("未指定真实只读数据源")
        }
        var configuration = Configuration()
        configuration.readonly = true
        let actualSource = try DatabaseQueue(path: sourcePath, configuration: configuration)
        let expected = try await actualSource.read { db in
            try Row.fetchAll(db, sql: "SELECT id, cost, tokens_input, tokens_output, tokens_reasoning, tokens_cache_read, tokens_cache_write FROM session_v2 ORDER BY id")
        }
        let importer = OpenCodeDatabaseSyncService(sourceDatabaseURL: URL(fileURLWithPath: sourcePath), dbPool: target,
            syncMetadataRepo: SyncMetadataRepository(dbPool: target), messageRepo: MessageRepository(dbPool: target),
            sessionService: SessionService(dbPool: target), parser: OpenCodeMessageParser(),
            report: { [weak self] in self?.states.append($0) })
        _ = try await importer.syncDirectory(at: directory, toolId: "opencode")
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(states.last?.missingSessions, 0)
        let targetColumns = ["token_input", "token_output", "token_reasoning", "cache_read", "cache_write"]
        let sourceColumns = ["tokens_input", "tokens_output", "tokens_reasoning", "tokens_cache_read", "tokens_cache_write"]
        let aggregateColumns = ["input_tokens", "output_tokens", "reasoning_tokens", "cache_read", "cache_write"]
        let actual = try await target.read { db in
            try Row.fetchAll(db, sql: "SELECT session_id, SUM(cost) AS cost, SUM(token_input) AS token_input, SUM(token_output) AS token_output, SUM(token_reasoning) AS token_reasoning, SUM(cache_read) AS cache_read, SUM(cache_write) AS cache_write FROM messages GROUP BY session_id")
        }
        let indexed = Dictionary(uniqueKeysWithValues: actual.map { ($0["session_id"] as String, $0) })
        var totals = [Int64](repeating: 0, count: 5)
        var totalCost: Double = 0
        for row in expected {
            let id: String = row["id"]
            let actualCost = (indexed[id]?["cost"] as Double?) ?? 0
            let expectedCost: Double = row["cost"]
            XCTAssertEqual(actualCost, expectedCost, accuracy: 0.000001)
            totalCost += expectedCost
            for i in targetColumns.indices {
                let value = (indexed[id]?[targetColumns[i]] as Int64?) ?? 0
                let expectedValue: Int64 = row[sourceColumns[i]]
                XCTAssertEqual(value, expectedValue)
                totals[i] += expectedValue
            }
        }
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM sessions", as: Int.self), expected.count)
        for table in ["hourly_stats", "daily_stats", "monthly_stats"] {
            XCTAssertEqual(try XCTUnwrap(scalar("SELECT SUM(cost) FROM \(table)", as: Double.self)), totalCost, accuracy: 0.000001)
            for i in aggregateColumns.indices {
                XCTAssertEqual(try scalar("SELECT SUM(\(aggregateColumns[i])) FROM \(table)", as: Int64.self), totals[i])
            }
        }
        let firstCount: Int? = try scalar("SELECT COUNT(*) FROM messages", as: Int.self)
        _ = try await importer.resynchronize()
        XCTAssertEqual(states.last?.kind, .v2)
        XCTAssertEqual(try scalar("SELECT COUNT(*) FROM messages", as: Int.self), firstCount)
        XCTAssertEqual(try XCTUnwrap(scalar("SELECT SUM(cost) FROM messages", as: Double.self)), totalCost, accuracy: 0.000001)
        print("真实只读数据验收：\(expected.count) 个会话；消息、小时/日/月汇总与五类 Token 全部核对通过；重复同步不增加消耗。")
    }

    func testSourceIsOpenedReadOnly() throws {
        let readonly = try service.openSource()
        XCTAssertThrowsError(try readonly.write { try $0.execute(sql: "CREATE TABLE must_not_write(id TEXT)") })
    }
}
