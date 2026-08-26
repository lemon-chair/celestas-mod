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

-- How far Exo's frame extends past the card. Sprite:draw_from scales by
-- (1 + ms), and the art is 84 wide against a 71 wide card, so 84/71 - 1 is
-- its drawn-at-intended-size value. Nudge this to taste - it is the only
-- number controlling how thick the border reads.
CelestasMod.EXO_OVERHANG = 84 / 71 - 1

local exo_frame_sprite

SMODS.Enhancement {
    key = "exo",
    atlas = "enh_exo",
    pos = { x = 0, y = 0 },
    discovered = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    -- Called from the card's draw pass. The centre sprite is only the card
    -- body; the frame is drawn here instead so it can be larger than the card,
    -- the same way a Legendary Joker's soul overlay is drawn.
    draw = function(self, card, layer)
        local atlas = G.ASSET_ATLAS[SMODS.current_mod.prefix .. "_enh_exo_frame"]
        if not atlas then return end
        if not exo_frame_sprite then
            exo_frame_sprite = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, { x = 0, y = 0 })
            exo_frame_sprite.role.draw_major = card
        end
        exo_frame_sprite.role.draw_major = card
        exo_frame_sprite:draw_shader("dissolve", nil, nil, nil,
            card.children.center, CelestasMod.EXO_OVERHANG, 0)
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
            -- An enhancement reads its own config off card.ability.extra, so
            -- handing it Eutrophic's ability crashes anything expecting its
            -- own fields - Cryptid's Abstract does exactly that. Lend it the
            -- copied card's ability and centre for the duration.
            --
            -- The ability is a COPY: an enhancement that scales itself would
            -- otherwise write that growth onto the card being copied, every
            -- time Eutrophic evaluated.
            local saved_center, saved_ability = card.config.center, card.ability
            card.config.center = center
            local borrowed = copy_table(left.ability)
            -- copy_table is shallow, so `extra` would still be the copied
            -- card's own table and a scaling enhancement would write its
            -- growth straight back onto it. That is the table effects
            -- actually mutate, so it needs its own copy.
            if type(left.ability.extra) == "table" then
                borrowed.extra = copy_table(left.ability.extra)
            end
            card.ability = borrowed

            local ok, copied = pcall(center.calculate, center, card, context)

            card.config.center, card.ability = saved_center, saved_ability

            if not ok then
                -- Copying arbitrary third-party enhancements is best-effort;
                -- one that cannot run against a borrowed card must not take
                -- the run down with it.
                CelestasMod.warn_once(
                    "eutrophic_copy_" .. tostring(center.key),
                    ("Eutrophic could not copy %s: %s")
                        :format(tostring(center.key), tostring(copied)))
            elseif copied then
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

--------------------------------------------------------------------------------
-- Driftwood: counting as any rank
--------------------------------------------------------------------------------
--
-- SMODS has `any_suit` for wild suits but no rank equivalent, and rank is not
-- resolved in one place: get_X_same compares get_id() pairwise, while
-- get_straight buckets cards by rank key. Patching both invites double
-- counting - a card added to every bucket appears at every position of a
-- straight, and a wild shared between two rank groups can invent a Two Pair
-- that the player cannot actually make.
--
-- So rather than teach each evaluator about wilds, resolve the wild BEFORE
-- evaluation: temporarily give every Driftwood in the hand a concrete rank,
-- run the untouched evaluator, and keep whichever rank produced the best hand.
-- Every hand type then works with no changes and nothing can be counted twice.
--
-- All Driftwoods in a hand take the SAME rank. Searching per-card assignments
-- is 13^n evaluations; one shared rank is 13 and still covers what players
-- actually do - completing a pair, trips or quads, five of a kind from a hand
-- of Driftwoods, or filling a single gap in a straight. Two Driftwoods filling
-- two DIFFERENT gaps in one straight is the case this does not find.
--
-- Only ever runs when a Driftwood is actually in the hand, so normal play
-- costs one extra table scan and nothing else.

