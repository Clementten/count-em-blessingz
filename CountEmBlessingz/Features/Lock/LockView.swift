import SwiftUI

/// Shown while the app is locked. Tries to unlock automatically when it appears.
struct LockView: View {
    @Environment(\.theme) private var theme
    let lock: BiometricLock

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44)).foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text(theme.title("Locked"))
                .font(theme.displayFont(28, .bold)).foregroundStyle(theme.textPrimary)
            ThemedButton(title: String(localized: "Unlock")) { Task { await lock.unlock() } }
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .task { await lock.unlock() }
    }
}

/// Blank themed screen shown while the app is inactive, so snapshots hold no data.
struct PrivacyCoverView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        theme.background.ignoresSafeArea()
            .overlay {
                Text(theme.title("Count 'Em Blessingz"))
                    .font(theme.displayFont(24, .bold)).foregroundStyle(theme.textMuted)
            }
            .accessibilityHidden(true)
    }
}
