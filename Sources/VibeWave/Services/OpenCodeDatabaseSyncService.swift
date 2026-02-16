import Foundation
import GRDB

public final class OpenCodeDatabaseSyncService: SyncServiceProtocol {
    private let sourceDatabaseURL: URL
    private let dbPool: DatabasePool
    private let syncMetadataRepo: SyncMetadataRepository
    private let messageRepo: MessageRepository
    private let sessionService: SessionService
    private let parser: MessageParsing

    public init(
        sourceDatabaseURL: URL,
        dbPool: DatabasePool,
        syncMetadataRepo: SyncMetadataRepository,
        messageRepo: MessageRepository,
        sessionService: SessionService,
        parser: MessageParsing
    ) {
        self.sourceDatabaseURL = sourceDatabaseURL
        self.dbPool = dbPool
        self.syncMetadataRepo = syncMetadataRepo
        self.messageRepo = messageRepo
        self.sessionService = sessionService
        self.parser = parser
    }

    public func syncDirectory(at url: URL, toolId: String) async throws -> SyncProgress {
        let result = try syncDatabase(toolId: toolId)
        if result.importedCount > 0 {
            return SyncProgress(
                totalFiles: 1,
                currentFile: "",
                importedFiles: 1,
                skippedFiles: 0,
                skippedFilePaths: [],
                importedFilePaths: [sourceDatabaseURL.path]
            )
        }
        return SyncProgress(
            totalFiles: 1,
            currentFile: "",
            importedFiles: 0,
            skippedFiles: 1,
            skippedFilePaths: [sourceDatabaseURL.path],
            importedFilePaths: []
        )
    }

    public func syncFile(at url: URL, toolId: String) async throws -> (Int, Set<String>, String) {
        let result = try syncDatabase(toolId: toolId)
        return (result.importedCount, result.affectedSessionIds, toolId)
    }

    public func syncFiles(at urls: [URL], toolId: String) async throws -> (Int, Set<String>, String) {
        let result = try syncDatabase(toolId: toolId)
        return (result.importedCount, result.affectedSessionIds, toolId)
    }
}

private extension OpenCodeDatabaseSyncService {
    static let batchSize = 1000
    static let repairBatchSize = 400

    struct SyncResult {
        let importedCount: Int
        let affectedSessionIds: Set<String>
    }

    func syncDatabase(toolId: String) throws -> SyncResult {
        guard FileManager.default.fileExists(atPath: sourceDatabaseURL.path) else {
            throw SyncError.databaseNotFound(sourceDatabaseURL.path)
        }

        let sourceQueue = try DatabaseQueue(path: sourceDatabaseURL.path)
        let metadataKey = sourceDatabaseURL.path
        let existing = syncMetadataRepo.fetch(filePath: metadataKey)
        var cursorUpdated = existing?.lastMessageTime ?? 0
        var cursorMessageID = existing?.fileHash ?? ""
        var totalImported = 0
        var affectedSessionIds = Set<String>()
        var importedCreatedTimes: [TimeInterval] = []

        while true {
            let rows = try sourceQueue.read { db in
                try Row.fetchAll(
                    db,
                    sql: """
                        SELECT id, session_id, data, time_updated
                        FROM message
                        WHERE time_updated > ?
                           OR (time_updated = ? AND id > ?)
                        ORDER BY time_updated ASC, id ASC
                        LIMIT ?
                    """,
                    arguments: [cursorUpdated, cursorUpdated, cursorMessageID, Self.batchSize]
                )
            }

            guard !rows.isEmpty else { break }

            var messagesToInsert: [Message] = []
            for row in rows {
                guard let messageId = row["id"] as? String,
                      let sessionId = row["session_id"] as? String,
                      let payload = row["data"] as? String,
                      let timeUpdated = row["time_updated"] as? Int64,
                      let payloadData = payload.data(using: .utf8),
                      let enrichedData = enrichMessageData(payloadData, messageId: messageId, sessionId: sessionId) else {
                    continue
                }

                let parseResult = parser.parseMessages(from: enrichedData, sourceURL: sourceDatabaseURL)
                if !parseResult.messages.isEmpty {
                    messagesToInsert.append(contentsOf: parseResult.messages)
                    affectedSessionIds.formUnion(parseResult.affectedSessionIds)
                    importedCreatedTimes.append(contentsOf: parseResult.messages.compactMap {
                        guard let created = $0.time?.created else { return nil }
                        return parseMessageTimestamp(created)
                    })
                }

                cursorUpdated = timeUpdated
                cursorMessageID = messageId
            }

            if !messagesToInsert.isEmpty {
                let snapshot = messagesToInsert
                try dbPool.write { db in
                    try self.messageRepo.insert(messages: snapshot, in: db)
                }
                totalImported += messagesToInsert.count
            }
        }

        let previousFirst = existing?.firstMessageTime
        let runFirst = importedCreatedTimes.min().map { Int64($0 * 1000) }
        let firstMessageTime = minNonNil(previousFirst, runFirst)
        let metadata = SyncMetadataRecord(
            filePath: metadataKey,
            toolId: toolId,
            fileHash: cursorMessageID,
            lastImportedAt: Int64(Date().timeIntervalSince1970 * 1000),
            messageCount: Int64((existing?.messageCount ?? 0) + Int64(totalImported)),
            firstMessageTime: firstMessageTime,
            lastMessageTime: cursorUpdated,
            isFileExists: true
        )

        try dbPool.write { db in
            try self.syncMetadataRepo.upsert(metadata, in: db)
        }

        if !affectedSessionIds.isEmpty {
            try sessionService.recalculateSessions(for: affectedSessionIds)
        }

        _ = try repairMissingAssistantProviderAndModel(
            sourceQueue: sourceQueue,
            toolId: toolId
        )

        return SyncResult(importedCount: totalImported, affectedSessionIds: affectedSessionIds)
    }

