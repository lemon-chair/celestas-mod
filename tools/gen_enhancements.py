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

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOWNLOADS = os.path.join(os.path.expanduser("~"), "Downloads")

# name -> (1x source or None to derive from 2x, 2x source, cell size at 1x)
SOURCES = {
    "exo":  ("exo.png",  "exo2.png",  (84, 104)),
    "gash": (None,       "gash2.png", (71, 95)),
}


def main():
    for name, (src1, src2, (cw, ch)) in SOURCES.items():
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

        for img, folder in ((small, "1x"), (big, "2x")):
            out = os.path.join(ROOT, "assets", folder, "enh_%s.png" % name)
            img.save(out)
            print("wrote %-28s %s" % (os.path.relpath(out, ROOT), img.size))

    print("\natlas declarations for main.lua:")
    for name, (_, _, (cw, ch)) in SOURCES.items():
        print('SMODS.Atlas { key = "enh_%s", path = "enh_%s.png", px = %d, py = %d }'
              % (name, name, cw, ch))


if __name__ == "__main__":
    main()
