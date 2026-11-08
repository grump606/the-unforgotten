# Windows installer

Build: `powershell -ExecutionPolicy Bypass -File scripts/build_installer.ps1`
Output: `build/TheUnforgotten-Setup-<version>.exe` and `build/TheUnforgotten-Setup-<version>.exe.sha256` (the `build/` folder is git-ignored).

## One-time setup on a build machine

- Godot 4.7.2 export templates, installed under `%APPDATA%\Godot\export_templates\4.7.2.stable\` (Editor > Manage Export Templates, or extract the official `.tpz`).
- Inno Setup, pinned: `winget install JRSoftware.InnoSetup --version 6.7.3`. The pinned version is `INNO_SETUP_VERSION` in `scripts/engine_version.txt` (the build script's error message quotes it); to move to a newer Inno Setup, install it, build once, then change that line and this one.
- The engine version is `GODOT_VERSION` in `scripts/engine_version.txt` (see `docs/CI.md`); the template folder name above follows it.

## Releasing a new version

1. Bump `config/version` in `project.godot` (dotted numbers, e.g. `0.2.0`). Also set `application/file_version` and `application/product_version` in `export_presets.cfg` to the same number with a trailing `.0` (e.g. `0.2.0.0`); they are what the exe's Properties dialog shows. The macOS preset (see `docs/MACOS.md`) has its own `application/short_version` and `application/version`: set them to the plain version (`0.2.0`, no `.0`).
2. Run the build script (or `scripts/release.ps1`, which also checks CI and creates the release; the macOS build is not part of it, see `docs/MACOS.md`).
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
- Same app id on every build, so running a newer setup upgrades in place, in the folder the game is already in. Saves live in Godot's user data folder (`%APPDATA%\Godot\app_userdata\The Unforgotten`) and are never touched by an upgrade, except for the one-time move described under "Renamed folders".
- Running an older setup over a newer install is refused with a message.
- On launch it asks the GitHub API for the latest release. If that is newer than the setup being run, it offers to open the download page. Skipped silently when offline, in silent mode, or when the repository is private (GitHub answers 404 without credentials). A token is deliberately not embedded in the installer. The reply is validated the way the game does it (`run/update_check.gd`): the response must be at most 65536 characters and the tag must be an optional `v`, then 1-4 dot-separated groups of 1-4 digits, at most 24 characters, nothing else. Anything else counts as no update info and setup proceeds silently.

## Renamed folders (v0.6.0 rename)

Up to v0.6.6 the game kept its data in `%APPDATA%\Godot\app_userdata\Card Battle Prototype` and could be installed in a folder with that name. Both now use the name of the game, and setup moves existing installs over:

- **Saves and settings.** After installing, setup copies `run_save.json` and `settings.json` (and their `.bak` and `.tmp` files) from the old user-data folder into `%APPDATA%\Godot\app_userdata\The Unforgotten`, never over a file that already exists there, and deletes the old folder once every file arrived (logs, caches and leftovers go with it). The game does the same move at startup (`run/user_data_migration.gd`, run by the `UserDataMigrationRunner` autoload before the settings load), so a direct run, a portable copy or a dev build is covered too. Whichever runs first does the work; the other finds nothing to do. If any copy fails the old folder is kept and the move is tried again next time.
- **Install folder.** An existing install in a folder named `Card Battle Prototype` is installed fresh into `{autopf}\The Unforgotten` and the old folder is deleted afterwards. An install in any other folder, including one the player chose, stays where it is. A game that is still running from the old folder (the in-game updater) may keep it from being deleted; it is then left behind and harmless.
- A v0.6.6 or older game started after the move finds no save in the old folder (it looks there) and starts fresh. Update it first. Progress made in an old build after the move is not copied over the newer save.

## Limits

- The exe is unsigned, so Windows SmartScreen may warn on first run.
- The exe has the default Godot icon (needs rcedit and an `.ico` to change).
- The game's own `exclude_filter` leaves out tests, tools, scripts and docs; the export is the full game in one embedded-pck exe (about 110 MB, 28 MB compressed).
