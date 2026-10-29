--- LUCKS SHI
---
--- Its own file for the reason Cryogen and KloeKroc have one: it wraps a global at load - Card:set_debuff - and
--- jokers/implemented.lua is sliced apart and run against stubs by the test harnesses, so a hook at the top
--- level of it cannot be loaded there.

local LUCKS_SHI_KEY = "j_" .. SMODS.current_mod.prefix .. "_lucksshi"

--------------------------------------------------------------------------------
-- Lucks Shi [Uncommon] - Lucky cards cannot be debuffed.
--------------------------------------------------------------------------------
--
-- Every debuff a card is given - a Blind's, a Sticker's, another Joker's - ends in Card:set_debuff, so that is
-- where it is refused: the same thing vanilla's own `prevent_debuff` does, which clears a debuff the card
-- already has and returns before it can be given another. Refused HERE rather than lifted after the Blind has
-- decided, which is how KloeKroc spares Obsidian from a Blind and from nothing else - "cannot be debuffed" is
-- everything.
--
-- Through find_joker, so an absorbed half answers, and a debuffed Lucks Shi does not.

--- True when a Lucks Shi that is able to act is out.
local function lucks_shi_out()
    return next(CelestasMod.find_joker(LUCKS_SHI_KEY)) ~= nil
end

--- Cheapest test first: this is asked of every card every time anything is debuffed, and nearly every card
--- is not a Lucky one.
local function is_lucky(card)
    return card ~= nil and card.ability ~= nil and SMODS.has_enhancement(card, "m_lucky") and true or false
end

local celesta_lucks_shi_debuff_ref = Card.set_debuff
function Card:set_debuff(should_debuff)
    if is_lucky(self) and lucks_shi_out() then
        if self.debuff then
            self.debuff = false
            self.debuffed_by_blind = false
        end
        return
    end
    return celesta_lucks_shi_debuff_ref(self, should_debuff)
end

--- Asks the Blind about every Lucky card again.
---
--- A card debuffed before Lucks Shi arrived stays debuffed until something re-judges it, and one it was sparing
--- is spared only for as long as it is out. Both are a question for the Blind, which is what
--- SMODS.recalc_debuff puts to it.
local function rejudge_lucky()
    if not (G.GAME and G.GAME.blind and G.playing_cards) then return end
    for _, held in ipairs(G.playing_cards) do
        if is_lucky(held) then SMODS.recalc_debuff(held) end
    end
end

SMODS.Joker {
    key = "lucksshi",
    atlas = "lucksshi",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A state the run reads rather than a trigger: nothing for a copy to add.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky
        return { vars = {} }
    end,

    -- Both deferred, and for opposite reasons. Arriving, add_to_deck runs BEFORE the card is emplaced in the
    -- row, so find_joker cannot see it yet and the rejudge would find no Lucks Shi. Leaving, remove_from_deck
    -- runs while the card is still in the row, and find_joker would count it for one judgement more than it
    -- should.
    add_to_deck = function(self, card, from_debuff)
        G.E_MANAGER:add_event(Event {
            func = function()
                rejudge_lucky()
                return true
            end
        })
    end,

    remove_from_deck = function(self, card, from_debuff)
        G.E_MANAGER:add_event(Event {
            func = function()
                rejudge_lucky()
                return true
            end
        })
    end,
}
