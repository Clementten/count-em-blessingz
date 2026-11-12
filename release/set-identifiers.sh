#!/bin/bash
# Replaces the placeholder identifiers (com.example.countemblessingz) with your own, everywhere they appear,
# then regenerates the Xcode project.
#
#   release/set-identifiers.sh com.yourname.countemblessingz
#
# This changes: the app, widget and test bundle ids, the App Group (group.<your id>), the file type id
# (<your id>.exchange) and the matching constants in the Swift code and tests.
# It needs XcodeGen (brew install xcodegen). Run it once, before your first archive.
set -euo pipefail

NEW="${1:-}"
OLD="com.example.countemblessingz"

if [[ -z "$NEW" ]]; then
  echo "usage: release/set-identifiers.sh com.yourname.countemblessingz" >&2
  exit 1
fi
if [[ ! "$NEW" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || [[ "$NEW" != *.* ]]; then
  echo "'$NEW' is not a valid reverse-DNS identifier (letters, digits, dots and hyphens, with at least one dot)." >&2
  exit 1
fi
if [[ "$NEW" == "$OLD" ]]; then
  echo "Nothing to do: that is already the identifier in use." >&2
  exit 0
fi
command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen" >&2; exit 1; }

cd "$(dirname "$0")/.."

# Only source files that carry the identifier; generated files (Info.plist, entitlements, .xcodeproj) are rebuilt below.
FILES=$(grep -rl --include='*.swift' --include='project.yml' "$OLD" CountEmBlessingz CountEmBlessingzTests CountEmBlessingzUITests CountEmBlessingzWidget project.yml 2>/dev/null || true)
if [[ -z "$FILES" ]]; then
  echo "No files contain $OLD. Has this already been changed?" >&2
  exit 1
fi

for f in $FILES; do
  perl -pi -e "s/\Q$OLD\E/$NEW/g" "$f"
  echo "updated $f"
done

xcodegen generate

echo
echo "Done. Identifiers now use: $NEW"
echo "  app:        $NEW"
echo "  widget:     $NEW.widget"
echo "  App Group:  group.$NEW"
echo "  file type:  $NEW.exchange"
echo "Next: open CountEmBlessingz.xcodeproj, select your team under Signing & Capabilities for BOTH the app and the widget."
