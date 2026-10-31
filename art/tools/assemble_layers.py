"""Turn raw generations into the game's layer files.

  python assemble_layers.py art/work/warden art/layers/warden

Reads bg_raw.png and figure_raw.png from the first folder; writes bg.png and figure.png (960x320)
to the second. mid.png and fg.png are left alone. Needs rembg (pip install "rembg[cpu]").
"""
import os
import sys

from PIL import Image, ImageChops
from rembg import remove

W, H = 960, 320


def main():
    work, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    bg = Image.open(os.path.join(work, "bg_raw.png")).convert("RGB").resize((W, H), Image.LANCZOS)
    bg.save(os.path.join(out, "bg.png"))

    fig = remove(Image.open(os.path.join(work, "figure_raw.png")).convert("RGB"))
    fig = fig.crop(fig.getchannel("A").point(lambda a: 255 if a > 20 else 0).getbbox())
    scale = (H * 0.98) / fig.height
    fig = fig.resize((max(1, round(fig.width * scale)), round(fig.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(fig, ((W - fig.width) // 2, H - fig.height), fig)
    canvas.save(os.path.join(out, "figure.png"))
    for name, gain, thr in (("mid", 0.8, 30), ("fg", 1.5, 70)):
        src = os.path.join(work, name + "_raw.png")
        if os.path.exists(src):
            img = Image.open(src).convert("RGB").resize((W, H), Image.LANCZOS)
            r, g, b = img.split()
            alpha = ImageChops.lighter(ImageChops.lighter(r, g), b).point(lambda v: min(255, int(max(0, v - thr) * gain)))
            img.putalpha(alpha)
            img.save(os.path.join(out, name + ".png"))
    print("wrote", out)


main()
