--- GLOBALS
--- Custom colours usable in localization text as {C:celesta_pink} etc.

G.C.CELESTA = {
    PINK    = HEX("FF6FB5"),
    PURPLE  = HEX("6C5CE7"),
    TEAL    = HEX("00B8A9"),
    GOLD    = HEX("F2C94C"),
    WHITE   = HEX("FFFFFF"),
}

-- Hooks

local loc_colour_ref = loc_colour
function loc_colour(_c, _default)
    if not G.ARGS.LOC_COLOURS then
        loc_colour_ref()
    end
    G.ARGS.LOC_COLOURS.celesta_pink   = G.C.CELESTA.PINK
    G.ARGS.LOC_COLOURS.celesta_purple = G.C.CELESTA.PURPLE
    G.ARGS.LOC_COLOURS.celesta_teal   = G.C.CELESTA.TEAL
    G.ARGS.LOC_COLOURS.celesta_gold   = G.C.CELESTA.GOLD
    G.ARGS.LOC_COLOURS.celesta_white  = G.C.CELESTA.WHITE
    return loc_colour_ref(_c, _default)
end

--- Log a message once per key, so a per-frame failure reports itself without
--- flooding the log. Used where this mod interoperates with other mods and
--- cannot assume their internals.
local warned = {}
function CelestasMod.warn_once(key, message)
    if warned[key] then return end
    warned[key] = true
    sendWarnMessage(message, "CelestasMod")
end

--------------------------------------------------------------------------------
-- Config backfill
--------------------------------------------------------------------------------
--
-- A card stores its own copy of its centre's config in card.ability.extra, and
-- that copy is written into the save. So a joker obtained BEFORE its config
-- changed keeps the old fields forever: when a placeholder carrying
-- extra = { mult = 4 } is implemented as extra = { chips = 0, chip_gain = 5 },
-- its loc_vars asks for chip_gain, gets nil, and the description prints "nil".
-- The same nil reaches calculate, so it is not only cosmetic.
--
-- Rather than making every loc_vars defensive one at a time, top up any of this
-- mod's cards with the keys its centre defines but the card is missing.
-- Existing values always win, so a joker that has scaled keeps its progress.

--- The mod table, captured while loading: SMODS.current_mod is only valid
--- then, and backfill runs long afterwards.
CelestasMod.MOD = SMODS.current_mod

--- Fill in any config keys a card is missing from its centre's defaults.
--- Returns the keys it added, for logging.
function CelestasMod.backfill_config(card)
    local center = card and card.config and card.config.center
    if not center then return end
    -- Only this mod's objects: another mod's card is not ours to repair.
    -- SMODS stamps every registered object with the mod that declared it,
    -- which is exact - matching on the key string would also catch anything
    -- that merely happens to contain the prefix.
    if center.mod ~= CelestasMod.MOD then return end
    if type(center.config) ~= "table" or type(center.config.extra) ~= "table" then return end

    card.ability = card.ability or {}
    if type(card.ability.extra) ~= "table" then card.ability.extra = {} end

    local added
    for key, value in pairs(center.config.extra) do
        if card.ability.extra[key] == nil then
            card.ability.extra[key] = value
            added = added and (added .. ", " .. key) or key
        end
    end
    return added
end

local card_load_ref = Card.load
function Card:load(cardTable, other_card)
    card_load_ref(self, cardTable, other_card)
    local added = CelestasMod.backfill_config(self)
    if added then
        CelestasMod.warn_once("backfill_" .. tostring(self.config.center.key),
            ("Filled in missing config on %s: %s")
                :format(tostring(self.config.center.key), added))
    end
end

--- True when a centre was registered by this mod.
--- SMODS stamps every object it registers with the mod that declared it, which
--- is a far more reliable test than matching on the key prefix - a key can be
--- taken over, and other mods can carry a similar prefix.
function CelestasMod.is_ours(center)
    return center ~= nil and center.mod ~= nil and center.mod == CelestasMod.MOD
end

--------------------------------------------------------------------------------
-- Which numbers in a description may be scaled
--------------------------------------------------------------------------------

-- A card's loc_vars is an unlabelled ordered list. Lucky Card's is
--     { probability, 5, 20, 15, 20 }
-- printed as "#1# in #2# chance for +#3# Mult" and "#1# in #4# to win $#5#":
-- only #3# and #5# are values, #2# and #4# are odds. Nothing in the list says
-- which is which.
--
-- The description text does. Balatro marks every number with the colour it
-- prints in, and a value is always written in mult, chip or money markup while
-- odds are green and counts are attention. So the markup immediately before
-- each #n# decides whether it may be scaled.
local SCALABLE_MARKUP = { "mult", "chips", "money" }

--- Which loc_var indices a centre prints as a scalable value, and how.
--- Returns index -> "mult" for a multiplier (X:mult, X:chips) or "add" for a
--- plain amount (C:mult, C:chips, C:money); nil when there is nothing to scale
--- or no description to read.
---
--- The two are not scaled the same way, which is why they are told apart here
--- rather than lumped together: halving Glass's X2 Mult means X1.5, not X1.
function CelestasMod.scalable_vars(set, key)
    local descriptions = G.localization and G.localization.descriptions
    local block = descriptions and set and descriptions[set]
    local entry = block and key and block[key]
    if not (entry and entry.text) then return nil end

    local marked = nil
    for _, line in ipairs(entry.text) do
        -- The nearest {markup} before a #n#, with no other placeholder or
        -- brace between them, is the one it prints in.
        for markup, index in string.gmatch(line, "{([^}]*)}[^#{]*#(%d+)#") do
            local scalable = false
            for _, want in ipairs(SCALABLE_MARKUP) do
                if string.find(markup, want, 1, true) then scalable = true break end
            end
            if scalable then
                marked = marked or {}
                -- "X:mult" is a multiplier, "C:mult" an amount.
                marked[tonumber(index)] =
                    string.find(markup, "X:", 1, true) and "mult" or "add"
            end
        end
    end
    return marked
end

--- A copy of `vars` with the marked entries scaled.
---
--- `multiplier_excess` selects how a multiplier is scaled, and must match how
--- the same value is scaled when it SCORES, or the card advertises one number
--- and pays another:
---   false - the multiplier itself moves.       Vedal: X3 -> X4.5
---   true  - only the part above 1 moves.       Tattered: X2 -> X1.5
---
--- Copied rather than scaled in place: these come straight off a card's
--- ability in some cases, and scaling that would change the real thing every
--- time the card was hovered.
function CelestasMod.scale_vars(vars, marked, scale, multiplier_excess)
    local out = {}
    for i, v in ipairs(vars) do
        local kind = marked[i]
        -- Only numbers. Several jokers pass a STRING built with
        -- ''..probabilities.normal, and arithmetic on it would error.
        if kind and type(v) == "number" then
            if kind == "mult" and multiplier_excess and v > 1 then
                out[i] = 1 + (v - 1) * scale
            else
                out[i] = v * scale
            end
        else
            out[i] = v
        end
    end
    return out
end
