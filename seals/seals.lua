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
    Gene      = SMODS.current_mod.prefix .. "_Gene",
    Rose      = SMODS.current_mod.prefix .. "_Rose",
    Star      = SMODS.current_mod.prefix .. "_Star",
}

--------------------------------------------------------------------------------
-- Gene — this card is dealt before every other card.
--------------------------------------------------------------------------------
--
-- There is no `calculate` here and there is not meant to be. A seal's
-- calculate answers a scoring pass, and this seal never scores: it decides
-- what reaches the hand in the first place, which happens in
-- G.FUNCS.draw_from_deck_to_hand, before any card is a scoring card.
--
-- So the behaviour lives with the other thing in this mod that reorders the
-- deck for a deal — GlassesJournal, in jokers/implemented.lua — because the
-- two have to agree on one order. Two independent sorts of the same table
-- would mean whichever ran last silently won, and "always drawn first" cannot
-- be true of a rule another rule is allowed to overwrite. That sort reads
-- CelestasMod.SEAL_KEYS.Gene, which is why the key above is the only thing
-- this section really has to get right.

SMODS.Seal {
    key = "Gene",
    atlas = "seals",
    pos = { x = 2, y = 0 },
    badge_colour = HEX("9333A6"),
    discovered = true,
    unlocked = true,
}

--------------------------------------------------------------------------------
-- Star — when NON-scoring, copies the card to its left into the deck.
-- How MANY copies is Ray + CottontailVA's business; see merge/bind.lua.
--------------------------------------------------------------------------------

SMODS.Seal {
    key = "Star",
    atlas = "seals",
    pos = { x = 4, y = 0 },
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

            -- How many, rather than one: Ray + CottontailVA answers two.
            -- Asked through CelestasMod so the seal does not have to know
            -- that merges exist, and asked once per trigger so a merge made
            -- or unmade mid-round takes effect straight away.
            local wanted = CelestasMod.star_seal_copies
                and CelestasMod.star_seal_copies() or 1
            if wanted < 1 then return end

            local made = {}
            for _ = 1, wanted do
                -- Duplication sequence lifted from vanilla DNA, but emplaced
                -- into G.deck rather than G.hand.
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
                made[#made + 1] = copy
            end

            -- El XoX + CottontailVA counts these. Said after the loop rather
            -- than at the trigger: what it is paid for is a card actually
            -- being copied, and `made` is how many really were - which is two
            -- when Ray + CottontailVA is the one answering `wanted`.
            if CelestasMod.star_seal_copied then
                CelestasMod.star_seal_copied(card, left, #made)
            end

            return {
                message = localize("k_copied_ex"),
                colour = G.C.CHIPS,
                card = card,
                playing_cards_created = made,
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

local ECTOPLAST_ODDS = 4

SMODS.Seal {
    key = "Ectoplast",
    atlas = "seals",
    pos = { x = 0, y = 0 },
    badge_colour = HEX("2BC4CE"),
    discovered = true,
    unlocked = true,

    -- The description carries #1# and #2#, so this must supply them; without
    -- it localize() indexes a nil `vars` and the game crashes on hover.
    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, ECTOPLAST_ODDS, "celesta_ectoplast")
        return { vars = { numerator, denominator } }
    end,

    calculate = function(self, card, context)
        if context.main_scoring and context.cardarea == G.play then
            if not SMODS.pseudorandom_probability(
                    card, "celesta_ectoplast", 1, ECTOPLAST_ODDS) then
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

            -- Spite's merges count these. Said here rather than at the roll:
            -- what they are paid for is a Joker actually being upgraded, and
            -- a roll that lands with nothing left to upgrade is not that.
            if CelestasMod.ectoplast_triggered then
                CelestasMod.ectoplast_triggered(card, pick.joker)
            end

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
    pos = { x = 3, y = 0 },
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

--------------------------------------------------------------------------------
-- No "new!" badge on any of them
--------------------------------------------------------------------------------
--
-- A seal that is `discovered` but not yet `alerted` puts a red circled "!" in
-- the top-left corner of every card carrying it (card.lua:83, the branch
-- Steamodded re-applies in lovely/seal.toml:123). That is vanilla's own
-- collection badge - the same one a newly discovered Joker gets - and on a
-- Joker it appears only in the collection, because vanilla gates that branch
-- on `self.area.config.collection`. The seal branch has no such gate, so it
-- lands on the actual playing card, in hand, mid-hand.
--
-- A centre says "do not do that" with `start_alerted`, and the loop that reads
-- the profile honours it - for G.P_CENTERS. The identical loop three screens
-- below it, for G.P_SEALS, does not (smods src/utils.lua:112 against :160), so
-- there is no field a seal can set. Declaring `alerted = true` on the seal
-- does not survive either: the same loop ends `elseif v.discovered then
-- v.alerted = false`, which overwrites it.
--
-- So it is set after those loops instead, at both places one runs:
--
--   * SMODS.SAVE_UNLOCKS, at boot. Vanilla's own pass happens before any mod
--     exists, so this is the one that sees these seals (loader.lua:615, after
--     the objects are injected).
--   * Game:init_item_prototypes, which runs again on a profile change and on
--     the way back to the main menu from a run (button_callbacks.lua:251 and
--     :1822) - and by then the seals ARE in G.P_SEALS, so vanilla's pass
--     clears the flag every time and it has to be put back.

--- Marks every seal this mod adds as already seen.
local function celesta_seals_seen()
    for _, key in pairs(CelestasMod.SEAL_KEYS) do
        local seal = G.P_SEALS and G.P_SEALS[key]
        if seal then seal.alerted = true end
    end
end

-- Both read defensively before being wrapped. Wrapping a nil would not cost a
-- badge, it would cost the mod: the reference would be nil and the first call
-- through would take the whole load down. SAVE_UNLOCKS in particular belongs
-- to Steamodded rather than to the game, and is a name that can move.
local celesta_save_unlocks_ref = SMODS.SAVE_UNLOCKS
if type(celesta_save_unlocks_ref) == "function" then
    function SMODS.SAVE_UNLOCKS(...)
        local out = celesta_save_unlocks_ref(...)
        celesta_seals_seen()
        return out
    end
end

local celesta_item_prototypes_ref = Game and Game.init_item_prototypes
if type(celesta_item_prototypes_ref) == "function" then
    function Game:init_item_prototypes(...)
        local out = celesta_item_prototypes_ref(self, ...)
        celesta_seals_seen()
        return out
    end
end
