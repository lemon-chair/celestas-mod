--- DICE
---
--- A Spectral that doubles every chance in the run, for the rest of it, at the
--- cost of hand size - and costs more the second time.
---
--- The price is Raise's, which is Ectoplasm's: the running count lives on
--- G.GAME because the card is consumed on use, so a counter kept on the card
--- would start again with every fresh copy; the card prints the price the NEXT
--- use will charge rather than its starting value, the way Ectoplasm prints
--- G.GAME.ecto_minus; and no floor is invented, because vanilla will take a
--- starting hand of 8 down to 0 across four Ectoplasms and lets it.
---
--- The doubling is a wrap on SMODS.get_probability_vars, which is the single
--- funnel both the ROLL and the PRINTED odds go through - so a card that says
--- "1 in 4" says "2 in 4" the moment this is used, and rolls it. Ellie Minibot
--- is already wrapped around the same function for the same reason.

SMODS.Atlas { key = "dice", path = "dice.png", px = 71, py = 95 }

--- How many times Dice has been used this run.
local function uses_this_run()
    return (G.GAME and G.GAME.celesta_dice_uses) or 0
end

--- What the next use will cost in hand size.
local function next_cost(card)
    local extra = card.ability.extra
    if uses_this_run() < 1 then return extra.hand_size end
    return extra.hand_size_more
end

--------------------------------------------------------------------------------
-- The doubling
--------------------------------------------------------------------------------
--
-- Installed here rather than from `use`, so it is in place on a loaded save:
-- what survives a reload is the COUNT on G.GAME, and a hook that only existed
-- after a use would be gone the next time the run was opened.
--
-- Wrapped AFTER the reference for Ellie's reason - it lands after every
-- additive change, Nagzz and Oops! All 6s among them - and this file loads
-- before jokers/, so Ellie's own wrap goes outside this one and has the last
-- word where it applies. Which is the right way round: a guarantee is already
-- everything, and doubling it would be asking for more than all of them.

--- Two to the power of however many times it has been used. One use doubles,
--- two quadruples; nothing about "permanently doubles" says the second one is
--- free.
--- Doubled by multiplying rather than with `^`, which is not fussiness: `2 ^ 1`
--- is a FLOAT in Lua, and the number this returns is multiplied into a
--- numerator that is then printed on a card. "2.0 in 4" is not odds.
local function multiplier()
    local scale = 1
    for _ = 1, uses_this_run() do scale = scale * 2 end
    return scale
end

local celesta_dice_probability_ref = SMODS.get_probability_vars
function SMODS.get_probability_vars(trigger_obj, base_numerator, base_denominator,
                                    identifier, from_roll, no_mod, ...)
    local numerator, denominator = celesta_dice_probability_ref(
        trigger_obj, base_numerator, base_denominator, identifier, from_roll,
        no_mod, ...)

    -- no_mod is the caller saying nothing may touch this one, and the
    -- reference has already answered untouched.
    if no_mod then return numerator, denominator end
    local scale = multiplier()
    if scale <= 1 then return numerator, denominator end

    -- Only arithmetic, and only the kinds this can multiply. Ellie's wrap
    -- learned this from Cryptid's RNJoker, which passes a sentence as a
    -- denominator; a numerator is no safer to assume about.
    local function usable(value)
        return type(value) == "number"
            or (type(value) == "table" and getmetatable(value) ~= nil)
    end
    if not (usable(numerator) and usable(denominator)) then
        return numerator, denominator
    end

    -- Capped at the denominator, because `n in n` is how this game says
    -- certain - it is what Ellie's guarantee answers - and there is nothing
    -- past it. Four in three is not twice as certain as two in three.
    local doubled = numerator * scale
    if CelestasMod.more_than(doubled, denominator) then return denominator, denominator end
    return doubled, denominator
end

SMODS.Consumable {
    key = "dice",
    set = "Spectral",
    atlas = "dice",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    config = { extra = { hand_size = 1, hand_size_more = 2 } },

    loc_vars = function(self, info_queue, card)
        -- The price the next use will charge, read live off the run.
        return { vars = { next_cost(card) } }
    end,

    -- A modded Consumable MUST answer this: Steamodded's patch inserts the
    -- obj:can_use dispatch ahead of vanilla's chain of name checks, and a
    -- Consumable without one falls through that chain, matches nothing, and
    -- has its USE button greyed out forever. Dice has no requirement - the
    -- hand-size floor is deliberately absent, the way Ectoplasm's is.
    can_use = function(self, card)
        return true
    end,

    use = function(self, card, area, copier)
        local hand_cost = next_cost(card)

        -- Counted per application rather than per card bought: a copier makes
        -- the effect happen again, and vanilla's consumeable_usage does not
        -- count those, so it cannot be the source of truth here.
        G.GAME.celesta_dice_uses = uses_this_run() + 1

        -- Applied here rather than from the event below, for Raise's reason: a
        -- Consumable's `use` is the last thing that happens before the card is
        -- gone, and anything left in the queue behind it is at the mercy of
        -- whatever else the use set off.
        if G.hand then G.hand:change_size(-hand_cost) end

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                play_sound("gold_seal", 1.1, 0.5)
                card:juice_up(0.3, 0.5)
                card_eval_status_text(card, "extra", nil, nil, nil,
                    { message = localize("celesta_doubled"), colour = G.C.GREEN })
                return true
            end
        })
    end,
}
