import Foundation

enum PaymentMethod: String, CaseIterable, Identifiable {
    case cash
    case eWallet = "E-wallet"
    case bank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: String(localized: "Cash")
        case .eWallet: String(localized: "E-wallet")
        case .bank: String(localized: "Bank")
        }
    }
}
