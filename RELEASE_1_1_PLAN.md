# Release 1.1 build brief

One build, one migration. This file is the master plan for everything going into 1.1, so it can be implemented in a single run in Xcode. Nothing here is built yet.

| Part | What | Detail |
|---|---|---|
| A | Donation ("Feed the developer") | [DONATION_PLAN.md](DONATION_PLAN.md) has the copy, products, states and App Store Connect steps. Summary below. |
| B | Wishes and prayers (blessings with no amount) | This file |
| C | Photo fixes: list tag, tap to preview, save to Photos | This file |

Do not merge anything into `main` until v1.0 has cleared App Review. Branch: `claude/relaxed-lamport-blpukm`.

## Findings from reading the 1.0 code

Things that shaped this plan. File names are under `CountEmBlessingz/`.

| Finding | Where | Effect |
|---|---|---|
| Money is a non-optional `Decimal` used by about 30 call sites | `Models/Blessing.swift` and everything that sums amounts | Wishes are stored as amount `0` plus a new `kind`, not as an optional amount. This avoids a risky migration and keeps every existing total correct. |
| `ImageDownscaler` draws with `UIGraphicsImageRenderer(size:)` at the screen scale | `Services/BlessingService.swift:143` | On a 3x iPhone a "1600" image is saved at 4800 px, about 9 times more pixels than intended. Backups and `.blessingz` files (photos travel as base64) grow accordingly. |
| A saved photo is only visible as a 64 pt thumbnail inside the editor | `Features/AddEdit/BlessingEditorSheet.swift:175` | Nothing in the list shows that an entry has a photo, and nothing opens it full size. |
| Photo loading fails silently | `loadPhoto` in the editor | If the photo cannot be read (for example an iCloud photo that is slow), the user sees nothing. |
| `photoData` is external storage | `Models/Blessing.swift:13` | Reading it for every list row would be slow, so the list needs a cheap `hasPhoto` flag. |
| Duplicate detection treats equal amounts as a clue | `Services/DuplicateDetector.swift` | Two wishes from one person would both be amount 0 and look like duplicates. |
| The schema is not versioned, but defaulted properties already migrate | `Models/SharedStore.swift`, `updatedAt: Date = Date.now` | New properties with default values migrate automatically. |

I could not run the app, so these come from the code. If the photo bug you saw is something different, add it to the list in section C.

## One migration

Add these in one go so the store migrates once. Every new property has a default.

| Model | Property | Default | Used for |
|---|---|---|---|
| `Blessing` | `kindRaw: String` | `"money"` | Part B |
| `Blessing` | `hasPhoto: Bool` | `false` | Part C |
| `AppSettings` | `donationPromptYear: Int?` | `nil` | Part A |
| `AppSettings` | `lastTipYear: Int?` | `nil` | Part A |
| `AppSettings` | `showSupporterSeal: Bool` | `false` | Part A |
| `AppSettings` | `photoFlagBackfilled: Bool` | `false` | Part C backfill |

Test the migration against a store created by the 1.0 build before anything else.

## Build order

1. Model changes and migration (above), with tests.
2. Photo pipeline fix and `hasPhoto` (Part C, items 1 to 3).
3. Wish kind in the draft, service and editor (Part B).
4. Audit of every place that sums amounts or counts blessings (Part B table).
5. Exchange file, backup, CSV and duplicate detection (Part B).
6. Photo tag, preview and save (Part C).
7. Donation (Part A).
8. Strings, accessibility, tests, listing, version bump.

---

## Part A: Donation

Everything is in [DONATION_PLAN.md](DONATION_PLAN.md). Points that touch the other parts:

- Five consumable tips in SGD: 0.88, 2.88, 8.88, 18.98 and 88.00. Settings row "Feed the developer". Final copy is in the plan.
- The Year in Review prompt shows at most once per year and is skipped after a tip that year.
- The fortune seal (福) is opt-in on the thank-you screen and appears on the Year in Review card.
- Adds the In-App Purchase capability in `project.yml` and a local `Support.storekit` file for testing.
- The new `AppSettings` fields are in the migration table above.

