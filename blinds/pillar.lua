--------------------------------------------------------------------------------
-- The Pillar never judges a card in the hand being played
--------------------------------------------------------------------------------
--
-- The Pillar debuffs a card carrying ability.played_this_ante, and
-- G.FUNCS.play_cards_from_highlighted gives every card in the hand that flag the
-- moment it is played (state_events.lua:481) - before evaluate_play has run at all.
-- Vanilla only asks the Blind to judge a card at the start of the Blind and when a
-- card is rewritten, and never rewrites one mid-hand, so the flag is never read in
-- the hand it was given in. Anything that does rewrite or re-judge a played card
-- while it scores - a conversion, an enhancement, a seal - reads it, and the card
-- goes dead mid-scoring.
--
-- globals.lua's CelestasMod.unjudged does this for the callers that know to ask.
-- This is the same thing at the one place they all end up, for the ones that do not:
-- a Blind judging a card that is in the play area ignores that one flag, across
-- the call. Every other rule a Blind has is applied as always, to the card as it
-- now is, and the flag goes straight back, so the card is still debuffed at the next
-- Blind - which is what The Pillar is for.
--
-- The first time it steps in from each place is written to the log, since a
-- re-judge that nothing is guarding is worth finding.

if Blind and type(Blind.debuff_card) == "function" then
    local celesta_pillar_debuff_ref = Blind.debuff_card

    function Blind:debuff_card(card, from_blind)
        if self.name == "The Pillar" and not from_blind and card
            and G.play and card.area == G.play
            and card.ability and card.ability.played_this_ante then
            local info = debug.getinfo(2, "Sl")
            CelestasMod.warn_once(
                "pillar_rejudge:" .. tostring(info and info.short_src) .. ":" .. tostring(info and info.currentline),
                "The Pillar was asked to judge a card being played, called from "
                    .. tostring(info and info.short_src) .. ":" .. tostring(info and info.currentline)
                    .. "; it was not debuffed for having been played.")
            local ret
            CelestasMod.unjudged(card, function()
                ret = celesta_pillar_debuff_ref(self, card, from_blind)
            end)
            return ret
        end
        return celesta_pillar_debuff_ref(self, card, from_blind)
    end
end
