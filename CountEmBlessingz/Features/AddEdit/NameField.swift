import SwiftUI
import SwiftData

/// Name entry with autocomplete from existing blessers. Typing a new name creates a blesser on save.
struct NameField: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    @Query(sort: \Blesser.name) private var blessers: [Blesser]

    private var suggestions: [Blesser] {
        let key = BlesserResolver.key(for: text)
        guard !key.isEmpty else { return [] }
        return blessers
            .filter { $0.nameKey.contains(key) && $0.nameKey != key }
            .prefix(4).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Who blessed you?", text: $text)
                .font(theme.bodyFont(17, .regular))
                .foregroundStyle(theme.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(12)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
            ForEach(suggestions) { blesser in
                Button {
                    text = blesser.name
                } label: {
                    HStack {
                        Text(blesser.name).foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(blesser.blessings.count) blessings").foregroundStyle(theme.textMuted)
                    }
                    .font(theme.bodyFont(14, .regular))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
