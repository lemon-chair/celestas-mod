--- GLOBALS
--- Custom colours usable in localization text as {C:celesta_pink} etc.

G.C.CELESTA = {
    PINK    = HEX("FF6FB5"),
    PURPLE  = HEX("6C5CE7"),
    TEAL    = HEX("00B8A9"),
    GOLD    = HEX("F2C94C"),
    WHITE   = HEX("FFFFFF"),
}

--------------------------------------------------------------------------------
-- Jokers that are not card-shaped
--------------------------------------------------------------------------------
--
-- Boosfer's art is a circle floating in a transparent cell, which is all the
-- vanilla editions need: foil, holo, polychrome and negative all end with
-- `tex.a = min(tex.a, ...)`, so the shine is bounded by the sprite's own alpha
-- and stops at the edge of the ball rather than filling a card-shaped rect.
--
-- Anything drawn OVER the card is the exception, because it brings its own
-- alpha - this mod's frost pane is card-shaped and would hang in the air
-- around the ball. Those overlays ask here and take the round shape instead.
--
-- Keys are written out rather than built from the prefix: this file is read
-- during load, and hardcoding is what the rest of the mod does where a key has
-- to exist before SMODS.current_mod is safe to touch.
CelestasMod.ROUND_JOKERS = {
    j_celesta_boosfer = true,
    j_celesta_red_boosfer = true,
}

--- True for a card whose art is a circle rather than a card.
function CelestasMod.is_round_joker(card)
    local key = card and card.config
        and (card.config.center_key or (card.config.center and card.config.center.key))
    return (key and CelestasMod.ROUND_JOKERS[key]) and true or false
end

--------------------------------------------------------------------------------
-- Rewriting a card that is being played
--------------------------------------------------------------------------------

--- Runs `fn` without letting the Blind re-judge `card` as one already played
--- this Ante.
---
--- Card:set_base and Card:set_ability BOTH end with
--- `G.GAME.blind:debuff_card(self)` (card.lua:143 and :365), and The Pillar
--- debuffs anything carrying ability.played_this_ante - a flag every card in
--- the hand is given before evaluate_play has run at all
--- (state_events.lua:481). Vanilla never re-judges a card during the hand it
--- is being played in, so nothing in the base game trips over it; anything
--- that converts or enhances a played card does, and the whole hand goes dead.
---
--- Only that one flag is hidden, and only across the call. Every other rule a
--- Blind has - a debuffed suit, rank, face or enhancement - is still applied,
--- and applied to the card as it now IS, which is what should happen to a card
--- rewritten into the thing the Blind is punishing. The flag goes straight
--- back, so the card is still debuffed at the next Blind, which is what The
--- Pillar is for.
function CelestasMod.unjudged(card, fn)
    local ability = card and card.ability
    local flag = ability and ability.played_this_ante
    if ability then ability.played_this_ante = nil end
    local ok, err = pcall(fn)
    if ability then ability.played_this_ante = flag end
    if not ok then error(err, 0) end
end

-- Hooks

local loc_colour_ref = loc_colour
function loc_colour(_c, _default)
    if not G.ARGS.LOC_COLOURS then
        loc_colour_ref()
    end
    G.ARGS.LOC_COLOURS.celesta_pink   = G.C.CELESTA.PINK
    G.ARGS.LOC_COLOURS.celesta_purple = G.C.CELESTA.PURPLE
    G.ARGS.LOC_COLOURS.celesta_teal   = G.C.CELESTA.TEAL
    G.ARGS.LOC_COLOURS.celesta_gold   = G.C.CELESTA.GOLD
    G.ARGS.LOC_COLOURS.celesta_white  = G.C.CELESTA.WHITE
    return loc_colour_ref(_c, _default)
end

--- Log a message once per key, so a per-frame failure reports itself without
--- flooding the log. Used where this mod interoperates with other mods and
--- cannot assume their internals.
local warned = {}
function CelestasMod.warn_once(key, message)
    if warned[key] then return end
    warned[key] = true
    sendWarnMessage(message, "CelestasMod")
end

--- True while a played hand is actually being scored, rather than previewed.
---
--- modify_scoring_hand - the context a Joker answers to widen the scoring hand,
--- the way Splash does - is asked in TWO places, not one. The scoring pass asks
--- it (state_events.lua:753), and so does Blind:debuff_hand through Steamodded
--- (overrides.lua:2637). debuff_hand is called on every change to the SELECTION,
--- from CardArea:parse_highlighted (cardarea.lua:208), to work out whether the
--- hand shows as debuffed before it is played.
---
--- So a Joker answering that context answers it every time a card is clicked,
--- and an answer is a TRIGGER: Steamodded fires post_trigger for it
--- (common_events.lua:787) and applies whatever that returns. Cryptid's Wario
--- pays $3 per Joker triggered, so selecting two cards paid out.
---
--- Asked as a game state rather than through context.in_scoring, which the
--- scoring pass sets but play-time debuff_hand does not: the Blind should still
--- see the widened hand when it decides. G.STATE is HAND_PLAYED for both of
--- those and SELECTING_HAND for the preview.
function CelestasMod.hand_is_being_played()
    return G ~= nil and G.STATES ~= nil and G.STATE == G.STATES.HAND_PLAYED
