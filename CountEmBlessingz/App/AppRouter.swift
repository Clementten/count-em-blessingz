import SwiftUI

enum EditorRoute: Identifiable {
    case new
    case edit(Blessing)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let blessing): blessing.id.uuidString
        }
    }
}

/// UI state shared across tabs: which sheet is open.
struct Celebration: Identifiable {
    let id = UUID()
    let milestone: Decimal
}

@Observable
final class AppRouter {
    var editor: EditorRoute?
    var celebration: Celebration?

    /// Fires the active theme's milestone effect once.
    func celebrate(_ milestone: Decimal) {
        celebration = Celebration(milestone: milestone)
    }
}
