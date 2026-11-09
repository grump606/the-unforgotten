# Continuous integration

`.github/workflows/check.yml` runs on every push to `main` and every pull request, on a pinned `windows-2022`
runner (not `windows-latest`: the installer step relies on what that image has preinstalled, and "latest" moves on
GitHub's schedule; change it on purpose in its own pull request). The job fails if any step fails. Permissions are
`contents: read`, the job times out after 45 minutes, and a newer run on the same ref cancels the older one. Every
action is pinned by commit SHA.

The workflow's steps, in order:

1. Checkout.
2. Read engine version (`scripts/engine_version.txt`, four keys exported).
3. Parse PowerShell scripts (every `scripts/*.ps1` must parse).
4. Cache and download the Godot engine (the zip must match `GODOT_ZIP_SHA512`).
5. Cache the Godot import folder.
6. Run full check: `scripts/check.ps1` (below).
7. Cache and download the Windows export templates (checked against `GODOT_TEMPLATES_SHA512`).
8. Install export templates and Inno Setup (a non-6.x Inno Setup fails the job).
9. Build the installer, unsigned: `scripts/build_installer.ps1 -NoSign` (see "Export and installer build").

`scripts/check.ps1` runs these steps, in order, and stops at the first failure:

1. `import`, `tests` (`tests/run_tests.gd`: every `tests/*_tests.gd`), `smoke`, `battle seed`, `audio runtime`.
2. One step per `tests/ui_*_test.gd` file (a floor on how many there must be), then `reskin restoration`.
3. `check log patterns` (`scripts/check_log_patterns_test.ps1`: the log rules against sample logs).
4. `inno setup choice` (`scripts/inno_setup_test.ps1`).
5. `engine version` (`scripts/engine_version_test.ps1`: the version file and the legacy installer cap).
6. `check floor record` (`scripts/check_floor_record_test.ps1`).
7. `manifest golden` (`scripts/check_manifest_golden.ps1`).
8. `verify release` (`scripts/check_verify_release.ps1`: `verify_release.ps1` against the signing fixture).

Every Godot step is also scanned for script and engine errors (see "What counts as a failed step"). `NOTE:` lines
printed by any step are repeated just before the verdict.

Everything runs headless (`--headless`), so no GPU or display is needed.

## Where the versions live

`scripts/engine_version.txt` is the one place the tool versions are written down:

```
GODOT_VERSION=4.7.2-stable
GODOT_ZIP_SHA512=<sha512 of Godot_v<GODOT_VERSION>_win64.exe.zip>
GODOT_TEMPLATES_SHA512=<sha512 of Godot_v<GODOT_VERSION>_export_templates.tpz>
INNO_SETUP_VERSION=6.7.3
LEGACY_CLIENT_CAP_MIB=150
```

It is read by `scripts/check.ps1`, `scripts/release.ps1`, `scripts/build_installer.ps1` and
`scripts/debug_fight.ps1` (through `scripts/engine_version.ps1`), and by the workflow's "Read engine
version" step, which exports the first four keys to the later steps (`LEGACY_CLIENT_CAP_MIB` is read only by the
installer and release scripts: the in-game download cap of already-released clients, `docs/UPDATE_CHECK.md`). The SHA512 is
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
3. From the same `SHA512-SUMS.txt`, copy the SHA512 of `Godot_v<version>_export_templates.tpz` into
   `GODOT_TEMPLATES_SHA512` (the installer-build job refuses templates that do not match it).
4. Install the matching export templates on the build machine (`docs/INSTALLER.md`).

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

## What counts as a failed step

