import Foundation
import CoreGraphics

public struct ContributionHeatCell: Identifiable, Sendable, Equatable {
    public let id: Int64
    public let date: Date
    public let value: Double

    public init(id: Int64, date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}

public struct ContributionHeatmapLayout {
    public struct ScaledMetrics: Sendable, Equatable {
        public let cellSize: CGFloat
        public let cellSpacing: CGFloat

        public init(cellSize: CGFloat, cellSpacing: CGFloat) {
            self.cellSize = cellSize
            self.cellSpacing = cellSpacing
        }
    }

    public struct WeekdayLabel: Sendable, Equatable {
        public let title: String
        public let rowIndex: Int

        public init(title: String, rowIndex: Int) {
            self.title = title
            self.rowIndex = rowIndex
        }
    }

    public struct MonthLabel: Identifiable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let weekIndex: Int

        public init(title: String, weekIndex: Int) {
            self.id = "\(title)-\(weekIndex)"
            self.title = title
            self.weekIndex = weekIndex
        }
    }

    public static let baseCellSize: CGFloat = 9
    public static let baseCellSpacing: CGFloat = 3
    public static let weekdayLabels: [WeekdayLabel] = [
        .init(title: "Sun", rowIndex: 0),
        .init(title: "Wed", rowIndex: 3),
        .init(title: "Sat", rowIndex: 6)
    ]

    public static func buildHeatCells(
        points: [DailyHeatPoint],
        calendar inputCalendar: Calendar = .current
    ) -> [ContributionHeatCell] {
        guard let rawFirstDate = points.first?.date, let rawLastDate = points.last?.date else {
            return []
        }

        let calendar = inputCalendar
        let firstDate = calendar.startOfDay(for: rawFirstDate)
        let lastDate = calendar.startOfDay(for: rawLastDate)
        let alignedStart = alignToSunday(firstDate, calendar: calendar)
        let totalDays = max(0, calendar.dateComponents([.day], from: alignedStart, to: lastDate).day ?? 0)
        let valueByDayMs = Dictionary(uniqueKeysWithValues: points.map { ($0.dayStartMs, $0.value) })

        return (0...totalDays).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: alignedStart) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let dayMs = Int64(dayStart.timeIntervalSince1970 * 1000)
            return ContributionHeatCell(id: dayMs, date: dayStart, value: valueByDayMs[dayMs] ?? 0)
        }
    }

    public static func weekColumnCount(cellCount: Int) -> Int {
        max(1, Int(ceil(Double(max(cellCount, 1)) / 7.0)))
    }

    public static func scaledMetrics(
        availableWidth: CGFloat,
        columnCount: Int,
        baseCellSize: CGFloat = baseCellSize,
        baseCellSpacing: CGFloat = baseCellSpacing
    ) -> ScaledMetrics {
        let safeColumns = max(1, columnCount)
        guard availableWidth > 0 else {
            return ScaledMetrics(cellSize: baseCellSize, cellSpacing: baseCellSpacing)
        }
        let baseGridWidth = (CGFloat(safeColumns) * baseCellSize) + (CGFloat(max(0, safeColumns - 1)) * baseCellSpacing)
        let scale = baseGridWidth > 0 ? max(0, availableWidth) / baseGridWidth : 1

        return ScaledMetrics(
            cellSize: baseCellSize * scale,
            cellSpacing: baseCellSpacing * scale
        )
    }

    public static func monthLabels(
        from cells: [ContributionHeatCell],
        calendar inputCalendar: Calendar = .current,
        locale: Locale = .current,
        limit: Int = 12
    ) -> [MonthLabel] {
        guard
            let firstDate = cells.first?.date,
            let lastDate = cells.last?.date
        else {
            return []
        }

        let calendar = inputCalendar
        guard let lastMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: lastDate)) else {
            return []
        }

        let safeLimit = max(1, limit)
        let alignedStart = calendar.startOfDay(for: firstDate)
        let maxWeekIndex = weekColumnCount(cellCount: cells.count) - 1

        let monthFormatter = DateFormatter()
        monthFormatter.locale = locale
        monthFormatter.dateFormat = "MMM"

        var labels: [MonthLabel] = []
        for monthOffset in stride(from: -(safeLimit - 1), through: 0, by: 1) {
            guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: lastMonthStart) else {
                continue
            }
            let daysFromStart = calendar.dateComponents([.day], from: alignedStart, to: monthStart).day ?? 0
            guard daysFromStart >= 0 else { continue }

            let weekIndex = min(maxWeekIndex, max(0, daysFromStart / 7))
            labels.append(MonthLabel(title: monthFormatter.string(from: monthStart), weekIndex: weekIndex))
        }
        return labels
    }

    private static func alignToSunday(_ date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysFromSunday = weekday - 1
        return calendar.date(byAdding: .day, value: -daysFromSunday, to: date) ?? date
    }
}
