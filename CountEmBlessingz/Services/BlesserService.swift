import SwiftData
import Foundation

struct BlesserStats: Equatable {
    struct YearTotal: Equatable, Identifiable {
        let year: Int
        let total: Decimal
        var id: Int { year }
    }

    let lifetime: Decimal
    let count: Int
    let byYear: [YearTotal]

    var average: Decimal { count == 0 ? 0 : lifetime / Decimal(count) }
}

struct BlesserService {
    enum RenameError: Error, Equatable {
        case empty
        case nameTaken      // another blesser already uses this name; merge instead
    }

    let context: ModelContext

    static func stats(for blesser: Blesser, calendar: Calendar = .current) -> BlesserStats {
        let items = blesser.blessings
        let lifetime = items.reduce(Decimal(0)) { $0 + $1.amount }
        let grouped = Dictionary(grouping: items) { calendar.component(.year, from: $0.date) }
        let byYear = grouped
            .map { BlesserStats.YearTotal(year: $0.key, total: $0.value.reduce(Decimal(0)) { $0 + $1.amount }) }
            .sorted { $0.year < $1.year }
        return BlesserStats(lifetime: lifetime, count: items.count, byYear: byYear)
    }

    /// 1-based rank by lifetime total; earlier `createdAt` wins ties.
    static func rank(of blesser: Blesser, among all: [Blesser]) -> Int {
        func total(_ b: Blesser) -> Decimal { b.blessings.reduce(0) { $0 + $1.amount } }
        let mine = total(blesser)
        let ahead = all.filter { other in
            guard other !== blesser else { return false }
            let theirs = total(other)
            return theirs > mine || (theirs == mine && other.createdAt < blesser.createdAt)
        }
        return ahead.count + 1
    }

    func rename(_ blesser: Blesser, to newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RenameError.empty }
        if let existing = try BlesserResolver(context: context).find(name: trimmed), existing !== blesser {
            throw RenameError.nameTaken
        }
        blesser.name = trimmed
        blesser.nameKey = BlesserResolver.key(for: trimmed)
    }

    /// Moves every blessing from `source` to `target`, then deletes `source`.
    /// The target stays thank-you pending if either blesser was.
    func merge(_ source: Blesser, into target: Blesser) {
        guard source !== target else { return }
        for blessing in source.blessings {
            blessing.blesser = target
            blessing.updatedAt = .now
        }
        target.thankYouPending = target.thankYouPending || source.thankYouPending
        context.delete(source)
    }
}
