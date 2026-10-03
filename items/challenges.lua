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
-- Challenges that unlock in order
--------------------------------------------------------------------------------
--
-- Bird Feeder I, II and III and Orbital I, II and III are each a chain: the second
-- cannot be played until the first has been won, nor the third until the second.
-- Each chain is also ONE button in the challenge list (see "one row in the
-- challenge list" below), which is why a chain's challenges are registered
-- together - the list can only join rows that sit on the same page.

--- True when the profile has won the challenge `id`. Vanilla records that when a
--- challenge run is won (state_events.lua:22).
local function challenge_beaten(id)
    local profile = G.PROFILES and G.SETTINGS and G.PROFILES[G.SETTINGS.profile]
    local progress = profile and profile.challenge_progress
    return (progress and progress.completed and progress.completed[id]) and true or false
end

--- The chains, each a list of challenge ids in the order they unlock.
local TIER_GROUPS = {}

--- id -> the id that has to be beaten first. The first of a chain has none.
local TIER_REQUIRES = {}

--- Registers a chain: each challenge after the first needs the one before it.
local function tier_group(ids)
    TIER_GROUPS[#TIER_GROUPS + 1] = ids
    for position = 2, #ids do TIER_REQUIRES[ids[position]] = ids[position - 1] end
end

--- Whether the challenge `id` may be played: the one before it, if any, is won.
--- Read by each challenge's `unlocked`, and through it by SMODS.challenge_is_unlocked.
local function tier_unlocked(id)
    local needs = TIER_REQUIRES[id]
    return needs == nil or challenge_beaten(needs)
end

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
-- Bird Feeder I, II and III - the hand is what you feed it
--------------------------------------------------------------------------------
--
-- Dokibird destroys the played cards that did not score, when exactly one of
-- them did, and gives what they were holding to the one that did - permanently.
-- Eternal, so that is not a trade taken when it suits: it is the shape of every
-- hand for the rest of the run, and the deck is what is being spent.
--
--   I    Dokibird, and nothing else
--   II   ...and an eternal LaynaLazar + Eros, already merged
--   III  ...the same, on the Ecstasy Deck's rules
--
-- II and III list LaynaLazar and Eros as two eternal Jokers and merge them once
-- they are in the row, as Tarobu and Infinity Draw do (see "a run that starts with
-- a merge already made" below). II is locked until I has been won, and III until II.
--
-- I keeps the key bird_feeder it always had, so a profile that has already won it
-- still has.

local BIRD_FEEDER_I = "c_" .. SMODS.current_mod.prefix .. "_bird_feeder"
local BIRD_FEEDER_II = "c_" .. SMODS.current_mod.prefix .. "_bird_feeder_ii"
local BIRD_FEEDER_III = "c_" .. SMODS.current_mod.prefix .. "_bird_feeder_iii"
tier_group({ BIRD_FEEDER_I, BIRD_FEEDER_II, BIRD_FEEDER_III })

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

SMODS.Challenge {
    key = "bird_feeder_ii",

    unlocked = function(self) return tier_unlocked(BIRD_FEEDER_II) end,

    jokers = {
        { id = "j_celesta_dokibird", eternal = true },
        -- Merged by start_run's queued event, LaynaLazar the host.
        { id = "j_celesta_laynalazar", eternal = true },
        { id = "j_celesta_eros", eternal = true },
    },

    restrictions = {
        banned_cards = STICKER_STRIPPERS,
    },

    rules = {
        custom = {
            { id = "celesta_start_laynalazar_eros" },
        },
        modifiers = {},
    },
}

-- III is II on the Ecstasy Deck's rules, which is what the Orbitals follow: only
-- this mod's Jokers, a Bind to start with, and a chance of a Bind or The Soul in
-- the shop. The same three calls the Orbitals make, for the same reasons (see
-- orbital_challenge below): the deck's own pool rule, registration for its shop,
-- and its starting Bind.
CelestasMod.ECSTASY_CHALLENGES[BIRD_FEEDER_III] = true

SMODS.Challenge {
    key = "bird_feeder_iii",

    unlocked = function(self) return tier_unlocked(BIRD_FEEDER_III) end,

    jokers = {
        { id = "j_celesta_dokibird", eternal = true },
        { id = "j_celesta_laynalazar", eternal = true },
        { id = "j_celesta_eros", eternal = true },
    },

    consumeables = {
        { id = "c_celesta_bind" },
    },

    restrictions = {
        banned_cards = STICKER_STRIPPERS,
    },

    apply = function(self)
        CelestasMod.ban_other_jokers()
    end,

    rules = {
        custom = {
            { id = "celesta_start_laynalazar_eros" },
            { id = "celesta_orbital_pool" },
            { id = "celesta_orbital_shop_bind",
              value = CelestasMod.ECSTASY_SHOP[1].odds },
            { id = "celesta_orbital_shop_soul",
              value = CelestasMod.ECSTASY_SHOP[2].odds },
        },
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
-- Orbital I, II and III - twice the price, and a CDawg that starts merged
--------------------------------------------------------------------------------
--
-- Three runs of one shape. Every Joker costs twice what it would, and the eternal
-- CDawg you start with is already merged with a card that widens what it retains.
-- Each also follows the Ecstasy Deck's rules: only this mod's Jokers, a Bind to
-- start with, and a chance of a Bind or The Soul in the shop.
--
-- Every rarity of this mod's Jokers can appear. The three differ only by the card
-- CDawg starts merged with:
--
--   I    Blue Card     retains Uncommons as well
--   II   Green Card    retains Rares as well
--   III  Fuchsia Card  retains Legendaries as well

--- Each Orbital: the Joker merged into CDawg.
local ORBITALS = {
    { key = "orbital_i",   partner = "j_celesta_blue_card" },
    { key = "orbital_ii",  partner = "j_celesta_green_card" },
    { key = "orbital_iii", partner = "j_celesta_fuchsia_card" },
}

--- What a Joker costs on an Orbital run, as a multiple of what it would.
local ORBITAL_PRICE = 2

--- The Orbitals by challenge id, which is what G.GAME.challenge holds.
---
--- Built at load, like PRINTER_KEY above and for the same reason: the prefix
--- comes off SMODS.current_mod, which is nil by the time any of this is asked.
---
--- Each is also registered as following the Ecstasy Deck's rules, which is what
--- puts The Soul and a Bind in its shop (items/decks.lua).
---
--- Each also knows its own id, and the three are a chain: II is locked until I has
--- been won and III until II has (see "Challenges that unlock in order").
local ORBITAL_BY_ID = {}
local ORBITAL_IDS = {}
for _, orbital in ipairs(ORBITALS) do
    local id = "c_" .. SMODS.current_mod.prefix .. "_" .. orbital.key
    orbital.id = id
    ORBITAL_BY_ID[id] = orbital
    ORBITAL_IDS[#ORBITAL_IDS + 1] = id
    CelestasMod.ECSTASY_CHALLENGES[id] = true
end
tier_group(ORBITAL_IDS)

--- The Orbital being played, or nil.
local function orbital_run()
    return ORBITAL_BY_ID[G.GAME and G.GAME.challenge]
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

    -- A run being CONTINUED already holds what it started with: its CDawg is
    -- already merged, and G.GAME.challenge is read back off the save, so without
    -- this the merge would be made a second time over the first.
    if args and args.savetext then return ret end

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

        --- Locked until the Orbital before it has been beaten. Read by
        --- SMODS.challenge_is_unlocked, which the challenge list asks of every
        --- row; a profile with everything unlocked still opens it.
        unlocked = function(self)
            return tier_unlocked(orbital.id)
        end,

        jokers = {
            -- The partner is not listed: it never enters the row. It is built as
            -- a stand-in and merged in by orbital_fuse above.
            { id = "j_celesta_cdawg", eternal = true },
        },

        -- The Ecstasy Deck's own starting Bind.
        consumeables = {
            { id = "c_celesta_bind" },
        },

        restrictions = {
            banned_cards = STICKER_STRIPPERS,
        },

        --- The Ecstasy Deck's pool rule, from the code that deck uses. After the
        --- deck's own apply and before banned_cards is written (game.lua:2111,
        --- :2117), onto a table both only ever add keys to.
        apply = function(self)
            CelestasMod.ban_other_jokers()
        end,

        rules = {
            custom = {
                -- First, because it is a warning about the rules below it.
                { id = "celesta_orbital_warning" },
                { id = "celesta_orbital_pool" },
                { id = "celesta_orbital_prices", value = ORBITAL_PRICE },
                -- Read off the deck's own table, so the screen cannot say a
                -- number the shop is not rolling.
                { id = "celesta_orbital_shop_bind",
                  value = CelestasMod.ECSTASY_SHOP[1].odds },
                { id = "celesta_orbital_shop_soul",
                  value = CelestasMod.ECSTASY_SHOP[2].odds },
            },
            modifiers = {},
        },
    }
end

for _, orbital in ipairs(ORBITALS) do orbital_challenge(orbital) end

--------------------------------------------------------------------------------
-- ...and a chain is one row in the challenge list
--------------------------------------------------------------------------------
--
-- Beat Orbital I to open Orbital II, and II to open III - and the same for Bird
-- Feeder. The list shows each chain as ONE button in three equal segments instead
-- of three rows: the first reads its own name, and each of the others reads Locked
-- until the one before it has been won, then its own name.
--
-- Built by editing the page vanilla builds rather than building it again, so the
-- row's number, its place in the page, its completed box and the focus the
-- controller snaps to all stay vanilla's. Three things change: the two rows after
-- the first are taken out, the first row's button becomes three, and its completed
-- box turns green only once all three are won.
--
-- A segment is an ordinary UIBox_button with its challenge's index as its id, so
-- clicking one runs change_challenge_description exactly as a row's button does,
-- and a locked one has no callback at all - the same way a locked row does not.

--- The total width of the button, as the other rows' is (minw = 4).
local TIER_BUTTON_WIDTH = 4

--- The G.CHALLENGES index of each challenge in a chain, in order, or nil if any
--- is missing.
local function tier_indices(group)
    local out = {}
    for _, id in ipairs(group) do
        local index = get_challenge_int_from_id(id)
        if not index or index == 0 then return nil end
        out[#out + 1] = index
    end
    return out
end

--- The challenge a row's button stands for, read off the row vanilla built: the
--- button is the second node, and UIBox_button puts the id on its inner node.
local function row_challenge_index(row)
    local button = row and row.nodes and row.nodes[2]
    local inner = button and button.nodes and button.nodes[1]
    return inner and inner.config and inner.config.id
end

--- Turns the page vanilla built into the one with `group` merged into one row.
local function merge_tier_rows(page, group)
    local indices = tier_indices(group)
    if not (indices and page and page.nodes) then return page end

    -- Where each of the chain's rows is on THIS page. Only the whole chain is
    -- merged: three rows that fall across a page break are left as three.
    local at = {}
    for position, row in ipairs(page.nodes) do
        local index = row_challenge_index(row)
        for n, wanted in ipairs(indices) do
            if index == wanted then at[n] = position end
        end
    end
    if not (at[1] and at[2] and at[3]) then return page end

    local first = page.nodes[at[1]]
    local original = first.nodes[2].nodes[1].config
    local segment_width = TIER_BUTTON_WIDTH / #indices

    local segments = {}
    local beaten = true
    for n, index in ipairs(indices) do
        local challenge = G.CHALLENGES[index]
        local unlocked = SMODS.challenge_is_unlocked(challenge, index)
        beaten = beaten and challenge_beaten(challenge.id)
        segments[n] = UIBox_button({
            id = index,
            col = true,
            label = { unlocked and localize(challenge.id, "challenge_names")
                or localize("k_locked") },
            button = unlocked and "change_challenge_description" or "nil",
            colour = unlocked and (challenge.button_colour or G.C.RED) or G.C.GREY,
            minw = segment_width,
            -- Smaller than a row's 0.4: "Orbital III" is wider than a third of the button
            -- (and the button shrinks a name that is still too long, see UIElement).
            scale = 0.3,
            minh = 0.6,
            -- The controller lands on the first, where it landed on the row.
            focus_args = n == 1 and original.focus_args or nil,
        })
    end
    first.nodes[2] = { n = G.UIT.C, config = { align = "cm", padding = 0 }, nodes = segments }

    -- The completed box is for the group: green once the last of them is won.
    local box = first.nodes[3] and first.nodes[3].nodes and first.nodes[3].nodes[1]
    if box then
        box.config.colour = beaten and G.C.GREEN or G.C.BLACK
        box.nodes = beaten and { { n = G.UIT.O, config = { object =
            Sprite(0, 0, 0.4, 0.4, G.ASSET_ATLAS["icons"], { x = 1, y = 0 }) } } } or {}
    end

    -- The other two rows are the same button now. Highest first, so the first
    -- removal does not move the second.
    table.remove(page.nodes, at[3])
    table.remove(page.nodes, at[2])
    return page
end

-- Only where there is a challenge list to edit: the test harnesses that load this file
-- whole have no G.UIDEF, and neither does anything before the game's UI exists.
local celesta_tier_list_page_ref = G.UIDEF and G.UIDEF.challenge_list_page
if celesta_tier_list_page_ref then
    function G.UIDEF.challenge_list_page(_page)
        local page = celesta_tier_list_page_ref(_page)
        for _, group in ipairs(TIER_GROUPS) do
            page = merge_tier_rows(page, group)
        end
        return page
    end
end

--------------------------------------------------------------------------------
-- Tarobu and Infinity Draw - a run that starts with a merge already made
--------------------------------------------------------------------------------
--
-- Tarobu starts with two Haruka Karibu + Haruka Karibu, Infinity Draw with one
-- Ben + Ben + Ben + Ben, and Bird Feeder II and III with a LaynaLazar + Eros. A
-- challenge can only list Jokers, so each is listed as
-- the Jokers it is made of - eternal, and negative where asked - and merged once
-- they are in the row.
--
-- Merged through Bind's own row merge rather than built as stand-ins the way an
-- Orbital's CDawg partner is, because these halves are real cards in the row:
-- the merge moves their passives across as it would for a player, and the half
-- that dissolves takes its own back, so Haruka's count and a Ben's hand size
-- come out right without any of it being written here. Matching editions are
-- never lost in a merge, so a negative pair stays negative, and Eternal is
-- inherited from every half.

--- Challenge id -> what is merged. Either copies of one Joker - `joker`, and how many
--- go into each card (2 for a pair, 4 for the quad) - or two different ones, `pair`,
--- the first of which stands as the host.
local START_MERGES = {}
START_MERGES["c_" .. SMODS.current_mod.prefix .. "_tarobu"] =
    { joker = "j_celesta_harukakaribu", size = 2 }
START_MERGES["c_" .. SMODS.current_mod.prefix .. "_infinity_draw"] =
    { joker = "j_celesta_ben", size = 4 }
START_MERGES[BIRD_FEEDER_II] = { pair = { "j_celesta_laynalazar", "j_celesta_eros" } }
START_MERGES[BIRD_FEEDER_III] = { pair = { "j_celesta_laynalazar", "j_celesta_eros" } }

--- The unmerged Jokers in the row that are `key`, left to right.
local function loose_jokers(key)
    local Bind = CelestasMod.Bind
    local out = {}
    for _, card in ipairs((G.jokers and G.jokers.cards) or {}) do
        local held = card.config and (card.config.center_key
            or (card.config.center and card.config.center.key))
        if held == key and not Bind.is_merged(card) then out[#out + 1] = card end
    end
    return out
end

--- Merges the two different Jokers of `plan.pair`, the first as the host, if both
--- are loose in the row. The leftmost of each if there is more than one.
local function merge_starting_pair(plan)
    local Bind = CelestasMod.Bind
    local host = loose_jokers(plan.pair[1])[1]
    local other = loose_jokers(plan.pair[2])[1]
    if not (host and other) then return end

    local ok, merged = pcall(Bind.merge, host, other)
    if not (ok and merged) then
        CelestasMod.warn_once("start_merge_" .. plan.pair[1] .. "_" .. plan.pair[2],
            ("A challenge could not merge its starting %s and %s: %s"):format(
                plan.pair[1], plan.pair[2], ok and "refused" or tostring(merged)))
    end
end

--- Merges every full group of `plan.size` loose Jokers into one card, the
--- leftmost of each group standing as the host.
local function merge_starting_jokers(plan)
    local Bind = CelestasMod.Bind
    if not (Bind and Bind.merge and Bind.merge_quad) then
        CelestasMod.warn_once("start_merge_no_bind",
            "A starting merge was asked for but Bind is not loaded")
        return
    end
    if plan.pair then return merge_starting_pair(plan) end

    local loose = loose_jokers(plan.joker)
    for first = 1, #loose - plan.size + 1, plan.size do
        local group = {}
        for offset = 0, plan.size - 1 do group[#group + 1] = loose[first + offset] end

        local ok, merged = pcall(function()
            if plan.size == 2 then return Bind.merge(group[1], group[2]) end
            return Bind.merge_quad(group)
        end)
        if not (ok and merged) then
            CelestasMod.warn_once("start_merge_" .. plan.joker,
                ("A challenge could not merge its starting %s: %s"):format(
                    plan.joker, ok and "refused" or tostring(merged)))
        end
    end
end

-- Queued AFTER start_run returns, for the Orbitals' reason: the challenge's
-- Jokers are added from events queued inside it, and one queued here lands
-- behind them. And not for a continued run, which already has its merges.
local celesta_start_merge_start_run_ref = Game.start_run
function Game:start_run(args)
    local ret = celesta_start_merge_start_run_ref(self, args)
    if args and args.savetext then return ret end

    local plan = START_MERGES[G.GAME and G.GAME.challenge]
    if plan then
        G.E_MANAGER:add_event(Event {
            func = function()
                merge_starting_jokers(plan)
                return true
            end
        })
    end
    return ret
end

--- Four of one Joker, each eternal and each of the edition given.
local function four_of(id, edition)
    local out = {}
    for i = 1, 4 do out[i] = { id = id, eternal = true, edition = edition } end
    return out
end

-- Tarobu: two Haruka Karibu + Haruka Karibu, so the Tarots are X4 for each, and
-- every Tarot is X16 as the run starts. The three vouchers are the Tarot ones,
-- plus the one slot for what they make.
SMODS.Challenge {
    key = "tarobu",

    -- Four, for two merged pairs.
    jokers = four_of("j_celesta_harukakaribu", "negative"),

    vouchers = {
        { id = "v_tarot_merchant" },
        { id = "v_tarot_tycoon" },
        { id = "v_crystal_ball" },
    },

    restrictions = {
        banned_cards = STICKER_STRIPPERS,
    },

    rules = {
        custom = {
            { id = "celesta_start_pairs" },
        },
        modifiers = {},
    },
}

-- Infinity Draw: Benception, kept. It draws the whole deck at the start of a
-- round, so the two vouchers that raise the hand size are the two that cannot
-- be bought.
local INFINITY_BANNED = {}
for _, banned in ipairs(STICKER_STRIPPERS) do INFINITY_BANNED[#INFINITY_BANNED + 1] = banned end
INFINITY_BANNED[#INFINITY_BANNED + 1] = { id = "v_paint_brush" }
INFINITY_BANNED[#INFINITY_BANNED + 1] = { id = "v_palette" }

SMODS.Challenge {
    key = "infinity_draw",

    jokers = four_of("j_celesta_ben"),

    restrictions = {
        banned_cards = INFINITY_BANNED,
    },

    rules = {
        custom = {
            { id = "celesta_start_quad" },
        },
        modifiers = {},
    },
}

--------------------------------------------------------------------------------
-- Wild Card Wednesday - every card in the deck is Wild
--------------------------------------------------------------------------------
--
-- Fifty-two cards, one of each rank and suit, each a Wild Card: the Nutshack's
-- deck shape (card_from_control reads s, r and e off each entry), with the whole
-- ordinary deck in place of one card repeated.

local WEDNESDAY_DECK = {}
for _, suit in ipairs({ "H", "C", "D", "S" }) do
    for _, rank in ipairs({ "2", "3", "4", "5", "6", "7", "8", "9",
                            "T", "J", "Q", "K", "A" }) do
        WEDNESDAY_DECK[#WEDNESDAY_DECK + 1] = { s = suit, r = rank, e = "m_wild" }
    end
end

SMODS.Challenge {
    key = "wild_card_wednesday",

    deck = { type = "Challenge Deck", cards = WEDNESDAY_DECK },

    rules = {
        custom = {
            { id = "celesta_wednesday_deck" },
        },
        modifiers = {},
    },
}

--------------------------------------------------------------------------------
-- Men's Shoes, Red, Orange, Yellow, Green, Blue, Purple, Pink - only these Jokers
--------------------------------------------------------------------------------
--
-- Eight challenges of one shape: a run with no starting Joker and no other rule,
-- where only a listed set of Jokers can appear - in the shop, in a pack, from a
-- consumable, anywhere the game rolls a Joker from the pool.
--
-- Done the way the Ecstasy Deck restricts its own pool, which is to ban what is
-- NOT wanted rather than to list what is. banned_cards would put every one of the
-- hundreds of Jokers outside the list on the challenge screen, so it is the
-- challenge's `apply` that writes G.GAME.banned_keys instead: after the deck's own
-- and before banned_cards is read (game.lua:2111, :2117), onto a table both only
-- ever add keys to.
--
-- A Lost Soul's Joker is allowed exactly when the Joker it was made from is. The
-- list of which is Lost.CONVERSIONS (jokers/lost.lua), read when the run starts
-- rather than copied here, so a conversion added later follows the rule without
-- this file hearing about it.
--
-- Every pool has Commons, Uncommons and Rares to roll, so the shop never has to
-- fall back on vanilla's answer to an empty pool (a plain Joker, which ignores the
-- ban list). Legendaries are only ever rolled by The Soul, and Purple has none:
-- there The Soul can give that fallback.

--- The Jokers each pool allows, as the challenge lists them: this mod's by
--- j_celesta_<key>, vanilla's by their own.
local POOL_JOKERS = {
    mens_shoes = {
        "j_celesta_arar", "j_celesta_shoto", "j_celesta_papamutt", "j_celesta_cdawg",
        "j_celesta_bluto", "j_celesta_nagzz", "j_celesta_jaws", "j_celesta_liffeh",
        "j_celesta_baddaboom", "j_celesta_jowol", "j_celesta_heavenlyfather",
        "j_celesta_axialmatt", "j_celesta_bricky", "j_celesta_cyyuvtuber", "j_celesta_ray",
        "j_celesta_nostro", "j_celesta_rtgame", "j_celesta_ariesakana", "j_celesta_taehoongie",
        "j_celesta_rubensargasm", "j_celesta_unnamed", "j_celesta_occi", "j_celesta_shiabun",
        "j_celesta_shaoanvt", "j_celesta_vantacrow_bringer", "j_celesta_lordaethelstan",
        "j_celesta_kuro", "j_celesta_boosfer",
    },
    red = {
        "j_lusty_joker", "j_credit_card", "j_raised_fist", "j_even_steven", "j_scary_face",
        "j_hack", "j_red_card", "j_superposition", "j_madness", "j_rocket", "j_baron",
        "j_drunkard", "j_reserved_parking", "j_gift", "j_popcorn", "j_bloodstone", "j_matador",
        "j_family", "j_tribe", "j_chicot", "j_celesta_xm05_thanatos", "j_celesta_zentreya",
        "j_celesta_berrycrepe", "j_celesta_laynalazar", "j_celesta_overezeggs",
        "j_celesta_fefe", "j_celesta_neuro", "j_celesta_jowol", "j_celesta_smugalana",
        "j_celesta_heavenlyfather", "j_celesta_beribug", "j_celesta_fenari",
        "j_celesta_slimegod", "j_celesta_pipi", "j_celesta_saiiren", "j_celesta_yoclesh",
        "j_celesta_fireonirei", "j_celesta_adfree", "j_celesta_nanoless", "j_celesta_kuro",
        "j_celesta_angelsteps", "j_celesta_lucypyre", "j_celesta_calamitas",
        "j_celesta_malliesprout",
    },
    orange = {
        "j_greedy_joker", "j_vagabond", "j_juggler", "j_erosion", "j_diet_cola", "j_trousers",
        "j_campfire", "j_flower_pot", "j_yorick", "j_burnt", "j_bootstraps",
        "j_shoot_the_moon", "j_celesta_blessed_phoenix_egg", "j_celesta_yharon",
        "j_celesta_demenishki", "j_celesta_smugalana", "j_celesta_axialmatt",
        "j_celesta_birdyovo", "j_celesta_clover", "j_celesta_ebiko", "j_celesta_sinder",
        "j_celesta_taehoongie", "j_celesta_glowypumpkin", "j_celesta_sonneflower",
        "j_celesta_smittenseraph", "j_celesta_maplechicken", "j_celesta_buffpup",
        "j_celesta_auteru", "j_celesta_obkatiekat", "j_celesta_squchan",
        "j_celesta_mellowmabel", "j_celesta_glassesjournal", "j_celesta_lordaethelstan",
        "j_celesta_calamitas",
    },
    yellow = {
        "j_gros_michel", "j_cavendish", "j_ride_the_bus", "j_todo_list", "j_shortcut",
        "j_midas_mask", "j_golden", "j_smiley", "j_ticket", "j_rough_gem", "j_certificate",
        "j_brainstorm", "j_hit_the_road", "j_cartomancer", "j_celesta_kokonuts",
        "j_celesta_arielle", "j_celesta_yuzu", "j_celesta_baddaboom", "j_celesta_jaws",
        "j_celesta_sunnysplosion", "j_celesta_kirana", "j_celesta_sigrid_bird",
        "j_celesta_sansin", "j_celesta_henya", "j_celesta_nana_ruru", "j_celesta_shenpai",
        "j_celesta_cerbervt", "j_celesta_rubensargasm", "j_celesta_minikomew",
        "j_celesta_grimmi", "j_celesta_suko", "j_celesta_jummy", "j_celesta_chrchie",
        "j_celesta_dooby", "j_celesta_nimi", "j_celesta_dokibird",
    },
    green = {
        "j_ceremonial", "j_chaos", "j_pareidolia", "j_green_joker", "j_blackboard",
        "j_turtle_bean", "j_to_the_moon", "j_baseball", "j_flash", "j_troubadour", "j_oops",
        "j_trio", "j_perkeo", "j_celesta_green_card", "j_celesta_boosfer", "j_celesta_ben",
        "j_celesta_kumi", "j_celesta_maya", "j_celesta_crelly", "j_celesta_rosedoodle",
        "j_celesta_limealicious", "j_celesta_pandabearlily", "j_celesta_x3dustco",
        "j_celesta_liffeh", "j_celesta_kloekroc", "j_celesta_harukakaribu",
        "j_celesta_heavenlyfather", "j_celesta_vedal", "j_celesta_ray", "j_celesta_suto",
        "j_celesta_kael", "j_celesta_kairyucrocodile", "j_celesta_piapiufo",
        "j_celesta_augustanomoly", "j_celesta_radiaactive", "j_celesta_rynxryn",
        "j_celesta_juniperactias", "j_celesta_alluux", "j_celesta_cupidyle", "j_celesta_momo",
    },
    blue = {
        "j_gluttenous_joker", "j_mystic_summit", "j_fibonacci", "j_supernova", "j_odd_todd",
        "j_splash", "j_blue_joker", "j_superposition", "j_ice_cream", "j_seance", "j_cloud_9",
        "j_luchador", "j_baseball", "j_selzer", "j_trousers", "j_castle", "j_walkie_talkie",
        "j_onyx_agate", "j_flower_pot", "j_blueprint", "j_seeing_double", "j_order", "j_duo",
        "j_triboulet", "j_satellite", "j_celesta_blue_card", "j_celesta_eidolonwyrm",
        "j_celesta_cryogen", "j_celesta_shylily", "j_celesta_spite", "j_celesta_beepers",
        "j_celesta_aquwa", "j_celesta_yuy_ix", "j_celesta_shoomimi", "j_celesta_bao",
        "j_celesta_yomiquinnely", "j_celesta_saruei", "j_celesta_bearthewitch",
        "j_celesta_moomerrily", "j_celesta_bluto", "j_celesta_amalee", "j_celesta_vulpixie",
        "j_celesta_mintfantome", "j_celesta_bricky", "j_celesta_cyyuvtuber",
        "j_celesta_radicalmari", "j_celesta_monikacinnyroll", "j_celesta_milky",
        "j_celesta_rinpenrose", "j_celesta_fream", "j_celesta_eros", "j_celesta_nihmune",
        "j_celesta_nana_ruru", "j_celesta_vienna", "j_celesta_cosmic", "j_celesta_ariesakana",
        "j_celesta_yokasiri", "j_celesta_geega", "j_celesta_fufu", "j_celesta_isaa",
        "j_celesta_kourra", "j_celesta_occi", "j_celesta_silvervale", "j_celesta_froot",
        "j_celesta_mogu",
    },
    purple = {
        "j_wrathful_joker", "j_8_ball", "j_sixth_sense", "j_fortune_teller", "j_arrowhead",
        "j_celesta_uzuri", "j_celesta_megalodon", "j_celesta_chacha", "j_celesta_onigiri",
        "j_celesta_michi", "j_celesta_shoto", "j_celesta_aicandii", "j_celesta_jaxvtuber",
        "j_celesta_hannahhyrule", "j_celesta_kyaree", "j_celesta_rtgame", "j_celesta_nostro",
        "j_celesta_vexoria", "j_celesta_nihmune", "j_celesta_cerbervt",
        "j_celesta_projektmelody", "j_celesta_pristinezero", "j_celesta_rainhoe",
        "j_celesta_shaoanvt", "j_celesta_shiabun", "j_celesta_nyanners",
        "j_celesta_itsdeadlyboop", "j_celesta_nekrolina", "j_celesta_moopybuns",
        "j_celesta_squchan", "j_celesta_astrum_aureus", "j_celesta_froot", "j_celesta_kiri",
        "j_celesta_elara", "j_celesta_fleshy", "j_celesta_nicoviras", "j_celesta_snuffy",
        "j_celesta_hime",
    },
    pink = {
        "j_four_fingers", "j_ramen", "j_trading", "j_celesta_froggyloch",
        "j_celesta_fuchsia_card", "j_celesta_kokonuts", "j_celesta_cottontail",
        "j_celesta_motherv3", "j_celesta_ironmouse", "j_celesta_meicha",
        "j_celesta_pomatomaster", "j_celesta_dejavudea", "j_celesta_camila",
        "j_celesta_spongeybuns", "j_celesta_chibidoki", "j_celesta_mariyume",
        "j_celesta_el_xox", "j_celesta_fream", "j_celesta_mooni", "j_celesta_matarakan",
        "j_celesta_trickywi", "j_celesta_rainyrentyn", "j_celesta_snapscube", "j_celesta_giwi",
        "j_celesta_suko", "j_celesta_toma", "j_celesta_pheromoan", "j_celesta_torioriane",
        "j_celesta_lucia", "j_celesta_urschleim", "j_celesta_tobs",
    },
}

--- Every Joker a pool allows: the ones it lists, and the Lost form of each of those.
local function pool_allowed(listed)
    local allowed = {}
    for _, key in ipairs(listed) do allowed[key] = true end

    local conversions = CelestasMod.Lost and CelestasMod.Lost.CONVERSIONS
    for base, lost in pairs(conversions or {}) do
        if allowed[base] then allowed[lost] = true end
    end
    return allowed
end

--- Bans every Joker that is not in `listed` or the Lost form of one that is.
function CelestasMod.ban_jokers_outside(listed)
    if not (G.GAME and G.GAME.banned_keys) then return end
    local allowed = pool_allowed(listed)
    for key, center in pairs(G.P_CENTERS) do
        if center.set == "Joker" and not allowed[key] then
            G.GAME.banned_keys[key] = true
        end
    end
end

--- The rule line each pool shows. A colour names itself - "Only Red Jokers appear
--- (44)" - which takes a line of its own per colour, as a rule is rendered from one
--- loc key and has room for one number. Men's Shoes is not a colour and keeps the
--- plain line.
local function pool_rule_id(key)
    if key == "mens_shoes" then return "celesta_pool_only" end
    return "celesta_pool_" .. key
end

--- Registers one pool challenge. Eight challenges, one shape, one place to change it.
local function pool_challenge(key)
    local listed = POOL_JOKERS[key]
    SMODS.Challenge {
        key = key,

        apply = function(self)
            CelestasMod.ban_jokers_outside(listed)
        end,

        rules = {
            custom = {
                -- The count rather than the names: eight lists of up to sixty-five
                -- would not fit the Rules tab.
                { id = pool_rule_id(key), value = #listed },
            },
            modifiers = {},
        },
    }
end

for _, key in ipairs({ "mens_shoes", "red", "orange", "yellow", "green", "blue", "purple", "pink" }) do
    pool_challenge(key)
end

--- Read by the tests, which ask what a pool allows rather than restating it.
CelestasMod.CHALLENGE_POOLS = POOL_JOKERS

--------------------------------------------------------------------------------
-- Starboard - one eternal Boosfer, and the one slot it fills
--------------------------------------------------------------------------------
--
-- A modifier is an absolute value (see the top of this file), so "four fewer Joker
-- slots" is joker_slots = 1: vanilla's five, less four. Boosfer is eternal and takes
-- that slot, so there is nowhere to put a second Joker at all.
--
-- Nothing else is asked for, so nothing else is here: no banned Jokers, so the
-- three that take an Eternal off (see STICKER_STRIPPERS) can still take Boosfer's.

SMODS.Challenge {
    key = "starboard",

    jokers = {
        { id = "j_celesta_boosfer", eternal = true },
    },

    rules = {
        custom = {},
        modifiers = {
            -- Absolute, not a delta: vanilla starts on 5, so four fewer is 1.
            { id = "joker_slots", value = 1 },
        },
    },
}

--------------------------------------------------------------------------------
-- Leaf Litter - the deck is two sets of Leaf cards
--------------------------------------------------------------------------------
--
-- Twenty-six cards: every rank of the Leaf suit, twice, and no other suit.
--
-- Leaf is conversion-only: suits/shared.lua lifts its prototypes out of G.P_CARDS
-- for the whole of Game:start_run so that no deck is dealt it, and a challenge deck
-- looks each card up there by `<suit>_<rank>`. A deck that lists Leaf cards would
-- therefore be looking up cards that are not there. A challenge's `apply` runs
-- after the deck's own and before the starting deck is built (game.lua:2117, then
-- :2407), which is the window the Plaid Deck uses to put them back - and this is
-- the same call.
--
-- Leaf's card_key is L, written into every save as part of its card ids and never
-- changed (suits/leaf.lua).

local LEAF_CARD_KEY = "L"

local LEAF_LITTER_DECK = {}
for _ = 1, 2 do
    for _, rank in ipairs({ "2", "3", "4", "5", "6", "7", "8", "9",
                            "T", "J", "Q", "K", "A" }) do
        LEAF_LITTER_DECK[#LEAF_LITTER_DECK + 1] = { s = LEAF_CARD_KEY, r = rank }
    end
end

SMODS.Challenge {
    key = "leaf_litter",

    deck = { type = "Challenge Deck", cards = LEAF_LITTER_DECK },

    apply = function(self)
        CelestasMod.deal_conversion_suits()
    end,

    rules = {
        custom = {
            { id = "celesta_leaf_litter_deck" },
        },
        modifiers = {},
    },
}
