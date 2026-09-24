--- Unlock conditions.
---
--- The Jokers listed here ship locked (`unlocked = false` at their declarations)
--- and are opened by something done during a run. Their names stay shown while
--- locked - see the generate_card_ui wrapper at the bottom - so the player can
--- tell which Joker a condition is for.
---
--- Two kinds of condition:
---
---   * EVENT - something the game already announces through check_for_unlock
---     (a hand's score, a win). Answered from the centre's own
---     check_for_unlock, which the game calls for every locked centre
---     (common_events.lua:1577).
---
---   * STATE - something true of the run at a moment: the deck, the slots, the
---     hands. Nothing announces most of those, and the one announcement that
---     does exist for the deck (modify_deck) fires once per card while a new
---     deck is being dealt, where a half-dealt deck looks like a single suit.
---     So these are polled from Game:update instead, which never runs in the
---     middle of start_run.
---
--- Loaded after implemented.lua and lost.lua (jokers/ loads sorted), so every
--- centre named here is already registered in SMODS.Centers.

CelestasMod.Unlocks = CelestasMod.Unlocks or {}
local Unlocks = CelestasMod.Unlocks

local PREFIX = SMODS.current_mod.prefix
local J = "j_" .. PREFIX .. "_"
local B = "b_" .. PREFIX .. "_"
local M = "m_" .. PREFIX .. "_"

local function warn(id, message)
    if CelestasMod.warn_once then CelestasMod.warn_once(id, message) end
end

--------------------------------------------------------------------------------
-- What the conditions ask
--------------------------------------------------------------------------------

local function count_cards(test)
    local count = 0
    for _, held in ipairs(G.playing_cards or {}) do
        if test(held) then count = count + 1 end
    end
    return count
end

local function any_card(test)
    for _, held in ipairs(G.playing_cards or {}) do
        if test(held) then return true end
    end
    return false
end

local function has_enhancement(key)
    return function(held) return SMODS.has_enhancement(held, key) end
end

--- Seal keys are resolved when asked: seals/seals.lua fills SEAL_KEYS after
--- the Jokers have loaded.
local function has_seal(name)
    return function(held)
        local key = CelestasMod.SEAL_KEYS and CelestasMod.SEAL_KEYS[name]
        return key ~= nil and held.seal == key
    end
end

--- Every card in the full deck printed with one and the same suit. A suitless
--- card (Stone, Limestone) is not of that suit, so it breaks the condition
--- rather than being ignored.
local function deck_is_one_suit()
    local cards = G.playing_cards or {}
    if #cards == 0 then return false end
    local suit = nil
    for _, held in ipairs(cards) do
        local printed = held.base and held.base.suit
        if not printed or SMODS.has_no_suit(held) then return false end
        if suit and printed ~= suit then return false end
        suit = printed
    end
    return true
end

--- Hands, discards and hand size each at least `extra` over what the run
--- started with. starting_params is what the deck and stake left the run with
--- before the first blind; round_resets and the hand's card limit are where
--- vouchers, Jokers and Spectrals put what they add.
local function over_start(extra)
    local start, resets = G.GAME.starting_params, G.GAME.round_resets
    if not (start and resets and G.hand and G.hand.config) then return false end
    return (resets.hands or 0) >= (start.hands or 0) + extra
        and (resets.discards or 0) >= (start.discards or 0) + extra
        and (G.hand.config.card_limit or 0) >= (start.hand_size or 0) + extra
end

--- A score can be a Talisman number past what a Lua number holds.
local function score_over(chips, threshold)
    if type(chips) == "number" then return chips > threshold end
    if chips ~= nil and to_big then return to_big(chips) > to_big(threshold) end
    return false
end

local function selected_back_key()
    local back = G.GAME and G.GAME.selected_back
    local center = back and back.effect and back.effect.center
    return center and center.key
end

local function all_jokers_merged()
    local cards = (G.jokers and G.jokers.cards) or {}
    if #cards == 0 then return false end
    local Bind = CelestasMod.Bind
    for _, held in ipairs(cards) do
        if not (Bind and Bind.is_merged(held)) then return false end
    end
    return true
end

--------------------------------------------------------------------------------
-- The conditions
--------------------------------------------------------------------------------

Unlocks.STAT_EXTRA = 2
Unlocks.SCORE = 12000
Unlocks.CONSUMABLE_SLOTS = 4
Unlocks.SUIT_COUNT = 40
Unlocks.ENHANCED_COUNT = 26

local function suit_rule(suit)
    return {
        state = function()
            return CelestasMod.count_suit_in_deck(suit) >= Unlocks.SUIT_COUNT
        end,
        vars = function() return { Unlocks.SUIT_COUNT } end,
    }
end

local function enhanced_count_rule(key)
    return {
        state = function()
            return count_cards(has_enhancement(key)) >= Unlocks.ENHANCED_COUNT
        end,
        vars = function() return { Unlocks.ENHANCED_COUNT } end,
    }
end

local function won_with(deck)
    return {
        event = function(args)
            return args.type == "win_deck" and selected_back_key() == B .. deck
        end,
    }
end

Unlocks.RULES = {
    [J .. "vantacrow_bringer"] = {
        state = function() return over_start(Unlocks.STAT_EXTRA) end,
        vars = function() return { Unlocks.STAT_EXTRA } end,
    },
    [J .. "obkatiekat"] = {
        event = function(args)
            return args.type == "chip_score" and score_over(args.chips, Unlocks.SCORE)
        end,
        vars = function() return { number_format(Unlocks.SCORE) } end,
    },
    [J .. "arielle"] = { state = deck_is_one_suit },

    [J .. "aquwa"] = won_with("rain"),
    [J .. "amalee"] = won_with("blizzard"),
    [J .. "mellowmabel"] = won_with("plaid"),
    [J .. "nana_ruru"] = {
        event = function(args) return args.type == "win" and all_jokers_merged() end,
    },

    [J .. "shoomimi"] = {
        state = function()
            local limit = G.consumeables and G.consumeables.config
                and G.consumeables.config.card_limit
            return (limit or 0) >= Unlocks.CONSUMABLE_SLOTS
        end,
        vars = function() return { Unlocks.CONSUMABLE_SLOTS } end,
    },

    [J .. "motherv3"] = { state = function() return any_card(has_enhancement(M .. "exo")) end },
    [J .. "shoto"] = { state = function() return any_card(has_enhancement(M .. "gash")) end },
    [J .. "sinder"] = { state = function() return any_card(has_enhancement(M .. "driftwood")) end },
    [J .. "limealicious"] = { state = function() return any_card(has_enhancement(M .. "limestone")) end },

    [J .. "beepers"] = { state = function() return any_card(has_seal("Foppy")) end },
    [J .. "cottontail"] = { state = function() return any_card(has_seal("Star")) end },
    [J .. "spite"] = { state = function() return any_card(has_seal("Ectoplast")) end },
    [J .. "uzuri"] = { state = function() return any_card(has_seal("Rose")) end },

    [J .. "fefe"] = suit_rule("Hearts"),
    [J .. "vexoria"] = suit_rule("Spades"),
    [J .. "ebiko"] = suit_rule("Diamonds"),
    [J .. "nihmune"] = suit_rule("Clubs"),

    [J .. "suto"] = enhanced_count_rule("m_wild"),
    [J .. "eros"] = enhanced_count_rule("m_bonus"),
    [J .. "laynalazar"] = enhanced_count_rule("m_mult"),
}

--------------------------------------------------------------------------------
-- Attaching them
--------------------------------------------------------------------------------

for key, rule in pairs(Unlocks.RULES) do
    local center = SMODS.Centers[key]
    if not center then
        warn("unlock_" .. key, "no Joker " .. key .. " to attach an unlock to")
    else
        center.check_for_unlock = function(self, args)
            if not rule.event then return false end
            local ok, met = pcall(rule.event, args or {})
            if not ok then
                warn("unlock_event_" .. key, "unlock check for " .. key .. " failed: " .. tostring(met))
                return false
            end
            return met and true or false
        end
        center.locked_loc_vars = function(self, info_queue, card)
            return { vars = rule.vars and rule.vars() or {} }
        end
    end
end

--------------------------------------------------------------------------------
-- The poll, for the STATE conditions
--------------------------------------------------------------------------------

Unlocks.POLL_SECONDS = 0.5
local poll_clock = 0

function Unlocks.poll()
    if not (G.STAGE == G.STAGES.RUN and G.GAME and G.playing_cards
            and G.jokers and G.hand and G.consumeables) then
        return
    end
    for key, rule in pairs(Unlocks.RULES) do
        local center = rule.state and G.P_CENTERS[key]
        if center and center.unlocked == false then
            local ok, met = pcall(rule.state)
            if not ok then
                warn("unlock_state_" .. key, "unlock check for " .. key .. " failed: " .. tostring(met))
            elseif met then
                -- Refuses in a seeded or challenge run, as every unlock does.
                unlock_card(center)
            end
        end
    end
end

local celesta_unlock_update_ref = Game and Game.update
if celesta_unlock_update_ref then
    function Game:update(dt)
        celesta_unlock_update_ref(self, dt)
        poll_clock = poll_clock + (dt or 0)
        if poll_clock < Unlocks.POLL_SECONDS then return end
        poll_clock = 0
        Unlocks.poll()
    end
end

--------------------------------------------------------------------------------
-- The name, shown while locked
--------------------------------------------------------------------------------
--
-- A locked centre's tooltip is titled "Locked" (common_events.lua:2814). For
-- these the Joker's own name is put back, on the first pass only - the calls
-- that pass a full_UI_table in are info_queue entries, which are titled by
-- the call that made the table.
--
-- Steamodded passes a NINTH argument, the card; everything past the stock
-- eight is forwarded untouched (see wear/tattered.lua).

local celesta_unlock_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges,
                          hide_desc, main_start, main_end, card, ...)
    local first_pass = full_UI_table == nil
    local ret = celesta_unlock_card_ui_ref(_c, full_UI_table, specific_vars, card_type,
                                           badges, hide_desc, main_start, main_end,
                                           card, ...)
    if first_pass and card_type == "Locked" and type(_c) == "table"
        and Unlocks.RULES[_c.key] and type(ret) == "table" then
        ret.name = localize { type = "name", set = "Joker", key = _c.key, nodes = {} }
    end
    return ret
end
