import SwiftData
import Foundation

/// The SwiftData store lives in an App Group container so the widget can read it.
/// Change the identifier together with the bundle id (and the entitlements) when you rename the app.
enum SharedStore {
    static let appGroupIdentifier = "group.com.example.countemblessingz"

    static let schema = Schema([Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self])

    /// App Group store when available. Falls back to the default store when the group isn't provisioned
    /// (for example a free personal team), in which case the widget has no data to show.
    static func makeContainer(readOnly: Bool = false) throws -> ModelContainer {
        let grouped = ModelConfiguration(
            schema: schema, allowsSave: !readOnly,
            groupContainer: .identifier(appGroupIdentifier), cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: grouped)
        } catch {
            guard !readOnly else { throw error }
            #if DEBUG
            print("App Group store unavailable (\(error)); using the default store.")
            #endif
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none))
        }
    }
}
