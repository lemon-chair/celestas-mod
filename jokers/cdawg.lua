--- CDAWG [Legendary]
---
--- Keeps the abilities of every Common Joker from this mod sold this run, and
--- shows them as small faces turning around its own. Its merges widen that two
--- ways: which rarities count, and whether Jokers from outside this mod do.
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

--- The rarities CDawg is retaining right now.
---
--- Common always, and the rest are merges: CDawg + Green Card adds Uncommon,
--- CDawg + Fuchsia Card adds Rare, CDawg + CDawg adds both. Legendary is in no
--- rule and nothing records one, so it is never here.
---
--- Asked rather than cached, for the reason kuro_sync asks rather than caching:
--- the pair can be made, sold or debuffed between one sale and the next reading
--- of the list, and the list is what the orbit and the description are drawn
--- from.
function CelestasMod.cdawg_rarities()
    local out = { [1] = true }
    for _, rule in ipairs(CelestasMod.CDAWG_RARITY_RULES or {}) do
        local ok, rarities = pcall(rule)
        if ok and type(rarities) == "table" then
            for _, rarity in ipairs(rarities) do out[rarity] = true end
        end
    end
    return out
end

--- The rarities CDawg is retaining from outside this mod.
---
--- Empty for a plain CDawg, which is what "from this mod" on its own card
--- means. CDawg + Blue Card opens Common.
---
--- Asked rather than cached, for the reason cdawg_rarities is.
function CelestasMod.cdawg_foreign_rarities()
    local out = {}
    for _, rule in ipairs(CelestasMod.CDAWG_FOREIGN_RULES or {}) do
        local ok, rarities = pcall(rule)
        if ok and type(rarities) == "table" then
            for _, rarity in ipairs(rarities) do out[rarity] = true end
        end
    end
    return out
end

