--- ENHANCEMENTS
---
--- Art is built by tools/gen_enhancements.py. Each gets its own atlas because
--- the cell sizes differ: Exo's frame is 84x104 for a 71x95 card, so it reads
--- as overhanging the card edges, while Gash sits inside the card.
---
--- Keys are prefixed like everything else, and are kept lowercase because
--- SMODS uses the key verbatim for localization: `gash` registers as
--- m_celesta_gash and reads its text from descriptions.Enhanced under that
--- exact key. A capitalised key would need capitalised loc entries too.

CelestasMod.ENHANCEMENT_KEYS = {
    Exo  = "m_" .. SMODS.current_mod.prefix .. "_exo",
    Gash = "m_" .. SMODS.current_mod.prefix .. "_gash",
}

-- Shared so Saruei can target this exact roll through fix_probability, and so
-- the odds shown on the card can never drift from the odds rolled.
CelestasMod.GASH_BREAK_ID = "celesta_gash_break"
CelestasMod.GASH_ODDS = 4

--------------------------------------------------------------------------------
-- Exo — retriggered once per consumable held.
--------------------------------------------------------------------------------

SMODS.Enhancement {
    key = "exo",
    atlas = "enh_exo",
    pos = { x = 0, y = 0 },
    discovered = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- One extra trigger per consumable currently held, so an empty
        -- consumable area leaves the card scoring exactly once.
        if context.repetition and context.cardarea == G.play then
            local held = (G.consumeables and G.consumeables.cards)
                and #G.consumeables.cards or 0
            if held > 0 then
                return {
                    message = localize("k_again_ex"),
                    repetitions = held,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Gash — X2 Chips, but 1 in 4 to break when scored.
--------------------------------------------------------------------------------

SMODS.Enhancement {
    key = "gash",
    atlas = "enh_gash",
    pos = { x = 0, y = 0 },
    discovered = true,

    -- Applied by the game, not by calculate. Card:set_ability copies an
    -- enhancement's config straight onto the card
    -- (x_mult = center.config.Xmult or center.config.x_mult or 1) and scoring
    -- reads ability.x_mult through Card:get_chip_x_mult. Returning it from
    -- calculate as well would apply it twice - which is exactly what the
    -- previous x_chips = 2 did, scoring X4 Chips instead of X2.
    config = { x_mult = 1.5 },

    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, CelestasMod.GASH_ODDS, CelestasMod.GASH_BREAK_ID)
        return { vars = { self.config.x_mult, numerator, denominator } }
    end,

    calculate = function(self, card, context)
        -- Self-destruct on the destroy pass, exactly as vanilla Glass does:
        -- the card asks to be removed, rather than a joker removing it.
        if context.destroy_card and context.destroy_card == card
            and context.cardarea == G.play then
            -- A Gash applied by Shoto this very hand gets a pass, so a card
            -- cannot be gashed and destroyed in the same scoring pass. The
            -- flag is consumed here, so it is immune exactly once - and
            -- because Shoto gashes during scoring, that "once" is always the
            -- hand it was created in. Checked ahead of the roll, so Saruei's
            -- 1-in-1 does not override the grace either.
            if card.celesta_gash_fresh then
                card.celesta_gash_fresh = nil
                return
            end
            if SMODS.pseudorandom_probability(card, CelestasMod.GASH_BREAK_ID,
                    1, CelestasMod.GASH_ODDS, CelestasMod.GASH_BREAK_ID) then
                return { remove = true }
            end
        end
    end,
}
