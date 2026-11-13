# Donation option ("Feed the developer")

Status: proposed, not built. Targets version 1.1, after 1.0 clears review.
Prototype: `design/donation/bless-the-maker.html` (published copy: https://claude.ai/artifact/EsmrL5QkLCWTdhqG9f1PVv)

## Decision

A tip jar in Settings, sold as five **consumable in-app purchases**. Nothing is unlocked, gated or changed after a tip. No ads, no accounts, no analytics.

All giving goes through Apple's in-app purchase. No external links or QR codes (Ko-fi, DuitNow, PayNow, GitHub Sponsors) in the app or on the support page. App Review guideline 3.1.1 expects in-app purchase for tipping the developer. Re-read the current guideline before submitting.

## Scope

| In | Out |
|---|---|
| Settings "Support" group with one row | Any locked feature or Pro tier |
| Tip sheet with five fixed amounts | Custom amounts (not possible with the App Store) |
| Thank-you state | Reminders or repeat prompts to donate |
| One-time soft prompt after sharing Year in Review | Prompts on launch or on Home |
| Optional supporter seal on the Year in Review card, themed per Vibe | Receipt upload, analytics, identifiers, external payment links |

## Products (App Store Connect, type: Consumable)

| Product ID | Display name | Description | Base price (SGD) |
|---|---|---|---|
| `<bundle id>.tip.small` | Tiny blessing | A pat on the head | 0.88 |
| `<bundle id>.tip.good` | Good blessing | One (1) kopi | 2.88 |
| `<bundle id>.tip.auspicious` | Auspicious blessing | A whole nasi lemak | 8.88 |
| `<bundle id>.tip.grand` | Grand blessing | Bubble tea, extra pearls, no regrets | 18.98 |
| `<bundle id>.tip.fortune` | Fortune blessing | I will tell my mum about you | 88.00 |

**Price points:** checked by the owner in App Store Connect, in SGD. All the chosen points exist except 18.88, so the Grand blessing uses **S$18.98**. The app always shows `Product.displayPrice` from StoreKit, so the UI adapts to whatever Apple sets.

The base currency is SGD (base country: Singapore). The prototype shows Singapore dollars only, with a disclaimer. In the app the App Store shows each price in the user's own currency, so no currency code lives in the app.

### Why five tiers, and why these
- **Anchor high, sell the middle.** An S$88 top tier makes S$8.88 look modest. Few will pick it, but it lifts what people choose in the middle. 88 is also the classic angpao number.
- **Highlight one tier, no label.** "Auspicious blessing" gets an accent border and no wording like "popular" or "recommended".
- **Keep an easy floor.** S$0.88 stays so nobody feels priced out.
- **Stay at five.** More choices slow people down and the sheet starts to scroll on small phones.
- **Eights.** Every tier contains an 8 and none contains a 4 (S$18.98 keeps two 8s). In each local storefront, App Store Connect lets you override the price point, so prefer 8s there too.

Set the SGD price points in App Store Connect and let Apple convert the other storefronts. Check the other currencies and override any that land on an awkward number.

## UX

### Settings entry
New group **Support**, placed between **Gratitude** and **Data**. One row: "Feed the developer", subtitle "Optional. Unlocks nothing.", chevron. Opens a sheet.

### Tip sheet
Medium to large detent, grabber, closed envelope. Five tier buttons, name and line on the left, the StoreKit price on the right. The middle tier (Auspicious blessing) has an accent border, with no label. The sheet scrolls on small phones.

Voice: dry and a bit derpy, first person, short. Money-related states stay plain.

| Element | Final copy |
|---|---|
| Title | Feed the developer |
| Body | No ads, no tracking, no business plan. Powered by a laptop, a lot of daydreaming and the occasional bubble tea. |
| Tiny blessing (S$0.88) | A pat on the head |
| Good blessing (S$2.88) | One (1) kopi |
| Auspicious blessing (S$8.88) | A whole nasi lemak |
| Grand blessing (S$18.98) | Bubble tea, extra pearls, no regrets |
| Fortune blessing (S$88) | I will tell my mum about you |
| Footnote, when every price contains an 8 | Unlocks nothing. Changes nothing. Just vibes and a suspicious number of eights. |
| Footnote, otherwise | Unlocks nothing. Changes nothing. Just vibes and much thanks. |
| Dismiss | Maybe later |
| Thank-you title | Thank you. |
| Thank-you body | A small celebration is happening somewhere. It is quiet and involves snacks. Nothing changes in the app. |
| Thank-you body, Fortune tier | Eighty-eight! Very auspicious. I will tell my mum. Nothing changes in the app. |
| Thank-you button | Back to counting |
| Offline | Can't reach the App Store right now. Nothing was charged. Try again? |
| Cancelled toast | No worries. Nothing charged. |
| Pending | Waiting for approval. We'll say thanks when it goes through. |

Keep the footnote and the thank-you line honest: no feature changes after any tip.

**Footnote depends on the storefront.** Only the SGD prices are set by hand. Apple converts them to every other storefront's nearest price point, and those will often have no 8s (for example a US price ending in .99). So the eights joke is shown only when it is true:
- Check the numeric `product.price` (a `Decimal`) of all five products, not the formatted string, so locales with other digits still work.
- If every price contains an 8, show the eights footnote. Otherwise show the short one.
- Overriding converted prices per storefront is optional; see Optional polish below.

### Soft prompt (idea B)
Shown under the Year in Review card after the user shares it, **at most once per year**. Wording is final:

> Glad this helped you keep count. If you like, send the maker a small blessing back.

Buttons: "Send a blessing" (opens the tip sheet) and "No thanks".

Rules:
- Show it at most once per review year. Store `donationPromptYear` when it is shown.
- Do not show it in a year in which the user has already tipped (`lastTipYear`).
- Dismissing means "not this year". It can appear again in next year's Year in Review.
- Never on launch, never on Home, never twice in the same review.
- Support stays reachable in Settings all year.

I read "more than once" as once per year's review. Showing it several times inside one review would feel like nagging, so it is not planned. There is no permanent "Don't ask again" option, by decision.

### States

| State | What the user sees | Recovery |
|---|---|---|
| Loading | Skeleton tiers | Resolves by itself |
| Offline or unavailable | "Can't reach the App Store right now. Nothing was charged." | "Try again", sheet stays open |
| Cancelled | Tiers again, toast "No charge made" | None needed |
| Pending (Ask to Buy) | "Waiting for approval. We'll say thanks when it goes through." | Close sheet. Handle in the transaction listener on next launch |
| Success | Thank-you state | "Done" returns to the previous screen |

### Per-Vibe styling
Use `AppTheme` tokens. Fonts follow each theme's display and body faces. Grand keeps its 2pt hard borders on tiers. Envelope and seal colors are per Vibe, so add `envelope`, `supporterSeal` and `supporterSealRing` tokens to `AppTheme`, reusing existing colors where equal:

| Vibe | Envelope | Seal | Seal ring and glyph |
|---|---|---|---|
| Jade & Gold | red `0xC8362C` | gold `0xD4AF37` | red `0xC8362C` |
| The Grand Ledger | crimson `0xB3223B` | crimson `0xB3223B` | gold `0xE8B04A` |
| Quiet Fortune | muted red `0xA65A5A` | bronze `0xB08D57` | dark `0x15171A` |

**Fortune seal (福).** A square chop, 38pt, corner radius 7, rotated -8 degrees, with a double border and the character 福 in a brush face. When it first appears on the Year in Review card it stamps in (scales from 1.8x to 1x and settles at -8 degrees, about 0.4s). With Reduce Motion on it simply appears. In SwiftUI use the iOS system font "Kaiti SC" with a serif fallback. Confirm it is present on iOS 17 devices. If not, bundle a subset of Ma Shan Zheng (SIL Open Font License) containing only 福. The prototype shows all three Vibes.

### Accessibility
- Tier buttons are real `Button`s, at least 44pt tall.
- VoiceOver label: "Tiny blessing, 88 cents, button" (use the localized `displayPrice`).
- Dynamic Type: tier text wraps, the sheet scrolls.
- Reduce Motion: skip the flap animation, show the open envelope directly. No confetti at any setting.
- Seal has the accessibility label "Supporter seal".
- Sheet is dismissible by swipe, "Maybe later", and VoiceOver escape.

## Implementation

Use StoreKit 2. No third-party packages (matches the existing "no packages" rule).

1. **`Services/TipJar.swift`**: an `@Observable` type.
   - `enum LoadState { loading, ready([Product]), unavailable }`
   - `func load() async` calls `Product.products(for:)` for the five IDs, sorted by price.
   - `func buy(_ product: Product) async -> Outcome` where `Outcome` is `.thanked, .cancelled, .pending, .failed`. Verify the transaction, then `await transaction.finish()`.
   - A `Task` listening to `Transaction.updates` started at app launch, so a pending purchase approved later still finishes and sets a "thank you" flag.
2. **`Features/Settings/SupportSection.swift`**: the new group and its row.
3. **`Features/Support/TipSheet.swift`**: the sheet and its five states. Tier row is a small themed view driven by `AppTheme`.
4. **`Features/Support/EnvelopeView.swift`**: SVG-style `Shape` drawing, with `isOpen` animated unless Reduce Motion is on.
5. **Year in Review**: add the soft prompt, gated by `AppSettings.donationPromptYear` and `AppSettings.lastTipYear` (see rules above).
6. **`AppSettings`**: add `donationPromptYear: Int? = nil`, `lastTipYear: Int? = nil` and `showSupporterSeal: Bool = false`. SwiftData lightweight migration should cover default-valued properties; confirm with the existing migration tests.
7. **Seal (idea C, included)**: render the 福 chop on the Year in Review card when `showSupporterSeal` is on, using the Vibe's seal colors above. The thank-you screen offers a checkbox, off by default. No receipt check. It is cosmetic and local.
8. **Widget**: no change.
9. **`project.yml`**: add the In-App Purchase capability, then `xcodegen generate`.
10. **StoreKit config**: add `Support.storekit` with the five products for local testing and UI tests. Do not ship it in Release.

### Tests
- Unit: tier ordering (five tiers, sorted by price), outcome mapping for each `Product.PurchaseResult`, that the soft prompt shows once per year, is skipped after a tip that year, and returns the next year after a dismissal, that the seal flag defaults off.
- UI: sheet opens from Settings; each store state renders (use the StoreKit test session with failures injected); the accessibility audit passes on the sheet in all three Vibes.

## App Store Connect checklist

1. Agreements, Tax and Banking: sign the **Paid Apps Agreement** and complete bank and tax details. In-app purchases cannot be sold without it.
2. Create the five consumables with the IDs above, localized names and descriptions, and a price.
3. Add a review screenshot for each product (the tip sheet in a Release build).
4. Attach the products to the 1.1 submission.
5. Join the **App Store Small Business Program** if not already in it (15% commission instead of 30%).
6. Review notes: "Tip jar only. The five purchases are optional consumables that unlock nothing."

## Listing and privacy updates

- The README and listing say "No network code at all". After this change that is no longer exact. Reword to: "No analytics, no tracking, no account. The only network use is Apple's own purchase sheet if you choose to leave a tip." Update `README.md`, `release/` listing text, `docs/privacy-policy.md` and `docs/support.md`. Do not add external donation links or QR codes to any of them.
- App Privacy label: purchases made through StoreKit do not require a data type for this app, since you receive nothing but Apple's payout reports. Re-check the questionnaire when you edit it.

## Decisions

| Question | Decision |
|---|---|
| Supporter seal | Included. A 福 chop, colored per Vibe (gold, crimson and gold, bronze). Opt-in, off by default |
| Tier amounts | Five tiers built on 8s: 0.88, 2.88, 8.88, 18.98, 88.00 SGD. Prices shown in SGD only in the prototype, with a disclaimer |
| Highlighted tier | Auspicious blessing, accent border only, no label |
| Soft prompt | Ship in 1.1. Wording B is final. At most once per year, skipped after a tip that year |
| External links or QR codes | None. In-app purchase only |
| "Don't ask again" | Not included |

Nothing is open. No permanent "Don't ask again" option: the prompt is limited to once a year, and "No thanks" only skips that year.

## Optional polish

Not required for 1.1. Decide while building.

**Override converted prices with 8-based ones.** Apple converts the SGD prices to every other storefront automatically. For the storefronts that matter most to you (for example MYR, IDR, USD), you can replace the converted price with an 8-based price point.
- Where: in App Store Connect, open each in-app purchase, then its price schedule, and set a manual price for that storefront.
- Effect: more users see the eights footnote, and the prices keep the lucky-number feel outside Singapore.
- Cost: five products times each storefront you choose, kept up by hand. Apple may also adjust prices for currency or tax changes, so recheck now and then.
- If you skip it: nothing breaks. Those users see the short footnote.

## Rollout

1. Finish 1.0 review. Do not touch the submitted build.
2. Branch for 1.1, build items 1-6 and the tests.
3. Create the five products in App Store Connect and test with a sandbox account on a real device.
4. Update listing and privacy text, submit 1.1.
5. Aim for release a few weeks before Chinese New Year or Hari Raya, when people open the app most.

## Expectations

Treat income as modest and seasonal. A niche utility with a free tip jar usually sees a small fraction of a percent of users tip. The goal is to cover the developer fee and a little more, not to replace a salary.
