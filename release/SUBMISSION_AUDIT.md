# Submission audit (2026-11-12)

Read-only audit of the code and docs against the App Store material. **Nothing in the app, `release/listing.md` or `docs/` has been changed.** Items that need a code or text change are marked *needs approval*. Line numbers refer to `main` at a623f3c. Apple pages used: age ratings values and definitions, DSA trader requirements, screenshot best practices, app preview specifications (developer.apple.com, fetched today). Apple's questionnaire wording and the live App Store Connect form could not be seen, so re-check them on screen.

## 1. Claims verified against the code

| Claim | Verdict | Evidence | Fix needed |
|---|---|---|---|
| No network code | **True** | No `URLSession`, `NWConnection`, `WKWebView`, `SafariServices`, `CloudKit`, `UIApplication.open` or `Link(` anywhere in `CountEmBlessingz/` or `CountEmBlessingzWidget/`. Store is `cloudKitDatabase: .none` (`Models/SharedStore.swift:16`). Only outbound paths are system sheets: `ShareLink` (`HomeView.swift:184`, `DataSection.swift:93`, `HallView.swift:51`) and `fileImporter` (`DataSection.swift:61`). | None |
| No third-party SDKs, analytics, ads, tracking | **True** | `project.yml` has no `packages:` section; no `Package.resolved`; no `AdSupport`, `AppTrackingTransparency` or analytics imports. | None |
| Exchange rate is entered by the user, not fetched | **True** | `Features/Settings/CurrencyRateSheet.swift:4-6` ("Asks for an exchange rate"), `:73-75` (user text), `Services/RateEntry.swift` parses typed text. No fetch code exists. | None |
| "Data Not Collected" (App Privacy) | **True** | Nothing leaves the device except through user-initiated share sheets (above). Matches Apple's definition (data not transmitted off device). | None |
| "No tracking" | **True** | No ATT, no IDFA, no analytics (above). Say "no tracking" only as "does not track you", as the policy does. | None |
| Privacy manifest (`PrivacyInfo.xcprivacy`) | **Missing** | `find . -name PrivacyInfo.xcprivacy` returns nothing, for the app and the widget. | *Needs approval:* add a minimal manifest to both targets (see below). Not strictly required today because no Required Reason API is used, but it is the safe, expected declaration. |
| Required Reason APIs | **None used in Release** | `UserDefaults`: only `App/MainView.swift:9-13` and `:56-64` and `App/CountEmBlessingzApp.swift:13-30`, all inside `#if DEBUG`. File timestamps, disk space, boot time, active keyboards: no matches. `Services/ExchangeFile.swift:366` reads only the file **size** (`.size`), not a timestamp or free space. | None. Manifest below declares none. |
| Minimal manifest content | n/a | `NSPrivacyTracking` = false; `NSPrivacyTrackingDomains` = []; `NSPrivacyCollectedDataTypes` = []; `NSPrivacyAccessedAPITypes` = []. | Same *needs approval* as above. |
| `ITSAppUsesNonExemptEncryption` = false | **True** | `project.yml:30`. No `CryptoKit`/`CommonCrypto` use in the code. Face ID uses `LocalAuthentication` only (`Services/BiometricLock.swift:11-14`). | None |
| iPhone only, portrait only | **True now** | `TARGETED_DEVICE_FAMILY: "1"` on every target (`project.yml:9,63,97,113,125`); `DeviceFamilyTests`. (This was wrong until a623f3c.) | None |
| `docs/privacy-policy.md` matches the code | **Mostly** | Snapshots: 3 kept, excluded from backup, file-protected (`Services/ImportService.swift:40,196-203`). Reminders: generic text when previews hidden (`Services/ReminderService.swift:77-80,105`). Photos: max 1600 px, JPEG (`Services/BlessingService.swift:145-151`). Widget hides total with Face ID (`CountEmBlessingzWidget.swift:39`). No contacts, camera, microphone or location APIs in the code. | **Small gap:** shared files also carry a *sharing name* (`exportedBy`, `Services/ExportService.swift:168`; defaults to the device name, `Models/AppSettings.swift:23-25`). The policy lists "names, amounts, notes and photos" only. *Needs approval:* add "and the sharing name shown in Settings". |
| App Privacy answers equal the policy | **Yes** | Both say nothing is collected, no tracking, data stays on device. | None |
| `UIDevice.current.name` as default sharing name | **Works, but generic** | `SettingsView.swift:38`, `AppSettings.swift:25`. On iOS 16+ without a special entitlement, iOS returns a generic name such as "iPhone", so the default label is not personal and not a privacy leak. | Optional: nudge users to set a name. Low priority. |

