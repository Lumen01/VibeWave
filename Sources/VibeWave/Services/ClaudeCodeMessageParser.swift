import Foundation

public final class ClaudeCodeMessageParser: MessageParsing {
    private let parser: MessageParser
    
    public init() {
        self.parser = MessageParser()
    }
    
    public func parseMessages(from url: URL) -> ParseResult {
        let parserResult = parser.parseMessages(from: url)
        
        var affectedSessionIds: Set<String> = []
        for message in parserResult.messages {
            affectedSessionIds.insert(message.sessionID)
        }
        
        return ParseResult(
            messages: parserResult.messages,
            affectedSessionIds: affectedSessionIds
        )
    }

    public func parseMessages(from data: Data, sourceURL: URL) -> ParseResult {
        let parserResult = parser.parseMessages(from: data, sourceURL: sourceURL)

        var affectedSessionIds: Set<String> = []
        for message in parserResult.messages {
            affectedSessionIds.insert(message.sessionID)
        }

        return ParseResult(
            messages: parserResult.messages,
            affectedSessionIds: affectedSessionIds
        )
    }
}
