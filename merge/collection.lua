--- The "Special Merges" tab in the Collection.
---
--- Lists every pair of Jokers that has an ability of its own. Which two go
--- together is shown from the start; WHAT they do is not, until this profile
--- has actually made that merge in a run. Bind.special_seen is the question
--- and merge/bind.lua answers it off the profile, so it survives the run that
--- earned it.
---
--- Steamodded's hook is SMODS.current_mod.custom_collection_tabs: it returns
--- buttons, and they are appended to the "Other" page of the Collection. The
--- button's `button` field names a G.FUNCS entry, which is why the one below
--- is global rather than local.

local Bind = CelestasMod.Bind

-- Enough to fit a page without scrolling. Nineteen pairs over four pages is
-- kinder than nineteen rows squeezed into one.
local PER_PAGE = 5

--------------------------------------------------------------------------------
-- What to list
--------------------------------------------------------------------------------

--- Every merge with an ability of its own - quad, named pair and wildcard
--- alike - sorted so the order does not move when one is added.
---
--- Quads first, so the six groups land on the first page. They are the ones
--- worth finding: a pair is two Jokers the player will stumble into, and a
--- group of four is something they have to go and assemble.
local function all_pairs()
    local out = {}
    for _, def in pairs(Bind.QUADS or {}) do out[#out + 1] = def end
    for _, def in pairs(Bind.SPECIALS or {}) do out[#out + 1] = def end
    for _, def in ipairs(Bind.WILDCARDS or {}) do out[#out + 1] = def end
    table.sort(out, function(a, b)
        local a_quad, b_quad = a.is_quad and 1 or 0, b.is_quad and 1 or 0
        if a_quad ~= b_quad then return a_quad > b_quad end
        return tostring(a.key) < tostring(b.key)
    end)
    return out
end

--- A Joker's display name, or its key if the game has never heard of it.
local function joker_name(key)
    if not (key and G.P_CENTERS and G.P_CENTERS[key]) then return tostring(key) end
    local ok, name = pcall(localize, { type = "name_text", set = "Joker", key = key })
    if ok and type(name) == "string" and name ~= "" then return name end
    return tostring(key)
end

--- "Arar + Jaws", or "x3Dustco + Any" for a wildcard.
---
--- A wildcard is ONE row, not one per Joker it could pair with: x3Dustco takes
--- any of this mod's 127, and listing those separately would bury the eighteen
--- pairs that are actually distinct under a wall of near-identical entries
--- saying the same thing.
--- ...and a quad is all four of them, joined the same way. Four names is a
--- long line, but it is the only thing that says which four to go and find.
local function pair_title(def)
    local halves = def.halves or {}
    local first = joker_name(halves[1])
    if not halves[2] then
        return first .. " + " .. localize("celesta_any_joker")
    end
    local title = first
    for index = 2, #halves do
        title = title .. " + " .. joker_name(halves[index])
    end
    return title
end

--------------------------------------------------------------------------------
-- Drawing one entry
--------------------------------------------------------------------------------

local function text_row(str, colour, scale)
    return {
        n = G.UIT.R,
        config = { align = "cl", padding = 0.02 },
        nodes = {
            { n = G.UIT.T, config = { text = str, scale = scale or 0.36,
                                      colour = colour or G.C.UI.TEXT_LIGHT } },
        },
    }
end

-- A card description is written to be read off the white panel the game draws
-- one on, so every part of one that was not given a colour of its own comes
-- back G.C.UI.TEXT_DARK - HEX("4F6367"), a near-black slate. This page puts
-- them on the entry's own dark box instead, where that is all but invisible.
--
-- So the dark default, and only the dark default, is swapped for a light grey.
-- Anything the description coloured on purpose - an {C:attention} highlight, a
-- red X-Mult chip - is left exactly as written, because those are the parts
-- carrying the meaning and they read fine already.
local DESC_GREY = { 0.77, 0.80, 0.82, 1 }

--- Is this the unstyled default rather than a colour someone chose?
--- loc_colour hands back G.C.UI.TEXT_DARK itself, so identity catches it; the
--- value check is there for a copy made by another mod's hook.
local function is_default_dark(colour)
    local dark = G.C.UI.TEXT_DARK
    -- Checked before the identity test: were both nil, nil == nil would call
    -- every uncoloured node dark and repaint the whole page.
    if type(dark) ~= "table" then return false end
    if colour == dark then return true end
    if type(colour) ~= "table" then return false end
    for i = 1, 4 do
        local got, want = colour[i], dark[i]
        -- Not every table reaching here is a colour: a description part can
        -- carry any table a mod put in it, and subtracting a string errors.
        if type(got) ~= "number" or type(want) ~= "number" then return false end
        if math.abs(got - want) > 0.001 then return false end
    end
    return true
end

--- Walks one description part and recolours the default dark wherever it sits.
--- Never mutates a shared colour table - the reference is replaced, so
--- G.C.UI.TEXT_DARK is left alone for the rest of the game.
local function lighten_text(node)
    if type(node) ~= "table" then return end

    local config = node.config
    if type(config) == "table" then
        if node.n == G.UIT.T and is_default_dark(config.colour) then
            config.colour = DESC_GREY
        end
        -- A {E:_} part is a DynaText, which reads its colours table at draw
        -- time rather than baking them in, so swapping an entry is enough.
        local object = config.object
        if type(object) == "table" and type(object.colours) == "table" then
            for i, colour in ipairs(object.colours) do
                if is_default_dark(colour) then object.colours[i] = DESC_GREY end
            end
        end
    end

    -- A part that brings its own background - an {X:mult} chip is a coloured
    -- container round its text - is not sitting on the dark box, so its text
    -- is left to read against the colour picked for it, exactly as the game
    -- draws the same chip everywhere else.
    if type(config) == "table" and node.n == G.UIT.C and config.colour then
        return
    end

    if type(node.nodes) == "table" then
        for _, child in ipairs(node.nodes) do lighten_text(child) end
    end
end

--- The pair's own description, as the game would draw it anywhere else.
---
--- Built through generate_card_ui, the same call merge/bind.lua uses for the
--- merged card's panel, so the colours and the numbers come out identical
--- rather than being re-derived here. loc_vars wants a card and this page has
--- none, so it is given a stand-in and the whole thing is pcall'd: a pair
--- whose description cannot be built shows its name and nothing else, which is
--- worse than the description and far better than a crash in the Collection.
local function description_nodes(def)

    -- Built in merge/bind.lua, which the web shares - including the reason
    -- the name is deliberately never built.
    local main = Bind.desc_rows("celesta_bind_" .. tostring(def.key), def)
    if not main then
        CelestasMod.warn_once("bind_collection_" .. tostring(def.key),
            ("The Special Merges tab could not describe %s"):format(tostring(def.key)))
        return nil
    end
    local aut = { main = main }

    -- aut.main is a list of RAW rows - each is a list of text parts, not a UI
    -- node - and every consumer in the game turns them into nodes before
    -- drawing them (desc_from_rows, UI_definitions.lua:1126). Splicing them
    -- straight in left each row without an `n`, so UIElement's colour
    -- defaulting, which keys off the node type, matched nothing and left
    -- config.colour nil; ui.lua:691 indexes that unconditionally.
    --
    -- Wrapped by hand rather than through desc_from_rows because that one also
    -- puts a white card-description panel around the lot, which is not what a
    -- row inside this page's own black entry should look like.
    local rows = {}
    for _, row in ipairs(aut.main) do
        for _, part in ipairs(row) do lighten_text(part) end
        rows[#rows + 1] = { n = G.UIT.R, config = { align = "cl" }, nodes = row }
    end
    return rows
end

local function entry_node(def)
    local seen = Bind.special_seen(def.key)
    local rows = { text_row(pair_title(def),
                            seen and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE) }

    if seen then
        local desc = description_nodes(def)
        if desc then
            for _, row in ipairs(desc) do rows[#rows + 1] = row end
        end
    else
        rows[#rows + 1] = text_row(localize("celesta_merge_unknown"),
                                   G.C.UI.TEXT_INACTIVE, 0.3)
    end

    return {
        n = G.UIT.R,
        -- A pair this profile has made is lifted out of the black the locked
        -- ones sit in, so the page reads at a glance as what is found and what
        -- is not - rather than only by the text being greyed.
        config = { align = "cl", padding = 0.06, r = 0.1,
                   colour = seen and lighten(G.C.BLACK, 0.2) or G.C.BLACK,
                   emboss = 0.05, minw = 5.6, minh = 0.9 },
        nodes = { { n = G.UIT.C, config = { align = "cl", padding = 0.04 },
                    nodes = rows } },
    }
end

--------------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------------

--- Which page is showing. Kept here rather than on G so leaving the Collection
--- and coming back starts at the beginning.
local page = 1

local function page_count(list)
    return math.max(1, math.ceil(#list / PER_PAGE))
end

local function build()
    local list = all_pairs()
    local pages = page_count(list)
    if page > pages then page = pages end

    local seen = 0
    for _, def in ipairs(list) do
        if Bind.special_seen(def.key) then seen = seen + 1 end
    end

    local rows = {}
    for i = (page - 1) * PER_PAGE + 1, math.min(page * PER_PAGE, #list) do
        rows[#rows + 1] = entry_node(list[i])
    end

    local contents = {
        { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            { n = G.UIT.T, config = {
                text = ("%d / %d"):format(seen, #list),
                scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
        } },
        { n = G.UIT.R, config = { align = "cm", padding = 0.06 }, nodes = rows },
    }

    if pages > 1 then
        local options = {}
        for i = 1, pages do options[i] = ("%d / %d"):format(i, pages) end
        contents[#contents + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.1 },
            nodes = { create_option_cycle {
                options = options,
                current_option = page,
                opt_callback = "celesta_merges_page",
                colour = G.C.RED,
                no_pips = true,
                focus_args = { snap_to = true, nav = "wide" },
            } } }
    end

    return create_UIBox_generic_options {
        back_func = "your_collection_other_gameobjects",
        contents = contents,
    }
end

--- The cycle rebuilds the whole overlay rather than swapping nodes in place.
--- Swapping would mean tearing down and re-parenting a variable number of
--- rows, and the page is cheap to build.
G.FUNCS.celesta_merges_page = function(args)
    page = (args and args.cycle_config and args.cycle_config.current_option) or 1

    -- The previous page's UIBox is not taken down here: G.FUNCS.overlay_menu
    -- already removes whatever it is replacing (button_callbacks.lua:1331).
    -- The titles that used to pile up in the corner were never the old page
    -- still drawing - see the note on no_name in description_nodes.
    --
    -- Opened flat, and without the shake.
    --
    -- An overlay defaults to being placed ten units low and then retargeted to
    -- the middle, so it slides up as it appears, and it bumps G.ROOM.jiggle on
    -- the way (button_callbacks.lua:1339 and :1352). That reads as the menu
    -- arriving, which is right when it is arriving - the tab opening below
    -- keeps both. A page turn is not an arrival: the same box is still there
    -- with different rows in it, and flying it up from the bottom every time
    -- an arrow is pressed is a lot of movement to read a list through.
    --
    -- A zero offset means the box is built where it belongs, and since a
    -- Moveable starts with its visible transform equal to its real one
    -- (moveable.lua:20), there is nothing left to ease.
    local jiggle = G.ROOM and G.ROOM.jiggle
    G.FUNCS.overlay_menu {
        definition = build(),
        config = { offset = { x = 0, y = 0 } },
    }
    if G.ROOM and jiggle then G.ROOM.jiggle = jiggle end
end

G.FUNCS.celesta_special_merges = function(e)
    page = 1
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu { definition = build() }
end

--------------------------------------------------------------------------------
-- The button
--------------------------------------------------------------------------------

--- How many pairs there are, and how many this profile has made.
local function tally()
    local list = all_pairs()
    local seen = 0
    for _, def in ipairs(list) do
        if Bind.special_seen(def.key) then seen = seen + 1 end
    end
    return seen, #list
end

local function collection_button()
    local seen, total = tally()
    return UIBox_button {
        button = "celesta_special_merges",
        label = { localize("celesta_special_merges") },
        count = { tally = seen, of = total },
        minw = 5,
        id = "celesta_special_merges",
    }
end

-- Steamodded's sanctioned home for a mod's collection tab: the "Other" page.
SMODS.current_mod.custom_collection_tabs = function()
    return { collection_button() }
end

--------------------------------------------------------------------------------
-- ...and on the Collection's own front page
--------------------------------------------------------------------------------
--
-- The Other page is where Steamodded puts a mod tab, and it is one click
-- further in than anyone looks. So the button is also spliced into the front
-- page, next to the ones it belongs with.
--
-- Spliced by finding a button already there rather than by index: the column
-- this lands in is vanilla's, Steamodded appends to it, and any mod may append
-- again, so a position counted from the top is wrong the moment anything else
-- loads. A named neighbour is not.
--
-- If neither neighbour is found the page is returned untouched and the tab is
-- still reachable through Other, which is why this is a warn and not an error.

--- Inserts `made` directly after the button called `target`, anywhere in the
--- tree. UIBox_button wraps its button one level down, so the node to compare
--- is the child's config and the node to insert beside is the parent.
local function insert_after_button(node, target, made)
    if type(node) ~= "table" or type(node.nodes) ~= "table" then return false end

    for i, child in ipairs(node.nodes) do
        local inner = type(child) == "table" and type(child.nodes) == "table"
            and child.nodes[1]
        local key = type(inner) == "table" and inner.config and inner.config.button
        if key == target then
            table.insert(node.nodes, i + 1, made)
            return true
        end
    end

    for _, child in ipairs(node.nodes) do
        if insert_after_button(child, target, made) then return true end
    end
    return false
end

if create_UIBox_your_collection then
    local celesta_collection_ref = create_UIBox_your_collection
    function create_UIBox_your_collection(...)
        local root = celesta_collection_ref(...)
        if type(root) ~= "table" then return root end

        local button = collection_button()
        -- Vouchers first: it is the bottom of the left column, above the
        -- Consumables block, and that column is the shorter of the two.
        if not insert_after_button(root, "your_collection_vouchers", button)
            and not insert_after_button(root, "your_collection_other_gameobjects", button)
            and not insert_after_button(root, "your_collection_blinds", button) then
            CelestasMod.warn_once("merge_tab_frontpage",
                "Could not place Special Merges on the Collection's front page; "
                .. "it is still under Other")
        end
        return root
    end
end
