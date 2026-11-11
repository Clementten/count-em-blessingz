import SwiftUI

/// About 24 gold coins fall over about 2 seconds. Non-interactive.
struct CoinRainView: View {
    @Environment(\.theme) private var theme
    let onFinish: () -> Void

    private struct Coin {
        let x: CGFloat          // 0...1 across the width
        let delay: Double       // seconds
        let speed: CGFloat      // points per second
        let radius: CGFloat
    }

    @State private var coins: [Coin] = (0..<24).map { _ in
        Coin(x: .random(in: 0.04...0.96), delay: .random(in: 0...0.8),
             speed: .random(in: 650...1000), radius: .random(in: 9...15))
    }
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for coin in coins {
                    let y = CGFloat(t - coin.delay) * coin.speed - 30
                    guard y > -30, y < size.height + 30 else { continue }
                    let rect = CGRect(x: coin.x * size.width - coin.radius, y: y - coin.radius,
                                      width: coin.radius * 2, height: coin.radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(theme.accent))
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: 3, dy: 3)), with: .color(theme.onAccent.opacity(0.4)), lineWidth: 1.5)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(2.4))
            onFinish()
        }
    }
}
