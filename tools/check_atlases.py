"""Checks every registered atlas against the image behind it.

A Sprite draws its atlas image through a quad cut at (pos.x*px, pos.y*py) of
size (px, py). Nothing validates that those numbers fit the file: if the image
is not a whole number of cells, or a sprite asks for a cell past the edge, the
quad samples outside the texture and the card renders as smeared garbage rather
than failing. That is invisible until someone looks at the right card.

Checks, for every SMODS.Atlas the mod registers:

  * both assets/1x and assets/2x exist
  * 1x is exactly px by py per cell, and 2x is exactly double
  * each image is a whole number of cells in both directions
  * every pos referenced by a Joker, Enhancement, Consumable, Seal or Blind
    lands inside its atlas

    python tools/check_atlases.py

Exit code is 1 if anything is wrong, so it can gate a commit.
"""
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Sheets whose cell size is deliberately not the card size, with the reason.
NON_CARD = {
    "modicon": "32x32 mod badge",
    "blind_clover": "34x34 animated blind chip",
    "blind_greed": "34x34 animated blind chip",
    "fx_downpour": "256x256 weather frames",
    "fx_snowstorm": "256x256 weather frames",
    # The suit pip is drawn into a fixed 0.3x0.3 rect, so its cell size is free
    # and the art's own 13x13 grid is used rather than resampling into 18x18.
    "suit_stars_ui": "13x13 suit pip",
    "suit_leaf_ui": "13x13 suit pip",
}


def png_size(path):
    with open(path, "rb") as f:
        f.read(16)
        return struct.unpack(">II", f.read(8))


def registered_atlases():
    """key -> (path, px, py) for every SMODS.Atlas call in the mod."""
    found = {}
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git", "assets", "tools")]
        for name in filenames:
            if not name.endswith(".lua"):
                continue
            src = open(os.path.join(dirpath, name), encoding="utf-8").read()
            for m in re.finditer(
                r"SMODS\.Atlas\s*\{(.*?)\}", src, re.S):
                body = m.group(1)
                key = re.search(r"key\s*=\s*['\"]([^'\"]+)['\"]", body)
                path = re.search(r"path\s*=\s*['\"]([^'\"]+)['\"]", body)
                px = re.search(r"px\s*=\s*(\d+)", body)
                py = re.search(r"py\s*=\s*(\d+)", body)
                if key and path and px and py:
                    found[key.group(1)] = (path.group(1), int(px.group(1)), int(py.group(1)))
    return found


def referenced_positions():
    """atlas key -> set of (x, y) any object draws from."""
    used = {}
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git", "assets", "tools")]
        for name in filenames:
            if not name.endswith(".lua"):
                continue
            src = open(os.path.join(dirpath, name), encoding="utf-8").read()
            for m in re.finditer(
                r"atlas\s*=\s*['\"]([^'\"]+)['\"]\s*,\s*\n?\s*pos\s*=\s*\{\s*x\s*=\s*(\d+)\s*,\s*y\s*=\s*(\d+)",
                src):
                used.setdefault(m.group(1), set()).add((int(m.group(2)), int(m.group(3))))
    return used


def main():
    atlases = registered_atlases()
    positions = referenced_positions()
    problems = []

    for key, (path, px, py) in sorted(atlases.items()):
        sizes = {}
        for folder, scale in (("1x", 1), ("2x", 2)):
            full = os.path.join(ROOT, "assets", folder, path)
            if not os.path.exists(full):
                problems.append("%s: assets/%s/%s is missing" % (key, folder, path))
                continue
            sizes[folder] = png_size(full)

        if "1x" not in sizes:
            continue

        w, h = sizes["1x"]
        if w % px or h % py:
            problems.append(
                "%s: 1x is %dx%d, which is not a whole number of %dx%d cells"
                % (key, w, h, px, py))
        cols, rows = w // px, h // py

        if "2x" in sizes:
            w2, h2 = sizes["2x"]
            if (w2, h2) != (w * 2, h * 2):
                problems.append(
                    "%s: 2x is %dx%d, expected %dx%d (exactly double the 1x)"
                    % (key, w2, h2, w * 2, h * 2))

        for x, y in sorted(positions.get(key, ())):
            if x >= cols or y >= rows:
                problems.append(
                    "%s: something draws cell (%d,%d) but the sheet is only %dx%d cells"
                    % (key, x, y, cols, rows))

        note = NON_CARD.get(key)
        if not note and (px, py) != (71, 95):
            problems.append(
                "%s: cell is %dx%d, not the 71x95 card size - add it to NON_CARD "
                "with a reason if that is deliberate" % (key, px, py))

    print("checked %d atlases" % len(atlases))
    if problems:
        print("\n%d PROBLEM(S) - these render as garbage rather than failing:\n"
              % len(problems))
        for p in problems:
            print("   " + p)
        return 1
    print("every atlas matches its image, and every cell referenced exists")
    return 0


if __name__ == "__main__":
    sys.exit(main())