---

## Part B: Wishes and prayers

Some blessings are not money: a wish for health, a prayer, a verse. They need to be recorded and kept with the giver, with no amount.

### Decisions

| Topic | Decision |
|---|---|
| Name | "Wish or prayer". The existing kind is labelled "Money". |
| Storage | `BlessingKind` enum: `money`, `wish`. Stored as `kindRaw`. A wish has `amount = 0`, so every existing sum stays correct without change. |
| Editor | A segmented control at the top: **Money** or **Wish or prayer**. Default is Money. |
| Wish form | Name, Occasion, Date and time, the wish text, optional photo. **Amount and Method are hidden.** |
| Wish text | The Note field, relabelled "Their wish for you" with a placeholder such as "Good health, happiness and a fruitful year". A wish needs text or a photo (for example a photographed card). |
| Switching kind | Switching Money to Wish keeps the typed amount in the draft, so switching back restores it. On save as a wish, the amount is set to 0 and `originalAmount` and `originalCurrencyCode` are cleared. When editing a saved gift, show "The amount will be removed" before saving as a wish. |
| Thank-you | Wishes also mark the giver "thank-you pending". Thanking someone for a prayer is natural. |
| Reminders | Unchanged. |
| Hide amounts | No effect on wishes, since they have no amount. The wish text is not hidden. |

### Display

| Place | Behavior |
|---|---|
| Home row, money | As today. |
| Home row, wish | A sparkle symbol (`sparkles`) replaces the amount on the right. The subtitle shows the first line of the wish after the occasion and date. VoiceOver: "Wish from Auntie Lim, Chinese New Year, Good health and happiness". |
| Home "Largest" sort | Money by amount. Wishes sort after all money, newest first. |
| Search | Already matches the note, so wishes are found by their text. |
| Optional filter | Chips "All", "Money", "Wishes" above the list. Nice to have, skip if time is short. |

### What counts

| Metric | Wishes included? | Change |
|---|---|---|
| Pot total, month total, widget | No (0) | None needed. Verify with tests. |
| Milestones and goal progress | No | `BlessingService.add` must not report a milestone for a wish. |
| "N blessings" counts (Home, Year in Review, profile) | **Yes** | Wishes are blessings. Where there is room show "31 gifts and 6 wishes". |
| Donut and Insights by person, month, occasion | No | Filter to `kind == money` in `InsightsLogic`. Otherwise zero-value slices appear. |
| "Top occasion brought in X%" | No | Money only. |
| Hall of Fame ranking and podium | Ranked by money. A person with only wishes is **not** ranked. | Filter in `HallLogic.ranking`. Show wish-only people in the list under the ranking with a "wishes" tag, so they are not invisible. |
| Profile (lifetime, average, by year) | Lifetime and average use money only | Add a line "N wishes". `BlesserService.stats` needs `moneyCount` and `wishCount`. Average = lifetime divided by `moneyCount`, so wishes do not drag it down. |
| Year in Review | Total is money only. Add a wish count. | `HallLogic.review`. |

### Touchpoints

