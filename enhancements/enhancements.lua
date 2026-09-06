--- ENHANCEMENTS
---
--- Art is built by tools/gen_enhancements.py. Each gets its own atlas because
--- the cell sizes differ: Exo's frame is 84x104 for a 71x95 card, so it reads
--- as overhanging the card edges, while Gash sits inside the card.
---
--- Keys are prefixed like everything else, and are kept lowercase because
--- SMODS uses the key verbatim for localization: `gash` registers as
--- m_celesta_gash and reads its text from descriptions.Enhanced under that
--- exact key. A capitalised key would need capitalised loc entries too.

CelestasMod.ENHANCEMENT_KEYS = {
    Exo  = "m_" .. SMODS.current_mod.prefix .. "_exo",
    Gash = "m_" .. SMODS.current_mod.prefix .. "_gash",
    Eutrophic = "m_" .. SMODS.current_mod.prefix .. "_eutrophic",
    Limestone = "m_" .. SMODS.current_mod.prefix .. "_limestone",
    Driftwood = "m_" .. SMODS.current_mod.prefix .. "_driftwood",
    Sandstone = "m_" .. SMODS.current_mod.prefix .. "_sandstone",
    Scoria = "m_" .. SMODS.current_mod.prefix .. "_scoria",
    Foliage = "m_" .. SMODS.current_mod.prefix .. "_foliage",
}

-- Shared so Saruei can target this exact roll through fix_probability, and so
-- the odds shown on the card can never drift from the odds rolled.
-- Resolved at load: SMODS.current_mod is only valid while the mod is
-- loading, and Exo's draw hook runs every frame long afterwards.
local EXO_FRAME_ATLAS = SMODS.current_mod.prefix .. "_enh_exo_frame"

--------------------------------------------------------------------------------
-- Scoring sounds
--------------------------------------------------------------------------------

-- Declared explicitly, one per file. SMODS.Sound has a register_global that
-- would sweep assets/sounds/ automatically, but nothing in Steamodded ever
-- calls it, so a file dropped in that folder registers only if it is named
-- here.
--
-- Keys are prefixed the same way everything else is, so `driftwood_score`
-- becomes celesta_driftwood_score. Avoid the words music, stream and ambient
-- in a sound key: SMODS matches those to decide streaming vs static, and a
-- short effect wants static.
SMODS.Sound { key = "driftwood_score", path = "driftwood_score.ogg" }
SMODS.Sound { key = "eutrophic_score", path = "eutrophic_score.mp3" }
SMODS.Sound { key = "limestone_score", path = "limestone_score.ogg" }
SMODS.Sound { key = "foliage_score", path = "foliage_score.mp3" }

CelestasMod.ENHANCEMENT_SOUNDS = {
    Driftwood = SMODS.current_mod.prefix .. "_driftwood_score",
    Eutrophic = SMODS.current_mod.prefix .. "_eutrophic_score",
    Limestone = SMODS.current_mod.prefix .. "_limestone_score",
    Foliage = SMODS.current_mod.prefix .. "_foliage_score",
}

--- Queues a scoring sound so it lands with this card's animation.
---
--- Scoring evaluates every card in one synchronous pass and queues the
--- animations as events, so play_sound called straight from calculate would
--- fire the whole hand's sounds at once, before the first card moves. Going
--- through the event manager puts each sound in the same queue position as
--- the card that asked for it.
---
--- A retriggered card scores more than once and so plays more than once,
--- which is the intent - it is the same beat the chip popups make.
local function play_scoring_sound(key)
    -- An unregistered key would send play_sound looking for
    -- resources/sounds/<key>.ogg in the base game and fail there, so a
    -- missing or misnamed file goes quiet rather than taking the hand down.
    if not (G.E_MANAGER and key) then return end
    if not (SMODS.Sounds and SMODS.Sounds[key]) then return end
    G.E_MANAGER:add_event(Event {
        trigger = "before",
        delay = 0.0,
        blocking = false,
        func = function()
            play_sound(key)
            return true
        end,
    })
end

--- True when a Nostro is in play and able to act.
--- Asked at the moment a Gash breaks rather than cached: Nostro can be
--- bought, sold or debuffed between one break and the next.
function CelestasMod.nostro_active()
    for _, joker in ipairs(SMODS.find_card("j_celesta_nostro")) do
        if not joker.debuff then return true end
    end
    return false
end

