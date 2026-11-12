# From this repository to the App Store

Follow the steps in order. Fields are named as in App Store Connect and Xcode at the time of writing; Apple renames things now and then, so if a label differs slightly, look for the nearest match. Text to paste is in [listing.md](listing.md).

Time: about 1 to 2 hours of your own time, plus Apple's processing (a build is usually ready within 15 to 30 minutes, and review often takes a day or two).

## 0. What you need

- A Mac with Xcode 17 or later (this project was built with Xcode 27) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- The paid Apple Developer Program membership (see [owner-inputs.md](owner-inputs.md)).
- One or two real iPhones running iOS 17 or later.

## 1. Fill in the owner inputs

Complete [owner-inputs.md](owner-inputs.md). You need the bundle identifier, contact email and legal name before the next steps.

## 2. Make the identifiers yours

In Terminal, from the project folder:

```bash
release/set-identifiers.sh com.yourname.countemblessingz
```

This changes the app, widget and test bundle ids, the App Group (`group.<your id>`), the file type id and the matching code constants, then regenerates the Xcode project. It was tested on a copy of this project (the result builds and the tests pass).

Then run the tests once to confirm: open the project, choose the scheme **CountEmBlessingz** and press Command-U.

## 3. Publish the privacy policy and support pages

App Store Connect requires a privacy policy URL and a support URL. The pages are already written in the `docs` folder.

1. Open `docs/privacy-policy.md` and `docs/support.md` and replace `[your contact email]` with your real address (it appears once in each).
2. Commit and push to GitHub.
3. On GitHub: **Settings > Pages > Build and deployment > Source: Deploy from a branch**, choose branch **main** and folder **/docs**, then Save.
4. After a minute your pages are live. With your GitHub user name and this repository name the addresses look like:
   - Privacy policy: `https://<your-github-name>.github.io/<repository-name>/privacy-policy/`
   - Support: `https://<your-github-name>.github.io/<repository-name>/support/`
5. Open both in a browser to confirm they load, and write the two URLs into [owner-inputs.md](owner-inputs.md).

If you would rather use your own website, publish the same text there instead.

## 4. Prepare the app in Xcode

1. Open `CountEmBlessingz.xcodeproj`.
2. Select the project, then the target **CountEmBlessingz** > **Signing & Capabilities**. Tick **Automatically manage signing** and choose your **Team**. Do the same for the target **CountEmBlessingzWidget**.
3. Check that **App Groups** lists `group.<your bundle id>` for both targets (Xcode adds it from the entitlements). If a red message appears, click **Try Again** or **Register**.
4. **General** tab: Version `1.0`, Build `2` (build `1` was already uploaded; each upload needs a higher build number than the last).
5. Run on a real iPhone (Product > Destination > your iPhone, then Run) and go through [real-device-checklist.md](real-device-checklist.md).

## 5. Create the app in App Store Connect

1. Go to App Store Connect > **Apps** > **+** > **New App**.
2. Platform **iOS**. Name: `Count 'Em Blessingz` (or your variant). Primary language **English (U.S.)**. Bundle ID: choose yours from the list (it appears after Xcode has registered it; archive once first if it does not). SKU: your SKU. User access: Full Access.
3. Under **App Information**: Subtitle, Category and Content Rights as in [listing.md](listing.md).
4. Under **Pricing and Availability**: your price and countries.

## 6. Upload the build

1. In Xcode choose the destination **Any iOS Device (arm64)**.
2. **Product > Archive**. When the Organizer opens, select the archive, click **Distribute App**, choose **App Store Connect**, then **Upload**, and keep the defaults (automatic signing).
3. In App Store Connect, open your app > **TestFlight**. After processing (usually 15 to 30 minutes) the build appears. Export compliance should not be asked, because the app declares no custom encryption.

## 7. Fill in the App Store page

Open the app > the **1.0 Prepare for Submission** page.

| Section | What to do |
|---|---|
| Screenshots | Upload the captioned screenshots, Jade & Gold set first: **1206 x 2622** files from [screenshots-captioned-1206x2622/](screenshots-captioned-1206x2622/) into the 6.1-inch tab (required), and optionally the 1320 x 2868 files from [screenshots-captioned/](screenshots-captioned/) into the 6.9-inch tab. A file dropped on the wrong size tab fails with "File dimensions are invalid" (see [screenshots.md](screenshots.md)). The plain versions are in [screenshots/](screenshots/). |
| Promotional text, Description, Keywords, What's New | Paste from [listing.md](listing.md). |
| Support URL, Marketing URL | From owner-inputs. |
| Copyright | `2026 <your name>` |
| Build | Click **+** and choose the processed build. |
| App Review Information | Contact details (yours). Notes: paste the review notes from [listing.md](listing.md). Attachment: [sample-import.blessingz](sample-import.blessingz). Sign-in required: **off**. |
| Age Rating | Answer the questionnaire as described in [listing.md](listing.md) (all No or None, so 4+). |
| App Privacy | **Data Not Collected**; tracking **No**. Add your privacy policy URL. |
| Version Release | Manual (recommended) |

## 8. TestFlight (strongly recommended)

1. App Store Connect > your app > **TestFlight** > **Internal Testing** > **+** and add yourself and family (they accept an email invitation and install the TestFlight app).
2. Install the build on a real iPhone and run the checklist in [real-device-checklist.md](real-device-checklist.md). Pay special attention to Face ID, notifications, the widget and the two-phone merge.
3. If you find a problem, fix it, raise the build number, archive and upload again.

## 9. Submit for review

1. On the **1.0 Prepare for Submission** page, check that nothing is flagged, then **Add for Review** > **Submit to App Review**.
2. Review usually takes a day or two. You get an email when the status changes. If it is rejected, open **Resolution Center**, read the message, fix or reply, and resubmit.

## 10. After approval

- With manual release, press **Release This Version** when you are ready.
- Keep a copy of your signing assets and the source (this repository).
- For updates: raise the build number (and the version for visible changes), archive, upload, and submit as above.

## Common questions from App Review, and the answers

| Question | Answer |
|---|---|
| "Does the app need an account?" | No. All data is local (this is also in the review notes). |
| "Why does the app ask for notification permission?" | For optional local thank-you reminders. It asks only when you first save a blessing or turn reminders on, never at launch. |
| "Why Face ID?" | Optional app lock. The usage description reads "Count 'Em Blessingz uses Face ID to keep your blessings private. You can also unlock with your passcode." |
| "How can we test sharing and import?" | Open the attached `sample-import.blessingz` from the Files app, or use the share button and share a file to yourself. |
| "Where is your privacy policy?" | The privacy policy URL on the app page. |
