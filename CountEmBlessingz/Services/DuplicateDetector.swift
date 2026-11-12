import Foundation

// Pure value types and functions: no SwiftData in here, so the rules can be tested in a table.

struct LocalPerson: Equatable, Hashable {
    let id: UUID
    let name: String
}

enum PersonMatch: Equatable {
    case sameID(LocalPerson)        // the file's person id is a local person's id
    case sameName(LocalPerson)      // same name after normalising (case, spaces, diacritics)
    case similar(LocalPerson)       // close but not the same: NEVER merged automatically
    case new

    /// The person to attach entries to without asking. `similar` is deliberately not included.
    var automaticMatch: LocalPerson? {
        switch self {
        case .sameID(let person), .sameName(let person): person
        case .similar, .new: nil
        }
    }
}

/// An entry already in the pot.
struct LocalEntry: Equatable {
    let id: UUID
    let blesserID: UUID
    let amount: Decimal
    let currencyCode: String
    let date: Date
    let occasion: String
    let method: String
    let note: String
    let updatedAt: Date
    let photoFingerprint: Int?
}

/// An entry from the file, with its amount already converted to the local currency (if that was needed).
struct IncomingEntry: Equatable {
    let id: UUID
    let blesserID: UUID             // the file's person id
    let amount: Decimal
    let date: Date
    let occasion: String
    let method: String
    let note: String
    let updatedAt: Date
    let photoFingerprint: Int?
}

enum EntryStatus: Equatable {
    case new
    case alreadyImported(LocalEntry)
    case updated(LocalEntry)                    // carries the old values
    case possibleDuplicate(LocalEntry)          // carries the entry it resembles
    case duplicateWithinFile(of: UUID)

    /// Ticked when the review screen opens.
    var selectedByDefault: Bool {
        switch self {
        case .new, .updated: true
        case .alreadyImported, .possibleDuplicate, .duplicateWithinFile: false
        }
    }

    /// Cannot be ticked at all.
    var isLocked: Bool {
        if case .alreadyImported = self { return true }
        return false
    }
}

enum DuplicateDetector {
    /// Same person, same amount and dates this close (inclusive) look like the same gift recorded twice.
    static let duplicateWindow: TimeInterval = 72 * 60 * 60

    // MARK: People

    /// Trim, collapse runs of spaces, lowercase, strip diacritics.
    static func normalize(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        return folded
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1]
            for (j, right) in b.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (left == right ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }

    /// Minimum length for the fuzzy rule, so "Mei" never "looks like" "Mei Ling".
    static let fuzzyMinimumLength = 4

    /// In order: same id, same normalised name, similar name, otherwise new.
    static func matchPerson(id: UUID, name: String, among local: [LocalPerson]) -> PersonMatch {
        if let person = local.first(where: { $0.id == id }) { return .sameID(person) }

        let key = normalize(name)
        guard !key.isEmpty else { return .new }
        if let person = local.first(where: { normalize($0.name) == key }) { return .sameName(person) }

        guard key.count >= fuzzyMinimumLength else { return .new }
        var best: (person: LocalPerson, distance: Int)?
        for person in local {
            let other = normalize(person.name)
            guard other.count >= fuzzyMinimumLength else { continue }
            let distance = editDistance(key, other)
            guard distance <= 2 || key.contains(other) || other.contains(key) else { continue }
            if let current = best,
               distance > current.distance || (distance == current.distance && person.name >= current.person.name) {
                continue
            }
            best = (person, distance)
        }
        return best.map { .similar($0.person) } ?? .new
    }

    // MARK: Entries

    private enum PersonKey: Hashable {
        case local(UUID)
        case incoming(UUID)
    }

    /// Status for every incoming entry.
    /// - `resolvedPerson`: the local person an incoming person id will attach to, or nil if a new person is created.
    /// - `currencyCode`: the local currency; amounts are compared after rounding to its minor unit.
    static func classify(
        _ incoming: [IncomingEntry],
        resolvedPerson: (UUID) -> UUID?,
        local: [LocalEntry],
        currencyCode: String
    ) -> [UUID: EntryStatus] {
        let scale = MoneyFormatter.minorUnits(for: currencyCode) == 0 ? 0 : 2
        func same(_ a: Decimal, _ b: Decimal) -> Bool {
            MoneyFormatter.round(a, scale: scale) == MoneyFormatter.round(b, scale: scale)
        }
        func close(_ a: Date, _ b: Date) -> Bool { abs(a.timeIntervalSince(b)) <= duplicateWindow }
        func key(_ entry: IncomingEntry) -> PersonKey {
            resolvedPerson(entry.blesserID).map(PersonKey.local) ?? .incoming(entry.blesserID)
        }

        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [UUID: EntryStatus] = [:]

        // 1. Same id as something already in the pot.
        for entry in incoming {
            guard let existing = localByID[entry.id] else { continue }
            let newer = entry.updatedAt > existing.updatedAt
            let changed = resolvedPerson(entry.blesserID) != existing.blesserID
                || !same(entry.amount, existing.amount)
                || abs(entry.date.timeIntervalSince(existing.date)) >= 1     // files keep milliseconds only
                || entry.occasion != existing.occasion
                || entry.method != existing.method
                || entry.note != existing.note
                || entry.photoFingerprint != existing.photoFingerprint
            result[entry.id] = newer && changed ? .updated(existing) : .alreadyImported(existing)
        }

        // 2. Everything else, oldest first so "the later one" of a pair is the one that gets flagged.
        let remaining = incoming.enumerated()
            .filter { result[$0.element.id] == nil }
            .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element)

        var seen: [PersonKey: [IncomingEntry]] = [:]
        for entry in remaining {
            let person = key(entry)
            if let earlier = seen[person]?.first(where: { same($0.amount, entry.amount) && close($0.date, entry.date) }) {
                result[entry.id] = .duplicateWithinFile(of: earlier.id)
            } else if let localPerson = resolvedPerson(entry.blesserID),
                      let match = local
                        .filter({ $0.blesserID == localPerson && same($0.amount, entry.amount) && close($0.date, entry.date) })
                        .min(by: { abs($0.date.timeIntervalSince(entry.date)) < abs($1.date.timeIntervalSince(entry.date)) }) {
                result[entry.id] = .possibleDuplicate(match)
            } else {
                result[entry.id] = .new
            }
            seen[person, default: []].append(entry)
        }
        return result
    }
}
