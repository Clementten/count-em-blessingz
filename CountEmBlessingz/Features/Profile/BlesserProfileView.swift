import SwiftUI
import SwiftData
import Charts

struct BlesserProfileView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast

    @Bindable var blesser: Blesser
    let settings: AppSettings
    @Query private var allBlessers: [Blesser]

    @State private var removed = false
    @State private var renaming = false
    @State private var newName = ""
    @State private var picking = false
    @State private var mergeTarget: Blesser?

    private var stats: BlesserStats { BlesserService.stats(for: blesser) }

    private func money(_ value: Decimal) -> String {
        settings.hideAmounts ? "••••" : MoneyFormatter.format(value, currency: settings.currencyCode)
    }

    var body: some View {
        Group {
            if removed {
                Color.clear
            } else {
                content
            }
        }
        .background(theme.background.ignoresSafeArea())
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statCards
                byYearChart
                thankYouToggle
                Text(theme.title("Blessings"))
                    .font(theme.bodyFont(12, .semibold)).foregroundStyle(theme.textMuted)
                VStack(spacing: theme.rowStyle == .cards ? 6 : 0) {
                    ForEach(blesser.blessings.sorted { $0.date > $1.date }) { blessing in
                        Button { router.editor = .edit(blessing) } label: {
                            BlessingRow(blessing: blessing, hideAmounts: settings.hideAmounts)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") { newName = blesser.name; renaming = true }
                    Button("Merge into…", systemImage: "arrow.triangle.merge") { picking = true }
                        .disabled(allBlessers.count < 2)
                } label: {
                    Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("More actions")
            }
        }
        .alert("Rename", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Save", action: rename)
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $picking) { mergePicker }
        .alert(
            "Merge \(blesser.name)?",
            isPresented: Binding(get: { mergeTarget != nil }, set: { if !$0 { mergeTarget = nil } }),
            presenting: mergeTarget
        ) { target in
            Button("Merge", role: .destructive) { merge(into: target) }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text("All \(blesser.blessings.count) blessings move to \(target.name), and \(blesser.name) is removed.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AvatarView(name: blesser.name, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(BlesserService.rank(of: blesser, among: allBlessers))")
                    .font(theme.bodyFont(13, .semibold)).foregroundStyle(theme.accent)
                Text(blesser.name)
                    .font(theme.displayFont(30, .bold)).foregroundStyle(theme.textPrimary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statCards: some View {
        HStack(spacing: 10) {
            statCard("Lifetime", money(stats.lifetime))
            statCard("Times", "\(stats.count)")
            statCard("Average", money(MoneyFormatter.round(stats.average, currency: settings.currencyCode)))
        }
    }

    private func statCard(_ title: LocalizedStringKey, _ value: String) -> some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(theme.bodyFont(11, .semibold)).foregroundStyle(theme.textMuted)
                Text(value).font(theme.displayFont(18, .bold)).foregroundStyle(theme.textPrimary)
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .blurIf(settings.hideAmounts, radius: 4)
                    .privacySensitive()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var byYearChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.title(String(localized: "By year")))
                .font(theme.bodyFont(12, .semibold)).foregroundStyle(theme.textMuted)
            Chart(stats.byYear) { item in
                BarMark(
                    x: .value("Year", String(item.year)),
                    // Bar height only; money stays Decimal elsewhere.
                    y: .value("Total", NSDecimalNumber(decimal: item.total).doubleValue)
                )
                .foregroundStyle(theme.accent)
                .cornerRadius(theme.donutStyle == .thin ? 0 : 3)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(theme.textMuted) }
            }
            .frame(height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                stats.byYear.map { "\($0.year): \(money($0.total))" }.joined(separator: ", ")
            )
        }
    }

    private var thankYouToggle: some View {
        ThemedCard {
            Toggle(isOn: Binding(
                get: { blesser.thankYouPending },
                set: { blesser.thankYouPending = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thank-you pending").font(theme.bodyFont(15, .semibold)).foregroundStyle(theme.textPrimary)
                    Text(blesser.thankYouPending
                         ? "Still to say thanks." : "Already thanked.")
                        .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.textMuted)
                }
            }
            .tint(theme.accent)
        }
    }

    private var mergePicker: some View {
        NavigationStack {
            List(allBlessers.filter { $0 !== blesser }.sorted { $0.name < $1.name }) { other in
                Button {
                    picking = false
                    mergeTarget = other
                } label: {
                    HStack {
                        Text(other.name).foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(other.blessings.count) blessings").foregroundStyle(theme.textMuted)
                    }
                    .frame(minHeight: 44)
                }
                .listRowBackground(theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Merge into…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { picking = false } } }
        }
        .themed(theme)
    }

    private func rename() {
        do {
            try BlesserService(context: modelContext).rename(blesser, to: newName)
        } catch BlesserService.RenameError.nameTaken {
            toast.show(String(localized: "That name already exists. Use Merge instead."))
        } catch {
            toast.show(String(localized: "Name can't be empty."))
        }
    }

    private func merge(into target: Blesser) {
        removed = true
        BlesserService(context: modelContext).merge(blesser, into: target)
        dismiss()
    }
}
