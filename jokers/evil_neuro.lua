--- EVIL NEURO, and the ritual that makes her.
---
--- Not in any pool. She is not bought, found or rolled - the only way to a
--- copy is the recipe below, so putting her in the shop would give the ritual
--- away and make it pointless.
---
--- THE RECIPE
---   * a Steel King of Hearts with a Red Seal, highlighted in hand
---   * a Neuro in the Joker row
---   * a Blank Joker in the row carrying at least the Gash and Bonus marks
---   * an Occult, used
---
--- The three ingredients are read off the board rather than all having to be
--- highlighted at once: a playing card and two Jokers live in different areas
--- and Balatro has no way to select across them. Highlighting the King is what
--- says "on these"; the Jokers only have to be present.
---
--- Nothing is consumed until the animation reaches the middle. If the run ends
--- between the two, the ingredients are all still there and only the Occult
--- was spent.

local Blank = CelestasMod.Blank

CelestasMod.EVIL_NEURO_KEY = "j_" .. SMODS.current_mod.prefix .. "_evil_neuro"

local NEURO_KEY = "j_" .. SMODS.current_mod.prefix .. "_neuro"
local OCCULT_KEY = "c_" .. SMODS.current_mod.prefix .. "_occult"

--- The marks the Blank Joker has to be carrying. "At least" - anything else it
--- has learned comes along for the ride.
local BLANK_MARKS = { "gash", "bonus" }

--------------------------------------------------------------------------------
-- Reading the board
--------------------------------------------------------------------------------

--- The Steel King of Hearts with a Red Seal, if one is highlighted.
---
--- Rank is asked through get_id like every other rank question in this mod.
--- Grandpaw Shao turns number cards into Aces rather than Kings, so he cannot
--- accidentally hand this a stand-in.
local function ritual_card()
    local picked = G.hand and G.hand.highlighted
    if not picked then return nil end
    for _, card in ipairs(picked) do
        if not card.debuff
            and SMODS.has_enhancement(card, "m_steel")
            and card.seal == "Red"
            and card.base and card.base.suit == "Hearts"
            and card.get_id and card:get_id() == 13 then
            return card
        end
    end
    return nil
end

--- The first Joker in the row matching `want`, ignoring debuffed ones.
local function find_joker(want)
    for _, joker in ipairs((G.jokers and G.jokers.cards) or {}) do
        if not joker.debuff and want(joker) then return joker end
    end
    return nil
end

--- A Blank Joker carrying every mark the recipe asks for.
local function ritual_blank()
    return find_joker(function(joker)
        if not Blank.is_blank(joker) then return false end
        for _, mark in ipairs(BLANK_MARKS) do
            if not Blank.has(joker, mark) then return false end
        end
        return true
    end)
end

--- The three ingredients, or nil when the board is not ready.
---
--- An Eternal ingredient refuses the whole thing rather than being spared:
--- Eternal means it cannot be destroyed, and a ritual that ate two of the
--- three and left the third would be worse than one that did not start.
local function ritual_parts()
    if not (G.hand and G.jokers) then return nil end

    local card = ritual_card()
    if not card then return nil end
    local neuro = find_joker(function(joker)
        local center = joker.config and joker.config.center
        return center and center.key == NEURO_KEY
    end)
    if not neuro then return nil end
    local blank = ritual_blank()
    if not blank then return nil end

    for _, part in ipairs({ card, neuro, blank }) do
        if SMODS.is_eternal and SMODS.is_eternal(part) then return nil end
    end

    return { card = card, neuro = neuro, blank = blank }
end

--- Is this consumable an Occult, aimed at a board that is ready?
local function occult_ritual(consumable)
    local config = consumable and consumable.config
    local key = config and (config.center_key
        or (config.center and config.center.key))
    if key ~= OCCULT_KEY then return nil end
    return ritual_parts()
end

--------------------------------------------------------------------------------
-- The animation
--------------------------------------------------------------------------------
--
-- The cards stay in the areas they are in. A Card is drawn by its CardArea and
-- by nothing else - Moveable:init only registers plain Moveables in
-- G.I.MOVEABLE, which is the list Game:draw walks for parentless things - so a
-- card pulled out of every area is simply invisible. Instead their transforms
-- are overwritten every frame, AFTER the game has finished its own update, so
-- what the areas laid out is what gets replaced rather than what fights back.
--
-- They ORBIT but do not turn: rotation is pinned to zero and the juice that
-- makes a card bob is cleared each frame. A card spinning on its own axis while
-- also going round the middle reads as a glitch rather than as a ritual.
--
-- The spiral is p^2 in both radius and angle: it starts where the cards are,
-- and both the closing and the spin accelerate into the middle.
--
-- The merge itself is start_dissolve in white, drawn out over a couple of
-- seconds. That is the game's own burn animation and it removes the card
-- properly on the way out - Card:remove takes it out of its area and calls
-- remove_from_deck - so the ball of light and the disposal are the same thing
-- rather than two that could disagree.

