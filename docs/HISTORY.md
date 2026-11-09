# History of the review fix passes

Moved out of [`NEXT_STEPS.md`](NEXT_STEPS.md) so that file stays about the current state. Everything here is shipped; the most recent pass (the sixth) is in NEXT_STEPS until the next release.

- **Second review (tests, release tooling, docs):** `scripts/verify_release.ps1` checks a draft or published release from what GitHub serves (hash, manifest bytes, signature against the embedded keys) and `release.ps1` pins the release to the built commit, handles a half-created draft (`-ReplaceDraft`) and verifies after a non-draft publish; `build_installer.ps1` stops on a failed import and checks the exe and installer versions; CI is pinned to `windows-2022` and builds the export and an unsigned installer (these steps have since run green on pull requests); the installer's two big hashes run on a worker thread; every suite uses `TestBase`; content totals come from the registries with the intentional numbers in `tests/pinned_balance_tests.gd`; a signing-compat fixture, updater edge tests and RunSave/Settings edge tests were added; the smart-policy run test now plays all four characters; the Stray's cards are in `docs/CARDS.md`.

- **Fourth fix pass (tests, tooling, updater, docs; from an independent final review).** Now historical.
  - The in-game installer cap went from 150 to 300 MiB (the real installer is about 123 MiB). A test keeps the cap at least 1.5x the size in `tests/golden/latest_installer_size.txt` (`docs/UPDATE_CHECK.md`, "Installer size cap").
  - `check.ps1` prints the tail of a step's output when it times out and fails on engine-side runtime errors; the rules are proven on sample logs (`docs/CI.md`).
  - `run_tests.gd` fails below a minimum check count (first a `MIN_CHECKS` constant, replaced in the fifth pass by `tests/golden/min_checks.txt`).
  - `build_installer.ps1` picks the newest `Inno Setup*` folder and prints its version; CI refuses a non-6.x Inno Setup; Dependabot refreshes the pinned actions weekly.
  - `UpdateInstaller.discard()` and `cancel()` waited for the worker before cleaning up (the fifth pass made them non-blocking).
  - The audio and installer tests wait on frames and the worker thread, not timers.
  - Docs fixes and an "Updates, settings and data migration" section in `docs/ARCHITECTURE.md`.
  - The new CI steps (Inno version check, Dependabot) ran on pull requests and are green.
- **Fifth fix pass (tooling, updater, docs; from an independent final review).** Now historical.
  - The next release must stay under 150 MiB because v0.8.2 clients carry the old download cap. `build_installer.ps1` fails above it and `release.ps1` prints the margin to both caps (`docs/UPDATE_CHECK.md`, "Installer size cap").
  - `UpdateInstaller.cancel()` resets the installing and launched flags (a cancel during the launch copy used to leave "Update & restart" dead until restart, and a stray `run_*` folder).
  - `cancel()`, `discard()` and a new job retire the worker without joining it. A reaper in `_process` joins it once it has finished and removes its `run_*` folder, so the UI no longer freezes for the copy. Only freeing the node still joins (a `Thread` must be joined before it is freed).
  - Rule: `cancel()` keeps a verified installer the player has not discarded; only `discard()` removes it.
  - `build_installer.ps1` uses the newest Inno Setup 6.x and stops with a message when only another major version is installed (`scripts/inno_setup.ps1`, tested).
  - The check floor comes from `tests/golden/min_checks.txt` minus 1.5%, plus a floor for the number of `ui_*_test.gd` steps.
  - `check_log_patterns.ps1` fails on any `ERROR:` line that is not known noise (an allowlist keyed on the `at:` location, proven on real logs and `scripts/check_log_samples/`); its rules are case-sensitive.
  - Docs fixes (`CI.md` engine-update steps, the tag regex, `art/README.md`).
  - The Inno 6 guard, the 150 MiB guard and the log allowlist have since run on pull requests and on `main` in CI and are green.
- **Fourth fix pass (rules, UI, from the same review):** reduced motion now covers all non-essential motion (fighters, vendor, end card, pile cues, banner; essential damage and heal numbers stay, instantly) and `tests/ui_reduced_motion_test.gd` fails if a new animated script forgets it; the tooltip and tutorial rule and key text is built from the real constants (`CardGlossary.REDUCED_PERCENT`, `HAUNT_FALLS`, `BattleKeys.pile_keys_text()`); number keys include the keypad and 0 plays the tenth card; `PileViewer` and the art queue update in place and touch cached paths; `Battle` exposes `combat()`, `enemy_views()`, `drag()` and `request_refresh()` for its helpers; `RunState.complete_combat` takes the outcome from the fight itself when it ended on its own (a fight with no outcome is abandoned and the caller's win/lose flag is used); the bots use the engine's `Combat.spent_energy`, `surge_scale`, `hit_count` and `preview_hit` (the 300-run escape rates and the 60-run sim outputs are byte-identical); save bounds follow progress (`RunSave.max_deck`, `max_gold`, `max_copies`, `max_relics`: tamper-resistance, not security, proven by saving and loading at every stop of real runs); `balance_sim` exits non-zero when its policy fails.

