# Balance and run simulations

How to run the two simulators and what they last measured. The figures here are a record of the day they were taken, not a promise: re-run the sims after any balance change. The line has since grown from 21 to 22 stops (a fifth rest before the finale, see [`GAME_FACTS.md`](GAME_FACTS.md)), so every "21-stop" number below was measured on the earlier line; the current line and map figures are in "Current figures" at the end. The tools accept `--character stray` (they take any id from `StarterContent.character_ids()`), and `--character all` plays the four classes in one invocation.

## Balance simulation (single fights)

`godot --headless --path . -s res://tools/balance_sim.gd -- --fights 500 --seed 1 --character deserter` plays N seeded fights (default 500, seed 1; `--character deserter|thief|medium|stray`, default deserter, picks whose max HP and starting deck the player uses) for each early encounter size (1 to 3 enemies) with a deterministic greedy policy (0-cost cards first, block when enemy intents out-damage current block, otherwise damage the lowest-HP enemy). It prints win rate, average turns, average player HP left on wins and stalls (fights over 50 turns) per size. Output is identical for identical arguments; invalid arguments print usage and exit with code 2. The player's HP and deck are the chosen character's real `max_hp` and `starting_deck` (not the 40-HP stand-alone battle's `extended_deck()`). Encounters come from `varied_encounter()` (the same content as the game): a lone enemy can be any type, a pair is the Gate Warden plus one small enemy (15% of pairs) or two small ones, and a trio is small enemies other than the Lost Shade (wisps, whisperers, cinder hounds, mourning crows). The Hollow Colossus only appears alone (it was unwinnable next to a second enemy in the sim). Early starting-deck fights are meant to be easy; difficulty comes from attrition across the (then) 21-stop line (see the run sim below), so there is no per-fight target. Measured with `--fights 2000 --seed 7` after the keep-5 hand change (before it, v0.6.5, in brackets): Deserter 99.8% / 98.9% / 96.3% wins with 1 / 2 / 3 enemies (96.9 / 96.8 / 88.0), Thief 99.8% / 95.0% / 98.0% (99.3 / 96.5 / 97.0), Medium 100% / 100% / 100% (unchanged), with no stalls. Before the change the hardest single fights were the Memorial Giant and the Threshold Keeper (about 77-80% for the Deserter and Thief); the Medium never loses an early fight (its Haunt and burst kill first).

The sim's policy plays an Expose card first when a damage card in hand can benefit, and prints a second table ("Win rate by enemy type": fights in which each enemy appeared, per encounter size) to show which enemy is over- or under-tuned. `--help` prints usage.

## Run-layer demo

How a run layer drives combat without changing it: `docs/RUN_INTEGRATION.md`. Throwaway demo: `godot --headless --path . -s res://tools/run_stub.gd -- --seed 1 [--character deserter|thief|medium|stray]`.

## Run simulation (whole runs)

`tools/run_sim.gd` plays many whole seeded runs through `RunState` and reports how winnable a run is: escape rate, where runs die (by stop index and description), average HP on arrival at each stop, and final HP and deck size on escapes. Run it with `godot --headless --path . -s res://tools/run_sim.gd -- --runs 300 --seed 1` (`--help` for usage; `--policy greedy|smart` picks the player model, default greedy; `--character deserter|thief|medium|stray` picks the character, default deserter; `--card-stats` also prints, per card, plays per run, the share of runs whose final deck held it and plays per run that held it, to check the bot really uses a class's cards; bad arguments exit 2; output is deterministic for equal arguments). Fights use the same Expose-aware greedy policy as `balance_sim.gd`, shared in `tools/sim_policy.gd`. After each win it takes the offered card that best fills what the deck lacks (damage or block) and never skips; at the vendor it heals if at least half a heal is missing, then buys the best-scoring cards it can afford and leaves. A fight past 50 turns is abandoned and counted as a stall. The policy is simple, so treat the escape rate as a lower bound for a human. On the (then) 21-stop line (600 runs, seeds 1 to 3 averaged) the greedy bot escapes about 32% (Deserter), 17% (Thief) and 25% (Medium) after the keep-5 hand change (it was 38 / 32 / 28 before; Brakeman/Mid-boss loss 24 / 25 / 2%, Conductor loss 32 / 53 / 54%); `docs/LEVELS_DESIGN.md` has the per-stop curve (measured before that change). The Bellkeeper Haunt cap (`max_haunt = 9` in `data/enemies/the_brakeman.tres`) moved the Medium smart bot's mid-boss loss from 0.6% to 11.2% and cost the Medium about 9 points of smart escape (65.8 to 56.9) and 1 of greedy (29.6 to 28.3), measured before the hand change (the Medium smart mid-boss loss is now 1.1%). The greedy bot understands the class cards (Block-scaled and per-play damage, Haunt count as attacks; it will not pay HP below a quarter of its max). It plays energy-refunding draw cards (Borrowed Time, Seance) first, unless the draw pile is too small (they would only draw themselves back), aims Reckoning at the most Haunted enemy and only once one is Haunted, and plays Spirit Tithe only when an enemy is Haunted and it is hurt. The smart bot counts a refunded energy as free.

`--policy smart` (`tools/smart_policy.gd`, heuristics documented in its header) is a stronger player model for judging balance at a second skill level. In combat it scores every playable card and target (killing blows, enemy threat per HP, block that exactly covers incoming damage, Expose before damage, energy spent well). For rewards and the vendor it scores cards against the deck's damage/block mix, skips a reward worse than the deck's average card, buys cards above that average, and removes the weakest card when affordable and clearly below average. It escapes about 63% (Deserter), 61% (Thief) and 70% (Medium) of runs after the keep-5 hand change (`--runs 600`, seeds 1 to 3 averaged; it was 61 / 71 / 57 before; Brakeman loss 1.9 / 2.0 / 1.1%, Conductor loss 14.6 / 1.3 / 15.2%), so treat greedy as a floor and smart as a near-ceiling for a skilled human. The bots keep the 5 best cards at end of turn (see "Hand and discard rules") and are not tuned for the new rule. Retaining cards shifted the classes unevenly (the Thief lost ground in both bots, the Medium gained in the smart one); that is left for review.


## Map mode (the default New Journey since v0.9.0)

New Journey plays the branching route map (`docs/MAP_DESIGN.md`, `docs/EVENTS_DESIGN.md`). The fixed line is still there behind `new_runs_use_map` in `run.gd` and is what `RunState` builds by default, so a sim without `--map` still plays the line.

- `tools/run_sim.gd --map` plays the map. `--route first|fighter|cautious|mixed|random|smart` picks the route strategy (`tools/route_policy.gd`) and is independent of `--policy greedy|smart`; without `--route` each policy keeps its own (greedy takes the first reachable node, smart its own `choose_route` rules). `--character all` plays the four classes, `--jobs N` splits the runs over N child processes (`--runs` stays below `SEED_STRIDE`; `MAX_RUNS` enforces it). With `--map` the report ends with the route strategy, the escape rate with its 95% Wilson interval, deaths by act and by row band (rows 0-4, 5-9 and so on), the mean HP on arrival at each boss, visits per run (fights, elites, rests, shops, chests, events), gold and relics held at the end, and the enemies per fight.
- `scripts/sim_matrix.ps1` runs every character x policy x route cell (one `run_sim` process per cell; `-Characters`, `-Policies` and `-Routes` override the defaults).
- `tools/threat_table.gd --seeds N` measures the budget packs (threat against the row budget, scale factors, redraws; `docs/MAP_DESIGN.md`, "Phase 4d").
- The node mix is measured by counting nodes over generated maps; the numbers and the weights behind them are in `docs/MAP_DESIGN.md` ("Phase 4h" and "Phase 5b").

## Current figures (2026-11-10)

Escape rate, 300 runs per cell, seed 1, all four classes, run with `--character all --jobs 4`. "With elites" is the map as shipped in v0.9.0 (elite weight 5.5, about 8% of the variable nodes, after the rest, shop and event tuning).

| | Deserter | Thief | Medium | Stray |
|---|---|---|---|---|
| Map with elites, greedy bot, `mixed` route | 58.7% | 57.0% | 42.7% | 68.3% |
| Map with elites, smart bot, `smart` route | 55.3% | 51.7% | 46.0% | 55.0% |
| Map before elites, greedy / `mixed` | 57.0% | 61.7% | 56.0% | 76.7% |
| Map before elites, smart / `smart` | 64.3% | 62.7% | 57.7% | 56.7% |
| 22-stop line, greedy | 62.0% | 58.7% | 44.0% | 55.0% |
| 22-stop line, smart | 67.3% | 68.7% | 68.7% | 71.0% |

- The 95% interval of one cell is about plus or minus 5 to 6 points, so differences under about 10 points between two cells are mostly noise.
- The greedy bot meets 1.5 to 1.8 elites per run on the `mixed` route, the smart bot 0.6 to 0.7 (it skips a fight when hurt). No stalls in any cell.
- Elites cost the Medium the most (about 11 points with both bots). Before elites the Stray differed by about 20 points between the greedy and smart bots (76.7% against 56.7%); that gap has not been looked into.
- An elite is 1.2 times the row's threat budget (`RunState.ELITE_BUDGET_MULTIPLIER`, 1.35 until 2026-11-10) and drops a relic and 20 gold; that multiplier is the first knob for the map's difficulty. The rows above are the 1.35 run; the 1.2 figures (greedy `mixed` 72.0 / 69.0 / 63.0 / 79.0%, smart `smart` 62.3 / 56.3 / 53.7 / 59.0%, Deserter / Thief / Medium / Stray) and the elite lethality are in `docs/MAP_DESIGN.md`, "Phase 5c". The `--map` report now prints `Elite lethality` and `Runs that fought an elite` lines.
- The line rows are the 22-stop line before the map became the default: the baseline for line mode, which players no longer see.

## Chapter 2 bot confirmation (2026-11-12, Gate 2 of `docs/CHAPTER2_PLAN.md`)

`tools/run_sim.gd --map --chapters 2 --seed 1 --runs 400 --jobs 4 --character <class>` with both policies, the Chapter 2 content as built (seven
enemies, two bosses, ten events, 24 cards and 7 relics, elite modifiers), with no script errors and no bot or engine errors logged. The target is
that a chapter's survival is about 15% lower than the previous chapter's, read relative, per class (mean of the greedy and smart bots; "survival" is
the share of runs that start the chapter and finish it).

| Class | Ch 1 survival (greedy / smart) | Ch 2 survival (greedy / smart) | Ch 2 mean | Target (0.85 x ch 1 mean) |
| --- | --- | --- | --- | --- |
| Deserter | 67.5% / 65.5% | 55.9% / 58.0% | 57.0% | 56.5% |
| Thief | 68.0% / 56.3% | 27.6% / 80.0% | 53.8% | 52.7% |
| Medium | 56.0% / 53.8% | 39.3% / 55.8% | 47.6% | 46.7% |
| Stray | 73.8% / 57.5% | 53.9% / 62.6% | 58.2% | 55.8% |

- **The class means are on target**, by `CHAPTER_2_CLASS_DIFFICULTY` (Deserter 1.11, Thief 1.28, Medium 1.135, Stray 0.90, on top of Chapter 1's class factors and the
  66 to 82 curve) and `CHAPTER_2_BOSS_FACTOR` (Stray 0.7). The Thief's two bots still disagree (greedy 28%, smart 80%): the greedy bot ends with a deck of about 47 cards.
  Use the smart bot as the Thief reference (`docs/CHAPTER2_PLAN.md`).
- **Bosses** (loss rate of those who reach them, 300 runs, mean of the four classes): the Archivist (170 HP) about 2 to 3%, the Registrar (165 HP) about 5%, against 3% and 0.5% for
  Chapter 1's Bellkeeper and Eraser. Both Chapter 2 bosses were first too weak (0%) at 120 and 130 HP.
- **Stalls** (a fight not finished in the 50-turn cap, the run counted lost): 0 for every class and bot except the smart Deserter, which loses about 1.5% of its runs
  (7 in 400) to the Archivist: a pure-Block deck cannot kill a 170-HP boss that Blocks 14 a cycle fast enough. At 210 HP it was 3%, so it is a long-fight effect and not a bug;
  a person would simply take longer.
- **Elite lethality** (share of elite visits that end the run, Chapters 1 and 2 together): greedy 18 to 27%, smart 13 to 24%, in line with Chapter 1 alone (about 9 to 14%)
  plus the harder Chapter 2 elites.
- **Chapter 3 is still a stub** (Chapter 1's content on a 84 to 100 curve) and has no confirmation.
