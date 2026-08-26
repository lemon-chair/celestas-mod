"""Catch SMODS.current_mod being read at runtime instead of at load.

    python tools/check_runtime_globals.py

SMODS.current_mod is only set while a mod is loading. Reading it from a hook
that runs later - a draw pass, a calculate, a config tab - gets nil and hard
crashes the game. This mod has hit that twice: once in the Arena draw hook and
once in Exo's, both of which run every frame.

The fix in both cases was to resolve it once at file scope:

    local EXO_FRAME_ATLAS = SMODS.current_mod.prefix .. "_enh_exo_frame"

so this flags uses that are indented far enough to be inside a function body.
Top-level statements and table literals sit at 0-4 spaces; anything deeper is
inside something that runs later.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Table literals at file scope indent by 4. Function bodies reach 8+.
DEPTH = 8
PATTERN = re.compile(r"^(\s*).*SMODS\.current_mod")


def main():
    problems = []
    for dirpath, _dirs, files in os.walk(ROOT):
        if os.sep + "tools" in dirpath or os.sep + ".git" in dirpath:
            continue
        for name in sorted(files):
            if not name.endswith(".lua"):
                continue
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
            for n, line in enumerate(open(path, encoding="utf-8"), 1):
                if "--" in line.split("SMODS.current_mod")[0]:
                    continue  # a comment mentioning it
                m = PATTERN.match(line)
                if m and len(m.group(1).expandtabs(4)) >= DEPTH:
                    problems.append("%s:%d  %s" % (rel, n, line.strip()))

    if problems:
        print("%d use(s) of SMODS.current_mod inside a function body:\n" % len(problems))
        for p in problems:
            print("   " + p)
        print("\nResolve these at file scope instead - current_mod is nil once "
              "loading finishes.")
        sys.exit(1)
    print("no runtime uses of SMODS.current_mod")


if __name__ == "__main__":
    main()
