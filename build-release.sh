#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="Roblox Overlay.app"
ARM_BIN="/tmp/RobloxOverlay-arm64-$$"
X64_BIN="/tmp/RobloxOverlay-x86_64-$$"
BIN="/tmp/RobloxOverlay-universal-$$"
for ARCH in arm64 x86_64; do
  swiftc -target "${ARCH}-apple-macos15.0" -parse-as-library \
    -framework SwiftUI -framework AppKit -framework CoreGraphics -framework Translation \
    Sources/RobloxOverlay/main.swift -o "/tmp/RobloxOverlay-${ARCH}-$$"
done
lipo -create "$ARM_BIN" "$X64_BIN" -output "$BIN"
install -m 755 "$BIN" "$APP/Contents/MacOS/RobloxOverlay"
rm -f "$ARM_BIN" "$X64_BIN" "$BIN"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Roblox Overlay' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Roblox Overlay' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.codex.roblox-overlay' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.4.0' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 15.0' "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=2 "$APP"
rm -f RobloxOverlay-macOS-universal.zip
ditto -c -k --sequesterRsrc --keepParent "$APP" RobloxOverlay-macOS-universal.zip
printf 'Universal Mac archive: %s/RobloxOverlay-macOS-universal.zip\n' "$PWD"
