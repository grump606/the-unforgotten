# Painted 2.5D art kit

Standalone: nothing in the game loads from `art/` yet. Preview with `godot --path . res://art/preview.tscn` (layered Gate Warden with parallax, and a card that tilts toward the mouse). `art/tools/shot.gd` saves a screenshot of the preview.

## Direction

Painted, moody, "last train out of a haunted station": soot, oxblood, brass and ember light. Keep the existing palette tokens so painted art still sits on the code-drawn frames (card class colours in `CardView.PALETTES`, enemy colours in `EnemyView.ART_COLORS`). One warm light source per picture (amber slit, ember heart, lantern), cool shadows, readable silhouette at 66 px tall.

The look is 2.5D: each picture is split into transparent PNG layers that move at different speeds (`fx/layered_art.gd`), and cards tilt in perspective with a moving sheen (`fx/card_tilt.gd`). Shaders stay GL Compatibility safe.

## Layer spec

Every layered picture is the same canvas, painted back to front. Name files exactly as below; layers 2 to 4 need real alpha.

| File | Content | Depth (parallax) |
|---|---|---|
| `bg.png` | opaque backdrop: walls, sky, distant light | 0.1 |
| `mid.png` | pillars, fog banks, set pieces behind the figure | 0.4 |
| `figure.png` | the character, hard silhouette edge, soft rim light | 0.8 |
| `fg.png` | sparks, dust, hanging cloth, anything in front | 1.6 |

Paint a little beyond the frame (about 5%) so shifting never reveals an edge.

| Asset | Canvas | Shown at | Folder |
|---|---|---|---|
| Enemy portrait | 960x320 (3:1) | portrait window 200x66 (boss 280x66) | `layers/<enemy>/` |
| Card art | 800x300 | card art window 136x50 | `layers/cards/<card_id>/` |
| Battle backdrop | 2304x1296 (16:9 at 2x) | full window | `layers/backdrop/<class>/` |
| Screens (vendor, rest, story, menu) | 2304x1296 | full window | `layers/screens/<name>/` |

Enemies: warden, shade, wisp, colossus, whisperer, hound, crow, conductor, brakeman. `layers/warden/` holds procedural stand-ins made by `tools/make_placeholders.gd`; overwrite them with painted PNGs of the same names and the preview picks them up.

## Applying it later

1. Drop painted layers into `art/layers/...` and let Godot import them.
2. In `EnemyView`, replace the `_art_<key>` draw call with a `LayeredArt` child sized to the portrait window (`set_layers(paths, [0.1, 0.4, 0.8, 1.6])`); keep the status chips and HP bar as they are.
3. In `CardView`, do the same for the art window and call `CardTilt.attach(card)` on hover-capable cards (battle hand, rewards, vendor). Keep the frame, banner and text code-drawn so cards stay data-driven.
4. Backdrop and screens use `LayeredArt` full-window with a smaller `strength`.

Open question before wiring: the 66 px portrait window is small for painted art. The panel can grow, or the portrait can bleed above the banner. Decide when applying.

Prompts for producing the painted layers are in `PROMPTS.md`.
