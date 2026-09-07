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
# Images that are NOT card faces and must never be masked to a card silhouette.
# The arena sheets are 256x256 weather frames, and Exo's frame is deliberately
# larger than a card so it reads as overhanging the edges - masking either to
# 71x95 corners would quietly destroy them.
SHARED = {"jokers", "consumables", "decks", "icon", "seals", "driftwood_fronts", "frozen",
          "enh_exo_frame", "fx_downpour", "fx_snowstorm",
          # A suit sheet is thirteen card-sized cells in a row, not one card,
          # and its UI pip is neither - masking either to a 71x95 silhouette
          # would cut the whole row down to its first cell's corners.
          "suit_stars", "suit_stars_ui", "suit_leaf", "suit_leaf_ui",
          # Boosfer is a circle, not a card, and frozen_round is the frost pane
          # cut to match it. The card silhouette would shave 1px off the widest
          # point of both.
          "boosfer", "red_boosfer", "frozen_round",
          # eighteen card-sized cells in a row, and the pips inside them are
          # not cards at all
          "blank_joker_layers",
          # Cryogen's ring TURNS, so its silhouette is a circle at every angle
          # and the card's corners are not part of it. Thanatos's art is
          # landscape on a square sheet and carries the card silhouette turned
          # a quarter turn, which gen_thanatos.py has already applied.
          "cryogen_ring", "xm05_thanatos_wide",
          # lost_soul is two cells wide, so the card silhouette would cut it
          # down to the first one's corners; lost_glow IS that silhouette
          # already. tools/gen_lost.py masks the half that needs it.
          "lost_soul", "lost_glow",
          # Asked for verbatim: use the file exactly as supplied, do not edit
          # it. Its corners are already the card silhouette, so masking is a
          # no-op today - listing it here is what keeps that true if the art
          # is ever redrawn, rather than leaving the promise to luck.
          "face"}
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


def main(check=False, quiet=False):
    """Mask every card face in assets/. Returns how many needed it.

    `check` and `quiet` are arguments rather than argv reads because
    gen_roster.py calls this at the top of its own run - argv there belongs to
    gen_roster, and a tool that reads someone else's flags is a tool that will
    one day do the wrong thing quietly."""
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

    if not quiet:
        verb = "need masking" if check else "masked"
        print("%d images: %d %s, %d already correct"
              % (total, changed, verb, skipped))
    return changed


if __name__ == "__main__":
    if "--reference" in sys.argv:
        print("measured profile:",
              derive_profile(sys.argv[sys.argv.index("--reference") + 1]))
    else:
        main(check="--check" in sys.argv)
