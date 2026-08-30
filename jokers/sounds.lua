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
--- Each of these is played from its Joker's add_to_deck, guarded on
--- `not from_debuff` - see any of them for why.

SMODS.Sound { key = "ben_join",      path = "ben_join.ogg" }
SMODS.Sound { key = "kokonuts_join", path = "kokonuts_join.ogg" }
SMODS.Sound { key = "shoomimi_join", path = "shoomimi_join.ogg" }
