--- GLOBALS
--- Custom colours usable in localization text as {C:celesta_pink} etc.

G.C.CELESTA = {
    PINK    = HEX("FF6FB5"),
    PURPLE  = HEX("6C5CE7"),
    TEAL    = HEX("00B8A9"),
    GOLD    = HEX("F2C94C"),
    WHITE   = HEX("FFFFFF"),
    -- The True Stars suit's own colour, hue 300. Kept here with the rest so
    -- the loc hook below has one place to read from; suits/true_stars.lua
    -- samples the same value off the art.
    TRUE_STAR = HEX("D411D4"),
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
    G.ARGS.LOC_COLOURS.celesta_true_star = G.C.CELESTA.TRUE_STAR
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

--- a > b, whichever kind of number either side is.
---
--- Lua 5.1 will not compare a table with a number: it does not reach the
--- metamethod, it raises. Talisman's numbers ARE tables, so any value that may
--- have passed through it has to be compared here rather than with `>`.
--- Arithmetic is the other way round - that does reach the metamethod - which
--- is why only the comparisons need this.
---
--- Learned from a crash: Vedal's counted door hands back one of Talisman's
--- numbers, and five Jokers guarding "is this worth announcing?" with `> 1`
--- took the run down the moment one was in the row.
function CelestasMod.more_than(a, b)
    if type(a) == "table" or type(b) == "table" then
        -- Only Talisman makes those, so it is loaded if one is here. Guarded
        -- anyway: a crash inside a guard is worse than a Joker that stays
        -- quiet.
        if type(to_big) ~= "function" then return false end
        return to_big(a) > to_big(b)
    end
    return a > b
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
--- Whether a card may answer a lookup at all.
---
--- A replacing pair speaks for both halves, so neither of them is in play as
--- itself - the same test with_partner makes before it runs an absorbed
--- half's hooks at all. Debuffed cards are out unless asked for, which is
--- what SMODS.find_card does and what every caller here relies on.
local function lookup_eligible(card, count_debuffed)
    local Bind = CelestasMod.Bind
    if Bind and Bind.replacing_special and Bind.replacing_special(card) then
        return false
    end
    return (count_debuffed or not card.debuff) and true or false
end

--- The half a card is standing in for, when one of its halves has been lent
--- its centre and ability. Nil the rest of the time, which is almost always.
---
--- merge/bind.lua records the lend; this is the one place the lookups below
--- ask about it, so that a card being run, hooked or described AS one half is
--- still the other one as far as the row is concerned.
local function lent_half(card)
    local Bind = CelestasMod.Bind
    local lent = Bind and Bind.lent and Bind.lent[card]
    return lent
end

--- True when `card` is in play AS `key`, either half of a merge counting.
---
--- The same rule find_joker counts by, written once and exported for the few
--- callers that cannot afford find_joker: a question asked of every card in
--- every hand the game scores cannot build a table each time.
function CelestasMod.card_is_joker(card, key, count_debuffed)
    if not (card and lookup_eligible(card, count_debuffed)) then return false end
    local center = card.config and card.config.center
    if center and center.key == key then return true end
    local Bind = CelestasMod.Bind
    if (Bind and Bind.is_merged and Bind.is_merged(card)
        and card.ability.celesta_bind.key == key) then
        return true
    end
    -- ...and the half it is standing in for, if it is standing in for one.
    local lent = lent_half(card)
    return (lent and lent.center and lent.center.key == key) and true or false
end

--- True when `card` is a merge, asked from anywhere - a lend included.
---
--- Bind.is_merged is the direct test and reads celesta_bind off card.ability.
--- That is the right answer everywhere except the one window this exists for:
--- while a card is lent to one of its halves it wears that half's ability, and
--- a half's ability has no celesta_bind on it, so the card answered that it was
--- not a merge at all.
---
--- Which is the window a Joker counting the row is most likely to ask in, since
--- the row includes itself and its own description is built inside that lend.
--- Nyanners paid +15 for itself rather than +30 for exactly this.
---
--- Being lent IS being merged: nothing but a merge ever lends a card out.
function CelestasMod.card_is_merged(card)
    if not card then return false end
    local Bind = CelestasMod.Bind
    if Bind and Bind.is_merged and Bind.is_merged(card) then return true end
    return lent_half(card) ~= nil
end

--- Every ability table `card` carries AS `key`: one per half of it that is
--- that Joker, so a card merged from two of them answers with two.
---
--- The companion to card_is_joker, for a caller that needs a half's own
--- NUMBERS rather than only to know it is there. An absorbed half's ability is
--- under celesta_bind; card.ability is the host's, and a Joker reading its own
--- config off it reads the wrong Joker's - or, as often, nothing at all,
--- because the host has no such field.
---
--- Builds a table, so it is for the callers find_joker's note rules out the
--- cheap predicate for: asked when a price is recomputed or a description
--- drawn, not of every card in every hand.
function CelestasMod.card_abilities(card, key, count_debuffed)
    local out = {}
    if not (card and lookup_eligible(card, count_debuffed)) then return out end

    local center = card.config and card.config.center
    if center and center.key == key then out[#out + 1] = card.ability end

    -- The half it is standing in for, for find_joker's reason above.
    local lent = lent_half(card)
    if lent and lent.center and lent.center.key == key then
        out[#out + 1] = lent.ability
    end

    local Bind = CelestasMod.Bind
    local bind = Bind and Bind.is_merged and Bind.is_merged(card)
        and card.ability.celesta_bind
    -- A second entry rather than an elseif, for find_joker's reason: two of
    -- the same Joker can be merged into one card, and that card is two of them.
    if bind and bind.key == key and bind.ability then
        out[#out + 1] = bind.ability
    end

    return out
end

function CelestasMod.find_joker(key, count_debuffed)
    local out = {}
    local Bind = CelestasMod.Bind
    local areas = (SMODS.get_card_areas and SMODS.get_card_areas("jokers"))
        or { G.jokers }

    for _, area in ipairs(areas) do
        for _, card in ipairs((area and area.cards) or {}) do
            if lookup_eligible(card, count_debuffed) then
                local center = card.config and card.config.center
                if center and center.key == key then
                    out[#out + 1] = { card = card, ability = card.ability }
                end

                -- A SECOND entry rather than an elseif. Two of the same Joker
                -- can be merged into one card, and that card is two of them:
                -- two ability tables, two lots of whatever they scale. An
                -- elseif here reported one, so a Haruka bound to a Haruka
                -- doubled Tarots once instead of twice, and the same for
                -- every other caller that counts rather than just asking.
                if Bind and Bind.is_merged and Bind.is_merged(card)
                    and card.ability.celesta_bind.key == key then
                    out[#out + 1] = {
                        card = card,
                        ability = card.ability.celesta_bind.ability,
                    }
                end

                -- ...and the half it is standing in for. A card being run,
                -- hooked or described AS one of its halves is lent that
                -- half's centre and ability, and looks like nothing else for
                -- the duration - so without this the OTHER half is not in the
                -- row for exactly as long as something is asking.
                local lent = lent_half(card)
                if lent and lent.center and lent.center.key == key then
                    out[#out + 1] = { card = card, ability = lent.ability }
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
    "celesta_shiabun_granted",    -- Shiabun, Eidolon Wyrm, Slime God and Snuffy: selection limit
    "celesta_aethal_granted",     -- Aethal: shop slots
    "celesta_vantacrow_granted",  -- Vantacrow: hands, discards and hand size
}

--------------------------------------------------------------------------------
-- Rules a merge adds to a Joker
--------------------------------------------------------------------------------
--
-- Two Jokers let a merge widen what they do, by keeping a list of extra rules
-- that merge/bind.lua appends to. The lists live HERE rather than beside those
-- Jokers, and that is the whole point of them being here: bind.lua is loaded
-- before jokers/ (main.lua:138 against :188), so a list declared beside its
-- Joker does not exist yet when bind.lua tries to append to it.
--
-- That is not hypothetical. KURO_RULES was declared in implemented.lua, and
-- bind.lua's registration was wrapped in `if CelestasMod.KURO_RULES then` -
-- which was false every single load, so Kuro + Arielle never disabled a Boss
-- Blind in a real run. The suite missed it because it builds its own
-- CelestasMod with the table already present.
--
-- globals.lua is loaded first (main.lua:22), so anything declared here is
-- there for whoever reaches it. No guards: appending to a missing list should
-- be a crash that names itself, not a registration that quietly does not
-- happen.

--- Extra answers to "is the Boss Blind held shut this Ante?", each a function
--- returning true when its own rule is met. jokers/implemented.lua asks them
--- all in CelestasMod.kuro_sync.
CelestasMod.KURO_RULES = {}

--- Extra factors on how fast Vedal's exponent climbs, each a function
--- returning a multiplier. jokers/implemented.lua multiplies them together in
--- CelestasMod.vedal_step.
CelestasMod.VEDAL_SCALE_RULES = {}

--- Which Jokers a copier is pointed at right now.
---
--- There is no general answer in the game. Every copier has its own rule -
--- Blueprint takes the one to its right, Brainstorm the leftmost - and none of
--- them says so anywhere a passive can ask; the rule lives inside a calculate
--- that only runs while a hand is scoring. So the ones that exist are written
--- down, one line each, and another mod's copier is simply not covered.
---
--- `row` is the Joker row and `i` where the copier sits in it, both worked out
--- once by copier_targets below rather than by each rule.
CelestasMod.COPIER_TARGETS = {
    j_blueprint = function(card, row, i) return { row[i + 1] } end,
    j_brainstorm = function(card, row, i) return { row[1] } end,
}

do
    local J = "j_" .. SMODS.current_mod.prefix .. "_"
    local T = CelestasMod.COPIER_TARGETS
    T[J .. "mariyume"] = function(card, row, i) return { row[#row] } end
    T[J .. "sigrid_bird"] = function(card, row, i)
        return CelestasMod.neighbours(row, i)
    end
    -- An index rather than a card, re-picked every hand; the Joker itself
    -- reads it the same way.
    T[J .. "onigiri"] = function(card, row, i)
        local at = card.ability and card.ability.extra and card.ability.extra.target
        return { at and row[at] or nil }
    end
end

--- The cards `card` is copying, or nothing.
---
--- Asked of every card on every frame by Ruben's price, so the cheap test comes
--- first: almost nothing in the row is a copier, and the table says so without
--- walking anything.
function CelestasMod.copier_targets(card)
    local center = card and card.config and card.config.center
    local rule = center and CelestasMod.COPIER_TARGETS[center.key]
    if not rule then return nil end

    local row = G.jokers and G.jokers.cards
    if not row then return nil end
    local index
    for i, held in ipairs(row) do
        if held == card then index = i break end
    end
    if not index then return nil end

    local ok, out = pcall(rule, card, row, index)
    if not (ok and type(out) == "table") then return nil end
    -- A copier pointed at itself copies nothing, which every one of them
    -- already refuses for itself.
    local targets = {}
    for _, target in ipairs(out) do
        if target and target ~= card then targets[#targets + 1] = target end
    end
    return targets[1] and targets or nil
end

--- What CDawg retains beyond Commons.
---
--- Each rule answers a list of rarity numbers while its pair is in the row, and
--- nothing while it is not. merge/bind.lua fills this in and jokers/cdawg.lua
--- reads it, the way every other rule list here is written from one side and
--- read from the other.
CelestasMod.CDAWG_RARITY_RULES = {}

--- ...and which of those rarities it retains from OUTSIDE this mod.
---
--- The same shape, because it is a second axis and not a wider first one: a
--- rule answers the rarity numbers it opens to foreign Jokers, so CDawg + Blue
--- Card opening Common and CDawg + Green Card opening Uncommon come to this
--- mod's Uncommons and the base game's Commons rather than to everything.
---
--- A rarity has to be in BOTH to be retained from elsewhere: nothing is
--- retained that CDawg is not retaining at all.
CelestasMod.CDAWG_FOREIGN_RULES = {}

--- Extra factors on what a Eutrophic card copies, each a function taking the
--- copying card and returning a multiplier. enhancements/enhancements.lua
--- takes the first that answers, in CelestasMod.eutrophic_scale.
CelestasMod.EUTROPHIC_SCALE_RULES = {}

--- Anything other than a loose Tobs that widens what a Eutrophic mimics, each
--- a function answering true. Tobs's own merges are here: a replacing pair
--- speaks for both halves, so a merged Tobs is not in play as itself and the
--- pairs would otherwise switch off the very thing they are about.
CelestasMod.EUTROPHIC_WIDE_RULES = {}

--- Anything other than a loose Arielle that makes every card one suit, each a
--- function answering true. The Baulder Gang is here: a quad replaces all four
--- of its members, so joker_in_play stops finding the Arielle inside it and
--- the merge would switch off the first line on its own card.
CelestasMod.SAME_SUIT_RULES = {}

--- Anything that makes every card count as ONE rank, each a function returning
--- that rank's id or nil. jokers/implemented.lua takes the first that answers,
--- inside the Card:get_id wrap Kael already needs.
---
--- Kael's own rule is not here: it covers face cards only, and it is the
--- narrower answer these override. Its merges are, for the SAME_SUIT_RULES
--- reason - a replacing pair speaks for both halves, so the Kael inside one is
--- not in play as itself and the pair would switch off the line on its own
--- card.
CelestasMod.CARD_RANK_RULES = {}

--- Anything that makes every card count as ONE suit, each a function returning
--- that suit's key or nil. suits/shared.lua takes the first that answers, and
--- the card then IS that suit and is not its own - which is what CARD_RANK_RULES
--- does for ranks, one level over.
CelestasMod.CARD_SUIT_RULES = {}

--- Anything that makes a card answer to a suit as well as its own, each a
--- function (card, suit, flush_calc) returning true when it does. Widening
--- only: a rule that says no leaves the question to the next one and then to
--- the game, so both suits keep everything they already were.
---
--- `flush_calc` is Balatro's own flag for "asked while working out a Flush",
--- which is how a rule can hold there and nowhere else. It is the reason these
--- are read in Card:is_suit rather than in SMODS.smeared_check, which is never
--- told.
CelestasMod.SUIT_MATCH_RULES = {}

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


--------------------------------------------------------------------------------
-- The slot bookkeeping Steamodded totals every frame
--------------------------------------------------------------------------------
--
-- CardArea:count_property adds a named ability field across every card in an
-- area straight onto a running number (smods src/utils.lua:3182), and
-- CardArea:update calls it for `card_limit` and `extra_slots_used` twice a
-- frame. There is no nil guard, so a card missing either field crashes:
--
--     src/utils.lua:3185: attempt to perform arithmetic on a nil value
--
-- Card:set_ability is the only thing that ever writes those two
-- (card.lua:376), so any card handed an ability table another way is short of
-- them. This mod lends and installs ability tables in several places and is
-- careful to carry them, but the crash has been seen twice in real runs and
-- reading has not found the card - so the check goes on the function that
-- crashes rather than on a guess about which card it is.
--
-- On count_property rather than on CardArea:emplace, deliberately. A card
-- whose ability is replaced while it sits in the row - which is most of the
-- ways this mod touches one - never passes through emplace again, and a guard
-- there would miss exactly the case that is hardest to find by reading.
--
-- Zero is the conservative repair. The field means "extra slots this card
-- grants", and a card that cannot say has not granted any.

--- Makes sure `card` can answer for `field`, and says so once per centre.
function CelestasMod.ensure_slot_field(card, field)
    if not (card and type(card.ability) == "table") then return end
    if type(card.ability[field]) == "number" then return end

    card.ability[field] = 0
    local key = (card.config and (card.config.center_key
        or (card.config.center and card.config.center.key))) or "?"
    CelestasMod.warn_once("slot_field_" .. tostring(field) .. "_" .. tostring(key),
        ("%s is in a CardArea with no ability.%s, which Steamodded totals "
         .. "every frame; filled in 0 to stop it crashing. Something handed "
         .. "this card an ability table without going through set_ability.")
            :format(tostring(key), tostring(field)))
end

-- Wrapped defensively. CardArea:count_property belongs to Steamodded, so it is
-- a name that can move: if it ever does, this degrades to no guard rather than
-- taking the mod down at load.
local celesta_slot_count_ref = CardArea and CardArea.count_property
if type(celesta_slot_count_ref) == "function" then
    function CardArea:count_property(property, ...)
        for _, card in ipairs(self.cards or {}) do
            CelestasMod.ensure_slot_field(card, property)
        end
        return celesta_slot_count_ref(self, property, ...)
    end
end
