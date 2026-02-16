import Foundation
import GRDB

public enum BackupKind: String, CaseIterable, Codable {
    case automatic
    case manual
    case system
    case legacy

    public var displayName: String {
        switch self {
        case .automatic:
            return L10n.settingsBackupKindAutomatic
        case .manual:
            return L10n.settingsBackupKindManual
        case .system:
            return L10n.settingsBackupKindSystem
        case .legacy:
            return L10n.settingsBackupKindLegacy
        }
    }
}

public struct BackupInfo: Identifiable, Equatable {
    public var id: String { fileURL.path }
    public let fileURL: URL
    public let createdAt: Date
    public let fileSize: Int64
    public let kind: BackupKind
}

public final class BackupManager {
    private let backupDirectory: URL
    private let additionalSearchDirectories: [URL]
    private let fileManager: FileManager
    private let logger = AppLogger(category: "BackupManager")

    public init(
        backupDirectory: URL,
        additionalSearchDirectories: [URL] = [],
        fileManager: FileManager = .default
    ) {
        self.backupDirectory = backupDirectory
        self.additionalSearchDirectories = additionalSearchDirectories.filter { $0 != backupDirectory }
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    public func createBackup(from reader: some DatabaseReader, kind: BackupKind) async throws -> BackupInfo {
        let createdAt = Date()
        let backupFileName = Self.makeBackupFileName(kind: kind, createdAt: createdAt)
        let backupURL = backupDirectory.appendingPathComponent(backupFileName)

        try await runBlockingIO {
            if self.fileManager.fileExists(atPath: backupURL.path) {
                try self.fileManager.removeItem(at: backupURL)
            }

            let destination = try DatabaseQueue(path: backupURL.path)
            try reader.backup(to: destination)

            try self.fileManager.setAttributes([.modificationDate: createdAt], ofItemAtPath: backupURL.path)
        }

        let attributes = try fileManager.attributesOfItem(atPath: backupURL.path)
        let fileSize = (attributes[.size] as? Int64) ?? 0

        return BackupInfo(
            fileURL: backupURL,
            createdAt: createdAt,
            fileSize: fileSize,
            kind: kind
        )
    }

    public func listBackups() async throws -> [BackupInfo] {
        let directories = [backupDirectory] + additionalSearchDirectories
        var resultsByPath: [String: BackupInfo] = [:]

        for directory in directories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }

            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )

            for url in contents {
                if let info = parseBackupInfo(from: url) {
                    resultsByPath[info.fileURL.path] = info
                }
            }
        }

        return resultsByPath.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func restoreBackup(_ backup: BackupInfo, to writer: some DatabaseWriter) async throws {
        guard fileManager.fileExists(atPath: backup.fileURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try await runBlockingIO {
            let source = try DatabaseQueue(path: backup.fileURL.path)
            try source.backup(to: writer)

            try? writer.writeWithoutTransaction { db in
                try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
            }
        }
    }

    public func deleteBackup(_ backup: BackupInfo) async throws {
        guard fileManager.fileExists(atPath: backup.fileURL.path) else {
            return
        }

        try fileManager.removeItem(at: backup.fileURL)
    }

    public func cleanupOldBackups(maxCount: Int, kind: BackupKind) async throws {
        guard maxCount > 0 else { return }

        let backups = try await listBackups().filter { $0.kind == kind }
        guard backups.count > maxCount else { return }

        let toDelete = backups.dropFirst(maxCount)
        for backup in toDelete {
            do {
                try await deleteBackup(backup)
            } catch {
                logger.warn("Failed to delete old backup at \(backup.fileURL.path): \(error)")
            }
        }
    }
}

// MARK: - Helpers

extension BackupManager {
    private static let utcTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let legacyTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private func runBlockingIO<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func makeBackupFileName(kind: BackupKind, createdAt: Date) -> String {
        let timestamp = utcTimestampFormatter.string(from: createdAt)
        let uuid = UUID().uuidString

        let prefix: String
        switch kind {
        case .automatic:
            prefix = "auto_backup_"
        case .manual:
            prefix = "manual_backup_"
        case .system:
            prefix = "system_backup_"
        case .legacy:
            prefix = "manual_backup_"
        }

        return "\(prefix)\(timestamp)_\(uuid).db"
    }

    private func parseBackupInfo(from url: URL) -> BackupInfo? {
        let name = url.lastPathComponent

        if let (kind, createdAt) = Self.parseNewStyle(name: name) {
            let fileSize = Self.fileSize(at: url)
            return BackupInfo(fileURL: url, createdAt: createdAt, fileSize: fileSize, kind: kind)
        }

        if let legacyDate = Self.parseLegacyTimestampFromVibeWaveBackupName(name) {
            let fileSize = Self.fileSize(at: url)
            return BackupInfo(fileURL: url, createdAt: legacyDate, fileSize: fileSize, kind: .legacy)
        }

        if name.hasPrefix("backup_"), url.pathExtension == "db" {
            let createdAt = Self.modificationDate(at: url) ?? Date.distantPast
            let fileSize = Self.fileSize(at: url)
            return BackupInfo(fileURL: url, createdAt: createdAt, fileSize: fileSize, kind: .legacy)
        }

        return nil
    }

    private static func parseNewStyle(name: String) -> (BackupKind, Date)? {
        let candidates: [(prefix: String, kind: BackupKind)] = [
            ("auto_backup_", .automatic),
            ("manual_backup_", .manual),
            ("system_backup_", .system),
        ]

        guard name.hasSuffix(".db") else { return nil }

        for candidate in candidates {
            if name.hasPrefix(candidate.prefix) {
                let rest = name.dropFirst(candidate.prefix.count)
                guard let underscoreIndex = rest.firstIndex(of: "_") else { return nil }
                let timestamp = String(rest[..<underscoreIndex])
                if let date = utcTimestampFormatter.date(from: timestamp) {
                    return (candidate.kind, date)
                }
                return nil
            }
        }

        return nil
    }

    private static func parseLegacyTimestampFromVibeWaveBackupName(_ name: String) -> Date? {
        // Example: vibewave.db.backup.20260205-170547
        let prefix = "vibewave.db.backup."
        guard name.hasPrefix(prefix) else { return nil }
        let timestamp = String(name.dropFirst(prefix.count))
        return legacyTimestampFormatter.date(from: timestamp)
    }

    private static func modificationDate(at url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    }

    private static func fileSize(at url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
}
