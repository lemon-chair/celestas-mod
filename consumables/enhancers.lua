--- THE ENHANCEMENT TAROTS
---
--- One Tarot per enhancement this mod adds that a player would otherwise have
--- to wait for: Limestone, Exo and Gash. The same job vanilla's Magician,
--- Empress, Hierophant and friends do for Lucky, Mult, Bonus and the rest.
---
--- All three are `mod_conv` cards and nothing more. That is not shorthand - it
--- is the whole implementation, and deliberately so:
---
---   * vanilla's Card:use_consumeable already handles mod_conv, with the full
---     animation an enhancement Tarot is supposed to have - tarot1 as the card
---     is spent, every selected card flipping face-down to card1, the ability
---     landing while they are hidden, then flipping back to tarot2. Writing a
---     `use` here would get none of that: Steamodded's patch sits immediately
---     BEFORE the mod_conv branch and returns as soon as a centre defines one
---     (smods lovely/center.toml), so a hand-written use REPLACES the vanilla
---     path rather than adding to it.
---
---   * it reads G.P_CENTERS[mod_conv] at use time, so a modded enhancement key
---     works exactly as a vanilla one does.
---
--- can_use is still ours: the same patch routes can_use_consumeable through
--- the centre when it defines one, and without it the USE button stays greyed
--- out forever - vanilla's chain of name checks ends in `return false` and a
--- modded key matches none of them.

SMODS.Atlas { key = "citrus",         path = "citrus.png",         px = 71, py = 95 }
SMODS.Atlas { key = "miracle_matter", path = "miracle_matter.png", px = 71, py = 95 }
SMODS.Atlas { key = "knife",          path = "knife.png",          px = 71, py = 95 }

--- How many cards may be selected. One each, as asked.
local SELECTED = 1

--- Shared by all three: at least one card highlighted, and no more than the
--- card allows. Shaped like Tree's, which is the other Tarot in this mod that
--- acts on the selection.
local function can_use(self, card)
    local picked = G.hand and G.hand.highlighted
    return picked and #picked > 0
        and #picked <= (self.config.max_highlighted or SELECTED)
end

--- The three are identical apart from which enhancement they hand out and
--- which sheet they are drawn from, so they are declared from a list rather
--- than written out three times.
local ENHANCERS = {
    { key = "citrus",         atlas = "citrus",         enhancement = "Limestone" },
    { key = "miracle_matter", atlas = "miracle_matter", enhancement = "Exo" },
    { key = "knife",          atlas = "knife",          enhancement = "Gash" },
}

for _, entry in ipairs(ENHANCERS) do
    local center_key = CelestasMod.ENHANCEMENT_KEYS[entry.enhancement]

    SMODS.Consumable {
        key = entry.key,
        set = "Tarot",
        atlas = entry.atlas,
        pos = { x = 0, y = 0 },

        cost = 3,
        unlocked = true,
        discovered = true,

        -- mod_conv is read off ability.consumeable, which IS this table:
        -- Card:set_ability assigns `self.ability.consumeable = center.config`.
        config = { mod_conv = center_key, max_highlighted = SELECTED },

        loc_vars = function(self, info_queue, card)
            info_queue[#info_queue + 1] = G.P_CENTERS[center_key]
            return { vars = { self.config.max_highlighted } }
        end,

        can_use = can_use,
    }
end
