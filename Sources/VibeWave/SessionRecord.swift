import GRDB
import Foundation

public struct SessionRecord: TableRecord, Identifiable, Hashable {
  public let id: String
  public static let databaseTableName = "sessions"

  enum Columns {
    static let sessionId = Column("session_id")
    static let firstMessageAt = Column("first_message_at")
    static let lastMessageAt = Column("last_message_at")
    static let userMsgCount = Column("user_msg_count")
    static let agentMsgCount = Column("agent_msg_count")
    static let totalInputTokens = Column("total_input_tokens")
    static let totalOutputTokens = Column("total_output_tokens")
    static let totalReasoningTokens = Column("total_reasoning_tokens")
    static let totalCacheRead = Column("total_cache_read")
    static let totalCacheWrite = Column("total_cache_write")
    static let totalCost = Column("total_cost")
    static let isOrphan = Column("is_orphan")
    static let totalAdditions = Column("total_additions")
    static let totalDeletions = Column("total_deletions")
    static let totalFileCount = Column("total_file_count")
    static let totalEdits = Column("total_edits")
    static let projectName = Column("project_name")
    static let finishReason = Column("finish_reason")
  }

  var sessionId: String
  var firstMessageAt: Int64?
  var lastMessageAt: Int64?
  var userMsgCount: Int?
  var agentMsgCount: Int?
  var totalInputTokens: Int?
  var totalOutputTokens: Int?
  var totalReasoningTokens: Int?
  var totalCacheRead: Int?
  var totalCacheWrite: Int?
  var totalCost: Double?
  var isOrphan: Int?
  var totalAdditions: Int?
  var totalDeletions: Int?
  var totalFileCount: Int?
  var totalEdits: Int?
  var projectName: String?
  var finishReason: String?

      public var totalTokens: Int {
        return (totalInputTokens ?? 0) + (totalOutputTokens ?? 0) + (totalReasoningTokens ?? 0) + (totalCacheRead ?? 0) + (totalCacheWrite ?? 0)
    }

 init(row: Row) {
    self.id = row[Columns.sessionId] as String
    self.sessionId = row[Columns.sessionId] as String
    self.firstMessageAt = row[Columns.firstMessageAt] as Int64?
    self.lastMessageAt = row[Columns.lastMessageAt] as Int64?
    self.userMsgCount = row[Columns.userMsgCount] as Int?
    self.agentMsgCount = row[Columns.agentMsgCount] as Int?
    self.totalInputTokens = row[Columns.totalInputTokens] as Int?
    self.totalOutputTokens = row[Columns.totalOutputTokens] as Int?
    self.totalReasoningTokens = row[Columns.totalReasoningTokens] as Int?
    self.totalCacheRead = row[Columns.totalCacheRead] as Int?
    self.totalCacheWrite = row[Columns.totalCacheWrite] as Int?
    self.totalCost = row[Columns.totalCost] as Double?
    self.isOrphan = row[Columns.isOrphan] as Int?
    self.totalAdditions = row[Columns.totalAdditions] as Int?
    self.totalDeletions = row[Columns.totalDeletions] as Int?
    self.totalFileCount = row[Columns.totalFileCount] as Int?
    self.totalEdits = row[Columns.totalEdits] as Int?
    self.projectName = row[Columns.projectName] as String?
    self.finishReason = row[Columns.finishReason] as String?
  }
}
