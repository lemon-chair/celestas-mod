--- BOSS BLINDS
---
--- Chip art is built by tools/gen_blinds.py. Blind chips are animated: the
--- vanilla atlas is registered with frames = 21 at 34x34, so a blind's atlas
--- must match that shape or the chip renders wrong.
---
--- Keys get the `bl` class prefix plus the mod prefix, so `clover` registers
--- as bl_celesta_clover and reads its text from descriptions.Blind.

CelestasMod.CLOVER_ODDS = 2

local CLOVER_SEED = "celesta_clover"
-- Resolved at load: SMODS.current_mod is only valid while the mod is loading,
-- and the hooks below run for the rest of the session.
local CLOVER_KEY = "bl_" .. SMODS.current_mod.prefix .. "_clover"

--- True while The Clover is the blind being played.
--- Read fresh each time rather than latched: a blind can be disabled mid-round
--- (Chicot, a Voucher), and a latched flag would keep suppressing after it.
local function clover_active()
    local blind = G.GAME and G.GAME.blind
    if not (blind and blind.config and blind.config.blind) then return false end
    if blind.disabled then return false end
    return blind.config.blind.key == CLOVER_KEY
end

-- Set while the roll itself is running. SMODS.pseudorandom_probability fires
-- mod_probability and fix_probability, and both re-enter every joker - which
-- comes straight back into the hook below. Without this the first roll never
-- finishes.
local clover_rolling = false

-- One decision per object per play or discard. hands_left and discards_left
-- are both decremented before anything is evaluated, so this is stable across
-- one event and changes the moment the next begins.
local decisions = setmetatable({}, { __mode = "k" })

local function event_id()
    local round = G.GAME and G.GAME.current_round
    if not round then return "?" end
    return table.concat({ tostring(G.GAME.round), tostring(round.hands_left),
                          tostring(round.discards_left) }, "/")
end

--- True when this card or joker is stopped from triggering for this event.
---
--- The roll goes through SMODS.pseudorandom_probability rather than a plain
--- pseudorandom, and that is the whole point of the blind: the helper runs the
--- mod_probability pass, so anything that edits listed odds edits this one
--- too. Oops! All 6s doubles the numerator, which turns 1 in 2 into 2 in 2 and
--- cancels the blind outright.
---
--- Rolled once per object per event rather than per trigger. Per trigger would
--- mean a probability lookup - two full evaluation passes - on every context
--- every joker sees, which is precisely what once took a hand from 4k
--- calculations to 88k and locked the game up.
local function clover_suppresses(obj)
    if clover_rolling or not clover_active() then return false end

    local id = event_id()
    local cached = decisions[obj]
    if cached and cached.id == id then return cached.suppressed end

    clover_rolling = true
    local ok, triggered = pcall(SMODS.pseudorandom_probability, obj,
        CLOVER_SEED, 1, CelestasMod.CLOVER_ODDS, CLOVER_SEED)
    clover_rolling = false

    -- A roll that errored lets the object through: a boss that silently
    -- switches everything off is far worse than one that misses a card.
    local suppressed = ok and not triggered or false
    decisions[obj] = { id = id, suppressed = suppressed }
    return suppressed
end

-- Getter contexts ask a question rather than producing an effect. Suppressing
-- those would corrupt display and probability lookups rather than stopping a
-- trigger - and mod_probability in particular is how the roll itself is
-- modified, so answering it wrong would break the Oops! interaction.
local function is_query(context)
    return context.mod_probability or context.fix_probability
        or context.check_enhancement or context.check_eternal
        or context.retrigger_joker_check
end

local celesta_clover_calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context, ...)
    if self.ability and self.ability.set == "Joker"
        and not is_query(context) and clover_suppresses(self) then
        return
    end
    return celesta_clover_calculate_joker_ref(self, context, ...)
end

local celesta_clover_eval_card_ref = eval_card
function eval_card(card, context)
    -- Only the scoring pass over played cards. A card held in hand arrives
    -- with cardarea == G.hand and one played outside the poker hand as the
    -- string 'unscored'; neither is a trigger to stop. extra_enhancement is
    -- excluded because quantum enhancements re-enter for the same trigger.
    if context and context.main_scoring and context.cardarea == G.play
        and not context.extra_enhancement and clover_suppresses(card) then
        return {}, {}
    end
    return celesta_clover_eval_card_ref(card, context)
