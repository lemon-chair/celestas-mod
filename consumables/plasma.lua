--- PLASMA
---
--- A Spectral that gives the run the Plasma Deck's balancing - Chips and Mult
--- pooled and split evenly before the hand scores - for the rest of the run, at
--- the cost of a consumable slot. Once used it cannot appear again.
---
--- Three gates, and each is a different mechanism:
---
---   hidden = true   Black Hole's rate exactly, which is what was asked for.
---                   SMODS defaults a hidden Consumable to soul_set 'Spectral'
---                   and soul_rate 0.003 (game_object.lua:1283) - the same
---                   0.997 threshold vanilla rolls for Black Hole - and rolls
---                   it as a FORCED key rather than out of a pool, which is
---                   what lets a hidden card appear at all.
---
---   in_pool         Once per run. SMODS.add_to_pool is called for every
---                   hidden Consumable before it can be rolled
---                   (common_events.lua:2447), so a hidden card is still asked
---                   - which is the only reason this gate works. The Unholy
---                   Stone gates itself the same way.
---
---   can_use         Belt and braces on the same fact, so a copy already in
---                   the tray when the first one is used cannot spend itself
---                   on nothing.
---
--- The balancing is NOT the Plasma Deck. That deck also doubles the size of
--- every Blind (ante_scaling = 2), and this is the balancing alone, which is
--- what was asked for and the half that is a reward rather than a price.

SMODS.Atlas { key = "plasma", path = "plasma.png", px = 71, py = 95 }

--- True once this run has been given the balancing.
local function balanced_run()
    return (G.GAME and G.GAME.celesta_plasma) and true or false
end

CelestasMod.plasma_balanced = balanced_run

--------------------------------------------------------------------------------
-- The balancing
--------------------------------------------------------------------------------
--
-- Hooked at Back:trigger_effect, which is where the Plasma Deck's own lives
-- (back.lua:159) and the ONE place a run may rewrite both totals at once. A
-- Joker cannot do this: state_events.lua:743 asks the row for
-- final_scoring_step and then asks the BACK separately, and only the back's
-- answer is read back into hand_chips and mult (:746).
--
-- Installed at load rather than from `use`, so a loaded save has it: what
-- survives a reload is the flag on G.GAME, and a hook that only existed after
-- a use would be gone the next time the run was opened.
--
-- Idempotent, which is what makes it safe on the Plasma Deck itself: the deck
-- balances first, and balancing an already-balanced pair changes nothing.
--- Guarded the way Grimmi's sell hook is (jokers/implemented.lua): the wrapped
--- global belongs to the game rather than to this mod, and the suites and the
--- checkers load this file against stubs where it is simply not there.
local celesta_plasma_back_ref = Back and Back.trigger_effect
if celesta_plasma_back_ref then

function Back:trigger_effect(args)
    local chips, mult = celesta_plasma_back_ref(self, args)
    if not (args and args.context == "final_scoring_step") then return chips, mult end
    if not balanced_run() then return chips, mult end

    -- The deck's own arithmetic, copied off back.lua:160 rather than invented,
    -- including the floor: two halves of an odd total are not equal and
    -- vanilla rounds both down.
    local total = (chips or args.chips) + (mult or args.mult)
    local half = math.floor(total / 2)
    args.chips, args.mult = half, half
    update_hand_text({ delay = 0 }, { mult = half, chips = half })

    -- The deck says so out loud, and so does this. Not the whole of vanilla's
    -- flourish: that eases the Chips and Mult colours to purple and back again
    -- over six seconds of queued events, and a half-finished ease would leave
    -- the scoreboard purple for the rest of the run.
    G.E_MANAGER:add_event(Event {
        func = function()
            play_sound("gong", 0.94, 0.3)
            play_sound("gong", 0.94 * 1.5, 0.2)
            attention_text {
                scale = 1.4, text = localize("k_balanced"), hold = 2,
                align = "cm", offset = { x = 0, y = -2.7 }, major = G.play,
            }
            return true
        end
    })

    return args.chips, args.mult
end

end

SMODS.Consumable {
    key = "plasma",
    set = "Spectral",
    atlas = "plasma",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = false,
    hidden = true,

    config = { extra = { slots = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.slots } }
    end,

    in_pool = function(self)
        return not balanced_run()
    end,

    can_use = function(self, card)
        return not balanced_run()
    end,

    use = function(self, card, area, copier)
        G.GAME.celesta_plasma = true

        -- The price. Taken here rather than from the event below for Raise's
        -- reason: `use` is the last thing that happens before the card is
        -- gone, and anything left in the queue behind it is at the mercy of
        -- whatever else this set off.
        if G.consumeables and G.consumeables.config then
            G.consumeables.config.card_limit =
                G.consumeables.config.card_limit - card.ability.extra.slots
        end

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                play_sound("gong", 0.94, 0.4)
                card:juice_up(0.3, 0.5)
                card_eval_status_text(card, "extra", nil, nil, nil,
                    { message = localize("k_balanced"), colour = G.C.PURPLE })
                return true
            end
        })
    end,
}
