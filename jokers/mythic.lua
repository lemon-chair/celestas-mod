--- THE MYTHIC JOKERS
---
--- Celesta, Drago, GG, Sox and Treemore. Their art and their names came from the Legends mod,
--- whose code for them did not work and is not used: every one of them is written again here.
---
--- All Mythic (items/mythic.lua), so none is ever in the shop, and a Summon (consumables/summon.lua)
--- is how one arrives. Calamitas and Yharon are Mythic too and live where they always have.
---
--- Its own file for the usual reason: GG wraps a global at load, and jokers/implemented.lua is
--- sliced apart and run against stubs by the test harnesses.

local PREFIX = SMODS.current_mod.prefix

local MYTHIC = PREFIX .. "_mythic"

local function more_than(a, b) return CelestasMod.more_than(a, b) end

--------------------------------------------------------------------------------
-- Celesta - a Negative copy of the leftmost Joker, whenever a Blind is beaten.
--------------------------------------------------------------------------------
--
-- "Not counting itself" is the card the effect is asked of: under a Blueprint the calculate is
-- still handed the Celesta, so the copy is still of whatever stands leftmost besides it.
--
-- end_of_round with main_eval is the Jokers' own pass, once a round; game_over is false when the
-- Blind was beaten (or something saved the run), and that is the only moment this is for.

SMODS.Joker {
    key = "celesta",
    atlas = "celesta",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,
    in_pool = function() return false end,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.e_negative
        return {}
    end,

    calculate = function(self, card, context)
        if not (context.end_of_round and context.main_eval and not context.game_over) then return end
        if not (G.jokers and G.jokers.cards) then return end

        local target
        for _, joker in ipairs(G.jokers.cards) do
            if joker ~= card then target = joker break end
        end
        if not target then return end

        G.E_MANAGER:add_event(Event {
            trigger = "before",
            delay = 0.0,
            func = function()
                -- It may have been sold or destroyed between the Blind and now.
                if target.area ~= G.jokers then return true end
                -- Edition stripped and then made Negative, rather than copied and overwritten:
                -- the copy has no edition of the original's to leave behind.
                local copy = copy_card(target, nil, nil, nil, true)
                copy:set_edition({ negative = true }, true)
                copy:add_to_deck()
                G.jokers:emplace(copy)
                copy:start_materialize()
                return true
            end,
        })

        return {
            message = localize("k_copied_ex"),
            colour = G.C.DARK_EDITION,
            card = context.blueprint_card or card,
        }
    end,
}

--------------------------------------------------------------------------------
-- Drago - Chips for good, ten times the stored Chips of what was played.
--------------------------------------------------------------------------------
--
-- "Stored Chips" is what a card is worth in Chips - its rank, its enhancement's bonus and any
-- permanent bonus on top - which is get_chip_bonus, the reading Dokibird's description means by the
-- phrase. Every card played counts, scored or not, and a debuffed one is worth nothing.
--
-- Gained at `before` so the hand that grows it is the first to be paid, and never by a copy:
-- the cards were played once. A copy still pays what Drago has stored.

CelestasMod.DRAGO_RATE = 10

