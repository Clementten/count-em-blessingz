import SwiftData
import Foundation

@Model
final class Blessing {
    @Attribute(.unique) var id: UUID
    var amount: Decimal                  // in the CURRENT currency (AppSettings.currencyCode)
    var currencyCode: String             // ISO 4217; kept equal to current currency
    var date: Date                       // auto-set to now, editable
    var occasionRaw: String              // Occasion.rawValue
    var methodRaw: String                // PaymentMethod.rawValue
    var note: String
    @Attribute(.externalStorage) var photoData: Data?
    var originalAmount: Decimal?         // set on first currency conversion, never overwritten
    var originalCurrencyCode: String?
    var blesser: Blesser?

    var occasion: Occasion {
        get { Occasion(rawValue: occasionRaw) ?? .other }
        set { occasionRaw = newValue.rawValue }
    }
    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .cash }
        set { methodRaw = newValue.rawValue }
    }

    init(
        amount: Decimal,
        currencyCode: String,
        date: Date = .now,
        occasion: Occasion = .justBecause,
        method: PaymentMethod = .cash,
        note: String = "",
        photoData: Data? = nil,
        blesser: Blesser? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.currencyCode = currencyCode
        self.date = date
        self.occasionRaw = occasion.rawValue
        self.methodRaw = method.rawValue
        self.note = note
        self.photoData = photoData
        self.blesser = blesser
    }
}
