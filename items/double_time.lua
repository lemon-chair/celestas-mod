--------------------------------------------------------------------------------
-- Double-Time - everything triggers twice
--------------------------------------------------------------------------------
--
-- Jokers, cards, vouchers and consumables each go off a second time, wherever the
-- game gives something a way to. Four separate mechanisms, because the four do not
-- trigger the same way:
--
--   JOKERS (and the consumables and vouchers that have effects of their own, which
--   Steamodded evaluates alongside them) are retriggered by asking
--   SMODS.calculate_retriggers, the one place every "does this go again?" answer is
--   gathered. It is asked once per Joker that has just done something, so this
--   adds one retrigger to its answer - the same entry a Joker like Ray adds, so the
--   rest of the game treats it as one and shows "Again!" on the card. Asked about
--   anything that is not a card (a deck, a Blind, this challenge) it adds nothing.
--
--   PLAYING CARDS are retriggered by the challenge's own `calculate`: Steamodded
--   asks the challenge about every card being scored or held in hand, the way it asks
--   a deck, and a repetition is how a card goes again. Cards that are in the played
--   hand but do not score, and cards in the deck or discard, are not asked.
--
--   VOUCHERS are applied twice. A voucher's effect is the work of Card:apply_to_run
--   - a hand more, a slot more, an Ante less - and redeeming one runs that once, so
--   it is run again. The price is paid once: that is redeem's, not apply_to_run's.
--   Steamodded files a copy of the voucher in the Vouchers area every time
--   apply_to_run is called; the second call's copy is held back so it is not there
--   twice. Where a voucher SETS a value rather than adding to it (a discount, a
--   rate) the second pass is the same number again, which is as twice as it gets.
--
--   CONSUMABLES are used twice. The second use is queued to run straight after the
--   first one's own events, still inside the lock the first use took out, and with
--   the cards the first use was aimed at selected again: a use lets go of its
--   selection when it ends, and the second one would otherwise be aimed at nothing.
--   A card the first use destroyed is not selected again, and a second use that
--   could no longer be made - nothing left to aim at, no room to create into - is
--   not made. It is told it is a copy (`copier`), which is how the game spares a use
--   from being counted twice in the run's tally.

local DOUBLE_TIME_KEY = "c_" .. SMODS.current_mod.prefix .. "_double_time"

--- Whether a Double-Time run is the one being played.
function CelestasMod.double_time_active()
    return (G.GAME and G.GAME.challenge == DOUBLE_TIME_KEY) and true or false
end

--------------------------------------------------------------------------------
-- Jokers
--------------------------------------------------------------------------------

local celesta_double_time_retriggers_ref = SMODS.calculate_retriggers
if type(celesta_double_time_retriggers_ref) == "function" then
    function SMODS.calculate_retriggers(card, context, ...)
        local retriggers = celesta_double_time_retriggers_ref(card, context, ...)

        -- A card in one of the Joker areas only: a deck, a Blind or the challenge is
        -- asked this too, and has no `ability` to be told apart by.
        if CelestasMod.double_time_active()
            and type(card) == "table" and card.ability and card.area
            and SMODS.optional_features and SMODS.optional_features.retrigger_joker
            and type(SMODS.insert_repetitions) == "function" then
            SMODS.insert_repetitions(retriggers, {
                repetitions = 1,
                retrigger_juice = card,
            }, card, "joker_retrigger")
        end

        return retriggers
    end
end

--------------------------------------------------------------------------------
-- Vouchers
--------------------------------------------------------------------------------

local celesta_double_time_apply_ref = Card.apply_to_run
function Card:apply_to_run(center, ...)
    celesta_double_time_apply_ref(self, center, ...)

    if not CelestasMod.double_time_active() then return end

    -- The copy Steamodded files in the Vouchers area is held back for the second
    -- pass, and taken out of the game once the events that pass queued have run.
    local held = nil
    local area = G.vouchers
    local own = area and rawget(area, "emplace")
    if area then
        area.emplace = function(_, card) held = held or card end
    end
    local ok, err = pcall(celesta_double_time_apply_ref, self, center, ...)
    if area then area.emplace = own end

    if held and type(held.remove) == "function" then
        G.E_MANAGER:add_event(Event({
            func = function()
                held:remove()
                return true
            end,
        }))
    end
    if not ok then error(err, 0) end
