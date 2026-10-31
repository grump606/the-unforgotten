"""Copy the picked candidate for each screen to art/layers/screens/<name>/bg.png (1536x864).

  python assemble_screens.py

PICKS maps screen name -> seed of the chosen candidate (art/work/screens/<name>/cand_<seed>.png).
"""
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PICKS = {
    "battle_boss": 102, "battle_deserter": 102, "battle_medium": 102, "battle_neutral": 102,
    "battle_pickpocket": 102, "end_defeat": 101, "end_escape": 113, "pause": 102, "rest": 102,
    "story_boarding": 102, "story_conductor": 102, "story_generic": 101, "story_last_light": 113,
    "story_platform": 101, "vendor": 102, "menu": 201,
}

for name, seed in PICKS.items():
    src = os.path.join(ROOT, "work", "screens", name, "cand_%d.png" % seed)
    out = os.path.join(ROOT, "layers", "screens", name)
    os.makedirs(out, exist_ok=True)
    Image.open(src).convert("RGB").save(os.path.join(out, "bg.png"), optimize=True)
print("wrote", len(PICKS), "screens")
