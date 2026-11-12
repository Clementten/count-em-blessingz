import SwiftUI

/// Top three in order 2, 1, 3.
struct PodiumView: View {
    @Environment(\.theme) private var theme
    let top: [RankedBlesser]          // up to 3, already ranked
    let currency: String
    let hideAmounts: Bool
    let onSelect: (Blesser) -> Void

    private var displayOrder: [RankedBlesser] {
        let byRank = Dictionary(uniqueKeysWithValues: top.map { ($0.rank, $0) })
        return [2, 1, 3].compactMap { byRank[$0] }
    }

    private func height(_ rank: Int) -> CGFloat { rank == 1 ? 120 : rank == 2 ? 92 : 72 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(displayOrder) { entry in
                Button { onSelect(entry.blesser) } label: {
                    VStack(spacing: 6) {
                        AvatarView(name: entry.blesser.name, size: entry.rank == 1 ? 52 : 44)
                        Text(entry.blesser.name).font(theme.bodyFont(13, .semibold)).foregroundStyle(theme.textPrimary)
                            .lineLimit(2).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        Text(hideAmounts ? "••••" : MoneyFormatter.format(entry.total, currency: currency))
                            .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.amountColor)
                            .blurIf(hideAmounts, radius: 4).privacySensitive()
                        Text("#\(entry.rank)")
                            .font(theme.displayFont(26, .bold)).foregroundStyle(theme.onAccent)
                            .frame(maxWidth: .infinity, minHeight: height(entry.rank))
                            .background(theme.accent, in: RoundedRectangle(cornerRadius: theme.controlRadius))
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rank \(entry.rank), \(entry.blesser.name)")
            }
        }
    }
}
