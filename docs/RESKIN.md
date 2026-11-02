# The Unforgotten reskin (v0.5.0)

The game is now presented as **The Unforgotten**: a memorial city in the rain instead of a train line. It is a presentation layer only. Card effects, combat numbers, enemy and relic IDs, the 21-stop route and the save signature are unchanged, so code, tests, the sim and older docs keep using the original IDs and names.

## Name map

Display names changed; the file and ID on the left did not.

| ID / file | Was | Now |
| --- | --- | --- |
| `gate_warden` | Gate Warden | Threshold Keeper |
| `lost_shade` | Lost Shade | The Unnamed |
| `skittering_wisp` | Skittering Wisp | Stray Recollection |
| `hollow_colossus` | Hollow Colossus | Memorial Giant |
| `pale_whisperer` | Pale Whisperer | The Husher |
| `cinder_hound` | Cinder Hound | Ash Hound |
| `mourning_crow` | Mourning Crow | Keepsake Crow |
| `the_brakeman` (mid-boss, stop 9) | The Brakeman | Bellkeeper |
| `the_conductor` (final boss) | The Conductor | Eraser |
| `ticket_stub_charm` | Ticket Stub Charm | Folded Farewell |

`Fighter.ART_KEYS` maps the new display names to the sprite keys, so a renamed enemy needs an entry there (a test fails if one is missing). Class pitches and all story beats (`data/story/`, including the per-character versions) were rewritten.

## What was added

- `run/destination_art.gd`: the 21 stop labels (Shore of Names ... The Threshold) shown in the header, and `battle_key()`, which picks a destination backdrop for some fights.
- `run/menu_style.gd`: one shared slate and bone theme, serif headings and amber focus outlines for the menus. Menu wording: New Journey, "A moment of quiet" on the pause menu.
- Five destination backdrops in `art/layers/screens/` (`battle_street`, `battle_bell_court`, `battle_garden`, `battle_archive`, `battle_threshold`) next to the class and boss ones. `Battle.destination_key` feeds `BattleBackdrop.set_variant`.
- A painted Wisp sprite (`art/layers/wisp/sprite.png`).
- A stance animation in `run/fighter.gd` (`stance_motion()`): small weight shifts and a forward lean, with its own pace per class and enemy type. It uses the presentation clock only, no RNG.
- `tests/reskin_presentation_test.gd`, run by `scripts/check.ps1` as "reskin restoration".

All sprites now face left in the source art, so `PLAYER_ART_FACING` is right for all three classes and `SPRITE_FACES_RIGHT` is empty.

## Still open

- A graphical review in motion (facing, stance animation, the new backdrops).
- Rest and vendor figures and the Warden and Conductor details from the art to-do list.
- The installer, `README.md` and older design docs still use the original names in places; treat the table above as the key.
