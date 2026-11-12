import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = Themes.jade
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    /// Injects the theme and forces its color scheme.
    func themed(_ theme: AppTheme) -> some View {
        environment(\.theme, theme)
            .preferredColorScheme(theme.colorScheme)
            .tint(theme.accent)
    }
}
