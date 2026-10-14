"""Build the Iron Stake's chip sheet from the four named exports.

    python tools/gen_stakes.py <folder holding iron_stake_tier1_1x.png .. iron_stake_tier4_1x.png>

One sheet, four cells in a row, the way the base game keeps its stake chips on one sheet: tier 1
is the first cell and tier 4 the last, and items/stakes.lua picks one by position.

The art is 71x71, which is the 1x size, so the 1x sheet is the four of them side by side
untouched. The 2x sheet is each pixel doubled - nearest-neighbour, nothing smoothed - because
the exports have no 2x of their own (the other size in the folder, 54x54, is not twice anything).

The folder is READ ONLY, for the reason tools/import_art.py gives: the originals live outside this
repository and are the only copy there is.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIERS = 4
CELL = 71


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__.strip().splitlines()[0] + "\n" + __doc__.strip().splitlines()[2].strip())
    folder = argv[1]

    sheet = Image.new("RGBA", (CELL * TIERS, CELL), (0, 0, 0, 0))
    seen = {}
    for tier in range(1, TIERS + 1):
        path = os.path.join(folder, "iron_stake_tier%d_1x.png" % tier)
        if not os.path.exists(path):
            sys.exit("no such file: " + path)
        img = Image.open(path).convert("RGBA")
        if img.size != (CELL, CELL):
            sys.exit("%s is %dx%d, and a chip is %dx%d" % (path, img.size[0], img.size[1], CELL, CELL))
        fingerprint = img.tobytes()
        if fingerprint in seen:
            sys.exit("tier %d is the same picture as tier %d" % (tier, seen[fingerprint]))
        seen[fingerprint] = tier
        sheet.paste(img, ((tier - 1) * CELL, 0))

    for scale, name in ((1, "1x"), (2, "2x")):
        out = sheet if scale == 1 else sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
        dest = os.path.join(ROOT, "assets", name, "stake_iron.png")
        out.save(dest)
        print("wrote assets/%s/stake_iron.png (%dx%d)" % (name, out.width, out.height))
    print("Now LOOK at it: every check here is about what the file is, not whether it is the right picture.")


if __name__ == "__main__":
    main(sys.argv)
