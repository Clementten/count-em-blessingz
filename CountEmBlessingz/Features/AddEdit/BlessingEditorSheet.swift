import SwiftUI
import SwiftData
import PhotosUI

struct BlessingEditorSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toast
    @Environment(ReminderService.self) private var reminders

    let settings: AppSettings
    let editing: Blessing?
    var onMilestone: (Decimal) -> Void = { _ in }

    @State private var draft: BlessingDraft
    @State private var showDatePicker = false
    @State private var attempted = false
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var amountFocused: Bool

    init(settings: AppSettings, editing: Blessing?, onMilestone: @escaping (Decimal) -> Void = { _ in }) {
        self.settings = settings
        self.editing = editing
        self.onMilestone = onMilestone
        _draft = State(initialValue: editing.map(BlessingDraft.init(editing:)) ?? BlessingDraft())
    }

    private var problems: [BlessingDraft.Problem] { attempted ? draft.problems() : [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                field("Name") {
                    NameField(text: $draft.name)
                    error("Name is required", show: problems.contains(.nameRequired))
                }
                field("Amount") { amountField }
                field("Occasion") { occasionChips }
                field("Date and time") { dateField }
                field("Method") { methodMenu }
                field("Note (optional)") {
                    TextField("Add a note", text: $draft.note, axis: .vertical)
                        .font(theme.bodyFont(16, .regular)).foregroundStyle(theme.textPrimary)
                        .padding(12)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
                }
                field("Photo (optional)") { photoField }
                ThemedButton(title: String(localized: "Save"), action: save)
                    .accessibilityIdentifier("save-blessing")
            }
            .padding(20)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        .themed(theme)
    }

    private var header: some View {
        HStack {
            Text(theme.title(editing == nil ? String(localized: "Add blessing") : String(localized: "Edit blessing")))
                .font(theme.displayFont(26, .bold)).foregroundStyle(theme.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(theme.textMuted)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
        }
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(theme.bodyFont(12, .semibold)).foregroundStyle(theme.textMuted)
            content()
        }
    }

    @ViewBuilder private func error(_ message: LocalizedStringKey, show: Bool) -> some View {
        if show { Text(message).font(theme.bodyFont(12, .regular)).foregroundStyle(theme.danger) }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(MoneyFormatter.symbol(for: settings.currencyCode))
                    .font(theme.displayFont(32, .medium)).foregroundStyle(theme.textMuted)
                TextField("0", text: $draft.amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .accessibilityIdentifier("amount-field")
                    .font(theme.displayFont(32, .bold)).foregroundStyle(theme.amountColor)
            }
            .padding(12)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
            error("Amount must be greater than 0", show: problems.contains(.amountInvalid))
        }
    }

    private var occasionChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Occasion.allCases) { occasion in
                let selected = draft.occasion == occasion
                Button { draft.occasion = occasion } label: {
                    Text(occasion.title)
                        .font(theme.bodyFont(13, .medium))
                        .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selected ? theme.accent : theme.surface,
                                    in: RoundedRectangle(cornerRadius: theme.controlRadius))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation { showDatePicker.toggle() } } label: {
                let date = draft.date ?? .now
                let text = StampFormatter.string(date)
                Text(draft.date == nil ? "Now · \(text)" : text)
                    .font(theme.bodyFont(16, .regular)).foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
            }
            .buttonStyle(.plain)
            if showDatePicker {
                DatePicker("Date and time", selection: Binding(
                    get: { draft.date ?? .now }, set: { draft.date = $0 }
                ))
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
        }
    }

    private var methodMenu: some View {
        Menu {
            Picker("Method", selection: $draft.method) {
                ForEach(PaymentMethod.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            HStack {
                Text(draft.method.title).font(theme.bodyFont(16, .regular)).foregroundStyle(theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").foregroundStyle(theme.textMuted)
            }
            .frame(minHeight: 44).padding(.horizontal, 12)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlRadius))
        }
    }

    private var photoField: some View {
        HStack(spacing: 12) {
            if let data = draft.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: theme.controlRadius))
                    .accessibilityLabel("Attached photo")
                Button("Remove") { draft.photoData = nil; photoItem = nil }
                    .foregroundStyle(theme.danger).frame(minHeight: 44)
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(draft.photoData == nil ? "Add photo" : "Change photo", systemImage: "photo")
                    .font(theme.bodyFont(14, .medium)).foregroundStyle(theme.accent)
                    .frame(minHeight: 44)
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                draft.photoData = ImageDownscaler.jpegData(from: data)
            }
        }
    }

    private func save() {
        attempted = true
        guard draft.problems().isEmpty else { return }
        let service = BlessingService(context: modelContext)
        do {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let amount = draft.parsedAmount() ?? 0
            var message = String(localized: "Saved: \(name), \(MoneyFormatter.format(amount, currency: settings.currencyCode))")
            if let editing {
                try service.update(editing, with: draft)
            } else {
                let result = try service.add(draft, currency: settings.currencyCode, goal: settings.goal)
                if let crossed = result.crossedMilestone {
                    Haptics.success()
                    onMilestone(crossed)
                    message += " · " + String(localized: "Milestone \(MilestoneService.shortLabel(crossed)) reached!")
                }
            }
            Haptics.impact()
            if editing == nil, settings.reminderDays > 0 {
                // First time a reminder is actually needed: ask for permission now, not at launch.
                Task { _ = await reminders.requestPermissionIfNeeded() }
            }
            toast.show(message, duration: 4)
            dismiss()
        } catch {
            toast.show(String(localized: "Could not save. Please try again."))
        }
    }
}
