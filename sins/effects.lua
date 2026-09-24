--- What the Deck of Sins' stats actually do.
---
--- Every effect is a TIER: a level it unlocks at and a function from the
--- stat's level to what it is worth. One table drives both the scoring below
--- and the list the sidebar shows when a stat is clicked, so a tier cannot do
--- one thing and say another.
---
--- The scoring lives on the deck's own `calculate`. A Back IS a scoring
--- target - SMODS.get_card_areas('individual') puts G.GAME.selected_back in
--- the list, and every SMODS.calculate_context dispatch reaches it - so the
--- deck answers contexts exactly the way a Joker does, without a Joker to
--- hang them on. The two it leans on hardest:
---
---     context.initial_scoring_step   after the hand is named, before any
---                                    card has scored - which is what "base
---                                    Chips" means (state_events.lua:656)
---     context.final_scoring_step     after every card and Joker has scored,
---                                    which is "after the hand is scored"
---                                    (state_events.lua:749)
---
--- context.joker_main is NOT among them: it is raised by eval_card directly
--- inside the Joker loop and never goes through calculate_context, so a deck
--- never sees it. That is why the two halves of Pride and Envy sit on the two
--- steps above rather than on one pass.

local Sins = CelestasMod.Sins

--- floor(level / every), which is the shape of every "+1 per N levels" tier.
local function per(every)
    return function(level) return math.floor(level / every) end
end

--- The first entry whose level has been reached, walked from the top.
local function step(pairs_list)
    return function(level)
        for _, entry in ipairs(pairs_list) do
            if level >= entry[1] then return entry[2] end
        end
        return nil
    end
end

--- Each stat's tiers, in unlock order. `at` is the level it starts at,
--- `value` is what it is worth at a given level, and `loc` names the line the
--- sidebar shows for it.
Sins.TIERS = {}

-- The four suits share one ladder, so it is written once.
local SUIT_TIERS = {
    { at = 1,  key = "chips",      loc = "chips",      value = function(l) return 5 * l end },
    { at = 2,  key = "mult",       loc = "mult",       value = per(2) },
    { at = 4,  key = "dollars",    loc = "dollars",    value = per(4) },
    { at = 10, key = "retriggers", loc = "retriggers", value = per(10) },
}
for _, key in ipairs(Sins.SETS[1]) do
    Sins.TIERS[key] = SUIT_TIERS
end

local SCORE_X = step { { 20, 5 }, { 15, 3 }, { 10, 2 }, { 5, 1.5 } }

Sins.TIERS.pride = {
    { at = 1,  key = "base",       loc = "pride_base",  value = function(l) return 5 * l end },
    { at = 5,  key = "x",          loc = "pride_x",     value = SCORE_X },
    { at = 20, key = "retriggers", loc = "pride_retrigger", value = function() return 2 end },
}
Sins.TIERS.envy = {
    { at = 1,  key = "base",       loc = "envy_base",   value = function(l) return 5 * l end },
    { at = 5,  key = "x",          loc = "envy_x",      value = SCORE_X },
    { at = 20, key = "retriggers", loc = "envy_retrigger", value = function() return 2 end },
}
Sins.TIERS.sloth = {
    { at = 1,  key = "dollars",  loc = "sloth_dollars",  value = function(l) return l end },
    { at = 4,  key = "discount", loc = "sloth_discount",
      value = step { { 20, 100 }, { 16, 75 }, { 12, 50 }, { 8, 25 }, { 4, 10 } } },
    { at = 5,  key = "interest", loc = "sloth_interest",
      value = function(l) return math.floor(l / 5) + 1 end },
    { at = 9,  key = "rares",    loc = "sloth_rares",    value = function() return true end },
    { at = 18, key = "legendary", loc = "sloth_legendary", value = function() return true end },
}

--- What `key` is worth for this stat right now, or nil below its tier.
---
--- The unlock level and the formula are asked together, so a tier that has
--- not been reached cannot be read by accident - every caller below gets nil
--- rather than a number it would have to remember to gate itself.
function Sins.tier(stat_key, tier_key)
    local level = Sins.level(stat_key)
    for _, tier in ipairs(Sins.TIERS[stat_key] or {}) do
        if tier.key == tier_key then
            if level < tier.at then return nil end
            local value = tier.value(level)
            if value == 0 then return nil end
            return value
        end
    end
    return nil
end

--- Every tier of a stat, with what it is worth and whether it is unlocked.
--- This is what the sidebar lists when a stat is clicked.
function Sins.tier_list(stat_key)
    local level = Sins.level(stat_key)
    local out = {}
    for _, tier in ipairs(Sins.TIERS[stat_key] or {}) do
        out[#out + 1] = {
            key = tier.key,
            loc = tier.loc,
            at = tier.at,
            unlocked = level >= tier.at,
            -- Shown at its unlock level while it is still locked, so the list
            -- says what is coming rather than 0 of something.
            value = tier.value(math.max(level, tier.at)),
        }
    end
    return out
