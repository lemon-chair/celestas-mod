--- STAMPS
---
--- A stamp is a mark pressed onto a Joker. It pays out every time that Joker
--- triggers, it costs something the moment it is chosen, and it comes out of a
--- Stamp Pack rather than the shop.
---
--- Three things in this file:
---
---   THE CARD      a consumable of its own type, drawn as the stamp laid over
---                 a blank card. It is never in the shop and never in a
---                 consumable slot: the Stamp Pack is the only thing that
---                 makes one, and it is used out of the pack onto a Joker
---                 there and then.
---
---   THE MARK      the same art again, alone on transparency, drawn over the
---                 Joker it was used on. One per Joker; a Joker already marked
---                 cannot be picked.
---
---   THE PAYOUT    hooked onto Card:calculate_joker, which is the one place
---                 that knows a Joker has triggered, whatever made it trigger.
---
--- Each stamp is its own: the kind is rolled when the pack is opened and the
--- number inside its range is rolled with it, so two Mult Stamps out of the
--- same pack are worth different amounts.
---
--- What it costs is stamps/downsides.lua's business.

CelestasMod.Stamps = {}
local Stamps = CelestasMod.Stamps
local Downsides = CelestasMod.StampDownsides

--- The consumable type. NOT prefixed by Steamodded - ConsumableType sets
--- prefix_config.key = false - so the prefix is written in, which is also what
--- keeps it from colliding with another mod's 'Stamp'.
Stamps.SET = "celesta_Stamp"

--------------------------------------------------------------------------------
-- Art
--------------------------------------------------------------------------------
--
-- One sheet per drawing, two cells wide: cell 0 is the stamp over a blank
-- card, which is the card in the pack, and cell 1 is the stamp alone, which is
-- the mark on the Joker. tools/gen_stamps.py builds them; ART below is the
-- same list that script keeps.
--
-- Several stamps share a drawing - the three Money Stamps are one, and so are
-- the two Retrigger Stamps - so this is a list of ART, not of stamps.

local ART = { "mult", "chips", "x_mult", "x_chips",
              "e_mult", "e_chips", "money", "retrigger" }

-- Written out one by one rather than looped over ART, which would be shorter
-- and would hide all eight from tools/check_atlases.py: that reads the calls
-- statically, and a key built by concatenation is a key it cannot see. The
-- checker is the only thing standing between a mis-sized sheet and a card that
-- renders as smeared garbage, so the sheets stay where it can find them.
SMODS.Atlas { key = "stamp_mult",      path = "stamp_mult.png",      px = 71, py = 95 }
SMODS.Atlas { key = "stamp_chips",     path = "stamp_chips.png",     px = 71, py = 95 }
SMODS.Atlas { key = "stamp_x_mult",    path = "stamp_x_mult.png",    px = 71, py = 95 }
SMODS.Atlas { key = "stamp_x_chips",   path = "stamp_x_chips.png",   px = 71, py = 95 }
SMODS.Atlas { key = "stamp_e_mult",    path = "stamp_e_mult.png",    px = 71, py = 95 }
SMODS.Atlas { key = "stamp_e_chips",   path = "stamp_e_chips.png",   px = 71, py = 95 }
SMODS.Atlas { key = "stamp_money",     path = "stamp_money.png",     px = 71, py = 95 }
SMODS.Atlas { key = "stamp_retrigger", path = "stamp_retrigger.png", px = 71, py = 95 }

-- The pack art is 57x93, which is neither a card's shape nor a card's size, so
-- it is CENTRED in a card-sized cell rather than given one of its own - the
-- same treatment Boosfer's circle and Urschleim's blob get.
--
-- A cell of its own does not work: a Booster is sized by the CardArea it sits
-- in, not by its centre (the shop's is built at 1.27 card widths,
-- UI_definitions.lua:672), so the cell is stretched to that rect whatever
-- shape it is. A 57x93 cell came out half again as big as a vanilla pack.
SMODS.Atlas { key = "stamp_pack", path = "stamp_pack.png", px = 71, py = 95 }