## 1b. Info.plist usage strings

| Key | Present | Used for | Verdict | Proposed wording |
|---|---|---|---|---|
| `NSFaceIDUsageDescription` | Yes, "Unlock your honeypot" (`project.yml:71`, confirmed in the uploaded build) | `LAContext.evaluatePolicy` (`BiometricLock.swift:14`) | **Vague**; "honeypot" is the app's own jargon and does not say what Face ID does. Apple reviewers ask for a clear purpose. | `Count 'Em Blessingz uses Face ID to keep your blessings private. You can also unlock with your passcode.` (112 characters). *Needs approval; ships in build 2.* |
| Photo library | Not needed | `PhotosPicker` runs out of process (`BlessingEditorSheet.swift:185`) | Correct: no key required | None |
| Camera, microphone, contacts, location | Not used | n/a | Correct | None |
| Notifications | No plist key exists for them | `requestAuthorization` (`ReminderService.swift:49`), asked at first save or when reminders are turned on, not at launch | Correct | None |

## 1c. Widget, App Group, file type: review risks

| Item | Verdict | Evidence | Fix |
|---|---|---|---|
| App Group identical in app, widget and code | OK | `project.yml:56,93`; both entitlements files; `SharedStore.swift:7` | None |
| Widget privacy | OK | Hides total when Face ID lock is on (`CountEmBlessingzWidget.swift:39`) | None |
| **Widget fallback shows a goal** | **Inconsistent** | `CountEmBlessingzWidget.swift:31` falls back to `goal: 20_000` when the store cannot be read; with goals now optional it would show "0% of goal". Edge case only. | *Needs approval:* use `goal: 0`. Trivial. |
| **Widget version literals** | **Latent risk** | `CountEmBlessingzWidget/Info.plist:20,22` hard-code "1.0" and "1" instead of `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`. If you raise the app build to 2, the widget stays at 1; App Store Connect can reject an extension whose version does not match its app. I could not verify the exact rule today. | *Needs approval:* switch both literals to the build-setting variables. Do this before build 2. |
| `.blessingz` type | OK | Exported UTI `com.clemzzz.countemblessingz.exchange` conforming to `public.json`, extension `blessingz` (`project.yml:22-28`); role Viewer, rank Owner (`:34`); not opened in place (`:29`). Standard pattern. | None |
| Debug-only code in Release | OK | Theme gallery and demo flags are inside `#if DEBUG` (`SettingsView.swift:91-94`, `ThemeGalleryView.swift:1,44`, `MainView.swift:9-13`). | None |
| **Third-party names in the UI** | **Rejection risk (medium)** | `Theme/Themes.swift:5,32,59` describe the looks as "Crazy Rich Asians", "Wes Anderson" and "Succession", and `Features/Onboarding/VibeStep.swift:47` shows that text on screen. Naming other people's films, shows or a person is an intellectual-property flag (App Review Guideline 5.2). The App Store screenshots do not show it (`VibePicker` does not use the text). | *Needs approval:* replace the three descriptions with neutral text, for example "Deep jade, gold leaf and lacquer red.", "Candy pink, plum and a touch of theatre.", "Old money, muted brass, no shouting." Ships in build 2. |

## 2. Accessibility Nutrition Labels (App Store Connect)

The automatic audit covers element descriptions, hit regions, traits and clipped text on 14 screens (`AccessibilityAuditUITests.swift:44`). **It explicitly skips contrast** (`:32`); contrast is covered by `ThemeTests` instead. You already ran VoiceOver and the other device checks and reported they worked, but I did not see the device, so "owner-checked" below means your report.

