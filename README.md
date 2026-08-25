# Celesta's Mod

A Balatro mod built on [Steamodded](https://github.com/Steamodded/smods),
structured after the Legends mod. 119 VTuber Jokers driven by a generated roster,
plus three worked example Jokers, a Tarot, and a Deck to copy patterns from.

## Layout

```
CelestasMod/
+- CelestasMod.json      Mod manifest - id, prefix, version, dependencies
+- main.lua              Entry point: globals, shared atlases, auto-loads jokers/
+- globals.lua           Custom colours + loc_colour hook (mirrors Legends)
+- config.lua            Default mod config (editable in the Mods menu)
+- jokers/               Every .lua here is auto-loaded, sorted by filename
|  +- atlases.lua        GENERATED - one SMODS.Atlas per image in assets/1x
|  +- examples.lua       Hand-written: flat, scaling, and per-card patterns
|  +- vtubers.lua        GENERATED - the 119-joker roster
+- items/
|  +- consumables.lua    Tarot with can_use / use
|  +- decks.lua          Back with starting params + apply()
+- localization/
|  +- en-us.lua          GENERATED - all player-facing text
+- assets/
|  +- 1x/                One 71x95 image per joker + shared sheets
|  +- 2x/                Same names at 142x190
+- tools/
|  +- gen_roster.py      Rebuilds the three GENERATED files from assets/1x
+- lovely/               Raw source patches (only if Steamodded cannot reach it)
+- .vscode/              Lua LSP settings, extension recs, launch/log tasks
```

## The roster

119 Jokers, one per image, following the Legends mod's convention: each image is
its own single-sprite atlas, referenced by the filename stem.

```
assets/1x/shylily.png  ->  SMODS.Atlas { key = "shylily" }  ->  j_celesta_shylily
```

Right now every one of them is a Common Joker with the same placeholder
`+4 Mult`, so the full roster loads and is testable in-game. To give one a real
effect, add a `calculate` to its row in `jokers/vtubers.lua`:

```lua
{ key = "neuro", rarity = 3, cost = 8, mult = 0,
  calculate = function(self, card, context)
      if context.joker_main then return { x_mult = 3 } end
  end },
```

...then rewrite its text in `localization/en-us.lua`. `jokers/examples.lua` has
worked examples of the three most common trigger shapes.

**Regenerating:** `python tools/gen_roster.py` rebuilds `jokers/atlases.lua`,
`jokers/vtubers.lua`, and `localization/en-us.lua` from whatever is in
`assets/1x/`. It overwrites hand-written descriptions, so once you start writing
real text, stop running it. Display names come from filenames; corrections go in
the `DISPLAY_NAMES` map at the top of the script.

## Setup

1. **Install Steamodded.** Lovely is already in place on this machine
   (`version.dll` in the Balatro folder). Download the Steamodded release and
   unzip it so you have `%APPDATA%\Balatro\Mods\Steamodded\`.
2. **Launch Balatro.** This mod is already in the Mods folder, so it loads on
   startup. Check the `MODS` button on the main menu.
3. **Iterate.** Lua is re-read on launch — edit, relaunch, retest. There is no
   hot reload.

## Key naming

The `prefix` in the manifest (`celesta`) is prepended to everything:

| You write | Game sees |
| --- | --- |
| `SMODS.Joker { key = 'shylily' }` | `j_celesta_shylily` |
| `SMODS.Consumable { key = 'reforge' }` | `c_celesta_reforge` |
| `SMODS.Back { key = 'founders' }` | `b_celesta_founders` |
| `SMODS.Atlas { key = 'shylily' }` | `celesta_shylily` |

Localization keys must use the **full prefixed** form. Cross-references between
your own objects do too — see `decks.lua` spawning `j_celesta_spark`.

## Debugging

- Logs: `%APPDATA%\Balatro\Mods\lovely\log\` — the VS Code task
  **Tail Steamodded log** follows the newest one.
- `sendDebugMessage('text', 'CelestasMod')` from any Lua file writes there.
- A Lua error during load shows as the mod failing in the `MODS` menu with the
  stack trace attached; open that entry rather than guessing.

## Editor autocomplete (optional)

Extract Balatro's Lua source into `.balatro-src/` (gitignored) and the Lua LSP
will resolve `G.GAME`, `Card:set_ability`, and friends. Use a `.love` extractor
such as [love-extract](https://github.com/MikuAuahDark/love-extract) or 7-Zip on
`Balatro.exe`. Everything works without this — you just lose completions.

## Reference

- Steamodded API wiki: https://github.com/Steamodded/smods/wiki
- `calculate` contexts: https://github.com/Steamodded/smods/wiki/calculate-functions
- Lovely: https://github.com/ethangreen-dev/lovely-injector
