"""Build the enhancement atlases from source art in Downloads.

    python tools/gen_enhancements.py

Writes assets/{1x,2x}/enh_<name>.png. One atlas per enhancement because they
do not share a cell size: Exo's frame overhangs the card (84x104 for a 71x95
card) while Gash sits inside it.

The `enh_` prefix keeps these out of gen_roster.py (which would otherwise make
jokers of them) and round_corners.py (which would try to mask them).

Gash's supplied 1x was 71x92 - the 2x downscaled and then cropped a row off
the top - which would have sat 3px short in a 71x95 cell and drifted out of
step with its own 2x. It is rebuilt from gash2.png instead so both scales come
from one source and line up exactly.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import round_corners

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOWNLOADS = os.path.join(os.path.expanduser("~"), "Downloads")

# name -> (1x source or None to derive from 2x, 2x source, cell size at 1x)
SOURCES = {
    # name: (1x source or None to halve the 2x, 2x source, 1x cell, composite?)
    # composite=True puts the vanilla card body underneath - only needed for
    # overlay art that would otherwise leave the card with no body.
    "exo":       ("exo.png",       "exo2.png",       (84, 104), True),
    "gash":      (None,            "gash2.png",      (71, 95),  True),
    "eutrophic": ("eutrophic.png", "eutrophic2.png", (71, 95),  False),
    "limestone": ("limestone.png", "limestone2.png", (71, 95),  False),
    "driftwood": ("driftwood.png", "driftwood2.png", (71, 95),  False),
}


BASE_CARD = os.path.join(ROOT, "tools", "base_card.png")


def shape_corners(img):
    """Cut the vanilla card silhouette out of an enhancement sprite.

    An enhancement replaces the card body, so square-cornered art gives a
    square-cornered card - eutrophic's is 100% opaque and showed exactly that.
    round_corners.PROFILE is the silhouette measured off vanilla Enhancers.png;
    the mask is built at card size and scaled to the cell, which is correct
    even for Exo's larger cell because that cell maps onto the card rect.
    Masking already-shaped art is a no-op, so this is safe to apply to all.
    """
    mask = round_corners.build_mask(1)
    if mask.size != img.size:
        mask = mask.resize(img.size, Image.NEAREST)
    alpha = Image.composite(img.split()[3], Image.new("L", img.size, 0), mask)
    out = img.copy()
    out.putalpha(alpha)
    return out


def composite(overlay, w, h):
    """Put the vanilla card body under an overlay-style enhancement.

    This is the whole reason Gash rendered as an invisible card. A playing
    card's white body comes from its CENTER sprite - vanilla c_base is 69x93
    opaque - while children.front carries only the pips (4.4% opaque). An
    enhancement replaces the center, so art that is mostly transparent removes
    the body and leaves pips floating over nothing.

    Baking c_base underneath makes these read as a normal card wearing the
    overlay. The body is stretched to the cell, so Exo's larger cell still maps
    exactly onto the card rect.
    """
    base = Image.open(BASE_CARD).convert("RGBA").resize((w, h), Image.NEAREST)
    base.alpha_composite(overlay)
    return base


def main():
    for name, (src1, src2, (cw, ch), needs_base) in SOURCES.items():
        big = Image.open(os.path.join(DOWNLOADS, src2)).convert("RGBA")
        if big.size != (cw * 2, ch * 2):
            sys.exit("%s is %s, expected %s" % (src2, big.size, (cw * 2, ch * 2)))

        if src1:
            small = Image.open(os.path.join(DOWNLOADS, src1)).convert("RGBA")
            if small.size != (cw, ch):
                sys.exit("%s is %s, expected %s" % (src1, small.size, (cw, ch)))
        else:
            # NEAREST keeps the pixel art crisp and makes the 1x an exact
            # halving of the 2x rather than a separately-authored crop.
            small = big.resize((cw, ch), Image.NEAREST)

        for img, folder, scale in ((small, "1x", 1), (big, "2x", 2)):
            out = os.path.join(ROOT, "assets", folder, "enh_%s.png" % name)
            out_img = composite(img, cw * scale, ch * scale) if needs_base else img
            shape_corners(out_img).save(out)
            print("wrote %-28s %s" % (os.path.relpath(out, ROOT), img.size))

    print("\natlas declarations for main.lua:")
    for name, (_, _, (cw, ch), _b) in SOURCES.items():
        print('SMODS.Atlas { key = "enh_%s", path = "enh_%s.png", px = %d, py = %d }'
              % (name, name, cw, ch))


if __name__ == "__main__":
    main()
