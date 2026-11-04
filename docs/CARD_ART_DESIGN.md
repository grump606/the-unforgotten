# Card art design

Cards are drawn in code (`run/card_view.gd`, `class_name CardView`); no image assets. A card is a **punched train ticket**: one shared layout, and the class changes the stock colour, frame treatment and corner emblem. Preview with `godot --path . -s res://tools/card_sheet.gd -- <out dir> [scale]` (needs a window, not headless): it writes `cards_all.png` (all cards by class) and `cards_states.png`.

## Layout (base 136x190, plus 6 px of lift room; `view_scale` scales it)

Header band (price stamp left, class label centre, emblem right), name banner, art window (50 px) with the icon, effect text (12 px, shrinks to 10), perforation with side notches, keyword strip. The strip shows the target (`ONE ENEMY`, `ALL ENEMIES`, `SELF`), then keywords (Expose, Hold, Thorns, Haunt) if they fit, and a red `-N HP` chip for HP-cost cards.

Hand fit: the hand is an `HFlowContainer` (`battle.tscn`, min height 100) in a 1152x648 view; seven cards at 136 px plus 10 px gaps is 1042 px wide, so one row holds up to 8. A row needs about 196 px of height, which the current layout (enemy row 90, log, buttons) must make room for in Phase 2.

## Classes (palette tokens live in `CardView.PALETTES`)

| Class | Stock / frame | Header label, frame decor | Emblem | Art window motif |
|---|---|---|---|---|
| Neutral | keepsake paper `#D7D0BC` / slate `#526979`, dark ink | `KEEPSAKE`, plain rule | punched hole | faint ring |
| Deserter | steel `#29313A` / rust `#A66A50`, light ink | `DESERTER`, hazard stripes, corner rivets | hex bolt | diagonal stripes |
| Thief | dusk teal `#253D3D` / sage `#78A99B` | `THIEF`, stitched thread border | keyhole | ruled lines |
| Medium | bruised violet `#342F42` / lilac `#9A89AD` | `MEDIUM`, dots, bone double line | candle | concentric eye rings |

Neutral is the only light card, so class cards read as "darker, coloured, framed" next to it. Shared: cost badge amber `(.96,.78,.30)` with dark number, art window near-black tinted per class, icon colours by kind.

## Icons (primary = first present in the priority order below)

| Kind | Icon | Kind | Icon |
|---|---|---|---|
| DAMAGE_PER_BLOCK | shield + hammer | THORNS | spiked star |
| DAMAGE_IF_BLOCK | blade + small shield | EXPOSE | crosshair |
| DAMAGE_PER_PLAY | blade + rising bars | HOLD | shield outline with lock |
| DAMAGE_PER_HAUNT | ghost + blade | GAIN_ENERGY | bolt |
| DAMAGE | weapon by variant (below) | DRAW | two cards |
| HAUNT | ghost | HEAL_PER_HAUNTED | heart with plus |
| BLOCK | shield | LOSE_HP | blood drop |


### Damage variants (`CardView.icon_variant(card)`)

Plain DAMAGE (as primary icon) picks a weapon from the card's own data, first match wins. All stay red/orange except the bone. The secondary glyph for DAMAGE is always the sword.

| Variant | Rule | Icon | Cards today |
|---|---|---|---|
| needle | class thief | thin pin with ring eye and thread | Cutting Word, Hamstring, Filch |
| bone | class medium | pale bone club | Grave Chill |
| sweep | target ALL_ENEMIES | wide arc slash (plus the enemy pips) | Sweep |
| fist | id in `FIST_IDS` (shove, shoulder_charge) | fist with motion lines | Shove, Shoulder Charge |
| axe | total damage >= 12 (`HEAVY_DAMAGE`) | haft with crescent head | Heavy Blow |
| flurry | damage <= 4 (`LIGHT_DAMAGE`) and cost 0 | three parallel slashes | Flurry |
| dagger | damage <= 4 | short broad blade | Guarded Strike |
| sword | everything else | the original blade | none yet |

DAMAGE_PER_BLOCK uses a hammer next to the shield (variant `hammer`; Bash). The other composite icons keep the blade.
Further kinds appear as up to three small glyphs in the window's bottom right. All-enemy cards show three small enemy pips top left. A new `CardEffect.Kind` needs an entry in `ICON_PRIORITY` and `_draw_icon` (the test enforces it).

## States (`CardView.set_state(state, note)`)

- Normal: sits 6 px low. Hover: lifted, lighter frame, thin glow. Selected: lifted with a 3 px gold outline.
- Unplayable: desaturated stock and frame, cost badge turns red; `note` (for example `NEED 2 ENERGY`, `TOO LOW HP`) replaces the keyword strip in amber. The `-N HP` chip is always drawn on HP-cost cards, so the warning is visible before the card is blocked.
- `auto_hover = true` lifts on mouse hover by itself; it is off by default.

## Accessibility

Class is carried by label text and emblem shape as well as colour; unplayable is shown by the red badge, dimming and a text note; HP cost is a text chip. Body text is ink on stock at roughly 7:1 or better (neutral `.13` on `.90`; light ink on the dark class stocks, dimmed cards stay above 4.5:1). Minimum text size is 10 px (labels), body 12 px.

## Not done yet

Keyboard focus ring, localisation of the labels. Phase 2 wiring is done: the battle hand (scale 0.85, `HAND_CARD_SCALE`), reward and vendor offers (1.2), remove pickers (0.7) and the select screen (0.6) all use CardView; `clickable` + `pressed`, `hotkey`, `preview` and `CardView.find_all` support them.