end

SMODS.Blind {
    key = "clover",
    atlas = "blind_clover",
    pos = { x = 0, y = 0 },

    -- Standard boss payout and score requirement.
    dollars = 5,
    mult = 2,
    boss = { min = 1, max = 10 },
    boss_colour = HEX("4C9A2A"),
    discovered = true,

    -- Blind text goes through TWO hooks, and supplying only one leaves the
    -- other printing "nil" for every placeholder. loc_vars feeds the text on
    -- the Blind itself once it is in play; collection_loc_vars feeds the
    -- popup - the panel on the Blind select screen and the entry in the
    -- collection - which otherwise falls back to `self.vars`, and SMODS.Blind
    -- defaults that to an empty table. Steamodded's own take_ownership of The
    -- Wheel defines both for this reason.
    loc_vars = function(self)
        -- Shown through get_probability_vars so the number on the blind is the
        -- number actually rolled: with Oops! All 6s in play the text reads
        -- "2 in 2" and the blind is visibly doing nothing.
        local numerator, denominator = SMODS.get_probability_vars(
            nil, 1, CelestasMod.CLOVER_ODDS, CLOVER_SEED)
        return { vars = { numerator, denominator } }
    end,

    -- The collection is browsed with no run loaded, so the printed odds are
    -- the base ones rather than whatever a run would modify them to. The Wheel
    -- answers its own collection entry the same way.
    collection_loc_vars = function(self)
        return { vars = { 1, CelestasMod.CLOVER_ODDS } }
    end,
}

--------------------------------------------------------------------------------
-- The Greed - hands and discards cost money
--------------------------------------------------------------------------------
--
-- Discards go through vanilla's own machinery. The Golden Needle challenge
-- charges for a discard with `G.GAME.modifiers.discard_cost`, which
-- state_events.lua spends right where the discard is counted:
--     if G.GAME.modifiers.discard_cost then
--         ease_dollars(-G.GAME.modifiers.discard_cost)
--     end
-- Setting that for the duration is better than charging by hand: it is
-- deducted at exactly the moment vanilla deducts it, and it skips the discards
-- a Joker forces, which are not the player's to pay for.
--
-- There is no `hand_cost` to match it - Golden Needle only charges for
-- discards - so the hand is charged from press_play, which vanilla calls once
-- per played hand and returns from early when the Blind is disabled.

CelestasMod.GREED_COST = 2

--- Remembers whatever discard cost was already in force and installs ours.
--- A challenge can be charging for discards too, and this must not become the
--- way to cancel it. `false` records "there was none" - nil would read as
--- "nothing saved yet" and let a second call overwrite the real answer with
--- our own value.
local function greed_take_over()
    if G.GAME.celesta_greed_prior == nil then
        G.GAME.celesta_greed_prior = G.GAME.modifiers.discard_cost or false
    end
    G.GAME.modifiers.discard_cost = CelestasMod.GREED_COST
end

--- Puts back whatever was there before. Safe to call twice: a Blind that is
--- disabled and then defeated gets both hooks.
local function greed_hand_back()
    if G.GAME.celesta_greed_prior == nil then return end
    G.GAME.modifiers.discard_cost = G.GAME.celesta_greed_prior or nil
    G.GAME.celesta_greed_prior = nil
end

SMODS.Blind {
    key = "greed",
    atlas = "blind_greed",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    boss = { min = 1, max = 10 },
    boss_colour = HEX("C9A227"),
    discovered = true,

    -- Both hooks, for the reason spelled out on The Clover above.
    loc_vars = function(self)
        return { vars = { CelestasMod.GREED_COST } }
    end,

    collection_loc_vars = function(self)
        return { vars = { CelestasMod.GREED_COST } }
    end,

    set_blind = function(self)
        greed_take_over()
    end,

    disable = function(self)
        greed_hand_back()
    end,

    defeat = function(self)
        greed_hand_back()
    end,

    press_play = function(self)
        -- vanilla's Blind:press_play returns before this when the Blind is
        -- disabled, so there is nothing to check here.
        ease_dollars(-CelestasMod.GREED_COST)
    end,
}