local function is_driftwood(card)
    return card and card.config and card.config.center
        and card.config.center.key == CelestasMod.ENHANCEMENT_KEYS.Driftwood
end

--- Index of the best hand in a results table, by G.handlist order (1 = best).
local function hand_index(results)
    if not results or not results.top then return math.huge end
    for i, name in ipairs(G.handlist) do
        if results[name] and results[name] == results.top then return i end
    end
    return math.huge
end

local evaluate_poker_hand_ref = evaluate_poker_hand
function evaluate_poker_hand(hand)
    local wilds = {}
    for _, card in ipairs(hand or {}) do
        if is_driftwood(card) then wilds[#wilds + 1] = card end
    end
    if #wilds == 0 then return evaluate_poker_hand_ref(hand) end

    -- Remember what to put back. base.value matters as well as base.id:
    -- get_straight looks ranks up by key, not just by numeric id.
    local saved = {}
    for i, card in ipairs(wilds) do
        saved[i] = { id = card.base.id, value = card.base.value }
    end
    local function restore()
        for i, card in ipairs(wilds) do
            card.base.id, card.base.value = saved[i].id, saved[i].value
        end
    end

    local best_rank, best_index = nil, math.huge
    for _, rank_key in ipairs(SMODS.Rank.obj_buffer) do
        local rank = SMODS.Ranks[rank_key]
        if rank and rank.id then
            for _, card in ipairs(wilds) do
                card.base.id, card.base.value = rank.id, rank_key
            end
            local index = hand_index(evaluate_poker_hand_ref(hand))
            if index < best_index then
                best_index, best_rank = index, rank_key
            end
        end
    end

    if not best_rank then
        restore()
        return evaluate_poker_hand_ref(hand)
    end

    -- Re-apply the winner and evaluate once more, so the results returned are
    -- the ones the rest of scoring will use.
    local winner = SMODS.Ranks[best_rank]
    for _, card in ipairs(wilds) do
        card.base.id, card.base.value = winner.id, best_rank
    end
    local results = evaluate_poker_hand_ref(hand)

    -- Put the real rank back: the Driftwood keeps its own nominal chip value
    -- and reads as its printed rank to everything downstream.
    restore()
    return results
end

--------------------------------------------------------------------------------
-- Driftwood: show the suit in the centre, the way an Ace does
--------------------------------------------------------------------------------
--
-- A card's front sprite is picked from its rank+suit, so a Driftwood would
-- otherwise print whatever rank it happens to carry - misleading for a card
-- that counts as all of them. Pointing the front at the Ace of the same suit
-- gives the large central pip while keeping the suit visible.

-- Index into the driftwood_fronts atlas, matching SUIT_ORDER in
-- tools/gen_driftwood_fronts.py.
local DRIFTWOOD_SUIT_POS = { Hearts = 0, Clubs = 1, Diamonds = 2, Spades = 3 }
local DRIFTWOOD_FRONT_ATLAS = SMODS.current_mod.prefix .. "_driftwood_fronts"

local set_sprites_ref = Card.set_sprites
function Card:set_sprites(_center, _front)
    set_sprites_ref(self, _center, _front)

    local center = _center or (self.config and self.config.center)
    if not center or center.key ~= CelestasMod.ENHANCEMENT_KEYS.Driftwood then return end
    if not self.children or not self.children.front then return end

    -- Repoint the front at the stripped-Ace sheet rather than swapping in a
    -- real Ace: that gave the central pip but printed an "A" in the corners,
    -- which is wrong for a card that counts as every rank.
    local suit = (_front and _front.suit) or (self.base and self.base.suit)
    local pos = DRIFTWOOD_SUIT_POS[suit]
    local atlas = G.ASSET_ATLAS[DRIFTWOOD_FRONT_ATLAS]
    -- Modded suits are not in the sheet; those keep their normal front.
    if not pos or not atlas then return end

    self.children.front.atlas = atlas
    self.children.front:set_sprite_pos({ x = pos, y = 0 })
end
