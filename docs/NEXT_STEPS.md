# Next steps

Last updated 2026-11-16. **Released:** v0.10.0 (2026-11-13), Chapter 2, the Registry; v0.10.1 (2026-11-15: Find the
Seam+ keeps Ready in the export, a Draw after a Glimpse waits for the pick, the 400 MiB installer cap and the review
fixes). **Version on `main`: 0.10.2** (safe save migration, the release floor check and the updater thread fallback).
Threaded art reads (PaintedArt on the loader threads, about a third of the main-thread warm-up time) were tried and
reverted before release: the UI flow test once logged `Parameter "t" is null` (a texture read back before it was
ready); not reproduced in 6 further runs. Retry only with a test that forces that race. **On `main`, not released:** Chapter 3 and the finale, built and bot-tuned but switched off (`Chapters.COUNT` is still 2, so a run
still ends with "To be continued"), plus a code review pass (below). The next work is the Chapter 3 playtest and the
release that turns it on (`docs/CHAPTER3_PLAN.md`, "Order of work", step 6).
Numbers such as the stop count and card counts live in [`GAME_FACTS.md`](GAME_FACTS.md); sim results live in [`SIM.md`](SIM.md).
Older states of this page are in [`HISTORY.md`](HISTORY.md).

## State

- **Released:** v0.10.0 (GitHub release `v0.10.0`, 2026-11-13, Windows installer only): Chapter 2, the Registry, and the chapter
  structure (a break and a boss reward after each chapter), with the elite art, elite modifiers, the tutorial and the
  district names. Before it: v0.9.0 (the branching route map, elites).
- **On `main`, unreleased:**
  - **Chapter 3 and the finale** (`docs/CHAPTER3_PLAN.md`): seven enemies, the Blotter (mid-boss), the Warden of the
    Inkwell (end boss) and the Scrivener (final boss, three phases) in `data/enemies/chapter3/`; the Cross Out effect;
    35 story texts, 10 events, 24 cards, 7 relics and the finale texts; the art (enemies, elite auras, backdrops,
    story paintings, card art). Tuned with a per-chapter pack scale bound and class and boss factors; the 400-run bot
    confirmation is in `docs/SIM.md` ("Chapter 3 confirmation"): every class within about 5 points of target, the
    finale a little hard (18 to 23% of smart runs that reach it lost; target 15%). Switched on by `Chapters.COUNT = 3`.
  - **In-game download cap 400 MiB** (from 300) for the larger Chapter 3 installer; it ships one release before it is
    needed, so v0.10.1 should go out before the Chapter 3 release (`docs/UPDATE_CHECK.md`, "Installer size cap").
  - **Code review pass (2026-11-14/15):**
    - The run and combat layers were split into helpers: `RunEvents`, `RunRewards`, `RunSpoils`, `RunChapters`,
      `RelicEffects`, `ScentRules`.
    - `Encounters` now builds every fight, and `StarterContent` is the content catalog only.
    - `CharacterIds` holds the character ids, and typed classes replace ad-hoc dictionaries.
    - `tests/script_wiring_tests.gd` fails on an unused game script or a missing `.uid`.
    - Updater: the signed `min_version` floor, a 60 s download stall watchdog instead of a 600 s total timeout, and
      `/DIR=` so a moved copy updates itself.
    - Saves: a newer `.tmp` wins after a failed rename.
    - CI installs exactly the pinned Inno Setup, checked by SHA-256 and Authenticode.
- **Standing features:** four characters (Deserter, Thief, Medium, Stray), the route map with elites, relics,
  events, shops and rests, a pause menu and crash-safe save/resume, the tutorial, the Windows installer
  (`docs/INSTALLER.md`), the in-game update check and self-install (`docs/UPDATE_CHECK.md`, `docs/UPDATE_SIGNING.md`)
  and CI on every push (`docs/CI.md`).

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
9. **`latest_installer_size.txt` stays manual (decided 2026-11-08).** `release.ps1` does not update it, because `build_installer.ps1` already warns above 2/3 of the current cap (it does not fail on size since 2026-11-10). The file only feeds the "cap is at least 1.5x the latest installer" test.
10. **Scent-spending kill (decided, sixth pass).** If a hit that spends Scent kills the quarry, the kill still counts as the quarry's death: the `QUARRY_KILL_HEAL` relic and the `QUARRY_DIES` Oaths fire, and no Scent is passed on to an heir because it was spent (`docs/RULES.md`, "Scent and the quarry").
11. **Block from `discard_effects` (decided, sixth pass).** It stays as is: it does not trigger `ON_BLOCK_GAINED` (`docs/RULES.md`).
12. **Keyboard-only play (decided, sixth pass).** Focus restore, focus on overlay open and a combat-log key (L) are added in this pass. No keyboard readout of enemy Omen or status, and no keyword key.
13. **Quit and resume (decided, sixth pass).** Quitting mid-fight and continuing replays the same encounter and shuffle on purpose (`docs/RULES.md`, "Saving and resuming").

## To do, in the order I would take it

1. **Hand-test an in-game update** before the next release: install v0.10.0, build v0.10.1 locally and update in
   game. It is the only check of the new `/DIR=` installer argument and the download stall watchdog against a real
   install and a real network (the tests cover their logic, not the installer).
2. **Release v0.10.1** (the 400 MiB cap and the review fixes, Chapter 3 still off): bump `config/version` and
   `export_presets.cfg`, then `scripts/release.ps1` (`docs/UPDATE_SIGNING.md`, "Every release").
3. **Playtest Chapter 3 and the finale** with Chapter 3 switched on locally (`Chapters.COUNT = 3`): the Scrivener's
   three phases, the finale's difficulty (bots say a little hard), the new events and cards.
4. **Release Chapter 3** (v0.11.0): `Chapters.COUNT = 3`, retune from the playtest, check with the sims.
5. **The Stray and Thief bots**: the greedy Thief bot reaches 0% in Chapter 3 (deck bloat) and the Stray has the
   widest gap between the two bots (`docs/SIM.md`); see whether the bots or the classes are at fault.
6. **Art polish**: the 960x320 `figure.png` portrait layers and the rest paintings (`art/PROMPTS.md`, "Touch-ups still
   open").

## Smaller open items

- Economy (gold, vendor prices) is untested beyond a back-of-envelope check.
- Relics: playtest the feel and prices; the bots buy relics but do not play around them, so sim numbers understate them.
- Save-scumming is intentional (see decision 13 above).
- A sim-bot card that refunds its own cost and draws (Borrowed Time, Seance) is skipped when the draw pile is smaller than the draw, to avoid a self-redraw loop.
- Repo size: see `docs/REPO_SIZE.md` for the options the maintainer has to decide on.
- Bigger ideas: more enemies, more events, an elite-only enemy set, map choices that reward risk (the branching map and a basic elite tier are done).

## How to run

- Play: open the project in Godot 4.7.2 and press F5.
- Full check: `powershell -ExecutionPolicy Bypass -File scripts/check.ps1`
- Sims: see `docs/SIM.md`.
