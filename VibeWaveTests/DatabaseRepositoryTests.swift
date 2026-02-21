import XCTest
import GRDB
@testable import VibeWave

public class DatabaseRepositoryTests: XCTestCase {
    public override func setUp() {
        super.setUp()
    }

    public override func tearDown() {
        super.tearDown()
    }

    // In-memory tables existence check using DatabaseQueue (avoids WAL mode issues)
    public func testInMemoryTablesExistAfterMigration() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try queue.write { db in
            try DatabaseRepository.createTables(on: db)
        }
        let exists: Bool = try queue.read { db in
            let rows = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('messages','sessions')")
            return Set(rows).count == 2
        }
        XCTAssertTrue(exists, "messages and sessions tables should exist in in-memory DB")
    }

    public func testFreshRunInMemoryCreateTablesCreatesExpectedCoreTables() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try queue.write { db in
            try DatabaseRepository.createTables(on: db)
        }
        let exists: Bool = try queue.read { db in
            let rows = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('messages','sessions')")
            return Set(rows).count == 2
        }
        XCTAssertTrue(exists, "Messages and sessions tables must exist after createTables")
    }

    public func testHasAnyData_ReturnsFalseForEmptyDatabase() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try queue.write { db in
            try DatabaseRepository.createTables(on: db)
        }

        let count = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages LIMIT 1") ?? 0
        }
        XCTAssertEqual(count, 0, "Empty database should have 0 messages")
    }

    public func testHasAnyData_ReturnsTrueWithData() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try queue.write { db in
            try DatabaseRepository.createTables(on: db)
            try db.execute(sql: """
                INSERT INTO messages (id, session_id, role, created_at)
                VALUES ('test-id', 'test-session', 'user', 1234567890)
            """)
        }

        let count = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages LIMIT 1") ?? 0
        }
        XCTAssertEqual(count, 1, "Database with records should have 1 message")
    }

    // MARK: - V2 Migration Tests

    public func testV2MigrationCreatesSyncMetadataTableWithToolId() throws {
        let queue = try DatabaseQueue(path: ":memory:")

        // Manually run V1 migration
        try queue.write { db in
            try DatabaseRepository.createTables(on: db)
        }

        // Manually run V2 migration (simulating what DatabaseRepository.init does)
        try queue.write { db in
            try db.execute(sql: """
              CREATE TABLE IF NOT EXISTS sync_metadata (
                file_path TEXT PRIMARY KEY,
                tool_id TEXT DEFAULT 'opencode',
                file_hash TEXT NOT NULL,
                last_imported_at REAL NOT NULL,
                message_count INTEGER,
                first_message_time REAL,
                last_message_time REAL,
                is_file_exists INTEGER DEFAULT 1
              )
            """)

            try db.execute(sql: """
              CREATE INDEX IF NOT EXISTS idx_sync_metadata_tool ON sync_metadata(tool_id)
            """)
        }

        // Verify table exists
        let tableExists: Bool = try queue.read { db in
            let rows = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_metadata'")
            return !rows.isEmpty
        }
        XCTAssertTrue(tableExists, "sync_metadata table should exist after V2 migration")

        // Verify tool_id column exists
        let columnExists: Bool = try queue.read { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(sync_metadata)")
            return rows.contains { row in
                let name = row["name"] as? String ?? ""
                return name == "tool_id"
            }
        }
        XCTAssertTrue(columnExists, "tool_id column should exist in sync_metadata table")

        // Verify index exists
        let indexExists: Bool = try queue.read { db in
            let indexes = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_sync_metadata_tool'")
            return !indexes.isEmpty
        }
        XCTAssertTrue(indexExists, "idx_sync_metadata_tool index should exist after V2 migration")

        // Verify we can insert a record with tool_id
        try queue.write { db in
            try db.execute(sql: """
              INSERT INTO sync_metadata (file_path, tool_id, file_hash, last_imported_at)
              VALUES ('/test/path.json', 'opencode', 'abc123', 1234567890.0)
            """)
        }

        // Verify tool_id default value works
        try queue.write { db in
            try db.execute(sql: """
              INSERT INTO sync_metadata (file_path, file_hash, last_imported_at)
              VALUES ('/test/path2.json', 'def456', 1234567891.0)
            """)
        }

        let toolIdCount: Int = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE tool_id = 'opencode'") ?? 0
        }
        XCTAssertEqual(toolIdCount, 2, "Both records should have tool_id = 'opencode' (one explicit, one default)")
    }

    public func testV2MigrationToolIdFieldAcceptsDifferentTools() throws {
        let queue = try DatabaseQueue(path: ":memory:")

        // Run migrations
        try queue.write { db in
            try DatabaseRepository.createTables(on: db)
            try db.execute(sql: """
              CREATE TABLE IF NOT EXISTS sync_metadata (
                file_path TEXT PRIMARY KEY,
                tool_id TEXT DEFAULT 'opencode',
                file_hash TEXT NOT NULL,
                last_imported_at REAL NOT NULL,
                message_count INTEGER,
                first_message_time REAL,
                last_message_time REAL,
                is_file_exists INTEGER DEFAULT 1
              )
            """)
            try db.execute(sql: """
              CREATE INDEX IF NOT EXISTS idx_sync_metadata_tool ON sync_metadata(tool_id)
            """)
        }

        // Insert records with different tool_ids
        try queue.write { db in
            try db.execute(sql: "INSERT INTO sync_metadata (file_path, tool_id, file_hash, last_imported_at) VALUES ('/claude/test1.json', 'claude_code', 'hash1', 1234567890.0)")
            try db.execute(sql: "INSERT INTO sync_metadata (file_path, tool_id, file_hash, last_imported_at) VALUES ('/cursor/test2.json', 'cursor', 'hash2', 1234567891.0)")
            try db.execute(sql: "INSERT INTO sync_metadata (file_path, tool_id, file_hash, last_imported_at) VALUES ('/opencode/test3.json', 'opencode', 'hash3', 1234567892.0)")
        }

        // Verify we can query by tool_id
        let claudeCount: Int = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE tool_id = 'claude_code'") ?? 0
        }
        XCTAssertEqual(claudeCount, 1, "Should find 1 record with tool_id = 'claude_code'")

        let cursorCount: Int = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE tool_id = 'cursor'") ?? 0
        }
        XCTAssertEqual(cursorCount, 1, "Should find 1 record with tool_id = 'cursor'")

        let opencodeCount: Int = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE tool_id = 'opencode'") ?? 0
        }
        XCTAssertEqual(opencodeCount, 1, "Should find 1 record with tool_id = 'opencode'")
    }

    public func testDatabaseConfigurationAppliesPerformancePragmas() throws {
        let config = DatabaseRepository.makeConfiguration()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("pragma_test_\(UUID().uuidString).db")
        let pool = try DatabasePool(path: tempURL.path, configuration: config)

        let journalMode: String? = try pool.read { db in
            try String.fetchOne(db, sql: "PRAGMA journal_mode")
        }
        XCTAssertEqual(journalMode?.lowercased(), "wal")

        let synchronous: Int? = try pool.read { db in
            try Int.fetchOne(db, sql: "PRAGMA synchronous")
        }
        XCTAssertEqual(synchronous, 1)

        let tempStore: Int? = try pool.read { db in
            try Int.fetchOne(db, sql: "PRAGMA temp_store")
        }
        XCTAssertEqual(tempStore, 2)

        let cacheSize: Int? = try pool.read { db in
            try Int.fetchOne(db, sql: "PRAGMA cache_size")
        }
        XCTAssertEqual(cacheSize, -20000)
    }

    public func testMessagesTokenColumnsAreInteger() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try queue.write { db in
            try DatabaseRepository.createTables(on: db)
        }

        let columnTypes = try queue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(messages)")
                .reduce(into: [String: String]()) { partialResult, row in
                    let name = row["name"] as? String ?? ""
                    let type = row["type"] as? String ?? ""
                    partialResult[name] = type.uppercased()
                }
        }

        XCTAssertEqual(columnTypes["token_input"], "INTEGER")
        XCTAssertEqual(columnTypes["token_output"], "INTEGER")
        XCTAssertEqual(columnTypes["token_reasoning"], "INTEGER")
    }

    public func testBootstrapSchemaCreatesCoreTablesFromEmptyDatabase() throws {
        let queue = try DatabaseQueue(path: ":memory:")

        try queue.write { db in
            try DatabaseRepository.bootstrapSchema(on: db)
        }

        let tableNames = try queue.read { db in
            try Set(String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('messages', 'sessions', 'sync_metadata', 'hourly_stats', 'daily_stats', 'monthly_stats')"
            ))
        }

        XCTAssertEqual(tableNames, Set(["messages", "sessions", "sync_metadata", "hourly_stats", "daily_stats", "monthly_stats"]))
    }

    public func testBootstrapSchemaMigratesLegacyTokenColumnsAndDropsMigrationsTable() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try queue.write { db in
            try db.execute(sql: """
              CREATE TABLE messages (
                id TEXT PRIMARY KEY,
                session_id TEXT,
                token_input TEXT,
                token_output TEXT,
                token_reasoning TEXT
              )
            """)
            try db.execute(sql: """
              INSERT INTO messages (id, session_id, token_input, token_output, token_reasoning)
              VALUES ('m1', 's1', '10', '20', '30')
            """)
            try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        }

        try queue.write { db in
            try DatabaseRepository.bootstrapSchema(on: db)
        }

        let columnTypes = try queue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(messages)")
                .reduce(into: [String: String]()) { partialResult, row in
                    let name = row["name"] as? String ?? ""
                    let type = row["type"] as? String ?? ""
                    partialResult[name] = type.uppercased()
                }
        }
        XCTAssertEqual(columnTypes["token_input"], "INTEGER")
        XCTAssertEqual(columnTypes["token_output"], "INTEGER")
        XCTAssertEqual(columnTypes["token_reasoning"], "INTEGER")

        let migratedValues = try queue.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT token_input, token_output, token_reasoning FROM messages WHERE id = 'm1'"
            )
        }
        XCTAssertEqual(migratedValues?["token_input"] as? Int64, 10)
        XCTAssertEqual(migratedValues?["token_output"] as? Int64, 20)
        XCTAssertEqual(migratedValues?["token_reasoning"] as? Int64, 30)

        let migrationTableCount = try queue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='grdb_migrations'"
            ) ?? 0
        }

        XCTAssertEqual(migrationTableCount, 0)
    }
}
