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

local LOST_SOUL_KEY = "c_" .. PREFIX .. "_lost_soul"

--- A Joker key, from the bare name.
local function joker(name) return "j_" .. PREFIX .. "_" .. name end

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
    [joker("maya")] = joker("corrupt_maya"),
    [joker("berrycrepe")] = joker("blueberrypancake"),
    [joker("ironmouse")] = joker("iron_moose"),
    [joker("boosfer")] = joker("red_boosfer"),
    -- The first with a VANILLA base. Nothing here assumes a pair is this
    -- mod's own: the shop filler reads this table backwards and will hand out
    -- Mail-In Rebates as readily as Mayas.
    ["j_mail"] = joker("unwanted_rebate"),
    ["j_blueprint"] = joker("schematic"),
    ["j_turtle_bean"] = joker("navy_bean"),
    ["j_scary_face"] = joker("face"),
    ["j_hanging_chad"] = joker("error_missing_chad"),
    [joker("arielle")] = joker("elleira"),
}

--- The same table read the other way: which Joker a Corrupt one used to be.
--- Built rather than written out, so the pair above stays the single place a
--- conversion is declared.
Lost.BASE_OF = {}
for base, corrupt in pairs(Lost.CONVERSIONS) do Lost.BASE_OF[corrupt] = base end

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

