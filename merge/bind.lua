--- BIND: merging two Jokers into one
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

--- The host a card is standing in front of while one half is lent its centre.
---
--- Three places lend a merged card to its absorbed half - that half's
--- calculate, that half's centre hooks, and that half's description - and
--- through all three the card looks like that half ALONE: its centre is the
--- half's, and the ability it is carrying has no celesta_bind on it. So every
--- question about what is in the ROW, asked from inside one of them, could not
--- see the host.
---
--- That window is where such questions get asked. A chance is fixed by a pass
--- raised from inside the calculate of the Joker rolling it, which is how Ellie
--- Minibot merged with Shoto stopped guaranteeing Shoto's chance.
---
--- Weak keys: a card that is gone should not be kept alive by being remembered
--- here, and a lend that somehow never ended should not pin one either.
Bind.lent = setmetatable({}, { __mode = "k" })

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

--- The two highlighted merged Jokers, or nil when the selection is not
--- exactly two of them.
---
--- Stricter than Bind.selection on purpose: every card has to be a pair
--- already, because a swap trades second halves and a card without one has
--- nothing to put on the table.
function Bind.swap_selection()
    if not (G.jokers and G.jokers.highlighted) then return nil end
    local picked = {}
    for _, joker in ipairs(G.jokers.highlighted) do
        if not (Bind.is_merged(joker) and not Bind.is_quad(joker)) then return nil end
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

--- `fresh` is a card being BORN merged rather than merged in the row: the
--- Fusion Deck's offered Jokers. The pair itself is formed exactly the same
--- way. What it skips is everything that only makes sense for a card already
--- sitting in the deck, which is the CATCHING UP a row merge exists to do:
---
---   * the passives, on both sides. Neither half has applied one, because the
---     card has not entered the deck - and Card:add_to_deck, hooked further
---     down, gives a merged card both halves' passives when it arrives, which
---     is the moment they are owed. Applying them here would grant them for a
---     Joker still in a shop.
---   * the edition coin-flip. resolve_edition is there to settle two real
---     cards holding two editions down to one; a stand-in partner holds none,
---     so there is nothing to settle and the host keeps its own. Flipping
---     anyway would take a Polychrome off a shop Joker half the time.
---   * the arrival sounds. Nothing has arrived, and a shop of six would play
---     twelve.
---   * dissolving the absorbed half. It is a stand-in built to carry an
---     ability table, never in a CardArea and never drawn, so there is nothing
---     to animate away; its maker disposes of it.
function Bind.merge(host, absorbed, fresh)
    if not (Bind.can_bind(host) and Bind.can_bind(absorbed)) then return false end

    -- Spelled out rather than folded into an `and`/`or`: resolve_edition
    -- answering nil is not a missing answer, it is the edition being lost, and
    -- an expression would fall straight through that to the host's own.
    local edition = host.edition
    if not fresh then
        edition = Bind.resolve_edition(host.edition, absorbed.edition)
    end

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

    if not fresh then host:set_edition(edition, true, true) end

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

    -- Everything that follows from a pair now existing on this card, which
    -- is the half of merging that a SWAP does too. Through the table, not a
    -- local: it is declared with the rest of the passive hooks two thousand
    -- lines below this, so a bare name here would compile as a global and be
    -- nil.
    Bind.pair_formed(host, fresh)

    -- Everything from here down is about a row: an arrival to announce, and a
    -- card to take out of it. A card born merged has neither.
    if fresh then return true end

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

--- Records every merge there is as made, and saves once. The Config tab's
--- button, beside the two that unlock and discover every Joker.
---
--- Here rather than in the caller because the store is this file's: reaching
--- it from outside would mean mark_special_seen per merge, and that saves the
--- profile on every write.
---
--- Returns how many were newly marked, so a second press can say nothing
--- happened rather than write and save again.
function Bind.mark_every_special_seen()
    local store = seen_store()
    if not store then return 0 end

    local marked = 0
    for _, group in ipairs({ Bind.QUADS, Bind.SPECIALS, Bind.WILDCARDS }) do
        for _, def in pairs(group or {}) do
            if def.key and not store[def.key] then
                store[def.key] = true
                marked = marked + 1
            end
        end
    end

    if marked > 0 and G.save_progress then G:save_progress() end
    return marked
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

--- One consumable set at random, out of every set the game has registered.
---
--- SORTED before the pick, because pairs() walks a table in whatever order it
--- likes and the same seed has to give the same card twice. The fallback is
--- for a Steamodded that has registered nothing yet: picking from an empty
--- list is nil, and SMODS.add_card would make nothing at all.
---
--- Every registered set counts, this mod's own included - a Stamp arriving
--- this way rolls its kind in set_ability like any other, so it is a working
--- card rather than a blank one.
local function any_consumable_set(seed)
    local sets = {}
    for key in pairs(SMODS.ConsumableTypes or {}) do sets[#sets + 1] = key end
    table.sort(sets)
    if #sets == 0 then sets = { "Tarot", "Planet", "Spectral" } end
    return pseudorandom_element(sets, pseudoseed(seed))
end

--- How many cards in the run's deck carry `enhancement`.
---
--- G.playing_cards is the deck as a whole, wherever each card happens to be
--- sitting - hand, draw pile, discard - which is what "in your full deck"
--- means everywhere in this file. The enhancement is asked rather than the
--- centre, so a card made Wild by any route counts, the way Jummy's does.
---
--- nil is 0 rather than an error: a key read off CelestasMod.ENHANCEMENT_KEYS
--- before that table exists would otherwise take the hand down.
local function enhanced_in_deck(enhancement)
    if not enhancement then return 0 end
    local count = 0
    for _, held in ipairs(G.playing_cards or {}) do
        if SMODS.has_enhancement(held, enhancement) then count = count + 1 end
    end
    return count
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

        local set = any_consumable_set("celesta_bind_mari_papa")

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

    on_merge = function(def, card, state, fresh)
        card.ability.h_size = state.h_size
        card.ability.d_size = state.d_size
        -- The fields are the point, and they are written either way: vanilla's
        -- Card:add_to_deck is what applies them, so a card born merged gets
        -- both numbers when it is bought. Only the catch-up below is skipped.
        if fresh then return end
        Bind.intrinsic_passive(
            { h_size = state.h_size, d_size = state.d_size }, 1)
    end,

    on_unmerge = function(def, card, state, losing)
        Bind.intrinsic_passive(
            { h_size = state.h_size, d_size = state.d_size }, -1)

        -- ...and the numbers the pair wrote over are written back, so that
        -- what unmerge applies afterwards is the survivor's own. Only this
        -- pair needs it: SET, not added to, is how on_merge put the pair's
        -- numbers on the card, so the host's own are not underneath them.
        --
        -- Only when the HOST survives. The absorbed half's saved ability still
        -- carries its own numbers - nothing was written over them - and which
        -- half survives cannot be read off the card here, because the centre
        -- swap happens after this returns.
        if losing ~= "host" then
            local center = card.config.center
            local config = (type(center) == "table" and center.config) or {}
            card.ability.h_size = config.h_size or 0
            card.ability.d_size = config.d_size or 0
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

    on_merge = function(def, card, state, fresh)
        -- Ben's own conditional hand size is already gone by now, by both
        -- routes: Bind.merge takes the host centre's passive off when a
        -- special forms, and an absorbed card dissolves through Card:remove,
        -- which calls remove_from_deck on its way out. So this only adds.
        card.ability.h_size = (card.ability.h_size or 0) + state.h_size
        -- As above: the field is what applies on arrival, and only the
        -- catch-up for a card already holding the hand is skipped.
        if fresh then return end
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
-- true } - for one that is always the same. `enhancement` is the centre the
-- card arrives wearing, which is KokoNuts' own Lucky unless a pair says
-- otherwise - Eros + KokoNuts makes Bonus ones, because Bonus is what Eros
-- eats.
local function koko_sevens(card, count, seed, editioned, seal, enhancement)
    if count <= 0 then return end
    G.E_MANAGER:add_event(Event {
        func = function()
            local made = {}
            for i = 1, count do
                local seven = create_playing_card(
                    { front = G.P_CARDS.S_7,
                      center = enhancement or G.P_CENTERS.m_lucky },
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
            return nil, true
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

    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
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
-- cares about.
--
-- The Mult is permanent, which is BerryCrepe's own doing rather than an
-- embellishment: perma_mult is where a Mult bonus that outlives the hand
-- lives, it is scored by Card:get_chip_mult, and the card prints it as
-- "+N Mult" on its own with no display work here.
special("j_celesta_kumi", "j_celesta_berrycrepe", {
    key = "kumi_berry",
    config = { mult = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.mult } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        if not (other and SMODS.has_enhancement(other, "m_gold")) then return end

        other.ability.perma_mult = (other.ability.perma_mult or 0) + state.mult
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
            return nil, true
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

    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
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

--- An exponent is Talisman's; asked at score time, for the reason Vienna gives.
---
--- `what` is which half of the score the exponent is on, and it is only there
--- for the message: Mult unless a pair says otherwise. ObKatieKat's eight are
--- all ^Chips, and they ask through here rather than through a second copy of
--- this, so the two cannot come to disagree about what "Talisman is here"
--- means.
local function power_supported(id, name, what)
    if Card.get_chip_e_mult ~= nil then return true end
    CelestasMod.warn_once(id, name .. " scores ^" .. (what or "Mult")
        .. ", which needs Talisman; without it the pair does nothing")
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
        local out = celesta_bind_ease_dollars_ref(mod, ...)
        -- ...and Lab Brats' slots follow the wallet, so this is where they
        -- follow it. Its own calculate only runs during a scoring pass, which
        -- left the slots saying whatever the money said the last time a hand
        -- was played - so buying, selling or cashing out moved nothing until
        -- the next hand. AFTER the call, because the count is read off
        -- G.GAME.dollars and that is what has just changed.
        if CelestasMod.lab_brats_sync then CelestasMod.lab_brats_sync() end
        return out
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
    local keys = CelestasMod.ENHANCEMENT_KEYS
    return enhanced_in_deck(keys and keys.Limestone)
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
--- A scoring global as a plain number, or 0 when it is not one this can use.
---
--- Talisman swaps these for big-number objects once scores outgrow a double,
--- hence the conversion - and the finite check, because a non-finite value
--- banked into a pair's state would be serialized into the save as inf or nan
--- and come back as something no comparison can handle. Past that scale a pair
--- stops banking rather than corrupting the run.
local function scored_number(value)
    local n = value
    if type(n) ~= "number" and type(to_number) == "function" then
        local ok, converted = pcall(to_number, n)
        n = ok and converted or nil
    end
    if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then return 0 end
    return n
end

--- The Chips the hand just scored.
local function scored_chips() return scored_number(hand_chips) end

--- ...and the Mult. `mult` is the global Balatro keeps the running multiplier
--- in, and the ordinary scoring path never clears it - only the "hand not
--- allowed" branch does (state_events.lua:786), and that never reaches the
--- `after` pass either of these is read in.
local function scored_mult() return scored_number(mult) end

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
    local total = value + gain
    -- Rounded to three places so the card reads cleanly - but only while it is
    -- a plain number. Talisman's are tables and math.floor refuses them
    -- outright, which is reachable now that Vedal can accelerate one of these
    -- counts; and a number that large has nothing left worth rounding.
    if type(total) ~= "number" then return total end
    return math.floor(total * 1000 + 0.5) / 1000
end


--- Ironmouse's ^Mult, the way every pair of hers pays it.
local function ironmouse_pays(key, label, e_mult)
    -- more_than rather than `<=`: Ironmouse + Silvervale counts a run tally
    -- that Vedal can accelerate, and an accelerated one is a Talisman number,
    -- which Lua 5.1 refuses to compare against 1.
    if not CelestasMod.more_than(e_mult, 1) then return nil end
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
                          pow_after(1, CelestasMod.vedal_counted
                              and CelestasMod.vedal_counted(card, state.e_mult_gain, CelestasMod.rares_sold())
                              or state.e_mult_gain * CelestasMod.rares_sold()) } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local sold = CelestasMod.rares_sold()
        local e_mult = pow_after(1, CelestasMod.vedal_counted
            and CelestasMod.vedal_counted(card, state.e_mult_gain, sold)
            or state.e_mult_gain * sold)
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
            return nil, true
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
    --
    -- Read before celesta_bind is cleared, and needed again at the bottom:
    -- under a replacing pair NEITHER half's own passive is on, so the survivor
    -- has one to get back.
    local was_replacing = Bind.replacing_special(card) ~= nil
    if not was_replacing then
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

        -- SMODS keeps two slot-bookkeeping fields on every ability table and
        -- Card:set_ability is the only thing that writes them (card.lua:376),
        -- so a table installed wholesale has to bring them itself.
        -- CardArea:update sums both across the row every frame without a nil
        -- guard (smods src/utils.lua:3182), and a card missing one crashes the
        -- game rather than miscounting.
        --
        -- The merged card's own values, not zeroes: the row has already
        -- counted those slots, and zeroing here would take them off the player
        -- for having unmerged.
        for _, field in ipairs({ "card_limit", "extra_slots_used" }) do
            surviving_ability[field] = card.ability[field]
                or surviving_ability[field] or 0
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

    -- The survivor is a lone Joker again, and gets its own passive back.
    --
    -- Only after a REPLACING pair, because only that takes both halves' off:
    -- Bind.merge removes the host's when the pair forms and
    -- apply_partner_passive declines to apply the absorbed half's at all, the
    -- pair standing in for both. An additive pair kept them, and there is
    -- nothing owed.
    --
    -- Here rather than beside the removals above, because this is after the
    -- centre and ability swap: `card` is the survivor whichever half left, and
    -- its own centre and its own numbers are what go back on.
    if was_replacing then
        local center = card.config.center
        if type(center) == "table" and type(center.add_to_deck) == "function" then
            pcall(center.add_to_deck, center, card, false)
        end
        Bind.intrinsic_passive(card.ability, 1)
    end

    Bind.invalidate_art(card)
    card.ability_UIBox_table = nil          -- the two-panel description is stale
    if card.juice_up then card:juice_up(0.4, 0.5) end
    return true
end

--- Undoes a destruction that is not going to happen after all.
---
--- A Joker that removes itself animates first and removes second, so by the
--- time Card:remove can object the card is already dressed for its own
--- funeral. Two shapes, and a survivor must be let out of both:
---
---   * the extinction one tips the card, holds it as though it were being
---     dragged, and pinches the centre sprite (card.lua:2342 - Gros Michel,
---     Cavendish, and Hidden Tech which copies them). A pinched sprite eases
---     its width to zero and stays there (engine/moveable.lua:439), so the
---     card goes on holding its Joker slot while drawing nothing at all.
---   * start_dissolve eases `dissolve` to 1 and calls remove at the end of it,
---     and SMODS.destroy_cards marks the card sliced and destroyed before it
---     starts (smods src/utils.lua:2575). Left on, `destroyed` picks the
---     colours of a dissolve that already happened and `getting_sliced` makes
---     the next destruction ask whether it may proceed as though this one were
---     still in progress.
---
--- Not a reset of the card: only the marks those two put on it.
local function cancel_destruction(card)
    card.dissolve = nil
    card.dissolve_colours = nil
    card.getting_sliced = nil
    card.destroyed = nil

    -- The resting rotation of a Joker in the row; the animation tipped it to
    -- -0.2 and nothing else was going to tip it back.
    if card.T then card.T.r = 0 end
    if card.states and card.states.drag then card.states.drag.is = false end

    local sprite = card.children and card.children.center
    if sprite and sprite.pinch then
        -- Only x is ever set by either animation, but a sprite easing to
        -- nothing in either direction is the same invisible card.
        sprite.pinch.x = false
        sprite.pinch.y = false
    end
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
            -- Before it goes back, so that it goes back drawable and so that
            -- align_cards is not handed a card that still says it is held.
            cancel_destruction(self)
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

--- True for a value the arithmetic below can be done on.
---
--- Not `type(v) == "number"`, and that distinction is the whole of a reported
--- bug. Talisman is a dependency of this mod, and what it does once a number
--- grows large is replace it with an object of its own; those add and multiply
--- exactly as numbers do, which is what they are for, but `type` says "table".
--- Tested on `type` alone, a half whose Mult had got big made the OTHER half's
--- Mult fall through to the `existing == nil` branch, which declines to
--- overwrite - so the second Joker went on scaling and silently stopped paying.
---
--- The same test vedal_rewrite makes before it raises a rate to a power.
local function numeric(value)
    if type(value) == "number" then return true end
    if type(value) ~= "table" then return false end
    local meta = getmetatable(value)
    return (meta and (meta.__add or meta.__mul)) and true or false
end

--- Folds the absorbed half's effect into the host's.
--- Additive values add and multiplicative ones multiply, which is what makes a
--- +4 Mult bound to a X3 Mult behave like owning both Jokers.
---
--- Mixing one of Talisman's numbers with a plain one is arithmetic either way
--- round: Lua reaches for the metamethod whichever side carries it.
local function combine(primary, secondary)
    if not primary then return secondary end
    if not secondary then return primary end
    for key, value in pairs(secondary) do
        local existing = primary[key]
        if numeric(value) and numeric(existing) then
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
        -- Three values, not two. A pair that did its work in a queued
        -- event has no effect table to show and says so the way vanilla does,
        -- with `nil, true` - and that second value is what tells eval_card the
        -- Joker triggered, which is what it asks before it will consider
        -- retriggering it at all. Captured here or it is lost on the way out.
        local ok, ret, ret_triggered = pcall(def.calculate, def, self, context, state)
        running[self] = nil
        if not ok then
            CelestasMod.warn_once("bind_special_" .. tostring(def.key),
                ("Bind pair %s failed: %s"):format(tostring(def.key), tostring(ret)))
            return (def.additive and effect or nil), post
        end
        -- A replacing pair is the whole answer. An additive one is one more
        -- voice, so it falls through and is combined with both halves below.
        if not def.additive then return ret, ret_triggered or post end
        post = post or ret_triggered
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
    -- Recorded before the swap, for the reason partner_special gives: the
    -- lent ability has no celesta_bind, so without this the absorbed half
    -- cannot see the pair it is running under.
    local saved_special = partner_special[self]
    partner_special[self] = Bind.special_of(self)
    self.config.center = center
    self.config.center_key = center.key or saved_key
    self.ability = self.ability.celesta_bind.ability
    local saved_lent = Bind.lent[self]
    Bind.lent[self] = { center = saved_center, ability = saved_ability }
    local ok, partner = pcall(with_acting_half, self, "absorbed",
                              celesta_bind_calculate_joker_ref, self, context)
    Bind.lent[self] = saved_lent
    self.config.center, self.ability = saved_center, saved_ability
    self.config.center_key = saved_key
    partner_special[self] = saved_special
    running[self] = nil

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
    -- AiCandii + Shiabun: VchiBan's selection half on its own. Shiabun hands
    -- out the picks, AiCandii counts the Discards left, and the two together
    -- are one pick per discard not yet spent.
    aicandii_shiabun = function(state)
        local round = G.GAME and G.GAME.current_round
        return (round and round.discards_left) or 0
    end,
    -- Kairyu + Shiabun: the same, the other way up. Kairyu is the Joker that
    -- wants the discards SPENT, so the picks arrive as they are used rather
    -- than being lent against the ones still in hand. discards_used is the
    -- run's own count and it is cleared with the round, which is the whole of
    -- what "for the round" means.
    kairyu_shiabun = function(state)
        local round = G.GAME and G.GAME.current_round
        return (round and round.discards_used) or 0
    end,
    -- Mint Fantome + Snuffy: Snuffy's own count and one more. It moves within
    -- a round as Hands are spent, which is what this pass is here for.
    mint_snuffy = function(state)
        local round = G.GAME and G.GAME.current_round
        return ((round and round.hands_left) or 0) + (state.extra or 0)
    end,
}

--- What each card has been granted. Weak keys: a card that is gone should not
--- be kept alive by being remembered here.
local selection_granted = setmetatable({}, { __mode = "k" })

--- The run those grants belong to, by seed.
local selection_run = nil

local function selection_limit_sync()
    if not (SMODS.change_play_limit and SMODS.change_discard_limit) then return end

    -- What the two SMODS calls actually read: starting_params and
    -- G.hand.config (smods src/utils.lua:2617). Game:update runs this every
    -- frame forever, and a finished run is torn down with G.STAGE still set to
    -- RUN - so the stage is no guard, and G.hand going first is what crashed
    -- this pass trying to hand a limit back.
    if not (G.GAME and G.GAME.starting_params and G.hand and G.hand.config) then
        return
    end

    -- A new run owns none of the last one's grants. starting_params is rebuilt
    -- at the start of a run, so handing one back here would take a limit this
    -- run was never given. Dropped rather than released, for that reason.
    local run = G.GAME.pseudorandom and G.GAME.pseudorandom.seed
    if run ~= selection_run then
        for card in pairs(selection_granted) do selection_granted[card] = nil end
        selection_run = run
    end

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

--------------------------------------------------------------------------------
-- Booster slots that move with the run
--------------------------------------------------------------------------------
--
-- The pass above, for packs, and for the same reasons. A pair whose grant is
-- a COUNT of something cannot hand it over once in add_to_deck: the deck it is
-- counting changes under it. So the number is asked of the world each frame
-- and the run is moved by the difference.
--
-- Released by the same pass rather than by a hook: a pair that is sold,
-- debuffed, unmerged or destroyed simply stops being in the row, and one place
-- noticing that covers all four.

local BOOSTER_PAIRS = {
    heavenly_arielle = function(state)
        return CelestasMod.unique_suits_in_deck() * state.per
    end,
}

--- What each card has been granted. Weak keys, as above: a card that is gone
--- should not be kept alive by being remembered here.
local booster_granted = setmetatable({}, { __mode = "k" })

--- ...and the run those belong to, for the reason above.
local booster_run = nil

local function booster_limit_sync()
    if not SMODS.change_booster_limit then return end

    -- change_booster_limit reads G.GAME.modifiers (smods src/utils.lua:2406),
    -- and this pass runs every frame including with no run at all.
    if not (G.GAME and G.GAME.modifiers) then return end

    local run = G.GAME.pseudorandom and G.GAME.pseudorandom.seed
    if run ~= booster_run then
        for card in pairs(booster_granted) do booster_granted[card] = nil end
        booster_run = run
    end

    local live = nil
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        local def = (not held.debuff) and Bind.special_of(held)
        local wanted = def and BOOSTER_PAIRS[def.key]
        if wanted then
            local ok, want = pcall(wanted, Bind.special_state(held, def))
            if ok and type(want) == "number" then
                live = live or {}
                live[held] = math.max(0, math.floor(want))
            end
        end
    end

    for card, granted in pairs(booster_granted) do
        if not (live and live[card]) and granted ~= 0 then
            SMODS.change_booster_limit(-granted)
            booster_granted[card] = nil
        end
    end

    for card, want in pairs(live or {}) do
        local granted = booster_granted[card] or 0
        if want ~= granted then
            -- change_booster_limit puts a pack straight into an OPEN shop when
            -- the number goes up (utils.lua:2407), so a suit gained while
            -- standing in one is a pack that appears there.
            SMODS.change_booster_limit(want - granted)
            booster_granted[card] = want
        end
    end
end

CelestasMod.Bind.booster_limit_sync = booster_limit_sync

local celesta_bind_booster_update_ref = Game and Game.update
if celesta_bind_booster_update_ref then
    function Game:update(dt)
        celesta_bind_booster_update_ref(self, dt)
        booster_limit_sync()
    end
end

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
    local saved_lent = Bind.lent[card]
    partner_special[card] = Bind.special_of(card)
    Bind.lent[card] = { center = saved_center, ability = saved_ability }
    card.config.center = center
    card.ability = card.ability.celesta_bind.ability
    local ok, ret = pcall(fn, center, card)
    card.config.center, card.ability = saved_center, saved_ability
    partner_special[card] = saved_special
    Bind.lent[card] = saved_lent

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
-- Runs on every card every frame, so the cheap test comes first: an unmerged
-- card takes the same path it always did, and neither of the two calls below
-- it does any work for one.
--
-- The host's OWN update is muffled under a replacing pair, the way its
-- calculate, its add_to_deck, its remove_from_deck and its calc_dollar_bonus
-- already are. For most Jokers that changes nothing, because update only
-- animates - but the four that GRANT from it leak without it, and leak in the
-- direction there is no way back from:
--
--   Snuffy raises the card selection limit and follows the number from here.
--   Merged with Dokibird the pair replaces both halves, so forming it takes
--   Snuffy's grant off through its remove_from_deck - and update handed it
--   straight back on the next frame. Selling the merge then muffles
--   remove_from_deck, so nothing ever gave it back, and the limit stayed up
--   for the rest of the run.
local celesta_bind_update_ref = Card.update
function Card:update(dt)
    if not Bind.is_merged(self) then
        celesta_bind_update_ref(self, dt)
        return
    end

    without_center_hook(self, "update", function()
        celesta_bind_update_ref(self, dt)
    end)
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

--- Everything that follows from a pair existing on a card that is in the row.
---
--- Shared by merging and by swapping, because they agree on this part and
--- differ on all the rest: a merge settles an edition, inherits stickers,
--- announces itself and dissolves the half that lost, and a swap does none of
--- those - nothing arrives and nothing leaves, two halves change places.
---
--- `fresh` is Bind.merge's: a card being born merged, which has not entered
--- the deck and so has no passive to move yet.
function Bind.pair_formed(host, fresh)
    if not fresh then Bind.apply_partner_passive(host) end

    -- A special REPLACES both halves, so a passive either of them applied when
    -- it entered the deck has to come off - the pair speaks for the card now.
    -- Only the host's: the absorbed half's was already taken back when it left
    -- the row, and Bind.apply_partner_passive above skips specials entirely.
    local def = Bind.special_of(host)
    if not def then return end

    Bind.mark_special_seen(def.key)

    -- Only a replacing pair takes the host's passive off; an additive one is
    -- keeping both halves, passives included. A fresh card has applied nothing
    -- yet, so there is nothing to take: what stops the host's own passive
    -- going on is without_center_hook, when the card is bought.
    if not fresh and Bind.replacing_special(host) then
        local center = host.config.center
        if type(center) == "table" and type(center.remove_from_deck) == "function" then
            pcall(center.remove_from_deck, center, host, false)
        end
        -- ...and its ability-driven ones, for the same reason: the pair speaks
        -- for the card now, so a hand size or a discard the host brought with
        -- it is no longer being granted by anything.
        Bind.intrinsic_passive(host.ability, -1)
    end

    if type(def.on_merge) == "function" then
        local ok, err = pcall(def.on_merge, def, host,
                              Bind.special_state(host, def), fresh)
        if not ok then
            CelestasMod.warn_once("bind_merge_" .. tostring(def.key),
                ("Bind pair %s failed to form: %s"):format(tostring(def.key), tostring(err)))
        end
    end
end

--- Trades the absorbed halves of two merged cards.
---
--- Each card is taken apart and put back together with the other's half. Both
--- are taken apart FIRST, because a swap is one move: doing one card at a time
--- would have the first card's new pair forming - passives, on_merge and all -
--- while the second still held the half it is about to give up.
---
--- Neither card moves and neither half is created or destroyed, so there is no
--- edition to settle, no sticker to inherit and nothing to dissolve. What does
--- change is which pair each card is, and that is what pair_formed says.
function Bind.swap(a, b)
    if not (a and b and a ~= b) then return false end
    -- Two halves is the whole question. A quad has four and no second half to
    -- trade; a loose Joker has none.
    for _, card in ipairs({ a, b }) do
        if not (Bind.is_merged(card) and not Bind.is_quad(card)) then return false end
    end

    local bound_a = a.ability.celesta_bind
    local bound_b = b.ability.celesta_bind
    if not (Bind.unmerge(a, "absorbed") and Bind.unmerge(b, "absorbed")) then
        return false
    end

    --- Puts `bound` onto `card`, which is a lone Joker in the row.
    local function attach(card, bound)
        -- The state belongs to the PAIR, not to the half carrying it: this
        -- half is joining a different Joker, so whatever the old pair had
        -- banked is not this one's. special_state builds a fresh one from the
        -- new pair's config when it is next asked.
        bound.special = nil
        -- What the card is worth on its own, for when it comes apart again.
        bound.host_sell_cost = card.sell_cost
        card.ability.celesta_bind = bound
        card.sell_cost = (card.sell_cost or 0) + (bound.sell_cost or 0)
        Bind.invalidate_art(card)
        card.ability_UIBox_table = nil
        Bind.pair_formed(card)
    end

    attach(a, bound_b)
    attach(b, bound_a)
    return true
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
    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
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
    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
        kairyu_add_to_deck(def, card, state, false)
    end,
    on_unmerge = function(def, card, state)
        kairyu_remove_from_deck(def, card, state, false)
    end,
})

--- A Mult card, which is the card Rosedoodle is about. Through
--- SMODS.has_enhancement for the reason every enhancement question here goes
--- through it: an enhancement another card is standing in for still counts.
local function bind_is_mult(other)
    return other ~= nil and SMODS.has_enhancement(other, "m_mult")
end

-- Kairyu + Rosedoodle: Kairyu grows the hand on what the round throws away,
-- Rosedoodle is the Mult card Joker. Together the hand grows on the Mult cards
-- discarded - one card for every three, which is Kairyu + PiaPiUFO's rate for
-- a suit that is not hard to come by, rather than Tori Oriane's one-for-one.
special("j_celesta_kairyucrocodile", "j_celesta_rosedoodle", {
    key = "kairyu_rosedoodle",
    config = { h_size = 1, per = 3, discarded = 0, applied = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.h_size, state.per, state.applied } }
    end,

    calculate = kairyu_discard_calculate(bind_is_mult),
    add_to_deck = kairyu_add_to_deck,
    remove_from_deck = kairyu_remove_from_deck,
    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
        kairyu_add_to_deck(def, card, state, false)
    end,
    on_unmerge = function(def, card, state)
        kairyu_remove_from_deck(def, card, state, false)
    end,
})

