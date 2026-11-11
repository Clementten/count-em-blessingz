import SwiftUI

struct LegendList: View {
    @Environment(\.theme) private var theme
    let groups: [InsightGroup]
    let currency: String
    let hideAmounts: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                HStack(spacing: 10) {
                    Circle().fill(theme.chart[index % theme.chart.count]).frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                    Text(group.label).font(theme.bodyFont(15, .medium)).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("\(group.percent)%").font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
                    Text(hideAmounts ? "••••" : MoneyFormatter.format(group.value, currency: currency))
                        .font(theme.bodyFont(14, .semibold)).foregroundStyle(theme.amountColor)
                        .frame(minWidth: 70, alignment: .trailing)
                        .blur(radius: hideAmounts ? 4 : 0)
                        .privacySensitive()
                }
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(theme.rowDivider).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
