--- TATTERED CARDS
---
--- A playing card wears out after it has been scored somewhere between 20 and
--- 30 times in a run. Once it does, everything it contributes is worth half:
--- its rank, its enhancement, its edition, its seal.
---
--- Worked example, the one this was built against - a Lucky 7 of Clubs with a
--- Polychrome edition, tattered:
---     7 Chips           -> 3.5 Chips
---     Polychrome X1.5   -> X1.25 Mult
---     1 in 5 for +20    -> 1 in 5 for +10 Mult
---     1 in 15 for $20   -> 1 in 15 for $10
--- Note what does NOT change: the odds. Halving a probability would make the
--- card fire half as often on top of paying half as much, which is a much
--- harsher penalty than the one described.

CelestasMod.Tattered = {}
local Tattered = CelestasMod.Tattered

-- The window the wear-out threshold is rolled from, inclusive at both ends.
Tattered.MIN_SCORES = 20
Tattered.MAX_SCORES = 30
Tattered.SCALE = 0.5

local TATTER_SEED = "celesta_tatter"

-- Resolved at load: SMODS.current_mod is only valid while the mod is loading,
-- and the draw hook below runs every frame long afterwards.
local PREFIX = SMODS.current_mod.prefix
local ATLAS = {
    tatter    = PREFIX .. "_tatter",
    lucky     = PREFIX .. "_lucky_card_tatter",
    limestone = PREFIX .. "_limestone_tatter",
}

--------------------------------------------------------------------------------
-- What the wear is called
--------------------------------------------------------------------------------

-- A worn card is described by what it is made of. Stone, Glass, Limestone and
-- Eutrophic crack; Driftwood chips; everything else tatters. Purely cosmetic -
-- all three are the same mechanic.
local CRACKED = { m_stone = true, m_glass = true }
local CHIPPED = {}

--- Filled in after the enhancements have registered, since the keys are
--- prefixed and built at that point.
function Tattered.classify_enhancements()
    local keys = CelestasMod.ENHANCEMENT_KEYS or {}
    if keys.Limestone then CRACKED[keys.Limestone] = true end
    if keys.Eutrophic then CRACKED[keys.Eutrophic] = true end
    if keys.Driftwood then CHIPPED[keys.Driftwood] = true end
end

--- "tattered", "cracked" or "chipped" for a given card.
function Tattered.word(card)
    local center = card and card.config and card.config.center
    local key = center and center.key
    if key then
        if CRACKED[key] then return "cracked" end
        if CHIPPED[key] then return "chipped" end
    end
    return "tattered"
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

--- Only real playing cards wear out. Jokers and consumables are excluded by
--- set, so a Joker that happens to be scored never picks up a counter.
local function is_playing_card(card)
    if not (card and card.ability and card.base) then return false end
    local set = card.ability.set
    return set ~= "Joker" and card.config and card.config.center
end

function Tattered.is_tattered(card)
    return card and card.ability and card.ability.celesta_tattered == true
end

--- Rolls this card's wear-out point the first time it scores.
--- Rolled per card rather than fixed, so a deck does not all fail at once, and
--- stored on the card so it survives a save: re-rolling on load would let a
--- player reload away a card that was about to go.
local function threshold(card)
    local existing = card.ability.celesta_tatter_at
    if type(existing) == "number" then return existing end
    local span = Tattered.MAX_SCORES - Tattered.MIN_SCORES + 1
    local ok, roll = pcall(pseudorandom, pseudoseed(TATTER_SEED))
    local at = Tattered.MIN_SCORES
    if ok and type(roll) == "number" then
        at = Tattered.MIN_SCORES + math.floor(roll * span)
        if at > Tattered.MAX_SCORES then at = Tattered.MAX_SCORES end
    end
    card.ability.celesta_tatter_at = at
    return at
end

--- True for a card Dejavudea has protected. Stored on the card, so the
--- protection lasts the rest of the run and survives a save.
function Tattered.is_immune(card)
    return card and card.ability and card.ability.celesta_tatter_immune == true
end

