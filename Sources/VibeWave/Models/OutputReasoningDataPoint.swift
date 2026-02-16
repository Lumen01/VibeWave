import Foundation

public struct OutputReasoningDataPoint: Identifiable {
    public var id: TimeInterval { bucketStart }
    public let timestamp: TimeInterval
    public let bucketStart: TimeInterval
    public let bucketIndex: Int
    public let label: String
    public let outputTokens: Int
    public let reasoningTokens: Int
    public let hasData: Bool

    public var totalTokens: Int {
        outputTokens + reasoningTokens
    }

    public init(
        timestamp: TimeInterval,
        label: String,
        outputTokens: Int,
        reasoningTokens: Int,
        bucketIndex: Int = 0,
        hasData: Bool = false,
        bucketStart: TimeInterval? = nil
    ) {
        self.timestamp = timestamp
        self.bucketStart = bucketStart ?? timestamp
        self.bucketIndex = bucketIndex
        self.label = label
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.hasData = hasData
    }
}
