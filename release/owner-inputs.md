# What only you can provide

Fill this in first. Each item says where it is used. Items marked **required** block submission.

## Apple account

| Done | Item | Notes |
|---|---|---|
| [ ] | **Paid Apple Developer Program membership** (required) | US$99 per year. An individual account is simplest. Needed for TestFlight, the App Store, and for the widget's App Group on a real iPhone. A free account cannot use App Groups. |
| [ ] | **Team** (required) | Chosen in Xcode under Signing & Capabilities, for both the app and the widget. |
| [ ] | Apple ID used for App Store Connect | |

## Identifiers

| Done | Item | Your value | Used in |
|---|---|---|---|
| [ ] | **Bundle identifier** (required): reverse domain, for example `com.yourname.countemblessingz` | | Set by `release/set-identifiers.sh`. Also the "Bundle ID" in App Store Connect. It cannot be changed after the first upload. |
| [ ] | App Group id (derived, nothing to choose) | `group.<your bundle id>` | Created automatically when you sign (Xcode registers it). |
| [ ] | SKU (any private label, letters and digits) | for example `COUNTEM001` | App Store Connect, when creating the app. |
| [ ] | **App name is available** (required) | `Count 'Em Blessingz` | App Store names are unique across the store. If it is taken, pick a variant such as `Count 'Em Blessingz: Angpao`. It must be 30 characters or fewer. |

## Contact and legal

| Done | Item | Your value | Used in |
|---|---|---|---|
| [ ] | **Contact email** (required) | | Replace `[your contact email]` in `docs/privacy-policy.md` and `docs/support.md`. Also the App Review contact. |
| [ ] | **Legal name or company** (required) | | Copyright line: `2026 <name>`. |
| [ ] | **Privacy policy URL** (required) | | Your published `docs/privacy-policy.md` (see submission guide, step 3). |
| [ ] | **Support URL** (required) | | Your published `docs/support.md`. |
| [ ] | Marketing URL (optional) | | Leave empty if you have none. |
| [ ] | App Review contact: first name, last name, phone, email (required) | | App Store Connect, App Review Information. |

## Decisions

| Done | Decision | Suggested | Notes |
|---|---|---|---|
| [ ] | Price | Free | Paid apps and in-app purchases need extra tax and banking setup, so free is the quickest. |
| [ ] | Countries and regions | All | You can limit them in App Store Connect. |
| [ ] | Primary category | Lifestyle | Finance is also reasonable (see `listing.md`). |
| [ ] | Release method | Manual | You press Release after approval, so you control the day. |
| [ ] | TestFlight testers (emails) | Family who will use it | Up to 100 internal testers need no review. |
| [ ] | Two real iPhones for testing | | One for the merge test. See `real-device-checklist.md`. |

## Already decided in the code (change only if you disagree)

- Languages: English only.
- Devices: iPhone only, portrait.
- Minimum iOS: 17.0.
- Data collected: none (App Privacy answer: Data Not Collected).
- Encryption: none of its own (`ITSAppUsesNonExemptEncryption` is `NO`).
