--- BIND — merging two Jokers into one
---
--- Bind is a Spectral card. Highlight two Jokers, use it, and they become a
--- single Joker occupying one slot that does everything both of them did.
---
--- The merged card keeps the LEFT Joker as its host: that card stays in the
--- row, keeps its position and its center, and carries the right-hand Joker's
--- center key and ability table in card.ability.celesta_bind. Nothing new is
--- created, so eternal stickers, sell value and every other per-card thing
--- have an obvious home.
---
--- Editions follow the rule as given:
---   * neither has one          -> the merge has none
---   * exactly one has one      -> 50% chance to keep it
---   * both have the SAME one   -> always kept
---   * both have DIFFERENT ones -> 50/50 between the two

CelestasMod.Bind = {}
local Bind = CelestasMod.Bind

local BIND_SEED = "celesta_bind"

-- Resolved at load: SMODS.current_mod is only valid while the mod is loading,
-- and the draw hook below runs every frame long afterwards.
local PREFIX = SMODS.current_mod.prefix

-- The glowing white the split line and the border are drawn in. One constant
-- so they can never drift apart.
Bind.GLOW = { 1, 1, 1, 0.9 }
Bind.GLOW_WIDTH = 2

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function Bind.is_merged(card)
    return card and card.ability and type(card.ability.celesta_bind) == "table"
        and card.ability.celesta_bind.key ~= nil
end

--- The centre of the Joker bound into this one.
function Bind.partner_center(card)
    if not Bind.is_merged(card) then return nil end
    return G.P_CENTERS[card.ability.celesta_bind.key]
end

--- True for a Joker that Bind is willing to take as an ingredient.
--- A merged Joker is refused: merging merges would nest indefinitely, and the
--- art has exactly two halves.
function Bind.can_bind(card)
    if not (card and card.ability and card.config and card.config.center) then return false end
    if card.ability.set ~= "Joker" then return false end
    if Bind.is_merged(card) then return false end
    return true
end

