import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor private var retained: [ModelContainer] = []

private let us = Locale(identifier: "en_US")
private let t0 = Date(timeIntervalSince1970: 1_750_000_000)
private let hour: TimeInterval = 3_600
private let day: TimeInterval = 86_400

/// One phone: its own in-memory store, its own snapshot folder.
@MainActor
private final class Phone {
    let context: ModelContext
    let snapshots: URL
    var clock: Date
    var service: ImportService

    init(label: String = "", currency: String = "MYR") throws {
        let container = try ModelContainer(
            for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        retained.append(container)
        context = container.mainContext
        let settings = AppSettings()
        settings.hasOnboarded = true
        settings.deviceLabel = label
        settings.currencyCode = currency
        context.insert(settings)
        try context.save()
        snapshots = FileManager.default.temporaryDirectory.appending(path: "snap-\(UUID().uuidString)")
        clock = Date.now
        service = ImportService(context: context, snapshotDirectory: snapshots)
        service.now = { [unowned self] in self.clock.addTimeInterval(1); return self.clock }
    }

    var settings: AppSettings { try! context.fetch(FetchDescriptor<AppSettings>())[0] }
    var blessings: [Blessing] { (try? context.fetch(FetchDescriptor<Blessing>())) ?? [] }
    var blessers: [Blesser] { (try? context.fetch(FetchDescriptor<Blesser>())) ?? [] }
    var total: Decimal { blessings.reduce(0) { $0 + $1.amount } }

    @discardableResult
    func add(_ name: String, _ amount: Decimal, at date: Date = t0, occasion: Occasion = .birthday, note: String = "") throws -> Blessing {
        var draft = BlessingDraft()
        draft.name = name; draft.amountText = "\(amount)"; draft.date = date; draft.occasion = occasion; draft.note = note
        let blessing = try BlessingService(context: context).add(draft, currency: settings.currencyCode, goal: nil, locale: us).blessing
        try context.save()
        return blessing
    }

    func edit(_ blessing: Blessing, amount: Decimal) throws {
        var draft = BlessingDraft(editing: blessing)
        draft.amountText = "\(amount)"
        try BlessingService(context: context).update(blessing, with: draft, locale: us)
        try context.save()
    }

    func share(_ kind: ExchangeFile.Kind = .full) throws -> ExchangeFile {
        try ExportService(context: context).exchangeFile(kind: kind)
    }

    /// Marks everything as shared, like tapping "Share changes since last export".
    func markShared() { settings.lastExportAt = .now }

    func plan(_ file: ExchangeFile) throws -> ImportPlan { try service.buildPlan(file: file) }

    func state() -> [String] {
        // Edit times are compared separately (files keep milliseconds only).
        blessings.map { "\($0.id)|\($0.blesser?.name ?? "")|\($0.amount)" }.sorted()
            + blessers.map { "P|\($0.id)|\($0.name)|\($0.thankYouPending)" }.sorted()
    }
}

// MARK: - Plan (reads only)

@MainActor
struct BuildPlanTests {
    @Test func buildingAPlanAndFiddlingWithItWritesNothing() throws {
        let a = try Phone(label: "A"), b = try Phone(label: "B")
        try a.add("Aunt Mei", 100); try a.add("Lin", 50)
        try b.add("Aunt Mei", 100, at: t0.addingTimeInterval(hour))
        let before = b.state()

        var plan = try b.plan(try a.share())
        plan.selectAll(); plan.selectNone(); plan.selectAllNew()
        if let person = plan.persons.first { plan.setMapping(person: person.id, .createNew) }

        #expect(!b.context.hasChanges)
        #expect(b.state() == before)                                    // "Cancel" is simply never committing
        #expect(!FileManager.default.fileExists(atPath: b.snapshots.path))          // no snapshot either
    }

    @Test func planDescribesTheFile() throws {
        let a = try Phone(label: "Dad's phone"), b = try Phone()
        try a.add("Aunt Mei", 100)
        let plan = try b.plan(try a.share())
        #expect(plan.source.exportedBy == "Dad's phone" && plan.source.fileCurrency == "MYR")
        #expect(plan.localCurrency == "MYR" && plan.currency == .notNeeded && plan.isReady)
        #expect(plan.summary == .init(total: 1, new: 1, updated: 0, possibleDuplicates: 0, alreadyInPot: 0))
    }