CelestasMod.EVIL_NEURO_SPIN = 3        -- turns each card makes on the way in
CelestasMod.EVIL_NEURO_TIME = 1.6      -- seconds from the edges to the middle
CelestasMod.EVIL_NEURO_BURN = 2.5      -- how much longer than usual they burn
CelestasMod.EVIL_NEURO_HOLD = 0.5      -- seconds she hangs in the middle
CelestasMod.EVIL_NEURO_DARK = 0.5      -- how far the whole screen is dimmed
CelestasMod.EVIL_NEURO_FADE = 0.4      -- seconds the dimming takes to arrive

local ritual = nil

-- LuaJIT's, which the game runs on, and the two-argument math.atan that
-- replaced it in 5.3. Written for both, or the suites cannot reach the funnel
-- at all - and an animation nothing can drive is an animation nothing checks.
local atan2 = math.atan2 or math.atan

--- Where a card has to be PUT to sit in the middle of the screen.
---
--- Vanilla's own answer for a card with no area to place it in is
--- `G.ROOM.T.w/2 - G.CARD_W/2` (common_events.lua:378) - the standard card
--- size, not the card's own width. A Joker's T.w is whatever its area last
--- scaled it to, so subtracting that puts it near the middle rather than in
--- it.
local function centre_for(card)
    local room = G.ROOM and G.ROOM.T
    if not room then return 0, 0 end
    local w = G.CARD_W or (card and card.T and card.T.w) or 0
    local h = G.CARD_H or (card and card.T and card.T.h) or 0
    return room.w / 2 - w / 2, room.h / 2 - h / 2
end

--- The middle itself, for working out where each card starts from.
local function room_centre()
    local room = G.ROOM and G.ROOM.T
    if not room then return 0, 0 end
    return room.w / 2, room.h / 2
end

--- Holds a card exactly where it is put, with no turn and no bob.
---
--- Both transforms, because VT eases toward T and would otherwise lag a frame
--- behind the spiral. `juice` is what Moveable:move_juice reads to make a card
--- pulse, and every one of these was juiced on its way in.
local function pin(card, x, y)
    -- A card with no transform is not one this can place. Every real Card has
    -- both; guarded because being handed something else must not take the
    -- frame down.
    if not (card and card.T and card.VT) then return end
    card.T.x, card.T.y, card.T.r = x, y, 0
    card.VT.x, card.VT.y, card.VT.r = x, y, 0
    card.juice = nil
end

--- Starts the funnel. The cards are not consumed here; that happens when it
--- lands, so an interrupted ritual costs nothing but the Occult.
local function ritual_begin(parts)
    local cx, cy = room_centre()
    local tracked = {}

    for _, card in ipairs({ parts.card, parts.neuro, parts.blank }) do
        local x = card.T.x + card.T.w / 2 - cx
        local y = card.T.y + card.T.h / 2 - cy
        tracked[#tracked + 1] = {
            card = card,
            angle = atan2(y, x),
            radius = math.sqrt(x * x + y * y),
        }
    end

    ritual = { parts = tracked, phase = "funnel", t = 0, dark = 0 }
    play_sound("timpani")
end

