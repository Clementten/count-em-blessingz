import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settings: [AppSettings]
    @State private var lock = BiometricLock()

    var body: some View {
        let current = settings.first
        let theme = Themes.theme(id: current?.themeID ?? Themes.jade.id)
        ZStack {
            if let current {
                if current.hasOnboarded {
                    MainView(settings: current)
                } else {
                    OnboardingView(settings: current)
                }
            } else {
                Color.clear
            }
            overlay
        }
        .themed(theme)
        .environment(lock)
        .onAppear(perform: ensureSettingsRow)
        .onChange(of: current != nil, initial: true) { _, hasSettings in
            if hasSettings { lock.launch(enabled: current?.faceIDEnabled ?? false) }
        }
        .onChange(of: scenePhase) { _, phase in
            lock.scenePhaseChanged(to: phase, enabled: current?.faceIDEnabled ?? false)
        }
    }

    /// Lock screen while locked, plain cover while inactive or before settings load.
    @ViewBuilder private var overlay: some View {
        if lock.isLocked {
            LockView(lock: lock)
        } else if lock.isCovered {
            PrivacyCoverView()
        }
    }

    /// Exactly one `AppSettings` row exists; create it on first launch.
    private func ensureSettingsRow() {
        guard settings.isEmpty else { return }
        modelContext.insert(AppSettings())
    }
}

#if DEBUG
#Preview("Onboarding") {
    RootView()
        .modelContainer(for: [Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self], inMemory: true)
}
#endif
