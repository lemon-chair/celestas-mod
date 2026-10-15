--- THE IRON, BRASS AND ROSE STAKES
---
--- Twelve stakes in one chain, one above the other, that sit on top of the Gold Stake:
---
---   Iron Stake I     Jokers can have Eternal, Perishable and Rental all at once
---   Iron Stake II    Blinds scale faster after each Ante
---   Iron Stake III   -1 Joker slot
---   Iron Stake IV    Ante 12 is the final Ante
---   Brass Stake I    -1 hand size
---   Brass Stake II   Blinds scale faster after each Ante
---   Brass Stake III  Uncommon and Rare Jokers appear less often
---   Brass Stake IV   Booster Packs have 1 less option to choose from
---   Rose Stake I     -1 hand
---   Rose Stake II    Blinds scale faster after each Ante
---   Rose Stake III   Vouchers restock every other Ante
---   Rose Stake IV    -1 consumable slot
---
--- Each applies the one below it, and the first applies Gold. Which is also what unlocks it: Steamodded
--- offers a stake once everything it applies has been won, so winning Gold is what opens this, and it
--- opens it beside Cryptid's Pink Stake - which applies Gold too - rather than behind it. Winning
--- either only carries on up its own chain: Iron Stake II needs Iron Stake I, Cryptid's Brown Stake
--- needs Pink, and neither needs the other. Brass Stake I sits on Iron Stake IV and Rose Stake I on
--- Brass Stake IV, so each metal opens once the one before it has been won.
---
--- On the Purgatory Deck the first and last Iron are different - that deck has its own cost to pay -
--- and the stake's description says which it is for the deck being looked at. See items/purgatory.lua
--- (`P.owed_count`) for what they do there.
---
--- How the stickers stack is Cryptid's Brown Stake: Eternal and Perishable stop excluding each
--- other, and each is rolled of its own rather than from one shared roll. Done here without Cryptid.

local PREFIX = SMODS.current_mod.prefix

-- One sheet of chips a metal, four in a row. The Iron art is 71x71 and the others 54x54: a chip is
-- drawn at the same size whatever the sheet's cells are.
SMODS.Atlas { key = "stake_iron", path = "stake_iron.png", px = 71, py = 71 }
SMODS.Atlas { key = "stake_brass", path = "stake_brass.png", px = 54, py = 54 }
SMODS.Atlas { key = "stake_rose", path = "stake_rose.png", px = 54, py = 54 }

--- The colour each metal's chips are made of.
local IRON = HEX("8f9a9c")
local BRASS = HEX("c9993f")
local ROSE = HEX("ff4f7b")

--- The Purgatory Deck's key, and its sleeve's: what the stake is looked at under.
local PURGATORY_DECK = "b_" .. PREFIX .. "_purgatory"
local PURGATORY_SLEEVE = "sleeve_" .. PREFIX .. "_purgatory"

--- True when the run being set up or played is on the Purgatory Deck, or its sleeve.
---
--- Two places to ask, because there are two moments: in the menu the run is being CHOSEN, and the
--- deck is the one being viewed; in a run it has been chosen, and the deck is the one selected.
local function on_purgatory()
    if G.STAGE == G.STAGES.RUN then
        return (CelestasMod.run_has_deck and CelestasMod.run_has_deck("purgatory")) and true or false
    end
    local viewed = G.GAME and G.GAME.viewed_back and G.GAME.viewed_back.effect
        and G.GAME.viewed_back.effect.center
    if viewed and viewed.key == PURGATORY_DECK then return true end
    return G.viewed_sleeve == PURGATORY_SLEEVE
end

--- Blinds are bigger from the second Ante on: the base game's own `scaling`, one step up. Vanilla
--- has three of them and Steamodded reads any (utils.lua, SMODS.get_blind_amount), so a stake that
--- adds one on top of Gold's is just a higher number.
local function faster_blinds()
    G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
end

