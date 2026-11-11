#!/bin/bash
# Builds a signed, notarized release into ./dist:
#   dist/Hoops-Ticker.dmg   for new installs (drag to Applications)
#   dist/Hoops-Ticker.zip   what Sparkle downloads when an installed copy updates itself
#   dist/appcast.xml        Sparkle's update list, signed with the maintainer's key (kept in the Keychain)
#
# Needs:
#   SIGN_ID         your "Developer ID Application: Name (TEAMID)" certificate
#   NOTARY_PROFILE  a keychain profile made once with:
#                   xcrun notarytool store-credentials <name> --apple-id <email> --team-id <TEAMID>
#   NOTES_FILE      (optional) release notes in Markdown. The "### What's new" part goes in the update dialog.
#
# Then publish all three files on one GitHub release (the appcast must be named appcast.xml):
#   gh release create vX.Y.Z dist/Hoops-Ticker.dmg dist/Hoops-Ticker.zip dist/appcast.xml --title "…" --notes-file …
set -euo pipefail
cd "$(dirname "$0")"

: "${SIGN_ID:?Set SIGN_ID to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool keychain profile}"
REPO="GeekNerdCarp/ncaa-hoops-ticker"

SIGN_ID="$SIGN_ID" ./build.sh

APP="dist/Hoops Ticker.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"

# 1. Notarize the app itself and staple the ticket to it, so the copy Sparkle installs passes Gatekeeper offline.
ditto -c -k --keepParent "$APP" dist/notarize-app.zip
xcrun notarytool submit dist/notarize-app.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute -v "$APP"
rm dist/notarize-app.zip

# 2. The archive Sparkle downloads (the stapled app).
ZIP="dist/Hoops-Ticker.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

# 3. The DMG for new installs.
DMG="dist/Hoops Ticker.dmg"
STAGE="dist/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Hoops Ticker.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Hoops Ticker" -srcfolder "$STAGE" -format UDZO "$DMG"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"
cp "$DMG" dist/Hoops-Ticker.dmg

# 4. The appcast. It lists just this version, with a download link on this release, and is signed
#    with the private key in the Keychain (macOS may ask once to allow access).
FEED="dist/feed"
rm -rf "$FEED"; mkdir -p "$FEED"
cp "$ZIP" "$FEED/Hoops-Ticker.zip"
if [[ -n "${NOTES_FILE:-}" ]]; then
    sed '/^### Install/,$d' "$NOTES_FILE" > "$FEED/Hoops-Ticker.md"   # just "What's new"
fi
.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    --embed-release-notes "$FEED"
cp "$FEED/appcast.xml" dist/appcast.xml

echo
echo "Release $VERSION ready in dist/:"
ls -1 dist/Hoops-Ticker.dmg dist/Hoops-Ticker.zip dist/appcast.xml
