#!/bin/zsh
# Builds Vault in Release, runs the tests, and installs it to /Applications.
# Usage: Scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP=/Applications/Vault.app
BUILT=build/DD/Build/Products/Release/Vault.app
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

xcodegen generate --quiet
xcodebuild -project Vault.xcodeproj -scheme Vault -derivedDataPath build/DD -destination 'platform=macOS,arch=arm64' test -quiet
xcodebuild -project Vault.xcodeproj -scheme Vault -configuration Release -derivedDataPath build/DD clean build -quiet
codesign --verify --strict "$BUILT"

pkill -x Vault || true
sleep 0.5
rm -rf "$APP"
ditto "$BUILT" "$APP"

# Only the installed copy should be known to Spotlight, login items and
# the Accessibility list.
for stale in build/DD/Build/Products/*/Vault.app; do
  "$LSREGISTER" -u "$stale" 2>/dev/null || true
done
"$LSREGISTER" -f "$APP"

open "$APP"
echo "Vault $(defaults read "$APP/Contents/Info" CFBundleShortVersionString) installed and running."
