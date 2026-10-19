--- THE MYTHIC JOKERS
---
--- Celesta, Drago, GG, Sox and Treemore. Their art and their names came from the Legends mod,
--- whose code for them did not work and is not used: every one of them is written again here.
--- Broo is the odd one out: its own, and it does nothing until it is merged.
--- DougDoug and ROX are this mod's own as well.
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
--
-- What it gains is a different size every hand, so it says so (celesta_amount): Vedal raises each
-- hand's own gain to its power, where for a Joker with a rate it would raise the first gain it saw
-- every time.

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

--------------------------------------------------------------------------------
-- Broo - does nothing, for now.
--------------------------------------------------------------------------------
--
-- Nothing in it at all: no calculate, no config. What it is for is the ten Jokers it can be merged
-- with and nothing else (merge/bind.lua, Bind.BROO_PARTNERS), each of which it makes into something
-- of its own. Its art is a square, centred in the card's cell - see CelestasMod.SQUARE_JOKERS.

SMODS.Joker {
    key = "broo",
    atlas = "broo",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,
    in_pool = function() return false end,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- DougDoug - every consumable can be used again.
--------------------------------------------------------------------------------
--
-- Cryptid's way: the card is not used up, it is kept and counted. `keep_on_use` is Steamodded's own
-- hook for that - a centre that answers true is neither taken out of its area nor dissolved
-- (button_callbacks.lua:2218) - where Cryptid has a Lovely patch of its own to hold the card back
-- and put it in again afterwards. How many it has been used is kept on the card, as Cryptid keeps
-- `cry_multiuse`; what it is allowed is read off the Jokers in play at the moment, so selling a
-- DougDoug stops the extra uses and a card already used up goes on its next use.
--
-- One use more for every use a DougDoug gives, and every DougDoug gives them: two of them are four
-- extra uses, as two of Cryptid's Quantum Computing vouchers would be. Counted through find_joker,
-- which sees one merged into another Joker and leaves out a debuffed one.
--
-- Wherever it is used from, a card that is kept ends up in the consumable row, and uses what is
-- left there:
--
--   the row     it stays where it is.
--   a pack      it goes to the row when the use is done. Steamodded does that itself for any card
--               that is kept (button_callbacks.lua, "nc and area == G.pack_cards"), which is what
--               makes this the one place a pack's card is kept; Cryptid's own patch leaves packs
--               out, and this does not.
--   the shop    bought and used in one go, it has already left the shop and is in no area when it
--               is used, and the game puts a kept card that is in no area into the row once the use
--               is done (button_callbacks.lua, "nc and not area"). So that is the one thing this
--               must NOT do itself: put it there first and it is in the row twice, one of them with
--               nothing to draw - a slot taken by nothing.
--
-- A card that has no room to go to is used up instead: a pack's card or a shop's is not in the row
-- yet, and keeping it would overfill it.

local DOUGDOUG_KEY = "j_" .. PREFIX .. "_dougdoug"

--- How many extra uses the Jokers in play give every consumable.
function CelestasMod.dougdoug_extra_uses()
    local extra = 0
    for _, found in ipairs(CelestasMod.find_joker(DOUGDOUG_KEY)) do
        extra = extra + (((found.ability or {}).extra or {}).uses or 0)
    end
    return extra
end

--- Where a consumable that is being used is being used from: "row", "pack" or "shop", or nil for
--- anywhere else. Asked in that order, as every guard is against nil - a card with no area at all
--- and a run with no pack open are both nil, and nil equals nil.
local function dougdoug_source(card)
    if G.consumeables and card.area == G.consumeables then return "row" end
    if G.pack_cards and card.area == G.pack_cards then return "pack" end
    -- Bought and used from the shop: taken out of it first, so in no area, and remembered where from.
    if card.area == nil and G.shop_jokers and card.from_area == G.shop_jokers then return "shop" end
    return nil
end

--- Whether the consumable row has a place for `card`, which is not in it. The shop's own test for a
--- card it is about to sell.
local function dougdoug_has_room(card)
    local row = G.consumeables
    return #row.cards + 1 + (card.ability.extra_slots_used or 0)
        <= row.config.card_limit + (card.ability.card_limit or 0)
end

--- Whether `card`, which is being used, is kept for another go. Called as the use starts.
function CelestasMod.dougdoug_keeps(card)
    if not (card and card.ability and G.consumeables) then return false end
    local source = dougdoug_source(card)
    if not source then return false end
    if source ~= "row" and not dougdoug_has_room(card) then return false end

    local allowed = 1 + CelestasMod.dougdoug_extra_uses()
    local taken = (card.ability.celesta_uses_taken or 0) + 1
    -- The last of its uses, or a card that is only ever used the once: used up as it always is.
    if taken >= allowed then return false end

    card.ability.celesta_uses_taken = taken
    -- Neither a pack's card nor a shop's is put in the row here: the game does that once it is used.
    -- What is left, over the card, as Cryptid says it.
    if type(attention_text) == "function" then
        attention_text({
            text = tostring(allowed - taken), scale = 1.1, hold = 0.6, major = card,
            backdrop_colour = (G.C.SET and G.C.SET[card.config.center.set]) or G.C.FILTER,
            align = "bm", offset = { x = 0, y = 0.2 },
        })
    end
    return true
end

local dougdoug_kept = {}

--- Gives every consumable's centre the hook, ahead of whatever it already had.
function CelestasMod.install_dougdoug_hook()
    for _, center in pairs(G.P_CENTERS or {}) do
        if type(center) == "table" and center.consumeable and not dougdoug_kept[center] then
            dougdoug_kept[center] = true
            local ref = center.keep_on_use
            center.keep_on_use = function(self, card, ...)
                if type(ref) == "function" and ref(self, card, ...) then return true end
                return CelestasMod.dougdoug_keeps(card)
            end
        end
    end
end

SMODS.Joker {
    key = "dougdoug",
    atlas = "dougdoug",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    -- A passive the use of a consumable reads, not a trigger; there is nothing to copy.
    blueprint_compat = true, eternal_compat = true,
    in_pool = function() return false end,

    config = { extra = { uses = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.uses } }
    end,
}

--------------------------------------------------------------------------------
-- ROX - Boss Blinds ask for a quarter, and a Showdown for a tenth.
--------------------------------------------------------------------------------
--
-- A Blind's quota is the Ante's amount times the `mult` its prototype carries (blind.lua:118, and
-- UI_definitions.lua:1682 for the number offered on the Blind select screen). Hooking the Ante's
-- amount, as LucyPyre does, would take a share off every Blind and not only a Boss, so it is the
-- Boss prototypes' `mult` that is scaled - which both of those read, so the number offered and the
-- number required cannot disagree, as LucyPyre's note says of its own.
--
-- Scaled from the base the prototype started with, which is kept on it, so selling ROX gives the
-- Blind back exactly and two of them are the share taken twice rather than twice the share. Synced
-- as a Blind is set and as one is offered, which are the only two places a quota is made from it,
-- rather than as ROX comes and goes - a loaded run has ROX and no moment it arrived.

local ROX_KEY = "j_" .. PREFIX .. "_rox"

--- What a Boss Blind's quota is multiplied by while ROX is held: a share off for each, taken of
--- what is left. `showdown` for a Showdown Boss Blind, which is cut further.
function CelestasMod.rox_scale(showdown)
    local scale = 1
    for _, found in ipairs(CelestasMod.find_joker(ROX_KEY)) do
        local extra = (found.ability or {}).extra or {}
        local percent = showdown and extra.showdown or extra.boss or 0
        scale = scale * (1 - percent / 100)
    end
    return math.max(0, scale)
end

--- Puts every Boss Blind's `mult` where the Jokers in play say it should be.
function CelestasMod.rox_sync()
    for _, blind in pairs(G.P_BLINDS or {}) do
        if type(blind) == "table" and blind.boss then
            local base = blind.celesta_rox_base
            if base == nil then
                base = blind.mult
                blind.celesta_rox_base = base
            end
            if type(base) == "number" then
                blind.mult = base * CelestasMod.rox_scale(type(blind.boss) == "table" and blind.boss.showdown)
            end
        end
    end
end

local rox_wrapped = {}

--- Wraps `name` in the table `owner` so that every call syncs first. Once: a second run starting
--- must not put a second wrapper over the first.
local function rox_wrap(owner, name)
    local ref = owner[name]
    if type(ref) ~= "function" or rox_wrapped[ref] then return end
    local function wrapper(...)
        CelestasMod.rox_sync()
        return ref(...)
    end
    rox_wrapped[wrapper] = true
    owner[name] = wrapper
end

function CelestasMod.install_rox_hook()
    rox_wrap(Blind, "set_blind")
    rox_wrap(_G, "create_UIBox_blind_choice")
end

SMODS.Joker {
    key = "rox",
    atlas = "rox",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    -- A passive the quota reads, not a trigger; there is nothing to copy.
    blueprint_compat = true, eternal_compat = true,
    in_pool = function() return false end,

    config = { extra = { boss = 75, showdown = 90 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.boss, card.ability.extra.showdown } }
    end,
}

--------------------------------------------------------------------------------
-- Aga - every Booster Pack is a Mega one, costs $1, and is opened wide.
--------------------------------------------------------------------------------
--
-- Nothing here is a trigger: Aga is owned, and the packs answer. Asked through
-- CelestasMod.joker_in_play, which sees the half of a merge and leaves out a Joker that is
-- debuffed.
--
-- THE PACK ITSELF. Every Booster Pack passes through Card:set_ability on its way to being a card - bought
-- from the shop, handed over by a Tag, made by anything else - so that is where it becomes the Mega
-- one of its own kind: p_arcana_normal_2 is p_arcana_mega_2, and a kind with no Mega is left alone. A
-- pack already on the shelf when Aga arrives is put through the same door.
--
-- WHAT OPENING IT DOES. Twelve cards on the table and eight to take, and the shop's own price of $1.
-- The count is a rule in CelestasMod.PACK_OPTION_RULES (jokers/implemented.lua, Geega's list), asked as
-- the pack is opened: it brings the pack UP to twelve and never down, so Geega's one more is still one
-- more. The number to take is the pack's own `choose`, which is what Card:open reads for it.

CelestasMod.AGA_COST = 1
CelestasMod.AGA_OPTIONS = 12
CelestasMod.AGA_PICKS = 8

local AGA_KEY = "j_celesta_aga"

function CelestasMod.aga_active()
    return CelestasMod.joker_in_play(AGA_KEY)
end

--- The Mega pack of the same kind a pack comes in, or nil: it is one already, it is not a pack that has
--- sizes, or its kind has no Mega. The same number if there is one (the Mega packs are numbered by
--- their art), and the first where there is not.
function CelestasMod.mega_pack(center)
    local key = type(center) == "table" and center.key
    if type(key) ~= "string" then return nil end
    local prefix, size, index = key:match("^(p_.-)_(%a+)_(%d+)$")
    if not (prefix and size ~= "mega") then return nil end
    local centers = G.P_CENTERS
    return centers[prefix .. "_mega_" .. index] or centers[prefix .. "_mega_1"]
end

local celesta_aga_set_ability_ref = Card.set_ability
function Card:set_ability(center, ...)
    if type(center) == "table" and center.set == "Booster" and CelestasMod.aga_active() then
        center = CelestasMod.mega_pack(center) or center
    end
    return celesta_aga_set_ability_ref(self, center, ...)
end

local celesta_aga_set_cost_ref = Card.set_cost
function Card:set_cost(...)
    local ret = celesta_aga_set_cost_ref(self, ...)
    -- Down to the price and no further up: a pack a Coupon Tag made free stays free.
    if self.ability and self.ability.set == "Booster" and (self.cost or 0) > CelestasMod.AGA_COST
        and CelestasMod.aga_active() then
        self.cost = CelestasMod.AGA_COST
    end
    return ret
end

local celesta_aga_open_ref = Card.open
function Card:open(...)
    local ability = self.ability
    if ability and ability.set == "Booster" and CelestasMod.aga_active() then
        local center = self.config and self.config.center
        local own = ability.choose or (center and center.config and center.config.choose) or 1
        ability.choose = math.max(own, CelestasMod.AGA_PICKS)
    end
    return celesta_aga_open_ref(self, ...)
end

CelestasMod.PACK_OPTION_RULES = CelestasMod.PACK_OPTION_RULES or {}
CelestasMod.PACK_OPTION_RULES[#CelestasMod.PACK_OPTION_RULES + 1] = function(pack)
    local extra = pack and pack.ability and pack.ability.extra
    if type(extra) ~= "number" or not CelestasMod.aga_active() then return 0 end
    return math.max(0, CelestasMod.AGA_OPTIONS - extra)
end

--- The packs on the shelf, made Mega and re-priced to what is so now. Queued, because a Joker is
--- asked to leave or arrive before the row says so; and a second time a moment later for one that is
--- leaving, whose card is still in the row for the length of its dissolve.
function CelestasMod.aga_refresh_shop()
    local function refresh()
        local shelf = G.shop_booster and G.shop_booster.cards
        for _, pack in ipairs(shelf or {}) do
            if pack.ability and pack.ability.set == "Booster" then
                local center = pack.config and pack.config.center
                local mega = CelestasMod.aga_active() and CelestasMod.mega_pack(center)
                if mega then pack:set_ability(mega) end
                pack:set_cost()
            end
        end
        return true
    end
    G.E_MANAGER:add_event(Event { func = refresh })
    G.E_MANAGER:add_event(Event { trigger = "after", delay = 1, blockable = false, func = refresh })
end

SMODS.Joker {
    key = "aga",
    atlas = "aga",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    -- The packs are changed by Aga being owned; there is no trigger to copy.
    blueprint_compat = false, eternal_compat = true,
    in_pool = function() return false end,

    loc_vars = function(self, info_queue, card)
        return { vars = { CelestasMod.AGA_COST, CelestasMod.AGA_OPTIONS, CelestasMod.AGA_PICKS } }
    end,

    add_to_deck = function(self, card, from_debuff)
        CelestasMod.aga_refresh_shop()
    end,

    remove_from_deck = function(self, card, from_debuff)
        CelestasMod.aga_refresh_shop()
    end,
}

--------------------------------------------------------------------------------
-- Magnetar - the cards that have been played most are dealt first, and nothing wears out:
-- it turns Auric instead.
--------------------------------------------------------------------------------
--
-- Both halves are somewhere else. The deal is jokers/implemented.lua's one sort of the deck, which asks
-- for Magnetar there (`deal_reorder`); the wear is wear/tattered.lua's, which asks here. The Auric
-- edition is editions/auric.lua's. Like Aga, Magnetar is owned and the rest of the game answers it.
--
-- Credit for the art: PVZ Fusion (the Credits tab).

CelestasMod.MAGNETAR_KEY = "j_celesta_magnetar"

SMODS.Joker {
    key = "magnetar",
    atlas = "magnetar",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,
    in_pool = function() return false end,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.AURIC_KEY]
        return { vars = {} }
    end,
}

--------------------------------------------------------------------------------
-- Seabill - $50 at the end of the round, and a dollar less each time.
--------------------------------------------------------------------------------
--
-- Paid through calc_dollar_bonus, so the money has its own line on the cash-out the way Projekt
-- Melody's and Rocket's do. What it is worth is taken off AFTER the cash-out, not before: the end of the
-- round only marks the payout as owed (`owed`), and the shop that follows the cash-out takes the dollar
-- off, which is the first moment that is unambiguously after the payout has been collected. Skipping the
-- Blind's shop never happens - a cash-out always leads to one - and a Seabill bought in the shop was
-- not in the row for the round, so it is owed nothing and loses nothing until it has been paid.
--
-- At $0 it goes the way Gros Michel does, beat for beat, which is also the route merge/bind.lua
-- watches: a merged Seabill unmerges and leaves its partner behind.

CelestasMod.SEABILL_DOLLARS = 50
CelestasMod.SEABILL_LOSS = 1

SMODS.Joker {
    key = "seabill",
    atlas = "seabill",
    pos = { x = 0, y = 0 },
    rarity = MYTHIC, cost = 20,
    unlocked = true, discovered = false,
    -- Copying it would pay twice for one round and drain it twice for one shop.
    blueprint_compat = false, eternal_compat = false,
    in_pool = function() return false end,

    config = { extra = { dollars = CelestasMod.SEABILL_DOLLARS, loss = CelestasMod.SEABILL_LOSS } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.dollars, card.ability.extra.loss } }
    end,

    calc_dollar_bonus = function(self, card)
        local dollars = card.ability.extra.dollars
        if not CelestasMod.more_than(dollars, 0) then return end
        return dollars
    end,

    calculate = function(self, card, context)
        if context.blueprint then return end
        local extra = card.ability.extra

        -- The once-a-round Joker pass. Without main_eval this is also heard for every card held in hand.
        if context.end_of_round and context.main_eval and not context.game_over then
            extra.owed = true
            return
        end

        if context.starting_shop and extra.owed then
            extra.owed = nil
            extra.dollars = extra.dollars - extra.loss

            if extra.dollars <= 0 then
                -- Gros Michel's exit, beat for beat.
                G.E_MANAGER:add_event(Event {
                    func = function()
                        play_sound("tarot1")
                        card.T.r = -0.2
                        card:juice_up(0.3, 0.4)
                        card.states.drag.is = true
                        card.children.center.pinch.x = true
                        G.E_MANAGER:add_event(Event {
                            trigger = "after", delay = 0.3, blockable = false,
                            func = function()
                                G.jokers:remove_card(card)
                                card:remove()
                                return true
                            end
                        })
                        return true
                    end
                })
                return
            end

            return {
                message = localize { type = "variable", key = "celesta_seabill_loss", vars = { extra.loss } },
                colour = G.C.MONEY,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Both hooks go on when a run starts, for the reason LucyPyre's does: every other mod has loaded by
-- then, so these sit outside whatever they left behind rather than under it.
--------------------------------------------------------------------------------

local celesta_mythic_start_ref = Game.start_run
function Game:start_run(...)
    CelestasMod.install_dougdoug_hook()
    CelestasMod.install_rox_hook()
    return celesta_mythic_start_ref(self, ...)
end
