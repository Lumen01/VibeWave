import Foundation
import os

public final class AppLogger {
    public typealias LogLevel = AppLogLevel

    public struct LogEntry: Equatable {
        public let level: LogLevel
        public let message: String
        public let category: String
    }

    private let subsystem: String
    private let category: String
    private let userDefaults: UserDefaults
    private let sink: ((LogEntry) -> Void)?
    private let logger: Logger

    public init(
        subsystem: String = Bundle.main.bundleIdentifier ?? AppConfiguration.App.identifier,
        category: String,
        userDefaults: UserDefaults = .standard,
        sink: ((LogEntry) -> Void)? = nil
    ) {
        self.subsystem = subsystem
        self.category = category
        self.userDefaults = userDefaults
        self.sink = sink
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func debug(_ message: String, category: String? = nil) {
        log(.debug, message, category: category)
    }

    public func info(_ message: String, category: String? = nil) {
        log(.info, message, category: category)
    }

    public func warn(_ message: String, category: String? = nil) {
        log(.warn, message, category: category)
    }

    public func error(_ message: String, category: String? = nil) {
        log(.error, message, category: category)
    }

    private func log(_ level: LogLevel, _ message: String, category: String?) {
        guard shouldLog(level) else { return }
        let resolvedCategory = category ?? self.category
        let entry = LogEntry(level: level, message: message, category: resolvedCategory)
        sink?(entry)
        logger.log(level: level.osLogType, "\(message, privacy: .public)")
    }

    private func shouldLog(_ level: LogLevel) -> Bool {
        let configured = currentLogLevel()
        return level.rank <= configured.rank
    }

    private func currentLogLevel() -> LogLevel {
        if let raw = userDefaults.string(forKey: "log.level"),
           let level = LogLevel(rawValue: raw) {
            return level
        }
        return .debug
    }
}
