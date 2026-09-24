--- The Deck of Sins' seven stats.
---
--- Seven counters that climb while the run is played on this deck, in two
--- sets. What they DO is not decided yet; this file is the ladder they climb
--- and the five things that push them up it, and nothing else reads a level.
---
--- Every stat shares one ladder - ten points to a level, twenty levels - so
--- each source below is expressed as points per unit of whatever it counts,
--- and the rates in the request fall out of that:
---
---     Greed/Lust/Wrath/Gluttony  +3 Mult = 1 point  ->  30 Mult a level
---                                a card destroyed = 1.25  ->  8 cards a level
---                                a card that cannot say which suit it is
---                                pays the JOKER's suit in full and whoever
---                                it is confused with a half each
---     Pride    200 Chips a level    Envy  20 Mult a level
---     Pride    a Foil trigger = 1 point    Envy  a Holo trigger = 1 point
---     Sloth    $20 a level
---
--- The state lives on G.GAME, so it is saved and reloaded with the run for
--- free, the way every other run-long count in this mod is.

CelestasMod.Sins = {}
local Sins = CelestasMod.Sins

Sins.DECK = "sins"
Sins.MAX_LEVEL = 20
Sins.POINTS_PER_LEVEL = 10
--- The flat ladder's top. Sloth's is higher and is asked for through its
--- own ladder; nothing should use this as "the maximum" in general.
Sins.MAX_POINTS = Sins.MAX_LEVEL * Sins.POINTS_PER_LEVEL

--- Sloth's ladder rises: every level costs more than the last. The whole
--- curve is this one number, because the running total is the triangular
--- L * (L + 1) - so the constant is HALF the first level's price. At 10 the
--- first level is $20, the twentieth is $400, and all twenty are $4200.
---
--- Doubled from 5 after a run reached level 10 on $592 by Ante 8. The rising
--- shape means the early levels are cheap by design, but half the ladder for
--- a quarter of its cost was fast enough that Sloth was closing set two -
--- the first stat to twenty shuts the other two out - before Pride and Envy
--- had got anywhere near.
Sins.RISING_STEP = 10

--- Points per unit, so one number says what a source is worth.
local PER_MULT      = 1 / 3      -- +3 Mult is a point
local PER_DESTROYED = 1.25       -- 8 cards is a level
local PER_CHIP      = Sins.POINTS_PER_LEVEL / 200
local PER_ENH_MULT  = Sins.POINTS_PER_LEVEL / 20
--- A Foil or Holographic trigger is one whole point, so ten of them are a
--- level. Jokers and playing cards alike, and once per trigger - a retriggered
--- card pays twice for the same reason its Mult does.
local PER_EDITION   = 1

--- What a stat gets when it only SHARES in a payment rather than earning it.
Sins.SHARED_SPLIT = 0.5
-- Sloth counts dollars themselves: its ladder is not flat, so there is no
-- fixed number of points a dollar is worth.
local PER_DOLLAR    = 1

--- What a Lucky card pays when its money roll lands, if the card cannot say.
--- Vanilla's own is 20 (game.lua:664); the card is asked first so a modified
--- one counts what it actually paid.
local LUCKY_DOLLARS = 20

--- The four Jokers the first shop is built around. `fed_by` is the suit whose
--- DESTRUCTION feeds the stat - the opposite one, so the black pair and the
--- red pair each feed each other.
---
--- Stat set 2 has no Joker and no suit. Its symbol is a glyph in the colour
--- of the thing it counts - a blue +, a red X, a yellow $ - which is how the
--- game writes Chips, Mult and money everywhere else.
Sins.STATS = {
    greed    = { set = 1, order = 1, suit = "Diamonds",
                 joker = "j_greedy_joker",     joker_name = "Greedy Joker",
                 fed_by = "Hearts" },
    lust     = { set = 1, order = 2, suit = "Hearts",
                 joker = "j_lusty_joker",      joker_name = "Lusty Joker",
                 fed_by = "Diamonds" },
    wrath    = { set = 1, order = 3, suit = "Spades",
                 joker = "j_wrathful_joker",   joker_name = "Wrathful Joker",
                 fed_by = "Clubs" },
    gluttony = { set = 1, order = 4, suit = "Clubs",
                 joker = "j_gluttenous_joker", joker_name = "Gluttonous Joker",
                 fed_by = "Spades" },
    pride    = { set = 2, order = 5, glyph = "+", colour = "CHIPS" },
    envy     = { set = 2, order = 6, glyph = "X", colour = "MULT" },
    sloth    = { set = 2, order = 7, glyph = "$", colour = "MONEY",
                 ladder = "rising" },
}