--- What each tier does to the run, once. The flags are what the rest of the mod reads.
---
--- The first and last Iron only set one: what they do depends on the deck, and the deck is not
--- chosen until after the stake is applied, so it is asked where it is used and not here.
local METALS = {
    {
        key = "iron", name = "Iron", atlas = "stake_iron", colour = IRON,
        tiers = {
            function() G.GAME.modifiers.celesta_iron_1 = true end,
            function()
                faster_blinds()
                G.GAME.modifiers.celesta_iron_2 = true
            end,
            function()
                G.GAME.starting_params.joker_slots = G.GAME.starting_params.joker_slots - 1
                G.GAME.modifiers.celesta_iron_3 = true
            end,
            function()
                G.GAME.win_ante = 12
                G.GAME.modifiers.celesta_iron_4 = true
            end,
        },
    },
    {
        key = "brass", name = "Brass", atlas = "stake_brass", colour = BRASS,
        tiers = {
            function() G.GAME.starting_params.hand_size = G.GAME.starting_params.hand_size - 1 end,
            faster_blinds,
            -- Half as likely each: SMODS.poll_rarity multiplies a rarity's weight by
            -- G.GAME.<rarity>_mod (utils.lua), the way this mod's Sins do (sins/effects.lua).
            -- Whatever the two lose, Common gains - the weights are shares of a total.
            function()
                G.GAME.uncommon_mod = (G.GAME.uncommon_mod or 1) * 0.5
                G.GAME.rare_mod = (G.GAME.rare_mod or 1) * 0.5
            end,
            -- Card:open reads the size of every pack through this (card.lua), never below 1 card.
            function()
                G.GAME.modifiers.booster_size_mod = (G.GAME.modifiers.booster_size_mod or 0) - 1
            end,
        },
    },
    {
        key = "rose", name = "Rose", atlas = "stake_rose", colour = ROSE,
        tiers = {
            function() G.GAME.starting_params.hands = G.GAME.starting_params.hands - 1 end,
            faster_blinds,
            -- Read by the shop (see below), which is where a voucher is put on the shelf.
            function() G.GAME.modifiers.celesta_rose_3 = true end,
            function() G.GAME.starting_params.consumable_slots = G.GAME.starting_params.consumable_slots - 1 end,
        },
    },
}

--- The tiers whose text is different on the Purgatory Deck: the first and last Iron.
local PURGATORY_TEXT = { iron = { [1] = true, [4] = true } }

local NUMERALS = { "I", "II", "III", "IV" }

-- One chain: each applies the one below it, and the first of a metal applies the last of the one
-- before - Iron's applies Gold.
local below_key = "gold"
for _, metal in ipairs(METALS) do
    for tier = 1, #metal.tiers do
        local below = below_key
        below_key = metal.key .. "_" .. tier
        -- Only Gold is the base game's, and so not given this mod's prefix.
        local on_base_game = below == "gold"
        SMODS.Stake {
            name = metal.name .. " Stake " .. NUMERALS[tier],
            key = metal.key .. "_" .. tier,
            atlas = metal.atlas,
            pos = { x = tier - 1, y = 0 },
            applied_stakes = { below },
            above_stake = below,
            prefix_config = on_base_game and {
                applied_stakes = { mod = false },
                above_stake = { mod = false },
            } or nil,
            modifiers = metal.tiers[tier],
            colour = metal.colour,

            loc_vars = function(self)
                if PURGATORY_TEXT[metal.key] and PURGATORY_TEXT[metal.key][tier] and on_purgatory() then
                    return { key = self.key .. "_purgatory" }
                end
                return {}
            end,
        }
    end
end

--------------------------------------------------------------------------------
-- Stacking stickers
--------------------------------------------------------------------------------

--- Whether Eternal, Perishable and Rental may all be on one Joker: the first Iron Stake, on any
--- deck but the Purgatory Deck, whose version of it is a different cost.
function CelestasMod.iron_stacks_stickers()
    local modifiers = G.GAME and G.GAME.modifiers
    if not (modifiers and modifiers.celesta_iron_1) then return false end
    local Purgatory = CelestasMod.Purgatory
    return not (Purgatory and Purgatory.active and Purgatory.active())
end

-- Wrapped when a run starts rather than here, because what is wrapped has to be the LAST thing
-- anyone assigned to it. Cryptid replaces Card:set_eternal and set_perishable outright at its own
-- load, so a wrap made here would be gone if it loaded after this - and by the time a run begins,
-- everything has.
local wrapped = {}

local function wrap_method(name, replacement)
    local ref = Card[name]
    if not ref or wrapped[ref] then return end
    local function method(self, ...)
        local done, ret = replacement(self, ...)
        if done then return ret end
        return ref(self, ...)
    end
    wrapped[method] = true
    Card[name] = method
end

