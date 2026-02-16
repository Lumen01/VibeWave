import Foundation

public struct SessionSummary: Codable {
    public let title: String?
    public let diffs: [FileDiff]?
    
    public struct FileDiff: Codable {
        public let file: String?
        public let before: String?
        public let after: String?
        public let additions: Int?
        public let deletions: Int?
        
        public init(file: String? = nil, before: String? = nil, after: String? = nil, additions: Int? = nil, deletions: Int? = nil) {
            self.file = file
            self.before = before
            self.after = after
            self.additions = additions
            self.deletions = deletions
        }
    }
    
    // 计算属性
    public var totalAdditions: Int { 
        diffs?.compactMap { $0.additions }.reduce(0, +) ?? 0 
    }
    public var totalDeletions: Int { 
        diffs?.compactMap { $0.deletions }.reduce(0, +) ?? 0 
    }
    public var fileCount: Int {
        diffs?.count ?? 0
    }
    
    public init(title: String? = nil, diffs: [FileDiff]? = nil) {
        self.title = title
        self.diffs = diffs
    }
}
