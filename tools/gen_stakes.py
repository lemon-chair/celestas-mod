"""Build the Stakes' chip sheet from their named exports.

    python tools/gen_stakes.py <folder holding the exports>

The folder holds one 54x54 picture a stake, named for the stake - iron.png, lead.png, brass.png and so
on, in the order items/stakes.lua chains them (STAKES below says which). They are laid out five to a
row on one sheet, the way the base game keeps its stake chips on one sheet: the first stake is the
first cell, and items/stakes.lua picks a cell by the stake's place in the list.

The sheet is the 1x size - the chips side by side untouched - and the 2x sheet is each pixel
doubled, nearest-neighbour, nothing smoothed, because the exports have no 2x of their own.

The folder is READ ONLY, for the reason tools/import_art.py gives: the originals live outside this
repository and are the only copy there is.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: Every stake, in the order it is chained: what sits on Gold first, what sits highest last.
STAKES = [
    "iron", "lead", "brass", "rose", "lavish", "eryl", "azure", "crimson", "glimmer", "ichor",
    "herbium", "magical", "abyssal", "heathen", "soul", "titanium", "hedron", "burning", "terra",
    "celestial",
]
CELL = 54
COLUMNS = 5


def build(folder):
    rows = (len(STAKES) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGBA", (CELL * COLUMNS, CELL * rows), (0, 0, 0, 0))
    seen = {}
    for index, key in enumerate(STAKES):
        path = os.path.join(folder, key + ".png")
        if not os.path.exists(path):
            sys.exit("no such file: " + path)
        img = Image.open(path).convert("RGBA")
        if img.size != (CELL, CELL):
            sys.exit("%s is %dx%d, and a stake chip is %dx%d" % (path, img.size[0], img.size[1], CELL, CELL))
        fingerprint = img.tobytes()
        if fingerprint in seen:
            sys.exit("%s is the same picture as %s" % (key, seen[fingerprint]))
        seen[fingerprint] = key
        sheet.paste(img, ((index % COLUMNS) * CELL, (index // COLUMNS) * CELL))

    for scale, name in ((1, "1x"), (2, "2x")):
        out = sheet if scale == 1 else sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
        dest = os.path.join(ROOT, "assets", name, "stake_chips.png")
        out.save(dest)
        print("wrote assets/%s/stake_chips.png (%dx%d)" % (name, out.width, out.height))


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__.strip().splitlines()[0] + "\n" + __doc__.strip().splitlines()[2].strip())
    build(argv[1])
    print("Now LOOK at it: every check here is about what the file is, not whether it is the right picture.")


if __name__ == "__main__":
    main(sys.argv)
