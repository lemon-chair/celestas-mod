--- FROZEN
---
--- Frozen is deliberately NOT an SMODS.Edition. A card carries exactly one
--- `edition` table, so registering it as one would replace whatever edition
--- the joker already had - and Frozen is meant to sit on top of Foil, Holo,
--- Negative or anything else. It is stored as its own field instead and drawn
--- as an overlay, which is what lets it coexist.
---
--- State lives on card.ability so it is saved with the run:
---     card.ability.celesta_frozen = <rounds remaining>
---
--- Behaviour, all installed as hooks below:
---   * a frozen joker still works, but each evaluation has a 1 in 2 chance to
---     do nothing (Vulpixie cancels that)
---   * rental and perishable are paused - no rent charged, no timer ticking
---   * it thaws after 3 end-of-round passes and is removed

CelestasMod.FROZEN_ROUNDS = 3
CelestasMod.FROZEN_FAIL_ODDS = 2

local FROZEN_ATLAS = SMODS.current_mod.prefix .. "_frozen"

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function CelestasMod.is_frozen(card)
    return card and card.ability and (card.ability.celesta_frozen or 0) > 0
end

function CelestasMod.freeze(card, rounds)
    if not card or not card.ability then return false end
    if CelestasMod.is_frozen(card) then return false end
    card.ability.celesta_frozen = rounds or CelestasMod.FROZEN_ROUNDS
    card:juice_up(0.4, 0.5)
    return true
end

--- Thaw a card, running whatever should happen as it melts.
function CelestasMod.thaw(card)
    if not card or not card.ability then return end
    card.ability.celesta_frozen = nil
    -- Smug Alana strips a sticker as the ice comes off; kept here rather than
    -- in the joker so the melt has one definition wherever it is triggered.
    if next(SMODS.find_card("j_celesta_smugalana")) then
        CelestasMod.strip_random_sticker(card)
    end
end

--- Remove one random sticker from a card, if it has any.
function CelestasMod.strip_random_sticker(card)
    if not card or not card.ability then return end
    local present = {}
    for key, _ in pairs(SMODS.Stickers or {}) do
        if card.ability[key] then present[#present + 1] = key end
    end
    if #present == 0 then return end

    local key = pseudorandom_element(present, pseudoseed("celesta_smugalana"))
    card.ability[key] = nil
    -- perish_tally is perishable's counter and would otherwise linger and
    -- re-destroy the joker later.
    if key == "perishable" then card.ability.perish_tally = nil end
    card:juice_up(0.3, 0.4)
    return key
end

--------------------------------------------------------------------------------
-- Drawing: an overlay on top of whatever edition the card already has
--------------------------------------------------------------------------------

local frozen_sprite

local card_draw_ref = Card.draw
function Card:draw(layer)
    card_draw_ref(self, layer)

    if not CelestasMod.is_frozen(self) then return end
    if self.facing == "back" or layer == "shadow" then return end

    local atlas = G.ASSET_ATLAS[FROZEN_ATLAS]
    if not atlas then return end
    if not frozen_sprite then
        frozen_sprite = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, { x = 0, y = 0 })
    end
    frozen_sprite.role.draw_major = self
    frozen_sprite:draw_shader("dissolve", nil, nil, nil, self.children.center)
end

--------------------------------------------------------------------------------
-- A frozen joker sometimes does nothing
--------------------------------------------------------------------------------

-- Cards currently resolving a freeze roll. Weak keys so a destroyed joker is
-- not held alive by this table.
--
-- Rolling is not free. SMODS.get_probability_vars fires TWO full
-- calculate_context passes - mod_probability and fix_probability - and each
-- re-evaluates every joker, re-entering this hook on the same card. Cryptid
-- additionally wraps calculate_joker and calls eval_card again whenever the
-- inner chain returns nothing, which is exactly what a failed freeze roll
-- does. Together those nested until the stack overflowed, first seen when
-- AmaLee froze a Hanging Chad.
--
-- Exempting query contexts from FAILING was not enough: they still re-enter.
-- This makes the roll itself non-reentrant per card, so a nested evaluation
-- passes straight through to the real calculate instead of rolling again.
local FROZEN_FAIL_SEED = "celesta_frozen_fail"
local rolling = setmetatable({}, { __mode = "k" })

-- Last event a card announced a failure on, so "Failed!" shows once.
local announced = setmetatable({}, { __mode = "k" })

-- The failure roll for the current play or discard, cached per card.
local decision = setmetatable({}, { __mode = "k" })

--- Identifies the current play or discard.
--- hands_left and discards_left are both decremented before jokers are
--- evaluated, so this is stable for the whole of one event and changes the
--- moment the next one begins.
local function event_id()
    local round = G.GAME and G.GAME.current_round
    if not round then return "?" end
    return table.concat({
        tostring(G.GAME.round),
        tostring(round.hands_left),
        tostring(round.discards_left),
    }, "/")
end

