import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast

    @Bindable var settings: AppSettings
    @Query(sort: \Blessing.date, order: .reverse) private var blessings: [Blessing]

    @State private var path: [Blesser] = []
    @State private var query = ""
    @State private var thisYearOnly = false
    @State private var sort: BlessingSort = .newest

    private var filtered: [Blessing] {
        HomeListLogic.filter(blessings, query: query, thisYearOnly: thisYearOnly)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                HomeHeader(
                    settings: settings, blessings: blessings,
                    query: $query, thisYearOnly: $thisYearOnly, sort: $sort
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(HomeListLogic.sections(filtered, sort: sort)) { section in
                        Section {
                            ForEach(section.blessings) { blessing in
                                row(blessing)
                            }
                        } header: {
                            if !section.title.isEmpty {
                                Text(theme.title(section.title))
                                    .font(theme.bodyFont(12, .semibold)).foregroundStyle(theme.textMuted)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 90, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Blesser.self) { BlesserProfileView(blesser: $0, settings: settings) }
        }
    }

    private var emptyState: some View {
        Text(blessings.isEmpty ? "No blessings yet. Tap + to add the first one." : "No matches.")
            .font(theme.bodyFont(15, .regular)).foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, minHeight: 120)
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
    }

    private func row(_ blessing: Blessing) -> some View {
        Button {
            if let blesser = blessing.blesser { path.append(blesser) }
        } label: {
            BlessingRow(blessing: blessing, hideAmounts: settings.hideAmounts)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: theme.rowStyle == .cards ? 3 : 0, leading: 20, bottom: theme.rowStyle == .cards ? 3 : 0, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { delete(blessing) } label: { Label("Delete", systemImage: "trash") }
            Button { router.editor = .edit(blessing) } label: { Label("Edit", systemImage: "pencil") }
                .tint(theme.accent)
        }
        .swipeActions(edge: .leading) {
            if blessing.blesser?.thankYouPending == true {
                Button { blessing.blesser?.thankYouPending = false } label: {
                    Label("Mark thanked", systemImage: "heart.fill")
                }
                .tint(theme.positive)
            }
        }
    }

    private func delete(_ blessing: Blessing) {
        let service = BlessingService(context: modelContext)
        let name = blessing.blesser?.name ?? ""
        let snapshot = service.delete(blessing)
        toast.show(String(localized: "Deleted: \(name)"), actionTitle: String(localized: "Undo"), duration: 5) {
            try? service.restore(snapshot)
        }
    }
}

/// Title row, hero, search and chips.
private struct HomeHeader: View {
    @Environment(\.theme) private var theme
    @Environment(SharePreparation.self) private var sharing
    @Bindable var settings: AppSettings
    let blessings: [Blessing]
    @Binding var query: String
    @Binding var thisYearOnly: Bool
    @Binding var sort: BlessingSort

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // One row when it fits; stacked (never breaking words) at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { titleText; Spacer(minLength: 8); shareButton; hideChip }
                VStack(alignment: .leading, spacing: 8) { titleText; HStack(spacing: 8) { hideChip; shareButton } }
            }
            HeroPotView(
                total: HomeListLogic.total(blessings),
                monthDelta: HomeListLogic.monthTotal(blessings),
                goal: settings.goal, currency: settings.currencyCode,
                hideAmounts: settings.hideAmounts
            )
            TextField("Search name, note or occasion", text: $query)
                .font(theme.bodyFont(15, .regular)).foregroundStyle(theme.textPrimary)
                .padding(12)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
                .autocorrectionDisabled()
            HStack(spacing: 8) {
                chip("All", selected: !thisYearOnly) { thisYearOnly = false }
                chip("This year", selected: thisYearOnly) { thisYearOnly = true }
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(BlessingSort.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    chipLabel("Sort: \(sort.title)", systemImage: "arrow.up.arrow.down", selected: false)
                }
            }
            Text(theme.title(theme.recentTitle))
                .font(theme.bodyFont(12, .semibold)).foregroundStyle(theme.textMuted)
        }
    }

    private var titleText: some View {
        Text(theme.title("Count 'Em Blessingz"))
            .font(theme.displayFont(22, .bold)).foregroundStyle(theme.textPrimary)
            .lineLimit(2).minimumScaleFactor(0.6)
    }

    private var hideChip: some View {
        chip(settings.hideAmounts ? "Show amounts" : "Hide amounts",
             systemImage: settings.hideAmounts ? "eye" : "eye.slash",
             selected: settings.hideAmounts) { settings.hideAmounts.toggle() }
    }

    /// Opens the system share sheet (WhatsApp, Telegram, Mail, AirDrop, Files...) with every entry.
    @ViewBuilder private var shareButton: some View {
        if let item = sharing.allItem() {
            ShareLink(item: item, preview: SharePreview(String(localized: "All my entries"))) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
            }
            .accessibilityLabel("Share all my entries")
            .accessibilityIdentifier("share-all")
        }
    }

    private func chip(_ title: LocalizedStringKey, systemImage: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { chipLabel(title, systemImage: systemImage, selected: selected) }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func chipLabel(_ title: LocalizedStringKey, systemImage: String?, selected: Bool) -> some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(theme.bodyFont(13, .medium))
        .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
        .padding(.horizontal, 12).frame(minHeight: 44)
        .background(selected ? theme.accent : theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
    }
}

#if DEBUG
#Preview("Jade") { previewHome("jade") }
#Preview("Grand") { previewHome("grand") }
#Preview("Quiet") { previewHome("quiet") }

@MainActor private func previewHome(_ id: String) -> some View {
    let container = SeedData.previewContainer(themeID: id)
    let settings = (try? container.mainContext.fetch(FetchDescriptor<AppSettings>()))?.first ?? AppSettings()
    let theme = Themes.theme(id: id)
    return HomeView(settings: settings)
        .background(theme.background)
        .themed(theme)
        .environment(AppRouter())
        .environment(ToastCenter())
        .environment(SharePreparation())
        .modelContainer(container)
}
#endif
