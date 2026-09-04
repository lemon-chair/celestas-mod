--- CHALLENGES
---
--- A challenge is data, not behaviour: Game:start_run reads the table straight
--- off G.CHALLENGES and does the work itself (game.lua:2113 onward). It adds
--- each `jokers` entry through add_joker and calls set_eternal on it, then
--- assigns every `rules.modifiers` entry into starting_params.
---
--- Two things about that are worth knowing before editing one.
---
--- A modifier is an ABSOLUTE value, not a delta the way a Back's config is:
--- `self.GAME.starting_params[v.id] = v.value`. joker_slots below is 6 because
--- 6 is the number wanted, not because it adds one to the usual five.
---
--- And add_joker indexes G.P_CENTERS[id] without looking first
--- (common_events.lua:377), so a key that is not a real centre is not one
--- missing Joker - it is a run that cannot start. The keys here are checked
--- against the mod's own registrations by the test suite for that reason.

--------------------------------------------------------------------------------
-- Dairy Farm - the three Milk Bottle Jokers, kept.
--------------------------------------------------------------------------------
--
-- The three of them are the whole Milk Bottle engine: Moo Merrily makes a
-- Bottle every round, Milky stops the Bottles taking up consumable slots, and
-- Moo Moo Clover lets each Bottle pick two cards instead of one. Eternal, so
-- the engine cannot be sold off, and six Joker slots so there are three left
-- to build something around it with.

--------------------------------------------------------------------------------
-- Joker Printer - two slots and a press
--------------------------------------------------------------------------------
--
-- x3Dustco makes a Joker from this mod at the end of every shop, and there is
-- nowhere to put them: three slots fewer than usual leaves two, one of which
-- x3Dustco is standing in. The Bind is what the challenge is actually about -
-- folding each new Joker into the one you kept rather than choosing between
-- them - and it is the starting consumable rather than something to be found,
-- because a Bind cannot reach a shop on its own (merge/bind.lua).
--
-- A challenge consumable goes through add_joker, which routes it by the
-- centre's `consumeable` flag rather than by the field it was listed under
-- (common_events.lua:377), so a Spectral listed here lands in the consumable
-- row and not among the Jokers.

-- Resolved at load: SMODS.current_mod is nil by the time a Blind is set.
local PRINTER_KEY = "c_" .. SMODS.current_mod.prefix .. "_joker_printer"

-- Gold Stake's, whatever Stake the run is actually on.
--
-- get_blind_amount picks its table of base amounts off
-- G.GAME.modifiers.scaling (misc_functions.lua:1040): 1 is White's - 300, 800,
-- 2000, 5000 ... - 2 is what Green and up use, and 3 is what Purple and up use,
-- which is where Gold lands: 300, 1000, 3200, 9000, 25000, 60000, 110000,
-- 200000.
--
-- Gold is 3 rather than 8 because the Stakes do not each have their own table.
-- Steamodded builds Gold out of every Stake below it, and exactly two of them
-- - Green and Purple - raise `scaling` by one (src/game_object.lua:790, :830).
local PRINTER_BASE_SCALING = 3

--- What the quota is multiplied by at this Ante: 1, 3, 6, 10, 15, 21, 28, 36.
---
--- The triangular numbers, n(n+1)/2 - the multiplier does not climb by a fixed
--- amount, the CLIMB itself grows by one each Ante. Ante 2 is two more than
--- Ante 1, Ante 3 is three more than Ante 2, and so on.
---
--- Written as the closed form rather than as a running total because a running
--- total would need somewhere to live, and this has to answer for any Ante at
--- any time: the Blind select screen asks about the Ante being offered, and the
--- ladder in the run info asks about all eight at once.
---
--- Antes below 1 are left alone. get_blind_amount answers 100 for them - it is
--- the tutorial's - and n(n+1)/2 would hand Ante 0 a multiplier of 0, which is
--- a Blind that needs no chips at all.
function CelestasMod.printer_quota_scale(ante)
    if type(ante) ~= "number" or ante < 1 then return 1 end
    -- floor, because `/` is float division in every Lua the game might run
    -- on: n(n+1) is always even so nothing is lost, and an integer keeps the
    -- quota an integer.
    return math.floor(ante * (ante + 1) / 2)
