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
function Card:calculate_joker(context)
    if self.ability and self.ability.set == "Joker"
        and not is_query(context) and clover_suppresses(self) then
        return
    end
    return celesta_clover_calculate_joker_ref(self, context)
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

    loc_vars = function(self)
        -- Shown through get_probability_vars so the number on the blind is the
        -- number actually rolled: with Oops! All 6s in play the text reads
        -- "2 in 2" and the blind is visibly doing nothing.
        local numerator, denominator = SMODS.get_probability_vars(
            nil, 1, CelestasMod.CLOVER_ODDS, CLOVER_SEED)
        return { vars = { numerator, denominator } }
    end,
}
