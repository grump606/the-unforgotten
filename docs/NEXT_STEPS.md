# Next steps

Last updated after the v0.8.2 release (2026-11-08) and the repository history rewrite. `main` is at v0.8.2; the next release needs a version bump.
Numbers such as the stop count and card counts live in [`GAME_FACTS.md`](GAME_FACTS.md); sim results live in [`SIM.md`](SIM.md).

## State

- **Released:** v0.8.2 (tag `v0.8.2`, 2026-11-08, Windows installer only), on top of v0.8.1 (card tooltips) and v0.8.0. Earlier milestones: v0.8.0 and before brought the Stray (fourth class, Scent engine), v0.6.0 the rename to The Unforgotten, v0.5.0 the reskin, v0.4.0 painted art and the battle stage, v0.3.2 the in-game update check. `git tag` and the GitHub releases have the full list.
- **What v0.8.2 contains (all of it is released):**
  - The Stray on the title screen.
  - A fifth rest before the Conductor (22 stops instead of 21; `docs/LEVELS_DESIGN.md`, "Pre-finale rest"). It lifts escape rates and has not been playtested.
  - Reckoning (3x the target's Haunt) and Spirit Tithe (heal 4 per Haunted enemy) retuned.
  - Condensed card tooltips (narrow wrapped block, smaller text).
  - A first-launch tutorial and a How to Play button (`run/tutorial_overlay.gd`, words in `run/tutorial_content.gd`, picture `art/tutorial/battle_layout.png`; retake the picture and move the markers if the battle layout changes).
  - P1 review fixes: dead attackers no longer hit, bad `Combat` input is rejected, the release script is hardened, and the macOS build is no longer part of releases (`docs/MACOS.md`).
  - Test and docs review pass (this one): tests are auto-discovered (`tests/README.md`), a shared `TestBase`, scratch-file cleanup, the big test files split by topic, one engine-version file for CI and scripts, an update-manifest golden test, a README split into `docs/`, `docs/GAME_FACTS.md`, `docs/README.md` (index of every doc with its status) and `docs/REPO_SIZE.md`.
  - Engine and UI review pass: the Forgotten-return relic and scaled-enemy fixes, bot rules shared with the engine, cached card pools (a 100-run sim went from 107 s to 6 s), route labels and backdrops stored on each stop, an idle-fighter redraw fix for defeated fighters only, and updater hardening (private launch copy of the installer, settings size cap, Skip cleans up, redirect limit, debug launch off in release builds). The `battle.gd` and `card_view.gd` splits from that review are done (PR #127, `docs/ARCHITECTURE.md`). Still open from it: rebuilding the hand without recreating every card view, Authenticode signing (see "Decisions for the owner"), and the repo size options in `docs/REPO_SIZE.md`.
- Four characters (Deserter, Thief, Medium, Stray), a neutral pool, relics sold at vendors, a pause menu and crash-safe save/resume. Design notes are in `docs/CLASSES_PLAN.md` and `docs/RELICS_DESIGN.md`.
- Windows installer (`scripts/build_installer.ps1`, `docs/INSTALLER.md`), in-game update check and self-install (`docs/UPDATE_CHECK.md`, `docs/UPDATE_SIGNING.md`), CI on every push (`docs/CI.md`). To ship: bump `config/version` (and `export_presets.cfg`), then `scripts/release.ps1`.

- Earlier fix passes: [`HISTORY.md`](HISTORY.md).
- **Sixth fix pass (tooling, updater, docs; the last one, from an independent review).**
  - Updater: a verified installer kept by `cancel()` (for example after update checks were switched off and on) is no longer run when the bar names a newer tag; the button discards it and downloads the new tag (`UpdateNotice._on_download`, test in `tests/ui_update_notice_test.gd`). `cancel()` and `discard()` no longer clear the launched flag once the installer has started. The three teardown paths are one `_abandon()` helper, and the header of `run/update_installer.gd` has a state table.
  - `scripts/build_installer.ps1`: the 2/3-of-cap rule only warns, because the 150 MiB legacy guard is always lower. The legacy cap is written once, as `LEGACY_CLIENT_CAP_MIB` in `scripts/engine_version.txt`, read by `build_installer.ps1` and `release.ps1` and tested by `scripts/engine_version_test.ps1`.
  - `scripts/check_log_patterns.ps1`: a `push_error` is allowed only with one of the known messages the tests provoke on purpose; an unknown `push_error` fails the check. Proven on a real full log, the CI log of the latest `main` push and `check_log_samples/passing_noise.txt` (0 false flags), with new bad and good samples.
  - Check floor record: `release.ps1` refuses a record that is more than 5% below the live total (`scripts/check_floor_record.ps1`); `check.ps1` repeats `NOTE:` lines (the 5% above-the-record note comes from `run_tests.gd`) before its verdict.
  - Docs: `CI.md` lists every workflow and `check.ps1` step; `RULES.md` was checked against `combat/combat.gd` (Surge at 0 and the Block trigger were right, wording tightened) and gained the owner decisions below.
  - Other teammates' changes in this pass (rules, UI, keyboard, sim exit codes) are documented by the supervisor.

## Decisions for the owner

These were deliberately not done in the review round.

1. **Authenticode signing of the installer. On hold (owner's call, 2026-11-08).** Today the in-game update is protected by our own signature, but a first-time download from the releases page is an unsigned `.exe`, so SmartScreen warns and some antivirus products are suspicious. Fixing that needs a code-signing certificate (an EV certificate from a CA, or Azure Trusted Signing; roughly 100 to 400 USD a year, with identity checks) and a `signtool` step in `build_installer.ps1` plus the key kept off the dev machine. Recommendation: not worth it while the audience is friends and playtesters who get the link directly; revisit before any public launch (itch.io or Steam distribution removes most of the warning on its own), and then prefer Azure Trusted Signing over a hardware token.
2. **Manifest freshness / expiry. Skipped (owner's decision, 2026-11-08).** Revisit only if a release ever needs to be withdrawn from players who have not yet updated, or after a security-relevant fix; then prefer a signed `revoked_below` version over an expiry date. The signed manifest names the file, version and hash, which stops an old installer being replayed as an update, but a manifest never expires: a stolen older-but-newer-than-installed signed release could still be served to someone who is further behind, and there is no way to withdraw a bad release for already-offered clients. A `valid_until` or `min_version` field would change the manifest format (both writers, the golden file and the fixture) and needs a clock the game can trust, so it is a policy call. Recommendation: skip the expiry date (a player offline for weeks would be unable to update, and the game cannot trust the clock anyway) and, if withdrawal ever matters, add a signed `revoked_below` version instead.
3. **History rewrite and repo size: done (2026-11-08).** History was rewritten once: fresh clones went from about 250 MiB to about 155 MiB, `audio/source` and `docs/reference` left the repository (they are git-ignored) and every commit now carries today's art. See `docs/REPO_SIZE.md`. Not done, deliberately: lossless PNG recompression. The tool is `oxipng` (`winget install Shssoichiro.Oxipng`); a test with a weaker optimizer saved about 20% with identical pixels, so roughly 25 to 30 MB of the 147 MB of art. It only shrinks clones if history is rewritten again (new files would otherwise sit beside the old ones and grow a fresh clone from about 157 MB to about 270 MB), and it does not change the installer or the game, which import their own texture format. Recommendation: skip it, and add it to the pass only if another history rewrite is ever needed for another reason.
4. **Oath `QUARRY_DIES` self-trigger rule: settled.** An Oath that is played does not react to its own play, as the comment always said; the code now follows it (`Combat._play_oath_limit`). No shipped card is affected: the only Quarry Oath, the Stray's `keep_the_trail`, adds a Dread and deals no damage, so it cannot kill the quarry (`tests/oath_quarry_tests.gd` pins this).
5. **Text-size option: not built.** A player-facing text-size setting was considered in the review and left out; it touches every screen's layout, so it needs a design decision first. (Reconfirmed 2026-11-08: still no text-size option.)
6. **Surge at 0 energy: stays playable (decided 2026-11-08).** A Surge card can be played at 0 energy; it then does nothing and counts as a play, like any other 0-cost card (`docs/RULES.md`).
7. **`ON_BLOCK_GAINED` rule (decided 2026-11-08).** It counts only Block gained by the played card's own effects, not Block from an Oath effect or relic that fires during the same play (`docs/RULES.md`).
8. **No keyword key (decided 2026-11-08).** A separate keyword key (a legend of the card keywords) was considered in the review and is not added.
9. **`latest_installer_size.txt` stays manual (decided 2026-11-08).** `release.ps1` does not update it, because the build-time guard is the enforcement: `build_installer.ps1` fails above the 150 MiB cap of already-released clients (`LEGACY_CLIENT_CAP_MIB`) and only warns above 2/3 of the current cap. The file only feeds the "cap is at least 1.5x the latest installer" test.
10. **Scent-spending kill (decided, sixth pass).** If a hit that spends Scent kills the quarry, the kill still counts as the quarry's death: the `QUARRY_KILL_HEAL` relic and the `QUARRY_DIES` Oaths fire, and no Scent is passed on to an heir because it was spent (`docs/RULES.md`, "Scent and the quarry").
11. **Block from `discard_effects` (decided, sixth pass).** It stays as is: it does not trigger `ON_BLOCK_GAINED` (`docs/RULES.md`).
12. **Keyboard-only play (decided, sixth pass).** Focus restore, focus on overlay open and a combat-log key (L) are added in this pass. No keyboard readout of enemy Omen or status, and no keyword key.
13. **Quit and resume (decided, sixth pass).** Quitting mid-fight and continuing replays the same encounter and shuffle on purpose (`docs/RULES.md`, "Saving and resuming").

## To do, in the order I would take it

1. **Playtest v0.8.2**, mostly the new rest before the finale and the retuned Medium cards, then the Stray as a whole. The numbers are tuned against bots, not people (`docs/PLAYTEST_CHECKLIST.md`). Re-run the sims on the 22-stop line first: the figures in `docs/SIM.md` were measured on the 21-stop line and do not include the Stray.
2. **Cut the next release** once playtest feedback is in (0.8.3 or 0.9.0). **It must stay under 150 MiB** (the installer is about 123 MiB): v0.8.2 players carry the old 150 MiB download cap, and `build_installer.ps1` fails above it until a release with the 300 MiB cap has been out long enough (`docs/UPDATE_CHECK.md`, "Installer size cap"): bump `config/version` and `export_presets.cfg`, merge, then `scripts/release.ps1 -Publish`, check the draft with `scripts/verify_release.ps1 -Draft`, and publish it on GitHub. Check `docs/PLAYTEST_CHECKLIST.md` first.
3. **Finish the art**: painted rest and vendor figures, the Warden halberd and Conductor watch chain details (`art/README.md`).
4. **Retune from playtest feedback**: `REWARD_HEAL`, `HEAL_BELOW`, class HP, card costs. Check any change with the sims.
5. **Keep-5 hand rule review**: it shifted bot numbers unevenly (the Thief lost ground, the Medium gained in the smart bot). Knobs: `Combat.HAND_SIZE`, `Combat.HAND_MAX`.

## Smaller open items

- Economy (gold, vendor prices) is untested beyond a back-of-envelope check.
- Relics: playtest the feel and prices; the bots buy relics but do not play around them, so sim numbers understate them.
- Save-scumming is intentional (see decision 13 above).
- A sim-bot card that refunds its own cost and draws (Borrowed Time, Seance) is skipped when the draw pile is smaller than the draw, to avoid a self-redraw loop.
- Repo size: see `docs/REPO_SIZE.md` for the options the maintainer has to decide on.
- Bigger ideas: a branching map, more enemies, an elite tier that could drop relics.

## How to run

- Play: open the project in Godot 4.7.2 and press F5.
- Full check: `powershell -ExecutionPolicy Bypass -File scripts/check.ps1`
- Sims: see `docs/SIM.md`.
