# Contributing

Thanks for looking. This is a one-person hobby mod, so the most useful things
are bug reports and ideas — but if you want to change code, this is what the
repo expects.

## Before anything else

Three files are **generated**. Editing them by hand works until the next time
the generator runs, and then your change is gone:

- `jokers/atlases.lua` — one atlas per image in `assets/1x/`
- `jokers/zz_vtubers.lua` — the placeholder roster, currently empty
- `localization/en-us.lua` — every `j_celesta_*` Joker block is preserved from
  the existing file; **everything else** comes from `tools/gen_roster.py`

So: a Joker's own description is edited in `localization/en-us.lua`. Anything
else player-facing — merge descriptions, deck text, blind text, the strings in
`misc` — is edited in `tools/gen_roster.py`, and then you run:

```bash
python tools/gen_roster.py
```

That rebuilds all three, and masks every card image to Balatro's corner
silhouette on the way past, so art can't reach the game unshaped.

## Run the checkers

Six of them, all in `tools/`. They are fast and they catch the things that are
invisible in game until someone hits them:

```bash
python tools/check_atlases.py          # every atlas matches its image
python tools/check_loc_keys.py         # every localize key resolves
python tools/check_loc_vars.py         # every #n# is supplied by loc_vars
python tools/check_dependencies.py     # foreign globals are declared or guarded
python tools/check_duplicate_art.py    # no image ships under two names
python tools/check_runtime_globals.py  # no runtime use of SMODS.current_mod
```

`check_loc_vars.py` loads the whole mod, so it is also the one that catches a
file that has stopped compiling.

There is a larger test suite behind this mod — a few hundred scenarios run
against the real Lua — but it lives outside the repository and is run by the
maintainer. Please don't take its absence as permission to skip the checkers.

## Two traps worth knowing

**The 200-local ceiling.** `merge/bind.lua` and `jokers/implemented.lua` both
sit at Lua's limit of 200 local variables per chunk. Go one over and the *whole
file* stops loading — you don't get an error on the offending line, you get a
mod that fails to load. New top-level helpers in either file go inside a
`do ... end` block so they're released at the end of it.

**A merge speaks for both halves.** When two Jokers are bound, neither is "in
play" as itself any more, so `joker_in_play` and `find_joker` won't find them.
If a pair's effect depends on one of its own halves still working, the merge
will silently switch off the very thing it's about. The usual fix is a rule
list declared in `globals.lua` that the relevant hook consults — see
`SAME_SUIT_RULES` and `CARD_RANK_RULES` for the pattern.

Every new Joker should be tried **merged, in both directions** — as the host
and as the absorbed half. The absorbed one is what breaks.

## Art

Use the importer rather than copying files in:

```bash
python tools/import_art.py <name> <1x file> <2x file>
```

1x is 71×95, 2x is 142×190, and the tool refuses every way this has gone wrong
before: art already in `assets/` under another name, the same file passed
twice, or a size that doesn't match. Art that isn't card-shaped is centred in
the cell rather than stretched.

Then look at the result. Nothing the tool checks can tell you it's the right
picture.

**Only submit art you have the right to submit.** Every face in this mod was
drawn by a person and is credited; see the art notice in the README.

## Keys

The manifest `prefix` is `celesta`, and it is prepended to everything, so
`SMODS.Joker { key = "shylily" }` becomes `j_celesta_shylily`. Localization
keys and cross-references between the mod's own objects use the full prefixed
form.

## Pull requests

Small and one thing at a time is easiest to review. Say what you changed and
why, and mention anything you couldn't test. If you're adding a merge, say
which two Jokers and what it's meant to do — the description matters as much as
the code, because it's what the player reads.
