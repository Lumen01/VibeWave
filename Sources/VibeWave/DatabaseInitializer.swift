import Foundation

public final class DatabaseInitializer {
    private static let logger = AppLogger(category: "DatabaseInitializer")

    public static func initialize() {
        logger.debug("DatabaseInitializer.initialize() called")

        // Access the shared repository to trigger bootstrap.
        _ = DatabaseRepository.shared
        logger.debug("DatabaseRepository.shared accessed")

        logger.info("Database initialized")
    }
}
