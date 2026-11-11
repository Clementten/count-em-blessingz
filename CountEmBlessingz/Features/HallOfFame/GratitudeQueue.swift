import SwiftUI

struct GratitudeQueue: View {
    @Environment(\.theme) private var theme
    let pending: [Blesser]
    let onThank: (Blesser) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.title(String(localized: "Gratitude queue")))
                .font(theme.bodyFont(12, .semibold)).foregroundStyle(theme.textMuted)
            if pending.isEmpty {
                Text("Everyone has been thanked.")
                    .font(theme.bodyFont(14, .regular)).foregroundStyle(theme.textMuted)
            }
            ForEach(pending) { blesser in
                HStack {
                    AvatarView(name: blesser.name, size: 36)
                    Text(blesser.name).font(theme.bodyFont(15, .medium)).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Button("Mark thanked") { onThank(blesser) }
                        .font(theme.bodyFont(13, .semibold)).foregroundStyle(theme.accent)
                        .frame(minHeight: 44)
                }
            }
        }
    }
}