--- Rolls once per card per play or discard, and remembers the answer.
---
--- A joker is evaluated against a dozen contexts in a single hand - before,
--- one 'individual' per scored card, joker_main, after. Rolling each of them
--- separately meant one joker could fail some and pass others in the same
--- hand, so the player saw "Failed!" over a joker that had visibly just
--- worked. One decision per event is also the natural reading of "1 in 2
--- chance to fail": the joker is out for this hand, not for a coin-flip on
--- each internal lookup.
local function frozen_fails(card)
    local id = event_id()
    local cached = decision[card]
    if cached and cached.id == id then return cached.failed end

    -- Plain pseudorandom, NOT SMODS.pseudorandom_probability.
    --
    -- That helper runs two full calculate_context passes per call
    -- (mod_probability and fix_probability), each re-evaluating every joker.
    -- Inside a copier chain - Blueprints copying Blueprints, Brainstorm,
    -- Hanging Chad retriggers - the cost multiplies with the chain and the
    -- game locks up mid-score. Talisman measured 88k calculations against a
    -- 4k baseline.
    --
    -- The trade is that probability modifiers (Oops! All 6s, Dejavudea, The
    -- Clover) no longer reach this roll. For a penalty chance that is
    -- arguably the right behaviour anyway.
    rolling[card] = true
    local ok, roll = pcall(pseudorandom, pseudoseed(FROZEN_FAIL_SEED))
    rolling[card] = nil
    -- A roll that errored is treated as a pass: a frozen joker working too
    -- often is far better than one that cannot run.
    local failed = ok and roll >= 1 / CelestasMod.FROZEN_FAIL_ODDS or false
    decision[card] = { id = id, failed = failed }
    return failed
end

local calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context)
    if CelestasMod.is_frozen(self) and self.ability.set == "Joker"
        and not rolling[self] then
        -- Vulpixie cancels the failure outright rather than improving the odds.
        if not next(SMODS.find_card("j_celesta_vulpixie")) then
            -- Getter contexts ask a question rather than producing an effect;
            -- failing those would corrupt display and probability lookups
            -- rather than "fail to trigger".
            local is_query = context.mod_probability or context.fix_probability
                or context.check_enhancement or context.check_eternal
                or context.retrigger_joker_check
            if not is_query and frozen_fails(self) then
                -- Announce only on the main scoring pass. joker_main reaches
                -- every joker exactly once per hand, which makes it the one
                -- honest place to say the joker is out for this hand.
                --
                -- Every other context is a poor place to speak. Discarding
                -- sends context.discard to jokers that have nothing to do
                -- with discards, and announcing there reads as a failure the
                -- player had no stake in. A copy carries context.blueprint
                -- and stays silent too - the popup belongs on the frozen
                -- joker, not on the Blueprint pointing at it.
                --
                -- Told through card_eval_status_text rather than a returned
                -- effect so the return stays nil: anything else reads
                -- downstream as "this joker did something".
                local id = event_id()
                if context.joker_main and not context.blueprint
                    and announced[self] ~= id then
                    announced[self] = id
                    card_eval_status_text(self, "extra", nil, nil, nil, {
                        message = localize("celesta_failed"),
                        colour = G.C.BLUE,
                    })
                end
                return
            end
        end
    end
    return calculate_joker_ref(self, context)
end

--------------------------------------------------------------------------------
-- Rental and perishable are paused while frozen
--------------------------------------------------------------------------------

local PAUSED_STICKERS = { rental = true, perishable = true }

local calculate_sticker_ref = Card.calculate_sticker
function Card:calculate_sticker(context, key)
    -- Both stickers do their work from here - rental charges its rent and
    -- perishable ticks its counter - so skipping the call is the whole pause.
    if PAUSED_STICKERS[key] and CelestasMod.is_frozen(self) then return end
    return calculate_sticker_ref(self, context, key)
end

--------------------------------------------------------------------------------
-- Melting
--------------------------------------------------------------------------------

--- Count down every frozen joker and thaw the ones that are done. Called once
--- per round from the Arena's update rather than from a joker, so freezing
--- works even with no CelestasMod joker in play.
function CelestasMod.tick_frozen()
    if not G.jokers or not G.jokers.cards then return end
    for _, joker in ipairs(G.jokers.cards) do
        if CelestasMod.is_frozen(joker) then
            joker.ability.celesta_frozen = joker.ability.celesta_frozen - 1
            if joker.ability.celesta_frozen <= 0 then
                CelestasMod.thaw(joker)
                G.E_MANAGER:add_event(Event {
                    func = function()
                        SMODS.calculate_effect({
                            message = localize("celesta_melted"),
                            colour = G.C.BLUE,
                        }, joker)
                        return true
                    end
                })
            end
        end
    end
end

--- Drive the countdown once per round. G.GAME.round increments in
--- select_blind, so seeing it change means a round has fully ended - the same
--- signal the Arena uses to expire itself. Hung off Game.update rather than a
--- joker's end_of_round so freezing still expires when no CelestasMod joker
--- is in play.
local last_round
local game_update_ref = Game.update
function Game:update(dt)
    game_update_ref(self, dt)
    if not G.GAME or not G.GAME.round then return end
    if last_round == nil then last_round = G.GAME.round end
    if G.GAME.round ~= last_round then
        last_round = G.GAME.round
        CelestasMod.tick_frozen()
    end
end
