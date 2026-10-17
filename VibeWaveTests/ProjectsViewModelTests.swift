import XCTest
@testable import VibeWave

final class ProjectsViewModelTests: XCTestCase {
    func testProjectStats_UsesProjectRootAsStableIdentity() {
        let first = makeStats(projectRoot: "/tmp/project", sessionCount: 1)
        let reloaded = makeStats(projectRoot: "/tmp/project", sessionCount: 2)

        XCTAssertEqual(first.id, reloaded.id)
        XCTAssertNotEqual(first, reloaded)
    }

    private func makeStats(projectRoot: String, sessionCount: Int) -> ProjectsViewModel.ProjectStats {
        ProjectsViewModel.ProjectStats(
            projectRoot: projectRoot,
            sessionCount: sessionCount,
            messageCount: 0,
            inputTokens: 0,
            outputTokens: 0,
            cacheRead: 0,
            cacheWrite: 0,
            netCodeLines: 0,
            fileCount: 0,
            tokens: 0,
            cost: 0,
            activeDays: 0,
            lastActiveAt: nil
        )
    }
}
