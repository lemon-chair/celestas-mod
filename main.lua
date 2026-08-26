--- Celesta's Mod — entry point.
--- Structure follows the Legends mod: globals first, then every .lua file in
--- jokers/ is auto-loaded, then the hand-maintained items/ files.

CelestasMod = {}

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

-- Card enhancements (built by tools/gen_enhancements.py). Exo's cell is
-- larger than a card so its frame reads as overhanging the edges.
SMODS.Atlas { key = 'enh_exo',  path = 'enh_exo.png',  px = 84, py = 104 }
SMODS.Atlas { key = 'enh_gash', path = 'enh_gash.png', px = 71, py = 95 }

-- Arena effect sprite sheets (generated from GIFs by tools/gen_fx.py).
SMODS.Atlas { key = 'fx_downpour', path = 'fx_downpour.png',  px = 256, py = 256 }

--------------------------------------------------------------------------------
-- Arena effects — screen-wide, round-scoped weather. Loaded before jokers
-- because Aquwa and friends call into CelestasMod.Arena.
--------------------------------------------------------------------------------

assert(SMODS.load_file('arena/arena.lua'))()

-- Enhancements load before jokers: Shoto, Saruei and MOTHERv3 all
-- reference CelestasMod.ENHANCEMENT_KEYS.
assert(SMODS.load_file('enhancements/enhancements.lua'))()

--------------------------------------------------------------------------------
-- Jokers — auto-loaded from jokers/.
-- Sorted so atlases.lua always registers before vtubers.lua references it.
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
for _, file in ipairs({ 'seals/seals.lua', 'items/decks.lua' }) do
    assert(SMODS.load_file(file))()
end

--------------------------------------------------------------------------------
-- Mod config tab
--------------------------------------------------------------------------------

SMODS.current_mod.config_tab = function()
    return {
        n = G.UIT.ROOT,
        config = { align = 'cm', padding = 0.05, colour = G.C.CLEAR },
        nodes = {
            create_toggle {
                label = localize('celesta_cfg_animation'),
                ref_table = SMODS.current_mod.config,
                ref_value = 'arena_animation',
            },
            create_toggle {
                label = localize('celesta_cfg_verbose'),
                ref_table = SMODS.current_mod.config,
                ref_value = 'verbose_logging',
            },
            create_toggle {
                label = localize('celesta_cfg_downpour'),
                ref_table = SMODS.current_mod.config,
                ref_value = 'debug_downpour',
            },
        },
    }
end

sendInfoMessage('Loaded ' .. SMODS.current_mod.name, 'CelestasMod')
