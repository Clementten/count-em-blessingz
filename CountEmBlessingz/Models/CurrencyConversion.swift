import SwiftData
import Foundation

@Model
final class CurrencyConversion {         // audit log, one row per currency change
    var date: Date
    var fromCode: String
    var toCode: String
    var rate: Decimal                    // 1 from = rate to
    var convertedAmounts: Bool           // false = label-only change
    var count: Int
    init(date: Date = .now, fromCode: String, toCode: String, rate: Decimal, convertedAmounts: Bool, count: Int) {
        self.date = date; self.fromCode = fromCode; self.toCode = toCode
        self.rate = rate; self.convertedAmounts = convertedAmounts; self.count = count
    }
}
