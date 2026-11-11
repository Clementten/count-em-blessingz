# Count 'Em Blessingz: iOS App Blueprint

Build instructions for an LLM coding agent (Claude Sonnet) working in Xcode.
Read the whole file first, then build phase by phase (section 12). Commit after each phase.

---

## 1. What the app is

A private, offline iPhone app to track a "honeypot": money people have blessed the user with (angpao, birthday gifts, wedding gifts, and so on), and who gave what.

- One long list of blessings, newest first, grouped by month.
- A "+" button to add: name, amount, occasion. The timestamp is logged automatically.
- Analytics: a pie (donut) chart of the allocation by person, month or occasion.
- Blesser profiles, a Hall of Fame, milestones, thank-you reminders, export and backup.
- All data lives on the device. No cloud, no account, no analytics SDK, no network calls.
- Three swappable visual "vibes" (themes) chosen in onboarding and Settings.

Non-goals: multi-user, sync, budgeting, spending or outflows, currency live-rate lookup, iPad or Mac layouts.

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Language / UI | Swift 5.9+, SwiftUI |
| Persistence | SwiftData, local only (default on-disk store) |
| Min iOS | 17.0 |
| Charts | Swift Charts (`SectorMark`) |
| Money type | `Decimal` everywhere. Never `Double`/`Float` for money. |
| Currency | One currency at a time, derived from the user's country. Changing country triggers an exchange-rate prompt (section 7). |
| Themes | Three, swappable at runtime: Jade & Gold, The Grand Ledger, Quiet Fortune |
| Third-party deps | None |
| Architecture | MVVM-lite: `@Query` and `@Environment(\.modelContext)` in views where simple, `@Observable` view models where logic grows |
| Orientation | Portrait only, iPhone only |
| Localization | Write user-facing strings with `String(localized:)`/`LocalizedStringKey`, English only for now |

## 3. Reference mocks (design source of truth)

These are private claude.ai artifacts made during ideation. The owner can share them on request. This file contains everything needed, so the agent does not depend on them.

- Vibe boards and UX wireframes: https://claude.ai/artifact/AJ7poWYm2jNce1ou5UhApm
- Clickable app mock with theme switcher: https://claude.ai/artifact/TK2nvq84gqgvinwLJMaCGn

Where this file and the mocks disagree, this file wins.

## 4. Project setup

1. New Xcode project: iOS App, SwiftUI, SwiftData storage, name `CountEmBlessingz`, bundle id `com.example.countemblessingz` (owner changes it later), iOS 17 deployment target, iPhone only, portrait only.
2. Add test targets: unit tests (Swift Testing or XCTest).
3. Info.plist keys: `NSFaceIDUsageDescription` ("Unlock your honeypot"), `UIAppFonts` (section 8.3), `UIUserInterfaceStyle` is **not** forced; each theme sets its own color scheme (section 8.1).
4. Capabilities: none for v1. The widget phase adds an App Group (section 12, phase 12).
5. Folder layout (create exactly this, as groups with matching folders on disk):

```
CountEmBlessingz/
  App/
    CountEmBlessingzApp.swift        // @main, ModelContainer, theme injection, lock gate
    RootView.swift                   // routes: onboarding vs main tabs
  Models/
    Blessing.swift
    Blesser.swift
    AppSettings.swift
    CurrencyConversion.swift
    Occasion.swift                   // enum
    PaymentMethod.swift              // enum
  Services/
    MoneyFormatter.swift
    CountryCatalog.swift             // countries + currency codes
    CurrencyConverter.swift
    BlesserResolver.swift            // find-or-create by name
    MilestoneService.swift
    ExportService.swift              // CSV, JSON backup, restore
    BiometricLock.swift
    ReminderService.swift            // local notifications
    SeedData.swift                   // DEBUG and previews only
  Theme/
    AppTheme.swift                   // struct + enums
    Themes.swift                     // jade, grand, quiet
    ThemeEnvironment.swift           // @Environment key
    Fonts.swift
    ThemedComponents.swift           // ThemedCard, ThemedRow, ThemedButton, Avatar, Hero
  Features/
    Onboarding/ (CountryStep, VibeStep)
    Home/ (HomeView, BlessingRow, HeroPotView)
    AddEdit/ (BlessingEditorSheet, NameField)
    Profile/ (BlesserProfileView)
    Insights/ (InsightsView, DonutChart, LegendList)
    HallOfFame/ (HallView, PodiumView, MilestoneStrip, GratitudeQueue, YearReviewCard)
    Settings/ (SettingsView, CurrencyRateSheet, VibePicker)
    Lock/ (LockView)
    Effects/ (CoinRainView, ChapterCardView, CountUpText)
  Resources/
    Fonts/ (see 8.3)
    Assets.xcassets
CountEmBlessingzTests/
```

