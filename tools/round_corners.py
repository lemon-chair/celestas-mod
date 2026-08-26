"""Apply Balatro's card-corner silhouette to every joker image in assets/.

Run from the mod root:   python tools/round_corners.py

Vanilla joker art is not a plain rectangle: it has a 1px transparent inset all
round plus a chamfered corner, and the mask is hard-edged (alpha is only ever 0
or 255 - no anti-aliasing, because the game scales the sprite up and soft edges
would smear). PROFILE below was measured directly off Balatro's own Jokers.png
and is identical on all four corners of every vanilla sprite.

Because the mask is binary, re-running this is exactly idempotent - masking an
already-masked image changes nothing. It is still destructive in one direction:
corner pixels are discarded, so a *smaller* corner cannot be recovered later.
The untouched originals are in the birme-71x95 / birme-142x190 download folders.

    --check   report which images still need masking, change nothing
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = {"jokers", "consumables", "decks", "icon", "seals", "driftwood_fronts"}   # placeholder sheets, skip
CARD_W, CARD_H = 71, 95

# Transparent run inwards from the left edge, per row, for a 71x95 sprite.
# Mirrored horizontally and vertically, so this describes the whole silhouette.
# Rows 0 and 94 are fully transparent; rows 4..90 carry the 1px inset.
PROFILE = ([CARD_W, 4, 2, 2] + [1] * 87 + [2, 2, 4, CARD_W])
assert len(PROFILE) == CARD_H, len(PROFILE)


def build_mask(scale):
    """The 71x95 mask, nearest-upscaled by `scale`."""
    m = Image.new("L", (CARD_W, CARD_H), 255)
    px = m.load()
    for y, run in enumerate(PROFILE):
        for x in range(min(run, CARD_W)):
            px[x, y] = 0
            px[CARD_W - 1 - x, y] = 0
    if scale != 1:
        m = m.resize((CARD_W * scale, CARD_H * scale), Image.NEAREST)
    return m


def derive_profile(reference):
    """Re-measure PROFILE from a real Balatro Jokers.png (10x16 grid of 71x95)."""
    a = Image.open(reference).convert("RGBA").split()[3]
    out = []
    for y in range(CARD_H):
        run = 0
        for x in range(CARD_W):
            if a.getpixel((x, y)) == 0:
                run += 1
            else:
                break
        out.append(run)
    return out


def targets(scale):
    """Card art only. Skips the shared placeholder sheets and fx_* arena
    sprite sheets, which are not card-sized and must not be masked."""
    d = os.path.join(ROOT, "assets", "%dx" % scale)
    for f in sorted(os.listdir(d)):
        if (f.lower().endswith(".png")
                and not f.lower().startswith(("fx_", "enh_", "blind_"))
                and os.path.splitext(f)[0] not in SHARED):
            yield os.path.join(d, f)


def main():
    check = "--check" in sys.argv
    if "--reference" in sys.argv:
        ref = sys.argv[sys.argv.index("--reference") + 1]
        print("measured profile:", derive_profile(ref))
        return

    total = changed = skipped = 0
    for scale in (1, 2):
        mask = build_mask(scale)
        size = mask.size
        for p in targets(scale):
            total += 1
            im = Image.open(p).convert("RGBA")
            if im.size != size:
                sys.exit("%s is %s, expected %s" % (p, im.size, size))
            old = im.split()[3]
            # mask wins where it is 0; existing transparency is otherwise kept
            new = Image.composite(old, Image.new("L", size, 0), mask)
            if new.tobytes() == old.tobytes():
                skipped += 1
                continue
            changed += 1
            if not check:
                im.putalpha(new)
                im.save(p)

    verb = "need masking" if check else "masked"
    print("%d images: %d %s, %d already correct" % (total, changed, verb, skipped))


if __name__ == "__main__":
    main()
