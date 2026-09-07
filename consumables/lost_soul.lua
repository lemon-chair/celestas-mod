--- LOST SOUL
---
--- The Soul's opposite number. It turns up the same way and about as rarely,
--- and instead of making a Legendary out of nothing it takes a Joker already
--- on the board and makes it something worse.
---
--- Which Jokers it can be spent on, and what they become, is jokers/lost.lua's
--- business - CelestasMod.Lost. This file is the card.
---
--- Load order: consumables/ is loaded from main.lua before jokers/, so
--- CelestasMod.Lost does not exist yet while this file runs. Nothing below
--- reads it at load time; can_use and use are both called with a run in
--- progress, long after everything has loaded.

local PREFIX = SMODS.current_mod.prefix

-- Two cells: the face and, at (1,0), the wisp that floats over it. One sheet
-- because Steamodded builds the floating sprite from the centre's OWN atlas
-- (src/overrides.lua:1807), so a separate one could not be reached.
-- tools/gen_lost.py builds it.
SMODS.Atlas { key = "lost_soul", path = "lost_soul.png", px = 71, py = 95 }

-- Declared here rather than in jokers/sounds.lua: that file is the roster of
-- JOKER arrival sounds, and this is a consumable's. SMODS.Sound has a
-- register_global that would sweep assets/sounds/ automatically, but nothing
-- in Steamodded ever calls it, so a file dropped in that folder registers only
-- if it is named somewhere.
--
-- Avoid the words music, stream and ambient in a sound key: SMODS matches
-- those to decide streaming vs static, and a short effect wants static.
SMODS.Sound { key = "lost_soul_use", path = "lost_soul_use.wav" }
local USE_SOUND = SMODS.current_mod.prefix .. "_lost_soul_use"

--------------------------------------------------------------------------------

-- `hidden` is what puts it on the same roll as The Soul rather than in the
-- ordinary Spectral pool: Steamodded reads that flag and adds the card to
-- SMODS.Consumable.legendaries (game_object.lua:1282).
--
-- "The same odds and places as The Soul" is spelled out by the two fields
-- below rather than left to the defaults. The Soul is rolled at > 0.997 when
-- the pack being filled is a Tarot or a Spectral one (common_events.lua:2423),
-- and a modded soul is offered when the pack matches EITHER its own set or its
-- soul_set (common_events.lua:2408) - so set = Spectral and soul_set = Tarot
-- between them cover both packs, at the same 0.003.
SMODS.Consumable {
    key = "lost_soul",
    set = "Spectral",
    atlas = "lost_soul",
    pos = { x = 0, y = 0 },
    soul_pos = { x = 1, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    hidden = true,
    soul_set = "Tarot",
    soul_rate = 0.003,

    -- Not offered at all unless there is something on the board to spend it
    -- on. The soul roll asks this: create_card walks
    -- SMODS.Consumable.legendaries and takes only the entries
    -- SMODS.add_to_pool accepts (common_events.lua:2408), and add_to_pool is
    -- in_pool (utils.lua:3059).
    --
    -- The same question can_use asks, through the same function - so a Lost
    -- Soul can never turn up as a card the player is unable to use. A Joker
    -- already Corrupt does not count, and neither does one bound into a
    -- merge, because Lost.convertible refuses both.
    in_pool = function(self, args)
        local Lost = CelestasMod.Lost
        return Lost ~= nil and #Lost.targets() > 0
    end,

    -- Ours because it has to be: Steamodded routes can_use_consumeable through
    -- the centre, and vanilla's chain of name checks ends in `return false`
    -- for a key it does not recognise, which would grey the button out
    -- forever.
    can_use = function(self, card)
        local Lost = CelestasMod.Lost
        return Lost ~= nil and #Lost.targets() > 0
    end,

    use = function(self, card, area, copier)
        -- Straight away, not with the conversion event below: the sound is
        -- the card being spent, and the Joker turning is what follows it.
        play_sound(USE_SOUND)

        local Lost = CelestasMod.Lost
        if not Lost then return end

        -- The leftmost eligible Joker. There is no way to point at a Joker the
        -- way a Tarot points at playing cards - Balatro has no selection for
        -- them - so the card takes the first one it comes to, which is the one
        -- the outline has been drawn around since the Soul was picked up.
        local target = Lost.targets()[1]
        if not target then return end

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                Lost.convert(target)
                target:juice_up(0.5, 0.6)
                return true
            end,
        })
    end,
}