    @Test func badFilesGiveFriendlyErrorsAndChangeNothing() throws {
        let b = try Phone()
        try b.add("Aunt Mei", 100)
        let before = b.state()
        #expect(throws: ExportError.notABackup) { _ = try b.service.plan(from: Data("hello".utf8)) }
        #expect(throws: ExportError.unsupportedVersion(3)) { _ = try b.service.plan(from: Data("{\"schemaVersion\":3}".utf8)) }
        #expect(throws: ExportError.corrupt) { _ = try b.service.plan(from: Data("{\"schemaVersion\":2}".utf8)) }
        #expect(ExportError.notABackup.errorDescription == "This isn't a Count 'Em Blessingz file.")
        #expect(ExportError.unsupportedVersion(3).errorDescription == "This file is from a newer version of the app.")
        #expect(b.state() == before && !b.context.hasChanges)
    }
}

// MARK: - Commit

@MainActor
struct CommitTests {
    @Test func addsExactlySelectedEntriesAndOnlyTheNeededPeople() throws {
        let a = try Phone(label: "A"), b = try Phone()
        try a.add("Aunt Mei", 100, at: t0.addingTimeInterval(hour))       // looks like B's own entry
        try a.add("Aunt Mei", 200, at: t0.addingTimeInterval(10 * day))
        let lin = try a.add("Lin", 50)
        let tan = try a.add("Uncle Tan", 75)
        try b.add("Aunt Mei", 100, at: t0)                                // B's Aunt Mei is pending thank-you
        let mei = try #require(b.blessers.first)
        #expect(mei.thankYouPending)

        var plan = try b.plan(try a.share())
        #expect(plan.summary.possibleDuplicates == 1 && plan.summary.new == 3)
        plan.setSelected(item: tan.id, false)                              // Tan has no selected entry: must not be created

        let result = try b.service.commit(plan)
        #expect(result.addedCount == 2 && result.updatedCount == 0 && result.newPeopleCount == 1)   // Lin only
        #expect(Set(b.blessers.map(\.name)) == ["Aunt Mei", "Lin"])
        #expect(b.blessings.count == 3 && b.total == 350)
        #expect(!b.blessings.contains { $0.id == tan.id })

        let imported = try #require(b.blessings.first { $0.id == lin.id })
        #expect(imported.date == lin.date && imported.occasion == .birthday && imported.currencyCode == "MYR")
        #expect(abs(imported.updatedAt.timeIntervalSince(lin.updatedAt)) < 0.01)    // the file's edit time is kept
        #expect(imported.blesser?.id == lin.blesser?.id)                              // the file's person id is kept

        // No thank-you flags are created and Aunt Mei's stays as it was; so no reminder for imported people.
        #expect(try #require(b.blessers.first { $0.name == "Lin" }).thankYouPending == false)
        #expect(mei.thankYouPending)
        let reminders = ReminderPlan.items(for: b.blessers, days: 3, now: t0)
        #expect(reminders.count == 1 && reminders[0].name == "Aunt Mei")
    }

    @Test func similarNameStaysSeparateUnlessTheUserSaysSamePerson() throws {
        let a = try Phone(), b = try Phone()
        try a.add("Aunty Mei", 80)
        try b.add("Aunt Mei", 100)
        var plan = try b.plan(try a.share())
        let person = try #require(plan.persons.first)
        #expect(person.match == .similar(LocalPerson(id: b.blessers[0].id, name: "Aunt Mei")))
        #expect(person.mapping == .createNew)                              // default: keep separate

        var separate = plan
        try b.service.commit(separate)
        #expect(Set(b.blessers.map(\.name)) == ["Aunt Mei", "Aunty Mei"])

        // Fresh phone, this time "Same person".
        let c = try Phone()
        try c.add("Aunt Mei", 100)
        plan = try c.plan(try a.share())
        plan.setMapping(person: plan.persons[0].id, .existing(LocalPerson(id: c.blessers[0].id, name: "Aunt Mei")))
        try c.service.commit(plan)
        #expect(c.blessers.count == 1 && c.blessers[0].blessings.count == 2)
        separate.selectNone()
    }