--- Edition -> the stat it feeds. Only these two: Polychrome and Negative
--- feed nothing, which is why this is a table rather than a pair of ifs.
local EDITION_STAT = { foil = "pride", holo = "envy" }

--- The stat a Smeared Joker confuses each one with: its own colour, which is
--- the only union Smeared makes (utils.lua:2434 spells out both pairs).
local SMEAR_PARTNER = {
    greed = "lust",  lust  = "greed",       -- Diamonds and Hearts
    wrath = "gluttony", gluttony = "wrath", -- Spades and Clubs
}

--- The Joker that makes every card count as every suit.
local ARIELLE_KEY = "j_celesta_arielle"

--- Sidebar order, and the order every loop here walks.
Sins.ORDER = { "greed", "lust", "wrath", "gluttony", "pride", "envy", "sloth" }

Sins.SETS = {
    { "greed", "lust", "wrath", "gluttony" },
    { "pride", "envy", "sloth" },
}

--- Joker key -> the stat its Mult feeds.
local JOKER_STAT = {}
--- Suit -> the stat its destroyed cards feed.
local DESTROYED_STAT = {}
for key, def in pairs(Sins.STATS) do
    if def.joker then JOKER_STAT[def.joker] = key end
    if def.fed_by then DESTROYED_STAT[def.fed_by] = key end
end

--------------------------------------------------------------------------------
-- The ladders
--------------------------------------------------------------------------------
--
-- Six of the seven climb a FLAT ladder: ten points a level, every level.
-- Sloth climbs a RISING one - its first level costs $10, its second $20, its
-- twentieth $200 - so the running total needed to reach level L is
--
--     10 * (1 + 2 + ... + L)  =  5L(L + 1)
--
-- which is 10 to reach level 1, 30 to reach 2, and 2100 to reach 20. Sloth's
-- points ARE dollars spent, so nothing has to convert between the two.

Sins.LADDERS = {
    flat = {
        --- The level a running total has earned.
        level_of = function(points)
            return math.floor(points / Sins.POINTS_PER_LEVEL)
        end,
        --- The running total that reaches `level`.
        total_for = function(level) return level * Sins.POINTS_PER_LEVEL end,
    },
    rising = {
        -- Walked down from the top rather than solved: twenty-one comparisons
        -- cost nothing, and the closed form needs a square root that would
        -- put the boundary levels at the mercy of rounding.
        level_of = function(points)
            for level = Sins.MAX_LEVEL, 1, -1 do
                if points >= Sins.RISING_STEP * level * (level + 1) then
                    return level
                end
            end
            return 0
        end,
        total_for = function(level)
            return Sins.RISING_STEP * level * (level + 1)
        end,
    },
}

--- The ladder a stat climbs.
local function ladder_of(key)
    return Sins.LADDERS[(Sins.STATS[key] or {}).ladder or "flat"]
end
Sins.ladder_of = ladder_of

--------------------------------------------------------------------------------
-- The climb
--------------------------------------------------------------------------------

--- True while the run is being played on this deck, or its sleeve.
function Sins.active()
    return CelestasMod.run_has_deck(Sins.DECK)
end

--- The run's stats, created on first ask. Nil off this deck, which is what
--- every source below checks before it counts anything.
function Sins.state()
    if not (G.GAME and Sins.active()) then return nil end
    local state = G.GAME.celesta_sins
    if state then
        -- A run saved before a field existed comes back without it. Backfilled
        -- on the way out rather than at load, because there is no load hook a
        -- deck gets - and the panel read `nil` out of exactly this gap.
        if state.greed and state.greed.to_next == nil then
            Sins.refresh_progress()
        end
        return state
    end
    if not state then
        state = {}
        for _, key in ipairs(Sins.ORDER) do
            state[key] = { level = 0, points = 0 }
        end
        G.GAME.celesta_sins = state
        Sins.refresh_progress()
    end
    return state
end

