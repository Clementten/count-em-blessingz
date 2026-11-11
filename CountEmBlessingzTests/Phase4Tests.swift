import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor
private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
}

private let us = Locale(identifier: "en_US")

private func draft(_ name: String, _ amount: String, occasion: Occasion = .justBecause) -> BlessingDraft {
    var d = BlessingDraft()
    d.name = name; d.amountText = amount; d.occasion = occasion
    return d
}

@MainActor
struct BlessingServiceTests {
    @Test func validationRequiresNameAndPositiveAmount() {
        #expect(draft("", "10").problems(locale: us) == [.nameRequired])
        #expect(draft("Mei", "0").problems(locale: us) == [.amountInvalid])
        #expect(draft(" ", "abc").problems(locale: us) == [.nameRequired, .amountInvalid])
        #expect(draft("Mei", "10").problems(locale: us).isEmpty)
    }

    @Test func addingSameNameTwiceCreatesOneBlesser() throws {
        let context = try makeContext()
        let service = BlessingService(context: context)
        try service.add(draft("Aunt Mei", "100"), currency: "MYR", goal: nil, locale: us)
        try service.add(draft("aunt mei ", "50"), currency: "MYR", goal: nil, locale: us)
        #expect(try context.fetchCount(FetchDescriptor<Blesser>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Blessing>()) == 2)
    }

    @Test func addMarksThankYouPending() throws {
        let context = try makeContext()
        let result = try BlessingService(context: context).add(draft("Mei", "100"), currency: "MYR", goal: nil, locale: us)
        #expect(result.blessing.blesser?.thankYouPending == true)
    }

    @Test func addingThreeCrossingTenThousandReportsMilestone() throws {
        let context = try makeContext()
        SeedData.insert(into: context)
        let result = try BlessingService(context: context).add(draft("Ah Kong", "300"), currency: "MYR", goal: 20_000, locale: us)
        #expect(result.crossedMilestone == 10_000)
        let second = try BlessingService(context: context).add(draft("Ah Kong", "10"), currency: "MYR", goal: 20_000, locale: us)
        #expect(second.crossedMilestone == nil)
    }

    @Test func editKeepsThankYouPendingAndRemovesEmptyOldBlesser() throws {
        let context = try makeContext()
        let service = BlessingService(context: context)
        let result = try service.add(draft("Mei", "100"), currency: "MYR", goal: nil, locale: us)
        result.blessing.blesser?.thankYouPending = false
        var edited = BlessingDraft(editing: result.blessing)
        edited.name = "Lin"
        try service.update(result.blessing, with: edited, locale: us)
        #expect(result.blessing.blesser?.name == "Lin")
        #expect(result.blessing.blesser?.thankYouPending == true)   // Lin is new, defaults pending
        let names = try context.fetch(FetchDescriptor<Blesser>()).map(\.name)
        #expect(names == ["Lin"])
    }

    @Test func editOfAmountDoesNotChangePending() throws {
        let context = try makeContext()
        let service = BlessingService(context: context)
        let result = try service.add(draft("Mei", "100"), currency: "MYR", goal: nil, locale: us)
        result.blessing.blesser?.thankYouPending = false
        var edited = BlessingDraft(editing: result.blessing)
        edited.amountText = "250"
        try service.update(result.blessing, with: edited, locale: us)
        #expect(result.blessing.amount == 250)
        #expect(result.blessing.blesser?.thankYouPending == false)
    }

    @Test func deleteLastBlessingRemovesBlesserAndUndoRestoresBoth() throws {
        let context = try makeContext()
        let service = BlessingService(context: context)
        let result = try service.add(draft("Mei", "100", occasion: .wedding), currency: "MYR", goal: nil, locale: us)
        let id = result.blessing.id
        let snapshot = service.delete(result.blessing)
        #expect(try context.fetchCount(FetchDescriptor<Blessing>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Blesser>()) == 0)
        try service.restore(snapshot)
        let restored = try context.fetch(FetchDescriptor<Blessing>())
        #expect(restored.count == 1)
        #expect(restored.first?.id == id)
        #expect(restored.first?.occasion == .wedding)
        #expect(restored.first?.blesser?.name == "Mei")
    }

    @Test func deleteKeepsBlesserWithOtherBlessings() throws {
        let context = try makeContext()
        let service = BlessingService(context: context)
        let first = try service.add(draft("Mei", "100"), currency: "MYR", goal: nil, locale: us)
        try service.add(draft("Mei", "50"), currency: "MYR", goal: nil, locale: us)
        service.delete(first.blessing)
        #expect(try context.fetchCount(FetchDescriptor<Blesser>()) == 1)
    }
}

@MainActor
struct HomeListLogicTests {
    private func seeded() throws -> [Blessing] {
        let context = try makeContext()
        SeedData.insert(into: context)
        return try context.fetch(FetchDescriptor<Blessing>())
    }

    private let now = ISO8601DateFormatter().date(from: "2026-02-15T12:00:00Z")!

    @Test func totalsAndMonthDelta() throws {
        let all = try seeded()
        #expect(HomeListLogic.total(all) == 9_776)
        #expect(HomeListLogic.monthTotal(all, now: now) == 1_888)   // Feb 2026: 888 + 1000
    }

    @Test func groupsByMonthNewestFirst() throws {
        let sections = HomeListLogic.sections(try seeded(), sort: .newest, locale: us)
        #expect(sections.first?.title == "Feb 2026")
        #expect(sections.first?.blessings.map(\.amount) == [888, 1000])
        #expect(sections.map(\.id) == sections.map(\.id).sorted(by: >))
    }

    @Test func largestIsFlatAndDescending() throws {
        let sections = HomeListLogic.sections(try seeded(), sort: .largest)
        #expect(sections.count == 1)
        #expect(sections[0].blessings.first?.amount == 1_200)
    }

    @Test func searchMatchesNameOccasionAndThisYear() throws {
        let all = try seeded()
        #expect(HomeListLogic.filter(all, query: "mei", thisYearOnly: false).count == 4)
        #expect(HomeListLogic.filter(all, query: "wedding", thisYearOnly: false).count == 3)
        #expect(HomeListLogic.filter(all, query: "", thisYearOnly: true, now: now).count == 3)
    }
}
