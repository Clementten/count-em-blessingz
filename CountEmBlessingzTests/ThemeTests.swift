import Testing
import SwiftUI
import UIKit
@testable import CountEmBlessingz

private func luminance(_ color: Color) -> Double {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
    func lin(_ c: CGFloat) -> Double {
        let v = Double(c)
        return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

private func contrast(_ a: Color, _ b: Color) -> Double {
    let (l1, l2) = (luminance(a), luminance(b))
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
}

struct ThemeTests {
    @Test func threeThemesWithFiveChartColors() {
        #expect(Themes.all.map(\.id) == ["jade", "grand", "quiet"])
        #expect(Themes.all.allSatisfy { $0.chart.count == 5 && $0.tabTitles.count == 4 })
    }

    @Test func unknownIDFallsBackToJade() {
        #expect(Themes.theme(id: "nope").id == "jade")
    }

    @Test(arguments: Themes.all)
    func textContrastIsAtLeast4_5(theme: AppTheme) {
        let pairs: [(String, Color, Color)] = [
            ("primary/background", theme.textPrimary, theme.background),
            ("primary/surface", theme.textPrimary, theme.surface),
            ("muted/background", theme.textMuted, theme.background),
            ("muted/surface", theme.textMuted, theme.surface),
            ("onAccent/accent", theme.onAccent, theme.accent),
            ("accent/background", theme.accent, theme.background),
            ("danger/background", theme.danger, theme.background),
            ("tab text/tab bar", theme.tabBarText, theme.tabBarBackground),
            ("tab active/tab bar", theme.tabBarActive, theme.tabBarBackground),
            ("hero text/hero", theme.heroText, theme.heroBackground == .clear ? theme.background : theme.heroBackground),
            ("hero label/hero", theme.heroLabel, theme.heroBackground == .clear ? theme.background : theme.heroBackground),
            ("amount/background", theme.amountColor, theme.background),
            ("amount/surface", theme.amountColor, theme.surface),
            ("positive/background", theme.positive, theme.background),
            ("danger/surface", theme.danger, theme.surface),
        ]
        for (label, fg, bg) in pairs {
            #expect(contrast(fg, bg) >= 4.5, "\(theme.id) \(label) = \(contrast(fg, bg))")
        }
        // Avatar initials are decorative and set in bold at 14pt or more, which counts as large text (3:1).
        if theme.avatarStyle != .none {
            #expect(contrast(theme.avatarText, theme.avatarBackground) >= 3.0, "\(theme.id) avatar initials")
        }
    }

    @Test func bundledFontsLoad() {
        for family in FontFamily.all {
            for face in family.faces {
                #expect(UIFont(name: face.postScriptName, size: 12) != nil, "\(face.postScriptName) missing")
            }
        }
    }
}
