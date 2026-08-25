--- Consumables (Tarot / Planet / Spectral).
--- Change `set` to 'Planet' or 'Spectral' to make one of those instead;
--- SMODS.Consumable handles all three the same way.

SMODS.Consumable {
    key = 'reforge',
    set = 'Tarot',
    atlas = 'consumables',
    pos = { x = 0, y = 0 },

    cost = 3,
    unlocked = true,
    discovered = true,

    config = { extra = { max_highlighted = 2 } },

    loc_vars = function(self, info_queue, card)
        -- Tooltip for the enhancement this card applies.
        info_queue[#info_queue + 1] = G.P_CENTERS.m_mult
        return { vars = { card.ability.extra.max_highlighted } }
    end,

    -- Greys the card out in the consumable area when this returns false.
    can_use = function(self, card)
        return #G.hand.highlighted > 0
            and #G.hand.highlighted <= card.ability.extra.max_highlighted
    end,

    use = function(self, card, area, copier)
        local highlighted = {}
        for i = 1, #G.hand.highlighted do highlighted[i] = G.hand.highlighted[i] end

        -- Flip the selected cards face down.
        for i = 1, #highlighted do
            local percent = 1.15 - (i - 0.999) / (#highlighted - 0.998) * 0.3
            G.E_MANAGER:add_event(Event { trigger = 'after', delay = 0.15, func = function()
                highlighted[i]:flip()
                play_sound('card1', percent)
                highlighted[i]:juice_up(0.3, 0.3)
                return true
            end })
        end
        delay(0.2)

        -- Apply the enhancement while they are hidden.
        for i = 1, #highlighted do
            G.E_MANAGER:add_event(Event { trigger = 'after', delay = 0.1, func = function()
                highlighted[i]:set_ability(G.P_CENTERS.m_mult)
                return true
            end })
        end

        -- Flip them back.
        for i = 1, #highlighted do
            local percent = 0.85 + (i - 0.999) / (#highlighted - 0.998) * 0.3
            G.E_MANAGER:add_event(Event { trigger = 'after', delay = 0.15, func = function()
                highlighted[i]:flip()
                play_sound('tarot2', percent, 0.6)
                highlighted[i]:juice_up(0.3, 0.3)
                return true
            end })
        end

        G.E_MANAGER:add_event(Event { trigger = 'after', delay = 0.2, func = function()
            G.hand:unhighlight_all()
            return true
        end })
        delay(0.5)
    end,
}
