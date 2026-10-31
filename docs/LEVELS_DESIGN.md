# Levels design: the long line

The run used to be 12 stops with four regular fights and the Conductor. It is now 21 stops in two acts: eight regular fights, a mid-boss (the Brakeman) exactly halfway, and the Conductor at the end. Later fights are measurably harder than earlier ones.

## The line

Defined in `RunState._default_line()`. Tier is the act (0 up to and including the mid-boss, 1 after it); fight is the 0-based number of a regular fight.

| Stop | Kind | Notes |
|---|---|---|
| 0 | Story, beat 0 | boarding |
| 1 | Combat, 1 enemy | fight 0 |
| 2 | Combat, 2 enemies | fight 1 |
| 3 | Rest | |
| 4 | Combat, 2 | fight 2 |
| 5 | Vendor | |
| 6 | Combat, 2 | fight 3 |
| 7 | Story, beat 1 | the Conductor glimpsed |
| 8 | Rest | |
| 9 | **Mid-boss: The Brakeman** | after the 4th regular fight, tier 0 |
| 10 | Story, beat 2 | the "empty platform" beat, now used; tier 1 starts here |
| 11 | Rest | recovery after the mid-boss |
| 12 | Combat, 2 | fight 4 |
| 13 | Combat, 3 | fight 5 |
| 14 | Vendor | |
| 15 | Rest | |
| 16 | Combat, 2 | fight 6 |
| 17 | Combat, 3 | fight 7 |
| 18 | Vendor | |
| 19 | Story, beat 3 | last light |
| 20 | **Final boss: The Conductor** | |

Eight regular fights, three vendors (up to three relics), four rests, beats 0 to 3 in order.

Deviation from the first sketch (rests at 8 and 13/17): the sim showed the Brakeman costs about 25 HP and, with no rest straight after it, the next pair (arriving at about 20 HP) lost 45 to 60 percent of runs. A rest at 11 fixes that. A rest at 17 (between the last trio and the Conductor) made the finale too soft and the second trio pair too punishing, so the second act's rest moved to 15, between the two fight pairs, and the vendor at 18 tops HP up before the Conductor.

## Mid-boss and boss rules

- `Stop.mid_boss` (bool), `Stop.tier` (int), `Stop.fight` (int). `Stop.describe()` returns "Mid-boss".
- `StarterContent.mid_boss_encounter()` is the Brakeman alone (`data/enemies/the_brakeman.tres`, not in `ALL_ENEMY_PATHS`).
- Beating the mid-boss pays `Vendor.gold_for_win(1)` plus `RunState.MID_BOSS_GOLD_BONUS` (15), offers a card reward, triggers relic win hooks, and the run continues. Losing ends the run.
- Beating the Conductor still pays nothing, offers nothing and ends the run. Relics stay vendor-only.
- Neither boss is stat-ramped; their numbers are hand-tuned.
- `RunState.complete_combat` treats a "victory" with a dead player as a defeat. `Combat._check_end` can report a victory when the final enemy dies to Thorns on the same enemy action that kills the player. The longer line made this reachable (the sim crashed on it); `combat.gd` itself was left untouched.

### The Brakeman

96 HP (was 90). Intent cycle: Block 14, Attack 13, Expose 1, Attack 18 (was 20). The Expose turn is followed by the heavy hit, so the 18 lands as 27 on an unprepared player. Tougher than any regular enemy (Colossus 74 HP, 20 damage) and no more HP than the Conductor (a test pins this, so the Conductor stays at 96).

### The Conductor

Retuned from 108 HP to 96 HP (attacks unchanged at 19 and 13, Block 10, Expose 2, 13). Arriving with less HP than before (the line is longer and the last trio comes just before) made the old 108 HP version a wall for the Deserter and Medium; HP was the least damaging knob to turn.

## Progressive difficulty

