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
    var tokenInput: String?
    var tokenOutput: String?
    var tokenReasoning: String?
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
        self.tokenInput = row[Columns.tokenInput] as String?
        self.tokenOutput = row[Columns.tokenOutput] as String?
        self.tokenReasoning = row[Columns.tokenReasoning] as String?
        self.cacheRead = row[Columns.cacheRead] as Int
        self.cacheWrite = row[Columns.cacheWrite] as Int
        self.cost = row[Columns.cost] as Double
        self.summaryTitle = row[Columns.summaryTitle] as String?
        self.summaryTotalAdditions = row[Columns.summaryTotalAdditions] as Int
        self.summaryTotalDeletions = row[Columns.summaryTotalDeletions] as Int
        self.summaryFileCount = row[Columns.summaryFileCount] as Int
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
        if let inVal = message.tokens?.input {
            self.tokenInput = String(inVal)
        } else {
            self.tokenInput = nil
        }
        if let outVal = message.tokens?.output {
            self.tokenOutput = String(outVal)
        } else {
            self.tokenOutput = nil
        }
        if let reasonVal = message.tokens?.reasoning {
            self.tokenReasoning = String(reasonVal)
        } else {
            self.tokenReasoning = nil
        }
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
}

// PersistableRecord/EncodableRecord conformance removed. Insert via raw SQL in MessageRepository.
