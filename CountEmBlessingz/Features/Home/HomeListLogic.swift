import Foundation

enum BlessingSort: String, CaseIterable, Identifiable {
    case newest, largest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: String(localized: "Newest")
        case .largest: String(localized: "Largest")
        }
    }
}

struct BlessingSection: Identifiable {
    let id: String
    let title: String
    let blessings: [Blessing]
}

enum HomeListLogic {
    static func total(_ blessings: [Blessing]) -> Decimal {
        blessings.reduce(0) { $0 + $1.amount }
    }

    static func monthTotal(_ blessings: [Blessing], now: Date = .now, calendar: Calendar = .current) -> Decimal {
        total(blessings.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) })
    }

    /// Search over name, note and occasion; optional "this year" filter.
    static func filter(
        _ blessings: [Blessing], query: String, thisYearOnly: Bool,
        now: Date = .now, calendar: Calendar = .current
    ) -> [Blessing] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return blessings.filter { blessing in
            if thisYearOnly, !calendar.isDate(blessing.date, equalTo: now, toGranularity: .year) { return false }
            guard !needle.isEmpty else { return true }
            return (blessing.blesser?.name.localizedCaseInsensitiveContains(needle) ?? false)
                || blessing.note.localizedCaseInsensitiveContains(needle)
                || blessing.occasion.title.localizedCaseInsensitiveContains(needle)
        }
    }

    /// Newest: grouped by month, newest first. Largest: one flat section.
    static func sections(
        _ blessings: [Blessing], sort: BlessingSort,
        calendar: Calendar = .current, locale: Locale = .current
    ) -> [BlessingSection] {
        switch sort {
        case .largest:
            guard !blessings.isEmpty else { return [] }
            return [BlessingSection(id: "all", title: "", blessings: blessings.sorted { $0.amount > $1.amount })]
        case .newest:
            let sorted = blessings.sorted { $0.date > $1.date }
            let grouped = Dictionary(grouping: sorted) { blessing -> String in
                let parts = calendar.dateComponents([.year, .month], from: blessing.date)
                return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
            }
            return grouped.keys.sorted(by: >).compactMap { key in
                guard let items = grouped[key], let first = items.first else { return nil }
                var style = Date.FormatStyle(locale: locale, calendar: calendar)
                style = style.month(.abbreviated).year()
                return BlessingSection(id: key, title: first.date.formatted(style), blessings: items)
            }
        }
    }
}
