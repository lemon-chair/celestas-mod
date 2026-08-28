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

-- The glow along the split and around the border. One definition, so the two
-- can never drift apart.
--
-- Drawn as three passes rather than one stroke: widest and faintest first,
-- narrowest and solid last, so the white core sits inside a soft halo. A
-- single 2px line is not a glow - it reads as a grey hairline once the card is
-- scaled down to its place on the board.
--
-- Widths are in units of 1/71st of the card, so the 1x and 2x sheets glow
-- identically instead of the 2x looking half as thick.
Bind.GLOW = { 1, 1, 1 }
Bind.GLOW_PASSES = {
    { width = 5.0, alpha = 0.16 },
    { width = 2.6, alpha = 0.38 },
    { width = 1.2, alpha = 1.00 },
}

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
-- Special pairs
--------------------------------------------------------------------------------
--
-- Some pairs are worth more than the sum of their halves. When both centres of
-- a merge match one of these, the pair's own ability REPLACES both - neither
-- half's normal behaviour runs.
--
-- Keyed on the two centre keys sorted and joined, so a pair matches whichever
-- order the player merged them in.

Bind.SPECIALS = {}

local function pair_key(a, b)
    if a > b then a, b = b, a end
    return a .. "|" .. b
end

--- def = { key, config, calculate, loc_vars }
--- `config` is the pair's own mutable state; it is copied onto the card the
--- first time the pair is evaluated and serialized with it thereafter.
local function special(key_a, key_b, def)
    Bind.SPECIALS[pair_key(key_a, key_b)] = def
end

--- The special governing this merge, if the pair has one.
function Bind.special_of(card)
    if not Bind.is_merged(card) then return nil end
    local host = card.config.center_key
        or (card.config.center and card.config.center.key)
    if not host then return nil end
    return Bind.SPECIALS[pair_key(host, card.ability.celesta_bind.key)]
end

--- The pair's saved state, created from its config on first use.
function Bind.special_state(card, def)
    local bound = card.ability.celesta_bind
    if type(bound.special) ~= "table" then
        bound.special = copy_table(def.config or {})
    end
    return bound.special
end

--------------------------------------------------------------------------------

-- Arar + Jaws: the cards that missed out get something out of the hand anyway.
special("j_celesta_arar", "j_celesta_jaws", {
    key = "arar_jaws",
    calculate = function(def, card, context, state)
        if not (context.after and not context.blueprint) then return end
        local hand = context.full_hand or (G.play and G.play.cards)
        if type(hand) ~= "table" then return end

        -- Everything the poker hand actually used, so what is left is exactly
        -- the cards that were carried along without scoring.
        local scored = {}
        for _, played in ipairs(context.scoring_hand or {}) do scored[played] = true end

        local touched = 0
        for _, played in ipairs(hand) do
            if not scored[played] and played.config
                and played.config.center == G.P_CENTERS.c_base then
                -- poll_enhancement respects the run's pool, so this never
                -- rolls an enhancement the run has disabled and does pick up
                -- ones other mods add.
                local enhancement = SMODS.poll_enhancement {
                    key = "celesta_bind_arar_jaws",
                    guaranteed = true,
                }
                if enhancement and G.P_CENTERS[enhancement] then
                    local target = played
                    G.E_MANAGER:add_event(Event {
                        func = function()
                            target:set_ability(G.P_CENTERS[enhancement], nil, true)
                            return true
                        end
                    })
                    touched = touched + 1
                end
            end
        end

        if touched > 0 then
            return {
                message = localize("k_plus_enhancement"),
                colour = G.C.SECONDARY_SET.Enhanced,
                card = card,
            }
        end
    end,
})

