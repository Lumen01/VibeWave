import Foundation

public struct Message: Codable {
  public let id: String
  public let sessionID: String
  public let role: String
  public let time: MessageTime?
  public let parentID: String?
  public let providerID: String?
  public let modelID: String?
  public let agent: String?
  public let mode: String?
  public let variant: String?
  public let cwd: String?
  public let root: String?
  public let tokens: Tokens?
  public let cost: Double?
  public let summary: SessionSummary?
  public let finish: String?

  // Helper for nested model object
  private struct ModelContainer: Codable {
    let providerID: String?
    let modelID: String?
  }

  // Helper for nested path object (real OpenCode format)
  private struct PathInfo: Codable {
    let cwd: String?
    let root: String?
  }

  private static func normalizedNonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  public init(id: String, sessionID: String, role: String, time: MessageTime?, parentID: String?, providerID: String?, modelID: String?, agent: String?, mode: String?, variant: String?, cwd: String?, root: String?, tokens: Tokens?, cost: Double?, summary: SessionSummary? = nil, finish: String? = nil) {
    self.id = id
    self.sessionID = sessionID
    self.role = role
    self.time = time
    self.parentID = parentID
    self.providerID = providerID
    self.modelID = modelID
    self.agent = agent
    self.mode = mode
    self.variant = variant
    self.cwd = cwd
    self.root = root
    self.tokens = tokens
    self.cost = cost
    self.summary = summary
    self.finish = finish
  }

  public init(from decoder: Decoder) throws {
    // Try snake_case first (backward compatibility with tests)
    if let message = try? Message.decodeAsSnakeCase(decoder: decoder) {
      self = message
      return
    }
    // Try camelCase (actual OpenCode format)
    if let message = try? Message.decodeAsCamelCase(decoder: decoder) {
      self = message
      return
    }
    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode Message in either format"))
  }

  private static func decodeAsSnakeCase(decoder: Decoder) throws -> Message {
    struct SnakeKeys: CodingKey {
      var stringValue: String
      var intValue: Int? { nil }
      init(stringValue: String) { self.stringValue = stringValue }
      init?(intValue: Int) { nil }
    }
    
    let container = try decoder.container(keyedBy: SnakeKeys.self)
    
    let id = try container.decode(String.self, forKey: SnakeKeys(stringValue: "id"))
    let sessionID = try container.decode(String.self, forKey: SnakeKeys(stringValue: "session_id"))
    let role = try container.decode(String.self, forKey: SnakeKeys(stringValue: "role"))
    let time = try? container.decode(MessageTime.self, forKey: SnakeKeys(stringValue: "time"))
    let parentID = try? container.decode(String.self, forKey: SnakeKeys(stringValue: "parent_id"))
    let agent = try? container.decode(String.self, forKey: SnakeKeys(stringValue: "agent"))
    let mode = try? container.decode(String.self, forKey: SnakeKeys(stringValue: "mode"))
    let variant = try? container.decode(String.self, forKey: SnakeKeys(stringValue: "variant"))
    var cwd: String? = nil
    var root: String? = nil

    if let pathInfo = try? container.decode(PathInfo.self, forKey: SnakeKeys(stringValue: "path")) {
      cwd = pathInfo.cwd
      root = pathInfo.root
    }

    if cwd == nil {
      cwd = try? container.decode(String.self, forKey: SnakeKeys(stringValue: "cwd"))
    }
    if root == nil {
      root = try? container.decode(String.self, forKey: SnakeKeys(stringValue: "root"))
    }
    let tokens = try? container.decode(Tokens.self, forKey: SnakeKeys(stringValue: "tokens"))
    let cost = try? container.decode(Double.self, forKey: SnakeKeys(stringValue: "cost"))
    let summary = try? container.decode(SessionSummary.self, forKey: SnakeKeys(stringValue: "summary"))
    let finish = try? container.decode(String.self, forKey: SnakeKeys(stringValue: "finish"))

    var providerID = normalizedNonEmpty(try? container.decode(String.self, forKey: SnakeKeys(stringValue: "provider_id")))
    var modelID = normalizedNonEmpty(try? container.decode(String.self, forKey: SnakeKeys(stringValue: "model_id")))

    if providerID == nil {
      providerID = normalizedNonEmpty(try? container.decode(String.self, forKey: SnakeKeys(stringValue: "providerID")))
    }
    if modelID == nil {
      modelID = normalizedNonEmpty(try? container.decode(String.self, forKey: SnakeKeys(stringValue: "modelID")))
    }

    if providerID == nil || modelID == nil {
      if let modelContainer = try? container.decode(ModelContainer.self, forKey: SnakeKeys(stringValue: "model")) {
        if providerID == nil {
          providerID = normalizedNonEmpty(modelContainer.providerID)
        }
        if modelID == nil {
          modelID = normalizedNonEmpty(modelContainer.modelID)
        }
      }
    }

    return Message(
      id: id, sessionID: sessionID, role: role, time: time,
      parentID: parentID, providerID: providerID, modelID: modelID,
      agent: agent, mode: mode, variant: variant, cwd: cwd, root: root,
      tokens: tokens, cost: cost, summary: summary, finish: finish
    )
  }