## 5. Data model (SwiftData)

```swift
import SwiftData
import Foundation

@Model
final class Blesser {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameKey: String            // name.trimmed.lowercased(), used for matching
    var thankYouPending: Bool      // true after a new blessing until user marks thanked
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Blessing.blesser)
    var blessings: [Blessing] = []

    init(name: String) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.nameKey = self.name.lowercased()
        self.thankYouPending = true
        self.createdAt = .now
    }
}

@Model
final class Blessing {
    @Attribute(.unique) var id: UUID
    var amount: Decimal                  // in the CURRENT currency (AppSettings.currencyCode)
    var currencyCode: String             // ISO 4217; kept equal to current currency
    var date: Date                       // auto-set to now, editable
    var occasionRaw: String              // Occasion.rawValue
    var methodRaw: String                // PaymentMethod.rawValue
    var note: String
    @Attribute(.externalStorage) var photoData: Data?
    var originalAmount: Decimal?         // set on first currency conversion, never overwritten
    var originalCurrencyCode: String?
    var blesser: Blesser?

    var occasion: Occasion { get { Occasion(rawValue: occasionRaw) ?? .other } set { occasionRaw = newValue.rawValue } }
    var method: PaymentMethod { get { PaymentMethod(rawValue: methodRaw) ?? .cash } set { methodRaw = newValue.rawValue } }
}

@Model
final class AppSettings {                // exactly one row; create on first launch
    var hasOnboarded: Bool = false
    var countryCode: String = "MY"       // ISO 3166 alpha-2
    var currencyCode: String = "MYR"
    var themeID: String = "jade"         // "jade" | "grand" | "quiet"
    var faceIDEnabled: Bool = false
    var hideAmounts: Bool = false
    var goal: Decimal = 20000
    var reminderDays: Int = 3            // 0 = reminders off
    init() {}
}

@Model
final class CurrencyConversion {         // audit log, one row per currency change
    var date: Date
    var fromCode: String
    var toCode: String
    var rate: Decimal                    // 1 from = rate to
    var convertedAmounts: Bool           // false = label-only change
    var count: Int
    init(date: Date = .now, fromCode: String, toCode: String, rate: Decimal, convertedAmounts: Bool, count: Int) {
        self.date = date; self.fromCode = fromCode; self.toCode = toCode
        self.rate = rate; self.convertedAmounts = convertedAmounts; self.count = count
    }
}
```

Enums (plain `String` raw values, `CaseIterable`):

- `Occasion`: `chineseNewYear = "Chinese New Year"`, `birthday`, `wedding`, `hariRaya = "Hari Raya"`, `christmas`, `promotion`, `justBecause = "Just because"`, `other`. Provide a `title` string.
- `PaymentMethod`: `cash`, `eWallet = "E-wallet"`, `bank`.

Rules:
- `Blessing.amount` must be greater than 0. Validate in the editor, not in the model.
- Matching a typed name to an existing `Blesser` goes through `BlesserResolver` (case-insensitive, trimmed). Never create two blessers with the same `nameKey`.
- Deleting a blessing leaves the blesser if they still have other blessings. If a blesser ends up with none, delete them too.
- Create the single `AppSettings` row in `RootView` on first appearance if the query returns empty.

## 6. Services

**MoneyFormatter**: `format(_ d: Decimal, currency: String) -> String` using `Decimal.FormatStyle.Currency(code:)` with `.precision(.fractionLength(0...2))`, and zero decimals for currencies with no minor unit (JPY). Also `plain(_:)` (number only, for list rows that show the amount without a symbol). When `AppSettings.hideAmounts` is on, all views show `••••` and apply `.blur` plus `.privacySensitive()`.

**CountryCatalog**: build the country list from `Locale.Region.isoRegions` (or `Locale.isoRegionCodes` for older APIs), map each to its currency via `Locale(identifier: "en_\(code)").currency?.identifier`, drop entries with no currency. Default selection is `Locale.current.region`. Provide search by country name.

**CurrencyConverter**: see section 7.

