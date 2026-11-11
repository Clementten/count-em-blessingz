import Foundation

/// The state of the rate sheet: what the user typed and which side they typed into.
struct RateEntry {
    var text = ""
    var direction: CurrencyConverter.Direction = .fromToTo

    /// "1 FROM = rate TO", or nil if the input is not a positive decimal.
    func rate(locale: Locale = .current) -> Decimal? {
        guard let input = CurrencyConverter.parseRate(text, locale: locale) else { return nil }
        return CurrencyConverter.rate(input: input, direction: direction)
    }

    /// True when something is typed but it is not usable (drives the inline error).
    func showsError(locale: Locale = .current) -> Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && rate(locale: locale) == nil
    }

    /// Flips the typed side and clears the field.
    mutating func swap() {
        direction = direction == .fromToTo ? .toToFrom : .fromToTo
        text = ""
    }

    /// Converted value for the live preview.
    func preview(total: Decimal, to currency: String, locale: Locale = .current) -> Decimal? {
        rate(locale: locale).map { CurrencyConverter.convert(total, rate: $0, to: currency) }
    }
}
