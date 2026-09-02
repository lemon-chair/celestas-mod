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
consumables, backs = {}, {}
sounds = {}
suits = {}
SMODS = {
  Atlas = function(t) atlases[t.key] = t end,
  Sound = function(t) sounds[t.key] = t end,
  Sounds = {},
  Joker = function(t) jokers[t.key] = t end,
  Seal  = function(t) seals[t.key] = t end,
  Enhancement = function(t) enhancements[t.key] = t end,
  Blind = function(t) blinds[t.key] = t end,
  -- Suits carry their own loc_txt rather than a descriptions entry, so
  -- they are only recorded here to keep main.lua loadable.
  Suit = function(t) suits[t.key] = t end,
  Consumable = function(t) consumables[t.key] = t end,
  Back = function(t) backs[t.key] = t end,
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
-- Vanilla's starting values, which a Back's loc_vars may add its own deltas
-- to rather than restating them.
function get_starting_params()
  return { dollars = 4, hand_size = 8, discards = 3, hands = 4,
           reroll_cost = 5, joker_slots = 5, ante_scaling = 1,
           consumable_slots = 2, no_faces = false,
           erratic_suits_and_ranks = false }
end
-- Wrapped by a mod adding a button to the Collection's front page.
function create_UIBox_your_collection() return { nodes = {} } end
CardArea = {}; function CardArea:emplace() end
love = { graphics = {} }
G = {
  STATES = { SELECTING_HAND=1, SHOP=5, BLIND_SELECT=7, ROUND_EVAL=8, MENU=11,
             NEW_ROUND=19, HAND_PLAYED=2, DRAW_TO_HAND=3, GAME_OVER=4,
             PLAY_TAROT=6, TAROT_PACK=9, PLANET_PACK=10, SPECTRAL_PACK=15,
             STANDARD_PACK=17, BUFFOON_PACK=18, SMODS_BOOSTER_OPENED=999 },
  -- Colour lookups are one or two levels deep (G.C.MULT, but also
  -- G.C.SUITS[key]), so a leaf has to be indexable as well.
  C = setmetatable({}, { __index = function()
        return setmetatable({}, { __index = function() return 0 end })
      end }),
  UIT = {}, GAME = { round = 1 }, ASSET_ATLAS = {}, handlist = {},
  -- Real in the game; a mod adding a Collection tab defines entries in
  -- it at load, which is not a runtime use of anything.
  FUNCS = {},
  P_CARDS = setmetatable({}, { __index = function() return {} end }),
  P_CENTERS = setmetatable({}, { __index = function() return {} end }),
  P_SEALS = setmetatable({}, { __index = function() return {} end }),
}

-- Build a stand-in playing card / joker whose ability mirrors the object's
-- own config, which is what loc_vars reads.
--
-- The TOP-LEVEL config keys are copied as well as `extra`, because Card
-- :set_ability copies them too - h_size and d_size among them, which vanilla
-- reads straight off ability to apply hand size and discards (card.lua:358).
-- Copying only `extra` made a loc_vars that reads one of those look as though
-- it returned nothing.
function fake_card(obj)
  local ability = { extra = {}, perma_x_mult = 0, perma_mult = 0 }
  if obj.config then
    for k, v in pairs(obj.config) do
      if k ~= 'extra' and type(v) ~= 'table' then ability[k] = v end
    end
    if obj.config.extra then
      for k, v in pairs(obj.config.extra) do ability.extra[k] = v end
    end
  end
  return { ability = ability, config = { center = obj }, base = {} }
end

--- How many vars a merged pair's loc_vars supplies.
---
--- A pair describes itself in place of both halves, so its text has the same
--- #n# contract as any other object's - but its loc_vars takes (def, card,
--- state) rather than (self, info_queue, card), and its state is a copy of the
--- pair's own config rather than anything on the card. Same failure either
--- way: a missing var and localize indexes a nil.
function count_pair_vars(def)
  if type(def.loc_vars) ~= "function" then return -1 end
  local state = {}
  for k, v in pairs(def.config or {}) do state[k] = v end
  local card = { ability = { extra = {}, celesta_bind = { special = state } },
                 config = { center = {} }, base = {} }
  local ok, res = pcall(def.loc_vars, def, card, state)
  if not ok then return -2, tostring(res) end
  if type(res) ~= "table" or type(res.vars) ~= "table" then return 0 end
  local n = #res.vars
  for i = 1, n do
    if res.vars[i] == nil then return -3, tostring(i) end
  end
  return n, res.vars.colours and #res.vars.colours or 0
end