| Feature | Answer | Evidence | What blocks a stronger claim |
|---|---|---|---|
| VoiceOver | **Yes** (claim after your own pass over every task) | 46 explicit accessibility modifiers; icon buttons labelled (`MainView.swift:177`, `BlesserProfileView.swift:70`); donut has a spoken summary (`DonutChart.swift:51-52`), legend rows combined (`LegendList.swift:49`), by-year chart labelled (`BlesserProfileView.swift:143-144`); inactive tabs hidden (UI test). Audit passes. | Apple requires all common tasks to work; confirm the Add sheet, import review and Settings by VoiceOver once more. |
| Voice Control | **Not yet** | Controls have visible text or labels (audit "sufficient element description" passes), but nobody has driven it by voice. | A 15-minute pass with Voice Control > "Show names". Then claim. |
| Larger Text | **Yes, with a caveat** | Custom fonts use `relativeTo:` so they scale (`Theme/Fonts.swift:9-14`); layouts switch at accessibility sizes (`LegendList.swift:17`, `ImportReviewParts.swift:119,357`); UI test at the largest size (`CoreFlowUITests.swift:258`). Capped on purpose: tab bar (`MainView.swift:203`), donut centre (`DonutChart.swift:39`), avatar initials (`ThemedComponents.swift:68`). | Apple expects text to reach at least 200%; the tab-bar cap stops at xxxLarge. Decide whether you are comfortable claiming it. |
| Dark Interface | **Not yet** | Each look fixes its own appearance and ignores the system setting (`Theme/AppTheme.swift:37`, `ThemeEnvironment.swift:18`). Jade and Quiet are dark, Grand is light. | The app does not follow the system dark setting. Claiming it is a judgement call; I would not claim. |
| Differentiate Without Color Alone | **Not yet** | Donut slices are told apart by colour, matched to the legend by coloured dots only (`LegendList.swift:21,34`); selected filter chips change fill colour only (`HomeView.swift:195-207`). | See fixes 1 and 2 below. |
| Sufficient Contrast | **Yes, with one note** | Every declared text and background pair is at least 4.5:1 in all three looks (`ThemeTests.swift:31-51`). Note: avatar initials are only held to 3:1 as "large bold text" (`ThemeTests.swift:53-55`; `BLUEPRINT.md` says Jade is about 4.4:1). Non-text contrast is not tested. | If you want to be strict, raise the avatar contrast to 4.5:1 (changes theme tokens; `ThemeTests` enforces). |
| Reduced Motion | **Not yet** | Big effects respect it: coin rain, chapter card, count-up (`MainView.swift:22`, `CountUpText.swift:5,13`), import and Home scroll. But small slides and fades ignore it: toast (`ToastCenter.swift:51`, `MainView.swift:39`), look change fades (`VibePicker.swift:11`, `VibeStep.swift:20`), onboarding step (`OnboardingView.swift:23,38`), date picker (`BlessingEditorSheet.swift:139`), insights picker (`InsightsView.swift:26`). | Fix 3 below. |
| Captions / Audio Descriptions | **Not applicable** | No audio or video. Leave unclaimed. | None |

**Code fixes that would let you claim more, ranked by effort** (all *need approval*):
1. **Selected chips:** add a checkmark icon to the selected state (`HomeView.swift` chip), about 15 minutes. Helps Differentiate Without Color.
2. **Donut and legend:** show the percentage on or beside each slice, or add thin white separators and number the legend, about 1 to 2 hours. Completes Differentiate Without Color.
3. **Reduced Motion helper:** one small function that returns no animation when Reduce Motion is on, used at the 7 spots above, about 1 hour.
4. **Voice Control pass:** no code, 15 minutes, may reveal nothing to fix.
5. **Avatar contrast to 4.5:1:** adjust `avatarText`/`avatarBackground` per look; `ThemeTests` will prove it; about 1 hour. Needs a contrast re-check per your rule.
6. **Dark Interface:** only if you want the app to follow the system; this is a design change, not recommended for 1.0.

## 3. Keywords and localization

**Current** (`listing.md:29`, 100/100): `angpao,ang pao,red packet,hongbao,money gift,gift tracker,wedding gift,birthday,CNY,thank you,family`

Problems: `angpao` and `tracker` repeat the subtitle (wasted), and Apple builds phrases from single words, so multi-word entries waste spaces and commas.

**Proposed** (98/100):

```
duit,raya,hari,ang,bao,pow,pao,angbao,hongbao,red,packet,cny,lunar,wedding,birthday,gift,money,thr
```

- Phrases still match because Apple combines words: "duit raya", "hari raya", "ang bao", "ang pow", "ang pao", "red packet", "lunar new year" (with "new year" if you add it), "wedding gift", "money gift", "birthday gift".
- Added: `duit`, `raya`, `hari`, `ang`, `bao`, `pow`, `pao`, `angbao`, `lunar`, `thr` (Indonesian holiday bonus, a common search).
- Dropped: `angpao` and `gift tracker` (already in the subtitle; "tracker" and "angpao" are indexed from it), `thank you`, `family` (generic and low value), and the spaces.
- Not included, to stay within 100: `hongpao`, `envelope`, `shagun` (Indian wedding money gifts), `ledger`. Swap in `shagun` for `lunar` if you want to reach Indian families first.
- Rule check: no competitor names, no "best", no prices.

**Languages, ranked by impact.** A localized *store listing* with an English-only app is allowed. It improves search and trust, but the app opens in English, so say so honestly in the description ("The app is in English") to avoid a "misleading metadata" complaint.

