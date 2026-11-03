# Windows installer

Build: `powershell -ExecutionPolicy Bypass -File scripts/build_installer.ps1`
Output: `build/TheUnforgotten-Setup-<version>.exe` and `build/TheUnforgotten-Setup-<version>.exe.sha256` (the `build/` folder is git-ignored).

## One-time setup on a build machine

- Godot 4.7.2 export templates, installed under `%APPDATA%\Godot\export_templates\4.7.2.stable\` (Editor > Manage Export Templates, or extract the official `.tpz`).
- Inno Setup 6: `winget install JRSoftware.InnoSetup`.

## Releasing a new version

1. Bump `config/version` in `project.godot` (dotted numbers, e.g. `0.2.0`). Also set `application/file_version` and `application/product_version` in `export_presets.cfg` to the same number with a trailing `.0` (e.g. `0.2.0.0`); they are what the exe's Properties dialog shows.
2. Run the build script.
3. Publish the installer and its checksum file together as a GitHub release tagged `v<version>` (for example `gh release create v0.2.0 build/TheUnforgotten-Setup-0.2.0.exe build/TheUnforgotten-Setup-0.2.0.exe.sha256`).

When a signing key is configured the build also writes `.manifest` and `.manifest.sig` next to the installer; publish all four files. It is what lets the game install the update itself. See `docs/UPDATE_SIGNING.md` for the one-time key setup and the per-release steps.

## Verifying a download

The `.sha256` file holds one line in the standard `<hash>  <filename>` format, written by the build script after the installer is compiled. Download both files into the same folder, then check:

```powershell
(Get-FileHash -Algorithm SHA256 .\TheUnforgotten-Setup-<version>.exe).Hash.ToLower() -eq ((Get-Content .\TheUnforgotten-Setup-<version>.exe.sha256) -split '\s+')[0]
```

or `sha256sum -c TheUnforgotten-Setup-<version>.exe.sha256` where available. A checksum published next to the file only detects a corrupted download; it does not prove who built it (the exe is unsigned, see Limits).

## What the installer does

- Per-user install by default (no admin prompt), Start Menu entry, optional desktop shortcut, uninstaller.
- Same app id on every build, so running a newer setup upgrades in place; saves live in Godot's user data folder and are untouched.
- Running an older setup over a newer install is refused with a message.
- On launch it asks the GitHub API for the latest release. If that is newer than the setup being run, it offers to open the download page. Skipped silently when offline, in silent mode, or when the repository is private (GitHub answers 404 without credentials). A token is deliberately not embedded in the installer. The reply is validated the way the game does it (`run/update_check.gd`): the response must be at most 65536 characters and the tag must be an optional `v`, then 1-4 dot-separated groups of 1-4 digits, at most 24 characters, nothing else. Anything else counts as no update info and setup proceeds silently.

## Limits

- The exe is unsigned, so Windows SmartScreen may warn on first run.
- The exe has the default Godot icon (needs rcedit and an `.ico` to change).
- The game's own `exclude_filter` leaves out tests, tools, scripts and docs; the export is the full game in one embedded-pck exe (about 110 MB, 28 MB compressed).
