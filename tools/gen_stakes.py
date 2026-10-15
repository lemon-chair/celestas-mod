"""Build a stake's chip sheet from its four named exports.

    python tools/gen_stakes.py <folder holding the exports> <metal> [<metal> ...]

    metal      the files it reads, in <folder>
    iron       iron_stake_tier1_1x.png .. iron_stake_tier4_1x.png   (71x71)
    brass      brass_stake_t1.png .. brass_stake_t4.png             (54x54)
    rose       rose_stake_t1.png .. rose_stake_t4.png               (54x54)

One sheet a metal, four cells in a row, the way the base game keeps its stake chips on one sheet:
tier 1 is the first cell and tier 4 the last, and items/stakes.lua picks one by position.

The sheet is the 1x size - the four chips side by side untouched - and the 2x sheet is each pixel
doubled, nearest-neighbour, nothing smoothed, because the exports have no 2x of their own (the other
size beside the Iron ones, 54x54, is not twice anything).

The folder is READ ONLY, for the reason tools/import_art.py gives: the originals live outside this
repository and are the only copy there is.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIERS = 4

#: metal -> (file name for a tier, the size of a chip)
METALS = {
    "iron": ("iron_stake_tier%d_1x.png", 71),
    "brass": ("brass_stake_t%d.png", 54),
    "rose": ("rose_stake_t%d.png", 54),
}


def build(folder, metal):
    pattern, cell = METALS[metal]
    sheet = Image.new("RGBA", (cell * TIERS, cell), (0, 0, 0, 0))
    seen = {}
    for tier in range(1, TIERS + 1):
        path = os.path.join(folder, pattern % tier)
        if not os.path.exists(path):
            sys.exit("no such file: " + path)
        img = Image.open(path).convert("RGBA")
        if img.size != (cell, cell):
            sys.exit("%s is %dx%d, and a %s chip is %dx%d" % (path, img.size[0], img.size[1], metal, cell, cell))
        fingerprint = img.tobytes()
        if fingerprint in seen:
            sys.exit("%s tier %d is the same picture as tier %d" % (metal, tier, seen[fingerprint]))
        seen[fingerprint] = tier
        sheet.paste(img, ((tier - 1) * cell, 0))

    for scale, name in ((1, "1x"), (2, "2x")):
        out = sheet if scale == 1 else sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
        dest = os.path.join(ROOT, "assets", name, "stake_%s.png" % metal)
        out.save(dest)
        print("wrote assets/%s/stake_%s.png (%dx%d)" % (name, metal, out.width, out.height))


def main(argv):
    if len(argv) < 3 or any(metal not in METALS for metal in argv[2:]):
        sys.exit(__doc__.strip().splitlines()[0] + "\n" + __doc__.strip().splitlines()[2].strip()
                 + "\nmetals: " + ", ".join(sorted(METALS)))
    for metal in argv[2:]:
        build(argv[1], metal)
    print("Now LOOK at it: every check here is about what the file is, not whether it is the right picture.")


if __name__ == "__main__":
    main(sys.argv)
