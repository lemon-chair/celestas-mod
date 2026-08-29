--- SUITS THIS MOD ADDS - the machinery both of them share.
---
--- Stars and Leaf are "conversion-only": the suit is registered, so every
--- system that walks SMODS.Suits knows about it, but its thirteen cards are
--- never dealt into a starting deck. They arrive by conversion - a Tarot, a
--- Spectral, a Joker - and until one does, the run has the vanilla 52.
---
--- That decision is why this file exists. A registered suit is in every deck
--- by default (Game:start_run builds the starting deck by walking G.P_CARDS),
--- so each conversion-only suit has to be lifted out of P_CARDS for the
--- duration of the build. Two suits doing that independently would mean two
--- nested wrappers around start_run, two pcalls and two restore paths for one
--- indivisible operation, so the hook is installed once here and reads the
--- registry below at call time.

--- Suit keys that exist but are never dealt. Written by
--- CelestasMod.register_conversion_suit, read by the start_run hook.
CelestasMod.CONVERSION_SUITS = {}

--- The same suits in registration order. The set above answers "is this one of
--- ours"; this answers "in what order", which anything presenting them in a
--- list needs - pairs() over the set would put them in a different order from
--- one run to the next, and Yomi's rotation is saved as an index into exactly
--- such a list.
CelestasMod.CONVERSION_SUIT_ORDER = {}

--- Marks a suit as conversion-only. Called by each suit's own file after it
--- has registered the suit, so the prefixed key is already resolved.
function CelestasMod.register_conversion_suit(suit)
    if CelestasMod.CONVERSION_SUITS[suit] then return end
    CelestasMod.CONVERSION_SUITS[suit] = true
    CelestasMod.CONVERSION_SUIT_ORDER[#CelestasMod.CONVERSION_SUIT_ORDER + 1] = suit
end

--------------------------------------------------------------------------------
-- Asking what is in the deck
--------------------------------------------------------------------------------

--- True when the run's deck holds at least one card printed with `suit`.
---
--- Read off base.suit rather than through card:is_suit. is_suit routes through
--- SMODS.smeared_check, so a Wild Card matches every suit and Arielle makes
--- every card match every suit - either would report a Star in a deck that has
--- none. This asks what is printed on the card, which is the question.
---
--- G.playing_cards is the whole run deck wherever its cards happen to be, so a
--- card in the discard pile or in hand counts as much as one in the draw pile.
function CelestasMod.suit_in_deck(suit)
    for _, held in ipairs(G.playing_cards or {}) do
        if held.base and held.base.suit == suit then
            return true
        end
    end
    return false
end

--- How many cards in the run's deck are printed with `suit`.
---
--- Printed suit, for the same reason as suit_in_deck: through card:is_suit a
--- single Wild Card would count towards every suit at once, and Arielle would
--- make the whole deck count towards all of them.
function CelestasMod.count_suit_in_deck(suit)
    local count = 0
    for _, held in ipairs(G.playing_cards or {}) do
        if held.base and held.base.suit == suit then count = count + 1 end
    end
    return count
end

--- How many distinct suits the run's deck is printed with.
---
--- Suitless cards - Stone, Limestone, anything registering `no_suit` - are not
--- a suit and are not counted. They still carry a base.suit underneath the
--- enhancement, so the enhancement has to be asked rather than the base;
--- SMODS.has_no_suit is that question, and it already knows that a Wild Stone
--- Card is not suitless.
function CelestasMod.unique_suits_in_deck()
    local seen, count = {}, 0
    for _, held in ipairs(G.playing_cards or {}) do
        local suit = held.base and held.base.suit
        if suit and not seen[suit] and not SMODS.has_no_suit(held) then
            seen[suit] = true
            count = count + 1
        end
    end
    return count, seen
end

--- True when every registered suit is represented in the run's deck.
---
--- Asked of SMODS.Suits rather than of a hardcoded list, so another mod's suit
--- widens the requirement rather than leaving it satisfiable while a suit goes
--- unrepresented.
function CelestasMod.all_suits_in_deck()
    local _, seen = CelestasMod.unique_suits_in_deck()
    for key in pairs(SMODS.Suits or {}) do
        if not seen[key] then return false end
    end
    return true
end

--- A suit's localized name and its colour, for descriptions.
---
--- Plural by default, singular when asked. Vanilla draws that line by what the
--- sentence is doing: Greedy Joker reads "Played cards with Diamond suit" and
--- The Sun reads "to Diamonds", so a suit qualifying a noun is singular and a
--- suit named as a set is plural. It matters more here than it does in vanilla,
--- because the Leaf suit's plural is "Leaves".
---
--- The colour falls back to the raw value: G.C.SUITS is filled in when the
--- suit registers its colours, and handing localize a nil colour renders the
--- suit name blank rather than failing.
function CelestasMod.suit_name_and_colour(suit, fallback_hex, singular)
    return localize(suit, singular and "suits_singular" or "suits_plural"),
           (G.C.SUITS or {})[suit] or HEX(fallback_hex)
end

--------------------------------------------------------------------------------
-- Keeping the conversion-only suits out of the starting deck
--------------------------------------------------------------------------------
--
-- Done by lifting the prototypes out of G.P_CARDS for the duration of the
-- build rather than by filtering afterwards, because the deck is assembled and
-- shuffled inside start_run and there is no seam between those.
--
-- The suits are still reachable without anything else being written: Sigil,
-- Grim, Familiar and Incantation all pick from SMODS.Suits, which includes
-- them.

local celesta_suits_start_run_ref = Game.start_run
function Game:start_run(args)
    -- A save is restored from the card list it stores, not from P_CARDS, in a
    -- different branch of start_run entirely - but the restore still looks
    -- each card's prototype up. Hiding them here would make a run that already
    -- holds these cards fail to load, so loads are passed straight through.
    if not args or args.savetext then
        return celesta_suits_start_run_ref(self, args)
    end

    local hidden = {}
    for key, proto in pairs(G.P_CARDS) do
        if CelestasMod.CONVERSION_SUITS[proto.suit] then hidden[key] = proto end
    end
    for key in pairs(hidden) do G.P_CARDS[key] = nil end

    -- pcall so a failure anywhere in start_run cannot leave the suits missing
    -- for the rest of the session: without the restore, every later conversion
    -- into one would look up a prototype that is not there.
    local ok, err = pcall(celesta_suits_start_run_ref, self, args)

    for key, proto in pairs(hidden) do G.P_CARDS[key] = proto end

    if not ok then error(err, 0) end
    return
end
