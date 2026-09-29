--- Decks (called "Backs" internally).
--- Any key in `config` that matches a vanilla starting param is applied for
--- free: dollars, hands, discards, hand_size, joker_slot, consumable_slot,
--- reroll_cost, ante_scaling, no_faces, ... Use `apply` for anything else.
---
--- The `decks` atlas is one row of card-sized cells, in this order:
---     0 Admin   1 Plaid   2 Ecstasy   3 Hell   4 Blizzard   5 Rain
---     6 Verdant 7 Rock    8 Sins     9 Fusion

local DECK_PREFIX = SMODS.current_mod.prefix

--- True while the run is being played on this mod's deck `name` - as the deck
--- itself, or as its Card Sleeves sleeve (items/sleeves.lua). The deck is the
--- chain vanilla's own deck checks walk (misc_functions.lua:1086); the sleeve
--- is the key Card Sleeves keeps on G.GAME, so a saved run keeps it too.
function CelestasMod.run_has_deck(name)
    if not G.GAME then return false end
    local back = G.GAME.selected_back
    local center = back and back.effect and back.effect.center
    if center and center.key == 'b_' .. DECK_PREFIX .. '_' .. name then
        return true
    end
    return G.GAME.selected_sleeve == 'sleeve_' .. DECK_PREFIX .. '_' .. name
end

--------------------------------------------------------------------------------
-- Admin Deck - the bench.
--------------------------------------------------------------------------------
--
-- Not a deck to win with; a deck to test with. It deals the exact board Evil
-- Neuro's ritual asks for and hands over the cards that reach the rest of it,
-- so the recipe, the funnel and everything the Blank Joker can learn are one
-- run away instead of twenty.
--
-- Fifty-two Steel Kings of Hearts with Red Seals. The conversion is queued
-- rather than done in `apply`, because `apply` runs BEFORE the starting deck
-- is built - the Plaid Deck below leans on the same ordering from the other
-- side - so there is nothing to convert yet at the moment this is called.
--
-- The consumable slot is raised by one because the three cards it starts with
-- do not fit in two, and a starting card that silently never arrives is worse
-- than no starting card.

local ADMIN_JOKERS = {
    'j_celesta_blank_joker',
    'j_celesta_neuro',
}

local ADMIN_CONSUMABLES = {
    'c_celesta_occult',
    -- Balatro's own spelling. The Hierophant's key is misspelled in the base
    -- game and has been since release, so the correct spelling is the one that
    -- does not exist.
    'c_heirophant',
    'c_celesta_knife',
}