1. **Tier-aware pools** (`StarterContent.varied_encounter(count, rng, tier = 0, fight = 0)`): tier 1 raises the chance that a pair is Gate Warden plus a small enemy from 15% to 20% (`TIER1_BIG_PAIR_CHANCE`). Singles use the same pool at every tier (the line has no single-enemy fight in act 2, and the old reserved tier-1 single list was removed). The random draws are identical in number and order to tier 0, so seeds stay in step.
2. **Stat ramp**: `StarterContent.ramp_factor(fight) = 1 + 0.012 * fight`, applied by `StarterContent.scaled()` to a regular encounter's max HP and DAMAGE intents, rounded, minimum 1. Block and statuses are not scaled. It builds new `EnemyData` and `CardEffect` objects, so shared resources and the global RNG are untouched. Fight 0 is x1.00, fight 7 is x1.084.

Why such a small ramp: the combat numbers are on breakpoints (a Shove does 6, a Wisp has 16 HP, the small enemies hit for 3 to 9). The sim showed 7 percent per fight (fight 7 at x1.49) took the Deserter's escape rate to 0.2 percent, 3.5 percent to about 45 percent trio loss rates, and even 2 percent per fight (x1.14) pushed the fight-5 trio from 10 to 26 percent loss. Most of the felt difficulty comes from attrition (HP carried across eight fights) and the act-2 pools; the ramp is a gentle nudge on top.

## Balance changes (with reasons)

| Change | Was | Now | Why |
|---|---|---|---|
| `REST_HEAL` | 24 | 36 | The line has twice the fights between recoveries; a rest after the mid-boss must restore a real fraction. |
| Deserter max HP | 47 | 52 | Same attrition argument; the Deserter was the class that wore down fastest in act 2. |
| Medium max HP | 41 | 56 | The Medium is the most HP-sensitive class (see NEXT_STEPS); at 41 HP it escaped about 0 to 16 percent of runs. |
| Pickpocket max HP | 34 | 34 | Unchanged in the first pass: it already sat at the top of the target band. |
| Conductor HP | 108 | 96 | See above. |
| `MID_BOSS_GOLD_BONUS` | n/a | 15 | The mid-boss is the biggest fight so far; it pays like a trio plus a bit. |

Second balance pass (greedy-bot escape and the Brakeman), see "Second pass" below: Pickpocket max HP 34 to 36, Medium max HP 56 to 60, Brakeman HP 90 to 96 and heavy attack 20 to 18.

Gold and prices were not changed: fights pay 13, 21 or 29 gold, a run has eight of them plus the mid-boss bonus, and three vendors sell relics at 50 to 75. The bots buy a relic at the second or third vendor in almost every run that gets that far (smart: 464/600 Deserter, 388/600 Pickpocket, 495/600 Medium bought at least one), so the economy does not choke. Deck growth (a reward every fight) does not trivialise the end: the greedy bot, which never skips, ends escapes with 25 cards and still loses 20 to 60 percent of Conductor attempts, and the smart bot holds a thin 11 to 15 card deck.

## Results

600 runs per cell, seed 1. Before is the old 12-stop line (commit `0cf23fb`), after is this change.

| Escape rate | Deserter | Pickpocket | Medium |
|---|---|---|---|
| Smart, before | 81.2% | 76.5% | 68.7% |
| Smart, after | 58.3% | 59.5% | 56.8% |
| Greedy, before | 52.0% | 46.5% | 46.7% |
| Greedy, after | 32.7% | 19.8% | 21.2% |

Targets were smart 55 to 70 percent and greedy 25 to 40 percent. All three smart rates are in range. Greedy is in range for the Deserter and a few points under for the Pickpocket and Medium; it has no lookahead, so it gains least from the longer line's extra cards and loses most to the Brakeman's Expose.

Loss rate per fight (percent of runs that reached the stop), smart bot:

| Stop | 1 | 2 | 4 | 6 | 9 Mid-boss | 12 | 13 | 16 | 17 | 20 Conductor |
|---|---|---|---|---|---|---|---|---|---|---|
| Deserter | 0.2 | 3.0 | 1.2 | 1.7 | 10.1 | 2.8 | 10.1 | 1.4 | 5.5 | 15.3 |
| Pickpocket | 2.7 | 10.1 | 6.1 | 4.5 | 9.6 | 3.3 | 10.0 | 0.5 | 2.4 | 0.8 |
| Medium | 0.0 | 0.7 | 0.0 | 1.7 | 2.7 | 1.9 | 12.5 | 0.8 | 9.1 | 22.7 |

