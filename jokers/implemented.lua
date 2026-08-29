--- Hand-written Jokers with real effects.
---
--- Anything defined here is EXCLUDED from the generated roster in
--- jokers/vtubers.lua, so move a joker into this file the moment it stops
--- being a placeholder. tools/gen_roster.py finds them by matching
--- `SMODS.Joker {` followed immediately by `key = "..."`, so keep `key` as the
--- first field of every definition.
---
--- Their localization in localization/en-us.lua is preserved across
--- regeneration too - the generator only ever appends missing entries.

--------------------------------------------------------------------------------
-- Arar [Common]
-- At the start of each round, add a random enhancement to a random
-- unenhanced card held in hand.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "arar",
    atlas = "arar",
    pos = { x = 0, y = 0 },

    rarity = 1,
    cost = 4,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
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
            local enhancement = SMODS.poll_enhancement {
                key = "celesta_arar_enh",
                guaranteed = true,
            }
            if not enhancement then return end

            target.celesta_arar_claimed = true
            G.E_MANAGER:add_event(Event {
                func = function()
                    target:set_ability(G.P_CENTERS[enhancement], nil, true)
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
    discovered = true,
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

                card.ability.extra.x_mult = card.ability.extra.x_mult
                    + card.ability.extra.x_mult_gain

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

        if context.joker_main and card.ability.extra.x_mult > 1 then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Kumi [Rare]
-- Destroys all scoring Gold cards in the played hand, with a 1 in 4 chance
-- to give $20 for each Gold card destroyed.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "kumi",
    atlas = "kumi",
    pos = { x = 0, y = 0 },

    rarity = 3,
    cost = 8,
    unlocked = true,
    discovered = true,
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
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { odds = 2, repetitions = 2 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_steel
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, card.ability.extra.odds, "celesta_maya")
        return { vars = { numerator, denominator, card.ability.extra.repetitions } }
    end,

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
    discovered = true,
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
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky
        return {}
    end,

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

    rarity = 2,
    cost = 6,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { mult = 0, mult_gain = 2 } },

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
                    played:set_ability(G.P_CENTERS.c_base, nil, true)
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

        if context.joker_main and card.ability.extra.mult > 0 then
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
    discovered = true,
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
    discovered = true,
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
-- Yuy_ix [Rare]
-- On the final hand of the round, each scoring card gives X1.5 Mult.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "yuy_ix",
    atlas = "yuy_ix",
    pos = { x = 0, y = 0 },

    rarity = 3,
    cost = 8,
    unlocked = true,
    discovered = true,
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
    discovered = true,
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

        if context.joker_main and card.ability.extra.mult > 0 then
            return { mult = card.ability.extra.mult }
        end

        -- context.main_eval is the once-per-round joker pass; without it this
        -- also fires during the per-card and repetition passes.
        if context.end_of_round and context.main_eval and not context.blueprint then
            if card.ability.extra.mult > 0 then
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
    unlocked = true,
    discovered = true,
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

--- IMPLEMENTED: cottontail, spite, fraiki, beepers
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
        key = "fraiki", seal = "Rose", cost = 6,
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
        unlocked = true,
        discovered = true,
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
    discovered = true,
    blueprint_compat = true,
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
    discovered = true,
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
-- and this scores nothing.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "ironmouse",
    atlas = "ironmouse",
    pos = { x = 0, y = 0 },

    rarity = 4,
    cost = 20,
    unlocked = true,
    discovered = true,
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
    unlocked = true, discovered = true,
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
                other:set_ability(G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Gash], nil, true)
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
-- Saruei [Common] - Gashed cards always break when scored.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "saruei",
    atlas = "saruei",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Gash]
        return {}
    end,

    calculate = function(self, card, context)
        -- fix_probability OVERRIDES the odds rather than nudging them, which is
        -- what "1 in 1" needs. Scoped by identifier so it only touches Gash's
        -- break roll and nothing else in the run.
        if context.fix_probability
            and context.identifier == CelestasMod.GASH_BREAK_ID then
            return { numerator = context.denominator }
        end
    end,
}

--------------------------------------------------------------------------------
-- Bao [Rare] - +5 Mult, or X5 Mult while a Downpour is running.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "bao",
    atlas = "bao",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
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

local YOMI_BASE_SUITS = { "Clubs", "Spades", "Diamonds", "Hearts" }

