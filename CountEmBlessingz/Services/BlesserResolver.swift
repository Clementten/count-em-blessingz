import SwiftData
import Foundation

/// Finds or creates blessers by name, so two blessers never share a `nameKey`.
struct BlesserResolver {
    let context: ModelContext

    static func key(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func find(name: String) throws -> Blesser? {
        let key = Self.key(for: name)
        guard !key.isEmpty else { return nil }
        var descriptor = FetchDescriptor<Blesser>(predicate: #Predicate { $0.nameKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Returns the existing blesser matching `name` (case-insensitive, trimmed) or inserts a new one.
    /// Returns nil for an empty name.
    @discardableResult
    func findOrCreate(name: String) throws -> Blesser? {
        if let existing = try find(name: name) { return existing }
        guard !Self.key(for: name).isEmpty else { return nil }
        let blesser = Blesser(name: name)
        context.insert(blesser)
        return blesser
    }
}
