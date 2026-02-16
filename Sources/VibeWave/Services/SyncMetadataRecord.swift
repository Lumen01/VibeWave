import Foundation

public struct SyncMetadataRecord: Codable {
    public let filePath: String
    public let toolId: String
    public let fileHash: String
    public let lastImportedAt: Int64
    public let messageCount: Int64?
    public let firstMessageTime: Int64?
    public let lastMessageTime: Int64?
    public let isFileExists: Bool

    public init(
        filePath: String,
        toolId: String = "opencode",
        fileHash: String,
        lastImportedAt: Int64,
        messageCount: Int64? = nil,
        firstMessageTime: Int64? = nil,
        lastMessageTime: Int64? = nil,
        isFileExists: Bool = true
    ) {
        self.filePath = filePath
        self.toolId = toolId
        self.fileHash = fileHash
        self.lastImportedAt = lastImportedAt
        self.messageCount = messageCount
        self.firstMessageTime = firstMessageTime
        self.lastMessageTime = lastMessageTime
        self.isFileExists = isFileExists
    }
}
