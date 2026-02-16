import XCTest
import GRDB
@testable import VibeWave

final class SyncMetadataRepositoryTests: XCTestCase {
    var dbPool: DatabasePool!
    var repository: SyncMetadataRepository!
    private var tempDBPath: String?
    
    override func setUp() {
        super.setUp()
        // DatabasePool requires WAL mode, which is not supported by :memory:
        let tempDBFile = FileManager.default.temporaryDirectory
          .appendingPathComponent("test_sync_metadata_repository-\(UUID().uuidString).db")
        tempDBPath = tempDBFile.path
        dbPool = try! DatabasePool(path: tempDBFile.path)
        repository = SyncMetadataRepository(dbPool: dbPool)
        
        try! dbPool.write { db in
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
            
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_sync_metadata_tool ON sync_metadata(tool_id)
            """)
        }
    }
    
    override func tearDown() {
        repository = nil
        try? dbPool.close()
        dbPool = nil
        if let path = tempDBPath {
          try? FileManager.default.removeItem(atPath: path)
          try? FileManager.default.removeItem(atPath: path + "-wal")
          try? FileManager.default.removeItem(atPath: path + "-shm")
        }
        tempDBPath = nil
        super.tearDown()
    }
    
    func testUpsertAndFetch() {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let record = SyncMetadataRecord(
            filePath: "/test/file.json",
            toolId: "opencode",
            fileHash: "abc123",
            lastImportedAt: timestamp,
            messageCount: 5
        )
        
        try! repository.upsert(record)
        let fetched = repository.fetch(filePath: "/test/file.json")
        
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.filePath, "/test/file.json")
        XCTAssertEqual(fetched?.toolId, "opencode")
        XCTAssertEqual(fetched?.fileHash, "abc123")
        XCTAssertEqual(fetched?.messageCount, 5)
    }
    
    func testFetchNonExistent() {
        let fetched = repository.fetch(filePath: "/nonexistent/file.json")
        XCTAssertNil(fetched)
    }
    
    func testDelete() {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let record = SyncMetadataRecord(
            filePath: "/test/file.json",
            toolId: "opencode",
            fileHash: "abc123",
            lastImportedAt: timestamp
        )
        try! repository.upsert(record)
        
        try! repository.delete(filePath: "/test/file.json")
        let fetched = repository.fetch(filePath: "/test/file.json")
        
        XCTAssertNil(fetched)
    }
    
    func testFetchByTool() {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let opencodeRecord = SyncMetadataRecord(
            filePath: "/opencode.json",
            toolId: "opencode",
            fileHash: "hash1",
            lastImportedAt: timestamp
        )
        let claudeRecord = SyncMetadataRecord(
            filePath: "/claude.json",
            toolId: "claude_code",
            fileHash: "hash2",
            lastImportedAt: timestamp
        )
        
        try! repository.upsert(opencodeRecord)
        try! repository.upsert(claudeRecord)
        
        let opencodeFiles = repository.fetchAll(toolId: "opencode")
        let claudeFiles = repository.fetchAll(toolId: "claude_code")
        let allFiles = repository.fetchAll()
        
        XCTAssertEqual(opencodeFiles.count, 1)
        XCTAssertEqual(claudeFiles.count, 1)
        XCTAssertEqual(allFiles.count, 2)
    }
    
    func testDefaultToolId() {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let record = SyncMetadataRecord(
            filePath: "/test.json",
            fileHash: "abc",
            lastImportedAt: timestamp
        )
        
        XCTAssertEqual(record.toolId, "opencode")
    }
}
