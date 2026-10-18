--- THE PURGATORY DECK
---
--- A roguelike deck: after every Boss Blind, before the cash-out, the run stops and offers three
--- modifiers. Each is a pro that comes with a con, like a Stamp, and the player must take one of
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
--- The chance, on the Celestial Stake, that a modifier in an offer is hidden: 1 in this.
P.HIDDEN_ODDS = 4
--- What the two price modifiers scale the shop by.
P.PRICE_DOWN, P.PRICE_UP = 0.5, 1.5
--- What the blind size modifier scales every Blind by.
P.BLIND_UP = 1.5
--- What the blind size pro scales every Blind by.
P.BLIND_DOWN = 0.75

local SEED = "celesta_purgatory"

--- What a Boss Blind's key of this mod starts with. Resolved here: SMODS.current_mod is only set while
--- the mod is loading, and the Summon pro asks for a key long after.
local BOSS_PREFIX = "bl_" .. SMODS.current_mod.prefix .. "_"

--- What the warning over a forbidden hand reads (set into SMODS.debuff_text while one is selected).
P.BANNED_TEXT = nil

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

--- True when a Stake has made this a rule of the run (items/stakes.lua sets one flag a Stake). The con
--- of the same name is then not offered: it would be asking for what is already so.
local function stake_rule(flag)
    return G.GAME and G.GAME.modifiers and G.GAME.modifiers[flag] and true or false
end

--- The state the standing rules are read from. On this deck, its own; on any deck, the one a Stake
--- made when it set one of them (items/stakes.lua: four of the Stakes are four of the cons below,
--- as a rule of the run from the start). The hooks that carry those rules ask this, and the rest of
--- the deck keeps asking `live`.
local function rules()
    local st = live()
    if st then return st end
    if G.GAME and G.GAME.modifiers and G.GAME.modifiers.celesta_standing_rules then return P.state() end
    return nil
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
    -- skip_materialize, because create_card plays start_materialize itself unless it is told not
    -- to: a burst of particles in the card's set colour, which is right for a card coming out of a
    -- pack and not for what arrives here as the reward for a choice. (Leaving the call out of
    -- this function was not enough - it is made before this returns.) The Admin Deck leaves it
    -- out of its starting cards for the same reason. A small jolt says it arrived.
    local card = SMODS.add_card {
        key = key, set = opts.set, rarity = opts.rarity, area = area,
        edition = opts.negative and "e_negative" or nil,
        stickers = opts.stickers, force_stickers = opts.stickers and true or nil,
        key_append = "celesta_purgatory",
        skip_materialize = true,
    }
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
-- would be a con that moves the whole run forward a step rather than taking something away.
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

-- ---------------------------------------------------------------- pros

