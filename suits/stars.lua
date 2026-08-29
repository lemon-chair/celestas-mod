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
---
--- Read off base.suit rather than through card:is_suit. is_suit routes through
--- SMODS.smeared_check, so a Wild Card matches every suit and Arielle makes
--- every card match every suit - either would report a Star in a deck that has
--- none. This asks what is printed on the card, which is the question.
---
--- G.playing_cards is the whole run deck wherever its cards happen to be, so a
--- Star in the discard pile or in hand counts as much as one in the draw pile.
function CelestasMod.stars_in_deck()
    for _, held in ipairs(G.playing_cards or {}) do
        if held.base and held.base.suit == CelestasMod.STARS_SUIT then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Keeping Stars out of the starting deck
--------------------------------------------------------------------------------
--
-- A registered suit is in every deck by default: Game:start_run builds the
-- starting deck by walking G.P_CARDS, so thirteen Star cards would be dealt
-- into every run and the base deck would be 65 cards. That is a balance change
-- to the whole game rather than an addition to it, so the suit exists but is
-- not dealt - Stars arrive by conversion.
--
-- They are still reachable without anything else being written: Sigil, Grim,
-- Familiar and Incantation all pick from SMODS.Suits, which includes this one.
--
-- Done by lifting the prototypes out of G.P_CARDS for the duration of the
-- build rather than by filtering afterwards, because the deck is assembled and
-- shuffled inside start_run and there is no seam between those.

local celesta_stars_start_run_ref = Game.start_run
function Game:start_run(args)
    -- A save is restored from the card list it stores, not from P_CARDS, in a
    -- different branch of start_run entirely - but the restore still looks
    -- each card's prototype up. Hiding them here would make a run that already
    -- holds Star cards fail to load, so loads are passed straight through.
    if not args or args.savetext then
        return celesta_stars_start_run_ref(self, args)
    end

    local hidden = {}
    for key, proto in pairs(G.P_CARDS) do
        if proto.suit == CelestasMod.STARS_SUIT then hidden[key] = proto end
    end
    for key in pairs(hidden) do G.P_CARDS[key] = nil end

    -- pcall so a failure anywhere in start_run cannot leave the suit missing
    -- for the rest of the session: without the restore, every later conversion
    -- to Stars would look up a prototype that is not there.
    local ok, err = pcall(celesta_stars_start_run_ref, self, args)

    for key, proto in pairs(hidden) do G.P_CARDS[key] = proto end

    if not ok then error(err, 0) end
    return
end

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
        -- G.C.SUITS is filled in when the suit registers its colours. Falling
        -- back to the raw value keeps {V:1} substitutable rather than handing
        -- localize a nil colour, which renders as a blank suit name.
        local colour = (G.C.SUITS or {})[CelestasMod.STARS_SUIT]
            or HEX(CelestasMod.STARS_COLOUR)
        -- colours goes INSIDE vars: localize reads
        -- args.vars.colours[tonumber(part.control.V)], and Steamodded's
        -- generate_ui does not forward a colours table returned beside vars.
        return {
            vars = { self.config.max_highlighted,
                     localize(CelestasMod.STARS_SUIT, "suits_plural"),
                     colours = { colour } },
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
