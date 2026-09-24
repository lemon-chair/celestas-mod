"""Build assets/{1x,2x}/sleeves.png - a Card Sleeves sleeve for every deck.

    python tools/gen_sleeves.py

Card Sleeves draws a sleeve as its own 73x95 frame: a pocket cut into the top,
a white stroke round the window and a grey lip along the bottom. None of this
mod's decks had one, so each is built from the deck's own face, which is what
makes a sleeve read as that deck.

The frame is Card Sleeves' own, not a copy of it:

  * its blank sleeve says WHERE the deck shows through - every pixel of that
    sleeve's one fill green is window or band - and
  * its four plain sleeves - Red, Blue, Yellow, Green - say what the rest is.
    Where all four agree, the pixel is frame every sleeve shares (the grey
    lip), and it is copied. Where they differ, the pixel is drawn in that
    sleeve's own colour (the outline of the band and pocket), so it is the
    deck's colour here: the face's pixel, shaded by the same ratio the blank
    shades its own green by.

The stroke is the blank's plain white. A window pixel takes the deck face's
pixel from the same place, one column in (the face is 71 wide and the sleeve
73). Where the face has none - its own rounded corners - the lip's middle grey
stands in.

Read from the Card Sleeves mod, so it has to be installed to rebuild the
sheets; the built sheets are what ships. The deck faces are the ones
gen_decks.py builds decks.png from, in the same order, so a sleeve's `pos.x`
is its deck's.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_decks import ART, DECKS                             # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODS = os.path.dirname(ROOT)

SLEEVE_W, SLEEVE_H = 73, 95
CARD_W = 71
# Cells of Card Sleeves' sheet, (column, row).
BLANK_CELL = (1, 3)
PLAIN_CELLS = [(0, 0), (1, 0), (2, 0), (3, 0)]  # Red, Blue, Yellow, Green
FILL = (0, 156, 45, 255)  # the blank sleeve's window green
GAP = (75, 75, 75, 255)   # the lip's middle grey
WHITE = (255, 255, 255, 255)


def card_sleeves_sheet(scale):
    """Card Sleeves' own sheet, from whichever folder it is installed in."""
    for name in sorted(os.listdir(MODS)):
        manifest = os.path.join(MODS, name, "CardSleeves.json")
        if os.path.exists(manifest):
            return os.path.join(MODS, name, "assets", "%dx" % scale, "sleeves.png")
    sys.exit("Card Sleeves is not installed in %s; it is needed to build "
             "the sleeve frames" % MODS)


def cell(sheet, pos, scale):
    w, h = SLEEVE_W * scale, SLEEVE_H * scale
    return sheet.crop((pos[0] * w, pos[1] * h, (pos[0] + 1) * w, (pos[1] + 1) * h))


def build(scale):
    sheet = Image.open(card_sleeves_sheet(scale)).convert("RGBA")
    blank = cell(sheet, BLANK_CELL, scale)
    plain = [cell(sheet, pos, scale).load() for pos in PLAIN_CELLS]
    w, h = blank.size
    inset = (SLEEVE_W - CARD_W) * scale // 2

    out = Image.new("RGBA", (w * len(DECKS), h), (0, 0, 0, 0))
    for i, (key, stem) in enumerate(DECKS):
        path = os.path.join(ART, "%s_%dx.png" % (stem, scale))
        if not os.path.exists(path):
            sys.exit("missing deck face: " + path)
        face = Image.open(path).convert("RGBA")
        if face.size != (CARD_W * scale, h):
            sys.exit("%s is %dx%d, expected %dx%d"
                     % (path, face.width, face.height, CARD_W * scale, h))

        sleeve = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px, bl, fc = sleeve.load(), blank.load(), face.load()
        for y in range(h):
            for x in range(w):
                b = bl[x, y]
                if b[3] == 0:
                    continue
                if b == WHITE:
                    px[x, y] = WHITE
                    continue

                fx = x - inset
                shown = fc[fx, y] if 0 <= fx < face.width else (0, 0, 0, 0)
                if not shown[3]:
                    shown = GAP
                if b == FILL:
                    px[x, y] = shown
                    continue

                shared = {p[x, y] for p in plain}
                if len(shared) == 1:
                    px[x, y] = shared.pop()
                    continue
                ratio = b[1] / FILL[1]
                px[x, y] = tuple(min(255, int(c * ratio)) for c in shown[:3]) + (255,)
        out.paste(sleeve, (i * w, 0))

    dest = os.path.join(ROOT, "assets", "%dx" % scale, "sleeves.png")
    out.save(dest)
    print("wrote %s  (%dx%d, %d cells of %dx%d)"
          % (os.path.relpath(dest, ROOT), out.width, out.height,
             len(DECKS), w, h))


def main():
    for scale in (1, 2):
        build(scale)
    print("\natlas positions:")
    for i, (key, _) in enumerate(DECKS):
        print("   %-10s pos = { x = %d, y = 0 }" % (key, i))


if __name__ == "__main__":
    main()
