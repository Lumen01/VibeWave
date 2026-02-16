import Foundation
import SwiftUI

/// 分段数据（用于堆叠或分组显示）
public struct SegmentData: Identifiable {
    public let id = UUID()

    /// 维度值（项目名称或模型ID）
    public let dimensionValue: String

    /// Tokens 数量
    public let tokenCount: Int

    /// 颜色（由外部指定）
    public let color: Color

    public init(dimensionValue: String, tokenCount: Int, color: Color) {
        self.dimensionValue = dimensionValue
        self.tokenCount = tokenCount
        self.color = color
    }
}

public struct InputTokensDataPoint: Identifiable {
    public var id: TimeInterval { bucketStart }
    public let timestamp: TimeInterval
    public let bucketStart: TimeInterval
    public let bucketIndex: Int
    public let label: String
    public let totalTokens: Int
    public let hasData: Bool
    public let segments: [SegmentData]

    public init(
        timestamp: TimeInterval,
        label: String,
        totalTokens: Int,
        segments: [SegmentData],
        bucketIndex: Int = 0,
        hasData: Bool = false,
        bucketStart: TimeInterval? = nil
    ) {
        self.timestamp = timestamp
        self.bucketStart = bucketStart ?? timestamp
        self.bucketIndex = bucketIndex
        self.label = label
        self.totalTokens = totalTokens
        self.hasData = hasData
        self.segments = segments
    }
}