--- True while a Lost Soul is somewhere the player can see it: the consumable
--- tray, or the booster pack open on screen.
---
--- The pack is where one is FIRST seen - the Lost Soul is a pack card, like
--- the Soul it comes with - and the moment the outline is worth anything is
--- the moment you are looking at the pack deciding whether to take it. The
--- Joker row sits above the pack and stays visible, so it can be read off
--- while the choice is still open.
---
--- G.pack_cards is not cleared when a pack closes: the area is marked REMOVED
--- and left in place, which is the test vanilla itself makes
--- (button_callbacks.lua:2022). Asking for the area alone would leave every
--- Joker outlined for the rest of the run after one Spectral pack.
function Lost.soul_present()
    local areas = { G.consumeables }
    if G.pack_cards and not G.pack_cards.REMOVED then
        areas[#areas + 1] = G.pack_cards
    end

    for _, area in ipairs(areas) do
        for _, card in ipairs((area and area.cards) or {}) do
            if card.config and card.config.center
                and card.config.center.key == LOST_SOUL_KEY then
                return true
            end
        end
    end
    return false
end

--- The name this went by when it only looked at the tray.
Lost.soul_held = Lost.soul_present

--- Turns `card` into its Lost version, in place.
---
--- The same card rather than a new one, so it keeps its slot, its edition, its
--- stickers and its sell value. set_ability is how every centre swap in the
--- game is done - it is what the enhancement Tarots and the Phoenix Egg use -
--- but it does NOT run either centre's add_to_deck or remove_from_deck, and
--- both of those matter here: the old Joker may have given the run something,
--- and the new one takes four Joker slots away. So they are called by hand,
--- in the order a sale-then-purchase would have done it.
--- Takes the lock and the "?" off a Lost centre the player has just made one
--- of, and off the card carrying it.
---
--- Both halves matter, and the second is the one that bites. An UNDISCOVERED
--- centre is exempted in the Joker row and the consumable tray, so a card you
--- own always draws as itself (card.lua:717). A LOCKED centre has no such
--- exemption (card.lua:720): left locked, the Joker you just made would sit in
--- your row as a padlock.
---
--- unlock_card and discover_card both refuse outright in a seeded or challenge
--- run (common_events.lua:1630, 1880), so the centre is opened here as well.
--- That may reach the profile on the next save_progress, which is a fair price:
--- a padlock where a Joker should be is the worse of the two.
local function reveal(center, card)
    if unlock_card then unlock_card(center) end
    if discover_card then discover_card(center) end
    center.unlocked, center.discovered = true, true

    -- Saved with the card (card.lua:4652), so a reload does not hide it again.
    card.bypass_lock = true
    card.bypass_discovery_center = true
    card.bypass_discovery_ui = true
    card.params = card.params or {}
    card.params.bypass_discovery_center = true
    card.params.bypass_discovery_ui = true
end

function Lost.convert(card)
    local key = Lost.CONVERSIONS[card.config.center.key]
    local center = key and G.P_CENTERS[key]
    if not center then return false end

    -- Before the swap, so the sprite it is given is its own rather than the
    -- lock: set_sprites reads both flags as it goes (card.lua:168).
    reveal(center, card)

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

--- The Joker every shop item is to become, or nil while the shop is free.
---
--- celesta_lost_shop says which. `true` means "whatever I used to be", which
--- is what four of the five want: Corrupt Maya fills the shop with Mayas and
--- BlueberryPancake with BerryCrepes. A KEY means that Joker instead, and
--- Unwanted Rebate names ITSELF - a shop of Jokers that cannot be sold and
--- take four slots each.
---
--- With two Corrupt Jokers on the board the leftmost wins, the way the Joker
--- row settles every other disagreement.
local function shop_filler()
    if not (G.jokers and G.jokers.cards) then return nil end
    for _, held in ipairs(G.jokers.cards) do
        if Lost.is_lost(held) then
            local center = held.config.center

            -- An enhancement instead of a Joker: Elleira fills the shop with
            -- Stone Cards rather than with copies of anything.
            local enhancement = center.celesta_lost_shop_enhancement
            if enhancement and G.P_CENTERS[enhancement] then
                return enhancement, "enhancement"
            end

            local declared = center.celesta_lost_shop
            if declared then
                local key = declared
                if key == true then key = Lost.BASE_OF[center.key] end
                if key and G.P_CENTERS[key] then return key, "joker" end
            end
        end
    end
    return nil
end

--- Makes `card` the Joker `key` names, whatever it was.
local function refill(card, key)
    local center = G.P_CENTERS[key]
    if not (card and center) then return end
    if card.config and card.config.center == center then return end

    -- Cleared before the swap: it is what create_shop_card_ui would otherwise
    -- read to decide this is a voucher.
    card.shop_voucher = nil

    -- A booster pack is built at 1.27 times card size (game.lua:3260), and
    -- set_ability restores a card's dimensions from original_T before it
    -- applies the new centre's own (card.lua:248) - so the pack's size would
    -- outlive the pack and leave a Joker sitting a quarter again too big.
    -- Corrected first, so set_ability copies the right numbers across and the
    -- set_sprites it schedules rebuilds the face to match. Only w and h:
    -- scale is 0.95 on every card in the game, boosters included
    -- (card.lua:61).
    if card.original_T then
        card.original_T.w, card.original_T.h = G.CARD_W, G.CARD_H
    end
    if card.T then card.T.w, card.T.h = G.CARD_W, G.CARD_H end
    if card.VT then card.VT.w, card.VT.h = G.CARD_W, G.CARD_H end

    card:set_ability(center, nil, true)
    card:set_cost()
end

--- Makes `card` a playing card carrying `enhancement`, whatever it was.
---
--- A shop CAN sell a playing card, which is what makes this possible at all:
--- vanilla's buy_from_shop has a branch for a card whose ability.set is
--- 'Default' or 'Enhanced' that puts it into the deck rather than the Joker
--- row (button_callbacks.lua), and create_shop_card_ui gives anything that is
--- neither a Voucher nor a Booster a plain Buy button
--- (UI_definitions.lua:824). So this is the swap above plus a FRONT: a
--- playing card needs a rank and a suit underneath the enhancement, and
--- set_base is what gives it one.
---
--- The front is rolled and then never looked at again, because a Stone Card
--- has neither rank nor suit to show. It is rolled rather than fixed so the
--- deck a shop of them builds is not fifty copies of the same card underneath.
---
--- The price looks after itself: set_ability takes base_cost from the centre's
--- own `cost` and falls back to 1 where there is none (card.lua:213), which an
--- enhancement has - so a Stone Card is the cheapest thing the shop can sell.
local function refill_playing(card, enhancement)
    local center = G.P_CENTERS[enhancement]
    if not (card and center) then return end
    if card.config and card.config.center == center and card.base then return end

    card.shop_voucher = nil
    if card.original_T then
        card.original_T.w, card.original_T.h = G.CARD_W, G.CARD_H
    end
    if card.T then card.T.w, card.T.h = G.CARD_W, G.CARD_H end
    if card.VT then card.VT.w, card.VT.h = G.CARD_W, G.CARD_H end

    card:set_base(pseudorandom_element(G.P_CARDS, pseudoseed("celesta_elleira")))
    card:set_ability(center, nil, true)
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
        local key, kind = shop_filler()
        if key and kind == "enhancement" then
            refill_playing(card, key)
        elseif key then
            refill(card, key)
        end
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
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes. See reveal() below.
    unlocked = false,
    discovered = false,
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

    -- Which of the numbers loc_vars hands back is a retrigger count, so the
    -- tooltip shows the capped one. See VEDAL_REPETITION_CAP.
    celesta_repetition_vars = { 2 },

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
-- BlueberryPancake
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "blueberrypancake",
    atlas = "blueberrypancake",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes. See reveal() below.
    unlocked = false,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    in_pool = function() return false end,

    -- The three flags, as on Corrupt Maya above, where what each one does is
    -- written out.
    celesta_no_bind = true,
    celesta_lost = true,
    celesta_lost_shop = true,

    config = { extra = { mult_gain = 66.6, joker_slots = 4 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return { vars = { extra.mult_gain, extra.joker_slots } }
    end,

    add_to_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, -card.ability.extra.joker_slots)
        retake_shop()
    end,

    remove_from_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, card.ability.extra.joker_slots)
    end,

    calculate = function(self, card, context)
        -- BerryCrepe's own pass, at sixty-six and a half times the number.
        -- perma_mult is scored by Card:get_chip_mult and printed on the card
        -- automatically as "+N Mult", so no display work is needed.
        if context.individual and context.cardarea == G.play then
            local other = context.other_card
            if not other then return end
            other.ability.perma_mult = (other.ability.perma_mult or 0)
                + card.ability.extra.mult_gain
            return {
                extra = {
                    message = localize {
                        type = "variable",
                        key = "a_mult",
                        vars = { other.ability.perma_mult },
                    },
                    colour = G.C.MULT,
                },
                card = other,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Iron Moose
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "iron_moose",
    atlas = "iron_moose",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes. See reveal() below.
    unlocked = false,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    in_pool = function() return false end,

    -- The three flags, as on Corrupt Maya above, where what each one does is
    -- written out.
    celesta_no_bind = true,
    celesta_lost = true,
    celesta_lost_shop = true,

    config = { extra = { e_mult = 1.666, joker_slots = 4 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return { vars = { extra.e_mult, extra.joker_slots } }
    end,

    add_to_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, -card.ability.extra.joker_slots)
        retake_shop()
    end,

    remove_from_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, card.ability.extra.joker_slots)
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            -- ^Mult is Talisman's, and Talisman is a declared dependency of
            -- this mod - but a run without it should say so rather than
            -- silently score nothing. XM-05 Thanatos checks the same way.
            if Card.get_chip_e_mult == nil then
                CelestasMod.warn_once("iron_moose_no_talisman",
                    "Iron Moose scores ^Mult, which needs Talisman; "
                    .. "without it the Joker does nothing")
                return
            end
            return { e_mult = card.ability.extra.e_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Red Boosfer
--------------------------------------------------------------------------------
--
-- Three things at once, and the order they happen in is the whole card.
--
-- THE CONVERSION runs at context.before, and it runs SYNCHRONOUSLY. That is
-- not a style choice: context.before is raised part-way through
-- G.FUNCS.evaluate_play, and the rest of that function - naming the hand,
-- every card's chips, every suit check a Joker or a Blind makes - runs before
-- it returns. An event queued here would not run until the next frame, and the
-- hand that triggered it would already have scored as it was. Only the juice
-- is queued, which is vanilla's Midas Mask shape. jokers/implemented.lua says
-- the same thing at greater length above convert_scoring_to.
--
-- CelestasMod.unjudged is what makes converting a PLAYED card safe. Card:
-- set_base ends by asking the Blind to judge the card again, and The Pillar
-- debuffs anything carrying ability.played_this_ante - a flag every card in
-- the hand was given moments before evaluate_play ran. Vanilla never
-- re-judges a card mid-hand so it never notices; this does. Cards in hand
-- were not played and need none of that.

--- True when a card counts as a Star. is_suit rather than reading base.suit,
--- so a Wild card is a Star like every other suit check in the game sees it.
local function is_star(other_card)
    return other_card ~= nil and other_card.is_suit ~= nil
        and other_card:is_suit(CelestasMod.STARS_SUIT)
end

--- Turns one card into a Star, or reports that there was nothing to turn.
---
--- A card with no suit is left alone. Stone Cards and this mod's Limestone
--- report through has_no_suit, and handing them a suit is handing them
--- something they are not supposed to have.
local function starify(target, played)
    if SMODS.has_no_suit(target) then return false end
    if target:is_suit(CelestasMod.STARS_SUIT) then return false end

    if played then
        CelestasMod.unjudged(target, function()
            SMODS.change_base(target, CelestasMod.STARS_SUIT)
        end)
    else
        SMODS.change_base(target, CelestasMod.STARS_SUIT)
    end

    G.E_MANAGER:add_event(Event {
        func = function() target:juice_up() return true end
    })
    return true
end

SMODS.Joker {
    key = "red_boosfer",
    atlas = "red_boosfer",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes. See reveal() below.
    unlocked = false,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    in_pool = function() return false end,

    -- The three flags, as on Corrupt Maya above, where what each one does is
    -- written out.
    celesta_no_bind = true,
    celesta_lost = true,
    celesta_lost_shop = true,

    config = { extra = { repetitions = 2, e_mult = 1, e_mult_gain = 0.06,
                         joker_slots = 4 } },

    -- Which of the numbers loc_vars hands back is a retrigger count, so the
    -- tooltip shows the capped one. See VEDAL_REPETITION_CAP.
    celesta_repetition_vars = { 2 },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR, true)
        return { vars = { name, extra.repetitions, extra.e_mult_gain,
                          extra.e_mult, extra.joker_slots,
                          colours = { colour } } }
    end,

    add_to_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, -card.ability.extra.joker_slots)
        retake_shop()
    end,

    remove_from_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, card.ability.extra.joker_slots)
    end,

    calculate = function(self, card, context)
        ------------------------------------------------------------------
        -- Everything becomes a Star
        ------------------------------------------------------------------
        if context.before and not context.blueprint then
            local changed = 0
            for _, played in ipairs(context.full_hand or {}) do
                if starify(played, true) then changed = changed + 1 end
            end
            for _, held in ipairs((G.hand and G.hand.cards) or {}) do
                if starify(held, false) then changed = changed + 1 end
            end
            if changed > 0 then
                return {
                    message = localize("celesta_starred"),
                    colour = G.C.FILTER,
                    card = card,
                }
            end
            return
        end

        ------------------------------------------------------------------
        -- Every Star triggers again, and pays for doing so
        ------------------------------------------------------------------
        if context.repetition and is_star(context.other_card)
            and (context.cardarea == G.play or context.cardarea == G.hand) then
            local extra = card.ability.extra

            -- The exponent is raised once per RETRIGGER, not once per card:
            -- this pass is raised a single time and hands back how many extra
            -- triggers to run, so the whole lot is banked here.
            if not context.blueprint then
                extra.e_mult = extra.e_mult + extra.e_mult_gain * extra.repetitions
            end

            return {
                message = localize("k_again_ex"),
                repetitions = extra.repetitions,
                card = card,
            }
        end

        ------------------------------------------------------------------
        -- ...and then it scores
        ------------------------------------------------------------------
        if context.joker_main and card.ability.extra.e_mult > 1 then
            -- ^Mult is Talisman's, and Talisman is a declared dependency of
            -- this mod - but a run without it should say so rather than
            -- silently score nothing. Iron Moose checks the same way.
            if Card.get_chip_e_mult == nil then
                CelestasMod.warn_once("red_boosfer_no_talisman",
                    "Red Boosfer scores ^Mult, which needs Talisman; "
                    .. "without it the Joker does nothing")
                return
            end
            return { e_mult = card.ability.extra.e_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Unwanted Rebate
--------------------------------------------------------------------------------
--
-- Mail-In Rebate pays for one rank, chosen fresh each round
-- (G.GAME.current_round.mail_card). This one pays for sixes and only sixes,
-- and pays $6.66 a card - which is not a whole number, and is not meant to be.
-- ease_dollars takes it as given, so the run's money goes fractional and stays
-- that way; three sixes is $19.98.
--
-- A debuffed card is not counted, which is vanilla's own test in the same
-- place (card.lua:3164): the Blind has taken the card's rank away, so there is
-- no six there to pay for.
SMODS.Joker {
    key = "unwanted_rebate",
    atlas = "unwanted_rebate",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes. See reveal() below.
    unlocked = false,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    in_pool = function() return false end,

    -- The three flags, as on Corrupt Maya above, where what each one does is
    -- written out - except that this one names the Joker its shop fills with
    -- rather than taking the default. It is ITSELF: a shop of cards that
    -- cannot be sold and take four Joker slots each.
    celesta_no_bind = true,
    celesta_lost = true,
    celesta_lost_shop = "j_" .. PREFIX .. "_unwanted_rebate",

    config = { extra = { dollars = 6.66, rank = 6, joker_slots = 4 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return { vars = { extra.dollars, extra.rank, extra.joker_slots } }
    end,

    add_to_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, -card.ability.extra.joker_slots)
        retake_shop()
    end,

    remove_from_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, card.ability.extra.joker_slots)
    end,

    calculate = function(self, card, context)
        if context.discard and context.other_card
            and not context.other_card.debuff
            and context.other_card.get_id
            and context.other_card:get_id() == card.ability.extra.rank then
            return { dollars = card.ability.extra.dollars, card = card }
        end
    end,
}

--------------------------------------------------------------------------------
-- Schematic
--------------------------------------------------------------------------------
--
-- Blueprint copies the Joker to its right. This one makes every Joker to its
-- right go again, twice.
--
-- The ONLY Corrupt Joker that leaves the run's shape alone: no Joker slots
-- taken, no shop held shut. It carries celesta_lost, which is what makes it
-- unsellable and draws its description inverted, and nothing else - so it has
-- no celesta_lost_shop and no joker_slots at all rather than a zero, because
-- a zero would still be a number somebody could scale.
--
-- retrigger_joker_check is asked of every Joker about every OTHER Joker, and
-- about itself, so the answer has to name who it is being asked about. Ray
-- guards that with an explicit `other_card ~= card`; here the position test
-- already says it - a card is never further along the row than itself - so
-- adding the guard as well would be a branch that can never be taken, and a
-- negative test aimed at it could never fail.
--
-- Steamodded only runs that pass at all when a loaded mod has asked for it,
-- which main.lua does through optional_features.retrigger_joker; Ray is why
-- that is already on.

--- Where `card` sits in the Joker row, or nil if it is not in it.
local function row_index(card)
    if not (G.jokers and G.jokers.cards) then return nil end
    for i, held in ipairs(G.jokers.cards) do
        if held == card then return i end
    end
    return nil
end

SMODS.Joker {
    key = "schematic",
    atlas = "schematic",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes. See reveal() below.
    unlocked = false,
    discovered = false,
    -- A copy of a Joker that retriggers Jokers is a knot; Blueprint itself is
    -- blueprint_compat = false for the same reason.
    blueprint_compat = false,
    eternal_compat = true,

    in_pool = function() return false end,

    celesta_no_bind = true,
    celesta_lost = true,

    config = { extra = { repetitions = 2 } },

    -- Which of the numbers loc_vars hands back is a retrigger count, so the
    -- tooltip shows the capped one. See VEDAL_REPETITION_CAP.
    celesta_repetition_vars = { 1 },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        if context.retrigger_joker_check and context.other_card then
            local mine = row_index(card)
            local theirs = row_index(context.other_card)
            -- To the RIGHT: further along the row than this card. Both have to
            -- be in it - a Joker being evaluated from somewhere else is not to
            -- anyone's right.
            if mine and theirs and theirs > mine then
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
-- Navy Bean
--------------------------------------------------------------------------------
--
-- Turtle Bean gives five cards of hand size and takes one back every round.
-- This one gives six and keeps them.
--
-- The hand size is applied HERE rather than left to vanilla. Turtle Bean's is
-- granted by a branch of Card:add_to_deck that tests ability.name
-- (card.lua:778), and after the conversion the name is no longer Turtle
-- Bean's - so nothing in the game would apply it. A centre's own add_to_deck
-- and remove_from_deck are the supported way to say it, and they cover
-- selling, debuffing and destroying without another hook.
--
-- Not written to ability.h_size, which is the OTHER way a Joker can carry a
-- hand size - vanilla reads that field directly and would then apply it as
-- well as this, twice over. Turtle Bean keeps its number in extra for the
-- same reason.
SMODS.Joker {
    key = "navy_bean",
    atlas = "navy_bean",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes. See reveal() below.
    unlocked = false,
    discovered = false,
    -- Half of it is a passive nothing can copy, which is why vanilla's Turtle
    -- Bean refuses a copy too.
    blueprint_compat = false,
    eternal_compat = true,

    in_pool = function() return false end,

    celesta_no_bind = true,
    celesta_lost = true,
    -- Itself, the way Unwanted Rebate does: a shop of Jokers that cannot be
    -- sold and take four slots each.
    celesta_lost_shop = "j_" .. PREFIX .. "_navy_bean",

    config = { extra = { h_size = 6, joker_slots = 4 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return { vars = { extra.h_size, extra.joker_slots } }
    end,

    add_to_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, -card.ability.extra.joker_slots)
        retake_shop()
        if G.hand then G.hand:change_size(card.ability.extra.h_size) end
    end,

    remove_from_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, card.ability.extra.joker_slots)
        if G.hand then G.hand:change_size(-card.ability.extra.h_size) end
    end,
}

--------------------------------------------------------------------------------
-- face
--------------------------------------------------------------------------------
--
-- Scary Face, corrupted. +30 Chips a face card becomes +66.6 - fractional on
-- purpose, the way Unwanted Rebate's $6.66 is.
--
-- Its name is lowercase, and that needs nothing special: Balatro prints the
-- localization string as it is written, and does not case it either way.
--
-- Card:is_face is the whole test and is asked rather than reimplemented. It
-- already refuses a debuffed card (card.lua:1159) and already says yes to
-- every card while Pareidolia is out (card.lua:1163) - two rules that would
-- have to be remembered separately if the rank were compared by hand.
SMODS.Joker {
    key = "face",
    atlas = "face",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes. See reveal() below.
    unlocked = false,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    in_pool = function() return false end,

    celesta_no_bind = true,
    celesta_lost = true,
    celesta_lost_shop = "j_" .. PREFIX .. "_face",

    config = { extra = { chips = 66.6, joker_slots = 4 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return { vars = { extra.chips, extra.joker_slots } }
    end,

    add_to_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, -card.ability.extra.joker_slots)
        retake_shop()
    end,

    remove_from_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, card.ability.extra.joker_slots)
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and context.other_card and context.other_card.is_face
            and context.other_card:is_face() then
            return { chips = card.ability.extra.chips,
                     card = context.other_card }
        end
    end,
}

--------------------------------------------------------------------------------
-- ERROR:missing_chad.exe
--------------------------------------------------------------------------------
--
-- Hanging Chad retriggers the first scoring card twice more; this does it six
-- times.
--
-- "The first played card" is the first card of the SCORING hand, which is
-- what Hanging Chad means by it - its own description says "first played card
-- used in scoring". A five-card hand that makes a Pair starts scoring at the
-- Pair, not at whatever was leftmost. Spongey in jokers/implemented.lua tests
-- the same thing against the LAST entry and says so there.
--
-- The name is punctuation and mixed case, and neither needs anything: Balatro
-- prints the localization string exactly as written. The KEY cannot be, so it
-- is error_missing_chad - keys are lowercase and underscored throughout this
-- mod, and nothing player-facing reads them.
SMODS.Joker {
    key = "error_missing_chad",
    atlas = "error_missing_chad",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes. See reveal() below.
    unlocked = false,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    in_pool = function() return false end,

    celesta_no_bind = true,
    celesta_lost = true,
    celesta_lost_shop = "j_" .. PREFIX .. "_error_missing_chad",

    config = { extra = { repetitions = 6, joker_slots = 4 } },

    -- Which of the numbers loc_vars hands back is a retrigger count, so the
    -- tooltip shows the capped one. See VEDAL_REPETITION_CAP.
    celesta_repetition_vars = { 1 },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return { vars = { extra.repetitions, extra.joker_slots } }
    end,

    add_to_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, -card.ability.extra.joker_slots)
        retake_shop()
    end,

    remove_from_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, card.ability.extra.joker_slots)
    end,

    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play
            and context.scoring_hand
            and context.other_card == context.scoring_hand[1] then
            return {
                message = localize("k_again_ex"),
                repetitions = card.ability.extra.repetitions,
                card = card,
            }
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
-- Elleira
--------------------------------------------------------------------------------
--
-- Arielle, corrupted, and it is her own rule read backwards. Arielle widens
-- the question "is this card that suit?" until every card answers yes to every
-- suit; Elleira narrows it until every card answers no to all of them, which
-- is the same sentence from the other side: if no card shares a suit with any
-- other, nothing is ever a Flush, and no suit named by a Joker, a Blind or a
-- seal finds anything to name.
--
-- Hooked on Card:is_suit rather than on SMODS.smeared_check, where Arielle
-- sits. smeared_check only decides whether two DIFFERENT suits are to count as
-- one; turning it off would still leave two Hearts as two Hearts.
local ELLEIRA_KEY = "j_" .. PREFIX .. "_elleira"

--- Walked by hand rather than through find_joker: is_suit is asked of every
--- card in every hand the game scores, several times over, and find_joker
--- builds a table on each call.
local function elleira_out()
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        local center = held.config and held.config.center
        if center and center.key == ELLEIRA_KEY and not held.debuff then
            return true
        end
    end
    return false
end

local celesta_elleira_is_suit_ref = Card.is_suit
function Card:is_suit(suit, bypass_debuff, flush_calc)
    if elleira_out() then return false end
    return celesta_elleira_is_suit_ref(self, suit, bypass_debuff, flush_calc)
end

SMODS.Joker {
    key = "elleira",
    atlas = "elleira",
    pos = { x = 0, y = 0 },

    rarity = LOST_RARITY,
    cost = 20,
    -- Hidden in the collection until one has been made, and locked rather
    -- than merely undiscovered: a locked centre is the one the game will
    -- print a per-card reason for (card.lua:720 beats 723), which is where
    -- "use a Lost Soul on <Joker>" goes.
    unlocked = false,
    discovered = false,
    -- The suit rule is not an effect a copy could return, and the slots are a
    -- passive; there is nothing here for a Blueprint to copy.
    blueprint_compat = false,
    eternal_compat = true,

    in_pool = function() return false end,

    celesta_no_bind = true,
    celesta_lost = true,
    -- Not a Joker: a shop of Stone Cards. See refill_playing above.
    celesta_lost_shop_enhancement = "m_stone",

    config = { extra = { joker_slots = 4 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_stone
        return { vars = { card.ability.extra.joker_slots } }
    end,

    add_to_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, -card.ability.extra.joker_slots)
        retake_shop()
    end,

    remove_from_deck = function(self, card, from_debuff)
        bump_limit(G.jokers, card.ability.extra.joker_slots)
    end,
}

--------------------------------------------------------------------------------
-- The glow
--------------------------------------------------------------------------------
--
-- A Joker the held Lost Soul could be spent on wears a white outline.
--
-- The outline is a sprite rather than a tint, and hollow rather than filled.
-- Balatro draws sprites through the dissolve shader, whose fragment stage
-- returns either the texture's own colours or a hardcoded black silhouette and
-- ignores the vertex colour entirely (resources/shaders/dissolve.fs), so
-- setColor cannot whiten anything drawn that way and a multiply tint could
-- only ever darken it. The sheet is therefore white to begin with, and it is
-- drawn plainly over the card - no tint, no fade, no animation. It says which
-- Jokers the Soul can be spent on and nothing else.
--
-- Declared here rather than in the generated jokers/atlases.lua: that file is
-- one atlas per Joker face, and this sheet is not a face.
SMODS.Atlas { key = "lost_glow", path = "lost_glow.png", px = 71, py = 95 }
local GLOW_ATLAS = PREFIX .. "_lost_glow"

--- How far outside the card the outline sits, as a fraction of the card -
--- which is what draw_shader's `ms` is. Constant: the outline is a flag
--- saying "this one", and a flag does not need to move to be read.
local GLOW_OUTSET = 0.05

-- One sprite shared by every glowing Joker, built on first use: the atlases do
-- not exist yet while this file is loading. Cryogen's ring is built the same
-- way, for the same reason.
local glow_sprite = nil

local function glow()
    if glow_sprite then return glow_sprite end
    local atlas = G.ASSET_ATLAS[GLOW_ATLAS]
    if not atlas then
        -- Silently drawing nothing is how this went unnoticed: the outline is
        -- the only thing that says a Joker can be spent on, and a missing
        -- sheet looks exactly like a Joker that cannot.
        CelestasMod.warn_once("lost_glow_atlas",
            ("The Lost Soul glow sheet %s is not loaded, so convertible "
             .. "Jokers will not outline"):format(GLOW_ATLAS))
        return nil
    end
    glow_sprite = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, { x = 0, y = 0 })
    return glow_sprite
end

local celesta_lost_draw_ref = Card.draw
function Card:draw(layer)
    celesta_lost_draw_ref(self, layer)

    -- Nothing to outline on the back of a card, and the shadow pass is the
    -- card's silhouette rather than its face.
    if layer == "shadow" or self.facing == "back" then return end
    if not (Lost.soul_present() and Lost.convertible(self)) then return end

    local sprite = glow()
    if not sprite then return end

    -- Through draw_shader, which is how every other overlay in this mod is
    -- drawn: Cryogen's ring, Thanatos' wide sheet, the frost pane, Exo's
    -- frame. draw_from is the layer underneath it (engine/sprite.lua:180) and
    -- the game never calls it on its own - draw_shader sets the shader and
    -- the draw_major the transform is built from, then calls it. Called cold
    -- it drew nothing at all, which is exactly what the outline did.
    sprite.role.draw_major = self
    sprite:draw_shader("dissolve", nil, nil, nil, self.children.center,
                       GLOW_OUTSET, 0)
end
