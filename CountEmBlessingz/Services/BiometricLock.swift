import SwiftUI
import LocalAuthentication

protocol Authenticator {
    func authenticate(reason: String) async -> Bool
}

/// Face ID / Touch ID with device-passcode fallback.
struct SystemAuthenticator: Authenticator {
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Lock state: locks when the app goes to the background, covers the UI whenever the app is not active
/// (so the app-switcher snapshot shows nothing sensitive).
@MainActor @Observable
final class BiometricLock {
    private(set) var isLocked = false
    private(set) var hasLaunched = false
    private var coverRequested = false
    private var isAuthenticating = false
    private let authenticator: Authenticator

    init(authenticator: Authenticator = SystemAuthenticator()) {
        self.authenticator = authenticator
    }

    /// True while anything should hide the app content.
    var isCovered: Bool { !hasLaunched || isLocked || coverRequested }

    /// Call once, when settings are first available.
    func launch(enabled: Bool) {
        guard !hasLaunched else { return }
        hasLaunched = true
        isLocked = enabled
    }

    func scenePhaseChanged(to phase: ScenePhase, enabled: Bool) {
        switch phase {
        case .background:
            coverRequested = true
            if enabled { isLocked = true }
        case .inactive:
            coverRequested = true
        case .active:
            coverRequested = false
        @unknown default:
            break
        }
    }

    /// Prompts to unlock. Returns true when the app is unlocked afterwards.
    @discardableResult
    func unlock() async -> Bool {
        guard isLocked else { return true }
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let ok = await authenticator.authenticate(reason: String(localized: "Unlock your honeypot"))
        if ok { isLocked = false }
        return ok
    }

    /// Settings: confirm the user can authenticate before turning the lock on.
    func verifyForEnabling() async -> Bool {
        await authenticator.authenticate(reason: String(localized: "Turn on Face ID lock"))
    }
}