**MilestoneService**: thresholds `[1_000, 5_000, 10_000, 20_000]` plus the user's goal. `crossed(before:after:) -> Decimal?` returns the highest threshold crossed by an add. Thresholds are in the current currency units, and are not rescaled on conversion.

**ExportService**
- CSV: columns `date(ISO8601),name,amount,currency,occasion,method,note`. Write to a temp file and present with `ShareLink`.
- JSON backup: Codable `BackupFile { schemaVersion: Int; exportedAt: Date; settings; blessers; blessings; conversions }`, `schemaVersion = 1`. Photos are base64 inside the JSON.
- Restore: `.fileImporter` for `.json`. Show a confirmation ("Replace everything on this device?"). Replace, not merge, in v1. Validate `schemaVersion`.

**BiometricLock**: `LAContext.evaluatePolicy(.deviceOwnerAuthentication, ...)`. Lock on scene `.background`, require auth when `.active` again. Cover the app with a privacy view while `.inactive` so the app switcher snapshot shows nothing sensitive.

**ReminderService**: `UNUserNotificationCenter` local notifications only. Request permission the first time the user turns reminders on (not at launch). Schedule one notification per pending blesser, `reminderDays` after the blessing date, text: "Say thanks to {name}." Cancel on mark-thanked, delete, or reminders off. Notification identifier: `thank-{blesser.id}`.

## 7. Currency and conversion

The user picks a country in onboarding, which sets `currencyCode`. Later they may change country in Settings. Because a different currency means the stored numbers are no longer meaningful, the app asks for an exchange rate.

**Flow (Settings, Country row)**
1. User picks a new country. The setting is not applied yet. Present `CurrencyRateSheet`.
2. Sheet text: "Switching from MYR to USD. Enter the rate so your existing amounts convert. Fill in one side, the other side is 1."
3. Two sides shown left to right: `1 MYR  =  [ ? ] USD`. The side the user types in is the input; the other side is fixed at `1 <code>`.
4. A "Swap sides" button flips to `[ ? ] MYR  =  1 USD` and clears the field. Internally: direction `.fromToTo` gives `rate = input`; direction `.toToFrom` gives `rate = 1 / input`.
5. Live preview: "MYR 9,776 becomes USD 2,053" using the entered rate.
6. Primary button "Convert N blessings". Secondary "Keep the numbers, change the label only". Cancel leaves everything unchanged.
7. Input must be a positive decimal. Accept `,` and `.` per locale (parse with `Decimal(string:locale:)`). Show inline error text otherwise.

**Apply (`CurrencyConverter.apply`)** in one `modelContext` transaction:
- For each `Blessing`: if `originalAmount == nil`, set `originalAmount = amount` and `originalCurrencyCode = currencyCode`. Then `amount = round(amount * rate, to: target minor units)` using `NSDecimalNumber` rounding mode `.plain` and scale 0 for JPY, 2 otherwise. Set `currencyCode = target`.
- `AppSettings.goal = max(100, round(goal * rate to nearest 100))`.
- Update `AppSettings.countryCode` and `currencyCode`.
- Insert a `CurrencyConversion` log row.
- "Label only" path: same, but skip the multiplication (rate treated as 1, `convertedAmounts = false`).
- Show a toast: "Converted at 1 MYR = 0.2100 USD."

Display: if `originalAmount` exists and differs, the blessing detail shows a small "Originally MYR 888" line.

## 8. Theme system

Three themes swap at runtime and are stored as `AppSettings.themeID`. One set of views, driven by tokens. No separate view trees per theme.

### 8.1 AppTheme

```swift
struct AppTheme: Identifiable, Equatable {
    enum AvatarStyle { case circle, roundedSquare, none }
    enum RowStyle { case dividers, cards, hairlines }
    enum DonutStyle { case flat, outlined, thin }
    enum Effect { case coinRain, chapterCard, countUp }

    let id: String
    let name: String
    let blurb: String
    let colorScheme: ColorScheme        // fixed per theme; ignore the system appearance
    // Colors
    let background, surface, textPrimary, textMuted, accent, onAccent, line, positive, danger: Color
    let heroBackground, heroText, heroLabel, heroBorder: Color
    let tabBarBackground, tabBarText, tabBarActive: Color
    let chart: [Color]                  // exactly 5
    // Type
    let displayFont: (CGFloat, Font.Weight) -> Font
    let bodyFont: (CGFloat, Font.Weight) -> Font
    let uppercaseTitles: Bool
    // Shape
    let cornerRadius: CGFloat           // cards
    let controlRadius: CGFloat
    let avatarStyle: AvatarStyle
    let rowStyle: RowStyle
    let donutStyle: DonutStyle
    let donutThickness: CGFloat
    let heroBorderStyle: HeroBorder     // .single(1) | .double(4) | .none
    let fabShape: FabShape              // .circle | .roundedSquare
    // Copy
    let tabTitles: [String]             // [Home, Insights, Hall, Settings]
    let hallTitle: String
    let potLabel: String
    let recentTitle: String
    let effect: Effect
}
```

