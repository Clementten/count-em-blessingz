import SwiftUI
import Charts

struct DonutSlice: Identifiable {
    let id: String
    let label: String
    let value: Decimal
}

struct DonutChart: View {
    @Environment(\.theme) private var theme
    let slices: [DonutSlice]
    var size: CGFloat = 200
    var centerText: String?

    private var innerRatio: Double { max(0.3, 1 - Double(theme.donutThickness) / Double(size / 2)) }

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                // Angle geometry only; money stays Decimal everywhere else.
                angle: .value("Amount", NSDecimalNumber(decimal: slice.value).doubleValue),
                innerRadius: .ratio(innerRatio),
                angularInset: theme.donutStyle == .outlined ? 2 : 1
            )
            .foregroundStyle(by: .value("Group", slice.label))
        }
        .chartForegroundStyleScale(
            domain: slices.map(\.label),
            range: slices.indices.map { theme.chart[$0 % theme.chart.count] }
        )
        .chartLegend(.hidden)
        .frame(width: size, height: size)
        .overlay {
            if let centerText {
                Text(centerText)
                    .font(theme.displayFont(22, .bold)).foregroundStyle(theme.textPrimary)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)          // it sits in a fixed-size ring
                    .frame(width: size * innerRatio * 0.8)
                    .privacySensitive()
            }
        }
        .overlay {
            if theme.donutStyle == .outlined {
                Circle().stroke(theme.line, lineWidth: 2)
                Circle().stroke(theme.line, lineWidth: 2)
                    .frame(width: size * innerRatio, height: size * innerRatio)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private var summary: String {
        let total = slices.reduce(Decimal(0)) { $0 + $1.value }
        guard total > 0 else { return String(localized: "No data") }
        return slices.map { slice in
            let pct = NSDecimalNumber(decimal: slice.value / total * 100).intValue
            return "\(slice.label) \(pct)%"
        }.joined(separator: ", ")
    }
}