--- How many more points each stat needs for its next level, written onto the
--- stat itself so the sidebar can bind to it and watch it count down rather
--- than rebuilding the panel every time a card scores.
---
--- All seven are refreshed together: the one that just gained is not the only
--- one whose answer changed, because a stat reaching twenty closes its whole
--- set and everything else in it stops needing anything.
--- Guarded against re-entry. This is reached from Sins.state(), and the work
--- below asks for stats and for Sloth's world numbers, which ask state() back
--- - without this the first call never returns.
local refreshing = false

function Sins.refresh_progress()
    local state = G.GAME and G.GAME.celesta_sins
    if not state or refreshing then return end
    refreshing = true

    -- Which sets are closed, read off the raw table rather than through
    -- Sins.set_is_closed for the same reason: that one asks state().
    local closed = {}
    if not Sins.lockout_lifted() then
        for set, keys in ipairs(Sins.SETS) do
            for _, key in ipairs(keys) do
                if state[key] and (state[key].level or 0) >= Sins.MAX_LEVEL then
                    closed[set] = true
                end
            end
        end
    end

    for _, key in ipairs(Sins.ORDER) do
        local stat = state[key]
        local def = Sins.STATS[key]
        if stat and def then
            if stat.level >= Sins.MAX_LEVEL or closed[def.set] then
                stat.to_next = 0
            else
                local ladder = ladder_of(key)
                local left = ladder.total_for(stat.level + 1) - stat.points
                -- One decimal: a single +3 Mult is a whole point, but a Bonus
                -- card is a fraction of one, so the remainder is rarely round.
                stat.to_next = math.floor(left * 10 + 0.5) / 10
            end
        end
    end
    refreshing = false
    -- Sloth's shop discount, interest and Rare rate follow its level, so they
    -- are brought back into line the moment that level can have moved. After
    -- the guard is lifted, because this reads the stats back.
    if Sins.sync_world then Sins.sync_world() end
end

--- One stat, or nil off this deck.
function Sins.get(key)
    local state = Sins.state()
    return state and state[key] or nil
end

--- Its level, and 0 when there is no run on this deck to ask about.
function Sins.level(key)
    local stat = Sins.get(key)
    return stat and stat.level or 0
end

--- How far into the next level, 0 to 1. The bar the sidebar draws.
function Sins.progress(key)
    local stat = Sins.get(key)
    if not stat or stat.level >= Sins.MAX_LEVEL then return 1 end
    local ladder = ladder_of(key)
    local base = ladder.total_for(stat.level)
    local span = ladder.total_for(stat.level + 1) - base
    if span <= 0 then return 1 end
    return (stat.points - base) / span
end

--- True once an Unholy Stone has been used this run: the set lockout is off
--- and every stat can be taken to twenty. On G.GAME, so it is saved with the
--- run like everything else here.
function Sins.lockout_lifted()
    return (G.GAME and G.GAME.celesta_sins_unholy) and true or false
end

--- Lifts it, once.
function Sins.lift_lockout()
    if not G.GAME then return end
    G.GAME.celesta_sins_unholy = true
    -- Six stats have just stopped needing nothing, so the countdowns move.
    Sins.refresh_progress()
end

--- True once any stat in `set` has reached the top.
function Sins.set_is_closed(set)
    local state = Sins.state()
    if not state then return false end
    if Sins.lockout_lifted() then return false end
    for _, key in ipairs(Sins.SETS[set] or {}) do
        if state[key] and state[key].level >= Sins.MAX_LEVEL then return true end
    end
    return false
end

--- True while `key` can still take points.
---
--- A maxed stat closes its whole set, itself included: the first of the four
--- suits - or of the three scores - to reach twenty is the only one that ever
--- does, which is the choice the deck is asking the player to make.
function Sins.can_gain(key)
    local def = Sins.STATS[key]
    local stat = Sins.get(key)
    if not (def and stat) then return false end
    return not Sins.set_is_closed(def.set)
end

--- Adds points, levels up what they earn, and says how many levels that was.
--- Fractional on purpose: a single +3 Mult is one point, and a single Bonus
--- card is a fraction of one, so the ladder has to hold the remainder.
---
--- Rounded to six places on the way in, which is not tidiness. A third of a
--- Mult cannot be written exactly in binary, so thirty Mult paid as 30, or as
--- 29 and 1, lands on 19.999999999999996 rather than 20 - and the player is
--- told they are one level lower than they earned, for the rest of the run.
--- Six places is far finer than any source here moves and far coarser than
--- the error, so it removes the error and nothing else.
local function tidy(n)
    return math.floor(n * 1e6 + 0.5) / 1e6
