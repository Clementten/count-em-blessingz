import Foundation

enum MilestoneService {
    static let fixedThresholds: [Decimal] = [1_000, 5_000, 10_000, 20_000]

    /// Fixed thresholds plus the user's goal, sorted and de-duplicated.
    static func thresholds(goal: Decimal? = nil) -> [Decimal] {
        var all = fixedThresholds
        if let goal, goal > 0, !all.contains(goal) { all.append(goal) }
        return all.sorted()
    }

    /// The highest threshold crossed by an add that moves the total from `before` to `after`.
    static func crossed(before: Decimal, after: Decimal, goal: Decimal? = nil) -> Decimal? {
        thresholds(goal: goal).last { before < $0 && after >= $0 }
    }

    /// "10k" for round thousands, otherwise the plain number.
    static func shortLabel(_ value: Decimal) -> String {
        var thousands = value / 1_000
        var whole = Decimal()
        NSDecimalRound(&whole, &thousands, 0, .down)
        if value >= 1_000, whole == value / 1_000 {
            return "\(NSDecimalNumber(decimal: whole).intValue)k"
        }
        return MoneyFormatter.plain(value)
    }
}
