"""Generate full-window painted backgrounds (16:9) for the battle backdrop and the scene screens.

  python gen_screens.py [name ...]      (no args = all)

Writes art/work/screens/<name>/cand_<seed>.png. Pick one per scene, then run assemble_screens.py.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "..", "work", "screens")
STYLE = ("dark painterly illustration, gouache and oil texture, visible brush strokes, soot-black shadows, "
         "single warm light source, gothic mood, dim and low contrast, wide establishing shot")
NEG = "characters, people, figures, animals, text, letters, watermark, signature, frame, border, blurry, photo, 3d render"
SEEDS = tuple(int(s) for s in os.environ.get("SCREEN_SEEDS", "101,102").split(","))
CORRIDOR = ("view straight down a long dark ghost-train corridor at night, symmetrical, vanishing point in the centre, "
            "rows of tall windows and iron ribs receding, hanging lamps, empty")

SCREENS = {
    "menu": "a lone old steam train waiting at a dark misty station platform at night, its windows glowing amber, a distant pale gate of white light at the far end of the tracks, iron pillars, gas lamps, fog, symmetrical wide composition with open dark space in the centre, no people",
    "battle_neutral": CORRIDOR + ", cold steel blue and amber tones",
    "battle_deserter": CORRIDOR + ", rust orange and steel grey tones",
    "battle_pickpocket": CORRIDOR + ", deep teal and brass tones",
    "battle_medium": CORRIDOR + ", bruised violet and bone white tones",
    "battle_boss": CORRIDOR + ", blood red lamps, a pale cold glow at the far end, ominous",
    "rest": "empty dim train carriage interior at night, bare wooden floor, small dark windows, a single hanging lamp, warm quiet mood, no furniture",
    "vendor": "interior of a dim station ticket office, dark wooden panelling and brass fittings, a warm lantern glow, empty counter area",
    "pause": "dark empty train carriage interior seen from the aisle, rain on the windows, a faint lamp, very dim",
    "end_escape": "view from inside a dark tunnel mouth out onto a bright pale dawn landscape, soft white-gold light flooding in, mist, rails leading into the light, hopeful, bright sky",
    "end_defeat": "abandoned dark platform in cold fog, a single dying lamp, rusted tracks vanishing into black, bleak",
    "story_platform": "empty night station platform with iron pillars and gas lamps, fog, long perspective",
    "story_boarding": "an open train carriage door on a misty platform, warm light spilling out, steps up into the carriage, night",
    "story_conductor": "a dark carriage vestibule with a brass lamp and a closed door at the end, ominous red light",
    "story_last_light": "long dark railway tunnel with iron ribs receding to a bright pale blue-white glow at the far end, rails in the centre, symmetrical, ominous",
    "story_generic": "dim moody train window view of a passing night landscape, faint lamplight reflections",
}


def main():
    for name in (sys.argv[1:] or list(SCREENS)):
        d = os.path.join(WORK, name)
        os.makedirs(d, exist_ok=True)
        for seed in SEEDS:
            prompt = "cbpstyle, %s, %s" % (STYLE, SCREENS[name])
            subprocess.run([sys.executable, os.path.join(HERE, "comfy_gen.py"), "--prompt", prompt, "--negative", NEG,
                            "--out", os.path.join(d, "cand_%d.png" % seed), "--width", "1536", "--height", "864",
                            "--seed", str(seed), "--lora", "cbpstyle.safetensors", "--lora-strength", "0.6"], check=True)


main()
