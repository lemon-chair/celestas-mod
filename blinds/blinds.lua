--- BOSS BLINDS
---
--- Chip art is built by tools/gen_blinds.py. Blind chips are animated: the
--- vanilla atlas is registered with frames = 21 at 34x34, so a blind's atlas
--- must match that shape or the chip renders wrong.
---
--- Keys get the `bl` class prefix plus the mod prefix, so `clover` registers
--- as bl_celesta_clover and reads its text from descriptions.Blind.

SMODS.Blind {
    key = "clover",
    atlas = "blind_clover",
    pos = { x = 0, y = 0 },

    -- Standard boss payout and score requirement.
    dollars = 5,
    mult = 2,
    boss = { min = 1, max = 10 },
    boss_colour = HEX("4C9A2A"),
    discovered = true,

    loc_vars = function(self)
        return { vars = {} }
    end,

    calculate = function(self, blind, context)
        -- Same hook Dejavudea uses: mod_probability is the additive pass every
        -- SMODS.get_probability_vars call runs through, so this reaches every
        -- listed chance without needing to know about any of them. Doubling
        -- the denominator keeps odds readable as "1 in N".
        if context.mod_probability then
            return { denominator = (context.denominator or 1) * 2 }
        end
    end,
}
