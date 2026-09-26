--- CDAWG [Legendary]
---
--- Keeps the abilities of every Common Joker from this mod sold this run, and
--- shows them as small faces turning around its own.
---
--- Its own file for the reason Cryogen has one: it wraps a global at load -
--- Card.draw, for the orbit - and jokers/implemented.lua is sliced apart and
--- run against stubs by the test harnesses, so a top-level hook cannot live
--- there.

local CDAWG_KEY = "j_" .. SMODS.current_mod.prefix .. "_cdawg"

--------------------------------------------------------------------------------
-- What has been sold
--------------------------------------------------------------------------------
--
-- Kept on G.GAME rather than on the card, for the reason Grimmi's last-sale
-- name is: "sold this run" is a fact about the RUN, not about what CDawg
-- happened to witness. Selling three Commons and THEN finding a CDawg should
-- hand it all three.
--
-- Written by the Card:sell_card hook in jokers/implemented.lua, which is the
-- one place every sale of every card goes through, and read here.
--
-- One entry per KEY, however many copies were sold. Two Fufus are one Fufu's
-- worth of ability - the second would score twice off one card - and the orbit
-- would show the same face twice with nothing to tell them apart.

--- The centre keys CDawg is retaining, in the order they were sold.
function CelestasMod.commons_sold_keys()
    return (G.GAME and G.GAME.celesta_commons_sold) or {}
end

--- ...and how many there are. Read by CDawg + Ironmouse as well.
function CelestasMod.commons_sold()
    return #CelestasMod.commons_sold_keys()
end

--------------------------------------------------------------------------------
-- Running them
--------------------------------------------------------------------------------
--
-- The same trick Bind runs an absorbed half with: lend the card the retained
-- centre and an ability table of its own, then put it back through
-- Card:calculate_joker rather than calling center.calculate directly.
--
-- The ref, not the centre's function, for the reason merge/bind.lua gives at
-- length: a vanilla Joker has no `calculate` at all - what it does lives in
-- vanilla's own chain of name checks - and going through the ref also puts the
-- retained Joker through this mod's other wrappers, the Frozen edition's roll
-- and the rest. Every Common here is this mod's, so the vanilla half of that
-- does not arise; the wrappers do.
--
-- Re-entrancy takes care of itself. The lent ability table has no celesta_bind
-- on it, so Bind's own wrapper looks at the card mid-lend, sees something that
-- is not merged, and passes straight through instead of running the partner
-- once per retained Joker.

local celesta_cdawg_calculate_ref = Card.calculate_joker

--- The ability table CDawg keeps for `key`, built from the centre's config the
--- first time it is asked for.
---
--- Its own table per key, and kept on CDawg rather than on G.GAME: a retained
--- Joker that scales has to keep its growth, and that growth belongs to this
--- card - a second CDawg scales its own copy, and selling one does not take
--- the other's progress with it.
local function cdawg_ability(card, key, center)
    card.ability.celesta_cdawg = card.ability.celesta_cdawg or {}
    local held = card.ability.celesta_cdawg[key]
    if held then return held end

    held = { set = "Joker", extra = {} }
    if type(center.config) == "table" then held = copy_table(center.config) end
    held.set = "Joker"
    held.extra = held.extra or {}
    card.ability.celesta_cdawg[key] = held
    return held
end

--- True when `center` is not something CDawg keeps at all.
local function cdawg_never(center)
    return center and center.celesta_cdawg_never and true or false
end

--- True when `center` keeps this context to itself.
---
--- Declared on the centre rather than listed here, so a Joker with a part that
--- cannot be run from somebody else's card says so where that part is written.
local function cdawg_skips(center, context)
    local skip = center and center.celesta_cdawg_skip
    if type(skip) ~= "table" then return false end
    for key in pairs(skip) do
        if context[key] then return true end
    end
    return false
end

--- Runs `center` against `card` and hands back whatever it returned.
local function cdawg_run(card, center, ability, context)
    local saved_center, saved_key, saved_ability =
        card.config.center, card.config.center_key, card.ability

    card.config.center = center
    card.config.center_key = center.key or saved_key
    card.ability = ability

    local ok, effect = pcall(celesta_cdawg_calculate_ref, card, context)

    card.config.center = saved_center
    card.config.center_key = saved_key
    card.ability = saved_ability

    if not ok then
        CelestasMod.warn_once("cdawg_" .. tostring(center.key),
            ("CDawg could not run %s: %s"):format(tostring(center.key),
                                                  tostring(effect)))
        return nil
    end
    return effect
end

