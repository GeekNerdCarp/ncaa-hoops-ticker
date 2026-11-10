#!/bin/bash
# Builds a universal (Apple Silicon + Intel) "Hoops Ticker.app" into ./dist
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64

APP="dist/Hoops Ticker.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/HoopsTicker" "$APP/Contents/MacOS/HoopsTicker"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Hoops Ticker</string>
	<key>CFBundleDisplayName</key><string>Hoops Ticker</string>
	<key>CFBundleExecutable</key><string>HoopsTicker</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleIdentifier</key><string>app.hoopsticker.mac</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0.5</string>
	<key>CFBundleVersion</key><string>6</string>
	<key>LSMinimumSystemVersion</key><string>12.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Strip debug info (it embeds the builder's local file paths).
strip -S -x "$APP/Contents/MacOS/HoopsTicker"

# SIGN_ID="Developer ID Application: …" signs for notarization (hardened runtime + timestamp).
# Without it the app is ad-hoc signed, which is fine for running it on your own Mac.
if [[ -n "${SIGN_ID:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
else
    codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
lipo -archs "$APP/Contents/MacOS/HoopsTicker"
echo "Built: $APP"
