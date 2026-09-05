"""Build the Lost Soul's sheet and the eligibility glow.

Run from the mod root:   python tools/gen_lost.py

Two outputs, both of which are sheets rather than card faces, so both sit in
the SHARED sets of gen_roster.py and round_corners.py.

assets/{1x,2x}/lost_soul.png
    TWO cells side by side, because that is how the game reads a card that has
    a floating half. Steamodded builds the floating sprite from the centre's
    OWN atlas (src/overrides.lua:1807), so the face and the wisp have to share
    one sheet: cell (0,0) is the face, cell (1,0) is the wisp, and the card
    declares soul_pos = {x=1,y=0}.

    Only the face is masked to the card silhouette. The wisp is a blob floating
    well inside the card outline - it is drawn scaled and rotated over the top,
    so the corners of its cell are not the corners of anything.

assets/{1x,2x}/lost_glow.png
    A white OUTLINE of the card silhouette - the silhouette with an eroded
    copy of itself cut out of the middle - which is what a Joker eligible for
    conversion wears while a Lost Soul is in the consumable tray. One sprite
    serves every eligible Joker: they are all the same shape, and the outline
    traces the card, not the art.

    Hollow rather than filled because it is drawn AFTER the card. Drawing
    before it would put the outline behind the art and need no hole, but the
    card's children have not been laid out for this frame at that point;
    drawing after is the route Cryogen's ring already takes and is known to
    land in the right place.

    It has to be an image rather than a tint. Balatro draws sprites through
    the dissolve shader, whose fragment stage returns either the texture's own
    colours or a hardcoded black silhouette (resources/shaders/dissolve.fs) and
    ignores the vertex colour entirely - so love.graphics.setColor cannot
    whiten a sprite, and a multiply tint could only ever darken one.
"""
import os
import sys

from PIL import Image, ImageChops, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import round_corners  # noqa: E402  (needs the path set above)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "lost_soul_art")
CARD_W, CARD_H = round_corners.CARD_W, round_corners.CARD_H


def load(name, scale):
    """One source image, checked against the card size it claims to be."""
    path = os.path.join(SRC, "%s_%dx.png" % (name, scale))
    img = Image.open(path).convert("RGBA")
    want = (CARD_W * scale, CARD_H * scale)
    if img.size != want:
        sys.exit("%s is %dx%d, expected %dx%d"
                 % (path, img.size[0], img.size[1], want[0], want[1]))
    return img


def build_sheet(scale):
    face = load("face", scale)
    wisp = load("wisp", scale)

    # The face carries the card silhouette; the wisp does not get one.
    mask = round_corners.build_mask(scale)
    face.putalpha(Image.composite(face.split()[3],
                                  Image.new("L", face.size, 0), mask))

    sheet = Image.new("RGBA", (face.size[0] * 2, face.size[1]), (0, 0, 0, 0))
    sheet.paste(face, (0, 0))
    sheet.paste(wisp, (face.size[0], 0))
    return sheet


#: Outline thickness in 1x pixels.
GLOW_PX = 2


def build_glow(scale):
    """The card silhouette with its own inside cut out, in opaque white."""
    mask = round_corners.build_mask(scale)
    # MinFilter is an erosion: every pixel takes the darkest value in its
    # neighbourhood, so the lit region shrinks by half the window each way.
    inner = mask.filter(ImageFilter.MinFilter(2 * GLOW_PX * scale + 1))
    ring = ImageChops.subtract(mask, inner)

    glow = Image.new("RGBA", mask.size, (255, 255, 255, 255))
    glow.putalpha(ring)
    return glow


def main():
    for scale in (1, 2):
        out = os.path.join(ROOT, "assets", "%dx" % scale)
        for name, img in (("lost_soul", build_sheet(scale)),
                          ("lost_glow", build_glow(scale))):
            path = os.path.join(out, name + ".png")
            img.save(path)
            print("wrote %s  %dx%d" % (path, img.size[0], img.size[1]))


if __name__ == "__main__":
    main()
