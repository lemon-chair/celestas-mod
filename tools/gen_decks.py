"""Build assets/{1x,2x}/decks.png from the per-deck faces in tools/deck_art/.

    python tools/gen_decks.py

The sheet was hand-assembled until there were six of them. Each deck's face is
now its own file and the order of DECKS below is the atlas order, so a Back's
`pos.x` is its index in that list - the same arrangement gen_seals.py uses.

The faces live in tools/deck_art/ rather than in assets/, deliberately:
gen_roster.py walks assets/1x and treats every PNG it does not recognise as a
Joker needing a placeholder, so six deck faces sitting there would turn into
six imaginary Jokers.

Corners are masked here rather than by round_corners.py. That tool skips
decks.png - it is six card-sized cells in a row, not one card, and masking the
sheet as a whole would cut it down to the first cell's corners - so the faces
are masked individually on the way in, which is the same silhouette and the
same idempotence.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import round_corners                                        # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "tools", "deck_art")

CARD_W, CARD_H = 71, 95

# key -> face file stem. The order IS the atlas order.
DECKS = [
    ("founders", "founders"),
    ("plaid", "plaid"),
    ("ecstasy", "ecstasy"),
    ("hell", "hell"),
    ("blizzard", "blizzard"),
    ("rain", "rain"),
    ("verdant", "verdant"),
]


def build(scale):
    cw, ch = CARD_W * scale, CARD_H * scale
    mask = round_corners.build_mask(scale)
    sheet = Image.new("RGBA", (cw * len(DECKS), ch), (0, 0, 0, 0))

    for i, (key, stem) in enumerate(DECKS):
        path = os.path.join(ART, "%s_%dx.png" % (stem, scale))
        if not os.path.exists(path):
            sys.exit("missing deck face: " + path)
        face = Image.open(path).convert("RGBA")
        if face.size != (cw, ch):
            sys.exit("%s is %dx%d, expected %dx%d"
                     % (path, face.width, face.height, cw, ch))

        # Binary mask, so re-running changes nothing about an already-masked
        # face - the same property round_corners.py relies on.
        alpha = face.split()[3]
        alpha = Image.eval(alpha, lambda a: a)
        face.putalpha(Image.composite(alpha, Image.new("L", face.size, 0), mask))
        sheet.paste(face, (i * cw, 0))

    out = os.path.join(ROOT, "assets", "%dx" % scale, "decks.png")
    sheet.save(out)
    print("wrote %s  (%dx%d, %d cells of %dx%d)"
          % (os.path.relpath(out, ROOT), sheet.width, sheet.height,
             len(DECKS), cw, ch))


def main():
    for scale in (1, 2):
        build(scale)
    print("\natlas positions:")
    for i, (key, _) in enumerate(DECKS):
        print("   %-10s pos = { x = %d, y = 0 }" % (key, i))


if __name__ == "__main__":
    main()
