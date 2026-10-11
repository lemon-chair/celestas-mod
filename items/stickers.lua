--- STICKERS
---
--- Eternal and Perishable are drawn on the same spot of a Joker: each sticker is a card-sized
--- overlay with its icon painted into it, and the base game paints both into the top-left corner
--- (cell (0, 0) and cell (0, 2) of its sticker sheet). A Joker wearing both had one icon on top of
--- the other. Rental's icon sits lower in its own cell, which is the place Perishable's wants.
---
--- So Eternal keeps the corner, and Perishable is drawn that much lower: where it sits in the sheet,
--- the same distance Rental's icon sits below Eternal's. Done as an offset on the draw rather than
--- a new sheet, so there is no art of the base game's to copy: a sprite's draw_shader takes an
--- offset, and the one sprite Perishable is drawn with is given a draw_shader of its own that adds
--- one.
---
--- Measured on the 2x sheet: Eternal's icon is centred (28, 26) in its 142x190 cell, Perishable's
--- (28, 26) in its own, Rental's (26, 66) in its. Rental is 40 pixels down and 2 to the left of the
--- other two, which is 40/190 of a card's height and 2/142 of its width.

local DOWN = 40 / 190
local LEFT = -2 / 142

--- Moves the one Perishable sprite down the card. Idempotent: the sprite is shared by every card.
local function lower_perishable()
    local sprite = G.shared_sticker_perishable
    if not sprite or sprite.celesta_lowered then return end
    sprite.celesta_lowered = true

    local draw_ref = sprite.draw_shader
    sprite.draw_shader = function(self, shader, shadow, send, no_tilt, other, ms, mr, mx, my, ...)
        return draw_ref(self, shader, shadow, send, no_tilt, other, ms, mr,
                        (mx or 0) + LEFT * G.CARD_W, (my or 0) + DOWN * G.CARD_H, ...)
    end
end

CelestasMod.lower_perishable = lower_perishable

-- The sprite is made when Steamodded injects the sticker, which is after every mod has loaded, so
-- it is looked for when there is a run to draw it in and again, cheaply, as cards are drawn.
local celesta_sticker_start_ref = Game.start_run
function Game:start_run(...)
    local out = celesta_sticker_start_ref(self, ...)
    lower_perishable()
    return out
end

local celesta_sticker_draw_ref = Card.draw
function Card:draw(...)
    if not G.shared_sticker_perishable or not G.shared_sticker_perishable.celesta_lowered then
        lower_perishable()
    end
    return celesta_sticker_draw_ref(self, ...)
end
