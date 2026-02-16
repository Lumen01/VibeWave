import Foundation
import GRDB

public final class DatabaseInitializer {
    private static let logger = AppLogger(category: "DatabaseInitializer")

    public static func initialize() {
        logger.debug("DatabaseInitializer.initialize() called")

        // Access the shared repository to trigger initialization
        let repo = DatabaseRepository.shared
        logger.debug("DatabaseRepository.shared accessed")

        // Explicitly create schema to ensure tables exist
        do {
            try repo.dbPool().write { db in
                try DatabaseRepository.createTables(on: db)
                try DatabaseRepository.createAggregationTables(on: db)
            }
            logger.info("Database schema created explicitly")
        } catch {
            logger.error("Failed to create database schema: \(error)")
        }

        logger.info("Database initialized")
    }
}
