--- Player-facing text. Maintained by tools/gen_roster.py, which only ever
--- APPENDS entries for art that has no text yet - anything already here is
--- preserved verbatim, so it is safe to write real descriptions in place.
---
--- Keys use the full prefixed form: key "shylily" -> j_celesta_shylily.
--- Colour tags: {C:chips} {C:mult} {C:money} {C:attention} {X:mult,C:white}
--- plus this mod's own {C:celesta_pink} {C:celesta_purple} {C:celesta_teal}
--- {C:celesta_gold} from globals.lua. {} resets.

return {
    descriptions = {
        Joker = {
            j_celesta_spark = {
                name = "Spark",
                text = {
                    "{C:chips}+#1#{} Chips",
                },
            },
            j_celesta_ledger = {
                name = "The Ledger",
                text = {
                    "This Joker gains {C:mult}+#1#{} Mult",
                    "per discarded card",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
            j_celesta_tollkeeper = {
                name = "Tollkeeper",
                text = {
                    "Played {C:diamonds}Diamond{} cards",
                    "give {X:mult,C:white}X#1#{} Mult when scored",
                    "Earn {C:money}$#2#{} at end of round",
                },
            },
            j_celesta_aicandii = {
                name = "AiCandii",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_amalee = {
                name = "AmaLee",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_aquwa = {
                name = "Aquwa",
                text = {
                    "At the start of each round,",
                    "starts a {C:blue}Downpour{}",
                    "{C:inactive}Consumables obtained during{}",
                    "{C:inactive}a Downpour are {C:dark_edition}Negative",
                },
            },
            j_celesta_arar = {
                name = "Arar",
                text = {
                    "At the start of each round,",
                    "add a random {C:attention}enhancement{} to",
                    "a random unenhanced card",
                    "held in hand",
                },
            },
            j_celesta_arielle = {
                name = "Arielle",
                text = {
                    "All cards are considered",
                    "to be the {C:attention}same suit{}",
                },
            },
            j_celesta_ariesakana = {
                name = "Ariesakana",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_augustanomoly = {
                name = "Augustanomoly",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_axialmatt = {
                name = "Axialmatt",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_baddaboom = {
                name = "Baddaboom",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult",
                    "each time a {C:attention}Gash{} card breaks",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            j_celesta_bao = {
                name = "Bao",
                text = {
                    "{C:mult}+#1#{} Mult, or {X:mult,C:white}X#2#{} Mult",
                    "during a {C:blue}Downpour{}",
                },
            },
            j_celesta_bearthewitch = {
                name = "Bear The Witch",
                text = {
                    "{C:attention}Bonus{} cards give",
                    "{C:chips}+#1#{} extra Chips",
                    "when scored",
                },
            },
            j_celesta_beepers = {
                name = "Beepers",
                text = {
                    "{C:green}#1# in #2#{} chance to add a",
                    "{C:attention}Foppy Seal{} to a scored",
                    "card with a {C:red}Red Seal{}",
                },
            },
            j_celesta_beribug = {
                name = "Beribug",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_berrycrepe = {
                name = "BerryCrepe",
                text = {
                    "Scored cards permanently",
                    "gain {C:mult}+#1#{} Mult",
                },
            },
            j_celesta_birdyovo = {
                name = "Birdyovo",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_bluto = {
                name = "Bluto",
                text = {
                    "Retriggers {C:attention}Blueprint{} and",
                    "{C:attention}Brainstorm{} {C:attention}#1#{} extra time each",
                },
            },
            j_celesta_bricky = {
                name = "Bricky",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_buffpup = {
                name = "Buffpup",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_camila = {
                name = "Camila",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_cerbervt = {
                name = "CerberVT",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_chacha = {
                name = "Chacha",
                text = {
                    "When this Joker is {C:attention}sold{},",
                    "gain an {C:attention}Uncommon{} or",
                    "{C:attention}Rare{} Joker tag",
                },
            },
            j_celesta_chibidoki = {
                name = "Chibidoki",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_clover = {
                name = "Clover",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_cottontail = {
                name = "CottontailVA",
                text = {
                    "{C:green}#1# in #2#{} chance to add a",
                    "{C:attention}Star Seal{} to a scored",
                    "{C:attention}face card{} with no seal",
                },
            },
            j_celesta_crelly = {
                name = "Crelly",
                text = {
                    "At the end of the shop,",
                    "{C:attention}consumes{} a random held",
                    "consumable and gains {X:mult,C:white}X#1#{} Mult",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            j_celesta_cweamcat = {
                name = "CweamCat",
                text = {
                    "This Joker gains {C:chips}+#1#{} Chips",
                    "if played hand is a {C:attention}#2#{}",
                    "{C:inactive}(hand changes after each hand played)",
                    "{C:inactive}(Currently {C:chips}+#3#{C:inactive} Chips)",
                },
            },
            j_celesta_cyyuvtuber = {
                name = "CyyuVTuber",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_dejavudea = {
                name = "Dejavudea",
                text = {
                    "{C:attention}Halves{} all listed",
                    "{C:green}probabilities{}",
                    "{C:inactive}(e.g. 1 in 4 becomes 1 in 8)",
                },
            },
            j_celesta_demenishki = {
                name = "Deme",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult",
                    "per consecutive hand played",
                    "with exactly {C:attention}1{} card",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            j_celesta_dooby = {
                name = "Dooby",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_el_xox = {
                name = "El_XoX",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_elorapard = {
                name = "Elorapard",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_fefe = {
                name = "Fefe",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_fraiki = {
                name = "Fraiki",
                text = {
                    "{C:green}#1# in #2#{} chance to add a",
                    "{C:attention}Rose Seal{} to a scored",
                    "{C:attention}non-face card{} with no seal",
                },
            },
            j_celesta_fream = {
                name = "Fream",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_froggyloch = {
                name = "FroggyLoch",
                text = {
                    "Scoring cards have a",
                    "{C:green}#1# in #2#{} chance to retrigger",
                    "{C:attention}#3#{} additional time",
                },
            },
            j_celesta_fufu = {
                name = "Fufu",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_geega = {
                name = "Geega",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_giwi = {
                name = "Giwi",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_hannahhyrule = {
                name = "Hannahhyrule",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_harukakaribu = {
                name = "Harukakaribu",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_heavenlyfather = {
                name = "HeavenlyFather",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_henya = {
                name = "Henya",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_huntressspectre = {
                name = "HuntressSpectre",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_ironmouse = {
                name = "Ironmouse",
                text = {
                    "{E:1,C:mult}^#1#{} Mult",
                },
            },
            j_celesta_itsdeadlyboop = {
                name = "ItsDeadlyBoop",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_jaws = {
                name = "Jaws",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_jaxvtuber = {
                name = "JaxVTuber",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_jowol = {
                name = "Jowol",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_juniperactias = {
                name = "Juniperactias",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_kael = {
                name = "Kael",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_kairyucrocodile = {
                name = "Kairyucrocodile",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_kirana = {
                name = "Kirana",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_kiri = {
                name = "Kiri",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_kokonuts = {
                name = "KokoNuts",
                text = {
                    "At the start of each round,",
                    "add a {C:attention}Lucky{} {C:attention}7 of Spades{}",
                    "to your deck",
                },
            },
            j_celesta_kourra = {
                name = "Kourra",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_kumi = {
                name = "Kumi",
                text = {
                    "Destroys all scoring",
                    "{C:attention}Gold{} cards in played hand",
                    "{C:green}#1# in #2#{} chance to earn",
                    "{C:money}$#3#{} per card destroyed",
                },
            },
            j_celesta_kyaree = {
                name = "Kyaree",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_laynalazar = {
                name = "LaynaLazar",
                text = {
                    "Removes {C:attention}Mult{} enhancements",
                    "from scoring cards, this Joker",
                    "gains {C:mult}+#1#{} Mult per",
                    "enhancement removed",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
            j_celesta_liffeh = {
                name = "Liffeh",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_limealicious = {
                name = "Limealicious",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_lucypyre = {
                name = "Lucypyre",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_maplechicken = {
                name = "Maplechicken",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_mariyume = {
                name = "Mariyume",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_maya = {
                name = "Maya",
                text = {
                    "{C:green}#1# in #2#{} chance to retrigger",
                    "each {C:attention}Steel Card{} held in hand",
                    "{C:attention}#3#{} extra times",
                },
            },
            j_celesta_megalodon = {
                name = "Megalodon",
                text = {
                    "This Joker gains {C:mult}+#1#{} Mult",
                    "for each card in played hand",
                    "{C:inactive}Resets at end of round{}",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
            j_celesta_meicha = {
                name = "Meicha",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_mellowmabel = {
                name = "Mellowmabel",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_michi = {
                name = "Michi",
                text = {
                    "{C:purple}Purple Seal{} cards give",
                    "{C:attention}2{} Tarot cards",
                    "when discarded",
                },
            },
            j_celesta_milky = {
                name = "Milky",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_mintfantome = {
                name = "Mintfantome",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_monikacinnyroll = {
                name = "MonikaCinnyroll",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_moomerrily = {
                name = "Moomerrily",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_mooni = {
                name = "Mooni",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_motherv3 = {
                name = "MOTHERv3",
                text = {
                    "After a hand is played,",
                    "adds {C:attention}Exo{} to a random",
                    "unenhanced card held in hand",
                },
            },
            j_celesta_nagzz = {
                name = "Nagzz",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_nekrolina = {
                name = "Nekrolina",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_neuro = {
                name = "Neuro",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_nicoviras = {
                name = "Nicoviras",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_nihmune = {
                name = "Nihmune",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_nostro = {
                name = "Nostro",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_nyanners = {
                name = "Nyanners",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_onigiri = {
                name = "OniGiri",
                text = {
                    "Copies the ability of",
                    "a random {C:attention}Joker{}",
                    "{C:inactive}(changes after each hand played)",
                },
            },
            j_celesta_overezeggs = {
                name = "OverEzEggs",
                text = {
                    "At the end of each round,",
                    "converts all cards held",
                    "in hand to {C:hearts}Hearts{}",
                },
            },
            j_celesta_pandabearlily = {
                name = "PandaBearLily",
                text = {
                    "If the {C:attention}first hand{} of a round",
                    "is a single card, add {C:attention}#1#{} random",
                    "cards of that suit to your deck",
                },
            },
            j_celesta_papamutt = {
                name = "Papa Mutt",
                text = {
                    "Creates a random {C:tarot}Tarot{} card",
                    "if played hand is a {C:attention}#1#{}",
                    "{C:inactive}(Must have room)",
                },
            },
            j_celesta_pipi = {
                name = "Pipi",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_pomatomaster = {
                name = "Pomatomaster",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_pristinezero = {
                name = "Pristinezero",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_radiaactive = {
                name = "Radiaactive",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_radicalmari = {
                name = "Radicalmari",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_rainhoe = {
                name = "Rainhoe",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_rainyrentyn = {
                name = "Rainyrentyn",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_ray = {
                name = "Ray",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_rinpenrose = {
                name = "Rinpenrose",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_rosedoodle = {
                name = "Rosedoodle",
                text = {
                    "{C:attention}Mult{} cards have a {C:green}#1# in #2#{}",
                    "chance to give {X:mult,C:white}X#3#{} Mult",
                    "when scored",
                },
            },
            j_celesta_rtgame = {
                name = "RTGame",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_rynxryn = {
                name = "Rynxryn",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_saruei = {
                name = "Saruei",
                text = {
                    "{C:attention}Gash{} cards always",
                    "break when scored",
                },
            },
            j_celesta_shenpai = {
                name = "Shenpai",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_shiabun = {
                name = "Shiabun",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_shoomimi = {
                name = "Shoomimi",
                text = {
                    "{C:green}#1# in #2#{} chance to gain",
                    "{C:attention}+1{} consumable slot",
                    "for each shop {C:attention}reroll{}",
                },
            },
            j_celesta_shoto = {
                name = "Shoto",
                text = {
                    "{C:green}#1# in #2#{} chance to add a",
                    "{C:attention}Gash{} to a scored card",
                },
            },
            j_celesta_shylily = {
                name = "ShyLily",
                text = {
                    "Retriggers the {C:attention}last{}",
                    "scoring card {C:attention}#1#{}",
                    "additional times",
                },
            },
            j_celesta_sinder = {
                name = "Sinder",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_smugalana = {
                name = "Smugalana",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_snapscube = {
                name = "Snapscube",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_spite = {
                name = "Spite",
                text = {
                    "{C:green}#1# in #2#{} chance to add an",
                    "{C:attention}Ectoplast Seal{} to a scored",
                    "{C:attention}enhanced card{} with no seal",
                },
            },
            j_celesta_spongeybuns = {
                name = "Spongeybuns",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_suto = {
                name = "Suto",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_vedal = {
                name = "Vedal",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_vexoria = {
                name = "Vexoria",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_vulpixie = {
                name = "Vulpixie",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_x3dustco = {
                name = "x3Dustco",
                text = {
                    "At the end of the shop,",
                    "creates a random {C:attention}Joker{}",
                    "from this mod",
                },
            },
            j_celesta_yoclesh = {
                name = "Yoclesh",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_yokasiri = {
                name = "Yokasiri",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_yomiquinnely = {
                name = "Yomi Quinnely",
                text = {
                    "Retriggers scored",
                    "{C:attention}#1#{} cards",
                    "{C:inactive}(suit changes each round)",
                },
            },
            j_celesta_yuy_ix = {
                name = "Yuy_ix",
                text = {
                    "On the {C:attention}final hand{} of the round,",
                    "each scoring card gives",
                    "{X:mult,C:white}X#1#{} Mult",
                },
            },
            j_celesta_yuzu = {
                name = "Yuzu",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_zentreya = {
                name = "Zentreya",
                text = {
                    "{C:attention}Steel Cards{} in played hand",
                    "give {X:mult,C:white}X#1#{} Mult when scored",
                },
            },
        },

        Tarot = {
            c_celesta_reforge = {
                name = "Reforge",
                text = {
                    "Enhances up to {C:attention}#1#{}",
                    "selected cards to",
                    "{C:attention}Mult Cards",
                },
            },
        },

        Enhanced = {
            m_celesta_exo = {
                name = "Exo Card",
                text = {
                    "Retriggered once per",
                    "{C:attention}consumable{} held",
                },
            },
            m_celesta_gash = {
                name = "Gash Card",
                text = {
                    "{X:mult,C:white}X#1#{} Mult",
                    "{C:green}#2# in #3#{} chance this",
                    "card is destroyed",
                },
            },
        },

        Other = {
            celesta_ectoplast_seal = {
                name = "Ectoplast Seal",
                text = {
                    "When scored, {C:green}#1# in #2#{} chance",
                    "to upgrade a random Joker's",
                    "{C:dark_edition}edition{} by one step",
                },
            },
            celesta_foppy_seal = {
                name = "Foppy Seal",
                text = {
                    "Retriggers this card",
                    "{C:attention}2{} extra times",
                },
            },
            celesta_rose_seal = {
                name = "Rose Seal",
                text = {
                    "When scored, permanently",
                    "gains {X:mult,C:white}X0.1{} Mult",
                },
            },
            celesta_star_seal = {
                name = "Star Seal",
                text = {
                    "When {C:attention}not scoring{}, copies the",
                    "card to its left into your deck",
                },
            },
        },

        Back = {
            b_celesta_founders = {
                name = "Founder's Deck",
                text = {
                    "Start with an extra {C:money}$#1#{}",
                    "and an {C:attention}Arar{}",
                    "{C:red}-#2#{} Joker slot",
                },
            },
        },

        Mod = {
            CelestasMod = {
                name = "Celesta's Mod",
                text = {
                    "VTuber Jokers.",
                },
            },
        },
    },

    misc = {
        labels = {
            m_celesta_exo = "Exo Card",
            m_celesta_gash = "Gash Card",
            celesta_ectoplast_seal = "Ectoplast Seal",
            celesta_foppy_seal = "Foppy Seal",
            celesta_rose_seal = "Rose Seal",
            celesta_star_seal = "Star Seal",
        },
        dictionary = {
            celesta_cfg_animation = "Arena animation (off = tint only)",
            celesta_cfg_verbose = "Verbose logging",
            celesta_cfg_downpour = "Force Downpour (debug)",
            -- Floating message text. Vanilla has no generic "+card" key
            -- (k_plus_stone is Marble Joker's own), so this mod supplies one.
            celesta_upgraded = "Upgraded!",
            celesta_gashed = "Gashed!",
            celesta_plus_slot = "+1 Consumable Slot",
            celesta_plus_tag = "+1 Tag",
            celesta_sealed = "Sealed!",
            celesta_hearts = "All Hearts!",
            celesta_plus_seven = "+7 of Spades",
            celesta_downpour = "Downpour!",
        },
    },
}