SMODS.Back {
    key = 'founders',
    atlas = 'decks',
    pos = { x = 0, y = 0 },

    unlocked = true,
    discovered = true,

    config = {
        -- Three starting consumables need three slots.
        consumable_slot = 1,
    },

    loc_vars = function(self, info_queue, back)
        return { vars = { #ADMIN_JOKERS + #ADMIN_CONSUMABLES } }
    end,

    -- Runs once at the start of a run using this deck.
    apply = function(self, back)
        G.E_MANAGER:add_event(Event { func = function()
            -- Checked before it is asked for. create_card indexes the centre a
            -- forced key names without looking first (common_events.lua:2446),
            -- so one key that does not exist does not mean one missing card -
            -- it means the run does not start.
            local function deal(key, area)
                if not (G.P_CENTERS and G.P_CENTERS[key]) then
                    CelestasMod.warn_once("admin_deck_" .. tostring(key),
                        ("The Admin Deck cannot deal %s: no such centre")
                            :format(tostring(key)))
                    return
                end
                -- No start_materialize. It throws a burst of particles in the
                -- card's set colour - purple for a Tarot - and five of them
                -- going off at once on the first frame of a run is a screenful
                -- of confetti over cards the player has not even seen yet.
                -- These are the starting board, not a reward.
                SMODS.add_card { key = key, area = area }
            end

            for _, key in ipairs(ADMIN_JOKERS) do deal(key) end
            for _, key in ipairs(ADMIN_CONSUMABLES) do
                deal(key, G.consumeables)
            end

            -- Every card in the deck, turned into the one the ritual wants.
            -- Silent and immediate on all three: this is the deck being built,
            -- not fifty-two things happening to the player.
            for _, card in ipairs(G.playing_cards or {}) do
                if G.P_CARDS and G.P_CARDS.H_K then
                    card:set_base(G.P_CARDS.H_K)
                end
                if G.P_CENTERS and G.P_CENTERS.m_steel then
                    card:set_ability(G.P_CENTERS.m_steel, nil, true)
                end
                if card.set_seal then card:set_seal('Red', true, true) end
            end
            return true
        end })
    end,
}

--------------------------------------------------------------------------------
-- Plaid Deck - every suit the game has, dealt.
--------------------------------------------------------------------------------
--
-- Stars and Leaves are conversion-only: suits/shared.lua lifts their
-- prototypes out of G.P_CARDS for the duration of Game:start_run, so no deck
-- is dealt them. This is the deck that says otherwise.
--
-- It works because of the order inside start_run: the back is chosen, applied
-- (which is this `apply`), and only afterwards is the starting deck built by
-- walking G.P_CARDS. Putting the prototypes back here is early enough for the
-- build to see them, and the wrapper's own restore afterwards writes the same
-- prototypes back under the same keys, so it costs nothing.
--
-- Nothing about the count is hardcoded. The deck is however many suits are
-- registered times however many ranks, which is 6 x 13 with this mod loaded
-- and more if another mod adds a suit - the whole point being that the deck
-- holds a full set of every suit there is, not a set of six.

SMODS.Back {
    key = 'plaid',
    atlas = 'decks',
    pos = { x = 1, y = 0 },

    unlocked = true,
    discovered = true,

    config = { hand_size = 2 },

    loc_vars = function(self, info_queue, back)
        local suits, ranks = 0, 0
        for _ in pairs(SMODS.Suits or {}) do suits = suits + 1 end
        for _ in pairs(SMODS.Ranks or {}) do ranks = ranks + 1 end
        return { vars = { suits, suits * ranks, self.config.hand_size } }
    end,

    apply = function(self, back)
        CelestasMod.deal_conversion_suits()
    end,
}

--------------------------------------------------------------------------------
-- Ecstasy Deck - this mod's Jokers, and no others.
--------------------------------------------------------------------------------
--
-- G.GAME.banned_keys is the supported way to take something out of the pools:
-- get_current_pool ends every candidate with
--     if add and not G.GAME.banned_keys[v.key] then
-- and it is what a Challenge's banned_cards writes to. It covers the shop and
-- every pack and Joker-making effect with it, because they all draw from that
-- same pool, and it survives a save because G.GAME is serialised whole.
--
-- Banning rather than allow-listing is deliberate: it is the mechanism that
-- already exists, so nothing here has to know how a pool is built.
--
-- If every one of this mod's Jokers is somehow unavailable at once - all owned,
-- no Showman - get_current_pool falls back to j_joker rather than to nothing.
-- That is vanilla's empty-pool valve and it is left alone; an unwinnable shop
-- would be worse than one vanilla Joker.

-- Resolved at load: prefix_config puts every one of this mod's Jokers under
-- this prefix, and asking SMODS.current_mod at runtime is not supported.
local CELESTA_JOKER_PREFIX = 'j_' .. SMODS.current_mod.prefix .. '_'

SMODS.Back {
    key = 'ecstasy',
    atlas = 'decks',
    pos = { x = 2, y = 0 },

    unlocked = true,
    discovered = true,

    -- `consumables` is a vanilla starting param, handled by Back:apply_to_run
    -- itself. It passes each key to create_card as a FORCED key with the type
    -- hardcoded to 'Tarot', which sounds like it would refuse a Spectral - but
    -- create_card corrects itself from the centre it was handed:
    --     _type = (center.set ~= 'Default' and center.set or _type)
    -- so a Bind arrives as a Bind. Steamodded runs this deck's own `apply`
    -- before any of that, which is why banning the Jokers cannot interfere.
    config = { consumables = { CelestasMod.BIND_KEY } },

    -- No info_queue, whatever the parameter list here suggests: a Back's
    -- loc_vars is called as `back_config:loc_vars()`, with nothing after self
    -- (Back:generate_UI, back.lua:73, and Steamodded's lovely/back.toml:157).
    -- Pointing a tooltip at Bind from here indexed a nil and took the
    -- deck-select screen down.
    loc_vars = function(self, info_queue, back)
        return { vars = { CelestasMod.ECSTASY_SHOP[1].odds,
                          CelestasMod.ECSTASY_SHOP[2].odds } }
    end,

    apply = function(self, back)
        if not (G.GAME and G.GAME.banned_keys) then return end
        for key, center in pairs(G.P_CENTERS) do
            if center.set == 'Joker'
                and key:sub(1, #CELESTA_JOKER_PREFIX) ~= CELESTA_JOKER_PREFIX then
                G.GAME.banned_keys[key] = true
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- ...and the two cards it slips into the shop
--------------------------------------------------------------------------------
--
-- Neither can reach a shop on its own. Bind is a Spectral, and the shop only
-- rolls Spectrals at all once a Voucher has opened that rate up; The Soul is
-- `hidden = true`, which is what keeps it out of every pool by design - it is
-- meant to arrive from a pack. So rather than widening a pool, the card a shop
-- slot was about to hold is replaced.
--
-- create_card_for_shop is the one place a shop card is made
-- (UI_definitions.lua:742 - the shop being built, a reroll, and Buffoon-pack
-- overflow all come through it), and it already has a branch that returns a
-- forced card for the tutorial. Returning one here is a shape it supports.

--- The forced shop cards, in the order they are rolled for. `odds` is a
--- denominator: 100 is 1 in 100. Read by the deck's own loc_vars above, so the
--- printed numbers cannot drift from the rolled ones.
CelestasMod.ECSTASY_SHOP = {
    { key = CelestasMod.BIND_KEY, odds = 100, seed = 'celesta_ecstasy_bind' },
    { key = 'c_soul',             odds = 200, seed = 'celesta_ecstasy_soul' },
}

--- True while the run is being played on the Ecstasy Deck, or its sleeve.
local function on_ecstasy()
    return CelestasMod.run_has_deck('ecstasy')
end

local celesta_ecstasy_shop_ref = create_card_for_shop
function create_card_for_shop(area)
    -- Rolled per card offered, and only on this deck - so no other run's shop
    -- has its random stream shifted by the two extra pulls.
    if area == G.shop_jokers and on_ecstasy() then
        for _, entry in ipairs(CelestasMod.ECSTASY_SHOP) do
            local center = G.P_CENTERS[entry.key]
            if center and pseudorandom(pseudoseed(entry.seed)) < 1 / entry.odds then
                -- A forced key goes straight to the centre and never consults a
                -- pool, which is what gets a hidden card into a shop at all.
                local card = create_card(center.set, area, nil, nil, nil, nil,
                                         entry.key, 'sho')
                if card then
                    create_shop_card_ui(card, center.set, area)
                    return card
                end
            end
        end
    end
    return celesta_ecstasy_shop_ref(area)
end

--------------------------------------------------------------------------------
-- Hell Deck - everything at once, and less of all of it.
--------------------------------------------------------------------------------
--
-- Every line of this is a vanilla starting param, so there is no `apply`:
-- Back:apply_to_run reads each key off the config itself. They are DELTAS
-- against get_starting_params(), which is why the numbers below are negative
-- and why the description does not repeat them - it adds them to the same
-- defaults the game would, so changing a number here changes the text with it
-- rather than leaving it to say something that used to be true.
--
-- Only what it actually changes is in the config, and so only that is in the
-- description. Discards and hand size are both absent rather than set to 0:
-- the text counts what the config holds, so a 0 left behind would print a
-- live "-0" on the deck select screen, and a stat the deck does not touch has
-- no business being listed beside the ones it does.

SMODS.Back {
    key = 'hell',
    atlas = 'decks',
    pos = { x = 3, y = 0 },

    unlocked = true,
    discovered = true,

    config = {
        hands = -3,            -- 4 -> 1
        joker_slot = -1,       -- 5 -> 4
        consumable_slot = -1,  -- 2 -> 1
        no_interest = true,
    },

    loc_vars = function(self, info_queue, back)
        local base = get_starting_params()
        return { vars = {
            base.hands + self.config.hands,
            math.abs(self.config.joker_slot),
            math.abs(self.config.consumable_slot),
        } }
    end,
}

--------------------------------------------------------------------------------
-- Blizzard and Rain - the weather never lets up
--------------------------------------------------------------------------------
--
-- Two decks, one shape: a weather effect that holds for the whole run instead
-- of for the round a Joker started it in, and a shop that leans toward the
-- Jokers which care about that weather.
--
-- The weather itself is Arena.set_permanent, which is asked about separately
-- from the round-scoped one for the reason given in arena/arena.lua: a round's
-- own weather still wins while it lasts, so starting a Downpour on the
-- Blizzard Deck really does give a Downpour for that round.
--
-- The shop half is a hook on get_current_pool. That function builds a flat
-- array where every candidate contributes one slot - its key, or the string
-- 'UNAVAILABLE' - and create_card picks from it uniformly, resampling until it
-- lands on something available (common_events.lua:2449). So a key listed more
-- than once is simply drawn more often, and no other Joker's chances change in
-- kind. Appending is also the only edit that cannot break the array: the
-- positions vanilla built keep their meaning.
--
-- An extra copy is only appended for a Joker the pool ALREADY offers. The
-- base pool writes 'UNAVAILABLE' over one that is owned, banned or gated, and
-- appending its key regardless would put an owned Joker back in the shop -
-- which is exactly the check the base pool exists to make.

CelestasMod.WEATHER_WEIGHT = 4

--- Which Jokers each weather is about: they start it, or they read it.
--- Verified against jokers/implemented.lua by test_weather_decks.py rather
--- than trusted, because a Joker that learns about the weather later and is
--- not added here would simply never see the shop bonus.
CelestasMod.WEATHER_JOKERS = {
    downpour = {
        "aquwa",            -- starts one
        "rainyrentyn",      -- starts one
        "rainhoe",          -- starts one, and pays while it lasts
        "bao",              -- pays while it lasts
        "monikacinnyroll",  -- pays while it lasts
    },
    -- Freezing is the Snowstorm's other half rather than a separate thing:
    -- AmaLee raises the storm AND freezes with it, so the Jokers that live
    -- around Frozen belong to the same weather.
    snowstorm = {
        "amalee",           -- starts one, and freezes a Joker under it
        "cryogen",          -- paid every time one freezes
        "vulpixie",         -- a frozen Joker of yours never misfires
        "smugalana",        -- strips a sticker as the ice comes off
    },
}

-- Prefixed once, here at load, through the prefix the Ecstasy Deck already
-- resolved above: SMODS.current_mod is only meaningful while the mod is
-- loading and is nil by the time a shop is built.
local WEATHER_KEYS = {}
for weather, names in pairs(CelestasMod.WEATHER_JOKERS) do
    local keys = {}
    for _, name in ipairs(names) do
        keys[#keys + 1] = CELESTA_JOKER_PREFIX .. name
    end
    WEATHER_KEYS[weather] = keys
end
CelestasMod.WEATHER_JOKER_KEYS = WEATHER_KEYS

--- The prefixed keys for the weather currently held up, or nil.
local function weather_keys()
    local weather = CelestasMod.Arena and CelestasMod.Arena.permanent()
    return weather and WEATHER_KEYS[weather] or nil
end

--------------------------------------------------------------------------------
-- Verdant - nothing common grows here
--------------------------------------------------------------------------------
--
-- Two things have to be true for a Common Joker never to appear, because there
-- are two ways one is made.
--
-- Almost every Joker comes from a rarity that was ROLLED, and Steamodded rolls
-- it through SMODS.poll_rarity, which scales each rarity's weight by
-- `G.GAME[<rarity>_mod]` (src/utils.lua:838). Setting common_mod to 0 gives
-- Common a weight of zero, so the cumulative test never reaches it and it is
-- never selected. That is Steamodded's own knob rather than a hook, and it
-- rides on G.GAME, so it is saved with the run.
--
-- The other way is a caller that NAMES the rarity. Riff-raff asks for
-- create_card('Joker', G.jokers, nil, 0, ...) (card.lua:2855), and a numeric
-- rarity is read as a poll value: 0 is not above 0.7, so it means Common
-- outright and no weighting can touch it. Those are turned into Uncommon in
-- the pool hook below.
--
-- Banning every Common key instead would have been the obvious move and is
-- wrong: get_current_pool falls back to j_joker when a pool comes out empty
-- (common_events.lua:2359), and j_joker is itself Common - so a shop would
-- have filled with the one Joker the deck is meant to exclude.

--- True while the run is being played on the Verdant Deck. Read from the flag
--- the deck sets rather than from the Back, because that is what a save keeps.
local function verdant_run()
    return G.GAME and G.GAME.celesta_no_commons == true
end

SMODS.Back {
    key = "verdant",
    atlas = "decks",
    pos = { x = 6, y = 0 },

    unlocked = true,
    discovered = true,

    apply = function(self, back)
        if not G.GAME then return end
        G.GAME.celesta_no_commons = true
        -- Weight, not ban: see above.
        G.GAME.common_mod = 0
    end,
}

local celesta_deck_pool_ref = get_current_pool
function get_current_pool(_type, _rarity, _legendary, _append)
    -- Verdant, before the pool is built: a caller that named Common by number
    -- is handed Uncommon instead.
    --
    -- Only a NUMBER is rewritten. poll_rarity probes each rarity's pool by its
    -- key - the string "Common" - to find out whether it is empty
    -- (src/utils.lua:828), and answering that probe with Uncommon's pool would
    -- be telling it about the wrong rarity. A number is always a caller
    -- choosing, which is the only case this is for.
    --
    -- The replacement is the string rather than 2, because a number is read as
    -- a poll value: 2 is above 0.95, so passing it would ask for a Rare.
    if _type == "Joker" and type(_rarity) == "number" and verdant_run() then
        local named = (_legendary and 4)
            or (_rarity > 0.95 and 3) or (_rarity > 0.7 and 2) or 1
        if named == 1 then _rarity = "Uncommon" end
    end

    local pool, key = celesta_deck_pool_ref(_type, _rarity, _legendary, _append)
    if _type ~= "Joker" then return pool, key end

    local keys = weather_keys()
    if not keys then return pool, key end

    -- Guarded: a shop that cannot be built is a run that cannot continue, and
    -- a shop that is merely not weighted is a disappointment.
    local ok, err = pcall(function()
        local offered = {}
        for _, entry in ipairs(pool) do offered[entry] = true end

        for _, joker in ipairs(keys) do
            if offered[joker] then
                for _ = 2, CelestasMod.WEATHER_WEIGHT do
                    pool[#pool + 1] = joker
                end
            end
        end
    end)
    if not ok then
        CelestasMod.warn_once("weather_pool",
            "could not weight the weather Jokers: " .. tostring(err))
    end

    return pool, key
end

--- The two weather decks differ only in which weather they hold and which cell
--- of the sheet they are drawn from, so they are declared from a list.
local WEATHER_DECKS = {
    { key = "blizzard", pos = 4, weather = "snowstorm" },
    { key = "rain",     pos = 5, weather = "downpour" },
}

for _, entry in ipairs(WEATHER_DECKS) do
    SMODS.Back {
        key = entry.key,
        atlas = "decks",
        pos = { x = entry.pos, y = 0 },

        unlocked = true,
        discovered = true,

        -- Nothing else changes: no starting param is touched, so there is no
        -- config at all and Back:apply_to_run has nothing of its own to do.

        -- A Back's loc_vars is called as `back_config:loc_vars()`, with
        -- nothing after self - the same trap the Ecstasy Deck documents above.
        loc_vars = function(self, info_queue, back)
            return { vars = { CelestasMod.WEATHER_WEIGHT } }
        end,

        apply = function(self, back)
            CelestasMod.Arena.set_permanent(entry.weather)
        end,
    }
end

--------------------------------------------------------------------------------
-- Hell: Bosses the deck does not meet
--------------------------------------------------------------------------------
--
-- The Clover is out of the pool for the whole run, at every Ante. It gives
-- every card and Joker a chance to simply not trigger, and Hell's whole shape
-- is one hand an Ante with no interest to fall back on - a Blind that can
-- decline to let the hand score is not a fight this deck has an answer to,
-- and no amount of shopping makes it one.
--
-- The Pillar and Greed are barred from the FIRST Boss only. The Pillar debuffs
-- every card played this Ante and Greed charges for playing at all; meeting
-- either at Ante 1 is a run that was over before it began. From Ante 2 both
-- are back in the pool: by then there has been a shop, and the deck is meant
-- to be brutal.

-- Never, at any Ante.
local HELL_BANNED = {
    'bl_' .. SMODS.current_mod.prefix .. '_clover',
}

-- ...and these two on top of it, for the opening Boss alone.
local HELL_FIRST_BOSS_BANNED = {
    'bl_pillar',
    'bl_' .. SMODS.current_mod.prefix .. '_greed',
}

--- True while the run is being played on the Hell Deck, or its sleeve.
local function on_hell()
    return CelestasMod.run_has_deck('hell')
end

local celesta_hell_boss_ref = get_new_boss
function get_new_boss(...)
    if not (on_hell() and G.GAME.banned_keys) then
        return celesta_hell_boss_ref(...)
    end

    -- What this particular pick may not land on. The Clover always; the other
    -- two only while the opening Boss is still to come.
    local barred = {}
    for _, key in ipairs(HELL_BANNED) do barred[#barred + 1] = key end

    local resets = G.GAME.round_resets
    if (resets and resets.ante or 1) <= 1 then
        for _, key in ipairs(HELL_FIRST_BOSS_BANNED) do
            barred[#barred + 1] = key
        end
    end

    -- Banned for the length of the pick rather than re-rolled afterwards.
    -- get_new_boss already drops every key in banned_keys from the pool
    -- (common_events.lua:2745), so borrowing that leaves the choice, the
    -- per-boss use counts and the boss seed exactly where vanilla would have
    -- put them. A re-roll loop would pull from the 'boss' stream more than
    -- once and shift every later Ante's Boss along with it.
    local restore = {}
    for _, key in ipairs(barred) do
        restore[key] = G.GAME.banned_keys[key]
        G.GAME.banned_keys[key] = true
    end

    local ok, boss = pcall(celesta_hell_boss_ref, ...)

    for _, key in ipairs(barred) do
        G.GAME.banned_keys[key] = restore[key]
    end

    -- A run needs a Boss more than it needs this rule. If dropping these
    -- somehow left nothing to pick - another mod having banned the rest -
    -- take whatever vanilla would have given.
    if not ok or not boss then
        CelestasMod.warn_once("hell_boss_ban",
            "Hell had no Boss left once The Clover, The Pillar and Greed were "
            .. "taken out; letting the run have one of them")
        return celesta_hell_boss_ref(...)
    end
    return boss
end

--------------------------------------------------------------------------------
-- Rock: a deck of nothing but stone
--------------------------------------------------------------------------------
--
-- Spades and Clubs become Stone Cards, Hearts and Diamonds Limestone. Both
-- enhancements take the rank and the suit off the card they are on, so what
-- the deck really hands over is fifty-two rankless cards in two kinds - and
-- the difference between the two kinds is what the run is played on.
--
-- Done from a queued event walking G.playing_cards, which is how vanilla's
-- Checkered Deck rewrites a starting deck (back.lua:239): the deck is built
-- before the Back is applied, so the cards are there to change, and changing
-- them from inside an event keeps it behind the deal.
--
-- Suits this mod adds are left alone. A Star or a Leaf cannot be in a starting
-- deck - both are conversion-only - so naming the four vanilla suits is
-- naming every card that can be there, and a deck that somehow held one would
-- keep it rather than being asked what a Leaf is made of.

SMODS.Back {
    key = "rock",
    atlas = "decks",
    pos = { x = 7, y = 0 },

    unlocked = true,
    discovered = true,

    apply = function(self, back)
        G.E_MANAGER:add_event(Event {
            func = function()
                local stone = G.P_CENTERS.m_stone
                local limestone = G.P_CENTERS[
                    (CelestasMod.ENHANCEMENT_KEYS or {}).Limestone]
                if not (stone and limestone) then
                    CelestasMod.warn_once("rock_deck_enhancements",
                        "the Rock Deck needs the Stone and Limestone "
                        .. "enhancements, and one of them is missing")
                    return true
                end

                for _, card in pairs(G.playing_cards or {}) do
                    local suit = card.base and card.base.suit
                    local want = ((suit == "Spades" or suit == "Clubs") and stone)
                        or ((suit == "Hearts" or suit == "Diamonds") and limestone)
                        or nil
                    if want then card:set_ability(want, nil, true) end
                end
                return true
            end
        })
    end,
}

--------------------------------------------------------------------------------
-- Deck of Sins - seven counters, and the four Jokers that start them.
--------------------------------------------------------------------------------
--
-- The stats themselves are sins/sins.lua: what they count, how they level and
-- the sidebar that shows them. All this has to do is open the shop up and get
-- out of the way.
--
-- Overstock and Overstock Plus are `config.vouchers`, which Back:apply_to_run
-- redeems for free (back.lua:289) the way the Zodiac Deck gets its three. Two
-- of them take the Joker shelf from two slots to four - which is exactly the
-- four Jokers sins.lua puts in the first shop, so the offer fills the shelf
-- and leaves the player choosing between them rather than affording them all.

SMODS.Back {
    key = "sins",
    atlas = "decks",
    pos = { x = 8, y = 0 },

    unlocked = true,
    discovered = true,

    config = { vouchers = { "v_overstock_norm", "v_overstock_plus" } },

    -- A Back is a scoring target: SMODS.get_card_areas('individual') puts the
    -- selected one in the list, so every calculate_context dispatch reaches
    -- here and the deck answers contexts the way a Joker does. What each stat
    -- is worth lives in sins/effects.lua.
    calculate = function(self, back, context)
        return CelestasMod.Sins.calculate(back, context)
    end,
}

--------------------------------------------------------------------------------
-- Fusion Deck - nothing arrives alone
--------------------------------------------------------------------------------
--
-- Every Joker the run is offered is already merged with another one.
--
-- Hooked on create_card rather than on the shop, because that is the one funnel
-- the three sources share: a shop slot, a Buffoon Pack and a consumable that
-- makes a Joker - The Soul, Wraith - all arrive through it. A Joker some other
-- Joker makes comes through it too, and is fused as well; there is no way to
-- tell those apart from a consumable's, because both are created inside a
-- queued event long after the thing that asked for them has returned.
--
-- The merge itself is Bind's, told the card is new (see Bind.merge's `fresh`),
-- so the passives wait for Card:add_to_deck and the card keeps its edition.

--- A CardArea-shaped nowhere, for building a card that belongs to no area.
---
--- create_card reads the area for a position, and reads it again for three
--- questions about where the card is going: whether to discover its centre,
--- and whether to roll Eternal, Perishable or Rental onto it. A stand-in
--- should answer no to all three - a partner is not a shop card and must not
--- arrive wearing a sticker the host then inherits - and passing nowhere is
--- what says so. `nil` would not: create_card reads that as G.jokers.
local FUSION_NOWHERE = { T = { x = 0, y = 0, w = 0, h = 0 } }

--- How many times a partner is rolled before the card is left alone.
---
--- More than one because a Joker may refuse to be bound - the Blank Joker is
--- the only one in a pool that does - and bounded because the alternative to
--- finding a partner is an unfused Joker, which is a far smaller thing than a
--- shop that never finishes being built.
local FUSION_TRIES = 3

--- True while the run is being played on the Fusion Deck, or its sleeve.
local function on_fusion()
    return CelestasMod.run_has_deck("fusion")
end

--- A Joker to fuse in, or nil.
---
--- Rolled by create_card rather than picked out of a pool by hand, so it is a
--- random Joker in exactly the sense the game means: the rarity weights, the
--- banned keys, Showman and the pool flags are all the ones in force. Off its
--- own seed, so the shop's rolls land where they would have anyway.
---
--- No edition. Editions belong to the card that rolled one, and a stand-in has
--- no business bringing one to a merge for the host's to be weighed against.
local function fusion_partner()
    local saved = SMODS.bypass_create_card_edition
    SMODS.bypass_create_card_edition = true
    local ok, made = pcall(create_card, "Joker", FUSION_NOWHERE, nil, nil,
                           true, nil, nil, "celesta_fusion")
    SMODS.bypass_create_card_edition = saved
    return ok and made or nil
end

--- Merges a partner into `card`.
---
--- The partner is disposed of either way. It was built only to carry an
--- ability table, which Bind.merge copies rather than keeps, and Card's
--- constructor has already put it in G.I.CARD - so leaving it there would be a
--- card the game updates every frame for the rest of the run.
---
--- Building and removing one touches G.GAME.used_jokers twice: Card:set_ability
--- marks the centre used and Card:remove unmarks it if no copy is in play. Both
--- are wrong here. A Joker the run had already used must not be forgotten
--- because a shop card borrowed it for a moment, and a fused partner must not
--- be struck out of the pools either, or a deck that fuses every Joker offered
--- would empty them. So that one entry is put back exactly as it was found.
local function fusion_fuse(card)
    local Bind = CelestasMod.Bind
    if not (Bind and Bind.merge and Bind.can_bind(card)) then return false end

    for _ = 1, FUSION_TRIES do
        -- Taken before the partner exists, because building it is the first of
        -- the two writes: a value read afterwards is already the stand-in's
        -- own, and putting THAT back would mark the partner used for good. The
        -- whole table, because which entry matters is not known until the
        -- partner has been rolled.
        local used = G.GAME and G.GAME.used_jokers
        local before = used and copy_table(used) or {}

        local partner = fusion_partner()
        if not partner then return false end

        local center = partner.config.center
        local key = partner.config.center_key or (center and center.key)

        local merged = Bind.merge(card, partner, true)
        partner:remove()
        if used and key then used[key] = before[key] end

        if merged then return true end
    end
    return false
end

--- Set while a fusion is in progress, so the partner's own creation - and
--- anything else reached from inside one - cannot fuse in turn.
local fusing = false

local celesta_fusion_create_ref = create_card
function create_card(_type, area, ...)
    local made = celesta_fusion_create_ref(_type, area, ...)
    if fusing or not made or not on_fusion() then return made end
    if not (made.ability and made.ability.set == "Joker") then return made end

    fusing = true
    local ok, err = pcall(fusion_fuse, made)
    fusing = false
    if not ok then
        CelestasMod.warn_once("fusion_deck",
            ("The Fusion Deck could not fuse a Joker: %s"):format(tostring(err)))
    end
    return made
end

SMODS.Back {
    key = "fusion",
    atlas = "decks",
    pos = { x = 9, y = 0 },

    unlocked = true,
    discovered = true,
}
