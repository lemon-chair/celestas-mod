--- The Deck of Sins' stat sidebar.
---
--- A panel down the right-hand side of the run, opposite the HUD, in two
--- views: symbol and level, or symbol, name and level. The arrow at the top
--- switches between them.
---
--- The levels are DynaText bound to the stat tables themselves, the way the
--- HUD binds hands, discards and money (UI_definitions.lua:create_UIBox_HUD).
--- So nothing has to rebuild the panel when a stat climbs - only the arrow
--- rebuilds it, because the two views are different shapes.

local Sins = CelestasMod.Sins
Sins.Sidebar = {}
local Sidebar = Sins.Sidebar

--- The panel's own palette.
---
--- NOT the dynamic boss colours, which is what these used to read. Balatro
--- eases those to the CURRENT BLIND's colour every time one is set
--- (blind.lua:46), so the panel was tinted by whatever boss was up - and The
--- Goat is HEX("8A8A8A") while G.C.UI.TEXT_INACTIVE is HEX("88888899"). Two
--- units apart per channel: every inactive line was painted grey on grey and
--- vanished, so the upgrade list went blank and "To next level:" left nothing
--- behind but its number.
---
--- PANEL_MAIN is the value the dynamic pair itself defaults to
--- (globals.lua:389), so the panel looks as it did on a neutral blind - it has
--- simply stopped taking its contrast from something that can be any colour at
--- all. A HUD that is on screen all round cannot afford to.
local PANEL_MAIN = HEX("374244")
local PANEL_ROW  = HEX("2B3335")

--- What a line that is not yet earned is written in.
---
--- NOT G.C.UI.TEXT_INACTIVE, which is HEX("88888899") - a mid grey at 60%
--- alpha, meant for text on a light menu. Over the dark panel it composites
--- to little more than the panel itself, which is the other half of why the
--- upgrade list could not be read. This is a light grey at full alpha: still
--- plainly dimmer than an earned line, and still plainly there.
local PANEL_DIM = HEX("A9B4B7")

local SYMBOL = 0.38

--- Collapsed is the narrow view. Kept on G.GAME so a run comes back the way
--- the player left it, alongside the stats it is showing.
local function collapsed()
    local state = Sins.state()
    return state and G.GAME.celesta_sins_collapsed and true or false
end

--- The stat whose upgrades are open underneath it, if any.
local function opened()
    local state = Sins.state()
    return state and G.GAME.celesta_sins_open or nil
end

--------------------------------------------------------------------------------
-- The symbols
--------------------------------------------------------------------------------
--
-- Stat set 1 uses the game's own suit symbols - the same sprite the run info
-- and the poker-hand rows draw - through SMODS.Suits, which is what keeps them
-- correct under a colour palette or colourblind mode rather than pinning one
-- picture. This mod's own suits declare theirs the same way (suits/leaf.lua).
--
-- Stat set 2 has no sprite to find: the game ships no chip, Mult or money
-- icon, only coloured text. So each of those three is written as the glyph
-- the game already uses for it, in that thing's own colour - a blue +, a red
-- X, a yellow $.

local function suit_symbol(suit)
    local def = SMODS.Suits and SMODS.Suits[suit]
    if not def then return nil end
    local palette = G.SETTINGS.colour_palettes and G.SETTINGS.colour_palettes[suit]
    local atlas = (palette == "hc" and def.hc_ui_atlas)
        or (palette == "lc" and def.lc_ui_atlas)
        or def[G.SETTINGS.colourblind_option and "hc_ui_atlas" or "lc_ui_atlas"]
        or ("ui_" .. (G.SETTINGS.colourblind_option and "2" or "1"))
    local sheet = G.ASSET_ATLAS[atlas]
    if not (sheet and def.ui_pos) then return nil end
    return Sprite(0, 0, SYMBOL, SYMBOL, sheet, def.ui_pos)
end

--- One row's symbol, as a UI node: a sprite for the four suits, a glyph for
--- the three scores. A node rather than a Sprite, because the two are not the
--- same kind of thing and only the row above them has to know that.
local function symbol_node(key)
    local def = Sins.STATS[key]
    if not def then return nil end

    if def.suit then
        local sprite = suit_symbol(def.suit)
        if not sprite then return nil end
        return { n = G.UIT.O, config = { object = sprite } }
    end

    if not def.glyph then return nil end
    return { n = G.UIT.T, config = {
        text = def.glyph,
        -- Larger than the row's own text: it stands where a suit symbol
        -- stands, so it is sized against that rather than against the name.
        scale = 0.46,
        colour = G.C[def.colour] or G.C.UI.TEXT_LIGHT,
        shadow = true,
    } }
