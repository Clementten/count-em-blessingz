import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

/// Models become unusable once their container is released, so keep containers alive for the test run.
@MainActor private var retainedContainers: [ModelContainer] = []

@MainActor
private func seeded() throws -> [Blessing] {
    let container = try ModelContainer(
        for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    retainedContainers.append(container)
    SeedData.insert(into: container.mainContext)
    return try container.mainContext.fetch(FetchDescriptor<Blessing>())
}

private let us = Locale(identifier: "en_US")
private let now = ISO8601DateFormatter().date(from: "2026-02-15T12:00:00Z")!

struct PercentTests {
    @Test func alwaysSumTo100() {
        #expect(InsightsLogic.percents([1, 1, 1]).reduce(0, +) == 100)          // 33.33 each
        #expect(InsightsLogic.percents([2_488, 2_500, 1_100, 1_520, 2_168]).reduce(0, +) == 100)
        #expect(InsightsLogic.percents([5, 5]) == [50, 50])
        #expect(InsightsLogic.percents([]) == [])
        #expect(InsightsLogic.percents([0, 0]) == [0, 0])
    }
}

@MainActor
struct InsightsLogicTests {
    @Test func byPersonCollapsesToTopFourPlusOthers() throws {
        let groups = InsightsLogic.groups(try seeded(), mode: .person, locale: us, othersLabel: "Others")
        #expect(groups.count == 5)                         // 6 blessers: top 4 + Others
        #expect(groups.last?.label == "Others")
        #expect(groups.first?.label == "Dad & Mum")
        #expect(groups.map(\.percent).reduce(0, +) == 100)
        #expect(groups.map(\.value).reduce(0, +) == 9_776)
    }

    @Test func noOthersAtFiveGroupsOrFewer() throws {
        let blessings = try seeded().filter { $0.occasion == .chineseNewYear || $0.occasion == .wedding || $0.occasion == .birthday }
        let groups = InsightsLogic.groups(blessings, mode: .occasion, locale: us)
        #expect(groups.count == 3)
        #expect(!groups.contains { $0.id == "others" })
        #expect(groups.map(\.percent).reduce(0, +) == 100)
    }

    @Test func byMonthLabelsAndTotals() throws {
        let groups = InsightsLogic.groups(try seeded().filter { $0.date >= now.addingTimeInterval(-60 * 86_400) }, mode: .month, locale: us)
        #expect(groups.map(\.label).contains("Feb 2026"))
        #expect(groups.first { $0.label == "Feb 2026" }?.value == 1_888)
    }

    @Test func rangeFilters() throws {
        let all = try seeded()
        #expect(InsightsLogic.filter(all, range: .allTime, now: now).count == 15)
        #expect(InsightsLogic.filter(all, range: .thisMonth, now: now).count == 2)
        #expect(InsightsLogic.filter(all, range: .thisYear, now: now).count == 3)
        let start = ISO8601DateFormatter().date(from: "2025-11-01T00:00:00Z")!
        let end = ISO8601DateFormatter().date(from: "2025-11-30T00:00:00Z")!
        #expect(InsightsLogic.filter(all, range: .custom, custom: start...end, now: now).count == 2)
    }

    @Test func funFactUsesTopOccasion() throws {
        let fact = try #require(InsightsLogic.topOccasionFact(try seeded()))
        // CNY: 888 + 1000 + 800 + 880 = 3,568 of 9,776 ≈ 36%
        #expect(fact.occasion == .chineseNewYear)
        #expect(fact.percent == 36)
        #expect(InsightsLogic.topOccasionFact([]) == nil)
    }
}
