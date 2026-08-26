--- SEALS
---
--- Art is built by tools/gen_seals.py into assets/{1x,2x}/seals.png. Each
--- atlas cell is card shaped (71x95) because Balatro stretches a seal's cell
--- across the whole card; the square emblem is padded into it, anchored where
--- the vanilla seals sit.
---
--- Keys are prefixed, so `Rose` becomes `celesta_Rose`, and its text lives
--- under descriptions.Other / misc.labels as `celesta_rose_seal` (SMODS
--- lowercases the whole prefixed key for localization).
---
--- A seal's calculate is `function(self, card, context)` where `card` is the
--- playing card carrying it. SMODS.score_card sets context.main_scoring with
--- context.cardarea == G.play for scoring cards and == 'unscored' for the
--- rest of the played hand, which is what separates Star from the others.

CelestasMod.SEAL_KEYS = {
    Ectoplast = SMODS.current_mod.prefix .. "_Ectoplast",
    Foppy     = SMODS.current_mod.prefix .. "_Foppy",
    Rose      = SMODS.current_mod.prefix .. "_Rose",
    Star      = SMODS.current_mod.prefix .. "_Star",
}

--------------------------------------------------------------------------------
-- Star — when NON-scoring, copies the card to its left into the deck.
--------------------------------------------------------------------------------

SMODS.Seal {
    key = "Star",
    atlas = "seals",
    pos = { x = 3, y = 0 },
    badge_colour = HEX("F3A0BE"),
    discovered = true,
    unlocked = true,

    calculate = function(self, card, context)
        -- 'unscored' is how SMODS marks played cards outside the scoring hand.
        if context.main_scoring and context.cardarea == "unscored" then
            local hand = context.full_hand or (G.play and G.play.cards)
            if not hand then return end

            local index
            for i, c in ipairs(hand) do
                if c == card then index = i break end
            end
            -- Leftmost card has nothing to its left.
            if not index or index <= 1 then return end
            local left = hand[index - 1]
            if not left then return end

            -- Duplication sequence lifted from vanilla DNA, but emplaced into
            -- G.deck rather than G.hand.
            G.playing_card = (G.playing_card and G.playing_card + 1) or 1
            local copy = copy_card(left, nil, nil, G.playing_card)
            copy:add_to_deck()
            G.deck.config.card_limit = G.deck.config.card_limit + 1
            table.insert(G.playing_cards, copy)
            G.deck:emplace(copy)
            copy.states.visible = nil

            G.E_MANAGER:add_event(Event {
                func = function()
                    copy:start_materialize()
                    return true
                end
            })

            return {
                message = localize("k_copied_ex"),
                colour = G.C.CHIPS,
                card = card,
                playing_cards_created = { copy },
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Ectoplast — when scored, 1 in 4 to upgrade a random Joker's edition,
-- stepping none -> Foil -> Holographic -> Polychrome -> Negative.
--------------------------------------------------------------------------------

-- Current edition key -> what it becomes. Absent from the table means the
-- edition is already at the top of the chain and cannot be upgraded.
local EDITION_UPGRADE = {
    [false]         = "e_foil",       -- no edition at all
    e_foil          = "e_holo",
    e_holo          = "e_polychrome",
    e_polychrome    = "e_negative",
}

SMODS.Seal {
    key = "Ectoplast",
    atlas = "seals",
    pos = { x = 0, y = 0 },
    badge_colour = HEX("2BC4CE"),
    discovered = true,
    unlocked = true,

    calculate = function(self, card, context)
        if context.main_scoring and context.cardarea == G.play then
            if not SMODS.pseudorandom_probability(card, "celesta_ectoplast", 1, 4) then
                return
            end
            if not G.jokers or not G.jokers.cards then return end

            -- Only consider Jokers that actually have somewhere to go.
            local candidates = {}
            for _, joker in ipairs(G.jokers.cards) do
                local current = joker.edition and joker.edition.key or false
                local upgrade = EDITION_UPGRADE[current]
                if upgrade then
                    candidates[#candidates + 1] = { joker = joker, edition = upgrade }
                end
            end
            if #candidates == 0 then return end

            local pick = pseudorandom_element(candidates, pseudoseed("celesta_ectoplast_pick"))
            pick.joker:set_edition(pick.edition, true)
            pick.joker:juice_up(0.3, 0.5)

            return {
                message = localize("celesta_upgraded"),
                colour = G.C.DARK_EDITION,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Rose — when scored, permanently gains X0.1 Mult for this card.
--------------------------------------------------------------------------------

SMODS.Seal {
    key = "Rose",
    atlas = "seals",
    pos = { x = 2, y = 0 },
    badge_colour = HEX("8C2A7A"),
    discovered = true,
    unlocked = true,

    calculate = function(self, card, context)
        if context.main_scoring and context.cardarea == G.play then
            -- perma_x_mult is stored as the amount ABOVE 1: the game scores it
            -- through Card:get_chip_x_mult and prints it on the card as
            -- "X(1 + perma_x_mult) Mult" with no extra work from us.
            card.ability.perma_x_mult = (card.ability.perma_x_mult or 0) + 0.1
            return {
                message = localize {
                    type = "variable",
                    key = "a_xmult",
                    vars = { 1 + card.ability.perma_x_mult },
                },
                colour = G.C.MULT,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Foppy — retriggers this card 2 extra times.
--------------------------------------------------------------------------------

SMODS.Seal {
    key = "Foppy",
    atlas = "seals",
    pos = { x = 1, y = 0 },
    badge_colour = HEX("E8365D"),
    discovered = true,
    unlocked = true,

    calculate = function(self, card, context)
        -- No cardarea gate, matching vanilla Red Seal: this retriggers the
        -- card both when scored and while held in hand.
        if context.repetition then
            return {
                message = localize("k_again_ex"),
                repetitions = 2,
                card = card,
            }
        end
    end,
}