--------------------------------------------------------------------------------
-- The orbit
--------------------------------------------------------------------------------
--
-- Each retained Joker's own face, shrunk and placed around the card, turning
-- clockwise. Drawn over the card every frame the way Cryogen's ring is, and by
-- the same route: Sprite:draw_from takes a scale and an offset alongside the
-- rotation (engine/sprite.lua:204), so the whole of "small, and over there" is
-- two arguments rather than a transform of this file's own.
--
-- The offsets are in the card's own units - VT.w and VT.h - so the orbit sits
-- in the same place whatever the resolution and whatever the card is being
-- scaled to at the time.

--- Radians a second, clockwise.
local ORBIT_SPIN = 0.9

--- How big a retained face is drawn, as a fraction of the card it turns
--- around.
local ORBIT_SIZE = 0.38

--- ...which is what draw_shader's `ms` wants: it scales by 1 + ms
--- (engine/sprite.lua:208).
local ORBIT_SCALE = ORBIT_SIZE - 1

--- ...and how far out its centre sits, as a fraction of the card's width and
--- height. Wider than tall, because the card is taller than it is wide and one
--- number for both would stand the ring on its end.
---
--- CHOSEN, not derived, and far enough out that each face sits wholly outside
--- the card. That is the shape of the thing: a ring turning AROUND CDawg,
--- rather than a pattern printed on it.
---
--- These were briefly replaced with a single inset derived from the face size,
--- (1 - size)/2, which keeps every face within the card's own bounds. It also
--- pulls the ring in to under half the distance and bunches the faces over the
--- card, which is not what this is. If the ring reaching across a neighbouring
--- Joker ever has to be solved, it is a drawing-order problem rather than a
--- reason to shrink the orbit.
---
--- Card units, not pixels, so this holds at any resolution and at whatever
--- size the card is being drawn.
local ORBIT_X, ORBIT_Y = 0.72, 0.56

--- Read by the tests, which hold these to the distance the orbit is drawn at.
CelestasMod.CDAWG_ORBIT = { size = ORBIT_SIZE, x = ORBIT_X, y = ORBIT_Y }

--- One sprite per atlas, built on first use: the atlases do not exist while
--- this file is loading.
local orbit_sprites = {}

local function orbit_sprite(center)
    local key = center.atlas or center.key
    if not key then return nil end
    if orbit_sprites[key] ~= nil then return orbit_sprites[key] or nil end

    local atlas = G.ASSET_ATLAS[key]
    if not atlas then
        -- false rather than nil, so a missing atlas is asked about once
        -- rather than every frame of every card.
        orbit_sprites[key] = false
        return nil
    end
    orbit_sprites[key] = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas,
                                center.pos or { x = 0, y = 0 })
    return orbit_sprites[key]
end

--- True when this card is a CDawg, either half of it.
---
--- Both halves, because a merged card is one card doing two Jokers' jobs: a
--- CDawg bound into something else still retains, so it still shows what.
local function is_cdawg(card)
    if not (card and card.config) then return false end
    local center = card.config.center
    if center and center.key == CDAWG_KEY then return true end

    local Bind = CelestasMod.Bind
    if Bind and Bind.is_merged and Bind.is_merged(card)
        and not (Bind.replacing_special and Bind.replacing_special(card)) then
        return card.ability.celesta_bind.key == CDAWG_KEY
    end
    return false
end

local celesta_cdawg_draw_ref = Card.draw
function Card:draw(layer)
    celesta_cdawg_draw_ref(self, layer)

    if not is_cdawg(self) then return end
    -- Nothing to show on the back of a card, and the shadow pass is the card's
    -- silhouette rather than its face.
    if self.facing == "back" or layer == "shadow" then return end
    -- ...and nothing in the Collection. The orbit is a reading of the RUN -
    -- which Commons have been sold in it - and a card in the Collection is not
    -- in a run at all, so it was showing one run's faces over a card that
    -- belongs to none. It covers the art, too, which is the point of it in the
    -- row and only in the way on a page of Jokers to look at.
    --
    -- area.config.collection is vanilla's own test for that (card.lua:98), and
    -- merge/web.lua already reads it the same way.
    if self.area and self.area.config and self.area.config.collection then
        return
    end

    local keys = CelestasMod.commons_sold_keys()
    local n = #keys
    if n == 0 then return end

    local major = self.children.center
    if not major then return end

    -- G.TIMERS.REAL rather than an angle carried on the card: every CDawg
    -- turns in step, and a value on the card would be one more thing in the
    -- save that has to survive being merged, sold and loaded.
    local now = (G.TIMERS.REAL or 0) * ORBIT_SPIN
    local step = 2 * math.pi / n

    for i = 1, n do
        local center = G.P_CENTERS[keys[i]]
        local sprite = center and orbit_sprite(center)
        if sprite then
            local angle = now + (i - 1) * step
            -- sin across, minus cos down. y grows downwards on screen, so
            -- that pair runs top, right, bottom, left: clockwise.
            sprite.role.draw_major = self
            sprite:draw_shader("dissolve", nil, nil, nil, major,
                               ORBIT_SCALE, nil,
                               math.sin(angle) * major.VT.w * ORBIT_X,
                               -math.cos(angle) * major.VT.h * ORBIT_Y)
        end
    end
