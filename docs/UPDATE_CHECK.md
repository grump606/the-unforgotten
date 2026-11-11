# Update check

On launch the game asks GitHub whether a newer release exists. If one does, nothing appears on its own: the main menu's small **Update** button turns red. Clicking the red button shows a small bar at the bottom of the screen (main menu, character select, or the saved-run Continue prompt) that says `Update available: v0.3.1 (you have 0.3.0)` with a **Download** button (opens the releases page in the browser) and a **Skip** button. **Skip** turns update checks off (saved in settings, the Update button goes grey) and the bar goes away, so the menu looks normal again. The bar never blocks play, and it is not shown once a run is under way.

## Privacy

The game contacts `api.github.com` once per launch: a single HTTPS `GET https://api.github.com/repos/grump606/the-unforgotten/releases/latest` with a `User-Agent: the-unforgotten/<version>` header and an `Accept` header. Nothing else is sent: no identifiers, no save data, no tokens, no telemetry. GitHub sees the usual connection details (IP address) like for any web request. The check itself only reads the reply and downloads nothing. Installing an update in the game is a separate step that only runs when the player clicks (see "Updating in the game" below).

## Turning it off

In the game: the main menu has a small **Update** button in the bottom-right corner: grey when checks are off, teal when on, red when checks are on and a newer version is available. Click it to toggle the checks, except when it is red: then the click shows the update bar instead (use **Skip** there to turn the checks off). It is saved in `user://settings.json` as `{"update_check_enabled": false}` and applies from then on. Turning it off cancels any request in flight and hides a notice already shown; no request is made at all while it is off. Turning it on asks GitHub right away. It defaults to on. The settings file is treated as untrusted: it is capped at 4 KB and the value must be a real boolean, otherwise the default (on) is used, with no error.

From outside the game: set the environment variable `THE_UNFORGOTTEN_NO_UPDATE_CHECK` to any non-empty value before launching, for example `$env:THE_UNFORGOTTEN_NO_UPDATE_CHECK = "1"`. The check is also skipped on its own in headless runs (tests, CI, the sims), so those never touch the network. The variable and headless always win: the check runs only if none of the three says no.

## Behaviour and safety

- The request is asynchronous (an `HTTPRequest` node, which does its networking off the main thread; 5 s timeout, reply capped at 64 KB), so the game never waits on it.
- Every failure is silent: offline, timeout, HTTP error or rate limit (anything but 200), a reply that is not JSON, a missing or odd `tag_name`. No notice, no dialog, no warning in the log.
- The reply is untrusted. Only `tag_name` is read, and only if it matches `^[vV]?[0-9]{1,4}(\.[0-9]{1,4}){0,3}\z` (`\z`, not `$`, which would also accept a trailing newline). The page Download opens is the constant `https://github.com/grump606/the-unforgotten/releases/latest`; no URL from the reply is ever used.

## Version comparison

The running version is `application/config/version` in `project.godot`. Versions are compared as dotted numbers, group by group, with missing groups counted as 0, like the installer's `CompareVersions`: `1.2.10` is newer than `1.2.9`, `0.3.1` is newer than `0.3`, and `0.3` equals `0.3.0`. A notice shows only when the release is strictly newer. If either side is not a valid version there is no notice.

## Code and tests

- `run/update_check.gd` (`UpdateCheck`): the pure logic (enable rules, tag validation, version compare, reply parsing, notice text).
- `run/update_notice.gd` (`UpdateNotice`): the bar and the `HTTPRequest` (`reveal()` shows the bar, the `skipped` signal is Skip). `handle_response(code, body)` takes a reply directly, which is how tests and `tools/update_sheet.gd` (screenshots) work without a network.
- `run/settings.gd` (`Settings`): load/save of `user://settings.json`. `run.gd` reads it at launch (`settings_path`, which tests point at a scratch file) and the menu toggle writes it.
- Tests: `tests/update_check_tests.gd` (discovered by `run_tests.gd`, as are `tests/settings_tests.gd`, `tests/update_verifier_tests.gd` and `tests/update_installer_tests.gd`) and `tests/ui_update_notice_test.gd` (`scripts/check.ps1`).

## Updating in the game

