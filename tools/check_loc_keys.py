"""Every localize key this mod asks for has to exist.

localize does not raise on a key it cannot find. For a plain string it hands
back the literal 'ERROR' (misc_functions.lua:1692); for type='variable' it does
the same (:1726). Both go straight into a floating message over the Joker, so a
typo ships as a yellow ERROR sitting where a number should be and nothing in
the logs says otherwise. Trickywi and Nekrolina both did exactly that, asking
for an 'a_dollars' that no dictionary has ever had.

So the keys are checked against the dictionaries the game will actually have
loaded: Balatro's own, Steamodded's, and this mod's.
"""
import io
import os
import re
import sys
import zipfile

import lupa

MOD = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BALATRO = r"C:\Program Files (x86)\Steam\steamapps\common\Balatro\Balatro.exe"
SMODS = os.path.join(os.path.dirname(MOD), "smods-main",
                     "localization", "en-us.lua")

L = lupa.LuaRuntime(unpack_returned_tuples=True)


def load(source, what):
    """A localization file is one big `return {...}`, so Lua can read it."""
    try:
        return L.execute(source)
    except Exception as exc:                      # noqa: BLE001
        print("  could not read %s: %s" % (what, exc))
        return None


def misc_of(table):
    if table is None:
        return {}
    misc = table["misc"] if "misc" in dict(table) else None
    return misc or {}


def collect():
    """{category: set(keys)} across every localization the game loads."""
    out = {}

    def absorb(table):
        misc = misc_of(table)
        if not misc:
            return
        for cat, entries in misc.items():
            if not hasattr(entries, "items"):
                continue
            out.setdefault(cat, set()).update(str(k) for k in entries.keys())

    if os.path.exists(BALATRO):
        with zipfile.ZipFile(BALATRO) as z:
            absorb(load(z.read("localization/en-us.lua").decode("utf8", "ignore"),
                        "Balatro's localization"))
    else:
        print("  Balatro.exe not found - vanilla keys unchecked")
    if os.path.exists(SMODS):
        absorb(load(io.open(SMODS, encoding="utf-8").read(), "Steamodded's"))
    absorb(load(io.open(os.path.join(MOD, "localization", "en-us.lua"),
                        encoding="utf-8").read(), "this mod's"))
    return out


# localize{type = 'variable', key = 'x'} - key and type in either order.
VARIABLE = re.compile(
    r"""localize\s*[{(]\s*(?=[^}]*type\s*=\s*['"]variable['"])"""
    r"""[^}]*?key\s*=\s*['"]([\w]+)['"]""", re.S)
# localize('x') and localize('x', 'category')
PLAIN = re.compile(r"""localize\s*\(\s*['"]([^'"]+)['"]\s*"""
                   r"""(?:,\s*['"]([\w]+)['"]\s*)?\)""")


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def main():
    have = collect()
    bad = []

    for root, dirs, files in os.walk(MOD):
        dirs[:] = [d for d in dirs
                   if d not in (".git", "tools", "localization", "__pycache__")]
        for name in sorted(files):
            if not name.endswith(".lua"):
                continue
            path = os.path.join(root, name)
            rel = os.path.relpath(path, MOD).replace("\\", "/")
            text = io.open(path, encoding="utf-8").read()

            for m in VARIABLE.finditer(text):
                if m.group(1) not in have.get("v_dictionary", ()):
                    bad.append((rel, line_of(text, m.start()),
                                "v_dictionary", m.group(1)))
            for m in PLAIN.finditer(text):
                key, cat = m.group(1), m.group(2) or "dictionary"
                if cat not in have:
                    continue           # not a category the game keeps here
                if key not in have[cat]:
                    bad.append((rel, line_of(text, m.start()), cat, key))

    counted = sum(len(v) for v in have.values())
    print("checked against %d keys in %d categories"
          % (counted, len(have)))
    for rel, line, cat, key in bad:
        print("  %s:%d  no %s entry for %r - localize returns 'ERROR'"
              % (rel, line, cat, key))
    print("%d bad localize key(s)" % len(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