end

function Sins.add(key, points)
    if not (type(points) == "number" and points > 0) then return 0 end
    local stat = Sins.get(key)
    if not (stat and Sins.can_gain(key)) then return 0 end

    local ladder = ladder_of(key)
    local before = stat.level
    stat.points = math.min(tidy(stat.points + points),
                           ladder.total_for(Sins.MAX_LEVEL))
    stat.level = math.min(ladder.level_of(stat.points), Sins.MAX_LEVEL)
    Sins.refresh_progress()
    return stat.level - before
end

--- The stat whose suit `card` is, if any.
---
--- is_suit rather than base.suit, which is what every suit question in this
--- mod goes through - so a card standing in for a suit counts as it.
function Sins.suit_stat_for(card)
    if not (card and card.is_suit) then return nil end
    for _, key in ipairs(Sins.SETS[1]) do
        if card:is_suit(Sins.STATS[key].suit) then return key end
    end
    return nil
end

--- The stat `card`'s edition feeds, or nil for no edition and for the two
--- that feed nothing.
---
--- `edition.type` rather than `edition.foil` or `edition.key`: vanilla's
--- Card:set_edition writes all three (card.lua:517) and so does Steamodded's
--- replacement (overrides.lua:2074), but `type` is the one both spell the
--- same way, and it is a plain string rather than a set of flags to search.
function Sins.edition_stat(card)
    local edition = card and card.edition
    if type(edition) ~= "table" then return nil end
    return EDITION_STAT[edition.type]
end

--- True while the Joker for this stat's suit is owned.
---
--- Through the global find_joker, which matches on ability.name - so a
--- Greedy Joker merged into something else still counts as owned, which
--- SMODS.find_card would miss (merge/bind.lua says why it is that one).
function Sins.suit_joker_owned(stat_key)
    local name = (Sins.STATS[stat_key] or {}).joker_name
    if not (name and find_joker) then return false end
    return next(find_joker(name)) ~= nil
end

--------------------------------------------------------------------------------
-- The five things that push them up
--------------------------------------------------------------------------------

--- Stat set 1, first source: the Mult a suit Joker paid for a scored card.
---
--- The stat credited is the SCORED CARD'S suit, and it only counts while the
--- Joker for that suit is owned. Those are two separate tests and both have
--- to hold: a Diamond scored with only the Spades Joker owned feeds nothing,
--- whichever Joker happened to pay for it.
---
--- That matters the moment anything decouples the two. Arielle makes every
--- card count as one suit, so the Diamonds Joker starts paying for Hearts -
--- and crediting the Joker's stat would have levelled Greed off cards that
--- were not Diamonds and had no Greedy Joker behind them.
---
--- The AMOUNT is still what calculate_joker returned, so a retrigger counts
--- twice because it really did pay twice, and a debuffed Joker counts for
--- nothing because it really did pay nothing.
celesta_sins_traced = 0

--- The stats a payment is SHARED with, or nil when the card says plainly
--- which suit it is.
---
--- Three things blur a scored card's suit, and each blurs it differently:
---
---   * a Wild card is every suit at once, by itself
---   * Arielle says the same thing about the whole deck: every card counts as
---     every suit, so a scored card is exactly as ambiguous as a Wild one
---   * a Smeared Joker unions each card with its OWN COLOUR only, so the
---     confusion is between Spades and Clubs, or Diamonds and Hearts, and
---     nothing is shared across the colours
---
--- Arielle is asked first and through the same joker_in_play the mod's own
--- SMODS.smeared_check wrapper asks (jokers/implemented.lua) - so an Arielle
--- that is not widening suits, because a replacing merge speaks for it, does
--- not widen this either. Asking Smeared first would answer the narrow pair
--- while Arielle had already made the card every suit.
local function sins_shared_with(other, paying)
    if SMODS.has_enhancement(other, "m_wild")
        or CelestasMod.joker_in_play(ARIELLE_KEY) then
        -- All four, and the caller skips the one that earned it.
        return Sins.SETS[1]
    end
    -- find_joker by display name, the same question SMODS.smeared_check asks
    -- before it unions anything (utils.lua:2435).
    if find_joker and next(find_joker("Smeared Joker")) then
        local partner = SMEAR_PARTNER[paying]
        if partner then return { partner } end
    end
    return nil
end

