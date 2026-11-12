import SwiftData
import Foundation

enum ImportError: LocalizedError, Equatable {
    case currencyUndecided
    case nothingSelected
    case nothingToUndo

    var errorDescription: String? {
        switch self {
        case .currencyUndecided:
            String(localized: "Choose an exchange rate, or import the numbers as they are.")
        case .nothingSelected:
            String(localized: "Nothing is selected to import.")
        case .nothingToUndo:
            String(localized: "There's no recent import to undo.")
        }
    }
}

struct ImportResult: Equatable {
    let addedCount: Int
    let updatedCount: Int
    let newPeopleCount: Int
    let crossedMilestone: Decimal?

    var importedCount: Int { addedCount + updatedCount }
}

struct ImportSnapshotInfo: Equatable {
    let url: URL
    let date: Date
}

/// Merge import: builds a read-only plan, then writes it in one transaction after taking a snapshot.
/// Import only adds or updates entries. It never deletes anything and never carries deletions over.
struct ImportService {
    static let snapshotsToKeep = 3
    static let undoWindow: TimeInterval = 7 * 24 * 60 * 60

    let context: ModelContext
    var snapshotDirectory: URL = ImportService.defaultSnapshotDirectory
    var now: () -> Date = { .now }

    static var defaultSnapshotDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "ImportSnapshots", directoryHint: .isDirectory)
    }

    // MARK: Plan (no writes)

    /// Reads what is in the pot and compares it with the file. Writes nothing.
    func buildPlan(file: ExchangeFile) throws -> ImportPlan {
        let settings = try context.fetch(FetchDescriptor<AppSettings>()).first
        let blessers = try context.fetch(FetchDescriptor<Blesser>())
        let blessings = try context.fetch(FetchDescriptor<Blessing>())
        let incomingIDs = Set(file.blessings.map(\.id))

        let entries: [LocalEntry] = blessings.compactMap { blessing in
            guard let blesser = blessing.blesser else { return nil }
            return LocalEntry(
                id: blessing.id, blesserID: blesser.id, amount: blessing.amount, currencyCode: blessing.currencyCode,
                date: blessing.date, occasion: blessing.occasionRaw, method: blessing.methodRaw, note: blessing.note,
                updatedAt: blessing.updatedAt,
                // Only entries that might be matched by id need a photo fingerprint (reading photos is not free).
                photoFingerprint: incomingIDs.contains(blessing.id) ? blessing.photoData?.hashValue : nil
            )
        }
        let local = LocalSnapshot(persons: blessers.map { LocalPerson(id: $0.id, name: $0.name) }, entries: entries)
        return ImportPlan(file: file, localCurrency: settings?.currencyCode ?? "MYR", local: local)
    }

    /// Convenience: decode then plan. Errors leave the store untouched.
    func plan(from data: Data) throws -> ImportPlan {
        try buildPlan(file: ExchangeFileCodec.decode(data))
    }

    // MARK: Commit

    /// Applies the selected entries. Order: snapshot, then one transaction, then the milestone check.
    @discardableResult
    func commit(_ plan: ImportPlan) throws -> ImportResult {
        guard plan.isReady else { throw ImportError.currencyUndecided }
        let selected = plan.itemsToImport
        guard !selected.isEmpty else { throw ImportError.nothingSelected }

        // 1. Safety net first: if this fails nothing has been touched.
        try writeSnapshot()

        let settings = try context.fetch(FetchDescriptor<AppSettings>()).first
        let localCurrency = plan.localCurrency
        let goal = settings?.goal
        let existingBlessings = try context.fetch(FetchDescriptor<Blessing>())
        let before = existingBlessings.reduce(Decimal(0)) { $0 + $1.amount }
        var blessingsByID = Dictionary(existingBlessings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var blessersByID = Dictionary(
            try context.fetch(FetchDescriptor<Blesser>()).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )

        var added = 0, updated = 0
        var createdPeople = Set<UUID>()
        do {
            // 2. Everything in one transaction.
            try context.transaction {
                func blesser(for item: PlanItem) -> Blesser? {
                    let person = plan.person(item.personID)
                    if case .existing(let local)? = person?.mapping, let found = blessersByID[local.id] { return found }
                    // New person: keep the file's id and name. Imported people don't start as "thank-you pending".
                    if let found = blessersByID[item.personID] { return found }
                    guard let name = person?.name ?? plan.fileBlesser(item.personID)?.name else { return nil }
                    let created = Blesser(name: name)
                    created.id = item.personID
                    created.thankYouPending = false
                    context.insert(created)
                    blessersByID[created.id] = created
                    createdPeople.insert(created.id)
                    return created
                }

                var touchedPrevious: [Blesser] = []
                for item in selected {
                    guard let target = blesser(for: item) else { continue }
                    let dto = item.dto
                    let converted = plan.convertsAmounts

                    if case .updated = item.status, let existing = blessingsByID[dto.id] {
                        if let previous = existing.blesser, previous !== target { touchedPrevious.append(previous) }
                        existing.blesser = target
                        apply(item, to: existing, localCurrency: localCurrency, converted: converted)
                        updated += 1
                    } else {
                        let blessing = Blessing(amount: item.entry.amount, currencyCode: localCurrency, date: dto.date)
                        blessing.id = dto.id
                        context.insert(blessing)
                        apply(item, to: blessing, localCurrency: localCurrency, converted: converted)
                        blessing.blesser = target
                        blessingsByID[dto.id] = blessing
                        added += 1
                    }
                }
                // A person left with no entries after one moved away is removed, as everywhere else.
                for previous in touchedPrevious where previous.blessings.isEmpty { context.delete(previous) }
            }
        } catch {
            context.rollback()
            throw error
        }

        // 3. Milestone check on the pot's total before and after.
        let after = try context.fetch(FetchDescriptor<Blessing>()).reduce(Decimal(0)) { $0 + $1.amount }
        return ImportResult(
            addedCount: added, updatedCount: updated, newPeopleCount: createdPeople.count,
            crossedMilestone: MilestoneService.crossed(before: before, after: after, goal: goal)
        )
    }

    private func apply(_ item: PlanItem, to blessing: Blessing, localCurrency: String, converted: Bool) {
        let dto = item.dto
        blessing.amount = item.entry.amount
        blessing.currencyCode = localCurrency
        blessing.date = dto.date
        blessing.occasionRaw = dto.occasion
        blessing.methodRaw = dto.method
        blessing.note = dto.note
        blessing.photoData = dto.photo
        blessing.updatedAt = dto.updatedAt
        if converted {
            blessing.originalAmount = dto.amount
            blessing.originalCurrencyCode = dto.currencyCode
        }
    }

    // MARK: Snapshots and undo

    private func snapshotName(for date: Date) -> String {
        "ImportSnapshot-\(Int64(date.timeIntervalSince1970 * 1000)).\(ExchangeFile.fileExtension)"
    }

    private func snapshots() -> [ImportSnapshotInfo] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: snapshotDirectory, includingPropertiesForKeys: nil)) ?? []
        return urls.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("ImportSnapshot-"), let millis = Int64(name.dropFirst("ImportSnapshot-".count)) else { return nil }
            return ImportSnapshotInfo(url: url, date: Date(timeIntervalSince1970: Double(millis) / 1000))
        }
        .sorted { $0.date > $1.date }
    }

    /// A full backup of the pot, written before every import. Only the newest few are kept.
    private func writeSnapshot() throws {
        try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        let data = try ExportService(context: context).backupData(now: now())
        try data.write(to: snapshotDirectory.appending(path: snapshotName(for: now())), options: .atomic)
        for old in snapshots().dropFirst(Self.snapshotsToKeep) { try? FileManager.default.removeItem(at: old.url) }
    }

    /// The snapshot "Undo last import" would restore: the newest one, if it is under 7 days old.
    func latestSnapshot() -> ImportSnapshotInfo? {
        guard let newest = snapshots().first, now().timeIntervalSince(newest.date) < Self.undoWindow else { return nil }
        return newest
    }

    /// Restores the newest snapshot. Everything in the pot goes back to how it was just before that import.
    func undoLastImport() throws {
        guard let snapshot = latestSnapshot() else { throw ImportError.nothingToUndo }
        let data = try Data(contentsOf: snapshot.url)
        try ExportService(context: context).restore(from: data)
        try? FileManager.default.removeItem(at: snapshot.url)
    }
}