--- The two highlighted Jokers, or nil when the selection is not exactly two
--- bindable ones.
function Bind.selection()
    if not (G.jokers and G.jokers.highlighted) then return nil end
    local picked = {}
    for _, joker in ipairs(G.jokers.highlighted) do
        if not Bind.can_bind(joker) then return nil end
        picked[#picked + 1] = joker
    end
    if #picked ~= 2 then return nil end
    return picked
end

--------------------------------------------------------------------------------
-- Editions
--------------------------------------------------------------------------------

--- Resolves which edition, if any, survives the merge.
--- Split out so the rule is readable on its own and testable without a board.
function Bind.resolve_edition(edition_a, edition_b)
    local function coin(id)
        local ok, roll = pcall(pseudorandom, pseudoseed(BIND_SEED .. "_" .. id))
        -- A roll that errored keeps the edition: losing one to an error is
        -- worse for the player than keeping one.
        return (not ok) or roll < 0.5
    end

    if not edition_a and not edition_b then return nil end

    if edition_a and edition_b then
        -- Matching editions are never lost.
        if edition_a.key == edition_b.key then return edition_a end
        -- Otherwise a straight 50/50 between the two; neither can be dropped.
        return coin("which") and edition_a or edition_b
    end

    -- Exactly one edition in play: half the time it carries over.
    local lone = edition_a or edition_b
    return coin("keep") and lone or nil
end

--------------------------------------------------------------------------------
-- The merge
--------------------------------------------------------------------------------

--- Folds `absorbed` into `host` and removes it from the Joker row.
function Bind.merge(host, absorbed)
    if not (Bind.can_bind(host) and Bind.can_bind(absorbed)) then return false end

    local edition = Bind.resolve_edition(host.edition, absorbed.edition)

    -- Copied, not referenced: the absorbed card is about to be destroyed, and
    -- a Joker that scales itself needs somewhere of its own to keep growing.
    local carried = copy_table(absorbed.ability)
    if type(absorbed.ability.extra) == "table" then
        -- copy_table is shallow, and `extra` is the table effects actually
        -- mutate, so it needs a copy of its own.
        carried.extra = copy_table(absorbed.ability.extra)
    end
    -- Cannot survive on the absorbed half: it would let a merge be merged.
    carried.celesta_bind = nil

    host.ability.celesta_bind = {
        key = absorbed.config.center_key or absorbed.config.center.key,
        ability = carried,
    }

    -- The stickers are inherited rather than dropped, so a merge cannot be
    -- used to launder an Eternal Joker into a sellable one.
    for _, sticker in ipairs({ "eternal", "perishable", "rental" }) do
        if absorbed.ability[sticker] then host.ability[sticker] = absorbed.ability[sticker] end
    end
    if absorbed.ability.perish_tally and (not host.ability.perish_tally
        or absorbed.ability.perish_tally < host.ability.perish_tally) then
        host.ability.perish_tally = absorbed.ability.perish_tally
    end

    host:set_edition(edition, true, true)

    -- Cryptid's face-down flag has no meaning on a card whose whole point is
    -- showing two faces, and the spec rules it out outright.
    host.cry_flipped = nil

    -- One card now does two jobs, so it is worth what both were worth.
    host.sell_cost = (host.sell_cost or 0) + (absorbed.sell_cost or 0)

    Bind.invalidate_art(host)

    absorbed.ability.eternal = nil       -- or it refuses to leave the row
    absorbed:start_dissolve(nil, true)
    return true
end

--------------------------------------------------------------------------------
-- Running both halves
--------------------------------------------------------------------------------

-- Set while the absorbed half is being evaluated, so a centre that starts a
-- fresh evaluation pass cannot come straight back in here.
local running = false

-- Which keys combine how, when both halves answer the same context.
local ADDITIVE = {
    chips = true, h_chips = true, chip_mod = true,
    mult = true, h_mult = true, mult_mod = true,
    p_dollars = true, dollars = true, h_dollars = true,
    repetitions = true,
}
local MULTIPLICATIVE = {
    x_chips = true, xchips = true, Xchip_mod = true,
    x_mult = true, Xmult = true, xmult = true,
    x_mult_mod = true, Xmult_mod = true, h_x_mult = true,
    e_mult = true, emult = true, e_chips = true, echips = true,
}

--- Folds the absorbed half's effect into the host's.
--- Additive values add and multiplicative ones multiply, which is what makes a
--- +4 Mult bound to a X3 Mult behave like owning both Jokers.
local function combine(primary, secondary)
    if not primary then return secondary end
    if not secondary then return primary end
    for key, value in pairs(secondary) do
        local existing = primary[key]
        if type(value) == "number" and type(existing) == "number" then
            if MULTIPLICATIVE[key] then
                primary[key] = existing * value
            elseif ADDITIVE[key] then
                primary[key] = existing + value
            end
        elseif existing == nil then
            primary[key] = value
        end
    end
    return primary
end

local celesta_bind_calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context)
    local effect, post = celesta_bind_calculate_joker_ref(self, context)

    if running or not Bind.is_merged(self) then return effect, post end
    local center = Bind.partner_center(self)
    if not center or type(center.calculate) ~= "function" then return effect, post end

    -- The absorbed centre reads its own fields off card.ability, so it is lent
    -- the ability table that came with it - the same trick Eutrophic uses to
    -- run a foreign centre against a card that is not really it. Lent rather
    -- than copied: a Joker that scales itself must keep that growth.
    running = true
    local saved_center, saved_ability = self.config.center, self.ability
    self.config.center = center
    self.ability = self.ability.celesta_bind.ability
    local ok, partner = pcall(center.calculate, center, self, context)
    self.config.center, self.ability = saved_center, saved_ability
    running = false

    if not ok then
        CelestasMod.warn_once("bind_calc_" .. tostring(center.key),
            ("Bind could not run %s: %s"):format(tostring(center.key), tostring(partner)))
        return effect, post
    end
    if type(partner) ~= "table" then return effect, post end

    -- Both halves can want to say something, and an effect table carries only
    -- one message. The host's rides along in the return; the absorbed half's
    -- is spoken here so neither trigger goes unannounced.
    if effect and effect.message and partner.message then
        local said = partner.message
        partner.message = nil
        card_eval_status_text(self, "extra", nil, nil, nil,
            { message = said, colour = partner.colour or G.C.FILTER })
    end

    return combine(effect, partner), post
end

--------------------------------------------------------------------------------
-- Art: the two faces split corner to corner
--------------------------------------------------------------------------------

-- Composited into an off-screen canvas at merge time rather than stencilled
-- during Card:draw. In canvas space the split is just a triangle across a
-- known rectangle; doing it live would mean reproducing Balatro's card
-- transform (position, rotation, the hover tilt) to place the same triangle in
-- screen space, and getting that subtly wrong is invisible until it is not.
local art_cache = setmetatable({}, { __mode = "k" })

