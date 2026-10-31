"""Generate side-view full-body player sprite candidates with the style LoRA, cut them out, and make
a contact sheet to pick from.

  python gen_players.py [class ...]      (no args = deserter pickpocket medium)

Writes art/work/players/<class>/raw_<seed>.png, cut_<seed>.png (transparent) and sheet.png.
Pick one per class and copy it to art/work/players/<class>/pick.png.
"""
import os
import subprocess
import sys

from PIL import Image
from rembg import remove

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "..", "work", "players")
STYLE = ("dark painterly illustration, gouache and oil texture, visible brush strokes, soot-black and "
         "oxblood shadows, tarnished brass highlights, single warm ember light source, gothic rail-station mood")
SIDE = "full body, standing, seen from the side in profile, facing right, plain flat grey background"
NEG = ("text, watermark, signature, frame, blurry, photo, 3d render, multiple characters, front view, "
       "facing camera, cropped, close-up, portrait, lamppost, street lamp, lantern post, train, railway, tracks, arch, doorway")
SEEDS = tuple(int(s) for s in os.environ.get("PLAYER_SEEDS", "51,52,53,54").split(","))
LORA = ("cbpstyle.safetensors", "0.6")

CLASSES = {
    "deserter": "a weary deserter soldier in a battered rust-coloured greatcoat and dented steel pauldron, "
                "holding a notched sword low, tattered cape, grim set jaw, rust and steel colours",
    "pickpocket": "a lean nimble pickpocket in a teal hooded jacket with brass buckles, flat cap, "
                  "a dagger in one hand and a stolen pocket watch dangling in the other, teal and brass colours",
    "medium": "a gaunt spirit medium in a long violet shawl and bone-white gloves, holding a glowing "
              "pale lantern, pale ghostly wisps curling around her, violet and bone colours, no lamppost, no street lamp",
}


def main():
    names = sys.argv[1:] or list(CLASSES)
    for name in names:
        d = os.path.join(WORK, name)
        os.makedirs(d, exist_ok=True)
        cuts = []
        for seed in SEEDS:
            raw = os.path.join(d, "raw_%d.png" % seed)
            subprocess.run([sys.executable, os.path.join(HERE, "comfy_gen.py"), "--prompt",
                            "cbpstyle, %s, %s, %s" % (STYLE, CLASSES[name], SIDE), "--negative", NEG,
                            "--out", raw, "--width", "768", "--height", "1024", "--seed", str(seed),
                            "--lora", LORA[0], "--lora-strength", LORA[1]], check=True)
            cut = remove(Image.open(raw).convert("RGB"))
            cut.save(os.path.join(d, "cut_%d.png" % seed))
            cuts.append(cut)
        sheet = Image.new("RGBA", (384 * len(cuts), 512), (60, 70, 80, 255))
        for i, c in enumerate(cuts):
            small = c.resize((384, 512), Image.LANCZOS)
            sheet.paste(small, (i * 384, 0), small)
        sheet.convert("RGB").save(os.path.join(d, "sheet.png"))
        print("sheet", os.path.join(d, "sheet.png"))


main()
