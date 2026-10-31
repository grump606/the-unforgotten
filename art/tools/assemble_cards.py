"""Copy the picked candidate for each card to art/layers/cards/<id>/art.png at 800x300.

  python assemble_cards.py

PICKS maps card id -> seed of the chosen candidate (art/work/cards/<id>/cand_<seed>.png).
"""
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PICKS = {
    "bash": 82, "bleed_the_veil": 81, "brace": 92, "cold_steel": 81, "cold_whisper": 81, "confess": 82,
    "counter_stance": 92, "cutting_word": 82, "dig_in": 81, "flurry": 92, "glimpse_exit": 81,
    "grave_chill": 82, "guarded_strike": 81, "hamstring": 92, "heavy_blow": 81, "hold_the_line": 82,
    "iron_resolve": 81, "last_pocket": 82, "last_stand": 82, "lift": 82, "lingering_dread": 82,
    "mark_the_weak": 82, "penance": 82, "pocket_watch": 82, "reckoning": 81, "seance": 81,
    "second_wind": 82, "shoulder_charge": 91, "shove": 82, "sleight": 82, "slip_past": 82,
    "spirit_tithe": 82, "spree": 81, "steady_breath": 82, "sweep": 92,
}

for cid, seed in PICKS.items():
    src = os.path.join(ROOT, "work", "cards", cid, "cand_%d.png" % seed)
    out = os.path.join(ROOT, "layers", "cards", cid)
    os.makedirs(out, exist_ok=True)
    Image.open(src).convert("RGB").resize((800, 300), Image.LANCZOS).save(os.path.join(out, "art.png"))
print("wrote", len(PICKS), "cards")
