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
}

--- Indexed by the operation number, 1 = addition through 3 = exponentiation.
local MULT_RETURN = { "mult", "xmult", "emult" }

--- The popup for each, by the game's own eval types: it picks the wording, the
--- colour and the sound (multhit1, multhit2, Talisman's ExponentialMult) so
--- the promoted number announces itself the way that operator always does.
local MULT_MESSAGE = { "mult", "x_mult", "e_mult" }

--- The mark left on the Joker to Yharon's left.
local YHARON_MARK = "celesta_yharon"

--- Resolved at load, where SMODS.current_mod is still valid.
local YHARON_KEY = "j_" .. SMODS.current_mod.prefix .. "_yharon"

--- One step up the ladder.
--- Returns whether the key moved, the key to use, and the operation number it
--- landed on - nil when nothing moved.
function CelestasMod.yharon_new_key(key)
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
                -- Capped at 3: exponentiation is the top of the ladder, and
                -- Talisman's tetration above it is not what the card says.
                local raised = math.max(1, math.min(op.operation + 1, 3))
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
        local moved, new_key, raised = CelestasMod.yharon_new_key(key)
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
                        left.ability[YHARON_MARK] = true
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