local function sins_joker_mult(card, context, effect)
    if not (type(effect) == "table" and type(effect.mult) == "number") then return end
    if effect.mult <= 0 then return end

    -- Paid by one of the four, for a card that is being scored.
    local center = card.config and card.config.center
    local key = center and center.key
    local paying = key and JOKER_STAT[key]
    if not paying then return end
    local other = context and context.other_card
    if not other then return end

    local points = effect.mult * PER_MULT

    -- When the card cannot say which suit it is, the JOKER says instead: its
    -- own suit takes the whole amount and whoever it is confused with takes
    -- half each.
    --
    -- Those sharers are not gated on owning their Jokers, which every other
    -- route into these four stats is. They cannot be: buying one of the four
    -- bans the other three for the rest of the run, so a gate here would make
    -- this rule unreachable by construction.
    local shared = sins_shared_with(other, paying)
    if shared then
        Sins.add(paying, points)
        for _, stat in ipairs(shared) do
            if stat ~= paying then
                Sins.add(stat, points * Sins.SHARED_SPLIT)
            end
        end
        return
    end

    local stat = Sins.suit_stat_for(other)
    if not (stat and Sins.suit_joker_owned(stat)) then return end

    Sins.add(stat, points)

    -- TEMPORARY [sins] trace - remove once the suit report is settled.
    --
    -- The report is that an off-suit card feeds a suit stat. It does not do
    -- that here or in a harness, so this says what actually arrived: which
    -- Joker paid, what it paid, which card it was looking at, and whether
    -- that card really is the stat's suit.
    --
    -- AFTER the award, and behind its own pcall. A trace ahead of the work
    -- can stop the work: this one sat above Sins.add, sendInfoMessage was
    -- missing in a harness, and the enclosing pcall swallowed the error - so
    -- nothing was ever awarded. A diagnostic must not be able to break the
    -- thing it is diagnosing.
    if celesta_sins_traced < 24 and sendInfoMessage then
        celesta_sins_traced = celesta_sins_traced + 1
        pcall(function()
            sendInfoMessage(("[sins] %s paid %s -> %s | card %s of %s | owned=%s"):format(
                tostring(key), tostring(effect.mult), tostring(stat),
                tostring(other.base and other.base.value),
                tostring(other.base and other.base.suit),
                tostring(Sins.suit_joker_owned(stat))), "CelestasMod")
        end)
    end
end

--- Stat set 2: a Joker whose edition feeds a stat, each time it triggers.
---
--- "Triggered" is taken to be "answered a context with an effect", which is
--- what makes a Joker flash and say something. A Joker asked a question it
--- has no answer to has not triggered.
---
--- Blueprint copies are left out: the context is raised against the copied
--- Joker, but it is the Blueprint that acts and the Blueprint's own edition
--- that is on the card the player sees go off.
local function sins_joker_edition(card, context, effect)
    if type(effect) ~= "table" then return end
    if context and context.blueprint then return end
    local stat = Sins.edition_stat(card)
    if stat then Sins.add(stat, PER_EDITION) end
end

--- Stat set 1, second source: cards destroyed of the OPPOSITE suit.
---
--- is_suit rather than base.suit, which is what every suit question in this
--- mod goes through - so a Wild card counts as the suit it is standing in for,
--- and as both when it is standing in for both.
local function sins_destroyed(removed)
    for _, card in ipairs(removed or {}) do
        if type(card) == "table" and card.is_suit then
            for suit, stat in pairs(DESTROYED_STAT) do
                if card:is_suit(suit) then Sins.add(stat, PER_DESTROYED) end
            end
        end
    end
end

--- Stat set 2: what a scoring card paid, when it is the enhancement that
--- stat counts.
---
--- The Mult is read off the ability rather than through Card:get_chip_mult,
--- which ROLLS for a Lucky Card on the way past (card.lua:1213). Asking it
--- here would spend a pull from the run's stream for a number nothing scores.
local function sins_scoring_card(other)
    if not (type(other) == "table" and other.ability) or other.debuff then return end

    -- The card's edition, on the same terms as a Joker's: scoring is what a
    -- playing card does instead of answering a context.
    local edition = Sins.edition_stat(other)
    if edition then Sins.add(edition, PER_EDITION) end

    if SMODS.has_enhancement(other, "m_bonus") and other.get_chip_bonus then
        local chips = other:get_chip_bonus()
        if type(chips) == "number" and chips > 0 then
            Sins.add("pride", chips * PER_CHIP)
        end
    end

    if SMODS.has_enhancement(other, "m_mult") then
        local mult = (other.ability.mult or 0) + (other.ability.perma_mult or 0)
        if type(mult) == "number" and mult > 0 then
            Sins.add("envy", mult * PER_ENH_MULT)
        end
    end
