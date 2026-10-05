--- THE FAVOR STAMP
---
--- A stamp that changes how one particular Joker works. It can only be put on a Joker it has an
--- effect for, and only turns up in a Stamp Pack while one is owned (stamps/stamps.lua gates
--- both). What it does to each Joker is here, or - for this mod's own - beside the Joker's own
--- code, which asks CelestasMod.favored(card): the stamp is on the card and not in its ability
--- table, and the answer looks through a merge's lend (Stamps.worn), so a Joker asked about
--- itself from inside a merge still knows.
---
--- The base game's Jokers have nothing to ask: their rules are a chain of name checks inside
--- Card:calculate_joker. They are handled from a wrap of that function, in three ways, and each
--- Joker below says which:
---
---   REPLACED   the favoured Joker answers a context itself, in the shape vanilla would have
---              answered with, and vanilla is not asked.
---   SKIPPED    a context is not given to vanilla at all - the one where the Joker would have
---              worn itself down or destroyed itself.
---   FAKED      vanilla is asked, with one number of the run's set to what makes its condition
---              true for the length of the call and put straight back. "The first hand" is
---              `hands_played == 0` and "the final hand" is `hands_left == 0`; saying so for
---              the length of one Joker's call makes that Joker always active and nothing else.
---
--- Each Joker also has a line, `celesta_stamp_favor_<key>` in the localization, which is what the
--- stamp says it does - on the stamp's own card and on the Joker it is stamped onto.

CelestasMod.Favor = {}
local Favor = CelestasMod.Favor

local PREFIX = SMODS.current_mod.prefix

local function ours(name) return "j_" .. PREFIX .. "_" .. name end

--------------------------------------------------------------------------------
-- The Jokers it can go on
--------------------------------------------------------------------------------

--- In the order the listing shows them: the base game's, then this mod's.
Favor.KEYS = {
    -- the base game's
    "j_loyalty_card", "j_drivers_license", "j_yorick", "j_blue_joker", "j_todo_list",
    "j_obelisk", "j_ride_the_bus", "j_madness",
    "j_stuntman", "j_merry_andy", "j_troubadour", "j_burglar",
    "j_ice_cream", "j_popcorn", "j_turtle_bean", "j_selzer", "j_gros_michel", "j_cavendish",
    "j_ramen",
    "j_dna", "j_sixth_sense", "j_trading", "j_burnt", "j_acrobat", "j_dusk",
    -- this mod's
    ours("dokibird"), ours("blessed_phoenix_egg"), ours("glassesjournal"), ours("obkatiekat"),
    ours("slimegod"), ours("pristinezero"), ours("matarakan"), ours("unnamed"),
    ours("yokasiri"), ours("eros"), ours("laynalazar"), ours("megalodon"), ours("urschleim"),
    ours("fireonirei"), ours("hidden_tech"),
    ours("adfree"), ours("yuy_ix"), ours("hannahhyrule"), ours("camila"), ours("isaa"),
    ours("pandabearlily"),
    ours("monolith"), ours("demenishki"),
    ours("bao"), ours("monikacinnyroll"), ours("rainhoe"),
}

Favor.SET = {}
for _, key in ipairs(Favor.KEYS) do Favor.SET[key] = true end

