import XCTest
@testable import VibeWave

final class AppLoggerTests: XCTestCase {
    func testLogger_RespectsLogLevelThreshold() {
        let defaults = UserDefaults(suiteName: "app-logger-tests")!
        defaults.removePersistentDomain(forName: "app-logger-tests")
        defaults.set(AppLogger.LogLevel.warn.rawValue, forKey: "log.level")

        var captured: [AppLogger.LogEntry] = []
        let logger = AppLogger(
            category: "test",
            userDefaults: defaults,
            sink: { entry in
                captured.append(entry)
            }
        )

        logger.info("info message", category: "test")
        logger.error("error message", category: "test")

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.level, .error)
        XCTAssertEqual(captured.first?.message, "error message")
    }
}
