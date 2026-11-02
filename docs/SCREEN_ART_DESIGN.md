# Rest, story and end-card scenes

> **Naming note (v0.5.0):** the game was reskinned as "The Unforgotten". Enemy and relic display names changed (for example Brakeman = Bellkeeper, Conductor = Eraser, Gate Warden = Threshold Keeper). IDs, files and rules did not. This document still uses the original names; see [`docs/RESKIN.md`](RESKIN.md) for the full map.

Three code-drawn animated scenes behind the remaining plain screens, all built on `run/screen_scene.gd` (`ScreenScene`): `RestScene` (`run/rest_scene.gd`), `StoryScene` (`run/story_scene.gd`) and `EndScene` (`run/end_scene.gd`). No image assets. `run.gd` adds one as the first child of the body (`_add_backdrop`, full rect, mouse ignored, clipped to its rect) and then the panel on top, as at the vendor. Buttons keep their text and callbacks.

The base owns what is shared: `time`, a seeded noise table and mote field (local `RandomNumberGenerator`, fixed seed per scene, the run RNG is untouched), `advance(delta)` (does nothing unless visible in the tree; `_process` is off while hidden or paused), `wobble`/`flicker`, and helpers (ellipse, soft halo, gradient, lantern, scrim).

## Rest stop (`RestScene`)

A dim carriage: four night windows, one hanging lantern above the panel, a wooden bench along the lower left with the class seated on it (a side-on silhouette in the `CardView.PALETTES` accent: cap and strap, hood, long hair and shawl; neutral for an unknown id; `CharacterPanel`'s portrait code is instance-bound and was left alone), and at the right a stove with a glowing grate, a kettle and rising steam and embers. Palette: wall browns `(0.075, 0.055, 0.05)`, amber `(1.0, 0.78, 0.42)`, stove orange, pale steam. Motion: lantern sway and flicker, stove glow flicker, 6 steam puffs and 12 embers on loops, slow breathing (0.9 rad/s), 26 dust motes.

## Story beats (`StoryScene`)

A letterboxed window (34 px bars with a brass line) chosen by `beat_index`, `mood()` names it:

- 0 boarding: dusk sky and skyline, platform planks, a carriage at the right with lit windows and an open door spilling light, two lamp posts, steam along the platform.
- 1 conductor: an aisle in perspective (ribs rushing slowly, seat rows, two lanterns); the Conductor himself (skull face, crimson lapels, watch chain, swinging baton) in his own pool of light at the right, mirrored to face the card, about 210 px tall, tickets drifting up. He is drawn by `ConductorFigure.draw()` (`run/conductor_figure.gd`), the same code as his enemy portrait, so he is the same character everywhere. The hollow coats on the platform (beat 2) still use the scene's own faceless `_draw_coat_figure`. The end scenes show no figures.
- 2 empty platform: night, one lamp with a cone of light at the left, five hollow coats waiting beneath it, a dark far lamp, an empty bench, low fog.
- 3 last light: the tunnel ribs rush toward a pale breathing glow with rays, drawn above the card.
- any other index: a dim generic tunnel with one lantern.

The text is on a paper card (`PanelContainer`, 0.89/0.83/0.68 with a brown 3 px border and shadow, ink 0.14/0.10/0.07, 22 px title) that `run.gd` wraps round the existing column.

## End card (`EndScene`)

Escaped: a dawn gradient (slate to peach), a rock face with a bright tunnel mouth at the right and faint rays, a lit train rolling along the front that slows to a halt (`train_offset()` flattens out exponentially), roof steam, 30% extra dimming. Defeated: near-black tunnel with faint ribs and sleepers, the train shrinking away at the right with a dim red tail lamp, and a lone lamp at the left that dims, stutters and goes out after 9 s (`lamp_level()`), leaving an ember.

## Legibility budget

All text sits on real controls: the rest and end labels use the vendor's dark brass ribbon (`_style_banner`), the end summary is its own ribbon, buttons use the brass `_style_service` look, the story text is dark ink on paper. Art right behind text stays dark or is covered by those backings; side scrims darken the edges; nothing animated is brighter than the panel.

## Layout at 1152x648

The body is about 1120x590 under the header line. Rest panel about 265x105 centred (y 240 to 345 in the body); the bench rail starts below it. Story card about 520x280 centred, leaving about 300 px each side for the art. End column about 310x230 centred. Subjects (figure, train, lamp, conductor, tunnel mouth) sit left or right of centre, or above it.

## Performance and tests

About 150 to 300 `draw_*` calls a frame per scene (the halos are many faint polygons; no textures, shaders or strings), redrawn only from `advance()`. Hidden, detached or paused scenes do nothing.

`tests/ui_screen_scenes_test.gd` (in `scripts/check.ps1`) covers building and drawing, determinism, hidden/detached freeze, mouse ignore, every beat index plus an unknown one, both end variants, and one scene beneath each real stop's panel with working buttons. `tools/screens_sheet.gd` takes the screenshots (not headless).
