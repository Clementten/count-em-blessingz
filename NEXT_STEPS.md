# Next steps (what only you can do)

The code is finished, tested and merged into `main`. Everything below needs you: your GitHub account, your Apple account, a real iPhone, or a decision. Work through it top to bottom and tick the boxes. Each step links to the detailed document.

Time: about 4 to 6 hours of your own time in total, spread over a few days (Apple's processing and review add waiting time).

## 1. Git and GitHub (15 minutes)

- [x] **Check the push.** `main` on GitHub should now show the merge commit "Merge feature/merge-import". If it does not, run `git push origin main` from the project folder.
- [x] **Tidy the two leftover branches on GitHub.** They come from earlier design sessions and were never merged. Neither is future work: both are finished, and `main` already has what mattered.

  | Branch | What is on it | What to do |
  |---|---|---|
  | `claude/adoring-knuth-7pyy43` | The final app icon. No pull request was ever opened for it. The PNGs are already in `main`, and the three SVG sources were copied into `main` under `design/app-icon/`. | **Delete it.** Nothing unique is left on it. |
  | `claude/exciting-brown-4nq3zg` | **Open pull request #4**, "Blueprint: merge import with preview and duplicate flags": the written spec of merge import. The feature is built and documented in section 18 of the blueprint, with one exception (see "Decisions you can make later"). Merging it now would only conflict with the blueprint, which has since changed a lot. | **Close PR #4 with a comment, then delete the branch.** Deleting the branch of an open PR closes it without a note, so close it first. To keep the original wording: `git tag archive/merge-spec origin/claude/exciting-brown-4nq3zg && git push origin archive/merge-spec`. |

  Commands (run them in the project folder):

  ```bash
  git fetch --prune
  git branch -a                              # what exists
  git branch -r --merged origin/main         # remote branches already merged (neither of the two above is)

  # the icon branch: nothing unique is left on it
  git push origin --delete claude/adoring-knuth-7pyy43

  # the spec branch: close its open pull request first, then delete the branch
  gh pr close 4 --comment "Implemented on main; see BLUEPRINT.md section 18 and NEXT_STEPS.md."
  git push origin --delete claude/exciting-brown-4nq3zg

  git fetch --prune                          # tidy your local list of remote branches

  # local branches in other clones: -d deletes only if fully merged and refuses otherwise;
  # -D forces it (you lose commits only that branch has). Use -D only if you are sure.
  git branch -d <branch-name>
  ```

  Deleting a remote branch is permanent (there is no "safe" mode). Repeat `git fetch --prune` in any other clone or worktree.

- [x] **Publish the public pages** (needed for the App Store). First put your real email in `docs/privacy-policy.md` and `docs/support.md` (search for `[your contact email]`), commit and push. Then on GitHub: **Settings > Pages > Source: Deploy from a branch > Branch `main`, folder `/docs` > Save.** After a minute open `https://<your-github-name>.github.io/<repository-name>/privacy-policy/` and `.../support/` and check they load. Write both URLs down.

## 2. Provide your details and decisions (15 minutes)

- [ ] Fill in **[release/owner-inputs.md](release/owner-inputs.md)**: bundle id, contact email, legal name, price and the other decisions. It tells you where each value is used.
- [x] Join the **Apple Developer Program** if you have not (US$99 per year, individual is simplest). You need it for TestFlight, the App Store and the widget.
- [ ] Check that the **app name** `Count 'Em Blessingz` is free in App Store Connect (names are unique). If it is taken, choose a variant of 30 characters or fewer.

## 3. Make the project yours in Xcode (30 minutes)

- [x] Run `release/set-identifiers.sh com.yourname.countemblessingz` (your bundle id). It replaces the placeholder ids everywhere and regenerates the project. Then run the tests (Command-U) to confirm.
- [x] Open `CountEmBlessingz.xcodeproj`. For **both** targets (`CountEmBlessingz` and `CountEmBlessingzWidget`): Signing & Capabilities > tick *Automatically manage signing* > choose your **Team**. Check that the App Groups capability lists `group.<your bundle id>`.
- [x] Run the app on your own iPhone.

## 4. Test on real phones (1 to 2 hours)

- [x] Work through **[release/real-device-checklist.md](release/real-device-checklist.md)**. These are the things a simulator cannot check: Face ID, notifications, the widget, AirDrop, WhatsApp and Telegram, and merging between two phones. Use a second iPhone (family is fine) for the merge test.
- [x] If anything fails, note exactly what you did and what happened, and fix or ask for a fix before submitting.

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
