# Next steps

Last updated after the tagged v0.8.1 release plus the unreleased work on `main` (the version in
`project.godot` is now 0.8.2, bumped and ready for `scripts/release.ps1`). Numbers such as the stop count
and card counts live in [`GAME_FACTS.md`](GAME_FACTS.md); sim results live in [`SIM.md`](SIM.md).

## State

- **Released:** v0.8.1 (tag `v0.8.1`): card tooltips that explain every mechanic on the card (`CardGlossary`), on top of v0.8.0. Earlier milestones: v0.8.0 and before brought the Stray (fourth class, Scent engine), v0.6.0 the rename to The Unforgotten, v0.5.0 the reskin, v0.4.0 painted art and the battle stage, v0.3.2 the in-game update check. `git tag` and the GitHub releases have the full list.
- **Unreleased on `main` since v0.8.1:**
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

## To do, in the order I would take it

1. **Playtest the unreleased build**, mostly the new rest before the finale and the retuned Medium cards, then the Stray as a whole. The numbers are tuned against bots, not people (`docs/PLAYTEST_CHECKLIST.md`). Re-run the sims on the 22-stop line first: the figures in `docs/SIM.md` were measured on the 21-stop line and do not include the Stray.
2. **Cut the next release** (0.8.2 or 0.9.0) once the playtest is happy. Check `docs/PLAYTEST_CHECKLIST.md` and the version mismatch checks in `scripts/release.ps1`.
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
