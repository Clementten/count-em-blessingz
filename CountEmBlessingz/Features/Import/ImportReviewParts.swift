import SwiftUI

/// "1 blessing" / "3 blessings".
func blessingCountText(_ count: Int) -> String {
    count == 1 ? String(localized: "1 blessing") : String(localized: "\(count) blessings")
}

/// Formats money for the review, honoring hide-amounts.
struct ImportMoney {
    let currency: String
    let hidden: Bool

    func text(_ value: Decimal) -> String {
        hidden ? "••••" : MoneyFormatter.format(value, currency: currency)
    }
}

struct TriStateCheckbox: View {
    @Environment(\.theme) private var theme
    let state: Bool?            // nil = some
    var locked = false

    var body: some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(locked ? theme.textMuted : (state == false ? theme.line : theme.accent))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }

    private var symbol: String {
        if locked { return "checkmark.square" }
        switch state {
        case .some(true): return "checkmark.square.fill"
        case .some(false): return "square"
        case .none: return "minus.square.fill"
        }
    }
}

struct StatusBadge: View {
    @Environment(\.theme) private var theme
    let status: EntryStatus

    private var title: String {
        switch status {
        case .new: String(localized: "New")
        case .updated: String(localized: "Updated")
        case .possibleDuplicate: String(localized: "Possible duplicate")
        case .duplicateWithinFile: String(localized: "Duplicate in file")
        case .alreadyImported: String(localized: "Already in your pot")
        }
    }

    private var color: Color {
        switch status {
        case .new: theme.positive
        case .updated: theme.accent
        case .possibleDuplicate, .duplicateWithinFile: theme.danger
        case .alreadyImported: theme.textMuted
        }
    }

    /// Text stays in a colour that is readable on the row; the status colour is carried by the outline.
    /// (The Grand Ledger's green is only 4.3:1 on its pink surface, below the 4.5:1 minimum.)
    private var textColor: Color {
        switch status {
        case .new: theme.textPrimary
        default: color
        }
    }

