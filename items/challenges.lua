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
