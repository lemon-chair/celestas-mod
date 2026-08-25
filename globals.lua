--- GLOBALS
--- Custom colours usable in localization text as {C:celesta_pink} etc.

G.C.CELESTA = {
    PINK    = HEX("FF6FB5"),
    PURPLE  = HEX("6C5CE7"),
    TEAL    = HEX("00B8A9"),
    GOLD    = HEX("F2C94C"),
    WHITE   = HEX("FFFFFF"),
}

-- Hooks

local loc_colour_ref = loc_colour
function loc_colour(_c, _default)
    if not G.ARGS.LOC_COLOURS then
        loc_colour_ref()
    end
    G.ARGS.LOC_COLOURS.celesta_pink   = G.C.CELESTA.PINK
    G.ARGS.LOC_COLOURS.celesta_purple = G.C.CELESTA.PURPLE
    G.ARGS.LOC_COLOURS.celesta_teal   = G.C.CELESTA.TEAL
    G.ARGS.LOC_COLOURS.celesta_gold   = G.C.CELESTA.GOLD
    G.ARGS.LOC_COLOURS.celesta_white  = G.C.CELESTA.WHITE
    return loc_colour_ref(_c, _default)
end