--- The Joker keys a card answers to: its own, and the one bound into it by a merge.
--- Read off the card's own ability, so this is asked of a card from outside.
local function keys_of(card)
    local out = {}
    local center = card and card.config and card.config.center
    if center and center.key then out[#out + 1] = center.key end
    local bound = card and card.ability and card.ability.celesta_bind
    if type(bound) == "table" and type(bound.key) == "string" then out[#out + 1] = bound.key end
    return out
end

--- The same, with the ability table each key's numbers live on: the card's own for its own
--- Joker, and the one that came with the absorbed half for a merge's other.
local function halves_of(card)
    local out = {}
    local center = card and card.config and card.config.center
    if center and center.key then out[#out + 1] = { key = center.key, ability = card.ability } end
    local bound = card and card.ability and card.ability.celesta_bind
    if type(bound) == "table" and type(bound.key) == "string" then
        out[#out + 1] = { key = bound.key, ability = bound.ability }
    end
    return out
end

--- Whether a Joker is one the stamp has an effect for - either half of a merge.
function Favor.accepts(card)
    for _, key in ipairs(keys_of(card)) do
        if Favor.SET[key] then return true end
    end
    return false
end

--- The owned Jokers the stamp could go on: wearing nothing yet, and one it has an effect for.
function Favor.targets()
    local out = {}
    for _, card in ipairs((G.jokers and G.jokers.cards) or {}) do
        if not (card.ability and card.ability.celesta_stamp) and Favor.accepts(card) then
            out[#out + 1] = card
        end
    end
    return out
end

--- Whether there is one: what lets a Favor Stamp turn up in a pack.
function Favor.has_target()
    return #Favor.targets() > 0
end

--------------------------------------------------------------------------------
-- What the stamp says
--------------------------------------------------------------------------------

local function loc_key(joker_key) return "celesta_stamp_favor_" .. joker_key end

--- A Joker's name, as the game would print it.
local function joker_name(key)
    return localize { type = "name_text", set = "Joker", key = key }
end

--- The effect line of one Joker, as rows of parts, or {} if the localization has none.
local function effect_lines(key)
    local lines = {}
    local ok = pcall(localize, { type = "descriptions", set = "Other", key = loc_key(key),
                                 vars = {}, nodes = lines })
    return ok and lines or {}
end

--- What a Favor Stamp card lists under its description.
---
--- In a run it is the Jokers the stamp could go on right now, each with what it would do to it.
--- With none to ask - the Collection - it is every Joker the stamp has an effect for, by name.
function Favor.listing_rows()
    local rows = {}
    local UIT = G.UIT
    local owned = G.jokers and G.jokers.cards and #G.jokers.cards > 0
    local seen = {}

    if owned then
        for _, card in ipairs(Favor.targets()) do
            for _, key in ipairs(keys_of(card)) do
                if Favor.SET[key] and not seen[key] then
                    seen[key] = true
                    -- The Joker's name leads its first line; the rest follow as they are.
                    for i, line in ipairs(effect_lines(key)) do
                        local parts = {}
                        if i == 1 then
                            parts[1] = { n = UIT.T, config = { text = tostring(joker_name(key)) .. ": ",
                                                               colour = G.C.FILTER, scale = 0.3 } }
                        end
                        for _, part in ipairs(line) do parts[#parts + 1] = part end
                        rows[#rows + 1] = { n = UIT.R, config = { align = "cl" }, nodes = parts }
                    end
                end
            end
        end
        if #rows > 0 then return rows end
    end

    -- Every name, five to a row.
    rows[#rows + 1] = { n = UIT.R, config = { align = "cl" }, nodes = {
        { n = UIT.T, config = { text = "Can go on:", colour = G.C.UI.TEXT_INACTIVE, scale = 0.3 } } } }
    local line, count = {}, 0
    local function flush()
        if #line > 0 then
            rows[#rows + 1] = { n = UIT.R, config = { align = "cl" }, nodes = { { n = UIT.T, config = {
                text = table.concat(line, ", "), colour = G.C.FILTER, scale = 0.28 } } } }
            line, count = {}, 0
        end
    end
    for _, key in ipairs(Favor.KEYS) do
        line[#line + 1] = tostring(joker_name(key))
        count = count + 1
        if count >= 3 then flush() end
    end
    flush()
    return rows
end

--- The lines a Favor-stamped Joker carries: what it does to THIS Joker.
function Favor.mark_rows(card, localized_rows)
    local rows = {}
    for _, key in ipairs(keys_of(card)) do
        if Favor.SET[key] then
            for i, line in ipairs(effect_lines(key)) do
                if i == 1 then
                    table.insert(line, 1, { n = G.UIT.T, config = { text = "Stamp: ",
                                                                    colour = G.C.FILTER, scale = 0.32 } })
                end
                rows[#rows + 1] = line
            end
        end
    end
    return rows
end

--------------------------------------------------------------------------------
-- The state of the round, put aside for the length of one call
--------------------------------------------------------------------------------

--- Runs `fn` with these fields of the current round set to these values, and puts them back.
---
--- Synchronous, and put back on the way out of an error as well as the way out of success: the
--- round's own counters are what every other Joker reads in the very next call.
local function with_round(overrides, fn)
    local round = G.GAME and G.GAME.current_round
    if not round then return fn() end
    local saved = {}
    for field, value in pairs(overrides) do
        saved[field] = round[field]
        round[field] = value
    end
    local ok, a, b = pcall(fn)
    for field in pairs(overrides) do round[field] = saved[field] end
    if not ok then error(a, 0) end
    return a, b
end

--- The poker hand played most this run, the way The Ox works it out: ties go to the one that
--- comes first in the list.
local function most_played_hand()
    local name, played, order = "High Card", -1, 100
    for key, hand in pairs((G.GAME and G.GAME.hands) or {}) do
        local n = type(hand.played) == "number" and hand.played or 0
        if SMODS.is_poker_hand_visible(key)
            and (n > played or (n == played and order > (hand.order or 100))) then
            played, order, name = n, hand.order or 100, key
        end
    end
    return name
end

Favor.most_played_hand = most_played_hand

--------------------------------------------------------------------------------
-- The base game's Jokers
--------------------------------------------------------------------------------

--- Each handler: (self, context, ref, ...) -> effect, post. `ref` is the function underneath.
Favor.VANILLA = {}
local V = Favor.VANILLA

--- A Joker that is asked as if it were the first hand, or the final one, or the first discard.
local function faked(overrides)
    -- calculate_joker takes the context and nothing else, so there is nothing to pass along:
    -- a vararg cannot be reached from inside the closure.
    return function(self, context, ref)
        return with_round(overrides, function() return ref(self, context) end)
    end
end

-- FAKED: "the first hand" is hands_played == 0 ...
V.j_dna = faked({ hands_played = 0 })
V.j_sixth_sense = faked({ hands_played = 0 })
-- ... "the first discard" is discards_used == 0 ...
V.j_trading = faked({ discards_used = 0 })
V.j_burnt = faked({ discards_used = 0 })
-- ... and "the final hand" is hands_left == 0.
V.j_dusk = faked({ hands_left = 0 })
V.j_acrobat = faked({ hands_left = 0 })

--- A Joker that is not given the context in which it would wear itself down.
local function skipped(test)
    return function(self, context, ref, ...)
        if test(context) then return nil end
        return ref(self, context, ...)
    end
end

--- The end of a round, as the Joker pass sees it - not the per-card passes that share the flag.
local function round_ends(context)
    return context.end_of_round and not context.individual and not context.repetition
end

--- A hand scored, as the Joker pass sees it, and not one a copier is running.
local function hand_scored(context)
    return context.after and not context.blueprint
end

-- SKIPPED: the ones that would be eaten, or melt, or go extinct, at the end of the round ...
V.j_popcorn = skipped(round_ends)
V.j_turtle_bean = skipped(round_ends)
V.j_gros_michel = skipped(round_ends)
V.j_cavendish = skipped(round_ends)
-- ... the ones that count their hands down ...
V.j_ice_cream = skipped(hand_scored)
V.j_selzer = skipped(hand_scored)
-- ... and Ramen, which is worn away by discards.
V.j_ramen = skipped(function(context) return context.discard and not context.blueprint end)

-- FAKED: Driver's License counts enhanced cards in the full deck and wants sixteen, and the
-- count is the whole of its condition. It is rebuilt every frame in Card:update, so the number
-- is only ever put up for the length of the call.
V.j_drivers_license = function(self, context, ref, ...)
    local ability = self.ability
    local saved = ability.driver_tally
    ability.driver_tally = math.max(saved or 0, 16)
    local ok, a, b = pcall(ref, self, context, ...)
    ability.driver_tally = saved
    if not ok then error(a, 0) end
    return a, b
end

-- REPLACED: Loyalty Card pays every hand.
V.j_loyalty_card = function(self, context, ref, ...)
    if not context.joker_main then return ref(self, context, ...) end
    local x = self.ability.extra and self.ability.extra.Xmult or 4
    return {
        message = localize { type = "variable", key = "a_xmult", vars = { x } },
        Xmult_mod = x,
    }
end

-- REPLACED: Blue Joker counts the full deck rather than what is left of the draw pile.
V.j_blue_joker = function(self, context, ref, ...)
    if not context.joker_main then return ref(self, context, ...) end
    local count = #(G.playing_cards or {})
    if count <= 0 then return nil end
    local chips = (type(self.ability.extra) == "number" and self.ability.extra or 2) * count
    return {
        message = localize { type = "variable", key = "a_chips", vars = { chips } },
        chip_mod = chips,
        colour = G.C.CHIPS,
    }
end

-- Yorick: every five cards discarded rather than every 23.
local YORICK_EVERY = 5
local function yorick_shorten(ability)
    local extra = ability.extra
    if type(extra) ~= "table" then return end
    extra.discards = YORICK_EVERY
    if type(ability.yorick_discards) ~= "number" or ability.yorick_discards > YORICK_EVERY then
        ability.yorick_discards = YORICK_EVERY
    end
end
V.j_yorick = function(self, context, ref, ...)
    yorick_shorten(self.ability)
    return ref(self, context, ...)
end

-- To Do List: the most played hand, asked again each time it is looked at - so also after a
-- round that would have picked a new one at random.
local function todo_retarget(ability)
    ability.to_do_poker_hand = most_played_hand()
end
V.j_todo_list = function(self, context, ref, ...)
    todo_retarget(self.ability)
    local effect, post = ref(self, context, ...)
    todo_retarget(self.ability)
    return effect, post
end

-- REPLACED: Madness gains, and destroys nothing.
V.j_madness = function(self, context, ref, ...)
    if not (context.setting_blind and not self.getting_sliced and not context.blueprint
        and not (context.blind and context.blind.boss)) then
        return ref(self, context, ...)
    end
    local owner = context.blueprint_card or self
    if not owner.getting_sliced then
        SMODS.scale_card(owner, {
            ref_table = self.ability,
            ref_value = "x_mult",
            scalar_value = "extra",
            message_key = "a_xmult",
        })
    end
    return nil, true
end

-- REPLACED: Burglar gives its Hands and keeps the discards.
V.j_burglar = function(self, context, ref, ...)
    if not (context.setting_blind and not self.getting_sliced
        and not (context.blueprint_card or self).getting_sliced) then
        return ref(self, context, ...)
    end
    G.E_MANAGER:add_event(Event {
        func = function()
            ease_hands_played(self.ability.extra)
            card_eval_status_text(context.blueprint_card or self, "extra", nil, nil, nil, {
                message = localize { type = "variable", key = "a_hands",
                                     vars = { self.ability.extra } } })
            return true
        end,
    })
    return nil, true
end

-- REPLACED: Ride the Bus and Obelisk keep what they have built. Each does what it does when the
-- hand is not the one that would have ended it, and nothing at all when it is.
V.j_ride_the_bus = function(self, context, ref, ...)
    if not (context.before and not context.blueprint) then return ref(self, context, ...) end
    for _, scored in ipairs(context.scoring_hand or {}) do
        if scored:is_face() then return nil end
    end
    SMODS.scale_card(self, { ref_table = self.ability, ref_value = "mult",
                             scalar_value = "extra", no_message = true })
    return nil, true
end
V.j_obelisk = function(self, context, ref, ...)
    if not (context.before and not context.blueprint) then return ref(self, context, ...) end
    local hands = G.GAME.hands
    local played = (hands[context.scoring_name] and hands[context.scoring_name].played) or 0
    for key, hand in pairs(hands) do
        if key ~= context.scoring_name and (hand.played or 0) >= played
            and SMODS.is_poker_hand_visible(key) then
            -- Not the most played hand: it would have been reset. It is left as it is.
            return nil
        end
    end
    SMODS.scale_card(self, { ref_table = self.ability, ref_value = "x_mult",
                             scalar_value = "extra", no_message = true })
    return nil, true
end

--- The wrap: the one place a base game Joker is asked anything.
---
--- Loaded BEFORE merge/bind.lua so that it sits underneath Bind's wrapper, which runs an
--- absorbed half by calling the function beneath it with the half's centre and ability lent
--- to the card: the half's own Favor handler is then the one found, and the stamp is read
--- through the lend (Stamps.worn).
local celesta_favor_calculate_ref = Card.calculate_joker
function Card:calculate_joker(context, ...)
    local config = self.config
    local key = config and (config.center_key or (config.center and config.center.key))
    local handler = key and V[key]
    if handler and type(context) == "table" and CelestasMod.favored(self) then
        return handler(self, context, celesta_favor_calculate_ref, ...)
    end
    return celesta_favor_calculate_ref(self, context, ...)
end

--------------------------------------------------------------------------------
-- The moment it lands
--------------------------------------------------------------------------------

--- Per Joker: what the stamp does the moment it is put on, which is the state a Joker took
--- from the run when it was bought and has to give back now. Each is undone at the card's
--- own numbers, which are set to nothing: selling it takes nothing twice.
---
--- (card, ability): the ability is the one the half's numbers live on, which for the absorbed
--- half of a merge is not the card's own.
Favor.PRESS = {}
local PRESS = Favor.PRESS

--- Gives a hand size penalty back, once, and zeroes it on the card.
local function give_back_hand_size(card, ability)
    if type(ability.h_size) == "number" and ability.h_size < 0 then
        if card.added_to_deck and G.hand then G.hand:change_size(-ability.h_size) end
        ability.h_size = 0
    end
end

PRESS.j_merry_andy = give_back_hand_size
PRESS[ours("fireonirei")] = give_back_hand_size

PRESS.j_stuntman = function(card, ability)
    local extra = ability.extra
    if type(extra) ~= "table" or (extra.h_size or 0) == 0 then return end
    if card.added_to_deck and G.hand then G.hand:change_size(extra.h_size) end
    extra.h_size = 0
end

PRESS.j_troubadour = function(card, ability)
    local extra = ability.extra
    if type(extra) ~= "table" or (extra.h_plays or 0) == 0 then return end
    if card.added_to_deck and G.GAME and G.GAME.round_resets then
        G.GAME.round_resets.hands = G.GAME.round_resets.hands - extra.h_plays
    end
    extra.h_plays = 0
end

PRESS.j_yorick = function(card, ability) yorick_shorten(ability) end
PRESS.j_todo_list = function(card, ability) todo_retarget(ability) end

-- Matara Kan hands back what she was keeping: the account is closed, at its own rate.
PRESS[ours("matarakan")] = function(card, ability)
    local extra = ability.extra
    if type(extra) ~= "table" or not (type(extra.stored) == "number" and extra.stored > 0) then
        return
    end
    local payout = math.floor(extra.stored * (extra.payout_mult or 1))
    extra.stored = 0
    if payout > 0 then ease_dollars(payout) end
end

-- A ready egg hatches the moment it is stamped.
PRESS[ours("blessed_phoenix_egg")] = function(card, ability)
    local extra = ability.extra
    if type(extra) == "table" and (extra.rounds or 0) >= (extra.needed or 7)
        and CelestasMod.egg_hatch then
        CelestasMod.egg_hatch(card)
    end
end

-- Adfree works out whether to hold the Boss from the world, so it is asked to again.
PRESS[ours("adfree")] = function()
    if CelestasMod.adfree_sync then CelestasMod.adfree_sync() end
end

--- Gives the run what the stamp changes, for the Jokers that have something to give.
function Favor.press(card)
    for _, half in ipairs(halves_of(card)) do
        local apply = PRESS[half.key]
        if apply and type(half.ability) == "table" then
            local ok, err = pcall(apply, card, half.ability)
            if not ok then
                CelestasMod.warn_once("favor_press_" .. half.key,
                    ("The Favor Stamp could not change %s: %s"):format(half.key, tostring(err)))
            end
        end
    end
end
