import Foundation
import GRDB

public final class SessionService {
    public let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func recalculateSessions(for sessionIds: Set<String>) throws {
        guard !sessionIds.isEmpty else { return }

        try dbPool.write { db in
            try recalculateSessions(for: sessionIds, in: db)
        }
    }

    func recalculateSessions(for sessionIds: Set<String>, in db: Database) throws {
        guard !sessionIds.isEmpty else { return }
        // Delete existing sessions for these IDs
        let placeholders = sessionIds.map { _ in "?" }.joined(separator: ",")
        try db.execute(sql: "DELETE FROM sessions WHERE session_id IN (\(placeholders))", arguments: StatementArguments(Array(sessionIds)))

        // Insert sessions with raw project_root first
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
              COUNT(CASE WHEN m.role = 'assistant' THEN 1 END),
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
              (SELECT m2.project_root
               FROM messages m2
               WHERE m2.session_id = m.session_id AND m2.project_root IS NOT NULL
               LIMIT 1),
              (SELECT m3.finish
               FROM messages m3
               WHERE m3.session_id = m.session_id
               ORDER BY m3.created_at DESC
               LIMIT 1)
            FROM messages m
            WHERE m.session_id IN (\(placeholders))
            GROUP BY m.session_id
        """, arguments: StatementArguments(Array(sessionIds)))

        // Extract project names correctly using Swift
        let sessionRows = try Row.fetchAll(db, sql: "SELECT session_id, project_name FROM sessions WHERE session_id IN (\(placeholders))", arguments: StatementArguments(Array(sessionIds)))
        let projectUpdate = try db.makeStatement(sql: "UPDATE sessions SET project_name = ? WHERE session_id = ?")
        for row in sessionRows {
            guard let sessionId = row[0] as? String else { continue }
            if let projectRoot = row[1] as? String {
                let projectName = PathHelper.extractProjectName(from: projectRoot)
                try projectUpdate.execute(arguments: [projectName, sessionId])
            }
        }

        let fileRows = try Row.fetchAll(db, sql: """
            SELECT session_id, diff_files FROM messages
            WHERE session_id IN (\(placeholders)) AND diff_files IS NOT NULL
        """, arguments: StatementArguments(Array(sessionIds)))
        try updateUniqueFileCounts(from: fileRows, in: db)
    }

    public func rebuildAllSessions() throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM sessions")

            // Insert sessions with raw project_root first
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
                  COUNT(CASE WHEN m.role = 'assistant' THEN 1 END),
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
                  (SELECT m2.project_root
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

            // Extract project names correctly using Swift
            let sessionRows = try Row.fetchAll(db, sql: "SELECT session_id, project_name FROM sessions")
            let projectUpdate = try db.makeStatement(sql: "UPDATE sessions SET project_name = ? WHERE session_id = ?")
            for row in sessionRows {
                guard let sessionId = row[0] as? String else { continue }
                if let projectRoot = row[1] as? String {
                    let projectName = PathHelper.extractProjectName(from: projectRoot)
                    try projectUpdate.execute(arguments: [projectName, sessionId])
                }
            }

            let fileRows = try Row.fetchAll(db, sql: """
                SELECT session_id, diff_files FROM messages
                WHERE diff_files IS NOT NULL
            """)
            try updateUniqueFileCounts(from: fileRows, in: db)
        }
    }

    private func updateUniqueFileCounts(from rows: [Row], in db: Database) throws {
        var filesBySession: [String: Set<String>] = [:]
        for row in rows {
            guard let sessionId = row[0] as? String,
                  let diffFiles = row[1] as? String else { continue }
            filesBySession[sessionId, default: []].formUnion(diffFiles.split(separator: ",").map(String.init))
        }

        let update = try db.makeStatement(sql: "UPDATE sessions SET total_file_count = ? WHERE session_id = ?")
        for (sessionId, files) in filesBySession where !files.isEmpty {
            try update.execute(arguments: [files.count, sessionId])
        }
    }

    public func deleteSession(sessionId: String) throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM sessions WHERE session_id = ?", arguments: [sessionId])
            try db.execute(sql: "DELETE FROM messages WHERE session_id = ?", arguments: [sessionId])
        }
    }
}
