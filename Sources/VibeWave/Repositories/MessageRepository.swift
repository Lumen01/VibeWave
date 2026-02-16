import Foundation
import GRDB

// MessageRepository uses the OpenCode schema as defined in MessageRecord.swift
// and maps between the Codable Message and the GRDB MessageRecord for database operations.
public final class MessageRepository {
    public let dbPool: DatabasePool
    private static let insertSQL = """
        INSERT OR REPLACE INTO messages (
          id, session_id, role, created_at, completed_at, provider_id, model_id,
          agent, mode, variant, project_root, project_cwd,
          token_input, token_output, token_reasoning,
          cache_read, cache_write, cost,
          summary_title, summary_total_additions, summary_total_deletions,
          summary_file_count, finish, diff_files
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    // Create the exact messages table schema as defined by MessageRecord.swift
    public func createSchemaIfNeeded() throws {
        try dbPool.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS messages (
                  id TEXT PRIMARY KEY,
                  session_id TEXT,
                  role TEXT,
                  created_at INTEGER,
                  completed_at INTEGER,
                  provider_id TEXT,
                  model_id TEXT,
                  agent TEXT,
                  mode TEXT,
                  variant TEXT,
                  project_root TEXT,
                  project_cwd TEXT,
                  token_input TEXT,
                  token_output TEXT,
                  token_reasoning TEXT,
                  cache_read INTEGER,
                  cache_write INTEGER,
                  cost REAL,
                  summary_title TEXT,
                  summary_total_additions INTEGER,
                  summary_total_deletions INTEGER,
                  summary_file_count INTEGER,
                  finish TEXT,
                  diff_files TEXT
                )
                """)
        }
    }

    // Insert with idempotency
    public func insert(message: Message) throws {
        let record = MessageRecord(message)
        try dbPool.write { db in
            // Map fields explicitly to the full OpenCode schema
            let args: StatementArguments = [
                record.id,
                record.sessionId,
                record.role,
                record.createdAt,
                record.completedAt,
                record.providerId,
                record.modelId,
                record.agent,
                record.mode,
                record.variant,
                record.projectRoot,
                record.projectCwd,
                record.tokenInput,
                record.tokenOutput,
                record.tokenReasoning,
                record.cacheRead,
                record.cacheWrite,
                record.cost,
                record.summaryTitle,
                record.summaryTotalAdditions,
                record.summaryTotalDeletions,
                record.summaryFileCount,
                record.finish,
                record.diffFiles
            ]
            try db.execute(sql: Self.insertSQL, arguments: args)
        }
    }

    public func insert(messages: [Message]) throws {
        guard !messages.isEmpty else { return }
        try dbPool.write { db in
            try insert(messages: messages, in: db)
        }
    }

    public func insert(messages: [Message], in db: Database) throws {
        guard !messages.isEmpty else { return }
        let statement = try db.makeStatement(sql: Self.insertSQL)
        for message in messages {
            let record = MessageRecord(message)
            let args: StatementArguments = [
                record.id,
                record.sessionId,
                record.role,
                record.createdAt,
                record.completedAt,
                record.providerId,
                record.modelId,
                record.agent,
                record.mode,
                record.variant,
                record.projectRoot,
                record.projectCwd,
                record.tokenInput,
                record.tokenOutput,
                record.tokenReasoning,
                record.cacheRead,
                record.cacheWrite,
                record.cost,
                record.summaryTitle,
                record.summaryTotalAdditions,
                record.summaryTotalDeletions,
                record.summaryFileCount,
                record.finish,
                record.diffFiles
            ]
            try statement.execute(arguments: args)
        }
    }

    // Fetch a single record by ID
    public func fetch(by messageId: String) -> MessageRecord? {
        var result: MessageRecord?
        try? dbPool.read { db in
            if let row = try? Row.fetchOne(db, sql: "SELECT * FROM messages WHERE id = ?", arguments: [messageId]) {
                result = MessageRecord(row: row)
            }
        }
        return result
    }

    // Fetch all messages for a given session
    public func fetchBy(sessionId: String) -> [MessageRecord] {
        var records: [MessageRecord] = []
        try? dbPool.read { db in
            let rows = try? Row.fetchAll(db, sql: "SELECT * FROM messages WHERE session_id = ?", arguments: [sessionId])
            records = rows?.map { MessageRecord(row: $0) } ?? []
        }
        return records
    }

    // Fetch all messages with an optional limit
    public func fetchAll(limited count: Int? = nil) -> [MessageRecord] {
        var sql = "SELECT * FROM messages"
        if let limit = count {
            sql += " LIMIT \(limit)"
        }
        var records: [MessageRecord] = []
        try? dbPool.read { db in
            let rows = try? Row.fetchAll(db, sql: sql)
            records = rows?.map { MessageRecord(row: $0) } ?? []
        }
        return records
    }

    // Fetch all messages within a timestamp range
    public func fetchAll(startTimestamp start: Date, endTimestamp end: Date) -> [MessageRecord] {
        var records: [MessageRecord] = []
        try? dbPool.read { db in
            let rows = try? Row.fetchAll(db, sql: "SELECT * FROM messages WHERE created_at >= ? AND created_at <= ? ORDER BY created_at ASC", arguments: [start.timeIntervalSince1970, end.timeIntervalSince1970])
            records = rows?.map { MessageRecord(row: $0) } ?? []
        }
        return records
    }
}
