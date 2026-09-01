"""Regenerate jokers/atlases.lua, jokers/vtubers.lua and localization/en-us.lua
from whatever PNGs sit in assets/1x/.

Run from the mod root:   python tools/gen_roster.py

One image == one atlas == one Joker, matching the Legends mod's convention.
Hand-edit DISPLAY_NAMES below when the auto-capitalisation gets a name wrong.

Real work is never clobbered:
  * Jokers defined in jokers/implemented.lua are left out of the generated
    roster, so they are not registered twice.
  * Existing localization entries are preserved verbatim; only missing ones
    are appended as placeholders.
So this stays safe to re-run at any point in the mod's life.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = {"jokers", "consumables", "decks", "icon", "seals", "driftwood_fronts",
          "frozen", "frozen_round",
          # wear overlays, drawn on top of a playing card
          "tatter", "lucky_card_tatter", "limestone_tatter",
          "bind", "milk_bottle",
          # the added suits: a 13-cell rank row and a UI pip each
          "suit_stars", "suit_stars_ui",
          "suit_leaf", "suit_leaf_ui",
          # the consumables that make them, and the rest of the standalones
          "star_fury", "tree", "raise",
          # the three Tarots that hand out this mod's enhancements
          "citrus", "miracle_matter", "knife",
          # eighteen cells in a row, not a card. blank_joker itself is an
          # ordinary Joker face and stays in the roster.
          "blank_joker_layers"}   # not per-joker art

# Auto title-casing cannot know how a creator styles their own name.
# Add corrections here; anything absent falls back to the mechanical rule.
DISPLAY_NAMES = {
    "auteru": "Auteru",
    "juniperactias": "Juniper Actias",
    "obkatiekat": "ObKatieKat",
    "nekrolina": "Nekrolina",
    "nyanners": "Nyanners",
    "rainhoe": "Rainhoe",
    "trickywi": "Trickywi",
    "shaoanvt": "Grandpaw Shao",
    "yoclesh": "Yoclesh",
    "saiiren": "Saiiren",
    "blank_joker": "Blank Joker",
    "boosfer": "Boosfer",
    "ben": "Ben",
    "rynxryn": "RYNxRYN",
    "smittenseraph": "SmittenSeraph",
    "kourra": "Kourra",
    "shiabun": "Shiabun",
    "pipi": "Pipi",
    "buffpup": "BuffPup",
    "maplechicken": "MapleChicken",
    "fufu": "Fufu",
    "isaa": "Isaa",
    "occi": "Occi",
    "matarakan": "Matarakan",
    "projektmelody": "Projekt Melody",
    "pristinezero": "Pristine Zero",
    "minikomew": "Minikomew",
    "rubensargasm": "Ruben Sargasm",
    "yokasiri": "Yoka Siri",
    "radiaactive": "Radiaactive",
    "augustanomoly": "August Anomoly",
    "glowypumpkin": "Glowy Pumpkin",
    "fenari": "Fenari",
    "geega": "Geega",
    "unnamed": "Unnamed",
    "cosmic": "Cosmic",
    "vienna": "Vienna",
    "piapiufo": "PiapiUFO",
    "mooni": "Mooni",
    "ariesakana": "Aries Akana",
    "sonneflower": "SonneFlower",
    "taehoongie": "Taehoongie",
    "shenpai": "Shenpai",
    "sigrid_bird": "Sigrid & Bird",
    "nana_ruru": "Nana & Ruru",
    "henya": "Henya",
    "el_xox": "El_Xox",
    "fream": "Fream",
    "kirana": "Kirana",
    "kael": "Kael",
    "mariyume": "Mari Yume",
    "kairyucrocodile": "Kairyu",
    "sinder": "Sinder",
    "eros": "Eros",
    "ebiko": "Ebiko",
    "vexoria": "Vexoria",
    "nihmune": "Nihmune",
    "spongeybuns": "Spongey",
    "moomerrily": "Moo Merrily",
    "clover": "Moo Moo Clover",
    "radicalmari": "Radical Mari",
    "rinpenrose": "Rin Penrose",
    "harukakaribu": "Haruka Karibu",
    "axialmatt": "AxialMatt",
    "mintfantome": "Mint Fantome",
    "aicandii": "AiCandii",
    "amalee": "AmaLee",
    "bearthewitch": "Bear The Witch",
    "beribug": "BeriBug",
    "berrycrepe": "BerryCrepe",
    "demenishki": "Deme",
    "cerbervt": "CerberVT",
    "cottontail": "CottontailVA",
    "cweamcat": "CweamCat",
    "cyyuvtuber": "Cy Yu",
    "el_xox": "El_XoX",
    "froggyloch": "FroggyLoch",
    "hannahhyrule": "Hannah Hyrule",
    "heavenlyfather": "HeavenlyFather",
    "huntressspectre": "HuntressSpectre",
    "ironmouse": "Ironmouse",
    "itsdeadlyboop": "ItsDeadlyBoop",
    "jaxvtuber": "Jax",
    "jowol": "Jowol",
    "kokonuts": "KokoNuts",
    "limealicious": "Limealicious",
    "laynalazar": "LaynaLazar",
    "monikacinnyroll": "MonikaCinnyroll",
    "onigiri": "OniGiri",
    "pandabearlily": "PandaBearLily",
    "papamutt": "Papa Mutt",
    "overezeggs": "OverEzEggs",
    "motherv3": "MOTHERv3",
    "rtgame": "RTGame",
    "shylily": "ShyLily",
    "smugalana": "Smug Alana",
    "x3dustco": "x3Dustco",
    "yomiquinnely": "Yomi Quinnely",
    "yuy_ix": "Yuy_ix",
}


def display_name(stem):
    if stem in DISPLAY_NAMES:
        return DISPLAY_NAMES[stem]
    return " ".join(w.capitalize() for w in stem.split("_"))


def collect():
    """Joker art only: the shared placeholder sheets and anything prefixed
    fx_ (arena effect sprite sheets, see tools/gen_fx.py) are not jokers."""
    d = os.path.join(ROOT, "assets", "1x")
    stems = sorted(os.path.splitext(f)[0] for f in os.listdir(d)
                   if f.lower().endswith(".png")
                   and not f.lower().startswith(("fx_", "enh_", "blind_")))
    missing = [s for s in stems
               if not os.path.exists(os.path.join(ROOT, "assets", "2x", s + ".png"))]
    if missing:
        sys.exit("No 2x art for: " + ", ".join(missing))
    return [s for s in stems if s not in SHARED]


def implemented_keys():
    """Keys defined by hand anywhere in jokers/, vtubers.lua aside.

    Every .lua in the folder is read rather than implemented.lua alone: a Joker
    that carries enough machinery to want its own file - the Blank Joker does -
    is still a hand-written one, and a roster that cannot see it would register
    it a second time as a placeholder AND drop its localization on the next
    regeneration.

    Two sources per file, unioned:
      * `SMODS.Joker {` followed by `key = "..."` - which is why those files
        keep `key` as the first field of every literal definition.
      * `--- IMPLEMENTED: a, b, c` comment lines, for jokers registered from a
        loop where the key is a variable and cannot be read statically.

    Missing a key here is not silent: it stays in the generated roster and
    registers a second time, which the load test catches as a duplicate.
    """
    keys = set()
    d = os.path.join(ROOT, "jokers")
    if not os.path.isdir(d):
        return keys
    for name in sorted(os.listdir(d)):
        if not name.endswith(".lua") or name == "vtubers.lua":
            continue
        src = open(os.path.join(d, name), encoding="utf-8").read()
        keys.update(re.findall(
            r'SMODS\.Joker\s*\{\s*key\s*=\s*["\']([^"\']+)["\']', src))
        for line in re.findall(r'^---\s*IMPLEMENTED:\s*(.+)$', src, re.MULTILINE):
            keys.update(k.strip() for k in line.split(",") if k.strip())
    return keys


def existing_loc_blocks():
    """Every j_celesta_* entry already in localization/en-us.lua, verbatim.

    Relies on the 12-space indentation this script writes; a block runs from
    `            j_celesta_x = {` to the matching `            },`.
    """
    p = os.path.join(ROOT, "localization", "en-us.lua")
    if not os.path.exists(p):
        return {}
    lines = open(p, encoding="utf-8").read().splitlines(keepends=True)
    blocks, i = {}, 0
    start = re.compile(r'^            (j_celesta_\w+) = \{\s*$')
    while i < len(lines):
        m = start.match(lines[i])
        if not m:
            i += 1
            continue
        j = i + 1
        while j < len(lines) and lines[j].rstrip("\n") != "            },":
            j += 1
        if j < len(lines):
            blocks[m.group(1)] = "".join(lines[i:j + 1])
        i = j + 1
    return blocks


def write(relpath, text):
    p = os.path.join(ROOT, *relpath.split("/"))
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


BANNER = ("--- AUTO-GENERATED by tools/gen_roster.py - do not hand-edit.\n"
          "--- Add or remove art in assets/ and re-run the script instead.\n\n")

ATLAS_TMPL = ('SMODS.Atlas {\n'
              '    key = "%s",\n'
              '    path = "%s.png",\n'
              '    px = 71,\n'
              '    py = 95,\n'
              '}\n')

JOKER_LOOP = '''
for _, entry in ipairs(ROSTER) do
    SMODS.Joker {
        key = entry.key,
        atlas = entry.key,          -- one image, one atlas, single sprite
        pos = { x = 0, y = 0 },

        rarity = entry.rarity,
        cost = entry.cost,
        unlocked = true,
        discovered = true,
        blueprint_compat = true,
        eternal_compat = true,

        -- Placeholders are kept out of the shop and every booster pack until
        -- they have a real effect. SMODS.add_to_pool calls this, and
        -- get_current_pool gates the shop on it. They stay visible in the
        -- Collection. Move a joker to jokers/implemented.lua to let it spawn.
        in_pool = function(self, args) return false end,

        config = { extra = { mult = entry.mult } },

        loc_vars = function(self, info_queue, card)
            return { vars = { card.ability.extra.mult } }
        end,

        calculate = entry.calculate or function(self, card, context)
            if context.joker_main then
                return { mult = card.ability.extra.mult }
            end
        end,
    }
end
'''

LOC_HEAD = '''--- Player-facing text. Maintained by tools/gen_roster.py, which only ever
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
'''

# Used only when a key has no entry in en-us.lua yet (e.g. first run, or the
# file was deleted). Existing entries always win.
SEED_BLOCKS = {
    "j_celesta_spark": '''            j_celesta_spark = {
                name = "Spark",
                text = {
                    "{C:chips}+#1#{} Chips",
                },
            },
''',
    "j_celesta_ledger": '''            j_celesta_ledger = {
                name = "The Ledger",
                text = {
                    "This Joker gains {C:mult}+#1#{} Mult",
                    "per discarded card",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
''',
    "j_celesta_tollkeeper": '''            j_celesta_tollkeeper = {
                name = "Tollkeeper",
                text = {
                    "Played {C:diamonds}Diamond{} cards",
                    "give {X:mult,C:white}X#1#{} Mult when scored",
                    "Earn {C:money}$#2#{} at end of round",
                },
            },
''',
}

EXAMPLE_KEYS = ["j_celesta_spark", "j_celesta_ledger", "j_celesta_tollkeeper"]

LOC_TAIL = '''        },

        Tarot = {
            c_celesta_tree = {
                name = "Tree",
                text = {
                    "Converts up to",
                    "{C:attention}#1#{} selected cards",
                    "to {V:1}#2#{}",
                },
            },
            c_celesta_star_fury = {
                name = "Star Fury",
                text = {
                    "Converts up to",
                    "{C:attention}#1#{} selected cards",
                    "to {V:1}#2#{}",
                },
            },
            c_celesta_citrus = {
                name = "The Citrus",
                text = {
                    "Enhances up to {C:attention}#1#{}",
                    "selected card into a",
                    "{C:attention}Limestone Card",
                },
            },
            c_celesta_miracle_matter = {
                name = "The Miracle Matter",
                text = {
                    "Enhances up to {C:attention}#1#{}",
                    "selected card into an",
                    "{C:attention}Exo Card",
                },
            },
            c_celesta_knife = {
                name = "The Knife",
                text = {
                    "Enhances up to {C:attention}#1#{}",
                    "selected card into a",
                    "{C:attention}Gash Card",
                },
            },
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
            c_celesta_raise = {
                name = "Raise",
                text = {
                    "{C:attention}+#1#{} Ante,",
                    "{C:red}-#2#{} hand size",
                },
            },
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
            bl_celesta_greed = {
                name = "The Greed",
                text = {
                    "Hands and discards",
                    "cost {C:money}$#1#{} to use",
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
            celesta_bind_aries_yoka = {
                name = "Aries Akana + Yoka Siri",
                text = {
                    "This Joker gains {X:chips,C:white}X#1#{} Chips if the",
                    "played hand contains a {C:attention}Flush{}",
                    "of {V:1}#3#{} cards",
                    "{C:inactive}(Currently {X:chips,C:white}X#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_zentreya_zentreya = {
                name = "Zentreya + Zentreya",
                text = {
                    "{C:attention}Steel Cards{} in the played hand",
                    "and held in hand give",
                    "{X:mult,C:white}X#1#{} Mult when scored",
                },
            },
            celesta_bind_x3dustco_any = {
                name = "x3Dustco + Anything",
                text = {
                    "At the end of the shop, creates",
                    "a {C:dark_edition}Negative{} copy of the",
                    "{C:attention}other{} merged Joker",
                },
            },
            celesta_bind_arar_arielle = {
                name = "Arar + Arielle",
                text = {
                    "At the start of each round, adds a random",
                    "{C:attention}enhancement{} to every unenhanced",
                    "card held in hand",
                },
            },
            celesta_bind_camila_neuro = {
                name = "Camila + Neuro",
                text = {
                    "Destroys the {C:attention}first hand{} played each round",
                    "and returns every card next round with",
                    "its {C:dark_edition}edition{} upgraded one step",
                },
            },
            celesta_bind_camila_vedal = {
                name = "Camila + Vedal",
                text = {
                    "Destroys the {C:attention}first hand{} played each round",
                    "if it is a single card, and returns it next",
                    "round as {C:dark_edition}Polychrome{}",
                },
            },
            celesta_bind_cottontail_crelly = {
                name = "CottontailVA + Crelly",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult for each",
                    "{C:attention}Star Seal{} card in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_crelly_vedal = {
                name = "Crelly + Vedal",
                text = {
                    "At the end of the shop, consumes a random",
                    "held {C:attention}consumable{} and gains {X:mult,C:white}X#1#{} Mult",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_froggy_papa = {
                name = "FroggyLoch + PapaMutt",
                text = {
                    "Creates a random {C:tarot}Tarot{} card if the played",
                    "hand contains a {C:attention}#1#{}, with a {C:green}#2# in #3#{}",
                    "chance to create a second",
                    "{C:inactive}(Must have room)",
                },
            },
            celesta_bind_heavenly_boom = {
                name = "HeavenlyFather + Baddaboom",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult for each",
                    "{C:attention}Booster Pack{} skipped",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_mari_papa = {
                name = "Radical Mari + PapaMutt",
                text = {
                    "Creates a random {C:attention}consumable{} if the",
                    "played hand contains a {C:attention}#1#{}",
                    "{C:inactive}(Must have room)",
                },
            },
            celesta_bind_rose_buff = {
                name = "Rosedoodle + BuffPup",
                text = {
                    "Played {V:1}#4#{} cards have a {C:green}#1# in #2#{}",
                    "chance to give {X:mult,C:white}X#3#{} Mult",
                    "when scored",
                },
            },
            celesta_bind_arar_heavenly = {
                name = "Arar + HeavenlyFather",
                text = {
                    "At the start of each round, adds a",
                    "random {C:attention}enhancement{} to a random",
                    "unenhanced card held in hand, then adds",
                    "a copy of that card to your deck",
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
            celesta_bind_cottontail_deme = {
                name = "CottontailVA + Deme",
                text = {
                    "Played cards with a {C:attention}Star Seal{}",
                    "give this Joker {X:mult,C:white}X#1#{} Mult",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
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
            celesta_bind_koko_kumi = {
                name = "KokoNuts + Kumi",
                text = {
                    "Destroys scoring {C:attention}7s of Spades{},",
                    "{C:green}#1# in #2#{} chance to earn {C:money}$#3#{} each",
                    "and {C:green}#4# in #5#{} chance to earn {C:money}$#6#{} each",
                },
            },
            celesta_bind_lime_ray = {
                name = "Limealicious + Ray",
                text = {
                    "Retriggers {C:attention}Bloodstone{}, {C:attention}Rough Gem{},",
                    "{C:attention}Onyx Agate{}, {C:attention}Arrowhead{}, {C:attention}Vienna{}",
                    "and {C:attention}MapleChicken{} #1# additional time",
                },
            },
            celesta_bind_kumi_heavenly = {
                name = "Kumi + HeavenlyFather",
                text = {
                    "Destroys all scoring {C:attention}Gold Cards{}, with a",
                    "{C:green}#1# in #2#{} chance to earn {C:money}$#3#{} per card destroyed",
                    "{C:attention}+#4#{} booster pack slots",
                    "Booster packs cost {C:attention}half{} as much",
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
            celesta_bind_maya_ben = {
                name = "Maya + Ben",
                text = {
                    "{C:attention}+#1#{} hand size",
                    "Retriggers each {C:attention}Steel Card{}",
                    "held in hand {C:attention}#2#{} times",
                },
            },
            celesta_bind_nagzz_chibidoki = {
                name = "Nagzz + Chibidoki",
                text = {
                    "Retriggers {C:attention}Lucky Cards{}",
                    "{C:attention}#1#{} additional time",
                },
            },
            celesta_bind_neuro_vedal = {
                name = "Neuro + Vedal",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult",
                    "for each card destroyed",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
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
            celesta_bind_deme_boosfer = {
                name = "Deme + Boosfer",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult per consecutive",
                    "hand played with exactly {C:attention}1{} card, and",
                    "retriggers that card {C:attention}#2#{} additional times",
                    "{C:inactive}(Currently {X:mult,C:white}X#3#{C:inactive} Mult)",
                },
            },
            celesta_bind_zentreya_boosfer = {
                name = "Zentreya + Boosfer",
                text = {
                    "{V:1}#3#{} suit {C:attention}Steel Cards{} in the played hand",
                    "give {X:mult,C:white}X#1#{} Mult when scored, and are",
                    "retriggered {C:attention}#2#{} additional time",
                },
            },
            celesta_bind_koko_maya = {
                name = "KokoNuts + Maya",
                text = {
                    "At the start of each round, adds a",
                    "{C:attention}Lucky 7 of Spades{} to your deck, with a",
                    "{C:green}#1# in #2#{} chance to add {C:attention}#3#{} more",
                },
            },
            celesta_bind_heavenly_nostro = {
                name = "HeavenlyFather + Nostro",
                text = {
                    "{C:attention}+#1#{} Booster Pack slots and",
                    "{C:attention}+#2#{} Voucher slot",
                    "available in the shop",
                },
            },
            celesta_bind_kumi_deja = {
                name = "Kumi + Dejavudea",
                text = {
                    "Worn-out cards become",
                    "{C:money}Gold Cards{} instead",
                    "of {C:attention}Tattered{}",
                },
            },
            celesta_bind_arar_deja = {
                name = "Arar + Dejavudea",
                text = {
                    "At the start of each round, adds a random",
                    "{C:dark_edition}edition{} to a random card held in",
                    "hand that has none",
                },
            },
            celesta_bind_zentreya_ruben = {
                name = "Zentreya + Ruben Sargasm",
                text = {
                    "At the end of each round, earn money",
                    "equal to the total {C:attention}sell value{} of",
                    "every Joker you own",
                    "{C:inactive}(Currently {C:money}+$#1#{C:inactive})",
                },
            },
            celesta_bind_boosfer_boosfer = {
                name = "Boosfer + Boosfer",
                text = {
                    "Each scored {C:attention}Ace{} of {V:1}#3#{} has a",
                    "{C:green}#1# in #2#{} chance to create",
                    "{C:spectral}The Soul{}",
                    "{C:inactive}(Must have room)",
                },
            },
            celesta_bind_camila_koko = {
                name = "Camila + KokoNuts",
                text = {
                    "If every scoring card is a {C:spades}Spade{} and",
                    "they total {C:attention}#1#{}, they become {C:attention}Lucky{}",
                    "and {C:dark_edition}Polychrome{}",
                },
            },
            celesta_bind_sonne_birdy = {
                name = "SonneFlower + Birdyovo",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult per",
                    "consecutively scored {V:1}#3#{} card",
                    "{C:inactive}Resets if a hand scores none",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_arielle_ironmouse = {
                name = "Arielle + Ironmouse",
                text = {
                    "This Joker gains {X:mult,C:white}^#1#{} Mult",
                    "each time a card is scored",
                    "{C:inactive}(Currently {X:mult,C:white}^#2#{C:inactive} Mult)",
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
            b_celesta_ecstasy = {
                name = "Ecstasy Deck",
                text = {
                    "Only {C:attention}Celesta's Mod{} Jokers appear",
                    "Start with a {C:spectral}Bind{}",
                    "{C:green}1 in #1#{} chance for a {C:spectral}Bind{} and",
                    "{C:green}1 in #2#{} for {C:spectral}The Soul{} in the shop",
                },
            },
            b_celesta_hell = {
                name = "Hell Deck",
                text = {
                    "{C:attention}#1#{} hand, {C:attention}#2#{} discards",
                    "{C:red}-#3#{} hand size, {C:red}-#4#{} Joker slot",
                    "{C:red}-#5#{} consumable slot",
                    "Earn no {C:attention}interest{}",
                },
            },
            b_celesta_plaid = {
                name = "Plaid Deck",
                text = {
                    "Start with a full set of",
                    "all {C:attention}#1#{} suits",
                    "{C:attention}+#3#{} hand size",
                    "{C:inactive}(#2# cards)",
                },
            },
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
            celesta_gilded = "Gold!",
            celesta_blank_nothing = "nothing yet",
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
            celesta_unmerged = "Unmerged!",
            celesta_raised = "Raised!",
            celesta_sealed = "Sealed!",
            celesta_hearts = "All Hearts!",
            celesta_spades = "All Spades!",
            celesta_diamonds = "All Diamonds!",
            celesta_clubs = "All Clubs!",
            celesta_plus_seven = "+7 of Spades",
            celesta_downpour = "Downpour!",
            -- The Special Merges collection tab.
            celesta_special_merges = "Special Merges",
            celesta_merge_unknown = "Merge these two to find out",
            celesta_any_joker = "Any",
            celesta_aces = "All Aces of Spades!",
            celesta_stored = "Stored!",
            celesta_plus_consumable = "+Consumable",
        },
    },
}
'''


def main():
    stems = collect()
    done = implemented_keys()
    placeholders = [s for s in stems if s not in done]

    # Atlases cover every image, implemented or not.
    write("jokers/atlases.lua",
          BANNER + "\n".join(ATLAS_TMPL % (s, s) for s in stems))

    roster = "".join('    { key = "%s", rarity = 1, cost = 4, mult = 4 },\n' % s
                     for s in placeholders)
    write("jokers/vtubers.lua",
          BANNER
          + "--- Placeholder roster: every entry is a Common Joker with a stand-in\n"
            "--- +Mult effect, so all art is loadable and testable in-game.\n"
            "--- Jokers with real effects live in jokers/implemented.lua and are\n"
            "--- deliberately absent from this list.\n\n"
          + "local ROSTER = {\n" + roster + "}\n" + JOKER_LOOP)

    # Localization: keep everything that already exists, append what is missing.
    existing = existing_loc_blocks()
    kept = added = 0
    parts = []
    for key in EXAMPLE_KEYS + ["j_celesta_" + s for s in stems]:
        if key in existing:
            parts.append(existing[key])
            kept += 1
        elif key in SEED_BLOCKS:
            parts.append(SEED_BLOCKS[key])
            added += 1
        else:
            parts.append('            %s = {\n'
                         '                name = "%s",\n'
                         '                text = {\n'
                         '                    "{C:mult}+#1#{} Mult",\n'
                         '                },\n'
                         '            },\n'
                         % (key, display_name(key[len("j_celesta_"):])))
            added += 1
    write("localization/en-us.lua", LOC_HEAD + "".join(parts) + LOC_TAIL)

    print("%d images | %d implemented by hand | %d placeholder jokers"
          % (len(stems), len(done), len(placeholders)))
    print("localization: %d entries preserved, %d added" % (kept, added))
    if done:
        print("implemented:", ", ".join(sorted(done)))


if __name__ == "__main__":
    main()
