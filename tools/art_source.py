"""Where the hand-drawn source art lives.

The .aseprite files and their PNG exports are not in this repository - the
repository holds only the built atlases under assets/. The tools that build
those atlases read the exports from here.

The folder has moved once already (it was ~/Downloads), so it is asked for
rather than spelled out in four separate tools, and the old location is still
searched behind the new one: art that has not been moved yet still builds.
"""
import os

HOME = os.path.expanduser("~")

#: Searched in order; the first that holds the file wins.
ROOTS = [
    os.path.join(HOME, "Documents", "Aseprites", "VtuberTCG"),
    os.path.join(HOME, "Downloads"),
]


def find(name):
    """The full path to source art `name`, or None if no root has it."""
    for root in ROOTS:
        path = os.path.join(root, name)
        if os.path.exists(path):
            return path
    return None


def path(name):
    """The full path to source art `name`, or where it should have been.

    Callers that want to report a missing file get a sensible path to name in
    the message rather than None.
    """
    return find(name) or os.path.join(ROOTS[0], name)
