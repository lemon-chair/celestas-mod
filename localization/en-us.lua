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
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_bao = {
                name = "Bao",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_bearthewitch = {
                name = "Bearthewitch",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_beepers = {
                name = "Beepers",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_beribug = {
                name = "Beribug",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_berrycrepe = {
                name = "Berrycrepe",
                text = {
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
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
                name = "Cottontail",
                text = {
                    "{C:mult}+#1#{} Mult",
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
                name = "Cweamcat",
                text = {
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_demenishki = {
                name = "Demenishki",
                text = {
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
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
                name = "MotherV3",
                text = {
                    "{C:mult}+#1#{} Mult",
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
                name = "Onigiri",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_overezeggs = {
                name = "Overezeggs",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_pandabearlily = {
                name = "Pandabearlily",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_papamutt = {
                name = "Papamutt",
                text = {
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_shoto = {
                name = "Shoto",
                text = {
                    "{C:mult}+#1#{} Mult",
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
                    "{C:mult}+#1#{} Mult",
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
                name = "x3dustco",
                text = {
                    "{C:mult}+#1#{} Mult",
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
                name = "Yomiquinnely",
                text = {
                    "{C:mult}+#1#{} Mult",
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
        dictionary = {
            celesta_cfg_verbose = "Verbose logging",
            celesta_cfg_downpour = "Force Downpour (debug)",
            -- Floating message text. Vanilla has no generic "+card" key
            -- (k_plus_stone is Marble Joker's own), so this mod supplies one.
            celesta_plus_seven = "+7 of Spades",
            celesta_downpour = "Downpour!",
        },
    },
}