end

--------------------------------------------------------------------------------
-- Sloth's three world tiers
--------------------------------------------------------------------------------
--
-- These do not return an effect to a scoring pass; they move numbers the run
-- reads elsewhere. So each is HELD as a difference against what this deck has
-- already applied - Rainhoe's and Vantacrow's shape - and every one of them
-- goes through the same routine, which does nothing unless the answer is
-- changing. That is what makes it safe to call on every point gained.
---
--- What the deck currently holds, on G.GAME so it is saved with the run and
--- cannot drift across a reload.
local function world()
    G.GAME.celesta_sins_world = G.GAME.celesta_sins_world
        or { discount = 0, interest = 0, rare = 0 }
    return G.GAME.celesta_sins_world
end

--- Moves `field` by the difference between what is held and what is wanted.
local function hold(key, want, apply)
    local held = world()
    want = want or 0
    if held[key] == want then return end
    apply(want - held[key])
    held[key] = want
end

--- Brings all three in line with Sloth's level. Called whenever points move
--- and when a run is loaded, so there is no moment where the level and the
--- run disagree.
function Sins.sync_world()
    if not (G.GAME and Sins.state()) then return end

    -- Shop prices. discount_percent is vanilla's own, the one Clearance Sale
    -- writes and Card:set_cost reads (card.lua:505).
    hold("discount", Sins.tier("sloth", "discount") or 0, function(delta)
        G.GAME.discount_percent = (G.GAME.discount_percent or 0) + delta
    end)

    -- Interest, as a multiplier expressed as a difference, the way Rainhoe
    -- holds its tripled rate: the base rate is what the run would have had,
    -- so what this adds is that base times one less than the multiplier.
    local mult = Sins.tier("sloth", "interest") or 1
    local base = (G.GAME.interest_amount or 0) - world().interest
    hold("interest", base * (mult - 1), function(delta)
        G.GAME.interest_amount = (G.GAME.interest_amount or 0) + delta
    end)

    -- Rare Jokers. rare_mod is read inside SMODS.poll_rarity off G.GAME
    -- (utils.lua:838), so raising it is all this tier has to do. Vanilla's
    -- weights are Common 0.70, Uncommon 0.25, Rare 0.05 - so five times makes
    -- a Rare land about as often as an Uncommon, which is what was asked.
    hold("rare", Sins.tier("sloth", "rares") and (Sins.RARE_BOOST - 1) or 0,
        function(delta)
            G.GAME.rare_mod = (G.GAME.rare_mod or 1) + delta
        end)
end

Sins.RARE_BOOST = 5
Sins.LEGENDARY_ODDS = 20

--------------------------------------------------------------------------------
-- ...and the two that need a hook of their own
--------------------------------------------------------------------------------
--
-- Installed from Game:start_run for the reason every other late hook in this
-- mod is: by then every other mod has loaded, so these sit outside their
-- wrappers rather than under them.

local cost_wrapper, rarity_wrapper

--- Which installation of each hook below is the live one.
---
--- The identity guards stop a second wrapper going on while ours is still the
--- outermost. They cannot stop this: another mod wraps the same global AFTER
--- we did, our guard sees a stranger, and we wrap again to stay outside it -
--- leaving the previous copy alive further down the chain, where it still
--- runs. Game:start_run installs these every run, so the layers pile up for
--- as long as the session lasts.
---
--- Each wrapper captures the generation it was made in and stands aside
--- unless it is still the current one, so older copies are pass-throughs.
local cost_gen, rarity_gen = 0, 0

function CelestasMod.install_sloth_hooks()
    -- Free at twenty. discount_percent cannot do this on its own: set_cost
    -- ends in math.max(1, ...), so a hundred per cent off is still a dollar.
    if Card.set_cost ~= cost_wrapper then
        local ref = Card.set_cost
        if type(ref) == "function" then
            cost_gen = cost_gen + 1
            local mine = cost_gen
            cost_wrapper = function(self, ...)
                local ret = ref(self, ...)
                if mine == cost_gen and Sins.state()
                    and (Sins.tier("sloth", "discount") or 0) >= 100 then
                    self.cost = 0
                end
                return ret
            end
            Card.set_cost = cost_wrapper
        end
    end

    -- Legendaries in the shop. The pool a shop rolls from has no Legendary
    -- weight to raise, so this upgrades a roll that already landed rather
    -- than reweighting a rarity that is not there. Taken from Common, the
    -- most frequent answer, so the Uncommon and Rare rates are left alone.
    if SMODS.poll_rarity ~= rarity_wrapper then
        local ref = SMODS.poll_rarity
        if type(ref) == "function" then
            rarity_gen = rarity_gen + 1
            local mine = rarity_gen
            rarity_wrapper = function(pool_key, rand_key, ...)
                local rarity = ref(pool_key, rand_key, ...)
                -- Stacked copies would each roll the upgrade, so a Legendary
                -- would come up once per layer AND burn a pull from the run's
                -- stream every time.
                if mine == rarity_gen and rarity == 1 and Sins.state()
                    and Sins.tier("sloth", "legendary")
                    and pseudorandom(pseudoseed("celesta_sins_legendary"))
                        < 1 / Sins.LEGENDARY_ODDS then
                    return 4
                end
                return rarity
            end
            SMODS.poll_rarity = rarity_wrapper
        end
    end
