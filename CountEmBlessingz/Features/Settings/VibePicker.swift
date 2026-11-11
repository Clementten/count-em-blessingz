import SwiftUI

/// Three selectable vibe cards; the whole app previews the choice live.
struct VibePicker: View {
    @Binding var themeID: String

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Themes.all) { option in
                VibeCard(option: option, selected: option.id == themeID) {
                    withAnimation(.easeInOut(duration: 0.25)) { themeID = option.id }
                }
            }
        }
    }
}
