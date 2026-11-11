import SwiftUI

struct HeroPotView: View {
    @Environment(\.theme) private var theme
    let total: Decimal
    let monthDelta: Decimal
    let goal: Decimal
    let currency: String
    var hideAmounts = false

    private var progress: Double {
        guard goal > 0 else { return 0 }
        // Geometry only (bar width and percent label), never stored as money.
        return min(1, NSDecimalNumber(decimal: total / goal).doubleValue)
    }

    private func money(_ value: Decimal) -> String {
        hideAmounts ? "••••" : MoneyFormatter.format(value, currency: currency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.title(theme.potLabel))
                .font(theme.bodyFont(13, .semibold)).foregroundStyle(theme.heroLabel)
            CountUpText(text: money(total), value: total, animated: theme.effect == .countUp)
                .font(theme.displayFont(44, .bold)).foregroundStyle(theme.heroText)
                .minimumScaleFactor(0.6).lineLimit(1)
                .blur(radius: hideAmounts ? 6 : 0)
                .privacySensitive()
            Text(monthDelta > 0
                 ? "+ \(money(monthDelta)) this month"
                 : String(localized: "No blessings yet this month"))
                .font(theme.bodyFont(14, .regular)).foregroundStyle(theme.heroText.opacity(0.85))
            ProgressView(value: progress)
                .tint(theme.accent)
            Text("\(Int(progress * 100))% of \(money(goal)) goal")
                .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.heroText.opacity(0.85))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.heroBackground, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay { heroBorder }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var heroBorder: some View {
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius)
        switch theme.heroBorderStyle {
        case .none:
            EmptyView()
        case .single(let width):
            shape.stroke(theme.heroBorder, lineWidth: width)
        case .double(let width):
            // Two thin lines with a gap, like CSS `border: double`.
            ZStack {
                shape.stroke(theme.heroBorder, lineWidth: width / 3)
                shape.inset(by: width * 2 / 3).stroke(theme.heroBorder, lineWidth: width / 3)
            }
        }
    }
}
