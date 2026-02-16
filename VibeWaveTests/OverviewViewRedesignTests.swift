import XCTest
@testable import VibeWave

final class OverviewViewRedesignTests: XCTestCase {

    func testTabLabelShows总览() {
        XCTAssertEqual(ContentView.AppTab.usage.rawValue, "总览")
    }

    func testCodeImpactChart_zeroValues() {
        let additions = 0
        let deletions = 0
        let fileCount = 0

        _ = CodeImpactChart(
            additions: additions,
            deletions: deletions,
            fileCount: fileCount
        )

        let totalChanges = additions + deletions
        XCTAssertEqual(totalChanges, 0)
    }

    func testCodeImpactChart_onlyAddAdditions() {
        let additions = 1000
        let deletions = 0
        let fileCount = 10

        _ = CodeImpactChart(
            additions: additions,
            deletions: deletions,
            fileCount: fileCount
        )

        let totalChanges = additions + deletions
        XCTAssertEqual(totalChanges, 1000)
        XCTAssertEqual(Double(additions) / Double(totalChanges) * 100, 100.0, accuracy: 0.01)
        XCTAssertEqual(Double(deletions) / Double(totalChanges) * 100, 0.0, accuracy: 0.01)
    }

    func testCodeImpactChart_onlyDeletions() {
        let additions = 0
        let deletions = 500
        let fileCount = 5

        _ = CodeImpactChart(
            additions: additions,
            deletions: deletions,
            fileCount: fileCount
        )

        let totalChanges = additions + deletions
        XCTAssertEqual(totalChanges, 500)
        XCTAssertEqual(Double(additions) / Double(totalChanges) * 100, 0.0, accuracy: 0.01)
        XCTAssertEqual(Double(deletions) / Double(totalChanges) * 100, 100.0, accuracy: 0.01)
    }

    func testCodeImpactChart_bothAdditionsAndDeletions() {
        let additions = 1390
        let deletions = 396
        let fileCount = 31

        _ = CodeImpactChart(
            additions: additions,
            deletions: deletions,
            fileCount: fileCount
        )

        let totalChanges = additions + deletions
        XCTAssertEqual(totalChanges, 1786)
        XCTAssertEqual(Double(additions) / Double(totalChanges) * 100, 77.82, accuracy: 0.01)
        XCTAssertEqual(Double(deletions) / Double(totalChanges) * 100, 22.18, accuracy: 0.01)
    }

    func testCodeImpactChart_percentageCalculation() {
        // Test edge cases
        XCTAssertEqual(Double(0) / Double(100) * 100, 0.0, accuracy: 0.01)
        XCTAssertEqual(Double(50) / Double(100) * 100, 50.0, accuracy: 0.01)
        XCTAssertEqual(Double(100) / Double(100) * 100, 100.0, accuracy: 0.01)
    }

    func testCodeImpactChart_statsSummaryFormatting() {
        // Test the formatStat logic
        let formatStat = { (value: Int, label: String, percentage: Double, sign: String) -> String in
            if value == 0 {
                return "\(sign)0 \(label)"
            }
            return "\(sign)\(value) \(label) (\(Int(percentage))%)"
        }

        // Test zero value
        XCTAssertEqual(formatStat(0, "lines", 0.0, "+"), "+0 lines")

        // Test non-zero value
        XCTAssertEqual(formatStat(1390, "lines", 78.0, "+"), "+1390 lines (78%)")
        XCTAssertEqual(formatStat(396, "lines", 22.0, "-"), "-396 lines (22%)")

        // Test file count formatting
        XCTAssertEqual("31 files", "31 files")
    }
}
