# Release preparation

Everything needed to publish the app, ready to use. The code is finished; this folder is for the steps only you can do (they need your Apple account, your identity and your decisions).

Start here:

1. **[owner-inputs.md](owner-inputs.md)** is a fill-in sheet of everything you must provide. About 15 minutes.
2. **[submission-guide.md](submission-guide.md)** is the step-by-step route from this repository to the App Store, with exact values to paste.
3. **[listing.md](listing.md)** has the App Store text (name, subtitle, description, keywords, review notes, age rating, privacy answers), already within Apple's limits.
4. **[screenshots.md](screenshots.md)** and **[screenshots/](screenshots/)** have 18 ready screenshots (1320 x 2868, the iPhone 6.9 inch size) and how to upload and regenerate them.
5. **[real-device-checklist.md](real-device-checklist.md)** is the test plan for a real iPhone: the things a simulator cannot check (Face ID, notifications, widget, AirDrop, WhatsApp and Telegram, two-phone merge).

Also here:

- **[set-identifiers.sh](set-identifiers.sh)** replaces the placeholder bundle id, App Group and file type id with yours in one command.
- **[sample-import.blessingz](sample-import.blessingz)** is a small sample file to attach for App Review, and handy for trying the merge screen.
- The public pages (privacy policy, support) live in **[../docs](../docs)**, because GitHub Pages publishes that folder.

What was already done for you: the app icon, `ITSAppUsesNonExemptEncryption` (no export-compliance question), version 1.0 (build 1), the privacy and support page text, the listing copy, the screenshots, the reviewer sample file and the identifier script.