-- Resolved at load. SMODS.current_mod is only set while a mod is loading, and
-- the mark is drawn every frame.
local MARK_ATLAS = {}
for _, name in ipairs(ART) do
    MARK_ATLAS[name] = SMODS.current_mod.prefix .. "_stamp_" .. name
end

--------------------------------------------------------------------------------
-- The thirteen stamps
--------------------------------------------------------------------------------
--
-- One entry per line of the list this was asked from, which is why the three
-- Money Stamps and the two Retrigger Stamps are separate entries rather than
-- one entry with a tier: they are different cards that happen to share a face,
-- and keeping them apart is what lets the roll below pick a TIER first and a
-- card second.
--
--   art      which sheet it is drawn from
--   tier     1 common, 2 uncommon, 3 rare. Also the tier of downside it is
--            offered against.
--   effect   the key its payout is returned under, or "retrigger"
--   min/max  the range its number is rolled in, in whole steps
--   div      what that number is divided by afterwards, so the multipliers
--            and exponents roll 11..15 and pay X1.1..X1.5

Stamps.KINDS = {
    -- ---------------- common ----------------
    { key = "mult",     art = "mult",     tier = 1, effect = "mult",    min = 5,  max = 20 },
    { key = "chips",    art = "chips",    tier = 1, effect = "chips",   min = 15, max = 60 },
    { key = "money",    art = "money",    tier = 1, effect = "dollars", min = 1,  max = 2 },
    { key = "x_mult",   art = "x_mult",   tier = 1, effect = "x_mult",  min = 11, max = 15, div = 10 },
    { key = "x_chips",  art = "x_chips",  tier = 1, effect = "x_chips", min = 11, max = 15, div = 10 },

    -- ---------------- uncommon ----------------
    { key = "x_mult_uncommon",  art = "x_mult",    tier = 2, effect = "x_mult",    min = 16, max = 20, div = 10 },
    { key = "x_chips_uncommon", art = "x_chips",   tier = 2, effect = "x_chips",   min = 16, max = 20, div = 10 },
    { key = "money_uncommon",   art = "money",     tier = 2, effect = "dollars",   min = 3,  max = 4 },
    { key = "retrigger",        art = "retrigger", tier = 2, effect = "retrigger", min = 1,  max = 1 },

    -- ---------------- rare ----------------
    -- ^Chips and ^Mult are Talisman's arithmetic. Talisman is a declared
    -- dependency of this mod, which is why these return the key directly the
    -- way Ironmouse does rather than carrying a fallback: the enhancements
    -- that DO carry one are playing cards, which a player can be holding
    -- before they ever find out.
    { key = "e_mult",         art = "e_mult",    tier = 3, effect = "e_mult",    min = 11, max = 15, div = 10 },
    { key = "e_chips",        art = "e_chips",   tier = 3, effect = "e_chips",   min = 11, max = 15, div = 10 },
    { key = "money_rare",     art = "money",     tier = 3, effect = "dollars",   min = 5,  max = 6 },
    { key = "retrigger_rare", art = "retrigger", tier = 3, effect = "retrigger", min = 2,  max = 2 },
}

--- How often each tier comes up. Balatro's own Joker rarities - 70 / 25 / 5
--- (common_events.lua) - because the list this was asked from names its three
--- groups after those rarities and gives no rates of its own.
Stamps.TIER_WEIGHTS = { 0.70, 0.25, 0.05 }

