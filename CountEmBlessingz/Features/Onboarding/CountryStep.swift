import SwiftUI

/// Searchable country list. Scrolls to the selected country on appear.
struct CountryList: View {
    @Environment(\.theme) private var theme
    let selectedCode: String
    let onSelect: (Country) -> Void
    @State private var query = ""

    private var results: [Country] { CountryCatalog.search(query) }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search countries", text: $query)
                .font(theme.bodyFont(16, .regular))
                .textFieldStyle(.plain)
                .padding(12)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { country in
                            countryRow(country)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(selectedCode, anchor: .center) }
            }
        }
    }

    private func countryRow(_ country: Country) -> some View {
        let selected = country.code == selectedCode
        return Button { onSelect(country) } label: {
            HStack {
                Text(country.name).font(theme.bodyFont(16, .medium)).foregroundStyle(theme.textPrimary)
                Spacer()
                Text(country.currencyCode).font(theme.bodyFont(14, .regular)).foregroundStyle(theme.textMuted)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? theme.accent : theme.line)
            }
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(theme.rowDivider).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(country.code)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CountryStep: View {
    @Environment(\.theme) private var theme
    @Binding var selectedCode: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(theme.title("Where are you based?"))
                .font(theme.displayFont(30, .bold)).foregroundStyle(theme.textPrimary)
            Text("We use your country to set your currency. You can change this later in Settings.")
                .font(theme.bodyFont(14, .regular)).foregroundStyle(theme.textMuted)
            CountryList(selectedCode: selectedCode) { selectedCode = $0.code }
            ThemedButton(title: String(localized: "Continue"), action: onContinue)
        }
        .padding(20)
    }
}
