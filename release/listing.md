# App Store listing copy

Copy and paste these into App Store Connect (App Store tab, version 1.0). Every field is already within Apple's character limit; the count is shown next to each.

## App information

| Field | Value | Limit |
|---|---|---|
| Name | `Count 'Em Blessingz` | 19/30 |
| Subtitle | `Your private angpao tracker` | 27/30 |
| Primary category | Lifestyle (see the note below) | |
| Secondary category | Finance (optional) | |
| Content rights | Does not contain, show or access third-party content | |
| Price | Your choice (free works with nothing else to set up) | |

> **Category note.** The app tracks gifts you receive and never handles payments, so Lifestyle fits best. Finance is also reasonable. This is your call; neither needs extra paperwork.

## Version information

**Promotional text** (159/170, can be changed any time without a new review):

```
Keep every angpao, birthday gift and wedding blessing in one private place. No account, no cloud. See who blessed you, say thanks, and merge lists with family.
```

**Keywords** (98/100, comma separated, no spaces after commas; Apple combines the single words into phrases such as "duit raya" and "ang bao", and the name and subtitle are indexed already):

```
duit,raya,hari,ang,bao,pow,pao,angbao,hongbao,red,packet,cny,lunar,wedding,birthday,gift,money,thr
```

**Description** (2211/4000):

```
Count 'Em Blessingz is a private, offline app for tracking the money people have blessed you with: angpao at Chinese New Year, birthday gifts, wedding envelopes, Hari Raya duit raya, promotion treats and more.

Everything stays on your iPhone. There is no account, no cloud and no tracking.

KEEP A LONG, HAPPY LIST
- Add a blessing in seconds: who, how much and which occasion. The time is filled in for you.
- See everything newest first, grouped by month, with a running total for your honeypot and, if you set one, progress towards a goal.
- Search by name, note or occasion. Attach a photo of the card or envelope.
- Swipe to edit or delete, with undo.

SEE THE BIG PICTURE
- A donut chart shows where your blessings came from: by person, by month or by occasion.
- Every giver has a profile with their lifetime total, how many times they blessed you and a chart by year.
- The Hall of Fame ranks your most generous givers and unlocks milestones as your honeypot grows.

SAY THANK YOU
- Each new blessing adds the giver to your thank-you list. Mark them thanked when you have, or let a gentle reminder nudge you a few days later.
- Share a year-in-review card with your top giver and favourite occasion.

COMBINE LISTS WITH FAMILY, NO CLOUD
- Share your entries as a small file through AirDrop, WhatsApp, Telegram, Mail or Messages.
- Open a file from someone else and review it before anything is added. The app spots entries you already have and possible duplicates, and never merges two people without asking.
- Undo the last import, and back up or restore everything to a file.

PRIVATE BY DESIGN
- Face ID lock, a privacy cover in the app switcher and a Hide amounts switch for when others are watching.
- A widget shows your honeypot on the home screen (hidden when Face ID lock is on).
- Works fully offline. Your data is only shared when you choose to share it.

YOUR LOOK, YOUR WAY
- Three hand-made looks: Jade & Gold, The Grand Ledger and Quiet Fortune.
- Choose your country and the app sets your currency. Changing it later asks for an exchange rate so your amounts convert correctly.

Count 'Em Blessingz is for keeping track of gifts you receive. It does not move money and never asks for payment details.
```

**What's New in This Version**:

```
Welcome to Count 'Em Blessingz 1.0.
```

## URLs and legal (you fill these in)

| Field | What to enter |
|---|---|
| Support URL (required) | The URL of your published support page. See `docs/support.md`, published by GitHub Pages (see `release/submission-guide.md`, step 2). |
| Marketing URL (optional) | Leave empty, or your site. |
| Privacy Policy URL (required) | The URL of your published privacy policy. See `docs/privacy-policy.md`. |
| Copyright | `2026 Your Name` (use your legal name or company) |

## Age rating (Apple's questionnaire)

Answer **None** or **No** to every content question: no violence, no sexual content, no profanity, no horror, no medical or drug content, no gambling or contests, no unrestricted web access, no user-generated content shared with others, no messaging with strangers. The expected rating is **4+**.

## App Privacy ("nutrition label")

Choose **Data Not Collected**. The app has no accounts, no analytics, no advertising and no network code, and nothing leaves the device unless the person taps a share button. Answer **No** to tracking.

## Export compliance

The app uses no encryption of its own, and `ITSAppUsesNonExemptEncryption` is already set to `NO` in the app, so App Store Connect will not ask the question on each upload. If it does ask, answer: not using encryption beyond what iOS provides (exempt).

## Notes for App Review

```
No login or account is needed. All data is stored locally on the device.
Face ID lock is optional (Settings > Privacy).

To see the app with data quickly: finish onboarding (pick any country and look), then tap "+" to add a blessing, or open the attached file "sample-import.blessingz" from the Files app. It opens the app's merge review screen (a share target named Count 'Em Blessingz); tap Import to add the sample entries.

The app makes no network connections. The share buttons open the standard iOS share sheet and only share a file the person chooses to send.
```

Attach `release/sample-import.blessingz` in the **App Review Information > Attachment** field.