--- Undoes any wear on a card and protects it from wearing again.
--- Returns true only when there was wear to undo, so a caller can tell the
--- difference between repairing a card and merely insuring one.
function Tattered.repair(card)
    if not is_playing_card(card) then return false end
    card.ability.celesta_tatter_immune = true
    if card.ability.celesta_tattered then
        card.ability.celesta_tattered = nil
        -- The counter goes too. It is dead weight while the card is immune,
        -- and clearing it means a card that somehow lost immunity starts over
        -- rather than tattering again on its next trigger.
        card.ability.celesta_scored = 0
        return true
    end
    return false
end

--- Counts one scoring and reports whether the card just wore out.
function Tattered.record_score(card)
    if not is_playing_card(card) or Tattered.is_tattered(card) then return false end
    if Tattered.is_immune(card) then return false end
    local count = (card.ability.celesta_scored or 0) + 1
    card.ability.celesta_scored = count
    if count < threshold(card) then return false end
    card.ability.celesta_tattered = true
    return true
end

--------------------------------------------------------------------------------
-- Halving
--------------------------------------------------------------------------------

-- Additive contributions are simply halved.
local ADDITIVE = {
    "chips", "h_chips", "chip_mod",
    "mult", "h_mult", "mult_mod",
    "p_dollars", "dollars", "h_dollars",
}

-- Multiplicative ones have the part ABOVE 1 halved, which is what makes a
-- Polychrome X1.5 read as X1.25 rather than X0.75. Halving the multiplier
-- itself would turn most editions into a penalty worse than removing them.
local MULTIPLICATIVE = {
    "x_chips", "xchips", "Xchip_mod",
    "x_mult", "Xmult", "xmult", "x_mult_mod", "Xmult_mod",
    "h_x_mult",
}

--- The sub-tables of an eval_card result that belong to the card itself.
---
--- Deliberately NOT 'jokers', 'retriggers' or 'individual': those are other
--- jokers reacting to this card being scored, and a joker's payout is not the
--- card's stat. Nor 'repetitions' - halving a retrigger count would round a
--- red seal down to nothing.
local OWNED = { "playing_card", "enhancement", "edition", "seals", "end_of_round" }

local function halve(effect)
    if type(effect) ~= "table" then return end
    for _, key in ipairs(ADDITIVE) do
        local v = effect[key]
        if type(v) == "number" and v ~= 0 then
            effect[key] = v * Tattered.SCALE
        end
    end
    for _, key in ipairs(MULTIPLICATIVE) do
        local v = effect[key]
        if type(v) == "number" and v > 1 then
            effect[key] = 1 + (v - 1) * Tattered.SCALE
        end
    end
end

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

-- eval_card is the one place every contribution a card makes passes through,
-- and it is also the per-trigger pass, so it does both jobs here.
--
-- HALVING. SMODS assembles ret.playing_card from the get_chip_* getters,
-- ret.edition from get_edition, and ret.seals and ret.enhancement alongside
-- them, so halving here catches the rank, the enhancement, the edition and
-- the seal together. The getters themselves are deliberately left alone:
-- SMODS reads them into that same table, so halving both would quarter
-- every value.
--
-- COUNTING. SMODS.score_card sets context.main_scoring once per repetition of
-- its reps loop, so a card retriggered four times by Hanging Chad arrives here
-- four times and is counted four times. Three conditions gate it:
--
--   * main_scoring - the trigger itself, not the repetition or destroy passes
--   * cardarea == G.play - calculate_main_scoring runs over EVERY playing-card
--     area and evaluates every card in each. A scored card arrives as G.play,
--     a played card outside the poker hand as the string 'unscored', and every
--     card sitting in hand as G.hand. Only the first was scored.
--   * not extra_enhancement - SMODS.calculate_quantum_enhancements re-enters
--     eval_card once per extra enhancement with main_scoring still set, which
--     would count a single trigger several times over.
local celesta_tatter_eval_card_ref = eval_card
function eval_card(card, context)
    local ret, post = celesta_tatter_eval_card_ref(card, context)

    -- Read BEFORE the count below, so the very trigger that wears a card out
    -- still pays in full and the halving starts from the next one.
    if Tattered.is_tattered(card) and type(ret) == "table" then
        for _, key in ipairs(OWNED) do halve(ret[key]) end
    end

    if context and context.main_scoring and context.cardarea == G.play
        and not context.extra_enhancement then
        if Tattered.record_score(card) then
            card_eval_status_text(card, "extra", nil, nil, nil, {
                message = localize("celesta_" .. Tattered.word(card)),
                colour = G.C.FILTER,
            })
        end
    end

    return ret, post
