"""Generate card-art candidates (wide 8:3) with the style LoRA.

  python gen_cards.py [card_id ...]     (no args = all cards)

Writes art/work/cards/<id>/cand_<seed>.png. Pick one, copy it to art/work/cards/<id>/pick.png and run
assemble_cards.py to produce art/layers/cards/<id>/art.png (800x300).
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "..", "work", "cards")
STYLE = ("dark painterly illustration, gouache and oil texture, visible brush strokes, soot-black shadows, "
         "single warm light source, gothic mood, bold readable composition, subject centred")
NEG = "text, letters, watermark, signature, frame, border, blurry, photo, 3d render, multiple panels, train, locomotive"
PALETTE = {
    "": "cream and warm grey tones",
    "deserter": "rust orange and steel grey tones",
    "pickpocket": "deep teal and tarnished brass tones",
    "medium": "bruised violet and bone white tones",
}
SEEDS = tuple(int(s) for s in os.environ.get("CARD_SEEDS", "81,82").split(","))

# id: (class, subject)
CARDS = {
    "brace": ("", "a medieval knight crouched behind a raised heavy iron shield, bracing against a blow, seen from the front"),
    "flurry": ("", "a fencer lunging with three rapid sword thrusts, motion trails of steel in the dark, a hooded duelist"),
    "glimpse_exit": ("", "a lit doorway at the far end of a dark corridor"),
    "shove": ("", "two strong hands shoving a figure backwards"),
    "slip_past": ("", "a shadowy figure slipping past a distracted guard"),
    "sweep": ("", "a warrior in a long coat swinging a great scythe in a wide low arc, several figures knocked back"),
    "bash": ("deserter", "a soldier smashing an iron shield into an enemy"),
    "cold_steel": ("deserter", "a bare steel blade glinting in cold light"),
    "counter_stance": ("deserter", "a medieval soldier in a long greatcoat with a sword raised in a defensive parry, seen from the front"),
    "dig_in": ("deserter", "a soldier planting his boots in mud behind sandbags"),
    "guarded_strike": ("deserter", "a sword thrust from behind a shield"),
    "heavy_blow": ("deserter", "a huge hammer swung down in a heavy overhead blow"),
    "hold_the_line": ("deserter", "a line of soldiers with shields locked together"),
    "iron_resolve": ("deserter", "a clenched iron gauntlet fist"),
    "last_stand": ("deserter", "a lone wounded soldier standing among the fallen"),
    "shoulder_charge": ("deserter", "a heavily armoured knight charging forward shoulder first, a pauldron smashing through a wooden door"),
    "steady_breath": ("deserter", "a soldier with closed eyes breathing out cold steam"),
    "cutting_word": ("pickpocket", "a razor blade and a sly whispering smirk"),
    "hamstring": ("pickpocket", "a thief with a small curved knife slashing the back of a guard leg, the guard stumbling"),
    "last_pocket": ("pickpocket", "a hand sliding into the last coat pocket"),
    "lift": ("pickpocket", "a nimble hand lifting a wallet from a coat"),
    "mark_the_weak": ("pickpocket", "a chalk mark scrawled on the back of a coat"),
    "pocket_watch": ("pickpocket", "a brass pocket watch swinging on its chain"),
    "second_wind": ("pickpocket", "a thief catching his breath in a dark alley"),
    "sleight": ("pickpocket", "a hand performing a coin and card trick"),
    "spree": ("pickpocket", "coins and watches flying through the air"),
    "bleed_the_veil": ("medium", "a blood red tear opening in a thin pale veil"),
    "cold_whisper": ("medium", "a pale ghostly mouth whispering in the dark"),
    "confess": ("medium", "a kneeling figure confessing by candlelight"),
    "grave_chill": ("medium", "frost creeping over old gravestones"),
    "lingering_dread": ("medium", "a dark silhouette standing at a window at night"),
    "penance": ("medium", "a kneeling figure bound in chains in candlelight"),
    "reckoning": ("medium", "a spectral hand holding balanced scales"),
    "seance": ("medium", "a circle of candles around a table with spirits rising"),
    "spirit_tithe": ("medium", "coins offered in an open palm to a ghost"),
}


def main():
    ids = sys.argv[1:] or list(CARDS)
    for cid in ids:
        cls, subject = CARDS[cid]
        d = os.path.join(WORK, cid)
        os.makedirs(d, exist_ok=True)
        for seed in SEEDS:
            prompt = "cbpstyle, %s, %s, %s, wide composition" % (STYLE, subject, PALETTE[cls])
            subprocess.run([sys.executable, os.path.join(HERE, "comfy_gen.py"), "--prompt", prompt,
                            "--negative", NEG, "--out", os.path.join(d, "cand_%d.png" % seed),
                            "--width", "1536", "--height", "576", "--seed", str(seed),
                            "--lora", "cbpstyle.safetensors", "--lora-strength", "0.6"], check=True)


main()
