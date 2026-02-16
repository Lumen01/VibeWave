import Foundation

public protocol AIToolAdapter {
    var toolId: String { get }
    var toolName: String { get }
    var parser: MessageParsing { get }
    func parseMessages(from url: URL) -> AIParseResult
}

public struct AIParseResult {
    public let messages: [Message]
    public let affectedSessionIds: Set<String>
    public let toolSpecificData: [String: Any]?

    public init(messages: [Message], affectedSessionIds: Set<String>, toolSpecificData: [String: Any]? = nil) {
        self.messages = messages
        self.affectedSessionIds = affectedSessionIds
        self.toolSpecificData = toolSpecificData

    }
}

public struct AIToolAdapterRegistry {
    private var adapters: [String: AIToolAdapter] = [:]
    
    public init() {}
    
    public mutating func register(adapter: AIToolAdapter) {
        adapters[adapter.toolId] = adapter
    }
    
    public func getAdapter(for toolId: String) -> AIToolAdapter? {
        return adapters[toolId]
    }
    
    public func getAllToolIds() -> [String] {
        return Array(adapters.keys)
    }
}

public final class OpenCodeAdapter: AIToolAdapter {
    public let toolId = "opencode"
    public let toolName = "OpenCode"
    public let parser: MessageParsing
    
    public init(parser: MessageParsing) {
        self.parser = parser
    }
    
    public func parseMessages(from url: URL) -> AIParseResult {
        let parseResult = parser.parseMessages(from: url)
        return AIParseResult(
            messages: parseResult.messages,
            affectedSessionIds: parseResult.affectedSessionIds,
            toolSpecificData: nil
        )
    }
}

public final class ClaudeCodeAdapter: AIToolAdapter {
    public let toolId = "claude_code"
    public let toolName = "Claude Code"
    public let parser: MessageParsing
    
    public init(parser: MessageParsing) {
        self.parser = parser
    }
    
    public func parseMessages(from url: URL) -> AIParseResult {
        let parseResult = parser.parseMessages(from: url)
        return AIParseResult(
            messages: parseResult.messages,
            affectedSessionIds: parseResult.affectedSessionIds,
            toolSpecificData: nil
        )
    }
}

public final class CursorAdapter: AIToolAdapter {
    public let toolId = "cursor"
    public let toolName = "Cursor"
    public let parser: MessageParsing
    
    public init(parser: MessageParsing) {
        self.parser = parser
    }
    
    public func parseMessages(from url: URL) -> AIParseResult {
        let parseResult = parser.parseMessages(from: url)
        return AIParseResult(
            messages: parseResult.messages,
            affectedSessionIds: parseResult.affectedSessionIds,
            toolSpecificData: nil
        )
    }
}