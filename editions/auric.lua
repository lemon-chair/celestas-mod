--- AURIC
---
--- An edition only Magnetar hands out, in place of a card wearing out (wear/tattered.lua). It
--- replaces whatever edition the card had, which is how an edition works: a card carries one.
---
--- What it does:
---   * the card is retriggered 3 times when it scores
---   * every roll a Lucky Card makes - the 1 in 5 for Mult and the 1 in 15 for money - is won
---   * a card that can break - Glass, Gash, Driftwood - does not
---
--- It has no shader. Drawn as an overlay over the card, the way a worn card's tears are, since its
--- art is a pattern of its own rather than a recolouring of the card under it.

local PREFIX = SMODS.current_mod.prefix

--- How many more times the card scores.
CelestasMod.AURIC_RETRIGGERS = 3

--- The key the edition is found under, for the Joker that tooltips it and the wear that gives it.
CelestasMod.AURIC_KEY = "e_" .. PREFIX .. "_auric"

local AURIC_ATLAS = PREFIX .. "_auric"

SMODS.Edition {
    key = "auric",
    shader = false,
    -- Never rolled for: no shop, no pack, no Wheel of Fortune. Magnetar is the only way in.
    in_shop = false, weight = 0, extra_cost = 0,
    badge_colour = HEX("D9A93C"),

    loc_vars = function(self, info_queue, card)
        return { vars = { CelestasMod.AURIC_RETRIGGERS } }
    end,

    calculate = function(self, card, context)
        -- Scored, not held in hand: a Red Seal's retrigger, which this is three of.
        if context.repetition and context.cardarea == G.play then
            return {
                message = localize("k_again_ex"),
                repetitions = CelestasMod.AURIC_RETRIGGERS,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Drawn over the card
--------------------------------------------------------------------------------

local auric_sprite

local celesta_auric_draw_ref = Card.draw
function Card:draw(layer)
    celesta_auric_draw_ref(self, layer)

    if not (self.edition and self.edition.key == CelestasMod.AURIC_KEY) then return end
    if self.facing == "back" or layer == "shadow" then return end

    -- Built on first use: the atlases do not exist yet when this file runs.
    if not auric_sprite then
        local atlas = G.ASSET_ATLAS[AURIC_ATLAS]
        if not atlas then return end
        auric_sprite = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, { x = 0, y = 0 })
    end
    auric_sprite.role.draw_major = self
    auric_sprite:draw_shader("dissolve", nil, nil, nil, self.children.center)
end

--------------------------------------------------------------------------------
-- The rolls
--------------------------------------------------------------------------------
--
-- Answered where a roll is worked out, SMODS.get_probability_vars, rather than by the edition's own
-- `calculate`. Steamodded does not ask an object that is in the middle of raising a probability question
-- (SMODS.check_looping_context), and a card's own Lucky and Glass rolls are made from inside its own
-- evaluation - so asked through `calculate`, the edition would never hear its own card's.
--
-- Installed when a run starts rather than here, for the reason LucyPyre's and Dooby's are: it has to
-- be the LAST word, outside every other mod's wrapper, and the Hedron Stake's (which doubles every
-- denominator) loads after this file. The identity guard stops a second run from stacking another
-- copy on the first.
--
-- A guarantee is a numerator as big as the denominator, and a refusal is a numerator of nothing.
-- Not asked for a roll made without modifiers (`no_mod`): that is the Soul Stake's, and the Celestial
-- Stake's, which say they are what they say.

local GUARANTEED = { lucky_mult = true, lucky_money = true }
local REFUSED = { glass = true, celesta_driftwood = true }

local function is_auric(card)
    return type(card) == "table" and type(card.edition) == "table"
        and card.edition.key == CelestasMod.AURIC_KEY
end

local installed = setmetatable({}, { __mode = "k" })

function CelestasMod.install_auric_hook()
    local current = SMODS.get_probability_vars
    if installed[current] then return end

    local function wrapper(trigger_obj, base_numerator, base_denominator, identifier, from_roll, no_mod, ...)
        local numerator, denominator = current(trigger_obj, base_numerator, base_denominator, identifier,
                                               from_roll, no_mod, ...)
        if no_mod or not is_auric(trigger_obj) then return numerator, denominator end

        if GUARANTEED[identifier] then return denominator, denominator end
        if REFUSED[identifier] or identifier == CelestasMod.GASH_BREAK_ID then return 0, denominator end
        return numerator, denominator
    end

    installed[wrapper] = true
    SMODS.get_probability_vars = wrapper
end

local celesta_auric_start_run_ref = Game.start_run
function Game:start_run(...)
    CelestasMod.install_auric_hook()
    return celesta_auric_start_run_ref(self, ...)
end
