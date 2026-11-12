import Foundation

// The review screen's model. Plain values only: it is built from the database once, and every change the
// user makes in the review (ticks, person choices, exchange rate) is a pure update. Nothing is written.

enum PersonMapping: Equatable {
    case existing(LocalPerson)      // add to this person
    case createNew                  // create a person from the file

    var existingPerson: LocalPerson? {
        if case .existing(let person) = self { person } else { nil }
    }
}

enum CurrencyDecision: Equatable {
    case notNeeded                  // same currency as the pot
    case undecided                  // different currency, the user hasn't chosen yet
    case rate(Decimal)              // 1 file-currency = rate local-currency
    case importNumbers              // keep the numbers, label them in the local currency
}

/// What is already in the pot, captured when the plan is built.
struct LocalSnapshot: Equatable {
    var persons: [LocalPerson]
    var entries: [LocalEntry]

    func entries(of person: LocalPerson) -> [LocalEntry] { entries.filter { $0.blesserID == person.id } }
    func last(of person: LocalPerson) -> LocalEntry? { entries(of: person).max { $0.date < $1.date } }
}

struct PlanPerson: Identifiable, Equatable {
    let id: UUID                    // the person's id in the file
    let name: String
    let match: PersonMatch
    var mapping: PersonMapping

    var similarCandidate: LocalPerson? {
        if case .similar(let person) = match { person } else { nil }
    }

    /// The local person whose history to show: where entries will go, or the lookalike being considered.
    var historyPerson: LocalPerson? { mapping.existingPerson ?? similarCandidate }
}

struct PlanItem: Identifiable, Equatable {
    let dto: ExchangeFile.BlessingDTO
    let personID: UUID
    let entry: IncomingEntry        // amount already converted to the local currency
    let status: EntryStatus
    var isSelected: Bool

    var id: UUID { dto.id }
    var isLocked: Bool { status.isLocked }
}

struct ImportPlan {
    struct Source: Equatable {
        let exportedBy: String
        let exportedAt: Date
        let deviceID: UUID
        let fileCurrency: String
        let kind: ExchangeFile.Kind
    }

    struct Summary: Equatable {
        let total: Int
        let new: Int
        let updated: Int
        let possibleDuplicates: Int     // includes duplicates inside the file
        let alreadyInPot: Int
    }

    let source: Source
    let localCurrency: String
    let skippedWithoutPerson: Int       // entries in the file that name no person; they cannot be imported
    private let local: LocalSnapshot
    private let dtos: [ExchangeFile.BlessingDTO]
    private let fileBlessers: [UUID: ExchangeFile.BlesserDTO]
    private var overrides: [UUID: Bool] = [:]

    private(set) var currency: CurrencyDecision
    private(set) var persons: [PlanPerson]
    private(set) var items: [PlanItem]

