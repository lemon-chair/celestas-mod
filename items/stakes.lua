--- THE STAKES
---
--- Twenty stakes in one chain, one above the other, that sit on top of the Gold Stake:
---
---   Iron       Jokers can have Eternal, Perishable and Rental all at once
---   Lead       Blinds scale faster after each Ante
---   Brass      -1 Joker slot
---   Rose       Ante 12 is the final Ante
---   Lavish     -1 hand size
---   Eryl       Blinds scale faster after each Ante
---   Azure      Uncommon and Rare Jokers appear less often
---   Crimson    Booster Packs have 1 less option to choose from
---   Glimmer    -1 hand
---   Ichor      Blinds scale faster after each Ante
---   Herbium    Vouchers restock every other Ante
---   Magical    -1 consumable slot
---   Abyssal    Boss Blinds can replace Big Blinds
---   Heathen    Shop prices are X1.5 higher; Blinds scale faster after each Ante
---   Soul       Played cards have a 1 in 6 chance to be destroyed after scoring
---   Titanium   Planet cards no longer appear in the shop
---   Hedron     Probabilities are halved (the Soul Stake's own is not)
---   Burning    -1 hand; Blinds scale faster after each Ante
---   Terra      Tarot cards no longer appear in the shop
---   Celestial  Showdown Boss Blinds can replace regular Boss Blinds (on the Purgatory Deck:
---              the modifiers in an offer each have a 1 in 6 chance to be hidden)
---
--- Each applies the one below it, and the first applies Gold. Which is also what unlocks it: Steamodded
--- offers a stake once everything it applies has been won, so winning Gold is what opens this, and it
--- opens it beside Cryptid's Pink Stake - which applies Gold too - rather than behind it. Winning
--- either only carries on up its own chain: Lead needs Iron, Cryptid's Brown Stake needs Pink, and
--- neither needs the other.
---
--- On the Purgatory Deck Iron and Rose are different - that deck has its own cost to pay - and the
--- stake's description says which it is for the deck being looked at. See items/purgatory.lua
--- (`P.owed_count`) for what they do there. Four of the Stakes are four of that deck's curses made a
--- rule of the run from the start (Abyssal, Titanium and Terra), and on that deck the curse of the same
--- name is not offered: it would be asking for what is already so. Celestial's rule is the same one on
--- any other deck, and on this one it is something else: see `P.roll_offers`.
---
--- Glimmer takes a hand, and the Hell Deck has one: there it takes a discard.
---
--- How the stickers stack is Cryptid's Brown Stake: Eternal and Perishable stop excluding each
--- other, and each is rolled of its own rather than from one shared roll. Done here without Cryptid.

local PREFIX = SMODS.current_mod.prefix

-- One sheet of chips, five to a row, in the order of the chain below.
SMODS.Atlas { key = "stake_chips", path = "stake_chips.png", px = 54, py = 54 }
local COLUMNS = 5

--- True when the run being set up or played is on this deck (by name, as run_has_deck has it), or its
--- sleeve.
---
--- Two places to ask, because there are two moments: in the menu the run is being CHOSEN, and the
--- deck is the one being viewed; in a run it has been chosen, and the deck is the one selected.
local function on_deck(name)
    if G.STAGE == G.STAGES.RUN then
        return (CelestasMod.run_has_deck and CelestasMod.run_has_deck(name)) and true or false
    end
    local viewed = G.GAME and G.GAME.viewed_back and G.GAME.viewed_back.effect
        and G.GAME.viewed_back.effect.center
    if viewed and viewed.key == "b_" .. PREFIX .. "_" .. name then return true end
    return G.viewed_sleeve == "sleeve_" .. PREFIX .. "_" .. name
end

local function on_purgatory() return on_deck("purgatory") end

--- Blinds are bigger from the second Ante on: the base game's own `scaling`, one step up. Vanilla
--- has three of them and Steamodded reads any (utils.lua, SMODS.get_blind_amount), so a stake that
--- adds one on top of Gold's is just a higher number.
local function faster_blinds()
    G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
end

--- Makes one of the rules items/purgatory.lua's hooks stand on a rule of the run, for any deck: the
--- flag is what those hooks ask, and `name` is the one the deck's own curse of that name would set.
local function standing_rule(name)
    return function()
        CelestasMod.Purgatory.state()[name] = true
        G.GAME.modifiers.celesta_standing_rules = true
    end
end

--- The chance Soul destroys a played card, as 1 in this.
CelestasMod.SOUL_ODDS = 6
--- What the shop's prices are made higher by on the Heathen Stake.
CelestasMod.HEATHEN_PRICE = 1.5

--- Whether Soul destroys this card. It is an ordinary listed chance in every way but one: it is
--- rolled after the additive pass alone, so what changes the odds by being an odds-changer - Oops!
--- All 6s, Dice, a guarantee, the Hedron Stake's halving - is not asked, and Nagzz, which is the
--- additive pass, is.
function CelestasMod.soul_roll(card)
    local identifier = "celesta_soul"
    local denominator = CelestasMod.SOUL_ODDS
    local passed = SMODS.calculate_context({
        mod_probability = true, from_roll = true, trigger_obj = card, identifier = identifier,
        numerator = 1, denominator = denominator,
    }, nil, false)
    if type(passed) == "table" and passed.denominator ~= nil then denominator = passed.denominator end
    local ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or 0
    return SMODS.pseudorandom_probability(card, identifier .. ante, 1, denominator, identifier, true)
end

--- The colour each stake's chip is made of: the middle of the chip.
local COLOURS = {
    iron = "6f776f", lead = "465d8c", brass = "daa255", rose = "ff4774", lavish = "6a60c1",
    eryl = "4791d8", azure = "1111a6", crimson = "bf0000", glimmer = "238a6f", ichor = "cdae20",
    herbium = "167d16", magical = "d9a3c7", abyssal = "1e3763", heathen = "32557f", soul = "16adfe",
    titanium = "a6a1b6", hedron = "9b008e", burning = "f6830e", terra = "35d4c6", celestial = "ff6778",
}

--- Every stake, in the order it is chained, and what it does to the run once. Each also sets a flag of
--- its own - celesta_<key> - which is what the rest of the mod reads.
---
--- Iron and Rose only set theirs: what they do depends on the deck, and the deck is not chosen until
--- after the stake is applied, so it is asked where it is used and not here.
local STAKES = {
    { key = "iron", name = "Iron" },
    { key = "lead", name = "Lead", effect = faster_blinds },
    { key = "brass", name = "Brass", effect = function()
        G.GAME.starting_params.joker_slots = G.GAME.starting_params.joker_slots - 1
    end },
    { key = "rose", name = "Rose", effect = function() G.GAME.win_ante = 12 end },
    { key = "lavish", name = "Lavish", effect = function()
        G.GAME.starting_params.hand_size = G.GAME.starting_params.hand_size - 1
    end },
    { key = "eryl", name = "Eryl", effect = faster_blinds },
    -- Half as likely each: SMODS.poll_rarity multiplies a rarity's weight by G.GAME.<rarity>_mod
    -- (utils.lua), the way this mod's Sins do (sins/effects.lua). Whatever the two lose, Common gains -
    -- the weights are shares of a total.
    { key = "azure", name = "Azure", effect = function()
        G.GAME.uncommon_mod = (G.GAME.uncommon_mod or 1) * 0.5
        G.GAME.rare_mod = (G.GAME.rare_mod or 1) * 0.5
    end },
    -- Card:open reads the size of every pack through this (card.lua), never below 1 card.
    { key = "crimson", name = "Crimson", effect = function()
        G.GAME.modifiers.booster_size_mod = (G.GAME.modifiers.booster_size_mod or 0) - 1
    end },
    -- The Hell Deck starts with one hand, and one less is none: it takes a discard there instead. Asked of
    -- the deck chosen (run_has_deck) rather than of the stage, which is not yet a run's while this is applied.
    { key = "glimmer", name = "Glimmer", effect = function()
        if CelestasMod.run_has_deck and CelestasMod.run_has_deck("hell") then
            G.GAME.starting_params.discards = G.GAME.starting_params.discards - 1
        else
            G.GAME.starting_params.hands = G.GAME.starting_params.hands - 1
        end
    end },
    { key = "ichor", name = "Ichor", effect = faster_blinds },
    -- Read by the shop (see below), which is where a voucher is put on the shelf.
    { key = "herbium", name = "Herbium" },
    { key = "magical", name = "Magical", effect = function()
        G.GAME.starting_params.consumable_slots = G.GAME.starting_params.consumable_slots - 1
    end },
    { key = "abyssal", name = "Abyssal", effect = standing_rule("boss_for_big") },
    -- A price is made of its own discount; Purgatory's price modifiers scale it the same way, so this
    -- is the same number in the same place.
    { key = "heathen", name = "Heathen", effect = function()
        faster_blinds()
        local state = CelestasMod.Purgatory.state()
        state.price_mult = (state.price_mult or 1) * CelestasMod.HEATHEN_PRICE
        G.GAME.modifiers.celesta_standing_rules = true
    end },
    -- The destruction is the stake's own `calculate`, below.
    { key = "soul", name = "Soul" },
    { key = "titanium", name = "Titanium", effect = standing_rule("no_planets") },
    -- Read by the wrap on SMODS.get_probability_vars, below.
    { key = "hedron", name = "Hedron" },
    { key = "burning", name = "Burning", effect = function()
        G.GAME.starting_params.hands = G.GAME.starting_params.hands - 1
        faster_blinds()
    end },
    { key = "terra", name = "Terra", effect = standing_rule("no_tarots") },
    -- On any deck but the Purgatory Deck this is the Boss Blind rule (items/purgatory.lua asks for it); on
    -- that deck it is the offer's chance to hide a modifier, which is read off the flag.
    { key = "celestial", name = "Celestial", effect = function()
        G.GAME.modifiers.celesta_standing_rules = true
    end },
}

--- The chips on the sheet after the stakes' own: pictures that are not a stake's, drawn in the same style
--- for the Purgatory Deck's categories. They follow the last stake, so no stake's cell moves.
local EXTRA_CHIPS = { "spectral", "tarot", "summon", "sandstone", "lucky" }

--- Where a chip is on the sheet, as the position an atlas cell is asked for by - or nil for a name that is
--- no stake's and no extra's. What the Purgatory Deck's offer draws beside each modifier.
function CelestasMod.stake_chip_pos(key)
    local function at(index)
        return { x = (index - 1) % COLUMNS, y = math.floor((index - 1) / COLUMNS) }
    end
    for index, stake in ipairs(STAKES) do
        if stake.key == key then return at(index) end
    end
    for index, name in ipairs(EXTRA_CHIPS) do
        if name == key then return at(#STAKES + index) end
    end
    return nil
end

--- The stakes whose text is different on the Purgatory Deck: the first two that pay it a cost of their
--- own, and the four whose curse is no longer offered there.
local PURGATORY_TEXT = {
    iron = true, rose = true, abyssal = true, titanium = true, terra = true, celestial = true,
}

-- One chain: each applies the one below it, and the first applies Gold.
local below_key = "gold"
for index, stake in ipairs(STAKES) do
    local below = below_key
    below_key = stake.key
    -- Only Gold is the base game's, and so not given this mod's prefix.
    local on_base_game = below == "gold"
    SMODS.Stake {
        name = stake.name .. " Stake",
        key = stake.key,
        atlas = "stake_chips",
        pos = { x = (index - 1) % COLUMNS, y = math.floor((index - 1) / COLUMNS) },
        applied_stakes = { below },
        above_stake = below,
        prefix_config = on_base_game and {
            applied_stakes = { mod = false },
            above_stake = { mod = false },
        } or nil,
        modifiers = function()
            G.GAME.modifiers["celesta_" .. stake.key] = true
            if stake.effect then stake.effect() end
        end,
        colour = HEX(COLOURS[stake.key]),

        loc_vars = function(self)
            if PURGATORY_TEXT[stake.key] and on_purgatory() then
                return { key = self.key .. "_purgatory" }
            end
            if stake.key == "glimmer" and on_deck("hell") then
                return { key = self.key .. "_hell" }
            end
            return {}
        end,

        -- Soul: each card that scored may be destroyed afterwards. A stake is asked as an individual,
        -- once for each card, in the same pass the Jokers' own `destroying_card` is.
        calculate = stake.key == "soul" and function(self, context)
            if context.destroying_card and context.cardarea == G.play
                and G.GAME.modifiers.celesta_soul and CelestasMod.soul_roll(context.destroying_card) then
                return { remove = true }
            end
        end or nil,
    }
end

-- Whatever a stake that has set a standing rule asks of the blinds being set: the Big Blind a Boss Blind
-- stood in for is still the Big Blind. The deck does the same for its own curse (items/purgatory.lua).
local celesta_stake_mod_calculate = SMODS.current_mod.calculate
SMODS.current_mod.calculate = function(self, context)
    if context.setting_blind and G.GAME and G.GAME.modifiers and G.GAME.modifiers.celesta_abyssal
        and CelestasMod.Purgatory and not CelestasMod.Purgatory.active() then
        CelestasMod.Purgatory.calculate(context, true)
    end
    if celesta_stake_mod_calculate then return celesta_stake_mod_calculate(self, context) end
end

--- Hedron: every listed chance is half as likely, the way Nagzz's is - the denominator doubled, so a
--- 1 in 4 reads 1 in 8. Wrapped after the reference for the Dice's reason: it lands after every
--- additive change, and Ellie Minibot's wrap, which loads later and goes outside it, has the last word.
--- Soul's own chance never comes through here (it is asked with nothing to apply).
local celesta_hedron_probability_ref = SMODS.get_probability_vars
function SMODS.get_probability_vars(trigger_obj, base_numerator, base_denominator,
                                    identifier, from_roll, no_mod, ...)
    local numerator, denominator = celesta_hedron_probability_ref(
        trigger_obj, base_numerator, base_denominator, identifier, from_roll, no_mod, ...)
    if no_mod then return numerator, denominator end
    if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.celesta_hedron) then
        return numerator, denominator
    end
    -- Only a number, or a Talisman number that doubles through its own metamethod: the denominator is
    -- whatever the card asking passed in (Cryptid's RNJoker hands over a sentence).
    local meta = type(denominator) == "table" and getmetatable(denominator)
    if type(denominator) ~= "number" and not (meta and meta.__mul) then return numerator, denominator end
    return numerator, denominator * 2
end

--------------------------------------------------------------------------------
-- Stacking stickers
--------------------------------------------------------------------------------

--- Whether Eternal, Perishable and Rental may all be on one Joker: the Iron Stake, on any
--- deck but the Purgatory Deck, whose version of it is a different cost.
function CelestasMod.iron_stacks_stickers()
    local modifiers = G.GAME and G.GAME.modifiers
    if not (modifiers and modifiers.celesta_iron) then return false end
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

    -- Herbium Stake. The shop puts its vouchers on the shelf one by one, by key, from the list the
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

--- Whether the shop is not to be stocked with vouchers: the Herbium Stake, on every other
--- Ante - the odd ones are stocked, so the first shop is.
function CelestasMod.vouchers_are_held_back()
    local modifiers = G.GAME and G.GAME.modifiers
    if not (modifiers and modifiers.celesta_herbium) then return false end
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
-- are the same only while the stakes form one line. Pink Stake and the Iron Stake both sit on Gold,
-- so both have the same level, and whichever one the list found at that place was shown for the
-- other: Lead Stake said it applied Pink Stake's rule, and Cryptid's Brown Stake said it applied
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
