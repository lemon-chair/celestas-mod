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
                    "At the end of the round, gains",
                    "{C:mult}+#1#{} Mult per unused {C:attention}discard{}",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
            j_celesta_amalee = {
                name = "AmaLee",
                text = {
                    "At the start of each round,",
                    "starts a {C:blue}Snowstorm{}",
                    "{C:green}#1# in #2#{} chance to {C:blue}Freeze{} a random",
                    "Joker after each hand played",
                },
            },
            j_celesta_angelsteps = {
                name = "Angelsteps",
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
            j_celesta_auteru = {
                name = "Auteru",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_axialmatt = {
                name = "AxialMatt",
                text = {
                    "Adds {C:attention}double{} the rank",
                    "of the {C:attention}highest{} ranked",
                    "card held in hand to {C:mult}Mult{}",
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
                name = "BeriBug",
                text = {
                    "Retriggers each scored",
                    "{C:attention}8{} {C:attention}#1#{} extra time",
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
                    "Every {C:attention}#1#{} scored cards",
                    "gives {X:mult,C:white}X#2#{} Mult",
                    "{C:inactive}(#3# remaining)",
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
                    "This Joker gains {C:chips}+#1#{} Chips",
                    "for each {C:attention}Stone Card{} and",
                    "{C:attention}Limestone Card{} in your full deck",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
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
                    "If first hand is a single card,",
                    "destroy it. At the start of the",
                    "next round, return it to your deck",
                    "with its {C:dark_edition}edition{} upgraded",
                    "{C:inactive}(caps at Polychrome)",
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
                    "Retriggers the {C:attention}lowest{} ranked",
                    "scoring card in played hand",
                    "{C:attention}#1#{} times",
                },
            },
            j_celesta_clover = {
                name = "Moo Moo Clover",
                text = {
                    "{C:spectral}Milk Bottles{} can select",
                    "up to {C:attention}#1#{} cards",
                },
            },
            j_celesta_cosmic = {
                name = "Cosmic",
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
                name = "Cy Yu",
                text = {
                    "Retriggers {C:attention}Exo{} cards",
                    "{C:attention}#1#{} extra times",
                },
            },
            j_celesta_dejavudea = {
                name = "Dejavudea",
                text = {
                    "Removes {C:attention}Tattered{} from cards",
                    "in played hand, and prevents",
                    "them from becoming {C:attention}Tattered{}",
                    "for the rest of the run",
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
            j_celesta_dokidomiki = {
                name = "Dokidomiki",
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
            j_celesta_ebiko = {
                name = "Ebiko",
                text = {
                    "Converts all scoring cards",
                    "in played hand to {C:diamonds}Diamonds{}",
                },
            },
            j_celesta_el_xox = {
                name = "El_Xox",
                text = {
                    "At the end of the round,",
                    "gain {C:money}$#1#{} for each",
                    "{C:attention}hand{} used that round",
                },
            },
            j_celesta_elara = {
                name = "Elara",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_ellyvtuber = {
                name = "Ellyvtuber",
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
            j_celesta_eros = {
                name = "Eros",
                text = {
                    "Removes {C:attention}Bonus{} enhancements",
                    "from scoring cards. This Joker",
                    "gains {C:chips}+#1#{} Chips per one removed",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            j_celesta_fefe = {
                name = "FeFe",
                text = {
                    "Converts all scoring cards",
                    "in played hand to {C:hearts}Hearts{}",
                },
            },
            j_celesta_fenari = {
                name = "Fenari",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_fleshy = {
                name = "Fleshy",
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
                    "Retriggers {C:attention}Wild Cards{}",
                    "#1# time",
                },
            },
            j_celesta_freyaamari = {
                name = "Freyaamari",
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
            j_celesta_froot = {
                name = "Froot",
                text = {
                    "{C:mult}+#1#{} Mult",
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
            j_celesta_glassesjournal = {
                name = "Glassesjournal",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_glowypumpkin = {
                name = "Glowypumpkin",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_hannahhyrule = {
                name = "Hannah Hyrule",
                text = {
                    "On the {C:attention}final hand{} of the round,",
                    "{X:chips,C:white}X#1#{} Chips and {X:mult,C:white}X#1#{} Mult",
                },
            },
            j_celesta_harukakaribu = {
                name = "Haruka Karibu",
                text = {
                    "Values on {C:tarot}Tarot{} cards",
                    "are {C:attention}#1# times{} as large",
                },
            },
            j_celesta_heavenlyfather = {
                name = "HeavenlyFather",
                text = {
                    "{C:attention}+#1#{} Booster Pack",
                    "slots available",
                    "in the shop",
                },
            },
            j_celesta_henya = {
                name = "Henya",
                text = {
                    "Retriggered cards give",
                    "{C:money}$#1#{} for each retrigger",
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
            j_celesta_isaa = {
                name = "Isaa",
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
                    "Destroys {C:attention}non-scoring{} cards",
                    "in played hand, gaining {C:chips}+#1#{} Chips each",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            j_celesta_jaxvtuber = {
                name = "Jax",
                text = {
                    "Retriggers {C:attention}Stone{} and",
                    "{C:attention}Limestone{} cards",
                    "{C:attention}#1#{} extra time",
                },
            },
            j_celesta_jowol = {
                name = "Jowol",
                text = {
                    "{C:attention}Stone{} cards held in hand",
                    "give {C:chips}+#1#{} Chips each",
                    "{C:inactive}(after cards in hand score)",
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
                    "{C:attention}Face cards{} are",
                    "considered {C:attention}10s{}",
                },
            },
            j_celesta_kairyucrocodile = {
                name = "Kairyu",
                text = {
                    "Gain {C:attention}+#1#{} hand size for each",
                    "{C:red}discard{} used this round",
                    "{C:inactive}(Currently {C:attention}+#2#{C:inactive} hand size)",
                    "{C:inactive}Resets at end of round",
                },
            },
            j_celesta_kirana = {
                name = "Kirana",
                text = {
                    "Gain {C:money}$#1#{} for each {C:attention}3{}",
                    "held in hand at the",
                    "end of the round",
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
                    "This Joker gains {C:chips}+#1#{} Chips",
                    "for each {C:spades}Spade{} card discarded",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
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
                    "{C:green}#1# in #2#{} chance to gain",
                    "an extra {C:tarot}Tarot{} card",
                    "whenever you gain one",
                },
            },
            j_celesta_limealicious = {
                name = "Limealicious",
                text = {
                    "At the start of each round,",
                    "adds a {C:attention}Limestone{} card",
                    "to your deck",
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
                name = "Mari Yume",
                text = {
                    "Copies the ability of",
                    "the {C:attention}rightmost{} Joker",
                },
            },
            j_celesta_matarakan = {
                name = "Matarakan",
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
                    "{C:attention}Straights{} can wrap around",
                    "{C:inactive}(e.g. 3, 2, Ace, King, Queen)",
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
                    "{C:spectral}Milk Bottles{} do not",
                    "take up consumable slots",
                },
            },
            j_celesta_minikomew = {
                name = "Minikomew",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_mintfantome = {
                name = "Mint Fantome",
                text = {
                    "When the played hand",
                    "finishes scoring, score the",
                    "{C:attention}leftmost{} card held in hand",
                },
            },
            j_celesta_monikacinnyroll = {
                name = "MonikaCinnyRoll",
                text = {
                    "Retriggers scoring cards",
                    "{C:attention}#1#{} extra time while",
                    "{C:blue}Downpour{} is active",
                },
            },
            j_celesta_moomerrily = {
                name = "Moo Merrily",
                text = {
                    "At the start of each round,",
                    "creates a {C:spectral}Milk Bottle{}",
                    "{C:inactive}(Must have room)",
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
                    "{C:attention}Halves{} all listed",
                    "{C:green}probabilities{}",
                    "{C:inactive}(e.g. 1 in 4 becomes 1 in 8)",
                },
            },
            j_celesta_nana_ruru = {
                name = "Nana Ruru",
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
                    "At the end of the round,",
                    "destroys all {C:attention}unenhanced{}",
                    "cards held in hand",
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
                    "Converts all scoring cards",
                    "in played hand to {C:clubs}Clubs{}",
                },
            },
            j_celesta_nostro = {
                name = "Nostro",
                text = {
                    "When a {C:attention}Gashed{} card breaks,",
                    "it loses all enhancements,",
                    "editions and seals",
                    "instead of disappearing",
                },
            },
            j_celesta_nyanners = {
                name = "Nyanners",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_obkatiekat = {
                name = "Obkatiekat",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_occi = {
                name = "Occi",
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
            j_celesta_piapiufo = {
                name = "Piapiufo",
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
                    "When a hand is played,",
                    "enhances the {C:attention}lowest rank{}",
                    "unenhanced card held in hand",
                    "to {C:attention}Eutrophic{}",
                },
            },
            j_celesta_pristinezero = {
                name = "Pristinezero",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_projektmelody = {
                name = "Projektmelody",
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
                name = "Radical Mari",
                text = {
                    "{C:spectral}Spectral{} cards prioritize",
                    "the leftmost available {C:attention}Joker{}",
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
                    "Retriggers {C:attention}Greedy{}, {C:attention}Wrathful{},",
                    "{C:attention}Lusty{} and {C:attention}Gluttonous{} Jokers",
                    "{C:attention}#1#{} additional time",
                },
            },
            j_celesta_rinpenrose = {
                name = "Rin Penrose",
                text = {
                    "This Joker gains {C:mult}+#1#{} Mult",
                    "for every {C:chips}#2#{} chips scored",
                    "{C:inactive}(#3# chips remaining)",
                    "{C:inactive}(Currently {C:mult}+#4#{C:inactive} Mult)",
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
                    "After each {C:attention}Ante{}, this",
                    "Joker gains {X:mult,C:white}X#1#{} Mult",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            j_celesta_rubensargasm = {
                name = "Rubensargasm",
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
            j_celesta_saiiren = {
                name = "Saiiren",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_sansin = {
                name = "Sansin",
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
            j_celesta_shaoanvt = {
                name = "Shaoanvt",
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
            j_celesta_sigrid_bird = {
                name = "Sigrid Bird",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_sinder = {
                name = "Sinder",
                text = {
                    "{C:attention}Driftwood{} cards",
                    "never break",
                },
            },
            j_celesta_smittenseraph = {
                name = "Smittenseraph",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_smugalana = {
                name = "Smug Alana",
                text = {
                    "When a {C:blue}Frozen{} Joker melts,",
                    "removes a random {C:attention}sticker{}",
                    "from it",
                },
            },
            j_celesta_smuggiess = {
                name = "Smuggiess",
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
            j_celesta_sonneflower = {
                name = "Sonneflower",
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
                name = "Spongey",
                text = {
                    "This Joker gains {C:chips}+#1#{} Chips",
                    "every time a {C:attention}Joker{} triggers",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            j_celesta_squchan = {
                name = "Squchan",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_suto = {
                name = "Suto",
                text = {
                    "Converts all played cards",
                    "into {C:attention}Wild Cards{}",
                },
            },
            j_celesta_taehoongie = {
                name = "Taehoongie",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_trickywi = {
                name = "Trickywi",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_unnamed = {
                name = "Unnamed",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_uzuri = {
                name = "Uzuri",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_vantacrow_bringer = {
                name = "Vantacrow Bringer",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_vedal = {
                name = "Vedal",
                text = {
                    "Multiplies every value other",
                    "{C:attention}Jokers from this mod{} give",
                    "by {X:mult,C:white}X#1#{}",
                    "{C:inactive}(Cannot be copied)",
                },
            },
            j_celesta_vexoria = {
                name = "Vexoria",
                text = {
                    "Converts all scoring cards",
                    "in played hand to {C:spades}Spades{}",
                },
            },
            j_celesta_vienna = {
                name = "Vienna",
                text = {
                    "{C:mult}+#1#{} Mult",
                },
            },
            j_celesta_vulpixie = {
                name = "Vulpixie",
                text = {
                    "{C:blue}Frozen{} Jokers never",
                    "fail to trigger",
                },
            },
            j_celesta_x3dustco = {
                name = "x3Dustco",
                text = {
                    "At the end of the shop,",
                    "creates a random {C:attention}Joker{} from this mod",
                    "{C:inactive}#1#% Common, #2#% Uncommon,",
                    "{C:inactive}#3#% Rare, #4#% Legendary",
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
                    "{C:attention}Limestone{} cards held in hand",
                    "have a {C:green}#1# in #2#{} chance to give",
                    "{C:money}$#3#{} when a hand is played",
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

        Spectral = {
            c_celesta_bind = {
                name = "Bind",
                text = {
                    "Merge {C:attention}2{} selected {C:attention}Jokers{}",
                    "into one Joker with",
                    "the abilities of both",
                },
            },
            c_celesta_milk_bottle = {
                name = "Milk Bottle",
                text = {
                    "Give up to {C:attention}#2#{} selected",
                    "cards a permanent",
                    "{C:chips}+#1#{} Chip bonus",
                },
            },
        },

        Blind = {
            bl_celesta_clover = {
                name = "The Clover",
                text = {
                    "Cards and Jokers have a",
                    "{C:green}#1# in #2#{} chance to trigger",
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
            m_celesta_eutrophic = {
                name = "Eutrophic Card",
                text = {
                    "Copies the {C:chips}Chips{}, {C:mult}Mult{}",
                    "and abilities of the",
                    "{C:attention}leftmost{} card in the hand",
                },
            },
            m_celesta_limestone = {
                name = "Limestone Card",
                text = {
                    "{C:mult}+#1#{} Mult",
                    "{C:inactive}no rank or suit",
                },
            },
            m_celesta_driftwood = {
                name = "Driftwood Card",
                text = {
                    "Counts as {C:attention}any rank{}",
                    "{C:green}#1# in #2#{} chance to break",
                    "if held in hand at",
                    "the end of the round",
                },
            },
            m_celesta_gash = {
                name = "Gash Card",
                text = {
                    "{X:chips,C:white}X#1#{} Chips",
                    "{C:green}#2# in #3#{} chance this",
                    "card is destroyed",
                },
            },
        },

        Other = {
            celesta_bind_arar_arar = {
                name = "Arar + Arar",
                text = {
                    "{X:mult,C:white}X#1#{} Mult when exactly",
                    "{C:attention}#2#{} hands remain",
                },
            },
            celesta_bind_arar_jaws = {
                name = "Arar + Jaws",
                text = {
                    "Adds a random {C:attention}enhancement{} to",
                    "non-scoring unenhanced cards",
                    "in played hand",
                },
            },
            celesta_bind_bear_moo = {
                name = "Bear The Witch + Moo Merrily",
                text = {
                    "Each {C:spectral}Milk Bottle{} held gives",
                    "{X:mult,C:white}X#1#{} Mult",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_blueprint_brainstorm = {
                name = "Blueprint + Brainstorm",
                text = {
                    "Retriggers each other",
                    "{C:attention}Joker{} #1# time",
                },
            },
            celesta_bind_crelly_koko = {
                name = "Crelly + KokoNuts",
                text = {
                    "Destroys scoring {C:attention}Lucky 7s of Spades{},",
                    "gaining {X:mult,C:white}X#1#{} Mult per card destroyed",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_jax_bricky = {
                name = "Jax + Bricky",
                text = {
                    "This Joker gains {C:chips}+#1#{} Chips",
                    "for each {C:attention}Stone{} or {C:attention}Limestone{}",
                    "card scored",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_kumi_maya = {
                name = "Kumi + Maya",
                text = {
                    "Destroys all scoring {C:attention}Steel Cards{}",
                    "in played hand, with a {C:green}#1# in #2#{} chance",
                    "to earn {C:money}$#3#{} per card destroyed",
                },
            },
            celesta_bind_nagzz_chibidoki = {
                name = "Nagzz + Chibidoki",
                text = {
                    "Retriggers {C:attention}Lucky Cards{}",
                    "{C:attention}#1#{} additional time",
                },
            },
            celesta_bind_deme_camila = {
                name = "Deme + Camila",
                text = {
                    "If first hand is a single card, gains",
                    "{X:mult,C:white}X0.25{} Mult, or {X:mult,C:white}X0.5{} if {C:dark_edition}Foil{},",
                    "{X:mult,C:white}X0.75{} if {C:dark_edition}Holographic{}, {X:mult,C:white}X1{} if {C:dark_edition}Polychrome{}",
                    "{C:inactive}(Currently {X:mult,C:white}X#1#{C:inactive} Mult)",
                },
            },
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
            m_celesta_eutrophic = "Eutrophic Card",
            m_celesta_limestone = "Limestone Card",
            m_celesta_driftwood = "Driftwood Card",
            m_celesta_gash = "Gash Card",
            celesta_tattered = "Tattered",
            celesta_cracked = "Cracked",
            celesta_chipped = "Chipped",
            celesta_ectoplast_seal = "Ectoplast Seal",
            celesta_foppy_seal = "Foppy Seal",
            celesta_rose_seal = "Rose Seal",
            celesta_star_seal = "Star Seal",
        },
        dictionary = {
            celesta_cfg_animation = "Arena weather animation (off = tint only)",
            celesta_cfg_verbose = "Verbose logging",
            celesta_cfg_downpour = "Force Downpour (debug)",
            -- Floating message text. Vanilla has no generic "+card" key
            -- (k_plus_stone is Marble Joker's own), so this mod supplies one.
            celesta_upgraded = "Upgraded!",
            celesta_gashed = "Gashed!",
            celesta_broke = "Broke!",
            celesta_tattered = "Tattered!",
            celesta_repaired = "Repaired!",
            celesta_taken = "Taken!",
            celesta_returned = "Returned!",
            celesta_cracked = "Cracked!",
            celesta_chipped = "Chipped!",
            celesta_stripped = "Stripped!",
            celesta_melted = "Melted!",
            celesta_snowstorm = "Snowstorm!",
            celesta_frozen = "Frozen!",
            celesta_failed = "Failed!",
            celesta_cleared = "Cleared!",
            celesta_plus_limestone = "+Limestone",
            celesta_plus_hand_size = "+1 Hand Size",
            celesta_plus_slot = "+1 Consumable Slot",
            celesta_plus_tag = "+1 Tag",
            celesta_sealed = "Sealed!",
            celesta_hearts = "All Hearts!",
            celesta_spades = "All Spades!",
            celesta_diamonds = "All Diamonds!",
            celesta_clubs = "All Clubs!",
            celesta_plus_seven = "+7 of Spades",
            celesta_downpour = "Downpour!",
        },
    },
}