| Rank | Language | Why | Effort | Verdict |
|---|---|---|---|---|
| 1 | Simplified Chinese | Largest searcher base for 红包 (hóngbāo), Malaysia, Singapore | Medium: name stays, subtitle, keywords, description, promo text | Worth it |
| 2 | Bahasa Melayu | "duit raya" and "angpau" searches in Malaysia | Medium | Worth it |
| 3 | Bahasa Indonesia | "angpao", "THR" searches in Indonesia; big market | Medium | Worth it |
| 4 | Traditional Chinese | Malaysia/Singapore overlap is small; Taiwan/HK is not your audience | Medium | Later |
| 5 | Tamil | Smaller store audience; Tamil searchers often use English | Higher | Skip for 1.0 |

My recommendation: add Simplified Chinese, Bahasa Melayu and Bahasa Indonesia **listings only**, and only after the English listing is approved. I will not write translations until you approve.

## 4. Other forms

**Digital Services Act trader status.** You decide; Apple does not. For a free app by an individual with no ads, no in-app purchases and no business activity, "This is not a trader account" fits. Steps: App Store Connect > **Business** > **Agreements** > Compliance > Digital Services Act > Complete Compliance Requirements > "This is not a trader account" > Done. No contact details are needed or published. Consequence: EU consumers are told consumer-protection rights do not apply to you. If you ever add ads, purchases or a business, you must switch to trader, and then **your address (or P.O. box), phone and email become public on EU product pages**. If unsure, ask a legal adviser; I cannot give legal advice.

**Pricing and regions (free, all).** Free is fine. Flags:
- **China mainland** needs an ICP filing number to distribute (Apple's rule; check Pricing and Availability in your account, I could not verify today's wording). Without one, deselect China mainland. Your audience is Southeast Asian, so deselecting it costs little.
- **EU:** DSA declaration above.
- **Encryption:** none beyond iOS, so no export paperwork (`project.yml:30`); Face ID is an OS feature.
- **South Korea, Vietnam and others:** no extra rules for a non-game, non-finance app that I know of; none required to my knowledge.
- Do **not** list as Finance if you want to avoid finance-related questions; Lifestyle keeps it simple.

**Age rating.** The answer is still **4+**. Apple's current categories (from the age rating reference) include questions `listing.md:88` does not name. Answer all of them None/No:

| Section | Questions to answer None/No |
|---|---|
| In-app controls | Parental Controls, Age Assurance |
| Capabilities | Unrestricted Web Access, User-Generated Content, Social Media, Social Media disabled for under 13, Messaging and Chat, Advertising |
| Mature themes | Profanity or Crude Humor, Horror/Fear, Alcohol/Tobacco/Drug |
| Medical or Wellness | Medical or Treatment Information, **Health or Wellness Topics** |
| Sexuality or Nudity | Mature or Suggestive Themes, Sexual Content, Graphic Sexual Content |
| Violence | Cartoon/Fantasy, Realistic, Prolonged Graphic, **Guns or Other Weapons** |
| Chance-based | Gambling, Simulated Gambling, Contests, **Loot Boxes** |

Not in `listing.md`: Parental Controls, Age Assurance, Social Media (both), Advertising, Health or Wellness, Guns or Weapons, Loot Boxes, Mature or Suggestive Themes. Then **Age Categories and Override: Not Applicable**; do not choose Made for Kids. Note "gift" and "coin rain" are not gambling; answer Gambling/Contests None.

## 5. Screenshot captions (plan, nothing generated)

Apple's guidance (asset best practices): up to 3 screenshots show in search results; lead with the strongest benefits; use a short phrase that enhances the visual; keep text legible in a safe area with the focal point centred; no prices, URLs, unverifiable claims, other platforms or Apple awards; assets must suit a 4+ rating.

**Layout (per screenshot).** Canvas 1320 x 2868. Top caption band 420 px high in the look's background colour; headline centred, 2 lines max, 72 to 84 px bold; screen below scaled to about 88% (1160 px wide), centred, 48 px rounded corners, bleeding off the bottom edge. No device frame (keeps the app large and avoids clutter). Margins 90 px. System font (SF Pro Rounded Bold) so it is reproducible; Dynamic Type does not apply to image assets.

| Look | Caption band | Headline | Contrast (from `Themes.swift`) |
|---|---|---|---|
| Jade & Gold | `#0B3B2E` | `#F6EBCB` | tested 4.5:1 or better as app pair |
| The Grand Ledger | `#FFE9EE` | `#3D1D40` | same |
| Quiet Fortune | `#15171A` | `#EDE6D6` | same |

