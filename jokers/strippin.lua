--- STRIPPIN
---
--- Its own file for the usual reason: it wraps globals at load - two of the buttons that take a Joker, and
--- CardArea:emplace - and jokers/implemented.lua is sliced apart and run against stubs by the test harnesses.

local STRIPPIN_KEY = "j_" .. SMODS.current_mod.prefix .. "_strippin"

--------------------------------------------------------------------------------
-- Strippin [Rare] - Jokers can also be held in the Consumables tray.
--------------------------------------------------------------------------------
--
-- The tray is already a row of the same kind as the Joker row - vanilla builds it with type "joker" - and
-- Steamodded already asks every area the Jokers could be in when something happens, the tray among them. So a
-- Joker sitting in it is a Joker in every way that matters: it scores, it triggers, it can be sold. What it
-- lacks is a way in, and that is all this adds.
--
-- A Joker goes to the tray when the Joker row has no room for it, Strippin is out and the tray has room - the
-- row first, because that is where it was always going. That decision is made in the two places the game asks
-- "is there room for this Joker": buying one from the shop, and taking one out of a pack. Each marks the card
-- when the answer is the tray, and the one place every route ends - CardArea:emplace - sends a marked card
-- there instead of to the row.
--
-- The mark is made again every time the question is asked (a button asks it every frame) and cleared when the
-- row has room, so a Joker that was headed for the tray is not sent there after a sale has made room.

local function strippin_out()
    return next(CelestasMod.find_joker(STRIPPIN_KEY)) ~= nil
end

--- Whether `area` has room for `card`, asked the way the game asks it: the slots it already takes, the one
--- more, and whatever slot the card brings itself - a Negative one.
local function has_room(area, card)
    if not (area and area.cards and area.config and card and card.ability) then return false end
    return #area.cards + 1 + (card.ability.extra_slots_used or 0)
        <= area.config.card_limit + (card.ability.card_limit or 0)
end

--- True when `card` is a Joker that has to go to the tray: no room in the row, room in the tray, and a
--- Strippin to allow it.
local function goes_to_tray(card)
    if not (card and card.ability and card.ability.set == "Joker") then return false end
    if not (G.jokers and G.consumeables) then return false end
    if has_room(G.jokers, card) or not has_room(G.consumeables, card) then return false end
    return strippin_out()
end

CelestasMod.strippin_sends_to_tray = goes_to_tray

-- Buying: the room check the Buy button runs when it is pressed.
local celesta_strippin_space_ref = G.FUNCS.check_for_buy_space
G.FUNCS.check_for_buy_space = function(card)
    if card and card.ability and card.ability.set == "Joker" then
        local goes = goes_to_tray(card)
        card.celesta_to_tray = goes or nil
        if goes then return true end
    end
    return celesta_strippin_space_ref(card)
end

-- Taking one out of a pack: the Select button's colour and whether it does anything, set every frame.
local celesta_strippin_select_ref = G.FUNCS.can_select_card
G.FUNCS.can_select_card = function(e)
    celesta_strippin_select_ref(e)
    local card = e.config and e.config.ref_table
    if card and card.ability and card.ability.set == "Joker" then
        local goes = goes_to_tray(card)
        card.celesta_to_tray = goes or nil
        if goes then
            e.config.colour = G.C.GREEN
            e.config.button = "use_card"
        end
    end
end

local celesta_strippin_emplace_ref = CardArea.emplace
function CardArea:emplace(card, location, stay_flipped)
    if self == G.jokers and card and card.celesta_to_tray and G.consumeables then
        card.celesta_to_tray = nil
        return celesta_strippin_emplace_ref(G.consumeables, card, location, stay_flipped)
    end
    return celesta_strippin_emplace_ref(self, card, location, stay_flipped)
end

SMODS.Joker {
    key = "strippin",
    atlas = "strippin",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- A rule about where Jokers may be kept, not a trigger: nothing for a copy to add.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return { vars = {} }
    end,
}
