--- THE ENHANCEMENT TAROTS
---
--- One Tarot per enhancement this mod adds that a player would otherwise have
--- to wait for: Limestone, Exo, Gash and Sandstone. The same job vanilla's
--- Magician, Empress, Hierophant and friends do for Lucky, Mult, Bonus and the
--- rest. Polish is the odd one only in that it demands a Stone Card to work
--- on; what it then does is what the others do.
---
--- All four are `mod_conv` cards and nothing more. That is not shorthand - it
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
SMODS.Atlas { key = "polish",         path = "polish.png",         px = 71, py = 95 }

--- How many cards may be selected. One each, as asked.
local SELECTED = 1

--- What Polish accepts, and what each one becomes.
---
--- Two stones in, two stones out, and the pair are the same card in Chips and
--- in Mult. Vanilla's Stone Card is the plain one and becomes Sandstone; this
--- mod's Limestone becomes Scoria.
local POLISH = {
    ["m_stone"] = CelestasMod.ENHANCEMENT_KEYS.Sandstone,
    [CelestasMod.ENHANCEMENT_KEYS.Limestone] = CelestasMod.ENHANCEMENT_KEYS.Scoria,
}

--- What Polish would turn `chosen` into, or nil if it is not a stone.
local function polished_into(chosen)
    for from, into in pairs(POLISH) do
        if SMODS.has_enhancement(chosen, from) then return into end
    end
    return nil
end

--- Shared: at least one card highlighted, and no more than the card allows.
--- Shaped like Tree's, which is the other Tarot in this mod that acts on the
--- selection.
---
--- `requires` is Polish's alone. Polish does not enhance a card, it weathers a
--- stone, so every card picked has to already BE one - and the check has to be
--- here rather than in `use`, because there is no use of ours to check in: the
--- conversion is vanilla's mod_conv path, which acts on whatever was
--- highlighted without asking.
local function can_use_with(requires)
    return function(self, card)
        local picked = G.hand and G.hand.highlighted
        if not (picked and #picked > 0
                and #picked <= (self.config.max_highlighted or SELECTED)) then
            return false
        end
        if not requires then return true end
        for _, chosen in ipairs(picked) do
            if not polished_into(chosen) then return false end
        end
        return true
    end
end

--- The three are identical apart from which enhancement they hand out and
--- which sheet they are drawn from, so they are declared from a list rather
--- than written out three times.
local ENHANCERS = {
    { key = "citrus",         atlas = "citrus",         enhancement = "Limestone" },
    { key = "miracle_matter", atlas = "miracle_matter", enhancement = "Exo" },
    { key = "knife",          atlas = "knife",          enhancement = "Gash" },
    -- Either stone. Which one it is decides what comes out, which is the one
    -- thing here mod_conv alone cannot express - see the wrapper below.
    -- `enhancement` is the default, and the one a Stone Card gets.
    { key = "polish",         atlas = "polish",         enhancement = "Sandstone",
      requires = true },
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
            -- What it needs before what it gives, which is the order the
            -- player meets them in. Polish has two of each, listed as pairs so
            -- the stone and what it becomes sit together.
            if entry.requires then
                info_queue[#info_queue + 1] = G.P_CENTERS["m_stone"]
                info_queue[#info_queue + 1] = G.P_CENTERS[POLISH["m_stone"]]
                local limestone = CelestasMod.ENHANCEMENT_KEYS.Limestone
                info_queue[#info_queue + 1] = G.P_CENTERS[limestone]
                info_queue[#info_queue + 1] = G.P_CENTERS[POLISH[limestone]]
            else
                info_queue[#info_queue + 1] = G.P_CENTERS[center_key]
            end
            return { vars = { self.config.max_highlighted } }
        end,

        can_use = can_use_with(entry.requires),

        -- Polish alone. A Tarot that can only be used on a stone is dead
        -- weight in a deck that has none, and unlike the other three it cannot
        -- make its own target - so it is not offered until the deck holds
        -- something it could work on.
        --
        -- The FULL deck rather than the hand or the draw pile:
        -- G.playing_cards is the run's whole deck, a registry kept for
        -- counting (see CelestasMod.prune_unrenderable_cards in globals.lua
        -- for what it is and is not). A stone sitting in the discard pile is
        -- still a stone the player will draw again.
        in_pool = entry.requires and function(self, args)
            for _, playing in ipairs(G.playing_cards or {}) do
                if polished_into(playing) then return true end
            end
            return false
        end or nil,
    }
end

--------------------------------------------------------------------------------
-- Which stone Polish is polishing
--------------------------------------------------------------------------------
--
-- mod_conv is ONE key applied to whatever was highlighted, and Polish now has
-- two answers depending on what it finds. So the key is chosen at the moment
-- the card is spent, just before vanilla reads it.
--
-- The card is given its OWN copy of the config table first. Card:set_ability
-- assigns ability.consumeable = center.config by reference (card.lua:416), so
-- every Polish in the run shares one table - and the conversion reads mod_conv
-- out of it inside a deferred event (card.lua:1386), not at the moment of use.
-- Writing to the shared table would mean two Polishes spent in the same breath
-- could read each other's answer. A per-card copy cannot.
--
-- Wrapped here rather than given a `use`: Steamodded's patch returns as soon as
-- a centre defines one (the `if obj.use ... return end` immediately above the
-- mod_conv branch), so a use of ours would REPLACE vanilla's conversion and
-- lose the whole animation with it - which is the reason this file has no use
-- functions at all.

local POLISH_KEY = "c_" .. SMODS.current_mod.prefix .. "_polish"

local celesta_polish_use_ref = Card.use_consumeable
function Card:use_consumeable(area, copier)
    local center = self.config and self.config.center
    if center and center.key == POLISH_KEY
        and G.hand and G.hand.highlighted and G.hand.highlighted[1] then
        local into = polished_into(G.hand.highlighted[1])
        if into then
            if self.ability.consumeable == center.config then
                local own = {}
                for k, v in pairs(center.config) do own[k] = v end
                self.ability.consumeable = own
            end
            self.ability.consumeable.mod_conv = into
        end
    end
    return celesta_polish_use_ref(self, area, copier)
end
