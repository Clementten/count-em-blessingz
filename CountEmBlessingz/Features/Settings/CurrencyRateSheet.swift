import SwiftUI
import SwiftData

/// Asks for an exchange rate before the currency changes. Nothing is applied until the user confirms.
/// The same swap-sides sheet is also used to pick the rate for amounts in an import file; in that mode it
/// only reports the rate and changes nothing itself.
struct CurrencyRateSheet: View {
    enum Purpose {
        case switchCurrency(settings: AppSettings, target: Country)
        case importRate(from: String, to: String, sampleTotal: Decimal, count: Int, onConfirm: (Decimal) -> Void)
    }

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toast

    private let purpose: Purpose
    @Query private var blessings: [Blessing]

    @State private var entry = RateEntry()
    @FocusState private var focused: Bool

    init(settings: AppSettings, target: Country) {
        purpose = .switchCurrency(settings: settings, target: target)
    }

    /// Rate for an import: `1 {from} = rate {to}`, with `sampleTotal` shown converted in the preview.
    init(importFrom from: String, to: String, sampleTotal: Decimal, count: Int, onConfirm: @escaping (Decimal) -> Void) {
        purpose = .importRate(from: from, to: to, sampleTotal: sampleTotal, count: count, onConfirm: onConfirm)
    }

    private var isImport: Bool {
        if case .importRate = purpose { return true }
        return false
    }

    private var from: String {
        switch purpose {
        case .switchCurrency(let settings, _): settings.currencyCode
        case .importRate(let from, _, _, _, _): from
        }
    }

    private var to: String {
        switch purpose {
        case .switchCurrency(_, let target): target.currencyCode
        case .importRate(_, let to, _, _, _): to
        }
    }

    private var total: Decimal {
        switch purpose {
        case .switchCurrency: HomeListLogic.total(blessings)
        case .importRate(_, _, let sampleTotal, _, _): sampleTotal
        }
    }
    private var rate: Decimal? { entry.rate() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(theme.title(isImport ? String(localized: "Exchange rate") : String(localized: "Change currency")))
                    .font(theme.displayFont(26, .bold)).foregroundStyle(theme.textPrimary)
                Group {
                    if isImport {
                        Text("The file is in \(from) and your pot is in \(to). Enter the rate so incoming amounts convert. Fill in one side, the other side is 1.")
                    } else {
                        Text("Switching from \(from) to \(to). Enter the rate so your existing amounts convert. Fill in one side, the other side is 1.")
                    }
                }
                .font(theme.bodyFont(14, .regular)).foregroundStyle(theme.textMuted)

                rateRow
                if entry.showsError() {
                    Text("Enter a rate greater than 0.")
                        .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.danger)
                }
                Button { entry.swap(); focused = true } label: {
                    Label("Swap sides", systemImage: "arrow.left.arrow.right")
                        .font(theme.bodyFont(14, .medium)).foregroundStyle(theme.accent)
                        .frame(minHeight: 44)
                }

                if let converted = entry.preview(total: total, to: to) {
                    Text("\(from) \(MoneyFormatter.plain(total)) becomes \(to) \(MoneyFormatter.plain(converted))")
                        .font(theme.bodyFont(15, .semibold)).foregroundStyle(theme.textPrimary)
                }

                ThemedButton(title: primaryTitle) { apply(labelOnly: false) }
                    .opacity(rate == nil ? 0.4 : 1).disabled(rate == nil)

                if !isImport {
                    Button { apply(labelOnly: true) } label: {
                        Text("Keep the numbers, change the label only")
                            .font(theme.bodyFont(14, .medium)).foregroundStyle(theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.line, lineWidth: 1))
                    }
                }
                Button("Cancel") { dismiss() }
                    .font(theme.bodyFont(14, .medium)).foregroundStyle(theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(20)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } }
        .themed(theme)
    }

    private var primaryTitle: String {
        switch purpose {
        case .importRate(_, _, _, let count, _):
            String(localized: "Use this rate for \(count) entries")
        case .switchCurrency:
            blessings.isEmpty ? String(localized: "Change currency") : String(localized: "Convert \(blessings.count) blessings")
        }
    }

    /// `1 MYR = [ ? ] USD`, or `[ ? ] MYR = 1 USD` after swapping.
    private var rateRow: some View {
        HStack(spacing: 8) {
            if entry.direction == .fromToTo {
                fixed("1 \(from)"); equals; input; code(to)
            } else {
                input; code(from); equals; fixed("1 \(to)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var equals: some View {
        Text("=").font(theme.bodyFont(18, .semibold)).foregroundStyle(theme.textMuted)
    }

    private func fixed(_ text: String) -> some View {
        Text(text).font(theme.bodyFont(18, .semibold)).foregroundStyle(theme.textPrimary)
    }

    private func code(_ text: String) -> some View {
        Text(text).font(theme.bodyFont(18, .semibold)).foregroundStyle(theme.textPrimary)
    }

    private var input: some View {
        TextField("?", text: $entry.text)
            .keyboardType(.decimalPad)
            .focused($focused)
            .multilineTextAlignment(.center)
            .font(theme.bodyFont(18, .semibold)).foregroundStyle(theme.amountColor)
            .frame(minWidth: 90, minHeight: 44)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
            .accessibilityLabel("Exchange rate")
            .accessibilityIdentifier("rate-field")
    }

    private func apply(labelOnly: Bool) {
        if case .importRate(_, _, _, _, let onConfirm) = purpose {
            guard let rate else { return }
            onConfirm(rate)
            dismiss()
            return
        }
        guard case .switchCurrency(let settings, let target) = purpose else { return }
        guard labelOnly || rate != nil else { return }
        let appliedRate = labelOnly ? 1 : (rate ?? 1)
        do {
            let log = try CurrencyConverter.apply(
                rate: appliedRate, to: to, countryCode: target.code, labelOnly: labelOnly,
                blessings: blessings, settings: settings, context: modelContext
            )
            let rateText = log.rate.formatted(.number.precision(.fractionLength(4)))
            toast.show(labelOnly
                       ? String(localized: "Currency label changed to \(to).")
                       : String(localized: "Converted at 1 \(log.fromCode) = \(rateText) \(log.toCode)."), duration: 4)
            dismiss()
        } catch {
            toast.show(String(localized: "Could not change currency."))
        }
    }
}
