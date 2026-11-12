import SwiftUI

struct MilestoneStrip: View {
    @Environment(\.theme) private var theme
    let total: Decimal
    var hideAmounts = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MilestoneService.fixedThresholds, id: \.self) { threshold in
                // With amounts hidden, which milestones are reached would reveal the pot's size.
                let reached = !hideAmounts && HallLogic.isReached(threshold, total: total)
                VStack(spacing: 4) {
                    Image(systemName: hideAmounts ? "eye.slash" : (reached ? "checkmark.seal.fill" : "lock.fill"))
                    Text(MilestoneService.shortLabel(threshold)).font(theme.bodyFont(14, .bold))
                    Text(hideAmounts ? "Hidden" : (reached ? "Reached" : "Locked")).font(theme.bodyFont(11, .regular))
                }
                .foregroundStyle(reached ? theme.onAccent : theme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .frame(minHeight: 72)
                .background(reached ? theme.accent : theme.surface,
                            in: RoundedRectangle(cornerRadius: theme.controlRadius))
                .accessibilityElement(children: .combine)
            }
        }
    }
}
