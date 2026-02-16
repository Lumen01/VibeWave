import Foundation

public final class MessageParser {
  private let logger = AppLogger(category: "MessageParser")
  
  public struct ParseResult {
    public let messages: [Message]
    public let sessionSummary: SessionSummary?
    public let error: Error?
    
    public init(messages: [Message], sessionSummary: SessionSummary?, error: Error? = nil) {
      self.messages = messages
      self.sessionSummary = sessionSummary
      self.error = error
    }
  }
  
  public enum ParserError: LocalizedError {
    case invalidFile
    case invalidJSON
    case missingRequiredField(String)
    
    public var errorDescription: String? {
      switch self {
      case .invalidFile:
        return "Invalid file format or unreadable"
      case .invalidJSON:
        return "Invalid JSON structure"
      case .missingRequiredField(let field):
        return "Missing required field: \(field)"
      }
    }
  }
  
  private let decoder: JSONDecoder
  
  public init() {
    self.decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
  }
  
  public func parseMessages(from fileURL: URL) -> ParseResult {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return ParseResult(messages: [], sessionSummary: nil, error: ParserError.invalidFile)
    }

    guard let data = try? Data(contentsOf: fileURL) else {
      return ParseResult(messages: [], sessionSummary: nil, error: ParserError.invalidFile)
    }

    return parseMessages(from: data, sourceURL: fileURL)
  }

  public func parseMessages(from data: Data, sourceURL: URL) -> ParseResult {
    // Optimization: Try single message first (most common case)
    do {
      let message = try decoder.decode(Message.self, from: data)
      return ParseResult(messages: [message], sessionSummary: nil)
    } catch {
      // Single message decode failed, try array as fallback
      do {
        let messages = try decoder.decode([Message].self, from: data)
        return ParseResult(messages: messages, sessionSummary: nil)
      } catch {
        // Array decode also failed, try SessionSummary as last fallback
        do {
          let summary = try decoder.decode(SessionSummary.self, from: data)
          return ParseResult(messages: [], sessionSummary: summary)
        } catch {
          // All decode attempts failed
          if let jsonString = String(data: data, encoding: .utf8) {
            logger.error("All decode attempts failed for file: \(sourceURL.path)")
            logger.debug("File content (first 500 chars): \(String(jsonString.prefix(500)))")
          } else {
            logger.error("All decode attempts failed for file: \(sourceURL.path)")
          }
          return ParseResult(messages: [], sessionSummary: nil, error: ParserError.invalidJSON)
        }
      }
    }
  }
  
  public func parseJSONString(_ jsonString: String) -> ParseResult {
    guard let data = jsonString.data(using: .utf8) else {
      return ParseResult(messages: [], sessionSummary: nil, error: ParserError.invalidJSON)
    }
    
    do {
      let messages = try decoder.decode([Message].self, from: data)
      return ParseResult(messages: messages, sessionSummary: nil)
    } catch {
      do {
        let message = try decoder.decode(Message.self, from: data)
        return ParseResult(messages: [message], sessionSummary: nil)
      } catch {
        return ParseResult(messages: [], sessionSummary: nil, error: ParserError.invalidJSON)
      }
    }
  }
}