    var body: some View {
        Text(title)
            .font(theme.bodyFont(11, .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(color, lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Describes an entry for VoiceOver and the status badge's wording, in one place.
enum ImportStatusText {
    static func title(_ status: EntryStatus) -> String {
        switch status {
        case .new: String(localized: "new")
        case .updated: String(localized: "updated")
        case .possibleDuplicate: String(localized: "possible duplicate")
        case .duplicateWithinFile: String(localized: "duplicate within the file")
        case .alreadyImported: String(localized: "already in your pot")
        }
    }

    /// "3 days apart", or "less than a day apart".
    static func apart(_ a: Date, _ b: Date) -> String {
        let days = Int(abs(a.timeIntervalSince(b)) / 86_400)
        if days < 1 { return String(localized: "less than a day apart") }
        return days == 1 ? String(localized: "1 day apart") : String(localized: "\(days) days apart")
    }

    /// Which fields differ between the old local entry and the incoming one.
    static func changes(from old: LocalEntry, to new: IncomingEntry) -> [String] {
        var changed: [String] = []
        if old.amount != new.amount { changed.append(String(localized: "amount")) }
        if abs(old.date.timeIntervalSince(new.date)) >= 1 { changed.append(String(localized: "date")) }
        if old.occasion != new.occasion { changed.append(String(localized: "occasion")) }
        if old.method != new.method { changed.append(String(localized: "method")) }
        if old.note != new.note { changed.append(String(localized: "note")) }
        if old.photoFingerprint != new.photoFingerprint { changed.append(String(localized: "photo")) }
        return changed
    }
}

/// One entry. The whole row toggles; the checkbox is decoration, so VoiceOver gets a single switch.
struct ImportEntryRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    let item: PlanItem
    let personName: String
    let money: ImportMoney          // for the incoming amount (file currency until the user chooses)
    let localMoney: ImportMoney     // for amounts already in the pot
    let fileCurrency: String?       // set when amounts were converted, to show the original
    let toggle: () -> Void

    private var occasionTitle: String { Occasion(rawValue: item.dto.occasion)?.title ?? item.dto.occasion }
    private func stamp(_ date: Date) -> String { StampFormatter.string(date) }

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 4) {
                TriStateCheckbox(state: item.isSelected, locked: item.isLocked)
                VStack(alignment: .leading, spacing: 4) {
                    headline
                    Text("\(occasionTitle) · \(stamp(item.entry.date))")
                        .font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
                    if !item.entry.note.isEmpty {
                        Text(item.entry.note).font(theme.bodyFont(13, .regular))
                            .foregroundStyle(item.isLocked ? theme.textMuted : theme.textPrimary)
                    }
                    if let fileCurrency, item.dto.currencyCode == fileCurrency {
                        Text("Was \(fileCurrency) \(money.hidden ? "••••" : item.dto.amount.formatted())")
                            .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.textMuted)
                    }
                    detail
                }
                .padding(.vertical, 8)
                Spacer(minLength: 0)
            }
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item.isLocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(item.isLocked ? "" : (item.isSelected ? String(localized: "selected") : String(localized: "not selected")))
        .accessibilityAddTraits(item.isLocked ? [] : .isToggle)
        .accessibilityHint(item.isLocked ? String(localized: "Already in your pot, can't be selected") : "")
    }

    @ViewBuilder private var headline: some View {
        let amount = Text(money.text(item.entry.amount))
            .font(theme.amountFont(18)).foregroundStyle(item.isLocked ? theme.textMuted : theme.amountColor)
            .blurIf(money.hidden, radius: 4).privacySensitive()
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) { amount; StatusBadge(status: item.status) }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) { amount; Spacer(minLength: 4); StatusBadge(status: item.status) }
        }
    }

    @ViewBuilder private var detail: some View {
        switch item.status {
        case .possibleDuplicate(let match):
            detailLine("Matches \(localMoney.text(match.amount)) · \(Occasion(rawValue: match.occasion)?.title ?? match.occasion) · \(stamp(match.date)) (\(ImportStatusText.apart(match.date, item.entry.date)))")
        case .updated(let old):
            let changed = ImportStatusText.changes(from: old, to: item.entry).joined(separator: ", ")
            detailLine("Was \(localMoney.text(old.amount)) · \(Occasion(rawValue: old.occasion)?.title ?? old.occasion) · \(stamp(old.date)) → now \(money.text(item.entry.amount))")
            if !changed.isEmpty { detailLine("Changed: \(changed)") }
        case .duplicateWithinFile:
            detailLine("Same person, amount and time as another entry in this file")
        case .new, .alreadyImported:
            EmptyView()
        }
    }

    private func detailLine(_ text: LocalizedStringKey) -> some View {
        Text(text).font(theme.bodyFont(12, .regular)).foregroundStyle(theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var accessibilityText: String {
        var parts = [personName, money.text(item.entry.amount), occasionTitle, stamp(item.entry.date)]
        if !item.entry.note.isEmpty { parts.append(item.entry.note) }
        parts.append(ImportStatusText.title(item.status))
        switch item.status {
        case .possibleDuplicate(let match):
            parts.append(String(localized: "matches \(localMoney.text(match.amount)) on \(stamp(match.date)), \(ImportStatusText.apart(match.date, item.entry.date))"))
        case .updated(let old):
            parts.append(String(localized: "was \(localMoney.text(old.amount)), now \(money.text(item.entry.amount))"))
        default: break
        }
        return parts.joined(separator: ", ")
    }
}

/// Person section header: name, who they are locally, history, and the person-level checkbox.
struct ImportPersonHeader: View {
    @Environment(\.theme) private var theme

    let person: PlanPerson
    let plan: ImportPlan
    let money: ImportMoney
    let toggleAll: () -> Void
    let setMapping: (PersonMapping) -> Void

    private var chip: String {
        switch person.match {
        case .sameID, .sameName: String(localized: "Existing person")
        case .new: String(localized: "New person")
        case .similar(let local): String(localized: "Looks like \(local.name)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                Button(action: toggleAll) {
                    TriStateCheckbox(state: plan.selection(of: person.id))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Select all entries for \(person.name)"))
                .accessibilityValue(selectionWord)
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name).font(theme.bodyFont(17, .semibold)).foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(chip)
                        .font(theme.bodyFont(11, .semibold)).foregroundStyle(chipColor)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(chipColor, lineWidth: 1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)
                Spacer(minLength: 0)
            }
            if let local = person.similarCandidate { similarChoice(local) }
            if let history = plan.history(of: person) { historyLine(history) }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background)          // opaque, so pinned headers hide what scrolls beneath
    }

    private var chipColor: Color {
        if case .similar = person.match { return theme.accent }
        return person.match == .new ? theme.positive : theme.textMuted
    }

    private var selectionWord: String {
        switch plan.selection(of: person.id) {
        case .some(true): String(localized: "all selected")
        case .some(false): String(localized: "none selected")
        case .none: String(localized: "some selected")
        }
    }

    /// "Same person" or "Keep separate", defaulting to keeping them apart.
    private func similarChoice(_ local: LocalPerson) -> some View {
        Picker("Is this the same person?", selection: Binding(
            get: { person.mapping == .createNew },
            set: { setMapping($0 ? .createNew : .existing(local)) }
        )) {
            Text("Same person").tag(false)
            Text("Keep separate").tag(true)
        }
        .pickerStyle(.segmented)
    }

    private func historyLine(_ history: (count: Int, last: LocalEntry?)) -> some View {
        Group {
            if let last = history.last {
                let occasion = Occasion(rawValue: last.occasion)?.title ?? last.occasion
                Text("\(blessingCountText(history.count)) · Last: \(money.text(last.amount)) · \(occasion) · \(StampFormatter.string(last.date))")
            } else {
                Text(blessingCountText(history.count))
            }
        }
        .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.textMuted)
        .fixedSize(horizontal: false, vertical: true)
        .privacySensitive()
    }
}