    @Test func nothingSelectedAndUndecidedCurrencyAreRefusedWithoutChanges() throws {
        let a = try Phone(), b = try Phone(currency: "USD")
        try a.add("Lin", 50)
        var plan = try b.plan(try a.share())
        let before = b.state()
        #expect(plan.currency == .undecided && !plan.isReady)
        #expect(throws: ImportError.currencyUndecided) { try b.service.commit(plan) }
        plan.setCurrency(.importNumbers)
        plan.selectNone()
        #expect(throws: ImportError.nothingSelected) { try b.service.commit(plan) }
        #expect(b.state() == before && !b.context.hasChanges)
    }

    @Test func failingSnapshotAbortsBeforeAnyChange() throws {
        let a = try Phone(), b = try Phone()
        try a.add("Lin", 50)
        try Data().write(to: b.snapshots)                                 // a file where the folder should be
        let before = b.state()
        #expect(throws: (any Error).self) { try b.service.commit(try b.plan(try a.share())) }
        #expect(b.state() == before && !b.context.hasChanges)
    }

    @Test func updatedEntryOverwritesAndMovesPersonCleanly() throws {
        let a = try Phone(), b = try Phone()
        let entry = try a.add("Lin", 50)
        try b.service.commit(try b.plan(try a.share()))
        #expect(b.blessings.count == 1)

        try a.edit(entry, amount: 80)
        var draft = BlessingDraft(editing: entry); draft.name = "Cousin Lin"; draft.amountText = "80"
        try BlessingService(context: a.context).update(entry, with: draft, locale: us)

        var plan = try b.plan(try a.share())
        guard case .updated(let old) = try #require(plan.items.first).status else { Issue.record("expected updated"); return }
        #expect(old.amount == 50)
        plan.selectAll()
        let result = try b.service.commit(plan)
        #expect(result.updatedCount == 1 && result.addedCount == 0)
        #expect(b.blessings.count == 1 && b.blessings[0].amount == 80 && b.blessings[0].blesser?.name == "Cousin Lin")
        #expect(b.blessers.map(\.name) == ["Cousin Lin"])                 // "Lin" had no entries left and is removed
        #expect(abs(b.blessings[0].updatedAt.timeIntervalSince(entry.updatedAt)) < 0.01)
    }

    @Test func importingTheSameFileTwiceAddsNothing() throws {
        let a = try Phone(), b = try Phone()
        try a.add("Lin", 50); try a.add("Tan", 20)
        let file = try a.share()
        try b.service.commit(try b.plan(file))
        let plan = try b.plan(file)
        #expect(plan.summary.alreadyInPot == 2 && plan.selectedCount == 0 && plan.selectableCount == 0)
        #expect(throws: ImportError.nothingSelected) { try b.service.commit(plan) }
        #expect(b.blessings.count == 2)
    }

    @Test func lockedEntriesCannotBeSelected() throws {
        let a = try Phone(), b = try Phone()
        try a.add("Lin", 50)
        let file = try a.share()
        try b.service.commit(try b.plan(file))
        var plan = try b.plan(file)
        let id = try #require(plan.items.first).id
        plan.setSelected(item: id, true); plan.selectAll(); plan.setSelected(person: plan.persons[0].id, true)
        #expect(plan.selectedCount == 0 && plan.items[0].isLocked)
    }

