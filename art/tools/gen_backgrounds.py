"""Regenerate per-enemy backgrounds and mid layers without locomotives, and redo the Wisp figure.

  python gen_backgrounds.py

Writes art/work/<enemy>/bg_raw.png and mid_raw.png, and art/work/wisp/fig_5x.png candidates.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "..", "work")
STYLE = ("dark painterly illustration, gouache and oil texture, visible brush strokes, soot-black and "
         "oxblood shadows, tarnished brass highlights, single warm ember light source, gothic rail-station mood")
NEG = ("train, locomotive, steam engine, railway carriage, characters, people, figures, animals, text, "
       "watermark, frame, blurry, photo, 3d render")
LORA = ["--lora", "cbpstyle.safetensors", "--lora-strength", "0.6"]

BACKGROUNDS = {
    "warden": "massive iron station gates at night, tall pillars, amber glow beyond the bars",
    "shade": "empty foggy station arcade, pale blue moonlight, wet flagstones, cold mist",
    "wisp": "burnt out station concourse, scattered embers, orange firelight on dark brick",
    "colossus": "cavernous boiler room, iron pipes, furnace glow, steam, stone floor",
    "whisperer": "derelict station waiting room, cold lamplight, dust, wooden benches",
    "hound": "empty rail yard at night, glowing cinders on the ground, smoke, fences",
    "crow": "rusted signal gantry and chimneys at dusk, smoky red sky, rooftops",
    "conductor": "grand empty station hall, gaslamps, long polished floor, ghostly mist",
    "brakeman": "railway yard storage sheds, stacked sleepers, lantern light, drifting smoke",
}
MID = {
    "warden": "thin dark smoke wisps along the ground",
    "shade": "pale cold fog banks drifting low",
    "wisp": "rising heat haze and thin dark smoke",
    "colossus": "thick billowing steam clouds",
    "whisperer": "faint dust motes and soft grey mist",
    "hound": "low creeping smoke and drifting cinders",
    "crow": "streaks of dark storm cloud",
    "conductor": "thin ghostly mist hugging the floor",
    "brakeman": "oily black smoke wisps",
}
WISP = ("a single floating ball of living fire, a flame elemental with a bright white-yellow core, trailing tongues "
        "of flame and a few tiny glowing sparks circling it, no legs, no spider, no body, no person")


def gen(prompt, neg, out, w, h, seed, lora=True):
    cmd = [sys.executable, os.path.join(HERE, "comfy_gen.py"), "--prompt", prompt, "--negative", neg,
           "--out", out, "--width", str(w), "--height", str(h), "--seed", str(seed)]
    subprocess.run(cmd + (LORA if lora else []), check=True)


def main():
    for name, bg in BACKGROUNDS.items():
        d = os.path.join(WORK, name)
        os.makedirs(d, exist_ok=True)
        gen("cbpstyle, %s, %s, wide empty scene" % (STYLE, bg), NEG, os.path.join(d, "bg_raw.png"), 1536, 512, 51)
        gen("%s, painterly, soft, on a pure black background, empty above" % MID[name],
            "text, objects, bright, white, dense, ground", os.path.join(d, "mid_raw.png"), 1536, 512, 61, lora=False)
    for seed in (51, 52, 53, 54):
        gen("cbpstyle, %s, %s, plain dark background" % (STYLE, WISP),
            "spider, legs, person, human, text, watermark, frame, blurry, photo, 3d render",
            os.path.join(WORK, "wisp", "fig_%d.png" % seed), 768, 768, seed)


main()
