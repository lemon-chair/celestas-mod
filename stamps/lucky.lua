--- THE LUCKY STAMP
---
--- The odds listed on the Joker it is on are guaranteed: "1 in 4" rolls, and reads, as "4 in 4".
---
--- Answered at SMODS.get_probability_vars, the one funnel both halves of a chance go through -
--- pseudorandom_probability rolls with what it returns and every loc_vars prints it - and for the
--- reason Ellie Minibot's wrap in jokers/implemented.lua is there: it is a statement about the
--- Joker a chance is rolled FOR, `trigger_obj`, and a calculate is something a Joker has to be
--- asked for. A merged Joker rolls the other half's chance from inside that half's own calculate,
--- where the card is lent the other half's ability table - which is why the stamp is read through
--- Stamps.worn and not off card.ability.
---
--- A guarantee is `n in n`, and nothing is past it. Dice's doubling is capped at the same place
--- and Ellie's wrap sits outside both, so whichever of them answers last answers the same.

local celesta_lucky_probability_ref = SMODS.get_probability_vars
function SMODS.get_probability_vars(trigger_obj, base_numerator, base_denominator,
                                    identifier, from_roll, no_mod, ...)
    local numerator, denominator = celesta_lucky_probability_ref(
        trigger_obj, base_numerator, base_denominator, identifier, from_roll,
        no_mod, ...)

    -- no_mod is the caller saying nothing may touch this one.
    if no_mod then return numerator, denominator end
    -- A Joker's chance and nothing else: a playing card's is not "listed on this Joker".
    local ability = type(trigger_obj) == "table" and trigger_obj.ability
    if not (type(ability) == "table" and ability.set == "Joker") then
        return numerator, denominator
    end
    if not (CelestasMod.lucky and CelestasMod.lucky(trigger_obj)) then
        return numerator, denominator
    end
    -- Only a number, or a Talisman big number: the denominator is whatever the roller passed, and
    -- Cryptid's RNJoker passes a sentence.
    if type(denominator) ~= "number"
        and not (type(denominator) == "table" and getmetatable(denominator)) then
        return numerator, denominator
    end

    return denominator, denominator
end
