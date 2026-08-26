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
-- Removes Mult enhancements from scoring cards; gains +4 permanent Mult
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
-- Megalodon [Uncommon]
-- Gains +5 Mult for each card in the played hand. Resets at end of round.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "megalodon",
    atlas = "megalodon",
    pos = { x = 0, y = 0 },

    rarity = 2,
    cost = 6,
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

    rarity = 3,
    cost = 9,
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
