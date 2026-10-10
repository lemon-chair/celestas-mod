--- STAMP DOWNSIDES
---
--- Every stamp is chosen WITH a cost, printed at the bottom of its card and
--- paid the moment the stamp goes on a Joker. This file is the list of costs
--- and the machinery for the ones that cannot be paid on the spot.
---
--- A downside's tier matches the stamp's: a rare stamp is offered against a
--- rare downside. The three lists were written against each other - five
--- common, five uncommon, nine rare - and pairing across them would make the
--- rare stamps the obvious pick every time, which is the one thing a cost is
--- there to stop.
---
--- Three shapes of cost, and they are paid in three different places:
---
---   NOW        money, poker hand levels, the permanent hands / discards /
---              hand size, and the quarter of the deck. Applied in `apply`.
---
---   NEXT ROUND hands and discards ride vanilla's own G.GAME.round_bonus,
---              which new_round adds in and then zeroes (state_events.lua:244)
---              - exactly "for the next round", with no bookkeeping of ours.
---              Hand size has no such field, so it is taken at setting_blind
---              and given back at end_of_round, and what was taken is
---              remembered so the two can never disagree.
---
---   THE BLIND  a multiplier on get_blind_amount, which is the one function
---              both the number OFFERED on the blind select screen and the
---              number REQUIRED by the blind itself go through. Same hook the
---              Joker Printer challenge uses, and for the same reason.

CelestasMod.StampDownsides = {}
local Downsides = CelestasMod.StampDownsides

--------------------------------------------------------------------------------
-- The list
--------------------------------------------------------------------------------
--
-- `loc` names a block in descriptions.Other as celesta_stamp_down_<loc>, and
-- several entries share one: the three hand-level costs differ only by the
-- number they put in it. Everything else on an entry is what `apply` does.
--
--   levels          poker hand levels off the most played hand, now
--   money           { min, max } dollars, rolled per stamp, ignoring the
--                   debt limit
--   hand_size       cards off the hand, next round only
--   hands           hands, next round only
--   discards        discards, next round only
--   hand_size_perm / hands_perm / discards_perm   the same three, for good
--   blind_next / blind_perm   a multiplier on the blind's chip requirement
--   face_down       the first hand of the next round arrives face down
--   destroy         a fraction of the full deck, now

Downsides.LIST = {
    -- ---------------- common ----------------
    { key = "level_1",     tier = 1, loc = "levels",     levels = 1 },
    { key = "hand_size_1", tier = 1, loc = "hand_size",  hand_size = 1 },
    { key = "hands_1",     tier = 1, loc = "hands",      hands = 1 },
    { key = "discards_1",  tier = 1, loc = "discards",   discards = 1 },
    { key = "money_1",     tier = 1, loc = "money",      money = { 5, 10 } },

    -- ---------------- uncommon ----------------
    { key = "level_2",     tier = 2, loc = "levels",     levels = 2 },
    { key = "hand_size_2", tier = 2, loc = "hand_size",  hand_size = 2 },
    { key = "face_down",   tier = 2, loc = "face_down",  face_down = true },
    { key = "blind_25",    tier = 2, loc = "blind_pct",  blind_next = 1.25 },
    { key = "money_2",     tier = 2, loc = "money",      money = { 10, 15 } },

    -- ---------------- rare ----------------
    { key = "level_4",          tier = 3, loc = "levels",          levels = 4 },
    { key = "hand_size_3",      tier = 3, loc = "hand_size",       hand_size = 3 },
    { key = "hand_size_forever", tier = 3, loc = "hand_size_perm", hand_size_perm = 1 },
    { key = "hands_forever",    tier = 3, loc = "hands_perm",      hands_perm = 1 },
    { key = "discards_forever", tier = 3, loc = "discards_perm",   discards_perm = 1 },
    { key = "blind_50",         tier = 3, loc = "blind_pct_perm",  blind_perm = 1.5 },
    { key = "blind_x2",         tier = 3, loc = "blind_mult",      blind_next = 2 },
    { key = "destroy_quarter",  tier = 3, loc = "destroy",         destroy = 0.25 },
    { key = "money_3",          tier = 3, loc = "money",           money = { 16, 32 } },
}

