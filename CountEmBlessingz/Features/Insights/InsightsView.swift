import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.theme) private var theme
    let settings: AppSettings
    @Query private var blessings: [Blessing]

    @State private var mode: InsightMode = .person
    @State private var range: InsightRange = .allTime
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEnd = Date.now

    private var inRange: [Blessing] {
        InsightsLogic.filter(blessings, range: range, custom: min(customStart, customEnd)...max(customStart, customEnd))
    }

    var body: some View {
        let groups = InsightsLogic.groups(inRange, mode: mode)
        let total = HomeListLogic.total(inRange)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(theme.title("Insights"))
                    .font(theme.displayFont(28, .bold)).foregroundStyle(theme.textPrimary)
                Picker("Group by", selection: $mode.animation()) {
                    ForEach(InsightMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                rangeChips
                if range == .custom { customPickers }

                if groups.isEmpty {
                    Text("No blessings in this range.")
                        .font(theme.bodyFont(15, .regular)).foregroundStyle(theme.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    DonutChart(
                        slices: groups.map { DonutSlice(id: $0.id, label: $0.label, value: $0.value) },
                        centerText: settings.hideAmounts ? "••••" : MoneyFormatter.format(total, currency: settings.currencyCode)
                    )
                    .frame(maxWidth: .infinity)
                    LegendList(groups: groups, currency: settings.currencyCode, hideAmounts: settings.hideAmounts)
                    if let fact = InsightsLogic.topOccasionFact(inRange) {
                        ThemedCard {
                            Text("\(fact.occasion.title) brought in \(fact.percent)% of your honeypot.")
                                .font(theme.bodyFont(15, .medium)).foregroundStyle(theme.textPrimary)
                        }
                    }
                }
            }
            .padding(20)
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
    }

    private var rangeChips: some View {
        HStack(spacing: 8) {
            ForEach(InsightRange.allCases) { option in
                let selected = range == option
                Button { range = option } label: {
                    Text(option.title).font(theme.bodyFont(13, .medium))
                        .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .background(selected ? theme.accent : theme.surface,
                                    in: RoundedRectangle(cornerRadius: theme.controlRadius))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var customPickers: some View {
        HStack {
            DatePicker("From", selection: $customStart, displayedComponents: .date)
            DatePicker("To", selection: $customEnd, displayedComponents: .date)
        }
        .font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textPrimary)
    }
}

#if DEBUG
#Preview("Jade") { previewInsights("jade") }
#Preview("Grand") { previewInsights("grand") }
#Preview("Quiet") { previewInsights("quiet") }

@MainActor private func previewInsights(_ id: String) -> some View {
    let container = SeedData.previewContainer(themeID: id)
    let settings = (try? container.mainContext.fetch(FetchDescriptor<AppSettings>()))?.first ?? AppSettings()
    let theme = Themes.theme(id: id)
    return InsightsView(settings: settings)
        .background(theme.background)
        .themed(theme)
        .modelContainer(container)
}
#endif
