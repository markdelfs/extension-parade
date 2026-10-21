#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/../Extension Parade.app"
IDENTITY="${SIGNING_IDENTITY:-067772BAC3F61F4FEE01934DFF66E8806F6AC619}"
PROFILE="${NOTARY_PROFILE:-CamDeck-notarize}"
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for part in "$FW/XPCServices/Downloader.xpc" "$FW/XPCServices/Installer.xpc" "$FW/Updater.app" "$FW/Autoupdate" "$APP/Contents/Frameworks/Sparkle.framework"; do
 codesign --force --options runtime --timestamp --sign "$IDENTITY" "$part"
done
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p .build
 ditto -c -k --keepParent "$APP" .build/notary.zip
xcrun notarytool submit .build/notary.zip --keychain-profile "$PROFILE" --wait --output-format json > ../notarization.json
python3 -c 'import json; assert json.load(open("../notarization.json"))["status"] == "Accepted"'
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" ../Extension-Parade-1.0.1.zip
mkdir -p .build/dmg
 ditto "$APP" ".build/dmg/Extension Parade.app"
ln -sfn /Applications .build/dmg/Applications
hdiutil create -fs HFS+ -srcfolder .build/dmg -volname "Extension Parade" -format UDZO -ov ../Extension-Parade-1.0.1.dmg
codesign --force --timestamp --sign "$IDENTITY" ../Extension-Parade-1.0.1.dmg
xcrun notarytool submit ../Extension-Parade-1.0.1.dmg --keychain-profile "$PROFILE" --wait --output-format json > ../dmg-notarization.json
python3 -c 'import json; assert json.load(open("../dmg-notarization.json"))["status"] == "Accepted"'
xcrun stapler staple ../Extension-Parade-1.0.1.dmg
xcrun stapler validate ../Extension-Parade-1.0.1.dmg
