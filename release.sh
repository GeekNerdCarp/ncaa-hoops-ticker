#!/bin/bash
# Builds a signed, notarized, stapled "Hoops Ticker.dmg" in ./dist.
#
# Needs:
#   SIGN_ID         your "Developer ID Application: Name (TEAMID)" certificate
#   NOTARY_PROFILE  a keychain profile made once with:
#                   xcrun notarytool store-credentials <name> --apple-id <email> --team-id <TEAMID>
set -euo pipefail
cd "$(dirname "$0")"

: "${SIGN_ID:?Set SIGN_ID to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool keychain profile}"

SIGN_ID="$SIGN_ID" ./build.sh

DMG="dist/Hoops Ticker.dmg"
STAGE="dist/dmg"
mkdir -p "$STAGE"
ditto "dist/Hoops Ticker.app" "$STAGE/Hoops Ticker.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Hoops Ticker" -srcfolder "$STAGE" -format UDZO "$DMG"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"
echo "Release ready: $DMG"
