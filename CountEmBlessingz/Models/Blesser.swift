import SwiftData
import Foundation

@Model
final class Blesser {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameKey: String            // name.trimmed.lowercased(), used for matching
    var thankYouPending: Bool      // true after a new blessing until user marks thanked
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Blessing.blesser)
    var blessings: [Blessing] = []

    init(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = UUID()
        self.name = trimmed
        self.nameKey = trimmed.lowercased()
        self.thankYouPending = true
        self.createdAt = .now
    }
}
