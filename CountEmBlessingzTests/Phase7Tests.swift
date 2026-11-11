import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor private var retained: [ModelContainer] = []

@MainActor
private func seeded() throws -> (blessers: [Blesser], blessings: [Blessing]) {
    let container = try ModelContainer(
        for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    retained.append(container)
    SeedData.insert(into: container.mainContext)
    return (try container.mainContext.fetch(FetchDescriptor<Blesser>()),
            try container.mainContext.fetch(FetchDescriptor<Blessing>()))
}

@MainActor
struct HallLogicTests {
    @Test func rankingOrderAndNumbers() throws {
        let ranking = HallLogic.ranking(try seeded().blessers)
        #expect(ranking.map(\.rank) == [1, 2, 3, 4, 5, 6])
        #expect(ranking.prefix(3).map(\.blesser.name) == ["Dad & Mum", "Aunt Mei", "Cousin Lin"])
        #expect(ranking[0].blesser.name == "Dad & Mum")
        #expect(ranking[0].total == 2_500)
        #expect(ranking.map(\.total) == ranking.map(\.total).sorted(by: >))
    }

    @Test func milestonesReachedAtTotal() {
        #expect(HallLogic.isReached(5_000, total: 9_776))
        #expect(!HallLogic.isReached(10_000, total: 9_776))
        #expect(HallLogic.isReached(10_000, total: 10_000))
    }

    @Test func yearReview() throws {
        let blessings = try seeded().blessings
        let review = try #require(HallLogic.review(blessings, preferredYear: 2025))
        #expect(review.year == 2025)
        #expect(review.count == 10)
        #expect(review.topOccasion == .wedding)      // 300 + 1100 + 800
    }

    @Test func reviewFallsBackToLatestYearWithData() throws {
        let blessings = try seeded().blessings
        #expect(HallLogic.review(blessings, preferredYear: 2030)?.year == 2026)
        #expect(HallLogic.review([], preferredYear: 2026) == nil)
    }
}

struct MilestoneLabelTests {
    @Test func shortLabels() {
        #expect(MilestoneService.shortLabel(10_000) == "10k")
        #expect(MilestoneService.shortLabel(1_000) == "1k")
        #expect(MilestoneService.shortLabel(7_500) == "7,500")
    }
}