end

--------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------

--- Levels are written in white, every one of them.
---
--- They were the stat's own colour, which read well for the three scores and
--- not at all for the four suits: SMODS.Suit's base class defaults both
--- lc_colour and hc_colour to HEX '000000' (game_object.lua:1905) and the
--- vanilla suits do not override them, so all four came back black - on a
--- black panel. The symbol beside each level already says which stat it is,
--- so the number does not have to.
--------------------------------------------------------------------------------
-- What a stat is worth, and what it will be
--------------------------------------------------------------------------------

--- tier.loc -> the v_dictionary line that describes it.
---
--- Written out rather than concatenated from a prefix. localize is read by
--- tools/check_loc_keys.py, which can only check a key that is a whole
--- literal; building one from a prefix hid a missing line until the panel
--- shipped showing ERROR on every row.
local TIER_LINE = {
    chips = "celesta_sin_tier_chips",
    mult = "celesta_sin_tier_mult",
    dollars = "celesta_sin_tier_dollars",
    retriggers = "celesta_sin_tier_retriggers",
    pride_base = "celesta_sin_tier_pride_base",
    pride_x = "celesta_sin_tier_pride_x",
    pride_retrigger = "celesta_sin_tier_pride_retrigger",
    envy_base = "celesta_sin_tier_envy_base",
    envy_x = "celesta_sin_tier_envy_x",
    envy_retrigger = "celesta_sin_tier_envy_retrigger",
    sloth_dollars = "celesta_sin_tier_sloth_dollars",
    sloth_discount = "celesta_sin_tier_sloth_discount",
    sloth_interest = "celesta_sin_tier_sloth_interest",
    sloth_rares = "celesta_sin_tier_sloth_rares",
    sloth_legendary = "celesta_sin_tier_sloth_legendary",
}

--- The rows that open under a stat when it is clicked: every tier it has,
--- unlocked ones in the stat's own colour and locked ones greyed, each named
--- with the level it arrives at.
---
--- Built from Sins.tier_list, which is the same table the scoring reads, so
--- the panel cannot promise something the deck does not do.
local function tier_rows(key)
    local stat = Sins.get(key)
    local rows = {}

    -- The countdown first, bound to the stat rather than written in: it moves
    -- every time a card scores, and nothing rebuilds this panel for that.
    rows[#rows + 1] = {
        n = G.UIT.R,
        config = { align = "cl", padding = 0.02, minw = 2.4 },
        nodes = {
            { n = G.UIT.T, config = { text = localize("celesta_sin_to_next") .. " ",
                                      scale = 0.26, colour = PANEL_DIM } },
            { n = G.UIT.O, config = { object = DynaText {
                string = { { ref_table = stat, ref_value = "to_next" } },
                colours = { G.C.UI.TEXT_LIGHT },
                font = G.LANGUAGES["en-us"].font, scale = 0.28,
            } } },
        },
    }

    for _, tier in ipairs(Sins.tier_list(key)) do
        local colour = tier.unlocked and (G.C[Sins.STATS[key].colour or ""] or G.C.UI.TEXT_LIGHT)
            or PANEL_DIM
        rows[#rows + 1] = {
            n = G.UIT.R,
            config = { align = "cl", padding = 0.02, minw = 2.4 },
            nodes = {
                -- The level it arrives at, so a locked line says WHEN rather
                -- than only that it is not here yet.
                { n = G.UIT.C, config = { align = "cm", minw = 0.52, r = 0.1,
                                          colour = tier.unlocked and PANEL_ROW
                                              or G.C.CLEAR },
                  nodes = { { n = G.UIT.T, config = {
                      text = localize("celesta_sin_level_short") .. tier.at,
                      scale = 0.24, colour = colour } } } },
                { n = G.UIT.C, config = { align = "cl", minw = 1.84, padding = 0.03 },
                  nodes = { { n = G.UIT.T, config = {
                      -- Spelled out per tier rather than built from a
                      -- prefix: tools/check_loc_keys.py can only verify a key
                      -- it can read whole, and the one time it could not, a
                      -- whole panel shipped reading ERROR.
                      text = localize { type = "variable",
                                        key = TIER_LINE[tier.loc],
                                        vars = { tier.value } },
                      scale = 0.24, colour = colour } } } },
            },
        }
    end

    return rows
end

