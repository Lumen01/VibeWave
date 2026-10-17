import Foundation
import GRDB
import CommonCrypto

public protocol MessageParsing {
    func parseMessages(from url: URL) -> ParseResult
    func parseMessages(from data: Data, sourceURL: URL) -> ParseResult
}

public struct ParseResult {
    public let messages: [Message]
    public let affectedSessionIds: Set<String>
    public let error: Error?
    
    public init(messages: [Message], affectedSessionIds: Set<String>, error: Error? = nil) {
        self.messages = messages
        self.affectedSessionIds = affectedSessionIds
        self.error = error
    }
}

public enum SyncError: Error {
    case notAJsonFile(String)
    case notADirectory(String)
    case databaseNotFound(String)
    case fileUnstable(String)
    case parseError(Error)
    case databaseError(Error)
}

extension SyncError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAJsonFile(let path):
            return "Not a JSON file: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .databaseNotFound(let path):
            return "Database not found: \(path)"
        case .fileUnstable(let path):
            return "File is unstable: \(path)"
        case .parseError(let error):
            return "Parse error: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}

public struct SyncProgress {
    public var totalFiles: Int
    public var currentFile: String
    public var importedFiles: Int
    public var skippedFiles: Int
    public var skippedFilePaths: [String]
    public var importedFilePaths: [String]
    public var currentError: Error?
    
    public init(
        totalFiles: Int = 0,
        currentFile: String = "",
        importedFiles: Int = 0,
        skippedFiles: Int = 0,
        skippedFilePaths: [String] = [],
        importedFilePaths: [String] = [],
        currentError: Error? = nil
    ) {
        self.totalFiles = totalFiles
        self.currentFile = currentFile
        self.importedFiles = importedFiles
        self.skippedFiles = skippedFiles
        self.skippedFilePaths = skippedFilePaths
        self.importedFilePaths = importedFilePaths
        self.currentError = currentError
    }
}

public final class IncrementalSyncService: SyncServiceProtocol {
    public let dbPool: DatabasePool
    private let syncMetadataRepo: SyncMetadataRepository
    private let messageRepo: MessageRepository
    private let sessionService: SessionService
    private let parser: MessageParsing
    private let bulkInsertMessageThreshold = 2000
    private let bulkInsertFileThreshold = 100
    private let skippedPathDiagnosticLimit = 100

    public init(
        dbPool: DatabasePool,
        syncMetadataRepo: SyncMetadataRepository,
        messageRepo: MessageRepository,
        sessionService: SessionService,
        parser: MessageParsing
    ) {
        self.dbPool = dbPool
        self.syncMetadataRepo = syncMetadataRepo
        self.messageRepo = messageRepo
        self.sessionService = sessionService
        self.parser = parser
    }

    public func syncFile(at url: URL, toolId: String = "opencode") async throws -> (Int, Set<String>, String) {
        let (data, fileHash) = try await readStableFile(at: url)

        let existingMetadata = syncMetadataRepo.fetch(filePath: url.path)

        if let existing = existingMetadata, existing.fileHash == fileHash {
            return (0, [], toolId)
        }

        let parseResult = parser.parseMessages(from: data, sourceURL: url)
        if let error = parseResult.error { throw SyncError.parseError(error) }
        let (firstMessageTime, lastMessageTime) = messageTimeRange(from: parseResult.messages)

        let metadata = SyncMetadataRecord(
            filePath: url.path,
            toolId: toolId,
            fileHash: fileHash,
            lastImportedAt: Int64(Date().timeIntervalSince1970 * 1000),
            messageCount: Int64(parseResult.messages.count),
            firstMessageTime: firstMessageTime.map { Int64($0 * 1000) },
            lastMessageTime: lastMessageTime.map { Int64($0 * 1000) },
            isFileExists: true
        )

        let messagesToInsert = parseResult.messages

        try await dbPool.write { db in
            try self.messageRepo.insert(messages: messagesToInsert, in: db)
            try self.syncMetadataRepo.upsert(metadata, in: db)
        }

        return (parseResult.messages.count, parseResult.affectedSessionIds, toolId)
    }