end

--------------------------------------------------------------------------------
-- Consumables
--------------------------------------------------------------------------------

--- The cards selected in each card area right now, as {area, card} pairs.
local function selections()
    local out = {}
    for _, area in ipairs((G.I and G.I.CARDAREA) or {}) do
        for _, card in ipairs(area.highlighted or {}) do
            out[#out + 1] = { area = area, card = card }
        end
    end
    return out
end

--- Selects again whatever the first use let go of and the game still has.
local function reselect(saved)
    for _, s in ipairs(saved) do
        local card, area = s.card, s.area
        local selected = false
        for _, h in ipairs(area.highlighted or {}) do
            if h == card then selected = true break end
        end
        if not selected and not card.removed and not card.getting_sliced
            and card.area == area then
            area:add_to_highlighted(card, true)
        end
    end
end

--- Whether the second use can be made: asked in the state the first one started in,
--- since a use moves the game on to PLAY_TAROT and what a Tarot may be used on is
--- decided by the state it was picked up in.
local function can_repeat(card)
    if not card.ability or not card.ability.consumeable then return false end
    local state = G.STATE
    if G.TAROT_INTERRUPT then G.STATE = G.TAROT_INTERRUPT end
    local ok, can = pcall(card.can_use_consumeable, card, true, true)
    G.STATE = state
    return ok and can and true or false
end

local celesta_double_time_use_ref = Card.use_consumeable
function Card:use_consumeable(area, copier)
    local saved = CelestasMod.double_time_active() and not self.debuff and selections() or nil

    local ret = celesta_double_time_use_ref(self, area, copier)
    if not saved then return ret end

    local queue = G.E_MANAGER.queues and G.E_MANAGER.queues.base
    local this
    this = Event({
        func = function()
            reselect(saved)
            if not can_repeat(self) then return true end

            -- Whatever the second use queues goes in right behind this event, ahead
            -- of the events the caller queued after the first use (the card's
            -- dissolve, the game's state put back, the lock let go): the second
            -- use belongs inside the first one's lock, not after it.
            local manager = G.E_MANAGER
            local held, own = {}, rawget(manager, "add_event")
            local add = manager.add_event
            manager.add_event = function(m, event, queue_name, front)
                if (queue_name == nil or queue_name == "base") and not front then
                    held[#held + 1] = event
                    return
                end
                return add(m, event, queue_name, front)
            end
            local ok, err = pcall(celesta_double_time_use_ref, self, area, copier or self)
            manager.add_event = own

            local at = #queue
            for i, event in ipairs(queue) do
                if event == this then at = i break end
            end
            for n, event in ipairs(held) do table.insert(queue, at + n, event) end

            if not ok then error(err, 0) end
            return true
        end,
    })
    if queue then G.E_MANAGER:add_event(this) end

    return ret
end

--------------------------------------------------------------------------------
-- The challenge
--------------------------------------------------------------------------------

SMODS.Challenge {
    key = "double_time",

    -- Playing cards. Steamodded evaluates the challenge as it does a deck, for every
    -- context: a repetition asked of a card being scored (G.play) or held in hand
    -- (G.hand) is a card going again. The challenge is not itself retriggered - the
    -- retrigger wrap above only answers for cards.
    calculate = function(self, context)
        if context.repetition and context.other_card
            and (context.cardarea == G.play or context.cardarea == G.hand) then
            return {
                repetitions = 1,
                card = context.other_card,
            }
        end
    end,

    rules = {
        custom = {
            { id = "celesta_double_time" },
        },
        modifiers = {},
    },
}
