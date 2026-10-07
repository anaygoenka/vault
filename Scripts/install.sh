#!/bin/zsh
# Builds Vault, runs the tests, and installs it to /Applications.
#
# Usage:
#   Scripts/install.sh            # Vault Direct: pastes for you (default)
#   Scripts/install.sh appstore   # Vault: the sandboxed App Store edition
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-direct}" == "appstore" ]]; then
  SCHEME="Vault"; NAME="Vault"; OTHER="Vault Direct"
else
  SCHEME="Vault Direct"; NAME="Vault Direct"; OTHER="Vault"
fi
APP="/Applications/$NAME.app"
BUILT="build/DD/Build/Products/Release/$NAME.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

xcodegen generate --quiet
xcodebuild -project Vault.xcodeproj -scheme Vault -derivedDataPath build/DD -destination 'platform=macOS,arch=arm64' test -quiet
xcodebuild -project Vault.xcodeproj -scheme "$SCHEME" -configuration Release -derivedDataPath build/DD clean build -quiet
codesign --verify --strict "$BUILT"

# Both editions want ⇧⌘V, so only one runs at a time.
pkill -x "Vault" || true
pkill -x "Vault Direct" || true
sleep 0.5
rm -rf "$APP"
ditto "$BUILT" "$APP"

# Only installed copies should be known to Spotlight, login items and the
# Accessibility list.
for stale in build/DD/Build/Products/*/*.app; do
  "$LSREGISTER" -u "$stale" 2>/dev/null || true
done
"$LSREGISTER" -f "$APP"

open "$APP"
echo "$NAME $(defaults read "$APP/Contents/Info" CFBundleShortVersionString) installed and running."
[[ -d "/Applications/$OTHER.app" ]] && echo "Note: /Applications/$OTHER.app is also installed; quit it if both are open."
exit 0
