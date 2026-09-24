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
--- A quad-merged card is drawn larger, the same 1.2x Cryptid's Macabre Joker
--- uses (items/m.lua:1641). Not through Steamodded's `display_size`, which is
--- read off the CENTRE: a merged card wears its host's centre, and that table
--- is shared with every other copy of that Joker in the game - setting a size
--- on it would grow all of them.
Bind.QUAD_SCALE = 1.2

--- How many Jokers may be highlighted at once: four, which is a quad merge
--- made from four loose Jokers. See the note further down on why not more.
Bind.SELECT_LIMIT = 4

--- Puts a card at the size its merge calls for.
---
--- Written absolutely rather than as a multiply, so the repeated calls that
--- come from re-spriting cannot compound it.
function Bind.apply_size(card)
    if not (card and card.T and G.CARD_W and G.CARD_H) then return end
    if Bind.is_quad(card) then
        card.T.w = G.CARD_W * Bind.QUAD_SCALE
        card.T.h = G.CARD_H * Bind.QUAD_SCALE
    end
end

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

--- True for a card holding a QUAD - four Jokers rather than two.
---
--- `members` is what tells them apart, and it is only ever written by
--- Bind.merge_quad. A pair leaves it absent and every ordinary path below
--- carries on reading `key` the way it always did.
function Bind.is_quad(card)
    return Bind.is_merged(card)
        and type(card.ability.celesta_bind.members) == "table"
end

--- Every centre key a card carries: one loose, two merged, four quad-merged.
---
--- The one question the quad rules are written in terms of. "Can these be
--- merged" and "which group is this" are both about the MEMBERS of what was
--- selected, never about how many cards were selected - which is what makes
--- four loose Jokers, a pair and two loose ones, and two pairs the same case.
function Bind.members_of(card)
    if not (card and card.config) then return {} end
    local host = card.config.center_key
        or (card.config.center and card.config.center.key)
    if not host then return {} end
    if not Bind.is_merged(card) then return { host } end

    local bind = card.ability.celesta_bind
    if type(bind.members) == "table" then
        local out = {}
        for i, key in ipairs(bind.members) do out[i] = key end
        return out
    end
    return { host, bind.key }
end

