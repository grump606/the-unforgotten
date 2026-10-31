"""Generate figure candidates and a background for each enemy with the style LoRA.

  python gen_enemies.py [enemy ...]      (no args = all except the Warden)

Writes art/work/<enemy>/fig_<seed>.png (four candidates) and bg_raw.png. Pick one candidate, copy it to
figure_raw.png, then run assemble_layers.py. mid_raw.png / fg_raw.png are copied from the Warden set.
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "..", "work")
STYLE = ("dark painterly illustration, gouache and oil texture, visible brush strokes, soot-black and "
         "oxblood shadows, tarnished brass highlights, single warm ember light source, gothic rail-station mood")
NEG = "arch, doorway, text, watermark, signature, frame, blurry, photo, 3d render, multiple characters, train, railway, tracks"
BG_NEG = "characters, people, text, watermark, frame, blurry, photo, 3d render"
SEEDS = (41, 42, 43, 44)
LORA = ("cbpstyle.safetensors", "0.6")

ENEMIES = {
    "shade": ("hooded ghost with hollow glowing eyes, ragged hem, long reaching arms, pale blue glow",
              "foggy rail tunnel mouth, pale blue moonlight, wet stone, cold mist"),
    "wisp": ("a floating ball of orange fire with thin spindly spider legs, circling sparks, no person, no human",
             "burnt out station concourse, scattered embers, orange firelight on dark brick"),
    "colossus": ("hulking slab-bodied stone golem, huge fists, tiny head, ember heart glowing in a hollow chest",
                 "cavernous boiler room, iron pipes, furnace glow, steam"),
    "whisperer": ("hooded pale figure whose face is covered in small murmuring mouths, sunken eyes",
                  "derelict station waiting room, cold lamplight, dust, wooden benches"),
    "hound": ("lean hound seen from the side, ember eye and glowing maw, embers in its fur, no person",
              "rail yard at night, glowing cinders on the ground, smoke"),
    "crow": ("large black crow with raised wings, a single falling tear",
             "signal gantry at dusk, rusted iron, smoky red sky"),
    "conductor": ("tall figure in a long coat and peaked cap with a skull face, holding a baton, a watch chain, pale ghost passengers behind him",
                  "grand station departure platform at night, gaslamps, pale ghostly crowd in the distance"),
    "brakeman": ("hulking railway worker in a soot-stained oxblood coat holding a heavy brake lever and an amber lantern",
                 "railway yard with parked wagons, lantern light, drifting smoke"),
}


def gen(prompt, negative, out, w, h, seed, lora=True):
    cmd = [sys.executable, os.path.join(HERE, "comfy_gen.py"), "--prompt", prompt, "--negative", negative,
           "--out", out, "--width", str(w), "--height", str(h), "--seed", str(seed)]
    if lora:
        cmd += ["--lora", LORA[0], "--lora-strength", LORA[1]]
    subprocess.run(cmd, check=True)


def main():
    names = sys.argv[1:] or list(ENEMIES)
    for name in names:
        fig, bg = ENEMIES[name]
        d = os.path.join(WORK, name)
        os.makedirs(d, exist_ok=True)
        for seed in SEEDS:
            gen("cbpstyle, %s, %s, full figure, plain dark background" % (STYLE, fig), NEG,
                os.path.join(d, "fig_%d.png" % seed), 768, 768, seed)
        gen("cbpstyle, %s, %s, wide scene, no characters" % (STYLE, bg), BG_NEG,
            os.path.join(d, "bg_raw.png"), 1536, 512, SEEDS[0])
        for layer in ("mid_raw.png", "fg_raw.png"):
            shutil.copy(os.path.join(WORK, "warden", layer), os.path.join(d, layer))


main()
