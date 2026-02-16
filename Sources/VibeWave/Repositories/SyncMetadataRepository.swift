import Foundation
import GRDB

public final class SyncMetadataRepository {
    public let dbPool: DatabasePool
    
    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }
    
    public func createSchemaIfNeeded() throws {
        try dbPool.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS sync_metadata (
                  file_path TEXT PRIMARY KEY,
                  tool_id TEXT,
                  file_hash TEXT,
                  last_imported_at INTEGER,
                  message_count INTEGER,
                  first_message_time INTEGER,
                  last_message_time INTEGER,
                  is_file_exists INTEGER
                )
                """)
        }
    }
    
    public func upsert(_ record: SyncMetadataRecord) throws {
        try dbPool.write { db in
            try upsert(record, in: db)
        }
    }

    public func upsert(_ record: SyncMetadataRecord, in db: Database) throws {
        try db.execute(sql: """
            INSERT OR REPLACE INTO sync_metadata (
              file_path, tool_id, file_hash, last_imported_at,
              message_count, first_message_time, last_message_time, is_file_exists
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [
            record.filePath, record.toolId, record.fileHash,
            record.lastImportedAt,
            record.messageCount ?? 0, record.firstMessageTime ?? 0,
            record.lastMessageTime ?? 0, record.isFileExists ? 1 : 0
        ])
    }
    
    public func fetch(filePath: String) -> SyncMetadataRecord? {
        var result: SyncMetadataRecord?
        try? dbPool.read { db in
            if let row = try? Row.fetchOne(
                db,
                sql: "SELECT * FROM sync_metadata WHERE file_path = ?",
                arguments: [filePath]
            ) {
                result = SyncMetadataRecord(row: row)
            }
        }
        return result
    }
    
    public func fetchAll(toolId: String? = nil) -> [SyncMetadataRecord] {
        var records: [SyncMetadataRecord] = []
        try? dbPool.read { db in
            let rows: [Row]

            if let tool = toolId {
                rows = (try? Row.fetchAll(
                    db,
                    sql: "SELECT * FROM sync_metadata WHERE tool_id = ?",
                    arguments: [tool]
                )) ?? []
            } else {
                rows = (try? Row.fetchAll(
                    db,
                    sql: "SELECT * FROM sync_metadata"
                )) ?? []
            }

            records = rows.map { SyncMetadataRecord(row: $0) }
        }
        return records
    }

    public func delete(filePath: String) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM sync_metadata WHERE file_path = ?",
                arguments: [filePath]
            )
        }
    }
}

extension SyncMetadataRecord {
    init(row: Row) {
        self.filePath = row["file_path"] as? String ?? ""
        self.toolId = row["tool_id"] as? String ?? "opencode"
        self.fileHash = row["file_hash"] as? String ?? ""
        self.lastImportedAt = row["last_imported_at"] as? Int64 ?? 0
        self.messageCount = row["message_count"] as? Int64
        self.firstMessageTime = row["first_message_time"] as? Int64
        self.lastMessageTime = row["last_message_time"] as? Int64
        self.isFileExists = (row["is_file_exists"] as? Int64 ?? 0) != 0
    }
}
