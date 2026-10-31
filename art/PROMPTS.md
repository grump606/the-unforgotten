# Prompt pack for painted layers

Use with any image tool (or hand it to an illustrator). Generate each layer separately on the canvas size from `README.md`, and remove backgrounds on `mid`, `figure` and `fg` so they have real alpha.

## Shared style block (prepend to every prompt)

> Dark painterly illustration, gouache and oil texture, visible brush strokes, soot-black and oxblood shadows, tarnished brass highlights, single warm ember light source, cool desaturated shadows, gothic rail-station mood, no text, no border, no UI.

## Layer suffixes

- bg: `empty background only, no characters, abandoned train platform at night, distant glow, wide 3:1 composition, opaque`
- mid: `pillars, iron gates and low drifting fog only, transparent background, no character`
- figure: `single character centred, full silhouette readable at small size, rim lit by ember light, isolated on transparent background`
- fg: `sparse floating embers and dust, a few out-of-focus foreground shapes, transparent background`

## Subjects

| Enemy | Figure prompt |
|---|---|
| Gate Warden | tall armoured sentinel, closed helm with a glowing amber slit, iron gate bars across the chest, long halberd |
| Lost Shade | hooded ghost with hollow eyes, ragged hem, reaching arms, pale blue glow |
| Skittering Wisp | orb of flame on thin spider legs, circling sparks |
| Hollow Colossus | slab torso, huge fists, tiny head, ember heart glowing in a hollow chest |
| Pale Whisperer | hooded pale face covered in small murmuring mouths, sunken eyes |
| Cinder Hound | side-on hound, ember eye and maw, embers in the fur |
| Mourning Crow | crow with raised wings, a single falling tear |
| The Conductor | tall coat, peaked cap, skull face, baton, watch chain, ghost passengers behind |
| The Brakeman | hulking railway worker, soot-stained, oxblood coat, heavy brake lever, amber lamp |

Card art subjects follow each card's effect (see `CardView.icon_variant` and `docs/CARD_ART_DESIGN.md`); give each class its accent colour: Deserter rust and steel, Pickpocket teal and brass, Medium violet and bone, Neutral cream and grey.

## Consistency tips

Reuse one seed or reference image per enemy across its four layers, keep the light direction fixed (from lower centre), and review at the real display size (about 200x66 for portraits) before committing a set.
