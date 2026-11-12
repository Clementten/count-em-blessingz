import Foundation

/// The honeypot goal is optional: 0 means "no goal". These helpers keep that rule in one place
/// (the app, the Settings field and the widget all use them).
enum GoalProgress {
    /// 0...1, or nil when there is no goal. Geometry only (bar width and percent label), never stored as money.
    static func fraction(total: Decimal, goal: Decimal) -> Double? {
        guard goal > 0 else { return nil }
        return min(1, NSDecimalNumber(decimal: total / goal).doubleValue)
    }
}

enum GoalInput {
    /// What typing in the Settings field means. Empty or zero turns the goal off; a real number sets it;
    /// anything else (half-typed, negative, letters) leaves the current goal unchanged.
    static func resolve(_ text: String, current: Decimal, locale: Locale = .current) -> Decimal {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        if let value = MoneyFormatter.parsePositive(trimmed, locale: locale) { return value }
        // "0" and "0.00" are not "positive", but they plainly mean no goal.
        let zeroLike = trimmed.allSatisfy { $0 == "0" || $0 == "." || $0 == "," }
        return zeroLike && trimmed.contains("0") ? 0 : current
    }

    /// The field is empty when there is no goal, so its placeholder ("No goal") shows.
    static func fieldText(for goal: Decimal, locale: Locale = .current) -> String {
        goal > 0 ? goal.formatted(.number.precision(.fractionLength(0...2)).locale(locale)) : ""
    }
}
