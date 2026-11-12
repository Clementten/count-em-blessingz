import SwiftUI

/// Review before anything is written. Cancel leaves the pot exactly as it was.
struct ImportReviewView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(ToastCenter.self) private var toast
    @Environment(AppRouter.self) private var router

    @Bindable var model: ImportReviewModel
    let settings: AppSettings

    @State private var choosingRate = false
    @State private var errorText: String?

    private var plan: ImportPlan { model.plan }
    /// Amounts already in the pot.
    private var localMoney: ImportMoney { ImportMoney(currency: plan.localCurrency, hidden: settings.hideAmounts) }

    /// Incoming amounts: in the file's own currency until the user chooses a rate or "import the numbers".
    private var money: ImportMoney {
        ImportMoney(currency: plan.currency == .undecided ? plan.source.fileCurrency : plan.localCurrency,
                    hidden: settings.hideAmounts)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                header
                if plan.needsCurrencyDecision {
                    ImportCurrencyBanner(
                        plan: plan,
                        setRate: { choosingRate = true },
                        importNumbers: { model.plan.setCurrency(.importNumbers) }
                    )
                }
                controls
                ForEach(model.visiblePersons) { person in
                    Section {
                        ForEach(model.visibleItems(of: person)) { item in
                            ImportEntryRow(
                                item: item, personName: person.name, money: money, localMoney: localMoney,
                                fileCurrency: plan.convertsAmounts ? plan.source.fileCurrency : nil
                            ) { model.plan.setSelected(item: item.id, !item.isSelected) }
                        }
                    } header: {
                        ImportPersonHeader(
                            person: person, plan: plan, money: localMoney,
                            toggleAll: { model.plan.setSelected(person: person.id, plan.selection(of: person.id) != true) },
                            setMapping: { model.plan.setMapping(person: person.id, $0) }
                        )
                    }
                }
                if model.visiblePersons.isEmpty {
                    Text("Nothing matches.").font(theme.bodyFont(14, .regular)).foregroundStyle(theme.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .padding(.horizontal, 20)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ImportFooter(plan: plan, money: money, onImport: importTapped, onCancel: { dismiss() })
        }
        .sheet(isPresented: $choosingRate) {
            CurrencyRateSheet(
                importFrom: plan.source.fileCurrency, to: plan.localCurrency,
                sampleTotal: plan.items.reduce(0) { $0 + $1.dto.amount }, count: plan.items.count
            ) { model.plan.setCurrency(.rate($0)) }
            .environment(toast)
        }
        .alert("Couldn't import", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
        .themed(theme)
    }

    // MARK: Header and controls

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if typeSize.isAccessibilitySize { accessibilityTopBar }
            Text(theme.title(String(localized: "Review import")))
                .font(theme.displayFont(26, .bold)).foregroundStyle(theme.textPrimary)
            Text(fromLine).font(theme.bodyFont(14, .medium)).foregroundStyle(theme.textPrimary)
            let s = plan.summary
            Text("\(s.total) in file: \(s.new) new, \(s.updated) updated, \(s.possibleDuplicates) possible duplicates, \(s.alreadyInPot) already in your pot.")
                .font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
            if plan.skippedWithoutPerson > 0 {
                Text("\(plan.skippedWithoutPerson) entries in the file have no person and can't be imported.")
                    .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.danger)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 20)
        .accessibilityElement(children: .combine)
    }

    /// Cancel and the live totals, moved out of the footer at accessibility sizes.
    private var accessibilityTopBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("Cancel") { dismiss() }
                .font(theme.bodyFont(16, .semibold)).foregroundStyle(theme.accent)
                .frame(minHeight: 44)
            Text("Selected: \(plan.selectedCount) of \(plan.selectableCount) · \(money.text(plan.selectedSum))")
                .font(theme.bodyFont(14, .semibold)).foregroundStyle(theme.textPrimary)
            if !plan.newPersonIDs.isEmpty {
                Text(plan.newPersonIDs.count == 1
                     ? String(localized: "1 new person will be created")
                     : String(localized: "\(plan.newPersonIDs.count) new people will be created"))
                    .font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
            }
        }
    }

    private var fromLine: String {
        let who = plan.source.exportedBy.trimmingCharacters(in: .whitespaces)
        let when = plan.source.exportedAt.formatted(date: .abbreviated, time: .shortened)
        return who.isEmpty
            ? String(localized: "From another phone · exported \(when)")
            : String(localized: "From \(who) · exported \(when)")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ImportFilter.allCases) { filter in
                        let selected = model.filter == filter
                        Button { model.filter = filter } label: {
                            Text(filter.title).font(theme.bodyFont(13, .medium))
                                .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
                                .padding(.horizontal, 12).frame(minHeight: 44)
                                .background(selected ? theme.accent : theme.surface,
                                            in: RoundedRectangle(cornerRadius: theme.controlRadius))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("Search name, note or occasion", text: $model.search)
                    .font(theme.bodyFont(15, .regular)).foregroundStyle(theme.textPrimary)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
                Menu {
                    Button("Select all new") { model.plan.selectAllNew() }
                    Button("Select all") { model.plan.selectAll() }
                    Button("Select none") { model.plan.selectNone() }
                } label: {
                    Image(systemName: "checklist").font(.title3).foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
                }
                .accessibilityLabel("Selection options")
            }
        }
    }

    // MARK: Import

    private func importTapped() {
        let service = ImportService(context: modelContext)
        let context = modelContext
        do {
            let result = try service.commit(model.plan)
            Haptics.impact()
            let toast = toast
            let router = router
            let reduceMotion = reduceMotion
            if let crossed = result.crossedMilestone {
                Haptics.success()
                if !reduceMotion {
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))     // let the sheet finish dismissing
                        router.celebrate(crossed)
                    }
                }
            }
            dismiss()
            let message = result.importedCount == 1
                ? String(localized: "Imported 1 blessing.")
                : String(localized: "Imported \(result.importedCount) blessings.")
            toast.show(message, actionTitle: String(localized: "Undo"), duration: 8) {
                do {
                    try ImportService(context: context).undoLastImport()
                    toast.show(String(localized: "Import undone."))
                } catch {
                    toast.show((error as? LocalizedError)?.errorDescription ?? String(localized: "Couldn't undo."))
                }
            }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? String(localized: "Something went wrong. Nothing was changed.")
        }
    }
}