end

--------------------------------------------------------------------------------
-- What the retained Jokers are holding
--------------------------------------------------------------------------------
--
-- A Joker that keeps a running total says so on its own card - "(Currently +14
-- Chips)" and the like - and a retained one is still keeping it, in the ability
-- table CDawg holds for it. So those lines are put on CDawg's card too, one per
-- total, each with the name of the Joker it belongs to.
--
-- Which line is a total is read off the RAW localization text, because that is
-- where the word "Currently" still is: by the time the row is built it is parts
-- and colours. The row is then built with the Joker's OWN loc_vars against
-- CDawg's copy of its ability, so the number is the one this CDawg has grown.

--- The word a running total is written with. English only, and deliberately:
--- it is looked for in this mod's own descriptions and vanilla's, both of
--- which are written in it, and a translation would want its own list here
--- rather than a guess.
local TOTAL_MARKER = "Currently"

--- Rows for one retained Joker's running totals, or nil if it keeps none.
local function cdawg_total_rows(card, key)
    local center = G.P_CENTERS[key]
    local loc = G.localization and G.localization.descriptions
        and G.localization.descriptions.Joker
        and G.localization.descriptions.Joker[key]
    if not (center and loc and loc.text) then return nil end

    local wanted = {}
    for i, line in ipairs(loc.text) do
        if type(line) == "string" and line:find(TOTAL_MARKER, 1, true) then
            wanted[#wanted + 1] = i
        end
    end
    if #wanted == 0 then return nil end

    local stub = { ability = cdawg_ability(card, key, center),
                   config = { center = center, center_key = key } }
    local vars = {}
    if type(center.loc_vars) == "function" then
        local ok, res = pcall(center.loc_vars, center, {}, stub)
        if ok and type(res) == "table" and type(res.vars) == "table" then
            vars = res.vars
        end
    end

    -- localize rather than generate_card_ui: this wants the lines and nothing
    -- else, and generate_card_ui would run the centre's loc_vars a second time
    -- against a card that is not CDawg.
    local rows = {}
    local ok = pcall(localize, { type = "descriptions", set = "Joker",
                                 key = key, vars = vars, nodes = rows })
    if not ok then return nil end

    local name = localize { type = "name_text", set = "Joker", key = key }
    local out = {}
    for _, i in ipairs(wanted) do
        local row = rows[i]
        if row then
            -- The name after the total, in the same inactive grey the total is
            -- written in, so the pair reads as one line.
            row[#row + 1] = { n = G.UIT.T, config = {
                text = " - " .. tostring(name),
                colour = G.C.UI.TEXT_INACTIVE, scale = 0.32 } }
            out[#out + 1] = { n = G.UIT.R, config = { align = "cl" },
                              nodes = row }
        end
    end
    if #out == 0 then return nil end
    return out
end

--- Every retained Joker's totals, as the one extra node loc_vars may add.
---
--- main_end is appended to the description as a SINGLE node (Steamodded's
--- game_object.lua:1858), so several lines have to arrive inside one column
--- rather than as several rows.
local function cdawg_totals(card)
    local rows = {}
    for _, key in ipairs(CelestasMod.commons_sold_keys()) do
        for _, row in ipairs(cdawg_total_rows(card, key) or {}) do
            rows[#rows + 1] = row
        end
    end
    if #rows == 0 then return nil end
    return { { n = G.UIT.C, config = { align = "m" }, nodes = rows } }
end

--------------------------------------------------------------------------------
-- The Joker
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "cdawg",
    atlas = "cdawg",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    -- A copy would run every retained Joker a second time, which is a good
    -- deal more than a copy of one Joker is meant to be.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {
            vars = { CelestasMod.commons_sold() },
            main_end = cdawg_totals(card),
        }
    end,

    calculate = function(self, card, context)
        local keys = CelestasMod.commons_sold_keys()
        if #keys == 0 then return end

        local out = nil
        local combine = CelestasMod.Bind and CelestasMod.Bind.combine
        for _, key in ipairs(keys) do
            local center = G.P_CENTERS[key]
            if center and not cdawg_never(center)
                and not cdawg_skips(center, context) then
                local effect = cdawg_run(card, center,
                    cdawg_ability(card, key, center), context)
                if effect then
                    -- Bind's, so a +4 Mult retained alongside a X3 Mult
                    -- behaves like owning both - additive values add and
                    -- multiplicative ones multiply.
                    out = combine and combine(out, effect) or (out or effect)
                end
            end
        end
        return out
    end,
}
