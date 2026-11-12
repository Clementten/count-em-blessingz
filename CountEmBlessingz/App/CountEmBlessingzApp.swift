import SwiftUI
import SwiftData
import WidgetKit

@main
struct CountEmBlessingzApp: App {
    private let container: ModelContainer

    init() {
        // Build the country list off the main thread so onboarding doesn't stall on first launch.
        Task.detached(priority: .utility) { _ = CountryCatalog.all }

        #if DEBUG
        FontDebug.logBundledFonts()
        // `-seedDemo` opens an in-memory store with the mock data; `-demoTheme grand` picks the vibe.
        // `-uiTesting` opens an empty in-memory store (first launch), used by the UI tests.
        let seedDemo = CommandLine.arguments.contains("-seedDemo")
        if seedDemo || CommandLine.arguments.contains("-uiTesting") {
            do {
                let demo = try ModelContainer(for: SharedStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                if seedDemo {
                    SeedData.insert(into: demo.mainContext).themeID = UserDefaults.standard.string(forKey: "demoTheme") ?? "jade"
                }
                container = demo
                return
            } catch {
                fatalError("Could not create demo container: \(error)")
            }
        }
        #endif
        do {
            container = try SharedStore.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
