"""Put a Joker's art into assets/, refusing every way it has gone wrong.

    python tools/import_art.py <name> <1x file> <2x file>
    python tools/import_art.py <name> <1x file> <2x file> --replace

Three Jokers once shipped wearing another card's face. The art had been pulled
out of the session transcript by taking the last image in the file - which is
the newest message only if the transcript has caught up, and when it has not,
it is somebody else's picture at exactly the right dimensions. Nothing
downstream noticed: the file existed, the atlas checker was happy, every suite
passed.

So this tool exists to make the safe path the easy one, and every refusal below
is one of the ways that went wrong:

  * SOURCES ARE NAMED, never guessed. Nothing here reads a transcript.
  * The art folder is READ ONLY. The originals live outside this repository
    and are the only copy there is; writing into it once overwrote a file that
    could not be got back.
  * A picture already in assets/ is REFUSED. That is the actual failure - the
    same image landing under a second name - and it is worth catching at the
    moment of the copy rather than at the next check.
  * 1x and 2x must DIFFER, and each must be its own size. Handing the same
    file twice is the other easy slip.

`--replace` allows an existing name to be overwritten, and says what it did.
It does not relax any of the checks above.
"""
import hashlib
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZES = {"1x": (71, 95), "2x": (142, 190)}


def fingerprint(path):
    """The RGB channels, ignoring alpha.

    Corner masking only ever changes alpha, and round art is exempt from it -
    so comparing bytes lets the same picture through under a second name.
    """
    img = Image.open(path).convert("RGBA")
    r, g, b, _a = img.split()
    return img.size, hashlib.md5(Image.merge("RGB", (r, g, b)).tobytes()).hexdigest()


def existing(name):
    """{fingerprint: stem} for every image already in assets/, `name` aside."""
    seen = {}
    for folder in SIZES:
        d = os.path.join(ROOT, "assets", folder)
        for f in sorted(os.listdir(d)):
            if not f.lower().endswith(".png"):
                continue
            stem = os.path.splitext(f)[0]
            if stem == name:
                continue
            seen[fingerprint(os.path.join(d, f))] = folder + "/" + stem
    return seen


def main(argv):
    if len(argv) < 4:
        sys.exit(__doc__.strip().splitlines()[2].strip())

    name, src1, src2 = argv[1], argv[2], argv[3]
    replace = "--replace" in argv[4:]

    for src, folder in ((src1, "1x"), (src2, "2x")):
        if not os.path.exists(src):
            sys.exit("no such file: %s" % src)
        size, _ = fingerprint(src)
        if size != SIZES[folder]:
            sys.exit("%s is %dx%d, and %s art must be %dx%d"
                     % (src, size[0], size[1], folder, *SIZES[folder]))

    if fingerprint(src1)[1] == fingerprint(src2)[1]:
        sys.exit("the 1x and 2x sources are the same picture")

    already = existing(name)
    for src in (src1, src2):
        match = already.get(fingerprint(src))
        if match:
            sys.exit("%s is already in assets as %s - importing it under a "
                     "second name is how a Joker ends up wearing another "
                     "card's face" % (os.path.basename(src), match))

    for src, folder in ((src1, "1x"), (src2, "2x")):
        dest = os.path.join(ROOT, "assets", folder, name + ".png")
        if os.path.exists(dest) and not replace:
            sys.exit("%s already exists; pass --replace to overwrite it" % dest)
        was = " (replaced)" if os.path.exists(dest) else ""
        shutil.copyfile(src, dest)
        print("wrote assets/%s/%s.png%s" % (folder, name, was))

    print("Now LOOK at them. Every check here is about what the file is, and "
          "none of them can tell you it is the right picture.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