--- key -> entry, and tier -> the entries in it.
Downsides.BY_KEY = {}
Downsides.BY_TIER = { {}, {}, {} }
for _, entry in ipairs(Downsides.LIST) do
    Downsides.BY_KEY[entry.key] = entry
    local tier = Downsides.BY_TIER[entry.tier]
    tier[#tier + 1] = entry
end

--- The entry a rolled downside refers to, or nil for one this version no
--- longer has. A saved run can carry a key that has since been removed, and a
--- stamp on a Joker still has to render.
function Downsides.entry(picked)
    return picked and picked.key and Downsides.BY_KEY[picked.key] or nil
end

--------------------------------------------------------------------------------
-- Rolling one
--------------------------------------------------------------------------------

local DOWNSIDE_SEED = "celesta_stamp_downside"
local DOWNSIDE_MONEY_SEED = "celesta_stamp_downside_money"

--- A downside for a stamp of this tier, as { key = ..., amount = ... }.
---
--- `amount` is only the money ones' rolled figure; everything else carries its
--- number on the entry, where it cannot drift between the card's description
--- and what the card does.
function Downsides.roll(tier)
    local pool = Downsides.BY_TIER[tier] or Downsides.BY_TIER[1]
    local entry = pseudorandom_element(pool, pseudoseed(DOWNSIDE_SEED))
    if not entry then return nil end

    local picked = { key = entry.key }
    if entry.money then
        picked.amount = pseudorandom(pseudoseed(DOWNSIDE_MONEY_SEED),
                                     entry.money[1], entry.money[2])
    end
    return picked
end

--- The numbers this downside's description asks for.
function Downsides.vars(picked)
    local entry = Downsides.entry(picked)
    if not entry then return {} end
    if entry.money then return { picked.amount or entry.money[1] } end
    if entry.levels then return { entry.levels } end
    if entry.hand_size then return { entry.hand_size } end
    if entry.hands then return { entry.hands } end
    if entry.discards then return { entry.discards } end
    if entry.hand_size_perm then return { entry.hand_size_perm } end
    if entry.hands_perm then return { entry.hands_perm } end
    if entry.discards_perm then return { entry.discards_perm } end
    if entry.blind_next then
        -- A percentage where it was asked for as one, the multiplier where it
        -- was asked for as that.
        return { entry.loc == "blind_pct" and (entry.blind_next - 1) * 100
            or entry.blind_next }
    end
    if entry.blind_perm then return { (entry.blind_perm - 1) * 100 } end
    if entry.destroy then return { entry.destroy * 100 } end
    return {}
end

--------------------------------------------------------------------------------
-- The state a downside can leave behind
--------------------------------------------------------------------------------

--- The run's stamp bookkeeping, created on first use.
---
--- Lives on G.GAME so it is saved with the run and thrown away with it:
---   hand_size          cards to take off the hand at the next blind
---   hand_size_taken    cards taken and owed back at the end of this round
---   face_down          the next round's first hand arrives face down
---   blind_next         multiplier on the next blind's requirement
---   blind_perm         ...and the one that never comes off
function Downsides.state()
    if not G.GAME then return nil end
    G.GAME.celesta_stamps = G.GAME.celesta_stamps or {}
    return G.GAME.celesta_stamps
end

--------------------------------------------------------------------------------
-- Paying up
--------------------------------------------------------------------------------

--- A plain Lua number, or nil. Talisman replaces hand levels and money with
--- its own tables, and Lua 5.1 refuses to COMPARE one against a number - so
--- anything that has to be clamped comes through here first.
local function plain(value)
    if type(value) == "number" then
        if value ~= value then return nil end
        return value
    end
    if type(value) == "table" and type(value.to_number) == "function" then
        local ok, n = pcall(value.to_number, value)
        if ok and type(n) == "number" and n == n then return n end
    end
    return nil
end

--- The hand this run has played most, ties going to the one listed first.
---
--- Vanilla's own answer, copied off state_events.lua:130 rather than invented:
--- that is the computation the game itself calls "most played poker hand", and
--- two different definitions of it in one game would be a bug waiting.
local function most_played_hand()
    local name, played, order = "High Card", -1, 100
    for key, hand in pairs((G.GAME and G.GAME.hands) or {}) do
        local n = plain(hand.played) or 0
        if n > played or (n == played and order > (hand.order or 100)) then
            played, order, name = n, hand.order or 100, key
        end
    end
    return name
end

-- Shared with items/purgatory.lua, which lowers and raises hands for its own reasons.
Downsides.plain = plain
Downsides.most_played_hand = most_played_hand

--- Take `levels` off the most played hand, never below level 1.
---
--- Clamped because nothing else clamps it: level_up_hand with a negative
--- amount walks the level and every scoring parameter straight past zero
--- (SMODS.upgrade_poker_hands), and a hand at level -2 scores negative Mult.
--- Level 1 is the floor the game itself is written against.
local function drop_levels(levels)
    if not (G.GAME and G.GAME.hands) then return 0 end
    local hand = most_played_hand()
    local entry = G.GAME.hands[hand]
    if not entry then return 0 end

    local level = plain(entry.level) or 1
    local room = math.floor(level) - 1
    if room <= 0 then return 0 end
    local drop = math.min(levels, room)

    -- instant: this is paid in a booster pack, where there is no scoring
    -- display for the level animation to play against.
    level_up_hand(nil, hand, true, -drop)
    return drop
end

--- Lose `amount` dollars, past the debt limit if that is where it lands.
---
--- "no debt limit" in the list, and ease_dollars is already that: the limit is
--- only ever consulted when BUYING (button_callbacks.lua:58), never when money
--- is taken away. So this is a plain loss, and the note on the card is telling
--- the player it will not be softened rather than asking for anything special.
local function lose_money(amount)
    if amount and amount > 0 then ease_dollars(-amount) end
end

--- Destroy `fraction` of the full deck, chosen at random.
---
--- The FULL deck, so cards still face down in the draw pile count and can go.
--- Eternal cards are left alone, which is SMODS.destroy_cards' own rule and
--- the one every other destroyer in this mod inherits.
local function destroy_fraction(fraction)
    if not (G.playing_cards and #G.playing_cards > 0) then return 0 end

    local pool = {}
    for _, card in ipairs(G.playing_cards) do pool[#pool + 1] = card end

    local want = math.floor(#pool * fraction + 0.5)
    if want <= 0 then return 0 end

    local doomed = {}
    for _ = 1, math.min(want, #pool) do
        -- pseudorandom_element hands back the chosen INDEX as well as the
        -- card, so the card can be lifted out and the next draw is from what
        -- is left. Drawing with replacement would pick some cards twice and
        -- the quarter would quietly be a fifth.
        local card, i = pseudorandom_element(pool,
                                             pseudoseed("celesta_stamp_cull"))
        if not card then break end
        table.remove(pool, i)
        doomed[#doomed + 1] = card
    end

    if #doomed > 0 then SMODS.destroy_cards(doomed) end
    return #doomed
end

--- Pay a rolled downside. Called once, as the stamp goes onto the Joker.
function Downsides.apply(picked)
    local entry = Downsides.entry(picked)
    if not entry then return end
    local state = Downsides.state()
    if not state then return end

    if entry.levels then drop_levels(entry.levels) end
    if entry.money then lose_money(picked.amount or entry.money[1]) end
    if entry.destroy then destroy_fraction(entry.destroy) end

    -- Next round only. Hands and discards are vanilla's own field, which
    -- new_round adds in and then clears; the reads there are clamped
    -- (hands never below 1, discards never below 0), so none of these can
    -- leave a round that cannot be played.
    if entry.hands and G.GAME.round_bonus then
        G.GAME.round_bonus.next_hands =
            (G.GAME.round_bonus.next_hands or 0) - entry.hands
    end
    if entry.discards and G.GAME.round_bonus then
        G.GAME.round_bonus.discards =
            (G.GAME.round_bonus.discards or 0) - entry.discards
    end
    if entry.hand_size then
        state.hand_size = (state.hand_size or 0) + entry.hand_size
    end
    if entry.face_down then state.face_down = true end
    if entry.blind_next then
        state.blind_next = (state.blind_next or 1) * entry.blind_next
    end

    -- ...and the ones that never come off.
    if entry.blind_perm then
        state.blind_perm = (state.blind_perm or 1) * entry.blind_perm
    end
    if entry.hands_perm and G.GAME.round_resets then
        G.GAME.round_resets.hands =
            math.max(1, G.GAME.round_resets.hands - entry.hands_perm)
    end
    if entry.discards_perm and G.GAME.round_resets then
        G.GAME.round_resets.discards =
            math.max(0, G.GAME.round_resets.discards - entry.discards_perm)
    end
    if entry.hand_size_perm and G.hand then
        G.hand:change_size(-entry.hand_size_perm)
    end
end

--------------------------------------------------------------------------------
-- The next round, when it comes
--------------------------------------------------------------------------------

--- Take the hand size owed, and arm anything else that waits for a blind.
--- Called from the setting_blind pass, which runs after new_round has reset
--- the round's numbers and before the hand is drawn.
function Downsides.arm()
    local state = Downsides.state()
    if not state then return end
    local owed = state.hand_size or 0
    if owed > 0 and G.hand then
        G.hand:change_size(-owed)
        state.hand_size_taken = (state.hand_size_taken or 0) + owed
        state.hand_size = 0
    end
end

--- Give back what was borrowed for one round, and let the round's own
--- penalties go. Called at the end of the round.
function Downsides.disarm()
    local state = Downsides.state()
    if not state then return end
    local taken = state.hand_size_taken or 0
    if taken > 0 and G.hand then G.hand:change_size(taken) end
    state.hand_size_taken = nil
    state.face_down = nil
    state.blind_next = nil
end

--- True while the next hand of cards should arrive face down.
--- The House's own condition (blind.lua:656): the first cards of the round,
--- before anything has been played or discarded.
function Downsides.draws_face_down()
    local state = G.GAME and G.GAME.celesta_stamps
    if not (state and state.face_down) then return false end
    local round = G.GAME.current_round
    if not round then return false end
    return (round.hands_played or 0) == 0 and (round.discards_used or 0) == 0
end

--------------------------------------------------------------------------------
-- The blind, when it is asked how big it is
--------------------------------------------------------------------------------

--- What this run's stamps multiply the blind at `ante` by.
---
--- The permanent one applies wherever a blind amount is asked for. The
--- next-round one is held to the Ante being played, so the ladder in the run
--- info still reports honest numbers for the Antes ahead - the penalty is one
--- blind's, and those are not it.
function Downsides.blind_scale(ante)
    local state = G.GAME and G.GAME.celesta_stamps
    if not state then return 1 end
    local scale = state.blind_perm or 1
    if state.blind_next then
        local resets = G.GAME.round_resets
        local current = resets and (resets.blind_ante or resets.ante)
        if ante == nil or current == nil or ante == current then
            scale = scale * state.blind_next
        end
    end
    return scale
end

-- Wrapped at load, over Talisman's own version rather than under it: this is a
-- multiplier on whatever the run says the quota is, and deliberately not
-- guarded on the value being a plain number. Past a certain Ante it is one of
-- Talisman's big numbers, and those multiply through their own metamethod - it
-- is COMPARISON Lua 5.1 refuses across types, not arithmetic.
local celesta_stamp_blind_ref = get_blind_amount
if type(celesta_stamp_blind_ref) == "function" then
    function get_blind_amount(ante, ...)
        local amount = celesta_stamp_blind_ref(ante, ...)
        local scale = Downsides.blind_scale(ante)
        if scale == 1 then return amount end
        return amount * scale
    end
end

-- The first hand face down, the way The House does it. Wrapped rather than
-- registered as a Blind of ours: this has to hold whatever Blind is actually
-- being played, boss or not.
local celesta_stamp_flipped_ref = Blind.stay_flipped
function Blind:stay_flipped(area, card, from_area)
    if area == G.hand and Downsides.draws_face_down() then return true end
    return celesta_stamp_flipped_ref(self, area, card, from_area)
end

--------------------------------------------------------------------------------
-- Where a round begins and where it ends
--------------------------------------------------------------------------------
--
-- Hung off the two global functions rather than a Joker's end_of_round,
-- because a stamp's cost is owed whether or not this mod has a Joker on the
-- board - and after new_round, because that is where vanilla resets the
-- round's own numbers.
--
-- arm is idempotent: it moves what is owed into what has been taken and
-- leaves nothing behind, so a second call - a run loaded mid-round sets the
-- Blind again - takes nothing twice.

local celesta_stamp_new_round_ref = new_round
if type(celesta_stamp_new_round_ref) == "function" then
    function new_round(...)
        local ret = celesta_stamp_new_round_ref(...)
        Downsides.arm()
        return ret
    end
end

-- Disarmed at the END of the round rather than the start of the next one:
-- between those two is the shop, which is where the next stamp is chosen, and
-- a penalty cleared after that point would clear the one just bought.
local celesta_stamp_end_round_ref = end_round
if type(celesta_stamp_end_round_ref) == "function" then
    function end_round(...)
        local ret = celesta_stamp_end_round_ref(...)
        Downsides.disarm()
        return ret
    end
end