local function stat_row(key, stat, wide)
    local nodes = {}

    local symbol = symbol_node(key)
    nodes[#nodes + 1] = {
        n = G.UIT.C,
        config = { align = "cm", minw = 0.42 },
        nodes = symbol and { symbol } or {},
    }

    if wide then
        nodes[#nodes + 1] = {
            n = G.UIT.C,
            config = { align = "cl", minw = 1.15, padding = 0.04 },
            nodes = { { n = G.UIT.T, config = {
                text = localize("celesta_sin_" .. key),
                scale = 0.3, colour = G.C.UI.TEXT_LIGHT, shadow = true,
            } } },
        }
    end

    -- Bound to the stat table, so it climbs on its own.
    nodes[#nodes + 1] = {
        n = G.UIT.C,
        config = { align = "cr", minw = 0.42 },
        nodes = { { n = G.UIT.O, config = { object = DynaText {
            string = { { ref_table = stat, ref_value = "level" } },
            colours = { G.C.UI.TEXT_LIGHT },
            font = G.LANGUAGES["en-us"].font,
            scale = 0.42, shadow = true,
        } } } },
    }

    return {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.03, r = 0.1, minh = 0.44,
                   colour = opened() == key and lighten(PANEL_ROW, 0.25)
                       or PANEL_ROW,
                   button = "celesta_sins_stat", hover = true,
                   ref_table = { stat = key } },
        nodes = nodes,
    }
end

--- A set that is closed reads as closed: the row of stats that can no longer
--- climb sits behind a divider, rather than only being inferable from one of
--- them reading 20.
local function divider(closed)
    return {
        n = G.UIT.R,
        config = { align = "cm", minh = 0.12, minw = 0.2, r = 0.1,
                   colour = closed and G.C.UI.TEXT_INACTIVE or G.C.CLEAR },
        nodes = {},
    }
end

