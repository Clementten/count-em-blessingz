import SwiftUI
import SwiftData

/// Asks for an exchange rate before the currency changes. Nothing is applied until the user confirms.
struct CurrencyRateSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toast

    let settings: AppSettings
    let target: Country
    @Query private var blessings: [Blessing]

    @State private var entry = RateEntry()
    @FocusState private var focused: Bool

    private var from: String { settings.currencyCode }
    private var to: String { target.currencyCode }
    private var total: Decimal { HomeListLogic.total(blessings) }
    private var rate: Decimal? { entry.rate() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(theme.title("Change currency"))
                    .font(theme.displayFont(26, .bold)).foregroundStyle(theme.textPrimary)
                Text("Switching from \(from) to \(to). Enter the rate so your existing amounts convert. Fill in one side, the other side is 1.")
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

                ThemedButton(title: blessings.isEmpty
                             ? String(localized: "Change currency")
                             : String(localized: "Convert \(blessings.count) blessings")) { apply(labelOnly: false) }
                    .opacity(rate == nil ? 0.4 : 1).disabled(rate == nil)

                Button { apply(labelOnly: true) } label: {
                    Text("Keep the numbers, change the label only")
                        .font(theme.bodyFont(14, .medium)).foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.line, lineWidth: 1))
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
    }

    private func apply(labelOnly: Bool) {
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