end

--------------------------------------------------------------------------------
-- Finding a Joker that may be half of a merge
--------------------------------------------------------------------------------
--
-- SMODS.find_card matches card.config.center.key (utils.lua), and a Joker
-- absorbed by a Bind does not have one: the merged card wears the HOST's
-- centre and keeps the other half's key and ability under
-- ability.celesta_bind. So an absorbed Yoclesh, Kael or Vedal is invisible to
-- it, and every "is one of these in play" test silently answered no - which is
-- the whole of what those Jokers do.
--
-- Kept as this mod's own rather than patching SMODS.find_card, which other
-- mods and Steamodded itself call for their own reasons: a merged card
-- appearing in an answer that was not asking about merges is a bug somewhere
-- else, not a fix here.

--- Every copy of `key` in the Joker row, merged halves included.
---
--- Each entry is { card = the card sitting in the row, ability = that HALF's
--- ability table }. Those are not the same table for an absorbed half, and a
--- Joker that SCALES has to write to the half's or it grows the host instead.
---
--- Debuffed cards are left out unless asked for, which is what SMODS.find_card
--- does and what every caller here was already relying on.
function CelestasMod.find_joker(key, count_debuffed)
    local out = {}
    local Bind = CelestasMod.Bind
    local areas = (SMODS.get_card_areas and SMODS.get_card_areas("jokers"))
        or { G.jokers }

    for _, area in ipairs(areas) do
        for _, card in ipairs((area and area.cards) or {}) do
            -- A replacing pair speaks for both halves, so neither of them is
            -- in play as itself - the same test with_partner makes before it
            -- runs an absorbed half's hooks at all.
            local replaced = Bind and Bind.replacing_special
                and Bind.replacing_special(card)
            if not replaced and (count_debuffed or not card.debuff) then
                local center = card.config and card.config.center
                if center and center.key == key then
                    out[#out + 1] = { card = card, ability = card.ability }
                elseif Bind and Bind.is_merged and Bind.is_merged(card)
                    and card.ability.celesta_bind.key == key then
                    out[#out + 1] = {
                        card = card,
                        ability = card.ability.celesta_bind.ability,
                    }
                end
            end
        end
    end

    return out
end

--- True when at least one is in play and able to act.
function CelestasMod.joker_in_play(key)
    return next(CelestasMod.find_joker(key)) ~= nil
end

--------------------------------------------------------------------------------
-- What a merge must not carry across
--------------------------------------------------------------------------------
--
-- A Joker that hands the RUN something - Joker slots, a selection limit, shop
-- slots - records how much it has handed over on its own ability, so it can
-- follow the number when it changes and give back exactly what it gave. That
-- record is a receipt for something the RUN is holding, not part of what the
-- Joker is.
--
-- At a merge the absorbed half's ability is copied onto the host and the
-- absorbed card is then dissolved, which runs its remove_from_deck and hands
-- everything back. Copying the receipt across means the host believes it has
-- already granted what has just been taken away, and grants nothing: a merged
-- SmittenSeraph gave no slots at all, and unmerging it would have taken three
-- more away.
--
-- So these are dropped on the way in. The host starts owing nothing, grants
-- afresh, and the absorbed card's own release cancels its own grant.
--
-- test_bind_grants.py reads the field names back out of jokers/implemented.lua,
-- so a fifth one added there and not here fails rather than going quiet.
CelestasMod.GRANT_LEDGERS = {
    "celesta_seraph_granted",     -- SmittenSeraph: Joker and consumable slots
    "celesta_shiabun_granted",    -- Shiabun and Eidolon Wyrm: selection limit
    "celesta_aethal_granted",     -- Aethal: shop slots
}

--------------------------------------------------------------------------------
-- Config backfill
--------------------------------------------------------------------------------
--
-- A card stores its own copy of its centre's config in card.ability.extra, and
-- that copy is written into the save. So a joker obtained BEFORE its config
-- changed keeps the old fields forever: when a placeholder carrying
-- extra = { mult = 4 } is implemented as extra = { chips = 0, chip_gain = 5 },
-- its loc_vars asks for chip_gain, gets nil, and the description prints "nil".
-- The same nil reaches calculate, so it is not only cosmetic.
--
-- Rather than making every loc_vars defensive one at a time, top up any of this
-- mod's cards with the keys its centre defines but the card is missing.
-- Existing values always win, so a joker that has scaled keeps its progress.

--- The mod table, captured while loading: SMODS.current_mod is only valid
--- then, and backfill runs long afterwards.
CelestasMod.MOD = SMODS.current_mod

--- Fill in any config keys a card is missing from its centre's defaults.
--- Returns the keys it added, for logging.
function CelestasMod.backfill_config(card)
    local center = card and card.config and card.config.center
    if not center then return end
    -- Only this mod's objects: another mod's card is not ours to repair.
    -- SMODS stamps every registered object with the mod that declared it,
    -- which is exact - matching on the key string would also catch anything
    -- that merely happens to contain the prefix.
    if center.mod ~= CelestasMod.MOD then return end
    if type(center.config) ~= "table" or type(center.config.extra) ~= "table" then return end

    card.ability = card.ability or {}
    if type(card.ability.extra) ~= "table" then card.ability.extra = {} end

    local added
    for key, value in pairs(center.config.extra) do
        if card.ability.extra[key] == nil then
            card.ability.extra[key] = value
            added = added and (added .. ", " .. key) or key
        end
    end
    return added
end

local card_load_ref = Card.load
function Card:load(cardTable, other_card)
    card_load_ref(self, cardTable, other_card)
    local added = CelestasMod.backfill_config(self)
    if added then
        CelestasMod.warn_once("backfill_" .. tostring(self.config.center.key),
            ("Filled in missing config on %s: %s")
                :format(tostring(self.config.center.key), added))
    end
end

--- True when a centre was registered by this mod.
--- SMODS stamps every object it registers with the mod that declared it, which
--- is a far more reliable test than matching on the key prefix - a key can be
--- taken over, and other mods can carry a similar prefix.
function CelestasMod.is_ours(center)
    return center ~= nil and center.mod ~= nil and center.mod == CelestasMod.MOD
end

--------------------------------------------------------------------------------
-- Which numbers in a description may be scaled
--------------------------------------------------------------------------------

-- A card's loc_vars is an unlabelled ordered list. Lucky Card's is
--     { probability, 5, 20, 15, 20 }
-- printed as "#1# in #2# chance for +#3# Mult" and "#1# in #4# to win $#5#":
-- only #3# and #5# are values, #2# and #4# are odds. Nothing in the list says
-- which is which.
--
-- The description text does. Balatro marks every number with the colour it
-- prints in, and a value is always written in mult, chip or money markup while
-- odds are green and counts are attention. So the markup immediately before
-- each #n# decides whether it may be scaled.
local SCALABLE_MARKUP = { "mult", "chips", "money" }

--- Which loc_var indices a centre prints as a scalable value, and how.
--- Returns index -> "mult" for a multiplier (X:mult, X:chips) or "add" for a
--- plain amount (C:mult, C:chips, C:money); nil when there is nothing to scale
--- or no description to read.
---
--- The two are not scaled the same way, which is why they are told apart here
--- rather than lumped together: halving Glass's X2 Mult means X1.5, not X1.
function CelestasMod.scalable_vars(set, key)
    local descriptions = G.localization and G.localization.descriptions
    local block = descriptions and set and descriptions[set]
    local entry = block and key and block[key]
    if not (entry and entry.text) then return nil end

    local marked = nil
    for _, line in ipairs(entry.text) do
        -- The nearest {markup} before a #n#, with no other placeholder or
        -- brace between them, is the one it prints in.
        for markup, index in string.gmatch(line, "{([^}]*)}[^#{]*#(%d+)#") do
            local scalable = false
            for _, want in ipairs(SCALABLE_MARKUP) do
                if string.find(markup, want, 1, true) then scalable = true break end
            end
            if scalable then
                marked = marked or {}
                -- "X:mult" is a multiplier, "C:mult" an amount.
                marked[tonumber(index)] =
                    string.find(markup, "X:", 1, true) and "mult" or "add"
            end
        end
    end
    return marked
end

--- Every loc_var a centre prints, marked the same way - not only the ones
--- written in a value colour.
---
--- Vedal's rule is every numerical value on this mod's Jokers, so the markup
--- filter above is the wrong question for it: a count of cards and a chance
--- are numbers a Joker gives too. This marks all of them.
---
--- The one exclusion is a printed CHANCE - both halves of "#1# in #2#".
--- Scaling both leaves the odds exactly where they were while making the card
--- claim they moved; scaling the numerator alone would be right, except that
--- a chance is already scaled a layer down, in mod_probability, which is what
--- both the roll and the number loc_vars asks for come through. Touching it
--- again here would show one chance and roll another.
function CelestasMod.numeric_vars(set, key)
    local descriptions = G.localization and G.localization.descriptions
    local block = descriptions and set and descriptions[set]
    local entry = block and key and block[key]
    if not (entry and entry.text) then return nil end

    local marked, chances = nil, {}
    for _, line in ipairs(entry.text) do
        for index in string.gmatch(line, "#(%d+)#") do
            marked = marked or {}
            marked[tonumber(index)] = "add"
        end
        -- "#1# in #2#", however it is coloured in between.
        for first, second in string.gmatch(
                line, "#(%d+)#[^#]-%f[%a]in%f[%A][^#]-#(%d+)#") do
            chances[tonumber(first)] = true
            chances[tonumber(second)] = true
        end
    end
    if not marked then return nil end
    for index in pairs(chances) do marked[index] = nil end
    return next(marked) and marked or nil
end

--- A copy of `vars` with the marked entries scaled.
---
--- `multiplier_excess` selects how a multiplier is scaled, and must match how
--- the same value is scaled when it SCORES, or the card advertises one number
--- and pays another:
---   false - the multiplier itself moves.       Vedal: X3 -> X4.5
---   true  - only the part above 1 moves.       Tattered: X2 -> X1.5
---
--- Copied rather than scaled in place: these come straight off a card's
--- ability in some cases, and scaling that would change the real thing every
--- time the card was hovered.
function CelestasMod.scale_vars(vars, marked, scale, multiplier_excess)
    -- Every key first, not just the numbered ones. A loc_vars list carries
    -- named fields alongside its numbered slots - `colours` above all, which
    -- is what a {V:1} placeholder reads its colour out of - and rebuilding the
    -- table from ipairs alone dropped them, leaving localize to index a nil
    -- `colours` and take the game down on hover (misc_functions.lua:2048).
    local out = {}
    for k, v in pairs(vars) do out[k] = v end

    for i, v in ipairs(vars) do
        local kind = marked[i]
        -- Only numbers. Several jokers pass a STRING built with
        -- ''..probabilities.normal, and arithmetic on it would error.
        if kind and type(v) == "number" then
            if kind == "mult" and multiplier_excess and v > 1 then
                out[i] = 1 + (v - 1) * scale
            else
                out[i] = v * scale
            end
        else
            out[i] = v
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- The deck preview, and cards it cannot draw
--------------------------------------------------------------------------------
--
-- Steamodded's G.UIDEF.deck_preview counts the run's cards with
--
--     if SUITS[v.base.suit][v.base.value] and not v_nr and not v_ns then
--
-- where SUITS is keyed by registered suit. The two indexes are evaluated
-- before the `and`, so an entry in G.playing_cards whose base carries a suit
-- that is not registered - or no base at all - crashes the game the moment the
-- deck panel is drawn, which is every frame while a hand is being selected.
--
-- G.playing_cards is a registry used for counting, not the thing that owns the
-- cards: a card lives in its CardArea. Dropping an unrenderable entry from the
-- registry therefore removes it from the deck COUNT and nothing else, which is
-- the least destructive way to keep the panel alive.
--
-- What puts such an entry there is not yet known - it is not in the save, and
-- every conversion in this mod goes through SMODS.change_base with a suit that
-- exists. So this reports what it found rather than only swallowing it: the
-- suit, the rank and the centre key are enough to recognise the card next
-- time, and warn_once keeps it to one line per distinct suit.

--- Drops entries the deck preview cannot draw. Returns how many went.
function CelestasMod.prune_unrenderable_cards()
    if not (G.playing_cards and SMODS and SMODS.Suits) then return 0 end

    local removed = 0
    for i = #G.playing_cards, 1, -1 do
        local card = G.playing_cards[i]
        local base = card and card.base
        local suit = base and base.suit
        if not (suit and SMODS.Suits[suit]) then
            local center = card and card.config
                and (card.config.center_key
                     or (card.config.center and card.config.center.key))
            CelestasMod.warn_once("unrenderable_" .. tostring(suit),
                ("Removed a card from the deck count that the deck preview "
                 .. "cannot draw: suit=%s rank=%s centre=%s playing_card=%s")
                    :format(tostring(suit), tostring(base and base.value),
                            tostring(center), tostring(card and card.playing_card)))
            table.remove(G.playing_cards, i)
            removed = removed + 1
        end
    end
    return removed
end

if G.UIDEF and G.UIDEF.deck_preview then
    local celesta_deck_preview_ref = G.UIDEF.deck_preview
    function G.UIDEF.deck_preview(...)
        CelestasMod.prune_unrenderable_cards()
        return celesta_deck_preview_ref(...)
    end
end
