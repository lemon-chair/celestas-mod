"""Build the Blank Joker's base art and its sheet of layers.

    python tools/gen_blank_joker.py

The Blank Joker is drawn at runtime from up to five layers: a body, up to three
overlays and a suit pip. Every layer is card-sized here so the compositor is a
straight draw at (0, 0) with nothing to position - the alignment problem is
solved once, in this file, rather than every frame in Lua.

Where each layer comes from:

  bodies      glass, steel, gold, stone, lucky are drawn art, and already carry
              the JOKER text. Limestone is the exception: it is this mod's own
              enhancement, so its body is the enhancement sheet with
              blank_joker_text laid over it - which is why the text is a layer
              of its own rather than baked into the base.

  overlays    mult, wild and bonus are drawn art. Gash and Exo are this mod's,
              so they come from the same source art gen_enhancements.py uses -
              the overlay-style originals, before a card body is composited
              under them, which is exactly the shape wanted here.

  suit pips   the big central pip of the Ace, high-contrast. The vanilla four
              are read out of Balatro's own 8BitDeck_opt2.png - "_opt2" IS the
              high-contrast sheet, the one the colourblind option switches to -
              and Stars and Leaves are drawn art already in that style.

              Found rather than measured: an Ace has five bands of content down
              its height (rank / small pip / BIG PIP / small pip / rank), the
              same rule gen_driftwood_fronts.py relies on, so the middle band
              is the pip at any scale.

The suit pips are derived from the 2x art at both scales rather than taking the
supplied 1x, so the two never disagree about how big the pip is.
"""
import io
import os
import sys
import zipfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_source  # noqa: E402  (needs the path set above)
BALATRO = r"C:\Program Files (x86)\Steam\steamapps\common\Balatro\Balatro.exe"

CARD_W, CARD_H = 71, 95
ACE_COLUMN = 12
# Row index in 8BitDeck matches the suit's y in G.P_CARDS.
VANILLA_ROWS = {"Hearts": 0, "Clubs": 1, "Diamonds": 2, "Spades": 3}

# The sheet's cell order. Mirrored by BLANK.LAYERS in jokers/blank.lua; the two
# are asserted against each other by test_blank_joker.py, so neither can be
# renumbered on its own.
BODIES = ["glass", "steel", "gold", "stone", "lucky", "limestone"]
OVERLAYS = ["mult", "wild", "bonus", "gash", "exo"]
SUITS = ["Hearts", "Clubs", "Diamonds", "Spades", "celesta_Stars", "celesta_Leaf"]
ORDER = BODIES + OVERLAYS + SUITS + ["text"]

# Layers that are drawn art dropped straight in from Downloads.
DRAWN = {
    "glass": "glass_effect", "steel": "steel_effect", "gold": "gold_effect",
    "stone": "stone_effect", "lucky": "lucky_effect",
    "mult": "mult_effect", "wild": "wild_effect", "bonus": "bonus_effect",
    "text": "blank_joker_text",
}
# ...and the two suits this mod adds, whose pips are drawn rather than found.
DRAWN_PIPS = {"celesta_Stars": "star_suit_effect", "celesta_Leaf": "leaf_suit_effect"}


def load(stem, scale, folder=art_source.ROOTS[0]):
    path = os.path.join(folder, "%s%dx.png" % (stem, scale))
    if not os.path.exists(path):
        sys.exit("missing source art: " + path)
    return Image.open(path).convert("RGBA")


def card_sized(img, scale, what):
    if img.size != (CARD_W * scale, CARD_H * scale):
        sys.exit("%s is %s, expected %s"
                 % (what, img.size, (CARD_W * scale, CARD_H * scale)))
    return img


def content_bands(img):
    """Contiguous runs of rows that contain any opaque pixel."""
    alpha = img.split()[3]
    w, h = img.size
    bands, start = [], None
    for y in range(h):
        filled = any(alpha.getpixel((x, y)) > 0 for x in range(w))
        if filled and start is None:
            start = y
        elif not filled and start is not None:
            bands.append((start, y - 1))
            start = None
    if start is not None:
        bands.append((start, h - 1))
    return bands


