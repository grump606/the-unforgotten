"""Turn the picked player cutouts into game files.

  python assemble_players.py [class ...]

Reads art/work/players/<class>/pick.png (transparent cutout), trims it to its painted pixels, scales it
to at most 900 px tall and writes art/layers/players/<class>/figure.png.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "..", "work", "players")
OUT = os.path.join(HERE, "..", "layers", "players")


def main():
    for name in sys.argv[1:] or ["deserter", "pickpocket", "medium"]:
        img = Image.open(os.path.join(WORK, name, "pick.png")).convert("RGBA")
        img = img.crop(img.getchannel("A").point(lambda a: 255 if a > 20 else 0).getbbox())
        if img.height > 900:
            img = img.resize((round(img.width * 900 / img.height), 900), Image.LANCZOS)
        os.makedirs(os.path.join(OUT, name), exist_ok=True)
        img.save(os.path.join(OUT, name, "figure.png"))
        print("wrote", name, img.size)


main()
