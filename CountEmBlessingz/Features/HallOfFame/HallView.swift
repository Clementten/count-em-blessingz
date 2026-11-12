import SwiftUI
import SwiftData

struct HallView: View {
    @Environment(\.theme) private var theme
    let settings: AppSettings
    @Query private var blessers: [Blesser]
    @Query private var blessings: [Blessing]

    @State private var path: [Blesser] = []
    @State private var shareImage: Image?

    private var ranking: [RankedBlesser] { HallLogic.ranking(blessers) }
    private var review: YearReview? {
        HallLogic.review(blessings, preferredYear: Calendar.current.component(.year, from: .now))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(theme.title(theme.hallTitle))
                        .font(theme.displayFont(28, .bold)).foregroundStyle(theme.textPrimary)
                        .lineLimit(2).minimumScaleFactor(0.6)
                    if ranking.isEmpty {
                        Text("No blessers yet. Tap + to add the first one.")
                            .font(theme.bodyFont(15, .regular)).foregroundStyle(theme.textMuted)
                    } else {
                        PodiumView(top: Array(ranking.prefix(3)), currency: settings.currencyCode,
                                   hideAmounts: settings.hideAmounts) { path.append($0) }
                        VStack(spacing: theme.rowStyle == .cards ? 6 : 0) {
                            ForEach(ranking.dropFirst(3)) { entry in
                                Button { path.append(entry.blesser) } label: {
                                    ThemedRow(name: entry.blesser.name, subtitle: "#\(entry.rank)",
                                              amount: MoneyFormatter.plain(entry.total), hideAmount: settings.hideAmounts)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    section("Milestones") { MilestoneStrip(total: HomeListLogic.total(blessings)) }
                    GratitudeQueue(pending: blessers.filter(\.thankYouPending).sorted { $0.name < $1.name }) {
                        $0.thankYouPending = false
                    }
                    if let review {
                        section("Year in review") {
                            YearReviewCard(review: review, currency: settings.currencyCode, hideAmounts: settings.hideAmounts)
                                .scaleEffect(0.9, anchor: .topLeading)
                                .frame(height: 360, alignment: .topLeading)
                            if let shareImage {
                                ShareLink(item: shareImage, preview: SharePreview("Year in review", image: shareImage)) {
                                    Label("Share year-in-review card", systemImage: "square.and.arrow.up")
                                        .font(theme.bodyFont(15, .semibold)).foregroundStyle(theme.accent)
                                        .frame(minHeight: 44)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .contentMargins(.bottom, 80, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Blesser.self) { BlesserProfileView(blesser: $0, settings: settings) }
            .task(id: renderKey) { renderShareImage() }
        }
    }

    private var renderKey: String {
        "\(review?.total ?? 0)-\(review?.count ?? 0)-\(settings.themeID)-\(settings.hideAmounts)"
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(theme.bodyFont(12, .semibold)).foregroundStyle(theme.textMuted)
            content()
        }
    }

    @MainActor private func renderShareImage() {
        guard let review else { shareImage = nil; return }
        let renderer = ImageRenderer(content:
            YearReviewCard(review: review, currency: settings.currencyCode, hideAmounts: settings.hideAmounts)
                .themed(theme)
        )
        renderer.scale = 3
        shareImage = renderer.uiImage.map(Image.init(uiImage:))
    }
}

#if DEBUG
#Preview("Jade") { previewHall("jade") }
#Preview("Grand") { previewHall("grand") }
#Preview("Quiet") { previewHall("quiet") }

@MainActor private func previewHall(_ id: String) -> some View {
    let container = SeedData.previewContainer(themeID: id)
    let settings = (try? container.mainContext.fetch(FetchDescriptor<AppSettings>()))?.first ?? AppSettings()
    let theme = Themes.theme(id: id)
    return HallView(settings: settings)
        .background(theme.background)
        .themed(theme)
        .environment(AppRouter())
        .environment(ToastCenter())
        .modelContainer(container)
}
#endif
