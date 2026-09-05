"""Build Cryogen's two sheets from tools/cryogen_art/.

Run from the mod root:   python tools/gen_cryogen.py

Cryogen is drawn in two pieces that move independently: a crystal that sits
still in the middle of the card, and a ring that turns around it. So they
cannot be one image - a spinning face would spin the crystal too.

Both come out as ordinary 71x95 card cells, which is what makes the spin cheap:
the ring is drawn over the card by the same Sprite:draw_shader path the Frozen
overlay uses, and that path takes a rotation argument (Sprite:draw_from's `mr`,
engine/sprite.lua:88) which turns the sprite about the card's centre. A sheet
larger than a card would need its own centring; one the same size does not.

The ring is fitted to the card's WIDTH, which leaves it a little clear of the
top and bottom edges. That gap is the point: the ring has to stay inside the
card as it turns, and a ring fitted to the height would sweep its corners off
the sides four times a revolution.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cryogen_art")

CARD_W, CARD_H = 71, 95
# How much of the card's width the ring spans. Full width would put its outer
# edge exactly on the card's, where the corner mask would bite it.
RING_SPAN = 0.94
# The crystal, as a fraction of the ring's diameter. Taken from the source art:
# the centre is 44px across against the ring's 110.
CENTRE_SPAN = 44 / 110


def fit(img, box):
    """`img` scaled to fit a square `box` px on a side, keeping its aspect."""
    w, h = img.size
    scale = box / max(w, h)
    return img.resize((max(1, round(w * scale)), max(1, round(h * scale))),
                      Image.NEAREST)


def cell(art, span, scale):
    """One 71x95 cell with `art` centred, sized to `span` of the card width."""
    canvas = Image.new("RGBA", (CARD_W * scale, CARD_H * scale), (0, 0, 0, 0))
    fitted = fit(art.convert("RGBA"), round(CARD_W * span) * scale)
    canvas.alpha_composite(fitted, ((canvas.width - fitted.width) // 2,
                                    (canvas.height - fitted.height) // 2))
    return canvas


def main():
    for scale in (1, 2):
        centre = Image.open(os.path.join(SRC, "center%dx.png" % scale))
        ring = Image.open(os.path.join(SRC, "ring%dx.png" % scale))

        out = os.path.join(ROOT, "assets", "%dx" % scale)
        cell(centre, RING_SPAN * CENTRE_SPAN, scale).save(
            os.path.join(out, "cryogen.png"))
        cell(ring, RING_SPAN, scale).save(
            os.path.join(out, "cryogen_ring.png"))
        print("cryogen %dx: face and ring written" % scale)


if __name__ == "__main__":
    sys.exit(main())
