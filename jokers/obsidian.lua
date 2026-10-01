--- MALLIE SPROUT AND KLOEKROC
---
--- The two Jokers that make something of Obsidian (enhancements/enhancements.lua): one adds
--- the card, the other is what the card is for.
---
--- Its own file rather than a place in implemented.lua, for the reason Cryogen and CDawg
--- have one: KloeKroc wraps a global at load - SMODS.has_any_suit and Blind:debuff_card - and
--- implemented.lua is sliced apart and run against stubs by the test harnesses, so a hook at
--- the top level of it cannot be loaded there.

local OBSIDIAN_KEY = CelestasMod.ENHANCEMENT_KEYS.Obsidian
local KLOEKROC_KEY = "j_" .. SMODS.current_mod.prefix .. "_kloekroc"

--------------------------------------------------------------------------------
-- Mallie Sprout [Uncommon] - at the start of the round, adds an Obsidian card.
--------------------------------------------------------------------------------
--
-- KokoNuts' shape, for the same reasons: built in G.play so the player watches it go in and
-- animated into the deck the way vanilla Marble Joker does, with the getting_sliced guard
-- that stops a Joker destroyed this frame from still firing.
--
-- The card is a random one, rank and suit rolled the way every other random playing card
-- is - SMODS.add_card with set Base - and then made Obsidian. Nothing in the request names
-- a rank, and KokoNuts' fixed seven is a thing about KokoNuts.
--
-- No blueprint guard: a copy adds another, which is what copying it is for.

SMODS.Joker {
    key = "malliesprout",
    atlas = "malliesprout",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[OBSIDIAN_KEY]
        return { vars = {} }
    end,

    calculate = function(self, card, context)
        if context.setting_blind
            and not (context.blueprint_card or card).getting_sliced then
            G.E_MANAGER:add_event(Event {
                func = function()
                    local made = SMODS.add_card {
                        set = "Base",
                        enhancement = OBSIDIAN_KEY,
                        area = G.play,
                        key_append = "celesta_malliesprout",
                    }
                    if not made then return true end

                    SMODS.calculate_effect({
                        message = localize("celesta_plus_obsidian"),
                        colour = G.C.SECONDARY_SET.Enhanced,
                    }, context.blueprint_card or card)

                    G.E_MANAGER:add_event(Event {
                        func = function()
                            draw_card(G.play, G.deck, 90, "up", nil)
                            return true
                        end
                    })

                    -- Lets other Jokers react to a new playing card existing.
                    playing_card_joker_effects({ made })
                    return true
                end
            })
            -- The card is made inside that event, so there is no effect table to hand back
            -- - but eval_card will not consider retriggering a Joker that has not said it
            -- triggered, which is what a retrigger Stamp needs. `nil, true` is vanilla's way.
            return nil, true
        end
    end,
}

--------------------------------------------------------------------------------
-- KloeKroc [Uncommon] - Obsidian counts as any suit, and no blind can debuff it.
--------------------------------------------------------------------------------
--
-- Two questions the game asks of a card, answered in the two places it asks them.
--
-- ANY SUIT. Card:is_suit asks SMODS.has_any_suit, and that is where Wild Card says yes. Wrapped
-- rather than given a flag on the enhancement, because the enhancement is only any-suit while
-- KloeKroc is out. Cheapest test first: this is asked of every card in every hand, and
-- almost every card is not Obsidian.
--
-- NOT DEBUFFED. Every card a Blind judges goes through Blind:debuff_card, and
-- card.debuffed_by_blind is what says the Blind was the one that did it, so this lifts exactly
-- that and nothing else: a debuff from a Sticker or from another Joker is not the Blind's
-- and is left alone. Lifted AFTER the Blind has decided rather than prevented, the way Nimi
-- and the four friends do it, because the Blind recalculates constantly and a card spared
-- once would be judged again on the next recalculation.
--
-- Both through find_joker, so an absorbed half, and a CDawg that has retained one, answer.

--- True when a KloeKroc that is able to act is out.
local function kloekroc_out()
    return next(CelestasMod.find_joker(KLOEKROC_KEY)) ~= nil
end

local function is_obsidian(card)
    local center = card and card.config and card.config.center
    return center ~= nil and center.key == OBSIDIAN_KEY
end

local celesta_kloekroc_any_suit_ref = SMODS.has_any_suit
function SMODS.has_any_suit(card)
    local ret = celesta_kloekroc_any_suit_ref(card)
    if ret then return ret end
    if not is_obsidian(card) then return ret end
    return kloekroc_out() or ret
end

-- Guarded the way the sale hook is: there is always a Blind in the game, and there is not
-- always one in a harness that has sliced a file open to read a single Joker.
local celesta_kloekroc_debuff_ref = Blind and Blind.debuff_card
if celesta_kloekroc_debuff_ref then
    function Blind:debuff_card(card, from_blind)
        local ret = celesta_kloekroc_debuff_ref(self, card, from_blind)
        if not (card and card.debuff and card.debuffed_by_blind) then return ret end
        if not is_obsidian(card) then return ret end
        if not kloekroc_out() then return ret end

        -- The line vanilla ends on for a card its Blind does not want (blind.lua:721),
        -- which is what LIFTS a debuff rather than preventing one.
        card:set_debuff(false)
        return ret
    end
end

--- Asks the Blind about every Obsidian card again.
---
--- A card debuffed before KloeKroc arrived stays debuffed until something re-judges it, and
--- one KloeKroc was sparing is spared only for as long as KloeKroc is out. Both are a
--- question for the Blind, which is what SMODS.recalc_debuff puts to it.
local function rejudge_obsidian()
    if not (G.GAME and G.GAME.blind and G.playing_cards) then return end
    for _, held in ipairs(G.playing_cards) do
        if is_obsidian(held) then SMODS.recalc_debuff(held) end
    end
end

SMODS.Joker {
    key = "kloekroc",
    atlas = "kloekroc",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A state the run reads rather than a trigger, so a copy has nothing further to add - but
    -- nothing here stops one being made, and it is not on the list of Jokers that refuse.
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[OBSIDIAN_KEY]
        return { vars = {} }
    end,

    -- Both deferred, and for opposite reasons. Arriving, add_to_deck runs BEFORE the card is
    -- emplaced in the row (create_card, add_to_deck, emplace is the order everything that
    -- makes a Joker uses), so find_joker cannot see it yet and the rejudge would find no
    -- KloeKroc. Leaving, remove_from_deck runs while the card is still in the row, and
    -- find_joker would count it for one judgement more than it should.
    add_to_deck = function(self, card, from_debuff)
        G.E_MANAGER:add_event(Event {
            func = function()
                rejudge_obsidian()
                return true
            end
        })
    end,

    remove_from_deck = function(self, card, from_debuff)
        G.E_MANAGER:add_event(Event {
            func = function()
                rejudge_obsidian()
                return true
            end
        })
    end,
}
