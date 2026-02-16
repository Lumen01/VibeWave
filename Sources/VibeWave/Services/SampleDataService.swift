import Foundation
import GRDB

public final class SampleDataService {
    private let logger = AppLogger(category: "SampleDataService")
    private let dbPool: DatabasePool
    private let messageRepository: MessageRepository
    
    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
        self.messageRepository = MessageRepository(dbPool: dbPool)
    }
    
    public func generateSampleData() {
        let messages = createSampleMessages()

        do {
            try dbPool.write { db in
                // Clear existing data only if table exists
                let tableExists = try db.tableExists("messages")
                if tableExists {
                    try db.execute(sql: "DELETE FROM messages")
                }

                // Insert sample messages
                for message in messages {
                    try messageRepository.insert(message: message)
                }
            }
            logger.info("Successfully generated \(messages.count) sample messages")
        } catch {
            logger.error("Error generating sample data: \(error)")
        }
    }
    
    private func createSampleMessages() -> [Message] {
        var messages: [Message] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Generate data for the last 30 days
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // Generate 3-8 messages per day
            let messagesPerDay = Int.random(in: 3...8)
            
            for messageIndex in 0..<messagesPerDay {
                let sessionId = "session_\(dayOffset)"
                let hour = Int.random(in: 9...18) // Business hours
                let minute = Int.random(in: 0...59)
                
                guard let messageDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else { continue }
                
                let message = Message(
                    id: UUID().uuidString,
                    sessionID: sessionId,
                    role: messageIndex % 2 == 0 ? "user" : "assistant",
                    time: MessageTime(created: ISO8601DateFormatter().string(from: messageDate), completed: nil),
                    parentID: nil,
                    providerID: ["openai", "anthropic"].randomElement() ?? "openai",
                    modelID: ["gpt-4", "gpt-3.5-turbo", "claude-3"].randomElement() ?? "gpt-4",
                    agent: nil,
                    mode: nil,
                    variant: nil,
                    cwd: "/Users/lumen/Develop/\(["projectA", "projectB", "projectC"].randomElement() ?? "projectA")",
                    root: nil,
                    tokens: Tokens(
                        input: Int.random(in: 50...200),
                        output: Int.random(in: 100...500),
                        reasoning: messageIndex % 3 == 0 ? Int.random(in: 100...300) : 0,
                        cacheRead: Int.random(in: 0...100),
                        cacheWrite: Int.random(in: 0...50)
                    ),
                    cost: Double.random(in: 0.01...0.50)
                )
                
                messages.append(message)
            }
        }
        
        return messages
    }
}
