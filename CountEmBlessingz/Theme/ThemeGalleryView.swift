#if DEBUG
import SwiftUI

/// DEBUG-only screen showing each theme's hero, row, button, avatar and donut.
struct ThemeGalleryView: View {
    @State private var themeID = Themes.jade.id

    private var theme: AppTheme { Themes.theme(id: themeID) }

    private let slices = [
        DonutSlice(id: "a", label: "Aunt Mei", value: 2488),
        DonutSlice(id: "b", label: "Dad & Mum", value: 2500),
        DonutSlice(id: "c", label: "Uncle Tan", value: 1100),
        DonutSlice(id: "d", label: "Cousin Lin", value: 1520),
        DonutSlice(id: "e", label: "Others", value: 2168),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Theme", selection: $themeID.animation(.easeInOut(duration: 0.25))) {
                    ForEach(Themes.all) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.segmented)

                Text(theme.title(theme.name)).font(theme.displayFont(28, .bold)).foregroundStyle(theme.textPrimary)
                HeroPotView(total: 9_776, monthDelta: 1_888, goal: 20_000, currency: "MYR")
                Text(theme.title(theme.recentTitle)).font(theme.bodyFont(13, .semibold)).foregroundStyle(theme.textMuted)
                ThemedRow(name: "Aunt Mei", subtitle: "Chinese New Year · 2 Feb, 10:14", amount: "+888")
                ThemedRow(name: "Uncle Tan", subtitle: "Wedding · thank-you pending", amount: "+300")
                HStack { AvatarView(name: "Dad & Mum"); ThemedButton(title: "Add blessing") {} }
                ThemedCard {
                    DonutChart(slices: slices).frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .background(theme.background.ignoresSafeArea())
        .themed(theme)
    }
}

#Preview("Jade") { ThemeGalleryView() }
#endif