add { kind = "good", key = "rerolls", repeatable = true,
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

add { kind = "good", key = "odds_double", repeatable = true,
      apply = function()
          G.GAME.probabilities.normal = (G.GAME.probabilities.normal or 1) * 2
      end }

add { kind = "good", key = "prices_half",
      apply = function(st)
          st.price_mult = (st.price_mult or 1) * P.PRICE_DOWN
          reprice()
      end }

add { kind = "good", key = "no_tatter",
      apply = function(st)
          st.no_tatter = true
          -- "No longer become tattered" is not only for the cards that are not yet: the ones already
          -- worn are mended, wherever in the run's deck they are.
          local Tattered = CelestasMod.Tattered
          if not Tattered then return end
          for _, card in ipairs(G.playing_cards or {}) do Tattered.mend(card) end
      end }

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

--- Whether a Joker of this key is owned, either half of a merge, debuffed or not.
local function owns(key)
    return #CelestasMod.find_joker(key, true) > 0
end

--- Gives the run a Tag.
local function gain_tag(key)
    G.E_MANAGER:add_event(Event {
        func = function()
            add_tag(Tag(key))
            play_sound("generic1")
            return true
        end,
    })
end

-- A quad merge, until it is unlocked here, cannot be made on this deck (merge/bind.lua asks
-- Bind.quad_unlocked). Only a quad that two of its four Jokers are owned for is offered, and
-- which one is rolled with the offer, so the card names the one that will be unlocked.
local function quad_options(st)
    local out = {}
    local Bind = CelestasMod.Bind
    for _, def in pairs((Bind and Bind.QUADS) or {}) do
        if not (st.quads and st.quads[def.key]) then
            local held = 0
            for _, member in ipairs(def.members) do
                if owns(member) then held = held + 1 end
            end
            if held >= 2 then out[#out + 1] = def end
        end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

--- A quad merge's name as the Collection prints it, or its key where there is none.
local function quad_name(key)
    local name = localize { type = "name_text", set = "Other", key = "celesta_bind_" .. tostring(key) }
    if type(name) ~= "string" or name == "ERROR" then return tostring(key) end
    return name
end

add { kind = "good", key = "unlock_quad", repeatable = true,
      available = function(st) return #quad_options(st) > 0 end,
      roll = function(st)
          local def = pick(quad_options(st), "_quad")
          return def and def.key or nil
      end,
      vars = function(arg) return { quad_name(arg) } end,
      apply = function(st, arg)
          if not arg then return end
          st.quads = st.quads or {}
          st.quads[arg] = true
      end }

add { kind = "good", key = "d6_tag", repeatable = true,
      apply = function() gain_tag("tag_d_six") end }

add { kind = "good", key = "stamp_tag", repeatable = true,
      apply = function() gain_tag("tag_celesta_stamp") end }

add { kind = "good", key = "stamp_slots",
      available = function() return ((G.GAME.celesta_stamp_slots or 1) < 2) end,
      apply = function() G.GAME.celesta_stamp_slots = 2 end }

add { kind = "good", key = "egg",
      available = function()
          return #jokers() < limit(G.jokers) and not G.GAME.banned_keys["j_celesta_blessed_phoenix_egg"]
      end,
      apply = function() give("j_celesta_blessed_phoenix_egg", G.jokers) end }

add { kind = "good", key = "reroll_vouchers",
      available = function()
          local used = G.GAME.used_vouchers or {}
          return not (used.v_reroll_surplus or used.v_reroll_glut)
      end,
      -- Redeemed the way a deck's own vouchers are (back.lua:289): marked, and applied to the run.
      apply = function()
          for _, key in ipairs({ "v_reroll_surplus", "v_reroll_glut" }) do
              G.GAME.used_vouchers[key] = true
              G.E_MANAGER:add_event(Event {
                  func = function()
                      Card.apply_to_run(nil, G.P_CENTERS[key])
                      return true
                  end,
              })
          end
      end }

add { kind = "good", key = "lost_slots",
      available = function()
          local Lost = CelestasMod.Lost
          return (Lost and Lost.any_held()) and true or false
      end,
      apply = function(st)
          st.lost_slots = true
          if CelestasMod.Lost then CelestasMod.Lost.sync_slots() end
      end }

add { kind = "good", key = "lost_shop",
      -- Only while there is a Lost Joker to be rid of: what it does to the shop is jokers/lost.lua's
      -- shop filler, which stands down for the flag.
      available = function()
          local Lost = CelestasMod.Lost
          return (Lost and Lost.any_held()) and true or false
      end,
      apply = function(st) st.lost_shop = true end }

add { kind = "good", key = "lost_sell",
      -- Only while there is a Lost Joker that cannot be sold: the wrap on Card:can_sell_card
      -- (jokers/lost.lua) lets them go for the flag.
      available = function()
          local Lost = CelestasMod.Lost
          return (Lost and Lost.any_held()) and true or false
      end,
      apply = function(st) st.lost_sell = true end }

-- The Jokers a pro changes, one pro each. Each is only offered while the Joker is owned. What it
-- changes is in the Joker's own code, which reads the flag by this name (CelestasMod.purg).
local JOKER_PROS = {
    { key = "grimmi", joker = "j_celesta_grimmi" },
    { key = "chacha", joker = "j_celesta_chacha" },
    { key = "crelly", joker = "j_celesta_crelly" },
    { key = "calamitas", joker = "j_celesta_calamitas" },
    { key = "snuffy", joker = "j_celesta_snuffy" },
    { key = "dokibird", joker = "j_celesta_dokibird" },
    { key = "lucypyre", joker = "j_celesta_lucypyre" },
    { key = "aethal", joker = "j_celesta_lordaethelstan" },
    { key = "heavenlyfather", joker = "j_celesta_heavenlyfather" },
    { key = "astrum", joker = "j_celesta_astrum_aureus" },
    { key = "seraph", joker = "j_celesta_smittenseraph" },
    { key = "isaa", joker = "j_celesta_isaa" },
}
P.JOKER_PROS = JOKER_PROS

for _, pro in ipairs(JOKER_PROS) do
    add { kind = "good", key = pro.key,
          available = function() return owns(pro.joker) end,
          apply = function(st)
              st[pro.key] = true
              if pro.key == "heavenlyfather" then
                  -- Already in the row, it has handed out its two; the two more are paid now and
                  -- written on the card, which is what it gives back when it leaves.
                  for _, found in ipairs(CelestasMod.find_joker(pro.joker, true)) do
                      local held = found.ability.celesta_hf_granted
                      if held then
                          SMODS.change_booster_limit(2)
                          found.ability.celesta_hf_granted = held + 2
                      end
                  end
              end
          end }
end

add { kind = "good", key = "true_stars",
      apply = function()
          local ranks = {}
          for rank in pairs(SMODS.Ranks or {}) do ranks[#ranks + 1] = rank end
          table.sort(ranks)
          local rank = pick(ranks, "_true_star_rank")
          if not rank then return end
          for _ = 1, 3 do
              SMODS.add_card {
                  set = "Base", suit = CelestasMod.TRUE_STARS_SUIT, rank = rank, area = G.deck,
                  key_append = "celesta_purgatory",
              }
          end
      end }

add { kind = "good", key = "spectral_shop",
      -- Nothing to change on a deck whose shop already sells them (the Ghost Deck).
      available = function() return (G.GAME.spectral_rate or 0) <= 0 end,
      apply = function(st) st.spectral_shop = true end }

add { kind = "good", key = "stamp_packs",
      apply = function(st) st.stamp_packs = true end }

add { kind = "good", key = "summon", repeatable = true,
      -- Only while there is a Mythic Joker to summon and somewhere to put the card. Its con is
      -- doubled, if it can be: see P.double.
      available = function()
          return #CelestasMod.summonable() > 0 and limit(G.consumeables) > #(G.consumeables.cards or {})
      end,
      apply = function() give("c_celesta_summon", G.consumeables) end }

add { kind = "good", key = "select_limit", repeatable = true,
      -- Both limits by the same amount, the way Shiabun does (jokers/implemented.lua): one more card
      -- to play is one more to discard, or six could be played and not discarded.
      available = function() return SMODS.change_play_limit ~= nil and SMODS.change_discard_limit ~= nil end,
      apply = function()
          SMODS.change_play_limit(1)
          SMODS.change_discard_limit(1)
      end }

--- The Planet card for a poker hand, or nil for a hand none belongs to.
local function planet_of(hand)
    for _, center in ipairs((G.P_CENTER_POOLS and G.P_CENTER_POOLS.Planet) or {}) do
        if center.config and center.config.hand_type == hand then return center.key end
    end
    return nil
end

add { kind = "good", key = "negative_planets", repeatable = true,
      available = function() return planet_of(most_played()) ~= nil end,
      apply = function()
          local key = planet_of(most_played())
          if not key then return end
          for _ = 1, 3 do give(key, G.consumeables, { negative = true }) end
      end }

add { kind = "good", key = "ante_down", repeatable = true,
      available = function() return number(G.GAME.round_resets.ante) > 1 end,
      apply = function() ease_ante(-1) end }

add { kind = "good", key = "coupon_tag", repeatable = true,
      apply = function() gain_tag("tag_coupon") end }

--- How many modifiers must be on the list, pros and cons together, before the Purge is offered.
P.PURGE_AT = 16

add { kind = "good", key = "purge", repeatable = true,
      available = function(st)
          return #P.in_effect(st, "good") + #P.in_effect(st, "bad") >= P.PURGE_AT
      end,
      apply = function(st) P.purge(st) end }

add { kind = "good", key = "blind_size",
      apply = function()
          local params = G.GAME.starting_params
          params.ante_scaling = (params.ante_scaling or 1) * P.BLIND_DOWN
      end }

-- ---------------------------------------------------------------- cons

add { kind = "bad", key = "rerolls", repeatable = true,
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
      available = function() return not stake_rule("celesta_abyssal") end,
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
      -- The cash-out about to be counted pays nothing at all: the Blind's reward, the money for
      -- Hands left over, interest, what Jokers and Tags pay. See "The cash-out" below.
      apply = function(st) st.no_pay_round = true end }

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

add { kind = "bad", key = "odds_half", repeatable = true,
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

add { kind = "bad", key = "least_hand",
      -- Only while there is a least-played hand to name: with every hand played the same number
      -- of times there is none, and the con would forbid nothing.
      available = function() return next(P.banned_hands(true)) ~= nil end,
      apply = function(st) st.no_least_hand = true end }

add { kind = "bad", key = "reroll_two",
      apply = function(st) st.reroll_two = true end }

add { kind = "bad", key = "no_planets",
      available = function() return not stake_rule("celesta_titanium") end,
      apply = function(st) st.no_planets = true end }

add { kind = "bad", key = "no_tarots",
      available = function() return not stake_rule("celesta_terra") end,
      apply = function(st) st.no_tarots = true end }

add { kind = "bad", key = "destroy_held",
      apply = function(st) st.destroy_held = true end }

-- ---------------------------------------------------------------- the Boss Blinds
--
-- Nine of the cons make one Boss Blind of this mod worse for the rest of the run. Each is a flag
-- in `buffs`, and the Blind itself asks for it (blinds/blinds.lua, CelestasMod.boss_buffed). A
-- pro takes a random one off again, and only offers to when there is one to take.

local BUFFS = { "clover", "flower", "wyrm", "robot", "brick", "goat", "frog", "horn", "gem", "spore", "cross", "shield" }
P.BUFFS = BUFFS

for _, name in ipairs(BUFFS) do
    add { kind = "bad", key = "buff_" .. name,
          apply = function(st) st.buffs[name] = true end }
end

add { kind = "bad", key = "lost_soul",
      -- Needs a place to sit: it takes a consumable slot for as long as it is kept.
      available = function()
          return limit(G.consumeables) > #(G.consumeables.cards or {})
              and not G.GAME.banned_keys["c_celesta_lost_soul"]
      end,
      apply = function()
          local card = give("c_celesta_lost_soul", G.consumeables)
          if card then card.ability.celesta_unsellable = true end
      end }

-- "Cannot be sold", as jokers/lost.lua asks it of a Lost Joker: wrapped, not made Eternal, so it can still
-- be used.
local celesta_purg_can_sell_ref = Card.can_sell_card
function Card:can_sell_card(context)
    if self.ability and self.ability.celesta_unsellable then return false end
    return celesta_purg_can_sell_ref(self, context)
end

--- The Ante a con jumps the run to.
P.JUMP_ANTE = 12
--- The Ante the other one moves the end of the run to.
P.LONG_ANTE = 16

add { kind = "bad", key = "ante_jump",
      available = function() return number(G.GAME.round_resets.ante) < P.JUMP_ANTE end,
      apply = function() ease_ante(P.JUMP_ANTE - number(G.GAME.round_resets.ante)) end }

add { kind = "bad", key = "ante_end",
      available = function() return number(G.GAME.win_ante or P.WIN_ANTE) < P.LONG_ANTE end,
      apply = function() G.GAME.win_ante = P.LONG_ANTE end }

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
-- Taking one back
--------------------------------------------------------------------------------
--
-- The Purge removes the modifiers on the Modifiers list: every one taken and not yet removed (and, for a
-- Boss Blind upgrade, not dropped). Taking one back puts back what its own `apply` changed, by the same
-- amount, and that is this table: a modifier has an `undo` when what it did stays (a slot, a rule, a rate).
-- One with none was done once and is over (money, a card, a level, a tag): it leaves the list, and what it
-- did is not undone.

--- The pair being chosen right now, which the Purge must leave alone: it is on the record before either
--- half has happened.
local choosing = nil

--- Takes `by` off the Hands each round, never below the one a round needs.
local function hands_change(by)
    G.GAME.round_resets.hands = math.max(1, G.GAME.round_resets.hands + by)
end

local function discards_change(by)
    G.GAME.round_resets.discards = math.max(0, G.GAME.round_resets.discards + by)
end

local function selection_change(by)
    if not (SMODS.change_play_limit and SMODS.change_discard_limit) then return end
    SMODS.change_play_limit(by)
    SMODS.change_discard_limit(by)
    if by < 0 and G.hand and G.hand.unhighlight_all then G.hand:unhighlight_all() end
end

local function reprice_by(factor)
    return function(st)
        st.price_mult = (st.price_mult or 1) / factor
        reprice()
    end
end

local UNDO = {
    ["good:rerolls"] = function(st) st.reroll_bonus = (st.reroll_bonus or 0) - 2 end,
    ["good:debt"] = function() G.GAME.bankrupt_at = (G.GAME.bankrupt_at or 0) + 10 end,
    ["good:income"] = function(st) st.income = math.max(0, (st.income or 0) - 5) end,
    ["good:hand"] = function() hands_change(-1) end,
    ["good:discard"] = function() discards_change(-1) end,
    ["good:joker_slot"] = function() G.jokers:change_size(-1) end,
    ["good:consumable_slot"] = function() G.consumeables:change_size(-1) end,
    ["good:hand_size"] = function() G.hand:change_size(-2) end,
    ["good:select_limit"] = function() selection_change(-1) end,
    ["good:skip_boss"] = function(st) st.disable_boss = math.max(0, (st.disable_boss or 0) - 1) end,
    ["good:legendary_shop"] = function(st) st.legendary_shop = nil end,
    ["good:odds_double"] = function()
        G.GAME.probabilities.normal = (G.GAME.probabilities.normal or 1) / 2
    end,
    ["good:prices_half"] = reprice_by(P.PRICE_DOWN),
    ["good:no_tatter"] = function(st) st.no_tatter = nil end,
    ["good:shop_slot"] = function() change_shop_size(-1) end,
    ["good:booster_slot"] = function() SMODS.change_booster_limit(-1) end,
    ["good:voucher_slot"] = function() SMODS.change_voucher_limit(-1) end,
    ["good:tarot_double"] = function()
        G.GAME.celesta_tarot_scale = (G.GAME.celesta_tarot_scale or 1) / 2
        if CelestasMod.haruka_refresh then CelestasMod.haruka_refresh(nil, false) end
    end,
    ["good:stamp_slots"] = function() G.GAME.celesta_stamp_slots = 1 end,
    ["good:stamp_packs"] = function(st) st.stamp_packs = nil end,
    ["good:spectral_shop"] = function(st) st.spectral_shop = nil end,
    ["good:lost_shop"] = function(st) st.lost_shop = nil end,
    ["good:lost_sell"] = function(st) st.lost_sell = nil end,
    ["good:lost_slots"] = function(st)
        st.lost_slots = nil
        if CelestasMod.Lost then CelestasMod.Lost.sync_slots() end
    end,
    ["good:unlock_quad"] = function(st, arg)
        if st.quads and arg then st.quads[arg] = nil end
    end,
    ["good:reroll_vouchers"] = function()
        for _, key in ipairs({ "v_reroll_surplus", "v_reroll_glut" }) do
            if G.GAME.used_vouchers[key] then
                G.GAME.used_vouchers[key] = nil
                VOUCHER_UNDO[key]()
            end
        end
    end,

    ["bad:rerolls"] = function(st) st.reroll_bonus = (st.reroll_bonus or 0) + 1 end,
    ["bad:hand"] = function() hands_change(1) end,
    ["bad:discard"] = function() discards_change(1) end,
    ["bad:joker_slot"] = function() G.jokers:change_size(1) end,
    ["bad:consumable_slot"] = function() G.consumeables:change_size(1) end,
    ["bad:hand_size"] = function() G.hand:change_size(1) end,
    ["bad:boss_big"] = function(st) st.boss_for_big = nil end,
    ["good:blind_size"] = function()
        local params = G.GAME.starting_params
        params.ante_scaling = (params.ante_scaling or 1) / P.BLIND_DOWN
    end,
    ["bad:blind_size"] = function()
        local params = G.GAME.starting_params
        params.ante_scaling = (params.ante_scaling or 1) / P.BLIND_UP
    end,
    ["bad:boss_repeat"] = function(st) st.boss_repeat = nil end,
    ["bad:prices_up"] = reprice_by(P.PRICE_UP),
    ["bad:shop_slot"] = function() change_shop_size(1) end,
    ["bad:booster_slot"] = function() SMODS.change_booster_limit(1) end,
    ["bad:odds_half"] = function()
        G.GAME.probabilities.normal = (G.GAME.probabilities.normal or 1) * 2
    end,
    ["bad:tatter_fast"] = function(st) st.fast_tatter = nil end,
    ["bad:super_boss"] = function(st) st.super_boss = nil end,
    ["bad:least_hand"] = function(st) st.no_least_hand = nil end,
    ["bad:reroll_two"] = function(st) st.reroll_two = nil end,
    ["bad:no_planets"] = function(st) st.no_planets = nil end,
    ["bad:no_tarots"] = function(st) st.no_tarots = nil end,
    ["bad:destroy_held"] = function(st) st.destroy_held = nil end,
    ["bad:ante_end"] = function() G.GAME.win_ante = P.WIN_ANTE end,
}

for _, pro in ipairs(JOKER_PROS) do
    UNDO["good:" .. pro.key] = function(st)
        st[pro.key] = nil
        if pro.key == "heavenlyfather" then
            -- ...and the two boosters it was handed on top, which are written on the card.
            for _, found in ipairs(CelestasMod.find_joker(pro.joker, true)) do
                local held = found.ability.celesta_hf_granted
                if held and held >= 2 then
                    SMODS.change_booster_limit(-2)
                    found.ability.celesta_hf_granted = held - 2
                end
            end
        end
    end
end

for _, name in ipairs(BUFFS) do
    UNDO["bad:buff_" .. name] = function(st) st.buffs[name] = nil end
end

--- Whether a Boss Blind upgrade is still on: one a pro has dropped is no longer in effect.
local STANDING = {}
for _, name in ipairs(BUFFS) do
    STANDING["bad:buff_" .. name] = function(st) return st.buffs[name] and true or false end
end

for _, entry in ipairs(P.MODIFIERS) do
    entry.undo = UNDO[entry.id]
    entry.standing = STANDING[entry.id]
end

--- The modifiers of `kind` taken and not yet removed - the ones the Modifiers list shows - as
--- { record, kind, entry }, in the order taken. `except` is a record to leave out.
function P.in_effect(st, kind, except)
    local out = {}
    for _, record in ipairs(st.history or {}) do
        local entry = record[kind] and P.find(kind, record[kind])
        if entry and record ~= except and not record[kind .. "_removed"]
            and (not entry.standing or entry.standing(st)) then
            out[#out + 1] = { record = record, kind = kind, entry = entry }
        end
    end
    return out
end

--- Takes one modifier back: it leaves the list and, if it has an undo, what it changed is put back. One
--- that could only be chosen once may be offered again.
function P.take_back(st, item)
    local record, entry = item.record, item.entry
    record[item.kind .. "_removed"] = true
    -- A con a Summon doubled was applied twice.
    local times = (item.kind == "bad" and record.twice) and 2 or 1
    if not entry.undo then times = 0 end
    for _ = 1, times do
        local ok, err = pcall(entry.undo, st, record[item.kind .. "_arg"])
        if not ok then
            CelestasMod.warn_once("purgatory_undo_" .. entry.id,
                ("Purgatory could not take back %s: %s"):format(entry.id, tostring(err)))
        end
    end
    st.taken[entry.id] = math.max(0, (st.taken[entry.id] or 0) - 1)
end

--- The Purge: half of the pros on the list (rounded as a cull is, at random) and every con.
function P.purge(st)
    local pros = P.in_effect(st, "good", choosing)
    local cons = P.in_effect(st, "bad", choosing)
    for _ = 1, math.floor(#pros / 2 + 0.5) do
        local item, index = pick(pros, "_purge")
        if not item then break end
        table.remove(pros, index)
        P.take_back(st, item)
    end
    for _, item in ipairs(cons) do P.take_back(st, item) end
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

--- Whether one modifier of an offer is hidden: 1 in P.HIDDEN_ODDS, and that exactly. Nothing that changes the
--- odds of a listed chance (the Hedron Stake's halving, Oops! All 6s, a Joker that doubles a numerator)
--- is asked, the way the Soul Stake's own roll is not: the Celestial Stake's chance is its own.
function P.hidden_roll(seed)
    return SMODS.pseudorandom_probability({}, SEED .. seed, 1, P.HIDDEN_ODDS, "celesta_hidden", true) and true or nil
end

--- Three offers, each a pro and a con, no pro and no con twice. Fewer when the pools run
--- short, and none when either is empty - in which case there is nothing to choose between.
function P.roll_offers(st)
    local goods, bads = offerable_of("good", st), offerable_of("bad", st)
    local hides = stake_rule("celesta_celestial")
    local offers = {}
    while #offers < P.OFFERS and #goods > 0 and #bads > 0 do
        local good, gi = pick(goods, "_offer_good")
        local bad, bi = pick(bads, "_offer_bad")
        table.remove(goods, gi)
        table.remove(bads, bi)
        offers[#offers + 1] = {
            good = good.key,
            bad = bad.key,
            -- On the Celestial Stake each one may be hidden from the choice, and stays so for as long as the
            -- offer does: a reroll is a new offer, and a reload is not.
            good_hidden = hides and P.hidden_roll("_hide_good") or nil,
            bad_hidden = hides and P.hidden_roll("_hide_bad") or nil,
            -- What each one rolled with the offer (the quad merge a pro unlocks, the suit a con
            -- removes), kept so the text names it and the choice applies that very thing.
            good_arg = good.roll and good.roll(st) or nil,
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

--- The cons a second helping would not change: a standing rule is either on or off, and what is
--- idempotent is already as bad as it gets.
P.NOT_DOUBLED = {
    no_pay = true, boss_big = true, boss_repeat = true, tatter_fast = true, super_boss = true,
    least_hand = true, reroll_two = true, no_planets = true, no_tarots = true, destroy_held = true,
    ante_jump = true, ante_end = true,
    lose_editions = true, lose_consumables = true,
}

--- The Summon pro's price: the con that came with it, twice - when twice means anything, and
--- while there is anything left for the second to take (every con that has a limit asks again
--- whether it still may, as if it were being offered). A con that upgrades a Boss Blind cannot be
--- doubled and is made certain instead: that Blind is the next Boss Blind there is.
function P.double(st, bad, arg)
    local name = bad.key:match("^buff_(.+)$")
    if name then
        st.next_boss = BOSS_PREFIX .. name
        return
    end
    if P.NOT_DOUBLED[bad.key] then return end
    if bad.available and not bad.available(st) then return end
    local ok, err = pcall(bad.apply, st, arg)
    if not ok then
        CelestasMod.warn_once("purgatory_double_" .. bad.id,
            ("Purgatory could not double %s: %s"):format(bad.id, tostring(err)))
    end
    return ok
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
    --
    -- With another still owed, the box stays owed, the rerolls are not given back (the second choice
    -- is made with what the first left of them), and a fresh three are dealt once this one is done.
    local more = (st.pick_left or 1) > 1
    if more then
        st.pick_left = st.pick_left - 1
        st.offers = nil
    else
        st.offers, st.owed, st.rerolls_used = nil, false, 0
        st.pick_left, st.pick_total = nil, nil
    end
    st.taken[good.id] = (st.taken[good.id] or 0) + 1
    st.taken[bad.id] = (st.taken[bad.id] or 0) + 1
    -- ...and the pair itself, in order, with what each half was rolled with and whether the con was
    -- doubled: `taken` counts, and a list of what is in effect has to say which suit and which quad.
    st.history = st.history or {}
    local record = {
        good = good.key, bad = bad.key, good_arg = offer.good_arg, bad_arg = offer.bad_arg,
        doubled = P.doubles_its_con(offer) or nil,
    }
    st.history[#st.history + 1] = record
    choosing = record
    if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end

    -- The Summon pro after its con rather than before: a con that empties the consumable row
    -- must not take the card it came with.
    local summoning = good.key == "summon"
    for _, entry in ipairs(summoning and { bad, good } or { good, bad }) do
        local ok, err = pcall(entry.apply, st, entry == bad and offer.bad_arg or offer.good_arg)
        if not ok then
            CelestasMod.warn_once("purgatory_" .. entry.id,
                ("Purgatory could not apply %s: %s"):format(entry.id, tostring(err)))
        end
    end
    if summoning then record.twice = P.double(st, bad, offer.bad_arg) or nil end
    choosing = nil
    if more then P.deal_next(st) end
    return true
end

--- Deals the next three of two owed. Dealt after the first choice has been made, so what it took
--- is no longer offered; and when there is nothing left to choose between the debt is cancelled, as
--- an empty box is when the first is dealt.
function P.deal_next(st)
    st.offers = P.roll_offers(st)
    if #st.offers == 0 then
        st.offers, st.owed, st.rerolls_used = nil, false, 0
        st.pick_left, st.pick_total = nil, nil
    end
end

--- Throws the three back and deals three more, if there is a reroll left.
function P.reroll()
    local st = P.state()
    if not (st and st.owed and P.rerolls_left(st) > 0) then return false end
    st.rerolls_used = (st.rerolls_used or 0) + 1
    st.offers = st.shop and P.roll_shop(st) or P.roll_offers(st)
    return true
end

--- Modifiers on the table in the Ichor Stake's shop.
P.SHOP_SIZE = 6

--- The pros the shop puts out: six that could be offered now, no two the same, and no con with any of them.
function P.roll_shop(st)
    local pool = offerable_of("good", st)
    local hides = stake_rule("celesta_celestial")
    local offers = {}
    while #offers < P.SHOP_SIZE and #pool > 0 do
        local entry, index = pick(pool, "_shop")
        table.remove(pool, index)
        offers[#offers + 1] = {
            good = entry.key,
            good_arg = entry.roll and entry.roll(st) or nil,
            price = P.price_of("good", entry.key),
            -- Hidden the way an offer's are on the Celestial Stake: the price is shown, the pro is not.
            good_hidden = hides and P.hidden_roll("_hide_shop") or nil,
        }
    end
    return offers
end

--- Whether the run can pay `price`, as the shop asks it: what is left may not go below the debt limit.
local function can_pay(price)
    return dollars() - price >= number(G.GAME.bankrupt_at)
end

--- Whether the pro at `index` in the shop can be bought now.
function P.can_buy(index)
    local st = P.state()
    local offer = st and st.shop and st.offers and st.offers[index]
    return offer ~= nil and not offer.sold and can_pay(offer.price)
end

--- Buys the pro at `index`: it is paid for and takes effect with no con, and the place is sold out.
function P.buy(index)
    if not P.can_buy(index) then return false end
    local st = P.state()
    local offer = st.offers[index]
    local pro = P.find("good", offer.good)
    if not pro then return false end

    offer.sold = true
    ease_dollars(-offer.price)
    st.taken[pro.id] = (st.taken[pro.id] or 0) + 1
    -- On the list like any other, and with no con beside it.
    st.history = st.history or {}
    local record = { good = pro.key, good_arg = offer.good_arg, bought = offer.price }
    st.history[#st.history + 1] = record
    choosing = record
    local ok, err = pcall(pro.apply, st, offer.good_arg)
    choosing = nil
    if not ok then
        CelestasMod.warn_once("purgatory_" .. pro.id,
            ("Purgatory could not apply %s: %s"):format(pro.id, tostring(err)))
    end
    return true
end

--- Leaves the shop, which is the way out of it: nothing has to be bought.
function P.leave_shop()
    local st = P.state()
    if not (st and st.shop) then return false end
    st.offers, st.owed, st.shop, st.rerolls_used = nil, false, nil, 0
    if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
    return true
end

--------------------------------------------------------------------------------
-- The prompt
--------------------------------------------------------------------------------

--- Whether this offer's con comes doubled: the Summon pro is paid for with it twice (P.double).
function P.doubles_its_con(offer)
    return offer ~= nil and offer.good == "summon"
end

--- The localization key a modifier's text is under. A con that is being doubled has a second
--- entry, `_double`, that says what twice is - "-2 Hands", not "-1 Hand" with a note. One that
--- cannot be doubled has none and reads as it always does, which is what happens to it.
local function text_key(kind, key, doubled)
    local base = "celesta_purg_" .. kind .. "_" .. key
    if not (doubled and kind == "bad") then return base end
    local other = G.localization and G.localization.descriptions
        and G.localization.descriptions.Other
    local twice = base .. "_double"
    return (other and other[twice]) and twice or base
end

--- The numbers a modifier's text prints. A modifier that names something rolled with it (a suit, a
--- quad) cannot be asked without it, and a list of what was taken in a run begun before that was
--- kept has no roll to give: the text is then built without, rather than the screen not at all.
local function vars_of(entry, arg)
    if not (entry and entry.vars) then return {} end
    local ok, vars = pcall(entry.vars, arg)
    return ok and vars or {}
end

--- The lines of one modifier's text, each as the parts a row is made of.
local function text_lines(kind, key, arg, doubled)
    local entry = P.find(kind, key)
    local lines = {}
    local ok = pcall(localize, {
        type = "descriptions", set = "Other",
        key = text_key(kind, key, doubled),
        vars = vars_of(entry, arg),
        nodes = lines,
    })
    return ok and lines or {}
end
P.text_lines = text_lines

--- Lines of text, in the white box a card's own text sits in.
local function box_of(lines)
    local rows = {}
    for _, line in ipairs(lines) do
        rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm" }, nodes = line }
    end
    return { n = G.UIT.R, config = { align = "cm", padding = 0.06, r = 0.1, minw = 3.3, minh = 1.0,
                                     colour = G.C.WHITE },
             nodes = { { n = G.UIT.C, config = { align = "cm" }, nodes = rows } } }
end

--- One modifier's text, in that box.
local function text_box(kind, key, arg, doubled)
    return box_of(text_lines(kind, key, arg, doubled))
end

--- The box of a modifier that is hidden from the choice.
local function hidden_box()
    local lines = {}
    local ok = pcall(localize, {
        type = "descriptions", set = "Other", key = "celesta_purg_hidden", nodes = lines,
    })
    return box_of(ok and lines or {})
end

local function label(text, colour)
    return { n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = {
        { n = G.UIT.T, config = { text = text, scale = 0.38, colour = colour, shadow = true } } } }
end

--------------------------------------------------------------------------------
-- Categories, and the chip beside each modifier
--------------------------------------------------------------------------------
--
-- Every modifier belongs to one category, and the category's icon stands on either side of it in the offer.
-- The icons are Stakes' chips for now, and a name that is no Stake's (the ones not drawn yet) is a blank: which
-- icon goes with which category is only this table.

P.CATEGORIES = {
    { title = "Money", icon = "ichor",
      good = { "debt", "income", "money_15", "money_30", "prices_half" },
      bad = { "lose_20", "broke", "no_pay", "prices_up", "reroll_two" } },
    { title = "Hands", icon = "soul",
      good = { "hand" }, bad = { "hand", "least_hand" } },
    { title = "Hand size and card selection limit", icon = "brass",
      good = { "hand_size", "select_limit" }, bad = { "hand_size" } },
    { title = "Discards", icon = "crimson",
      good = { "discard" }, bad = { "discard" } },
    { title = "Poker hand levels", icon = "lavish",
      good = { "level_all", "level_top" }, bad = { "level_all", "level_top" } },
    { title = "Jokers", icon = "lead",
      good = { "joker_slot", "rare_joker", "negative_joker", "unsticker", "lost_slots", "lost_shop", "lost_sell" },
      bad = { "joker_slot", "destroy_joker", "lose_negative", "sticker", "eternal_perishable", "lose_editions" } },
    { title = "Specific Jokers", icon = "abyssal",
      -- the twelve that change one Joker each (JOKER_PROS)
      good = { "grimmi", "chacha", "crelly", "calamitas", "snuffy", "dokibird", "lucypyre", "aethal",
               "heavenlyfather", "astrum", "seraph", "isaa" },
      bad = { "obelisk" } },
    { title = "Blessed Phoenix Egg", icon = "burning", good = { "egg" }, bad = {} },
    { title = "Spectral cards", icon = "spectral",
      good = { "soul", "spectral_shop", "bind_swap" }, bad = { "lost_soul" } },
    { title = "Tarot cards", icon = "tarot", good = { "tarot_double" }, bad = { "no_tarots" } },
    { title = "Summon", icon = "summon", good = { "summon" }, bad = {} },
    { title = "Consumables", icon = "magical",
      good = { "consumable_slot" }, bad = { "consumable_slot", "lose_consumables" } },
    { title = "Planet cards", icon = "heathen", good = { "negative_planets" }, bad = { "no_planets" } },
    { title = "Shop and vouchers", icon = "herbium",
      good = { "shop_slot", "booster_slot", "voucher_slot", "reroll_vouchers", "legendary_shop" },
      bad = { "shop_slot", "booster_slot", "lose_voucher" } },
    { title = "Stamps and tags", icon = "rose",
      good = { "d6_tag", "stamp_tag", "stamp_slots", "stamp_packs", "coupon_tag" }, bad = {} },
    { title = "True Stars", icon = "hedron", good = { "true_stars" }, bad = {} },
    { title = "Tattered", icon = "sandstone", good = { "no_tatter" }, bad = { "tatter_fast" } },
    { title = "Card destruction", icon = "iron",
      good = {}, bad = { "cull_quarter", "cull_faces", "cull_suit", "destroy_held" } },
    { title = "Boss Blinds", icon = "glimmer",
      good = { "skip_boss", "blind_size" }, bad = { "boss_big", "blind_size", "boss_repeat", "super_boss" } },
    { title = "Specific Boss Blinds", icon = "terra",
      good = { "drop_buff" },
      bad = { "buff_clover", "buff_flower", "buff_wyrm", "buff_robot", "buff_brick", "buff_goat", "buff_frog",
              "buff_horn", "buff_gem", "buff_spore", "buff_cross", "buff_shield" } },
    { title = "Odds", icon = "lucky", good = { "odds_double" }, bad = { "odds_half" } },
    { title = "Modifier rerolls", icon = "eryl", good = { "rerolls" }, bad = { "rerolls" } },
    { title = "Antes", icon = "azure", good = { "ante_down" }, bad = { "ante_jump", "ante_end" } },
    { title = "Quad merges", icon = "titanium", good = { "unlock_quad" }, bad = {} },
    { title = "Purging", icon = "celestial", good = { "purge" }, bad = {} },
}

local CATEGORY_OF = {}
for _, category in ipairs(P.CATEGORIES) do
    for _, kind in ipairs({ "good", "bad" }) do
        for _, key in ipairs(category[kind]) do CATEGORY_OF[kind .. ":" .. key] = category end
    end
end

--- The category a modifier is in, or nil for one that has none.
function P.category_of(kind, key)
    return CATEGORY_OF[kind .. ":" .. tostring(key)]
end

--- The atlas the Stakes' chips are on, named once: the prefix is only known while the mod loads.
local CHIP_ATLAS = SMODS.current_mod.prefix .. "_stake_chips"
--- How big a chip is drawn beside a modifier.
local CHIP_SIZE = 0.55

--- The chip beside a modifier, as a UI node. Where it cannot be drawn (no category, no sheet) an empty box of
--- the same size stands in for it, so the text does not move.
local function chip_node(kind, key)
    local category = P.category_of(kind, key)
    local at = category and CelestasMod.stake_chip_pos and CelestasMod.stake_chip_pos(category.icon)
    local sheet = G.ASSET_ATLAS and G.ASSET_ATLAS[CHIP_ATLAS]
    if not (at and sheet) then return { n = G.UIT.B, config = { w = CHIP_SIZE, h = CHIP_SIZE } } end
    return { n = G.UIT.O, config = { object = Sprite(0, 0, CHIP_SIZE, CHIP_SIZE, sheet, at) } }
end

--- A label and its text box, a chip standing on either side of them.
local function flanked(kind, key, heading, box)
    return { n = G.UIT.R, config = { align = "cm" }, nodes = {
        { n = G.UIT.C, config = { align = "cm", padding = 0.04 }, nodes = { chip_node(kind, key) } },
        { n = G.UIT.C, config = { align = "cm" }, nodes = { heading, box } },
        { n = G.UIT.C, config = { align = "cm", padding = 0.04 }, nodes = { chip_node(kind, key) } },
    } }
end

--- The modifiers that are rare, as `kind:key`.
P.RARE = {
    ["good:egg"] = true,
    ["good:soul"] = true,
    ["good:summon"] = true,
    ["good:negative_planets"] = true,
    ["good:legendary_shop"] = true,
    ["good:stamp_slots"] = true,
    ["bad:least_hand"] = true,
    ["bad:destroy_joker"] = true,
    ["bad:eternal_perishable"] = true,
    ["bad:lost_soul"] = true,
    ["bad:destroy_held"] = true,
    ["bad:boss_big"] = true,
    ["bad:ante_end"] = true,
}

--- The modifiers that are uncommon, as `kind:key`. Every one in neither this nor P.RARE is common.
P.UNCOMMON = {
    ["good:income"] = true,
    ["good:prices_half"] = true,
    ["good:level_all"] = true,
    ["good:level_top"] = true,
    ["good:rare_joker"] = true,
    ["good:negative_joker"] = true,
    ["good:lost_slots"] = true,
    ["good:lost_shop"] = true,
    ["good:tarot_double"] = true,
    ["good:reroll_vouchers"] = true,
    ["good:stamp_packs"] = true,
    ["good:no_tatter"] = true,
    ["good:odds_double"] = true,
    ["good:purge"] = true,
    ["bad:prices_up"] = true,
    ["bad:reroll_two"] = true,
    ["bad:level_top"] = true,
    ["bad:lose_editions"] = true,
    ["bad:no_tarots"] = true,
    ["bad:no_planets"] = true,
    ["bad:tatter_fast"] = true,
    ["bad:cull_suit"] = true,
    ["bad:boss_repeat"] = true,
    ["bad:super_boss"] = true,
    ["bad:ante_jump"] = true,
}

--- What a pro costs in the Ichor Stake's shop, by how common it is.
P.PRICES = { common = 10, uncommon = 25, rare = 50 }

--- How common a modifier is: "common", "uncommon" or "rare".
function P.rarity(kind, key)
    local id = kind .. ":" .. tostring(key)
    if P.RARE[id] then return "rare" end
    if P.UNCOMMON[id] then return "uncommon" end
    return "common"
end

--- What a modifier costs in the shop.
function P.price_of(kind, key)
    return P.PRICES[P.rarity(kind, key)]
end

--- Whether a modifier is a rare one.
function P.is_rare(kind, key)
    return P.RARE[kind .. ":" .. tostring(key)] and true or false
end

--- The name a modifier is shown under in an offer, in place of the plain "Pro" or "Con" - or `fallback`
--- where it has none, and where it is hidden: a name would say what the `???` is hiding.
function P.name_of(kind, key, fallback, hidden)
    if hidden then return fallback end
    local name = localize { type = "name_text", set = "Other", key = "celesta_purg_" .. kind .. "_" .. tostring(key) }
    if type(name) ~= "string" or name == "ERROR" then return fallback end
    return name
end

--- One of the three: the pro over the con, all of it one button.
local function offer_panel(index, offer)
    return { n = G.UIT.C,
             config = { align = "cm", padding = 0.1, r = 0.12, hover = true, shadow = true,
                        colour = G.C.GREY, emboss = 0.05, minw = 3.6,
                        button = "celesta_purg_pick", ref_table = { index = index },
                        focus_args = { nav = "wide" } },
             nodes = {
                 flanked("good", offer.good,
                         label(P.name_of("good", offer.good, localize("celesta_purg_good"), offer.good_hidden), G.C.GREEN),
                         offer.good_hidden and hidden_box() or text_box("good", offer.good, offer.good_arg)),
                 flanked("bad", offer.bad,
                         label(P.name_of("bad", offer.bad, localize("celesta_purg_bad"), offer.bad_hidden), G.C.RED),
                         offer.bad_hidden and hidden_box()
                             or text_box("bad", offer.bad, offer.bad_arg, P.doubles_its_con(offer))),
             } }
end

--- One of the six in the shop: the pro and its price, all of it one button.
local function shop_panel(index, offer)
    local sold = offer.sold
    local price = { n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = {
        { n = G.UIT.T, config = { text = sold and localize("celesta_purg_sold") or ("$" .. tostring(offer.price)),
                                  scale = 0.42, colour = sold and G.C.UI.TEXT_INACTIVE or G.C.MONEY, shadow = true } } } }
    return { n = G.UIT.C,
             config = { align = "cm", padding = 0.08, r = 0.12, hover = true, shadow = true,
                        colour = G.C.GREY, emboss = 0.05, minw = 3.5,
                        button = (not sold) and "celesta_purg_buy" or nil, func = "celesta_purg_can_buy",
                        ref_table = { index = index }, focus_args = { nav = "wide" } },
             nodes = {
                 flanked("good", offer.good,
                         label(P.name_of("good", offer.good, localize("celesta_purg_good"), offer.good_hidden), G.C.GREEN),
                         offer.good_hidden and hidden_box() or text_box("good", offer.good, offer.good_arg)),
                 price,
             } }
end

--- The run's money as the box prints it, with the sign.
function P.money_text()
    local dollars = G.GAME and G.GAME.dollars or 0
    return "$" .. (number_format and number_format(dollars) or tostring(number(dollars)))
end

--- The Ichor Stake's shop: the six, three to a row, the run's money, and the way to reroll them and to leave.
function P.shop_definition(st)
    local rows = {}
    for first = 1, #(st.offers or {}), 3 do
        local last = math.min(first + 2, #st.offers)
        local row = {}
        for i = first, last do
            row[#row + 1] = shop_panel(i, st.offers[i])
            if i < last then row[#row + 1] = { n = G.UIT.C, config = { minw = 0.15 } } end
        end
        rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.08 }, nodes = row }
    end

    local left = P.rerolls_left(st)
    local contents = {
        { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            { n = G.UIT.T, config = { text = localize("celesta_purg_title"), scale = 0.7,
                                      colour = G.C.ORANGE, shadow = true } } } },
        { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            { n = G.UIT.T, config = { text = localize("celesta_purg_buy_prompt"), scale = 0.4,
                                      colour = G.C.UI.TEXT_LIGHT } } } },
    }
    for _, row in ipairs(rows) do contents[#contents + 1] = row end
    -- The run's money sits in the bottom left corner of the box, where the HUD's own is covered by it; an
    -- empty column of the same width on the right keeps the two buttons in the middle.
    local money = { n = G.UIT.C, config = { align = "bl", minw = 3.0 }, nodes = {
        { n = G.UIT.R, config = { align = "cm", padding = 0.08, r = 0.1, colour = G.C.BLACK, emboss = 0.05 }, nodes = {
            { n = G.UIT.T, config = { text = P.money_text(), scale = 0.5, colour = G.C.MONEY, shadow = true } } } } } }
    contents[#contents + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
        money,
        { n = G.UIT.C, config = { align = "cm", padding = 0.05 }, nodes = {
            UIBox_button {
                label = { localize("celesta_purg_reroll") .. " (" .. left .. ")" },
                button = "celesta_purg_reroll",
                func = "celesta_purg_can_reroll",
                colour = left > 0 and G.C.GREEN or G.C.UI.BACKGROUND_INACTIVE,
                minw = 3.6, minh = 0.7, scale = 0.45,
            } } },
        { n = G.UIT.C, config = { align = "cm", padding = 0.05 }, nodes = {
            UIBox_button {
                label = { localize("celesta_purg_done") },
                button = "celesta_purg_done",
                colour = G.C.ORANGE,
                minw = 3.6, minh = 0.7, scale = 0.45,
            } } },
        { n = G.UIT.C, config = { minw = 3.0 } },
    } }
    return create_UIBox_generic_options { no_back = true, no_esc = true, minw = 12, contents = contents }
end

--- What the box asks: to choose a modifier, and which of two it is when two are owed.
local function prompt_text(st)
    local text = localize("celesta_purg_prompt")
    local total = st.pick_total or 1
    if total > 1 then
        text = text .. " (" .. (total - (st.pick_left or total) + 1) .. "/" .. total .. ")"
    end
    return text
end

--- The whole screen. Built from the state, so a reroll is a fresh call and a reload is too.
function P.definition()
    local st = P.state()
    if st.shop then return P.shop_definition(st) end
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
            { n = G.UIT.T, config = { text = prompt_text(st), scale = 0.4,
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

G.FUNCS.celesta_purg_buy = function(e)
    local ref = e and e.config and e.config.ref_table
    if ref and ref.index and P.buy(ref.index) then
        -- Flat, for the reason a reroll is: the same screen with one place sold.
        local jiggle = G.ROOM and G.ROOM.jiggle
        show(true)
        if G.ROOM and jiggle then G.ROOM.jiggle = jiggle end
    end
end

--- A place that cannot be bought (sold out, or more than the run has) is greyed and does nothing.
G.FUNCS.celesta_purg_can_buy = function(e)
    local ref = e and e.config and e.config.ref_table
    if ref and ref.index and P.can_buy(ref.index) then
        e.config.colour = G.C.GREY
        e.config.button = "celesta_purg_buy"
    else
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    end
end

G.FUNCS.celesta_purg_done = function() P.leave_shop() end

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
        st.offers = st.shop and P.roll_shop(st) or P.roll_offers(st)
        -- Nothing to choose between: the run goes on rather than waiting on an empty box.
        if #st.offers == 0 then
            st.offers, st.owed, st.shop = nil, false, nil
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
-- What has been taken
--------------------------------------------------------------------------------
--
-- A button in the run's pause menu opens a list of every modifier taken so far, the pros on the
-- left and the cons on the right, as many to a page as fit. Every one that was taken is listed,
-- the ones that happened once as well as the ones that stay: a list that left out "$15" would also
-- leave out a choice, and which is which is not a line the deck draws anywhere else.

P.LIST_PER_PAGE = 5

--- Every modifier of `kind` taken, as rows { key, arg, doubled, count } in the order first taken.
--- The same modifier taken twice is one row counting two; with a different suit, or doubled by a
--- Summon, it is a row of its own - unless doubling changes nothing about how it reads, and then it
--- is the same row, which is what is on the screen.
function P.taken_rows(kind, st)
    st = st or P.state()
    local picks = {}
    if st.history then
        for _, entry in ipairs(st.history) do
            -- One the Purge took back is no longer in effect, and no longer on the list.
            if kind == "good" then
                if not entry.good_removed then picks[#picks + 1] = { key = entry.good, arg = entry.good_arg } end
            elseif entry.bad and not entry.bad_removed then
                picks[#picks + 1] = { key = entry.bad, arg = entry.bad_arg, doubled = entry.doubled }
            end
        end
    else
        -- A run from before the record was kept: what was taken and how often, in a fixed order, but
        -- not what each was rolled with.
        local ids = {}
        for id in pairs(st.taken or {}) do
            if id:sub(1, #kind + 1) == kind .. ":" then ids[#ids + 1] = id end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            for _ = 1, st.taken[id] do picks[#picks + 1] = { key = id:sub(#kind + 2) } end
        end
    end

    local rows, seen = {}, {}
    for _, pick in ipairs(picks) do
        local base = "celesta_purg_" .. kind .. "_" .. pick.key
        local doubled = text_key(kind, pick.key, pick.doubled) ~= base
        local id = pick.key .. "|" .. tostring(pick.arg) .. "|" .. tostring(doubled)
        local row = seen[id]
        if not row then
            row = { key = pick.key, arg = pick.arg, doubled = doubled, count = 0 }
            seen[id] = row
            rows[#rows + 1] = row
        end
        row.count = row.count + 1
    end
    return rows
end

--- One row of the list: how many times, if more than once, and the modifier's text.
local function list_row(kind, row)
    local count = { n = G.UIT.T, config = { text = row.count > 1 and ("x" .. row.count) or "", scale = 0.45,
        colour = kind == "good" and G.C.GREEN or G.C.RED, shadow = true } }
    return { n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = {
        { n = G.UIT.C, config = { align = "cm", minw = 0.8 }, nodes = { count } },
        { n = G.UIT.C, config = { align = "cm" }, nodes = { text_box(kind, row.key, row.arg, row.doubled) } },
    } }
end

--- One column: its label, then this page's rows of it.
local function list_column(kind, rows, page)
    local nodes = { label(localize("celesta_purg_" .. kind), kind == "good" and G.C.GREEN or G.C.RED) }
    if #rows == 0 then
        nodes[#nodes + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = localize("celesta_purg_none"), scale = 0.4,
                                      colour = G.C.UI.TEXT_INACTIVE } } } }
    end
    for i = (page - 1) * P.LIST_PER_PAGE + 1, math.min(#rows, page * P.LIST_PER_PAGE) do
        nodes[#nodes + 1] = list_row(kind, rows[i])
    end
    return { n = G.UIT.C, config = { align = "tm", padding = 0.1, minw = 4.6 }, nodes = nodes }
end

--- The list's screen, at a page of it.
function P.list_definition(page)
    local st = P.state()
    local good, bad = P.taken_rows("good", st), P.taken_rows("bad", st)
    local pages = math.max(1, math.ceil(math.max(#good, #bad) / P.LIST_PER_PAGE))
    page = math.min(math.max(page or 1, 1), pages)

    local contents = {
        { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            { n = G.UIT.T, config = { text = localize("celesta_purg_modifiers"), scale = 0.7,
                                      colour = G.C.ORANGE, shadow = true } } } },
        { n = G.UIT.R, config = { align = "tm", padding = 0.1 }, nodes = {
            list_column("good", good, page),
            { n = G.UIT.C, config = { minw = 0.15 } },
            list_column("bad", bad, page),
        } },
    }
    if pages > 1 then
        local function turn(text, to, on)
            return UIBox_button {
                col = true, label = { text }, button = on and "celesta_purg_list_page" or "nil",
                ref_table = { page = to }, minw = 0.9, minh = 0.6, scale = 0.45,
                colour = on and G.C.ORANGE or G.C.UI.BACKGROUND_INACTIVE,
            }
        end
        contents[#contents + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            turn("<", page - 1, page > 1),
            { n = G.UIT.C, config = { align = "cm", minw = 2.4 }, nodes = {
                { n = G.UIT.T, config = { text = localize("k_page") .. " " .. page .. "/" .. pages,
                                          scale = 0.4, colour = G.C.UI.TEXT_LIGHT } } } },
            turn(">", page + 1, page < pages),
        } }
    end
    return create_UIBox_generic_options { back_func = "options", minw = 10, contents = contents }
end

G.FUNCS.celesta_purg_list = function()
    G.FUNCS.overlay_menu { definition = P.list_definition(1) }
end

G.FUNCS.celesta_purg_list_page = function(e)
    local ref = e and e.config and e.config.ref_table
    if not ref then return end
    -- Flat, as the reroll is: the same screen with other rows is not a new one to fly in.
    G.FUNCS.overlay_menu { definition = P.list_definition(ref.page), config = { offset = { x = 0, y = 0 } } }
end

--- Whether a node, or anything under it, is the button named `name`.
local function holds_button(node, name)
    if type(node) ~= "table" then return false end
    if node.config and node.config.button == name then return true end
    for _, child in ipairs(node.nodes or {}) do
        if holds_button(child, name) then return true end
    end
    return false
end

-- The pause menu gets a button on a Purgatory run, under Settings. Found by looking for Settings
-- rather than by counting down the boxes, so another mod's button added above or below it - Talisman
-- appends its own to the same list - does not move it.
local celesta_purg_options_ref = create_UIBox_options
function create_UIBox_options(...)
    local menu = celesta_purg_options_ref(...)
    if not (G.STAGE == G.STAGES.RUN and P.active()) then return menu end

    local ok, list = pcall(function() return menu.nodes[1].nodes[1].nodes[1].nodes end)
    if not (ok and type(list) == "table") then return menu end

    local button = UIBox_button {
        label = { localize("celesta_purg_modifiers") }, button = "celesta_purg_list", minw = 5,
        colour = G.C.ORANGE,
    }
    local at = #list + 1
    for i, node in ipairs(list) do
        if holds_button(node, "settings") then at = i + 1 break end
    end
    table.insert(list, at, button)
    return menu
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

--- How many modifiers the Blind that has just ended is owed: none, one, or two.
---
--- A Boss Blind owes one, and two on the Iron Stake (and so every Stake above it); the final Boss
--- owes none, as it ends the run. Any other Blind owes nothing - except on the Rose Stake, where every
--- Blind owes two: Small, Big and Boss alike. A Blind that was lost owes nothing.
function P.owed_count(context)
    local modifiers = G.GAME.modifiers or {}
    if context.beat_boss then
        if ends_the_run() then return 0 end
        return modifiers.celesta_iron and 2 or 1
    end
    if modifiers.celesta_rose and not context.game_over then return 2 end
    return 0
end

function P.calculate(context, from_stake)
    if not (context.end_of_round or context.setting_blind) then return end
    local st = live() or (from_stake and rules())
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

    -- end_of_round: the per-card passes share this flag. Only the deck owes a modifier; a Stake that
    -- reaches this on another deck came for the Blind above.
    if not live() then return end
    if context.individual or context.repetition then return end

    local owed = P.owed_count(context)
    -- The Ichor Stake: after a Boss Blind on an even Ante the choice is a shop of pros to buy instead.
    local shop = owed > 0 and context.beat_boss and (G.GAME.modifiers or {}).celesta_ichor
        and number(G.GAME.round_resets.ante) % 2 == 0
    st.owed = owed > 0
    st.shop = shop and true or nil
    -- How many this Blind is owed, and how many of them are still to be chosen.
    st.pick_total = (owed > 0 and not shop) and owed or nil
    st.pick_left = st.pick_total
    if (st.income or 0) > 0 and not context.game_over then
        return { dollars = st.income }
    end
end

--------------------------------------------------------------------------------
-- A Boss Blind in a Big Blind's place, and the Blind that decides which
--------------------------------------------------------------------------------

--- True once the Boss Blind con has been taken, in a run on this deck.
local function big_may_be_boss()
    local st = rules()
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
    local st = rules()
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
    if turning and rules() then G.GAME.round_resets.blind_choices.Big = "bl_big" end
    return out
end

local celesta_purg_boss_ref = get_new_boss
function get_new_boss(...)
    local st = rules()
    if not st then return celesta_purg_boss_ref(...) end

    -- A Boss Blind that was made certain (the Summon pro with a Boss Blind con): this one, once.
    if st.next_boss and G.P_BLINDS and G.P_BLINDS[st.next_boss] then
        local key = st.next_boss
        st.next_boss = nil
        G.GAME.bosses_used = G.GAME.bosses_used or {}
        G.GAME.bosses_used[key] = (G.GAME.bosses_used[key] or 0) + 1
        return key
    end

    -- Every Boss Blind eligible again, as though none had been used.
    if st.boss_repeat and type(G.GAME.bosses_used) == "table" then
        for key in pairs(G.GAME.bosses_used) do G.GAME.bosses_used[key] = 0 end
    end

    -- A showdown Blind in a plain Boss's place. get_new_boss asks whether the Ante is the winning
    -- one by `ante % win_ante`, so for the length of the call it is.
    -- ...whether by the con, or by the Celestial Stake on a deck that is not this one.
    local super = st.super_boss or (stake_rule("celesta_celestial") and not P.active())
    if super and not is_showdown_ante() and G.GAME.round_resets.ante >= 2
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
    local st = rules()
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

--------------------------------------------------------------------------------
-- What the shop sells, and what a Joker Pack holds
--------------------------------------------------------------------------------
--
-- The shop rolls a card's set from three rates it reads off G.GAME as each card is made, and the
-- Tarot and Planet Merchants write the first two again when they are redeemed. So the rates are
-- moved for the length of that one call and put back after, rather than set once and overwritten.
-- Spectral cards are as common as the Ghost Deck makes them (2, against 4 for a Tarot).

--- The Spectral rate the pro gives the shop: the Ghost Deck's.
P.SPECTRAL_SHOP_RATE = 2

local celesta_purg_shop_ref = create_card_for_shop
function create_card_for_shop(...)
    local st = rules()
    if not (st and (st.no_tarots or st.no_planets or st.spectral_shop)) then
        return celesta_purg_shop_ref(...)
    end

    local game = G.GAME
    local tarot, planet, spectral = game.tarot_rate, game.planet_rate, game.spectral_rate
    if st.no_tarots then game.tarot_rate = 0 end
    if st.no_planets then game.planet_rate = 0 end
    if st.spectral_shop then
        game.spectral_rate = math.max(game.spectral_rate or 0, P.SPECTRAL_SHOP_RATE)
    end

    local out = { pcall(celesta_purg_shop_ref, ...) }
    game.tarot_rate, game.planet_rate, game.spectral_rate = tarot, planet, spectral
    if not out[1] then error(out[2], 0) end
    return unpack(out, 2)
end

--- The chance a card in a Joker Pack is a Stamp instead: the Omen Globe's, for the Spectral card an
--- Arcana Pack may hold.
P.STAMP_PACK_ODDS = 0.2

-- A Joker Pack makes each card through SMODS.create_card with the key_append "buf". A Stamp that
-- turns up is an ordinary Stamp card; it is taken into the consumable tray (stamps/stamps.lua says
-- so for a pack of this kind), and put on a Joker from there.
local celesta_purg_create_ref = SMODS.create_card
function SMODS.create_card(t, ...)
    local st = live()
    local Stamps = CelestasMod.Stamps
    if st and st.stamp_packs and Stamps and type(t) == "table"
        and t.set == "Joker" and t.key_append == "buf" and G.pack_cards and t.area == G.pack_cards
        and pseudorandom(pseudoseed(SEED .. "_stamp_pack")) > 1 - P.STAMP_PACK_ODDS then
        local kind = Stamps.roll_kind()
        if kind then
            return celesta_purg_create_ref({
                set = Stamps.SET,
                key = Stamps.center_key(kind.key),
                area = G.pack_cards,
                skip_materialize = true,
            }, ...)
        end
    end
    return celesta_purg_create_ref(t, ...)
end

--------------------------------------------------------------------------------
-- The hand at the end of the round
--------------------------------------------------------------------------------
--
-- The cards still held are put away just after what they pay is counted (a Gold Card has paid by
-- then) and before they go to the discard. Destroyed here, so they never reach it: the ones
-- destroyed are taken out of the hand at once, so the draws that put the rest away - each takes
-- whatever the hand holds when it runs - do not pick a card that is on its way out. An Eternal
-- playing card cannot be destroyed and is put away like any other.

local celesta_purg_put_away_ref = G.FUNCS.draw_from_hand_to_discard
G.FUNCS.draw_from_hand_to_discard = function(e, ...)
    local st = live()
    if st and st.destroy_held and G.hand and G.hand.cards[1] then
        local held = {}
        for i, card in ipairs(G.hand.cards) do held[i] = card end
        SMODS.destroy_cards(held)
        for _, card in ipairs(held) do
            if card.destroyed or card.shattered then G.hand:remove_card(card) end
        end
    end
    return celesta_purg_put_away_ref(e, ...)
end

--------------------------------------------------------------------------------
-- The cash-out
--------------------------------------------------------------------------------
--
-- "Earn no money from this Blind" is the whole cash-out and not only the Blind's reward: the
-- money for Hands left over, interest, and what Jokers and Tags pay are all money earned at
-- the end of this round, and a con that took only the first left the rest coming in.
--
-- Every row is added through add_round_eval_row, so each is made to say 0, and the last one - the
-- total the cash-out button pays - is the one the money really comes from. The button is wrapped
-- as well, as the thing that pays, in case a row was added some other way.

local celesta_purg_row_ref = add_round_eval_row
function add_round_eval_row(config, ...)
    local st = live()
    if st and st.no_pay_round and type(config) == "table" and config.dollars ~= nil then
        config.dollars = 0
    end
    return celesta_purg_row_ref(config, ...)
end

local celesta_purg_cash_ref = G.FUNCS.cash_out
G.FUNCS.cash_out = function(e, ...)
    local st = live()
    if st and st.no_pay_round then
        G.GAME.current_round.dollars = 0
        st.no_pay_round = nil
    end
    return celesta_purg_cash_ref(e, ...)
end

--------------------------------------------------------------------------------
-- What the Shop does to a reroll
--------------------------------------------------------------------------------

-- A reroll that costs $2 more each time rather than $1: vanilla adds one, and this adds one
-- more. It is added AFTER everything that has a say in the price has had it (Nico Viras, Mogu,
-- the Shoomimi + MinikoMew pair), and only when the price did go up: a Mogu that stops the
-- increase stops all of it, and a free reroll, which vanilla returns from before touching the
-- increase, leaves nothing for this to add to. calculate_reroll_cost(true) is the call that
-- rebuilds the price without increasing it.
local celesta_purg_reroll_ref = calculate_reroll_cost
function calculate_reroll_cost(skip_increment, ...)
    local st = live()
    local round = G.GAME and G.GAME.current_round
    if not (st and st.reroll_two and not skip_increment and round) then
        return celesta_purg_reroll_ref(skip_increment, ...)
    end
    local before = round.reroll_cost_increase or 0
    local ret = celesta_purg_reroll_ref(skip_increment, ...)
    if (round.reroll_cost_increase or 0) > before then
        round.reroll_cost_increase = round.reroll_cost_increase + 1
        celesta_purg_reroll_ref(true, ...)
    end
    return ret
end

--------------------------------------------------------------------------------
-- The hands that cannot be played
--------------------------------------------------------------------------------
--
-- "Least played" is by the number of times the run has played each hand, among the hands the run
-- can see, and every hand tied for the fewest is out. With every hand tied there is no least, and
-- nothing is out.
--
-- Two things stop a hand: the Play button is greyed, and the hand is debuffed the way The Mouth
-- debuffs one, which puts the "will not score" warning over the cards with the reason under it.
-- The warning alone would still let it be played, for nothing.

--- The hands that are out, as a set of names. `ignore_flag` asks who would be, flag or no flag.
function P.banned_hands(ignore_flag)
    local out = {}
    if not ignore_flag then
        local st = live()
        if not (st and st.no_least_hand) then return out end
    end
    local least, most
    local counts = {}
    for name, hand in pairs((G.GAME and G.GAME.hands) or {}) do
        if SMODS.is_poker_hand_visible(name) then
            local n = number(hand.played)
            counts[name] = n
            if not least or n < least then least = n end
            if not most or n > most then most = n end
        end
    end
    if not least or least == most then return out end
    for name, n in pairs(counts) do
        if n == least then out[name] = true end
    end
    return out
end

local celesta_purg_debuff_ref = Blind.debuff_hand
function Blind:debuff_hand(cards, hand, handname, ...)
    local st = live()
    if st and st.no_least_hand and P.banned_hands()[handname] then
        P.BANNED_TEXT = localize("celesta_purg_banned_hand")
        SMODS.debuff_text = P.BANNED_TEXT
        return true
    end
    -- Ours is only ever up for the hand that is forbidden.
    if SMODS.debuff_text and SMODS.debuff_text == P.BANNED_TEXT then SMODS.debuff_text = nil end
    return celesta_purg_debuff_ref(self, cards, hand, handname, ...)
end

--- Whether the hand now highlighted is one that is out. Worked out when the selection changes -
--- which is when vanilla works out what the hand is - and read every frame by the Play button.
P.selected_banned = false

local celesta_purg_parse_ref = CardArea.parse_highlighted
function CardArea:parse_highlighted(...)
    local out = celesta_purg_parse_ref(self, ...)
    if self == G.hand then
        P.selected_banned = false
        local st = live()
        if st and st.no_least_hand and #(self.highlighted or {}) > 0 then
            local name = G.FUNCS.get_poker_hand_info(self.highlighted)
            P.selected_banned = (name ~= "NULL" and P.banned_hands()[name]) and true or false
        end
    end
    return out
end

local celesta_purg_can_play_ref = G.FUNCS.can_play
G.FUNCS.can_play = function(e, ...)
    celesta_purg_can_play_ref(e, ...)
    if P.selected_banned and e.config.button then
        local st = live()
        if st and st.no_least_hand then
            e.config.colour = G.C.UI.BACKGROUND_INACTIVE
            e.config.button = nil
        end
    end
end
