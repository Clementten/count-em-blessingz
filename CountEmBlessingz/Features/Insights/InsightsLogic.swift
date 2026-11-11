import Foundation

enum InsightMode: String, CaseIterable, Identifiable {
    case person, month, occasion
    var id: String { rawValue }
    var title: String {
        switch self {
        case .person: String(localized: "By person")
        case .month: String(localized: "By month")
        case .occasion: String(localized: "By occasion")
        }
    }
}

enum InsightRange: String, CaseIterable, Identifiable {
    case thisMonth, thisYear, allTime, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .thisMonth: String(localized: "This month")
        case .thisYear: String(localized: "This year")
        case .allTime: String(localized: "All time")
        case .custom: String(localized: "Custom")
        }
    }
}

struct InsightGroup: Identifiable, Equatable {
    let id: String
    let label: String
    let value: Decimal
    let percent: Int
}

enum InsightsLogic {
    /// More groups than this collapse into the top (maxGroups - 1) plus "Others".
    static let maxGroups = 5

    static func filter(
        _ blessings: [Blessing], range: InsightRange, custom: ClosedRange<Date>? = nil,
        now: Date = .now, calendar: Calendar = .current
    ) -> [Blessing] {
        switch range {
        case .allTime:
            return blessings
        case .thisMonth:
            return blessings.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .thisYear:
            return blessings.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
        case .custom:
            guard let custom else { return blessings }
            let start = calendar.startOfDay(for: custom.lowerBound)
            let endDay = calendar.startOfDay(for: custom.upperBound)
            let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? custom.upperBound
            return blessings.filter { $0.date >= start && $0.date < end }
        }
    }

    static func groups(
        _ blessings: [Blessing], mode: InsightMode,
        calendar: Calendar = .current, locale: Locale = .current,
        othersLabel: String = String(localized: "Others")
    ) -> [InsightGroup] {
        var totals: [String: (label: String, value: Decimal)] = [:]
        for blessing in blessings {
            let key: String
            let label: String
            switch mode {
            case .person:
                key = blessing.blesser?.nameKey ?? "?"
                label = blessing.blesser?.name ?? "?"
            case .month:
                let parts = calendar.dateComponents([.year, .month], from: blessing.date)
                key = String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
                var style = Date.FormatStyle(locale: locale, calendar: calendar)
                style = style.month(.abbreviated).year()
                label = blessing.date.formatted(style)
            case .occasion:
                key = blessing.occasionRaw
                label = blessing.occasion.title
            }
            totals[key, default: (label, 0)].value += blessing.amount
        }
        var sorted = totals.map { (id: $0.key, label: $0.value.label, value: $0.value.value) }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.label < $1.label }
        if sorted.count > maxGroups {
            let rest = sorted[(maxGroups - 1)...].reduce(Decimal(0)) { $0 + $1.value }
            sorted = Array(sorted[..<(maxGroups - 1)]) + [(id: "others", label: othersLabel, value: rest)]
        }
        let percents = percents(sorted.map(\.value))
        return zip(sorted, percents).map { InsightGroup(id: $0.id, label: $0.label, value: $0.value, percent: $1) }
    }

    /// Whole-number percentages that always sum to 100 (largest-remainder method).
    static func percents(_ values: [Decimal]) -> [Int] {
        let total = values.reduce(0, +)
        guard total > 0 else { return values.map { _ in 0 } }
        let exact = values.map { $0 * 100 / total }
        var floors = exact.map { value -> Int in
            var input = value, output = Decimal()
            NSDecimalRound(&output, &input, 0, .down)
            return NSDecimalNumber(decimal: output).intValue
        }
        let leftover = 100 - floors.reduce(0, +)
        let byRemainder = exact.indices.sorted { exact[$0] - Decimal(floors[$0]) > exact[$1] - Decimal(floors[$1]) }
        for index in byRemainder.prefix(max(0, leftover)) { floors[index] += 1 }
        return floors
    }

    /// "{Top occasion} brought in {pct}% of your honeypot."
    static func topOccasionFact(_ blessings: [Blessing]) -> (occasion: Occasion, percent: Int)? {
        var totals: [Occasion: Decimal] = [:]
        for blessing in blessings { totals[blessing.occasion, default: 0] += blessing.amount }
        let total = totals.values.reduce(0, +)
        guard total > 0, let top = totals.max(by: { $0.value < $1.value }) else { return nil }
        var share = top.value * 100 / total, rounded = Decimal()
        NSDecimalRound(&rounded, &share, 0, .plain)
        return (top.key, NSDecimalNumber(decimal: rounded).intValue)
    }
}
