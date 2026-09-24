--- The Unholy Stone - a Spectral that lifts the Deck of Sins' one hard rule.
---
--- Every other Sin the deck has is a number that climbs. This is the only
--- thing that changes the SHAPE of the climb: without it, the first stat in a
--- set to reach twenty closes that set and the rest of it stops for the run.
--- With it, all seven can be taken to twenty.
---
--- Three gates, each a different mechanism:
---
---   hidden = true      Black Hole's rate exactly. SMODS defaults a hidden
---                      Consumable to soul_set 'Spectral' and soul_rate
---                      0.003 (game_object.lua:1283) - the same 0.997
---                      threshold vanilla rolls for Black Hole - and rolls it
---                      as a FORCED key rather than out of a pool, which is
---                      what lets a hidden card appear at all.
---
---   in_pool            Only on this deck. SMODS.add_to_pool is called for
---                      every hidden Consumable before it can be rolled
---                      (common_events.lua:2447), so a hidden card is still
---                      asked - which is the only reason this gate works.
---
---   check_for_unlock   Only after the deck has won. get_deck_win_stake
---                      answers the highest stake a deck has been won on, so
---                      "> 0" is White Stake or better.

SMODS.Atlas { key = "unholy", path = "unholy.png", px = 71, py = 95 }

local Sins = CelestasMod.Sins

--- Resolved at load: SMODS.current_mod is nil by the time anything runs, so
--- the deck's key cannot be built inside check_for_unlock.
local SINS_DECK_KEY = "b_" .. SMODS.current_mod.prefix .. "_" .. Sins.DECK

SMODS.Consumable {
    key = "unholy",
    set = "Spectral",
    atlas = "unholy",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = false,
    discovered = false,
    hidden = true,

    loc_vars = function(self, info_queue, card)
        return { vars = { Sins.MAX_LEVEL } }
    end,

    in_pool = function(self)
        return CelestasMod.run_has_deck(Sins.DECK)
    end,

    -- Nothing to do a second time, and a Spectral that consumes itself for
    -- nothing is worse than one that cannot be used.
    can_use = function(self, card)
        return Sins.state() ~= nil and not Sins.lockout_lifted()
    end,

    use = function(self, card, area, copier)
        Sins.lift_lockout()
        card_eval_status_text(copier or card, "extra", nil, nil, nil, {
            message = localize("celesta_unholy_used"),
            colour = G.C.PURPLE,
        })
    end,

    check_for_unlock = function(self, args)
        if args.type == "win_deck" and get_deck_win_stake(SINS_DECK_KEY) > 0 then
            unlock_card(self)
        end
    end,
}
