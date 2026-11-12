import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor private var retained: [ModelContainer] = []

private let t0 = Date(timeIntervalSince1970: 1_750_000_000)
private let day: TimeInterval = 86_400

@MainActor
struct ImportFilterTests {
    private let some = LocalEntry(id: UUID(), blesserID: UUID(), amount: 1, currencyCode: "MYR", date: t0, occasion: "x",
                                  method: "cash", note: "", updatedAt: t0, photoFingerprint: nil)

    @Test func filtersMatchTheirStatuses() {
        let statuses: [EntryStatus] = [.new, .updated(some), .possibleDuplicate(some), .duplicateWithinFile(of: UUID()), .alreadyImported(some)]
        func matching(_ filter: ImportFilter) -> [Bool] { statuses.map(filter.matches) }
        #expect(matching(.all) == [true, true, true, true, true])
        #expect(matching(.new) == [true, true, false, false, false])                 // "New" includes updates
        #expect(matching(.possibleDuplicates) == [false, false, true, true, false])
        #expect(matching(.alreadyInPot) == [false, false, false, false, true])
    }

    @Test func searchAndFilterNarrowTheList() {
        let model = ImportReviewSamples.model()
        #expect(model.visiblePersons.count == 3)
        let mei = model.plan.persons.first { $0.name.contains("mei") }!
        #expect(model.visibleItems(of: mei).count == 4)

        model.filter = .possibleDuplicates
        #expect(model.visibleItems(of: mei).count == 1)
        #expect(model.visiblePersons.map(\.name).sorted() == ["Cousin Wei", "aunt  mei"])   // Wei has the in-file duplicate

        model.filter = .all
        model.search = "christmas"
        #expect(model.visibleItems(of: mei).map(\.dto.note) == ["Merry Christmas!"])
        #expect(model.visiblePersons.count == 1)

        model.search = "COUSIN"                                                           // person name, any case
        #expect(model.visiblePersons.map(\.name) == ["Cousin Wei"])

        model.search = "hong bao"                                                          // note
        #expect(model.visibleItems(of: mei).count == 1)

        model.search = "zzz"
        #expect(model.visiblePersons.isEmpty)
    }

    @Test func filtersNeverChangeWhatIsSelected() {
        let model = ImportReviewModel(plan: ImportReviewSamples.model().plan)
        let before = model.plan.selectedCount
        model.filter = .alreadyInPot
        model.search = "x"
        #expect(model.plan.selectedCount == before)
    }
}

@MainActor
struct ImportReviewTextTests {
    @Test func hiddenAmountsAreMasked() {
        #expect(ImportMoney(currency: "MYR", hidden: true).text(888) == "••••")
        #expect(ImportMoney(currency: "MYR", hidden: false).text(888).contains("888"))
    }

    @Test(arguments: [(0.5, "less than a day apart"), (1.2, "1 day apart"), (3.0, "3 days apart"), (3.9, "3 days apart")])
    func daysApart(days: Double, expected: String) {
        #expect(ImportStatusText.apart(t0, t0.addingTimeInterval(days * day)) == expected)
        #expect(ImportStatusText.apart(t0.addingTimeInterval(days * day), t0) == expected)     // either direction
    }

    @Test func changedFieldsAreListed() {
        let old = LocalEntry(id: UUID(), blesserID: UUID(), amount: 50, currencyCode: "MYR", date: t0, occasion: "birthday",
                             method: "cash", note: "", updatedAt: t0, photoFingerprint: nil)
        let new = IncomingEntry(id: old.id, blesserID: UUID(), amount: 80, date: t0.addingTimeInterval(day), occasion: "birthday",
                                method: "bank", note: "hi", updatedAt: t0, photoFingerprint: 7)
        #expect(ImportStatusText.changes(from: old, to: new) == ["amount", "date", "method", "note", "photo"])
    }

    @Test func statusWordsAreSpokenForVoiceOver() {
        #expect(ImportStatusText.title(.new) == "new")
        #expect(ImportStatusText.title(.duplicateWithinFile(of: UUID())) == "duplicate within the file")
    }

    @Test func blessingCounts() {
        #expect(blessingCountText(1) == "1 blessing" && blessingCountText(3) == "3 blessings" && blessingCountText(0) == "0 blessings")
    }
}

@MainActor
struct ImportCoordinatorTests {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        retained.append(container)
        SeedData.insert(into: container.mainContext)
        try container.mainContext.save()
        return container.mainContext
    }

    private func file(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).blessingz")
        try Data(text.utf8).write(to: url)
        return url
    }

    @Test(arguments: [
        ("hello", "This isn't a Count 'Em Blessingz file."),
        ("{\"schemaVersion\":9}", "This file is from a newer version of the app."),
        ("{\"schemaVersion\":2}", "This file is damaged, so nothing was changed."),
        ("{\"schemaVersion\":1}", "This is an older backup. Use Restore from backup instead."),
    ])
    func badFilesShowAFriendlyMessageAndChangeNothing(text: String, message: String) async throws {
        let ctx = try context()
        let before = try ctx.fetchCount(FetchDescriptor<Blessing>())
        let coordinator = ImportCoordinator()
        coordinator.receive(try file(text))
        await coordinator.process(context: ctx)
        #expect(coordinator.errorMessage == message)
        #expect(coordinator.session == nil && coordinator.pendingURL == nil && !coordinator.isLoading)
        #expect(try ctx.fetchCount(FetchDescriptor<Blessing>()) == before && !ctx.hasChanges)
    }

    @Test func missingFileIsReported() async throws {
        let ctx = try context()
        let coordinator = ImportCoordinator()
        coordinator.receive(FileManager.default.temporaryDirectory.appending(path: "nope-\(UUID().uuidString).blessingz"))
        await coordinator.process(context: ctx)
        #expect(coordinator.errorMessage == "That file couldn't be read." && coordinator.session == nil)
    }

    @Test func aGoodFileOpensTheReviewWithoutWritingAnything() async throws {
        let ctx = try context()
        let other = try ExportService(context: ctx).exchangeFile(kind: .full)
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).blessingz")
        try ExchangeFileCodec.encode(other).write(to: url)

        let coordinator = ImportCoordinator()
        coordinator.receive(url)
        await coordinator.process(context: ctx)
        let session = try #require(coordinator.session)
        #expect(coordinator.errorMessage == nil)
        #expect(session.plan.summary.total == 15 && session.plan.summary.alreadyInPot == 15)   // it is this very pot
        #expect(!ctx.hasChanges)
    }

    @Test func nothingHappensWithoutAFile() async throws {
        let coordinator = ImportCoordinator()
        await coordinator.process(context: try context())
        #expect(coordinator.session == nil && coordinator.errorMessage == nil)
    }
}