--------------------------------------------------------------------------------
-- The Goat and The Frog - what a played card is made of
--------------------------------------------------------------------------------
--
-- Both act in press_play, which vanilla raises as the hand is played and
-- before evaluate_play scores it (the Hook discards from there) - so a card
-- scores as whatever it has been turned into, not as what it was. Vanilla
-- returns from Blind:press_play before reaching a Blind's own when the Blind
-- is disabled, so neither needs to check for that.
--
-- Every rewrite goes through CelestasMod.unjudged. set_ability ends by
-- re-judging the card against the Blind, and a card being rewritten mid-hand
-- is exactly the case The Pillar killed hands over; these two Blinds debuff
-- nothing themselves, but the habit is the point - the next one might.

--- The cards being played, at the moment press_play runs.
---
--- NOT G.play.cards. draw_card only QUEUES the move out of the hand - its
--- body sits inside an Event with a delay (common_events.lua) - so when a
--- Blind's press_play is called the cards are still in G.hand.highlighted and
--- G.play is empty. Reading G.play there is reading an empty table, which is
--- why The Frog removed nothing at all and The Goat shuffled nothing (which
--- looks exactly like working).
---
--- G.play is still preferred when it has anything in it, so a mod that has
--- already moved the hand is followed rather than second-guessed.
local function played_cards()
    local play = (G.play and G.play.cards) or {}
    if #play > 0 then return play end
    return (G.hand and G.hand.highlighted) or {}
end

local GOAT_SEED = "celesta_goat"

