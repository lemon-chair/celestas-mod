--- HOW MANY CARDS A CONSUMABLE MAY BE USED ON
---
--- Vanilla caps it at five, every frame, in Card:update (card.lua:4452):
---
---     self.ability.consumeable.mod_num = math.min(5, ...max_highlighted)
---
--- and can_use_consumeable compares the SELECTION against mod_num rather than
--- against max_highlighted (card.lua:1809). So max_highlighted is the number
--- the card advertises, and mod_num is the number it will actually accept.
---
--- In vanilla the two can never disagree: a hand selection is capped at five
--- as well, so nothing can be highlighted past the cap and the min() never
--- does anything. Both halves of that hold together only because neither
--- number moves.
---
--- This mod moves both. Eidolon Wyrm and ShiaBun raise the selection limit, so
--- six cards CAN be highlighted; and Haruka doubles every Tarot's
--- max_highlighted, so The World reads "Converts up to 6 selected cards". With
--- six selected the description is honest, the selection is legal, and the USE
--- button stays grey - because mod_num is still five.
---
--- So the number is written again, after vanilla has written it, from the
--- value the card actually advertises. Nothing else changes: a consumable
--- still accepts only as many cards as its own description promises, and a
--- selection is still capped by the hand. The only thing removed is a ceiling
--- that exists to guard against a selection this mod deliberately allows.
---
--- Its own file because it wraps a global at load, and jokers/implemented.lua
--- is sliced apart and run against stubs by the test harnesses.

local celesta_targets_update_ref = Card.update

function Card:update(dt)
    celesta_targets_update_ref(self, dt)

    -- Cheapest test first: this runs for every card in the game, every frame,
    -- and almost none of them are consumables.
    local consumeable = self.ability and self.ability.consumeable
    if consumeable and type(consumeable.max_highlighted) == "number" then
        consumeable.mod_num = consumeable.max_highlighted
    end
end
