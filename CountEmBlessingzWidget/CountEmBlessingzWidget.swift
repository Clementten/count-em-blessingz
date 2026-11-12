import WidgetKit
import SwiftUI
import SwiftData

struct PotEntry: TimelineEntry {
    let date: Date
    let total: Decimal
    let goal: Decimal
    let currency: String
    let hideAmounts: Bool
    let themeID: String

    static let sample = PotEntry(date: .now, total: 9_776, goal: 20_000, currency: "MYR", hideAmounts: false, themeID: "jade")
}

struct PotProvider: TimelineProvider {
    func placeholder(in context: Context) -> PotEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (PotEntry) -> Void) {
        completion(context.isPreview ? .sample : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PotEntry>) -> Void) {
        // The app reloads timelines after every change; the hourly refresh is only a safety net.
        completion(Timeline(entries: [load()], policy: .after(Date().addingTimeInterval(3600))))
    }

    /// Reads the shared store read-only. Anything unreadable shows an empty pot rather than failing.
    private func load() -> PotEntry {
        guard let container = try? SharedStore.makeContainer(readOnly: true) else {
            return PotEntry(date: .now, total: 0, goal: 20_000, currency: "MYR", hideAmounts: false, themeID: "jade")
        }
        let context = ModelContext(container)
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first ?? AppSettings()
        let blessings = (try? context.fetch(FetchDescriptor<Blessing>())) ?? []
        return PotEntry(
            date: .now, total: blessings.reduce(0) { $0 + $1.amount }, goal: settings.goal,
            // The app lock must not be bypassed by a widget: with Face ID lock on, the total stays hidden.
            currency: settings.currencyCode, hideAmounts: settings.hideAmounts || settings.faceIDEnabled, themeID: settings.themeID
        )
    }
}

struct PotWidgetView: View {
    let entry: PotEntry
    private var theme: AppTheme { Themes.theme(id: entry.themeID) }

    private var progress: Double {
        guard entry.goal > 0 else { return 0 }
        // Geometry only (bar width and percent label).
        return min(1, NSDecimalNumber(decimal: entry.total / entry.goal).doubleValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(theme.title(theme.potLabel))
                .font(theme.bodyFont(11, .semibold)).foregroundStyle(theme.heroLabel)
            Text(entry.hideAmounts ? "••••" : MoneyFormatter.format(entry.total, currency: entry.currency))
                .font(theme.displayFont(26, .bold)).foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.5).lineLimit(1)
            Spacer(minLength: 0)
            ProgressView(value: progress).tint(theme.accent)
            Text("\(Int(progress * 100))% of goal")
                .font(theme.bodyFont(11, .regular)).foregroundStyle(theme.textMuted)
        }
        .containerBackground(theme.background, for: .widget)
        .accessibilityElement(children: .combine)
    }
}

struct PotWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HoneypotWidget", provider: PotProvider()) { entry in
            PotWidgetView(entry: entry)
        }
        .configurationDisplayName("Honeypot")
        .description("Your honeypot total and goal progress.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct CountEmBlessingzWidgetBundle: WidgetBundle {
    var body: some Widget { PotWidget() }
}
