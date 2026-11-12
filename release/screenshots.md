# Screenshots

18 ready screenshots are in [screenshots/](screenshots/): six screens in each of the three looks (jade, grand and quiet). Each is **1320 x 2868**, the size of the iPhone 6.9 inch display, taken from the real app with sample data (no real personal information) and a clean status bar (9:41, full signal, full battery).

| File | Screen |
|---|---|
| `01-home.png` | Home: honeypot total, search and the blessing list |
| `02-insights.png` | Insights: donut chart by person |
| `03-hall-of-fame.png` | Hall of Fame: podium, milestones, thank-you queue |
| `04-add-blessing.png` | Adding a blessing |
| `05-vibes.png` | Settings with the three looks |
| `06-import-review.png` | Merging a family member's file: new, updated and possible duplicates |

## What to upload

App Store Connect currently asks for **6.9 inch** screenshots (1320 x 2868). Apple scales them for smaller phones. You can add up to 10 per language.

- **Recommended first set, Jade & Gold** (the app's default look, 6 shots): `jade/01-home`, `jade/02-insights`, `jade/06-import-review`, `jade/03-hall-of-fame`, `jade/04-add-blessing`, `jade/05-vibes`. Lead with Home and Insights; the merge screen sets the app apart.
- **If you want to show all three looks**, replace the last slot with `grand/01-home` and `quiet/01-home` (use up to 10 in total).
- If App Store Connect also asks for the 6.5 inch size (1284 x 2778), resize these (for example in Preview, Tools > Adjust Size, with proportions kept) or ask me to export that size.

Upload order = display order: drag to rearrange after uploading.

## Optional: add headlines

Plain screenshots are accepted. If you want caption text on top, suggested headlines are:

1. "Every blessing in one private place"
2. "See who has blessed you most"
3. "Your most generous givers"
4. "Add a blessing in seconds"
5. "Three looks, your choice"
6. "Merge family lists, no cloud"

## Regenerating

If the design changes, regenerate them from the real app (needs Xcode and a simulator named iPhone 17 Pro Max, which is exactly 1320 x 2868):

```bash
# 1. a clean status bar for the shots
xcrun simctl status_bar booted override --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 --operatorName ""

# 2. run the screenshot test (it is skipped unless this variable is set)
TEST_RUNNER_SCREENSHOT_DIR=/tmp/appstore xcodebuild test -scheme CountEmBlessingzUI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:CountEmBlessingzUITests/AppStoreScreenshotUITests

# 3. restore the normal status bar, then copy the pictures from /tmp/appstore into release/screenshots
xcrun simctl status_bar booted clear
```

The test lives in `CountEmBlessingzUITests/AppStoreScreenshotUITests.swift`. It uses the debug launch flags `-seedDemo -demoFresh` (sample data with recent dates).
