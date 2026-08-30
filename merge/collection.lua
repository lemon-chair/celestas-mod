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

--- Every pair with an ability of its own, named and wildcard alike, sorted by
--- the name shown so the order does not move when a pair is added.
local function all_pairs()
    local out = {}
    for _, def in pairs(Bind.SPECIALS or {}) do out[#out + 1] = def end
    for _, def in ipairs(Bind.WILDCARDS or {}) do out[#out + 1] = def end
    table.sort(out, function(a, b)
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
local function pair_title(def)
    local halves = def.halves or {}
    local first = joker_name(halves[1])
    if not halves[2] then
        return first .. " + " .. localize("celesta_any_joker")
    end
    return first .. " + " .. joker_name(halves[2])
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

--- The pair's own description, as the game would draw it anywhere else.
---
--- Built through generate_card_ui, the same call merge/bind.lua uses for the
--- merged card's panel, so the colours and the numbers come out identical
--- rather than being re-derived here. loc_vars wants a card and this page has
--- none, so it is given a stand-in and the whole thing is pcall'd: a pair
--- whose description cannot be built shows its name and nothing else, which is
--- worse than the description and far better than a crash in the Collection.
local function description_nodes(def)
    local vars = {}
    if type(def.loc_vars) == "function" then
        local stub = { ability = { extra = {} }, config = { center = {} } }
        local ok, res = pcall(def.loc_vars, def, stub, def.config or {})
        if ok and type(res) == "table" and type(res.vars) == "table" then
            vars = res.vars
        end
    end

    local ok, aut = pcall(generate_card_ui,
        { set = "Other", key = "celesta_bind_" .. tostring(def.key) },
        nil, vars, "Other", nil, false)
    if not (ok and type(aut) == "table" and type(aut.main) == "table") then
        CelestasMod.warn_once("bind_collection_" .. tostring(def.key),
            ("The Special Merges tab could not describe %s"):format(tostring(def.key)))
        return nil
    end
    return aut.main
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
        config = { align = "cl", padding = 0.06, r = 0.1, colour = G.C.BLACK,
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
    G.FUNCS.overlay_menu { definition = build() }
end

G.FUNCS.celesta_special_merges = function(e)
    page = 1
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu { definition = build() }
end

--------------------------------------------------------------------------------
-- The button
--------------------------------------------------------------------------------

SMODS.current_mod.custom_collection_tabs = function()
    local list = all_pairs()
    local seen = 0
    for _, def in ipairs(list) do
        if Bind.special_seen(def.key) then seen = seen + 1 end
    end

    return {
        UIBox_button {
            button = "celesta_special_merges",
            label = { localize("celesta_special_merges") },
            count = { tally = seen, of = #list },
            minw = 5,
            id = "celesta_special_merges",
        },
    }
end