**Order and headlines (6 words max).** First three matter most.

| # | Screen | Headline | Words |
|---|---|---|---|
| 1 | `01-home` | Every angpao, safely in one place | 6 |
| 2 | `02-insights` | See who has blessed you | 5 |
| 3 | `06-import-review` | Merge family lists, no cloud | 5 |
| 4 | `03-hall-of-fame` | Never forget to say thanks | 5 |
| 5 | `04-add-blessing` | Add a blessing in seconds | 5 |
| 6 | `05-vibes` | Pick the look you love | 5 |

Changes from `screenshots.md`: warmer and more specific to angpao; the merge screen moves to slot 3 (your differentiator); no "most generous" ranking language (can read as competitive); no claims about Face ID or the widget because there is no screenshot of them. The demo screenshots show a 20,000 goal; the description now says "if you set one", so this is consistent.

**Decision for you (I will not generate anything until you answer):** (A) a script in `release/` that overlays these captions with the system font and writes 1320 x 2868 PNGs (reproducible, about 120 lines of Swift or Python, outputs 18 images); or (B) a design brief for Figma or Keynote.

## 6. App preview video (optional)

**Recommendation: skip for 1.0, add later.** Previews help conversion but cost review time and Apple processes them for up to 24 hours; the screenshots tell the story already. If you want one: spec from Apple: portrait **886 x 1920** for the large iPhone, up to 30 fps, `.mov`/`.mp4`/`.m4v`, H.264 (about 10 to 12 Mbps), stereo AAC audio track, **15 to 30 seconds**, at most 500 MB, up to 3 previews, poster frame default at 5 s. It must show the app itself.

**Storyboard (about 22 s), using the Jade look:**

| Time | Shot | On screen |
|---|---|---|
| 0 to 3 s | Home | Total and list, finger scrolls gently |
| 3 to 8 s | Add | Tap +, type a name and amount, save, toast |
| 8 to 12 s | Insights | Donut chart, tap a person in the legend |
| 12 to 17 s | Merge | Open a family file, review, tap Import |
| 17 to 20 s | Hall of Fame | Podium, thank-you queue |
| 20 to 22 s | Close | Home with the new total |

**Record:** `xcrun simctl io booted recordVideo --codec=h264 preview.mov` (stop with Control-C), after setting a clean status bar as in `screenshots.md`. The simulator records at native size; you may need to scale to 886 x 1920 (for example with `ffmpeg` or QuickTime/Compressor). Use sample data only. I have not made the video.

## 7. Final report

**(a) Fixes applied:** none to the app or listing. This file is the only change.

**(b) Needs your approval** (listed in order of risk reduction):
1. Remove film and director names from the look descriptions (`Themes.swift:5,32,59`, shown at `VibeStep.swift:47`) *medium rejection risk; ships in build 2.*
2. Better Face ID usage text (`project.yml:71`) *build 2.*
3. Widget `Info.plist` version literals to build-setting variables (`CountEmBlessingzWidget/Info.plist:20,22`) *before build 2.*
4. Add `PrivacyInfo.xcprivacy` to the app and the widget *build 2.*
5. Widget fallback goal 0 (`CountEmBlessingzWidget.swift:31`) *build 2.*
6. Privacy policy: add the sharing name to what a shared file contains (`docs/privacy-policy.md`).
7. Replace `listing.md` keywords with the proposed 98-character string.
8. Accessibility fixes 1 to 3, if you want to claim Differentiate Without Color and Reduced Motion.
9. Add localized store listings (Simplified Chinese, Bahasa Melayu, Bahasa Indonesia); I will not translate until you say yes.
10. Caption images (option A or B), and whether to make an app preview.

**(c) Values only you can supply:** App Review contact (first and last name, phone, email), legal name for the copyright line (`Clement Ten` per your notes; confirm it matches your Apple account), DSA trader choice, price and countries (decide on China mainland), whether you have an ICP filing, release method, TestFlight testers.

**(d) Remaining rejection risks:** the film/director names in the UI (item 1); a vague Face ID string (item 2); widget version mismatch when you raise the build (item 3); a missing privacy manifest (item 4); the app being English-only while advertising community terms (low; the description already says what it is); Guideline 4.2 "minimum functionality" is unlikely given the feature set. Nothing else found.

**(e) Still open from `NEXT_STEPS.md`:** fill in `release/owner-inputs.md`; **step 5**: finish the App Store page (screenshots, text, URLs, build, review info, age rating, App Privacy), TestFlight run on a real iPhone, submit, release; decisions under "Decisions you can make later" (smarter undo, iCloud, languages, tab re-tap).
