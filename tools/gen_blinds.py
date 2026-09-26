"""Build blind-chip animation strips from a single static image.

    python tools/gen_blinds.py

Blind chips are not static sprites: Balatro registers the vanilla atlas as
    {name = "blind_chips", path = "...BlindChips.png", px = 34, py = 34,
     frames = 21}
so a blind needs 21 frames of 34x34 (68x68 at 2x), laid out left to right. A
still image is turned into a strip by repeating it, which reads as a chip that
simply does not animate rather than a broken sprite.

Source art is centred rather than stretched, so it keeps its own pixel grid:
  2x cell 68x68 <- 64x64 art at native size, 2px margin
  1x cell 34x34 <- the same art halved to 32x32, 1px margin
Halving 64 to 32 is exact, so neither scale resamples unevenly.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_source  # noqa: E402  (needs the path set above)

FRAMES = 21
CELL = 34          # at 1x

# key -> source file
BLINDS = {
    "clover": "the_clover.png",
    "greed": "the_greed2.png",
    # The 2x file is the source: gen_blinds halves it for 1x, and 64 -> 32 is
    # exact, so neither scale resamples unevenly.
    "goat": "the_goat2x.png",
    "frog": "the_frog2x.png",
    "star": "the_star2x.png",
    "heart": "the_heart2x.png",
    "robot": "the_robot2x.png",
    "brick": "the_brick2x.png",
    "wyrm": "the_wyrm2x.png",
    "horn": "the_horn2x.png",
    "gem": "the_gem2x.png",
    "flower": "the_flower2x.png",
}


def main():
    for name, filename in BLINDS.items():
        src = Image.open(art_source.path(filename)).convert("RGBA")
        if src.width != src.height:
            sys.exit("%s is %s; blind art must be square" % (filename, src.size))

        for scale in (1, 2):
            cell = CELL * scale
            # Largest even size that leaves at least a 1px margin per side.
            art = min(src.width, (cell - 2 * scale))
            art -= art % 2
            resized = src.resize((art, art), Image.NEAREST)

            strip = Image.new("RGBA", (cell * FRAMES, cell), (0, 0, 0, 0))
            offset = (cell - art) // 2
            for frame in range(FRAMES):
                strip.paste(resized, (frame * cell + offset, offset), resized)

            out = os.path.join(ROOT, "assets", "%dx" % scale, "blind_%s.png" % name)
            strip.save(out)
            print("wrote %-30s %s  (%d frames of %dx%d, art %dpx)"
                  % (os.path.relpath(out, ROOT), strip.size, FRAMES, cell, cell, art))

    print("\natlas declaration for main.lua:")
    for name in BLINDS:
        print('SMODS.Atlas { key = "blind_%s", path = "blind_%s.png",'
              ' px = %d, py = %d, frames = %d, atlas_table = "ANIMATION_ATLAS" }'
              % (name, name, CELL, CELL, FRAMES))


if __name__ == "__main__":
    main()
