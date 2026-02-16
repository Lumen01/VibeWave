import SwiftUI

@available(macOS 14.0, *)
public struct AnimatedKPICard: View {
    let title: String
    let value: Int
    let icon: String
    let format: NumberFormat
    let trendValues: [Double]
    let duration: Double
    
    @State private var displayValue: Double = 0
    @State private var hasAnimated: Bool = false
    @State private var bounceTrigger: Bool = false
    
    public enum NumberFormat {
        case plain
        case compact
        case currency
        case tokens
    }
    
    public init(
        title: String,
        value: Int,
        icon: String,
        format: NumberFormat,
        trendValues: [Double] = [],
        duration: Double = 0.4
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.format = format
        self.trendValues = trendValues
        self.duration = duration
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .symbolEffect(.bounce, value: bounceTrigger)
                    Spacer()
                }

                Text(formattedValue)
                    .font(DesignTokens.Typography.kpiValue)
                    .onAppear {
                        if !hasAnimated {
                            animate(from: 0, to: Double(value), duration: 0.6)
                            hasAnimated = true
                        } else {
                            animate(from: displayValue, to: Double(value), duration: duration)
                        }
                    }
                    .onChange(of: value) { newValue in
                        animate(from: displayValue, to: Double(newValue), duration: duration)
                        animateIconBounce()
                    }

                Text(title)
                    .font(DesignTokens.Typography.kpiTitle)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trendBars
                .frame(width: 58)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func animate(from: Double, to: Double, duration: Double) {
        withAnimation(.easeInOut(duration: duration)) {
            displayValue = to
        }
    }

    private var trendBars: some View {
        let normalized = normalizedTrendValues
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(normalized.enumerated()), id: \.offset) { _, ratio in
                let clampedRatio = max(0.0, min(ratio, 1.0))
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor.opacity(0.25 + clampedRatio * 0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: CGFloat(4 + clampedRatio * 14))
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .frame(height: 32)
        .accessibilityHidden(true)
    }

    private var normalizedTrendValues: [Double] {
        let normalizedCount = 7
        var values = Array(trendValues.suffix(normalizedCount))
        if values.count < normalizedCount {
            values.insert(contentsOf: Array(repeating: 0, count: normalizedCount - values.count), at: 0)
        }

        let maxValue = values.max() ?? 0
        guard maxValue > 0 else {
            return Array(repeating: 0.25, count: normalizedCount)
        }
        return values.map { $0 / maxValue }
    }
    
    private func animateIconBounce() {
        bounceTrigger.toggle()
    }
    
    private var formattedValue: String {
        let intValue = Int(displayValue)
        switch format {
        case .plain:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return formatter.string(from: NSNumber(value: intValue)) ?? "\(intValue)"
        case .compact:
            return formatCompact(intValue)
        case .currency:
            return String(format: "$%.2f", displayValue / 100.0)
        case .tokens:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: intValue)) ?? "\(intValue)"
        }
    }
    
    private func formatCompact(_ value: Int) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000 {
            let millions = Double(value) / 1_000_000.0
            if millions >= 1000 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.groupingSeparator = ","
                formatter.minimumFractionDigits = 1
                formatter.maximumFractionDigits = 1
                if let formatted = formatter.string(from: NSNumber(value: millions)) {
                    return formatted + "M"
                }
            }
            return String(format: "%.1fM", millions)
        } else if absValue >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000.0)
        } else {
            return "\(value)"
        }
    }
}

#if DEBUG
@available(macOS 14.0, *)
struct AnimatedKPICard_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            AnimatedKPICard(title: "Sessions", value: 1234, icon: "doc.text", format: .plain)
            AnimatedKPICard(title: "Messages", value: 56789, icon: "bubble.left", format: .compact)
        }
        .padding()
    }
}
#endif