    init(file: ExchangeFile, localCurrency: String, local: LocalSnapshot) {
        source = Source(exportedBy: file.exportedBy, exportedAt: file.exportedAt, deviceID: file.deviceID,
                        fileCurrency: file.currencyCode, kind: file.kind)
        self.localCurrency = localCurrency
        self.local = local
        let withPerson = file.blessings.filter { $0.blesserID != nil }
        skippedWithoutPerson = file.blessings.count - withPerson.count
        dtos = withPerson
        fileBlessers = Dictionary(file.blessers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        currency = file.currencyCode == localCurrency ? .notNeeded : .undecided

        let usedIDs = Set(withPerson.compactMap(\.blesserID))
        persons = file.blessers
            .filter { usedIDs.contains($0.id) }
            .map { dto in
                let match = DuplicateDetector.matchPerson(id: dto.id, name: dto.name, among: local.persons)
                return PlanPerson(id: dto.id, name: dto.name, match: match,
                                  mapping: match.automaticMatch.map(PersonMapping.existing) ?? .createNew)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        items = []
        reclassify()
    }

    // MARK: Changes the review can make

    var needsCurrencyDecision: Bool { source.fileCurrency != localCurrency }
    var isReady: Bool { currency != .undecided }

    mutating func setCurrency(_ decision: CurrencyDecision) {
        guard needsCurrencyDecision else { return }
        currency = decision
        reclassify()
    }

    mutating func setMapping(person id: UUID, _ mapping: PersonMapping) {
        guard let index = persons.firstIndex(where: { $0.id == id }) else { return }
        persons[index].mapping = mapping
        reclassify()
    }

    mutating func setSelected(item id: UUID, _ isSelected: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isLocked else { return }
        overrides[id] = isSelected
        items[index].isSelected = isSelected
    }

    mutating func setSelected(person id: UUID, _ isSelected: Bool) {
        for item in items where item.personID == id && !item.isLocked { setSelected(item: item.id, isSelected) }
    }

    mutating func selectAllNew() {
        for item in items where item.status == .new { setSelected(item: item.id, true) }
    }

    mutating func selectAll() {
        for item in items where !item.isLocked { setSelected(item: item.id, true) }
    }

    mutating func selectNone() {
        for item in items where !item.isLocked { setSelected(item: item.id, false) }
    }

    // MARK: Reading the plan

    func person(_ id: UUID) -> PlanPerson? { persons.first { $0.id == id } }
    func items(of person: UUID) -> [PlanItem] { items.filter { $0.personID == person } }

    /// How many blessings the person's local match already has, and their latest one.
    func history(of person: PlanPerson) -> (count: Int, last: LocalEntry?)? {
        guard let existing = person.historyPerson else { return nil }
        return (local.entries(of: existing).count, local.last(of: existing))
    }

    /// Tri-state for a person's checkbox: nil = some selected.
    func selection(of person: UUID) -> Bool? {
        let selectable = items(of: person).filter { !$0.isLocked }
        guard !selectable.isEmpty else { return false }
        let selected = selectable.filter(\.isSelected).count
        return selected == 0 ? false : (selected == selectable.count ? true : nil)
    }

    var itemsToImport: [PlanItem] { items.filter { $0.isSelected && !$0.isLocked } }
    var selectedCount: Int { itemsToImport.count }
    var selectableCount: Int { items.filter { !$0.isLocked }.count }
    var selectedSum: Decimal { itemsToImport.reduce(0) { $0 + $1.entry.amount } }

    /// Persons that will be created: mapped to "new" and with at least one entry being imported.
    var newPersonIDs: [UUID] {
        let used = Set(itemsToImport.map(\.personID))
        return persons.filter { $0.mapping == .createNew && used.contains($0.id) }.map(\.id)
    }

    var summary: Summary {
        var new = 0, updated = 0, possible = 0, already = 0
        for item in items {
            switch item.status {
            case .new: new += 1
            case .updated: updated += 1
            case .possibleDuplicate, .duplicateWithinFile: possible += 1
            case .alreadyImported: already += 1
            }
        }
        return Summary(total: items.count, new: new, updated: updated, possibleDuplicates: possible, alreadyInPot: already)
    }

    /// Whether an entry's amount was changed by an exchange rate (so its original is recorded).
    var convertsAmounts: Bool {
        if case .rate = currency { return needsCurrencyDecision }
        return false
    }

    func fileBlesser(_ id: UUID) -> ExchangeFile.BlesserDTO? { fileBlessers[id] }

    // MARK: Classification

    private func incomingEntry(_ dto: ExchangeFile.BlessingDTO) -> IncomingEntry {
        var amount = dto.amount
        if needsCurrencyDecision {
            if case .rate(let rate) = currency { amount = amount * rate }
            amount = MoneyFormatter.round(amount, currency: localCurrency)
        }
        return IncomingEntry(
            id: dto.id, blesserID: dto.blesserID ?? UUID(), amount: amount, date: dto.date,
            occasion: dto.occasion, method: dto.method, note: dto.note, updatedAt: dto.updatedAt,
            photoFingerprint: dto.photo?.hashValue
        )
    }

    /// Re-runs duplicate detection (after a rate or person choice), keeping the user's ticks.
    private mutating func reclassify() {
        let converted = dtos.map(incomingEntry)
        let mapped = Dictionary(persons.map { ($0.id, $0.mapping.existingPerson?.id) }, uniquingKeysWith: { first, _ in first })
        let statuses = DuplicateDetector.classify(
            converted, resolvedPerson: { mapped[$0].flatMap { $0 } }, local: local.entries, currencyCode: localCurrency
        )
        items = zip(dtos, converted).map { dto, entry in
            let status = statuses[dto.id] ?? .new
            let selected = status.isLocked ? false : (overrides[dto.id] ?? status.selectedByDefault)
            return PlanItem(dto: dto, personID: dto.blesserID ?? UUID(), entry: entry, status: status, isSelected: selected)
        }
    }
}
