import Testing
import Foundation
@testable import CountEmBlessingz

private let hour: TimeInterval = 3_600
private let day: TimeInterval = 86_400
private let t0 = Date(timeIntervalSince1970: 1_750_000_000)

private let meiID = UUID(), tanID = UUID(), fileMei = UUID(), fileTan = UUID()

private func local(_ id: UUID = UUID(), person: UUID = meiID, amount: Decimal = 100, at date: Date = t0,
                   occasion: String = "birthday", note: String = "", updated: Date = t0, photo: Int? = nil) -> LocalEntry {
    LocalEntry(id: id, blesserID: person, amount: amount, currencyCode: "MYR", date: date, occasion: occasion,
               method: "cash", note: note, updatedAt: updated, photoFingerprint: photo)
}

private func incoming(_ id: UUID = UUID(), person: UUID = fileMei, amount: Decimal = 100, at date: Date = t0,
                      occasion: String = "birthday", note: String = "", updated: Date = t0, photo: Int? = nil) -> IncomingEntry {
    IncomingEntry(id: id, blesserID: person, amount: amount, date: date, occasion: occasion,
                  method: "cash", note: note, updatedAt: updated, photoFingerprint: photo)
}

/// File person `fileMei` is Aunt Mei here; `fileTan` is not matched to anyone.
private let resolveMei: (UUID) -> UUID? = { $0 == fileMei ? meiID : nil }

private func classify(_ entries: [IncomingEntry], local: [LocalEntry], currency: String = "MYR",
                      resolve: @escaping (UUID) -> UUID? = resolveMei) -> [UUID: EntryStatus] {
    DuplicateDetector.classify(entries, resolvedPerson: resolve, local: local, currencyCode: currency)
}

// MARK: - Person matching

struct PersonMatchTests {
    private let people = [
        LocalPerson(id: meiID, name: "Aunt Mei"),
        LocalPerson(id: tanID, name: "Uncle Tan"),
        LocalPerson(id: UUID(), name: "Zoe"),
    ]

    private enum Expect { case sameID, sameName, similar(String), new }

    @Test(arguments: [
        ("aunt  mei", "sameName"), ("  AUNT MEI ", "sameName"), ("Zoë", "sameName"), ("ZOE", "sameName"),
        ("Aunty Mei", "similar:Aunt Mei"), ("Aunt Mei Lin", "similar:Aunt Mei"),
        ("Uncle Tam", "similar:Uncle Tan"), ("Uncle Tanaka", "similar:Uncle Tan"),
        ("Mei", "new"), ("Bob", "new"), ("", "new"), ("   ", "new"), ("Cousin Lin", "new"),
    ])
    func byName(name: String, expected: String) {
        let match = DuplicateDetector.matchPerson(id: UUID(), name: name, among: people)
        switch match {
        case .sameName: #expect(expected == "sameName", "\(name)")
        case .similar(let person): #expect(expected == "similar:\(person.name)", "\(name)")
        case .new: #expect(expected == "new", "\(name)")
        case .sameID: Issue.record("unexpected id match for \(name)")
        }
    }

    @Test func sameIDWinsEvenWhenTheNameDiffers() {
        let match = DuplicateDetector.matchPerson(id: meiID, name: "Somebody Else", among: people)
        #expect(match == .sameID(people[0]))
        #expect(match.automaticMatch == people[0])
    }

    @Test func similarIsNeverAnAutomaticMatch() {
        let match = DuplicateDetector.matchPerson(id: UUID(), name: "Aunty Mei", among: people)
        #expect(match == .similar(people[0]))
        #expect(match.automaticMatch == nil)
        #expect(PersonMatch.new.automaticMatch == nil)
    }

    @Test func fuzzyRuleNeedsFourCharactersOnBothSides() {
        let short = [LocalPerson(id: UUID(), name: "Mei")]
        #expect(DuplicateDetector.matchPerson(id: UUID(), name: "Mei Ling", among: short) == .new)
        #expect(DuplicateDetector.matchPerson(id: UUID(), name: "Mea", among: short) == .new)
    }

    @Test func closestSimilarWins() {
        let list = [LocalPerson(id: UUID(), name: "Uncle Tanner"), LocalPerson(id: UUID(), name: "Uncle Tan")]
        guard case .similar(let person) = DuplicateDetector.matchPerson(id: UUID(), name: "Uncle Tam", among: list) else {
            Issue.record("expected similar"); return
        }
        #expect(person.name == "Uncle Tan")
    }

