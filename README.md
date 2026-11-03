# The Unforgotten

> **Renamed (v0.6.0):** this project was called "Card Battle Prototype" and lived at `grump606/card-battle-prototype` (now a private backup). Old design docs may still use the original enemy and relic names; see [`docs/RESKIN.md`](docs/RESKIN.md) for the map. Saves from v0.5.1 and earlier still load.

A small turn-based card battler (afterlife-escape theme) built with Godot 4.7, GDScript, targeting Windows PC. The player fights 1 to 3 enemies with a deck of cards; enemies repeat a fixed cycle of intents.

## Layout

- `combat/` - rules only: no nodes, no scenes. `Combat` drives turns and emits signals; `CardPiles`, `Combatant`, `EnemyUnit`, `CardData`, `CardEffect`, `EnemyData` are the building blocks. `starter_content.gd` holds placeholder cards and enemies.
- `battle.gd` / `battle.tscn` - the combat UI. It observes `Combat` signals and calls `play_card` / the discard-step API (`begin_discard`, `toggle_discard`, `confirm_discard`, `cancel_discard`; see "Hand and discard rules"); it contains no rules. Run on its own (F6 on `battle.tscn`) it plays a random fight with a New Fight button; embedded by the run screen it shows a fight the run built and ends with Continue.
- `docs/RESKIN.md` - the v0.5.0 "The Unforgotten" presentation reskin: renamed enemies, new story and menu style, same rules and IDs (name map inside).
- `run/run_state.gd` - the run layer, rules only: a fixed 21-stop line (story, 8 regular fights, rests, 3 vendors, the Brakeman as a mid-boss halfway and a Conductor boss fight at the end; see `docs/LEVELS_DESIGN.md`) with the player's HP and deck carried from stop to stop. Wins pay gold and offer a pick-one-of-three card reward (the Conductor pays no gold and offers none; the Brakeman (shown in game as Bellkeeper) carries at most 9 Haunt stacks, `max_haunt` on `EnemyData`, so the Medium cannot Haunt it to death before it acts; the mid-boss pays gold plus a bonus and offers a card, and the run goes on; both bosses have a second phase at 50% HP, `phase_two_intents` on `EnemyData`, see `docs/ADDING_CONTENT.md`); rests heal 36; a defeat ends the run; passing the last stop escapes. Each run is played as a character (`run/character.gd`, `data/characters/`): the Deserter (52 HP), the Pickpocket (36 HP) or the Medium (60 HP), each with its own starting deck and a card pool of the neutral cards plus its own (a card's `character` tag; empty means neutral). Combat on its own, and the combat sim, use 40 HP. Class design: `docs/CLASSES_PLAN.md`. `run/vendor.gd` is the vendor visit (3 cards for sale, one relic, remove a card, heal; placeholder prices), `run/story_beat.gd` / `run/story_content.gd` + `data/story/` are the cutscene beats (four beats, all used by the line, with per-character versions of three). Relics (`combat/relic_data.gd`, `data/relics/`, `docs/RELICS_DESIGN.md`) are 12 passive items, bought one per vendor visit. New stop kinds are new `StopType` values plus one branch in `run.gd`.
- `run.gd` / `run.tscn` - the run screen (main scene, F5): a thin coordinator over `RunState` that embeds `battle.tscn` for combat stops; each other screen (character select, story, reward, vendor, rest, end card, pause menu) lives in its own script under `run/screens/` (see `docs/RUN_SCREEN_STRUCTURE.md`), and the animated code-drawn art is in `run/*_scene.gd`, `run/*_view.gd` (see `docs/*_ART_DESIGN.md`). Card effects (`combat/card_effect.gd`) are damage, block, draw, Expose, plus the Deserter's Hold (keep Block into the next turn), Block-scaled damage and thorns, the Pickpocket's energy gain and damage that grows with the cards played earlier in the turn, and the Medium's Haunt (damage over time), HP costs, healing and damage from Haunt. Every launch opens a main menu (Continue when a valid save exists, New Run, Exit, and a persisted "Check for updates" toggle); New Run opens a character select screen with a Back button (name, HP, pitch and starting deck for each). Between stops it autosaves to `user://run_save.json` (`run/run_save.gd`, format version 3: crash-safe via `.bak`/`.tmp` fallback, v2 saves migrate on load) and offers Continue on the main menu (a save is taken at the start of each stop, so quitting mid-stop and continuing replays that stop from its start: undoing a bad fight this way is intended); a Pause button (or Escape) opens a menu over an animated, code-drawn carriage backdrop (`run/pause_scene.gd`, with a detail per character) that freezes the fight and offers Continue, Save & Exit and New Run (with a confirmation); the end card summarises the run (outcome, stops cleared, HP, deck, gold).
- `tests/run_tests.gd` - headless rules tests (it also runs the content, run state, save, vendor, relic, mechanics and class test groups). `tests/smoke_main.gd` - loads and instantiates the main scene.
- `tests/ui_*.gd` - headless UI tests: the battle screen, whole runs driven through the real `run.tscn` buttons (`ui_flow_test.gd`), and each code-drawn view and scene.
- `scripts/check.ps1` - full validation: import, rules tests, smoke load and every UI test. Each step has a timeout (300 s, `CHECK_STEP_TIMEOUT_MS` to change) so a hang fails instead of blocking. CI runs it on every push (`.github/workflows/check.yml`, `docs/CI.md`).
- `installer/setup.iss`, `scripts/build_installer.ps1` - the Windows installer (`docs/INSTALLER.md`).

