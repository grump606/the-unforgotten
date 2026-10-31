# Update check

On launch the game asks GitHub whether a newer release exists. If one does, a small bar at the bottom of the first screen (character select, or the saved-run Continue prompt) says `Update available: v0.3.1 (you have 0.3.0)` with a **Download** button (opens the releases page in the browser) and an **x** to dismiss it. It never blocks play, and it is not shown once a run is under way.

## Privacy

The game contacts `api.github.com` once per launch: a single HTTPS `GET https://api.github.com/repos/grump606/card-battle-prototype/releases/latest` with a `User-Agent: card-battle-prototype/<version>` header and an `Accept` header. Nothing else is sent: no identifiers, no save data, no tokens, no telemetry. GitHub sees the usual connection details (IP address) like for any web request. The check itself only reads the reply and downloads nothing. Installing an update in the game is a separate step that only runs when the player clicks (see "Updating in the game" below).

## Turning it off

In the game: the main menu has a **Check for updates: On/Off** button. It is saved in `user://settings.json` as `{"update_check_enabled": false}` and applies from then on. Turning it off cancels any request in flight and hides a notice already shown; no request is made at all while it is off. Turning it on asks GitHub right away. It defaults to on. The settings file is treated as untrusted: it is capped at 4 KB and the value must be a real boolean, otherwise the default (on) is used, with no error.

From outside the game: set the environment variable `CARD_BATTLE_NO_UPDATE_CHECK` to any non-empty value before launching, for example `$env:CARD_BATTLE_NO_UPDATE_CHECK = "1"`. The check is also skipped on its own in headless runs (tests, CI, the sims), so those never touch the network. The variable and headless always win: the check runs only if none of the three says no.

## Behaviour and safety

- The request is asynchronous (a worker thread, 5 s timeout, reply capped at 64 KB), so the game never waits on it.
- Every failure is silent: offline, timeout, HTTP error or rate limit (anything but 200), a reply that is not JSON, a missing or odd `tag_name`. No notice, no dialog, no warning in the log.
- The reply is untrusted. Only `tag_name` is read, and only if it matches `^[vV]?[0-9]{1,4}(\.[0-9]{1,4}){0,3}$`. The page Download opens is the constant `https://github.com/grump606/card-battle-prototype/releases/latest`; no URL from the reply is ever used.

## Version comparison

The running version is `application/config/version` in `project.godot`. Versions are compared as dotted numbers, group by group, with missing groups counted as 0, like the installer's `CompareVersions`: `1.2.10` is newer than `1.2.9`, `0.3.1` is newer than `0.3`, and `0.3` equals `0.3.0`. A notice shows only when the release is strictly newer. If either side is not a valid version there is no notice.

## Code and tests

- `run/update_check.gd` (`UpdateCheck`): the pure logic (enable rules, tag validation, version compare, reply parsing, notice text).
- `run/update_notice.gd` (`UpdateNotice`): the bar and the `HTTPRequest`. `handle_response(code, body)` takes a reply directly, which is how tests and `tools/update_sheet.gd` (screenshots) work without a network.
- `run/settings.gd` (`Settings`): load/save of `user://settings.json`. `run.gd` reads it at launch (`settings_path`, which tests point at a scratch file) and the menu toggle writes it.
- Tests: `tests/update_check_tests.gd` (in `run_tests.gd`; it also runs `tests/settings_tests.gd`) and `tests/ui_update_notice_test.gd` (`scripts/check.ps1`).

## Updating in the game

When a signing key is built in (`docs/UPDATE_SIGNING.md`) and the game is an exported, writable install named `CardBattlePrototype.exe`, the notice's button reads **Update & restart** instead of Download. Nothing happens until the player clicks it. Then, with progress shown on the bar:

1. The game downloads `CardBattlePrototype-Setup-<version>.exe.sig` (at most 1 KB) and then the installer (at most 150 MB) from `https://github.com/grump606/card-battle-prototype/releases/download/v<version>/`. The URL is built from the already-validated tag and that fixed prefix; nothing from the reply chooses where it downloads from.
2. It checks the signature: an RSA PKCS#1 v1.5 signature over the installer's SHA-256, made with the maintainer's private key, verified against the public key embedded in `run/update_verifier.gd`. A mismatch, a missing `.sig`, a damaged file or no embedded key all stop here and delete the download.
3. It checks the signature again immediately before running the file (it sits in the player's profile folder in between), then starts the installer silently (`/SILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1`) and quits. The installer replaces the game files in place (same AppId) and `installer/setup.iss` starts the game again because of `/RELAUNCH=1`.

The button only appears on the first screens, where no run is in progress. If the download finishes while a run has been started, nothing restarts; the bar waits with a **Restart now** button for the next menu screen.

Any failure shows `Update failed: <reason>` and the button falls back to the plain Download button, so the player is never stuck. The game also never updates itself from the editor, from a differently named executable, or from a folder it cannot write (an all-users install), where it keeps the Download button.

Files downloaded this way carry no Windows "downloaded from the internet" mark, so SmartScreen does not warn about them; the signature check is the protection. The installer is not Authenticode-signed.

Code: `run/update_installer.gd` (`UpdateInstaller`, the download/verify/launch state machine), `run/update_verifier.gd` (`UpdateVerifier`), URL builders in `run/update_check.gd`. Tests: `tests/update_installer_tests.gd`, `tests/update_verifier_tests.gd`, the in-game-install section of `tests/ui_update_notice_test.gd`.
