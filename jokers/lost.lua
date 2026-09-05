--- THE LOST
---
--- What the Lost Soul leaves behind. A Joker it is spent on is not replaced -
--- the same card stays in the same slot and becomes a harder, worse-tempered
--- version of itself, at a rarity that is drawn black and named "...".
---
--- Its own file because it wraps three globals at load - Card.can_sell_card,
--- create_shop_card_ui and G.UIDEF.card_h_popup - and jokers/implemented.lua is
--- sliced apart and run against stubs by the test harnesses, so a top-level
--- hook cannot live there. Cryogen, Yharon and the Phoenix Egg have their own
--- files for the same reason.
---
--- Loads after implemented.lua (jokers/ is loaded in sorted order) and before
--- zz_vtubers.lua, so the Lost forms sit with the finished Jokers in the
--- Collection rather than past the placeholder roster.

local PREFIX = SMODS.current_mod.prefix

local MAYA_KEY = "j_" .. PREFIX .. "_maya"
local CORRUPT_MAYA_KEY = "j_" .. PREFIX .. "_corrupt_maya"
local LOST_SOUL_KEY = "c_" .. PREFIX .. "_lost_soul"

--------------------------------------------------------------------------------
-- The rarity
--------------------------------------------------------------------------------
--
-- Weight 0, which is how Legendary is declared too (game_object.lua:957): the
-- rarity exists and has a pool, but no ordinary roll ever lands on it. A Lost
-- Joker arrives by conversion or not at all.

local rarity = SMODS.Rarity {
    key = "lost",
    loc_txt = {},
    default_weight = 0,
    badge_colour = HEX("000000"),
}

--- The prefixed key the badge and every Joker below refer to.
--- Read back off the object rather than spelled out, because the prefix is
--- applied inside the constructor (game_object.lua:33).
local LOST_RARITY = rarity and rarity.key or (PREFIX .. "_lost")

--------------------------------------------------------------------------------
-- The registry
--------------------------------------------------------------------------------

CelestasMod.Lost = CelestasMod.Lost or {}
local Lost = CelestasMod.Lost

Lost.SOUL_KEY = LOST_SOUL_KEY

--- Which Joker becomes which. One entry per pair; everything else in this file
--- reads the table rather than naming a card, so adding the next conversion is
--- a line here plus the Joker itself.
Lost.CONVERSIONS = {
    [MAYA_KEY] = CORRUPT_MAYA_KEY,
}

--- True for a Joker the Lost Soul can be spent on.
---
--- A merged Joker is refused. A Lost Joker cannot be merged, so converting one
--- half of a pair would make a merged card that is not allowed to exist - and
--- there is no answer to what the other half would then be.
function Lost.convertible(card)
    if not (card and card.ability and card.config and card.config.center) then
        return false
    end
    if card.ability.set ~= "Joker" then return false end
    if not Lost.CONVERSIONS[card.config.center.key] then return false end

    local Bind = CelestasMod.Bind
    if Bind and Bind.is_merged and Bind.is_merged(card) then return false end
    return true
end

--- True for a Joker that has already been converted.
function Lost.is_lost(card)
    return card ~= nil and card.config ~= nil and card.config.center ~= nil
        and card.config.center.celesta_lost == true
end

