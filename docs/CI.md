# Continuous integration

`.github/workflows/check.yml` runs on every push to `main` and every pull request, on a
`windows-latest` runner. It downloads the pinned Godot engine, then runs
`scripts/check.ps1` (import, headless unit tests, main-scene smoke load, every UI test, the update
manifest golden check). The job fails if the script exits non-zero. Permissions are `contents: read`,
the job times out after 30 minutes, and a newer run on the same ref cancels the older one. Every
action is pinned by commit SHA.

Everything runs headless (`--headless`), so no GPU or display is needed.

## Where the versions live

`scripts/engine_version.txt` is the one place the tool versions are written down:

```
GODOT_VERSION=4.7.2-stable
GODOT_ZIP_SHA512=<sha512 of Godot_v<GODOT_VERSION>_win64.exe.zip>
INNO_SETUP_VERSION=6.7.3
```

It is read by `scripts/check.ps1`, `scripts/release.ps1`, `scripts/build_installer.ps1` and
`scripts/debug_fight.ps1` (through `scripts/engine_version.ps1`), and by the workflow's "Read engine
version" step, which exports `GODOT_VERSION` and `GODOT_ZIP_SHA512` to the later steps. The SHA512 is
the integrity pin: the download step throws if the zip does not hash to it. Prose docs
(`INSTALLER.md`, `MACOS*.md`) mention the version for humans; they are not read by anything.

## Run it locally

The script finds the engine in this order: `-Godot` parameter, `GODOT_EXE`, `GODOT`, then
`Godot_v<GODOT_VERSION>_win64.exe\Godot_v<GODOT_VERSION>_win64_console.exe` in the repo root.

```powershell
$env:GODOT_EXE = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File scripts/check.ps1
# or
powershell -ExecutionPolicy Bypass -File scripts/check.ps1 -Godot 'C:\path\to\...console.exe'
```

`scripts/build_installer.ps1` also honours `GODOT_EXE`.

## Update the engine version

1. In `scripts/engine_version.txt`, change `GODOT_VERSION` (for example `4.7.3-stable`).
2. Copy the SHA512 of `Godot_v<version>_win64.exe.zip` from
   `https://github.com/godotengine/godot-builds/releases/download/<version>/SHA512-SUMS.txt`
   into `GODOT_ZIP_SHA512`. The engine cache key and the import cache key both include the
   version, so a change refetches and re-imports.
3. Install the matching export templates on the build machine (`docs/INSTALLER.md`).

Nothing else needs editing. The Inno Setup pin (`INNO_SETUP_VERSION`) is changed the same way; see
`docs/INSTALLER.md`.

## The import cache

The "Cache Godot import folder" step caches `.godot` (imported textures and audio, the class and uid
caches), which is the slowest part of a cold run. It cannot hide a failure:

- The key is an exact hash of everything that affects import: scripts, scenes, resources, `.import`
  and `.uid` files, `art/` and `audio/`, `project.godot`, `export_presets.cfg`, the engine version and a
  salt. There is no `restore-keys` fallback, so a hit means a byte-identical project and anything
  else imports from scratch.
- `check.ps1` still runs `--import` first, so a restored cache is re-validated by the engine.
- `actions/cache` saves only when the job succeeded, so a failing run never writes a cache.

To force a cold run (for example if you suspect a bad cache), bump `IMPORT_CACHE_SALT` at the top of
`check.yml`.

## The update manifest golden check

The signed update manifest is written by PowerShell (`New-UpdateManifestText` in
`scripts/update_signing.ps1`, used by `build_installer.ps1`) and parsed by GDScript
(`UpdateCheck.make_manifest` and `parse_manifest`). `tests/golden/update_manifest.txt` holds the exact
bytes for a fixed input. `tests/update_manifest_golden_tests.gd` checks the GDScript side and
`scripts/check_manifest_golden.ps1` (a step of `check.ps1`) checks the PowerShell side. If you change
the manifest format, change both writers and the golden file together.
