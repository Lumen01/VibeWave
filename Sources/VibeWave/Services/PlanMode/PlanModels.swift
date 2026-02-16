import Foundation

/// Structured plan for completing complex tasks
public struct TaskPlan {
    public let id: String
    public let objective: String
    public let context: String
    public var phases: [Phase]
    public let createdAt: Date
    public var status: PlanStatus
    
    public init(
        id: String = UUID().uuidString,
        objective: String,
        context: String,
        phases: [Phase]
    ) {
        self.id = id
        self.objective = objective
        self.context = context
        self.phases = phases
        self.createdAt = Date()
        self.status = .pending
    }
    
    public struct Phase {
        public let id: String
        public let title: String
        public let description: String
        public let tasks: [Task]
        public var status: PhaseStatus
        
        public init(
            id: String = UUID().uuidString,
            title: String,
            description: String,
            tasks: [Task]
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.tasks = tasks
            self.status = .pending
        }
    }
    
    public struct Task {
        public let id: String
        public let description: String
        public var status: TaskStatus
        
        public init(
            id: String = UUID().uuidString,
            description: String
        ) {
            self.id = id
            self.description = description
            self.status = .pending
        }
    }
    
    public enum PlanStatus: String, CaseIterable {
        case pending = "pending"
        case inProgress = "in_progress"
        case completed = "completed"
        case cancelled = "cancelled"
    }
    
    public enum PhaseStatus: String, CaseIterable {
        case pending = "pending"
        case inProgress = "in_progress"
        case completed = "completed"
        case skipped = "skipped"
    }
    
    public enum TaskStatus: String, CaseIterable {
        case pending = "pending"
        case inProgress = "in_progress"
        case completed = "completed"
        case blocked = "blocked"
        case skipped = "skipped"
    }
}

/// Markdown formatter for plans
public struct PlanMarkdownFormatter {
    public static func format(_ plan: TaskPlan) -> String {
        var markdown = ""
        
        // Header
        markdown += "# 📋 Plan: \(plan.objective)\n\n"
        markdown += "**Status:** \(plan.status.rawValue)\n"
        markdown += "**Created:** \(formatDate(plan.createdAt))\n\n"
        
        // Context
        if !plan.context.isEmpty {
            markdown += "## Context\n\n"
            markdown += "\(plan.context)\n\n"
        }
        
        // Phases
        markdown += "## Phases\n\n"
        for (index, phase) in plan.phases.enumerated() {
            markdown += format(phase, index: index + 1)
            markdown += "\n"
        }
        
        return markdown
    }
    
    private static func format(_ phase: TaskPlan.Phase, index: Int) -> String {
        var markdown = ""
        
        let statusEmoji = emoji(for: phase.status)
        markdown += "### \(statusEmoji) Phase \(index): \(phase.title)\n\n"
        markdown += "**Status:** \(phase.status.rawValue)\n"
        markdown += "**Description:** \(phase.description)\n\n"
        
        // Tasks
        if !phase.tasks.isEmpty {
            markdown += "#### Tasks\n\n"
            for (taskIndex, task) in phase.tasks.enumerated() {
                let taskEmoji = emoji(for: task.status)
                markdown += "\(taskEmoji) **\(taskIndex + 1).** \(task.description) (\(task.status.rawValue))\n"
            }
            markdown += "\n"
        }
        
        return markdown
    }
    
    private static func emoji(for status: TaskPlan.PhaseStatus) -> String {
        switch status {
        case .pending: return "⏳"
        case .inProgress: return "🔄"
        case .completed: return "✅"
        case .skipped: return "⏭️"
        }
    }
    
    private static func emoji(for status: TaskPlan.TaskStatus) -> String {
        switch status {
        case .pending: return "⏸️"
        case .inProgress: return "🔨"
        case .completed: return "✓"
        case .blocked: return "🚫"
        case .skipped: return "↷"
        }
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
