--- Sounds a Joker plays for itself.
---
--- Declared here rather than beside each Joker, and that is not a filing
--- preference. jokers/implemented.lua is sliced apart and run against stubs by
--- the test harnesses, so a top-level call in it has to be survivable by every
--- one of them - and SMODS.Sound at load is not. Enhancement sounds are
--- grouped the same way in enhancements/enhancements.lua for readability; this
--- one is grouped because it has to be.
---
--- Loaded after implemented.lua (jokers/ is walked in sorted order, and
--- "sounds" follows "implemented"), which is fine: nothing needs the sound to
--- exist until a Joker actually plays it.
---
--- Keys are prefixed like everything else, so `ben_join` becomes
--- celesta_ben_join. Avoid the words music, stream and ambient in a sound key:
--- Steamodded matches those to decide streaming vs static, and a one-second
--- effect wants static.
---
--- Each of these is played from its Joker's add_to_deck. All but Ben's go
--- through the `announces` helper at the top of implemented.lua, which carries
--- the `not from_debuff` guard and the reason for it; Ben has its own because
--- it also holds a hand-size bonus that debuffing SHOULD take away.
---
--- The map below is the single place a Joker is tied to its sound. Everything
--- else - the Jokers themselves, and merge/bind.lua when two of them become
--- one - goes through CelestasMod.play_join_sound and a Joker key, so there is
--- nowhere for a Joker and its sound to drift apart.

SMODS.Sound { key = "arar_join",     path = "arar_join.ogg" }
SMODS.Sound { key = "ben_join",      path = "ben_join.mp3" }
SMODS.Sound { key = "eidolonwyrm_join", path = "eidolonwyrm_join.wav" }
SMODS.Sound { key = "kokonuts_join", path = "kokonuts_join.ogg" }
SMODS.Sound { key = "kumi_join",     path = "kumi_join.ogg" }
SMODS.Sound { key = "maya_join",     path = "maya_join.ogg" }
SMODS.Sound { key = "shoomimi_join", path = "shoomimi_join.ogg" }
SMODS.Sound { key = "yharon_join",   path = "yharon_join.wav" }

--- Joker centre key -> the sound it announces itself with.
CelestasMod.JOIN_SOUNDS = {
    j_celesta_arar     = "celesta_arar_join",
    j_celesta_ben      = "celesta_ben_join",
    j_celesta_eidolonwyrm = "celesta_eidolonwyrm_join",
    j_celesta_kokonuts = "celesta_kokonuts_join",
    j_celesta_kumi     = "celesta_kumi_join",
    j_celesta_maya     = "celesta_maya_join",
    j_celesta_shoomimi = "celesta_shoomimi_join",
    j_celesta_yharon   = "celesta_yharon_join",
}

--- Plays a Joker's arrival sound, if it has one. Silent for every Joker that
--- does not, which is most of them.
function CelestasMod.play_join_sound(joker_key)
    local sound = joker_key and CelestasMod.JOIN_SOUNDS[joker_key]
    if sound then play_sound(sound) end
end
