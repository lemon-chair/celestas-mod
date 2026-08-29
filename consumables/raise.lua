--- RAISE
---
--- A Spectral that skips Antes at the cost of hand size, and costs more the
--- second time. The escalation is per RUN, not per card - the card is consumed
--- on use, so a counter on it would reset with every fresh copy.
---
--- The count lives on G.GAME because that is what the run save serializes;
--- the same place Milky keeps the slots it has handed out.

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

--- The hand size the run is actually working from.
--- real_card_limit is the honest number: card_limit is clamped at zero, so
--- once it bottoms out it stops telling you how far below you are.
local function current_hand_size()
    local config = G.hand and G.hand.config
    if not config then return nil end
    return config.real_card_limit or config.card_limit
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
        -- Both tiers are printed rather than only the one that applies next.
        -- The second is the one that decides whether using the first is a good
        -- idea, and it is not visible anywhere else.
        return { vars = { extra.ante, extra.hand_size,
                          extra.ante_more, extra.hand_size_more } }
    end,

    can_use = function(self, card)
        local size = current_hand_size()
        if not size then return false end
        -- A hand of nothing cannot be played, and the game offers no way back
        -- up. Refusing the card is better than selling a soft lock.
        local _, cost = next_cost(card)
        return size - cost >= 1
    end,

    use = function(self, card, area, copier)
        local antes, hand_cost = next_cost(card)

        -- Counted per application rather than per card bought: a copier makes
        -- the effect happen again, and vanilla's own consumeable_usage does
        -- not count those, so it cannot be the source of truth here.
        G.GAME.celesta_raise_uses = uses_this_run() + 1

        if G.hand then G.hand:change_size(-hand_cost) end
        ease_ante(antes)

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.2,
            func = function()
                play_sound("gold_seal", 0.9, 0.5)
                card_eval_status_text(card, "extra", nil, nil, nil,
                    { message = localize("celesta_raised"), colour = G.C.FILTER })
                return true
            end
        })
    end,
}
