--- XM-05 THANATOS [Rare]
---
--- A LANDSCAPE Joker: its art is 95x71 where a card is 71x95, and it is meant
--- to be too wide for its slot and to overhang the Jokers either side of it.
---
--- Its own file because of that, not because of the effect. A Joker's face is
--- drawn stretched to G.CARD_W by G.CARD_H, so a landscape face would be
--- squashed into portrait; the art has to be an overlay instead, and an
--- overlay is a Card:draw hook, which jokers/implemented.lua cannot hold - the
--- test harnesses slice that file and run it against stubs.
---
--- So the Joker's own face is an empty card cell and the art is drawn over it
--- from a second sheet. Sprite:draw_from scales a sheet by the CARD's
--- dimensions rather than the sheet's (engine/sprite.lua:88), so 71 pixels
--- across is one card width whatever the sheet is: a 95-pixel sheet comes out
--- 95/71 of a card wide and hangs over the edges by twelve pixels a side.
---
--- The sheet is 95 TALL as well, not 71, so the vertical mapping is the card's
--- own and needs no correction - only the horizontal overhang is offset, and
--- only in one place. tools/gen_thanatos.py builds both sheets, with Balatro's
--- corner silhouette turned a quarter turn for the landscape one.

local THANATOS_KEY = "j_" .. SMODS.current_mod.prefix .. "_xm05_thanatos"

-- Declared here rather than in the generated jokers/atlases.lua: that file is
-- one atlas per Joker face, and this sheet is not a face.
SMODS.Atlas { key = "xm05_thanatos_wide", path = "xm05_thanatos_wide.png",
              px = 95, py = 95 }
local WIDE_ATLAS = SMODS.current_mod.prefix .. "_xm05_thanatos_wide"

--- Half the overhang, as a fraction of a card's width: the sheet is 95 across
--- where the card is 71, so it starts twelve pixels to the left of it.
local OVERHANG = (95 - 71) / 2 / 71

--- True when this card is a Thanatos, either half of it.
---
--- Asked of both halves because a merged card is one card doing two Jokers'
--- jobs: a Thanatos bound into something else still eats, so it still shows.
local function is_thanatos(card)
    if not (card and card.config) then return false end
    local center = card.config.center
    if center and center.key == THANATOS_KEY then return true end

    local Bind = CelestasMod.Bind
    if Bind and Bind.is_merged and Bind.is_merged(card)
        and not (Bind.replacing_special and Bind.replacing_special(card)) then
        return card.ability.celesta_bind.key == THANATOS_KEY
    end
    return false
end

-- One sprite shared by every Thanatos on the board, built on first use: the
-- atlases do not exist yet while this file is loading.
local wide_sprite = nil

local function wide()
    if wide_sprite then return wide_sprite end
    local atlas = G.ASSET_ATLAS[WIDE_ATLAS]
    if not atlas then return nil end
    wide_sprite = Sprite(0, 0, G.CARD_W, G.CARD_H, atlas, { x = 0, y = 0 })
    return wide_sprite
end

local celesta_thanatos_draw_ref = Card.draw
function Card:draw(layer)
    celesta_thanatos_draw_ref(self, layer)

    if not is_thanatos(self) then return end
    -- Nothing to show on the back of a card, and the shadow pass is the card's
    -- silhouette rather than its face.
    if self.facing == "back" or layer == "shadow" then return end

    local sprite = wide()
    local anchor = self.children.center
    if not (sprite and anchor) then return end

    -- The offset is in the card's own units, which is what draw_from's mx is
    -- added to: VT.w is one card across, so OVERHANG of it is twelve pixels of
    -- the sheet. No y offset - the sheet is a card tall already.
    sprite.role.draw_major = self

    --- One pass of the wide sheet, in the card's place.
    local function pass(shader, send)
        sprite:draw_shader(shader, nil, send, nil, anchor, nil, nil,
                           -OVERHANG * (anchor.VT.w or 0), 0)
    end

    -- An edition is drawn onto the card's OWN sprite, which is card shaped
    -- (SMODS card_draw.lua:252, and vanilla card.lua:4459 before it). This
    -- Joker's art is not: it hangs twelve pixels over each edge, and those
    -- twelve pixels were the only part of it left matte while the rest of the
    -- card shone. So every shader the card is wearing is run over the wide
    -- sheet as well, in the same order the game runs them.
    --
    -- Read off G.P_CENTER_POOLS.Edition rather than a list of the three
    -- vanilla ones, which is how SMODS itself does it: an edition is any
    -- centre whose flag is set on the card, so a modded one is covered by
    -- being registered rather than by being named here. `key:sub(3)` drops
    -- the "e_".
    local edition = self.delay_edition or self.edition

    -- Negative replaces the dissolve pass rather than adding to it, the way
    -- the card's own sprite is drawn (card_draw.lua:151).
    if edition and edition.negative then
        pass("negative", self.ARGS.send_to_shader)
    else
        pass("dissolve")
    end

    if edition then
        for _, e in pairs(G.P_CENTER_POOLS.Edition or {}) do
            if e.key and e.shader and edition[e.key:sub(3)] then
                pass(e.shader, self.ARGS.send_to_shader)
            end
        end
        if edition.negative then
            pass("negative_shine", self.ARGS.send_to_shader)
        end
    end