--- The centre keys CDawg is retaining, in the order they were sold.
---
--- Every sale is recorded, whatever its rarity, and the filtering happens HERE
--- rather than at the sale. That is CDawg's own rule about time: "sold this
--- run" is a fact about the run and not about what CDawg witnessed, and a merge
--- made after a sale has the same claim on it that a CDawg bought after one
--- does. Recording only what was retainable at the time would have made the
--- order the player did things in matter, silently.
---
--- Where a Joker came from is filtered here for the same reason, and used to be
--- filtered at the sale instead. A vanilla Common sold before the pair existed
--- would never have been written down, so the pair would have retained nothing
--- from before itself - which is exactly the silent dependence on order that
--- moving the rarity test here was meant to end.
---
--- The rarity is read back off the centre rather than stored, so the list is
--- the shape it has always been and a save written before any of this reads
--- back unchanged. An unknown centre counts as Common AND as one of ours, which
--- between them are the only thing such a save could have held.
function CelestasMod.commons_sold_keys()
    local sold = (G.GAME and G.GAME.celesta_commons_sold) or {}
    local retained = CelestasMod.cdawg_rarities()
    local foreign = CelestasMod.cdawg_foreign_rarities()
    local out = {}
    for _, key in ipairs(sold) do
        local center = G.P_CENTERS and G.P_CENTERS[key]
        local rarity = (center and center.rarity) or 1
        local mine = center == nil or CelestasMod.is_ours(center)
        if retained[rarity] and (mine or foreign[rarity]) then
            out[#out + 1] = key
        end
    end
    return out
end

--- ...and how many there are. Read by CDawg + Ironmouse as well.
function CelestasMod.commons_sold()
    return #CelestasMod.commons_sold_keys()
end

--- The CDawg that is running `key`, if one is.
---
--- For the Jokers whose behaviour is NOT a calculate. CDawg runs a retained
--- Common by lending its own card that centre and calling calculate, which
--- reaches everything written as one - and nothing written as a hook
--- somewhere else. Those ask "is one of me in the Joker row", and a retained
--- Joker is in no row: it was sold. So they ask this as well.
---
--- The CDawg card is what comes back rather than a boolean, because that is
--- what those hooks want it for: the probability roll needs an object the run
--- can see, and the popup belongs over the card actually doing the thing.
---
--- A Joker CDawg will never retain is never in the list to begin with - the
--- sale is not recorded for one (jokers/implemented.lua) - so there is no
--- never-check to repeat here.
function CelestasMod.cdawg_running(key)
    if not key then return nil end

    local held = false
    for _, sold in ipairs(CelestasMod.commons_sold_keys()) do
        if sold == key then held = true break end
    end
    if not held then return nil end

    -- find_joker rather than a walk of G.jokers: it skips a debuffed CDawg
    -- and finds one bound into a merge, both of which this has to honour.
    local found = CelestasMod.find_joker("j_celesta_cdawg")[1]
    return found and found.card or nil
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

--- The ability table the game itself would give a card of `center`.
---
--- Mirrored from Card:set_ability's `new_ability` (card.lua:559 onward) rather
--- than built from the centre's config, which is what this used to do and what
--- made every retained Joker that reached vanilla's own chain raise rather than
--- pay: card.lua:3976 is `self.ability.x_mult > 1`, and the table had no x_mult
--- on it. Two dozen fields are read that way, each with a default that is not
--- nil.
---
--- `name` is the one that matters most. A Joker from this mod does its work in
--- center.calculate, which is reached off the centre; a Joker from the base game
--- does its work in a chain of `self.ability.name ==` checks (card.lua:2611
--- onward), and a table with no name matches none of them.
---
--- Mirrored rather than called, because set_ability is not a table builder: it
--- resizes the card, rebuilds its sprites, takes it out of the deck and puts it
--- back, and clears the centre's used mark - all of which belong to a card
--- actually becoming that Joker, and none of which CDawg is doing.
local function vanilla_ability(center)
    local config = type(center.config) == "table" and center.config or {}
    local held = {
        -- set_ability's own fallback, for a centre that carries no name.
        name = center.name or center.key,
        effect = center.effect,
        set = "Joker",
        mult = config.mult or 0,
        h_mult = config.h_mult or 0,
        h_x_mult = config.h_x_mult or 0,
        h_dollars = config.h_dollars or 0,
        p_dollars = config.p_dollars or 0,
        t_mult = config.t_mult or 0,
        t_chips = config.t_chips or 0,
        x_mult = config.Xmult or config.x_mult or 1,
        h_chips = config.h_chips or 0,
        x_chips = config.x_chips or 1,
        h_x_chips = config.h_x_chips or 1,
        repetitions = config.repetitions or 0,
        h_size = config.h_size or 0,
        d_size = config.d_size or 0,
        type = config.type or "",
        order = center.order,
        extra_value = 0,
        perma_bonus = 0,
        perma_x_chips = 0,
        perma_mult = 0,
        perma_x_mult = 0,
        perma_h_chips = 0,
        perma_h_x_chips = 0,
        perma_h_mult = 0,
        perma_h_x_mult = 0,
        perma_p_dollars = 0,
        perma_h_dollars = 0,
        perma_repetitions = 0,
        card_limit = 0,
        extra_slots_used = 0,
        bonus = config.bonus or 0,
    }

    -- ...and then every key of the centre's config on top, which is vanilla's
    -- last word on the table and how a Joker's own fields arrive.
    for key, value in pairs(config) do
        if key ~= "bonus" then
            held[key] = type(value) == "table" and copy_table(value) or value
        end
    end

    -- Not vanilla's - it leaves `extra` nil for a centre without one - but this
    -- mod's Jokers reach into ability.extra without asking, and a retained one
    -- is not in a position to be given one later.
    held.extra = held.extra or {}
    return held
end

--- The ability table CDawg keeps for `key`, built the first time it is asked for.
---
--- Its own table per key, and kept on CDawg rather than on G.GAME: a retained
--- Joker that scales has to keep its growth, and that growth belongs to this
--- card - a second CDawg scales its own copy, and selling one does not take
--- the other's progress with it.
local function cdawg_ability(card, key, center)
    card.ability.celesta_cdawg = card.ability.celesta_cdawg or {}
    local held = card.ability.celesta_cdawg[key]
    if held then
        -- A table written before this mirrored vanilla's is missing the fields
        -- that made it raise, `name` among them. Filled in rather than replaced,
        -- and only where there is nothing there: a run in progress keeps
        -- whatever its retained Jokers have grown.
        for field, value in pairs(vanilla_ability(center)) do
            if held[field] == nil then held[field] = value end
        end
        return held
    end

    held = vanilla_ability(center)
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
    local saved_cost, saved_sell = card.cost, card.sell_cost

    card.config.center = center
    card.config.center_key = center.key or saved_key
    card.ability = ability

    local ok, effect = pcall(celesta_cdawg_calculate_ref, card, context)

    -- Asked before the ability goes back, because the answer is about what the
    -- retained Joker did while it was the one on the card. Egg is the one that
    -- does: it grows its own extra_value and then calls set_cost, which priced
    -- CDawg out of a table belonging to a Joker that is not in the row.
    local repriced = card.cost ~= saved_cost or card.sell_cost ~= saved_sell

    card.config.center = saved_center
    card.config.center_key = saved_key
    card.ability = saved_ability

    -- Priced again with CDawg's own ability back on it, which is where the
    -- banked totals are added properly (the set_cost wrap below). Only when
    -- something moved the price: this runs once per retained Joker per context.
    if repriced and card.set_cost then card:set_cost() end

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

--- One sprite per CENTRE, built on first use: the atlases do not exist while
--- this file is loading.
---
--- Per centre and not per sheet, which it used to be. `pos` is baked into the
--- Sprite and every Joker in the base game shares one sheet, so keying on the
--- sheet gave the second vanilla Joker retained the first one's face.
local orbit_sprites = {}

local function orbit_sprite(center)
    -- The sheet the game itself would draw this centre from: its own atlas if
    -- it has one and its set's otherwise, which is how Card:set_sprites
    -- resolves it (card.lua:183).
    --
    -- The fallback is the whole of what lets a Joker from outside this mod
    -- appear here at all. Every Joker in this mod has an atlas of its own, so
    -- asking for center.atlas alone always found one; a vanilla Joker has none
    -- - j_egg is one cell of G.ASSET_ATLAS.Joker - so the lookup found nothing,
    -- and a CDawg retaining the base game's Commons had an empty orbit however
    -- many it was holding.
    local sheet = center.atlas or center.set
    local key = center.key or sheet
    if not (sheet and key) then return nil end
    if orbit_sprites[key] ~= nil then return orbit_sprites[key] or nil end

    local atlas = G.ASSET_ATLAS[sheet]
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

--- Everything the retained Jokers have banked onto CDawg's sell price.
---
--- Vanilla computes a card's sell value in Card:set_cost as
---     sell_cost = max(1, floor(cost/2)) + (ability.extra_value or 0)
--- and the only extra_value it can see is CDawg's own. A retained Egg grows the
--- extra_value of the table CDawg lends IT, which vanilla will never look at.
---
--- Read off the retained tables rather than banked into CDawg's own
--- extra_value, which is Ruben Sargasm's reason: a derived total stored one
--- level down card.ability is a number Cryptid's misprintize walks and
--- randomises, and it then disagrees with the description that recomputes it.
---
--- Only what is RETAINED. A table for a Joker the row has stopped retaining -
--- the pair that widened the range was sold - is still on the card, and its
--- value is not the host's any more.
local function cdawg_banked_value(card)
    local held = card.ability and card.ability.celesta_cdawg
    if type(held) ~= "table" then return 0 end

    local total = 0
    for _, key in ipairs(CelestasMod.commons_sold_keys()) do
        local ability = held[key]
        total = total + ((ability and ability.extra_value) or 0)
    end
    return total
end

--- Read by the tests, which ask it of a card rather than of the file.
CelestasMod.cdawg_banked_value = cdawg_banked_value

-- No guard against firing mid-lend, and none is needed: is_cdawg reads
-- config.center, which during a lend is the retained Joker's centre, so it
-- answers false. That is the same reason Bind's own wrapper passes a lent card
-- straight through.
local celesta_cdawg_cost_ref = Card.set_cost
function Card:set_cost(...)
    local ret = celesta_cdawg_cost_ref(self, ...)
    if not is_cdawg(self) then return ret end

    local banked = cdawg_banked_value(self)
    if banked > 0 then
        self.sell_cost = (self.sell_cost or 0) + banked
        self.sell_cost_label = self.facing == "back" and "?" or self.sell_cost
    end
    return ret
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
    blueprint_compat = true, eternal_compat = true,

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
