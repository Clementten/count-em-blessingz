import Testing
import SwiftUI
@testable import CountEmBlessingz

private struct StubAuthenticator: Authenticator {
    let result: Bool
    func authenticate(reason: String) async -> Bool { result }
}

@MainActor
struct BiometricLockTests {
    @Test func coveredUntilLaunched() {
        let lock = BiometricLock(authenticator: StubAuthenticator(result: true))
        #expect(lock.isCovered)
        lock.launch(enabled: false)
        #expect(!lock.isCovered && !lock.isLocked)
    }

    @Test func launchesLockedWhenEnabled() {
        let lock = BiometricLock(authenticator: StubAuthenticator(result: true))
        lock.launch(enabled: true)
        #expect(lock.isLocked)
    }

    @Test func backgroundThenActiveRequiresAuth() async {
        let lock = BiometricLock(authenticator: StubAuthenticator(result: true))
        lock.launch(enabled: false)
        lock.scenePhaseChanged(to: .background, enabled: true)
        lock.scenePhaseChanged(to: .active, enabled: true)
        #expect(lock.isLocked)
        #expect(await lock.unlock())
        #expect(!lock.isLocked && !lock.isCovered)
    }

    @Test func failedAuthStaysLocked() async {
        let lock = BiometricLock(authenticator: StubAuthenticator(result: false))
        lock.launch(enabled: true)
        #expect(await lock.unlock() == false)
        #expect(lock.isLocked)
    }

    @Test func inactiveCoversButDoesNotLock() {
        let free = BiometricLock(authenticator: StubAuthenticator(result: true))
        free.launch(enabled: false)
        free.scenePhaseChanged(to: .inactive, enabled: true)
        #expect(free.isCovered && !free.isLocked)       // app-switcher snapshot is blank
        free.scenePhaseChanged(to: .active, enabled: true)
        #expect(!free.isCovered)
    }

    @Test func backgroundDoesNotLockWhenDisabled() {
        let lock = BiometricLock(authenticator: StubAuthenticator(result: true))
        lock.launch(enabled: false)
        lock.scenePhaseChanged(to: .background, enabled: false)
        lock.scenePhaseChanged(to: .active, enabled: false)
        #expect(!lock.isLocked && !lock.isCovered)
    }

    @Test func enablingRequiresSuccessfulVerification() async {
        #expect(await BiometricLock(authenticator: StubAuthenticator(result: true)).verifyForEnabling())
        #expect(await BiometricLock(authenticator: StubAuthenticator(result: false)).verifyForEnabling() == false)
    }
}