-- Kairyu + Giwi: Giwi is the Queens Joker, so the hand grows on the Queens
-- thrown away - one card for each of them, which is Tori Oriane's rate rather
-- than PiaPiUFO's one-in-three, because a deck holds four Queens and not a
-- quarter of itself.
--
-- The Queen test is Giwi's own, down to being asked through get_id: what Kael
-- says a card counts as is what every other rank question in this mod reads,
-- and this is no different.
special("j_celesta_kairyucrocodile", "j_celesta_giwi", {
    key = "kairyu_giwi",
    config = { h_size = 1, per = 1, discarded = 0, applied = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.h_size, state.applied } }
    end,

    calculate = kairyu_discard_calculate(function(other)
        return other ~= nil and other.get_id ~= nil and other:get_id() == 12
    end),
    add_to_deck = kairyu_add_to_deck,
    remove_from_deck = kairyu_remove_from_deck,
    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
        kairyu_add_to_deck(def, card, state, false)
    end,
    on_unmerge = function(def, card, state)
        kairyu_remove_from_deck(def, card, state, false)
    end,
})

-- Kairyu + Nihmune: Nihmune is the Clubs Joker, so the hand grows on the Clubs
-- thrown away - one card for every three, which is PiaPiUFO's rate rather than
-- Tori Oriane's one-for-one, because a deck holds a quarter of itself in Clubs
-- and a handful of True Stars.
--
-- Asked through is_suit rather than off base.suit, which is what every suit
-- question in this file does: a Wild Card is every suit, and a card Nihmune
-- itself converted is a Club by the only reading that matters.
special("j_celesta_kairyucrocodile", "j_celesta_nihmune", {
    key = "kairyu_nihmune",
    config = { h_size = 1, per = 3, discarded = 0, applied = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.h_size, state.per, state.applied } }
    end,

    calculate = kairyu_discard_calculate(function(other)
        return other ~= nil and other.is_suit ~= nil and other:is_suit("Clubs")
    end),
    add_to_deck = kairyu_add_to_deck,
    remove_from_deck = kairyu_remove_from_deck,
    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
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
---
--- Through CelestasMod.bump_limit rather than by writing config.card_limit,
--- and that is the whole of why this used to do nothing. Steamodded makes
--- card_limit a DERIVED property (lovely/card_limit.toml:30): reading it
--- returns `total_slots - extra_slots_used` and writing it back-computes
--- `mod = value - base - extra_slots`. Adding to it is therefore a
--- read-modify-write of a number the game rebuilds from `mod` on the next
--- frame, and it drops `extra_slots_used` on every pass - so on a row that
--- uses extra slots, which a Joker row holding this mod's slot-granters does,
--- the grant shrinks away underneath itself. bump_limit adds to `mod`, which
--- is stored rather than derived, and explains itself at length in
--- jokers/implemented.lua.
local function lab_sync(state)
    if not (G.GAME and G.jokers and G.jokers.config
        and G.consumeables and G.consumeables.config) then return end
    if not CelestasMod.bump_limit then return end
    local dollars = G.GAME.dollars or 0
    local want_consumable = math.floor(dollars / (state.per_consumable or 5))
    local want_joker = math.floor(dollars / (state.per_joker or 10))
    if want_consumable < 0 then want_consumable = 0 end
    if want_joker < 0 then want_joker = 0 end

    local had_c, had_j = state.consumable_applied or 0, state.joker_applied or 0
    if want_consumable ~= had_c then
        CelestasMod.bump_limit(G.consumeables, want_consumable - had_c)
        state.consumable_applied = want_consumable
    end
    if want_joker ~= had_j then
        CelestasMod.bump_limit(G.jokers, want_joker - had_j)
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

        -- "that many" is the slots THIS handed out, which is what the two
        -- sentences before it are about. It used to read the two areas' whole
        -- limits, which is the base slots plus every other Joker's grant as
        -- well - and those limits are derived now, so they are not a number
        -- this quad can claim to own anyway.
        if context.end_of_round and context.main_eval and not context.blueprint then
            local total = (state.consumable_applied or 0)
                + (state.joker_applied or 0)
            if total > 0 then return { dollars = total, card = card } end
        end
    end,

    add_to_deck = function(def, card, state, from_debuff)
        state.consumable_applied, state.joker_applied = 0, 0
        lab_sync(state)
    end,

    remove_from_deck = function(def, card, state, from_debuff)
        -- Given back the same way it was handed out, or the two would not
        -- cancel: one writing `mod` and the other a derived `card_limit`
        -- leaves the row holding slots nothing owns.
        if CelestasMod.bump_limit then
            CelestasMod.bump_limit(G.consumeables, -(state.consumable_applied or 0))
            CelestasMod.bump_limit(G.jokers, -(state.joker_applied or 0))
        end
        state.consumable_applied, state.joker_applied = 0, 0
    end,

    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
        def.add_to_deck(def, card, state, false)
    end,
    on_unmerge = function(def, card, state)
        def.remove_from_deck(def, card, state, false)
    end,
})

