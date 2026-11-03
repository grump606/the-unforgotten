# Vendor scene

An animated stall behind the vendor panel (`run/vendor_scene.gd`, `class_name VendorScene`). Since v0.5.0 the wall, shelves and lamps come from a painted backdrop (`art/layers/screens/vendor/bg.png`) and the shopkeeper is a painted figure (`keeper.png`, drawn by `_draw_painted_keeper`); everything below that describes code-drawn shelves, lanterns and a hooded void-faced keeper is now only the fallback used when those files are missing. The counter, till, props, motes and scrim are still code-drawn. `run.gd` adds one as the first child of the body at a vendor stop (full rect, mouse ignored) and then the HUD controls on top. The stop is full screen like a fight: `_dock_stall_hud` hides the header row and the frame margin and shrinks the Pause button to a small plaque top right; every other screen is unchanged.

## Composition and palette

A ghostly vendor trades from a baggage car. A hooded shopkeeper (a dark cloak, a void face with a veil and two amber eyes) sits behind a counter, with shelves of old suitcases, hatboxes and jars on both sides and four lanterns hanging from a rail. The offers and the services sit in a HUD row along the bottom of the screen, with the speech banner centred just above it, clear of the keeper's face. There is no backing box over the art.

Warm lantern amber `(1.0, 0.78, 0.42)` and brass `(0.78, 0.55, 0.24)` over wood browns `(0.22, 0.13, 0.075)` and a near-black wall `(0.085, 0.06, 0.05)`; cloak `(0.035, 0.03, 0.045)`, pale ghost `(0.72, 0.84, 0.95)` only on the veil and glass. No enemy red and none of the class colours.

## Layers (back to front) and motion

All motion derives from one accumulator `time`; every flicker is a pure function of it.

1. Wall planks and the lantern rail (static), the pool of lamp light behind the shopkeeper (flickers).
2. Shelves with luggage (layout from the fixed seed; lit by the nearest lantern).
3. Four lanterns on chains, each swinging on its own rhythm with a smooth halo and its own flicker.
4. Shopkeeper: breathing (2 px, 1.1 rad/s), a blink every 4.7 s, a rim of lantern light on the shoulders.
5. Counter: top with lamp pools, brass edge, front with plank seams.
6. Till (brass, display reads the gold, coin stacks of five up to 15 coins, glows 0.8 s after a change), a case with a swaying tag, a service bell.
7. A prop left of each service button: ticket-punch (Remove), medicine bottle (Heal, glows), small case (Leave); dimmed when the button is disabled.
8. 36 dust motes, then a scrim (darker sides and top; 60% dim over everything while the remove picker is open).

## Legibility budget

- The HUD is real controls: CardViews (prices as labels under each, SOLD / NEED n GOLD on the card), the relic as a card-sized clickable plate (same states and price label, no Buy button), plaque Buttons with their original text, a `GoldBadge` (coin and total), and ribbon labels (greeting and the last refusal) on a 90% dark, brass-edged background. Successful purchases show no message. The service buttons use `RunScreen.compact_plaque` so a 34 px plaque keeps an intact border.
- The top-left text (stop title and journey number at 20 pt, owned relics under them) matches the fight HUD.
- Behind text the art stays dark and low-contrast: no lantern, shelf or prop sits behind a ribbon or label; the counter top behind the price labels is about 0.2 luminance. Small lanterns are above the banner.

## Layout at 1152x648

The body is the whole 1152x648 window. A 104 px head space at top centre marks the hood. A bottom stack holds the banner (and a refusal message) above one row: a 190 px left column (gold total, Remove, Heal), the offers (cards 116x161 at 0.85, and the relic plate the same size) and a 190 px right column (Leave). The stall tracks the panel by reference (`head_anchor`, `counter_anchor`, `service_anchors`, read each draw), so it follows layout changes; without them it uses defaults. In the remove picker the bottom row is dropped, a centred dark panel holds the deck, and the stall is dimmed.

## Variants

None. When the player cannot afford the cheapest offer (`Vendor.PRICE_CHEAP`) the greeting changes to a line about empty pockets; the till shows the lower gold and fewer coins.

## Retaking the captures

`tools/vendor_sheet.gd` writes the rich, sold, remove and poor shots (not headless); the reference sheets under `docs/reference` use `vendor_rich.png` as JPEGs.

## Performance and tests

About 400 `draw_*` calls a frame (rects, lines, small polygons, circles and three strings; no textures, no shaders), redrawn only from `advance()`, which does nothing unless the node is visible in the tree (`_process` is switched off while hidden; the paused tree stops it too). The generator is local with a fixed seed, so the run RNG is untouched.

`tests/ui_vendor_scene_test.gd` (in `scripts/check.ps1`) covers building, determinism, hidden/detached freeze, mouse ignore, the till, and a real vendor stop with one stall beneath clickable offers. `tools/vendor_sheet.gd` takes the screenshots (not headless).

## Painted keeper (v0.5.0)

`PaintedArt.keeper_figure()` loads `art/layers/screens/vendor/keeper.png` (transparent PNG) and the box around its painted pixels. `_draw_painted_keeper` scales it so the face sits at the head anchor (`FACE_FROM_BOTTOM`), lets the hands drop behind the counter edge, applies a tiny vertical stretch for breathing and tints it with the lantern flicker. It has one frame: no blink and no low-gold variant. The prompt used to generate it is in `art/CHATGPT_VENDOR_BRIEF.md`.
