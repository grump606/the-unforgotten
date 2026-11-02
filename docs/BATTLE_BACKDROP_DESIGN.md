# Battle backdrop

> **Naming note (v0.5.0):** the game was reskinned as "The Unforgotten". Enemy and relic display names changed (for example Brakeman = Bellkeeper, Conductor = Eraser, Gate Warden = Threshold Keeper). IDs, files and rules did not. This document still uses the original names; see [`docs/RESKIN.md`](RESKIN.md) for the full map.

An animated, code-drawn background behind the battle UI (`run/battle_backdrop.gd`, `class_name BattleBackdrop`). No image assets. It is the first child of `battle.tscn` (node `Backdrop`, full rect, mouse ignored), so it sits under everything and the standalone F6 battle shows it too.

## Composition and palette

The inside of a train corridor seen head-on at night. Vanishing point at (0.5, 0.36) of the screen, a small door frame at the far end, floor, ceiling and wall rails running out to the screen edges. Colours match the pause scene and card/enemy docs: night `(0.035, 0.04, 0.06)`, steel lines `(0.16, 0.19, 0.25)`, lamp amber `(1.0, 0.78, 0.42)`, pale ghost glow `(0.72, 0.84, 0.95)`, boss red `(0.92, 0.22, 0.16)`.

## Layers (back to front) and motion

All motion derives from one accumulator `time`; depth `s = p*p` so things quicken as they near the viewer.

1. Night fill, far door with a faint pale glow (breathes 0.8 rad/s).
2. Wall/ceiling/floor rails and floor seams (static).
3. Frame ribs rushing outward (0.15 cycles/s).
4. Windows on both walls sliding past, with the odd distant light crossing the glass.
5. Floor sheen down the middle, with a lamp reflection under each lamp.
6. Six ceiling lamps, hung in side lanes, each swinging on its own rhythm, flickering (table sampled 11 times a second).
7. 44 dust motes drifting up (embers in the boss fight), positions are pure functions of time.
8. Whole picture sways a few pixels and about 0.3 degrees (overscan 48 px keeps corners covered).
9. Scrim: 20% dim overall, darker left/right edges and top rim (60%), darker lower 45% (up to 45%).

## Legibility budget

- Quiet zones: the enemy row (top, y 16 to 180), the log and player labels (left/centre), and the hand and End Turn (y 430 to 632). Lamps and windows live in the side lanes and the corridor middle, never behind the hand.
- Behind text the art stays at or below about 0.12 luminance; peaks (lamp cores, light on the glass) at most 0.5 and under 8 px across; glow alpha at most 0.16 (boss) behind the log. Lines are 1 to 3 px at under 0.5 alpha.
- Art must read as subordinate: if a card, panel or label looks muddy, lower the scrim-free alphas, not the UI.

## Variants (`set_variant(boss, character_id)`)

- Default: amber lamps, gentle flicker, sway 0.5 rad/s, rush 0.15.
- Boss (the Conductor): red lamps, harder flicker, sway 0.9 rad/s and double angle, rush 0.20, embers, pale end glow about three times stronger.
- Class tint, mixed 32% (TINT_AMOUNT, was 14%, too faint to read) into lines, glass, glow and dust: Deserter rust, Pickpocket teal, Medium violet. The window glass takes the class colour (GLASS_TINT 0.45), the lights outside the windows are class coloured, and a class-coloured wash (ACCENT_GLOW 0.07) surrounds the far door. In the boss fight the tint is halved (BOSS_TINT_SCALE 0.5) and the lights stay red, so the boss mood holds. Unknown or empty id is neutral. The scrim is unchanged, so cards and text stay as legible.
- `run.gd` sets `boss_fight` and `character_id` on the battle before adding it; the standalone battle uses the default.

## Performance and tests

About 150 `draw_*` calls a frame (rects, lines, small polygons and circles; no textures, no shaders), redrawn only from `advance()`, which does nothing unless the node is visible in the tree. The paused tree (pause overlay) stops `_process` too. The local `RandomNumberGenerator` has a fixed seed, so layout is identical every run and the run RNG is untouched.

`tests/ui_battle_backdrop_test.gd` (in `scripts/check.ps1`) covers variants, determinism, hidden/detached freeze, mouse ignore and the battle screen having one backdrop as lowest, full-screen child. `tools/backdrop_sheet.gd` takes the screenshots (not headless).

## Mid-boss

The mid-boss fight (The Brakeman) uses the same boss variant as the Conductor: `run.gd` sets `boss_fight` for a stop that is `boss` or `mid_boss`. The battle also writes a `Mid-boss fight` (or `Boss fight`) line at the top of its log (`battle.boss_label`), and the run header already reads `Stop n/N: Mid-boss`. Only the final boss ends the run; the mid-boss leads to the normal reward screen and the line goes on.