--- Strips a card back to a plain playing card - no enhancement, no edition,
--- no seal - which is what Nostro turns a Gash break into.
--- Queued rather than immediate: this runs inside the destroy pass, which is
--- still walking the played cards.
function CelestasMod.strip_card(card)
    if not (G.E_MANAGER and card) then return end
    G.E_MANAGER:add_event(Event {
        func = function()
            if G.P_CENTERS and G.P_CENTERS.c_base and card.set_ability then
                card:set_ability(G.P_CENTERS.c_base, nil, true)
            end
            -- set_edition(edition, immediate, silent)
            if card.set_edition then card:set_edition(nil, true, true) end
            -- set_seal(seal, silent, immediate)
            if card.set_seal then card:set_seal(nil, true, true) end
            return true
        end,
    })
end

CelestasMod.GASH_BREAK_ID = "celesta_gash_break"
CelestasMod.GASH_ODDS = 4

--------------------------------------------------------------------------------
-- Exo — retriggered once per consumable held.
--------------------------------------------------------------------------------

-- How far Exo's frame extends past the card. Sprite:draw_from scales by
-- (1 + ms) around a box sized to the card, so the frame's cell must itself be
-- card-sized - an 84-wide cell renders 84/71 too big AND overflows that box,
-- which is too large and off-centre at once. gen_enhancements.py fits the art
-- into a card cell; this number then restores its authored 84-wide size.
-- It is the only knob for how thick the border reads.
CelestasMod.EXO_OVERHANG = 84 / 71 - 1

local exo_frame_sprite

