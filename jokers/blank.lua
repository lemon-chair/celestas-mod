--- THE BLANK JOKER
---
--- A Joker with no ability of its own. Use a Tarot on it - the same Tarots that
--- enhance or convert playing cards - and it takes on that property and
--- retriggers cards that have it.
---
--- What it can hold at once:
---     one body     glass, steel, gold, stone, limestone, lucky
---     three marks  mult, wild, bonus, gash, exo
---     one suit     the four vanilla ones, plus Stars and Leaves
--- The single-slot groups REPLACE what is there; the marks fill up and then
--- refuse, because silently dropping the oldest of three is not something a
--- player can plan around.
---
--- The face is composited at runtime from tools/gen_blank_joker.py's sheet:
--- body (or the bare card), then each mark in the order it was taught, then the
--- suit pip on top. Every cell on that sheet is card-sized, so this is a stack
--- of draws at the origin with nothing to align.

CelestasMod.Blank = {}
local Blank = CelestasMod.Blank

Blank.KEY = "j_celesta_blank_joker"

-- The base card's atlas is generated with every other Joker's, in
-- jokers/atlases.lua. Only the layer sheet is declared here, because it is not
-- a Joker's face and the roster is right to leave that one alone.
SMODS.Atlas { key = "blank_joker_layers", path = "blank_joker_layers.png",
              px = 71, py = 95 }

local BASE_ATLAS = SMODS.current_mod.prefix .. "_blank_joker"
local LAYER_ATLAS = SMODS.current_mod.prefix .. "_blank_joker_layers"

--------------------------------------------------------------------------------
-- What it can learn
--------------------------------------------------------------------------------

-- Cell order on blank_joker_layers.png. Mirrors ORDER in
-- tools/gen_blank_joker.py; test_blank_joker.py asserts the two against each
-- other, so neither can be renumbered on its own.
Blank.BODIES = { "glass", "steel", "gold", "stone", "lucky", "limestone" }
Blank.MARKS = { "mult", "wild", "bonus", "gash", "exo" }
Blank.SUITS = { "Hearts", "Clubs", "Diamonds", "Spades" }

Blank.MAX_MARKS = 3

--- The enhancement each property retriggers. Built at load, because the mod's
--- own keys are only resolved once enhancements/ has run.
Blank.ENHANCEMENT = {
    glass = "m_glass", steel = "m_steel", gold = "m_gold",
    stone = "m_stone", lucky = "m_lucky",
    mult = "m_mult", wild = "m_wild", bonus = "m_bonus",
    limestone = CelestasMod.ENHANCEMENT_KEYS.Limestone,
    gash = CelestasMod.ENHANCEMENT_KEYS.Gash,
    exo = CelestasMod.ENHANCEMENT_KEYS.Exo,
}

--- ...and the suit, for the properties that are one.
Blank.SUIT = {}
for _, suit in ipairs(Blank.SUITS) do Blank.SUIT[suit] = suit end
Blank.SUIT[CelestasMod.STARS_SUIT] = CelestasMod.STARS_SUIT
Blank.SUIT[CelestasMod.LEAF_SUIT] = CelestasMod.LEAF_SUIT

