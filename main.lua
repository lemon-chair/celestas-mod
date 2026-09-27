--- Celesta's Mod: entry point.
--- Structure follows the Legends mod: globals first, then every .lua file in
--- jokers/ is auto-loaded, then the hand-maintained items/ files.

CelestasMod = {}

-- Ray retriggers other Jokers, and Steamodded only runs that calculation when
-- a loaded mod asks for it - SMODS.calculate_retriggers returns immediately
-- otherwise. Declared here rather than beside the joker because
-- SMODS.get_optional_features() reads this once, after every mod's main file
-- has finished.
SMODS.current_mod.optional_features = {
    retrigger_joker = true,
    -- Spongey reacts to other Jokers triggering, and Steamodded only raises
    -- that context when a loaded mod asks for it. Cryptid happens to ask for
    -- both of these, which would mask the omission on any install that has it
    -- and leave the joker silently dead everywhere else.
    post_trigger = true,
}

-- Load globals (custom colours + loc_colour hook)
assert(SMODS.load_file("globals.lua"))()

--------------------------------------------------------------------------------
-- Shared atlases (the placeholder sheets + mod icon).
-- Per-joker atlases live in jokers/atlases.lua, one per image.
--------------------------------------------------------------------------------

SMODS.Atlas { key = 'jokers',      path = 'jokers.png',      px = 71, py = 95 }
SMODS.Atlas { key = 'consumables', path = 'consumables.png', px = 71, py = 95 }
SMODS.Atlas { key = 'decks',       path = 'decks.png',       px = 71, py = 95 }
-- Card Sleeves' frame is two pixels wider than a card. Registered whether or
-- not Card Sleeves is installed: an unused atlas costs nothing.
SMODS.Atlas { key = 'sleeves',     path = 'sleeves.png',     px = 73, py = 95 }
SMODS.Atlas { key = 'modicon',     path = 'icon.png',        px = 34, py = 34 }

-- Seal emblems, card-shaped cells (built by tools/gen_seals.py).
SMODS.Atlas { key = 'seals',       path = 'seals.png',       px = 71, py = 95 }

-- Card enhancements (built by tools/gen_enhancements.py).
-- enh_exo is only the card body; its frame is a separate sprite drawn larger
-- than the card, because an enhancement's cell is always squashed onto the
-- card rect. Every cell here is card-sized - Sprite:draw_from centres a box
-- sized to the card, so an oversized cell renders both too big and off-centre.
SMODS.Atlas { key = 'enh_exo',  path = 'enh_exo.png',  px = 71, py = 95 }
SMODS.Atlas { key = 'enh_exo_frame', path = 'enh_exo_frame.png', px = 71, py = 95 }
SMODS.Atlas { key = 'enh_gash', path = 'enh_gash.png', px = 71, py = 95 }
SMODS.Atlas { key = 'enh_eutrophic', path = 'enh_eutrophic.png', px = 71, py = 95 }
SMODS.Atlas { key = 'enh_limestone', path = 'enh_limestone.png', px = 71, py = 95 }
SMODS.Atlas { key = 'enh_driftwood', path = 'enh_driftwood.png', px = 71, py = 95 }
SMODS.Atlas { key = 'enh_sandstone', path = 'enh_sandstone.png', px = 71, py = 95 }
SMODS.Atlas { key = 'enh_scoria', path = 'enh_scoria.png', px = 71, py = 95 }
SMODS.Atlas { key = 'enh_foliage', path = 'enh_foliage.png', px = 71, py = 95 }
-- Ace fronts with the rank glyph stripped, for Driftwood (tools/gen_driftwood_fronts.py).
SMODS.Atlas { key = 'driftwood_fronts', path = 'driftwood_fronts.png', px = 71, py = 95 }

