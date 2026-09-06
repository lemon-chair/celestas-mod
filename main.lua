--- Celesta's Mod — entry point.
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
SMODS.Atlas { key = 'modicon',     path = 'icon.png',        px = 32, py = 32 }

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

--------------------------------------------------------------------------------
-- Arena effects — screen-wide, round-scoped weather. Loaded before jokers
-- because Aquwa and friends call into CelestasMod.Arena.
--------------------------------------------------------------------------------

assert(SMODS.load_file('arena/arena.lua'))()

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

-- Standalone consumables. After enhancements/, which is where the keys the
-- enhancement Tarots hand out are resolved.
assert(SMODS.load_file('consumables/raise.lua'))()
assert(SMODS.load_file('consumables/enhancers.lua'))()
assert(SMODS.load_file('consumables/occult.lua'))()
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
-- Jokers — auto-loaded from jokers/.
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
-- Everything else — explicit list, order matters here.
--------------------------------------------------------------------------------

-- 'items/consumables.lua' (the Reforge Tarot) is disabled while it still has
-- placeholder art — add it back to this list to re-enable. Its code, atlas and
-- localization are all still in place.
for _, file in ipairs({ 'seals/seals.lua', 'items/decks.lua',
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
                label = localize('celesta_cfg_verbose'),
                ref_table = MOD.config,
                ref_value = 'verbose_logging',
            },
            create_toggle {
                label = localize('celesta_cfg_downpour'),
                ref_table = MOD.config,
                ref_value = 'debug_downpour',
            },
        },
    }
end

sendInfoMessage('Loaded ' .. MOD.name, 'CelestasMod')
