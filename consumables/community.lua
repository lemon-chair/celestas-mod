--- THE COMMUNITY
---
--- A Tarot that hands out two copies of one Tag, picked at random from five.
---
--- The five are all `new_blind_choice` Tags (game.lua:250-256): they do not
--- fire when they arrive, they sit in the HUD and open their pack the next time
--- a Blind is chosen. Two of the same one queue up behind each other, which is
--- what makes "double" mean anything - two Charm Tags are two Arcana Packs, not
--- one bigger one.
---
--- add_tag is the whole of the giving (UI_definitions.lua:1389): it builds the
--- HUD sprite, discovers the Tag, lets the Tags already in the HUD react to a
--- new one arriving, and raises `tag_added`. So a Tag handed out this way is
--- indistinguishable from one earned by skipping a Blind, which is the point.
---
--- The Anaglyph Deck is the model for the sound and the event (back.lua:145).
--- It is the one place vanilla creates a Tag out of nothing rather than from a
--- skip, so it is the one place that had to answer the same question.

SMODS.Atlas { key = "community", path = "community.png", px = 71, py = 95 }

--- The Tags it can hand out.
local COMMUNITY_TAGS = {
    "tag_standard",
    "tag_charm",
    "tag_meteor",
    "tag_buffoon",
    "tag_ethereal",
}

--- The "double" in the description.
local COPIES = 2

--- Which of the five actually exist, in case a mod has taken one out.
--- Asked at use time rather than at load: G.P_TAGS is filled in by Steamodded
--- after every mod has had its say, and this file is loaded during that.
local function available()
    local pool = {}
    for _, key in ipairs(COMMUNITY_TAGS) do
        if G.P_TAGS and G.P_TAGS[key] then pool[#pool + 1] = key end
    end
    return pool
end

SMODS.Consumable {
    key = "community",
    set = "Tarot",
    atlas = "community",
    pos = { x = 0, y = 0 },

    -- What a vanilla Tarot costs.
    cost = 3,
    unlocked = true,
    discovered = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    -- Ours because it has to be: Steamodded routes can_use_consumeable through
    -- the centre, and vanilla's chain of name checks ends in `return false` for
    -- a key it does not recognise, which would grey the button out forever.
    -- There is nothing to select and nothing to be short of, so it is always
    -- usable.
    can_use = function(self, card)
        return true
    end,

    use = function(self, card, area, copier)
        local pool = available()
        if #pool == 0 then return end
        local key = pseudorandom_element(pool, pseudoseed("celesta_community"))

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                -- A Tag object each: add_tag keeps the one it is handed in
                -- G.GAME.tags and hangs its HUD sprite off it, so handing it
                -- the same object twice would be one Tag listed twice.
                for _ = 1, COPIES do add_tag(Tag(key)) end
                play_sound("generic1", 0.9 + math.random() * 0.1, 0.8)
                play_sound("holo1", 1.2 + math.random() * 0.1, 0.4)
                card:juice_up(0.3, 0.5)
                return true
            end,
        })

        delay(0.6)
    end,
}
