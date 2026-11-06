# Selectable route map: design

Replaces the fixed 21-stop line with a branching map the player chooses a path through. This document is the spec;
`docs/LEVELS_DESIGN.md` describes the line it replaces. Work proceeds in phases, one small PR each, on the
`map-route` integration branch.

## Shape

- A run is two acts of 15 rows each, 30 rows in all. The last row of each act is its boss (the Bellkeeper ends act 1,
  the Eraser ends act 2). A path through the map takes exactly one node per row, so every path is 30 stops.
- Each row holds 1 to 4 nodes. Rows with one node are choke points that every path passes through.
- Node types: fight, elite fight (supported by the data model; weight 0 until phase 5), rest, shop, story beat,
  mid-boss, boss.
- A rest or shop takes the place of a fight in its row. They are ordinary branches: a path that never picks one never
  sees one. Only the story beats and the two bosses are on every path.

## Row layout

| Act | Row(s) | Content |
|---|---|---|
| 1 | 0 | Story beat 0 (boarding). One node. |
| 1 | 1 to 12 | Free rows (3 to 4 nodes). Rows 1 to 3 are all fights. |
| 1 | 13 | Story beat 1 (the Bellkeeper's hall). One node. |
| 1 | 14 | Mid-boss. One node. |
| 2 | 0 to 12 except 3 | Free rows (3 to 4 nodes). Rows 0 to 2 are all fights. |
| 2 | 3 | Story beat 2 (the garden). One node. |
| 2 | 13 | Story beat 3 (the Eraser). One node. |
| 2 | 14 | Final boss. One node. |

That is 4 story beats, 2 bosses and 24 free rows per run, the same story order as the line.

## Edges

- Every node has at least one edge to the next row and at least one from the previous row (except the first and last).
- A node connects to 1 or 2 nodes of the next row whose column is within one of its own. Edges never cross.
- A one-node row connects to every node of the next row, and every node of the row before it connects to it.

## Node types in free rows

- Weights per free node (tuning values, kept in one config dictionary `RouteMap.CONFIG`): fight 26, rest 42, shop 13,
  elite 0 (until phase 5). The first 3 free rows of an act are all fights, and an elite never appears there. Because
  those safe rows and the adjacency rule add fights, the weights are not the resulting mix: they give about 63% fights,
  24% rests and 13% shops of all free nodes. Elite weight 14 (about 11% of free nodes) would bring the fights down to
  about 57% and give a random path about 14 fights, 5 rests and 2.5 shops; it stays 0 by default.
- Adjacency: a rest, shop or elite may not follow a node of the same type on any incoming edge. A blocked type is
  taken out of that node's roll and the remaining weights are used as they are (one roll), so a blocked rest
  turns into a fight, shop or elite in proportion to their weights, not always into a fight.
- The generator guarantees nothing per path. It guarantees map-level availability: in each act every run of
  4 consecutive free rows contains at least one rest node and every 8 consecutive free rows at least one shop node,
  placed so the choice is real (not forced). Windows only count free rows at or after the safe rows, so nothing is
  forced inside the all-fight opening.

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
- Rest and shop nodes have no backdrop; they keep their one fixed painting.

## Determinism

`RouteMap.generate(seed, character_id, config)` uses its own seeded `RandomNumberGenerator`, never the run's. The same
arguments give an identical map. The map is plain data (`to_dict` / `from_dict`) so a later phase can save it.

## Phases

1. Graph, generator, validator and tests. Nothing in the game uses it yet, so play is unchanged. A straight-line
   adapter turns today's 21-stop line into a one-node-per-row map so the old layout stays expressible.
2. Map screen and navigation; the run follows the chosen path; row-keyed ramp and backdrop.
3. Save format 5 and migration of old saves.
4. Threat-budget packs for random counts, route-choosing bots, and a rebalance for the 30-stop length.
5. Elites (new tougher packs, relic reward).
6. Balance pass and docs.
7. Later: event and treasure nodes.

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

Measured node mix (2400 default maps, 600 per character, free nodes only, elites off). Before the retune the weights
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