-- Crelly + KokoNuts: KokoNuts keeps making Lucky 7s of Spades; this eats them.
special("j_celesta_crelly", "j_celesta_kokonuts", {
    key = "crelly_koko",
    config = { x_mult = 1, x_mult_gain = 0.25 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.destroying_card and context.cardarea == G.play
            and not context.blueprint then
            local target = context.destroying_card
            if SMODS.has_enhancement(target, "m_lucky")
                and target.get_id and target:get_id() == 7
                and target.is_suit and target:is_suit("Spades") then
                -- calculate_destroying_cards acts on `remove` without checking
                -- whether the card can actually go, so eternals are refused
                -- here or the row keeps a card that was told to leave.
                if SMODS.is_eternal and SMODS.is_eternal(target) then return end
                state.x_mult = state.x_mult + state.x_mult_gain
                return {
                    remove = true,
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { state.x_mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- Kumi + Maya: Kumi eats gold, Maya works with Steel; together they cash Steel in.
special("j_celesta_kumi", "j_celesta_maya", {
    key = "kumi_maya",
    config = { dollars = 15, odds = 2 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_kumi_maya")
        return { vars = { numerator, denominator, state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if context.destroying_card and context.cardarea == G.play
            and not context.blueprint then
            local target = context.destroying_card
            if SMODS.has_enhancement(target, "m_steel") then
                if SMODS.is_eternal and SMODS.is_eternal(target) then return end
                -- `remove` and `dollars` are both other_calculation_keys, so
                -- one table can destroy the card and pay out at once.
                local effect = { remove = true, card = card }
                if SMODS.pseudorandom_probability(card, "celesta_bind_kumi_maya",
                        1, state.odds, "celesta_bind_kumi_maya") then
                    effect.dollars = state.dollars
                end
                return effect
            end
        end
    end,
})

-- Deme + Camila: both care about a lone first hand; this reads what it was
-- wearing.
local DEME_CAMILA_GAINS = {
    none = 0.25,
    e_foil = 0.5,
    e_holo = 0.75,
    e_polychrome = 1.0,
}

special("j_celesta_demenishki", "j_celesta_camila", {
    key = "deme_camila",
    config = { x_mult = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        -- hands_played == 0 is vanilla's own idiom for "this is the first hand
        -- of the round" - DNA and Sixth Sense both gate on it.
        if context.before and not context.blueprint
            and G.GAME and G.GAME.current_round
            and G.GAME.current_round.hands_played == 0
            and context.full_hand and #context.full_hand == 1 then
            local played = context.full_hand[1]
            local edition = played.edition and played.edition.key or "none"
            -- An unknown edition, from another mod, is worth the plain rate
            -- rather than nothing.
            local gain = DEME_CAMILA_GAINS[edition] or DEME_CAMILA_GAINS.none
            state.x_mult = state.x_mult + gain
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { state.x_mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- Jax + Bricky: Bricky alone reads the whole deck every hand; bound to Jax it
-- stops counting and starts collecting, keeping what it is paid.
special("j_celesta_jaxvtuber", "j_celesta_bricky", {
    key = "jax_bricky",
    config = { chips = 0, chip_mod = 20 },

    loc_vars = function(def, card, state)
        return { vars = { state.chip_mod, state.chips } }
    end,

    calculate = function(def, card, context, state)
        -- The individual pass runs over the scoring cards BEFORE the joker row
        -- is evaluated, so a stone scored this hand is already paying by the
        -- time joker_main asks for the total.
        if context.individual and context.cardarea == G.play
            and not context.blueprint then
            local scored = context.other_card
            local limestone = (CelestasMod.ENHANCEMENT_KEYS or {}).Limestone
            if scored and (SMODS.has_enhancement(scored, "m_stone")
                or (limestone and SMODS.has_enhancement(scored, limestone))) then
                state.chips = state.chips + state.chip_mod
                return {
                    message = localize { type = "variable", key = "a_chips",
                                         vars = { state.chips } },
                    colour = G.C.CHIPS,
                    card = card,
                }
            end
        end

        if context.joker_main and state.chips > 0 then
            return { chips = state.chips }
        end
    end,
})

-- Nagzz + Chibidoki: Nagzz bends every listed chance; together they lean on
-- the cards whose whole point is a chance.
special("j_celesta_nagzz", "j_celesta_chibidoki", {
    key = "nagzz_chibidoki",
    config = { repetitions = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if context.repetition and context.cardarea == G.play
            and context.other_card
            and SMODS.has_enhancement(context.other_card, "m_lucky") then
            return {
                message = localize("k_again_ex"),
                repetitions = state.repetitions,
                card = card,
            }
        end
    end,
})

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
function Card:calculate_joker(context, ...)
    local effect, post = celesta_bind_calculate_joker_ref(self, context, ...)

    if running or not Bind.is_merged(self) then return effect, post end

    -- A special pair REPLACES both halves. The host's own calculate has
    -- already run by this point - the ref is called first so that frozen
    -- rolls, tattered counting and every other mod's hook still see the
    -- evaluation - but its result is dropped in favour of the pair's.
    local def = Bind.special_of(self)
    if def then
        if running then return effect, post end
        running = true
        local state = Bind.special_state(self, def)
        local ok, special_effect = pcall(def.calculate, def, self, context, state)
        running = false
        if not ok then
            CelestasMod.warn_once("bind_special_" .. tostring(def.key),
                ("Bind pair %s failed: %s"):format(tostring(def.key), tostring(special_effect)))
            return nil, post
        end
        return special_effect, post
    end

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

--- The atlas a centre draws itself from.
--- The same rule Card:set_sprites uses (card.lua:165): a centre's own atlas if
--- it declares one, otherwise its set for the sets that have their own sheet,
--- otherwise the shared "centers" sheet.
local function atlas_for(center)
    if not center then return nil end
    local key = center.atlas
        or ((center.set == "Joker" or center.consumeable or center.set == "Voucher")
            and center.set)
        or "centers"
    return G.ASSET_ATLAS[key]
end

--- The atlas and quad a centre draws itself from.
local function face_of(center)
    if not center then return nil end
    local atlas = atlas_for(center)
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

    local atlas = atlas_for(card.config.center)
    if not atlas then return nil end
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
    local unit = w / CORNER_W
    love.graphics.stencil(function() card_silhouette(w, h) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    for _, pass in ipairs(Bind.GLOW_PASSES) do
        local stroke = pass.width * unit
        love.graphics.setColor(Bind.GLOW[1], Bind.GLOW[2], Bind.GLOW[3], pass.alpha)
        love.graphics.setLineWidth(stroke)
        love.graphics.line(0, h, w, 0)
        -- Inset by half the stroke. LOVE centres a stroke on its path, so a
        -- rectangle drawn on the canvas edge loses its outer half off the side
        -- and the border comes out looking thinner than the split line - which
        -- is exactly how it looked before.
        local inset = stroke / 2
        love.graphics.rectangle("line", inset, inset, w - stroke, h - stroke)
    end
    love.graphics.setStencilTest()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas(previous)

    -- Handed back as a private atlas rather than a bare canvas. The sprite is
    -- given this whole table in place of its own, so nothing is ever written
    -- into the shared one - vanilla Jokers all draw from a single Jokers.png,
    -- and swapping the image on that table would hand every other joker on the
    -- board this canvas for the rest of the frame.
    return { image = canvas, px = w, py = h }
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
    if not (sprite and sprite.atlas and sprite.sprite) then
        return celesta_bind_card_draw_ref(self, layer)
    end

    -- The QUAD has to be swapped too, not just the image.
    --
    -- Sprite:draw_shader draws self.atlas.image through self.sprite, and that
    -- quad was cut for the card's real atlas: for a mod joker, whose atlas is
    -- one card, it is (0,0,71,95) and pointing it at this canvas happens to be
    -- right. For a vanilla joker it points at that joker's cell deep inside
    -- the shared Jokers.png, and sampling a 71x95 canvas with it returns
    -- whatever lies outside - which is exactly how a merge of two vanilla
    -- jokers came out as a smear.
    if not art.quad then
        art.quad = love.graphics.newQuad(0, 0, art.px, art.py,
                                         art.image:getDimensions())
    end

    local saved_atlas, saved_quad, saved_dims =
        sprite.atlas, sprite.sprite, sprite.image_dims
    sprite.atlas = art
    sprite.sprite = art.quad
    sprite.image_dims = { art.image:getDimensions() }

    celesta_bind_card_draw_ref(self, layer)

    sprite.atlas, sprite.sprite, sprite.image_dims =
        saved_atlas, saved_quad, saved_dims
end

--------------------------------------------------------------------------------
-- Description: both halves, side by side
--------------------------------------------------------------------------------

-- A special pair describes itself, in place of both halves.
--
-- Swapped into the card's own AUT rather than assembled as a panel by hand:
-- card_h_popup then builds it exactly as it builds every other card's, name
-- row and rarity badge and box included. Hand-assembling a panel is what
-- crashed set_parent_child the first time.
local celesta_bind_special_ability_ref = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table(...)
    local box = celesta_bind_special_ability_ref(self, ...)
    local def = Bind.special_of(self)
    if not (def and type(box) == "table") then return box end

    local state = Bind.special_state(self, def)
    local vars = {}
    if type(def.loc_vars) == "function" then
        local ok, res = pcall(def.loc_vars, def, self, state)
        if ok and type(res) == "table" and res.vars then vars = res.vars end
    end

    local loc_key = "celesta_bind_" .. def.key
    local ok, aut = pcall(generate_card_ui,
        { set = "Other", key = loc_key }, nil, vars, "Other", nil, false)
    if not (ok and type(aut) == "table" and aut.main) then
        CelestasMod.warn_once("bind_special_desc_" .. tostring(def.key),
            "Bind pair " .. tostring(def.key) .. " has no description")
        return box
    end
    box.main = aut.main

    -- The pair's own name, in place of the host's.
    local name_rows = {}
    localize { type = "name", set = "Other", key = loc_key, nodes = name_rows }
    if name_rows[1] then box.name = name_rows[1] end
    return box
end

-- Set while the absorbed half's description is being generated, so the hook
-- below cannot re-enter itself.
local describing = false

--- The absorbed half's description table, built as though it were on its own
--- card so its own loc_vars run and any value it has scaled up shows the
--- number it has actually reached.
local function partner_ui(card)
    local center = Bind.partner_center(card)
    if not center or describing then return nil end

    describing = true
    local saved_center, saved_ability = card.config.center, card.ability
    card.config.center = center
    card.ability = card.ability.celesta_bind.ability
    local ok, aut = pcall(card.generate_UIBox_ability_table, card)
    card.config.center, card.ability = saved_center, saved_ability
    describing = false

    if not (ok and type(aut) == "table" and aut.main) then
        CelestasMod.warn_once("bind_desc_" .. tostring(center.key),
            ("Bind could not describe %s: %s"):format(tostring(center.key), tostring(aut)))
        return nil
    end
    return aut, center
end

-- Both halves get the same panel, because it is literally the same node shape
-- card_h_popup builds for the card's own description: an outer rounded row in
-- lightened JOKER_GREY holding an inner row in the type background, wrapping
-- name_from_rows / desc_from_rows / badges.
--
-- The first attempt appended the absorbed half to AUT.info instead, which was
-- less code but rendered it as a tooltip - a smaller box in a different style
-- sitting beside a full one.
-- G.UIDEF is built at boot, well before mods load, so this is present. Guarded
-- anyway: wrapping a nil would swap a missing popup for a crashing one.
local celesta_bind_popup_ref = G.UIDEF and G.UIDEF.card_h_popup
if celesta_bind_popup_ref then
function G.UIDEF.card_h_popup(card)
    local root = celesta_bind_popup_ref(card)
    if not Bind.is_merged(card) then return root end
    if type(root) ~= "table" or type(root.nodes) ~= "table" then return root end

    -- A special pair has one ability and therefore one panel. Its description
    -- is swapped in below, before card_h_popup ever sees it, so there is
    -- nothing to add here.
    if Bind.special_of(card) then return root end

    local aut, center = partner_ui(card)
    if not aut then return root end

    -- Its own rarity, shown the way the host's is.
    local badges = {}
    local rarity_names = { localize("k_common"), localize("k_uncommon"),
                           localize("k_rare"), localize("k_legendary") }
    local label = center.rarity and rarity_names[center.rarity]
    if label then
        badges[1] = create_badge(label, get_type_colour(center, card), nil, 1.2)
    end

    root.nodes[#root.nodes + 1] = {
        n = G.UIT.C,
        config = { align = "cm" },
        nodes = { {
            n = G.UIT.R,
            config = { padding = 0.05, r = 0.12,
                       colour = lighten(G.C.JOKER_GREY, 0.5), emboss = 0.07 },
            nodes = { {
                n = G.UIT.R,
                config = { align = "cm", padding = 0.07, r = 0.1,
                           colour = adjust_alpha(darken(G.C.BLACK, 0.1), 0.8) },
                nodes = {
                    name_from_rows(aut.name),
                    desc_from_rows(aut.main),
                    badges[1] and { n = G.UIT.R, config = { align = "cm", padding = 0.03 },
                                    nodes = badges } or nil,
                },
            } },
        } },
    }
    return root
end
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
