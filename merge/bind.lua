--- BIND — merging two Jokers into one
---
--- Bind is a Spectral card. Highlight two Jokers, use it, and they become a
--- single Joker occupying one slot that does everything both of them did.
---
--- The merged card keeps the LEFT Joker as its host: that card stays in the
--- row, keeps its position and its center, and carries the right-hand Joker's
--- center key and ability table in card.ability.celesta_bind. Nothing new is
--- created, so eternal stickers, sell value and every other per-card thing
--- have an obvious home.
---
--- Editions follow the rule as given:
---   * neither has one          -> the merge has none
---   * exactly one has one      -> 50% chance to keep it
---   * both have the SAME one   -> always kept
---   * both have DIFFERENT ones -> 50/50 between the two

CelestasMod.Bind = {}
local Bind = CelestasMod.Bind

local BIND_SEED = "celesta_bind"

-- Resolved at load: SMODS.current_mod is only valid while the mod is loading,
-- and the draw hook below runs every frame long afterwards.
local PREFIX = SMODS.current_mod.prefix

-- The Spectral card's own key, for the Jokers that want to point a tooltip at
-- it. Built here for the same reason: the prefix is only readable at load.
CelestasMod.BIND_KEY = "c_" .. PREFIX .. "_bind"

-- The glow along the split and around the border. One definition, so the two
-- can never drift apart.
--
-- Drawn as three passes rather than one stroke: widest and faintest first,
-- narrowest and solid last, so the white core sits inside a soft halo. A
-- single 2px line is not a glow - it reads as a grey hairline once the card is
-- scaled down to its place on the board.
--
-- Widths are in units of 1/71st of the card, so the 1x and 2x sheets glow
-- identically instead of the 2x looking half as thick.
Bind.GLOW = { 1, 1, 1 }
Bind.GLOW_PASSES = {
    { width = 5.0, alpha = 0.16 },
    { width = 2.6, alpha = 0.38 },
    { width = 1.2, alpha = 1.00 },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function Bind.is_merged(card)
    return card and card.ability and type(card.ability.celesta_bind) == "table"
        and card.ability.celesta_bind.key ~= nil
end

--- The centre of the Joker bound into this one.
function Bind.partner_center(card)
    if not Bind.is_merged(card) then return nil end
    return G.P_CENTERS[card.ability.celesta_bind.key]
end

--- True for a Joker that Bind is willing to take as an ingredient.
--- A merged Joker is refused: merging merges would nest indefinitely, and the
--- art has exactly two halves.
function Bind.can_bind(card)
    if not (card and card.ability and card.config and card.config.center) then return false end
    if card.ability.set ~= "Joker" then return false end
    if Bind.is_merged(card) then return false end
    return true
end

--- The two highlighted Jokers, or nil when the selection is not exactly two
--- bindable ones.
function Bind.selection()
    if not (G.jokers and G.jokers.highlighted) then return nil end
    local picked = {}
    for _, joker in ipairs(G.jokers.highlighted) do
        if not Bind.can_bind(joker) then return nil end
        picked[#picked + 1] = joker
    end
    if #picked ~= 2 then return nil end
    return picked
end

--------------------------------------------------------------------------------
-- Editions
--------------------------------------------------------------------------------

--- Resolves which edition, if any, survives the merge.
--- Split out so the rule is readable on its own and testable without a board.
function Bind.resolve_edition(edition_a, edition_b)
    local function coin(id)
        local ok, roll = pcall(pseudorandom, pseudoseed(BIND_SEED .. "_" .. id))
        -- A roll that errored keeps the edition: losing one to an error is
        -- worse for the player than keeping one.
        return (not ok) or roll < 0.5
    end

    if not edition_a and not edition_b then return nil end

    if edition_a and edition_b then
        -- Matching editions are never lost.
        if edition_a.key == edition_b.key then return edition_a end
        -- Otherwise a straight 50/50 between the two; neither can be dropped.
        return coin("which") and edition_a or edition_b
    end

    -- Exactly one edition in play: half the time it carries over.
    local lone = edition_a or edition_b
    return coin("keep") and lone or nil
end

--------------------------------------------------------------------------------
-- The merge
--------------------------------------------------------------------------------

--- Folds `absorbed` into `host` and removes it from the Joker row.
function Bind.merge(host, absorbed)
    if not (Bind.can_bind(host) and Bind.can_bind(absorbed)) then return false end

    local edition = Bind.resolve_edition(host.edition, absorbed.edition)

    -- Copied, not referenced: the absorbed card is about to be destroyed, and
    -- a Joker that scales itself needs somewhere of its own to keep growing.
    local carried = copy_table(absorbed.ability)
    if type(absorbed.ability.extra) == "table" then
        -- copy_table is shallow, and `extra` is the table effects actually
        -- mutate, so it needs a copy of its own.
        carried.extra = copy_table(absorbed.ability.extra)
    end
    -- Cannot survive on the absorbed half: it would let a merge be merged.
    carried.celesta_bind = nil

    host.ability.celesta_bind = {
        key = absorbed.config.center_key or absorbed.config.center.key,
        ability = carried,
    }

    -- The stickers are inherited rather than dropped, so a merge cannot be
    -- used to launder an Eternal Joker into a sellable one.
    for _, sticker in ipairs({ "eternal", "perishable", "rental" }) do
        if absorbed.ability[sticker] then host.ability[sticker] = absorbed.ability[sticker] end
    end
    if absorbed.ability.perish_tally and (not host.ability.perish_tally
        or absorbed.ability.perish_tally < host.ability.perish_tally) then
        host.ability.perish_tally = absorbed.ability.perish_tally
    end

    host:set_edition(edition, true, true)

    -- Cryptid's face-down flag has no meaning on a card whose whole point is
    -- showing two faces, and the spec rules it out outright.
    host.cry_flipped = nil

    -- One card now does two jobs, so it is worth what both were worth. Each
    -- half's own cost is kept, so a later unmerge can hand the survivor back
    -- what it was worth rather than guessing at half the total.
    host.ability.celesta_bind.host_sell_cost = host.sell_cost
    host.ability.celesta_bind.sell_cost = absorbed.sell_cost
    host.sell_cost = (host.sell_cost or 0) + (absorbed.sell_cost or 0)

    Bind.invalidate_art(host)

    -- Defined further down, with the rest of the hooks that are not part of
    -- the calculate pass; looked up here at call time.
    Bind.apply_partner_passive(host)

    -- A special REPLACES both halves, so a passive either of them applied when
    -- it entered the deck has to come off - the pair speaks for the card now.
    -- Only the host's: the absorbed half's was already taken back when it left
    -- the row, and Bind.apply_partner_passive above skips specials entirely.
    local def = Bind.special_of(host)
    if def then
        Bind.mark_special_seen(def.key)

        -- Only a replacing pair takes the host's passive off; an additive one
        -- is keeping both halves, passives included.
        local center = Bind.replacing_special(host) and host.config.center
        if type(center) == "table" and type(center.remove_from_deck) == "function" then
            pcall(center.remove_from_deck, center, host, false)
        end
        if type(def.on_merge) == "function" then
            local ok, err = pcall(def.on_merge, def, host, Bind.special_state(host, def))
            if not ok then
                CelestasMod.warn_once("bind_merge_" .. tostring(def.key),
                    ("Bind pair %s failed to form: %s"):format(tostring(def.key), tostring(err)))
            end
        end
    end

    -- Both halves announce themselves, if they have anything to announce.
    --
    -- Merging is the one arrival that does not go through add_to_deck - the
    -- host was already in the row and the absorbed half is leaving it - so
    -- neither Joker's own hook fires and this is the only place that can say
    -- so. Played back to back with no delay, which is to say together.
    --
    -- Two of the same Joker get one playback rather than two: the sound
    -- manager restarts a source rather than layering it over itself. Two
    -- copies of one clip in perfect sync would only have sounded louder.
    if CelestasMod.play_join_sound then
        CelestasMod.play_join_sound(host.config.center_key
            or (host.config.center and host.config.center.key))
        CelestasMod.play_join_sound(host.ability.celesta_bind.key)
    end

    absorbed.ability.eternal = nil       -- or it refuses to leave the row
    absorbed:start_dissolve(nil, true)
    return true
end

--------------------------------------------------------------------------------
-- Special pairs
--------------------------------------------------------------------------------
--
-- Some pairs are worth more than the sum of their halves. When both centres of
-- a merge match one of these, the pair's own ability REPLACES both - neither
-- half's normal behaviour runs.
--
-- Keyed on the two centre keys sorted and joined, so a pair matches whichever
-- order the player merged them in.

Bind.SPECIALS = {}

local function pair_key(a, b)
    if a > b then a, b = b, a end
    return a .. "|" .. b
end

--- def = { key, config, calculate, loc_vars, on_merge, on_unmerge }
--- `config` is the pair's own mutable state; it is copied onto the card the
--- first time the pair is evaluated and serialized with it thereafter.
---
--- on_merge and on_unmerge are for a pair whose ability is not a calculate at
--- all - a passive, a slot, a hand size. They are called once each, with
--- (def, card, state), at the two moments the pair comes into and goes out of
--- existence. Everything in between is the card's own: a passive written onto
--- card.ability is applied and removed by vanilla's own add_to_deck and
--- remove_from_deck, so selling, debuffing and destroying the merge all work
--- without either hook being involved.
local function special(key_a, key_b, def)
    -- Kept on the def so anything listing the pairs - the collection tab - can
    -- name both halves without picking the joined key back apart.
    def.halves = { key_a, key_b }
    Bind.SPECIALS[pair_key(key_a, key_b)] = def
end

--- Specials that pair one Joker with a CLASS of partners rather than a named
--- one. Ordered, because more than one could match and the first registered
--- wins - though a named pair beats all of them.
Bind.WILDCARDS = {}

--- def = the same shape as a special, plus:
---   anchor(key)  -> is this the Joker the wildcard is about?
---   partner(key) -> does this one qualify as its other half?
--- Both halves are offered to each in turn, so the merge order does not matter
--- any more than it does for a named pair.
local function wildcard(def)
    Bind.WILDCARDS[#Bind.WILDCARDS + 1] = def
end

--- The two centre keys of a merge, host first.
local function pair_keys(card)
    local host = card.config.center_key
        or (card.config.center and card.config.center.key)
    return host, card.ability.celesta_bind.key
end

--- The special governing this merge, if the pair has one.
---
--- A named pair is looked up first and wins outright: a wildcard says "any
--- Joker from this mod", and a pair that names both halves is by definition
--- the more specific answer.
function Bind.special_of(card)
    if not Bind.is_merged(card) then return nil end
    local host, other = pair_keys(card)
    if not host then return nil end

    local exact = Bind.SPECIALS[pair_key(host, other)]
    if exact then return exact end

    for _, def in ipairs(Bind.WILDCARDS) do
        if (def.anchor(host) and def.partner(other))
            or (def.anchor(other) and def.partner(host)) then
            return def
        end
    end
    return nil
end

--- The special governing this merge, but only when it REPLACES both halves.
---
--- Most do: the pair's ability stands in for both, so neither half's calculate
--- runs, neither half's passives are applied, and a self-destruct cannot
--- unmerge because there are no halves left to be one of. A special marked
--- `additive` is the other kind - it adds to what both halves already do - so
--- everything that asks "has this been replaced" has to ask through here
--- rather than through special_of.
function Bind.replacing_special(card)
    local def = Bind.special_of(card)
    if def and not def.additive then return def end
    return nil
end

--- The half of this merge that is NOT the wildcard's anchor.
function Bind.wildcard_partner(card, def)
    local host, other = pair_keys(card)
    if def.anchor(host) and def.partner(other) then return other end
    return host
end

--------------------------------------------------------------------------------
-- Which pairs the player has actually seen
--------------------------------------------------------------------------------
--
-- Kept on the PROFILE rather than in the run, because that is the question:
-- "has this player ever made this merge", not "is one in the row right now".
-- Game:load_profile copies every key of the saved table back over the live
-- one, so an unknown key of ours round-trips without anything else being
-- written - and Game:save_progress serialises the whole profile, so marking
-- one seen is a write plus a save.

--- The per-profile set of pair keys the player has made, created on first use.
--- nil before a profile is loaded, which is every moment before the main menu.
local function seen_store()
    local profile = G.PROFILES and G.SETTINGS
        and G.PROFILES[G.SETTINGS.profile]
    if type(profile) ~= "table" then return nil end
    if type(profile.celesta_merges_seen) ~= "table" then
        profile.celesta_merges_seen = {}
    end
    return profile.celesta_merges_seen
end

--- True once this profile has made that pair at least once.
function Bind.special_seen(key)
    local store = seen_store()
    return (store and store[key]) and true or false
end

--- Records a pair as made, and saves. Writes only on the first sighting, so
--- merging the same pair every run is not a save every time.
function Bind.mark_special_seen(key)
    if not key then return false end
    local store = seen_store()
    if not store or store[key] then return false end
    store[key] = true
    if G.save_progress then G:save_progress() end
    return true
end

--- The pair's saved state, created from its config on first use.
---
--- Deliberately kept under ability.celesta_bind rather than in ability.extra,
--- and that is load-bearing for more than tidiness: Cryptid's Misprint Deck
--- randomises numbers by walking card.ability and descending exactly ONE
--- level, so ability.extra.x is reached and ability.celesta_bind.special.x is
--- not. A merged pair's numbers therefore stay as written.
---
--- That is wanted. A pair's effect is agreed between two halves and several of
--- them hand out retriggers; a randomised repetition count on a Joker that is
--- already doubling the whole row is how a run stops being playable. The host
--- half's own ability.extra is still misprinted, as any Joker's would be.
---
--- test_misprint.py asserts this against Cryptid's real traversal, so if
--- Cryptid ever descends further this is found rather than discovered.
function Bind.special_state(card, def)
    local bound = card.ability.celesta_bind
    if type(bound.special) ~= "table" then
        bound.special = copy_table(def.config or {})
    end
    return bound.special
end

--------------------------------------------------------------------------------

--- Is there room for one more consumable? consumeable_buffer is vanilla's own
--- reservation: a slot claimed now and filled by an event later still counts
--- as taken, which is what stops two cards racing for one slot.
local function bind_consumable_room()
    if not (G.consumeables and G.consumeables.config) then return false end
    return #G.consumeables.cards + (G.GAME.consumeable_buffer or 0)
        < G.consumeables.config.card_limit
end

--- X1 plus the gain per Star Seal in the run's deck.
---
--- Read off card.seal, which holds the PREFIXED key, and counted live rather
--- than accrued - converting the last sealed card away costs the Mult back.
local function cottontail_crelly_mult(state)
    local star = (CelestasMod.SEAL_KEYS or {}).Star
    local sealed = 0
    for _, held in ipairs((G and G.playing_cards) or {}) do
        if held.seal == star then sealed = sealed + 1 end
    end
    return 1 + state.x_mult_gain * sealed
end

-- Arar + Jaws: the cards that missed out get something out of the hand anyway.
special("j_celesta_arar", "j_celesta_jaws", {
    key = "arar_jaws",
    calculate = function(def, card, context, state)
        if not (context.after and not context.blueprint) then return end
        local hand = context.full_hand or (G.play and G.play.cards)
        if type(hand) ~= "table" then return end

        -- Everything the poker hand actually used, so what is left is exactly
        -- the cards that were carried along without scoring.
        local scored = {}
        for _, played in ipairs(context.scoring_hand or {}) do scored[played] = true end

        local touched = 0
        for _, played in ipairs(hand) do
            if not scored[played] and played.config
                and played.config.center == G.P_CENTERS.c_base then
                -- poll_enhancement respects the run's pool, so this never
                -- rolls an enhancement the run has disabled and does pick up
                -- ones other mods add.
                local enhancement = SMODS.poll_enhancement {
                    key = "celesta_bind_arar_jaws",
                    guaranteed = true,
                }
                if enhancement and G.P_CENTERS[enhancement] then
                    local target = played
                    G.E_MANAGER:add_event(Event {
                        func = function()
                            target:set_ability(G.P_CENTERS[enhancement], nil, true)
                            return true
                        end
                    })
                    touched = touched + 1
                end
            end
        end

        if touched > 0 then
            return {
                message = localize("k_plus_enhancement"),
                colour = G.C.SECONDARY_SET.Enhanced,
                card = card,
            }
        end
    end,
})

-- Crelly + KokoNuts: KokoNuts keeps making Lucky 7s of Spades; this eats them.
special("j_celesta_crelly", "j_celesta_kokonuts", {
    key = "crelly_koko",
    config = { x_mult = 1, x_mult_gain = 0.25 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.destroying_card and context.cardarea == G.play
            and not context.blueprint then
            local target = context.destroying_card
            if SMODS.has_enhancement(target, "m_lucky")
                and target.get_id and target:get_id() == 7
                and target.is_suit and target:is_suit("Spades") then
                -- calculate_destroying_cards acts on `remove` without checking
                -- whether the card can actually go, so eternals are refused
                -- here or the row keeps a card that was told to leave.
                if SMODS.is_eternal and SMODS.is_eternal(target) then return end
                state.x_mult = state.x_mult + state.x_mult_gain
                return {
                    remove = true,
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { state.x_mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- Kumi + Maya: Kumi eats gold, Maya works with Steel; together they cash Steel in.
special("j_celesta_kumi", "j_celesta_maya", {
    key = "kumi_maya",
    config = { dollars = 15, odds = 2 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_kumi_maya")
        return { vars = { numerator, denominator, state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if context.destroying_card and context.cardarea == G.play
            and not context.blueprint then
            local target = context.destroying_card
            if SMODS.has_enhancement(target, "m_steel") then
                if SMODS.is_eternal and SMODS.is_eternal(target) then return end
                -- `remove` and `dollars` are both other_calculation_keys, so
                -- one table can destroy the card and pay out at once.
                local effect = { remove = true, card = card }
                if SMODS.pseudorandom_probability(card, "celesta_bind_kumi_maya",
                        1, state.odds, "celesta_bind_kumi_maya") then
                    effect.dollars = state.dollars
                end
                return effect
            end
        end
    end,
})

-- Deme + Camila: both care about a lone first hand; this reads what it was
-- wearing.
local DEME_CAMILA_GAINS = {
    none = 0.25,
    e_foil = 0.5,
    e_holo = 0.75,
    e_polychrome = 1.0,
}

special("j_celesta_demenishki", "j_celesta_camila", {
    key = "deme_camila",
    config = { x_mult = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        -- hands_played == 0 is vanilla's own idiom for "this is the first hand
        -- of the round" - DNA and Sixth Sense both gate on it.
        if context.before and not context.blueprint
            and G.GAME and G.GAME.current_round
            and G.GAME.current_round.hands_played == 0
            and context.full_hand and #context.full_hand == 1 then
            local played = context.full_hand[1]
            local edition = played.edition and played.edition.key or "none"
            -- An unknown edition, from another mod, is worth the plain rate
            -- rather than nothing.
            local gain = DEME_CAMILA_GAINS[edition] or DEME_CAMILA_GAINS.none
            state.x_mult = state.x_mult + gain
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { state.x_mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- Jax + Bricky: Bricky alone reads the whole deck every hand; bound to Jax it
-- stops counting and starts collecting, keeping what it is paid.
special("j_celesta_jaxvtuber", "j_celesta_bricky", {
    key = "jax_bricky",
    config = { chips = 0, chip_mod = 20 },

    loc_vars = function(def, card, state)
        return { vars = { state.chip_mod, state.chips } }
    end,

    calculate = function(def, card, context, state)
        -- The individual pass runs over the scoring cards BEFORE the joker row
        -- is evaluated, so a stone scored this hand is already paying by the
        -- time joker_main asks for the total.
        if context.individual and context.cardarea == G.play
            and not context.blueprint then
            local scored = context.other_card
            local limestone = (CelestasMod.ENHANCEMENT_KEYS or {}).Limestone
            if scored and (SMODS.has_enhancement(scored, "m_stone")
                or (limestone and SMODS.has_enhancement(scored, limestone))) then
                state.chips = state.chips + state.chip_mod
                return {
                    message = localize { type = "variable", key = "a_chips",
                                         vars = { state.chips } },
                    colour = G.C.CHIPS,
                    card = card,
                }
            end
        end

        if context.joker_main and state.chips > 0 then
            return { chips = state.chips }
        end
    end,
})

-- Nagzz + Chibidoki: Nagzz bends every listed chance; together they lean on
-- the cards whose whole point is a chance.
special("j_celesta_nagzz", "j_celesta_chibidoki", {
    key = "nagzz_chibidoki",
    config = { repetitions = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if context.repetition and context.cardarea == G.play
            and context.other_card
            and SMODS.has_enhancement(context.other_card, "m_lucky") then
            return {
                message = localize("k_again_ex"),
                repetitions = state.repetitions,
                card = card,
            }
        end
    end,
})

-- Arar + Arar: two of the same Joker, and the pair does something neither
-- half does alone. hands_left is read at the moment the Joker row is
-- evaluated, and vanilla decrements it before any of that happens: the first
-- hand of a five-hand round is played with four remaining, not five.
special("j_celesta_arar", "j_celesta_arar", {
    key = "arar_arar",
    config = { x_mult = 14, hands = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult, state.hands } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local round = G.GAME and G.GAME.current_round
        if not round or round.hands_left ~= state.hands then return end
        return { x_mult = state.x_mult }
    end,
})

--- The Mult from every Milk Bottle currently held, multiplied together.
---
--- Counted at the moment it is asked for rather than tracked: a consumable
--- comes and goes through more paths than are worth hooking, and the answer is
--- a scan of at most a few cards.
local function bottles_held_mult(state)
    local total = 1
    for _, held in ipairs(G.consumeables and G.consumeables.cards or {}) do
        local config = held.config
        local key = config and (config.center_key
            or (config.center and config.center.key))
        if key == CelestasMod.MILK_BOTTLE_KEY then total = total * state.x_mult end
    end
    return total
end

-- Blueprint + Brainstorm: the two copiers, and between them they stop copying
-- and start doubling. Every Joker in the row goes round again - including the
-- Jokers a copier would normally have to be standing next to.
special("j_blueprint", "j_brainstorm", {
    key = "blueprint_brainstorm",
    config = { repetitions = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        -- retrigger_joker_check is asked of every Joker about every other
        -- Joker, so the answer has to name who it is being asked about, and
        -- this must refuse itself or it would retrigger its own answer.
        if context.retrigger_joker_check and context.other_card
            and context.other_card ~= card then
            return {
                message = localize("k_again_ex"),
                repetitions = state.repetitions,
                card = card,
            }
        end
    end,
})

-- Bear The Witch + Moo Merrily: Moo Merrily makes the Milk Bottles, and this
-- pays for keeping them rather than drinking them. The Observatory voucher's
-- shape, for a consumable instead of a Planet.
special("j_celesta_bearthewitch", "j_celesta_moomerrily", {
    key = "bear_moo",
    config = { x_mult = 1.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult, bottles_held_mult(state) } }
    end,

    calculate = function(def, card, context, state)
        if context.joker_main then
            local total = bottles_held_mult(state)
            if total > 1 then return { x_mult = total } end
        end
    end,
})

-- Aries Akana + Yoka Siri: Aries collects Chips off Stars one at a time, Yoka
-- makes a Joker's numbers bigger. Together they stop counting cards and start
-- multiplying, on the one hand that is nothing but Stars.
--
-- "Contains a flush" rather than "is a Flush": the hand named Straight Flush,
-- Flush House and Flush Five all contain one, and there is no reason a better
-- hand should pay less. context.poker_hands is the game's own answer to that
-- question - it lists every hand the played cards make, not just the best -
-- and its "Flush" entry holds the cards that make it, which is exactly what
-- has to be all Stars.
--
-- Asked through is_suit, like every other Star Joker here, so a Wild Card
-- counts and Arielle makes the whole hand count. That is what those are for.

--- The cards forming a flush in this hand, or nil if there is not one.
local function flush_cards(context)
    local hands = context.poker_hands
    local flush = hands and hands["Flush"]
    return flush and flush[1] or nil
end

--- True when every card of that flush is a Star.
local function all_stars(cards)
    if not cards or #cards == 0 then return false end
    for _, played in ipairs(cards) do
        if not (played.is_suit and played:is_suit(CelestasMod.STARS_SUIT)) then
            return false
        end
    end
    return true
end

-- Arar + HeavenlyFather: Arar's enhancement, and then the card it landed on
-- again. Arar's own body is written out rather than borrowed, because a
-- replacing pair has no halves left to borrow from - and because the copy has
-- to be made from the SAME card Arar picked, which means picking it here.
special("j_celesta_arar", "j_celesta_heavenlyfather", {
    key = "arar_heavenly",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.first_hand_drawn and not context.blueprint) then return end
        if not (G.hand and G.hand.cards) then return end

        local candidates = {}
        for _, c in ipairs(G.hand.cards) do
            if c.config.center == G.P_CENTERS.c_base
                and not c.celesta_arar_claimed then
                candidates[#candidates + 1] = c
            end
        end
        if #candidates == 0 then return end

        local target = pseudorandom_element(candidates,
            pseudoseed("celesta_bind_arar_heavenly"))
        local enhancement = SMODS.poll_enhancement {
            key = "celesta_bind_arar_heavenly_enh",
            guaranteed = true,
        }
        if not (enhancement and G.P_CENTERS[enhancement]) then return end

        target.celesta_arar_claimed = true
        G.E_MANAGER:add_event(Event {
            func = function()
                target:set_ability(G.P_CENTERS[enhancement], nil, true)
                target:juice_up(0.3, 0.5)
                target.celesta_arar_claimed = nil

                -- Copied AFTER the enhancement lands, in the same event, so
                -- the copy is of the enhanced card rather than the bare one it
                -- was a moment ago. Duplication sequence lifted from vanilla
                -- DNA, emplaced into G.deck the way the Star Seal's is: the
                -- copy joins the full deck rather than the current hand.
                G.playing_card = (G.playing_card and G.playing_card + 1) or 1
                local copy = copy_card(target, nil, nil, G.playing_card)
                if not copy then return true end
                copy:add_to_deck()
                G.deck.config.card_limit = G.deck.config.card_limit + 1
                table.insert(G.playing_cards, copy)
                G.deck:emplace(copy)
                copy.states.visible = nil
                G.E_MANAGER:add_event(Event {
                    func = function() copy:start_materialize() return true end
                })
                playing_card_joker_effects({ copy })
                return true
            end
        })

        return {
            message = localize("k_copied_ex"),
            colour = G.C.SECONDARY_SET.Enhanced,
            card = card,
        }
    end,
})

-- Kumi + HeavenlyFather: the first pair that ADDS instead of replacing.
--
-- Both halves keep working - Kumi still eats Gold for money, HeavenlyFather
-- still hands out booster slots - and the pair puts those packs on sale. So it
-- is marked `additive`, which is what tells Bind to keep running both centres
-- and to keep applying both passives.
--
-- The price is not a calculate at all. A booster's cost is decided in
-- Card:set_cost, and vanilla has no per-type discount to move: G.GAME.discount
-- _percent is every shop item at once. So set_cost is wrapped further down,
-- and this half of the pair is only the number it reads.
special("j_celesta_kumi", "j_celesta_heavenlyfather", {
    key = "kumi_heavenly",
    additive = true,
    config = { discount = 0.5 },

    loc_vars = function(def, card, state)
        local kumi = G.P_CENTERS.j_celesta_kumi
        local extra = kumi and kumi.config and kumi.config.extra or {}
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, extra.odds or 4, "celesta_kumi")
        local father = G.P_CENTERS.j_celesta_heavenlyfather
        local slots = father and father.config and father.config.extra
            and father.config.extra.slots or 2
        return { vars = { numerator, denominator, extra.dollars or 20, slots } }
    end,

    calculate = function(def, card, context, state) end,
})

-- Zentreya + Zentreya: one Zentreya pays for Steel that scores. Two pay for
-- Steel wherever it is, and pay more.
--
-- context.individual fires in both areas - cardarea is G.play for the scoring
-- pass and G.hand for the held-in-hand one - so naming both is the whole of
-- "played hand and held in hand".
special("j_celesta_zentreya", "j_celesta_zentreya", {
    key = "zentreya_zentreya",
    config = { x_mult = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.other_card
            and (context.cardarea == G.play or context.cardarea == G.hand)
            and SMODS.has_enhancement(context.other_card, "m_steel") then
            return { x_mult = state.x_mult, card = card }
        end
    end,
})

-- Limealicious + Ray: Limealicious makes Limestone, Ray makes suit Jokers go
-- again. Together they go again for the Jokers that care what a card is made
-- of as much as what suit it is.
--
-- The four vanilla stones, plus the two of ours that belong with them: Vienna,
-- which is the Star suit's chance-based one, and MapleChicken, which
-- retriggers the Leaf suit. Ray's own list is the four suit Jokers and their
-- Star and Leaf equivalents; this is the other half of that family.
--
-- Same shape as Ray: retrigger_joker_check is asked of every Joker about every
-- other one, so the answer has to name who it is being asked about, and it
-- must refuse itself or it would retrigger its own answer.
local LIME_RAY_TARGETS = {
    j_bloodstone = true,     -- Hearts
    j_rough_gem = true,      -- Diamonds
    j_onyx_agate = true,     -- Clubs
    j_arrowhead = true,      -- Spades
    j_celesta_vienna = true,
    j_celesta_maplechicken = true,
}

special("j_celesta_limealicious", "j_celesta_ray", {
    key = "lime_ray",
    config = { repetitions = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if context.retrigger_joker_check and context.other_card
            and context.other_card ~= card then
            local config = context.other_card.config
            local key = config and (config.center_key
                or (config.center and config.center.key))
            if key and LIME_RAY_TARGETS[key] then
                return {
                    message = localize("k_again_ex"),
                    repetitions = state.repetitions,
                    card = card,
                }
            end
        end
    end,
})

-- x3Dustco + anything of ours: the one pair that does not name its other half.
--
-- A wildcard rather than 126 named pairs, and the reason it can be one is that
-- the effect does not care WHAT it was merged with - only that there was
-- something, and that the something can be made again. That is exactly the
-- shape Bind.wildcard_partner answers.
--
-- Excluding x3Dustco itself is not a special case for its own sake: two of
-- them have nothing to copy but each other, and a Joker that duplicates itself
-- every shop is a different card entirely.
--
-- Restricted to this mod's Jokers because that is what was asked, and because
-- an arbitrary foreign Joker is the one thing a fresh copy cannot be trusted
-- to survive - another mod's centre may keep state this knows nothing about.
--
-- Perkeo is the reference for the copy itself, beat for beat: on
-- context.ending_shop, queue an event, build the card, set_edition negative
-- BEFORE add_to_deck (the negative slot is granted by add_to_deck, so setting
-- it afterwards gives a Joker that quietly eats a slot), then emplace.
local X3DUSTCO = "j_celesta_x3dustco"
local CELESTA_JOKER_PREFIX = "j_" .. PREFIX .. "_"

wildcard {
    key = "x3dustco_any",
    -- No second half to name, so the collection shows the anchor and says so.
    halves = { X3DUSTCO },

    anchor = function(key) return key == X3DUSTCO end,
    partner = function(key)
        return type(key) == "string" and key ~= X3DUSTCO
            and key:sub(1, #CELESTA_JOKER_PREFIX) == CELESTA_JOKER_PREFIX
    end,

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.ending_shop and not context.blueprint) then return end

        local partner_key = Bind.wildcard_partner(card, def)
        if not (partner_key and G.P_CENTERS[partner_key]) then return end

        -- The half's own accumulated state, not a fresh one: a copy of a
        -- Joker that has been growing all run should have grown. Stickers ride
        -- along with it deliberately - a merge inherits them precisely so one
        -- cannot be laundered off, and copying must not become the way round
        -- that either.
        local carried = card.ability.celesta_bind.ability
        if card.config.center_key == partner_key then carried = card.ability end

        G.E_MANAGER:add_event(Event {
            func = function()
                local copy = SMODS.create_card {
                    key = partner_key,
                    area = G.jokers,
                    skip_materialize = true,
                }
                if not copy then return true end

                if type(carried) == "table" then
                    for k, v in pairs(carried) do
                        -- celesta_bind on an unmerged card would make it claim
                        -- to be half of a pair that does not exist.
                        if k ~= "celesta_bind" then
                            copy.ability[k] = type(v) == "table" and copy_table(v) or v
                        end
                    end
                end

                copy:set_edition({ negative = true }, true)
                copy:add_to_deck()
                G.jokers:emplace(copy)
                copy:start_materialize()
                return true
            end
        })

        return {
            message = localize("k_duplicated_ex"),
            colour = G.C.DARK_EDITION,
            card = card,
        }
    end,
}

-- CottontailVA + Deme: Cottontail hands out Star Seals, Deme grows on a
-- condition. Together the seals are the condition.
--
-- Asked per scoring card rather than once per hand, so five sealed cards are
-- five gains. card.seal holds the PREFIXED key - CelestasMod.SEAL_KEYS.Star,
-- not "Star" - because that is what set_seal was given and what a save keeps.
special("j_celesta_cottontail", "j_celesta_demenishki", {
    key = "cottontail_deme",
    config = { x_mult = 1, x_mult_gain = 0.25 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.cardarea == G.play
            and not context.blueprint and context.other_card
            and context.other_card.seal == (CelestasMod.SEAL_KEYS or {}).Star then
            state.x_mult = state.x_mult + state.x_mult_gain
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { state.x_mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- KokoNuts + Kumi: KokoNuts keeps making 7s of Spades, Kumi eats cards for
-- money. This eats those, enhanced or not - what Crelly + KokoNuts wants is a
-- LUCKY 7 of Spades, and this wants the rank and suit alone.
--
-- Two rolls, not one outcome of two: the small payout and the large one are
-- independent, so a card can hit both and pay $87. Written as two calls to
-- pseudorandom_probability with different identifiers, or they would share a
-- seed and the rare one would only ever land on cards the common one did.
special("j_celesta_kokonuts", "j_celesta_kumi", {
    key = "koko_kumi",
    config = { odds = 2, dollars = 17, rare_odds = 17, rare_dollars = 70 },

    loc_vars = function(def, card, state)
        local n1, d1 = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_koko_kumi")
        local n2, d2 = SMODS.get_probability_vars(
            card, 1, state.rare_odds, "celesta_bind_koko_kumi_rare")
        return { vars = { n1, d1, state.dollars, n2, d2, state.rare_dollars } }
    end,

    calculate = function(def, card, context, state)
        if context.destroying_card and context.cardarea == G.play
            and not context.blueprint then
            local target = context.destroying_card
            if not (target.get_id and target:get_id() == 7
                and target.is_suit and target:is_suit("Spades")) then return end
            -- calculate_destroying_cards acts on `remove` without checking
            -- whether the card can actually go, so eternals are refused here
            -- or the row keeps a card that was told to leave.
            if SMODS.is_eternal and SMODS.is_eternal(target) then return end

            -- `remove` and `dollars` are both other_calculation_keys, so one
            -- table can destroy the card and pay out at once.
            local effect = { remove = true, card = card }
            local paid = 0
            if SMODS.pseudorandom_probability(card, "celesta_bind_koko_kumi",
                    1, state.odds, "celesta_bind_koko_kumi") then
                paid = paid + state.dollars
            end
            if SMODS.pseudorandom_probability(card, "celesta_bind_koko_kumi_rare",
                    1, state.rare_odds, "celesta_bind_koko_kumi_rare") then
                paid = paid + state.rare_dollars
            end
            if paid > 0 then effect.dollars = paid end
            return effect
        end
    end,
})

-- Neuro + Vedal: paid for the wreckage, whoever caused it.
--
-- remove_playing_cards fires once after the destroy pass with every card that
-- died, which is where vanilla Caino counts its face cards. Counting there
-- rather than hooking any particular destroyer means it catches a Glass Card
-- shattering, a Gash breaking and another Joker eating something, all the same
-- way.
special("j_celesta_neuro", "j_celesta_vedal", {
    key = "neuro_vedal",
    config = { x_mult = 1, x_mult_gain = 1.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.remove_playing_cards and not context.blueprint then
            local gone = #(context.removed or {})
            if gone > 0 then
                state.x_mult = state.x_mult + state.x_mult_gain * gone
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { state.x_mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- CottontailVA + Crelly: Cottontail hands out Star Seals; this counts them
-- wherever they ended up. Live off the deck, like Fufu - converting the last
-- sealed card away costs the Mult back rather than leaving it banked.
special("j_celesta_cottontail", "j_celesta_crelly", {
    key = "cottontail_crelly",
    config = { x_mult_gain = 0.2 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, cottontail_crelly_mult(state) } }
    end,

    calculate = function(def, card, context, state)
        if context.joker_main then
            local total = cottontail_crelly_mult(state)
            if total > 1 then return { x_mult = total } end
        end
    end,
})

-- FroggyLoch + PapaMutt: PapaMutt makes a Tarot on a Three of a Kind and
-- FroggyLoch rolls for a second go at things, so this rolls for a second Tarot.
--
-- Room is asked for TWICE, once per card, because the first one takes a slot
-- the second may then not have. consumeable_buffer is vanilla's way of
-- reserving that slot across the events that fill it.
special("j_celesta_froggyloch", "j_celesta_papamutt", {
    key = "froggy_papa",
    config = { odds = 2 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_froggy_papa")
        return { vars = { localize("Three of a Kind", "poker_hands"), n, d } }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint
                and context.scoring_name == "Three of a Kind") then return end

        local wanted = 1
        if SMODS.pseudorandom_probability(card, "celesta_bind_froggy_papa",
                1, state.odds, "celesta_bind_froggy_papa") then
            wanted = 2
        end

        local made = 0
        for _ = 1, wanted do
            if not bind_consumable_room() then break end
            made = made + 1
            G.GAME.consumeable_buffer = (G.GAME.consumeable_buffer or 0) + 1
            G.E_MANAGER:add_event(Event {
                trigger = "before", delay = 0.0,
                func = function()
                    local card_made = SMODS.add_card {
                        set = "Tarot", key_append = "celesta_bind_froggy_papa" }
                    if card_made then card_made:juice_up(0.3, 0.5) end
                    G.GAME.consumeable_buffer =
                        math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
                    return true
                end
            })
        end

        if made > 0 then
            return { message = localize("k_plus_tarot"), colour = G.C.PURPLE,
                     card = card }
        end
    end,
})

-- Radical Mari + PapaMutt: PapaMutt's Three of a Kind, but the card it makes
-- is any consumable rather than a Tarot.
--
-- The set is picked from the run's own consumable types rather than a fixed
-- three, so a type another mod adds is reachable - which is the difference
-- between "any consumable" and "one of the three vanilla ones".
special("j_celesta_radicalmari", "j_celesta_papamutt", {
    key = "mari_papa",

    loc_vars = function(def, card, state)
        return { vars = { localize("Three of a Kind", "poker_hands") } }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint
                and context.scoring_name == "Three of a Kind") then return end
        if not bind_consumable_room() then return end

        local sets = {}
        for key in pairs(SMODS.ConsumableTypes or {}) do sets[#sets + 1] = key end
        table.sort(sets)
        if #sets == 0 then sets = { "Tarot", "Planet", "Spectral" } end
        local set = pseudorandom_element(sets, pseudoseed("celesta_bind_mari_papa"))

        G.GAME.consumeable_buffer = (G.GAME.consumeable_buffer or 0) + 1
        G.E_MANAGER:add_event(Event {
            trigger = "before", delay = 0.0,
            func = function()
                local made = SMODS.add_card {
                    set = set, key_append = "celesta_bind_mari_papa" }
                if made then made:juice_up(0.3, 0.5) end
                G.GAME.consumeable_buffer =
                    math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
                return true
            end
        })

        return { message = localize("celesta_plus_consumable"), colour = G.C.PURPLE,
                 card = card }
    end,
})

-- HeavenlyFather + Baddaboom: HeavenlyFather adds booster slots, Baddaboom
-- grows on things being spent. This grows on the packs you WALK PAST.
--
-- context.skipping_booster is raised once per pack skipped, which is the whole
-- of it.
special("j_celesta_heavenlyfather", "j_celesta_baddaboom", {
    key = "heavenly_boom",
    config = { x_mult = 1, x_mult_gain = 0.1 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.skipping_booster and not context.blueprint then
            state.x_mult = state.x_mult + state.x_mult_gain
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { state.x_mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- Rosedoodle + BuffPup: Rosedoodle's coin flip, on BuffPup's suit.
--
-- Rolled per card, so a hand of five Leaves gets five rolls - the same shape
-- Vienna uses for Stars.
special("j_celesta_rosedoodle", "j_celesta_buffpup", {
    key = "rose_buff",
    config = { odds = 2, x_mult = 1.5 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_rose_buff")
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR, true)
        return { vars = { n, d, state.x_mult, name, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.cardarea == G.play
            and context.other_card and context.other_card.is_suit
            and context.other_card:is_suit(CelestasMod.LEAF_SUIT) then
            if SMODS.pseudorandom_probability(card, "celesta_bind_rose_buff",
                    1, state.odds, "celesta_bind_rose_buff") then
                return { x_mult = state.x_mult, card = card }
            end
        end
    end,
})

-- Arar + Arielle: Arar enhances one card a round and Arielle makes every card
-- count as everything, so together every card gets one.
special("j_celesta_arar", "j_celesta_arielle", {
    key = "arar_arielle",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.first_hand_drawn and not context.blueprint) then return end
        if not (G.hand and G.hand.cards) then return end

        local touched = 0
        for _, held in ipairs(G.hand.cards) do
            if held.config and held.config.center == G.P_CENTERS.c_base then
                -- Rolled per card rather than once for the hand: "a random
                -- enhancement" to each, not one enhancement to all of them.
                local enhancement = SMODS.poll_enhancement {
                    key = "celesta_bind_arar_arielle",
                    guaranteed = true,
                }
                if enhancement and G.P_CENTERS[enhancement] then
                    local target = held
                    touched = touched + 1
                    G.E_MANAGER:add_event(Event {
                        func = function()
                            target:set_ability(G.P_CENTERS[enhancement], nil, true)
                            target:juice_up(0.3, 0.5)
                            return true
                        end
                    })
                end
            end
        end

        if touched > 0 then
            return { message = localize("k_plus_enhancement"),
                     colour = G.C.SECONDARY_SET.Enhanced, card = card }
        end
    end,
})

-- Camila + Neuro, and Camila + Vedal.
--
-- Neither reimplements Camila. They are `additive`, so Camila's own calculate
-- still runs and does all of the work; each pair is a flag Camila reads off
-- CelestasMod.Bind.special_of(card) while it runs. That is why the flags live
-- on the def and not in `config`: they are read, never written, and a merge
-- cannot misprint what it does not store.
special("j_celesta_camila", "j_celesta_neuro", {
    key = "camila_neuro",
    additive = true,
    camila_any_count = true,

    loc_vars = function(def, card, state) return { vars = {} } end,
    calculate = function(def, card, context, state) end,
})

special("j_celesta_camila", "j_celesta_vedal", {
    key = "camila_vedal",
    additive = true,
    camila_edition = "e_polychrome",

    loc_vars = function(def, card, state) return { vars = {} } end,
    calculate = function(def, card, context, state) end,
})

-- Crelly + Vedal: Crelly eats a consumable at the end of the shop for X0.2;
-- Vedal upgrades things. The meal is worth a great deal more.
special("j_celesta_crelly", "j_celesta_vedal", {
    key = "crelly_vedal",
    config = { x_mult = 1, x_mult_gain = 1.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.ending_shop and not context.blueprint then
            if #G.consumeables.cards == 0 then return end
            local target = pseudorandom_element(G.consumeables.cards,
                pseudoseed("celesta_bind_crelly_vedal"))

            state.x_mult = state.x_mult + state.x_mult_gain
            -- Respects eternal and undestroyable stickers, and animates it.
            SMODS.destroy_cards(target)
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { state.x_mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- Maya + Ben: Maya retriggers Steel Cards held in hand on a coin flip, Ben
-- makes room to hold more of them. Together the coin flip goes away and the
-- room is permanent rather than only against the Boss.
--
-- The hand size is the interesting half, because it is not a calculate at all.
-- It goes on card.ability.h_size, which is vanilla's OWN field: Card:add_to_deck
-- applies it and remove_from_deck takes it back, so selling the merge,
-- debuffing it and destroying it are all handled without another hook here.
-- The one thing vanilla cannot do is notice the field appearing on a card that
-- is already in the deck, which is what on_merge's change_size is for.
special("j_celesta_maya", "j_celesta_ben", {
    key = "maya_ben",
    config = { h_size = 4, repetitions = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.h_size, state.repetitions } }
    end,

    on_merge = function(def, card, state)
        -- Ben's own conditional hand size is already gone by now, by both
        -- routes: Bind.merge takes the host centre's passive off when a
        -- special forms, and an absorbed card dissolves through Card:remove,
        -- which calls remove_from_deck on its way out. So this only adds.
        card.ability.h_size = (card.ability.h_size or 0) + state.h_size
        if G.hand then G.hand:change_size(state.h_size) end
    end,

    on_unmerge = function(def, card, state)
        card.ability.h_size = (card.ability.h_size or 0) - state.h_size
        if G.hand then G.hand:change_size(-state.h_size) end
    end,

    calculate = function(def, card, context, state)
        -- Maya's own pass, with the coin flip taken out.
        if context.repetition and context.cardarea == G.hand
            and context.other_card
            and SMODS.has_enhancement(context.other_card, "m_steel") then
            return {
                message = localize("k_again_ex"),
                repetitions = state.repetitions,
                card = card,
            }
        end
    end,
})

special("j_celesta_ariesakana", "j_celesta_yokasiri", {
    key = "aries_yoka",
    config = { x_chips = 1, x_chip_mod = 0.5 },

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR, true)
        return { vars = { state.x_chip_mod, state.x_chips, name,
                          colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        -- context.before is the one pass that sees the whole hand before any
        -- of it scores, so the growth happens once per hand and is already in
        -- place by the time joker_main asks for the total.
        if context.before and not context.blueprint then
            if all_stars(flush_cards(context)) then
                state.x_chips = state.x_chips + state.x_chip_mod
                return {
                    message = localize { type = "variable", key = "a_xchips",
                                         vars = { state.x_chips } },
                    colour = G.C.CHIPS,
                    card = card,
                }
            end
        end

        if context.joker_main and state.x_chips > 1 then
            return { x_chips = state.x_chips }
        end
    end,
})

-- Deme + Boosfer: Deme's streak, at twice the rate, and Boosfer turns the lone
-- card it is counting into three extra scorings of itself.
--
-- The streak is Deme's own shape - context.before sees the whole hand ahead of
-- scoring, so a hand that extends the streak counts for itself - and the
-- retrigger is asked in the same terms, off full_hand rather than off what the
-- streak currently stands at. A single card played is retriggered whether or
-- not the streak was already running; the reading is "hands played with
-- exactly one card", once for each of the two things it does.
special("j_celesta_demenishki", "j_celesta_boosfer", {
    key = "deme_boosfer",
    config = { x_mult = 1, x_mult_gain = 0.5, repetitions = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.repetitions, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.before and not context.blueprint then
            if #context.full_hand == 1 then
                state.x_mult = state.x_mult + state.x_mult_gain
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { state.x_mult } },
                    colour = G.C.MULT, card = card,
                }
            elseif state.x_mult > 1 then
                state.x_mult = 1
                return { message = localize("k_reset"), colour = G.C.RED, card = card }
            end
        end

        if context.repetition and context.cardarea == G.play
            and context.full_hand and #context.full_hand == 1 then
            return {
                message = localize("k_again_ex"),
                repetitions = state.repetitions,
                card = card,
            }
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- Zentreya + Boosfer: Zentreya's Steel Cards, narrowed to Boosfer's suit and
-- paid far better for it, and retriggered the way Boosfer retriggers Stars.
--
-- Narrower than either half on its own: Zentreya pays every Steel Card and
-- Boosfer retriggers every Star, and this pays only where the two meet. That
-- is what the X2 and the retrigger together are for.
--- A scored card that is both halves' subject at once.
local function star_steel(other)
    return other ~= nil and other.is_suit ~= nil
        and other:is_suit(CelestasMod.STARS_SUIT)
        and SMODS.has_enhancement(other, "m_steel")
end

special("j_celesta_zentreya", "j_celesta_boosfer", {
    key = "zentreya_boosfer",
    config = { x_mult = 2, repetitions = 1 },

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR, true)
        return { vars = { state.x_mult, state.repetitions, name,
                          colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        -- The two passes are separate on purpose: repetition decides how many
        -- times the card scores, individual is what pays for each of them.
        if context.repetition and context.cardarea == G.play
            and star_steel(context.other_card) then
            return {
                message = localize("k_again_ex"),
                repetitions = state.repetitions,
                card = card,
            }
        end

        if context.individual and context.cardarea == G.play
            and star_steel(context.other_card) then
            return { x_mult = state.x_mult, card = context.other_card }
        end
    end,
})

-- KokoNuts's card, made `count` times.
--
-- Built in G.play so the player watches it appear and then animated into the
-- deck, which is vanilla Marble Joker's shape and what KokoNuts itself is
-- built on. Shared by the two pairs below because they differ only in how
-- many are made and whether they arrive with an edition.
local function koko_sevens(card, count, seed, editioned)
    if count <= 0 then return end
    G.E_MANAGER:add_event(Event {
        func = function()
            local made = {}
            for i = 1, count do
                local seven = create_playing_card(
                    { front = G.P_CARDS.S_7, center = G.P_CENTERS.m_lucky },
                    G.play, nil, nil, { G.C.SECONDARY_SET.Enhanced })
                if editioned then
                    -- Guaranteed, and never Negative: a Negative playing card
                    -- does nothing in vanilla, so rolling one would read as
                    -- the Joker having failed rather than as an edition.
                    local edition = poll_edition(seed .. "_ed" .. i, nil, true, true)
                    if edition then seven:set_edition(edition, true) end
                end
                made[#made + 1] = seven
            end

            SMODS.calculate_effect({
                message = localize("celesta_plus_seven"),
                colour = G.C.SECONDARY_SET.Enhanced,
            }, card)

            G.E_MANAGER:add_event(Event {
                func = function()
                    -- One call per card: draw_card moves a single card.
                    for _ = 1, count do draw_card(G.play, G.deck, 90, "up", nil) end
                    return true
                end
            })

            -- Lets other Jokers react to the new playing cards existing.
            playing_card_joker_effects(made)
            return true
        end
    })
end

-- KokoNuts + Camila: KokoNuts's Lucky 7 of Spades, and Camila hands editions
-- to the cards it touches. The seven arrives wearing one.
special("j_celesta_kokonuts", "j_celesta_camila", {
    key = "koko_camila",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        -- The getting_sliced guard is KokoNuts's own: a Joker destroyed this
        -- frame must not still be making cards.
        if context.setting_blind and not context.blueprint
            and not (context.blueprint_card or card).getting_sliced then
            koko_sevens(card, 1, "celesta_bind_koko_camila", true)
        end
    end,
})

-- KokoNuts + Maya: KokoNuts's seven, and Maya's coin flip decides whether two
-- more come with it.
special("j_celesta_kokonuts", "j_celesta_maya", {
    key = "koko_maya",
    config = { odds = 2, extra_cards = 2 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_koko_maya")
        return { vars = { n, d, state.extra_cards } }
    end,

    calculate = function(def, card, context, state)
        if context.setting_blind and not context.blueprint
            and not (context.blueprint_card or card).getting_sliced then
            local count = 1
            if SMODS.pseudorandom_probability(card, "celesta_bind_koko_maya",
                    1, state.odds, "celesta_bind_koko_maya") then
                count = count + state.extra_cards
            end
            koko_sevens(card, count, "celesta_bind_koko_maya", false)
        end
    end,
})

-- HeavenlyFather + Nostro: more of the shop, in both directions.
--
-- This is a passive, not a calculate, so it is declared the way a Joker
-- declares one: add_to_deck grants and remove_from_deck gives back, and
-- selling the merge, debuffing it and destroying it all go through vanilla's
-- own machinery. on_merge covers the one moment vanilla cannot see - the pair
-- coming into existence on a card that is already in the row - and on_unmerge
-- its mirror.
special("j_celesta_heavenlyfather", "j_celesta_nostro", {
    key = "heavenly_nostro",
    config = { boosters = 3, vouchers = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.boosters, state.vouchers } }
    end,

    add_to_deck = function(def, card, state, from_debuff)
        SMODS.change_booster_limit(state.boosters)
        SMODS.change_voucher_limit(state.vouchers)
    end,

    remove_from_deck = function(def, card, state, from_debuff)
        SMODS.change_booster_limit(-state.boosters)
        SMODS.change_voucher_limit(-state.vouchers)
    end,

    on_merge = function(def, card, state)
        def.add_to_deck(def, card, state, false)
    end,

    on_unmerge = function(def, card, state)
        def.remove_from_deck(def, card, state, false)
    end,
})

-- Kumi + Dejavudea: Dejavudea saves cards from wearing out and Kumi wants Gold
-- ones. Wear turns into Gold instead of into tatters.
--
-- No calculate at all: wear is counted in wear/tattered.lua, and that is where
-- the question has to be asked, at the moment a card crosses its threshold.
-- CelestasMod.Tattered.gilds() looks for this pair the same way the wear delay
-- looks for Sansin.
special("j_celesta_kumi", "j_celesta_dejavudea", {
    key = "kumi_deja",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
    end,
})

-- Arar + Dejavudea: Arar's start-of-round gift, in editions rather than
-- enhancements.
special("j_celesta_arar", "j_celesta_dejavudea", {
    key = "arar_deja",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.first_hand_drawn and not context.blueprint) then return end
        if not (G.hand and G.hand.cards) then return end

        local candidates = {}
        for _, held in ipairs(G.hand.cards) do
            -- The claim flag is Arar's: set_edition is deferred into an event,
            -- so a copy evaluating in the same pass would still see the card
            -- as bare and could waste itself re-picking it.
            if not held.edition and not held.celesta_arar_deja_claimed then
                candidates[#candidates + 1] = held
            end
        end
        if #candidates == 0 then return end

        local target = pseudorandom_element(candidates,
            pseudoseed("celesta_bind_arar_deja"))
        if not target then return end
        local edition = poll_edition("celesta_bind_arar_deja_ed", nil, true, true)
        if not edition then return end

        target.celesta_arar_deja_claimed = true
        G.E_MANAGER:add_event(Event {
            func = function()
                target:set_edition(edition, true)
                target:juice_up(0.3, 0.5)
                target.celesta_arar_deja_claimed = nil
                return true
            end
        })

        return { message = localize("k_upgrade_ex"),
                 colour = G.C.DARK_EDITION, card = card }
    end,
})

-- Zentreya + Ruben Sargasm: Ruben is worth more the fuller the row is, and
-- this cashes that reading out across every Joker in it.
--
-- Paid through calc_dollar_bonus rather than an end_of_round calculate,
-- because that is the hook vanilla pays reward money through: the amount gets
-- its own line on the cash-out screen instead of arriving as a floating
-- message. Bind dispatches it to the pair the same way it dispatches the
-- halves'.

--- Every Joker in the row, this one included.
local function row_sell_total()
    local total = 0
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        total = total + (held.sell_cost or 0)
    end
    return total
end

special("j_celesta_zentreya", "j_celesta_rubensargasm", {
    key = "zentreya_ruben",

    loc_vars = function(def, card, state)
        return { vars = { row_sell_total() } }
    end,

    calc_dollar_bonus = function(def, card, state)
        local total = row_sell_total()
        if total <= 0 then return end
        return total
    end,

    calculate = function(def, card, context, state)
    end,
})

-- Boosfer + Boosfer: two of them, and the Aces of its own suit start giving
-- up Legendaries.
special("j_celesta_boosfer", "j_celesta_boosfer", {
    key = "boosfer_boosfer",
    config = { odds = 20 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_boosfer_boosfer")
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR, true)
        return { vars = { n, d, name, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and not context.blueprint) then return end

        local other = context.other_card
        if not (other and other.is_suit and other:is_suit(CelestasMod.STARS_SUIT)
                and other.get_id and other:get_id() == 14) then return end

        -- Rolled before the room is asked for, so a full tray costs the roll
        -- rather than banking it for the next Ace.
        if not SMODS.pseudorandom_probability(card, "celesta_bind_boosfer_boosfer",
                1, state.odds, "celesta_bind_boosfer_boosfer") then return end
        if not bind_consumable_room() then return end

        G.GAME.consumeable_buffer = (G.GAME.consumeable_buffer or 0) + 1
        G.E_MANAGER:add_event(Event {
            trigger = "before", delay = 0.0,
            func = function()
                -- By key, because The Soul is `hidden` and never comes out of
                -- the Spectral pool on its own.
                local made = SMODS.add_card { set = "Spectral", key = "c_soul" }
                if made then made:juice_up(0.3, 0.5) end
                G.GAME.consumeable_buffer =
                    math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
                return true
            end
        })

        return { message = localize("k_plus_spectral"), colour = G.C.SECONDARY_SET.Spectral,
                 card = card }
    end,
})

--------------------------------------------------------------------------------
-- Unmerging: when one half destroys itself
--------------------------------------------------------------------------------
--
-- A Joker that removes itself - Gros Michel going extinct, Cavendish after it,
-- Invisible Joker cashing in - does it to `self`, and on a merged card `self`
-- is the whole card. Left alone that takes the other half with it, which is
-- not what the player agreed to when they merged them. So a self-destruct on a
-- merged card unmerges instead: the half that asked to go is dropped and the
-- other carries on as an ordinary Joker.
--
-- Knowing WHICH half asked is the whole difficulty. None of them return
-- anything that says so: they queue an event during their calculate, and the
-- removal happens later from inside that event - or from an event that event
-- queued, which is Gros Michel's shape exactly. So the acting half is recorded
-- across the calculate AND across every event queued while it runs, however
-- deeply nested.

-- Which half of which card is running right now. Both are needed: a Joker
-- destroying a DIFFERENT Joker is a normal thing to do, and only a card
-- removing ITSELF should unmerge.
local acting_card, acting_half = nil, nil

--- Runs `fn` with `half` of `card` recorded as acting, and arranges for that
--- record to be restored while any event queued during the run executes.
---
--- G.E_MANAGER.add_event is swapped only for the duration - during the
--- calculate itself, and again inside each event it tagged - so outside those
--- windows the queue is untouched. The wrapper re-enters this function, which
--- is what carries the record down a chain of events that queue events.
local function with_acting_half(card, half, fn, ...)
    local saved_card, saved_half = acting_card, acting_half
    acting_card, acting_half = card, half

    local manager = G.E_MANAGER
    local add_ref = manager and manager.add_event
    if add_ref then
        manager.add_event = function(mgr, event, ...)
            if type(event) == "table" and type(event.func) == "function" then
                local inner = event.func
                event.func = function(...)
                    return with_acting_half(card, half, inner, ...)
                end
            end
            return add_ref(mgr, event, ...)
        end
    end

    local ok, a, b = pcall(fn, ...)

    if add_ref then manager.add_event = add_ref end
    acting_card, acting_half = saved_card, saved_half

    if not ok then error(a, 0) end
    return a, b
end

Bind.with_acting_half = with_acting_half

--- The index this card last sat at in the Joker row.
--- Order matters in Balatro - it decides what Blueprint copies and the sequence
--- everything scores in - so a card that is put back has to go back where it
--- was, and by the time anything can be put back it has already been taken out.
local celesta_bind_remove_card_ref = CardArea.remove_card
function CardArea:remove_card(card, discarded_only)
    if card and self == G.jokers then
        for i, held in ipairs(self.cards) do
            if held == card then card.celesta_bind_row_index = i break end
        end
    end
    return celesta_bind_remove_card_ref(self, card, discarded_only)
end

--- Puts a card back in the Joker row at the position it was taken from.
local function restore_to_row(card)
    if not (G.jokers and G.jokers.cards) then return end
    for _, held in ipairs(G.jokers.cards) do
        if held == card then return end          -- never left
    end

    G.jokers:emplace(card)
    local index = card.celesta_bind_row_index
    if index and index >= 1 and index < #G.jokers.cards then
        table.remove(G.jokers.cards, #G.jokers.cards)
        table.insert(G.jokers.cards, index, card)
    end
    if G.jokers.set_ranks then G.jokers:set_ranks() end
    G.jokers:align_cards()
end

--- Splits a merged card, dropping `losing` ("host" or "absorbed").
--- Returns true when it actually unmerged.
---
--- The card object always survives; what changes is which centre it presents.
--- Dropping the absorbed half is a matter of forgetting it. Dropping the host
--- means the card has to BECOME the other Joker - centre, ability and sprite -
--- because there is only ever one card and the survivor has to be it.
function Bind.unmerge(card, losing)
    if not Bind.is_merged(card) then return false end
    local bound = card.ability.celesta_bind

    -- Undone while the pair still exists, because special_of stops answering
    -- the moment celesta_bind is cleared.
    local def = Bind.special_of(card)
    if def and type(def.on_unmerge) == "function" then
        local ok, err = pcall(def.on_unmerge, def, card, Bind.special_state(card, def))
        if not ok then
            CelestasMod.warn_once("bind_unmerge_" .. tostring(def.key),
                ("Bind pair %s failed to part: %s"):format(tostring(def.key), tostring(err)))
        end
    end

    if losing == "host" then
        local center = Bind.partner_center(card)
        if not center then return false end
        local surviving_ability = bound.ability

        -- Carried over rather than left behind: a merge inherits its halves'
        -- stickers precisely so one cannot be laundered off, and unmerging
        -- must not become the way to do it.
        for _, sticker in ipairs({ "eternal", "perishable", "rental" }) do
            if card.ability[sticker] then surviving_ability[sticker] = card.ability[sticker] end
        end
        if card.ability.perish_tally then
            surviving_ability.perish_tally = card.ability.perish_tally
        end

        card.config.center = center
        card.config.center_key = center.key
        card.ability = surviving_ability
        card.ability.celesta_bind = nil
        card.sell_cost = bound.sell_cost
            or math.max(1, math.floor((card.sell_cost or 2) / 2))
        if card.set_sprites then card:set_sprites(center) end
    else
        card.ability.celesta_bind = nil
        card.sell_cost = bound.host_sell_cost
            or math.max(1, math.floor((card.sell_cost or 2) / 2))
    end

    Bind.invalidate_art(card)
    card.ability_UIBox_table = nil          -- the two-panel description is stale
    if card.juice_up then card:juice_up(0.4, 0.5) end
    return true
end

-- Card:remove is where every self-destruct ends up, whichever route it took:
-- vanilla's own extinction code calls G.jokers:remove_card(self) and then
-- self:remove(), and SMODS.destroy_cards arrives here through start_dissolve.
-- Catching it here rather than at each source means one place to be right.
local celesta_bind_card_remove_ref = Card.remove
function Card:remove()
    if acting_card == self and acting_half and Bind.is_merged(self)
        and not Bind.replacing_special(self) then
        -- Removed from the row already, by the time anything can object.
        if Bind.unmerge(self, acting_half) then
            restore_to_row(self)
            card_eval_status_text(self, "extra", nil, nil, nil,
                { message = localize("celesta_unmerged"), colour = G.C.FILTER })
            return
        end
    end
    return celesta_bind_card_remove_ref(self)
end

--------------------------------------------------------------------------------
-- Running both halves
--------------------------------------------------------------------------------

-- Set while the absorbed half is being evaluated, so a centre that starts a
-- fresh evaluation pass cannot come straight back in here.
local running = false

-- Which keys combine how, when both halves answer the same context.
local ADDITIVE = {
    chips = true, h_chips = true, chip_mod = true,
    mult = true, h_mult = true, mult_mod = true,
    p_dollars = true, dollars = true, h_dollars = true,
    repetitions = true,
}
local MULTIPLICATIVE = {
    x_chips = true, xchips = true, Xchip_mod = true,
    x_mult = true, Xmult = true, xmult = true,
    x_mult_mod = true, Xmult_mod = true, h_x_mult = true,
    e_mult = true, emult = true, e_chips = true, echips = true,
}

--- Folds the absorbed half's effect into the host's.
--- Additive values add and multiplicative ones multiply, which is what makes a
--- +4 Mult bound to a X3 Mult behave like owning both Jokers.
local function combine(primary, secondary)
    if not primary then return secondary end
    if not secondary then return primary end
    for key, value in pairs(secondary) do
        local existing = primary[key]
        if type(value) == "number" and type(existing) == "number" then
            if MULTIPLICATIVE[key] then
                primary[key] = existing * value
            elseif ADDITIVE[key] then
                primary[key] = existing + value
            end
        elseif existing == nil then
            primary[key] = value
        end
    end
    return primary
end

local celesta_bind_calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context, ...)
    -- The host's own centre runs inside a recorded window too: it is as
    -- likely to be the half that destroys itself as the absorbed one.
    local effect, post
    if Bind.is_merged(self) and not running then
        effect, post = with_acting_half(self, "host",
            celesta_bind_calculate_joker_ref, self, context, ...)
    else
        effect, post = celesta_bind_calculate_joker_ref(self, context, ...)
    end

    if running or not Bind.is_merged(self) then return effect, post end

    -- A special pair REPLACES both halves. The host's own calculate has
    -- already run by this point - the ref is called first so that frozen
    -- rolls, tattered counting and every other mod's hook still see the
    -- evaluation - but its result is dropped in favour of the pair's.
    local def = Bind.special_of(self)
    local special_effect = nil
    if def then
        if running then return effect, post end
        running = true
        local state = Bind.special_state(self, def)
        local ok, ret = pcall(def.calculate, def, self, context, state)
        running = false
        if not ok then
            CelestasMod.warn_once("bind_special_" .. tostring(def.key),
                ("Bind pair %s failed: %s"):format(tostring(def.key), tostring(ret)))
            return (def.additive and effect or nil), post
        end
        -- A replacing pair is the whole answer. An additive one is one more
        -- voice, so it falls through and is combined with both halves below.
        if not def.additive then return ret, post end
        special_effect = ret
        effect = combine(effect, special_effect)
    end

    local center = Bind.partner_center(self)
    if not center or type(center.calculate) ~= "function" then return effect, post end

    -- The absorbed centre reads its own fields off card.ability, so it is lent
    -- the ability table that came with it - the same trick Eutrophic uses to
    -- run a foreign centre against a card that is not really it. Lent rather
    -- than copied: a Joker that scales itself must keep that growth.
    running = true
    local saved_center, saved_ability = self.config.center, self.ability
    self.config.center = center
    self.ability = self.ability.celesta_bind.ability
    local ok, partner = pcall(with_acting_half, self, "absorbed",
                              center.calculate, center, self, context)
    self.config.center, self.ability = saved_center, saved_ability
    running = false

    if not ok then
        CelestasMod.warn_once("bind_calc_" .. tostring(center.key),
            ("Bind could not run %s: %s"):format(tostring(center.key), tostring(partner)))
        return effect, post
    end
    if type(partner) ~= "table" then return effect, post end

    -- Both halves can want to say something, and an effect table carries only
    -- one message. The host's rides along in the return; the absorbed half's
    -- is spoken here so neither trigger goes unannounced.
    if effect and effect.message and partner.message then
        local said = partner.message
        partner.message = nil
        card_eval_status_text(self, "extra", nil, nil, nil,
            { message = said, colour = partner.colour or G.C.FILTER })
    end

    return combine(effect, partner), post
end

--------------------------------------------------------------------------------
-- The hooks that are not part of the calculate pass
--------------------------------------------------------------------------------

--- The first card in the Joker row governed by the special `key`, if any.
function Bind.find_special(key)
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        local def = Bind.special_of(held)
        if def and def.key == key then return held, def end
    end
    return nil
end

-- Booster prices, for Kumi + HeavenlyFather.
--
-- A booster's cost is decided in Card:set_cost and nowhere else, and vanilla
-- has no per-type discount to move - G.GAME.discount_percent is every shop
-- item at once, and the voucher that moves it is not what was asked for. So
-- the price is adjusted after the fact, at the one place that sets it.
--
-- Rounded up and floored at 1, matching what set_cost does to every other
-- price: a free booster is a different card, and math.floor would make the
-- cheapest packs free by accident.
local celesta_bind_set_cost_ref = Card.set_cost
function Card:set_cost()
    celesta_bind_set_cost_ref(self)
    if not (self.ability and self.ability.set == "Booster") then return end

    local holder, def = Bind.find_special("kumi_heavenly")
    if not holder then return end

    local discount = Bind.special_state(holder, def).discount or 0.5
    self.cost = math.max(1, math.ceil(self.cost * discount))
end
--
-- `calculate` is dispatched through Card:calculate_joker, which is wrapped
-- above, so both halves are asked. The rest of a centre's hooks are dispatched
-- straight off self.config.center and never look further, so the absorbed half
-- is simply never asked. Each one below is a behaviour that would go silently
-- missing on a merge.

--- Runs `fn(center, card)` with the absorbed half's centre and ability lent to
--- the card, so the centre reads and writes its own state rather than the
--- host's. Returns nil when there is nothing to run.
---
--- During the lend the card no longer looks merged - celesta_bind lives on the
--- host's ability, not the absorbed one - so a hook that re-enters any of this
--- passes straight through instead of recursing.
local function with_partner(card, hook, fn)
    if not Bind.is_merged(card) then return nil end
    -- A special pair replaces both halves, so neither half's hooks run - but
    -- an additive one keeps them, which is the whole of what it is.
    if Bind.replacing_special(card) then return nil end

    local center = Bind.partner_center(card)
    if not (center and type(center[hook]) == "function") then return nil end

    local saved_center, saved_ability = card.config.center, card.ability
    card.config.center = center
    card.ability = card.ability.celesta_bind.ability
    local ok, ret = pcall(fn, center, card)
    card.config.center, card.ability = saved_center, saved_ability

    if not ok then
        CelestasMod.warn_once("bind_" .. hook .. "_" .. tostring(center.key),
            ("Bind could not run %s on %s: %s"):format(hook, tostring(center.key), tostring(ret)))
        return nil
    end
    return ret
end

-- End-of-round money. Vanilla dispatches this to self.config.center alone, and
-- it is where a whole family of Jokers both pays AND scales - Cryptid's
-- Compound Interest raises its own rate here and never touches `calculate`.
-- Without this an absorbed one pays nothing and sits frozen at its opening
-- rate for the rest of the run.
--- Runs `fn` with the host centre's `hook` hidden, so vanilla's own dispatch
--- skips it.
---
--- Bind.merge takes the host centre's passive off the moment a REPLACING pair
--- forms - the pair speaks for the card now - and it does that by calling the
--- centre directly, which never touches added_to_deck. Vanilla still believes
--- the passive is on, so it takes it off a SECOND time when the card is sold
--- or debuffed: a merge hosted by HeavenlyFather leaves the run two booster
--- slots short of where it started, and a debuff leaves it short until the
--- debuff lifts. test_bind_passives.py has the sequence.
---
--- The hook is nilled on the centre rather than swapped behind a proxy table
--- because config.center is compared by IDENTITY all over the game -
--- `c.config.center == G.P_CENTERS.c_base` and its like - and a stand-in would
--- fail every one of those. The window is a single synchronous call.
local function without_center_hook(card, hook, fn)
    local center = card.config and card.config.center
    local hide = type(center) == "table" and type(center[hook]) == "function"
        and Bind.replacing_special(card) and true or false
    if not hide then return fn() end

    local saved = center[hook]
    center[hook] = nil
    local ok, ret = pcall(fn)
    center[hook] = saved
    if not ok then error(ret, 0) end
    return ret
end

--- The pair's own passive, for a special whose ability is not a calculate.
---
--- Declared the same way a Joker declares one and run from the same two
--- moments, so selling the merge, debuffing it and destroying it all work
--- through vanilla's machinery instead of needing a hook each. on_merge is
--- still needed for the one moment vanilla cannot see: the pair coming into
--- existence on a card that is already in the deck.
local function special_passive(card, hook, from_debuff)
    local def = Bind.replacing_special(card)
    if not (def and type(def[hook]) == "function") then return end
    local ok, err = pcall(def[hook], def, card,
                          Bind.special_state(card, def), from_debuff)
    if not ok then
        CelestasMod.warn_once("bind_passive_" .. tostring(def.key),
            ("Bind pair %s failed its %s: %s"):format(
                tostring(def.key), hook, tostring(err)))
    end
end

local celesta_bind_dollar_ref = Card.calculate_dollar_bonus
function Card:calculate_dollar_bonus()
    -- The host's own payout is muffled under a replacing pair for the same
    -- reason its passive is: the pair stands in for both halves, and a pair
    -- that pays at the end of the round must not pay twice.
    local own = without_center_hook(self, "calc_dollar_bonus", function()
        return celesta_bind_dollar_ref(self)
    end)
    -- Vanilla returns before paying anything when debuffed; the absorbed half
    -- is debuffed by exactly the same token.
    if self.debuff then return own end

    local def = Bind.replacing_special(self)
    if def and type(def.calc_dollar_bonus) == "function" then
        local ok, mine = pcall(def.calc_dollar_bonus, def, self,
                               Bind.special_state(self, def))
        if not ok then
            CelestasMod.warn_once("bind_dollar_" .. tostring(def.key),
                ("Bind pair %s failed to pay: %s"):format(
                    tostring(def.key), tostring(mine)))
        elseif type(mine) == "number" and mine ~= 0 then
            own = (own or 0) + mine
        end
    end

    local theirs = with_partner(self, "calc_dollar_bonus", function(center, card)
        return center:calc_dollar_bonus(card)
    end)
    if type(theirs) ~= "number" then return own end
    return (own or 0) + theirs
end

-- Passives: +1 hand size, an extra Joker slot, anything a centre applies once
-- when it enters the deck and undoes when it leaves.
--
-- Both guard their bodies with self.added_to_deck, so the flag is read BEFORE
-- the ref runs and flips it - otherwise the partner's half of the passive
-- would be applied every time the card was touched.
local celesta_bind_add_ref = Card.add_to_deck
function Card:add_to_deck(from_debuff)
    local first = not self.added_to_deck
    without_center_hook(self, "add_to_deck", function()
        celesta_bind_add_ref(self, from_debuff)
    end)
    if not first then return end
    special_passive(self, "add_to_deck", from_debuff)
    with_partner(self, "add_to_deck", function(center, card)
        center:add_to_deck(card, from_debuff)
    end)
end

local celesta_bind_remove_ref = Card.remove_from_deck
function Card:remove_from_deck(from_debuff)
    local was_added = self.added_to_deck
    without_center_hook(self, "remove_from_deck", function()
        celesta_bind_remove_ref(self, from_debuff)
    end)
    if not was_added then return end
    special_passive(self, "remove_from_deck", from_debuff)
    with_partner(self, "remove_from_deck", function(center, card)
        center:remove_from_deck(card, from_debuff)
    end)
end

--- Applies the absorbed half's passive at merge time.
--- The absorbed card dissolves out of the row, which runs its own
--- remove_from_deck and takes the passive back off; this puts it on the host.
--- Not needed on load: a passive lands in state that is itself saved, so
--- re-applying it would hand out the same slot twice.
function Bind.apply_partner_passive(host)
    with_partner(host, "add_to_deck", function(center, card)
        center:add_to_deck(card, false)
    end)
end

--------------------------------------------------------------------------------
-- Art: the two faces split corner to corner
--------------------------------------------------------------------------------

-- Composited into an off-screen canvas at merge time rather than stencilled
-- during Card:draw. In canvas space the split is just a triangle across a
-- known rectangle; doing it live would mean reproducing Balatro's card
-- transform (position, rotation, the hover tilt) to place the same triangle in
-- screen space, and getting that subtly wrong is invisible until it is not.
local art_cache = setmetatable({}, { __mode = "k" })

-- Balatro's card silhouette: the transparent run inwards from the left edge,
-- per row, for a 71x95 sprite, mirrored horizontally. Measured off the game's
-- own Jokers.png by tools/round_corners.py, which masks every sprite in this
-- mod with the same numbers - so a merged card is cut to exactly the shape a
-- joker is meant to be.
--
-- The two halves arrive already rounded, being ordinary joker art. Only the
-- glow needs this: a stroked rectangle runs straight through the corners the
-- art carefully leaves empty, which reads as a merged card having square
-- corners while every other card is round.
local CORNER_W, CORNER_H = 71, 95
local CORNER_PROFILE = { CORNER_W, 4, 2, 2 }
for _ = 1, 87 do CORNER_PROFILE[#CORNER_PROFILE + 1] = 1 end
for _, inset in ipairs({ 2, 2, 4, CORNER_W }) do
    CORNER_PROFILE[#CORNER_PROFILE + 1] = inset
end

--- Fills the card silhouette, scaled to a canvas of any size, as a stencil.
local function card_silhouette(w, h)
    local sx, sy = w / CORNER_W, h / CORNER_H
    for row = 1, CORNER_H do
        local inset = CORNER_PROFILE[row] * sx
        local run = w - inset * 2
        if run > 0 then
            love.graphics.rectangle("fill", inset, (row - 1) * sy, run, sy + 1)
        end
    end
end

function Bind.invalidate_art(card)
    art_cache[card] = nil
end

--- The atlas a centre draws itself from.
--- The same rule Card:set_sprites uses (card.lua:165): a centre's own atlas if
--- it declares one, otherwise its set for the sets that have their own sheet,
--- otherwise the shared "centers" sheet.
local function atlas_for(center)
    if not center then return nil end
    local key = center.atlas
        or ((center.set == "Joker" or center.consumeable or center.set == "Voucher")
            and center.set)
        or "centers"
    return G.ASSET_ATLAS[key]
end

--- The atlas and quad a centre draws itself from.
local function face_of(center)
    if not center then return nil end
    local atlas = atlas_for(center)
    if not (atlas and atlas.image) then return nil end
    local pos = center.pos or { x = 0, y = 0 }
    local w, h = atlas.px, atlas.py
    return atlas.image, love.graphics.newQuad(pos.x * w, pos.y * h, w, h,
        atlas.image:getDimensions())
end

--- Builds the merged face: host in the upper-left, absorbed in the lower-right,
--- a glowing white line along the corner-to-corner split and the same glow
--- around the border.
local function build_art(card)
    local host_image, host_quad = face_of(card.config.center)
    local other_image, other_quad = face_of(Bind.partner_center(card))
    if not (host_image and other_image) then return nil end

    local atlas = atlas_for(card.config.center)
    if not atlas then return nil end
    local w, h = atlas.px, atlas.py

    -- The stencil flag belongs on setCanvas, NOT on newCanvas: LOVE 11 has no
    -- such canvas setting and rejects it outright ("Invalid canvas setting
    -- name: stencil"). Asking for it at bind time is what makes LOVE attach a
    -- stencil buffer for the duration.
    local canvas = love.graphics.newCanvas(w, h)
    local previous = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)

    -- The split runs bottom-left to top-right, so the host keeps the corner
    -- above that line and the absorbed half takes the one below it.
    love.graphics.draw(host_image, host_quad, 0, 0)
    love.graphics.stencil(function()
        love.graphics.polygon("fill", 0, h, w, h, w, 0)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.draw(other_image, other_quad, 0, 0)
    love.graphics.setStencilTest()

    -- Clipped to the card silhouette so the border follows the rounding
    -- instead of squaring off the corners.
    local unit = w / CORNER_W
    love.graphics.stencil(function() card_silhouette(w, h) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    for _, pass in ipairs(Bind.GLOW_PASSES) do
        local stroke = pass.width * unit
        love.graphics.setColor(Bind.GLOW[1], Bind.GLOW[2], Bind.GLOW[3], pass.alpha)
        love.graphics.setLineWidth(stroke)
        love.graphics.line(0, h, w, 0)
        -- Inset by half the stroke. LOVE centres a stroke on its path, so a
        -- rectangle drawn on the canvas edge loses its outer half off the side
        -- and the border comes out looking thinner than the split line - which
        -- is exactly how it looked before.
        local inset = stroke / 2
        love.graphics.rectangle("line", inset, inset, w - stroke, h - stroke)
    end
    love.graphics.setStencilTest()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas(previous)

    -- Handed back as a private atlas rather than a bare canvas. The sprite is
    -- given this whole table in place of its own, so nothing is ever written
    -- into the shared one - vanilla Jokers all draw from a single Jokers.png,
    -- and swapping the image on that table would hand every other joker on the
    -- board this canvas for the rest of the frame.
    return { image = canvas, px = w, py = h }
end

-- Building happens between frames, never inside one.
--
-- The obvious place is the draw hook, the moment the art turns out to be
-- missing - and it is the wrong place: Balatro draws the whole game into its
-- own canvas, so binding another one mid-draw means restoring the caller's
-- canvas afterwards without knowing what attachments it was bound with.
-- love.graphics.getCanvas hands back the canvas but not the flags, so the
-- restore is a guess. Doing it from update sidesteps the question - nothing is
-- bound there.
--
-- A card that wants art is queued and drawn plainly for the frame or two until
-- it arrives, which nobody will catch.
local pending = setmetatable({}, { __mode = "k" })

local celesta_bind_game_update_ref = Game.update
function Game:update(dt)
    celesta_bind_game_update_ref(self, dt)
    if not next(pending) then return end
    for card in pairs(pending) do
        pending[card] = nil
        if Bind.is_merged(card) and art_cache[card] == nil then
            local ok, art = pcall(build_art, card)
            if not ok then
                CelestasMod.warn_once("bind_art",
                    "Bind could not build merged art: " .. tostring(art))
                art = nil
            end
            -- false rather than nil: nil means "not tried yet" and would queue
            -- this card again every single frame.
            art_cache[card] = art or false
        end
    end
end

local celesta_bind_card_draw_ref = Card.draw
function Card:draw(layer)
    if not Bind.is_merged(self) or self.facing == "back" or layer == "shadow" then
        return celesta_bind_card_draw_ref(self, layer)
    end

    local art = art_cache[self]
    if art == nil then
        -- Not built yet. Ask for it and draw plainly this frame.
        pending[self] = true
        return celesta_bind_card_draw_ref(self, layer)
    end
    if not art then return celesta_bind_card_draw_ref(self, layer) end

    -- The merged face replaces the host's centre sprite for the duration of
    -- the normal draw, so everything else - shadows, tilt, edition shaders,
    -- stickers - keeps working untouched.
    local sprite = self.children.center
    if not (sprite and sprite.atlas and sprite.sprite) then
        return celesta_bind_card_draw_ref(self, layer)
    end

    -- The QUAD has to be swapped too, not just the image.
    --
    -- Sprite:draw_shader draws self.atlas.image through self.sprite, and that
    -- quad was cut for the card's real atlas: for a mod joker, whose atlas is
    -- one card, it is (0,0,71,95) and pointing it at this canvas happens to be
    -- right. For a vanilla joker it points at that joker's cell deep inside
    -- the shared Jokers.png, and sampling a 71x95 canvas with it returns
    -- whatever lies outside - which is exactly how a merge of two vanilla
    -- jokers came out as a smear.
    if not art.quad then
        art.quad = love.graphics.newQuad(0, 0, art.px, art.py,
                                         art.image:getDimensions())
    end

    local saved_atlas, saved_quad, saved_dims =
        sprite.atlas, sprite.sprite, sprite.image_dims
    sprite.atlas = art
    sprite.sprite = art.quad
    sprite.image_dims = { art.image:getDimensions() }

    celesta_bind_card_draw_ref(self, layer)

    sprite.atlas, sprite.sprite, sprite.image_dims =
        saved_atlas, saved_quad, saved_dims
end

--------------------------------------------------------------------------------
-- Description: both halves, side by side
--------------------------------------------------------------------------------

-- A special pair describes itself, in place of both halves.
--
-- Swapped into the card's own AUT rather than assembled as a panel by hand:
-- card_h_popup then builds it exactly as it builds every other card's, name
-- row and rarity badge and box included. Hand-assembling a panel is what
-- crashed set_parent_child the first time.
local celesta_bind_special_ability_ref = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table(...)
    local box = celesta_bind_special_ability_ref(self, ...)
    local def = Bind.special_of(self)
    if not (def and type(box) == "table") then return box end

    local state = Bind.special_state(self, def)
    local vars = {}
    if type(def.loc_vars) == "function" then
        local ok, res = pcall(def.loc_vars, def, self, state)
        if ok and type(res) == "table" and res.vars then vars = res.vars end
    end

    local loc_key = "celesta_bind_" .. def.key
    local ok, aut = pcall(generate_card_ui,
        { set = "Other", key = loc_key }, nil, vars, "Other", nil, false)
    if not (ok and type(aut) == "table" and aut.main) then
        CelestasMod.warn_once("bind_special_desc_" .. tostring(def.key),
            "Bind pair " .. tostring(def.key) .. " has no description")
        return box
    end
    box.main = aut.main

    -- The pair's own name, in place of the host's.
    local name_rows = {}
    localize { type = "name", set = "Other", key = loc_key, nodes = name_rows }
    if name_rows[1] then box.name = name_rows[1] end
    return box
end

-- Set while the absorbed half's description is being generated, so the hook
-- below cannot re-enter itself.
local describing = false

--- The absorbed half's description table, built as though it were on its own
--- card so its own loc_vars run and any value it has scaled up shows the
--- number it has actually reached.
local function partner_ui(card)
    local center = Bind.partner_center(card)
    if not center or describing then return nil end

    describing = true
    local saved_center, saved_ability = card.config.center, card.ability
    card.config.center = center
    card.ability = card.ability.celesta_bind.ability
    local ok, aut = pcall(card.generate_UIBox_ability_table, card)
    card.config.center, card.ability = saved_center, saved_ability
    describing = false

    if not (ok and type(aut) == "table" and aut.main) then
        CelestasMod.warn_once("bind_desc_" .. tostring(center.key),
            ("Bind could not describe %s: %s"):format(tostring(center.key), tostring(aut)))
        return nil
    end
    return aut, center
end

-- Both halves get the same panel, because it is literally the same node shape
-- card_h_popup builds for the card's own description: an outer rounded row in
-- lightened JOKER_GREY holding an inner row in the type background, wrapping
-- name_from_rows / desc_from_rows / badges.
--
-- The first attempt appended the absorbed half to AUT.info instead, which was
-- less code but rendered it as a tooltip - a smaller box in a different style
-- sitting beside a full one.
-- G.UIDEF is built at boot, well before mods load, so this is present. Guarded
-- anyway: wrapping a nil would swap a missing popup for a crashing one.
local celesta_bind_popup_ref = G.UIDEF and G.UIDEF.card_h_popup
if celesta_bind_popup_ref then
function G.UIDEF.card_h_popup(card)
    local root = celesta_bind_popup_ref(card)
    if not Bind.is_merged(card) then return root end
    if type(root) ~= "table" or type(root.nodes) ~= "table" then return root end

    -- A special pair has one ability and therefore one panel. Its description
    -- is swapped in below, before card_h_popup ever sees it, so there is
    -- nothing to add here.
    if Bind.special_of(card) then return root end

    local aut, center = partner_ui(card)
    if not aut then return root end

    -- Its own rarity, shown the way the host's is.
    local badges = {}
    local rarity_names = { localize("k_common"), localize("k_uncommon"),
                           localize("k_rare"), localize("k_legendary") }
    local label = center.rarity and rarity_names[center.rarity]
    if label then
        badges[1] = create_badge(label, get_type_colour(center, card), nil, 1.2)
    end

    root.nodes[#root.nodes + 1] = {
        n = G.UIT.C,
        config = { align = "cm" },
        nodes = { {
            n = G.UIT.R,
            config = { padding = 0.05, r = 0.12,
                       colour = lighten(G.C.JOKER_GREY, 0.5), emboss = 0.07 },
            nodes = { {
                n = G.UIT.R,
                config = { align = "cm", padding = 0.07, r = 0.1,
                           colour = adjust_alpha(darken(G.C.BLACK, 0.1), 0.8) },
                nodes = {
                    name_from_rows(aut.name),
                    desc_from_rows(aut.main),
                    badges[1] and { n = G.UIT.R, config = { align = "cm", padding = 0.03 },
                                    nodes = badges } or nil,
                },
            } },
        } },
    }
    return root
end
end

--------------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------------

SMODS.Consumable {
    key = "bind",
    set = "Spectral",
    atlas = "bind",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    can_use = function(self, card)
        return Bind.selection() ~= nil
    end,

    use = function(self, card, area, copier)
        local picked = Bind.selection()
        if not picked then return end

        -- The host is whichever sits further left, so the merge lands where the
        -- player already expects it rather than jumping position.
        local host, absorbed = picked[1], picked[2]
        for _, joker in ipairs(G.jokers.cards) do
            if joker == picked[2] then host, absorbed = picked[2], picked[1] break end
            if joker == picked[1] then break end
        end

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                play_sound("gold_seal", 1.2, 0.6)
                host:juice_up(0.4, 0.5)
                Bind.merge(host, absorbed)
                return true
            end,
        })
        delay(0.6)
    end,
}

-- Two Jokers have to be selectable at once. Vanilla builds G.jokers with
-- highlight_limit = 1, which would make Bind impossible to satisfy. Raised to
-- exactly 2 rather than something large, so the rest of the game's
-- single-selection behaviour is disturbed as little as possible. Cryptid sets
-- this to 1e100 for its own cards; whoever asks for more wins.
--------------------------------------------------------------------------------
-- Misprint: both halves, not just the host
--------------------------------------------------------------------------------
--
-- Cryptid's Misprint Deck randomises a Joker's numbers by walking card.ability
-- and descending exactly one level. On a merged card that reaches the host's
-- ability.extra and stops: the absorbed half's own ability sits three levels
-- down, at celesta_bind.ability.extra, so it never moves while every other
-- Joker in the run does.
--
-- Numbers it was carrying at the moment of the merge do come along, because
-- Bind.merge copies the ability table as it stands - a Joker misprinted before
-- being merged keeps those. What it loses is every re-roll afterwards, so it
-- drifts further out of step the longer the run goes on. This is what fixes
-- that.
--
-- Done by lending Cryptid the absorbed half and letting it do exactly what it
-- does to any Joker, rather than reimplementing the walk. Cryptid decides
-- between misprinting and restoring base values, applies each centre's caps
-- and records base values per centre key - all of which has to be right, and
-- none of which is this mod's to duplicate. Lending means the absorbed half is
-- measured against ITS OWN centre, which is the whole point: its base values
-- are its own, not the host's.
--
-- The pair's agreed state, celesta_bind.special, is deliberately left out: it
-- lives beside celesta_bind.ability, not inside it, so this cannot reach it.
-- See Bind.special_state for why that matters.

local misprint_hooked = false

local function hook_cryptid_misprint()
    if misprint_hooked then return end
    if type(Cryptid) ~= "table" or type(Cryptid.misprintize) ~= "function" then
        return
    end
    misprint_hooked = true

    local misprintize_ref = Cryptid.misprintize
    function Cryptid.misprintize(card, override, force_reset, stack, grow_type, pow_level)
        local ret = misprintize_ref(card, override, force_reset, stack, grow_type, pow_level)
        if not Bind.is_merged(card) then return ret end

        local bound = card.ability.celesta_bind
        local center = Bind.partner_center(card)
        if type(bound.ability) ~= "table" or not center then return ret end

        -- The same lend Card:calculate_joker uses. The inner call is the
        -- original function, not this wrapper, so it cannot recurse - and
        -- while it is lent the card does not read as merged anyway, because
        -- celesta_bind lives on the host's ability rather than this one.
        local saved_center = card.config.center
        local saved_key = card.config.center_key
        local saved_ability = card.ability
        card.config.center = center
        card.config.center_key = bound.key
        card.ability = bound.ability

        local ok, err = pcall(misprintize_ref, card, override, force_reset,
                              stack, grow_type, pow_level)

        -- Cryptid REPLACES the table rather than editing it in place - the
        -- last line of misprintize_tbl is `ref_tbl[ref_value] = tbl`, where
        -- tbl is a deep copy. So the lent half's new ability has to be taken
        -- back off the card before it is handed its own one again, or the
        -- misprinted copy is simply dropped on the floor.
        local misprinted = card.ability

        card.config.center = saved_center
        card.config.center_key = saved_key
        card.ability = saved_ability

        if ok and type(misprinted) == "table" then bound.ability = misprinted end

        if not ok then
            CelestasMod.warn_once("bind_misprint_" .. tostring(bound.key),
                ("Bind could not misprint %s: %s"):format(tostring(bound.key), tostring(err)))
        end
        return ret
    end
end

-- Cryptid loads after this mod, so the hook cannot be installed at load time.
-- Installed BEFORE the reference runs rather than after: a saved run restores
-- its cards inside start_run, and those cards can be misprinted on the way in.
local celesta_bind_start_run_ref = Game.start_run
function Game:start_run(args)
    hook_cryptid_misprint()
    local ret = celesta_bind_start_run_ref(self, args)
    if G.jokers and G.jokers.config
        and (G.jokers.config.highlighted_limit or 1) < 2 then
        G.jokers.config.highlighted_limit = 2
    end
    return ret
end
