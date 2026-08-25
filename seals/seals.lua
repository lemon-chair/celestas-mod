--- SEALS
---
--- Art is built by tools/gen_seals.py into assets/{1x,2x}/seals.png. Each
--- atlas cell is card shaped (71x95) because Balatro stretches a seal's cell
--- across the whole card; the square emblem is padded into it, anchored where
--- the vanilla seals sit.
---
--- Keys are prefixed like everything else, so `Rose` becomes `celesta_Rose`,
--- and its text lives under descriptions.Other / misc.labels as
--- `celesta_rose_seal` (SMODS lowercases the whole prefixed key for loc).
---
--- NONE OF THESE DO ANYTHING YET. Effects are still to be specified, so each
--- one returns false from in_pool and cannot be rolled onto a card. They are
--- registered and browsable so the art and keys are in place. To bring one
--- into the game: delete its in_pool line, add a `calculate`, and replace its
--- placeholder text in localization/en-us.lua.
---
--- Seal calculate contexts work like a joker's, with `card` being the playing
--- card carrying the seal - for example:
---     calculate = function(self, card, context)
---         if context.main_scoring and context.cardarea == G.play then
---             return { mult = 7 }
---         end
---     end

local SEALS = {
    { key = "Ectoplast", pos = 0, badge_colour = HEX("2BC4CE") },
    { key = "Foppy",     pos = 1, badge_colour = HEX("E8365D") },
    { key = "Rose",      pos = 2, badge_colour = HEX("8C2A7A") },
    { key = "Star",      pos = 3, badge_colour = HEX("F3A0BE") },
}

for _, seal in ipairs(SEALS) do
    SMODS.Seal {
        key = seal.key,
        atlas = "seals",
        pos = { x = seal.pos, y = 0 },

        badge_colour = seal.badge_colour,
        discovered = true,
        unlocked = true,

        -- Remove this once the seal has a real effect. Seals are rolled from
        -- get_current_pool("Seal"), which consults SMODS.add_to_pool, so
        -- returning false keeps them off cards entirely for now.
        in_pool = function(self, args) return false end,
    }
end
