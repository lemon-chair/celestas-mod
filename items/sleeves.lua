--- Card Sleeves: a sleeve for every deck.
---
--- Card Sleeves lets a run take a sleeve alongside its deck, each one a run
--- modifier. It is optional, so everything below is behind the check for it.
---
--- Each sleeve IS its deck, borrowed rather than written a second time: the
--- same config, the same description numbers and the same `apply`, so the two
--- cannot drift apart. Every config key the decks use - hands, hand_size,
--- joker_slot, consumable_slot, no_interest, consumables - is one that Card
--- Sleeves' own Sleeve:apply already understands (CardSleeves.lua:148).
---
--- On its own deck a sleeve adds nothing, and the run plays exactly as that
--- deck does alone. Stacking was the alternative, and it breaks Hell: four
--- hands, less three, less three. Card Sleeves' own sleeves say what they do on
--- their own deck through a `_alt` description, and these do the same.
---
--- The decks that act from a hook rather than from `apply` - Ecstasy's shop and
--- Hell's Bosses - ask CelestasMod.run_has_deck, which answers for the sleeve
--- too. The rest either leave a flag on G.GAME from `apply` (Verdant, the
--- weather) or rewrite the starting deck once (Admin, Plaid, Rock), and need
--- nothing more. A sleeve's `apply` runs inside Back:apply_to_run, which is
--- the moment the deck's own does.
---
--- Art: assets/*/sleeves.png, built from the deck faces by
--- tools/gen_sleeves.py.

if type(CardSleeves) ~= "table" or type(CardSleeves.Sleeve) ~= "table" then return end

local PREFIX = SMODS.current_mod.prefix

-- The order of tools/gen_decks.py's DECKS, which is the order of both sheets:
-- a sleeve's cell is its deck's.
local DECKS = { "founders", "plaid", "ecstasy", "hell",
                "blizzard", "rain", "verdant", "rock", "sins", "fusion" }

for i, name in ipairs(DECKS) do
    local back_key = "b_" .. PREFIX .. "_" .. name
    local back = SMODS.Centers[back_key]
    if not back then
        CelestasMod.warn_once("sleeve_" .. name,
            ("There is no %s to make a sleeve from"):format(back_key))
    else
        CardSleeves.Sleeve {
            key = name,
            atlas = "sleeves",
            pos = { x = i - 1, y = 0 },
            unlocked = true,
            discovered = true,

            config = copy_table(back.config or {}),

            loc_vars = function(self)
                if self.get_current_deck_key() == back_key then
                    return { key = self.key .. "_alt", vars = {} }
                end
                -- The deck's own, called the way a Back's is - with nothing
                -- after self (back.lua:73) - so it reads its own config.
                if type(back.loc_vars) == "function" then
                    return back:loc_vars()
                end
                return { vars = {} }
            end,

            apply = function(self, sleeve)
                if self.get_current_deck_key() == back_key then return end
                CardSleeves.Sleeve.apply(self)
                if type(back.apply) == "function" then back:apply() end
            end,

            -- A deck whose ability is a `calculate` rather than an `apply`
            -- needs its sleeve to answer the same contexts, or the sleeve is
            -- the deck with its effects missing. The Deck of Sins is the one
            -- such: banking stat levels is a hook, but what a level PAYS is
            -- the Back answering contexts (items/decks.lua), and a Back only
            -- answers while it is the selected one.
            --
            -- Card Sleeves puts the worn sleeve into SMODS.get_card_areas
            -- 'individual' (CardSleeves.lua:1896), so this is reached with the
            -- same contexts and may return the same effects.
            --
            -- Silent on its own deck: the Back is already answering there, and
            -- forwarding as well would pay everything twice.
            calculate = function(self, sleeve, context)
                if self.get_current_deck_key() == back_key then return end
                if type(back.calculate) == "function" then
                    return back:calculate(back, context)
                end
            end,
        }
    end
end
