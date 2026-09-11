--- The merge web.
---
--- Click a Joker in the Joker collection that has special merges and it is
--- shown on its own, on a darkened screen, with every Joker it has a special
--- merge with branching out from it.
---
--- Named pairs only. x3Dustco's merge is a wildcard - it takes any Joker from
--- this mod - so it is a partner of everything, and a web that drew it would
--- draw it on every Joker and say nothing. It is left out of both ends: it
--- opens no web of its own, and it is not a branch on anyone else's.
---
--- What each pair DOES is not shown. The Special Merges tab keeps that hidden
--- until the pair has been made, and a web that printed it would be a way
--- round that; what the web shows is which Jokers go together, which that tab
--- shows from the start. A partner the player has not discovered yet stays the
--- "?" card for the same reason - the Cards are made without bypassing
--- discovery, so the game draws them the way it draws them everywhere else.

local Bind = CelestasMod.Bind

local X3DUSTCO = "j_celesta_x3dustco"

--- Marks the areas the web is built from. NOT `collection`: that flag is what
--- the collection's "new" badges hang off (card.lua:81), and it is what the
--- click hook below looks for, so a partner in the web would open a web of its
--- own.
local WEB_FLAG = "celesta_merge_web"

--------------------------------------------------------------------------------
-- Who pairs with whom
--------------------------------------------------------------------------------