    @Test(arguments: [("", "", 0), ("abc", "", 3), ("kitten", "sitting", 3), ("aunt mei", "aunty mei", 1), ("same", "same", 0)])
    func editDistance(a: String, b: String, expected: Int) {
        #expect(DuplicateDetector.editDistance(a, b) == expected)
        #expect(DuplicateDetector.editDistance(b, a) == expected)
    }

    @Test func normalizeCollapsesAndFolds() {
        #expect(DuplicateDetector.normalize("  Ünclé   TAN\n") == "uncle tan")
    }
}

// MARK: - Entry status

struct EntryStatusTests {
    @Test func windowConstantIs72Hours() {
        #expect(DuplicateDetector.duplicateWindow == 72 * hour)
    }

    @Test(arguments: [
        (0.0, "possible"), (1.0, "possible"), (71.0, "possible"), (72.0, "possible"),     // inclusive boundary
        (72.0 + 1.0 / 3600, "new"), (73.0, "new"), (24.0 * 365, "new"),                     // a year later is a genuine repeat
        (-72.0, "possible"), (-73.0, "new"),                                                // either direction
    ])
    func windowBoundary(hoursApart: Double, expected: String) {
        let existing = local()
        let entry = incoming(at: t0.addingTimeInterval(hoursApart * hour))
        let status = classify([entry], local: [existing])[entry.id]
        switch status {
        case .possibleDuplicate(let match): #expect(expected == "possible" && match.id == existing.id, "\(hoursApart)h")
        case .new: #expect(expected == "new", "\(hoursApart)h")
        default: Issue.record("unexpected \(String(describing: status))")
        }
    }

    @Test func possibleDuplicateIsUnselectedButNotLocked() {
        let entry = incoming()
        let status = try! #require(classify([entry], local: [local()])[entry.id])
        #expect(!status.selectedByDefault && !status.isLocked)
    }

    @Test func newAndUpdatedAreSelectedAndAlreadyImportedIsLocked() {
        #expect(EntryStatus.new.selectedByDefault && !EntryStatus.new.isLocked)
        let any = local()
        #expect(EntryStatus.updated(any).selectedByDefault && !EntryStatus.updated(any).isLocked)
        #expect(!EntryStatus.alreadyImported(any).selectedByDefault && EntryStatus.alreadyImported(any).isLocked)
        #expect(!EntryStatus.duplicateWithinFile(of: UUID()).selectedByDefault)
    }

    @Test func differentAmountOrDifferentPersonIsNew() {
        let a = incoming(amount: 101), b = incoming(person: fileTan)
        let result = classify([a, b], local: [local()])
        #expect(result[a.id] == .new && result[b.id] == .new)
    }

    @Test func unmatchedPersonNeverFlagsAgainstLocalEntries() {
        let entry = incoming(person: fileTan)          // resolves to nil: a new person
        #expect(classify([entry], local: [local()])[entry.id] == .new)
    }

    @Test func nearestLocalEntryIsReported() {
        let far = local(at: t0.addingTimeInterval(-60 * hour)), near = local(at: t0.addingTimeInterval(2 * hour))
        let entry = incoming()
        #expect(classify([entry], local: [far, near])[entry.id] == .possibleDuplicate(near))
    }

    // Amounts are compared after rounding to the currency's minor unit.
    @Test(arguments: [
        ("MYR", "100.004", "100", true), ("MYR", "100.005", "100", false), ("MYR", "186.48", "186.48", true),
        ("JPY", "100.4", "100", true), ("JPY", "100.5", "100", false), ("USD", "2052.96", "2052.96", true),
    ])
    func comparedAfterRounding(currency: String, incomingAmount: String, localAmount: String, isDuplicate: Bool) {
        let entry = incoming(amount: Decimal(string: incomingAmount)!)
        let existing = local(amount: Decimal(string: localAmount)!)
        let status = classify([entry], local: [existing], currency: currency)[entry.id]
        #expect((status == .possibleDuplicate(existing)) == isDuplicate, "\(incomingAmount) vs \(localAmount) \(currency)")
    }

    // MARK: same id

