#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="Roblox Overlay.app"
VERSION="${GITHUB_REF_NAME:-v1.4.2}"
VERSION="${VERSION#v}"
ARM_BIN="/tmp/RobloxOverlay-arm64-$$"
X64_BIN="/tmp/RobloxOverlay-x86_64-$$"
BIN="/tmp/RobloxOverlay-universal-$$"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key><string>Roblox Overlay</string>
  <key>CFBundleExecutable</key><string>RobloxOverlay</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>local.codex.roblox-overlay</string>
  <key>CFBundleName</key><string>Roblox Overlay</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
for ARCH in arm64 x86_64; do
  swiftc -target "${ARCH}-apple-macos15.0" -parse-as-library \
    -framework SwiftUI -framework AppKit -framework CoreGraphics -framework Translation \
    Sources/RobloxOverlay/main.swift -o "/tmp/RobloxOverlay-${ARCH}-$$"
done
lipo -create "$ARM_BIN" "$X64_BIN" -output "$BIN"
install -m 755 "$BIN" "$APP/Contents/MacOS/RobloxOverlay"
rm -f "$ARM_BIN" "$X64_BIN" "$BIN"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=2 "$APP"
rm -f RobloxOverlay-macOS-universal.zip
ditto -c -k --sequesterRsrc --keepParent "$APP" RobloxOverlay-macOS-universal.zip
printf 'Universal Mac archive: %s/RobloxOverlay-macOS-universal.zip\n' "$PWD"
