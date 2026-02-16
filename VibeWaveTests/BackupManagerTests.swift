import XCTest
import GRDB
@testable import VibeWave

final class BackupManagerTests: XCTestCase {
    var backupManager: BackupManager!
    var testBackupDirectory: URL!
    var legacyBackupDirectory: URL!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        testBackupDirectory = tempDir.appendingPathComponent("vibewave_backup_tests_\(UUID().uuidString)")
        legacyBackupDirectory = tempDir.appendingPathComponent("vibewave_backup_tests_legacy_\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testBackupDirectory, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: legacyBackupDirectory, withIntermediateDirectories: true)
        backupManager = BackupManager(
            backupDirectory: testBackupDirectory,
            additionalSearchDirectories: [legacyBackupDirectory]
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testBackupDirectory)
        try? FileManager.default.removeItem(at: legacyBackupDirectory)
        super.tearDown()
    }

    func testCreateBackup_createsBackupFile() async throws {
        let sourceURL = testBackupDirectory.appendingPathComponent("source.db")
        let source = try DatabaseQueue(path: sourceURL.path)
        try await source.write { db in
            try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute(sql: "INSERT INTO t(name) VALUES ('alpha')")
        }

        let backupInfo = try await backupManager.createBackup(from: source, kind: .manual)

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupInfo.fileURL.path))
        XCTAssertEqual(backupInfo.kind, .manual)
        XCTAssertTrue(backupInfo.fileSize > 0)
        XCTAssertTrue(backupInfo.createdAt.timeIntervalSinceNow < 5)
    }

    func testListBackups_parsesCreatedAtFromFilename() async throws {
        let filename = "auto_backup_20260101-120000_\(UUID().uuidString).db"
        let url = testBackupDirectory.appendingPathComponent(filename)
        FileManager.default.createFile(atPath: url.path, contents: Data())

        let backups = try await backupManager.listBackups()
        guard let backup = backups.first(where: { $0.fileURL.lastPathComponent == filename }) else {
            XCTFail("Missing parsed backup")
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let expected = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12, minute: 0, second: 0))!
        XCTAssertEqual(backup.createdAt.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(backup.kind, .automatic)
    }

    func testCleanupOldBackups_onlyAffectsAutomatic() async throws {
        let timestamps = ["20260101-120000", "20260102-120000", "20260103-120000"]

        for stamp in timestamps {
            let autoName = "auto_backup_\(stamp)_\(UUID().uuidString).db"
            let manualName = "manual_backup_\(stamp)_\(UUID().uuidString).db"
            FileManager.default.createFile(atPath: testBackupDirectory.appendingPathComponent(autoName).path, contents: Data())
            FileManager.default.createFile(atPath: testBackupDirectory.appendingPathComponent(manualName).path, contents: Data())
        }

        try await backupManager.cleanupOldBackups(maxCount: 2, kind: .automatic)

        let backups = try await backupManager.listBackups()
        let autoCount = backups.filter { $0.kind == .automatic }.count
        let manualCount = backups.filter { $0.kind == .manual }.count

        XCTAssertEqual(autoCount, 2)
        XCTAssertEqual(manualCount, 3)
    }

    func testRestoreBackup_restoresIntoLiveDatabase() async throws {
        let sourceURL = testBackupDirectory.appendingPathComponent("source_restore.db")
        let destinationURL = testBackupDirectory.appendingPathComponent("destination_restore.db")

        let source = try DatabaseQueue(path: sourceURL.path)
        try await source.write { db in
            try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute(sql: "INSERT INTO t(name) VALUES ('source')")
        }

        let destination = try DatabaseQueue(path: destinationURL.path)
        try await destination.write { db in
            try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute(sql: "INSERT INTO t(name) VALUES ('destination')")
        }

        let backupInfo = try await backupManager.createBackup(from: source, kind: .manual)
        try await backupManager.restoreBackup(backupInfo, to: destination)

        let restoredName: String? = try await destination.read { db in
            try String.fetchOne(db, sql: "SELECT name FROM t ORDER BY id LIMIT 1")
        }
        XCTAssertEqual(restoredName, "source")
    }

    func testListBackups_supportsLegacyFilename() async throws {
        let legacyName = "vibewave.db.backup.20260205-170547"
        let legacyURL = legacyBackupDirectory.appendingPathComponent(legacyName)
        FileManager.default.createFile(atPath: legacyURL.path, contents: Data())

        let backups = try await backupManager.listBackups()
        guard let backup = backups.first(where: { $0.fileURL.lastPathComponent == legacyName }) else {
            XCTFail("Missing legacy backup")
            return
        }

        XCTAssertEqual(backup.kind, .legacy)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let expected = formatter.date(from: "20260205-170547")!
        XCTAssertEqual(backup.createdAt.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }
}
