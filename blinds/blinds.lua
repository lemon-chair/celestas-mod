--- BOSS BLINDS
---
--- Chip art is built by tools/gen_blinds.py. Blind chips are animated: the
--- vanilla atlas is registered with frames = 21 at 34x34, so a blind's atlas
--- must match that shape or the chip renders wrong.
---
--- Keys get the `bl` class prefix plus the mod prefix, so `clover` registers
--- as bl_celesta_clover and reads its text from descriptions.Blind.

CelestasMod.CLOVER_ODDS = 2

local CLOVER_SEED = "celesta_clover"
-- Resolved at load: SMODS.current_mod is only valid while the mod is loading,
-- and the hooks below run for the rest of the session.
local CLOVER_KEY = "bl_" .. SMODS.current_mod.prefix .. "_clover"

--- True while The Clover is the blind being played.
--- Read fresh each time rather than latched: a blind can be disabled mid-round
--- (Chicot, a Voucher), and a latched flag would keep suppressing after it.
local function clover_active()
    local blind = G.GAME and G.GAME.blind
    if not (blind and blind.config and blind.config.blind) then return false end
    if blind.disabled then return false end
    return blind.config.blind.key == CLOVER_KEY
end

-- Set while the roll itself is running. SMODS.pseudorandom_probability fires
-- mod_probability and fix_probability, and both re-enter every joker - which
-- comes straight back into the hook below. Without this the first roll never
-- finishes.
local clover_rolling = false

-- One decision per object per play or discard. hands_left and discards_left
-- are both decremented before anything is evaluated, so this is stable across
-- one event and changes the moment the next begins.
local decisions = setmetatable({}, { __mode = "k" })

local function event_id()
    local round = G.GAME and G.GAME.current_round
    if not round then return "?" end
    return table.concat({ tostring(G.GAME.round), tostring(round.hands_left),
                          tostring(round.discards_left) }, "/")
end

--- True when this card or joker is stopped from triggering for this event.
---
--- The roll goes through SMODS.pseudorandom_probability rather than a plain
--- pseudorandom, and that is the whole point of the blind: the helper runs the
--- mod_probability pass, so anything that edits listed odds edits this one
--- too. Oops! All 6s doubles the numerator, which turns 1 in 2 into 2 in 2 and
--- cancels the blind outright.
---
--- Rolled once per object per event rather than per trigger. Per trigger would
--- mean a probability lookup - two full evaluation passes - on every context
--- every joker sees, which is precisely what once took a hand from 4k
--- calculations to 88k and locked the game up.
local function clover_suppresses(obj)
    if clover_rolling or not clover_active() then return false end

    local id = event_id()
    local cached = decisions[obj]
    if cached and cached.id == id then return cached.suppressed end

    clover_rolling = true
    local ok, triggered = pcall(SMODS.pseudorandom_probability, obj,
        CLOVER_SEED, 1, CelestasMod.CLOVER_ODDS, CLOVER_SEED)
    clover_rolling = false

    -- A roll that errored lets the object through: a boss that silently
    -- switches everything off is far worse than one that misses a card.
    local suppressed = ok and not triggered or false
    decisions[obj] = { id = id, suppressed = suppressed }
    return suppressed
end

-- Getter contexts ask a question rather than producing an effect. Suppressing
-- those would corrupt display and probability lookups rather than stopping a
-- trigger - and mod_probability in particular is how the roll itself is
-- modified, so answering it wrong would break the Oops! interaction.
local function is_query(context)
    return context.mod_probability or context.fix_probability
        or context.check_enhancement or context.check_eternal
        or context.retrigger_joker_check
end

local celesta_clover_calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context, ...)
    if self.ability and self.ability.set == "Joker"
        and not is_query(context) and clover_suppresses(self) then
        return
    end
    return celesta_clover_calculate_joker_ref(self, context, ...)
end

local celesta_clover_eval_card_ref = eval_card
function eval_card(card, context)
    -- Only the scoring pass over played cards. A card held in hand arrives
    -- with cardarea == G.hand and one played outside the poker hand as the
    -- string 'unscored'; neither is a trigger to stop. extra_enhancement is
    -- excluded because quantum enhancements re-enter for the same trigger.
    if context and context.main_scoring and context.cardarea == G.play
        and not context.extra_enhancement and clover_suppresses(card) then
        return {}, {}
    end
    return celesta_clover_eval_card_ref(card, context)
end

SMODS.Blind {
    key = "clover",
    atlas = "blind_clover",
    pos = { x = 0, y = 0 },

    -- Standard boss payout and score requirement.
    dollars = 5,
    mult = 2,
    boss = { min = 1, max = 10 },
    boss_colour = HEX("4C9A2A"),
    discovered = true,

    -- Blind text goes through TWO hooks, and supplying only one leaves the
    -- other printing "nil" for every placeholder. loc_vars feeds the text on
    -- the Blind itself once it is in play; collection_loc_vars feeds the
    -- popup - the panel on the Blind select screen and the entry in the
    -- collection - which otherwise falls back to `self.vars`, and SMODS.Blind
    -- defaults that to an empty table. Steamodded's own take_ownership of The
    -- Wheel defines both for this reason.
    loc_vars = function(self)
        -- Shown through get_probability_vars so the number on the blind is the
        -- number actually rolled: with Oops! All 6s in play the text reads
        -- "2 in 2" and the blind is visibly doing nothing.
        local numerator, denominator = SMODS.get_probability_vars(
            nil, 1, CelestasMod.CLOVER_ODDS, CLOVER_SEED)
        return { vars = { numerator, denominator } }
    end,

    -- The collection is browsed with no run loaded, so the printed odds are
    -- the base ones rather than whatever a run would modify them to. The Wheel
    -- answers its own collection entry the same way.
    collection_loc_vars = function(self)
        return { vars = { 1, CelestasMod.CLOVER_ODDS } }
    end,
}

