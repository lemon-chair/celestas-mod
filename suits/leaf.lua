--- THE LEAF SUIT
---
--- A sixth suit, built exactly like Stars: one row of 13 card cells, its own
--- UI pip at the art's native grid, and no place in any starting deck. See
--- suits/shared.lua for why conversion-only suits work the way they do.

SMODS.Atlas { key = "suit_leaf",    path = "suit_leaf.png",    px = 71, py = 95 }
SMODS.Atlas { key = "suit_leaf_ui", path = "suit_leaf_ui.png", px = 13, py = 13 }

-- Prefixed like every other object, and resolved once: `card:is_suit("Leaf")`
-- would never match, because the prefixed form is what lands on every card.
CelestasMod.LEAF_SUIT = SMODS.current_mod.prefix .. "_Leaf"

-- Sampled from the art itself.
CelestasMod.LEAF_COLOUR = "DF7126"

SMODS.Suit {
    key = "Leaf",

    -- One character, matching the shape vanilla's four use, and distinct from
    -- both those and the Stars suit's T. This is written into every save as
    -- part of `L_A`-style card ids and can never be changed afterwards.
    card_key = "L",

    -- Row 0 of a one-row sheet.
    pos = { y = 0 },
    ui_pos = { x = 0, y = 0 },

    lc_atlas = "suit_leaf",
    hc_atlas = "suit_leaf",
    lc_ui_atlas = "suit_leaf_ui",
    hc_ui_atlas = "suit_leaf_ui",

    -- One sheet, so high-contrast mode has nothing different to show.
    lc_colour = HEX(CelestasMod.LEAF_COLOUR),
    hc_colour = HEX(CelestasMod.LEAF_COLOUR),

    loc_txt = {
        singular = "Leaf",
        plural = "Leaves",
    },
}

--- True when the run's deck holds at least one Leaf card.
function CelestasMod.leaf_in_deck()
    return CelestasMod.suit_in_deck(CelestasMod.LEAF_SUIT)
end

CelestasMod.register_conversion_suit(CelestasMod.LEAF_SUIT)

--------------------------------------------------------------------------------
-- Tree - the Tarot that makes Leaf cards
--------------------------------------------------------------------------------
--
-- The Leaf analogue of Star Fury, and of vanilla's four suit Tarots. Since
-- Leaves are never dealt, this is the deliberate route into them.

SMODS.Atlas { key = "tree", path = "tree.png", px = 71, py = 95 }

SMODS.Consumable {
    key = "tree",
    set = "Tarot",
    atlas = "tree",
    pos = { x = 0, y = 0 },

    cost = 3,
    unlocked = true,
    discovered = true,

    -- max_highlighted lives on the CENTRE: the game reads it from
    -- ability.consumeable, which is this very table.
    config = { max_highlighted = 3 },

    loc_vars = function(self, info_queue, card)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR)
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
                    SMODS.change_base(target, CelestasMod.LEAF_SUIT)
                    target:juice_up(0.3, 0.3)
                    play_sound("tarot1", 1.0 + 0.05 * i, 0.4)
                    return true
                end
            })
        end
    end,
}
