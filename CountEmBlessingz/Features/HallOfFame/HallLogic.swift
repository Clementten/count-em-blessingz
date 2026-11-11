import Foundation

struct RankedBlesser: Identifiable {
    let blesser: Blesser
    let total: Decimal
    let rank: Int
    var id: UUID { blesser.id }
}

struct YearReview: Equatable {
    let year: Int
    let total: Decimal
    let count: Int
    let topBlesserName: String?
    let topOccasion: Occasion?
}

enum HallLogic {
    /// Ranked by lifetime total; earlier `createdAt` wins ties.
    static func ranking(_ blessers: [Blesser]) -> [RankedBlesser] {
        var entries: [(blesser: Blesser, total: Decimal)] = []
        for blesser in blessers where !blesser.blessings.isEmpty {
            let total = blesser.blessings.reduce(Decimal(0)) { $0 + $1.amount }
            entries.append((blesser, total))
        }
        entries.sort { lhs, rhs in
            lhs.total != rhs.total ? lhs.total > rhs.total : lhs.blesser.createdAt < rhs.blesser.createdAt
        }
        var ranked: [RankedBlesser] = []
        for (index, entry) in entries.enumerated() {
            ranked.append(RankedBlesser(blesser: entry.blesser, total: entry.total, rank: index + 1))
        }
        return ranked
    }

    static func isReached(_ threshold: Decimal, total: Decimal) -> Bool { total >= threshold }

    /// Review for `year`, or the latest year with data if none is given / the year is empty.
    static func review(_ blessings: [Blessing], preferredYear: Int, calendar: Calendar = .current) -> YearReview? {
        func year(_ b: Blessing) -> Int { calendar.component(.year, from: b.date) }
        var chosen = preferredYear
        if !blessings.contains(where: { year($0) == chosen }) {
            guard let latest = blessings.map(year).max() else { return nil }
            chosen = latest
        }
        let items = blessings.filter { year($0) == chosen }
        var byPerson: [String: Decimal] = [:]
        var byOccasion: [Occasion: Decimal] = [:]
        for item in items {
            byPerson[item.blesser?.name ?? "", default: 0] += item.amount
            byOccasion[item.occasion, default: 0] += item.amount
        }
        return YearReview(
            year: chosen,
            total: items.reduce(0) { $0 + $1.amount },
            count: items.count,
            topBlesserName: byPerson.max { $0.value < $1.value }?.key,
            topOccasion: byOccasion.max { $0.value < $1.value }?.key
        )
    }
}