function Sidebar.definition()
    local state = Sins.state()
    if not state then return { n = G.UIT.ROOT, config = { colour = G.C.CLEAR }, nodes = {} } end

    local wide = not collapsed()
    local rows = {}

    -- The arrow. Points the way the panel will go, so it reads as what
    -- pressing it does rather than as what the panel currently is.
    rows[#rows + 1] = {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.02 },
        nodes = { {
            n = G.UIT.C,
            config = { align = "cm", minw = wide and 1.99 or 0.84, minh = 0.34,
                       r = 0.1, colour = PANEL_MAIN, emboss = 0.04,
                       button = "celesta_sins_toggle", hover = true,
                       shadow = true, id = "celesta_sins_arrow" },
            nodes = { { n = G.UIT.T, config = {
                text = wide and ">" or "<",
                scale = 0.38, colour = G.C.UI.TEXT_LIGHT, shadow = true,
            } } },
        } },
    }

    local last_set
    for _, key in ipairs(Sins.ORDER) do
        local def = Sins.STATS[key]
        if last_set and def.set ~= last_set then
            rows[#rows + 1] = divider(Sins.set_is_closed(last_set))
        end
        last_set = def.set
        rows[#rows + 1] = stat_row(key, state[key], wide)
        -- Opened underneath the stat it belongs to, rather than in a floating
        -- box, so it reads as part of that row.
        if opened() == key then
            for _, row in ipairs(tier_rows(key)) do rows[#rows + 1] = row end
        end
    end
    rows[#rows + 1] = divider(Sins.set_is_closed(last_set))

    return {
        n = G.UIT.ROOT,
        config = { align = "cm", padding = 0.06, r = 0.1, colour = PANEL_MAIN,
                   emboss = 0.05, minw = wide and 2.2 or 1.05 },
        nodes = rows,
    }
end

--------------------------------------------------------------------------------
-- Putting it on the screen, and taking it off again
--------------------------------------------------------------------------------

function Sidebar.remove()
    Sidebar.bound_to = nil
    if G.celesta_sins_hud then
        G.celesta_sins_hud:remove()
        G.celesta_sins_hud = nil
    end
end

function Sidebar.build()
    Sidebar.remove()
    local state = Sins.state()
    if not state then return end
    -- Which run's stats this panel was built against. The levels are DynaText
    -- bound to the stat tables themselves, so a panel is only ever valid for
    -- the tables it was built from - see the note in Game:update below.
    Sidebar.bound_to = state
    -- 'cri' is the HUD's 'cli' mirrored: centred against the right edge of the
    -- room, so it sits opposite the hands-and-money panel at every resolution
    -- rather than at a guessed coordinate.
    G.celesta_sins_hud = UIBox {
        definition = Sidebar.definition(),
        config = { align = "cri", offset = { x = 0.7, y = 0 },
                   major = G.ROOM_ATTACH, bond = "Weak" },
    }
    -- Taken out of the ordinary draw pass; Game:draw below puts it back at
    -- the end of the frame. See there for why.
    G.celesta_sins_hud.parent = G.ROOM_ATTACH
end

--------------------------------------------------------------------------------
-- ...in front of everything else
--------------------------------------------------------------------------------
--
-- G.I.CARDAREA is drawn AFTER G.I.NODE (game.lua:2897), so the Joker and
-- consumable trays sit on top of any UIBox they overlap - and the cursor
-- picks the last thing in G.DRAW_HASH, which is walked backwards
-- (controller.lua:1030). So the tray took the pixels AND the clicks, and the
-- collapse arrow underneath it could not be pressed.
--
-- Drawn here instead, after everything the base game draws. `parent` is set
-- above purely to keep the ordinary pass from drawing it as well: the only
-- thing that reads parent on a UIBox is `if not v.parent` in that loop, and
-- where the box sits comes from `container`, not from this.

local celesta_sins_draw_ref = Game.draw
function Game:draw(...)
    local ret = celesta_sins_draw_ref(self, ...)

    local hud = G.celesta_sins_hud
    if hud and not hud.REMOVED then
        love.graphics.push()
        hud:translate_container()
        hud:draw()
        love.graphics.pop()
    end
    return ret
end

G.FUNCS.celesta_sins_stat = function(e)
    if not Sins.state() then return end
    local key = e and e.config and e.config.ref_table and e.config.ref_table.stat
    if not key then return end
    -- Clicking the open one closes it, so the panel is never stuck open.
    --
    -- Spelled out rather than `(open == key) and nil or key`, which cannot
    -- work: `true and nil` is nil, and `nil or key` is key - so the short
    -- form re-opens the stat it was meant to close, every time.
    if G.GAME.celesta_sins_open == key then
        G.GAME.celesta_sins_open = nil
    else
        G.GAME.celesta_sins_open = key
    end
    play_sound("cardSlide1", 1.1, 0.3)
    Sidebar.build()
end

G.FUNCS.celesta_sins_toggle = function()
    if not Sins.state() then return end
    G.GAME.celesta_sins_collapsed = not G.GAME.celesta_sins_collapsed
    -- Hiding the sidebar puts away what was open inside it: a panel left
    -- hanging under a collapsed strip has nothing to belong to.
    G.GAME.celesta_sins_open = nil
    play_sound("cardSlide1", 1.2, 0.4)
    Sidebar.build()
end

--- Kept in step from Game:update rather than created once at the start of a
--- run: that one moment misses a saved run being loaded back in, a deck being
--- changed, and the panel outliving the run it belongs to. Asked every frame
--- and answered in one comparison, which is what the Vantacrow and Aethal
--- passives do with the numbers they hold.
local celesta_sins_update_ref = Game.update
function Game:update(dt)
    celesta_sins_update_ref(self, dt)

    -- A box this mod did not remove can still be gone. Starting a new run
    -- tears the screen's UI down, and what is left here is a reference to a
    -- REMOVED box - so `not G.celesta_sins_hud` was false forever and the
    -- panel was never rebuilt, while Game:draw below skips a REMOVED box and
    -- never drew it either. Gone for the rest of the session, on a deck whose
    -- whole point is the panel.
    --
    -- Dropped rather than guarded at the draw, because the box is genuinely
    -- finished: the build below puts a fresh one up on the next frame.
    if G.celesta_sins_hud and G.celesta_sins_hud.REMOVED then
        G.celesta_sins_hud = nil
    end

    -- Rebuilt when the RUN's stats change identity, not only when the panel
    -- is missing. The levels are DynaText bound to the stat tables
    -- (Sidebar.definition), which is what lets them climb without anything
    -- rebuilding the panel - but a new run puts a whole new G.GAME in place,
    -- so Sins.state() hands back a different table and the old bindings go on
    -- reading the finished run's numbers. Starting a run after losing one
    -- showed the dead run's levels rather than zeroes.
    local state = Sins.state()
    local want = G.STAGE == G.STAGES.RUN and state ~= nil
    if want and (not G.celesta_sins_hud or Sidebar.bound_to ~= state) then
        Sidebar.build()
    elseif not want and G.celesta_sins_hud then
        Sidebar.remove()
    end
end
