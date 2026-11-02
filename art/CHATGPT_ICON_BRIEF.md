# ChatGPT brief: game icon

The game currently ships the default Godot icon (`icon.svg`; the exe export has no icon set). This brief makes a replacement in the style of "The Unforgotten".

## Attach these references

1. `art/layers/screens/menu/bg.png` - the mood: rain, slate blue-grey, one warm light.
2. `art/layers/brakeman/sprite.png` - the brass bell and tarnished metal finish (the Bellkeeper's bell is the game's recognisable object).
3. `art/layers/screens/vendor/keeper.png` - cloth, stitching and worn-brass detail.
4. One card face, for example `art/layers/cards/bash/art.png`.

## Prompt

> Using the attached images as strict style references, paint a **single square app icon** for a dark fantasy card game called "The Unforgotten", set in a drowned memorial city in the rain.
>
> **Subject:** one bold central object that reads at 16 pixels: a **tarnished brass bell** with a small crack, hanging slightly off-centre-left of a **single upright playing card** (dark slate with a worn brass border and a faint stitched edge) that sits behind it. A soft warm lantern glow comes from the lower right and catches the bell's rim; a few fine rain streaks and a little mist. Nothing else in the picture.
>
> **Style:** match the references: dark painterly gouache and oil finish, visible brush strokes, slate blue-grey shadows, muted teal, bone and tarnished brass, one warm amber light. No red. Not cartoonish, no glossy 3D app-store look, no lens flare.
>
> **Composition:** centred, with the bell and card together filling about 70% of the canvas and a calm margin all round (the icon will be cropped to a rounded square and shrunk to 16 px, so keep the silhouette simple with strong contrast between the brass and the dark background). Full-bleed dark slate-blue misty background, **opaque, no transparency**, no border, no frame.
>
> **Output:** exactly square, at least 1024 x 1024. **No text, no letters, no logo, no watermark, no UI.**

## Variants to ask for in the same chat

- "Same icon with a lantern instead of the bell" (alternative silhouette).
- "A simplified version with fewer details and higher contrast, for 16-32 px."

## After it is generated

1. Save the PNG as `art/icon/icon_source.png` (outside the project if you prefer; tell Claude where it is).
2. Claude then:
   - writes `art/icon/icon.png` (256) and a multi-size `icon.ico` (16, 24, 32, 48, 64, 128, 256);
   - points `project.godot` `config/icon` and the export preset `application/icon` at them (the exe icon);
   - sets `SetupIconFile` and `UninstallDisplayIcon` in `installer/setup.iss` (installer and Apps list);
   - checks the 16/32/48 px renders for legibility before committing.
