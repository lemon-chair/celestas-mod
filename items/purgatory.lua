--- THE PURGATORY DECK
---
--- A roguelike deck: after every Boss Blind, before the cash-out, the run stops and offers three
--- modifiers. Each is a boon that comes with a curse, like a Stamp, and the player must take one of
--- the three to go on. The offer can be rerolled twice. The run ends at Ante 12, where the
--- showdown Blind used to be at Ante 8.
---
--- The deck itself is in items/decks.lua and does two things: starts the run here (P.start) and
--- hands every scoring context to P.calculate. Everything else is a hook this file owns, and each
--- of them does nothing unless the run is being played on this deck - or on its sleeve, which
--- CelestasMod.run_has_deck answers for as well.
---
--- WHAT IS KEPT. One table, G.GAME.celesta_purgatory, so a saved run keeps all of it:
---
---   taken        how many times each modifier has been chosen. A modifier that is not
---                `repeatable` leaves the pool once it has been.
---   buffs        the Boss Blind buffs chosen so far (see "The Boss Blinds" below)
---   offers       the three on the table, and `rerolls_used` for them. Kept so that leaving the
---                game with the choice open and coming back finds the same three: a reload is
---                not a reroll.
---   owed         true from the moment a Boss Blind is beaten until a modifier is chosen
---   ...and one flag or count for each standing rule below.
---
--- WHERE THE PROMPT SITS. end_round moves the game to ROUND_EVAL and Game:update_round_eval then
--- builds the cash-out. That function is held (see "The prompt") for as long as a choice is owed,
--- so the cash-out is not built until the choice is made - which is what lets "gain no money from
--- this blind" and "earn $5 at the end of the round" change the payout that is about to be
--- counted.
---
--- A modifier is a table:
---   key         names it, with `kind`, in the localization: celesta_purg_<kind>_<key>
---   kind        "good" or "bad"
---   repeatable  may be offered again after being chosen
---   available   (state) -> bool; whether there is anything for it to do. Not asked of the modifiers
---               with nothing to ask: a modifier that could not change anything is not offered.
---   roll        (state) -> arg, once, when the offer is made. Kept on the offer and handed to
---               `apply` and `vars`, so what the card says and what happens are one thing.
---   vars        (arg) -> the numbers its text prints
---   apply       (state, arg)

CelestasMod.Purgatory = {}
local P = CelestasMod.Purgatory

local Downsides = CelestasMod.StampDownsides

P.DECK = "purgatory"
--- The Ante the run ends at: where the showdown Blind sits, instead of 8.
P.WIN_ANTE = 12
--- Modifiers on the table at once.
P.OFFERS = 3
--- Rerolls of one offer, before any modifier moves it.
P.REROLLS = 2
--- The chance, per Joker the shop offers, that it is a Legendary once they are allowed in it.
P.LEGENDARY_SHOP_RATE = 0.02
--- "A chance" in the Boss modifiers, as 1 in this.
P.BOSS_ODDS = 3
--- What the two price modifiers scale the shop by.
P.PRICE_DOWN, P.PRICE_UP = 0.5, 1.5
--- What the blind size modifier scales every Blind by.
P.BLIND_UP = 1.5

local SEED = "celesta_purgatory"

--------------------------------------------------------------------------------
-- The run's state
--------------------------------------------------------------------------------

--- True while the run is on this deck.
function P.active()
    return (G.GAME and CelestasMod.run_has_deck and CelestasMod.run_has_deck(P.DECK)) and true or false
end

--- The state table. Made on first ask, so a sleeve - which has no `apply` of its own that is
--- certain to run first - and a loaded run both find it there.
function P.state()
    if not G.GAME then return nil end
    local st = G.GAME.celesta_purgatory
    if not st then
        st = { taken = {}, buffs = {}, reroll_bonus = 0, rerolls_used = 0, price_mult = 1 }
        G.GAME.celesta_purgatory = st
    end
    st.taken = st.taken or {}
    st.buffs = st.buffs or {}
    return st
end

--- The state, but only in a run that is on this deck. What every hook below asks.
local function live()
    if not P.active() then return nil end
    return P.state()
end

--- Called as the run starts: the final Ante moves.
function P.start()
    if not G.GAME then return end
    G.GAME.win_ante = P.WIN_ANTE
    P.state()
end

--------------------------------------------------------------------------------
-- Small things the modifiers are made of
--------------------------------------------------------------------------------

local plain = Downsides.plain

--- A plain number for anything that may be one of Talisman's, or 0.
local function number(value)
    return plain(value) or 0
end

--- One element of a list, and where it was, off this deck's own stream.
local function pick(list, seed)
    if #list == 0 then return nil end
    local item, index = pseudorandom_element(list, pseudoseed(SEED .. (seed or "")))
    return item, index
end

local function jokers()
    return (G.jokers and G.jokers.cards) or {}
end

local function is_negative(card)
    return card.edition and card.edition.negative and true or false
end

