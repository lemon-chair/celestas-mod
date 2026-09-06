"""Build the enhancement atlases from the hand-drawn source art.

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

from PIL import Image, ImageChops

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_source  # noqa: E402  (needs the path set above)
import round_corners

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BASE_CARD = os.path.join(ROOT, "tools", "base_card.png")

CARD = (71, 95)

# name: (1x source or None to halve the 2x, 2x source, 1x cell, composite?)
SOURCES = {
    "gash":      (None,            "gash2.png",      CARD, True),
    "eutrophic": ("eutrophic.png", "eutrophic2.png", CARD, False),
    "limestone": ("limestone.png", "limestone2.png", CARD, False),
    "driftwood": ("driftwood.png", "driftwood2.png", CARD, False),
    # Sandstone was drawn at both sizes already, so neither is halved from the
    # other, and it is full-card art like the rest of the stones - no base to
    # composite underneath.
    "sandstone": ("sandstone_card1x.png", "sandstone_card2x.png", CARD, False),
    # Scoria, what Polish makes of a Limestone card. Drawn at both sizes and
    # full-card, like the other stones.
    "scoria":    ("scoria_card1x.png", "scoria_card2x.png", CARD, False),
    # Foliage keeps its rank and suit - the pips draw over it - so it is an
    # ordinary enhancement like Gold or Steel rather than one of the stones.
    "foliage":   ("foliage_card1x.png", "foliage_card2x.png", CARD, False),
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


def round_frost(frost, scale):
    """The frost pane cut to the round-joker silhouette instead of the card's.

    Frozen is drawn OVER whatever it lands on, so on a joker whose art is a
    circle the card-shaped pane hangs in the air around it. The shape is taken
    from Boosfer's own alpha rather than a circle drawn here, so the pane and
    the sprite it covers cannot drift apart.
    """
    art = Image.open(os.path.join(ROOT, "assets", "%dx" % scale,
                                  "boosfer.png")).convert("RGBA")
    if art.size != frost.size:
        sys.exit("boosfer is %s, frost is %s" % (art.size, frost.size))
    alpha = ImageChops.multiply(frost.split()[3], art.split()[3])
    out = frost.copy()
    out.putalpha(alpha)
    return out


def composite(overlay, w, h):
    """Put the vanilla card body under an overlay-style enhancement."""
    base = Image.open(BASE_CARD).convert("RGBA").resize((w, h), Image.NEAREST)
    base.alpha_composite(overlay)
    return base


def load_pair(src1, src2, cw, ch):
    big = Image.open(art_source.path(src2)).convert("RGBA")
    if big.size != (cw * 2, ch * 2):
        sys.exit("%s is %s, expected %s" % (src2, big.size, (cw * 2, ch * 2)))
    if src1:
        small = Image.open(art_source.path(src1)).convert("RGBA")
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


def already_built(name):
    """True when both atlases for `name` are already on disk."""
    return all(os.path.exists(os.path.join(ROOT, "assets", f, "%s.png" % name))
               for f in ("1x", "2x"))


def main():
    for name, (src1, src2, (cw, ch), needs_base) in SOURCES.items():
        # The source art is not in this repository, and the folder it lives
        # in has moved before (see tools/art_source.py). An enhancement whose
        # source has gone but whose atlas is already built is left alone
        # rather than taking the whole run down with it - otherwise adding one
        # enhancement means finding the art for every one that came before.
        if art_source.find(src2) is None:
            if already_built("enh_" + name):
                print("skipped %-26s (no source, atlas already built)" % name)
                continue
            sys.exit("%s: no source at %s and no atlas built"
                     % (name, art_source.path(src2)))
        small, big = load_pair(src1, src2, cw, ch)
        for img, folder, scale in ((small, "1x", 1), (big, "2x", 2)):
            out = composite(img, cw * scale, ch * scale) if needs_base else img
            save(shape_corners(out), "enh_%s" % name, folder)

    # Frozen is an overlay drawn over a whole card, so it takes the card
    # silhouette but never the card body underneath.
    fsmall, fbig = load_pair("frozen.png", "frozen2.png", CARD[0], CARD[1])
    save(shape_corners(fsmall), "frozen", "1x")
    save(shape_corners(fbig), "frozen", "2x")
    # ...and again for the jokers that are a circle rather than a card.
    save(round_frost(fsmall, 1), "frozen_round", "1x")
    save(round_frost(fbig, 2), "frozen_round", "2x")

    small, big = load_pair(EXO[0], EXO[1], EXO[2][0], EXO[2][1])
    for scale, folder in ((1, "1x"), (2, "2x")):
        body = Image.open(BASE_CARD).convert("RGBA").resize(
            (CARD[0] * scale, CARD[1] * scale), Image.NEAREST)
        save(shape_corners(body), "enh_exo", folder)
    # The frame ships in a CARD-SIZED cell, not its native 84x104.
    #
    # Sprite:draw_from centres a box sized to the card and then draws the quad
    # at its own pixel size, so an 84-wide cell renders 84/71 too big AND
    # overflows down-right out of that box - too large and off-centre at once.
    # Fitting the art into a card-sized cell restores every assumption
    # draw_from makes; CelestasMod.EXO_OVERHANG then does the enlarging, and
    # 84/71 - 1 puts the frame back at exactly its authored size.
    for art, folder, scale in ((small, "1x", 1), (big, "2x", 2)):
        cw, ch = CARD[0] * scale, CARD[1] * scale
        fit = cw / art.width          # uniform, so the frame keeps its shape
        sized = art.resize((cw, max(1, round(art.height * fit))), Image.NEAREST)
        cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cell.paste(sized, (0, (ch - sized.height) // 2), sized)
        save(cell, "enh_exo_frame", folder)

    print("\natlas declarations for main.lua:")
    for name, (_, _, (cw, ch), _b) in SOURCES.items():
        print('SMODS.Atlas { key = "enh_%s", path = "enh_%s.png", px = %d, py = %d }'
              % (name, name, cw, ch))
    print('SMODS.Atlas { key = "enh_exo", path = "enh_exo.png", px = %d, py = %d }'
          % CARD)
    print('SMODS.Atlas { key = "enh_exo_frame", path = "enh_exo_frame.png",'
          ' px = %d, py = %d }' % CARD)


if __name__ == "__main__":
    main()
