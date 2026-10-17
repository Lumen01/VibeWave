import Foundation
import CryptoKit
import GRDB

/// v2 会话累计值是消耗核对依据；事件日志默认不持久化，不能作为必需数据。
/// 所有历史明细均从 OpenCode 只读源生成，不能把 App 缓存当成额外消耗。
final class OpenCodeV2SyncService {
    struct Result {
        let changedCount: Int
        let affectedSessions: Set<String>
        let incompleteCount: Int
    }
    private struct Model: Decodable {
        let id: String
        let providerID: String
        let variant: String?
    }
    private struct Time: Decodable {
        let created: Int64
        let streamed: Int64?
        let completed: Int64?
    }
    private struct Payload: Decodable {
        let agent: String?
        let model: Model?
        let tokens: Tokens?
        let cost: Double?
        let time: Time
        let finish: String?
    }
    private struct EventPayload: Decodable {
        let assistantMessageID: String?
        let agent: String?
        let model: Model?
        let started: Int64?
        let tokens: Tokens?
        let cost: Double?
        let finish: String?
        let source: String?
    }
    private struct PreparedSession {
        let source: Row
        let fingerprint: String
        let messages: [Message]
    }

    private let pool: DatabasePool
    private let path: String
    private let report: (OpenCodeSourceState) -> Void
    private let decoder = JSONDecoder()

    init(pool: DatabasePool, path: String, report: @escaping (OpenCodeSourceState) -> Void) {
        self.pool = pool
        self.path = path
        self.report = report
    }

