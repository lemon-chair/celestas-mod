--- CRYOGEN [Rare]
---
--- Gains X0.75 Mult every time a Joker is frozen, and cannot be frozen itself.
---
--- Its own file for the same reason Yharon has one: it wraps a global at load,
--- and jokers/implemented.lua is sliced apart and run against stubs by the test
--- harnesses, so a top-level hook cannot live there.
---
--- The art is TWO pieces that move independently - a crystal that sits still in
--- the middle and a ring that turns around it - so it cannot be one image. The
--- crystal is the Joker's ordinary face; the ring is an overlay drawn over the
--- card every frame, turned by however long the run has been going.
---
--- Both sheets are plain 71x95 card cells (tools/gen_cryogen.py builds them),
--- which is what keeps the spin cheap: Sprite:draw_from takes a rotation
--- argument, `mr` (engine/sprite.lua:88), and turns the sprite about the card's
--- centre. A sheet larger than the card would have to be centred by hand.
---
--- editions/frozen.lua is the model for the overlay - it draws the frost pane
--- over whatever edition a card already has by exactly this route - and it is
--- loaded before this file, so the freeze functions wrapped below exist.

local CRYOGEN_KEY = "j_" .. SMODS.current_mod.prefix .. "_cryogen"

-- Declared here rather than in the generated jokers/atlases.lua: that file is
-- one atlas per Joker face, and this sheet is not a face.
SMODS.Atlas { key = "cryogen_ring", path = "cryogen_ring.png", px = 71, py = 95 }
local RING_ATLAS = SMODS.current_mod.prefix .. "_cryogen_ring"

--- Radians a second.
local SPIN = 1.2

--- True when this card is a Cryogen, either half of it.
---
--- Asked of both halves because a merged card is one card doing two Jokers'
--- jobs: a Cryogen bound into something else still gains, so it still turns.
local function is_cryogen(card)
    if not (card and card.config) then return false end
    local center = card.config.center
    if center and center.key == CRYOGEN_KEY then return true end

    local Bind = CelestasMod.Bind
    if Bind and Bind.is_merged and Bind.is_merged(card)
        and not (Bind.replacing_special and Bind.replacing_special(card)) then
        return card.ability.celesta_bind.key == CRYOGEN_KEY
    end
    return false
end

--------------------------------------------------------------------------------
-- The ring
--------------------------------------------------------------------------------

-- One sprite shared by every Cryogen on the board, built on first use: the
-- atlases do not exist yet while this file is loading.
local ring_sprite = nil

local function ring()
    if ring_sprite then return ring_sprite end
    local atlas = G.ASSET_ATLAS[RING_ATLAS]
    if not atlas then return nil end
    ring_sprite = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, { x = 0, y = 0 })
    return ring_sprite
end

local celesta_cryogen_draw_ref = Card.draw
function Card:draw(layer)
    celesta_cryogen_draw_ref(self, layer)

    if not is_cryogen(self) then return end
    -- Nothing to turn on the back of a card, and the shadow pass is the card's
    -- silhouette rather than its face.
    if self.facing == "back" or layer == "shadow" then return end

    local sprite = ring()
    if not sprite then return end

    -- G.TIMERS.REAL rather than a per-card angle: every Cryogen turns in step,
    -- and a value carried on the card would be one more thing in the save that
    -- has to survive being merged, sold and loaded.
    sprite.role.draw_major = self
    sprite:draw_shader("dissolve", nil, nil, nil, self.children.center,
                       nil, (G.TIMERS.REAL or 0) * SPIN)
end

--------------------------------------------------------------------------------
-- Freezing
--------------------------------------------------------------------------------
--
-- Both halves of this go through CelestasMod.freeze, which is the one place a
-- Joker is frozen from - AmaLee, Vulpixie and the Snowstorm all end up here -
-- so wrapping it catches every route without knowing any of them.

local celesta_cryogen_freeze_ref = CelestasMod.freeze
function CelestasMod.freeze(card, rounds)
    -- Refused rather than frozen-and-immediately-thawed: freeze answers
    -- whether it froze anything, and callers pay out on that answer.
    if is_cryogen(card) then return false end

    local froze = celesta_cryogen_freeze_ref(card, rounds)
    if not froze then return froze end

    for _, found in ipairs(CelestasMod.find_joker(CRYOGEN_KEY)) do
        local extra = found.ability and found.ability.extra
        if extra then
            extra.x_mult = extra.x_mult + extra.gain
            card_eval_status_text(found.card, "extra", nil, nil, nil, {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { extra.x_mult } },
                colour = G.C.MULT,
            })
        end
    end

    return froze
end

--------------------------------------------------------------------------------
-- The Joker
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "cryogen",
    atlas = "cryogen",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
    -- The gain is not a trigger a copy could take part in - it happens when
    -- something else freezes - and a copy of the multiplier would be a second
    -- Joker's worth of it.
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { x_mult = 1, gain = 0.75 } },

    loc_vars = function(self, info_vars, card)
        return { vars = { card.ability.extra.gain, card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        if context.joker_main and card.ability.extra.x_mult > 1 then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}
