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
