"""Build the enhancement atlases from source art in Downloads.

    python tools/gen_enhancements.py

Writes assets/{1x,2x}/enh_<name>.png. One atlas per enhancement.

Two things worth knowing about how Balatro draws these:

1. An enhancement REPLACES the card body. A playing card's white body comes
   from its centre sprite - vanilla c_base is 69x93 opaque - while
   children.front carries only the pips, 4.4% opaque. So overlay-style art
   needs the card body composited underneath or the card renders empty.
   `needs_base` controls that; full-card art does not need it.

2. An enhancement's atlas cell is stretched onto the card rect whatever size
   the cell is. An 84x104 cell does NOT render bigger than a 71x95 one - it
   just gets squashed to card size. Exo is meant to overhang the card as a
   thick border, which the centre sprite cannot do at all, so its frame is
   split into its own atlas and drawn separately at a larger scale (see
   enhancements/enhancements.lua). What lands in enh_exo.png is only the card
   body that sits underneath it.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import round_corners

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOWNLOADS = os.path.join(os.path.expanduser("~"), "Downloads")
BASE_CARD = os.path.join(ROOT, "tools", "base_card.png")

CARD = (71, 95)

# name: (1x source or None to halve the 2x, 2x source, 1x cell, composite?)
SOURCES = {
    "gash":      (None,            "gash2.png",      CARD, True),
    "eutrophic": ("eutrophic.png", "eutrophic2.png", CARD, False),
    "limestone": ("limestone.png", "limestone2.png", CARD, False),
    "driftwood": ("driftwood.png", "driftwood2.png", CARD, False),
}

# Exo is handled separately: its frame is drawn oversized rather than squashed
# into the card rect.
EXO = ("exo.png", "exo2.png", (84, 104))


def shape_corners(img):
    """Cut the vanilla card silhouette out of a sprite.

    An enhancement replaces the card body, so square-cornered art gives a
    square-cornered card. round_corners.PROFILE is the silhouette measured off
    vanilla Enhancers.png. Masking already-shaped art is a no-op.
    """
    mask = round_corners.build_mask(1)
    if mask.size != img.size:
        mask = mask.resize(img.size, Image.NEAREST)
    alpha = Image.composite(img.split()[3], Image.new("L", img.size, 0), mask)
    out = img.copy()
    out.putalpha(alpha)
    return out


def composite(overlay, w, h):
    """Put the vanilla card body under an overlay-style enhancement."""
    base = Image.open(BASE_CARD).convert("RGBA").resize((w, h), Image.NEAREST)
    base.alpha_composite(overlay)
    return base


def load_pair(src1, src2, cw, ch):
    big = Image.open(os.path.join(DOWNLOADS, src2)).convert("RGBA")
    if big.size != (cw * 2, ch * 2):
        sys.exit("%s is %s, expected %s" % (src2, big.size, (cw * 2, ch * 2)))
    if src1:
        small = Image.open(os.path.join(DOWNLOADS, src1)).convert("RGBA")
        if small.size != (cw, ch):
            sys.exit("%s is %s, expected %s" % (src1, small.size, (cw, ch)))
    else:
        # NEAREST keeps the pixel art crisp and makes the 1x an exact halving
        # of the 2x rather than a separately-authored crop.
        small = big.resize((cw, ch), Image.NEAREST)
    return small, big


def save(img, name, folder):
    out = os.path.join(ROOT, "assets", folder, "%s.png" % name)
    img.save(out)
    print("wrote %-34s %s" % (os.path.relpath(out, ROOT), img.size))


def main():
    for name, (src1, src2, (cw, ch), needs_base) in SOURCES.items():
        small, big = load_pair(src1, src2, cw, ch)
        for img, folder, scale in ((small, "1x", 1), (big, "2x", 2)):
            out = composite(img, cw * scale, ch * scale) if needs_base else img
            save(shape_corners(out), "enh_%s" % name, folder)

    # Frozen is an overlay drawn over a whole card, so it takes the card
    # silhouette but never the card body underneath.
    fsmall, fbig = load_pair("frozen.png", "frozen2.png", CARD[0], CARD[1])
    save(shape_corners(fsmall), "frozen", "1x")
    save(shape_corners(fbig), "frozen", "2x")

    small, big = load_pair(EXO[0], EXO[1], EXO[2][0], EXO[2][1])
    for scale, folder in ((1, "1x"), (2, "2x")):
        body = Image.open(BASE_CARD).convert("RGBA").resize(
            (CARD[0] * scale, CARD[1] * scale), Image.NEAREST)
        save(shape_corners(body), "enh_exo", folder)
    save(small, "enh_exo_frame", "1x")
    save(big, "enh_exo_frame", "2x")

    print("\natlas declarations for main.lua:")
    for name, (_, _, (cw, ch), _b) in SOURCES.items():
        print('SMODS.Atlas { key = "enh_%s", path = "enh_%s.png", px = %d, py = %d }'
              % (name, name, cw, ch))
    print('SMODS.Atlas { key = "enh_exo", path = "enh_exo.png", px = %d, py = %d }'
          % CARD)
    print('SMODS.Atlas { key = "enh_exo_frame", path = "enh_exo_frame.png",'
          ' px = %d, py = %d }' % EXO[2])


if __name__ == "__main__":
    main()
