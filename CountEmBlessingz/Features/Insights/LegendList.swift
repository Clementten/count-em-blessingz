import SwiftUI

struct LegendList: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    let groups: [InsightGroup]
    let currency: String
    let hideAmounts: Bool

    private func amountText(_ group: InsightGroup) -> some View {
        Text(hideAmounts ? "••••" : MoneyFormatter.format(group.value, currency: currency))
            .font(theme.bodyFont(14, .semibold)).foregroundStyle(theme.amountColor)
            .blurIf(hideAmounts, radius: 4)
            .privacySensitive()
    }

    /// One line normally; name on top and figures below at accessibility text sizes.
    @ViewBuilder private func row(_ group: InsightGroup, color: Color) -> some View {
        if typeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(color).frame(width: 12, height: 12).padding(.top, 8).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.label).font(theme.bodyFont(15, .medium)).foregroundStyle(theme.textPrimary)
                    HStack(spacing: 10) {
                        Text("\(group.percent)%").font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
                        amountText(group)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
        } else {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 12, height: 12).accessibilityHidden(true)
                Text(group.label).font(theme.bodyFont(15, .medium)).foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(group.percent)%").font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
                amountText(group).frame(minWidth: 70, alignment: .trailing)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                row(group, color: theme.chart[index % theme.chart.count])
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(theme.rowDivider).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
