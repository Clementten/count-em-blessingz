import SwiftUI

enum Themes {
    static let jade = AppTheme(
        id: "jade", name: "Jade & Gold", blurb: "Crazy Rich Asians: deep jade, gold leaf, lacquer red.",
        colorScheme: .dark,
        background: Color(hex: 0x0B3B2E), surface: Color(hex: 0x123F33),
        textPrimary: Color(hex: 0xF6EBCB), textMuted: Color(hex: 0xD9CDA8),
        accent: Color(hex: 0xD4AF37), onAccent: Color(hex: 0x06241B),
        line: Color(hex: 0x2A6B57), positive: Color(hex: 0x6FBF9B), danger: Color(hex: 0xFF9C8F),
        heroBackground: Color(hex: 0x123F33), heroText: Color(hex: 0xF6EBCB),
        heroLabel: Color(hex: 0xD4AF37), heroBorder: Color(hex: 0xD4AF37),
        tabBarBackground: Color(hex: 0x06241B), tabBarText: Color(hex: 0xD9CDA8), tabBarActive: Color(hex: 0xD4AF37),
        chart: [0xD4AF37, 0xC8362C, 0x6FBF9B, 0xF6EBCB, 0x4F8F78].map { Color(hex: $0) },
        rowDivider: Color(hex: 0x1F5A49),
        avatarBackground: Color(hex: 0xC8362C), avatarText: Color(hex: 0xF6EBCB),
        amountColor: Color(hex: 0xD4AF37), amountUsesDisplayFont: true,
        fabBorder: .clear,
        displayFont: { FontFamily.playfair.font(size: $0, weight: $1) },
        bodyFont: { FontFamily.montserrat.font(size: $0, weight: $1) },
        uppercaseTitles: false,
        cornerRadius: 20, controlRadius: 12,
        avatarStyle: .circle, rowStyle: .dividers,
        donutStyle: .flat, donutThickness: 26,
        heroBorderStyle: .single(1), fabShape: .circle, fabBorderWidth: 0,
        tabTitles: ["Blessings", "Insights", "Hall of Fame", "Settings"],
        hallTitle: "Hall of Fame", potLabel: "The Honeypot", recentTitle: "Recent blessings",
        effect: .coinRain
    )

    static let grand = AppTheme(
        id: "grand", name: "The Grand Ledger", blurb: "Wes Anderson: candy pink, plum and a touch of theatre.",
        colorScheme: .light,
        background: Color(hex: 0xFFE9EE), surface: Color(hex: 0xF7C6D0),
        textPrimary: Color(hex: 0x3D1D40), textMuted: Color(hex: 0x5A2D55),
        accent: Color(hex: 0xB3223B), onAccent: Color(hex: 0xFFE9EE),
        line: Color(hex: 0x3D1D40), positive: Color(hex: 0x1F6B45), danger: Color(hex: 0xA3162B),
        heroBackground: Color(hex: 0x5B2A5E), heroText: Color(hex: 0xFFE9EE),
        heroLabel: Color(hex: 0xF7C6D0), heroBorder: Color(hex: 0xF7C6D0),
        tabBarBackground: Color(hex: 0x5B2A5E), tabBarText: Color(hex: 0xF7C6D0), tabBarActive: Color(hex: 0xE8B04A),
        chart: [0xB3223B, 0xE8B04A, 0xA8D5BA, 0xB9A0D6, 0xF7C6D0].map { Color(hex: $0) },
        rowDivider: Color(hex: 0x3D1D40),
        avatarBackground: Color(hex: 0x5B2A5E), avatarText: Color(hex: 0xFFE9EE),
        amountColor: Color(hex: 0x3D1D40), amountUsesDisplayFont: false,
        fabBorder: Color(hex: 0x3D1D40),
        displayFont: { FontFamily.jost.font(size: $0, weight: $1) },
        bodyFont: { FontFamily.jost.font(size: $0, weight: $1) },
        uppercaseTitles: true,
        cornerRadius: 6, controlRadius: 4,
        avatarStyle: .roundedSquare, rowStyle: .cards,
        donutStyle: .outlined, donutThickness: 34,
        heroBorderStyle: .double(4), fabShape: .roundedSquare, fabBorderWidth: 3,
        tabTitles: ["Ledger", "Insights", "Hall of Fame", "Settings"],
        hallTitle: "Hall of Fame", potLabel: "The Honeypot", recentTitle: "Chapter one: recent guests",
        effect: .chapterCard
    )

    static let quiet = AppTheme(
        id: "quiet", name: "Quiet Fortune", blurb: "Succession: old money, muted brass, no shouting.",
        colorScheme: .dark,
        background: Color(hex: 0x15171A), surface: Color(hex: 0x1F2226),
        textPrimary: Color(hex: 0xEDE6D6), textMuted: Color(hex: 0xA9ADB5),
        accent: Color(hex: 0xB08D57), onAccent: Color(hex: 0x15171A),
        line: Color(hex: 0x3A3F46), positive: Color(hex: 0x8FA596), danger: Color(hex: 0xE59A9A),
        heroBackground: .clear, heroText: Color(hex: 0xEDE6D6),
        heroLabel: Color(hex: 0xB08D57), heroBorder: .clear,
        tabBarBackground: Color(hex: 0x0D0F11), tabBarText: Color(hex: 0xA9ADB5), tabBarActive: Color(hex: 0xEDE6D6),
        chart: [0xB08D57, 0xEDE6D6, 0x6F7F73, 0x5F6B7A, 0xA65A5A].map { Color(hex: $0) },
        rowDivider: Color(hex: 0x2A2E33),
        avatarBackground: .clear, avatarText: .clear,
        amountColor: Color(hex: 0xB08D57), amountUsesDisplayFont: true,
        fabBorder: .clear,
        displayFont: { FontFamily.cormorant.font(size: $0, weight: $1) },
        bodyFont: { FontFamily.inter.font(size: $0, weight: $1) },
        uppercaseTitles: false,
        cornerRadius: 2, controlRadius: 2,
        avatarStyle: .none, rowStyle: .hairlines,
        donutStyle: .thin, donutThickness: 10,
        heroBorderStyle: .none, fabShape: .circle, fabBorderWidth: 0,
        tabTitles: ["Ledger", "Insights", "Board", "Settings"],
        hallTitle: "The Board", potLabel: "Honeypot", recentTitle: "Recent",
        effect: .countUp
    )

    static let all: [AppTheme] = [jade, grand, quiet]

    static func theme(id: String) -> AppTheme {
        all.first { $0.id == id } ?? jade
    }
}
