--- STICKERS
---
--- Each sticker is a card-sized overlay with its icon painted into it, so where an icon sits is a
--- fact about the sheet, and the base game's three sit like this (2x sheet, 142x190 cell, centre
--- of each icon): Eternal (28, 26) and Perishable (28, 26) - the same place - and Rental (26, 66),
--- 40 pixels lower. A Joker wearing Eternal and Perishable had one icon on top of the other, and
--- one wearing all three had Perishable and Rental on top of each other instead.
---
--- Every icon gets a place of its own, the way a pile of stickers is laid out in Cryptid: not by
--- repainting the sheet, but by where the sticker is drawn - one place down the left edge for each
--- sticker that sits above it, and no further than that, so a card is drawn as the base game
--- draws it wherever the base game was not overlapping.
---
---   Eternal    the corner, always
---   Perishable the corner; the next place down when Eternal holds it
---   Rental     the second place, as in the base game; the third when Eternal and Perishable
---              both hold the first two
---
--- Done as an offset on the draw rather than as new art, so there is no art of the base game's to
--- copy: a sprite's draw_shader takes an offset, and the sprites for these stickers are each given
--- a draw_shader of their own that adds the one the card they are being drawn on calls for. The
--- card is the one Steamodded has just named the sprite's draw_major (card_draw.lua:288, :302).

local DOWN = 40 / 190
local LEFT = -2 / 142

--- How far down the card (as a fraction of its height) and left of the corner icon (as a fraction
--- of its width) `sticker`'s icon is drawn on `card`, over where its sprite puts it.
local function offset_for(card, sticker)
    local ability = card and card.ability
    if not ability then return 0, 0 end

    local dx, dy = 0, 0
    if sticker == "perishable" then
        -- The next place down, and in the column Rental's icon sits in.
        if ability.eternal then dx, dy = LEFT, DOWN end
    elseif sticker == "rental" then
        -- Rental's own place is the second; with the first two both taken it is the third.
        if ability.eternal and ability.perishable then dy = DOWN end
    end

    -- A square Joker's picture starts 12 rows below the top of the card's cell, so every icon goes
    -- down by that much: the same distance in from the picture's own corner as on any other card.
    if CelestasMod.is_square_joker and CelestasMod.is_square_joker(card) then
        dy = dy + (CelestasMod.SQUARE_SHIFT or 0)
    end
    return dx, dy
end

CelestasMod.sticker_offset = offset_for

--- Moves one sticker's sprite by what its card calls for. Idempotent: the sprite is shared by every
--- card.
local function place(sticker)
    local sprite = G["shared_sticker_" .. sticker]
    if not sprite or sprite.celesta_placed then return end
    sprite.celesta_placed = true

    local draw_ref = sprite.draw_shader
    sprite.draw_shader = function(self, shader, shadow, send, no_tilt, other, ms, mr, mx, my, ...)
        local dx, dy = offset_for(self.role and self.role.draw_major, sticker)
        if dx ~= 0 or dy ~= 0 then
            mx, my = (mx or 0) + dx * G.CARD_W, (my or 0) + dy * G.CARD_H
        end
        return draw_ref(self, shader, shadow, send, no_tilt, other, ms, mr, mx, my, ...)
    end
end

--- The three that can be moved. Eternal holds the corner on every card but a square one, whose
--- picture does not start at the top of the cell.
local MOVABLE = { "eternal", "perishable", "rental" }

local function place_all()
    for _, sticker in ipairs(MOVABLE) do place(sticker) end
end

CelestasMod.place_stickers = place_all

-- The sprites are made when Steamodded injects the stickers, which is after every mod has loaded,
-- so they are looked for when there is a run to draw them in and again, cheaply, as cards are drawn.
local celesta_sticker_start_ref = Game.start_run
function Game:start_run(...)
    local out = celesta_sticker_start_ref(self, ...)
    place_all()
    return out
end

local celesta_sticker_draw_ref = Card.draw
function Card:draw(...)
    for _, sticker in ipairs(MOVABLE) do
        local sprite = G["shared_sticker_" .. sticker]
        if sprite and not sprite.celesta_placed then place(sticker) end
    end
    return celesta_sticker_draw_ref(self, ...)
end
