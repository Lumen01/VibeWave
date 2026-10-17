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
    private static let levelLock = NSLock()
    private static var sharedLevel = loadLogLevel(from: .standard)
    private let configuredLevel: LogLevel?

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
        self.configuredLevel = userDefaults === UserDefaults.standard ? nil : Self.loadLogLevel(from: userDefaults)
    }

    public static func updateConfiguredLevel(_ level: LogLevel) {
        levelLock.lock()
        sharedLevel = level
        levelLock.unlock()
    }

    public func debug(_ message: @autoclosure () -> String, category: String? = nil) {
        log(.debug, message, category: category)
    }

    public func info(_ message: @autoclosure () -> String, category: String? = nil) {
        log(.info, message, category: category)
    }

    public func warn(_ message: @autoclosure () -> String, category: String? = nil) {
        log(.warn, message, category: category)
    }

    public func error(_ message: @autoclosure () -> String, category: String? = nil) {
        log(.error, message, category: category)
    }

    private func log(_ level: LogLevel, _ message: () -> String, category: String?) {
        guard shouldLog(level) else { return }
        let message = message()
        let resolvedCategory = category ?? self.category
        let entry = LogEntry(level: level, message: message, category: resolvedCategory)
        sink?(entry)
        logger.log(level: level.osLogType, "\(message, privacy: .public)")
    }

    private func shouldLog(_ level: LogLevel) -> Bool {
        let threshold: LogLevel
        if let configuredLevel {
            threshold = configuredLevel
        } else {
            Self.levelLock.lock()
            threshold = Self.sharedLevel
            Self.levelLock.unlock()
        }
        return level.rank <= threshold.rank
    }

    private static func loadLogLevel(from userDefaults: UserDefaults) -> LogLevel {
        if let raw = userDefaults.string(forKey: "log.level"),
           let level = LogLevel(rawValue: raw) {
            return level
        }
#if DEBUG
        return .debug
#else
        return .info
#endif
    }
}