    @Test func crossingTenThousandIsReportedOnce() throws {
        let a = try Phone(), b = try Phone()
        SeedData.insert(into: b.context)
        b.settings.currencyCode = "MYR"
        try a.add("Ah Kong", 300)
        let result = try b.service.commit(try b.plan(try a.share()))
        #expect(b.total == 10_076)
        #expect(result.crossedMilestone == 10_000)
        let again = try a.add("Ah Kong", 10, at: t0.addingTimeInterval(30 * day))
        let second = try b.service.commit(try b.plan(try a.share(.full)))
        #expect(second.crossedMilestone == nil && again.amount == 10)
    }
}

// MARK: - Currency

@MainActor
struct ImportCurrencyTests {
    @Test func rateConvertsIncomingAmountsAndRecordsTheOriginals() throws {
        let a = try Phone(currency: "USD"), b = try Phone(currency: "MYR")
        let entry = try a.add("Lin", Decimal(string: "33.33")!)
        var plan = try b.plan(try a.share())
        #expect(plan.needsCurrencyDecision)
        plan.setCurrency(.rate(Decimal(string: "4.7")!))
        #expect(plan.items[0].entry.amount == Decimal(string: "156.65")!)  // 33.33 × 4.7 = 156.651
        try b.service.commit(plan)
        let imported = try #require(b.blessings.first { $0.id == entry.id })
        #expect(imported.amount == Decimal(string: "156.65")! && imported.currencyCode == "MYR")
        #expect(imported.originalAmount == Decimal(string: "33.33")! && imported.originalCurrencyCode == "USD")
    }

    @Test func importNumbersKeepsTheNumbersAndRelabels() throws {
        let a = try Phone(currency: "USD"), b = try Phone(currency: "MYR")
        try a.add("Lin", 50)
        var plan = try b.plan(try a.share())
        plan.setCurrency(.importNumbers)
        try b.service.commit(plan)
        #expect(b.blessings[0].amount == 50 && b.blessings[0].currencyCode == "MYR" && b.blessings[0].originalAmount == nil)
    }

    @Test func duplicatesAreDetectedAfterConversion() throws {
        let a = try Phone(currency: "USD"), b = try Phone(currency: "MYR")
        try a.add("Lin", 100, at: t0.addingTimeInterval(day))
        try b.add("Lin", 470, at: t0)
        var plan = try b.plan(try a.share())
        #expect(plan.items[0].status == .new)                              // before a rate, numbers don't match
        plan.setCurrency(.rate(Decimal(string: "4.7")!))
        guard case .possibleDuplicate = plan.items[0].status else { Issue.record("expected possible duplicate"); return }
        #expect(!plan.items[0].isSelected)
        plan.setCurrency(.rate(5))
        #expect(plan.items[0].status == .new && plan.items[0].isSelected)  // 500 ≠ 470: not a duplicate any more
    }

    @Test func wholeNumberCurrenciesRoundToWholeUnits() throws {
        let a = try Phone(currency: "USD"), b = try Phone(currency: "JPY")
        try a.add("Lin", Decimal(string: "10.55")!)
        var plan = try b.plan(try a.share())
        plan.setCurrency(.rate(150))
        #expect(plan.items[0].entry.amount == 1583)                        // 1582.5 rounds half away from zero
    }

    @Test func sameCurrencyNeedsNoDecision() throws {
        let a = try Phone(), b = try Phone()
        try a.add("Lin", 50)
        var plan = try b.plan(try a.share())
        plan.setCurrency(.rate(9))                                         // ignored: nothing to convert
        #expect(plan.currency == .notNeeded && plan.items[0].entry.amount == 50 && !plan.convertsAmounts)
    }
}

// MARK: - Snapshots and undo

@MainActor
struct UndoTests {
    @Test func undoRestoresTheSnapshotAndRemovesIt() throws {
        let a = try Phone(), b = try Phone()
        try b.add("Aunt Mei", 100)
        let before = b.state()
        try a.add("Lin", 50); try a.add("Tan", 20)
        try b.service.commit(try b.plan(try a.share()))
        #expect(b.blessings.count == 3)
        #expect(b.service.latestSnapshot() != nil)

        try b.service.undoLastImport()
        #expect(b.state() == before)
        #expect(b.service.latestSnapshot() == nil)
        #expect(throws: ImportError.nothingToUndo) { try b.service.undoLastImport() }
    }

    @Test func undoExpiresAfterSevenDays() throws {
        let a = try Phone(), b = try Phone()
        try a.add("Lin", 50)
        try b.service.commit(try b.plan(try a.share()))
        b.clock = b.clock.addingTimeInterval(7 * day - hour)
        #expect(b.service.latestSnapshot() != nil)
        b.clock = b.clock.addingTimeInterval(2 * hour)
        #expect(b.service.latestSnapshot() == nil)
        #expect(throws: ImportError.nothingToUndo) { try b.service.undoLastImport() }
    }

