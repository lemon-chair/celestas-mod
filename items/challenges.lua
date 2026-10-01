--- CHALLENGES
---
--- A challenge is data, not behaviour: Game:start_run reads the table straight
--- off G.CHALLENGES and does the work itself (game.lua:2113 onward). It adds
--- each `jokers` entry through add_joker and calls set_eternal on it, then
--- assigns every `rules.modifiers` entry into starting_params.
---
--- Two things about that are worth knowing before editing one.
---
--- A modifier is an ABSOLUTE value, not a delta the way a Back's config is:
--- `self.GAME.starting_params[v.id] = v.value`. joker_slots below is 6 because
--- 6 is the number wanted, not because it adds one to the usual five.
---
--- And add_joker indexes G.P_CENTERS[id] without looking first
--- (common_events.lua:377), so a key that is not a real centre is not one
--- missing Joker - it is a run that cannot start. The keys here are checked
--- against the mod's own registrations by the test suite for that reason.

--------------------------------------------------------------------------------
-- Dairy Farm - the three Milk Bottle Jokers, kept.
--------------------------------------------------------------------------------
--
-- The three of them are the whole Milk Bottle engine: Moo Merrily makes a
-- Bottle every round, Milky stops the Bottles taking up consumable slots, and
-- Moo Moo Clover lets each Bottle pick two cards instead of one. Eternal, so
-- the engine cannot be sold off, and six Joker slots so there are three left
-- to build something around it with.

--------------------------------------------------------------------------------
-- Joker Printer - two slots and a press
--------------------------------------------------------------------------------
--
-- x3Dustco makes a Joker from this mod at the end of every shop, and there is
-- nowhere to put them: three slots fewer than usual leaves two, one of which
-- x3Dustco is standing in. The Bind is what the challenge is actually about -
-- folding each new Joker into the one you kept rather than choosing between
-- them - and it is the starting consumable rather than something to be found,
-- because a Bind cannot reach a shop on its own (merge/bind.lua).
--
-- A challenge consumable goes through add_joker, which routes it by the
-- centre's `consumeable` flag rather than by the field it was listed under
-- (common_events.lua:377), so a Spectral listed here lands in the consumable
-- row and not among the Jokers.

-- Resolved at load: SMODS.current_mod is nil by the time a Blind is set.
local PRINTER_KEY = "c_" .. SMODS.current_mod.prefix .. "_joker_printer"

-- Gold Stake's, whatever Stake the run is actually on.
--
-- get_blind_amount picks its table of base amounts off
-- G.GAME.modifiers.scaling (misc_functions.lua:1040): 1 is White's - 300, 800,
-- 2000, 5000 ... - 2 is what Green and up use, and 3 is what Purple and up use,
-- which is where Gold lands: 300, 1000, 3200, 9000, 25000, 60000, 110000,
-- 200000.
--
-- Gold is 3 rather than 8 because the Stakes do not each have their own table.
-- Steamodded builds Gold out of every Stake below it, and exactly two of them
-- - Green and Purple - raise `scaling` by one (src/game_object.lua:790, :830).
local GOLD_STAKE_SCALING = 3

--- What the quota is multiplied by at this Ante: 1, 3, 6, 10, 15, 21, 28, 36.
---
--- The triangular numbers, n(n+1)/2 - the multiplier does not climb by a fixed
--- amount, the CLIMB itself grows by one each Ante. Ante 2 is two more than
--- Ante 1, Ante 3 is three more than Ante 2, and so on.
---
--- Written as the closed form rather than as a running total because a running
--- total would need somewhere to live, and this has to answer for any Ante at
--- any time: the Blind select screen asks about the Ante being offered, and the
--- ladder in the run info asks about all eight at once.
---
--- Antes below 1 are left alone. get_blind_amount answers 100 for them - it is
--- the tutorial's - and n(n+1)/2 would hand Ante 0 a multiplier of 0, which is
--- a Blind that needs no chips at all.
function CelestasMod.printer_quota_scale(ante)
    if type(ante) ~= "number" or ante < 1 then return 1 end
    -- floor, because `/` is float division in every Lua the game might run
    -- on: n(n+1) is always even so nothing is lost, and an integer keeps the
    -- quota an integer.
    return math.floor(ante * (ante + 1) / 2)
end

