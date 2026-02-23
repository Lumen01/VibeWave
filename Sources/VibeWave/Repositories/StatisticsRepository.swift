import Foundation
import GRDB

public final class StatisticsRepository: @unchecked Sendable {
  public let dbPool: DatabasePool
  private let logger = AppLogger(category: "StatisticsRepository")

  static func calculateAutomationLevel(assistantCount: Int64, userCount: Int64) -> Double {
    let totalMessages = assistantCount + userCount
    guard totalMessages > 0 else { return 0.0 }
    return Double(assistantCount) / Double(totalMessages) * 100
  }

  public init(dbPool: DatabasePool) {
    self.dbPool = dbPool
  }

  // MARK: - Overview Stats
  
  public struct OverviewStats {
    public var totalSessions: Int
    public var totalMessages: Int
    public var totalCost: Double
    public var totalTokens: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var reasoningTokens: Int
    public var cacheRead: Int
    public var cacheWrite: Int
    
    public init(totalSessions: Int, totalMessages: Int, totalCost: Double, totalTokens: Int, inputTokens: Int, outputTokens: Int, reasoningTokens: Int, cacheRead: Int, cacheWrite: Int) {
      self.totalSessions = totalSessions
      self.totalMessages = totalMessages
      self.totalCost = totalCost
      self.totalTokens = totalTokens
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
      self.reasoningTokens = reasoningTokens
      self.cacheRead = cacheRead
      self.cacheWrite = cacheWrite
    }
  }

  public struct OverviewKPITrends {
    public let sessions: [Double]
    public let messages: [Double]
    public let cost: [Double]
    public let inputTokens: [Double]
    public let outputTokens: [Double]
    public let reasoningTokens: [Double]
    public let cacheRead: [Double]
    public let cacheWrite: [Double]
    public let avgTokensPerSession: [Double]

    public init(
      sessions: [Double],
      messages: [Double],
      cost: [Double],
      inputTokens: [Double],
      outputTokens: [Double],
      reasoningTokens: [Double],
      cacheRead: [Double],
      cacheWrite: [Double],
      avgTokensPerSession: [Double]
    ) {
      self.sessions = sessions
      self.messages = messages
      self.cost = cost
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
      self.reasoningTokens = reasoningTokens
      self.cacheRead = cacheRead
      self.cacheWrite = cacheWrite
      self.avgTokensPerSession = avgTokensPerSession
    }

    public static func empty(days: Int = 7) -> OverviewKPITrends {
      let safeDays = max(1, days)
      let zeros = Array(repeating: 0.0, count: safeDays)
      return OverviewKPITrends(
        sessions: zeros,
        messages: zeros,
        cost: zeros,
        inputTokens: zeros,
        outputTokens: zeros,
        reasoningTokens: zeros,
        cacheRead: zeros,
        cacheWrite: zeros,
        avgTokensPerSession: zeros
      )
    }
  }

  public struct DateStats {
    public var date: Date
    public var messageCount: Int
    public var tokenCount: Int
    public var cost: Double
    
    public init(date: Date, messageCount: Int, tokenCount: Int, cost: Double) {
      self.date = date
      self.messageCount = messageCount
      self.tokenCount = tokenCount
      self.cost = cost
    }
  }

  public struct ProjectStats: Identifiable {
    public let id = UUID()
    public var projectRoot: String
    public var sessionCount: Int
    public var messageCount: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheRead: Int
    public var cacheWrite: Int
    public var netCodeLines: Int
    public var fileCount: Int
    public var tokens: Int
    public var cost: Double
    public var activeDays: Int
    public var lastActiveAt: Date?

    public init(projectRoot: String, sessionCount: Int, messageCount: Int, inputTokens: Int, outputTokens: Int, cacheRead: Int, cacheWrite: Int, netCodeLines: Int, fileCount: Int, tokens: Int, cost: Double, activeDays: Int, lastActiveAt: Date? = nil) {
      self.projectRoot = projectRoot
      self.sessionCount = sessionCount
      self.messageCount = messageCount
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
      self.cacheRead = cacheRead
      self.cacheWrite = cacheWrite
      self.netCodeLines = netCodeLines
      self.fileCount = fileCount
      self.tokens = tokens
      self.cost = cost
      self.activeDays = activeDays
      self.lastActiveAt = lastActiveAt
    }
  }

  public struct ModelStats: Hashable {
    public var providerId: String
    public var modelId: String
    public var sessionCount: Int
    public var messageCount: Int
    public var tokens: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var reasoningTokens: Int
    public var cost: Double
    public var avgTokensPerMessage: Double
    public var avgCostPerMessage: Double

    public var uniqueId: String { providerId + "-" + modelId }

    public init(providerId: String, modelId: String, sessionCount: Int, messageCount: Int, tokens: Int, inputTokens: Int, outputTokens: Int, reasoningTokens: Int, cost: Double, avgTokensPerMessage: Double, avgCostPerMessage: Double) {
      self.providerId = providerId
      self.modelId = modelId
      self.sessionCount = sessionCount
      self.messageCount = messageCount
      self.tokens = tokens
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
      self.reasoningTokens = reasoningTokens
      self.cost = cost
      self.avgTokensPerMessage = avgTokensPerMessage
      self.avgCostPerMessage = avgCostPerMessage
    }
  }

  public struct ProjectDailyStat {
    public var date: Date
    public var sessionCount: Int
    public var messageCount: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var reasoningTokens: Int
    public var totalCost: Double
    public var totalDuration: Double
    public var totalAdditions: Int
    public var totalDeletions: Int
    public var netCodeLines: Int
    public var fileCount: Int

    public init(date: Date, sessionCount: Int, messageCount: Int, inputTokens: Int, outputTokens: Int, reasoningTokens: Int, totalCost: Double, totalDuration: Double, totalAdditions: Int, totalDeletions: Int, netCodeLines: Int, fileCount: Int) {
      self.date = date
      self.sessionCount = sessionCount
      self.messageCount = messageCount
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
      self.reasoningTokens = reasoningTokens
      self.totalCost = totalCost
      self.totalDuration = totalDuration
      self.totalAdditions = totalAdditions
      self.totalDeletions = totalDeletions
      self.netCodeLines = netCodeLines
      self.fileCount = fileCount
    }
  }

  public struct ModelDailyStat {
    public var date: Date
    public var sessionCount: Int
    public var messageCount: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var reasoningTokens: Int
    public var totalCost: Double
    public var totalDuration: Double
    public var cacheRead: Int
    public var cacheWrite: Int

    public init(date: Date, sessionCount: Int, messageCount: Int, inputTokens: Int, outputTokens: Int, reasoningTokens: Int, totalCost: Double, totalDuration: Double, cacheRead: Int, cacheWrite: Int) {
      self.date = date
      self.sessionCount = sessionCount
      self.messageCount = messageCount
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
      self.reasoningTokens = reasoningTokens
      self.totalCost = totalCost
      self.totalDuration = totalDuration
      self.cacheRead = cacheRead
      self.cacheWrite = cacheWrite
    }
  }

  public struct BillingCostStats {
    public let totalCost: Double
    public let billedMessageCount: Int
    public let totalMessageCount: Int
    public let coverageRatio: Double

    public init(totalCost: Double, billedMessageCount: Int, totalMessageCount: Int, coverageRatio: Double) {
      self.totalCost = totalCost
      self.billedMessageCount = billedMessageCount
      self.totalMessageCount = totalMessageCount
      self.coverageRatio = coverageRatio
    }
  }

  public struct NetCodeOutputStats {
    public let additions: Int
    public let deletions: Int
    public let net: Int

    public init(additions: Int, deletions: Int, net: Int) {
      self.additions = additions
      self.deletions = deletions
      self.net = net
    }
  }

  public struct CodeOutputCostTrendPoint: Identifiable {
    public let id = UUID()
    public let timestamp: TimeInterval
    public let label: String
    public let additions: Double
    public let deletions: Double
    public let billedCost: Double

    public init(timestamp: TimeInterval, label: String, additions: Double, deletions: Double, billedCost: Double) {
      self.timestamp = timestamp
      self.label = label
      self.additions = additions
      self.deletions = deletions
      self.billedCost = billedCost
    }
  }

  public struct UserAgentTrendPoint: Identifiable {
    public let id = UUID()
    public let timestamp: TimeInterval
    public let label: String
    public let userCount: Double
    public let agentCount: Double

    public init(timestamp: TimeInterval, label: String, userCount: Double, agentCount: Double) {
      self.timestamp = timestamp
      self.label = label
      self.userCount = userCount
      self.agentCount = agentCount
    }
  }

  public struct UserAgentCount: Identifiable {
    public let id = UUID()
    public let name: String
    public let count: Int
    public let isUser: Bool

    public init(name: String, count: Int, isUser: Bool) {
      self.name = name
      self.count = count
      self.isUser = isUser
    }
  }

  public struct UserAgentSessionCounts {
    public let userSessions: Int
    public let agentSessions: Int
    public let totalSessions: Int

    public init(userSessions: Int, agentSessions: Int, totalSessions: Int) {
      self.userSessions = userSessions
      self.agentSessions = agentSessions
      self.totalSessions = totalSessions
    }
  }

  public struct AgentSessionCount: Identifiable {
    public let id = UUID()
    public let name: String
    public let sessionCount: Int

    public init(name: String, sessionCount: Int) {
      self.name = name
      self.sessionCount = sessionCount
    }
  }

  public struct ModelProcessingStat: Identifiable {
    public let id = UUID()
    public let providerId: String
    public let modelId: String
    public let sessionCount: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let reasoningTokens: Int
    public let billedCost: Double
    public let inputPerSession: Double
    public let reasoningOutputRatio: Double

    public init(providerId: String, modelId: String, sessionCount: Int, inputTokens: Int, outputTokens: Int, reasoningTokens: Int, billedCost: Double) {
      self.providerId = providerId
      self.modelId = modelId
      self.sessionCount = sessionCount
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
      self.reasoningTokens = reasoningTokens
      self.billedCost = billedCost
      self.inputPerSession = sessionCount > 0 ? Double(inputTokens) / Double(sessionCount) : 0.0
      self.reasoningOutputRatio = outputTokens > 0 ? Double(reasoningTokens) / Double(outputTokens) : 0.0
    }
  }

  public struct RhythmInsights {
    public let peakHour: Int
    public let peakHourMessageCount: Int
    public let nightOwlMessageRatio: Double
    public let nightOwlSessionRatio: Double
    public let weekendMessageRatio: Double
    public let weekendSessionRatio: Double

    public init(peakHour: Int, peakHourMessageCount: Int, nightOwlMessageRatio: Double, nightOwlSessionRatio: Double, weekendMessageRatio: Double, weekendSessionRatio: Double) {
      self.peakHour = peakHour
      self.peakHourMessageCount = peakHourMessageCount
      self.nightOwlMessageRatio = nightOwlMessageRatio
      self.nightOwlSessionRatio = nightOwlSessionRatio
      self.weekendMessageRatio = weekendMessageRatio
      self.weekendSessionRatio = weekendSessionRatio
    }
  }

  public struct AnomalyMetric {
    public let current: Double
    public let mean: Double
    public let stdDev: Double
    public let threshold: Double
    public let isAnomaly: Bool

    public init(current: Double, mean: Double, stdDev: Double) {
      self.current = current
      self.mean = mean
      self.stdDev = stdDev
      self.threshold = mean + (2.0 * stdDev)
      self.isAnomaly = current > (mean + (2.0 * stdDev))
    }
  }

  public struct AnomalyStats {
    public let message: AnomalyMetric
    public let session: AnomalyMetric
    public let cost: AnomalyMetric
    public let netOutput: AnomalyMetric

    public init(message: AnomalyMetric, session: AnomalyMetric, cost: AnomalyMetric, netOutput: AnomalyMetric) {
      self.message = message
      self.session = session
      self.cost = cost
      self.netOutput = netOutput
    }
  }

  public struct HourlyStats {
    public var hour: Int
    public var messageCount: Int

    public init(hour: Int, messageCount: Int) {
      self.hour = hour
      self.messageCount = messageCount
    }
  }

  public struct TrendDataPoint: Identifiable {
    public let id = UUID()
    public let timestamp: TimeInterval
    public let label: String
    public let value: Double
    public let metricType: MetricType
    public var secondaryValue: Double?
  }

  public struct HourlyStat: Identifiable {
    public let id = UUID()
    public let hour: Int
    public let value: Double
    public let metricType: MetricType
    
    public init(hour: Int, value: Double, metricType: MetricType) {
      self.hour = hour
      self.value = value
      self.metricType = metricType
    }
  }

  public func getHourlyBreakdown(timeRange: TimeRange, metric: MetricType) -> [HourlyStat] {
    let (start, end) = getTimestamps(for: timeRange)

    var stats: [HourlyStat] = []
    try? dbPool.read { db in
      let valueField: String
      switch metric {
      case .messages:
        valueField = "COUNT(*)"
      case .tokens:
        valueField = "SUM(\(tokenSumExpression))"
      case .cost:
        valueField = "SUM(cost)"
      case .sessions:
        valueField = "COUNT(DISTINCT session_id)"
      }

      let rows = try Row.fetchAll(db, sql: """
        SELECT
          CAST(strftime('%H', created_at, 'unixepoch', 'localtime') AS INTEGER) as hour,
          \(valueField) as value
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY hour
        ORDER BY hour
      """, arguments: [start, end])

      var hourlyMap: [Int: Double] = [:]
      for hour in 0..<24 {
        hourlyMap[hour] = 0.0
      }
      
      for row in rows {
        let hour = Int(row["hour"] as? Int64 ?? -1)
        guard (0..<24).contains(hour) else { continue }

        let value: Double = {
          if let value = row["value"] as? Double { return value }
          if let value = row["value"] as? Int64 { return Double(value) }
          return 0.0
        }()
        hourlyMap[hour] = value
      }

      stats = hourlyMap.sorted(by: { $0.key < $1.key }).map { hour, value in
        HourlyStat(hour: hour, value: value, metricType: metric)
      }
      return ()
    }
    return stats
  }

  // MARK: - Time Cluster Stats