end

--- Once one of the four is bought, none of them can be offered again.
---
--- banned_keys is the supported way out of every pool at once - the shop, the
--- packs and anything that makes a Joker all end at get_current_pool - and it
--- is saved with G.GAME, the same mechanism the Ecstasy Deck uses.
local function sins_bought(card)
    local key = card and card.config and card.config.center
        and card.config.center.key
    if not (key and JOKER_STAT[key]) then return end
    G.GAME.banned_keys = G.GAME.banned_keys or {}
    for joker in pairs(JOKER_STAT) do
        G.GAME.banned_keys[joker] = true
    end
    G.GAME.celesta_sins_claimed = true
end

--------------------------------------------------------------------------------
-- ...and the one place all of them are heard
--------------------------------------------------------------------------------
--
-- SMODS.calculate_card_areas is the funnel every context goes through, and the
-- only one that sees all three of these. calculate_context does not: the
-- per-card scoring pass calls calculate_card_areas('individual', ...) directly
-- from SMODS.score_card, once per repetition, and never comes back through
-- calculate_context at all.
--
-- Guarded whole, and by a re-entry flag. This runs inside scoring, and a fault
-- or a loop here would take the hand down with it; a stat that quietly stops
-- counting is a bug, a hand that cannot be scored is a broken run.

local observing = false

local function sins_observe(area, context)
    if observing or not (type(context) == "table") then return end
    if not Sins.state() then return end
    -- The quantum-enhancement probe runs every Joker over a card to ask what
    -- it counts as. Nothing scored, so nothing to count.
    if context.check_enhancement or context.extra_enhancement then return end

    observing = true
    pcall(function()
        if area == "individual" and context.cardarea == G.play
            and context.other_card and not context.blueprint then
            sins_scoring_card(context.other_card)
        end
        -- Both gated to the `jokers` pass, not to main_eval alone.
        -- SMODS.calculate_context raises main_eval for the `jokers` pass AND
        -- again for `individual` (utils.lua:1902 and :1907), and both of these
        -- arrive through it - so keying on main_eval alone was hearing every
        -- destroyed card twice and paying the suit stats double for it.
        if area == "jokers" and context.remove_playing_cards
            and context.main_eval then
            sins_destroyed(context.removed)
        end
        if area == "jokers" and context.buying_card and context.main_eval then
            sins_bought(context.card)
        end

        -- Sloth: a Lucky card's 1 in 15 counts as that much money SPENT, even
        -- though it is money arriving. Asked for by name, and it has to be
        -- asked this way: the card's own lucky_trigger flag is set by BOTH of
        -- its rolls - the 1 in 5 for Mult and the 1 in 15 for money
        -- (card.lua:1187 and :1312) - so the flag alone cannot tell them
        -- apart. Steamodded reports every roll it makes with the identifier
        -- that asked for it, which can.
        --
        -- Gated to the `jokers` pass because main_eval is true for that one
        -- AND for `individual` (utils.lua:1902 and :1907), so anything keyed
        -- on main_eval alone is heard twice.
        if area == "jokers" and context.main_eval
            and context.pseudorandom_result and context.result
            and context.identifier == "lucky_money" then
            local trigger = context.trigger_obj
            local paid = trigger and trigger.ability
                and trigger.ability.p_dollars
            if type(paid) ~= "number" or paid <= 0 then paid = LUCKY_DOLLARS end
            Sins.add("sloth", paid * PER_DOLLAR)
        end
    end)
    observing = false
end

--- Installed from Game:start_run rather than at load, for the reason LucyPyre
--- and Dooby are: every other mod has loaded by then, so these sit outside
--- their wrappers instead of under them, and the identity guards stop a second
--- run from stacking another copy on top.
local areas_wrapper, joker_wrapper, ease_wrapper

