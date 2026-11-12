import SwiftUI
import UIKit

/// Tells the main screen whether the software keyboard is up, so the tab bar and the "+" button can step aside
/// instead of riding on top of the keyboard.
@MainActor @Observable
final class KeyboardObserver {
    private(set) var isVisible = false
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(center: NotificationCenter = .default) {
        tasks.append(Task { [weak self] in
            for await _ in center.notifications(named: UIResponder.keyboardWillShowNotification) { self?.isVisible = true }
        })
        tasks.append(Task { [weak self] in
            for await _ in center.notifications(named: UIResponder.keyboardWillHideNotification) { self?.isVisible = false }
        })
    }

    deinit { tasks.forEach { $0.cancel() } }
}
