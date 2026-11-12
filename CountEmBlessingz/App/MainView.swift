import SwiftUI
import SwiftData
import WidgetKit

/// Themed tab bar, floating "+" button, add/edit sheet and toast.
struct MainView: View {
    let settings: AppSettings

    #if DEBUG
    @State private var tab = UserDefaults.standard.integer(forKey: "demoTab")   // launch arg: -demoTab 2
    #else
    @State private var tab = 0
    #endif
    @State private var router = AppRouter()
    @State private var toast = ToastCenter()
    @State private var reminders = ReminderService()
    @Environment(ImportCoordinator.self) private var importCoordinator
    @Environment(\.modelContext) private var modelContext
    @Query private var blessers: [Blesser]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let icons = ["list.bullet", "chart.pie", "trophy", "gearshape"]

    var body: some View {
        let theme = Themes.theme(id: settings.themeID)
        @Bindable var router = router
        @Bindable var importCoordinator = importCoordinator
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                content
                if tab != 3 { fab(theme) }
                effectOverlay(theme)
                if importCoordinator.isLoading { ProgressView().controlSize(.large).tint(theme.accent).frame(maxWidth: .infinity, maxHeight: .infinity) }
                ToastOverlay(toast: toast)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 12)
                    .animation(.easeInOut(duration: 0.2), value: toast.current?.id)
            }
            tabBar(theme)
        }
        .background(theme.background.ignoresSafeArea())
        .environment(router)
        .environment(toast)
        .environment(reminders)
        .task(id: widgetSignature) { WidgetCenter.shared.reloadAllTimelines() }
        .task(id: reminderSignature) {
            await reminders.sync(blessers: blessers, days: settings.reminderDays)
        }
        .task(id: importCoordinator.pendingURL) { await importCoordinator.process(context: modelContext) }
        #if DEBUG
        .task {
            if CommandLine.arguments.contains("-demoImport") {
                let sample = ImportReviewSamples.model(
                    fileCurrency: UserDefaults.standard.string(forKey: "demoFileCurrency") ?? "MYR")
                sample.search = UserDefaults.standard.string(forKey: "demoImportSearch") ?? ""
                importCoordinator.session = sample
            }
        }
        #endif
        .sheet(item: $importCoordinator.session) { session in
            ImportReviewView(model: session, settings: settings)
                .environment(toast)
                .environment(router)
        }
        .alert("Couldn't open file", isPresented: Binding(
            get: { importCoordinator.errorMessage != nil },
            set: { if !$0 { importCoordinator.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importCoordinator.errorMessage ?? "")
        }
        .sheet(item: $router.editor) { route in
            BlessingEditorSheet(settings: settings, editing: route.blessing) { milestone in
                // Reduce Motion: skip the animation, the toast still announces it.
                guard !reduceMotion else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))   // let the sheet finish dismissing
                    router.celebrate(milestone)
                }
            }
                .environment(toast)
                .presentationDetents([.large])
        }
        .themed(theme)
    }

    /// Changes whenever what the widget shows changes (total, goal, currency, theme, hide-amounts).
    private var widgetSignature: String {
        let total = blessers.reduce(Decimal(0)) { sum, blesser in
            sum + blesser.blessings.reduce(Decimal(0)) { $0 + $1.amount }
        }
        return "\(total)|\(settings.goal)|\(settings.currencyCode)|\(settings.themeID)|\(settings.hideAmounts)"
    }

    /// Changes whenever anything that affects reminders changes (pending flags, blessing dates, delay).
    private var reminderSignature: String {
        let rows = blessers.map { blesser in
            let latest = blesser.blessings.map(\.date).max()?.timeIntervalSince1970 ?? 0
            return "\(blesser.id)|\(blesser.thankYouPending)|\(latest)"
        }
        return "\(settings.reminderDays);" + rows.sorted().joined(separator: ";")
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case 0: HomeView(settings: settings)
        case 1: InsightsView(settings: settings)
        case 2: HallView(settings: settings)
        default: SettingsView(settings: settings)
        }
    }

    @ViewBuilder private func effectOverlay(_ theme: AppTheme) -> some View {
        if let celebration = router.celebration {
            switch theme.effect {
            case .coinRain:
                CoinRainView { router.celebration = nil }.id(celebration.id)
            case .chapterCard:
                ChapterCardView(milestone: celebration.milestone) { router.celebration = nil }.id(celebration.id)
            case .countUp:
                Color.clear.onAppear { router.celebration = nil }   // the hero count-up already ran
            }
        }
    }

    private func fab(_ theme: AppTheme) -> some View {
        Button { router.editor = .new } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 60, height: 60)
                .background(theme.accent, in: fabShape(theme))
                .overlay(fabShape(theme).stroke(theme.fabBorder, lineWidth: theme.fabBorderWidth))
        }
        .accessibilityLabel("Add blessing")
        .padding(.trailing, 20).padding(.bottom, 16)
    }

    private func fabShape(_ theme: AppTheme) -> AnyShape {
        theme.fabShape == .circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 6))
    }

    private func tabBar(_ theme: AppTheme) -> some View {
        HStack {
            ForEach(0..<4, id: \.self) { index in
                Button { tab = index } label: {
                    VStack(spacing: 2) {
                        Image(systemName: icons[index])
                        Text(theme.tabTitles[index]).font(theme.bodyFont(10, .medium)).lineLimit(1)
                    }
                    .foregroundStyle(tab == index ? theme.tabBarActive : theme.tabBarText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityAddTraits(tab == index ? .isSelected : [])
            }
        }
        .padding(.top, 8)
        .background(theme.tabBarBackground.ignoresSafeArea(edges: .bottom))
    }
}

private extension EditorRoute {
    var blessing: Blessing? {
        if case .edit(let blessing) = self { return blessing }
        return nil
    }
}