| File | Change |
|---|---|
| `Models/Blessing.swift` | Add `kindRaw`, `kind` accessor, `BlessingKind`. `init` takes `kind`. |
| `Services/BlessingService.swift` | `BlessingDraft`: add `kind`; `problems()` requires text or photo for a wish and an amount for money. `add`, `update`, `delete` snapshot, `restore` carry `kind`. No milestone for wishes. |
| `Features/AddEdit/BlessingEditorSheet.swift` | Segmented control, hide Amount and Method for wishes, relabel the note, save message without an amount. |
| `Features/Home/BlessingRow.swift` and `Theme/ThemedComponents.swift` | `ThemedRow` takes an optional trailing view or a wish flag instead of always an amount string. |
| `Features/Home/HomeListLogic.swift` | "Largest" sort, totals unchanged. |
| `Features/Insights/InsightsLogic.swift` | Filter wishes out of the money groups and the top-occasion fact. |
| `Features/HallOfFame/HallLogic.swift`, `HallView.swift`, `PodiumView.swift`, `YearReviewCard.swift` | Ranking and review changes above. |
| `Services/BlesserService.swift`, `Features/Profile/BlesserProfileView.swift` | Stats split and the "N wishes" line. |
| `Services/CurrencyConverter.swift` | Skip wishes. Do not set `originalAmount`. |
| `Services/ExchangeFile.swift`, `ExportService.swift` | See next section. |
| `Services/DuplicateDetector.swift`, `ImportPlan.swift`, `ImportService.swift` | See next section. |
| `Features/Import/ImportReviewParts.swift` | Show "Wish" in place of a zero amount. |
| `Services/SeedData.swift` | Add sample wishes for the debug demo and for screenshots. |

### Files, backup and CSV

- **Exchange file:** add an optional `kind` key to `BlessingDTO`, decoded with `decodeIfPresent` and defaulting to `"money"`. Keep `schemaVersion` at 2. The key is additive, so existing files still read.
- **Version 1.0 receiving a wish file:** an older app ignores `kind` and imports the entry as a gift of 0 with the wish text in the note. It does not fail. This is acceptable and should be mentioned in the release notes.
- **Validation:** `isConsistent()` already allows amount 0. For a wish require a non-empty `note` or a `photo`.
- **Legacy backup (schemaVersion 1):** everything is money.
- **Backup and restore:** `ExportService.restore` must set `kind` when it builds the `Blessing`.
- **CSV:** keep the current columns in order and add `kind` as the **last** column, so existing spreadsheets do not break. For wishes the amount and method cells are empty. Update the header constant and its test.
- **Duplicate detection:** for wishes, "same" also requires an equal, trimmed, case-insensitive note. Otherwise two different wishes from one person on one day look like duplicates. Add `kind` to `LocalEntry` and `IncomingEntry` and use the stricter rule when either side is a wish. A wish never matches a money entry.
- **Import review:** a changed kind shows as "kind" in the list of changes.

### Tests to add

- A 1.0 store migrates and every entry is `money`.
- Saving a wish with text, with only a photo, and with neither (rejected).
- Switching a saved gift to a wish clears the amount and original fields.
- Totals, goal progress, milestones, widget total and Insights ignore wishes.
- Hall of Fame: wish-only person is not ranked but is listed. Profile average ignores wishes.
- Exchange file and backup round trip a wish. A file without `kind` reads as money.
- CSV has `kind` last. A wish row has empty amount and method.
- Duplicate detection: two different wishes are both new. Identical wishes are flagged.
- Currency conversion leaves wishes alone.

---

## Part C: Photo fixes

### Fix the pipeline first

1. **Resize at scale 1.** Render with a format that has `scale = 1`, so the pixel size equals the point size.

   ```swift
   let format = UIGraphicsImageRendererFormat.default()
   format.scale = 1
   format.opaque = true
   let renderer = UIGraphicsImageRenderer(size: size, format: format)
   ```

   Consider lowering the long side from 1600 to 1440. Keep JPEG quality 0.8.
2. **Show errors.** `loadPhoto` shows a spinner on the thumbnail while loading and a toast "Couldn't load that photo. Try another one" if it fails.
3. **`hasPhoto`.** Set it wherever `photoData` is set: `BlessingService.add`, `update`, `restore`, `ImportService`, and backup restore. Make it a single helper so it cannot drift from `photoData`.
4. **Backfill.** On first launch of 1.1 set `hasPhoto = (photoData != nil)` for existing entries once, guarded by `AppSettings.photoFlagBackfilled`.
5. **Optional:** recompress photos that are larger than 1600 px on the long side. Skip this if time is short. Old photos still display, only larger.