--- A shuffled copy, Fisher-Yates off the run's own stream so a seeded run
--- deals the same hand twice.
local function goat_shuffle(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    for i = #out, 2, -1 do
        local j = math.floor(pseudorandom(pseudoseed(GOAT_SEED)) * i) + 1
        if j > i then j = i end
        out[i], out[j] = out[j], out[i]
    end
    return out
end

SMODS.Blind {
    key = "goat",
    atlas = "blind_goat",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    -- From Ante 4 on: after Ante 3, not before it.
    boss = { min = 4, max = 10 },
    boss_colour = HEX("8A8A8A"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    press_play = function(self)
        local cards = played_cards()
        if #cards < 2 then return end

        -- What the hand is carrying, in hand order.
        local centers, editions = {}, {}
        for i, card in ipairs(cards) do
            centers[i] = (card.config and card.config.center) or G.P_CENTERS.c_base
            editions[i] = card.edition and card.edition.key or false
        end

        -- Shuffled independently: an edition and an enhancement that arrived
        -- on the same card have no reason to leave on the same one.
        centers = goat_shuffle(centers)
        editions = goat_shuffle(editions)

        for i, card in ipairs(cards) do
            CelestasMod.unjudged(card, function()
                card:set_ability(centers[i] or G.P_CENTERS.c_base, nil, true)
                -- set_edition(key, immediate, silent); false clears one.
                card:set_edition(editions[i] or nil, true, true)
            end)
        end
    end,
}

SMODS.Blind {
    key = "frog",
    atlas = "blind_frog",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    boss = { min = 4, max = 10 },
    boss_colour = HEX("C86FC9"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    press_play = function(self)
        local base = G.P_CENTERS and G.P_CENTERS.c_base
        if not base then return end
        for _, card in ipairs(played_cards()) do
            if card.config and card.config.center ~= base then
                CelestasMod.unjudged(card, function()
                    card:set_ability(base, nil, true)
                end)
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- The Star and The Heart - half of what the hand earned
--------------------------------------------------------------------------------
--
-- A Blind IS a scoring target: SMODS.get_card_areas('individual') puts
-- G.GAME.blind in the list whenever it has a chip sprite, and Blind:calculate
-- hands the context to the Blind's own definition (SMODS utils.lua:2170). So
-- these answer contexts the way a Joker does.
--
-- context.final_scoring_step is raised once, after every card and every Joker
-- has scored (state_events.lua:749) - which is what "after scoring" means.
-- Halving there takes half of the finished total rather than half of the base,
-- which is what The Flint does and is a different, much weaker, Blind.
--
-- Both check `disabled` themselves. Blind:calculate does not, unlike
-- press_play - so without it Adfree would hold the Blind shut and these two
-- would go on halving.
--
-- Half of an odd total is not a whole number, and Balatro's are. These used to
-- return a bare multiplier and leave the fraction where it fell, which put
-- 330.75 chips on a run whose readout said 331: the display rounds what it
-- prints and the score multiplies what is there, so every hand under either
-- Blind read higher than it landed.
--
-- Vanilla's own halving rounds instead. The Flint (blind.lua:537) is
--     math.max(math.floor(mult*0.5 + 0.5), 1),
--     math.max(math.floor(hand_chips*0.5 + 0.5), 0)
-- so the rounding and the floor under Mult are both copied from it rather than
-- chosen here. A hand that keeps no Mult at all scores nothing, which is a
-- different Blind from this one.

local HALF = 0.5

--- Half of `total`, rounded the way The Flint rounds, and never below `floor`.
local function halved(total, floor_at)
    return math.max(math.floor(total * HALF + 0.5), floor_at)
end

--- What to return to land the running total on `wanted`.
---
--- An addition rather than a multiplication, because a multiplier cannot pick
--- a number: SMODS applies `chips` and `mult` through the scoring parameter's
--- own modify(amount), so the difference is what puts the total exactly there.
---
--- Talisman's big numbers keep the multiplier. math.floor cannot be asked of
--- one - it is a table, not a number - and a fraction inside a total that large
--- is not what anybody is reading off the screen.
local function halve(total, floor_at, key, x_key)
    if type(total) ~= "number" then return { [x_key] = HALF } end
    return { [key] = halved(total, floor_at) - total }
end

SMODS.Blind {
    key = "star",
    atlas = "blind_star",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    -- min 2 keeps it away from Ante 1, which is the run's first Boss.
    boss = { min = 2, max = 10 },
    boss_colour = HEX("5B3FA8"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    calculate = function(self, blind, context)
        if blind.disabled then return end
        if context.final_scoring_step then
            return halve(hand_chips, 0, "chips", "x_chips")
        end
    end,
}

SMODS.Blind {
    key = "heart",
    atlas = "blind_heart",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    boss = { min = 2, max = 10 },
    boss_colour = HEX("D94F9A"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    calculate = function(self, blind, context)
        if blind.disabled then return end
        if context.final_scoring_step then
            return halve(mult, 1, "mult", "x_mult")
        end
    end,
}

--------------------------------------------------------------------------------
-- The Robot - a Seal is a liability
--------------------------------------------------------------------------------
--
-- recalc_debuff rather than debuff_card: Steamodded prefers it and warns about
-- the other (blind.lua:678), and it is asked of every playing card and every
-- Joker as the Blind is set and again whenever a card changes
-- (SMODS.recalc_debuff). The answer IS the whole state - returning false
-- un-debuffs - so a Joker, which has no seal, simply answers no.
--
-- `card.seal` is the field every seal lives in, this mod's five included:
-- SMODS.Seal writes the prefixed key there, so asking whether there is one at
-- all catches them without naming any.

SMODS.Blind {
    key = "robot",
    atlas = "blind_robot",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    -- From Ante 4 on: after Ante 3, not before it.
    boss = { min = 4, max = 10 },
    boss_colour = HEX("305DFF"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    recalc_debuff = function(self, card, from_blind)
        return card.seal ~= nil
    end,
}

--------------------------------------------------------------------------------
-- The Brick - the hand shrinks as it is spent
--------------------------------------------------------------------------------
--
-- The Manacle takes one card off the hand for the whole Blind; this takes one
-- more for every hand played, so by the fourth hand there are three fewer
-- cards to play it with.
--
-- What has been taken is written down rather than recomputed, and given back
-- in full when the Blind ends. The Manacle's own shape - change_size(-1) at
-- set_blind, change_size(1) at defeat and at disable - with a running total in
-- place of its one card, because a Blind disabled by Chicot half way through
-- has to hand back however many it had taken by then.
--
-- On G.GAME so it is saved with the run, beside the card limit itself.

local BRICK_TAKEN = "celesta_brick_taken"

--- Take one more card off the hand.
local function brick_take()
    if not (G.GAME and G.hand) then return end
    G.GAME[BRICK_TAKEN] = (G.GAME[BRICK_TAKEN] or 0) + 1
    G.hand:change_size(-1)
end

--- Give back everything this Blind took. Idempotent: what is owed is
--- remembered rather than worked out, so defeat and disable cannot each hand
--- the same cards back.
local function brick_release()
    if not G.GAME then return end
    local taken = G.GAME[BRICK_TAKEN] or 0
    G.GAME[BRICK_TAKEN] = nil
    if taken > 0 and G.hand then G.hand:change_size(taken) end
end

SMODS.Blind {
    key = "brick",
    atlas = "blind_brick",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    -- From Ante 2 on: after Ante 1.
    boss = { min = 2, max = 10 },
    boss_colour = HEX("F49B45"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    set_blind = function(self)
        -- Nothing taken yet, and nothing owed from a Blind before this one.
        brick_release()
    end,

    -- press_play is the hand being played, and it runs before the draw that
    -- follows - so the card taken here is a card not dealt back.
    press_play = function(self)
        brick_take()
    end,

    defeat = function(self) brick_release() end,
    disable = function(self) brick_release() end,
}

--------------------------------------------------------------------------------
-- The Wyrm - nothing in the consumable tray works
--------------------------------------------------------------------------------
--
-- Consumables are the one thing Blind:set_blind does NOT walk: it debuffs
-- every playing card and every Joker (blind.lua:217-224) and never looks at
-- the tray. So this Blind debuffs them itself, from a pass that works the
-- answer out from the world rather than from whoever called - which also
-- covers a Tarot bought during the Blind, a run loaded mid-Blind, and the
-- Blind being switched off by Chicot.
--
-- And debuffing a consumable had to be taught to mean something: vanilla's
-- Card:can_use_consumeable never looks at `debuff` (card.lua:1763), so a
-- greyed-out Tarot was still usable. That refusal is written as a general
-- rule rather than as this Blind's own - a debuffed card does nothing is what
-- debuffed MEANS, and anything else that debuffs one should get the same.

local WYRM_KEY = "bl_" .. SMODS.current_mod.prefix .. "_wyrm"

--- True while The Wyrm is the Blind being played.
--- Read fresh each time rather than latched, as The Clover's is: a Blind can
--- be disabled mid-round, and a latched flag would keep suppressing after it.
local function wyrm_active()
    local blind = G.GAME and G.GAME.blind
    if not (blind and blind.config and blind.config.blind) then return false end
    if blind.disabled then return false end
    return blind.config.blind.key == WYRM_KEY
end

--- Marks the consumables this Blind debuffed, so it only ever un-debuffs its
--- own: one already debuffed by something else is left alone.
local WYRM_MARK = "celesta_wyrm_debuffed"

--- Brings the tray in line with whether The Wyrm is out.
local function wyrm_sync()
    local tray = G.consumeables and G.consumeables.cards
    if not tray then return end
    local wanted = wyrm_active()
    for _, held in ipairs(tray) do
        if wanted then
            if not held.debuff then
                held[WYRM_MARK] = true
                held:set_debuff(true)
            end
        elseif held[WYRM_MARK] then
            held[WYRM_MARK] = nil
            held:set_debuff(false)
        end
    end
end

CelestasMod.wyrm_sync = wyrm_sync

-- Asked every frame, and answers with a single comparison in every round this
-- Blind is not being played. The tray is a handful of cards, so the walk when
-- it IS costs nothing worth measuring - and it is what makes a consumable that
-- arrives mid-Blind arrive debuffed.
local celesta_wyrm_update_ref = Game.update
function Game:update(dt)
    celesta_wyrm_update_ref(self, dt)
    wyrm_sync()
end

-- A debuffed consumable cannot be used. Vanilla never asks, so this is the
-- only thing standing between a greyed-out Tarot and a working one.
local celesta_wyrm_can_use_ref = Card.can_use_consumeable
function Card:can_use_consumeable(any_state, skip_check)
    if self.debuff and self.ability and self.ability.consumeable then
        return false
    end
    return celesta_wyrm_can_use_ref(self, any_state, skip_check)
end

SMODS.Blind {
    key = "wyrm",
    atlas = "blind_wyrm",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    -- From Ante 2 on: after Ante 1.
    boss = { min = 2, max = 10 },
    boss_colour = HEX("013140"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    -- The pass above does the work at every other moment; these three are the
    -- ones where waiting a frame would be visible.
    set_blind = function(self) wyrm_sync() end,
    defeat = function(self) wyrm_sync() end,
    disable = function(self) wyrm_sync() end,
}

--------------------------------------------------------------------------------
-- The Horn - the row is nailed down
--------------------------------------------------------------------------------
--
-- A Joker is reordered by dragging it, and a Moveable is only draggable while
-- its own states.drag.can is true (engine/moveable.lua:218, and the controller
-- checks the same flag before it starts one). So locking the row is that flag,
-- off, on every Joker in it.
--
-- Clicking is a separate state, and deliberately left alone: highlighting a
-- Joker is how a Bind merge and a Stamp are aimed, and neither of those moves
-- anything. This Blind is about position.
--
-- The same shape as The Wyrm's pass, and for the same reasons: worked out from
-- the world each frame, so a Joker bought mid-Blind arrives locked, and only
-- ever unlocking what it locked.

local HORN_KEY = "bl_" .. SMODS.current_mod.prefix .. "_horn"
local HORN_MARK = "celesta_horn_locked"

local function horn_active()
    local blind = G.GAME and G.GAME.blind
    if not (blind and blind.config and blind.config.blind) then return false end
    if blind.disabled then return false end
    return blind.config.blind.key == HORN_KEY
end

local function horn_sync()
    local row = G.jokers and G.jokers.cards
    if not row then return end
    local wanted = horn_active()
    for _, held in ipairs(row) do
        local drag = held.states and held.states.drag
        if drag then
            if wanted then
                if drag.can then
                    held[HORN_MARK] = true
                    drag.can = false
                end
            elseif held[HORN_MARK] then
                held[HORN_MARK] = nil
                drag.can = true
            end
        end
    end
end

CelestasMod.horn_sync = horn_sync

local celesta_horn_update_ref = Game.update
function Game:update(dt)
    celesta_horn_update_ref(self, dt)
    horn_sync()
end

SMODS.Blind {
    key = "horn",
    atlas = "blind_horn",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    -- From Ante 2 on: after Ante 1.
    boss = { min = 2, max = 10 },
    boss_colour = HEX("BAA566"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    -- The pass above covers every other moment; these are the three where
    -- waiting a frame would be visible.
    set_blind = function(self) horn_sync() end,
    defeat = function(self) horn_sync() end,
    disable = function(self) horn_sync() end,
}

--------------------------------------------------------------------------------
-- The Gem - an edition is a liability
--------------------------------------------------------------------------------
--
-- Every edition, Negative included: `card.edition` is the one field any of
-- them lives in, so asking whether there is one at all catches Foil, Holo,
-- Polychrome, Negative and anything another mod adds without naming any.
--
-- Cards AND Jokers, which needs nothing extra: Blind:set_blind walks both and
-- asks recalc_debuff of each (blind.lua:217-224).
--
-- Frozen is not an edition and is not caught here. That is deliberate - this
-- mod keeps it off the edition field precisely so it can sit on top of one
-- (editions/frozen.lua), and a Blind that reads editions should read editions.

SMODS.Blind {
    key = "gem",
    atlas = "blind_gem",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    -- From Ante 4 on: after Ante 3, not before it.
    boss = { min = 4, max = 10 },
    boss_colour = HEX("960672"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    recalc_debuff = function(self, card, from_blind)
        return card.edition ~= nil
    end,
}

--------------------------------------------------------------------------------
-- The Flower - the ends of the row wither
--------------------------------------------------------------------------------
--
-- The leftmost and rightmost Jokers, which with one Joker in the row is that
-- one Joker twice over - and it is debuffed, because it is both.
--
-- The position is not a property of the card, so unlike every other
-- recalc_debuff Blind this one has to be asked again when the ROW changes and
-- the cards do not. Steamodded re-judges a card when that card changes; it has
-- no reason to re-judge a card because its neighbour was sold. So the ends are
-- watched, and every Joker is re-judged when they move.
--
-- Which makes reordering the play: the row can still be rearranged under this
-- Blind, and moving the Joker that matters out of the ends is how it is
-- beaten. The Horn is the one that takes that away.

local FLOWER_KEY = "bl_" .. SMODS.current_mod.prefix .. "_flower"

local function flower_active()
    local blind = G.GAME and G.GAME.blind
    if not (blind and blind.config and blind.config.blind) then return false end
    if blind.disabled then return false end
    return blind.config.blind.key == FLOWER_KEY
end

--- True when `card` is at either end of the Joker row.
local function flower_at_an_end(card)
    local row = (G.jokers and G.jokers.cards) or {}
    if #row == 0 then return false end
    return card == row[1] or card == row[#row]
end

--- What the ends are now, as a string that changes when either does.
local function flower_ends()
    local row = (G.jokers and G.jokers.cards) or {}
    if #row == 0 then return "-" end
    return tostring(row[1]) .. "/" .. tostring(row[#row])
end

local flower_seen = nil

--- Re-judges the row when its ends move. Every Joker, not just the ends: the
--- card that WAS an end has to be let go at the same moment the new one is
--- taken, and by then it is not an end to find.
local function flower_sync()
    if not flower_active() then flower_seen = nil return end
    local ends = flower_ends()
    if ends == flower_seen then return end
    flower_seen = ends
    local blind = G.GAME and G.GAME.blind
    if not blind then return end
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        blind:debuff_card(held, true)
    end
end

CelestasMod.flower_sync = flower_sync

local celesta_flower_update_ref = Game.update
function Game:update(dt)
    celesta_flower_update_ref(self, dt)
    flower_sync()
end

SMODS.Blind {
    key = "flower",
    atlas = "blind_flower",
    pos = { x = 0, y = 0 },

    dollars = 5,
    mult = 2,
    -- From Ante 2 on: after Ante 1.
    boss = { min = 2, max = 10 },
    boss_colour = HEX("59002D"),
    discovered = true,

    loc_vars = function(self) return { vars = {} } end,
    collection_loc_vars = function(self) return { vars = {} } end,

    recalc_debuff = function(self, card, from_blind)
        -- Jokers only. A playing card is never in the row, so it answers no
        -- and is left alone.
        return flower_at_an_end(card)
    end,
}

--------------------------------------------------------------------------------
-- Boss Blinds added to a run already in progress
--------------------------------------------------------------------------------
--
-- G.GAME.bosses_used is built once, when a run starts, from the Blinds that
-- exist at that moment. get_new_boss marks every eligible Blind with `true`,
-- then replaces those marks with use counts by walking bosses_used:
--
--     for k, v in pairs(G.GAME.bosses_used) do
--         if eligible_bosses[k] then eligible_bosses[k] = v ... end
--     end
--     for k, v in pairs(eligible_bosses) do
--         if eligible_bosses[k] > min_use then eligible_bosses[k] = nil end
--     end
--
-- A Blind the run has never heard of is not in bosses_used, so its mark stays
-- `true` and the second loop compares a boolean with a number. That is a crash
-- on picking a Blind, in any run that was started before the Blind was added -
-- which is every run a player already has going when this mod updates.
--
-- Cryptid repairs the same thing and says so in a comment, but does it AFTER
-- calling through, so the call it is protecting has already thrown. This runs
-- before. Load order puts this mod ahead of Cryptid, so this wrapper is the
-- one Cryptid captured and it goes first either way.
--
-- Zero is what the count would have been had the Blind existed at run start.

local celesta_boss_backfill_ref = get_new_boss
function get_new_boss(...)
    if G.GAME and G.P_BLINDS then
        -- Created rather than skipped when it is missing entirely. An empty
        -- bosses_used is the same crash as a partial one: with no counts to
        -- replace them, EVERY mark stays a boolean and the comparison throws
        -- on the first Blind it reaches.
        if type(G.GAME.bosses_used) ~= "table" then G.GAME.bosses_used = {} end
        local added = 0
        for key, center in pairs(G.P_BLINDS) do
            if center.boss and G.GAME.bosses_used[key] == nil then
                G.GAME.bosses_used[key] = 0
                added = added + 1
            end
        end
        if added > 0 then
            CelestasMod.warn_once("boss_backfill",
                ("Filled in bosses_used for %d Blind(s) this run had not seen")
                    :format(added))
        end
    end
    return celesta_boss_backfill_ref(...)
end
