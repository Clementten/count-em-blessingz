# Real-device test checklist

The simulator cannot check these, so they need a real iPhone (two for the merge test). Tick each box. Expected results are in italics. If something is wrong, note what you did and what happened.

**Setup:** install from Xcode (Run on your iPhone) or from TestFlight. Have a second iPhone for section 7. iOS 17 or later.

## 1. First run
- [ ] Launch the app fresh. *The country step appears with your region preselected.*
- [ ] Pick a country, then a look, then Start counting. *Home opens with an empty honeypot and the message to tap +.*
- [ ] Go back from the look step with the Back button. *You return to the country step.*

## 2. Everyday use
- [ ] Add a blessing (name, amount, occasion). *It appears at the top; the total and the toast update; a light haptic is felt.*
- [ ] Add a second blessing for the same name in different capitals. *No duplicate person is created.*
- [ ] Edit an amount of 1,000 or more and save without changing it. *The amount is unchanged (this was a bug that is now fixed).*
- [ ] Swipe to delete and tap Undo within 5 seconds. *The blessing returns.*
- [ ] Add a blessing with a photo from your library. *The photo shows when you edit it.*
- [ ] Type in the search field. *The keyboard opens and the tab bar and + button step aside. Dismiss the keyboard and they return.*
- [ ] Open a person (tap a row), then switch tabs and come back. *You are still on that person.*

## 3. Milestones
- [ ] Add blessings until the total crosses 1,000. *A milestone effect plays once (coin rain, chapter card or count-up depending on the look), with a success haptic.*
- [ ] Turn on Reduce Motion in iOS Settings and repeat. *No animation, only the toast.*

## 4. Face ID and privacy
- [ ] Settings > Face ID lock: turn on. *A Face ID prompt appears first; the switch stays off if you cancel.*
- [ ] Press the side button, wait, and wake. *The lock screen of the app appears and Face ID unlocks it.*
- [ ] Open the app switcher. *The app's preview is blank (privacy cover), not your data.*
- [ ] Turn on Hide amounts. *Amounts are masked everywhere, including the toast after saving and the import screen.*

## 5. Reminders
- [ ] Settings > Reminder delay: choose 1 day. *iOS asks for notification permission the first time.*
- [ ] Add a blessing and set your clock/test as needed, or wait. *One reminder "Say thanks to {name}." arrives after the delay.*
- [ ] Mark that person thanked before the delay. *No reminder arrives.*
- [ ] In iOS Settings > Notifications > Count 'Em Blessingz > Show Previews, choose "When Unlocked". *A locked-screen reminder shows "Someone is waiting for a thank-you." instead of the name.*

## 6. Widget
- [ ] Add the Honeypot widget to the Home Screen. *It shows the total and goal progress in your chosen look.*
- [ ] Add a blessing in the app and return to the Home Screen. *The widget total updates within a few seconds.*
- [ ] Turn Face ID lock on. *The widget shows dots instead of the total.*

## 7. Sharing and merging (needs two iPhones, A and B)
- [ ] On A, record three blessings. Tap the share button on Home. *The share sheet shows the file "CountEmBlessingz-entries-...blessingz" and your apps (AirDrop, Messages, Mail, WhatsApp, Telegram if installed).*
- [ ] Send it to B by **AirDrop**. *On B, tapping the file offers Count 'Em Blessingz and opens the review screen.*
- [ ] On B, tap Import. *The three entries appear; the toast offers Undo.*
- [ ] Send a file by **WhatsApp**, then by **Telegram**, then by **Mail**. *In each app the file arrives; tapping it offers Open in / Share to Count 'Em Blessingz (WhatsApp and Telegram may need Share > Count 'Em Blessingz, or Save to Files then open it).*
- [ ] On B, edit one imported entry's amount and add a new entry; on A, edit a different entry and add another. Then A: Settings > Data > Share changes since last export. *The sheet lists only the changed entries.*
- [ ] After sending, open Settings again on A. *"No changes since last export" shows, because the file was really shared. Cancelling the share sheet instead leaves the changes pending.*
- [ ] Import on B, then share all from B and import on A. *Both phones end with the same entries, no duplicates, nothing missing.*
- [ ] On B, import a file whose person has a similar name ("Aunty Mei" vs "Aunt Mei"). *The screen says "Looks like Aunt Mei" and defaults to Keep separate.*
- [ ] Import again the same file. *Everything shows "Already in your pot" and nothing is added.*
- [ ] Settings > Data > Undo last import. *The pot returns to how it was before that import.*

## 8. Backup, restore and erase
- [ ] Settings > Data > Back up to file, save to Files. Erase all data (it asks twice). Restore from backup. *Counts and totals match what you had, with your settings.*
- [ ] Export CSV and open it in Numbers or Excel. *One row per blessing; amounts are plain numbers.*

## 9. Currency
- [ ] Change the country to one with another currency, enter a rate. *Every amount and the goal convert; the toast shows the rate; an entry shows "Originally ..." details.*
- [ ] Choose "Keep the numbers, change the label only". *Numbers stay, label changes.*

## 10. Screens and sizes
- [ ] On the smallest iPhone you have (SE or mini) and the largest (Pro Max): visit Home, Insights, Hall of Fame, Settings, the Add sheet and an import review. *Nothing is cut off or overlapping.*
- [ ] iOS Settings > Accessibility > Display & Text Size > Larger Text, drag to the maximum. *Text wraps, buttons stay reachable, nothing is clipped; the tab bar stays readable.*
- [ ] Turn on VoiceOver and move through Home. *Controls are announced with meaningful names; rows read name, occasion, date and amount; the share button says "Share all my entries"; only the current tab is read.*
- [ ] Switch to each of the three looks. *Text is readable in all of them.*

## 11. Offline and reinstall
- [ ] Turn on Airplane Mode and use every feature above. *Everything works (the app makes no network connections).*
- [ ] Delete the app and install it again. *The first-run onboarding appears.*

## Result

Date: ____________  Device(s) and iOS version: ______________________________

Problems found: ________________________________________________________________
