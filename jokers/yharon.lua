--- Yharon, Dragon of Rebirth [Legendary]
---
--- The Joker to Yharon's left has its Mult promoted one step up the
--- hyperoperation ladder: +Mult becomes XMult, XMult becomes ^Mult, and ^Mult
--- stays where it is. Cryptid's Caeruleum is the model and this is the same
--- machine, narrowed to one neighbour and pointed at Mult instead of Chips
--- (Cryptid-main/items/exotic.lua:1679).
---
--- Why it is a wrapper around SMODS.calculate_individual_effect rather than
--- anything a Joker normally does: the operator is not a number a Joker
--- returns, it is the KEY it returns the number under. `{ mult = 4 }` and
--- `{ x_mult = 4 }` are the same 4. Nothing downstream can tell the two apart
--- afterwards, so the only place to change it is between the Joker returning
--- its effect and the game applying it - which is exactly that function.
---
--- The marking is Caeruleum's, and it exists because that function is handed
--- the effect and the card, not the position: it has no idea what is sitting
--- next to what. So the neighbour is marked on its own ability table during
--- the `before` pass, read during scoring, and cleared on `after`.
---
--- Unlike Caeruleum this cannot stack. Caeruleum marks BOTH neighbours, so a
--- Joker between two of them is marked twice and climbs two steps; a Joker has
--- only one right-hand neighbour, so at most one Yharon can ever mark it. The
--- mark is a plain flag for that reason rather than Caeruleum's list.

--------------------------------------------------------------------------------
-- The ladder
--------------------------------------------------------------------------------
--
-- The keys are Steamodded's own, from the mult Scoring_Parameter
-- (game_object.lua:3718):
--     calculation_keys = {'mult', 'h_mult', 'mult_mod', 'x_mult', 'Xmult',
--                         'xmult', 'x_mult_mod', 'Xmult_mod'}
-- and the exponential spellings are Talisman's (main.lua:2456). Talisman is a
-- declared dependency of this mod, so ^Mult is always available; without it
-- there would be nothing above XMult to promote to.
--
-- The keys written BACK are the plain spellings - a Joker asking for `h_mult`
-- is promoted to `xmult`, not to some held-in-hand XMult that does not exist.
-- Held in hand is about WHEN the Mult is given, and that has already happened
-- by the time this runs.

local MULT_OPERATORS = {
    { operation = 1, keys = { "mult", "h_mult", "mult_mod" } },
    { operation = 2, keys = { "x_mult", "xmult", "Xmult",
                              "x_mult_mod", "Xmult_mod" } },
    -- The top rung is only reachable by a Yharon merged with a Yharon; a
    -- single one's cap sends ^Mult straight back as ^Mult.
    { operation = 3, keys = { "e_mult", "emult", "Emult_mod" } },
}

--- Indexed by the operation number, 1 = addition through 4 = tetration.
local MULT_RETURN = { "mult", "xmult", "emult", "eemult" }

