import SwiftUI

/// Full-screen dim with a centered "CHAPTER 10k / The pot grows" card, shown about 2.2 seconds.
struct ChapterCardView: View {
    @Environment(\.theme) private var theme
    let milestone: Decimal
    var hideAmounts = false
    let onFinish: () -> Void

    private var heading: String {
        hideAmounts ? String(localized: "A NEW CHAPTER") : "CHAPTER \(MilestoneService.shortLabel(milestone))"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 8) {
                Text(heading)
                    .font(theme.displayFont(30, .bold)).foregroundStyle(theme.heroText)
                Text("The pot grows")
                    .font(theme.bodyFont(16, .medium)).foregroundStyle(theme.heroLabel)
            }
            .padding(.horizontal, 36).padding(.vertical, 28)
            .background(theme.heroBackground, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay {
                let shape = RoundedRectangle(cornerRadius: theme.cornerRadius)
                shape.stroke(theme.heroBorder, lineWidth: 1.5)
                shape.inset(by: 6).stroke(theme.heroBorder, lineWidth: 1.5)
            }
            .transition(.scale.combined(with: .opacity))
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hideAmounts ? "A new chapter. The pot grows." : "Chapter \(MilestoneService.shortLabel(milestone)). The pot grows.")
        .task {
            try? await Task.sleep(for: .seconds(2.2))
            onFinish()
        }
    }
}