Inject with a custom `EnvironmentKey` (`@Environment(\.theme)`), set at the root from `AppSettings.themeID`. Wrap theme changes in `withAnimation(.easeInOut(duration: 0.25))`. Each theme forces its own `.preferredColorScheme`.

### 8.2 Token values

| Token | Jade & Gold (`jade`) | The Grand Ledger (`grand`) | Quiet Fortune (`quiet`) |
|---|---|---|---|
| Inspiration | Crazy Rich Asians | Wes Anderson / Grand Budapest | Succession / old money |
| colorScheme | dark | light | dark |
| background | #0B3B2E | #FFE9EE | #15171A |
| surface | #123F33 | #F7C6D0 | #1F2226 |
| textPrimary | #F6EBCB | #3D1D40 | #EDE6D6 |
| textMuted | #D9CDA8 | #5A2D55 | #A9ADB5 |
| accent | #D4AF37 | #B3223B | #B08D57 |
| onAccent | #06241B | #FFE9EE | #15171A |
| line | #2A6B57 | #3D1D40 | #3A3F46 |
| positive | #6FBF9B | #1F6B45 | #8FA596 |
| danger | #FF9C8F | #A3162B | #E59A9A |
| hero bg / text / label | #123F33 / #F6EBCB / #D4AF37 | #5B2A5E / #FFE9EE / #F7C6D0 | clear / #EDE6D6 / #B08D57 |
| hero border | 1pt #D4AF37 | 4pt double #F7C6D0 | none |
| tab bar bg / text / active | #06241B / #D9CDA8 / #D4AF37 | #5B2A5E / #F7C6D0 / #E8B04A | #0D0F11 / #A9ADB5 / #EDE6D6 |
| chart 1 to 5 | #D4AF37 #C8362C #6FBF9B #F6EBCB #4F8F78 | #B3223B #E8B04A #A8D5BA #B9A0D6 #F7C6D0 | #B08D57 #EDE6D6 #6F7F73 #5F6B7A #A65A5A |
| display font | Playfair Display | Jost | Cormorant Garamond |
| body font | Montserrat | Jost | Inter |
| uppercaseTitles | no | yes | no |
| cornerRadius / controlRadius | 20 / 12 | 6 / 4 | 2 / 2 |
| avatarStyle | circle (bg #C8362C, text #F6EBCB) | roundedSquare (bg #5B2A5E, text #FFE9EE) | none (hidden) |
| rowStyle | dividers (1pt #1F5A49) | cards (fill surface, radius 4, 6pt gap) | hairlines (1pt #2A2E33) |
| donut | flat, thickness 26 | outlined, thickness 34 | thin, thickness 10 |
| fab | circle, accent fill | roundedSquare (radius 6, 3pt #3D1D40 border) | circle, accent fill |
| tabTitles | Blessings, Insights, Hall of Fame, Settings | Ledger, Insights, Hall of Fame, Settings | Ledger, Insights, Board, Settings |
| hallTitle | Hall of Fame | Hall of Fame | The Board |
| potLabel | The Honeypot | The Honeypot | Honeypot |
| recentTitle | Recent blessings | Chapter one: recent guests | Recent |
| amount color / font | accent / display | textPrimary / body bold | accent / display |
| effect | coinRain | chapterCard | countUp |

Minimum contrast: text at least 4.5:1 against its surface in every theme. Do not change token values without re-checking.

### 8.3 Fonts

Bundle these open-licence (OFL) Google Fonts as `.ttf` in `Resources/Fonts/` and list them in `UIAppFonts`: Playfair Display (500, 700), Montserrat (400, 500, 600), Jost (400, 500, 700, 800), Cormorant Garamond (500, 600), Inter (400, 500, 600). Include each font's OFL licence text in `Resources/Fonts/LICENSES/`. After adding, print `UIFont.familyNames` and fontNames once in DEBUG to confirm the exact PostScript names, then reference them in `Fonts.swift`. Use `Font.custom(_, size:relativeTo:)` so Dynamic Type works. Provide a system-font fallback if a face fails to load.

### 8.4 Signature effects (fire when an add crosses a milestone)

- `coinRain` (Jade): about 24 gold circles fall from the top over about 2 s with random delays and positions. Use `TimelineView` plus `Canvas`, or simple `withAnimation` offsets. Non-interactive overlay.
- `chapterCard` (Grand): a full-screen dim overlay with a centered card "CHAPTER 10k / The pot grows" in a double border, shown about 2.2 s.
- `countUp` (Quiet): the hero total animates from the old to the new value over about 0.9 s using `.contentTransition(.numericText())` or a manual timer. Quiet runs this on every add, not only milestones.
- Respect `accessibilityReduceMotion`: skip animations and show only the toast.
- Add a medium haptic (`UIImpactFeedbackGenerator`) on save, and a success notification haptic on milestones.

## 9. Screens

Tab bar (custom, themed) with 4 tabs: Blessings, Insights, Hall, Settings. A floating "+" button appears on Home, Insights, Hall and the profile screen (not Settings). The FAB sits about 90pt above the bottom edge on the right.

### 9.1 Onboarding (shown while `hasOnboarded == false`)
- **Step 1, country**: title "Where are you based?", helper "We use your country to set your currency. You can change this later in Settings." Search field, list of countries (name, currency code), the device region preselected. "Continue".
- **Step 2, vibe**: title "Pick a vibe", three cards (name, blurb, swatch strip). Selecting one live-previews the screen theme. Button "Start counting" sets `hasOnboarded = true`.
- No conversion prompt in onboarding (no data yet).

### 9.2 Home (Blessings)
- Header: app name and a "Hide amounts" chip.
- Hero: potLabel, total in large display font, "+ {amount} this month" (or "No blessings yet this month"), goal progress bar and "{pct}% of {goal} goal".
- Search field (name, note, occasion). Chips: All, This year, Sort (Newest / Largest).
- List grouped by "Mon YYYY" when sorting by newest; flat when sorting by largest. Row: avatar, name, "Occasion · d Mon, HH:mm" (plus "thank-you pending" when applicable), amount with "+" prefix.
- Tap a row opens the blesser profile. Swipe: Edit, Delete (with an undo toast for 5 s), Mark thanked.
- Empty state: "No blessings yet. Tap + to add the first one."

### 9.3 Add / Edit sheet
- Fields: Name (autocompletes existing blessers, shows "N blessings"; typing a new name creates a blesser), Amount (decimal pad, currency symbol prefix, large display font), Occasion (single-select chips, default Just because), Date and time (shows "Now · d Mon, HH:mm", tap to edit with a `DatePicker`), Method (menu), Note (optional), Photo (optional, `PhotosPicker`).
- Validation: name required, amount greater than 0. Inline error text.
- Save: insert, mark blesser `thankYouPending = true`, schedule reminder, haptic, toast "Saved: {name}, {amount}", run `MilestoneService`, fire the theme effect if crossed.
- Edit uses the same sheet prefilled. Edit does not change `thankYouPending`.

### 9.4 Blesser profile
- Back button, rank "#N", rename and merge actions (merge moves all blessings to another blesser then deletes this one).
- Avatar and name (hidden avatar in Quiet), stat cards: Lifetime, Times, Average.
- "By year" small bar chart (Swift Charts `BarMark`).
- Thank-you toggle with caption, tied to `thankYouPending` and its reminder.
- List of all their blessings.

### 9.5 Insights
- Title and a 3-way segmented control: By person, By month, By occasion.
- Range chips: This month, This year, All time (default), Custom.
- Donut chart (`SectorMark`, `innerRadius: .ratio(0.62)`, `angularInset: 1`) with the total in the middle. Show the top 4 groups plus "Others" (merged). Colors from `theme.chart`. Thickness and outline per `donutStyle`.
- Legend list: color swatch, label, percent, amount.
- Fun-fact card: "{Top occasion} brought in {pct}% of your honeypot."
- Empty state when no data in range.
- Every chart has an accessibility summary (`accessibilityLabel` listing groups and percentages).

### 9.6 Hall of Fame
- Title from theme. Podium for the top 3 blessers (order 2, 1, 3), ranked list from 4 onwards.
- Milestones strip: 1k, 5k, 10k, 20k as Reached or Locked.
- Gratitude queue: blessers with `thankYouPending`, each with a "Mark thanked" button.
- "Share year-in-review card": render a themed card (top blesser, total, count, top occasion) with `ImageRenderer` and share via `ShareLink`.

### 9.7 Settings
- General: Country and currency (opens the rate flow on change), Honeypot goal (stepper in 5,000 steps, minimum 5,000 in the mock; use a text field with numeric pad for any value).
- Vibe: three selectable cards with live preview.
- Privacy: Face ID lock toggle (verify with a prompt before enabling), Hide amounts by default toggle.
- Gratitude: Reminder delay (Off, 1, 3, 7 days).
- Data (stays on this device): Export CSV, Back up to file (JSON), Restore from backup, Erase all data (two-step confirm: first tap changes the label to "Tap again to erase everything", plus a system confirmation dialog).
- Footer: "No cloud, no account. Back up regularly: if you lose this phone, the honeypot is gone."

### 9.8 Lock screen
Shown when Face ID is enabled and the app is locked. Themed background, an unlock button, and an automatic attempt on appearance.

## 10. Feature checklist (all in scope for v1)

- [ ] Blessing list, add, edit, delete with undo
- [ ] Auto timestamp (editable)
- [ ] Country on first use, changeable in Settings, with exchange-rate conversion
- [ ] Donut chart by person, month, occasion, with range filters
- [ ] Honeypot hero total, monthly delta, goal progress
- [ ] Blesser profiles, autocomplete, rename, merge
- [ ] Occasion tags and payment method
- [ ] Search, sort, filter
- [ ] Hall of Fame (podium, milestones), milestone effects per theme
- [ ] Thank-you tracking and local reminders
- [ ] Hide amounts and Face ID lock
- [ ] CSV export, JSON backup and restore
- [ ] Three themes, swappable, with live preview
- [ ] Photo attachment
- [ ] Year-in-review share card
- [ ] Home screen widget (phase 12)

## 11. Conventions for the implementing agent

1. No third-party packages. Apple frameworks only.
2. `Decimal` for all money, and never convert through `Double`. Parse user input with `Decimal(string:locale:)`.
3. No force unwraps and no `try!` outside tests and previews.
4. Every screen has an `#Preview` using an in-memory `ModelContainer` seeded by `SeedData`, shown in all three themes.
5. All colors and fonts come from `@Environment(\.theme)`. No hard-coded colors in feature views.
6. Accessibility: labels on icon-only buttons, Dynamic Type via `relativeTo:`, minimum 44pt tap targets, VoiceOver summaries for charts, honor Reduce Motion.
7. Keep views small. Extract a subview once a `body` passes about 80 lines.
8. Do not make network calls. Do not add analytics or crash reporting.
9. Small, reviewable commits. One phase per branch or PR. Run tests before each commit.
10. If something in this file is ambiguous or seems wrong, stop and ask the owner. Do not invent large features.

## 12. Build phases

Each phase ends with: it builds, tests pass, previews render in all themes, and the acceptance points hold.

**Phase 0, setup.** Create the project and folder structure (section 4). App launches to an empty `RootView`. *Accept: builds and runs on iPhone simulator.*

**Phase 1, models and services.** Models (5), enums, `MoneyFormatter`, `CountryCatalog`, `BlesserResolver`, `MilestoneService`, `CurrencyConverter`, `SeedData`. *Accept: unit tests cover decimal rounding (including JPY), resolver case-insensitivity, milestone crossing, converter original-amount preservation, and rate direction (`1/input`).*

**Phase 2, theme system.** `AppTheme`, three themes from the section 8.2 table, fonts bundled, environment key, themed components, and a DEBUG "Theme gallery" screen. *Accept: gallery shows each theme's hero, a row, a button, an avatar and a donut with correct colors and fonts; text contrast holds.*

**Phase 3, onboarding.** Country step, vibe step with live preview, creation of `AppSettings`. *Accept: first launch shows onboarding; after finishing it never shows again; device region preselected.*

**Phase 4, home and add/edit.** Hero, search, chips, grouped list, swipe actions, editor sheet with autocomplete, validation, haptics, toast. *Accept: add three blessings; names autocomplete without creating duplicates; delete shows undo; list persists across relaunch; hide-amounts blurs everything.*

**Phase 5, blesser profile.** Stats, by-year chart, thank-you toggle, rename, merge. *Accept: merge moves all blessings and removes the old blesser; stats match the list.*

**Phase 6, insights.** Donut, legend, modes, range chips, fun fact, empty state. *Accept: percentages sum to 100; "Others" appears only above 5 groups; chart readable in all themes.*

**Phase 7, hall of fame and effects.** Podium, ranking, milestones, gratitude queue, year-in-review card, the three effects. *Accept: an add that crosses 10,000 fires the active theme's effect once; Reduce Motion disables animation; share card renders.*

**Phase 8, settings and currency conversion.** All settings, vibe picker, `CurrencyRateSheet` with swap, preview, convert and label-only paths, conversion log. *Accept: MYR to USD at `1 MYR = 0.21 USD` converts every amount and the goal; swapping sides and entering `4.76` gives the same rate within rounding; Cancel changes nothing; originals preserved.*

**Phase 9, privacy.** Face ID lock, privacy cover in the app switcher, hide-by-default. *Accept: backgrounding then returning requires auth; app-switcher snapshot is covered.*

**Phase 10, export and backup.** CSV, JSON backup, restore with confirmation, erase-all. *Accept: backup then erase then restore returns identical data (compare counts and totals); bad files show a friendly error.*

**Phase 11, reminders.** Permission request on first enable, schedule, cancel on thanked, reminder delay setting. *Accept: a pending blesser produces one notification at the right delay; marking thanked removes it.*

**Phase 12, widget and polish (optional but planned).** Move the store to an App Group container, add a WidgetKit small widget showing the honeypot total (respect hide-amounts), app icon, launch screen, final accessibility pass, empty states, haptics review. *Accept: widget updates after an add; no regressions in earlier phases.*

## 13. Testing

- Unit: models, converter, resolver, milestone, CSV output, backup round trip, rate parsing for `,` and `.` locales.
- UI (basic): onboarding, add a blessing, see it in the list and in Insights, change vibe, change currency.
- Manual checklist before release: all three themes on small (SE) and large (Pro Max) screens, Dynamic Type at the largest accessibility size, VoiceOver on Home and Insights, airplane mode (everything must still work), delete and reinstall to confirm the first-run flow.

## 14. Seed and preview data (DEBUG only)

Use these in `SeedData` so previews match the mocks. Currency MYR.

| Name | Amount | Occasion | Date |
|---|---|---|---|
| Aunt Mei | 888 | Chinese New Year | 2026-02-02 10:14 |
| Dad & Mum | 1000 | Chinese New Year | 2026-02-01 20:30 |
| Dad & Mum | 500 | Birthday | 2026-01-14 08:02 |
| Uncle Tan | 300 | Wedding | 2025-12-09 19:40 (thank-you pending) |
| Wong & team | 1200 | Promotion | 2025-11-28 12:30 |
| Ah Kong | 88 | Just because | 2025-11-03 16:05 |
| Cousin Lin | 1100 | Wedding | 2025-10-05 15:00 |
| Aunt Mei | 500 | Birthday | 2025-08-21 09:00 |
| Cousin Lin | 420 | Hari Raya | 2025-04-01 11:00 |
| Uncle Tan | 800 | Wedding | 2025-03-15 17:20 |
| Aunt Mei | 800 | Chinese New Year | 2025-02-10 10:00 |
| Ah Kong | 880 | Chinese New Year | 2025-01-29 09:30 |
| Dad & Mum | 600 | Birthday | 2025-01-14 08:00 |
| Aunt Mei | 300 | Christmas | 2024-12-25 21:00 |
| Dad & Mum | 400 | Birthday | 2024-01-14 08:00 |

Total 9,776. Adding 300 crosses the 10,000 milestone, which is the easiest way to demo the effects.

## 15. App icon

Concept: **"My cup overflows"**. A gold pot of honey and coins running over, with a simple cream cross on the pot and soft rays of light behind it. It draws on Psalm 23 ("my cup overflows") and the promised land "flowing with milk and honey". The aim is gratitude and blessing, welcoming to a wide Christian audience.

Preview (private link, owner can share): https://claude.ai/artifact/28s8uApjANhcj9L3UibLwe

**Deliverables**
- Three 1024×1024 PNGs in `Assets.xcassets/AppIcon`: Any Appearance, Dark, Tinted.
- No alpha channel and no pre-rounded corners (iOS applies the mask). Keep key shapes inside the central 80%.

**Composition (1024 canvas)**
- Ground: flat jade. Behind the pot, 12 soft light rays fanning from a point at (512, 430), at 11 to 16% opacity.
- Pot: round-bellied gold body (about 450 wide, 320 tall), darker gold rim ellipse with a dark opening, coins rising from the opening (three gold coins, each with an inner ring and a square hole).
- Honey: an amber drip down the left side of the pot.
- Cross: cream, two rounded rectangles on the pot's belly (vertical 44×162, crossbar 128×44, corner radius 8) with a soft shadow.
- A shadow under the pot and two coins lying at the base.
- Shading uses flat 20 to 30% white or black overlays. No gradients inside the pot.

**Colors**

| Part | Light | Dark | Tinted (grayscale) |
|---|---|---|---|
| Ground | #0B3B2E | #04170F | #0E0E0F |
| Pot | #E0B83E | #C9A23A | #E8E8E8 |
| Rim, coin edge | #B98A1E | #94701A | #9A9A9A |
| Cross | #FFF4D6 | #F1E6C3 | #3A3A3A |
| Honey | #FFB627 | #E39A1C | #CFCFCF |
| Coins | #F2CE5B | #E2BE55 | #F5F5F5 |
| Rays | #F2CE5B | #F2CE5B | #FFFFFF |

**Checks**: at 40 px the pot, coins and cross must still read. If the owner decides a cross is not right for a money app, ship the same icon without the cross (rays and honey only).

## 16. Releasing to the App Store

Do this after phase 12, with the owner doing the account steps. The agent prepares files and checklists but cannot enrol, sign in to App Store Connect, or submit.

1. **Apple Developer Program.** Owner enrols (US$99 per year, individual is simplest). Needed for TestFlight and App Store.
2. **Finalize the app.** Set the final bundle id and display name. Add the icon (section 15). Set version `1.0` and build `1`. In Xcode: Signing & Capabilities, choose the team, automatic signing.
3. **Info.plist and compliance.** Set `ITSAppUsesNonExemptEncryption` to `NO` (no custom encryption). Confirm `NSFaceIDUsageDescription` and the font entries are present. Confirm there are no network calls and no tracking, so no `NSUserTrackingUsageDescription`.
4. **Create the app in App Store Connect.** New app, platform iOS, name, primary language, bundle id, SKU. Category: Finance or Lifestyle. Complete the age rating questionnaire.
5. **Privacy.**
   - App Privacy answers: **Data Not Collected** (nothing leaves the device).
   - A **privacy policy URL** is required. Publish a short page (GitHub Pages is enough) stating that all data is stored only on the device, nothing is collected or shared, and exports are created only when the user requests them.
   - A **support URL** is required (a page or contact page).
6. **Store listing.** Description, subtitle, keywords, 1024 icon, and iPhone screenshots at the currently required size (6.9"). Use screenshots of the three vibes: home list, insights pie, hall of fame, add sheet. Do not show real personal data; use the seed data in section 14.
7. **Build and upload.** In Xcode: select "Any iOS Device (arm64)", Product, Archive, Distribute App, App Store Connect, Upload. Wait for processing.
8. **TestFlight.** Internal testers need no review. Optionally add external testers (up to 10,000, short beta review). Test on a real device: first-run onboarding, add and edit, exchange-rate conversion, Face ID, reminders permission, backup then erase then restore, all three themes, smallest and largest iPhones, Dynamic Type at large sizes, airplane mode.
9. **Submit for review.**
   - Pick the build, fill in review notes: "No login or account. Face ID is optional. All data is stored locally on the device."
   - Choose release method (manual recommended for the first release) and pricing (free or paid).
   - Submit. Review usually takes a day or two. If rejected, read the message in Resolution Center, fix, and resubmit.
10. **After release.** Keep a backup of the signing assets and the source. Plan updates by bumping the build number for each upload.

**Without a public release**: a free Apple account lets the owner install from Xcode to their own phone (the build expires after 7 days). A paid account lets the owner share via TestFlight with friends and family and builds last 90 days, with no public listing.

Note for the store description and in-app Settings: the app has no cloud. iPhone device backups (iCloud or computer) include the app's data by default, and the in-app JSON backup is the user's own extra safety net.

## 17. Open items for the owner (not blockers)

- Final bundle id and App Store display name. "Count 'Em Blessingz" is the working title and fits the 30-character limit; "Blessingz" is a short option for the home screen label.
- Whether to keep the cross on the icon (section 15).
- Whether restore should offer a "merge" option later.
- Whether to add iCloud backup as an opt-in v2 (kept out of v1 on purpose).