  public enum Intensity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
  }

  public enum TimeCluster: String, CaseIterable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"
  }

  public struct TimeClusterStat: Identifiable {
    public let id = UUID()
    public let cluster: TimeCluster
    public let messageCount: Int
    public let percentage: Double

    public init(cluster: TimeCluster, messageCount: Int, percentage: Double) {
      self.cluster = cluster
      self.messageCount = messageCount
      self.percentage = percentage
    }
  }

  public struct WeekdayWeekendStats {
    public var weekdayAvg: Double
    public var weekendAvg: Double
    public var weekdayTotal: Int
    public var weekendTotal: Int

    public init(weekdayAvg: Double, weekendAvg: Double, weekdayTotal: Int, weekendTotal: Int) {
      self.weekdayAvg = weekdayAvg
      self.weekendAvg = weekendAvg
      self.weekdayTotal = weekdayTotal
      self.weekendTotal = weekendTotal
    }
  }

  public struct MonthlyStat: Identifiable {
    public let id = UUID()
    public let month: String
    public var value: Double
    public let metricType: MetricType

    public init(month: String, value: Double, metricType: MetricType) {
      self.month = month
      self.value = value
      self.metricType = metricType
    }
  }

  public struct DayActivity: Identifiable {
    public let id = UUID()
    public let date: Date
    public let value: Double
    public let intensity: Intensity

    public init(date: Date, value: Double, intensity: Intensity) {
      self.date = date
      self.value = value
      self.intensity = intensity
    }
  }

  public struct TokenDivergingDataPoint: Identifiable {
    public let id = UUID()
    public let timestamp: TimeInterval
    public let label: String
    public let inputTokens: Double
    public let outputTokens: Double

    public init(timestamp: TimeInterval, label: String, inputTokens: Double, outputTokens: Double) {
      self.timestamp = timestamp
      self.label = label
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
    }
  }

  public struct DualAxisDataPoint: Identifiable {
    public let id = UUID()
    public let timestamp: TimeInterval
    public let label: String
    public let messages: Double
    public let sessions: Double

    public init(timestamp: TimeInterval, label: String, messages: Double, sessions: Double) {
      self.timestamp = timestamp
      self.label = label
      self.messages = messages
      self.sessions = sessions
    }
  }

  public func getTimeClusterStats(timeRange: TimeRange) -> [TimeClusterStat] {
    let (start, end) = getTimestamps(for: timeRange)

    var stats: [TimeClusterStat] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          CASE
            WHEN CAST(strftime('%H', created_at, 'unixepoch', 'localtime') AS INTEGER) BETWEEN 6 AND 11 THEN 'morning'
            WHEN CAST(strftime('%H', created_at, 'unixepoch', 'localtime') AS INTEGER) BETWEEN 12 AND 17 THEN 'afternoon'
            WHEN CAST(strftime('%H', created_at, 'unixepoch', 'localtime') AS INTEGER) BETWEEN 18 AND 23 THEN 'evening'
            ELSE 'night'
          END as cluster,
          COUNT(*) as messageCount
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY cluster
        ORDER BY
          CASE cluster
            WHEN 'morning' THEN 1
            WHEN 'afternoon' THEN 2
            WHEN 'evening' THEN 3
            ELSE 4
          END
      """, arguments: [start, end])

      let totalCount = rows.reduce(0) { $0 + ($1["messageCount"] as? Int64 ?? 0) }

      var clusterMap: [TimeCluster: Int] = [:]

      for row in rows {
        guard let clusterStr = row["cluster"] as? String else { continue }

        let cluster: TimeCluster?
        switch clusterStr.lowercased() {
        case "morning": cluster = .morning
        case "afternoon": cluster = .afternoon
        case "evening": cluster = .evening
        case "night": cluster = .night
        default: cluster = nil
        }

        if let validCluster = cluster {
          let messageCount = Int(row["messageCount"] as? Int64 ?? 0)
          clusterMap[validCluster] = messageCount
        }
      }

      // Fill in missing clusters with 0 count
      for cluster in TimeCluster.allCases {
        let messageCount = clusterMap[cluster] ?? 0
        let percentage = totalCount > 0 ? Double(messageCount) / Double(totalCount) * 100.0 : 0.0
        stats.append(TimeClusterStat(cluster: cluster, messageCount: messageCount, percentage: percentage))
      }

      return ()
    }

    return stats
  }

  public func getWeekdayVsWeekendStats(timeRange: TimeRange) -> WeekdayWeekendStats {
    let (start, end) = getTimestamps(for: timeRange)

    var weekdayTotal = 0, weekendTotal = 0
    var weekdayDays = 0, weekendDays = 0

    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          strftime('%w', datetime(created_at, 'unixepoch', 'localtime')) as dayOfWeek,
          strftime('%Y-%m-%d', created_at, 'unixepoch', 'localtime') as date,
          COUNT(*) as messageCount
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY date
        ORDER BY date ASC
      """, arguments: [start, end])

      for row in rows {
        let dayOfWeek = row["dayOfWeek"] as? String ?? "0"
        let count = Int(row["messageCount"] as? Int64 ?? 0)

        if ["1", "2", "3", "4", "5"].contains(dayOfWeek) {
          weekdayTotal += count
          weekdayDays += 1
        } else {
          weekendTotal += count
          weekendDays += 1
        }
      }

      return ()
    }

    let weekdayAvg = weekdayDays > 0 ? Double(weekdayTotal) / Double(weekdayDays) : 0.0
    let weekendAvg = weekendDays > 0 ? Double(weekendTotal) / Double(weekendDays) : 0.0

    return WeekdayWeekendStats(
      weekdayAvg: weekdayAvg,
      weekendAvg: weekendAvg,
      weekdayTotal: weekdayTotal,
      weekendTotal: weekendTotal
    )
  }

  public func getMonthlyStats(timeRange: TimeRange, metric: MetricType) -> [MonthlyStat] {
    let (start, end) = getTimestamps(for: timeRange)

    var stats: [MonthlyStat] = []
    try? dbPool.read { db in
      let valueField = buildMetricColumn(for: metric)

      let rows = try Row.fetchAll(db, sql: """
        SELECT
          strftime('%Y-%m', datetime(created_at, 'unixepoch', 'localtime')) as month,
          \(valueField) as value
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY month
        ORDER BY month ASC
      """, arguments: [start, end])

      stats = rows.compactMap { row -> MonthlyStat? in
        guard let month = row["month"] as? String else { return nil }
        let value = row["value"] as? Double ?? 0.0
        return MonthlyStat(month: month, value: value, metricType: metric)
      }

      return ()
    }

    return stats
  }

  public func getActiveStreakData(year: Int) -> [DayActivity] {
    var start: TimeInterval = 0
    var end: TimeInterval = 0

    var calendar = Calendar.current
    calendar.timeZone = TimeZone.current
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current

    if let startDate = dateFormatter.date(from: "\(year)-01-01"),
       let endDate = calendar.date(byAdding: .day, value: 1, to: dateFormatter.date(from: "\(year)-12-31")!) {
      start = startDate.timeIntervalSince1970
      end = endDate.timeIntervalSince1970
    }

    var activities: [DayActivity] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          strftime('%Y-%m-%d', created_at, 'unixepoch', 'localtime') as date,
          COUNT(*) as value
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY date
        ORDER BY date ASC
      """, arguments: [start, end])

      activities = rows.compactMap { row -> DayActivity? in
        guard let dateStr = row["date"] as? String,
              let date = dateFormatter.date(from: dateStr) else { return nil }

        let value = Double(row["value"] as? Int64 ?? 0)
        let intensity: Intensity
        if value < 5 {
          intensity = .low
        } else if value < 20 {
          intensity = .medium
        } else {
          intensity = .high
        }

        return DayActivity(date: date, value: value, intensity: intensity)
      }

      return ()
    }

    return activities
  }

  private var tokenSumExpression: String {
    "COALESCE(CAST(token_input AS INTEGER), 0) + " +
    "COALESCE(CAST(token_output AS INTEGER), 0) + " +
    "COALESCE(CAST(token_reasoning AS INTEGER), 0)"
  }

  private func buildMetricColumn(for metric: MetricType) -> String {
    switch metric {
    case .messages:
      return "COUNT(*)"
    case .tokens:
      return "SUM(\(tokenSumExpression))"
    case .cost:
      return "SUM(cost)"
    case .sessions:
      return "COUNT(DISTINCT session_id)"
    }
  }

  // MARK: - Overview Queries

  public func getOverviewStats(timeRange: TimeRange) -> OverviewStats {
    let (start, end) = getTimestamps(for: timeRange)

    var overview: OverviewStats? = OverviewStats(totalSessions: 0, totalMessages: 0, totalCost: 0.0, totalTokens: 0, inputTokens: 0, outputTokens: 0, reasoningTokens: 0, cacheRead: 0, cacheWrite: 0)
    try? dbPool.read { db in
      let row = try Row.fetchOne(db, sql: """
        SELECT
          (SELECT COUNT(DISTINCT session_id) FROM messages WHERE created_at >= ? AND created_at <= ?) as totalSessions,
          (SELECT COUNT(*) FROM messages WHERE created_at >= ? AND created_at <= ?) as totalMessages,
          (SELECT SUM(cost) FROM messages WHERE created_at >= ? AND created_at <= ?) as totalCost,
          (SELECT SUM(\(tokenSumExpression)) FROM messages WHERE created_at >= ? AND created_at <= ?) as totalTokens,
          (SELECT SUM(CAST(token_input AS INTEGER)) FROM messages WHERE created_at >= ? AND created_at <= ?) as inputTokens,
          (SELECT SUM(CAST(token_output AS INTEGER)) FROM messages WHERE created_at >= ? AND created_at <= ?) as outputTokens,
          (SELECT SUM(CAST(token_reasoning AS INTEGER)) FROM messages WHERE created_at >= ? AND created_at <= ?) as reasoningTokens,
          (SELECT SUM(cache_read) FROM messages WHERE created_at >= ? AND created_at <= ?) as cacheRead,
          (SELECT SUM(cache_write) FROM messages WHERE created_at >= ? AND created_at <= ?) as cacheWrite
      """, arguments: [start, end, start, end, start, end, start, end, start, end, start, end, start, end, start, end, start, end])

      if let row = row {
        overview = OverviewStats(
          totalSessions: Int(row["totalSessions"] as? Int64 ?? 0),
          totalMessages: Int(row["totalMessages"] as? Int64 ?? 0),
          totalCost: row["totalCost"] as? Double ?? 0.0,
          totalTokens: Int(row["totalTokens"] as? Int64 ?? 0),
          inputTokens: Int(row["inputTokens"] as? Int64 ?? 0),
          outputTokens: Int(row["outputTokens"] as? Int64 ?? 0),
          reasoningTokens: Int(row["reasoningTokens"] as? Int64 ?? 0),
          cacheRead: Int(row["cacheRead"] as? Int64 ?? 0),
          cacheWrite: Int(row["cacheWrite"] as? Int64 ?? 0)
        )
      }
      return ()
    }
    return overview!
  }

  public func getOverviewStatsOptimized(timeRange: TimeRange) -> OverviewStats {
    let (start, end) = getTimestamps(for: timeRange)
    
    // Choose aggregate table based on time range
    let tableName: String
    switch timeRange {
    case .today:
      tableName = "hourly_stats"
    default:
      tableName = "daily_stats"
    }
    
    var overview: OverviewStats? = OverviewStats(totalSessions: 0, totalMessages: 0, totalCost: 0.0, totalTokens: 0, inputTokens: 0, outputTokens: 0, reasoningTokens: 0, cacheRead: 0, cacheWrite: 0)
    try? dbPool.read { db in
      let row = try Row.fetchOne(db, sql: """
        SELECT
          COALESCE(SUM(session_count), 0) as totalSessions,
          COALESCE(SUM(message_count), 0) as totalMessages,
          COALESCE(SUM(cost), 0.0) as totalCost,
          COALESCE(SUM(input_tokens + output_tokens + reasoning_tokens), 0) as totalTokens,
          COALESCE(SUM(input_tokens), 0) as inputTokens,
          COALESCE(SUM(output_tokens), 0) as outputTokens,
          COALESCE(SUM(reasoning_tokens), 0) as reasoningTokens,
          COALESCE(SUM(cache_read), 0) as cacheRead,
          COALESCE(SUM(cache_write), 0) as cacheWrite
        FROM \(tableName)
        WHERE time_bucket_ms >= ? AND time_bucket_ms < ?
      """, arguments: [start, end])
      
      if let row = row {
        overview = OverviewStats(
          totalSessions: Int(row["totalSessions"] as? Int64 ?? 0),
          totalMessages: Int(row["totalMessages"] as? Int64 ?? 0),
          totalCost: row["totalCost"] as? Double ?? 0.0,
          totalTokens: Int(row["totalTokens"] as? Int64 ?? 0),
          inputTokens: Int(row["inputTokens"] as? Int64 ?? 0),
          outputTokens: Int(row["outputTokens"] as? Int64 ?? 0),
          reasoningTokens: Int(row["reasoningTokens"] as? Int64 ?? 0),
          cacheRead: Int(row["cacheRead"] as? Int64 ?? 0),
          cacheWrite: Int(row["cacheWrite"] as? Int64 ?? 0)
        )
      }
      return ()
    }
    return overview!
  }

  public func getOverviewKPITrends(lastNDays: Int = 7) -> OverviewKPITrends {
    let safeDays = max(1, lastNDays)

    var calendar = Calendar.current
    calendar.timeZone = TimeZone.current
    let todayStart = calendar.startOfDay(for: Date())

    guard
      let startDate = calendar.date(byAdding: .day, value: -(safeDays - 1), to: todayStart),
      let endDateExclusive = calendar.date(byAdding: .day, value: 1, to: todayStart)
    else {
      return .empty(days: safeDays)
    }

    let startMs = Int64(startDate.timeIntervalSince1970 * 1000)
    let endMs = Int64(endDateExclusive.timeIntervalSince1970 * 1000)

    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "yyyy-MM-dd"
    dayFormatter.timeZone = TimeZone.current

    struct DailyOverviewTotals {
      let sessions: Double
      let messages: Double
      let cost: Double
      let inputTokens: Double
      let outputTokens: Double
      let reasoningTokens: Double
      let cacheRead: Double
      let cacheWrite: Double
      let totalTokens: Double

      static let zero = DailyOverviewTotals(
        sessions: 0,
        messages: 0,
        cost: 0,
        inputTokens: 0,
        outputTokens: 0,
        reasoningTokens: 0,
        cacheRead: 0,
        cacheWrite: 0,
        totalTokens: 0
      )
    }

    var totalsByDay: [String: DailyOverviewTotals] = [:]

    if hasAggregationData(in: "daily_stats") {
      try? dbPool.read { db in
        let rows = try Row.fetchAll(db, sql: """
          SELECT
            strftime('%Y-%m-%d', time_bucket_ms / 1000.0, 'unixepoch', 'localtime') AS day_key,
            COALESCE(SUM(session_count), 0) AS sessions,
            COALESCE(SUM(message_count), 0) AS messages,
            COALESCE(SUM(cost), 0) AS cost,
            COALESCE(SUM(input_tokens), 0) AS input_tokens,
            COALESCE(SUM(output_tokens), 0) AS output_tokens,
            COALESCE(SUM(reasoning_tokens), 0) AS reasoning_tokens,
            COALESCE(SUM(cache_read), 0) AS cache_read,
            COALESCE(SUM(cache_write), 0) AS cache_write,
            COALESCE(SUM(input_tokens + output_tokens + reasoning_tokens), 0) AS total_tokens
          FROM daily_stats
          WHERE time_bucket_ms >= ? AND time_bucket_ms < ?
          GROUP BY day_key
          ORDER BY day_key ASC
        """, arguments: [startMs, endMs])

        for row in rows {
          guard let dayKey = row["day_key"] as? String else { continue }
          totalsByDay[dayKey] = DailyOverviewTotals(
            sessions: Self.numericValue(row: row, key: "sessions"),
            messages: Self.numericValue(row: row, key: "messages"),
            cost: Self.numericValue(row: row, key: "cost"),
            inputTokens: Self.numericValue(row: row, key: "input_tokens"),
            outputTokens: Self.numericValue(row: row, key: "output_tokens"),
            reasoningTokens: Self.numericValue(row: row, key: "reasoning_tokens"),
            cacheRead: Self.numericValue(row: row, key: "cache_read"),
            cacheWrite: Self.numericValue(row: row, key: "cache_write"),
            totalTokens: Self.numericValue(row: row, key: "total_tokens")
          )
        }
      }
    } else {
      try? dbPool.read { db in
        let rows = try Row.fetchAll(db, sql: """
          SELECT
            strftime('%Y-%m-%d', created_at / 1000.0, 'unixepoch', 'localtime') AS day_key,
            COUNT(DISTINCT session_id) AS sessions,
            COUNT(*) AS messages,
            COALESCE(SUM(cost), 0) AS cost,
            COALESCE(SUM(CAST(COALESCE(token_input, '0') AS INTEGER)), 0) AS input_tokens,
            COALESCE(SUM(CAST(COALESCE(token_output, '0') AS INTEGER)), 0) AS output_tokens,
            COALESCE(SUM(CAST(COALESCE(token_reasoning, '0') AS INTEGER)), 0) AS reasoning_tokens,
            COALESCE(SUM(COALESCE(cache_read, 0)), 0) AS cache_read,
            COALESCE(SUM(COALESCE(cache_write, 0)), 0) AS cache_write,
            COALESCE(SUM(
              CAST(COALESCE(token_input, '0') AS INTEGER) +
              CAST(COALESCE(token_output, '0') AS INTEGER) +
              CAST(COALESCE(token_reasoning, '0') AS INTEGER)
            ), 0) AS total_tokens
          FROM messages
          WHERE created_at >= ? AND created_at < ?
          GROUP BY day_key
          ORDER BY day_key ASC
        """, arguments: [startMs, endMs])

        for row in rows {
          guard let dayKey = row["day_key"] as? String else { continue }
          totalsByDay[dayKey] = DailyOverviewTotals(
            sessions: Self.numericValue(row: row, key: "sessions"),
            messages: Self.numericValue(row: row, key: "messages"),
            cost: Self.numericValue(row: row, key: "cost"),
            inputTokens: Self.numericValue(row: row, key: "input_tokens"),
            outputTokens: Self.numericValue(row: row, key: "output_tokens"),
            reasoningTokens: Self.numericValue(row: row, key: "reasoning_tokens"),
            cacheRead: Self.numericValue(row: row, key: "cache_read"),
            cacheWrite: Self.numericValue(row: row, key: "cache_write"),
            totalTokens: Self.numericValue(row: row, key: "total_tokens")
          )
        }
      }
    }

    var sessions: [Double] = []
    var messages: [Double] = []
    var cost: [Double] = []
    var inputTokens: [Double] = []
    var outputTokens: [Double] = []
    var reasoningTokens: [Double] = []
    var cacheRead: [Double] = []
    var cacheWrite: [Double] = []
    var avgTokensPerSession: [Double] = []

    sessions.reserveCapacity(safeDays)
    messages.reserveCapacity(safeDays)
    cost.reserveCapacity(safeDays)
    inputTokens.reserveCapacity(safeDays)
    outputTokens.reserveCapacity(safeDays)
    reasoningTokens.reserveCapacity(safeDays)
    cacheRead.reserveCapacity(safeDays)
    cacheWrite.reserveCapacity(safeDays)
    avgTokensPerSession.reserveCapacity(safeDays)

    for offset in 0..<safeDays {
      guard let day = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
      let dayKey = dayFormatter.string(from: day)
      let totals = totalsByDay[dayKey] ?? .zero

      sessions.append(totals.sessions)
      messages.append(totals.messages)
      cost.append(totals.cost)
      inputTokens.append(totals.inputTokens)
      outputTokens.append(totals.outputTokens)
      reasoningTokens.append(totals.reasoningTokens)
      cacheRead.append(totals.cacheRead)
      cacheWrite.append(totals.cacheWrite)
      if totals.sessions > 0 {
        avgTokensPerSession.append(totals.totalTokens / totals.sessions)
      } else {
        avgTokensPerSession.append(0)
      }
    }

    return OverviewKPITrends(
      sessions: sessions,
      messages: messages,
      cost: cost,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      reasoningTokens: reasoningTokens,
      cacheRead: cacheRead,
      cacheWrite: cacheWrite,
      avgTokensPerSession: avgTokensPerSession
    )
  }

  // MARK: - Time Buckets

  public func getDailyStats(timeRange: TimeRange) -> [DateStats] {
    let (start, end) = getTimestamps(for: timeRange)

    var stats: [DateStats] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          strftime('%Y-%m-%d', created_at, 'unixepoch', 'localtime') as date,
          COUNT(*) as messageCount,
          SUM(\(tokenSumExpression)) as tokenCount,
          SUM(cost) as cost
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY strftime('%Y-%m-%d', created_at, 'unixepoch', 'localtime')
        ORDER BY date ASC
      """, arguments: [start, end])

      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd"
      dateFormatter.timeZone = TimeZone.current
      
      stats = rows.compactMap { row -> DateStats? in
        guard let dateStr = row["date"] as? String,
              let date = dateFormatter.date(from: dateStr) else { return nil }
        return DateStats(
          date: date,
          messageCount: Int(row["messageCount"] as? Int64 ?? 0),
          tokenCount: Int(row["tokenCount"] as? Int64 ?? 0),
          cost: row["cost"] as? Double ?? 0.0
        )
      }
      return ()
    }
    return stats
  }

  public func getHourlyStats(timeRange: TimeRange) -> [HourlyStats] {
    let (start, end) = getTimestamps(for: timeRange)

    var stats: [HourlyStats] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          CAST(strftime('%H', created_at, 'unixepoch', 'localtime') AS INTEGER) as hour,
          COUNT(*) as messageCount
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY hour
        ORDER BY hour
      """, arguments: [start, end])

      stats = rows.compactMap { row -> HourlyStats? in
        let hour = Int(row["hour"] as? Int64 ?? -1)
        guard (0..<24).contains(hour) else { return nil }
        return HourlyStats(hour: hour, messageCount: Int(row["messageCount"] as? Int64 ?? 0))
      }
      return ()
    }
    return stats
  }

  public func getTrendData(timeRange: TimeRange, metric: MetricType, granularity: TimeGranularity) -> [TrendDataPoint] {
    let (start, end) = getTimestamps(for: timeRange)

    var dataPoints: [TrendDataPoint] = []
    try? dbPool.read { db in
      let valueField: String
      switch metric {
      case .messages:
        valueField = "COUNT(*)"
      case .tokens:
        valueField = "SUM(\(tokenSumExpression))"
      case .cost:
        valueField = "SUM(cost)"
      case .sessions:
        valueField = "COUNT(DISTINCT session_id)"
      }

      let (groupByClause, dateFormat): (String, String)
      switch granularity {
      case .hourly:
        groupByClause = "strftime('%Y-%m-%d %H', created_at, 'unixepoch', 'localtime')"
        dateFormat = "yyyy-MM-dd HH"
      case .daily:
        groupByClause = "strftime('%Y-%m-%d', created_at, 'unixepoch', 'localtime')"
        dateFormat = "yyyy-MM-dd"
      case .weekly:
        groupByClause = "strftime('%Y-%W', datetime(created_at, 'unixepoch', 'localtime'))"
        dateFormat = "yyyy-ww"
      case .monthly:
        groupByClause = "strftime('%Y-%m', datetime(created_at, 'unixepoch', 'localtime'))"
        dateFormat = "yyyy-MM"
      }

      let rows = try Row.fetchAll(db, sql: """
        SELECT
          \(groupByClause) as timeGroup,
          \(valueField) as value
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY timeGroup
        ORDER BY timeGroup ASC
      """, arguments: [start, end])

      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = dateFormat
      dateFormatter.timeZone = TimeZone.current

      dataPoints = rows.compactMap { row -> TrendDataPoint? in
        guard let timeGroupStr = row["timeGroup"] as? String,
              let date = dateFormatter.date(from: timeGroupStr) else { return nil }

        let value: Double = {
          if let value = row["value"] as? Double { return value }
          if let value = row["value"] as? Int64 { return Double(value) }
          return 0.0
        }()
        return TrendDataPoint(
          timestamp: date.timeIntervalSince1970,
          label: timeGroupStr,
          value: value,
          metricType: metric
        )
      }

      // Fill in missing dates (for daily granularity)
      if granularity == .daily && !dataPoints.isEmpty {
        let startDate = Date(timeIntervalSince1970: Double(start) / 1000.0)
        let endDate = Date(timeIntervalSince1970: Double(end) / 1000.0)

        let allDates = generateDateRange(from: startDate, to: endDate, granularity: .daily)

        let dateMap = Dictionary(uniqueKeysWithValues: dataPoints.map {
          (Date(timeIntervalSince1970: $0.timestamp), $0)
        })

        var filledDataPoints: [TrendDataPoint] = []
        for date in allDates {
          if let existing = dateMap[date] {
            filledDataPoints.append(existing)
          } else {
            filledDataPoints.append(TrendDataPoint(
              timestamp: date.timeIntervalSince1970,
              label: dateFormatter.string(from: date),
              value: 0.0,
              metricType: metric
            ))
          }
        }
        dataPoints = filledDataPoints.sorted { $0.timestamp < $1.timestamp }
      }

      if granularity == .hourly {
        let existingByLabel = Dictionary(uniqueKeysWithValues: dataPoints.map { ($0.label, $0) })
        var filledDataPoints: [TrendDataPoint] = []

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        if case .today = timeRange {
          // Stable 00..23 series for the current local day.
          let startDate = Date(timeIntervalSince1970: Double(start) / 1000.0)
          let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
          let alignedStart = calendar.date(from: startComponents)!

          for hourOffset in 0..<24 {
            let hourDate = calendar.date(byAdding: .hour, value: hourOffset, to: alignedStart)!
            let label = dateFormatter.string(from: hourDate)

            if let existing = existingByLabel[label] {
              filledDataPoints.append(existing)
            } else {
              filledDataPoints.append(TrendDataPoint(
                timestamp: hourDate.timeIntervalSince1970,
                label: label,
                value: 0.0,
                metricType: metric
              ))
            }
          }
          dataPoints = filledDataPoints
        } else {
          // Rolling 24h window anchored to the end hour boundary.
          let endDate = Date(timeIntervalSince1970: Double(end) / 1000.0)
          let endComponents = calendar.dateComponents([.year, .month, .day, .hour], from: endDate)
          let alignedEnd = calendar.date(from: endComponents)!

          for hourOffset in 0..<24 {
            let hourDate = calendar.date(byAdding: .hour, value: -hourOffset, to: alignedEnd)!
            let label = dateFormatter.string(from: hourDate)

            if let existing = existingByLabel[label] {
              filledDataPoints.append(existing)
            } else {
              filledDataPoints.append(TrendDataPoint(
                timestamp: hourDate.timeIntervalSince1970,
                label: label,
                value: 0.0,
                metricType: metric
              ))
            }
          }
          // Reverse so oldest hour is first (leftmost on chart)
          dataPoints = filledDataPoints.reversed()
        }
      }

      return ()
    }
    return dataPoints
  }

  private func generateDateRange(from startDate: Date, to endDate: Date, granularity: TimeGranularity) -> [Date] {
    var calendar = Calendar.current
    calendar.timeZone = TimeZone.current
    var dates: [Date] = []
    var currentDate = startDate

    while currentDate < endDate {
      dates.append(currentDate)
      switch granularity {
      case .daily:
        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
      case .weekly:
        currentDate = calendar.date(byAdding: .day, value: 7, to: currentDate)!
      case .monthly:
        currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
      case .hourly:
        currentDate = calendar.date(byAdding: .hour, value: 1, to: currentDate)!
      }
    }

    return dates
  }

  private func timeGrouping(for granularity: TimeGranularity) -> (groupBy: String, dateFormat: String) {
    switch granularity {
    case .hourly:
      return ("strftime('%Y-%m-%d %H', created_at, 'unixepoch', 'localtime')", "yyyy-MM-dd HH")
    case .daily:
      return ("strftime('%Y-%m-%d', created_at, 'unixepoch', 'localtime')", "yyyy-MM-dd")
    case .weekly:
      return ("strftime('%Y-%W', datetime(created_at, 'unixepoch', 'localtime'))", "yyyy-ww")
    case .monthly:
      return ("strftime('%Y-%m', datetime(created_at, 'unixepoch', 'localtime'))", "yyyy-MM")
    }
  }

  private func buildAnomalyMetric(series: [Double], current: Double) -> AnomalyMetric {
    guard !series.isEmpty else {
      return AnomalyMetric(current: current, mean: 0.0, stdDev: 0.0)
    }
    let mean = series.reduce(0.0, +) / Double(series.count)
    let variance = series.reduce(0.0) { $0 + pow($1 - mean, 2.0) } / Double(series.count)
    let stdDev = sqrt(variance)
    return AnomalyMetric(current: current, mean: mean, stdDev: stdDev)
  }

  public func getTokenDivergingData(timeRange: TimeRange, granularity: TimeGranularity) -> [TokenDivergingDataPoint] {
    let (start, end) = getTimestamps(for: timeRange)

    var dataPoints: [TokenDivergingDataPoint] = []
    try? dbPool.read { db in
      let (groupByClause, dateFormat): (String, String)
      switch granularity {
      case .hourly:
        groupByClause = "strftime('%Y-%m-%d %H', created_at, 'unixepoch', 'localtime')"
        dateFormat = "yyyy-MM-dd HH"
      case .daily:
        groupByClause = "strftime('%Y-%m-%d', created_at, 'unixepoch', 'localtime')"
        dateFormat = "yyyy-MM-dd"
      case .weekly:
        groupByClause = "strftime('%Y-%W', datetime(created_at, 'unixepoch', 'localtime'))"
        dateFormat = "yyyy-ww"
      case .monthly:
        groupByClause = "strftime('%Y-%m', datetime(created_at, 'unixepoch', 'localtime'))"
        dateFormat = "yyyy-MM"
      }

      let rows = try Row.fetchAll(db, sql: """
        SELECT
          \(groupByClause) as timeGroup,
          SUM(CAST(token_input AS INTEGER)) as inputTokens,
          SUM(CAST(token_output AS INTEGER)) as outputTokens
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY timeGroup
        ORDER BY timeGroup ASC
      """, arguments: [start, end])

      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = dateFormat
      dateFormatter.timeZone = TimeZone.current

      dataPoints = rows.compactMap { row -> TokenDivergingDataPoint? in
        guard let timeGroupStr = row["timeGroup"] as? String,
              let date = dateFormatter.date(from: timeGroupStr) else { return nil }

        let inputTokens = Double(row["inputTokens"] as? Int64 ?? 0)
        let outputTokens = Double(row["outputTokens"] as? Int64 ?? 0)
        return TokenDivergingDataPoint(
          timestamp: date.timeIntervalSince1970,
          label: timeGroupStr,
          inputTokens: inputTokens,
          outputTokens: outputTokens
        )
      }

      if granularity == .hourly {
        let existingByLabel = Dictionary(uniqueKeysWithValues: dataPoints.map { ($0.label, $0) })
        var filledDataPoints: [TokenDivergingDataPoint] = []

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        if case .today = timeRange {
          // Stable 00..23 series for the current local day.
          let startDate = Date(timeIntervalSince1970: Double(start) / 1000.0)
          let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
          let alignedStart = calendar.date(from: startComponents)!

          for hourOffset in 0..<24 {
            let hourDate = calendar.date(byAdding: .hour, value: hourOffset, to: alignedStart)!
            let label = dateFormatter.string(from: hourDate)

            if let existing = existingByLabel[label] {
              filledDataPoints.append(existing)
            } else {
              filledDataPoints.append(TokenDivergingDataPoint(
                timestamp: hourDate.timeIntervalSince1970,
                label: label,
                inputTokens: 0.0,
                outputTokens: 0.0
              ))
            }
          }
          dataPoints = filledDataPoints
        } else {
          // Rolling 24h window anchored to the end hour boundary.
          let endDate = Date(timeIntervalSince1970: Double(end) / 1000.0)
          let endComponents = calendar.dateComponents([.year, .month, .day, .hour], from: endDate)
          let alignedEnd = calendar.date(from: endComponents)!

          for hourOffset in 0..<24 {
            let hourDate = calendar.date(byAdding: .hour, value: -hourOffset, to: alignedEnd)!
            let label = dateFormatter.string(from: hourDate)

            if let existing = existingByLabel[label] {
              filledDataPoints.append(existing)
            } else {
              filledDataPoints.append(TokenDivergingDataPoint(
                timestamp: hourDate.timeIntervalSince1970,
                label: label,
                inputTokens: 0.0,
                outputTokens: 0.0
              ))
            }
          }
          dataPoints = filledDataPoints.reversed()
        }
      }

      return ()
    }
    return dataPoints
  }

  // MARK: - Input Tokens Aggregation Queries

  public func getInputTokensByProject(timeRange: TimeRange, topN: Int = 6) -> [SegmentedBarDataPoint] {
    let (start, end) = getTimestamps(for: timeRange)
    var dataPoints: [SegmentedBarDataPoint] = []

    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          project_root,
          SUM(CAST(token_input AS INTEGER)) as totalTokens,
          MAX(created_at) as latestTimestamp
        FROM messages
        WHERE created_at >= ? AND created_at <= ? AND project_root IS NOT NULL
        GROUP BY project_root
        ORDER BY totalTokens DESC
      """, arguments: [start, end])

      let topProjects = rows.prefix(topN)
      let otherTokens = rows.dropFirst(topN).reduce(0) { $0 + Int64(truncating: ($1["totalTokens"] as? NSNumber ?? 0)) }

      var allDataPoints: [SegmentedBarDataPoint] = []

      for row in topProjects {
        guard let project = row["project_root"] as? String else { continue }
        let tokens = Double(row["totalTokens"] as? Int64 ?? 0)
        let timestampMs = row["latestTimestamp"] as? Int64 ?? end
        let timestamp = Double(timestampMs) / 1000.0

        let displayName = (project as NSString).lastPathComponent
        allDataPoints.append(SegmentedBarDataPoint(
          timestamp: timestamp,
          label: displayName,
          dimension: .project,
          dimensionValue: project,
          value: tokens
        ))
      }

      if otherTokens > 0 {
        allDataPoints.append(SegmentedBarDataPoint(
          timestamp: Double(end) / 1000.0,
          label: "Other",
          dimension: .project,
          dimensionValue: "Other",
          value: Double(otherTokens)
        ))
      }

      dataPoints = allDataPoints
      return ()
    }
    return dataPoints
  }

  public func getInputTokensByModel(timeRange: TimeRange, topN: Int = 6) -> [SegmentedBarDataPoint] {
    let (start, end) = getTimestamps(for: timeRange)
    var dataPoints: [SegmentedBarDataPoint] = []

    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          model_id,
          SUM(CAST(token_input AS INTEGER)) as totalTokens,
          MAX(created_at) as latestTimestamp
        FROM messages
        WHERE created_at >= ? AND created_at <= ? AND model_id IS NOT NULL
        GROUP BY model_id
        ORDER BY totalTokens DESC
      """, arguments: [start, end])

      let topModels = rows.prefix(topN)
      let otherTokens = rows.dropFirst(topN).reduce(0) { $0 + Int64(truncating: ($1["totalTokens"] as? NSNumber ?? 0)) }

      var allDataPoints: [SegmentedBarDataPoint] = []

      for row in topModels {
        guard let model = row["model_id"] as? String else { continue }
        let tokens = Double(row["totalTokens"] as? Int64 ?? 0)
        let timestampMs = row["latestTimestamp"] as? Int64 ?? end
        let timestamp = Double(timestampMs) / 1000.0

        allDataPoints.append(SegmentedBarDataPoint(
          timestamp: timestamp,
          label: model,
          dimension: .model,
          dimensionValue: model,
          value: tokens
        ))
      }

      if otherTokens > 0 {
        allDataPoints.append(SegmentedBarDataPoint(
          timestamp: Double(end) / 1000.0,
          label: "Other",
          dimension: .model,
          dimensionValue: "Other",
          value: Double(otherTokens)
        ))
      }

      dataPoints = allDataPoints
      return ()
    }
    return dataPoints
  }

  public func getUserAgentMessageCounts(timeRange: TimeRange) -> [UserAgentCount] {
    let (start, end) = getTimestamps(for: timeRange)

    var userCount = 0
    var agentCount = 0

    try? dbPool.read { db in
      if let row = try Row.fetchOne(db, sql: """
        SELECT
          SUM(CASE WHEN role = 'user' THEN 1 ELSE 0 END) AS user_count,
          SUM(CASE WHEN role = 'assistant' OR (agent IS NOT NULL AND agent != '') THEN 1 ELSE 0 END) AS agent_count
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
      """, arguments: [start, end]) {
        userCount = Int(row["user_count"] as? Int64 ?? 0)
        agentCount = Int(row["agent_count"] as? Int64 ?? 0)
      }
      return ()
    }

    return [
      UserAgentCount(name: "User", count: userCount, isUser: true),
      UserAgentCount(name: "Agent", count: agentCount, isUser: false)
    ]
  }

  public func getUserAgentSessionCounts(timeRange: TimeRange) -> UserAgentSessionCounts {
    let (start, end) = getTimestamps(for: timeRange)

    var userSessions = 0
    var agentSessions = 0
    var totalSessions = 0

    try? dbPool.read { db in
      if let row = try Row.fetchOne(db, sql: """
        SELECT
          COUNT(DISTINCT CASE WHEN role = 'user' THEN session_id END) AS user_sessions,
          COUNT(DISTINCT CASE WHEN role = 'assistant' OR (agent IS NOT NULL AND agent != '') THEN session_id END) AS agent_sessions,
          COUNT(DISTINCT session_id) AS total_sessions
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
      """, arguments: [start, end]) {
        userSessions = Int(row["user_sessions"] as? Int64 ?? 0)
        agentSessions = Int(row["agent_sessions"] as? Int64 ?? 0)
        totalSessions = Int(row["total_sessions"] as? Int64 ?? 0)
      }
      return ()
    }

    return UserAgentSessionCounts(
      userSessions: userSessions,
      agentSessions: agentSessions,
      totalSessions: totalSessions
    )
  }

  public func getAgentSessionDistribution(timeRange: TimeRange) -> [AgentSessionCount] {
    let (start, end) = getTimestamps(for: timeRange)
    var result: [AgentSessionCount] = []

    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          COALESCE(NULLIF(agent, ''), 'Assistant') AS agent_name,
          COUNT(DISTINCT session_id) AS session_count
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
          AND (role = 'assistant' OR (agent IS NOT NULL AND agent != ''))
        GROUP BY agent_name
        ORDER BY session_count DESC
      """, arguments: [start, end])

      result = rows.compactMap { row in
        guard let name = row["agent_name"] as? String else { return nil }
        let count = Int(row["session_count"] as? Int64 ?? 0)
        return AgentSessionCount(name: name, sessionCount: count)
      }

      let userSessionCount = (try? Int.fetchOne(
        db,
        sql: """
          SELECT COUNT(DISTINCT session_id)
          FROM messages
          WHERE created_at >= ? AND created_at <= ? AND role = 'user'
        """,
        arguments: [start, end]
      )) ?? 0

      if userSessionCount > 0 {
        result.append(AgentSessionCount(name: "User", sessionCount: userSessionCount))
      }
      return ()
    }

    return result.sorted(by: { $0.sessionCount > $1.sessionCount })
  }

  public func getNetCodeOutputStats(timeRange: TimeRange) -> NetCodeOutputStats {
    let (additions, deletions, _) = getCodeOutputStats(timeRange: timeRange)
    return NetCodeOutputStats(additions: additions, deletions: deletions, net: additions - deletions)
  }

  public func getBillingCostStats(timeRange: TimeRange) -> BillingCostStats {
    let (start, end) = getTimestamps(for: timeRange)

    var totalCost: Double = 0.0
    var billedCount = 0
    var totalCount = 0

    try? dbPool.read { db in
      if let row = try Row.fetchOne(db, sql: """
        SELECT
          SUM(CASE WHEN cost > 0 THEN cost ELSE 0 END) as totalCost,
          SUM(CASE WHEN cost > 0 THEN 1 ELSE 0 END) as billedCount,
          COUNT(*) as totalCount
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
      """, arguments: [start, end]) {
        totalCost = row["totalCost"] as? Double ?? 0.0
        billedCount = Int(row["billedCount"] as? Int64 ?? 0)
        totalCount = Int(row["totalCount"] as? Int64 ?? 0)
      }
      return ()
    }

    let coverage = totalCount > 0 ? Double(billedCount) / Double(totalCount) : 0.0
    return BillingCostStats(totalCost: totalCost, billedMessageCount: billedCount, totalMessageCount: totalCount, coverageRatio: coverage)
  }

  public func getUserAgentMessageTrend(timeRange: TimeRange, granularity: TimeGranularity) -> [UserAgentTrendPoint] {
    let (start, end) = getTimestamps(for: timeRange)
    var dataPoints: [UserAgentTrendPoint] = []

    let (groupByClause, dateFormat) = timeGrouping(for: granularity)

    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          \(groupByClause) as timeGroup,
          SUM(CASE WHEN role = 'user' THEN 1 ELSE 0 END) as userCount,
          SUM(CASE WHEN role = 'assistant' OR (agent IS NOT NULL AND agent != '') THEN 1 ELSE 0 END) as agentCount
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY timeGroup
        ORDER BY timeGroup ASC
      """, arguments: [start, end])

      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = dateFormat
      dateFormatter.timeZone = TimeZone.current

      dataPoints = rows.compactMap { row in
        guard let timeGroupStr = row["timeGroup"] as? String,
              let date = dateFormatter.date(from: timeGroupStr) else { return nil }
        let userCount = row["userCount"] as? Double ?? 0.0
        let agentCount = row["agentCount"] as? Double ?? 0.0
        return UserAgentTrendPoint(
          timestamp: date.timeIntervalSince1970,
          label: timeGroupStr,
          userCount: userCount,
          agentCount: agentCount
        )
      }

      if granularity == .daily && !dataPoints.isEmpty {
        let startDate = Date(timeIntervalSince1970: Double(start) / 1000.0)
        let endDate = Date(timeIntervalSince1970: Double(end) / 1000.0)
        let allDates = generateDateRange(from: startDate, to: endDate, granularity: .daily)
        let dateMap = Dictionary(uniqueKeysWithValues: dataPoints.map {
          (Date(timeIntervalSince1970: $0.timestamp), $0)
        })

        var filled: [UserAgentTrendPoint] = []
        for date in allDates {
          if let existing = dateMap[date] {
            filled.append(existing)
          } else {
            filled.append(UserAgentTrendPoint(
              timestamp: date.timeIntervalSince1970,
              label: dateFormatter.string(from: date),
              userCount: 0.0,
              agentCount: 0.0
            ))
          }
        }
        dataPoints = filled.sorted { $0.timestamp < $1.timestamp }
      }

      if granularity == .hourly {
        var filled: [UserAgentTrendPoint] = []
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let endDate = Date(timeIntervalSince1970: Double(end) / 1000.0)
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour], from: endDate)
        let alignedEnd = calendar.date(from: endComponents)!

        for hourOffset in 0..<24 {
          let hourDate = calendar.date(byAdding: .hour, value: -hourOffset, to: alignedEnd)!
          let label = dateFormatter.string(from: hourDate)
          if let existing = dataPoints.first(where: { $0.label == label }) {
            filled.append(existing)
          } else {
            filled.append(UserAgentTrendPoint(
              timestamp: hourDate.timeIntervalSince1970,
              label: label,
              userCount: 0.0,
              agentCount: 0.0
            ))
          }
        }
        dataPoints = filled.reversed()
      }

      return ()
    }

    return dataPoints
  }

  public func getCodeOutputCostTrend(timeRange: TimeRange, granularity: TimeGranularity) -> [CodeOutputCostTrendPoint] {
    let (start, end) = getTimestamps(for: timeRange)
    var dataPoints: [CodeOutputCostTrendPoint] = []
    let (groupByClause, dateFormat) = timeGrouping(for: granularity)

    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          \(groupByClause) as timeGroup,
          SUM(summary_total_additions) as additions,
          SUM(summary_total_deletions) as deletions,
          SUM(CASE WHEN cost > 0 THEN cost ELSE 0 END) as billedCost
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY timeGroup
        ORDER BY timeGroup ASC
      """, arguments: [start, end])

      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = dateFormat
      dateFormatter.timeZone = TimeZone.current

      dataPoints = rows.compactMap { row in
        guard let timeGroupStr = row["timeGroup"] as? String,
              let date = dateFormatter.date(from: timeGroupStr) else { return nil }
        let additions = row["additions"] as? Double ?? 0.0
        let deletions = row["deletions"] as? Double ?? 0.0
        let billedCost = row["billedCost"] as? Double ?? 0.0
        return CodeOutputCostTrendPoint(
          timestamp: date.timeIntervalSince1970,
          label: timeGroupStr,
          additions: additions,
          deletions: deletions,
          billedCost: billedCost
        )
      }

      if granularity == .daily && !dataPoints.isEmpty {
        let startDate = Date(timeIntervalSince1970: Double(start) / 1000.0)
        let endDate = Date(timeIntervalSince1970: Double(end) / 1000.0)
        let allDates = generateDateRange(from: startDate, to: endDate, granularity: .daily)
        let dateMap = Dictionary(uniqueKeysWithValues: dataPoints.map {
          (Date(timeIntervalSince1970: $0.timestamp), $0)
        })

        var filled: [CodeOutputCostTrendPoint] = []
        for date in allDates {
          if let existing = dateMap[date] {
            filled.append(existing)
          } else {
            filled.append(CodeOutputCostTrendPoint(
              timestamp: date.timeIntervalSince1970,
              label: dateFormatter.string(from: date),
              additions: 0.0,
              deletions: 0.0,
              billedCost: 0.0
            ))
          }
        }
        dataPoints = filled.sorted { $0.timestamp < $1.timestamp }
      }

      if granularity == .hourly {
        var filled: [CodeOutputCostTrendPoint] = []
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let endDate = Date(timeIntervalSince1970: Double(end) / 1000.0)
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour], from: endDate)
        let alignedEnd = calendar.date(from: endComponents)!

        for hourOffset in 0..<24 {
          let hourDate = calendar.date(byAdding: .hour, value: -hourOffset, to: alignedEnd)!
          let label = dateFormatter.string(from: hourDate)
          if let existing = dataPoints.first(where: { $0.label == label }) {
            filled.append(existing)
          } else {
            filled.append(CodeOutputCostTrendPoint(
              timestamp: hourDate.timeIntervalSince1970,
              label: label,
              additions: 0.0,
              deletions: 0.0,
              billedCost: 0.0
            ))
          }
        }
        dataPoints = filled.reversed()
      }

      return ()
    }

    return dataPoints
  }

  public func getModelProcessingStats(timeRange: TimeRange) -> [ModelProcessingStat] {
    let (start, end) = getTimestamps(for: timeRange)
    var stats: [ModelProcessingStat] = []

    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          COALESCE(provider_id, 'unknown') as provider_id,
          COALESCE(model_id, 'unknown') as model_id,
          COUNT(DISTINCT session_id) as sessionCount,
          SUM(CAST(token_input AS INTEGER)) as inputTokens,
          SUM(CAST(token_output AS INTEGER)) as outputTokens,
          SUM(CAST(token_reasoning AS INTEGER)) as reasoningTokens,
          SUM(CASE WHEN cost > 0 THEN cost ELSE 0 END) as billedCost
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
          AND model_id IS NOT NULL
        GROUP BY provider_id, model_id
        ORDER BY billedCost DESC
      """, arguments: [start, end])

      stats = rows.compactMap { row in
        guard let providerId = row["provider_id"] as? String,
              let modelId = row["model_id"] as? String else { return nil }
        let sessionCount = Int(row["sessionCount"] as? Int64 ?? 0)
        let inputTokens = Int(row["inputTokens"] as? Int64 ?? 0)
        let outputTokens = Int(row["outputTokens"] as? Int64 ?? 0)
        let reasoningTokens = Int(row["reasoningTokens"] as? Int64 ?? 0)
        let billedCost = row["billedCost"] as? Double ?? 0.0
        return ModelProcessingStat(
          providerId: providerId,
          modelId: modelId,
          sessionCount: sessionCount,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          reasoningTokens: reasoningTokens,
          billedCost: billedCost
        )
      }
      return ()
    }

    return stats
  }

  public func getRhythmInsights(timeRange: TimeRange) -> RhythmInsights {
    let (start, end) = getTimestamps(for: timeRange)

    var totalMessages = 0
    var weekendMessages = 0
    var nightMessages = 0
    var peakHour = 0
    var peakHourCount = 0
    var totalSessions = 0
    var weekendSessions = 0
    var nightSessions = 0

    try? dbPool.read { db in
      let hourlyRows = try Row.fetchAll(db, sql: """
        SELECT
          CAST(strftime('%H', created_at / 1000.0, 'unixepoch', 'localtime') AS INTEGER) AS hour_of_day,
          COUNT(*) AS message_count
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY hour_of_day
      """, arguments: [start, end])

      for row in hourlyRows {
        let hour = Int(row["hour_of_day"] as? Int64 ?? 0)
        let count = Int(row["message_count"] as? Int64 ?? 0)
        totalMessages += count
        if hour >= 22 || hour < 6 {
          nightMessages += count
        }
        if count > peakHourCount {
          peakHourCount = count
          peakHour = hour
        }
      }

      if let weekendRow = try Row.fetchOne(db, sql: """
        SELECT
          SUM(CASE WHEN CAST(strftime('%w', created_at / 1000.0, 'unixepoch', 'localtime') AS INTEGER) IN (0, 6) THEN 1 ELSE 0 END) AS weekend_messages
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
      """, arguments: [start, end]) {
        weekendMessages = Int(weekendRow["weekend_messages"] as? Int64 ?? 0)
      }

      if let sessionRow = try Row.fetchOne(db, sql: """
        SELECT
          COUNT(DISTINCT session_id) AS total_sessions,
          COUNT(DISTINCT CASE
            WHEN CAST(strftime('%w', created_at / 1000.0, 'unixepoch', 'localtime') AS INTEGER) IN (0, 6)
            THEN session_id END) AS weekend_sessions,
          COUNT(DISTINCT CASE
            WHEN CAST(strftime('%H', created_at / 1000.0, 'unixepoch', 'localtime') AS INTEGER) >= 22
              OR CAST(strftime('%H', created_at / 1000.0, 'unixepoch', 'localtime') AS INTEGER) < 6
            THEN session_id END) AS night_sessions
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
      """, arguments: [start, end]) {
        totalSessions = Int(sessionRow["total_sessions"] as? Int64 ?? 0)
        weekendSessions = Int(sessionRow["weekend_sessions"] as? Int64 ?? 0)
        nightSessions = Int(sessionRow["night_sessions"] as? Int64 ?? 0)
      }
      return ()
    }

    let nightMessageRatio = totalMessages > 0 ? Double(nightMessages) / Double(totalMessages) : 0
    let weekendMessageRatio = totalMessages > 0 ? Double(weekendMessages) / Double(totalMessages) : 0
    let nightSessionRatio = totalSessions > 0 ? Double(nightSessions) / Double(totalSessions) : 0
    let weekendSessionRatio = totalSessions > 0 ? Double(weekendSessions) / Double(totalSessions) : 0

    return RhythmInsights(
      peakHour: peakHour,
      peakHourMessageCount: peakHourCount,
      nightOwlMessageRatio: nightMessageRatio,
      nightOwlSessionRatio: nightSessionRatio,
      weekendMessageRatio: weekendMessageRatio,
      weekendSessionRatio: weekendSessionRatio
    )
  }

  public func getAnomalyStats(timeRange: TimeRange) -> AnomalyStats {
    let (start, end) = getTimestamps(for: timeRange)

    var messageSeries: [Double] = []
    var sessionSeries: [Double] = []
    var costSeries: [Double] = []
    var netOutputSeries: [Double] = []

    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          strftime('%Y-%m-%d', created_at / 1000.0, 'unixepoch', 'localtime') AS day_key,
          COUNT(*) AS message_count,
          COUNT(DISTINCT session_id) AS session_count,
          SUM(COALESCE(cost, 0)) AS cost_total,
          SUM(COALESCE(summary_total_additions, 0) - COALESCE(summary_total_deletions, 0)) AS net_output
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY day_key
        ORDER BY day_key ASC
      """, arguments: [start, end])

      for row in rows {
        messageSeries.append(Self.numericValue(row: row, key: "message_count"))
        sessionSeries.append(Self.numericValue(row: row, key: "session_count"))
        costSeries.append(Self.numericValue(row: row, key: "cost_total"))
        netOutputSeries.append(Self.numericValue(row: row, key: "net_output"))
      }
      return ()
    }

    return AnomalyStats(
      message: Self.anomalyMetric(from: messageSeries),
      session: Self.anomalyMetric(from: sessionSeries),
      cost: Self.anomalyMetric(from: costSeries),
      netOutput: Self.anomalyMetric(from: netOutputSeries)
    )
  }

  public func getDualAxisData(timeRange: TimeRange, granularity: TimeGranularity) -> [DualAxisDataPoint] {
    let (start, end) = getTimestamps(for: timeRange)

    var dataPoints: [DualAxisDataPoint] = []
    try? dbPool.read { db in
      let (groupByClause, dateFormat): (String, String)
      switch granularity {
      case .hourly:
        groupByClause = "strftime('%Y-%m-%d %H', created_at, 'unixepoch', 'localtime')"
        dateFormat = "yyyy-MM-dd HH"
      case .daily:
        groupByClause = "strftime('%Y-%m-%d', created_at, 'unixepoch', 'localtime')"
        dateFormat = "yyyy-MM-dd"
      case .weekly:
        groupByClause = "strftime('%Y-%W', datetime(created_at, 'unixepoch', 'localtime'))"
        dateFormat = "yyyy-ww"
      case .monthly:
        groupByClause = "strftime('%Y-%m', datetime(created_at, 'unixepoch', 'localtime'))"
        dateFormat = "yyyy-MM"
      }

      let rows = try Row.fetchAll(db, sql: """
        SELECT
          \(groupByClause) as timeGroup,
          COUNT(*) as messageCount,
          COUNT(DISTINCT session_id) as sessionCount
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY timeGroup
        ORDER BY timeGroup ASC
      """, arguments: [start, end])

      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = dateFormat
      dateFormatter.timeZone = TimeZone.current

      dataPoints = rows.compactMap { row -> DualAxisDataPoint? in
        guard let timeGroupStr = row["timeGroup"] as? String,
              let date = dateFormatter.date(from: timeGroupStr) else { return nil }

        let messages = Double(row["messageCount"] as? Int64 ?? 0)
        let sessions = Double(row["sessionCount"] as? Int64 ?? 0)
        return DualAxisDataPoint(
          timestamp: date.timeIntervalSince1970,
          label: timeGroupStr,
          messages: messages,
          sessions: sessions
        )
      }

      if granularity == .hourly {
        let existingByLabel = Dictionary(uniqueKeysWithValues: dataPoints.map { ($0.label, $0) })
        var filledDataPoints: [DualAxisDataPoint] = []

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        if case .today = timeRange {
          // Stable 00..23 series for current local day.
          let startDate = Date(timeIntervalSince1970: Double(start) / 1000.0)
          let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
          let alignedStart = calendar.date(from: startComponents)!

          for hourOffset in 0..<24 {
            let hourDate = calendar.date(byAdding: .hour, value: hourOffset, to: alignedStart)!
            let label = dateFormatter.string(from: hourDate)

            if let existing = existingByLabel[label] {
              filledDataPoints.append(existing)
            } else {
              filledDataPoints.append(DualAxisDataPoint(
                timestamp: hourDate.timeIntervalSince1970,
                label: label,
                messages: 0.0,
                sessions: 0.0
              ))
            }
          }
          dataPoints = filledDataPoints
        } else {
          // Rolling 24h window anchored to the end hour boundary.
          let endDate = Date(timeIntervalSince1970: Double(end) / 1000.0)
          let endComponents = calendar.dateComponents([.year, .month, .day, .hour], from: endDate)
          let alignedEnd = calendar.date(from: endComponents)!

          for hourOffset in 0..<24 {
            let hourDate = calendar.date(byAdding: .hour, value: -hourOffset, to: alignedEnd)!
            let label = dateFormatter.string(from: hourDate)

            if let existing = existingByLabel[label] {
              filledDataPoints.append(existing)
            } else {
              filledDataPoints.append(DualAxisDataPoint(
                timestamp: hourDate.timeIntervalSince1970,
                label: label,
                messages: 0.0,
                sessions: 0.0
              ))
            }
          }
          dataPoints = filledDataPoints.reversed()
        }
      }

      return ()
    }
    return dataPoints
  }

  // MARK: - Project Stats

  public func getProjectStats(timeRange: TimeRange) -> [ProjectStats] {
    let (start, end) = getTimestamps(for: timeRange)

    var stats: [ProjectStats] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          project_root,
          COUNT(DISTINCT session_id) as sessionCount,
          COUNT(*) as messageCount,
          SUM(CAST(token_input AS INTEGER)) as inputTokens,
          SUM(CAST(token_output AS INTEGER)) as outputTokens,
          SUM(cache_read) as cacheRead,
          SUM(cache_write) as cacheWrite,
          SUM(COALESCE(summary_total_additions, 0) - COALESCE(summary_total_deletions, 0)) as netCodeLines,
          SUM(COALESCE(summary_file_count, 0)) as fileCount,
          SUM(\(tokenSumExpression)) as tokens,
          SUM(cost) as cost,
          COUNT(DISTINCT strftime('%Y-%m-%d', created_at, 'unixepoch', 'localtime')) as activeDays
        FROM messages
        WHERE created_at >= ? AND created_at <= ?
        GROUP BY project_root
        ORDER BY cost DESC
      """, arguments: [start, end])

      stats = rows.compactMap { row -> ProjectStats? in
        guard let projectRoot = row["project_root"] as? String else { return nil }
        return ProjectStats(
          projectRoot: projectRoot.isEmpty ? "No Project" : projectRoot,
          sessionCount: Int(row["sessionCount"] as? Int64 ?? 0),
          messageCount: Int(row["messageCount"] as? Int64 ?? 0),
          inputTokens: Int(row["inputTokens"] as? Int64 ?? 0),
          outputTokens: Int(row["outputTokens"] as? Int64 ?? 0),
          cacheRead: Int(row["cacheRead"] as? Int64 ?? 0),
          cacheWrite: Int(row["cacheWrite"] as? Int64 ?? 0),
          netCodeLines: Int(row["netCodeLines"] as? Int64 ?? 0),
          fileCount: Int(row["fileCount"] as? Int64 ?? 0),
          tokens: Int(row["tokens"] as? Int64 ?? 0),
          cost: row["cost"] as? Double ?? 0.0,
          activeDays: Int(row["activeDays"] as? Int64 ?? 0)
        )
      }
      return ()
    }
        return stats
    }

    public func getProjectStatsFromMonthly() -> [ProjectStats] {
        var stats: [ProjectStats] = []
        
        do {
            let rows = try dbPool.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT
                        project_id,
                        SUM(session_count) as session_count,
                        SUM(message_count) as message_count,
                        SUM(input_tokens) as input_tokens,
                        SUM(output_tokens) as output_tokens,
                        SUM(reasoning_tokens) as reasoning_tokens,
                        SUM(cache_read) as cache_read,
                        SUM(cache_write) as cache_write,
                        SUM(cost) as total_cost,
                        COUNT(DISTINCT time_bucket_ms) as active_days,
                        MAX(last_created_at_ms) as last_active_ms
                    FROM monthly_stats
                    WHERE project_id IS NOT NULL AND project_id != ''
                    GROUP BY project_id
                    ORDER BY last_active_ms DESC
                """)
            }
            
            stats = rows.compactMap { row -> ProjectStats? in
                guard let projectRoot = row["project_id"] as? String else { return nil }
                
                let lastActiveMs = row["last_active_ms"] as? Int64
                let lastActiveAt: Date? = lastActiveMs != nil ? Date(timeIntervalSince1970: Double(lastActiveMs!) / 1000.0) : nil
                
                return ProjectStats(
                    projectRoot: projectRoot,
                    sessionCount: Int(row["session_count"] as? Int64 ?? 0),
                    messageCount: Int(row["message_count"] as? Int64 ?? 0),
                    inputTokens: Int(row["input_tokens"] as? Int64 ?? 0),
                    outputTokens: Int(row["output_tokens"] as? Int64 ?? 0),
                    cacheRead: Int(row["cache_read"] as? Int64 ?? 0),
                    cacheWrite: Int(row["cache_write"] as? Int64 ?? 0),
                    netCodeLines: 0,
                    fileCount: 0,
                    tokens: Int(row["input_tokens"] as? Int64 ?? 0) + Int(row["output_tokens"] as? Int64 ?? 0),
                    cost: row["total_cost"] as? Double ?? 0.0,
                    activeDays: Int(row["active_days"] as? Int64 ?? 0),
                    lastActiveAt: lastActiveAt
                )
            }
        } catch {
            logger.error("Error fetching project stats from monthly: \(error)")
        }
        
        return stats
    }

    // MARK: - Project Activity Stats

    public struct ProjectActivityStats {
        public let projectRoot: String
        public let firstActiveAt: Date?
        public let lastActiveAt: Date?
        public let activeDays: Int
        public let netCodeLines: Int
        public let totalDurationMs: Int64

        public init(projectRoot: String, firstActiveAt: Date?, lastActiveAt: Date?, activeDays: Int, netCodeLines: Int, totalDurationMs: Int64) {
            self.projectRoot = projectRoot
            self.firstActiveAt = firstActiveAt
            self.lastActiveAt = lastActiveAt
            self.activeDays = activeDays
            self.netCodeLines = netCodeLines
            self.totalDurationMs = totalDurationMs
        }
    }

    public func getProjectActivityStats(projectRoot: String) -> ProjectActivityStats? {
        var stats: ProjectActivityStats?

        do {
            let row = try dbPool.read { db in
                try Row.fetchOne(db, sql: """
                    SELECT
                        MIN(time_bucket_ms) as first_active_ms,
                        MAX(last_created_at_ms) as last_active_ms,
                        COUNT(DISTINCT time_bucket_ms) as active_days,
                        SUM(net_code_lines) as net_code_lines,
                        SUM(duration_ms) as total_duration_ms
                    FROM daily_stats
                    WHERE project_id = ?
                    AND project_id IS NOT NULL AND project_id != ''
                """, arguments: [projectRoot])
            }

            guard let r = row else { return nil }

            let firstActiveMs = r["first_active_ms"] as? Int64
            let lastActiveMs = r["last_active_ms"] as? Int64

            stats = ProjectActivityStats(
                projectRoot: projectRoot,
                firstActiveAt: firstActiveMs != nil ? Date(timeIntervalSince1970: Double(firstActiveMs!) / 1000.0) : nil,
                lastActiveAt: lastActiveMs != nil ? Date(timeIntervalSince1970: Double(lastActiveMs!) / 1000.0) : nil,
                activeDays: Int(r["active_days"] as? Int64 ?? 0),
                netCodeLines: Int(r["net_code_lines"] as? Int64 ?? 0),
                totalDurationMs: r["total_duration_ms"] as? Int64 ?? 0
            )
        } catch {
            logger.error("Error fetching project activity stats: \(error)")
        }

        return stats
    }

    // MARK: - Top 3 Daily Stats

    public struct DailyTop3Stat {
        public let date: Date
        public let netCodeLines: Int
        public let inputTokens: Int
        public let messageCount: Int
        public let totalDurationMs: Int64
        public let cost: Double

        public init(date: Date, netCodeLines: Int, inputTokens: Int, messageCount: Int, totalDurationMs: Int64, cost: Double) {
            self.date = date
            self.netCodeLines = netCodeLines
            self.inputTokens = inputTokens
            self.messageCount = messageCount
            self.totalDurationMs = totalDurationMs
            self.cost = cost
        }
    }

    public func getDailyTop3Stats(projectRoot: String, orderBy: String) -> [DailyTop3Stat] {
        var stats: [DailyTop3Stat] = []

        let validColumns = ["net_code_lines", "input_tokens", "message_count", "duration_ms", "cost"]
        guard validColumns.contains(orderBy) else {
            logger.error("Invalid orderBy column: \(orderBy)")
            return stats
        }

        do {
            let rows = try dbPool.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT
                        time_bucket_ms,
                        net_code_lines,
                        input_tokens,
                        message_count,
                        duration_ms,
                        cost
                    FROM daily_stats
                    WHERE project_id = ?
                    AND project_id IS NOT NULL AND project_id != ''
                    ORDER BY \(orderBy) DESC
                    LIMIT 3
                """, arguments: [projectRoot])
            }

            stats = rows.compactMap { row -> DailyTop3Stat? in
                guard let timeBucketMs = row["time_bucket_ms"] as? Int64 else { return nil }

                return DailyTop3Stat(
                    date: Date(timeIntervalSince1970: Double(timeBucketMs) / 1000.0),
                    netCodeLines: Int(row["net_code_lines"] as? Int64 ?? 0),
                    inputTokens: Int(row["input_tokens"] as? Int64 ?? 0),
                    messageCount: Int(row["message_count"] as? Int64 ?? 0),
                    totalDurationMs: row["duration_ms"] as? Int64 ?? 0,
                    cost: row["cost"] as? Double ?? 0.0
                )
            }
        } catch {
            logger.error("Error fetching daily top3 stats: \(error)")
        }

        return stats
    }

    // MARK: - Project Consumption Stats

    public struct ProjectConsumptionStats {
        public let cost: Double
        public let inputTokens: Int
        public let outputTokens: Int
        public let reasoningTokens: Int
        public let netCodeLines: Int

        public init(cost: Double, inputTokens: Int, outputTokens: Int, reasoningTokens: Int, netCodeLines: Int) {
            self.cost = cost
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.reasoningTokens = reasoningTokens
            self.netCodeLines = netCodeLines
        }
    }

    public func getProjectConsumptionStats(projectRoot: String) -> ProjectConsumptionStats? {
        var stats: ProjectConsumptionStats?

        do {
            let row = try dbPool.read { db in
                try Row.fetchOne(db, sql: """
                    SELECT
                        SUM(cost) as total_cost,
                        SUM(input_tokens) as total_input_tokens,
                        SUM(output_tokens) as total_output_tokens,
                        SUM(reasoning_tokens) as total_reasoning_tokens,
                        SUM(net_code_lines) as total_net_code_lines
                    FROM monthly_stats
                    WHERE project_id = ?
                    AND project_id IS NOT NULL AND project_id != ''
                """, arguments: [projectRoot])
            }

            guard let r = row else { return nil }

            let totalCost = r["total_cost"] as? Double ?? 0.0
            let totalInputTokens = Int(r["total_input_tokens"] as? Int64 ?? 0)
            let totalOutputTokens = Int(r["total_output_tokens"] as? Int64 ?? 0)
            let totalReasoningTokens = Int(r["total_reasoning_tokens"] as? Int64 ?? 0)

            guard totalCost > 0 || totalInputTokens > 0 || totalOutputTokens > 0 || totalReasoningTokens > 0 else {
                return nil
            }

            stats = ProjectConsumptionStats(
                cost: totalCost,
                inputTokens: totalInputTokens,
                outputTokens: totalOutputTokens,
                reasoningTokens: totalReasoningTokens,
                netCodeLines: Int(r["total_net_code_lines"] as? Int64 ?? 0)
            )
        } catch {
            logger.error("Error fetching project consumption stats: \(error)")
        }

        return stats
    }

    // MARK: - Project Model and Agent Stats

    public struct ProjectModelAgentStats {
        public struct ModelContribution {
            public let modelId: String
            public let providerId: String
            public let inputTokens: Int
            public let percentage: Double

            public init(modelId: String, providerId: String, inputTokens: Int, percentage: Double) {
                self.modelId = modelId
                self.providerId = providerId
                self.inputTokens = inputTokens
                self.percentage = percentage
            }
        }

        public struct AgentUsage {
            public let agent: String
            public let messageCount: Int
            public let percentage: Double

            public init(agent: String, messageCount: Int, percentage: Double) {
                self.agent = agent
                self.messageCount = messageCount
                self.percentage = percentage
            }
        }

        public let modelContributions: [ModelContribution]
        public let agentUsages: [AgentUsage]
        public let automationLevel: Double

        public init(modelContributions: [ModelContribution], agentUsages: [AgentUsage], automationLevel: Double) {
            self.modelContributions = modelContributions
            self.agentUsages = agentUsages
            self.automationLevel = automationLevel
        }
    }

    public func getProjectModelAgentStats(projectRoot: String) -> ProjectModelAgentStats? {
        var stats: ProjectModelAgentStats?

        do {
            let modelRows = try dbPool.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT
                        model_id,
                        provider_id,
                        SUM(input_tokens) as total_input_tokens
                    FROM monthly_stats
                    WHERE project_id = ?
                    AND project_id IS NOT NULL AND project_id != ''
                    GROUP BY model_id, provider_id
                    ORDER BY total_input_tokens DESC
                """, arguments: [projectRoot])
            }

            var modelContributions: [ProjectModelAgentStats.ModelContribution] = []
            let totalInputTokens = modelRows.reduce(0) { $0 + ($1["total_input_tokens"] as? Int64 ?? 0) }

            if totalInputTokens > 0 {
                for (index, row) in modelRows.enumerated() {
                    if index >= 11 {
                        let otherTokens = modelRows.dropFirst(11).reduce(0) { $0 + ($1["total_input_tokens"] as? Int64 ?? 0) }
                        if otherTokens > 0 {
                            let otherPercentage = Double(otherTokens) / Double(totalInputTokens) * 100
                            modelContributions.append(ProjectModelAgentStats.ModelContribution(
                                modelId: "other",
                                providerId: "",
                                inputTokens: Int(otherTokens),
                                percentage: otherPercentage
                            ))
                        }
                        break
                    }

                    let modelId = row["model_id"] as? String ?? ""
                    let providerId = row["provider_id"] as? String ?? ""
                    let inputTokens = Int(row["total_input_tokens"] as? Int64 ?? 0)
                    let percentage = Double(inputTokens) / Double(totalInputTokens) * 100

                    modelContributions.append(ProjectModelAgentStats.ModelContribution(
                        modelId: modelId,
                        providerId: providerId,
                        inputTokens: inputTokens,
                        percentage: percentage
                    ))
                }
            }

            let agentRows = try dbPool.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT
                        agent,
                        SUM(message_count) as total_messages
                    FROM monthly_stats
                    WHERE project_id = ?
                    AND project_id IS NOT NULL AND project_id != ''
                    AND agent IS NOT NULL AND agent != ''
                    GROUP BY agent
                    ORDER BY total_messages DESC
                """, arguments: [projectRoot])
            }

            var agentUsages: [ProjectModelAgentStats.AgentUsage] = []
            let totalAgentMessages = agentRows.reduce(0) { $0 + ($1["total_messages"] as? Int64 ?? 0) }

            if totalAgentMessages > 0 {
                for row in agentRows {
                    let agent = row["agent"] as? String ?? ""
                    let messageCount = Int(row["total_messages"] as? Int64 ?? 0)
                    let percentage = Double(messageCount) / Double(totalAgentMessages) * 100

                    agentUsages.append(ProjectModelAgentStats.AgentUsage(
                        agent: agent,
                        messageCount: messageCount,
                        percentage: percentage
                    ))
                }
            }

            let automationRow = try dbPool.read { db in
                try Row.fetchOne(db, sql: """
                    SELECT
                        COALESCE(SUM(CASE WHEN role = 'assistant' THEN message_count ELSE 0 END), 0) as assistant_count,
                        COALESCE(SUM(CASE WHEN role = 'user' THEN message_count ELSE 0 END), 0) as user_count
                    FROM monthly_stats
                    WHERE project_id = ?
                    AND project_id IS NOT NULL AND project_id != ''
                    AND role IN ('assistant', 'user')
                """, arguments: [projectRoot])
            }

            var automationLevel: Double = 0.0
            if let r = automationRow {
                let assistantCount = r["assistant_count"] as? Int64 ?? 0
                let userCount = r["user_count"] as? Int64 ?? 0
                automationLevel = Self.calculateAutomationLevel(
                    assistantCount: assistantCount,
                    userCount: userCount
                )
            }

            stats = ProjectModelAgentStats(
                modelContributions: modelContributions,
                agentUsages: agentUsages,
                automationLevel: automationLevel
            )
        } catch {
            logger.error("Error fetching project model and agent stats: \(error)")
        }

        return stats
    }

  // MARK: - Extended Metrics Queries

  public func getSessionDepthDistribution(timeRange: TimeRange) -> (shallow: Int, medium: Int, deep: Int) {
    let (start, end) = getTimestamps(for: timeRange)

    var shallow = 0, medium = 0, deep = 0
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          CASE
            WHEN COALESCE(user_msg_count, 0) <= 3 THEN 'shallow'
            WHEN COALESCE(user_msg_count, 0) BETWEEN 4 AND 10 THEN 'medium'
            ELSE 'deep'
          END as depth,
          COUNT(*) as count
        FROM sessions
        WHERE last_message_at >= ? AND last_message_at <= ?
        GROUP BY depth
      """, arguments: [start, end])

      for row in rows {
        if let depth = row["depth"] as? String,
           let count = row["count"] as? Int64 {
          switch depth {
          case "shallow": shallow = Int(count)
          case "medium": medium = Int(count)
          case "deep": deep = Int(count)
          default: break
          }
        }
      }
      return ()
    }
    return (shallow: shallow, medium: medium, deep: deep)
  }

  public func getTopProjects(timeRange: TimeRange, limit: Int = 5) -> [ProjectStats] {
    let (start, end) = getTimestamps(for: timeRange)

    var projects: [ProjectStats] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          COALESCE(NULLIF(s.project_name, ''), '未命名项目') as projectRoot,
          COUNT(DISTINCT m.session_id) as sessionCount,
          SUM(m.messageCount) as messageCount,
          SUM(m.inputTokens) as inputTokens,
          SUM(m.outputTokens) as outputTokens,
          SUM(m.reasoningTokens) as reasoningTokens,
          SUM(m.cacheRead) as cacheRead,
          SUM(m.cacheWrite) as cacheWrite,
          SUM(s.total_additions - s.total_deletions) as netCodeLines,
          SUM(s.total_file_count) as fileCount,
          SUM(m.inputTokens + m.outputTokens + m.reasoningTokens) as tokens,
          SUM(s.total_cost) as cost,
          COUNT(DISTINCT date(m.firstMessageAt, 'unixepoch', 'localtime')) as activeDays
        FROM (
          SELECT 
            session_id,
            MIN(created_at) as firstMessageAt,
            COUNT(*) as messageCount,
            SUM(CAST(COALESCE(token_input, '0') AS INTEGER)) as inputTokens,
            SUM(CAST(COALESCE(token_output, '0') AS INTEGER)) as outputTokens,
            SUM(CAST(COALESCE(token_reasoning, '0') AS INTEGER)) as reasoningTokens,
            SUM(COALESCE(cache_read, 0)) as cacheRead,
            SUM(COALESCE(cache_write, 0)) as cacheWrite
          FROM messages
          WHERE role = 'assistant'
            AND created_at >= ?
            AND created_at <= ?
          GROUP BY session_id
        ) m
        INNER JOIN sessions s ON m.session_id = s.session_id
        GROUP BY projectRoot
        ORDER BY inputTokens DESC
        LIMIT ?
      """, arguments: [start, end, limit])

      projects = rows.map { row in
        ProjectStats(
          projectRoot: row["projectRoot"] as? String ?? "",
          sessionCount: Int(row["sessionCount"] as? Int64 ?? 0),
          messageCount: Int(row["messageCount"] as? Int64 ?? 0),
          inputTokens: Int(row["inputTokens"] as? Int64 ?? 0),
          outputTokens: Int(row["outputTokens"] as? Int64 ?? 0),
          cacheRead: Int(row["cacheRead"] as? Int64 ?? 0),
          cacheWrite: Int(row["cacheWrite"] as? Int64 ?? 0),
          netCodeLines: Int(row["netCodeLines"] as? Int64 ?? 0),
          fileCount: Int(row["fileCount"] as? Int64 ?? 0),
          tokens: Int(row["tokens"] as? Int64 ?? 0),
          cost: row["cost"] as? Double ?? 0.0,
          activeDays: Int(row["activeDays"] as? Int64 ?? 0)
        )
      }
      return ()
    }
    return projects
  }

  public func getTopProjectsOptimized(timeRange: TimeRange, limit: Int = 5) -> [ProjectStats] {
    let (start, end) = getTimestamps(for: timeRange)

    let tableName: String
    switch timeRange {
    case .today:
      tableName = "hourly_stats"

    default:
      tableName = "daily_stats"
    }

    var projects: [ProjectStats] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          COALESCE(NULLIF(project_id, ''), '未命名项目') as projectRoot,
          COALESCE(SUM(session(session_count), 0) as sessionCount,
          COALESCE(SUM(message_count), 0) as messageCount,
          COALESCE(SUM(input_tokens), 0) as inputTokens,
          COALESCE(SUM(output_tokens), 0) as outputTokens,
          COALESCE(SUM(reasoning_tokens), 0) as reasoningTokens,
          COALESCE(SUM(cache_read), 0) as cacheRead,
          COALESCE(SUM(cache_write), 0) as cacheWrite,
          COALESCE(SUM(net_code_lines), 0) as netCodeLines,
          COALESCE(SUM(file_count), 0) as fileCount,
          COALESCE(SUM(input_tokens + output_tokens + reasoning_tokens), 0) as tokens,
          COALESCE(SUM(cost), 0.0) as cost,
          COUNT(DISTINCT time_bucket_ms) as activeDays
        FROM \(tableName)
        WHERE time_bucket_ms >= ? AND time_bucket_ms < ?
        GROUP BY project_id
        ORDER BY inputTokens DESC
        LIMIT ?
      """, arguments: [start, end, limit])

      projects = rows.map { row in
        ProjectStats(
          projectRoot: row["projectRoot"] as? String ?? "",
          sessionCount: Int(row["sessionCount"] as? Int64 ?? 0),
          messageCount: Int(row["messageCount"] as? Int64 ?? 0),
          inputTokens: Int(row["inputTokens"] as? Int64 ?? 0),
          outputTokens: Int(row["outputTokens"] as? Int64 ?? 0),
          cacheRead: Int(row["cacheRead"] as? Int64 ?? 0),
          cacheWrite: Int(row["cacheWrite"] as? Int64 ?? 0),
          netCodeLines: Int(row["netCodeLines"] as? Int64 ?? 0),
          fileCount: Int(row["fileCount"] as? Int64 ?? 0),
          tokens: Int(row["tokens"] as? Int64 ?? 0),
          cost: row["cost"] as? Double ?? 0.0,
          activeDays: Int(row["activeDays"] as? Int64 ?? 0)
        )
      }
      return ()
    }
    return projects
  }

  public func getTopModels(timeRange: TimeRange, limit: Int = 5) -> [ModelStats] {
    let (start, end) = getTimestamps(for: timeRange)

    var models: [ModelStats] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          provider_id,
          model_id,
          COUNT(DISTINCT session_id) as sessionCount,
          COUNT(*) as messageCount,
          SUM(\(tokenSumExpression)) as tokens,
          SUM(CAST(token_input AS INTEGER)) as inputTokens,
          SUM(CAST(token_output AS INTEGER)) as outputTokens,
          SUM(CAST(token_reasoning AS INTEGER)) as reasoningTokens,
          SUM(cost) as cost,
          AVG(\(tokenSumExpression)) as avgTokensPerMessage,
          AVG(cost) as avgCostPerMessage
        FROM messages
        WHERE created_at >= ? AND created_at <= ? AND model_id IS NOT NULL
        GROUP BY provider_id, model_id
        ORDER BY inputTokens DESC
        LIMIT ?
      """, arguments: [start, end, limit])

      models = rows.map { row in
        ModelStats(
          providerId: row["provider_id"] as? String ?? "",
          modelId: row["model_id"] as? String ?? "",
          sessionCount: Int(row["sessionCount"] as? Int64 ?? 0),
          messageCount: Int(row["messageCount"] as? Int64 ?? 0),
          tokens: Int(row["tokens"] as? Int64 ?? 0),
          inputTokens: Int(row["inputTokens"] as? Int64 ?? 0),
          outputTokens: Int(row["outputTokens"] as? Int64 ?? 0),
          reasoningTokens: Int(row["reasoningTokens"] as? Int64 ?? 0),
          cost: row["cost"] as? Double ?? 0.0,
          avgTokensPerMessage: row["avgTokensPerMessage"] as? Double ?? 0.0,
          avgCostPerMessage: row["avgCostPerMessage"] as? Double ?? 0.0
        )
      }
      return ()
    }
    return models
  }

  /// 使用聚合表查询热门模型（优化版本）
  public func getTopModelsOptimized(timeRange: TimeRange, limit: Int = 5) -> [ModelStats] {
    let (start, end) = getTimestamps(for: timeRange)

    // 根据时间范围选择聚合表：today 使用 hourly_stats，其他使用 daily_stats
    let tableName: String
    switch timeRange {
    case .today:
      tableName = "hourly_stats"
    default:
      tableName = "daily_stats"
    }

    var models: [ModelStats] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          provider_id,
          model_id,
          COALESCE(SUM(session_count), 0) as sessionCount,
          COALESCE(SUM(message_count), 0) as messageCount,
          COALESCE(SUM(input_tokens + output_tokens + reasoning_tokens), 0) as tokens,
          COALESCE(SUM(input_tokens), 0) as inputTokens,
          COALESCE(SUM(output_tokens), 0) as outputTokens,
          COALESCE(SUM(reasoning_tokens), 0) as reasoningTokens,
          COALESCE(SUM(cost), 0.0) as cost,
          CASE WHEN COALESCE(SUM(message_count), 0) > 0
            THEN CAST(COALESCE(SUM(input_tokens + output_tokens + reasoning_tokens), 0) AS FLOAT) / COALESCE(SUM(message_count), 1)
            ELSE 0.0
          END as avgTokensPerMessage,
          CASE WHEN COALESCE(SUM(message_count), 0) > 0
            THEN COALESCE(SUM(cost), 0.0) / COALESCE(SUM(message_count), 1)
            ELSE 0.0
          END as avgCostPerMessage
        FROM \(tableName)
        WHERE time_bucket_ms >= ? AND time_bucket_ms < ?
        GROUP BY provider_id, model_id
        ORDER BY inputTokens DESC
        LIMIT ?
      """, arguments: [start, end, limit])

      models = rows.map { row in
        ModelStats(
          providerId: row["provider_id"] as? String ?? "",
          modelId: row["model_id"] as? String ?? "",
          sessionCount: Int(row["sessionCount"] as? Int64 ?? 0),
          messageCount: Int(row["messageCount"] as? Int64 ?? 0),
          tokens: Int(row["tokens"] as? Int64 ?? 0),
          inputTokens: Int(row["inputTokens"] as? Int64 ?? 0),
          outputTokens: Int(row["outputTokens"] as? Int64 ?? 0),
          reasoningTokens: Int(row["reasoningTokens"] as? Int64 ?? 0),
          cost: row["cost"] as? Double ?? 0.0,
          avgTokensPerMessage: row["avgTokensPerMessage"] as? Double ?? 0.0,
          avgCostPerMessage: row["avgCostPerMessage"] as? Double ?? 0.0
        )
      }
      return ()
    }
    return models
  }

  // MARK: - Daily Stats Queries (Real-time calculation from messages table)

  /// 查询项目日统计数据（实时从 messages 表计算）
  public func getProjectDailyStats(projectName: String, days: Int) -> [ProjectDailyStat] {
    let calendar = Calendar.current
    let endDate = calendar.startOfDay(for: Date())
    guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) else {
      return []
    }

    var stats: [ProjectDailyStat] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          date(m.created_at, 'unixepoch', 'localtime') as date,
          COUNT(DISTINCT m.session_id) as sessionCount,
          COUNT(*) as messageCount,
          SUM(CAST(COALESCE(m.token_input, '0') AS INTEGER)) as inputTokens,
          SUM(CAST(COALESCE(m.token_output, '0') AS INTEGER)) as outputTokens,
          SUM(CAST(COALESCE(m.token_reasoning, '0') AS INTEGER)) as reasoningTokens,
          SUM(COALESCE(m.cost, 0)) as totalCost,
          SUM(CASE 
            WHEN m.completed_at IS NOT NULL AND m.completed_at > m.created_at 
            THEN m.completed_at - m.created_at
            ELSE 0 
          END) as totalDuration,
          SUM(COALESCE(s.total_additions, 0)) as totalAdditions,
          SUM(COALESCE(s.total_deletions, 0)) as totalDeletions,
          SUM(COALESCE(s.total_additions, 0) - COALESCE(s.total_deletions, 0)) as netCodeLines,
          SUM(COALESCE(s.total_file_count, 0)) as fileCount
        FROM messages m
        LEFT JOIN sessions s ON m.session_id = s.session_id
        WHERE m.role = 'assistant'
          AND m.created_at >= ?
          AND m.created_at < ?
          AND COALESCE(NULLIF(s.project_name, ''), NULLIF(m.project_root, ''), '未命名项目') = ?
        GROUP BY date(m.created_at, 'unixepoch', 'localtime')
        ORDER BY date ASC
      """, arguments: [Int64(startDate.timeIntervalSince1970), Int64(endDate.timeIntervalSince1970) + 86400, projectName])

      stats = rows.compactMap { row -> ProjectDailyStat? in
        let dateStr = row["date"] as? String ?? ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        guard let date = dateFormatter.date(from: dateStr) else { return nil }

        return ProjectDailyStat(
          date: date,
          sessionCount: Int(row["sessionCount"] as? Int64 ?? 0),
          messageCount: Int(row["messageCount"] as? Int64 ?? 0),
          inputTokens: Int(row["inputTokens"] as? Int64 ?? 0),
          outputTokens: Int(row["outputTokens"] as? Int64 ?? 0),
          reasoningTokens: Int(row["reasoningTokens"] as? Int64 ?? 0),
          totalCost: row["totalCost"] as? Double ?? 0.0,
          totalDuration: row["totalDuration"] as? Double ?? 0.0,
          totalAdditions: Int(row["totalAdditions"] as? Int64 ?? 0),
          totalDeletions: Int(row["totalDeletions"] as? Int64 ?? 0),
          netCodeLines: Int(row["netCodeLines"] as? Int64 ?? 0),
          fileCount: Int(row["fileCount"] as? Int64 ?? 0)
        )
      }
      return ()
    }
    return stats
  }

  /// 查询模型日统计数据（实时从 messages 表计算）
  public func getModelDailyStats(providerId: String, modelId: String, days: Int) -> [ModelDailyStat] {
    let calendar = Calendar.current
    let endDate = calendar.startOfDay(for: Date())
    guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) else {
      return []
    }

    var stats: [ModelDailyStat] = []
    try? dbPool.read { db in
      let rows = try Row.fetchAll(db, sql: """
        SELECT
          date(created_at, 'unixepoch', 'localtime') as date,
          COUNT(DISTINCT session_id) as sessionCount,
          COUNT(*) as messageCount,
          SUM(CAST(COALESCE(token_input, '0') AS INTEGER)) as inputTokens,
          SUM(CAST(COALESCE(token_output, '0') AS INTEGER)) as outputTokens,
          SUM(CAST(COALESCE(token_reasoning, '0') AS INTEGER)) as reasoningTokens,
          SUM(COALESCE(cost, 0)) as totalCost,
          SUM(CASE 
            WHEN completed_at IS NOT NULL AND completed_at > created_at 
            THEN completed_at - created_at
            ELSE 0 
          END) as totalDuration,
          SUM(COALESCE(cache_read, 0)) as cacheRead,
          SUM(COALESCE(cache_write, 0)) as cacheWrite
        FROM messages
        WHERE role = 'assistant'
          AND created_at >= ?
          AND created_at < ?
          AND COALESCE(provider_id, 'unknown') = ?
          AND COALESCE(model_id, 'unknown') = ?
        GROUP BY date(created_at, 'unixepoch', 'localtime')
        ORDER BY date ASC
      """, arguments: [Int64(startDate.timeIntervalSince1970), Int64(endDate.timeIntervalSince1970) + 86400, providerId, modelId])

      stats = rows.compactMap { row -> ModelDailyStat? in
        let dateStr = row["date"] as? String ?? ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        guard let date = dateFormatter.date(from: dateStr) else { return nil }

        return ModelDailyStat(
          date: date,
          sessionCount: Int(row["sessionCount"] as? Int64 ?? 0),
          messageCount: Int(row["messageCount"] as? Int64 ?? 0),
          inputTokens: Int(row["inputTokens"] as? Int64 ?? 0),
          outputTokens: Int(row["outputTokens"] as? Int64 ?? 0),
          reasoningTokens: Int(row["reasoningTokens"] as? Int64 ?? 0),
          totalCost: row["totalCost"] as? Double ?? 0.0,
          totalDuration: row["totalDuration"] as? Double ?? 0.0,
          cacheRead: Int(row["cacheRead"] as? Int64 ?? 0),
          cacheWrite: Int(row["cacheWrite"] as? Int64 ?? 0)
        )
      }
      return ()
    }
    return stats
  }

  // MARK: - Code Output Stats

  public func getCodeOutputStats(timeRange: TimeRange) -> (totalAdditions: Int, totalDeletions: Int, fileCount: Int) {
    let (start, end) = getTimestamps(for: timeRange)

    var totalAdditions = 0, totalDeletions = 0, fileCount = 0

    try? dbPool.read { db in
      // Optimized: Use pre-aggregated sessions table instead of messages
      if let row = try Row.fetchOne(db, sql: """
        SELECT
          SUM(total_additions) as totalAdditions,
          SUM(total_deletions) as totalDeletions,
          SUM(total_file_count) as fileCount
        FROM sessions
        WHERE last_message_at >= ? AND last_message_at <= ?
      """, arguments: [start, end]) {
        totalAdditions = Int(row["totalAdditions"] as? Int64 ?? 0)
        totalDeletions = Int(row["totalDeletions"] as? Int64 ?? 0)
        fileCount = Int(row["fileCount"] as? Int64 ?? 0)
      }
      return ()
    }

    return (totalAdditions: totalAdditions, totalDeletions: totalDeletions, fileCount: fileCount)
  }

    public func getMinTimeBucketMs(from tableName: String) -> Int64? {
        var minTime: Int64? = nil
        
        do {
            try dbPool.read { db in
                let sql = "SELECT MIN(time_bucket_ms) as minTime FROM \(tableName)"
                if let row = try Row.fetchOne(db, sql: sql) {
                    minTime = row["minTime"] as? Int64
                }
            }
        } catch {
            logger.error("Error getting min time bucket from \(tableName): \(error)")
        }
        
        return minTime
    }

    // MARK: - Insights Data

    public func getDailyActivityHeatmap(metric: InsightMetric, lastNDays: Int = 365) -> [DailyHeatPoint] {
        let context = makeDailyHeatmapQueryContext(lastNDays: lastNDays)
        let maps = fetchDailyHeatValueMaps(context: context)
        return buildDailyHeatPoints(
            valuesByDayStartMs: maps[metric] ?? [:],
            startDate: context.startDate,
            dayCount: context.safeDays,
            calendar: context.calendar
        )
    }

    public func getDailyActivityHeatmapBundle(lastNDays: Int = 365) -> [InsightMetric: [DailyHeatPoint]] {
        let context = makeDailyHeatmapQueryContext(lastNDays: lastNDays)
        let maps = fetchDailyHeatValueMaps(context: context)

        var result: [InsightMetric: [DailyHeatPoint]] = [:]
        for metric in InsightMetric.allCases {
            result[metric] = buildDailyHeatPoints(
                valuesByDayStartMs: maps[metric] ?? [:],
                startDate: context.startDate,
                dayCount: context.safeDays,
                calendar: context.calendar
            )
        }
        return result
    }

    public func getWeekdayWeekendIntensity(metric: InsightMetric, filter: DayTypeFilter) -> WeekdayWeekendIntensity {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        var weekdayTotal = 0.0
        var weekendTotal = 0.0
        var weekdayDays = 0
        var weekendDays = 0

        let metricAlias = "day_value"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current

        if hasAggregationData(in: "daily_stats") {
            let metricColumn = Self.insightMetricAggregateColumn(metric)
            try? dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT
                        strftime('%Y-%m-%d', time_bucket_ms / 1000.0, 'unixepoch', 'localtime') AS day_key,
                        SUM(\(metricColumn)) AS \(metricAlias)
                    FROM daily_stats
                    GROUP BY day_key
                """)

                for row in rows {
                    guard let dayKey = row["day_key"] as? String,
                          let dayDate = dateFormatter.date(from: dayKey) else { continue }

                    let weekday = calendar.component(.weekday, from: dayDate)
                    let isWeekday = (2...6).contains(weekday)
                    let value = Self.numericValue(row: row, key: metricAlias)

                    switch filter {
                    case .all:
                        if isWeekday {
                            weekdayTotal += value
                            weekdayDays += 1
                        } else {
                            weekendTotal += value
                            weekendDays += 1
                        }
                    case .weekdays:
                        if isWeekday {
                            weekdayTotal += value
                            weekdayDays += 1
                        }
                    case .weekends:
                        if !isWeekday {
                            weekendTotal += value
                            weekendDays += 1
                        }
                    }
                }
            }
        } else {
            let metricSQL = Self.insightMetricMessageSQL(metric)
            try? dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT
                        strftime('%Y-%m-%d', created_at / 1000.0, 'unixepoch', 'localtime') AS day_key,
                        \(metricSQL) AS \(metricAlias)
                    FROM messages
                    GROUP BY day_key
                """)

                for row in rows {
                    guard let dayKey = row["day_key"] as? String,
                          let dayDate = dateFormatter.date(from: dayKey) else { continue }

                    let weekday = calendar.component(.weekday, from: dayDate)
                    let isWeekday = (2...6).contains(weekday)
                    let value = Self.numericValue(row: row, key: metricAlias)

                    switch filter {
                    case .all:
                        if isWeekday {
                            weekdayTotal += value
                            weekdayDays += 1
                        } else {
                            weekendTotal += value
                            weekendDays += 1
                        }
                    case .weekdays:
                        if isWeekday {
                            weekdayTotal += value
                            weekdayDays += 1
                        }
                    case .weekends:
                        if !isWeekday {
                            weekendTotal += value
                            weekendDays += 1
                        }
                    }
                }
            }
        }

        let weekdayAverage = weekdayDays > 0 ? weekdayTotal / Double(weekdayDays) : 0
        let weekendAverage = weekendDays > 0 ? weekendTotal / Double(weekendDays) : 0

        return WeekdayWeekendIntensity(
            weekdayTotal: weekdayTotal,
            weekendTotal: weekendTotal,
            weekdayAverage: weekdayAverage,
            weekendAverage: weekendAverage
        )
    }

    public func getHourlyIntensity(metric: InsightMetric, filter: DayTypeFilter) -> [HourlyIntensityPoint] {
        var valueByHour: [Int: Double] = Dictionary(uniqueKeysWithValues: (0..<24).map { ($0, 0) })

        if hasAggregationData(in: "hourly_stats") {
            let metricColumn = Self.insightMetricAggregateColumn(metric)
            let dayFilterSQL = Self.insightDayFilterSQL(timestampExpr: "time_bucket_ms", filter: filter)
            try? dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT
                        CAST(strftime('%H', time_bucket_ms / 1000.0, 'unixepoch', 'localtime') AS INTEGER) AS hour_of_day,
                        SUM(\(metricColumn)) AS hour_value
                    FROM hourly_stats
                    WHERE \(dayFilterSQL)
                    GROUP BY hour_of_day
                    ORDER BY hour_of_day ASC
                """)

                for row in rows {
                    let hour = Int(row["hour_of_day"] as? Int64 ?? -1)
                    guard (0..<24).contains(hour) else { continue }
                    valueByHour[hour] = Self.numericValue(row: row, key: "hour_value")
                }
            }
        } else {
            let metricSQL = Self.insightMetricMessageSQL(metric)
            let dayFilterSQL = Self.insightDayFilterSQL(timestampExpr: "created_at", filter: filter)
            try? dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT
                        CAST(strftime('%H', created_at / 1000.0, 'unixepoch', 'localtime') AS INTEGER) AS hour_of_day,
                        \(metricSQL) AS hour_value
                    FROM messages
                    WHERE \(dayFilterSQL)
                    GROUP BY hour_of_day
                    ORDER BY hour_of_day ASC
                """)

                for row in rows {
                    let hour = Int(row["hour_of_day"] as? Int64 ?? -1)
                    guard (0..<24).contains(hour) else { continue }
                    valueByHour[hour] = Self.numericValue(row: row, key: "hour_value")
                }
            }
        }

        return (0..<24).map { hour in
            HourlyIntensityPoint(hour: hour, value: valueByHour[hour] ?? 0)
        }
    }

    public func getModelLensRows(groupBy: ModelLensGroupBy) -> [ModelLensRow] {
        let groupExpr: String
        let providerExpr: String
        switch groupBy {
        case .model:
            groupExpr = "COALESCE(NULLIF(model_id, ''), 'unknown')"
            providerExpr = "COALESCE(NULLIF(provider_id, ''), '')"
        case .provider:
            groupExpr = "COALESCE(NULLIF(provider_id, ''), 'unknown')"
            providerExpr = "''"
        }

        var rowsResult: [ModelLensRow] = []

        if hasAggregationData(in: "monthly_stats") {
            try? dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT
                        \(groupExpr) AS dimension_name,
                        \(providerExpr) AS provider_id,
                        SUM(input_tokens) AS input_tokens,
                        SUM(output_tokens) AS output_tokens,
                        SUM(duration_ms) AS duration_ms,
                        SUM(message_count) AS total_messages,
                        SUM(CASE WHEN duration_ms > 0 THEN message_count ELSE 0 END) AS valid_duration_messages
                    FROM monthly_stats
                    \(groupBy == .model ? "GROUP BY dimension_name, provider_id" : "GROUP BY dimension_name")
                """)

                rowsResult = rows.compactMap { row in
                    let name = row["dimension_name"] as? String ?? "unknown"
                    let provider = row["provider_id"] as? String ?? ""
                    let inputTokens = Self.numericValue(row: row, key: "input_tokens")
                    let outputTokens = Self.numericValue(row: row, key: "output_tokens")
                    let durationMs = Self.numericValue(row: row, key: "duration_ms")
                    let durationSeconds = durationMs / 1000.0
                    let tps = durationSeconds > 0 ? outputTokens / durationSeconds : 0
                    let totalMessages = Self.numericValue(row: row, key: "total_messages")
                    let validMessages = Self.numericValue(row: row, key: "valid_duration_messages")
                    let ratio = totalMessages > 0 ? validMessages / totalMessages : 0
                    return ModelLensRow(
                        dimensionName: name,
                        providerId: provider,
                        inputTokens: inputTokens,
                        outputTPS: tps,
                        outputTokens: outputTokens,
                        durationSeconds: durationSeconds,
                        validDurationMessageRatio: ratio
                    )
                }
            }
        } else if hasAggregationData(in: "daily_stats") {
            try? dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT
                        \(groupExpr) AS dimension_name,
                        \(providerExpr) AS provider_id,
                        SUM(input_tokens) AS input_tokens,
                        SUM(output_tokens) AS output_tokens,
                        SUM(duration_ms) AS duration_ms,
                        SUM(message_count) AS total_messages,
                        SUM(CASE WHEN duration_ms > 0 THEN message_count ELSE 0 END) AS valid_duration_messages
                    FROM daily_stats
                    \(groupBy == .model ? "GROUP BY dimension_name, provider_id" : "GROUP BY dimension_name")
                """)

                rowsResult = rows.compactMap { row in
                    let name = row["dimension_name"] as? String ?? "unknown"
                    let provider = row["provider_id"] as? String ?? ""
                    let inputTokens = Self.numericValue(row: row, key: "input_tokens")
                    let outputTokens = Self.numericValue(row: row, key: "output_tokens")
                    let durationMs = Self.numericValue(row: row, key: "duration_ms")
                    let durationSeconds = durationMs / 1000.0
                    let tps = durationSeconds > 0 ? outputTokens / durationSeconds : 0
                    let totalMessages = Self.numericValue(row: row, key: "total_messages")
                    let validMessages = Self.numericValue(row: row, key: "valid_duration_messages")
                    let ratio = totalMessages > 0 ? validMessages / totalMessages : 0
                    return ModelLensRow(
                        dimensionName: name,
                        providerId: provider,
                        inputTokens: inputTokens,
                        outputTPS: tps,
                        outputTokens: outputTokens,
                        durationSeconds: durationSeconds,
                        validDurationMessageRatio: ratio
                    )
                }
            }
        } else {
            try? dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT
                        \(groupExpr) AS dimension_name,
                        \(providerExpr) AS provider_id,
                        SUM(CAST(COALESCE(token_input, '0') AS REAL)) AS input_tokens,
                        SUM(CAST(COALESCE(token_output, '0') AS REAL)) AS output_tokens,
                        SUM(
                            CASE
                                WHEN completed_at IS NOT NULL AND completed_at > created_at
                                THEN (completed_at - created_at) / 1000.0
                                ELSE 0
                            END
                        ) AS duration_seconds,
                        COUNT(*) AS total_messages,
                        SUM(
                            CASE
                                WHEN completed_at IS NOT NULL AND completed_at > created_at THEN 1
                                ELSE 0
                            END
                        ) AS valid_duration_messages
                    FROM messages
                    \(groupBy == .model ? "GROUP BY dimension_name, provider_id" : "GROUP BY dimension_name")
                """)

                rowsResult = rows.compactMap { row in
                    let name = row["dimension_name"] as? String ?? "unknown"
                    let provider = row["provider_id"] as? String ?? ""
                    let inputTokens = Self.numericValue(row: row, key: "input_tokens")
                    let outputTokens = Self.numericValue(row: row, key: "output_tokens")
                    let durationSeconds = Self.numericValue(row: row, key: "duration_seconds")
                    let totalMessages = Self.numericValue(row: row, key: "total_messages")
                    let validMessages = Self.numericValue(row: row, key: "valid_duration_messages")
                    let tps = durationSeconds > 0 ? outputTokens / durationSeconds : 0
                    let ratio = totalMessages > 0 ? validMessages / totalMessages : 0
                    return ModelLensRow(
                        dimensionName: name,
                        providerId: provider,
                        inputTokens: inputTokens,
                        outputTPS: tps,
                        outputTokens: outputTokens,
                        durationSeconds: durationSeconds,
                        validDurationMessageRatio: ratio
                    )
                }
            }
        }

        rowsResult.sort(by: { $0.inputTokens > $1.inputTokens })
        return rowsResult
    }

    public func getModelLensStats(groupBy: ModelLensGroupBy, metric: ModelLensMetric) -> [ModelLensPoint] {
        let rows = getModelLensRows(groupBy: groupBy)
        var points: [ModelLensPoint] = rows.map { row in
            ModelLensPoint(
                dimensionName: row.dimensionName,
                providerId: row.providerId,
                value: metric == .inputTokens ? row.inputTokens : row.outputTPS,
                outputTokens: row.outputTokens,
                durationSeconds: row.durationSeconds,
                validDurationMessageRatio: row.validDurationMessageRatio
            )
        }

        points.sort(by: { $0.value > $1.value })

        return points
    }
    
    // MARK: - Helper Methods

    private struct DailyHeatmapQueryContext {
        let safeDays: Int
        let calendar: Calendar
        let startDate: Date
        let endDateExclusive: Date
        let startMs: Int64
        let endMs: Int64
        let queryStartMs: Int64
        let queryEndMs: Int64
    }

    private func makeDailyHeatmapQueryContext(lastNDays: Int) -> DailyHeatmapQueryContext {
        let safeDays = max(1, lastNDays)
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        let todayStart = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(safeDays - 1), to: todayStart) ?? todayStart
        let endDateExclusive = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        let startMs = Int64(startDate.timeIntervalSince1970 * 1000)
        let endMs = Int64(endDateExclusive.timeIntervalSince1970 * 1000)
        let queryStart = calendar.date(byAdding: .day, value: -2, to: startDate) ?? startDate
        let queryEnd = calendar.date(byAdding: .day, value: 2, to: endDateExclusive) ?? endDateExclusive
        let queryStartMs = Int64(queryStart.timeIntervalSince1970 * 1000)
        let queryEndMs = Int64(queryEnd.timeIntervalSince1970 * 1000)

        return DailyHeatmapQueryContext(
            safeDays: safeDays,
            calendar: calendar,
            startDate: startDate,
            endDateExclusive: endDateExclusive,
            startMs: startMs,
            endMs: endMs,
            queryStartMs: queryStartMs,
            queryEndMs: queryEndMs
        )
    }

    private func dayStartMsSQL(_ timestampExpr: String) -> String {
        "CAST(strftime('%s', datetime(\(timestampExpr) / 1000.0, 'unixepoch', 'localtime', 'start of day', 'utc')) AS INTEGER) * 1000"
    }

    private func fetchDailyHeatValueMaps(context: DailyHeatmapQueryContext) -> [InsightMetric: [Int64: Double]] {
        var maps: [InsightMetric: [Int64: Double]] = [
            .inputTokens: [:],
            .messages: [:],
            .cost: [:]
        ]

        if hasAggregationData(in: "daily_stats") {
            let dayStart = dayStartMsSQL("time_bucket_ms")
            try? dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT
                        \(dayStart) AS day_start_ms,
                        SUM(input_tokens) AS input_tokens_value,
                        SUM(message_count) AS messages_value,
                        SUM(cost) AS cost_value
                    FROM daily_stats
                    WHERE time_bucket_ms >= ? AND time_bucket_ms < ?
                    GROUP BY day_start_ms
                """, arguments: [context.queryStartMs, context.queryEndMs])

                for row in rows {
                    let dayStartMs = row["day_start_ms"] as? Int64 ?? 0
                    maps[.inputTokens]?[dayStartMs] = Self.numericValue(row: row, key: "input_tokens_value")
                    maps[.messages]?[dayStartMs] = Self.numericValue(row: row, key: "messages_value")
                    maps[.cost]?[dayStartMs] = Self.numericValue(row: row, key: "cost_value")
                }
            }
        }

        let hasCoverage = InsightMetric.allCases.contains { metric in
            !(maps[metric] ?? [:]).isEmpty
        }
        if hasCoverage {
            return maps
        }

        let dayStart = dayStartMsSQL("created_at")
        try? dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    \(dayStart) AS day_start_ms,
                    SUM(CAST(COALESCE(token_input, '0') AS INTEGER)) AS input_tokens_value,
                    COUNT(*) AS messages_value,
                    SUM(COALESCE(cost, 0)) AS cost_value
                FROM messages
                WHERE created_at >= ? AND created_at < ?
                GROUP BY day_start_ms
            """, arguments: [context.startMs, context.endMs])

            for row in rows {
                let dayStartMs = row["day_start_ms"] as? Int64 ?? 0
                maps[.inputTokens]?[dayStartMs] = Self.numericValue(row: row, key: "input_tokens_value")
                maps[.messages]?[dayStartMs] = Self.numericValue(row: row, key: "messages_value")
                maps[.cost]?[dayStartMs] = Self.numericValue(row: row, key: "cost_value")
            }
        }

        return maps
    }

    private func buildDailyHeatPoints(
        valuesByDayStartMs: [Int64: Double],
        startDate: Date,
        dayCount: Int,
        calendar: Calendar
    ) -> [DailyHeatPoint] {
        (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let dayMs = Int64(dayStart.timeIntervalSince1970 * 1000)
            return DailyHeatPoint(date: dayStart, dayStartMs: dayMs, value: valuesByDayStartMs[dayMs] ?? 0)
        }
    }

    private func hasAggregationData(in tableName: String) -> Bool {
        do {
            return try dbPool.read { db in
                let tableExists = (try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?",
                    arguments: [tableName]
                ) ?? 0) > 0
                guard tableExists else { return false }
                return try Row.fetchOne(db, sql: "SELECT 1 FROM \(tableName) LIMIT 1") != nil
            }
        } catch {
            return false
        }
    }

    private static func insightMetricAggregateColumn(_ metric: InsightMetric) -> String {
        switch metric {
        case .inputTokens:
            return "input_tokens"
        case .messages:
            return "message_count"
        case .cost:
            return "cost"
        }
    }

    private static func insightMetricMessageSQL(_ metric: InsightMetric) -> String {
        switch metric {
        case .inputTokens:
            return "SUM(CAST(COALESCE(token_input, '0') AS INTEGER))"
        case .messages:
            return "COUNT(*)"
        case .cost:
            return "SUM(COALESCE(cost, 0))"
        }
    }

    private static func insightDayFilterSQL(timestampExpr: String, filter: DayTypeFilter) -> String {
        switch filter {
        case .all:
            return "1 = 1"
        case .weekdays:
            return "CAST(strftime('%w', \(timestampExpr) / 1000.0, 'unixepoch', 'localtime') AS INTEGER) BETWEEN 1 AND 5"
        case .weekends:
            return "CAST(strftime('%w', \(timestampExpr) / 1000.0, 'unixepoch', 'localtime') AS INTEGER) IN (0, 6)"
        }
    }

    private static func numericValue(row: Row, key: String) -> Double {
        if let value = row[key] as? Double {
            return value
        }
        if let value = row[key] as? Int64 {
            return Double(value)
        }
        if let value = row[key] as? Int {
            return Double(value)
        }
        return 0
    }

    private static func anomalyMetric(from values: [Double]) -> AnomalyMetric {
        guard !values.isEmpty else {
            return AnomalyMetric(current: 0, mean: 0, stdDev: 0)
        }

        let current = values.last ?? 0
        let baseline = values.count > 1 ? Array(values.dropLast()) : values
        let mean = baseline.reduce(0, +) / Double(max(1, baseline.count))

        let variance = baseline.reduce(0.0) { partial, value in
            let delta = value - mean
            return partial + (delta * delta)
        } / Double(max(1, baseline.count))

        let stdDev = sqrt(max(0, variance))
        return AnomalyMetric(current: current, mean: mean, stdDev: stdDev)
    }

    public enum TimeRange {
        case today
        case last24Hours
        case last7Days
        case last30Days
        case allTime
        case custom(start: Date, end: Date)
    }

    private func getTimestamps(for range: TimeRange) -> (start: Int64, end: Int64) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let now = Date()

        let (startDate, endDate): (Date, Date)
        switch range {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            (startDate, endDate) = (start, end)
        case .last24Hours:
            // Use current time as end to include current hour's partial data
            // This ensures that chart shows up to current moment, not 1 hour behind
            let end = now
            let start = calendar.date(byAdding: .hour, value: -24, to: end)!
            (startDate, endDate) = (start, end)
        case .last7Days:
            let rangeEnd = calendar.startOfDay(for: now)
            let rangeStart = calendar.date(byAdding: .day, value: -7, to: rangeEnd)!
            (startDate, endDate) = (rangeStart, rangeEnd)
        case .last30Days:
            let end = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -30, to: end)!
            (startDate, endDate) = (start, end)
        case .allTime:
            var startTime: Int64 = 0
            try? dbPool.read { db in
                if let row = try Row.fetchOne(db, sql: "SELECT MIN(created_at) as minTime FROM messages") {
                    startTime = row["minTime"] as? Int64 ?? 0
                }
            }
            return (startTime, Int64(now.timeIntervalSince1970 * 1000))
        case .custom(let start, let end):
            (startDate, endDate) = (start, end)
        }

        let start = Int64(startDate.timeIntervalSince1970 * 1000)
        let end = Int64(endDate.timeIntervalSince1970 * 1000)
        #if DEBUG
        logger.debug("TimeRange.\(range): start=\(Date(timeIntervalSince1970: Double(start) / 1000)), end=\(Date(timeIntervalSince1970: Double(end) / 1000))")
        #endif
        return (start, end)
    }
}

extension StatisticsRepository: StatisticsRepositoryProtocol {}
