--- HESTIA, EKKOMORI AND BUBI
---
--- Three Jokers that reach into what the run is handed, as Kson and GirlDM do: Hestia doubles
--- the values of Jokers the run has already sold when they come round again, Ekkomori hands out
--- a Double Tag for every Boss Blind, and Bubi takes the cost off Stamps and fills the Stamp
--- Packs.
---
--- Their own file rather than a place in implemented.lua, which is within a handful of Lua's
--- limit of 200 locals in a main chunk and is sliced apart and run against stubs by the test
--- harnesses. Named so that it loads after the Jokers before it, which is the order the
--- Collection shows them in.

--------------------------------------------------------------------------------
-- Hestia [Rare] - sold Jokers come back, and may come back doubled.
--------------------------------------------------------------------------------
--
-- "Future copies of sold Jokers": a Joker that is created - in the shop, from a pack, from
-- anything that makes one - and whose key is one the run has sold. Every Joker sold is on the
-- list, this mod's and the base game's and another mod's (Card:sell_card in
-- jokers/implemented.lua writes it), and it is the run's rather than Hestia's, so selling a Joker
-- and THEN finding Hestia counts, the way a sale CDawg did not witness counts.
--
-- The roll is made as the copy is created, so the doubled values are on the card in the shop
-- before it is bought. "If possible" is the machinery Yoka Siri uses to multiply a Joker's
-- values: a Joker with nothing it can multiply is left as it is.

--- The odds, as a denominator: 1 in 4.
CelestasMod.HESTIA_ODDS = 4

--- How much the values are multiplied by.
CelestasMod.HESTIA_SCALE = 2

--- The Hestia in play that is able to act, or the CDawg running one it has retained.
---
--- The card rather than a boolean: the roll wants an object the run can see, and Oops! All 6s
--- and its like are read off it.
function CelestasMod.hestia_active()
    local found = CelestasMod.find_joker("j_celesta_hestia")[1]
    if found then return found.card end
    return CelestasMod.cdawg_running and CelestasMod.cdawg_running("j_celesta_hestia") or nil
end

--- Whether `key` is one the run has sold.
function CelestasMod.joker_was_sold(key)
    local sold = G.GAME and G.GAME.celesta_sold_keys
    return (sold and key and sold[key]) and true or false
end

--- Doubles a freshly made Joker's values, if the roll is won. Returns whether it did.
---
--- Split from the hook so it can be asked of a card directly.
function CelestasMod.hestia_doubles(card)
    if not (card and card.ability and card.ability.set == "Joker") then return false end
    local key = card.config and (card.config.center_key
        or (card.config.center and card.config.center.key))
    if not CelestasMod.joker_was_sold(key) then return false end

    local hestia = CelestasMod.hestia_active()
    if not hestia then return false end
    if not SMODS.pseudorandom_probability(
        hestia, "celesta_hestia", 1, CelestasMod.HESTIA_ODDS, "celesta_hestia") then
        return false
    end

    local scale = CelestasMod.yoka_scale
    if type(scale) ~= "function" then return false end
    local ok, changed = pcall(scale, card, CelestasMod.HESTIA_SCALE)
    if not ok then
        CelestasMod.warn_once("hestia_scale",
            ("Hestia could not double that Joker: %s"):format(tostring(changed)))
        return false
    end
    return changed and true or false
end

-- create_card is the one place every Joker the run is handed is made: the shop, a pack, a
-- Judgement, a Riff-Raff, SMODS.add_card. The card is judged after it is made, and handed on
-- as it was.
local celesta_hestia_create_ref = create_card
function create_card(...)
    local card = celesta_hestia_create_ref(...)
    if card then
        local ok, err = pcall(CelestasMod.hestia_doubles, card)
        if not ok then
            CelestasMod.warn_once("hestia_create",
                ("Hestia could not judge a new Joker: %s"):format(tostring(err)))
        end
    end
    return card
end

SMODS.Joker {
    key = "hestia",
    atlas = "hestia",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- A passive that create_card reads, not a trigger; a copy would have nothing to do.
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { odds = CelestasMod.HESTIA_ODDS, scale = CelestasMod.HESTIA_SCALE } },

    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_hestia")
        return { vars = { numerator, denominator } }
    end,
}

--------------------------------------------------------------------------------
-- Ekkomori [Rare] - a Double Tag for every Boss Blind.
--------------------------------------------------------------------------------
--
-- context.beat_boss is Steamodded's: the Blind just defeated was a Boss. It is raised with
-- game_over, so a Boss Blind lost is excluded as well. main_eval keeps it to once per round,
-- not once per card in the end-of-round pass.
--
-- The Tag is added in an event, like GirlDM's, and the Tag is made inside it. A copy of
-- Ekkomori hands out its own, which is what copying it is for, and speaks over the copier.

SMODS.Joker {
    key = "ekkomori",
    atlas = "ekkomori",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        if G.P_TAGS and G.P_TAGS.tag_double then info_queue[#info_queue + 1] = G.P_TAGS.tag_double end
        return { vars = {} }
    end,

    calculate = function(self, card, context)
        if not (context.end_of_round and context.main_eval and context.beat_boss
            and not context.game_over) then
            return
        end

        G.E_MANAGER:add_event(Event {
            func = function()
                add_tag(Tag("tag_double"))
                play_sound("generic1")
                return true
            end
        })

        return {
            message = localize { type = "name_text", set = "Tag", key = "tag_double" },
            colour = G.C.FILTER,
            card = context.blueprint_card or card,
        }
    end,
}

--------------------------------------------------------------------------------
-- Bubi [Legendary] - Stamps cost nothing, and the packs are full.
--------------------------------------------------------------------------------
--
-- Nothing here but the Joker: what it changes is in stamps/stamps.lua, which owns the Stamps and
-- asks Stamps.bubi() at the moment each thing is decided - whether a stamp is paid for as it
-- lands, how many a Stamp Pack holds, which of them are Rare. Bubi + Ironmouse (merge/bind.lua)
-- is the same Joker with every stamp in the pack Rare.

SMODS.Joker {
    key = "bubi",
    atlas = "bubi",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    -- A passive that the Stamps read, not a trigger; there is nothing to copy.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        -- The number the packs are filled to, read off the Stamps rather than written twice.
        local Stamps = CelestasMod.Stamps
        return { vars = { Stamps and Stamps.BUBI_PACK_SIZE or 5 } }
    end,
}
