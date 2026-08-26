"""Build the Driftwood card front: an Ace with the rank glyph removed.

    python tools/gen_driftwood_fronts.py

Driftwood counts as any rank, so printing a rank on it is misleading. Pointing
its front at the Ace of its own suit gives the large central pip, but leaves an
"A" in the corners. This strips that glyph and keeps everything else.

Source art comes from the game itself: Balatro.exe is a LOVE archive, so both
resources/textures/1x/8BitDeck.png and the 2x version can be read straight out
of it. That matters - upscaling the 1x would leave Driftwood visibly coarser
than every other card at 2x.

The glyph is found rather than hardcoded. An Ace sprite has five bands of
content down its height:
    A  /  small pip  /  big central pip  /  small pip  /  A (rotated)
so the first and last bands are the rank glyph at any scale.

Output: assets/{1x,2x}/driftwood_fronts.png, four cells in SUIT_ORDER.
"""
import io
import os
import sys
import zipfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BALATRO = r"C:\Program Files (x86)\Steam\steamapps\common\Balatro\Balatro.exe"

CARD_W, CARD_H = 71, 95
ACE_COLUMN = 12
# Row index in 8BitDeck matches the suit's y in G.P_CARDS.
SUIT_ORDER = ["Hearts", "Clubs", "Diamonds", "Spades"]


def content_bands(alpha, height, width):
    """Contiguous runs of rows that contain any opaque pixel."""
    bands, start = [], None
    for y in range(height):
        filled = any(alpha.getpixel((x, y)) > 0 for x in range(width))
        if filled and start is None:
            start = y
        elif not filled and start is not None:
            bands.append((start, y - 1))
            start = None
    if start is not None:
        bands.append((start, height - 1))
    return bands


def strip_rank(ace):
    """Clear the first and last content bands - the two rank glyphs."""
    w, h = ace.size
    bands = content_bands(ace.split()[3], h, w)
    if len(bands) < 3:
        sys.exit("unexpected Ace layout: found %d content bands" % len(bands))
    out = ace.copy()
    blank = Image.new("RGBA", (w, 0), (0, 0, 0, 0))
    for top, bottom in (bands[0], bands[-1]):
        out.paste(Image.new("RGBA", (w, bottom - top + 1), (0, 0, 0, 0)), (0, top))
    return out, bands


def main():
    if not os.path.exists(BALATRO):
        sys.exit("Balatro.exe not found at " + BALATRO)
    archive = zipfile.ZipFile(BALATRO)

    for scale, folder in ((1, "1x"), (2, "2x")):
        name = "resources/textures/%s/8BitDeck.png" % folder
        deck = Image.open(io.BytesIO(archive.read(name))).convert("RGBA")
        cw, ch = CARD_W * scale, CARD_H * scale

        sheet = Image.new("RGBA", (cw * len(SUIT_ORDER), ch), (0, 0, 0, 0))
        for i, suit in enumerate(SUIT_ORDER):
            box = (ACE_COLUMN * cw, i * ch, (ACE_COLUMN + 1) * cw, (i + 1) * ch)
            stripped, bands = strip_rank(deck.crop(box))
            sheet.paste(stripped, (i * cw, 0))
            if scale == 1:
                print("   %-9s bands %s -> cleared %s and %s"
                      % (suit, len(bands), bands[0], bands[-1]))

        out = os.path.join(ROOT, "assets", folder, "driftwood_fronts.png")
        sheet.save(out)
        print("wrote %-38s %s" % (os.path.relpath(out, ROOT), sheet.size))

    print("\natlas declaration for main.lua:")
    print('SMODS.Atlas { key = "driftwood_fronts", path = "driftwood_fronts.png",'
          ' px = %d, py = %d }' % (CARD_W, CARD_H))
    print("suit order:", ", ".join("%s=%d" % (s, i) for i, s in enumerate(SUIT_ORDER)))


if __name__ == "__main__":
    main()