--- Which installation of each hook is the live one.
---
--- The identity guards below stop a second wrapper going on while ours is
--- still the outermost. They cannot stop this: another mod wraps one of these
--- globals AFTER we did, our guard sees a stranger, and we wrap again to stay
--- outside it - leaving our previous copy alive further down the chain. Both
--- then run, and a dollar spent is counted once per layer. Game:start_run
--- does this every run, so the layers pile up all session: Sloth reached 273
--- points in two rounds of Ante 2, and $9 bought 189 of them.
---
--- Each wrapper captures the generation it was made in and does nothing
--- unless it is still the current one, so the older copies stay in the chain
--- as pass-throughs rather than as extra voices.
local areas_gen, joker_gen, ease_gen = 0, 0, 0

function CelestasMod.install_sins_hooks()
    if SMODS.calculate_card_areas ~= areas_wrapper then
        local ref = SMODS.calculate_card_areas
        if type(ref) == "function" then
            areas_gen = areas_gen + 1
            local mine = areas_gen
            areas_wrapper = function(area, context, ...)
                if mine == areas_gen then sins_observe(area, context) end
                return ref(area, context, ...)
            end
            SMODS.calculate_card_areas = areas_wrapper
        end
    end

    if Card.calculate_joker ~= joker_wrapper then
        local ref = Card.calculate_joker
        if type(ref) == "function" then
            joker_gen = joker_gen + 1
            local mine = joker_gen
            joker_wrapper = function(self, context, ...)
                -- Two returns: calculate_joker answers with (effect, post).
                local effect, post = ref(self, context, ...)
                if mine == joker_gen and Sins.state() then
                    pcall(sins_joker_mult, self, context, effect)
                    pcall(sins_joker_edition, self, context, effect)
                end
                return effect, post
            end
            Card.calculate_joker = joker_wrapper
        end
    end

    -- Sloth: money leaving the player's hands, wherever it goes. `mod` is
    -- negative on the way out, and Talisman's big numbers only compare
    -- through to_big - which is there whenever one of them is.
    if ease_dollars ~= ease_wrapper then
        local ref = ease_dollars
        if type(ref) == "function" then
            ease_gen = ease_gen + 1
            local mine = ease_gen
            ease_wrapper = function(mod, ...)
                if mine == ease_gen and Sins.state() then
                    local spent
                    if type(mod) == "number" then
                        spent = mod < 0 and -mod or nil
                    elseif type(mod) == "table" and to_big
                        and to_big(mod) < to_big(0) then
                        spent = -mod
                    end
                    if spent then
                        pcall(function() Sins.add("sloth", spent * PER_DOLLAR) end)
                    end
                end
                return ref(mod, ...)
            end
            ease_dollars = ease_wrapper
        end
    end
end

local celesta_sins_start_run_ref = Game.start_run
function Game:start_run(args)
    CelestasMod.install_sins_hooks()
    return celesta_sins_start_run_ref(self, args)
end

--------------------------------------------------------------------------------
-- The first shop
--------------------------------------------------------------------------------
--
-- The deck opens with Overstock and Overstock Plus, so the first shop has four
-- Joker slots rather than two - which is exactly the four this fills.
--
-- create_card_for_shop is the one place a shop card is made
-- (UI_definitions.lua:742), and it already has a branch that returns a forced
-- card, which is the shape the Ecstasy Deck uses a few files over. Handing
-- them out from a queue rather than rolling for each means the first shop has
-- all four and the second has none, without counting slots.
--
-- The queue is on G.GAME so a run saved inside its first shop comes back with
-- whatever is left of it, rather than dealing the four a second time.

local function sins_queue()
    if not Sins.state() then return nil end
    if G.GAME.celesta_sins_offered == nil then
        local queue = {}
        for _, key in ipairs(Sins.ORDER) do
            local def = Sins.STATS[key]
            if def.joker then queue[#queue + 1] = def.joker end
        end
        G.GAME.celesta_sins_offered = queue
    end
    return G.GAME.celesta_sins_offered
end

local celesta_sins_shop_ref = create_card_for_shop
function create_card_for_shop(area)
    if area == G.shop_jokers then
        local queue = sins_queue()
        local key = queue and queue[1]
        local center = key and G.P_CENTERS[key]
        if center then
            table.remove(queue, 1)
            -- A forced key goes straight to the centre and never consults a
            -- pool, so a banned or already-owned one is still offered here -
            -- which is the point: these four are guaranteed.
            local card = create_card(center.set, area, nil, nil, nil, nil, key, "sho")
            if card then
                create_shop_card_ui(card, center.set, area)
                return card
            end
        end
    end
    return celesta_sins_shop_ref(area)
end