--- The members of a whole selection, in the order the cards were given.
function Bind.group_members(cards)
    local out = {}
    for _, card in ipairs(cards or {}) do
        for _, key in ipairs(Bind.members_of(card)) do out[#out + 1] = key end
    end
    return out
end

--- The centre of the Joker bound into this one.
function Bind.partner_center(card)
    if not Bind.is_merged(card) then return nil end
    return G.P_CENTERS[card.ability.celesta_bind.key]
end

--- True for a Joker that Bind is willing to take as an ingredient.
---
--- A merged PAIR is now allowed, because a quad can be reached by merging two
--- of them - but only as an ingredient. Whether the result is anything is
--- decided by Bind.selection, which asks whether the members add up to a
--- registered quad; without that this would still be "merging merges nest
--- indefinitely", which is what it used to refuse outright.
---
--- A quad itself is refused. There is no fifth face, no group of five, and
--- nothing to make out of one.
function Bind.can_bind(card)
    if not (card and card.ability and card.config and card.config.center) then return false end
    if card.ability.set ~= "Joker" then return false end
    if Bind.is_quad(card) then return false end
    -- A centre may refuse outright. The Blank Joker does: its face is built
    -- from up to five layers at runtime, and there is no answer to what that
    -- looks like cut corner to corner, nor to what the pair's description says
    -- about properties it cannot know in advance.
    if card.config.center.celesta_no_bind then return false end
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
    -- Two loose Jokers is the ordinary merge, and always has been.
    if #picked == 2 and not Bind.is_merged(picked[1])
        and not Bind.is_merged(picked[2]) then
        return picked
    end

    -- Anything else is a quad or it is nothing. Two pairs, a pair and two
    -- loose Jokers, or four loose ones: all three are just "the members add
    -- up to a registered group", so there is one test rather than three.
    if #picked >= 2 and #picked <= 4
        and Bind.quad_for(Bind.group_members(picked)) then
        return picked
    end
    return nil
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
--- Merges a whole selection into a quad.
---
--- One path for all three routes in, because by the time this is reached they
--- are the same thing: a list of cards whose members add up to a registered
--- group. Whether those members arrived as four loose Jokers, as a pair and
--- two loose ones or as two pairs has already stopped mattering.
---
--- The host is cards[1]; the caller puts the leftmost card there, the way the
--- ordinary merge does, so the group lands where the player expects it.
function Bind.merge_quad(cards)
    local members = Bind.group_members(cards)
    local def = Bind.quad_for(members)
    if not def then return false end
    for _, card in ipairs(cards) do
        if not Bind.can_bind(card) then return false end
    end

    local host = cards[1]
    local abilities, edition = {}, host.edition

    -- Each member's ability, copied for the same reason the ordinary merge
    -- copies one: the cards these came off are about to be destroyed.
    for _, card in ipairs(cards) do
        local own = Bind.members_of(card)
        local bind = card.ability.celesta_bind
        for index = 1, #own do
            local source = (index == 1) and card.ability
                or (bind and bind.ability)
            local carried = copy_table(source or {})
            if type((source or {}).extra) == "table" then
                carried.extra = copy_table(source.extra)
            end
            carried.celesta_bind = nil
            for _, ledger in ipairs(CelestasMod.GRANT_LEDGERS or {}) do
                carried[ledger] = nil
            end
            abilities[#abilities + 1] = carried
        end
        if card ~= host then
            edition = Bind.resolve_edition(edition, card.edition)
        end
    end

    -- Stickers are inherited from every member, for the reason the ordinary
    -- merge inherits them from one: a merge cannot be a way to launder an
    -- Eternal Joker into a sellable one.
    local total = 0
    for _, card in ipairs(cards) do
        total = total + (card.sell_cost or 0)
        for _, sticker in ipairs({ "eternal", "perishable", "rental" }) do
            if card.ability[sticker] then host.ability[sticker] = card.ability[sticker] end
        end
        if card.ability.perish_tally and (not host.ability.perish_tally
            or card.ability.perish_tally < host.ability.perish_tally) then
            host.ability.perish_tally = card.ability.perish_tally
        end
    end

    -- `key` stays set to the second member so that everything reading a pair
    -- - is_merged, the sell-cost split, the art's fallback - keeps working on
    -- a quad without being taught about one.
    host.ability.celesta_bind = {
        key = members[2],
        ability = abilities[2],
        members = members,
        member_abilities = abilities,
        host_sell_cost = host.sell_cost,
        sell_cost = total - (host.sell_cost or 0),
    }
    host.sell_cost = total

    host:set_edition(edition, true, true)
    host.cry_flipped = nil

    Bind.invalidate_art(host)
    Bind.apply_size(host)
    Bind.mark_special_seen(def.key)

    -- A quad replaces all four, so whatever the host was granting as itself
    -- comes off - the group speaks for the card now. The others hand theirs
    -- back on the way out, through their own remove_from_deck.
    Bind.remove_own_passive(host)

    if type(def.on_merge) == "function" then
        local ok, err = pcall(def.on_merge, def, host, Bind.special_state(host, def))
        if not ok then
            CelestasMod.warn_once("bind_merge_" .. tostring(def.key),
                ("Quad merge %s failed to form: %s"):format(tostring(def.key),
                                                            tostring(err)))
        end
    end

    if CelestasMod.play_join_sound then
        for _, key in ipairs(members) do CelestasMod.play_join_sound(key) end
    end

    for _, card in ipairs(cards) do
        if card ~= host then
            card.ability.eternal = nil
            card:start_dissolve(nil, true)
        end
    end
    return true
end

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

    -- Nor can a receipt for something the RUN is holding. The absorbed card is
    -- about to dissolve, and its remove_from_deck hands back every slot and
    -- limit it granted; carrying the record of that across would leave the
    -- host believing it had already given what has just been taken back, so it
    -- would grant nothing. See CelestasMod.GRANT_LEDGERS in globals.lua.
    for _, ledger in ipairs(CelestasMod.GRANT_LEDGERS or {}) do
        carried[ledger] = nil
    end

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
        if Bind.replacing_special(host) then
            local center = host.config.center
            if type(center) == "table" and type(center.remove_from_deck) == "function" then
                pcall(center.remove_from_deck, center, host, false)
            end
            -- ...and its ability-driven ones, for the same reason: the pair
            -- speaks for the card now, so a hand size or a discard the host
            -- brought with it is no longer being granted by anything.
            --
            -- Through the table, not the local: that is declared with the rest
            -- of the passive hooks two thousand lines below this, so the bare
            -- name here would compile as a global and be nil. Same reason
            -- Bind.apply_partner_passive is reached that way above.
            Bind.intrinsic_passive(host.ability, -1)
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
--- all - a passive, a slot, a hand size. They are called once each, at the two
--- moments the pair comes into and goes out of existence: on_merge with
--- (def, card, state), and on_unmerge with (def, card, state, losing), where
--- `losing` is "host" or "partner" - the half that is leaving. It is passed
--- because the centre swap has not happened yet, so a pair that has to hand
--- something back to the SURVIVOR cannot read which one that is off the card. Everything in between is the card's own: a passive written onto
--- card.ability is applied and removed by vanilla's own add_to_deck and
--- remove_from_deck, so selling, debuffing and destroying the merge all work
--- without either hook being involved.
local function special(key_a, key_b, def)
    -- Kept on the def so anything listing the pairs - the collection tab - can
    -- name both halves without picking the joined key back apart.
    def.halves = { key_a, key_b }
    Bind.SPECIALS[pair_key(key_a, key_b)] = def
end

--- The quad merges, keyed by their four centre keys sorted and joined.
---
--- Sorted, so the order the four were merged in never matters - which it
--- cannot, when the same group can be reached by three different routes.
Bind.QUADS = {}

local function quad_key(keys)
    local sorted = {}
    for i, key in ipairs(keys) do sorted[i] = key end
    table.sort(sorted)
    return table.concat(sorted, "|")
end

--- def = the same shape as a special, plus `members`: the four centre keys.
--- Quads are always replacing - the group has a name and an ability of its
--- own, and none of the four speaks for itself any more.
local function quad(def)
    assert(type(def.members) == "table" and #def.members == 4,
        "a quad merge has exactly four members")
    def.is_quad = true
    -- Named `halves` for the collection tab, which asks every special for the
    -- Jokers it is made of and does not care how many there are.
    def.halves = def.members
    Bind.QUADS[quad_key(def.members)] = def
end

--- The quad these keys make, if they make one. Four keys, and a group that
--- was registered: anything else is not a quad and cannot be merged into one.
function Bind.quad_for(keys)
    if type(keys) ~= "table" or #keys ~= 4 then return nil end
    return Bind.QUADS[quad_key(keys)]
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

--- The pair an ABSORBED half is running under, while it is running.
---
--- with_partner swaps card.ability to the absorbed half's own for the length
--- of its call, and that table has no celesta_bind in it - so a half asking
--- Bind.special_of(card) about its own merge, from inside that call, was told
--- there was no merge at all. An additive pair is a flag its halves read
--- exactly that way (Camila's three, jokers/implemented.lua), so the flag was
--- there for the host and gone for the absorbed one, and which half the player
--- merged into which decided whether the pair did anything.
---
--- Weak-keyed, and written only for the length of a partner call.
local partner_special = setmetatable({}, { __mode = "k" })

--- The special governing this merge, if the pair has one.
---
--- A named pair is looked up first and wins outright: a wildcard says "any
--- Joker from this mod", and a pair that names both halves is by definition
--- the more specific answer.
function Bind.special_of(card)
    -- An absorbed half mid-call: its own ability is in place, so the merge is
    -- not visible on the card and the answer is the one recorded for it.
    if not Bind.is_merged(card) then return partner_special[card] end

    -- A quad answers for itself. Its members are four, so no pair key and no
    -- wildcard could match them anyway, but asking first keeps the two kinds
    -- of merge from ever being confused for one another.
    if Bind.is_quad(card) then
        return Bind.quad_for(card.ability.celesta_bind.members)
    end

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
                            -- Under unjudged, for the reason FeFe gives: these
                            -- are played cards, and the event runs while they
                            -- still carry played_this_ante.
                            CelestasMod.unjudged(target, function()
                                target:set_ability(G.P_CENTERS[enhancement], nil, true)
                            end)
                            return true
                        end
                    })
                    touched = touched + 1
                end
            end
        end

        if touched > 0 then
            return {
                message = localize("celesta_plus_enhancement"),
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
        -- not end_of_round: SMODS raises the held-in-hand individual pass
        -- again at the cash-out, where there is no score for the Mult to join
        -- and the X2 would pop on every held Steel Card for nothing.
        if context.individual and context.other_card
            and not context.end_of_round
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
        -- A copy duplicates too. This pair replaces both halves, so the
        -- duplicate is the whole of what the merged card does - a Mari Yume,
        -- Blueprint or Brainstorm pointed at it had nothing else to copy, and
        -- refusing context.blueprint left them doing nothing at all. The copy
        -- is Negative, so a second one needs no room.
        if not context.ending_shop then return end

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

-- Rosedoodle + Buffpup: Rosedoodle's coin flip, on Buffpup's suit.
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
            return { message = localize("celesta_plus_enhancement"),
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

-- Drunkard + Juggler: one gives a discard, the other a card in hand. Together
-- each of them doubles, and each half gets what the other had.
--
-- The first special whose BOTH halves carry an intrinsic passive - h_size and
-- d_size are read straight off self.ability by Card:add_to_deck and undone by
-- remove_from_deck (card.lua:759, :762), rather than living in a centre hook.
-- So the fields are written onto the card and vanilla handles selling,
-- debuffing and destroying the merge from there.
--
-- SET, not added to. Juggler's h_size and Drunkard's d_size are the whole of
-- what those two Jokers are, and the host's is still sitting on the card when
-- the pair forms - Bind.remove_own_passive reverses its EFFECT but leaves the
-- field. Adding to it would leave the field higher than what is actually
-- applied, and the next debuff or sale would take back more than was given.
--
-- The live change goes through Bind.intrinsic_passive rather than being
-- written out, so it obeys the same rules vanilla does - including that a
-- d_size is only ever applied when it is positive.
special("j_drunkard", "j_juggler", {
    key = "drunkard_juggler",
    config = { h_size = 2, d_size = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.h_size, state.d_size } }
    end,

    on_merge = function(def, card, state)
        card.ability.h_size = state.h_size
        card.ability.d_size = state.d_size
        Bind.intrinsic_passive(
            { h_size = state.h_size, d_size = state.d_size }, 1)
    end,

    on_unmerge = function(def, card, state, losing)
        Bind.intrinsic_passive(
            { h_size = state.h_size, d_size = state.d_size }, -1)

        -- ...and the survivor goes back to being itself, with its own number
        -- applied again. Nothing else does this: a split is not leaving the
        -- deck, so neither vanilla hook runs, and the host's own passive was
        -- taken off when the pair formed.
        --
        -- Which half survives cannot be read off the card here - the centre
        -- swap happens after this returns - so `losing` is what says.
        local surviving
        if losing == "host" then
            -- The absorbed half's saved ability becomes the card's, numbers
            -- and all, so there is nothing to write: only to apply.
            surviving = card.ability.celesta_bind
                and card.ability.celesta_bind.ability
        else
            surviving = card.ability
            local center = card.config.center
            local config = (type(center) == "table" and center.config) or {}
            surviving.h_size = config.h_size or 0
            surviving.d_size = config.d_size or 0
        end
        if surviving then Bind.intrinsic_passive(surviving, 1) end
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

-- Deme + LucyPyre: Deme counts consecutive single-card hands and LucyPyre
-- shrinks the Blind, so together the streak IS the reduction.
--
-- A replacing pair, which is what makes it start at nothing: the merged card
-- is no longer a LucyPyre as far as the quota lookup is concerned, so the flat
-- 10% is gone and two single-card hands buy it back. Deme's X Mult goes with
-- it. That is the trade - a fixed discount for one with no ceiling.
--
-- The streak is Deme's own shape, down to the reset: context.before sees the
-- whole hand ahead of scoring, so a hand that extends the streak counts for
-- itself, and a hand of anything other than one card clears it.
--
-- What it earns is spent at the NEXT Blind, not this one. get_blind_amount is
-- asked once when a Blind is set, and nothing re-asks it mid-round.
special("j_celesta_demenishki", "j_celesta_lucypyre", {
    key = "deme_lucypyre",
    config = { percent = 0, percent_gain = 5 },

    loc_vars = function(def, card, state)
        return { vars = { state.percent_gain, state.percent } }
    end,

    calculate = function(def, card, context, state)
        if context.before and not context.blueprint then
            if #context.full_hand == 1 then
                state.percent = state.percent + state.percent_gain
                return {
                    message = localize { type = "variable",
                                         key = "celesta_blind_percent",
                                         vars = { state.percent } },
                    colour = G.C.BLUE, card = card,
                }
            elseif state.percent > 0 then
                state.percent = 0
                return { message = localize("k_reset"), colour = G.C.RED,
                         card = card }
            end
        end
    end,
})

--- What a merge is multiplying every Blind's quota by.
---
--- Named for what it does rather than for the pair behind it, so the quota
--- hook in jokers/implemented.lua can ask without knowing that merges exist -
--- the same way seals/seals.lua asks star_seal_copies.
---
--- Clamped at zero. The streak has no ceiling, so twenty single-card hands
--- take the reduction past 100% and the multiplier through zero into negative
--- numbers; a Blind worth nothing is the reward that was earned, a Blind worth
--- less than nothing is a scoring comparison nobody wrote.
function CelestasMod.bind_blind_scale()
    local scale = 1
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        local def = Bind.special_of(held)
        if def and def.key == "deme_lucypyre" and not held.debuff then
            local percent = Bind.special_state(held, def).percent or 0
            scale = scale * (1 - percent / 100)
        end
    end
    return math.max(0, scale)
end

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
--
-- `editioned` is true for a rolled edition, or an edition table - { foil =
-- true } - for one that is always the same.
local function koko_sevens(card, count, seed, editioned, seal)
    if count <= 0 then return end
    G.E_MANAGER:add_event(Event {
        func = function()
            local made = {}
            for i = 1, count do
                local seven = create_playing_card(
                    { front = G.P_CARDS.S_7, center = G.P_CENTERS.m_lucky },
                    G.play, nil, nil, { G.C.SECONDARY_SET.Enhanced })
                if type(editioned) == "table" then
                    seven:set_edition(editioned, true)
                elseif editioned then
                    -- Guaranteed, and never Negative: a Negative playing card
                    -- does nothing in vanilla, so rolling one would read as
                    -- the Joker having failed rather than as an edition.
                    local edition = poll_edition(seed .. "_ed" .. i, nil, true, true)
                    if edition then seven:set_edition(edition, true) end
                end
                if seal then seven:set_seal(seal, nil, true) end
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

-- Shared with vgn in jokers/lost.lua, which makes seventeen at a time.
CelestasMod.koko_sevens = koko_sevens

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

-- Camila + KokoNuts: KokoNuts deals in Sevens of Spades and Camila hands
-- editions back. A hand that is all Spades and adds up to seventeen becomes
-- Lucky and Polychrome, every card of it.
--
-- Seventeen is read off base.nominal - the card's CHIP value, so an Ace is 11
-- and a face is 10 - which is what "sum" means for a hand of cards and what
-- AxialMatt already reads a rank as. Seven and Ten, or two Sevens and a Three.

--- The sum of a scoring hand, or nil when it is not all one suit.
local function spade_total(scoring, suit)
    if type(scoring) ~= "table" or #scoring == 0 then return nil end
    local total = 0
    for _, played in ipairs(scoring) do
        if not (played.is_suit and played:is_suit(suit)) then return nil end
        total = total + ((played.base and played.base.nominal) or 0)
    end
    return total
end

special("j_celesta_camila", "j_celesta_kokonuts", {
    key = "camila_koko",
    config = { total = 17 },

    loc_vars = function(def, card, state)
        return { vars = { state.total } }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint) then return end
        if spade_total(context.scoring_hand, "Spades") ~= state.total then return end

        local touched = 0
        for _, played in ipairs(context.scoring_hand) do
            local target = played
            touched = touched + 1
            G.E_MANAGER:add_event(Event {
                func = function()
                    -- Card:set_ability ends with G.GAME.blind:debuff_card, and
                    -- The Pillar debuffs anything already played this Ante -
                    -- which every card in this hand was, moments ago. Without
                    -- this the reward would kill the hand it rewarded.
                    CelestasMod.unjudged(target, function()
                        target:set_ability(G.P_CENTERS.m_lucky, nil, true)
                    end)
                    target:set_edition({ polychrome = true }, true)
                    target:juice_up(0.3, 0.5)
                    return true
                end
            })
        end

        if touched > 0 then
            return { message = localize("k_upgrade_ex"),
                     colour = G.C.SECONDARY_SET.Enhanced, card = card }
        end
    end,
})

-- SonneFlower + Birdyovo: SonneFlower is the Leaf suit's, Birdyovo counts
-- scored cards. This counts Leaves, and keeps counting only while they keep
-- coming.
--
-- The streak is per HAND, not per card: a hand with no Leaf in it resets the
-- whole thing, and a hand with three adds three lots. Read in context.before,
-- which sees the scoring hand whole and lands before any of it scores, so a
-- hand that extends the streak is paid for itself.
special("j_celesta_sonneflower", "j_celesta_birdyovo", {
    key = "sonne_birdy",
    config = { x_mult = 1, x_mult_gain = 0.7 },

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR, true)
        return { vars = { state.x_mult_gain, state.x_mult, name,
                          colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if context.before and not context.blueprint then
            local leaves = 0
            for _, played in ipairs(context.scoring_hand or {}) do
                if played.is_suit and played:is_suit(CelestasMod.LEAF_SUIT) then
                    leaves = leaves + 1
                end
            end

            if leaves == 0 then
                if state.x_mult <= 1 then return end
                state.x_mult = 1
                return { message = localize("k_reset"), colour = G.C.RED,
                         card = card }
            end

            state.x_mult = state.x_mult + state.x_mult_gain * leaves
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { state.x_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- Arielle + Ironmouse: every card counts as every suit, and every card counts.
--
-- ^Mult, so it needs Talisman, and the check is made at score time rather than
-- at load for the reason Vienna gives - mods load in priority order, and
-- Talisman may not have run when this file did. Card.get_chip_e_mult is the
-- method Talisman adds and nothing else does.
special("j_celesta_arielle", "j_celesta_ironmouse", {
    key = "arielle_ironmouse",
    config = { e_mult = 1, e_mult_gain = 0.03 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_mult_gain, state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        -- Counted per scored card. An unscored card arrives as 'unscored', and
        -- the end-of-round pass over the hand is G.hand, so neither reaches it.
        if context.individual and context.cardarea == G.play
            and not context.blueprint then
            state.e_mult = state.e_mult + state.e_mult_gain
            return {
                message = localize { type = "variable", key = "celesta_powmult",
                                     vars = { state.e_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main and state.e_mult > 1 then
            if Card.get_chip_e_mult == nil then
                CelestasMod.warn_once("arielle_ironmouse_no_talisman",
                    "Arielle + Ironmouse scores ^Mult, which needs Talisman; "
                    .. "without it the pair does nothing")
                return
            end
            return { e_mult = state.e_mult }
        end
    end,
})

-- Yharon + Yharon: the ceiling moves up one, from exponentiation to tetration.
--
-- Additive, and it has to be: what the pair changes is the CAP on a promotion
-- Yharon itself performs, so both halves have to keep running. A replacing
-- pair would switch off the very thing it is raising the ceiling of.
--
-- The cap itself is read off the card in jokers/yharon.lua rather than out of
-- this state, because both halves of the merge answer the question and they
-- have to answer it the same way. This entry exists so the pair has a name and
-- a description in the Collection, which is where a player finds out that two
-- of them are worth merging at all.
special("j_celesta_yharon", "j_celesta_yharon", {
    key = "yharon_yharon",
    additive = true,

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state) end,
})

--------------------------------------------------------------------------------
-- The second batch
--------------------------------------------------------------------------------
--
-- Each of these stands in for both halves, like every pair above that is not
-- marked additive: an Arielle bound into one of them no longer makes every
-- card every suit, and a Jaws in one no longer eats anything.

--- True while a Downpour is up.
local function raining()
    local Arena = CelestasMod.Arena
    return (Arena and Arena.is_active and Arena.is_active("downpour")) and true or false
end

--- Aquwa's opening move, for the three pairs that keep it: a Downpour at the
--- moment the Blind is chosen, before a card is dealt, so it is up for the
--- whole round. The Arena clears itself on the way back to Blind select.
local function open_with_downpour(card, context)
    if not (context.setting_blind and not context.blueprint) then return nil end
    local Arena = CelestasMod.Arena
    if raining() or not (Arena and Arena.start) then return nil end
    Arena.start("downpour")
    return { message = localize("celesta_downpour"), colour = G.C.BLUE, card = card }
end

--- How many consumable slots the run has - the tray's size, not how full it is.
local function consumable_slots()
    local area = G.consumeables
    local limit = area and area.config and area.config.card_limit
    return type(limit) == "number" and limit or 0
end

-- Arielle + FroggyLoch: FroggyLoch's retrigger, rolled at better odds and
-- paid out three times over.
special("j_celesta_arielle", "j_celesta_froggyloch", {
    key = "arielle_froggy",
    config = { odds = 2, repetitions = 3 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_arielle_froggy")
        return { vars = { n, d, state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_arielle_froggy",
                1, state.odds, "celesta_bind_arielle_froggy") then return end
        return {
            message = localize("k_again_ex"),
            repetitions = state.repetitions,
            card = card,
        }
    end,
})

-- Arielle + Haruka Karibu: a Tarot card leaves an edition behind on what it
-- touched. Nothing in the calculate pass says what a Tarot was used ON, so
-- this one is done from Card:use_consumeable - see the hooks further down.
special("j_celesta_arielle", "j_celesta_harukakaribu", {
    key = "arielle_haruka",
    config = { odds = 2 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_arielle_haruka")
        return { vars = { n, d } }
    end,

    calculate = function(def, card, context, state) end,
})

-- Aquwa + Megalodon: Megalodon's hunger, doubled while it is raining.
special("j_celesta_aquwa", "j_celesta_megalodon", {
    key = "aquwa_megalodon",
    config = { mult = 0, mult_gain = 5, rain_scale = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.mult_gain, state.rain_scale, state.mult } }
    end,

    calculate = function(def, card, context, state)
        -- context.before carries full_hand: every card played, not just the
        -- scoring ones, and it lands ahead of scoring so the hand that fed the
        -- Joker is the first to be paid by it.
        if context.before and not context.blueprint then
            local played = #(context.full_hand or {})
            if played > 0 then
                local per = state.mult_gain * (raining() and state.rain_scale or 1)
                state.mult = state.mult + per * played
                return {
                    message = localize { type = "variable", key = "a_mult",
                                         vars = { state.mult } },
                    colour = G.C.MULT,
                    card = card,
                }
            end
        end

        if context.joker_main and state.mult > 0 then
            return { mult = state.mult }
        end

        -- main_eval is the once-a-round pass; without it the reset would also
        -- run for every card the end of the round looks at.
        if context.end_of_round and context.main_eval and not context.blueprint
            and state.mult > 0 then
            state.mult = 0
            return { message = localize("k_reset"), colour = G.C.MULT, card = card }
        end
    end,
})

-- Aquwa + Yuy: Aquwa's Downpour and Yuy's last hand, both.
special("j_celesta_aquwa", "j_celesta_yuy_ix", {
    key = "aquwa_yuy",
    config = { x_mult = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        local rain = open_with_downpour(card, context)
        if rain then return rain end

        -- hands_left == 0 is how Yuy and vanilla Dusk both know the final
        -- hand: it is decremented before the hand scores.
        if context.individual and context.cardarea == G.play
            and G.GAME.current_round and G.GAME.current_round.hands_left == 0 then
            return { x_mult = state.x_mult, colour = G.C.RED, card = card }
        end
    end,
})

-- CottontailVA + LaynaLazar: LaynaLazar goes looking for Mult cards;
-- Cottontail seals them. Every one, with no roll - and, like Cottontail, only
-- a card with no seal already, so a Red or a Gold is never traded away.
special("j_celesta_cottontail", "j_celesta_laynalazar", {
    key = "cottontail_layna",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        if not (other and not other.seal
                and SMODS.has_enhancement(other, "m_mult")) then return end
        other:set_seal(CelestasMod.SEAL_KEYS.Star, nil, true)
        return { message = localize("celesta_sealed"), colour = G.C.PURPLE, card = card }
    end,
})

-- Aquwa + Nekrolina: a Downpour turns every consumable that arrives in the
-- round Negative (arena.lua), and this is paid for each Negative consumable
-- that arrives - the Downpour's own and any other. The payment is made where
-- the card lands in the tray; see the hooks further down.
special("j_celesta_aquwa", "j_celesta_nekrolina", {
    key = "aquwa_nekrolina",
    config = { dollars = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = function(def, card, context, state)
        return open_with_downpour(card, context)
    end,
})

-- BerryCrepe + Shoomimi: BerryCrepe's permanent Mult, sized by how much room
-- Shoomimi has made in the consumable tray. Read when each card scores, so a
-- slot gained mid-run counts from the next card on.
special("j_celesta_berrycrepe", "j_celesta_shoomimi", {
    key = "berry_shoomimi",

    loc_vars = function(def, card, state)
        return { vars = { consumable_slots() } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        local gain = consumable_slots()
        if not other or gain <= 0 then return end
        -- perma_mult is scored by Card:get_chip_mult and printed on the card
        -- as "+N Mult" by the game, the same field BerryCrepe writes.
        other.ability.perma_mult = (other.ability.perma_mult or 0) + gain
        return {
            extra = {
                message = localize { type = "variable", key = "a_mult",
                                     vars = { other.ability.perma_mult } },
                colour = G.C.MULT,
            },
            card = other,
        }
    end,
})

-- BerryCrepe + Chrchie: BerryCrepe's permanent bonus, in money.
--
-- perma_p_dollars is the money twin of the perma_mult BerryCrepe writes: the
-- game pays it every time the card scores (card.lua:1321, get_p_dollars) and
-- prints it on the card, so nothing here has to pay anything. Like
-- BerryCrepe's Mult, a gain lands after the card's own payout for this
-- scoring, and is paid from the card's next one.
special("j_celesta_berrycrepe", "j_celesta_chrchie", {
    key = "berry_chrchie",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        if not other then return end
        other.ability.perma_p_dollars = (other.ability.perma_p_dollars or 0) + state.dollars
        return {
            extra = {
                message = localize("$") .. other.ability.perma_p_dollars,
                colour = G.C.MONEY,
            },
            card = other,
        }
    end,
})

-- Shoomimi + Chrchie: paid at the cash-out, per consumable slot. Through
-- calc_dollar_bonus, like Zentreya + Ruben above, so it gets its own line on
-- the cash-out screen.
special("j_celesta_shoomimi", "j_celesta_chrchie", {
    key = "shoomimi_chrchie",
    config = { per_slot = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.per_slot, state.per_slot * consumable_slots() } }
    end,

    calc_dollar_bonus = function(def, card, state)
        local total = state.per_slot * consumable_slots()
        if total <= 0 then return end
        return total
    end,

    calculate = function(def, card, context, state) end,
})

-- Jaws + Liffeh: a Tarot out of the wreckage. remove_playing_cards fires once
-- after the destroy pass with every card that died, so this catches a Glass
-- Card shattering and another Joker eating something the same way - and it is
-- one roll per card, so three at once are three chances.
special("j_celesta_jaws", "j_celesta_liffeh", {
    key = "jaws_liffeh",
    config = { odds = 5 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_jaws_liffeh")
        return { vars = { n, d } }
    end,

    calculate = function(def, card, context, state)
        if not (context.remove_playing_cards and not context.blueprint) then return end

        local made = 0
        for _ in ipairs(context.removed or {}) do
            -- Rolled before the room is asked for, so a full tray costs the
            -- roll rather than banking it.
            if SMODS.pseudorandom_probability(card, "celesta_bind_jaws_liffeh",
                    1, state.odds, "celesta_bind_jaws_liffeh")
                and bind_consumable_room() then
                made = made + 1
                G.GAME.consumeable_buffer = (G.GAME.consumeable_buffer or 0) + 1
                G.E_MANAGER:add_event(Event {
                    trigger = "before", delay = 0.0,
                    func = function()
                        local tarot = SMODS.add_card {
                            set = "Tarot", key_append = "celesta_bind_jaws_liffeh" }
                        if tarot then tarot:juice_up(0.3, 0.5) end
                        G.GAME.consumeable_buffer =
                            math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
                        return true
                    end
                })
            end
        end

        if made > 0 then
            return { message = localize("k_plus_tarot"), colour = G.C.PURPLE, card = card }
        end
    end,
})

-- CottontailVA + Kumi: Cottontail's Star Seals, cashed in on the cards that
-- did NOT score. A non-scoring played card reaches a Joker through the same
-- individual pass as a scoring one, with cardarea set to the string 'unscored'
-- rather than G.play (SMODS utils.lua:1993).
--
-- The dollars are returned rather than eased on: `dollars` is one of the keys
-- SMODS pays out itself, and it raises the "+$8" of its own accord - a message
-- alongside it would be a second popup saying the same thing.
special("j_celesta_cottontail", "j_celesta_kumi", {
    key = "cottontail_kumi",
    config = { odds = 4, dollars = 8 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_cottontail_kumi")
        return { vars = { n, d, state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == "unscored") then return end
        local other = context.other_card
        if not (other and other.seal == CelestasMod.SEAL_KEYS.Star) then return end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_cottontail_kumi",
                1, state.odds, "celesta_bind_cottontail_kumi") then return end
        return { dollars = state.dollars, card = card }
    end,
})

-- Arielle + Nagzz: Nagzz turned the other way. Nagzz alone halves every listed
-- chance by doubling its denominator; bound to Arielle, every chance is
-- raised instead, and a Lucky Card's twice as far again.
--
-- The numerator is the half that moves, which is what makes it "1 in 2"
-- becoming "2 in 2" rather than a fraction. Only a number is multiplied, or a
-- Talisman big number: the denominator of a chance is whatever the card
-- asking passed in, and Cryptid's RNJoker passes a sentence.
special("j_celesta_arielle", "j_celesta_nagzz", {
    key = "arielle_nagzz",
    config = { scale = 2, lucky_scale = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.scale, state.lucky_scale } }
    end,

    calculate = function(def, card, context, state)
        if not context.mod_probability then return end
        local n = context.numerator or 1
        local meta = type(n) == "table" and getmetatable(n)
        if type(n) ~= "number" and not (meta and meta.__mul) then return end

        local roller = context.trigger_obj
        local lucky = roller and roller.ability
            and SMODS.has_enhancement(roller, "m_lucky")
        return { numerator = n * (lucky and state.lucky_scale or state.scale) }
    end,
})

--------------------------------------------------------------------------------
-- The third batch
--------------------------------------------------------------------------------

--- Chips scored so far, as a number this can divide - or nil past what a Lua
--- number holds, where Talisman's arithmetic is the only thing that can still
--- answer. Kourra asks the same question of the same variable.
local function chips_so_far()
    local chips = hand_chips or 0
    if type(chips) == "number" then return chips end
    return nil
end

-- Arar + Kumi: Kumi eats the Gold cards; with Arar, which enhances cards to
-- begin with, it eats every enhanced card in the hand.
--
-- destroying_card is only raised for cards that are both in G.play and part of
-- the scoring hand, so this is already "scoring cards" only. `remove` and
-- `dollars` are both keys SMODS acts on, so one table destroys the card and
-- pays for it at once - Kumi's own shape.
special("j_celesta_arar", "j_celesta_kumi", {
    key = "arar_kumi",
    config = { odds = 4, dollars = 20 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_arar_kumi")
        return { vars = { n, d, state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if not (context.destroying_card and context.cardarea == G.play) then return end
        local target = context.destroying_card

        -- Enhanced at all, rather than Gold. c_base is the unenhanced centre.
        local center = target.config and target.config.center
        if not center or center == G.P_CENTERS.c_base then return end

        -- calculate_destroying_cards acts on `remove` without checking eternal
        -- itself, so it is checked here or the pair eats eternal cards.
        if SMODS.is_eternal(target) then return end

        local effect = { remove = true }
        if SMODS.pseudorandom_probability(card, "celesta_bind_arar_kumi",
                1, state.odds, "celesta_bind_arar_kumi") then
            effect.dollars = state.dollars
        end
        return effect
    end,
})

-- Beepers + HeavenlyFather: Beepers hands out seals; this hands out a seal and
-- the enhancement under it, to the one rank that wants both.
special("j_celesta_beepers", "j_celesta_heavenlyfather", {
    key = "beepers_heavenly",
    config = { odds = 4 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_beepers_heavenly")
        return { vars = { n, d } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        -- get_id is the rank question every Joker asks, and it is the one
        -- Grandpaw Shao widens - so a King by Shao's reckoning is a King here.
        if not (other and other.get_id and other:get_id() == 13) then return end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_beepers_heavenly",
                1, state.odds, "celesta_bind_beepers_heavenly") then return end

        -- Under unjudged, for the reason FeFe gives.
        CelestasMod.unjudged(other, function()
            other:set_ability(G.P_CENTERS.m_steel, nil, true)
        end)
        other:set_seal("Red", nil, true)
        return { message = localize("celesta_sealed"), colour = G.C.PURPLE, card = card }
    end,
})

-- Kumi + BerryCrepe: BerryCrepe's permanent Mult, paid onto the cards Kumi
-- cares about - and Kumi's payout, without the destruction.
special("j_celesta_kumi", "j_celesta_berrycrepe", {
    key = "kumi_berry",
    config = { mult = 2, odds = 8, dollars = 20 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_kumi_berry")
        return { vars = { state.mult, n, d, state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        if not (other and SMODS.has_enhancement(other, "m_gold")) then return end

        other.ability.perma_mult = (other.ability.perma_mult or 0) + state.mult

        local effect = {
            extra = {
                message = localize { type = "variable", key = "a_mult",
                                     vars = { other.ability.perma_mult } },
                colour = G.C.MULT,
            },
            card = other,
        }
        if SMODS.pseudorandom_probability(card, "celesta_bind_kumi_berry",
                1, state.odds, "celesta_bind_kumi_berry") then
            effect.dollars = state.dollars
        end
        return effect
    end,
})

-- Birdyovo + Kourra: Kourra counts the Chips of the hand so far and pays Mult
-- per fifty; bound to Birdyovo, which multiplies, each fifty multiplies.
--
-- Every step is a multiplication, so the number climbs fast. With Talisman -
-- a declared dependency - it climbs into Talisman's own numbers and stays
-- exact. Without it the exponent is held where a Lua number still is one:
-- 1.2^3700 is about 1e293, and inf on a card reads as a broken Joker.
local KOURRA_SAFE_STEPS = 3700

special("j_celesta_birdyovo", "j_celesta_kourra", {
    key = "birdyovo_kourra",
    config = { x_mult = 1.2, per_chips = 50 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult, state.per_chips } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end

        local chips = chips_so_far()
        if chips then
            local steps = math.floor(chips / state.per_chips)
            if steps <= 0 then return end
            if to_big then
                return { x_mult = to_big(state.x_mult) ^ steps }
            end
            return { x_mult = state.x_mult ^ math.min(steps, KOURRA_SAFE_STEPS) }
        end

        -- Past a Lua number entirely, which only Talisman can have made.
        if to_big then
            local steps = to_big(hand_chips) / state.per_chips
            return { x_mult = to_big(state.x_mult) ^ steps }
        end
    end,
})

-- SonneFlower + Kourra: SonneFlower watches for Leaf cards and Kourra counts,
-- so this counts the Leaves.
special("j_celesta_sonneflower", "j_celesta_kourra", {
    key = "sonne_kourra",
    config = { mult = 2 },

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR)
        return { vars = { state.mult, name, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end

        local leaves = 0
        for _, scored in ipairs(context.scoring_hand or {}) do
            if scored.is_suit and scored:is_suit(CelestasMod.LEAF_SUIT) then
                leaves = leaves + 1
            end
        end
        if leaves <= 0 then return end
        return { mult = leaves * state.mult }
    end,
})

-- Buffpup + Shiabun: Buffpup reads the Leaf cards in the deck and Shiabun
-- hands out selection, so the deck decides how much selection. Granted from
-- the sync below rather than from here: the number moves as the deck does.
special("j_celesta_buffpup", "j_celesta_shiabun", {
    key = "buffpup_shiabun",
    config = { per = 6 },

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR)
        return { vars = { state.per, name,
                          CelestasMod.count_suit_in_deck(CelestasMod.LEAF_SUIT),
                          colours = { colour } } }
    end,

    calculate = function(def, card, context, state) end,
})

-- Arielle + Shiabun: Arielle is about suits and Shiabun about selection, so
-- the deck's variety decides how much selection.
special("j_celesta_arielle", "j_celesta_shiabun", {
    key = "arielle_shiabun",
    config = { per = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.per, CelestasMod.unique_suits_in_deck() } }
    end,

    calculate = function(def, card, context, state) end,
})

-- Arar + Occi: Arar changes a card held in hand at the start of the round and
-- Occi turns cards into Aces of Spades, so this turns one.
--
-- first_hand_drawn is the moment the opening hand is on the table, which is
-- the only "start of the round" where there is a hand to reach into. Arar's
-- own effect uses it for the same reason.
special("j_celesta_arar", "j_celesta_occi", {
    key = "arar_occi",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.first_hand_drawn and not context.blueprint) then return end
        if not (G.hand and G.hand.cards and #G.hand.cards > 0) then return end

        -- Any card in hand, Ace of Spades or not: the roll is what it is, and
        -- filtering would make a hand of Aces re-roll forever.
        local target = pseudorandom_element(G.hand.cards,
            pseudoseed("celesta_bind_arar_occi"))
        if not target then return end

        SMODS.change_base(target, "Spades", "Ace")
        G.E_MANAGER:add_event(Event {
            func = function() target:juice_up() return true end
        })
        return { message = localize("celesta_aces"), colour = G.C.SPADES, card = card }
    end,
})

-- Arielle + Grandpaw Shao: Arielle makes every card the same suit and Shao
-- makes the numbers Aces; together every card is the same card.
--
-- Both halves of that are questions the game asks constantly - is this card
-- that suit, what rank is this card - so both are answered in the hooks
-- below, where Arielle and Shao answer their own.
special("j_celesta_arielle", "j_celesta_shaoanvt", {
    key = "arielle_shao",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state) end,
})

-- Fufu + ObKatieKat: ObKatieKat's ^Chips, raised by how many suits the deck
-- holds.
--
-- Counted off the full deck whenever it is asked rather than stored: the
-- number of suits in the deck is something the deck has now, and it goes down
-- as well as up. ^Chips needs Talisman, checked at score time for the reason
-- Arielle + Ironmouse gives.
special("j_celesta_fufu", "j_celesta_obkatiekat", {
    key = "fufu_katie",
    config = { e_chips_gain = 0.05 },

    loc_vars = function(def, card, state)
        local suits = CelestasMod.unique_suits_in_deck()
        return { vars = { state.e_chips_gain, 1 + state.e_chips_gain * suits } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local suits = CelestasMod.unique_suits_in_deck()
        local e_chips = 1 + state.e_chips_gain * suits
        if e_chips <= 1 then return end
        if Card.get_chip_e_mult == nil then
            CelestasMod.warn_once("fufu_katie_no_talisman",
                "Fufu + ObKatieKat scores ^Chips, which needs Talisman; "
                .. "without it the pair does nothing")
            return
        end
        return { e_chips = e_chips }
    end,
})

-- Ironmouse + Michi: Ironmouse's ^Mult, grown one Purple Seal at a time.
--
-- context.discard is raised once per discarded card, so each Purple Seal card
-- in a discard counts. The gain is kept on the pair's state, which is saved
-- with the card.
special("j_celesta_ironmouse", "j_celesta_michi", {
    key = "ironmouse_michi",
    config = { e_mult = 1, e_mult_gain = 0.05 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_mult_gain, state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.discard and not context.blueprint then
            local other = context.other_card
            if other and other.seal == "Purple" then
                state.e_mult = state.e_mult + state.e_mult_gain
                return {
                    message = localize { type = "variable", key = "celesta_powmult",
                                         vars = { state.e_mult } },
                    colour = G.C.MULT, card = card,
                }
            end
        end

        if context.joker_main and state.e_mult > 1 then
            if Card.get_chip_e_mult == nil then
                CelestasMod.warn_once("ironmouse_michi_no_talisman",
                    "Ironmouse + Michi scores ^Mult, which needs Talisman; "
                    .. "without it the pair does nothing")
                return
            end
            return { e_mult = state.e_mult }
        end
    end,
})

-- Bao + ShyLily: the last card played is retriggered, more often during a
-- Downpour.
--
-- "Last played" is the last card of full_hand, whether or not it scores. The
-- repetition pass is only raised for scoring cards, so a last card that does
-- not score is never asked about and gets nothing.
special("j_celesta_bao", "j_celesta_shylily", {
    key = "bao_shylily",
    config = { repetitions = 2, rain_repetitions = 5 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions, state.rain_repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        local played = context.full_hand or (G.play and G.play.cards) or {}
        if context.other_card ~= played[#played] then return end
        return {
            message = localize("k_again_ex"),
            repetitions = raining() and state.rain_repetitions or state.repetitions,
            card = card,
        }
    end,
})

-- Bao + Nihmune: during a Downpour, the first Club played is retriggered.
--
-- First in the order played, out of full_hand - so a Spade ahead of it does
-- not move which Club is first, and a first Club that does not score is not
-- replaced by the second one.
special("j_celesta_bao", "j_celesta_nihmune", {
    key = "bao_nihmune",
    config = { repetitions = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        -- Only during a Downpour.
        if not raining() then return end
        for _, played in ipairs(context.full_hand or (G.play and G.play.cards) or {}) do
            if played.is_suit and played:is_suit("Clubs") then
                if played ~= context.other_card then return end
                return {
                    message = localize("k_again_ex"),
                    repetitions = state.repetitions,
                    card = card,
                }
            end
        end
    end,
})

-- ShyLily + Nihmune: every Club played is retriggered.
special("j_celesta_shylily", "j_celesta_nihmune", {
    key = "shylily_nihmune",
    config = { repetitions = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play and context.other_card
            and context.other_card:is_suit("Clubs")) then return end
        return {
            message = localize("k_again_ex"),
            repetitions = state.repetitions,
            card = card,
        }
    end,
})

-- Fream + Nostro: every played Gash card is retriggered.
special("j_celesta_fream", "j_celesta_nostro", {
    key = "fream_nostro",
    config = { repetitions = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if not SMODS.has_enhancement(context.other_card, "m_celesta_gash") then return end
        return {
            message = localize("k_again_ex"),
            repetitions = state.repetitions,
            card = card,
        }
    end,
})

-- Kairyu + BeriBug: every played 8 is retriggered once for each discard used
-- this round.
--
-- discards_used is the round's own count, reset with the round, so the number
-- is read when the 8 is scored rather than kept anywhere.
special("j_celesta_kairyucrocodile", "j_celesta_beribug", {
    key = "kairyu_beribug",
    config = { repetitions = 1 },

    loc_vars = function(def, card, state)
        local round = G.GAME and G.GAME.current_round
        return { vars = { state.repetitions, (round and round.discards_used or 0) * state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if context.other_card:get_id() ~= 8 then return end
        local used = G.GAME.current_round.discards_used or 0
        if used <= 0 then return end
        return {
            message = localize("k_again_ex"),
            repetitions = used * state.repetitions,
            card = card,
        }
    end,
})

-- Suto + FeFe: every played card, and every Heart held in hand, becomes Wild.
--
-- context.before, FeFe's moment: after the poker hand is named and before
-- anything scores, so the Wild cards count during scoring without changing
-- which hand was played. Played cards are converted under unjudged, FeFe's
-- guard against a Pillar debuffing a card in the hand it was converted in.
special("j_celesta_suto", "j_celesta_fefe", {
    key = "suto_fefe",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint) then return end
        local wild = G.P_CENTERS.m_wild
        if not wild then return end

        local converted = 0
        local function make_wild(target, played)
            if SMODS.has_enhancement(target, "m_wild") then return end
            if played then
                CelestasMod.unjudged(target, function() target:set_ability(wild, nil, true) end)
            else
                target:set_ability(wild, nil, true)
            end
            converted = converted + 1
            G.E_MANAGER:add_event(Event {
                func = function() target:juice_up() return true end
            })
        end

        for _, played in ipairs(context.full_hand or {}) do
            make_wild(played, true)
        end
        for _, held in ipairs((G.hand and G.hand.cards) or {}) do
            if held:is_suit("Hearts") and not SMODS.has_enhancement(held, "m_wild") then
                make_wild(held, false)
            end
        end

        if converted > 0 then
            return {
                message = localize("k_upgrade_ex"),
                colour = G.C.SECONDARY_SET.Enhanced,
                card = card,
            }
        end
    end,
})

-- Squchan + Laimu: a Holographic Limestone card added to the deck as the round
-- starts.
--
-- Vanilla Marble Joker's shape, which is the same thing with a Stone card:
-- chosen at setting_blind, made in G.play so it is seen arriving, then drawn
-- into the deck, and announced to the Jokers that care about new cards.
special("j_celesta_squchan", "j_celesta_limealicious", {
    key = "squchan_laimu",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.setting_blind and not card.getting_sliced) then return end
        local limestone = G.P_CENTERS.m_celesta_limestone
        if not limestone then return end

        G.E_MANAGER:add_event(Event {
            func = function()
                local stone = create_playing_card({
                    front = pseudorandom_element(G.P_CARDS, pseudoseed("celesta_bind_squchan_laimu")),
                    center = limestone }, G.play, nil, nil, { G.C.SECONDARY_SET.Enhanced })
                stone:set_edition({ holo = true }, true)
                SMODS.calculate_effect({ message = localize("celesta_plus_limestone"),
                                         colour = G.C.SECONDARY_SET.Enhanced }, card)
                G.E_MANAGER:add_event(Event {
                    func = function()
                        draw_card(G.play, G.deck, 90, "up", nil)
                        return true
                    end,
                })
                playing_card_joker_effects({ stone })
                return true
            end,
        })
    end,
})

-- Suko + KokoNuts: KokoNuts's seven, arriving Foil, as the round starts.
special("j_celesta_suko", "j_celesta_kokonuts", {
    key = "suko_koko",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if context.setting_blind and not context.blueprint
            and not (context.blueprint_card or card).getting_sliced then
            koko_sevens(card, 1, "celesta_bind_suko_koko", { foil = true })
        end
    end,
})

-- KokoNuts + Cerber: KokoNuts makes the sevens; every one played goes round
-- twice more.
special("j_celesta_kokonuts", "j_celesta_cerbervt", {
    key = "koko_cerber",
    config = { repetitions = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if context.other_card:get_id() ~= 7 then return end
        return {
            message = localize("k_again_ex"),
            repetitions = state.repetitions,
            card = card,
        }
    end,
})

-- HeavenlyFather + Aethal: the whole shop wider - Jokers, packs and vouchers.
--
-- HeavenlyFather + Nostro's shape, with Aethal's slots added. Those go through
-- change_shop_size, which RETURNS EARLY when there is no shop, so what landed
-- is written down and only that is given back - never a slot that was not
-- granted.
special("j_celesta_heavenlyfather", "j_celesta_lordaethelstan", {
    key = "heavenly_aethal",
    config = { shop = 3, boosters = 3, vouchers = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.shop, state.boosters, state.vouchers } }
    end,

    add_to_deck = function(def, card, state, from_debuff)
        SMODS.change_booster_limit(state.boosters)
        SMODS.change_voucher_limit(state.vouchers)
        if G.GAME and G.GAME.shop and change_shop_size then
            change_shop_size(state.shop)
            state.shop_held = state.shop
        end
    end,

    remove_from_deck = function(def, card, state, from_debuff)
        SMODS.change_booster_limit(-state.boosters)
        SMODS.change_voucher_limit(-state.vouchers)
        local held = state.shop_held
        state.shop_held = nil
        if held and G.GAME and G.GAME.shop and change_shop_size then
            change_shop_size(-held)
        end
    end,

    on_merge = function(def, card, state)
        def.add_to_deck(def, card, state, false)
    end,

    on_unmerge = function(def, card, state)
        def.remove_from_deck(def, card, state, false)
    end,
})

-- BerryCrepe + CweamCat: CweamCat's moving target, paid in Mult.
--
-- CweamCat's shape exactly - checked before scoring, rerolled after, so the
-- hand shown when you play is the one that counts - through CweamCat's own
-- reroll, pointed at the pair's state. The first target is rolled as the pair
-- forms, the way CweamCat rolls one arriving.
special("j_celesta_berrycrepe", "j_celesta_cweamcat", {
    key = "berry_cweam",
    config = { mult = 0, mult_gain = 6, hand = "Pair" },

    loc_vars = function(def, card, state)
        return { vars = { state.mult_gain,
                          localize(state.hand or "Pair", "poker_hands"),
                          state.mult } }
    end,

    on_merge = function(def, card, state)
        CelestasMod.cweamcat_repick(state)
    end,

    calculate = function(def, card, context, state)
        if context.before and not context.blueprint then
            if context.scoring_name == state.hand then
                state.mult = state.mult + state.mult_gain
                return {
                    message = localize { type = "variable", key = "a_mult",
                                         vars = { state.mult } },
                    colour = G.C.MULT, card = card,
                }
            end
        end

        if context.after and not context.blueprint then
            CelestasMod.cweamcat_repick(state)
            return
        end

        if context.joker_main and state.mult > 0 then
            return { mult = state.mult }
        end
    end,
})

-- Arar + FroggyLoch: Arar's start-of-round enhancement, rolled for every
-- unenhanced card in hand instead of given to one.
--
-- Each card is its own 1 in 2. What it becomes is Arar's own choice -
-- CelestasMod.arar_forced, the enhancement of a Tarot in the first consumable
-- slot while the run still offers it - and otherwise a roll. The claimed flag
-- is Arar's too, so a card this pass has taken is not taken again before its
-- event lands.
special("j_celesta_arar", "j_celesta_froggyloch", {
    key = "arar_froggy",
    config = { odds = 2 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_arar_froggy")
        return { vars = { numerator, denominator } }
    end,

    calculate = function(def, card, context, state)
        if not (context.first_hand_drawn and not context.blueprint) then return end
        if not (G.hand and G.hand.cards) then return end

        local touched = 0
        for _, held in ipairs(G.hand.cards) do
            if held.config.center == G.P_CENTERS.c_base
                and not held.celesta_arar_claimed
                and SMODS.pseudorandom_probability(card, "celesta_bind_arar_froggy",
                    1, state.odds, "celesta_bind_arar_froggy") then
                local enhancement = (CelestasMod.arar_forced and CelestasMod.arar_forced())
                    or SMODS.poll_enhancement {
                        key = "celesta_bind_arar_froggy_enh",
                        guaranteed = true,
                    }
                if enhancement and G.P_CENTERS[enhancement] then
                    local target = held
                    target.celesta_arar_claimed = true
                    G.E_MANAGER:add_event(Event {
                        func = function()
                            target:set_ability(G.P_CENTERS[enhancement], nil, true)
                            target:juice_up(0.3, 0.5)
                            target.celesta_arar_claimed = nil
                            return true
                        end
                    })
                    touched = touched + 1
                end
            end
        end

        if touched > 0 then
            return {
                message = localize("k_upgrade_ex"),
                colour = G.C.SECONDARY_SET.Enhanced,
                card = card,
            }
        end
    end,
})

-- Arar + Maya: Arar's start-of-round card, made into the one Maya plays with -
-- a Steel Card, sealed so it goes round again.
--
-- Arar + HeavenlyFather's shape: one unenhanced card held in hand, claimed so
-- nothing else this pass takes it, and changed in an event. A Red Seal, or 1
-- in 3 the Foppy Seal - a Red Seal's retrigger twice over - rolled once for
-- the card made.
special("j_celesta_arar", "j_celesta_maya", {
    key = "arar_maya",
    config = { odds = 3 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_arar_maya_foppy")
        return { vars = { numerator, denominator } }
    end,

    calculate = function(def, card, context, state)
        if not (context.first_hand_drawn and not context.blueprint) then return end
        if not (G.hand and G.hand.cards) then return end
        local steel = G.P_CENTERS.m_steel
        if not steel then return end

        local candidates = {}
        for _, held in ipairs(G.hand.cards) do
            if held.config.center == G.P_CENTERS.c_base
                and not held.celesta_arar_claimed then
                candidates[#candidates + 1] = held
            end
        end
        if #candidates == 0 then return end

        local target = pseudorandom_element(candidates,
            pseudoseed("celesta_bind_arar_maya"))
        local seal = "Red"
        if SMODS.pseudorandom_probability(card, "celesta_bind_arar_maya_foppy",
                1, state.odds, "celesta_bind_arar_maya_foppy") then
            seal = (CelestasMod.SEAL_KEYS or {}).Foppy or seal
        end

        target.celesta_arar_claimed = true
        G.E_MANAGER:add_event(Event {
            func = function()
                target:set_ability(steel, nil, true)
                target:set_seal(seal, nil, true)
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
    end,
})

--------------------------------------------------------------------------------
-- Money, Stars, Clubs and Driftwood
--------------------------------------------------------------------------------

local function is_star_card(card)
    return card ~= nil and card.is_suit ~= nil and card:is_suit(CelestasMod.STARS_SUIT)
end

local function star_vars()
    return CelestasMod.suit_name_and_colour(CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR, true)
end

--- A card's rank as money: its nominal, which is 2 to 10, 10 for a face card
--- and 11 for an Ace. A card with no rank is worth nothing.
local function rank_value(card)
    if not (card and card.base) or SMODS.has_no_rank(card) then return 0 end
    return card.base.nominal or 0
end

--- What the destroyed cards of `suit` are worth, or nil for nothing.
---
--- remove_playing_cards is raised for every way a playing card is destroyed -
--- SMODS.destroy_cards, a discard, a Tarot - with the cards in context.removed.
local function paid_for_destroyed(context, suit)
    if not (context.remove_playing_cards and not context.blueprint) then return nil end
    local total = 0
    for _, gone in ipairs(context.removed or {}) do
        if gone.is_suit and gone:is_suit(suit) then total = total + rank_value(gone) end
    end
    if total > 0 then return total end
end

--- Yuzu's payout, for the held cards `wanted` accepts.
---
--- The held-in-hand pass while a hand is played, and not the end-of-round one,
--- which would pay a second time on the cash-out - Yuzu's own reason.
local function yuzu_held(card, context, state, key, wanted)
    if not (context.individual and context.cardarea == G.hand
            and not context.end_of_round) then return end
    local other = context.other_card
    if not (other and wanted(other)) then return end
    if not SMODS.pseudorandom_probability(card, key, 1, state.odds, key) then return end
    return { dollars = state.dollars, card = card }
end

local function yuzu_vars(card, state, key)
    local n, d = SMODS.get_probability_vars(card, 1, state.odds, key)
    return n, d
end

--- ^Mult is Talisman's; asked at score time, for the reason Vienna gives.
local function power_supported(id, name)
    if Card.get_chip_e_mult ~= nil then return true end
    CelestasMod.warn_once(id, name .. " scores ^Mult, which needs Talisman; "
        .. "without it the pair does nothing")
    return false
end

-- Hannah Hyrule + KokoNuts: the last scoring card gives X Chips and X Mult.
special("j_celesta_hannahhyrule", "j_celesta_kokonuts", {
    key = "hannah_koko",
    config = { x_chips = 1.7, x_mult = 1.7 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_chips, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and context.other_card) then return end
        local scoring = context.scoring_hand or {}
        if context.other_card ~= scoring[#scoring] then return end
        return { x_chips = state.x_chips, x_mult = state.x_mult, card = context.other_card }
    end,
})

-- Yoclesh + Milky: a scored Heart may bring a Negative consumable with it.
--
-- Negative, so it needs no room in the tray; made from an event, so it arrives
-- after the card that earned it has scored.
special("j_celesta_yoclesh", "j_celesta_milky", {
    key = "yoclesh_milky",
    config = { odds = 4 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(card, 1, state.odds, "celesta_bind_yoclesh_milky")
        return { vars = { n, d } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and context.other_card) then return end
        if not context.other_card:is_suit("Hearts") then return end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_yoclesh_milky",
                1, state.odds, "celesta_bind_yoclesh_milky") then return end
        G.E_MANAGER:add_event(Event {
            func = function()
                SMODS.add_card { set = "Consumeables", edition = "e_negative",
                                 key_append = "celesta_bind_yoclesh_milky" }
                return true
            end,
        })
        return { message = localize("celesta_plus_consumable"), colour = G.C.PURPLE, card = card }
    end,
})

-- Vienna + Trickywi: a destroyed Star pays its rank.
special("j_celesta_vienna", "j_celesta_trickywi", {
    key = "vienna_tricky",

    loc_vars = function(def, card, state)
        local name, colour = star_vars()
        return { vars = { name, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        local total = paid_for_destroyed(context, CelestasMod.STARS_SUIT)
        if total then return { dollars = total, card = card } end
    end,
})

-- Trickywi + Nihmune: a destroyed Club pays its rank.
special("j_celesta_trickywi", "j_celesta_nihmune", {
    key = "tricky_nihmune",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        local total = paid_for_destroyed(context, "Clubs")
        if total then return { dollars = total, card = card } end
    end,
})

-- Rainhoe + Nihmune: Rainhoe's tripled interest, on a deck of Clubs instead of
-- a wet round.
--
-- Rainhoe's shape: interest is not a Joker effect, so G.GAME.interest_amount is
-- raised in the end_of_round pass, before the cash-out reads it, and lowered
-- again at ending_shop so it cannot compound. Recorded as a difference against
-- what the pair has added, so selling or debuffing it cannot leave it behind.
local function pair_interest_hold(state, on)
    if not G.GAME then return false end
    local applied = state.applied or 0
    if on then
        if applied > 0 then return false end
        local add = (G.GAME.interest_amount or 0) * (state.scale - 1)
        if add <= 0 then return false end
        G.GAME.interest_amount = G.GAME.interest_amount + add
        state.applied = add
        return true
    end
    if applied <= 0 then return false end
    G.GAME.interest_amount = (G.GAME.interest_amount or 0) - applied
    state.applied = 0
    return true
end

special("j_celesta_rainhoe", "j_celesta_nihmune", {
    key = "rainhoe_nihmune",
    config = { scale = 3, clubs = 30, applied = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.scale, state.clubs, CelestasMod.count_suit_in_deck("Clubs") } }
    end,

    calculate = function(def, card, context, state)
        if context.end_of_round and context.main_eval and not context.blueprint then
            local enough = CelestasMod.count_suit_in_deck("Clubs") >= state.clubs
            if pair_interest_hold(state, enough) and enough then
                return { message = localize("k_upgrade_ex"), colour = G.C.MONEY, card = card }
            end
        end
        if context.ending_shop and not context.blueprint then
            pair_interest_hold(state, false)
        end
    end,

    remove_from_deck = function(def, card, state, from_debuff)
        pair_interest_hold(state, false)
    end,
})

-- Yuzu + Bao: during a Downpour, any held card may pay.
special("j_celesta_yuzu", "j_celesta_bao", {
    key = "yuzu_bao",
    config = { odds = 2, dollars = 3 },

    loc_vars = function(def, card, state)
        local n, d = yuzu_vars(card, state, "celesta_bind_yuzu_bao")
        return { vars = { n, d, state.dollars } }
    end,

    calculate = function(def, card, context, state)
        return yuzu_held(card, context, state, "celesta_bind_yuzu_bao", raining)
    end,
})

-- Yuzu + Trickywi: held Scoria may pay, as much as the merged card sells for.
--
-- Yuzu's held-card payout with the amount read off the card when it pays:
-- sell_cost, which already carries any extra_value the card has picked up.
-- A card worth nothing pays nothing rather than announcing $0.
special("j_celesta_yuzu", "j_celesta_trickywi", {
    key = "yuzu_tricky",
    config = { odds = 2 },

    loc_vars = function(def, card, state)
        local n, d = yuzu_vars(card, state, "celesta_bind_yuzu_tricky")
        return { vars = { n, d, card.sell_cost or 0 } }
    end,

    calculate = function(def, card, context, state)
        local worth = card.sell_cost or 0
        if worth <= 0 then return end
        local scoria = CelestasMod.ENHANCEMENT_KEYS and CelestasMod.ENHANCEMENT_KEYS.Scoria
        return yuzu_held(card, context, { odds = state.odds, dollars = worth },
            "celesta_bind_yuzu_tricky", function(held)
                return scoria and SMODS.has_enhancement(held, scoria)
            end)
    end,
})

-- Yuzu + Nihmune: held Clubs may pay.
special("j_celesta_yuzu", "j_celesta_nihmune", {
    key = "yuzu_nihmune",
    config = { odds = 2, dollars = 3 },

    loc_vars = function(def, card, state)
        local n, d = yuzu_vars(card, state, "celesta_bind_yuzu_nihmune")
        return { vars = { n, d, state.dollars } }
    end,

    calculate = function(def, card, context, state)
        return yuzu_held(card, context, state, "celesta_bind_yuzu_nihmune", function(held)
            return held.is_suit and held:is_suit("Clubs")
        end)
    end,
})

-- Yuzu + Vienna: held Stars may pay.
special("j_celesta_yuzu", "j_celesta_vienna", {
    key = "yuzu_vienna",
    config = { odds = 2, dollars = 3 },

    loc_vars = function(def, card, state)
        local n, d = yuzu_vars(card, state, "celesta_bind_yuzu_vienna")
        local name, colour = star_vars()
        return { vars = { n, d, state.dollars, name, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        return yuzu_held(card, context, state, "celesta_bind_yuzu_vienna", is_star_card)
    end,
})

-- Bao + Vienna: played Stars give +Mult, or X Mult during a Downpour.
special("j_celesta_bao", "j_celesta_vienna", {
    key = "bao_vienna",
    config = { mult = 5, x_mult = 1.5 },

    loc_vars = function(def, card, state)
        local name, colour = star_vars()
        return { vars = { state.mult, state.x_mult, name, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and is_star_card(context.other_card)) then return end
        if raining() then return { x_mult = state.x_mult, card = context.other_card } end
        return { mult = state.mult, card = context.other_card }
    end,
})

-- Trickywi + Bao: money gained during a Downpour is doubled. See the
-- ease_dollars wrapper below: every payout - a Joker's `dollars`, interest,
-- a sale - ends there, and nothing else sees all of them.
special("j_celesta_trickywi", "j_celesta_bao", {
    key = "tricky_bao",
    config = { scale = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.scale } }
    end,

    calculate = function(def, card, context, state) end,
})

local function gained(mod)
    if type(mod) == "number" then return mod > 0 end
    if type(mod) == "table" and to_big then return to_big(mod) > to_big(0) end
    return false
end

local celesta_bind_ease_dollars_ref = ease_dollars
if celesta_bind_ease_dollars_ref then
    function ease_dollars(mod, ...)
        if raining() then
            local holder, def = Bind.find_special("tricky_bao")
            if holder and not holder.debuff and gained(mod) then
                mod = mod * (Bind.special_state(holder, def).scale or 2)
            end
        end
        return celesta_bind_ease_dollars_ref(mod, ...)
    end
end

-- Yuzu + Juniper Actias: X Chips for every Star added to the deck.
--
-- Juniper's count: playing_card_added, by base.suit, for the reason Juniper
-- gives - is_suit would let Arielle make every card a Star.
special("j_celesta_yuzu", "j_celesta_juniperactias", {
    key = "yuzu_juniper",
    config = { x_chips = 1, x_chip_gain = 0.1 },

    loc_vars = function(def, card, state)
        local name, colour = star_vars()
        return { vars = { state.x_chip_gain, state.x_chips, name, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if context.playing_card_added and not context.blueprint
            and not card.getting_sliced then
            local added = 0
            for _, new_card in ipairs(context.cards or {}) do
                local base = new_card.base
                if base and base.suit == CelestasMod.STARS_SUIT then added = added + 1 end
            end
            if added == 0 then return end
            state.x_chips = state.x_chips + state.x_chip_gain * added
            return {
                message = localize { type = "variable", key = "a_xchips", vars = { state.x_chips } },
                colour = G.C.CHIPS, card = card,
            }
        end

        if context.joker_main and state.x_chips > 1 then
            return { x_chips = state.x_chips }
        end
    end,
})

--- Limestone cards in the run's deck.
---
--- G.playing_cards is the deck as a whole, wherever each card happens to be
--- sitting - hand, draw pile, discard - which is what "in full deck" means,
--- and it is the registry count_suit_in_deck walks for the same reason.
local function limestone_in_deck()
    local key = CelestasMod.ENHANCEMENT_KEYS and CelestasMod.ENHANCEMENT_KEYS.Limestone
    if not key then return 0 end
    local count = 0
    for _, held in ipairs(G.playing_cards or {}) do
        if SMODS.has_enhancement(held, key) then count = count + 1 end
    end
    return count
end

-- Yuzu + Laimu: Laimu adds a Limestone card a round, and this is paid for
-- every one of them that is still in the deck.
special("j_celesta_yuzu", "j_celesta_limealicious", {
    key = "yuzu_laimu",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars, limestone_in_deck() } }
    end,

    calculate = function(def, card, context, state)
        -- main_eval is the once-per-round Joker pass, so this pays once at the
        -- cash-out rather than once per Joker asked.
        if not (context.end_of_round and context.main_eval
                and not context.blueprint) then return end
        local owed = limestone_in_deck() * state.dollars
        if owed <= 0 then return end
        return { dollars = owed, card = card }
    end,
})

-- Yuzu + Camila: Camila's own trigger, paid for.
--
-- The whole body is Camila's, in jokers/implemented.lua: the first played hand
-- of a single card is taken on the destroy pass, and handed back when the next
-- Blind is picked. This pair only names a price, the way camila_any_count
-- names a count and camila_edition names an edition - so nothing here has to
-- know how the card is taken, and the two cannot drift apart.
special("j_celesta_yuzu", "j_celesta_camila", {
    key = "yuzu_camila",
    additive = true,
    camila_dollars = 9,

    loc_vars = function(def, card, state)
        return { vars = { def.camila_dollars } }
    end,
    calculate = function(def, card, context, state) end,
})

-- Yuzu + Shoto: Shoto's Gashed cards pay while they are held, the way Yuzu +
-- Trickywi's Scoria ones do.
special("j_celesta_yuzu", "j_celesta_shoto", {
    key = "yuzu_shoto",
    config = { odds = 2, dollars = 3 },

    loc_vars = function(def, card, state)
        local n, d = yuzu_vars(card, state, "celesta_bind_yuzu_shoto")
        return { vars = { n, d, state.dollars } }
    end,

    calculate = function(def, card, context, state)
        local gash = CelestasMod.ENHANCEMENT_KEYS and CelestasMod.ENHANCEMENT_KEYS.Gash
        return yuzu_held(card, context, state, "celesta_bind_yuzu_shoto",
            function(held)
                return gash and SMODS.has_enhancement(held, gash)
            end)
    end,
})

-- Yoka Siri + ItsDeadlyBoop: a Full House may scale the neighbour, the way
-- Yoka Siri does after a Boss.
--
-- The Joker to the right of the merged card, scaled by Yoka Siri's own
-- routine (CelestasMod.yoka_scale), so Cryptid is asked when it is installed
-- and a merge on the right has both halves scaled.
special("j_celesta_yokasiri", "j_celesta_itsdeadlyboop", {
    key = "yoka_boop",
    config = { odds = 4, scale = 1.5 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(card, 1, state.odds, "celesta_bind_yoka_boop")
        return { vars = { n, d, state.scale } }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint) then return end
        if not (context.scoring_name == "Full House" or context.scoring_name == "Flush House") then return end
        local row = G.jokers and G.jokers.cards
        if not row then return end
        local index
        for i, joker in ipairs(row) do
            if joker == card then index = i break end
        end
        local target = index and row[index + 1]
        if not target or not CelestasMod.yoka_scale then return end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_yoka_boop",
                1, state.odds, "celesta_bind_yoka_boop") then return end
        if CelestasMod.yoka_scale(target, state.scale) then
            return { message = localize("k_upgrade_ex"), colour = G.C.GREEN, card = card }
        end
    end,
})

-- Shenpai + RTGame: a Four of a Kind grows X Mult by the ranks it scored.
--
-- Shenpai's test - four of one rank among the scoring cards, which a Five of a
-- Kind passes too - and the ranks summed as rank_value counts them.
special("j_celesta_shenpai", "j_celesta_rtgame", {
    key = "shenpai_rt",
    config = { x_mult = 1, x_mult_gain = 0.1 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.before and not context.blueprint then
            local by_rank, sum = {}, 0
            for _, scored in ipairs(context.scoring_hand or {}) do
                if not SMODS.has_no_rank(scored) then
                    local id = scored:get_id()
                    by_rank[id] = (by_rank[id] or 0) + 1
                    sum = sum + rank_value(scored)
                end
            end
            local four = false
            for _, count in pairs(by_rank) do
                if count >= 4 then four = true break end
            end
            if four and sum > 0 then
                state.x_mult = state.x_mult + state.x_mult_gain * sum
                return {
                    message = localize { type = "variable", key = "a_xmult", vars = { state.x_mult } },
                    colour = G.C.MULT, card = card,
                }
            end
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- Rin Penrose + RTGame: Rin's banked Chips, paid in X Mult.
--
-- Rin's shape: the hand's total read in the `after` pass, banked, and paid a
-- step per 32 with the remainder kept. Divided rather than looped, and a total
-- past what a number holds stops banking rather than writing inf into a save.
local function scored_chips()
    local n = hand_chips
    if type(n) ~= "number" and type(to_number) == "function" then
        local ok, converted = pcall(to_number, n)
        n = ok and converted or nil
    end
    if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then return 0 end
    return n
end

special("j_celesta_rinpenrose", "j_celesta_rtgame", {
    key = "rin_rt",
    config = { x_mult = 1, x_mult_gain = 0.01, chips_per_step = 32, bank = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.chips_per_step,
                          state.chips_per_step - (state.bank or 0), state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.after and not context.blueprint then
            local scored = scored_chips()
            if scored <= 0 then return end
            state.bank = (state.bank or 0) + scored
            local steps = math.floor(state.bank / state.chips_per_step)
            if steps > 0 then
                state.bank = state.bank - steps * state.chips_per_step
                state.x_mult = state.x_mult + steps * state.x_mult_gain
                return {
                    message = localize { type = "variable", key = "a_xmult", vars = { state.x_mult } },
                    colour = G.C.MULT, card = card,
                }
            end
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- CottontailVA + FeFe: scoring Hearts may take a Star Seal, and once the hand
-- has scored, every scoring card becomes a Heart.
--
-- The seal is rolled as each card scores, so it is the Hearts at that moment
-- that are asked. The conversion waits for `after`, when scoring is finished -
-- which is what keeps it from changing this hand's suits - and goes through
-- unjudged for FeFe's reason.
special("j_celesta_cottontail", "j_celesta_fefe", {
    key = "cottontail_fefe",
    config = { odds = 4 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(card, 1, state.odds, "celesta_bind_cottontail_fefe")
        return { vars = { n, d } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.cardarea == G.play and context.other_card then
            local other = context.other_card
            if not other:is_suit("Hearts") then return end
            local seal = CelestasMod.SEAL_KEYS and CelestasMod.SEAL_KEYS.Star
            if not seal or other.seal == seal then return end
            if not SMODS.pseudorandom_probability(card, "celesta_bind_cottontail_fefe",
                    1, state.odds, "celesta_bind_cottontail_fefe") then return end
            other:set_seal(seal, nil, true)
            return { message = localize("celesta_sealed"), colour = G.C.PURPLE, card = card }
        end

        if context.after and not context.blueprint then
            local converted = 0
            for _, scored in ipairs(context.scoring_hand or {}) do
                if not SMODS.has_no_suit(scored) and not scored:is_suit("Hearts") then
                    CelestasMod.unjudged(scored, function() SMODS.change_base(scored, "Hearts") end)
                    converted = converted + 1
                    local target = scored
                    G.E_MANAGER:add_event(Event {
                        func = function() target:juice_up() return true end
                    })
                end
            end
            if converted > 0 then
                return { message = localize("celesta_hearts"), colour = G.C.HEARTS, card = card }
            end
        end
    end,
})

-- Ray + AxialMatt: AxialMatt's Raised Fist, pointed both ways - the highest
-- card held in hand and the lowest each add double their rank to Mult.
--
-- The highest is AxialMatt's own pick. The lowest is vanilla Raised Fist's
-- (card.lua:3647), the same rule with the comparison turned round: chosen by
-- rank (base.id), paid by chip value (base.nominal), rankless cards skipped,
-- ties to the last in hand order. A card that is both - a hand of one, or all
-- one rank - is both, and pays twice, as owning the two Jokers would. Paid as
-- h_mult on the held-in-hand pass, where both live, and never at the cash-out,
-- which raises that pass again for Gold cards.

--- Raised Fist's card, and what it is worth.
local function raised_fist_card()
    local low_id, low_nominal, low_card = 15, 0, nil
    for _, held in ipairs(G.hand and G.hand.cards or {}) do
        local base = held.base
        if base and low_id >= (base.id or 0) and not SMODS.has_no_rank(held) then
            low_id, low_nominal, low_card = base.id, base.nominal or 0, held
        end
    end
    return low_card, low_nominal
end

special("j_celesta_ray", "j_celesta_axialmatt", {
    key = "ray_axial",
    config = { rank_mult = 2 },

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.hand
                and not context.end_of_round) then return end
        local other = context.other_card
        if not other then return end

        local high, high_value = nil, 0
        if CelestasMod.axialmatt_raised then
            high, high_value = CelestasMod.axialmatt_raised()
        end
        local low, low_value = raised_fist_card()
        if other ~= high and other ~= low then return end

        -- Raised Fist's own answer for a debuffed pick: it is still the one
        -- raised, and says so, rather than handing the bonus down the hand.
        if other.debuff then
            return { message = localize("k_debuffed"), colour = G.C.RED, card = card }
        end

        local total = 0
        if other == high then total = total + high_value end
        if other == low then total = total + low_value end
        return { h_mult = state.rank_mult * total, card = card }
    end,
})

--------------------------------------------------------------------------------
-- Ellie Minibot and MinikoMew
--------------------------------------------------------------------------------

-- Ellie Minibot + MinikoMew: MinikoMew's debt, at ten times the rate. The
-- debt is MinikoMew's own reading of it, Talisman's big numbers included.
special("j_celesta_ellie_minibot", "j_celesta_minikomew", {
    key = "ellie_miniko",
    config = { mult = 20 },

    loc_vars = function(def, card, state)
        local debt = CelestasMod.minikomew_debt and CelestasMod.minikomew_debt() or 0
        local shown = state.mult * debt
        if type(shown) == "table" then shown = number_format(shown) end
        return { vars = { state.mult, shown } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local debt = CelestasMod.minikomew_debt()
        if CelestasMod.minikomew_in_debt(debt) then
            return { mult = state.mult * debt }
        end
    end,
})

-- Ellie Minibot + Shoomimi: the first reroll in each shop is worth a Joker
-- slot. Kept for the run the way Shoomimi's own consumable slots are, and
-- granted through the slot Jokers' bump_limit, which writes where Steamodded
-- actually stores the number. One shop is one round, so the round it last
-- paid in is what stops a second reroll paying again.
special("j_celesta_ellie_minibot", "j_celesta_shoomimi", {
    key = "ellie_shoomimi",
    config = { slots = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.slots } }
    end,

    calculate = function(def, card, context, state)
        if not (context.reroll_shop and not context.blueprint) then return end
        local round = G.GAME and G.GAME.round
        if state.last_round == round then return end
        state.last_round = round
        CelestasMod.bump_limit(G.jokers, state.slots)
        return { message = localize("celesta_plus_slot"), colour = G.C.FILTER, card = card }
    end,
})

-- Ellie Minibot + Chrchie: Chrchie's count, at $10 a card.
special("j_celesta_ellie_minibot", "j_celesta_chrchie", {
    key = "ellie_chrchie",
    config = { dollars = 10, cards = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars, state.cards } }
    end,

    calculate = function(def, card, context, state)
        if context.before and not context.blueprint and context.full_hand then
            state.cards = state.cards + #context.full_hand
        end

        if context.end_of_round and context.main_eval and not context.blueprint then
            local owed = state.cards * state.dollars
            state.cards = 0
            if owed > 0 then
                return { dollars = owed, card = card }
            end
        end
    end,
})

-- Shoomimi + MinikoMew: a 1 in 4 chance that a shop reroll costs nothing.
--
-- Rolled as the reroll button is pressed, before G.FUNCS.reroll_shop charges
-- anything (button_callbacks.lua:2920), and paid for with one of vanilla's own
-- free rerolls - Chaos the Clown's. calculate_reroll_cost then prices the
-- reroll at $0, and a free reroll does not raise the price of the next one.
-- A reroll that was already free is not rolled for.
special("j_celesta_shoomimi", "j_celesta_minikomew", {
    key = "shoomimi_miniko",
    config = { odds = 4 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_shoomimi_miniko")
        return { vars = { numerator, denominator } }
    end,

    calculate = function(def, card, context, state) end,
})

local celesta_bind_reroll_shop_ref = G.FUNCS and G.FUNCS.reroll_shop
if celesta_bind_reroll_shop_ref then
    G.FUNCS.reroll_shop = function(e)
        local round = G.GAME and G.GAME.current_round
        if round and (round.reroll_cost or 0) > 0 and (round.free_rerolls or 0) <= 0 then
            for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
                local def = Bind.special_of(held)
                if def and def.key == "shoomimi_miniko" and not held.debuff then
                    local state = Bind.special_state(held, def)
                    if SMODS.pseudorandom_probability(held, "celesta_bind_shoomimi_miniko",
                            1, state.odds, "celesta_bind_shoomimi_miniko") then
                        round.free_rerolls = (round.free_rerolls or 0) + 1
                        calculate_reroll_cost(true)
                        held:juice_up(0.3, 0.4)
                        break
                    end
                end
            end
        end
        return celesta_bind_reroll_shop_ref(e)
    end
end

-- Chrchie + MinikoMew: a debt left at the end of the round is written off.
--
-- Paid through ease_dollars rather than returned as `dollars`: a returned
-- amount is one Vedal scales, and this has to land on exactly $0. Counted
-- against dollar_buffer the way vanilla's own payouts are (To Do List), so two
-- of these in one round write the debt off once between them.
special("j_celesta_chrchie", "j_celesta_minikomew", {
    key = "chrchie_miniko",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.end_of_round and context.main_eval and not context.blueprint) then
            return
        end
        local debt = CelestasMod.minikomew_debt()
        local pending = G.GAME.dollar_buffer or 0
        if type(debt) == "number" and type(pending) == "number" then
            debt = math.max(0, debt - pending)
        end
        if not CelestasMod.minikomew_in_debt(debt) then return end

        if type(debt) == "number" and type(pending) == "number" then
            G.GAME.dollar_buffer = pending + debt
            G.E_MANAGER:add_event(Event {
                func = function() G.GAME.dollar_buffer = 0 return true end
            })
        end
        ease_dollars(debt)
        return {
            message = localize("$") .. tostring(number_format(debt)),
            colour = G.C.MONEY,
            card = card,
        }
    end,
})

--------------------------------------------------------------------------------
-- Silvervale, Ironmouse, Projekt Melody, Moo Merrily
--------------------------------------------------------------------------------

--- An exponent after a gain, kept to three places: the gains are tenths, and
--- tenths added in floating point print as 1.2000000000000002.
local function pow_after(value, gain)
    return math.floor((value + gain) * 1000 + 0.5) / 1000
end

--- Ironmouse's ^Mult, the way every pair of hers pays it.
local function ironmouse_pays(key, label, e_mult)
    if e_mult <= 1 then return nil end
    if Card.get_chip_e_mult == nil then
        CelestasMod.warn_once(key .. "_no_talisman",
            label .. " scores ^Mult, which needs Talisman; without it the pair does nothing")
        return nil
    end
    return { e_mult = e_mult }
end

-- Ironmouse + Projekt Melody: Projekt Melody's raise, paid in ^Mult. Up after
-- every round, and further after a skipped Blind - Projekt Melody's own two
-- moments (end_of_round with main_eval, and skip_blind).
special("j_celesta_ironmouse", "j_celesta_projektmelody", {
    key = "ironmouse_melody",
    config = { e_mult = 1, round_gain = 0.1, skip_gain = 0.3 },

    loc_vars = function(def, card, state)
        return { vars = { state.round_gain, state.skip_gain, state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        local gain = nil
        if context.end_of_round and context.main_eval and not context.blueprint then
            gain = state.round_gain
        elseif context.skip_blind and not context.blueprint then
            gain = state.skip_gain
        end
        if gain then
            state.e_mult = pow_after(state.e_mult, gain)
            return {
                message = localize { type = "variable", key = "celesta_powmult",
                                     vars = { state.e_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main then
            return ironmouse_pays("ironmouse_melody", "Ironmouse + Projekt Melody", state.e_mult)
        end
    end,
})

-- Ironmouse + Silvervale: Silvervale's count, in ^Mult. Read off the run's
-- tally (CelestasMod.rares_sold) every time, so nothing is kept on the card.
special("j_celesta_ironmouse", "j_celesta_silvervale", {
    key = "ironmouse_silver",
    config = { e_mult_gain = 0.3 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_mult_gain,
                          pow_after(1, state.e_mult_gain * CelestasMod.rares_sold()) } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local e_mult = pow_after(1, state.e_mult_gain * CelestasMod.rares_sold())
        return ironmouse_pays("ironmouse_silver", "Ironmouse + Silvervale", e_mult)
    end,
})

-- Projekt Melody + Silvervale: Projekt Melody's cash-out, raised by the Rares
-- sold instead of by the rounds. Through calc_dollar_bonus, so it has its own
-- line on the cash-out screen, and read from the run's tally when it pays.
special("j_celesta_projektmelody", "j_celesta_silvervale", {
    key = "melody_silver",
    config = { dollars = 1, per_rare = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars, state.per_rare } }
    end,

    calc_dollar_bonus = function(def, card, state)
        local total = state.dollars + state.per_rare * CelestasMod.rares_sold()
        if total <= 0 then return end
        return total
    end,

    calculate = function(def, card, context, state) end,
})

-- Moo Merrily + Yomi Quinnely: Moo Merrily's bottle, but the Burgundy Brew.
-- Moo Merrily's own room check, buffer included.
special("j_celesta_moomerrily", "j_celesta_yomiquinnely", {
    key = "moo_yomi",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.setting_blind
                and not (context.blueprint_card or card).getting_sliced) then return end
        local brew = CelestasMod.BURGUNDY_BREW_KEY
        if not (brew and G.P_CENTERS[brew] and G.consumeables) then return end

        local buffer = G.GAME.consumeable_buffer or 0
        if #G.consumeables.cards + buffer >= G.consumeables.config.card_limit then return end
        G.GAME.consumeable_buffer = buffer + 1

        G.E_MANAGER:add_event(Event {
            trigger = "before",
            delay = 0.0,
            func = function()
                local made = SMODS.create_card { set = "Spectral", key = brew,
                                                 area = G.consumeables }
                made:add_to_deck()
                G.consumeables:emplace(made)
                G.GAME.consumeable_buffer = math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
                return true
            end
        })

        return {
            message = localize("k_plus_spectral"),
            colour = G.C.SECONDARY_SET.Spectral,
            card = context.blueprint_card or card,
        }
    end,
})

--------------------------------------------------------------------------------
-- Glassesjournal, and what each partner wants dealt first
--------------------------------------------------------------------------------
--
-- Glassesjournal's deal order (deal_rank in jokers/implemented.lua) with the
-- partner naming the cards instead of Steel and Aces. Every pair is the same
-- shape, so they are declared from one table: `deal_first` is asked of each
-- card in the deck at every deal, and the ones it says yes to go to the front
-- in the order the shuffle left them.
--
-- Replacing pairs, like the rest: the merged card is no longer a
-- Glassesjournal, so its Steel-and-Aces rule gives way to the partner's.
-- Keys, suits and enhancements are all looked up when a card is asked about,
-- so this mod's Leaf, Stars, Gash and Limestone need nothing loaded first.

--- A card of rank `id`, asked the way every rank question here is.
local function deal_rank_is(id)
    return function(card) return card.get_id ~= nil and card:get_id() == id end
end

--- A card of suit `suit` - a name, or a function returning one. A debuffed
--- card still belongs to its suit, so the debuff is looked past.
local function deal_suit_is(suit)
    return function(card)
        local name = type(suit) == "function" and suit() or suit
        return name ~= nil and card.is_suit ~= nil and card:is_suit(name, true) and true or false
    end
end

--- A card carrying enhancement `key` - a key, or a function returning one.
local function deal_enh_is(key)
    return function(card)
        local name = type(key) == "function" and key() or key
        return name ~= nil and SMODS.has_enhancement(card, name) and true or false
    end
end

--- One of this mod's enhancement keys, by its short name.
local function mod_enhancement(name)
    return function() return (CelestasMod.ENHANCEMENT_KEYS or {})[name] end
end

--- A face card, asked through is_face so Pareidolia counts.
local function deal_face(card)
    return card.is_face ~= nil and card:is_face() and true or false
end

--- The name and colour of one of this mod's suits, for the text.
local function suit_vars(which)
    return function(def, card, state)
        local suit, colour = which()
        -- Plural: "Leaves are dealt". The third argument asks for singular.
        local name, shown = CelestasMod.suit_name_and_colour(suit, colour, false)
        return { vars = { name, colours = { shown } } }
    end
end

local GLASSES_DEALS = {
    { key = "koko", partner = "j_celesta_kokonuts", rule = deal_rank_is(7) },
    { key = "gluttonous", partner = "j_gluttenous_joker", rule = deal_suit_is("Clubs") },
    { key = "wrathful", partner = "j_wrathful_joker", rule = deal_suit_is("Spades") },
    { key = "lusty", partner = "j_lusty_joker", rule = deal_suit_is("Hearts") },
    { key = "greedy", partner = "j_greedy_joker", rule = deal_suit_is("Diamonds") },
    { key = "auteru", partner = "j_celesta_auteru", rule = deal_suit_is(function() return CelestasMod.LEAF_SUIT end), loc_vars = suit_vars(function() return CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR end) },
    { key = "cosmic", partner = "j_celesta_cosmic", rule = deal_suit_is(function() return CelestasMod.STARS_SUIT end), loc_vars = suit_vars(function() return CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR end) },
    { key = "fream", partner = "j_celesta_fream", rule = deal_enh_is("m_wild") },
    { key = "eros", partner = "j_celesta_eros", rule = deal_enh_is("m_bonus") },
    { key = "layna", partner = "j_celesta_laynalazar", rule = deal_enh_is("m_mult") },
    { key = "kael", partner = "j_celesta_kael", rule = deal_rank_is(10) },
    { key = "stone", partner = "j_stone", rule = deal_enh_is("m_stone") },
    { key = "glass", partner = "j_glass", rule = deal_enh_is("m_glass") },
    { key = "shoto", partner = "j_celesta_shoto", rule = deal_enh_is(mod_enhancement("Gash")) },
    { key = "midas", partner = "j_midas_mask", rule = deal_enh_is("m_gold") },
    { key = "laimu", partner = "j_celesta_limealicious", rule = deal_enh_is(mod_enhancement("Limestone")) },
    { key = "baron", partner = "j_baron", rule = deal_rank_is(13) },
    { key = "giwi", partner = "j_celesta_giwi", rule = deal_rank_is(12) },
    { key = "moon", partner = "j_shoot_the_moon", rule = deal_rank_is(12) },
    { key = "wee", partner = "j_wee", rule = deal_rank_is(2) },
    { key = "road", partner = "j_hit_the_road", rule = deal_rank_is(11) },
    { key = "lucky", partner = "j_lucky_cat", rule = deal_enh_is("m_lucky") },
    { key = "sock", partner = "j_sock_and_buskin", rule = deal_face },
    { key = "sixth", partner = "j_sixth_sense", rule = deal_rank_is(6) },
    { key = "eight", partner = "j_8_ball", rule = deal_rank_is(8) },
    { key = "cloud", partner = "j_cloud_9", rule = deal_rank_is(9) },
    { key = "kirana", partner = "j_celesta_kirana", rule = deal_rank_is(3) },
}

for _, entry in ipairs(GLASSES_DEALS) do
    special("j_celesta_glassesjournal", entry.partner, {
        key = "glasses_" .. entry.key,
        deal_first = entry.rule,
        loc_vars = entry.loc_vars or function(def, card, state) return { vars = {} } end,
        calculate = function(def, card, context, state) end,
    })
end

--------------------------------------------------------------------------------
-- LaynaLazar strips, and KokoNuts seals
--------------------------------------------------------------------------------

--- LaynaLazar's strip, for a merge: every scoring card wearing `enhancement`
--- goes back to a plain card, and the number taken is returned.
---
--- LaynaLazar's own shape (jokers/implemented.lua): context.before, so the
--- cards do not pay their enhancement out this hand; the claim flag stops a
--- copier stripping the same card twice, since set_ability is deferred; a
--- debuffed card is left alone; and the swap runs under unjudged, because
--- set_ability re-judges the card and The Pillar debuffs anything played this
--- Ante.
local function layna_strips(card, context, enhancement)
    if not (context.before and not context.blueprint) then return 0 end
    local removed = 0
    for _, played in ipairs(context.scoring_hand or {}) do
        if SMODS.has_enhancement(played, enhancement) and not played.debuff
            and not played.celesta_stripped then
            played.celesta_stripped = true
            CelestasMod.unjudged(played, function()
                played:set_ability(G.P_CENTERS.c_base, nil, true)
            end)
            local target = played
            G.E_MANAGER:add_event(Event {
                func = function()
                    target:juice_up()
                    target.celesta_stripped = nil
                    return true
                end
            })
            removed = removed + 1
        end
    end
    return removed
end

--- Kept to three places: tenths added in floating point print as 1.2000000000000002.
local function tidy(value)
    return math.floor(value * 1000 + 0.5) / 1000
end

-- KokoNuts + LaynaLazar: LaynaLazar's strip, pointed at the Lucky cards
-- KokoNuts keeps making, and paid in flat Mult.
special("j_celesta_kokonuts", "j_celesta_laynalazar", {
    key = "koko_layna",
    config = { mult = 0, mult_gain = 17 },

    loc_vars = function(def, card, state)
        return { vars = { state.mult_gain, state.mult } }
    end,

    calculate = function(def, card, context, state)
        local removed = layna_strips(card, context, "m_lucky")
        if removed > 0 then
            state.mult = state.mult + state.mult_gain * removed
            return {
                message = localize { type = "variable", key = "a_mult",
                                     vars = { state.mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main and state.mult > 0 then
            return { mult = state.mult }
        end
    end,
})

-- KokoNuts + CottontailVA: KokoNuts's seven, sealed the way Cottontail seals
-- things. The Star Seal is this mod's own, so it is read when the card is made.
special("j_celesta_kokonuts", "j_celesta_cottontail", {
    key = "koko_cottontail",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if context.setting_blind and not context.blueprint
            and not (context.blueprint_card or card).getting_sliced then
            koko_sevens(card, 1, "celesta_bind_koko_cottontail", false,
                (CelestasMod.SEAL_KEYS or {}).Star)
        end
    end,
})

-- Crelly + LaynaLazar: LaynaLazar's own Mult cards, paid in X Mult instead.
special("j_celesta_crelly", "j_celesta_laynalazar", {
    key = "crelly_layna",
    config = { x_mult = 1, x_mult_gain = 0.2 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        local removed = layna_strips(card, context, "m_mult")
        if removed > 0 then
            state.x_mult = tidy(state.x_mult + state.x_mult_gain * removed)
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { state.x_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- KokoNuts + Trickywi: Trickywi eats the neighbour, and KokoNuts is paid
-- properly for it - rarely, and seven times over.
--
-- Trickywi's own shape: an eternal Joker is refused by SMODS.destroy_cards, so
-- it is asked about first and nothing is paid for one, and the payout is read
-- BEFORE the meal because a removed card has no sell value left to read.
special("j_celesta_kokonuts", "j_celesta_trickywi", {
    key = "koko_tricky",
    config = { odds = 6, scale = 7 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_koko_tricky")
        return { vars = { numerator, denominator, state.scale } }
    end,

    calculate = function(def, card, context, state)
        if not (context.ending_shop and not context.blueprint) then return end
        local row = G.jokers and G.jokers.cards
        if not row then return end
        local index
        for i, joker in ipairs(row) do
            if joker == card then index = i break end
        end
        local target = index and row[index - 1]
        if not target or target == card then return end

        if not SMODS.pseudorandom_probability(card, "celesta_bind_koko_tricky",
                1, state.odds, "celesta_bind_koko_tricky") then return end
        if SMODS.is_eternal(target) then return end

        local payout = (target.sell_cost or 0) * state.scale
        SMODS.destroy_cards(target)
        if payout <= 0 then return end
        return { dollars = payout, card = card }
    end,
})

--------------------------------------------------------------------------------
-- Arielle
--------------------------------------------------------------------------------

--- The Jokers that pay Mult for one suit. Arielle already makes every card
--- count as the same suit; Arielle + Ray takes the suit out of the question
--- altogether and raises what they pay.
local SUIT_MULT_JOKERS = {
    j_greedy_joker = true,
    j_lusty_joker = true,
    j_wrathful_joker = true,
    j_gluttenous_joker = true,
    j_celesta_cosmic = true,
    j_celesta_auteru = true,
}

-- Arielle + Ray: Ray retriggers those four; merged with Arielle it rewrites
-- what all six of them pay instead.
--
-- Answered in a wrapper rather than by the pair's own calculate, for the
-- reason Trickywi + Bao's ease_dollars wrapper gives: what this changes is
-- what ANOTHER card returns, and the only place that can be reached is the
-- call that returns it.
special("j_celesta_arielle", "j_celesta_ray", {
    key = "arielle_ray",
    config = { mult = 12 },

    loc_vars = function(def, card, state)
        return { vars = { state.mult } }
    end,

    calculate = function(def, card, context, state) end,
})

local celesta_arielle_ray_ref = Card.calculate_joker
function Card:calculate_joker(context, ...)
    if context and context.individual and context.cardarea == G.play
        and context.other_card and not self.debuff then
        local center = self.config and self.config.center
        if center and SUIT_MULT_JOKERS[center.key] then
            local holder, def = Bind.find_special("arielle_ray")
            if holder and not holder.debuff then
                -- Instead of, not as well as: the Joker's own answer is the
                -- suit-gated one this replaces.
                return { mult = Bind.special_state(holder, def).mult,
                         card = context.other_card }
            end
        end
    end
    -- Two returns, because calculate_joker answers with (effect, post).
    return celesta_arielle_ray_ref(self, context, ...)
end

-- Arielle + Henya: Henya pays for retriggers; merged with Arielle every
-- scoring card pays, retriggered or not.
special("j_celesta_arielle", "j_celesta_henya", {
    key = "arielle_henya",
    config = { dollars = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.cardarea == G.play
            and context.other_card and not context.blueprint then
            return { dollars = state.dollars, card = context.other_card }
        end
    end,
})

--- The run's deck as a whole. Not count_suit_in_deck: once Arielle has made
--- every card the same suit there is no suit left to narrow by, and this is
--- the same live count vanilla's Erosion reads.
local function deck_size()
    return #(G.playing_cards or {})
end

-- Arielle + Buffpup: Buffpup is paid by the Leaves in the deck, and Arielle
-- makes every card count as one suit - so the merge is paid by all of it, at
-- Buffpup's own rate.
special("j_celesta_arielle", "j_celesta_buffpup", {
    key = "arielle_buffpup",
    config = { chips = 16 },

    loc_vars = function(def, card, state)
        return { vars = { state.chips, state.chips * deck_size() } }
    end,

    calculate = function(def, card, context, state)
        if context.joker_main then
            local total = state.chips * deck_size()
            if total > 0 then return { chips = total } end
        end
    end,
})

-- Ray + CottontailVA: CottontailVA is the Joker that hands out Star Seals,
-- and Ray is the one that makes another Joker go again - so together a Star
-- Seal goes again too, and copies the card to its left twice.
special("j_celesta_ray", "j_celesta_cottontail", {
    key = "ray_cottontail",
    config = { copies = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.copies } }
    end,

    -- Nothing to answer: a seal is not a Joker and is never asked a Joker's
    -- contexts. The behaviour is the hook below, the same way Geega + Henya's
    -- is Card:set_cost.
    calculate = function(def, card, context, state) end,
})

--- How many copies a Star Seal makes when it triggers.
---
--- seals/seals.lua calls this and has no other opinion, so the whole of the
--- pair lives here. A debuffed holder answers nothing, which is the rule
--- every other special follows.
function CelestasMod.star_seal_copies()
    local holder, def = Bind.find_special("ray_cottontail")
    if not (holder and not holder.debuff) then return 1 end
    return Bind.special_state(holder, def).copies or 1
end

--------------------------------------------------------------------------------
-- Geega
--------------------------------------------------------------------------------

-- Geega + Henya: Geega turns a debuffed Joker Negative; Henya pays. Together
-- a debuffed Joker is worth twice as much on the way out.
special("j_celesta_geega", "j_celesta_henya", {
    key = "geega_henya",
    config = { scale = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.scale } }
    end,

    calculate = function(def, card, context, state) end,
})

--- The pair's multiplier, or nil when no such merge is able to act.
local function geega_henya_scale()
    local holder, def = Bind.find_special("geega_henya")
    if not (holder and not holder.debuff) then return nil end
    return Bind.special_state(holder, def).scale
end

-- sell_cost is worked out inside Card:set_cost, from the card's base cost
-- (card.lua:512). Doubling the ANSWER rather than the card means a second
-- call recomputes from base and cannot compound, and a Joker that stops being
-- debuffed goes back to its normal price without anything having to undo this.
local celesta_geega_henya_cost_ref = Card.set_cost
function Card:set_cost(...)
    local ret = celesta_geega_henya_cost_ref(self, ...)
    if self.debuff and self.ability and self.ability.set == "Joker" then
        local scale = geega_henya_scale()
        if scale and type(self.sell_cost) == "number" then
            self.sell_cost = math.floor(self.sell_cost * scale)
        end
    end
    return ret
end

-- Nothing re-prices a card when it is debuffed - set_debuff does not call
-- set_cost - so without this the new price would not show until something
-- else happened to the card.
local celesta_geega_henya_debuff_ref = Card.set_debuff
function Card:set_debuff(should_debuff)
    local was = self.debuff
    local ret = celesta_geega_henya_debuff_ref(self, should_debuff)
    if self.debuff ~= was and self.ability and self.ability.set == "Joker"
        and type(self.set_cost) == "function" then
        self:set_cost()
    end
    return ret
end

-- Mooni + MOTHERv3: MOTHERv3 puts Exo on the cards sitting in hand, and Mooni
-- is paid for throwing them away.
special("j_celesta_mooni", "j_celesta_motherv3", {
    key = "mooni_mother",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = function(def, card, context, state)
        -- context.discard arrives once per discarded card, which is exactly
        -- the per-card payout this wants - Mooni's own shape, asking about an
        -- enhancement where Mooni asks about a suit.
        if not (context.discard and not context.blueprint
                and context.other_card) then return end
        local exo = CelestasMod.ENHANCEMENT_KEYS and CelestasMod.ENHANCEMENT_KEYS.Exo
        if exo and SMODS.has_enhancement(context.other_card, exo) then
            return { dollars = state.dollars, card = card }
        end
    end,
})

--------------------------------------------------------------------------------
-- Spite
--------------------------------------------------------------------------------

--- Told by the Ectoplast Seal each time one upgrades a Joker
--- (seals/seals.lua). Every merge in play that asked to know is told, with the
--- card that was sealed and the Joker that gained the edition.
---
--- Guarded per pair: a merge that faults must not stop the seal finishing its
--- own work, or stop the next merge hearing about it.
function CelestasMod.ectoplast_triggered(sealed, upgraded)
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        if not held.debuff then
            local def = Bind.special_of(held)
            if def and type(def.on_ectoplast) == "function" then
                local ok, err = pcall(def.on_ectoplast, def, held,
                    Bind.special_state(held, def), sealed, upgraded)
                if not ok then
                    CelestasMod.warn_once("bind_ectoplast_" .. tostring(def.key),
                        ("Bind pair %s failed on an Ectoplast Seal: %s")
                            :format(tostring(def.key), tostring(err)))
                end
            end
        end
    end
end

-- Spite + Megalodon: Megalodon's growing Mult, fed by the seals Spite hands
-- out rather than by the cards played - and it keeps what it gains.
special("j_celesta_spite", "j_celesta_megalodon", {
    key = "spite_megalodon",
    config = { mult = 0, mult_gain = 15 },

    loc_vars = function(def, card, state)
        return { vars = { state.mult_gain, state.mult } }
    end,

    on_ectoplast = function(def, card, state)
        state.mult = state.mult + state.mult_gain
        SMODS.calculate_effect({
            message = localize { type = "variable", key = "a_mult",
                                 vars = { state.mult } },
            colour = G.C.MULT,
        }, card)
    end,

    calculate = function(def, card, context, state)
        if context.joker_main and state.mult > 0 then
            return { mult = state.mult }
        end
    end,
})

-- Spite + CottontailVA: both of them stamp seals, so the merge stamps either -
-- Cottontail's Star or Spite's Ectoplast, a coin flip each time - and on any
-- scoring card rather than only the enhanced or the face ones.
special("j_celesta_spite", "j_celesta_cottontail", {
    key = "spite_cottontail",
    config = { odds = 2 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_spite_cottontail")
        return { vars = { numerator, denominator } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        if not (other and not other.seal) then return end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_spite_cottontail",
                1, state.odds, "celesta_bind_spite_cottontail") then return end

        local seals = CelestasMod.SEAL_KEYS or {}
        local which = pseudorandom(pseudoseed("celesta_bind_spite_cottontail_seal")) < 0.5
            and seals.Star or seals.Ectoplast
        if not which then return end
        other:set_seal(which, nil, true)
        return { message = localize("celesta_sealed"), colour = G.C.PURPLE, card = card }
    end,
})

-- Spite + Vexoria: Vexoria turns the hand to Spades, and this seals them.
special("j_celesta_spite", "j_celesta_vexoria", {
    key = "spite_vexoria",
    config = { odds = 3 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_spite_vexoria")
        return { vars = { numerator, denominator } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        if not (other and not other.seal and other.is_suit and other:is_suit("Spades")) then
            return
        end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_spite_vexoria",
                1, state.odds, "celesta_bind_spite_vexoria") then return end

        local ecto = (CelestasMod.SEAL_KEYS or {}).Ectoplast
        if not ecto then return end
        other:set_seal(ecto, nil, true)
        return { message = localize("celesta_sealed"), colour = G.C.PURPLE, card = card }
    end,
})

-- Spite + Trickywi: Trickywi's meal, with a way out. 1 in 3 the neighbour is
-- turned Negative instead of eaten; otherwise it goes the way Trickywi eats
-- it, paid before the meal because a removed card has no sell value to read.
-- An eternal neighbour is refused by SMODS.destroy_cards, so it is asked about
-- first and nothing is paid for it - Trickywi's own rule. It can still be
-- turned Negative: that destroys nothing.
special("j_celesta_spite", "j_celesta_trickywi", {
    key = "spite_tricky",
    config = { odds = 3, scale = 2 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_spite_tricky")
        return { vars = { numerator, denominator, state.scale } }
    end,

    calculate = function(def, card, context, state)
        if not (context.ending_shop and not context.blueprint) then return end
        local row = G.jokers and G.jokers.cards
        if not row then return end
        local index
        for i, joker in ipairs(row) do
            if joker == card then index = i break end
        end
        local target = index and row[index - 1]
        if not target or target == card then return end

        if SMODS.pseudorandom_probability(card, "celesta_bind_spite_tricky",
                1, state.odds, "celesta_bind_spite_tricky") then
            if target.edition and target.edition.negative then return end
            target:set_edition({ negative = true }, true)
            return { message = localize("k_upgrade_ex"), colour = G.C.DARK_EDITION,
                     card = target }
        end

        if SMODS.is_eternal(target) then return end
        local payout = (target.sell_cost or 0) * state.scale
        SMODS.destroy_cards(target)
        if payout <= 0 then return end
        return { dollars = payout, card = card }
    end,
})

-- Spite + El XoX: El XoX pays for the hands of the round; this pays for the
-- seals that fired in it. Counted as they fire and spent at the cash-out.
special("j_celesta_spite", "j_celesta_el_xox", {
    key = "spite_elxox",
    config = { dollars = 1, triggers = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    on_ectoplast = function(def, card, state)
        state.triggers = (state.triggers or 0) + 1
    end,

    calculate = function(def, card, context, state)
        if context.end_of_round and context.main_eval and not context.blueprint then
            local owed = (state.triggers or 0) * state.dollars
            state.triggers = 0
            if owed > 0 then
                return { dollars = owed, card = card }
            end
        end
    end,
})

-- Ray + LaynaLazar: played Mult cards are retriggered.
special("j_celesta_ray", "j_celesta_laynalazar", {
    key = "ray_layna",
    config = { repetitions = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if not SMODS.has_enhancement(context.other_card, "m_mult") then return end
        return { message = localize("k_again_ex"), repetitions = state.repetitions, card = card }
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
        -- `losing` as well, because a pair that has to hand something back to
        -- the SURVIVOR needs to know which half that is - and it cannot be
        -- read off the card, since the centre swap has not happened yet.
        local ok, err = pcall(def.on_unmerge, def, card,
            Bind.special_state(card, def), losing)
        if not ok then
            CelestasMod.warn_once("bind_unmerge_" .. tostring(def.key),
                ("Bind pair %s failed to part: %s"):format(tostring(def.key), tostring(err)))
        end
    end

    -- Whichever half is leaving takes its passive with it. Neither vanilla
    -- hook runs on its own here: the card never leaves the Joker row, it just
    -- stops being two Jokers.
    if not Bind.replacing_special(card) then
        if losing == "host" then
            Bind.remove_own_passive(card)
        else
            Bind.remove_partner_passive(card)
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

-- The cards whose absorbed half (or pair) is being evaluated right now, so a
-- centre that starts a fresh evaluation pass cannot bring the SAME card
-- straight back in here.
--
-- Per card, not one flag for everything. A single flag meant that while any
-- merged card's absorbed half was running, every OTHER merged card was treated
-- as re-entering too: its host centre was not hidden and its pair never ran.
-- A copier is exactly that - Mari Yume absorbed into Megalodon copying the
-- rightmost Joker - and a copied Moo Merrily + Yomi Quinnely answered as a
-- plain Moo Merrily and made a Milk Bottle.
local running = setmetatable({}, { __mode = "k" })

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

--- Shared with CDawg, which retains several Jokers at once and has the same
--- question to answer about their effects. One copy, so the two cannot come to
--- disagree about what adding two Jokers together means.
Bind.combine = combine

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
    -- Two returns, because calculate_joker answers with (effect, post).
    local ok, a, b = pcall(fn)
    center[hook] = saved
    if not ok then error(a, 0) end
    return a, b
end

local celesta_bind_calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context, ...)
    -- The host's own centre runs inside a recorded window too: it is as
    -- likely to be the half that destroys itself as the absorbed one.
    --
    -- Under a REPLACING pair the host's centre must not run at all, rather
    -- than run and have its answer thrown away. A calculate is not only its
    -- return value: Arar's queues the event that enhances a card, so Arar +
    -- HeavenlyFather enhanced TWO - one for the host's own pass, one for the
    -- pair's, each skipping the other's because of the claim flag they share.
    --
    -- Only the centre's own calculate is hidden, not the ref, so frozen rolls,
    -- tattered counting and every other mod's wrapper still see the
    -- evaluation - which is the reason the ref is called first at all.
    -- TEMPORARY trace: why an absorbed Chrchie never counts. Remove once found.
    local bound_key = type(self.ability) == "table"
        and type(self.ability.celesta_bind) == "table" and self.ability.celesta_bind.key
    if (bound_key == "j_celesta_chrchie"
            or (self.config and self.config.center_key == "j_celesta_chrchie"))
        and (context.before or context.end_of_round) and sendInfoMessage then
        sendInfoMessage(("[chrchie] enter %s host=%s bound=%s merged=%s running=%s special=%s main_eval=%s blueprint=%s full_hand=%s"):format(
            context.before and "before" or "end_of_round",
            tostring(self.config and self.config.center_key), tostring(bound_key),
            tostring(Bind.is_merged(self)), tostring(running[self] or false),
            tostring((Bind.special_of(self) or {}).key), tostring(context.main_eval),
            tostring(context.blueprint), tostring(context.full_hand and #context.full_hand)),
            "CelestasMod")
    end

    local effect, post
    if Bind.is_merged(self) and not running[self] then
        effect, post = without_center_hook(self, "calculate", function()
            return with_acting_half(self, "host",
                celesta_bind_calculate_joker_ref, self, context)
        end)
    else
        effect, post = celesta_bind_calculate_joker_ref(self, context, ...)
    end

    if running[self] or not Bind.is_merged(self) then return effect, post end

    -- A special pair REPLACES both halves. The host's own calculate has
    -- already run by this point - the ref is called first so that frozen
    -- rolls, tattered counting and every other mod's hook still see the
    -- evaluation - but its result is dropped in favour of the pair's.
    local def = Bind.special_of(self)
    local special_effect = nil
    if def then
        -- A pair whose whole ability is a passive or a cash-out - HeavenlyFather
        -- + Nostro, HeavenlyFather + Aethal - has no calculate. Calling nil
        -- failed, and the failure was logged as the pair breaking.
        if type(def.calculate) ~= "function" then
            return (def.additive and effect or nil), post
        end
        running[self] = true
        local state = Bind.special_state(self, def)
        local ok, ret = pcall(def.calculate, def, self, context, state)
        running[self] = nil
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
    if not center then return effect, post end

    -- Run through the chain BELOW this wrapper rather than by calling
    -- center.calculate directly.
    --
    -- A vanilla Joker has no calculate at all. Greedy Joker is
    -- `{name = "Greedy Joker", effect = "Suit Mult", ...}` and nothing more -
    -- what it DOES lives in vanilla's own Card:calculate_joker, a chain of
    -- name and effect checks. Calling center.calculate meant every merge whose
    -- absorbed half was a vanilla Joker carried a passenger: no Mult, no
    -- popup, nothing.
    --
    -- The ref reaches both. Steamodded's dispatch sits at the top of that
    -- function and hands a modded centre to its own calculate; a vanilla one
    -- falls through to the chain that knows it. It also puts the absorbed half
    -- through this mod's other wrappers - the Frozen edition's roll, the
    -- Clover's suppression - which is what "as if it were on its own card"
    -- should have meant all along. Frozen caches its roll per card per play,
    -- so the two halves share one outcome rather than rolling twice.
    --
    -- The absorbed centre reads its own fields off card.ability, so it is lent
    -- the ability table that came with it - the same trick Eutrophic uses to
    -- run a foreign centre against a card that is not really it. Lent rather
    -- than copied: a Joker that scales itself must keep that growth.
    running[self] = true
    local saved_center, saved_ability = self.config.center, self.ability
    local saved_key = self.config.center_key
    -- TEMPORARY trace (see above).
    local chrchie_trace = center.key == "j_celesta_chrchie"
        and (context.before or context.end_of_round) and sendInfoMessage
    local lent = self.ability.celesta_bind.ability
    local chrchie_was = chrchie_trace and type(lent) == "table"
        and type(lent.extra) == "table" and lent.extra.cards
    -- Recorded before the swap, for the reason partner_special gives: the
    -- lent ability has no celesta_bind, so without this the absorbed half
    -- cannot see the pair it is running under.
    local saved_special = partner_special[self]
    partner_special[self] = Bind.special_of(self)
    self.config.center = center
    self.config.center_key = center.key or saved_key
    self.ability = self.ability.celesta_bind.ability
    local ok, partner = pcall(with_acting_half, self, "absorbed",
                              celesta_bind_calculate_joker_ref, self, context)
    self.config.center, self.ability = saved_center, saved_ability
    self.config.center_key = saved_key
    partner_special[self] = saved_special
    running[self] = nil
    if chrchie_trace then
        local now = self.ability.celesta_bind and self.ability.celesta_bind.ability
        sendInfoMessage(("[chrchie] absorbed %s ok=%s ret=%s cards %s -> %s same_table=%s"):format(
            context.before and "before" or "end_of_round", tostring(ok),
            type(partner) == "table" and tostring(partner.dollars) or tostring(partner),
            tostring(chrchie_was),
            tostring(type(now) == "table" and type(now.extra) == "table" and now.extra.cards),
            tostring(now == lent)), "CelestasMod")
    end

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

--- A merge's description as RAW rows - the shape generate_card_ui hands back
--- in aut.main, which is a list of rows of text parts rather than UI nodes.
---
--- Shared, because two places draw it and they need the same numbers: the
--- Special Merges tab turns these into its own rows, and the merge web hands
--- them to a card's hover popup, which converts them itself.
---
--- loc_vars wants a card and neither caller has one, so it is given a stand-in
--- and the whole thing is pcall'd: a pair whose description cannot be built is
--- a missing description, not a crash in the Collection.
---
--- no_name is not cosmetic. generate_card_ui builds the card's NAME as well
--- (common_events.lua:2436), a name is DynaText, and DynaText puts itself into
--- G.I.MOVEABLE on construction (text.lua:60) - so a name that is built and
--- then dropped is never parented and never removed, and Game:draw paints it
--- at the room origin forever after. Asking for no name never builds one.
function Bind.desc_rows(loc_key, def)
    local vars = {}
    if def and type(def.loc_vars) == "function" then
        local stub = { ability = { extra = {} }, config = { center = {} } }
        local ok, res = pcall(def.loc_vars, def, stub, def.config or {})
        if ok and type(res) == "table" and type(res.vars) == "table" then
            vars = res.vars
        end
    end
    vars.no_name = true

    local ok, aut = pcall(generate_card_ui,
        { set = "Other", key = loc_key }, nil, vars, "Other", nil, false)
    if not (ok and type(aut) == "table" and type(aut.main) == "table") then
        return nil
    end
    return aut.main
end

--- The first card in the Joker row governed by the special `key`, if any.
function Bind.find_special(key)
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        local def = Bind.special_of(held)
        if def and def.key == key then return held, def end
    end
    return nil
end

-- Arielle + Haruka Karibu: an edition on what a Tarot was used on.
--
-- Nothing raised in the calculate pass says what a Tarot was used ON -
-- using_consumeable carries the card and where it came from, not its targets -
-- so they are read here, before the Tarot runs, off the same selection it is
-- about to read them from.
--
-- A Tarot that takes a selection declares max_highlighted, and a hand Tarot
-- cannot be used with nothing picked in the hand. So a selecting Tarot used
-- with the hand empty is one that selects Jokers, and its targets are the
-- Jokers picked instead. A Tarot that selects nothing - The Fool, Judgement -
-- was not used on anything, and adds nothing.
--
-- Only a card with no edition gets one, and the roll is Aura's: Foil,
-- Holographic or Polychrome, never Negative. The edition is put on by an event
-- queued behind the Tarot's own, so its flips and swaps finish first.

local ARIELLE_HARUKA = "arielle_haruka"

--- Every held, working card governed by the special `key`.
local function specials_held(key)
    local out = {}
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        local def = Bind.special_of(held)
        if def and def.key == key and not held.debuff then
            out[#out + 1] = { card = held, def = def }
        end
    end
    return out
end

--- What `tarot` is about to be used on, in the order it was picked.
local function tarot_targets(tarot)
    local consumeable = tarot.ability and tarot.ability.consumeable
    if not (consumeable and consumeable.max_highlighted) then return {} end
    local picked = (G.hand and G.hand.highlighted) or {}
    if #picked == 0 then picked = (G.jokers and G.jokers.highlighted) or {} end
    local out = {}
    for i, target in ipairs(picked) do out[i] = target end
    return out
end

local celesta_bind_use_consumeable_ref = Card.use_consumeable
function Card:use_consumeable(area, copier, ...)
    local holders, targets = nil, nil
    if self.ability and self.ability.set == "Tarot" then
        holders = specials_held(ARIELLE_HARUKA)
        if #holders > 0 then targets = tarot_targets(self) end
    end

    local ret = celesta_bind_use_consumeable_ref(self, area, copier, ...)

    if targets and #targets > 0 then
        -- Rolled now, so the seed is spent in the order things happened; one
        -- card is only ever given one edition, whoever rolled for it first.
        local given = {}
        for _, h in ipairs(holders) do
            local state = Bind.special_state(h.card, h.def)
            for _, target in ipairs(targets) do
                if not target.edition and not given[target]
                    and SMODS.pseudorandom_probability(h.card, "celesta_bind_arielle_haruka",
                        1, state.odds, "celesta_bind_arielle_haruka") then
                    given[target] = h.card
                end
            end
        end

        for _, target in ipairs(targets) do
            local holder = given[target]
            if holder then
                G.E_MANAGER:add_event(Event {
                    func = function()
                        -- The Tarot may have destroyed it, or given it an
                        -- edition of its own, while this waited.
                        if target.REMOVED or target.edition then return true end
                        target:set_edition(
                            poll_edition("celesta_bind_arielle_haruka_ed", nil, true, true), true)
                        holder:juice_up(0.3, 0.5)
                        return true
                    end
                })
            end
        end
    end

    return ret
end

-- Aquwa + Nekrolina: paid for each Negative consumable that arrives.
--
-- Where a consumable lands in the tray is the one place every source of one
-- goes through - bought, made by a Joker, taken from a pack - and it is where
-- the Downpour turns one Negative (arena.lua). This file is loaded after that
-- one, so this wraps the Downpour's wrapper and sees the card after it has
-- turned, and a card that arrived Negative from anywhere else counts the same.
--
-- Marked on the card once paid, so one put back into the tray is not paid for
-- twice. The mark is saved with it.

local AQUWA_NEKROLINA = "aquwa_nekrolina"
local NEGATIVE_PAID = "celesta_bind_negative_paid"

local celesta_bind_nekro_emplace_ref = CardArea.emplace
function CardArea:emplace(card, ...)
    local ret = celesta_bind_nekro_emplace_ref(self, card, ...)

    if self == G.consumeables and card and card.ability
        and card.edition and card.edition.negative
        and not card.ability[NEGATIVE_PAID] then
        for _, h in ipairs(specials_held(AQUWA_NEKROLINA)) do
            card.ability[NEGATIVE_PAID] = true
            local state = Bind.special_state(h.card, h.def)
            SMODS.calculate_effect({ dollars = state.dollars }, h.card)
        end
    end

    return ret
end

-- Arielle + Grandpaw Shao: every card the same suit, and every card an Ace.
--
-- Both are questions the game asks of a card constantly - is this that suit,
-- what rank is this - and both have one gate. SMODS.smeared_check is where
-- Arielle widens the first (jokers/implemented.lua) and Card:get_id is where
-- Shao widens the second, so the pair answers in the same two places.
--
-- The row is walked by hand rather than through find_joker or special_of: a
-- replacing pair hides both halves from find_joker, and these two functions
-- are called for every card of every hand, several times over, where building
-- a table per call would be felt.

--- True while a merge of these two Jokers is in the row and able to act.
---
--- The two keys are compared rather than special_of being asked: that builds
--- the pair's joined key as a string every time, and these two functions are
--- called for every card of every hand several times over.
local function pair_in_row(a, b)
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        local bound = not held.debuff and held.ability and held.ability.celesta_bind
        if bound then
            local config = held.config or {}
            local host = config.center_key or (config.center and config.center.key)
            local other = bound.key
            if (host == a and other == b) or (host == b and other == a) then
                return true
            end
        end
    end
    return false
end

local ARIELLE, SHAO = "j_celesta_arielle", "j_celesta_shaoanvt"

local celesta_bind_smeared_ref = SMODS.smeared_check
function SMODS.smeared_check(card, suit, ...)
    if pair_in_row(ARIELLE, SHAO) then return true end
    return celesta_bind_smeared_ref(card, suit, ...)
end

local celesta_bind_get_id_ref = Card.get_id
function Card:get_id(...)
    local id = celesta_bind_get_id_ref(self, ...)
    -- A Stone Card answers with a large negative number rather than a rank,
    -- and is not a card with a rank to change; Shao's own check is the same.
    if type(id) == "number" and id >= 2 and id <= 13 and pair_in_row(ARIELLE, SHAO) then
        return 14
    end
    return id
end

-- Buffpup + Shiabun and Arielle + Shiabun: a card selection limit that is
-- COUNTED rather than fixed, off the deck - so it moves while the pair sits
-- there, as the deck does.
--
-- SMODS.change_play_limit and change_discard_limit ADD to a stored number and
-- nothing re-reads them, so what has been granted is remembered and only the
-- difference is applied - the same delta Shiabun's own limit is granted by.
--
-- Released by the same pass rather than by a hook: a pair that is sold,
-- debuffed, unmerged or destroyed simply stops being in the row, and one place
-- noticing that covers all four.

local SELECTION_PAIRS = {
    buffpup_shiabun = function(state)
        return math.floor(
            CelestasMod.count_suit_in_deck(CelestasMod.LEAF_SUIT) / state.per)
    end,
    arielle_shiabun = function(state)
        return math.floor(CelestasMod.unique_suits_in_deck() / state.per)
    end,
    -- VchiBan: as many extra picks as there are Discards left, which moves
    -- within a round rather than only between them - which is exactly what
    -- this pass is for.
    quad_vchiban = function(state)
        local round = G.GAME and G.GAME.current_round
        return (round and round.discards_left) or 0
    end,
}

--- What each card has been granted. Weak keys: a card that is gone should not
--- be kept alive by being remembered here.
local selection_granted = setmetatable({}, { __mode = "k" })

local function selection_limit_sync()
    if not (SMODS.change_play_limit and SMODS.change_discard_limit) then return end

    local live = nil
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        local def = (not held.debuff) and Bind.special_of(held)
        local wanted = def and SELECTION_PAIRS[def.key]
        if wanted then
            local ok, want = pcall(wanted, Bind.special_state(held, def))
            if ok and type(want) == "number" then
                live = live or {}
                live[held] = math.max(0, math.floor(want))
            end
        end
    end

    for card, granted in pairs(selection_granted) do
        if not (live and live[card]) and granted ~= 0 then
            SMODS.change_play_limit(-granted)
            SMODS.change_discard_limit(-granted)
            selection_granted[card] = nil
        end
    end

    for card, want in pairs(live or {}) do
        local granted = selection_granted[card] or 0
        if want ~= granted then
            SMODS.change_play_limit(want - granted)
            SMODS.change_discard_limit(want - granted)
            selection_granted[card] = want
        end
    end
end

CelestasMod.Bind.selection_limit_sync = selection_limit_sync

local celesta_bind_selection_update_ref = Game and Game.update
if celesta_bind_selection_update_ref then
    function Game:update(dt)
        celesta_bind_selection_update_ref(self, dt)
        selection_limit_sync()
    end
end

-- Stake badges for both halves of a merge.
--
-- A won run gives a stake badge to every Joker in the row: set_joker_win
-- (misc_functions.lua:1192) counts the win against each card's own centre -
-- which for a merged card is the host alone. The absorbed half was in the row
-- for the win just the same, so it is counted the same way, into both the
-- stake-index table vanilla keeps and the stake-key one Steamodded's
-- get_joker_win_sticker builds the badge from.

--- Counts this run's win against `key`, the way set_joker_win does.
local function record_joker_win(key, center)
    local profile = G.PROFILES and G.SETTINGS and G.PROFILES[G.SETTINGS.profile]
    local all_usage = profile and profile.joker_usage
    if not (all_usage and G.GAME and G.GAME.stake) then return false end

    local usage = all_usage[key] or { count = 1, order = center.order, wins = {},
                                      losses = {}, wins_by_key = {}, losses_by_key = {} }
    all_usage[key] = usage
    usage.wins = usage.wins or {}
    usage.wins[G.GAME.stake] = (usage.wins[G.GAME.stake] or 0) + 1
    if SMODS.stake_from_index then
        local stake_key = SMODS.stake_from_index(G.GAME.stake)
        usage.wins_by_key = usage.wins_by_key or {}
        usage.wins_by_key[stake_key] = (usage.wins_by_key[stake_key] or 0) + 1
    end
    return true
end

local celesta_bind_joker_win_ref = set_joker_win
if celesta_bind_joker_win_ref then
    function set_joker_win(...)
        local ret = celesta_bind_joker_win_ref(...)
        local recorded = false
        for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
            local bound = held.ability and held.ability.set == "Joker"
                and Bind.is_merged(held) and held.ability.celesta_bind
            -- A half whose mod has since been removed has no centre to badge.
            local center = bound and G.P_CENTERS[bound.key]
            if center and record_joker_win(bound.key, center) then recorded = true end
        end
        if recorded then G:save_settings() end
        return ret
    end
end

-- A copy starts owing nothing.
--
-- copy_card copies every field of a card's ability (common_events.lua:2504),
-- and that includes the receipts CelestasMod.GRANT_LEDGERS lists - what a
-- slot- or limit-granting Joker has already handed the run. A copy made by
-- Invisible Joker, Ankh, Grimmi or anything else therefore believed it had
-- already granted what its original holds, and granted nothing: two Aethals
-- stayed one Aethal wide, and selling the copy took the original's slots with
-- it. So the receipts are cleared on the copy, and on its absorbed half when
-- it is a merge - the same clearing Bind.merge does for a half it carries.
--
-- Only on a card that is not already in play. copy_table is deep, so the copy
-- holds tables of its own and the original's receipts are untouched.
local celesta_bind_copy_card_ref = copy_card
if celesta_bind_copy_card_ref then
    function copy_card(...)
        local new_card = celesta_bind_copy_card_ref(...)
        local ability = new_card and not new_card.added_to_deck and new_card.ability
        if type(ability) == "table" then
            local bound = type(ability.celesta_bind) == "table" and ability.celesta_bind.ability
            for _, ledger in ipairs(CelestasMod.GRANT_LEDGERS or {}) do
                ability[ledger] = nil
                if type(bound) == "table" then bound[ledger] = nil end
            end
        end
        return new_card
    end
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
    local saved_special = partner_special[card]
    partner_special[card] = Bind.special_of(card)
    card.config.center = center
    card.ability = card.ability.celesta_bind.ability
    local ok, ret = pcall(fn, center, card)
    card.config.center, card.ability = saved_center, saved_ability
    partner_special[card] = saved_special

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

-- Passives vanilla applies from a Joker's ABILITY rather than from its centre.
--
-- Card:add_to_deck calls the centre's own add_to_deck hook and then runs a
-- block of branches that read self.ability directly - +1 discard, +1 hand
-- size, Credit Card's overdraft, and the rest (card.lua:759-801), each undone
-- by the matching branch in remove_from_deck. with_partner swaps the centre
-- in, so the HOOK half of that has always worked for an absorbed Joker. The
-- ability half never did, because self.ability at that moment is the host's:
-- two Drunkards gave +1 discard rather than +2, and two Jugglers +1 hand size.
--
-- Reimplemented rather than re-entered. Calling vanilla's own function again
-- under the swap would also run its tail, which fires SMODS card_added and
-- resets the Blind - both about a card ARRIVING, and at a merge nothing
-- arrives, one card leaves. A Joker counting cards added would count the merge
-- as one more.
--
-- Only the branches vanilla itself UNDOES are here. Chicot's is add-only: it
-- disables the Blind then and there, which is an event rather than a passive,
-- and something that cannot be taken back must not be handed out twice.
-- Astronomer's only refreshes displayed prices.
--
-- test_bind_intrinsic.py reads the branch list back out of the game, so one
-- added there and not here fails rather than going quiet.

--- ability.name -> the effect, scaled by `sign`: 1 applying, -1 taking back.
local INTRINSIC = {
    ["Credit Card"] = function(ability, sign)
        G.GAME.bankrupt_at = G.GAME.bankrupt_at - sign * (ability.extra or 0)
    end,
    ["Chaos the Clown"] = function(_, sign)
        SMODS.change_free_rerolls(sign)
        calculate_reroll_cost(true)
    end,
    ["Turtle Bean"] = function(ability, sign)
        G.hand:change_size(sign * ((ability.extra or {}).h_size or 0))
    end,
    ["Oops! All 6s"] = function(_, sign)
        for k, v in pairs(G.GAME.probabilities) do
            G.GAME.probabilities[k] = sign > 0 and v * 2 or v / 2
        end
    end,
    ["To the Moon"] = function(ability, sign)
        G.GAME.interest_amount = G.GAME.interest_amount + sign * (ability.extra or 0)
    end,
    ["Troubadour"] = function(ability, sign)
        local extra = ability.extra or {}
        G.hand:change_size(sign * (extra.h_size or 0))
        G.GAME.round_resets.hands =
            G.GAME.round_resets.hands + sign * (extra.h_plays or 0)
    end,
    ["Stuntman"] = function(ability, sign)
        G.hand:change_size(-sign * ((ability.extra or {}).h_size or 0))
    end,
}

--- Applies (sign 1) or takes back (sign -1) one ability's own passives.
---
--- Guarded as a whole: a passive that faults halfway leaves the run with the
--- wrong number of discards, which is bad - a merge that throws is a crash.
local function intrinsic_passive(ability, sign)
    if type(ability) ~= "table" then return end

    local ok, err = pcall(function()
        if G.hand and (ability.h_size or 0) ~= 0 then
            G.hand:change_size(sign * ability.h_size)
        end
        -- `> 0` is vanilla's own test, on both sides. A negative d_size is
        -- never applied, so it must never be taken back either.
        if (ability.d_size or 0) > 0 then
            G.GAME.round_resets.discards =
                G.GAME.round_resets.discards + sign * ability.d_size
            ease_discard(sign * ability.d_size)
        end
        local named = INTRINSIC[ability.name]
        if named then named(ability, sign) end
    end)

    if not ok then
        CelestasMod.warn_once("bind_intrinsic_" .. tostring(ability.name),
            ("Bind could not %s the passive of %s: %s"):format(
                sign > 0 and "apply" or "take back",
                tostring(ability.name), tostring(err)))
    end
end

--- The absorbed half's, if this card has one and the pair has not replaced it.
local function partner_intrinsic(card, sign)
    if not Bind.is_merged(card) then return end
    if Bind.replacing_special(card) then return end
    intrinsic_passive(card.ability.celesta_bind.ability, sign)
end

Bind.intrinsic_passive = intrinsic_passive

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
    partner_intrinsic(self, 1)
end

-- "Is one of these in play?" for a VANILLA Joker.
--
-- find_joker matches card.ability.name (misc_functions.lua:1044), and a merged
-- card's is the host's - so an absorbed Splash, Shortcut, Pareidolia, Smeared
-- Joker or Astronomer was not in play as far as the game was concerned, and
-- those five ARE nothing but that question. Merging one in as the second half
-- switched it off.
--
-- A card is added at most once even when both halves answer to the same name.
-- Every caller of this in the game asks whether there is one at all - `next`,
-- or `# > 0` - so counting a merge of two Splashes as two would change nothing
-- it is asked, while handing the same card twice to a caller that acts on each
-- of them could double whatever it does.
--
-- This mod's own Jokers go through CelestasMod.find_joker instead, which
-- answers with the right ability table as well; a vanilla Joker has no state
-- to get wrong, so presence is the whole of the question here.
local celesta_bind_find_joker_ref = find_joker
function find_joker(name, non_debuff)
    local found = celesta_bind_find_joker_ref(name, non_debuff)
    if not (G.jokers and G.jokers.cards) then return found end

    local already = {}
    for _, card in ipairs(found) do already[card] = true end

    for _, card in ipairs(G.jokers.cards) do
        if not already[card] and Bind.is_merged(card)
            and not Bind.replacing_special(card)
            and (non_debuff or not card.debuff) then
            local ability = card.ability.celesta_bind.ability
            if type(ability) == "table" and ability.name == name then
                found[#found + 1] = card
            end
        end
    end

    return found
end

-- Per-frame upkeep. Vanilla dispatches this to self.config.center alone
-- (card.lua:4678), which is the host's, so an absorbed half's `update` never
-- ran at all.
--
-- It is the hook a passive uses to FOLLOW its own number: this mod's four
-- slot-granting Jokers apply by delta from here, so that anything raising the
-- number afterwards - Yoka Siri, a Cryptid misprint - moves the run and not
-- only the text. Without this an absorbed one was frozen at whatever it
-- granted the moment it was merged.
--
-- Runs on every card every frame, so the cheap test comes first: with_partner
-- returns immediately for a card that is not merged.
local celesta_bind_update_ref = Card.update
function Card:update(dt)
    celesta_bind_update_ref(self, dt)
    with_partner(self, "update", function(center, card)
        center:update(card, dt)
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
    partner_intrinsic(self, -1)
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
    partner_intrinsic(host, 1)
end

--- The mirror, for a merge coming apart while the card stays in the row.
--- Splitting is not leaving the deck - the survivor is still there and vanilla
--- runs neither hook - so without this the departing half's passive would stay
--- behind, and merging two Drunkards then destroying one would be a way to
--- keep the second discard for good.
function Bind.remove_partner_passive(card)
    with_partner(card, "remove_from_deck", function(center, held)
        center:remove_from_deck(held, false)
    end)
    partner_intrinsic(card, -1)
end

--- ...and the same for the HOST's own, for when the host is the half that
--- goes. Taken while card.config.center and card.ability are still the
--- host's, because a moment later they are the survivor's.
function Bind.remove_own_passive(card)
    local center = card.config.center
    if type(center) == "table" and type(center.remove_from_deck) == "function" then
        pcall(center.remove_from_deck, center, card, false)
    end
    intrinsic_passive(card.ability, -1)
end

--------------------------------------------------------------------------------
-- The True Stars pairs, and the two that grow a hand
--------------------------------------------------------------------------------

--- True when a card counts as a Star. Through is_suit, which is what every
--- suit question in this mod goes through, so a Wild card counts as one - the
--- same answer PiaPiUFO's own is_star gives.
local function bind_is_star(other)
    return other ~= nil and other.is_suit ~= nil
        and other:is_suit(CelestasMod.STARS_SUIT)
end

--- Whether the discard now in progress was forced by a Joker.
---
--- Remembered from pre_discard because context.discard does not carry `hook`
--- (state_events.lua:399 raises it without one; :390 is where the flag is).
--- Kairyu does not count a forced discard against the round - vanilla does not
--- either - so neither do the two pairs below.
local discard_is_hooked = false

--- Brings the hand size in line with what a pair has earned, written as a
--- difference against what it has already handed out.
---
--- Kairyu's own celesta_resize in the same shape and for the same reason: the
--- hand's size is saved with the run, so the amount handed out has to be saved
--- with it. A local would come back zero after a reload and the size would
--- never be given back.
local function bind_resize(state, wanted)
    local applied = state.applied or 0
    if wanted == applied then return 0 end
    if G.hand then G.hand:change_size(wanted - applied) end
    state.applied = wanted
    return wanted - applied
end

--- The calculate both Kairyu pairs share: count the discarded cards `counts`
--- answers yes to, and hand out one hand size for every `per` of them.
---
--- context.discard rather than pre_discard, because this counts CARDS and
--- pre_discard fires once per discard ACTION.
local function kairyu_discard_calculate(counts)
    return function(def, card, context, state)
        if context.pre_discard then
            discard_is_hooked = context.hook and true or false
        end

        if context.discard and not context.blueprint and not discard_is_hooked
            and counts(context.other_card) then
            state.discarded = (state.discarded or 0) + 1
            local earned = math.floor(state.discarded / state.per) * state.h_size
            if bind_resize(state, earned) > 0 then
                return {
                    message = localize("celesta_plus_hand_size"),
                    colour = G.C.FILTER, card = card,
                }
            end
        end

        -- main_eval is the once-per-round Joker pass.
        if context.end_of_round and context.main_eval and not context.blueprint then
            state.discarded = 0
            if (state.applied or 0) > 0 then
                bind_resize(state, 0)
                return { message = localize("k_reset"), colour = G.C.FILTER,
                         card = card }
            end
        end
    end
end

--- The passive hooks both Kairyu pairs share.
---
--- Mid-round only, for Kairyu's own reason: what a round counted is not
--- cleared until the next round starts, so it survives the cash-out and the
--- whole shop. A pair formed in the shop would otherwise open the next round
--- already holding hand size for cards it never saw.
local function kairyu_add_to_deck(def, card, state, from_debuff)
    state.applied = 0
    if not (G.GAME and G.GAME.facing_blind) then state.discarded = 0 end
    bind_resize(state,
        math.floor((state.discarded or 0) / state.per) * state.h_size)
end

local function kairyu_remove_from_deck(def, card, state, from_debuff)
    bind_resize(state, 0)
end

-- Kairyu + PiaPiUFO: Kairyu grows the hand as the round is spent, PiaPiUFO
-- cares about Stars. Together the hand grows on the Stars thrown away.
special("j_celesta_kairyucrocodile", "j_celesta_piapiufo", {
    key = "kairyu_piapiufo",
    config = { h_size = 1, per = 3, discarded = 0, applied = 0 },

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR)
        -- colours goes INSIDE vars, which is where every other suit-naming
        -- loc_vars in this mod puts it.
        return { vars = { state.h_size, state.per, name, state.applied,
                          colours = { colour } } }
    end,

    calculate = kairyu_discard_calculate(bind_is_star),
    add_to_deck = kairyu_add_to_deck,
    remove_from_deck = kairyu_remove_from_deck,
    on_merge = function(def, card, state)
        kairyu_add_to_deck(def, card, state, false)
    end,
    on_unmerge = function(def, card, state)
        kairyu_remove_from_deck(def, card, state, false)
    end,
})

-- Kairyu + ToriOriane: the same, for the suit that is hard to come by - so
-- every one of them counts rather than every third.
special("j_celesta_kairyucrocodile", "j_celesta_torioriane", {
    key = "kairyu_torioriane",
    config = { h_size = 1, per = 1, discarded = 0, applied = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.h_size, state.applied } }
    end,

    calculate = kairyu_discard_calculate(CelestasMod.is_true_star),
    add_to_deck = kairyu_add_to_deck,
    remove_from_deck = kairyu_remove_from_deck,
    on_merge = function(def, card, state)
        kairyu_add_to_deck(def, card, state, false)
    end,
    on_unmerge = function(def, card, state)
        kairyu_remove_from_deck(def, card, state, false)
    end,
})

-- PiaPiUFO + BeriBug: BeriBug's 8s, paid at PiaPiUFO's rate. The retrigger is
-- gone and the multiplier has moved onto the rank BeriBug was watching.
special("j_celesta_piapiufo", "j_celesta_beribug", {
    key = "piapiufo_beribug",
    config = { x_mult = 1.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.cardarea == G.play then
            local other = context.other_card
            -- get_id is the rank's numeric value; 8 is literally 8.
            if other and other.get_id and other:get_id() == 8 then
                return { x_mult = state.x_mult }
            end
        end
    end,
})

-- ToriOriane + BeriBug: BeriBug's retrigger, pointed at ToriOriane's suit.
special("j_celesta_torioriane", "j_celesta_beribug", {
    key = "torioriane_beribug",
    config = { repetitions = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if context.repetition and context.cardarea == G.play
            and CelestasMod.is_true_star(context.other_card) then
            return {
                message = localize("k_again_ex"),
                repetitions = state.repetitions,
                card = card,
            }
        end
    end,
})

-- PiaPiUFO + ToriOriane: PiaPiUFO's X Mult and ToriOriane's flat pair of
-- numbers both become multipliers, on the rarer suit.
special("j_celesta_piapiufo", "j_celesta_torioriane", {
    key = "piapiufo_torioriane",
    config = { x_mult = 1.5, x_chips = 1.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult, state.x_chips } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.cardarea == G.play
            and CelestasMod.is_true_star(context.other_card) then
            return { x_mult = state.x_mult, x_chips = state.x_chips }
        end
    end,
})

--------------------------------------------------------------------------------
-- The quad merges
--------------------------------------------------------------------------------
--
-- Six named groups of four. Every one is replacing - the group has a name and
-- an ability of its own, and none of the four speaks for itself any more - so
-- none of them needs to say so.

--- The hand size a quad is holding open for the round, resized as a difference
--- against what it has already handed out. Same rule as the Kairyu pairs
--- above, and for the same reason: the hand's size is saved with the run.
local function quad_resize(state, wanted)
    local applied = state.applied or 0
    if wanted == applied then return 0 end
    if G.hand then G.hand:change_size(wanted - applied) end
    state.applied = wanted
    return wanted - applied
end

-- The Beastiez: Kairyu's hand size, PiaPiUFO's Stars, BeriBug's 8s and
-- ToriOriane's True Stars, all four narrowed onto one card - an 8 of either
-- Star suit.
quad({
    key = "quad_beastiez",
    members = { "j_celesta_kairyucrocodile", "j_celesta_piapiufo",
                "j_celesta_beribug", "j_celesta_torioriane" },
    config = { x_mult = 4, h_size = 1, applied = 0 },

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR)
        return { vars = { state.x_mult, state.h_size, name,
                          colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.cardarea == G.play then
            local other = context.other_card
            local eight = other and other.get_id and other:get_id() == 8
            local starry = other and ((other.is_suit
                    and other:is_suit(CelestasMod.STARS_SUIT))
                or CelestasMod.is_true_star(other))
            if eight and starry then
                -- One more card in hand for the rest of the round, and only
                -- one however many 8s score: "for the round" is a state the
                -- card is in, not a thing it collects.
                quad_resize(state, state.h_size)
                return { x_mult = state.x_mult }
            end
        end

        if context.end_of_round and context.main_eval and not context.blueprint
            and (state.applied or 0) > 0 then
            quad_resize(state, 0)
            return { message = localize("k_reset"), colour = G.C.FILTER,
                     card = card }
        end
    end,

    add_to_deck = function(def, card, state, from_debuff)
        state.applied = 0
    end,
    remove_from_deck = function(def, card, state, from_debuff)
        quad_resize(state, 0)
    end,
    on_unmerge = function(def, card, state)
        quad_resize(state, 0)
    end,
})

--- Every card in the full deck this group is paid for: a Lucky 7 of Spades,
--- anything with a Star Seal, or anything Mult enhanced.
---
--- Counted once per CARD however many of the three it answers to - a card is
--- one card - and off the live deck rather than a running total, the way
--- every other "for each card in your full deck" in this mod is.
local function tootie_count()
    local seal = CelestasMod.SEAL_KEYS and CelestasMod.SEAL_KEYS.Star
    local n = 0
    for _, held in ipairs(G.playing_cards or {}) do
        local lucky_seven = SMODS.has_enhancement(held, "m_lucky")
            and held.get_id and held:get_id() == 7
            and held.is_suit and held:is_suit("Spades")
        if lucky_seven
            or (seal and held.seal == seal)
            or SMODS.has_enhancement(held, "m_mult") then
            n = n + 1
        end
    end
    return n
end

-- Tootie Pies: CottontailVA's Star Seals, KokoNuts's Lucky sevens, LaynaLazar
-- and Crelly - four Jokers about what a card has been made into, paid by how
-- much of that the deck holds.
quad({
    key = "quad_tootie_pies",
    members = { "j_celesta_cottontail", "j_celesta_kokonuts",
                "j_celesta_laynalazar", "j_celesta_crelly" },
    config = { x_mult_gain = 0.2 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain,
                          1 + state.x_mult_gain * tootie_count() } }
    end,

    calculate = function(def, card, context, state)
        if context.joker_main then
            local x_mult = 1 + state.x_mult_gain * tootie_count()
            if x_mult > 1 then return { x_mult = x_mult } end
        end
    end,
})

-- Piss Boys: Ray, Nagzz, Chibidoki and AxialMatt - the retrigger group. What
-- they end up doing instead is read off the two ends of the hand.
quad({
    key = "quad_piss_boys",
    members = { "j_celesta_ray", "j_celesta_nagzz",
                "j_celesta_chibidoki", "j_celesta_axialmatt" },
    config = { scale = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.scale } }
    end,

    calculate = function(def, card, context, state)
        if context.joker_main then
            -- Held in hand, not scored: the cards still sitting there when the
            -- hand is played. Rankless cards - Stone and anything else that
            -- declares no rank - have no rank to be the lowest or highest of.
            local low, high
            for _, held in ipairs((G.hand and G.hand.cards) or {}) do
                if held.base and not SMODS.has_no_rank(held) then
                    local id = held.base.id
                    if id then
                        if not low or id < low then low = id end
                        if not high or id > high then high = id end
                    end
                end
            end
            if not low then return end

            local total = (low + high) * state.scale
            return { chips = total, mult = total }
        end
    end,
})

-- Sinful Joker: all four suit Jokers at once, so suit stops mattering and
-- every scored card is paid instead.
quad({
    key = "quad_sinful",
    members = { "j_greedy_joker", "j_lusty_joker",
                "j_wrathful_joker", "j_gluttenous_joker" },
    config = { mult = 15, x_mult = 1.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.mult, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.cardarea == G.play
            and context.other_card then
            -- Both in one answer, which is also the order they are applied in:
            -- Steamodded walks its calculation keys with mult ahead of x_mult,
            -- so the flat number lands before the multiplier rather than after.
            return { mult = state.mult, x_mult = state.x_mult }
        end
    end,
})

-- Geode: all four of vanilla's suit stones. The same shape as Sinful above -
-- four suits is no suit - and everything the four of them do at once.
quad({
    key = "quad_geode",
    members = { "j_rough_gem", "j_arrowhead", "j_onyx_agate", "j_bloodstone" },
    config = { dollars = 1, chips = 50, mult = 7, x_mult = 1.5, odds = 2 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_quad_geode")
        return { vars = { state.dollars, state.chips, state.mult,
                          numerator, denominator, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.individual and context.cardarea == G.play
            and context.other_card then
            local out = { dollars = state.dollars, chips = state.chips,
                          mult = state.mult }
            if SMODS.pseudorandom_probability(card, "celesta_quad_geode", 1,
                                              state.odds) then
                out.x_mult = state.x_mult
            end
            return out
        end
    end,
})

--- The slots Lab Brats is holding open, as a difference against what it has
--- already handed out - the same ledger rule the hand size uses, and for the
--- same reason: both limits are saved with the run.
local function lab_sync(state)
    if not (G.GAME and G.jokers and G.jokers.config
        and G.consumeables and G.consumeables.config) then return end
    local dollars = G.GAME.dollars or 0
    local want_consumable = math.floor(dollars / (state.per_consumable or 5))
    local want_joker = math.floor(dollars / (state.per_joker or 10))
    if want_consumable < 0 then want_consumable = 0 end
    if want_joker < 0 then want_joker = 0 end

    local had_c, had_j = state.consumable_applied or 0, state.joker_applied or 0
    if want_consumable ~= had_c then
        G.consumeables.config.card_limit =
            G.consumeables.config.card_limit + (want_consumable - had_c)
        state.consumable_applied = want_consumable
    end
    if want_joker ~= had_j then
        G.jokers.config.card_limit =
            G.jokers.config.card_limit + (want_joker - had_j)
        state.joker_applied = want_joker
    end
end

CelestasMod.lab_brats_sync = function()
    local holder, def = Bind.find_special("quad_lab_brats")
    if not (holder and not holder.debuff) then return end
    lab_sync(Bind.special_state(holder, def))
end

-- Lab Brats: Shoomimi's consumable slots, Chrchie, Ellie Minibot and
-- Minikomew. The slots follow the wallet, and the wallet pays for them again
-- at the end of the round.
quad({
    key = "quad_lab_brats",
    members = { "j_celesta_shoomimi", "j_celesta_chrchie",
                "j_celesta_ellie_minibot", "j_celesta_minikomew" },
    config = { per_consumable = 5, per_joker = 10,
               consumable_applied = 0, joker_applied = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.per_consumable, state.per_joker } }
    end,

    calculate = function(def, card, context, state)
        -- Kept in step wherever money moved: the wallet changes in the shop,
        -- mid-hand and at the cash-out, and the slots have to follow it.
        lab_sync(state)

        if context.end_of_round and context.main_eval and not context.blueprint then
            local total = (G.jokers and G.jokers.config
                and G.jokers.config.card_limit or 0)
                + (G.consumeables and G.consumeables.config
                    and G.consumeables.config.card_limit or 0)
            if total > 0 then return { dollars = total, card = card } end
        end
    end,

    add_to_deck = function(def, card, state, from_debuff)
        state.consumable_applied, state.joker_applied = 0, 0
        lab_sync(state)
    end,

    remove_from_deck = function(def, card, state, from_debuff)
        if G.consumeables and G.consumeables.config then
            G.consumeables.config.card_limit =
                G.consumeables.config.card_limit - (state.consumable_applied or 0)
        end
        if G.jokers and G.jokers.config then
            G.jokers.config.card_limit =
                G.jokers.config.card_limit - (state.joker_applied or 0)
        end
        state.consumable_applied, state.joker_applied = 0, 0
    end,

    on_merge = function(def, card, state)
        def.add_to_deck(def, card, state, false)
    end,
    on_unmerge = function(def, card, state)
        def.remove_from_deck(def, card, state, false)
    end,
})

-- Sloppy Sisters: Dokibird, Snuffy, Laimu and Mint Fantome. Laimu is the one
-- that puts Limestone cards in the deck, and this is what they are worth once
-- they are in your hand rather than in the played hand.
quad({
    key = "quad_sloppy_sisters",
    members = { "j_celesta_dokibird", "j_celesta_snuffy",
                "j_celesta_limealicious", "j_celesta_mintfantome" },

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        -- The held-in-hand pass IS the moment the played hand has finished
        -- scoring: SMODS walks G.play and then G.hand through the same main
        -- scoring step (state_events.lua:652), so a Limestone card sitting in
        -- hand is reached here and nowhere else.
        --
        -- not end_of_round, because the same context is raised over the cards
        -- still in hand at the cash-out, where no hand was played and there is
        -- nothing to multiply by. Yuzu's Limestone payout is guarded the same
        -- way and for the same reason.
        if not (context.individual and context.cardarea == G.hand
            and not context.end_of_round and context.other_card) then
            return
        end

        local held = context.other_card
        if not SMODS.has_enhancement(held,
            CelestasMod.ENHANCEMENT_KEYS.Limestone) then
            return
        end

        -- Every card played, not only the ones that scored: "the number of
        -- cards played" is what was put on the table.
        local played = #((G.play and G.play.cards) or {})
        -- Limestone's Mult is applied by the game from ability.mult rather
        -- than returned from its calculate, so that is where the card's own
        -- number is - and reading it rather than the enhancement's config
        -- means a Limestone a Joker has grown is worth what it grew to.
        local mult = (held.ability and held.ability.mult) or 0
        if played <= 0 or mult <= 0 then return end

        return { mult = played * mult, card = held }
    end,
})

--------------------------------------------------------------------------------
-- The Leaf, the consumables and the sold
--------------------------------------------------------------------------------

-- Buffpup + Ironmouse: Buffpup is the Leaf Joker and Ironmouse is the
-- exponent, so a Leaf that scores is a chance at one.
--
-- ^Mult needs Talisman, and the check is made at score time rather than at
-- load for the reason Vienna gives: mods load in priority order, and Talisman
-- may not have run when this file did.
special("j_celesta_buffpup", "j_celesta_ironmouse", {
    key = "buffpup_ironmouse",
    config = { odds = 4, e_mult = 1.13 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_buffpup_ironmouse")
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR, true)
        return { vars = { n, d, state.e_mult, name, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
            and context.other_card and context.other_card.is_suit
            and context.other_card:is_suit(CelestasMod.LEAF_SUIT)) then
            return
        end
        if not SMODS.pseudorandom_probability(
            card, "celesta_bind_buffpup_ironmouse", 1, state.odds) then
            return
        end
        if Card.get_chip_e_mult == nil then
            CelestasMod.warn_once("buffpup_ironmouse_no_talisman",
                "Buffpup + Ironmouse scores ^Mult, which needs Talisman; "
                .. "without it the pair does nothing")
            return
        end
        return { e_mult = state.e_mult, card = card }
    end,
})

-- Buffpup + AiCandii: Buffpup counts Leaves and AiCandii is the one that
-- grows, so this grows on the Leaves that are still in hand when the round
-- ends rather than the ones that were played.
special("j_celesta_buffpup", "j_celesta_aicandii", {
    key = "buffpup_aicandii",
    config = { chips = 0, per = 16 },

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR, true)
        return { vars = { state.per, name, state.chips, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        -- cardarea == G.jokers is what marks the once-a-round Joker pass; the
        -- same context reaches a Joker several times without it.
        if context.end_of_round and context.cardarea == G.jokers
            and not context.blueprint then
            local leaves = 0
            for _, held in ipairs((G.hand and G.hand.cards) or {}) do
                if held.is_suit and held:is_suit(CelestasMod.LEAF_SUIT) then
                    leaves = leaves + 1
                end
            end
            if leaves == 0 then return end

            state.chips = state.chips + state.per * leaves
            return {
                message = localize { type = "variable", key = "a_chips",
                                     vars = { state.chips } },
                colour = G.C.CHIPS, card = card,
            }
        end

        if context.joker_main and state.chips > 0 then
            return { chips = state.chips }
        end
    end,
})

-- Haruka Karibu + Henya: Haruka is about consumables and Henya about money,
-- so spending one pays.
special("j_celesta_harukakaribu", "j_celesta_henya", {
    key = "haruka_henya",
    config = { dollars = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if context.using_consumeable and not context.blueprint then
            return { dollars = state.dollars, card = card }
        end
    end,
})

-- Haruka Karibu + Nyanners: the same consumables, counted where they sit
-- rather than as they are spent.
special("j_celesta_harukakaribu", "j_celesta_nyanners", {
    key = "haruka_nyanners",
    config = { per = 75 },

    loc_vars = function(def, card, state)
        local held = #((G.consumeables and G.consumeables.cards) or {})
        return { vars = { state.per, state.per * held } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local held = #((G.consumeables and G.consumeables.cards) or {})
        if held == 0 then return end
        return { chips = state.per * held }
    end,
})

-- CDawg + Ironmouse: CDawg keeps what the Commons left behind and Ironmouse is
-- the exponent, so the pile of them is one.
--
-- Read off the run's own tally rather than counted here, so it is the same
-- list CDawg is retaining - see jokers/cdawg.lua.
special("j_celesta_cdawg", "j_celesta_ironmouse", {
    key = "cdawg_ironmouse",
    config = { e_mult_gain = 0.1 },

    loc_vars = function(def, card, state)
        local sold = CelestasMod.commons_sold and CelestasMod.commons_sold() or 0
        return { vars = { state.e_mult_gain, 1 + state.e_mult_gain * sold } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local sold = CelestasMod.commons_sold and CelestasMod.commons_sold() or 0
        local e_mult = 1 + state.e_mult_gain * sold
        if e_mult <= 1 then return end
        if Card.get_chip_e_mult == nil then
            CelestasMod.warn_once("cdawg_ironmouse_no_talisman",
                "CDawg + Ironmouse scores ^Mult, which needs Talisman; "
                .. "without it the pair does nothing")
            return
        end
        return { e_mult = e_mult }
    end,
})

--------------------------------------------------------------------------------
-- Two more quads
--------------------------------------------------------------------------------

-- The Wildcard Club: AmaLee brings the Snowstorm, Ironmouse is the exponent,
-- and the other two are along for it. What the four of them do is stand in
-- their own weather and grow in it.
--
-- The freeze immunity is not in `calculate` - being frozen is not something a
-- Joker is asked about. It is wrapped onto CelestasMod.freeze below, which is
-- the one place a Joker is frozen from, the same way Cryogen's is.
CelestasMod.WILDCARD_CLUB_KEY = "quad_wildcard_club"

quad({
    key = CelestasMod.WILDCARD_CLUB_KEY,
    members = { "j_celesta_amalee", "j_celesta_ironmouse",
                "j_celesta_rinpenrose", "j_celesta_dokibird" },
    config = { e_mult = 1, e_mult_gain = 0.1, per_chips = 300, pool = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_mult_gain, state.per_chips, state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.setting_blind and not context.blueprint then
            if not CelestasMod.Arena.is_active("snowstorm") then
                CelestasMod.Arena.start("snowstorm")
                return {
                    message = localize("celesta_snowstorm"),
                    colour = G.C.BLUE, card = card,
                }
            end
            return
        end

        -- Counted after the hand rather than during it, so one hand is one
        -- helping of Chips however many Jokers added to it. hand_chips is the
        -- running total evaluate_play keeps, and chips_so_far is what the rest
        -- of this file reads it through.
        if context.after and not context.blueprint
            and CelestasMod.Arena.is_active("snowstorm") then
            local chips = chips_so_far()
            if not chips or chips <= 0 then return end

            -- The remainder is KEPT. Two hands of 200 are 400 Chips scored and
            -- so are worth one step, which throwing the leftovers away every
            -- hand would never pay out.
            state.pool = (state.pool or 0) + chips
            local steps = math.floor(state.pool / state.per_chips)
            if steps <= 0 then return end

            state.pool = state.pool - steps * state.per_chips
            state.e_mult = state.e_mult + state.e_mult_gain * steps
            return {
                message = localize { type = "variable", key = "celesta_powmult",
                                     vars = { state.e_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main and (state.e_mult or 1) > 1 then
            if Card.get_chip_e_mult == nil then
                CelestasMod.warn_once("wildcard_club_no_talisman",
                    "The Wildcard Club scores ^Mult, which needs Talisman; "
                    .. "without it the group does nothing")
                return
            end
            return { e_mult = state.e_mult }
        end
    end,
})

-- Nothing freezes a Wildcard Club. CelestasMod.freeze is the one place a Joker
-- is frozen from - AmaLee, Vulpixie and the Snowstorm all end up there - so
-- wrapping it catches every route, and refusing rather than thawing keeps the
-- answer honest for the callers that pay out on it. Cryogen's immunity is the
-- same shape; the two sit on top of each other without either noticing.
local celesta_wildcard_freeze_ref = CelestasMod.freeze
if celesta_wildcard_freeze_ref then
    function CelestasMod.freeze(card, rounds)
        local def = card and Bind.replacing_special and Bind.replacing_special(card)
        if def and def.key == CelestasMod.WILDCARD_CLUB_KEY then return false end
        return celesta_wildcard_freeze_ref(card, rounds)
    end
end

-- VchiBan: Shiabun hands out selection and Buffpup, AiCandii and Rosedoodle
-- are the three that care about Leaf cards, so the group is both halves of
-- that at once.
--
-- The selection half is granted through SELECTION_PAIRS above rather than from
-- `calculate`: that pass already owns the running total this mod has handed
-- out, and it is what gives the limit back when the merge stops being in the
-- row.
quad({
    key = "quad_vchiban",
    members = { "j_celesta_buffpup", "j_celesta_aicandii",
                "j_celesta_rosedoodle", "j_celesta_shiabun" },
    config = { odds = 2, x_chips = 1.5 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_quad_vchiban")
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR, true)
        local round = G.GAME and G.GAME.current_round
        return { vars = { (round and round.discards_left) or 0,
                          n, d, state.x_chips, name, colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
            and context.other_card and context.other_card.is_suit
            and context.other_card:is_suit(CelestasMod.LEAF_SUIT)) then
            return
        end
        if SMODS.pseudorandom_probability(card, "celesta_bind_quad_vchiban",
                                          1, state.odds) then
            return { x_chips = state.x_chips, card = card }
        end
    end,
})

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
--- The wedges a quad's four faces are drawn into, as polygons of the canvas.
---
--- Both diagonals, forming an X, so the four regions are top, right, bottom
--- and left. Members are laid into them in merge order, which is the order
--- Bind.members_of hands them back.
local function quad_wedges(w, h)
    local cx, cy = w / 2, h / 2
    return {
        { 0, 0, w, 0, cx, cy },   -- top
        { w, 0, w, h, cx, cy },   -- right
        { 0, h, w, h, cx, cy },   -- bottom
        { 0, 0, 0, h, cx, cy },   -- left
    }
end

local function build_art(card)
    local members = Bind.members_of(card)
    local faces = {}
    -- The host draws from its own centre, which may have been swapped; the
    -- rest are looked up by key.
    for index, key in ipairs(members) do
        local center = (index == 1) and card.config.center or G.P_CENTERS[key]
        local image, quad = face_of(center)
        if not image then return nil end
        faces[index] = { image = image, quad = quad }
    end
    if #faces < 2 then return nil end

    local host_image, host_quad = faces[1].image, faces[1].quad
    local other_image, other_quad = faces[2].image, faces[2].quad

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

    if #faces >= 4 then
        -- Four faces, one per wedge of the X.
        for index, wedge in ipairs(quad_wedges(w, h)) do
            local face = faces[index]
            love.graphics.stencil(function()
                love.graphics.polygon("fill", unpack(wedge))
            end, "replace", 1)
            love.graphics.setStencilTest("greater", 0)
            love.graphics.draw(face.image, face.quad, 0, 0)
            love.graphics.setStencilTest()
        end
    else
        -- The split runs bottom-left to top-right, so the host keeps the corner
        -- above that line and the absorbed half takes the one below it.
        love.graphics.draw(host_image, host_quad, 0, 0)
        love.graphics.stencil(function()
            love.graphics.polygon("fill", 0, h, w, h, w, 0)
        end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        love.graphics.draw(other_image, other_quad, 0, 0)
        love.graphics.setStencilTest()
    end

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
        -- The second diagonal, which is what makes the X. Only a quad has one.
        if #faces >= 4 then love.graphics.line(0, 0, w, h) end
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
        -- Ordered by the row, so the leftmost card is the host and the merge
        -- lands where the player already expects it rather than jumping.
        local ordered = {}
        for _, joker in ipairs(G.jokers.cards) do
            for _, one in ipairs(picked) do
                if joker == one then ordered[#ordered + 1] = joker break end
            end
        end
        local host, absorbed = ordered[1], ordered[2]

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                play_sound("gold_seal", 1.2, 0.6)
                host:juice_up(0.4, 0.5)
                if #ordered > 2 or Bind.is_merged(host)
                    or Bind.is_merged(absorbed) then
                    Bind.merge_quad(ordered)
                else
                    Bind.merge(host, absorbed)
                end
                return true
            end,
        })
        delay(0.6)
    end,
}

-- FOUR Jokers have to be selectable at once. Vanilla builds G.jokers with
-- highlight_limit = 1, which would make Bind impossible to satisfy. Raised to
-- exactly 4 rather than something large, so the rest of the game's
-- single-selection behaviour is disturbed as little as possible - four is what
-- a quad merge needs when all four are still loose, and nothing here wants a
-- fifth. Cryptid sets this to 1e100 for its own cards; whoever asks for more
-- wins.
--
-- The code this describes is at the bottom of the file, in the start_run hook:
-- it has to run after a run exists, and there is one such hook rather than two.
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
        and (G.jokers.config.highlighted_limit or 1) < Bind.SELECT_LIMIT then
        G.jokers.config.highlighted_limit = Bind.SELECT_LIMIT
    end
    return ret
end