`check.ps1` fails a step on a non-zero exit code, on a timeout (the last 60 lines of its output are printed
first, so a hang leaves a log), and when its output contains a script error. What that means is in
`scripts/check_log_patterns.ps1`: every `SCRIPT ERROR` / `Parse Error` / failed script load and the runtime
shapes `Invalid call`, `Invalid access`, `Cannot call method` (all case-sensitive, as the engine prints them),
and **every other `ERROR:` line unless it is known test noise**. The noise is an allowlist keyed on the `at:`
location the engine prints under the message: `push_error` calls with one of the known messages the tests provoke
on purpose (`$script:CheckKnownPushErrors`; a `push_error` with any other message fails, so a real regression that
reports through `push_error` is caught), the few engine complaints about a deliberately bad argument
(`hashing_context.cpp`, `crypto_mbedtls.cpp`, `dir_access.cpp` in the installer tests) and the exit-time leak report. Warnings never fail a step. An
`ERROR:` line that is not on the list fails the check: fix the code, or add it to the list with a comment on
which test causes it (a new negative test that provokes a new `push_error` message needs a line in
`CheckKnownPushErrors` and an example in the test). The lists were built from a real full passing log and the CI log of the same commit.
`scripts/check_log_patterns_test.ps1` (a step of `check.ps1`) feeds the rules sample bad and noisy logs, and
`scripts/check_log_samples/passing_noise.txt` (every distinct `ERROR:`/`WARNING:` shape of a real passing run,
with the line after it) must stay clean.

## Check floors

`tests/run_tests.gd` fails a run whose `CHECKS: n` total is below the recorded total minus 1.5%, and
`check.ps1` fails with fewer `ui_*_test.gd` steps than recorded. Both records live in
`tests/golden/min_checks.txt`, which also says how to refresh them (`tests/README.md`).

The record must not fall far behind either. `tests/run_tests.gd` prints a `NOTE:` when the live total is more than
5% above the record (`check.ps1` repeats it just before `CHECK PASSED`), and `scripts/release.ps1` refuses to
release when the record is more than 5% below the live total of its own full check (`scripts/check_floor_record.ps1`,
tested by `check_floor_record_test.ps1`). Refresh `TOTAL_CHECKS` first, then release.

## Export and installer build (no signing, no publishing)

After the check, the job builds what `scripts/release.ps1` would build, so a broken export preset, a missing
template, an installer script that no longer compiles or a version string that disagrees with `project.godot`
fails the pull request instead of release day:

1. **Windows export templates**: the Godot `.tpz` is downloaded once, checked against `GODOT_TEMPLATES_SHA512`
   and only the three Windows files are kept and cached (key: version plus hash).
2. **Inno Setup**: `choco install innosetup --version=<INNO_SETUP_VERSION>` (Chocolatey is on the runner image;
   winget is not reliably there). `build_installer.ps1` finds `ISCC.exe` in the newest `Inno Setup*` folder under `Program Files (x86)`, `Program Files` or the per-user `Programs` folder.
3. **`scripts/build_installer.ps1 -NoSign`**: imports (a failed import fails the build), exports the Windows
   build, checks the exe's file and product version against `config/version`, compiles the installer and checks
   its version. It fails when the installer is over the legacy client cap (`LEGACY_CLIENT_CAP_MIB`, 150 MiB) and only
   warns when it is over 2/3 of the current 300 MiB cap. `-NoSign` skips the manifest and signature (no private key is ever on the runner); the output
   is discarded with the runner and must never be released. `release.ps1` never passes `-NoSign`.

These steps have run green on pull requests since they were added. They are not skipped when no
installer-related file changed; the export is a couple of minutes and a path filter would need another pinned
action. If Chocolatey has no package for the pinned Inno Setup version, the step installs the newest one it has
and then fails unless that is a 6.x (and prints the version either way); `build_installer.ps1` prints the Inno
Setup version it found and picks the newest `Inno Setup*` folder. Dependabot (`.github/dependabot.yml`, weekly)
opens pull requests that refresh the SHA-pinned actions.

`scripts/check_verify_release.ps1` (a step of `check.ps1`) tests `scripts/verify_release.ps1` offline against
the committed signing fixture in `tests/golden` (see `tests/signing_compat_tests.gd`).

## The update manifest golden check

The signed update manifest is written by PowerShell (`New-UpdateManifestText` in
`scripts/update_signing.ps1`, used by `build_installer.ps1`) and parsed by GDScript
(`UpdateCheck.make_manifest` and `parse_manifest`). `tests/golden/update_manifest.txt` holds the exact
bytes for a fixed input. `tests/update_manifest_golden_tests.gd` checks the GDScript side and
`scripts/check_manifest_golden.ps1` (a step of `check.ps1`) checks the PowerShell side. If you change
the manifest format, change both writers and the golden file together.
