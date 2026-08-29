--- RAISE
---
--- A Spectral that skips Antes at the cost of hand size, and costs more the
--- second time. Built on vanilla Ectoplasm, which is the same trade with an
--- escalating price, and on Ouija, which is the other Spectral that shrinks
--- the hand.
---
--- Ectoplasm keeps its running price on G.GAME (`ecto_minus`, lazily started
--- at 1), applies it from a deferred event, and prints the price it is about
--- to charge - `loc_vars = {G.GAME.ecto_minus or 1}`. All three of those are
--- followed here. The escalation has to live on the run rather than the card
--- either way: the card is consumed on use, so a counter on it would reset
--- with every fresh copy.
---
--- Also followed: neither Ectoplasm nor Ouija refuses to be used when the hand
--- is nearly gone. Ectoplasm will take a starting hand of 8 down to 0 across
--- four uses and vanilla lets it, so this does not invent a floor either.

SMODS.Atlas { key = "raise", path = "raise.png", px = 71, py = 95 }

--- How many times Raise has been used this run.
local function uses_this_run()
    return (G.GAME and G.GAME.celesta_raise_uses) or 0
end

--- What the next use will cost: Antes gained, hand size lost.
local function next_cost(card)
    local extra = card.ability.extra
    if uses_this_run() < 1 then
        return extra.ante, extra.hand_size
    end
    return extra.ante_more, extra.hand_size_more
end

SMODS.Consumable {
    key = "raise",
    set = "Spectral",
    atlas = "raise",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    config = { extra = { ante = 2, hand_size = 1,
                         ante_more = 3, hand_size_more = 2 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        -- The price it is about to charge, read live off the run - the way
        -- Ectoplasm prints G.GAME.ecto_minus rather than its starting value.
        -- The second line is worded as a standing fact rather than as
        -- something still to come, so it stays true after the rise.
        local antes, cost = next_cost(card)
        return { vars = { antes, cost, extra.ante_more, extra.hand_size_more } }
    end,

    can_use = function(self, card)
        -- A modded Consumable MUST answer this. Vanilla's can_use_consumeable
        -- is a chain of name checks that ends in `return false`, and
        -- Steamodded's patch inserts the obj:can_use dispatch ahead of that
        -- chain - so a Consumable with no can_use falls through it, matches
        -- nothing, and its USE button is greyed out forever.
        --
        -- Ectoplasm looks like it needs no such check only because its
        -- condition is written into that vanilla chain: "is there a Joker
        -- without an edition". Raise has no requirement of its own - the
        -- hand-size floor is deliberately absent - so it is always usable.
        return true
    end,

    use = function(self, card, area, copier)
        local antes, hand_cost = next_cost(card)

        -- Counted per application rather than per card bought: a copier makes
        -- the effect happen again, and vanilla's own consumeable_usage does
        -- not count those, so it cannot be the source of truth here.
        G.GAME.celesta_raise_uses = uses_this_run() + 1

        -- Ante immediately, hand size from an event - Ectoplasm's order, and
        -- it reads better: the Ante counter moves, then the hand shrinks.
        ease_ante(antes)

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                if G.hand then G.hand:change_size(-hand_cost) end
                play_sound("gold_seal", 0.9, 0.5)
                card:juice_up(0.3, 0.5)
                card_eval_status_text(card, "extra", nil, nil, nil,
                    { message = localize("celesta_raised"), colour = G.C.FILTER })
                return true
            end
        })
    end,
}