--- Every Joker on the board the Lost Soul could be spent on, board order.
function Lost.targets()
    local out = {}
    if not (G.jokers and G.jokers.cards) then return out end
    for _, joker in ipairs(G.jokers.cards) do
        if Lost.convertible(joker) then out[#out + 1] = joker end
    end
    return out
end

--- True while a Lost Soul is sitting in the consumable tray.
--- This is what "in the Lost Soul's presence" means: one held, not one that
--- exists somewhere in the run.
function Lost.soul_held()
    if not (G.consumeables and G.consumeables.cards) then return false end
    for _, card in ipairs(G.consumeables.cards) do
        if card.config and card.config.center
            and card.config.center.key == LOST_SOUL_KEY then
            return true
        end
    end
    return false
end

--- Turns `card` into its Lost version, in place.
---
--- The same card rather than a new one, so it keeps its slot, its edition, its
--- stickers and its sell value. set_ability is how every centre swap in the
--- game is done - it is what the enhancement Tarots and the Phoenix Egg use -
--- but it does NOT run either centre's add_to_deck or remove_from_deck, and
--- both of those matter here: the old Joker may have given the run something,
--- and the new one takes four Joker slots away. So they are called by hand,
--- in the order a sale-then-purchase would have done it.
function Lost.convert(card)
    local key = Lost.CONVERSIONS[card.config.center.key]
    local center = key and G.P_CENTERS[key]
    if not center then return false end

    card:remove_from_deck()
    card:set_ability(center, nil, true)
    card:add_to_deck()
    return true
end

--------------------------------------------------------------------------------
-- Joker slots
--------------------------------------------------------------------------------

--- Moves an area's slot count by `delta`.
---
--- Through card_limits.mod rather than through config.card_limit, for the
--- reason written out at length above bump_limit in jokers/implemented.lua:
--- under Steamodded card_limit is DERIVED and only as fresh as the last frame,
--- so two writes inside one frame both read the same stale number. `mod` is
--- stored rather than derived and has no such problem.
local function bump_limit(area, delta)
    if delta == 0 or not area or not area.config then return end
    local limits = area.config.card_limits
    if limits then
        limits.mod = (limits.mod or 0) + delta
    else
        -- No Steamodded metatable: card_limit is an ordinary field.
        area.config.card_limit = area.config.card_limit + delta
    end
end

--------------------------------------------------------------------------------
-- Steel
--------------------------------------------------------------------------------

--- What one Steel card is worth held in hand right now.
---
--- Read rather than assumed to be 1.5. A Lost Maya says Steel Cards give X3,
--- and it delivers that by multiplying whatever Steel is already giving up to
--- 3 - so if a card's own h_x_mult has been moved (Hologram, a misprint, a
--- mod that retunes the enhancement), the pair still lands on exactly X3
--- instead of on 3 times the wrong number.
local function steel_value(other_card)
    local own = other_card and other_card.ability and other_card.ability.h_x_mult
    if own and own ~= 0 then return own end
    local center = G.P_CENTERS and G.P_CENTERS.m_steel
    local base = center and center.config and center.config.h_x_mult
    if base and base ~= 0 then return base end
    return nil
end

--------------------------------------------------------------------------------
-- The shop
--------------------------------------------------------------------------------
--
-- Every shop item, without exception - the Jokers, the vouchers and the
-- booster packs.
--
-- create_shop_card_ui is the hook because it is the one thing all of them have
-- in common: a card without a price tag and a buy button is not a shop item,
-- and every path that puts one in front of the player goes through here -
-- create_card_for_shop (UI_definitions.lua:764), SMODS.add_voucher_to_shop and
-- SMODS.add_booster_to_shop (utils.lua:2380, 2400), the four branches that
-- rebuild a shop from a save (game.lua:3208-3261), and the tag that hands out
-- a voucher (tag.lua:335).
--
-- The card is changed in place rather than swapped out, which matters: every
-- one of those callers keeps hold of the object and goes on to materialize it,
-- position it and emplace it afterwards. And the button is chosen from
-- card.ability.set inside a deferred event, not from the `type` argument
-- (UI_definitions.lua:836), so a card that has become a Joker by the time that
-- event runs gets a Buy button rather than Redeem or Open - which is why
-- nothing here has to touch the argument.

--- True while some Lost Joker is holding the shop shut.
local function shop_is_taken()
    if not (G.jokers and G.jokers.cards) then return false end
    for _, joker in ipairs(G.jokers.cards) do
        if Lost.is_lost(joker) and joker.config.center.celesta_lost_shop then
            return true
        end
    end
    return false
end

--- Makes `card` a Maya, whatever it was.
local function mayaify(card)
    local maya = G.P_CENTERS[MAYA_KEY]
    if not (card and maya) then return end
    if card.config and card.config.center == maya then return end

    -- Set before the swap: it is what create_shop_card_ui would otherwise
    -- read to decide this is a voucher.
    card.shop_voucher = nil
    card:set_ability(maya, nil, true)
    card:set_cost()
end