  private static func decodeAsCamelCase(decoder: Decoder) throws -> Message {
    struct CamelKeys: CodingKey {
      var stringValue: String
      var intValue: Int? { nil }
      init(stringValue: String) { self.stringValue = stringValue }
      init?(intValue: Int) { nil }
    }
    
    let container = try decoder.container(keyedBy: CamelKeys.self)
    
    let id = try container.decode(String.self, forKey: CamelKeys(stringValue: "id"))
    let sessionID = try container.decode(String.self, forKey: CamelKeys(stringValue: "sessionID"))
    let role = try container.decode(String.self, forKey: CamelKeys(stringValue: "role"))
    let time = try? container.decode(MessageTime.self, forKey: CamelKeys(stringValue: "time"))
    let parentID = try? container.decode(String.self, forKey: CamelKeys(stringValue: "parentID"))
    let agent = try? container.decode(String.self, forKey: CamelKeys(stringValue: "agent"))
    let mode = try? container.decode(String.self, forKey: CamelKeys(stringValue: "mode"))
    let variant = try? container.decode(String.self, forKey: CamelKeys(stringValue: "variant"))
    // Try nested path object first (real OpenCode format), fallback to top-level
    var cwd: String? = nil
    var root: String? = nil

    if let pathInfo = try? container.decode(PathInfo.self, forKey: CamelKeys(stringValue: "path")) {
      cwd = pathInfo.cwd
      root = pathInfo.root
    }

    // Fallback to top-level fields for backward compatibility
    if cwd == nil {
      cwd = try? container.decode(String.self, forKey: CamelKeys(stringValue: "cwd"))
    }
    if root == nil {
      root = try? container.decode(String.self, forKey: CamelKeys(stringValue: "root"))
    }
    let tokens = try? container.decode(Tokens.self, forKey: CamelKeys(stringValue: "tokens"))
    let cost = try? container.decode(Double.self, forKey: CamelKeys(stringValue: "cost"))
    let summary = try? container.decode(SessionSummary.self, forKey: CamelKeys(stringValue: "summary"))
    let finish = try? container.decode(String.self, forKey: CamelKeys(stringValue: "finish"))

    var providerID = normalizedNonEmpty(try? container.decode(String.self, forKey: CamelKeys(stringValue: "providerID")))
    var modelID = normalizedNonEmpty(try? container.decode(String.self, forKey: CamelKeys(stringValue: "modelID")))

    if providerID == nil {
      providerID = normalizedNonEmpty(try? container.decode(String.self, forKey: CamelKeys(stringValue: "provider_id")))
    }
    if modelID == nil {
      modelID = normalizedNonEmpty(try? container.decode(String.self, forKey: CamelKeys(stringValue: "model_id")))
    }

    if providerID == nil || modelID == nil {
      if let modelContainer = try? container.decode(ModelContainer.self, forKey: CamelKeys(stringValue: "model")) {
        if providerID == nil {
          providerID = normalizedNonEmpty(modelContainer.providerID)
        }
        if modelID == nil {
          modelID = normalizedNonEmpty(modelContainer.modelID)
        }
      }
    }

    return Message(
      id: id, sessionID: sessionID, role: role, time: time,
      parentID: parentID, providerID: providerID, modelID: modelID,
      agent: agent, mode: mode, variant: variant, cwd: cwd, root: root,
      tokens: tokens, cost: cost, summary: summary, finish: finish
    )
  }
}

public struct MessageTime: Codable {
  public let created: String?
  public let completed: String?

  private enum CodingKeys: String, CodingKey {
    case created, completed
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if let createdInt = try? container.decode(Int.self, forKey: .created) {
      self.created = String(createdInt)
    } else if let createdDouble = try? container.decode(Double.self, forKey: .created) {
      self.created = String(Int(createdDouble))
    } else {
      self.created = try? container.decodeIfPresent(String.self, forKey: .created)
    }

    if let completedInt = try? container.decode(Int.self, forKey: .completed) {
      self.completed = String(completedInt)
    } else if let completedDouble = try? container.decode(Double.self, forKey: .completed) {
      self.completed = String(Int(completedDouble))
    } else {
      self.completed = try? container.decodeIfPresent(String.self, forKey: .completed)
    }
  }

  public init(created: String?, completed: String?) {
    self.created = created
    self.completed = completed
  }
}

public struct Tokens: Codable {
  public let input: Int?
  public let output: Int?
  public let reasoning: Int?

  // Cache info can be nested: {"cache": {"read": 0, "write": 0}}
  private let cache: CacheInfo?

  // Computed properties for convenient access
  public var cacheRead: Int {
    cache?.read ?? 0
  }

  public var cacheWrite: Int {
    cache?.write ?? 0
  }

  // Public initializer for creating Tokens programmatically
  public init(input: Int?, output: Int?, reasoning: Int?, cacheRead: Int = 0, cacheWrite: Int = 0) {
    self.input = input
    self.output = output
    self.reasoning = reasoning
    self.cache = CacheInfo(read: cacheRead, write: cacheWrite)
  }

  private struct CacheInfo: Codable {
    let read: Int?
    let write: Int?
  }
}
