--- WHICH JOKERS COME FIRST IN THE COLLECTION
---
--- The Joker collection pages straight through G.P_CENTER_POOLS.Joker in
--- registration order, which is the order the files happened to load in and
--- says nothing about anything. This puts fifteen of them - one full page, five
--- to a row - at the front of THIS MOD'S stretch of it.
---
--- The front of the mod's block rather than the front of the collection: the
--- vanilla Jokers come first and stay there, so these open the first page that
--- is this mod's. With the current counts that is page 11, and it stays the
--- first page of the mod whatever those counts become - which hardcoding a page
--- number would not.
---
--- Done by wrapping SMODS.collection_pool rather than by reordering the pool
--- itself. That function is what the collection screens build their grid from
--- (ui.lua:1964 through card_collection_UIBox), and it already hands back a
--- COPY, so rearranging it changes what is shown and nothing else. The pool is
--- also what create_card draws from, and reordering that would be reaching into
--- the run to change a menu.
---
--- Every other Joker keeps the order it had, immediately behind these.

--- One page of the Joker collection, in reading order: five to a row.
CelestasMod.COLLECTION_FIRST = {
    "j_celesta_arar", "j_celesta_froggyloch", "j_celesta_kumi",
    "j_celesta_maya", "j_celesta_kokonuts",

    "j_celesta_eidolonwyrm", "j_celesta_yharon", "j_celesta_xm05_thanatos",
    "j_celesta_cryogen", "j_celesta_ben",

    "j_celesta_blue_card", "j_celesta_green_card", "j_celesta_fuchsia_card",
    "j_celesta_boosfer", "j_celesta_blank_joker",
}

if type(SMODS.collection_pool) == "function" then
    local celesta_collection_pool_ref = SMODS.collection_pool

    function SMODS.collection_pool(base_pool)
        local pool = celesta_collection_pool_ref(base_pool)

        -- Jokers only. Every other collection screen - Tarots, Vouchers,
        -- Blinds - comes through here too, with its own pool.
        if base_pool ~= (G.P_CENTER_POOLS and G.P_CENTER_POOLS.Joker) then
            return pool
        end

        -- Where this mod's Jokers start. Everything before it is somebody
        -- else's and is left exactly where it is.
        local ours = nil
        for i, center in ipairs(pool) do
            if CelestasMod.is_ours(center) then ours = i break end
        end
        if not ours then return pool end

        local wanted = {}
        for i, key in ipairs(CelestasMod.COLLECTION_FIRST) do wanted[key] = i end

        -- Held by position rather than appended in the order they are met, so
        -- the page reads the way the list is written whatever order the pool
        -- happens to be in.
        local first, rest = {}, {}
        for i, center in ipairs(pool) do
            local place = i >= ours and center.key and wanted[center.key]
            if place then first[place] = center else rest[#rest + 1] = center end
        end

        local out = {}
        -- Everything ahead of this mod, untouched.
        for i = 1, ours - 1 do out[#out + 1] = rest[i] end

        -- A gap is skipped rather than left as a hole: a Joker in the list that
        -- the screen is not showing - filtered to another mod's page, or removed
        -- outright - must not shift the rest of the page or end the loop.
        for i = 1, #CelestasMod.COLLECTION_FIRST do
            if first[i] then out[#out + 1] = first[i] end
        end
        for i = ours, #rest do out[#out + 1] = rest[i] end

        return out
    end
end
