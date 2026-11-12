import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor
private func seededContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    SeedData.insert(into: context)
    return context
}

@MainActor
private func blesser(_ name: String, in context: ModelContext) throws -> Blesser {
    try #require(try BlesserResolver(context: context).find(name: name))
}

@MainActor
struct BlesserServiceTests {
    @Test func statsMatchTheList() throws {
        let context = try seededContext()
        let mei = try blesser("Aunt Mei", in: context)
        let stats = BlesserService.stats(for: mei)
        #expect(stats.lifetime == 2_488)        // 888 + 500 + 800 + 300
        #expect(stats.count == 4)
        #expect(stats.average == 622)
        #expect(stats.byYear.map(\.year) == [2024, 2025, 2026])
        #expect(stats.byYear.map(\.total) == [300, 1_300, 888])
    }

    @Test func rankingByLifetime() throws {
        let context = try seededContext()
        let all = try context.fetch(FetchDescriptor<Blesser>())
        // Dad & Mum 2,500 > Aunt Mei 2,488 > Wong 1,200 ...
        #expect(BlesserService.rank(of: try blesser("Dad & Mum", in: context), among: all) == 1)
        #expect(BlesserService.rank(of: try blesser("Aunt Mei", in: context), among: all) == 2)
        #expect(BlesserService.rank(of: try blesser("Ah Kong", in: context), among: all) == all.count)
    }

    @Test func mergeMovesBlessingsAndDeletesSource() throws {
        let context = try seededContext()
        let service = BlesserService(context: context)
        let mei = try blesser("Aunt Mei", in: context)
        let tan = try blesser("Uncle Tan", in: context)   // pending
        let before = BlesserService.stats(for: mei).count + BlesserService.stats(for: tan).count
        let totalBefore = try context.fetch(FetchDescriptor<Blessing>()).reduce(Decimal(0)) { $0 + $1.amount }
        service.merge(tan, into: mei)
        #expect(mei.blessings.count == before)
        #expect(mei.thankYouPending)
        #expect(try BlesserResolver(context: context).find(name: "Uncle Tan") == nil)
        let totalAfter = try context.fetch(FetchDescriptor<Blessing>()).reduce(Decimal(0)) { $0 + $1.amount }
        #expect(totalAfter == totalBefore)
    }

    @Test func renameRules() throws {
        let context = try seededContext()
        let service = BlesserService(context: context)
        let mei = try blesser("Aunt Mei", in: context)
        #expect(throws: BlesserService.RenameError.empty) { try service.rename(mei, to: "  ") }
        #expect(throws: BlesserService.RenameError.nameTaken) { try service.rename(mei, to: "ah kong") }
        try service.rename(mei, to: "  Auntie Mei ")
        #expect(mei.name == "Auntie Mei")
        #expect(mei.nameKey == "auntie mei")
        try service.rename(mei, to: "AUNTIE MEI")     // same blesser, different case is allowed
        #expect(mei.name == "AUNTIE MEI")
    }
}
