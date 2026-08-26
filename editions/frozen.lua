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

local calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context)
    if CelestasMod.is_frozen(self) and self.ability.set == "Joker" then
        -- Vulpixie cancels the failure outright rather than improving the odds.
        if not next(SMODS.find_card("j_celesta_vulpixie")) then
            -- Getter contexts ask a question rather than producing an effect;
            -- failing those would corrupt display and probability lookups
            -- rather than "fail to trigger".
            local is_query = context.mod_probability or context.fix_probability
                or context.check_enhancement or context.check_eternal
                or context.retrigger_joker_check
            if not is_query and not SMODS.pseudorandom_probability(
                    self, "celesta_frozen_fail", 1, CelestasMod.FROZEN_FAIL_ODDS,
                    "celesta_frozen_fail") then
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
