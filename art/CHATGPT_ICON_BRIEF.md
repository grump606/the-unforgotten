# ChatGPT brief: game icon

The game currently ships the default Godot icon (`icon.svg`; the exe export has no icon set). This brief makes a replacement in the current "The Unforgotten" art style.

## Attach these references

1. `art/layers/screens/menu/bg.png` - the mood: rain, weathered blue, one faint warm light.
2. `art/layers/brakeman/sprite.png` - the bell and the dull, worn metal finish (the Bellkeeper's bell is the game's most recognisable object).
3. `art/layers/screens/vendor/keeper.png` - patched linen, fraying and faded stitching.
4. One card face, for example `art/layers/cards/bash/art.png`.

## Shared style block (the first part of every art prompt)

> Painterly dark storybook fantasy for "The Unforgotten," a weathered coastal afterlife built from forgotten memories. Use rough ink contours, matte brushwork, simplified readable shapes, and tactile materials: patched linen, frayed cloth, salt-stained stone, dull iron, faded paper, and cloudy glass. The mood is quiet, melancholic, and uncanny, with small signs of human warmth.
>
> Palette: deep shadow #171D28, weathered blue #526979, faded bone #D7D0BC, muted rust #A66A50, sea glass #78A99B, bruised lilac #9A89AD, and restrained candle amber #E8B773.
>
> Lighting: consistent cool upper-left ambient light, with occasional faint amber light from sheltered lamps or embers. Keep backgrounds lower in contrast than characters and interactive elements.
>
> Avoid: glossy 3D rendering, photorealism, flat vector decoration, bright neon effects, ornate medieval armor, excessive gold trim, railway uniforms, ticket motifs, and baked-in text or interface labels.

## Asset block (paste after the style block)

> Subject: a single square game icon: one **dull aged-bronze bell** with a small crack and a worn rope loop, hanging in front of one **upright playing card** made of faded memento paper with a narrow bone-coloured border and faint stitched edges (a card, not a ticket: rounded corners, no punch holes or stubs). The bell's rim catches a faint candle-amber light from a sheltered lamp; a hint of sea-glass colour in the shadows, a few fine rain streaks and a little mist. Nothing else in the picture.
>
> Composition: centred, the bell and card together filling about 70% of the canvas with a calm margin all round, bell slightly in front and left of the card. A strong, simple silhouette with clear contrast between the bronze/bone shapes and a quiet, low-contrast deep-shadow (#171D28) to weathered-blue (#526979) misty background, so it stays readable when shrunk to 16 pixels. No border, no frame, no text.
>
> Output: exactly square, at least 1024 x 1024, fully opaque background (no transparency). Preserve readability at the intended in-game display size (16, 32 and 48 pixel icons and a 256 pixel installer icon).

## Variants to ask for in the same chat

- "Same style with a small sheltered lantern in place of the bell" (alternative silhouette).
- "A simplified version with fewer details and a bolder outline, for 16-32 px."

## After it is generated

1. Save the PNG as `art/icon/icon_source.png` (or tell Claude where it is).
2. Claude then:
   - writes `art/icon/icon.png` (256) and a multi-size `icon.ico` (16, 24, 32, 48, 64, 128, 256);
   - points `project.godot` `config/icon` and the export preset `application/icon` at them (the exe icon);
   - sets `SetupIconFile` and `UninstallDisplayIcon` in `installer/setup.iss` (installer and Apps list);
   - checks the 16/32/48 px renders for legibility before committing.

## Using this style for other assets

Keep the shared style block as-is and only change the asset block: `Subject: [describe the asset]. Composition: [framing, facing direction, and clear space]. Output: [dimensions and opaque or genuinely transparent background]. Preserve readability at the intended in-game display size.`

UI materials to mention for interface art: weathered memento paper, softly painted slate, repaired cloth, subtle fibres, faded stitching and narrow bone-coloured borders, with decorative texture restrained and text areas quiet, and modest serif headings.
