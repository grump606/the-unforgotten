# Run screen structure

`run.gd` (scene `run.tscn`) is the coordinator. Each screen it shows is built by a small script under `run/screens/`. All run rules stay in `run/run_state.gd`.

## run.gd keeps

- the `RunState` (`_run`), stop routing (`_show_stop`), the header line and relic strip (`_update_header`), the one-off `_notice`;
- autosave and save deletion, `save_path`, `exit_callable`;
- pause plumbing: it creates a `PauseMenu` and mirrors its parts as `_pause_button`, `_pause_overlay`, `_pause_box`, `_pause_scene` (tests read these), and implements `_save_and_exit` (returns `""` or the reason it did not exit);
- the vendor entry points `_buy_card`, `_buy_relic`, `_start_removing`, `_cancel_removing`, `_leave_vendor`, which forward to the vendor screen (tests and `tools/*_sheet.gd` call them).

## Screens

| Script | Shows |
| --- | --- |
| `run_screen.gd` (`RunScreen`) | Base class: `attach(run, body, refresh)`, `panel()`, `add_backdrop()`, `add_remove_picker()`, and static helpers `add_button`, `make_label`, `card_view`, `style_banner`, `style_service` |
| `select_screen.gd` | Character select, Back button along the bottom edge, re-centring |
| `main_menu_screen.gd` | The start screen shown on every launch: Continue (valid save only), New Run, Exit |
| `combat_screen.gd` | Embeds `battle.tscn` around the run's Combat |
| `reward_screen.gd` | Card choices, Skip, once-per-run Remove / Heal, remove picker (keeps `removing`) |
| `story_screen.gd` | Story beat on a paper card over `StoryScene` |
| `vendor_screen.gd` | Stall, card and relic offers, services (keeps `message`, `removing`) |
| `rest_screen.gd` | Rest stop |
| `treasure_screen.gd` | Treasure stop: a closed chest, then its relic |
| `event_screen.gd` | Event stop ("?" node): scene text, buttons with their cost lines, the outcome, the pick flows |
| `end_screen.gd` | End card and summary |
| `pause_menu.gd` | Pause button, overlay, options, abandon confirmation |

## Conventions

- A screen is a `RefCounted` owned by run.gd as a field, so state that must survive a redraw (vendor message, remove pickers) lives on the screen, with `reset()` called when a run starts or resumes.
- run.gd calls `_open(screen)` (which runs `attach`) and then `screen.show(...)`. Screens never route: they call `run` methods and then `refresh.call()` (run.gd's `_show_stop`). Other transitions (new run, start over, fight finished) arrive as callables passed to `show`.
- Screen widgets use the same node structure and button texts as before; UI tests look buttons up by text.
- To add a screen: extend `RunScreen`, add a field in run.gd, route to it in `_show_stop`.
