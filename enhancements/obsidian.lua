--- OBSIDIAN
---
--- Its own file, apart from the rest of the enhancements, because suites slice
--- enhancements.lua by banner to run one section at a time and a whole enhancement does not
--- belong in the middle of anybody's slice. Loaded straight after it (main.lua), so the
--- scoring-sound helper it shares and ENHANCEMENT_KEYS.Obsidian both exist.

--------------------------------------------------------------------------------
-- Obsidian: X1.2 Chips or X1.2 Mult, and a rank that does not stay put.
--------------------------------------------------------------------------------
--
-- Not a stone. It keeps its rank and its suit - the art is the card body and the
-- pips draw over it, the way Foliage's do - so it scores as the card it is, and the
-- suit it keeps is what KloeKroc has something to say about.
--
-- "X1.2 Chips or X1.2 Mult" is an even pick between the two, and "1 in 6 chance for
-- both" is ONE roll: the rare branch is rolled and the ordinary one is whatever that
-- is not, which is how Sandstone and Scoria are written, so a Joker that moves the
-- odds - Oops! All 6s - cannot leave the card claiming chances that do not add up.
--
-- It scores through Limestone's sound, as asked.

CelestasMod.OBSIDIAN_X = 1.2
CelestasMod.OBSIDIAN_ODDS = 6
CelestasMod.OBSIDIAN_ROLL_ID = "celesta_obsidian"

--- The ranks this card could become: every rank its suit has a card for, but its own.
---
--- Sorted, because pseudorandom_element picks by position and pairs() has no order, so
--- the same seed would otherwise answer differently from one run of the game to the next.
local function obsidian_ranks(card)
    local out = {}
    local suit = card.base and SMODS.Suits[card.base.suit]
    if not suit then return out end
    for key, rank in pairs(SMODS.Ranks) do
        if key ~= card.base.value and G.P_CARDS[suit.card_key .. "_" .. rank.card_key] then
            out[#out + 1] = key
        end
    end
    table.sort(out)
    return out
end

CelestasMod.obsidian_ranks = obsidian_ranks

local OBSIDIAN_KEY = CelestasMod.ENHANCEMENT_KEYS.Obsidian

SMODS.Enhancement {
    key = "obsidian",
    atlas = "enh_obsidian",
    pos = { x = 0, y = 0 },
    discovered = true,

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(
            card, 1, CelestasMod.OBSIDIAN_ODDS, CelestasMod.OBSIDIAN_ROLL_ID)
        return { vars = { CelestasMod.OBSIDIAN_X, n, d } }
    end,

    calculate = function(self, card, context)
        if context.main_scoring and context.cardarea == G.play then
            CelestasMod.play_scoring_sound(CelestasMod.ENHANCEMENT_SOUNDS.Limestone)

            local x = CelestasMod.OBSIDIAN_X
            if SMODS.pseudorandom_probability(
                    card, CelestasMod.OBSIDIAN_ROLL_ID, 1, CelestasMod.OBSIDIAN_ODDS) then
                return { x_chips = x, x_mult = x }
            end
            if pseudorandom(pseudoseed("celesta_obsidian_pick")) < 0.5 then
                return { x_chips = x }
            end
            return { x_mult = x }
        end

        -- Its rank is changed by the mod-level pass below, which reaches the whole deck. Not
        -- here: this is only ever asked of cards in hand, and a card asked by both would
        -- change twice.
    end,
}

--- Changes this card's rank to another its suit has a card for. The suit is left exactly as
--- it is - change_base is told nothing about it - and a card with nowhere to go stays put.
local function rerank(card)
    local ranks = obsidian_ranks(card)
    if #ranks == 0 then return end
    local rank = pseudorandom_element(ranks, pseudoseed("celesta_obsidian_rank"))
    G.E_MANAGER:add_event(Event {
        func = function()
            SMODS.change_base(card, nil, rank)
            card:juice_up(0.3, 0.5)
            return true
        end
    })
end

--------------------------------------------------------------------------------
-- The end of the round, over the whole deck
--------------------------------------------------------------------------------
--
-- Every Obsidian card in the run, wherever it is: in hand, in the draw pile, in the discard.
-- G.playing_cards is the run's whole deck (see CelestasMod.prune_unrenderable_cards in
-- globals.lua for what it is), so a card does not have to be drawn to be reached.
--
-- main_eval is what makes this once per round: the end-of-round evaluation is raised through
-- the Joker row, the playing cards and the individual targets in turn, and only the last of
-- those is this mod's. game_over is skipped - a run that has just been lost has no next round
-- for the rank to matter in.
--
-- Chained, so a mod-level calculate someone else gives this mod later is not lost.

local celesta_obsidian_mod_calculate = SMODS.current_mod.calculate

SMODS.current_mod.calculate = function(self, context)
    if context.end_of_round and context.main_eval and not context.game_over then
        for _, card in ipairs(G.playing_cards or {}) do
            if SMODS.has_enhancement(card, OBSIDIAN_KEY) then rerank(card) end
        end
    end
    if celesta_obsidian_mod_calculate then
        return celesta_obsidian_mod_calculate(self, context)
    end
end