-- Balatro's card silhouette: the transparent run inwards from the left edge,
-- per row, for a 71x95 sprite, mirrored horizontally. Measured off the game's
-- own Jokers.png by tools/round_corners.py, which masks every sprite in this
-- mod with the same numbers - so a merged card is cut to exactly the shape a
-- joker is meant to be.
--
-- The two halves arrive already rounded, being ordinary joker art. Only the
-- glow needs this: a stroked rectangle runs straight through the corners the
-- art carefully leaves empty, which reads as a merged card having square
-- corners while every other card is round.
local CORNER_W, CORNER_H = 71, 95
local CORNER_PROFILE = { CORNER_W, 4, 2, 2 }
for _ = 1, 87 do CORNER_PROFILE[#CORNER_PROFILE + 1] = 1 end
for _, inset in ipairs({ 2, 2, 4, CORNER_W }) do
    CORNER_PROFILE[#CORNER_PROFILE + 1] = inset
end

--- Fills the card silhouette, scaled to a canvas of any size, as a stencil.
local function card_silhouette(w, h)
    local sx, sy = w / CORNER_W, h / CORNER_H
    for row = 1, CORNER_H do
        local inset = CORNER_PROFILE[row] * sx
        local run = w - inset * 2
        if run > 0 then
            love.graphics.rectangle("fill", inset, (row - 1) * sy, run, sy + 1)
        end
    end
end

function Bind.invalidate_art(card)
    art_cache[card] = nil
end

--- The atlas and quad a centre draws itself from.
local function face_of(center)
    if not center then return nil end
    local atlas = G.ASSET_ATLAS[center.atlas or center.set]
    if not (atlas and atlas.image) then return nil end
    local pos = center.pos or { x = 0, y = 0 }
    local w, h = atlas.px, atlas.py
    return atlas.image, love.graphics.newQuad(pos.x * w, pos.y * h, w, h,
        atlas.image:getDimensions())
end

--- Builds the merged face: host in the upper-left, absorbed in the lower-right,
--- a glowing white line along the corner-to-corner split and the same glow
--- around the border.
local function build_art(card)
    local host_image, host_quad = face_of(card.config.center)
    local other_image, other_quad = face_of(Bind.partner_center(card))
    if not (host_image and other_image) then return nil end

    local atlas = G.ASSET_ATLAS[card.config.center.atlas or card.config.center.set]
    local w, h = atlas.px, atlas.py

    -- The stencil flag belongs on setCanvas, NOT on newCanvas: LOVE 11 has no
    -- such canvas setting and rejects it outright ("Invalid canvas setting
    -- name: stencil"). Asking for it at bind time is what makes LOVE attach a
    -- stencil buffer for the duration.
    local canvas = love.graphics.newCanvas(w, h)
    local previous = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)

    -- The split runs bottom-left to top-right, so the host keeps the corner
    -- above that line and the absorbed half takes the one below it.
    love.graphics.draw(host_image, host_quad, 0, 0)
    love.graphics.stencil(function()
        love.graphics.polygon("fill", 0, h, w, h, w, 0)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.draw(other_image, other_quad, 0, 0)
    love.graphics.setStencilTest()

    -- Clipped to the card silhouette so the border follows the rounding
    -- instead of squaring off the corners.
    love.graphics.stencil(function() card_silhouette(w, h) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setColor(Bind.GLOW)
    love.graphics.setLineWidth(Bind.GLOW_WIDTH)
    love.graphics.line(0, h, w, 0)
    love.graphics.rectangle("line", 0, 0, w, h)
    love.graphics.setStencilTest()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas(previous)
    return canvas
end

-- Building happens between frames, never inside one.
--
-- The obvious place is the draw hook, the moment the art turns out to be
-- missing - and it is the wrong place: Balatro draws the whole game into its
-- own canvas, so binding another one mid-draw means restoring the caller's
-- canvas afterwards without knowing what attachments it was bound with.
-- love.graphics.getCanvas hands back the canvas but not the flags, so the
-- restore is a guess. Doing it from update sidesteps the question - nothing is
-- bound there.
--
-- A card that wants art is queued and drawn plainly for the frame or two until
-- it arrives, which nobody will catch.
local pending = setmetatable({}, { __mode = "k" })

local celesta_bind_game_update_ref = Game.update
function Game:update(dt)
    celesta_bind_game_update_ref(self, dt)
    if not next(pending) then return end
    for card in pairs(pending) do
        pending[card] = nil
        if Bind.is_merged(card) and art_cache[card] == nil then
            local ok, art = pcall(build_art, card)
            if not ok then
                CelestasMod.warn_once("bind_art",
                    "Bind could not build merged art: " .. tostring(art))
                art = nil
            end
            -- false rather than nil: nil means "not tried yet" and would queue
            -- this card again every single frame.
            art_cache[card] = art or false
        end
    end
end

local celesta_bind_card_draw_ref = Card.draw
function Card:draw(layer)
    if not Bind.is_merged(self) or self.facing == "back" or layer == "shadow" then
        return celesta_bind_card_draw_ref(self, layer)
    end

    local art = art_cache[self]
    if art == nil then
        -- Not built yet. Ask for it and draw plainly this frame.
        pending[self] = true
        return celesta_bind_card_draw_ref(self, layer)
    end
    if not art then return celesta_bind_card_draw_ref(self, layer) end

    -- The merged face replaces the host's centre sprite for the duration of
    -- the normal draw, so everything else - shadows, tilt, edition shaders,
    -- stickers - keeps working untouched.
    local sprite = self.children.center
    if not (sprite and sprite.atlas) then return celesta_bind_card_draw_ref(self, layer) end
    local saved_image = sprite.atlas.image
    sprite.atlas.image = art
    celesta_bind_card_draw_ref(self, layer)
    sprite.atlas.image = saved_image
end

--------------------------------------------------------------------------------
-- Description: both halves, side by side
--------------------------------------------------------------------------------

local celesta_bind_ability_table_ref = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table(...)
    local box = celesta_bind_ability_table_ref(self, ...)
    if not Bind.is_merged(self) then return box end

    local center = Bind.partner_center(self)
    if not (center and type(box) == "table" and box.info) then return box end

    -- Handing generate_card_ui the table it already built, rather than a fresh
    -- one, is what puts the absorbed half's description into box.info - the
    -- same list the game fills for tooltips, so it renders as its own panel
    -- beside the main one and needs no layout of mine.
    --
    -- Building the columns by hand is what the first attempt did, and it
    -- crashed in set_parent_child: a UI node's `nodes` must be a LIST of
    -- nodes, and getting that one level wrong is not visible until something
    -- walks the tree. This route cannot get the shape wrong, because the game
    -- builds it.
    local ok, err = pcall(generate_card_ui, center, box, nil, "Joker", nil, nil)
    if not ok then
        CelestasMod.warn_once("bind_desc_" .. tostring(center.key),
            ("Bind could not describe %s: %s"):format(tostring(center.key), tostring(err)))
    end
    return box
end

--------------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------------

SMODS.Consumable {
    key = "bind",
    set = "Spectral",
    atlas = "bind",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    can_use = function(self, card)
        return Bind.selection() ~= nil
    end,

    use = function(self, card, area, copier)
        local picked = Bind.selection()
        if not picked then return end

        -- The host is whichever sits further left, so the merge lands where the
        -- player already expects it rather than jumping position.
        local host, absorbed = picked[1], picked[2]
        for _, joker in ipairs(G.jokers.cards) do
            if joker == picked[2] then host, absorbed = picked[2], picked[1] break end
            if joker == picked[1] then break end
        end

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                play_sound("gold_seal", 1.2, 0.6)
                host:juice_up(0.4, 0.5)
                Bind.merge(host, absorbed)
                return true
            end,
        })
        delay(0.6)
    end,
}

-- Two Jokers have to be selectable at once. Vanilla builds G.jokers with
-- highlight_limit = 1, which would make Bind impossible to satisfy. Raised to
-- exactly 2 rather than something large, so the rest of the game's
-- single-selection behaviour is disturbed as little as possible. Cryptid sets
-- this to 1e100 for its own cards; whoever asks for more wins.
local celesta_bind_start_run_ref = Game.start_run
function Game:start_run(args)
    local ret = celesta_bind_start_run_ref(self, args)
    if G.jokers and G.jokers.config
        and (G.jokers.config.highlighted_limit or 1) < 2 then
        G.jokers.config.highlighted_limit = 2
    end
    return ret
end
