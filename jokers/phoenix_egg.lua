--- BLESSED PHOENIX EGG
---
--- A Spectral card that is not used, but PULLED: it moves into the Joker row
--- and sits there counting rounds. After seven it is ready, and spending a Soul
--- while it is ready hatches it into Yharon - which is now the only way to get
--- one at all.
---
--- Two objects, not one. The thing in a Spectral pack is a Consumable and the
--- thing in the Joker row is a Joker, because those are two different areas
--- with two different sets of rules about what may sit in them - what can be
--- sold, what a Blind may debuff, what a Joker slot counts. They share a name,
--- an atlas and a description, so it reads as one card moving; underneath, the
--- Spectral is spent and the Joker is created.
---
--- Its own file for the usual reason: it wraps two globals at load, and
--- jokers/implemented.lua is sliced apart and run against stubs by the test
--- harnesses.

local EGG_JOKER_KEY = "j_" .. SMODS.current_mod.prefix .. "_blessed_phoenix_egg"
local EGG_CARD_KEY = "c_" .. SMODS.current_mod.prefix .. "_blessed_phoenix_egg"
local YHARON_KEY = "j_" .. SMODS.current_mod.prefix .. "_yharon"
local SOUL_KEY = "c_soul"

--- Rounds it has to sit through.
local ROUNDS = 7

--- True when the run has banned the Joker the Spectral turns into.
local function egg_banned()
    local banned = G.GAME and G.GAME.banned_keys
    return (banned and banned[EGG_JOKER_KEY]) and true or false
end

--------------------------------------------------------------------------------
-- The Spectral
--------------------------------------------------------------------------------
--
-- `hidden` is what puts it on the same roll as Black Hole rather than in the
-- ordinary Spectral pool: Steamodded reads that flag and adds the card to
-- SMODS.Consumable.legendaries with a soul_set and a soul_rate
-- (game_object.lua:1282). Both are spelled out below rather than left to the
-- defaults, because they ARE the answer to "as often as a Black Hole" - the
-- 0.003 and the Spectral pack are exactly what vanilla rolls for that card
-- (common_events.lua:2469).

SMODS.Consumable {
    key = "blessed_phoenix_egg",
    set = "Spectral",
    atlas = "blessed_phoenix_egg",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    hidden = true,
    soul_set = "Spectral",
    soul_rate = 0.003,

    -- Pulling it makes the Joker, so it only turns up in a run where that Joker is allowed.
    -- The Soul-type roll asks nothing but this: a ban on the Joker does not stop it, and the
    -- Pull then asked for a banned Joker and was given a different one - Nekrolina, on the
    -- Purple challenge. The colour challenges ban every Joker they do not list, so the egg
    -- is left to the Orange one that lists it.
    in_pool = function(self, args)
        return not egg_banned()
    end,

    loc_vars = function(self, info_queue, card)
        return { vars = { ROUNDS } }
    end,

    -- Ours because it has to be: Steamodded routes can_use_consumeable through
    -- the centre, and vanilla's chain of name checks ends in `return false` for
    -- a key it does not recognise, which would grey the button out forever.
    --
    -- Room in the Joker row is the whole condition. Asked the way every vanilla
    -- source asks it, buffer included, so two things creating a Joker in the
    -- same breath cannot both claim the last slot.
    can_use = function(self, card)
        if not (G.jokers and G.jokers.config) then return false end
        if egg_banned() then return false end
        return #G.jokers.cards + (G.GAME.joker_buffer or 0)
            < G.jokers.config.card_limit
    end,

    use = function(self, card, area, copier)
        -- Reserved across the event boundary: the Joker is created a frame
        -- later, and the slot has to be spoken for until it is.
        G.GAME.joker_buffer = (G.GAME.joker_buffer or 0) + 1

        G.E_MANAGER:add_event(Event {
            trigger = "before",
            delay = 0.0,
            func = function()
                local egg = SMODS.create_card {
                    set = "Joker",
                    key = EGG_JOKER_KEY,
                    area = G.jokers,
                    skip_materialize = true,
                }
                G.GAME.joker_buffer = math.max((G.GAME.joker_buffer or 1) - 1, 0)
                if not egg then return true end

                egg:add_to_deck()
                G.jokers:emplace(egg)
                egg:start_materialize()
                return true
            end,
        })
    end,
}

