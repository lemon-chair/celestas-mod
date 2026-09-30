--- Hand-written Jokers with real effects.
---
--- Anything defined here is EXCLUDED from the generated roster in
--- jokers/zz_vtubers.lua, so move a joker into this file the moment it stops
--- being a placeholder. tools/gen_roster.py finds them by matching
--- `SMODS.Joker {` followed immediately by `key = "..."`, so keep `key` as the
--- first field of every definition.
---
--- Their localization in localization/en-us.lua is preserved across
--- regeneration too - the generator only ever appends missing entries.

--- Builds an add_to_deck that announces the Joker's arrival, once.
---
--- Takes the JOKER's key rather than the sound's, because jokers/sounds.lua
--- holds the one map from one to the other - and merge/bind.lua reads that
--- same map when two Jokers become one, so a merge can play both halves'
--- sounds without knowing anything about either Joker.
---
--- Cryptid's Supercell is the pattern, and the from_debuff guard is the whole
--- of it: add_to_deck runs again every time a debuff is LIFTED - a Boss Blind
--- ending, a Joker being un-debuffed - so without it the sound replays on each
--- of those rather than only when the Joker turns up.
---
--- The sounds themselves are declared in jokers/sounds.lua, not here: this
--- file is compiled against stubs by the test harnesses, so it cannot call
--- SMODS.Sound at load.
local function announces(joker_key)
    return function(self, card, from_debuff)
        if not from_debuff then CelestasMod.play_join_sound(joker_key) end
    end
end

--------------------------------------------------------------------------------
-- Arar [Common]
-- At the start of each round, add a random enhancement to a random
-- unenhanced card held in hand.
--------------------------------------------------------------------------------

--- The enhancement made by the Tarot in the first consumable slot, if there is
--- one there and it makes one at all.
---
--- Read through `mod_conv`, which is what an enhancement Tarot IS: vanilla's
--- Card:use_consumeable applies whatever centre that field names
--- (card.lua:1401), and this mod's own enhancement Tarots are nothing but that
--- field. So a Tarot from any mod is understood here without naming any of
--- them, and a Tarot that does something else - The Fool, Judgement - names no
--- enhancement and is passed over rather than mistaken for one.
local function arar_favoured()
    local slot = G.consumeables and G.consumeables.cards
        and G.consumeables.cards[1]
    local center = slot and slot.config and slot.config.center
    if not (center and center.set == "Tarot") then return nil end

    local key = center.config and center.config.mod_conv
    if key and G.P_CENTERS[key] then return key end
    return nil
end

--- The enhancement to hand out without rolling for it, or nil to roll.
---
--- Every time, while that Tarot is sitting there - but only if the run is
--- still offering that enhancement. get_current_pool is what a Challenge or a
--- Deck that bans one takes it out of, and a Joker that could put it back is a
--- Joker that ignores the ban. So a favoured enhancement the run has culled
--- falls back to the ordinary roll rather than overriding it.
local function arar_forced()
    local favoured = arar_favoured()
    if not favoured then return nil end

    for _, key in ipairs(get_current_pool("Enhanced") or {}) do
        if key == favoured then return favoured end
    end
    return nil
end

-- Shared with Arar + FroggyLoch in merge/bind.lua, which favours the same Tarot.
CelestasMod.arar_forced = arar_forced

SMODS.Joker {
    key = "arar",
    atlas = "arar",
    pos = { x = 0, y = 0 },

    rarity = 1,
    cost = 4,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return CelestasMod.with_true_star_line("j_celesta_arar", {})
    end,

    add_to_deck = announces("j_celesta_arar"),

    calculate = function(self, card, context)
        -- True Stars in the deck are worth X Mult here; suits/true_stars.lua
        -- says what counts as one.
        if context.joker_main then
            local x_mult = CelestasMod.true_star_x_mult()
            if x_mult > 1 then return { x_mult = x_mult } end
        end

        -- Fires once per round, right after the opening hand is dealt.
        -- (Set by state_events.lua as
        --  `not G.GAME.current_round.any_hand_drawn and G.GAME.facing_blind`.)
        if context.first_hand_drawn then
            local candidates = {}
            for _, c in ipairs(G.hand.cards) do
                -- c_base is the unenhanced playing-card center. The flag
                -- excludes a card already claimed this pass: set_ability is
                -- deferred into an event, so a Blueprint/Brainstorm copy
                -- evaluating in the same pass would still see it as
                -- unenhanced and could waste the copy re-picking it.
                -- Vanilla Vampire guards the same way with `vampired`.
                if c.config.center == G.P_CENTERS.c_base
                    and not c.celesta_arar_claimed then
                    candidates[#candidates + 1] = c
                end
            end
            if #candidates == 0 then return end

            local target = pseudorandom_element(candidates, pseudoseed("celesta_arar"))
            -- poll_enhancement respects the run's current pool, so this never
            -- rolls an enhancement the run has disabled, and it does pick up
            -- enhancements added by other mods.
            local enhancement = arar_forced() or SMODS.poll_enhancement {
                key = "celesta_arar_enh",
                guaranteed = true,
            }
            if not enhancement then return end

            target.celesta_arar_claimed = true
            G.E_MANAGER:add_event(Event {
                func = function()
                    target:set_ability(G.P_CENTERS[enhancement])
                    target:juice_up(0.3, 0.5)
                    target.celesta_arar_claimed = nil
                    return true
                end
            })

            return {
                message = localize("k_upgrade_ex"),
                colour = G.C.SECONDARY_SET.Enhanced,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Crelly [Uncommon]
-- At the end of the shop, consumes a random held consumable and gains
-- X0.2 Mult for doing so. Base X1 Mult.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "crelly",
    atlas = "crelly",
    pos = { x = 0, y = 0 },

    rarity = 2,
    cost = 6,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { x_mult = 1, x_mult_gain = 0.2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult_gain, card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        -- Fires when the "Next Round" button leaves the shop.
        -- `not context.blueprint` so a Blueprint copy cannot eat a second
        -- consumable or double the growth - it still copies the X Mult below.
        if context.ending_shop and not context.blueprint then
            if #G.consumeables.cards > 0 then
                local target = pseudorandom_element(G.consumeables.cards,
                    pseudoseed("celesta_crelly"))

                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "x_mult",
                    scalar_value = "x_mult_gain",
                    no_message = true,
                })

                -- Respects eternal/undestroyable stickers and animates the eat.
                SMODS.destroy_cards(target)

                return {
                    message = localize {
                        type = "variable",
                        key = "a_xmult",
                        vars = { card.ability.extra.x_mult },
                    },
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Kumi [Uncommon]
-- Destroys all scoring Gold cards in the played hand, with a 1 in 4 chance
-- to give $20 for each Gold card destroyed.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "kumi",
    atlas = "kumi",
    pos = { x = 0, y = 0 },

    rarity = 2,
    cost = 8,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { dollars = 20, odds = 4 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_gold
        -- Reads the live odds so the text tracks Oops! All 6s and friends.
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_kumi")
        return { vars = { numerator, denominator, card.ability.extra.dollars } }
    end,

    add_to_deck = announces("j_celesta_kumi"),

    calculate = function(self, card, context)
        -- destroying_card is only set for cards that are both in G.play and
        -- part of the scoring hand, so this is already "scoring cards" only.
        if context.destroying_card and context.cardarea == G.play then
            if SMODS.has_enhancement(context.destroying_card, "m_gold") then
                -- calculate_destroying_cards acts on `remove` without checking
                -- eternal itself, so guard here or Kumi eats eternal cards.
                -- No destruction means no payout, hence the early return.
                if SMODS.is_eternal(context.destroying_card) then return end

                -- `remove` and `dollars` are both in other_calculation_keys,
                -- so one table can destroy the card and pay out at once.
                local effect = { remove = true }
                if SMODS.pseudorandom_probability(
                        card, "celesta_kumi", 1, card.ability.extra.odds) then
                    effect.dollars = card.ability.extra.dollars
                end
                return effect
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Maya [Rare]
-- 1 in 2 chance to retrigger Steel Cards held in hand 2 extra times.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "maya",
    atlas = "maya",
    pos = { x = 0, y = 0 },

    rarity = 3,
    cost = 8,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { odds = 2, repetitions = 2 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_steel
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_maya")
        return { vars = { numerator, denominator, card.ability.extra.repetitions } }
    end,

    add_to_deck = announces("j_celesta_maya"),

    calculate = function(self, card, context)
        -- Held-in-hand repetition pass: cardarea is G.hand and other_card is
        -- the card being considered for a retrigger.
        if context.repetition and context.cardarea == G.hand then
            if SMODS.has_enhancement(context.other_card, "m_steel")
                and SMODS.pseudorandom_probability(
                    card, "celesta_maya", 1, card.ability.extra.odds) then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Zentreya [Uncommon]
-- Steel Cards in the played hand give X1.75 Mult when scored.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "zentreya",
    atlas = "zentreya",
    pos = { x = 0, y = 0 },

    rarity = 2,
    cost = 6,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { x_mult = 1.75 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_steel
        return { vars = { card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        -- context.individual + cardarea == G.play is the scoring-card pass;
        -- unscored cards arrive with cardarea == 'unscored' instead.
        if context.individual and context.cardarea == G.play then
            if SMODS.has_enhancement(context.other_card, "m_steel") then
                return {
                    x_mult = card.ability.extra.x_mult,
                    card = context.other_card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- KokoNuts [Common]
-- At the start of each round, add a Lucky 7 of Spades to the deck.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "kokonuts",
    atlas = "kokonuts",
    pos = { x = 0, y = 0 },

    rarity = 1,
    cost = 5,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky
        return {}
    end,

    add_to_deck = announces("j_celesta_kokonuts"),

    calculate = function(self, card, context)
        -- Same shape as vanilla Marble Joker: build the card in G.play so the
        -- player sees it, then animate it into the deck. The getting_sliced
        -- guard stops a Joker being destroyed this frame from still firing.
        if context.setting_blind
            and not (context.blueprint_card or card).getting_sliced then
            G.E_MANAGER:add_event(Event {
                func = function()
                    local new_card = create_playing_card(
                        { front = G.P_CARDS.S_7, center = G.P_CENTERS.m_lucky },
                        G.play, nil, nil, { G.C.SECONDARY_SET.Enhanced })

                    SMODS.calculate_effect({
                        message = localize("celesta_plus_seven"),
                        colour = G.C.SECONDARY_SET.Enhanced,
                    }, context.blueprint_card or card)

                    G.E_MANAGER:add_event(Event {
                        func = function()
                            draw_card(G.play, G.deck, 90, "up", nil)
                            return true
                        end
                    })

                    -- Lets other jokers react to a new playing card existing.
                    playing_card_joker_effects({ new_card })
                    return true
                end
            })
            -- The card is made inside that event, so there is no effect table
            -- to hand back - but eval_card will not consider retriggering a
            -- Joker that has not said it triggered, which is what a retrigger
            -- Stamp on this one needs. `nil, true` is vanilla's way of saying
            -- it (card.lua, Obelisk and Ride the Bus both end this way).
            return nil, true
        end
    end,
}

--------------------------------------------------------------------------------
-- LaynaLazar [Uncommon]
-- Removes Mult enhancements from scoring cards; gains +2 permanent Mult
-- for each one removed.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "laynalazar",
    atlas = "laynalazar",
    pos = { x = 0, y = 0 },

    rarity = 1,
    cost = 5,
    unlocked = false,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { mult = 0, mult_gain = 4 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_mult
        return { vars = { card.ability.extra.mult_gain, card.ability.extra.mult } }
    end,

    calculate = function(self, card, context)
        -- Same shape as vanilla Vampire: context.before, so the enhancement is
        -- stripped before the hand scores and those cards do not pay out their
        -- Mult this hand. context.scoring_hand is only populated here.
        if context.before and not context.blueprint then
            local removed = {}
            for _, played in ipairs(context.scoring_hand) do
                if SMODS.has_enhancement(played, "m_mult")
                    and not played.debuff
                    and not played.celesta_stripped then
                    removed[#removed + 1] = played
                    played.celesta_stripped = true
                    -- Under unjudged: set_ability re-judges the card, and
                    -- The Pillar debuffs anything played this Ante - which is
                    -- every card in the hand being played.
                    CelestasMod.unjudged(played, function()
                        played:set_ability(G.P_CENTERS.c_base, nil, true)
                    end)
                    G.E_MANAGER:add_event(Event {
                        func = function()
                            played:juice_up()
                            played.celesta_stripped = nil
                            return true
                        end
                    })
                end
            end

            if #removed > 0 then
                -- scale_card rather than a raw add: it routes through SMODS'
                -- scaling hooks and Talisman's big-number handling, and shows
                -- the "+N Mult" popup itself.
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "mult",
                    scalar_value = "mult_gain",
                    message_key = "a_mult",
                    message_colour = G.C.MULT,
                    operation = function(ref_table, ref_value, initial, scaling)
                        ref_table[ref_value] = initial + scaling * #removed
                    end
                })
            end
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.mult, 0) then
            return { mult = card.ability.extra.mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- FroggyLoch [Uncommon]
-- Scoring cards have a 1 in 2 chance to retrigger 1 additional time.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "froggyloch",
    atlas = "froggyloch",
    pos = { x = 0, y = 0 },

    rarity = 2,
    cost = 6,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { odds = 2, repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_froggyloch")
        return { vars = { numerator, denominator, card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        -- The repetition pass runs once per scoring card, so the roll is
        -- independent for each one.
        if context.repetition and context.cardarea == G.play then
            if SMODS.pseudorandom_probability(
                    card, "celesta_froggyloch", 1, card.ability.extra.odds) then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- ShyLily [Common]
-- Retriggers the last scoring card 2 additional times.
-- Hanging Chad, but anchored to the end of the scoring hand.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "shylily",
    atlas = "shylily",
    pos = { x = 0, y = 0 },

    rarity = 1,
    cost = 4,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { repetitions = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        -- Hanging Chad tests context.other_card == context.scoring_hand[1];
        -- this is the same test against the last entry instead.
        if context.repetition and context.cardarea == G.play then
            if context.other_card == context.scoring_hand[#context.scoring_hand] then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Yuy [Rare]
-- On the final hand of the round, each scoring card gives X1.5 Mult.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "yuy_ix",
    atlas = "yuy_ix",
    pos = { x = 0, y = 0 },

    rarity = 3,
    cost = 8,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { x_mult = 1.5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        -- hands_left == 0 is how vanilla Dusk detects the final hand.
        if context.individual and context.cardarea == G.play
            and G.GAME.current_round.hands_left == 0 then
            return {
                x_mult = card.ability.extra.x_mult,
                colour = G.C.RED,
                -- The JOKER, not the scored card. The effect pipeline only
                -- juices `effect.card` when it differs from the card being
                -- scored, so pointing this at other_card meant nothing
                -- animated. Vanilla Photograph returns `card = self` here.
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Megalodon [Rare]
-- Gains +5 Mult for each card in the played hand. Resets at end of round.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "megalodon",
    atlas = "megalodon",
    pos = { x = 0, y = 0 },

    rarity = 3,
    cost = 8,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { mult = 0, mult_gain = 5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.mult_gain, card.ability.extra.mult } }
    end,

    calculate = function(self, card, context)
        -- context.before is where full_hand is populated (state_events.lua
        -- passes full_hand = G.play.cards). That is every played card, not
        -- just the scoring ones, and it lands before scoring so the Mult
        -- gained counts for the hand that earned it.
        if context.before and not context.blueprint then
            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "mult",
                scalar_value = "mult_gain",
                message_key = "a_mult",
                message_colour = G.C.MULT,
                operation = function(ref_table, ref_value, initial, scaling)
                    ref_table[ref_value] = initial + scaling * #context.full_hand
                end
            })
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.mult, 0) then
            return { mult = card.ability.extra.mult }
        end

        -- context.main_eval is the once-per-round joker pass; without it this
        -- also fires during the per-card and repetition passes.
        if context.end_of_round and context.main_eval and not context.blueprint then
            if CelestasMod.more_than(card.ability.extra.mult, 0) then
                card.ability.extra.mult = 0
                return {
                    message = localize("k_reset"),
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Aquwa [Rare]
-- At the start of each round, starts a Downpour, which lasts until the end
-- of the round. See arena/arena.lua for what a Downpour does.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "aquwa",
    atlas = "aquwa",
    pos = { x = 0, y = 0 },

    rarity = 3,
    cost = 8,
    unlocked = false,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- setting_blind is the moment the blind is chosen, before any cards
        -- are dealt, so the Downpour is already up for the whole round.
        -- The Arena clears itself on the return to BLIND_SELECT.
        if context.setting_blind and not context.blueprint then
            if not CelestasMod.Arena.is_active("downpour") then
                CelestasMod.Arena.start("downpour")
                return {
                    message = localize("celesta_downpour"),
                    colour = G.C.BLUE,
                    card = card,
                }
            end
        end
    end,
}

--- IMPLEMENTED: cottontail, spite, uzuri, beepers
--- (declared explicitly because these are registered from a loop, so
---  tools/gen_roster.py cannot read their keys from the source)

--------------------------------------------------------------------------------
-- SEAL-GRANTING JOKERS
-- All four share a shape: on the individual scoring pass, if the card matches
-- and carries no seal, roll 1 in 4 and stamp a seal on it.
-- CelestasMod.SEAL_KEYS holds the prefixed keys, set in seals/seals.lua.
--------------------------------------------------------------------------------

local SEAL_GRANTERS = {
    {
        key = "cottontail", seal = "Star", cost = 6,
        -- Face cards only, and only if the card is bare.
        eligible = function(c) return c:is_face() and not c.seal end,
    },
    {
        key = "spite", seal = "Ectoplast", cost = 6,
        -- "Enhanced" means any enhancement at all, i.e. not the base center.
        eligible = function(c)
            return c.config.center ~= G.P_CENTERS.c_base and not c.seal
        end,
    },
    {
        key = "uzuri", seal = "Rose", cost = 6,
        eligible = function(c) return not c:is_face() and not c.seal end,
    },
    {
        key = "beepers", seal = "Foppy", cost = 6,
        -- Deliberately targets a card that DOES have a seal: it upgrades a
        -- Red Seal (1 retrigger) into a Foppy Seal (2).
        eligible = function(c) return c.seal == "Red" end,
    },
}

for _, entry in ipairs(SEAL_GRANTERS) do
    SMODS.Joker {
        key = entry.key,
        atlas = entry.key,
        pos = { x = 0, y = 0 },

        rarity = 2,
        cost = entry.cost,
        unlocked = false,
        discovered = false,
        blueprint_compat = true,
        eternal_compat = true,

        config = { extra = { odds = 4 } },

        loc_vars = function(self, info_queue, card)
            local numerator, denominator = SMODS.get_probability_vars(
                card, 1, card.ability.extra.odds, "celesta_" .. entry.key)
            return { vars = { numerator, denominator } }
        end,

        calculate = function(self, card, context)
            if context.individual and context.cardarea == G.play then
                local other = context.other_card
                if other and entry.eligible(other)
                    and SMODS.pseudorandom_probability(
                        card, "celesta_" .. entry.key, 1, card.ability.extra.odds) then
                    other:set_seal(CelestasMod.SEAL_KEYS[entry.seal], nil, true)
                    return {
                        message = localize("celesta_sealed"),
                        colour = G.C.PURPLE,
                        card = card,
                    }
                end
            end
        end,
    }
end

--------------------------------------------------------------------------------
-- OverEzEggs [Uncommon]
-- At the end of each round, converts all cards held in hand to Hearts.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "overezeggs",
    atlas = "overezeggs",
    pos = { x = 0, y = 0 },

    rarity = 2,
    cost = 6,
    unlocked = true,
    discovered = false,
    blueprint_compat = false,
    eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- main_eval is the once-per-round joker pass; without it this also
        -- runs during the per-card and repetition passes.
        if context.end_of_round and context.main_eval and not context.blueprint then
            if not G.hand or #G.hand.cards == 0 then return end
            for _, held in ipairs(G.hand.cards) do
                -- change_base rather than poking base.suit directly: it keeps
                -- the sprite and any modded suit bookkeeping in step.
                SMODS.change_base(held, "Hearts")
            end
            return {
                message = localize("celesta_hearts"),
                colour = G.C.RED,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- BerryCrepe [Common]
-- Scored cards permanently gain +1 Mult.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "berrycrepe",
    atlas = "berrycrepe",
    pos = { x = 0, y = 0 },

    rarity = 1,
    cost = 5,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { mult_gain = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.mult_gain } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play then
            local other = context.other_card
            if not other then return end
            -- perma_mult is scored by Card:get_chip_mult and printed on the
            -- card automatically as "+N Mult", so no display work is needed.
            other.ability.perma_mult = (other.ability.perma_mult or 0)
                + card.ability.extra.mult_gain
            return {
                extra = {
                    message = localize {
                        type = "variable",
                        key = "a_mult",
                        vars = { other.ability.perma_mult },
                    },
                    colour = G.C.MULT,
                },
                card = other,
            }
        end
    end,
}

--- Reads Ironmouse's exponent defensively. Falls back through the older field
--- name and finally the centre's own default, so a card saved under a previous
--- field name can never render "^nil Mult" or silently score nothing.
function CelestasMod.ironmouse_emult(self, card)
    local extra = card and card.ability and card.ability.extra
    return (extra and (extra.emult or extra.e_mult))
        or (self.config and self.config.extra and self.config.extra.emult)
        or 1.3
end

--------------------------------------------------------------------------------
-- Ironmouse [Rare]
-- ^1.3 Mult. Exponential scoring comes from Talisman, which registers `emult`
-- as a scoring parameter; without Talisman installed the key is unrecognised
-- and this scores nothing. Talisman is a declared dependency, so that is not
-- a configuration the mod is expected to run in.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "ironmouse",
    atlas = "ironmouse",
    pos = { x = 0, y = 0 },

    rarity = 4,
    cost = 20,
    unlocked = true,
    discovered = false,
    blueprint_compat = true,
    eternal_compat = true,

    -- Stored as `emult`, matching Cryptid. The effect KEY below is `e_mult`;
    -- Talisman accepts either spelling, but a card created before this field
    -- was named still carries `emult`, and a nil here is not cosmetic - the
    -- key drops out of the return entirely, so nothing scores, no popup
    -- appears and nothing animates. Hence the fallback chain.
    config = { extra = { emult = 1.3 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { CelestasMod.ironmouse_emult(self, card) } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            return {
                e_mult = CelestasMod.ironmouse_emult(self, card),
                colour = G.C.DARK_EDITION,
                card = card,

                -- The exponential cue Cryptid uses. The sound is Talisman's,
                -- not Cryptid's: ExponentialMult.wav, registered as `emult`
                -- under Talisman's `talisman` prefix. Talisman's own e_mult
                -- handler prints the message but plays nothing, so it has to
                -- be triggered by hand - Cryptid does the same.
                --
                -- Timing: `func` runs while the effect resolves, but the
                -- "^N Mult" popup is not drawn then - card_eval_status_text
                -- queues it on G.E_MANAGER. Calling play_sound directly here
                -- fires it a beat ahead of the visual, so queue it the same
                -- way and let the event manager line the two up.
                func = function()
                    if SMODS.no_resolve then return end
                    if not (SMODS.Sounds and SMODS.Sounds.talisman_emult) then return end
                    G.E_MANAGER:add_event(Event {
                        trigger = "before",
                        delay = 0,
                        func = function()
                            play_sound("talisman_emult", 1)
                            return true
                        end,
                    })
                end,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Shoto [Common] - 1 in 4 to Gash a scored card.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "shoto",
    atlas = "shoto",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = false, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 4 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Gash]
        local n, d = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "celesta_shoto")
        return { vars = { n, d } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play then
            local other = context.other_card
            if other and not SMODS.has_enhancement(other, CelestasMod.ENHANCEMENT_KEYS.Gash)
                and SMODS.pseudorandom_probability(card, "celesta_shoto", 1, card.ability.extra.odds) then
                -- Under unjudged, for the reason FeFe gives.
                CelestasMod.unjudged(other, function()
                    other:set_ability(G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Gash])
                end)
                -- Spare it from breaking on the hand it was gashed in; the
                -- Gash enhancement consumes this flag on its next destroy
                -- check. Without it a card could be gashed and destroyed in
                -- the same scoring pass.
                other.celesta_gash_fresh = true
                other:juice_up(0.3, 0.4)
                return { message = localize("celesta_gashed"), colour = G.C.RED, card = card }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Saruei [Common] - paid by the fragile cards that survive, charged for the
-- ones that do not.
--------------------------------------------------------------------------------
--
-- context.after is the only pass that can answer this, and the reason is worth
-- writing down. The destroy pass is the last thing evaluate_play does
-- (state_events.lua:750), and the remove_playing_cards context that follows it
-- is raised ONLY when something was actually destroyed (state_events.lua:756) -
-- so a hand where every Glass card held would never pay for a single one of
-- them. `after` is raised unconditionally after all of it
-- (state_events.lua:869), by which point every card that is going to break has
-- been marked and not one has left G.play yet.
--
-- getting_sliced is the mark to read. SMODS sets it on every card the destroy
-- pass takes, BEFORE splitting them into shattered and destroyed
-- (utils.lua:2074), so one field covers Glass shattering and Gash dissolving
-- alike - and covers anything else that destroys a played card too, which is
-- what "doesn't break" ought to mean.
--
-- Not guarded against context.blueprint: what this returns is money and
-- nothing else, so a copy paying again is exactly what a copy should do.

SMODS.Joker {
    key = "saruei",
    atlas = "saruei",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { earn = 3, lose = 1 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_glass
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Gash]
        return { vars = { card.ability.extra.earn, card.ability.extra.lose } }
    end,

    calculate = function(self, card, context)
        if not context.after then return end

        local kept, broken = 0, 0
        for _, played in ipairs(context.full_hand or {}) do
            -- A debuffed card is not counted on either side of the ledger. Its
            -- enhancement does nothing while the Blind holds it down - it does
            -- not score and it cannot break - so paying for it surviving would
            -- be paying for a card that was never at risk.
            --
            -- Counted once even if a card is somehow both, which this mod's
            -- extra_enhancement cards can be.
            if not played.debuff
                and (SMODS.has_enhancement(played, "m_glass")
                     or SMODS.has_enhancement(
                        played, CelestasMod.ENHANCEMENT_KEYS.Gash)) then
                if played.getting_sliced then
                    broken = broken + 1
                else
                    kept = kept + 1
                end
            end
        end

        -- One payout rather than two: what leaves the wallet and what enters
        -- it happen in the same breath, so the player is shown the difference.
        local money = kept * card.ability.extra.earn
            - broken * card.ability.extra.lose
        if money == 0 then return end
        return { dollars = money, card = card }
    end,
}

--------------------------------------------------------------------------------
-- Bao [Uncommon] - +5 Mult, or X5 Mult while a Downpour is running.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "bao",
    atlas = "bao",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { mult = 5, x_mult = 5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.mult, card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            if CelestasMod.Arena.is_active("downpour") then
                return { x_mult = card.ability.extra.x_mult }
            end
            return { mult = card.ability.extra.mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Yomi Quinnely [Uncommon] - retriggers one suit, rotating each round.
--------------------------------------------------------------------------------

local ROTATION_BASE_SUITS = { "Clubs", "Spades", "Diamonds", "Hearts" }

--- The suits Yomi rotates through.
---
--- An added suit joins the list only once the deck actually holds one of its
--- cards. Neither Stars nor Leaves are dealt at the start of a run - see
--- suits/shared.lua - so a rotation that could land on one beforehand would
--- spend a whole round retriggering a suit the player has no cards in.
---
--- CelestasMod.suit_in_deck reads base.suit rather than going through is_suit:
--- is_suit routes through SMODS.smeared_check, and Arielle widens that to
--- match everything, which would report every suit as present in every deck.
local function rotation_suits()
    -- Appended in registration order, never prepended: the four vanilla suits
    -- keep the positions a saved suit_index already points at, so acquiring a
    -- Star card does not jump a Yomi part-way through the rotation onto a
    -- different suit - it simply reaches the new one when it next wraps.
    --
    -- With two added suits that is no longer quite airtight: picking up a Star
    -- while already holding Leaves inserts Stars ahead of Leaves and moves the
    -- rotation on by one. Reserving a slot for a suit the deck does not have
    -- would mean rotating onto nothing, which is the worse of the two.
    local suits = nil
    for _, suit in ipairs(CelestasMod.CONVERSION_SUIT_ORDER or {}) do
        if CelestasMod.suit_in_deck(suit) then
            if not suits then
                suits = {}
                for i, base in ipairs(ROTATION_BASE_SUITS) do suits[i] = base end
            end
            suits[#suits + 1] = suit
        end
    end
    return suits or ROTATION_BASE_SUITS
end

--- `index` as a whole number inside 1..count.
---
--- The rotation index is a number the Joker keeps in its ability table, and
--- Cryptid's misprintize walks that table multiplying every number it finds by
--- a random factor - so a saved 1 comes back as 46.101724272927, and
--- suits[46.101724272927] is nil. That nil reaches localize, which indexes it
--- and crashes: the description is what dies, not the effect, so it takes the
--- run down the moment the Joker is hovered.
---
--- Repaired on the way OUT rather than refused on the way in, because by the
--- time this is known the corrupted value is already in the save. Talisman can
--- also leave a big number here rather than a Lua one, and a misprint of a
--- misprint can arrive as nan, so anything that is not a plain finite number
--- falls back to the first suit instead of being done arithmetic on.
local function rotation_index(index, count)
    if type(index) ~= "number" or index ~= index
        or index == math.huge or index == -math.huge then
        return 1
    end
    return (math.floor(index) - 1) % count + 1
end

--- The suit at `index`, wrapped into range.
--- Shared with Saiiren, which walks the same rotation on its own index.
--- The list changes length when the first Star card arrives or the last one
--- leaves, so a saved index can point past the end; wrapping keeps it inside
--- the list rather than silently resetting the rotation to Clubs.
local function rotation_suit_at(suits, index)
    -- Yoclesh pins every rotating suit to Hearts. Answered here rather than in
    -- each Joker because this is the one place either of them asks what the
    -- rotation is currently on - the description reads it through here too, so
    -- the card says Hearts as well as meaning it. The index still advances
    -- underneath, so selling the Yoclesh resumes the rotation where it got to
    -- rather than restarting it.
    if CelestasMod.yoclesh_active and CelestasMod.yoclesh_active() then
        return "Hearts"
    end
    return suits[rotation_index(index, #suits)]
end

-- Shared with merge/bind.lua, where ObKatieKat + Saiiren walks the same
-- rotation on its own index.
CelestasMod.rotation_suits = rotation_suits
CelestasMod.rotation_index = rotation_index
CelestasMod.rotation_suit_at = rotation_suit_at

SMODS.Joker {
    key = "yomiquinnely",
    atlas = "yomiquinnely",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { suit_index = 1 } },

    loc_vars = function(self, info_queue, card)
        local suits = rotation_suits()
        -- Singular: the name qualifies "cards", so it reads "Heart cards" the
        -- way vanilla's suit Jokers do - and the Leaf suit's plural is
        -- "Leaves", which would not read at all.
        return { vars = { localize(rotation_suit_at(suits, card.ability.extra.suit_index),
                                   "suits_singular") } }
    end,

    calculate = function(self, card, context)
        local suits = rotation_suits()
        local suit = rotation_suit_at(suits, card.ability.extra.suit_index)

        if context.repetition and context.cardarea == G.play then
            if context.other_card:is_suit(suit) then
                return { message = localize("k_again_ex"), repetitions = 1, card = card }
            end
        end

        -- main_eval keeps the rotation to once per round rather than once per
        -- card evaluated during the end-of-round pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            -- Through rotation_index so a misprinted index is written
            -- back whole: advancing 46.101724272927 by hand would only carry
            -- the fraction forward for the rest of the run.
            card.ability.extra.suit_index =
                rotation_index(card.ability.extra.suit_index + 1, #suits)
            local next_suit = rotation_suit_at(suits, card.ability.extra.suit_index)
            return {
                message = localize(next_suit, "suits_singular"),
                colour = G.C.SUITS[next_suit],
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Arielle [Legendary] - every card counts as every suit.
--------------------------------------------------------------------------------

-- Card:is_suit routes suit equivalence through SMODS.smeared_check, which is
-- how vanilla Smeared Joker merges Hearts/Diamonds and Spades/Clubs. Widening
-- it to always match while Arielle is out makes every card every suit, and
-- covers flushes, suit-gated jokers and enhancements from one place.
local smeared_check_ref = SMODS.smeared_check
function SMODS.smeared_check(card, suit)
    if CelestasMod.joker_in_play("j_celesta_arielle") then return true end
    -- ...or anything else that says every card is one suit. The Baulder Gang
    -- is a quad, and a quad replaces all four of its members, so the Arielle
    -- inside one is not in play as itself. See globals.lua.
    for _, rule in ipairs(CelestasMod.SAME_SUIT_RULES or {}) do
        local ok, same = pcall(rule)
        if ok and same then return true end
    end
    return smeared_check_ref(card, suit)
end

SMODS.Joker {
    key = "arielle",
    atlas = "arielle",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = false, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Deme [Uncommon] - X0.25 Mult per consecutive single-card hand.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "demenishki",
    atlas = "demenishki",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 1, x_mult_gain = 0.25 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult_gain, card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        -- context.before is where full_hand exists, and it lands ahead of
        -- scoring so a continued streak counts for the hand that extended it.
        if context.before and not context.blueprint then
            if #context.full_hand == 1 then
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "x_mult",
                    scalar_value = "x_mult_gain",
                    no_message = true,
                })
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { card.ability.extra.x_mult } },
                    colour = G.C.MULT, card = card,
                }
            elseif CelestasMod.more_than(card.ability.extra.x_mult, 1) then
                card.ability.extra.x_mult = 1
                return { message = localize("k_reset"), colour = G.C.RED, card = card }
            end
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- MOTHERv3 [Common] - after each hand, Exo a random unenhanced held card.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "motherv3",
    atlas = "motherv3",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = false, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Exo]
        return {}
    end,

    calculate = function(self, card, context)
        if context.after and not context.blueprint then
            if not G.hand then return end
            local candidates = {}
            for _, held in ipairs(G.hand.cards) do
                if held.config.center == G.P_CENTERS.c_base
                    and not held.celesta_mother_claimed then
                    candidates[#candidates + 1] = held
                end
            end
            if #candidates == 0 then return end

            local target = pseudorandom_element(candidates, pseudoseed("celesta_motherv3"))
            -- Claim immediately: set_ability is deferred, so a copy evaluating
            -- in the same pass would otherwise re-pick the same card.
            target.celesta_mother_claimed = true
            G.E_MANAGER:add_event(Event {
                func = function()
                    target:set_ability(G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Exo])
                    target:juice_up(0.3, 0.5)
                    target.celesta_mother_claimed = nil
                    return true
                end
            })
            return { message = localize("k_upgrade_ex"),
                     colour = G.C.SECONDARY_SET.Enhanced, card = card }
        end
    end,
}

--------------------------------------------------------------------------------
-- Michi [Uncommon] - Purple Seal cards give 2 Tarots on discard.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "michi",
    atlas = "michi",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_SEALS.Purple
        return {}
    end,

    calculate = function(self, card, context)
        -- The Purple Seal already makes one Tarot on discard; this adds the
        -- second, so the pair is the seal's own plus this one.
        if context.discard and context.other_card
            and context.other_card.seal == "Purple" and not context.blueprint then
            if #G.consumeables.cards + (G.GAME.consumeable_buffer or 0)
                >= G.consumeables.config.card_limit then
                return
            end
            G.GAME.consumeable_buffer = (G.GAME.consumeable_buffer or 0) + 1
            G.E_MANAGER:add_event(Event {
                trigger = "before",
                delay = 0.0,
                func = function()
                    local made = SMODS.add_card { set = "Tarot", key_append = "celesta_michi" }
                    if made then made:juice_up(0.3, 0.5) end
                    G.GAME.consumeable_buffer = 0
                    return true
                end
            })
            return { message = localize("k_plus_tarot"), colour = G.C.PURPLE, card = card }
        end
    end,
}

--------------------------------------------------------------------------------
-- Bear The Witch [Common] - Bonus cards give +20 extra Chips.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "bearthewitch",
    atlas = "bearthewitch",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 20 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_bonus
        return { vars = { card.ability.extra.chips } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play then
            if SMODS.has_enhancement(context.other_card, "m_bonus") then
                return { chips = card.ability.extra.chips, card = card }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Shoomimi [Rare] - 1 in 6 per shop reroll to gain a consumable slot.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "shoomimi",
    atlas = "shoomimi",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = false, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 6 } },

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "celesta_shoomimi")
        return CelestasMod.with_true_star_line("j_celesta_shoomimi", { vars = { n, d } })
    end,

    add_to_deck = announces("j_celesta_shoomimi"),

    calculate = function(self, card, context)
        -- True Stars in the deck are worth X Mult here; suits/true_stars.lua
        -- says what counts as one.
        if context.joker_main then
            local x_mult = CelestasMod.true_star_x_mult()
            if x_mult > 1 then return { x_mult = x_mult } end
        end

        if context.reroll_shop and not context.blueprint then
            if SMODS.pseudorandom_probability(card, "celesta_shoomimi", 1, card.ability.extra.odds) then
                G.consumeables.config.card_limit = G.consumeables.config.card_limit + 1
                return { message = localize("celesta_plus_slot"), colour = G.C.FILTER, card = card }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Chacha [Uncommon] - sells for an Uncommon or Rare Joker tag.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "chacha",
    atlas = "chacha",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = false,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        if context.selling_self and not context.blueprint then
            local tag_key = pseudorandom_element({ "tag_uncommon", "tag_rare" },
                pseudoseed("celesta_chacha"))
            G.E_MANAGER:add_event(Event {
                func = function()
                    add_tag(Tag(tag_key))
                    play_sound("generic1")
                    return true
                end
            })
            return { message = localize("celesta_plus_tag"), colour = G.C.FILTER, card = card }
        end
    end,
}

--------------------------------------------------------------------------------
-- OniGiri [Uncommon] - copies a random Joker, re-picked after each hand.
--------------------------------------------------------------------------------

--- Choose a fresh Joker for OniGiri to copy, never itself.
local function onigiri_repick(card)
    if not G.jokers then return end
    local options = {}
    for i, other in ipairs(G.jokers.cards) do
        if other ~= card and other.config.center.blueprint_compat then
            options[#options + 1] = i
        end
    end
    card.ability.extra.target = (#options > 0)
        and pseudorandom_element(options, pseudoseed("celesta_onigiri"))
        or nil
end

SMODS.Joker {
    key = "onigiri",
    atlas = "onigiri",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { target = nil } },

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    add_to_deck = function(self, card, from_debuff)
        onigiri_repick(card)
    end,

    calculate = function(self, card, context)
        -- Re-pick once the hand is fully resolved, so the target that was
        -- copied during scoring is the one shown for that hand.
        if context.after and not context.blueprint then
            onigiri_repick(card)
            return
        end

        -- An index rather than a stored card: jokers get sold, moved and
        -- destroyed between hands, and the index is refreshed every hand
        -- anyway. Guarded so a stale index cannot copy itself or nothing.
        local index = card.ability.extra.target
        if not index or not G.jokers then return end
        local target = G.jokers.cards[index]
        if not target or target == card then return end

        -- Same machinery Blueprint uses, so copy depth, blueprint_compat and
        -- the recursion guard are all handled for us.
        return SMODS.blueprint_effect(card, target, context)
    end,
}

--------------------------------------------------------------------------------
-- Papa Mutt [Common] - a Tarot when the hand is a Three of a Kind.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "papamutt",
    atlas = "papamutt",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return { vars = { localize("Three of a Kind", "poker_hands") } }
    end,

    calculate = function(self, card, context)
        -- Contains, not is: a Full House or a Four of a Kind holds a Three of
        -- a Kind too, and context.poker_hands lists every hand the played one
        -- contains - the question vanilla's own "contains" Jokers ask.
        if context.before and not context.blueprint
            and context.poker_hands
            and next(context.poker_hands["Three of a Kind"] or {}) then
            if #G.consumeables.cards + (G.GAME.consumeable_buffer or 0)
                >= G.consumeables.config.card_limit then
                return
            end
            G.GAME.consumeable_buffer = (G.GAME.consumeable_buffer or 0) + 1
            G.E_MANAGER:add_event(Event {
                trigger = "before",
                delay = 0.0,
                func = function()
                    local made = SMODS.add_card { set = "Tarot", key_append = "celesta_papamutt" }
                    if made then made:juice_up(0.3, 0.5) end
                    G.GAME.consumeable_buffer = 0
                    return true
                end
            })
            return { message = localize("k_plus_tarot"), colour = G.C.PURPLE, card = card }
        end
    end,
}

--------------------------------------------------------------------------------
-- CweamCat [Common] - gains Chips on a target hand, which then rerolls.
--------------------------------------------------------------------------------

--- Pick a new target poker hand, avoiding an immediate repeat. Mirrors how
--- vanilla To Do List rerolls, including the is_poker_hand_visible filter so
--- hands the run has not unlocked are never chosen.
---
--- `holder` is whichever table keeps the target in `.hand`: CweamCat's extra,
--- or BerryCrepe + CweamCat's pair state.
local function cweamcat_repick(holder)
    local hands = {}
    for k, _ in pairs(G.GAME.hands) do
        if SMODS.is_poker_hand_visible(k) then hands[#hands + 1] = k end
    end
    if #hands == 0 then return end
    local old = holder.hand
    local pick = old
    for _ = 1, 10 do
        pick = pseudorandom_element(hands, pseudoseed("celesta_cweamcat"))
        if pick ~= old then break end
    end
    holder.hand = pick
end

-- Shared with BerryCrepe + CweamCat in merge/bind.lua.
CelestasMod.cweamcat_repick = cweamcat_repick

SMODS.Joker {
    key = "cweamcat",
    atlas = "cweamcat",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 0, chip_gain = 24, hand = "Pair" } },

    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                card.ability.extra.chip_gain,
                localize(card.ability.extra.hand or "Pair", "poker_hands"),
                card.ability.extra.chips,
            },
        }
    end,

    add_to_deck = function(self, card, from_debuff)
        cweamcat_repick(card.ability.extra)
    end,

    calculate = function(self, card, context)
        -- Check before scoring, reroll after, so the hand shown when you play
        -- is the one that counts.
        if context.before and not context.blueprint then
            if context.scoring_name == card.ability.extra.hand then
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "chips",
                    scalar_value = "chip_gain",
                    no_message = true,
                })
                return {
                    message = localize { type = "variable", key = "a_chips",
                                         vars = { card.ability.extra.chips } },
                    colour = G.C.CHIPS, card = card,
                }
            end
        end

        if context.after and not context.blueprint then
            cweamcat_repick(card.ability.extra)
            return
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.chips, 0) then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- PandaBearLily [Common] - a single-card opening hand adds 2 of that suit.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "pandabearlily",
    atlas = "pandabearlily",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { cards = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.cards } }
    end,

    calculate = function(self, card, context)
        -- hands_played == 0 during context.before means this IS the first hand
        -- of the round; the counter only increments afterwards.
        if context.before and not context.blueprint
            and G.GAME.current_round.hands_played == 0
            and #context.full_hand == 1 then
            local suit = context.full_hand[1].base.suit
            if not suit then return end

            for _ = 1, card.ability.extra.cards do
                G.E_MANAGER:add_event(Event {
                    func = function()
                        -- Rank left nil so create_card rolls one; area is the
                        -- deck rather than the hand.
                        local made = SMODS.add_card {
                            set = "Base",
                            suit = suit,
                            area = G.deck,
                            key_append = "celesta_pandabearlily",
                        }
                        if made then made:start_materialize() end
                        return true
                    end
                })
            end

            return {
                message = localize("k_copied_ex"),
                colour = G.C.SUITS[suit] or G.C.CHIPS,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Bluto [Rare] - Blueprint and Brainstorm each trigger one extra time.
--------------------------------------------------------------------------------

-- Shared with Zentreya + Bluto in merge/bind.lua, which retriggers the same
-- two: one list, so a third copier taught to one is taught to both.
local BLUTO_TARGETS = { j_blueprint = true, j_brainstorm = true }
CelestasMod.BLUTO_TARGETS = BLUTO_TARGETS

SMODS.Joker {
    key = "bluto",
    atlas = "bluto",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.j_blueprint
        info_queue[#info_queue + 1] = G.P_CENTERS.j_brainstorm
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        -- The joker-retrigger pass. `not context.retrigger_joker` stops this
        -- from retriggering a retrigger, which would compound without bound.
        if context.retrigger_joker_check and not context.retrigger_joker then
            local other = context.other_card
            if other and other ~= card and other.config and other.config.center
                and BLUTO_TARGETS[other.config.center.key] then
                return { repetitions = card.ability.extra.repetitions }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Rosedoodle [Uncommon] - Mult cards may give X1.5 Mult when scored.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "rosedoodle",
    atlas = "rosedoodle",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 2, x_mult = 1.5 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_mult
        local n, d = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_rosedoodle")
        return { vars = { n, d, card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play then
            if SMODS.has_enhancement(context.other_card, "m_mult")
                and SMODS.pseudorandom_probability(
                    card, "celesta_rosedoodle", 1, card.ability.extra.odds) then
                return {
                    x_mult = card.ability.extra.x_mult,
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Nagzz [Common] - halves every listed probability.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "nagzz",
    atlas = "nagzz",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- mod_probability is the additive pass every SMODS.get_probability_vars
        -- call runs through, so this reaches every listed chance in the run
        -- rather than needing to be taught about each one. Doubling the
        -- denominator rather than halving the numerator keeps the odds
        -- readable as "1 in N" instead of turning into a fraction.
        if context.mod_probability then
            -- Only a number is doubled. The denominator is whatever the card
            -- asking passed in, and that is not always a number: Cryptid's
            -- RNJoker prints a joke as its odds, handing SMODS the string
            -- "The Entire Fucking Deck" (items/misc_joker.lua:4038), and
            -- doubling that took the game down on hover. A Talisman big
            -- number is a table, and doubles through its own metamethod.
            local d = context.denominator or 1
            local meta = type(d) == "table" and getmetatable(d)
            if type(d) ~= "number" and not (meta and meta.__mul) then return end
            return { denominator = d * 2 }
        end
    end,
}

--------------------------------------------------------------------------------
-- Baddaboom [Uncommon] - grows every time a Gash card breaks.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "baddaboom",
    atlas = "baddaboom",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_chips = 1, x_chips_gain = 0.75 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Gash]
        return { vars = { card.ability.extra.x_chips_gain, card.ability.extra.x_chips } }
    end,

    calculate = function(self, card, context)
        -- remove_playing_cards fires once after the destroy pass with every
        -- card that died, which is where vanilla Caino counts its face cards.
        -- Counting here rather than hooking the Gash roll means it catches a
        -- break however it happened.
        if context.remove_playing_cards and not context.blueprint then
            local broken = 0
            for _, removed in ipairs(context.removed or {}) do
                if SMODS.has_enhancement(removed, CelestasMod.ENHANCEMENT_KEYS.Gash) then
                    broken = broken + 1
                end
            end
            if broken > 0 then
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "x_chips",
                    scalar_value = "x_chips_gain",
                    message_key = "a_xchips",
                    message_colour = G.C.CHIPS,
                    operation = function(ref_table, ref_value, initial, scaling)
                        ref_table[ref_value] = initial + scaling * broken
                    end,
                })
            end
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_chips, 1) then
            return { x_chips = card.ability.extra.x_chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- x3Dustco [Legendary] - at the end of the shop, a Negative Joker from this mod.
--------------------------------------------------------------------------------

local MOD_JOKER_PREFIX = "j_" .. SMODS.current_mod.prefix .. "_"

-- Roll weights by rarity. Only tiers that actually have a candidate take part
-- in the roll, and the total is renormalised over those - otherwise an empty
-- tier would silently eat its share and, worse, a roll landing in it would
-- have to fall through to some arbitrary neighbour.
local X3_RARITY_WEIGHTS = { [1] = 0.60, [2] = 0.30, [3] = 0.09, [4] = 0.01 }

--- Pick a key from `buckets` (rarity -> list of keys) using X3_RARITY_WEIGHTS.
local function x3_weighted_pick(buckets)
    local total = 0
    for rarity, weight in pairs(X3_RARITY_WEIGHTS) do
        if buckets[rarity] and #buckets[rarity] > 0 then total = total + weight end
    end
    if total <= 0 then return nil end

    local roll = pseudorandom(pseudoseed("celesta_x3dustco_rarity")) * total
    local chosen
    for rarity = 1, 4 do
        local weight = X3_RARITY_WEIGHTS[rarity]
        if weight and buckets[rarity] and #buckets[rarity] > 0 then
            roll = roll - weight
            if roll <= 0 then chosen = rarity break end
        end
    end
    -- Floating point can leave `roll` a hair above zero on the last tier.
    if not chosen then
        for rarity = 4, 1, -1 do
            if buckets[rarity] and #buckets[rarity] > 0 then chosen = rarity break end
        end
    end
    if not chosen then return nil end
    return pseudorandom_element(buckets[chosen], pseudoseed("celesta_x3dustco"))
end

SMODS.Joker {
    key = "x3dustco",
    atlas = "x3dustco",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        -- Read straight off the weight table so the printed odds can never
        -- drift from the odds actually rolled.
        return {
            vars = {
                X3_RARITY_WEIGHTS[1] * 100,
                X3_RARITY_WEIGHTS[2] * 100,
                X3_RARITY_WEIGHTS[3] * 100,
                X3_RARITY_WEIGHTS[4] * 100,
            },
        }
    end,

    calculate = function(self, card, context)
        if context.ending_shop and not context.blueprint then
            if not G.jokers then return end
            -- No room check and no joker_buffer: what this makes is Negative,
            -- and a Negative Joker brings its own slot with it (its edition's
            -- add_to_deck raises the limit), so a full row is not a reason not
            -- to make one.

            -- Built from the live Joker pool rather than a hardcoded list, so
            -- it picks up anything added later automatically. add_to_pool is
            -- what keeps the unimplemented placeholders out - they return
            -- false from in_pool - and itself is excluded so it cannot clone.
            -- Bucketed by rarity so the weights below decide the tier first
            -- and the specific Joker second; picking uniformly from one flat
            -- list would just mirror how many of each tier happen to exist.
            -- Modded non-numeric rarities are skipped: they have no weight.
            local buckets = {}
            for _, center in ipairs(G.P_CENTER_POOLS.Joker or {}) do
                if center.key and center.key:find(MOD_JOKER_PREFIX, 1, true) == 1
                    and center ~= card.config.center
                    and type(center.rarity) == "number"
                    and X3_RARITY_WEIGHTS[center.rarity]
                    and SMODS.add_to_pool(center) then
                    buckets[center.rarity] = buckets[center.rarity] or {}
                    table.insert(buckets[center.rarity], center.key)
                end
            end

            local chosen = x3_weighted_pick(buckets)
            if not chosen then return end
            G.E_MANAGER:add_event(Event {
                func = function()
                    -- The edition is set before add_to_deck runs (SMODS'
                    -- create_card, utils.lua:392), which is what grants the
                    -- slot in time for the card that is using it.
                    local made = SMODS.add_card {
                        key = chosen, edition = "e_negative" }
                    if made then made:start_materialize() end
                    return true
                end
            })

            return {
                message = localize("k_plus_joker"),
                colour = G.C.BLUE,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Limealicious [Uncommon] - a Limestone card each round.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "limealicious",
    atlas = "limealicious",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = false, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Limestone]
        return CelestasMod.with_true_star_line("j_celesta_limealicious", {})
    end,

    calculate = function(self, card, context)
        -- True Stars in the deck are worth X Mult here; suits/true_stars.lua
        -- says what counts as one.
        if context.joker_main then
            local x_mult = CelestasMod.true_star_x_mult()
            if x_mult > 1 then return { x_mult = x_mult } end
        end

        -- Same shape as vanilla Marble Joker: build it in G.play so the player
        -- sees it, then animate it into the deck.
        if context.setting_blind
            and not (context.blueprint_card or card).getting_sliced then
            -- TEMPORARY trace: why only one of several Laimus seems to add a card.
            local function laimu_trace(what)
                if not sendInfoMessage then return end
                local limestones = 0
                for _, held in ipairs(G.playing_cards or {}) do
                    if SMODS.has_enhancement(held, CelestasMod.ENHANCEMENT_KEYS.Limestone) then
                        limestones = limestones + 1
                    end
                end
                sendInfoMessage(("[laimu] %s: laimu sort_id=%s blueprint=%s play=%s deck=%s limestone_in_deck_count=%s")
                    :format(what, tostring(card.sort_id), tostring(context.blueprint_card ~= nil),
                            tostring(G.play and #G.play.cards), tostring(G.deck and #G.deck.cards),
                            tostring(limestones)), "CelestasMod")
            end
            laimu_trace("setting_blind")
            G.E_MANAGER:add_event(Event {
                func = function()
                    local new_card = create_playing_card(
                        { front = pseudorandom_element(G.P_CARDS, pseudoseed("celesta_lime")),
                          center = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Limestone] },
                        G.play, nil, nil, { G.C.SECONDARY_SET.Enhanced })
                    laimu_trace("created " .. tostring(new_card and new_card.sort_id))

                    SMODS.calculate_effect({
                        message = localize("celesta_plus_limestone"),
                        colour = G.C.SECONDARY_SET.Enhanced,
                    }, context.blueprint_card or card)

                    G.E_MANAGER:add_event(Event {
                        func = function()
                            laimu_trace("before draw")
                            draw_card(G.play, G.deck, 90, "up", nil)
                            G.E_MANAGER:add_event(Event {
                                func = function()
                                    laimu_trace("after draw")
                                    return true
                                end
                            })
                            return true
                        end
                    })
                    playing_card_joker_effects({ new_card })
                    return true
                end
            })
        end
    end,
}

--------------------------------------------------------------------------------
-- Jax [Uncommon] - retriggers Stone and Limestone cards.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "jaxvtuber",
    atlas = "jaxvtuber",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_stone
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Limestone]
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play then
            local other = context.other_card
            if other and (SMODS.has_enhancement(other, "m_stone")
                or SMODS.has_enhancement(other, CelestasMod.ENHANCEMENT_KEYS.Limestone)) then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Yuzu [Common] - held Limestone cards may pay out when a hand is played.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "yuzu",
    atlas = "yuzu",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 2, dollars = 3 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Limestone]
        local n, d = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "celesta_yuzu")
        return { vars = { n, d, card.ability.extra.dollars } }
    end,

    calculate = function(self, card, context)
        -- The held-in-hand pass, which runs while a hand is being played -
        -- and not the one at the end of the round, or the payout lands a
        -- second time on the cash-out screen. See AxialMatt for why that pass
        -- reaches a modded Joker at all.
        if context.individual and context.cardarea == G.hand
            and not context.end_of_round then
            local other = context.other_card
            if other and SMODS.has_enhancement(other, CelestasMod.ENHANCEMENT_KEYS.Limestone)
                and SMODS.pseudorandom_probability(
                    card, "celesta_yuzu", 1, card.ability.extra.odds) then
                return {
                    dollars = card.ability.extra.dollars,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Jowol [Common] - held Stone cards give Chips.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "jowol",
    atlas = "jowol",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 50 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_stone
        return { vars = { card.ability.extra.chips } }
    end,

    calculate = function(self, card, context)
        -- joker_main runs after the played cards and the held-in-hand pass
        -- have both scored, which is the "after cards in hand finish scoring"
        -- slot. Counted here rather than per-card so one popup covers them all.
        if context.joker_main then
            if not G.hand then return end
            local stones = 0
            for _, held in ipairs(G.hand.cards) do
                if SMODS.has_enhancement(held, "m_stone") then stones = stones + 1 end
            end
            if stones > 0 then
                return { chips = card.ability.extra.chips * stones }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Neuro [Rare] - clears unenhanced cards out of hand at end of round.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "neuro",
    atlas = "neuro",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    -- last_round is how it fires once per round; see calculate.
    config = { extra = { last_round = -1 } },

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- Modelled on Cryptid's SUS, which does the same job at the same
        -- moment and demonstrably works alongside this mod. Two things taken
        -- from it, both of which this had wrong:
        --
        -- The gate is cardarea == G.jokers, which is what marks the
        -- once-per-round joker pass. This used context.main_eval instead. That
        -- is set around the same call, but only by SMODS.calculate_context,
        -- which reaches jokers through a lovely patch over vanilla's direct
        -- calculate_joker; cardarea is set by the card-area walk itself and
        -- does not depend on that patch holding.
        --
        -- The cards are dissolved directly rather than through
        -- SMODS.destroy_cards. That helper raises a nested
        -- SMODS.calculate_context({ remove_playing_cards = ... }) - a fresh
        -- evaluation pass from inside the end-of-round pass. Cryptid
        -- explicitly does not do that here, noting it makes the removal
        -- effects trigger repeatedly.
        if context.end_of_round and context.cardarea == G.jokers
            and not context.blueprint then
            if not (G.hand and G.GAME and #G.hand.cards >= 1) then return end

            -- Once per round: end_of_round reaches a joker more than once.
            local round = G.GAME.round
            if card.ability.extra.last_round == round then return end

            local doomed = {}
            for _, held in ipairs(G.hand.cards) do
                if held.config.center == G.P_CENTERS.c_base
                    and not held.getting_sliced
                    and not SMODS.is_eternal(held) then
                    doomed[#doomed + 1] = held
                end
            end
            if #doomed == 0 then return end
            card.ability.extra.last_round = round

            G.E_MANAGER:add_event(Event {
                trigger = "after",
                delay = 0.1,
                func = function()
                    -- Say what died, once, before any of it does.
                    --
                    -- Nekrolina counts deaths off this context and so does
                    -- every other pair that is paid by one - it is raised once
                    -- after a destroy pass with every card that went, which is
                    -- where vanilla Caino counts its face cards. Without it
                    -- these three cards died silently and only the Gash card
                    -- breaking elsewhere was ever counted.
                    --
                    -- Raised here rather than by calling SMODS.destroy_cards,
                    -- and the note above still says why: that helper raises
                    -- this synchronously, and Neuro DECIDES during the
                    -- end-of-round pass, so calling it there would open an
                    -- evaluation inside the one already running. This event is
                    -- not that moment - it runs once the pass has finished, so
                    -- the context is raised with nothing nested inside it.
                    --
                    -- Before the dissolving, the order destroy_cards uses
                    -- (utils.lua:2593 raises, :2595 dissolves), so a Joker
                    -- asked about a card that died can still look at it.
                    SMODS.calculate_context({
                        remove_playing_cards = true,
                        removed = doomed,
                    })

                    -- Backwards, and only the last one animates: removing from
                    -- a list while walking it forwards skips entries, and that
                    -- flag is what stops every card playing the sound at once.
                    for i = #doomed, 1, -1 do
                        local held = doomed[i]
                        if SMODS.shatters(held) then
                            held:shatter()
                        else
                            held:start_dissolve(nil, i == #doomed)
                        end
                    end
                    return true
                end,
            })

            return {
                message = localize("celesta_cleared"),
                colour = G.C.RED,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Pomatomaster [Common] - Exo... Eutrophic, on the lowest held card.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "pomatomaster",
    atlas = "pomatomaster",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Eutrophic]
        return {}
    end,

    calculate = function(self, card, context)
        if context.after and not context.blueprint then
            if not G.hand then return end

            local target, lowest
            for _, held in ipairs(G.hand.cards) do
                if held.config.center == G.P_CENTERS.c_base
                    and not held.celesta_poma_claimed then
                    -- get_id is the rank's numeric value, so this is a plain
                    -- minimum. Ties resolve to the leftmost card.
                    local id = held:get_id()
                    if id and (not lowest or id < lowest) then
                        lowest, target = id, held
                    end
                end
            end
            if not target then return end

            target.celesta_poma_claimed = true
            G.E_MANAGER:add_event(Event {
                func = function()
                    target:set_ability(
                        G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Eutrophic], nil, true)
                    target:juice_up(0.3, 0.5)
                    target.celesta_poma_claimed = nil
                    return true
                end
            })
            return {
                message = localize("k_upgrade_ex"),
                colour = G.C.SECONDARY_SET.Enhanced,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Jaws [Common] - eats the cards that did not score.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "jaws",
    atlas = "jaws",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 0, chip_gain = 5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.chip_gain, card.ability.extra.chips } }
    end,

    calculate = function(self, card, context)
        -- The destroy pass marks non-scoring played cards with cardarea
        -- 'unscored'; scoring ones get G.play and destroying_card instead.
        if context.destroy_card and context.cardarea == "unscored"
            and not context.blueprint then
            -- calculate_destroying_cards acts on `remove` without checking
            -- eternal itself, so guard here or Jaws eats eternal cards. No
            -- destruction means no growth, hence the early return.
            if SMODS.is_eternal(context.destroy_card) then return end

            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "chips",
                scalar_value = "chip_gain",
                no_message = true,
            })
            return {
                remove = true,
                message = localize { type = "variable", key = "a_chips",
                                     vars = { card.ability.extra.chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.chips, 0) then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- Meicha [Common] - straights wrap around.
--------------------------------------------------------------------------------

-- SMODS.wrap_around_straight is an extension point that returns false by
-- default; the straight PokerHandPart passes its result into get_straight as
-- the `wrap` argument. Widening it here means Ace can bridge King and 2
-- without this having to know anything about straight detection itself.
local wrap_around_straight_ref = SMODS.wrap_around_straight
function SMODS.wrap_around_straight()
    if CelestasMod.joker_in_play("j_celesta_meicha") then return true end
    return wrap_around_straight_ref()
end

SMODS.Joker {
    key = "meicha",
    atlas = "meicha",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- AiCandii [Common] - paid for the discards you did not need.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "aicandii",
    atlas = "aicandii",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { mult = 0, mult_gain = 4 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.mult_gain, card.ability.extra.mult } }
    end,

    calculate = function(self, card, context)
        -- main_eval keeps this to the one once-per-round joker pass rather
        -- than firing again for every card evaluated at end of round.
        if context.end_of_round and context.main_eval and not context.blueprint then
            local unused = G.GAME.current_round.discards_left or 0
            if unused <= 0 then return end
            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "mult",
                scalar_value = "mult_gain",
                message_key = "a_mult",
                message_colour = G.C.MULT,
                operation = function(ref_table, ref_value, initial, scaling)
                    ref_table[ref_value] = initial + scaling * unused
                end
            })
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.mult, 0) then
            return { mult = card.ability.extra.mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Hannah Hyrule [Uncommon] - a last-hand multiplier on both halves.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "hannahhyrule",
    atlas = "hannahhyrule",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x = 1.5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x } }
    end,

    calculate = function(self, card, context)
        -- hands_left == 0 is how vanilla Dusk detects the final hand.
        if context.joker_main and G.GAME.current_round.hands_left == 0 then
            return {
                x_mult = card.ability.extra.x,
                x_chips = card.ability.extra.x,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- BeriBug [Common] - retriggers 8s.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "beribug",
    atlas = "beribug",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play then
            local other = context.other_card
            -- get_id is the rank's numeric value; 8 is literally 8.
            if other and other.get_id and other:get_id() == 8 then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Smug Alana [Uncommon] - melting ice takes a sticker with it.
--------------------------------------------------------------------------------
--
-- The strip itself lives in CelestasMod.thaw (editions/frozen.lua), so melting
-- has one definition wherever it is triggered from. This joker only has to
-- exist for that path to fire - it checks for it by key.

SMODS.Joker {
    key = "smugalana",
    atlas = "smugalana",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- AmaLee [Rare] - brings the Snowstorm, which freezes Jokers.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "amalee",
    atlas = "amalee",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = false, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 4 } },

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "celesta_amalee")
        return { vars = { n, d } }
    end,

    calculate = function(self, card, context)
        if context.setting_blind and not context.blueprint then
            if not CelestasMod.Arena.is_active("snowstorm") then
                CelestasMod.Arena.start("snowstorm")
                return {
                    message = localize("celesta_snowstorm"),
                    colour = G.C.BLUE,
                    card = card,
                }
            end
            return
        end

        -- After each played hand, while the storm is up.
        if context.after and not context.blueprint
            and CelestasMod.Arena.is_active("snowstorm") then
            if not SMODS.pseudorandom_probability(
                    card, "celesta_amalee", 1, card.ability.extra.odds) then
                return
            end
            if not G.jokers then return end

            -- Only Jokers that are not already frozen; freezing a frozen card
            -- would silently reset its timer.
            local options = {}
            for _, joker in ipairs(G.jokers.cards) do
                if not CelestasMod.is_frozen(joker) then
                    options[#options + 1] = joker
                end
            end
            if #options == 0 then return end

            local target = pseudorandom_element(options, pseudoseed("celesta_amalee_pick"))
            if CelestasMod.freeze(target) then
                return {
                    message = localize("celesta_frozen"),
                    colour = G.C.BLUE,
                    card = target,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Nothing freezes an AmaLee, or anything merged with one.
--------------------------------------------------------------------------------
--
-- CelestasMod.freeze is the one place a Joker is frozen from - AmaLee itself,
-- Vulpixie and the Snowstorm all end up there - so wrapping it catches every
-- route, and refusing rather than thawing keeps the answer honest for the
-- callers that pay out on a freeze. Cryogen's immunity and the Wildcard Club's
-- are the same shape, and the three sit on top of each other without any of
-- them having to know about the others.
--
-- Bind.members_of rather than a centre compare: it answers with every key a
-- card carries - one loose, two merged, four quad-merged - so "anything merged
-- with AmaLee" needs no special case, and neither does AmaLee on its own.

local AMALEE_KEY = "j_celesta_amalee"

local celesta_amalee_freeze_ref = CelestasMod.freeze
if celesta_amalee_freeze_ref then
    function CelestasMod.freeze(card, rounds)
        local Bind = CelestasMod.Bind
        if card and Bind and Bind.members_of then
            for _, key in ipairs(Bind.members_of(card)) do
                if key == AMALEE_KEY then return false end
            end
        end
        return celesta_amalee_freeze_ref(card, rounds)
    end
end

--------------------------------------------------------------------------------
-- Vulpixie [Uncommon] - frozen Jokers keep working.
--------------------------------------------------------------------------------
--
-- The check lives in the Card.calculate_joker hook in editions/frozen.lua,
-- which looks this joker up by key. Cancelling the failure there rather than
-- here means it covers every frozen Joker at once, including ones that
-- evaluate before this one in the row.

SMODS.Joker {
    key = "vulpixie",
    atlas = "vulpixie",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Cy Yu [Rare] - retriggers Exo cards.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "cyyuvtuber",
    atlas = "cyyuvtuber",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 2 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Exo]
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play then
            local other = context.other_card
            if other and SMODS.has_enhancement(other, CelestasMod.ENHANCEMENT_KEYS.Exo) then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Vedal [Legendary]
-- Scaling Jokers scale as n^x, and x goes up by one every time one scales.
--------------------------------------------------------------------------------
--
-- Cryptid's Scalae is the shape this follows. Every Joker that grows a number
-- over a run goes through SMODS.scale_card (utils.lua:2865) - it reads the
-- rate out of the card, applies it, and prints the message - so one hook there
-- reaches every scaling Joker in the game, this mod's and everyone else's,
-- without having to know anything about any of them.
--
-- Where Scalae raises a fixed degree once a round, this raises it once per
-- scale, per Joker, per value: the nth time a Joker scales a number, it scales
-- by its own rate times n^x, and x goes up by one straight afterwards. x
-- starts at 1, so the first scale is untouched and the acceleration is all
-- afterwards:
--
--     +1 Mult a hand  ->  +1, +4, +27, +256
--     +4 Chips a hand ->  +4, +16, +108, +1024
--
-- Hooked at SMODS.scale_card rather than through a calc_scaling on the centre,
-- which is the door Scalae uses. calc_scaling is dispatched off
-- _card.config.center, and a merged Vedal is not its own centre any more - the
-- host's is - so an absorbed Vedal would have gone quietly dead. Asking
-- find_joker instead is the lookup this mod keeps for exactly that, and it
-- answers for either half. It also means two Vedals advance the exponent once
-- between them rather than twice, which dispatching per card would not.

local VEDAL_KEY = "j_celesta_vedal"

--- How much x goes up by after each scale, before anything widens it.
CelestasMod.VEDAL_EXPONENT_STEP = 1

--- ...and what it actually goes up by right now.
---
--- Ellie Minibot + Vedal doubles it, which is what "scales twice as fast"
--- means here: the exponent climbs two at a time rather than one, so the
--- second scale is already the third one it would otherwise have been.
---
--- Asked rather than cached, for the reason kuro_sync asks rather than
--- caching: the pair can be made, sold or debuffed between one scale and the
--- next. The rules live in globals.lua and merge/bind.lua fills them in.
function CelestasMod.vedal_step()
    local step = CelestasMod.VEDAL_EXPONENT_STEP
    for _, rule in ipairs(CelestasMod.VEDAL_SCALE_RULES or {}) do
        local ok, factor = pcall(rule)
        if ok and type(factor) == "number" then step = step * factor end
    end
    return step
end

--- The exponent the FIRST scale uses, which is why a Joker's opening scale is
--- the one it would have had without Vedal.
CelestasMod.VEDAL_FIRST_EXPONENT = 1

--- What `other` has done so far for the value being scaled.
---
--- Kept on the scaling Joker's own ability table, so selling that Joker takes
--- its progress with it and a save carries it. Keyed by the scalar's NAME,
--- because one Joker can grow several numbers independently and they each
--- deserve their own count - Cryptid's Compound Interest scales two.
---
--- `scalar` is the rate as it was BEFORE Vedal first touched it. Every step is
--- computed from that rather than from the rate now on the card, which this
--- has already rewritten; reading it back would fold the exponent into itself
--- and the number would leave the universe on about the third scale.
local function vedal_progress(other, name, current_scalar)
    local info = other.ability.celesta_vedal
    if not info then
        info = {}
        other.ability.celesta_vedal = info
    end

    local seen = info[name]
    if not seen then
        seen = { scalar = current_scalar, n = 0,
                 x = CelestasMod.VEDAL_FIRST_EXPONENT }
        info[name] = seen
    end
    return seen
end

--- n^x, in Talisman's arithmetic where it is loaded.
---
--- n^n passes what a double can hold at about n = 144, which is an ordinary
--- number of hands for a Joker that scales every one of them. Talisman is a
--- declared dependency and its numbers go where doubles cannot; without it
--- this is a plain power, and a Joker that scales that many times will reach
--- infinity, which is the same thing that happens to everything else in the
--- run at that point.
local function vedal_power(n, x)
    if type(to_big) == "function" then return to_big(n) ^ x end
    return n ^ x
end

--- Rewrites the rate `card` is about to scale by, if Vedal is out to do it.
---
--- The rate is written back into the Joker's own table rather than handed
--- back, because that is where SMODS.scale_card reads it from - and leaving it
--- written is deliberate: the card's tooltip then advertises the rate it will
--- actually grow by, and a Vedal sold mid-run leaves behind what it already
--- did, the way Scalae does.
local function vedal_rewrite(card, args)
    if not (card and args and args.scalar_value) then return end
    if not (card.ability and card.ability.set == "Joker") then return end

    -- Vedal does not scale Vedal, either half of a merged one. Counted with
    -- debuffed included: a debuffed Vedal does no work, but it is still not
    -- something the other one should be accelerating.
    if CelestasMod.card_is_joker(card, VEDAL_KEY, true) then return end
    if not next(CelestasMod.find_joker(VEDAL_KEY)) then return end

    local scalar_table = args.scalar_table or args.ref_table
        or (card.ability and card.ability.extra)
    if type(scalar_table) ~= "table" then return end

    local current = scalar_table[args.scalar_value]
    -- A rate that is not arithmetic is not something to raise to a power. The
    -- lesson is Adfree's: another mod put a joke string where SMODS expects a
    -- number, and multiplying it took the run down.
    local meta = type(current) == "table" and getmetatable(current)
    if type(current) ~= "number" and not (meta and meta.__mul) then return end

    local seen = vedal_progress(card, tostring(args.scalar_value), current)
    seen.n = seen.n + 1
    scalar_table[args.scalar_value] = seen.scalar * vedal_power(seen.n, seen.x)
    seen.x = seen.x + CelestasMod.vedal_step()
end

--- The most terms this will raise before it gives up and adds the rest flat.
--- Far past any real run - a Blind can only be skipped so many times - and
--- here so that a counter this file does not own cannot turn a hover into a
--- thousand big-number powers.
CelestasMod.VEDAL_COUNT_STEPS = 1000

--- Vedal's arithmetic for a Joker that COUNTS rather than banks.
---
--- A banked Joker that has scaled n times has added
--- rate*1^1 + rate*2^2 + ... + rate*n^n, one term per scale, because the hook
--- below rewrites the rate each time it comes through. A counted Joker never
--- comes through: it has no stored total to add to and no rate to rewrite, it
--- simply reads a number off the run. So it asks for the same sum outright.
---
--- Green Card is the one that does. Its counter is G.GAME.skips, which only
--- ever goes up, and that is the whole test of whether a counted Joker belongs
--- here: Fufu counts the suits in the deck and Nyanners the Jokers in the row,
--- and both of those FALL when you lose one. A number that can go down is not
--- scaling, whatever it looks like on a good run.
---
--- Nothing is stored, which is the one place this differs from the hook. A
--- Vedal sold mid-run leaves a banked Joker holding everything it already
--- gained, and takes the acceleration straight back off a counted one. That is
--- the counted Joker's own bargain - every part of its value is read fresh,
--- and this is now part of it.
function CelestasMod.vedal_counted(card, gain, count)
    if type(count) ~= "number" or count <= 0 then return gain * 0 end

    -- Vedal does not accelerate Vedal, either half of a merged one, and the
    -- acceleration needs a Vedal in the row at all. Both asked the way the
    -- hook below asks them.
    if card and CelestasMod.card_is_joker(card, VEDAL_KEY, true) then
        return gain * count
    end
    if not next(CelestasMod.find_joker(VEDAL_KEY)) then return gain * count end

    local steps = math.min(math.floor(count), CelestasMod.VEDAL_COUNT_STEPS)
    local total = type(to_big) == "function" and to_big(0) or 0
    local x = CelestasMod.VEDAL_FIRST_EXPONENT
    -- Read once rather than per term: the row cannot change inside the loop,
    -- and asking a thousand times would walk the Joker row a thousand times.
    local step = CelestasMod.vedal_step()
    for n = 1, steps do
        total = total + vedal_power(n, x)
        x = x + step
    end
    -- Past the cap, flat. Unreachable in a run, and better than a hang.
    if count > steps then total = total + (count - steps) end
    return total * gain
end

local celesta_vedal_scale_ref = SMODS.scale_card

function SMODS.scale_card(card, args, ...)
    -- Before the reference, because scale_card reads the rate out of the
    -- table on its first line and everything after - the arithmetic and the
    -- message the player sees - uses that one read.
    local ok, err = pcall(vedal_rewrite, card, args)
    if not ok then
        CelestasMod.warn_once("vedal_scale",
            ("Vedal could not scale that: %s"):format(tostring(err)))
    end
    return celesta_vedal_scale_ref(card, args, ...)
end

SMODS.Joker {
    key = "vedal",
    atlas = "vedal",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    -- The one joker in the mod that opts out of copying, per its own text.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return { vars = { CelestasMod.VEDAL_EXPONENT_STEP } }
    end,
}

--------------------------------------------------------------------------------
-- Liffeh [Common]
-- 1 in 4 chance to gain a Negative copy of any Tarot card you gain.
--------------------------------------------------------------------------------

CelestasMod.LIFFEH_ODDS = 4

-- Set while the bonus Tarot is being created, so the bonus cannot roll a
-- bonus of its own.
local liffeh_creating = false

--- The first Liffeh in play that is able to act, or the CDawg holding one.
local function liffeh_active()
    -- The card in the row rather than the half's ability: what this is for is
    -- the probability roll below, which wants the object the run can see.
    local found = CelestasMod.find_joker("j_celesta_liffeh")[1]
    if found then return found.card end
    -- ...and a sold one CDawg is still running. Nothing here is a calculate,
    -- so CDawg's own lend never reaches it; see jokers/cdawg.lua. The roll and
    -- the popup land on CDawg, which is the card doing it.
    return CelestasMod.cdawg_running
        and CelestasMod.cdawg_running("j_celesta_liffeh") or nil
end

-- Every route by which a Tarot is gained - The Fool, purple seals, The
-- Emperor, booster packs, shop purchases - ends in the same three lines:
-- create_card of a Tarot into G.consumeables, then card:add_to_deck(), then
-- G.consumeables:emplace(card). Hooking add_to_deck catches all of them from
-- one place, including Tarots added by other mods.
--
-- Loading a save does NOT come through here: CardArea:load builds its cards
-- and appends them to self.cards directly, without add_to_deck or emplace. A
-- run reloaded with six Tarots in hand will not hand out six more.
local celesta_liffeh_add_to_deck_ref = Card.add_to_deck
function Card:add_to_deck(from_debuff)
    -- add_to_deck guards its own body with self.added_to_deck, so read the
    -- flag first: a second call on the same card is a no-op and must not roll.
    local first_time = not self.added_to_deck
    celesta_liffeh_add_to_deck_ref(self, from_debuff)

    if not first_time or liffeh_creating then return end
    if not (self.ability and self.ability.set == "Tarot") then return end
    if not (G.GAME and G.consumeables and G.consumeables.config) then return end

    local liffeh = liffeh_active()
    if not liffeh then return end

    -- The copy is Negative, and a Negative consumable brings its own slot, so
    -- there is no room to run out of and no consumeable_buffer to reserve.
    local key = self.config and (self.config.center_key
        or (self.config.center and self.config.center.key))
    if not key then return end

    if not SMODS.pseudorandom_probability(
        liffeh, "celesta_liffeh", 1, CelestasMod.LIFFEH_ODDS, "celesta_liffeh") then
        return
    end

    G.E_MANAGER:add_event(Event {
        trigger = "before",
        delay = 0.0,
        func = function()
            liffeh_creating = true
            -- A Negative duplicate of the card that triggered it, not a fresh
            -- roll: the key is captured above rather than read here, because
            -- by the time this event runs the Tarot may already have been
            -- used and turned into something else.
            SMODS.add_card { key = key, area = G.consumeables,
                             edition = "e_negative" }
            liffeh_creating = false
            return true
        end,
    })
    card_eval_status_text(liffeh, "extra", nil, nil, nil,
        { message = localize("k_plus_tarot"), colour = G.C.PURPLE })
end

SMODS.Joker {
    key = "liffeh",
    atlas = "liffeh",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = CelestasMod.LIFFEH_ODDS } },

    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_liffeh")
        return { vars = { numerator, denominator } }
    end,
}

--------------------------------------------------------------------------------
-- Birdyovo [Common]
-- Every 7 scored cards gives X2 Mult.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "birdyovo",
    atlas = "birdyovo",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    -- count carries across hands and rounds, so the seventh card is the
    -- seventh Birdyovo has ever seen, not the seventh of this hand.
    config = { extra = { x_mult = 2, requirement = 7, count = 0 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        local to_go = extra.requirement - (extra.count % extra.requirement)
        return { vars = { extra.requirement, extra.x_mult, to_go } }
    end,

    calculate = function(self, card, context)
        -- context.individual with cardarea == G.play is the scoring-card pass;
        -- unscored cards arrive with cardarea set to unscored instead.
        if context.individual and context.cardarea == G.play then
            local extra = card.ability.extra
            -- A copy must not advance the count - the cards were scored once.
            -- It still pays out on a card that lands on the seventh, so a
            -- Blueprint doubles the payoff rather than shifting the rhythm.
            if not context.blueprint then
                extra.count = extra.count + 1
            end
            if extra.count % extra.requirement == 0 then
                return { x_mult = extra.x_mult, card = card }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Mint Fantome [Common]
-- When the played hand finishes scoring, score the leftmost card held in hand.
--------------------------------------------------------------------------------

-- Set while the held card is being scored, so the pass cannot re-enter.
local mintfantome_scoring = false

SMODS.Joker {
    key = "mintfantome",
    atlas = "mintfantome",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- Timing. context.after reads like the obvious hook and is the wrong
        -- one: vanilla reads hand_chips*mult and commits the score at
        -- state_events.lua:1031, then fires `after` at :1070, so anything
        -- scored there would add nothing to the hand.
        --
        -- The held-in-hand pass (:798) is the first thing that runs once every
        -- played card has finished scoring, and it still lands before the
        -- commit. Reacting to the leftmost held card there is both the right
        -- moment and the last one that counts.
        if context.individual and context.cardarea == G.hand
            and not context.end_of_round and not mintfantome_scoring then
            local target = G.hand and G.hand.cards and G.hand.cards[1]
            if not target or context.other_card ~= target then return end
            -- A debuffed card scores nothing, the same as in the played hand.
            if target.debuff then return end

            -- A fresh context rather than the live one: SMODS.score_card sets
            -- main_scoring, individual and other_card as it goes, and
            -- clobbering the table the caller is still iterating would corrupt
            -- the rest of the held pass.
            --
            -- cardarea = G.play is what makes this scoring rather than another
            -- held trigger. Every joker watching for a scored card sees this
            -- one, and the card contributes its chips, enhancement, edition
            -- and seal exactly as a played card would.
            mintfantome_scoring = true
            local ok, err = pcall(SMODS.score_card, target, {
                cardarea = G.play,
                full_hand = context.full_hand,
                scoring_hand = context.scoring_hand,
                scoring_name = context.scoring_name,
                poker_hands = context.poker_hands,
            })
            mintfantome_scoring = false

            if not ok then
                CelestasMod.warn_once("mintfantome_score",
                    "Mint Fantome could not score the leftmost held card: "
                    .. tostring(err))
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Bricky [Uncommon]
-- +20 Chips for each Stone or Limestone card in the full deck.
--------------------------------------------------------------------------------

--- Counts the Stone and Limestone cards in the run's full deck.
--- Read live rather than kept as a running tally. Vanilla Stone Joker caches
--- one in ability.stone_tally and has to refresh it from several places; a
--- 52-card walk once per hover and once per hand is not worth that risk of
--- drifting out of sync when cards are added, destroyed or re-enhanced.
local function bricky_tally(_)
    if not G.playing_cards then return 0 end
    local limestone = CelestasMod.ENHANCEMENT_KEYS.Limestone
    local tally = 0
    for _, playing_card in pairs(G.playing_cards) do
        if SMODS.has_enhancement(playing_card, "m_stone")
            or SMODS.has_enhancement(playing_card, limestone) then
            tally = tally + 1
        end
    end
    return tally
end

SMODS.Joker {
    key = "bricky",
    atlas = "bricky",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chip_mod = 20 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_stone
        info_queue[#info_queue + 1] =
            G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Limestone]
        local chip_mod = card.ability.extra.chip_mod
        return { vars = { chip_mod, chip_mod * bricky_tally(card) } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            local chips = card.ability.extra.chip_mod * bricky_tally(card)
            if chips > 0 then
                return { chips = chips }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- AxialMatt [Common]
-- Adds double the rank of the highest ranked card held in hand to Mult.
--------------------------------------------------------------------------------

--- The card AxialMatt raises, and the Mult it is worth.
---
--- Mirrors vanilla Raised Fist exactly, inverted to pick the highest:
---   * chosen by base.id (the rank) but valued by base.nominal (the chip
---     value). A King is 2x10 = +20 and an Ace 2x11 = +22 - NOT 2x13 and
---     2x14. Raised Fist reads those two fields off different cards' worth
---     of meaning and this has to match it.
---   * rankless cards are skipped through SMODS.has_no_rank. That is exactly
---     what Steamodded patches vanilla's `effect ~= 'Stone Card'` check into,
---     so Stone Cards and Limestone are both covered.
---   * ties go to the LAST such card in hand order, mirroring vanilla's `>=`.
local function axialmatt_raised()
    local best_id, best_nominal, best_card = 0, 0, nil
    for _, held in ipairs(G.hand and G.hand.cards or {}) do
        local base = held.base
        if base and best_id <= (base.id or 0) and not SMODS.has_no_rank(held) then
            best_id, best_nominal, best_card = base.id, base.nominal or 0, held
        end
    end
    return best_card, best_nominal
end

-- Shared with Ray + AxialMatt in merge/bind.lua, which raises this card too.
CelestasMod.axialmatt_raised = axialmatt_raised

SMODS.Joker {
    key = "axialmatt",
    atlas = "axialmatt",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { rank_mult = 2 } },

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- The held-in-hand pass, and h_mult rather than mult, because that is
        -- where Raised Fist lives: the Mult pops on the raised card as the
        -- hand is read rather than with the joker row afterwards.
        --
-- Vanilla reaches its held-in-hand block through an if/elseif chain whose
-- end_of_round branch comes FIRST, so Raised Fist, Baron and Shoot the Moon
-- are all structurally barred from firing at the cash-out. A modded Joker gets
-- no such guard: SMODS raises context.individual over G.hand again at the end
-- of the round, for the Gold cards paying out, and anything reading only
-- `individual + G.hand` triggers there too.
        if context.individual and context.cardarea == G.hand
            and not context.end_of_round then
            local raised, nominal = axialmatt_raised()
            if raised == context.other_card then
                -- A debuffed card is still eligible to be raised, and then
                -- reports Debuffed instead of paying. Skipping debuffed cards
                -- during selection would quietly promote the next card down,
                -- which Raised Fist does not do.
                if context.other_card.debuff then
                    return {
                        message = localize("k_debuffed"),
                        colour = G.C.RED,
                        card = card,
                    }
                end
                return {
                    h_mult = card.ability.extra.rank_mult * nominal,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Haruka Karibu [Uncommon]
-- Values on Tarot cards are doubled.
--------------------------------------------------------------------------------

CelestasMod.HARUKA_SCALE = 2

local HARUKA_KEY = "j_celesta_harukakaribu"

-- The numeric config fields a Tarot can carry: how many cards it affects
-- (max_highlighted), how many cards it creates (planets, tarots) and its
-- single loose number (extra - The Hermit's money cap, Temperance's payout
-- cap).
local HARUKA_FIELDS = { "max_highlighted", "planets", "tarots", "extra" }

-- The Wheel of Fortune's `extra` is a probability denominator, not a payout:
-- 1 in 4. Doubling the number would make it 1 in 8, which is the opposite of
-- a buff, so it is divided instead and the chance is what doubles.
local HARUKA_ODDS = { c_wheel_of_fortune = true }

-- The original values, captured before anything is scaled. Every application
-- recomputes from these rather than multiplying what is already there, so a
-- missed revert cannot compound.
local haruka_base = nil

--- These values live on the shared centre, not on the card.
---
--- set_ability never copies max_highlighted onto a card at all - vanilla reads
--- it straight off self.ability.consumeable, which IS G.P_CENTERS[key].config,
--- and the card's description reads the same table. So there is no per-card
--- value to double: doubling is necessarily a change to the centre, and the
--- description picks it up for free.
local function haruka_capture()
    if haruka_base then return end
    haruka_base = {}
    for key, center in pairs(G.P_CENTERS or {}) do
        if center.set == "Tarot" and center.config then
            local saved = {}
            for _, field in ipairs(HARUKA_FIELDS) do
                if type(center.config[field]) == "number" then
                    saved[field] = center.config[field]
                end
            end
            if next(saved) then haruka_base[key] = saved end
        end
    end
end

--- Rescales every Tarot centre for `count` copies of Haruka in play.
--- count 0 restores the originals, which is what makes this safe: G.P_CENTERS
--- outlives a run, so a run that ended with Haruka in play must not leak
--- doubled Tarots into the next one.
local function haruka_apply(count)
    haruka_capture()
    local scale = CelestasMod.HARUKA_SCALE ^ count
    for key, saved in pairs(haruka_base) do
        local center = G.P_CENTERS[key]
        if center and center.config then
            for field, base in pairs(saved) do
                if HARUKA_ODDS[key] and field == "extra" then
                    center.config[field] = math.max(1, base / scale)
                else
                    center.config[field] = base * scale
                end
            end
        end
    end
end

--- Counts the Harukas in play, ignoring one card.
---
--- Through CelestasMod.find_joker, never a walk of G.jokers.cards asking each
--- card its centre key. An ABSORBED half has no centre key of its own - the
--- merged card wears the HOST's - so the hand-rolled version this replaces
--- could not see a Haruka that had been merged as the second Joker, and the
--- Tarots quietly went back to their base numbers. find_joker is the lookup
--- this mod keeps for exactly that; see globals.lua.
---
--- The exclusion is what makes this correct from both callbacks, because
--- vanilla is not symmetric about when the card is in G.jokers:
---   * bought      - add_to_deck runs BEFORE emplace, so it is not in the area
---   * un-debuffed - add_to_deck runs while self.debuff is still true
---   * sold        - Card:remove strips it from the area BEFORE remove_from_deck
---   * debuffed    - remove_from_deck runs while self.debuff is still false
--- Excluding the card in question makes all four read "everyone else", and
--- the caller adds one back when the card is arriving.
---
--- A merge is a fifth shape and needs no case of its own. Bind applies the
--- absorbed half's passive while that half is STILL in the row, so the count
--- momentarily reads one too many - and then the half dissolves, its own
--- remove_from_deck runs last, and the answer settles. That is safe only
--- because haruka_apply recomputes from the captured originals every time
--- rather than multiplying what is already there.
local function haruka_count(excluding)
    local n = 0
    for _, held in ipairs(CelestasMod.find_joker(HARUKA_KEY)) do
        if held.card ~= excluding then n = n + 1 end
    end
    return n
end

-- Loading a save never runs add_to_deck (CardArea:load appends cards
-- directly), so a run reloaded with Haruka in play would come back with
-- undoubled Tarots. Recomputing once at the end of start_run covers that, and
-- covers starting a fresh run after one that ended with Haruka out.
local celesta_haruka_start_run_ref = Game.start_run
function Game:start_run(args)
    local ret = celesta_haruka_start_run_ref(self, args)
    haruka_apply(haruka_count(nil))
    return ret
end

SMODS.Joker {
    key = "harukakaribu",
    atlas = "harukakaribu",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { scale = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.scale } }
    end,

    add_to_deck = function(self, card, from_debuff)
        haruka_apply(haruka_count(card) + 1)
    end,

    remove_from_deck = function(self, card, from_debuff)
        haruka_apply(haruka_count(card))
    end,
}

--------------------------------------------------------------------------------
-- HeavenlyFather [Uncommon]
-- +2 booster pack slots.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "heavenlyfather",
    atlas = "heavenlyfather",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { slots = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.slots } }
    end,

    -- SMODS.change_booster_limit is the designated API: it moves
    -- G.GAME.modifiers.extra_boosters, which the shop reads when laying out
    -- packs, and fills the new slots immediately if the shop is already open.
    -- Pairing it with remove_from_deck means selling the joker, or having it
    -- debuffed, gives the slots back.
    add_to_deck = function(self, card, from_debuff)
        SMODS.change_booster_limit(card.ability.extra.slots)
    end,

    remove_from_deck = function(self, card, from_debuff)
        SMODS.change_booster_limit(-card.ability.extra.slots)
    end,
}

--------------------------------------------------------------------------------
-- Kyaree [Uncommon]
-- +6 Chips for each Spade card discarded.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "kyaree",
    atlas = "kyaree",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 0, chip_mod = 6 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.chip_mod, card.ability.extra.chips } }
    end,

    calculate = function(self, card, context)
        -- Shaped exactly like vanilla Castle, including the "Upgrade!" popup
        -- in chip blue that gives the tick as it counts up.
        --
        -- is_suit rather than a raw base.suit compare, so Wild cards and
        -- Smeared Joker count the way they do everywhere else.
        if context.discard and context.other_card
            and not context.other_card.debuff
            and context.other_card:is_suit("Spades")
            and not context.blueprint then
            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "chips",
                scalar_value = "chip_mod",
                no_message = true,
            })
            return {
                message = localize("k_upgrade_ex"),
                card = card,
                colour = G.C.CHIPS,
            }
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.chips, 0) then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- RTGame [Rare]
-- Gains X1 Mult after each Ante.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "rtgame",
    atlas = "rtgame",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 1, x_mult_gain = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult_gain, card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        -- ease_ante fires this after the ante has actually moved, and carries
        -- the delta. Guarded to gains only: a blind or voucher that lowers the
        -- ante should not hand out Mult for the ante being crossed twice.
        if context.ante_change and not context.blueprint then
            local moved = tonumber(context.ante_change) or 0
            if moved > 0 then
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "x_mult",
                    scalar_value = "x_mult_gain",
                    no_message = true,
                    operation = function(ref_table, ref_value, initial, scaling)
                        ref_table[ref_value] = initial + scaling * moved
                    end,
                })
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { card.ability.extra.x_mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Nostro [Common]
-- A breaking Gashed card is stripped instead of destroyed.
--------------------------------------------------------------------------------

-- The behaviour itself lives on the Gash enhancement, which asks
-- CelestasMod.nostro_active() at the moment it would break. This joker only
-- has to exist.
SMODS.Joker {
    key = "nostro",
    atlas = "nostro",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    -- Nothing to copy: it is a passive the enhancement reads, not a trigger.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Gash]
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Rin Penrose [Rare]
-- Gains +10 Mult for every 10 chips scored.
--------------------------------------------------------------------------------

--- Reads the hand's chip total as a plain number.
---
--- hand_chips is a global Balatro assigns during scoring and never clears, so
--- it still holds this hand's total when the `after` pass runs. Talisman
--- swaps it for a big-number object once scores outgrow a double, hence the
--- conversion - and the finite check, because a non-finite value written into
--- ability.extra would be serialized into the save as inf or nan and come
--- back as something no comparison can handle. Past that scale the joker
--- simply stops banking rather than corrupting the run.
local function rin_chips(value)
    local n = value
    if type(n) ~= "number" then
        if type(to_number) == "function" then
            local ok, converted = pcall(to_number, n)
            n = ok and converted or nil
        else
            n = nil
        end
    end
    if type(n) ~= "number" then return 0 end
    if n ~= n or n == math.huge or n == -math.huge then return 0 end
    return n
end

SMODS.Joker {
    key = "rinpenrose",
    atlas = "rinpenrose",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    -- bank is the chips carried toward the next step, so a hand of 15 chips
    -- pays once and leaves 5 behind rather than throwing the remainder away.
    config = { extra = { mult = 0, mult_gain = 10, chips_per_step = 100, bank = 0 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        local remaining = extra.chips_per_step - (extra.bank or 0)
        return { vars = { extra.mult_gain, extra.chips_per_step,
                          remaining, extra.mult } }
    end,

    calculate = function(self, card, context)
        -- context.after runs once per hand, after scoring is finished. The
        -- Mult banked here is therefore paid from the NEXT hand onwards,
        -- which is how every scaling joker in the game behaves.
        if context.after and not context.blueprint then
            local extra = card.ability.extra
            local scored = rin_chips(hand_chips)
            if scored <= 0 then return end

            extra.bank = (extra.bank or 0) + scored
            -- Divided rather than looped: one hand under Talisman can be
            -- worth more steps than a loop would ever finish.
            local steps = math.floor(extra.bank / extra.chips_per_step)
            if steps > 0 then
                extra.bank = extra.bank - steps * extra.chips_per_step
                extra.mult = extra.mult + steps * extra.mult_gain
                return {
                    message = localize { type = "variable", key = "a_mult",
                                         vars = { extra.mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.mult, 0) then
            return { mult = card.ability.extra.mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Radical Mari [Uncommon]
-- Spectral cards target the leftmost available Joker.
--------------------------------------------------------------------------------

-- The seeds the joker-targeting Spectrals roll with. Every one of them ends
-- up at pseudorandom_element(pool, pseudoseed(<seed>)):
--   ankh_choice - Ankh, choosing which Joker survives
--   ectoplasm   - Ectoplasm, choosing who gets Negative
--   hex         - Hex, choosing who gets Polychrome
-- The Wheel of Fortune uses the same shape but is a Tarot, so it is left out.
local MARI_SEEDS = {
    ankh_choice = true,
    ectoplasm = true,
    hex = true,
}

-- pseudoseed is called as the argument to pseudorandom_element, and Lua
-- evaluates arguments left to right, so the key recorded here is always the
-- one belonging to the call being entered. This is the only way to recover it
-- - by the time pseudorandom_element runs, the key has already been hashed
-- into a number that cannot be recomputed without advancing the RNG again.
local last_seed_key = nil
local celesta_mari_pseudoseed_ref = pseudoseed
function pseudoseed(key, ...)
    last_seed_key = key
    return celesta_mari_pseudoseed_ref(key, ...)
end

local function mari_active()
    return CelestasMod.joker_in_play("j_celesta_radicalmari")
end

--- The candidate sitting furthest left in the Joker row.
--- Picked by position in G.jokers rather than by index in the pool, so it is
--- leftmost on screen even if the pool was assembled in some other order.
local function leftmost_of(pool)
    if type(pool) ~= "table" or not (G.jokers and G.jokers.cards) then return nil end
    local best, best_pos = nil, math.huge
    for _, candidate in pairs(pool) do
        for position, joker in ipairs(G.jokers.cards) do
            if joker == candidate and position < best_pos then
                best, best_pos = candidate, position
                break
            end
        end
    end
    return best
end

local celesta_mari_pseudorandom_element_ref = pseudorandom_element
function pseudorandom_element(pool, seed, ...)
    local key = last_seed_key
    -- Rolled first and then overridden, rather than skipped: the roll consumes
    -- exactly as much of the RNG stream as it would without Mari, so having
    -- her in play does not shift every later roll in the run.
    --
    -- BOTH return values matter. Vanilla ends `return _t[key], key`, and
    -- callers pick whichever they need - get_new_boss takes the second, the
    -- table KEY, and drops the value. A wrapper that returns only the first
    -- hands those callers nil, which is how this once crashed every run on
    -- start with "attempt to perform arithmetic on a nil value" three frames
    -- deep in get_new_boss.
    local rolled, rolled_key = celesta_mari_pseudorandom_element_ref(pool, seed, ...)
    if MARI_SEEDS[key] and mari_active() then
        local left = leftmost_of(pool)
        if left then
            -- The key has to travel with the value it belongs to, or a caller
            -- reading the key gets one that points at a different entry.
            for k, v in pairs(pool) do
                if v == left then return left, k end
            end
            return left, rolled_key
        end
    end
    return rolled, rolled_key
end

SMODS.Joker {
    key = "radicalmari",
    atlas = "radicalmari",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- MonikaCinnyRoll [Uncommon]
-- Retriggers scoring cards while Downpour is active.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "monikacinnyroll",
    atlas = "monikacinnyroll",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        -- cardarea == G.play is the scoring-card repetition pass; cards held
        -- in hand arrive with G.hand instead and are not "scoring cards".
        --
        -- Arena.active() already expires an effect that outlived its round,
        -- so this cannot keep retriggering into a later round if a save was
        -- reloaded mid-Downpour.
        if context.repetition and context.cardarea == G.play
            and CelestasMod.Arena.is_active("downpour") then
            return {
                message = localize("k_again_ex"),
                repetitions = card.ability.extra.repetitions,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Dejavudea [Uncommon]
-- Repairs the cards in the played hand and protects them for the rest of the
-- run.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "dejavudea",
    atlas = "dejavudea",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- Protection is a binary state, so a copy has nothing left to add.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- context.before lands ahead of scoring, so a worn card played this
        -- hand is repaired in time to score at full value rather than paying
        -- half on the way through.
        --
        -- full_hand is every card played, not just the ones the poker hand
        -- scores. Playing a worn card alongside a pair protects it too, which
        -- is the reading that makes the joker usable on purpose.
        if context.before and not context.blueprint then
            local hand = context.full_hand or (G.play and G.play.cards)
            if type(hand) ~= "table" then return end

            local repaired = 0
            for _, played in ipairs(hand) do
                -- repair() insures every card it touches and reports back only
                -- for the ones that actually had wear to undo, so the popup
                -- appears when something visibly changed.
                if CelestasMod.Tattered.repair(played) then
                    repaired = repaired + 1
                end
            end

            if repaired > 0 then
                return {
                    message = localize("celesta_repaired"),
                    colour = G.C.FILTER,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Camila [Rare]
-- A lone first hand is consumed, and comes back next round one edition better.
--------------------------------------------------------------------------------

-- none -> Foil -> Holographic -> Polychrome, and no further.
CelestasMod.EDITION_LADDER = {
    none = "e_foil",
    e_foil = "e_holo",
    e_holo = "e_polychrome",
    e_polychrome = "e_polychrome",
}

--- Appends a snapshot to whatever is already stored, and returns the list.
---
--- Tolerates a bare snapshot as the existing value, because that is the shape
--- older saves hold: Camila kept exactly one card until a merge could widen it
--- to the whole hand, and a run in progress must not lose the card it is owed.
function CelestasMod.store_snapshot(existing, snapshot)
    local list = CelestasMod.stored_list(existing)
    list[#list + 1] = snapshot
    return list
end

--- Whatever is stored, as a list. A bare snapshot becomes a list of one.
function CelestasMod.stored_list(stored)
    if type(stored) ~= "table" then return {} end
    if stored.suit then return { stored } end
    return stored
end

--- The permanent bonuses a playing card can accumulate - Milk Bottle's Chips,
--- Burgundy Brew's Mult, a Rose Seal's X Mult, Hiker's, and the rest.
---
--- This is not a list of everything that could be called an upgrade; it is
--- vanilla's own, taken from Card:set_ability (card.lua:365-375), which
--- carries exactly these eleven forward when a card's centre changes under it
--- and rebuilds everything else. That is the game's existing answer to "what
--- belongs to the card rather than to its enhancement", and a card coming back
--- from Camila is the same question. perma_debuff is deliberately not among
--- them - set_ability lists it in reset_keys, so it does NOT survive, and
--- carrying it here would make Camila the one way to keep a debuff through a
--- change of enhancement.
CelestasMod.PERMA_KEYS = {
    "perma_bonus", "perma_mult", "perma_x_mult", "perma_x_chips",
    "perma_h_chips", "perma_h_mult", "perma_h_x_mult", "perma_h_x_chips",
    "perma_p_dollars", "perma_h_dollars", "perma_repetitions",
}

--- Everything needed to rebuild a playing card, as plain strings and numbers.
--- Stored on the joker and therefore serialized into the save, so it has to
--- survive a reload with no live references in it.
function CelestasMod.snapshot_card(card)
    if not (card and card.base) then return nil end

    -- Only what was actually earned. set_ability starts all eleven at 0, so a
    -- card with no upgrades stores no `perma` table at all and the shape on
    -- disk is exactly what it was before this existed.
    local perma = nil
    for _, key in ipairs(CelestasMod.PERMA_KEYS) do
        local value = card.ability and card.ability[key]
        if type(value) == "number" and value ~= 0 then
            perma = perma or {}
            perma[key] = value
        end
    end

    return {
        suit = card.base.suit,
        value = card.base.value,
        center = card.config and card.config.center_key or "c_base",
        edition = card.edition and card.edition.key or "none",
        seal = card.seal,
        perma = perma,
    }
end

--- The G.P_CARDS entry for a suit and rank.
--- Searched rather than composed: the table is keyed like S_7 and H_A, and
--- guessing that scheme for every rank is a bug waiting for the first Ten.
local function front_for(suit, value)
    for _, front in pairs(G.P_CARDS or {}) do
        if front.suit == suit and front.value == value then return front end
    end
end

SMODS.Joker {
    key = "camila",
    atlas = "camila",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = {} },

    loc_vars = function(self, info_queue, card)
        return CelestasMod.with_true_star_line("j_celesta_camila", {})
    end,

    calculate = function(self, card, context)
        -- True Stars in the deck are worth X Mult here; suits/true_stars.lua
        -- says what counts as one.
        if context.joker_main then
            local x_mult = CelestasMod.true_star_x_mult()
            if x_mult > 1 then return { x_mult = x_mult } end
        end

        -- Two Bind pairs change what this does rather than replacing it, and
        -- they say so on their own def rather than reimplementing the body:
        -- camila_any_count widens "a single card" to any number, and
        -- camila_edition names what the card comes back as. Read here so
        -- neither depends on which half of the merge ran first.
        local pair = CelestasMod.Bind and CelestasMod.Bind.special_of
            and CelestasMod.Bind.special_of(card)
        local any_count = pair and pair.camila_any_count

        -- Taken on the destroy pass rather than before scoring. A card pulled
        -- out from under evaluate_play mid-hand leaves the scoring loop
        -- holding a card that is no longer there; the destroy pass exists
        -- precisely for removing scored cards and runs once scoring is done.
        -- The card pays out for the hand that consumes it.
        if context.destroying_card and context.cardarea == G.play
            and not context.blueprint
            and G.GAME.current_round.hands_played == 0
            and context.full_hand
            and (any_count
                 or (#context.full_hand == 1
                     and context.destroying_card == context.full_hand[1])) then
            local doomed = context.destroying_card
            -- Eternal cards refuse destruction, and taking one would strand
            -- the snapshot forever.
            if SMODS.is_eternal and SMODS.is_eternal(doomed) then return end

            -- A list, because a widened pair takes every card of the hand and
            -- the destroy pass asks about them one at a time.
            card.ability.extra.stored = CelestasMod.store_snapshot(
                card.ability.extra.stored, CelestasMod.snapshot_card(doomed))
            return {
                remove = true,
                -- A pair may name a price for the card. Paid here, on the one
                -- pass that actually takes one, so a widened pair pays per
                -- card taken and a hand that triggers nothing pays nothing.
                dollars = pair and pair.camila_dollars or nil,
                message = localize("celesta_taken"),
                colour = G.C.PURPLE,
                card = card,
            }
        end

        -- Handed back when the next blind is picked.
        if context.setting_blind and card.ability.extra.stored
            and not (context.blueprint_card or card).getting_sliced then
            local held = CelestasMod.stored_list(card.ability.extra.stored)
            card.ability.extra.stored = nil

            for _, stored in ipairs(held) do
            G.E_MANAGER:add_event(Event {
                func = function()
                    local front = front_for(stored.suit, stored.value)
                    if not front then return true end
                    local center = G.P_CENTERS[stored.center] or G.P_CENTERS.c_base

                    -- Built in G.play so the player watches it arrive, then
                    -- animated into the deck - the same shape KokoNuts uses.
                    local restored = create_playing_card(
                        { front = front, center = center },
                        G.play, nil, nil, { G.C.SECONDARY_SET.Enhanced })

                    -- A pair may name the edition outright; otherwise the
                    -- card climbs one rung from whatever it was. The ladder
                    -- only knows the three it climbs, so anything else - a
                    -- Negative card, an edition from another mod - falls back
                    -- to what it already had. Without that last `or` the
                    -- ladder returns nil for it and the card comes back with
                    -- no edition at all, which loses more than it grants.
                    local upgraded = (pair and pair.camila_edition)
                        or CelestasMod.EDITION_LADDER[stored.edition or "none"]
                        or stored.edition
                    if upgraded then restored:set_edition(upgraded, true, true) end
                    if stored.seal then restored:set_seal(stored.seal, true) end

                    -- The upgrades it was carrying. Written straight onto the
                    -- ability because that is where they live; set_ability has
                    -- already run and started each of them at 0.
                    for key, value in pairs(stored.perma or {}) do
                        restored.ability[key] = value
                    end

                    SMODS.calculate_effect({
                        message = localize("celesta_returned"),
                        colour = G.C.DARK_EDITION,
                    }, context.blueprint_card or card)

                    G.E_MANAGER:add_event(Event {
                        func = function()
                            draw_card(G.play, G.deck, 90, "up", nil)
                            return true
                        end
                    })

                    playing_card_joker_effects({ restored })
                    return true
                end
            })
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Milk Bottle: permanent Chips on the cards you pick
--------------------------------------------------------------------------------

CelestasMod.MILK_BOTTLE_KEY = "c_" .. SMODS.current_mod.prefix .. "_milk_bottle"
CelestasMod.MILK_BOTTLE_BASE_SELECTION = 2
CelestasMod.MILK_BOTTLE_CLOVER_SELECTION = 3

SMODS.Consumable {
    key = "milk_bottle",
    set = "Spectral",
    atlas = "milk_bottle",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    -- max_highlighted lives on the CENTRE, not the card: the game reads it
    -- from ability.consumeable, which is this very table. That is what lets
    -- Moo Moo Clover raise it below - and why it has to be put back when she
    -- leaves.
    config = { extra = { chips = 8 }, max_highlighted = 2 },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.chips,
                          self.config.max_highlighted } }
    end,

    can_use = function(self, card)
        local picked = G.hand and G.hand.highlighted
        return picked and #picked > 0
            and #picked <= (self.config.max_highlighted or 2)
    end,

    use = function(self, card, area, copier)
        local chips = card.ability.extra.chips
        local picked = {}
        for i = 1, #G.hand.highlighted do picked[i] = G.hand.highlighted[i] end

        for i, target in ipairs(picked) do
            G.E_MANAGER:add_event(Event {
                trigger = "after",
                delay = 0.15,
                func = function()
                    -- perma_bonus is vanilla's own permanent chip store - the
                    -- one Hiker uses - and get_chip_bonus adds it on top of the
                    -- card's rank and enhancement, so it stacks with anything
                    -- the card already carries and survives re-enhancement.
                    target.ability.perma_bonus =
                        (target.ability.perma_bonus or 0) + chips
                    target:juice_up(0.3, 0.3)
                    play_sound("gold_seal", 1.1 + 0.05 * i, 0.4)
                    return true
                end
            })
        end

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.2,
            func = function()
                SMODS.calculate_effect({
                    message = localize { type = "variable", key = "a_chips",
                                         vars = { chips } },
                    colour = G.C.CHIPS,
                }, picked[1] or card)
                return true
            end
        })
        delay(0.4)
    end,
}

--------------------------------------------------------------------------------
-- Burgundy Brew: permanent Mult on the cards you pick
--------------------------------------------------------------------------------
--
-- Milk Bottle's twin, and written as its twin on purpose: same set, same cost,
-- same two-card selection, same event-per-card so the juice and the sound
-- stagger the way they do there. The one difference is which permanent store
-- it writes to.
--
-- perma_mult is vanilla's own, the pair of perma_bonus that Milk Bottle uses.
-- Card:get_chip_mult reads it and adds it on top of whatever the card's rank
-- and enhancement give (card.lua:1183), so it stacks with anything already
-- there and survives the card being re-enhanced.
--
-- NOT wired into Moo Merrily or Moo Moo Clover. Both of those name Milk Bottle
-- specifically - one hands one out each round, the other raises how many cards
-- it may take - and quietly teaching them a second bottle would change what
-- THEY do, which is not what was asked for.

CelestasMod.BURGUNDY_BREW_KEY =
    "c_" .. SMODS.current_mod.prefix .. "_burgundy_brew"

SMODS.Consumable {
    key = "burgundy_brew",
    set = "Spectral",
    atlas = "burgundy_brew",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    -- max_highlighted lives on the CENTRE, the way Milk Bottle's does: the
    -- game reads it from ability.consumeable, which is this very table.
    config = { extra = { mult = 2 }, max_highlighted = 2 },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.mult,
                          self.config.max_highlighted } }
    end,

    can_use = function(self, card)
        local picked = G.hand and G.hand.highlighted
        return picked and #picked > 0
            and #picked <= (self.config.max_highlighted or 2)
    end,

    use = function(self, card, area, copier)
        local mult = card.ability.extra.mult
        -- Copied before the first event runs: G.hand.highlighted is the live
        -- selection and the cards leave it as they are used.
        local picked = {}
        for i = 1, #G.hand.highlighted do picked[i] = G.hand.highlighted[i] end

        for i, target in ipairs(picked) do
            G.E_MANAGER:add_event(Event {
                trigger = "after",
                delay = 0.15,
                func = function()
                    target.ability.perma_mult =
                        (target.ability.perma_mult or 0) + mult
                    target:juice_up(0.3, 0.3)
                    play_sound("gold_seal", 1.1 + 0.05 * i, 0.4)
                    return true
                end
            })
        end

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.2,
            func = function()
                SMODS.calculate_effect({
                    message = localize { type = "variable", key = "a_mult",
                                         vars = { mult } },
                    colour = G.C.MULT,
                }, picked[1] or card)
                return true
            end
        })
        delay(0.4)
    end,
}

--------------------------------------------------------------------------------
-- Moo Merrily [Uncommon] - a Milk Bottle every round.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "moomerrily",
    atlas = "moomerrily",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.MILK_BOTTLE_KEY]
        return {}
    end,

    calculate = function(self, card, context)
        if context.setting_blind
            and not (context.blueprint_card or card).getting_sliced then
            -- The same room check vanilla makes before creating a consumable,
            -- with the buffer reserving the slot across the event boundary so
            -- two sources cannot both claim the last one.
            local buffer = G.GAME.consumeable_buffer or 0
            if #G.consumeables.cards + buffer >= G.consumeables.config.card_limit then
                return
            end
            G.GAME.consumeable_buffer = buffer + 1

            G.E_MANAGER:add_event(Event {
                trigger = "before",
                delay = 0.0,
                func = function()
                    local bottle = SMODS.create_card {
                        set = "Spectral",
                        key = CelestasMod.MILK_BOTTLE_KEY,
                        area = G.consumeables,
                    }
                    bottle:add_to_deck()
                    G.consumeables:emplace(bottle)
                    G.GAME.consumeable_buffer =
                        math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
                    return true
                end
            })

            return {
                message = localize("k_plus_spectral"),
                colour = G.C.SECONDARY_SET.Spectral,
                card = context.blueprint_card or card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Moo Moo Clover [Common] - one more card per Milk Bottle.
--------------------------------------------------------------------------------

--- Sets how many cards a Milk Bottle may target.
---
--- This has to be a change to the CENTRE, because there is nowhere else it
--- could live: set_ability never copies max_highlighted onto a card, and the
--- game reads it straight off ability.consumeable, which IS the centre's
--- config table. The same reason Haruka Karibu has to work this way.
---
--- Recomputed from the count of Clovers in play rather than nudged up and
--- down, so it cannot drift, and 0 restores the base - G.P_CENTERS outlives a
--- run, and a run that ended with a Clover must not leak the wider selection
--- into the next one.
local function clover_apply(count)
    local center = G.P_CENTERS and G.P_CENTERS[CelestasMod.MILK_BOTTLE_KEY]
    if not (center and center.config) then return end
    center.config.max_highlighted = count > 0
        and CelestasMod.MILK_BOTTLE_CLOVER_SELECTION
        or CelestasMod.MILK_BOTTLE_BASE_SELECTION
end

--- Counts the Clovers in play, ignoring one card.
--- Vanilla is not symmetric about when a joker is in G.jokers - bought runs
--- add_to_deck before emplace, sold strips the card first, debuff and undebuff
--- each run while the flag still says the opposite - so every path asks for
--- "everyone else" and the arriving ones add themselves back.
---
--- Through find_joker, because an absorbed half has no centre key of its own:
--- a Clover merged as the second Joker was invisible to the walk this
--- replaces. See globals.lua.
local function clover_count(excluding)
    local n = 0
    for _, held in ipairs(CelestasMod.find_joker("j_celesta_clover")) do
        if held.card ~= excluding then n = n + 1 end
    end
    return n
end

-- Loading a save never runs add_to_deck, so a reloaded run needs this
-- recomputed once the row exists.
local celesta_clover_start_run_ref = Game.start_run
function Game:start_run(args)
    local ret = celesta_clover_start_run_ref(self, args)
    clover_apply(clover_count(nil))
    return ret
end

SMODS.Joker {
    key = "clover",
    atlas = "clover",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { selection = CelestasMod.MILK_BOTTLE_CLOVER_SELECTION } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.MILK_BOTTLE_KEY]
        return { vars = { card.ability.extra.selection } }
    end,

    add_to_deck = function(self, card, from_debuff)
        clover_apply(clover_count(card) + 1)
    end,

    remove_from_deck = function(self, card, from_debuff)
        clover_apply(clover_count(card))
    end,
}

--------------------------------------------------------------------------------
-- Chibidoki [Common] - the lowest card in the hand goes again.
--------------------------------------------------------------------------------

--- The lowest ranked card among those actually scoring.
--- Ranked by base.id the way vanilla ranks - Ace 14 down to 2 - and rankless
--- cards are skipped through SMODS.has_no_rank, which is what Steamodded
--- patches vanilla's Stone Card check into. Ties go to the LAST such card,
--- mirroring how Raised Fist resolves them.
function CelestasMod.lowest_scoring(scoring_hand)
    local best_id, best_card = math.huge, nil
    for _, played in ipairs(scoring_hand or {}) do
        local base = played.base
        if base and not SMODS.has_no_rank(played) then
            local id = base.id or math.huge
            if id <= best_id then best_id, best_card = id, played end
        end
    end
    return best_card
end

SMODS.Joker {
    key = "chibidoki",
    atlas = "chibidoki",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play then
            local lowest = CelestasMod.lowest_scoring(context.scoring_hand)
            if lowest and context.other_card == lowest then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Ray [Common] - the suit Jokers go again.
--------------------------------------------------------------------------------

-- Vanilla's four suit Jokers. Note the key: the base game spells Gluttonous
-- "gluttenous", and that typo is the actual centre key. The corrected spelling
-- is listed too, so a future patch fixing it does not silently drop the card
-- out of Ray's reach.
local RAY_TARGETS = {
    -- Cosmic and Auteru are this mod's Star- and Leaf-suit equivalents of the
    -- vanilla four, so Ray treats them the same way.
    j_celesta_cosmic = true,
    j_celesta_auteru = true,
    j_greedy_joker = true,
    j_lusty_joker = true,
    j_wrathful_joker = true,
    j_gluttenous_joker = true,
    j_gluttonous_joker = true,
}

SMODS.Joker {
    key = "ray",
    atlas = "ray",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        -- retrigger_joker_check is asked of every Joker about every other
        -- Joker, so the answer has to name who it is being asked about, and
        -- Ray must refuse itself or it would retrigger its own answer.
        if context.retrigger_joker_check and context.other_card
            and context.other_card ~= card then
            local config = context.other_card.config
            local key = config and (config.center_key
                or (config.center and config.center.key))
            if key and RAY_TARGETS[key] then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Spongey [Rare] - soaks up every other Joker's trigger.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "spongeybuns",
    atlas = "spongeybuns",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 0, chip_mod = 10 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.chip_mod, card.ability.extra.chips } }
    end,

    calculate = function(self, card, context)
        -- post_trigger fires once for anything that just produced an effect,
        -- with other_card as whatever produced it and other_context as the
        -- context it was answering.
        if context.post_trigger and not context.blueprint then
            local trigger = context.other_card
            local inner = context.other_context

            -- Probability lookups run a full evaluation pass of their own and
            -- arrive here looking exactly like a trigger. They are questions,
            -- not triggers, and counting them would pay Spongey for every
            -- listed chance anything in the run consults.
            if inner and (inner.mod_probability or inner.fix_probability
                or inner.fixed_probability or inner.retrigger_joker_check) then
                return
            end

            -- other_card is not always a Joker: the same context is raised for
            -- playing cards, seals and enhancements as they trigger.
            if not (trigger and trigger.ability and trigger.ability.set == "Joker") then
                return
            end
            -- Itself excluded, so it does not pay itself for scoring.
            if trigger == card then return end

            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "chips",
                scalar_value = "chip_mod",
                no_message = true,
            })
            return {
                message = localize { type = "variable", key = "a_chips",
                                     vars = { card.ability.extra.chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.chips, 0) then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- FeFe [Uncommon] - the scoring cards all turn to Hearts.
--------------------------------------------------------------------------------
--
-- FeFe and its three siblings differ only in which suit they name, so the
-- behaviour is written once, here, above the first of them.

--- Converts every scoring card that has a suit to `suit`.
--- Returns how many were changed, so the caller can stay quiet when the hand
--- was already that suit.
---
--- The rewrite is SYNCHRONOUS and only the juice is queued, which is vanilla's
--- Midas Mask shape:
---     v:set_ability(G.P_CENTERS.m_gold, nil, true)
---     G.E_MANAGER:add_event(Event({ func = function() v:juice_up() ... end }))
---
--- That is not a style choice. context.before is raised part-way through
--- G.FUNCS.evaluate_play, and the rest of that function - naming the hand,
--- every card's chips, every suit check a Joker or Blind makes - runs
--- synchronously before it returns. An event queued here does not run until
--- evaluate_play has finished, and in fact not until the NEXT frame, because
--- the event evaluate_play is itself running inside blocks the queue for the
--- rest of this one. So a queued conversion misses the hand that triggered it
--- entirely; it would only be seen by the next one.
--- Changes a PLAYED card's base without letting the Blind re-judge whether it
--- was played before.
---
--- Card:set_base ends with `G.GAME.blind:debuff_card(self)`, and The Pillar
--- debuffs anything carrying ability.played_this_ante - a flag every card in
--- the hand was given moments earlier, in G.FUNCS.play_cards_from_highlighted,
--- before evaluate_play had run at all. Vanilla never re-judges a card during
--- the hand it is being played in, so it never notices; converting one does,
--- and the whole hand went dead mid-scoring against that Blind.
---
--- Only that one flag is hidden, and only across the call. Every other rule a
--- Blind has - a debuffed suit, rank, face or enhancement - is still judged,
--- and judged against the NEW base, which is exactly what should happen to a
--- card converted into the suit the Blind is punishing. The flag goes back
--- immediately, so the card is still debuffed at the next Blind, which is what
--- The Pillar is actually for.
---
--- Used by Occi as well, which rewrites the same cards to Aces of Spades.
local function convert_played_base(played, suit, rank)
    CelestasMod.unjudged(played, function()
        SMODS.change_base(played, suit, rank)
    end)
end

local function convert_scoring_to(context, suit)
    local scoring = context.scoring_hand
    if type(scoring) ~= "table" then return 0 end

    local converted = 0
    for _, played in ipairs(scoring) do
        -- A card with no suit has none to convert. Stone Cards and Limestone
        -- report through has_no_suit, and changing their base would hand them
        -- one they are not supposed to have.
        if not SMODS.has_no_suit(played) and not played:is_suit(suit) then
            convert_played_base(played, suit)
            converted = converted + 1

            local target = played
            G.E_MANAGER:add_event(Event {
                func = function() target:juice_up() return true end
            })
        end
    end
    return converted
end

SMODS.Joker {
    key = "fefe",
    atlas = "fefe",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = false, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- context.before runs after the poker hand has been named but before
        -- any card scores, so the conversion counts towards every suit check
        -- during scoring - Bloodstone, a Lusty Joker, a flush-suit Blind -
        -- without retroactively rewriting which hand was played.
        if context.before and not context.blueprint then
            if convert_scoring_to(context, "Hearts") > 0 then
                return {
                    message = localize("celesta_hearts"),
                    colour = G.C.HEARTS,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Milky [Rare] - Milk Bottles are free to hold.
--------------------------------------------------------------------------------

--- True when a Milky is in play and able to act.
---
--- card_is_joker rather than the centre key: a Milky merged as the second
--- Joker wears the host's centre and was invisible to the walk this replaces.
--- Walked here rather than through find_joker only to keep the exclusion,
--- which find_joker has no way to express.
local function milky_active(excluding)
    for _, joker in ipairs(G.jokers and G.jokers.cards or {}) do
        if joker ~= excluding
            and CelestasMod.card_is_joker(joker, "j_celesta_milky") then
            return true
        end
    end
    return false
end

--- Widens the consumable area by however many Milk Bottles are being held.
---
--- A slot is freed by raising card_limit, which is exactly how a Negative
--- consumable pays for itself in vanilla - the room check every source makes
--- is `#cards + buffer < card_limit`, so there is nothing else to teach.
---
--- The amount already applied lives on G.GAME rather than in a local. It is
--- baked into card_limit, and card_limit is saved: a local would come back as
--- zero after a reload and hand out the same slots a second time, every time.
local function milky_sync(excluding_joker)
    if not (G.GAME and G.consumeables and G.consumeables.config) then return end
    local applied = G.GAME.celesta_milky_slots or 0

    local wanted = 0
    if milky_active(excluding_joker) then
        for _, held in ipairs(G.consumeables.cards) do
            local key = held.config and (held.config.center_key
                or (held.config.center and held.config.center.key))
            if key == CelestasMod.MILK_BOTTLE_KEY then wanted = wanted + 1 end
        end
    end

    if wanted ~= applied then
        G.consumeables.config.card_limit =
            G.consumeables.config.card_limit + (wanted - applied)
        G.GAME.celesta_milky_slots = wanted
    end
end

CelestasMod.milky_sync = milky_sync

-- The count changes whenever any card enters or leaves the deck, which is the
-- same pair of calls a Milk Bottle arrives and departs through.
local celesta_milky_add_ref = Card.add_to_deck
function Card:add_to_deck(from_debuff)
    celesta_milky_add_ref(self, from_debuff)
    milky_sync()
end

local celesta_milky_remove_ref = Card.remove_from_deck
function Card:remove_from_deck(from_debuff)
    celesta_milky_remove_ref(self, from_debuff)
    milky_sync()
end

-- Loading a save never runs add_to_deck, so the count is recomputed once the
-- consumable area exists. The applied amount is read back off G.GAME, so this
-- settles on the right number rather than stacking another set of slots.
local celesta_milky_start_run_ref = Game.start_run
function Game:start_run(args)
    local ret = celesta_milky_start_run_ref(self, args)
    milky_sync()
    return ret
end

SMODS.Joker {
    key = "milky",
    atlas = "milky",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.MILK_BOTTLE_KEY]
        return {}
    end,

    -- Bought and sold are not symmetric about when the card is in G.jokers -
    -- add_to_deck runs before emplace, and Card:remove strips the card first -
    -- so the leaving card is excluded explicitly and the arriving one is not.
    add_to_deck = function(self, card, from_debuff)
        milky_sync()
    end,

    remove_from_deck = function(self, card, from_debuff)
        milky_sync(card)
    end,
}

--------------------------------------------------------------------------------
-- The suit converters: FeFe's siblings
--------------------------------------------------------------------------------
--
-- Three more Jokers that differ from FeFe only in which suit they name, so
-- they share its convert_scoring_to. See FeFe above for why the rewrite is
-- synchronous and only the juice is queued.

--- The body all three share. Written out as three separate declarations
--- rather than built in a loop because tools/gen_roster.py finds implemented
--- Jokers by matching `SMODS.Joker {` followed by a literal `key = "..."`:
--- a key passed as a variable is invisible to it, and the generator would
--- register each of these a second time as a placeholder.
local function converter_calculate(suit, colour, message)
    return function(self, card, context)
        if context.before and not context.blueprint then
            if convert_scoring_to(context, suit) > 0 then
                return { message = localize(message), colour = colour, card = card }
            end
        end
    end
end

SMODS.Joker {
    key = "vexoria",
    atlas = "vexoria",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = false, discovered = false,
    blueprint_compat = false, eternal_compat = true,
    loc_vars = function(self, info_queue, card) return {} end,
    calculate = converter_calculate("Spades", G.C.SPADES, "celesta_spades"),
}

SMODS.Joker {
    key = "ebiko",
    atlas = "ebiko",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = false, discovered = false,
    blueprint_compat = false, eternal_compat = true,
    loc_vars = function(self, info_queue, card) return {} end,
    calculate = converter_calculate("Diamonds", G.C.DIAMONDS, "celesta_diamonds"),
}

SMODS.Joker {
    key = "nihmune",
    atlas = "nihmune",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = false, discovered = false,
    blueprint_compat = false, eternal_compat = true,
    loc_vars = function(self, info_queue, card) return {} end,
    calculate = converter_calculate("Clubs", G.C.CLUBS, "celesta_clubs"),
}

--------------------------------------------------------------------------------
-- SunnySplosion [Common] - every card played comes down a rank.
--------------------------------------------------------------------------------
--
-- SMODS.modify_rank is the one funnel a rank change goes through - it is where
-- Steamodded routes the Strength Tarot (game_object.lua:2217), and this mod
-- already wraps it once for the Ace of Stars (suits/true_stars.lua). It also
-- already answers "if possible": a rank with nothing below it, or one whose
-- prev_behavior says to ignore, is left exactly where it is
-- (smods src/utils.lua:299). So that is not a judgement made here.
--
-- The WHOLE played hand, not the scoring part of it: "played cards" is every
-- card that went out, and the ones a Pair leaves unscored went out too.
--
-- context.before, which is where Nihmune and the other converters above
-- rewrite a played card. The poker hand has already been named by then, so a
-- downgrade cannot turn the hand into something else underneath the player -
-- but what each card is worth in Chips is read afterwards, so the new rank is
-- what scores.

-- Wrapped in a block because this file sits at Lua's limit of 200 local
-- variables per chunk: a helper declared at the top level here is the one that
-- stops the whole file compiling. Scoped, it is released at the end and never
-- counted against it.
do

--- Moves one played card's rank by `amount`, and says whether it moved.
---
--- Under unjudged, for the reason convert_played_base gives above: the change
--- ends in the Blind re-judging the card, and The Pillar debuffs anything
--- carrying played_this_ante - a flag every card in the hand was given moments
--- before evaluate_play ran. Vanilla never re-judges a card during the hand it
--- is played in, so nothing in the base game trips over it and everything that
--- rewrites one does.
---
--- A card with no rank is left alone: a Stone Card matches nothing on purpose,
--- and moving its base would hand it a rank it is not supposed to have. That
--- is the rank half of what convert_scoring_to does with has_no_suit.
---
--- Whether it moved is read off base.value rather than assumed, because
--- modify_rank writes the base back either way - a 2 asked to go lower is a
--- rewrite to the rank it already had.
local function shift_played_rank(played, amount)
    if SMODS.has_no_rank(played) then return false end
    local was = played.base and played.base.value
    CelestasMod.unjudged(played, function()
        SMODS.modify_rank(played, amount)
    end)
    if not played.base or played.base.value == was then return false end
    played:juice_up(0.3, 0.5)
    return true
end

--- Every played card moved by `amount`, with a popup only if something moved.
---
--- Shared with Mogu + SunnySplosion in merge/bind.lua, which is this one step
--- in the other direction: one body, so the two cannot come to disagree about
--- which cards are moved or about what "if possible" means.
function CelestasMod.sunny_shift(card, context, amount)
    if not (context.before and not context.blueprint) then return nil end

    local moved = 0
    for _, played in ipairs(context.full_hand or {}) do
        if shift_played_rank(played, amount) then moved = moved + 1 end
    end
    if moved == 0 then return nil end

    return {
        message = localize(amount > 0 and "k_upgrade_ex" or "celesta_downgrade"),
        colour = G.C.SECONDARY_SET.Planet,
        card = card,
    }
end

SMODS.Joker {
    key = "sunnysplosion",
    atlas = "sunnysplosion",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    -- Nihmune's, and for its reason: the rewrite is permanent and a copy
    -- would apply it a second time, so the calculate refuses a copier - which
    -- is what every permanent played-card rewrite in this file does.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { amount = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.amount } }
    end,

    calculate = function(self, card, context)
        return CelestasMod.sunny_shift(card, context,
                                       -card.ability.extra.amount)
    end,
}

end

--------------------------------------------------------------------------------
-- Eros [Uncommon] - eats Bonus enhancements, keeps the Chips.
--------------------------------------------------------------------------------

--- Takes the Bonus enhancement off every scoring card carrying one, and says
--- how many it took.
---
--- Shared with Eros + Grimmi in merge/bind.lua, which does the same thing for
--- more Chips - so the two cannot come to disagree about what counts as
--- removed, which is what both of them are paid by.
function CelestasMod.eros_strip(scoring)
    local removed = 0
    for _, played in ipairs(scoring or {}) do
        if SMODS.has_enhancement(played, "m_bonus")
            and not played.debuff
            and not played.celesta_stripped then
            removed = removed + 1
            -- The flag stops a copier stripping the same card twice in one
            -- pass: set_ability is deferred into an event, so the second look
            -- would still see the enhancement.
            played.celesta_stripped = true
            -- Under unjudged: set_ability re-judges the card, and The Pillar
            -- debuffs anything played this Ante - which is every card in the
            -- hand being played.
            CelestasMod.unjudged(played, function()
                played:set_ability(G.P_CENTERS.c_base, nil, true)
            end)
            G.E_MANAGER:add_event(Event {
                func = function()
                    played:juice_up()
                    played.celesta_stripped = nil
                    return true
                end
            })
        end
    end
    return removed
end

--- Takes the Bonus enhancement off every scoring card carrying one, and says
--- how many it took.
---
--- Shared with Eros + Grimmi in merge/bind.lua, which does the same thing for
--- more Chips - so the two cannot come to disagree about what counts as
--- removed, which is what both of them are paid by.
function CelestasMod.eros_strip(scoring)
    local removed = 0
    for _, played in ipairs(scoring or {}) do
        if SMODS.has_enhancement(played, "m_bonus")
            and not played.debuff
            and not played.celesta_stripped then
            removed = removed + 1
            -- The flag stops a copier stripping the same card twice in one
            -- pass: set_ability is deferred into an event, so the second look
            -- would still see the enhancement.
            played.celesta_stripped = true
            -- Under unjudged: set_ability re-judges the card, and The Pillar
            -- debuffs anything played this Ante - which is every card in the
            -- hand being played.
            CelestasMod.unjudged(played, function()
                played:set_ability(G.P_CENTERS.c_base, nil, true)
            end)
            G.E_MANAGER:add_event(Event {
                func = function()
                    played:juice_up()
                    played.celesta_stripped = nil
                    return true
                end
            })
        end
    end
    return removed
end

SMODS.Joker {
    key = "eros",
    atlas = "eros",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = false, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 0, chip_gain = 15 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_bonus
        return CelestasMod.with_true_star_line("j_celesta_eros",
            { vars = { card.ability.extra.chip_gain, card.ability.extra.chips } })
    end,

    calculate = function(self, card, context)
        -- Same shape as LaynaLazar, and as vanilla Vampire: context.before, so
        -- the enhancement is stripped before the hand scores and those cards
        -- do not pay their Chips this hand. scoring_hand is only populated here.
        if context.before and not context.blueprint then
            local removed = CelestasMod.eros_strip(context.scoring_hand)

            if removed > 0 then
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "chips",
                    scalar_value = "chip_gain",
                    message_key = "a_chips",
                    message_colour = G.C.CHIPS,
                    operation = function(ref_table, ref_value, initial, scaling)
                        ref_table[ref_value] = initial + scaling * removed
                    end
                })
            end
        end

        if context.joker_main then
            -- One return carries both: a Joker answers a context once, so the
            -- Chips it has banked and the True Star multiplier travel together
            -- rather than as two branches racing each other.
            local chips = card.ability.extra.chips
            local x_mult = CelestasMod.true_star_x_mult()
            if chips > 0 or x_mult > 1 then
                return {
                    chips = chips > 0 and chips or nil,
                    x_mult = x_mult > 1 and x_mult or nil,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Sinder [Common] - Driftwood stops breaking.
--------------------------------------------------------------------------------

-- The behaviour lives on the Driftwood enhancement, which asks
-- CelestasMod.sinder_active() before rolling. This Joker only has to exist.
SMODS.Joker {
    key = "sinder",
    atlas = "sinder",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = false, discovered = false,
    -- Nothing to copy: it is a passive the enhancement reads, not a trigger.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] =
            G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Driftwood]
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Suto [Uncommon] - the whole played hand turns Wild.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "suto",
    atlas = "suto",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = false, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_wild
        return {}
    end,

    calculate = function(self, card, context)
        -- Vanilla Midas Mask's shape: context.before, set_ability immediately
        -- so the change is in place before anything reads a suit this hand,
        -- and juice the card from an event so the flourish is not lost inside
        -- the evaluation.
        --
        -- The whole played hand rather than the scoring cards. FeFe and its
        -- siblings convert what scores; this one is a Rare and takes the
        -- cards that were carried along too, which is where the change keeps
        -- paying - a Wild card is Wild for the rest of the run.
        if context.before and not context.blueprint then
            local played = context.full_hand or (G.play and G.play.cards)
            if type(played) ~= "table" then return end

            local converted = 0
            for _, target in ipairs(played) do
                if target.config and target.config.center ~= G.P_CENTERS.m_wild
                    and not target.celesta_suto_claimed then
                    -- set_ability is deferred, so a copier evaluating in this
                    -- same pass would otherwise see the card as unconverted
                    -- and spend its message on work already done.
                    target.celesta_suto_claimed = true
                    -- Under unjudged, for the reason FeFe gives.
                    CelestasMod.unjudged(target, function()
                        target:set_ability(G.P_CENTERS.m_wild, nil, true)
                    end)
                    local claimed = target
                    G.E_MANAGER:add_event(Event {
                        func = function()
                            claimed:juice_up()
                            claimed.celesta_suto_claimed = nil
                            return true
                        end
                    })
                    converted = converted + 1
                end
            end

            if converted > 0 then
                return {
                    message = localize("celesta_plus_enhancement"),
                    colour = G.C.SECONDARY_SET.Enhanced,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Henya [Uncommon] - paid by the retrigger.
--------------------------------------------------------------------------------
--
-- A retrigger has no context of its own: SMODS runs the whole scoring pass for
-- a card again, once per repetition, with exactly the same context. eval_card,
-- though, is called once per trigger per card - the same signal the Tattered
-- system counts - so the tally is kept there, once, rather than by each Joker
-- that wants to read it.
--
-- Kept in one place for a reason: a Blueprint copying Henya calls Henya's own
-- calculate a second time in the same pass. A tally that Henya maintained
-- itself would count that copy as another trigger.

--- Identifies one play or discard. Both counters are decremented before
--- anything is evaluated, so this is stable across a single scoring sequence
--- and changes the moment the next one begins.
--- (blinds.lua computes the same thing for The Clover's once-per-event roll.)
local function hand_event_id()
    local round = G.GAME and G.GAME.current_round
    if not round then return "?" end
    return table.concat({ tostring(G.GAME.round), tostring(round.hands_left),
                          tostring(round.discards_left) }, "/")
end

--- How many times this card has triggered in the current scoring sequence.
--- 1 is its own trigger; anything above that is a retrigger.
local function trigger_count(scored)
    local seq = scored and scored.celesta_triggers
    if not seq or seq.id ~= hand_event_id() then return 0 end
    return seq.n
end

-- Shared with ObKatieKat + Henya in merge/bind.lua, which pays a retrigger in
-- ^Chips rather than in money. The count itself is kept by the eval_card
-- wrapper below, so both read the same sequence.
CelestasMod.trigger_count = trigger_count

local celesta_henya_eval_card_ref = eval_card
function eval_card(card, context)
    -- The same gate Tattered counts on: the main scoring pass over a real
    -- card. extra_enhancement is excluded because a quantum enhancement
    -- re-enters for a trigger that has already been counted.
    if context and context.main_scoring and not context.extra_enhancement
        and (context.cardarea == G.play or context.cardarea == G.hand) then
        local id = hand_event_id()
        local seq = card.celesta_triggers
        if not seq or seq.id ~= id then
            seq = { id = id, n = 0 }
            card.celesta_triggers = seq
        end
        seq.n = seq.n + 1
    end
    return celesta_henya_eval_card_ref(card, context)
end

SMODS.Joker {
    key = "henya",
    atlas = "henya",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { dollars = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.dollars } }
    end,

    calculate = function(self, card, context)
        -- The individual pass runs once per trigger, immediately after the
        -- eval_card above has counted it - so the count is already correct
        -- for the trigger being paid for.
        if context.individual and context.other_card
            and not context.end_of_round
            and (context.cardarea == G.play or context.cardarea == G.hand) then
            if trigger_count(context.other_card) > 1 then
                return {
                    dollars = card.ability.extra.dollars,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- El_Xox [Common] - paid by the hand.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "el_xox",
    atlas = "el_xox",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 4,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { dollars = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.dollars } }
    end,

    -- calc_dollar_bonus rather than an end_of_round calculate: this is the
    -- hook vanilla pays reward money through, so the amount shows up in the
    -- round's cash-out screen as its own line the way Delayed Gratification's
    -- does, rather than arriving as a floating message mid-scoring.
    calc_dollar_bonus = function(self, card)
        local round = G.GAME and G.GAME.current_round
        local played = round and round.hands_played or 0
        if played <= 0 then return end
        return played * card.ability.extra.dollars
    end,
}

--------------------------------------------------------------------------------
-- Fream [Common] - Wild Cards go round twice.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "fream",
    atlas = "fream",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_wild
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play
            and context.other_card
            and SMODS.has_enhancement(context.other_card, "m_wild") then
            return {
                message = localize("k_again_ex"),
                repetitions = card.ability.extra.repetitions,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Kirana [Common] - paid for holding 3s.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "kirana",
    atlas = "kirana",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { dollars = 3 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.dollars } }
    end,

    calculate = function(self, card, context)
        -- main_eval is the once-per-round Joker pass; without it this fires
        -- again for every card evaluated during the end-of-round pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            if not G.hand then return end

            local threes = 0
            for _, held in ipairs(G.hand.cards) do
                -- A Stone Card has no rank to be a 3, and get_id on one
                -- returns its printed rank regardless.
                if not SMODS.has_no_rank(held) and not held.debuff
                    and held:get_id() == 3 then
                    threes = threes + 1
                end
            end
            if threes == 0 then return end

            return {
                dollars = threes * card.ability.extra.dollars,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Kael [Uncommon] - every face card is a 10.
--------------------------------------------------------------------------------
--
-- Built the way Cryptid's Maximized is built, which is the same idea one rank
-- further: it wraps Card:get_id and answers with the rank it wants cards to
-- count as. Vanilla's Pareidolia does the mirror image for faces, widening
-- Card:is_face rather than the rank.
--
-- Two details taken straight from Maximized, both of which cost something to
-- learn the hard way:
--
-- Card:is_face CALLS Card:get_id -
--     function Card:is_face(from_boss)
--         if self.debuff and not from_boss then return end
--         local id = self:get_id()
--         if id == 11 or id == 12 or id == 13 or next(find_joker("Pareidolia")) then
-- - so asking is_face from inside a get_id wrapper recurses forever. Maximized
-- inlines the id range and the Pareidolia lookup instead of calling it, and so
-- does this.
--
-- And the deck viewer has to be exempt. Maximized keeps an `override` flag
-- that G.UIDEF.view_deck raises around itself, because a player looking at
-- their deck wants to see the ranks their cards actually have. The same flag
-- is here for the same reason.
--
-- Straights are deliberately untouched. get_straight buckets cards by their
-- rank KEY rather than by get_id, so a King is still a King when the game
-- looks for a run - which means Kael no longer breaks 9-10-J-Q-K the way
-- rewriting base.value did. Pairs, trips and quads all go through get_id and
-- do see the 10.

--- True when a Kael is in play and able to act.
local function kael_active()
    return CelestasMod.joker_in_play("j_celesta_kael")
end

-- Raised while something needs the PRINTED rank rather than Kael's answer.
local kael_suppressed = false

local celesta_kael_get_id_ref = Card.get_id
function Card:get_id()
    local id = celesta_kael_get_id_ref(self)
    if kael_suppressed then return id end

    -- Anything that makes EVERY card one rank answers first. That is the wider
    -- rule - Kael's own is faces only - and it is asked here rather than of
    -- the Jokers because a replacing pair speaks for both halves: the Kael
    -- inside Kairyu + Kael is not in play as itself, so kael_active() below
    -- would never find it. See globals.lua.
    --
    -- A card with no rank is left out. A Stone Card matches nothing on
    -- purpose, and get_id hands back a large negative number to say so; the
    -- suit side of this does the same, since the Baulder Gang gives a Stone
    -- Card no suit either. has_no_rank reads enhancements only and never asks
    -- get_id, so there is no loop here.
    if not SMODS.has_no_rank(self) then
        for _, rule in ipairs(CelestasMod.CARD_RANK_RULES or {}) do
            local ok, rank = pcall(rule)
            if ok and type(rank) == "number" then return rank end
        end
    end

    if not kael_active() then return id end

    -- The face test, inlined rather than called - see above. It is Pareidolia's
    -- own test, and this follows it exactly rather than second-guessing it:
    -- whatever Pareidolia calls a face card, Kael calls a 10.
    --
    -- That includes a Stone Card. On its own a Stone Card is untouched, since
    -- get_id hands back a large negative number precisely so it matches
    -- nothing - but Pareidolia short-circuits the rank check, so under both it
    -- is a face card and therefore a 10. Which is what Pareidolia would do.
    if (id and id >= 11 and id <= 13) or next(find_joker("Pareidolia")) then
        return 10
    end
    return id
end

--- Runs fn with Kael's answer suppressed, so get_id gives the printed rank.
local function kael_printed(fn, ...)
    local saved = kael_suppressed
    kael_suppressed = true
    local ok, ret = pcall(fn, ...)
    kael_suppressed = saved
    if not ok then error(ret, 0) end
    return ret
end

-- A King is still a face card. is_face works off get_id -
--     local id = self:get_id()
--     if id == 11 or id == 12 or id == 13 or next(find_joker("Pareidolia"))
-- - so without this a King answering 10 stops being a face card, and
-- Photograph, Midas Mask, Baron, Sock and Buskin and Pareidolia itself all
-- quietly stop seeing it. Kael changes what a card COUNTS AS, not what it IS.
--
-- Maximized never meets this because it maps faces to 13, which is still a
-- face id. Mapping them to 10 walks straight into it.
local celesta_kael_is_face_ref = Card.is_face
function Card:is_face(from_boss)
    return kael_printed(celesta_kael_is_face_ref, self, from_boss)
end

-- The deck viewer shows printed ranks, the way Maximized exempts it.
if G.UIDEF and G.UIDEF.view_deck then
    local celesta_kael_view_deck_ref = G.UIDEF.view_deck
    function G.UIDEF.view_deck(...)
        return kael_printed(celesta_kael_view_deck_ref, ...)
    end
end

SMODS.Joker {
    key = "kael",
    atlas = "kael",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A passive the rank lookup reads, not a trigger; there is nothing to copy.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------

-- Mari Yume [Rare] - Blueprint, aimed at the far end of the row.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "mariyume",
    atlas = "mariyume",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- Copyable, like Blueprint is: a Blueprint next to this one copies it and
    -- ends up pointed at the same rightmost Joker.
    blueprint_compat = true, eternal_compat = true,

    -- The tooltip of what it copies, for a real card only, and never another
    -- Mari Yume. A tooltip entry is described by calling ITS loc_vars with no
    -- card, so a Mari Yume at the end of the row - a second one, or one merged
    -- into the rightmost Joker - named itself, which named itself again, and
    -- the game ran out of stack.
    loc_vars = function(self, info_queue, card)
        if not card then return {} end
        local target = G.jokers and G.jokers.cards and G.jokers.cards[#G.jokers.cards]
        local center = target and target.config and target.config.center
        if target and target ~= card and center and center ~= self then
            info_queue[#info_queue + 1] = center
        end
        return {}
    end,

    calculate = function(self, card, context)
        local row = G.jokers and G.jokers.cards
        if not row then return end

        local target = row[#row]
        -- Nothing to copy when it IS the rightmost. blueprint_effect refuses
        -- a copier pointed at itself anyway; returning early keeps the run out
        -- of the copy stack entirely.
        if not target or target == card then return end

        return SMODS.blueprint_effect(card, target, context)
    end,
}

--------------------------------------------------------------------------------
-- Kairyu [Uncommon] - the more you throw away, the more you hold.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "kairyucrocodile",
    atlas = "kairyucrocodile",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A copy would grant a second set of the same slots, which the reset
    -- below could not take back off: the amount applied lives on this card.
    blueprint_compat = true, eternal_compat = true,

    -- `applied` is what this card has actually handed out. It lives in the
    -- ability table rather than a local because card_limit is saved with the
    -- run: a local would come back as zero after a reload and the size would
    -- never be given back.
    config = { extra = { h_size = 1, applied = 0 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.h_size, card.ability.extra.applied } }
    end,

    --- Brings the hand size in line with the number of discards used.
    ---
    --- Written as a difference against what is already applied rather than as
    --- an add: every path in and out of the deck goes through here, so the
    --- card can be bought, sold, debuffed and reloaded without the size
    --- drifting.
    celesta_resize = function(self, card, wanted)
        local applied = card.ability.extra.applied or 0
        if wanted == applied then return 0 end
        if G.hand then G.hand:change_size(wanted - applied) end
        card.ability.extra.applied = wanted
        return wanted - applied
    end,

    calculate = function(self, card, context)
        -- pre_discard, not discard: `discard` arrives once per discarded
        -- CARD, while this fires once per discard action. It also carries
        -- context.hook, which marks the discards a Joker forces - vanilla does
        -- not count those against the round, so neither does this.
        --
        -- discards_used is incremented AFTER the whole discard sequence, so at
        -- this point it is still the count before this one.
        if context.pre_discard and not context.blueprint and not context.hook then
            local round = G.GAME and G.GAME.current_round
            local used = (round and round.discards_used or 0) + 1
            local delta = self:celesta_resize(card, used * card.ability.extra.h_size)
            if delta > 0 then
                return {
                    message = localize("celesta_plus_hand_size"),
                    colour = G.C.FILTER,
                    card = card,
                }
            end
        end

        -- main_eval is the once-per-round Joker pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            if (card.ability.extra.applied or 0) > 0 then
                self:celesta_resize(card, 0)
                return {
                    message = localize("k_reset"),
                    colour = G.C.FILTER,
                    card = card,
                }
            end
        end
    end,

    -- Sold, or debuffed: the size it handed out goes back. Bought or
    -- un-debuffed mid-round, it hands out what the round has earned so far.
    --
    -- Only mid-round, though. discards_used is not cleared until new_round,
    -- which runs when the NEXT round starts - so all the way through the
    -- cash-out screen and the shop it still holds the last round's count, and
    -- a Kairyu bought there would open the new round already holding hand size
    -- for discards it never saw. G.GAME.facing_blind is vanilla's own "a round
    -- is in progress": set at blind select, cleared before the cash-out.
    add_to_deck = function(self, card, from_debuff)
        local round = G.GAME and G.GAME.current_round
        local in_round = G.GAME and G.GAME.facing_blind
        local used = (in_round and round and round.discards_used) or 0
        card.ability.extra.applied = 0
        self:celesta_resize(card, used * card.ability.extra.h_size)
    end,

    remove_from_deck = function(self, card, from_debuff)
        self:celesta_resize(card, 0)
    end,
}

--------------------------------------------------------------------------------
-- Sansin [Common] - the deck wears out half as fast.
--------------------------------------------------------------------------------

-- The behaviour lives in wear/tattered.lua, which asks Tattered.wear_delay()
-- each time it counts a score. This Joker only has to exist.
SMODS.Joker {
    key = "sansin",
    atlas = "sansin",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    -- A passive the wear system reads, not a trigger; nothing to copy.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Sigrid & Bird [Legendary] - Blueprint in both directions at once.
--------------------------------------------------------------------------------

--- The cards either side of position `index`, left first, gaps left out.
---
--- Built by appending rather than as a literal: `{ row[i - 1], row[i + 1] }`
--- with no left neighbour is a table whose first slot is nil, and ipairs stops
--- at the first gap - which silently dropped the RIGHT neighbour whenever this
--- Joker was leftmost in the row.
function CelestasMod.neighbours(row, index)
    local out = {}
    if row[index - 1] then out[#out + 1] = row[index - 1] end
    if row[index + 1] then out[#out + 1] = row[index + 1] end
    return out
end

SMODS.Joker {
    key = "sigrid_bird",
    atlas = "sigrid_bird",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    -- Copyable, the way Blueprint is: a copier next to this one ends up
    -- pointed at the same two neighbours.
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        local row = G.jokers and G.jokers.cards
        if not row then return {} end
        for i, joker in ipairs(row) do
            if joker == card then
                for _, side in ipairs(CelestasMod.neighbours(row, i)) do
                    info_queue[#info_queue + 1] = side.config.center
                end
                break
            end
        end
        return {}
    end,

    calculate = function(self, card, context)
        local row = G.jokers and G.jokers.cards
        if not row then return end

        local index
        for i, joker in ipairs(row) do
            if joker == card then index = i break end
        end
        if not index then return end

        -- Left first, then right, so the order the two copies resolve in
        -- matches the order the row is read.
        local effects = {}
        for _, side in ipairs(CelestasMod.neighbours(row, index)) do
            -- blueprint_effect refuses a copier pointed at itself, a debuffed
            -- target, and anything that opts out of copying, so there is
            -- nothing else to check here.
            local copied = SMODS.blueprint_effect(card, side, context)
            if copied then effects[#effects + 1] = copied end
        end

        if #effects == 0 then return end
        -- One calculate returns one effect table, so two copies are chained
        -- through `extra` - which is what merge_effects builds.
        return SMODS.merge_effects(effects)
    end,
}

--------------------------------------------------------------------------------
-- Nana & Ruru [Rare] - a chance to run a merged Joker again.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "nana_ruru",
    atlas = "nana_ruru",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 9,
    unlocked = false, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 4, repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.BIND_KEY]
        -- Reads the live odds so the text tracks Oops! All 6s and friends.
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_nana_ruru")
        return { vars = { numerator, denominator, card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        -- retrigger_joker_check is asked of every Joker about every other
        -- Joker, so the answer has to name who it is being asked about, and
        -- this must refuse itself - a merged Nana & Ruru would otherwise
        -- retrigger its own answer.
        if context.retrigger_joker_check and context.other_card
            and context.other_card ~= card
            and CelestasMod.Bind and CelestasMod.Bind.is_merged(context.other_card) then
            if SMODS.pseudorandom_probability(card, "celesta_nana_ruru", 1,
                    card.ability.extra.odds, "celesta_nana_ruru") then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- The Star suit Jokers
--------------------------------------------------------------------------------
--
-- All of these ask through card:is_suit, not base.suit. is_suit routes through
-- SMODS.smeared_check, so a Wild Card counts as a Star and Arielle makes every
-- card one - which is what those are for. (The one place this mod deliberately
-- reads base.suit instead is Yomi's "is there a Star in the deck at all", where
-- Arielle would otherwise answer yes for every deck.)

--- The Star suit's name and colour, for the descriptions that print it.
---
--- The colour goes INSIDE vars, as vars.colours, which is where localize reads
--- it from: `args.vars.colours[tonumber(part.control.V)]`. Steamodded's
--- generate_ui forwards res.vars, res.key, res.set, res.scale and
--- res.text_colour and nothing else, so a colours table returned beside vars
--- is dropped and {V:1} then indexes a nil - a crash on hover, not a blank.
--- Vanilla's own suit Tarots build it the same way.
---
--- The colour falls back to the raw value: G.C.SUITS is filled in when the
--- suit registers its colours.
--- Singular, because every one of these descriptions uses the suit to qualify
--- a noun - "Star suit", "Star card" - which is the form vanilla's own suit
--- Jokers use. The Tarots that name the suit as a set stay plural.
local function star_name_and_colour()
    return CelestasMod.suit_name_and_colour(
        CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR, true)
end

--- Keeps a Joker out of the pools until the deck holds a Star.
---
--- The same idea as vanilla's Golden Ticket, which sits out of the shop until
--- a Gold card exists - except vanilla hangs that on `enhancement_gate`, and
--- there is no suit equivalent to hang this on, so it goes through
--- Steamodded's in_pool. Steamodded consults it from get_current_pool, so it
--- covers the shop, packs and every other source rather than the shop alone.
---
--- Only for Jokers that can do NOTHING without a Star. Yomi is not one: it
--- rotates through the four either way and merely gains a fifth suit once one
--- exists, so it stays available.
local function star_gated(self, args)
    return CelestasMod.stars_in_deck()
end

--- True when a scored card counts as a Star.
local function is_star(other_card)
    return other_card ~= nil and other_card.is_suit ~= nil
        and other_card:is_suit(CelestasMod.STARS_SUIT)
end

--- The Leaf suit's name and colour, and the same question about a card. Same
--- shape as the two above, and for the same reasons.
local function leaf_name_and_colour()
    return CelestasMod.suit_name_and_colour(
        CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR, true)
end

local function is_leaf(other_card)
    return other_card ~= nil and other_card.is_suit ~= nil
        and other_card:is_suit(CelestasMod.LEAF_SUIT)
end

--- Keeps a Joker out of the pools until the deck holds a Leaf, for the Jokers
--- that can do nothing at all without one. See star_gated above.
local function leaf_gated(self, args)
    return CelestasMod.leaf_in_deck()
end

--------------------------------------------------------------------------------
-- Cosmic [Common] - the plain one.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "cosmic",
    atlas = "cosmic",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { mult = 3 } },

    in_pool = star_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = star_name_and_colour()
        return { vars = { card.ability.extra.mult, name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and is_star(context.other_card) then
            return { mult = card.ability.extra.mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Vienna [Uncommon] - a chance at exponential Mult.
--------------------------------------------------------------------------------
--
-- ^Mult is Talisman's, not Steamodded's: Talisman wraps SMODS.calculate_effect
-- to understand `e_mult` and adds Card:get_chip_e_mult alongside it. Without
-- Talisman the key is simply ignored and the Joker would do nothing at all,
-- silently.
--
-- Talisman is a declared dependency in CelestasMod.json, so Steamodded will
-- refuse to load this mod without it and the branch below should be
-- unreachable. It is kept because "unreachable" rests on the manifest staying
-- correct, and the failure it guards is a Joker that quietly does nothing -
-- the kind that gets reported as "Vienna is broken" rather than as a missing
-- dependency.
--
-- Asked at score time rather than at load: mods load in priority order, and
-- Talisman may not have run yet when this file does.
local function exponential_supported()
    if Card.get_chip_e_mult ~= nil then return true end
    CelestasMod.warn_once("vienna_no_talisman",
        "Vienna scores ^Mult, which needs Talisman; without it the Joker does nothing")
    return false
end

SMODS.Joker {
    key = "vienna",
    atlas = "vienna",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 3, e_mult = 1.15 } },

    in_pool = star_gated,

    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_vienna")
        local name, colour = star_name_and_colour()
        return { vars = { numerator, denominator, card.ability.extra.e_mult, name,
                          colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and is_star(context.other_card) then
            -- Rolled per card, so a hand of five Stars gets five rolls.
            if SMODS.pseudorandom_probability(card, "celesta_vienna", 1,
                    card.ability.extra.odds, "celesta_vienna") then
                if not exponential_supported() then return end
                return { e_mult = card.ability.extra.e_mult }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- PiapiUFO [Rare] - every Star multiplies.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "piapiufo",
    atlas = "piapiufo",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 1.5 } },

    in_pool = star_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = star_name_and_colour()
        return { vars = { card.ability.extra.x_mult, name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and is_star(context.other_card) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Mooni [Common] - paid for throwing Stars away.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "mooni",
    atlas = "mooni",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 4,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { dollars = 1 } },

    in_pool = star_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = star_name_and_colour()
        return { vars = { card.ability.extra.dollars, name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        -- context.discard arrives once per discarded card, which is exactly
        -- the per-card payout this wants.
        if context.discard and not context.blueprint
            and is_star(context.other_card) then
            return {
                dollars = card.ability.extra.dollars,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Aries Akana [Uncommon] - collects Chips off Stars.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "ariesakana",
    atlas = "ariesakana",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 0, chip_mod = 3 } },

    in_pool = star_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = star_name_and_colour()
        return { vars = { card.ability.extra.chip_mod, card.ability.extra.chips, name,
                          colours = { colour } } }
    end,

    calculate = function(self, card, context)
        -- The individual pass runs over the scoring cards BEFORE the Joker row
        -- is evaluated, so a Star scored this hand is already paying by the
        -- time joker_main asks for the total.
        if context.individual and context.cardarea == G.play
            and not context.blueprint and is_star(context.other_card) then
            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "chips",
                scalar_value = "chip_mod",
                message_key = "a_chips",
                message_colour = G.C.CHIPS,
            })
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.chips, 0) then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- SonneFlower [Uncommon] - grows on Leaves, and only on Leaves.
--------------------------------------------------------------------------------
--
-- Not star_gated, and deliberately: a deck with no Leaves in it can still be
-- given some, and a Joker that resets to X1 every hand until then is doing
-- something the player can see and act on rather than nothing.

SMODS.Joker {
    key = "sonneflower",
    atlas = "sonneflower",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 1, x_mult_gain = 0.25 } },

    loc_vars = function(self, info_queue, card)
        local name, colour = leaf_name_and_colour()
        return { vars = { card.ability.extra.x_mult_gain, card.ability.extra.x_mult,
                          name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        -- context.before is the one pass that sees the whole scoring hand
        -- before any of it scores, so the decision is made once per hand
        -- rather than once per card.
        if context.before and not context.blueprint then
            local leaf = false
            for _, played in ipairs(context.scoring_hand or {}) do
                if is_leaf(played) then leaf = true break end
            end

            if leaf then
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "x_mult",
                    scalar_value = "x_mult_gain",
                    no_message = true,
                })
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { card.ability.extra.x_mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end

            -- Reset only when there is something to lose, so a run of
            -- Diamond-less hands does not announce a reset every time.
            if CelestasMod.more_than(card.ability.extra.x_mult, 1) then
                card.ability.extra.x_mult = 1
                return {
                    message = localize("k_reset"),
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Taehoongie [Uncommon] - one of every suit.
--------------------------------------------------------------------------------
--
-- It asks for one card of every suit the game has, so it is gated on the deck
-- actually being able to answer: with two conversion-only suits registered, a
-- Stars-only gate would let it into the shop in a run that has no Leaf and no
-- way for the condition to be met.

SMODS.Joker {
    key = "taehoongie",
    atlas = "taehoongie",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { levels = 1 } },

    in_pool = function(self, args) return CelestasMod.all_suits_in_deck() end,

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.levels,
                          localize("Five of a Kind", "poker_hands") } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            -- Every suit the game has, not a hardcoded five: another mod
            -- adding a suit should widen what this asks for rather than
            -- leaving it satisfiable while a suit goes unrepresented.
            local wanted, found = 0, 0
            for _, suit in pairs(SMODS.Suits) do
                wanted = wanted + 1
                for _, played in ipairs(context.scoring_hand or {}) do
                    if played:is_suit(suit.key) then found = found + 1 break end
                end
            end
            if wanted == 0 or found < wanted then return end

            return {
                level_up = card.ability.extra.levels,
                level_up_hand = "Five of a Kind",
                message = localize("k_level_up_ex"),
                colour = G.C.SECONDARY_SET.Planet,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Shenpai [Uncommon] - gilds a Four of a Kind.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "shenpai",
    atlas = "shenpai",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { needed = 4 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_SEALS.Gold
        return { vars = { card.ability.extra.needed } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            -- Grouped by rank rather than trusting the hand name: a Five of a
            -- Kind contains four of a rank too, and so does a Full House's
            -- larger half when a Joker has widened what scores.
            local by_rank = {}
            for _, played in ipairs(context.scoring_hand or {}) do
                if not SMODS.has_no_rank(played) then
                    local id = played:get_id()
                    by_rank[id] = by_rank[id] or {}
                    table.insert(by_rank[id], played)
                end
            end

            local gilded = 0
            for _, group in pairs(by_rank) do
                if #group >= card.ability.extra.needed then
                    for _, target in ipairs(group) do
                        -- A card that is already Gold is left alone, so the
                        -- Joker does not claim to have done something it did
                        -- not do when the hand is replayed.
                        if target.seal ~= "Gold" then
                            local sealed = target
                            G.E_MANAGER:add_event(Event {
                                func = function()
                                    sealed:set_seal("Gold", nil, true)
                                    return true
                                end
                            })
                            gilded = gilded + 1
                        end
                    end
                end
            end

            if gilded > 0 then
                return {
                    message = localize("celesta_sealed"),
                    colour = G.C.MONEY,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Yoka Siri [Rare] - pays the neighbour after a boss falls.
--------------------------------------------------------------------------------

-- Values live in TWO places, and a Joker that scales only one of them misses
-- most of the game. Vanilla builds its ability table flat -
--     self.ability = { mult = center.config.mult or 0, t_mult = ..., x_mult =
--                      center.config.Xmult or 1, extra = copy_table(...) or nil }
-- - so a Jolly Joker keeps its 8 in ability.t_mult and has no `extra` table at
-- all, while modded Jokers conventionally keep everything in ability.extra.
--
-- The two are read differently. ability.extra belongs to whoever declared the
-- Joker, so anything numeric in it is fair game bar a short blocklist. The
-- flat table is vanilla's own and is full of things that are not values -
-- `order` is the sort position, `h_size` and `d_size` are applied once as the
-- Joker enters the deck - so that one is an allowlist.
-- Retrigger counts are NOT here. They are scaled like any other value, then
-- made whole and capped below - Hanging Chad's have been scaled all along,
-- because vanilla keeps them in a bare `extra`, and a modded Joker keeping the
-- same thing under `repetitions` should not be treated differently.
--
-- `odds` stays: scaling a chance UP makes it worse, since the number is the
-- denominator. 1 in 4 would become 1 in 6.
local YOKA_LEAVE_ALONE = {
    odds = true,
    perish_tally = true, cry_prob = true,
    -- this mod's own bookkeeping
    applied = true, bank = true, suit_index = true, last_round = true,
    needed = true, levels = true,
}

--- The most retriggers any one count can be scaled to.
---
--- Yoka fires after every Boss defeated and multiplies what is already there,
--- so an uncapped count compounds - X1.5 a Boss walks 2 into the hundreds over
--- a long run, and every one of those is a whole extra scoring pass.
CelestasMod.YOKA_RETRIGGER_CAP = 40

local YOKA_FLAT_VALUES = {
    mult = true, t_mult = true, h_mult = true, perma_mult = true,
    chips = true, t_chips = true, h_chips = true, perma_bonus = true,
    x_mult = true, h_x_mult = true, x_chips = true, h_x_chips = true,
    e_mult = true, e_chips = true,
    p_dollars = true, h_dollars = true, dollars = true,
}

--- True for a multiplier sitting at its do-nothing value.
---
--- Vanilla gives EVERY Joker `x_mult = center.config.Xmult or 1`, so scaling a
--- 1 here would hand X1.5 Mult to a Joker that never had a multiplier at all.
--- Cryptid's misprintize refuses the same values for the same reason.
local function yoka_neutral(key, value)
    if value ~= 1 then return false end
    return key:find("x_mult") ~= nil or key:find("x_chips") ~= nil
        or key:find("e_mult") ~= nil or key:find("e_chips") ~= nil
end

--- True when this Joker is willing to be changed at all.
--- Cryptid marks some of its own as `immutable`, and Oil Lamp checks exactly
--- this before touching its neighbour. Without Cryptid there is no such
--- concept and everything is fair game.
local function yoka_may_change(target)
    if type(Card) == "table" and type(Card.no) == "function" then
        return not Card.no(target, "immutable", true)
    end
    return true
end

--- Multiplies every printed number a Joker keeps, in place.
---
--- Straight multiplication rather than Vedal's rule, which scales the excess
--- of a multiplier so that halving X2 lands on X1.5 instead of X1. That rule
--- exists to stop a REDUCTION wiping a multiplier out; going up has no such
--- problem, and "multiply the values by 1.5" plainly means X2 becomes X3.
---
--- Cryptid does this job already. Oil Lamp is the same Joker - the neighbour
--- to the right, at end of round - and it hands the work to
--- Cryptid.manipulate(target, { value = increase }), which walks the whole
--- ability table, applies each centre's misprintize_caps, refuses the values
--- that are neutral rather than absent, keeps Talisman's big numbers big and
--- knows about Cryptid's own fused Jokers. Reimplementing that would be
--- reimplementing it worse, so when Cryptid is present it is asked.
---
--- The fallback below is what runs without Cryptid, and only has to be right
--- about base-game Jokers.
--- Multiplies the numbers in one ability table, in place.
--- `deny` is consulted on top of YOKA_LEAVE_ALONE, for the fields a caller
--- knows are not per-hand values.
local function yoka_scale_ability(ability, scale, deny)
    if type(ability) ~= "table" then return false end
    local changed = 0

    --- What a number becomes. A retrigger count is scaled like anything else
    --- and then made whole and capped.
    ---
    --- Whole, because a fraction of a retrigger is not something the game can
    --- do: the loop is `for h = 1, effect.repetitions`
    --- (smods src/utils.lua:1498), so 1.5 runs once while the card goes on
    --- claiming 1.5.
    ---
    --- Matched on the NAME rather than against a list of keys, so this mod's
    --- enhanced_repetitions and rain_repetitions are covered without naming
    --- them, and so is whatever the next one is called.
    local function scaled(key, value)
        local out = value * scale
        if tostring(key):find("repetitions") then
            out = math.floor(out + 0.5)
            local cap = CelestasMod.YOKA_RETRIGGER_CAP
            if cap and out > cap then out = cap end
        end
        return out
    end

    local extra = ability.extra
    -- A modded Joker keeps a TABLE in `extra`; several vanilla ones keep a
    -- bare number that is the value itself. The Idol's X2 lives there -
    -- `config = {extra = 2}`, scored as `x_mult = self.ability.extra`
    -- (card.lua:3458) - and so do Credit Card's overdraft and To the Moon's
    -- interest. Walking only the table shape missed all of them.
    if type(extra) == "number" and extra ~= 0
        and not (deny and deny.extra) then
        ability.extra = extra * scale
        changed = changed + 1
    elseif type(extra) == "table" then
        for key, value in pairs(extra) do
            if type(value) == "number" and not YOKA_LEAVE_ALONE[key]
                and not (deny and deny[key]) and not yoka_neutral(key, value) then
                local was = value
                extra[key] = scaled(key, value)
                -- A count already at the cap has not moved, and saying it has
                -- would put an "Upgrade!" over a Joker that is unchanged.
                if extra[key] ~= was then changed = changed + 1 end
            end
        end
    end

    -- Iterated over the allowlist rather than over the table, so a field
    -- vanilla adds later cannot quietly start being scaled.
    for key in pairs(YOKA_FLAT_VALUES) do
        local value = ability[key]
        if type(value) == "number" and value ~= 0
            and not (deny and deny[key]) and not yoka_neutral(key, value) then
            ability[key] = value * scale
            changed = changed + 1
        end
    end

    return changed > 0
end

--- A merged pair's own numbers are read every evaluation, the same as a
--- Joker's, with these exceptions: they are handed out ONCE, by on_merge or by
--- the pair's add_to_deck, and nothing reads them again. Scaling one would not
--- give the player anything - it would only make the description claim more
--- than the card is doing.
local YOKA_PAIR_LEAVE_ALONE = {
    h_size = true,      -- Maya + Ben, applied at merge
    boosters = true,    -- HeavenlyFather + Nostro
    vouchers = true,    -- ...and its other half
    discount = true,    -- Kumi + HeavenlyFather, read by Card:set_cost
    shop = true,        -- HeavenlyFather + Aethal
    shop_held = true,   -- ...and what of it actually landed
    last_round = true,  -- Ellie Minibot + Shoomimi: which shop it last paid in
}

--- Everything below this line that is not Cryptid's is a fallback, and only
--- a fallback. Cryptid is optional for this mod (tools/check_dependencies.py
--- lists it that way), so there has to be something for a run without it - but
--- when it is installed, Yoka Siri is Oil Lamp: it calls
--- Cryptid.manipulate(target, { value = scale }) and does nothing else.
---
--- Nothing else, specifically including the merged-half pass below.
--- manipulate walks the ability table RECURSIVELY (Cryptid.manipulate_table
--- recurses into every nested table it finds), so it already reaches an
--- absorbed half's own ability under celesta_bind and the pair's state beside
--- it. Running the hand pass over those afterwards scaled them a second time -
--- a X2 on the absorbed half landing on X2.25 instead of X1.5 - which is the
--- kind of thing nobody notices until the numbers are wrong.
local function yoka_scale(target, scale)
    local ability = target and target.ability
    if type(ability) ~= "table" then return false end
    if not yoka_may_change(target) then return false end

    -- Oil Lamp's, verbatim apart from the value it passes.
    if type(Cryptid) == "table" and type(Cryptid.manipulate) == "function" then
        local ok, err = pcall(Cryptid.manipulate, target, { value = scale })
        if ok then return true end
        CelestasMod.warn_once("yoka_manipulate",
            "Yoka Siri could not use Cryptid.manipulate (" .. tostring(err)
            .. "); scaling by hand instead")
    end

    local changed = yoka_scale_ability(ability, scale)

    -- The rest of a merged card, which the hand pass above cannot reach on its
    -- own: the absorbed half keeps a whole ability table under celesta_bind,
    -- and a special pair keeps its state beside it.
    --
    -- Both are scaled whichever kind of merge it is. A replacing pair's halves
    -- never run, so scaling them changes nothing; an additive one's do, and so
    -- does its state. Working out which would buy nothing over doing both.
    local bound = ability.celesta_bind
    if type(bound) == "table" then
        if yoka_scale_ability(bound.ability, scale) then changed = true end
        if type(bound.special) == "table" then
            -- The pair's state has no `extra` of its own; its numbers sit
            -- directly on it, the way a config does.
            if yoka_scale_ability({ extra = bound.special }, scale,
                                  YOKA_PAIR_LEAVE_ALONE) then
                changed = true
            end
        end
    end

    return changed
end

-- Shared with Yoka Siri + ItsDeadlyBoop in merge/bind.lua, which scales a
-- neighbour the same way.
CelestasMod.yoka_scale = yoka_scale

SMODS.Joker {
    key = "yokasiri",
    atlas = "yokasiri",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 9,
    unlocked = true, discovered = false,
    -- A copy would multiply the same neighbour a second time.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { scale = 1.5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.scale } }
    end,

    calculate = function(self, card, context)
        -- main_eval is the once-per-round Joker pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            local blind = G.GAME and G.GAME.blind
            if not (blind and blind.boss) then return end

            local row = G.jokers and G.jokers.cards
            if not row then return end
            local index
            for i, joker in ipairs(row) do
                if joker == card then index = i break end
            end
            local target = index and row[index + 1]
            if not target or target == card then return end

            -- Oil Lamp's announcement, not a made-up one: it says only that
            -- the neighbour was upgraded, because after Cryptid has walked a
            -- whole ability table there is no single number to name.
            if yoka_scale(target, card.ability.extra.scale) then
                return {
                    message = localize("k_upgrade_ex"),
                    colour = G.C.GREEN,
                    card = card,
                }
            end

            -- Nothing on that Joker is a number this can multiply. Two thirds
            -- of the ones it cannot touch carry no values at all - a copier
            -- has none of its own, and neither does a Joker that only changes
            -- a rule - and the rest are at the retrigger cap.
            --
            -- Said out loud rather than passed over in silence, which is what
            -- this did before: a pass that does nothing and says nothing is
            -- indistinguishable from one that never ran, and it was reported
            -- twice as a Joker that had stopped working.
            return {
                message = localize("celesta_no_upgrade"),
                colour = G.C.UI.TEXT_INACTIVE,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Radiaactive [Uncommon] - Blue Seals go round twice.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "radiaactive",
    atlas = "radiaactive",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_SEALS.Blue
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        -- Held in hand, not played: a Blue Seal does its work at end of round
        -- from the hand, so that is the pass worth repeating.
        if context.repetition and context.cardarea == G.hand
            and context.other_card and context.other_card.seal == "Blue" then
            return {
                message = localize("k_again_ex"),
                repetitions = card.ability.extra.repetitions,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Blue Seal planets: August Anomoly and Glowy Pumpkin
--------------------------------------------------------------------------------
--
-- Both of these act on the Planet a Blue Seal makes, and neither can find it
-- from a calculate context: the Seal builds it inside an event queued from
-- Card:get_end_of_round_effect, where no Joker is consulted.
--
-- It is identifiable at the source, though. Vanilla creates it with
--     create_card('Planet', G.consumeables, nil, nil, nil, nil, _planet, 'blusl')
-- and that last argument - the key_append - is 'blusl' for this and nothing
-- else in the game. Wrapping create_card and watching for it is exact, where
-- watching for "a Planet appeared at end of round" would also catch Moo
-- Merrily, a Cryptid effect, or the player using a card.

local BLUE_SEAL_APPEND = "blusl"

--- True when a Joker with this key is in play and able to act.
local function joker_active(key)
    return CelestasMod.joker_in_play(key)
end

--- Room for one more consumable, by the same test every vanilla source makes.
local function consumable_room()
    if not (G.consumeables and G.consumeables.config) then return false end
    return #G.consumeables.cards + (G.GAME.consumeable_buffer or 0)
        < G.consumeables.config.card_limit
end

local celesta_blue_seal_create_ref = create_card
function create_card(_type, area, legendary, _rarity, skip_materialize,
                     soulable, forced_key, key_append, ...)
    local card = celesta_blue_seal_create_ref(_type, area, legendary, _rarity,
        skip_materialize, soulable, forced_key, key_append, ...)

    if key_append ~= BLUE_SEAL_APPEND or not card then return card end

    -- El XoX + August Anomoly counts these. The Planet is the whole of what a
    -- Blue Seal does and vanilla makes exactly one per trigger, so this is the
    -- Seal firing - and a Radiaactive retrigger arrives here a second time,
    -- which is a second firing.
    if CelestasMod.blue_seal_triggered then
        CelestasMod.blue_seal_triggered(card)
    end

    -- Negative first: the copy below is made from this card, so it inherits
    -- the edition and both Planets match.
    if joker_active("j_celesta_glowypumpkin") and card.set_edition then
        card:set_edition({ negative = true }, true, true)
    end

    if joker_active("j_celesta_augustanomoly") then
        -- A Negative consumable costs no slot, so the second one only has to
        -- fit when it is not Negative. Vanilla reserved room for one card
        -- before this ran; this asks again for the other.
        if card.edition and card.edition.negative or consumable_room() then
            local twin = copy_card(card, nil, nil, nil, skip_materialize)
            if twin then
                twin:add_to_deck()
                G.consumeables:emplace(twin)
            end
        end
    end

    return card
end

SMODS.Joker {
    key = "augustanomoly",
    atlas = "augustanomoly",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- The work happens at the Seal, not here; there is no trigger to copy.
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_SEALS.Blue
        return {}
    end,
}

SMODS.Joker {
    key = "glowypumpkin",
    atlas = "glowypumpkin",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_SEALS.Blue
        info_queue[#info_queue + 1] = G.P_CENTERS.e_negative
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Fenari [Rare] - peels stickers off, and grows doing it.
--------------------------------------------------------------------------------

--- Every sticker a card is currently wearing.
--- Read from SMODS.Stickers rather than a list of the three vanilla ones, so a
--- sticker another mod adds is peeled off too.
local function stickers_on(target)
    local worn = {}
    if not (target and target.ability) then return worn end
    for key in pairs(SMODS.Stickers or {}) do
        if target.ability[key] then worn[#worn + 1] = key end
    end
    return worn
end

-- Shared with Fenari + HeavenlyFather in merge/bind.lua, which takes them all
-- off a pack's Jokers rather than one off a Joker in the row.
CelestasMod.stickers_on = stickers_on

SMODS.Joker {
    key = "fenari",
    atlas = "fenari",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 9,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 1, x_mult_gain = 0.5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult_gain, card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        -- main_eval is the once-per-round Joker pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            local wearing = {}
            for _, joker in ipairs(G.jokers and G.jokers.cards or {}) do
                if #stickers_on(joker) > 0 then wearing[#wearing + 1] = joker end
            end
            if #wearing == 0 then return end

            local target = pseudorandom_element(wearing, pseudoseed("celesta_fenari"))
            if not target then return end
            local worn = stickers_on(target)
            local sticker = pseudorandom_element(worn, pseudoseed("celesta_fenari_which"))
            if not sticker then return end

            target.ability[sticker] = nil
            -- Perishable keeps a countdown beside its flag; left behind it
            -- would debuff the Joker on its own later.
            if sticker == "perishable" then target.ability.perish_tally = nil end
            target:juice_up(0.3, 0.4)

            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "x_mult",
                scalar_value = "x_mult_gain",
                no_message = true,
            })
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { card.ability.extra.x_mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Geega [Uncommon] - a debuffed Joker is worth something after all.
--------------------------------------------------------------------------------
--
-- Card:set_debuff is where every route in ends up: a Blind debuffing the row,
-- a Perishable running out - which has its own branch above the general one -
-- and anything a mod does through SMODS.debuff_card.

local celesta_geega_set_debuff_ref = Card.set_debuff
function Card:set_debuff(should_debuff)
    local was_debuffed = self.debuff
    local ret = celesta_geega_set_debuff_ref(self, should_debuff)

    if self.debuff and not was_debuffed
        and self.ability and self.ability.set == "Joker"
        and not (self.edition and self.edition.negative)
        and joker_active("j_celesta_geega") then
        -- Not the Geega doing the debuffing to itself: a Joker that debuffs
        -- itself and turns Negative for it is fine, but it must not be the
        -- reason it counts as active.
        self:set_edition({ negative = true }, true, true)
    end

    return ret
end

SMODS.Joker {
    key = "geega",
    atlas = "geega",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.e_negative
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Cerber [Common] - the biggest card goes round again.
--------------------------------------------------------------------------------

--- The highest-ranked card of a scoring hand, or nil.
---
--- A Stone Card has no rank to be the highest. Ties go to the LAST such card,
--- so exactly one card is picked however many share the rank - the same rule
--- Chibidoki uses for the lowest.
---
--- Shared with MinikoMew + Cerber in merge/bind.lua, which retriggers the same
--- card a different number of times, so the two cannot come to disagree about
--- which card is the biggest.
function CelestasMod.highest_ranked(scoring)
    if type(scoring) ~= "table" then return nil end
    local highest
    for _, played in ipairs(scoring) do
        if not SMODS.has_no_rank(played) then
            if not highest or played:get_id() >= highest:get_id() then
                highest = played
            end
        end
    end
    return highest
end

SMODS.Joker {
    key = "cerbervt",
    atlas = "cerbervt",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play
            and context.other_card then
            local highest = CelestasMod.highest_ranked(context.scoring_hand)

            if highest and highest == context.other_card then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Unnamed [Common] - the cards nobody saw still count.
--------------------------------------------------------------------------------
--
-- Splash is not a special case in the scoring code; it is one answer to a
-- question the game asks about every played card:
--     local splashed = SMODS.always_scores(card) or next(find_joker('Splash'))
--     ... SMODS.calculate_context({modify_scoring_hand = true, other_card = card, ...})
--     if flags.add_to_hand then splashed = true end
-- So rather than copy Splash, this answers the same question for the cards it
-- cares about. add_to_hand is the supported way in.
--
-- "Flipped over" has to be captured before scoring, because by then it is no
-- longer true: CardArea:emplace turns a face-down card face up as it enters
-- the play area -
--     if card.facing == 'back' and self.config.type ~= 'discard' ... then card:flip() end
-- - so the flag is set from inside emplace, reading the facing the card
-- arrived with. It is cleared when the card lands anywhere else, which is
-- every route out of the play area.

local celesta_unnamed_emplace_ref = CardArea.emplace
function CardArea:emplace(card, location, stay_flipped)
    if card then
        if self == G.play then
            card.celesta_played_flipped = (card.facing == "back") or nil
        elseif self == G.hand or self == G.discard then
            card.celesta_played_flipped = nil
        end
    end
    return celesta_unnamed_emplace_ref(self, card, location, stay_flipped)
end

SMODS.Joker {
    key = "unnamed",
    atlas = "unnamed",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    -- Answering a question twice does not answer it harder.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        if context.modify_scoring_hand and context.other_card
            and context.other_card.celesta_played_flipped
            and CelestasMod.hand_is_being_played() then
            return { add_to_hand = true }
        end
    end,
}

--------------------------------------------------------------------------------
-- The Leaf suit Jokers
--------------------------------------------------------------------------------
--
-- Same shape as the Star suit set above, and for the same reasons: is_leaf
-- asks through card:is_suit so a Wild Card counts, leaf_gated keeps a Joker
-- out of the pools while the deck has no Leaf to work with, and the suit
-- colour goes inside vars as vars.colours.

--------------------------------------------------------------------------------
-- Auteru [Common] - the plain one. Cosmic's opposite number.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "auteru",
    atlas = "auteru",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { mult = 3 } },

    in_pool = leaf_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = leaf_name_and_colour()
        return { vars = { card.ability.extra.mult, name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and is_leaf(context.other_card) then
            return { mult = card.ability.extra.mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Buffpup [Common] - paid by the deck, not by the hand.
--------------------------------------------------------------------------------
--
-- Counted off the whole run deck rather than the hand, so it is worth exactly
-- as much whatever gets played - the same live-count shape as vanilla's
-- Erosion, which reads #G.playing_cards in its description and again when it
-- scores.

SMODS.Joker {
    key = "buffpup",
    atlas = "buffpup",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 16 } },

    in_pool = leaf_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = leaf_name_and_colour()
        local held = CelestasMod.count_suit_in_deck(CelestasMod.LEAF_SUIT)
        return { vars = { card.ability.extra.chips, name,
                          held * card.ability.extra.chips,
                          colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            local held = CelestasMod.count_suit_in_deck(CelestasMod.LEAF_SUIT)
            if held > 0 then
                return { chips = held * card.ability.extra.chips }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- MapleChicken [Uncommon] - every Leaf goes round twice.
--------------------------------------------------------------------------------
--
-- Two cardareas, because a Leaf card can be doing either job: G.play is the
-- retrigger vanilla's Sock and Buskin gives face cards as they score, and
-- G.hand is the one Mime gives cards held in hand. A Steel or Gold Leaf sat in
-- hand is exactly the case that needs the second one, so both are answered
-- rather than only the scoring pass.

SMODS.Joker {
    key = "maplechicken",
    atlas = "maplechicken",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1 } },

    in_pool = leaf_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = leaf_name_and_colour()
        return { vars = { card.ability.extra.repetitions, name,
                          colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.repetition and is_leaf(context.other_card)
            and (context.cardarea == G.play or context.cardarea == G.hand) then
            return {
                message = localize("k_again_ex"),
                repetitions = card.ability.extra.repetitions,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Fufu [Rare] - paid for a varied deck.
--------------------------------------------------------------------------------
--
-- Live-counted rather than accrued: "for each unique suit in your full deck"
-- is a question about the deck as it is now, so converting the last Heart away
-- costs the Mult back rather than leaving it banked.
--
-- Suitless cards are not a suit. Stone and Limestone still carry a base.suit
-- under the enhancement, so the enhancement has to be asked rather than the
-- base - CelestasMod.unique_suits_in_deck does that through SMODS.has_no_suit.
--
-- Not gated on either added suit: a vanilla deck already answers four.

--- X1 plus the gain per distinct suit the deck is printed with.
local function fufu_x_mult(card)
    return 1 + card.ability.extra.x_mult_gain * CelestasMod.unique_suits_in_deck()
end

SMODS.Joker {
    key = "fufu",
    atlas = "fufu",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    -- Locked until a run is won with the Plaid Deck; see jokers/unlocks.lua.
    unlocked = false, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult_gain = 0.5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult_gain, fufu_x_mult(card) } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            local x_mult = fufu_x_mult(card)
            if x_mult > 1 then return { x_mult = x_mult } end
        end
    end,
}

--------------------------------------------------------------------------------
-- Isaa [Rare] - the first hand of the round comes back.
--------------------------------------------------------------------------------
--
-- Played cards go to the discard pile from exactly one place: an event queued
-- by play_cards_from_highlighted calls G.FUNCS.draw_from_play_to_discard, and
-- nothing else in the game calls it. That single caller is the seam, so this
-- wraps it rather than trying to intercept the cards somewhere later.
--
-- The other half is already written, and by the base game: vanilla ships
-- G.FUNCS.draw_from_play_to_hand, which walks the play area the same way its
-- discard twin does and skips the cards that were destroyed or shattered while
-- scoring. Nothing in vanilla calls it - it is left over from an earlier design
-- - but it is exactly this, so it is used as-is rather than reimplemented.
--
-- "The first played hand" and "once per round" are one condition, not two:
-- current_round.hands_played is incremented immediately after the discard call,
-- so it is 0 for the first hand of the round and never 0 again until the round
-- resets and rebuilds current_round. No flag to set, and none to forget to
-- clear.
--
-- Known interaction: The Serpent draws exactly three cards after a hand
-- whatever the hand already holds, so returning five to a full hand and then
-- drawing three leaves it over its limit for that round. The cards squeeze up
-- and nothing breaks; it is left alone rather than special-cased, because a
-- Joker that quietly stops working under one Boss is worse than a crowded hand.

--- True when a Joker in the row is an undebuffed Isaa.
local function isaa_in_play()
    return CelestasMod.joker_in_play("j_celesta_isaa")
end

--- Whether this hand is the one Isaa gets back.
local function isaa_returns_this_hand()
    local round = G.GAME and G.GAME.current_round
    if not round or (round.hands_played or 0) ~= 0 then return false end
    if not (G.play and G.play.cards and #G.play.cards > 0) then return false end
    return isaa_in_play()
end

-- The wrap is installed at load if there is anything to wrap, and whether it
-- was is remembered rather than reported here. A missing hook is only worth
-- saying out loud to someone who actually has the Joker, so add_to_deck says
-- it - and a file that talks at load time is a file that cannot be loaded by
-- anything but the game.
local celesta_isaa_hooked = false
local celesta_isaa_to_discard_ref = G.FUNCS and G.FUNCS.draw_from_play_to_discard

if celesta_isaa_to_discard_ref then
    celesta_isaa_hooked = true
    G.FUNCS.draw_from_play_to_discard = function(e)
        if isaa_returns_this_hand() and G.FUNCS.draw_from_play_to_hand then
            for _, isaa in ipairs(CelestasMod.find_joker("j_celesta_isaa")) do
                card_eval_status_text(isaa.card, "extra", nil, nil, nil,
                    { message = localize("celesta_returned"), colour = G.C.FILTER })
            end
            -- Copied out: draw_card moves cards between areas as it goes, and
            -- G.play.cards is the list being mutated.
            local played = {}
            for i, held in ipairs(G.play.cards) do played[i] = held end
            return G.FUNCS.draw_from_play_to_hand(played)
        end
        return celesta_isaa_to_discard_ref(e)
    end
end

SMODS.Joker {
    key = "isaa",
    atlas = "isaa",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- There is no calculate to copy: the effect is in where the cards go
    -- afterwards, which happens once for the hand however many Isaas are out.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    add_to_deck = function(self, card, from_debuff)
        if not celesta_isaa_hooked then
            CelestasMod.warn_once("isaa_no_discard_hook",
                "Isaa returns the first hand of the round by wrapping "
                .. "G.FUNCS.draw_from_play_to_discard, which was not present "
                .. "when this mod loaded; the Joker will do nothing")
        end
    end,
}

--------------------------------------------------------------------------------
-- Occi [Rare] - everything that scored is an Ace of Spades.
--------------------------------------------------------------------------------
--
-- Midas Mask is the reference: it runs on context.before, walks
-- context.scoring_hand and rewrites each card in place, then juices them up
-- from an event. The rewrite is synchronous and the animation is not, which is
-- what makes the change count towards the hand it triggered on - context.before
-- runs after the poker hand has been named but before any card scores, and an
-- event queued there would not run until the whole hand had already scored.
--
-- Suitless AND rankless cards are left alone: Stone and Limestone are the card
-- rather than a card with a face on it, and giving them an Ace of Spades base
-- would hand them a rank and a suit they are not supposed to have. This is the
-- same line FeFe and its siblings draw.

SMODS.Joker {
    key = "occi",
    atlas = "occi",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    -- Spades is a vanilla suit, so {C:spades} paints it and there is no
    -- {V:1} colour to thread through vars the way the added suits need.
    loc_vars = function(self, info_queue, card)
        return { vars = { localize("Ace", "ranks"),
                          localize("Spades", "suits_plural") } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            local scoring = context.scoring_hand
            if type(scoring) ~= "table" then return end

            local changed = 0
            for _, played in ipairs(scoring) do
                -- What is printed on the card, not what it counts as: a Wild
                -- Ace already counts as a Spade, and leaving it alone would
                -- mean Occi silently skipped a card it is meant to convert.
                local base = played.base or {}
                local already = base.suit == "Spades" and base.value == "Ace"
                if not (SMODS.has_no_suit(played) and SMODS.has_no_rank(played))
                    and not already then
                    convert_played_base(played, "Spades", "Ace")
                    changed = changed + 1
                    local target = played
                    G.E_MANAGER:add_event(Event {
                        func = function() target:juice_up() return true end
                    })
                end
            end

            if changed > 0 then
                return {
                    message = localize("celesta_aces"),
                    colour = G.C.SPADES,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Matarakan [Common] - a savings account with a deadline.
--------------------------------------------------------------------------------
--
-- The money from a sale goes into the Joker instead of into the player's
-- pocket. Vanilla pays a sale out from inside Card:sell_card, in a queued
-- event, and only then raises context.selling_card on every OTHER Joker in the
-- row - so the sale price is still readable on context.card, and taking it
-- back is a matter of queuing the opposite. Both events land in the same
-- drain, so the player never sees the money arrive.
--
-- Paying out at "the end of the Ante" is Rocket's test: context.end_of_round
-- with G.GAME.blind.boss, which is the round that finishes an Ante.
--
-- Self-destruct is Gros Michel's: remove from the row first, then remove the
-- card. That route is also the one merge/bind.lua watches, so a merged
-- Matarakan unmerges and leaves its partner behind rather than taking it down
-- - which holds only while it asks to die ONCE. See main_eval below.

SMODS.Joker {
    key = "matarakan",
    atlas = "matarakan",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    -- Copying it would copy the payout without the deposits.
    blueprint_compat = false, eternal_compat = false,

    -- ...and CDawg does not retain it at all. What this Joker does to a card
    -- is fill it with money and then destroy it, and the card CDawg would be
    -- running that on is CDawg. See jokers/cdawg.lua.
    celesta_cdawg_never = true,

    config = { extra = { stored = 0, payout_mult = 1.5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.payout_mult,
                          card.ability.extra.stored } }
    end,

    calculate = function(self, card, context)
        if context.selling_card and context.card and not context.blueprint then
            local price = context.card.sell_cost or 0
            if price > 0 then
                card.ability.extra.stored = card.ability.extra.stored + price
                -- Queued rather than returned as `dollars`: the sale's own
                -- payout is a queued event too, and this has to land behind it
                -- rather than being folded into a scoring total.
                G.E_MANAGER:add_event(Event {
                    func = function() ease_dollars(-price) return true end
                })
                return {
                    message = localize("celesta_stored"),
                    colour = G.C.MONEY,
                    card = card,
                }
            end
        end

        -- main_eval is the once-a-round Joker pass. Without it this branch
        -- also runs for every card held in hand, and it both pays and asks to
        -- die - so the money came out several times over, and the second death
        -- arrived at a card that had already unmerged and took the surviving
        -- half with it.
        if context.end_of_round and context.main_eval and not context.blueprint
            and G.GAME and G.GAME.blind and G.GAME.blind.boss then
            local payout = math.floor(card.ability.extra.stored
                                      * card.ability.extra.payout_mult)

            -- Gros Michel's exit, beat for beat.
            G.E_MANAGER:add_event(Event {
                func = function()
                    play_sound("tarot1")
                    card.T.r = -0.2
                    card:juice_up(0.3, 0.4)
                    card.states.drag.is = true
                    card.children.center.pinch.x = true
                    G.E_MANAGER:add_event(Event {
                        trigger = "after", delay = 0.3, blockable = false,
                        func = function()
                            G.jokers:remove_card(card)
                            card:remove()
                            return true
                        end
                    })
                    return true
                end
            })

            -- `dollars` rather than a hand-rolled ease_dollars: Steamodded
            -- pays it out and prints the +$N itself, in every context.
            if payout > 0 then
                return { dollars = payout, colour = G.C.MONEY, card = card }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Projekt Melody [Uncommon] - the payout that grows either way.
--------------------------------------------------------------------------------
--
-- Paid through calc_dollar_bonus, so the money appears as its own line on the
-- cash-out screen the way Rocket's and Delayed Gratification's do.
--
-- The raise happens on context.ending_shop rather than context.end_of_round,
-- and that is the whole difference between paying $1 on the first round and
-- paying $2. end_of_round runs BEFORE the cash-out screen asks each Joker for
-- its dollar bonus - it is why Rocket pays its upgraded amount on the very
-- round the Boss died - so raising there would mean the first round already
-- paid the second round's rate. Leaving the shop is unambiguously after the
-- round, and it is the one thing a played round always ends with.
--
-- Skipping a Blind never reaches a shop, which is why the two raises sit on
-- two different contexts rather than on one with a flag.

SMODS.Joker {
    key = "projektmelody",
    atlas = "projektmelody",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { dollars = 1, round_gain = 1, skip_gain = 3 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.dollars,
                          card.ability.extra.round_gain,
                          card.ability.extra.skip_gain } }
    end,

    -- What THIS round pays, which is not what the Joker will be worth once the
    -- round is over.
    --
    -- The raise happens in the end_of_round pass, and the cash-out screen reads
    -- this afterwards - end_round() runs the Joker pass at state_events.lua:101
    -- and the payout is not collected until the round-evaluation UI is built,
    -- at :1176. Without a value fixed before the raise, the round just finished
    -- would collect the raise it had only just earned, and the first round
    -- would never pay the printed amount even once.
    calc_dollar_bonus = function(self, card)
        local dollars = card.ability.extra.paid or card.ability.extra.dollars
        if dollars <= 0 then return end
        return dollars
    end,

    calculate = function(self, card, context)
        -- "after each round" is the end of the round, not the end of the shop.
        -- context.ending_shop is a whole screen later, and reads as the Joker
        -- upgrading on the way out of the shop rather than for the round it
        -- was paid for.
        --
        -- It also settles who is owed the raise without a flag: a Joker bought
        -- in the shop after a round was not in the row for that round's
        -- end_of_round pass, so it simply does not get it.
        if context.end_of_round and context.main_eval and not context.blueprint then
            card.ability.extra.paid = card.ability.extra.dollars
            card.ability.extra.dollars =
                card.ability.extra.dollars + card.ability.extra.round_gain
            return {
                message = localize("k_upgrade_ex"),
                colour = G.C.MONEY,
                card = card,
            }
        end

        -- A skipped Blind ends no round, so there is no payout to fix first.
        if context.skip_blind and not context.blueprint then
            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "dollars",
                scalar_value = "skip_gain",
                no_message = true,
            })
            return {
                message = localize("k_upgrade_ex"),
                colour = G.C.MONEY,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Reading the run's money
--------------------------------------------------------------------------------
--
-- G.GAME.dollars is not always a Lua number. With Talisman installed it becomes
-- one of its big-number tables once the run's money outgrows a double - and
-- Talisman also replaces math.max with one that returns a big whenever EITHER
-- argument is one, so even a debt of nothing can arrive as a table.
--
-- That is not a display problem. Lua 5.1 consults __lt only when BOTH operands
-- are tables, so `dollars > 0` against a big is not a slow comparison, it is a
-- hard error - "attempt to compare number with table" - and it took the run
-- down mid-hand. Every comparison against money therefore goes through here.

--- The run's money, defaulting to nothing before a run exists.
local function money()
    return (G.GAME and G.GAME.dollars) or 0
end

--- a < b, whichever kind of number either side is.
--- to_big is only reached when one of them is already one of Talisman's, and
--- only Talisman makes those, so it is present whenever this branch is.
local function money_lt(a, b)
    if type(a) == "table" or type(b) == "table" then
        return to_big(a) < to_big(b)
    end
    return a < b
end

--- a == b, on the same terms. Lua 5.1 will not reach __eq across types either;
--- it merely answers false rather than erroring, which is worse - the card
--- silently stops working instead of saying so.
local function money_eq(a, b)
    if type(a) == "table" or type(b) == "table" then
        return to_big(a) == to_big(b)
    end
    return a == b
end

--------------------------------------------------------------------------------
-- Pwistine [Uncommon] - broke, exactly.
--------------------------------------------------------------------------------
--
-- Vanilla's Bull reads G.GAME.dollars straight, and so does this. Exactly
-- zero: a dollar either way and it is worth nothing, which is the whole card.

SMODS.Joker {
    key = "pristinezero",
    atlas = "pristinezero",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 3 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        if context.joker_main and money_eq(money(), 0) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Minikomew [Common] - paid by the size of the hole.
--------------------------------------------------------------------------------
--
-- Bull again with the sign flipped: Bull is extra*math.max(0, G.GAME.dollars),
-- and this is the same expression asked about the debt instead. At $0 or above
-- it is worth nothing at all.

--- How far below zero the player is, never negative.
---
--- A plain number wherever one will do, and one of Talisman's only once the
--- debt has outgrown one - so the ordinary case never pays for the unusual.
--- math.max is deliberately not used on the big path: Talisman's returns a big
--- whichever way the comparison went, which is what made `debt > 0` a crash.
local function minikomew_debt()
    local dollars = money()
    if type(dollars) ~= "table" then
        return math.max(0, -dollars)
    end
    local debt = to_big(0) - to_big(dollars)
    return money_lt(0, debt) and debt or 0
end

--- True when there is any debt at all. The helper above returns a table only
--- when it has already established the debt is positive, so a table IS debt.
local function minikomew_in_debt(debt)
    if type(debt) == "table" then return true end
    return debt > 0
end

-- Shared with MinikoMew's merges in merge/bind.lua, which read the same debt.
CelestasMod.minikomew_debt = minikomew_debt
CelestasMod.minikomew_in_debt = minikomew_in_debt

SMODS.Joker {
    key = "minikomew",
    atlas = "minikomew",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { mult = 2 } },

    loc_vars = function(self, info_queue, card)
        -- Arithmetic across the two kinds is fine - Lua 5.1 reaches __mul
        -- whichever side is the table - but the RESULT would print as
        -- "table: 0x..." on the card. number_format is vanilla's, and
        -- Talisman wraps it to render its own numbers.
        local shown = card.ability.extra.mult * minikomew_debt()
        if type(shown) == "table" then shown = number_format(shown) end
        return { vars = { card.ability.extra.mult, shown } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            local debt = minikomew_debt()
            if minikomew_in_debt(debt) then
                return { mult = card.ability.extra.mult * debt }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Ruben Sargasm [Common] - worth more in company.
--------------------------------------------------------------------------------
--
-- Sell value is not something a Joker returns; it is read off the card.
-- Vanilla computes it in Card:set_cost as
--     self.sell_cost = math.max(1, math.floor(self.cost/2)) + (self.ability.extra_value or 0)
-- so extra_value is the supported way to raise it, and Egg and Gift Card both
-- write to exactly that field.
--
-- The catch is that nothing calls set_cost when a Joker is bought, so the
-- value would sit stale until something else happened to refresh it.
-- Card:update is where vanilla solves the same problem for Temperance, which
-- re-adds every Joker's sell value there every frame - so this asks in the
-- same place, and only calls set_cost on the frames where the answer changed.

--- This Joker's own centre key. Written out the way Ray's target list is,
--- rather than built from SMODS.current_mod.prefix: the prefix is a constant
--- of this mod, and every other centre key named in this file is a literal.
local RUBEN_KEY = "j_celesta_rubensargasm"

--- Every Joker in the row counts, this one included - and a card merged from
--- two Rubens counts as two of them, which is how find_joker counts them.
---
--- Through card_abilities rather than off card.ability, because per_joker
--- belongs to the half that is Ruben: an absorbed half keeps its own table
--- under celesta_bind, and card.ability there is the HOST's, which has no
--- per_joker at all and so priced the merge at nothing.
---
--- The absorbed half's description is drawn with its own centre and ability
--- lent to the card (Bind's partner_ui), and during that lend the card does
--- not look merged - so this answers for that half alone, which is what that
--- panel should say. Outside the lend it answers for the whole card, which is
--- what the price is.
local function ruben_extra_value(card)
    local jokers = #(((G.jokers or {}).cards) or {})
    local total = 0
    for _, ability in ipairs(CelestasMod.card_abilities(card, RUBEN_KEY, true)) do
        local per = ability.extra and ability.extra.per_joker
        total = total + (per or 0) * jokers
    end
    return total
end

--- True for a card whose sell value this Joker is raising.
---
--- Cheapest test first: almost every card in the game is not a Joker at all,
--- and this is asked of all of them on every frame.
---
--- Either half of a merge counts. This used to compare card.config.center_key
--- against Ruben's, and a merged card keeps the HOST's - so Ruben paid when it
--- was the first Joker selected and did nothing when it was the second, which
--- is an ability that depended on the order they were highlighted in.
---
--- count_debuffed, because a debuffed Ruben has always kept its sell value and
--- taking that away is a different change from this one. card_is_joker still
--- refuses a REPLACING pair, which speaks for both halves: none of it, either
--- way round.
local function ruben_applies(card)
    if not (card.ability and card.ability.set == "Joker"
        and card.area == G.jokers) then
        return false
    end
    return CelestasMod.card_is_joker(card, RUBEN_KEY, true)
end

-- Added at set_cost, never stored.
--
-- ability.extra_value is vanilla's supported field for this and the total used
-- to be written into it. The trouble is WHERE that field lives: one level down
-- card.ability, which is exactly where Cryptid's misprintize walks and
-- randomises every number it finds - the same reach the Misprint note in
-- merge/bind.lua is about. A derived total sitting in a field another mod
-- rewrites drifts away from the description, which recomputes the same total
-- every time it is drawn. The card read "+$94.2" and sold for $31.
--
-- Derived at the point of use instead. The description and the price now come
-- from one function, so they cannot disagree whatever else touches the card.
local celesta_ruben_cost_ref = Card.set_cost
function Card:set_cost(...)
    local mine = ruben_applies(self)
    -- A run saved by the version that stored the total still carries it, and
    -- vanilla's set_cost adds extra_value on top of whatever this adds below.
    if mine then self.ability.extra_value = 0 end

    local ret = celesta_ruben_cost_ref(self, ...)

    if mine then
        self.sell_cost = (self.sell_cost or 0) + ruben_extra_value(self)
        self.sell_cost_label = self.facing == "back" and "?" or self.sell_cost
    end
    return ret
end

--- The joker count each Ruben was last priced against, so set_cost is called
--- when the row changes rather than on every frame. Weak-keyed: a sold Joker
--- should not be kept alive by this.
local ruben_counted = setmetatable({}, { __mode = "k" })

local celesta_ruben_update_ref = Card.update
function Card:update(dt)
    celesta_ruben_update_ref(self, dt)

    if ruben_applies(self) then
        local n = #(((G.jokers or {}).cards) or {})
        if ruben_counted[self] ~= n then
            ruben_counted[self] = n
            self:set_cost()
        end
    end
end

SMODS.Joker {
    key = "rubensargasm",
    atlas = "rubensargasm",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 4,
    unlocked = true, discovered = false,
    -- It has no calculate to copy; the sell value belongs to this card.
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.per_joker,
                          ruben_extra_value(card) } }
    end,

    config = { extra = { per_joker = 2 } },
}

--------------------------------------------------------------------------------
-- Kourra [Common] - paid by the chips already on the board.
--------------------------------------------------------------------------------
--
-- `hand_chips` is a global that G.FUNCS.evaluate_play keeps the running chip
-- total in - Steamodded reads and writes the same one, as _G.hand_chips - so
-- reading it during joker_main is reading the score as it stands right now.
--
-- Which means POSITION MATTERS, and that is the card. Jokers score left to
-- right, so Kourra counts the played cards' chips plus whatever any Joker to
-- its LEFT has added, and nothing from its right. Sliding it one place along
-- the row is a real decision.
--
-- The awkward part is Talisman. Once the numbers get big it replaces them with
-- its own objects, and math.floor on one of those is not arithmetic. So the
-- value is asked for a plain Lua number first, and only when it is too large
-- to be one does this fall back to Talisman's own arithmetic - dropping the
-- floor there, because at that magnitude the fraction it would remove is
-- smaller than the number can represent anyway.

--- A plain Lua number for `value`, whether it is one already or one of
--- Talisman's. Returns nil when it cannot be one - too large, or not a number
--- at all - so the caller can tell that apart from a genuine zero.
local function plain_number(value)
    if type(value) == "number" then
        -- nan is the only value that is not equal to itself.
        if value ~= value or value == math.huge or value == -math.huge then
            return nil
        end
        return value
    end
    if type(value) == "table" and type(value.to_number) == "function" then
        local ok, n = pcall(value.to_number, value)
        if ok and type(n) == "number" and n == n
            and n ~= math.huge and n ~= -math.huge then
            return n
        end
    end
    return nil
end

SMODS.Joker {
    key = "kourra",
    atlas = "kourra",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { mult = 2, per_chips = 50 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.mult, card.ability.extra.per_chips } }
    end,

    calculate = function(self, card, context)
        if not context.joker_main then return end

        local per = card.ability.extra.per_chips
        local gain = card.ability.extra.mult
        local chips = hand_chips or 0

        local plain = plain_number(chips)
        if plain then
            local steps = math.floor(plain / per)
            if steps <= 0 then return end
            return { mult = steps * gain }
        end

        -- Past what a Lua number holds, Talisman's arithmetic is the only
        -- thing that can still answer.
        if to_big then
            return { mult = to_big(chips) / per * gain }
        end
    end,
}

--------------------------------------------------------------------------------
-- SmittenSeraph [Rare] - room for everything.
--------------------------------------------------------------------------------
--
-- Slots are held on the CardArea, not in starting_params, and the one thing in
-- vanilla that changes them mid-run is the Negative edition:
--     G.jokers.config.card_limit = G.jokers.config.card_limit + 1
-- in Card:add_to_deck, undone in remove_from_deck. This is that, with bigger
-- numbers - but NOT applied once on arrival, which is what it used to do and
-- what made it silently un-scalable.
--
-- Granted by DELTA, from `update`, against what this card is already holding.
-- Two reasons, and the second is the one that matters:
--
--   * Nothing re-reads the number after it changes. Applying it once in
--     add_to_deck meant that anything raising extra.joker_slots later - Yoka
--     Siri, a Cryptid misprint - moved the text on the card and nothing else.
--     The card said +4.5 while the tray still held 8.
--
--   * Re-seating the Joker to re-apply it does not work either, and cannot.
--     Steamodded replaces a CardArea's config with a metatable: reading
--     card_limit returns `total_slots - extra_slots_used`, and writing it
--     stores `mod = value - base - extra_slots` (lovely/card_limit.toml:30).
--     total_slots is only recomputed once a frame, in
--     CardArea:handle_card_limit. So a remove-then-add inside one frame reads
--     the SAME stale number twice: take 3 off 8 and then add 4.5 to 8 again,
--     and the run ends up with 12.5 slots rather than 9.5.
--
-- One write per change, which is what makes the read-modify-write safe: the
-- sync only writes when the number has moved, and records what it granted, so
-- there is never a second write before the frame's recompute.

local SERAPH_GRANTED = "celesta_seraph_granted"

--- Moves an area's slot count by `delta`.
---
--- Through card_limits.mod rather than through config.card_limit, and that is
--- the whole difference between this working and not. Under Steamodded
--- card_limit is DERIVED - reading it returns total_slots minus the slots in
--- use, and total_slots is recomputed once a frame in
--- CardArea:handle_card_limit. `mod` is where the write actually lands and is
--- the authoritative half.
---
--- So `config.card_limit = config.card_limit + n` reads a number that is only
--- as fresh as the last frame. One of those per frame is fine. TWO is not, and
--- two is exactly what Cryptid does: with_deck_effects takes the Joker out of
--- the deck, changes the number and puts it back, all inside one frame, so
--- both the take and the give read the same stale 8 - and 8 minus 3 plus 4.5
--- is 9.5 only if the 8 moved in between. It does not, and the run ended up
--- with 12.5 slots.
---
--- Adding to `mod` has no such problem: it is stored, not derived.
local function bump_limit(area, delta)
    if delta == 0 or not area or not area.config then return end
    local limits = area.config.card_limits
    if limits then
        limits.mod = (limits.mod or 0) + delta
    else
        -- No Steamodded metatable: card_limit is an ordinary field.
        area.config.card_limit = area.config.card_limit + delta
    end
end

-- Shared with Ellie Minibot + Shoomimi in merge/bind.lua, which grants a slot.
CelestasMod.bump_limit = bump_limit

--- What this card is worth right now, in whole slots.
---
--- Rounded, because a slot is a thing you either have or do not. The game
--- tests `#cards < card_limit`, so a limit of 8.3 would let a ninth Joker in
--- while the card claimed 8.3.
---
--- This used to be multiplied by Vedal, which at the time scaled every number
--- this mod's Jokers showed. Vedal does not do that any more - it changes how
--- scaling Jokers scale and nothing else - so the two numbers are now simply
--- what the card says.
local function seraph_slots(card)
    local extra = card.ability.extra
    return math.floor(extra.joker_slots + 0.5),
           math.floor(extra.consumable_slots + 0.5)
end

--- Brings the run's slots in line with what this card currently promises.
local function seraph_sync(card)
    local held = card.ability[SERAPH_GRANTED] or { jokers = 0, consumables = 0 }
    local want_j, want_c = seraph_slots(card)
    if held.jokers == want_j and held.consumables == want_c then return end

    bump_limit(G.jokers, want_j - held.jokers)
    bump_limit(G.consumeables, want_c - held.consumables)
    card.ability[SERAPH_GRANTED] = { jokers = want_j, consumables = want_c }
end

--- ...and hands all of it back.
local function seraph_release(card)
    local held = card.ability[SERAPH_GRANTED]
    if not held then return end
    bump_limit(G.jokers, -held.jokers)
    bump_limit(G.consumeables, -held.consumables)
    card.ability[SERAPH_GRANTED] = nil
end

SMODS.Joker {
    key = "smittenseraph",
    atlas = "smittenseraph",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 9,
    unlocked = true, discovered = false,
    -- Nothing to copy: the slots belong to this card, and they are given and
    -- taken back by its own hooks.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { joker_slots = 3, consumable_slots = 1 } },

    loc_vars = function(self, info_queue, card)
        local jokers, consumables = seraph_slots(card)
        return { vars = { jokers, consumables } }
    end,

    add_to_deck = function(self, card, from_debuff)
        seraph_sync(card)
    end,

    remove_from_deck = function(self, card, from_debuff)
        seraph_release(card)
    end,

    -- Every frame, but it writes only when the number has actually moved. The
    -- added_to_deck gate keeps a copy in the shop or the collection from
    -- handing out slots it does not own.
    update = function(self, card, front)
        if card.added_to_deck then seraph_sync(card) end
    end,
}

--------------------------------------------------------------------------------
-- Shiabun [Uncommon] - one more card in hand can be picked.
--------------------------------------------------------------------------------
--
-- The selection limit is Steamodded's, not vanilla's: SMODS.change_play_limit
-- and SMODS.change_discard_limit keep G.GAME.starting_params.play_limit and
-- discard_limit, then set G.hand.config.highlighted_limit to the larger of the
-- two. Cryptid's Grappling Hook voucher moves both by the same amount, which is
-- what "card selection limit" means in one number, and this does the same.
--
-- Both, not one: moving only the play limit would let you select six cards to
-- play and then find you could not select six to discard.
--
-- Granted by DELTA from `update`, for the reason SmittenSeraph above is: those
-- two functions ADD to a stored number, and nothing calls them again when
-- extra.limit changes. Applied once on arrival, anything that raised the
-- number later - Yoka Siri, a misprint - moved the text on the card and left
-- the actual limit where it was.
--
-- Unhighlighting on the way out is Cryptid's too, and it matters - without it
-- a hand that already had six cards picked keeps them selected after the limit
-- has dropped back to five.

--- Shared with Eidolon Wyrm, which raises the same limit by a different
--- number. The field name is Shiabun's because it is what has been written
--- into saves since Shiabun shipped: renaming it would make an existing
--- Shiabun read back a zero and grant its limit a second time.
local SELECTION_GRANTED = "celesta_shiabun_granted"

--- Moves both limits by however much this card's number has changed.
---
--- `want` overrides the card's own number, for a Joker whose grant comes and
--- goes rather than simply being what it says: Slime God hands its two cards
--- back on a Big Blind and takes them again on the next Small one, and does it
--- through this same delta so the two of them cannot double-grant.
local function selection_sync(card, want)
    if not (SMODS.change_play_limit and SMODS.change_discard_limit) then
        CelestasMod.warn_once("selection_no_limit_api",
            "This mod raises the card selection limit through "
            .. "SMODS.change_play_limit, which this Steamodded does not "
            .. "have; the Jokers that do it will do nothing")
        return
    end
    local held = card.ability[SELECTION_GRANTED] or 0
    want = want or card.ability.extra.limit
    if held == want then return end

    SMODS.change_play_limit(want - held)
    SMODS.change_discard_limit(want - held)
    card.ability[SELECTION_GRANTED] = want
end

--- ...and gives all of it back.
local function selection_release(card)
    local held = card.ability[SELECTION_GRANTED]
    if not held or held == 0 then
        card.ability[SELECTION_GRANTED] = nil
        return
    end
    if SMODS.change_play_limit and SMODS.change_discard_limit then
        SMODS.change_play_limit(-held)
        SMODS.change_discard_limit(-held)
    end
    card.ability[SELECTION_GRANTED] = nil
    -- A selection made under the old limit would otherwise survive it.
    if G.hand and G.hand.unhighlight_all then G.hand:unhighlight_all() end
end

--------------------------------------------------------------------------------
-- Slime God [Rare] - a different Joker depending on which Blind is up.
--------------------------------------------------------------------------------
--
-- Blind:get_type answers 'Small', 'Big' or 'Boss' off the Blind's name
-- (blind.lua:368), and nil for the blank one that sits in G.GAME.blind between
-- rounds - so "no round in progress" needs no separate test.
--
-- The selection half is granted by DELTA through selection_sync, the same
-- route Shiabun and Eidolon Wyrm use, and for a reason those two do not have:
-- this grant comes and goes. Asked every frame from `update`, it hands the two
-- cards back on a Big Blind and takes them again on the next Small one, and
-- because the delta is computed from what this card has already given, the
-- coming and going cannot leak a card either way.
--
-- Both halves run on a Boss Blind, which is what makes it a Boss.

--- The Blind now, or nil between rounds.
local function slime_blind()
    local blind = G.GAME and G.GAME.blind
    if not (blind and blind.get_type) then return nil end
    return blind:get_type()
end

--- How many ranks are held twice or more.
---
--- ONE per rank, however many copies are held: two Queens and two Sixes are
--- two pairs, and so are three Queens and two Sixes. That is what "unique"
--- does here - counting every combination instead would make four of a kind
--- six pairs rather than one.
---
--- A rankless card is held but has no rank to match: Stone Cards, this mod's
--- Limestone and Foliage all report through has_no_rank.
local function slime_pairs()
    if not (G.hand and G.hand.cards) then return 0 end

    local seen, found = {}, 0
    for _, held in ipairs(G.hand.cards) do
        if held.get_id and not SMODS.has_no_rank(held) then
            local id = held:get_id()
            seen[id] = (seen[id] or 0) + 1
            -- Counted on the SECOND copy and never again, which is the whole
            -- of "one per rank".
            if seen[id] == 2 then found = found + 1 end
        end
    end
    return found
end

SMODS.Joker {
    key = "slimegod",
    atlas = "slimegod",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- Half of it is a passive nothing can copy, and a copy of the other half
    -- would read as the whole Joker being copied. Eidolon Wyrm is the same
    -- shape for the same reason.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { selection = 2, x_mult = 1, x_mult_gain = 0.2 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return { vars = { extra.selection, extra.x_mult_gain, extra.x_mult } }
    end,

    add_to_deck = function(self, card, from_debuff)
        selection_sync(card, 0)
        if not from_debuff then
            CelestasMod.play_join_sound("j_celesta_slimegod")
        end
    end,

    remove_from_deck = function(self, card, from_debuff)
        selection_release(card)
    end,

    update = function(self, card, front)
        if not card.added_to_deck then return end
        local blind = slime_blind()
        local want = (blind == "Small" or blind == "Boss")
            and card.ability.extra.selection or 0
        selection_sync(card, want)
    end,

    calculate = function(self, card, context)
        -- Before the hand scores, while the cards NOT played are still the
        -- ones in G.hand - which is what "held in hand" means.
        if context.before and not context.blueprint then
            local blind = slime_blind()
            if not (blind == "Big" or blind == "Boss") then return end

            local pairs_held = slime_pairs()
            if pairs_held <= 0 then return end

            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "x_mult",
                scalar_value = "x_mult_gain",
                no_message = true,
                operation = function(ref_table, ref_value, initial, scaling)
                    ref_table[ref_value] = initial + scaling * pairs_held
                end,
            })
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { card.ability.extra.x_mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        -- X1 is no multiplier at all, and returning it would put a "X1 Mult"
        -- flourish over the Joker every hand for doing nothing.
        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

SMODS.Joker {
    key = "shiabun",
    atlas = "shiabun",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { limit = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.limit } }
    end,

    add_to_deck = function(self, card, from_debuff)
        selection_sync(card)
    end,

    remove_from_deck = function(self, card, from_debuff)
        selection_release(card)
    end,

    update = function(self, card, front)
        if card.added_to_deck then selection_sync(card) end
    end,
}

--------------------------------------------------------------------------------
-- Pipi [Common] - two cards, both counted, both twice.
--------------------------------------------------------------------------------
--
-- Two separate contexts, because they are two separate questions.
--
-- "Score both" is the one Splash answers, and Unnamed above answers it the same
-- way: modify_scoring_hand is asked about every played card in turn, and
-- add_to_hand is the supported way to say yes. It is needed because a two-card
-- hand is not always two scoring cards - a Pair scores both, but a High Card
-- scores one and leaves the other sitting there.
--
-- "Retrigger both" is context.repetition in G.play, which is Sock and Buskin's
-- shape. It is asked once per scoring card, so returning one repetition each
-- gives two triggers apiece - and it is asked AFTER the scoring hand has been
-- widened, so the card the first half added gets retriggered too.

--- How many cards were played, whichever context is asking.
local function pipi_played_count(context)
    local hand = context.full_hand or (G.play and G.play.cards)
    return hand and #hand or 0
end

SMODS.Joker {
    key = "pipi",
    atlas = "pipi",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    -- Widening the scoring hand is a yes/no answer; a copy cannot say yes
    -- harder, and the retrigger it could copy is not worth the confusion of
    -- half the Joker being copyable.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { cards = 2, repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.cards } }
    end,

    calculate = function(self, card, context)
        if pipi_played_count(context) ~= card.ability.extra.cards then return end

        if context.modify_scoring_hand and context.other_card
            and CelestasMod.hand_is_being_played() then
            return { add_to_hand = true }
        end

        if context.repetition and context.cardarea == G.play then
            return {
                message = localize("k_again_ex"),
                repetitions = card.ability.extra.repetitions,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- ItsDeadlyBoop [Rare] - both halves of the score, on one hand.
--------------------------------------------------------------------------------
--
-- context.poker_hands is every hand the played cards make, not only the one
-- the game named, so this pays on anything CONTAINING a Full House - a Flush
-- House, and a Five of a Kind, which registers one because its five same-rank
-- cards satisfy both the three-of-a-rank and two-of-a-rank halves.
--
-- That is the same test The Duo and its siblings use for "contains a Pair",
-- and the opposite of the one Sly Joker uses to name a hand outright.
--
-- Every entry in that table exists whether or not the hand was made - it is
-- built with all eleven keys and left empty - so the question is whether the
-- entry has anything in it, not whether it is there.
--
-- Both keys come back from a single return. Steamodded applies each scoring
-- key it recognises off the same table, so there is nothing gained by
-- answering twice.

SMODS.Joker {
    key = "itsdeadlyboop",
    atlas = "itsdeadlyboop",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 2, x_chips = 2, hand = "Full House" } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult, card.ability.extra.x_chips,
                          localize(card.ability.extra.hand, "poker_hands") } }
    end,

    calculate = function(self, card, context)
        if not context.joker_main then return end

        local hands = context.poker_hands
        local made = hands and hands[card.ability.extra.hand]
        if made and next(made) then
            return {
                x_mult = card.ability.extra.x_mult,
                x_chips = card.ability.extra.x_chips,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- RYNxRYN [Rare] - every Gold Card goes round twice.
--------------------------------------------------------------------------------
--
-- Two cardareas, because a Gold Card has two jobs and they pay in different
-- passes. G.play is Sock and Buskin's retrigger, and re-scores the card's
-- chips. G.hand is Mime's, and that is where the $3 lives: a Gold Card pays
-- for being HELD, at the end of the round, not for being played.
--
-- That end-of-round pass is a third context wearing the second one's clothes -
-- it arrives as repetition + cardarea == G.hand with end_of_round set - so
-- naming G.hand covers it without naming it, exactly as Mime does.
--
-- Mime carries a guard this does not need. It checks context.card_effects for
-- something worth repeating, because a card held in hand during SCORING often
-- has no held-in-hand effect at all and retriggering it would announce
-- "Again!" over nothing. Steamodded already refuses to ask the question in
-- that case - calculate_repetitions runs there only `if flags.calculated` -
-- so the guard would be dead code here. The end-of-round pass has no such
-- gate, which is right: that is the one where the money is.

SMODS.Joker {
    key = "rynxryn",
    atlas = "rynxryn",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_gold
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        if context.repetition and context.other_card
            and (context.cardarea == G.play or context.cardarea == G.hand)
            and SMODS.has_enhancement(context.other_card, "m_gold") then
            return {
                message = localize("k_again_ex"),
                repetitions = card.ability.extra.repetitions,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Ben [Rare] - a bigger hand, but only against the Boss.
--------------------------------------------------------------------------------
--
-- Hand size is a running total on G.hand, not a value anything recomputes, so
-- a Joker that changes it for a while has to give back exactly what it took.
-- The Manacle is the closest thing in the game - it does G.hand:change_size(-1)
-- when the Blind is set and change_size(1) again in Blind:defeat and
-- Blind:disable - and everything below is the same idea reached through the
-- hooks a Joker actually gets.
--
-- The flag is the whole of the safety. Every path goes through ben_hold, which
-- does nothing unless the answer is changing, so no route can double-apply and
-- none can give back twice. The routes are:
--
--   setting_blind     the Blind just became (or stopped being) a Boss
--   end_of_round      the round is over, whoever won
--   add_to_deck       bought or un-debuffed - possibly mid-Boss
--   remove_from_deck  sold, destroyed or debuffed - possibly mid-Boss
--
-- add_to_deck and remove_from_deck cover debuffing for free, because that is
-- how vanilla implements it: Card:set_debuff calls remove_from_deck(true) and
-- add_to_deck(true). Which is also why the SOUND checks from_debuff and the
-- hand size does not - a debuffed Ben should stop working, but it has not
-- arrived again.
--
-- A disabled Boss Blind - Luchador, Chicot - still counts. It is still the
-- Boss Blind; it just is not doing anything.

--- True while the run is on a Boss Blind.
local function ben_boss_blind()
    local blind = G.GAME and G.GAME.blind
    return (blind and blind.boss) and true or false
end

--- True when a Bind pair ability has taken this card over. A special replaces
--- both halves, so Ben's own conditional hand size must let go - two claims on
--- one number is how a hand ends up permanently bigger.
---
--- Letting go itself needs no help from the pair. Both routes into a merge run
--- Ben's own remove_from_deck: Bind.merge calls the host centre's directly
--- when a special forms, and the absorbed card dissolves through Card:remove,
--- which calls remove_from_deck on its way out. This only has to make sure it
--- does not come straight back.
local function ben_superseded(card)
    local bind = CelestasMod.Bind
    return bind and bind.special_of and bind.special_of(card) and true or false
end

--- Applies or removes the bonus, and only ever on a change.
local function ben_hold(card, wanted)
    local extra = card.ability and card.ability.extra
    if not extra then return end
    if ben_superseded(card) then wanted = false end
    if (extra.applied == true) == (wanted == true) then return end

    extra.applied = wanted or nil
    if G.hand and G.hand.change_size then
        G.hand:change_size(wanted and extra.h_size or -extra.h_size)
    end
end

SMODS.Joker {
    key = "ben",
    atlas = "ben",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- Hand size belongs to this card and is given back by its own hooks;
    -- there is no scoring effect for a copier to repeat.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { h_size = 4, applied = nil } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.h_size } }
    end,

    -- Its own rather than announces(), because it has a second job: the same
    -- from_debuff that must silence the sound must NOT skip the hand size,
    -- since a debuffed Ben should stop working.
    add_to_deck = function(self, card, from_debuff)
        if not from_debuff then CelestasMod.play_join_sound("j_celesta_ben") end
        ben_hold(card, ben_boss_blind())
    end,

    remove_from_deck = function(self, card, from_debuff)
        ben_hold(card, false)
    end,

    calculate = function(self, card, context)
        if context.setting_blind then
            ben_hold(card, ben_boss_blind())
            if card.ability.extra.applied then
                -- a_handsize is vanilla's own "+N Hand Size", so the number
                -- shown is the one actually applied rather than a fixed
                -- string that would lie if h_size ever changed.
                return {
                    message = localize { type = "variable", key = "a_handsize",
                                         vars = { card.ability.extra.h_size } },
                    colour = G.C.FILTER,
                    card = card,
                }
            end
        end

        if context.end_of_round then
            ben_hold(card, false)
        end
    end,
}

--------------------------------------------------------------------------------
-- Boosfer [Legendary] - retriggers Stars, and feeds on every retrigger.
--------------------------------------------------------------------------------
--
-- The Mult is not limited to the retriggers Boosfer hands out itself. Mime,
-- Sock and Buskin, a Red Seal, a second Boosfer - anything that makes a Star
-- card score again feeds it, which is what makes it worth a Legendary slot.
--
-- Nothing raises a context that says "a repetition happened", so it is counted
-- off the scoring pass instead. SMODS.score_card collects a card's repetitions
-- once and then runs the whole individual pass once per repetition, so a Star
-- retriggered N times raises context.individual N+1 times for that card: the
-- first is the card scoring, and every one after it is a retrigger.
--
-- Telling those apart needs a mark, and the mark is cleared in context.before,
-- which lands ahead of all scoring in the same hand. A mark can therefore
-- never survive into a hand that would read it - and a debuffed Boosfer sets
-- none, because it is not evaluated at all.

--- Has this Joker already watched that card score this hand?
--- Records the sighting as it answers. Keyed by the Joker's ID rather than a
--- flag, so two Boosfers each count their own retriggers instead of one of
--- them stealing the other's first sighting.
local function boosfer_seen(target, joker)
    local seen = target.celesta_boosfer_seen
    if not seen then
        seen = {}
        target.celesta_boosfer_seen = seen
    end
    if seen[joker.ID] then return true end
    seen[joker.ID] = true
    return false
end

SMODS.Joker {
    key = "boosfer",
    atlas = "boosfer",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 1, x_mult = 1, x_mult_gain = 0.1 } },

    in_pool = star_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = star_name_and_colour()
        return { vars = { card.ability.extra.repetitions,
                          card.ability.extra.x_mult_gain,
                          card.ability.extra.x_mult,
                          name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        -- Ahead of any scoring in this hand: whatever the last hand saw is
        -- forgotten before it can be mistaken for a retrigger.
        if context.before and not context.blueprint then
            for _, played in ipairs(context.full_hand or {}) do
                if played.celesta_boosfer_seen then
                    played.celesta_boosfer_seen[card.ID] = nil
                end
            end
        end

        if context.repetition and context.cardarea == G.play
            and is_star(context.other_card) then
            return {
                message = localize("k_again_ex"),
                repetitions = card.ability.extra.repetitions,
                card = card,
            }
        end

        -- Counting, not scoring. A copy is skipped on both halves: it must not
        -- bank the gain, and marking on its behalf would make the real
        -- Boosfer's own first sighting look like a retrigger.
        if context.individual and context.cardarea == G.play
            and not context.blueprint and is_star(context.other_card) then
            if boosfer_seen(context.other_card, card) then
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "x_mult",
                    scalar_value = "x_mult_gain",
                    no_message = true,
                })
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { card.ability.extra.x_mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        -- joker_main runs after every played card has scored, so a retrigger
        -- seen this hand is already in the number.
        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Saiiren [Common] - one card a hand, and it moves every round.
--------------------------------------------------------------------------------
--
-- Walks the same rotation Yomi Quinnely does, on its own index: the four
-- vanilla suits, plus Stars and Leaves once the deck holds any. See
-- rotation_suits above for why the added suits are appended rather than
-- slotted in.
--
-- "The last scored card" is read off context.scoring_hand, which is the cards
-- the poker hand actually scores, in the order they were played. Reading
-- G.play.cards instead would count a card that is in the hand but not part of
-- it, and pay for one that never scored.

--- The last card of `suit` in the scoring hand, or nil.
---
--- Asked through is_suit rather than base.suit, which is what SCORING means by
--- a suit: a Wild Card is every suit, and so is everything while Arielle is
--- out. That makes a Wild Card the last card of whatever the rotation is on
--- whenever it is played last, which is what Wild is for.
local function saiiren_target(context, suit)
    local hand = context.scoring_hand
    if type(hand) ~= "table" then return nil end
    local last = nil
    for _, scored in ipairs(hand) do
        if scored.is_suit and scored:is_suit(suit) then last = scored end
    end
    return last
end

-- Shared with ObKatieKat + Saiiren in merge/bind.lua, which pays the same card
-- in ^Chips.
CelestasMod.saiiren_target = saiiren_target

SMODS.Joker {
    key = "saiiren",
    atlas = "saiiren",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 2, suit_index = 1 } },

    loc_vars = function(self, info_queue, card)
        local suits = rotation_suits()
        local suit = rotation_suit_at(suits, card.ability.extra.suit_index)
        -- Singular, because the name qualifies "card" - and the Leaf suit's
        -- plural is "Leaves", which would not read at all.
        return {
            vars = { card.ability.extra.x_mult,
                     localize(suit, "suits_singular"),
                     colours = { G.C.SUITS[suit] } },
        }
    end,

    calculate = function(self, card, context)
        local suits = rotation_suits()
        local suit = rotation_suit_at(suits, card.ability.extra.suit_index)

        -- cardarea == G.play is the scoring-card pass; an unscored card
        -- arrives as 'unscored' instead, and the end-of-round pass over the
        -- hand is G.hand, so neither reaches this.
        if context.individual and context.cardarea == G.play then
            if context.other_card == saiiren_target(context, suit) then
                return { x_mult = card.ability.extra.x_mult,
                         card = context.other_card }
            end
        end

        -- main_eval keeps the rotation to once per round rather than once per
        -- card evaluated during the end-of-round pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            -- Through rotation_index so a misprinted index is written
            -- back whole: advancing 46.101724272927 by hand would only carry
            -- the fraction forward for the rest of the run.
            card.ability.extra.suit_index =
                rotation_index(card.ability.extra.suit_index + 1, #suits)
            local next_suit = rotation_suit_at(suits, card.ability.extra.suit_index)
            return {
                message = localize(next_suit, "suits_singular"),
                colour = G.C.SUITS[next_suit],
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- JuniperActias [Uncommon] - grows on every Star that joins the deck.
--------------------------------------------------------------------------------
--
-- Counted rather than surveyed: this is about cards ARRIVING, not about how
-- many the deck holds, so converting a Heart into a Star with a Tarot does not
-- pay - nothing was added. context.playing_card_added is raised once per batch
-- with the cards in context.cards (misc_functions.lua:1582), which is where
-- vanilla Hologram counts the same event.
--
-- base.suit rather than is_suit, for the reason CelestasMod.suit_in_deck gives:
-- is_suit routes through SMODS.smeared_check, and Arielle widens that to match
-- everything, which would pay for every card added to every deck.

SMODS.Joker {
    key = "juniperactias",
    atlas = "juniperactias",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_chips = 1, x_chip_gain = 0.1 } },

    in_pool = star_gated,

    loc_vars = function(self, info_queue, card)
        local name, colour = star_name_and_colour()
        return { vars = { card.ability.extra.x_chip_gain,
                          card.ability.extra.x_chips,
                          name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if context.playing_card_added and not context.blueprint
            and not card.getting_sliced then
            local added = 0
            for _, new_card in ipairs(context.cards or {}) do
                local base = new_card.base
                if base and base.suit == CelestasMod.STARS_SUIT then
                    added = added + 1
                end
            end
            if added == 0 then return end

            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "x_chips",
                scalar_value = "x_chip_gain",
                no_message = true,
                operation = function(ref_table, ref_value, initial, scaling)
                    ref_table[ref_value] = initial + scaling * added
                end,
            })
            return {
                message = localize { type = "variable", key = "a_xchips",
                                     vars = { card.ability.extra.x_chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_chips, 1) then
            return { x_chips = card.ability.extra.x_chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- Nekrolina [Common] - worth more for every card that dies.
--------------------------------------------------------------------------------
--
-- Sell value is not returned from a calculate; it is read off the card. Vanilla
-- computes it in Card:set_cost as
--     self.sell_cost = math.max(1, math.floor(self.cost/2)) + (self.ability.extra_value or 0)
-- so extra_value is the supported field, the one Egg and Gift Card both write.
-- Ruben Sargasm uses it too, but for a value it recomputes every frame; this
-- one is banked, so it is written when the cards die and set_cost called there
-- and then.

SMODS.Joker {
    key = "nekrolina",
    atlas = "nekrolina",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    -- The value belongs to this card; a copy has nothing to add to it.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { dollars = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.dollars,
                          card.ability.extra_value or 0 } }
    end,

    calculate = function(self, card, context)
        -- remove_playing_cards is raised once after the destroy pass with every
        -- card that died, which is where vanilla Caino counts its face cards.
        -- Counting here catches a death however it happened - eaten, broken,
        -- shattered - rather than one route into it.
        if context.remove_playing_cards and not context.blueprint then
            local died = #(context.removed or {})
            if died == 0 then return end

            card.ability.extra_value = (card.ability.extra_value or 0)
                + card.ability.extra.dollars * died
            if card.set_cost then card:set_cost() end
            -- What went up is what this card SELLS for, not the player's
            -- money, and "Value Up!" is what the game says for that - the same
            -- message vanilla's Egg uses for the same move (card.lua:2989).
            -- A +$n here would read as cash that never arrived.
            return {
                message = localize("k_val_up"),
                colour = G.C.MONEY,
                card = card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Rainhoe [Uncommon] - interest, tripled, on a wet round.
--------------------------------------------------------------------------------
--
-- Interest is not a Joker effect. The cash-out reads G.GAME.interest_amount
-- directly (state_events.lua:1192), so the only way to change a round's
-- interest is to have changed that number before the screen is built.
--
-- Applied in the end_of_round pass rather than at setting_blind, which is when
-- the Downpour starts. That is not tidiness: Aquwa raises the Downpour from its
-- OWN setting_blind, so whether Rainhoe saw it would depend on which of the two
-- sat further left in the row. By the end of the round the question has one
-- answer - and the Arena is still up, because it is cleared on entering the
-- shop, not at the cash-out.
--
-- Taken back at ending_shop, which is after the payout and before the next
-- round, so the multiplier cannot compound across rounds.

--- Brings the interest bonus in line with whether it should be applied.
--- Written as a difference against what this card has already added, the way
--- Kairyu's hand size is: every path in and out goes through here, so the card
--- can be sold, debuffed and reloaded without the number drifting.
local function rainhoe_hold(card, on)
    local extra = card.ability.extra
    local applied = extra.applied or 0
    if not G.GAME then return false end

    if on then
        if applied > 0 then return false end
        local add = (G.GAME.interest_amount or 0) * (extra.scale - 1)
        if add <= 0 then return false end
        G.GAME.interest_amount = G.GAME.interest_amount + add
        extra.applied = add
        return true
    end

    if applied <= 0 then return false end
    G.GAME.interest_amount = (G.GAME.interest_amount or 0) - applied
    extra.applied = 0
    return true
end

SMODS.Joker {
    key = "rainhoe",
    atlas = "rainhoe",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A copy would triple the interest a second time, off one round.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { scale = 3, applied = 0 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.scale } }
    end,

    remove_from_deck = function(self, card, from_debuff)
        rainhoe_hold(card, false)
    end,

    calculate = function(self, card, context)
        -- main_eval is the once-per-round Joker pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            local wet = CelestasMod.Arena and CelestasMod.Arena.is_active("downpour")
            if rainhoe_hold(card, wet and true or false) then
                return {
                    message = localize("celesta_downpour"),
                    colour = G.C.BLUE,
                    card = card,
                }
            end
        end

        if context.ending_shop and not context.blueprint then
            rainhoe_hold(card, false)
        end
    end,
}

--------------------------------------------------------------------------------
-- Nyanners [Common] - paid by the company it keeps.
--------------------------------------------------------------------------------
--
-- Counted live off the row rather than banked, the way Bricky counts the deck:
-- "for each owned Joker" is a question about the row as it is NOW, so selling
-- one takes the Chips back rather than leaving them earned.
--
-- A merged Joker counts twice. It is two Jokers in one slot, which is the whole
-- of what Bind does, and counting it once would make merging a way to lose
-- Chips.

--- How many Jokers the row is worth, merges counted double.
local function nyanners_count()
    local total = 0
    for _, joker in ipairs((G.jokers and G.jokers.cards) or {}) do
        total = total + 1
        -- Through the row lookup rather than Bind.is_merged directly: this
        -- counts the card it is ASKED ON as well as every other, and a card
        -- asked about itself from inside its own description is lent to one
        -- half and does not look merged to the direct test.
        if CelestasMod.card_is_merged(joker) then
            total = total + 1
        end
    end
    return total
end

SMODS.Joker {
    key = "nyanners",
    atlas = "nyanners",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 15 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.chips,
                          card.ability.extra.chips * 2,
                          card.ability.extra.chips * nyanners_count() } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            local total = card.ability.extra.chips * nyanners_count()
            if total > 0 then return { chips = total } end
        end
    end,
}

--------------------------------------------------------------------------------
-- ObKatieKat [Rare] - paid for leaving no room.
--------------------------------------------------------------------------------
--
-- ^Chips, which only Talisman can score. Asked at score time rather than at
-- load for the reason Vienna gives: mods load in priority order, and Talisman
-- may not have run when this file does.

SMODS.Joker {
    key = "obkatiekat",
    atlas = "obkatiekat",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = false, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { e_chips = 1.2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.e_chips } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            local row = G.jokers
            if not (row and row.cards and row.config) then return end
            -- A Negative Joker raises card_limit with it, so "full" stays the
            -- honest question rather than a fixed five.
            if #row.cards < (row.config.card_limit or 0) then return end
            if not exponential_supported() then return end
            return { e_chips = card.ability.extra.e_chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- Trickywi [Common] - eats its neighbour on the way out of the shop.
--------------------------------------------------------------------------------
--
-- The one to its LEFT, so the choice is a placement: sliding Trickywi along the
-- row picks a different victim, and putting it leftmost feeds it nothing.
--
-- Paid before the meal, because sell_cost is read off the card and a card that
-- has been removed is not one to read anything off. SMODS.destroy_cards is what
-- does the removing: it respects eternal and undestroyable stickers and plays
-- the dissolve, so an eternal neighbour is refused rather than eaten - and the
-- payout is withheld with it, since nothing was destroyed.

SMODS.Joker {
    key = "trickywi",
    atlas = "trickywi",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    -- A copy would eat a second Joker, and the row this reads is position, not
    -- an effect worth repeating.
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { scale = 2 } },

    loc_vars = function(self, info_queue, card)
        return CelestasMod.with_true_star_line("j_celesta_trickywi",
            { vars = { card.ability.extra.scale } })
    end,

    calculate = function(self, card, context)
        -- True Stars in the deck are worth X Mult here; suits/true_stars.lua
        -- says what counts as one.
        if context.joker_main then
            local x_mult = CelestasMod.true_star_x_mult()
            if x_mult > 1 then return { x_mult = x_mult } end
        end

        if not (context.ending_shop and not context.blueprint) then return end

        local row = G.jokers and G.jokers.cards
        if not row then return end
        local index
        for i, joker in ipairs(row) do
            if joker == card then index = i break end
        end
        local target = index and row[index - 1]
        if not target or target == card then return end
        -- Asked before destroying, so an eternal neighbour costs nothing: the
        -- same question SMODS.destroy_cards is about to answer for itself.
        if SMODS.is_eternal(target) then return end

        local payout = (target.sell_cost or 0) * card.ability.extra.scale
        SMODS.destroy_cards(target)
        if payout <= 0 then return end

        -- Handed back as `dollars` rather than eased here and captioned by
        -- hand: SMODS pays it, juices the card, writes the +$n itself, and
        -- raises money_altered so anything watching the player's money sees
        -- this (utils.lua:1239). A bare ease_dollars is silent on that last
        -- one.
        return { dollars = payout, card = card }
    end,
}

--------------------------------------------------------------------------------
-- Grandpaw Shao [Uncommon] - every number is an Ace.
--------------------------------------------------------------------------------
--
-- Rank equivalence has one gate, and it is Card:get_id. evaluate_poker_hand
-- reads every card through it (misc_functions.lua:555 and :598), and so does
-- every Joker that asks what a card is, so widening it there covers pairs,
-- Five of a Kind, Baron, the lot from one place - the same shape Arielle uses
-- for suits through SMODS.smeared_check.
--
-- Number cards are 2 through 10. Faces and Aces are already what they are, and
-- a Stone Card answers with a large negative number rather than a rank, so the
-- range check leaves it alone without having to know about it.
--
-- What this does NOT change is what a card is worth: chips come from
-- base.nominal, so a Two still scores two. This makes hands, not Chips.

local SHAO_KEY = "j_celesta_shaoanvt"

local celesta_shao_get_id_ref = Card.get_id
function Card:get_id()
    local id = celesta_shao_get_id_ref(self)
    if type(id) == "number" and id >= 2 and id <= 10
        and CelestasMod.joker_in_play(SHAO_KEY) then
        return 14
    end
    return id
end

SMODS.Joker {
    key = "shaoanvt",
    atlas = "shaoanvt",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A passive the rank lookup reads, not a trigger; there is nothing to copy.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Yoclesh [Rare] - the wandering suits stop wandering.
--------------------------------------------------------------------------------
--
-- Some Jokers name a suit that MOVES: vanilla's Ancient Joker, Castle and The
-- Idol pick a new one every round, and this mod's Yomi Quinnely and Saiiren
-- walk a rotation. Yoclesh pins all of them to Hearts. Jokers that name a fixed
-- suit - Greedy Joker, Auteru - are not what this is about and are left alone.
--
-- Two levers, because the two families keep the answer in different places.
--
-- This mod's pair both read rotation_suit_at, so that function answers Hearts
-- and both are covered at once - description included.
--
-- Vanilla's three keep theirs on G.GAME.current_round.<x>_card.suit, rewritten
-- by a global reset_<x>_card() at the start of every round. Wrapping those
-- three is the whole of it: whatever they roll, the suit is put back to Hearts
-- afterwards. The Idol names a rank as well and keeps it - only the suit half
-- of it is a suit.

local YOCLESH_KEY = "j_celesta_yoclesh"

--- True while a Yoclesh is in the row and able to act.
--- Asked at the moment the answer is wanted rather than cached: it can be
--- bought, sold or debuffed between one round and the next.
function CelestasMod.yoclesh_active()
    return CelestasMod.joker_in_play(YOCLESH_KEY)
end

-- Which round-scoped table each vanilla reset writes its suit into.
local ROTATING_RESETS = {
    reset_ancient_card = "ancient_card",
    reset_castle_card = "castle_card",
    reset_idol_card = "idol_card",
}

--- Puts every wandering suit onto Hearts, if a Yoclesh is out.
--- Safe to call at any time: it only ever writes a field the game itself keeps
--- there, and does nothing at all when no Yoclesh is in play.
function CelestasMod.yoclesh_pin()
    if not CelestasMod.yoclesh_active() then return false end
    local round = G.GAME and G.GAME.current_round
    if not round then return false end
    local pinned = false
    for _, field in pairs(ROTATING_RESETS) do
        local target = round[field]
        if type(target) == "table" and target.suit ~= "Hearts" then
            target.suit = "Hearts"
            pinned = true
        end
    end
    return pinned
end

for name in pairs(ROTATING_RESETS) do
    local ref = _G[name]
    if type(ref) == "function" then
        _G[name] = function(...)
            local out = ref(...)
            CelestasMod.yoclesh_pin()
            return out
        end
    end
end

SMODS.Joker {
    key = "yoclesh",
    atlas = "yoclesh",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- A passive that other Jokers read, not a trigger; there is nothing to
    -- copy, and pinning a pinned suit twice is still Hearts.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    add_to_deck = function(self, card, from_debuff)
        -- Bought mid-run, the round's suits were rolled before it arrived; the
        -- wrappers above only catch the NEXT roll.
        CelestasMod.yoclesh_pin()
    end,

    calculate = function(self, card, context)
        -- ...and again as each blind is chosen, which covers a Yoclesh that
        -- was debuffed when the round began and is not any more.
        if context.setting_blind and not context.blueprint then
            CelestasMod.yoclesh_pin()
        end
    end,
}

--------------------------------------------------------------------------------
-- Vantacrow Bringer [Rare] - more of everything, for the price of a Common.
--------------------------------------------------------------------------------
--
-- All three numbers live in extra and are granted by DELTA from `update`,
-- against what this card is already holding - the way SmittenSeraph's slots
-- are, and for the same reason: nothing re-reads a number after it changes.
--
-- Hand size and discards used to be vanilla's own ability.h_size and d_size,
-- which Card:add_to_deck applies once. That made them unscalable twice over:
-- applied once, a raised number moved the text and nothing else, and Cryptid's
-- manipulate - which Yoka Siri hands the work to - refuses those two names
-- outright (Cryptid.misprintize_value_blacklist). Hands were in extra all
-- along, which is why Yoka reached the hands and not the other two.
-- `discards` and `hand_size` are names neither vanilla nor Cryptid treats
-- specially.
--
-- All three are moved into the round in progress AS WELL as into
-- round_resets. round_resets alone is only read at the start of a round
-- (state_events.lua:245), so hands used to be the one number of the three
-- that did not arrive with the card: the discards were eased in and the hand
-- size changed at once, while the hands the card leads with did not show up
-- until the round after. Anything that hands this Joker over mid-round - a
-- Buffoon pack, Riff-Raff, a Bind merge, a Lost Soul shop - made that gap
-- visible, and it reads exactly like the card not working.
--
-- ease_hands_played does not clamp (common_events.lua:165), which is the
-- reason it was left out before and is now handled rather than avoided:
-- giving hands is always safe, and taking them back is held at zero so a
-- round that has already spent them cannot be pushed below nothing and left
-- unable to end. Discards and hand size are moved the way vanilla moved them
-- for this card (card.lua:759-764).

local VANTACROW_GRANTED = "celesta_vantacrow_granted"

--- What the card promises right now, in whole hands, discards and cards.
--- Rounded, as Seraph's slots are: half a hand is not something a round holds.
local function vantacrow_wants(card)
    local ability = card.ability
    local extra = ability.extra
    return math.floor(extra.h_plays + 0.5),
           math.floor((extra.discards or ability.d_size or 0) + 0.5),
           math.floor((extra.hand_size or ability.h_size or 0) + 0.5)
end

--- A Vantacrow saved before the three moved into extra still carries
--- ability.h_size and d_size, and nothing recording what it holds.
---
--- Moved into extra and zeroed, so vanilla stops applying them. Card:add_to_deck
--- and remove_from_deck read those fields AFTER calling this centre's hooks
--- (card.lua:757-764 and :822-829), so zeroing them inside a hook is in time.
--- `applied` is whether the run currently holds this card's numbers: true in
--- the deck (update, and remove_from_deck, which runs before vanilla takes its
--- half back), false arriving (add_to_deck, before vanilla gives its half).
local function vantacrow_adopt(card, applied)
    local ability, extra = card.ability, card.ability.extra
    if extra.discards ~= nil and extra.hand_size ~= nil then return end
    extra.discards = extra.discards or ability.d_size or 0
    extra.hand_size = extra.hand_size or ability.h_size or 0
    ability.d_size, ability.h_size = 0, 0
    if applied and not ability[VANTACROW_GRANTED] then
        ability[VANTACROW_GRANTED] = {
            hands = extra.h_plays, discards = extra.discards, hand_size = extra.hand_size,
        }
    end
end

--- Brings the round in progress along with round_resets, never below zero.
--- Between rounds there is nothing to ease: new_round overwrites hands_left
--- from round_resets moments later, so this is only ever the in-round half.
local function vantacrow_ease_hands(hands)
    local round = G.GAME.current_round
    if not (round and type(round.hands_left) == "number") then return end
    if hands < 0 then hands = -math.min(-hands, round.hands_left) end
    if hands == 0 then return end
    if ease_hands_played then
        ease_hands_played(hands)
    else
        round.hands_left = round.hands_left + hands
    end
end

--- Moves the run by these amounts.
local function vantacrow_move(hands, discards, hand_size)
    if hands ~= 0 then
        G.GAME.round_resets.hands = G.GAME.round_resets.hands + hands
        vantacrow_ease_hands(hands)
    end
    if discards ~= 0 then
        G.GAME.round_resets.discards = G.GAME.round_resets.discards + discards
        ease_discard(discards)
    end
    if hand_size ~= 0 and G.hand then G.hand:change_size(hand_size) end
end

--- Brings the run in line with what this card currently promises.
local function vantacrow_sync(card, applied)
    if not (G.GAME and G.GAME.round_resets) then return end
    vantacrow_adopt(card, applied)
    local held = card.ability[VANTACROW_GRANTED] or { hands = 0, discards = 0, hand_size = 0 }
    local hands, discards, hand_size = vantacrow_wants(card)
    if held.hands == hands and held.discards == discards
        and held.hand_size == hand_size then
        return
    end
    vantacrow_move(hands - held.hands, discards - held.discards,
                   hand_size - held.hand_size)
    card.ability[VANTACROW_GRANTED] = { hands = hands, discards = discards, hand_size = hand_size }
end

--- ...and hands all of it back.
local function vantacrow_release(card)
    if not (G.GAME and G.GAME.round_resets) then return end
    vantacrow_adopt(card, true)
    local held = card.ability[VANTACROW_GRANTED]
    if not held then return end
    vantacrow_move(-held.hands, -held.discards, -held.hand_size)
    card.ability[VANTACROW_GRANTED] = nil
end

SMODS.Joker {
    key = "vantacrow_bringer",
    atlas = "vantacrow_bringer",
    pos = { x = 0, y = 0 },
    -- Rare, at a Common's price, as asked.
    rarity = 3, cost = 6,
    unlocked = false, discovered = false,
    -- A passive the run reads, not a trigger; there is nothing to copy.
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { h_plays = 2, discards = 2, hand_size = 2 } },

    loc_vars = function(self, info_queue, card)
        local hands, discards, hand_size = vantacrow_wants(card)
        return { vars = { hands, discards, hand_size } }
    end,

    add_to_deck = function(self, card, from_debuff)
        vantacrow_sync(card, false)
    end,

    remove_from_deck = function(self, card, from_debuff)
        vantacrow_release(card)
    end,

    -- Every frame, but it writes only when a number has actually moved. The
    -- added_to_deck gate keeps a copy in the shop or the collection from
    -- granting anything it does not own.
    update = function(self, card, front)
        if card.added_to_deck then vantacrow_sync(card, true) end
    end,
}

--------------------------------------------------------------------------------
-- RainyRentyn [Uncommon] - sometimes it rains.
--------------------------------------------------------------------------------
--
-- setting_blind, not end_of_round: it is the moment the Blind is chosen,
-- before any card is dealt, so the Downpour is up for the whole round rather
-- than arriving partway through it. The Arena clears itself on the way back to
-- Blind Select, so there is nothing to stop.

CelestasMod.RAINYRENTYN_ODDS = 4

SMODS.Joker {
    key = "rainyrentyn",
    atlas = "rainyrentyn",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(
            card, 1, CelestasMod.RAINYRENTYN_ODDS, "celesta_rainyrentyn")
        return { vars = { n, d } }
    end,

    calculate = function(self, card, context)
        if not (context.setting_blind and not context.blueprint) then return end
        -- Rolled only when there is something to start. A Downpour already up
        -- cannot be started twice, and rolling anyway would burn a pull from
        -- the stream for nothing.
        if CelestasMod.Arena.is_active("downpour") then return end
        if not SMODS.pseudorandom_probability(
                card, "celesta_rainyrentyn", 1,
                CelestasMod.RAINYRENTYN_ODDS) then
            return
        end

        CelestasMod.Arena.start("downpour")
        return {
            message = localize("celesta_downpour"),
            colour = G.C.BLUE,
            card = card,
        }
    end,
}

--------------------------------------------------------------------------------
-- SnapsCube [Common] - paid for playing exactly four.
--------------------------------------------------------------------------------
--
-- context.before is where full_hand exists, and it lands ahead of scoring, so
-- the hand that earns the Mult is also the hand that scores it - the same
-- ordering Deme relies on.
--
-- full_hand is every played card, not only the scoring ones: "exactly 4 cards"
-- is about what was played, not about what the poker hand happened to use.
--
-- Nothing resets it. This one only ever climbs.

SMODS.Joker {
    key = "snapscube",
    atlas = "snapscube",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { gain = 4, size = 4, mult = 0 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.gain, card.ability.extra.size,
                          card.ability.extra.mult } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            if #context.full_hand == card.ability.extra.size then
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "mult",
                    scalar_value = "gain",
                    no_message = true,
                })
                return {
                    message = localize { type = "variable", key = "a_mult",
                                         vars = { card.ability.extra.mult } },
                    colour = G.C.MULT, card = card,
                }
            end
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.mult, 0) then
            return { mult = card.ability.extra.mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Chrchie [Uncommon] - paid by the card, at the cash-out
--------------------------------------------------------------------------------
--
-- Nothing in the game counts the cards played in a round. current_round keeps
-- hands_played, and inc_career_stat('c_cards_played') is a lifetime total on
-- the profile - neither answers "this round". So the tally is kept on the card
-- and cleared as it is paid out.
--
-- Counted in context.before, which is the pass that carries full_hand and runs
-- once per hand ahead of scoring. full_hand is every played card, not only the
-- scoring ones: a card that was played is a card that was played.
--
-- Kept on ability.extra so it is saved with the run. A hand played, then the
-- game quit mid-round, is still owed at the cash-out.

SMODS.Joker {
    key = "chrchie",
    atlas = "chrchie",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { dollars = 1, cards = 0 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.dollars, card.ability.extra.cards } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint and context.full_hand then
            card.ability.extra.cards =
                card.ability.extra.cards + #context.full_hand
        end

        if context.end_of_round and context.main_eval and not context.blueprint then
            local owed = card.ability.extra.cards * card.ability.extra.dollars
            card.ability.extra.cards = 0
            if owed > 0 then
                return { dollars = owed, card = card }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Aethal [Uncommon] - a wider shop
--------------------------------------------------------------------------------
--
-- change_shop_size is vanilla's own (common_events.lua:1353), the function the
-- Overstock voucher goes through: it moves G.GAME.shop.joker_max and then
-- fills or trims the row to match.
--
-- Granted by DELTA from `update`, the way SmittenSeraph and Shiabun are, and
-- for both of their reasons. Nothing re-reads the number after it changes, so
-- applied once on arrival it would go stale the moment anything scaled it. And
-- change_shop_size RETURNS EARLY when there is no shop - a Joker bought from a
-- Buffoon pack mid-round arrives before one exists - so a single attempt can
-- simply be dropped. The sync retries every frame until it lands, and records
-- nothing until it has.

local AETHAL_GRANTED = "celesta_aethal_granted"

--- Brings the shop's width in line with what this card promises.
---
--- Not while a Bind pair has taken the card over. The merge takes the slots
--- back through remove_from_deck, but vanilla still sends `update` to the
--- host's centre, so without this a host Aethal granted them straight back.
local function aethal_sync(card)
    local bind = CelestasMod.Bind
    if bind and bind.replacing_special and bind.replacing_special(card) then return end
    if not (G.GAME and G.GAME.shop and change_shop_size) then return end
    local held = card.ability[AETHAL_GRANTED] or 0
    local want = card.ability.extra.slots
    if held == want then return end

    change_shop_size(want - held)
    card.ability[AETHAL_GRANTED] = want
end

--- ...and narrows it again.
local function aethal_release(card)
    local held = card.ability[AETHAL_GRANTED]
    if not held or held == 0 then
        card.ability[AETHAL_GRANTED] = nil
        return
    end
    if G.GAME and G.GAME.shop and change_shop_size then
        change_shop_size(-held)
    end
    card.ability[AETHAL_GRANTED] = nil
end

SMODS.Joker {
    key = "lordaethelstan",
    atlas = "lordaethelstan",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- The slots belong to this card, and it gives them back itself.
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { slots = 4 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.slots } }
    end,

    add_to_deck = function(self, card, from_debuff)
        aethal_sync(card)
    end,

    remove_from_deck = function(self, card, from_debuff)
        aethal_release(card)
    end,

    update = function(self, card, front)
        if card.added_to_deck then aethal_sync(card) end
    end,
}

--------------------------------------------------------------------------------
-- Jummy [Common] - Wild cards are worth something on their own
--------------------------------------------------------------------------------
--
-- has_enhancement rather than a raw centre compare, so a card made Wild by
-- anything - a Tarot, a quantum enhancement - counts the same as one dealt
-- that way. The Joker above Kirana reads Wild the same way.

SMODS.Joker {
    key = "jummy",
    atlas = "jummy",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 4,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { mult = 4 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_wild
        return { vars = { card.ability.extra.mult } }
    end,

    calculate = function(self, card, context)
        -- The scoring-card pass; an unscored played card arrives with
        -- cardarea == 'unscored' instead, and a debuffed one not at all.
        if context.individual and context.cardarea == G.play
            and SMODS.has_enhancement(context.other_card, "m_wild") then
            return {
                mult = card.ability.extra.mult,
                card = context.other_card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- MoopyBuns [Uncommon] - the shop pays it back
--------------------------------------------------------------------------------
--
-- context.buying_card is Steamodded's, raised once for each thing bought
-- (lovely/better_calc.toml:935) - a Joker, a consumable, a voucher, a pack.
--
-- `not context.blueprint` for the reason Red Card and Flash Card carry it: the
-- growth lives on this card's own ability, so a copier answering would bank it
-- onto the original a second time.

SMODS.Joker {
    key = "moopybuns",
    atlas = "moopybuns",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { gain = 0.1, x_chips = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.gain, card.ability.extra.x_chips } }
    end,

    calculate = function(self, card, context)
        if context.buying_card and not context.blueprint then
            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "x_chips",
                scalar_value = "gain",
                no_message = true,
            })
            return {
                message = localize { type = "variable", key = "a_xchips",
                                     vars = { card.ability.extra.x_chips } },
                colour = G.C.CHIPS, card = card,
            }
        end

        -- X1 is no multiplier at all; returning it would put a flourish over
        -- the Joker every hand for doing nothing.
        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_chips, 1) then
            return { x_chips = card.ability.extra.x_chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- Cupidyle [Common] - Hearts pay
--------------------------------------------------------------------------------
--
-- is_suit rather than a base.suit compare, which is what every suit question
-- in this mod goes through: it routes through SMODS.smeared_check, so a Wild
-- card counts as a Heart and so does everything Smeared Joker makes one.
--
-- Per scoring card, through context.individual, which is how every suit Joker
-- in the game works and is what makes a debuffed Heart pay nothing.

SMODS.Joker {
    key = "cupidyle",
    atlas = "cupidyle",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 4,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { dollars = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.dollars } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and context.other_card:is_suit("Hearts") then
            return {
                p_dollars = card.ability.extra.dollars,
                card = context.other_card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Blue, Green and Fuchsia Card - paid for the things you walk past
--------------------------------------------------------------------------------
--
-- Vanilla's Red Card is the shape all three follow: a Joker that grows on a
-- moment the player usually treats as a non-event. Red Card takes the skipped
-- Booster; these take the skipped Booster in Chips, the skipped Blind, and the
-- reroll.
--
-- All three contexts are Steamodded's, patched into the same if/elseif chain
-- Red Card and Flash Card sit in (card.lua:2709, :2737, :2751), so they arrive
-- exactly where vanilla's own do and need nothing else installed:
--
--     context.skipping_booster  a Booster Pack was skipped
--     context.skip_blind        a Blind was skipped for its tag
--     context.reroll_shop       the shop was rerolled
--
-- `not context.blueprint` on each, which is what vanilla puts on Red Card and
-- Flash Card. A copier answering these would bank the growth onto the ORIGINAL
-- a second time - the scaling lives on the card's own ability, and a copy has
-- no ability of its own to grow. Blueprint still copies what they score.
--
-- Nothing resets any of them. They only ever climb.

--------------------------------------------------------------------------------
-- Blue Card [Common] - +6 Chips per Booster Pack skipped
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "blue_card",
    atlas = "blue_card",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { gain = 6, chips = 0 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.gain, card.ability.extra.chips } }
    end,

    calculate = function(self, card, context)
        if context.skipping_booster and not context.blueprint then
            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "chips",
                scalar_value = "gain",
                no_message = true,
            })
            return {
                message = localize { type = "variable", key = "a_chips",
                                     vars = { card.ability.extra.chips } },
                colour = G.C.CHIPS, card = card,
            }
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.chips, 0) then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- Green Card [Uncommon] - X0.25 Chips per Blind skipped this RUN
--------------------------------------------------------------------------------
--
-- Counted, not accumulated. G.GAME.skips is the run's own tally of skipped
-- Blinds (button_callbacks.lua:2808), so a Green Card bought on Ante 5 is
-- worth every skip that came before it - which is what "during the entire
-- run" means, and what a number climbing on the card's own ability could
-- never give.
--
-- Vanilla does the same thing with Throwback (card.lua:4482), off the same
-- counter.
--
-- Nothing is stored, so there is nothing to reset, nothing to save and
-- nothing for a merge to carry: both halves of a bound pair read the one
-- number the run is keeping anyway.

--- The multiplier right now. Declared immediately above the Joker rather than
--- with the other helpers at the top of this file: several test harnesses
--- slice it from somewhere in the middle to the end, and a local declared
--- above the slice is a nil global inside it.
local function green_card_x_chips(card)
    local skips = (G.GAME and G.GAME.skips) or 0
    local gain = card.ability.extra.gain
    -- Vedal accelerates a Joker that scales, and this is one - it counts
    -- rather than banking, so it asks rather than being hooked. See
    -- CelestasMod.vedal_counted for why that needed a second door.
    --
    -- Guarded because several test harnesses slice this file from below
    -- Vedal, where the helper does not exist; a counted Joker with no Vedal
    -- to ask is worth exactly what it always was.
    if CelestasMod.vedal_counted then
        return 1 + CelestasMod.vedal_counted(card, gain, skips)
    end
    return 1 + gain * skips
end

SMODS.Joker {
    key = "green_card",
    atlas = "green_card",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { gain = 0.25 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.gain, green_card_x_chips(card) } }
    end,

    calculate = function(self, card, context)
        -- G.GAME.skips is raised before this context is (button_callbacks.lua
        -- :2808 and :2821), so the number announced already counts the skip
        -- that just happened. Nothing is written here - the message is the
        -- whole of it.
        if context.skip_blind and not context.blueprint then
            return {
                message = localize { type = "variable", key = "a_xchips",
                                     vars = { green_card_x_chips(card) } },
                colour = G.C.CHIPS, card = card,
            }
        end

        -- X1 is no multiplier at all, and returning it would put a "X1 Chips"
        -- flourish over the Joker every hand for doing nothing.
        --
        -- more_than rather than `>`: with Vedal out this is one of Talisman's
        -- numbers, and Lua 5.1 raises on comparing one of those to a number.
        if context.joker_main then
            local x_chips = green_card_x_chips(card)
            if CelestasMod.more_than(x_chips, 1) then
                return { x_chips = x_chips }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Fuchsia Card [Rare] - X0.2 Mult per shop reroll
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "fuchsia_card",
    atlas = "fuchsia_card",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { gain = 0.2, x_mult = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.gain, card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        if context.reroll_shop and not context.blueprint then
            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "x_mult",
                scalar_value = "gain",
                no_message = true,
            })
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { card.ability.extra.x_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- GlassesJournal [Uncommon] - Steel first, then Aces - and the deal order
-- generally, which the Gene Seal also has a claim on.
--------------------------------------------------------------------------------
--
-- ONE sort, not one per rule. The Gene Seal (seals/seals.lua) says its card is
-- always dealt first, and GlassesJournal says Steel is; two hooks on the same
-- function would each reorder G.deck.cards and whichever ran last would
-- silently win, which makes "always" untrue of whichever lost. So both are
-- ranks in the single pass below, and the precedence between them is written
-- down once, here, where it can be read.
--
-- Cards are dealt off the END of G.deck.cards. Vanilla draws without naming
-- one and CardArea:remove_card hands back _cards[#_cards] for a deck;
-- Steamodded replaces that loop with one that walks the deck backwards
-- (lovely/card_limit.toml). Both ends agree, so "dealt first" means "sorted
-- last" and the priority order goes into the array reversed: the rest, then
-- Aces, then Steel.
--
-- Reordered rather than drawn differently. Every route that puts a card in
-- hand - the opening deal, the draw after a hand, the three The Serpent
-- allows - goes through that one function, so moving the deck under it covers
-- all of them without touching how any of them draw.
--
-- STABLE within each group: cards keep the order the shuffle gave them, so
-- this decides which cards come first and nothing about which of the equals
-- does. And it runs per deal rather than once, because a card can become Steel
-- or stop being one between two of them.
--
-- Rank is asked through get_id, the way every rank question in this mod is, so
-- Grandpaw Shao - who makes every number card an Ace - hands this a much
-- larger set to prioritise. That is the same answer he gives everything else.

local GLASSES_KEY = "j_celesta_glassesjournal"

local function glasses_active()
    return CelestasMod.joker_in_play(GLASSES_KEY)
end

--- The deal-first rules of every Glassesjournal merge in play
--- (merge/bind.lua), gathered once per deal. A debuffed merge has none.
---
--- Two kinds, because two kinds were asked for. `deal_first` picks a category
--- out of the deck and puts it at the front - "Clubs are dealt first" - and is
--- a yes or a no. `deal_weight` ranks cards against EACH OTHER and hands back
--- a number, which is what "more frequently played cards first" needs and what
--- no yes/no can express.
local function glasses_pair_rules()
    local rules, weights = {}, {}
    local Bind = CelestasMod.Bind
    if not (Bind and Bind.special_of) then return rules, weights end
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        if not held.debuff then
            local def = Bind.special_of(held)
            if def and type(def.deal_first) == "function" then
                rules[#rules + 1] = def.deal_first
            end
            if def and type(def.deal_weight) == "function" then
                weights[#weights + 1] = def.deal_weight
            end
        end
    end
    return rules, weights
end

--- Orders one place by what the weight rules say.
---
--- Heaviest LAST, because the deal comes off the end of G.deck.cards - the
--- same reason the places themselves go into the array reversed. Ties keep the
--- order the shuffle gave them, which table.sort will not do on its own, so
--- the card's position in the bucket is the tie-break.
local function order_by_weight(bucket, weights)
    if #bucket < 2 then return end
    local score, at = {}, {}
    for i, card in ipairs(bucket) do
        at[card] = i
        local total = 0
        for _, rule in ipairs(weights) do
            local ok, n = pcall(rule, card)
            if ok and type(n) == "number" then total = total + n end
        end
        score[card] = total
    end
    table.sort(bucket, function(a, b)
        if score[a] ~= score[b] then return score[a] < score[b] end
        return at[a] < at[b]
    end)
end

--- Where a card goes in the deal, low to high; the highest is dealt first.
---
--- 3 is the Gene Seal's and outranks the Joker's two, because the seal is put
--- on one named card by spending a Tarot on it and the Joker is a standing
--- rule over a whole category. A player who paid to move one card to the front
--- should see it there.
---
--- seals/seals.lua loads after this file, so the key is read here at call time
--- rather than captured at load - it does not exist yet when this runs.
---
--- A Glassesjournal merge's cards share Steel's place: both are a standing rule
--- over a category, and within one place the shuffle's order stands.
local function deal_rank(card, glasses, rules)
    local gene = CelestasMod.SEAL_KEYS and CelestasMod.SEAL_KEYS.Gene
    if gene and card.seal == gene then return 3 end
    if glasses and SMODS.has_enhancement(card, "m_steel") then return 2 end
    for _, rule in ipairs(rules or {}) do
        if rule(card) then return 2 end
    end
    if glasses and card.get_id and card:get_id() == 14 then return 1 end
    return 0
end

local function deal_reorder()
    local deck = G.deck and G.deck.cards
    if not deck or #deck < 2 then return end

    local glasses = glasses_active()
    local rules, weights = glasses_pair_rules()
    -- One bucket per rank, filled in deck order, so the sort is stable within
    -- a rank without needing a comparator that can tie.
    local buckets = { [0] = {}, {}, {}, {} }
    local ranked = false
    for _, card in ipairs(deck) do
        local rank = deal_rank(card, glasses, rules)
        if rank > 0 then ranked = true end
        local bucket = buckets[rank]
        bucket[#bucket + 1] = card
    end
    -- Nothing has a claim: leave the shuffle exactly as it was found.
    if not ranked and #weights == 0 then return end

    local i = 0
    for rank = 0, 3 do
        if #weights > 0 then order_by_weight(buckets[rank], weights) end
        for _, card in ipairs(buckets[rank]) do
            i = i + 1
            deck[i] = card
        end
    end
end

-- G.FUNCS is built when state_events.lua loads at boot, long before any mod,
-- so this is always here in the game. Read defensively anyway: wrapping a nil
-- would swap a Joker that does nothing for a mod that will not load at all.
local celesta_glasses_draw_ref = G.FUNCS and G.FUNCS.draw_from_deck_to_hand
if type(celesta_glasses_draw_ref) == "function" then
    G.FUNCS.draw_from_deck_to_hand = function(...)
        -- Guarded so a fault in the sort cannot stop the deal. A hand that
        -- comes out in the wrong order is a disappointment; a hand that never
        -- comes out is the end of the run.
        local ok, err = pcall(deal_reorder)
        if not ok then
            CelestasMod.warn_once("deal_reorder",
                "could not reorder the deck for the deal: " .. tostring(err))
        end
        return celesta_glasses_draw_ref(...)
    end
end
-- No `else`, and no warning in one: the branch is unreachable in the game, and
-- the only callers that can take it are the test harnesses, which slice this
-- file to its end and build a G of their own. A warn_once at load time would
-- be a line of unreachable noise that any of them could trip over.

SMODS.Joker {
    key = "glassesjournal",
    atlas = "glassesjournal",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A passive the deal reads, not a trigger; there is nothing to copy.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_steel
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Giwi [Rare] - Queens are worth holding.
--------------------------------------------------------------------------------
--
-- `not context.end_of_round` is the guard every held-in-hand Joker in this mod
-- carries. Vanilla reaches its held-in-hand block through an if/elseif chain
-- whose end_of_round branch comes first, so Baron and Raised Fist are
-- structurally barred from firing at the cash-out; a modded Joker gets no such
-- guard, and SMODS raises individual over G.hand again there for the Gold
-- cards paying out.
--
-- x_chips rather than an h_ key: SMODS's effect keys for a multiplier are
-- x_chips and x_mult, and neither has a held-in-hand spelling
-- (utils.lua:1444). What makes this held in hand is the pass it answers.

SMODS.Joker {
    key = "giwi",
    atlas = "giwi",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_chips = 1.5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_chips } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.hand
            and not context.end_of_round then
            local held = context.other_card
            if held and not held.debuff
                and held.get_id and held:get_id() == 12 then
                return { x_chips = card.ability.extra.x_chips, card = held }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Eidolon Wyrm [Rare] - room for three more cards, and a reason to use them.
--------------------------------------------------------------------------------
--
-- The two halves answer each other: +3 selection takes a hand to eight cards,
-- and the multiplier only starts once more than five of them SCORE. Nothing
-- here pays until the extra room is actually used, and used on cards the poker
-- hand takes.
--
-- The limit goes through the same pair of helpers Shiabun uses - see the
-- comment above them for why it is granted by delta from `update` rather than
-- applied once on arrival, and why both the play and the discard limit move.
--
-- `needed` rather than `threshold` because that is the name this mod gives a
-- "how many cards before it counts" field, and Yoka Siri's leave-alone list
-- knows it: scaling the requirement UP would make the Joker worse, which is
-- not what an upgrade means.

SMODS.Joker {
    key = "eidolonwyrm",
    atlas = "eidolonwyrm",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- Half of it is a passive nothing can copy, and a copy of the other half
    -- would read as the whole Joker being copied.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { limit = 3, x_mult_gain = 1, needed = 5 } },

    loc_vars = function(self, info_queue, card)
        -- Its own value, not the shared one: the Wyrm's line is per card in
        -- the played hand, so there is no full-deck total to show.
        return CelestasMod.with_true_star_line("j_celesta_eidolonwyrm",
            { vars = { card.ability.extra.limit,
                       card.ability.extra.x_mult_gain,
                       card.ability.extra.needed } },
            CelestasMod.TRUE_STAR_WYRM_X)
    end,

    add_to_deck = function(self, card, from_debuff)
        selection_sync(card)
        if not from_debuff then
            CelestasMod.play_join_sound("j_celesta_eidolonwyrm")
        end
    end,

    remove_from_deck = function(self, card, from_debuff)
        selection_release(card)
    end,

    update = function(self, card, front)
        if card.added_to_deck then selection_sync(card) end
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            -- Cards SCORED, not cards played: an eight-card hand that scores
            -- two is worth nothing here, and eight scored cards - a Flush
            -- with three extra cards along for the ride does not manage it -
            -- is what the multiplier is for.
            --
            -- scoring_hand is carried on this context by the scoring pass
            -- itself (state_events.lua:667), so there is nothing to fall back
            -- to: an empty one means no hand scored.
            local hand = context.scoring_hand or {}
            local above = #hand - card.ability.extra.needed

            -- Counted from X1 rather than from nothing: the first card over
            -- the line is worth a whole X1 on top, so six cards is X2 and
            -- eight is X4. Multiplying the rate by the count alone would make
            -- six cards X1, which is the do-nothing multiplier.
            local x_mult = above > 0
                and (1 + card.ability.extra.x_mult_gain * above) or 1

            -- True Stars in the PLAYED hand, multiplied on rather than added,
            -- so two of them are X2.25. Over full_hand, because the line says
            -- the played hand - this is not the scored-card rule above, which
            -- is deliberately about what scored.
            for _, played in ipairs(context.full_hand or hand) do
                if CelestasMod.is_true_star(played) then
                    x_mult = x_mult * CelestasMod.TRUE_STAR_WYRM_X
                end
            end

            if x_mult == 1 then return end
            return { x_mult = x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Astrum Aureus [Uncommon] - paid by the five-card hand, card by card.
--------------------------------------------------------------------------------
--
-- context.individual with cardarea == G.play is the scoring pass over each card
-- that the poker hand actually uses, and it is raised again for every retrigger
-- - which is what "each time those cards are scored" says. A Sock and Buskin
-- doubling the hand doubles what this collects.
--
-- The size is read off context.full_hand, the cards that were PLAYED, not off
-- the scoring hand. A five-card High Card is five cards played and one card
-- scored; it is still a five-card hand, and it pays for the one card that
-- scores rather than for five.

SMODS.Joker {
    key = "astrum_aureus",
    atlas = "astrum_aureus",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 1, gain = 0.05, size = 5 } },

    -- Written out rather than through the `announces` helper at the top of
    -- this file: several test harnesses slice it from the middle to the end,
    -- and a helper declared above the slice is a nil global inside it. Every
    -- Joker added to the tail of this file carries its own.
    add_to_deck = function(self, card, from_debuff)
        if not from_debuff then
            CelestasMod.play_join_sound("j_celesta_astrum_aureus")
        end
    end,

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.size, card.ability.extra.gain,
                          card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and not context.blueprint then
            local hand = context.full_hand or (G.play and G.play.cards) or {}
            if #hand ~= card.ability.extra.size then return end

            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "x_mult",
                scalar_value = "gain",
                no_message = true,
            })
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { card.ability.extra.x_mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Alluux [Common] - the first Leaf card of a hand is worth X2.5 Chips.
--------------------------------------------------------------------------------
--
-- "First" is asked of the scoring hand rather than remembered as the pass goes
-- along. context.individual runs once per scoring card, and again for every
-- retrigger of one, so a counter would make a retriggered first card the
-- second - and a Joker that retriggers the hand would move the bonus onto a
-- different card. Read off context.scoring_hand it is a question about the
-- hand, and every pass over the same card answers it the same way.

SMODS.Joker {
    key = "alluux",
    atlas = "alluux",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_chips = 2.5 } },

    loc_vars = function(self, info_queue, card)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR, true)
        return { vars = { card.ability.extra.x_chips, name, colours = { colour } } }
    end,

    calculate = function(self, card, context)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        if not other then return end

        local first = nil
        for _, scored in ipairs(context.scoring_hand or {}) do
            if scored.is_suit and scored:is_suit(CelestasMod.LEAF_SUIT) then
                first = scored
                break
            end
        end
        if not first or first ~= other then return end

        return { x_chips = card.ability.extra.x_chips, card = card }
    end,
}

--------------------------------------------------------------------------------
-- Grimmi [Uncommon] - the Joker sold before it comes back Negative.
--------------------------------------------------------------------------------
--
-- "The Joker sold before this one" is a fact about the RUN, not about what
-- Grimmi happened to witness. The first version kept the name on Grimmi's own
-- ability, written from context.selling_card - and that only hears the sales
-- made while Grimmi is already in the row, so selling a Joker and then buying
-- Grimmi left it with nothing to bring back. It also heard its OWN sale and
-- wrote itself down, because vanilla broadcasts selling_card to the row after
-- the sale rather than before it.
--
-- So the name is kept on G.GAME, written where every sale of every card goes
-- through, and recorded AFTER the sale has been evaluated. That order is the
-- whole of it: Card:sell_card raises selling_self from inside itself
-- (card.lua:1842), so a Grimmi being sold reads the Joker before it and is
-- only then written down as the latest sale itself.

-- Guarded the way the shop hook in jokers/lost.lua is: there is always a
-- Card:sell_card in the game, and there is not always one in a harness that
-- has sliced this file open to read a single Joker.
--- How many Rare Jokers have been sold this run. Written by the sale hook
--- below; read by Silvervale and its merges.
function CelestasMod.rares_sold()
    return (G.GAME and G.GAME.celesta_rares_sold) or 0
end

--- Notes a Common from this mod on the run's list, if it is not on it already.
---
--- CDawg retains one of each, however many copies were sold: two Fufus are one
--- Fufu's worth of ability, and the orbit would show the same face twice with
--- nothing to tell them apart. jokers/cdawg.lua reads the list back.
--- Named for what it records and not for what CDawg does with it: Commons are
--- all a plain CDawg retains, but its merges widen that and a sale made before
--- the merge counts the same as one made after. So every rarity a merge could
--- ever reach is written down, and jokers/cdawg.lua decides what is retained.
---
--- Listed rather than bounded, because `rarity` is not always a number - this
--- mod's own Lost Jokers carry a rarity of their own, and another mod's could
--- be anything at all. Legendary is deliberately absent: no merge reaches it.
local RETAINABLE_RARITY = { [1] = true, [2] = true, [3] = true }

local function record_joker_sold(center)
    if not (G.GAME and center and RETAINABLE_RARITY[center.rarity]
        and CelestasMod.is_ours(center) and center.key) then
        return
    end
    -- One list, and it means "what CDawg retains" - so a Joker it will never
    -- retain is not counted by the orbit, the tally on the card, or CDawg +
    -- Ironmouse either.
    if center.celesta_cdawg_never then return end
    local sold = G.GAME.celesta_commons_sold or {}
    G.GAME.celesta_commons_sold = sold
    for _, key in ipairs(sold) do
        if key == center.key then return end
    end
    sold[#sold + 1] = center.key
end

local celesta_grimmi_sell_ref = Card and Card.sell_card
if celesta_grimmi_sell_ref then
    function Card:sell_card(...)
        local ret = celesta_grimmi_sell_ref(self, ...)

        if G.GAME and self.ability and self.ability.set == "Joker" then
            local config = self.config or {}
            G.GAME.celesta_last_joker_sold = config.center_key
                or (config.center and config.center.key)
            -- Silvervale's count, kept here for the same reason as the name:
            -- it is every Rare sold this RUN, including the ones sold before
            -- a Silvervale was there to hear it.
            if config.center and config.center.rarity == 3 then
                G.GAME.celesta_rares_sold = (G.GAME.celesta_rares_sold or 0) + 1
            end
            record_joker_sold(config.center)
        end

        return ret
    end
end

SMODS.Joker {
    key = "grimmi",
    atlas = "grimmi",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- Nothing to copy: what it does happens as it leaves the row.
    blueprint_compat = true, eternal_compat = false,

    loc_vars = function(self, info_queue, card)
        return { vars = {} }
    end,

    calculate = function(self, card, context)
        if not (context.selling_self and not context.blueprint) then return end

        local key = G.GAME and G.GAME.celesta_last_joker_sold
        -- TEMPORARY trace, until this is seen working in a run.
        sendInfoMessage("[grimmi] sold, last joker sold=" .. tostring(key)
            .. " known=" .. tostring(key ~= nil and G.P_CENTERS[key] ~= nil),
            "CelestasMod")
        if not (key and G.P_CENTERS[key]) then return end

        -- Negative, so there is no room to check: it brings its own slot. Made
        -- from an event because the sale is one too, and this has to land
        -- behind it.
        G.E_MANAGER:add_event(Event {
            func = function()
                local made = SMODS.add_card { key = key }
                if made then
                    made:set_edition({ negative = true }, true)
                    made:juice_up(0.3, 0.5)
                end
                return true
            end
        })
        return { message = localize("k_plus_joker"), colour = G.C.DARK_EDITION,
                 card = card }
    end,
}

--------------------------------------------------------------------------------
-- Mellow Mabel [Common] - Stars and Leaves are one suit.
--------------------------------------------------------------------------------
--
-- Through SMODS.smeared_check, which is the one place the game asks whether
-- two suits are to count as one: it is how vanilla's Smeared Joker merges
-- Hearts with Diamonds, and widening it covers flushes, suit-gated Jokers and
-- suit-gated enhancements together rather than one at a time. Arielle sits on
-- the same hook and answers yes to everything; this answers yes to one pair.

local celesta_mabel_smeared_ref = SMODS.smeared_check
function SMODS.smeared_check(card, suit, ...)
    if CelestasMod.joker_in_play("j_celesta_mellowmabel") then
        local own = card and card.base and card.base.suit
        local pair = { [CelestasMod.STARS_SUIT] = true, [CelestasMod.LEAF_SUIT] = true }
        if pair[own] and pair[suit] then return true end
    end
    return celesta_mabel_smeared_ref(card, suit, ...)
end

SMODS.Joker {
    key = "mellowmabel",
    atlas = "mellowmabel",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = false, discovered = false,
    -- The suits are rewritten for as long as it is in the row; there is no
    -- effect returned for a copy to return.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        local stars, star_colour = CelestasMod.suit_name_and_colour(
            CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR)
        local leaves, leaf_colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR)
        return { vars = { stars, leaves, colours = { star_colour, leaf_colour } } }
    end,
}

--------------------------------------------------------------------------------
-- Squchan [Rare] - sold, it leaves the row full of Holographic Jokers.
--------------------------------------------------------------------------------
--
-- A round has to pass first, counted at the end of each one: bought and sold
-- inside the same shop it gives nothing, which is what stops a shop with money
-- in it being turned straight into a row of Holographics.
--
-- The fill is bounded. "Every empty slot" is the ask, and in an ordinary run
-- that is a handful - but this mod can put the Joker limit into the millions
-- (Smitten Seraph under a grown Vedal), and a loop that filled THAT would
-- allocate until the game died. It is the same shape as the retrigger count
-- Vedal was capped for. So the ceiling below is a bound on the loop, not a
-- rule about the Joker: past it there was never room on screen anyway.

local SQUCHAN_MAX_FILL = 25

SMODS.Joker {
    key = "squchan",
    atlas = "squchan",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- What it does happens as it leaves the row, which a copy cannot do.
    blueprint_compat = true, eternal_compat = false,

    config = { extra = { rounds = 0, needed = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.needed, card.ability.extra.rounds } }
    end,

    calculate = function(self, card, context)
        -- main_eval is the once-a-round pass; without it this counts once per
        -- card the end of the round looks at.
        if context.end_of_round and context.main_eval and not context.blueprint then
            card.ability.extra.rounds = card.ability.extra.rounds + 1
            return
        end

        if not (context.selling_self and not context.blueprint) then return end
        if card.ability.extra.rounds < card.ability.extra.needed then return end
        if not (G.jokers and G.jokers.config) then return end

        -- The slot Squchan is vacating counts: it is still in the row as this
        -- runs, and gone by the time the events below fill anything.
        local limit = G.jokers.config.card_limit or 0
        local free = limit - (#G.jokers.cards - 1) - (G.GAME.joker_buffer or 0)
        free = math.min(free, SQUCHAN_MAX_FILL)
        if free <= 0 then return end

        for _ = 1, free do
            G.GAME.joker_buffer = (G.GAME.joker_buffer or 0) + 1
            G.E_MANAGER:add_event(Event {
                trigger = "before", delay = 0.0,
                func = function()
                    local made = SMODS.add_card { set = "Joker" }
                    if made then
                        made:set_edition({ holo = true }, true)
                        made:start_materialize()
                    end
                    G.GAME.joker_buffer =
                        math.max(0, (G.GAME.joker_buffer or 1) - 1)
                    return true
                end
            })
        end

        return { message = localize("k_plus_joker"), colour = G.C.SECONDARY_SET.Joker,
                 card = card }
    end,
}

--------------------------------------------------------------------------------
-- Suko [Rare] - leaving the shop, a Foil Joker.
--------------------------------------------------------------------------------
--
-- context.ending_shop is raised as "Next Round" leaves the shop. Room is asked
-- the way every vanilla Joker-maker asks it, buffer included, and the slot is
-- reserved across the event that fills it - Riff-Raff's shape - so two things
-- making a Joker in the same moment cannot both take the last slot.

SMODS.Joker {
    key = "suko",
    atlas = "suko",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.e_foil
        return {}
    end,

    calculate = function(self, card, context)
        if not context.ending_shop then return end
        if not (G.jokers and G.jokers.config) then return end
        if #G.jokers.cards + (G.GAME.joker_buffer or 0) >= G.jokers.config.card_limit then
            return
        end

        G.GAME.joker_buffer = (G.GAME.joker_buffer or 0) + 1
        G.E_MANAGER:add_event(Event {
            trigger = "before", delay = 0.0,
            func = function()
                local made = SMODS.add_card { set = "Joker", key_append = "celesta_suko" }
                if made then made:set_edition({ foil = true }, true) end
                G.GAME.joker_buffer = math.max(0, (G.GAME.joker_buffer or 1) - 1)
                return true
            end,
        })
        return { message = localize("k_plus_joker"), colour = G.C.SECONDARY_SET.Joker,
                 card = card }
    end,
}

--------------------------------------------------------------------------------
-- Pheromoan [Uncommon] - the cards along for the ride take the first scorer's
-- enhancement.
--------------------------------------------------------------------------------
--
-- context.before, FeFe's moment: after the poker hand is named and before
-- anything scores. The first scoring card is scoring_hand[1], which keeps the
-- order the cards were played in. A first card with no enhancement has none to
-- hand on, so nothing changes. Played cards are converted under unjudged, for
-- the reason FeFe gives.

SMODS.Joker {
    key = "pheromoan",
    atlas = "pheromoan",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A copy has nothing left to convert.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        if not (context.before and not context.blueprint) then return end
        local scoring = context.scoring_hand or {}
        local first = scoring[1]
        local center = first and first.config and first.config.center
        if not center or center == G.P_CENTERS.c_base then return end

        local scored = {}
        for _, scorer in ipairs(scoring) do scored[scorer] = true end

        local converted = 0
        for _, played in ipairs(context.full_hand or {}) do
            if not scored[played] and played.config.center ~= center then
                CelestasMod.unjudged(played, function()
                    played:set_ability(center, nil, true)
                end)
                converted = converted + 1
                local target = played
                G.E_MANAGER:add_event(Event {
                    func = function() target:juice_up() return true end
                })
            end
        end

        if converted > 0 then
            return { message = localize("celesta_plus_enhancement"),
                     colour = G.C.SECONDARY_SET.Enhanced, card = card }
        end
    end,
}

--------------------------------------------------------------------------------
-- FireOniRei [Rare] - a card fewer in hand, and every sticker burnt off after
-- a Boss.
--------------------------------------------------------------------------------
--
-- The hand size is vanilla's own ability.h_size, Juggler's field: applied by
-- Card:add_to_deck and given back by remove_from_deck (card.lua:759 and :824),
-- and applied for an absorbed half by Bind's intrinsic_passive. A penalty has
-- no business scaling, and h_size is the one name Cryptid's manipulate and
-- Yoka Siri both leave alone - which is why Vantacrow had to move OFF it.
--
-- "Defeated" is end_of_round on a Boss without game_over. game_over is decided
-- before any Joker runs and a Mr. Bones save only clears it after the pass
-- (state_events.lua:108-109), so a round survived that way strips nothing.
--
-- Every sticker SMODS knows of comes off through its own apply, the way
-- Card:remove_sticker does it, so a modded sticker that granted something
-- takes it back. Pinned keeps its flag on the card rather than the ability,
-- so both are looked at. A merged Joker also holds its absorbed half's own
-- copy under celesta_bind, and unmerging hands that copy back
-- (merge/bind.lua:3689), so that copy goes too.

--- Strips every sticker off `joker`. True if it was wearing any.
local function fireonirei_strip(joker)
    if not (joker and joker.ability) then return false end
    local stripped = false

    for key, sticker in pairs(SMODS.Stickers or {}) do
        if joker.ability[key] or joker[key] then
            sticker:apply(joker, false)
            joker.ability[key] = nil
            joker[key] = nil
            stripped = true
        end
    end

    local bound = joker.ability.celesta_bind
    local half = type(bound) == "table" and bound.ability
    if type(half) == "table" then
        for key in pairs(SMODS.Stickers or {}) do
            if half[key] then
                half[key] = nil
                stripped = true
            end
        end
        if not half.perishable then half.perish_tally = nil end
    end

    -- Perishable keeps a countdown beside its flag; left behind it would
    -- debuff the Joker on its own later.
    if not joker.ability.perishable then joker.ability.perish_tally = nil end
    return stripped
end

SMODS.Joker {
    key = "fireonirei",
    atlas = "fireonirei",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- The stickers are gone after the first pass; a copy has nothing to add.
    blueprint_compat = false, eternal_compat = true,

    config = { h_size = -1 },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.h_size } }
    end,

    calculate = function(self, card, context)
        -- main_eval is the once-per-round Joker pass.
        if not (context.end_of_round and context.main_eval) then return end
        if context.blueprint or context.game_over then return end
        local blind = G.GAME and G.GAME.blind
        if not (blind and blind.boss) then return end

        -- In an event, not here and now. Merged as the absorbed half, this runs
        -- while Bind has lent the card the half's ability table, so its own
        -- card's stickers - on the host's table - would be out of reach.
        G.E_MANAGER:add_event(Event {
            func = function()
                for _, joker in ipairs(G.jokers and G.jokers.cards or {}) do
                    if fireonirei_strip(joker) then joker:juice_up(0.3, 0.4) end
                end
                return true
            end,
        })
    end,
}


--------------------------------------------------------------------------------
-- Ellie Minibot [Legendary] - nothing this mod rolls for can miss.
--------------------------------------------------------------------------------
--
-- Answered at SMODS.get_probability_vars, which is the one funnel both halves
-- of a chance go through: pseudorandom_probability rolls with what it returns
-- and every loc_vars prints it, so "1 in 6" reads, and rolls, as "6 in 6" from
-- one place. After the reference, so it lands after every additive change -
-- Nagzz, Oops! All 6s - and nothing afterwards can undo it.
--
-- NOT from Ellie's own calculate, which is where this used to be, because a
-- calculate is something Ellie has to be ASKED for and there are two moments
-- when it cannot be. A chance belonging to the half Ellie is MERGED with is
-- rolled from inside that half's own calculate, and printed inside the lend
-- that builds that half's description - and through both of those the card is
-- the other half and is not Ellie at all. The pass walked the row, reached the
-- card, and got the other half's answer twice; a merged Shoto went on reading
-- and rolling 1 in 4 with Ellie sitting on the same card.
--
-- What the card says is a statement about the ROW, and joker_in_play is what
-- answers that - counting either half of a merge, refusing a debuffed card,
-- and refusing a replacing pair, which speaks for both halves and is not Ellie
-- any more than it is the other one.
--
-- "This mod's Jokers" is the Joker a chance is rolled FOR, trigger_obj, which
-- covers a merged card whichever half is this mod's. The Clover's roll names
-- the card it is deciding about rather than the blind, so it is known by its
-- identifier instead - and guaranteeing it means every card gets to trigger.

do

local ELLIE_KEY = "j_celesta_ellie_minibot"
local ELLIE_CLOVER = "celesta_clover"

--- True when a chance belongs to one of this mod's Jokers, or to The Clover.
local function ellie_covers(trigger_obj, identifier)
    if identifier == ELLIE_CLOVER then return true end
    local ability = type(trigger_obj) == "table" and trigger_obj.ability
    if not (type(ability) == "table" and ability.set == "Joker") then return false end
    local center = trigger_obj.config and trigger_obj.config.center
    if center and CelestasMod.is_ours(center) then return true end
    local bound = ability.celesta_bind
    local partner = type(bound) == "table" and type(bound.key) == "string"
        and G.P_CENTERS[bound.key]
    return partner and CelestasMod.is_ours(partner) or false
end

local celesta_ellie_probability_ref = SMODS.get_probability_vars
function SMODS.get_probability_vars(trigger_obj, base_numerator, base_denominator,
                                    identifier, from_roll, no_mod, ...)
    local numerator, denominator = celesta_ellie_probability_ref(
        trigger_obj, base_numerator, base_denominator, identifier, from_roll,
        no_mod, ...)

    -- no_mod is the caller saying nothing may touch this one, and the
    -- reference has already returned the numbers untouched.
    if no_mod then return numerator, denominator end
    -- Cheapest test first: almost every chance in a run is not one of these,
    -- and only the ones that are are worth walking the row for.
    if not ellie_covers(trigger_obj, identifier) then return numerator, denominator end
    if not CelestasMod.joker_in_play(ELLIE_KEY) then return numerator, denominator end
    -- Only a number, or a Talisman big number. The denominator is whatever the
    -- roller passed, and Cryptid's RNJoker passes a sentence.
    if type(denominator) ~= "number"
        and not (type(denominator) == "table" and getmetatable(denominator)) then
        return numerator, denominator
    end

    return denominator, denominator
end

SMODS.Joker {
    key = "ellie_minibot",
    atlas = "ellie_minibot",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    -- A guarantee is already everything; a copy has nothing to add.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

end


--------------------------------------------------------------------------------
-- Froot [Rare] - the more Wild the deck, the harder it hits.
--------------------------------------------------------------------------------
--
-- Fufu's shape, counting a different thing: read off the full deck every time
-- it is asked, so a card made Wild or taken out of the deck counts from the
-- next hand without anything to keep in step. has_enhancement rather than a
-- centre compare, so a card Wild by any route counts, the way Jummy's does.

--- Wild Cards in the full deck.
local function froot_wilds()
    local count = 0
    for _, held in ipairs(G.playing_cards or {}) do
        if SMODS.has_enhancement(held, "m_wild") then count = count + 1 end
    end
    return count
end

SMODS.Joker {
    key = "froot",
    atlas = "froot",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult_gain = 0.4 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_wild
        local gain = card.ability.extra.x_mult_gain
        return { vars = { gain, 1 + gain * froot_wilds() } }
    end,

    calculate = function(self, card, context)
        if not context.joker_main then return end
        local x_mult = 1 + card.ability.extra.x_mult_gain * froot_wilds()
        if x_mult > 1 then return { x_mult = x_mult } end
    end,
}

--------------------------------------------------------------------------------
-- Momo [Uncommon] - every hand is a Flush.
--------------------------------------------------------------------------------
--
-- Answered where the game asks: get_flush, which Steamodded's _flush hand part
-- calls for every evaluation (game_object.lua:2791). With a Momo in play every
-- played card is the flush, whatever its suit and however few there are, so
-- the hands built on a flush follow on their own - a Straight is a Straight
-- Flush, a Full House a Flush House - and every card of it scores, because
-- the flush is part of the hand.
--
-- joker_in_play, so a Momo merged into another Joker still counts. Guarded the
-- way the sale hook above is: a harness that slices this file has no get_flush.

-- Written out, as the other Jokers at the tail of this file do: harnesses
-- slice from the middle to the end, where SMODS.current_mod is not set.
local MOMO_KEY = "j_celesta_momo"

local celesta_momo_flush_ref = get_flush
if celesta_momo_flush_ref then
    function get_flush(hand)
        if type(hand) == "table" and #hand > 0
            and CelestasMod.joker_in_play and CelestasMod.joker_in_play(MOMO_KEY) then
            local every = {}
            for i, played in ipairs(hand) do every[i] = played end
            return { every }
        end
        return celesta_momo_flush_ref(hand)
    end
end

SMODS.Joker {
    key = "momo",
    atlas = "momo",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A passive the hand evaluation reads; there is nothing to copy.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Silvervale [Legendary] - every Rare sold this run is X1 Mult.
--------------------------------------------------------------------------------
--
-- The count is the run's, kept by the sale hook above, so Rares sold before
-- Silvervale arrived count too, and nothing on the card has to be kept.

--- What the sales are worth, Vedal included.
---
--- Green Card's shape: a value counted off a tally that only goes up is a
--- scaling Joker that never comes through SMODS.scale_card, so it asks rather
--- than being hooked. See CelestasMod.vedal_counted.
local function silvervale_total(card, gain)
    if CelestasMod.vedal_counted then
        return CelestasMod.vedal_counted(card, gain, CelestasMod.rares_sold())
    end
    return gain * CelestasMod.rares_sold()
end

SMODS.Joker {
    key = "silvervale",
    atlas = "silvervale",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult_gain = 1 } },

    loc_vars = function(self, info_queue, card)
        local gain = card.ability.extra.x_mult_gain
        return { vars = { gain, 1 + silvervale_total(card, gain) } }
    end,

    calculate = function(self, card, context)
        if not context.joker_main then return end
        local x_mult = 1 + silvervale_total(card, card.ability.extra.x_mult_gain)
        -- more_than, for the reason Green Card gives: with Vedal out this is
        -- one of Talisman's numbers.
        if CelestasMod.more_than(x_mult, 1) then return { x_mult = x_mult } end
    end,
}

--------------------------------------------------------------------------------
-- LucyPyre [Uncommon] - every Blind asks for a tenth less.
--------------------------------------------------------------------------------
--
-- Hooked on get_blind_amount for the reason items/challenges.lua gives for the
-- Printer's quota: it is the one function BOTH places asking for a quota go
-- through - the Blind itself and the panel on the Blind select screen - so the
-- number offered and the number required cannot disagree. Writing
-- G.GAME.blind.chips at setting_blind instead would quietly lower a number the
-- player had already been shown, and had already chosen to skip or play
-- against. The Ante ladder in the run info reads it too, and so shows what
-- LucyPyre will actually be asking for.
--
-- Two of them stack multiplicatively - each takes a tenth of what is LEFT, so
-- two are X0.81 rather than X0.8 - and are counted through
-- CelestasMod.find_joker, which sees a LucyPyre merged into another Joker as
-- well as one sitting on its own and already leaves out a debuffed one. The
-- percentage is read off each copy's own half, since that is the table a
-- merged half keeps its config in.
--
-- Installed from Game:start_run rather than at load, and this is not a detail.
-- Talisman REPLACES get_blind_amount (talisman.lua:342): it captures the
-- previous one but only calls it when to_big gives a plain number, so with its
-- big numbers on - which is this install's setting - everything wrapped before
-- it is simply dropped. This mod has priority 0 and sorts ahead of Talisman,
-- so a wrapper installed at load is always the one that gets dropped. By the
-- time a run starts every mod has loaded, so installing there puts this
-- OUTSIDE whatever they left behind. The identity guard keeps a second run
-- from stacking another copy on top.
--
-- Deliberately NOT guarded on the answer being a plain number: past a certain
-- Ante it is one of Talisman's big numbers, and those multiply through their
-- own metamethod. Nothing here COMPARES it, which is the thing Lua 5.1
-- refuses across types.

local LUCYPYRE_KEY = "j_celesta_lucypyre"

--- What every Blind's quota is multiplied by while LucyPyre is held.
function CelestasMod.lucypyre_scale()
    local scale = 1
    for _, found in ipairs(CelestasMod.find_joker(LUCYPYRE_KEY)) do
        local percent = ((found.ability or {}).extra or {}).percent or 0
        scale = scale * (1 - percent / 100)
    end

    -- ...and whatever a merge is reducing it by on top. Deme + LucyPyre is one
    -- such, and it is a REPLACING pair - so its card is not a LucyPyre to the
    -- loop above and its reduction has to arrive from somewhere else. See
    -- merge/bind.lua.
    if CelestasMod.bind_blind_scale then
        scale = scale * CelestasMod.bind_blind_scale()
    end

    return math.max(0, scale)
end

local lucypyre_wrapper
--- See the note on generations in sins/sins.lua: a second copy of this in
--- the chain would multiply the quota by the scale twice, so two runs in
--- one session halved the blind rather than taking a tenth off it.
local lucypyre_gen = 0

function CelestasMod.install_lucypyre_hook()
    if get_blind_amount == lucypyre_wrapper then return end
    local ref = get_blind_amount
    if type(ref) ~= "function" then return end

    lucypyre_gen = lucypyre_gen + 1
    local mine = lucypyre_gen
    lucypyre_wrapper = function(ante, ...)
        local amount = ref(ante, ...)
        if mine ~= lucypyre_gen then return amount end
        -- Asked for before the run has a Joker row, on the splash screen.
        if not (G.jokers and G.jokers.cards) then return amount end
        local scale = CelestasMod.lucypyre_scale()
        if scale == 1 then return amount end
        return amount * scale
    end
    get_blind_amount = lucypyre_wrapper
end

SMODS.Joker {
    key = "lucypyre",
    atlas = "lucypyre",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A passive the quota lookup reads, not a trigger; there is nothing to copy.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { percent = 10 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.percent } }
    end,
}

--------------------------------------------------------------------------------
-- Dooby [Uncommon] - paid for walking out of the shop with a full wallet.
--------------------------------------------------------------------------------
--
-- "No money was spent" is a question about MONEY, not about actions, so it is
-- answered by watching the wallet rather than by counting purchases.
-- context.buying_card would say a free card bought under Clearance Sale was
-- spending, and would miss a reroll besides; ease_dollars is where vanilla
-- sends every purchase, reroll, pack and voucher alike, so one hook covers all
-- of them and a $0 reroll correctly costs nothing.
--
-- Watched globally rather than from Dooby's own calculate, so that buying
-- Dooby ITSELF counts: the Joker is not in the row yet when its own price is
-- paid, and a card that pays out on the shop it was bought in would be free
-- money every time.
--
-- Stamped with the round number rather than raised and cleared, which is what
-- arena.lua does with G.GAME.round for the same reason: each shop sits on its
-- own round number, so last shop's stamp expires on its own and there is no
-- reset to get wrong - no second Dooby can clear the flag out from under the
-- first, and a reload cannot lose it.

local DOOBY_KEY = "j_celesta_dooby"

--- True for an amount that leaves the player's hands. Talisman's big numbers
--- have to go through to_big, which Lua 5.1 will not compare against a plain
--- number - and only Talisman makes them, so it is there whenever this is.
local function dooby_outgoing(mod)
    if type(mod) == "number" then return mod < 0 end
    if type(mod) == "table" and to_big then return to_big(mod) < to_big(0) end
    return false
end

--- True when money has left the player's hands during the shop now open.
function CelestasMod.shop_had_spending()
    if not (G.GAME and G.GAME.round) then return false end
    return G.GAME.celesta_shop_spent == G.GAME.round
end

--- Remembers that money left the player's hands in the shop now open.
local function dooby_note_spending()
    if G.GAME and G.GAME.round then
        G.GAME.celesta_shop_spent = G.GAME.round
    end
end

-- Installed from Game:start_run for the reason LucyPyre's is: every other mod
-- has loaded by then, so this sits outside their wrappers instead of under
-- them. Talisman does call the ease_dollars it captured while its animations
-- are on, but that is a setting the player can flip, and UnStable and Cryptid
-- are in this chain too - being outermost is the only version that does not
-- depend on what four other mods happen to do.
local dooby_wrapper
--- ...and the same here. Noting the spending twice is harmless in itself,
--- but the guard is the same one that was wrong for Sloth.
local dooby_gen = 0

function CelestasMod.install_dooby_hook()
    if ease_dollars == dooby_wrapper then return end
    local ref = ease_dollars
    if type(ref) ~= "function" then return end

    dooby_gen = dooby_gen + 1
    local mine = dooby_gen
    dooby_wrapper = function(mod, ...)
        if mine == dooby_gen and G.STATE == G.STATES.SHOP
            and dooby_outgoing(mod) then
            dooby_note_spending()
        end
        return ref(mod, ...)
    end
    ease_dollars = dooby_wrapper
end

-- Installed together, before the run the first quota is asked for.
local celesta_late_start_run_ref = Game.start_run
function Game:start_run(args)
    CelestasMod.install_lucypyre_hook()
    CelestasMod.install_dooby_hook()
    return celesta_late_start_run_ref(self, args)
end

SMODS.Joker {
    key = "dooby",
    atlas = "dooby",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- MoopyBuns' shape: a copier may score the X Mult, but `not
    -- context.blueprint` below keeps it from banking the growth a second time
    -- onto the original, which is where the scaling actually lives.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult_gain = 0.25, x_mult = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult_gain,
                          card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        -- Steamodded raises this for each thing bought - a Joker, a
        -- consumable, a voucher, a pack (button_callbacks.lua:2512), just
        -- before the price is charged at :2526, and it is the same context
        -- MoopyBuns counts. Heard as well as the wallet, not instead of it:
        -- this is the ordinary way money leaves in a shop, and hearing it here
        -- does not depend on a global wrapper surviving four other mods.
        -- `cost ~= 0` is vanilla's own test for whether it charges at all, so
        -- a card made free still costs nothing.
        if context.buying_card and not context.blueprint then
            local bought = context.card
            if bought and (bought.cost or 0) ~= 0 then
                dooby_note_spending()
            end
        end

        if context.ending_shop and not context.blueprint then
            if CelestasMod.shop_had_spending() then return end
            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "x_mult",
                scalar_value = "x_mult_gain",
                no_message = true,
            })
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { card.ability.extra.x_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        -- X1 is no multiplier at all; returning it would put a flourish over
        -- the Joker every hand for doing nothing.
        if context.joker_main and CelestasMod.more_than(card.ability.extra.x_mult, 1) then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Holding a Boss Blind shut
--------------------------------------------------------------------------------
--
-- Blind:disable() is deliberately NOT used. It is a one-way door: it undoes
-- the Blind's setup outright - The Wall's chips halved, The Manacle's hand
-- size handed back, The Needle's hands restored (blind.lua:687 onward) - and
-- there is no matching enable to put any of it back. `disabled` is the flag
-- every one of those effects is gated on, so setting the flag alone is "the
-- Boss does nothing right now" without spending anything that cannot be
-- un-spent.
--
-- ONE hold, and a set of REASONS for it. Adfree shuts the Boss for the opening
-- hand and Kuro shuts it for a whole Ante; two independent holders would each
-- set the flag and each clear it, so whichever let go first would hand the
-- Boss back while the other still wanted it held. The flag comes off when the
-- last reason does.
--
-- A Blind somebody else disabled - Chicot, a Tag - is left alone. Nothing is
-- recorded as held in that case, so nothing here ever hands back a Blind it
-- did not shut.

--- reason -> true, on G.GAME so it is saved with the run.
local BOSS_REASONS = "celesta_boss_holds"
--- ...and whether the Blind currently sitting out is sitting out because of
--- one of them.
local BOSS_OURS = "celesta_boss_held"

local function boss_apply()
    local blind = G.GAME and G.GAME.blind
    if not blind then return false end
    local wanted = next(G.GAME[BOSS_REASONS] or {}) ~= nil

    if wanted and not blind.disabled then
        if not blind.boss then return false end

        -- Through vanilla's Blind:disable(), rather than by setting the flag.
        --
        -- Five Boss Blinds apply a one-off change the moment they are SET and
        -- give it back only in there: The Needle takes the round's hands
        -- (blind.lua:196, refunded at :401), The Water its discards, The
        -- Manacle a hand size, and Crimson Heart and The Fish flip cards.
        -- Setting `disabled` leaves every one of those standing - so a held
        -- Needle still left the round with one hand, and the Joker looked
        -- like it had not fired at all. It also runs a MODDED Blind's own
        -- disable, which the flag never did, so this mod's twelve let go too.
        --
        -- ONCE per Blind, because disable() is not idempotent for those five:
        -- run twice against a Needle it hands the hands back twice. G.GAME.blind
        -- is one object reused for the whole run (game.lua:2481) - set_blind
        -- resets its fields rather than replacing it - so "already undone" is
        -- remembered against the round rather than on the object. One Blind
        -- per round, and the token changes with the name too, so a Blind
        -- re-rolled inside a round is still undone on its own account.
        --
        -- Guarded: a Blind that faults on the way out must not take the run
        -- down, and a Boss flagged shut is still better than one left open.
        local undone = "celesta_boss_undone"
        local token = tostring(G.GAME.round or 0) .. "|" .. tostring(blind.name)
        local let_go = false
        if type(blind.disable) == "function" and G.GAME[undone] ~= token then
            G.GAME[undone] = token
            local ok, err = pcall(blind.disable, blind)
            let_go = ok
            if not ok then
                CelestasMod.warn_once("boss_disable",
                    ("A held Boss Blind could not be let go through its own "
                     .. "disable(), so it is only flagged: %s"):format(tostring(err)))
            end
        end
        if not let_go then blind.disabled = true end
        G.GAME[BOSS_OURS] = true
    elseif not wanted and G.GAME[BOSS_OURS] then
        blind.disabled = false
        G.GAME[BOSS_OURS] = nil
    else
        -- Already where it should be, or shut by somebody else. Asked this way
        -- rather than by comparing the two flags so a NEW Blind, which arrives
        -- enabled with a reason still standing, is shut again.
        return false
    end

    -- Re-judged so the cards agree with the Blind: set_blind with `reset`
    -- skips choosing one and walks every card through debuff_card again
    -- (blind.lua:220), which is the route card.lua already takes whenever a
    -- Joker changes what a card is.
    G.E_MANAGER:add_event(Event {
        func = function()
            if G.GAME.blind then G.GAME.blind:set_blind(nil, true, nil) end
            return true
        end
    })
    return true
end

--- Hold the Boss shut for `reason`, or let that reason go.
function CelestasMod.hold_boss(reason, on)
    if not G.GAME then return false end
    G.GAME[BOSS_REASONS] = G.GAME[BOSS_REASONS] or {}
    G.GAME[BOSS_REASONS][reason] = on and true or nil
    return boss_apply()
end

--------------------------------------------------------------------------------
-- Adfree [Uncommon] - the Boss sits out the opening hand.
--------------------------------------------------------------------------------
--
-- Ben's shape: one sync that every route goes through and that works the
-- answer out from the world rather than from whoever called, so no path can
-- apply it twice and none can hand it back twice. The routes are setting_blind,
-- after (the hand just finished), end_of_round, and the two deck hooks - which
-- covers debuffing for free, because that is how vanilla implements it.

local ADFREE_KEY = "j_celesta_adfree"
local ADFREE_OVER = "celesta_adfree_opening_hand_over"

--- True while the round's opening hand has not been played yet.
---
--- The counter alone will not do it, and this is the whole of the bug this
--- Joker had. context.after is raised from INSIDE evaluate_play
--- (state_events.lua:869), while current_round.hands_played is incremented by
--- a separate, later event queued alongside it (:523). So at the one moment
--- this Joker has to let go, the hand that just finished has not been counted
--- yet - and reading the counter there kept the Boss shut for a second hand
--- as well.
---
--- The flag is what context.after writes, and it is asked first. The counter
--- stays underneath it for the case the flag cannot cover: a save loaded
--- part-way through a round, where no flag was ever written but the counter
--- is already right.
local function adfree_first_hand()
    if G.GAME and G.GAME[ADFREE_OVER] then return false end
    local round = G.GAME and G.GAME.current_round
    return round and (round.hands_played or 0) == 0 or false
end

--- Works the answer out from the world rather than from whoever called, so
--- selling one of two Adfrees does not hand the Boss back early.
local function adfree_sync()
    CelestasMod.hold_boss("adfree", adfree_first_hand()
        and CelestasMod.joker_in_play(ADFREE_KEY)
        and G.GAME.blind and G.GAME.blind.boss and true or false)
end

CelestasMod.adfree_sync = adfree_sync

SMODS.Joker {
    key = "adfree",
    atlas = "adfree",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A copy would hold a Blind that is already held; there is nothing to copy.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    add_to_deck = function(self, card, from_debuff)
        adfree_sync()
    end,

    remove_from_deck = function(self, card, from_debuff)
        -- Queued: on a sale this runs while the card is still in the row, so
        -- the count is asked once the row has settled.
        G.E_MANAGER:add_event(Event { func = function() adfree_sync() return true end })
    end,

    calculate = function(self, card, context)
        -- A new Blind is a new opening hand.
        if context.setting_blind and not context.blueprint then
            G.GAME[ADFREE_OVER] = nil
            adfree_sync()
        end

        -- context.after is the end of a played hand. The flag rather than the
        -- counter, for the reason on adfree_first_hand - and set before the
        -- sync rather than being the sync's own business, so every other route
        -- into it (a Joker bought, sold or debuffed later in this same hand)
        -- gets the same answer.
        if context.after and not context.blueprint then
            G.GAME[ADFREE_OVER] = true
            adfree_sync()
        end

        if context.end_of_round and not context.blueprint then
            G.GAME[ADFREE_OVER] = nil
            CelestasMod.hold_boss("adfree", false)
        end
    end,
}

--------------------------------------------------------------------------------
-- Kuro [Rare] - the Boss sits out every other Ante.
--------------------------------------------------------------------------------
--
-- Adfree's shape with a longer answer: that one holds the Boss for a hand,
-- this one for the whole of an Ante. Both go through the single hold above, so
-- the two of them in one row cannot fight over the flag.
--
-- The parity is the ANTE rather than the Blind, and only a Boss can be held at
-- all, so this is exactly "the Boss Blind of every odd Ante does nothing".

local KURO_KEY = "j_celesta_kuro"

--- Which Antes Kuro itself covers: 1 is the odd ones.
CelestasMod.KURO_PARITY = 1

--- True when the Ante being played has this parity.
function CelestasMod.ante_parity_is(parity)
    local resets = G.GAME and G.GAME.round_resets
    local ante = resets and resets.ante
    if type(ante) ~= "number" then return false end
    return ante % 2 == parity
end

-- Anything else in the row that holds the Boss on some Antes is a rule in
-- CelestasMod.KURO_RULES, which globals.lua declares and merge/bind.lua fills
-- in - so this file does not have to know that merges exist. It is declared
-- there rather than here because bind.lua is loaded before this file and would
-- otherwise have nothing to append to.

--- Works the answer out from the world, as Adfree's does.
---
--- Answers whether THIS call shut the Boss, so the Joker can say so the way
--- Chicot does. hold_boss reports any change including letting go, and letting
--- go is not something to announce.
function CelestasMod.kuro_sync()
    local want = CelestasMod.joker_in_play(KURO_KEY)
        and CelestasMod.ante_parity_is(CelestasMod.KURO_PARITY) and true or false
    if not want then
        for _, rule in ipairs(CelestasMod.KURO_RULES or {}) do
            local ok, met = pcall(rule)
            if ok and met then want = true break end
        end
    end
    local changed = CelestasMod.hold_boss("kuro", want)
    return want and changed or false
end

SMODS.Joker {
    key = "kuro",
    atlas = "kuro",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- A copy would hold a Blind that is already held; there is nothing to copy.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    add_to_deck = function(self, card, from_debuff)
        CelestasMod.kuro_sync()
    end,

    remove_from_deck = function(self, card, from_debuff)
        -- Queued: on a sale this runs while the card is still in the row, so
        -- the count is asked once the row has settled.
        G.E_MANAGER:add_event(Event {
            func = function() CelestasMod.kuro_sync() return true end })
    end,

    calculate = function(self, card, context)
        if context.setting_blind and not context.blueprint then
            -- Chicot's own two lines when it shuts a Boss (card.lua:2805): a
            -- timpani and "Boss Disabled!". Without them nothing on screen
            -- says this Joker did anything - which is how a Boss that was held
            -- but not undone read as a Joker that had never fired.
            if CelestasMod.kuro_sync() then
                play_sound("timpani")
                return {
                    message = localize("ph_boss_disabled"),
                    card = card,
                }
            end
        end
        -- Let go at the end of the round rather than at the next Ante: the
        -- reason is asked again the moment the next Blind is set, and leaving
        -- it standing through the shop would shut a Blind nobody has chosen.
        if context.end_of_round and not context.blueprint then
            CelestasMod.hold_boss("kuro", false)
        end
    end,
}

--------------------------------------------------------------------------------
-- The True Stars suit Jokers
--------------------------------------------------------------------------------
--
-- Two of the three can do nothing at all without a True Star in the deck, and
-- a True Star is not something a run stumbles into - it takes a Strength on an
-- Ace of Stars and nothing else - so they are gated the way the Star and Leaf
-- Jokers above are, through in_pool. AngelSteps is not: it has nothing to do
-- with the suit beyond shipping alongside it.

--- Keeps a Joker out of the pools until the deck holds a True Star. See
--- star_gated above for why this goes through in_pool rather than a gate
--- field.
local function true_star_gated(self, args)
    return CelestasMod.has_true_star()
end

--------------------------------------------------------------------------------
-- AngelSteps [Uncommon] - the base score, the other way round.
--------------------------------------------------------------------------------
--
-- `mult` and `hand_chips` are the globals evaluate_play keeps the running base
-- score in, and Steamodded raises context.modify_hand from inside
-- Blind:modify_hand with both already written to _G - so writing them here is
-- how a Joker does what The Flint does, at the one moment the base score is
-- still the base score and nothing has been added to it yet.
--
-- Returning a message rather than nothing: the flag that makes evaluate_play
-- re-draw the score readout is `modded`, and Steamodded raises it from
-- whether anything was calculated. Without it the hand would score swapped
-- while the readout still showed the old numbers.

SMODS.Joker {
    key = "angelsteps",
    atlas = "angelsteps",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A second swap is the first one undone.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        if context.modify_hand then
            mult, hand_chips = hand_chips, mult
            return { message = localize("celesta_swapped"), colour = G.C.CHIPS }
        end
    end,
}

--------------------------------------------------------------------------------
-- Kiri [Uncommon] - every True Star scores.
--------------------------------------------------------------------------------
--
-- Same shape as Unnamed above: modify_scoring_hand is asked once per card in
-- the played hand, and add_to_hand puts one into the scoring hand that the
-- poker hand left out - which is what vanilla's Splash does for everything.
--
-- Guarded on the hand actually being played, because the same context is
-- raised while a hand is only highlighted, to draw the preview.

SMODS.Joker {
    key = "kiri",
    atlas = "kiri",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- It is a question about the hand, and a copy would answer the same one.
    blueprint_compat = false, eternal_compat = true,

    in_pool = true_star_gated,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        if context.modify_scoring_hand and context.other_card
            and CelestasMod.is_true_star(context.other_card)
            and CelestasMod.hand_is_being_played() then
            return { add_to_hand = true }
        end
    end,
}

--------------------------------------------------------------------------------
-- Elara [Uncommon] - X3 the Chips a True Star holds.
--------------------------------------------------------------------------------
--
-- get_chip_bonus() is where a card's Chips live: its rank, its enhancement's
-- bonus and any perma_bonus a Hiker or a Bind has put on it. The card has
-- already paid that once by the time a Joker is asked, so the top-up is TWO
-- times it, not three - three would be X4.

SMODS.Joker {
    key = "elara",
    atlas = "elara",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_chips = 3 } },

    in_pool = true_star_gated,

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_chips } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and CelestasMod.is_true_star(context.other_card) then
            local other = context.other_card
            local stored = other.get_chip_bonus and other:get_chip_bonus() or 0
            if stored <= 0 then return end
            return {
                chips = stored * (card.ability.extra.x_chips - 1),
                card = other,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Nanoless [Rare] - a True Star's Chips arrive as Mult.
--------------------------------------------------------------------------------
--
-- Paid as a negative and a positive in one answer, which is the only shape
-- available: the card has ALREADY paid its Chips by the time a Joker is asked
-- about it. SMODS.calculate_main_scoring evaluates the scoring card first and
-- then walks the Jokers with context.individual, so there is nothing to
-- intercept - only something to take back.
--
-- Taking it back here rather than zeroing Card:get_chip_bonus, which would
-- have been the tidier-looking hook: that number is read by Elara, by Evil
-- Neuro and by the Deck of Sins' Pride stat, and none of those asked for a
-- True Star to be worth nothing. The redirection is this Joker's business and
-- stays inside it.
--
-- "Its Chips" is get_chip_bonus - rank, enhancement and any perma_bonus -
-- which is the same quantity Elara calls stored Chips. What another Joker
-- pays for the card is that Joker's, and is not moved.

SMODS.Joker {
    key = "nanoless",
    atlas = "nanoless",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    in_pool = true_star_gated,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and CelestasMod.is_true_star(context.other_card) then
            local other = context.other_card
            local chips = other.get_chip_bonus and other:get_chip_bonus() or 0
            if chips <= 0 then return end
            return { chips = -chips, mult = chips, card = other }
        end
    end,
}

--------------------------------------------------------------------------------
-- Toma [Common] - a True Star pays out, half the time.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "toma",
    atlas = "toma",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 2, dollars = 5 } },

    in_pool = true_star_gated,

    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_toma")
        return { vars = { numerator, denominator, card.ability.extra.dollars } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and CelestasMod.is_true_star(context.other_card)
            and SMODS.pseudorandom_probability(
                card, "celesta_toma", 1, card.ability.extra.odds) then
            return { dollars = card.ability.extra.dollars,
                     card = context.other_card }
        end
    end,
}

--------------------------------------------------------------------------------
-- ToriOriane [Common] - a flat pair of numbers on a True Star.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "torioriane",
    atlas = "torioriane",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { mult = 6, chips = 6 } },

    in_pool = true_star_gated,

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.mult, card.ability.extra.chips } }
    end,

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play
            and CelestasMod.is_true_star(context.other_card) then
            return {
                mult = card.ability.extra.mult,
                chips = card.ability.extra.chips,
                card = context.other_card,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Fleshy [Uncommon] - a Boss Blind cannot touch a True Star.
--------------------------------------------------------------------------------
--
-- Blind:debuff_card is the whole of what this has to answer. Every way a Boss
-- Blind marks a card goes through it: the suit, rank, face and enhancement
-- rules in vanilla's own body, The Pillar's played-this-Ante flag, Verdant
-- Leaf's blanket, and any modded Blind at all, which Steamodded routes through
-- the same function by way of its recalc_debuff (blind.lua:669). Hooking here
-- is therefore narrower than it looks - it is Boss Blinds and nothing else,
-- which is what was asked for. A debuff from somewhere that is not a Blind
-- never reaches this function and is left alone.

local FLESHY_KEY = "j_celesta_fleshy"

--- True when a Fleshy other than `excluding` is in play.
---
--- find_joker, so a Fleshy inside a merge counts as either half, and a
--- debuffed one does not count at all - Crimson Heart picking Fleshy should
--- take the shield down with it.
local function fleshy_present(excluding)
    for _, held in ipairs(CelestasMod.find_joker(FLESHY_KEY)) do
        if held.card ~= excluding then return true end
    end
    return false
end

--- Forced during the re-judge below, because vanilla is not symmetric about
--- when a Joker is in G.jokers: add_to_deck runs before the card is emplaced
--- and remove_from_deck runs after it is stripped (see the Haruka note
--- above), so at the one moment the answer has to change, asking the row
--- gives last moment's answer.
local fleshy_forced = nil

local function fleshy_shields()
    if fleshy_forced ~= nil then return fleshy_forced end
    return fleshy_present(nil)
end

--- Puts every True Star in the deck back in front of the Blind in play.
---
--- Selling Fleshy mid-Blind has to re-apply what the Blind was going to do,
--- and buying one mid-Blind has to lift it; nothing else re-judges a card on
--- its own. Only True Stars are re-judged, because no other card's answer can
--- have changed.
local function fleshy_rejudge(shielded)
    local blind = G.GAME and G.GAME.blind
    if not (blind and blind.debuff_card and G.playing_cards) then return end

    fleshy_forced = shielded
    local ok, err = pcall(function()
        for _, playing in ipairs(G.playing_cards) do
            if CelestasMod.is_true_star(playing) then
                blind:debuff_card(playing)
            end
        end
    end)
    fleshy_forced = nil
    if not ok then error(err, 0) end
end

local celesta_fleshy_debuff_ref = Blind.debuff_card

function Blind:debuff_card(card, from_blind)
    if CelestasMod.is_true_star(card) and fleshy_shields() then
        -- set_debuff(false) rather than an early return with nothing done:
        -- this is the same line vanilla ends on for a card its Blind does not
        -- want (blind.lua:721), and it is what LIFTS a debuff the Blind
        -- applied before Fleshy arrived.
        card:set_debuff(false)
        return
    end
    return celesta_fleshy_debuff_ref(self, card, from_blind)
end

SMODS.Joker {
    key = "fleshy",
    atlas = "fleshy",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    -- Gated like the rest of the True Stars Jokers: there is nothing for it to
    -- shield until the deck holds one, and a True Star is not something a run
    -- stumbles into.
    in_pool = true_star_gated,

    add_to_deck = function(self, card, from_debuff)
        fleshy_rejudge(true)
    end,

    remove_from_deck = function(self, card, from_debuff)
        fleshy_rejudge(fleshy_present(card))
    end,
}

--------------------------------------------------------------------------------
-- Nico Viras [Uncommon] - the shop's reroll price climbs half as fast.
--------------------------------------------------------------------------------
--
-- calculate_reroll_cost is the one place the price is worked out
-- (common_events.lua:2630): it adds a dollar to the round's running increase
-- and rebuilds the price from it. Everything that rerolls - the shop button,
-- Chaos the Clown, a Director's Cut - comes through here, so one hook covers
-- them all.
--
-- The increase is halved AFTER vanilla has added to it, and then the price is
-- rebuilt by calling vanilla again with the increment skipped. Doing it that
-- way rather than writing the price directly means vanilla still owns both
-- sums, including the temp_reroll_cost a Voucher may have put in the way.

local NICOVIRAS_KEY = "j_celesta_nicoviras"

--- What a reroll adds to the price while this Joker is out.
CelestasMod.NICOVIRAS_STEP = 0.5

local celesta_nicoviras_reroll_ref = calculate_reroll_cost

function calculate_reroll_cost(skip_increment, ...)
    local round = G.GAME and G.GAME.current_round
    if skip_increment or not round
        or not next(CelestasMod.find_joker(NICOVIRAS_KEY)) then
        return celesta_nicoviras_reroll_ref(skip_increment, ...)
    end

    local before = round.reroll_cost_increase or 0
    local ret = celesta_nicoviras_reroll_ref(skip_increment, ...)
    local added = (round.reroll_cost_increase or 0) - before
    -- A free reroll returns before the increase is touched, and so does
    -- anything else that decides this one is not chargeable.
    if added <= 0 then return ret end

    round.reroll_cost_increase = before + added * CelestasMod.NICOVIRAS_STEP
    celesta_nicoviras_reroll_ref(true, ...)
    return ret
end

SMODS.Joker {
    key = "nicoviras",
    atlas = "nicoviras",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { step = CelestasMod.NICOVIRAS_STEP } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.step } }
    end,
}

--------------------------------------------------------------------------------
-- Mogu [Common] - the reroll sometimes costs nothing extra.
--------------------------------------------------------------------------------
--
-- Nico Viras' hook with a different answer: that one halves what a reroll adds
-- to the price, this one sometimes takes all of it back. Wrapped after it, so
-- with both in the row Nico halves the increase first and Mogu's roll can then
-- wipe what is left - which is the order the two descriptions read in.
--
-- The roll is made against the Joker's own odds rather than a constant, so
-- Oops! All 6s and anything else that widens a chance widens this one. Safe
-- here where it would not be inside scoring: SMODS.pseudorandom_probability
-- runs two full calculate_context passes, and a reroll happens once, in the
-- shop, outside any copier chain.

local MOGU_KEY = "j_celesta_mogu"
CelestasMod.MOGU_ODDS = 4

local celesta_mogu_reroll_ref = calculate_reroll_cost

--- Every Mogu that can act on a reroll, as { card = ... } entries.
---
--- The ones in the row, and - if none - a CDawg holding a sold one. Nothing
--- in this Joker is a calculate, so CDawg's own lend never reaches it; see
--- jokers/cdawg.lua. The CDawg card is what rolls, being the card doing it.
local function mogu_holders()
    local held = CelestasMod.find_joker(MOGU_KEY)
    if next(held) then return held end
    local cdawg = CelestasMod.cdawg_running
        and CelestasMod.cdawg_running(MOGU_KEY)
    return cdawg and { { card = cdawg } } or held
end

function calculate_reroll_cost(skip_increment, ...)
    local round = G.GAME and G.GAME.current_round
    local held = round and mogu_holders()
    if skip_increment or not held or not next(held) then
        return celesta_mogu_reroll_ref(skip_increment, ...)
    end

    local before = round.reroll_cost_increase or 0
    local ret = celesta_mogu_reroll_ref(skip_increment, ...)
    local added = (round.reroll_cost_increase or 0) - before
    -- A free reroll returns before the increase is touched, and so does
    -- anything else that decides this one is not chargeable.
    if added <= 0 then return ret end

    -- The leftmost Mogu rolls, the way the Joker row settles every
    -- disagreement. One roll however many are held: the price either goes up
    -- or it does not, and there is nothing for a second one to add.
    local mine = held[1]
    local odds = (mine.ability and mine.ability.extra
        and mine.ability.extra.odds) or CelestasMod.MOGU_ODDS
    if not SMODS.pseudorandom_probability(mine.card, "celesta_mogu", 1, odds,
                                          "celesta_mogu") then
        return ret
    end

    -- Put back where it was, and rebuild the price from it the way Nico Viras
    -- does - vanilla still owns both sums, including the temp_reroll_cost a
    -- Voucher may have put in the way.
    round.reroll_cost_increase = before
    celesta_mogu_reroll_ref(true, ...)
    return ret
end

SMODS.Joker {
    key = "mogu",
    atlas = "mogu",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = CelestasMod.MOGU_ODDS } },

    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_mogu")
        return { vars = { numerator, denominator } }
    end,
}

--------------------------------------------------------------------------------
-- Dokibird [Rare] - one card scores, and the rest are spent on it.
--------------------------------------------------------------------------------
--
-- UnStable's Social Experiment is the shape: take the Chips off a played card,
-- double them, and put them on another one permanently.
--
-- Hooked at context.destroy_card rather than by dissolving the cards here.
-- That is the game's own question - SMODS walks the played cards after the
-- final scoring step and asks every Joker whether each one should go
-- (utils.lua:2044) - so saying yes gets the animation, the removal from the
-- deck and the remove_playing_cards pass that other Jokers watch, all for
-- free. It also hands over context.cardarea == 'unscored' for exactly the
-- cards this is about, which is the distinction the card is written in.
--
-- "Stored Chips" is what a card is worth in Chips - its rank, its
-- enhancement's bonus and any permanent bonus on top - which is
-- get_chip_bonus, the same reading Elara's description means by the phrase.
-- The gain is written to perma_bonus, which is where a Chip bonus that
-- outlives the hand lives.

--- A played card with this many stored Chips or more is left alone.
CelestasMod.DOKIBIRD_CAP = 100

--- ...and one under it is worth this much to the card that did score.
CelestasMod.DOKIBIRD_RATE = 2

--- The one card that scored, if the hand is the shape this Joker wants.
---
--- Only the one-scoring-card half is tested. "With at least one unscoring
--- card" is the other half of the rule and needs no test: the caller only
--- reaches this from the unscored branch, and a card being unscored IS an
--- unscoring card in the hand.
local function dokibird_target(context)
    local scoring = context.scoring_hand
    if not (scoring and #scoring == 1) then return nil end
    return scoring[1]
end

SMODS.Joker {
    key = "dokibird",
    atlas = "dokibird",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- A copy would be asked the same question about the same cards and would
    -- pay the doubling a second time.
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { cap = CelestasMod.DOKIBIRD_CAP,
                         rate = CelestasMod.DOKIBIRD_RATE } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.cap, card.ability.extra.rate } }
    end,

    calculate = function(self, card, context)
        if not (context.destroy_card and context.cardarea == "unscored"
            and not context.blueprint and not context.retrigger_joker) then
            return
        end

        local target = dokibird_target(context)
        if not target then return end

        local doomed = context.destroy_card
        local stored = doomed.get_chip_bonus and doomed:get_chip_bonus() or 0
        -- Nothing to take is not a card to destroy, and the cap is what the
        -- card advertises: a big card is left where it is.
        --
        -- Through more_than both times. `stored` is a playing card's chip
        -- bonus and this Joker is what makes those large - it writes the
        -- perma_bonus that get_chip_bonus reads back - so it feeds the number
        -- that would break its own guard, and needs no Vedal in the row to get
        -- there. `a <= 0` is `not (a > 0)`; `a >= b` is `not (b > a)`.
        if not CelestasMod.more_than(stored, 0)
            or not CelestasMod.more_than(card.ability.extra.cap, stored) then
            return
        end

        local gain = stored * card.ability.extra.rate
        target.ability.perma_bonus = (target.ability.perma_bonus or 0) + gain

        return {
            remove = true,
            message = localize { type = "variable", key = "a_chips",
                                 vars = { gain } },
            colour = G.C.CHIPS,
            card = target,
        }
    end,
}

--------------------------------------------------------------------------------
-- Snuffy [Rare] - select as many extra cards as you have Hands left.
--------------------------------------------------------------------------------
--
-- Granted through selection_sync above, which is the ONE way this mod moves
-- the card selection limit. Writing G.hand.config.highlighted_limit directly
-- would not survive contact with it: SMODS.change_play_limit keeps its own
-- play and discard limits and then SETS highlighted_limit to the larger of the
-- two, so the next Joker to raise the limit properly would wipe whatever had
-- been written by hand.
--
-- The ledger field is Shiabun's, shared by everything here that raises this
-- limit. It is per CARD, so two Jokers keeping their own receipts under the
-- same name do not collide.

--- How many extra picks this card should be handing out right now.
local function snuffy_want()
    local round = G.GAME and G.GAME.current_round
    return math.max(0, (round and round.hands_left) or 0)
end

SMODS.Joker {
    key = "snuffy",
    atlas = "snuffy",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- Nothing to copy: the limit belongs to this card, and its own hooks give
    -- it and take it back.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return { vars = { snuffy_want() } }
    end,

    -- Polled rather than hooked to whatever spends a Hand. The number changes
    -- at the start of a round, when a hand is played, when a Joker or Voucher
    -- hands one back, and when a Blind takes one away; a poll is right for all
    -- of them and cannot be wrong for the one that gets added next.
    --
    -- added_to_deck gated the way SmittenSeraph's is, so a copy in the shop or
    -- the Collection does not hand out a limit it does not own.
    update = function(self, card, front)
        if card.added_to_deck then selection_sync(card, snuffy_want()) end
    end,

    add_to_deck = function(self, card, from_debuff)
        selection_sync(card, snuffy_want())
    end,

    remove_from_deck = function(self, card, from_debuff)
        selection_release(card)
    end,
}

--------------------------------------------------------------------------------
-- Urschleim [Rare] - eats a Joker a round, and eventually there are more of it.
--------------------------------------------------------------------------------
--
-- Several Urschleims are one Urschleim wearing several cards. The numbers live
-- on each card, and every meal writes the same pair onto all of them - which is
-- what "in sync" is: one total, shown and scored the same by each. Kept on the
-- cards rather than on G.GAME so that selling them takes it away, which a
-- run-level tally would not.
--
-- Only ONE of them eats. Otherwise three copies would clear three Jokers a
-- round and the board would be gone by the ante after next. The one that eats
-- is the leftmost, which is how the Joker row settles every other disagreement
-- in this mod - and it stands in for "the original" without having to mark a
-- card and then decide what happens when that card is the one sold.
--
-- The art is 71x85, centred in the card cell the way Boosfer's 71x71 is, and
-- exempt from the corner mask in tools/round_corners.py for the same reason:
-- the card's corners are nowhere near a blob.

local URSCHLEIM_KEY = "j_celesta_urschleim"

--- Every Urschleim in play, leftmost first.
---
--- find_joker, so one inside a merge answers as either half and a debuffed one
--- does not answer at all - a debuffed Urschleim is not eating anything.
local function urschleim_all()
    return CelestasMod.find_joker(URSCHLEIM_KEY)
end

--- Writes the group's two numbers onto every Urschleim there is.
---
--- The ability table comes from find_joker rather than from the card, because
--- a merged Urschleim keeps its own ability under the host's and that is the
--- one its loc_vars and its scoring read.
local function urschleim_sync(x_chips, consumed)
    for _, held in ipairs(urschleim_all()) do
        local extra = held.ability and held.ability.extra
        if extra then
            extra.x_chips = x_chips
            extra.consumed = consumed
        end
    end
end

--- The Jokers this one is allowed to eat: everything in the row that is not an
--- Urschleim and not eternal.
---
--- Eternal is asked here rather than left to SMODS.destroy_cards, which would
--- refuse it anyway - but refusing it AFTER the meal has been paid for is how
--- Trickywi once paid out for a neighbour it never ate.
---
--- card_is_joker with debuffed included, so a debuffed copy is still family.
local function urschleim_menu()
    local out = {}
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        if not CelestasMod.card_is_joker(held, URSCHLEIM_KEY, true)
            and not held.getting_sliced
            and not SMODS.is_eternal(held) then
            out[#out + 1] = held
        end
    end
    return out
end

--- True when there is room in the row for one more.
---
--- getting_sliced is skipped because the Joker just eaten is still in the row:
--- SMODS.destroy_cards marks it and dissolves it on a later frame, so counting
--- the cards as they are would say the row is full when it is about to not be.
local function urschleim_room()
    if not (G.jokers and G.jokers.config) then return false end
    local occupied = 0
    for _, held in ipairs(G.jokers.cards or {}) do
        if not held.getting_sliced then occupied = occupied + 1 end
    end
    return occupied < (G.jokers.config.card_limit or 0)
end

SMODS.Joker {
    key = "urschleim",
    atlas = "urschleim",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- A copy would eat a second Joker every round, which is not a copy of one
    -- Joker's worth of anything.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { rate = 0.1, per = 5, x_chips = 1, consumed = 0,
                         last_round = 0 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        return { vars = { extra.rate, extra.per, extra.x_chips } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            local x_chips = card.ability.extra.x_chips or 1
            if x_chips > 1 then return { x_chips = x_chips } end
            return
        end

        -- cardarea == G.jokers is what marks the once-a-round Joker pass; the
        -- same context reaches a Joker several times without it, and the round
        -- number is the belt to that pass's braces.
        if not (context.end_of_round and context.cardarea == G.jokers
            and not context.blueprint) then
            return
        end

        local all = urschleim_all()
        if not (all[1] and all[1].card == card) then return end

        local extra = card.ability.extra
        local round = G.GAME and G.GAME.round
        if round and extra.last_round == round then return end

        local menu = urschleim_menu()
        if #menu == 0 then return end
        extra.last_round = round

        local victim = pseudorandom_element(menu, pseudoseed("celesta_urschleim"))
        -- Read before the meal: a card that has been removed is not one to
        -- read a sell value off.
        local gain = extra.rate * (victim.sell_cost or 0)
        local x_chips = (extra.x_chips or 1) + gain
        local consumed = (extra.consumed or 0) + 1

        SMODS.destroy_cards(victim)

        -- One more of itself every `per` meals. Made before the sync, so the
        -- new card is written the same numbers as the rest of them.
        --
        -- Skipped when the row is full rather than queued: the meal has
        -- already happened and the Chips are already owed, and a duplicate
        -- that has nowhere to sit is not worth holding the round open for.
        if consumed % extra.per == 0 and urschleim_room() then
            local made = SMODS.add_card { key = URSCHLEIM_KEY }
            if made then made:start_materialize() end
        end

        urschleim_sync(x_chips, consumed)

        return {
            message = localize { type = "variable", key = "a_xchips",
                                 vars = { x_chips } },
            colour = G.C.CHIPS,
            card = card,
        }
    end,
}

--------------------------------------------------------------------------------
-- Hidden Tech [Common] - retriggers by rank, and is living on borrowed time.
--------------------------------------------------------------------------------
--
-- Two rolls out of the same twenty. The played card's RANK is the numerator of
-- the first, so a Two is 2 in 20 and an Ace is 14 - Card:get_id is the rank as
-- a number and is asked rather than reimplemented, because it already knows
-- what a Stone Card is (card.lua:1148) and SMODS.has_no_rank is the question
-- to ask before it.
--
-- The second roll is the one that ends it. It starts at 1 in 20 and the
-- numerator goes up by one every round it comes through, so the card is on a
-- clock from the moment it is bought: twenty rounds is certain death and the
-- middle of that is likelier than not.
--
-- Both go through SMODS.pseudorandom_probability rather than a bare
-- pseudorandom, which is what puts them in front of Oops! All 6s, Adfree and
-- every other thing in the game that moves a listed chance.

local HIDDEN_TECH_SEED = "celesta_hidden_tech"
local HIDDEN_TECH_DEATH_SEED = "celesta_hidden_tech_death"

SMODS.Joker {
    key = "hidden_tech",
    atlas = "hidden_tech",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = false,
    -- A copy would roll its own retriggers, which is a fair copy of what this
    -- does; it has no clock of its own to run down.
    blueprint_compat = true, eternal_compat = true,

    -- CDawg keeps the retrigger and not the clock: the end-of-round branch
    -- below removes the card it is running on, and under CDawg's lend that
    -- card is CDawg. See jokers/cdawg.lua.
    celesta_cdawg_skip = { end_of_round = true },

    config = { extra = { odds = 20, chance = 1, step = 1, repetitions = 1 } },

    loc_vars = function(self, info_queue, card)
        local extra = card.ability.extra
        -- Asked of both rolls separately. The numerator of the first is the
        -- rank and so has no number to print - "n" is the whole of what the
        -- card can say about it - but the DENOMINATOR is still whatever the
        -- run has made it, and printing 20 while rolling out of 40 is the
        -- drift these vars exist to prevent.
        local _, denominator = SMODS.get_probability_vars(
            card, 1, extra.odds, HIDDEN_TECH_SEED)
        local chance, death_denominator = SMODS.get_probability_vars(
            card, extra.chance, extra.odds, HIDDEN_TECH_DEATH_SEED)
        return { vars = { "n", denominator, chance, death_denominator,
                          extra.step } }
    end,

    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play
            and context.other_card then
            local other = context.other_card
            -- A card with no rank has no numerator, which is not the same as
            -- a numerator of zero: there is nothing to roll.
            if SMODS.has_no_rank(other) or not other.get_id then return end
            local rank = other:get_id()
            if not (type(rank) == "number" and rank > 0) then return end

            if SMODS.pseudorandom_probability(
                card, HIDDEN_TECH_SEED, rank, card.ability.extra.odds) then
                return {
                    message = localize("k_again_ex"),
                    repetitions = card.ability.extra.repetitions,
                    card = card,
                }
            end
            return
        end

        -- cardarea == G.jokers is what marks the once-a-round Joker pass; the
        -- same context reaches a Joker several times without it, and this one
        -- both kills the card and winds its clock on.
        if not (context.end_of_round and context.cardarea == G.jokers
            and not context.blueprint) then
            return
        end

        local extra = card.ability.extra
        if not SMODS.pseudorandom_probability(
            card, HIDDEN_TECH_DEATH_SEED, extra.chance, extra.odds) then
            -- Lived. The next one is that much less likely to be survived.
            extra.chance = extra.chance + extra.step
            return
        end

        -- Gros Michel's exit, beat for beat.
        G.E_MANAGER:add_event(Event {
            func = function()
                play_sound("tarot1")
                card.T.r = -0.2
                card:juice_up(0.3, 0.4)
                card.states.drag.is = true
                card.children.center.pinch.x = true
                G.E_MANAGER:add_event(Event {
                    trigger = "after", delay = 0.3, blockable = false,
                    func = function()
                        G.jokers:remove_card(card)
                        card:remove()
                        return true
                    end
                })
                return true
            end
        })

        -- Not "Extinct!". That is Gros Michel's word and it means the Joker
        -- has left the run's pool for good; this one has no pool flag and can
        -- be bought again the next time the shop offers it.
        return {
            message = localize("celesta_useless"),
            colour = G.C.RED,
            card = card,
        }
    end,
}


--------------------------------------------------------------------------------
-- Nimi [Uncommon] - takes a Boss Blind's debuffs back off, twenty times.
--------------------------------------------------------------------------------
--
-- Fleshy's shape, a little further down the same funnel. Blind:debuff_card
-- (blind.lua:667) is the one place a card is debuffed BY a Blind - every rule a
-- Boss has ends there - so one hook covers every Boss in the game, this mod's
-- six included, without knowing anything about any of them.
--
-- Where Fleshy answers BEFORE the ref and the card is never debuffed at all,
-- this answers after it. That is what the card says: it undoes a debuff, and
-- what it counts is cards the Blind actually debuffed. The marker is vanilla's
-- own - card.debuffed_by_blind, set on the tail of every branch of debuff_card
-- that debuffs something - so nothing here has to work out which rule caught
-- the card.
--
-- Written out the way the other Jokers at the tail of this file are: harnesses
-- slice from the middle to the end, where SMODS.current_mod is not set.
local NIMI_KEY = "j_celesta_nimi"

--- How many more cards this Nimi will free.
local function nimi_left(ability)
    local extra = ability and ability.extra
    if not extra then return 0 end
    return math.max(0, (extra.limit or 0) - (extra.freed or 0))
end

--- The Nimi that frees the next card, and the ability table holding its count.
---
--- Through find_joker rather than a walk of the row, so an absorbed Nimi
--- answers too - and find_joker hands back that HALF's ability table, which is
--- where the count has to be written or the host's would grow instead.
local function nimi_on_duty()
    for _, entry in ipairs(CelestasMod.find_joker(NIMI_KEY)) do
        if nimi_left(entry.ability) > 0 then return entry end
    end
    return nil
end

--- Set while this is spending a Nimi, so the re-judge it causes cannot re-enter.
local nimi_spending = false

-- Guarded the way the sale hook further up is: there is always a Blind in the
-- game, and there is not always one in a harness that has sliced this file open
-- to read a single Joker.
local celesta_nimi_debuff_ref = Blind and Blind.debuff_card
if celesta_nimi_debuff_ref then
    function Blind:debuff_card(card, from_blind)
        local ret = celesta_nimi_debuff_ref(self, card, from_blind)
        if nimi_spending then return ret end
        -- Boss Blinds only, which is what the card says - and the only kind
        -- that debuffs anything in the first place.
        if not (self.boss and not self.disabled) then return ret end
        if not (card and card.debuff and card.debuffed_by_blind) then return ret end

        local entry = nimi_on_duty()
        if not entry then return ret end

        -- The same line vanilla ends on for a card its Blind does not want
        -- (blind.lua:721), which is what LIFTS a debuff rather than preventing
        -- one. set_debuff clears debuffed_by_blind itself on the way out.
        card:set_debuff(false)

        -- A card freed earlier this round is freed again without being counted
        -- again. Every set_ability and set_base re-judges the card it touches
        -- (card.lua:151, :490) and so does every enhancement handed out
        -- mid-hand, so a count kept per JUDGEMENT would spend the whole
        -- allowance on one card.
        local round = (G.GAME and G.GAME.round) or 0
        if card.celesta_nimi_freed == round then return ret end
        card.celesta_nimi_freed = round

        local extra = entry.ability.extra
        extra.freed = (extra.freed or 0) + 1
        if nimi_left(entry.ability) > 0 then
            card_eval_status_text(entry.card, "extra", nil, nil, nil,
                { message = localize("celesta_undebuffed"), colour = G.C.FILTER })
            return ret
        end

        -- Spent. Debuffed through SMODS.debuff_card rather than set_debuff,
        -- because the Blind recalculates every card's debuff constantly and a
        -- plain one would be cleared straight back off; a debuff SOURCE
        -- survives that and is saved with the card (utils.lua:419).
        --
        -- On a merge that debuffs the whole card, both halves with it. There is
        -- no debuff that applies to one half of a merged Joker - the card is
        -- what carries it - and a spent Nimi that kept on working would be the
        -- worse answer.
        nimi_spending = true
        local ok, err = pcall(SMODS.debuff_card, entry.card, true, "celesta_nimi")
        nimi_spending = false
        if not ok then
            CelestasMod.warn_once("nimi_spent",
                "Nimi could not debuff itself once spent: " .. tostring(err))
        end
        card_eval_status_text(entry.card, "extra", nil, nil, nil,
            { message = localize("celesta_spent"), colour = G.C.RED })
        return ret
    end
end

SMODS.Joker {
    key = "nimi",
    atlas = "nimi",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- The undebuffing belongs to this card and is counted on it; a copy would
    -- spend an allowance it does not own.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { limit = 20, freed = 0 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.limit,
                          nimi_left(card.ability) } }
    end,
}


--------------------------------------------------------------------------------
-- Lucia [Rare] - the smaller the hand, the harder it hits.
--------------------------------------------------------------------------------
--
-- Counted off the PLAYED hand rather than the scoring one: a card that did not
-- score was still played, and "cards in played hand" is what the line says.
-- context.joker_main carries full_hand, which is G.play.cards
-- (state_events.lua:667).

--- The taper: `top` for a hand of one card, one less for each card after that,
--- and never below `bottom`.
---
--- Shared with Lucia + Mari Yume in merge/bind.lua, which spends the same
--- curve on retriggers instead of on Mult. The two differ only in where the
--- bottom is - X1 is no multiplier and 0 is no retrigger - so that is the
--- argument rather than a second copy of the arithmetic.
function CelestasMod.lucia_taper(top, played, bottom)
    return math.max(bottom, top - math.max(0, played - 1))
end

SMODS.Joker {
    key = "lucia",
    atlas = "lucia",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        if not context.joker_main then return end
        local played = #(context.full_hand or {})
        if played <= 0 then return end
        local x_mult = CelestasMod.lucia_taper(card.ability.extra.x_mult, played, 1)
        -- X1 is no multiplier at all, and returning it would put a flourish
        -- over the Joker every hand for doing nothing.
        if x_mult > 1 then return { x_mult = x_mult } end
    end,
}


--------------------------------------------------------------------------------
-- Hime [Uncommon] - the Eutrophic cards in your hand copy what you played.
--------------------------------------------------------------------------------
--
-- Two things at once, and the second is what makes the first worth anything.
--
-- A Eutrophic card held in hand already copies the leftmost card of its own
-- area, which is the leftmost card still in your hand - whatever happened to
-- be left over. Hime points it at the leftmost card of the hand you PLAYED,
-- through CelestasMod.eutrophic_source, and then scores it.
--
-- The timing is Mint Fantome's, for Mint Fantome's reason: context.after is
-- too late, because vanilla commits the score at state_events.lua:1031 and
-- fires `after` at :1070. The held-in-hand pass (:798) is the first thing to
-- run once every played card has scored and the last thing that still counts.
--
-- Written out the way the other Jokers at the tail of this file are:
-- harnesses slice from the middle to the end, where SMODS.current_mod is not
-- set.
local HIME_EUTROPHIC = "m_celesta_eutrophic"

--- Set while Hime is scoring a held card, so the pass cannot re-enter.
local hime_scoring = false

--- Scores one held Eutrophic card as though it had been played, pointed at the
--- leftmost card of the played hand.
---
--- A FRESH context, not the live one: SMODS.score_card sets main_scoring,
--- individual and other_card as it goes, and clobbering the table the caller is
--- still iterating would corrupt the rest of the held pass. cardarea = G.play
--- is what makes this scoring rather than another held trigger, and it is also
--- what Eutrophic's own scoring branch is gated on.
local function hime_score(target, context)
    local played = G.play and G.play.cards and G.play.cards[1]
    if not played then return false end

    hime_scoring = true
    CelestasMod.eutrophic_target = played
    local ok, err = pcall(SMODS.score_card, target, {
        cardarea = G.play,
        full_hand = context.full_hand,
        scoring_hand = context.scoring_hand,
        scoring_name = context.scoring_name,
        poker_hands = context.poker_hands,
    })
    CelestasMod.eutrophic_target = nil
    hime_scoring = false

    if not ok then
        CelestasMod.warn_once("hime_score",
            "Hime could not score a held Eutrophic card: " .. tostring(err))
    end
    return ok
end

SMODS.Joker {
    key = "hime",
    atlas = "hime",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A copy would score the same held cards a second time, which is a
    -- retrigger of the whole hand rather than a copy of what this does.
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[HIME_EUTROPHIC]
        return {}
    end,

    calculate = function(self, card, context)
        if not (context.individual and context.cardarea == G.hand
                and context.other_card and not context.end_of_round
                and not hime_scoring) then return end
        local target = context.other_card
        -- A debuffed card scores nothing, the same as in the played hand.
        if target.debuff then return end
        if not SMODS.has_enhancement(target, HIME_EUTROPHIC) then return end
        hime_score(target, context)
    end,
}


--------------------------------------------------------------------------------
-- Calamitas [Legendary] - the row on its shorter side, over and over.
--------------------------------------------------------------------------------
--
-- Placement is the whole of it. Calamitas counts the Jokers to its left and
-- the Jokers to its right and takes the SMALLER of the two, so sitting at
-- either end is worth nothing and the middle is worth the most - and widening
-- the row only helps on the side that is already short.
--
-- Written out the way the other Jokers at the tail of this file are: harnesses
-- slice from the middle to the end, where SMODS.current_mod is not set.

--- The most it will ever retrigger, whatever the row looks like.
---
--- Only reachable once the row has been widened: min(left, right) tops out at
--- two in a five-slot row, and this mod hands out Joker slots freely. Read off
--- the card so a save carries it and the description cannot disagree with it;
--- the constant is the fallback for a card from before it existed.
CelestasMod.CALAMITAS_CAP = 4

--- How many times Calamitas retriggers each other Joker, from where it sits.
---
--- A card not in the row at all is nothing: this is asked of a Joker in the
--- shop and of the one in the Collection, and neither has a side.
function CelestasMod.calamitas_times(card)
    local extra = card and card.ability and card.ability.extra
    local cap = (extra and extra.max) or CelestasMod.CALAMITAS_CAP
    local row = G.jokers and G.jokers.cards
    if not row then return 0 end
    for i, held in ipairs(row) do
        if held == card then
            local side = math.min(i - 1, #row - i)
            -- Clamped, rather than handed to math.min as a third argument.
            -- Talisman replaces that function with a two-argument one
            -- (talisman.lua:482) and forwards only those two, so a third is
            -- dropped without a word - and Talisman is a dependency here, so
            -- the three-argument form never clamped anything in a real game.
            -- It shipped that way: "up to 4 times (Currently 9 times)".
            if side > cap then side = cap end
            return side
        end
    end
    return 0
end

SMODS.Joker {
    key = "calamitas",
    atlas = "calamitas",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = false,
    -- A copy sits somewhere else in the row and so counts a different pair of
    -- sides; what it would retrigger is not what this does.
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { max = CelestasMod.CALAMITAS_CAP } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.max,
                          CelestasMod.calamitas_times(card) } }
    end,

    calculate = function(self, card, context)
        -- retrigger_joker_check is asked of every Joker about every other
        -- Joker, so the answer has to name who it is being asked about, and
        -- Calamitas must refuse itself or it would retrigger its own answer.
        --
        -- `not context.retrigger_joker` is Bluto's guard, and this needs it far
        -- more: Bluto retriggers two named Jokers and this one retriggers the
        -- whole row, so a retrigger of a retrigger would compound without
        -- bound - two Calamitas either side of a third most of all.
        if not (context.retrigger_joker_check and not context.retrigger_joker
                and context.other_card and context.other_card ~= card) then
            return
        end

        local times = CelestasMod.calamitas_times(card)
        if times <= 0 then return end
        return {
            message = localize("k_again_ex"),
            repetitions = times,
            card = card,
        }
    end,
}


--------------------------------------------------------------------------------
-- Tobs [Uncommon] - a Eutrophic card copies more than two numbers.
--------------------------------------------------------------------------------
--
-- A Eutrophic card mimics the stored Chips and the stored Mult of the card it
-- is copying, and nothing else. Tobs widens that to the card's ENHANCEMENT -
-- its multipliers and the enhancement's own behaviour, run against the
-- Eutrophic card - and its EDITION.
--
-- None of that lives here. enhancements/enhancements.lua asks
-- CelestasMod.eutrophic_mimics_more at the moment a Eutrophic copies, which is
-- the one place the question arises, so this Joker only has to exist - the
-- same shape Sinder has for Driftwood and Meicha for wrap-around straights.

SMODS.Joker {
    key = "tobs",
    atlas = "tobs",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = false,
    -- A passive the enhancement reads for as long as it is in the row; there
    -- is no effect returned for a copy to return.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] =
            G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Eutrophic]
        return {}
    end,
}
