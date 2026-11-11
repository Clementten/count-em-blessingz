import SwiftData
import Foundation
import UIKit

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
    var deviceID: UUID = UUID()          // identifies this phone in exchange files
    var deviceLabel: String = ""         // sharing name; empty means "use the device name"
    var lastExportAt: Date?              // when entries were last shared ("changes since last export")
    init() {}

    /// The name shown to people who import your file.
    var effectiveDeviceLabel: String {
        let trimmed = deviceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UIDevice.current.name : trimmed
    }

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
        // deviceID is kept: it identifies this phone, not its data.
        deviceLabel = ""
        lastExportAt = nil
    }
}