--------------------------------------------------------------------------------
-- The egg in the row
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "blessed_phoenix_egg",
    atlas = "blessed_phoenix_egg",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    -- Nothing to copy: it counts rounds and then stops being itself.
    blueprint_compat = false, eternal_compat = true,

    -- Never offered. The Spectral is the only way one arrives, and a copy in
    -- the shop would be a seven-round wait somebody could buy past.
    in_pool = function() return false end,

    config = { extra = { rounds = 0, needed = ROUNDS } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return {
            -- A second description rather than a line that appears and
            -- disappears: Steamodded takes the whole entry from `key`, so the
            -- ready card and the waiting one are two texts that can each read
            -- properly instead of one with a hole in it.
            key = extra.rounds >= extra.needed
                and "j_celesta_blessed_phoenix_egg_ready" or nil,
            vars = { extra.rounds, extra.needed },
        }
    end,

    calculate = function(self, card, context)
        -- main_eval keeps this to once per round rather than once per Joker
        -- evaluated during the end-of-round pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            local extra = card.ability.extra
            if extra.rounds >= extra.needed then return end

            extra.rounds = extra.rounds + 1

            -- A Favor Stamp hatches it the round it is ready, with no Soul to spend.
            if extra.rounds >= extra.needed and CelestasMod.favored
                and CelestasMod.favored(card) and CelestasMod.egg_hatch then
                CelestasMod.egg_hatch(card)
            end
            return {
                message = extra.rounds .. "/" .. extra.needed,
                colour = G.C.FILTER,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Hatching
--------------------------------------------------------------------------------

--- The first egg in the row that has finished counting.
local function ready_egg()
    for _, found in ipairs(CelestasMod.find_joker(EGG_JOKER_KEY)) do
        local extra = found.ability and found.ability.extra
        if extra and (extra.rounds or 0) >= (extra.needed or ROUNDS) then
            return found.card
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Souls come easier once an egg is ready
--------------------------------------------------------------------------------
--
-- A ready egg needs a Soul and can do nothing else, so while one is waiting
-- The Soul turns up half again as often: 0.003 becomes 0.0045.
--
-- Done as a SECOND, independent roll rather than by moving vanilla's number,
-- because vanilla's number is a literal inside create_card
-- (common_events.lua:2424) with no hook near it - reaching it would mean a
-- Lovely patch on a block Steamodded has already rewritten, which is a
-- fragile thing to own for one constant. Two independent rolls at 0.003 and
-- 0.0015 come to 1 - 0.997*0.9985 = 0.0044955, which is the 0.0045 asked for
-- to within a twentieth of a percent.
--
-- The extra roll draws on a stream of its own, so every other pseudorandom
-- decision in a seeded run falls exactly where it did before.
--
-- Setting forced_key skips the rest of create_card's soul block, the modded
-- souls included - the same thing vanilla's own hit does. It costs the other
-- souls a roll on 0.15% of the cards that could have carried one, which is
-- around four in a million.

--- The extra roll's threshold: half of vanilla's 0.003, over the line.
local EXTRA_SOUL_RATE = 0.0015

local celesta_egg_create_ref = create_card

if celesta_egg_create_ref then
    function create_card(_type, area, legendary, _rarity, skip_materialize,
                         soulable, forced_key, key_append)
        -- Cheapest checks first: this function runs for every card the game
        -- makes, and the board scan is the expensive part.
        if soulable and not forced_key
            and (_type == "Tarot" or _type == "Spectral"
                 or _type == "Tarot_Planet")
            and G.GAME and not (G.GAME.banned_keys or {})[SOUL_KEY]
            -- The same two conditions vanilla puts on its own roll: a Soul
            -- already used this run does not come back without a Showman.
            and not ((G.GAME.used_jokers or {})[SOUL_KEY]
                     and not SMODS.showman(SOUL_KEY))
            and ready_egg() then
            local roll = pseudorandom("celesta_egg_soul_" .. _type
                .. ((G.GAME.round_resets or {}).ante or 0))
            if roll > 1 - EXTRA_SOUL_RATE then forced_key = SOUL_KEY end
        end

        return celesta_egg_create_ref(_type, area, legendary, _rarity,
            skip_materialize, soulable, forced_key, key_append)
    end
end

--------------------------------------------------------------------------------
-- Hatching, continued
--------------------------------------------------------------------------------

--- Turns `egg` into Yharon in place.
---
--- The same card rather than a new one: it keeps its slot in the row, its
--- edition, its stickers and its sell value, which is what "the card turns
--- into Yharon" says. set_ability is how every centre swap in the game is
--- done, and it is what Camila and the enhancement Tarots use.
local function hatch(egg)
    local yharon = G.P_CENTERS[YHARON_KEY]
    if not (egg and yharon) then return end

    G.E_MANAGER:add_event(Event {
        trigger = "after",
        delay = 0.4,
        func = function()
            -- Card:add_to_deck is where an arriving Joker is discovered
            -- (card.lua:735), and an in-place swap never runs it. discover_card
            -- refuses in a seeded or challenge run, so the centre is marked as
            -- well - an undiscovered card in the row still draws as itself, so
            -- this is only for the Collection.
            if not yharon.discovered then
                if discover_card then discover_card(yharon) end
                yharon.discovered = true
            end
            egg:set_ability(yharon, nil, true)
            egg:juice_up(0.5, 0.6)
            -- set_ability does not run the centre's add_to_deck, which is
            -- where a Joker announces itself. This is the one arrival that
            -- happens without one.
            if CelestasMod.play_join_sound then
                CelestasMod.play_join_sound(YHARON_KEY)
            end
            return true
        end,
    })
end

--- Hatches an egg that is the card itself. Not one that is merged into another Joker: that
--- card is somebody else's, and turning it into Yharon would take the host with it.
---
--- Exported for the Favor Stamp, which hatches a ready egg without a Soul.
function CelestasMod.egg_hatch(card)
    local Bind = CelestasMod.Bind
    if Bind and Bind.lent and Bind.lent[card] then return end
    local center = card and card.config and card.config.center
    if not (center and center.key == EGG_JOKER_KEY) then return end
    hatch(card)
end

-- Spending a Soul while an egg is ready hatches it INSTEAD of making a
-- Legendary. Yharon is no longer in that pool at all, so without this there is
-- no way to one.
--
-- Vanilla picks its Soul branch by ability.name (card.lua:1763), so the name is
-- put aside for the length of the call: everything else use_consumeable does -
-- counting the usage, paying the rental, playing the sound, dissolving the card
-- - still happens, and only the Legendary it would have made does not. Skipping
-- the call outright would have skipped all of that with it.
local celesta_egg_use_ref = Card.use_consumeable
function Card:use_consumeable(area, copier)
    local center = self.config and self.config.center
    local egg = center and center.key == SOUL_KEY and ready_egg() or nil
    if not egg then return celesta_egg_use_ref(self, area, copier) end

    local saved = self.ability.name
    self.ability.name = "celesta_hatching_soul"
    local ok, err = pcall(celesta_egg_use_ref, self, area, copier)
    self.ability.name = saved
    if not ok then error(err, 0) end

    hatch(egg)
end

--------------------------------------------------------------------------------
-- The Pull button
--------------------------------------------------------------------------------
--
-- The button's label is localize('b_use'), read inside G.UIDEF.use_and_sell
-- _buttons (UI_definitions.lua:279) and nowhere this mod can reach on its own.
-- So localize is lent a different answer for that one key, for the length of
-- building this one card's buttons - a synchronous call, restored on the way
-- out and on the way out of an error.

local celesta_egg_buttons_ref = G.UIDEF and G.UIDEF.use_and_sell_buttons

if celesta_egg_buttons_ref then
    G.UIDEF.use_and_sell_buttons = function(card)
        local center = card and card.config and card.config.center
        local key = center and center.key
        if key ~= EGG_CARD_KEY then
            return celesta_egg_buttons_ref(card)
        end

        local localize_ref = localize
        localize = function(request, ...)
            if request == "b_use" then return localize_ref("celesta_b_pull") end
            return localize_ref(request, ...)
        end

        local ok, box = pcall(celesta_egg_buttons_ref, card)
        localize = localize_ref
        if not ok then error(box, 0) end
        return box
    end
end