--- Rebuilds the shop that is already on screen.
---
--- The hook above catches a shop as it is BUILT, which is every shop the
--- player walks into - but a Lost Soul can be spent while standing in one,
--- and the items already laid out have had their price tag and their button
--- made. So those are torn down and asked for again, which sends each card
--- back through the hook. Torn down the way buying a card does it
--- (button_callbacks.lua:2240), because a UIBox left behind is a button that
--- still works.
local function retake_shop()
    local areas = {}
    if G.shop_jokers then areas[#areas + 1] = G.shop_jokers end
    if G.shop_vouchers then areas[#areas + 1] = G.shop_vouchers end
    if G.shop_booster then areas[#areas + 1] = G.shop_booster end

    for _, area in ipairs(areas) do
        for _, card in ipairs(area.cards or {}) do
            for _, name in ipairs({ "price", "buy_button", "buy_and_use_button" }) do
                local box = card.children and card.children[name]
                if box then
                    box:remove()
                    card.children[name] = nil
                end
            end
            create_shop_card_ui(card, nil, area)
        end
    end
end

local celesta_lost_shop_ui_ref = create_shop_card_ui

if celesta_lost_shop_ui_ref then
    function create_shop_card_ui(card, type, area)
        if shop_is_taken() then mayaify(card) end
        return celesta_lost_shop_ui_ref(card, type, area)
    end
end

--------------------------------------------------------------------------------
-- Corrupt Maya
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "corrupt_maya",
    atlas = "corrupt_maya",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,

    -- Never offered, never rolled. Weight 0 already keeps the rarity out of
    -- every ordinary roll; this is the belt to that pair of braces, and covers
    -- anything that builds a pool by walking the centres instead.
    in_pool = function() return false end,

    -- Read by merge/bind.lua's can_bind, which is where the Blank Joker
    -- refuses to be merged too. A Lost Joker is not an ingredient.
    celesta_no_bind = true,

    -- Read by Lost.is_lost, which is what the no-sell hook and the inverted
    -- description box below both key off.
    celesta_lost = true,

    -- This one is Maya's own, not every Lost Joker's: it is what holds the
    -- shop shut. The next conversion added will not take the shop over unless
    -- it says so here too.
    celesta_lost_shop = true,

    config = { extra = { x_mult = 3, repetitions = 6, joker_slots = 4 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_steel
        local extra = card.ability.extra
        return { vars = { extra.x_mult, extra.repetitions, extra.joker_slots } }
    end,

    add_to_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, -card.ability.extra.joker_slots)
        -- A Lost Soul can be spent while standing in the shop, so the shop
        -- that is already on screen is rebuilt rather than left until the
        -- next one.
        retake_shop()
    end,

    remove_from_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, card.ability.extra.joker_slots)
    end,

    calculate = function(self, card, context)
        -- Held-in-hand scoring pass: one raise per Steel card, per trigger.
        --
        -- The card is given the RATIO rather than the whole number, because
        -- Steel is still paying its own X1.5 alongside this. 3/1.5 = X2 from
        -- here, and the two together are the X3 the description promises.
        if context.individual and context.cardarea == G.hand
            and not context.end_of_round then
            if SMODS.has_enhancement(context.other_card, "m_steel") then
                local base = steel_value(context.other_card)
                if base then
                    return { x_mult = card.ability.extra.x_mult / base }
                end
            end
        end

        -- Held-in-hand repetition pass. Maya's is a coin flip for two extra
        -- triggers; this one is neither a coin flip nor two.
        if context.repetition and context.cardarea == G.hand then
            if SMODS.has_enhancement(context.other_card, "m_steel") then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Cannot be sold
--------------------------------------------------------------------------------
--
-- Wrapped rather than answered through check_eternal, which is the other route
-- Card:can_sell_card offers (card.lua:1905, via SMODS.is_eternal). That route
-- runs a whole calculation pass and shares its no_destroy flag with being
-- destroyed, so a Joker that used it would also become indestructible - which
-- is not what "cannot be sold" says.

local celesta_lost_can_sell_ref = Card.can_sell_card
function Card:can_sell_card(context)
    if Lost.is_lost(self) then return false end
    return celesta_lost_can_sell_ref(self, context)
end

--------------------------------------------------------------------------------
-- The inverted description
--------------------------------------------------------------------------------
--
-- The description box and the text in it, and nothing else: the card's name
-- plate and its badges are left alone, so the rarity badge stays the black it
-- was declared as rather than being flipped to white along with everything
-- around it.
--
-- The box is found by its own flag. desc_from_rows marks the main description
-- with main_box_flag (UI_definitions.lua:1065) precisely so it can be picked
-- out of the finished tree later, which is what the multi-box code just below
-- it does too.

--- A colour, inverted. A NEW table every time, without exception: the tables
--- in this tree are G.C entries, shared by every card in the game, and one
--- in-place flip of G.C.UI.TEXT_DARK would invert the text on all of them.
local function invert(colour)
    if type(colour) ~= "table" or #colour < 3 then return colour end
    return { 1 - colour[1], 1 - colour[2], 1 - colour[3], colour[4] or 1 }
end

--- Inverts every colour in a UI subtree, in place.
local function invert_tree(node, seen)
    if type(node) ~= "table" then return end
    seen = seen or {}
    if seen[node] then return end
    seen[node] = true

    local config = node.config
    if config then
        config.colour = invert(config.colour)
        config.outline_colour = invert(config.outline_colour)

        -- Text is a DynaText object rather than a node, and holds its own
        -- list of colours to cycle through.
        local object = config.object
        if object and type(object.colours) == "table" then
            local flipped = {}
            for i, colour in ipairs(object.colours) do flipped[i] = invert(colour) end
            object.colours = flipped
        end
    end

    for _, child in ipairs(node.nodes or {}) do invert_tree(child, seen) end
end

--- Finds the main description box in a finished popup and inverts it.
local function invert_description(node, seen)
    if type(node) ~= "table" then return false end
    seen = seen or {}
    if seen[node] then return false end
    seen[node] = true

    if node.config and node.config.main_box_flag then
        invert_tree(node)
        return true
    end
    for _, child in ipairs(node.nodes or {}) do
        if invert_description(child, seen) then return true end
    end
    return false
end

local celesta_lost_popup_ref = G.UIDEF and G.UIDEF.card_h_popup

if celesta_lost_popup_ref then
    G.UIDEF.card_h_popup = function(card)
        local box = celesta_lost_popup_ref(card)
        if Lost.is_lost(card) then invert_description(box) end
        return box
    end
end

--------------------------------------------------------------------------------
-- The glow
--------------------------------------------------------------------------------
--
-- A Joker the held Lost Soul could be spent on wears a pulsing white outline.
--
-- The outline is a sprite rather than a tint, and hollow rather than filled.
-- Balatro draws sprites through the dissolve shader, whose fragment stage
-- returns either the texture's own colours or a hardcoded black silhouette and
-- ignores the vertex colour entirely (resources/shaders/dissolve.fs), so
-- setColor cannot whiten anything drawn that way and a multiply tint could
-- only ever darken it. Drawn straight through draw_from instead - no shader -
-- where the colour IS honoured (engine/sprite.lua:157), which is also what
-- lets the pulse be an alpha.
--
-- Declared here rather than in the generated jokers/atlases.lua: that file is
-- one atlas per Joker face, and this sheet is not a face.
SMODS.Atlas { key = "lost_glow", path = "lost_glow.png", px = 71, py = 95 }
local GLOW_ATLAS = PREFIX .. "_lost_glow"

--- Radians a second the pulse runs at.
local PULSE = 3.4

-- One sprite shared by every glowing Joker, built on first use: the atlases do
-- not exist yet while this file is loading. Cryogen's ring is built the same
-- way, for the same reason.
local glow_sprite = nil

local function glow()
    if glow_sprite then return glow_sprite end
    local atlas = G.ASSET_ATLAS[GLOW_ATLAS]
    if not atlas then return nil end
    glow_sprite = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, { x = 0, y = 0 })
    return glow_sprite
end

local celesta_lost_draw_ref = Card.draw
function Card:draw(layer)
    celesta_lost_draw_ref(self, layer)

    -- Nothing to outline on the back of a card, and the shadow pass is the
    -- card's silhouette rather than its face.
    if layer == "shadow" or self.facing == "back" then return end
    if not (Lost.soul_held() and Lost.convertible(self)) then return end

    local sprite = glow()
    if not sprite then return end

    -- G.TIMERS.REAL rather than a per-card phase: every eligible Joker pulses
    -- in step, and a value carried on the card would be one more thing in the
    -- save that has to survive being sold and loaded.
    local pulse = 0.5 + 0.5 * math.sin(PULSE * G.TIMERS.REAL)
    local overlay = G.BRUTE_OVERLAY
    G.BRUTE_OVERLAY = { 1, 1, 1, 0.25 + 0.65 * pulse }
    -- Slightly larger than the card so the ring sits just outside its edge
    -- rather than on top of the border.
    sprite:draw_from(self.children.center, 0.04, 0)
    G.BRUTE_OVERLAY = overlay
end