### List tag

- A small photo symbol (`photo`, filled in the accent color) shown in the row **before** the date, for any entry with `hasPhoto`.
- The tag is a button with a 44 pt hit area. Tapping it opens the preview directly. Tapping the rest of the row still opens the editor.
- The tag is read as "Has photo, button" by VoiceOver.
- The row is currently one `Button` (`BlesserProfileView.swift:52` and `HomeView`), and a button inside a button is unreliable in SwiftUI. Make the row tappable with `onTapGesture` and the tag a real `Button` with `.buttonStyle(.borderless)`, or use an overlay. Test with VoiceOver and with a real tap.
- Applies to both money and wish rows, and to the Profile list.

### Preview

A full-screen cover, `PhotoPreviewView`.

- Black or theme-dark background, the image fitted to the screen.
- Pinch to zoom, double tap to zoom in and out, drag to pan when zoomed.
- A close button at the top left, the giver's name and the date as the title.
- Swipe down to dismiss.
- Opens from the list tag and from tapping the thumbnail in the editor.
- It must receive the same shared environment objects as other sheets (see the comment on `sheetContent` in `App/MainView.swift`), and must be covered by the app switcher privacy cover and the Face ID lock like every other screen.

### Save

Two small round icon buttons (44 pt, translucent, icon only) centered under the photo, like the system Photos viewer. No text labels, so they stay light. Each has an accessibility label ("Share" and "Save to Photos").

1. **Share:** a `ShareLink` with the image. The system share sheet already includes Save Image, Copy, AirDrop, Messages and so on. This needs no permission.
2. **Save:** a button with the download arrow that writes straight to Photos using add-only access (`PHPhotoLibrary`, `.addOnly`). It shows a toast "Saved to Photos", or "Photos access is off. You can turn it on in Settings" with a link to the Settings page if the user declined.
   - Add `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` to `project.yml`, next to the Face ID key: "Count 'Em Blessingz saves a photo to your library only when you tap Save."
   - No change to the App Privacy label: the app still collects nothing.

### Tests to add

- `ImageDownscaler` returns pixels at or under the limit regardless of screen scale.
- `hasPhoto` stays equal to `photoData != nil` after add, edit (add and remove), undo delete, import, restore.
- Backfill sets the flag once.
- UI test: a row with a photo shows the tag, tapping it opens the preview, close returns to the list.
- Accessibility audit passes on the preview and on rows with the tag.

---

## Strings, listing and release

- Add every new string to the localization catalog, including the wish labels, tag labels, errors and the donation copy.
- `CFBundleShortVersionString` to 1.1 and bump the build number in `project.yml`, then `xcodegen generate`.
- README: replace "No network code at all" as described in DONATION_PLAN.md. Add wishes and photo preview to the Features list.
- Listing: update the description for wishes. Optional new screenshots for a wish row and the photo preview. The 18 existing screenshots still apply.
- What's New (draft): "Record wishes and prayers, not just money. Photos now show a tag in your list, open full screen, and can be saved to your photos. A small tip jar, if you feel like it."
- Do not put the 1.0 file-compatibility note in What's New. Mention it on the support page if you want to.
- Review notes: mention the tip jar only. See DONATION_PLAN.md.

## Definition of done

- [ ] A store from the 1.0 build opens in 1.1 with no data lost.
- [ ] Money entries behave exactly as before. All existing tests pass.
- [ ] A wish can be added, edited, deleted with undo, searched, exported, imported and restored.
- [ ] No total, chart, milestone or widget value changes because of a wish.
- [ ] New photos are stored at 1600 px or less on the long side.
- [ ] A photo tag appears in the Home list and the Profile list, opens a full-screen preview, and the photo can be shared and saved.
- [ ] Tip jar works in the StoreKit test session and on a real device with a sandbox account.
- [ ] UI accessibility audit passes in all three Vibes, including the new screens.
- [ ] README, listing text and privacy page match the build.