local function install()
    -- Vanilla's own, minus the line that makes the other one a reason not to: each only asks
    -- whether the Joker may have it at all.
    wrap_method("set_eternal", function(self, value)
        if not CelestasMod.iron_stacks_stickers() then return false end
        self.ability.eternal = nil
        if self.config.center.eternal_compat then self.ability.eternal = value end
        return true
    end)
    wrap_method("set_perishable", function(self, value)
        if not CelestasMod.iron_stacks_stickers() then return false end
        self.ability.perishable = nil
        if value ~= false and self.config.center.perishable_compat then
            self.ability.perishable = true
            self.ability.perish_tally = G.GAME.perishable_rounds
        end
        return true
    end)

    -- A Joker the shop or a pack makes. Vanilla rolls Eternal and Perishable from ONE number - one
    -- above 0.7, the other between 0.4 and 0.7 - so they cannot come together however the card
    -- would take them. Perishable is rolled again on a number of its own, at the same 30%, so each
    -- is as likely as before and a Joker can be both. Rental already has a roll of its own.
    local create_ref = create_card
    if create_ref and not wrapped[create_ref] then
        local function create(_type, area, legendary, rarity, skip, soulable, forced_key, key_append, ...)
            local card = create_ref(_type, area, legendary, rarity, skip, soulable, forced_key, key_append, ...)
            if card and card.ability and card.ability.set == "Joker"
                and (area == G.shop_jokers or area == G.pack_cards)
                and CelestasMod.iron_stacks_stickers()
                and G.GAME.modifiers.enable_perishables_in_shop then
                card.ability.perishable = nil
                card.ability.perish_tally = nil
                local roll = pseudorandom("celesta_iron_per" .. (key_append or "") .. G.GAME.round_resets.ante)
                if roll > 0.7 then card:set_perishable(true) end
            end
            return card
        end
        wrapped[create] = true
        create_card = create
    end

    -- Rose Stake III. The shop puts its vouchers on the shelf one by one, by key, from the list the
    -- last Boss Blind drew (game.lua, SMODS.add_voucher_to_shop). On the Antes the shelf is to be
    -- empty that is where they are held back, as Cryptid's Blank Deck does for all of them: the
    -- list is left as drawn, so a Voucher Tag, which makes its own, and everything else that
    -- reads the list are as they were.
    local shelf_ref = SMODS.add_voucher_to_shop
    if shelf_ref and not wrapped[shelf_ref] then
        local function shelf(key, ...)
            if key and CelestasMod.vouchers_are_held_back() then
                local drawn = G.GAME.current_round.voucher
                if drawn and drawn.spawn and drawn.spawn[key] then return end
            end
            return shelf_ref(key, ...)
        end
        wrapped[shelf] = true
        SMODS.add_voucher_to_shop = shelf
    end
end

--- Whether the shop is not to be stocked with vouchers: the Rose Stake's third tier, on every other
--- Ante - the odd ones are stocked, so the first shop is.
function CelestasMod.vouchers_are_held_back()
    local modifiers = G.GAME and G.GAME.modifiers
    if not (modifiers and modifiers.celesta_rose_3) then return false end
    return G.GAME.round_resets.ante % 2 == 0
end

local celesta_stake_start_ref = Game.start_run
function Game:start_run(...)
    install()
    return celesta_stake_start_ref(self, ...)
end

--------------------------------------------------------------------------------
-- Two stakes of the same level
--------------------------------------------------------------------------------
--
-- Steamodded lists what a stake applies under its description, and finds each one by its
-- stake_level - how many stakes are in ITS chain - as though that were its place in the list. They
-- are the same only while the stakes form one line. Pink Stake and Iron Stake I both sit on Gold,
-- so both have the same level, and whichever one the list found at that place was shown for the
-- other: Iron Stake II said it applied Pink Stake's rule, and Cryptid's Brown Stake said it applied
-- Iron's.
--
-- Rewritten, with the one change: the place is looked up by key.

local function pool_index(key)
    for index, stake in ipairs(G.P_CENTER_POOLS.Stake) do
        if stake.key == key then return index end
    end
end

function SMODS.applied_stakes_UI(i, stake_desc_rows, num_added)
    if num_added == nil then num_added = { val = 0 } end
    local stake = G.P_CENTER_POOLS.Stake[i]
    for _, key in pairs((stake and stake.applied_stakes) or {}) do
        if key ~= "white" then
            local index = pool_index(key)
            -- todo in Steamodded: manage this with pages
            if index and num_added.val < 8 then
                local _stake_desc = {}
                local _stake_center = G.P_CENTER_POOLS.Stake[index]
                local t, res = {}, {}
                if _stake_center.loc_vars and type(_stake_center.loc_vars) == "function" then
                    res = _stake_center:loc_vars() or {}
                end
                t.vars = res.vars or {}
                t.key = res.key or _stake_center.key
                t.set = res.set or _stake_center.set
                localize { type = "descriptions", key = t.key, set = t.set, nodes = _stake_desc, vars = t.vars }
                local _full_desc = {}
                for _, line in ipairs(_stake_desc) do
                    _full_desc[#_full_desc + 1] = { n = G.UIT.R, config = { align = "cm" }, nodes = line }
                end
                _full_desc[#_full_desc] = nil
                stake_desc_rows[#stake_desc_rows + 1] = { n = G.UIT.R, config = { align = "cm" }, nodes = {
                    { n = G.UIT.C, config = { align = "cm" }, nodes = {
                        { n = G.UIT.C, config = { align = "cm", colour = get_stake_col(index), r = 0.1,
                                                  minh = 0.35, minw = 0.35, emboss = 0.05 }, nodes = {} },
                        { n = G.UIT.B, config = { w = 0.1, h = 0.1 } } } },
                    { n = G.UIT.C, config = { align = "cm", padding = 0.03, colour = G.C.WHITE, r = 0.1,
                                              minh = 0.7, minw = 4.8 }, nodes = _full_desc },
                } }
            end
            num_added.val = num_added.val + 1
            if index then
                num_added.val = SMODS.applied_stakes_UI(index, stake_desc_rows, num_added)
            end
        end
    end
    return num_added.val
end
