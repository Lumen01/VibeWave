import XCTest
@testable import VibeWave

final class ConfigServiceTests: XCTestCase {
    var configService: ConfigService!

    override func setUp() {
        super.setUp()
        configService = ConfigService.shared
        configService.resetToDefault()
    }

    override func tearDown() {
        configService.resetToDefault()
        super.tearDown()
    }

    func testDefaultImportPath() {
        let defaultPath = configService.defaultImportPath
        XCTAssertTrue(defaultPath.hasSuffix(".local/share/opencode/opencode.db"))
        XCTAssertTrue(defaultPath.starts(with: "/Users/") || defaultPath.starts(with: "/home/"))
    }

    func testImportPathPersistence() {
        let testPath = "/tmp/test/import/path"

        configService.importPath = testPath
        XCTAssertEqual(configService.importPath, testPath)

        let newService = ConfigService()
        XCTAssertEqual(newService.importPath, testPath)
    }

    func testValidateImportPath_DirectoryNotFound() {
        let result = configService.validateImportPath("/nonexistent/path/12345")
        XCTAssertEqual(result, .directoryNotFound)
    }

    func testValidateImportPath_NotDirectory() {
        let tempDir = "/tmp/testdir_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let result = configService.validateImportPath(tempDir)
        XCTAssertEqual(result, .notDirectory)
    }

    func testValidateImportPath_NotDatabaseFile() {
        let tempFile = "/tmp/testfile_\(UUID().uuidString).txt"
        FileManager.default.createFile(atPath: tempFile, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let result = configService.validateImportPath(tempFile)
        XCTAssertEqual(result, .noJSONFiles)
    }

    func testValidateImportPath_Valid() {
        let dbFile = "/tmp/test_db_\(UUID().uuidString).db"
        FileManager.default.createFile(atPath: dbFile, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: dbFile) }

        let result = configService.validateImportPath(dbFile)
        XCTAssertEqual(result, .valid)
    }

    func testResolveDatabasePath_WhenDirectoryContainsOpenCodeDB_ReturnsDBPath() {
        let tempDir = "/tmp/test_opencode_dir_\(UUID().uuidString)"
        let dbFile = "\(tempDir)/opencode.db"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: dbFile, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let resolved = configService.resolveDatabasePath(from: URL(fileURLWithPath: tempDir))
        XCTAssertEqual(resolved, dbFile)
    }

    func testResetToDefault() {
        let testPath = "/custom/path"
        configService.importPath = testPath
        configService.isDataSourceConfirmed = true
        XCTAssertEqual(configService.importPath, testPath)

        configService.resetToDefault()
        XCTAssertEqual(configService.importPath, configService.defaultImportPath)
        XCTAssertFalse(configService.isDataSourceConfirmed)
    }
}
