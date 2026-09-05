"""Build XM-05 Thanatos's two sheets from tools/thanatos_art/.

Run from the mod root:   python tools/gen_thanatos.py

Thanatos is a LANDSCAPE Joker: 95x71 where a card is 71x95. It is meant to be
too wide for its slot and to overhang the Jokers either side of it, which is
not something a card sprite can do - the game draws every Joker's face stretched
to fit G.CARD_W by G.CARD_H, so handing it over as a face would squash it into
portrait.

So it comes out as two sheets:

  * xm05_thanatos.png       a transparent 71x95 card cell - the Joker's own
                            face, which draws nothing
  * xm05_thanatos_wide.png  a 95x95 cell holding the art, drawn over the card
                            as an overlay at its true size

The overlay path (Sprite:draw_from) scales the sheet by the CARD's dimensions
rather than the sheet's, so 71 pixels across is exactly one card width whatever
the sheet is. That is what makes 95 pixels come out 95/71 of a card wide and
overhang - and it is why the wide sheet is 95 tall rather than 71: at 95 the
vertical mapping is the card's own and needs no correction, leaving only the
horizontal overhang to offset.

The corners are Balatro's, turned a quarter turn: the mask round_corners builds
for a portrait card, rotated, is the silhouette a landscape one would have.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import round_corners  # noqa: E402  (needs the path set above)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "thanatos_art")

CARD_W, CARD_H = 71, 95
# The wide sheet is a square of the long side, so the art's own height sits
# inside the card's without any vertical offset at draw time.
WIDE = CARD_H


def main():
    for scale in (1, 2):
        art = Image.open(os.path.join(SRC, "thanatos%dx.png" % scale)).convert("RGBA")
        want = (CARD_H * scale, CARD_W * scale)
        if art.size != want:
            art = art.resize(want, Image.NEAREST)

        # Balatro's corner silhouette, a quarter turn round: the portrait mask
        # rotated is exactly the landscape one.
        mask = round_corners.build_mask(scale).rotate(90, expand=True)
        assert mask.size == art.size, (mask.size, art.size)
        alpha = art.split()[3].point(lambda a: a)
        art.putalpha(Image.composite(alpha, Image.new("L", art.size, 0), mask))

        out = os.path.join(ROOT, "assets", "%dx" % scale)

        # The face draws nothing: the art is the overlay below, and a face
        # under it would be the same picture squashed into portrait.
        blank = Image.new("RGBA", (CARD_W * scale, CARD_H * scale), (0, 0, 0, 0))
        blank.save(os.path.join(out, "xm05_thanatos.png"))

        wide = Image.new("RGBA", (WIDE * scale, WIDE * scale), (0, 0, 0, 0))
        wide.alpha_composite(art, (0, (wide.height - art.height) // 2))
        wide.save(os.path.join(out, "xm05_thanatos_wide.png"))

        print("thanatos %dx: %dx%d art on a %dx%d overlay, empty face"
              % (scale, art.width, art.height, wide.width, wide.height))


if __name__ == "__main__":
    sys.exit(main())
