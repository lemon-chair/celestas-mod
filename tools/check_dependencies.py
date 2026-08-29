"""Every other mod this one touches is either declared or optional.

    python tools/check_dependencies.py

Two ways to go wrong, and they fail in opposite directions:

  * Reaching for another mod's globals WITHOUT declaring it, and without
    guarding the call. The mod loads and then dies, or worse, quietly does
    nothing, on any machine that does not happen to have it.

  * Declaring a dependency the code does not actually need, which locks
    players out of the mod for no reason.

So each foreign global is listed below as either DECLARED - required, may be
called freely - or OPTIONAL - must be reached only from behind a type check.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Globals owned by another mod -> the mod that provides them.
FOREIGN = {
    "Cryptid": "Cryptid",
    "Card.no": "Cryptid",              # Cryptid's `immutable` and friends
    # Talisman is not reached through a global of its own. It is reached by
    # returning the `e_mult` scoring key, which Talisman teaches
    # SMODS.calculate_effect to understand, and by asking for the method it
    # adds alongside it. Those ARE the dependency.
    "e_mult": "Talisman",
    "emult": "Talisman",
    "get_chip_e_mult": "Talisman",
}

# Reached only from behind a `type(x) == ...` check, and never declared.
OPTIONAL = {"Cryptid"}


def strip_noise(line):
    """The code of a line, with comments and string literals removed.

    A mod's name inside a warning message is not a use of that mod, and
    flagging one sends the reader to a line that is already correct.
    """
    code = line.split("--", 1)[0]
    return re.sub(r"(\"[^\"]*\"|'[^']*')", "", code)


def guarded_before(lines, n, token):
    """True when the enclosing function tests for `token` before line n."""
    start = 0
    for i in range(n - 1, -1, -1):
        if re.match(r"\s*(local\s+)?function", lines[i]):
            start = i
            break
    body = "".join(strip_noise(l) for l in lines[start:n])
    root = token.split(".")[0]
    return re.search(r"type\s*\(\s*%s" % re.escape(root), body) is not None


def declared():
    with open(os.path.join(ROOT, "CelestasMod.json"), encoding="utf-8") as f:
        raw = json.load(f)
    return {d.split()[0] for d in raw.get("dependencies", [])}


def lua_sources():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git", "assets", "tools")]
        for name in filenames:
            if name.endswith(".lua"):
                yield os.path.join(dirpath, name)


def main():
    have = declared()
    problems = []
    seen = {}

    for path in lua_sources():
        rel = os.path.relpath(path, ROOT).replace("\\", "/")
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
        for n, line in enumerate(lines, 1):
            code = strip_noise(line)
            for token, owner in FOREIGN.items():
                if not re.search(r"\b%s\b" % re.escape(token).replace(r"\.", r"\."), code):
                    continue
                seen.setdefault(owner, []).append("%s:%d" % (rel, n))
                if owner in have:
                    continue
                if owner not in OPTIONAL:
                    problems.append("%s:%d uses %s but %s is not declared"
                                    % (rel, n, token, owner))
                    continue
                # Optional: somewhere in the enclosing function there has to
                # be a type check. Looking only a line or two back is not
                # enough - a guard at the top of a function protects every use
                # in its body, which is the normal shape.
                if not guarded_before(lines, n, token):
                    problems.append(
                        "%s:%d reaches %s (from %s, which is OPTIONAL) without a "
                        "type check - it must degrade, not crash, when that mod "
                        "is absent" % (rel, n, token, owner))

    for owner in sorted(have):
        if owner in ("Steamodded", "Lovely"):
            continue
        if owner not in seen:
            problems.append("%s is declared as a dependency but nothing uses it"
                            % owner)

    print("checked %d Lua files" % sum(1 for _ in lua_sources()))
    for owner in sorted(seen):
        state = "declared" if owner in have else "optional"
        print("   %-10s %-9s %d use(s)" % (owner, state, len(seen[owner])))

    if problems:
        print("\n%d PROBLEM(S):" % len(problems))
        for p in problems:
            print("   " + p)
        sys.exit(1)
    print("every foreign global is declared or guarded")


if __name__ == "__main__":
    main()
