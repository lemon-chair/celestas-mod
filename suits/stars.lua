--- THE STARS SUIT
---
--- A fifth suit. The card art is one row of 13 cells - the atlas x comes from
--- the RANK and the y from the SUIT, so a suit is exactly one row:
---     pos = { x = rank.pos.x, y = suit.pos.y }   (SMODS.inject_p_card)
---
--- The UI pip has its own atlas at its own native cell size rather than
--- vanilla's 18x18. Nothing depends on that size: the pip is drawn through
--- SMODS.create_sprite(0, 0, 0.3, 0.3, ...) into a fixed rect, so the cell is
--- scaled to fit whatever it is. Using the art's own 13x13 grid keeps every
--- pixel exactly as drawn instead of resampling it into a larger cell.

SMODS.Atlas { key = "suit_stars",    path = "suit_stars.png",    px = 71, py = 95 }
SMODS.Atlas { key = "suit_stars_ui", path = "suit_stars_ui.png", px = 13, py = 13 }

-- The key is prefixed like every other object, so another mod adding its own
-- "Stars" cannot collide with this one. That prefixed form is what lands on
-- every card and in every save, so it is resolved once here and read from
-- CelestasMod everywhere else - `card:is_suit("Stars")` would never match.
CelestasMod.STARS_SUIT = SMODS.current_mod.prefix .. "_Stars"

-- Sampled from the art itself.
CelestasMod.STARS_COLOUR = "5BD311"

SMODS.Suit {
    key = "Stars",

    -- One character. SMODS patches the two places vanilla pulls a suit out of
    -- a P_CARDS key by position (game.lua's `string.sub(k, 1, 1)`), so a
    -- longer key would survive those - but this key is written into every save
    -- as part of `T_A`-style card ids and can never be changed afterwards, so
    -- it matches the shape vanilla's own four use. T_* is unused.
    card_key = "T",

    -- Row 0 of a one-row sheet.
    pos = { y = 0 },
    ui_pos = { x = 0, y = 0 },

    -- Prefixed automatically (prefix_config.atlas), so these are the bare keys.
    lc_atlas = "suit_stars",
    hc_atlas = "suit_stars",
    lc_ui_atlas = "suit_stars_ui",
    hc_ui_atlas = "suit_stars_ui",

    -- Same colour in both palettes: there is one sheet, so high-contrast mode
    -- has nothing different to show. Giving it a different colour without
    -- different art would just make the pip and the text disagree.
    lc_colour = HEX(CelestasMod.STARS_COLOUR),
    hc_colour = HEX(CelestasMod.STARS_COLOUR),

    loc_txt = {
        singular = "Star",
        plural = "Stars",
    },
}

--- True when the run's deck holds at least one Star card.
function CelestasMod.stars_in_deck()
    return CelestasMod.suit_in_deck(CelestasMod.STARS_SUIT)
end

CelestasMod.register_conversion_suit(CelestasMod.STARS_SUIT)

--------------------------------------------------------------------------------
-- Star Fury - the Tarot that makes Star cards
--------------------------------------------------------------------------------
--
-- The Stars analogue of vanilla's four suit Tarots: The Star, The Moon, The
-- Sun and The World each turn up to three selected cards to one suit. Since
-- Stars are never dealt, this is the deliberate route into them - the vanilla
-- Spectrals that reach the suit (Sigil, Grim, Familiar, Incantation) all do it
-- by chance rather than by choice.
--
-- Written out rather than leaning on vanilla's `effect = "Suit Conversion"`
-- machinery: that path is reached by name in several places in card.lua, and
-- SMODS.change_base is what every suit conversion in this mod already uses.

SMODS.Atlas { key = "star_fury", path = "star_fury.png", px = 71, py = 95 }

SMODS.Consumable {
    key = "star_fury",
    set = "Tarot",
    atlas = "star_fury",
    pos = { x = 0, y = 0 },

    cost = 3,
    unlocked = true,
    discovered = true,

    -- max_highlighted lives on the CENTRE: the game reads it from
    -- ability.consumeable, which is this very table.
    config = { max_highlighted = 3 },

    loc_vars = function(self, info_queue, card)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR)
        -- colours goes INSIDE vars: localize reads
        -- args.vars.colours[tonumber(part.control.V)], and Steamodded's
        -- generate_ui does not forward a colours table returned beside vars.
        return {
            vars = { self.config.max_highlighted, name, colours = { colour } },
        }
    end,

    can_use = function(self, card)
        local picked = G.hand and G.hand.highlighted
        return picked and #picked > 0
            and #picked <= (self.config.max_highlighted or 3)
    end,

    use = function(self, card, area, copier)
        -- Copied out first: the highlight is cleared before the events run.
        local picked = {}
        for i = 1, #G.hand.highlighted do picked[i] = G.hand.highlighted[i] end

        for i, target in ipairs(picked) do
            G.E_MANAGER:add_event(Event {
                trigger = "after",
                delay = 0.15,
                func = function()
                    -- change_base rather than poking base.suit: it keeps the
                    -- sprite and the modded-suit bookkeeping in step.
                    SMODS.change_base(target, CelestasMod.STARS_SUIT)
                    target:juice_up(0.3, 0.3)
                    play_sound("tarot1", 1.0 + 0.05 * i, 0.4)
                    return true
                end
            })
        end
    end,
}
