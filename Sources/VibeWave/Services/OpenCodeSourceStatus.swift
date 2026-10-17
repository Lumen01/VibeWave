import Foundation
import Combine
import GRDB

public struct OpenCodeSourceState: Equatable {
    public enum Kind: String {
        case checking, v1, connecting, v2, waiting, updateRequired, historyIncomplete, failed
    }
    public let kind: Kind
    public var completedSessions: Int = 0
    public var totalSessions: Int = 0
    public var missingSessions: Int = 0
    public var sessionUsageCount: Int = 0
    public var lastSuccess: Date?

    public init(kind: Kind, completedSessions: Int = 0, totalSessions: Int = 0,
                missingSessions: Int = 0, sessionUsageCount: Int = 0, lastSuccess: Date? = nil) {
        self.kind = kind
        self.completedSessions = completedSessions
        self.totalSessions = totalSessions
        self.missingSessions = missingSessions
        self.sessionUsageCount = sessionUsageCount
        self.lastSuccess = lastSuccess
    }
}

public final class OpenCodeSourceStatus: ObservableObject {
    public static let shared = OpenCodeSourceStatus()
    @Published public private(set) var state = OpenCodeSourceState(kind: .checking)

    public func report(_ state: OpenCodeSourceState) {
        DispatchQueue.main.async { self.state = state }
    }
}

enum OpenCodeSourceError: Error {
    case unsupportedSchema
    case migrationInProgress
    case invalidRecord
    case incompleteAccounting
}

enum OpenCodeDatabaseFormat: Equatable {
    case v1, v2

    static func detect(in db: Database) throws -> Self {
        func has(_ table: String, _ required: Set<String>) throws -> Bool {
            guard try db.tableExists(table) else { return false }
            return required.isSubset(of: Set(try db.columns(in: table).map(\.name)))
        }
        // A dormant session_message table also exists in V1. Never use it alone.
        if try db.tableExists("session_v2") {
            guard try has("session_v2", ["id", "project_id", "directory", "time_created", "time_updated",
                                        "cost", "tokens_input", "tokens_output", "tokens_reasoning",
                                        "tokens_cache_read", "tokens_cache_write", "fork_session_id", "summary_diffs",
                                        "title", "summary_additions", "summary_deletions", "summary_files"]),
                  try has("session_message", ["id", "session_id", "type", "seq", "data", "time_created", "time_updated"]),
                  try has("event", ["id", "aggregate_id", "seq", "created", "type", "data"]),
                  try has("event_sequence", ["aggregate_id", "seq"]),
                  try has("project", ["id", "worktree"]) else {
                throw OpenCodeSourceError.unsupportedSchema
            }
            if try db.tableExists("kv"),
               let value = try String.fetchOne(db, sql: "SELECT value FROM kv WHERE key = 'migration.v1-v2'"),
               let bytes = value.data(using: .utf8),
               let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
               let phase = object["phase"] as? String, phase != "completed" {
                throw OpenCodeSourceError.migrationInProgress
            }
            return .v2
        }
        if try has("session_message", ["type"]),
           try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM session_message LIMIT 1)") == true {
            throw OpenCodeSourceError.unsupportedSchema
        }
        // Persisted V2 events without session_v2 identify an unsupported beta lineage.
        if try db.tableExists("event"),
           try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM event WHERE type LIKE 'session.step.%' LIMIT 1)") == true {
            throw OpenCodeSourceError.unsupportedSchema
        }
        guard try has("message", ["id", "session_id", "data", "time_updated"]) else {
            throw OpenCodeSourceError.unsupportedSchema
        }
        return .v1
    }
}
