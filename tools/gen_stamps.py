"""Build the Stamp sheets and the Stamp Pack's art.

    python tools/gen_stamps.py

A stamp is drawn TWICE, from one piece of source art:

  cell 0   the stamp laid over a blank card. That is the card the player picks
           out of a Stamp Pack, and "overlayed on a blank card" is what it was
           asked to look like. base_card.png is the same silhouette every
           sprite in this mod is masked to, so the result already carries
           vanilla's rounded corners and needs no pass from round_corners.py.

  cell 1   the stamp alone on transparency. That is what is drawn on top of
           the Joker it is attached to, so it must keep its transparent
           background and must NOT be masked to a card - it is the mark, not
           the card.

Two cells in one sheet rather than two files, the way lost_soul.png carries a
face and the wisp that floats over it: the two are one piece of art used two
ways, and a sheet keeps them from ever drifting apart.

The source art is 71x95 already - the mark is drawn where it will sit on the
card, at (43, 68) - so nothing here resizes or repositions it. The 2x art is
its own export and is used as supplied.

The pack is the exception twice over. Every pack in this art folder is 114x186,
a single file with no 1x beside it, and it is a clean 2x upscale (checked
below), so the 1x is recovered by halving it. And at 57x93 it is not
card-shaped, so it is CENTRED in a card-sized cell rather than given a cell of
its own - the same treatment Boosfer's circle and Urschleim's blob get, and for
the same reason. A Booster is sized by the CardArea it sits in
(UI_definitions.lua:672 builds the shop's at 1.27 card widths), so a cell of
another shape is drawn stretched to that rect rather than at its own
proportions: the pack came out half again as large as a vanilla one.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_source  # noqa: E402  (needs the path set above)

BASE = os.path.join(ROOT, "tools", "base_card.png")
CARD_W, CARD_H = 71, 95

#: asset name -> source art stem. One entry per piece of stamp art; several
#: stamps may share one (the three Money Stamps are one drawing, and so are
#: the two Retrigger Stamps). Mirrored by ART in stamps/stamps.lua.
STAMPS = {
    "stamp_mult": "mult_stamp",
    "stamp_chips": "chips_stamp",
    "stamp_x_mult": "mult_stamp_multiplier",
    "stamp_x_chips": "chips_stamp_multiplier",
    "stamp_e_mult": "mult_stamp_exponent",
    "stamp_e_chips": "chips_stamp_exponent",
    "stamp_money": "money_stamp",
    "stamp_retrigger": "retrigger_stamp",
    "stamp_lucky": "lucky_stamp",
    "stamp_favor": "favor_stamp",
}

PACK = "stamp_pack"
PACK_SOURCE = "stamp_pack.png"


def sheet(mark, scale):
    """One stamp's two cells: over a blank card, then alone."""
    w, h = CARD_W * scale, CARD_H * scale
    if mark.size != (w, h):
        raise SystemExit("stamp art is %dx%d, expected %dx%d"
                         % (mark.size[0], mark.size[1], w, h))

    base = Image.open(BASE).convert("RGBA")
    if base.size != (w, h):
        base = base.resize((w, h), Image.NEAREST)
    base.alpha_composite(mark)

    out = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0))
    out.paste(base, (0, 0))
    out.paste(mark, (w, 0))
    return out


def in_cell(img, scale):
    """`img` centred in a card-sized cell, never resized."""
    cell = Image.new("RGBA", (CARD_W * scale, CARD_H * scale), (0, 0, 0, 0))
    cell.paste(img, ((cell.width - img.width) // 2,
                     (cell.height - img.height) // 2))
    return cell


def halve(img):
    """A 2x pixel-art image at 1x, refusing anything that is not one.

    Every 2x2 block has to be a single colour, or the source was not drawn at
    half this size and halving it would invent pixels.
    """
    w, h = img.size
    if w % 2 or h % 2:
        raise SystemExit("pack art is %dx%d, which does not halve" % (w, h))
    px = img.load()
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            c = px[x, y]
            if px[x + 1, y] != c or px[x, y + 1] != c or px[x + 1, y + 1] != c:
                raise SystemExit("pack art is not a clean 2x upscale; it "
                                 "needs a 1x export of its own")
    return img.resize((w // 2, h // 2), Image.NEAREST)


def source(name):
    path = art_source.find(name)
    if not path:
        raise SystemExit("missing source art: %s" % art_source.path(name))
    return Image.open(path).convert("RGBA")


def main():
    written = 0
    for name, stem in sorted(STAMPS.items()):
        for folder, scale in (("1x", 1), ("2x", 2)):
            mark = source("%s%s.png" % (stem, folder))
            out = os.path.join(ROOT, "assets", folder, name + ".png")
            sheet(mark, scale).save(out)
            written += 1
        print("  %-18s %s, two cells" % (name, stem))

    two = source(PACK_SOURCE)
    for folder, scale, img in (("2x", 2, two), ("1x", 1, halve(two))):
        in_cell(img, scale).save(
            os.path.join(ROOT, "assets", folder, PACK + ".png"))
        written += 1
    print("  %-18s %dx%d, centred in a %dx%d cell"
          % (PACK, two.width // 2, two.height // 2, CARD_W, CARD_H))

    print("wrote %d files" % written)
    return 0


if __name__ == "__main__":
    sys.exit(main())