When a signing key is built in (`docs/UPDATE_SIGNING.md`) and the game is an exported, writable install named `TheUnforgotten.exe`, the notice's button reads **Update & restart** instead of Download. Nothing happens until the player clicks it. Then, with progress shown on the bar:

1. The game downloads `TheUnforgotten-Setup-<version>.exe.manifest.sig` (at most 1 KB), then `TheUnforgotten-Setup-<version>.exe.manifest` (at most 512 bytes), and only then the installer (at most 300 MiB; the real installer is about 123 MiB, and a test keeps the cap at least 1.5x the latest release, see "Installer size cap" below), all from `https://github.com/grump606/the-unforgotten/releases/download/v<version>/`. The URLs are built from the already-validated tag and that fixed prefix; nothing from the reply chooses where it downloads from.
2. It checks the manifest before downloading the installer. The manifest is four fixed lines (header, `name=`, `version=`, `sha256=`). Its RSA PKCS#1 v1.5 signature must verify against the public key embedded in `run/update_verifier.gd`; it must name exactly this release's installer file and version; and that version must be newer than the running game. Signing the name and version, not just the bytes, is what stops an older genuinely signed installer being replayed as an update. Any mismatch, a missing file, a malformed manifest or no embedded key stops here, before the installer is downloaded.
3. It checks the downloaded installer's SHA-256 against the one in the signed manifest, and checks it again immediately before running the file (it sits in the player's profile folder in between). A mismatch deletes the file. Then it starts the installer silently (`/SILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1`) and quits. The installer replaces the game files in place (same AppId) and `installer/setup.iss` starts the game again because of `/RELAUNCH=1`.

The button only appears on the first screens, where no run is in progress. If the download finishes while a run has been started, nothing restarts; the bar waits with a **Restart now** button for the next menu screen.

Any failure shows `Update failed: <reason>` and the button falls back to the plain Download button, so the player is never stuck. The game also never updates itself from the editor, from a differently named executable, or from a folder it cannot write (an all-users install), where it keeps the Download button.

Files downloaded this way carry no Windows "downloaded from the internet" mark, so SmartScreen does not warn about them; the signature check is the protection. The installer is not Authenticode-signed.

Code: `run/update_installer.gd` (`UpdateInstaller`, the download/verify/launch state machine), `run/update_verifier.gd` (`UpdateVerifier`), URL builders in `run/update_check.gd`. Tests: `tests/update_installer_tests.gd`, `tests/update_verifier_tests.gd`, the in-game-install section of `tests/ui_update_notice_test.gd`.

## Cancel, Skip and the worker

The copy and hash of the installer run on a worker thread. `cancel()` (the player turned update checks off) abandons work in flight: a download goes back to idle, and a launch copy that is being made is dropped while the verified installer is kept, so "Update & restart" still works afterwards. `discard()` (Skip) removes the installer too. Neither waits for the worker: the result is ignored and a reaper in `_process` joins the thread once it has finished and deletes its `run_*` folder. Only freeing the node joins a running worker, since a `Thread` must be joined before it is freed. `cancel()`, `discard()` and freeing the node share one helper (`_abandon`); the states and flags are tabulated in the header of `run/update_installer.gd`. Once the installer has been started, nothing clears the launched flag, so a late click cannot start a second one. A verified installer kept by `cancel()` is for the tag it was downloaded for: if the bar later names a different tag, the button discards it and downloads the new one instead of running the old file.

## Installer size cap

`UpdateCheck.MAX_INSTALLER_BYTES` (300 MiB) is the most the game will download for an installer; a larger body is refused by the HTTP node and the update fails with "could not be downloaded". The real installer is about 123 MiB (v0.8.2: 129,156,777 bytes), so the cap has room for the art to roughly double. Two guards keep it that way:

- `tests/golden/latest_installer_size.txt` holds the byte size of the latest published installer, and `tests/update_check_tests.gd` fails if the cap is below 1.5x of it. After each release, put the size that `release.ps1` prints ("Installer size: ...") in that file in the next commit.
- `scripts/build_installer.ps1` only warns when the installer is over 2/3 of the cap. It used to fail above 150 MiB, the cap inside games released up to v0.8.2 (decided 2026-11-10): those games cannot install a larger installer in-game, so those players must download it from the releases page by hand. To raise the cap, change the constant in `run/update_check.gd` and ship the game with the new cap one release before the installer needs it, because already-installed games keep their old cap.
