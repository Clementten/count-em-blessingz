import Testing
import UIKit
@testable import CountEmBlessingz

@MainActor
struct KeyboardObserverTests {
    @Test func followsTheKeyboardNotifications() async throws {
        let center = NotificationCenter()
        let observer = KeyboardObserver(center: center)
        #expect(observer.isVisible == false)

        await settle()
        center.post(name: UIResponder.keyboardWillShowNotification, object: nil)
        await settle()
        #expect(observer.isVisible)

        center.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        await settle()
        #expect(!observer.isVisible)
    }

    /// Lets the observer's listening tasks run.
    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(50))
    }
}