--- The suits Yomi rotates through.
---
--- Stars join the list only once the deck actually holds one. They are not
--- dealt at the start of a run - see suits/stars.lua - so a rotation that
--- could land on them beforehand would spend a whole round retriggering a suit
--- the player has no cards in.
---
--- Read off base.suit rather than through is_suit: is_suit routes through
--- SMODS.smeared_check, and Arielle widens that to match everything, which
--- would report Stars as present in every deck.
local function yomi_suits()
    if not CelestasMod.stars_in_deck() then return YOMI_BASE_SUITS end
    -- Appended, not prepended: the four keep the positions a saved suit_index
    -- already points at, so acquiring a Star card does not jump a Yomi that is
    -- part-way through the rotation onto a different suit. Stars are simply
    -- reached when it next wraps.
    local with_stars = {}
    for i, suit in ipairs(YOMI_BASE_SUITS) do with_stars[i] = suit end
    with_stars[#with_stars + 1] = CelestasMod.STARS_SUIT
    return with_stars
end

--- The suit at `index`, wrapped into range.
--- The list changes length when the first Star card arrives or the last one
--- leaves, so a saved index can point past the end; wrapping keeps it inside
--- the list rather than silently resetting the rotation to Clubs.
local function yomi_suit_at(suits, index)
    return suits[((index - 1) % #suits) + 1]
end

SMODS.Joker {
    key = "yomiquinnely",
    atlas = "yomiquinnely",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { suit_index = 1 } },

    loc_vars = function(self, info_queue, card)
        local suits = yomi_suits()
        return { vars = { localize(yomi_suit_at(suits, card.ability.extra.suit_index),
                                   "suits_plural") } }
    end,

    calculate = function(self, card, context)
        local suits = yomi_suits()
        local suit = yomi_suit_at(suits, card.ability.extra.suit_index)

        if context.repetition and context.cardarea == G.play then
            if context.other_card:is_suit(suit) then
                return { message = localize("k_again_ex"), repetitions = 1, card = card }
            end
        end

        -- main_eval keeps the rotation to once per round rather than once per
        -- card evaluated during the end-of-round pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            card.ability.extra.suit_index =
                (card.ability.extra.suit_index % #suits) + 1
            local next_suit = yomi_suit_at(suits, card.ability.extra.suit_index)
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
    if next(SMODS.find_card("j_celesta_arielle")) then return true end
    return smeared_check_ref(card, suit)
end

SMODS.Joker {
    key = "arielle",
    atlas = "arielle",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Deme [Rare] - X0.25 Mult per consecutive single-card hand.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "demenishki",
    atlas = "demenishki",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
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
                card.ability.extra.x_mult =
                    card.ability.extra.x_mult + card.ability.extra.x_mult_gain
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { card.ability.extra.x_mult } },
                    colour = G.C.MULT, card = card,
                }
            elseif card.ability.extra.x_mult > 1 then
                card.ability.extra.x_mult = 1
                return { message = localize("k_reset"), colour = G.C.RED, card = card }
            end
        end

        if context.joker_main and card.ability.extra.x_mult > 1 then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- MOTHERv3 [Rare] - after each hand, Exo a random unenhanced held card.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "motherv3",
    atlas = "motherv3",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
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
                    target:set_ability(G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Exo], nil, true)
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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 6 } },

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "celesta_shoomimi")
        return { vars = { n, d } }
    end,

    calculate = function(self, card, context)
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = true,

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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return { vars = { localize("Three of a Kind", "poker_hands") } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint
            and context.scoring_name == "Three of a Kind" then
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
local function cweamcat_repick(card)
    local hands = {}
    for k, _ in pairs(G.GAME.hands) do
        if SMODS.is_poker_hand_visible(k) then hands[#hands + 1] = k end
    end
    if #hands == 0 then return end
    local old = card.ability.extra.hand
    local pick = old
    for _ = 1, 10 do
        pick = pseudorandom_element(hands, pseudoseed("celesta_cweamcat"))
        if pick ~= old then break end
    end
    card.ability.extra.hand = pick
end

SMODS.Joker {
    key = "cweamcat",
    atlas = "cweamcat",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = true,
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
        cweamcat_repick(card)
    end,

    calculate = function(self, card, context)
        -- Check before scoring, reroll after, so the hand shown when you play
        -- is the one that counts.
        if context.before and not context.blueprint then
            if context.scoring_name == card.ability.extra.hand then
                card.ability.extra.chips =
                    card.ability.extra.chips + card.ability.extra.chip_gain
                return {
                    message = localize { type = "variable", key = "a_chips",
                                         vars = { card.ability.extra.chips } },
                    colour = G.C.CHIPS, card = card,
                }
            end
        end

        if context.after and not context.blueprint then
            cweamcat_repick(card)
            return
        end

        if context.joker_main and card.ability.extra.chips > 0 then
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
    unlocked = true, discovered = true,
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

local BLUTO_TARGETS = { j_blueprint = true, j_brainstorm = true }

SMODS.Joker {
    key = "bluto",
    atlas = "bluto",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
-- Nagzz [Uncommon] - halves every listed probability.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "nagzz",
    atlas = "nagzz",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
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
            return { denominator = (context.denominator or 1) * 2 }
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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 1, x_mult_gain = 0.2 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Gash]
        return { vars = { card.ability.extra.x_mult_gain, card.ability.extra.x_mult } }
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
                    ref_value = "x_mult",
                    scalar_value = "x_mult_gain",
                    message_key = "a_xmult",
                    message_colour = G.C.MULT,
                    operation = function(ref_table, ref_value, initial, scaling)
                        ref_table[ref_value] = initial + scaling * broken
                    end,
                })
            end
        end

        if context.joker_main and card.ability.extra.x_mult > 1 then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- x3Dustco [Legendary] - at the end of the shop, creates a Joker from this mod.
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
    unlocked = true, discovered = true,
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
            if #G.jokers.cards + (G.GAME.joker_buffer or 0)
                >= G.jokers.config.card_limit then
                return
            end

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
            G.GAME.joker_buffer = (G.GAME.joker_buffer or 0) + 1
            G.E_MANAGER:add_event(Event {
                func = function()
                    local made = SMODS.add_card { key = chosen }
                    if made then made:start_materialize() end
                    G.GAME.joker_buffer = 0
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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Limestone]
        return {}
    end,

    calculate = function(self, card, context)
        -- Same shape as vanilla Marble Joker: build it in G.play so the player
        -- sees it, then animate it into the deck.
        if context.setting_blind
            and not (context.blueprint_card or card).getting_sliced then
            G.E_MANAGER:add_event(Event {
                func = function()
                    local new_card = create_playing_card(
                        { front = pseudorandom_element(G.P_CARDS, pseudoseed("celesta_lime")),
                          center = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Limestone] },
                        G.play, nil, nil, { G.C.SECONDARY_SET.Enhanced })

                    SMODS.calculate_effect({
                        message = localize("celesta_plus_limestone"),
                        colour = G.C.SECONDARY_SET.Enhanced,
                    }, context.blueprint_card or card)

                    G.E_MANAGER:add_event(Event {
                        func = function()
                            draw_card(G.play, G.deck, 90, "up", nil)
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { odds = 2, dollars = 3 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Limestone]
        local n, d = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "celesta_yuzu")
        return { vars = { n, d, card.ability.extra.dollars } }
    end,

    calculate = function(self, card, context)
        -- The held-in-hand pass, which runs while a hand is being played.
        if context.individual and context.cardarea == G.hand then
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

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
-- Pomatomaster [Rare] - Exo... Eutrophic, on the lowest held card.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "pomatomaster",
    atlas = "pomatomaster",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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

            card.ability.extra.chips =
                card.ability.extra.chips + card.ability.extra.chip_gain
            return {
                remove = true,
                message = localize { type = "variable", key = "a_chips",
                                     vars = { card.ability.extra.chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        if context.joker_main and card.ability.extra.chips > 0 then
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
    if next(SMODS.find_card("j_celesta_meicha")) then return true end
    return wrap_around_straight_ref()
end

SMODS.Joker {
    key = "meicha",
    atlas = "meicha",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,
}

--------------------------------------------------------------------------------
-- AiCandii [Uncommon] - paid for the discards you did not need.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "aicandii",
    atlas = "aicandii",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
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

        if context.joker_main and card.ability.extra.mult > 0 then
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
-- Smug Alana [Rare] - melting ice takes a sticker with it.
--------------------------------------------------------------------------------
--
-- The strip itself lives in CelestasMod.thaw (editions/frozen.lua), so melting
-- has one definition wherever it is triggered from. This joker only has to
-- exist for that path to fire - it checks for it by key.

SMODS.Joker {
    key = "smugalana",
    atlas = "smugalana",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = true,

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
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
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
-- Multiplies every value your other Jokers produce by X1.5, and cannot be
-- copied.
--------------------------------------------------------------------------------

CelestasMod.VEDAL_SCALE = 1.5

-- Additive values are scaled directly: +4 Mult becomes +6 Mult.
local VEDAL_ADDITIVE = {
    "chips", "h_chips", "chip_mod",
    "mult", "h_mult", "mult_mod",
}

-- Multiplicative values have the multiplier itself scaled, so X3 Mult becomes
-- X4.5 Mult. Talisman exponential keys are here too, which makes Vedal
-- enormous in a Talisman run - that is the reading of "all values", but it is
-- the one list to cut from if it turns out to be too much.
local VEDAL_MULTIPLICATIVE = {
    "x_chips", "xchips", "Xchip_mod",
    "x_mult", "Xmult", "xmult", "x_mult_mod", "Xmult_mod",
    "e_mult", "emult", "e_chips", "echips",
}

--- True when a Vedal is in play and not debuffed.
local function vedal_active()
    for _, joker in ipairs(SMODS.find_card("j_celesta_vedal")) do
        if not joker.debuff then return true end
    end
    return false
end

--- Cheap pre-check, so the common case costs a handful of table lookups.
--- Nearly every joker evaluation returns a table with nothing scalable in it,
--- and this hook sits on the hottest path in the game - the same path that
--- once locked the game up mid-score.
local function vedal_has_target(effect)
    for _, key in ipairs(VEDAL_ADDITIVE) do
        local v = effect[key]
        if type(v) == "number" and v ~= 0 then return true end
    end
    for _, key in ipairs(VEDAL_MULTIPLICATIVE) do
        local v = effect[key]
        -- 1 is the identity for a multiplier. Scaling it would conjure X1.5
        -- out of a joker that was explicitly contributing nothing.
        if type(v) == "number" and v > 1 then return true end
    end
    return false
end

local celesta_vedal_calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context, ...)
    local effect, post = celesta_vedal_calculate_joker_ref(self, context, ...)

    -- Only the outermost evaluation is scaled. SMODS.blueprint_effect runs the
    -- copied joker with context.blueprint set and then hands that same table
    -- back up through the copier own calculate_joker, where context.blueprint
    -- is nil again. Scaling both would apply X1.5 twice per copy.
    if type(effect) ~= "table" or context.blueprint then return effect, post end
    if self.ability.set ~= "Joker" then return effect, post end
    if self.config.center.key == "j_celesta_vedal" then return effect, post end
    -- This mod's Jokers only. Reaching into other mods' Jokers meant reaching
    -- into machinery this cannot see: Compound Interest scales inside
    -- calc_dollar_bonus rather than calculate, and froze while Vedal was out.
    -- Rather than keep guessing at how a boost here reaches a scale there,
    -- Vedal now stays within what this mod owns, and says so on the card.
    if not CelestasMod.is_ours(self.config.center) then return effect, post end
    if not vedal_has_target(effect) then return effect, post end
    if not vedal_active() then return effect, post end

    -- Scaled onto a copy rather than in place: a joker is free to return its
    -- own ability table, and scaling that would permanently inflate its stats
    -- instead of this one trigger.
    local scaled = {}
    for k, v in pairs(effect) do scaled[k] = v end
    local mult = CelestasMod.VEDAL_SCALE
    for _, key in ipairs(VEDAL_ADDITIVE) do
        local v = scaled[key]
        if type(v) == "number" and v ~= 0 then scaled[key] = v * mult end
    end
    for _, key in ipairs(VEDAL_MULTIPLICATIVE) do
        local v = scaled[key]
        if type(v) == "number" and v > 1 then scaled[key] = v * mult end
    end
    return scaled, post
end

--------------------------------------------------------------------------------
-- Showing the boost on the Jokers it boosts
--------------------------------------------------------------------------------

-- Vedal changes what a Joker SCORES, and nothing about that reaches the
-- Joker's tooltip - so a boosted Bloodstone still advertised X1.5 while paying
-- X2.25, and a scaling Joker's "(Currently ...)" line never moved.
--
-- The hard part is knowing WHICH number to scale. A joker's loc_vars is an
-- unlabelled ordered list: Bloodstone's is
--     { probabilities.normal, extra.odds, extra.Xmult }   -- 2, 2, 1.5
-- and only the third may move. Scaling all three turns "2 in 2 chance" into
-- "3 in 3", which is both wrong and meaningless.
--
-- The description text is what disambiguates them. Balatro marks every number
-- with the colour it prints in, and a value Vedal touches is always written in
-- mult or chip markup:
--     "{X:mult,C:white}X#3#{} Mult"        -> scale
--     "{C:chips}+#1#{} Chips"              -> scale
--     "{C:green}#1# in #2#{} chance"       -> leave alone
--     "{C:attention}#1#{} cards"           -> leave alone
-- So the markup immediately before each #n# decides it.

-- Steamodded patches generate_card_ui to take a NINTH argument, the card being
-- described (lovely/center.toml). That is both how this knows whose tooltip it
-- is looking at, and a trap: a wrapper declaring the stock eight silently drops
-- it, and the game crashes indexing a nil card on the next hover. Everything
-- past the arguments actually used is forwarded untouched, so another one
-- appearing cannot break this again.
local celesta_vedal_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges,
                          hide_desc, main_start, main_end, card, ...)
    -- Only Jokers actually in the row: one in the shop is not owned yet, and
    -- advertising a boost it will not get until bought would be a lie.
    if not (card and card.area == G.jokers
        and type(_c) == "table" and _c.set == "Joker"
        and _c.key ~= "j_celesta_vedal"
        and CelestasMod.is_ours(_c)
        and type(specific_vars) == "table" and type(specific_vars.vars) == "table"
        and vedal_active()) then
        return celesta_vedal_card_ui_ref(_c, full_UI_table, specific_vars, card_type,
                                         badges, hide_desc, main_start, main_end,
                                         card, ...)
    end

    local marked = CelestasMod.scalable_vars(_c.set, _c.key)
    if marked then
        local copy = {}
        for k, v in pairs(specific_vars) do copy[k] = v end
        copy.vars = CelestasMod.scale_vars(specific_vars.vars, marked,
                                           CelestasMod.VEDAL_SCALE)
        specific_vars = copy
    end

    return celesta_vedal_card_ui_ref(_c, full_UI_table, specific_vars, card_type,
                                     badges, hide_desc, main_start, main_end,
                                     card, ...)
end

SMODS.Joker {
    key = "vedal",
    atlas = "vedal",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = true,
    -- The one joker in the mod that opts out of copying, per its own text.
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { x_value = 1.5 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_value } }
    end,
}

--------------------------------------------------------------------------------
-- Liffeh [Common]
-- 1 in 4 chance to gain an extra Tarot card whenever you gain one.
--------------------------------------------------------------------------------

CelestasMod.LIFFEH_ODDS = 4

-- Set while the bonus Tarot is being created, so the bonus cannot roll a
-- bonus of its own.
local liffeh_creating = false

--- The first Liffeh in play that is able to act.
local function liffeh_active()
    for _, joker in ipairs(SMODS.find_card("j_celesta_liffeh")) do
        if not joker.debuff then return joker end
    end
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

    -- Same room check vanilla makes before creating a Tarot. consumeable_buffer
    -- reserves the slot across the event boundary so two sources cannot both
    -- claim the last one.
    local buffer = G.GAME.consumeable_buffer or 0
    if #G.consumeables.cards + buffer >= G.consumeables.config.card_limit then return end

    if not SMODS.pseudorandom_probability(
        liffeh, "celesta_liffeh", 1, CelestasMod.LIFFEH_ODDS, "celesta_liffeh") then
        return
    end

    G.GAME.consumeable_buffer = buffer + 1
    G.E_MANAGER:add_event(Event {
        trigger = "before",
        delay = 0.0,
        func = function()
            liffeh_creating = true
            -- A random Tarot rather than a copy of the one that triggered it:
            -- "an extra Tarot card", the way a purple seal gives one.
            local extra = create_card("Tarot", G.consumeables, nil, nil, nil, nil,
                                      nil, "celesta_liffeh")
            extra:add_to_deck()
            G.consumeables:emplace(extra)
            liffeh_creating = false
            G.GAME.consumeable_buffer = math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
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
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = true,

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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
            and not mintfantome_scoring then
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
    unlocked = true, discovered = true,
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

SMODS.Joker {
    key = "axialmatt",
    atlas = "axialmatt",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { rank_mult = 2 } },

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- The held-in-hand pass, and h_mult rather than mult, because that is
        -- where Raised Fist lives: the Mult pops on the raised card as the
        -- hand is read rather than with the joker row afterwards.
        if context.individual and context.cardarea == G.hand then
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
--- The exclusion is what makes this correct from both callbacks, because
--- vanilla is not symmetric about when the card is in G.jokers:
---   * bought      - add_to_deck runs BEFORE emplace, so it is not in the area
---   * un-debuffed - add_to_deck runs while self.debuff is still true
---   * sold        - Card:remove strips it from the area BEFORE remove_from_deck
---   * debuffed    - remove_from_deck runs while self.debuff is still false
--- Excluding the card in question makes all four read "everyone else", and
--- the caller adds one back when the card is arriving.
local function haruka_count(excluding)
    local n = 0
    for _, joker in ipairs(G.jokers and G.jokers.cards or {}) do
        if joker ~= excluding and not joker.debuff
            and joker.config.center.key == HARUKA_KEY then
            n = n + 1
        end
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
            card.ability.extra.chips =
                card.ability.extra.chips + card.ability.extra.chip_mod
            return {
                message = localize("k_upgrade_ex"),
                card = card,
                colour = G.C.CHIPS,
            }
        end

        if context.joker_main and card.ability.extra.chips > 0 then
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
    unlocked = true, discovered = true,
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
                card.ability.extra.x_mult =
                    card.ability.extra.x_mult + card.ability.extra.x_mult_gain * moved
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { card.ability.extra.x_mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and card.ability.extra.x_mult > 1 then
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    -- bank is the chips carried toward the next step, so a hand of 15 chips
    -- pays once and leaves 5 behind rather than throwing the remainder away.
    config = { extra = { mult = 0, mult_gain = 10, chips_per_step = 32, bank = 0 } },

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

        if context.joker_main and card.ability.extra.mult > 0 then
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
    for _, joker in ipairs(SMODS.find_card("j_celesta_radicalmari")) do
        if not joker.debuff then return true end
    end
    return false
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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

--- Everything needed to rebuild a playing card, as plain strings.
--- Stored on the joker and therefore serialized into the save, so it has to
--- survive a reload with no live references in it.
function CelestasMod.snapshot_card(card)
    if not (card and card.base) then return nil end
    return {
        suit = card.base.suit,
        value = card.base.value,
        center = card.config and card.config.center_key or "c_base",
        edition = card.edition and card.edition.key or "none",
        seal = card.seal,
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
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = true,

    config = { extra = {} },

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- Taken on the destroy pass rather than before scoring. A card pulled
        -- out from under evaluate_play mid-hand leaves the scoring loop
        -- holding a card that is no longer there; the destroy pass exists
        -- precisely for removing scored cards and runs once scoring is done.
        -- The card pays out for the hand that consumes it.
        if context.destroying_card and context.cardarea == G.play
            and not context.blueprint
            and G.GAME.current_round.hands_played == 0
            and context.full_hand and #context.full_hand == 1
            and context.destroying_card == context.full_hand[1] then
            local doomed = context.destroying_card
            -- Eternal cards refuse destruction, and taking one would strand
            -- the snapshot forever.
            if SMODS.is_eternal and SMODS.is_eternal(doomed) then return end

            card.ability.extra.stored = CelestasMod.snapshot_card(doomed)
            return {
                remove = true,
                message = localize("celesta_taken"),
                colour = G.C.PURPLE,
                card = card,
            }
        end

        -- Handed back when the next blind is picked.
        if context.setting_blind and card.ability.extra.stored
            and not (context.blueprint_card or card).getting_sliced then
            local stored = card.ability.extra.stored
            card.ability.extra.stored = nil

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

                    local upgraded = CelestasMod.EDITION_LADDER[stored.edition or "none"]
                    if upgraded then restored:set_edition(upgraded, true, true) end
                    if stored.seal then restored:set_seal(stored.seal, true) end

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
    end,
}

--------------------------------------------------------------------------------
-- Milk Bottle — permanent Chips on the cards you pick
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
-- Moo Merrily [Uncommon] - a Milk Bottle every round.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "moomerrily",
    atlas = "moomerrily",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
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
local function clover_count(excluding)
    local n = 0
    for _, joker in ipairs(G.jokers and G.jokers.cards or {}) do
        if joker ~= excluding and not joker.debuff
            and joker.config.center.key == "j_celesta_clover" then
            n = n + 1
        end
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
    -- Cosmic is this mod's Star-suit equivalent of the vanilla four, so Ray
    -- treats it the same way.
    j_celesta_cosmic = true,
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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

            card.ability.extra.chips =
                card.ability.extra.chips + card.ability.extra.chip_mod
            return {
                message = localize { type = "variable", key = "a_chips",
                                     vars = { card.ability.extra.chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        if context.joker_main and card.ability.extra.chips > 0 then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- FeFe [Uncommon] - the scoring cards all turn to Hearts.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "fefe",
    atlas = "fefe",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- context.before runs after the poker hand has been named but before
        -- any card scores, so the conversion lands in time for every suit
        -- check during scoring - Bloodstone, a Lusty Joker, a flush-suit
        -- Blind - without retroactively rewriting which hand was played.
        if context.before and not context.blueprint then
            local scoring = context.scoring_hand
            if type(scoring) ~= "table" then return end

            local converted = 0
            for _, played in ipairs(scoring) do
                -- A card with no suit has none to convert. Stone Cards and
                -- Limestone report through has_no_suit, and changing their
                -- base would hand them one they are not supposed to have.
                if not SMODS.has_no_suit(played) and not played:is_suit("Hearts") then
                    local target = played
                    G.E_MANAGER:add_event(Event {
                        func = function()
                            SMODS.change_base(target, "Hearts")
                            return true
                        end
                    })
                    converted = converted + 1
                end
            end

            if converted > 0 then
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
local function milky_active(excluding)
    for _, joker in ipairs(G.jokers and G.jokers.cards or {}) do
        if joker ~= excluding and not joker.debuff
            and joker.config.center.key == "j_celesta_milky" then
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
    unlocked = true, discovered = true,
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
-- Four Jokers that differ only in which suit they name, so the behaviour is
-- written once. See FeFe above for why this runs on context.before.

--- Converts every scoring card that has a suit to `suit`.
--- Returns how many were changed, so the caller can stay quiet when the hand
--- was already that suit.
local function convert_scoring_to(context, suit)
    local scoring = context.scoring_hand
    if type(scoring) ~= "table" then return 0 end

    local converted = 0
    for _, played in ipairs(scoring) do
        -- A card with no suit has none to convert. Stone Cards and Limestone
        -- report through has_no_suit, and changing their base would hand them
        -- one they are not supposed to have.
        if not SMODS.has_no_suit(played) and not played:is_suit(suit) then
            local target = played
            G.E_MANAGER:add_event(Event {
                func = function()
                    SMODS.change_base(target, suit)
                    return true
                end
            })
            converted = converted + 1
        end
    end
    return converted
end

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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,
    loc_vars = function(self, info_queue, card) return {} end,
    calculate = converter_calculate("Spades", G.C.SPADES, "celesta_spades"),
}

SMODS.Joker {
    key = "ebiko",
    atlas = "ebiko",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,
    loc_vars = function(self, info_queue, card) return {} end,
    calculate = converter_calculate("Diamonds", G.C.DIAMONDS, "celesta_diamonds"),
}

SMODS.Joker {
    key = "nihmune",
    atlas = "nihmune",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,
    loc_vars = function(self, info_queue, card) return {} end,
    calculate = converter_calculate("Clubs", G.C.CLUBS, "celesta_clubs"),
}

--------------------------------------------------------------------------------
-- Eros [Uncommon] - eats Bonus enhancements, keeps the Chips.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "eros",
    atlas = "eros",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { chips = 0, chip_gain = 15 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_bonus
        return { vars = { card.ability.extra.chip_gain, card.ability.extra.chips } }
    end,

    calculate = function(self, card, context)
        -- Same shape as LaynaLazar, and as vanilla Vampire: context.before, so
        -- the enhancement is stripped before the hand scores and those cards
        -- do not pay their Chips this hand. scoring_hand is only populated here.
        if context.before and not context.blueprint then
            local removed = {}
            for _, played in ipairs(context.scoring_hand) do
                if SMODS.has_enhancement(played, "m_bonus")
                    and not played.debuff
                    and not played.celesta_stripped then
                    removed[#removed + 1] = played
                    -- The flag stops a copier stripping the same card twice in
                    -- one pass: set_ability is deferred into an event, so the
                    -- second look would still see the enhancement.
                    played.celesta_stripped = true
                    played:set_ability(G.P_CENTERS.c_base, nil, true)
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
                SMODS.scale_card(card, {
                    ref_table = card.ability.extra,
                    ref_value = "chips",
                    scalar_value = "chip_gain",
                    message_key = "a_chips",
                    message_colour = G.C.CHIPS,
                    operation = function(ref_table, ref_value, initial, scaling)
                        ref_table[ref_value] = initial + scaling * #removed
                    end
                })
            end
        end

        if context.joker_main and card.ability.extra.chips > 0 then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- Sinder [Uncommon] - Driftwood stops breaking.
--------------------------------------------------------------------------------

-- The behaviour lives on the Driftwood enhancement, which asks
-- CelestasMod.sinder_active() before rolling. This Joker only has to exist.
SMODS.Joker {
    key = "sinder",
    atlas = "sinder",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    -- Nothing to copy: it is a passive the enhancement reads, not a trigger.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] =
            G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Driftwood]
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Suto [Rare] - the whole played hand turns Wild.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "suto",
    atlas = "suto",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

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
                    target:set_ability(G.P_CENTERS.m_wild, nil, true)
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
                    message = localize("k_plus_enhancement"),
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
-- Kirana [Rare] - paid for holding 3s.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "kirana",
    atlas = "kirana",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
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
-- Same approach as Driftwood counting as any rank, and for the same reason:
-- rank is not resolved in one place, so rather than teach get_X_same and
-- get_straight about a card that is two ranks at once, the rank is rewritten
-- BEFORE evaluation and put back afterwards. Every hand type then works with
-- no changes to any evaluator.
--
-- Only the hand evaluation is affected. A King keeps its own printed rank
-- everywhere else, is still a face card to Pareidolia and its friends, and
-- scores the ten Chips it already scored.

--- True when a Kael is in play and able to act.
local function kael_active()
    for _, joker in ipairs(SMODS.find_card("j_celesta_kael")) do
        if not joker.debuff then return true end
    end
    return false
end

local celesta_kael_evaluate_ref = evaluate_poker_hand
function evaluate_poker_hand(hand)
    if not kael_active() then return celesta_kael_evaluate_ref(hand) end

    local ten = SMODS.Ranks["10"]
    if not ten then return celesta_kael_evaluate_ref(hand) end

    local faces, saved = {}, {}
    for _, card in ipairs(hand or {}) do
        if card.is_face and card:is_face() and not SMODS.has_no_rank(card) then
            faces[#faces + 1] = card
            -- base.value matters as well as base.id: get_straight looks ranks
            -- up by key, not by numeric id.
            saved[#saved + 1] = { id = card.base.id, value = card.base.value }
        end
    end
    if #faces == 0 then return celesta_kael_evaluate_ref(hand) end

    for _, card in ipairs(faces) do
        card.base.id, card.base.value = ten.id, "10"
    end
    local results = celesta_kael_evaluate_ref(hand)
    for i, card in ipairs(faces) do
        card.base.id, card.base.value = saved[i].id, saved[i].value
    end
    return results
end

SMODS.Joker {
    key = "kael",
    atlas = "kael",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    -- A passive the evaluator reads, not a trigger; there is nothing to copy.
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
    unlocked = true, discovered = true,
    -- Copyable, like Blueprint is: a Blueprint next to this one copies it and
    -- ends up pointed at the same rightmost Joker.
    blueprint_compat = true, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        local target = G.jokers and G.jokers.cards and G.jokers.cards[#G.jokers.cards]
        if target and target ~= card then
            info_queue[#info_queue + 1] = target.config.center
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
    unlocked = true, discovered = true,
    -- A copy would grant a second set of the same slots, which the reset
    -- below could not take back off: the amount applied lives on this card.
    blueprint_compat = false, eternal_compat = true,

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
    add_to_deck = function(self, card, from_debuff)
        local round = G.GAME and G.GAME.current_round
        local used = round and round.discards_used or 0
        card.ability.extra.applied = 0
        self:celesta_resize(card, used * card.ability.extra.h_size)
    end,

    remove_from_deck = function(self, card, from_debuff)
        self:celesta_resize(card, 0)
    end,
}

--------------------------------------------------------------------------------
-- Sansin [Uncommon] - the deck wears out half as fast.
--------------------------------------------------------------------------------

-- The behaviour lives in wear/tattered.lua, which asks Tattered.wear_delay()
-- each time it counts a score. This Joker only has to exist.
SMODS.Joker {
    key = "sansin",
    atlas = "sansin",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
local function star_name_and_colour()
    return localize(CelestasMod.STARS_SUIT, "suits_plural"),
           (G.C.SUITS or {})[CelestasMod.STARS_SUIT]
               or HEX(CelestasMod.STARS_COLOUR)
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

--------------------------------------------------------------------------------
-- Cosmic [Common] - the plain one.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "cosmic",
    atlas = "cosmic",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
    unlocked = true, discovered = true,
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
-- silently - so it is asked about here and says so once if it is missing.
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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
    unlocked = true, discovered = true,
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

        if context.joker_main and card.ability.extra.chips > 0 then
            return { chips = card.ability.extra.chips }
        end
    end,
}

--------------------------------------------------------------------------------
-- SonneFlower [Uncommon] - grows on Diamonds, and only on Diamonds.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "sonneflower",
    atlas = "sonneflower",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { x_mult = 1, x_mult_gain = 0.25 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_mult_gain, card.ability.extra.x_mult } }
    end,

    calculate = function(self, card, context)
        -- context.before is the one pass that sees the whole scoring hand
        -- before any of it scores, so the decision is made once per hand
        -- rather than once per card.
        if context.before and not context.blueprint then
            local diamond = false
            for _, played in ipairs(context.scoring_hand or {}) do
                if played:is_suit("Diamonds") then diamond = true break end
            end

            if diamond then
                card.ability.extra.x_mult =
                    card.ability.extra.x_mult + card.ability.extra.x_mult_gain
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { card.ability.extra.x_mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end

            -- Reset only when there is something to lose, so a run of
            -- Diamond-less hands does not announce a reset every time.
            if card.ability.extra.x_mult > 1 then
                card.ability.extra.x_mult = 1
                return {
                    message = localize("k_reset"),
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and card.ability.extra.x_mult > 1 then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Taehoongie [Uncommon] - one of every suit.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "taehoongie",
    atlas = "taehoongie",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { levels = 1 } },

    in_pool = star_gated,

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
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

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
local YOKA_LEAVE_ALONE = {
    odds = true, repetitions = true, perma_repetitions = true,
    perish_tally = true, cry_prob = true,
    -- this mod's own bookkeeping
    applied = true, bank = true, suit_index = true, last_round = true,
    needed = true, levels = true,
}

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
local function yoka_scale(target, scale)
    local ability = target and target.ability
    if type(ability) ~= "table" then return false end
    if not yoka_may_change(target) then return false end

    if type(Cryptid) == "table" and type(Cryptid.manipulate) == "function" then
        local ok = pcall(Cryptid.manipulate, target, { value = scale })
        if ok then return true end
        CelestasMod.warn_once("yoka_manipulate",
            "Yoka Siri could not use Cryptid.manipulate; scaling by hand instead")
    end

    local changed = 0

    local extra = ability.extra
    if type(extra) == "table" then
        for key, value in pairs(extra) do
            if type(value) == "number" and not YOKA_LEAVE_ALONE[key]
                and not yoka_neutral(key, value) then
                extra[key] = value * scale
                changed = changed + 1
            end
        end
    end

    -- Iterated over the allowlist rather than over the table, so a field
    -- vanilla adds later cannot quietly start being scaled.
    for key in pairs(YOKA_FLAT_VALUES) do
        local value = ability[key]
        if type(value) == "number" and value ~= 0
            and not yoka_neutral(key, value) then
            ability[key] = value * scale
            changed = changed + 1
        end
    end

    return changed > 0
end

SMODS.Joker {
    key = "yokasiri",
    atlas = "yokasiri",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 9,
    unlocked = true, discovered = true,
    -- A copy would multiply the same neighbour a second time.
    blueprint_compat = false, eternal_compat = true,

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

            if yoka_scale(target, card.ability.extra.scale) then
                target:juice_up(0.4, 0.5)
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { card.ability.extra.scale } },
                    colour = G.C.MULT,
                    card = card,
                }
            end
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
    unlocked = true, discovered = true,
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
    for _, joker in ipairs(SMODS.find_card(key)) do
        if not joker.debuff then return true end
    end
    return false
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
    unlocked = true, discovered = true,
    -- The work happens at the Seal, not here; there is no trigger to copy.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_SEALS.Blue
        return {}
    end,
}

SMODS.Joker {
    key = "glowypumpkin",
    atlas = "glowypumpkin",
    pos = { x = 0, y = 0 },
    rarity = 4, cost = 20,
    unlocked = true, discovered = true,
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

SMODS.Joker {
    key = "fenari",
    atlas = "fenari",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 9,
    unlocked = true, discovered = true,
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

            card.ability.extra.x_mult =
                card.ability.extra.x_mult + card.ability.extra.x_mult_gain
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { card.ability.extra.x_mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        if context.joker_main and card.ability.extra.x_mult > 1 then
            return { x_mult = card.ability.extra.x_mult }
        end
    end,
}

--------------------------------------------------------------------------------
-- Geega [Rare] - a debuffed Joker is worth something after all.
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
    rarity = 3, cost = 9,
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.e_negative
        return {}
    end,
}

--------------------------------------------------------------------------------
-- Cerber [Uncommon] - the biggest card goes round again.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "cerbervt",
    atlas = "cerbervt",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { repetitions = 2 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.repetitions } }
    end,

    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play
            and context.other_card then
            local scoring = context.scoring_hand
            if type(scoring) ~= "table" then return end

            -- A Stone Card has no rank to be the highest. Ties go to the LAST
            -- such card, so exactly one card is picked however many share the
            -- rank - the same rule Chibidoki uses for the lowest.
            local highest
            for _, played in ipairs(scoring) do
                if not SMODS.has_no_rank(played) then
                    if not highest or played:get_id() >= highest:get_id() then
                        highest = played
                    end
                end
            end

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
    unlocked = true, discovered = true,
    -- Answering a question twice does not answer it harder.
    blueprint_compat = false, eternal_compat = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        if context.modify_scoring_hand and context.other_card
            and context.other_card.celesta_played_flipped then
            return { add_to_hand = true }
        end
    end,
}