end

local celesta_sloth_start_run_ref = Game.start_run
function Game:start_run(args)
    CelestasMod.install_sloth_hooks()
    local ret = celesta_sloth_start_run_ref(self, args)
    -- After the run exists, so a loaded save has its stats back before the
    -- three numbers above are brought into line with them.
    Sins.sync_world()
    return ret
end

--------------------------------------------------------------------------------
-- Scoring
--------------------------------------------------------------------------------

--- The stat whose suit a card is. Shared with the tracking in sins.lua, so
--- the suit a card scores FOR and the suit it counts TOWARDS cannot drift.
local suit_stat_for = Sins.suit_stat_for

--- The level of the hand being scored, which Pride and Envy multiply by.
local function hand_level(context)
    local hand = context.scoring_name and G.GAME.hands
        and G.GAME.hands[context.scoring_name]
    local level = hand and hand.level or 1
    -- A hand can be levelled DOWN below 1; a negative multiplier would turn a
    -- bonus into a penalty, which is not what "receives" means.
    if type(level) ~= "number" or level < 1 then return 1 end
    return level
end

--- One scored card of a stat's own suit.
local function suit_scored(stat_key)
    local effect = {
        chips = Sins.tier(stat_key, "chips"),
        mult = Sins.tier(stat_key, "mult"),
        dollars = Sins.tier(stat_key, "dollars"),
    }
    if effect.chips or effect.mult or effect.dollars then return effect end
    return nil
end

--- The deck's whole scoring answer. Called from the Back in items/decks.lua.
function Sins.calculate(back, context)
    if not Sins.state() then return end

    -- ---- a scored card of one of the four suits ----
    if context.individual and context.cardarea == G.play and context.other_card then
        local stat_key = suit_stat_for(context.other_card)
        if stat_key then
            local effect = suit_scored(stat_key)
            if effect then
                effect.card = context.other_card
                return effect
            end
        end
        return
    end

    -- ---- retriggers: the suits, and Pride's and Envy's enhancements ----
    if context.repetition and context.cardarea == G.play and context.other_card then
        local other = context.other_card
        local reps = 0

        local stat_key = suit_stat_for(other)
        if stat_key then reps = reps + (Sins.tier(stat_key, "retriggers") or 0) end
        if SMODS.has_enhancement(other, "m_bonus") then
            reps = reps + (Sins.tier("pride", "retriggers") or 0)
        end
        if SMODS.has_enhancement(other, "m_mult") then
            reps = reps + (Sins.tier("envy", "retriggers") or 0)
        end

        if reps > 0 then return { repetitions = reps, card = other } end
        return
    end

    -- ---- base Chips and Mult, before a card has scored ----
    if context.initial_scoring_step then
        local level = hand_level(context)
        local chips = Sins.tier("pride", "base")
        local mult = Sins.tier("envy", "base")
        if chips or mult then
            return {
                chips = chips and chips * level or nil,
                mult = mult and mult * level or nil,
            }
        end
        return
    end

    -- ---- and the multipliers, once everything else has scored ----
    if context.final_scoring_step then
        local x_chips = Sins.tier("pride", "x")
        local x_mult = Sins.tier("envy", "x")
        if (x_chips and x_chips > 1) or (x_mult and x_mult > 1) then
            return {
                x_chips = x_chips and x_chips > 1 and x_chips or nil,
                x_mult = x_mult and x_mult > 1 and x_mult or nil,
            }
        end
        return
    end

    -- ---- Sloth's cash-out ----
    -- Guarded off the retrigger and per-card passes the way Paperback's decks
    -- guard theirs: a deck has no context.main_eval to lean on.
    if context.end_of_round and not context.repetition and not context.individual then
        local dollars = Sins.tier("sloth", "dollars")
        if dollars then return { dollars = dollars } end
        return
    end
end