--- Every property in sheet order, which is also the order the pips sit in.
Blank.LAYERS = {}
do
    local order = {}
    for _, key in ipairs(Blank.BODIES) do order[#order + 1] = key end
    for _, key in ipairs(Blank.MARKS) do order[#order + 1] = key end
    for _, key in ipairs(Blank.SUITS) do order[#order + 1] = key end
    order[#order + 1] = CelestasMod.STARS_SUIT
    order[#order + 1] = CelestasMod.LEAF_SUIT
    order[#order + 1] = "text"
    for i, key in ipairs(order) do Blank.LAYERS[key] = i - 1 end
    Blank.ORDER = order
end

--- Which of the three groups a property belongs to, or nil for one this Joker
--- has no art or meaning for.
function Blank.group(property)
    if not property then return nil end
    for _, key in ipairs(Blank.BODIES) do
        if key == property then return "body" end
    end
    for _, key in ipairs(Blank.MARKS) do
        if key == property then return "mark" end
    end
    if Blank.SUIT[property] then return "suit" end
    return nil
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
--
-- Kept under ability.celesta_blank rather than in ability.extra, for the reason
-- Bind keeps its own state there: Cryptid's Misprint Deck randomises numbers by
-- walking card.ability one level down, so ability.extra.x is reached and this
-- is not. A misprinted retrigger count on a Joker that can hold five properties
-- is not a number anyone wants randomised.

--- This Joker's state, created on first use.
function Blank.state(card)
    if not (card and card.ability) then return nil end
    local state = card.ability.celesta_blank
    if type(state) ~= "table" then
        state = { marks = {} }
        card.ability.celesta_blank = state
    end
    if type(state.marks) ~= "table" then state.marks = {} end
    return state
end

--- True for the Blank Joker itself, merged or not.
function Blank.is_blank(card)
    if not (card and card.config) then return false end
    local key = card.config.center_key
        or (card.config.center and card.config.center.key)
    return key == Blank.KEY
end

--- Does this Joker already hold that property?
function Blank.has(card, property)
    local state = Blank.state(card)
    if not state then return false end
    if state.body == property or state.suit == property then return true end
    for _, mark in ipairs(state.marks) do
        if mark == property then return true end
    end
    return false
end

--- Everything it holds, in the order it is drawn: body, marks, suit.
function Blank.properties(card)
    local state = Blank.state(card)
    local out = {}
    if not state then return out end
    if state.body then out[#out + 1] = state.body end
    for _, mark in ipairs(state.marks) do out[#out + 1] = mark end
    if state.suit then out[#out + 1] = state.suit end
    return out
end

--- Can this Joker take that property right now?
--- A body or a suit always can - the new one replaces what was there. A mark
--- cannot once three are held, and never twice.
function Blank.accepts(card, property)
    local group = Blank.group(property)
    if not group then return false end
    if group == "mark" then
        local state = Blank.state(card)
        if Blank.has(card, property) then return false end
        return #state.marks < Blank.MAX_MARKS
    end
    -- Replacing a body or suit with the one already there changes nothing.
    return not Blank.has(card, property)
end

--- Teaches the Joker a property. Returns what it displaced, if anything.
function Blank.teach(card, property)
    if not Blank.accepts(card, property) then return nil end
    local state = Blank.state(card)
    local group = Blank.group(property)
    local replaced = nil
    if group == "body" then
        replaced, state.body = state.body, property
    elseif group == "suit" then
        replaced, state.suit = state.suit, property
    else
        state.marks[#state.marks + 1] = property
    end
    Blank.invalidate_art(card)
    card.ability_UIBox_table = nil          -- the description is stale
    return replaced or false
end

--------------------------------------------------------------------------------
-- Which Tarot teaches what
--------------------------------------------------------------------------------

-- The two suit Tarots this mod adds do their work through SMODS.change_base
-- rather than vanilla's suit_conv, so they are named here. Everything else is
-- read off the two fields vanilla and Steamodded already agree on, which is
-- what lets another mod's enhancement Tarot work without being listed at all.
local NAMED = {
    c_celesta_tree = CelestasMod.LEAF_SUIT,
    c_celesta_star_fury = CelestasMod.STARS_SUIT,
}

--- The enhancement key a property is named by, reversed.
local BY_ENHANCEMENT = {}
for property, key in pairs(Blank.ENHANCEMENT) do BY_ENHANCEMENT[key] = property end

--- The property a consumable would teach, or nil for one that teaches nothing.
function Blank.property_of(consumable)
    local center = consumable and consumable.config and consumable.config.center
    if not center then return nil end
    if NAMED[center.key] then return NAMED[center.key] end

    -- ability.consumeable IS the centre's config table (Card:set_ability
    -- assigns it directly), so either reaches the same fields.
    local conf = (consumable.ability and consumable.ability.consumeable)
        or center.config or {}
    if conf.suit_conv and Blank.SUIT[conf.suit_conv] then return conf.suit_conv end
    if conf.mod_conv then return BY_ENHANCEMENT[conf.mod_conv] end
    return nil
end

--- The one highlighted Blank Joker, or nil when the selection is anything else.
--- Exactly one, so there is never a question of which was meant.
function Blank.target()
    local picked = G.jokers and G.jokers.highlighted
    if not (picked and #picked == 1) then return nil end
    return Blank.is_blank(picked[1]) and picked[1] or nil
end

--------------------------------------------------------------------------------
-- Using a Tarot on it
--------------------------------------------------------------------------------
--
-- The Tarots are vanilla's, so neither the button nor the effect can be reached
-- from a centre of ours - both hooks have to be wrapped. can_use_consumeable
-- decides whether USE lights up; use_consumeable is what it does.

--- Is this consumable, right now, aimed at a Blank Joker that can take it?
local function aimed_at_blank(consumable)
    local target = Blank.target()
    if not target then return nil end
    local property = Blank.property_of(consumable)
    if not property or not Blank.accepts(target, property) then return nil end
    return target, property
end

local celesta_blank_can_use_ref = Card.can_use_consumeable
function Card:can_use_consumeable(any_state, skip_check)
    if aimed_at_blank(self) then return true end
    return celesta_blank_can_use_ref(self, any_state, skip_check)
end

local celesta_blank_use_ref = Card.use_consumeable
function Card:use_consumeable(area, copier)
    local target, property = aimed_at_blank(self)
    if not target then
        return celesta_blank_use_ref(self, area, copier)
    end

    -- The consumable itself is removed by G.FUNCS.use_card once this returns,
    -- exactly as it is for the vanilla path, so nothing is destroyed here.
    Blank.teach(target, property)
    G.E_MANAGER:add_event(Event {
        trigger = "after", delay = 0.2,
        func = function()
            play_sound("tarot1")
            target:juice_up(0.3, 0.5)
            if G.jokers then G.jokers:unhighlight_all() end
            return true
        end
    })
end

--------------------------------------------------------------------------------
-- The face
--------------------------------------------------------------------------------
--
-- Built into an off-screen canvas between frames and cached, which is the shape
-- merge/bind.lua uses and for the same reason: Balatro draws the game into its
-- own canvas, so binding another one mid-draw means restoring the caller's
-- without knowing which attachments it was bound with. Doing it from update
-- sidesteps the question entirely.

local art_cache = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })

function Blank.invalidate_art(card)
    art_cache[card] = nil
end

--- What the face is built from, as a string. Two Blank Jokers holding the same
--- properties draw the same face, so the cache is keyed on this rather than on
--- the card.
function Blank.signature(card)
    return table.concat(Blank.properties(card), "|")
end

local function build_art(card)
    local base = G.ASSET_ATLAS[BASE_ATLAS]
    local layers = G.ASSET_ATLAS[LAYER_ATLAS]
    if not (base and base.image and layers and layers.image) then return nil end

    local w, h = base.px, base.py
    local canvas = love.graphics.newCanvas(w, h)
    local previous = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)

    local state = Blank.state(card)
    local lw, lh = layers.px, layers.py
    local sheet_w, sheet_h = layers.image:getDimensions()
    local function cell(property)
        local index = Blank.LAYERS[property]
        if not index then return end
        love.graphics.draw(layers.image,
            love.graphics.newQuad(index * lw, 0, lw, lh, sheet_w, sheet_h), 0, 0)
    end

    -- A body IS the card, so it stands in for the bare one rather than sitting
    -- over it.
    if state.body then cell(state.body) else love.graphics.draw(base.image, 0, 0) end
    for _, mark in ipairs(state.marks) do cell(mark) end
    if state.suit then cell(state.suit) end

    love.graphics.setCanvas(previous)

    -- A table of its own, never the shared atlas: every Blank Joker draws from
    -- one blank_joker.png, and writing the canvas onto that table would hand it
    -- to every other one on the board for the rest of the frame.
    -- Stamped with what it was built from, so a Joker taught something new
    -- redraws instead of keeping the face it had.
    return { image = canvas, px = w, py = h, signature = Blank.signature(card) }
end

local celesta_blank_update_ref = Game.update
function Game:update(dt)
    celesta_blank_update_ref(self, dt)
    if not next(pending) then return end
    for card in pairs(pending) do
        pending[card] = nil
        if art_cache[card] == nil then
            local ok, art = pcall(build_art, card)
            if not ok then
                CelestasMod.warn_once("blank_art",
                    "Blank Joker art failed: " .. tostring(art))
                art = nil
            end
            -- false rather than nil: nil reads as "not tried yet" and would
            -- queue this card again every frame.
            art_cache[card] = art or false
        end
    end
end

local celesta_blank_draw_ref = Card.draw
function Card:draw(layer)
    if not Blank.is_blank(self) or self.facing == "back" or layer == "shadow"
        or #Blank.properties(self) == 0 then
        return celesta_blank_draw_ref(self, layer)
    end

    -- A face built for a different set of properties is not this card's.
    local art = art_cache[self]
    if art and art.signature ~= Blank.signature(self) then art = nil end
    if art == nil then
        pending[self] = true
        return celesta_blank_draw_ref(self, layer)
    end
    if not art then return celesta_blank_draw_ref(self, layer) end

    local sprite = self.children.center
    if not (sprite and sprite.atlas) then return celesta_blank_draw_ref(self, layer) end

    local saved = sprite.atlas
    sprite.atlas = art
    local ok, err = pcall(celesta_blank_draw_ref, self, layer)
    sprite.atlas = saved
    if not ok then error(err, 0) end
end

--------------------------------------------------------------------------------
-- The Joker
--------------------------------------------------------------------------------

--- Does this scored card carry `property`?
local function matches(other, property)
    if not other then return false end
    local suit = Blank.SUIT[property]
    if suit then
        return other.is_suit ~= nil and other:is_suit(suit)
    end
    local enhancement = Blank.ENHANCEMENT[property]
    return enhancement ~= nil and SMODS.has_enhancement(other, enhancement)
end

SMODS.Joker {
    key = "blank_joker",
    atlas = "blank_joker",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    -- Merging would have to answer what a face built from five layers looks
    -- like cut corner to corner, and what the pair's own description says about
    -- properties it cannot know in advance. Refused outright instead; Bind
    -- reads this off the centre.
    celesta_no_bind = true,

    config = { extra = { repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        local held = Blank.properties(card)
        local names = {}
        for i, property in ipairs(held) do
            names[i] = Blank.SUIT[property]
                and localize(property, "suits_singular")
                or localize { type = "name_text",
                              set = "Enhanced", key = Blank.ENHANCEMENT[property] }
        end
        return { vars = { #names > 0 and table.concat(names, ", ")
                              or localize("celesta_blank_nothing") } }
    end,

    calculate = function(self, card, context)
        -- The played hand only. An unscored card arrives as 'unscored', and the
        -- end-of-round pass over the hand is G.hand, so neither reaches this.
        if not (context.repetition and context.cardarea == G.play) then return end

        local held = Blank.properties(card)
        if #held == 0 then return end

        -- One retrigger per property the card carries, so a Gold Spade on a
        -- Joker taught both goes again twice.
        local total = 0
        for _, property in ipairs(held) do
            if matches(context.other_card, property) then
                total = total + card.ability.extra.repetitions
            end
        end
        if total <= 0 then return end

        return { message = localize("k_again_ex"), repetitions = total, card = card }
    end,
}
