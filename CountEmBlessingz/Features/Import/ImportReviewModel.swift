import SwiftUI
import SwiftData

enum ImportFilter: String, CaseIterable, Identifiable {
    case all, new, possibleDuplicates, alreadyInPot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .new: String(localized: "New")
        case .possibleDuplicates: String(localized: "Possible duplicates")
        case .alreadyInPot: String(localized: "Already in pot")
        }
    }

    /// "New" also covers entries that will update an existing one: both are things that will change.
    func matches(_ status: EntryStatus) -> Bool {
        switch (self, status) {
        case (.all, _): true
        case (.new, .new), (.new, .updated): true
        case (.possibleDuplicates, .possibleDuplicate), (.possibleDuplicates, .duplicateWithinFile): true
        case (.alreadyInPot, .alreadyImported): true
        default: false
        }
    }
}

/// What the review screen shows and edits. All real work is in `ImportPlan`.
@MainActor @Observable
final class ImportReviewModel: Identifiable {
    let id = UUID()
    var plan: ImportPlan
    var filter: ImportFilter = .all
    var search = ""

    init(plan: ImportPlan) {
        self.plan = plan
    }

    /// Entries that pass the filter and the search.
    func visibleItems(of person: PlanPerson) -> [PlanItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return plan.items(of: person.id).filter { item in
            guard filter.matches(item.status) else { return false }
            guard !query.isEmpty else { return true }
            let occasion = Occasion(rawValue: item.dto.occasion)?.title ?? item.dto.occasion
            return person.name.localizedCaseInsensitiveContains(query)
                || item.dto.note.localizedCaseInsensitiveContains(query)
                || occasion.localizedCaseInsensitiveContains(query)
        }
    }

    /// People with at least one visible entry.
    var visiblePersons: [PlanPerson] {
        plan.persons.filter { !visibleItems(of: $0).isEmpty }
    }
}

/// Receives a file (opened from AirDrop, Messages, Files, or picked in Settings), reads it off the main
/// thread and opens the review. Anything wrong is reported and nothing is touched.
@MainActor @Observable
final class ImportCoordinator {
    var pendingURL: URL?
    var session: ImportReviewModel?
    var errorMessage: String?
    private(set) var isLoading = false

    func receive(_ url: URL) {
        pendingURL = url
    }

    func process(context: ModelContext) async {
        guard let url = pendingURL else { return }
        pendingURL = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let file = try await ExchangeFileLoader.load(url: url)
            session = ImportReviewModel(plan: try ImportService(context: context).buildPlan(file: file))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "That file couldn't be opened.")
        }
    }
}
