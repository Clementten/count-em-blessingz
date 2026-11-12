import SwiftUI

struct BlessingRow: View {
    let blessing: Blessing
    let hideAmounts: Bool

    private var subtitle: String {
        let when = StampFormatter.string(blessing.date)
        var text = "\(blessing.occasion.title) · \(when)"
        if blessing.blesser?.thankYouPending == true { text += " · " + String(localized: "thank-you pending") }
        return text
    }

    var body: some View {
        ThemedRow(
            name: blessing.blesser?.name ?? "",
            subtitle: subtitle,
            amount: "+" + MoneyFormatter.plain(blessing.amount),
            hideAmount: hideAmounts
        )
    }
}