    @Test(arguments: [(-1.0, "already"), (0.0, "already")])
    func sameIDAndNotNewerIsAlreadyImported(secondsNewer: Double, expected: String) {
        let id = UUID()
        let existing = local(id, amount: 100, updated: t0)
        let entry = incoming(id, amount: 999, updated: t0.addingTimeInterval(secondsNewer))      // different content, but not newer
        #expect(classify([entry], local: [existing])[entry.id] == .alreadyImported(existing))
    }

    @Test func sameIDNewerAndChangedIsUpdated() {
        let id = UUID()
        let existing = local(id, amount: 100, updated: t0)
        let entry = incoming(id, amount: 150, updated: t0.addingTimeInterval(60))
        #expect(classify([entry], local: [existing])[entry.id] == .updated(existing))
    }

    @Test(arguments: ["amount", "date", "occasion", "note", "photo", "person"])
    func anyChangedFieldCountsAsUpdated(field: String) {
        let id = UUID()
        let existing = local(id, updated: t0)
        let entry = incoming(
            id,
            person: field == "person" ? fileTan : fileMei,
            amount: field == "amount" ? 120 : 100,
            at: field == "date" ? t0.addingTimeInterval(day) : t0,
            occasion: field == "occasion" ? "wedding" : "birthday",
            note: field == "note" ? "changed" : "",
            updated: t0.addingTimeInterval(60),
            photo: field == "photo" ? 42 : nil
        )
        let resolve: (UUID) -> UUID? = { $0 == fileMei ? meiID : ($0 == fileTan ? tanID : nil) }
        #expect(classify([entry], local: [existing], resolve: resolve)[entry.id] == .updated(existing), "\(field)")
    }

    @Test func sameIDNewerButIdenticalContentIsAlreadyImported() {
        let id = UUID()
        let existing = local(id, updated: t0)
        let entry = incoming(id, updated: t0.addingTimeInterval(60))
        #expect(classify([entry], local: [existing])[entry.id] == .alreadyImported(existing))
    }

    @Test func millisecondTruncatedDatesDoNotCountAsChanges() {
        let id = UUID()
        let existing = local(id, at: t0.addingTimeInterval(0.7345), updated: t0)
        let entry = incoming(id, at: t0.addingTimeInterval(0.734), updated: t0.addingTimeInterval(60))
        #expect(classify([entry], local: [existing])[entry.id] == .alreadyImported(existing))
    }

    @Test func idMatchAppliesEvenForAnUnrelatedPerson() {
        let id = UUID()
        let existing = local(id, person: tanID, updated: t0)
        let entry = incoming(id, person: fileTan, updated: t0)
        #expect(classify([entry], local: [existing], resolve: { _ in tanID })[entry.id] == .alreadyImported(existing))
    }

    // MARK: within the file

    @Test func laterOfTwoMatchingEntriesInTheFileIsFlagged() {
        let first = incoming(at: t0), second = incoming(at: t0.addingTimeInterval(10 * hour))
        let result = classify([second, first], local: [])            // order in the file doesn't matter
        #expect(result[first.id] == .new)
        #expect(result[second.id] == .duplicateWithinFile(of: first.id))
        #expect(!result[second.id]!.selectedByDefault)
    }

    @Test func withinFileAlsoAppliesToANewPerson() {
        let a = incoming(person: fileTan), b = incoming(person: fileTan, at: t0.addingTimeInterval(day))
        let result = classify([a, b], local: [])
        #expect(result[a.id] == .new && result[b.id] == .duplicateWithinFile(of: a.id))
    }

    @Test func repeatsFarApartOrForDifferentPeopleAreBothNew() {
        let a = incoming(), b = incoming(at: t0.addingTimeInterval(365 * day)), c = incoming(person: fileTan)
        let result = classify([a, b, c], local: [])
        #expect(result[a.id] == .new && result[b.id] == .new && result[c.id] == .new)
    }

    @Test func chainsAreFlaggedStepByStep() {
        let a = incoming(at: t0), b = incoming(at: t0.addingTimeInterval(60 * hour)), c = incoming(at: t0.addingTimeInterval(120 * hour))
        let result = classify([a, b, c], local: [])
        #expect(result[a.id] == .new)
        #expect(result[b.id] == .duplicateWithinFile(of: a.id))
        #expect(result[c.id] == .duplicateWithinFile(of: b.id))
    }

    @Test func everyIncomingEntryGetsAStatus() {
        let entries = (0..<20).map { incoming(amount: Decimal($0 + 1)) }
        #expect(classify(entries, local: []).count == 20)
    }
}
