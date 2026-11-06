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

- Weights per free node (tuning values, kept in one config dictionary): fight about 55%, rest about 20%, shop about 10%,
  elite about 10% (0 until phase 5). Elites never appear in the first 3 free rows of an act.
- Adjacency: a rest, shop or elite may not follow a node of the same type on any incoming edge.
- The generator guarantees nothing per path. It guarantees map-level availability: in each act every run of
  4 consecutive free rows contains at least one rest node and every 6 consecutive free rows at least one shop node,
  placed so the choice is real (not forced).

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
  from the new node's. With at most 4 columns the pool of 5 always has a legal choice; if a bug ever leaves none, fall
  back to the least recently used key and make the validator report it.
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
enemy-count and backdrop rules over many seeds, the validator against deliberately broken maps, the round trip and
the line adapter.

Choices where the spec left room:

- "Consecutive free rows" are consecutive in the act's list of free rows, so the act 2 story row (row 3) does not
  break a window. A window must be longer than the 3 safe rows, so the rest window of 4 puts a rest in the 4th free
  row of every act.
- Availability is applied as each row is rolled: a fight of the row that closes an empty window becomes the rest or
  shop, so the choice is real. Every free row also keeps at least one plain fight.
- Out-degree is 1 or 2 and in-degree is capped at 2 between free rows; a one-node row links to every node on either
  side regardless of columns.
- A story node after a 4-wide row passes all of that row's backdrops on to the fights behind it, which with a
  neighbouring fight can leave the pool of 5 empty; the backdrop pass re-rolls (up to 60 times) before it would
  accept a repeat, and the validator reports any repeat that remains.
- `from_line` maps COMBAT stops to fights, the mid-boss and boss flags to MID_BOSS and BOSS, VENDOR to SHOP, and
  validates only the graph shape and enemy counts (the 21-row line is not the generated layout).