Greedy bot:

| Stop | 1 | 2 | 4 | 6 | 9 Mid-boss | 12 | 13 | 16 | 17 | 20 Conductor |
|---|---|---|---|---|---|---|---|---|---|---|
| Deserter | 1.8 | 6.6 | 2.4 | 2.2 | 37.1 | 3.9 | 12.6 | 2.5 | 8.5 | 20.6 |
| Pickpocket | 1.8 | 9.0 | 3.4 | 6.9 | 36.5 | 5.2 | 15.5 | 6.9 | 14.0 | 39.3 |
| Medium | 0.0 | 2.3 | 0.7 | 2.4 | 2.8 | 2.7 | 29.6 | 1.1 | 20.3 | 57.4 |

Reading the curve:

- Within each act the loss rate climbs from the first fight to the trio, then resets after a rest; fights that follow a rest (12 and 16) start from full HP, so the trio that follows them (13 and 17) shows the true pressure. Act 2 trios lose 5 to 30 percent against 1 to 3 percent for act 1's strongest fight; there is no cliff at the mid-boss.
- The Conductor is the hardest fight for the Deserter and Medium with both bots. The Pickpocket breezes through it with the smart bot (0.8 percent: a burst class with a relic in 92 percent of runs); that is class balance, not line balance, and is open for a later pass.
- Mid-boss losses for the smart bot are 10 percent (Deserter), 10 percent (Pickpocket) and 3 percent (Medium, whose Haunt plan beats a slow, blocking boss). The greedy bot loses 37 percent to the Brakeman as the Deserter and Pickpocket because it never plays around Expose.
- The sim is very breakpoint-sensitive: moving the Brakeman by one HP point and one damage point moved the Deserter's mid-boss loss between 4 and 23 percent. Treat the numbers as tuned against these bots only; the next step is a human playtest.

## Second pass: greedy escape and the Brakeman

Goal: greedy escape 28 to 40 percent and smart 55 to 70 for every class, Brakeman loss smart 8 to 15 percent and greedy at most about 25, no cliff. Judged over seeds 1 to 3, 600 runs per cell (averages below; movements under about 3 points are noise). Stop line, bots, combat rules and cards untouched.

Changes: Pickpocket max HP 34 to 36, Medium max HP 56 to 60, Brakeman HP 90 to 96 and heavy attack 20 to 18. Conductor, `REST_HEAL`, gold and prices unchanged.

| Escape rate (seeds 1-3 avg) | Deserter | Pickpocket | Medium |
|---|---|---|---|
| Smart, before | 58.0% | 61.4% | 57.1% |
| Smart, after | 61.0% | 70.8% | 67.3% |
| Greedy, before | 32.8% | 20.3% | 21.1% |
| Greedy, after | 36.8% | 28.9% | 27.7% |

| Loss at the stop | Deserter | Pickpocket | Medium |
|---|---|---|---|
| Brakeman, smart, before / after | 9.2 / 3.6 | 9.2 / 1.9 | 1.9 / 0.4 |
| Brakeman, greedy, before / after | 36.1 / 26.7 | 35.9 / 21.2 | 3.4 / 1.4 |
| Conductor, smart, before / after | 13.4 / 13.7 | 1.1 / 0.6 | 24.0 / 19.9 |
| Conductor, greedy, before / after | 20.7 / 23.1 | 40.6 / 37.4 | 57.9 / 52.1 |

Experiment log (seed 1, escape smart/greedy for Deserter, Pickpocket, Medium; Brakeman loss smart/greedy):

