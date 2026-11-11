import SwiftUI

struct VibeStep: View {
    @Environment(\.theme) private var theme
    @Binding var themeID: String
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(theme.title("Pick a vibe"))
                .font(theme.displayFont(30, .bold)).foregroundStyle(theme.textPrimary)
            ForEach(Themes.all) { option in
                VibeCard(option: option, selected: option.id == themeID) {
                    withAnimation(.easeInOut(duration: 0.25)) { themeID = option.id }
                }
            }
            Spacer(minLength: 0)
            ThemedButton(title: String(localized: "Start counting"), action: onFinish)
        }
        .padding(20)
    }
}

/// A selectable vibe card. Drawn in the *option's* colors so each card previews itself.
struct VibeCard: View {
    @Environment(\.theme) private var current
    let option: AppTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(option.name).font(option.displayFont(22, .bold)).foregroundStyle(option.textPrimary)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(option.accent)
                    }
                }
                Text(option.blurb).font(option.bodyFont(13, .regular)).foregroundStyle(option.textMuted)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 0) {
                    ForEach(option.chart.indices, id: \.self) { option.chart[$0] }
                }
                .frame(height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(option.surface, in: RoundedRectangle(cornerRadius: option.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: option.cornerRadius)
                    .stroke(selected ? current.accent : option.line, lineWidth: selected ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
