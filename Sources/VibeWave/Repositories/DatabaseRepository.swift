import Foundation
import GRDB

// Public repository responsible for SQLite DB setup with migrations using GRDB
public final class DatabaseRepository {
  public static let versionKey: String = "VibeWaveDatabaseVersion"
  private static let logger = AppLogger(category: "DatabaseRepository")

  // Exposed singleton for production default (disk-based)
  public static let shared: DatabaseRepository = DatabaseRepository()

  private let pool: DatabasePool
  private let configuration: Configuration

  // MARK: - Initialization
    public init(inMemory: Bool = false) {
        self.configuration = Self.makeConfiguration()
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

    let currentVersion = UserDefaults.standard.integer(forKey: Self.versionKey)
    if currentVersion < 11 {
      var migrator = DatabaseMigrator()

      // V1: Create initial tables (messages, sessions)
      migrator.registerMigration("v1_create_tables") { db in
        try DatabaseRepository.createTables(on: db)
      }

      // V2: Add sync_metadata table with tool_id for multi-tool support
      migrator.registerMigration("v2_add_sync_metadata") { db in
        try db.execute(sql: """
          CREATE TABLE IF NOT EXISTS sync_metadata (
            file_path TEXT PRIMARY KEY,
            tool_id TEXT DEFAULT 'opencode',
            file_hash TEXT NOT NULL,
            last_imported_at INTEGER NOT NULL,
            message_count INTEGER,
            first_message_time INTEGER,
            last_message_time INTEGER,
            is_file_exists INTEGER DEFAULT 1
          )
        """)

        try db.execute(sql: """
          CREATE INDEX IF NOT EXISTS idx_sync_metadata_tool ON sync_metadata(tool_id)
        """)
      }

      // V3: Add finish and diff_files to messages
      migrator.registerMigration("v3_update_messages_schema") { db in
        try db.execute(sql: "ALTER TABLE messages ADD COLUMN finish TEXT")
        try db.execute(sql: "ALTER TABLE messages ADD COLUMN diff_files TEXT")
      }

      // V4: Add new fields to sessions table
      migrator.registerMigration("v4_add_session_fields") { db in
        try db.execute(sql: "ALTER TABLE sessions ADD COLUMN total_additions INTEGER")
        try db.execute(sql: "ALTER TABLE sessions ADD COLUMN total_deletions INTEGER")
        try db.execute(sql: "ALTER TABLE sessions ADD COLUMN total_file_count INTEGER")
        try db.execute(sql: "ALTER TABLE sessions ADD COLUMN total_unique_file_count INTEGER")
        try db.execute(sql: "ALTER TABLE sessions ADD COLUMN total_edits INTEGER")
        try db.execute(sql: "ALTER TABLE sessions ADD COLUMN project_name TEXT")
        try db.execute(sql: "ALTER TABLE sessions ADD COLUMN finish_reason TEXT")
      }

      migrator.registerMigration("v5_add_completed_at") { db in
        try db.execute(sql: "ALTER TABLE messages ADD COLUMN completed_at INTEGER")
      }

      migrator.registerMigration("v6_remove_session_completed_at") { db in
        try db.execute(sql: """
          CREATE TABLE sessions_new (
            session_id TEXT PRIMARY KEY,
            first_message_at REAL,
            last_message_at REAL,
            message_count INTEGER,
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
            total_unique_file_count INTEGER,
            total_edits INTEGER,
            project_name TEXT,
            finish_reason TEXT
          )
        """)

        try db.execute(sql: """
          INSERT INTO sessions_new (
            session_id, first_message_at, last_message_at, message_count,
            total_input_tokens, total_output_tokens, total_reasoning_tokens,
            total_cache_read, total_cache_write, total_cost, is_orphan,
            total_additions, total_deletions, total_file_count, total_unique_file_count,
            total_edits, project_name, finish_reason
          )
          SELECT
            session_id, first_message_at, last_message_at, message_count,
            total_input_tokens, total_output_tokens, total_reasoning_tokens,
            total_cache_read, total_cache_write, total_cost, is_orphan,
            total_additions, total_deletions, total_file_count, total_unique_file_count,
            total_edits, project_name, finish_reason
          FROM sessions
        """)

        try db.execute(sql: "DROP TABLE sessions")
        try db.execute(sql: "ALTER TABLE sessions_new RENAME TO sessions")
      }

      // V7: Remove total_unique_file_count and total_edits from sessions
      // total_file_count will now represent the deduplicated file count (unique files edited)
      migrator.registerMigration("v7_remove_redundant_session_fields") { db in
        try db.execute(sql: """
          CREATE TABLE sessions_new (
            session_id TEXT PRIMARY KEY,
            first_message_at REAL,
            last_message_at REAL,
            message_count INTEGER,
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
            project_name TEXT,
            finish_reason TEXT
          )
        """)

        try db.execute(sql: """
          INSERT INTO sessions_new (
            session_id, first_message_at, last_message_at, message_count,
            total_input_tokens, total_output_tokens, total_reasoning_tokens,
            total_cache_read, total_cache_write, total_cost, is_orphan,
            total_additions, total_deletions, total_file_count, project_name, finish_reason
          )
          SELECT
            session_id, first_message_at, last_message_at, message_count,
            total_input_tokens, total_output_tokens, total_reasoning_tokens,
            total_cache_read, total_cache_write, total_cost, is_orphan,
            total_additions, total_deletions, total_file_count, project_name, finish_reason
          FROM sessions
        """)

        try db.execute(sql: "DROP TABLE sessions")
        try db.execute(sql: "ALTER TABLE sessions_new RENAME TO sessions")
      }

      // V8: Update sessions schema - remove message_count, add user_msg_count, agent_msg_count, total_edits
      migrator.registerMigration("v8_update_sessions_schema") { db in
        try db.execute(sql: "DROP TABLE IF EXISTS sessions")
        try db.execute(sql: """
          CREATE TABLE sessions (
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
            finish_reason TEXT
          )
          """)
      }

      // V9: Add performance indexes for Top 5 projects query optimization
      migrator.registerMigration("v9_add_performance_indexes") { db in
        // Indexes for sessions table (Top 5 projects query)
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_sessions_last_message_at ON sessions(last_message_at)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_sessions_project_name ON sessions(project_name)")
        
        // Indexes for messages table (fallback query optimization)
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id)")
        
        // Fix data quality: ensure project_name is not empty
        try db.execute(sql: """
          UPDATE sessions 
          SET project_name = '未命名项目' 
          WHERE project_name IS NULL OR project_name = ''
        """)
      }

      // V11: Add tool_id to messages and sessions tables for multi-tool support
      migrator.registerMigration("v11_add_tool_id_to_messages_sessions") { db in
        // Add tool_id to messages table
        try db.execute(sql: "ALTER TABLE messages ADD COLUMN tool_id TEXT DEFAULT 'opencode'")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_messages_tool_id ON messages(tool_id)")
        
        // Add tool_id to sessions table
        try db.execute(sql: "ALTER TABLE sessions ADD COLUMN tool_id TEXT DEFAULT 'opencode'")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_sessions_tool_id ON sessions(tool_id)")
      }

      do {
        try migrator.migrate(self.pool)
        UserDefaults.standard.set(11, forKey: Self.versionKey)
        Self.logger.info("Database migration to v11 completed")
      } catch {
        Self.logger.error("Database migration failed: \(error)")
      }
    } else {
      Self.logger.debug("Database already at version \(currentVersion)")
    }
  }

  // MARK: - Public helpers
  public func dbPool() -> DatabasePool {
    return pool
  }
  
  public func dbQueue() throws -> DatabaseQueue {
    return try DatabaseQueue(path: pool.path, configuration: configuration)
  }

  internal static func makeConfiguration() -> Configuration {
    var configuration = Configuration()
    configuration.prepareDatabase { db in
      try db.execute(sql: "PRAGMA journal_mode = WAL")
      try db.execute(sql: "PRAGMA synchronous = NORMAL")
      try db.execute(sql: "PRAGMA temp_store = MEMORY")
      try db.execute(sql: "PRAGMA cache_size = -20000")
    }
    return configuration
  }

  // MARK: - Migration helpers

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
            diff_files TEXT,
            tool_id TEXT DEFAULT 'opencode'
          )
          """
        )
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_messages_tool_id ON messages(tool_id)")
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
      """
    )
    try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_sessions_tool_id ON sessions(tool_id)")
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
      """
    )
    try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_sync_metadata_tool ON sync_metadata(tool_id)")
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
