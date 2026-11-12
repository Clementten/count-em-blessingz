#if DEBUG
import SwiftUI
import SwiftData

/// A hand-built import that shows every status, for previews and the `-demoImport` launch argument.
enum ImportReviewSamples {
    private static let t0 = Date(timeIntervalSince1970: 1_750_000_000)
    private static let day: TimeInterval = 86_400

    @MainActor
    static func model(currency: String = "MYR", fileCurrency: String = "MYR") -> ImportReviewModel {
        let localMei = LocalPerson(id: UUID(), name: "Aunt Mei")
        let localLin = LocalPerson(id: UUID(), name: "Aunt Lin")
        let updatedID = UUID(), olderID = UUID()
        func local(_ person: LocalPerson, _ amount: Decimal, _ days: Double, id: UUID = UUID(), note: String = "", updated: Double = 0) -> LocalEntry {
            LocalEntry(id: id, blesserID: person.id, amount: amount, currencyCode: currency, date: t0.addingTimeInterval(days * day),
                       occasion: Occasion.birthday.rawValue, method: "cash", note: note, updatedAt: t0.addingTimeInterval(updated), photoFingerprint: nil)
        }
        let snapshot = LocalSnapshot(
            persons: [localMei, localLin],
            entries: [
                local(localMei, 500, 10, id: updatedID, note: "Hong bao", updated: 10 * day),
                local(localMei, 300, 20, id: olderID, updated: 20 * day),
                local(localMei, 888, 40),
                local(localLin, 120, 5),
            ]
        )

        let meiFile = UUID(), linFile = UUID(), weiFile = UUID()
        func dto(_ person: UUID, _ amount: Decimal, _ days: Double, id: UUID = UUID(), occasion: String = Occasion.birthday.rawValue,
                 note: String = "", updated: Double = 0) -> ExchangeFile.BlessingDTO {
            .init(id: id, blesserID: person, amount: amount, currencyCode: fileCurrency, date: t0.addingTimeInterval(days * day),
                  occasion: occasion, method: "cash", note: note, updatedAt: t0.addingTimeInterval(updated))
        }
        let file = ExchangeFile(
            schemaVersion: 2, exportedAt: t0.addingTimeInterval(60 * day), exportedBy: "Dad's phone", deviceID: UUID(),
            currencyCode: fileCurrency, kind: .full,
            blessers: [
                .init(id: meiFile, name: "aunt  mei", nameKey: "aunt  mei"),
                .init(id: linFile, name: "Aunty Lin", nameKey: "aunty lin"),
                .init(id: weiFile, name: "Cousin Wei", nameKey: "cousin wei"),
            ],
            blessings: [
                dto(meiFile, 888, 41, occasion: Occasion.chineseNewYear.rawValue),                                  // possible duplicate
                dto(meiFile, 200, 55, occasion: Occasion.christmas.rawValue, note: "Merry Christmas!"),             // new
                dto(meiFile, 650, 10, id: updatedID, note: "Hong bao, topped up", updated: 50 * day), // updated
                dto(meiFile, 300, 20, id: olderID, updated: 20 * day),                              // already in pot
                dto(linFile, 90, 58, occasion: Occasion.justBecause.rawValue),                                      // new, similar person
                dto(weiFile, 75, 30, occasion: Occasion.wedding.rawValue),                                          // new person
                dto(weiFile, 75, 31, occasion: Occasion.wedding.rawValue),                                          // duplicate within the file
            ]
        )
        return ImportReviewModel(plan: ImportPlan(file: file, localCurrency: currency, local: snapshot))
    }
}

@MainActor
private func previewReview(_ id: String, fileCurrency: String = "MYR") -> some View {
    let theme = Themes.themes(id)
    let container = SeedData.previewContainer(themeID: id)
    let settings = (try? container.mainContext.fetch(FetchDescriptor<AppSettings>()))?.first ?? AppSettings()
    return ImportReviewView(model: ImportReviewSamples.model(fileCurrency: fileCurrency), settings: settings)
        .background(theme.background)
        .themed(theme)
        .environment(AppRouter())
        .environment(ToastCenter())
        .modelContainer(container)
}

private extension Themes {
    static func themes(_ id: String) -> AppTheme { theme(id: id) }
}

#Preview("Jade") { previewReview("jade") }
#Preview("Grand") { previewReview("grand") }
#Preview("Quiet") { previewReview("quiet") }
#Preview("Jade, USD file") { previewReview("jade", fileCurrency: "USD") }
#endif
