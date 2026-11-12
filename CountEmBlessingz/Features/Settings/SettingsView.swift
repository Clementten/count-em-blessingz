import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(BiometricLock.self) private var lock
    @Environment(ToastCenter.self) private var toast
    @Environment(ReminderService.self) private var reminders
    @Bindable var settings: AppSettings

    @State private var pendingCountry: Country?
    @State private var choosingCountry = false
    @State private var goalText = ""
    @FocusState private var goalFocused: Bool

    private var country: Country? { CountryCatalog.country(code: settings.countryCode) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(theme.title("Settings"))
                        .font(theme.displayFont(28, .bold)).foregroundStyle(theme.textPrimary)
                        .lineLimit(2).minimumScaleFactor(0.6)

                    group("General") {
                        Button { choosingCountry = true } label: {
                            row("Country and currency") {
                                Text("\(country?.name ?? settings.countryCode) · \(settings.currencyCode)")
                                    .foregroundStyle(theme.textMuted)
                                Image(systemName: "chevron.right").foregroundStyle(theme.textMuted)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("country-row")
                        row("Sharing name") {
                            TextField(UIDevice.current.name, text: $settings.deviceLabel)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(theme.textPrimary)
                                .textInputAutocapitalization(.words)
                                .frame(minWidth: 140)
                        }
                        Text("Shown to people who import your file. Leave empty to use this phone's name.")
                            .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.textMuted)
                        row("Honeypot goal") {
                            Text(MoneyFormatter.symbol(for: settings.currencyCode)).foregroundStyle(theme.textMuted)
                            TextField("Goal", text: $goalText)
                                .keyboardType(.numberPad)
                                .focused($goalFocused)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(theme.amountColor)
                                .frame(minWidth: 90)
                                .onSubmit(commitGoal)
                        }
                    }

                    group("Vibe") { VibePicker(themeID: $settings.themeID) }

                    group("Privacy") {
                        Toggle(isOn: faceIDBinding) {
                            Text("Face ID lock").foregroundStyle(theme.textPrimary)
                        }
                        .frame(minHeight: 44)
                        Toggle(isOn: $settings.hideAmounts) {
                            Text("Hide amounts by default").foregroundStyle(theme.textPrimary)
                        }
                        .frame(minHeight: 44)
                    }

                    group("Gratitude") {
                        row("Reminder delay") {
                            Picker("Reminder delay", selection: reminderBinding) {
                                Text("Off").tag(0)
                                Text("1 day").tag(1)
                                Text("3 days").tag(3)
                                Text("7 days").tag(7)
                            }
                            .labelsHidden()
                        }
                    }

                    group("Data (stays on this device)") { DataSection(settings: settings) }

                    Text("No cloud, no account. Back up regularly: if you lose this phone, the honeypot is gone.")
                        .font(theme.bodyFont(12, .regular)).foregroundStyle(theme.textMuted)

                    #if DEBUG
                    NavigationLink("Theme gallery") { ThemeGalleryView() }
                        .foregroundStyle(theme.accent).frame(minHeight: 44)
                    #endif
                }
                .padding(20)
            }
            .contentMargins(.bottom, 20, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { goalText = MoneyFormatter.plain(settings.goal) }
            .onChange(of: settings.currencyCode) { goalText = MoneyFormatter.plain(settings.goal) }
            .onChange(of: goalFocused) { _, focused in
                if focused {
                    goalText = MoneyFormatter.editable(settings.goal)     // plain digits while typing
                } else {
                    commitGoal()
                }
            }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { goalFocused = false } } }
            .sheet(isPresented: $choosingCountry) { countrySheet }
            .sheet(item: $pendingCountry) { target in
                CurrencyRateSheet(settings: settings, target: target)
                    .environment(toast)
                    .presentationDetents([.large])
            }
        }
    }

    /// Turning the lock on first proves the user can authenticate, so they can't lock themselves out.
    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { settings.faceIDEnabled },
            set: { wantsOn in
                guard wantsOn else { settings.faceIDEnabled = false; return }
                Task {
                    if await lock.verifyForEnabling() {
                        settings.faceIDEnabled = true
                    } else {
                        toast.show(String(localized: "Couldn't verify. Face ID lock stays off."))
                    }
                }
            }
        )
    }

    /// Turning reminders on asks for notification permission first; if it is refused they stay off.
    private var reminderBinding: Binding<Int> {
        Binding(
            get: { settings.reminderDays },
            set: { days in
                guard days > 0 else { settings.reminderDays = 0; return }
                Task {
                    if await reminders.requestPermissionIfNeeded() {
                        settings.reminderDays = days
                    } else {
                        settings.reminderDays = 0
                        toast.show(String(localized: "Notifications are off for this app. Turn them on in the iPhone Settings app."), duration: 5)
                    }
                }
            }
        )
    }

    /// Saves the goal only when the user is done typing, and only if it is a real number.
    /// A half-typed or invalid entry puts the old goal back instead of changing it.
    private func commitGoal() {
        if let value = MoneyFormatter.parsePositive(goalText) { settings.goal = value }
        goalText = MoneyFormatter.plain(settings.goal)
    }

    private var countrySheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(theme.title("Country and currency"))
                .font(theme.displayFont(24, .bold)).foregroundStyle(theme.textPrimary)
            CountryList(selectedCode: settings.countryCode) { picked in
                choosingCountry = false
                choose(picked)
            }
        }
        .padding(20)
        .background(theme.background.ignoresSafeArea())
        .themed(theme)
    }

    /// Same currency: just relabel the country. Different currency: ask for the rate first.
    private func choose(_ picked: Country) {
        if picked.currencyCode == settings.currencyCode {
            settings.countryCode = picked.code
        } else {
            // Wait for the picker sheet to finish dismissing before presenting the next one.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                pendingCountry = picked
            }
        }
    }

    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(theme.bodyFont(12, .semibold)).foregroundStyle(theme.textMuted)
            content()
        }
    }

    private func row<Trailing: View>(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) -> some View {
        // Label and value share a line; at accessibility sizes the value moves below the label instead of squeezing it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Text(title).foregroundStyle(theme.textPrimary)
            if !typeSize.isAccessibilitySize { Spacer() }
            HStack(spacing: 8) { trailing() }
        }
        .font(theme.bodyFont(15, .regular))
        .padding(.vertical, typeSize.isAccessibilitySize ? 6 : 0)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())          // the whole row is tappable, not just the text
        .overlay(alignment: .bottom) { Rectangle().fill(theme.rowDivider).frame(height: 1) }
    }
}
