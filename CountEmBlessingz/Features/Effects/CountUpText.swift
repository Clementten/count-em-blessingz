import SwiftUI

/// Rolls digits when `value` changes (Quiet Fortune runs this on every add). Honors Reduce Motion.
struct CountUpText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let text: String
    let value: Decimal
    var animated = true

    var body: some View {
        Text(text)
            .contentTransition(.numericText())
            .animation(animated && !reduceMotion ? .easeOut(duration: 0.9) : nil, value: value)
    }
}
