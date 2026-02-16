import Foundation
import GRDB
import Combine

public final class MenuBarViewModel: ObservableObject {
    public static let shared = MenuBarViewModel(dbPool: DatabaseRepository.shared.dbPool())
    
    @Published public var stats: StatisticsRepository.OverviewStats?
    @Published public var topModels: [StatisticsRepository.ModelStats] = []
    @Published public var topProjects: [StatisticsRepository.ProjectStats] = []
    @Published public var isLoading: Bool = false
    
    @Published public var totalUsageTokens: Int = 0
    @Published public var totalUsageCost: Double = 0
    @Published public var firstUsageDate: Date?
    
    public var usageDays: Int? {
        guard let firstDate = firstUsageDate else { return nil }
        let calendar = Calendar.current
        let startOfFirstDay = calendar.startOfDay(for: firstDate)
        let startOfToday = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: startOfFirstDay, to: startOfToday)
        return components.day
    }
    
    public var usageDaysString: String? {
        guard let days = usageDays else { return nil }
        return String(format: L10n.menuBarDays, days)
    }
    
    private let statisticsRepository: StatisticsRepository
    private var cancellables = Set<AnyCancellable>()
    private let dbPool: DatabasePool
    
    private init(dbPool: DatabasePool) {
        self.dbPool = dbPool
        self.statisticsRepository = StatisticsRepository(dbPool: dbPool)
        loadData()
        setupNotificationObserver()
    }
    
    public func loadData() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let stats = self.statisticsRepository.getOverviewStats(timeRange: .today)
            let models = self.statisticsRepository.getTopModels(timeRange: .today, limit: 5)
            let projects = self.statisticsRepository.getTopProjects(timeRange: .today, limit: 5)
            
            let (totalTokens, totalCost, firstDate) = self.calculateTotalUsage()
            
            DispatchQueue.main.async {
                self.stats = stats
                self.topModels = models
                self.topProjects = projects
                self.totalUsageTokens = totalTokens
                self.totalUsageCost = totalCost
                self.firstUsageDate = firstDate
                self.isLoading = false
            }
        }
    }
    
    private func calculateTotalUsage() -> (Int, Double, Date?) {
        do {
            return try dbPool.read { db in
                var tokens = 0
                var cost: Double = 0.0
                var firstDate: Date?

                if let row = try Row.fetchOne(db, sql: "SELECT SUM(CAST(token_input AS INTEGER)) as total_tokens, SUM(cost) as total_cost FROM messages") {
                    tokens = Int(row["total_tokens"] as? Int64 ?? 0)
                    cost = row["total_cost"] as? Double ?? 0.0
                }

                if let row = try Row.fetchOne(db, sql: "SELECT MIN(created_at) as first_date FROM messages") {
                    let timestamp = row["first_date"] as? Int64
                    firstDate = timestamp != nil ? Date(timeIntervalSince1970: Double(timestamp!) / 1000.0) : nil
                }

                return (tokens, cost, firstDate)
            }
        } catch {
            print("Error calculating total usage: \(error)")
            return (0, 0.0, nil)
        }
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: .appDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadData()
            }
            .store(in: &cancellables)
    }
}

extension MenuBarViewModel {
    func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return String(value)
        }
    }
    
    func formatCost(_ value: Double) -> String {
        return String(format: "$%.2f", value)
    }
}
