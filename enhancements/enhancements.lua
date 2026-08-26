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
    Eutrophic = "m_" .. SMODS.current_mod.prefix .. "_eutrophic",
    Limestone = "m_" .. SMODS.current_mod.prefix .. "_limestone",
    Driftwood = "m_" .. SMODS.current_mod.prefix .. "_driftwood",
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

--------------------------------------------------------------------------------
-- Eutrophic — copies the abilities of the leftmost card.
--------------------------------------------------------------------------------

SMODS.Enhancement {
    key = "eutrophic",
    atlas = "enh_eutrophic",
    pos = { x = 0, y = 0 },
    discovered = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        local area = card.area
        if not area or not area.cards then return end
        local left = area.cards[1]
        -- Nothing to copy if this IS the leftmost card, which also stops a row
        -- of Eutrophics recursing into each other.
        if not left or left == card then return end

        local center = left.config and left.config.center
        if not center or center.key == self.key then return end

        local effect

        -- Config-driven values first. These never reach a calculate function -
        -- Card:set_ability copies them onto the card and scoring reads them
        -- directly - so copying behaviour alone would miss Limestone's Mult
        -- and Gash's X Mult entirely.
        if context.main_scoring and context.cardarea == G.play then
            effect = {}
            local a = left.ability
            if a then
                if (a.mult or 0) ~= 0 then effect.mult = a.mult end
                if (a.bonus or 0) ~= 0 then effect.chips = a.bonus end
                if (a.x_mult or 1) ~= 1 then effect.x_mult = a.x_mult end
                if (a.x_chips or 1) ~= 1 then effect.x_chips = a.x_chips end
            end
            if not next(effect) then effect = nil end
        end

        -- Then the copied centre's own behaviour, run against THIS card so its
        -- effects land here rather than on the card being copied.
        if type(center.calculate) == "function" then
            local copied = center:calculate(card, context)
            if copied then
                if not effect then return copied end
                for k, v in pairs(copied) do effect[k] = v end
            end
        end

        return effect
    end,
}

--------------------------------------------------------------------------------
-- Limestone — +10 Mult, rankless and suitless like a Stone Card.
--------------------------------------------------------------------------------

SMODS.Enhancement {
    key = "limestone",
    atlas = "enh_limestone",
    pos = { x = 0, y = 0 },
    discovered = true,

    -- Same shape as vanilla m_stone: it IS the card, has no rank or suit, and
    -- always scores whether or not it is part of the poker hand.
    replace_base_card = true,
    no_rank = true,
    no_suit = true,
    always_scores = true,

    -- Applied by the game (ability.mult), not returned from calculate.
    config = { mult = 10 },

    loc_vars = function(self, info_queue, card)
        return { vars = { self.config.mult } }
    end,
}

--------------------------------------------------------------------------------
-- Driftwood — may break if still held at the end of the round.
--------------------------------------------------------------------------------

CelestasMod.DRIFTWOOD_ODDS = 6

SMODS.Enhancement {
    key = "driftwood",
    atlas = "enh_driftwood",
    pos = { x = 0, y = 0 },
    discovered = true,

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(
            card, 1, CelestasMod.DRIFTWOOD_ODDS, "celesta_driftwood")
        return { vars = { n, d } }
    end,

    calculate = function(self, card, context)
        -- The end-of-round pass over cards still in hand. Destroying through
        -- SMODS.destroy_cards rather than returning `remove` because this is
        -- not the scoring destroy pass - nothing is collecting flags here.
        if context.end_of_round and context.cardarea == G.hand
            and not context.blueprint and not context.repetition then
            if SMODS.pseudorandom_probability(card, "celesta_driftwood", 1,
                    CelestasMod.DRIFTWOOD_ODDS, "celesta_driftwood") then
                G.E_MANAGER:add_event(Event {
                    func = function()
                        SMODS.destroy_cards(card)
                        return true
                    end
                })
                return {
                    message = localize("celesta_broke"),
                    colour = G.C.FILTER,
                    card = card,
                }
            end
        end
    end,
}
