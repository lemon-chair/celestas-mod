"""Builds consumable card art from a bare object image.

Source art for consumables arrives as the object alone on transparency, at
whatever size it was drawn - the Milk Bottle is 130x221, which is both the
wrong size and the wrong aspect for a 71x95 card cell. Stretching it to fit
would squash the bottle, so it is scaled to fit INSIDE the cell with its aspect
kept and centred on the card base.

base_card.png is the same 71x95 card silhouette every sprite in this mod is
masked to, so the result already has vanilla's rounded corners and needs no
pass from round_corners.py.

    python tools/gen_consumable_art.py

Re-running is idempotent: the output is rebuilt from the sources every time.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "tools", "base_card.png")
CARD_W, CARD_H = 71, 95

# Fraction of the card the art may occupy. Short of 1.0 so the object sits
# inside the card's border rather than running into the rounded corners.
INSET = 0.82

# key -> source path, relative to the home directory. Written this way
# rather than absolutely because an absolute one carries whichever
# account happened to run the script, and this file is committed.
SOURCES = {
    "milk_bottle": os.path.join("Documents", "VTuberTCG", "assets",
                                "support", "milk_bottle.png"),
}


def build(source_path, scale):
    base = Image.open(BASE).convert("RGBA")
    w, h = CARD_W * scale, CARD_H * scale
    if base.size != (w, h):
        base = base.resize((w, h), Image.NEAREST)

    art = Image.open(source_path).convert("RGBA")
    # Trim the transparent margin first, or the padding in the source decides
    # how big the object looks rather than the inset here.
    box = art.split()[3].getbbox()
    if box:
        art = art.crop(box)

    budget_w, budget_h = w * INSET, h * INSET
    ratio = min(budget_w / art.width, budget_h / art.height)
    art = art.resize((max(1, round(art.width * ratio)),
                      max(1, round(art.height * ratio))), Image.LANCZOS)

    base.alpha_composite(art, ((w - art.width) // 2, (h - art.height) // 2))
    return base


def main():
    written = 0
    for key, source in sorted(SOURCES.items()):
        source = os.path.join(os.path.expanduser("~"), source)
        if not os.path.exists(source):
            print(f"  MISSING {key}: {source}")
            continue
        for folder, scale in (("1x", 1), ("2x", 2)):
            out = os.path.join(ROOT, "assets", folder, key + ".png")
            build(source, scale).save(out)
            written += 1
        print(f"  {key}: {CARD_W}x{CARD_H} and {CARD_W*2}x{CARD_H*2}")
    print(f"wrote {written} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