## Run

Open the project in Godot 4.7 and press F5, or:

```powershell
& $env:GODOT --path .
```

On launch the game checks GitHub once for a newer release and shows a dismissible notice if there is one; once a signing key is built in (`docs/UPDATE_SIGNING.md`) the notice offers Update & restart, which downloads, verifies and installs the new version itself (`docs/UPDATE_CHECK.md`); set `THE_UNFORGOTTEN_NO_UPDATE_CHECK=1` to turn that off (`docs/UPDATE_CHECK.md`).

### Debug: start in any fight

To test a boss or any enemy combination without playing down the line, launch straight into a fight (`run/debug_launch.gd`). It uses the character's real deck, never touches your save, and returns to the main menu when the fight ends:

```powershell
.\scripts\debug_fight.ps1 eraser                                  # final boss
.\scripts\debug_fight.ps1 bellkeeper -Character medium            # mid-boss
.\scripts\debug_fight.ps1 wisp,crow,hound -Character pickpocket -Hp 20
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

Full validation (import, tests, main-scene smoke load; nonzero exit on any failure):

```powershell
$env:GODOT = 'path\to\Godot_v4.7.2-stable_win64_console.exe'   # optional
powershell -File scripts\check.ps1
```

If `GODOT` is unset the script uses `Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` in the repo root.

Tests only:

```powershell
& $env:GODOT --headless --path . -s res://tests/run_tests.gd
```

Expect `FAILURES: 0`.

## Add content

`docs/ADDING_CONTENT.md` is the tested procedure for cards, relics, enemies and characters (registries in `combat/starter_content.gd`, what `tests/content_tests.gd` checks, effect kinds are listed in `combat/card_effect.gd`).

Add a test in `tests/run_tests.gd` (a `_test_*` function plus a call in `_initialize`) for any new rule, and check the sim (below) for balance.

## Hand and discard rules

- Turn 1 draws `Combat.HAND_SIZE` (5) cards. During a turn the hand holds at most `Combat.HAND_MAX` (10): every draw (a card's Draw, the first-play relic) stops at the cap and the rest stay in the draw pile (nothing is burned, and the discard pile is only reshuffled when the draw pile runs dry below the cap).
- End Turn opens an end-of-turn discard step (`Phase.DISCARDING`): click cards (or press their number keys, 0 is the tenth) to mark them for discard, then confirm. You may keep at most 5 cards; the confirm button is disabled ("Discard N more") until the hand is down to 5, and you may discard more than required or everything. Unmarked cards stay in your hand through the enemy phase (hand is no longer thrown away automatically). With 5 or fewer cards and nothing marked the button reads "Keep all", so the extra step costs one click (E, E on the keyboard). Back (or Backspace) returns to playing cards with the hand unchanged. An empty hand skips the step.
- The next turn draws back up to 5: `max(0, 5 - cards kept)`. Keeping 5 draws nothing; draws that turn can take the hand up to 10. Discards go to the discard pile; reshuffle rules are unchanged.
- API: `Combat.end_player_turn(discard_indices := [])` is the atomic form (validates, returns false with no change if an index is bad or duplicated or more than 5 cards would stay; with no argument it keeps the hand, valid only for 5 or fewer). `is_valid_discard`, `discard_required` and `can_confirm_discard` support UIs. Bots choose discards with `SimPolicy.discards_for` / `SmartPolicy.discards_for` (keep the 5 best by card score, never discard when 5 or fewer). The numbers `HAND_SIZE` and `HAND_MAX` are the two constants to change.
- Fights are not saved mid-fight (saves are taken at stop boundaries), so the save format is unchanged.

## Card target modes and statuses

A card's `target_mode` (in its `.tres`) is `0` single enemy (default, the selected enemy), `1` all enemies, or `2` self. Block- and draw-only cards should use self so they never need or name a target. An `EXPOSE` effect (`kind = 3`, `amount` = turns) makes the target take 1.5x damage, rounded down, applied before block.

## Balance simulation

`godot --headless --path . -s res://tools/balance_sim.gd -- --fights 500 --seed 1 --character deserter` plays N seeded fights (default 500, seed 1; `--character deserter|pickpocket|medium`, default deserter, picks whose max HP and starting deck the player uses) for each early encounter size (1 to 3 enemies) with a deterministic greedy policy (0-cost cards first, block when enemy intents out-damage current block, otherwise damage the lowest-HP enemy). It prints win rate, average turns, average player HP left on wins and stalls (fights over 50 turns) per size. Output is identical for identical arguments; invalid arguments print usage and exit with code 2. The player's HP and deck are the chosen character's real `max_hp` and `starting_deck` (not the 40-HP stand-alone battle's `extended_deck()`). Encounters come from `varied_encounter()` (the same content as the game): a lone enemy can be any type, a pair is the Gate Warden plus one small enemy (15% of pairs) or two small ones, and a trio is small enemies other than the Lost Shade (wisps, whisperers, cinder hounds, mourning crows). The Hollow Colossus only appears alone (it was unwinnable next to a second enemy in the sim). Early starting-deck fights are meant to be easy; difficulty comes from attrition across the 21-stop line (see the run sim below), so there is no per-fight target. Measured with `--fights 2000 --seed 7` after the keep-5 hand change (before it, v0.6.5, in brackets): Deserter 99.8% / 98.9% / 96.3% wins with 1 / 2 / 3 enemies (96.9 / 96.8 / 88.0), Pickpocket 99.8% / 95.0% / 98.0% (99.3 / 96.5 / 97.0), Medium 100% / 100% / 100% (unchanged), with no stalls. Before the change the hardest single fights were the Memorial Giant and the Threshold Keeper (about 77-80% for the Deserter and Pickpocket); the Medium never loses an early fight (its Haunt and burst kill first).

