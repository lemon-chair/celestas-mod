--- ARENA EFFECTS
---
--- A round-scoped, screen-wide weather effect. One can be active at a time.
--- Each is an animated tiling texture drawn over the whole window, plus an
--- optional colour wash, plus whatever rules its `hooks` table installs.
---
--- Lifecycle
---   started  by a joker (Aquwa) on context.setting_blind
---   cleared  automatically once the game returns to BLIND_SELECT
--- That window deliberately extends past the last played hand so that things
--- awarded during round evaluation - Blue Seal Planets, for instance - still
--- count as "obtained during the round". The visuals are gated separately to
--- in-round states only, so the shop is not left raining.
---
--- The active effect is stored on G.GAME so it survives a save/load mid-run;
--- only the animation clock is local state.

CelestasMod.Arena = CelestasMod.Arena or {}
local Arena = CelestasMod.Arena

-- SMODS.current_mod is only meaningful while the mod is loading, so resolve
-- the prefix and keep the mod table now rather than inside the draw hook.
local MOD = SMODS.current_mod
local ATLAS_PREFIX = MOD.prefix .. "_"

--------------------------------------------------------------------------------
-- Definitions
--------------------------------------------------------------------------------

--- atlas   SMODS.Atlas key (unprefixed) holding the frame grid
--- frames  total frames, laid out left-to-right then top-to-bottom
--- cols    frames per row in that grid
--- fps     playback rate
--- tile    frame size in px; the texture must tile seamlessly at this size
--- scale   on-screen magnification of one tile
--- alpha   opacity of the animation itself
--- tint    {r, g, b, a} colour wash drawn under the animation
Arena.definitions = {
    downpour = {
        atlas  = "fx_downpour",
        frames = 16,
        cols   = 4,
        fps    = 10,
        tile   = 256,
        scale  = 2,
        alpha  = 0.55,
        -- Desaturated blue: low saturation so it reads as overcast light
        -- rather than a colour filter over the cards.
        tint   = { 0.32, 0.42, 0.55, 0.17 },
    },
    snowstorm = {
        atlas  = "fx_snowstorm",
        frames = 16,
        cols   = 4,
        fps    = 10,
        tile   = 256,
        scale  = 2,
        alpha  = 0.55,
        -- A pale, near-white wash: snow reads as brightness rather than a
        -- colour cast, so this is much less saturated than Downpour's blue.
        tint   = { 0.85, 0.90, 0.96, 0.15 },
    },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

Arena.time = 0
local quad_cache = {}

--- Log a reason at most once per distinct message, so the draw hook can
--- explain itself without spamming the log 60 times a second.
--- Currently unconditional while the overlay is being brought up; gate it
--- behind MOD.config.verbose_logging again once it is working.
local last_trace
function Arena.trace(msg)
    if msg == last_trace then return end
    last_trace = msg
    sendInfoMessage("[arena] " .. msg, "CelestasMod")
end

--- The weather a DECK holds up for the whole run, if any.
---
--- Kept apart from G.GAME.celesta_arena rather than written into it, because
--- that one is round-scoped by design: Arena.active clears it as soon as
--- G.GAME.round moves on, and the shop clears it outright. A deck's weather
--- has no round to belong to, so it has to be asked about separately.
function Arena.permanent()
    return G.GAME and G.GAME.celesta_arena_always or nil
end

--- Makes a weather permanent for the rest of the run. Called from a Back's
--- apply; on G.GAME so it is saved with the run like everything else.
function Arena.set_permanent(key)
    if not G.GAME then return end
    if key ~= nil and not Arena.definitions[key] then
        sendWarnMessage("No arena effect named " .. tostring(key), "CelestasMod")
        return
    end
    G.GAME.celesta_arena_always = key
end

function Arena.active()
    -- Debug toggle in the mod's Config tab: forces the effect on without
    -- needing to actually draw Aquwa. Still only draws in-round.
    if MOD.config and MOD.config.debug_downpour then return "downpour" end
    if not G.GAME then return nil end

    if G.GAME.celesta_arena then
        -- Safety net for save/load and any path that skips the shop: an
        -- effect never outlives the round it was started in.
        if not (G.GAME.celesta_arena_round and G.GAME.round
                and G.GAME.round ~= G.GAME.celesta_arena_round) then
            return G.GAME.celesta_arena
        end
    end

    -- A round's own weather wins while it lasts, which keeps "one at a time"
    -- true: a Joker that starts a Downpour on the Blizzard Deck really does
    -- get a Downpour, and the deck's own comes back when the round ends.
    return Arena.permanent()
end

function Arena.is_active(key)
    return Arena.active() == key
end

--------------------------------------------------------------------------------
-- What the weather DOES, beyond looking like weather
--------------------------------------------------------------------------------
--
-- A Snowstorm grows the hand: every hand played under one leaves another card
-- in the next.
--
-- The rule belongs to the STORM rather than to any Joker - it holds with an
-- empty Joker row - so the mod itself answers for it.
-- SMODS.get_mods_scoring_targets (utils.lua:2114) puts a mod carrying a
-- `calculate` into the same pass Backs, Blinds and Stakes are evaluated in, so
-- a rule with no card behind it still receives every context. That function is
-- assigned at the bottom of this section, and it is the mod's ONLY one: a
-- second rule that wants it has to be added inside it rather than written over
-- the top.
--
-- The cards are LENT for the round and taken back at the end of it, rather
-- than lasting as long as the storm. The Blizzard Deck's Snowstorm never
-- stops, and a hand that grows by one every hand for a whole run is a
-- different card from the one this is.

Arena.SNOWSTORM_HAND_SIZE = 1

--- How many cards the weather has lent the hand. On G.GAME so it is saved
--- with the run, beside the card limit it is paired with - a run loaded
--- mid-storm owes back exactly what it borrowed.
local LENT = "celesta_arena_hand_size"

--- Lend one more card, if there is weather asking for it. Returns how many.
function Arena.grow_hand()
    if not (G.GAME and G.hand and Arena.is_active("snowstorm")) then return 0 end
    local by = Arena.SNOWSTORM_HAND_SIZE
    if by <= 0 then return 0 end
    G.GAME[LENT] = (G.GAME[LENT] or 0) + by
    G.hand:change_size(by)
    return by
end

--- Take back everything the weather lent. Idempotent: what is owed is
--- remembered rather than recomputed, so a second call has nothing left to
--- take and a storm that ends twice cannot shrink the hand twice.
function Arena.release_hand()
    if not G.GAME then return 0 end
    local lent = G.GAME[LENT] or 0
    G.GAME[LENT] = nil
    if lent ~= 0 and G.hand then G.hand:change_size(-lent) end
    return lent
end

MOD.calculate = function(self, context)
    -- context.after is the end of a played hand, raised once from inside
    -- evaluate_play (state_events.lua:869) - which is before the deal that
    -- follows it, so the card lent here is a card drawn.
    if context.after then
        Arena.grow_hand()
    elseif context.end_of_round then
        Arena.release_hand()
    end
end

function Arena.start(key)
    if not Arena.definitions[key] then
        sendWarnMessage("No arena effect named " .. tostring(key), "CelestasMod")
        return
    end
    if not G.GAME then return end
    G.GAME.celesta_arena = key
    -- ease_round(1) runs in select_blind, before the setting_blind context, so
    -- G.GAME.round is already this round's number by the time a joker starts one.
    G.GAME.celesta_arena_round = G.GAME.round
    Arena.time = 0
    sendInfoMessage("Arena started: " .. key .. " (round " ..
        tostring(G.GAME.round) .. ")", "CelestasMod")
end

function Arena.stop()
    -- Belt and braces: the round's end has already given these back by the
    -- time the shop clears the weather, and release_hand is idempotent - but
    -- a storm must not be able to end while still holding cards of the
    -- player's, whichever route ends it.
    Arena.release_hand()
    if G.GAME then
        G.GAME.celesta_arena = nil
        G.GAME.celesta_arena_round = nil
    end
    Arena.time = 0
end

--- Should the overlay be drawn right now? Logically the effect outlives the
--- last hand, but it should not be visible in the shop or in menus.
local DRAW_STATES = nil
local function drawable_state()
    if not G.STATE or not G.STATES then return false end
    DRAW_STATES = DRAW_STATES or {
        [G.STATES.SELECTING_HAND] = true,
        [G.STATES.HAND_PLAYED]    = true,
        [G.STATES.DRAW_TO_HAND]   = true,
        [G.STATES.PLAY_TAROT]     = true,
        [G.STATES.NEW_ROUND]      = true,
        -- Round evaluation is still the round: Blue Seals resolve here.
        [G.STATES.ROUND_EVAL]     = true,
        [G.STATES.TAROT_PACK]     = true,
        [G.STATES.PLANET_PACK]    = true,
        [G.STATES.SPECTRAL_PACK]  = true,
        [G.STATES.STANDARD_PACK]  = true,
        [G.STATES.BUFFOON_PACK]   = true,
        [G.STATES.SMODS_BOOSTER_OPENED] = true,
    }
    return DRAW_STATES[G.STATE] or false
end

--------------------------------------------------------------------------------
-- Update / draw, hung off Game so no Lovely patch is needed
--------------------------------------------------------------------------------

local game_update_ref = Game.update
function Game:update(dt)
    game_update_ref(self, dt)

    -- Entering the shop ends the round proper. Clearing here rather than at
    -- BLIND_SELECT matters: setting_blind fires while G.STATE is still
    -- BLIND_SELECT, so a blind-select clear wiped the effect on the very next
    -- frame after a joker started it. The shop is also the correct cut-off for
    -- the rule itself - round evaluation (Blue Seals) still counts, shop
    -- purchases do not.
    if G.STATE == G.STATES.SHOP and G.GAME and G.GAME.celesta_arena then
        Arena.stop()
    end
    if Arena.active() then
        Arena.time = Arena.time + (dt or 0)
    end
end

local game_draw_ref = Game.draw
function Game:draw()
    game_draw_ref(self)

    -- Proves the wrapper is actually on the call path, which separates
    -- "never called" from "called but bailed" in the log. One-shot, and kept
    -- off Arena.trace's dedupe so the two do not alternate every frame.
    if not Arena.hook_logged then
        Arena.hook_logged = true
        sendInfoMessage("[arena] draw hook reached", "CelestasMod")
    end

    local key = Arena.active()
    if not key then return Arena.trace("no arena active") end
    if not drawable_state() then
        return Arena.trace("arena '" .. key .. "' active but state " ..
            tostring(G.STATE) .. " is not drawable")
    end
    local def = Arena.definitions[key]
    if not def then return Arena.trace("no definition for '" .. key .. "'") end
    local atlas = G.ASSET_ATLAS[ATLAS_PREFIX .. def.atlas]
    if not atlas or not atlas.image then
        return Arena.trace("atlas '" .. ATLAS_PREFIX .. def.atlas ..
            "' missing from G.ASSET_ATLAS")
    end
    -- Compared against false so a config predating this key still animates.
    local animate = not (MOD.config and MOD.config.arena_animation == false)
    -- One trace covering both modes; two alternating messages would defeat the
    -- dedupe and log every frame.
    Arena.trace("drawing '" .. key .. "'" .. (animate and "" or " (tint only)"))

    -- Game:draw has already flushed its canvas to the screen and cleared the
    -- shader, so this lands on top in raw window pixels.
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")

    local w, h = love.graphics.getDimensions()

    if def.tint then
        love.graphics.setColor(def.tint[1], def.tint[2], def.tint[3], def.tint[4])
        love.graphics.rectangle("fill", 0, 0, w, h)
    end

    -- "Arena animation" off in the mod config: keep the colour wash, skip the
    -- moving texture entirely.
    if not animate then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.pop()
        return
    end

    local img = atlas.image
    local iw, ih = img:getDimensions()
    local frame = math.floor(Arena.time * def.fps) % def.frames
    local cache = quad_cache[key]
    -- Balatro loads either the 1x or the 2x sheet depending on the graphics
    -- setting, so a frame is iw/cols px - NOT necessarily def.tile. Quads must
    -- be built from the real size or a 2x sheet yields a quarter of frame 0.
    local sheet_tile = iw / def.cols

    if not cache or cache.iw ~= iw then
        cache = { iw = iw, quads = {} }
        for i = 0, def.frames - 1 do
            cache.quads[i] = love.graphics.newQuad(
                (i % def.cols) * sheet_tile, math.floor(i / def.cols) * sheet_tile,
                sheet_tile, sheet_tile, iw, ih)
        end
        quad_cache[key] = cache
        Arena.trace(("sheet %dx%d, frame %dpx, %d quads")
            :format(iw, ih, sheet_tile, def.frames))
    end

    -- Draw at a constant on-screen tile size either way.
    local step = def.tile * def.scale
    local draw_scale = step / sheet_tile

    love.graphics.setColor(1, 1, 1, def.alpha)
    for x = 0, w, step do
        for y = 0, h, step do
            love.graphics.draw(img, cache.quads[frame], x, y, 0, draw_scale, draw_scale)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

--------------------------------------------------------------------------------
-- Downpour rule: consumables obtained during the round become Negative.
--------------------------------------------------------------------------------

local cardarea_emplace_ref = CardArea.emplace
function CardArea:emplace(card, location, stay_flipped)
    cardarea_emplace_ref(self, card, location, stay_flipped)

    if not Arena.is_active("downpour") then return end
    if self ~= G.consumeables then return end
    if not card or not card.ability or not card.config then return end
    -- Only consumable types, and never overwrite an edition the card already
    -- has (a Negative from elsewhere, a mod's custom edition, ...).
    if not SMODS.ConsumableTypes[card.ability.set] then return end
    if card.edition then return end

    card:set_edition({ negative = true }, true)
end
