#if DEBUG
import SwiftData
import Foundation

/// Preview and debug data matching the design mocks (currency MYR, total 9,776).
enum SeedData {
    private struct Row {
        let name: String
        let amount: Decimal
        let occasion: Occasion
        let date: String          // "yyyy-MM-dd HH:mm"
        var pending = false
    }

    private static let rows: [Row] = [
        Row(name: "Aunt Mei", amount: 888, occasion: .chineseNewYear, date: "2026-02-02 10:14"),
        Row(name: "Dad & Mum", amount: 1000, occasion: .chineseNewYear, date: "2026-02-01 20:30"),
        Row(name: "Dad & Mum", amount: 500, occasion: .birthday, date: "2026-01-14 08:02"),
        Row(name: "Uncle Tan", amount: 300, occasion: .wedding, date: "2025-12-09 19:40", pending: true),
        Row(name: "Wong & team", amount: 1200, occasion: .promotion, date: "2025-11-28 12:30"),
        Row(name: "Ah Kong", amount: 88, occasion: .justBecause, date: "2025-11-03 16:05"),
        Row(name: "Cousin Lin", amount: 1100, occasion: .wedding, date: "2025-10-05 15:00"),
        Row(name: "Aunt Mei", amount: 500, occasion: .birthday, date: "2025-08-21 09:00"),
        Row(name: "Cousin Lin", amount: 420, occasion: .hariRaya, date: "2025-04-01 11:00"),
        Row(name: "Uncle Tan", amount: 800, occasion: .wedding, date: "2025-03-15 17:20"),
        Row(name: "Aunt Mei", amount: 800, occasion: .chineseNewYear, date: "2025-02-10 10:00"),
        Row(name: "Ah Kong", amount: 880, occasion: .chineseNewYear, date: "2025-01-29 09:30"),
        Row(name: "Dad & Mum", amount: 600, occasion: .birthday, date: "2025-01-14 08:00"),
        Row(name: "Aunt Mei", amount: 300, occasion: .christmas, date: "2024-12-25 21:00"),
        Row(name: "Dad & Mum", amount: 400, occasion: .birthday, date: "2024-01-14 08:00"),
    ]

    /// In-memory container seeded with the mock data, for previews.
    @MainActor
    static func previewContainer(themeID: String = "jade") -> ModelContainer {
        let container = try! ModelContainer(
            for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        SeedData.insert(into: container.mainContext).themeID = themeID
        return container
    }

    /// Inserts the seed blessings and a settings row (onboarded, MYR).
    /// With `shiftToToday` every date moves forward by the same amount, so the newest sample entry is two days
    /// old. That makes screenshots show a believable "this month".
    @discardableResult
    static func insert(into context: ModelContext, shiftToToday: Bool = false) -> AppSettings {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let newest = rows.compactMap { formatter.date(from: $0.date) }.max() ?? .now
        let shift: TimeInterval = shiftToToday ? Date.now.timeIntervalSince(newest) - 2 * 86_400 : 0

        var blessers: [String: Blesser] = [:]
        for row in rows {
            let blesser = blessers[row.name] ?? {
                let created = Blesser(name: row.name)
                created.thankYouPending = false
                context.insert(created)
                blessers[row.name] = created
                return created
            }()
            if row.pending { blesser.thankYouPending = true }
            context.insert(Blessing(
                amount: row.amount, currencyCode: "MYR",
                date: (formatter.date(from: row.date) ?? .now).addingTimeInterval(shift),
                occasion: row.occasion, blesser: blesser
            ))
        }
        let settings = AppSettings()
        settings.hasOnboarded = true
        settings.goal = 20_000                  // the demo shows a goal; a real install starts with none
        context.insert(settings)
        return settings
    }
}
#endif