--- Everything the funnel is currently holding in place, so the darkening can
--- be drawn UNDER it and it can be drawn again on top.
function CelestasMod.evil_neuro_lit()
    if not ritual then return nil end
    local lit = {}
    for _, tracked in ipairs(ritual.parts) do
        if tracked.card and not tracked.card.REMOVED then
            lit[#lit + 1] = tracked.card
        end
    end
    if ritual.made and not ritual.made.REMOVED then
        lit[#lit + 1] = ritual.made
    end
    return lit, ritual.dark
end

--- The white ball. The cards burn for EVIL_NEURO_BURN times as long as the
--- game normally takes, because the merge is the moment and rushing it makes
--- the whole funnel look like a loading screen.
local function ritual_burn()
    -- Once. Called again on a card already dissolving it would start a second
    -- burn on it, which is what the error path below used to do.
    if ritual.burnt then return end
    ritual.burnt = true
    for _, tracked in ipairs(ritual.parts) do
        local card = tracked.card
        if card and not card.REMOVED and card.start_dissolve then
            card:start_dissolve({ G.C.WHITE }, nil, CelestasMod.EVIL_NEURO_BURN)
        end
    end
    play_sound("gold_seal", 0.9, 0.6)
end

--- What comes out of it. She is emplaced immediately, because a Card is drawn
--- by its area and nothing else - and then held in the middle by the same
--- transform override the ingredients were, until the hold is up.
local function ritual_reveal()
    if ritual.revealed then return end
    ritual.revealed = true
    if not (G.jokers and SMODS.create_card) then return end
    local made = SMODS.create_card {
        set = "Joker",
        key = CelestasMod.EVIL_NEURO_KEY,
        area = G.jokers,
        skip_materialize = true,
    }
    if not made then return end

    made:add_to_deck()
    G.jokers:emplace(made)
    made:juice_up(0.5, 0.8)
    play_sound("holo1", 1.1, 0.6)
    ritual.made = made
end

--- One frame. Returns true while there is still something to do.
local function ritual_step(dt)
    if not ritual then return false end

    ritual.t = ritual.t + dt
    -- The dimming arrives over EVIL_NEURO_FADE and stays up for the rest of it.
    ritual.dark = math.min(ritual.t / CelestasMod.EVIL_NEURO_FADE, 1)
        * CelestasMod.EVIL_NEURO_DARK

    if ritual.phase == "funnel" then
        local p = math.min(ritual.t / CelestasMod.EVIL_NEURO_TIME, 1)
        local eased = p * p

        for _, tracked in ipairs(ritual.parts) do
            local card = tracked.card
            if card and not card.REMOVED then
                local angle = tracked.angle
                    + eased * CelestasMod.EVIL_NEURO_SPIN * 2 * math.pi
                local radius = tracked.radius * (1 - eased)
                local mx, my = centre_for(card)
                pin(card,
                    mx + radius * math.cos(angle),
                    my + radius * math.sin(angle))
            end
        end

        if p < 1 then return true end
        ritual_burn()
        ritual.phase, ritual.t = "burning", 0
        return true
    end

    if ritual.phase == "burning" then
        -- Held in the middle while they burn, or the areas would pull what is
        -- left of them back into a row mid-dissolve.
        for _, tracked in ipairs(ritual.parts) do
            local card = tracked.card
            if card and not card.REMOVED then
                pin(card, centre_for(card))
            end
        end

        -- 0.6 is the game's own dissolve time, scaled by what we asked for.
        if ritual.t < 0.6 * CelestasMod.EVIL_NEURO_BURN then return true end
        ritual_reveal()
        ritual.phase, ritual.t = "holding", 0
        return true
    end

    -- holding: she hangs in the middle before the tray takes her.
    local made = ritual.made
    if made and not made.REMOVED then
        pin(made, centre_for(made))
    end
    if ritual.t < CelestasMod.EVIL_NEURO_HOLD then return true end

    ritual = nil
    return false
end

-- Driven from Game:update rather than from an event, because an event fires
-- between frames and this has to write the transforms every one of them. The
-- ref is called FIRST so the areas have already laid their cards out and this
-- is the last word before they are drawn.
local celesta_evil_update_ref = Game.update
function Game:update(dt, ...)
    celesta_evil_update_ref(self, dt, ...)

    if not ritual then return end
    local ok, err = pcall(ritual_step, dt)
    if not ok then
        -- A fault in the visuals must not cost the player the ritual: burn the
        -- ingredients and hand her over anyway, rather than leaving three
        -- cards spinning forever.
        CelestasMod.warn_once("evil_neuro_spiral",
            "Evil Neuro's funnel failed: " .. tostring(err))
        -- Finish what has not happened yet, and nothing that has. Both guard
        -- themselves, so this hands over the ritual whatever it faulted on.
        pcall(ritual_burn)
        pcall(ritual_reveal)
        ritual = nil
    end
end

--------------------------------------------------------------------------------
-- Dimming the board behind it
--------------------------------------------------------------------------------
--
-- Game:draw has already flushed its canvas to the screen and cleared the
-- shader by the time this runs, so a rectangle here lands on top of everything
-- in raw window pixels - the same seam arena/arena.lua tints the weather
-- through.
--
-- Which dims the ritual cards along with the board. That is deliberate, and it
-- is the second attempt: the first drew each card AGAIN on top of the
-- rectangle so it would stay lit, and a card drawn after love.graphics.origin
-- is drawn in a different transform from the one its CardArea used - so every
-- one of them got a second copy, offset to the left, carrying its own shadow
-- and jittering against the original. One honest wash over everything beats
-- three cards with doubles.
--
-- All of it is pcall'd. A ritual that looks wrong is a disappointment; a draw
-- that throws takes the frame, and every frame after it, with the game.

local celesta_evil_draw_ref = Game.draw
function Game:draw(...)
    celesta_evil_draw_ref(self, ...)

    local _, dark = CelestasMod.evil_neuro_lit()
    if not (dark and dark > 0) then return end

    local ok, err = pcall(function()
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setShader()
        love.graphics.setBlendMode("alpha")

        local w, h = love.graphics.getDimensions()
        love.graphics.setColor(0, 0, 0, dark)
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.pop()
    end)

    if not ok then
        CelestasMod.warn_once("evil_neuro_dark",
            "Evil Neuro's dimming failed: " .. tostring(err))
    end
end

--------------------------------------------------------------------------------
-- Spending the Occult on it
--------------------------------------------------------------------------------
--
-- Both hooks, for the same reason the Blank Joker wraps both: can_use_consumeable
-- decides whether USE lights up, use_consumeable is what it does. The ritual
-- makes an Occult usable even with no Spectral behind it, because what it is
-- about to do is not the Occult's usual job.

local celesta_evil_can_use_ref = Card.can_use_consumeable
function Card:can_use_consumeable(any_state, skip_check)
    if occult_ritual(self) then return true end
    return celesta_evil_can_use_ref(self, any_state, skip_check)
end

local celesta_evil_use_ref = Card.use_consumeable
function Card:use_consumeable(area, copier)
    local parts = occult_ritual(self)
    if not parts then
        return celesta_evil_use_ref(self, area, copier)
    end

    -- The Occult itself is removed by G.FUNCS.use_card once this returns, the
    -- same as on the vanilla path.
    if G.hand then G.hand:unhighlight_all() end
    ritual_begin(parts)
end

--------------------------------------------------------------------------------
-- Evil Neuro
--------------------------------------------------------------------------------
--
-- Two halves, and they are meant to be read together: she makes a two-card
-- hand score BOTH its cards, and then pays out on the two cards that scored.
--
-- "Score both of them" is answered through modify_scoring_hand, which is where
-- Steamodded asks whether a card the poker hand did not use should score
-- anyway - the same question Splash answers (overrides.lua:2491). Saying yes
-- there is what puts the second card in front of every other Joker too, rather
-- than only in front of this one.
--
-- The payout is a PERMUTATION, P(n, r) = n! / (n - r)!, of the bigger card's
-- chips over the smaller one's. That is the falling factorial n * (n-1) * ...
-- down r terms, which is what is computed - the two factorials it is written
-- as would both overflow long before their quotient did.
--
-- Chips are read the way scoring reads them: the rank's nominal value plus
-- get_chip_bonus, which is where a Bonus card's, a Milk Bottle's and any other
-- permanent upgrade all live.

--- What this card is worth in Chips, upgrades included.
local function chip_value(card)
    if not card then return 0 end
    local nominal = (card.base and card.base.nominal) or 0
    local bonus = card.get_chip_bonus and card:get_chip_bonus() or 0
    return nominal + bonus
end

-- Two cards of ten chips each is already 10!/0! - three and a half million.
-- The cap is on how many terms are multiplied, not on the answer: past it the
-- number is beyond anything a run can use, and the loop would only be spending
-- frames to say so.
CelestasMod.EVIL_NEURO_TERMS = 500

--- P(n, r), as the falling factorial. Talisman's big numbers when they are
--- there, since this leaves what a double can hold at about n = 20.
local function permutation(n, r)
    n, r = math.floor(n or 0), math.floor(r or 0)
    if n < 0 or r < 0 or r > n then return 0 end
    if r == 0 then return 1 end

    local total = to_big and to_big(1) or 1
    for i = 0, math.min(r, CelestasMod.EVIL_NEURO_TERMS) - 1 do
        total = total * (n - i)
    end
    return total
end

--- The two cards that were played, biggest first.
local function played_pair(context)
    local hand = context.full_hand or (G.play and G.play.cards) or {}
    if #hand ~= 2 then return nil end
    local a, b = chip_value(hand[1]), chip_value(hand[2])
    if a < b then a, b = b, a end
    return a, b
end

SMODS.Joker {
    key = "evil_neuro",
    atlas = "evil_neuro",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    -- Never offered. The recipe is the only way to one, and a copy in the shop
    -- would give it away.
    in_pool = function() return false end,

    config = { extra = { size = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.size } }
    end,

    calculate = function(self, card, context)
        -- Every played card scores, when there are exactly two of them.
        if context.modify_scoring_hand and not context.blueprint then
            local hand = context.full_hand or {}
            if #hand == card.ability.extra.size then
                return { add_to_hand = true }
            end
        end

        if context.joker_main then
            local greater, lesser = played_pair(context)
            if not greater then return end
            local chips = permutation(greater, lesser)
            if chips and chips ~= 0 and chips ~= 1 then
                return { chips = chips }
            end
        end
    end,
}