    func enrichMessageData(_ data: Data, messageId: String, sessionId: String) -> Data? {
        guard var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        object["id"] = messageId
        object["sessionID"] = sessionId
        object["session_id"] = sessionId
        return try? JSONSerialization.data(withJSONObject: object)
    }

    func parseMessageTimestamp(_ createdStr: String) -> TimeInterval? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: createdStr) {
            return date.timeIntervalSince1970
        }
        if let numeric = Double(createdStr) {
            return numeric >= 1_000_000_000_000 ? numeric / 1000.0 : numeric
        }
        return nil
    }

    func minNonNil(_ lhs: Int64?, _ rhs: Int64?) -> Int64? {
        switch (lhs, rhs) {
        case (let left?, let right?):
            return min(left, right)
        case (let left?, nil):
            return left
        case (nil, let right?):
            return right
        default:
            return nil
        }
    }

    func repairMissingAssistantProviderAndModel(sourceQueue: DatabaseQueue, toolId: String) throws -> Int {
        let missingAssistantIds: [String] = try dbPool.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT id
                    FROM messages
                    WHERE role = 'assistant'
                      AND COALESCE(tool_id, 'opencode') = ?
                      AND (
                        provider_id IS NULL OR provider_id = ''
                        OR model_id IS NULL OR model_id = ''
                      )
                """,
                arguments: [toolId]
            )
        }

        guard !missingAssistantIds.isEmpty else { return 0 }

        var repairedCount = 0
        for chunkStart in stride(from: 0, to: missingAssistantIds.count, by: Self.repairBatchSize) {
            let chunkEnd = min(chunkStart + Self.repairBatchSize, missingAssistantIds.count)
            let chunkIds = Array(missingAssistantIds[chunkStart..<chunkEnd])
            let placeholders = Array(repeating: "?", count: chunkIds.count).joined(separator: ",")

            let sourceRows = try sourceQueue.read { db in
                try Row.fetchAll(
                    db,
                    sql: """
                        SELECT
                          id,
                          COALESCE(
                            NULLIF(json_extract(data, '$.providerID'), ''),
                            NULLIF(json_extract(data, '$.provider_id'), ''),
                            NULLIF(json_extract(data, '$.model.providerID'), '')
                          ) AS provider_id,
                          COALESCE(
                            NULLIF(json_extract(data, '$.modelID'), ''),
                            NULLIF(json_extract(data, '$.model_id'), ''),
                            NULLIF(json_extract(data, '$.model.modelID'), '')
                          ) AS model_id
                        FROM message
                        WHERE id IN (\(placeholders))
                    """,
                    arguments: StatementArguments(chunkIds)
                )
            }

            let updates: [(id: String, providerId: String, modelId: String)] = sourceRows.compactMap { row in
                guard let id = row["id"] as? String,
                      let providerId = row["provider_id"] as? String,
                      let modelId = row["model_id"] as? String,
                      !providerId.isEmpty,
                      !modelId.isEmpty else {
                    return nil
                }
                return (id: id, providerId: providerId, modelId: modelId)
            }

            guard !updates.isEmpty else { continue }

            try dbPool.write { db in
                let statement = try db.makeStatement(
                    sql: """
                        UPDATE messages
                        SET provider_id = ?, model_id = ?
                        WHERE id = ?
                          AND role = 'assistant'
                          AND COALESCE(tool_id, 'opencode') = ?
                          AND (
                            provider_id IS NULL OR provider_id = ''
                            OR model_id IS NULL OR model_id = ''
                          )
                    """
                )

                for update in updates {
                    let args: StatementArguments = [
                        update.providerId,
                        update.modelId,
                        update.id,
                        toolId
                    ]
                    try statement.execute(arguments: args)
                    if db.changesCount > 0 {
                        repairedCount += Int(db.changesCount)
                    }
                }
            }
        }

        return repairedCount
    }
}
