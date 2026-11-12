import SwiftUI

/// Themed card rendered to an image for sharing. Fixed size so the image is consistent.
struct YearReviewCard: View {
    @Environment(\.theme) private var theme
    let review: YearReview
    let currency: String
    var hideAmounts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(theme.title(String(localized: "\(String(review.year)) in blessings")))
                .font(theme.displayFont(26, .bold)).foregroundStyle(theme.heroText)
                .fixedSize(horizontal: false, vertical: true)
            Text(hideAmounts ? "••••" : MoneyFormatter.format(review.total, currency: currency))
                .font(theme.displayFont(44, .bold)).foregroundStyle(theme.heroText)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text("\(review.count) blessings").font(theme.bodyFont(15, .medium)).foregroundStyle(theme.heroLabel)
            Divider().overlay(theme.heroLabel.opacity(0.5))
            if let name = review.topBlesserName, !name.isEmpty {
                line("Top blesser", name)
            }
            if let occasion = review.topOccasion {
                line("Top occasion", occasion.title)
            }
            Spacer(minLength: 0)
            Text(theme.potLabel).font(theme.bodyFont(12, .semibold)).foregroundStyle(theme.heroLabel)
        }
        .padding(24)
        .frame(width: 320, height: 400, alignment: .topLeading)
        .background(theme.heroBackground == .clear ? theme.background : theme.heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.heroLabel.opacity(0.6), lineWidth: 2))
    }

    private func line(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(theme.bodyFont(11, .semibold)).foregroundStyle(theme.heroLabel)
            Text(value).font(theme.displayFont(22, .bold)).foregroundStyle(theme.heroText)
        }
    }
}