Stamps.BY_KEY = {}
Stamps.BY_TIER = { {}, {}, {} }
for _, kind in ipairs(Stamps.KINDS) do
    Stamps.BY_KEY[kind.key] = kind
    local tier = Stamps.BY_TIER[kind.tier]
    tier[#tier + 1] = kind
end

-- Resolved at load, for the same reason MARK_ATLAS is.
local CENTER_PREFIX = "c_" .. SMODS.current_mod.prefix .. "_stamp_"

--- The centre key a kind is registered under.
function Stamps.center_key(kind_key)
    return CENTER_PREFIX .. kind_key
end

--- The kind a rolled stamp is, or nil for one this version no longer has.
--- A run saved against an older list can carry anything; a Joker wearing a
--- stamp nobody recognises simply stops paying rather than crashing.
function Stamps.kind(stamp)
    return stamp and stamp.kind and Stamps.BY_KEY[stamp.kind] or nil
end

--------------------------------------------------------------------------------
-- Rolling one
--------------------------------------------------------------------------------

local TIER_SEED = "celesta_stamp_tier"
local KIND_SEED = "celesta_stamp_kind"
local VALUE_SEED = "celesta_stamp_value"

--- Which tier the next stamp is, by the weights above.
local function roll_tier()
    local roll = pseudorandom(pseudoseed(TIER_SEED))
    local seen = 0
    for tier, weight in ipairs(Stamps.TIER_WEIGHTS) do
        seen = seen + weight
        if roll < seen then return tier end
    end
    -- The weights sum to 1 and pseudorandom is below it, so this is only
    -- reached if they are ever edited to sum to less.
    return #Stamps.TIER_WEIGHTS
end

--- A kind for the next stamp: a tier, then one of the cards in it. `tier` names one outright,
--- for a stamp that is promised to be of it.
function Stamps.roll_kind(tier)
    local pool = Stamps.BY_TIER[tier or roll_tier()]
    return pseudorandom_element(pool, pseudoseed(KIND_SEED))
end

--------------------------------------------------------------------------------
-- Bubi
--------------------------------------------------------------------------------
--
-- Two things Bubi changes, and Bubi + Ironmouse changes a third. All three are asked at the
-- moment they matter, rather than kept on a card: the Joker can be bought, sold or debuffed
-- between a pack being seen in the shop and being opened.
--
-- The Joker is looked for the way Liffeh is - in the row, or run by a CDawg that has one
-- sold. The pair is looked for the way Dooby + Nimi is, by name: a replacing pair is not
-- in the Joker lookups, and Bubi is one of its halves.

local BUBI_KEY = "j_" .. SMODS.current_mod.prefix .. "_bubi"

--- The pair's name, resolved here for the lookup below.
local BUBI_PAIR = "bubi_ironmouse"

--- The pair, if one is in the row and able to act.
local function bubi_pair_held()
    local Bind = CelestasMod.Bind
    if not (Bind and Bind.find_special) then return false end
    local holder = Bind.find_special(BUBI_PAIR)
    return (holder and not holder.debuff) and true or false
end

--- True while a Bubi - the Joker, a retained one, or the pair - is out.
function Stamps.bubi()
    if bubi_pair_held() then return true end
    if CelestasMod.joker_in_play and CelestasMod.joker_in_play(BUBI_KEY) then return true end
    return (CelestasMod.cdawg_running and CelestasMod.cdawg_running(BUBI_KEY)) and true or false
end

--- True while the pair is: every stamp in a Stamp Pack is Rare.
function Stamps.all_rare()
    return bubi_pair_held()
end

--- How many stamps a Stamp Pack holds with a Bubi out.
Stamps.BUBI_PACK_SIZE = 5

--- The number one stamp of this kind is worth.
function Stamps.roll_value(kind)
    local n = pseudorandom(pseudoseed(VALUE_SEED), kind.min, kind.max)
    if kind.div then return n / kind.div end
    return n
end

--- A whole stamp: what it is, what it is worth, and what it costs.
function Stamps.new(kind_key)
    local kind = Stamps.BY_KEY[kind_key]
    if not kind then return nil end
    return {
        kind = kind.key,
        value = Stamps.roll_value(kind),
        downside = Downsides.roll(kind.tier),
    }
end

--------------------------------------------------------------------------------
-- What is written on the cards
--------------------------------------------------------------------------------

--- The number to print: the rolled one, or the range on a card that has not
--- been rolled - which is the Collection, where there is no stamp yet and
--- "5-20" is the honest answer.
--- One end of a kind's range, in the units it pays in. The division is
--- skipped rather than done by one when there is no divisor: 5/1 prints as
--- "5" under LuaJIT and as "5.0" under later Luas, and a range that reads
--- "5.0-20.0" on somebody else's runtime is not worth the shorter line.
local function scaled(n, kind)
    if kind.div then return n / kind.div end
    return n
end

local function shown(stamp, kind)
    if stamp and stamp.value then return stamp.value end
    if kind.min == kind.max then return scaled(kind.min, kind) end
    return scaled(kind.min, kind) .. "-" .. scaled(kind.max, kind)
end

--- The value a description needs for anything other than printing - which is
--- only ever whether "time" or "times" is the right word.
local function value_of(stamp, kind)
    if stamp and stamp.value then return stamp.value end
    return kind.min
end

--- The vars one stamp's description asks for.
local function stamp_vars(stamp, kind)
    local vars = { shown(stamp, kind) }
    if kind.effect == "retrigger" then
        vars[2] = localize(value_of(stamp, kind) > 1
            and "b_retrigger_plural" or "b_retrigger_single")
    end
    return vars
end

--- One row of a description, as generate_card_ui builds them: a list of parts
--- per line, wrapped into a UIT row.
---
--- localize fills `nodes[i]` with the parts of line i and nothing else, so the
--- wrapping is done here - the same way jokers/cdawg.lua puts a retained
--- Joker's running total on CDawg's card.
local function localized_rows(key, vars, wrap)
    local lines = {}
    local ok = pcall(localize, { type = "descriptions", set = "Other",
                                 key = key, vars = vars, nodes = lines })
    if not ok then return {} end
    if not wrap then return lines end

    local rows = {}
    for _, line in ipairs(lines) do
        rows[#rows + 1] = { n = G.UIT.R, config = { align = "cl" },
                            nodes = line }
    end
    return rows
end

--- What this stamp costs, for the bottom of its card.
---
--- A rolled stamp shows the cost it actually carries. An unrolled one - the
--- Collection again - says which tier of cost it will come with, because that
--- much is known about it and nothing more is.
local function downside_rows(stamp, kind)
    local rows = {}
    local picked = stamp and stamp.downside
    -- Nothing to read about a cost that is not going to be paid.
    if Stamps.bubi() then return nil end
    if Downsides.entry(picked) then
        local entry = Downsides.entry(picked)
        for _, row in ipairs(localized_rows("celesta_stamp_downside", {}, true)) do
            rows[#rows + 1] = row
        end
        for _, row in ipairs(localized_rows(
                "celesta_stamp_down_" .. entry.loc,
                Downsides.vars(picked), true)) do
            rows[#rows + 1] = row
        end
    else
        local tier = ({ "k_common", "k_uncommon", "k_rare" })[kind.tier]
        for _, row in ipairs(localized_rows("celesta_stamp_downside_tier",
                                            { localize(tier) }, true)) do
            rows[#rows + 1] = row
        end
    end
    if #rows == 0 then return nil end

    -- main_end is appended as a SINGLE node (game_object.lua:1858), so several
    -- lines have to arrive inside one column rather than as several rows.
    return { { n = G.UIT.C, config = { align = "m" }, nodes = rows } }
end

--------------------------------------------------------------------------------
-- A stamp on a Joker
--------------------------------------------------------------------------------
--
-- Two different fields on purpose. `celesta_stamp_roll` is the stamp a CARD in
-- a pack is offering; `celesta_stamp` is the stamp a JOKER is wearing. Sharing
-- one name would have the mark drawn over the pack card too, which already has
-- the stamp printed on its face.

--- The stamp this Joker is wearing, if any.
function Stamps.of(card)
    return type(card) == "table" and card.ability and card.ability.celesta_stamp
        or nil
end

--- The one highlighted Joker a stamp may be used on, or nil.
---
--- Exactly one, so there is never a question of which was meant - the same
--- rule the Blank Joker's Tarots go by. A Joker already stamped is not one:
--- each Joker can only have one.
function Stamps.target()
    local picked = G.jokers and G.jokers.highlighted
    if not (picked and #picked == 1) then return nil end
    local joker = picked[1]
    if not (joker and joker.ability and joker.ability.set == "Joker") then
        return nil
    end
    if joker.ability.celesta_stamp then return nil end
    return joker
end

--------------------------------------------------------------------------------
-- The cards
--------------------------------------------------------------------------------

SMODS.ConsumableType {
    key = Stamps.SET,
    -- Never in the shop on its own: a Stamp comes out of a Stamp Pack and
    -- nowhere else. shop_rate is what would put it there.
    shop_rate = 0,

    -- ...and normally it is used out of the pack there and then, with no way
    -- to keep one. Dooby + Nimi is the one thing that changes that.
    --
    -- Steamodded asks the consumable TYPE which area a card in a pack may be
    -- SELECTED into (utils.lua:3134), and naming one is what puts the Select
    -- button on the card and sends it to the tray. Nothing else has to change:
    -- a Stamp in the tray is used exactly as a Stamp in a pack is, onto one
    -- highlighted Joker, because can_use and use never cared where it was.
    --
    -- Answered here rather than from merge/bind.lua because this file owns the
    -- type, and it is loaded after that one; the pair is looked up by name.
    select_card = function(self, card, pack)
        local Bind = CelestasMod.Bind
        if not (Bind and Bind.find_special) then return nil end
        local holder = Bind.find_special("dooby_nimi")
        if not (holder and not holder.debuff) then return nil end
        return "consumeables"
    end,
    collection_rows = { 5, 4 },
    primary_colour = HEX("8a6a3f"),
    secondary_colour = HEX("f4d79a"),
    loc_txt = {},
}

for _, kind in ipairs(Stamps.KINDS) do
    SMODS.Consumable {
        key = "stamp_" .. kind.key,
        set = Stamps.SET,
        atlas = "stamp_" .. kind.art,
        pos = { x = 0, y = 0 },

        cost = 4,
        unlocked = true,
        -- Discovered from the start, and it has to be: an undiscovered
        -- consumable is drawn as a question mark (card.lua:182), and the
        -- whole of choosing between two stamps is seeing which they are.
        discovered = true,

        --- Which line of the list this card is. Read back in set_ability,
        --- which is handed the CENTRE rather than the key.
        celesta_stamp_kind = kind.key,

        set_ability = function(self, card, initial, delay_sprites)
            -- Rolled once, on the card, and kept: a stamp saved with the run
            -- has to be worth the same when the run is loaded again, and a
            -- pack re-entered has to offer the same two cards.
            if card.ability.celesta_stamp_roll then return end
            card.ability.celesta_stamp_roll = Stamps.new(self.celesta_stamp_kind)
        end,

        loc_vars = function(self, info_queue, card)
            local mine = Stamps.BY_KEY[self.celesta_stamp_kind]
            local stamp = card and card.ability
                and card.ability.celesta_stamp_roll
            return {
                vars = stamp_vars(stamp, mine),
                main_end = downside_rows(stamp, mine),
            }
        end,

        -- Ours because it has to be: Steamodded routes can_use_consumeable
        -- through the centre, and vanilla's chain of name checks ends in
        -- `return false` for a key it does not know, which would grey the
        -- button out forever.
        can_use = function(self, card)
            return Stamps.target() ~= nil
        end,

        use = function(self, card, area, copier)
            Stamps.press(card)
        end,
    }
end

--- Put the stamp on the chosen Joker and pay for it.
function Stamps.press(card)
    local joker = Stamps.target()
    local stamp = card and card.ability and card.ability.celesta_stamp_roll
    if not (joker and stamp) then return end

    joker.ability.celesta_stamp = stamp
    if G.jokers then G.jokers:unhighlight_all() end

    G.E_MANAGER:add_event(Event {
        trigger = "after",
        delay = 0.2,
        func = function()
            joker:juice_up(0.5, 0.6)
            -- The cost is paid as the stamp lands, not when the card was
            -- picked up: the description said what it would be, and this is
            -- the moment it becomes true. With a Bubi out there is none.
            if not Stamps.bubi() then Downsides.apply(stamp.downside) end
            return true
        end,
    })
end

--------------------------------------------------------------------------------
-- The pack
--------------------------------------------------------------------------------
--
-- The same appearance rate as a Spectral Pack, which is weight 0.3
-- (game.lua:690), and one card chosen out of however many it turned out to
-- hold.
--
-- How many is rolled PER PACK rather than fixed, so two Stamp Packs in one
-- shop are different offers and the shop card says which is which before it is
-- bought. `extra` is the field the whole of the rest of the game reads that
-- from - Card:open fills the pack from it (card.lua:1976) and create_UIBox
-- sizes the row to it - so rolling it onto the card's own ability is the whole
-- of the change.
--
-- Five is also as many as the row is built to show: create_UIBox caps its
-- width at five cards (game_object.lua), so a sixth would be offered off the
-- side of the pack.

Stamps.PACK_MIN = 2
Stamps.PACK_MAX = 5

--- Set once the pack's size has been rolled, so it is rolled once. The
--- ability is saved with the run, so a pack seen in the shop, left there and
--- come back to is the same pack.
local PACK_ROLLED = "celesta_pack_rolled"
local PACK_SEED = "celesta_stamp_pack_size"

--- What the pack holds right now: the size it rolled, or a Bubi's five.
function Stamps.pack_extra(ability)
    if Stamps.bubi() then return Stamps.BUBI_PACK_SIZE end
    return ability.extra
end

--- The tier stamp number `i` of this pack is promised to be, or nil for an ordinary roll.
---
--- With a Bubi out one stamp in the pack is always Rare - a place picked once for the pack and
--- kept on it, so the Rare is not always the first - and with Bubi + Ironmouse every one is.
--- A place kept from before the pack shrank - a modifier arriving since - is picked again, so
--- a Rare is never missing.
function Stamps.guaranteed_tier(card, i)
    if Stamps.all_rare() then return 3 end
    if not Stamps.bubi() then return nil end

    local ability = card and card.ability
    if not ability then return nil end
    local size = math.max(1, Stamps.pack_extra(ability)
        + ((G.GAME and G.GAME.modifiers and G.GAME.modifiers.booster_size_mod) or 0))
    if not ability.celesta_rare_slot or ability.celesta_rare_slot > size then
        ability.celesta_rare_slot = pseudorandom(pseudoseed("celesta_bubi_slot"), 1, size)
    end
    if i == ability.celesta_rare_slot then return 3 end
    return nil
end

SMODS.Booster {
    key = "stamp_pack",
    kind = Stamps.SET,
    atlas = "stamp_pack",
    pos = { x = 0, y = 0 },
    group_key = "k_celesta_stamp_pack",

    weight = 0.3,
    cost = 4,
    -- The floor, which is what a pack holds if it never gets to roll.
    config = { extra = Stamps.PACK_MIN, choose = 1 },
    -- Discovered for the same reason the stamps are: an undiscovered Booster
    -- is drawn as a question mark (card.lua:182), and a pack nobody can see
    -- is a pack nobody buys.
    discovered = true,

    -- No display_size. The cell is card-sized, so the game sizes this exactly
    -- as it sizes a vanilla pack; see the atlas above for what happened when
    -- it was not.

    set_ability = function(self, card, initial, delay_sprites)
        if card.ability[PACK_ROLLED] then return end
        card.ability[PACK_ROLLED] = true
        card.ability.extra = pseudorandom(pseudoseed(PACK_SEED),
                                          Stamps.PACK_MIN, Stamps.PACK_MAX)
    end,

    loc_vars = function(self, info_queue, card)
        local cfg = (card and card.ability) or self.config
        local mods = (G.GAME and G.GAME.modifiers) or {}
        local bonus = mods.booster_size_mod or 0

        -- A card that has not rolled is the Collection's stand-in, where no
        -- pack exists to have a size - so the honest answer is the range it
        -- rolls in rather than either end of it.
        local size = card and card.ability and card.ability[PACK_ROLLED]
            and math.max(1, Stamps.pack_extra(cfg) + bonus) or nil
        local most = size or math.max(1, Stamps.PACK_MAX + bonus)
        if not size and Stamps.bubi() then
            most = math.max(1, Stamps.BUBI_PACK_SIZE + bonus)
        end

        return {
            vars = {
                math.min(cfg.choose + (mods.booster_choice_mod or 0), most),
                size or (Stamps.bubi() and most
                    or (math.max(1, Stamps.PACK_MIN + bonus) .. "-" .. most)),
            },
        }
    end,

    create_card = function(self, card, i)
        local kind = Stamps.roll_kind(Stamps.guaranteed_tier(card, i))
        return {
            set = Stamps.SET,
            key = kind and Stamps.center_key(kind.key) or nil,
            area = G.pack_cards,
            skip_materialize = true,
        }
    end,
}

--------------------------------------------------------------------------------
-- Paying out
--------------------------------------------------------------------------------
--
-- "Every time the joker this stamp is attached to triggers" is post_trigger,
-- which Steamodded raises to every Joker each time any one of them triggers
-- and names the one it is about in context.other_card. eval_card raises it
-- from the same `if jokers or triggered` that decides a Joker triggered at all
-- (common_events.lua:782), so it covers every context a Joker can act in - the
-- main scoring pass, a scored card, the end of a round, and the repetition
-- pass a retrigger Joker like ShyLily lives in.
--
-- The payout used to be hung on the tail of whatever the Joker returned
-- instead, and that was wrong: it assumed the return was a SCORING effect.
-- ShyLily's is a repetitions table, so the Chips went into the repetition
-- machinery, where SMODS.insert_repetitions walked the extra chain, found a
-- table with no repetitions, zeroed it and dropped it - warning about it in
-- the log each time. Every stamp on a Joker of that shape paid nothing.
--
-- What comes back from post_trigger is collected into the same list of effects
-- as the Joker's own and applied straight after it (utils.lua:1666), so the
-- shape is right whatever the Joker returned, and the popup lands on the
-- stamped card.
--
-- A Joker that grants several retriggers is post_triggered once per retrigger
-- it grants (SMODS.calculate_repetitions), so a stamp on one pays per
-- retrigger. That is the same count Steamodded uses for how many times the
-- Joker's effect happened.

--- Marks a payout as ours, so a Joker that hands back a table it KEEPS picks
--- up one payout rather than one per trigger for the rest of the run. Effect
--- tables are normally built fresh, which is why this is only a guard.
local PAYOUT_FLAG = "celesta_stamp_payout"

--- What this Joker's stamp pays for the trigger just reported, or nil.
function Stamps.payout(card, context)
    -- post_trigger goes to every Joker, so the one it is about has to be
    -- named. Anything else is somebody else triggering.
    if not (context.post_trigger and context.other_card == card) then
        return nil
    end

    local kind = Stamps.kind(Stamps.of(card))
    if not kind or kind.effect == "retrigger" then return nil end

    -- What the Joker was actually doing, which is what decides whether this
    -- was a trigger worth paying for.
    local inner = context.other_context or {}

    -- A copy is not the Joker triggering. Blueprint copies what a Joker DOES;
    -- the stamp is on the card, not in the ability, and it stays there.
    if inner.blueprint then return nil end
    -- Questions, not triggers. Answering these would pay out on every
    -- probability lookup in the hand.
    if SMODS.is_getter_context(inner) then return nil end

    -- Chips and Mult are only a thing while a hand is being scored: `mult` and
    -- `hand_chips` are globals that evaluate_play sets up, and adding to them
    -- outside it moves a number nobody is looking at. Money is not - it can be
    -- given at any point a Joker triggers, which is where an end-of-round
    -- Joker with a Money Stamp earns its keep.
    if kind.effect ~= "dollars" and not CelestasMod.hand_is_being_played() then
        return nil
    end

    local stamp = Stamps.of(card)
    return { [kind.effect] = stamp.value, card = card, [PAYOUT_FLAG] = true }
end

local celesta_stamp_calculate_ref = Card.calculate_joker
function Card:calculate_joker(context, ...)
    local eff, triggered = celesta_stamp_calculate_ref(self, context, ...)
    local payout = Stamps.payout(self, context)
    if not payout then return eff, triggered end

    -- A Joker with something of its own to say about another Joker triggering
    -- still gets to say it: the payout rides along on the tail rather than in
    -- place of it. Both are scoring effects here, which is the whole point of
    -- answering in this context rather than in the Joker's own.
    if type(eff) ~= "table" then return payout, triggered end
    local tail = eff
    while type(tail.extra) == "table" and not tail.extra[PAYOUT_FLAG] do
        tail = tail.extra
    end
    tail.extra = payout
    return eff, triggered
end

--------------------------------------------------------------------------------
-- ...and the one that retriggers instead
--------------------------------------------------------------------------------
--
-- SMODS.calculate_retriggers is where a Joker is asked how many times it runs
-- again, and eval_card only asks once the Joker has actually triggered
-- (common_events.lua:778) - which is the same "every time it triggers" the
-- other stamps pay on. It also refuses to ask during a getter context or from
-- inside a retrigger, so neither guard is needed here.

--- How many extra times this Joker's stamp runs it.
function Stamps.retriggers(card)
    local stamp = Stamps.of(card)
    local kind = Stamps.kind(stamp)
    if not kind or kind.effect ~= "retrigger" then return 0 end
    return stamp.value or 0
end

local celesta_stamp_retriggers_ref = SMODS.calculate_retriggers
SMODS.calculate_retriggers = function(card, context, _ret)
    local out = celesta_stamp_retriggers_ref(card, context, _ret)
    local times = Stamps.retriggers(card)
    if times > 0 then
        SMODS.insert_repetitions(out, {
            repetitions = times,
            card = card,
        }, card, "joker_retrigger")
    end
    return out
end

--------------------------------------------------------------------------------
-- Drawing the mark
--------------------------------------------------------------------------------
--
-- Over the card rather than as part of it, the same way frost is: a Joker
-- keeps whatever art, edition and enhancement it already had, and the stamp
-- sits on top of all of it.

-- One sprite per drawing, shared by every Joker wearing that stamp. Built on
-- first use rather than at load: the atlases do not exist yet when this file
-- runs.
local mark_sprites = {}

local function mark_sprite(art)
    if mark_sprites[art] then return mark_sprites[art] end
    local atlas = G.ASSET_ATLAS[MARK_ATLAS[art]]
    if not atlas then return nil end
    mark_sprites[art] = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas,
                               { x = 1, y = 0 })
    return mark_sprites[art]
end

local celesta_stamp_draw_ref = Card.draw
function Card:draw(layer)
    celesta_stamp_draw_ref(self, layer)

    local kind = Stamps.kind(Stamps.of(self))
    if not kind then return end
    if self.facing == "back" or layer == "shadow" then return end

    local sprite = mark_sprite(kind.art)
    if not sprite then return end
    sprite.role.draw_major = self
    sprite:draw_shader("dissolve", nil, nil, nil, self.children.center)
end

--------------------------------------------------------------------------------
-- ...and saying what it is
--------------------------------------------------------------------------------
--
-- The mark says WHICH stamp a Joker is wearing and the description says what
-- it is worth, which is the part the art cannot carry: a X1.1 and a X2 are the
-- same drawing.
--
-- Appended to the finished description rather than routed through a centre's
-- loc_vars, because the Joker underneath may be anybody's - vanilla's, this
-- mod's, or another mod's.

--- The stamp's line for the card it is on, or nil.
local function mark_rows(card)
    local stamp = Stamps.of(card)
    local kind = Stamps.kind(stamp)
    if not kind then return nil end
    return localized_rows("celesta_stamp_mark_" .. kind.effect,
                          stamp_vars(stamp, kind), false)
end

local celesta_stamp_ui_ref = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table(vars_only)
    local ui, main_start, main_end = celesta_stamp_ui_ref(self, vars_only)
    -- vars_only asks for the three pieces a description is built from rather
    -- than the description, and there is nothing to append to yet.
    if vars_only then return ui, main_start, main_end end

    if type(ui) == "table" and type(ui.main) == "table" then
        for _, row in ipairs(mark_rows(self) or {}) do
            ui.main[#ui.main + 1] = row
        end
    end
    return ui
end

--------------------------------------------------------------------------------
-- ...and opened at Bubi's size
--------------------------------------------------------------------------------
--
-- A pack rolls its size once, when it is made, and may be sitting in the shop for rounds
-- before it is bought. Bubi may arrive in between, so the size is settled when the pack is
-- opened, which is the one moment it is read (card.lua:1976).

local celesta_stamp_open_ref = Card.open
function Card:open(...)
    if self.ability and self.ability.set == "Booster" and self.config
        and self.config.center and self.config.center.kind == Stamps.SET
        and Stamps.bubi() then
        self.ability.extra = Stamps.BUBI_PACK_SIZE
    end
    return celesta_stamp_open_ref(self, ...)
end
