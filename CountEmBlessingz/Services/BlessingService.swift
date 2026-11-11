import SwiftData
import UIKit

/// The fields the add/edit sheet edits.
struct BlessingDraft {
    var name = ""
    var amountText = ""
    var occasion: Occasion = .justBecause
    var date: Date?                    // nil = "now" at save time
    var method: PaymentMethod = .cash
    var note = ""
    var photoData: Data?

    enum Problem: Error, Equatable {
        case nameRequired
        case amountInvalid
    }

    init() {}

    init(editing blessing: Blessing) {
        name = blessing.blesser?.name ?? ""
        amountText = MoneyFormatter.plain(blessing.amount)
        occasion = blessing.occasion
        date = blessing.date
        method = blessing.method
        note = blessing.note
        photoData = blessing.photoData
    }

    func parsedAmount(locale: Locale = .current) -> Decimal? {
        MoneyFormatter.parsePositive(amountText, locale: locale)
    }

    func problems(locale: Locale = .current) -> [Problem] {
        var found: [Problem] = []
        if BlesserResolver.key(for: name).isEmpty { found.append(.nameRequired) }
        if parsedAmount(locale: locale) == nil { found.append(.amountInvalid) }
        return found
    }
}

/// Enough to put a deleted blessing back (undo).
struct BlessingSnapshot {
    let id: UUID
    let amount: Decimal
    let currencyCode: String
    let date: Date
    let occasionRaw: String
    let methodRaw: String
    let note: String
    let photoData: Data?
    let originalAmount: Decimal?
    let originalCurrencyCode: String?
    let blesserName: String
    let blesserPending: Bool
}

struct BlessingService {
    struct AddResult {
        let blessing: Blessing
        let crossedMilestone: Decimal?
    }

    let context: ModelContext

    /// Inserts a blessing, marks the blesser thank-you pending and reports any milestone crossed.
    func add(_ draft: BlessingDraft, currency: String, goal: Decimal?, locale: Locale = .current) throws -> AddResult {
        guard let amount = draft.parsedAmount(locale: locale) else { throw BlessingDraft.Problem.amountInvalid }
        guard let blesser = try BlesserResolver(context: context).findOrCreate(name: draft.name) else {
            throw BlessingDraft.Problem.nameRequired
        }
        let before = try context.fetch(FetchDescriptor<Blessing>()).reduce(Decimal(0)) { $0 + $1.amount }
        blesser.thankYouPending = true
        let blessing = Blessing(
            amount: amount, currencyCode: currency, date: draft.date ?? .now,
            occasion: draft.occasion, method: draft.method, note: draft.note,
            photoData: draft.photoData, blesser: blesser
        )
        context.insert(blessing)
        let crossed = MilestoneService.crossed(before: before, after: before + amount, goal: goal)
        return AddResult(blessing: blessing, crossedMilestone: crossed)
    }

    /// Applies an edit. Does not touch `thankYouPending`.
    func update(_ blessing: Blessing, with draft: BlessingDraft, locale: Locale = .current) throws {
        guard let amount = draft.parsedAmount(locale: locale) else { throw BlessingDraft.Problem.amountInvalid }
        guard let target = try BlesserResolver(context: context).findOrCreate(name: draft.name) else {
            throw BlessingDraft.Problem.nameRequired
        }
        let previous = blessing.blesser
        blessing.blesser = target
        blessing.amount = amount
        blessing.date = draft.date ?? blessing.date
        blessing.occasion = draft.occasion
        blessing.method = draft.method
        blessing.note = draft.note
        blessing.photoData = draft.photoData
        if let previous, previous !== target, !previous.blessings.contains(where: { $0 !== blessing }) {
            context.delete(previous)
        }
    }

    /// Deletes a blessing (and its blesser if that was their last one). Returns a snapshot for undo.
    @discardableResult
    func delete(_ blessing: Blessing) -> BlessingSnapshot {
        let snapshot = BlessingSnapshot(
            id: blessing.id, amount: blessing.amount, currencyCode: blessing.currencyCode,
            date: blessing.date, occasionRaw: blessing.occasionRaw, methodRaw: blessing.methodRaw,
            note: blessing.note, photoData: blessing.photoData,
            originalAmount: blessing.originalAmount, originalCurrencyCode: blessing.originalCurrencyCode,
            blesserName: blessing.blesser?.name ?? "", blesserPending: blessing.blesser?.thankYouPending ?? false
        )
        let blesser = blessing.blesser
        context.delete(blessing)
        if let blesser, !blesser.blessings.contains(where: { $0 !== blessing }) {
            context.delete(blesser)
        }
        return snapshot
    }

    func restore(_ snapshot: BlessingSnapshot) throws {
        let blesser = try BlesserResolver(context: context).findOrCreate(name: snapshot.blesserName)
        blesser?.thankYouPending = snapshot.blesserPending
        let blessing = Blessing(amount: snapshot.amount, currencyCode: snapshot.currencyCode, date: snapshot.date)
        blessing.id = snapshot.id
        blessing.occasionRaw = snapshot.occasionRaw
        blessing.methodRaw = snapshot.methodRaw
        blessing.note = snapshot.note
        blessing.photoData = snapshot.photoData
        blessing.originalAmount = snapshot.originalAmount
        blessing.originalCurrencyCode = snapshot.originalCurrencyCode
        blessing.blesser = blesser
        context.insert(blessing)
    }
}

enum ImageDownscaler {
    /// JPEG data no larger than `maxDimension` on its long side.
    static func jpegData(from data: Data, maxDimension: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.8) { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