-- Blind chips are animated sprites, hence frames/ANIMATION_ATLAS.
SMODS.Atlas { key = 'blind_clover', path = 'blind_clover.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_greed', path = 'blind_greed.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_goat', path = 'blind_goat.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_frog', path = 'blind_frog.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_star', path = 'blind_star.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_heart', path = 'blind_heart.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_robot', path = 'blind_robot.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_brick', path = 'blind_brick.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_wyrm', path = 'blind_wyrm.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_horn', path = 'blind_horn.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_gem', path = 'blind_gem.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }
SMODS.Atlas { key = 'blind_flower', path = 'blind_flower.png', px = 34, py = 34,
              frames = 21, atlas_table = 'ANIMATION_ATLAS' }

-- Arena effect sprite sheets (generated from GIFs by tools/gen_fx.py).
SMODS.Atlas { key = 'fx_downpour', path = 'fx_downpour.png',  px = 256, py = 256 }
SMODS.Atlas { key = 'fx_snowstorm', path = 'fx_snowstorm.png', px = 256, py = 256 }

SMODS.Atlas { key = 'bind', path = 'bind.png', px = 71, py = 95 }
SMODS.Atlas { key = 'milk_bottle', path = 'milk_bottle.png', px = 71, py = 95 }
SMODS.Atlas { key = 'burgundy_brew', path = 'burgundy_brew.png', px = 71, py = 95 }

-- Wear overlays, drawn on top of a worn-out playing card.
SMODS.Atlas { key = 'tatter',            path = 'tatter.png',            px = 71, py = 95 }
SMODS.Atlas { key = 'lucky_card_tatter', path = 'lucky_card_tatter.png', px = 71, py = 95 }
SMODS.Atlas { key = 'limestone_tatter',  path = 'limestone_tatter.png',  px = 71, py = 95 }

-- Frozen is an overlay drawn on top of a card, not an edition (see
-- editions/frozen.lua for why it cannot be one).
SMODS.Atlas { key = 'frozen', path = 'frozen.png', px = 71, py = 95 }
-- The same pane cut to a circle, for the Jokers whose art is one. See
-- CelestasMod.ROUND_JOKERS in globals.lua.
SMODS.Atlas { key = 'frozen_round', path = 'frozen_round.png', px = 71, py = 95 }

--------------------------------------------------------------------------------
-- The suits this mod adds. Loaded before everything that reads suits, and
-- before the Jokers, so CelestasMod.STARS_SUIT and CelestasMod.LEAF_SUIT are
-- resolved by the time anything asks. shared.lua first: it holds the registry
-- both of them enrol in and the single start_run hook that keeps them out of
-- the starting deck.
--------------------------------------------------------------------------------

assert(SMODS.load_file('suits/shared.lua'))()
assert(SMODS.load_file('suits/stars.lua'))()
assert(SMODS.load_file('suits/leaf.lua'))()
-- After stars.lua: the one way into True Stars starts from an Ace of Stars.
assert(SMODS.load_file('suits/true_stars.lua'))()

--------------------------------------------------------------------------------
-- Arena effects: screen-wide, round-scoped weather. Loaded before jokers
-- because Aquwa and friends call into CelestasMod.Arena.
--------------------------------------------------------------------------------

assert(SMODS.load_file('arena/arena.lua'))()

-- The Deck of Sins' stats. Before jokers and before items/decks.lua, which
-- defines the deck itself and only has to hand the stats a run to count in.
assert(SMODS.load_file('sins/sins.lua'))()
-- After sins.lua: both read the stats that file defines.
assert(SMODS.load_file('sins/effects.lua'))()
assert(SMODS.load_file('sins/sidebar.lua'))()

-- Enhancements load before jokers: Shoto, Saruei and MOTHERv3 all
-- reference CelestasMod.ENHANCEMENT_KEYS.
assert(SMODS.load_file('enhancements/enhancements.lua'))()
assert(SMODS.load_file('blinds/blinds.lua'))()
assert(SMODS.load_file('editions/frozen.lua'))()
-- After enhancements: it classifies their keys into cracked/chipped.
assert(SMODS.load_file('wear/tattered.lua'))()
-- After the jokers exist, so a merged joker can run any of their centres.
assert(SMODS.load_file('merge/bind.lua'))()
-- After bind.lua: it lists the pairs that file registers.
assert(SMODS.load_file('merge/collection.lua'))()
-- After bind.lua too, for the same reason: clicking a Joker in the collection
-- shows the pairs it belongs to.
assert(SMODS.load_file('merge/web.lua'))()

-- Standalone consumables. After enhancements/, which is where the keys the
-- enhancement Tarots hand out are resolved.
assert(SMODS.load_file('consumables/raise.lua'))()
assert(SMODS.load_file('consumables/enhancers.lua'))()
assert(SMODS.load_file('consumables/occult.lua'))()
-- After sins/sins.lua, whose lockout it lifts.
assert(SMODS.load_file('consumables/unholy.lua'))()
-- Gene hands out a seal rather than an enhancement; it reads the seal's key at
-- use time, so it does not need seals/seals.lua to have loaded first.
assert(SMODS.load_file('consumables/gene.lua'))()
-- The Community hands out Tags, which needs nothing of this mod's at all.
assert(SMODS.load_file('consumables/community.lua'))()
-- The Lost Soul reaches into jokers/lost.lua, which has not loaded yet - but
-- only from can_use and use, both of which need a run in progress.
assert(SMODS.load_file('consumables/lost_soul.lua'))()
-- Lifts vanilla's five-card ceiling on what a consumable may be used on, which
-- this mod's raised selection limits and Haruka's doubling both run into.
assert(SMODS.load_file('consumables/targets.lua'))()

--------------------------------------------------------------------------------
-- Stamps: a consumable type of their own, the pack they come out of, and the
-- marks they leave on a Joker. downsides.lua first: it holds the costs a stamp
-- is chosen against, and stamps.lua reads the list at load.
--------------------------------------------------------------------------------

assert(SMODS.load_file('stamps/downsides.lua'))()
assert(SMODS.load_file('stamps/stamps.lua'))()

--------------------------------------------------------------------------------
-- Jokers: auto-loaded from jokers/.
-- Sorted, which does two things. atlases.lua registers before anything
-- references it, and zz_vtubers.lua - the placeholder roster - loads LAST, so
-- every finished Joker is contiguous in the Collection and the unfinished ones
-- are the tail. Named for its position: a Joker added after it would otherwise
-- land on the far side of seventeen stand-ins, which is where the last two
-- went missing.
--------------------------------------------------------------------------------

local joker_src = NFS.getDirectoryItems(SMODS.current_mod.path .. "jokers")
table.sort(joker_src)
for _, file in ipairs(joker_src) do
    if file:match("%.lua$") then
        assert(SMODS.load_file("jokers/" .. file))()
    end
end

--------------------------------------------------------------------------------
-- Everything else: explicit list, order matters here.
--------------------------------------------------------------------------------

-- 'items/consumables.lua' (the Reforge Tarot) is disabled while it still has
-- placeholder art: add it back to this list to re-enable. Its code, atlas and
-- localization are all still in place.
for _, file in ipairs({ 'seals/seals.lua', 'items/decks.lua',
                        -- After decks.lua: each sleeve is built from its
                        -- deck. Does nothing without Card Sleeves.
                        'items/sleeves.lua',
                        'items/challenges.lua',
                        -- Names Joker keys, so it reads best after the Jokers
                        -- exist; it only rearranges a menu, so it does not
                        -- actually need them to.
                        'items/collection_order.lua' }) do
    assert(SMODS.load_file(file))()
end

--------------------------------------------------------------------------------
-- Mod config tab
--------------------------------------------------------------------------------

-- Captured now: config_tab runs when the player opens the Config page, by
-- which point SMODS.current_mod is no longer guaranteed to be set.
local MOD = SMODS.current_mod

-- Resolved now for the same reason: the button runs long after loading.
local JOKER_PREFIX = 'j_' .. MOD.prefix .. '_'

--- Unlocks every Joker this mod adds, and only those.
---
--- Set straight onto the centres rather than through unlock_card, which pops
--- an unlock notice per card - for every Joker at once, a wall of them.
--- save_progress is what writes the flags into the profile.
G.FUNCS.celesta_unlock_all_jokers = function(e)
    local changed = false
    for key, center in pairs(G.P_CENTERS) do
        if center.set == 'Joker' and center.unlocked == false
            and key:sub(1, #JOKER_PREFIX) == JOKER_PREFIX then
            center.unlocked = true
            changed = true
        end
    end
    if changed then
        G:save_progress()
        if G.FILE_HANDLER then G.FILE_HANDLER.force = true end
    end
end

--- Discovers every Joker this mod adds, and only those.
---
--- Discovery is a separate flag from unlocking: an unlocked Joker can turn up
--- in a run, and an undiscovered one is still a "?" in the Collection. The
--- button above sets one and this sets the other.
---
--- Set straight onto the centres rather than through discover_card, which
--- raises an alert per card and adds each to the round's new-collection score
--- - neither of which means anything for a button pressed in the menu.
---
--- set_discover_tallies is what discover_card ends on, and the one piece of it
--- that cannot be skipped: the Collection's "n of m" counters are read from
--- what it computes, so without it every page would keep the old numbers.
G.FUNCS.celesta_discover_all_jokers = function(e)
    local changed = false
    for key, center in pairs(G.P_CENTERS) do
        if center.set == 'Joker' and not center.discovered
            and key:sub(1, #JOKER_PREFIX) == JOKER_PREFIX then
            center.discovered = true
            changed = true
        end
    end
    if changed then
        if set_discover_tallies then set_discover_tallies() end
        G:save_progress()
        if G.FILE_HANDLER then G.FILE_HANDLER.force = true end
    end
end

--- Marks every merge as found, so the Collection's Special Merges tab shows
--- all of them rather than a page of "???".
---
--- A merge is not unlocked or discovered the way a Joker is - there is no
--- centre to set a flag on. What the tab reads is whether this profile has
--- ever MADE the pair, which lives in Bind's own per-profile store, so this
--- asks Bind to fill it in rather than reaching into the profile itself.
G.FUNCS.celesta_unlock_all_merges = function(e)
    local Bind = CelestasMod.Bind
    if not (Bind and Bind.mark_every_special_seen) then return end
    if Bind.mark_every_special_seen() > 0 and G.FILE_HANDLER then
        G.FILE_HANDLER.force = true
    end
end

--- The art this mod did not draw itself, credited by line.
---
--- Localized like every other string in the mod, which for a list of names
--- mostly means it is one place to edit rather than one place to translate.
--- Written as one key per line because that is what the UI needs: a text node
--- holds a line, and the page has to decide where the wrap falls rather than
--- leave it to the width of the box.
local CREDIT_LINES = {
    "celesta_credit_calamitas",
    "celesta_credit_thanatos",
    "celesta_credit_eidolonwyrm",
    "celesta_credit_astrum",
    "celesta_credit_urschleim",
}

--- A line of credits text.
local function credit_row(str, colour)
    return {
        n = G.UIT.R,
        config = { align = "cl", padding = 0.04 },
        nodes = {
            { n = G.UIT.T, config = { text = str, scale = 0.4,
                                      colour = colour or G.C.UI.TEXT_LIGHT } },
        },
    }
end

MOD.extra_tabs = function()
    local rows = {}
    for _, key in ipairs(CREDIT_LINES) do
        rows[#rows + 1] = credit_row(localize(key))
    end

    -- A blank line, then the note that the rest is out there somewhere.
    rows[#rows + 1] = credit_row(" ")
    rows[#rows + 1] = credit_row(localize("celesta_credit_rest_1"), G.C.UI.TEXT_INACTIVE)
    rows[#rows + 1] = credit_row(localize("celesta_credit_rest_2"), G.C.UI.TEXT_INACTIVE)

    return {
        label = localize("celesta_credits_tab"),
        tab_definition_function = function()
            return {
                n = G.UIT.ROOT,
                config = { align = "cm", padding = 0.1, colour = G.C.CLEAR },
                nodes = rows,
            }
        end,
    }
end

--------------------------------------------------------------------------------
-- The startup speed notice
--------------------------------------------------------------------------------
--
-- Several of this mod's Jokers score through long animations, and on a slow
-- game speed a large hand can look like the game has hung. So the player is
-- shown where the speed slider is before that happens rather than left to
-- work it out, once, the first time the main menu is reached in a launch.
--
-- MOD.config.show_disclaimer is the single flag behind it. The checkbox in
-- the notice and the toggle in the Config tab are two views of that one
-- value, worded opposite ways round - which is why the checkbox cannot simply
-- point at the config table the way every other toggle here does.

--- The body, one key per line. A text node holds a line and nothing in
--- Balatro's UI wraps, so where each break falls is decided here rather than
--- by the width of the box. `false` is the blank line between the paragraphs.
local NOTICE_LINES = {
    "celesta_notice_1", "celesta_notice_2", "celesta_notice_3",
    "celesta_notice_4", "celesta_notice_5",
    false,
    "celesta_notice_6", "celesta_notice_7", "celesta_notice_8",
    "celesta_notice_9",
}

--- One line of the notice.
local function notice_row(text, colour, scale)
    return {
        n = G.UIT.R,
        config = { align = "cl", padding = 0.03 },
        nodes = {
            { n = G.UIT.T, config = { text = text, scale = scale or 0.4,
                                      colour = colour or G.C.UI.TEXT_LIGHT } },
        },
    }
end

--- The checkbox's own state. It reads "do not show this again" where the
--- setting reads "show this", so it holds the negation and writes back.
local notice_box = { hide = false }

--- The notice, built fresh each time so the checkbox opens showing the
--- setting as it currently stands.
function CelestasMod.notice_definition()
    notice_box.hide = not MOD.config.show_disclaimer

    local rows = { notice_row(localize("celesta_notice_title"), G.C.RED, 0.6),
                   notice_row(" ") }
    for _, key in ipairs(NOTICE_LINES) do
        rows[#rows + 1] = notice_row(key and localize(key) or " ")
    end
    rows[#rows + 1] = notice_row(" ")

    -- Both of these are columns, so they sit side by side on one row: a
    -- sibling C is placed beside the last one, where a sibling R goes below
    -- it - which is also why every line above is an R.
    rows[#rows + 1] = {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.1 },
        nodes = {
            create_toggle {
                col = true,
                -- The default 3 is a label column wide enough for the Settings
                -- menu's right-aligned labels; here it would open a gap in the
                -- middle of the row.
                w = 0,
                label = localize("celesta_notice_hide"),
                ref_table = notice_box,
                ref_value = "hide",
                -- Written through as it is ticked rather than on the way out,
                -- so Escape keeps the choice exactly as the button does.
                callback = function(hidden)
                    MOD.config.show_disclaimer = not hidden
                    SMODS.save_mod_config(MOD)
                end,
            },
            { n = G.UIT.C, config = { minw = 0.8 } },
            UIBox_button {
                col = true,
                label = { localize("celesta_notice_ok") },
                button = "exit_overlay_menu",
                minw = 2.5,
                colour = G.C.ORANGE,
            },
        },
    }

    -- no_back, because the Ok button IS the way out and a second one under it
    -- would say so twice. Escape still closes this: it calls
    -- exit_overlay_menu itself rather than pressing the back button
    -- (engine/controller.lua:800), and only a menu marked no_esc is exempt.
    return create_UIBox_generic_options { no_back = true, minw = 9.5,
                                          contents = rows }
end

--- Whether this launch has shown it yet. A local rather than G.GAME or the
--- profile: "the first time the game was opened" is a fact about this process,
--- and G.GAME is rebuilt every time the main menu is prepared.
local notice_shown = false

-- Game:main_menu is the one way in. It is reached from the splash animation
-- with 'splash', and called directly when the splash is skipped or when a run
-- is left (game.lua:1547), so hooking it covers all three - and it is always
-- AFTER the opening animation, which is the half that matters.
--
-- Read defensively before being wrapped, the way seals.lua wraps its two: a
-- nil reference here would take the whole mod down on the first call through.
local celesta_notice_menu_ref = Game and Game.main_menu
if type(celesta_notice_menu_ref) == "function" then
    function Game:main_menu(change_context, ...)
        local out = celesta_notice_menu_ref(self, change_context, ...)
        if notice_shown or not MOD.config.show_disclaimer then return out end
        notice_shown = true

        G.E_MANAGER:add_event(Event {
            trigger = "after",
            -- Long enough for the menu to settle, and on the REAL timer so the
            -- wait is the same wait however the game speed is set - which for
            -- this notice of all of them would be a poor joke otherwise.
            timer = "REAL",
            delay = 1.2,
            blocking = false,
            blockable = false,
            func = function()
                -- Into a run already: a greeting that arrives over the deck
                -- select is worse than one that never arrives.
                if G.STAGE ~= G.STAGES.MAIN_MENU then return true end
                -- Looking at something else - the settings, the mod list.
                -- Returning false holds the event over to the next frame
                -- rather than burying what they opened.
                if G.OVERLAY_MENU then return false end
                G.FUNCS.overlay_menu {
                    definition = CelestasMod.notice_definition() }
                return true
            end,
        })
        return out
    end
end

MOD.config_tab = function()
    return {
        n = G.UIT.ROOT,
        config = { align = 'cm', padding = 0.05, colour = G.C.CLEAR },
        nodes = {
            create_toggle {
                label = localize('celesta_cfg_animation'),
                ref_table = MOD.config,
                ref_value = 'arena_animation',
            },
            create_toggle {
                label = localize('celesta_cfg_notice'),
                ref_table = MOD.config,
                ref_value = 'show_disclaimer',
            },
            create_toggle {
                label = localize('celesta_cfg_verbose'),
                ref_table = MOD.config,
                ref_value = 'verbose_logging',
            },
            create_toggle {
                label = localize('celesta_cfg_downpour'),
                ref_table = MOD.config,
                ref_value = 'debug_downpour',
            },
            UIBox_button {
                label = { localize('celesta_cfg_unlock_all') },
                button = 'celesta_unlock_all_jokers',
                minw = 4,
                colour = G.C.RED,
            },
            UIBox_button {
                label = { localize('celesta_cfg_discover_all') },
                button = 'celesta_discover_all_jokers',
                minw = 4,
                colour = G.C.RED,
            },
            UIBox_button {
                label = { localize('celesta_cfg_unlock_merges') },
                button = 'celesta_unlock_all_merges',
                minw = 4,
                colour = G.C.RED,
            },
        },
    }
end

sendInfoMessage('Loaded ' .. MOD.name, 'CelestasMod')
