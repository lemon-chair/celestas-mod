--- Decks (called "Backs" internally).
--- Any key in `config` that matches a vanilla starting param is applied for
--- free: dollars, hands, discards, hand_size, joker_slot, consumable_slot,
--- reroll_cost, ante_scaling, no_faces, ... Use `apply` for anything else.
---
--- The `decks` atlas is one row of card-sized cells, in this order:
---     0 Admin   1 Plaid   2 Ecstasy   3 Hell

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

local ECSTASY_KEY = 'b_' .. SMODS.current_mod.prefix .. '_ecstasy'

--- True while the run is being played on the Ecstasy Deck.
--- The same chain vanilla's own deck checks walk (misc_functions.lua:1086).
local function on_ecstasy()
    local back = G.GAME and G.GAME.selected_back
    return back and back.effect and back.effect.center
        and back.effect.center.key == ECSTASY_KEY
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
-- The displayed hand and discard counts are the base-stake ones. From Gold
-- stake up the game takes a further discard before any deck is applied, so the
-- real number is one lower - which is true of every vanilla deck's description
-- too, and is left reading the same way they do.

SMODS.Back {
    key = 'hell',
    atlas = 'decks',
    pos = { x = 3, y = 0 },

    unlocked = true,
    discovered = true,

    config = {
        hands = -3,            -- 4 -> 1
        discards = -1,         -- 3 -> 2
        joker_slot = -1,       -- 5 -> 4
        consumable_slot = -1,  -- 2 -> 1
        no_interest = true,
    },

    loc_vars = function(self, info_queue, back)
        local base = get_starting_params()
        return { vars = {
            base.hands + self.config.hands,
            base.discards + self.config.discards,
            math.abs(self.config.joker_slot),
            math.abs(self.config.consumable_slot),
        } }
    end,
}

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

local HELL_KEY = 'b_' .. SMODS.current_mod.prefix .. '_hell'

-- Never, at any Ante.
local HELL_BANNED = {
    'bl_' .. SMODS.current_mod.prefix .. '_clover',
}

-- ...and these two on top of it, for the opening Boss alone.
local HELL_FIRST_BOSS_BANNED = {
    'bl_pillar',
    'bl_' .. SMODS.current_mod.prefix .. '_greed',
}

--- True while the run is being played on the Hell Deck.
local function on_hell()
    local back = G.GAME and G.GAME.selected_back
    return back and back.effect and back.effect.center
        and back.effect.center.key == HELL_KEY
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
