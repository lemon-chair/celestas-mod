"""Catch description placeholders that nothing fills in.

    python tools/check_loc_vars.py

A description line containing #1# needs loc_vars to return a matching entry in
`vars`. If it does not, localize() indexes a nil `vars` and Balatro hard
crashes the moment the card is hovered - it is not a silent formatting bug.

This loads the mod against a stubbed Steamodded, calls every registered Joker
and Seal's loc_vars with a fake card built from its own config, and compares
the number of vars returned against the highest #N# in its text.

Requires lupa (pip install lupa).
"""
import glob
import os
import re
import sys
import importlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BOOTSTRAP = '''
jokers, seals, enhancements, blinds, atlases = {}, {}, {}, {}, {}
consumables = {}
sounds = {}
SMODS = {
  Atlas = function(t) atlases[t.key] = t end,
  Sound = function(t) sounds[t.key] = t end,
  Sounds = {},
  Joker = function(t) jokers[t.key] = t end,
  Seal  = function(t) seals[t.key] = t end,
  Enhancement = function(t) enhancements[t.key] = t end,
  Blind = function(t) blinds[t.key] = t end,
  Consumable = function(t) consumables[t.key] = t end,
  Back = function() end,
  ConsumableTypes = {},
  current_mod = { path = "", name = "M", prefix = "celesta", config = {} },
}
SMODS.add_to_pool = function(o, a)
  if type(o.in_pool) == "function" then return o:in_pool(a) end
  return true
end
-- loc_vars often asks for live odds; return the base values unchanged.
SMODS.get_probability_vars = function(card, num, den, id) return num, den end
sendWarnMessage = function() end
sendInfoMessage = function() end
HEX = function(s) return s end
localize = function(s) return s end
create_toggle = function(t) return t end
loc_colour = function() end
Game = {}; function Game:update() end; function Game:draw() end
-- Globals the mod wraps; present in the real game.
Card = {}; function Card:set_sprites() end
evaluate_poker_hand = function() return {} end
SMODS.Rank = { obj_buffer = {} }
SMODS.Ranks = {}
SMODS.smeared_check = function() return false end
SMODS.find_card = function() return {} end
CardArea = {}; function CardArea:emplace() end
love = { graphics = {} }
G = {
  STATES = { SELECTING_HAND=1, SHOP=5, BLIND_SELECT=7, ROUND_EVAL=8, MENU=11,
             NEW_ROUND=19, HAND_PLAYED=2, DRAW_TO_HAND=3, GAME_OVER=4,
             PLAY_TAROT=6, TAROT_PACK=9, PLANET_PACK=10, SPECTRAL_PACK=15,
             STANDARD_PACK=17, BUFFOON_PACK=18, SMODS_BOOSTER_OPENED=999 },
  C = setmetatable({}, { __index = function() return 0 end }),
  UIT = {}, GAME = { round = 1 }, ASSET_ATLAS = {}, handlist = {},
  P_CARDS = setmetatable({}, { __index = function() return {} end }),
  P_CENTERS = setmetatable({}, { __index = function() return {} end }),
  P_SEALS = setmetatable({}, { __index = function() return {} end }),
}

-- Build a stand-in playing card / joker whose ability mirrors the object's
-- own config, which is what loc_vars reads.
function fake_card(obj)
  local ability = { extra = {}, perma_x_mult = 0, perma_mult = 0 }
  if obj.config and obj.config.extra then
    for k, v in pairs(obj.config.extra) do ability.extra[k] = v end
  end
  return { ability = ability, config = { center = obj }, base = {} }
end

function count_vars(obj)
  if type(obj.loc_vars) ~= "function" then return -1 end
  local ok, res = pcall(function()
    return obj:loc_vars({}, fake_card(obj))
  end)
  if not ok then return -2, tostring(res) end
  if type(res) ~= "table" or type(res.vars) ~= "table" then return 0 end
  -- A nil INSIDE vars is the bug that prints "nil" on the card, and #vars
  -- does not see it - the length of {5, nil} is not reliably 2. Report the
  -- first hole instead of the raw count.
  local n = #res.vars
  for i = 1, n do
    if res.vars[i] == nil then return -3, tostring(i) end
  end
  return n
end
'''


