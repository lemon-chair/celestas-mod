"""Build assets/{1x,2x}/seals.png from square emblem art.

    python tools/gen_seals.py

Balatro draws a seal as Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, pos) - the
atlas cell is stretched across the entire card, so every cell must be card
shaped (71x95, doubled at 2x) even though the emblem inside it is square.

Geometry measured off vanilla Enhancers.png: all four stock seals (Gold (2,0),
Purple (4,4), Red (5,4), Blue (6,4)) have an opaque bounding box of exactly
27x27 at offset (14, 15), i.e. centred on (27.5, 28.5) - up and left of the
cell centre. Emblems here are centred on that same point so they sit where a
player expects a seal to be.

Scales are integers so the pixel art stays crisp; 2x is exactly double 1x in
both size and offset.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_source  # noqa: E402  (needs the path set above)

CARD_W, CARD_H = 71, 95
# Centre of the vanilla 27x27 emblem within a 71x95 cell.
ANCHOR_X, ANCHOR_Y = 27.5, 28.5

# key -> (source file, emblem size at 1x). Order here is the atlas order,
# so a seal's pos.x is its index in this list.
SEALS = [
    ("Ectoplast", "ectoplast_seal.png", 32),   # 96 -> 32, integer /3
    ("Foppy",     "foppy_seal.png",     32),   # 16 -> 32, integer x2
    ("Gene",      "gene_seal.png",      36),   # 36 -> 36, untouched at 1x
    ("Rose",      "rose_seal.png",      32),   # 16 -> 32, integer x2
    ("Star",      "star_seal.png",      40),   # 20 -> 40, integer x2
]


def build(scale):
    cw, ch = CARD_W * scale, CARD_H * scale
    sheet = Image.new("RGBA", (cw * len(SEALS), ch), (0, 0, 0, 0))
    for i, (key, filename, size1x) in enumerate(SEALS):
        src_path = art_source.path(filename)
        if not os.path.exists(src_path):
            sys.exit("missing source art: " + src_path)
        emblem = Image.open(src_path).convert("RGBA")

        size = size1x * scale
        # NEAREST both ways: these are pixel art, and every ratio here is a
        # whole number, so nothing is resampled unevenly.
        emblem = emblem.resize((size, size), Image.NEAREST)

        x = int(ANCHOR_X - size1x / 2 + 0.5) * scale
        y = int(ANCHOR_Y - size1x / 2 + 0.5) * scale
        if x < 0 or y < 0 or x + size > cw or y + size > ch:
            sys.exit("%s at %dx does not fit its cell" % (key, scale))
        sheet.paste(emblem, (i * cw + x, y), emblem)

    out = os.path.join(ROOT, "assets", "%dx" % scale, "seals.png")
    sheet.save(out)
    print("wrote %s  (%dx%d, %d cells of %dx%d)"
          % (os.path.relpath(out, ROOT), *sheet.size, len(SEALS), cw, ch))


def main():
    for scale in (1, 2):
        build(scale)
    print("\natlas positions:")
    for i, (key, _, size) in enumerate(SEALS):
        print('   %-10s pos = { x = %d, y = 0 }   emblem %dx%d' % (key, i, size, size))


if __name__ == "__main__":
    main()