SMODS.Joker {
    key = "drago",
    atlas = "drago",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,
    in_pool = function() return false end,

    config = { extra = { chips = 0, rate = CelestasMod.DRAGO_RATE } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.rate, card.ability.extra.chips } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            local sum = 0
            for _, played in ipairs(context.full_hand or {}) do
                sum = sum + (played.get_chip_bonus and played:get_chip_bonus() or 0)
            end
            if not more_than(sum, 0) then return end

            local extra = card.ability.extra
            SMODS.scale_card(card, {
                ref_table = extra, ref_value = "chips",
                scalar_table = { gain = sum * extra.rate }, scalar_value = "gain",
                no_message = true,
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
-- GG - Negative Jokers and consumables, a coin flip at a time.
--------------------------------------------------------------------------------
--
-- Every Joker and consumable that is MADE - in the shop, in a pack, by a Tarot, by another Joker,
-- from anywhere - comes through create_card, so that is where the coin is flipped. Playing cards,
-- packs and vouchers are not Jokers or consumables and are left alone, and so is a card made
-- somewhere that is not a place a player gets cards (the Collection builds its own).
--
-- A card made with an edition asked for (SMODS.bypass_create_card_edition) keeps it, which is
-- also what stops what GG hands out itself being rolled a second time.
--
-- The odds are listed ones, so Oops! All 6s doubles them like any other.

CelestasMod.GG_ODDS = 2
CelestasMod.GG_CONSUMABLES = 2

--- The first GG in play that is able to act, as the lookups answer.
local function gg_active()
    local found = CelestasMod.find_joker and CelestasMod.find_joker("j_" .. PREFIX .. "_gg")[1]
    return found and found.card or nil
end

local celesta_gg_create_ref = create_card
function create_card(_type, area, ...)
    local card = celesta_gg_create_ref(_type, area, ...)
    if not (card and G.GAME and area) then return card end
    if not (area == G.jokers or area == G.consumeables or area == G.shop_jokers
            or area == G.pack_cards) then
        return card
    end
    if SMODS.bypass_create_card_edition then return card end

    local ability = card.ability
    if not (ability and (ability.set == "Joker" or ability.consumeable)) then return card end
    if card.edition and card.edition.negative then return card end

    local gg = gg_active()
    if not gg then return card end
    if SMODS.pseudorandom_probability(gg, "celesta_gg", 1, CelestasMod.GG_ODDS, "celesta_gg") then
        card:set_edition({ negative = true }, true)
    end
    return card
end

--- The kinds of consumable GG may hand out: the three the base game has, and any other that a
--- shop would stock.
local function consumable_sets()
    local out = { "Tarot", "Planet", "Spectral" }
    local vanilla = { Tarot = true, Planet = true, Spectral = true }
    local extra = {}
    for key, kind in pairs(SMODS.ConsumableTypes or {}) do
        if not vanilla[key] and (kind.shop_rate or 0) > 0 then extra[#extra + 1] = key end
    end
    table.sort(extra)
    for _, key in ipairs(extra) do out[#out + 1] = key end
    return out
end

SMODS.Joker {
    key = "gg",
    atlas = "gg",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,
    in_pool = function() return false end,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.e_negative
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, CelestasMod.GG_ODDS, "celesta_gg")
        return { vars = { numerator, denominator, CelestasMod.GG_CONSUMABLES } }
    end,

    calculate = function(self, card, context)
        if not (context.setting_blind and not (context.blueprint_card or card).getting_sliced) then
            return
        end

        -- Negative cards bring their own slot, so there is no room to ask for.
        G.E_MANAGER:add_event(Event {
            trigger = "before",
            delay = 0.0,
            func = function()
                SMODS.add_card { set = "Joker", edition = "e_negative", key_append = "celesta_gg" }
                local sets = consumable_sets()
                for _ = 1, CelestasMod.GG_CONSUMABLES do
                    SMODS.add_card {
                        set = pseudorandom_element(sets, pseudoseed("celesta_gg_set")),
                        area = G.consumeables, edition = "e_negative",
                        key_append = "celesta_gg",
                    }
                end
                return true
            end,
        })

        return {
            message = localize("celesta_negatives"),
            colour = G.C.DARK_EDITION,
            card = context.blueprint_card or card,
        }
    end,
}

--------------------------------------------------------------------------------
-- Sox - what scored is kept, and sometimes made better.
--------------------------------------------------------------------------------
--
-- After scoring, each scoring card is copied into the deck for good. Each copy is a coin flip from
-- Polychrome. Seals are then settled on the copy as it stands:
--
--   a copy that has a Red Seal (the card it was taken from had one) takes a Foppy Seal in its place
--   a Steel or Gold copy with no seal is a coin flip from a Red Seal
--
-- in that order, so a Red Seal made by the second rule is a Red Seal until it is copied in turn. A
-- copy wearing some other seal keeps it.

CelestasMod.SOX_ODDS = 2

--- Makes one permanent copy of a played card into the deck, and returns it.
--- The deck's way in is vanilla DNA's: a playing-card number, a slot more on the deck, the list of
--- playing cards, and a materialize on the next frame.
local function sox_copy(source)
    G.playing_card = (G.playing_card and G.playing_card + 1) or 1
    local copy = copy_card(source, nil, nil, G.playing_card)
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
    return copy
end

--- Settles the copy's edition and seal. `card` is the Sox, which the odds are asked as.
local function sox_dress(card, copy)
    if SMODS.pseudorandom_probability(card, "celesta_sox_edition", 1, CelestasMod.SOX_ODDS,
                                      "celesta_sox_edition") then
        copy:set_edition({ polychrome = true }, true)
    end

    if copy.seal == "Red" then
        copy:set_seal(CelestasMod.SEAL_KEYS.Foppy, true, true)
    elseif not copy.seal
        and (SMODS.has_enhancement(copy, "m_steel") or SMODS.has_enhancement(copy, "m_gold"))
        and SMODS.pseudorandom_probability(card, "celesta_sox_seal", 1, CelestasMod.SOX_ODDS,
                                           "celesta_sox_seal") then
        copy:set_seal("Red", true, true)
    end
end

SMODS.Joker {
    key = "sox",
    atlas = "sox",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,
    in_pool = function() return false end,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.e_polychrome
        info_queue[#info_queue + 1] = { key = "red_seal", set = "Other" }
        info_queue[#info_queue + 1] = { key = "celesta_foppy_seal", set = "Other" }
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, CelestasMod.SOX_ODDS, "celesta_sox_edition")
        return { vars = { numerator, denominator } }
    end,

    calculate = function(self, card, context)
        if not (context.after and context.scoring_hand and not context.individual
                and not context.repetition) then
            return
        end

        local made = {}
        for _, scored in ipairs(context.scoring_hand) do
            local copy = sox_copy(scored)
            sox_dress(card, copy)
            made[#made + 1] = copy
        end
        if #made == 0 then return end

        playing_card_joker_effects(made)
        return {
            message = localize("k_copied_ex"),
            colour = G.C.CHIPS,
            card = context.blueprint_card or card,
        }
    end,
}

--------------------------------------------------------------------------------
-- Treemore - money, doubled.
--------------------------------------------------------------------------------
--
-- Once a Blind is beaten: a Boss Blind always, and any other when the score was over twice what it
-- asked. The comparison is made the way every one against the score is, since a score is
-- Talisman's number once it is large.

SMODS.Joker {
    key = "treemore",
    atlas = "treemore",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,
    in_pool = function() return false end,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        if not (context.end_of_round and context.main_eval and not context.game_over) then return end
        if not (G.GAME and G.GAME.blind) then return end

        local over_double = more_than(G.GAME.chips, G.GAME.blind.chips * 2)
        if not (context.beat_boss or over_double) then return end

        local dollars = G.GAME.dollars
        if not more_than(dollars, 0) then return end

        -- Through ease_dollars so the counter animates and the ledger is kept, and the amount is
        -- the whole of what is held: one more of it is a double.
        ease_dollars(dollars)
        return {
            message = localize("celesta_doubled"),
            colour = G.C.MONEY,
            card = context.blueprint_card or card,
        }
    end,
}
