import SwiftUI

struct MilestoneStrip: View {
    @Environment(\.theme) private var theme
    let total: Decimal

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MilestoneService.fixedThresholds, id: \.self) { threshold in
                let reached = HallLogic.isReached(threshold, total: total)
                VStack(spacing: 4) {
                    Image(systemName: reached ? "checkmark.seal.fill" : "lock.fill")
                    Text(MilestoneService.shortLabel(threshold)).font(theme.bodyFont(14, .bold))
                    Text(reached ? "Reached" : "Locked").font(theme.bodyFont(11, .regular))
                }
                .foregroundStyle(reached ? theme.onAccent : theme.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(reached ? theme.accent : theme.surface,
                            in: RoundedRectangle(cornerRadius: theme.controlRadius))
                .accessibilityElement(children: .combine)
            }
        }
    }
}
