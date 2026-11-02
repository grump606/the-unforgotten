# Next steps

Last updated for v0.5.0, the "The Unforgotten" reskin (branch `reskin-unforgotten`, PR #1; not yet merged or released). It repaints the art, renames enemies and a relic, rewrites the story and restyles the menus, with no rule changes: see `docs/RESKIN.md` for the name map. Older notes below still use the original names (Brakeman = Bellkeeper, Conductor = Eraser). The latest published release is v0.4.0.

## State

- Three characters (Deserter, Pickpocket, Medium) with class cards, a neutral pool, a character select screen, a pause menu and save/resume.
- Classes plan: all seven phases done (infrastructure, select screen, the three classes' mechanics and cards, bots and balance, story). Per-character boarding, Conductor and Last Light beats live under `data/story/<id>/` with a neutral fallback (draft text, edit freely). Details: `docs/CLASSES_PLAN.md`.
- Card rewards: designs A and C are in (no repeats past 2 copies, skip pays 10 gold, free once-per-run Remove and Heal 12). See `docs/REWARDS_PROPOSAL.md`.
- Artwork (on `main` since v0.4.0, the `art-pipeline` branch is deleted): painted card art, backdrops, main menu and character select (`art/`), and a Slay the Spire style side-view battle stage with painted full-body sprites for the three classes and eight enemies (`docs/STAGE_DESIGN.md`). The art is AI-generated (ComfyUI, SDXL and a style LoRA; see `art/README.md`). The Wisp now has a painted sprite (v0.5.0). Still code-drawn: the rest and vendor figures and the neutral/standalone player cloak. Older code-drawn design notes: `docs/*_ART_DESIGN.md`, `docs/SCREEN_ART_DESIGN.md`.
- The damage preview on cards matches the damage actually dealt (shared `CardEffect.raw_damage`).
- Relics: 12 relics (3 per class, 3 neutral) sold one per vendor visit, so at most three per run (three vendors). Combat hooks, vendor stock, save support and code-drawn badges with a strip on the battle and run screens are in. Design: `docs/RELICS_DESIGN.md`, `docs/RELIC_ART_DESIGN.md`.
- Windows installer: `scripts/build_installer.ps1` builds `build/CardBattlePrototype-Setup-<version>.exe` (Inno Setup, upgrades in place, refuses downgrades). The repo is public (all rights reserved, no license), so the installer's GitHub update check works (tested against the live releases). Details: `docs/INSTALLER.md`. The latest release is v0.4.0 (painted art and the battle stage; earlier: v0.3.3 the polish pass, v0.3.2 the in-game update check, v0.3.0 the longer run and the Brakeman, v0.2.0 relics, the Back button and the installer), each published as a GitHub release with the setup exe attached. v0.4.0 also shipped a detached signature (`.sig`) that the in-game updater verified against the public key in `run/update_verifier.gd` (signing was switched off again in v0.5.0, see `docs/UPDATE_SIGNING.md`). The installer and exe are not code-signed (no budget for a certificate), so SmartScreen warns on first run. Saves from before the longer run are rejected.
- In-game update check (v0.3.2 onward): on launch the game asks the GitHub releases API once and, if a newer version exists, shows a notice with a Download button on the select and Continue screens. Silent on failure, skipped headless and when `CARD_BATTLE_NO_UPDATE_CHECK` is set. See `docs/UPDATE_CHECK.md`.
- CI: `.github/workflows/check.yml` runs the full check on every push and pull request (`docs/CI.md`); it has passed on GitHub. The pinned actions (`checkout@v5`, `cache@v5`) run on Node 24.
- Code structure: the run screen is split into per-screen scripts under `run/screens/` (`docs/RUN_SCREEN_STRUCTURE.md`). To ship a new version: bump `config/version`, run the build script, and `gh release create v<version> build/CardBattlePrototype-Setup-<version>.exe`.
- Every launch opens a main menu: Continue (only when a valid save exists), New Run and Exit. New Run opens the character select screen, whose Back button returns to the menu (the end card and the pause menu's New Run reach the same screen). The select cards were shrunk (deck card scale 0.5) so the panels sit comfortably in the window.
- The run is 21 stops: 8 regular fights, the Brakeman as a mid-boss at stop 9 (pays gold plus 15, offers a card, the run continues), the Conductor last, 3 vendors, 4 rests and story beats 0 to 3 (the "empty platform" beat now shows after the mid-boss). Regular fights ramp 1.2% HP and damage per fight number, so later fights are tougher. Old 12-stop saves are rejected cleanly. Design and results: `docs/LEVELS_DESIGN.md`.
- To make the longer line reachable the agent also changed `REST_HEAL` 24 to 36, Deserter max HP 47 to 52, Medium 41 to 56 and Conductor HP 108 to 96. A second balance pass then set Pickpocket max HP 34 to 36, Medium 56 to 60 and the Brakeman to 96 HP with a heavy attack of 18 (`docs/LEVELS_DESIGN.md`, "Second pass").
- Sim escape rates on the 21-stop line (600 runs, seeds 1 to 3 averaged): smart bot about 61 / 71 / 67% and greedy bot about 37 / 29 / 28% (Deserter / Pickpocket / Medium). Before the longer run they were smart 81 / 77 / 69% and greedy 52 / 47 / 47%.

## To do, in the order I would take it

0. **Playtest the reskin and the stage** (v0.4.0 stage, v0.5.0 art; includes the new stance animation, sprite facing and the five destination backdrops): sprite sizes and facing, attack lunges, hit reactions and enemy stagger timing, the intent and HP readouts, the log toggle, and the painted menu and select screens. Tune from what feels off (`Fighter` constants: `HEIGHTS`, `PLAYER_HEIGHT`, `ENEMY_GAP`, `LUNGE_TIME`; `battle.gd`: `ENEMY_STAGGER`).
0a. **Finish the art**: painted rest and vendor figures, then the Warden halberd and Conductor watch chain details. Pipeline notes are in `art/README.md`.
1. **Playtest each class** and say how it feels. The numbers are tuned against bots, not people. The greedy bot is probably the closer guide to a new player, and it now escapes about 29% as the Pickpocket and 28% as the Medium. Watch the Deserter (skill-sensitive) and the Medium (very HP-sensitive). Also check the Brakeman fight, the pause menu is centered in a normal F5 launch, and the new backdrop and screen scenes in motion.
2. **Retune from playtest feedback**: `REWARD_HEAL`, `HEAL_BELOW`, class HP, card costs. Use the sim to check any change.
3. **Remaining polish and balance items**:
   - Resolved in the second balance pass: greedy escape is in range for every class, and the unused tier 1 single pool is documented as reserved. Remaining: the smart bot almost never loses to the Brakeman (3.6 / 1.9 / 0.4% against a target of 8 to 15%), and the Medium cannot be raised by Brakeman numbers at all because Haunt and burst kill it first; every shape tried kept greedy loss at 3.5 to 7 times smart loss. A fix likely needs a Brakeman trait that counters Haunt (needs a combat rule) or human playtest data. The Pickpocket smart bot is marginally over 70% (70.8).
   - The Conductor figure in the story scene now uses his enemy portrait art (`run/conductor_figure.gd`); the platform coats keep the generic figure, and the end scenes have no figures.
   - Adding content: follow `docs/ADDING_CONTENT.md`. Tests now fail when a card, relic, enemy or character file is missing from its registry or an enemy has no `ART_KEYS` entry.

Done in the polish pass: a hovered card keeps its highlight after the hand rebuilds; the class tint on the battle backdrop is stronger (`TINT_AMOUNT` 0.32, halved on boss fights); the remove picker scrolls for big decks with Cancel always visible; per-character empty-platform beats; the Conductor story text now matches his skull face.

## Smaller open items

- The bots do not sequence the Pickpocket's per-play cards optimally, so that class's bot numbers may understate it.
- Several cards are rarely played by the bots (Spree, Pocket Watch, Seance, Spirit Tithe, Reckoning); worth a look if they feel weak in play.
- Save-scumming (quit mid-fight, Continue replays the stop) is intentional.
- Economy (gold, vendor prices) is still untested beyond a back-of-envelope check.
- Relics: playtest the feel and prices (Brass Token Purse is the bots' favorite at 50 gold); the bots only buy relics and do not play around them, so sim numbers understate them. The barbed-wire badge reads closer to a chain. Tooltips have not been seen in a real run. More relic sources (elites, a free pick after a fight) are an option.
- Bigger ideas: a branching map, more enemies and an elite tier (which could also drop relics).

## How to run

- Play: open the project in Godot 4.7.2 and press F5 (or launch `Godot_v4.7.2-stable_win64.exe --path .`).
- Full check: `powershell -ExecutionPolicy Bypass -File scripts/check.ps1`
- Sim: `godot --headless --path . -s res://tools/run_sim.gd -- --runs 600 --seed 1 --character deserter --policy smart --card-stats`
