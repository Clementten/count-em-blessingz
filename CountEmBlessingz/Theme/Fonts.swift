import SwiftUI
import UIKit

/// A bundled font family with its static faces, picked by nearest weight.
/// Falls back to the system font if a face fails to load.
struct FontFamily {
    let faces: [(weight: Int, postScriptName: String)]

    func font(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle = .body) -> Font {
        let target = Self.numericWeight(weight)
        guard let face = faces.min(by: { abs($0.weight - target) < abs($1.weight - target) }),
              UIFont(name: face.postScriptName, size: size) != nil
        else { return .system(size: size, weight: weight) }
        return .custom(face.postScriptName, size: size, relativeTo: style)
    }

    static func numericWeight(_ weight: Font.Weight) -> Int {
        switch weight {
        case .ultraLight: 100
        case .thin: 200
        case .light: 300
        case .regular: 400
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
    }

    // PostScript names come from the files in Resources/Fonts (Jost and Playfair carry a "Roman" infix).
    static let playfair = FontFamily(faces: [(500, "PlayfairDisplayRoman-Medium"), (700, "PlayfairDisplayRoman-Bold")])
    static let montserrat = FontFamily(faces: [(400, "Montserrat-Regular"), (500, "Montserrat-Medium"), (600, "Montserrat-SemiBold")])
    static let jost = FontFamily(faces: [(400, "JostRoman-Regular"), (500, "JostRoman-Medium"), (700, "JostRoman-Bold"), (800, "JostRoman-ExtraBold")])
    static let cormorant = FontFamily(faces: [(500, "CormorantGaramond-Medium"), (600, "CormorantGaramond-SemiBold")])
    static let inter = FontFamily(faces: [(400, "Inter-Regular"), (500, "Inter-Medium"), (600, "Inter-SemiBold")])

    static let all: [FontFamily] = [playfair, montserrat, jost, cormorant, inter]
}

#if DEBUG
enum FontDebug {
    /// Prints registered custom faces once, to confirm PostScript names.
    static func logBundledFonts() {
        let wanted = FontFamily.all.flatMap { $0.faces.map(\.postScriptName) }
        for name in wanted {
            print("Font \(name): \(UIFont(name: name, size: 12) == nil ? "MISSING" : "ok")")
        }
    }
}
#endif
