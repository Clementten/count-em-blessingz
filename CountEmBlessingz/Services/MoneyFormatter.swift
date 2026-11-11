import Foundation

enum MoneyFormatter {
    /// Number of minor-unit digits for an ISO 4217 code (0 for JPY, 2 for MYR/USD).
    static func minorUnits(for currency: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.maximumFractionDigits
    }

    /// Rounds with `.plain` mode (half away from zero) to `scale` decimal places, without touching `Double`.
    static func round(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }

    /// Rounds to the minor units of `currency`.
    static func round(_ value: Decimal, currency: String) -> Decimal {
        round(value, scale: minorUnits(for: currency) == 0 ? 0 : 2)
    }

    static func format(_ value: Decimal, currency: String) -> String {
        let maxDigits = minorUnits(for: currency) == 0 ? 0 : 2
        return value.formatted(
            .currency(code: currency).precision(.fractionLength(0...maxDigits))
        )
    }

    /// Parses a positive decimal typed by the user (`,` or `.` per `locale`); nil otherwise.
    static func parsePositive(_ text: String, locale: Locale = .current) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let value = Decimal(string: trimmed, locale: locale),
              value > 0
        else { return nil }
        return value
    }

    /// Currency symbol such as "RM" or "$" for an ISO code.
    static func symbol(for currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.currencySymbol ?? currency
    }

    /// Number only, no currency symbol.
    static func plain(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

enum StampFormatter {
    /// "2 Feb, 10:14" — day, month and 24-hour time, as the design specifies.
    static func string(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}
