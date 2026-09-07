"""No two pieces of art in assets/ may be byte-identical.

    python tools/check_duplicate_art.py

Art arrives by being copied into place, and a copy that lands from the wrong
source is invisible: the file exists, the atlas checker is happy, every suite
passes, and the Joker simply wears somebody else's face. Three of them did.

Two files with the same bytes is the signature of exactly that mistake, and
nothing legitimate in this mod produces it - every card is drawn once. The one
thing that would is a deliberate reuse, which is what SHARED_PAIRS is for:
naming it here is how a duplicate stops being an accident.
"""
import hashlib
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: Sets that are meant to share a picture, as {frozenset of stems: why}.
SHARED_PAIRS = {
    # The frost pane and the same pane cut to Boosfer's circle. Identical in
    # RGB by construction - gen_enhancements builds the second by multiplying
    # the first's alpha with Boosfer's - so only the alpha differs, which is
    # precisely what this check looks past.
    frozenset({"frozen", "frozen_round"}):
        "the same pane, cut to a card and to a circle",
}


def scan(folder):
    """{fingerprint: [names]} for every PNG in assets/<folder>.

    The fingerprint is the RGB channels, NOT the file bytes. Corner masking
    only ever changes alpha, and round art is exempt from it - so the same
    picture copied into a masked slot and an unmasked one produces two
    different files. That is exactly how one of the three got past a check on
    the bytes.
    """
    seen = {}
    d = os.path.join(ROOT, "assets", folder)
    for name in sorted(os.listdir(d)):
        if not name.lower().endswith(".png"):
            continue
        img = Image.open(os.path.join(d, name)).convert("RGBA")
        r, g, b, _a = img.split()
        digest = hashlib.md5(
            Image.merge("RGB", (r, g, b)).tobytes()).hexdigest()
        seen.setdefault((img.size, digest), []).append(
            os.path.splitext(name)[0])
    return seen


def main():
    bad = 0
    total = 0
    for folder in ("1x", "2x"):
        for digest, names in sorted(scan(folder).items()):
            total += len(names)
            if len(names) < 2:
                continue
            if SHARED_PAIRS.get(frozenset(names)):
                continue
            bad += 1
            print("  %s/  %s" % (folder, " == ".join(names)))

    print("checked %d images" % total)
    if bad:
        print("%d set(s) of identical art - one of them is wearing another's "
              "face" % bad)
        return 1
    print("every image is its own")
    return 0


if __name__ == "__main__":
    sys.exit(main())
