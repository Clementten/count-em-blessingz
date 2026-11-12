import SwiftUI

extension Color {
    /// `Color(hex: 0x0B3B2E)` — sRGB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum HeroBorder: Equatable {
    case none
    case single(CGFloat)
    case double(CGFloat)
}

enum FabShape: Equatable {
    case circle
    case roundedSquare
}

/// All visual decisions live here; views read tokens from `@Environment(\.theme)`.
struct AppTheme: Identifiable, Equatable {
    enum AvatarStyle { case circle, roundedSquare, none }
    enum RowStyle { case dividers, cards, hairlines }
    enum DonutStyle { case flat, outlined, thin }
    enum Effect { case coinRain, chapterCard, countUp }

    let id: String
    let name: String
    let blurb: String
    let colorScheme: ColorScheme        // fixed per theme; ignore the system appearance
    // Colors
    let background, surface, textPrimary, textMuted, accent, onAccent, line, positive, danger: Color
    let heroBackground, heroText, heroLabel, heroBorder: Color
    let tabBarBackground, tabBarText, tabBarActive: Color
    let chart: [Color]                  // exactly 5
    // Row, avatar, amount and FAB colors that the token table lists per theme
    let rowDivider: Color
    let avatarBackground, avatarText: Color
    let amountColor: Color
    let amountUsesDisplayFont: Bool
    let fabBorder: Color
    // Type
    let displayFont: (CGFloat, Font.Weight) -> Font
    let bodyFont: (CGFloat, Font.Weight) -> Font
    let uppercaseTitles: Bool
    // Shape
    let cornerRadius: CGFloat           // cards
    let controlRadius: CGFloat
    let avatarStyle: AvatarStyle
    let rowStyle: RowStyle
    let donutStyle: DonutStyle
    let donutThickness: CGFloat
    let heroBorderStyle: HeroBorder
    let fabShape: FabShape
    let fabBorderWidth: CGFloat
    // Copy
    let tabTitles: [String]             // [Home, Insights, Hall, Settings]
    let hallTitle: String
    let potLabel: String
    let recentTitle: String
    let effect: Effect

    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool { lhs.id == rhs.id }

    /// Applies the theme's title casing.
    func title(_ text: String) -> String {
        uppercaseTitles ? text.uppercased() : text
    }

    /// Font for an amount in a list row or hero.
    func amountFont(_ size: CGFloat) -> Font {
        amountUsesDisplayFont ? displayFont(size, .medium) : bodyFont(size, .bold)
    }
}
