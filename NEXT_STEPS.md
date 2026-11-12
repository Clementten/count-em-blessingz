# Next steps (what only you can do)

The code is finished, tested and merged into `main`. Everything below needs you: your GitHub account, your Apple account, a real iPhone, or a decision. Work through it top to bottom and tick the boxes. Each step links to the detailed document.

Time: about 4 to 6 hours of your own time in total, spread over a few days (Apple's processing and review add waiting time).

## 1. Git and GitHub (15 minutes)

- [ ] **Check the push.** `main` on GitHub should now show the merge commit "Merge feature/merge-import". If it does not, run `git push origin main` from the project folder.
- [ ] **Delete the leftover branches you no longer need.** Two branches from earlier design sessions are still on GitHub. They are not merged, so Git will not delete them for you without an explicit command. Decide for each:

  | Branch | What is on it | Safe to delete? |
  |---|---|---|
  | `claude/adoring-knuth-7pyy43` | The final app icon. The PNGs are already in `main`, and the three SVG sources were copied into `main` under `design/app-icon/`. | **Yes.** Nothing unique is left on it. |
  | `claude/exciting-brown-4nq3zg` | An earlier written spec of the merge-import feature (97 lines added to `BLUEPRINT.md`). The feature is built, and section 18 of the blueprint documents it. | **Yes, if you do not need the original wording.** To keep a copy first: `git tag archive/merge-spec origin/claude/exciting-brown-4nq3zg && git push origin archive/merge-spec`. |

  Commands (run them in the project folder):

  ```bash
  # see which branches exist and which are already merged into main
  git fetch --prune
  git branch -a
  git branch -r --merged origin/main        # branches fully merged (none of the two above are)

  # delete the two remote branches (this is permanent on GitHub; there is no "safe" mode for remote branches)
  git push origin --delete claude/adoring-knuth-7pyy43
  git push origin --delete claude/exciting-brown-4nq3zg

  # tidy your local copy of the remote branch list
  git fetch --prune

  # local branches: -d only deletes a branch that is fully merged, and refuses otherwise
  git branch -d <branch-name>
  # -D force-deletes even if unmerged (you lose any commits only that branch has). Use only if you are sure.
  ```

  If you work from other clones or worktrees, repeat `git fetch --prune` there and delete any local copies with `git branch -d <name>`.
- [ ] **Publish the public pages** (needed for the App Store). First put your real email in `docs/privacy-policy.md` and `docs/support.md` (search for `[your contact email]`), commit and push. Then on GitHub: **Settings > Pages > Source: Deploy from a branch > Branch `main`, folder `/docs` > Save.** After a minute open `https://<your-github-name>.github.io/<repository-name>/privacy-policy/` and `.../support/` and check they load. Write both URLs down.

## 2. Provide your details and decisions (15 minutes)

- [ ] Fill in **[release/owner-inputs.md](release/owner-inputs.md)**: bundle id, contact email, legal name, price and the other decisions. It tells you where each value is used.
- [ ] Join the **Apple Developer Program** if you have not (US$99 per year, individual is simplest). You need it for TestFlight, the App Store and the widget.
- [ ] Check that the **app name** `Count 'Em Blessingz` is free in App Store Connect (names are unique). If it is taken, choose a variant of 30 characters or fewer.

## 3. Make the project yours in Xcode (30 minutes)

- [ ] Run `release/set-identifiers.sh com.yourname.countemblessingz` (your bundle id). It replaces the placeholder ids everywhere and regenerates the project. Then run the tests (Command-U) to confirm.
- [ ] Open `CountEmBlessingz.xcodeproj`. For **both** targets (`CountEmBlessingz` and `CountEmBlessingzWidget`): Signing & Capabilities > tick *Automatically manage signing* > choose your **Team**. Check that the App Groups capability lists `group.<your bundle id>`.
- [ ] Run the app on your own iPhone.

## 4. Test on real phones (1 to 2 hours)

- [ ] Work through **[release/real-device-checklist.md](release/real-device-checklist.md)**. These are the things a simulator cannot check: Face ID, notifications, the widget, AirDrop, WhatsApp and Telegram, and merging between two phones. Use a second iPhone (family is fine) for the merge test.
- [ ] If anything fails, note exactly what you did and what happened, and fix or ask for a fix before submitting.

## 5. App Store Connect (1 to 2 hours)

Follow **[release/submission-guide.md](release/submission-guide.md)** step by step. The material you need is ready:

| What | Where |
|---|---|
| Text to paste (name, subtitle, description, keywords, review notes) | [release/listing.md](release/listing.md) |
| 18 screenshots, 1320 x 2868 (and which to upload) | [release/screenshots/](release/screenshots/) and [release/screenshots.md](release/screenshots.md) |
| File to attach for App Review | [release/sample-import.blessingz](release/sample-import.blessingz) |
| Privacy answer | **Data Not Collected**, no tracking |
| Age rating | answer No to everything: 4+ |
| Export compliance | already declared in the app (no encryption of its own) |

- [ ] Create the app record, upload a build (Product > Archive > Distribute > App Store Connect), and fill in the page.
- [ ] Test the uploaded build through **TestFlight** on a real iPhone before submitting.
- [ ] **Add for Review > Submit.** Review usually takes a day or two. If it is rejected, read the message in Resolution Center, fix, and resubmit (the guide lists the usual questions and answers).
- [ ] After approval, press **Release This Version** when you are ready (the guide suggests manual release).

## 6. Decisions you can make later

- Should **Undo last import** be smarter, reverting only what an import changed instead of restoring a whole snapshot? Today it restores the snapshot, so anything you add after importing is lost (the confirmation warns you).
- iCloud backup as an opt-in in a future version (left out of version 1 on purpose).
- More languages (version 1 is English only).
- Whether tapping the tab you are already on should return to its first screen (today it does nothing).

## If something goes wrong

| Problem | Look here |
|---|---|
| The project will not build after changing the bundle id | Run `xcodegen generate`, then check the signing team on both targets. |
| Xcode says the App Group is not available | A paid team is required. Open the target's Signing & Capabilities and press Try Again. |
| A screen looks wrong on your phone | Note the phone model, iOS version and text size (Settings > Accessibility > Display & Text Size). |
| You want to know how something works | [README.md](README.md) (overview) and [BLUEPRINT.md](BLUEPRINT.md) (design, status, how merge import works in section 18). |
