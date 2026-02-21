import Foundation
import GRDB

// Public repository responsible for SQLite DB setup and schema bootstrapping.
public final class DatabaseRepository {
  private static let logger = AppLogger(category: "DatabaseRepository")

  // Exposed singleton for production default (disk-based)
  public static let shared: DatabaseRepository = DatabaseRepository()

  private let pool: DatabasePool
  private let configuration: Configuration

  // MARK: - Initialization
  public init(inMemory: Bool = false) {
    self.configuration = Self.makeConfiguration(inMemory: inMemory)
    switch inMemory {
    case true:
      do {
        self.pool = try DatabasePool(path: ":memory:", configuration: configuration)
      } catch {
        fatalError("VibeWave: failed to create in-memory database pool: \(error)")
      }
    case false:
      let dbURL = DatabaseRepository.databaseURL
      // Ensure directory exists
      let dir = dbURL.deletingLastPathComponent()
      do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
      } catch {
        Self.logger.error("Failed to create DB directory at \(dir.path): \(error)")
      }
      do {
        self.pool = try DatabasePool(path: dbURL.path, configuration: configuration)
      } catch {
        fatalError("VibeWave: failed to create database pool at \(dbURL.path): \(error)")
      }
    }

    do {
      try self.pool.write { db in
        try Self.bootstrapSchema(on: db)
      }
      Self.logger.info("Database schema bootstrap completed")
    } catch {
      Self.logger.error("Database schema bootstrap failed: \(error)")
    }
  }

  // MARK: - Public helpers
  public func dbPool() -> DatabasePool {
    return pool
  }

  public func dbQueue() throws -> DatabaseQueue {
    return try DatabaseQueue(path: pool.path, configuration: configuration)
  }

  internal static func makeConfiguration(inMemory: Bool = false) -> Configuration {
    var configuration = Configuration()
    configuration.prepareDatabase { db in
      // WAL does not work with :memory: databases.
      if !inMemory {
        try db.execute(sql: "PRAGMA journal_mode = WAL")
      }
      try db.execute(sql: "PRAGMA synchronous = NORMAL")
      try db.execute(sql: "PRAGMA temp_store = MEMORY")
      try db.execute(sql: "PRAGMA cache_size = -20000")
    }
    return configuration
  }

  // MARK: - Schema bootstrap helpers

  public static func bootstrapSchema(on db: Database) throws {
    try createTables(on: db)
    try reconcileMessagesSchema(on: db)
    try reconcileSessionsSchema(on: db)
    try reconcileSyncMetadataSchema(on: db)
    try createAggregationTables(on: db)
    try reconcileAggregationSchema(on: db)

    // No longer rely on GRDB migration history.
    try db.execute(sql: "DROP TABLE IF EXISTS grdb_migrations")
  }

  public static func createAggregationTables(on db: Database) throws {
    try db.execute(sql: """
      CREATE TABLE IF NOT EXISTS hourly_stats (
        time_bucket_ms INTEGER,
        project_id TEXT,
        provider_id TEXT,
        model_id TEXT,
        role TEXT,
        agent TEXT,
        tool_id TEXT DEFAULT 'opencode',
        session_count INTEGER DEFAULT 0,
        message_count INTEGER DEFAULT 0,
        input_tokens INTEGER DEFAULT 0,
        output_tokens INTEGER DEFAULT 0,
        reasoning_tokens INTEGER DEFAULT 0,
        cache_read INTEGER DEFAULT 0,
        cache_write INTEGER DEFAULT 0,
        duration_ms INTEGER DEFAULT 0,
        cost REAL DEFAULT 0.0,
        net_code_lines INTEGER DEFAULT 0,
        file_count INTEGER DEFAULT 0,
        last_created_at_ms INTEGER DEFAULT 0,
        PRIMARY KEY (time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id)
      )
      """)

    try db.execute(sql: """
      CREATE TABLE IF NOT EXISTS daily_stats (
        time_bucket_ms INTEGER,
        project_id TEXT,
        provider_id TEXT,
        model_id TEXT,
        role TEXT,
        agent TEXT,
        tool_id TEXT DEFAULT 'opencode',
        session_count INTEGER DEFAULT 0,
        message_count INTEGER DEFAULT 0,
        input_tokens INTEGER DEFAULT 0,
        output_tokens INTEGER DEFAULT 0,
        reasoning_tokens INTEGER DEFAULT 0,
        cache_read INTEGER DEFAULT 0,
        cache_write INTEGER DEFAULT 0,
        duration_ms INTEGER DEFAULT 0,
        cost REAL DEFAULT 0.0,
        net_code_lines INTEGER DEFAULT 0,
        file_count INTEGER DEFAULT 0,
        last_created_at_ms INTEGER DEFAULT 0,
        PRIMARY KEY (time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id)
      )
      """)

    try db.execute(sql: """
      CREATE TABLE IF NOT EXISTS monthly_stats (
        time_bucket_ms INTEGER,
        project_id TEXT,
        provider_id TEXT,
        model_id TEXT,
        role TEXT,
        agent TEXT,
        tool_id TEXT DEFAULT 'opencode',
        session_count INTEGER DEFAULT 0,
        message_count INTEGER DEFAULT 0,
        input_tokens INTEGER DEFAULT 0,
        output_tokens INTEGER DEFAULT 0,
        reasoning_tokens INTEGER DEFAULT 0,
        cache_read INTEGER DEFAULT 0,
        cache_write INTEGER DEFAULT 0,
        duration_ms INTEGER DEFAULT 0,
        cost REAL DEFAULT 0.0,
        net_code_lines INTEGER DEFAULT 0,
        file_count INTEGER DEFAULT 0,
        last_created_at_ms INTEGER DEFAULT 0,
        PRIMARY KEY (time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id)
      )
      """)
  }

  public static func createTables(on db: Database) throws {
    try createMessagesTable(on: db)
    try createSessionsTable(on: db)
    try createSyncMetadataTable(on: db)
  }

  private static func createMessagesTable(on db: Database) throws {
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
        token_input INTEGER,
        token_output INTEGER,
        token_reasoning INTEGER,
        cache_read INTEGER,
        cache_write INTEGER,
        cost REAL,
        summary_title TEXT,
        summary_total_additions INTEGER,
        summary_total_deletions INTEGER,
        summary_file_count INTEGER,
        finish TEXT,
        diff_files TEXT,
        tool_id TEXT DEFAULT 'opencode'
      )
      """)
  }

  private static func createSessionsTable(on db: Database) throws {
    try db.execute(sql: """
      CREATE TABLE IF NOT EXISTS sessions (
        session_id TEXT PRIMARY KEY,
        first_message_at INTEGER,
        last_message_at INTEGER,
        user_msg_count INTEGER,
        agent_msg_count INTEGER,
        total_input_tokens INTEGER,
        total_output_tokens INTEGER,
        total_reasoning_tokens INTEGER,
        total_cache_read INTEGER,
        total_cache_write INTEGER,
        total_cost REAL,
        is_orphan INTEGER,
        total_additions INTEGER,
        total_deletions INTEGER,
        total_file_count INTEGER,
        total_edits INTEGER,
        project_name TEXT,
        finish_reason TEXT,
        tool_id TEXT DEFAULT 'opencode'
      )
      """)
  }

  private static func createSyncMetadataTable(on db: Database) throws {
    try db.execute(sql: """
      CREATE TABLE IF NOT EXISTS sync_metadata (
        file_path TEXT PRIMARY KEY,
        tool_id TEXT DEFAULT 'opencode',
        file_hash TEXT NOT NULL,
        last_imported_at INTEGER NOT NULL,
        message_count INTEGER,
        first_message_time INTEGER,
        last_message_time INTEGER,
        is_file_exists INTEGER DEFAULT 1,
        hourly_aggregated INTEGER DEFAULT 0,
        daily_aggregated INTEGER DEFAULT 0,
        monthly_aggregated INTEGER DEFAULT 0
      )
      """)
  }

  private static func reconcileMessagesSchema(on db: Database) throws {
    let columns = try columnDefinitions(on: db, table: "messages")
    let existingColumns = Set(columns.keys)
    let shouldRebuildForTokenType =
      normalizedType(columns["token_input"]) != "INTEGER" ||
      normalizedType(columns["token_output"]) != "INTEGER" ||
      normalizedType(columns["token_reasoning"]) != "INTEGER"

    if shouldRebuildForTokenType {
      try rebuildMessagesTable(on: db, existingColumns: existingColumns)
      return
    }

    try ensureColumn(on: db, table: "messages", column: "completed_at", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "provider_id", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "model_id", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "agent", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "mode", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "variant", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "project_root", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "project_cwd", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "cache_read", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "cache_write", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "cost", definition: "REAL", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "summary_title", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "summary_total_additions", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "summary_total_deletions", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "summary_file_count", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "finish", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "diff_files", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "messages", column: "tool_id", definition: "TEXT DEFAULT 'opencode'", existingColumns: existingColumns)
    try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_messages_tool_id ON messages(tool_id)")
  }

  private static func rebuildMessagesTable(on db: Database, existingColumns: Set<String>) throws {
    let legacyTable = "messages_legacy_tmp"
    try db.execute(sql: "DROP TABLE IF EXISTS \(legacyTable)")
    try db.execute(sql: "ALTER TABLE messages RENAME TO \(legacyTable)")
    try createMessagesTable(on: db)

    let orderedColumns = [
      "id", "session_id", "role", "created_at", "completed_at", "provider_id", "model_id",
      "agent", "mode", "variant", "project_root", "project_cwd", "token_input", "token_output",
      "token_reasoning", "cache_read", "cache_write", "cost", "summary_title",
      "summary_total_additions", "summary_total_deletions", "summary_file_count",
      "finish", "diff_files", "tool_id"
    ]

    let selectExpressions = orderedColumns.map { column in
      return messageSelectExpression(column: column, existingColumns: existingColumns)
    }

    try db.execute(sql: """
      INSERT INTO messages (\(orderedColumns.joined(separator: ", ")))
      SELECT \(selectExpressions.joined(separator: ", "))
      FROM \(legacyTable)
      """)

    try db.execute(sql: "DROP TABLE \(legacyTable)")
  }

  private static func messageSelectExpression(column: String, existingColumns: Set<String>) -> String {
    let hasColumn = existingColumns.contains(column)
    switch column {
    case "token_input", "token_output", "token_reasoning":
      guard hasColumn else { return "NULL" }
      return "CASE WHEN \(column) IS NULL OR TRIM(CAST(\(column) AS TEXT)) = '' THEN NULL ELSE CAST(\(column) AS INTEGER) END"
    case "cache_read", "cache_write":
      guard hasColumn else { return "0" }
      return "COALESCE(CAST(\(column) AS INTEGER), 0)"
    case "cost":
      guard hasColumn else { return "0.0" }
      return "COALESCE(CAST(\(column) AS REAL), 0.0)"
    case "summary_total_additions", "summary_total_deletions", "summary_file_count":
      guard hasColumn else { return "0" }
      return "COALESCE(CAST(\(column) AS INTEGER), 0)"
    case "tool_id":
      guard hasColumn else { return "'opencode'" }
      return "COALESCE(NULLIF(TRIM(CAST(tool_id AS TEXT)), ''), 'opencode')"
    case "created_at", "completed_at":
      guard hasColumn else { return "NULL" }
      return "CAST(\(column) AS INTEGER)"
    default:
      return hasColumn ? column : "NULL"
    }
  }

  private static func reconcileSessionsSchema(on db: Database) throws {
    let existingColumns = Set(try columnDefinitions(on: db, table: "sessions").keys)
    try ensureColumn(on: db, table: "sessions", column: "first_message_at", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "last_message_at", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "user_msg_count", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "agent_msg_count", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_input_tokens", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_output_tokens", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_reasoning_tokens", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_cache_read", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_cache_write", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_cost", definition: "REAL", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "is_orphan", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_additions", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_deletions", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_file_count", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "total_edits", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "project_name", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "finish_reason", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sessions", column: "tool_id", definition: "TEXT DEFAULT 'opencode'", existingColumns: existingColumns)
    try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_sessions_tool_id ON sessions(tool_id)")
  }

  private static func reconcileSyncMetadataSchema(on db: Database) throws {
    let existingColumns = Set(try columnDefinitions(on: db, table: "sync_metadata").keys)
    try ensureColumn(on: db, table: "sync_metadata", column: "tool_id", definition: "TEXT DEFAULT 'opencode'", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sync_metadata", column: "file_hash", definition: "TEXT", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sync_metadata", column: "last_imported_at", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sync_metadata", column: "message_count", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sync_metadata", column: "first_message_time", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sync_metadata", column: "last_message_time", definition: "INTEGER", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sync_metadata", column: "is_file_exists", definition: "INTEGER DEFAULT 1", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sync_metadata", column: "hourly_aggregated", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sync_metadata", column: "daily_aggregated", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: "sync_metadata", column: "monthly_aggregated", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_sync_metadata_tool ON sync_metadata(tool_id)")
  }

  private static func reconcileAggregationSchema(on db: Database) throws {
    try ensureAggregationTableSchema(on: db, table: "hourly_stats")
    try ensureAggregationTableSchema(on: db, table: "daily_stats")
    try ensureAggregationTableSchema(on: db, table: "monthly_stats")
  }

  private static func ensureAggregationTableSchema(on db: Database, table: String) throws {
    let existingColumns = Set(try columnDefinitions(on: db, table: table).keys)
    try ensureColumn(on: db, table: table, column: "tool_id", definition: "TEXT DEFAULT 'opencode'", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "session_count", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "message_count", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "input_tokens", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "output_tokens", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "reasoning_tokens", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "cache_read", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "cache_write", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "duration_ms", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "cost", definition: "REAL DEFAULT 0.0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "net_code_lines", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "file_count", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
    try ensureColumn(on: db, table: table, column: "last_created_at_ms", definition: "INTEGER DEFAULT 0", existingColumns: existingColumns)
  }

  private static func ensureColumn(
    on db: Database,
    table: String,
    column: String,
    definition: String,
    existingColumns: Set<String>
  ) throws {
    guard !existingColumns.contains(column) else { return }
    try db.execute(sql: "ALTER TABLE \(table) ADD COLUMN \(column) \(definition)")
  }

  private static func columnDefinitions(on db: Database, table: String) throws -> [String: String] {
    let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(\(table))")
    var definitions: [String: String] = [:]
    for row in rows {
      let name = (row["name"] as? String ?? "").lowercased()
      let type = row["type"] as? String ?? ""
      definitions[name] = type
    }
    return definitions
  }

  private static func normalizedType(_ type: String?) -> String {
    return type?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
  }

  // Convenience for tests to fetch URL (public)
  public static let databaseURL: URL = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let vibewaveDir = home.appendingPathComponent("Library/Application Support/VibeWave", isDirectory: true)
    try? FileManager.default.createDirectory(at: vibewaveDir, withIntermediateDirectories: true, attributes: nil)
    return vibewaveDir.appendingPathComponent("vibewave.db")
  }()

  public static func databaseExists() -> Bool {
    FileManager.default.fileExists(atPath: databaseURL.path)
  }

  public func hasAnyData() -> Bool {
    do {
      let count = try pool.read { db in
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages LIMIT 1") ?? 0
      }
      return count > 0
    } catch {
      return false
    }
  }
}
