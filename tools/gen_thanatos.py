"""Fit XM-05 Thanatos's landscape art onto a card cell.

Run from the mod root:   python tools/gen_thanatos.py

The source art is 95x71 - wider than it is tall, where a Balatro card is 71x95.
Handed to the game as it is, the sprite would be stretched to the card's shape
and the whole thing would be squashed vertically by a third.

So it is fitted to the card's WIDTH and centred, which keeps its proportions
exactly and leaves a band of empty card above and below. Nothing is cropped and
nothing is distorted; the art is simply smaller than the card it sits on.

A card that is genuinely wide is a different job: a Joker's footprint is
G.CARD_W by G.CARD_H for every card in the row, so making one of them landscape
means drawing it outside its own slot rather than fitting it inside one.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "thanatos_art")

CARD_W, CARD_H = 71, 95


def main():
    for scale in (1, 2):
        art = Image.open(os.path.join(SRC, "thanatos%dx.png" % scale)).convert("RGBA")
        w, h = art.size
        target_w = CARD_W * scale
        fitted = art.resize((target_w, max(1, round(h * target_w / w))),
                            Image.NEAREST)

        canvas = Image.new("RGBA", (CARD_W * scale, CARD_H * scale), (0, 0, 0, 0))
        canvas.alpha_composite(fitted, (0, (canvas.height - fitted.height) // 2))
        canvas.save(os.path.join(ROOT, "assets", "%dx" % scale,
                                 "xm05_thanatos.png"))
        print("thanatos %dx: %dx%d art on a %dx%d cell"
              % (scale, fitted.width, fitted.height, canvas.width, canvas.height))


if __name__ == "__main__":
    sys.exit(main())