end

local tatter_sprites = {}

--- Which overlay a card wears. Lucky and Limestone have their own so the
--- tears sit clear of the art those two already carry.
local function overlay_atlas(card)
    local key = card.config and card.config.center and card.config.center.key
    if key == "m_lucky" then return ATLAS.lucky end
    if key == (CelestasMod.ENHANCEMENT_KEYS or {}).Limestone then return ATLAS.limestone end
    return ATLAS.tatter
end

local celesta_tatter_card_draw_ref = Card.draw
function Card:draw(layer)
    celesta_tatter_card_draw_ref(self, layer)

    if not Tattered.is_tattered(self) then return end
    if self.facing == "back" or layer == "shadow" then return end

    local atlas_key = overlay_atlas(self)
    local atlas = G.ASSET_ATLAS[atlas_key]
    if not atlas then return end
    if not tatter_sprites[atlas_key] then
        tatter_sprites[atlas_key] = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, { x = 0, y = 0 })
    end
    local sprite = tatter_sprites[atlas_key]
    sprite.role.draw_major = self
    sprite:draw_shader("dissolve", nil, nil, nil, self.children.center)
end

--------------------------------------------------------------------------------
-- Saying so on the card
--------------------------------------------------------------------------------

-- A worn card said nothing about being worn and still advertised its full
-- numbers, so a tattered Lucky Card read exactly like a fresh one while paying
-- half. Two separate gaps: the badge, and the values.

-- The badge colour. get_badge_colour builds G.BADGE_COL lazily on its first
-- call, so the reference is called FIRST and only then overridden - assigning
-- G.BADGE_COL directly would replace vanilla's table before it existed and
-- lose every stock badge colour with it.
local WEAR_BADGE_COLOUR = { 0.55, 0.42, 0.35, 1 }

-- Defined at boot in UI_definitions.lua, well before mods load. Guarded
-- anyway: wrapping a nil would swap a missing colour for a crash.
local celesta_wear_badge_colour_ref = get_badge_colour
if celesta_wear_badge_colour_ref then
function get_badge_colour(key)
    local colour = celesta_wear_badge_colour_ref(key)
    if key == "celesta_tattered" or key == "celesta_cracked"
        or key == "celesta_chipped" then
        return WEAR_BADGE_COLOUR
    end
    return colour
end
end

-- Steamodded patches generate_card_ui to take a NINTH argument, the card being
-- described (lovely/center.toml). Declaring only the stock eight drops it and
-- crashes the game on the next hover, so it is named here and everything past
-- it forwarded untouched.
local celesta_wear_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges,
                          hide_desc, main_start, main_end, card, ...)
    if not (card and Tattered.is_tattered(card) and type(_c) == "table") then
        return celesta_wear_card_ui_ref(_c, full_UI_table, specific_vars, card_type,
                                        badges, hide_desc, main_start, main_end,
                                        card, ...)
    end

    -- The badge, so the card says what happened to it. Copied, so the caller's
    -- list is not appended to twice if the tooltip is rebuilt.
    local list = {}
    for _, badge in ipairs(badges or {}) do list[#list + 1] = badge end
    list[#list + 1] = "celesta_" .. Tattered.word(card)
    badges = list

    if type(specific_vars) == "table" then
        local copy = {}
        for k, v in pairs(specific_vars) do copy[k] = v end

        -- The "+N chips" line is not a loc_var at all - it is drawn from
        -- specific_vars.nominal_chips, which vanilla fills from base.nominal.
        if type(copy.nominal_chips) == "number" then
            copy.nominal_chips = copy.nominal_chips * Tattered.SCALE
        end

        -- The enhancement's own numbers, by the same markup rule the scoring
        -- uses: the Mult and the money halve, the odds do not.
        if type(copy.vars) == "table" then
            local marked = CelestasMod.scalable_vars(_c.set, _c.key)
            if marked then
                copy.vars = CelestasMod.scale_vars(copy.vars, marked, Tattered.SCALE)
            end
        end
        specific_vars = copy
    end

    return celesta_wear_card_ui_ref(_c, full_UI_table, specific_vars, card_type,
                                    badges, hide_desc, main_start, main_end,
                                    card, ...)
end

Tattered.classify_enhancements()