    public func syncFiles(at urls: [URL], toolId: String = "opencode") async throws -> (Int, Set<String>, String) {
        guard !urls.isEmpty else { return (0, [], toolId) }

        var totalImported = 0
        var affectedSessionIds = Set<String>()
        var messagesToInsert: [Message] = []
        var metadataToUpsert: [SyncMetadataRecord] = []

        for url in urls {
            let (data, fileHash) = try await readStableFile(at: url)
            let existingMetadata = syncMetadataRepo.fetch(filePath: url.path)

            if let existing = existingMetadata, existing.fileHash == fileHash {
                continue
            }

            let parseResult = parser.parseMessages(from: data, sourceURL: url)
            if let error = parseResult.error { throw SyncError.parseError(error) }
            if !parseResult.messages.isEmpty {
                messagesToInsert.append(contentsOf: parseResult.messages)
                affectedSessionIds.formUnion(parseResult.affectedSessionIds)
                totalImported += parseResult.messages.count
            }

            let (firstMessageTime, lastMessageTime) = messageTimeRange(from: parseResult.messages)
            let metadata = SyncMetadataRecord(
                filePath: url.path,
                toolId: toolId,
                fileHash: fileHash,
                lastImportedAt: Int64(Date().timeIntervalSince1970 * 1000),
                messageCount: Int64(parseResult.messages.count),
                firstMessageTime: firstMessageTime.map { Int64($0 * 1000) },
                lastMessageTime: lastMessageTime.map { Int64($0 * 1000) },
                isFileExists: true
            )
            metadataToUpsert.append(metadata)
        }

        if !messagesToInsert.isEmpty || !metadataToUpsert.isEmpty {
            let messagesToInsertSnapshot = messagesToInsert
            let metadataToUpsertSnapshot = metadataToUpsert

            try await dbPool.write { db in
                try self.messageRepo.insert(messages: messagesToInsertSnapshot, in: db)
                for record in metadataToUpsertSnapshot {
                    try self.syncMetadataRepo.upsert(record, in: db)
                }
            }
        }

        return (totalImported, affectedSessionIds, toolId)
    }

    public func syncDirectory(at url: URL, toolId: String = "opencode") async throws -> SyncProgress {

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SyncError.notADirectory(url.path)
        }