end

--------------------------------------------------------------------------------
-- XM-05 Thanatos [Rare] - eats the Steel Kings it finds in hand.
--------------------------------------------------------------------------------
--
-- context.before is the pass that runs once as a hand is played and before any
-- of it scores, which is when "held in hand" still means something: the played
-- cards have moved to G.play and what is left in G.hand is exactly the hand the
-- player kept. Doing this at joker_main instead would be reading the hand after
-- the game had already finished with it.
--
-- All three conditions are asked the way the game asks them. A King is
-- get_id() == 13, which is what Grandpaw Shao and Kael rewrite and what every
-- rank check in the mod goes through. Steel is asked through
-- SMODS.has_enhancement so a card wearing more than one still counts. The seal
-- is compared to the string "Red", which is what set_seal stores.
--
-- SMODS.destroy_cards does the removing: it refuses eternal and undestroyable
-- cards, plays the dissolve, and raises the removal contexts other Jokers watch
-- for. So the count is taken from what it ACTUALLY accepted rather than from
-- what was offered to it, and a hand full of eternal Steel Kings pays nothing.

--- Every Steel King with a Red Seal currently held in hand.
---
--- Not one something else is already destroying: that King is spoken for, and
--- eating it too would pay for a kill that was not this Joker's.
local function thanatos_targets()
    local held = G.hand and G.hand.cards
    if type(held) ~= "table" then return {} end

    local found = {}
    for _, card in ipairs(held) do
        if card.seal == "Red" and card.get_id and card:get_id() == 13
            and not card.getting_sliced
            and SMODS.has_enhancement(card, "m_steel") then
            found[#found + 1] = card
        end
    end
    return found
end

SMODS.Joker {
    key = "xm05_thanatos",
    atlas = "xm05_thanatos",
    pos = { x = 0, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = false,
    -- A copy would eat the same cards a second time, and there would be none
    -- left for it to eat.
    blueprint_compat = false, eternal_compat = true,

    config = { extra = { e_mult = 1, e_mult_gain = 0.05 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_steel
        info_queue[#info_queue + 1] = G.P_SEALS.Red
        return { vars = { 1 + card.ability.extra.e_mult_gain,
                          card.ability.extra.e_mult } }
    end,

    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            local targets = thanatos_targets()
            if #targets == 0 then return end

            -- Counted from what the destroy accepted rather than from the list
            -- handed to it: an eternal King is refused, and refusing it must
            -- not pay.
            --
            -- Accepted, not gone. destroy_cards flags each card it takes at
            -- once and dissolves it in a queued event (utils.lua:2573-2610),
            -- so straight after the call every King is still in G.hand.
            -- Waiting for REMOVED counted none of them: the Kings dissolved and
            -- nothing was gained. `destroyed` and `shattered` are the flags it
            -- sets on the spot, and an eternal King gets neither.
            SMODS.destroy_cards(targets)
            local eaten = 0
            for _, king in ipairs(targets) do
                if king.destroyed or king.shattered then eaten = eaten + 1 end
            end
            if eaten == 0 then return end

            SMODS.scale_card(card, {
                ref_table = card.ability.extra,
                ref_value = "e_mult",
                scalar_value = "e_mult_gain",
                no_message = true,
                operation = function(ref_table, ref_value, initial, scaling)
                    ref_table[ref_value] = initial + scaling * eaten
                end,
            })
            return {
                message = localize { type = "variable", key = "celesta_powmult",
                                     vars = { card.ability.extra.e_mult } },
                colour = G.C.MULT, card = card,
            }
        end

        if context.joker_main and card.ability.extra.e_mult > 1 then
            -- ^Mult is Talisman's, and Talisman is a declared dependency of
            -- this mod - but a run without it should say so rather than
            -- silently score nothing.
            if Card.get_chip_e_mult == nil then
                CelestasMod.warn_once("thanatos_no_talisman",
                    "XM-05 Thanatos scores ^Mult, which needs Talisman; "
                    .. "without it the Joker does nothing")
                return
            end
            return { e_mult = card.ability.extra.e_mult }
        end
    end,
}
