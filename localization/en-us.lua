--- All player-facing text. Keys here must match the full prefixed key:
---   Joker "spark"       -> j_celesta_spark
---   Tarot "reforge"      -> c_celesta_reforge
---   Deck  "founders"     -> b_celesta_founders
--- #1#, #2#, ... are filled in order by that object's loc_vars().
--- Colour tags: {C:chips}, {C:mult}, {C:money}, {C:attention}, {X:mult,C:white}
--- and {} to reset. To add another language, copy this file to e.g. fr.lua.

return {
    descriptions = {
        Joker = {
            j_celesta_spark = {
                name = 'Spark',
                text = {
                    '{C:chips}+#1#{} Chips',
                },
            },
            j_celesta_ledger = {
                name = 'The Ledger',
                text = {
                    'This Joker gains {C:mult}+#1#{} Mult',
                    'per discarded card',
                    '{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)',
                },
            },
            j_celesta_tollkeeper = {
                name = 'Tollkeeper',
                text = {
                    'Played {C:diamonds}Diamond{} cards',
                    'give {X:mult,C:white}X#1#{} Mult when scored',
                    'Earn {C:money}$#2#{} at end of round',
                },
            },
        },

        Tarot = {
            c_celesta_reforge = {
                name = 'Reforge',
                text = {
                    'Enhances up to {C:attention}#1#{}',
                    'selected cards to',
                    '{C:attention}Mult Cards',
                },
            },
        },

        Back = {
            b_celesta_founders = {
                name = "Founder's Deck",
                text = {
                    'Start with an extra {C:money}$#1#{}',
                    'and a {C:attention}Spark{}',
                    '{C:red}-#2#{} Joker slot',
                },
            },
        },

        -- Shown on the mod's page in the Mods menu.
        Mod = {
            CelestasMod = {
                name = "Celesta's Mod",
                text = {
                    'A starter mod with example',
                    'Jokers, a Tarot, and a Deck.',
                },
            },
        },
    },

    misc = {
        dictionary = {
            celesta_cfg_verbose = 'Verbose logging',
        },
    },
}
