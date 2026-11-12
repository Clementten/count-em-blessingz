import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor private var retained: [ModelContainer] = []

private let us = Locale(identifier: "en_US")
private let de = Locale(identifier: "de_DE")

struct NumberParsingTests {
    /// What the app puts in a text field must read back as the same number.
    @Test(arguments: [Decimal(0), 1, 20, 999, 1_000, 20_000, 1_234_567, Decimal(string: "1234.5")!, Decimal(string: "0.1")!, Decimal(string: "1000.25")!])
    func editableTextReadsBackExactly(value: Decimal) {
        for locale in [us, de] {
            let text = MoneyFormatter.editable(value, locale: locale)
            if value == 0 { #expect(MoneyFormatter.parsePositive(text, locale: locale) == nil); continue }
            #expect(MoneyFormatter.parsePositive(text, locale: locale) == value, "\(value) → \"\(text)\" in \(locale.identifier)")
        }
    }

    @Test(arguments: [
        ("1,000", us, "1000"), ("20,000", us, "20000"), ("1,234,567.89", us, "1234567.89"), ("1000", us, "1000"),
        ("0.5", us, "0.5"), ("1.000", de, "1000"), ("1.000,50", de, "1000.5"), ("4,76", de, "4.76"), ("  12 ", us, "12"),
    ])
    func acceptsGroupingAndDecimalMarks(text: String, locale: Locale, expected: String) {
        #expect(MoneyFormatter.parsePositive(text, locale: locale) == Decimal(string: expected)!, "\(text)")
    }

    @Test(arguments: ["", "  ", "abc", "12abc", "1,00", "1..5", "-5", "0", "0.00", "1e3", "+5", "5%"])
    func rejectsAnythingElse(text: String) {
        #expect(MoneyFormatter.parsePositive(text, locale: us) == nil, "\(text)")
    }
}

@MainActor
struct EditingLargeAmountsTests {
    @Test func editingAnEntryOverOneThousandKeepsItsAmount() throws {
        let container = try ModelContainer(
            for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        retained.append(container)
        let context = container.mainContext
        SeedData.insert(into: context)
        let big = try #require(try context.fetch(FetchDescriptor<Blessing>()).first { $0.amount == 1_200 })
        let draft = BlessingDraft(editing: big)               // as the Edit sheet opens it
        #expect(draft.parsedAmount(locale: us) == 1_200)
        try BlessingService(context: context).update(big, with: draft, locale: us)   // saved without touching the amount
        #expect(big.amount == 1_200)
    }
}
