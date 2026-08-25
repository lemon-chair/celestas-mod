"""Convert an animated GIF into a Balatro-loadable sprite sheet.

    python tools/gen_fx.py <name> <path-to.gif>
    python tools/gen_fx.py downpour "C:/.../assets/fx/downpour.gif"

Writes assets/1x/fx_<name>.png and assets/2x/fx_<name>.png as a square grid of
frames, and prints the SMODS.Atlas block plus the frame/fps numbers to paste
into arena/arena.lua.

The `fx_` filename prefix is what keeps these out of the joker roster -
tools/gen_roster.py skips anything starting with it.

LOVE cannot read GIFs, hence the conversion. Frames are laid out left-to-right,
top-to-bottom, and the 2x sheet is a nearest upscale so the pixel art stays
crisp rather than being smoothed.
"""
import math
import os
import sys

from PIL import Image, ImageSequence

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def convert(name, gif_path):
    src = Image.open(gif_path)
    frames = [f.convert("RGBA") for f in ImageSequence.Iterator(src)]
    if not frames:
        sys.exit("no frames in " + gif_path)

    w, h = frames[0].size
    for i, f in enumerate(frames):
        if f.size != (w, h):
            sys.exit("frame %d is %s, expected %s" % (i, f.size, (w, h)))

    # Frame durations are per-frame in a GIF; Balatro animates at one rate, so
    # take the mode and report if the source is not uniform.
    durations = [f.info.get("duration") or 100
                 for f in ImageSequence.Iterator(Image.open(gif_path))]
    uniform = len(set(durations)) == 1
    fps = round(1000.0 / (sum(durations) / float(len(durations))), 3)

    cols = math.ceil(math.sqrt(len(frames)))
    rows = math.ceil(len(frames) / cols)

    for scale, folder in ((1, "1x"), (2, "2x")):
        sheet = Image.new("RGBA", (cols * w * scale, rows * h * scale), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            img = f if scale == 1 else f.resize((w * scale, h * scale), Image.NEAREST)
            sheet.paste(img, ((i % cols) * w * scale, (i // cols) * h * scale))
        out = os.path.join(ROOT, "assets", folder, "fx_%s.png" % name)
        sheet.save(out)
        print("wrote %s  (%dx%d)" % (os.path.relpath(out, ROOT), *sheet.size))

    print("\n-- paste into main.lua:")
    print('SMODS.Atlas { key = "fx_%s", path = "fx_%s.png", px = %d, py = %d }'
          % (name, name, w, h))
    print("\n-- arena/arena.lua definition numbers:")
    print("   frames = %d, cols = %d, fps = %s, tile = %d"
          % (len(frames), cols, fps, w))
    if not uniform:
        print("   NOTE: source frame durations vary %s; using the average."
              % sorted(set(durations)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    convert(sys.argv[1], sys.argv[2])
