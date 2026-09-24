--- THE TRUE STARS SUIT
---
--- A sixth suit, and the narrowest thing in the mod: there is exactly one way
--- to get a True Star card. A Strength Tarot used on an ACE OF STARS turns it
--- into a 2 of True Stars, where any other card would become a 2 of its own
--- suit. Nothing else makes one - no Tarot, no Spectral, no Joker, no pack.
---
--- Built like the Stars suit next door (one 13-cell row, its own UI pip at the
--- art's native size) and registered as conversion-only through the same
--- registry, so the start-of-run hide keeps it out of every starting deck.

SMODS.Atlas { key = "suit_true_stars",    path = "suit_true_stars.png",    px = 71, py = 95 }
SMODS.Atlas { key = "suit_true_stars_ui", path = "suit_true_stars_ui.png", px = 13, py = 13 }

-- Prefixed for the reason the Stars key is, and written into every save from
-- the moment a card carries it, so it can never be changed afterwards.
CelestasMod.TRUE_STARS_SUIT = SMODS.current_mod.prefix .. "_TrueStars"

-- Sampled from the art: hue 300 exactly, which is the colour the Jokers that
-- react to this suit print their extra line in.
CelestasMod.TRUE_STARS_COLOUR = "D411D4"

SMODS.Suit {
    key = "TrueStars",

    -- One character, matching the shape vanilla's four use. S/H/C/D are taken,
    -- T is the Stars suit, so U is the free one closest to the name.
    card_key = "U",

    pos = { y = 0 },
    ui_pos = { x = 0, y = 0 },

    lc_atlas = "suit_true_stars",
    hc_atlas = "suit_true_stars",
    lc_ui_atlas = "suit_true_stars_ui",
    hc_ui_atlas = "suit_true_stars_ui",

    -- One sheet, so both palettes show the same thing; a second colour without
    -- second art would only make the pip and the text disagree.
    lc_colour = HEX(CelestasMod.TRUE_STARS_COLOUR),
    hc_colour = HEX(CelestasMod.TRUE_STARS_COLOUR),

    loc_txt = {
        singular = "True Star",
        plural = "True Stars",
    },

    -- Never rolled at random, which is the other half of "a Strength on an Ace
    -- of Stars is the ONLY way". The start-of-run hide and the create_card
    -- hide in suits/shared.lua keep the suit out of starting decks and out of
    -- Standard packs, but four vanilla Spectrals reach a suit without touching
    -- G.P_CARDS at all: Sigil converts the hand to
    -- pseudorandom_element(SMODS.Suits), and Grim, Familiar and Incantation
    -- each mint a card of one.
    --
    -- in_pool is Steamodded's own answer to that. pseudorandom_element asks it
    -- of every element it is about to choose between (misc_functions.lua:273)
    -- and drops the ones that say no, so one field covers all four - and any
    -- other mod that picks a suit the same way.
    --
    -- Always false, not "false until the deck has one": once a True Star
    -- existed, a yes here would let Sigil mint more, and that is the rule this
    -- is here to keep. The Stars and Leaf suits deliberately do NOT have this
    -- - arriving by Spectral is how those two are meant to be found.
    in_pool = function(self, args) return false end,
}

CelestasMod.register_conversion_suit(CelestasMod.TRUE_STARS_SUIT)

--- How many True Star cards the run's deck holds.
---
--- count_suit_in_deck reads base.suit, which is what makes two of this suit's
--- rules true without any code of their own: a Wild Card is not printed a True
--- Star, and Arielle - which widens is_suit, not base.suit - does not make one
--- either.
function CelestasMod.true_stars_in_deck()
    return CelestasMod.count_suit_in_deck(CelestasMod.TRUE_STARS_SUIT)
end

--- True when the run's deck holds at least one.
function CelestasMod.has_true_star()
    return CelestasMod.suit_in_deck(CelestasMod.TRUE_STARS_SUIT)
end

--- X0.25 a card, counted live off the deck the way Buffpup counts its Leaves:
--- "for each True Star card in the full deck" is a question about the deck as
--- it is now, so losing one takes the multiplier back down.
CelestasMod.TRUE_STAR_X_MULT = 0.25

--- The Eidolon Wyrm's is multiplicative and per card in the played hand, so
--- two of them are X2.25 rather than X3.
CelestasMod.TRUE_STAR_WYRM_X = 1.5

function CelestasMod.true_star_x_mult()
    return 1 + CelestasMod.TRUE_STAR_X_MULT * CelestasMod.true_stars_in_deck()
end

--- Points a Joker's loc_vars at its True Star description, and hands that
--- description the number.
---
--- A SECOND localization entry rather than a conditional line: a description
--- is a fixed list of lines, so the only way to add one is to point loc_vars
--- somewhere else - which SMODS supports by returning `key`. The entry is the
--- Joker's own key with "_true" on the end, and the extra line is the last
--- variable, so the ones already there keep their numbers.
--- The extra values default to the rate and the running total, which is how
--- the mod writes every "for each card in your full deck" line. A Joker whose
--- line needs something else - the Wyrm's, which is per played card and so has
--- no running total - passes its own instead.
function CelestasMod.with_true_star_line(key, ret, ...)
    ret = ret or {}
    if not CelestasMod.has_true_star() then return ret end
    ret.key = key .. "_true"
    ret.vars = ret.vars or {}

    local extra = select("#", ...)
    if extra == 0 then
        ret.vars[#ret.vars + 1] = CelestasMod.TRUE_STAR_X_MULT
        ret.vars[#ret.vars + 1] = CelestasMod.true_star_x_mult()
    else
        for i = 1, extra do
            ret.vars[#ret.vars + 1] = (select(i, ...))
        end
    end
    return ret
end

--------------------------------------------------------------------------------
-- The one way in
--------------------------------------------------------------------------------
--
-- SMODS takes ownership of the Strength Tarot and routes it through
-- SMODS.modify_rank(card, 1) (game_object.lua:2217), which is the single
-- funnel every rank raise goes through. Wrapped there rather than around the
-- Tarot itself: the Tarot's own branch is SMODS', not vanilla's, and hooking
-- the funnel catches it wherever it is called from.
--
-- The test is on the CARD, not on what called: an Ace that came back a 2 is
-- something only a rank RAISE does, and only Strength raises an Ace - vanilla
-- wraps 14 round to 2 and nothing else in the game does. Weakness lowers, so
-- it never reaches this.

local celesta_true_stars_rank_ref = SMODS.modify_rank

function SMODS.modify_rank(card, amount, ...)
    local was_ace_of_stars = amount and amount > 0
        and card and card.base
        and card.base.suit == CelestasMod.STARS_SUIT
        and card.base.id == 14

    local ret = celesta_true_stars_rank_ref(card, amount, ...)

    -- Only if the raise actually happened and landed where Strength lands.
    if was_ace_of_stars and card.base and card.base.id == 2 then
        SMODS.change_base(card, CelestasMod.TRUE_STARS_SUIT)
    end
    return ret
end

--------------------------------------------------------------------------------
-- ...and what does NOT count as one
--------------------------------------------------------------------------------
--
--- True when `card` IS a True Star, which is the only question anything in
--- this mod should ask about the suit.
---
--- Printed suit, never card:is_suit. That one answers yes for a Wild Card
--- (Card:is_suit checks the Wild enhancement before anything else) and yes for
--- everything at all while Arielle is out (which widens SMODS.smeared_check).
--- Both of those are right for an ordinary suit and wrong for this one: a True
--- Star is meant to be the card you had to go and get, not a card that counts
--- as one.
---
--- Asking base.suit rather than fighting is_suit also means there is no hook
--- to keep in the right order. A wrapper here would have to sit OUTSIDE
--- Arielle's to overrule it, and suits/ loads before jokers/ - so it would
--- have ended up inside, and Arielle would have had the last word.
function CelestasMod.is_true_star(card)
    return (card and card.base and card.base.suit == CelestasMod.TRUE_STARS_SUIT)
        and true or false
end

--------------------------------------------------------------------------------
-- What the rank is worth
--------------------------------------------------------------------------------

--- A True Star's RANK is worth X1.5 an ordinary card's: an 8 of True Stars
--- scores 12 Chips where an 8 of any other suit scores 8, and a 5 scores 7.5.
CelestasMod.TRUE_STAR_CHIP_X = 1.5

--- Runs `fn` with `card`'s rank already scaled, and puts it back afterwards.
---
--- base.nominal is the rank's chip value - the 8 in "an 8 gives 8 Chips" - and
--- scaling THAT rather than the answer is what keeps the rule the one that was
--- asked for: X1.5 what a card of that rank would give. Anything added on top
--- of the rank keeps its printed value, so a Bonus True Star is 12 + 30 rather
--- than 57; +30 is not part of a rank.
---
--- Scaled across the call instead of added to the result because the two
--- readers below each take one of several branches and only some of those
--- branches use the rank at all: Card:get_chip_bonus returns the enhancement's
--- chips alone for a Stone Card (card.lua:1175), and a Stone card has no rank
--- to be worth more of. Scaling the field vanilla reads means every branch is
--- right without this having to know which one ran - and means the two readers
--- cannot drift apart, which is the fault Ruben Sargasm shipped with.
---
--- Put back through pcall for the reason CelestasMod.unjudged is: a field
--- restored only on the happy path is a field left wrong forever the first
--- time something underneath throws. Three return values, which is what the
--- wider of the two callers has (card.lua:1104).
local function with_scaled_rank(card, fn)
    local base = card.base
    local nominal = base and base.nominal
    if not (nominal and nominal > 0) then return fn() end

    base.nominal = nominal * CelestasMod.TRUE_STAR_CHIP_X
    local a, b, c
    local ok, err = pcall(function() a, b, c = fn() end)
    base.nominal = nominal

    if not ok then error(err, 0) end
    return a, b, c
end

--- The Chips a card is worth, a True Star's rank counted at X1.5.
---
--- One funnel is all this needs: a played card's chips are read here and
--- nowhere else (SMODS' common_events.lua:636), so scoring, every retrigger
--- and every Joker in this mod that asks a card what it is worth all get the
--- same answer.
local celesta_true_star_chip_ref = Card.get_chip_bonus

function Card:get_chip_bonus()
    if not CelestasMod.is_true_star(self) then
        return celesta_true_star_chip_ref(self)
    end
    local ref, me = celesta_true_star_chip_ref, self
    return with_scaled_rank(self, function() return ref(me) end)
end

--- ...and what the card SAYS it is worth, so the two never disagree.
---
--- The hover builds its own numbers and reads base.nominal straight
--- (card.lua:897) rather than asking get_chip_bonus, so without this an 8 of
--- True Stars would print "8 Chips" on a card that scores 12.
local celesta_true_star_ui_ref = Card.generate_UIBox_ability_table

function Card:generate_UIBox_ability_table(vars_only)
    if not CelestasMod.is_true_star(self) then
        return celesta_true_star_ui_ref(self, vars_only)
    end
    local ref, me = celesta_true_star_ui_ref, self
    return with_scaled_rank(self, function() return ref(me, vars_only) end)
end