SMODS.Challenge {
    key = "joker_printer",

    jokers = {
        -- Eternal, so the press cannot be sold for the slot it occupies.
        { id = "j_celesta_x3dustco", eternal = true },
    },

    consumeables = {
        { id = "c_celesta_bind" },
    },

    --- Called by Game:start_run once the run exists, after the Stake has been
    --- set up and the deck applied (game.lua:2117).
    ---
    --- modifiers.scaling is read by get_blind_amount and by nothing else in
    --- the game, so writing it here moves the quota and only the quota.
    ---
    --- max rather than assignment: a run already above Gold - another mod's
    --- Stake - keeps what it had. This is a floor, not a ceiling.
    apply = function(self)
        if not (G.GAME and G.GAME.modifiers) then return end
        G.GAME.modifiers.scaling =
            math.max(G.GAME.modifiers.scaling or 1, GOLD_STAKE_SCALING)
    end,

    rules = {
        -- Rendered on the challenge screen from misc.v_text.ch_c_<id>, with
        -- `value` threaded in as #1# (UI_definitions.lua:6058). Without an
        -- entry there the rule would be listed as the literal string ERROR.
        custom = {
            -- No value on either: the text names what it means outright,
            -- because neither is a single number to thread through.
            -- Shared with The Nutshack, which is on the same base amounts.
            { id = "celesta_gold_base" },
            { id = "celesta_printer_quota" },
        },
        modifiers = {
            -- Absolute, not a delta: vanilla starts on 5, so three fewer is 2.
            { id = "joker_slots", value = 2 },
        },
    },
}

--------------------------------------------------------------------------------
-- ...and the quota that climbs with the Ante
--------------------------------------------------------------------------------
--
-- Ante 1 is untouched, Ante 2 is X3, Ante 3 is X5, and two more every Ante
-- after - so the multiplier at Ante n is 2n-1.
--
-- ante_scaling, the starting param the Plasma Deck uses, cannot do this: it is
-- one number for the whole run. So the hook is on get_blind_amount instead,
-- which is the one function BOTH places asking for a quota go through - the
-- Blind itself (blind.lua:118) and the panel on the Blind select screen
-- (UI_definitions.lua:1682) - so the number offered and the number required
-- cannot disagree. The Ante ladder in the run info reads it too, and shows the
-- challenge's own numbers while the challenge is being played.
--
-- Wrapped rather than replaced, and wrapped at load, so Talisman's own version
-- of this function still does its work first and this only multiplies the
-- answer. Deliberately NOT guarded on the value being a plain number: past a
-- certain Ante it is one of Talisman's big numbers, and those multiply through
-- their own metamethod. It is COMPARISON that Lua 5.1 refuses across types,
-- not arithmetic.

local celesta_printer_blind_ref = get_blind_amount
if type(celesta_printer_blind_ref) == "function" then
    function get_blind_amount(ante, ...)
        local amount = celesta_printer_blind_ref(ante, ...)
        if not (G.GAME and G.GAME.challenge == PRINTER_KEY) then return amount end
        return amount * CelestasMod.printer_quota_scale(ante)
    end
end

SMODS.Challenge {
    key = "dairy_farm",

    jokers = {
        { id = "j_celesta_moomerrily", eternal = true },
        { id = "j_celesta_milky",      eternal = true },
        -- Moo Moo Clover's key really is 'clover'. The Blind of the same name
        -- is bl_celesta_clover, which is a different centre entirely.
        { id = "j_celesta_clover",     eternal = true },
    },

    rules = {
        custom = {},
        modifiers = {
            { id = "joker_slots", value = 6 },
        },
    },
}

--------------------------------------------------------------------------------
-- The three Jokers that can end either challenge below
--------------------------------------------------------------------------------
--
-- Both of them are one eternal Joker and a run built around not being able to
-- get rid of it, so a Joker that takes the Eternal off is a Joker that ends the
-- challenge. Three of them can: Smug Alana takes one sticker off a Frozen Joker
-- as it melts, Fenari takes one off a random Joker at the end of every round,
-- and FireOniRei takes every sticker off every Joker a Boss Blind is beaten
-- with.
--
-- One list for both, because it is one reason. banned_cards is read and never
-- written - Game:start_run copies each id into G.GAME.banned_keys
-- (game.lua:2185), and the challenge screen reads the same table to draw the
-- cards (UI_definitions.lua:6094) - so sharing it cannot let the two come to
-- disagree.

