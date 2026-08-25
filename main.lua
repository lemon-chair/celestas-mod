--- Celesta's Mod — entry point.
--- Steamodded runs this file once, after the manifest is parsed.
--- `SMODS.current_mod` is this mod's table; the key prefix ("celesta") is
--- prepended to every key you register below, so a Joker with key "spark"
--- becomes "j_celesta_spark" in the game.

local mod = SMODS.current_mod

--------------------------------------------------------------------------------
-- Atlases (sprite sheets)
-- `path` is resolved against assets/1x/ and assets/2x/. px/py are the
-- dimensions of ONE sprite at 1x; the 2x sheet must be exactly double.
--------------------------------------------------------------------------------

SMODS.Atlas {
    key = 'jokers',
    path = 'jokers.png',
    px = 71,
    py = 95,
}

SMODS.Atlas {
    key = 'consumables',
    path = 'consumables.png',
    px = 71,
    py = 95,
}

SMODS.Atlas {
    key = 'decks',
    path = 'decks.png',
    px = 71,
    py = 95,
}

-- The little icon shown next to the mod in the Mods menu.
SMODS.Atlas {
    key = 'modicon',
    path = 'icon.png',
    px = 32,
    py = 32,
    atlas_table = 'ASSET_ATLAS',
}

--------------------------------------------------------------------------------
-- Content
-- Each file returns nothing; it just registers its objects. Split them up as
-- the mod grows — one file per category keeps main.lua readable.
--------------------------------------------------------------------------------

local files = {
    'items/jokers.lua',
    'items/consumables.lua',
    'items/decks.lua',
}

for _, file in ipairs(files) do
    assert(SMODS.load_file(file))()
end

--------------------------------------------------------------------------------
-- Mod config tab (optional)
-- Shows up as a "Config" button on the mod's page in the Mods menu.
--------------------------------------------------------------------------------

mod.config_tab = function()
    return {
        n = G.UIT.ROOT,
        config = { align = 'cm', padding = 0.05, colour = G.C.CLEAR },
        nodes = {
            create_toggle {
                label = localize('celesta_cfg_verbose'),
                ref_table = mod.config,
                ref_value = 'verbose_logging',
            },
        },
    }
end

sendInfoMessage('Loaded ' .. mod.name .. ' v' .. mod.version, 'CelestasMod')
