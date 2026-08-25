# Celesta's Mod

A Balatro mod skeleton built on [Steamodded](https://github.com/Steamodded/smods).
Ships with three example Jokers, a Tarot, and a Deck — enough of each object type
to copy from.

## Layout

```
CelestasMod/
├─ CelestasMod.json      Mod manifest — id, prefix, version, dependencies
├─ main.lua              Entry point: registers atlases, loads items/
├─ config.lua            Default mod config (editable in the Mods menu)
├─ items/
│  ├─ jokers.lua         Flat bonus, scaling, and per-card-trigger examples
│  ├─ consumables.lua    Tarot with can_use / use
│  └─ decks.lua          Back with starting params + apply()
├─ localization/
│  └─ en-us.lua          All player-facing text
├─ assets/
│  ├─ 1x/                Sprite sheets (71x95 per card)
│  └─ 2x/                Same sheets at exactly double size
├─ lovely/               Raw source patches (only if Steamodded can't reach it)
└─ .vscode/              Lua LSP settings, extension recs, launch/log tasks
```

The current sprites are generated placeholders — flat coloured cards with a
stripe marking the top-left. Replace them in place; keep the 1x sheet at
`71 x 95` per sprite and the 2x sheet at exactly double.

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
| `SMODS.Joker { key = 'spark' }` | `j_celesta_spark` |
| `SMODS.Consumable { key = 'reforge' }` | `c_celesta_reforge` |
| `SMODS.Back { key = 'founders' }` | `b_celesta_founders` |
| `SMODS.Atlas { key = 'jokers' }` | `celesta_jokers` |

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
