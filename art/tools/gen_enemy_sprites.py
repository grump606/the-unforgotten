"""Generate full-body, left-facing enemy sprite candidates with the style LoRA, cut them out and make
a contact sheet per enemy.

  python gen_enemy_sprites.py [enemy ...]     (no args = all, in the order below)

Writes art/work/sprites/<enemy>/raw_<seed>.png, cut_<seed>.png and sheet.png. Pick one per enemy and
copy its cutout to art/work/sprites/<enemy>/pick.png, then run assemble_enemy_sprites.py.
"""
import os
import subprocess
import sys

from PIL import Image
from rembg import remove

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "..", "work", "sprites")
STYLE = ("dark painterly illustration, gouache and oil texture, visible brush strokes, soot-black and "
         "oxblood shadows, tarnished brass highlights, single warm ember light source, gothic rail-station mood")
SIDE = "full body, whole figure visible head to feet, seen from the side facing left, plain flat grey background"
NEG = ("text, watermark, signature, frame, blurry, photo, 3d render, multiple characters, facing camera, "
       "cropped, close-up, portrait, train, railway, tracks, arch, doorway, lamppost, fire background, "
       "flames behind, glow behind, halo, scenery")
SEEDS = tuple(int(s) for s in os.environ.get("SPRITE_SEEDS", "71,72,73,74").split(","))
LORA = ("cbpstyle.safetensors", "0.6")
# name: (prompt, width, height)
ENEMIES = {
    "colossus": ("hulking slab-bodied stone golem, huge fists, tiny head, ember heart glowing in a hollow chest, cracked grey stone", 768, 1024),
    "wisp": ("a floating ball of orange fire with thin spindly spider legs, circling sparks, no person, no human", 768, 768),
    "warden": ("tall armoured sentinel in dark plate armour, closed helm with a glowing amber slit, long halberd", 768, 1024),
    "shade": ("hooded ghost with hollow glowing eyes, ragged hem, long reaching arms, pale blue glow", 768, 1024),
    "whisperer": ("hooded pale figure whose face is covered in small murmuring mouths, sunken eyes, long robe", 768, 1024),
    "hound": ("lean hound standing, ember eye and glowing maw, embers in its fur, no person", 1024, 768),
    "crow": ("large black crow with raised wings, a single falling tear, perched, no person", 1024, 768),
    "conductor": ("tall figure in a long dark coat and peaked cap with a skull face, holding a baton, a gold watch chain", 768, 1024),
    "brakeman": ("hulking railway worker in a soot-stained oxblood coat holding a heavy brake lever and an amber lantern", 768, 1024),
}


def main():
    names = sys.argv[1:] or list(ENEMIES)
    for name in names:
        prompt, w, h = ENEMIES[name]
        d = os.path.join(WORK, name)
        os.makedirs(d, exist_ok=True)
        cuts = []
        for seed in SEEDS:
            raw = os.path.join(d, "raw_%d.png" % seed)
            subprocess.run([sys.executable, os.path.join(HERE, "comfy_gen.py"), "--prompt",
                            "cbpstyle, %s, %s, %s" % (STYLE, prompt, SIDE), "--negative", NEG,
                            "--out", raw, "--width", str(w), "--height", str(h), "--seed", str(seed),
                            "--lora", LORA[0], "--lora-strength", LORA[1]], check=True)
            cut = remove(Image.open(raw).convert("RGB"))
            cut.save(os.path.join(d, "cut_%d.png" % seed))
            cuts.append(cut)
        sheet = Image.new("RGBA", (384 * len(cuts), 512), (60, 70, 80, 255))
        for i, c in enumerate(cuts):
            c = c.crop(c.getchannel("A").point(lambda a: 255 if a > 20 else 0).getbbox())
            k = min(372 / c.width, 500 / c.height)
            c = c.resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.LANCZOS)
            sheet.paste(c, (i * 384 + (384 - c.width) // 2, 506 - c.height), c)
        sheet.convert("RGB").save(os.path.join(d, "sheet.png"))
        print("sheet", name, flush=True)


main()
