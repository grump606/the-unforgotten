# Game facts (the one place for the numbers)

Counts and stats that other docs used to repeat, and that went stale when repeated. Other docs
should link here instead of restating a number. When the game changes, change this page; the
"Source" column says where the number really lives, and the test that would catch a mismatch where
there is one.

Last checked against v0.9.0 (the route map as the default New Journey).

| Fact | Value | Source |
| --- | --- | --- |
| Game version | 0.9.0 | `config/version` in `project.godot` (and `export_presets.cfg`, checked by `scripts/release.ps1`) |
| Engine | Godot 4.7.2 stable | `scripts/engine_version.txt` |
| New Journey | The route map (a run is `RunState.new(seed, character, true)`) | `new_runs_use_map := true` in `run.gd`; `RunState._init` defaults `use_map` to false, so a bare `RunState.new(...)` and a sim without `--map` still play the line |
| Map size | 2 acts of 15 rows = 30 rows (shown to the player as the districts The Quiet Streets and The Dead Country); a path takes one node per row; each act ends with a boss (the Bellkeeper, then the Eraser) | `RouteMap.ACTS`, `ACT_ROWS`, `ROWS`, `DISTRICT_NAMES` in `run/route_map.gd`; `docs/MAP_DESIGN.md` |
| Fixed rows of the map | rows within an act: 2 story beats (act 1 at rows 0 and 13, act 2 at rows 3 and 13), 1 row of chests (act 1 row 6, act 2 row 7), a forced rest row (row 12), the boss (row 14); so 4 story beats and 2 chests per run | `STORY_LOCAL_ROWS`, `TREASURE_LOCAL_ROWS`, `FORCED_REST_ROW`, `BOSS_LOCAL_ROW` in `run/route_map.gd` |
| Variable node mix (fights, rests, shops, events, elites) | about 66% fights, 12% rests, 5% shops, 9% events, 8% elites (measured, not set; the weights are fight 36, rest 31, shop 3.5, event 6.5, elite 5.5) | `CONFIG["type_weights"]` in `run/route_map.gd`; measured counts in `docs/MAP_DESIGN.md`, "Phase 4h" and "Phase 5b". Chests and story beats are fixed rows, not rolled |
| Elite rules | pack budget x1.2, at least 2 enemies, +20 gold, and spoils of one relic (60 gold instead if every relic is owned) | `RunState.ELITE_BUDGET_MULTIPLIER`, `ELITE_GOLD_BONUS`, `ELITE_RELIC_FALLBACK_GOLD` in `run/run_state.gd`; `StarterContent.ELITE_MIN_ENEMIES` in `combat/starter_content.gd` |
| Events | 12 | `data/events/*.tres`; `docs/EVENTS_DESIGN.md` |
| Stops on the fixed line | 22, in two acts (still built when `new_runs_use_map` is false) | `RunState._default_line()` in `run/run_state.gd`; `docs/LEVELS_DESIGN.md` |
| Line stop mix | 4 story beats, 8 regular fights, 1 mid-boss (the Brakeman, shown as Bellkeeper), 1 final boss (the Conductor, shown as Eraser), 3 vendors, 5 rests | same; `tests/rest_content_tests.gd` checks the 5 rests |
| Playable characters | 4: Deserter (52 HP), Thief (36 HP), Medium (56 HP), Stray (37 HP) | `data/characters/*.tres` |
| Cards | 112 in all | `data/cards/*.tres`; `tests/pinned_balance_tests.gd` |
| Class cards | Deserter 24, Thief 26, Medium 23, Stray 25 (each class pool must be at least 22) | `data/cards/*.tres` (`character` tag); `tests/pool_tests.gd` |
| Relics | 21 | `data/relics/*.tres`; `docs/RELICS_DESIGN.md` |
| Enemies | 9 (7 regular, 2 bosses) | `data/enemies/*.tres` |
| Hand | 5 cards drawn, at most 10 in hand, keep at most 5 at end of turn | `Combat.HAND_SIZE`, `Combat.HAND_MAX` |
| Energy per turn | 3 | `Combat.ENERGY_PER_TURN` |
| Stand-alone fight / sim player HP | 40 | `tools/balance_sim.gd`, `battle.tscn` on its own |
| Save format | version 5 (`RunSave.VERSION`); a map run writes 5, a line run still writes 4 (`LINE_VERSION`), and v2 to v4 saves load as line runs | `run/run_save.gd` |

## How to re-check a number

```powershell
# class cards
Select-String -Path data\cards\*.tres -Pattern 'character = &"stray"' | Measure-Object
# relics
(Get-ChildItem data\relics\*.tres).Count
# events
(Get-ChildItem data\events\*.tres).Count
# cards
(Get-ChildItem data\cards\*.tres).Count
# line stops: count the Stop.new(...) lines in _default_line()
# map size, elite and save constants: read the const lines named in the Source column
```
