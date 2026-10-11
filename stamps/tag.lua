--- THE STAMP TAG
---
--- A Tag that opens a free Stamp Pack, the way the Buffoon Tag opens a free Mega Buffoon Pack. It
--- is given by the Purgatory Deck's "Gain a Stamp tag" boon and by nothing else: it is not in the
--- pool the skip Tags are drawn from.
---
--- Its picture is the Buffoon Tag's for now: the real art has not been drawn. Replace `atlas` and
--- `pos` with an atlas of its own when it has.

-- Resolved at load: SMODS.current_mod is only valid while the mod is loading.
local PACK_KEY = "p_" .. SMODS.current_mod.prefix .. "_stamp_pack"

SMODS.Tag {
    key = "stamp",
    atlas = "tags",
    pos = { x = 4, y = 2 },
    config = { type = "new_blind_choice" },
    discovered = true,

    -- Never offered for skipping a Blind: only handed out.
    in_pool = function(self, args) return false end,

    loc_vars = function(self, info_queue, tag)
        return { vars = {} }
    end,

    apply = function(self, tag, context)
        if context.type ~= "new_blind_choice" then return end

        -- The Buffoon Tag's own sequence (tag.lua:292): lock input, open a pack made for free,
        -- unlock. A Tag that skipped the lock would let the Blind select screen be clicked while
        -- the pack is still arriving.
        local lock = tag.ID
        G.CONTROLLER.locks[lock] = true
        tag:yep("+", G.C.SECONDARY_SET.Spectral, function()
            local key = PACK_KEY
            local card = Card(G.play.T.x + G.play.T.w / 2 - G.CARD_W * 1.27 / 2,
                              G.play.T.y + G.play.T.h / 2 - G.CARD_H * 1.27 / 2,
                              G.CARD_W * 1.27, G.CARD_H * 1.27, G.P_CARDS.empty, G.P_CENTERS[key],
                              { bypass_discovery_center = true, bypass_discovery_ui = true })
            card.cost = 0
            card.from_tag = true
            G.FUNCS.use_card({ config = { ref_table = card } })
            card:start_materialize()
            G.CONTROLLER.locks[lock] = nil
            return true
        end)
        tag.triggered = true
        return true
    end,
}