The sim's policy plays an Expose card first when a damage card in hand can benefit, and prints a second table ("Win rate by enemy type": fights in which each enemy appeared, per encounter size) to show which enemy is over- or under-tuned. `--help` prints usage.

## Run-layer contract

How a later run layer (map, vendors, rest sites, cutscenes) drives combat without changing it: `docs/RUN_INTEGRATION.md`. Throwaway demo: `godot --headless --path . -s res://tools/run_stub.gd -- --seed 1 [--character deserter|pickpocket|medium]`.

## Run simulation

`tools/run_sim.gd` plays many whole seeded runs through `RunState` and reports how winnable a run is: escape rate, where runs die (by stop index and description), average HP on arrival at each stop, and final HP and deck size on escapes. Run it with `godot --headless --path . -s res://tools/run_sim.gd -- --runs 300 --seed 1` (`--help` for usage; `--policy greedy|smart` picks the player model, default greedy; `--character deserter|pickpocket|medium` picks the character, default deserter; `--card-stats` also prints, per card, plays per run, the share of runs whose final deck held it and plays per run that held it, to check the bot really uses a class's cards; bad arguments exit 2; output is deterministic for equal arguments). Fights use the same Expose-aware greedy policy as `balance_sim.gd`, shared in `tools/sim_policy.gd`. After each win it takes the offered card that best fills what the deck lacks (damage or block) and never skips; at the vendor it heals if at least half a heal is missing, then buys the best-scoring cards it can afford and leaves. A fight past 50 turns is abandoned and counted as a stall. The policy is simple, so treat the escape rate as a lower bound for a human. On the 21-stop line (600 runs, seeds 1 to 3 averaged) the greedy bot escapes about 32% (Deserter), 17% (Pickpocket) and 25% (Medium) after the keep-5 hand change (it was 38 / 32 / 28 before; Brakeman/Mid-boss loss 24 / 25 / 2%, Conductor loss 32 / 53 / 54%); `docs/LEVELS_DESIGN.md` has the per-stop curve (measured before that change). The Bellkeeper Haunt cap (`max_haunt = 9` in `data/enemies/the_brakeman.tres`) moved the Medium smart bot's mid-boss loss from 0.6% to 11.2% and cost the Medium about 9 points of smart escape (65.8 to 56.9) and 1 of greedy (29.6 to 28.3), measured before the hand change (the Medium smart mid-boss loss is now 1.1%). The greedy bot understands the class cards (Block-scaled and per-play damage, Haunt count as attacks; it will not pay HP below a quarter of its max). It plays energy-refunding draw cards (Pocket Watch, Seance) first, unless the draw pile is too small (they would only draw themselves back), aims Reckoning at the most Haunted enemy and only once one is Haunted, and plays Spirit Tithe only when an enemy is Haunted and it is hurt. The smart bot counts a refunded energy as free.

`--policy smart` (`tools/smart_policy.gd`, heuristics documented in its header) is a stronger player model for judging balance at a second skill level. In combat it scores every playable card and target (killing blows, enemy threat per HP, block that exactly covers incoming damage, Expose before damage, energy spent well). For rewards and the vendor it scores cards against the deck's damage/block mix, skips a reward worse than the deck's average card, buys cards above that average, and removes the weakest card when affordable and clearly below average. It escapes about 63% (Deserter), 61% (Pickpocket) and 70% (Medium) of runs after the keep-5 hand change (`--runs 600`, seeds 1 to 3 averaged; it was 61 / 71 / 57 before; Brakeman loss 1.9 / 2.0 / 1.1%, Conductor loss 14.6 / 1.3 / 15.2%), so treat greedy as a floor and smart as a near-ceiling for a skilled human. The bots keep the 5 best cards at end of turn (see "Hand and discard rules") and are not tuned for the new rule. Retaining cards shifted the classes unevenly (the Pickpocket lost ground in both bots, the Medium gained in the smart one); that is left for review.
