import SwiftUI

enum AutomationGaugeStyle {
    static func clampedLevel(_ level: Double?) -> Double {
        min(max(level ?? 0.0, 0.0), 100.0)
    }
}

/// Consumption and Efficiency View - 消耗和效能视图
/// 显示项目的消耗指标和每行代码的成本效率
public struct ConsumptionEfficiencyView: View {
    let consumption: StatisticsRepository.ProjectConsumptionStats?
    let automationLevel: Double?

    public init(consumption: StatisticsRepository.ProjectConsumptionStats?, automationLevel: Double? = nil) {
        self.consumption = consumption
        self.automationLevel = automationLevel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.consumptionConsumptionAndEfficiency)
                    .font(.headline)
                Spacer()
            }

            GeometryReader { _ in
                HStack(spacing: 8) {
                    consumptionCard(
                        title: L10n.consumptionCost,
                        value: consumption?.cost ?? 0,
                        icon: "dollarsign.circle",
                        color: .red,
                        perCodeLinesLabel: L10n.consumptionPerCodeLines,
                        efficiencyValue: {
                            guard let c = consumption, c.netCodeLines != 0 else { return "-" }
                            let perLine = abs(c.cost / Double(c.netCodeLines))
                            return String(format: "$%.4f", perLine)
                        }()
                    )

                    consumptionCard(
                        title: L10n.consumptionInput,
                        value: Double(consumption?.inputTokens ?? 0),
                        icon: "arrow.down",
                        color: .blue,
                        perCodeLinesLabel: L10n.consumptionPerCodeLines,
                        efficiencyValue: {
                            guard let c = consumption, c.netCodeLines != 0 else { return "-" }
                            let perLine = abs(Double(c.inputTokens) / Double(c.netCodeLines))
                            return formatCompactTokens(perLine)
                        }()
                    )

                    consumptionCard(
                        title: L10n.consumptionOutput,
                        value: Double(consumption?.outputTokens ?? 0),
                        icon: "arrow.up",
                        color: .red,
                        perCodeLinesLabel: L10n.consumptionPerCodeLines,
                        efficiencyValue: {
                            guard let c = consumption, c.netCodeLines != 0 else { return "-" }
                            let perLine = abs(Double(c.outputTokens) / Double(c.netCodeLines))
                            return formatCompactTokens(perLine)
                        }()
                    )

                    consumptionCard(
                        title: L10n.consumptionReasoning,
                        value: Double(consumption?.reasoningTokens ?? 0),
                        icon: "brain",
                        color: .purple,
                        perCodeLinesLabel: L10n.consumptionPerCodeLines,
                        efficiencyValue: {
                            guard let c = consumption, c.netCodeLines != 0 else { return "-" }
                            let perLine = abs(Double(c.reasoningTokens) / Double(c.netCodeLines))
                            return formatCompactTokens(perLine)
                        }()
                    )

                    automationGaugePanel(
                        level: AutomationGaugeStyle.clampedLevel(automationLevel)
                    )
                }
            }
            .frame(height: 100)
        }
    }

    private func consumptionCard(
        title: String,
        value: Double,
        icon: String,
        color: Color,
        perCodeLinesLabel: String,
        efficiencyValue: String
    ) -> some View {
        VStack(alignment: .center, spacing: 6) {
            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }

            let displayValue = title == "成本" ? formattedCost(value) : formattedTokens(value, useCompact: true)
            Text(displayValue)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .opacity(value > 0 ? 1.0 : 0.5)
                .frame(maxWidth: .infinity)

            HStack(spacing: 4) {
                Spacer()
                Text(efficiencyValue)
                    .font(.system(size: 12))
                    .foregroundColor(color.opacity(0.9))
                Text(perCodeLinesLabel)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func formattedCost(_ cost: Double) -> String {
        return String(format: "$%.2f", cost)
    }

    private func formattedTokens(_ tokens: Double, useCompact: Bool = false) -> String {
        if useCompact {
            let intValue = Int(tokens)
            if intValue >= 1_000_000 {
                return String(format: "%.1fM", Double(intValue) / 1_000_000)
            } else if intValue >= 1_000 {
                return String(format: "%.1fK", Double(intValue) / 1_000)
            }
            return String(format: "%.0f", intValue)
        } else {
            let intValue = Int(tokens)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return formatter.string(from: NSNumber(value: intValue)) ?? String(format: "%.0f", tokens)
        }
    }

    private func formatCompactTokens(_ tokens: Double) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", tokens / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", tokens / 1_000)
        } else {
            return String(format: "%.0f", tokens)
        }
    }

    private func automationGaugePanel(level: Double) -> some View {
        VStack(alignment: .center, spacing: 6) {
            HStack {
                Spacer()
                Image(systemName: "autostartstop")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
                Spacer()
            }

            Text(String(format: "%.0f%%", level))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(automationLevelColor(level))

            Text(L10n.consumptionAutomationLevel)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func automationLevelColor(_ level: Double) -> Color {
        if level < 30 {
            return .red
        } else if level < 60 {
            return .yellow
        } else {
            return .green
        }
    }
}
