import Foundation

public struct SingleMetricDataPoint: Identifiable {
    public var id: TimeInterval { bucketStart }
    public let timestamp: TimeInterval
    public let bucketStart: TimeInterval
    public let bucketIndex: Int
    public let label: String
    public let value: Double
    public let hasData: Bool

    public init(
        timestamp: TimeInterval,
        label: String,
        value: Double,
        bucketIndex: Int = 0,
        hasData: Bool = false,
        bucketStart: TimeInterval? = nil
    ) {
        self.timestamp = timestamp
        self.bucketStart = bucketStart ?? timestamp
        self.bucketIndex = bucketIndex
        self.label = label
        self.value = value
        self.hasData = hasData
    }
}
