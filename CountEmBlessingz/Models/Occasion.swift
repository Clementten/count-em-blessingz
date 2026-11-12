import Foundation

enum Occasion: String, CaseIterable, Identifiable {
    case chineseNewYear = "Chinese New Year"
    case birthday
    case wedding
    case hariRaya = "Hari Raya"
    case christmas
    case promotion
    case justBecause = "Just because"
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chineseNewYear: String(localized: "Chinese New Year")
        case .birthday: String(localized: "Birthday")
        case .wedding: String(localized: "Wedding")
        case .hariRaya: String(localized: "Hari Raya")
        case .christmas: String(localized: "Christmas")
        case .promotion: String(localized: "Promotion")
        case .justBecause: String(localized: "Just because")
        case .other: String(localized: "Other")
        }
    }
}
