import SwiftData
import Foundation

enum CurrencyConverter {
    /// Which side of "1 FROM = ? TO" the user typed into.
    enum Direction {
        case fromToTo   // 1 FROM = [input] TO  → rate = input
        case toToFrom   // [input] FROM = 1 TO  → rate = 1 / input
    }

    /// Parses a user-typed rate; nil unless it is a positive decimal. Accepts `,` or `.` per `locale`.
    static func parseRate(_ text: String, locale: Locale = .current) -> Decimal? {
        MoneyFormatter.parsePositive(text, locale: locale)
    }

    /// Converts the typed input into "1 FROM = rate TO".
    static func rate(input: Decimal, direction: Direction) -> Decimal? {
        guard input > 0 else { return nil }
        switch direction {
        case .fromToTo: return input
        case .toToFrom: return 1 / input
        }
    }

    static func convert(_ amount: Decimal, rate: Decimal, to currency: String) -> Decimal {
        MoneyFormatter.round(amount * rate, currency: currency)
    }

    /// Goal after conversion: scaled, rounded to the nearest 100, never below 100. No goal (0) stays 0.
    static func convertGoal(_ goal: Decimal, rate: Decimal) -> Decimal {
        guard goal > 0 else { return 0 }                 // no goal stays no goal
        return max(100, MoneyFormatter.round(goal * rate / 100, scale: 0) * 100)
    }

    /// Applies a currency change in one transaction and returns the audit row.
    /// `labelOnly` keeps the numbers and only changes the currency (rate treated as 1).
    @discardableResult
    static func apply(
        rate: Decimal,
        to target: String,
        countryCode: String,
        labelOnly: Bool,
        blessings: [Blessing],
        settings: AppSettings,
        context: ModelContext
    ) throws -> CurrencyConversion {
        let effectiveRate: Decimal = labelOnly ? 1 : rate
        let source = settings.currencyCode
        let log = CurrencyConversion(
            fromCode: source, toCode: target, rate: effectiveRate,
            convertedAmounts: !labelOnly, count: blessings.count
        )
        try context.transaction {
            for blessing in blessings {
                if blessing.originalAmount == nil {
                    blessing.originalAmount = blessing.amount
                    blessing.originalCurrencyCode = blessing.currencyCode
                }
                if !labelOnly {
                    blessing.amount = convert(blessing.amount, rate: effectiveRate, to: target)
                }
                blessing.currencyCode = target
                blessing.updatedAt = .now
            }
            if !labelOnly {
                settings.goal = convertGoal(settings.goal, rate: effectiveRate)
            }
            settings.countryCode = countryCode
            settings.currencyCode = target
            context.insert(log)
        }
        return log
    }
}
