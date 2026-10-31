"""Turn the picked enemy cutouts into game files.

  python assemble_enemy_sprites.py enemy=seed [enemy=seed ...]

Copies art/work/sprites/<enemy>/cut_<seed>.png to pick.png, trims it to its painted pixels, scales it
to at most 900 px tall and writes art/layers/<enemy>/sprite.png (the stage figure; the old 4-layer
figure.png stays for the fallback).
"""
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "..", "work", "sprites")
OUT = os.path.join(HERE, "..", "layers")


def main():
    for arg in sys.argv[1:]:
        name, seed = arg.split("=")
        src = os.path.join(WORK, name, "cut_%s.png" % seed)
        shutil.copy(src, os.path.join(WORK, name, "pick.png"))
        img = Image.open(src).convert("RGBA")
        img = img.crop(img.getchannel("A").point(lambda a: 255 if a > 20 else 0).getbbox())
        if img.height > 900:
            img = img.resize((round(img.width * 900 / img.height), 900), Image.LANCZOS)
        os.makedirs(os.path.join(OUT, name), exist_ok=True)
        img.save(os.path.join(OUT, name, "sprite.png"))
        print("wrote", name, img.size)


main()