/// Shown when the file's currency differs from the pot's: choose a rate or import the numbers as they are.
struct ImportCurrencyBanner: View {
    @Environment(\.theme) private var theme

    let plan: ImportPlan
    let setRate: () -> Void
    let importNumbers: () -> Void

    private var file: String { plan.source.fileCurrency }
    private var local: String { plan.localCurrency }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("This file is in \(file); your pot is in \(local).")
                    .font(theme.bodyFont(14, .semibold)).foregroundStyle(theme.textPrimary)
            } icon: {
                Image(systemName: "coloncurrencysign.circle").foregroundStyle(theme.accent)
            }
            switch plan.currency {
            case .rate(let rate):
                Text("Converted at 1 \(file) = \(rate.formatted(.number.precision(.fractionLength(0...4)))) \(local). Original amounts are kept.")
                    .font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
            case .importNumbers:
                Text("Importing the numbers as they are, in \(local).")
                    .font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
            default:
                Text("Choose how to bring the amounts in before importing.")
                    .font(theme.bodyFont(13, .regular)).foregroundStyle(theme.textMuted)
            }
            HStack(spacing: 8) {
                bannerButton(plan.currency == .undecided ? String(localized: "Set exchange rate…") : String(localized: "Change rate…"), action: setRate)
                bannerButton(String(localized: "Import the numbers as \(local)"), action: importNumbers)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(plan.isReady ? theme.line : theme.accent, lineWidth: plan.isReady ? 1 : 2))
    }

    private func bannerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(theme.bodyFont(13, .semibold)).foregroundStyle(theme.accent)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 6)
                .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.accent, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Sticky bottom bar: what will be imported, and the buttons. Nothing is written until Import is tapped.
struct ImportFooter: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    let plan: ImportPlan
    let money: ImportMoney
    let onImport: () -> Void
    let onCancel: () -> Void

    /// At accessibility sizes the footer is just the Import button; Cancel and the totals live in the header,
    /// so the list keeps most of the screen.
    private var compact: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        VStack(spacing: 8) {
            if !plan.isReady {
                Text("Choose how to handle the currency first.")
                    .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.danger)
            } else if !compact, !plan.newPersonIDs.isEmpty {
                Text(plan.newPersonIDs.count == 1
                     ? String(localized: "1 new person will be created")
                     : String(localized: "\(plan.newPersonIDs.count) new people will be created"))
                    .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.textMuted)
            }
            let enabled = plan.selectedCount > 0 && plan.isReady
            ThemedButton(
                title: compact
                    ? String(localized: "Import \(plan.selectedCount) of \(plan.selectableCount)")
                    : String(localized: "Import \(plan.selectedCount) of \(plan.selectableCount) · \(money.text(plan.selectedSum))"),
                action: onImport
            )
            .opacity(enabled ? 1 : 0.4)
            .disabled(!enabled)
            if !compact {
                Button(action: onCancel) {
                    Text("Cancel").font(theme.bodyFont(14, .medium)).foregroundStyle(theme.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 4)
        .background(theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
    }
}
