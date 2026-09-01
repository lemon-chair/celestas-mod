--- OCCULT
---
--- The Fool, for Spectrals. It creates the last Spectral card used this run,
--- shows which one that is in a chip under its description, and queues that
--- card's own description beside its own - all three of which are things
--- vanilla's Fool does, so all three are done the way vanilla's Fool does
--- them (common_events.lua:2659 for the chip and the tooltip, card.lua:1373
--- for the creation, card.lua:1553 for when the button lights up).
---
--- The one piece vanilla does NOT provide is the memory. set_consumeable_usage
--- records G.GAME.last_tarot_planet, and only for Tarots and Planets
--- (misc_functions.lua:1212) - nothing anywhere tracks the last Spectral. So
--- that function is wrapped and the Spectral half recorded next to vanilla's,
--- on G.GAME, which is where a save keeps it.
---
--- Wrapped THERE rather than around Card:use_consumeable because of one line:
--- set_consumeable_usage is called `if not copier` (card.lua:1093). A Spectral
--- replayed by something that copies consumables is not a Spectral the player
--- used, and hooking the function vanilla already gates that way inherits the
--- distinction instead of having to re-derive it.

SMODS.Atlas { key = "occult", path = "occult.png", px = 71, py = 95 }

--------------------------------------------------------------------------------
-- Remembering the last one
--------------------------------------------------------------------------------

local celesta_occult_usage_ref = set_consumeable_usage

--- Vanilla's, plus the Spectral it does not keep.
function set_consumeable_usage(used, ...)
    local out = celesta_occult_usage_ref(used, ...)

    local config = used and used.config
    local center = config and config.center
    if center and center.set == "Spectral" and config.center_key and G.GAME then
        G.GAME.celesta_last_spectral = config.center_key
    end

    return out
end

--- The key of the last Spectral used this run, if it still exists.
---
--- The centre is looked up rather than trusted: a key saved by a run that had
--- a mod installed can outlive that mod, and a card cannot be created from a
--- centre that is no longer there.
local function last_spectral()
    local key = G.GAME and G.GAME.celesta_last_spectral
    if key and G.P_CENTERS and G.P_CENTERS[key] then return key end
    return nil
end

--------------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------------

SMODS.Consumable {
    key = "occult",
    set = "Tarot",
    atlas = "occult",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    loc_vars = function(self, info_queue, card)
        local key = last_spectral()
        local center = key and G.P_CENTERS[key] or nil
        local name = center
            and localize { type = "name_text", key = center.key, set = center.set }
            or localize("k_none")

        -- The Spectral's own description, beside this card's. Nothing is
        -- queued when there is no last Spectral, or the panel would carry an
        -- empty box under it.
        if center then info_queue[#info_queue + 1] = center end

        return {
            vars = { name },
            -- The Fool's chip, verbatim in shape: red while there is nothing
            -- to make, green once there is. SMODS takes main_end straight off
            -- a loc_vars return (smods lovely/center.toml:142), so a modded
            -- card can have the thing vanilla hardcodes by name.
            main_end = {
                { n = G.UIT.C, config = { align = "bm", padding = 0.02 }, nodes = {
                    { n = G.UIT.C, config = { align = "m", r = 0.05, padding = 0.05,
                                              colour = center and G.C.GREEN or G.C.RED },
                      nodes = {
                        { n = G.UIT.T, config = { text = " " .. name .. " ",
                                                  colour = G.C.UI.TEXT_LIGHT,
                                                  scale = 0.3, shadow = true } },
                      } },
                } },
            },
        }
    end,

    can_use = function(self, card)
        if not (G.consumeables and last_spectral()) then return false end
        -- `or card.area == G.consumeables` is the Fool's, and it matters: the
        -- card being used frees its own slot, so a full row is not full by the
        -- time the new one lands.
        return #G.consumeables.cards < G.consumeables.config.card_limit
            or card.area == G.consumeables
    end,

    use = function(self, card, area, copier)
        local key = last_spectral()
        if not key then return end

        -- Deferred and re-checked, both of which are the Fool's. The room test
        -- in can_use was answered before this card left the row; by the time
        -- the event runs the row has actually changed, and that is the state
        -- worth trusting.
        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                if G.consumeables.config.card_limit > #G.consumeables.cards then
                    play_sound("timpani")
                    local made = create_card("Spectral", G.consumeables, nil, nil,
                                             nil, nil, key, "celesta_occult")
                    made:add_to_deck()
                    G.consumeables:emplace(made)
                    card:juice_up(0.3, 0.5)
                end
                return true
            end,
        })
        delay(0.6)
    end,
}
