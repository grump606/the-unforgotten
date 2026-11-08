# Game facts (the one place for the numbers)

Counts and stats that other docs used to repeat, and that went stale when repeated. Other docs
should link here instead of restating a number. When the game changes, change this page; the
"Source" column says where the number really lives, and the test that would catch a mismatch where
there is one.

Last checked against v0.8.2 (released 2026-11-08).

| Fact | Value | Source |
| --- | --- | --- |
| Game version | 0.8.2 | `config/version` in `project.godot` (and `export_presets.cfg`, checked by `scripts/release.ps1`) |
| Engine | Godot 4.7.2 stable | `scripts/engine_version.txt` |
| Stops on the line | 22, in two acts | `RunState._default_line()` in `run/run_state.gd`; `docs/LEVELS_DESIGN.md` |
| Stop mix | 4 story beats, 8 regular fights, 1 mid-boss (the Brakeman, shown as Bellkeeper), 1 final boss (the Conductor, shown as Eraser), 3 vendors, 5 rests | same; `tests/rest_content_tests.gd` checks the 5 rests |
| Playable characters | 4: Deserter (52 HP), Thief (36 HP), Medium (56 HP), Stray (37 HP) | `data/characters/*.tres` |
| Class cards | Deserter 24, Thief 26, Medium 23, Stray 25 (each class pool must be at least 22) | `data/cards/*.tres` (`character` tag); `tests/pool_tests.gd` |
| Relics | 21 | `data/relics/*.tres`; `docs/RELICS_DESIGN.md` |
| Enemies | 9 (7 regular, 2 bosses) | `data/enemies/*.tres` |
| Hand | 5 cards drawn, at most 10 in hand, keep at most 5 at end of turn | `Combat.HAND_SIZE`, `Combat.HAND_MAX` |
| Energy per turn | 3 | `Combat.ENERGY_PER_TURN` |
| Stand-alone fight / sim player HP | 40 | `tools/balance_sim.gd`, `battle.tscn` on its own |
| Save format | version 4 (v2 and v3 migrate on load) | `run/run_save.gd` |

## How to re-check a number

```powershell
# class cards
Select-String -Path data\cards\*.tres -Pattern 'character = &"stray"' | Measure-Object
# relics
(Get-ChildItem data\relics\*.tres).Count
# stops: count the Stop.new(...) lines in _default_line()
```