--- Every Joker for which `test(card)` is true, in row order.
local function jokers_where(test)
    local out = {}
    for _, card in ipairs(jokers()) do
        if test(card) then out[#out + 1] = card end
    end
    return out
end

--- The slot count of an area.
local function limit(area)
    return area and area.config and number(area.config.card_limit) or 0
end

--- Gives every card in the game its price again, after something that moves prices.
local function reprice()
    G.E_MANAGER:add_event(Event {
        func = function()
            for _, card in pairs(G.I.CARD or {}) do
                if card.set_cost then card:set_cost() end
            end
            return true
        end,
    })
end

--- Puts a card of this key in an area. Negative is asked for here and nowhere else.
local function give(key, area, opts)
    opts = opts or {}
    local card = SMODS.add_card {
        key = key, set = opts.set, rarity = opts.rarity, area = area,
        edition = opts.negative and "e_negative" or nil,
        stickers = opts.stickers, force_stickers = opts.stickers and true or nil,
        key_append = "celesta_purgatory",
    }
    -- No start_materialize: it throws a burst of particles in the card's set colour, and what
    -- arrives here is the reward for a choice, not a card coming out of a pack. The Admin Deck
    -- leaves it out of its starting cards for the same reason. A small jolt says it arrived.
    if card and card.juice_up then card:juice_up(0.5, 0.5) end
    return card
end

--- Level every poker hand by `by`, the way Black Hole does: all of them, hidden ones too.
local function level_all(by)
    for hand in pairs(G.GAME.hands or {}) do
        level_up_hand(nil, hand, true, by)
    end
end

--- Take `by` levels off one hand, never below level 1 - the floor the Stamp costs use as well,
--- and for the same reason: level_up_hand does not stop at zero, and a hand at a negative level
--- scores negative Mult. Says how many it took.
local function drop_levels(hand, by)
    local entry = G.GAME.hands and G.GAME.hands[hand]
    if not entry then return 0 end
    local room = math.floor(number(entry.level)) - 1
    if room <= 0 then return 0 end
    local drop = math.min(by, room)
    level_up_hand(nil, hand, true, -drop)
    return drop
end

local function most_played()
    return Downsides.most_played_hand()
end

--- Destroys `fraction` of the cards in the full deck that `test` accepts, picked at random.
local function cull(test, fraction, seed)
    local pool = {}
    for _, card in ipairs(G.playing_cards or {}) do
        if test(card) then pool[#pool + 1] = card end
    end
    local want = math.floor(#pool * fraction + 0.5)
    local doomed = {}
    for _ = 1, math.min(want, #pool) do
        local card, index = pick(pool, seed)
        if not card then break end
        table.remove(pool, index)
        doomed[#doomed + 1] = card
    end
    if #doomed > 0 then SMODS.destroy_cards(doomed) end
    return #doomed
end

--- The three stickers a Joker can be given, and whether this Joker can take each.
local STICKERS = { "eternal", "perishable", "rental" }

local function can_take(card, sticker)
    local center = card.config and card.config.center
    if not (center and card.ability) then return false end
    if card.ability[sticker] then return false end
    return center[sticker .. "_compat"] ~= false
end

--- The stickers a Joker is wearing, whichever mod made them.
local function worn_stickers(card)
    local out = {}
    for key in pairs(SMODS.Stickers or {}) do
        if card.ability and card.ability[key] then out[#out + 1] = key end
    end
    table.sort(out)
    return out
end

--- The vouchers the run has redeemed, as the cards they were kept as.
local function owned_vouchers()
    return (G.vouchers and G.vouchers.cards) or {}
end

--------------------------------------------------------------------------------
-- Taking a voucher back
--------------------------------------------------------------------------------
--
-- A voucher's effect is applied once, when it is bought, and nothing records how to undo it. So
-- each vanilla one is undone here by hand, from what Card:apply_to_run did. A voucher that is not
-- in this table is not offered for removal: taking its name off the list without taking its
-- effect would be a cost that costs nothing.
--
-- Hieroglyph and Petroglyph are left out on purpose. They lowered the Ante, and giving it back
-- would be a curse that moves the whole run forward a step rather than taking something away.
--
-- The rates are worked out afresh from the vouchers still owned rather than taken back by
-- amount, because a Tycoon replaced its Merchant's number rather than adding to it.

local function voucher_extra(key)
    local center = G.P_CENTERS[key]
    return center and center.config and center.config.extra
end

local function owned_voucher(key)
    return G.GAME.used_vouchers and G.GAME.used_vouchers[key]
end

--- A rate set by a Merchant-and-Tycoon style pair of vouchers, from whichever is still owned.
local function pair_rate(base, scale, low, high)
    local x = owned_voucher(high) and voucher_extra(high)
        or owned_voucher(low) and voucher_extra(low)
    if not x then return base end
    return scale * x
end

local VOUCHER_UNDO = {
    v_overstock_norm = function() change_shop_size(-1) end,
    v_overstock_plus = function() change_shop_size(-1) end,
    v_tarot_merchant = function() G.GAME.tarot_rate = pair_rate(4, 4, "v_tarot_merchant", "v_tarot_tycoon") end,
    v_tarot_tycoon = function() G.GAME.tarot_rate = pair_rate(4, 4, "v_tarot_merchant", "v_tarot_tycoon") end,
    v_planet_merchant = function() G.GAME.planet_rate = pair_rate(4, 4, "v_planet_merchant", "v_planet_tycoon") end,
    v_planet_tycoon = function() G.GAME.planet_rate = pair_rate(4, 4, "v_planet_merchant", "v_planet_tycoon") end,
    v_hone = function() G.GAME.edition_rate = pair_rate(1, 1, "v_hone", "v_glow_up") end,
    v_glow_up = function() G.GAME.edition_rate = pair_rate(1, 1, "v_hone", "v_glow_up") end,
    v_magic_trick = function() G.GAME.playing_card_rate = pair_rate(0, 1, "v_magic_trick", "v_illusion") end,
    v_illusion = function() G.GAME.playing_card_rate = pair_rate(0, 1, "v_magic_trick", "v_illusion") end,
    v_clearance_sale = function() G.GAME.discount_percent = pair_rate(0, 1, "v_clearance_sale", "v_liquidation"); reprice() end,
    v_liquidation = function() G.GAME.discount_percent = pair_rate(0, 1, "v_clearance_sale", "v_liquidation"); reprice() end,
    v_seed_money = function() G.GAME.interest_cap = pair_rate(25, 1, "v_seed_money", "v_money_tree") end,
    v_money_tree = function() G.GAME.interest_cap = pair_rate(25, 1, "v_seed_money", "v_money_tree") end,
    v_crystal_ball = function() G.consumeables:change_size(-1) end,
    v_antimatter = function() G.jokers:change_size(-1) end,
    v_paint_brush = function() G.hand:change_size(-1) end,
    v_palette = function() G.hand:change_size(-1) end,
    v_grabber = function() G.GAME.round_resets.hands = G.GAME.round_resets.hands - voucher_extra("v_grabber") end,
    v_nacho_tong = function() G.GAME.round_resets.hands = G.GAME.round_resets.hands - voucher_extra("v_nacho_tong") end,
    v_wasteful = function() G.GAME.round_resets.discards = G.GAME.round_resets.discards - voucher_extra("v_wasteful") end,
    v_recyclomancy = function() G.GAME.round_resets.discards = G.GAME.round_resets.discards - voucher_extra("v_recyclomancy") end,
    v_reroll_surplus = function()
        G.GAME.round_resets.reroll_cost = G.GAME.round_resets.reroll_cost + voucher_extra("v_reroll_surplus")
        G.GAME.current_round.reroll_cost = G.GAME.current_round.reroll_cost + voucher_extra("v_reroll_surplus")
    end,
    v_reroll_glut = function()
        G.GAME.round_resets.reroll_cost = G.GAME.round_resets.reroll_cost + voucher_extra("v_reroll_glut")
        G.GAME.current_round.reroll_cost = G.GAME.current_round.reroll_cost + voucher_extra("v_reroll_glut")
    end,
    -- Nothing to undo: these work by asking whether the voucher is owned.
    v_telescope = function() end,
    v_observatory = function() end,
    v_omen_globe = function() end,
    v_blank = function() end,
    v_directors_cut = function() end,
    v_retcon = function() end,
}

--- The owned vouchers that can be taken back.
local function removable_vouchers()
    local out = {}
    for _, card in ipairs(owned_vouchers()) do
        local key = card.config and card.config.center_key
        local center = card.config and card.config.center
        if key and (VOUCHER_UNDO[key] or (center and type(center.unredeem) == "function")) then
            out[#out + 1] = card
        end
    end
    return out
end

local function take_back_voucher()
    local card = pick(removable_vouchers(), "_voucher")
    if not card then return end
    local key = card.config.center_key
    G.GAME.used_vouchers[key] = nil
    local undo = VOUCHER_UNDO[key]
    if undo then
        undo()
    else
        card.config.center:unredeem(card)
    end
    card.getting_sliced = true
    card:start_dissolve({ G.C.RED })
end

--------------------------------------------------------------------------------
-- The modifiers
--------------------------------------------------------------------------------

P.MODIFIERS = {}
local function add(entry) P.MODIFIERS[#P.MODIFIERS + 1] = entry end

local function dollars()
    return number(G.GAME.dollars)
end

local function booster_slots()
    local shop = G.GAME.shop or {}
    return (shop.booster_max or 2) + ((G.GAME.modifiers or {}).extra_boosters or 0)
end

-- ---------------------------------------------------------------- boons

add { kind = "good", key = "rerolls",
      apply = function(st) st.reroll_bonus = (st.reroll_bonus or 0) + 2 end }

add { kind = "good", key = "debt",
      apply = function() G.GAME.bankrupt_at = (G.GAME.bankrupt_at or 0) - 10 end }

add { kind = "good", key = "income",
      apply = function(st) st.income = (st.income or 0) + 5 end }

add { kind = "good", key = "hand", repeatable = true,
      apply = function() G.GAME.round_resets.hands = G.GAME.round_resets.hands + 1 end }

add { kind = "good", key = "discard", repeatable = true,
      apply = function() G.GAME.round_resets.discards = G.GAME.round_resets.discards + 1 end }

add { kind = "good", key = "joker_slot", repeatable = true,
      apply = function() G.jokers:change_size(1) end }

add { kind = "good", key = "consumable_slot", repeatable = true,
      apply = function() G.consumeables:change_size(1) end }

add { kind = "good", key = "bind_swap", repeatable = true,
      apply = function()
          local key = pick({ "c_celesta_bind", "c_celesta_swap" }, "_bind_swap")
          give(key, G.consumeables, { negative = true })
      end }

add { kind = "good", key = "unsticker", repeatable = true,
      available = function()
          return #jokers_where(function(card) return #worn_stickers(card) > 0 end) > 0
      end,
      apply = function()
          local card = pick(jokers_where(function(c) return #worn_stickers(c) > 0 end), "_unsticker")
          if not card then return end
          local sticker = pick(worn_stickers(card), "_unsticker_which")
          card:remove_sticker(sticker)
          card:juice_up(0.4, 0.4)
      end }

add { kind = "good", key = "hand_size", repeatable = true,
      apply = function() G.hand:change_size(2) end }

add { kind = "good", key = "rare_joker", repeatable = true,
      apply = function() give(nil, G.jokers, { set = "Joker", rarity = "Rare", negative = true }) end }

add { kind = "good", key = "soul", repeatable = true,
      apply = function() give("c_soul", G.consumeables) end }

add { kind = "good", key = "level_all", repeatable = true,
      apply = function() level_all(1) end }

add { kind = "good", key = "skip_boss", repeatable = true,
      apply = function(st) st.disable_boss = (st.disable_boss or 0) + 1 end }

add { kind = "good", key = "legendary_shop",
      apply = function(st) st.legendary_shop = true end }

add { kind = "good", key = "money_15", repeatable = true,
      apply = function() ease_dollars(15) end }

add { kind = "good", key = "money_30", repeatable = true,
      apply = function() ease_dollars(30) end }

add { kind = "good", key = "level_top", repeatable = true,
      apply = function() level_up_hand(nil, most_played(), true, 3) end }

add { kind = "good", key = "odds_double",
      apply = function()
          G.GAME.probabilities.normal = (G.GAME.probabilities.normal or 1) * 2
      end }

add { kind = "good", key = "prices_half",
      apply = function(st)
          st.price_mult = (st.price_mult or 1) * P.PRICE_DOWN
          reprice()
      end }

add { kind = "good", key = "no_tatter",
      apply = function(st) st.no_tatter = true end }

add { kind = "good", key = "shop_slot", repeatable = true,
      apply = function() change_shop_size(1) end }

add { kind = "good", key = "booster_slot", repeatable = true,
      apply = function() SMODS.change_booster_limit(1) end }

add { kind = "good", key = "voucher_slot", repeatable = true,
      apply = function() SMODS.change_voucher_limit(1) end }

add { kind = "good", key = "tarot_double",
      apply = function()
          -- Read by Haruka Karibu's rescale (jokers/implemented.lua), which is the one place
          -- Tarot values are changed: this is one more factor in that same product.
          G.GAME.celesta_tarot_scale = (G.GAME.celesta_tarot_scale or 1) * 2
          if CelestasMod.haruka_refresh then CelestasMod.haruka_refresh(nil, false) end
      end }

add { kind = "good", key = "negative_joker",
      available = function()
          return #jokers_where(function(card) return not is_negative(card) end) > 0
      end,
      apply = function()
          local card = pick(jokers_where(function(c) return not is_negative(c) end), "_neg")
          if not card then return end
          card:set_edition({ negative = true }, true)
      end }

add { kind = "good", key = "drop_buff",
      available = function(st) return next(st.buffs) ~= nil end,
      apply = function(st)
          local keys = {}
          for key in pairs(st.buffs) do keys[#keys + 1] = key end
          table.sort(keys)
          local key = pick(keys, "_drop_buff")
          if key then st.buffs[key] = nil end
      end }

-- ---------------------------------------------------------------- curses

add { kind = "bad", key = "rerolls",
      apply = function(st) st.reroll_bonus = (st.reroll_bonus or 0) - 1 end }

add { kind = "bad", key = "lose_20", repeatable = true,
      apply = function() ease_dollars(-20) end }

add { kind = "bad", key = "broke", repeatable = true,
      -- From a standing start it would be a gift, not a cost.
      available = function() return dollars() > 0 end,
      apply = function() ease_dollars(-G.GAME.dollars) end }

add { kind = "bad", key = "destroy_joker",
      available = function() return #jokers() > 0 end,
      apply = function()
          local card = pick(jokers(), "_destroy_joker")
          if not card then return end
          -- Either half of a merge: both are gone with the card, and neither comes back.
          local center = card.config and card.config.center
          if center and center.key then G.GAME.banned_keys[center.key] = true end
          local bound = card.ability and card.ability.celesta_bind
          if type(bound) == "table" and bound.key then G.GAME.banned_keys[bound.key] = true end
          SMODS.destroy_cards(card, true)
      end }

add { kind = "bad", key = "hand", repeatable = true,
      available = function() return G.GAME.round_resets.hands > 1 end,
      apply = function() G.GAME.round_resets.hands = math.max(1, G.GAME.round_resets.hands - 1) end }

add { kind = "bad", key = "discard", repeatable = true,
      available = function() return G.GAME.round_resets.discards > 0 end,
      apply = function() G.GAME.round_resets.discards = math.max(0, G.GAME.round_resets.discards - 1) end }

add { kind = "bad", key = "joker_slot", repeatable = true,
      available = function() return limit(G.jokers) > 1 end,
      apply = function() G.jokers:change_size(-1) end }

add { kind = "bad", key = "hand_size", repeatable = true,
      available = function() return limit(G.hand) > 1 end,
      apply = function() G.hand:change_size(-1) end }

add { kind = "bad", key = "consumable_slot", repeatable = true,
      available = function() return limit(G.consumeables) > 1 end,
      apply = function() G.consumeables:change_size(-1) end }

add { kind = "bad", key = "lose_negative", repeatable = true,
      available = function() return #jokers_where(is_negative) > 0 end,
      apply = function()
          local card = pick(jokers_where(is_negative), "_lose_neg")
          if card then card:set_edition(nil, true) end
      end }

add { kind = "bad", key = "cull_quarter",
      apply = function() cull(function() return true end, 0.25, "_cull_quarter") end }

add { kind = "bad", key = "boss_big",
      apply = function(st) st.boss_for_big = true end }

add { kind = "bad", key = "blind_size",
      apply = function()
          local params = G.GAME.starting_params
          params.ante_scaling = (params.ante_scaling or 1) * P.BLIND_UP
      end }

add { kind = "bad", key = "boss_repeat",
      apply = function(st) st.boss_repeat = true end }

local function sticker_options()
    local out = {}
    for _, card in ipairs(jokers()) do
        for _, sticker in ipairs(STICKERS) do
            if can_take(card, sticker) then out[#out + 1] = { card = card, sticker = sticker } end
        end
    end
    return out
end

add { kind = "bad", key = "sticker", repeatable = true,
      available = function() return #sticker_options() > 0 end,
      apply = function()
          local option = pick(sticker_options(), "_sticker")
          if option then option.card:add_sticker(option.sticker, true) end
      end }

add { kind = "bad", key = "lose_consumables", repeatable = true,
      available = function() return #((G.consumeables and G.consumeables.cards) or {}) > 0 end,
      apply = function()
          local held = {}
          for i, card in ipairs(G.consumeables.cards) do held[i] = card end
          SMODS.destroy_cards(held)
      end }

add { kind = "bad", key = "no_pay", repeatable = true,
      apply = function()
          -- The Blind that was just beaten, whose reward is read when the cash-out is counted.
          if G.GAME.blind then G.GAME.blind.dollars = 0 end
      end }

add { kind = "bad", key = "prices_up",
      apply = function(st)
          st.price_mult = (st.price_mult or 1) * P.PRICE_UP
          reprice()
      end }

add { kind = "bad", key = "shop_slot",
      available = function() return ((G.GAME.shop or {}).joker_max or 2) > 1 end,
      apply = function() change_shop_size(-1) end }

add { kind = "bad", key = "booster_slot",
      available = function() return booster_slots() > 1 end,
      apply = function() SMODS.change_booster_limit(-1) end }

add { kind = "bad", key = "odds_half",
      apply = function()
          G.GAME.probabilities.normal = (G.GAME.probabilities.normal or 1) * 0.5
      end }

local function any_hand_above_one()
    for _, entry in pairs(G.GAME.hands or {}) do
        if number(entry.level) > 1 then return true end
    end
    return false
end

add { kind = "bad", key = "level_all", repeatable = true,
      available = any_hand_above_one,
      apply = function()
          for hand in pairs(G.GAME.hands or {}) do drop_levels(hand, 1) end
      end }

add { kind = "bad", key = "level_top", repeatable = true,
      available = function()
          local entry = G.GAME.hands and G.GAME.hands[most_played()]
          return entry ~= nil and number(entry.level) > 1
      end,
      apply = function() drop_levels(most_played(), 3) end }

add { kind = "bad", key = "tatter_fast",
      apply = function(st) st.fast_tatter = true end }

add { kind = "bad", key = "lose_voucher",
      available = function() return #removable_vouchers() > 0 end,
      apply = take_back_voucher }

add { kind = "bad", key = "super_boss",
      apply = function(st) st.super_boss = true end }

add { kind = "bad", key = "cull_faces",
      apply = function()
          cull(function(card) return card:is_face(true) end, 0.75, "_cull_faces")
      end }

--- The suits that have at least one card in the full deck.
local function suits_held()
    local seen, out = {}, {}
    for _, card in ipairs(G.playing_cards or {}) do
        local suit = card.base and card.base.suit
        if suit and not seen[suit] then
            seen[suit] = true
            out[#out + 1] = suit
        end
    end
    table.sort(out)
    return out
end

--- A suit's plural name as the game prints it, falling back to the key where it has none.
local function suit_name(suit)
    local name = localize(suit, "suits_plural")
    if type(name) ~= "string" or name == "ERROR" then return tostring(suit) end
    return name
end

add { kind = "bad", key = "cull_suit",
      available = function() return #suits_held() > 0 end,
      -- Which suit is rolled with the offer, so the card names the one that will go.
      roll = function() return (pick(suits_held(), "_suit")) end,
      vars = function(arg) return { suit_name(arg) } end,
      apply = function(st, arg)
          cull(function(card) return card.base and card.base.suit == arg end, 0.5, "_cull_suit")
      end }

add { kind = "bad", key = "obelisk",
      available = function() return #jokers() < limit(G.jokers) end,
      apply = function()
          give("j_obelisk", G.jokers, { stickers = { "eternal" } })
      end }

add { kind = "bad", key = "eternal_perishable",
      available = function()
          return #jokers_where(function(card)
              return (can_take(card, "eternal") or card.ability.eternal)
                  and (can_take(card, "perishable") or card.ability.perishable)
                  and not (card.ability.eternal and card.ability.perishable)
          end) > 0
      end,
      apply = function()
          local card = pick(jokers_where(function(c)
              return (can_take(c, "eternal") or c.ability.eternal)
                  and (can_take(c, "perishable") or c.ability.perishable)
                  and not (c.ability.eternal and c.ability.perishable)
          end), "_eternal_perishable")
          if not card then return end
          card:add_sticker("eternal", true)
          card:add_sticker("perishable", true)
      end }

add { kind = "bad", key = "lose_editions",
      available = function()
          return #jokers_where(function(c) return c.edition and not is_negative(c) end) > 0
      end,
      apply = function()
          for _, card in ipairs(jokers_where(function(c) return c.edition and not is_negative(c) end)) do
              card:set_edition(nil, true)
          end
      end }

-- ---------------------------------------------------------------- the Boss Blinds
--
-- Nine of the curses make one Boss Blind of this mod worse for the rest of the run. Each is a flag
-- in `buffs`, and the Blind itself asks for it (blinds/blinds.lua, CelestasMod.boss_buffed). A
-- boon takes a random one off again, and only offers to when there is one to take.

local BUFFS = { "clover", "flower", "wyrm", "robot", "brick", "goat", "frog", "horn", "gem" }
P.BUFFS = BUFFS

for _, name in ipairs(BUFFS) do
    add { kind = "bad", key = "buff_" .. name,
          apply = function(st) st.buffs[name] = true end }
end

--- The modifier of this kind and key.
local BY_ID = {}
for _, entry in ipairs(P.MODIFIERS) do
    entry.id = entry.kind .. ":" .. entry.key
    BY_ID[entry.id] = entry
end

function P.find(kind, key)
    return BY_ID[kind .. ":" .. tostring(key)]
end

--------------------------------------------------------------------------------
-- Offering them
--------------------------------------------------------------------------------

--- Whether a modifier may be offered now.
function P.offerable(entry, st)
    st = st or P.state()
    if not entry.repeatable and (st.taken[entry.id] or 0) > 0 then return false end
    if entry.available and not entry.available(st) then return false end
    return true
end

local function offerable_of(kind, st)
    local out = {}
    for _, entry in ipairs(P.MODIFIERS) do
        if entry.kind == kind and P.offerable(entry, st) then out[#out + 1] = entry end
    end
    return out
end

--- Three offers, each a boon and a curse, no boon and no curse twice. Fewer when the pools run
--- short, and none when either is empty - in which case there is nothing to choose between.
function P.roll_offers(st)
    local goods, bads = offerable_of("good", st), offerable_of("bad", st)
    local offers = {}
    while #offers < P.OFFERS and #goods > 0 and #bads > 0 do
        local good, gi = pick(goods, "_offer_good")
        local bad, bi = pick(bads, "_offer_bad")
        table.remove(goods, gi)
        table.remove(bads, bi)
        offers[#offers + 1] = {
            good = good.key,
            bad = bad.key,
            bad_arg = bad.roll and bad.roll(st) or nil,
        }
    end
    return offers
end

--- Rerolls of one offer: two, and what the modifiers have added or taken.
function P.max_rerolls(st)
    st = st or P.state()
    return math.max(0, P.REROLLS + (st.reroll_bonus or 0))
end

function P.rerolls_left(st)
    st = st or P.state()
    return math.max(0, P.max_rerolls(st) - (st.rerolls_used or 0))
end

--- Takes one: the pair at `index` goes into effect, and the choice is over.
function P.choose(index)
    local st = P.state()
    local offer = st and st.offers and st.offers[index]
    if not offer then return false end
    local good, bad = P.find("good", offer.good), P.find("bad", offer.bad)
    if not (good and bad) then return false end

    -- Closed first, and the choice written down before anything happens: an effect that fails
    -- must not leave the same three on the table to be taken again.
    st.offers, st.owed, st.rerolls_used = nil, false, 0
    st.taken[good.id] = (st.taken[good.id] or 0) + 1
    st.taken[bad.id] = (st.taken[bad.id] or 0) + 1
    if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end

    for _, entry in ipairs({ good, bad }) do
        local ok, err = pcall(entry.apply, st, entry == bad and offer.bad_arg or nil)
        if not ok then
            CelestasMod.warn_once("purgatory_" .. entry.id,
                ("Purgatory could not apply %s: %s"):format(entry.id, tostring(err)))
        end
    end
    return true
end

--- Throws the three back and deals three more, if there is a reroll left.
function P.reroll()
    local st = P.state()
    if not (st and st.owed and P.rerolls_left(st) > 0) then return false end
    st.rerolls_used = (st.rerolls_used or 0) + 1
    st.offers = P.roll_offers(st)
    return true
end

--------------------------------------------------------------------------------
-- The prompt
--------------------------------------------------------------------------------

--- The lines of one modifier's text, each as the parts a row is made of.
local function text_lines(kind, key, arg)
    local entry = P.find(kind, key)
    local lines = {}
    local ok = pcall(localize, {
        type = "descriptions", set = "Other",
        key = "celesta_purg_" .. kind .. "_" .. key,
        vars = entry and entry.vars and entry.vars(arg) or {},
        nodes = lines,
    })
    return ok and lines or {}
end
P.text_lines = text_lines

--- One modifier's text, in the white box a card's own text sits in.
local function text_box(kind, key, arg)
    local rows = {}
    for _, line in ipairs(text_lines(kind, key, arg)) do
        rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm" }, nodes = line }
    end
    return { n = G.UIT.R, config = { align = "cm", padding = 0.06, r = 0.1, minw = 3.3, minh = 1.0,
                                     colour = G.C.WHITE },
             nodes = { { n = G.UIT.C, config = { align = "cm" }, nodes = rows } } }
end

local function label(text, colour)
    return { n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = {
        { n = G.UIT.T, config = { text = text, scale = 0.38, colour = colour, shadow = true } } } }
end

--- One of the three: the boon over the curse, all of it one button.
local function offer_panel(index, offer)
    return { n = G.UIT.C,
             config = { align = "cm", padding = 0.1, r = 0.12, hover = true, shadow = true,
                        colour = G.C.GREY, emboss = 0.05, minw = 3.6,
                        button = "celesta_purg_pick", ref_table = { index = index },
                        focus_args = { nav = "wide" } },
             nodes = {
                 label(localize("celesta_purg_good"), G.C.GREEN),
                 text_box("good", offer.good),
                 label(localize("celesta_purg_bad"), G.C.RED),
                 text_box("bad", offer.bad, offer.bad_arg),
             } }
end

--- The whole screen. Built from the state, so a reroll is a fresh call and a reload is too.
function P.definition()
    local st = P.state()
    local panels = {}
    for i, offer in ipairs(st.offers or {}) do
        panels[#panels + 1] = offer_panel(i, offer)
        if i < #st.offers then panels[#panels + 1] = { n = G.UIT.C, config = { minw = 0.15 } } end
    end

    local left = P.rerolls_left(st)
    local contents = {
        { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            { n = G.UIT.T, config = { text = localize("celesta_purg_title"), scale = 0.7,
                                      colour = G.C.ORANGE, shadow = true } } } },
        { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            { n = G.UIT.T, config = { text = localize("celesta_purg_prompt"), scale = 0.4,
                                      colour = G.C.UI.TEXT_LIGHT } } } },
        { n = G.UIT.R, config = { align = "cm", padding = 0.15 }, nodes = panels },
        { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            UIBox_button {
                label = { localize("celesta_purg_reroll") .. " (" .. left .. ")" },
                button = "celesta_purg_reroll",
                func = "celesta_purg_can_reroll",
                colour = left > 0 and G.C.GREEN or G.C.UI.BACKGROUND_INACTIVE,
                minw = 3.6, minh = 0.7, scale = 0.45,
            } } },
    }

    -- no_back, because the choice IS the way out; no_esc, because Escape would close the box on
    -- a choice that has not been made.
    return create_UIBox_generic_options { no_back = true, no_esc = true, minw = 12, contents = contents }
end

local function show(flat)
    G.FUNCS.overlay_menu {
        definition = P.definition(),
        config = { no_esc = true, offset = flat and { x = 0, y = 0 } or nil },
    }
end

G.FUNCS.celesta_purg_pick = function(e)
    local ref = e and e.config and e.config.ref_table
    if ref and ref.index then P.choose(ref.index) end
end

G.FUNCS.celesta_purg_can_reroll = function(e)
    if P.rerolls_left() > 0 then
        e.config.colour = G.C.GREEN
        e.config.button = "celesta_purg_reroll"
    else
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    end
end

G.FUNCS.celesta_purg_reroll = function()
    if P.reroll() then
        -- Flat, so the box does not fly up again for what is the same screen with different cards.
        local jiggle = G.ROOM and G.ROOM.jiggle
        show(true)
        if G.ROOM and jiggle then G.ROOM.jiggle = jiggle end
    end
end

--- Whether the cash-out has to wait, and the box is put up if it is not already. Asked every
--- frame by the hook below.
function P.gate()
    local st = live()
    if not (st and st.owed) then return false end

    if not st.offers then
        st.rerolls_used = 0
        st.offers = P.roll_offers(st)
        -- Nothing to choose between: the run goes on rather than waiting on an empty box.
        if #st.offers == 0 then
            st.offers, st.owed = nil, false
            return false
        end
    end
    if not G.OVERLAY_MENU then show(false) end
    return true
end

-- The cash-out is not built while a choice is owed. The first lines are the ones vanilla runs
-- first, so the Play and Discard buttons and the shop are still taken down.
local celesta_purg_eval_ref = Game.update_round_eval
function Game:update_round_eval(dt)
    if P.gate() then
        if self.buttons then self.buttons:remove(); self.buttons = nil end
        if self.shop then self.shop:remove(); self.shop = nil end
        return
    end
    return celesta_purg_eval_ref(self, dt)
end

--------------------------------------------------------------------------------
-- The deck's own scoring contexts
--------------------------------------------------------------------------------

--- Whether the Blind just beaten was the one that ends the run: that has its own screen, and a
--- second box on top of it would be two overlays fighting over one slot.
local function ends_the_run()
    local blind = G.GAME.blind
    return G.GAME.round_resets.ante == G.GAME.win_ante and blind and blind:get_type() == "Boss"
end

function P.calculate(context)
    if not (context.end_of_round or context.setting_blind) then return end
    local st = live()
    if not st then return end

    if context.setting_blind then
        -- A Boss Blind standing in for the Big Blind is still the Big Blind as far as the run
        -- goes: end_round tells the two apart by which prototype was picked, and it was told the
        -- Boss's. Corrected as soon as the Blind is set, which is after it has been read here.
        if G.GAME.blind_on_deck == "Big" and G.P_BLINDS.bl_big
            and G.GAME.round_resets.blind ~= G.P_BLINDS.bl_big and st.boss_for_big then
            G.GAME.round_resets.blind = G.P_BLINDS.bl_big
            -- new_round marked the Boss slot as the current one, from the same prototype.
            local states = G.GAME.round_resets.blind_states
            if states then
                states.Big = "Current"
                if states.Boss == "Current" then states.Boss = "Upcoming" end
            end
        end

        if (st.disable_boss or 0) > 0 and G.GAME.blind and G.GAME.blind.boss then
            st.disable_boss = st.disable_boss - 1
            G.E_MANAGER:add_event(Event {
                func = function()
                    G.GAME.blind:disable()
                    play_sound("timpani")
                    return true
                end,
            })
        end
        return
    end

    -- end_of_round: the per-card passes share this flag.
    if context.individual or context.repetition then return end

    st.owed = (context.beat_boss and not ends_the_run()) and true or false
    if (st.income or 0) > 0 and not context.game_over then
        return { dollars = st.income }
    end
end

--------------------------------------------------------------------------------
-- A Boss Blind in a Big Blind's place, and the Blind that decides which
--------------------------------------------------------------------------------

--- True once the Boss Blind curse has been taken, in a run on this deck.
local function big_may_be_boss()
    local st = live()
    return st and st.boss_for_big
end

-- A Boss Blind in the Big Blind's slot is still the Big Blind. Blind:get_type goes by the
-- Blind's name, so it says Boss - and end_round gives the Ante to anything that says so.
local celesta_purg_type_ref = Blind.get_type
function Blind:get_type()
    local kind = celesta_purg_type_ref(self)
    if kind == "Boss" and G.GAME and self == G.GAME.blind
        and G.GAME.blind_on_deck == "Big" and big_may_be_boss() then
        return "Big"
    end
    return kind
end

--- Whether this Ante is one where the run's own showdown Blind sits.
local function is_showdown_ante()
    local ante = G.GAME.round_resets.ante
    return ante >= 2 and ante % G.GAME.win_ante == 0
end

-- The choices for the Ante are written when the Blind select screen is built, which is after the
-- last Boss was beaten and the Ante moved on, and before any Blind of the new one is chosen.
local celesta_purg_select_ref = create_UIBox_blind_select
function create_UIBox_blind_select(...)
    local st = live()
    local choices = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices
    if st and st.boss_for_big and choices and choices.Big == "bl_big"
        and st.big_rolled ~= G.GAME.round_resets.ante and not is_showdown_ante() then
        st.big_rolled = G.GAME.round_resets.ante
        if SMODS.pseudorandom_probability({}, SEED .. "_big", 1, P.BOSS_ODDS) then
            choices.Big = get_new_boss()
        end
    end
    return celesta_purg_select_ref(...)
end

-- A new Ante starts with a Big Blind that is a Big Blind.
local celesta_purg_reset_ref = reset_blinds
function reset_blinds(...)
    local states = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states
    local turning = states and states.Boss == "Defeated"
    local out = celesta_purg_reset_ref(...)
    if turning and live() then G.GAME.round_resets.blind_choices.Big = "bl_big" end
    return out
end

local celesta_purg_boss_ref = get_new_boss
function get_new_boss(...)
    local st = live()
    if not st then return celesta_purg_boss_ref(...) end

    -- Every Boss Blind eligible again, as though none had been used.
    if st.boss_repeat and type(G.GAME.bosses_used) == "table" then
        for key in pairs(G.GAME.bosses_used) do G.GAME.bosses_used[key] = 0 end
    end

    -- A showdown Blind in a plain Boss's place. get_new_boss asks whether the Ante is the winning
    -- one by `ante % win_ante`, so for the length of the call it is.
    if st.super_boss and not is_showdown_ante() and G.GAME.round_resets.ante >= 2
        and SMODS.pseudorandom_probability({}, SEED .. "_super", 1, P.BOSS_ODDS) then
        local saved = G.GAME.win_ante
        G.GAME.win_ante = G.GAME.round_resets.ante
        local ok, boss = pcall(celesta_purg_boss_ref, ...)
        G.GAME.win_ante = saved
        if not ok then error(boss, 0) end
        return boss
    end
    return celesta_purg_boss_ref(...)
end

--------------------------------------------------------------------------------
-- What is left of the shop
--------------------------------------------------------------------------------

-- Prices: the whole discount, moved. Done around vanilla's own set_cost for the reason the
-- Orbital challenges double a Joker's cost the same way - what a price is made of (inflation,
-- editions, the sell value at half) all comes out as vanilla computes it for a shop that costs
-- this much. Put back afterwards, because set_cost is called again every time a price could
-- have changed.
local celesta_purg_cost_ref = Card.set_cost
function Card:set_cost(...)
    local st = live()
    local scale = st and st.price_mult
    if not scale or scale == 1 then return celesta_purg_cost_ref(self, ...) end

    local saved = G.GAME.discount_percent
    G.GAME.discount_percent = 100 - (100 - (saved or 0)) * scale
    local ok, err = pcall(celesta_purg_cost_ref, self, ...)
    G.GAME.discount_percent = saved
    if not ok then error(err, 0) end
end

-- Legendary Jokers in the shop. Asked about as the shop's own Joker rolls ask about a rarity -
-- vanilla's key for those ends in "sho" - and given a small chance of their own rather than a
-- weight, so the rarities a player already knows keep the odds they have.
local celesta_purg_rarity_ref = SMODS.poll_rarity
function SMODS.poll_rarity(pool_key, rand_key, ...)
    local st = live()
    if st and st.legendary_shop and pool_key == "Joker"
        and type(rand_key) == "string" and rand_key:sub(-3) == "sho"
        and pseudorandom(pseudoseed(SEED .. "_legendary" .. G.GAME.round_resets.ante))
            < P.LEGENDARY_SHOP_RATE then
        -- Only when there is one left to offer: an empty pool is answered with a plain Joker.
        local pool = get_current_pool("Joker", 4, false, nil)
        local empty = (#pool == 1 and pool[1] == "empty_rarity")
        G.ARGS.TEMP_POOL = EMPTY(G.ARGS.TEMP_POOL)
        if not empty then return 4 end
    end
    return celesta_purg_rarity_ref(pool_key, rand_key, ...)
end
