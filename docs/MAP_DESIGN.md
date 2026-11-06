# Selectable route map: design

Replaces the fixed 21-stop line with a branching map the player chooses a path through. This document is the spec;
`docs/LEVELS_DESIGN.md` describes the line it replaces. Work proceeds in phases, one small PR each, on the
`map-route` integration branch.

## Shape

- A run is two acts of 15 rows each, 30 rows in all. The last row of each act is its boss (the Bellkeeper ends act 1,
  the Eraser ends act 2). A path through the map takes exactly one node per row, so every path is 30 stops.
- Each row holds 1 to 4 nodes. Rows with one node are choke points that every path passes through.
- Node types: fight, elite fight (supported by the data model; weight 0 until phase 5), rest, shop, treasure, story
  beat, mid-boss, boss.
- A rest or shop takes the place of a fight in its row. They are ordinary branches: a path that never picks one never
  sees one. Only the story beats, the two bosses and the forced rest row before each boss are on every path.

## Row layout

| Act | Row(s) | Content |
|---|---|---|
| 1 | 0 | Story beat 0 (boarding). One node. |
| 1 | 1 to 11 | Free rows (3 to 4 nodes). Rows 1 to 3 are all fights. Row 6 is the forced treasure row (every node a chest). Row 11 holds no rest. |
| 1 | 12 | Forced rest row (3 to 4 nodes, every one a rest). |
| 1 | 13 | Story beat 1 (the Bellkeeper's hall). One node. |
| 1 | 14 | Mid-boss. One node. |
| 2 | 0 to 11 except 3 | Free rows (3 to 4 nodes). Rows 0 to 2 are all fights. Row 7 is the forced treasure row (every node a chest). Row 11 holds no rest. |
| 2 | 3 | Story beat 2 (the garden). One node. |
| 2 | 12 | Forced rest row (3 to 4 nodes, every one a rest). |
| 2 | 13 | Story beat 3 (the Eraser). One node. |
| 2 | 14 | Final boss. One node. |

That is 4 story beats, 2 bosses, 20 plain free rows, 2 forced treasure rows and 2 forced rest rows per run, the same story
order as the line (phase 4b added the treasure rows by turning two of the free rows into chests; see "Phase 4b").
The forced rest row (`RouteMap.FORCED_REST_ROW`, local row 12) is a fairness anchor: every path rests once before
each boss, whatever else it skipped. It is built and connected like any other free row.

## Edges

- Every node has at least one edge to the next row and at least one from the previous row (except the first and last).
- A node connects to 1 or 2 nodes of the next row whose column is within one of its own. Edges never cross.
- A one-node row connects to every node of the next row, and every node of the row before it connects to it.

## Node types in free rows

- Weights per free node (tuning values, kept in one config dictionary `RouteMap.CONFIG`): fight 26, rest 18, shop 7,
  elite 0 (until phase 5). The first 3 free rows of an act are all fights, and an elite never appears there. The
  forced rest row ignores the weights (all rests) and the row before it rolls with the rest weight at zero. Because
  the safe rows and the adjacency rule add fights, the weights are not the resulting mix: they give about 68% fights,
  23% rests (the forced rows included) and 9% shops of all free nodes, and a random path per act of about 8.3 fights,
  2.7 rests (one of them the forced one) and 1.1 shops. An elite config (weight 14) still validates and keeps elites out
  of the first 3 free rows and out of the forced row; it stays 0 by default.
- Adjacency: a rest, shop or elite may not follow a node of the same type on any incoming edge. A blocked type is
  taken out of that node's roll and the remaining weights are used as they are (one roll), so a blocked rest
  turns into a fight, shop or elite in proportion to their weights, not always into a fight.
- Apart from the forced rest row the generator guarantees nothing per path. It guarantees map-level availability: in
  each act every run of 6 consecutive free rows contains at least one rest node and every 8 consecutive free rows at
  least one shop node, placed so the choice is real (not forced). Windows only count free rows at or after the safe
  rows and before the forced rest row: rest windows end at free row 9 of the act (free row 10 cannot hold a rest and
  free row 11 is the forced row), shop windows at free row 10. The forced row counts as satisfying the rests after the
  last window and is exempt from the "no rest after rest" rule (the row before it has none anyway).
- `validate()` reports: a forced-row node that is not a rest; a rest in the row before the forced row; any path that
  reaches a boss without a rest since the start or the previous boss.

## Enemy count

Outside boss fights the number of enemies is random, rolled when the map is generated and stored on the node
(`enemy_count`, 1 to `Combat.MAX_ENEMIES`). Bosses and the mid-boss are always 1. Weights depend on the row within the run:
early rows (row index 0 to 7 of the run) 1: 50%, 2: 40%, 3: 10%; middle (8 to 21) 1: 25%, 2: 50%, 3: 25%; late (22 to 29)
1: 10%, 2: 40%, 3: 50%. Elites are never 1. Non-fight nodes have `enemy_count` 0. (Pack strength per count is a
later phase.)

## Fight backdrops

Regular fights reuse the existing battle backdrops, assigned at generation and stored on the node as `backdrop`
(a screen key such as `battle_street`):

- Pool: `battle_street`, `battle_garden`, `battle_archive`, `battle_<character id>`, `battle_neutral`.
- The mid-boss uses `battle_bell_court` and the final boss `battle_threshold`; those two keys are never in the pool.
- A fight may not use the same backdrop as the most recent fight on any path leading into it. Walk back through any
  rest, shop or story nodes on each incoming path to the previous fight and take its backdrop; all those must differ
  from the new node's. The pool is not always large enough for one greedy pass: a story node after a 4-wide row
  passes all of that row's backdrops on to the fights behind it, and a rest beside a fight adds one more, which can
  leave no legal key in the pool of 5 (or of 4). The pass re-rolls up to 60 times, then falls back to the least
  recently used key and the validator reports the repeat (the generator then retries the whole map).
- A character id outside `BattleBackdrop.TINTS` (including an empty one) has no key of its own, so its pool is the
  three shared keys plus neutral. A boss key can never enter the pool.
- Rest, shop and treasure nodes have no backdrop; they keep their one fixed painting. The walk back to the previous
  fight passes through a treasure row like any other non-fight node.

## Determinism

`RouteMap.generate(seed, character_id, config)` uses its own seeded `RandomNumberGenerator`, never the run's. The same
arguments give an identical map. The map is plain data (`to_dict` / `from_dict`) so a later phase can save it.

## Phases

1. Graph, generator, validator and tests. Nothing in the game uses it yet, so play is unchanged. A straight-line
   adapter turns today's 21-stop line into a one-node-per-row map so the old layout stays expressible.
2. Map screen and navigation; the run follows the chosen path; row-keyed ramp and backdrop.
3. Save format 5: map runs can be saved and resumed. Old saves stay line runs (no migration; the map is opt-in).
4. Threat-budget packs for random counts, route-choosing bots, and a rebalance for the 30-stop length.
5. Elites (new tougher packs, relic reward).
6. Balance pass and docs.
7. Treasure nodes (phase 4b, below), then event nodes.

## Phase 1 (built)

`run/route_map.gd` (`class_name RouteMap`) holds the node data (`RouteMap.MapNode`), the graph and queries
(`node`, `next_ids`, `previous_ids`, `row_nodes`, `starts`, `finals`, `path_count`, `all_paths`), the tuning
dictionary `RouteMap.CONFIG`, `generate(seed, character_id, config)`, `validate()` (a list of broken rules, empty
when valid), `to_dict()` / `from_dict()` and `from_line(stops)`. `RouteMap.NodeType` is its own append-only enum.
Nothing in the game uses it yet; `tests/route_map_tests.gd` covers determinism, structure, the type, availability,
enemy-count and backdrop rules over many seeds, the validator against deliberately broken maps, the round trip,
hostile data, config shapes, the node mix and the line adapter.

Loading and config are defensive. `from_dict` returns null for data that is not well formed (wrong types, an unknown
kind or node type, a row outside the map, a column over 15, more than 1000 nodes, an edge to a missing node, a config
of the wrong shape); rule breaks inside well-formed data are left to `validate()`, which also reports an unknown
kind. `make_config` / `generate` ignore a config entry of the wrong shape or range and use the default for it
(`RouteMap.config_problems()` lists them); `free_widths` must be whole numbers from 2 to 5 that differ by at most 1.
`backdrop_pool(character_id)` is static.

Measured node mix (2400 default maps, 600 per character, free nodes only, elites off; these are the phase 1 figures, superseded by the Phase 4a section below). Before the retune the weights
were fight 55 / rest 20 / shop 10 with rest and shop windows of 4 and 6 counted from the first free row:

| | before | after |
|---|---|---|
| fight / rest / shop share of free nodes | 76.7% / 14.6% / 8.7% | 63.0% / 23.9% / 13.2% |
| random path, fights (mean) | 18.5 | 15.45 (min 8, p10 13, p90 18, max 23) |
| random path, rests (mean) | 3.4 | 5.47 (min 1, p10 4, p90 7, max 10) |
| random path, shops (mean) | 2.05 | 3.07 (min 0, p10 1, p90 5, max 8) |
| most rest-heavy path, rests (mean per map) | | 8.33 (p10 7, p90 9, max 10) |
| most shop-heavy path, shops (mean per map) | | 6.02 (p10 5, p90 7, max 9) |
| maps where every path holds a rest | 41.5% | 92.8% |
| maps where every path holds a shop | 11.6% | 35.3% |
| longest run of rows offering no rest | | mean 6.45, p90 7, max 9 |

The path rows are 6 random walks per map (each exit equally likely); the heavy-path rows are exact (a dynamic
programme over each map's paths). The map generator takes about 5 ms per map and `validate()` found no failure.
"Every path holds a rest" is now caused by the density of rests (about 1 in 4 free nodes), not by a repair forcing
one into a single row, and a rest is still skippable only by routing around rests row by row; if that proves too
tight in play, lower the rest weight or widen `free_widths`. The mix cannot reach fight 55 / rest 22 / shop 12 exactly
(those add up to 89, the rest being the elite share): with elites off the fights take that share, so a random path
has about 15 fights instead of 13 to 14. With elite weight 14 the mix is 57 / 21 / 10 / 11 and a random path has 13.9
fights, 4.9 rests and 2.5 shops.

How skippable they are (same 2400 maps, exact over each act's paths; acts are separate because both end in a boss
that every path passes through, so the run figures are the sums):

| Per act (act 1 / act 2) | rests | shops |
|---|---|---|
| fewest on any path (the skip-everything route), mean | 0.91 / 0.95 | 0.19 / 0.21 |
| fewest, p10 / p50 / p90 | 0 / 1 / 2 | 0 / 0 / 1 |
| maps with a path of none | 28.2% / 26.8% | 81.0% / 79.0% |
| most on any path (the cautious route), mean | 4.16 / 4.17 | 2.97 / 3.04 |
| most, p10 / p50 / p90 | 4 / 4 / 5 | 2 / 3 / 4 |
| random path, mean | 2.73 / 2.75 | 1.52 / 1.55 |
| longest run of free rows with none on offer: mean, p90, max | 3.1 / 3.1, 3, 5 | 4.1 / 3.9, 6 / 5, 10 / 9 |

Over the whole run the skip-everything route sees 1.86 rests on average (7.2% of maps allow none) and 0.41 shops
(64.7% allow none); the cautious route sees 8.33 rests and 6.02 shops. The runs without a rest are at most 3 free rows
in most acts because the 3 safe rows count. The windows barely matter at these weights (a rest window of 6 gives the
same figures to within noise): the node density sets how avoidable they are, so no retune was needed for the
skippability targets.

Choices where the spec left room:

- "Consecutive free rows" are consecutive in the act's list of free rows, so the act 2 story row (row 3) does not
  break a window. A window only spans free rows at or after the 3 safe rows (the first one covers free rows 3 to 6 for
  rests, 3 to 10 for shops), so the repair never fires inside the opening and does not pin a rest to one row.
- Availability is applied as each row is rolled: a fight of the row that closes an empty window becomes the rest or
  shop, so the choice is real. Every free row also keeps at least one plain fight. A repair converts a plain fight
  (if the row has a spare one), else an elite, else a node of the other special type, and only one whose loss leaves
  the other type's window ending in this row satisfied; if no node qualifies, the generator's validate-and-retry
  loop is the backstop. If all 20 attempts fail, `generate` pushes an error and returns the last map.
- Out-degree is 1 or 2 and in-degree is capped at 2 between free rows; a one-node row links to every node on either
  side regardless of columns.
- A story node after a 4-wide row passes all of that row's backdrops on to the fights behind it, which with a
  neighbouring fight can leave the pool of 5 empty; the backdrop pass re-rolls (up to 60 times) before it would
  accept a repeat, and the validator reports any repeat that remains.
- `from_line` maps COMBAT stops to fights, the mid-boss and boss flags to MID_BOSS and BOSS, VENDOR to SHOP, and
  validates only the graph shape and enemy counts (the 21-row line is not the generated layout).


## Map screen

Files: `run/map_view.gd` (`MapView`, the drawing and input), `run/screens/map_screen.gd` (`MapScreen`, the glue to
a run), `tools/map_sheet.gd` (screenshots), `tests/ui_map_test.gd`.

- `MapView` is a pure presentation `Control`: `set_data(route, visited, current, reachable, character_id)` and
  `signal node_chosen(node_id)`; `set_status(text)` sets the line at the right of its header strip. It shows one
  act, left to right (one column per row, up to 4 nodes tall), the act of the next choice (else of the current
  node), and scales from the window size (laid out for 1152x648). It draws its own header strip (act, "Row 7/15",
  the status text), a dimmed painted backdrop (`BACKDROP_SCREEN`, falling back to a dark panel), inked edges
  (bright for the path taken, pulsing from the current node to its choices, faint otherwise), glyph nodes (crossed
  blades for fights with 1 to 3 pips for the enemy count, horned blades for elites, an armchair for rests, coin for shops,
  open book for story beats, bell for the mid-boss, eye for the final boss) and a legend. Visited nodes are dimmed with
  a tick, the
  current node is ringed, reachable ones pulse; hovering any node shows a label ("Fight: 2 enemies", "Rest", "Shop",
  "Story: <beat title>", "Mid-boss", "Final boss").
- `MapScreen` is a `RunScreen`: run.gd attaches it like the others and calls `show_map(run)`, which builds the view
  from `run.route`, `run.visited`, `run.current_node` and `run.reachable_nodes()`. `node_chosen(node_id)` is
  re-emitted; run.gd calls `run.choose_node(id)`. The status line is left empty: run.gd's own header above the map shows the
  character, HP, gold and deck, and its "Journey n/30" counts the row being chosen (matching the view's "Row n/15"). `present(...)` does the same from plain data (used by the test and
  the screenshot tool).
- Controls: click a reachable node to choose it; Left/Right (or Up/Down) cycle the reachable choices and Enter or
  Space chooses the selected one (ringed while the view has focus). Unreachable, visited and current nodes cannot be
  chosen.
- Screenshots: `godot --path . -s res://tools/map_sheet.gd -- <out dir>` (needs a window, not `--headless`).

## Phase 2: state and flow

RunState gets an opt-in map mode. Off by default: `RunState.new(seed, character)` is the fixed 21-stop line, unchanged
(saves, bots and tests included). `RunState.new(seed, character, true)` builds `route = RouteMap.generate(seed,
character.id)`, which uses its own RNG, so the run's `_rng` sequence is identical in both modes at construction.

API:

- `var route: RouteMap` (null in line mode) and `uses_map()`.
- `var current_node: int` (-1 before the first choice) and `var visited: Array[int]` (node ids in order).
- `reachable_nodes() -> Array[int]`: the start nodes before any choice, else the current node's successors. Empty while a
  stop is in progress (fight, reward, vendor, rest or story unresolved), when the run is finished and in line mode.
- `choose_node(id) -> bool`: false unless `id` is reachable. Otherwise it records the node and opens its stop.
- `current_stop()` is the stop of the chosen node, and null between stops (and when finished). A node becomes a
  `RunState.Stop` of the matching StopType: fight `enemy_count` from the node, `tier` = the node's 0-based act, `boss` /
  `mid_boss` flags, `beat_index` for story nodes, `fight` = the row-keyed ramp number, plus the new fields `node_id` and
  `backdrop` (the node's battle screen key). The existing `start_combat`, `complete_combat`, `resolve_reward`, `rest`,
  `remember`, `vendor_*`/`leave_vendor` and `read_story` work unchanged and, when they finish, leave the run between
  stops. Beating the final boss ends the run as an escape; defeat ends it as before; the mid-boss pays gold and a reward.
- Helpers: `battle_backdrop()` (the node's backdrop in map mode, `DestinationArt.battle_key(stop_index)` on the line),
  `destination_label()` (place name; `DestinationArt.label_for_stop` in map mode) and `RunState.stop_type_for_node`.
- `stop_index` in map mode is the row (0 to 29) of the current node (0 before the first choice) and becomes
  `stops.size()` once the run is escaped. `stops` holds 30 placeholder entries so `stops.size()` is the journey length
  (30) and "Journey n/30" works; nothing should read their contents. `rarity_tier()` and `rest_number()` follow rows and
  visited nodes.
- Saving map runs is phase 3 (below).

Encounters: a fight uses the node's rolled `enemy_count` with `StarterContent.varied_encounter`. The ramp is keyed by row:
`StarterContent.ramp_fight_for_row(row)` = row * 8 / 28 (0 at the start, 8 on row 28; clamped), fed to the existing
`ramp_factor`, so depth sets difficulty on any path. This is a placeholder until phase 4's threat budgets. An elite node
(not generated by default) fights a normal pack of at least 2.

Run flow (run.gd): between stops `_show_stop` shows the map through one seam, `_map`: a screen that is `attach`ed like the
others, has `show_map(run)` and emits `node_chosen(node_id)`. It is `MapScreen`; `FallbackMapScreen`
(run/screens/fallback_map_screen.gd, a plain list of buttons) has the same contract, so swapping is a one-line change.

Debug switch (the only way in for now, no menu change): `--map` or `THE_UNFORGOTTEN_MAP=1` starts a map run for the
`--character` (default Deserter) as a debug session (nothing saved or deleted, see Phase 3); `--hp` and `--gold` apply
(phase 3); `--fight` and `--screen` take precedence. Bots: `tools/run_sim.gd --map`
uses `SimPolicy.choose_route` (first reachable node) or `SmartPolicy.choose_route` (rest under half HP, shop from 120
gold, else the first fight).

## Phase 3: saving map runs

### Format

`RunSave.VERSION` is 5 and `MIN_VERSION` stays 2. The rule for versions: a line run keeps writing **version 4**, byte for
byte the same keys as before (`RunSave.LINE_VERSION`), so the previous release can still read a line save made now; only a
map run writes **version 5** (`RunSave.MAP_VERSION`). The game reads 2 to 5: v2 and v3 are migrated and v2 to v4 saves
load as line runs exactly as before (no migration to a map). A save above 5 is rejected with "made by a newer version of
the game (save format N, this game reads up to 5)". A v5 save must have a map; a map block under version 4 or below is
ignored (nothing ever wrote one).

A v5 save has the v4 player fields (`character`, `hp`, `max_hp`, `gold`, `deck`, `offered`, `reward_remove_used`,
`reward_heal_used`, `relics`, `rng_state`, `stop_index`) minus `line`, plus:

- `map`: the whole route, `RouteMap.to_dict()` (kind, seed, character_id, config, every node with its edges). The full
  dict is stored instead of the seed so retuning the generator never changes a run in progress. (Consequence: a saved
  map is re-checked by `RouteMap.validate()` on load against its own stored config, so a future rule change in the
  validator can reject old saves; bump the save version if that is ever intended. A seed past 2^53 loses its low bits
  in JSON; the seed is informational once the nodes are stored.)
- `current_node`: the node id the player is at, -1 before the first choice.
- `visited`: the node ids taken so far, in order (the last is `current_node`).
- `at_node`: true when the player is inside the current node's stop, false when at the map between stops.
- `stop_index` is the row of the current node (0 before the first choice), as in RunState.

Nothing else is needed to resume: `rest_number()`, `rarity_tier()` and the ramp are derived from `visited` and the row,
and the vendor stock and encounters come from the saved RNG position (a save is only written at a stop boundary, so no
fight, reward or vendor visit is ever in flight). `RunState.restore_map` puts a freshly built run at the saved place and
rebuilds the stop of the current node.

### Validation (untrusted input)

`RunSave.from_dict` returns an error message and no run, never an exception, for each of these (all tested in
`tests/run_save_map_tests.gd`, plus 400 randomised corruptions that must be judged without a crash):

- `map` is missing, not an object, or `RouteMap.from_dict` returns null (wrong types, unknown kind or node type, a row,
  column, edge or node count out of range, over 1000 nodes, a malformed config).
- the map is not kind `generated` or does not have 30 rows, was made for another character, or `validate()` reports a
  problem (removed edges, a missing final boss, a self edge...).
- `current_node` is not an integer id of the map (or -1); `visited` is not an array of ids, is longer than 30, or is not
  one node per row from row 0 to the current node, connected by edges of the map, starting on the first row and ending
  at `current_node` (so a visited row beyond the current, a gap, a repeat or a wrong order is rejected).
- `stop_index` is not the row of `current_node` (0 with no current node); `at_node` is not a boolean.
- before the first choice: `visited` must be empty, `at_node` false and `stop_index` 0.
- at the map (`at_node` false) the current node must have somewhere to go: a save past the last row is a finished run,
  which is never saved.
- a v5 line run (no map), or any v5 save missing `current_node`, `visited` or `at_node`.

### When a map run is saved

Same convention as the line, plus the map:

- on arrival at a stop (`run.gd` `_show_stop` -> `_autosave`), so **choosing a node saves the choice**: Continue restores to
  the start of that stop, inside it, with no other road offered.
- when the map is shown (the start of the run and after every completed stop), so quitting at the map resumes at the map
  with the same reachable choices.
- Save & Exit writes the same boundary state; mid-fight or mid-reward it keeps the arrival save.

**Save-scum rule:** the save made when a node is chosen is written before the stop is shown, so the player cannot choose a
node, look at its fight, quit and choose another. (Only a damaged main save file falls back to the previous `.bak`, which
may be the map from before the choice; that is crash recovery, not something the game offers.) The legacy line-run
behaviour is the same: Continue after a lost-or-quit fight restarts the fight with the same RNG.

Deleting: when a run ends (win or defeat) `run.gd` deletes the save (and its `.tmp` and `.bak`), unless the run is a debug
session. `--map` is a debug session: it never saves or deletes, so a launch for testing cannot touch the player's own
save file (a real map run, once phase 4/6 offer one, saves to the same file and replaces a line save, like New Journey).
The main menu's Continue panel names a map run's place ("the crossroads" at the map, else the stop's place name) and the
pause overlay says what Save & Exit does for the situation (`PauseMenu.save_note`): unchanged text for a line run; at the
map "returns you to this map, with the same roads to choose from"; inside a stop "returns you to the start of this stop".

### Phase 2 leftovers settled here

- `--hp` and `--gold` are honoured by `--map`.
- The coastal ambience (the Shore of Names) plays on the map before the first choice and in the first row's stop, and stops
  once the player has left that stop (it was tied to `stop_index == 0`, which stays 0 at the map after row 0).
- `rest_number()` is unbounded in map mode and `RestContent.beat` clamps, so rests after the fourth repeat "Before the
  Door". Left as is on purpose (a map holds at most a handful of rests); revisit with the balance pass.

## Phase 4a: guaranteed rest before each boss, retuned mix

Each act has a forced rest row (local row 12, every node a rest) just before the story beat that precedes its boss,
so every path rests once before each boss. The row before it (local row 11) holds no rest, so the map never shows two
rests back to back there. Everywhere else rests stay optional. The row layout, the node-type rules and `validate()`
above describe the result; `ROWS` stays 15 per act and the story rows did not move, so the enemy-count bands (keyed
to the run row) and the backdrop no-repeat rule are unchanged.

Code: `RouteMap.FORCED_REST_ROW`, `row_info()["forced"]`, `window_last_index()`; the generator fills the forced row with
rests and rolls the row before it without the rest weight; `validate()` gained the three rules listed under "Node
types in free rows". `RunSave._check_map` re-validates through `validate()`, so it needed no change; a map saved
under the old layout (unreleased: map runs are still debug-only) is now rejected as invalid.

Weights and windows: fight 26 / rest 18 / shop 7 / elite 0 (was 26 / 42 / 13 / 0); rest window 6 (was 4), shop window
8. At these weights the windows never fire in practice (identical results with the rest window off or 7); the
density sets how avoidable things are.

Measured over 2400 maps (600 per character; exact dynamic programme for the extremes, 8 random walks per act per
map for the random path), 0 `validate()` failures, 0 first-attempt retries (before: 2.0%), about 6.6 ms per map
(before: 7.2 ms).

Per act, mean (act 1 / act 2), before (old weights, no forced row) and after:

| Per act | before | after |
|---|---|---|
| random path, fights | 7.68 / 7.72 | 8.27 / 8.29 |
| random path, rests | 2.78 / 2.80 | 2.66 / 2.65 (p10 2, p90 3.4) |
| random path, shops | 1.54 / 1.48 | 1.07 / 1.06 (p10 0.4, p90 1.8) |
| fewest rests on any path, mean | 0.99 / 0.99 | 1.30 / 1.36 (p50 1, p90 2, max 3) |
| most rests on any path, mean | 4.14 / 4.14 | 3.92 / 3.92 (p10 3, p90 5, max 5) |
| fewest shops on any path, mean | 0.20 / 0.15 | 0.09 / 0.08 |
| most shops on any path, mean | 3.00 / 2.95 | 2.34 / 2.29 (p10 1, p90 3, max 4) |
| maps with a shop-free path | 81% / 85% | 91% / 92% |
| maps where the rest-avoiding route sees exactly one rest (the forced one) | n/a (28% allowed none) | 71% / 65%; none allow zero |
| most fights on any path, mean | 9.93 / 9.96 | 10.06 / 10.03 |

Over the whole run (after): random path 16.6 fights (p10 15.4, p90 17.8), 5.3 rests (p10 4.4, p90 6.3, min 3.4),
2.1 shops (p10 1.3, p90 3.1); the cautious route sees 7.8 rests (p90 9, max 10) and 4.6 shops (p90 6, max 8); the
skip-everything route sees 2.7 rests (the two forced ones plus a few) and 0.17 shops. Free nodes (forced rows
included): 68.2% fights, 22.8% rests, 9.0% shops. Before: 63.0% / 23.9% / 13.2% (free nodes without a forced row),
random path 15.4 fights, 5.6 rests, 3.0 shops.

Choices where the spec left room: the forced row counts as a free row for width (3 or 4 nodes) and edges, and as the
last entry of the act's free-row list, so "free rows" in the availability windows and `RouteMap.free_rows()` still
count 12 per act; the 22 free rows are the ones that are not forced. The path check requires a rest before each boss
(and so before story beats 1 and 3); story beats 0 and 2 have no guarantee before them.

## Phase 4b: treasure rows and relic chests

A TREASURE node is a chest that gives the player one relic. Each act has a forced treasure row of chests (a guaranteed
chest per act, two per run), built like the forced rest row: it is a free row for width and edges, and every node in it
is a chest. No chest appears anywhere else.

### Layout

| Act | Local row | Free index | Notes |
|---|---|---|---|
| 1 | 6 | 5 | free rows run 1 to 12, so five free rows (1 to 5) come before it |
| 2 | 7 | 6 | the story beat sits at row 3, so free rows run 0 to 2 and 4 to 12 |

`RouteMap.TREASURE_LOCAL_ROWS := [6, 7]` (next to `FORCED_REST_ROW`), `row_info()["treasure"]`. Both rows come after the
3 safe rows (the first 3 free rows of an act are fights), are 5 rows or more away from the forced rest row (local row 12)
and from each other, so two forced rows are never neighbours. The rows next to a chest row follow the normal rules: a
rest or shop can neighbour it, and the adjacency rule never links a chest to anything because only chests share its row.
Act 2's row 7 sits mid-act (free index 6 of 12) where act 1's row 6 does (5 of 12): the same position counted from the
act's free rows. The chest row is exempt from the plain-fight rule like the rest row, and it has no enemy count and no
backdrop.

`NodeType.TREASURE` (value 7, appended) plays as `RunState.StopType.TREASURE` (value 4, appended). The `type_weights`
config has a reserved `"treasure": 0.0` key (accepted, validated, ignored by the generator: chests only fill the forced
row).

### Rules

- `validate()` reports a node of the treasure row that is not a chest, and a chest anywhere else (a type that does not
  belong in a free row). A chest has no enemies and no backdrop (the generic non-fight rules).
- The availability windows count the rows of `RouteMap.window_rows(act)`: the act's free rows without the treasure row,
  ending with the forced rest row (11 rows). The 3 safe rows still come first, so the rest window (6) covers window rows 3
  to 8 and the shop window covers 3 to 9. The shop window was 8 and would no longer fit once the chest row left the list,
  so it is now 7 (it had never fired at these weights, so the maps barely changed).
- `from_dict` accepts type 7 (and still rejects 8 and above). `RunSave._check_map` re-validates through `validate()`, so it
  needed no change: a map save made before this phase has no treasure row and is rejected as invalid (map runs are
  debug-only, no player has one; the save version stays 5).

### The stop

Entering a treasure stop shows `TreasureScreen` (`run/screens/treasure_screen.gd`) over `TreasureScene`
(`run/treasure_scene.gd`: the dimmed Name Vault painting and a code-drawn strongbox). Closed it offers "Open the chest";
opened it shows the relic (a `RelicView` badge, its name and effect) and "Take it", which adds the relic and moves on.
Taking plays the existing `reward` sound; the button click is the existing `click`. The header names the stop "The
Sealed Strongbox".

RunState API: `in_treasure_stop()`, `open_treasure()`, `treasure_opened()`, `treasure_relic()`, `treasure_gold()`,
`take_treasure()`. The relic is rolled by `open_treasure()` with the run RNG (the arrival save is written before the stop
is shown, so a save resumed there, opened again, rolls the same relic from the restored RNG). An open chest is not a stop
boundary (`at_stop_boundary()` is false, like an open vendor visit), so Save & Exit inside it keeps the arrival save and
the relic is never re-rolled differently. A MAX_HP relic raises max HP and HP once when taken, as when bought.

Relic selection: the character's pool (`StarterContent.relic_pool`) minus the relics owned, restricted to relics with a
vendor price of at least `RunState.TREASURE_MIN_RELIC_PRICE` (65) when any are left, else any of them; one is picked
uniformly with the run RNG. The relic prices run 50 to 75: the rule drops the two cheapest relics (50 and 55), so a chest
beats a shop's cheapest relic. If the character owns every relic of its pool (neutral relics are part of that pool, so no
neutral fallback exists) the chest holds `TREASURE_FALLBACK_GOLD` (100) gold, the screen says so and "Take the gold" pays
it.

### UI

A chest glyph (`MapView._glyph_chest`: a domed lid on a box with two straps and a lock plate, cream-gold `#f6d98e`),
a "Treasure" legend entry and the tooltip "Treasure: a relic". `FallbackMapScreen` lists "Treasure".

### Bots and debug

`SimPolicy.treasure_stop(run)` opens and takes the chest (both policies); `SmartPolicy.choose_route` prefers a chest
over a fight (after resting when hurt and shopping when rich). `tools/run_sim.gd --map` handles the stop. `--screen=treasure`
(or `THE_UNFORGOTTEN_SCREEN=treasure`, `treasure:2` for the second act) opens a chest of a throwaway map run.
`tools/treasure_sheet.gd` takes the screenshots.

### Measured numbers

2400 maps (600 per character), 8 random walks per map, exact dynamic programme for the extremes; 0 `validate()` failures,
about 5.9 ms per map. Per act (act 1 / act 2), before is the Phase 4a table:

| Per act | before | after |
|---|---|---|
| random path, fights | 8.27 / 8.29 | 7.52 / 7.53 |
| random path, rests | 2.66 / 2.65 | 2.51 / 2.52 |
| random path, shops | 1.07 / 1.06 | 0.97 / 0.95 |
| random path, chests | 0 | 1.00 / 1.00 |
| fewest rests on any path, mean | 1.30 / 1.36 | 1.28 / 1.26 |
| most rests on any path, mean | 3.92 / 3.92 | 3.66 / 3.75 |
| fewest shops on any path, mean | 0.09 / 0.08 | 0.06 / 0.05 |
| most shops on any path, mean | 2.34 / 2.29 | 2.13 / 2.11 |
| maps with a shop-free path | 91% / 92% | 94% / 95% |

Free nodes (the chest rows included): 62.2% fights, 21.4% rests, 8.1% shops, 8.3% chests. A random path loses about 0.75
fights per act (one free row became a chest row), as accepted; the rest and shop means stay in their 2.4 to 2.9 and 0.9 to
1.2 targets, so the weights were not changed.
