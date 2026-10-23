--- THE PRISM JOKERS
---
--- Rai Byte, Symbxl, Tenma and Froggyhoppins: the four Jokers of the Prism suit (suits/prism.lua), each
--- paid by a different thing a Prism card can be doing - scoring, held in hand, played, or having scored
--- often enough.
---
--- Gated like Cosmic and Auteru: with no Prism in the run's deck there is nothing for any of them to
--- count, so none is offered until one exists.
---
--- Its own file, as the Mythics and the late arrivals are: jokers/implemented.lua is within a handful of
--- Lua's limit of 200 locals in a main chunk, and is sliced apart and run against stubs by the test
--- harnesses.

local function more_than(a, b) return CelestasMod.more_than(a, b) end

--- The Prism suit's name and colour, singular because every description here uses the suit to qualify a
--- noun - "Prism card" - the form vanilla's own suit Jokers use.
local function prism_name_and_colour()
    return CelestasMod.suit_name_and_colour(CelestasMod.PRISM_SUIT, CelestasMod.PRISM_COLOUR, true)
end

--- True when a card counts as a Prism. Asked through is_suit, like every other suit question in this mod,
--- so a Wild Card counts as one - and a debuffed card does not.
local function is_prism(other_card)
    return other_card ~= nil and other_card.is_suit ~= nil
        and other_card:is_suit(CelestasMod.PRISM_SUIT)
end

--- Keeps a Joker out of the pools until the deck holds a Prism, for the Jokers that can do nothing at
--- all without one.
local function prism_gated(self, args)
    return CelestasMod.prism_in_deck()
end

--------------------------------------------------------------------------------
-- Rai Byte [Common] - Cosmic's, for the Prism suit.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "raibyte",
    atlas = "raibyte",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { mult = 3 } },

    in_pool = prism_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = prism_name_and_colour()
        return { vars = { card.ability.extra.mult, name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play and is_prism(context.other_card) then
            return { mult = card.ability.extra.mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Symbxl [Uncommon] - Chips for the Prisms it is kept waiting with.
--------------------------------------------------------------------------------
--
-- "Held in hand when a hand is played": read at `before`, when the played cards have already left the
-- hand, so what is in G.hand.cards is exactly what is being held. Gained there so the hand that earns it
-- is the first to be paid, and never by a copy - the hand was played once. A copy still pays what
-- Symbxl has stored.
--
-- A different size every hand, so it says so (celesta_amount): Vedal raises each hand's own gain to its
-- power, where for a Joker with a rate it would raise the first gain it saw every time.

SMODS.Joker {
    key = "symbxl",
    atlas = "symbxl",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { gain = 66, chips = 0 } },

    in_pool = prism_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = prism_name_and_colour()
        return { vars = { card.ability.extra.gain, card.ability.extra.chips, name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            local held = 0
            for _, in_hand in ipairs((G.hand and G.hand.cards) or {}) do
                if is_prism(in_hand) then held = held + 1 end
            end
            if held <= 0 then return end

            local extra = card.ability.extra
            SMODS.scale_card(card, {
                ref_table = extra, ref_value = "chips",
                scalar_table = { gain = held * extra.gain }, scalar_value = "gain",
                no_message = true,
                celesta_amount = true,
            })
            return {
                message = localize { type = "variable", key = "a_chips", vars = { extra.chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        if context.joker_main and more_than(card.ability.extra.chips, 0) then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- Tenma [Uncommon] - X Chips for the Prisms played this round.
--------------------------------------------------------------------------------
--
-- Every Prism played counts, scored or not: it is read off the whole played hand at `before`, the way
-- Drago reads what was played. The streak is the round's - it goes back to X1 when the round ends, on
-- the Jokers' own once-a-round pass, so a copy never resets it.

SMODS.Joker {
    key = "tenma",
    atlas = "tenma",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { gain = 0.1, x_chips = 1 } },

    in_pool = prism_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = prism_name_and_colour()
        return { vars = { card.ability.extra.gain, card.ability.extra.x_chips, name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            local played = 0
            for _, in_play in ipairs(context.full_hand or {}) do
                if is_prism(in_play) then played = played + 1 end
            end
            if played <= 0 then return end

            local extra = card.ability.extra
            SMODS.scale_card(card, {
                ref_table = extra, ref_value = "x_chips",
                scalar_table = { gain = played * extra.gain }, scalar_value = "gain",
                no_message = true,
                celesta_amount = true,
            })
            return {
                message = localize { type = "variable", key = "a_xchips", vars = { extra.x_chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        if context.end_of_round and context.main_eval and not context.blueprint then
            if more_than(card.ability.extra.x_chips, 1) then
                card.ability.extra.x_chips = 1
                return { message = localize("k_reset"), colour = G.C.RED, card = card }
            end
        end

        if context.joker_main and more_than(card.ability.extra.x_chips, 1) then
            return { x_chips = card.ability.extra.x_chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- Froggyhoppins [Rare] - a Joker slot for every fifty Prisms scored.
--------------------------------------------------------------------------------
--
-- Counted as each Prism scores, so a retrigger counts as another, and kept on the card with the
-- remainder carried: fifty is the whole of it, and a count that somehow ran past a second fifty pays
-- both. The slot is the run's from then on - it is not handed back if the card goes - the way
-- Shoomimi's consumable slot is not. A copy has nothing to count, so it counts nothing.
--
-- Through CelestasMod.bump_limit (jokers/implemented.lua), which writes where Steamodded keeps the
-- number, rather than to card_limit, which is derived.

SMODS.Joker {
    key = "froggyhoppins",
    atlas = "froggyhoppins",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { every = 50, scored = 0 } },

    in_pool = prism_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = prism_name_and_colour()
        return { vars = { card.ability.extra.every, name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if not (context.individual and context.cardarea == G.play and not context.blueprint) then return end
        if not is_prism(context.other_card) then return end

        local extra = card.ability.extra
        extra.scored = extra.scored + 1
        if extra.scored < extra.every then return end

        local slots = math.floor(extra.scored / extra.every)
        extra.scored = extra.scored - slots * extra.every
        CelestasMod.bump_limit(G.jokers, slots)
        return { message = localize("celesta_plus_joker_slot"), colour = G.C.FILTER, card = card }
    end,
}