--------------------------------------------------------------------------------
-- The Greed - hands and discards cost money
--------------------------------------------------------------------------------
--
-- Discards go through vanilla's own machinery. The Golden Needle challenge
-- charges for a discard with `G.GAME.modifiers.discard_cost`, which
-- state_events.lua spends right where the discard is counted:
--     if G.GAME.modifiers.discard_cost then
--         ease_dollars(-G.GAME.modifiers.discard_cost)
--     end
-- Setting that for the duration is better than charging by hand: it is
-- deducted at exactly the moment vanilla deducts it, and it skips the discards
-- a Joker forces, which are not the player's to pay for.
--
-- There is no `hand_cost` to match it - Golden Needle only charges for
-- discards - so the hand is charged from press_play, which vanilla calls once
-- per played hand and returns from early when the Blind is disabled.

CelestasMod.GREED_COST = 2

--- Remembers whatever discard cost was already in force and installs ours.
--- A challenge can be charging for discards too, and this must not become the
--- way to cancel it. `false` records "there was none" - nil would read as
--- "nothing saved yet" and let a second call overwrite the real answer with
--- our own value.
local function greed_take_over()
    if G.GAME.celesta_greed_prior == nil then
        G.GAME.celesta_greed_prior = G.GAME.modifiers.discard_cost or false
    end
    G.GAME.modifiers.discard_cost = CelestasMod.GREED_COST
end

--- Puts back whatever was there before. Safe to call twice: a Blind that is
--- disabled and then defeated gets both hooks.
local function greed_hand_back()
    if G.GAME.celesta_greed_prior == nil then return end
    G.GAME.modifiers.discard_cost = G.GAME.celesta_greed_prior or nil
    G.GAME.celesta_greed_prior = nil
end

SMODS.Blind {
    key = "greed",
    atlas = "blind_greed",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    boss = { min = 1, max = 10 },
    boss_colour = HEX("C9A227"),
    discovered = true,

    -- Both hooks, for the reason spelled out on The Clover above.
    loc_vars = function(self)
        return { vars = { CelestasMod.GREED_COST } }
    end,

    collection_loc_vars = function(self)
        return { vars = { CelestasMod.GREED_COST } }
    end,

    set_blind = function(self)
        greed_take_over()
    end,

    disable = function(self)
        greed_hand_back()
    end,

    defeat = function(self)
        greed_hand_back()
    end,

    press_play = function(self)
        -- vanilla's Blind:press_play returns before this when the Blind is
        -- disabled, so there is nothing to check here.
        ease_dollars(-CelestasMod.GREED_COST)
    end,
}

--------------------------------------------------------------------------------
-- Boss Blinds added to a run already in progress
--------------------------------------------------------------------------------
--
-- G.GAME.bosses_used is built once, when a run starts, from the Blinds that
-- exist at that moment. get_new_boss marks every eligible Blind with `true`,
-- then replaces those marks with use counts by walking bosses_used:
--
--     for k, v in pairs(G.GAME.bosses_used) do
--         if eligible_bosses[k] then eligible_bosses[k] = v ... end
--     end
--     for k, v in pairs(eligible_bosses) do
--         if eligible_bosses[k] > min_use then eligible_bosses[k] = nil end
--     end
--
-- A Blind the run has never heard of is not in bosses_used, so its mark stays
-- `true` and the second loop compares a boolean with a number. That is a crash
-- on picking a Blind, in any run that was started before the Blind was added -
-- which is every run a player already has going when this mod updates.
--
-- Cryptid repairs the same thing and says so in a comment, but does it AFTER
-- calling through, so the call it is protecting has already thrown. This runs
-- before. Load order puts this mod ahead of Cryptid, so this wrapper is the
-- one Cryptid captured and it goes first either way.
--
-- Zero is what the count would have been had the Blind existed at run start.

local celesta_boss_backfill_ref = get_new_boss
function get_new_boss(...)
    if G.GAME and G.P_BLINDS then
        -- Created rather than skipped when it is missing entirely. An empty
        -- bosses_used is the same crash as a partial one: with no counts to
        -- replace them, EVERY mark stays a boolean and the comparison throws
        -- on the first Blind it reaches.
        if type(G.GAME.bosses_used) ~= "table" then G.GAME.bosses_used = {} end
        local added = 0
        for key, center in pairs(G.P_BLINDS) do
            if center.boss and G.GAME.bosses_used[key] == nil then
                G.GAME.bosses_used[key] = 0
                added = added + 1
            end
        end
        if added > 0 then
            CelestasMod.warn_once("boss_backfill",
                ("Filled in bosses_used for %d Blind(s) this run had not seen")
                    :format(added))
        end
    end
    return celesta_boss_backfill_ref(...)
end