def centre_pip(ace):
    """The big central pip of an Ace, cropped tight."""
    bands = content_bands(ace)
    if len(bands) < 3:
        sys.exit("unexpected Ace layout: %d content bands" % len(bands))
    top, bottom = bands[len(bands) // 2]
    band = ace.crop((0, top, ace.width, bottom + 1))
    box = band.split()[3].getbbox()
    return band.crop(box)


def centred(pip, scale):
    """A card-sized cell with `pip` in the middle of it."""
    cell = Image.new("RGBA", (CARD_W * scale, CARD_H * scale), (0, 0, 0, 0))
    cell.paste(pip, ((cell.width - pip.width) // 2,
                     (cell.height - pip.height) // 2), pip)
    return cell


def main():
    if not os.path.exists(BALATRO):
        sys.exit("Balatro.exe not found at " + BALATRO)
    archive = zipfile.ZipFile(BALATRO)

    for scale, folder in ((1, "1x"), (2, "2x")):
        out_dir = os.path.join(ROOT, "assets", folder)

        # ---- the base the Joker starts as ----
        base = card_sized(load("blank_joker", scale), scale, "blank_joker")
        base.save(os.path.join(out_dir, "blank_joker.png"))

        text = card_sized(load("blank_joker_text", scale), scale, "blank_joker_text")

        layers = {}
        for key, stem in DRAWN.items():
            layers[key] = card_sized(load(stem, scale), scale, stem)

        # Limestone is the mod's own, so its body is the enhancement art with
        # the JOKER text laid over it.
        limestone = card_sized(
            Image.open(os.path.join(out_dir, "enh_limestone.png")).convert("RGBA"),
            scale, "enh_limestone")
        limestone = limestone.copy()
        limestone.alpha_composite(text)
        layers["limestone"] = limestone

        # Gash and Exo take the overlay-style originals - the same files
        # gen_enhancements.py reads - rather than the composited enhancements,
        # which carry a card body this must not paint over the Joker.
        # gen_enhancements.py names these gash.png / gash2.png rather than
        # 1x/2x, so they are opened directly.
        gash = Image.open(os.path.join(
            art_source.ROOTS[0], "gash2.png" if scale == 2 else "gash.png")).convert("RGBA")
        if gash.size != (CARD_W * scale, CARD_H * scale):
            gash = Image.open(art_source.path("gash2.png")).convert("RGBA")
            gash = gash.resize((CARD_W * scale, CARD_H * scale), Image.NEAREST)
        layers["gash"] = gash
        layers["exo"] = card_sized(
            Image.open(os.path.join(out_dir, "enh_exo_frame.png")).convert("RGBA"),
            scale, "enh_exo_frame")

        # ---- the suit pips ----
        name = "resources/textures/%s/8BitDeck_opt2.png" % folder
        deck = Image.open(io.BytesIO(archive.read(name))).convert("RGBA")
        cw, ch = CARD_W * scale, CARD_H * scale
        for suit, row in VANILLA_ROWS.items():
            ace = deck.crop((ACE_COLUMN * cw, row * ch,
                             (ACE_COLUMN + 1) * cw, (row + 1) * ch))
            pip = centre_pip(ace)
            layers[suit] = centred(pip, scale)
            if scale == 1:
                print("   %-14s pip %s" % (suit, pip.size))

        for suit, stem in DRAWN_PIPS.items():
            # Both scales off the 2x, so the pair can never disagree.
            pip = load(stem, 2)
            pip = pip.crop(pip.split()[3].getbbox())
            if scale == 1:
                pip = pip.resize((max(1, pip.width // 2), max(1, pip.height // 2)),
                                 Image.NEAREST)
                print("   %-14s pip %s" % (suit, pip.size))
            layers[suit] = centred(pip, scale)

        # ---- the sheet ----
        sheet = Image.new("RGBA", (cw * len(ORDER), ch), (0, 0, 0, 0))
        for i, key in enumerate(ORDER):
            if key not in layers:
                sys.exit("no art built for layer " + key)
            sheet.paste(layers[key], (i * cw, 0))
        out = os.path.join(out_dir, "blank_joker_layers.png")
        sheet.save(out)
        print("wrote %-40s %s" % (os.path.relpath(out, ROOT), sheet.size))

    print("\ncell order:")
    for i, key in enumerate(ORDER):
        print("   %2d  %s" % (i, key))


if __name__ == "__main__":
    main()
