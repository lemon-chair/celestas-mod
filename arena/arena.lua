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

function Arena.active()
    -- Debug toggle in the mod's Config tab: forces the effect on without
    -- needing to actually draw Aquwa. Still only draws in-round.
    if MOD.config and MOD.config.debug_downpour then return "downpour" end
    return G.GAME and G.GAME.celesta_arena or nil
end

function Arena.is_active(key)
    return Arena.active() == key
end

function Arena.start(key)
    if not Arena.definitions[key] then
        sendWarnMessage("No arena effect named " .. tostring(key), "CelestasMod")
        return
    end
    if not G.GAME then return end
    G.GAME.celesta_arena = key
    Arena.time = 0
    sendInfoMessage("Arena started: " .. key, "CelestasMod")
end

function Arena.stop()
    if G.GAME then G.GAME.celesta_arena = nil end
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

    -- Back at blind select means the previous round is fully settled.
    if G.STATE == G.STATES.BLIND_SELECT and Arena.active() then
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
    Arena.trace("drawing '" .. key .. "'")

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
