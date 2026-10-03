--- KSON AND GIRLDM
---
--- Two Jokers that reach into what the run is handed: Kson makes Spectral cards out of a full
--- wallet, and GirlDM makes Tags out of skipping a Blind.
---
--- Their own file rather than a place in implemented.lua, which is within a handful of Lua's
--- limit of 200 locals in a main chunk and is sliced apart and run against stubs by the test
--- harnesses. What both of them do is also what an OniGiri merge does, with a bigger number, so
--- it is written once here as fields of CelestasMod and the pairs in merge/bind.lua - loaded
--- first, and reaching these only when a hand is played or a Blind skipped - call it.

--------------------------------------------------------------------------------
-- Kson [Rare] - with $40 or more, a hand played makes a Spectral card.
--------------------------------------------------------------------------------

--- The money Kson asks for.
CelestasMod.KSON_THRESHOLD = 40

--- True when the run's money is `threshold` or more.
---
--- Through more_than, which is the one comparison against money in this mod that
--- survives Talisman: with it, a run's money becomes a table once it outgrows a double, and
--- Lua 5.1 refuses `>=` between a number and a table outright. "At least" is not
--- "more than" the other way round: `a >= b` is `not (b > a)`.
function CelestasMod.kson_ready(threshold)
    local dollars = (G.GAME and G.GAME.dollars) or 0
    return not CelestasMod.more_than(threshold, dollars)
end

--- Makes up to `count` random Spectral cards, as many as there is room for, and says how
--- many that was.
---
--- Room is vanilla's own test, asked once per card: consumeable_buffer is how a slot taken
--- now and filled by an event later still counts as taken, which is what stops two cards in
--- one hand racing for the same slot - and what makes the second of two wait for the first.
function CelestasMod.kson_deal(count, seed)
    local made = 0
    for _ = 1, count do
        if not (G.consumeables and G.consumeables.config) then break end
        local buffer = G.GAME.consumeable_buffer or 0
        if #G.consumeables.cards + buffer >= G.consumeables.config.card_limit then break end

        G.GAME.consumeable_buffer = buffer + 1
        made = made + 1
        G.E_MANAGER:add_event(Event {
            trigger = "before",
            delay = 0.0,
            func = function()
                local spectral = SMODS.add_card { set = "Spectral", key_append = seed }
                if spectral then spectral:juice_up(0.3, 0.5) end
                G.GAME.consumeable_buffer = math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
                return true
            end
        })
    end
    return made
end

SMODS.Joker {
    key = "kson",
    atlas = "kson",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- A copy makes another, which is what copying it is for; each takes its own room.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { threshold = CelestasMod.KSON_THRESHOLD } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.threshold } }
    end,

    calculate = function(self, card, context)
        -- context.before is a hand being played, ahead of its scoring, so the money asked
        -- about is the money the hand was played with.
        if not context.before then return end
        if not CelestasMod.kson_ready(card.ability.extra.threshold) then return end
        if CelestasMod.kson_deal(1, "celesta_kson") <= 0 then return end

        return {
            message = localize("k_plus_spectral"),
            colour = G.C.SECONDARY_SET.Spectral,
            card = context.blueprint_card or card,
        }
    end,
}

--------------------------------------------------------------------------------
-- GirlDM [Uncommon] - skipping a Blind earns two more Tags.
--------------------------------------------------------------------------------

--- Adds `count` random Tags, and says how many were added.
---
--- get_next_tag_key is vanilla's own pick - the Tag pool as it stands, ante and ban list
--- included - so these are Tags the run could have been offered. Added in events, and the
--- Tag made inside each: some Tags do something the moment they exist.
function CelestasMod.girldm_tags(count, seed)
    local added = 0
    for i = 1, count do
        local key = get_next_tag_key(seed .. i)
        if key then
            added = added + 1
            G.E_MANAGER:add_event(Event {
                func = function()
                    add_tag(Tag(key))
                    play_sound("generic1")
                    return true
                end
            })
        end
    end
    return added
end

SMODS.Joker {
    key = "girldm",
    atlas = "girldm",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A copy adds its own Tags, which is what copying it is for.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { tags = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.tags } }
    end,

    calculate = function(self, card, context)
        if not context.skip_blind then return end

        local added = CelestasMod.girldm_tags(card.ability.extra.tags, "celesta_girldm")
        if added <= 0 then return end

        return {
            message = localize { type = "variable", key = "celesta_plus_tags",
                                 vars = { added } },
            colour = G.C.FILTER,
            card = context.blueprint_card or card,
        }
    end,
}
