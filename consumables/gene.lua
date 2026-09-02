--- GENE
---
--- A Tarot that puts a Gene Seal on one selected card. What the seal then does
--- - move its card to the front of the deal - is in jokers/implemented.lua,
--- with the rest of the deal order; the seal itself is declared in
--- seals/seals.lua. This file is only how a player gets one.
---
--- Written with a `use` rather than declared like the enhancement Tarots in
--- enhancers.lua, and the difference is not a preference. Those work because
--- vanilla's Card:use_consumeable has a mod_conv branch that reads a centre's
--- config; there is no seal_conv beside it. Vanilla applies a seal only after
--- matching a card BY NAME - `if self.ability.name == 'Talisman' or ... 'Deja
--- Vu'` (card.lua:1421) - and no modded card can join that list.
---
--- So the sequence below is that branch, copied: tarot1 as the card is spent,
--- the seal landing a tenth of a second later, the selection released after
--- half. Steamodded's patch returns as soon as a centre defines `use` (smods
--- lovely/center.toml:206), so this REPLACES vanilla's path rather than adding
--- to it - anything left out here simply would not happen, which is why the
--- timing is matched rather than invented.

SMODS.Atlas { key = "gene", path = "gene.png", px = 71, py = 95 }

--- How many cards may be selected. One, as asked.
local SELECTED = 1

SMODS.Consumable {
    key = "gene",
    set = "Tarot",
    atlas = "gene",
    pos = { x = 0, y = 0 },

    -- The price of the other enhancement Tarots in this mod.
    cost = 3,
    unlocked = true,
    discovered = true,

    config = { max_highlighted = SELECTED },

    loc_vars = function(self, info_queue, card)
        -- The seal's own description under this card's, so the player can read
        -- what they are about to hand out. Guarded because a Tarot can be
        -- hovered in the collection with the seal not yet injected.
        local seal = CelestasMod.SEAL_KEYS and CelestasMod.SEAL_KEYS.Gene
        local center = seal and G.P_SEALS and G.P_SEALS[seal]
        if center then info_queue[#info_queue + 1] = center end

        return { vars = { self.config.max_highlighted } }
    end,

    -- Ours because it has to be: the same patch routes can_use_consumeable
    -- through the centre, and vanilla's chain of name checks ends in `return
    -- false` for a key it does not recognise, which greys the button out
    -- forever.
    can_use = function(self, card)
        local picked = G.hand and G.hand.highlighted
        return picked and #picked > 0
            and #picked <= (self.config.max_highlighted or SELECTED)
    end,

    use = function(self, card, area, copier)
        local target = G.hand and G.hand.highlighted and G.hand.highlighted[1]
        if not target then return end
        local seal = CelestasMod.SEAL_KEYS and CelestasMod.SEAL_KEYS.Gene
        if not seal then return end

        G.E_MANAGER:add_event(Event {
            func = function()
                play_sound("tarot1")
                card:juice_up(0.3, 0.5)
                return true
            end,
        })

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.1,
            func = function()
                -- The third argument is vanilla's `immediate`: the seal is
                -- already being announced by the Tarot, and without it the
                -- card plays the seal's own arrival on top of that.
                target:set_seal(seal, nil, true)
                return true
            end,
        })

        delay(0.5)

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.2,
            func = function()
                G.hand:unhighlight_all()
                return true
            end,
        })
    end,
}
