import XCTest
@testable import VibeWave

final class PathHelperTests: XCTestCase {
    func testExtractProjectNameFromFullPath() {
        // Standard Unix path
        XCTAssertEqual(
            PathHelper.extractProjectName(from: "/Users/lumen/projects/zt_server"),
            "zt_server"
        )

        // Path with trailing slash
        XCTAssertEqual(
            PathHelper.extractProjectName(from: "/Users/lumen/projects/zt_server/"),
            "zt_server"
        )

        // Deep nested path
        XCTAssertEqual(
            PathHelper.extractProjectName(from: "/Users/lumen/Develop/ZhengTai/zt_server"),
            "zt_server"
        )
    }

    func testExtractProjectNameFromSimplePath() {
        // Just a project name (no slashes)
        XCTAssertEqual(
            PathHelper.extractProjectName(from: "zt_server"),
            "zt_server"
        )
    }

    func testExtractProjectNameFromEdgeCases() {
        // Root path
        XCTAssertNil(PathHelper.extractProjectName(from: "/"))

        // Empty string
        XCTAssertNil(PathHelper.extractProjectName(from: ""))

        // nil
        XCTAssertNil(PathHelper.extractProjectName(from: nil))

        // Multiple trailing slashes
        XCTAssertEqual(
            PathHelper.extractProjectName(from: "/Users/lumen/projects/zt_server///"),
            "zt_server"
        )
    }

    func testExtractProjectNameConsistency() {
        // These should all produce the same result
        let paths = [
            "/Users/lumen/projects/zt_server",
            "/Users/lumen/Develop/ZhengTai/zt_server",
            "/home/user/code/zt_server",
            "zt_server",
            "/zt_server",
            "/zt_server/"
        ]

        for path in paths {
            XCTAssertEqual(
                PathHelper.extractProjectName(from: path),
                "zt_server",
                "Failed for path: \(path)"
            )
        }
    }
}
