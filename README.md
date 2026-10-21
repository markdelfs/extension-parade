# Extension Parade

A native macOS menu bar app inspired by the parade of extensions during Mac OS 9 startup. Eight supplied classic icons appear in order above the Dock, hold briefly, then fade. The overlay passes all mouse clicks through and never takes keyboard focus.

Requires macOS 13 or newer; includes Apple Silicon and Intel binaries.

## Use

Drag **Extension Parade.app** into Applications and open it. Use the stacked-squares menu bar icon to replay, stop, loop, keep the icons visible, change size (24–64 px), or choose a loading speed. Launch at Login is optional and uses Apple's ServiceManagement API. The parade also replays after wake. Hold Shift at login to use macOS's normal login-item suppression.

The overlay uses the main display. With a bottom Dock it sits above the Dock's reserved area; with automatic hiding it reserves the configured Dock icon height. With a left or right Dock, the parade sits along the bottom center. It follows display geometry while visible. This is a visual simulation; icons don't represent actual extension loading.

## Build

Install Xcode command-line tools. Obtain Sparkle 2.10.0 from the official [Sparkle project](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0). Then:

```sh
SPARKLE_FRAMEWORK=/absolute/path/to/Sparkle.framework ./scripts/build.sh
```

The app is written next to this source folder. The local build uses an ad hoc signature. To distribute with Developer ID and Apple notarization:

```sh
SIGNING_IDENTITY='Developer ID Application certificate SHA-1' NOTARY_PROFILE='saved-notarytool-profile' ./scripts/release.sh
```

The release script signs nested Sparkle components before the app, notarizes and staples both app and DMG, and creates a ZIP for Sparkle. Signing credentials and the Sparkle private key stay in the macOS Keychain.

## Updates

Sparkle 2.10.0 is embedded, with the existing account's Ed25519 public key and an HTTPS appcast configured for this repository's `updates` release. Publication is pending user approval; until then online update checks will fail because the feed is not hosted. Use **Check for Updates…** in the menu. New releases require a larger `CFBundleVersion`, a Developer ID signed and notarized app, and a signed archive using Sparkle's `sign_update` or `generate_appcast` tools. Upload the archive and replace the appcast only after successful notarization.

Icons were supplied by the user. No ownership or redistribution license for those images is asserted. Sparkle's license is included with the app under Resources.