| # | Lever | Result |
|---|---|---|
| 0 | baseline | esc 58/33, 60/20, 57/21; Brakeman 10/37, 10/37, 3/3 |
| 1 | Brakeman 105 HP, heavy 16 | Deserter 65/44, Pickpocket 64/22, Medium 58/23; Brakeman 2/15, 4/28, 1/3 (smart almost never loses) |
| 2 | Brakeman 130 HP, heavy 16 | Brakeman 15/54, 14/53, 3/-: smart in range, greedy far over. Medium unmoved by HP |
| 3 | Brakeman block 14 to 28 | no change at all for the Medium (Haunt and burst ignore the block turn) |
| 4 | Brakeman plain attack 13 to 20 | Brakeman Deserter smart 45 percent, Medium only 8: the Medium cannot be raised without wrecking the others |
| 5 | Conductor HP 96 to 84 | esc 62/35, 60/24, 63/27; Conductor greedy 21/39/57 down to 15/27/46 |
| 6 | Pickpocket HP 34 to 40 / 38 / 36 | smart 79 / 74 / 69, greedy 46 / 38 / 30: very HP sensitive, 36 chosen |
| 7 | Brakeman 112 HP heavy 16 / 100 HP heavy 18 / 104 HP heavy 17 / 100 HP 16+16 | Deserter greedy Brakeman 23 / 33 / 19 / 35, smart 4 / 7 / 4 / 7; the greedy/smart loss ratio stays at 3.5 to 7 whatever the shape |
| 8 | Conductor Expose 2 to 1 | no change (Expose on the Conductor only touches one hit anyway) |
| 9 | Conductor attacks 19/13 to 17/12 (HP 96) | like lever 5 but Deserter greedy 42, over range |
| 10 | Conductor back to 96, Brakeman 96 HP heavy 18, Medium HP 56 to 60 (final) | esc 62/37, 70/28, 67/29 |
| 11 | variant: Pickpocket 35, Medium 62 | Pickpocket 65/24.5, Medium 70/34: Pickpocket greedy too low, Medium smart at the ceiling |

Why the Conductor stayed at 96: a test requires the Brakeman not to out-HP the Conductor, and the Brakeman needs about 96 HP to keep the Deserter and Pickpocket greedy loss near 25. Class HP gives the greedy bot its margin instead.

Result against the goals:

- Greedy escape: 36.8 / 28.9 / 27.7. All in or at the edge of 28 to 40 (the Medium is 0.3 under, inside noise).
- Smart escape: 61.0 / 70.8 / 67.3, in range, the Pickpocket marginally over 70. One HP point either way trades about 4 points of smart for 3 of greedy for that class, so it was left.
- Brakeman, greedy: 27 / 21 / 1 percent, about 25 for the Deserter, under for the Pickpocket (was 36 for both).
- Brakeman, smart: 3.6 / 1.9 / 0.4 percent, BELOW the 8 to 15 target. Not reached on purpose: across every Brakeman shape tried the greedy loss was 3.5 to 7 times the smart loss, so smart at 8 percent meant greedy at 30 to 50. The Medium cannot be raised at all by Brakeman numbers (HP 130, block 28 changed nothing; raising damage to hit 8 percent put the Deserter at 45). The Medium's Haunt and burst kill the Brakeman before its damage matters, and the only Medium-specific lever (lower max HP) would hurt its greedy escape. Needs a class-aware answer (a Brakeman trait that counters Haunt) rather than numbers.
- Curve: per-stop loss still rises within each act with no cliff; the Conductor is the hardest fight for the Deserter and Medium, and the Pickpocket (as before) breezes through it with the smart bot.
- Singles have no tier-1 pool (the reserved list was removed; add one when act 2 gets a single).

## Saves

`RunSave.line_signature` now records `type:enemy_count:beat:boss:mid_boss:tier` per stop. A save from the old 12-stop line has a different signature and is rejected with "save is from a different stop line", which the game reports as "could not be loaded", rather than pointing `stop_index` at a different stop. The signature was the guard when the save version was 2 (the version is now 3; see `RunSave.migrate`).

## Tools

`tools/run_sim.gd` prints a loss percentage column per stop in its per-stop table. Command used for the results: `godot --headless --path . -s res://tools/run_sim.gd -- --runs 600 --seed 1 --character <id> --policy <smart|greedy>`.
