import GRDB
import Foundation

public struct MessageRecord: TableRecord {
    public static let databaseTableName = "messages"

    // OpenCode Message mapping
    var id: String
    var sessionId: String
    var role: String?
    var createdAt: Int64?
    var completedAt: Int64?
    var providerId: String?
    var modelId: String?
    var agent: String?
    var mode: String?
    var variant: String?
    var projectRoot: String?
    var projectCwd: String?
    var tokenInput: Int?
    var tokenOutput: Int?
    var tokenReasoning: Int?
    var cacheRead: Int
    var cacheWrite: Int
    var cost: Double
    var summaryTitle: String?
    var summaryTotalAdditions: Int
    var summaryTotalDeletions: Int
    var summaryFileCount: Int
    var finish: String?
    var diffFiles: String?

    enum Columns {
        static let id = Column("id")
        static let sessionId = Column("session_id")
        static let role = Column("role")
        static let createdAt = Column("created_at")
        static let completedAt = Column("completed_at")
        static let providerId = Column("provider_id")
        static let modelId = Column("model_id")
        static let agent = Column("agent")
        static let mode = Column("mode")
        static let variant = Column("variant")
        static let projectRoot = Column("project_root")
        static let projectCwd = Column("project_cwd")
        static let tokenInput = Column("token_input")
        static let tokenOutput = Column("token_output")
        static let tokenReasoning = Column("token_reasoning")
        static let cacheRead = Column("cache_read")
        static let cacheWrite = Column("cache_write")
        static let cost = Column("cost")
        static let summaryTitle = Column("summary_title")
        static let summaryTotalAdditions = Column("summary_total_additions")
        static let summaryTotalDeletions = Column("summary_total_deletions")
        static let summaryFileCount = Column("summary_file_count")
        static let finish = Column("finish")
        static let diffFiles = Column("diff_files")
    }

    init(row: Row) {
        self.id = row[Columns.id] as String
        self.sessionId = row[Columns.sessionId] as String
        self.role = row[Columns.role] as String?
        self.createdAt = row[Columns.createdAt] as Int64?
        self.completedAt = row[Columns.completedAt] as Int64?
        self.providerId = row[Columns.providerId] as String?
        self.modelId = row[Columns.modelId] as String?
        self.agent = row[Columns.agent] as String?
        self.mode = row[Columns.mode] as String?
        self.variant = row[Columns.variant] as String?
        self.projectRoot = row[Columns.projectRoot] as String?
        self.projectCwd = row[Columns.projectCwd] as String?
        self.tokenInput = Self.intValue(from: row, column: Columns.tokenInput)
        self.tokenOutput = Self.intValue(from: row, column: Columns.tokenOutput)
        self.tokenReasoning = Self.intValue(from: row, column: Columns.tokenReasoning)
        self.cacheRead = Self.intValue(from: row, column: Columns.cacheRead) ?? 0
        self.cacheWrite = Self.intValue(from: row, column: Columns.cacheWrite) ?? 0
        self.cost = Self.doubleValue(from: row, column: Columns.cost) ?? 0.0
        self.summaryTitle = row[Columns.summaryTitle] as String?
        self.summaryTotalAdditions = Self.intValue(from: row, column: Columns.summaryTotalAdditions) ?? 0
        self.summaryTotalDeletions = Self.intValue(from: row, column: Columns.summaryTotalDeletions) ?? 0
        self.summaryFileCount = Self.intValue(from: row, column: Columns.summaryFileCount) ?? 0
        self.finish = row[Columns.finish] as String?
        self.diffFiles = row[Columns.diffFiles] as String?
    }

    init(_ message: Message) {
        // Map fields from OpenCode Message to OpenCode MessageRecord
        self.id = message.id
        self.sessionId = message.sessionID
        self.role = message.role

        // Convert time.created to Unix timestamp (TimeInterval)
        // Time can be: ISO8601 string, or millisecond timestamp (as string/number)
        if let createdStr = message.time?.created {
            let df = ISO8601DateFormatter()

            if let date = df.date(from: createdStr) {
                self.createdAt = Int64(date.timeIntervalSince1970 * 1000)
            } else if let timestamp = Double(createdStr) {
                // Heuristic: millisecond timestamps are typically >= 1e12
                let seconds = timestamp >= 1_000_000_000_000 ? timestamp / 1000.0 : timestamp
                self.createdAt = Int64(seconds * 1000)
            } else {
                self.createdAt = nil
            }
        } else {
            self.createdAt = nil
        }

        if let completedStr = message.time?.completed {
            let df = ISO8601DateFormatter()

            if let date = df.date(from: completedStr) {
                self.completedAt = Int64(date.timeIntervalSince1970 * 1000)
            } else if let timestamp = Double(completedStr) {
                // Heuristic: millisecond timestamps are typically >= 1e12
                let seconds = timestamp >= 1_000_000_000_000 ? timestamp / 1000.0 : timestamp
                self.completedAt = Int64(seconds * 1000)
            } else {
                self.completedAt = nil
            }
        } else {
            self.completedAt = nil
        }

        self.providerId = message.providerID
        self.modelId = message.modelID
        self.agent = message.agent
        self.mode = message.mode
        self.variant = message.variant
        self.projectRoot = message.root
        self.projectCwd = message.cwd
        self.tokenInput = message.tokens?.input
        self.tokenOutput = message.tokens?.output
        self.tokenReasoning = message.tokens?.reasoning
        let cr: Int = message.tokens?.cacheRead ?? 0
        let cw: Int = message.tokens?.cacheWrite ?? 0
        self.cacheRead = cr
        self.cacheWrite = cw
        let cst: Double = message.cost ?? 0.0
        self.cost = cst
        
        // Handle summary field
        if let summary = message.summary {
            self.summaryTitle = summary.title
            self.summaryTotalAdditions = summary.totalAdditions
            self.summaryTotalDeletions = summary.totalDeletions
            self.summaryFileCount = summary.fileCount

            let files = summary.diffs?.compactMap { $0.file } ?? []
            let uniqueFiles = Set(files)
            self.diffFiles = uniqueFiles.isEmpty ? nil : uniqueFiles.joined(separator: ",")
        } else {
            self.summaryTitle = nil
            self.summaryTotalAdditions = 0
            self.summaryTotalDeletions = 0
            self.summaryFileCount = 0
            self.diffFiles = nil
        }

        self.finish = message.finish
    }

    private static func intValue(from row: Row, column: Column) -> Int? {
        if let value = row[column] as Int? {
            return value
        }
        if let value = row[column] as Int64? {
            return Int(value)
        }
        if let value = row[column] as Double? {
            return Int(value)
        }
        if let value = row[column] as String? {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func doubleValue(from row: Row, column: Column) -> Double? {
        if let value = row[column] as Double? {
            return value
        }
        if let value = row[column] as Int? {
            return Double(value)
        }
        if let value = row[column] as Int64? {
            return Double(value)
        }
        if let value = row[column] as String? {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

// PersistableRecord/EncodableRecord conformance removed. Insert via raw SQL in MessageRepository.
