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

struct MoneyTests {
    @Test func roundsHalfAwayFromZeroForTwoDecimalCurrency() {
        #expect(MoneyFormatter.round(Decimal(string: "1.005")!, currency: "USD") == Decimal(string: "1.01")!)
        #expect(MoneyFormatter.round(Decimal(string: "2.344")!, currency: "USD") == Decimal(string: "2.34")!)
    }

    @Test func jpyHasNoMinorUnits() {
        #expect(MoneyFormatter.minorUnits(for: "JPY") == 0)
        #expect(MoneyFormatter.round(Decimal(string: "1234.5")!, currency: "JPY") == 1235)
        #expect(MoneyFormatter.round(Decimal(string: "1234.4")!, currency: "JPY") == 1234)
    }

    @Test func formatsWithoutTrailingZeros() {
        #expect(MoneyFormatter.plain(888) == "888")
    }
}

struct MilestoneTests {
    @Test func crossingTenThousand() {
        #expect(MilestoneService.crossed(before: 9_776, after: 10_076) == 10_000)
    }

    @Test func noCrossingWhenBelowThreshold() {
        #expect(MilestoneService.crossed(before: 9_000, after: 9_776) == nil)
    }

    @Test func returnsHighestOfSeveralCrossed() {
        #expect(MilestoneService.crossed(before: 500, after: 6_000) == 5_000)
    }

    @Test func alreadyAtThresholdDoesNotRefire() {
        #expect(MilestoneService.crossed(before: 10_000, after: 10_100) == nil)
    }

    @Test func goalIsAThreshold() {
        #expect(MilestoneService.crossed(before: 7_000, after: 8_000, goal: 7_500) == 7_500)
    }
}

struct RateTests {
    @Test func directionFromToTo() {
        #expect(CurrencyConverter.rate(input: Decimal(string: "0.21")!, direction: .fromToTo) == Decimal(string: "0.21")!)
    }

    @Test func directionToToFromInverts() throws {
        let rate = try #require(CurrencyConverter.rate(input: Decimal(string: "4.76")!, direction: .toToFrom))
        // 1 / 4.76 ≈ 0.21008
        let diff = abs(rate - Decimal(string: "0.21")!)
        #expect(diff < Decimal(string: "0.0001")!)
    }

    @Test func rejectsNonPositive() {
        #expect(CurrencyConverter.rate(input: 0, direction: .fromToTo) == nil)
        #expect(CurrencyConverter.parseRate("-1") == nil)
        #expect(CurrencyConverter.parseRate("abc") == nil)
        #expect(CurrencyConverter.parseRate("  ") == nil)
    }

    @Test func parsesCommaAndDotLocales() {
        #expect(CurrencyConverter.parseRate("4,76", locale: Locale(identifier: "de_DE")) == Decimal(string: "4.76")!)
        #expect(CurrencyConverter.parseRate("4.76", locale: Locale(identifier: "en_US")) == Decimal(string: "4.76")!)
    }

    @Test func goalConversionRoundsToNearestHundred() {
        #expect(CurrencyConverter.convertGoal(20_000, rate: Decimal(string: "0.21")!) == 4_200)
        #expect(CurrencyConverter.convertGoal(100, rate: Decimal(string: "0.001")!) == 100)
    }
}

@MainActor
struct ResolverTests {
    @Test func matchesCaseInsensitivelyAndTrimmed() throws {
        let context = try makeContext()
        let resolver = BlesserResolver(context: context)
        let first = try #require(try resolver.findOrCreate(name: "Aunt Mei"))
        let second = try #require(try resolver.findOrCreate(name: "  aunt MEI "))
        #expect(first === second)
        #expect(try context.fetchCount(FetchDescriptor<Blesser>()) == 1)
    }

    @Test func emptyNameCreatesNothing() throws {
        let context = try makeContext()
        #expect(try BlesserResolver(context: context).findOrCreate(name: "   ") == nil)
        #expect(try context.fetchCount(FetchDescriptor<Blesser>()) == 0)
    }
}

@MainActor
struct ConverterApplyTests {
    private func seeded() throws -> (ModelContext, AppSettings, [Blessing]) {
        let context = try makeContext()
        let settings = SeedData.insert(into: context)
        let blessings = try context.fetch(FetchDescriptor<Blessing>())
        return (context, settings, blessings)
    }