--- Calls loc_vars the way the GAME calls it for that kind of object.
---
--- A Back is the odd one out: Back:generate_UI does `back_config:loc_vars()`
--- with nothing after self (back.lua:73, and Steamodded's
--- lovely/back.toml:157), so a Back never receives an info_queue. Handing one
--- to it here would let a deck that indexes info_queue pass this check and
--- then crash on the deck-select screen - which is exactly what happened.
function call_loc_vars(obj, kind)
  if kind == "Back" then return obj:loc_vars() end
  return obj:loc_vars({}, fake_card(obj))
end

function count_vars(obj, kind)
  if type(obj.loc_vars) ~= "function" then return -1 end
  local ok, res = pcall(function()
    return call_loc_vars(obj, kind)
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

-- Whether a Consumable can ever be used.
--
-- Vanilla's Card:can_use_consumeable is a chain of name checks ending in
-- `return false`, and Steamodded patches the obj:can_use dispatch in ahead of
-- it. A modded Consumable with no can_use therefore falls through the chain,
-- matches none of the vanilla names, and its USE button is greyed out for the
-- whole run. Nothing errors; the card simply cannot be played.
function has_can_use(obj)
  return type(obj.can_use) == "function"
end

-- How many vars a Blind's collection_loc_vars supplies.
--
-- Blind text goes through two hooks. loc_vars feeds the text on the Blind once
-- it is in play; collection_loc_vars feeds the popup - the panel on the select
-- screen and the collection entry - which otherwise falls back to self.vars,
-- and SMODS.Blind defaults that to an empty table. Supplying only loc_vars
-- leaves the popup printing "nil" for every placeholder, which is not a crash
-- and so goes unnoticed until someone looks at it.
--
-- -1 means the hook is missing entirely, which is the mistake worth naming.
function count_collection_vars(obj)
  if type(obj.collection_loc_vars) ~= "function" then
    if type(obj.vars) == "table" and #obj.vars > 0 then return #obj.vars end
    return -1
  end
  local ok, res = pcall(function() return obj:collection_loc_vars() end)
  if not ok then return -2, tostring(res) end
  if type(res) ~= "table" or type(res.vars) ~= "table" then return 0 end
  local n = #res.vars
  for i = 1, n do
    if res.vars[i] == nil then return -3, tostring(i) end
  end
  return n
end

-- How many {V:n} colours loc_vars supplies.
--
-- localize reads args.vars.colours[n], so the table has to sit INSIDE vars.
-- Steamodded's generate_ui forwards res.vars, res.key, res.set, res.scale and
-- res.text_colour and nothing else, so a colours table returned BESIDE vars is
-- silently dropped and {V:n} then indexes a nil - which crashes on hover
-- rather than merely rendering wrong. Returning -4 flags exactly that mistake,
-- because it is the one worth naming.
function count_colours(obj, kind)
  if type(obj.loc_vars) ~= "function" then return 0 end
  local ok, res = pcall(function()
    return call_loc_vars(obj, kind)
  end)
  if not ok or type(res) ~= "table" then return 0 end
  if type(res.vars) == "table" and type(res.vars.colours) == "table" then
    return #res.vars.colours
  end
  if type(res.colours) == "table" then return -4 end
  return 0
end
'''


def load_mod():
    """The whole mod, loaded against the stubs above. Returns the Lua runtime.

    Split out so anything else that needs every registered object in one place
    - rather than one Joker sliced out of a file - can borrow the same
    bootstrap instead of growing a second one that drifts from it.
    """
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
    return lua


def main():
    lua = load_mod()

    loc_src = open(os.path.join(ROOT, "localization", "en-us.lua"), encoding="utf-8").read()
    loc = lua.eval('function(s) return assert((loadstring or load)(s,"loc"))() end')(loc_src)

    g = lua.globals()
    count_vars = g.count_vars
    count_colours = g.count_colours
    count_collection_vars = g.count_collection_vars
    has_can_use = g.has_can_use

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
    # A Back's loc_vars has the same shape as everything else's, and its text
    # can carry the same #n# placeholders - Founder's Deck has two. They were
    # skipped here until the Plaid Deck added a third, which is exactly the
    # sort of gap this file exists to close.
    for key, obj in dict(g.backs).items():
        targets.append(("Back", key, "b_celesta_" + key, obj,
                        loc.descriptions.Back))
    for key, obj in dict(g.consumables).items():
        set_name = obj.set or "Tarot"
        table_ = dict(loc.descriptions).get(set_name)
        targets.append(("Consumable", key, "c_celesta_" + key, obj, table_))

    # Merged pairs. A pair's text replaces BOTH halves' descriptions, so a
    # placeholder it does not fill is as fatal as any other - and nothing else
    # here would ever look at them, because they are not registered objects.
    bind = g.CelestasMod.Bind
    pair_defs = {}
    for _, d in dict(bind.SPECIALS).items():
        pair_defs[d.key] = d
    for _, d in dict(bind.WILDCARDS).items():
        pair_defs[d.key] = d

    problems, checked = [], 0
    count_pair_vars = g.count_pair_vars
    for key in sorted(pair_defs):
        def_ = pair_defs[key]
        loc_key = "celesta_bind_" + key
        entry = dict(loc.descriptions.Other).get(loc_key)
        if entry is None:
            problems.append("Merge %s: no localization entry %s" % (key, loc_key))
            continue
        text = " ".join(dict(entry.text).values())
        needed = max((int(n) for n in re.findall(r"#(\d+)#", text)), default=0)
        needed_colours = max((int(n) for n in re.findall(r"\{V:(\d+)", text)),
                             default=0)
        got = count_pair_vars(def_)
        got_colours = 0
        err = ""
        if isinstance(got, tuple):
            got, err = got[0], str(got[1]) if len(got) > 1 else ""
            if got >= 0:
                got_colours = int(err or 0)
        checked += 1
        if got == -2:
            problems.append("Merge %s: loc_vars raised an error: %s" % (key, err))
        elif got == -3:
            problems.append("Merge %s: loc_vars returns nil for var #%s - the "
                            "card will print \"nil\"" % (key, err))
        elif needed > max(got, 0):
            problems.append("Merge %s: text needs #%d# but loc_vars returns "
                            "%d var(s)" % (key, needed, max(got, 0)))
        elif needed_colours > got_colours:
            problems.append("Merge %s: text uses {V:%d} but loc_vars supplies "
                            "%d colour(s)" % (key, needed_colours, got_colours))

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
        # An {X:...} tag paints the multiplier badge; it does not print the
        # "X". A value inside one has to be written as X#n# (or ^#n# for an
        # exponent), or the card reads "by 1.5" where it means "by X1.5".
        bare_badge = re.findall(r"\{X:[^}]*\}\s*#(\d+)#", text)

        # {V:n} picks colours[n] out of vars, and is a separate contract from
        # the #n# placeholders.
        needed_colours = max((int(n) for n in re.findall(r"\{V:(\d+)", text)),
                             default=0)
        # A Consumable that cannot answer can_use is unplayable, which no
        # amount of correct description text makes up for.
        if kind == "Consumable" and not has_can_use(obj):
            problems.append("%s %s: no can_use, so its USE button is greyed "
                            "out forever - vanilla's chain of name checks ends "
                            "in `return false` and a modded key matches none "
                            "of them" % (kind, key))
        got = count_vars(obj, kind)
        got_colours = count_colours(obj, kind)
        # Blinds alone have a second text hook for the popup.
        got_collection = count_collection_vars(obj) if kind == "Blind" else None
        if isinstance(got_collection, tuple):
            got_collection = got_collection[0]
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
        elif bare_badge:
            problems.append("%s %s: #%s# sits in an {X:...} badge with no X - "
                            "the tag paints the badge but does not print the "
                            "letter, so the card reads \"by 1.5\" where it "
                            "means \"by X1.5\"" % (kind, key, bare_badge[0]))
        elif needed_colours > 0 and got_colours == -4:
            problems.append("%s %s: text uses {V:%d} and loc_vars returns colours "
                            "BESIDE vars - it has to be inside, as vars.colours, "
                            "or Steamodded drops it and localize indexes a nil"
                            % (kind, key, needed_colours))
        elif needed > 0 and got_collection == -1:
            problems.append("%s %s: text needs #%d# but there is no "
                            "collection_loc_vars - the Blind select popup and "
                            "the collection will print \"nil\" for every "
                            "placeholder" % (kind, key, needed))
        elif got_collection is not None and needed > max(got_collection, 0):
            problems.append("%s %s: text needs #%d# but collection_loc_vars "
                            "supplies %d var(s)"
                            % (kind, key, needed, max(got_collection, 0)))
        elif needed_colours > max(got_colours, 0):
            problems.append("%s %s: text uses {V:%d} but loc_vars supplies %d "
                            "colour(s) in vars.colours"
                            % (kind, key, needed_colours, max(got_colours, 0)))

    print("checked %d objects" % checked)
    if problems:
        # Not all of these crash: a missing collection_loc_vars or a bare
        # {X:...} badge only renders wrong, which is why that class went
        # unnoticed long enough to need a tool.
        print(chr(10) + "%d PROBLEM(S) - these crash, misprint or disable "
              "an object:" % len(problems))
        for p in problems:
            print("   " + p)
        sys.exit(1)
    print("every description placeholder is supplied by loc_vars")


if __name__ == "__main__":
    main()
