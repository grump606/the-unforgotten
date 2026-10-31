"""Generate candidate training images for the style LoRA (SDXL base, via comfy_gen.py).

  python gen_dataset.py art/work/lora_candidates

Writes NNN_<subject>_<seed>.png plus a .txt caption beside each. Curate the folder by deleting weak
images before training; captions use the trigger word `cbpstyle` and omit the shared style words
so the LoRA learns them.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
STYLE = ("dark painterly illustration, gouache and oil texture, visible brush strokes, soot-black and "
         "oxblood shadows, tarnished brass highlights, single warm ember light source, gothic rail-station mood")
NEG = "text, watermark, signature, frame, border, blurry, photo, 3d render, multiple characters, sword"

SUBJECTS = {
    "warden": "towering iron gatekeeper in plate armour, closed helm with glowing amber eye slit, gate bars on the chest, long halberd",
    "shade": "hooded ghost with hollow eyes, ragged hem, reaching arms, pale blue glow",
    "wisp": "orb of flame on thin spider legs, circling sparks",
    "colossus": "hulking slab-bodied golem, huge fists, tiny head, ember heart glowing in a hollow chest",
    "whisperer": "hooded pale figure whose face is covered in small murmuring mouths, sunken eyes",
    "hound": "side-on hound with an ember eye and glowing maw, embers in its fur",
    "crow": "black crow with raised wings, a single falling tear",
    "conductor": "tall figure in a long coat and peaked cap with a skull face, holding a baton, a watch chain, ghost passengers behind",
    "brakeman": "hulking railway worker in a soot-stained oxblood coat holding a heavy brake lever and an amber lamp",
}
SEEDS = (101, 102, 103)
BACKDROPS = {
    "platform": "empty abandoned train platform at night, iron gates, distant amber glow",
    "waiting_room": "derelict station waiting room, cold lamplight, dust, wooden benches",
    "tunnel": "rail tunnel mouth, fog, a lone lantern, rusted tracks",
}


def gen(name, prompt, seed, width, height, out):
    path = os.path.join(out, "%s_%d.png" % (name, seed))
    subprocess.run([sys.executable, os.path.join(HERE, "comfy_gen.py"), "--prompt", "%s, %s" % (STYLE, prompt),
                    "--negative", NEG, "--out", path, "--width", str(width), "--height", str(height),
                    "--seed", str(seed)], check=True)
    with open(path[:-4] + ".txt", "w") as f:
        f.write("cbpstyle, " + prompt)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, desc in SUBJECTS.items():
        for seed in SEEDS:
            gen(name, desc + ", full figure, plain dark background", seed, 768, 768, out)
    for name, desc in BACKDROPS.items():
        for seed in SEEDS[:2]:
            gen(name, desc + ", wide scene, no characters", seed, 1024, 576, out)


main()