    func sync(source: DatabaseQueue, force: Bool = false) throws -> Result {
        let metadata = SyncMetadataRepository(dbPool: pool)
        let prefix = path + "#v2/session/"
        let previous = Dictionary(uniqueKeysWithValues: metadata.fetchAll(toolId: "opencode")
            .filter { $0.filePath.hasPrefix(prefix) }.map { (String($0.filePath.dropFirst(prefix.count)), $0) })
        let lastSuccessfulImport = metadata.fetch(filePath: path + "#v2") ?? metadata.fetch(filePath: path)
        let lastSuccess = lastSuccessfulImport.map { Date(timeIntervalSince1970: Double($0.lastImportedAt) / 1000) }
        var prepared: [PreparedSession] = []
        var incomplete = 0
        var allIDs = Set<String>()

        // One SQLite read transaction fixes the source snapshot for the entire run.
        try source.read { db in
            let sessions = try Row.fetchAll(db, sql: """
                SELECT s.*, p.worktree AS project_root,
                    COALESCE(e.seq, -1) AS event_seq,
                    (SELECT MAX(time_updated) FROM session_message WHERE session_id = s.id) AS message_updated,
                    (SELECT COUNT(*) FROM session_message WHERE session_id = s.id) AS message_count
                FROM session_v2 s LEFT JOIN project p ON p.id = s.project_id
                LEFT JOIN event_sequence e ON e.aggregate_id = s.id
                ORDER BY s.time_created, s.id
                """)
            allIDs = Set(sessions.map { $0["id"] as String })
            if try db.tableExists("session") {
                incomplete += try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM session s
                    WHERE NOT EXISTS(SELECT 1 FROM session_v2 v WHERE v.id = s.id)
                    """) ?? 0
            }
            for (index, session) in sessions.enumerated() {
                let id: String = session["id"]
                // Includes event sequence, row count and message update time, so a
                // deletion or settled streaming update cannot hide behind an ID cursor.
                let fingerprint = SHA256.hash(data: Data(("source-accounting-2|" + session.description).utf8))
                    .map { String(format: "%02x", $0) }.joined()
                if force || previous[id]?.fileHash != fingerprint {
                    let rows = try Row.fetchAll(db, sql: "SELECT * FROM session_message WHERE session_id = ? ORDER BY seq", arguments: [id])
                    let events = try Row.fetchAll(db, sql: "SELECT * FROM event WHERE aggregate_id = ? ORDER BY seq", arguments: [id])
                    let history = try db.tableExists("message")
                        ? Row.fetchAll(db, sql: "SELECT id, session_id, time_created, data FROM message WHERE session_id = ?", arguments: [id])
                        : []
                    var messages = try normalize(session: session, rows: rows, events: events, history: history)
                    guard reconcileAccounting(session, messages: &messages) else {
                        incomplete += 1
                        continue
                    }
                    prepared.append(PreparedSession(source: session, fingerprint: fingerprint, messages: messages))
                }
                if !prepared.isEmpty && (index % 25 == 0 || index + 1 == sessions.count) {
                    report(OpenCodeSourceState(kind: .connecting, completedSessions: index + 1,
                                               totalSessions: sessions.count, lastSuccess: lastSuccess))
                }
            }
        }

        let deleted = Set(previous.filter { $0.value.isFileExists }.keys).subtracting(allIDs)
        let affected = Set(prepared.map { $0.source["id"] as String }).union(deleted)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        // Messages, sessions, all chart buckets and checkpoint commit together. Readers
        // keep seeing the previous committed snapshot if preparation or writes fail.
        try pool.write { db in
            let messageRepo = MessageRepository(dbPool: self.pool)
            let affectedList = Array(affected)
            let placeholders = affectedList.map { _ in "?" }.joined(separator: ",")
            func bounds() throws -> (Int64, Int64)? {
                guard !affectedList.isEmpty,
                      let row = try Row.fetchOne(db, sql: "SELECT MIN(created_at) AS lo, MAX(created_at) AS hi FROM messages WHERE session_id IN (\(placeholders))", arguments: StatementArguments(affectedList)),
                      let lo = row["lo"] as Int64?, let hi = row["hi"] as Int64? else { return nil }
                return (lo, hi)
            }
            let oldBounds = try bounds()
            for item in prepared {
                let id: String = item.source["id"]
                try db.execute(sql: "DELETE FROM messages WHERE session_id = ? AND COALESCE(tool_id, 'opencode') = 'opencode'", arguments: [id])
                try messageRepo.insert(messages: item.messages, in: db)
                try metadata.upsert(SyncMetadataRecord(filePath: prefix + id, toolId: "opencode",
                    fileHash: item.fingerprint, lastImportedAt: now, messageCount: Int64(item.messages.count)), in: db)
            }
            for id in deleted {
                // A source deletion must remove transcript counts without erasing money
                // already spent. These rows are accounting-only after deletion.
                try db.execute(sql: "UPDATE messages SET role = 'usage', agent = NULL, completed_at = NULL WHERE session_id = ?", arguments: [id])
                try metadata.upsert(SyncMetadataRecord(filePath: prefix + id, fileHash: "deleted", lastImportedAt: now, isFileExists: false), in: db)
            }
            if !affected.isEmpty {
                try SessionService(dbPool: self.pool).recalculateSessions(for: affected, in: db)
                for item in prepared { try self.updateSession(item.source, in: db) }
                let newBounds = try bounds()
                let ranges = [oldBounds, newBounds].compactMap { $0 }
                if let lo = ranges.map({ $0.0 }).min(), let hi = ranges.map({ $0.1 }).max() {
                    try AggregationService(dbPool: self.pool).recalculateAggregations(from: lo, to: hi, in: db)
                }
            }
            // A partial import must not advance the last fully successful timestamp.
            if incomplete == 0 {
                try metadata.upsert(SyncMetadataRecord(filePath: path + "#v2", fileHash: "v2", lastImportedAt: now), in: db)
            }
        }
        let sessionUsageCount = try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE role = 'usage' AND id LIKE 'vw2:session-usage:%'") ?? 0
        }
        report(OpenCodeSourceState(kind: incomplete > 0 ? .historyIncomplete : .v2,
                                   missingSessions: incomplete, sessionUsageCount: sessionUsageCount,
                                   lastSuccess: incomplete > 0 ? lastSuccess : Date(timeIntervalSince1970: Double(now) / 1000)))
        return Result(changedCount: affected.count, affectedSessions: affected, incompleteCount: incomplete)
    }

    private func normalize(session: Row, rows: [Row], events: [Row], history: [Row]) throws -> [Message] {
        let sessionID: String = session["id"]
        let root: String? = session["project_root"]
        let directory: String = session["directory"]
        let knownTypes: Set<String> = ["user", "assistant", "compaction", "idle", "synthetic", "system", "skill", "shell", "agent-switched", "model-switched", "location-switched"]
        var forkPrefix: String?
        var starts: [String: (EventPayload, Int64)] = [:]
        var terminal: [String: (EventPayload, Int64)] = [:]
        var overhead: [(String, EventPayload, Int64)] = []
        for event in events {
            let type: String = event["type"]
            let eventID: String = event["id"]
            if type.hasPrefix("session.forked.") {
                guard type == "session.forked.2" else { throw OpenCodeSourceError.unsupportedSchema }
                forkPrefix = eventID.replacingOccurrences(of: "evt_", with: "msg_") + "_"
            }
            guard ["session.step.started.", "session.step.ended.", "session.step.failed.", "session.usage.recorded."].contains(where: { type.hasPrefix($0) }) else { continue }
            guard type.hasSuffix(".1") else { throw OpenCodeSourceError.unsupportedSchema }
            let payload: EventPayload = try decode(event["data"])
            if type.hasPrefix("session.step.ended."), payload.cost == nil || payload.tokens == nil {
                throw OpenCodeSourceError.invalidRecord
            }
            let created: Int64 = event["created"]
            if type.hasPrefix("session.step.started."), let id = payload.assistantMessageID {
                starts[id] = (payload, payload.started ?? created)
            } else if type.hasPrefix("session.step."), let id = payload.assistantMessageID {
                terminal[id] = (payload, created)
            } else if type.hasPrefix("session.usage.recorded.") {
                overhead.append((eventID, payload, created))
            }
        }
        let forked: String? = session["fork_session_id"]
        var result: [Message] = []
        var seen = Set<String>()
        for row in rows {
            let type: String = row["type"]
            let id: String = row["id"]
            guard knownTypes.contains(type) else { throw OpenCodeSourceError.unsupportedSchema }
            // Copied context is visible in OpenCode, but is not new user activity or spend.
            let sequence: Int = row["seq"]
            if let forkPrefix, id.hasPrefix(forkPrefix) { continue }
            // 官方分叉投影的 ID 为 msg_<fork-event>_<原序号>，不依赖事件表留存。
            if forked != nil && id.hasSuffix("_" + String(sequence)) { continue }
            let isCompaction = type == "compaction"
            guard type == "user" || type == "assistant" || isCompaction else { continue }
            if isCompaction && overhead.contains(where: { $0.1.source == "compaction" }) { continue }
            let payload: Payload = try decode(row["data"])
            if isCompaction && payload.tokens == nil && payload.cost == nil { continue }
            let usage = terminal[id]?.0
            let model = payload.model ?? starts[id]?.0.model
            if type == "assistant" && model == nil { throw OpenCodeSourceError.invalidRecord }
            let amount = usage?.cost ?? payload.cost
            let tokens = usage?.tokens ?? payload.tokens
            let created = starts[id]?.1 ?? payload.time.created
            result.append(Message(id: id, sessionID: sessionID, role: isCompaction ? "usage" : type,
                time: MessageTime(created: String(created), completed: isCompaction ? nil : payload.time.streamed.map(String.init)),
                parentID: nil, providerID: model?.providerID, modelID: model?.id,
                agent: isCompaction ? nil : payload.agent, mode: nil, variant: model?.variant, cwd: directory, root: root,
                tokens: tokens, cost: amount, finish: payload.finish))
            seen.insert(id)
        }
        // Reverted transcript rows can disappear; their durable spend remains real.
        for (id, item) in terminal where !seen.contains(id) {
            let start = starts[id]
            result.append(Message(id: id, sessionID: sessionID, role: "usage",
                time: MessageTime(created: String(start?.1 ?? item.1), completed: nil), parentID: nil,
                providerID: start?.0.model?.providerID, modelID: start?.0.model?.id, agent: nil,
                mode: nil, variant: start?.0.model?.variant, cwd: directory, root: root,
                tokens: item.0.tokens, cost: item.0.cost))
        }
        // Includes title generation and compaction. Their events are the accounting
        // authority; compaction transcript repeats must never be added a second time.
        for (id, usage, created) in overhead {
            guard usage.cost != nil, usage.tokens != nil else { throw OpenCodeSourceError.invalidRecord }
            result.append(Message(id: "vw2:" + id, sessionID: sessionID, role: "usage",
                time: MessageTime(created: String(created), completed: nil), parentID: nil,
                providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil,
                cwd: directory, root: root, tokens: usage.tokens, cost: usage.cost))
        }
        // 转换器可能将压缩摘要助手从 v2 展示流中移除，其消耗仍在会话累计值中。
        // 只采用源库保留的权威 v1 记录；本地已过期或已删除的缓存不参与核对。
        let represented = Set(rows.map { $0["id"] as String }).union(terminal.keys)
        let parser = OpenCodeMessageParser()
        for row in history {
            let id: String = row["id"]
            if represented.contains(id) { continue }
            let payload: String = row["data"]
            guard let bytes = payload.data(using: .utf8),
                  var object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
                throw OpenCodeSourceError.invalidRecord
            }
            guard object["role"] as? String == "assistant" else { continue }
            object["id"] = id
            object["sessionID"] = sessionID
            object["session_id"] = sessionID
            let parsed = parser.parseMessages(from: try JSONSerialization.data(withJSONObject: object), sourceURL: URL(fileURLWithPath: path))
            guard parsed.error == nil, let message = parsed.messages.first else { throw OpenCodeSourceError.invalidRecord }
            let created: Int64 = row["time_created"]
            result.append(Message(id: id, sessionID: sessionID, role: "usage",
                time: MessageTime(created: String(created), completed: nil), parentID: nil,
                providerID: message.providerID, modelID: message.modelID, agent: nil, mode: nil,
                variant: message.variant, cwd: directory, root: root, tokens: message.tokens, cost: message.cost))
        }
        return result
    }

    private func decode<T: Decodable>(_ text: String) throws -> T {
        guard let bytes = text.data(using: .utf8) else { throw OpenCodeSourceError.invalidRecord }
        do { return try decoder.decode(T.self, from: bytes) }
        catch { throw OpenCodeSourceError.invalidRecord }
    }

    /// 明细不能超过权威累计值。源库仅保留汇总的部分单列记账，不猜测模型或真实发生时刻。
    private func reconcileAccounting(_ session: Row, messages: inout [Message]) -> Bool {
        var totalCost: Double = 0
        var values = [0, 0, 0, 0, 0]
        for message in messages {
            totalCost += message.cost ?? 0
            values[0] += message.tokens?.input ?? 0
            values[1] += message.tokens?.output ?? 0
            values[2] += message.tokens?.reasoning ?? 0
            values[3] += message.tokens?.cacheRead ?? 0
            values[4] += message.tokens?.cacheWrite ?? 0
        }
        let expectedCost: Double = session["cost"]
        guard totalCost.isFinite, expectedCost.isFinite else { return false }
        let costDifference = expectedCost - totalCost
        guard costDifference >= -0.000001 else { return false }
        let columns = ["tokens_input", "tokens_output", "tokens_reasoning", "tokens_cache_read", "tokens_cache_write"]
        var difference = [0, 0, 0, 0, 0]
        for index in values.indices {
            let expected: Int = session[columns[index]]
            difference[index] = expected - values[index]
            if difference[index] < 0 { return false }
        }
        if costDifference > 0.000001 || difference.contains(where: { $0 > 0 }) {
            let id: String = session["id"]
            let created: Int64 = session["time_created"]
            messages.append(Message(id: "vw2:session-usage:" + id, sessionID: id, role: "usage",
                time: MessageTime(created: String(created), completed: nil), parentID: nil,
                providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil,
                cwd: session["directory"], root: session["project_root"],
                tokens: Tokens(input: difference[0], output: difference[1], reasoning: difference[2],
                               cacheRead: difference[3], cacheWrite: difference[4]), cost: max(0, costDifference)))
        }
        return true
    }

    private func updateSession(_ row: Row, in db: Database) throws {
        let id: String = row["id"]
        // Empty sessions are first-class in V2, including a newly created fork.
        try db.execute(sql: "INSERT OR IGNORE INTO sessions (session_id, user_msg_count, agent_msg_count, tool_id) VALUES (?, 0, 0, 'opencode')", arguments: [id])
        let root: String? = row["project_root"]
        try db.execute(sql: """
            UPDATE sessions SET project_name = ?, first_message_at = ?, last_message_at = ?,
                total_cost = ?, total_input_tokens = ?, total_output_tokens = ?, total_reasoning_tokens = ?,
                total_cache_read = ?, total_cache_write = ?, total_additions = ?, total_deletions = ?, total_file_count = ?
            WHERE session_id = ?
            """, arguments: [PathHelper.extractProjectName(from: root), row["time_created"] as Int64, row["time_updated"] as Int64,
                             row["cost"] as Double, row["tokens_input"] as Int, row["tokens_output"] as Int,
                             row["tokens_reasoning"] as Int, row["tokens_cache_read"] as Int, row["tokens_cache_write"] as Int,
                             row["summary_additions"] as Int?, row["summary_deletions"] as Int?, row["summary_files"] as Int?, id])
        // Project summary belongs to the session, not to every assistant step.
        let lastID = try String.fetchOne(db, sql: "SELECT id FROM messages WHERE session_id = ? AND role IN ('user', 'assistant') ORDER BY created_at DESC, id DESC LIMIT 1", arguments: [id])
        if let lastID {
            try db.execute(sql: "UPDATE messages SET summary_title = ?, summary_total_additions = ?, summary_total_deletions = ?, summary_file_count = ? WHERE id = ?", arguments: [row["title"] as String?, row["summary_additions"] as Int?, row["summary_deletions"] as Int?, row["summary_files"] as Int?, lastID])
        }
    }
}