def main():
    lupa = importlib.import_module("lupa.luajit21")
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(BOOTSTRAP)

    compile_ = lua.eval('function(s,n) return assert((loadstring or load)(s,n)) end')

    def load_file(rel, *_):
        path = os.path.join(ROOT, *str(rel).split("/"))
        return compile_(open(path, encoding="utf-8").read(), str(rel))

    def dir_items(p, *_):
        real = os.path.join(ROOT, *str(p).split("/")) if str(p) else ROOT
        return lua.table_from(sorted(os.listdir(real)))

    lua.globals().SMODS.load_file = load_file
    lua.globals().NFS = lua.table_from({"getDirectoryItems": dir_items})
    compile_(open(os.path.join(ROOT, "main.lua"), encoding="utf-8").read(), "main.lua")()

    loc_src = open(os.path.join(ROOT, "localization", "en-us.lua"), encoding="utf-8").read()
    loc = lua.eval('function(s) return assert((loadstring or load)(s,"loc"))() end')(loc_src)

    g = lua.globals()
    count_vars = g.count_vars

    targets = []
    for key, obj in dict(g.jokers).items():
        targets.append(("Joker", key, "j_celesta_" + key, obj, loc.descriptions.Joker))
    for key, obj in dict(g.seals).items():
        loc_key = ("celesta_" + key).lower() + "_seal"
        targets.append(("Seal", key, loc_key, obj, loc.descriptions.Other))
    for key, obj in dict(g.enhancements).items():
        targets.append(("Enhancement", key, "m_celesta_" + key, obj,
                        loc.descriptions.Enhanced))
    for key, obj in dict(g.blinds).items():
        targets.append(("Blind", key, "bl_celesta_" + key, obj,
                        loc.descriptions.Blind))
    # Consumables read their text from the block named after their set, so a
    # Spectral needs descriptions.Spectral to exist at all. gen_roster.py owns
    # that whole table and rewrites it, so an entry added to en-us.lua by hand
    # survives exactly until the next regeneration - which is how Bind and the
    # Milk Bottle both ended up in the shop with a blank description box.
    for key, obj in dict(g.consumables).items():
        set_name = obj.set or "Tarot"
        table_ = dict(loc.descriptions).get(set_name)
        targets.append(("Consumable", key, "c_celesta_" + key, obj, table_))

    problems, checked = [], 0
    for kind, key, loc_key, obj, table_ in sorted(targets):
        if table_ is None:
            problems.append("%s %s: no descriptions block for its set" % (kind, key))
            continue
        entry = dict(table_).get(loc_key)
        if entry is None:
            problems.append("%s %s: no localization entry %s" % (kind, key, loc_key))
            continue
        text = " ".join(dict(entry.text).values())
        needed = max((int(n) for n in re.findall(r"#(\d+)#", text)), default=0)
        got = count_vars(obj)
        # count_vars returns (code, message) on error, which lupa hands back
        # as a tuple; everything else comes through as a bare number.
        err = ""
        if isinstance(got, tuple):
            got, err = got[0], str(got[1]) if len(got) > 1 else ""
        checked += 1
        if got == -2:
            problems.append("%s %s: loc_vars raised an error: %s" % (kind, key, err))
        elif got == -3:
            problems.append("%s %s: loc_vars returns nil for var #%s - the card "
                            "will print \"nil\"" % (kind, key, err))
        elif needed > 0 and got == -1:
            problems.append("%s %s: text needs #%d# but there is no loc_vars"
                            % (kind, key, needed))
        elif needed > max(got, 0):
            problems.append("%s %s: text needs #%d# but loc_vars returns %d var(s)"
                            % (kind, key, needed, max(got, 0)))

    print("checked %d objects" % checked)
    if problems:
        print("\n%d PROBLEM(S) - these crash the game on hover:" % len(problems))
        for p in problems:
            print("   " + p)
        sys.exit(1)
    print("every description placeholder is supplied by loc_vars")


if __name__ == "__main__":
    main()