--- The popup for each, by the game's own eval types: it picks the wording, the
--- colour and the sound (multhit1, multhit2, Talisman's ExponentialMult) so
--- the promoted number announces itself the way that operator always does.
local MULT_MESSAGE = { "mult", "x_mult", "e_mult", "ee_mult" }

--- The mark left on the Joker to Yharon's left. Its VALUE is the ceiling that
--- Yharon promotes up to, because that is the only thing about the marking
--- Yharon the promotion needs to know later.
local YHARON_MARK = "celesta_yharon"

--- Exponentiation on its own; tetration for a Yharon merged with a Yharon.
--- Talisman goes further still - pentation - but the card says tetration and
--- a ceiling that is not the printed one is not a ceiling.
local YHARON_CAP = 3
local YHARON_PAIR_CAP = 4

--- Resolved at load, where SMODS.current_mod is still valid.
local YHARON_KEY = "j_" .. SMODS.current_mod.prefix .. "_yharon"

--- One step up the ladder, stopping at `cap`.
--- Returns whether the key moved, the key to use, and the operation number it
--- landed on - nil when nothing moved.
function CelestasMod.yharon_new_key(key, cap)
    -- Steamodded turns Mult off entirely for scoring calculations that do not
    -- have one (SMODS.Scoring_Calculation). Promoting a key it is going to
    -- ignore would be inventing an effect out of nothing.
    if not key then return false, key end
    if SMODS.Calculation_Controls and not SMODS.Calculation_Controls.mult then
        return false, key
    end

    for _, op in ipairs(MULT_OPERATORS) do
        for _, candidate in ipairs(op.keys) do
            if key == candidate then
                local ceiling = cap or YHARON_CAP
                local raised = math.max(1, math.min(op.operation + 1, ceiling))
                -- A key already at the ceiling has not moved, whatever the
                -- table says: returning it as a promotion would announce an
                -- effect that is the same effect.
                if raised <= op.operation then return false, key end
                return true, MULT_RETURN[raised], raised
            end
        end
    end

    return false, key
end

--------------------------------------------------------------------------------
-- The promotion itself
--------------------------------------------------------------------------------
--
-- Wrapped at file scope, which puts this mod's wrapper OUTSIDE Talisman's:
-- Talisman wraps the same function while main.lua is still loading
-- (main.lua:2351), long before any mod is loaded. That is the order this needs.
-- The promoted key is passed down the chain, and `emult` is a key only
-- Talisman's wrapper knows - so it has to still be ahead of us when we hand it
-- one.

local celesta_yharon_scie_ref = SMODS.calculate_individual_effect
function SMODS.calculate_individual_effect(effect, scored_card, key, amount,
                                           from_edition, ...)
    local card = effect and (effect.card or scored_card)
    local marked = card and card.ability and card.ability[YHARON_MARK]

    -- Collected rather than shown here: the promoted effect has not been
    -- applied yet, and a message drawn before the number it is about arrives
    -- in the wrong order. Caeruleum queues its own the same way.
    local announce = nil

    if marked then
        -- The mark carries the ceiling. An older save could still hold the
        -- plain flag this used to be, and math.min against `true` is a crash.
        local cap = type(marked) == "number" and marked or nil
        local moved, new_key, raised = CelestasMod.yharon_new_key(key, cap)
        if moved then
            key = new_key
            -- The Yharon is the Joker immediately to the marked one's right -
            -- that is what the mark MEANS - so the popup goes there rather
            -- than a second one landing on the Joker that already got one.
            local dragon = nil
            for i = 1, #G.jokers.cards do
                if G.jokers.cards[i] == card then
                    dragon = G.jokers.cards[i + 1]
                    break
                end
            end
            if dragon then announce = { dragon, MULT_MESSAGE[raised], amount } end
        end
    end

    local ret = celesta_yharon_scie_ref(effect, scored_card, key, amount,
                                        from_edition, ...)

    if announce and not SMODS.no_resolve then
        card_eval_status_text(announce[1], announce[2], announce[3], percent)
    end

    return ret
end

--------------------------------------------------------------------------------
-- When it can turn up
--------------------------------------------------------------------------------
--
-- Legendaries come out of The Soul and nothing else, so this is a gate on that
-- one moment. Two ways through it:
--
--   * a Soul has already been spent this run, or
--   * the run is past Ante 6.
--
-- Souls are counted through G.GAME.consumeable_usage, which the game keeps per
-- run for exactly this kind of question, so nothing has to be tracked here and
-- nothing new goes into the save.
--
-- The count is compared against ONE rather than zero, and that is not an
-- off-by-one: set_consumeable_usage runs at the TOP of Card:use_consumeable
-- (card.lua:1372), before the Soul has created anything at all. So by the time
-- a Soul asks this question it has already counted itself, and "a Soul has
-- already been used" means a second one is in hand.

local SOUL_KEY = "c_soul"
local YHARON_ANTE = 6

--- Souls spent this run, including one currently being used.
local function souls_spent()
    local usage = G.GAME and G.GAME.consumeable_usage
    local soul = usage and usage[SOUL_KEY]
    return (soul and soul.count) or 0
end

--- True once Yharon is allowed to be found.
function CelestasMod.yharon_available()
    local ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
    if type(ante) == "number" and ante > YHARON_ANTE then return true end
    return souls_spent() > 1
end

--- How high this particular Yharon promotes.
---
--- A Yharon merged with a Yharon reaches tetration; every other card wearing
--- this centre stops at exponentiation. Asked of the CARD rather than looked
--- up as a Bind pair, because both halves of that merge run this and both have
--- to answer the same - the pair is registered in merge/bind.lua only so that
--- it has a name and a description in the Collection.
local function yharon_cap(card)
    local Bind = CelestasMod.Bind
    if Bind and Bind.is_merged and Bind.is_merged(card)
        and card.ability.celesta_bind.key == YHARON_KEY
        and card.config and card.config.center
        and card.config.center.key == YHARON_KEY then
        return YHARON_PAIR_CAP
    end
    return YHARON_CAP
end

--------------------------------------------------------------------------------
-- The Joker
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "yharon",
    atlas = "yharon",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = true,
    -- A copy sits somewhere else in the row, so it would promote a different
    -- Joker than the one this card is pointing at - which is not a copy of
    -- this effect, it is a second one.
    blueprint_compat = false, eternal_compat = true,

    in_pool = function(self, args) return CelestasMod.yharon_available() end,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    add_to_deck = function(self, card, from_debuff)
        if not from_debuff then CelestasMod.play_join_sound("j_celesta_yharon") end
    end,

    calculate = function(self, card, context)
        if context.before and context.cardarea == G.jokers then
            for i = 1, #G.jokers.cards do
                if G.jokers.cards[i] == card then
                    local left = G.jokers.cards[i - 1]
                    -- Not another Yharon: promoting one would mean promoting
                    -- the Mult it does not give.
                    if left and left.config and left.config.center
                        and left.config.center.key ~= YHARON_KEY then
                        -- The HIGHER ceiling wins rather than the last one
                        -- written, because a Yharon + Yharon merge runs this
                        -- twice: once as the host, which can see the pair, and
                        -- once as the absorbed half, whose ability table is
                        -- its own and carries no record of the merge at all.
                        -- Overwriting would let the second pass undo the pair.
                        local cap = yharon_cap(card)
                        local held = left.ability[YHARON_MARK]
                        if type(held) ~= "number" or cap > held then
                            left.ability[YHARON_MARK] = cap
                        end
                    end
                    break
                end
            end
        end

        -- Cleared off every Joker rather than off the one that was marked: a
        -- Joker sold or moved mid-hand would otherwise keep the mark into the
        -- next one, and be promoted with no Yharon beside it at all.
        if context.after and context.cardarea == G.jokers then
            for i = 1, #G.jokers.cards do
                local held = G.jokers.cards[i]
                if held.ability then held.ability[YHARON_MARK] = nil end
            end
        end
    end,
}
