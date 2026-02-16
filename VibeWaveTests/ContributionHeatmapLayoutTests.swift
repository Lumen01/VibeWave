import XCTest
@testable import VibeWave

final class ContributionHeatmapLayoutTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = utcCalendar
    }

    func testBuildHeatCells_AlignsToSunday() {
        let firstDate = makeDate(year: 2026, month: 1, day: 7) // Wed
        let lastDate = makeDate(year: 2026, month: 1, day: 9)  // Fri
        let points = makePoints(from: firstDate, to: lastDate)

        let cells = ContributionHeatmapLayout.buildHeatCells(points: points, calendar: calendar)

        XCTAssertFalse(cells.isEmpty)
        XCTAssertEqual(cells.first?.date, makeDate(year: 2026, month: 1, day: 4)) // Sun
    }

    func testScaledMetrics_FillsWidthAndPreservesRatio() {
        let metrics = ContributionHeatmapLayout.scaledMetrics(
            availableWidth: 742,
            columnCount: 53
        )

        let totalWidth = (CGFloat(53) * metrics.cellSize) + (CGFloat(52) * metrics.cellSpacing)
        XCTAssertEqual(totalWidth, 742, accuracy: 0.2)
        XCTAssertEqual(metrics.cellSpacing / metrics.cellSize, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testWeekdayLabels_UseSunWedSatRows() {
        let labels = ContributionHeatmapLayout.weekdayLabels

        XCTAssertEqual(labels.map(\.title), ["Sun", "Wed", "Sat"])
        XCTAssertEqual(labels.map(\.rowIndex), [0, 3, 6])
    }

    func testMonthLabels_ReturnsLatestTwelveInAscendingOrder() {
        let startDate = makeDate(year: 2024, month: 1, day: 1)
        let endDate = calendar.date(byAdding: .day, value: 420, to: startDate)!
        let points = makePoints(from: startDate, to: endDate)

        let cells = ContributionHeatmapLayout.buildHeatCells(points: points, calendar: calendar)
        let labels = ContributionHeatmapLayout.monthLabels(
            from: cells,
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX"),
            limit: 12
        )

        XCTAssertEqual(labels.count, 12)
        XCTAssertEqual(labels.map(\.title).last, "Feb")

        let sortedByWeek = labels.sorted { $0.weekIndex < $1.weekIndex }
        XCTAssertEqual(labels.map(\.weekIndex), sortedByWeek.map(\.weekIndex))
    }

    private func makePoints(from start: Date, to end: Date) -> [DailyHeatPoint] {
        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return (0...dayCount).compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            return DailyHeatPoint(
                date: dayStart,
                dayStartMs: Int64(dayStart.timeIntervalSince1970 * 1000),
                value: 1
            )
        }
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
