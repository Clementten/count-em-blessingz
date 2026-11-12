import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor private var retainedContainers: [ModelContainer] = []

private let base = Date(timeIntervalSince1970: 1_750_000_000)
private let us = Locale(identifier: "en_US")

/// After an import Home scrolls to the newest imported entry (BLUEPRINT section 18).
@MainActor
struct RevealImportedTests {
    private func makePhone() throws -> (ModelContext, ImportService) {
        let container = try ModelContainer(
            for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        retainedContainers.append(container)
        let context = container.mainContext
        let settings = AppSettings()
        settings.hasOnboarded = true
        settings.currencyCode = "MYR"
        context.insert(settings)
        try context.save()
        let service = ImportService(
            context: context,
            snapshotDirectory: FileManager.default.temporaryDirectory.appending(path: "snap-\(UUID().uuidString)")
        )
        return (context, service)
    }

    @discardableResult
    private func add(_ name: String, _ amount: Decimal, at date: Date, to context: ModelContext) throws -> Blessing {
        var draft = BlessingDraft()
        draft.name = name; draft.amountText = "\(amount)"; draft.date = date
        let blessing = try BlessingService(context: context).add(draft, currency: "MYR", goal: nil, locale: us).blessing
        try context.save()
        return blessing
    }

    @Test func resultNamesTheNewestImportedEntryByDate() throws {
        let (aContext, _) = try makePhone()
        let older = try add("Aunt Mei", 100, at: base, to: aContext)
        let newest = try add("Lin", 50, at: base.addingTimeInterval(86_400 * 5), to: aContext)
        let middle = try add("Uncle Ho", 20, at: base.addingTimeInterval(86_400 * 2), to: aContext)
        let file = try ExportService(context: aContext).exchangeFile(kind: .full)

        let (bContext, bService) = try makePhone()
        var plan = try bService.buildPlan(file: file)
        plan.selectAll()
        let result = try bService.commit(plan)

        #expect(result.importedCount == 3)
        #expect(result.newestImportedID == newest.id)
        #expect(result.newestImportedID != older.id && result.newestImportedID != middle.id)
        #expect(try bContext.fetch(FetchDescriptor<Blessing>()).contains { $0.id == result.newestImportedID })
    }

    @Test func onlySelectedEntriesCountTowardsTheNewest() throws {
        let (aContext, _) = try makePhone()
        let chosen = try add("Aunt Mei", 100, at: base, to: aContext)
        try add("Lin", 50, at: base.addingTimeInterval(86_400 * 5), to: aContext)
        let file = try ExportService(context: aContext).exchangeFile(kind: .full)

        let (_, bService) = try makePhone()
        var plan = try bService.buildPlan(file: file)
        plan.selectNone()
        let item = try #require(plan.items.first { $0.dto.id == chosen.id })
        plan.setSelected(item: item.id, true)
        let result = try bService.commit(plan)

        #expect(result.importedCount == 1)
        #expect(result.newestImportedID == chosen.id)
    }

    @Test func routerHoldsAOneShotRevealRequest() {
        let router = AppRouter()
        let id = UUID()
        #expect(router.revealBlessingID == nil)
        router.reveal(id)
        #expect(router.revealBlessingID == id)
        router.revealBlessingID = nil                       // Home clears it once it has scrolled
        #expect(router.revealBlessingID == nil)
    }
}
