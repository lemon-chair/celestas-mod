--- SUMMON
---
--- A Spectral card that creates a random Mythic Joker. It turns up the way The Soul does in a
--- Spectral pack - the same 0.3% a card - and nowhere else: `hidden` is what puts it on that roll
--- rather than in the ordinary Spectral pool (Steamodded reads the flag and adds it to
--- SMODS.Consumable.legendaries, game_object.lua:1282), and the rate and the pack are spelled out
--- below rather than left to the defaults because they ARE the answer to "as often as a Soul".
---
--- Which Jokers it can make is `CelestasMod.summonable`: Mythic ones, that are not marked
--- celesta_no_summon (Yharon, who is hatched from an egg and from nothing else), that the run has
--- not banned and does not already have.
---
--- Occult cannot copy it (consumables/occult.lua), nor the Blessed Phoenix Egg or Plasma.

SMODS.Atlas { key = "summon", path = "summon.png", px = 71, py = 95 }

--- The keys of the Mythic Jokers a Summon could make right now, in key order.
---
--- Not owned, as the pool a Soul draws from is not: a run that has every one of them has nothing
--- to summon, unless it has a Showman. Not banned, which is how a colour challenge keeps out
--- every Joker it does not list - a Summon that made one anyway would be a way round the rules.
function CelestasMod.summonable()
    local out = {}
    local game = G.GAME or {}
    local banned = game.banned_keys or {}
    local showman = SMODS.find_card and next(SMODS.find_card("j_ring_master")) ~= nil
    for key, center in pairs(G.P_CENTERS or {}) do
        if center.set == "Joker" and CelestasMod.is_mythic_center(center)
            and not center.celesta_no_summon and not banned[key] then
            local owned = (game.used_jokers and game.used_jokers[key])
                or (CelestasMod.find_joker and #CelestasMod.find_joker(key, true) > 0)
            if showman or not owned then out[#out + 1] = key end
        end
    end
    table.sort(out)
    return out
end

--- Room in the Joker row, asked the way every vanilla source asks it, buffer included, so two
--- things creating a Joker in the same breath cannot both claim the last slot.
local function room()
    return G.jokers and G.jokers.config
        and #G.jokers.cards + (G.GAME.joker_buffer or 0) < G.jokers.config.card_limit
end

SMODS.Consumable {
    key = "summon",
    set = "Spectral",
    atlas = "summon",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    hidden = true,
    soul_set = "Spectral",
    soul_rate = 0.003,

    -- Not offered at all while there is nothing to make: the soul roll asks this, so a Summon can
    -- never turn up as a card the player is unable to use.
    in_pool = function(self, args)
        return #CelestasMod.summonable() > 0
    end,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    -- Ours because it has to be: Steamodded routes can_use_consumeable through the centre, and
    -- vanilla's chain of name checks ends in `return false` for a key it does not know.
    can_use = function(self, card)
        return room() and #CelestasMod.summonable() > 0
    end,

    use = function(self, card, area, copier)
        -- Reserved across the event boundary: the Joker is created a frame later, and the slot
        -- has to be spoken for until it is.
        G.GAME.joker_buffer = (G.GAME.joker_buffer or 0) + 1

        G.E_MANAGER:add_event(Event {
            trigger = "before",
            delay = 0.0,
            func = function()
                -- Chosen here and not above: what can be made is what is true now.
                local list = CelestasMod.summonable()
                local key = pseudorandom_element(list, pseudoseed("celesta_summon"))
                G.GAME.joker_buffer = math.max((G.GAME.joker_buffer or 1) - 1, 0)
                if not key then return true end

                local made = SMODS.create_card {
                    set = "Joker", key = key, area = G.jokers, skip_materialize = true,
                }
                if not made then return true end
                made:add_to_deck()
                G.jokers:emplace(made)
                made:start_materialize()
                return true
            end,
        })
    end,
}