        var progress = SyncProgress(totalFiles: 0, currentFile: "")
        var aggregatedSessionIds = Set<String>()
        var pendingMessages: [Message] = []
        var pendingMetadata: [SyncMetadataRecord] = []
        let metadataByPath = Dictionary(
            syncMetadataRepo.fetchAll(toolId: toolId).map { ($0.filePath, $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        func flushPending() async throws {
            guard !pendingMessages.isEmpty || !pendingMetadata.isEmpty else { return }
            let messagesSnapshot = pendingMessages
            let metadataSnapshot = pendingMetadata
            pendingMessages.removeAll(keepingCapacity: true)
            pendingMetadata.removeAll(keepingCapacity: true)

            try await dbPool.write { db in
                try self.messageRepo.insert(messages: messagesSnapshot, in: db)
                for record in metadataSnapshot {
                    try self.syncMetadataRepo.upsert(record, in: db)
                }
            }
        }

        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles, .skipsPackageDescendants])
        let excludedDirs = Set(["node_modules", ".git", ".vscode", ".idea", "build", "dist"])

        func recordSkipped(_ path: String) {
            progress.skippedFiles += 1
            if progress.skippedFilePaths.count < skippedPathDiagnosticLimit {
                progress.skippedFilePaths.append(path)
            }
        }

        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues?.isDirectory == true {
                if excludedDirs.contains(fileURL.lastPathComponent) {
                    enumerator?.skipDescendants()
                }
                continue
            }

            guard fileURL.pathExtension == "json" else {
                continue
            }

            progress.currentFile = fileURL.path
            progress.totalFiles += 1

            guard let stableFile = try? await readStableFile(at: fileURL) else {
                recordSkipped(fileURL.path)
                continue
            }

            let data = stableFile.data
            let fileHash = stableFile.hash
            let existingMetadata = metadataByPath[fileURL.path]

            if let existing = existingMetadata, existing.fileHash == fileHash {
                recordSkipped(fileURL.path)
                continue
            }

            let parseResult = parser.parseMessages(from: data, sourceURL: fileURL)
            if let error = parseResult.error { throw SyncError.parseError(error) }
            let (firstMessageTime, lastMessageTime) = messageTimeRange(from: parseResult.messages)
            let metadata = SyncMetadataRecord(
                filePath: fileURL.path,
                toolId: toolId,
                fileHash: fileHash,
                lastImportedAt: Int64(Date().timeIntervalSince1970 * 1000),
                messageCount: Int64(parseResult.messages.count),
                firstMessageTime: firstMessageTime.map { Int64($0 * 1000) },
                lastMessageTime: lastMessageTime.map { Int64($0 * 1000) },
                isFileExists: true
            )
            pendingMetadata.append(metadata)

            if parseResult.messages.isEmpty {
                recordSkipped(fileURL.path)
            } else {
                pendingMessages.append(contentsOf: parseResult.messages)
                aggregatedSessionIds.formUnion(parseResult.affectedSessionIds)
                progress.importedFiles += 1
                progress.importedFilePaths.append(fileURL.path)
            }

            if pendingMessages.count >= bulkInsertMessageThreshold || pendingMetadata.count >= bulkInsertFileThreshold {
                try await flushPending()
            }
        }

        progress.currentFile = ""

        try await flushPending()

        if !aggregatedSessionIds.isEmpty {
            try sessionService.recalculateSessions(for: aggregatedSessionIds)
        }
        return progress
    }

    private func messageTimeRange(from messages: [Message]) -> (TimeInterval?, TimeInterval?) {
        var firstMessageTime: TimeInterval?
        var lastMessageTime: TimeInterval?

        for message in messages {
            guard let createdStr = message.time?.created,
                  let timestamp = parseMessageTimestamp(createdStr) else {
                continue
            }

            if let currentFirst = firstMessageTime {
                firstMessageTime = min(currentFirst, timestamp)
            } else {
                firstMessageTime = timestamp
            }

            if let currentLast = lastMessageTime {
                lastMessageTime = max(currentLast, timestamp)
            } else {
                lastMessageTime = timestamp
            }
        }

        return (firstMessageTime, lastMessageTime)
    }

    public func waitForFileStable(at url: URL) async throws -> String {
        try await readStableFile(at: url).hash
    }

    private func readStableFile(at url: URL) async throws -> (data: Data, hash: String) {
        let maxAttempts = 3
        let delayBetweenAttempts: TimeInterval = 0.05

        for _ in 1...maxAttempts {
            let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let data = try Data(contentsOf: url)
            let after = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])

            if before.fileSize == after.fileSize && before.contentModificationDate == after.contentModificationDate {
                return (data, calculateFileHash(for: data))
            }

            try await Task.sleep(nanoseconds: UInt64(delayBetweenAttempts * 1_000_000_000))
        }

        throw SyncError.fileUnstable(url.path)
    }

    private func calculateFileHash(for data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func parseMessageTimestamp(_ createdStr: String) -> TimeInterval? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: createdStr) {
            return date.timeIntervalSince1970
        }
        if let numeric = Double(createdStr) {
            // Heuristic: millisecond timestamps are typically >= 1e12
            return numeric >= 1_000_000_000_000 ? numeric / 1000.0 : numeric
        }
        return nil
    }
}
