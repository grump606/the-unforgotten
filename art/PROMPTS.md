# Prompt pack for painted layers

> **Naming note (v0.5.0):** the game was reskinned as "The Unforgotten". Enemy and relic display names changed (for example Brakeman = Bellkeeper, Conductor = Eraser, Gate Warden = Threshold Keeper). IDs, files and rules did not. This document still uses the original names; see [`docs/RESKIN.md`](../docs/RESKIN.md) for the full map.

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

Card art subjects follow each card's effect (see `CardView.icon_variant` and `docs/CARD_ART_DESIGN.md`); give each class its accent colour: Deserter rust and steel, Thief teal and brass, Medium violet and bone, Neutral cream and grey.

## Consistency tips

Reuse one seed or reference image per enemy across its four layers, keep the light direction fixed (from lower centre), and review at the real display size (about 200x66 for portraits) before committing a set.

## Touch-ups still open

Two details are missing from otherwise finished enemies. Attach the current file as the edit reference, and the stage sprite too when editing a portrait layer. The style prefix is the same for both: "Dark painterly illustration, gouache and oil texture, visible brush strokes, soot-black and oxblood shadows, tarnished brass highlights, single warm ember light source, cool desaturated shadows, gothic rail-station mood, no text, no border, no UI."

| File | Prompt (after the style prefix) |
|---|---|
| `art/layers/warden/sprite.png` (trimmed, about 900 px tall) | Edit the attached Threshold Keeper: preserve its pale closed mask, ragged slate-and-bone robes, gate-like shield, proportions and left-facing pose. Add a long iron halberd held convincingly in the free hand, with a distinct axe blade, hook and spear point readable at small size. Match the existing lighting. Real transparent background, whole figure and weapon with clear space around every extremity, no scenery or ground. |
| `art/layers/conductor/sprite.png` (trimmed, about 900 px tall) | Edit the attached Eraser: preserve its blank pale face, tall slate coat, book, hanging tags, proportions and left-facing pose. Add a clearly legible tarnished-brass pocket-watch chain draped in a shallow curve across the waist, attached to a coat pocket and distinct from the tags. Keep highlights broad enough to survive downscaling. Real transparent background, full body, no passengers or scenery. |
| `art/layers/warden/figure.png` (960x320) | Edit the attached Warden figure layer to include the same halberd. Preserve character, position, scale and silhouette. Character centred, whole silhouette and weapon inside the frame, readable at about 200x66. Real transparent background, no arch, platform, fog or foreground. |
| `art/layers/conductor/figure.png` (960x320) | Edit the attached Conductor figure layer: add the same brass watch chain between coat attachment and pocket. Preserve identity, pose, placement and lighting. Centred, whole silhouette inside the frame, real transparent background, no ghost passengers, backdrop or foreground. |

## Elite sprites (`art/layers/<key>/sprite_elite.png`, 2026-11-10)

Elite enemies draw the plain sprite with a painted flame aura behind it (`PaintedArt.ELITE_PADS`, `docs/MAP_DESIGN.md` "Phase 5a"). Made with
ChatGPT through the Codex CLI (`codex exec -i <images> ... -`), one call per enemy, then composited in code:

1. Pad the plain `sprite.png` onto a larger transparent canvas (left and right 0.367 of the width, above 0.2444 and below 0.0889 of the
   height, rounded; the Threshold Keeper uses 160 / 220 / 80 px) and make a flat magenta silhouette of it on the same canvas.
2. Attach both and ask for the **aura only**, no character: flame tongues, embers and a soft warm glow hugging the silhouette (orange outer
   flame about #FF5A1A, pale yellow core about #FFE58A, painterly, real transparent background, exactly the canvas size, same position and scale).
3. Composite the aura under the unchanged padded sprite (`Image.alpha_composite`) and save as `sprite_elite.png`; add the pads to `ELITE_PADS`.

Known weaknesses of this prompt: the aura is wider and softer than asked (a glow with flame tongues, not only tongues), with a faint red
fringe at its edge, and the Skittering Wisp's aura is pale and low-contrast. A tighter prompt ("discrete flame tongues only, no glow, at most
4% of the figure height from the outline, clean alpha") gave crisper but patchier flames on a test of the Threshold Keeper.

