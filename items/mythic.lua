--- MYTHIC
---
--- A rarity above Legendary, and one that is not rolled for at all: a Mythic Joker arrives from a
--- Summon (consumables/summon.lua) or from whatever that Joker's own text names, and nowhere else.
--- Weight 0 is how Legendary is declared too (Steamodded game_object.lua:957) - the rarity exists
--- and has a pool, and no ordinary roll ever lands on it.
---
--- A Mythic Joker may only be merged with another Mythic Joker, and a Mythic one with a plain one
--- not at all: merge/bind.lua asks CelestasMod.is_mythic.
---
--- Loaded before the Jokers and before merge/bind.lua, so the key exists wherever it is asked for.
--- The Jokers name it by its prefixed key, which is what a Joker's `rarity` is.

local rarity = SMODS.Rarity {
    key = "mythic",
    loc_txt = {},
    default_weight = 0,
    badge_colour = HEX("e65ce6"),
}

--- The prefixed key the badge and every Mythic Joker refer to. Read back off the object, because
--- the prefix is applied inside the constructor (game_object.lua:33).
CelestasMod.MYTHIC_RARITY = rarity and rarity.key or (SMODS.current_mod.prefix .. "_mythic")

--- Whether a centre is a Mythic Joker.
function CelestasMod.is_mythic_center(center)
    return type(center) == "table" and center.rarity == CelestasMod.MYTHIC_RARITY
end

--- Whether a Joker card is Mythic: its own centre, or the half bound into it by a merge. A merge is
--- only ever made between two Mythic Jokers, so either answers for both.
function CelestasMod.is_mythic(card)
    local config = card and card.config
    if not config then return false end
    if CelestasMod.is_mythic_center(config.center) then return true end
    local bound = card.ability and card.ability.celesta_bind
    local center = type(bound) == "table" and bound.key and G.P_CENTERS and G.P_CENTERS[bound.key]
    return CelestasMod.is_mythic_center(center)
end
