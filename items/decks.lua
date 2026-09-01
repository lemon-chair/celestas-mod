--- Decks (called "Backs" internally).
--- Any key in `config` that matches a vanilla starting param is applied for
--- free: dollars, hands, discards, hand_size, joker_slot, consumable_slot,
--- reroll_cost, ante_scaling, no_faces, ... Use `apply` for anything else.
---
--- The `decks` atlas is one row of card-sized cells, in this order:
---     0 Founder's   1 Plaid   2 Ecstasy   3 Hell

SMODS.Back {
    key = 'founders',
    atlas = 'decks',
    pos = { x = 0, y = 0 },

    unlocked = true,
    discovered = true,

    config = {
        dollars = 10,     -- +$10 on top of the usual $4
        joker_slot = -1,  -- ...but one fewer Joker slot
    },

    loc_vars = function(self, info_queue, back)
        return { vars = { self.config.dollars, math.abs(self.config.joker_slot) } }
    end,

    -- Runs once at the start of a run using this deck.
    apply = function(self, back)
        G.E_MANAGER:add_event(Event { func = function()
            -- Was j_celesta_spark; that placeholder is disabled, so this now
            -- hands out a real Joker instead.
            local joker = SMODS.add_card { key = 'j_celesta_arar' }
            if joker then joker:start_materialize() end
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
        hand_size = -1,        -- 8 -> 7
        joker_slot = -1,       -- 5 -> 4
        consumable_slot = -1,  -- 2 -> 1
        no_interest = true,
    },

    loc_vars = function(self, info_queue, back)
        local base = get_starting_params()
        return { vars = {
            base.hands + self.config.hands,
            base.discards + self.config.discards,
            math.abs(self.config.hand_size),
            math.abs(self.config.joker_slot),
            math.abs(self.config.consumable_slot),
        } }
    end,
}
