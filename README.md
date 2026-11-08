# The Unforgotten

> **Renamed (v0.6.0):** this project was called "Card Battle Prototype" and lived at `grump606/card-battle-prototype` (now a private backup). Old design docs may still use the original enemy and relic names; see [`docs/RESKIN.md`](docs/RESKIN.md) for the map. Saves and settings from every earlier version are moved into the new `The Unforgotten` user-data folder the first time the new version is installed or run, and the old folder is removed (see `docs/INSTALLER.md`).

A small turn-based card battler (afterlife-escape theme) built with Godot 4.7, GDScript, targeting Windows PC. You pick one of four characters and make your way down a fixed line of stops (fights, rests, vendors, story beats and two bosses) with a deck that grows from stop to stop; enemies repeat a fixed cycle of intents. How many stops, characters, relics and cards there are is in [`docs/GAME_FACTS.md`](docs/GAME_FACTS.md).

## Where to read more

- [`docs/README.md`](docs/README.md) - index of every design doc, marked current, shipped or historical.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) - the code layout: what lives in `combat/`, `run/`, `battle.gd`, `run.gd`, `tools/`.
- [`docs/RULES.md`](docs/RULES.md) - hand and discard rules, target modes, statuses, card keywords.
- [`docs/CARDS.md`](docs/CARDS.md) - the card list by class.
- [`docs/SIM.md`](docs/SIM.md) - the balance and run simulators and their last measured results.
- [`docs/NEXT_STEPS.md`](docs/NEXT_STEPS.md) - what is released, what is unreleased, what to do next.

## Run

Open the project in Godot 4.7 and press F5, or:

```powershell
& $env:GODOT --path .
```

On launch the game checks GitHub once for a newer release and turns the main menu's Update button red if there is one (click it to see the update bar, with Download and Skip; Skip turns the checks off); with the maintainer's two signing keys built in (`docs/UPDATE_SIGNING.md`) the notice offers Update & restart, which downloads, verifies and installs the new version itself (`docs/UPDATE_CHECK.md`); set `THE_UNFORGOTTEN_NO_UPDATE_CHECK=1` to turn that off (`docs/UPDATE_CHECK.md`).

A macOS build (a universal `.app` in a zip, not yet tested on a Mac) can be exported from the second preset in `export_presets.cfg`. It is not published with releases; see `docs/MACOS.md`.

### Debug: start in any fight

To test a boss or any enemy combination without playing down the line, launch straight into a fight (`run/debug_launch.gd`). It uses the character's real deck, never touches your save, and returns to the main menu when the fight ends:

```powershell
.\scripts\debug_fight.ps1 eraser                                  # final boss
.\scripts\debug_fight.ps1 bellkeeper -Character medium            # mid-boss
.\scripts\debug_fight.ps1 wisp,crow,hound -Character thief -Hp 20
.\scripts\debug_fight.ps1 list                                    # accepted enemy names
```

Or pass the options to Godot directly after `--` (`--fight=`, `--character=`, `--hp=`), or set `THE_UNFORGOTTEN_FIGHT`, `THE_UNFORGOTTEN_CHARACTER` and `THE_UNFORGOTTEN_HP`. Up to three enemies, any mix of regular enemies and bosses; names match the enemy id, its in-game name or a short alias (`eraser`, `bellkeeper`, `wisp`, `crow`, `hound`...).

The same launcher opens a shop or a rest stop with gold in hand and the player already hurt (defaults: 100 gold, 55% HP), so heals, purchases and card removal can be tried straight away. Nothing is saved in a debug session, including Pause > Save & Exit:

```powershell
.\scripts\debug_fight.ps1 -Screen vendor                          # the first shop
.\scripts\debug_fight.ps1 -Screen vendor:2 -Character medium      # the second shop
.\scripts\debug_fight.ps1 -Screen rest -Hp 10 -Gold 0
```

Directly: `--screen=vendor|rest[:n]`, `--gold=`, `--hp=` (or `THE_UNFORGOTTEN_SCREEN`, `THE_UNFORGOTTEN_GOLD`).

## Test

Full validation (import, unit tests, main-scene smoke load, every UI test; nonzero exit on any failure):

```powershell
$env:GODOT = 'path\to\Godot_v4.7.2-stable_win64_console.exe'   # optional
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

If `GODOT` is unset the script uses the console exe in the repo-local `Godot_v<engine version>_win64.exe` folder. The engine version is set once, in `scripts/engine_version.txt`. Each step has a timeout (300 s, `CHECK_STEP_TIMEOUT_MS` to change) so a hang fails instead of blocking. CI runs the same script on every push and pull request (`docs/CI.md`).

Unit tests only:

```powershell
& $env:GODOT --headless --path . -s res://tests/run_tests.gd
```

Expect `FAILURES: 0`. Test files are found automatically: a new `tests/<topic>_tests.gd` with a `run()` method, or `tests/ui_<topic>_test.gd`, runs with no registration. See [`tests/README.md`](tests/README.md).

## Add content

`docs/ADDING_CONTENT.md` is the tested procedure for cards, relics, enemies and characters (registries in `combat/starter_content.gd`, what `tests/content_tests.gd` checks, effect kinds are listed in `combat/card_effect.gd`). Add a test file for any new rule, and check the sim ([`docs/SIM.md`](docs/SIM.md)) for balance.

## Build and release

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_installer.ps1   # build/TheUnforgotten-Setup-<version>.exe (+ .sha256)
powershell -ExecutionPolicy Bypass -File scripts\release.ps1            # check, confirm CI is green, build and sign
```

Bump `config/version` in `project.godot` (and the matching lines in `export_presets.cfg`) first. The installer, its checksum, and the signed update manifest are published together as a GitHub release. Details: `docs/INSTALLER.md` (setup and what the installer does), `docs/UPDATE_SIGNING.md` (the signing key), `docs/UPDATE_CHECK.md` (how the game finds and installs updates), `docs/CI.md` (the pinned engine and the workflow).

## Repository

All rights reserved, no license. The repository holds only what the game and its tooling need (the source audio and the screen reference sheets are kept out of it); see [`docs/REPO_SIZE.md`](docs/REPO_SIZE.md).