    @Test func seedTotalMatchesMock() throws {
        let (_, _, blessings) = try seeded()
        #expect(blessings.reduce(Decimal(0)) { $0 + $1.amount } == 9_776)
    }

    @Test func convertsAmountsGoalAndPreservesOriginals() throws {
        let (context, settings, blessings) = try seeded()
        let rate = Decimal(string: "0.21")!
        let log = try CurrencyConverter.apply(
            rate: rate, to: "USD", countryCode: "US", labelOnly: false,
            blessings: blessings, settings: settings, context: context
        )
        #expect(settings.currencyCode == "USD")
        #expect(settings.countryCode == "US")
        #expect(settings.goal == 4_200)
        #expect(blessings.allSatisfy { $0.currencyCode == "USD" && $0.originalCurrencyCode == "MYR" })
        #expect(blessings.reduce(Decimal(0)) { $0 + ($1.originalAmount ?? 0) } == 9_776)
        #expect(blessings.first { $0.originalAmount == 888 }?.amount == Decimal(string: "186.48")!)
        #expect(log.convertedAmounts && log.count == blessings.count && log.rate == rate)
    }

    @Test func secondConversionNeverOverwritesOriginal() throws {
        let (context, settings, blessings) = try seeded()
        try CurrencyConverter.apply(rate: Decimal(string: "0.21")!, to: "USD", countryCode: "US", labelOnly: false,
                                    blessings: blessings, settings: settings, context: context)
        try CurrencyConverter.apply(rate: 150, to: "JPY", countryCode: "JP", labelOnly: false,
                                    blessings: blessings, settings: settings, context: context)
        #expect(blessings.allSatisfy { $0.originalCurrencyCode == "MYR" })
        #expect(blessings.reduce(Decimal(0)) { $0 + ($1.originalAmount ?? 0) } == 9_776)
        #expect(blessings.allSatisfy { $0.currencyCode == "JPY" })
    }

    @Test func labelOnlyKeepsNumbers() throws {
        let (context, settings, blessings) = try seeded()
        let log = try CurrencyConverter.apply(
            rate: Decimal(string: "0.21")!, to: "USD", countryCode: "US", labelOnly: true,
            blessings: blessings, settings: settings, context: context
        )
        #expect(blessings.reduce(Decimal(0)) { $0 + $1.amount } == 9_776)
        #expect(settings.goal == 20_000)
        #expect(settings.currencyCode == "USD")
        #expect(!log.convertedAmounts && log.rate == 1)
    }
}

struct CountryCatalogTests {
    @Test func mapsMalaysiaToMYR() {
        #expect(CountryCatalog.country(code: "MY")?.currencyCode == "MYR")
        #expect(CountryCatalog.country(code: "JP")?.currencyCode == "JPY")
    }

    @Test func searchByName() {
        #expect(CountryCatalog.search("malay").contains { $0.code == "MY" })
        #expect(CountryCatalog.search("").count == CountryCatalog.all.count)
    }
}

struct RateEntryTests {
    private let us = Locale(identifier: "en_US")

    @Test func fromToToUsesInputAsRate() {
        var entry = RateEntry()
        entry.text = "0.21"
        #expect(entry.rate(locale: us) == Decimal(string: "0.21")!)
        #expect(entry.preview(total: 9_776, to: "USD", locale: us) == Decimal(string: "2052.96")!)
    }

    @Test func swappingFlipsDirectionAndClearsField() throws {
        var entry = RateEntry()
        entry.text = "0.21"
        entry.swap()
        #expect(entry.text.isEmpty)
        #expect(entry.direction == .toToFrom)
        #expect(entry.rate(locale: us) == nil)
        entry.text = "4.76"
        let rate = try #require(entry.rate(locale: us))
        #expect(abs(rate - Decimal(string: "0.21")!) < Decimal(string: "0.0001")!)
    }

    @Test func invalidInputShowsErrorOnlyWhenTyped() {
        var entry = RateEntry()
        #expect(!entry.showsError(locale: us))
        entry.text = "abc"
        #expect(entry.showsError(locale: us))
        entry.text = "0"
        #expect(entry.showsError(locale: us))
        entry.text = "4,76"
        #expect(entry.rate(locale: Locale(identifier: "de_DE")) == Decimal(string: "4.76")!)
    }
}
