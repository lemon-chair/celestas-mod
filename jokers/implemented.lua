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

local YOMI_SUITS = { "Clubs", "Spades", "Diamonds", "Hearts" }

SMODS.Joker {
    key = "yomiquinnely",
    atlas = "yomiquinnely",
    pos = { x = 0, y = 0 },
    rarity = 2, cost = 6,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true,

    config = { extra = { suit_index = 1 } },

    loc_vars = function(self, info_queue, card)
        local suit = YOMI_SUITS[card.ability.extra.suit_index] or YOMI_SUITS[1]
        return { vars = { localize(suit, "suits_plural") } }
    end,

    calculate = function(self, card, context)
        local suit = YOMI_SUITS[card.ability.extra.suit_index] or YOMI_SUITS[1]

        if context.repetition and context.cardarea == G.play then
            if context.other_card:is_suit(suit) then
                return { message = localize("k_again_ex"), repetitions = 1, card = card }
            end
        end

        -- main_eval keeps the rotation to once per round rather than once per
        -- card evaluated during the end-of-round pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            card.ability.extra.suit_index =
                (card.ability.extra.suit_index % #YOMI_SUITS) + 1
            local next_suit = YOMI_SUITS[card.ability.extra.suit_index]
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
-- Dejavudea [Uncommon] - halves every listed probability.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "dejavudea",
    atlas = "dejavudea",
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

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- main_eval keeps this to the single once-per-round joker pass rather
        -- than firing again for every card evaluated at end of round.
        if context.end_of_round and context.main_eval and not context.blueprint then
            if not G.hand then return end
            local doomed = {}
            for _, held in ipairs(G.hand.cards) do
                if held.config.center == G.P_CENTERS.c_base then
                    doomed[#doomed + 1] = held
                end
            end
            if #doomed == 0 then return end

            G.E_MANAGER:add_event(Event {
                func = function()
                    -- destroy_cards respects eternal and animates the removal.
                    SMODS.destroy_cards(doomed)
                    return true
                end
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
-- AiCandii [Common] - paid for the discards you did not need.
--------------------------------------------------------------------------------

SMODS.Joker {
    key = "aicandii",
    atlas = "aicandii",
    pos = { x = 0, y = 0 },
    rarity = 1, cost = 5,
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
function Card:calculate_joker(context)
    local effect, post = celesta_vedal_calculate_joker_ref(self, context)

    -- Only the outermost evaluation is scaled. SMODS.blueprint_effect runs the
    -- copied joker with context.blueprint set and then hands that same table
    -- back up through the copier own calculate_joker, where context.blueprint
    -- is nil again. Scaling both would apply X1.5 twice per copy.
    if type(effect) ~= "table" or context.blueprint then return effect, post end
    if self.ability.set ~= "Joker" then return effect, post end
    if self.config.center.key == "j_celesta_vedal" then return effect, post end
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
