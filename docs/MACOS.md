# macOS build

The game also builds for macOS, next to the Windows installer. The Windows build, its preset ("Windows Desktop") and the Inno Setup installer are unchanged. The macOS preset is `[preset.1]` ("macOS") in `export_presets.cfg`.

**Status:** it exports and the bundle looks right (name, bundle id `com.grump606.theunforgotten`, version, icon, a universal binary for Apple Silicon and Intel). It has **not been run on a Mac yet**: test it on a real machine before telling players it works.

## Build it

From Windows, Linux or macOS with Godot 4.7.2 and its export templates (the same set the Windows build uses; `macos.zip` is part of it):

```powershell
godot --headless --path . --export-release "macOS" build/TheUnforgotten-macOS.zip
```

The zip holds `The Unforgotten.app`. `scripts/release.ps1` does this for you and publishes the zip and a `.sha256` file beside the Windows installer files on the GitHub release (`TheUnforgotten-macOS-<version>.zip`).

Version numbers: set `application/short_version` and `application/version` in the macOS preset to the same number as `config/version` in `project.godot` (no trailing `.0`, unlike the Windows keys). `release.ps1` stops if they differ.

## What the preset sets, and why

- `binary_format/architecture="universal"`: one app for Apple Silicon and Intel. It needs ETC2/ASTC textures, so `project.godot` has `textures/vram_compression/import_etc2_astc=true`. The Windows preset keeps `texture_format/etc2_astc=false`, so the Windows build does not carry them.
- `codesign/codesign=1`: Godot's built-in ad-hoc signature. Apple Silicon will not run an unsigned binary at all, so this is the minimum. It is not a developer signature.
- `notarization/notarization=0`: not notarized (that needs an Apple Developer account and a Mac, see below).
- The icon is `art/layers/ui/game_icon.png`; Godot turns it into `icon.icns`.

## Installing it (for players)

1. Download `TheUnforgotten-macOS-<version>.zip` from the releases page and unzip it.
2. Drag **The Unforgotten** to Applications.
3. The first launch is blocked by Gatekeeper ("cannot be opened because the developer cannot be verified", or "is damaged"), because the app is not notarized. Either right-click the app, choose **Open**, and confirm; or run `xattr -dr com.apple.quarantine "/Applications/The Unforgotten.app"` in Terminal once.

Saves and settings live in `~/Library/Application Support/The Unforgotten/` (Godot's `user://`, named after the project).

## Updates

The in-game updater only installs the Windows installer. On macOS the update bar shows **Download**, which opens the releases page, as it does for any install that cannot update itself. Check for updates still works the same (it only reads the release tag).

## Smoother installs: notarization (optional, needs a Mac and an account)

To remove the Gatekeeper warning, join the Apple Developer Program, sign with a Developer ID certificate and notarize the app (`codesign/*` and `notarization/*` options in the preset; Godot can drive `xcrun notarytool` on a Mac with Xcode command line tools). That is a one-time setup on a Mac and is not done here.

## Not done / to check on a Mac

- Launch, play a run and save/continue; check the window size, fonts, audio and the Escape pause key.
- Confirm the saved-run location above.
- Add a macOS package step to the release if a `.dmg` is wanted instead of a zip.
