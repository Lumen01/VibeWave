import Foundation

public enum AppPaths {
    public static var appSupportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/VibeWave", isDirectory: true)
    }

    public static var legacyAppSupportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/vibewave", isDirectory: true)
    }

    public static var backupsDirectory: URL {
        appSupportDirectory.appendingPathComponent("backups", isDirectory: true)
    }

    public static var legacyBackupsDirectory: URL {
        legacyAppSupportDirectory.appendingPathComponent("backups", isDirectory: true)
    }
}