local STICKER_STRIPPERS = {
    { id = "j_celesta_smugalana" },
    { id = "j_celesta_fenari" },
    { id = "j_celesta_fireonirei" },
}

--------------------------------------------------------------------------------
-- The Passage - everything you buy goes the same way
--------------------------------------------------------------------------------
--
-- Urschleim eats one of your Jokers at the end of every round and keeps a tenth
-- of its sell value as Chips. Eternal, so the mouth is the one thing in the row
-- that cannot be sold - and it is not on its own menu either: urschleim_menu
-- passes over its own family and over anything eternal
-- (jokers/implemented.lua), so every Joker bought after it is food and it never
-- is.
--
-- Nothing else: no modifier, no second Joker, no consumable. The Joker is the
-- challenge.

SMODS.Challenge {
    key = "the_passage",

    jokers = {
        { id = "j_celesta_urschleim", eternal = true },
    },

    restrictions = {
        banned_cards = STICKER_STRIPPERS,
    },

    rules = {
        custom = {},
        modifiers = {},
    },
}

--------------------------------------------------------------------------------
-- Bird Feeder - the hand is what you feed it
--------------------------------------------------------------------------------
--
-- Dokibird destroys the played cards that did not score, when exactly one of
-- them did, and gives what they were holding to the one that did - permanently.
-- Eternal, so that is not a trade taken when it suits: it is the shape of every
-- hand for the rest of the run, and the deck is what is being spent.

SMODS.Challenge {
    key = "bird_feeder",

    jokers = {
        { id = "j_celesta_dokibird", eternal = true },
    },

    restrictions = {
        banned_cards = STICKER_STRIPPERS,
    },

    rules = {
        custom = {},
        modifiers = {},
    },
}

--------------------------------------------------------------------------------
-- The Nutshack - a deck of one card, and KokoNuts to keep making it
--------------------------------------------------------------------------------
--
-- Fifty-two Lucky 7 of Spades. Every hand is five sevens of one suit, every
-- card is a Lucky roll, and KokoNuts - eternal - puts another Lucky seven in at
-- the start of every round, which is the only thing in the run that makes the
-- deck bigger without making it different.
--
-- The Bind is the starting consumable for the reason Joker Printer's is: a Bind
-- cannot reach a shop on its own (merge/bind.lua). It is also the one thing that
-- can change what KokoNuts puts in - KokoNuts + BerryCrepe adds a Mult seven
-- instead - so the deck stays one card only as long as the player leaves it.
--
-- Blinds are Gold Stake's base amounts, doubled: the Plasma Deck's scaling on a
-- Gold run. `scaling` picks the ladder get_blind_amount reads, and ante_scaling
-- is the number both the Blind (blind.lua:118) and the panel offering it
-- (UI_definitions.lua:1682) multiply it by, which is the whole of what the
-- Plasma Deck does to a blind (back.lua:336).
--
-- ante_scaling is set in `apply` and deliberately NOT listed under
-- rules.modifiers. The challenge screen's Rules tab builds its list from seven
-- known modifier ids and reads `base_modifiers[v.id].value` for the old value
-- with no guard at all (UI_definitions.lua:6025), so a modifier it has never
-- heard of does not simply go unlisted - it takes the tab down with it. Only
-- vanilla's own seven starting params are safe to list; anything else belongs in
-- apply, with a custom rule to say so on the screen.

--- What the Plasma Deck multiplies a blind by (game.lua:650).
local PLASMA_ANTE_SCALING = 2

