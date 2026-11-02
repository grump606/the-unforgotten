# ChatGPT brief: vendor shopkeeper art

Paste the prompt below into ChatGPT (image generation) in a new chat, with the reference images attached. Generate one image at a time and iterate on the first before asking for variants.

## Attach these references (all in this repo)

1. `art/layers/screens/vendor/bg.png` - the stall the shopkeeper stands behind. Match its light, palette and scale.
2. `art/layers/brakeman/sprite.png` - a finished figure: the target for rendering, cloth and painterly finish.
3. `art/layers/conductor/sprite.png` and `art/layers/shade/sprite.png` - two more figures for consistency.
4. One class figure, for example `art/layers/players/medium/figure.png`.

## Prompt

> Using the attached images as strict style references, paint a single full-figure **shopkeeper** for a ghostly night market in a drowned memorial city. The first image is the stall they stand behind: match its moonlit blue-grey shadows, tarnished brass and single warm lantern glow from the right, and its worn cloth and weathered stone. The other images are finished characters from the same game: match their dark painterly gouache and oil finish, visible brush strokes, torn layered fabric, and the way edges fall off into shadow.
>
> **Subject:** a stooped, patient keeper of lost property. A long dark-slate coat and a hood with a pale, calm, faintly translucent face (no skull, no horror grin), hands in worn fingerless gloves resting forward as if over a counter. A ring of small brass keys and a few tarnished tags hang from the belt, and a folded cloth bundle is tucked under one arm. Quiet, welcoming and slightly sad, not threatening. Colour: slate, bone, muted teal and a little tarnished brass. No red.
>
> **Pose and framing:** facing slightly toward the viewer, torso and head lit by a warm lantern from the right, cool rim light on the left. Show from the head down to mid-thigh so the lower body can sit behind the counter. Centred, the full silhouette readable at small size, with clear space around it.
>
> **Output:** portrait 2:3, at least 1024 x 1536, on a **plain solid flat background** (pure #00FF00 green, no shadows or gradients, nothing touching the edges) so the background can be removed afterwards. No text, no border, no UI, no watermark, no props from the stall in the picture.

## Follow-ups (ask in the same chat once the first image is right)

- "Same character, eyes closed, as a blink frame."
- "Same character leaning a little further forward, one hand lifted, as an offering pose."
- "Same character from the same angle with the hood lowered a little, as a sad variant for when the player has no gold."
- "Now the keeper of the rest stop: the same style, a seated figure by a small lantern." (the rest scene is also still code-drawn)

## After it is generated

- Save the PNG somewhere outside the repo and remove the green background to real alpha (see `art/README.md`, `art/COMFYUI.md`).
- Drop the result in `art/layers/screens/vendor/keeper.png` and tell Claude; `VendorScene._draw_shopkeeper` still draws the code-drawn figure and needs a small change to use a painted one.
- Review next to the Bellkeeper sprite and the vendor backdrop at the real display size before committing.