    @Test func onlyTheLastThreeSnapshotsAreKept() throws {
        let a = try Phone(), b = try Phone()
        for index in 1...5 {
            try a.add("Lin", Decimal(index), at: t0.addingTimeInterval(Double(index) * 30 * day))
            try b.service.commit(try b.plan(try a.share()))
        }
        let files = try FileManager.default.contentsOfDirectory(atPath: b.snapshots.path)
        #expect(files.count == 3 && files.allSatisfy { $0.hasSuffix(".blessingz") })
    }

    @Test func undoOnlyReachesBackToTheLatestImport() throws {
        let a = try Phone(), b = try Phone()
        try a.add("Lin", 50)
        try b.service.commit(try b.plan(try a.share()))
        try a.add("Tan", 20, at: t0.addingTimeInterval(40 * day))
        try b.service.commit(try b.plan(try a.share()))
        #expect(b.blessings.count == 2)
        try b.service.undoLastImport()
        #expect(b.blessings.map(\.amount) == [50])                         // the first import is still there
    }
}

// MARK: - Two phones, merged back and forth

@MainActor
struct TwoDeviceMergeTests {
    @Test func exportEditOnBothMergeAgainNothingDuplicatedNothingLost() throws {
        let a = try Phone(label: "A"), b = try Phone(label: "B")

        // A records three blessings and shares everything.
        let e1 = try a.add("Aunt Mei", 100, at: t0)
        let e2 = try a.add("Aunt Mei", 200, at: t0.addingTimeInterval(40 * day))
        let e3 = try a.add("Uncle Tan", 300, at: t0.addingTimeInterval(80 * day))
        let first = try a.share()
        a.markShared()

        // B imports all of it.
        try b.service.commit(try b.plan(first))
        #expect(Set(b.blessings.map(\.id)) == [e1.id, e2.id, e3.id])

        // Both edit an entry and add a new one.
        let bOwn = try b.add("Cousin Lin", 50, at: t0.addingTimeInterval(90 * day))
        let bEdited = try #require(b.blessings.first { $0.id == e1.id })
        try b.edit(bEdited, amount: 110)
        let aOwn = try a.add("Ah Kong", 70, at: t0.addingTimeInterval(95 * day))
        try a.edit(e2, amount: 250)

        // A shares only what changed since the last export.
        let changes = try a.share(.sinceLastExport)
        #expect(Set(changes.blessings.map(\.id)) == [e2.id, aOwn.id])
        var planB = try b.plan(changes)
        #expect(planB.summary.updated == 1 && planB.summary.new == 1)
        try b.service.commit(planB)

        // B shares everything back; A merges it.
        let back = try b.share()
        let planA = try a.plan(back)
        #expect(planA.summary.updated == 1)                                // e1: B's edit is newer
        #expect(planA.summary.new == 1)                                    // B's own entry
        #expect(planA.summary.alreadyInPot == 3)                           // e2, e3 and aOwn came from A
        try a.service.commit(planA)

        // Same ids on both phones, same amounts, no duplicates, nothing lost.
        let ids = Set([e1.id, e2.id, e3.id, bOwn.id, aOwn.id])
        for phone in [a, b] {
            #expect(phone.blessings.count == 5)
            #expect(Set(phone.blessings.map(\.id)) == ids)
        }
        let amountsA = Dictionary(uniqueKeysWithValues: a.blessings.map { ($0.id, $0.amount) })
        let amountsB = Dictionary(uniqueKeysWithValues: b.blessings.map { ($0.id, $0.amount) })
        #expect(amountsA == amountsB)
        #expect(amountsA[e1.id] == 110 && amountsA[e2.id] == 250)
        #expect(Set(a.blessers.map(\.name)) == ["Aunt Mei", "Uncle Tan", "Cousin Lin", "Ah Kong"])
        #expect(a.blessers.count == 4 && b.blessers.count == 4)             // no duplicated people either
        planB.selectNone()

        // A third round with nothing new changes nothing.
        let quiet = try a.plan(try b.share())
        #expect(quiet.selectableCount == 0)
    }

