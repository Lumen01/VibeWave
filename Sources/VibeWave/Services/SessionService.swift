import Foundation
import GRDB

public final class SessionService {
    public let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func recalculateSessions(for sessionIds: Set<String>) throws {
        guard !sessionIds.isEmpty else { return }

        let sessionIdList = Array(sessionIds).joined(separator: "','")

        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM sessions WHERE session_id IN ('\(sessionIdList)')")

            try db.execute(sql: """
                INSERT INTO sessions (
                    session_id, first_message_at, last_message_at, user_msg_count, agent_msg_count,
                    total_input_tokens, total_output_tokens, total_reasoning_tokens,
                    total_cache_read, total_cache_write, total_cost, is_orphan,
                    total_additions, total_deletions, total_file_count, total_edits,
                    project_name, finish_reason
                )
                SELECT
                  m.session_id,
                  MIN(m.created_at),
                  MAX(m.created_at),
                  COUNT(CASE WHEN m.role = 'user' THEN 1 END),
                  COUNT(CASE WHEN m.role = 'assistant' OR (m.agent IS NOT NULL AND m.agent != '') THEN 1 END),
                  SUM(CAST(COALESCE(m.token_input, '0') AS INTEGER)),
                  SUM(CAST(COALESCE(m.token_output, '0') AS INTEGER)),
                  SUM(CAST(COALESCE(m.token_reasoning, '0') AS INTEGER)),
                  SUM(m.cache_read),
                  SUM(m.cache_write),
                  SUM(m.cost),
                  0,
                  SUM(m.summary_total_additions),
                  SUM(m.summary_total_deletions),
                  SUM(m.summary_file_count),
                  SUM(m.summary_file_count),
                  (SELECT SUBSTR(project_root, MAX(INSTR(project_root, '/'), INSTR(project_root, '\\\\')) + 1)
                   FROM messages m2
                   WHERE m2.session_id = m.session_id AND m2.project_root IS NOT NULL
                   LIMIT 1),
                  (SELECT m3.finish
                   FROM messages m3
                   WHERE m3.session_id = m.session_id
                   ORDER BY m3.created_at DESC
                   LIMIT 1)
                FROM messages m
                WHERE m.session_id IN ('\(sessionIdList)')
                GROUP BY m.session_id
            """)

            for sessionId in sessionIds {
                let fileRows = try Row.fetchAll(db, sql: """
                    SELECT diff_files FROM messages
                    WHERE session_id = ? AND diff_files IS NOT NULL
                """, arguments: [sessionId])

                var allFiles = Set<String>()
                for fileRow in fileRows {
                    if let diffFiles = fileRow[0] as? String {
                        let files = diffFiles.split(separator: ",").map(String.init)
                        allFiles.formUnion(files)
                    }
                }

                let uniqueCount = allFiles.count
                if uniqueCount > 0 {
                    try db.execute(sql: """
                        UPDATE sessions
                        SET total_file_count = ?
                        WHERE session_id = ?
                    """, arguments: [uniqueCount, sessionId])
                }
            }
        }
    }

    public func rebuildAllSessions() throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM sessions")

            try db.execute(sql: """
                INSERT INTO sessions (
                    session_id, first_message_at, last_message_at, user_msg_count, agent_msg_count,
                    total_input_tokens, total_output_tokens, total_reasoning_tokens,
                    total_cache_read, total_cache_write, total_cost, is_orphan,
                    total_additions, total_deletions, total_file_count, total_edits,
                    project_name, finish_reason
                )
                SELECT
                  m.session_id,
                  MIN(m.created_at),
                  MAX(m.created_at),
                  COUNT(CASE WHEN m.role = 'user' THEN 1 END),
                  COUNT(CASE WHEN m.role = 'assistant' OR (m.agent IS NOT NULL AND m.agent != '') THEN 1 END),
                  SUM(CAST(COALESCE(m.token_input, '0') AS INTEGER)),
                  SUM(CAST(COALESCE(m.token_output, '0') AS INTEGER)),
                  SUM(CAST(COALESCE(m.token_reasoning, '0') AS INTEGER)),
                  SUM(m.cache_read),
                  SUM(m.cache_write),
                  SUM(m.cost),
                  0,
                  SUM(m.summary_total_additions),
                  SUM(m.summary_total_deletions),
                  SUM(m.summary_file_count),
                  SUM(m.summary_file_count),
                  (SELECT SUBSTR(project_root, MAX(INSTR(project_root, '/'), INSTR(project_root, '\\\\')) + 1)
                   FROM messages m2
                   WHERE m2.session_id = m.session_id AND m2.project_root IS NOT NULL
                   LIMIT 1),
                  (SELECT m3.finish
                   FROM messages m3
                   WHERE m3.session_id = m.session_id
                   ORDER BY m3.created_at DESC
                   LIMIT 1)
                FROM messages m
                GROUP BY m.session_id
            """)

            let sessionRows = try Row.fetchAll(db, sql: "SELECT session_id FROM sessions")
            for row in sessionRows {
                guard let sessionId = row[0] as? String else { continue }

                let fileRows = try Row.fetchAll(db, sql: """
                    SELECT diff_files FROM messages
                    WHERE session_id = ? AND diff_files IS NOT NULL
                """, arguments: [sessionId])

                var allFiles = Set<String>()
                for fileRow in fileRows {
                    if let diffFiles = fileRow[0] as? String {
                        let files = diffFiles.split(separator: ",").map(String.init)
                        allFiles.formUnion(files)
                    }
                }

                let uniqueCount = allFiles.count
                if uniqueCount > 0 {
                    try db.execute(sql: """
                        UPDATE sessions
                        SET total_file_count = ?
                        WHERE session_id = ?
                    """, arguments: [uniqueCount, sessionId])
                }
            }
        }
    }

    public func deleteSession(sessionId: String) throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM sessions WHERE session_id = ?", arguments: [sessionId])
            try db.execute(sql: "DELETE FROM messages WHERE session_id = ?", arguments: [sessionId])
        }
    }
}