--- Every Joker `key` has a named special merge with, in collection order.
---
--- A pair of a Joker with itself - Arar and Arar, Yharon and Yharon - is a
--- partner like any other: the web shows a second copy of it.
function CelestasMod.merge_partners(key)
    local out, seen = {}, {}
    if not key or key == X3DUSTCO then return out end

    for _, def in pairs(Bind.SPECIALS or {}) do
        local halves = def.halves or {}
        local a, b = halves[1], halves[2]
        local other = (a == key and b) or (b == key and a) or nil
        if other and other ~= X3DUSTCO and not seen[other] then
            seen[other] = true
            out[#out + 1] = other
        end
    end

    -- By collection order, so a web is drawn the same way every time it is
    -- opened rather than in whatever order pairs() walked the table.
    local function order(k)
        local c = G.P_CENTERS and G.P_CENTERS[k]
        return (c and c.order) or math.huge
    end
    table.sort(out, function(x, y)
        local ox, oy = order(x), order(y)
        if ox ~= oy then return ox < oy end
        return x < y
    end)
    return out
end

--------------------------------------------------------------------------------
-- Where the branches go
--------------------------------------------------------------------------------
--
-- The web is a square grid with the Joker in the middle cell. The partners sit
-- in the ring around it, which is what lets the layout stay Balatro's own
-- rows-and-columns UI - every card is an ordinary CardArea in an ordinary
-- cell, hovering and drawing exactly as it does in the collection - while
-- still reading as branches coming off one card.
--
-- Up to five, a hand-picked arrangement for each count, balanced around the
-- middle. Past that the partners are spread evenly round the ring, and the
-- ring grows a size if they will not fit; nothing is ever dropped.

--- (row, column) cells, 1-based, on a 3x3 grid.
local PRESETS = {
    [1] = { { 1, 2 } },
    [2] = { { 2, 1 }, { 2, 3 } },
    [3] = { { 1, 2 }, { 3, 1 }, { 3, 3 } },
    [4] = { { 1, 2 }, { 2, 1 }, { 2, 3 }, { 3, 2 } },
    [5] = { { 1, 2 }, { 2, 1 }, { 2, 3 }, { 3, 1 }, { 3, 3 } },
}

--- The border cells of a size x size grid, clockwise from the top middle.
local function ring(size)
    local cells, last = {}, size
    -- Floored, not divided: a float here would print as "2.0" under Lua 5.3
    -- and later, and never match a cell key built from a loop counter.
    local mid = math.floor((size + 1) / 2)
    for c = mid, last do cells[#cells + 1] = { 1, c } end
    for r = 2, last do cells[#cells + 1] = { r, last } end
    for c = last - 1, 1, -1 do cells[#cells + 1] = { last, c } end
    for r = last - 1, 1, -1 do cells[#cells + 1] = { r, 1 } end
    for c = 2, mid - 1 do cells[#cells + 1] = { 1, c } end
    return cells
end

--- The grid size and the cell of each of `count` partners.
function CelestasMod.merge_web_layout(count)
    if PRESETS[count] then return 3, PRESETS[count] end

    local size = 3
    while 4 * (size - 1) < count do size = size + 2 end
    local border = ring(size)
    local cells = {}
    for i = 1, count do
        -- Evenly round the ring, starting at the top.
        cells[i] = border[math.floor((i - 1) * #border / count) + 1]
    end
    return size, cells
end

--------------------------------------------------------------------------------
-- The branches themselves
--------------------------------------------------------------------------------

--- How far along (dx, dy) a line from a card's centre leaves the card.
local function exit_t(dx, dy, half_w, half_h)
    local tx = dx ~= 0 and half_w / math.abs(dx) or math.huge
    local ty = dy ~= 0 and half_h / math.abs(dy) or math.huge
    return math.min(tx, ty)
end

--- The segment from `from`'s edge to `to`'s edge, in room units, or nil when
--- the two overlap and there is nothing between them to draw.
function CelestasMod.merge_web_branch(from, to)
    local fx, fy = from.x + from.w / 2, from.y + from.h / 2
    local tx, ty = to.x + to.w / 2, to.y + to.h / 2
    local dx, dy = tx - fx, ty - fy
    if dx == 0 and dy == 0 then return nil end

    local leave = exit_t(dx, dy, from.w / 2, from.h / 2)
    local arrive = 1 - exit_t(dx, dy, to.w / 2, to.h / 2)
    if leave >= arrive then return nil end
    return fx + dx * leave, fy + dy * leave, fx + dx * arrive, fy + dy * arrive
end

local BRANCH_WIDTH = 0.06
local BRANCH_COLOUR = { 1, 1, 1, 0.75 }

--- Drawn in room units: prep_draw scales by G.TILESCALE * G.TILESIZE before
--- anything else (misc_functions.lua:794), so doing the same here puts a point
--- given in VT coordinates exactly where a card at that VT is drawn.
local function draw_branches(centre, partners)
    love.graphics.push()
    love.graphics.scale(G.TILESCALE * G.TILESIZE)
    love.graphics.setLineWidth(BRANCH_WIDTH)
    love.graphics.setColor(BRANCH_COLOUR)
    for _, area in ipairs(partners) do
        local x1, y1, x2, y2 = CelestasMod.merge_web_branch(centre.VT, area.VT)
        if x1 then love.graphics.line(x1, y1, x2, y2) end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

--------------------------------------------------------------------------------
-- Building the view
--------------------------------------------------------------------------------

--- One card in a CardArea of its own, the way the collection holds each of
--- its cards (SMODS ui.lua:1904), so hovering it shows its description.
local function holder(key)
    local area = CardArea(G.ROOM.T.x, G.ROOM.T.h, G.CARD_W, G.CARD_H * 0.95,
                          { card_limit = 1, type = "title", highlight_limit = 0,
                            [WEB_FLAG] = true })
    local center = G.P_CENTERS[key]
    if center then
        local card = Card(area.T.x + area.T.w / 2, area.T.y, G.CARD_W, G.CARD_H,
                          G.P_CARDS.empty, center)
        area:emplace(card)
    end
    return area
end

--- A cell of the grid: a card, or the same space left empty.
local function cell(area)
    return {
        n = G.UIT.C,
        config = { align = "cm", minw = G.CARD_W * 1.35, minh = G.CARD_H * 1.2 },
        nodes = area and { { n = G.UIT.O, config = { object = area } } } or {},
    }
end

--- The web for `key`, as the contents of an overlay.
function CelestasMod.merge_web_definition(key)
    local partner_keys = CelestasMod.merge_partners(key)
    local size, cells = CelestasMod.merge_web_layout(#partner_keys)
    local mid = math.floor((size + 1) / 2)

    local centre = holder(key)
    local at, partners = {}, {}
    for i, k in ipairs(partner_keys) do
        local area = holder(k)
        partners[#partners + 1] = area
        at[cells[i][1] .. ":" .. cells[i][2]] = area
    end
    at[mid .. ":" .. mid] = centre

    -- The branches are drawn by the centre card's area, before its own card,
    -- and each one stops at the edge of both cards - so a line never crosses a
    -- card whichever of them the UI happens to draw first.
    centre.draw = function(self, ...)
        draw_branches(self, partners)
        return CardArea.draw(self, ...)
    end

    local rows = {}
    for r = 1, size do
        local cols = {}
        for c = 1, size do cols[#cols + 1] = cell(at[r .. ":" .. c]) end
        rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm" }, nodes = cols }
    end

    return create_UIBox_generic_options {
        back_func = "celesta_merge_web_back",
        -- The darkened screen. The generic panel's ROOT is the backdrop behind
        -- the whole overlay (UI_definitions.lua:6333), and the panel itself is
        -- left clear, so what is left is the web on the dark.
        bg_colour = { G.C.BLACK[1], G.C.BLACK[2], G.C.BLACK[3], 0.85 },
        colour = G.C.CLEAR,
        outline_colour = G.C.CLEAR,
        contents = rows,
    }
end

--------------------------------------------------------------------------------
-- Opening it, and coming back
--------------------------------------------------------------------------------

--- The Joker collection page the web was opened from, so Back lands on it
--- rather than on page one.
local return_page = nil

--- The page the open collection is showing, read off its own page cycle: the
--- cycle keeps its state in the table its arrows are handed
--- (button_callbacks.lua:538), and SMODS names its callback.
local function current_page()
    local root = G.OVERLAY_MENU and G.OVERLAY_MENU.UIRoot
    if not root then return 1 end
    local found = nil
    local function walk(node)
        if found or type(node) ~= "table" then return end
        local ref = node.config and node.config.ref_table
        if type(ref) == "table" and ref.opt_callback == "SMODS_card_collection_page" then
            found = ref.current_option
            return
        end
        for _, child in ipairs(node.children or {}) do walk(child) end
    end
    walk(root)
    return tonumber(found) or 1
end

function CelestasMod.open_merge_web(key)
    return_page = current_page()
    G.FUNCS.overlay_menu { definition = CelestasMod.merge_web_definition(key) }
end

-- SMODS builds the Joker collection's page cycle at page one every time
-- (ui.lua:1946). While coming back from a web, the cycle is built at the page
-- the web was opened from instead, so the number it shows and the cards on
-- the page agree.
local restoring = nil
local celesta_web_cycle_ref = create_option_cycle
function create_option_cycle(args, ...)
    if restoring and type(args) == "table"
        and args.opt_callback == "SMODS_card_collection_page"
        and args.options and args.options[restoring] then
        args.current_option = restoring
    end
    return celesta_web_cycle_ref(args, ...)
end

G.FUNCS.celesta_merge_web_back = function(e)
    local page = return_page or 1
    return_page = nil

    restoring = page
    local ok, err = pcall(function()
        G.FUNCS.overlay_menu { definition = create_UIBox_your_collection_jokers() }
    end)
    restoring = nil
    if not ok then error(err, 0) end

    if page > 1 and G.FUNCS.SMODS_card_collection_page then
        G.FUNCS.SMODS_card_collection_page { cycle_config = { current_option = page } }
    end
end

--------------------------------------------------------------------------------
-- The click
--------------------------------------------------------------------------------
--
-- A card in a collection does nothing when clicked: its area is a 'title' one
-- with a highlight limit of nothing, so Card:click falls straight through
-- (card.lua, Card:click). That is the space this uses.

local celesta_web_click_ref = Card.click
function Card:click(...)
    local area = self.area
    local center = self.config and self.config.center
    if area and area.config and area.config.collection
        and center and center.set == "Joker"
        -- An undiscovered Joker is a "?" in the collection, and its web would
        -- say what it is.
        and center.discovered
        and #CelestasMod.merge_partners(center.key) > 0 then
        CelestasMod.open_merge_web(center.key)
        return
    end
    return celesta_web_click_ref(self, ...)
end
