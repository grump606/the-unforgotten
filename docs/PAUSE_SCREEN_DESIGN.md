# Pause screen backdrop

An animated "cut scene" behind the pause menu, drawn entirely in code (`run/pause_scene.gd`, `class_name PauseScene`). No image assets.

## Scene

A dark carriage interior at night, seen from a bench:

- Back wall in near-black blue with panel seams; a ceiling band.
- A large window with a wooden frame and mullion. Inside it a tunnel: dark ribs rush outward, wall lamps (amber) drift out from a vanishing point and quicken as they pass, a faint pale glow breathes far ahead. A passing lamp briefly washes the glass.
- A hanging lamp at the upper right with a cone of light over the seats; it flickers.
- The bench across the aisle (back rest and seat) and the front edge of the bench you sit on at the bottom.
- The whole picture sways slowly (about 0.3 degrees and a few pixels), with overscan so corners stay covered.

## Palette

Matches the UI's `Color(0.04, 0.04, 0.07)` pause background and the story tone ("cold iron", "guttering lamp", "lamplight bends"): wall `(0.06, 0.06, 0.09)`, wood browns, lamp amber `(1.0, 0.78, 0.42)`, pale ghost glow `(0.72, 0.84, 0.95)`. A light scrim over everything and a darker soft band behind the menu column keep the buttons fully readable.

## Per-character detail (`RunState.character.id`)

- `deserter`: a discarded uniform coat on the seat at lower left (olive, brass buttons, epaulette), dimming and brightening with the lamp.
- `thief`: a stray pocket watch on a chain from a ceiling hook, swinging with a glint at each end of the swing.
- `medium`: three faint translucent figures on the far bench, each flickering in and out on its own rhythm.
- Anything else (empty, unknown): the neutral scene.

## Timing

All motion derives from one accumulator `time` (seconds): sway 0.55 rad/s, lamp flicker table sampled 14 times a second, tunnel ribs 0.22 cycles/s, wall lamps 0.17 cycles/s (squared for acceleration), watch swing 2 rad/s, ghost flicker 1.4 to 2 steps/s, glow breathing 0.9 rad/s.

## Integration

`run.gd` builds one `PauseScene` in the pause overlay (above the opaque background, below the menu) and calls `set_character()` whenever the pause opens. The node has `PROCESS_MODE_ALWAYS` so it runs while the tree is paused. It processes only while visible in the tree (`visibility_changed` toggles `set_process`), and `advance(delta)` is a no-op when hidden, so the closed menu costs nothing.

## Determinism and performance

- Flicker comes from a 64-entry noise table made once with a local `RandomNumberGenerator` seeded 606: never the global RNG or the run's RNG, so seeded runs are untouched.
- `advance(delta)` is the only thing that moves `time`; tests step it directly.
- About 100 draw calls of rects, circles, lines and a few polygons per frame; no per-frame allocation beyond small point arrays.

## Tests (`tests/ui_flow_test.gd`)

Pausing as each of the three characters shows the matching variant; unknown and empty ids give the neutral scene; `advance` changes `time` and the lamp level; a hidden scene does not advance; the scene keeps advancing by itself while the tree is paused; Continue hides it and stops processing. Existing pause tests (Escape, Continue, Save & Exit, New Run) are unchanged.

## Notes

The pause overlay anchors now use `set_anchors_and_offsets_preset`: with plain `set_anchors_preset` the overlay could stay at size 0 when built, which collapsed the menu to the top-left corner in a headless/scripted run.
