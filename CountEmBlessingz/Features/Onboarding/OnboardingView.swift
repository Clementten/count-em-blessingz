import SwiftUI
import SwiftData

/// Two steps: country (sets currency), then vibe. Theme changes preview live.
struct OnboardingView: View {
    @Bindable var settings: AppSettings
    @State private var step = 0
    @State private var selectedCode: String

    init(settings: AppSettings) {
        self.settings = settings
        _selectedCode = State(initialValue: CountryCatalog.deviceDefault?.code ?? settings.countryCode)
    }

    var body: some View {
        let theme = Themes.theme(id: settings.themeID)
        Group {
            if step == 0 {
                CountryStep(selectedCode: $selectedCode, onContinue: applyCountry)
            } else {
                VibeStep(
                    themeID: $settings.themeID,
                    onBack: { withAnimation { step = 0 } },
                    onFinish: { settings.hasOnboarded = true }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .themed(theme)
    }

    private func applyCountry() {
        if let country = CountryCatalog.country(code: selectedCode) {
            settings.countryCode = country.code
            settings.currencyCode = country.currencyCode
        }
        withAnimation { step = 1 }
    }
}