SMODS.Enhancement {
    key = "exo",
    atlas = "enh_exo",
    pos = { x = 0, y = 0 },
    discovered = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    -- Called from the card's draw pass. The centre sprite is only the card
    -- body; the frame is drawn here instead so it can be larger than the card,
    -- the same way a Legendary Joker's soul overlay is drawn.
    draw = function(self, card, layer)
        local atlas = G.ASSET_ATLAS[EXO_FRAME_ATLAS]
        if not atlas then return end
        if not exo_frame_sprite then
            exo_frame_sprite = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, { x = 0, y = 0 })
            exo_frame_sprite.role.draw_major = card
        end
        exo_frame_sprite.role.draw_major = card
        exo_frame_sprite:draw_shader("dissolve", nil, nil, nil,
            card.children.center, CelestasMod.EXO_OVERHANG, 0)
    end,

    calculate = function(self, card, context)
        -- One extra trigger per consumable currently held, so an empty
        -- consumable area leaves the card scoring exactly once.
        if context.repetition and context.cardarea == G.play then
            local held = (G.consumeables and G.consumeables.cards)
                and #G.consumeables.cards or 0
            if held > 0 then
                return {
                    message = localize("k_again_ex"),
                    repetitions = held,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Gash — X2 Chips, but 1 in 4 to break when scored.
--------------------------------------------------------------------------------

SMODS.Enhancement {
    key = "gash",
    atlas = "enh_gash",
    pos = { x = 0, y = 0 },
    discovered = true,

    -- Applied by the game, NOT returned from calculate. Card:set_ability
    -- copies an enhancement's config straight onto the card
    -- (x_chips = center.config.x_chips or 1) and scoring reads ability.x_chips
    -- through Card:get_chip_x_bonus. Declaring it here AND returning it from
    -- calculate applies it twice, which is how this once scored X4 Chips while
    -- advertising X2.
    config = { x_chips = 2 },

    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card, 1, CelestasMod.GASH_ODDS, CelestasMod.GASH_BREAK_ID)
        return { vars = { self.config.x_chips, numerator, denominator } }
    end,

    calculate = function(self, card, context)
        -- Self-destruct on the destroy pass, exactly as vanilla Glass does:
        -- the card asks to be removed, rather than a joker removing it.
        if context.destroy_card and context.destroy_card == card
            and context.cardarea == G.play then
            -- A Gash applied by Shoto this very hand gets a pass, so a card
            -- cannot be gashed and destroyed in the same scoring pass. The
            -- flag is consumed here, so it is immune exactly once - and
            -- because Shoto gashes during scoring, that "once" is always the
            -- hand it was created in. Checked ahead of the roll, so Saruei's
            -- 1-in-1 does not override the grace either.
            if card.celesta_gash_fresh then
                card.celesta_gash_fresh = nil
                return
            end
            if SMODS.pseudorandom_probability(card, CelestasMod.GASH_BREAK_ID,
                    1, CelestasMod.GASH_ODDS, CelestasMod.GASH_BREAK_ID) then
                -- Nostro turns the break into a stripping. Returning no
                -- `remove` is what spares the card: the destroy pass only
                -- removes cards that ask to be removed.
                if CelestasMod.nostro_active() then
                    CelestasMod.strip_card(card)
                    return {
                        message = localize("celesta_stripped"),
                        colour = G.C.FILTER,
                        card = card,
                    }
                end
                return { remove = true }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Eutrophic — copies the abilities of the leftmost card.
--------------------------------------------------------------------------------

SMODS.Enhancement {
    key = "eutrophic",
    atlas = "enh_eutrophic",
    pos = { x = 0, y = 0 },
    discovered = true,

    loc_vars = function(self, info_queue, card)
        return {}
    end,

    calculate = function(self, card, context)
        -- Ahead of the early returns below: the leftmost Eutrophic copies
        -- nothing, but it is still a Eutrophic card scoring.
        if context.main_scoring and context.cardarea == G.play then
            play_scoring_sound(CelestasMod.ENHANCEMENT_SOUNDS.Eutrophic)
        end

        local area = card.area
        if not area or not area.cards then return end
        local left = area.cards[1]
        -- Nothing to copy if this IS the leftmost card, which also stops a row
        -- of Eutrophics recursing into each other.
        if not left or left == card then return end

        local center = left.config and left.config.center
        if not center or center.key == self.key then return end

        local effect

        -- Scoring values first. These never reach a calculate function - the
        -- game reads them off the card directly - so copying behaviour alone
        -- would miss them entirely.
        --
        -- Use the same getters eval_card uses on a scored card rather than
        -- reading card.ability by hand. get_chip_bonus() includes the card's
        -- own rank value (base.nominal), which reading ability.bonus misses -
        -- that is why copying a plain King used to contribute nothing at all.
        -- They also fold in enhancement config and any permanent bonuses a
        -- seal has stacked up.
        if context.main_scoring and context.cardarea == G.play then
            effect = {}
            local chips   = left.get_chip_bonus  and left:get_chip_bonus() or 0
            local mult    = left.get_chip_mult   and left:get_chip_mult() or 0
            local x_mult  = left.get_chip_x_mult and left:get_chip_x_mult(context) or 1
            local x_chips = left.get_chip_x_bonus and left:get_chip_x_bonus() or 1

            if chips ~= 0 then effect.chips = chips end
            if mult ~= 0 then effect.mult = mult end
            -- Guarded at 1: these getters return 1 for "nothing", and passing
            -- that through would print a pointless X1 popup every score.
            if x_mult > 1 then effect.x_mult = x_mult end
            if x_chips > 1 then effect.x_chips = x_chips end

            if not next(effect) then effect = nil end
        end

        -- Then the copied centre's own behaviour, run against THIS card so its
        -- effects land here rather than on the card being copied.
        if type(center.calculate) == "function" then
            -- An enhancement reads its own config off card.ability.extra, so
            -- handing it Eutrophic's ability crashes anything expecting its
            -- own fields - Cryptid's Abstract does exactly that. Lend it the
            -- copied card's ability and centre for the duration.
            --
            -- The ability is a COPY: an enhancement that scales itself would
            -- otherwise write that growth onto the card being copied, every
            -- time Eutrophic evaluated.
            -- Same re-entrancy hazard as the frozen roll: a copied centre can
            -- start a fresh evaluation pass that comes straight back here.
            if CelestasMod.eutrophic_copying then return effect end
            CelestasMod.eutrophic_copying = true

            local saved_center, saved_ability = card.config.center, card.ability
            card.config.center = center
            local borrowed = copy_table(left.ability)
            -- copy_table is shallow, so `extra` would still be the copied
            -- card's own table and a scaling enhancement would write its
            -- growth straight back onto it. That is the table effects
            -- actually mutate, so it needs its own copy.
            if type(left.ability.extra) == "table" then
                borrowed.extra = copy_table(left.ability.extra)
            end
            card.ability = borrowed

            local ok, copied = pcall(center.calculate, center, card, context)

            card.config.center, card.ability = saved_center, saved_ability
            CelestasMod.eutrophic_copying = nil

            if not ok then
                -- Copying arbitrary third-party enhancements is best-effort;
                -- one that cannot run against a borrowed card must not take
                -- the run down with it.
                CelestasMod.warn_once(
                    "eutrophic_copy_" .. tostring(center.key),
                    ("Eutrophic could not copy %s: %s")
                        :format(tostring(center.key), tostring(copied)))
            elseif copied then
                if not effect then return copied end
                for k, v in pairs(copied) do effect[k] = v end
            end
        end

        return effect
    end,
}

--------------------------------------------------------------------------------
-- Limestone — +10 Mult, rankless and suitless like a Stone Card.
--------------------------------------------------------------------------------

SMODS.Enhancement {
    key = "limestone",
    atlas = "enh_limestone",
    pos = { x = 0, y = 0 },
    discovered = true,

    -- Same shape as vanilla m_stone: it IS the card, has no rank or suit, and
    -- always scores whether or not it is part of the poker hand.
    replace_base_card = true,
    no_rank = true,
    no_suit = true,
    always_scores = true,

    -- Applied by the game (ability.mult), not returned from calculate.
    config = { mult = 10 },

    loc_vars = function(self, info_queue, card)
        return { vars = { self.config.mult } }
    end,

    -- Limestone's Mult is applied from config by the game, so this exists
    -- only for the sound. always_scores means it fires even when the card is
    -- not part of the poker hand, which is when a Stone Card scores too.
    calculate = function(self, card, context)
        if context.main_scoring and context.cardarea == G.play then
            play_scoring_sound(CelestasMod.ENHANCEMENT_SOUNDS.Limestone)
        end
    end,
}

--------------------------------------------------------------------------------
-- Sandstone — Stone, weathered into something less predictable.
--------------------------------------------------------------------------------
--
-- What Polish turns a Stone Card into, so it is shaped like one: it IS the
-- card, has no rank or suit, and scores whether or not it is part of the poker
-- hand. Limestone is the same silhouette for the same reason.
--
-- Its two lines are ONE roll, not two. The rare branch is rolled and the
-- common one is whatever that is not, which is why the description works out
-- the 4 rather than stating it: a Joker that moves the odds - Oops! All 6s -
-- would otherwise leave the card claiming two chances that do not add up.

CelestasMod.SANDSTONE_ODDS = 5
CelestasMod.SANDSTONE_CHIPS = 80
CelestasMod.SANDSTONE_E_CHIPS = 1.15
CelestasMod.SANDSTONE_ROLL_ID = "celesta_sandstone"

SMODS.Enhancement {
    key = "sandstone",
    atlas = "enh_sandstone",
    pos = { x = 0, y = 0 },
    discovered = true,

    -- Same shape as vanilla m_stone and this mod's Limestone.
    replace_base_card = true,
    no_rank = true,
    no_suit = true,
    always_scores = true,

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(
            card, 1, CelestasMod.SANDSTONE_ODDS, CelestasMod.SANDSTONE_ROLL_ID)
        return { vars = { d - n, d, CelestasMod.SANDSTONE_CHIPS,
                          n, d, CelestasMod.SANDSTONE_E_CHIPS } }
    end,

    calculate = function(self, card, context)
        if not (context.main_scoring and context.cardarea == G.play) then return end

        if not SMODS.pseudorandom_probability(
                card, CelestasMod.SANDSTONE_ROLL_ID, 1,
                CelestasMod.SANDSTONE_ODDS) then
            return { chips = CelestasMod.SANDSTONE_CHIPS }
        end

        -- ^Chips is Talisman's arithmetic. Talisman is a declared dependency,
        -- so this should never be reached - but a card the player is holding
        -- must not silently score nothing if it is, so the common branch is
        -- paid instead. Arielle + Ironmouse returns nothing in the same spot
        -- because ^Mult is the entirety of that pair; here it is one branch in
        -- five of a card that otherwise still works.
        --
        -- get_chip_e_BONUS, not get_chip_e_chips. Talisman's ^Chips half is
        -- named for the chip bonus a playing card carries (talisman.lua:860)
        -- rather than for the scoring key it feeds, and it is only the ^Mult
        -- half that is named after its key (talisman.lua:889). This asked for
        -- a function Talisman has never defined, so the branch below fired on
        -- every ^Chips roll of every run - Sandstone has been paying its
        -- ordinary Chips since it shipped, and saying so in the log.
        if Card.get_chip_e_bonus == nil then
            CelestasMod.warn_once("sandstone_no_talisman",
                "Sandstone's ^Chips needs Talisman; without it that roll pays "
                .. "its ordinary Chips instead")
            return { chips = CelestasMod.SANDSTONE_CHIPS }
        end
        return { e_chips = CelestasMod.SANDSTONE_E_CHIPS }
    end,
}

--------------------------------------------------------------------------------
-- Scoria — Limestone, weathered into something less predictable.
--------------------------------------------------------------------------------
--
-- Sandstone's twin, and deliberately so: Polish makes Sandstone out of a Stone
-- Card and Scoria out of a Limestone one, so the pair are the same card in
-- Chips and in Mult. Everything true of Sandstone is true here - it IS the
-- card, has no rank or suit, scores whether or not the poker hand takes it -
-- and its two lines are ONE roll, the rare branch rolled and the common one
-- whatever that is not, so a Joker that moves the odds cannot leave the card
-- claiming two chances that do not add up.

CelestasMod.SCORIA_ODDS = 5
CelestasMod.SCORIA_MULT = 16
CelestasMod.SCORIA_E_MULT = 1.15
CelestasMod.SCORIA_ROLL_ID = "celesta_scoria"

SMODS.Enhancement {
    key = "scoria",
    atlas = "enh_scoria",
    pos = { x = 0, y = 0 },
    discovered = true,

    -- Same shape as vanilla m_stone, this mod's Limestone, and Sandstone.
    replace_base_card = true,
    no_rank = true,
    no_suit = true,
    always_scores = true,

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(
            card, 1, CelestasMod.SCORIA_ODDS, CelestasMod.SCORIA_ROLL_ID)
        return { vars = { d - n, d, CelestasMod.SCORIA_MULT,
                          n, d, CelestasMod.SCORIA_E_MULT } }
    end,

    calculate = function(self, card, context)
        if not (context.main_scoring and context.cardarea == G.play) then return end

        if not SMODS.pseudorandom_probability(
                card, CelestasMod.SCORIA_ROLL_ID, 1,
                CelestasMod.SCORIA_ODDS) then
            return { mult = CelestasMod.SCORIA_MULT }
        end

        -- ^Mult is Talisman's arithmetic. Talisman is a declared dependency,
        -- so this should never be reached - but a card the player is holding
        -- must not silently score nothing if it is, so the common branch is
        -- paid instead. Sandstone answers its own ^Chips branch the same way.
        if Card.get_chip_e_mult == nil then
            CelestasMod.warn_once("scoria_no_talisman",
                "Scoria's ^Mult needs Talisman; without it that roll pays "
                .. "its ordinary Mult instead")
            return { mult = CelestasMod.SCORIA_MULT }
        end
        return { e_mult = CelestasMod.SCORIA_E_MULT }
    end,
}

--------------------------------------------------------------------------------
-- Foliage — three ways to pay, and it spreads.
--------------------------------------------------------------------------------
--
-- STANDARD PACKS ONLY. get_current_pool hands in_pool the key_append it was
-- called with as `source` (common_events.lua:2283), and a Standard pack is the
-- only thing in the game that asks for an Enhanced card with 'sta'
-- (card.lua:2014). Everything else that reaches for an enhancement -
-- SMODS.poll_enhancement, this mod's own Arar, the enhancement Tarots - passes
-- no source at all, so the card is invisible to all of them.
--
-- ^MONEY is not a thing the game has. ^Chips and ^Mult are Talisman's, and
-- there is no money equivalent anywhere in Talisman or Steamodded, so it is
-- done here the only way that reads the same as its two siblings: the player's
-- dollars are raised to the power, and the difference is what is paid. Whole
-- dollars, because money is whole; and nothing at all at $0 or below, where
-- there is no exponent to take.

CelestasMod.FOLIAGE_EXPONENT = 1.12
CelestasMod.FOLIAGE_SPREAD_ODDS = 2

--- The three payouts, in the order the description lists them.
local FOLIAGE_PAYS = { "money", "chips", "mult" }

--- The player's money as a plain Lua number, or nil when there is no sensible
--- one to raise.
---
--- Talisman replaces G.GAME.dollars with a big-number TABLE, and `table <= 0`
--- is an ERROR in Lua rather than false - which is exactly how this crashed
--- the first time it was played for money. Talisman is a declared dependency
--- of this mod, so that table is the normal case, not the odd one.
---
--- nil is returned rather than 0 for anything that cannot be raised: a debt,
--- a number too large to bring back down, or a big number with no way to
--- convert itself. The caller pays nothing in every one of those cases, which
--- is what it already did for $0.
local function foliage_dollars()
    local held = (G.GAME and G.GAME.dollars) or 0

    if type(held) == "table" then
        if type(held.tonumber) ~= "function" then return nil end
        local ok, plain = pcall(held.tonumber, held)
        if not ok then return nil end
        held = plain
    end

    if type(held) ~= "number" then return nil end
    -- NaN and infinity: a run past the point money is a number any more.
    if held ~= held or held == math.huge or held == -math.huge then return nil end
    return held
end

--- The card to this one's left or right in the hand, chosen at random.
---
--- Both sides are offered when both are there and neither already has leaves
--- on it. An end of the hand has one neighbour; a card between two Foliage
--- cards has none, and the spread simply has nowhere to go - which is better
--- than spending the roll converting something already converted.
function CelestasMod.foliage_neighbour(card)
    if not (G.hand and G.hand.cards) then return nil end

    local index = nil
    for i, held in ipairs(G.hand.cards) do
        if held == card then index = i break end
    end
    if not index then return nil end

    local options = {}
    for _, i in ipairs({ index - 1, index + 1 }) do
        local side = G.hand.cards[i]
        if side and not SMODS.has_enhancement(
                side, CelestasMod.ENHANCEMENT_KEYS.Foliage) then
            options[#options + 1] = side
        end
    end
    if #options == 0 then return nil end
    return pseudorandom_element(options, pseudoseed("celesta_foliage_side"))
end

SMODS.Enhancement {
    key = "foliage",
    atlas = "enh_foliage",
    pos = { x = 0, y = 0 },
    discovered = true,

    -- Same shape as vanilla m_stone, and as this mod's Limestone, Sandstone
    -- and Scoria: it IS the card, has no rank and no suit, and scores whether
    -- or not the poker hand takes it.
    --
    -- Which makes the spread below expensive rather than free: a card that
    -- catches the leaves loses the rank and the suit it had, so a hand can be
    -- eaten by its own good luck.
    replace_base_card = true,
    no_rank = true,
    no_suit = true,
    always_scores = true,

    in_pool = function(self, args)
        return (args or {}).source == "sta"
    end,

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(
            card, 1, CelestasMod.FOLIAGE_SPREAD_ODDS, "celesta_foliage_spread")
        return { vars = { CelestasMod.FOLIAGE_EXPONENT, n, d } }
    end,

    calculate = function(self, card, context)
        ------------------------------------------------------------------
        -- Scoring: one of the three, chosen fresh every time
        ------------------------------------------------------------------
        if context.main_scoring and context.cardarea == G.play then
            play_scoring_sound(CelestasMod.ENHANCEMENT_SOUNDS.Foliage)

            local pick = pseudorandom_element(
                FOLIAGE_PAYS, pseudoseed("celesta_foliage"))
            local power = CelestasMod.FOLIAGE_EXPONENT

            if pick == "money" then
                -- Raised, not added to. Below a dollar there is no exponent
                -- worth taking, and a negative to a fractional power is not a
                -- number at all.
                local held = foliage_dollars()
                if not held or held <= 0 then return end

                local raised = held ^ power
                -- Off the end of what a double can hold: nothing is paid
                -- rather than a payout of infinity being handed to
                -- ease_dollars.
                if raised ~= raised or raised == math.huge then return end

                local gain = math.floor(raised) - held
                if gain <= 0 then return end

                -- `dollars` alone, with no message of its own. SMODS raises
                -- the "+$N" popup for that key already
                -- (utils.lua:1244), and `message` is a key in its own right
                -- that raises a SECOND one - so returning both announced the
                -- same payout twice.
                return { dollars = gain }
            end

            -- ^Chips and ^Mult are Talisman's arithmetic, and Talisman is a
            -- declared dependency - but a card the player is holding must not
            -- silently score nothing, so a run without it pays the money
            -- branch instead. Sandstone and Scoria answer their own branches
            -- the same way.
            if pick == "chips" then
                -- get_chip_e_BONUS: see the note on Sandstone above. The name
                -- that reads like the scoring key is not the one Talisman
                -- defines, and asking for it meant this branch scored nothing
                -- at all - a Foliage card that rolled Chips did nothing
                -- whatever, which is what it looked like from the table.
                if Card.get_chip_e_bonus == nil then
                    CelestasMod.warn_once("foliage_no_talisman",
                        "Foliage's ^Chips and ^Mult need Talisman; without it "
                        .. "those rolls pay nothing")
                    return
                end
                return { e_chips = power }
            end

            if Card.get_chip_e_mult == nil then
                CelestasMod.warn_once("foliage_no_talisman",
                    "Foliage's ^Chips and ^Mult need Talisman; without it "
                    .. "those rolls pay nothing")
                return
            end
            return { e_mult = power }
        end

        ------------------------------------------------------------------
        -- The end of the round: it spreads
        ------------------------------------------------------------------
        if context.end_of_round and context.cardarea == G.hand
            and not context.blueprint and not context.repetition then
            -- A card that became Foliage a moment ago does not get a turn of
            -- its own this round. The end-of-round pass walks the hand once,
            -- so without this a single card could take the whole hand in one
            -- go, each new leaf spreading to the next. Shoto's freshly-gashed
            -- cards are spared the same way.
            if card.celesta_foliage_fresh then
                card.celesta_foliage_fresh = nil
                return
            end

            if not SMODS.pseudorandom_probability(
                    card, "celesta_foliage_spread", 1,
                    CelestasMod.FOLIAGE_SPREAD_ODDS) then
                return
            end

            local neighbour = CelestasMod.foliage_neighbour(card)
            if not neighbour then return end

            neighbour:set_ability(
                G.P_CENTERS[CelestasMod.ENHANCEMENT_KEYS.Foliage], nil, true)
            neighbour.celesta_foliage_fresh = true
            neighbour:juice_up(0.3, 0.4)
            return {
                message = localize("celesta_spread"),
                colour = G.C.GREEN,
                card = neighbour,
            }
        end
    end,
}

--------------------------------------------------------------------------------
-- Driftwood — may break if still held at the end of the round.
--------------------------------------------------------------------------------

--- True when a Sinder is in play and able to act.
--- Asked at the moment a Driftwood would break rather than cached: Sinder can
--- be bought, sold or debuffed between one end of round and the next.
function CelestasMod.sinder_active()
    for _, joker in ipairs(SMODS.find_card("j_celesta_sinder")) do
        if not joker.debuff then return true end
    end
    return false
end

CelestasMod.DRIFTWOOD_ODDS = 2

SMODS.Enhancement {
    key = "driftwood",
    atlas = "enh_driftwood",
    pos = { x = 0, y = 0 },
    discovered = true,

    loc_vars = function(self, info_queue, card)
        local n, d = SMODS.get_probability_vars(
            card, 1, CelestasMod.DRIFTWOOD_ODDS, "celesta_driftwood")
        return { vars = { n, d } }
    end,

    calculate = function(self, card, context)
        if context.main_scoring and context.cardarea == G.play then
            play_scoring_sound(CelestasMod.ENHANCEMENT_SOUNDS.Driftwood)
        end

        -- The end-of-round pass over cards still in hand. Destroying through
        -- SMODS.destroy_cards rather than returning `remove` because this is
        -- not the scoring destroy pass - nothing is collecting flags here.
        if context.end_of_round and context.cardarea == G.hand
            and not context.blueprint and not context.repetition then
            -- Sinder takes the risk away entirely. Checked before the roll so
            -- the RNG is not consumed either - a Driftwood that cannot break
            -- should not be quietly shifting every later roll in the run.
            if CelestasMod.sinder_active() then return end
            if SMODS.pseudorandom_probability(card, "celesta_driftwood", 1,
                    CelestasMod.DRIFTWOOD_ODDS, "celesta_driftwood") then
                G.E_MANAGER:add_event(Event {
                    func = function()
                        SMODS.destroy_cards(card)
                        return true
                    end
                })
                return {
                    message = localize("celesta_broke"),
                    colour = G.C.FILTER,
                    card = card,
                }
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Driftwood: counting as any rank
--------------------------------------------------------------------------------
--
-- SMODS has `any_suit` for wild suits but no rank equivalent, and rank is not
-- resolved in one place: get_X_same compares get_id() pairwise, while
-- get_straight buckets cards by rank key. Patching both invites double
-- counting - a card added to every bucket appears at every position of a
-- straight, and a wild shared between two rank groups can invent a Two Pair
-- that the player cannot actually make.
--
-- So rather than teach each evaluator about wilds, resolve the wild BEFORE
-- evaluation: temporarily give every Driftwood in the hand a concrete rank,
-- run the untouched evaluator, and keep whichever rank produced the best hand.
-- Every hand type then works with no changes and nothing can be counted twice.
--
-- All Driftwoods in a hand take the SAME rank. Searching per-card assignments
-- is 13^n evaluations; one shared rank is 13 and still covers what players
-- actually do - completing a pair, trips or quads, five of a kind from a hand
-- of Driftwoods, or filling a single gap in a straight. Two Driftwoods filling
-- two DIFFERENT gaps in one straight is the case this does not find.
--
-- Only ever runs when a Driftwood is actually in the hand, so normal play
-- costs one extra table scan and nothing else.

local function is_driftwood(card)
    return card and card.config and card.config.center
        and card.config.center.key == CelestasMod.ENHANCEMENT_KEYS.Driftwood
end

--- Index of the best hand in a results table, by G.handlist order (1 = best).
--- Where a set of results places in G.handlist, best first.
---
--- Read the way the game reads it: the first entry in handlist that is
--- NON-EMPTY. Steamodded replaces evaluate_poker_hand wholesale, and its
--- version fills every hand with `evaluate(...) or {}` before setting
--- results.top from the first key that is merely non-nil - so top is not the
--- hand that was made, and G.FUNCS.get_poker_hand_info ignores it entirely in
--- favour of `next(poker_hands[v])`.
---
--- Trusting top meant every candidate rank scored the same index, so the first
--- rank tried always won: a Driftwood filling J-10-9-_-7 came out as a 2 and
--- the hand read as a plain Flush instead of a Straight Flush.
local function hand_index(results)
    if not results then return math.huge end
    for i, name in ipairs(G.handlist) do
        local made = results[name]
        if made and next(made) then return i end
    end
    return math.huge
end

local evaluate_poker_hand_ref = evaluate_poker_hand
function evaluate_poker_hand(hand)
    local wilds = {}
    for _, card in ipairs(hand or {}) do
        if is_driftwood(card) then wilds[#wilds + 1] = card end
    end
    if #wilds == 0 then return evaluate_poker_hand_ref(hand) end

    -- Remember what to put back. base.value matters as well as base.id:
    -- get_straight looks ranks up by key, not just by numeric id.
    local saved = {}
    for i, card in ipairs(wilds) do
        saved[i] = { id = card.base.id, value = card.base.value }
    end
    local function restore()
        for i, card in ipairs(wilds) do
            card.base.id, card.base.value = saved[i].id, saved[i].value
        end
    end

    local best_rank, best_index = nil, math.huge
    for _, rank_key in ipairs(SMODS.Rank.obj_buffer) do
        local rank = SMODS.Ranks[rank_key]
        if rank and rank.id then
            for _, card in ipairs(wilds) do
                card.base.id, card.base.value = rank.id, rank_key
            end
            local index = hand_index(evaluate_poker_hand_ref(hand))
            if index < best_index then
                best_index, best_rank = index, rank_key
            end
        end
    end

    if not best_rank then
        restore()
        return evaluate_poker_hand_ref(hand)
    end

    -- Re-apply the winner and evaluate once more, so the results returned are
    -- the ones the rest of scoring will use.
    local winner = SMODS.Ranks[best_rank]
    for _, card in ipairs(wilds) do
        card.base.id, card.base.value = winner.id, best_rank
    end
    local results = evaluate_poker_hand_ref(hand)

    -- Put the real rank back: the Driftwood keeps its own nominal chip value
    -- and reads as its printed rank to everything downstream.
    restore()
    return results
end

--------------------------------------------------------------------------------
-- Driftwood: show the suit in the centre, the way an Ace does
--------------------------------------------------------------------------------
--
-- A card's front sprite is picked from its rank+suit, so a Driftwood would
-- otherwise print whatever rank it happens to carry - misleading for a card
-- that counts as all of them. Pointing the front at the Ace of the same suit
-- gives the large central pip while keeping the suit visible.

-- Index into the driftwood_fronts atlas, matching SUIT_ORDER in
-- tools/gen_driftwood_fronts.py. This mod's own suits are drawn from their own
-- sheets and appended after the vanilla four, so a Driftwood Star or Leaf gets
-- the same rankless front rather than falling back to a printed rank.
local DRIFTWOOD_SUIT_POS = { Hearts = 0, Clubs = 1, Diamonds = 2, Spades = 3 }
DRIFTWOOD_SUIT_POS[CelestasMod.STARS_SUIT] = 4
DRIFTWOOD_SUIT_POS[CelestasMod.LEAF_SUIT] = 5
local DRIFTWOOD_FRONT_ATLAS = SMODS.current_mod.prefix .. "_driftwood_fronts"

local set_sprites_ref = Card.set_sprites
function Card:set_sprites(_center, _front)
    set_sprites_ref(self, _center, _front)

    local center = _center or (self.config and self.config.center)
    if not center or center.key ~= CelestasMod.ENHANCEMENT_KEYS.Driftwood then return end
    if not self.children or not self.children.front then return end

    -- Repoint the front at the stripped-Ace sheet rather than swapping in a
    -- real Ace: that gave the central pip but printed an "A" in the corners,
    -- which is wrong for a card that counts as every rank.
    local suit = (_front and _front.suit) or (self.base and self.base.suit)
    local pos = DRIFTWOOD_SUIT_POS[suit]
    local atlas = G.ASSET_ATLAS[DRIFTWOOD_FRONT_ATLAS]
    -- Another mod's suit is not in the sheet; those keep their normal front.
    if not pos or not atlas then return end

    self.children.front.atlas = atlas
    self.children.front:set_sprite_pos({ x = pos, y = 0 })
end
