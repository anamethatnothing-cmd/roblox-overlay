# Roblox Overlay for macOS

The official macOS app combines a customizable center reticle with display-wide shadow lift. It does not modify Roblox or automate game input. The universal release supports both Apple Silicon and Intel Macs (macOS 15 or later).

## Use

Open `Roblox Overlay.app`. The app opens directly to reticle settings. Use the sidebar for:

- **Reticle:** shape, size, spacing, rotation, center dot, line weight, outline, glow, opacity, and a live preview that uses the same drawing code as the screen overlay.
- **Color & effects:** custom reticle color, recent and favorite swatches, and an independent custom screen tint with intensity control.
- **Display correction:** shadow lift, exposure, gamma, contrast, and tint. The original display gamma table is restored when correction stops or the app quits normally.

Display correction affects everything on that display, including other apps. Reticle and correction settings are saved between launches.

## Platform support

- **macOS:** The Swift app supports macOS 15 or later. It provides system translation and display gamma correction.
This GitHub release is macOS-only and contains a universal app for Apple Silicon and Intel Macs.

## Build a macOS release archive

Requirements: macOS 15 or later and Xcode Command Line Tools. In-app translation uses Apple Translation with searchable Korean-to-target languages supported by this Mac. A language model download may be required. The release script builds both `arm64` and `x86_64` and combines them into one universal app. The icon source is included under `Assets/`.

```sh
./build-release.sh
```

This builds and verifies the universal Mac app and creates `RobloxOverlay-macOS-universal.zip`. The archive is ad-hoc signed for local testing. Public distribution should be signed with the publisher’s Apple Developer ID and notarized before release.