    @Test func eachPhoneKeepsItsOwnPeopleWhenNamesMatch() throws {
        let a = try Phone(), b = try Phone()
        try a.add("Aunt Mei", 100)
        try b.add("aunt  mei", 40, at: t0.addingTimeInterval(200 * day))
        try b.service.commit(try b.plan(try a.share()))
        #expect(b.blessers.count == 1 && b.blessers[0].blessings.count == 2)
    }
}

// MARK: - The plan itself

struct ImportPlanSelectionTests {
    private func plan() -> ImportPlan {
        let mei = UUID(), lin = UUID()
        func dto(_ person: UUID, _ amount: Decimal, _ days: Double) -> ExchangeFile.BlessingDTO {
            .init(id: UUID(), blesserID: person, amount: amount, currencyCode: "MYR", date: t0.addingTimeInterval(days * day),
                  occasion: "birthday", method: "cash", note: "", updatedAt: t0)
        }
        let file = ExchangeFile(
            schemaVersion: 2, exportedAt: t0, exportedBy: "A", deviceID: UUID(), currencyCode: "MYR", kind: .full,
            blessers: [.init(id: mei, name: "Aunt Mei", nameKey: "aunt mei"), .init(id: lin, name: "Lin", nameKey: "lin")],
            blessings: [dto(mei, 100, 0), dto(mei, 200, 100), dto(lin, 50, 0)]
        )
        return ImportPlan(file: file, localCurrency: "MYR", local: LocalSnapshot(persons: [], entries: []))
    }

    @Test func tickingByPersonGivesATriState() {
        var plan = plan()
        let mei = plan.persons.first { $0.name == "Aunt Mei" }!.id
        #expect(plan.selection(of: mei) == true)
        plan.setSelected(item: plan.items(of: mei)[0].id, false)
        #expect(plan.selection(of: mei) == nil)                            // mixed
        plan.setSelected(person: mei, false)
        #expect(plan.selection(of: mei) == false && plan.selectedCount == 1)
        plan.setSelected(person: mei, true)
        #expect(plan.selection(of: mei) == true && plan.selectedCount == 3)
    }

    @Test func menuActions() {
        var plan = plan()
        plan.selectNone()
        #expect(plan.selectedCount == 0 && plan.selectableCount == 3)
        plan.selectAllNew()
        #expect(plan.selectedCount == 3)
        plan.selectNone(); plan.selectAll()
        #expect(plan.selectedCount == 3 && plan.selectedSum == 350)
    }

    @Test func newPeopleCountOnlyThoseWithSelectedEntries() {
        var plan = plan()
        #expect(plan.newPersonIDs.count == 2)
        let lin = plan.persons.first { $0.name == "Lin" }!.id
        plan.setSelected(person: lin, false)
        #expect(plan.newPersonIDs.count == 1)
    }

    @Test func userTicksSurviveReclassification() {
        var plan = plan()
        let item = plan.items[0].id
        plan.setSelected(item: item, false)
        plan.setMapping(person: plan.persons[0].id, .createNew)
        #expect(plan.items.first { $0.id == item }?.isSelected == false)
    }

    @Test func entriesWithoutAPersonAreSkipped() {
        let lin = UUID()
        let file = ExchangeFile(
            schemaVersion: 2, exportedAt: t0, exportedBy: "A", deviceID: UUID(), currencyCode: "MYR", kind: .full,
            blessers: [.init(id: lin, name: "Lin", nameKey: "lin")],
            blessings: [
                .init(id: UUID(), blesserID: lin, amount: 1, currencyCode: "MYR", date: t0, occasion: "other", method: "cash", note: "", updatedAt: t0),
                .init(id: UUID(), blesserID: nil, amount: 2, currencyCode: "MYR", date: t0, occasion: "other", method: "cash", note: "", updatedAt: t0),
            ]
        )
        let plan = ImportPlan(file: file, localCurrency: "MYR", local: LocalSnapshot(persons: [], entries: []))
        #expect(plan.items.count == 1 && plan.skippedWithoutPerson == 1)
    }
}
