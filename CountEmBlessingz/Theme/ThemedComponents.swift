import SwiftUI

struct ThemedCard<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.line, lineWidth: 1)
            )
    }
}

struct ThemedButton: View {
    @Environment(\.theme) private var theme
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(theme.title(title))
                .font(theme.bodyFont(16, .semibold))
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(theme.accent, in: RoundedRectangle(cornerRadius: theme.controlRadius))
        }
        .buttonStyle(.plain)
    }
}

/// Initials in the theme's avatar shape; renders nothing when the theme hides avatars.
struct AvatarView: View {
    @Environment(\.theme) private var theme
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let letters = name.split(separator: " ").filter { $0.first?.isLetter == true }.prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    var body: some View {
        switch theme.avatarStyle {
        case .none:
            EmptyView()
        case .circle:
            label.background(theme.avatarBackground, in: Circle())
        case .roundedSquare:
            label.background(theme.avatarBackground, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var label: some View {
        Text(initials)
            .font(theme.bodyFont(size * 0.4, .semibold))
            .foregroundStyle(theme.avatarText)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A list row: avatar, title and subtitle, amount on the right. Styling follows `rowStyle`.
struct ThemedRow: View {
    @Environment(\.theme) private var theme
    let name: String
    let subtitle: String
    let amount: String
    var hideAmount = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: name)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(theme.bodyFont(16, .semibold)).foregroundStyle(theme.textPrimary)
                Text(subtitle).font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
            }
            Spacer(minLength: 8)
            Text(hideAmount ? "••••" : amount).font(theme.amountFont(18)).foregroundStyle(theme.amountColor)
                .blur(radius: hideAmount ? 4 : 0)
                .privacySensitive()
        }
        .padding(.vertical, theme.rowStyle == .cards ? 12 : 10)
        .padding(.horizontal, theme.rowStyle == .cards ? 12 : 0)
        .frame(minHeight: 44)
        .background {
            if theme.rowStyle == .cards {
                RoundedRectangle(cornerRadius: 4).fill(theme.surface)
            }
        }
        .overlay(alignment: .bottom) {
            if theme.rowStyle != .cards {
                Rectangle().fill(theme.rowDivider).frame(height: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
