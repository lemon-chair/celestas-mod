--- Decks (called "Backs" internally).
--- Any key in `config` that matches a vanilla starting param is applied for
--- free: dollars, hands, discards, hand_size, joker_slot, consumable_slot,
--- reroll_cost, ante_scaling, no_faces, ... Use `apply` for anything else.

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
