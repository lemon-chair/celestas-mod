--------------------------------------------------------------------------------
-- TEMPORARY. Delete this file and its line in main.lua once the crash is found.
--------------------------------------------------------------------------------
--
-- Two runs have died with LuaJIT's own out-of-memory abort - Windows recorded
-- exception 0xe24c4a04, which is LuaJIT's tag (4C 4A, "LJ") with Lua's
-- LUA_ERRMEM in the low byte - and neither left a crash screen, because
-- drawing one needs memory the process no longer had.
--
-- Nothing reaches the log at that point either: the error never becomes a Lua
-- error anybody catches, so SMODS never prints it. Watching the process from
-- outside says only that it was under 1.2 GB when it went, which rules out a
-- slow leak into the gigabytes and rules in a ceiling being hit.
--
-- So this writes the numbers from INSIDE, half a second apart, and closes the
-- file every time so the last line before the kill is on disk:
--
--   lua      collectgarbage("count") - the Lua heap itself, in MB. If this is
--            near 1000 the run is against LuaJIT's non-GC64 ceiling and the
--            next allocation of any size is the one that kills it.
--   card     G.I.CARD and friends - every Card, Sprite, Moveable, UIBox and
--            node the game is holding. A leak shows here as a count that
--            climbs and never comes back down.
--   ev       events queued in G.E_MANAGER. A scoring loop that queues per
--            trigger runs away here first.
--   jok/con  the two rows, as cards/limit. This is what the Seraph change
--            moved, and the reason it is written down.
--
-- The file is celesta_memwatch.log, beside the save data.

local WATCH_EVERY = 0.5

local function count(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

--- cards/limit for a CardArea, without assuming it exists yet.
local function row(area)
    if not (area and area.config) then return "-/-" end
    local limit = area.config.card_limit
    if type(limit) ~= "number" then limit = -1 end
    return string.format("%d/%s", #(area.cards or {}),
        limit >= 1e6 and string.format("%.1e", limit) or string.format("%d", limit))
end

--- Everything the event manager is still holding, across all its queues.
local function queued()
    local n = 0
    if not (G.E_MANAGER and G.E_MANAGER.queues) then return 0 end
    for _, q in pairs(G.E_MANAGER.queues) do n = n + count(q) end
    return n
end

local PATH = (os.getenv("APPDATA") or ".")
    .. "\\Balatro\\celesta_memwatch.log"

local function write(line)
    -- Opened and closed every time: a buffered handle loses exactly the lines
    -- that matter, which are the ones written just before the process dies.
    local f = io.open(PATH, "a")
    if not f then return end
    f:write(line, "\n")
    f:close()
end

write(string.format("---- %s  run started", os.date("%Y-%m-%d %H:%M:%S")))

local since = 0
local celesta_memwatch_update_ref = Game.update
function Game:update(dt)
    celesta_memwatch_update_ref(self, dt)

    since = since + (dt or 0)
    if since < WATCH_EVERY then return end
    since = 0

    local ok, line = pcall(function()
        -- TEMPORARY, with the rest of this file: the convertible-Joker
        -- outline draws nothing at all in game, and there are exactly three
        -- ways for that to happen. This says which.
        local Lost = CelestasMod.Lost or {}
        local glow = string.format("atlas:%s soul:%s tgt:%d",
            (G.ASSET_ATLAS and G.ASSET_ATLAS["celesta_lost_glow"]) and "y" or "N",
            (Lost.soul_present and Lost.soul_present()) and "y" or "n",
            Lost.targets and #Lost.targets() or -1)
        local vedal = 0
        for _, held in ipairs(CelestasMod.find_joker("j_celesta_vedal") or {}) do
            local total = held.ability and held.ability.extra
                and held.ability.extra.total
            if type(total) == "number" then vedal = total end
        end

        return string.format(
            "%s state=%-2s lua=%7.1fMB card=%-5d sprite=%-5d move=%-5d "
            .. "uibox=%-4d node=%-5d ev=%-4d jok=%-12s con=%-12s "
            .. "hand=%-3d deck=%-3d vedal=%-9.3g glow=%s",
            os.date("%H:%M:%S"), tostring(G.STATE),
            collectgarbage("count") / 1024,
            count(G.I and G.I.CARD), count(G.I and G.I.SPRITE),
            count(G.I and G.I.MOVEABLE), count(G.I and G.I.UIBOX),
            count(G.I and G.I.NODE), queued(),
            row(G.jokers), row(G.consumeables),
            #((G.hand or {}).cards or {}), #((G.deck or {}).cards or {}),
            vedal, glow)
    end)

    write(ok and line or ("watch failed: " .. tostring(line)))
end