end

SMODS.Challenge {
    key = "joker_printer",

    jokers = {
        -- Eternal, so the press cannot be sold for the slot it occupies.
        { id = "j_celesta_x3dustco", eternal = true },
    },

    consumeables = {
        { id = "c_celesta_bind" },
    },

    --- Called by Game:start_run once the run exists, after the Stake has been
    --- set up and the deck applied (game.lua:2117).
    ---
    --- modifiers.scaling is read by get_blind_amount and by nothing else in
    --- the game, so writing it here moves the quota and only the quota.
    ---
    --- max rather than assignment: a run already above Gold - another mod's
    --- Stake - keeps what it had. This is a floor, not a ceiling.
    apply = function(self)
        if not (G.GAME and G.GAME.modifiers) then return end
        G.GAME.modifiers.scaling =
            math.max(G.GAME.modifiers.scaling or 1, PRINTER_BASE_SCALING)
    end,

    rules = {
        -- Rendered on the challenge screen from misc.v_text.ch_c_<id>, with
        -- `value` threaded in as #1# (UI_definitions.lua:6058). Without an
        -- entry there the rule would be listed as the literal string ERROR.
        custom = {
            -- No value on either: the text names what it means outright,
            -- because neither is a single number to thread through.
            { id = "celesta_printer_stake" },
            { id = "celesta_printer_quota" },
        },
        modifiers = {
            -- Absolute, not a delta: vanilla starts on 5, so three fewer is 2.
            { id = "joker_slots", value = 2 },
        },
    },
}

--------------------------------------------------------------------------------
-- ...and the quota that climbs with the Ante
--------------------------------------------------------------------------------
--
-- Ante 1 is untouched, Ante 2 is X3, Ante 3 is X5, and two more every Ante
-- after - so the multiplier at Ante n is 2n-1.
--
-- ante_scaling, the starting param the Plasma Deck uses, cannot do this: it is
-- one number for the whole run. So the hook is on get_blind_amount instead,
-- which is the one function BOTH places asking for a quota go through - the
-- Blind itself (blind.lua:118) and the panel on the Blind select screen
-- (UI_definitions.lua:1682) - so the number offered and the number required
-- cannot disagree. The Ante ladder in the run info reads it too, and shows the
-- challenge's own numbers while the challenge is being played.
--
-- Wrapped rather than replaced, and wrapped at load, so Talisman's own version
-- of this function still does its work first and this only multiplies the
-- answer. Deliberately NOT guarded on the value being a plain number: past a
-- certain Ante it is one of Talisman's big numbers, and those multiply through
-- their own metamethod. It is COMPARISON that Lua 5.1 refuses across types,
-- not arithmetic.

local celesta_printer_blind_ref = get_blind_amount
if type(celesta_printer_blind_ref) == "function" then
    function get_blind_amount(ante, ...)
        local amount = celesta_printer_blind_ref(ante, ...)
        if not (G.GAME and G.GAME.challenge == PRINTER_KEY) then return amount end
        return amount * CelestasMod.printer_quota_scale(ante)
    end
end

SMODS.Challenge {
    key = "dairy_farm",

    jokers = {
        { id = "j_celesta_moomerrily", eternal = true },
        { id = "j_celesta_milky",      eternal = true },
        -- Moo Moo Clover's key really is 'clover'. The Blind of the same name
        -- is bl_celesta_clover, which is a different centre entirely.
        { id = "j_celesta_clover",     eternal = true },
    },

    rules = {
        custom = {},
        modifiers = {
            { id = "joker_slots", value = 6 },
        },
    },
}