-- The Baulder Gang: Arielle, FroggyLoch, Arar and Jaws.
--
-- Arielle's one suit; FroggyLoch's retrigger, no longer rolled for; Arar's
-- enhancements as the thing worth going round twice for; and Jaws's counter,
-- fed by both halves of a scoring pass rather than by the cards it eats.
--
-- The suit half is answered through CelestasMod.SAME_SUIT_RULES rather than by
-- anything here: it is a question SMODS.smeared_check asks, long before any
-- Joker is consulted, and a quad replaces all four members - so the Arielle
-- inside this one is not in play as itself and the wrap would never find it.
CelestasMod.SAME_SUIT_RULES = CelestasMod.SAME_SUIT_RULES or {}
CelestasMod.SAME_SUIT_RULES[#CelestasMod.SAME_SUIT_RULES + 1] = function()
    return specials_held("quad_baulder_gang")[1] ~= nil
end

--- True for a card carrying any enhancement at all.
---
--- Against c_base, which is the unenhanced playing-card centre and the test
--- this mod already makes elsewhere. Not SMODS.has_enhancement, which wants a
--- named one; the question here is "any".
local function enhanced_at_all(card)
    local center = card and card.config and card.config.center
    return center ~= nil and G.P_CENTERS ~= nil
        and center ~= G.P_CENTERS.c_base
end

quad({
    key = "quad_baulder_gang",
    members = { "j_celesta_arielle", "j_celesta_froggyloch",
                "j_celesta_arar", "j_celesta_jaws" },
    config = { repetitions = 1, enhanced_repetitions = 2,
               chips = 0, chip_gain = 5 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions, state.enhanced_repetitions,
                          state.chip_gain, state.chips } }
    end,

    calculate = function(def, card, context, state)
        -- FroggyLoch's retrigger, certain rather than rolled, and twice over
        -- for the cards Arar has been enhancing. Twice INSTEAD of once, not on
        -- top of it: an enhanced card goes round twice.
        if context.repetition and context.cardarea == G.play
            and context.other_card then
            local times = enhanced_at_all(context.other_card)
                and state.enhanced_repetitions or state.repetitions
            if times <= 0 then return end
            return {
                message = localize("k_again_ex"),
                repetitions = times,
                card = card,
            }
        end

        -- Jaws's counter, fed by every card that scores...
        if context.individual and context.cardarea == G.play
            and context.other_card and not context.blueprint then
            state.chips = state.chips + state.chip_gain
            return {
                message = localize { type = "variable", key = "a_chips",
                                     vars = { state.chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        -- ...and by every other Joker that triggers.
        --
        -- Spongey's reading of post_trigger, filter and all: a probability
        -- lookup runs a full evaluation pass that arrives here looking exactly
        -- like a trigger, other_card is not always a Joker, and this must not
        -- pay itself for its own scoring.
        if context.post_trigger and not context.blueprint then
            local trigger = context.other_card
            local inner = context.other_context
            if inner and (inner.mod_probability or inner.fix_probability
                or inner.fixed_probability or inner.retrigger_joker_check) then
                return
            end
            if not (trigger and trigger.ability
                and trigger.ability.set == "Joker") then return end
            if trigger == card then return end

            state.chips = state.chips + state.chip_gain
            return {
                message = localize { type = "variable", key = "a_chips",
                                     vars = { state.chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        -- ...and what it has all come to, once a hand.
        if context.joker_main and state.chips > 0 then
            return { chips = state.chips }
        end
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
        return { vars = { state.e_mult_gain,
                          1 + (CelestasMod.vedal_counted
                              and CelestasMod.vedal_counted(card, state.e_mult_gain, sold)
                              or state.e_mult_gain * sold) } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local sold = CelestasMod.commons_sold and CelestasMod.commons_sold() or 0
        local e_mult = 1 + (CelestasMod.vedal_counted
            and CelestasMod.vedal_counted(card, state.e_mult_gain, sold)
            or state.e_mult_gain * sold)
        -- more_than, for the reason ironmouse_pays gives just above.
        if not CelestasMod.more_than(e_mult, 1) then return end
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
-- Zentreya's two
--------------------------------------------------------------------------------

--- Steel cards held in hand, which is what Zentreya is about.
---
--- Debuffed ones are left out: a debuffed Steel card does nothing, and
--- counting it would pay for a card that is not paying.
local function steel_in_hand()
    local n = 0
    for _, held in ipairs((G.hand and G.hand.cards) or {}) do
        if not held.debuff and SMODS.has_enhancement(held, "m_steel") then
            n = n + 1
        end
    end
    return n
end

-- Zentreya + Bluto: Bluto retriggers the two copiers a fixed extra time, and
-- Zentreya counts Steel cards. Together the count is the number of retriggers.
--
-- Same shape as Bluto's own, including the reason for `not
-- context.retrigger_joker`: without it a retrigger would retrigger, and the
-- count would compound until the game gave up. The copier list is read off
-- Bluto rather than restated, so a third copier taught to Bluto is taught to
-- this at the same time.
--
-- "When a hand is played" needs no test of its own - retrigger_joker_check is
-- only raised during the joker pass of a played hand.
special("j_celesta_zentreya", "j_celesta_bluto", {
    key = "zentreya_bluto",

    loc_vars = function(def, card, state)
        return { vars = { steel_in_hand() } }
    end,

    calculate = function(def, card, context, state)
        if not (context.retrigger_joker_check and not context.retrigger_joker) then
            return
        end
        local other = context.other_card
        local center = other and other.config and other.config.center
        local targets = CelestasMod.BLUTO_TARGETS or {}
        if not (center and other ~= card and targets[center.key]) then return end

        local steel = steel_in_hand()
        if steel <= 0 then return end
        return { repetitions = steel }
    end,
})

-- Zentreya + Kumi: Kumi is the Gold card Joker and Zentreya raises what a card
-- held in hand is worth, so a Gold card is worth more.
--
-- INSTEAD of, not on top of, which is why this is not a `dollars` handed back
-- from calculate: that would pay a second time alongside the enhancement's own
-- and the card would read "+$3" and then "+$2". Card:get_h_dollars is the one
-- place a card held in hand is asked what it pays (card.lua:1240), so the
-- enhancement's own number is taken back out there and the pair's put in - one
-- payout, one popup, and any perma_h_dollars on the card still counted.
local GOLD_PAYOUT_PAIR = "zentreya_kumi"

special("j_celesta_zentreya", "j_celesta_kumi", {
    key = GOLD_PAYOUT_PAIR,
    config = { pay = 5 },

    loc_vars = function(def, card, state)
        return { vars = { state.pay } }
    end,

    -- The whole of it is the hook below; there is nothing to do in the pass.
    calculate = function(def, card, context, state) end,
})

--- What a Gold card is on while this pair is in the row, or nil when it is
--- not. The leftmost wins, the way the Joker row settles every disagreement.
local function gold_payout()
    for _, held in ipairs(specials_held(GOLD_PAYOUT_PAIR)) do
        local state = Bind.special_state(held.card, held.def)
        if state and type(state.pay) == "number" then return state.pay end
    end
    return nil
end

local celesta_bind_h_dollars_ref = Card.get_h_dollars

function Card:get_h_dollars(...)
    local ret = celesta_bind_h_dollars_ref(self, ...)
    -- A debuffed card pays nothing and the reference has already said so.
    if self.debuff or not SMODS.has_enhancement(self, "m_gold") then
        return ret
    end

    local pay = gold_payout()
    if not pay then return ret end
    return ret - (self.ability.h_dollars or 0) + pay
end

--------------------------------------------------------------------------------
-- Nihmune + Michi
--------------------------------------------------------------------------------
--
-- Nihmune turns cards into Clubs and Michi makes Tarots out of what is thrown
-- away, so a discarded Club is sometimes a Tarot.
--
-- Michi's own shape: the buffer is claimed BEFORE the event and released
-- inside it, because a discard sends this context once per discarded card and
-- the slots would otherwise be counted as empty for every card in the same
-- discard. The roll comes after the room check for the same reason it does on
-- every other card here - a chance spent on a slot that does not exist is a
-- chance the player never had.

special("j_celesta_nihmune", "j_celesta_michi", {
    key = "nihmune_michi",
    config = { odds = 3 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_nihmune_michi")
        return { vars = { n, d } }
    end,

    calculate = function(def, card, context, state)
        if not (context.discard and context.other_card and not context.blueprint) then
            return
        end
        local other = context.other_card
        -- is_suit rather than base.suit, so a Wild card, a smeared suit and
        -- Nihmune's own conversions all count as the Club they play as.
        if not (other.is_suit and other:is_suit("Clubs")) then return end

        if #G.consumeables.cards + (G.GAME.consumeable_buffer or 0)
            >= G.consumeables.config.card_limit then
            return
        end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_nihmune_michi",
                1, state.odds, "celesta_bind_nihmune_michi") then
            return
        end

        G.GAME.consumeable_buffer = (G.GAME.consumeable_buffer or 0) + 1
        G.E_MANAGER:add_event(Event {
            trigger = "before",
            delay = 0.0,
            func = function()
                local made = SMODS.add_card {
                    set = "Tarot", key_append = "celesta_bind_nihmune_michi" }
                if made then made:juice_up(0.3, 0.5) end
                G.GAME.consumeable_buffer = 0
                return true
            end
        })
        return { message = localize("k_plus_tarot"), colour = G.C.PURPLE,
                 card = card }
    end,
})

--------------------------------------------------------------------------------
-- Ray + Glassesjournal
--------------------------------------------------------------------------------
--
-- Ray makes a thing happen again and Glassesjournal decides what reaches the
-- hand, so the cards this deck keeps playing are the ones it keeps drawing.
--
-- `deal_weight` rather than `deal_first`: every other Glassesjournal merge
-- picks a CATEGORY out of the deck and puts it at the front, which is a yes or
-- a no, and this ranks cards against each other. jokers/implemented.lua sorts
-- each place by the total weight, heaviest dealt first, and leaves the
-- shuffle's order between equals - so a deck nothing has been played out of
-- deals exactly as it did before.
--
-- The count is kept on the card and starts when the pair does. Nothing in the
-- game has been counting how often a particular card is played, so there is
-- no honest number to backfill; a card played twice since the merge is ahead
-- of one played once, and that is all this can truthfully know.
--
-- Counted at context.before, which is the whole played hand rather than the
-- scoring part of it: a card that was played is a card that was played. Copies
-- are refused so a Blueprint does not double the count of a hand played once.

local RAY_GLASSES_PLAYS = "celesta_plays"

special("j_celesta_ray", "j_celesta_glassesjournal", {
    key = "ray_glasses",

    deal_weight = function(card)
        return (card.ability and card.ability[RAY_GLASSES_PLAYS]) or 0
    end,

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint) then return end
        for _, played in ipairs(context.full_hand or {}) do
            if played.ability then
                played.ability[RAY_GLASSES_PLAYS] =
                    (played.ability[RAY_GLASSES_PLAYS] or 0) + 1
            end
        end
    end,
})

--------------------------------------------------------------------------------
-- Kuro + Arielle
--------------------------------------------------------------------------------
--
-- Kuro alone shuts the Boss on odd Antes; bound to Arielle it shuts the even
-- ones instead. A replacing pair, like the rest, so the merged card is no
-- longer a Kuro and the odd Antes come back.
--
-- The hold itself is jokers/implemented.lua's, shared with Adfree, so the two
-- of them in one row cannot fight over the flag. What this adds is a rule to
-- the list that sync asks - which is why the rule is registered here rather
-- than the Joker file being taught that merges exist.

special("j_celesta_kuro", "j_celesta_arielle", {
    key = "kuro_arielle",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    -- The pair can form and break mid-round, so the Blind is asked again at
    -- both moments rather than waiting for the next one to be set. Unmerging
    -- is queued for the reason every count in this file is: it runs while the
    -- card is still in the row.
    on_merge = function(def, card, state)
        if CelestasMod.kuro_sync then CelestasMod.kuro_sync() end
    end,

    on_unmerge = function(def, card, state, losing)
        G.E_MANAGER:add_event(Event {
            func = function()
                if CelestasMod.kuro_sync then CelestasMod.kuro_sync() end
                return true
            end
        })
    end,

    calculate = function(def, card, context, state)
        if context.setting_blind and not context.blueprint then
            CelestasMod.kuro_sync()
        end
        if context.end_of_round and not context.blueprint then
            CelestasMod.hold_boss("kuro", false)
        end
    end,
})

-- ...and the rule the sync above asks about. A debuffed pair is not in the
-- row as far as specials_held is concerned, which is exactly right: a
-- debuffed Joker does nothing.
--
-- `or {}` rather than the `if CelestasMod.KURO_RULES then` this used to have.
-- That test was false on every single load - the list was declared in
-- jokers/implemented.lua, which is loaded AFTER this file - so the rule was
-- never registered and the pair did nothing in a real run. The suite missed it
-- because it builds its own CelestasMod with the list already there.
--
-- The list is declared in globals.lua now, which is loaded before everything.
-- This still says `or {}` so that the rule is registered whatever order the
-- files end up in, and whoever gets here second finds the same table - which
-- is the one thing a guard that skips can never do.
CelestasMod.KURO_RULES = CelestasMod.KURO_RULES or {}
CelestasMod.KURO_RULES[#CelestasMod.KURO_RULES + 1] = function()
    return specials_held("kuro_arielle")[1] ~= nil
        and CelestasMod.ante_parity_is(0)
end

--------------------------------------------------------------------------------
-- MoopyBuns' two
--------------------------------------------------------------------------------
--
-- MoopyBuns is paid by the shop; each partner decides what it is paid in.

-- MoopyBuns + BerryCrepe: BerryCrepe's Mult, banked per purchase instead of
-- per scored card.
--
-- `not context.blueprint` for the reason MoopyBuns' own carries it: the total
-- lives on this card's state, so a copier answering would bank the purchase a
-- second time.
special("j_celesta_moopybuns", "j_celesta_berrycrepe", {
    key = "moopy_berry",
    config = { mult = 0, mult_gain = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.mult_gain, state.mult } }
    end,

    calculate = function(def, card, context, state)
        -- context.buying_card is raised once for each thing bought - a Joker,
        -- a consumable, a voucher, a pack - which is what MoopyBuns counts.
        if context.buying_card and not context.blueprint then
            state.mult = state.mult + state.mult_gain
            return {
                message = localize { type = "variable", key = "a_mult",
                                     vars = { state.mult } },
                colour = G.C.MULT,
                card = card,
            }
        end

        if context.joker_main and state.mult > 0 then
            return { mult = state.mult }
        end
    end,
})

-- MoopyBuns + KokoNuts: KokoNuts is the 7s Joker, so the Chips come off the
-- 7s rather than off the shop.
--
-- Live-counted rather than banked, which is what "for each 7 in your full
-- deck" means and what Fufu's line of the same shape does: a deck that loses
-- its last 7 loses the Chips with it rather than leaving them banked.

--- How many cards in the run's deck are PRINTED as 7s.
---
--- The printed rank, the way count_suit_in_deck asks for the printed suit: a
--- deck-wide count is a question about what the deck is made of, not about
--- what a Joker is currently making each card count as. Rankless cards -
--- Stone, Limestone - are not 7s, and they still carry a base id underneath
--- the enhancement, so the enhancement has to be asked rather than the base.
local function sevens_in_deck()
    local count = 0
    for _, held in ipairs(G.playing_cards or {}) do
        if held.base and held.base.id == 7 and not SMODS.has_no_rank(held) then
            count = count + 1
        end
    end
    return count
end

--- X1 plus the gain per 7 the deck is printed with.
local function moopy_koko_x_chips(state)
    return 1 + state.x_chips_gain * sevens_in_deck()
end

special("j_celesta_moopybuns", "j_celesta_kokonuts", {
    key = "moopy_koko",
    config = { x_chips_gain = 0.4 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_chips_gain, moopy_koko_x_chips(state) } }
    end,

    calculate = function(def, card, context, state)
        if context.joker_main then
            local x_chips = moopy_koko_x_chips(state)
            -- X1 is no multiplier at all; returning it would put a flourish
            -- over the Joker every hand for doing nothing.
            if x_chips > 1 then return { x_chips = x_chips } end
        end
    end,
})

--------------------------------------------------------------------------------
-- Arielle + Saiiren
--------------------------------------------------------------------------------
--
-- Saiiren pays the last scoring card of one rotating suit, and Arielle makes
-- every card count as every suit - so together the suit stops mattering and
-- what is left is simply the last scoring card. The pair says that outright
-- rather than leaving it to be worked out from a smear, which also means it
-- holds whatever else is done to the suits.
--
-- The LAST entry of the scoring hand, tested the way ShyLily tests it - which
-- is Hanging Chad's own test against scoring_hand[1], anchored to the other
-- end. Unscored cards arrive with cardarea set to 'unscored' and never reach
-- this, so "scoring card" needs no test of its own.
special("j_celesta_arielle", "j_celesta_saiiren", {
    key = "arielle_saiiren",
    config = { x_mult = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local hand = context.scoring_hand
        if type(hand) ~= "table" or #hand == 0 then return end
        if context.other_card ~= hand[#hand] then return end
        return { x_mult = state.x_mult, card = card }
    end,
})

--------------------------------------------------------------------------------
-- HeavenlyFather + Arielle
--------------------------------------------------------------------------------
--
-- HeavenlyFather widens the shop and Arielle is the suits Joker, so the shop
-- widens by the suits.
--
-- The whole of it is the live pass above - BOOSTER_PAIRS names this key - so
-- there is nothing to hand over here and nothing to take back. A grant that is
-- a COUNT cannot be made once in add_to_deck: the deck it counts changes under
-- it, and a Tarot spent on the last Heart has to cost the slot back.
--
-- unique_suits_in_deck reads the PRINTED suit, so Arielle's own smear - every
-- card counting as every suit - does not inflate this. It would not anyway:
-- the pair replaces both halves, so the smear is not in play.
special("j_celesta_heavenlyfather", "j_celesta_arielle", {
    key = "heavenly_arielle",
    config = { per = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.per } }
    end,

    calculate = function(def, card, context, state) end,
})

--------------------------------------------------------------------------------
-- Aethal + Nyanners
--------------------------------------------------------------------------------
--
-- Aethal is the shop Joker and Nyanners pays Chips for each of something, so
-- the pair pays for what the shop has been spent on.
--
-- Counted live off the run rather than banked, which is what "redeemed this
-- run" means and what Nyanners' own line does with the Joker row: a Voucher
-- redeemed after the pair was made counts, because the question is about the
-- run rather than about the card.

--- How many Vouchers this run has redeemed.
---
--- G.GAME.used_vouchers is the run's own record, keyed by centre and set to
--- true as each one is redeemed (card.lua:2068) - which is also the table the
--- shop asks before offering one a second time. A Voucher handed over by a
--- deck or a challenge is written there too (back.lua:229), and those are
--- redeemed as much as any bought one.
local function vouchers_redeemed()
    local count = 0
    for _ in pairs((G.GAME and G.GAME.used_vouchers) or {}) do
        count = count + 1
    end
    return count
end

special("j_celesta_lordaethelstan", "j_celesta_nyanners", {
    key = "aethal_nyanners",
    config = { chips = 75 },

    loc_vars = function(def, card, state)
        return { vars = { state.chips,
                          CelestasMod.vedal_counted
                              and CelestasMod.vedal_counted(card, state.chips, vouchers_redeemed())
                              or state.chips * vouchers_redeemed() } }
    end,

    calculate = function(def, card, context, state)
        if context.joker_main then
            local redeemed = vouchers_redeemed()
            local total = CelestasMod.vedal_counted
                and CelestasMod.vedal_counted(card, state.chips, redeemed)
                or state.chips * redeemed
            -- No Vouchers is no Chips, and returning a zero would put a
            -- flourish over the Joker every hand for doing nothing.
            -- more_than, because an accelerated total is a Talisman number.
            if CelestasMod.more_than(total, 0) then
                return { chips = total }
            end
        end
    end,
})

--------------------------------------------------------------------------------
-- Grimmi
--------------------------------------------------------------------------------
--
-- Grimmi on its own reads a name off the run - the Joker sold BEFORE it - and
-- brings that back Negative. A pair does not need the record: the other half
-- is bound into the card, so what a merged Grimmi gives back when it is sold
-- is that half, and each of these three adds something of the half's own
-- while it is still in the row.

--- Grimmi's sale, aimed at a named Joker rather than at whatever was sold last.
---
--- Negative, so there is no room to check - it brings its own slot - and made
--- from an event for the reason Grimmi's own gives: the sale is an event too,
--- and this has to land behind it.
local function grimmi_returns(card, context, key)
    if not (context.selling_self and not context.blueprint) then return nil end
    if not (key and G.P_CENTERS and G.P_CENTERS[key]) then return nil end
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
end

-- Grimmi + HeavenlyFather: HeavenlyFather's shop, in Vouchers, and the man
-- himself back when the merge is sold.
--
-- The slots are a passive, declared the way HeavenlyFather + Nostro declares
-- its own: add_to_deck grants and remove_from_deck gives back, so selling the
-- merge, debuffing it and destroying it all go through vanilla's machinery.
-- on_merge covers the one moment vanilla cannot see - the pair coming into
-- existence on a card already in the row - and on_unmerge its mirror.
special("j_celesta_grimmi", "j_celesta_heavenlyfather", {
    key = "grimmi_heavenly",
    config = { vouchers = 5 },

    loc_vars = function(def, card, state)
        return { vars = { state.vouchers } }
    end,

    calculate = function(def, card, context, state)
        return grimmi_returns(card, context, "j_celesta_heavenlyfather")
    end,

    add_to_deck = function(def, card, state, from_debuff)
        SMODS.change_voucher_limit(state.vouchers)
    end,

    remove_from_deck = function(def, card, state, from_debuff)
        SMODS.change_voucher_limit(-state.vouchers)
    end,

    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
        def.add_to_deck(def, card, state, false)
    end,

    on_unmerge = function(def, card, state)
        def.remove_from_deck(def, card, state, false)
    end,
})

--- Stone cards in the run's deck.
---
--- G.playing_cards is the deck as a whole, wherever each card happens to be
--- sitting, which is what "in your full deck" means everywhere else in this
--- file. The enhancement is asked rather than the base, the way every other
--- deck-wide count here asks it.
local function stone_in_deck() return enhanced_in_deck("m_stone") end

-- Grimmi + Jowol: Jowol's Stone cards, counted across the whole deck rather
-- than only the ones in hand, and Jowol back when the merge is sold.
--
-- Live-counted rather than banked, which is what "in your full deck" means
-- and what MoopyBuns + KokoNuts does with its 7s: a deck that loses a Stone
-- card loses the Chips with it.
special("j_celesta_grimmi", "j_celesta_jowol", {
    key = "grimmi_jowol",
    config = { chips = 100 },

    loc_vars = function(def, card, state)
        return { vars = { state.chips, state.chips * stone_in_deck() } }
    end,

    calculate = function(def, card, context, state)
        local back = grimmi_returns(card, context, "j_celesta_jowol")
        if back then return back end

        if context.joker_main then
            local total = state.chips * stone_in_deck()
            -- A deck with no Stone card scores nothing rather than putting a
            -- "+0 Chips" over the Joker every hand.
            if total > 0 then return { chips = total } end
        end
    end,
})

--- The pair, so the sell-value hooks below can name it once.
local GRIMMI_EGGS = "grimmi_eggs"

--- What a pair adds to its card's sell value, in whole dollars.
---
--- Asked of the pair rather than written out here: a def declares `sell_extra`
--- and this finds it, so the two hooks below serve every pair that raises a
--- price instead of one. Grimmi + OverEzEggs derives its amount from the deck
--- and Yuy + Nekrolina banks its own; neither needs its own wrap.
---
--- A debuffed pair does nothing, and that includes this - the rule every
--- other passive in this file is held to.
---
--- Guarded: a pair that faults over a price must not stop the card being
--- priced at all.
local function bind_sell_extra(card)
    if not (card.ability and card.ability.set == "Joker" and not card.debuff) then
        return 0
    end
    local def = Bind.special_of(card)
    if not (def and type(def.sell_extra) == "function") then return 0 end

    local ok, amount = pcall(def.sell_extra, def, card,
                             Bind.special_state(card, def))
    if not ok then
        CelestasMod.warn_once("bind_sell_" .. tostring(def.key),
            ("Bind pair %s failed to price itself: %s")
                :format(tostring(def.key), tostring(amount)))
        return 0
    end
    return type(amount) == "number" and amount or 0
end

-- Grimmi + OverEzEggs: OverEzEggs fills the deck with Hearts, and this is paid
-- for every one of them - in what the merge is worth rather than in score.
--
-- Added to the ANSWER set_cost gives rather than written into
-- ability.extra_value, which is the mistake Ruben Sargasm was carrying: that
-- field sits one level down card.ability, exactly where Cryptid's misprintize
-- walks, and a derived total living there drifts away from the description
-- that recomputes it. Adding to the answer also cannot compound - a second
-- call recomputes from the card's base cost - and a pair that is unmerged,
-- debuffed or sold takes the raise with it without anything having to undo it.
special("j_celesta_grimmi", "j_celesta_overezeggs", {
    key = GRIMMI_EGGS,
    config = { per_heart = 0.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.per_heart } }
    end,

    -- Half a dollar a Heart, floored: the game deals in whole dollars and
    -- vanilla's own sell price is floored for that reason (card.lua:512). Two
    -- Hearts buy one dollar.
    sell_extra = function(def, card, state)
        return math.floor((state.per_heart or 0)
            * CelestasMod.count_suit_in_deck("Hearts"))
    end,

    calculate = function(def, card, context, state)
        return grimmi_returns(card, context, "j_celesta_overezeggs")
    end,
})

-- Both wraps below serve every pair that declares `sell_extra`, not only the
-- one above: what they add is whatever bind_sell_extra answers.
local celesta_grimmi_eggs_cost_ref = Card.set_cost
function Card:set_cost(...)
    local ret = celesta_grimmi_eggs_cost_ref(self, ...)
    local extra = bind_sell_extra(self)
    if extra > 0 and type(self.sell_cost) == "number" then
        self.sell_cost = self.sell_cost + extra
        self.sell_cost_label = self.facing == "back" and "?" or self.sell_cost
    end
    return ret
end

--- What each Joker was last priced against, so set_cost is called when the
--- answer changes rather than on every frame.
---
--- The AMOUNT rather than the Heart count, so forming the pair, losing it,
--- being debuffed and the deck changing are all the one question. Weak-keyed:
--- a sold Joker should not be kept alive by this.
local grimmi_eggs_priced = setmetatable({}, { __mode = "k" })

-- Nothing calls set_cost when the deck changes, so the price would sit stale
-- until something else happened to the card. Card:update is where vanilla
-- solves the same problem for Temperance, and where Ruben Sargasm asks it.
local celesta_grimmi_eggs_update_ref = Card.update
function Card:update(dt)
    celesta_grimmi_eggs_update_ref(self, dt)

    if self.ability and self.ability.set == "Joker" then
        local want = bind_sell_extra(self)
        if grimmi_eggs_priced[self] ~= want then
            grimmi_eggs_priced[self] = want
            if type(self.set_cost) == "function" then self:set_cost() end
        end
    end
end

--------------------------------------------------------------------------------
-- Cy Yu
--------------------------------------------------------------------------------
--
-- Cy Yu retriggers Exo cards in the played hand. Both of its pairs are that
-- retrigger pointed somewhere else: AmaLee's weather decides when it happens,
-- and Jowol's Stone cards replace Exo as what it happens to.
--
-- Neither brings its own weather. Aquwa + Megalodon is the same shape - a pair
-- whose other half makes the weather, worth more while it is up and saying
-- nothing about starting one - and the two pairs that DO open with weather say
-- so on the card.

--- True while a Snowstorm is up.
local function snowing()
    local Arena = CelestasMod.Arena
    return (Arena and Arena.is_active and Arena.is_active("snowstorm")) and true or false
end

-- Cy Yu + AmaLee: Cy Yu's own retrigger, more of it, and only in AmaLee's
-- weather.
special("j_celesta_cyyuvtuber", "j_celesta_amalee", {
    key = "cyyu_amalee",
    config = { repetitions = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if not snowing() then return end
        local exo = CelestasMod.ENHANCEMENT_KEYS and CelestasMod.ENHANCEMENT_KEYS.Exo
        if not (exo and SMODS.has_enhancement(context.other_card, exo)) then return end
        return {
            message = localize("k_again_ex"),
            repetitions = state.repetitions,
            card = card,
        }
    end,
})

-- Cy Yu + Jowol: Cy Yu's retrigger, aimed at Jowol's Stone cards instead of
-- its own Exo ones.
special("j_celesta_cyyuvtuber", "j_celesta_jowol", {
    key = "cyyu_jowol",
    config = { repetitions = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if not SMODS.has_enhancement(context.other_card, "m_stone") then return end
        return {
            message = localize("k_again_ex"),
            repetitions = state.repetitions,
            card = card,
        }
    end,
})


--------------------------------------------------------------------------------
-- Yoclesh + Squchan, and Fenari + HeavenlyFather
--------------------------------------------------------------------------------

-- Yoclesh + Squchan: Squchan deals in Holographic Jokers and Yoclesh in
-- Hearts, so the Holo goes onto the Hearts instead.
--
-- Rolled as each card scores and written onto it there, which is
-- CottontailVA + FeFe's shape for the same thing in seals. A card that already
-- has an edition is left alone - this gives one, it does not trade one away -
-- and that test is what stops the same card being re-rolled every hand.
special("j_celesta_yoclesh", "j_celesta_squchan", {
    key = "yoclesh_squchan",
    config = { odds = 2 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_yoclesh_squchan")
        return { vars = { n, d } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and context.other_card) then return end
        local other = context.other_card
        if other.edition then return end
        if not (other.is_suit and other:is_suit("Hearts")) then return end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_yoclesh_squchan",
                1, state.odds, "celesta_bind_yoclesh_squchan") then return end
        other:set_edition({ holo = true }, true)
        return { message = localize("k_upgrade_ex"),
                 colour = G.C.DARK_EDITION, card = card }
    end,
})

--- The pair, so the create_card hook below can name it once.
local FENARI_HEAVENLY = "fenari_heavenly"

-- Fenari + HeavenlyFather: Fenari peels stickers off one Joker a round;
-- HeavenlyFather is the booster pack. Together the packs stop handing them out
-- in the first place.
special("j_celesta_fenari", "j_celesta_heavenlyfather", {
    key = FENARI_HEAVENLY,

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state) end,
})

--- Takes every sticker off a card.
---
--- Fenari's own peel, all of them at once: read through CelestasMod.stickers_on
--- so a sticker another mod adds goes too, and perish_tally cleared with the
--- flag, because Perishable keeps a countdown beside it that would debuff the
--- Joker on its own later.
local function strip_stickers(target)
    local worn = CelestasMod.stickers_on(target)
    for _, sticker in ipairs(worn) do
        target.ability[sticker] = nil
        if sticker == "perishable" then target.ability.perish_tally = nil end
    end
    return #worn > 0
end

-- create_card is where a pack's Jokers are given their stickers - the
-- SMODS.Sticker loop at common_events.lua:2467, and vanilla's own Eternal,
-- Perishable and Rental rolls immediately below it - so it is where they can
-- be refused. Taken off after the fact rather than each roll being blocked:
-- those are four separate places and one of them is a loop over every sticker
-- any mod has registered, and this covers all of it in one line.
local celesta_fenari_heavenly_create_ref = create_card
function create_card(_type, area, ...)
    local made = celesta_fenari_heavenly_create_ref(_type, area, ...)
    if made and area == G.pack_cards
        and made.ability and made.ability.set == "Joker" then
        local holder = Bind.find_special(FENARI_HEAVENLY)
        if holder and not holder.debuff then strip_stickers(made) end
    end
    return made
end

--------------------------------------------------------------------------------
-- ObKatieKat
--------------------------------------------------------------------------------
--
-- ObKatieKat is the ^Chips Joker, and every one of these is the other half's
-- own payout made in ^Chips instead. None of them keeps ObKatieKat's own
-- condition - a full Joker row - because each pair has a condition of its own
-- and asking for both would leave most of them unreachable.
--
-- All eight need Talisman, which is what scores a ^ at all. Checked at score
-- time rather than at load for the reason Vienna gives: mods load in priority
-- order, and Talisman may not have run when this file did.

--- Wild Cards in the run's deck, counted the way Froot counts them.
local function wilds_in_deck() return enhanced_in_deck("m_wild") end

-- ObKatieKat + Froot: Froot's reading of the deck, in ^Chips.
--
-- Live off the deck rather than banked, which is what Froot's own line means
-- and what every other "for each card in your full deck" here does: a card
-- that stops being Wild takes its share with it.
special("j_celesta_obkatiekat", "j_celesta_froot", {
    key = "katie_froot",
    config = { e_chips_gain = 0.04 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_chips_gain,
                          1 + state.e_chips_gain * wilds_in_deck() } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local e_chips = 1 + state.e_chips_gain * wilds_in_deck()
        if e_chips <= 1 then return end
        if not power_supported("katie_froot_no_talisman",
                               "ObKatieKat + Froot", "Chips") then
            return
        end
        return { e_chips = e_chips }
    end,
})

-- ObKatieKat + Saiiren: Saiiren's rotating suit, paid in ^Chips.
--
-- The rotation is Saiiren's own, walked on the pair's index through the
-- helpers jokers/implemented.lua exports - so a Yoclesh pins this to Hearts
-- exactly as it pins Saiiren, and the two cannot come to disagree about which
-- suit the round is on.
special("j_celesta_obkatiekat", "j_celesta_saiiren", {
    key = "katie_saiiren",
    config = { e_chips = 1.15, suit_index = 1 },

    loc_vars = function(def, card, state)
        local suits = CelestasMod.rotation_suits()
        local suit = CelestasMod.rotation_suit_at(suits, state.suit_index)
        -- Singular, because the name qualifies "card" - Saiiren's own reason.
        return { vars = { state.e_chips, localize(suit, "suits_singular"),
                          colours = { G.C.SUITS[suit] } } }
    end,

    calculate = function(def, card, context, state)
        local suits = CelestasMod.rotation_suits()
        local suit = CelestasMod.rotation_suit_at(suits, state.suit_index)

        if context.individual and context.cardarea == G.play then
            if context.other_card ~= CelestasMod.saiiren_target(context, suit) then
                return
            end
            if not power_supported("katie_saiiren_no_talisman",
                                   "ObKatieKat + Saiiren", "Chips") then
                return
            end
            return { e_chips = state.e_chips, card = context.other_card }
        end

        -- main_eval keeps the rotation to once per round rather than once per
        -- card the end-of-round pass looks at.
        if context.end_of_round and context.main_eval and not context.blueprint then
            state.suit_index = CelestasMod.rotation_index(state.suit_index + 1, #suits)
            local next_suit = CelestasMod.rotation_suit_at(suits, state.suit_index)
            return { message = localize(next_suit, "suits_singular"),
                     colour = G.C.SUITS[next_suit], card = card }
        end
    end,
})

--- The pair, so the Steel hook below can name it once.
local KATIE_ZENTREYA = "katie_zentreya"

-- ObKatieKat + Zentreya: Zentreya's Steel Cards, paid in ^Chips instead of
-- Mult - and instead of the X1.5 the Steel Card itself gives.
--
-- Both passes, because a Steel Card triggers in either: G.play is Zentreya's
-- own half, and G.hand is where the enhancement's X1.5 lives and so where the
-- trade actually happens.
special("j_celesta_obkatiekat", "j_celesta_zentreya", {
    key = KATIE_ZENTREYA,
    config = { e_chips = 1.15 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_chips } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.other_card
                and (context.cardarea == G.play or context.cardarea == G.hand)) then
            return
        end
        if not SMODS.has_enhancement(context.other_card, "m_steel") then return end
        if not power_supported("katie_zentreya_no_talisman",
                               "ObKatieKat + Zentreya", "Chips") then
            return
        end
        return { e_chips = state.e_chips, card = context.other_card }
    end,
})

-- The Steel Card's own X1.5 is not a Joker effect and cannot be replaced by
-- returning something else: the game reads it straight off the card, in
-- eval_card (common_events.lua:721) through Card:get_chip_h_x_mult. Answering
-- nothing there is the one place it can be refused, and it leaves every other
-- card - and every Steel Card in a run without this pair - untouched.
local celesta_katie_zentreya_hxm_ref = Card.get_chip_h_x_mult
function Card:get_chip_h_x_mult(...)
    if SMODS.has_enhancement(self, "m_steel") then
        local holder = Bind.find_special(KATIE_ZENTREYA)
        if holder and not holder.debuff then return 0 end
    end
    return celesta_katie_zentreya_hxm_ref(self, ...)
end

-- ObKatieKat + Ironmouse: the two exponents, in ObKatieKat's half of the
-- score. Ironmouse's own rate, and no condition on either half left.
special("j_celesta_obkatiekat", "j_celesta_ironmouse", {
    key = "katie_ironmouse",
    config = { e_chips = 1.3 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_chips } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        if not power_supported("katie_ironmouse_no_talisman",
                               "ObKatieKat + Ironmouse", "Chips") then
            return
        end
        return { e_chips = state.e_chips }
    end,
})

-- ObKatieKat + Michi: Michi's Purple Seals, paid when they score rather than
-- when they are discarded.
special("j_celesta_obkatiekat", "j_celesta_michi", {
    key = "katie_michi",
    config = { e_chips = 1.15 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_chips } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and context.other_card) then return end
        if context.other_card.seal ~= "Purple" then return end
        if not power_supported("katie_michi_no_talisman",
                               "ObKatieKat + Michi", "Chips") then
            return
        end
        return { e_chips = state.e_chips, card = context.other_card }
    end,
})

-- ObKatieKat + Kuro: Kuro is the Boss Blind Joker, so the Boss is what pays.
--
-- Kuro's own hold is gone with the rest of it - a replacing pair speaks for
-- both halves, so neither is in play as itself and CelestasMod.kuro_sync stops
-- finding one. That is what makes this reachable at all: a Boss Kuro had shut
-- is not a Boss to be paid for.
--
-- joker_main is the "after the hand has finished scoring" slot, which is where
-- Jowol and every other Joker in this mod scores after the cards do.
special("j_celesta_obkatiekat", "j_celesta_kuro", {
    key = "katie_kuro",
    config = { e_chips = 1.25 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_chips } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local blind = G.GAME and G.GAME.blind
        if not (blind and blind.boss) then return end
        if not power_supported("katie_kuro_no_talisman",
                               "ObKatieKat + Kuro", "Chips") then
            return
        end
        return { e_chips = state.e_chips }
    end,
})

-- ObKatieKat + Henya: Henya pays for retriggers; this pays for them in ^Chips.
--
-- The scoring pass only, which is narrower than Henya alone - it pays a
-- retrigger of a card held in hand too - and is what "scored cards" means.
-- The count itself is Henya's, read through CelestasMod.trigger_count, so the
-- two cannot come to disagree about what a retrigger is.
special("j_celesta_obkatiekat", "j_celesta_henya", {
    key = "katie_henya",
    config = { e_chips = 1.15 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_chips } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and context.other_card and not context.end_of_round) then return end
        if CelestasMod.trigger_count(context.other_card) <= 1 then return end
        if not power_supported("katie_henya_no_talisman",
                               "ObKatieKat + Henya", "Chips") then
            return
        end
        return { e_chips = state.e_chips, card = context.other_card }
    end,
})

-- ObKatieKat + Projekt Melody: ObKatieKat counts the Joker row and Projekt
-- Melody pays at the cash-out, so the row is what it pays for.
--
-- Through calc_dollar_bonus, which is the hook Projekt Melody's own money
-- comes through and where it gets its own line on the cash-out screen rather
-- than arriving as a floating message.
special("j_celesta_obkatiekat", "j_celesta_projektmelody", {
    key = "katie_melody",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars,
                          state.dollars * #(((G.jokers or {}).cards) or {}) } }
    end,

    calc_dollar_bonus = function(def, card, state)
        local filled = #(((G.jokers or {}).cards) or {})
        if filled <= 0 then return end
        return filled * state.dollars
    end,

    calculate = function(def, card, context, state) end,
})

--------------------------------------------------------------------------------
-- Smitten Seraph
--------------------------------------------------------------------------------

--- Filled Joker slots less filled consumable slots, never below nothing.
---
--- What is FILLED rather than what the limits are, which is what the pair
--- says: a row of five with an empty tray is five, and filling the tray spends
--- it back. Negative is nothing - a retrigger count below zero is not a thing
--- the scoring pass can be handed.
local function seraph_gap()
    local jokers = #(((G.jokers or {}).cards) or {})
    local consumables = #(((G.consumeables or {}).cards) or {})
    local gap = jokers - consumables
    return gap > 0 and gap or 0
end

-- Maple Chicken + Smitten Seraph: Maple Chicken's Leaf retrigger, counted off
-- the two rows Smitten Seraph makes room in.
--
-- The played hand only, which is what the pair says - Maple Chicken alone also
-- retriggers a Leaf held in hand.
special("j_celesta_maplechicken", "j_celesta_smittenseraph", {
    key = "maple_seraph",

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR, true)
        return { vars = { name, seraph_gap(), colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        local other = context.other_card
        if not (other.is_suit and other:is_suit(CelestasMod.LEAF_SUIT)) then return end
        local times = seraph_gap()
        if times <= 0 then return end
        return {
            message = localize("k_again_ex"),
            repetitions = times,
            card = card,
        }
    end,
})

-- Birdyovo + Smitten Seraph: Smitten Seraph's slots, more of them, and
-- Birdyovo's count coming round faster.
--
-- The slots are a passive, declared the way HeavenlyFather + Nostro declares
-- its own - add_to_deck grants, remove_from_deck gives back, on_merge and
-- on_unmerge cover the one moment vanilla cannot see - and they go through
-- CelestasMod.bump_limit, which is the Joker's own way of moving a card_limit
-- that Steamodded may be keeping behind a metatable.
special("j_celesta_birdyovo", "j_celesta_smittenseraph", {
    key = "birdyovo_seraph",
    config = { joker_slots = 4, consumable_slots = 2,
               x_mult = 2, requirement = 5, count = 0 },

    loc_vars = function(def, card, state)
        local to_go = state.requirement - (state.count % state.requirement)
        return { vars = { state.joker_slots, state.consumable_slots,
                          state.requirement, state.x_mult, to_go } }
    end,

    calculate = function(def, card, context, state)
        -- Birdyovo's own count, carried across hands and rounds: the fifth
        -- card is the fifth the pair has ever seen.
        if context.individual and context.cardarea == G.play then
            -- A copy must not advance the count - the cards were scored once -
            -- but it still pays on a card that lands on the fifth, so a
            -- Blueprint doubles the payoff rather than shifting the rhythm.
            if not context.blueprint then state.count = state.count + 1 end
            if state.count % state.requirement == 0 then
                return { x_mult = state.x_mult, card = card }
            end
        end
    end,

    add_to_deck = function(def, card, state, from_debuff)
        CelestasMod.bump_limit(G.jokers, state.joker_slots)
        CelestasMod.bump_limit(G.consumeables, state.consumable_slots)
    end,

    remove_from_deck = function(def, card, state, from_debuff)
        CelestasMod.bump_limit(G.jokers, -state.joker_slots)
        CelestasMod.bump_limit(G.consumeables, -state.consumable_slots)
    end,

    on_merge = function(def, card, state, fresh)
        -- A card born merged has not entered the deck, so there is nothing to
        -- catch up: Card:add_to_deck reaches this def's add_to_deck when the
        -- card arrives. See Bind.merge's `fresh`.
        if fresh then return end
        def.add_to_deck(def, card, state, false)
    end,

    on_unmerge = function(def, card, state)
        def.remove_from_deck(def, card, state, false)
    end,
})


--------------------------------------------------------------------------------
-- Mint Fantome
--------------------------------------------------------------------------------
--
-- Mint Fantome scores the leftmost card held in hand once the played hand has
-- finished scoring, and its timing is the whole of it: context.after reads like
-- the obvious hook and is too late, because vanilla commits the score at
-- state_events.lua:1031 and fires `after` at :1070. The held-in-hand pass
-- (:798) is the first thing to run after every played card is done and the last
-- thing that still counts. All three of the pairs below answer that same pass.

--- Set while a held card is being scored by one of these, so the pass cannot
--- re-enter. Mint Fantome keeps its own flag for the same reason.
local mint_scoring = false

--- The leftmost card held in hand, when `other` is it and it can score.
local function mint_leftmost(context, other)
    if context.end_of_round or mint_scoring then return nil end
    local target = G.hand and G.hand.cards and G.hand.cards[1]
    if not target or other ~= target then return nil end
    -- A debuffed card scores nothing, the same as in the played hand.
    if target.debuff then return nil end
    return target
end

--- Scores a held card as though it had been played, the way Mint Fantome does.
---
--- A FRESH context, not the live one: SMODS.score_card sets main_scoring,
--- individual and other_card as it goes, and clobbering the table the caller is
--- still iterating would corrupt the rest of the held pass. cardarea = G.play
--- is what makes this scoring rather than another held trigger, so every Joker
--- watching for a scored card sees it and the card contributes its chips, its
--- enhancement, its edition and its seal exactly as a played card would.
local function mint_score(target, context, id)
    mint_scoring = true
    local ok, err = pcall(SMODS.score_card, target, {
        cardarea = G.play,
        full_hand = context.full_hand,
        scoring_hand = context.scoring_hand,
        scoring_name = context.scoring_name,
        poker_hands = context.poker_hands,
    })
    mint_scoring = false
    if not ok then
        CelestasMod.warn_once(id,
            "A Mint Fantome merge could not score a held card: " .. tostring(err))
    end
    return ok
end

-- Mint Fantome + Matara Kan: Matara Kan deals in money, so the leftmost held
-- card pays rather than scores.
--
-- Half its RANK, read through rank_value - the card's chip value, so an Ace is
-- 11 and a face is 10, which is what a rank means everywhere else in this file.
-- Floored, because the game deals in whole dollars.
special("j_celesta_mintfantome", "j_celesta_matarakan", {
    key = "mint_matara",
    config = { share = 0.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.share } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.hand
                and context.other_card) then return end
        local target = mint_leftmost(context, context.other_card)
        if not target then return end
        local owed = math.floor(rank_value(target) * state.share)
        if owed <= 0 then return end
        return { dollars = owed, card = card }
    end,
})

-- Mint Fantome + Laimu: Laimu fills the deck with Limestone, so every Limestone
-- card held in hand is scored rather than only the leftmost card.
--
-- Each held card gets its own turn in this pass, so answering for every
-- Limestone one scores every Limestone one - and the leftmost card is no longer
-- special unless it happens to be Limestone too.
special("j_celesta_mintfantome", "j_celesta_limealicious", {
    key = "mint_laimu",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.hand
                and context.other_card and not context.end_of_round
                and not mint_scoring) then return end
        local key = CelestasMod.ENHANCEMENT_KEYS
            and CelestasMod.ENHANCEMENT_KEYS.Limestone
        if not key then return end
        local target = context.other_card
        if target.debuff then return end
        if not SMODS.has_enhancement(target, key) then return end
        mint_score(target, context, "mint_laimu_score")
    end,
})

-- Mint Fantome + Dokibird: Dokibird deals in what a card has stored, so the
-- leftmost held card is scored for several times its own Chips.
--
-- The multiplier is lent to the CARD for the length of the scoring and taken
-- off again, rather than the Chips being returned separately: the card really
-- scores, so its seal, its edition and every Joker watching a scored card all
-- see the bigger number, which is what "score it for X5 its stored Chips"
-- means and a loose `chips` return would not.
--
-- perma_bonus is where a Chip bonus that outlives the hand lives, and where
-- Dokibird itself writes. get_chip_bonus adds it whichever kind of card this
-- is (card.lua:1172), so a Stone card held in hand is multiplied the same way
-- as any other.
special("j_celesta_mintfantome", "j_celesta_dokibird", {
    key = "mint_doki",
    config = { rate = 5 },

    loc_vars = function(def, card, state)
        return { vars = { state.rate } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.hand
                and context.other_card) then return end
        local target = mint_leftmost(context, context.other_card)
        if not target then return end

        local stored = target.get_chip_bonus and target:get_chip_bonus() or 0
        local lent = stored > 0 and stored * (state.rate - 1) or 0
        local was = target.ability.perma_bonus or 0
        target.ability.perma_bonus = was + lent
        -- mint_score never raises - it pcalls - so the loan is always repaid.
        mint_score(target, context, "mint_doki_score")
        target.ability.perma_bonus = was
    end,
})

-- Mint Fantome + Snuffy: Snuffy's extra picks, and one more.
--
-- The limit itself is granted by the live pass further up - SELECTION_PAIRS
-- names this key - because the number moves WITHIN a round as Hands are spent,
-- which an add_to_deck could not follow.
special("j_celesta_mintfantome", "j_celesta_snuffy", {
    key = "mint_snuffy",
    config = { extra = 1 },

    loc_vars = function(def, card, state)
        local round = G.GAME and G.GAME.current_round
        return { vars = { ((round and round.hands_left) or 0) + state.extra,
                          state.extra } }
    end,

    calculate = function(def, card, context, state) end,
})

--------------------------------------------------------------------------------
-- Laimu
--------------------------------------------------------------------------------

--- The pair, so the enhancement hook below can name it once.
local LAIMU_DOKI = "laimu_doki"

--- What a weathered card also counts as while that pair is in the row.
---
--- Polish makes Sandstone out of a Stone Card and Scoria out of a Limestone one
--- (enhancements/enhancements.lua), so this is the weathering read backwards:
--- each counts as the card it was made from.
---
--- Asked rather than held in a table built at load, because it is only two
--- questions and neither is worth a table that could go stale.
local function weathered_from(key)
    local keys = CelestasMod.ENHANCEMENT_KEYS
    if not keys then return nil end
    if key == keys.Limestone then return keys.Scoria end
    if key == "m_stone" then return keys.Sandstone end
    return nil
end

-- Laimu + Dokibird: the weathering undone, for the purpose of counting.
--
-- Answered at SMODS.has_enhancement, which is the one place the game and this
-- mod ask whether a card IS something - the same reasoning Mellow Mabel's
-- SMODS.smeared_check hook rests on. One hook covers every Joker, every
-- enhancement gate and every deck count at once, rather than each of them
-- having to be taught the rule.
--
-- It changes only what COUNTS as what. A Scoria card still scores Scoria's own
-- ^Mult; it is simply a Limestone card as well, for as long as this is out.
special("j_celesta_limealicious", "j_celesta_dokibird", {
    key = LAIMU_DOKI,

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state) end,
})

local celesta_laimu_doki_enh_ref = SMODS.has_enhancement
function SMODS.has_enhancement(card, key, ...)
    if celesta_laimu_doki_enh_ref(card, key, ...) then return true end
    -- Cheapest test first: this is asked of every card in every hand, and
    -- almost every question is about a key the pair has nothing to say about.
    local weathered = weathered_from(key)
    if not weathered then return false end
    local holder = Bind.find_special(LAIMU_DOKI)
    if not (holder and not holder.debuff) then return false end
    return celesta_laimu_doki_enh_ref(card, weathered, ...) and true or false
end

--- The pair, so the selection hook below can name it once.
local LAIMU_SNUFFY = "laimu_snuffy"

-- Laimu + Snuffy: Snuffy widens what can be selected; here Limestone cards are
-- outside the count altogether.
--
-- The limit is enforced in CardArea:add_to_highlighted (cardarea.lua:172),
-- which refuses the card outright once the hand is full. Rather than
-- reimplementing that branch - it also plays the sound and re-parses the
-- selection - the limit is lifted by one for the length of the call, so
-- vanilla's own code does the work and the card goes in.
special("j_celesta_limealicious", "j_celesta_snuffy", {
    key = LAIMU_SNUFFY,

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state) end,
})

local celesta_laimu_snuffy_highlight_ref = CardArea.add_to_highlighted
function CardArea:add_to_highlighted(card, silent)
    local key = CelestasMod.ENHANCEMENT_KEYS
        and CelestasMod.ENHANCEMENT_KEYS.Limestone
    local free = self == G.hand and card and key
        and SMODS.has_enhancement(card, key)
        and Bind.find_special(LAIMU_SNUFFY) or nil
    if not free or free.debuff then
        return celesta_laimu_snuffy_highlight_ref(self, card, silent)
    end

    local saved = self.config.highlighted_limit
    self.config.highlighted_limit = #self.highlighted + 1
    local ok, err = pcall(celesta_laimu_snuffy_highlight_ref, self, card, silent)
    self.config.highlighted_limit = saved
    if not ok then error(err, 0) end
end

--------------------------------------------------------------------------------
-- Dokibird + Snuffy
--------------------------------------------------------------------------------
--
-- Dokibird's harvest, over the wider hand Snuffy makes it possible to play.
-- Every played card under the cap goes, not only the unscoring ones, and what
-- survives is the LEFTMOST card played rather than the one that scored - so
-- there is no "exactly one card scores" to arrange any more, only a hand to
-- order.
--
-- context.destroy_card is raised once for every card in the played hand,
-- scoring and unscoring alike (SMODS utils.lua:2061), which is why this does
-- not narrow by cardarea the way Dokibird alone does. Saying `remove` is what
-- destroys the card, and it buys the animation, the removal from the deck and
-- the remove_playing_cards pass other Jokers watch, all for free.
--
-- The cap and the rate are written out rather than read from
-- CelestasMod.DOKIBIRD_CAP: this file is loaded before jokers/implemented.lua,
-- so those constants do not exist yet. test_specials.py reads both back out of
-- the two files and fails if they ever disagree.
special("j_celesta_dokibird", "j_celesta_snuffy", {
    key = "doki_snuffy",
    config = { cap = 100, rate = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.cap, state.rate } }
    end,

    calculate = function(def, card, context, state)
        if not (context.destroy_card and not context.blueprint
                and not context.retrigger_joker) then return end
        local hand = context.full_hand
        local target = hand and hand[1]
        if not target then return end

        local doomed = context.destroy_card
        -- The leftmost card is the one kept, and the one paid.
        if doomed == target then return end

        local stored = doomed.get_chip_bonus and doomed:get_chip_bonus() or 0
        -- Nothing to take is not a card to destroy, and the cap is what the
        -- card advertises: a big card is left where it is.
        if stored <= 0 or stored >= state.cap then return end

        local gain = stored * state.rate
        target.ability.perma_bonus = (target.ability.perma_bonus or 0) + gain

        return {
            remove = true,
            message = localize { type = "variable", key = "a_chips",
                                 vars = { gain } },
            colour = G.C.CHIPS,
            card = target,
        }
    end,
})


--------------------------------------------------------------------------------
-- Mint Fantome, Nimi, Dooby and Dokibird
--------------------------------------------------------------------------------
--
-- Four Jokers about the two things a run can be denied: a debuff, and a shop
-- that took no money. Every pair between them is registered, so the quad at
-- the end of this section is reachable by merging any two of them.

--- True when this shop took no money, which is Dooby's whole question.
local function shop_was_quiet()
    return CelestasMod.shop_had_spending
        and not CelestasMod.shop_had_spending()
end

-- Mint Fantome + Nimi: Nimi lifts a debuff, Mint Fantome scores the leftmost
-- card held in hand - so the card is freed first and then scored.
--
-- The lift lands in context.before, which is raised when the hand is played
-- and before anything scores, so the card is undebuffed for the whole hand
-- rather than only for the moment it is scored. Mint Fantome's own pass then
-- finds an ordinary card where it would have found a debuffed one and refused.
special("j_celesta_mintfantome", "j_celesta_nimi", {
    key = "mint_nimi",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if context.before and not context.blueprint then
            local target = G.hand and G.hand.cards and G.hand.cards[1]
            if not (target and target.debuff) then return end
            target:set_debuff(false)
            return { message = localize("celesta_undebuffed"),
                     colour = G.C.FILTER, card = card }
        end

        if not (context.individual and context.cardarea == G.hand
                and context.other_card) then return end
        local target = mint_leftmost(context, context.other_card)
        if not target then return end
        mint_score(target, context, "mint_nimi_score")
    end,
})

-- Mint Fantome + Dooby: Dooby counts the shops nothing was spent in, and each
-- one is another trigger of the leftmost card held in hand.
--
-- Banked at ending_shop, which is Dooby's own moment: the shop is over and
-- whether anything was bought in it is settled. The count only ever goes up,
-- which is what makes a run of quiet shops worth having.
special("j_celesta_mintfantome", "j_celesta_dooby", {
    key = "mint_dooby",
    config = { quiet = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.quiet } }
    end,

    calculate = function(def, card, context, state)
        if context.ending_shop and not context.blueprint then
            if not shop_was_quiet() then return end
            state.quiet = (state.quiet or 0) + 1
            return { message = localize("celesta_quiet_shop"),
                     colour = G.C.MONEY, card = card }
        end

        if not (context.individual and context.cardarea == G.hand
                and context.other_card) then return end
        if (state.quiet or 0) <= 0 then return end
        local target = mint_leftmost(context, context.other_card)
        if not target then return end
        for _ = 1, state.quiet do
            mint_score(target, context, "mint_dooby_score")
        end
    end,
})

-- Dooby + Dokibird: Dooby's quiet shop, banked in Dokibird's Chips.
special("j_celesta_dooby", "j_celesta_dokibird", {
    key = "dooby_doki",
    config = { chips = 0, chip_gain = 100 },

    loc_vars = function(def, card, state)
        return { vars = { state.chip_gain, state.chips } }
    end,

    calculate = function(def, card, context, state)
        if context.ending_shop and not context.blueprint then
            if not shop_was_quiet() then return end
            state.chips = state.chips + state.chip_gain
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

--- The pair, so the debuff hook below can name it once.
local NIMI_DOKI = "nimi_doki"

-- Nimi + Dokibird: a card with enough stored Chips is simply beyond the Blind.
--
-- Fleshy's shape rather than Nimi's: answered BEFORE the ref, so the card is
-- never debuffed at all rather than debuffed and freed. That is what "cannot
-- be debuffed" says, and it is also why there is no meter here - nothing is
-- being spent.
--
-- "Stored Chips" is get_chip_bonus, the reading Dokibird's own line is written
-- in: the card's rank, its enhancement's bonus and any permanent bonus on top.
special("j_celesta_nimi", "j_celesta_dokibird", {
    key = NIMI_DOKI,
    config = { chips = 50 },

    loc_vars = function(def, card, state)
        return { vars = { state.chips } }
    end,

    calculate = function(def, card, context, state) end,
})

local celesta_nimi_doki_debuff_ref = Blind and Blind.debuff_card
if celesta_nimi_doki_debuff_ref then
    function Blind:debuff_card(card, from_blind)
        local holder, def = Bind.find_special(NIMI_DOKI)
        if holder and not holder.debuff and card and card.get_chip_bonus then
            local stored = card:get_chip_bonus() or 0
            if stored > Bind.special_state(holder, def).chips then
                -- The same line vanilla ends on for a card its Blind does not
                -- want (blind.lua:721), which also lifts one already applied.
                card:set_debuff(false)
                return
            end
        end
        return celesta_nimi_doki_debuff_ref(self, card, from_blind)
    end
end

-- Dooby + Nimi: a Stamp can be taken out of the pack and kept.
--
-- No calculate at all. A Stamp is normally used out of the pack onto a Joker
-- there and then; what this changes is whether the pack offers to put one in
-- the consumable tray instead, which is Steamodded's `select_card` on the
-- consumable TYPE. That lives in stamps/stamps.lua, which owns the type and is
-- loaded after this file - it asks for this pair by name.
special("j_celesta_dooby", "j_celesta_nimi", {
    key = "dooby_nimi",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state) end,
})

--- The quad, so the debuff hook below can name it once.
CelestasMod.GAY_WOMEN_KEY = "quad_gay_women"

-- G.A.Y. Women: the four of them, and no debuff sticks to anything.
--
-- Nimi's rule with the meter taken off and a payout put on. The hook is the
-- same one - Blind:debuff_card, where every rule a Boss has ends - and so is
-- the per-card-per-round mark, for the same reason: every set_ability and
-- set_base re-judges the card it touches, so a count kept per judgement would
-- run away on a single hand.
--
-- Jokers as well as playing cards, which is what the group says and what the
-- funnel hands over anyway: a Blind that debuffs the row goes through here
-- card by card.
quad({
    key = CelestasMod.GAY_WOMEN_KEY,
    members = { "j_celesta_mintfantome", "j_celesta_nimi",
                "j_celesta_dooby", "j_celesta_dokibird" },
    config = { chips = 0, chip_gain = 100 },

    loc_vars = function(def, card, state)
        return { vars = { state.chip_gain, state.chips } }
    end,

    calculate = function(def, card, context, state)
        if context.joker_main and state.chips > 0 then
            return { chips = state.chips }
        end
    end,
})

local celesta_gay_women_debuff_ref = Blind and Blind.debuff_card
if celesta_gay_women_debuff_ref then
    function Blind:debuff_card(card, from_blind)
        local ret = celesta_gay_women_debuff_ref(self, card, from_blind)
        if not (card and card.debuff and card.debuffed_by_blind) then return ret end

        local holder, def = Bind.find_special(CelestasMod.GAY_WOMEN_KEY)
        if not (holder and not holder.debuff) then return ret end

        card:set_debuff(false)

        local round = (G.GAME and G.GAME.round) or 0
        if card.celesta_gay_freed == round then return ret end
        card.celesta_gay_freed = round

        local state = Bind.special_state(holder, def)
        state.chips = state.chips + state.chip_gain
        card_eval_status_text(holder, "extra", nil, nil, nil,
            { message = localize { type = "variable", key = "a_chips",
                                   vars = { state.chips } },
              colour = G.C.CHIPS })
        return ret
    end
end

--------------------------------------------------------------------------------
-- AmaLee, Ironmouse, Dokibird and Rin Penrose
--------------------------------------------------------------------------------

--- AmaLee's opening move, for the pair that keeps it: a Snowstorm at the
--- moment the Blind is chosen, so it is up for the whole round. The Arena
--- clears itself on the way back to Blind select. Aquwa's open_with_downpour
--- is the same thing in the other weather.
local function open_with_snowstorm(card, context)
    if not (context.setting_blind and not context.blueprint) then return nil end
    local Arena = CelestasMod.Arena
    if snowing() or not (Arena and Arena.start) then return nil end
    Arena.start("snowstorm")
    return { message = localize("celesta_snowstorm"), colour = G.C.BLUE,
             card = card }
end

-- AmaLee + Ironmouse: AmaLee's weather, and Ironmouse's exponent while it is
-- up. This one DOES bring its own storm, and the card says so.
special("j_celesta_amalee", "j_celesta_ironmouse", {
    key = "amalee_ironmouse",
    config = { e_mult = 1.4 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        local snow = open_with_snowstorm(card, context)
        if snow then return snow end

        if not (context.joker_main and snowing()) then return end
        if not power_supported("amalee_ironmouse_no_talisman",
                               "AmaLee + Ironmouse") then
            return
        end
        return { e_mult = state.e_mult }
    end,
})

-- AmaLee + Dokibird: Dokibird deals in what a card has stored, so the storm
-- leaves Chips behind on everything that scores in it.
--
-- perma_bonus is where a Chip bonus that outlives the hand lives, and where
-- Dokibird itself writes. The gain lands as the card scores, so it is paid
-- from that card's NEXT scoring - BerryCrepe's permanent Mult behaves the
-- same way.
special("j_celesta_amalee", "j_celesta_dokibird", {
    key = "amalee_doki",
    config = { chips = 20 },

    loc_vars = function(def, card, state)
        return { vars = { state.chips } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and context.other_card and not context.blueprint) then return end
        if not snowing() then return end
        local other = context.other_card
        other.ability.perma_bonus = (other.ability.perma_bonus or 0) + state.chips
        return {
            message = localize { type = "variable", key = "a_chips",
                                 vars = { state.chips } },
            colour = G.C.CHIPS, card = other,
        }
    end,
})

-- AmaLee + Rin Penrose: Rin's bank, paid double in AmaLee's weather.
--
-- Rin's shape: the hand's total read in the `after` pass, banked, and paid a
-- step at a time with the remainder kept, so two hands of 30 are worth a step
-- between them. Divided rather than looped, because one hand under Talisman
-- can be worth more steps than a loop would ever finish.
special("j_celesta_amalee", "j_celesta_rinpenrose", {
    key = "amalee_rin",
    config = { mult = 0, mult_gain = 10, snow_gain = 20,
               chips_per_step = 50, bank = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.mult_gain, state.snow_gain,
                          state.chips_per_step,
                          state.chips_per_step - (state.bank or 0),
                          state.mult } }
    end,

    calculate = function(def, card, context, state)
        if context.after and not context.blueprint then
            local scored = scored_chips()
            if scored <= 0 then return end
            state.bank = (state.bank or 0) + scored
            local steps = math.floor(state.bank / state.chips_per_step)
            if steps <= 0 then return end
            state.bank = state.bank - steps * state.chips_per_step
            -- The weather is read when the step is PAID, which is the hand
            -- that earned it: a storm that ends between hands does not take
            -- back what it was worth.
            local per = snowing() and state.snow_gain or state.mult_gain
            state.mult = state.mult + steps * per
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

-- Ironmouse + Dokibird: Dokibird's Chips, banked a hand at a time.
special("j_celesta_ironmouse", "j_celesta_dokibird", {
    key = "ironmouse_doki",
    config = { chips = 0, chip_gain = 100 },

    loc_vars = function(def, card, state)
        return { vars = { state.chip_gain, state.chips } }
    end,

    calculate = function(def, card, context, state)
        if context.after and not context.blueprint then
            state.chips = state.chips + state.chip_gain
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

-- Ironmouse + Rin Penrose: Rin's bank, in Ironmouse's exponent.
--
-- The exponent ACCUMULATES rather than compounding: a step adds 0.05 to it,
-- the way Ironmouse + Michi's does. ^1.05 twice over is ^1.10 here, not
-- ^1.1025 - which is the reading every other growing exponent in this file
-- uses, and the only one a player can do in their head.
special("j_celesta_ironmouse", "j_celesta_rinpenrose", {
    key = "ironmouse_rin",
    config = { e_mult = 1, e_mult_gain = 0.05, chips_per_step = 100, bank = 0 },

    loc_vars = function(def, card, state)
        return { vars = { 1 + state.e_mult_gain, state.chips_per_step,
                          state.chips_per_step - (state.bank or 0),
                          state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.after and not context.blueprint then
            local scored = scored_chips()
            if scored <= 0 then return end
            state.bank = (state.bank or 0) + scored
            local steps = math.floor(state.bank / state.chips_per_step)
            if steps <= 0 then return end
            state.bank = state.bank - steps * state.chips_per_step
            state.e_mult = state.e_mult + steps * state.e_mult_gain
            return {
                message = localize { type = "variable", key = "celesta_powmult",
                                     vars = { state.e_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main and state.e_mult > 1 then
            if not power_supported("ironmouse_rin_no_talisman",
                                   "Ironmouse + Rin Penrose") then
                return
            end
            return { e_mult = state.e_mult }
        end
    end,
})

-- Dokibird + Rin Penrose: Rin's bank read off the MULT the hand scored rather
-- than the Chips, and paid back in Chips.
--
-- `mult` is the global Balatro keeps the running multiplier in, and the
-- ordinary scoring path never clears it - only the "hand not allowed" branch
-- does (state_events.lua:786), which never reaches `after`. So it still holds
-- this hand's total here, exactly as hand_chips does.
special("j_celesta_dokibird", "j_celesta_rinpenrose", {
    key = "doki_rin",
    config = { chips = 0, chip_gain = 100, mult_per_step = 10, bank = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.chip_gain, state.mult_per_step,
                          state.mult_per_step - (state.bank or 0),
                          state.chips } }
    end,

    calculate = function(def, card, context, state)
        if context.after and not context.blueprint then
            local scored = scored_mult()
            if scored <= 0 then return end
            state.bank = (state.bank or 0) + scored
            local steps = math.floor(state.bank / state.mult_per_step)
            if steps <= 0 then return end
            state.bank = state.bank - steps * state.mult_per_step
            state.chips = state.chips + steps * state.chip_gain
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

--------------------------------------------------------------------------------
-- Snuffy
--------------------------------------------------------------------------------
--
-- Snuffy widens the hand, so all four of these are paid by how wide it got.
-- context.joker_main carries full_hand - the whole played hand, scoring and
-- unscoring alike (state_events.lua:667) - which is what "each card in played
-- hand" means and what Snuffy's own extra picks put there.

--- How many cards were played this hand.
local function played_count(context)
    local hand = context.full_hand or (G.play and G.play.cards)
    return #(hand or {})
end

-- Snuffy + Nyanners: Nyanners pays Chips for each of something, and the hand
-- is the something.
special("j_celesta_snuffy", "j_celesta_nyanners", {
    key = "snuffy_nyanners",
    config = { chips = 30 },

    loc_vars = function(def, card, state)
        return { vars = { state.chips } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local total = state.chips * played_count(context)
        if total > 0 then return { chips = total } end
    end,
})

-- Snuffy + Ironmouse: Ironmouse's exponent, one card's worth at a time.
--
-- The EXCESS over ^1 is what each card adds, so five cards are ^1.5 rather
-- than ^5.5. That is the reading every growing exponent in this file uses, and
-- the only one that leaves the number on the card meaning anything.
special("j_celesta_snuffy", "j_celesta_ironmouse", {
    key = "snuffy_ironmouse",
    config = { e_mult = 1.1 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local e_mult = 1 + (state.e_mult - 1) * played_count(context)
        if e_mult <= 1 then return end
        if not power_supported("snuffy_ironmouse_no_talisman",
                               "Snuffy + Ironmouse") then
            return
        end
        return { e_mult = e_mult }
    end,
})

-- Snuffy + Silvervale: Silvervale's X Mult, counted off the hand instead of
-- off the Rares sold.
special("j_celesta_snuffy", "j_celesta_silvervale", {
    key = "snuffy_silvervale",
    config = { x_mult = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local x_mult = state.x_mult * played_count(context)
        -- X1 is no multiplier at all, and returning it would put a flourish
        -- over the Joker every hand for doing nothing.
        if x_mult > 1 then return { x_mult = x_mult } end
    end,
})

-- Snuffy + Projekt Melody: Projekt Melody pays at the cash-out, for every card
-- the round has played.
--
-- Counted per ROUND, and kept against the round number rather than reset by a
-- hook: the cash-out reads calc_dollar_bonus AFTER the end_of_round pass
-- (state_events.lua:101 then :1176), so a reset there would zero the tally
-- before it was paid. Comparing the round instead cannot get that order wrong.
special("j_celesta_snuffy", "j_celesta_projektmelody", {
    key = "snuffy_melody",
    config = { dollars = 3, cards = 0, round = -1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars, state.dollars * state.cards } }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint) then return end
        local round = (G.GAME and G.GAME.round) or 0
        if state.round ~= round then
            state.round = round
            state.cards = 0
        end
        state.cards = state.cards + #(context.full_hand or {})
    end,

    calc_dollar_bonus = function(def, card, state)
        local round = (G.GAME and G.GAME.round) or 0
        if state.round ~= round or state.cards <= 0 then return end
        return state.dollars * state.cards
    end,
})


--------------------------------------------------------------------------------
-- Lucia
--------------------------------------------------------------------------------
--
-- Lucia pays most for a hand of one card and less for every card after it. Two
-- of these keep that taper - through CelestasMod.lucia_taper, so the Joker and
-- the pair cannot come to disagree about what "one less for each extra card"
-- means - and the rest trade it for something that does not care how wide the
-- hand was.

-- Lucia + Angel Steps: Angel Steps' swap, and a flat multiplier in place of
-- Lucia's taper.
--
-- The swap is Angel Steps' own, at context.modify_hand: `mult` and hand_chips
-- are the globals evaluate_play keeps the base score in, and that context is
-- raised from inside Blind:modify_hand with both already written - the one
-- moment the base score is still the base score. The message is load-bearing:
-- Steamodded re-draws the score readout from whether anything was calculated,
-- and without it the hand would score swapped while the readout still showed
-- the old numbers.
special("j_celesta_lucia", "j_celesta_angelsteps", {
    key = "lucia_angel",
    config = { x_mult = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.modify_hand then
            mult, hand_chips = hand_chips, mult
            return { message = localize("celesta_swapped"), colour = G.C.CHIPS }
        end

        if context.joker_main then return { x_mult = state.x_mult } end
    end,
})

-- Lucia + Mari Yume: Mari Yume copies, so the taper is spent on retriggers
-- rather than on Mult - five for a hand of one card, one fewer for each card
-- after that, down to the one trigger every card gets anyway.
special("j_celesta_lucia", "j_celesta_mariyume", {
    key = "lucia_mari",
    config = { repetitions = 5 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if not CelestasMod.lucia_taper then return end
        local times = CelestasMod.lucia_taper(state.repetitions,
                                              played_count(context), 0)
        if times <= 0 then return end
        return {
            message = localize("k_again_ex"),
            repetitions = times,
            card = card,
        }
    end,
})

-- Lucia + El XoX: El XoX counts the hands a round has, so what is left of them
-- is the multiplier.
special("j_celesta_lucia", "j_celesta_el_xox", {
    key = "lucia_elxox",

    loc_vars = function(def, card, state)
        local round = G.GAME and G.GAME.current_round
        return { vars = { (round and round.hands_left) or 0 } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local round = G.GAME and G.GAME.current_round
        local x_mult = (round and round.hands_left) or 0
        -- X1 and X0 are both nothing worth announcing, and X0 would take the
        -- whole score with it if it were.
        if x_mult > 1 then return { x_mult = x_mult } end
    end,
})

--- Both straights. A Straight Flush is a straight, and Yoka + Boop answers for
--- a Full House and a Flush House together for the same reason.
local LUCIA_STRAIGHTS = { ["Straight"] = true, ["Straight Flush"] = true }

-- Lucia + Meicha: Meicha is the straight Joker, so a straight is what pays.
special("j_celesta_lucia", "j_celesta_meicha", {
    key = "lucia_meicha",
    config = { x_mult = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        if not LUCIA_STRAIGHTS[context.scoring_name] then return end
        return { x_mult = state.x_mult }
    end,
})

--- Lucia's multiplier, paid to each scored card carrying `enhancement`.
---
--- Three pairs, one body: the only thing that differs between them is which
--- card the other half is about.
local function lucia_enhanced(context, state, enhancement)
    if not (context.individual and context.cardarea == G.play
            and context.other_card and enhancement) then return nil end
    if not SMODS.has_enhancement(context.other_card, enhancement) then return nil end
    return { x_mult = state.x_mult, card = context.other_card }
end

-- Lucia + Zentreya: Zentreya's Steel Cards.
special("j_celesta_lucia", "j_celesta_zentreya", {
    key = "lucia_zentreya",
    config = { x_mult = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        return lucia_enhanced(context, state, "m_steel")
    end,
})

-- Lucia + Sinder: Sinder's Driftwood.
special("j_celesta_lucia", "j_celesta_sinder", {
    key = "lucia_sinder",
    config = { x_mult = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        local keys = CelestasMod.ENHANCEMENT_KEYS
        return lucia_enhanced(context, state, keys and keys.Driftwood)
    end,
})

-- Lucia + Jowol: Jowol's Stone cards, paid when they are played rather than
-- when they are held.
special("j_celesta_lucia", "j_celesta_jowol", {
    key = "lucia_jowol",
    config = { x_mult = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        return lucia_enhanced(context, state, "m_stone")
    end,
})


-- Kuro + Michi: Michi's second card off a discarded Purple Seal, and it is no
-- longer only a Tarot.
--
-- The seal makes the first card itself; Michi adds a second. This pair is that
-- second one, rolled across every consumable set the game has - so the pair is
-- Michi's own body with the set no longer written in.
--
-- The buffer is vanilla's own reservation: a slot claimed now and filled by an
-- event later still counts as taken, which is what stops two discarded seals in
-- the same discard racing for one slot. Decremented rather than zeroed, so a
-- second claim in flight is not thrown away with this one.
special("j_celesta_kuro", "j_celesta_michi", {
    key = "kuro_michi",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.discard and context.other_card
                and not context.blueprint) then return end
        if context.other_card.seal ~= "Purple" then return end
        if not bind_consumable_room() then return end

        local set = any_consumable_set("celesta_bind_kuro_michi")

        G.GAME.consumeable_buffer = (G.GAME.consumeable_buffer or 0) + 1
        G.E_MANAGER:add_event(Event {
            trigger = "before",
            delay = 0.0,
            func = function()
                local made = SMODS.add_card {
                    set = set, key_append = "celesta_bind_kuro_michi" }
                if made then made:juice_up(0.3, 0.5) end
                G.GAME.consumeable_buffer =
                    math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
                return true
            end
        })

        return { message = localize("celesta_plus_consumable"),
                 colour = G.C.PURPLE, card = card }
    end,
})


--------------------------------------------------------------------------------
-- Froot
--------------------------------------------------------------------------------
--
-- Froot reads the whole deck for Wild Cards. Most of these are that reading
-- paid in something else, two of them point it at a different card, and two
-- are not a count of the deck at all.
--
-- Every counted one is LIVE off the deck rather than banked, which is what
-- Froot's own line means and what every other "for each card in your full
-- deck" here does: a card that stops being Wild takes its share with it.

-- Froot + Zentreya: Froot's rate, counting Zentreya's Steel Cards instead.
special("j_celesta_froot", "j_celesta_zentreya", {
    key = "froot_zentreya",
    config = { x_mult_gain = 0.4 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain,
                          1 + state.x_mult_gain * enhanced_in_deck("m_steel") } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local x_mult = 1 + state.x_mult_gain * enhanced_in_deck("m_steel")
        if x_mult > 1 then return { x_mult = x_mult } end
    end,
})

-- Froot + Projekt Melody: Projekt Melody pays at the cash-out, so the deck is
-- what it pays for.
--
-- Through calc_dollar_bonus, the hook Projekt Melody's own money comes through,
-- so it gets its own line on the cash-out screen rather than arriving as a
-- floating message.
special("j_celesta_froot", "j_celesta_projektmelody", {
    key = "froot_melody",
    config = { dollars = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars, state.dollars * wilds_in_deck() } }
    end,

    calc_dollar_bonus = function(def, card, state)
        local owed = state.dollars * wilds_in_deck()
        if owed <= 0 then return end
        return owed
    end,

    calculate = function(def, card, context, state) end,
})

-- Froot + Ironmouse: Froot's count, in Ironmouse's exponent.
--
-- The exponent ACCUMULATES rather than compounding, the way every growing
-- exponent in this file does: ten Wild Cards are ^1.5, not ^1.05 to the tenth.
special("j_celesta_froot", "j_celesta_ironmouse", {
    key = "froot_ironmouse",
    config = { e_mult_gain = 0.05 },

    loc_vars = function(def, card, state)
        return { vars = { 1 + state.e_mult_gain,
                          1 + state.e_mult_gain * wilds_in_deck() } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local e_mult = 1 + state.e_mult_gain * wilds_in_deck()
        if e_mult <= 1 then return end
        if not power_supported("froot_ironmouse_no_talisman",
                               "Froot + Ironmouse") then
            return
        end
        return { e_mult = e_mult }
    end,
})

-- Froot + Nyanners: Nyanners pays Chips for each of something, and the Wild
-- Cards are the something.
special("j_celesta_froot", "j_celesta_nyanners", {
    key = "froot_nyanners",
    config = { chips = 75 },

    loc_vars = function(def, card, state)
        return { vars = { state.chips, state.chips * wilds_in_deck() } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local total = state.chips * wilds_in_deck()
        if total > 0 then return { chips = total } end
    end,
})

-- Froot + Silvervale: Silvervale's X Mult, counted off the deck rather than
-- off the Rares sold.
--
-- X1 PLUS the gain per card, which is Silvervale's own arithmetic: a deck with
-- no Wild Card in it is X1 and scores nothing, rather than X0 taking the whole
-- hand with it.
special("j_celesta_froot", "j_celesta_silvervale", {
    key = "froot_silvervale",
    config = { x_mult_gain = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain,
                          1 + state.x_mult_gain * wilds_in_deck() } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local x_mult = 1 + state.x_mult_gain * wilds_in_deck()
        if x_mult > 1 then return { x_mult = x_mult } end
    end,
})

-- Froot + Momo: Momo makes every hand a Flush, so a Flush is what this grows
-- on.
--
-- BANKED rather than counted, which is the one of these that is not about the
-- deck: what it is worth is how many flushes the run has played.
--
-- Momo's own widening is gone with the rest of it - a replacing pair speaks for
-- both halves, so CelestasMod.joker_in_play stops finding a Momo and hands stop
-- being flushes for free. What is left is the flushes you actually make.
--
-- Any hand with a flush in it: Flush, Straight Flush, Flush House, Flush Five,
-- and whatever a mod adds that is named for one. `scoring_name` is the internal
-- name rather than the localized one, so a plain find is safe here.
local function contains_flush(name)
    return type(name) == "string" and name:find("Flush", 1, true) ~= nil
end

special("j_celesta_froot", "j_celesta_momo", {
    key = "froot_momo",
    config = { x_mult = 1, x_mult_gain = 0.4 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        -- context.before sees the hand whole and lands ahead of scoring, so
        -- the flush that earned the gain is the first hand to be paid by it.
        if context.before and not context.blueprint
            and contains_flush(context.scoring_name) then
            state.x_mult = state.x_mult + state.x_mult_gain
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

--- The pair, so the selection hook below can name it once.
local FROOT_SNUFFY = "froot_snuffy"

-- Froot + Snuffy: Snuffy widens what can be selected, and a Wild Card is
-- outside the count - up to two of them.
--
-- Laimu + Snuffy's shape with a ceiling: the selection may run to the limit
-- plus two, and only a Wild Card may take one of those two places. The limit is
-- lifted by one for the length of the call so vanilla's own branch does the
-- work (cardarea.lua:172) - it plays the sound and re-parses the selection, and
-- reimplementing it here would mean keeping that in step forever.
special("j_celesta_froot", "j_celesta_snuffy", {
    key = FROOT_SNUFFY,
    config = { extra = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.extra } }
    end,

    calculate = function(def, card, context, state) end,
})

local celesta_froot_snuffy_highlight_ref = CardArea.add_to_highlighted
function CardArea:add_to_highlighted(card, silent)
    local free = self == G.hand and card
        and SMODS.has_enhancement(card, "m_wild")
        and Bind.find_special(FROOT_SNUFFY) or nil
    if free and not free.debuff then
        local def = Bind.special_of(free)
        local extra = def and Bind.special_state(free, def).extra or 0
        local saved = self.config.highlighted_limit
        if #self.highlighted < saved + extra then
            self.config.highlighted_limit = #self.highlighted + 1
            local ok, err = pcall(celesta_froot_snuffy_highlight_ref,
                                  self, card, silent)
            self.config.highlighted_limit = saved
            if not ok then error(err, 0) end
            return
        end
    end
    return celesta_froot_snuffy_highlight_ref(self, card, silent)
end

-- Froot + FeFe: FeFe deals in Hearts, so the Hearts are what is counted.
special("j_celesta_froot", "j_celesta_fefe", {
    key = "froot_fefe",
    config = { x_mult_gain = 0.04 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain,
                          1 + state.x_mult_gain
                              * CelestasMod.count_suit_in_deck("Hearts") } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local x_mult = 1 + state.x_mult_gain
            * CelestasMod.count_suit_in_deck("Hearts")
        if x_mult > 1 then return { x_mult = x_mult } end
    end,
})

-- Froot + Hime: Hime deals in Eutrophic cards, so those are what is counted.
special("j_celesta_froot", "j_celesta_hime", {
    key = "froot_hime",
    config = { x_mult_gain = 0.4 },

    loc_vars = function(def, card, state)
        local keys = CelestasMod.ENHANCEMENT_KEYS
        return { vars = { state.x_mult_gain,
                          1 + state.x_mult_gain
                              * enhanced_in_deck(keys and keys.Eutrophic) } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local keys = CelestasMod.ENHANCEMENT_KEYS
        local x_mult = 1 + state.x_mult_gain
            * enhanced_in_deck(keys and keys.Eutrophic)
        if x_mult > 1 then return { x_mult = x_mult } end
    end,
})


--------------------------------------------------------------------------------
-- Ellie Minibot, and MinikoMew's debt
--------------------------------------------------------------------------------
--
-- Ellie Minibot answers context.fix_probability: it hands back a numerator
-- equal to the denominator, which is a chance that always comes up. On its own
-- it only covers this mod's own Jokers. Two of the pairs below point that at
-- rolls it does not normally reach, and one of them turns it round - a
-- numerator of NOTHING is a roll that never comes up.

-- Ellie Minibot + Cerber: Cerber sends the biggest card round again, which is
-- another chance for a fragile one to break. Together they stop breaking.
--
-- Both rolls: vanilla's Glass shatter, which rolls under the identifier
-- `glass`, and this mod's Gash break under CelestasMod.GASH_BREAK_ID. Answered
-- at the roll rather than at the destruction, so the card is never picked to
-- break in the first place and nothing downstream has to be told about it.
special("j_celesta_ellie_minibot", "j_celesta_cerbervt", {
    key = "ellie_cerber",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not context.fix_probability then return end
        local id = context.identifier
        if not (id == "glass" or id == CelestasMod.GASH_BREAK_ID) then return end
        -- Zero, not nil: nil would leave the roll at whatever it was, and 0 is
        -- a truthy value in Lua so it survives the `or` chain SMODS reads the
        -- fixed numerator through (utils.lua:2733).
        return { numerator = 0 }
    end,
})

-- Ellie Minibot + Neuro: the Lucky card's two rolls, always won.
--
-- Vanilla rolls them as `lucky_mult` (1 in 5, for the Mult) and `lucky_money`
-- (1 in 15, for the money) - card.lua:1186 and :1311. Neither belongs to a
-- Joker, which is why Ellie alone does not cover them: it asks whether the
-- thing rolling is one of this mod's Jokers, and a playing card is not.
special("j_celesta_ellie_minibot", "j_celesta_neuro", {
    key = "ellie_neuro",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not context.fix_probability then return end
        local id = context.identifier
        if not (id == "lucky_mult" or id == "lucky_money") then return end
        local d = context.denominator
        -- Only a number, or a Talisman big number - Ellie's own guard, for the
        -- same reason: Cryptid's RNJoker passes a sentence.
        if type(d) ~= "number" and not (type(d) == "table" and getmetatable(d)) then
            return
        end
        return { numerator = d }
    end,
})

-- Ellie Minibot + Vedal: Vedal's exponent climbs twice as fast.
--
-- Not a calculate at all. jokers/implemented.lua asks CelestasMod.vedal_step
-- at every scale and multiplies the rules it finds together, so this file does
-- not have to know how the scaling works and that one does not have to know
-- that merges exist - the same seam Kuro's boss hold uses.
special("j_celesta_ellie_minibot", "j_celesta_vedal", {
    key = "ellie_vedal",
    config = { scale = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.scale } }
    end,

    calculate = function(def, card, context, state) end,
})

-- `or {}` for the reason Kuro's rule gives: globals.lua declares the list, and
-- this file is loaded before the one that reads it.
CelestasMod.VEDAL_SCALE_RULES = CelestasMod.VEDAL_SCALE_RULES or {}
CelestasMod.VEDAL_SCALE_RULES[#CelestasMod.VEDAL_SCALE_RULES + 1] = function()
    local holder, def = Bind.find_special("ellie_vedal")
    if not (holder and not holder.debuff) then return 1 end
    return Bind.special_state(holder, def).scale
end

-- MinikoMew + Cerber: MinikoMew is paid for being in debt, and Cerber picks
-- the biggest card - so the debt buys retriggers of it.
--
-- The card is Cerber's own pick, through CelestasMod.highest_ranked, so the
-- two cannot disagree about which one is biggest. The debt is MinikoMew's own
-- reading, which is a Talisman number once it is large enough - hence the
-- floor going through a plain number rather than the debt itself.
special("j_celesta_minikomew", "j_celesta_cerbervt", {
    key = "minikomew_cerber",
    config = { per = 5 },

    loc_vars = function(def, card, state)
        return { vars = { state.per } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if not CelestasMod.highest_ranked then return end
        if context.other_card ~= CelestasMod.highest_ranked(context.scoring_hand) then
            return
        end

        local debt = CelestasMod.minikomew_debt and CelestasMod.minikomew_debt() or 0
        -- Through to_number for the same reason the banking pairs do: past a
        -- double the debt is one of Talisman's, and a repetition count has to
        -- be a plain number the scoring pass can loop on.
        if type(debt) ~= "number" and type(to_number) == "function" then
            local ok, converted = pcall(to_number, debt)
            debt = ok and converted or 0
        end
        if type(debt) ~= "number" or debt ~= debt or debt == math.huge then
            return
        end

        local times = math.floor(debt / state.per)
        if times <= 0 then return end
        return {
            message = localize("k_again_ex"),
            repetitions = times,
            card = card,
        }
    end,
})


--------------------------------------------------------------------------------
-- Eros
--------------------------------------------------------------------------------
--
-- Eros eats the Bonus enhancement off scoring cards and keeps the Chips. One
-- of these feeds it Bonus cards to eat, one eats them for a great deal more,
-- and one eats something else entirely.

-- Eros + KokoNuts: KokoNuts' seven, wearing the enhancement Eros lives on.
--
-- KokoNuts' own timing, which Suko + KokoNuts also keeps: setting_blind, so
-- the card is in the deck before a hand is drawn. The getting_sliced test is
-- KokoNuts' too - a Joker being destroyed as the Blind is set must not spend
-- its last act adding a card.
special("j_celesta_eros", "j_celesta_kokonuts", {
    key = "eros_koko",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if context.setting_blind and not context.blueprint
            and not (context.blueprint_card or card).getting_sliced then
            koko_sevens(card, 1, "celesta_bind_eros_koko", nil, nil,
                        G.P_CENTERS.m_bonus)
            return nil, true
        end
    end,
})

-- Eros + LaynaLazar: LaynaLazar goes looking through the played hand, and what
-- it finds here is face cards - eaten, for three times what they were holding.
--
-- context.destroy_card is raised once for every card in the played hand,
-- scoring and unscoring alike (SMODS utils.lua:2061), so this eats every face
-- card played rather than only the ones that scored. Saying `remove` is what
-- destroys it, and it buys the animation, the removal from the deck and the
-- remove_playing_cards pass other Jokers watch.
--
-- "Stored Chips" is get_chip_bonus - the card's rank, its enhancement's bonus
-- and any permanent bonus on top - which is the reading Dokibird's line uses
-- for the same phrase.
special("j_celesta_eros", "j_celesta_laynalazar", {
    key = "eros_layna",
    config = { chips = 0, rate = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.rate, state.chips } }
    end,

    calculate = function(def, card, context, state)
        if context.destroy_card and not context.blueprint
            and not context.retrigger_joker then
            local doomed = context.destroy_card
            if not (doomed.is_face and doomed:is_face()) then return end

            local stored = doomed.get_chip_bonus and doomed:get_chip_bonus() or 0
            state.chips = state.chips + stored * state.rate
            return {
                remove = true,
                message = localize { type = "variable", key = "a_chips",
                                     vars = { state.chips } },
                colour = G.C.CHIPS,
                card = card,
            }
        end

        if context.joker_main and state.chips > 0 then
            return { chips = state.chips }
        end
    end,
})

-- Eros + Grimmi: Eros's own meal, at more than twice the price.
--
-- The strip itself is Eros's, through CelestasMod.eros_strip, so the pair
-- cannot come to disagree with the Joker about which cards were eaten - and
-- the timing comes with it: context.before, so the enhancement is gone before
-- the hand scores and those cards do not pay their Chips this hand. That is
-- the trade, and it is vanilla Vampire's shape.
--
-- Banked plainly rather than through SMODS.scale_card, which is how every
-- other pair in this file grows. Eros alone goes through scale_card and so is
-- reachable by Vedal; no merge in this file is, and making this the one
-- exception would be a change to Vedal rather than to Eros.
special("j_celesta_eros", "j_celesta_grimmi", {
    key = "eros_grimmi",
    config = { chips = 0, chip_gain = 36 },

    loc_vars = function(def, card, state)
        return { vars = { state.chip_gain, state.chips } }
    end,

    calculate = function(def, card, context, state)
        if context.before and not context.blueprint then
            local removed = CelestasMod.eros_strip
                and CelestasMod.eros_strip(context.scoring_hand) or 0
            if removed <= 0 then return end
            state.chips = state.chips + state.chip_gain * removed
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


--------------------------------------------------------------------------------
-- Tobs
--------------------------------------------------------------------------------
--
-- All three are about Eutrophic cards, and all three replace Tobs - so the
-- widening it exists for would go with it. The rule below is what keeps it:
-- enhancements/enhancements.lua asks whether anything widens a Eutrophic, and
-- any of these three answers yes.

--- The three, so the rules below can name them once.
local TOBS_PAIRS = { "tobs_nihmune", "tobs_suko", "tobs_toma" }

CelestasMod.EUTROPHIC_WIDE_RULES = CelestasMod.EUTROPHIC_WIDE_RULES or {}
CelestasMod.EUTROPHIC_WIDE_RULES[#CelestasMod.EUTROPHIC_WIDE_RULES + 1] = function()
    for _, key in ipairs(TOBS_PAIRS) do
        if specials_held(key)[1] then return true end
    end
    return false
end

-- Tobs + Nihmune: Nihmune turns the scoring hand into Clubs; this turns the
-- Clubs into Eutrophic cards, which is then something Tobs's own widening has
-- a use for.
--
-- context.before, ahead of scoring, so the cards are Eutrophic by the time
-- they score - the same moment Arar and Eros work at. Under unjudged for
-- Arar's reason: set_ability re-judges the card, and The Pillar debuffs
-- anything played this Ante, which is every card in the hand being played.
special("j_celesta_tobs", "j_celesta_nihmune", {
    key = "tobs_nihmune",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint) then return end
        local key = CelestasMod.ENHANCEMENT_KEYS
            and CelestasMod.ENHANCEMENT_KEYS.Eutrophic
        local center = key and G.P_CENTERS[key]
        if not center then return end

        local made = 0
        for _, played in ipairs(context.scoring_hand or {}) do
            if played.is_suit and played:is_suit("Clubs")
                and not SMODS.has_enhancement(played, key) then
                made = made + 1
                local target = played
                CelestasMod.unjudged(target, function()
                    target:set_ability(center, nil, true)
                end)
                G.E_MANAGER:add_event(Event {
                    func = function() target:juice_up() return true end
                })
            end
        end

        if made > 0 then
            return { message = localize("k_upgrade_ex"),
                     colour = G.C.SECONDARY_SET.Enhanced, card = card }
        end
    end,
})

-- Tobs + Suko: every played Eutrophic card comes out Foil.
--
-- Only a card with no edition: this gives one, it does not trade one away -
-- and that test is also what stops the same card being re-done every hand.
special("j_celesta_tobs", "j_celesta_suko", {
    key = "tobs_suko",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint) then return end
        local key = CelestasMod.ENHANCEMENT_KEYS
            and CelestasMod.ENHANCEMENT_KEYS.Eutrophic
        if not key then return end

        local made = 0
        for _, played in ipairs(context.full_hand or {}) do
            if SMODS.has_enhancement(played, key) and not played.edition then
                made = made + 1
                played:set_edition({ foil = true }, true)
            end
        end

        if made > 0 then
            return { message = localize("k_upgrade_ex"),
                     colour = G.C.DARK_EDITION, card = card }
        end
    end,
})

-- Tobs + Toma: Toma is the True Stars Joker, so a Eutrophic True Star copies
-- twice as much.
--
-- Answered through CelestasMod.EUTROPHIC_SCALE_RULES rather than by a
-- calculate: what changes is a number the enhancement works out for itself,
-- long before any Joker is asked anything.
special("j_celesta_tobs", "j_celesta_toma", {
    key = "tobs_toma",
    config = { scale = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.scale } }
    end,

    calculate = function(def, card, context, state) end,
})

CelestasMod.EUTROPHIC_SCALE_RULES = CelestasMod.EUTROPHIC_SCALE_RULES or {}
CelestasMod.EUTROPHIC_SCALE_RULES[#CelestasMod.EUTROPHIC_SCALE_RULES + 1] =
    function(copying)
        if not (CelestasMod.is_true_star and CelestasMod.is_true_star(copying)) then
            return 1
        end
        local entry = specials_held("tobs_toma")[1]
        if not entry then return 1 end
        return Bind.special_state(entry.card, entry.def).scale
    end


--------------------------------------------------------------------------------
-- El XoX
--------------------------------------------------------------------------------
--
-- El XoX reads a round as a ledger and pays for the hands that were spent, so
-- nearly all of its merges pay money too. What changes between them is only
-- what the other half hands it to count.
--
-- The whole section is inside a `do` block, and that is not house style. Lua
-- allows 200 active locals in a chunk and this file was already at 179; the
-- helpers below would have taken most of what is left. A block's locals are
-- freed at its end, so the next batch starts from the same count this one did.

do

--- The hands left in the round, which three of these pairs are counted in.
local function hands_left()
    local round = G.GAME and G.GAME.current_round
    return (round and round.hands_left) or 0
end

--- The hands spent so far this round - El XoX's own measure.
local function hands_spent()
    local round = G.GAME and G.GAME.current_round
    return (round and round.hands_played) or 0
end

--- Tells every held, working merge that asked about `hook` that it happened.
---
--- CelestasMod.ectoplast_triggered, further up, is this written out longhand
--- for one hook. Three more in one section is enough to be worth one body.
---
--- Guarded per pair, for that one's reason: a merge that faults must not stop
--- whatever raised this finishing its own work, or stop the next merge
--- hearing about it.
local function notify_specials(hook, ...)
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        if not held.debuff then
            local def = Bind.special_of(held)
            if def and type(def[hook]) == "function" then
                local ok, err = pcall(def[hook], def, held,
                    Bind.special_state(held, def), ...)
                if not ok then
                    CelestasMod.warn_once(
                        "bind_" .. hook .. "_" .. tostring(def.key),
                        ("Bind pair %s failed on %s: %s")
                            :format(tostring(def.key), hook, tostring(err)))
                end
            end
        end
    end
end

--- Told by the Star Seal each time one copies a card into the deck
--- (seals/seals.lua), with the sealed card, the card it copied, and how many
--- copies it made.
function CelestasMod.star_seal_copied(sealed, source, copies)
    notify_specials("on_star_copy", sealed, source, copies or 1)
end

--- Told by the Eutrophic enhancement each time one actually produces
--- something from the card it is copying (enhancements/enhancements.lua).
function CelestasMod.eutrophic_mimicked(copier, source)
    notify_specials("on_eutrophic_mimic", copier, source)
end

--- Told each time a Blue Seal makes its Planet (jokers/implemented.lua, where
--- the create_card that does it is already watched for August Anomoly).
function CelestasMod.blue_seal_triggered(planet)
    notify_specials("on_blue_seal", planet)
end

--- A payout that arrives outside a scoring pass, where there is no effect
--- table to return one in. The four notification pairs below all pay this way.
local function pay_now(card, owed)
    if not owed or owed <= 0 then return end
    SMODS.calculate_effect({ dollars = owed }, card)
end

--- The pairs that are "scored cards of this description give money" differ
--- only in the description, so they share a body.
---
--- G.play only: these say "scored", and a card held in hand is not that.
local function scored_pays(matches)
    return function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and context.other_card) then return end
        if not matches(context.other_card) then return end
        return { dollars = state.dollars, card = context.other_card }
    end
end

--- Reads a suit off a card the way every other suit question in this mod
--- does, so a Wild card counts as one.
local function suited(suit)
    return function(other)
        return other.is_suit ~= nil and other:is_suit(suit)
    end
end

--- The name and colour of `suit`, singular, for a line reading "#2# cards".
local function suit_line(dollars, suit, hex)
    local name, colour = CelestasMod.suit_name_and_colour(suit, hex, true)
    return { vars = { dollars, name, colours = { colour } } }
end

-- El XoX + Toma: Toma is the Joker that rolls for money, so this rolls for it
-- once a hand instead of once a card.
special("j_celesta_el_xox", "j_celesta_toma", {
    key = "elxox_toma",
    config = { odds = 2, dollars = 5 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_elxox_toma")
        return { vars = { n, d, state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint) then return end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_elxox_toma",
                1, state.odds, "celesta_bind_elxox_toma") then return end
        return { dollars = state.dollars, card = card }
    end,
})

-- El XoX + Mari Yume: Mari Yume is about the rightmost Joker and El XoX counts
-- the hands of the round, so the rightmost Joker goes again once per hand left.
special("j_celesta_el_xox", "j_celesta_mariyume", {
    key = "elxox_mariyume",

    loc_vars = function(def, card, state)
        return { vars = { hands_left() } }
    end,

    calculate = function(def, card, context, state)
        -- retrigger_joker_check is asked of every Joker about every other one,
        -- so the answer has to name who it is being asked about, and it must
        -- refuse itself - which also covers the case of this card BEING the
        -- rightmost one.
        --
        -- `not context.retrigger_joker` is Calamitas's guard, and this wants
        -- it for the same reason: four repetitions of a retrigger that is
        -- itself a retrigger compound far faster than one does.
        if not (context.retrigger_joker_check and not context.retrigger_joker
                and context.other_card and context.other_card ~= card) then
            return
        end
        local row = G.jokers and G.jokers.cards
        if not (row and context.other_card == row[#row]) then return end

        local times = hands_left()
        if times <= 0 then return end
        return {
            message = localize("k_again_ex"),
            repetitions = times,
            card = card,
        }
    end,
})

-- El XoX + Projekt Melody: Projekt Melody's payout grows round by round, and
-- what grows it here is what El XoX counts - except it is the hands NOT spent,
-- so the round that banks the most is the round that needed the fewest.
--
-- The gain is taken in the end_of_round pass and paid out in the cash-out that
-- follows it, so a round's hands are banked before they are paid for, which is
-- the order the two sentences on the card read in.
special("j_celesta_el_xox", "j_celesta_projektmelody", {
    key = "elxox_melody",
    config = { dollars = 1, stored = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars, state.stored } }
    end,

    calculate = function(def, card, context, state)
        if not (context.end_of_round and context.main_eval
                and not context.blueprint) then return end
        local gained = hands_left() * state.dollars
        if gained <= 0 then return end
        state.stored = state.stored + gained
        return { message = localize("k_upgrade_ex"),
                 colour = G.C.MONEY, card = card }
    end,

    calc_dollar_bonus = function(def, card, state)
        if (state.stored or 0) <= 0 then return end
        return state.stored
    end,
})

-- El XoX + Aquwa: Aquwa's weather, paid for by the hand.
--
-- The pair does not start a Downpour - it replaces the half that would have -
-- so this is worth something only while something else brings the weather:
-- the Rain Deck, or another Joker. Aquwa + Megalodon is the same shape, and
-- says the same "if" on its card.
special("j_celesta_el_xox", "j_celesta_aquwa", {
    key = "elxox_aquwa",
    config = { dollars = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    -- The weather is round-scoped and the shop is what clears it, so it is
    -- still up at the cash-out - "had just happened that round" is exactly
    -- what asking here answers.
    calc_dollar_bonus = function(def, card, state)
        if not raining() then return end
        local spent = hands_spent()
        if spent <= 0 then return end
        return spent * state.dollars
    end,

    calculate = function(def, card, context, state) end,
})

-- El XoX + Kumi: Kumi is the Gold card Joker, and this pays for the Gold cards
-- that were NOT played - at half of one each, scaled by the hands spent.
special("j_celesta_el_xox", "j_celesta_kumi", {
    key = "elxox_kumi",
    config = { share = 0.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.share } }
    end,

    -- The end_of_round pass rather than the cash-out, because this reads the
    -- HAND: the cards are sent to the discard pile between the two
    -- (state_events.lua:174), so by the cash-out there is nothing to count.
    --
    -- Floored, the way Mint Fantome + Matara Kan floors its half: a payout is
    -- money, and money in this game is whole.
    calculate = function(def, card, context, state)
        if not (context.end_of_round and context.main_eval
                and not context.blueprint) then return end
        local gold = 0
        for _, held in ipairs((G.hand and G.hand.cards) or {}) do
            if SMODS.has_enhancement(held, "m_gold") then gold = gold + 1 end
        end
        local owed = math.floor(hands_spent() * gold * state.share)
        if owed <= 0 then return end
        return { dollars = owed, card = card }
    end,
})

-- El XoX + Crelly: Crelly eats a consumable at the end of the shop to grow.
-- Here it eats money instead, which is the thing El XoX makes.
special("j_celesta_el_xox", "j_celesta_crelly", {
    key = "elxox_crelly",
    config = { cost = 2, x_mult = 1, x_mult_gain = 0.2 },

    loc_vars = function(def, card, state)
        return { vars = { state.cost, state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.ending_shop and not context.blueprint then
            -- "Cannot go into debt" is about the money there IS, not about the
            -- floor a Credit Card lowers: this only ever eats what is already
            -- in hand, so it buys nothing on a round it cannot afford.
            local held = (G.GAME and G.GAME.dollars) or 0
            if CelestasMod.more_than(state.cost, held) then return end
            ease_dollars(-state.cost)
            state.x_mult = state.x_mult + state.x_mult_gain
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

-- El XoX + CottontailVA: CottontailVA hands out the Star Seals, and this is
-- paid when one of them does its work.
special("j_celesta_el_xox", "j_celesta_cottontail", {
    key = "elxox_cottontail",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    -- Per copy rather than per trigger: Ray + CottontailVA makes two copies
    -- from one Seal, and that is a card copied twice.
    on_star_copy = function(def, card, state, sealed, source, copies)
        pay_now(card, (copies or 1) * state.dollars)
    end,

    calculate = function(def, card, context, state) end,
})

-- El XoX + Jowol: Jowol's Stone cards, paid rather than scored. Both areas,
-- because "when triggered" is what Jowol's own line is about - it pays for
-- Stone cards held in hand.
special("j_celesta_el_xox", "j_celesta_jowol", {
    key = "elxox_jowol",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = function(def, card, context, state)
        -- Not the end-of-round held pass: that one is the cash-out, and
        -- Jowol's own line is about the pass after cards in hand score.
        -- Without this it would pay a second time for every Stone card the
        -- round ended holding.
        if not (context.individual and context.other_card
                and not context.end_of_round
                and (context.cardarea == G.play or context.cardarea == G.hand))
            then return end
        if not SMODS.has_enhancement(context.other_card, "m_stone") then return end
        return { dollars = state.dollars, card = context.other_card }
    end,
})

-- El XoX + KokoNuts: KokoNuts deals in 7s, so 7s are what pay.
special("j_celesta_el_xox", "j_celesta_kokonuts", {
    key = "elxox_koko",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    -- get_id is the rank's numeric value; 7 is literally 7.
    calculate = scored_pays(function(other)
        return other.get_id ~= nil and other:get_id() == 7
    end),
})

-- El XoX + Spongey: Spongey counts every Joker that triggers and turns it into
-- Chips. This counts the same thing and turns it into money.
special("j_celesta_el_xox", "j_celesta_spongeybuns", {
    key = "elxox_spongey",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    -- Spongey's own reading of post_trigger, filter and all: a probability
    -- lookup runs a full evaluation pass that arrives here looking exactly
    -- like a trigger, other_card is not always a Joker, and a Joker must not
    -- pay itself for its own scoring.
    calculate = function(def, card, context, state)
        if not (context.post_trigger and not context.blueprint) then return end
        local trigger = context.other_card
        local inner = context.other_context
        if inner and (inner.mod_probability or inner.fix_probability
            or inner.fixed_probability or inner.retrigger_joker_check) then
            return
        end
        if not (trigger and trigger.ability and trigger.ability.set == "Joker") then
            return
        end
        if trigger == card then return end
        return { dollars = state.dollars, card = card }
    end,
})

-- El XoX + Tobs: Tobs is the Joker about Eutrophic cards copying, and this is
-- paid each time one does.
--
-- The pair replaces Tobs, so what a Eutrophic mimics goes back to the two
-- numbers it mimics by default - and mimicking two numbers is still mimicking,
-- which is what this is paid for.
special("j_celesta_el_xox", "j_celesta_tobs", {
    key = "elxox_tobs",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    on_eutrophic_mimic = function(def, card, state, copier, source)
        pay_now(card, state.dollars)
    end,

    calculate = function(def, card, context, state) end,
})

-- El XoX + Vexoria: Vexoria turns the hand to Spades, so Spades are what pay.
special("j_celesta_el_xox", "j_celesta_vexoria", {
    key = "elxox_vexoria",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = scored_pays(suited("Spades")),
})

-- El XoX + Saiiren: Saiiren pays the last scored card of a suit; here every
-- suit qualifies and what it is worth is what El XoX counts.
special("j_celesta_el_xox", "j_celesta_saiiren", {
    key = "elxox_saiiren",

    loc_vars = function(def, card, state)
        return { vars = { hands_left() } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
                and context.other_card) then return end
        local scoring = context.scoring_hand or {}
        if context.other_card ~= scoring[#scoring] then return end
        local owed = hands_left()
        if owed <= 0 then return end
        return { dollars = owed, card = context.other_card }
    end,
})

-- El XoX + ObKatieKat: ObKatieKat's exponent, climbing on the thing El XoX
-- counts. Banked rather than read off the round, because it is the hands of
-- the whole RUN that have been played, not this round's.
--
-- The gain is taken in context.before, so the hand being played is already
-- counted by the time it scores - "every time a hand is played" includes this
-- one.
special("j_celesta_el_xox", "j_celesta_obkatiekat", {
    key = "elxox_katie",
    config = { e_chips = 1, e_chips_gain = 0.04 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_chips_gain, state.e_chips } }
    end,

    calculate = function(def, card, context, state)
        if context.before and not context.blueprint then
            state.e_chips = state.e_chips + state.e_chips_gain
        end

        if context.joker_main then
            if state.e_chips <= 1 then return end
            if not power_supported("elxox_katie_no_talisman",
                                   "El XoX + ObKatieKat", "Chips") then
                return
            end
            return { e_chips = state.e_chips }
        end
    end,
})

--- Any hand with a pair in it: Pair, Two Pair, Full House, and whatever a mod
--- adds that is named for one. The reading contains_flush gives, for the other
--- half of the same family - scoring_name is the internal name rather than the
--- localized one, so a plain find is safe.
---
--- Once per hand however many pairs are in it. "A pair is played" is about the
--- hand, the way "a Flush is played" is.
local function contains_pair(name)
    return type(name) == "string" and name:find("Pair", 1, true) ~= nil
end

-- El XoX + Pipi: Pipi is the two-card Joker, and two of a kind is what pays.
special("j_celesta_el_xox", "j_celesta_pipi", {
    key = "elxox_pipi",
    config = { dollars = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        if not contains_pair(context.scoring_name) then return end
        return { dollars = state.dollars, card = card }
    end,
})

-- El XoX + Pomatomaster: Pomatomaster makes the Eutrophic cards, and this pays
-- for the ones still in hand when the round ends.
special("j_celesta_el_xox", "j_celesta_pomatomaster", {
    key = "elxox_pomato",
    config = { dollars = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    -- The end_of_round pass rather than the cash-out, for El XoX + Kumi's
    -- reason: the hand is emptied between the two.
    calculate = function(def, card, context, state)
        if not (context.end_of_round and context.main_eval
                and not context.blueprint) then return end
        local key = CelestasMod.ENHANCEMENT_KEYS
            and CelestasMod.ENHANCEMENT_KEYS.Eutrophic
        if not key then return end

        local held = 0
        for _, card_in_hand in ipairs((G.hand and G.hand.cards) or {}) do
            if SMODS.has_enhancement(card_in_hand, key) then held = held + 1 end
        end
        if held <= 0 then return end
        return { dollars = held * state.dollars, card = card }
    end,
})

-- El XoX + Fufu: Fufu reads the deck for the suits it holds; this pays for
-- them instead of multiplying by them.
special("j_celesta_el_xox", "j_celesta_fufu", {
    key = "elxox_fufu",
    config = { dollars = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calc_dollar_bonus = function(def, card, state)
        local suits = CelestasMod.unique_suits_in_deck()
        if suits <= 0 then return end
        return suits * state.dollars
    end,

    calculate = function(def, card, context, state) end,
})

-- El XoX + August Anomoly: August Anomoly is the Blue Seal Joker, and this is
-- paid each time one fires.
special("j_celesta_el_xox", "j_celesta_augustanomoly", {
    key = "elxox_august",
    config = { dollars = 2 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    on_blue_seal = function(def, card, state, planet)
        pay_now(card, state.dollars)
    end,

    calculate = function(def, card, context, state) end,
})

-- El XoX + PiaPiUFO: PiaPiUFO's suit, paid rather than multiplied.
special("j_celesta_el_xox", "j_celesta_piapiufo", {
    key = "elxox_piapiufo",
    config = { dollars = 2 },

    loc_vars = function(def, card, state)
        return suit_line(state.dollars,
            CelestasMod.STARS_SUIT, CelestasMod.STARS_COLOUR)
    end,

    calculate = scored_pays(suited(CelestasMod.STARS_SUIT)),
})

-- El XoX + Buffpup: Buffpup's suit, paid rather than counted off the deck.
special("j_celesta_el_xox", "j_celesta_buffpup", {
    key = "elxox_buffpup",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return suit_line(state.dollars,
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR)
    end,

    calculate = scored_pays(suited(CelestasMod.LEAF_SUIT)),
})

-- El XoX + Ebiko: Ebiko turns the hand to Diamonds, so Diamonds are what pay.
special("j_celesta_el_xox", "j_celesta_ebiko", {
    key = "elxox_ebiko",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = scored_pays(suited("Diamonds")),
})

-- El XoX + Tori Oriane: Tori Oriane is the True Star Joker, and this pays for
-- every one the deck holds rather than for the ones that scored - which is
-- worth arranging, because True Stars are hard to come by.
special("j_celesta_el_xox", "j_celesta_torioriane", {
    key = "elxox_torioriane",
    config = { dollars = 6 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calc_dollar_bonus = function(def, card, state)
        local stars = CelestasMod.true_stars_in_deck()
        if stars <= 0 then return end
        return stars * state.dollars
    end,

    calculate = function(def, card, context, state) end,
})

end


--------------------------------------------------------------------------------
-- Aquwa, Arar, Arielle and Deme again
--------------------------------------------------------------------------------

-- Aquwa + Deme: Aquwa's weather, and Deme's one-card hand made worth playing
-- for its own sake rather than for the multiplier it builds.
--
-- open_with_downpour answers the setting_blind pass and nothing else, so the
-- two halves never contend for the same context.
special("j_celesta_aquwa", "j_celesta_demenishki", {
    key = "aquwa_deme",
    config = { cards = 1, repetitions = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.cards, state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        local opened = open_with_downpour(card, context)
        if opened then return opened end

        if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
        if played_count(context) ~= state.cards then return end
        return {
            message = localize("k_again_ex"),
            repetitions = state.repetitions,
            card = card,
        }
    end,
})

-- Arielle + Jaws: Arielle is the suit Joker and Jaws is the one that grows, so
-- this grows on suits - three times as fast as Fufu does it.
--
-- Live off the deck rather than banked, which is what "in full deck" means
-- everywhere else here: a deck that loses its last Heart loses the multiplier
-- with it. Note what the pair gives up to do it - Arielle alone makes every
-- card every suit, and a replaced Arielle does not, which is the only reason
-- there is more than one suit left to count.
special("j_celesta_arielle", "j_celesta_jaws", {
    key = "arielle_jaws",
    config = { x_mult_gain = 1.5 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain,
                          1 + state.x_mult_gain
                              * CelestasMod.unique_suits_in_deck() } }
    end,

    calculate = function(def, card, context, state)
        if not context.joker_main then return end
        local x_mult = 1 + state.x_mult_gain * CelestasMod.unique_suits_in_deck()
        if x_mult > 1 then return { x_mult = x_mult } end
    end,
})

-- Deme + Saruei: Saruei pays for a Glass or Gash card that survives scoring,
-- and Deme is the one-card hand. Play one on its own and it cannot break, so
-- the payout is certain.
--
-- Through fix_probability, the way Ellie Minibot + Cerber stops the same two
-- rolls: a numerator of ZERO rather than nil, because nil would leave the roll
-- at whatever it was, and 0 is truthy in Lua so it survives the `or` chain
-- SMODS reads the fixed numerator through (utils.lua:2733).
special("j_celesta_demenishki", "j_celesta_saruei", {
    key = "deme_saruei",
    config = { cards = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.cards } }
    end,

    calculate = function(def, card, context, state)
        if not context.fix_probability then return end
        local id = context.identifier
        if not (id == "glass" or id == CelestasMod.GASH_BREAK_ID) then return end
        -- The hand, not the card: a one-card hand has exactly one roll in it,
        -- and it belongs to the card that was played.
        if played_count(context) ~= state.cards then return end
        return { numerator = 0 }
    end,
})


--------------------------------------------------------------------------------
-- Yuy and HeavenlyFather again
--------------------------------------------------------------------------------

-- Yuy + Nekrolina: what the merge is WORTH grows, rather than what it scores.
--
-- Banked in the pair's own state and handed to the sell-value hooks above
-- through sell_extra, so it is saved with the card and taken away with it -
-- and not written into ability.extra_value, which is the mistake Ruben
-- Sargasm was carrying and Grimmi + OverEzEggs writes up: that field sits one
-- level down card.ability, exactly where Cryptid's misprintize walks.
--
-- set_cost is called as it banks, because nothing else will: the price would
-- otherwise sit stale until something happened to the card.
special("j_celesta_yuy_ix", "j_celesta_nekrolina", {
    key = "yuy_nekrolina",
    config = { per_hand = 1, banked = 0 },

    loc_vars = function(def, card, state)
        return { vars = { state.per_hand, state.banked } }
    end,

    sell_extra = function(def, card, state)
        return state.banked or 0
    end,

    calculate = function(def, card, context, state)
        if not (context.before and not context.blueprint) then return end
        state.banked = (state.banked or 0) + state.per_hand
        if type(card.set_cost) == "function" then card:set_cost() end
        return {
            message = localize("k_val_up"),
            colour = G.C.MONEY,
            card = card,
        }
    end,
})

--- How many slots each copier gets in the shop pool while the pair is held.
--- One is what it already has, so this is the multiplier on its chances.
CelestasMod.HEAVENLY_BLUTO_WEIGHT = 4

-- HeavenlyFather + Bluto: Bluto is about Blueprint and Brainstorm, and this is
-- the shop agreeing to hand them over.
--
-- The same route items/decks.lua takes for the weather decks, and writes up at
-- length: get_current_pool builds a flat array where every candidate
-- contributes one slot - its key, or the string 'UNAVAILABLE' - and create_card
-- picks from it uniformly, resampling until it lands on something available
-- (common_events.lua:2449). So a key listed more than once is simply drawn more
-- often, and no other Joker's chances change in kind. Appending is also the
-- only edit that cannot break the array: the positions vanilla built keep
-- their meaning.
--
-- A copy is only appended for a Joker the pool ALREADY offers. The base pool
-- writes 'UNAVAILABLE' over one that is owned, banned or gated, and appending
-- its key regardless would put an owned Blueprint back in the shop - which is
-- exactly the check the base pool exists to make.
special("j_celesta_heavenlyfather", "j_celesta_bluto", {
    key = "heavenly_bluto",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state) end,
})

local celesta_bind_pool_ref = get_current_pool
if celesta_bind_pool_ref then
    function get_current_pool(_type, _rarity, _legendary, _append, ...)
        local pool, key = celesta_bind_pool_ref(_type, _rarity, _legendary,
                                                _append, ...)
        if _type ~= "Joker" or type(pool) ~= "table" then return pool, key end

        local holder = Bind.find_special("heavenly_bluto")
        if not (holder and not holder.debuff) then return pool, key end

        -- Guarded: a shop that cannot be built is a run that cannot continue,
        -- and a shop that is merely not weighted is a disappointment.
        local ok, err = pcall(function()
            local offered = {}
            for _, entry in ipairs(pool) do offered[entry] = true end

            for copier in pairs(CelestasMod.BLUTO_TARGETS or {}) do
                if offered[copier] then
                    for _ = 2, CelestasMod.HEAVENLY_BLUTO_WEIGHT do
                        pool[#pool + 1] = copier
                    end
                end
            end
        end)
        if not ok then
            CelestasMod.warn_once("heavenly_bluto_pool",
                ("HeavenlyFather + Bluto could not weight the shop: %s")
                    :format(tostring(err)))
        end

        return pool, key
    end
end


--------------------------------------------------------------------------------
-- Kael's rank, widened; Kumi's gold, kept; and four Bens
--------------------------------------------------------------------------------

do
    --- Declares a pair that makes every card count as `rank`.
    ---
    --- The rank is registered with CelestasMod.CARD_RANK_RULES rather than
    --- returned from calculate, because it is not a scoring effect at all:
    --- Card:get_id is asked by straights, pairs, held-in-hand Jokers and the
    --- deck viewer alike, long before any Joker is consulted. Kael answers it
    --- for faces (jokers/implemented.lua) and this answers it for everyone.
    ---
    --- The pair has no calculate of its own for the same reason. It is a
    --- passive the rank lookup reads, and there is nothing to copy.
    local function rank_pair(a, b, key, rank)
        special(a, b, {
            key = key,
            loc_vars = function(def, card, state) return { vars = {} } end,
            calculate = function(def, card, context, state) end,
        })
        -- `or {}` the way the Baulder Gang's suit rule is written: globals.lua
        -- declares the list, and a writer that reaches it first is a writer
        -- that still has to work.
        CelestasMod.CARD_RANK_RULES = CelestasMod.CARD_RANK_RULES or {}
        CelestasMod.CARD_RANK_RULES[#CelestasMod.CARD_RANK_RULES + 1] = function()
            if specials_held(key)[1] == nil then return nil end
            return rank
        end
    end

    -- Kairyu + Kael: Kael's 10 stops belonging to the face cards and becomes
    -- everybody's.
    rank_pair("j_celesta_kairyucrocodile", "j_celesta_kael", "kairyu_kael", 10)

    -- Giwi + Kael: the same, on the rank Giwi is about.
    rank_pair("j_celesta_giwi", "j_celesta_kael", "giwi_kael", 12)
end

-- Kumi + Crelly: Kumi eats the Gold cards, Crelly keeps what it is fed.
--
-- The destruction is Kumi's own, done here: a replacing pair speaks for both
-- halves, so the Kumi inside this one is not in play as itself and nothing
-- else would take the Gold cards - the pair would be about something that
-- never happens. Kumi + Maya is the same shape on Steel, and says so.
special("j_celesta_kumi", "j_celesta_crelly", {
    key = "kumi_crelly",
    config = { x_mult = 1, x_mult_gain = 0.2, dollars = 20, odds = 4 },

    loc_vars = function(def, card, state)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_kumi_crelly")
        return { vars = { state.x_mult_gain, numerator, denominator,
                          state.dollars, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.destroying_card and context.cardarea == G.play
            and not context.blueprint then
            local target = context.destroying_card
            if not SMODS.has_enhancement(target, "m_gold") then return end
            -- calculate_destroying_cards acts on `remove` without checking
            -- whether the card can actually go, so eternals are refused here
            -- or the deck keeps a card that was told to leave.
            if SMODS.is_eternal and SMODS.is_eternal(target) then return end

            state.x_mult = state.x_mult + state.x_mult_gain
            -- `remove` and `dollars` are both other_calculation_keys, so one
            -- table can destroy the card and pay out at once. The roll is per
            -- card destroyed, which is Kumi's own.
            local effect = {
                remove = true,
                card = card,
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { state.x_mult } },
                colour = G.C.MULT,
            }
            if SMODS.pseudorandom_probability(card, "celesta_bind_kumi_crelly",
                    1, state.odds, "celesta_bind_kumi_crelly") then
                effect.dollars = state.dollars
            end
            return effect
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

do
    --- The run flag that says a draw is already on its way.
    local BENCEPTION_BUSY = "celesta_benception_drawing"

    -- Benception: Ben, four times over.
    --
    -- Cryptid's Effarcire, which the same effect is asked of: first_hand_drawn
    -- is the moment the opening hand is on the table, and the rest of the deck
    -- follows it from inside a queued event, because the draw that raised the
    -- context has not finished yet.
    --
    -- The flag is Effarcire's `effarcire_buffer` and is here for its reason:
    -- SMODS.draw_cards raises first_hand_drawn itself every time it has drawn
    -- something (smods src/utils.lua:2660). It cannot loop today - the field
    -- that context is built from, current_round.any_hand_drawn, is set in the
    -- same function immediately after - but a draw of the whole deck is not
    -- something to leave resting on that ordering.
    --
    -- Nothing is done about the hand's card limit. The cards go past it, which
    -- is what drawing the deck means, and card_limit is a DERIVED number under
    -- SMODS - writing to it is exactly the bug Lab Brats was carrying.
    quad({
        key = "quad_benception",
        members = { "j_celesta_ben", "j_celesta_ben",
                    "j_celesta_ben", "j_celesta_ben" },

        loc_vars = function(def, card, state)
            return { vars = {} }
        end,

        calculate = function(def, card, context, state)
            if not (context.first_hand_drawn and not context.blueprint) then return end
            if not (G.GAME and not G.GAME[BENCEPTION_BUSY]) then return end
            if not (G.deck and G.deck.cards and #G.deck.cards > 0) then return end

            G.GAME[BENCEPTION_BUSY] = true
            G.E_MANAGER:add_event(Event {
                func = function()
                    SMODS.draw_cards(#G.deck.cards)
                    G.E_MANAGER:add_event(Event {
                        func = function()
                            G.GAME[BENCEPTION_BUSY] = nil
                            return true
                        end,
                    })
                    return true
                end,
            })
        end,
    })
end


--------------------------------------------------------------------------------
-- The discards spent and unspent
--------------------------------------------------------------------------------

-- Kairyu + AiCandii: AiCandii is paid for the discards it did NOT need, and
-- Kairyu is the Joker that wants them spent - so bound, the payment moves onto
-- the ones that were.
--
-- discards_used rather than the complement of discards_left. The two are not
-- complements while anything is handing discards out mid-round, and the one
-- this counts is the one the card names.
special("j_celesta_kairyucrocodile", "j_celesta_aicandii", {
    key = "kairyu_aicandii",
    config = { mult = 0, mult_gain = 4 },

    loc_vars = function(def, card, state)
        return { vars = { state.mult_gain, state.mult } }
    end,

    calculate = function(def, card, context, state)
        -- main_eval is the once-per-round Joker pass; without it this would
        -- fire again for every card the end-of-round pass looks at.
        if context.end_of_round and context.main_eval and not context.blueprint then
            local round = G.GAME and G.GAME.current_round
            local used = (round and round.discards_used) or 0
            if used <= 0 then return end
            state.mult = state.mult + state.mult_gain * used
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

-- AiCandii + Shiabun: one more card to pick for every discard still unspent.
--
-- The limit itself is granted through SELECTION_PAIRS above rather than from
-- here, which is where VchiBan's identical half is granted from and for its
-- reason: that pass owns the running total this mod has handed out, and it is
-- what gives the limit back when the merge stops being in the row. There is
-- nothing left for calculate to do.
special("j_celesta_aicandii", "j_celesta_shiabun", {
    key = "aicandii_shiabun",

    loc_vars = function(def, card, state)
        local round = G.GAME and G.GAME.current_round
        return { vars = { (round and round.discards_left) or 0 } }
    end,

    calculate = function(def, card, context, state) end,
})

-- AiCandii + Rosedoodle: AiCandii's unused discards, paid in a multiplier
-- rather than flat Mult.
special("j_celesta_aicandii", "j_celesta_rosedoodle", {
    key = "aicandii_rosedoodle",
    config = { x_mult = 1, x_mult_gain = 0.25 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.end_of_round and context.main_eval and not context.blueprint then
            local round = G.GAME and G.GAME.current_round
            local unused = (round and round.discards_left) or 0
            if unused <= 0 then return end
            state.x_mult = state.x_mult + state.x_mult_gain * unused
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

-- AiCandii + Ironmouse: the same count again, in Ironmouse's exponent.
--
-- pow_after and ironmouse_pays are how every Ironmouse pair in this file
-- scales and scores: the first rounds the running total while it is still a
-- plain number, and the second is the one place that says ^Mult needs Talisman
-- rather than silently doing nothing.
special("j_celesta_aicandii", "j_celesta_ironmouse", {
    key = "aicandii_ironmouse",
    config = { e_mult = 1, e_mult_gain = 0.05 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_mult_gain, state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.end_of_round and context.main_eval and not context.blueprint then
            local round = G.GAME and G.GAME.current_round
            local unused = (round and round.discards_left) or 0
            if unused <= 0 then return end
            state.e_mult = pow_after(state.e_mult, state.e_mult_gain * unused)
            return {
                message = localize { type = "variable", key = "celesta_powmult",
                                     vars = { state.e_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main then
            return ironmouse_pays("aicandii_ironmouse", "AiCandii + Ironmouse",
                                  state.e_mult)
        end
    end,
})

--------------------------------------------------------------------------------
-- Taehoongie's hand, and Arar's
--------------------------------------------------------------------------------

do
    --- The hand Taehoongie levels up, and the one all four of these watch for.
    local FIVE_OF_A_KIND = "Five of a Kind"

    --- Liffeh's own 1 in 4.
    ---
    --- Spelled out rather than read from CelestasMod.LIFFEH_ODDS, which
    --- jokers/implemented.lua sets after this file has finished loading - a
    --- config built from it here would be built from nil.
    local LIFFEH_ODDS = 4

    --- True when the played hand CONTAINS a Five of a Kind.
    ---
    --- context.poker_hands lists every hand the played cards make rather than
    --- only the one the game named, which is the question vanilla's own
    --- "contains" Jokers ask. Every entry in that table exists whether or not
    --- the hand was made - it is built with all its keys and left empty - so
    --- what is asked is whether the entry has anything in it.
    local function contains_five(context)
        local hands = context.poker_hands
        local made = hands and hands[FIVE_OF_A_KIND]
        return (made ~= nil and next(made) ~= nil) and true or false
    end

    --- The Tarot that makes `enhancement`, if the run has one.
    ---
    --- Found by asking every Tarot what it converts to, rather than from a
    --- table of pairs: mod_conv is what an enhancement Tarot IS - vanilla's
    --- Card:use_consumeable applies whatever centre that field names
    --- (card.lua:1401), and Arar reads the same field the other way round. So
    --- vanilla's eight, this mod's four and any other mod's are all understood
    --- without naming one, and an enhancement no Tarot makes simply answers
    --- nil, which is what "if one exists" says.
    ---
    --- Sorted, because pairs() walks a table in whatever order it likes and
    --- two Tarots making the same enhancement must not depend on that order.
    local function tarot_for_enhancement(enhancement)
        if not (enhancement and G.P_CENTERS) then return nil end
        local found = {}
        for key, center in pairs(G.P_CENTERS) do
            if center.set == "Tarot" and center.config
                and center.config.mod_conv == enhancement then
                found[#found + 1] = key
            end
        end
        table.sort(found)
        return found[1]
    end

    --- Every unenhanced card held in hand that nothing has claimed this pass.
    ---
    --- c_base is the unenhanced playing-card centre, and celesta_arar_claimed
    --- is Arar's own flag: set_ability is deferred into an event, so a copier
    --- evaluating in the same pass would still see a claimed card as
    --- unenhanced and take it again.
    local function unenhanced_held()
        local out = {}
        for _, held in ipairs((G.hand and G.hand.cards) or {}) do
            if held.config.center == G.P_CENTERS.c_base
                and not held.celesta_arar_claimed then
                out[#out + 1] = held
            end
        end
        return out
    end

    --- Gives `target` an enhancement and says which one, or nil.
    ---
    --- Arar's own choice: the enhancement of a Tarot sitting in the first
    --- consumable slot while the run still offers it, and a roll otherwise.
    --- poll_enhancement respects the run's current pool, so this never hands
    --- out one a Challenge or a Deck has banned.
    local function enhance(target, seed)
        local enhancement = (CelestasMod.arar_forced and CelestasMod.arar_forced())
            or SMODS.poll_enhancement { key = seed, guaranteed = true }
        if not (enhancement and G.P_CENTERS[enhancement]) then return nil end

        target.celesta_arar_claimed = true
        G.E_MANAGER:add_event(Event {
            func = function()
                target:set_ability(G.P_CENTERS[enhancement], nil, true)
                target:juice_up(0.3, 0.5)
                target.celesta_arar_claimed = nil
                return true
            end
        })
        return enhancement
    end

    --- Enhances every unenhanced card held in hand; returns how many.
    local function enhance_all_held(seed)
        local touched = 0
        for _, held in ipairs(unenhanced_held()) do
            if enhance(held, seed) then touched = touched + 1 end
        end
        return touched
    end

    --- Each played card keeps `amount` Chips; returns how many were paid.
    ---
    --- perma_bonus is vanilla's own permanent Chip store - what Hiker writes to
    --- and what get_chip_bonus reads back - so the Chips are part of what the
    --- card is worth from here on rather than for this hand.
    ---
    --- The FULL hand rather than the scoring one: "each played card" is every
    --- card that went out, and a Five of a Kind played alongside something else
    --- sent that card out too.
    local function pay_played(context, amount)
        local touched = 0
        for _, played in ipairs(context.full_hand or {}) do
            played.ability.perma_bonus = (played.ability.perma_bonus or 0) + amount
            played:juice_up(0.3, 0.5)
            touched = touched + 1
        end
        return touched
    end

    --- Liffeh's roll, paying out a random consumable. True when one was made.
    ---
    --- Room is asked for first and reserved through consumeable_buffer, which
    --- is vanilla's way of holding a slot across the event that fills it - the
    --- card here is rolled for once per scoring card, so two of them in one
    --- hand would otherwise race for one slot.
    ---
    --- The set is picked from the run's own registered consumable types rather
    --- than a fixed three, which is the difference between "any consumable" and
    --- "one of the three vanilla ones".
    local function maybe_consumable(card, odds, seed)
        if not bind_consumable_room() then return false end
        if not SMODS.pseudorandom_probability(card, seed, 1, odds, seed) then
            return false
        end

        local set = any_consumable_set(seed)
        G.GAME.consumeable_buffer = (G.GAME.consumeable_buffer or 0) + 1
        G.E_MANAGER:add_event(Event {
            trigger = "before", delay = 0.0,
            func = function()
                local made = SMODS.add_card { set = set, key_append = seed }
                if made then made:juice_up(0.3, 0.5) end
                G.GAME.consumeable_buffer =
                    math.max(0, (G.GAME.consumeable_buffer or 1) - 1)
                return true
            end,
        })
        return true
    end

    -- Arar + Liffeh: Arar's enhancement moved off the start of the round and
    -- onto every hand played, and Liffeh's Negative copy of the Tarot that
    -- would have made it.
    --
    -- context.before, because "held in hand" means the cards that were NOT
    -- played and they are only still in G.hand until the hand scores - the
    -- same moment every held-in-hand pair in this file reads.
    --
    -- Negative, so the copy brings its own slot and there is no room to run out
    -- of. Liffeh's own copy needs no consumeable_buffer for that reason and
    -- neither does this.
    special("j_celesta_arar", "j_celesta_liffeh", {
        key = "arar_liffeh",
        config = { odds = LIFFEH_ODDS },

        loc_vars = function(def, card, state)
            local n, d = SMODS.get_probability_vars(
                card, 1, state.odds, "celesta_bind_arar_liffeh")
            return { vars = { n, d } }
        end,

        calculate = function(def, card, context, state)
            if not (context.before and not context.blueprint) then return end

            local candidates = unenhanced_held()
            if #candidates == 0 then return end
            local target = pseudorandom_element(candidates,
                pseudoseed("celesta_bind_arar_liffeh_pick"))
            local enhancement = enhance(target, "celesta_bind_arar_liffeh_enh")
            if not enhancement then return end

            local tarot = nil
            if SMODS.pseudorandom_probability(card, "celesta_bind_arar_liffeh",
                    1, state.odds, "celesta_bind_arar_liffeh") then
                tarot = tarot_for_enhancement(enhancement)
            end

            if tarot then
                G.E_MANAGER:add_event(Event {
                    trigger = "before", delay = 0.0,
                    func = function()
                        local made = SMODS.add_card { key = tarot,
                            area = G.consumeables, edition = "e_negative" }
                        if made then made:juice_up(0.3, 0.5) end
                        return true
                    end,
                })
            end

            return {
                message = tarot and localize("k_plus_tarot")
                    or localize("k_upgrade_ex"),
                colour = tarot and G.C.PURPLE or G.C.SECONDARY_SET.Enhanced,
                card = card,
            }
        end,
    })

    -- Arar + Taehoongie: Taehoongie's hand says when, Arar says what happens.
    --
    -- Arar's cards, which are the ones HELD IN HAND: that is what Arar is about
    -- on its own and in every other pair of its, and the trigger moving to the
    -- played hand does not move what it acts on.
    special("j_celesta_arar", "j_celesta_taehoongie", {
        key = "arar_taehoongie",

        loc_vars = function(def, card, state)
            return { vars = { localize(FIVE_OF_A_KIND, "poker_hands") } }
        end,

        calculate = function(def, card, context, state)
            if not (context.before and not context.blueprint) then return end
            if not contains_five(context) then return end
            if enhance_all_held("celesta_bind_arar_tae_enh") == 0 then return end
            return {
                message = localize("k_upgrade_ex"),
                colour = G.C.SECONDARY_SET.Enhanced, card = card,
            }
        end,
    })

    -- Jaws + Taehoongie: Jaws keeps Chips off the cards it eats; here the cards
    -- keep them instead, and nothing is eaten.
    special("j_celesta_jaws", "j_celesta_taehoongie", {
        key = "jaws_taehoongie",
        config = { chips = 25 },

        loc_vars = function(def, card, state)
            return { vars = { localize(FIVE_OF_A_KIND, "poker_hands"),
                              state.chips } }
        end,

        calculate = function(def, card, context, state)
            if not (context.before and not context.blueprint) then return end
            if not contains_five(context) then return end
            if pay_played(context, state.chips) == 0 then return end
            return {
                message = localize { type = "variable", key = "a_chips",
                                     vars = { state.chips } },
                colour = G.C.CHIPS, card = card,
            }
        end,
    })

    -- Liffeh + Taehoongie: Liffeh's roll, off the Tarots it copies and onto the
    -- cards that score.
    special("j_celesta_liffeh", "j_celesta_taehoongie", {
        key = "liffeh_taehoongie",
        config = { odds = LIFFEH_ODDS },

        loc_vars = function(def, card, state)
            local n, d = SMODS.get_probability_vars(
                card, 1, state.odds, "celesta_bind_liffeh_tae")
            return { vars = { n, d } }
        end,

        calculate = function(def, card, context, state)
            if not (context.individual and context.cardarea == G.play
                and context.other_card and not context.blueprint) then return end
            if not maybe_consumable(card, state.odds,
                    "celesta_bind_liffeh_tae") then return end
            return {
                message = localize("celesta_plus_consumable"),
                colour = G.C.PURPLE, card = card,
            }
        end,
    })

    -- The Big Bazoinga Boys: Arar, Jaws, Liffeh and Taehoongie.
    --
    -- The three Taehoongie pairs at once, which is what the group is: its hand
    -- is the trigger, and the other three each bring what they do to it.
    quad({
        key = "quad_bazoinga",
        members = { "j_celesta_arar", "j_celesta_jaws",
                    "j_celesta_liffeh", "j_celesta_taehoongie" },
        config = { chips = 25, odds = LIFFEH_ODDS },

        loc_vars = function(def, card, state)
            local n, d = SMODS.get_probability_vars(
                card, 1, state.odds, "celesta_bind_quad_bazoinga")
            return { vars = { localize(FIVE_OF_A_KIND, "poker_hands"),
                              state.chips, n, d } }
        end,

        calculate = function(def, card, context, state)
            if context.before and not context.blueprint
                and contains_five(context) then
                -- Both halves, from one pass: they are two things the same
                -- hand causes, not two passes.
                local enhanced = enhance_all_held("celesta_bind_quad_bazoinga_enh")
                local paid = pay_played(context, state.chips)
                if enhanced + paid == 0 then return end
                return {
                    message = localize { type = "variable", key = "a_chips",
                                         vars = { state.chips } },
                    colour = G.C.CHIPS, card = card,
                }
            end

            -- ...and the roll, which is not about the Five of a Kind at all.
            if context.individual and context.cardarea == G.play
                and context.other_card and not context.blueprint then
                if not maybe_consumable(card, state.odds,
                        "celesta_bind_quad_bazoinga") then return end
                return {
                    message = localize("celesta_plus_consumable"),
                    colour = G.C.PURPLE, card = card,
                }
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- Hime's Eutrophic cards
--------------------------------------------------------------------------------

do
    --- The Eutrophic cards held in hand, which is what Hime is about.
    ---
    --- Debuffed ones are left out, the way Zentreya's Steel count leaves them
    --- out: a debuffed card does nothing, and paying for it would be paying for
    --- a card that is not paying.
    ---
    --- The key is read at call time rather than at load: enhancements/ is
    --- loaded after this file, so CelestasMod.ENHANCEMENT_KEYS does not exist
    --- yet while this is being read.
    local function eutrophic_in_hand()
        local key = (CelestasMod.ENHANCEMENT_KEYS or {}).Eutrophic
        if not key then return 0 end
        local n = 0
        for _, held in ipairs((G.hand and G.hand.cards) or {}) do
            if not held.debuff and SMODS.has_enhancement(held, key) then
                n = n + 1
            end
        end
        return n
    end

    --- ...and the ones in the run's whole deck.
    local function eutrophic_in_deck()
        return enhanced_in_deck((CelestasMod.ENHANCEMENT_KEYS or {}).Eutrophic)
    end

    -- Hime + Projekt Melody: Hime's held Eutrophic cards, paid for rather than
    -- scored.
    --
    -- context.before, for the reason Hime's own timing is what it is: "held in
    -- hand" means the cards that were not played, and they are only still in
    -- G.hand until the hand scores.
    special("j_celesta_hime", "j_celesta_projektmelody", {
        key = "hime_melody",
        config = { dollars = 3 },

        loc_vars = function(def, card, state)
            return { vars = { state.dollars } }
        end,

        calculate = function(def, card, context, state)
            if not (context.before and not context.blueprint) then return end
            local held = eutrophic_in_hand()
            if held <= 0 then return end
            return { dollars = state.dollars * held, card = card }
        end,
    })

    -- Hime + Nyanners: Nyanners counts the row, and this counts the deck for
    -- the card Hime is about.
    --
    -- Counted live rather than banked, which is what Nyanners does and what "in
    -- your full deck" means everywhere in this file: converting the last
    -- Eutrophic card away takes the Chips back rather than leaving them earned.
    special("j_celesta_hime", "j_celesta_nyanners", {
        key = "hime_nyanners",
        config = { chips = 30 },

        loc_vars = function(def, card, state)
            return { vars = { state.chips,
                              state.chips * eutrophic_in_deck() } }
        end,

        calculate = function(def, card, context, state)
            if not context.joker_main then return end
            local total = state.chips * eutrophic_in_deck()
            if total <= 0 then return end
            return { chips = total }
        end,
    })
end


--------------------------------------------------------------------------------
-- Mogu and SunnySplosion
--------------------------------------------------------------------------------

-- Mogu + SunnySplosion: the same move, the other way up.
--
-- SunnySplosion's own downgrade stops of its own accord and needs no seam: it
-- lives in that Joker's calculate, and a replacing pair is never asked it.
--
-- The body is SunnySplosion's own with the direction as its argument, so the
-- two cannot come to disagree about which cards are moved or about what "if
-- possible" means. It is reached through CelestasMod because
-- jokers/implemented.lua is loaded after this file - the function is there by
-- the time anything calls it, and not while this is being read.
--
-- Not guarded against its absence. Bind already pcalls every special's
-- calculate and logs which pair failed, and a guard here would return silently
-- instead - so a body that really had gone missing would look like a pair that
-- simply does nothing.
special("j_celesta_mogu", "j_celesta_sunnysplosion", {
    key = "mogu_sunnysplosion",

    loc_vars = function(def, card, state)
        return { vars = { state.amount } }
    end,

    config = { amount = 1 },

    calculate = function(def, card, context, state)
        return CelestasMod.sunny_shift(card, context, state.amount)
    end,
})


--------------------------------------------------------------------------------
-- Steel, Star Seals, the ice, and the stone family
--------------------------------------------------------------------------------

-- Henya + Zentreya: Henya is paid per trigger and Zentreya is the Steel Joker,
-- so a Steel card is what pays.
--
-- Every trigger, not only the retriggers Henya alone wants: a retrigger raises
-- the individual pass again, so Henya's own reading is still what happens - a
-- Steel card retriggered three times pays three times - and the first trigger
-- pays too, which is what "every time" says.
--
-- Both areas, because a Steel card does its work held in hand and Zentreya
-- scores it when played. `not context.end_of_round` is the guard every
-- held-in-hand reader in this file carries: Steamodded raises individual over
-- G.hand again at the cash-out, for the Gold cards paying out.
special("j_celesta_henya", "j_celesta_zentreya", {
    key = "henya_zentreya",
    config = { dollars = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.other_card
            and not context.end_of_round
            and (context.cardarea == G.play or context.cardarea == G.hand)) then
            return
        end
        local other = context.other_card
        -- A debuffed card does nothing, and paying for it would pay for a card
        -- that is not paying.
        if other.debuff then return end
        if not SMODS.has_enhancement(other, "m_steel") then return end
        return { dollars = state.dollars, card = card }
    end,
})

-- Zentreya + CottontailVA: CottontailVA makes the Star Seals and Zentreya is
-- the multiplier, so the seal is what carries it.
--
-- card.seal holds the PREFIXED key, which is CelestasMod.SEAL_KEYS.Star: every
-- other seal test in this file reads it that way.
--
-- The multiplier lands on the sealed CARD rather than on the Joker, which is
-- where a per-card effect belongs and what makes the popup appear over the
-- card that earned it.
special("j_celesta_zentreya", "j_celesta_cottontail", {
    key = "zentreya_cottontail",
    config = { odds = 2, x_mult = 1.75 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, 1, state.odds, "celesta_bind_zentreya_cottontail")
        return { vars = { n, d, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play
            and context.other_card) then return end
        local star = (CelestasMod.SEAL_KEYS or {}).Star
        if not (star and context.other_card.seal == star) then return end
        if not SMODS.pseudorandom_probability(card,
                "celesta_bind_zentreya_cottontail", 1, state.odds,
                "celesta_bind_zentreya_cottontail") then return end
        return { x_mult = state.x_mult, card = context.other_card }
    end,
})

-- Kairyu + Shiabun: one more card to pick for every discard spent.
--
-- The limit itself is granted through SELECTION_PAIRS above rather than from
-- here, which is where AiCandii + Shiabun's and VchiBan's are granted from and
-- for their reason: that pass owns the running total this mod has handed out,
-- and it is what gives the limit back when the merge stops being in the row.
special("j_celesta_kairyucrocodile", "j_celesta_shiabun", {
    key = "kairyu_shiabun",

    loc_vars = function(def, card, state)
        local round = G.GAME and G.GAME.current_round
        return { vars = { (round and round.discards_used) or 0 } }
    end,

    calculate = function(def, card, context, state) end,
})

-- Kairyu + Ironmouse: a step in the exponent for every discard spent.
--
-- pre_discard rather than discard, which is Kairyu's own distinction:
-- context.discard arrives once per discarded CARD, and this counts the discard
-- ACTION. `hook` marks the discards a Joker forces, and vanilla does not count
-- those against the round - so neither does Kairyu, and neither does this.
--
-- pow_after and ironmouse_pays are how every Ironmouse pair here scales and
-- scores: the first rounds the running total while it is still a plain number,
-- and the second is the one place that says ^Mult needs Talisman rather than
-- silently doing nothing.
special("j_celesta_kairyucrocodile", "j_celesta_ironmouse", {
    key = "kairyu_ironmouse",
    config = { e_mult = 1, e_mult_gain = 0.04 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_mult_gain, state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        if context.pre_discard and not context.blueprint and not context.hook then
            state.e_mult = pow_after(state.e_mult, state.e_mult_gain)
            return {
                message = localize { type = "variable", key = "celesta_powmult",
                                     vars = { state.e_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main then
            return ironmouse_pays("kairyu_ironmouse", "Kairyu + Ironmouse",
                                  state.e_mult)
        end
    end,
})

do
    --- Thaws one frozen Joker at random, and says whether it found one.
    ---
    --- Through CelestasMod.thaw rather than by clearing the field: melting has
    --- one definition (editions/frozen.lua), and Smug Alana strips a sticker as
    --- the ice comes off - a pair that cleared the field itself would quietly
    --- stop paying that.
    ---
    --- The whole row, this card included: a frozen merge is a frozen Joker, and
    --- there is no reason for it to be the one thing the melt cannot reach.
    local function thaw_one(seed)
        if type(CelestasMod.thaw) ~= "function" then return false end
        local frozen = {}
        for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
            if CelestasMod.is_frozen and CelestasMod.is_frozen(held) then
                frozen[#frozen + 1] = held
            end
        end
        if #frozen == 0 then return false end
        CelestasMod.thaw(pseudorandom_element(frozen, pseudoseed(seed)))
        return true
    end

    --- The melt, said the way the freeze itself says it.
    local function melted(card)
        return { message = localize("celesta_melted"), colour = G.C.BLUE,
                 card = card }
    end

    -- Kairyu + Vulpixie: Vulpixie is the Joker that lives with the ice, and
    -- Kairyu is the one that spends discards - so a discard is what melts it.
    --
    -- pre_discard and the `hook` test, for Kairyu's reason above: this counts
    -- the discard ACTION, and a discard a Joker forced is not one the round
    -- spent.
    special("j_celesta_kairyucrocodile", "j_celesta_vulpixie", {
        key = "kairyu_vulpixie",

        loc_vars = function(def, card, state)
            return { vars = {} }
        end,

        calculate = function(def, card, context, state)
            if not (context.pre_discard and not context.blueprint
                and not context.hook) then return end
            if not thaw_one("celesta_bind_kairyu_vulpixie") then return end
            return melted(card)
        end,
    })

    -- Giwi + Vulpixie: the same melt, on the rank Giwi is about.
    --
    -- Asked through get_id, which is what every rank question in this mod
    -- reads - so what Kael says a card counts as is what counts here too.
    special("j_celesta_giwi", "j_celesta_vulpixie", {
        key = "giwi_vulpixie",

        loc_vars = function(def, card, state)
            return { vars = {} }
        end,

        calculate = function(def, card, context, state)
            if not (context.individual and context.cardarea == G.play
                and context.other_card and not context.blueprint) then return end
            local other = context.other_card
            if other.debuff then return end
            if not (other.get_id and other:get_id() == 12) then return end
            if not thaw_one("celesta_bind_giwi_vulpixie") then return end
            return melted(card)
        end,
    })

    --- The stone family: vanilla's Stone and the three this mod weathered out
    --- of it.
    ---
    --- Asked through has_enhancement rather than off the centre, which is what
    --- every enhancement question in this file does: an enhancement a card is
    --- standing in for still counts. The mod's three are read off
    --- ENHANCEMENT_KEYS at call time, since enhancements/ is loaded after this
    --- file.
    local STONE_FAMILY = { "Limestone", "Sandstone", "Scoria" }

    local function stone_like(other)
        if SMODS.has_enhancement(other, "m_stone") then return true end
        local keys = CelestasMod.ENHANCEMENT_KEYS or {}
        for _, name in ipairs(STONE_FAMILY) do
            local key = keys[name]
            if key and SMODS.has_enhancement(other, key) then return true end
        end
        return false
    end

    -- Jax + Jowol: Jax retriggers Stone and Limestone, Jowol is the Stone card
    -- Joker, and together the retrigger covers every stone this mod has -
    -- Sandstone and Scoria included.
    special("j_celesta_jaxvtuber", "j_celesta_jowol", {
        key = "jax_jowol",
        config = { repetitions = 1 },

        loc_vars = function(def, card, state)
            return { vars = { state.repetitions } }
        end,

        calculate = function(def, card, context, state)
            if not (context.repetition and context.cardarea == G.play
                and context.other_card) then return end
            if not stone_like(context.other_card) then return end
            return {
                message = localize("k_again_ex"),
                repetitions = state.repetitions,
                card = card,
            }
        end,
    })
end


--------------------------------------------------------------------------------
-- FeFe's Hearts, Vexoria's Spades
--------------------------------------------------------------------------------
--
-- FeFe turns the scoring cards into Hearts and Vexoria turns them into Spades,
-- so a merge of either with something else is that suit asked a second
-- question: what it is worth destroyed, discarded, scored, or counted as.
--
-- The two that rewrite what a suit IS go through the seams in globals.lua
-- rather than hooking anything themselves, for the reason those exist: a
-- replacing pair speaks for both halves, so the FeFe inside one is not in play
-- as itself and a rule written in terms of finding a FeFe would switch off the
-- line on the pair's own card.

do

local HEARTS, SPADES = "Hearts", "Spades"

-- Declared before they are written to, the way every seam in this file is:
-- globals.lua owns them, and this file is loaded on its own by the suites.
CelestasMod.CARD_SUIT_RULES = CelestasMod.CARD_SUIT_RULES or {}
CelestasMod.SUIT_MATCH_RULES = CelestasMod.SUIT_MATCH_RULES or {}

--- How many of `cards` are of `suit`.
---
--- Through is_suit rather than off base.suit, so a Wild card counts and so
--- does anything else this mod has widened - including these merges' own
--- rules, which is deliberate: a pair that says every card is a Spade and a
--- pair that pays for Spades destroyed should agree about what a Spade is.
local function count_suit(cards, suit)
    local n = 0
    for _, card in ipairs(cards or {}) do
        if card and card.is_suit and card:is_suit(suit) then n = n + 1 end
    end
    return n
end

--- The cards a destruction pass took, or nothing.
---
--- remove_playing_cards is raised once after the pass with every card that
--- died, whatever killed it, which is where vanilla Caino counts its face
--- cards. Counting there rather than hooking any one destroyer means these
--- merges are paid by a Boss Blind, a Joker or a consumable alike.
local function destroyed_cards(context)
    if not (context.remove_playing_cards and not context.blueprint) then return nil end
    return context.removed or {}
end

-- FeFe + Projekt Melody: Projekt Melody's payout, earned by the Hearts thrown
-- away rather than by surviving a round.
--
-- The leftover is kept rather than cleared at the end of the round: it is
-- "every 2 Hearts", not "every 2 Hearts in a round", and a player who discards
-- three and then one has discarded four.
local function discard_pair(a, b, key, suit)
    special(a, b, {
        key = key,
        config = { dollars = 3, per = 2, discarded = 0 },

        loc_vars = function(def, card, state)
            return { vars = { state.dollars, state.per } }
        end,

        calculate = function(def, card, context, state)
            -- context.discard arrives once per discarded card, which is what
            -- makes counting them one at a time correct.
            if not (context.discard and not context.blueprint) then return end
            local other = context.other_card
            if not (other and other.is_suit and other:is_suit(suit)) then return end

            state.discarded = state.discarded + 1
            if state.discarded < state.per then return end
            state.discarded = state.discarded - state.per
            return { dollars = state.dollars, card = card }
        end,
    })
end

discard_pair("j_celesta_fefe", "j_celesta_projektmelody", "fefe_melody", HEARTS)
-- Vexoria + Projekt Melody: the same, for the other suit.
discard_pair("j_celesta_vexoria", "j_celesta_projektmelody", "vexoria_melody", SPADES)

-- FeFe + Ironmouse: Ironmouse's ^Mult, fed by the Hearts that are destroyed.
special("j_celesta_fefe", "j_celesta_ironmouse", {
    key = "fefe_ironmouse",
    config = { e_mult = 1, e_mult_gain = 0.04 },

    loc_vars = function(def, card, state)
        return { vars = { state.e_mult_gain, state.e_mult } }
    end,

    calculate = function(def, card, context, state)
        local removed = destroyed_cards(context)
        if removed then
            local hearts = count_suit(removed, HEARTS)
            if hearts > 0 then
                -- One raise for the lot rather than one per card: the exponent
                -- adds either way, and a single message reads as the hand it
                -- was earned by.
                state.e_mult = pow_after(state.e_mult, state.e_mult_gain * hearts)
                return {
                    message = localize { type = "variable", key = "celesta_powmult",
                                         vars = { state.e_mult } },
                    colour = G.C.MULT, card = card,
                }
            end
            return
        end

        if context.joker_main then
            return ironmouse_pays("fefe_ironmouse", "FeFe + Ironmouse", state.e_mult)
        end
    end,
})

-- FeFe + Silvervale: Silvervale's growing XMult, counted in Hearts destroyed
-- rather than in Rare Jokers sold.
special("j_celesta_fefe", "j_celesta_silvervale", {
    key = "fefe_silvervale",
    config = { x_mult = 1, x_mult_gain = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.x_mult_gain, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        local removed = destroyed_cards(context)
        if removed then
            local hearts = count_suit(removed, HEARTS)
            if hearts > 0 then
                state.x_mult = state.x_mult + state.x_mult_gain * hearts
                return {
                    message = localize { type = "variable", key = "a_xmult",
                                         vars = { state.x_mult } },
                    colour = G.C.MULT, card = card,
                }
            end
            return
        end

        if context.joker_main and state.x_mult > 1 then
            return { x_mult = state.x_mult }
        end
    end,
})

-- FeFe + Zentreya: Zentreya's XMult, on the suit FeFe makes rather than on
-- Steel Cards, and on a roll rather than every time.
special("j_celesta_fefe", "j_celesta_zentreya", {
    key = "fefe_zentreya",
    config = { odds = 4, numerator = 3, x_mult = 1.75 },

    loc_vars = function(def, card, state)
        local n, d = SMODS.get_probability_vars(
            card, state.numerator, state.odds, "celesta_bind_fefe_zentreya")
        return { vars = { n, d, state.x_mult } }
    end,

    calculate = function(def, card, context, state)
        if not (context.individual and context.cardarea == G.play) then return end
        local other = context.other_card
        if not (other and other.is_suit and other:is_suit(HEARTS)) then return end
        if not SMODS.pseudorandom_probability(card, "celesta_bind_fefe_zentreya",
                state.numerator, state.odds, "celesta_bind_fefe_zentreya") then
            return
        end
        return { x_mult = state.x_mult, card = card }
    end,
})

-- Vexoria + Vexoria: two of the same, so the suit stops being something the
-- scoring cards are turned into and becomes what every card is.
--
-- The payout counts Spades through is_suit, which the rule below has just made
-- every card - so every card destroyed pays. That is the first line of the
-- pair being true rather than a second rule about it.
special("j_celesta_vexoria", "j_celesta_vexoria", {
    key = "vexoria_vexoria",
    config = { dollars = 1, dollars_gain = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.dollars, state.dollars_gain } }
    end,

    calculate = function(def, card, context, state)
        local removed = destroyed_cards(context)
        if not removed then return end

        local paid = 0
        for _, card_removed in ipairs(removed) do
            if card_removed and card_removed.is_suit and card_removed:is_suit(SPADES) then
                -- Counted one at a time, because each one raises what the next
                -- is worth.
                paid = paid + state.dollars
                state.dollars = state.dollars + state.dollars_gain
            end
        end
        if paid <= 0 then return end
        return { dollars = paid, card = card }
    end,
})

CelestasMod.CARD_SUIT_RULES[#CelestasMod.CARD_SUIT_RULES + 1] = function()
    if specials_held("vexoria_vexoria")[1] == nil then return nil end
    return SPADES
end

-- FeFe + Vexoria: one turns the scoring cards into Hearts and the other into
-- Spades, so together the two suits stop being different.
--
-- A widening, not a forcing: a Heart is still a Heart and a Spade still a
-- Spade, and each is now also the other. Read off base.suit rather than
-- through is_suit, which is what this rule is being asked inside.
special("j_celesta_fefe", "j_celesta_vexoria", {
    key = "fefe_vexoria",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state) end,
})

local HEART_OR_SPADE = { [HEARTS] = true, [SPADES] = true }
CelestasMod.SUIT_MATCH_RULES[#CelestasMod.SUIT_MATCH_RULES + 1] = function(card, suit)
    if specials_held("fefe_vexoria")[1] == nil then return false end
    local own = card and card.base and card.base.suit
    return (HEART_OR_SPADE[own] and HEART_OR_SPADE[suit]) and true or false
end

-- FeFe + Momo: Momo calls every hand a Flush and FeFe makes the suit, so the
-- Hearts are what every Flush is made of.
--
-- Only while a Flush is being worked out. Everywhere else a Heart is a Heart,
-- which is what keeps this from being Arielle.
special("j_celesta_fefe", "j_celesta_momo", {
    key = "fefe_momo",

    loc_vars = function(def, card, state)
        return { vars = {} }
    end,

    calculate = function(def, card, context, state) end,
})

CelestasMod.SUIT_MATCH_RULES[#CelestasMod.SUIT_MATCH_RULES + 1] = function(card, suit, flush_calc)
    if not flush_calc then return false end
    if specials_held("fefe_momo")[1] == nil then return false end
    return (card and card.base and card.base.suit) == HEARTS
end

-- Shenpai + Vulpixie: Shenpai hands out Gold Seals and Vulpixie is the one
-- that keeps working through a freeze, so the pair is what those seals are
-- worth in the weather Vulpixie was written for.
special("j_celesta_shenpai", "j_celesta_vulpixie", {
    key = "shenpai_vulpixie",
    config = { repetitions = 3 },

    loc_vars = function(def, card, state)
        return { vars = { state.repetitions } }
    end,

    calculate = function(def, card, context, state)
        if not (context.repetition and context.cardarea == G.play) then return end
        if not (CelestasMod.Arena and CelestasMod.Arena.is_active("snowstorm")) then
            return
        end
        local other = context.other_card
        if not (other and other.seal == "Gold") then return end
        return {
            message = localize("k_again_ex"),
            repetitions = state.repetitions,
            card = card,
        }
    end,
})

-- ...and nothing freezes it. CelestasMod.freeze is the one place a Joker is
-- frozen from, so wrapping it catches every route - the Snowstorm this pair is
-- about most of all. The Wildcard Club's immunity is the same shape and the
-- two sit on top of each other without either noticing.
local celesta_shenpai_vulpixie_freeze_ref = CelestasMod.freeze
if celesta_shenpai_vulpixie_freeze_ref then
    function CelestasMod.freeze(card, rounds)
        local def = card and Bind.replacing_special and Bind.replacing_special(card)
        if def and def.key == "shenpai_vulpixie" then return false end
        return celesta_shenpai_vulpixie_freeze_ref(card, rounds)
    end
end

end

--------------------------------------------------------------------------------
-- Neuro + Evil Neuro
--------------------------------------------------------------------------------
--
-- One number. Everything the pair does is that number, so there is one place
-- that raises it and four that read it.
--
-- It opens at 1 and rises by 1 three times a cycle: when the shop closes, when
-- the round starts, and when it ends. One rather than zero because two of the
-- sixteen are MULTIPLIERS, and X0 Chips is not a Joker that has not started
-- yet - it is a run that scores nothing. At 1 those two do nothing and the
-- rest are a +1, which is a pair that has just formed.

do

local NEURO_EVIL = "neuro_evil"

--- What n is on `card`, or nil when it is not this pair.
local function neuro_value(card)
    if card.debuff then return nil end
    local def = Bind.special_of(card)
    if not (def and def.key == NEURO_EVIL) then return nil end
    local n = Bind.special_state(card, def).n
    return type(n) == "number" and n or nil
end

--- Every way this pair moves the run, each applied as a difference.
---
--- A pair of these has to be exactly symmetric - apply(+d) and apply(-d) must
--- cancel - because that is the whole of how the pass below hands anything
--- back. Each one is vanilla's own route for that number, for that reason.
local GRANTS = {
    function(d) if G.hand then G.hand:change_size(d) end end,

    -- Cards selectable to play and to discard, which is what SMODS calls the
    -- play and discard limits. Both, because "card selection limit" is one
    -- number to a player and two to the game.
    function(d)
        if SMODS.change_play_limit then SMODS.change_play_limit(d) end
        if SMODS.change_discard_limit then SMODS.change_discard_limit(d) end
    end,

    -- Hands and discards for the round. round_resets is what a new round is
    -- built from; easing the live count as well is what makes a grant arriving
    -- mid-round worth something now rather than next round.
    function(d)
        local resets = G.GAME and G.GAME.round_resets
        if not resets then return end
        resets.hands = (resets.hands or 0) + d
        if ease_hands_played then ease_hands_played(d, true) end
    end,
    function(d)
        local resets = G.GAME and G.GAME.round_resets
        if not resets then return end
        resets.discards = (resets.discards or 0) + d
        if ease_discard then ease_discard(d, true) end
    end,

    -- The four shelves.
    function(d)
        if G.jokers and G.jokers.config then
            G.jokers.config.card_limit = (G.jokers.config.card_limit or 0) + d
        end
    end,
    function(d)
        if G.consumeables and G.consumeables.config then
            G.consumeables.config.card_limit = (G.consumeables.config.card_limit or 0) + d
        end
    end,
    function(d)
        -- The shop's Joker row. joker_max is vanilla's own field and the one
        -- Overstock moves.
        if G.GAME and G.GAME.shop then
            G.GAME.shop.joker_max = (G.GAME.shop.joker_max or 0) + d
        end
    end,
    function(d) if SMODS.change_voucher_limit then SMODS.change_voucher_limit(d) end end,
    function(d) if SMODS.change_booster_limit then SMODS.change_booster_limit(d) end end,
}

--- What each card has been granted. Weak keys: a card that is gone should not
--- be kept alive by being remembered here.
local granted = setmetatable({}, { __mode = "k" })
--- The run those grants belong to, by seed.
local granted_run = nil

local function neuro_sync()
    -- What the SMODS limit calls read, and what a run being torn down loses
    -- first. The selection pass above crashed on exactly this.
    if not (G.GAME and G.GAME.starting_params and G.hand and G.hand.config) then
        return
    end

    -- A new run owns none of the last one's grants: starting_params is rebuilt
    -- at the start of one, so handing anything back here would take what this
    -- run was never given. Dropped rather than released.
    local run = G.GAME.pseudorandom and G.GAME.pseudorandom.seed
    if run ~= granted_run then
        for card in pairs(granted) do granted[card] = nil end
        granted_run = run
    end

    local live = nil
    for _, held in ipairs((G.jokers and G.jokers.cards) or {}) do
        local n = neuro_value(held)
        if n then
            live = live or {}
            live[held] = math.max(0, math.floor(n))
        end
    end

    local function move(card, want)
        local have = granted[card] or 0
        if want == have then return end
        for _, grant in ipairs(GRANTS) do
            local ok, err = pcall(grant, want - have)
            if not ok then
                CelestasMod.warn_once("bind_neuro_evil_grant",
                    ("Neuro + Evil Neuro could not move the run: %s"):format(tostring(err)))
            end
        end
        if want == 0 then granted[card] = nil else granted[card] = want end
    end

    for card, have in pairs(granted) do
        if not (live and live[card]) and have ~= 0 then move(card, 0) end
    end
    for card, want in pairs(live or {}) do move(card, want) end

    -- ...and the Boss sits out while one is held. hold_boss works the answer
    -- out from every reason standing, so saying it every frame is saying the
    -- same thing rather than saying it again.
    if CelestasMod.hold_boss then
        pcall(CelestasMod.hold_boss, "bind_" .. NEURO_EVIL, live ~= nil)
    end
end

local celesta_bind_neuro_update_ref = Game and Game.update
if celesta_bind_neuro_update_ref then
    function Game:update(dt)
        celesta_bind_neuro_update_ref(self, dt)
        neuro_sync()
    end
end

--- The share of a price or a Blind this pair leaves behind, never below none.
--- n rises without limit and five percent of enough of it is all of it; a
--- negative share would be a Blind that pays you to lose.
local function neuro_scale()
    local holder = Bind.find_special(NEURO_EVIL)
    local n = holder and neuro_value(holder)
    if not n then return 1 end
    return math.max(0, 1 - n * 0.05)
end

-- Blind sizes. get_blind_amount is the one number every Blind is built from,
-- which is why the Printer challenge scales it there too - and it is
-- multiplication, which Talisman's numbers do through their own metamethod.
local celesta_bind_neuro_blind_ref = get_blind_amount
if type(celesta_bind_neuro_blind_ref) == "function" then
    function get_blind_amount(ante, ...)
        local amount = celesta_bind_neuro_blind_ref(ante, ...)
        local scale = neuro_scale()
        if scale >= 1 then return amount end
        return amount * scale
    end
end

-- Shop prices. Set in Card:set_cost and nowhere else, so the price is adjusted
-- after the fact at the one place that sets it - Kumi + HeavenlyFather's
-- booster discount is the same shape. Rounded up and floored at 1, which is
-- what set_cost does to every other price.
local celesta_bind_neuro_cost_ref = Card.set_cost
function Card:set_cost(...)
    local ret = celesta_bind_neuro_cost_ref(self, ...)
    local scale = neuro_scale()
    if scale < 1 and type(self.cost) == "number" and self.cost > 0 then
        self.cost = math.max(1, math.ceil(self.cost * scale))
    end
    return ret
end

special("j_celesta_neuro", "j_celesta_evil_neuro", {
    key = NEURO_EVIL,
    config = { n = 1, gain = 1 },

    loc_vars = function(def, card, state)
        return { vars = { state.n, state.n * 5 } }
    end,

    calculate = function(def, card, context, state)
        -- Three moments a cycle, and they are three separate passes: the shop
        -- closing, the Blind being chosen, and the round ending. main_eval on
        -- the last because end_of_round reaches a Joker once for the round and
        -- again for every card held in hand.
        local rises = (context.ending_shop and not context.blueprint)
            or (context.setting_blind and not context.blueprint
                and not (context.blueprint_card or card).getting_sliced)
            or (context.end_of_round and context.main_eval and not context.blueprint)
        if rises then
            state.n = state.n + state.gain
            return {
                message = localize { type = "variable", key = "a_xmult",
                                     vars = { state.n } },
                colour = G.C.FILTER, card = card,
            }
        end

        -- Every Skip Tag taken, n times over. The tag is already in the run's
        -- list by the time this is raised, so the copies are of the last one
        -- there; at n = 1 there are none, which is the do-nothing value again.
        if context.skip_blind and not context.blueprint then
            local tags = G.GAME and G.GAME.tags
            local taken = tags and tags[#tags]
            local key = taken and (taken.key or (taken.config and taken.config.key))
            if key and add_tag and Tag then
                for _ = 2, state.n do
                    local ok, err = pcall(function() add_tag(Tag(key)) end)
                    if not ok then
                        CelestasMod.warn_once("bind_neuro_evil_tag",
                            ("Neuro + Evil Neuro could not copy a Tag: %s"):format(tostring(err)))
                        break
                    end
                end
            end
            return
        end

        if context.joker_main and state.n > 1 then
            return { x_chips = state.n, x_mult = state.n }
        end
    end,

    calc_dollar_bonus = function(def, card, state)
        if state.n <= 0 then return end
        return state.n
    end,
})

end

--------------------------------------------------------------------------------
-- Deme + Auteru
--------------------------------------------------------------------------------
--
-- SonneFlower's shape in the other currency. Auteru is the Leaf suit's Joker
-- and Deme is the streak that resets the moment it stops being fed, so the pair
-- works the way SonneFlower does - "a Leaf in the scoring hand, or start again"
-- - in Chips rather than Mult, at Deme's own rate.
--
-- Working like SonneFlower is not being it, which is why this one ADDS. A
-- replacing pair is one ability in place of two Jokers; this is a third thing
-- the merge can do, so Deme goes on counting its single-card hands and Auteru
-- goes on paying for every Leaf scored underneath it.
--
-- Per HAND and not per card, which is the difference between this and
-- SonneFlower + Birdyovo next to it: Birdyovo is the one that counts, so that
-- pair takes a lot per Leaf, and this one takes Deme's 0.25 once for a hand
-- that had any.

special("j_celesta_demenishki", "j_celesta_auteru", {
    key = "deme_auteru",
    additive = true,
    config = { x_chips = 1, x_chip_gain = 0.25 },

    loc_vars = function(def, card, state)
        local name, colour = CelestasMod.suit_name_and_colour(
            CelestasMod.LEAF_SUIT, CelestasMod.LEAF_COLOUR, true)
        return { vars = { state.x_chip_gain, state.x_chips, name,
                          colours = { colour } } }
    end,

    calculate = function(def, card, context, state)
        -- context.before is the one pass that sees the scoring hand whole and
        -- lands before any of it scores, so the hand that extends the streak is
        -- paid for itself. Both halves decide in the same place.
        if context.before and not context.blueprint then
            for _, played in ipairs(context.scoring_hand or {}) do
                if played.is_suit and played:is_suit(CelestasMod.LEAF_SUIT) then
                    state.x_chips = state.x_chips + state.x_chip_gain
                    return {
                        message = localize { type = "variable", key = "a_xchips",
                                             vars = { state.x_chips } },
                        colour = G.C.CHIPS, card = card,
                    }
                end
            end

            -- Reset only when there is something to lose, so a run of
            -- Leafless hands does not announce a reset every time.
            if state.x_chips > 1 then
                state.x_chips = 1
                return { message = localize("k_reset"), colour = G.C.RED,
                         card = card }
            end
        end

        if context.joker_main and state.x_chips > 1 then
            return { x_chips = state.x_chips }
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
    local saved_lent = Bind.lent[card]
    Bind.lent[card] = { center = saved_center, ability = saved_ability }
    card.config.center = center
    card.ability = card.ability.celesta_bind.ability
    local ok, aut = pcall(card.generate_UIBox_ability_table, card)
    card.config.center, card.ability = saved_center, saved_ability
    Bind.lent[card] = saved_lent
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

-- Swap: the same two-Joker selection, trading halves rather than joining them.
--
-- Its own card rather than a mode of Bind, because what a player has selected
-- says which they want unambiguously: two loose Jokers can only be merged, and
-- two pairs can only be swapped or made into a quad. A single card would have
-- had to guess between the last two.
SMODS.Consumable {
    key = "swap",
    set = "Spectral",
    atlas = "swap",
    pos = { x = 0, y = 0 },

    cost = 4,
    unlocked = true,
    discovered = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    can_use = function(self, card)
        return Bind.swap_selection() ~= nil
    end,

    use = function(self, card, area, copier)
        local picked = Bind.swap_selection()
        if not picked then return end
        local a, b = picked[1], picked[2]

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            delay = 0.4,
            func = function()
                play_sound("gold_seal", 1.2, 0.6)
                a:juice_up(0.4, 0.5)
                b:juice_up(0.4, 0.5)
                Bind.swap(a, b)
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
