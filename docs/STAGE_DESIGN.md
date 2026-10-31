# Battle stage (side view)

The battle screen is a Slay the Spire style stage: the player stands bottom-left facing right, up to three enemies stand on the right facing left, all on one ground line over the painted battle backdrop. The hand, hotkeys and cards are unchanged. It replaced the older HUD panels per enemy (`EnemyView`, now removed).

## Layout (`battle.tscn`, `battle.gd`)

- **Stage**: an expanding area above the hand. `Fighter`s are children of it; `_layout_stage()` places the player at 19% of the stage width and centers the enemies as a group in the 40% to 98% band (enemy 0 nearest the player, 16 px gaps), bottoms aligned so every figure stands on the same line.
- **Bottom row**: energy orb (`EnergyOrb`) over the draw/discard counts on the left, the hand in the middle, End Turn (or Continue after the fight) and a Log toggle on the right. The combat log is a small panel in the stage's top-right corner, hidden until toggled. Relic badges sit in the stage's top-left corner.
- The result line ("You slip through the gate.") shows at the top of the stage.

## Fighter (`run/fighter.gd`)

One `Fighter` per combatant: figure, then, around it, an intent badge and number above the head (enemies only; the full text is in the tooltip as "Next: ..."), an HP bar under the feet with Block as a blue frame and a shield badge, status pills (Exposed, Haunt, Hold, Thorns) under the bar, a gold marker and ground ring on the target, and floating numbers. Clicking a living enemy selects it.

Animation runs only through `advance(delta)` (tests step it): idle breath, lunge toward the opponent (`play_attack(delay)`), hit recoil and red flash, `-N` / `Blocked` / `+N` floats, shield pop on Block gained, and a sink-and-fade on defeat. Hit reactions can wait for the attack that causes them: the battle sets `react_delay` on the targets of a card, and `schedule_hit()` on the player for each enemy attack, so a hit lands when its lunge peaks and enemies attack one after another (`ENEMY_STAGGER`, 0.4 s).

## Art

- Enemies: `art/layers/<key>/sprite.png`, a trimmed transparent full-body cutout. Without it the stage draws the old 4-layer `figure.png` (cropped to its painted pixels), then a ghost. `Fighter.ART_KEYS` maps display names to keys; `Fighter.HEIGHTS` is the figure height per key (scaled by `HEIGHT_SCALE`, 1.2). Sprites that face right as drawn are listed in `SPRITE_FACES_RIGHT` (the stage mirrors them); everything else faces left. The Skittering Wisp still uses its old fireball figure.
- Player classes: `art/layers/players/<id>/figure.png`, drawn mirrored to face right (`PLAYER_ART_FACING`). The standalone fight and any class without a sprite use a code-drawn cloak in the class colours.
- Generation: ComfyUI + the cbpstyle LoRA through `art/tools/gen_players.py` and `gen_enemy_sprites.py` (contact sheets in `art/work/`), then `assemble_players.py` and `assemble_enemy_sprites.py` trim and write the game files. See `art/COMFYUI.md`.
- The Conductor's code-drawn figure (`run/conductor_figure.gd`) is still used by the story scene.

## Previewing

`godot --path . -s res://tools/backdrop_sheet.gd -- <out dir>` (needs a window, not headless) saves the real battle screen for each class with 1 to 3 enemies and the boss fight. Tests: `tests/ui_stage_test.gd`.
