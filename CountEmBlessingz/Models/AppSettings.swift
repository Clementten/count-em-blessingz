import SwiftData
import Foundation

@Model
final class AppSettings {                // exactly one row; create on first launch
    var hasOnboarded: Bool = false
    var countryCode: String = "MY"       // ISO 3166 alpha-2
    var currencyCode: String = "MYR"
    var themeID: String = "jade"         // "jade" | "grand" | "quiet"
    var faceIDEnabled: Bool = false
    var hideAmounts: Bool = false
    var goal: Decimal = 20000
    var reminderDays: Int = 3            // 0 = reminders off
    init() {}

    /// Back to first-launch values (used by "Erase all data"; shows onboarding again).
    func resetToDefaults() {
        hasOnboarded = false
        countryCode = "MY"
        currencyCode = "MYR"
        themeID = "jade"
        faceIDEnabled = false
        hideAmounts = false
        goal = 20000
        reminderDays = 3
    }
}
