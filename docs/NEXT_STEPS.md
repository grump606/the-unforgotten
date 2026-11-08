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
  - Engine and UI review pass: the Forgotten-return relic and scaled-enemy fixes, bot rules shared with the engine, cached card pools (a 100-run sim went from 107 s to 6 s), route labels and backdrops stored on each stop, an idle-fighter redraw fix for defeated fighters only, and updater hardening (private launch copy of the installer, settings size cap, Skip cleans up, redirect limit, debug launch off in release builds). Still open from the review: the `battle.gd` and `card_view.gd` splits, rebuilding the hand without recreating every card view, Authenticode signing, and the repo size options in `docs/REPO_SIZE.md`.
- Four characters (Deserter, Thief, Medium, Stray), a neutral pool, relics sold at vendors, a pause menu and crash-safe save/resume. Design notes are in `docs/CLASSES_PLAN.md` and `docs/RELICS_DESIGN.md`.
- Windows installer (`scripts/build_installer.ps1`, `docs/INSTALLER.md`), in-game update check and self-install (`docs/UPDATE_CHECK.md`, `docs/UPDATE_SIGNING.md`), CI on every push (`docs/CI.md`). To ship: bump `config/version` (and `export_presets.cfg`), then `scripts/release.ps1`.

- **Second review (tests, release tooling, docs):** `scripts/verify_release.ps1` checks a draft or published release from what GitHub serves (hash, manifest bytes, signature against the embedded keys) and `release.ps1` pins the release to the built commit, handles a half-created draft (`-ReplaceDraft`) and verifies after a non-draft publish; `build_installer.ps1` stops on a failed import and checks the exe and installer versions; CI is pinned to `windows-2022` and builds the export and an unsigned installer (unproven until the first pull request run); the installer's two big hashes run on a worker thread; every suite uses `TestBase`; content totals come from the registries with the intentional numbers in `tests/pinned_balance_tests.gd`; a signing-compat fixture, updater edge tests and RunSave/Settings edge tests were added; the smart-policy run test now plays all four characters; the Stray's cards are in `docs/CARDS.md`.

## Decisions for the owner

These were deliberately not done in the review round.

1. **Authenticode signing of the installer. On hold (owner's call, 2026-11-08).** Today the in-game update is protected by our own signature, but a first-time download from the releases page is an unsigned `.exe`, so SmartScreen warns and some antivirus products are suspicious. Fixing that needs a code-signing certificate (an EV certificate from a CA, or Azure Trusted Signing; roughly 100 to 400 USD a year, with identity checks) and a `signtool` step in `build_installer.ps1` plus the key kept off the dev machine. Recommendation: not worth it while the audience is friends and playtesters who get the link directly; revisit before any public launch (itch.io or Steam distribution removes most of the warning on its own), and then prefer Azure Trusted Signing over a hardware token.
2. **Manifest freshness / expiry. Skipped (owner's decision, 2026-11-08).** Revisit only if a release ever needs to be withdrawn from players who have not yet updated, or after a security-relevant fix; then prefer a signed `revoked_below` version over an expiry date. The signed manifest names the file, version and hash, which stops an old installer being replayed as an update, but a manifest never expires: a stolen older-but-newer-than-installed signed release could still be served to someone who is further behind, and there is no way to withdraw a bad release for already-offered clients. A `valid_until` or `min_version` field would change the manifest format (both writers, the golden file and the fixture) and needs a clock the game can trust, so it is a policy call. Recommendation: skip the expiry date (a player offline for weeks would be unable to update, and the game cannot trust the clock anyway) and, if withdrawal ever matters, add a signed `revoked_below` version instead.
3. **History rewrite and repo size: done (2026-11-08).** History was rewritten once: fresh clones went from about 250 MiB to about 155 MiB, `audio/source` and `docs/reference` left the repository (they are git-ignored) and every commit now carries today's art. See `docs/REPO_SIZE.md`. Not done: lossless PNG recompression (needs `oxipng` or `zopflipng`), worth roughly another 15 to 25% of the art.

## To do, in the order I would take it

1. **Playtest v0.8.2**, mostly the new rest before the finale and the retuned Medium cards, then the Stray as a whole. The numbers are tuned against bots, not people (`docs/PLAYTEST_CHECKLIST.md`). Re-run the sims on the 22-stop line first: the figures in `docs/SIM.md` were measured on the 21-stop line and do not include the Stray.
2. **Cut the next release** once playtest feedback is in (0.8.3 or 0.9.0): bump `config/version` and `export_presets.cfg`, merge, then `scripts/release.ps1 -Publish`, check the draft with `scripts/verify_release.ps1 -Draft`, and publish it on GitHub. Check `docs/PLAYTEST_CHECKLIST.md` first.
3. **Finish the art**: painted rest and vendor figures, the Warden halberd and Conductor watch chain details (`art/README.md`).
4. **Retune from playtest feedback**: `REWARD_HEAL`, `HEAL_BELOW`, class HP, card costs. Check any change with the sims.
5. **Keep-5 hand rule review**: it shifted bot numbers unevenly (the Thief lost ground, the Medium gained in the smart bot). Knobs: `Combat.HAND_SIZE`, `Combat.HAND_MAX`.

## Smaller open items

- Economy (gold, vendor prices) is untested beyond a back-of-envelope check.
- Relics: playtest the feel and prices; the bots buy relics but do not play around them, so sim numbers understate them.
- Save-scumming (quit mid-fight, Continue replays the stop) is intentional.
- A sim-bot card that refunds its own cost and draws (Borrowed Time, Seance) is skipped when the draw pile is smaller than the draw, to avoid a self-redraw loop.
- Repo size: see `docs/REPO_SIZE.md` for the options the maintainer has to decide on.
- Bigger ideas: a branching map, more enemies, an elite tier that could drop relics.

## How to run

- Play: open the project in Godot 4.7.2 and press F5.
- Full check: `powershell -ExecutionPolicy Bypass -File scripts/check.ps1`
- Sims: see `docs/SIM.md`.