--- Fifty-two of one card, which is the whole deck.
---
--- The shape is vanilla's own - card_from_control reads s, r and e off each
--- entry (misc_functions.lua:1804) - and vanilla's own challenge decks write
--- all fifty-two out by hand. A loop instead, because what matters about this
--- one is that there is only ever the one card in it.
local NUTSHACK_DECK = {}
for _ = 1, 52 do
    NUTSHACK_DECK[#NUTSHACK_DECK + 1] = { s = "S", r = "7", e = "m_lucky" }
end

SMODS.Challenge {
    key = "the_nutshack",

    jokers = {
        { id = "j_celesta_kokonuts", eternal = true },
    },

    consumeables = {
        { id = "c_celesta_bind" },
    },

    deck = { type = "Challenge Deck", cards = NUTSHACK_DECK },

    restrictions = {
        banned_cards = STICKER_STRIPPERS,
    },

    --- max rather than assignment on both, for the reason Joker Printer's gives:
    --- a run already above either keeps what it had. These are floors.
    ---
    --- Safe to raise ante_scaling here because the deck has already had its say:
    --- selected_back:apply_to_run() runs at game.lua:2111 and the challenge
    --- block starts on the line after it.
    apply = function(self)
        if not (G.GAME and G.GAME.modifiers) then return end
        G.GAME.modifiers.scaling =
            math.max(G.GAME.modifiers.scaling or 1, GOLD_STAKE_SCALING)
        local params = G.GAME.starting_params
        if params then
            params.ante_scaling =
                math.max(params.ante_scaling or 1, PLASMA_ANTE_SCALING)
        end
    end,

    rules = {
        custom = {
            { id = "celesta_gold_base" },
            { id = "celesta_plasma_blinds", value = PLASMA_ANTE_SCALING },
            { id = "celesta_nutshack_deck" },
        },
        modifiers = {},
    },
}

--------------------------------------------------------------------------------
-- Orbital I, II and III - one rarity, twice the price, and CDawg keeping it
--------------------------------------------------------------------------------
--
-- Three runs of one shape. Every Joker the run offers is a single rarity, each
-- costs twice what it would, and the eternal CDawg you start with is already
-- merged with the card that makes it retain that rarity - from this mod and from
-- the base game both. So the Jokers the shop offers are exactly the Jokers the
-- orbit can keep, and the run is spent buying them to sell them.
--
--   I    Blue Card     Common
--   II   Green Card    Uncommon
--   III  Fuchsia Card  Rare

--- Each Orbital: the Joker merged into CDawg, the rarity the run deals in, and
--- the rule that says so on the challenge screen.
local ORBITALS = {
    { key = "orbital_i",   partner = "j_celesta_blue_card",
      rarity = 1, rule = "celesta_orbital_common" },
    { key = "orbital_ii",  partner = "j_celesta_green_card",
      rarity = 2, rule = "celesta_orbital_uncommon" },
    { key = "orbital_iii", partner = "j_celesta_fuchsia_card",
      rarity = 3, rule = "celesta_orbital_rare" },
}

--- What a Joker costs on an Orbital run, as a multiple of what it would.
local ORBITAL_PRICE = 2

--- The Orbitals by challenge id, which is what G.GAME.challenge holds.
---
--- Built at load, like PRINTER_KEY above and for the same reason: the prefix
--- comes off SMODS.current_mod, which is nil by the time any of this is asked.
local ORBITAL_BY_ID = {}
for _, orbital in ipairs(ORBITALS) do
    ORBITAL_BY_ID["c_" .. SMODS.current_mod.prefix .. "_" .. orbital.key] = orbital
end

--- The Orbital being played, or nil.
local function orbital_run()
    return ORBITAL_BY_ID[G.GAME and G.GAME.challenge]
end

--------------------------------------------------------------------------------
-- ...only one rarity is offered
--------------------------------------------------------------------------------
--
-- SMODS.poll_rarity is the one place a Joker's rarity is rolled: vanilla's
-- get_current_pool asks it for the Joker pool and for every modded ObjectType
-- with rarities of its own (common_events.lua:2266, :2275). So one wrap covers
-- the shop, the packs, a Wraith and a tag alike.
--
-- Narrowed to the Joker pool, because another ObjectType's rarities are its own
-- and a number is not an answer to them.
--
-- The Soul is untouched and that is not an oversight: get_current_pool takes the
-- Legendary pool when it is asked for a legendary and never rolls at all, so a
-- Soul found in a pack still gives what it gives. The CDawg the run starts with
-- is Legendary too - "only Commons appear" is about what the run OFFERS.

local celesta_orbital_poll_ref = SMODS.poll_rarity
function SMODS.poll_rarity(pool_key, ...)
    local orbital = orbital_run()
    if orbital and pool_key == "Joker" then return orbital.rarity end
    return celesta_orbital_poll_ref(pool_key, ...)
end

--------------------------------------------------------------------------------
-- ...and a Joker costs twice as much
--------------------------------------------------------------------------------
--
-- base_cost doubled around vanilla's own set_cost rather than the answer doubled
-- after it. Everything a price is made of then comes out as vanilla would
-- compute it for a Joker that costs that much: the Clearance Sale discount, the
-- run's inflation, an edition's extra cost, and the sell value at half of it.
--
-- Put back afterwards, because set_cost is called again every time a price could
-- have changed - doubling in place would compound once per call.

local celesta_orbital_cost_ref = Card.set_cost
function Card:set_cost(...)
    if not (orbital_run() and self.ability and self.ability.set == "Joker") then
        return celesta_orbital_cost_ref(self, ...)
    end

    local saved = self.base_cost
    self.base_cost = (saved or 0) * ORBITAL_PRICE
    local ok, err = pcall(celesta_orbital_cost_ref, self, ...)
    self.base_cost = saved
    if not ok then error(err, 0) end
end

--------------------------------------------------------------------------------
-- ...and the CDawg arrives already merged
--------------------------------------------------------------------------------

--- A CardArea-shaped nowhere, for the reason items/decks.lua has one: create_card
--- reads the area to decide whether to discover the centre and whether to roll
--- Eternal, Perishable or Rental onto the card, and a stand-in must answer no to
--- all three. `nil` would not do - create_card reads that as G.jokers.
local ORBITAL_NOWHERE = { T = { x = 0, y = 0, w = 0, h = 0 } }

--- Merges `partner_key` into the CDawg the challenge started the run with.
---
--- The partner exists only to carry an ability table for Bind.merge to copy, so
--- it is removed straight after - Card's constructor has already put it in
--- G.I.CARD, and leaving it there would be a card the game updates every frame
--- for the rest of the run.
---
--- The used mark its construction left on the centre is put back, for the reason
--- the Fusion Deck puts its own back: merging in this mod does not take either
--- half out of the run's pools, and nothing ever clears a used mark for a card
--- that no longer exists.
local function orbital_fuse(partner_key)
    local Bind = CelestasMod.Bind
    local found = CelestasMod.find_joker("j_celesta_cdawg")[1]
    local host = found and found.card
    if not (host and Bind and Bind.merge and Bind.can_bind(host)) then
        CelestasMod.warn_once("orbital_no_cdawg",
            "An Orbital run found no CDawg to merge its card into")
        return
    end

    local used = G.GAME and G.GAME.used_jokers
    local before = used and copy_table(used) or {}

    local ok, partner = pcall(create_card, "Joker", ORBITAL_NOWHERE, nil, nil,
                              true, nil, partner_key)
    if not (ok and partner) then
        CelestasMod.warn_once("orbital_no_partner",
            ("An Orbital run could not build %s to merge"):format(
                tostring(partner_key)))
        return
    end

    local merged = Bind.merge(host, partner, true)
    partner:remove()
    if used then used[partner_key] = before[partner_key] end

    if not merged then
        CelestasMod.warn_once("orbital_no_merge",
            ("An Orbital run could not merge %s into its CDawg"):format(
                tostring(partner_key)))
    end
end

-- Queued AFTER start_run has returned, and that is the whole reason this is a
-- wrap rather than part of `apply`. A challenge's Jokers are added from events
-- queued inside start_run, and apply runs before them (game.lua:2117) - so an
-- event queued from apply would go looking for the CDawg before add_joker had
-- put it in the row. One queued here lands behind those events instead.

local celesta_orbital_start_run_ref = Game.start_run
function Game:start_run(args)
    local ret = celesta_orbital_start_run_ref(self, args)

    local orbital = orbital_run()
    if orbital then
        G.E_MANAGER:add_event(Event {
            func = function()
                orbital_fuse(orbital.partner)
                return true
            end
        })
    end

    return ret
end

--- Registers one Orbital. Three challenges, one shape, one place to change it.
local function orbital_challenge(orbital)
    SMODS.Challenge {
        key = orbital.key,

        jokers = {
            -- The partner is not listed: it never enters the row. It is built as
            -- a stand-in and merged in by orbital_fuse above.
            { id = "j_celesta_cdawg", eternal = true },
        },

        restrictions = {
            banned_cards = STICKER_STRIPPERS,
        },

        rules = {
            custom = {
                -- First, because it is a warning about the two below it.
                { id = "celesta_orbital_warning" },
                { id = orbital.rule },
                { id = "celesta_orbital_prices", value = ORBITAL_PRICE },
            },
            modifiers = {},
        },
    }
end

for _, orbital in ipairs(ORBITALS) do orbital_challenge(orbital) end
