"""Regenerate jokers/atlases.lua, jokers/zz_vtubers.lua and localization/en-us.lua
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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import round_corners  # noqa: E402  (needs the path set above)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = {"jokers", "consumables", "decks", "sleeves", "icon", "seals", "driftwood_fronts",
          "frozen", "frozen_round",
          # wear overlays, drawn on top of a playing card
          "tatter", "lucky_card_tatter", "limestone_tatter",
          "bind", "swap", "milk_bottle", "burgundy_brew",
          # the added suits: a 13-cell rank row and a UI pip each
          "suit_stars", "suit_stars_ui",
          "suit_true_stars", "suit_true_stars_ui",
          "suit_leaf", "suit_leaf_ui",
          # the consumables that make them, and the rest of the standalones
          "star_fury", "tree", "raise", "unholy",
          # the Tarots that hand out this mod's enhancements, Occult, and Gene
          # (which hands out a seal rather than an enhancement)
          "citrus", "miracle_matter", "knife", "polish", "occult", "gene",
          # ...and The Community, which hands out Tags
          "community",
          # Cryogen's ring and Thanatos's landscape art: overlays drawn
          # over the card, not faces
          "cryogen_ring", "xm05_thanatos_wide",
          # The Lost Soul's sheet is two cells - a face and the wisp that
          # floats over it - and lost_glow is the white outline an eligible
          # Joker wears while one is held. Neither is a Joker face.
          "lost_soul", "lost_glow",
          # eighteen cells in a row, not a card. blank_joker itself is an
          # ordinary Joker face and stays in the roster.
          "blank_joker_layers",
          # The stamp sheets are two cells - the stamp over a blank
          # card, which is the card in a Stamp Pack, and the stamp
          # alone, which is the mark drawn on a Joker. The pack art
          # is 57x93 and not a card at all.
          "stamp_mult", "stamp_chips", "stamp_x_mult", "stamp_x_chips",
          "stamp_e_mult", "stamp_e_chips", "stamp_money",
          "stamp_retrigger", "stamp_pack",
}   # not per-joker art

# Auto title-casing cannot know how a creator styles their own name.
# Add corrections here; anything absent falls back to the mechanical rule.
DISPLAY_NAMES = {
    "auteru": "Auteru",
    "juniperactias": "Juniper Actias",
    "obkatiekat": "ObKatieKat",
    "obkhaoskat": "ObKhaosKat",
    "cdawg": "CDawg",
    "nicoviras": "Nico Viras",
    # the art is named for the creator; the card is not
    "lordaethelstan": "Aethal",
    "astrum_aureus": "Astrum Aureus",
    "blueberrypancake": "BlueberryPancake",
    "iron_moose": "Iron Moose",
    "red_boosfer": "Red Boosfer",
    "slimegod": "Slime God",
    # Lowercase on purpose. Balatro prints the localization string as written.
    "face": "face",
    # Punctuation and case on purpose, for the same reason. The KEY cannot
    # carry either, which is why the two differ so much here.
    "error_missing_chad": "ERROR:missing_chad.exe",
    "blessed_phoenix_egg": "Blessed Phoenix Egg",
    "cryogen": "Cryogen",
    "xm05_thanatos": "XM-05 Thanatos",
    "eidolonwyrm": "Eidolon Wyrm",
    "yharon": "Yharon, Dragon of Rebirth",
    "moopybuns": "MoopyBuns",
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
    "smittenseraph": "Smitten Seraph",
    "kourra": "Kourra",
    "shiabun": "Shiabun",
    "pipi": "Pipi",
    "buffpup": "Buffpup",
    "maplechicken": "Maple Chicken",
    "fufu": "Fufu",
    "isaa": "Isaa",
    "occi": "Occi",
    "angelsteps": "Angel Steps",
    "matarakan": "Matara Kan",
    "torioriane": "Tori Oriane",
    "projektmelody": "Projekt Melody",
    "pristinezero": "Pwistine",
    "mellowmabel": "Mellow Mabel",
    "minikomew": "Minikomew",
    "rubensargasm": "Ruben Sargasm",
    "vantacrow_bringer": "Vantacrow",
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
    "el_xox": "El XoX",
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
    "mintfantome": "Mint Fantôme",
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
    "el_xox": "El XoX",
    "froggyloch": "FroggyLoch",
    "hannahhyrule": "Hannah Hyrule",
    "heavenlyfather": "HeavenlyFather",
    "huntressspectre": "HuntressSpectre",
    "ironmouse": "Ironmouse",
    "itsdeadlyboop": "ItsDeadlyBoop",
    "jaxvtuber": "Jax",
    "jowol": "Jowol",
    "kokonuts": "KokoNuts",
    "limealicious": "Laimu",
    "laynalazar": "LaynaLazar",
    "lucypyre": "LucyPyre",
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
    "yuy_ix": "Yuy",
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
    """Keys defined by hand anywhere in jokers/, the placeholder roster aside.

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
        if not name.endswith(".lua") or name == "zz_vtubers.lua":
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
        discovered = false,
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

# Jokers with no art file of their own. The Joker section is built from what is
# in assets/, so one that borrows another sheet is invisible to that walk and
# gets no description at all unless it is named here.
#
# Anything listed here MUST NOT also have art: the two sources are concatenated
# and a key in both is written into the file twice.
ARTLESS_KEYS = [
    # The Blessed Phoenix Egg's second description, the one it reads once it
    # has finished counting. Not an object of its own - loc_vars swaps to it by
    # key - so nothing in assets/ points at it.
    "j_celesta_blessed_phoenix_egg_ready",
]

# The seven Jokers that say something extra while the deck holds a True Star.
#
# Each one needs a SECOND description - loc_vars points at the Joker's own key
# with "_true" on the end - and that description is the Joker's own text plus
# two lines. So it is DERIVED from whatever the base entry says rather than
# written out again: editing a Joker's description keeps the pair in step, and
# there is no second copy to forget about.
#
# The number is where the extra variables land. loc_vars appends them, so they
# carry on from however many the Joker already had.
TRUE_STAR_JOKERS = {
    "j_celesta_arar": 0,
    "j_celesta_camila": 0,
    "j_celesta_limealicious": 0,
    "j_celesta_trickywi": 1,
    "j_celesta_eros": 2,
    "j_celesta_shoomimi": 2,
}

# The Eidolon Wyrm's is the odd one: per card in the PLAYED HAND, so it has a
# flat rate and no running total, and it takes one variable rather than two.
TRUE_STAR_WYRM = "j_celesta_eidolonwyrm"

TRUE_STAR_DECK_LINES = (
    '                    "{C:celesta_true_star,E:1}X#%d# Mult{} for each'
    ' {C:celesta_true_star,E:1}True Star{}",\n'
    '                    "card in the full deck {C:inactive}(Currently'
    ' {X:mult,C:white}X#%d#{C:inactive} Mult)",\n'
)

TRUE_STAR_HAND_LINES = (
    '                    "{C:celesta_true_star,E:1}X#4#{} extra Mult for each",\n'
    '                    "{C:celesta_true_star,E:1}True Star{} card in the'
    ' played hand",\n'
)


def true_star_block(key, block):
    """The `_true` twin of one localization block, built from that block.

    The `unlock` section is deliberately dropped: an unlock condition is looked
    up by the Joker's own key, never by the one loc_vars points at, so a copy
    of it here would be a key nothing ever reads.
    """
    name = re.search(r"^ +name = .*$", block, re.M).group(0)
    open_at = block.index("                text = {\n")
    body_at = open_at + len("                text = {\n")
    close_at = block.index("\n                },", body_at)

    if key == TRUE_STAR_WYRM:
        extra = TRUE_STAR_HAND_LINES
    else:
        n = TRUE_STAR_JOKERS[key]
        extra = TRUE_STAR_DECK_LINES % (n + 1, n + 2)

    return ("            %s_true = {\n" % key
            + name + "\n"
            + "                text = {\n"
            + block[body_at:close_at + 1]
            + extra
            + "                },\n"
            + "            },\n")


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
            c_celesta_community = {
                name = "The Community",
                text = {
                    "Gives {C:attention}double{} of one of the",
                    "following Tags at random:",
                    "{C:attention}Standard{}, {C:attention}Charm{}, {C:attention}Meteor{},",
                    "{C:attention}Buffoon{}, {C:attention}Ethereal{}",
                },
            },
            c_celesta_gene = {
                name = "Gene",
                text = {
                    "Adds a {C:attention}Gene Seal{} to",
                    "up to {C:attention}#1#{} selected card",
                },
            },
            c_celesta_polish = {
                name = "Polish",
                text = {
                    "Converts up to {C:attention}#1#{} selected",
                    "{C:attention}Stone Card{} into {C:attention}Sandstone{},",
                    "or {C:attention}Limestone{} into {C:attention}Scoria",
                },
            },
            c_celesta_occult = {
                name = "Occult",
                text = {
                    "Creates the last",
                    "{C:spectral}Spectral{} card used",
                    "during this run",
                    "{C:inactive}(Must have room)",
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
            c_celesta_blessed_phoenix_egg = {
                name = "Blessed Phoenix Egg",
                text = {
                    "{C:attention}Pull{} into an empty",
                    "{C:attention}Joker{} slot, where it",
                    "hatches after {C:attention}#1#{} rounds",
                },
            },
            c_celesta_lost_soul = {
                name = "Lost Soul",
                text = {
                    "Turns the leftmost {C:attention}glowing{}",
                    "{C:attention}Joker{} into its lost version",
                },
            },
            c_celesta_unholy = {
                name = "Unholy Stone",
                text = {
                    "Every {C:attention}Sin{} may reach",
                    "level {C:attention}#1#{}, instead of",
                    "only one from each set",
                },
                unlock = {
                    "Win a run on {C:attention}White Stake{}",
                    "with the {C:attention}Deck of Sins{}",
                },
            },
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
            c_celesta_swap = {
                name = "Swap",
                text = {
                    "Swap the {C:attention}second{} Joker",
                    "between {C:attention}2{} selected",
                    "{C:attention}merged{} Jokers",
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
            c_celesta_burgundy_brew = {
                name = "Burgundy Brew",
                text = {
                    "Give up to {C:attention}#2#{} selected",
                    "cards a permanent",
                    "{C:mult}+#1#{} Mult bonus",
                },
            },
        },
        -- The stamps. Thirteen cards over eight drawings, one per line of
        -- the list they were asked from - which is why three of them are
        -- called Money Stamp and two Retrigger Stamp. The number each one
        -- shows is the one it rolled; in the Collection, where nothing has
        -- been rolled, it is the range it rolls in instead.
        celesta_Stamp = {
            c_celesta_stamp_mult = {
                name = "Mult Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {C:mult}+#1#{} Mult",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_chips = {
                name = "Chips Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {C:chips}+#1#{} Chips",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_money = {
                name = "Money Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {C:money}$#1#{}",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_x_mult = {
                name = "Mult Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {X:mult,C:white}X#1#{} Mult",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_x_chips = {
                name = "Chips Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {X:chips,C:white}X#1#{} Chips",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_x_mult_uncommon = {
                name = "Mult Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {X:mult,C:white}X#1#{} Mult",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_x_chips_uncommon = {
                name = "Chips Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {X:chips,C:white}X#1#{} Chips",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_money_uncommon = {
                name = "Money Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {C:money}$#1#{}",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_retrigger = {
                name = "Retrigger Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "Retrigger it {C:attention}#1#{} #2#",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_e_mult = {
                name = "Mult Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {E:1,C:mult}^#1#{} Mult",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_e_chips = {
                name = "Chips Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {E:1,C:chips}^#1#{} Chips",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_money_rare = {
                name = "Money Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "It gives {C:money}$#1#{}",
                    "every time it triggers",
                },
            },
            c_celesta_stamp_retrigger_rare = {
                name = "Retrigger Stamp",
                text = {
                    "Attach to a {C:attention}Joker{}",
                    "Retrigger it {C:attention}#1#{} #2#",
                    "every time it triggers",
                },
            },
        },

        Blind = {
            bl_celesta_horn = {
                name = "The Horn",
                text = {
                    "{C:attention}Jokers{} cannot be moved",
                    "and are locked in place",
                },
            },
            bl_celesta_gem = {
                name = "The Gem",
                text = {
                    "All cards and {C:attention}Jokers{} with",
                    "an {C:dark_edition}edition{} are debuffed",
                },
            },
            bl_celesta_flower = {
                name = "The Flower",
                text = {
                    "The {C:attention}leftmost{} and {C:attention}rightmost{}",
                    "Jokers are debuffed",
                },
            },
            bl_celesta_robot = {
                name = "The Robot",
                text = {
                    "All cards with a {C:attention}Seal{}",
                    "are debuffed",
                },
            },
            bl_celesta_brick = {
                name = "The Brick",
                text = {
                    "{C:attention}-1{} hand size for every",
                    "hand played this round",
                },
            },
            bl_celesta_wyrm = {
                name = "The Wyrm",
                text = {
                    "All {C:attention}consumable{} cards",
                    "are debuffed",
                },
            },
            bl_celesta_clover = {
                name = "The Clover",
                text = {
                    "Cards and Jokers have a",
                    "{C:green}#1# in #2#{} chance to trigger",
                },
            },
            bl_celesta_frog = {
                name = "The Frog",
                text = {
                    "Removes enhancements",
                    "from played cards",
                },
            },
            bl_celesta_goat = {
                name = "The Goat",
                text = {
                    "Shuffles editions and",
                    "enhancements of played cards",
                },
            },
            bl_celesta_heart = {
                name = "The Heart",
                text = {
                    "Scored Mult is halved",
                    "after scoring",
                },
            },
            bl_celesta_star = {
                name = "The Star",
                text = {
                    "Scored Chips are halved",
                    "after scoring",
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
            m_celesta_sandstone = {
                name = "Sandstone Card",
                text = {
                    "{C:green}#1# in #2#{} chance for {C:chips}+#3#{} Chips",
                    "{C:green}#4# in #5#{} chance for {X:chips,C:white}^#6#{} Chips",
                    "{C:inactive}no rank or suit",
                },
            },
            m_celesta_foliage = {
                name = "Foliage Card",
                text = {
                    "When scored, one of {X:chips,C:white}^#1#{} Chips,",
                    "{X:mult,C:white}^#1#{} Mult or {C:money}^#1#{} money",
                    "{C:green}#2# in #3#{} chance at end of round",
                    "to spread to a card beside it in hand",
                    "{C:inactive}no rank or suit",
                },
            },
            m_celesta_scoria = {
                name = "Scoria Card",
                text = {
                    "{C:green}#1# in #2#{} chance for {C:mult}+#3#{} Mult",
                    "{C:green}#4# in #5#{} chance for {X:mult,C:white}^#6#{} Mult",
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
            celesta_bind_arar_kumi = {
                name = "Arar + Kumi",
                text = {
                    "Destroys all scoring {C:attention}enhanced{}",
                    "cards in played hand",
                    "{C:green}#1# in #2#{} chance to earn",
                    "{C:money}$#3#{} per card destroyed",
                },
            },
            celesta_bind_beepers_heavenly = {
                name = "Beepers + HeavenlyFather",
                text = {
                    "{C:green}#1# in #2#{} chance to give a scored",
                    "{C:attention}King{} a {C:attention}Steel{} enhancement",
                    "and a {C:red}Red Seal{}",
                },
            },
            celesta_bind_kumi_berry = {
                name = "Kumi + BerryCrepe",
                text = {
                    "Scored {C:attention}Gold{} cards permanently",
                    "gain {C:mult}+#1#{} Mult",
                },
            },
            celesta_bind_arielle_saiiren = {
                name = "Arielle + Saiiren",
                text = {
                    "The {C:attention}last{} scoring card gives",
                    "{X:mult,C:white}X#1#{} Mult when scored",
                },
            },
            celesta_bind_heavenly_arielle = {
                name = "HeavenlyFather + Arielle",
                text = {
                    "{C:attention}+#1#{} Booster Pack slot for each",
                    "unique {C:attention}suit{} in your {C:attention}full deck{}",
                },
            },
            celesta_bind_aethal_nyanners = {
                name = "Aethal + Nyanners",
                text = {
                    "{C:chips}+#1#{} Chips for each {C:attention}Voucher{}",
                    "redeemed this run",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_moopy_berry = {
                name = "MoopyBuns + BerryCrepe",
                text = {
                    "This Joker gains {C:mult}+#1#{} Mult for each",
                    "item bought from the {C:attention}shop{}",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_moopy_koko = {
                name = "MoopyBuns + KokoNuts",
                text = {
                    "This Joker gains {X:chips,C:white}X#1#{} Chips for each",
                    "{C:attention}7{} in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {X:chips,C:white}X#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_nihmune_michi = {
                name = "Nihmune + Michi",
                text = {
                    "When a {C:clubs}Club{} card is discarded,",
                    "{C:green}#1# in #2#{} chance to create a",
                    "{C:tarot}Tarot{} card",
                    "{C:inactive}(Must have room)",
                },
            },
            celesta_bind_ray_glasses = {
                name = "Ray + Glassesjournal",
                text = {
                    "Cards you have {C:attention}played more often{}",
                    "are dealt first",
                    "{C:inactive}(Counted from when this Joker was made)",
                },
            },
            celesta_bind_kuro_arielle = {
                name = "Kuro + Arielle",
                text = {
                    "{C:attention}Boss Blinds{} are disabled",
                    "on {C:attention}even{} numbered Antes",
                },
            },
            celesta_bind_grimmi_heavenly = {
                name = "Grimmi + HeavenlyFather",
                text = {
                    "{C:attention}+#1#{} Voucher slots",
                    "available in the shop",
                    "Creates a {C:dark_edition}Negative{}",
                    "{C:attention}HeavenlyFather{} when sold",
                },
            },
            celesta_bind_grimmi_jowol = {
                name = "Grimmi + Jowol",
                text = {
                    "{C:chips}+#1#{} Chips for each {C:attention}Stone{}",
                    "card in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                    "Creates a {C:dark_edition}Negative{}",
                    "{C:attention}Jowol{} when sold",
                },
            },
            celesta_bind_grimmi_eggs = {
                name = "Grimmi + OverEzEggs",
                text = {
                    "{C:money}+$#1#{} sell value for each",
                    "{C:hearts}Heart{} card in your {C:attention}full deck{}",
                    "Creates a {C:dark_edition}Negative{}",
                    "{C:attention}OverEzEggs{} when sold",
                },
            },
            celesta_bind_cyyu_amalee = {
                name = "Cy Yu + AmaLee",
                text = {
                    "Retrigger each {C:attention}Exo{} card",
                    "{C:attention}#1#{} times during a {C:blue}Snowstorm{}",
                },
            },
            celesta_bind_cyyu_jowol = {
                name = "Cy Yu + Jowol",
                text = {
                    "Retrigger each {C:attention}Stone{}",
                    "card {C:attention}#1#{} times",
                },
            },
            celesta_bind_yoclesh_squchan = {
                name = "Yoclesh + Squchan",
                text = {
                    "Played {C:hearts}Heart{} cards with no edition",
                    "have a {C:green}#1# in #2#{} chance to",
                    "become {C:dark_edition}Holographic{}",
                },
            },
            celesta_bind_fenari_heavenly = {
                name = "Fenari + HeavenlyFather",
                text = {
                    "{C:attention}Jokers{} found in {C:attention}Booster Packs{}",
                    "cannot have stickers",
                },
            },
            celesta_bind_katie_froot = {
                name = "ObKatieKat + Froot",
                text = {
                    "This Joker gains {X:chips,C:white}^#1#{} Chips",
                    "for each {C:attention}Wild Card{} in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {X:chips,C:white}^#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_katie_saiiren = {
                name = "ObKatieKat + Saiiren",
                text = {
                    "The {C:attention}last{} scored {V:1}#2#{} card",
                    "gives {X:chips,C:white}^#1#{} Chips",
                    "{C:inactive}(suit changes each round)",
                },
            },
            celesta_bind_katie_zentreya = {
                name = "ObKatieKat + Zentreya",
                text = {
                    "{C:attention}Steel{} cards give {X:chips,C:white}^#1#{} Chips",
                    "when they trigger, instead of",
                    "their {X:mult,C:white}X1.5{} Mult",
                },
            },
            celesta_bind_katie_ironmouse = {
                name = "ObKatieKat + Ironmouse",
                text = {
                    "{X:chips,C:white}^#1#{} Chips",
                },
            },
            celesta_bind_katie_michi = {
                name = "ObKatieKat + Michi",
                text = {
                    "Scored {C:purple}Purple Seal{} cards",
                    "give {X:chips,C:white}^#1#{} Chips",
                },
            },
            celesta_bind_katie_kuro = {
                name = "ObKatieKat + Kuro",
                text = {
                    "During {C:attention}Boss Blinds{}, this Joker",
                    "gives {X:chips,C:white}^#1#{} Chips after the",
                    "hand finishes scoring",
                },
            },
            celesta_bind_katie_henya = {
                name = "ObKatieKat + Henya",
                text = {
                    "Scored cards give {X:chips,C:white}^#1#{} Chips",
                    "when {C:attention}retriggered{}",
                },
            },
            celesta_bind_katie_melody = {
                name = "ObKatieKat + Projekt Melody",
                text = {
                    "Earn {C:money}$#1#{} at end of round for",
                    "each filled {C:attention}Joker{} slot",
                    "{C:inactive}(Currently {C:money}$#2#{C:inactive})",
                },
            },
            celesta_bind_maple_seraph = {
                name = "Maple Chicken + Smitten Seraph",
                text = {
                    "Retrigger each played {V:1}#1#{} card",
                    "once for each filled {C:attention}Joker{} slot,",
                    "less each filled {C:attention}consumable{} slot",
                    "{C:inactive}(Currently {C:attention}#2#{C:inactive} times)",
                },
            },
            celesta_bind_birdyovo_seraph = {
                name = "Birdyovo + Smitten Seraph",
                text = {
                    "{C:attention}+#1#{} Joker slots, {C:attention}+#2#{} consumable slots",
                    "Every {C:attention}#3#{} scored cards",
                    "gives {X:mult,C:white}X#4#{} Mult",
                    "{C:inactive}(#5# remaining)",
                },
            },
            celesta_bind_mint_matara = {
                name = "Mint Fantôme + Matara Kan",
                text = {
                    "When the played hand finishes scoring,",
                    "earn {X:money,C:white}X#1#{} the {C:attention}rank{} of the",
                    "{C:attention}leftmost{} card held in hand",
                },
            },
            celesta_bind_mint_laimu = {
                name = "Mint Fantôme + Laimu",
                text = {
                    "When the played hand finishes",
                    "scoring, score each {C:attention}Limestone{}",
                    "card held in hand",
                },
            },
            celesta_bind_mint_doki = {
                name = "Mint Fantôme + Dokibird",
                text = {
                    "When the played hand finishes scoring,",
                    "score the {C:attention}leftmost{} card held in hand",
                    "for {X:chips,C:white}X#1#{} its stored {C:chips}Chips{}",
                },
            },
            celesta_bind_mint_snuffy = {
                name = "Mint Fantôme + Snuffy",
                text = {
                    "Select {C:attention}#1#{} more cards, equal to the",
                    "number of {C:blue}Hands{} remaining plus {C:attention}#2#{}",
                },
            },
            celesta_bind_laimu_doki = {
                name = "Laimu + Dokibird",
                text = {
                    "{C:attention}Scoria{} cards count as",
                    "{C:attention}Limestone{} cards, and {C:attention}Sandstone{}",
                    "cards count as {C:attention}Stone{} cards",
                },
            },
            celesta_bind_laimu_snuffy = {
                name = "Laimu + Snuffy",
                text = {
                    "{C:attention}Limestone{} cards ignore",
                    "the card selection limit",
                },
            },
            celesta_bind_doki_snuffy = {
                name = "Dokibird + Snuffy",
                text = {
                    "When a hand is played, destroy played",
                    "cards holding under {C:chips}#1#{} stored {C:chips}Chips{},",
                    "except the {C:attention}leftmost{}, and give that card",
                    "{C:attention}#2#X{} their {C:chips}Chips{} permanently",
                },
            },
            celesta_bind_mint_nimi = {
                name = "Mint Fantôme + Nimi",
                text = {
                    "When a hand is played, {C:attention}undebuffs{} the",
                    "{C:attention}leftmost{} card held in hand, and scores",
                    "it once the hand finishes scoring",
                },
            },
            celesta_bind_mint_dooby = {
                name = "Mint Fantôme + Dooby",
                text = {
                    "When the played hand finishes scoring,",
                    "score the {C:attention}leftmost{} card held in hand",
                    "once per shop you spent no {C:money}money{} in",
                    "{C:inactive}(Currently #1# triggers)",
                },
            },
            celesta_bind_dooby_doki = {
                name = "Dooby + Dokibird",
                text = {
                    "This Joker gains {C:chips}+#1#{} Chips after",
                    "a shop you spent no {C:money}money{} in",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_nimi_doki = {
                name = "Nimi + Dokibird",
                text = {
                    "Cards holding more than {C:chips}#1#{} stored",
                    "{C:chips}Chips{} cannot be {C:attention}debuffed{}",
                },
            },
            celesta_bind_dooby_nimi = {
                name = "Dooby + Nimi",
                text = {
                    "{C:attention}Stamps{} can be taken from packs",
                    "and held in your consumable slots",
                },
            },
            celesta_bind_quad_gay_women = {
                name = "G.A.Y. Women",
                text = {
                    "Whenever a card or Joker is {C:attention}debuffed{},",
                    "this Joker {C:attention}undebuffs{} it and gains",
                    "{C:chips}+#1#{} Chips",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_amalee_ironmouse = {
                name = "AmaLee + Ironmouse",
                text = {
                    "{X:mult,C:white}^#1#{} Mult during a {C:blue}Snowstorm{}",
                    "Starts a {C:blue}Snowstorm{} at the",
                    "start of each round",
                },
            },
            celesta_bind_amalee_doki = {
                name = "AmaLee + Dokibird",
                text = {
                    "During a {C:blue}Snowstorm{}, scored cards",
                    "permanently gain {C:chips}+#1#{} Chips",
                },
            },
            celesta_bind_amalee_rin = {
                name = "AmaLee + Rin Penrose",
                text = {
                    "This Joker gains {C:mult}+#1#{} Mult for every {C:chips}#3#{}",
                    "Chips scored, or {C:mult}+#2#{} during a {C:blue}Snowstorm{}",
                    "{C:inactive}(#4# Chips remaining)",
                    "{C:inactive}(Currently {C:mult}+#5#{C:inactive} Mult)",
                },
            },
            celesta_bind_ironmouse_doki = {
                name = "Ironmouse + Dokibird",
                text = {
                    "This Joker gains {C:chips}+#1#{} Chips",
                    "after each played hand",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_ironmouse_rin = {
                name = "Ironmouse + Rin Penrose",
                text = {
                    "This Joker gains {X:mult,C:white}^#1#{} Mult for",
                    "every {C:chips}#2#{} Chips scored",
                    "{C:inactive}(#3# Chips remaining)",
                    "{C:inactive}(Currently {X:mult,C:white}^#4#{C:inactive} Mult)",
                },
            },
            celesta_bind_doki_rin = {
                name = "Dokibird + Rin Penrose",
                text = {
                    "This Joker gains {C:chips}+#1#{} Chips for",
                    "every {C:mult}#2#{} Mult scored",
                    "{C:inactive}(#3# Mult remaining)",
                    "{C:inactive}(Currently {C:chips}+#4#{C:inactive} Chips)",
                },
            },
            celesta_bind_snuffy_nyanners = {
                name = "Snuffy + Nyanners",
                text = {
                    "{C:chips}+#1#{} Chips for each",
                    "card in played hand",
                },
            },
            celesta_bind_snuffy_ironmouse = {
                name = "Snuffy + Ironmouse",
                text = {
                    "{X:mult,C:white}^#1#{} Mult for each",
                    "card in played hand",
                },
            },
            celesta_bind_snuffy_silvervale = {
                name = "Snuffy + Silvervale",
                text = {
                    "{X:mult,C:white}X#1#{} Mult for each",
                    "card in played hand",
                },
            },
            celesta_bind_snuffy_melody = {
                name = "Snuffy + Projekt Melody",
                text = {
                    "Earn {C:money}$#1#{} at end of round for",
                    "each card played that round",
                    "{C:inactive}(Currently {C:money}$#2#{C:inactive})",
                },
            },
            celesta_bind_aquwa_deme = {
                name = "Aquwa + Deme",
                text = {
                    "At the start of the round,",
                    "starts a {C:blue}Downpour{}",
                    "If the played hand has {C:attention}#1#{} card,",
                    "retrigger it {C:attention}#2#{} times",
                },
            },
            celesta_bind_arielle_jaws = {
                name = "Arielle + Jaws",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult for each",
                    "unique {C:attention}suit{} in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_deme_saruei = {
                name = "Deme + Saruei",
                text = {
                    "A {C:attention}Glass{} or {C:attention}Gash{} card played",
                    "on its own can never break",
                },
            },
            celesta_bind_yuy_nekrolina = {
                name = "Yuy + Nekrolina",
                text = {
                    "This Joker gains {C:money}$#1#{} of",
                    "{C:attention}sell value{} every time a hand is played",
                    "{C:inactive}(Currently {C:money}+$#2#{C:inactive})",
                },
            },
            celesta_bind_heavenly_bluto = {
                name = "HeavenlyFather + Bluto",
                text = {
                    "{C:attention}Blueprint{} and {C:attention}Brainstorm{}",
                    "appear more often in the {C:attention}shop{}",
                },
            },
            celesta_bind_elxox_toma = {
                name = "El XoX + Toma",
                text = {
                    "{C:green}#1# in #2#{} chance to earn",
                    "{C:money}$#3#{} when a hand is played",
                },
            },
            celesta_bind_elxox_mariyume = {
                name = "El XoX + Mari Yume",
                text = {
                    "Retriggers the {C:attention}rightmost{} Joker",
                    "once for each {C:attention}hand{} remaining",
                    "{C:inactive}(Currently {C:attention}#1#{C:inactive} retriggers)",
                },
            },
            celesta_bind_elxox_melody = {
                name = "El XoX + Projekt Melody",
                text = {
                    "At the end of the round, permanently stores",
                    "{C:money}$#1#{} for each {C:attention}hand{} remaining,",
                    "then earns everything stored",
                    "{C:inactive}(Currently {C:money}$#2#{C:inactive})",
                },
            },
            celesta_bind_elxox_aquwa = {
                name = "El XoX + Aquwa",
                text = {
                    "At the end of the round, if a {C:blue}Downpour{}",
                    "happened that round, earn {C:money}$#1#{} for",
                    "each {C:attention}hand{} used that round",
                },
            },
            celesta_bind_elxox_kumi = {
                name = "El XoX + Kumi",
                text = {
                    "At the end of the round, earn money equal",
                    "to the {C:attention}hands{} used times {X:money,C:white}X#1#{} the",
                    "number of {C:attention}Gold{} cards held in hand",
                },
            },
            celesta_bind_elxox_crelly = {
                name = "El XoX + Crelly",
                text = {
                    "At the end of the shop, {C:attention}consumes{} {C:money}$#1#{}",
                    "to gain {X:mult,C:white}X#2#{} Mult",
                    "{C:inactive}(cannot go into debt)",
                    "{C:inactive}(Currently {X:mult,C:white}X#3#{C:inactive} Mult)",
                },
            },
            celesta_bind_elxox_cottontail = {
                name = "El XoX + CottontailVA",
                text = {
                    "Earn {C:money}$#1#{} every time a",
                    "{C:attention}Star Seal{} card copies a card",
                },
            },
            celesta_bind_elxox_jowol = {
                name = "El XoX + Jowol",
                text = {
                    "{C:attention}Stone{} cards give",
                    "{C:money}$#1#{} when triggered",
                },
            },
            celesta_bind_elxox_koko = {
                name = "El XoX + KokoNuts",
                text = {
                    "Scored {C:attention}7{}s give {C:money}$#1#{}",
                },
            },
            celesta_bind_elxox_spongey = {
                name = "El XoX + Spongey",
                text = {
                    "Earn {C:money}$#1#{} every time",
                    "another {C:attention}Joker{} triggers",
                },
            },
            celesta_bind_elxox_tobs = {
                name = "El XoX + Tobs",
                text = {
                    "Earn {C:money}$#1#{} every time a",
                    "{C:attention}Eutrophic{} card mimics a card",
                },
            },
            celesta_bind_elxox_vexoria = {
                name = "El XoX + Vexoria",
                text = {
                    "Scored {C:spades}Spade{} cards give {C:money}$#1#{}",
                },
            },
            celesta_bind_elxox_saiiren = {
                name = "El XoX + Saiiren",
                text = {
                    "The {C:attention}last{} scoring card gives money",
                    "equal to the {C:attention}hands{} remaining",
                    "{C:inactive}(Currently {C:money}$#1#{C:inactive})",
                },
            },
            celesta_bind_elxox_katie = {
                name = "El XoX + ObKatieKat",
                text = {
                    "This Joker gains {X:chips,C:white}^#1#{} Chips",
                    "every time a hand is played",
                    "{C:inactive}(Currently {X:chips,C:white}^#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_elxox_pipi = {
                name = "El XoX + Pipi",
                text = {
                    "Earn {C:money}$#1#{} every time",
                    "a {C:attention}Pair{} is played",
                },
            },
            celesta_bind_elxox_pomato = {
                name = "El XoX + Pomatomaster",
                text = {
                    "Earn {C:money}$#1#{} for each {C:attention}Eutrophic{}",
                    "card held in hand at end of round",
                },
            },
            celesta_bind_elxox_fufu = {
                name = "El XoX + Fufu",
                text = {
                    "Earn {C:money}$#1#{} at end of round for each",
                    "unique {C:attention}suit{} in your {C:attention}full deck{}",
                },
            },
            celesta_bind_elxox_august = {
                name = "El XoX + August Anomoly",
                text = {
                    "Earn {C:money}$#1#{} every time",
                    "a {C:blue}Blue Seal{} triggers",
                },
            },
            celesta_bind_elxox_piapiufo = {
                name = "El XoX + PiapiUFO",
                text = {
                    "Scored {V:1}#2#{} cards give {C:money}$#1#{}",
                },
            },
            celesta_bind_elxox_buffpup = {
                name = "El XoX + Buffpup",
                text = {
                    "Scored {V:1}#2#{} cards give {C:money}$#1#{}",
                },
            },
            celesta_bind_elxox_ebiko = {
                name = "El XoX + Ebiko",
                text = {
                    "Scored {C:diamonds}Diamond{} cards give {C:money}$#1#{}",
                },
            },
            celesta_bind_elxox_torioriane = {
                name = "El XoX + Tori Oriane",
                text = {
                    "Earn {C:money}$#1#{} at end of round for each",
                    "{C:celesta_true_star}True Star{} card in your {C:attention}full deck{}",
                },
            },
            celesta_bind_kairyu_rosedoodle = {
                name = "Kairyu + Rosedoodle",
                text = {
                    "Gain {C:attention}+#1#{} hand size for every",
                    "{C:attention}#2#{} {C:attention}Mult{} cards discarded this round",
                    "{C:inactive}(Currently {C:attention}+#3#{C:inactive} hand size)",
                },
            },
            celesta_bind_tobs_nihmune = {
                name = "Tobs + Nihmune",
                text = {
                    "Scoring {C:clubs}Club{} cards become",
                    "{C:attention}Eutrophic{} cards",
                },
            },
            celesta_bind_tobs_suko = {
                name = "Tobs + Suko",
                text = {
                    "Played {C:attention}Eutrophic{} cards",
                    "become {C:dark_edition}Foil{}",
                },
            },
            celesta_bind_tobs_toma = {
                name = "Tobs + Toma",
                text = {
                    "{C:celesta_true_star}True Star{} {C:attention}Eutrophic{} cards copy",
                    "{X:chips,C:white}X#1#{} the values of the card they copy",
                },
            },
            celesta_bind_eros_koko = {
                name = "Eros + KokoNuts",
                text = {
                    "At the start of each round, add a",
                    "{C:attention}Bonus{} {C:spades}7 of Spades{} to your deck",
                },
            },
            celesta_bind_eros_layna = {
                name = "Eros + LaynaLazar",
                text = {
                    "Destroys played {C:attention}face{} cards, and this Joker",
                    "gains {X:chips,C:white}X#1#{} their stored {C:chips}Chips{} each",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_eros_grimmi = {
                name = "Eros + Grimmi",
                text = {
                    "Removes {C:attention}Bonus{} enhancements from scoring",
                    "cards, and this Joker gains {C:chips}+#1#{} Chips each",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_ellie_cerber = {
                name = "Ellie Minibot + Cerber",
                text = {
                    "{C:attention}Glass{} and {C:attention}Gashed{} cards",
                    "cannot break",
                },
            },
            celesta_bind_ellie_neuro = {
                name = "Ellie Minibot + Neuro",
                text = {
                    "{C:attention}Lucky{} cards always",
                    "give their value",
                },
            },
            celesta_bind_ellie_vedal = {
                name = "Ellie Minibot + Vedal",
                text = {
                    "{C:attention}Vedal{} scales Jokers",
                    "{X:mult,C:white}X#1#{} as fast",
                },
            },
            celesta_bind_minikomew_cerber = {
                name = "MinikoMew + Cerber",
                text = {
                    "Retrigger the {C:attention}highest ranked{} played",
                    "card once for every {C:money}$#1#{} of {C:attention}debt{}",
                },
            },
            celesta_bind_froot_zentreya = {
                name = "Froot + Zentreya",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult for each",
                    "{C:attention}Steel Card{} in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_froot_melody = {
                name = "Froot + Projekt Melody",
                text = {
                    "Earn {C:money}$#1#{} at end of round for each",
                    "{C:attention}Wild Card{} in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {C:money}$#2#{C:inactive})",
                },
            },
            celesta_bind_froot_ironmouse = {
                name = "Froot + Ironmouse",
                text = {
                    "This Joker gains {X:mult,C:white}^#1#{} Mult per",
                    "{C:attention}Wild Card{} in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {X:mult,C:white}^#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_froot_nyanners = {
                name = "Froot + Nyanners",
                text = {
                    "This Joker gains {C:chips}+#1#{} Chips per",
                    "{C:attention}Wild Card{} in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_froot_silvervale = {
                name = "Froot + Silvervale",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult per",
                    "{C:attention}Wild Card{} in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_froot_momo = {
                name = "Froot + Momo",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult every time",
                    "a hand containing a {C:attention}Flush{} is played",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_froot_snuffy = {
                name = "Froot + Snuffy",
                text = {
                    "{C:attention}Wild Cards{} ignore the card",
                    "selection limit, up to {C:attention}#1#{} of them",
                },
            },
            celesta_bind_froot_fefe = {
                name = "Froot + FeFe",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult per",
                    "{C:hearts}Heart{} card in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_froot_hime = {
                name = "Froot + Hime",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult per",
                    "{C:attention}Eutrophic{} card in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_kuro_michi = {
                name = "Kuro + Michi",
                text = {
                    "Discarded {C:purple}Purple Seal{} cards",
                    "create a random {C:attention}consumable{}",
                    "{C:inactive}(Must have room)",
                },
            },
            celesta_bind_lucia_angel = {
                name = "Lucia + Angel Steps",
                text = {
                    "Base {C:chips}Chips{} and {C:mult}Mult{} are {C:attention}swapped{}",
                    "{X:mult,C:white}X#1#{} Mult after the hand",
                    "finishes scoring",
                },
            },
            celesta_bind_lucia_mari = {
                name = "Lucia + Mari Yume",
                text = {
                    "Retrigger each played card {C:attention}#1#{} times",
                    "if played hand contains {C:attention}1{} card,",
                    "{C:attention}1{} fewer for each extra card played",
                },
            },
            celesta_bind_lucia_elxox = {
                name = "Lucia + El XoX",
                text = {
                    "{X:mult,C:white}X#1#{} Mult, equal to the number",
                    "of {C:blue}Hands{} remaining",
                },
            },
            celesta_bind_lucia_meicha = {
                name = "Lucia + Meicha",
                text = {
                    "{X:mult,C:white}X#1#{} Mult if played",
                    "hand is a {C:attention}Straight{}",
                },
            },
            celesta_bind_lucia_zentreya = {
                name = "Lucia + Zentreya",
                text = {
                    "Each played {C:attention}Steel{} card",
                    "gives {X:mult,C:white}X#1#{} Mult",
                },
            },
            celesta_bind_lucia_sinder = {
                name = "Lucia + Sinder",
                text = {
                    "Each played {C:attention}Driftwood{} card",
                    "gives {X:mult,C:white}X#1#{} Mult",
                },
            },
            celesta_bind_lucia_jowol = {
                name = "Lucia + Jowol",
                text = {
                    "Each played {C:attention}Stone{} card",
                    "gives {X:mult,C:white}X#1#{} Mult",
                },
            },
            celesta_bind_birdyovo_kourra = {
                name = "Birdyovo + Kourra",
                text = {
                    "{X:mult,C:white}X#1#{} Mult for every",
                    "{C:chips}#2#{} Chips scored so far",
                },
            },
            celesta_bind_sonne_kourra = {
                name = "SonneFlower + Kourra",
                text = {
                    "{C:mult}+#1#{} Mult for every {V:1}#2#{}",
                    "card scored so far",
                },
            },
            celesta_bind_buffpup_shiabun = {
                name = "Buffpup + Shiabun",
                text = {
                    "{C:attention}+1{} card selection limit for",
                    "every {C:attention}#1#{} {V:1}#2#{} cards",
                    "in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {C:attention}#3#{C:inactive} cards)",
                },
            },
            celesta_bind_arielle_shiabun = {
                name = "Arielle + Shiabun",
                text = {
                    "{C:attention}+1{} card selection limit for every",
                    "{C:attention}#1#{} unique suits in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {C:attention}#2#{C:inactive} suits)",
                },
            },
            celesta_bind_arar_occi = {
                name = "Arar + Occi",
                text = {
                    "At the start of each round, converts",
                    "a random card held in hand to",
                    "the {C:attention}Ace{} of {C:spades}Spades{}",
                },
            },
            celesta_bind_arielle_shao = {
                name = "Arielle + Grandpaw Shao",
                text = {
                    "All cards are considered",
                    "{C:attention}Aces{} of the same {C:attention}suit{}",
                },
            },
            celesta_bind_fufu_katie = {
                name = "Fufu + ObKatieKat",
                text = {
                    "This Joker gains {X:chips,C:white}^#1#{} Chips",
                    "per unique {C:attention}suit{} in full deck",
                    "{C:inactive}(Currently {X:chips,C:white}^#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_ironmouse_michi = {
                name = "Ironmouse + Michi",
                text = {
                    "This Joker gains {X:mult,C:white}^#1#{} Mult",
                    "per {C:purple}Purple Seal{} card discarded",
                    "{C:inactive}(Currently {X:mult,C:white}^#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_bao_shylily = {
                name = "Bao + ShyLily",
                text = {
                    "Retrigger the {C:attention}last{} played card",
                    "{C:attention}#1#{} times, or {C:attention}#2#{} times",
                    "during a {C:blue}Downpour{}",
                },
            },
            celesta_bind_bao_nihmune = {
                name = "Bao + Nihmune",
                text = {
                    "During a {C:blue}Downpour{}, retrigger the",
                    "first played {C:clubs}Club{} card {C:attention}#1#{} times",
                },
            },
            celesta_bind_shylily_nihmune = {
                name = "ShyLily + Nihmune",
                text = {
                    "Retrigger each played",
                    "{C:clubs}Club{} card {C:attention}#1#{} times",
                },
            },
            celesta_bind_fream_nostro = {
                name = "Fream + Nostro",
                text = {
                    "Retrigger played {C:attention}Gash{}",
                    "cards {C:attention}#1#{} time",
                },
            },
            celesta_bind_kairyu_beribug = {
                name = "Kairyu + BeriBug",
                text = {
                    "Retrigger each played {C:attention}8{} {C:attention}#1#{} time",
                    "for each {C:red}discard{} used this round",
                    "{C:inactive}(Currently {C:attention}#2#{C:inactive} times)",
                },
            },
            celesta_bind_suto_fefe = {
                name = "Suto + FeFe",
                text = {
                    "Converts all played cards and",
                    "{C:hearts}Heart{} cards held in hand",
                    "to {C:attention}Wild Cards{}",
                },
            },
            celesta_bind_squchan_laimu = {
                name = "Squchan + Laimu",
                text = {
                    "At the start of the round, add a",
                    "{C:dark_edition}Holographic{} {C:attention}Limestone Card{}",
                    "to your full deck",
                },
            },
            celesta_bind_suko_koko = {
                name = "Suko + KokoNuts",
                text = {
                    "At the start of the round, add a",
                    "{C:dark_edition}Foil{} {C:attention}Lucky{} {C:attention}7{} of {C:spades}Spades{}",
                    "to your full deck",
                },
            },
            celesta_bind_koko_cerber = {
                name = "KokoNuts + Cerber",
                text = {
                    "Retrigger each played {C:attention}7{} {C:attention}#1#{} times",
                },
            },
            celesta_bind_heavenly_aethal = {
                name = "HeavenlyFather + Aethal",
                text = {
                    "{C:attention}+#1#{} shop slots,",
                    "{C:attention}+#2#{} Booster Pack slots and",
                    "{C:attention}+#3#{} Voucher slots",
                    "available in the shop",
                },
            },
            celesta_bind_berry_cweam = {
                name = "BerryCrepe + CweamCat",
                text = {
                    "This Joker gains {C:mult}+#1#{} Mult",
                    "if played hand is a {C:attention}#2#{}",
                    "{C:inactive}(hand changes after each hand played)",
                    "{C:inactive}(Currently {C:mult}+#3#{C:inactive} Mult)",
                },
            },
            celesta_bind_arar_froggy = {
                name = "Arar + FroggyLoch",
                text = {
                    "At the start of each round, each",
                    "unenhanced card held in hand has a",
                    "{C:green}#1# in #2#{} chance to gain an {C:attention}enhancement{}:",
                    "the one made by the {C:tarot}Tarot{} in the",
                    "{C:attention}first{} consumable slot, or a random",
                    "one if there is none",
                },
            },
            celesta_bind_arar_maya = {
                name = "Arar + Maya",
                text = {
                    "At the start of each round, a random",
                    "unenhanced card held in hand becomes a",
                    "{C:attention}Steel Card{} with a {C:red}Red Seal{}",
                    "{C:green}#1# in #2#{} chance for a",
                    "{C:attention}Foppy Seal{} instead",
                },
            },
            celesta_bind_hannah_koko = {
                name = "Hannah Hyrule + KokoNuts",
                text = {
                    "The last scoring card gives",
                    "{X:chips,C:white}X#1#{} Chips and {X:mult,C:white}X#2#{} Mult",
                    "when scored",
                },
            },
            celesta_bind_yoclesh_milky = {
                name = "Yoclesh + Milky",
                text = {
                    "Played {C:hearts}Heart{} cards have a",
                    "{C:green}#1# in #2#{} chance to create a",
                    "random {C:dark_edition}Negative{} consumable",
                    "when scored",
                },
            },
            celesta_bind_vienna_tricky = {
                name = "Vienna + Trickywi",
                text = {
                    "When a {V:1}#1#{} card is destroyed,",
                    "earn {C:money}${} equal to its rank",
                    "{C:inactive}(Face cards count as 10)",
                },
            },
            celesta_bind_tricky_nihmune = {
                name = "Trickywi + Nihmune",
                text = {
                    "When a {C:clubs}Club{} card is destroyed,",
                    "earn {C:money}${} equal to its rank",
                    "{C:inactive}(Face cards count as 10)",
                },
            },
            celesta_bind_rainhoe_nihmune = {
                name = "Rainhoe + Nihmune",
                text = {
                    "{X:money,C:white}X#1#{} interest if there are",
                    "{C:attention}#2#{} or more {C:clubs}Club{} cards",
                    "in your full deck",
                    "{C:inactive}(Currently {C:attention}#3#{C:inactive})",
                },
            },
            celesta_bind_yuzu_bao = {
                name = "Yuzu + Bao",
                text = {
                    "During a {C:blue}Downpour{}, {C:green}#1# in #2#{}",
                    "chance for cards held in hand",
                    "to give {C:money}$#3#{} when a hand is played",
                },
            },
            celesta_bind_yuzu_tricky = {
                name = "Yuzu + Trickywi",
                text = {
                    "{C:green}#1# in #2#{} chance for {C:attention}Scoria{}",
                    "cards held in hand to give money equal",
                    "to this Joker's sell value when a",
                    "hand is played",
                    "{C:inactive}(Currently {C:money}$#3#{C:inactive})",
                },
            },
            celesta_bind_yuzu_nihmune = {
                name = "Yuzu + Nihmune",
                text = {
                    "{C:green}#1# in #2#{} chance for {C:clubs}Club{}",
                    "cards held in hand to give",
                    "{C:money}$#3#{} when a hand is played",
                },
            },
            celesta_bind_yuzu_vienna = {
                name = "Yuzu + Vienna",
                text = {
                    "{C:green}#1# in #2#{} chance for {V:1}#4#{}",
                    "cards held in hand to give",
                    "{C:money}$#3#{} when a hand is played",
                },
            },
            celesta_bind_bao_vienna = {
                name = "Bao + Vienna",
                text = {
                    "Played {V:1}#3#{} cards give {C:mult}+#1#{} Mult",
                    "when scored, or {X:mult,C:white}X#2#{} Mult",
                    "during a {C:blue}Downpour{}",
                },
            },
            celesta_bind_tricky_bao = {
                name = "Trickywi + Bao",
                text = {
                    "Money earned during a",
                    "{C:blue}Downpour{} is {X:money,C:white}X#1#{}",
                },
            },
            celesta_bind_yuzu_juniper = {
                name = "Yuzu + Juniper Actias",
                text = {
                    "This Joker gains {X:chips,C:white}X#1#{} Chips",
                    "for each {V:1}#3#{} card added to your deck",
                    "{C:inactive}(Currently {X:chips,C:white}X#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_yoka_boop = {
                name = "Yoka Siri + ItsDeadlyBoop",
                text = {
                    "{C:green}#1# in #2#{} chance to multiply the values",
                    "of the Joker to the right by {X:attention,C:white}X#3#{}",
                    "when a {C:attention}Full House{} or",
                    "{C:attention}Flush House{} is played",
                },
            },
            celesta_bind_shenpai_rt = {
                name = "Shenpai + RTGame",
                text = {
                    "If scoring hand contains {C:attention}4{} cards",
                    "of the same rank, this Joker gains",
                    "{X:mult,C:white}X#1#{} Mult times the sum of",
                    "the scoring cards' ranks",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_rin_rt = {
                name = "Rin Penrose + RTGame",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult",
                    "every {C:attention}#2#{} Chips scored",
                    "{C:inactive}(#3# Chips remaining)",
                    "{C:inactive}(Currently {X:mult,C:white}X#4#{C:inactive} Mult)",
                },
            },
            celesta_bind_cottontail_fefe = {
                name = "CottontailVA + FeFe",
                text = {
                    "{C:green}#1# in #2#{} chance to add a {C:attention}Star Seal{}",
                    "to scoring {C:hearts}Heart{} cards",
                    "Converts scoring cards to {C:hearts}Hearts{}",
                    "after the hand finishes scoring",
                },
            },
            celesta_bind_glasses_koko = {
                name = "Glassesjournal + KokoNuts",
                text = {
                    "{C:attention}7s{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_gluttonous = {
                name = "Glassesjournal + Gluttonous Joker",
                text = {
                    "{C:clubs}Clubs{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_wrathful = {
                name = "Glassesjournal + Wrathful Joker",
                text = {
                    "{C:spades}Spades{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_lusty = {
                name = "Glassesjournal + Lusty Joker",
                text = {
                    "{C:hearts}Hearts{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_greedy = {
                name = "Glassesjournal + Greedy Joker",
                text = {
                    "{C:diamonds}Diamonds{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_auteru = {
                name = "Glassesjournal + Auteru",
                text = {
                    "{V:1}#1#{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_cosmic = {
                name = "Glassesjournal + Cosmic",
                text = {
                    "{V:1}#1#{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_fream = {
                name = "Glassesjournal + Fream",
                text = {
                    "{C:attention}Wild Cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_eros = {
                name = "Glassesjournal + Eros",
                text = {
                    "{C:attention}Bonus Cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_layna = {
                name = "Glassesjournal + LaynaLazar",
                text = {
                    "{C:attention}Mult Cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_kael = {
                name = "Glassesjournal + Kael",
                text = {
                    "{C:attention}10s{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_stone = {
                name = "Glassesjournal + Stone Joker",
                text = {
                    "{C:attention}Stone Cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_glass = {
                name = "Glassesjournal + Glass Joker",
                text = {
                    "{C:attention}Glass Cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_shoto = {
                name = "Glassesjournal + Shoto",
                text = {
                    "{C:attention}Gash Cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_midas = {
                name = "Glassesjournal + Midas Mask",
                text = {
                    "{C:attention}Gold Cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_laimu = {
                name = "Glassesjournal + Laimu",
                text = {
                    "{C:attention}Limestone Cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_baron = {
                name = "Glassesjournal + Baron",
                text = {
                    "{C:attention}Kings{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_giwi = {
                name = "Glassesjournal + Giwi",
                text = {
                    "{C:attention}Queens{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_moon = {
                name = "Glassesjournal + Shoot the Moon",
                text = {
                    "{C:attention}Queens{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_wee = {
                name = "Glassesjournal + Wee Joker",
                text = {
                    "{C:attention}2s{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_road = {
                name = "Glassesjournal + Hit the Road",
                text = {
                    "{C:attention}Jacks{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_lucky = {
                name = "Glassesjournal + Lucky Cat",
                text = {
                    "{C:attention}Lucky Cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_sock = {
                name = "Glassesjournal + Sock and Buskin",
                text = {
                    "{C:attention}Face cards{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_sixth = {
                name = "Glassesjournal + Sixth Sense",
                text = {
                    "{C:attention}6s{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_eight = {
                name = "Glassesjournal + 8 Ball",
                text = {
                    "{C:attention}8s{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_cloud = {
                name = "Glassesjournal + Cloud 9",
                text = {
                    "{C:attention}9s{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_glasses_kirana = {
                name = "Glassesjournal + Kirana",
                text = {
                    "{C:attention}3s{} are dealt",
                    "before other cards",
                },
            },
            celesta_bind_koko_layna = {
                name = "KokoNuts + LaynaLazar",
                text = {
                    "Removes {C:attention}Lucky{} enhancements",
                    "from scoring cards, this Joker",
                    "gains {C:mult}+#1#{} Mult per",
                    "enhancement removed",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_koko_cottontail = {
                name = "KokoNuts + CottontailVA",
                text = {
                    "At the start of each round, add a",
                    "{C:attention}Lucky{} {C:attention}7{} of {C:spades}Spades{} with a",
                    "{C:attention}Star Seal{} to your deck",
                },
            },
            celesta_bind_crelly_layna = {
                name = "Crelly + LaynaLazar",
                text = {
                    "Removes {C:attention}Mult{} enhancements",
                    "from scoring cards, this Joker",
                    "gains {X:mult,C:white}X#1#{} Mult per",
                    "enhancement removed",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_spite_megalodon = {
                name = "Spite + Megalodon",
                text = {
                    "This Joker gains {C:mult}+#1#{} Mult every time",
                    "an {C:attention}Ectoplast Seal{} successfully triggers",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_spite_cottontail = {
                name = "Spite + CottontailVA",
                text = {
                    "{C:green}#1# in #2#{} chance to add either a",
                    "{C:attention}Star Seal{} or an {C:attention}Ectoplast Seal{}",
                    "to a scoring card with no seal",
                },
            },
            celesta_bind_spite_vexoria = {
                name = "Spite + Vexoria",
                text = {
                    "{C:green}#1# in #2#{} chance to add an",
                    "{C:attention}Ectoplast Seal{} to a scored",
                    "{C:spades}Spade{} card with no seal",
                },
            },
            celesta_bind_spite_tricky = {
                name = "Spite + Trickywi",
                text = {
                    "At the end of the shop, {C:green}#1# in #2#{} chance",
                    "to make the Joker to the {C:attention}left{} {C:dark_edition}Negative{}",
                    "Otherwise it is destroyed and earns",
                    "{C:attention}#3#X{} its {C:money}sell value{}",
                },
            },
            celesta_bind_spite_elxox = {
                name = "Spite + El XoX",
                text = {
                    "At the end of the round, gain {C:money}$#1#{}",
                    "for each {C:attention}Ectoplast Seal{} that",
                    "successfully triggered that round",
                },
            },
            celesta_bind_koko_tricky = {
                name = "KokoNuts + Trickywi",
                text = {
                    "After the shop, {C:green}#1# in #2#{} chance to",
                    "{C:attention}destroy{} the Joker to the left and",
                    "receive {C:attention}#3#X{} its {C:money}sell value{}",
                },
            },
            celesta_bind_yuzu_laimu = {
                name = "Yuzu + Laimu",
                text = {
                    "At the end of the round, gain {C:money}$#1#{}",
                    "for each {C:attention}Limestone{} card",
                    "in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {C:money}$#2#{C:inactive})",
                },
            },
            celesta_bind_yuzu_camila = {
                name = "Yuzu + Camila",
                text = {
                    "If the first played hand contains",
                    "{C:attention}1{} card, destroy it and gain {C:money}$#1#{}",
                },
            },
            celesta_bind_yuzu_shoto = {
                name = "Yuzu + Shoto",
                text = {
                    "{C:attention}Gashed{} cards held in hand have a",
                    "{C:green}#1# in #2#{} chance to give {C:money}$#3#{}",
                    "when a hand is played",
                },
            },
            celesta_bind_arielle_ray = {
                name = "Arielle + Ray",
                text = {
                    "Jokers that give {C:mult}+3{} Mult for a",
                    "{C:attention}suit{} instead give {C:mult}+#1#{} Mult",
                    "when any card is scored",
                },
            },
            celesta_bind_arielle_henya = {
                name = "Arielle + Henya",
                text = {
                    "Cards give {C:money}$#1#{} when scored",
                },
            },
            celesta_bind_arielle_buffpup = {
                name = "Arielle + Buffpup",
                text = {
                    "{C:chips}+#1#{} Chips for each card",
                    "in your {C:attention}full deck{}",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_ray_cottontail = {
                name = "Ray + CottontailVA",
                text = {
                    "{C:attention}Star Seal{} cards give",
                    "{C:attention}#1#{} copies of the card to",
                    "their {C:attention}left{} when unscoring",
                },
            },
            celesta_bind_geega_henya = {
                name = "Geega + Henya",
                text = {
                    "{C:attention}Debuffed{} Jokers sell for",
                    "{C:attention}#1#X{} their normal amount",
                },
            },
            celesta_bind_quad_beastiez = {
                name = "The Beastiez",
                text = {
                    "Scored {C:attention}8{}s of {V:1}#3#{} or",
                    "{C:celesta_true_star}True Stars{} give {X:mult,C:white}X#1#{} Mult",
                    "and {C:attention}+#2#{} hand size for the round",
                },
            },
            celesta_bind_quad_tootie_pies = {
                name = "Tootie Pies",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult per",
                    "{C:attention}Lucky 7 of Spades{}, {C:attention}Star Seal{} card",
                    "or {C:attention}Mult{} card in your full deck",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_quad_piss_boys = {
                name = "Piss Boys",
                text = {
                    "Adds {C:attention}#1#X{} the rank of the lowest",
                    "and highest card {C:attention}held in hand{}",
                    "to both {C:chips}Chips{} and {C:mult}Mult{}",
                },
            },
            celesta_bind_quad_sinful = {
                name = "Sinful Joker",
                text = {
                    "Scored cards give {C:mult}+#1#{} Mult",
                    "and then {X:mult,C:white}X#2#{} Mult",
                },
            },
            celesta_bind_quad_geode = {
                name = "Geode",
                text = {
                    "Scored cards give {C:money}$#1#{}, {C:chips}+#2#{} Chips,",
                    "{C:mult}+#3#{} Mult, and a {C:green}#4# in #5#{} chance",
                    "for {X:mult,C:white}X#6#{} Mult",
                },
            },
            celesta_bind_kairyu_kael = {
                name = "Kairyu + Kael",
                text = {
                    "All cards are",
                    "considered {C:attention}10s{}",
                },
            },
            celesta_bind_giwi_kael = {
                name = "Giwi + Kael",
                text = {
                    "All cards are",
                    "considered {C:attention}Queens{}",
                },
            },
            celesta_bind_kairyu_giwi = {
                name = "Kairyu + Giwi",
                text = {
                    "Gain {C:attention}+#1#{} hand size for every",
                    "{C:attention}Queen{} discarded this round",
                    "{C:inactive}(Currently {C:attention}+#2#{C:inactive} hand size)",
                },
            },
            celesta_bind_kumi_crelly = {
                name = "Kumi + Crelly",
                text = {
                    "Destroys all scoring {C:attention}Gold{} cards in",
                    "played hand, gaining {X:mult,C:white}X#1#{} Mult each",
                    "{C:green}#2# in #3#{} chance to earn {C:money}$#4#{}",
                    "per card destroyed",
                    "{C:inactive}(Currently {X:mult,C:white}X#5#{C:inactive} Mult)",
                },
            },
            celesta_bind_quad_benception = {
                name = "Benception",
                text = {
                    "Draw your {C:attention}entire deck{} to hand",
                    "when {C:attention}Blind{} is selected",
                },
            },
            celesta_bind_kairyu_nihmune = {
                name = "Kairyu + Nihmune",
                text = {
                    "Gain {C:attention}+#1#{} hand size for every",
                    "{C:attention}#2#{} {C:clubs}Club{} cards discarded this round",
                    "{C:inactive}(Currently {C:attention}+#3#{C:inactive} hand size)",
                },
            },
            celesta_bind_kairyu_aicandii = {
                name = "Kairyu + AiCandii",
                text = {
                    "At the end of the round, gains",
                    "{C:mult}+#1#{} Mult per {C:attention}discard{} used",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_aicandii_shiabun = {
                name = "AiCandii + Shiabun",
                text = {
                    "{C:attention}+#1#{} card selection limit, equal to",
                    "your {C:red}Discards{} remaining",
                },
            },
            celesta_bind_aicandii_rosedoodle = {
                name = "AiCandii + Rosedoodle",
                text = {
                    "At the end of the round, this Joker gains",
                    "{X:mult,C:white}X#1#{} Mult per unused {C:attention}discard{}",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_aicandii_ironmouse = {
                name = "AiCandii + Ironmouse",
                text = {
                    "At the end of the round, this Joker gains",
                    "{E:1,C:mult}^#1#{} Mult per unused {C:attention}discard{}",
                    "{C:inactive}(Currently {E:1,C:mult}^#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_arar_liffeh = {
                name = "Arar + Liffeh",
                text = {
                    "When a hand is played, add an {C:attention}enhancement{}",
                    "to a random unenhanced card held in hand",
                    "{C:green}#1# in #2#{} chance to create a {C:dark_edition}Negative{}",
                    "{C:tarot}Tarot{} that makes that enhancement",
                },
            },
            celesta_bind_arar_taehoongie = {
                name = "Arar + Taehoongie",
                text = {
                    "When a hand containing a {C:attention}#1#{} is played,",
                    "add a random {C:attention}enhancement{} to every",
                    "unenhanced card held in hand",
                },
            },
            celesta_bind_jaws_taehoongie = {
                name = "Jaws + Taehoongie",
                text = {
                    "When a hand containing a {C:attention}#1#{} is played,",
                    "each played card permanently gains {C:chips}+#2#{} Chips",
                },
            },
            celesta_bind_liffeh_taehoongie = {
                name = "Liffeh + Taehoongie",
                text = {
                    "{C:green}#1# in #2#{} chance to create a random",
                    "{C:attention}Consumable{} card when a card is scored",
                    "{C:inactive}(Must have room)",
                },
            },
            celesta_bind_hime_melody = {
                name = "Hime + Projekt Melody",
                text = {
                    "Earn {C:money}$#1#{} for each {C:attention}Eutrophic{} card",
                    "held in hand when a hand is played",
                },
            },
            celesta_bind_hime_nyanners = {
                name = "Hime + Nyanners",
                text = {
                    "{C:chips}+#1#{} Chips for each {C:attention}Eutrophic{}",
                    "card in your full deck",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_quad_bazoinga = {
                name = "Big Bazoinga Boys",
                text = {
                    "When a hand containing a {C:attention}#1#{} is played, add a",
                    "random {C:attention}enhancement{} to every unenhanced card held",
                    "in hand, and each played card permanently gains {C:chips}+#2#{} Chips",
                    "{C:green}#3# in #4#{} chance to create a random {C:attention}Consumable{}",
                    "card when a card is scored {C:inactive}(Must have room)",
                },
            },
            celesta_bind_mogu_sunnysplosion = {
                name = "Mogu + SunnySplosion",
                text = {
                    "Increases the {C:attention}rank{} of each",
                    "played card by {C:attention}#1#{}, if possible",
                },
            },
            celesta_bind_henya_zentreya = {
                name = "Henya + Zentreya",
                text = {
                    "Earn {C:money}$#1#{} every time a {C:attention}Steel Card{}",
                    "is scored or triggered held in hand",
                },
            },
            celesta_bind_zentreya_cottontail = {
                name = "Zentreya + CottontailVA",
                text = {
                    "Scored cards with a {C:attention}Star Seal{} have",
                    "a {C:green}#1# in #2#{} chance to give {X:mult,C:white}X#3#{} Mult",
                },
            },
            celesta_bind_kairyu_shiabun = {
                name = "Kairyu + Shiabun",
                text = {
                    "{C:attention}+#1#{} card selection limit, equal to",
                    "the {C:red}discards{} used this round",
                },
            },
            celesta_bind_kairyu_ironmouse = {
                name = "Kairyu + Ironmouse",
                text = {
                    "This Joker gains {E:1,C:mult}^#1#{} Mult",
                    "every time a {C:red}discard{} is used",
                    "{C:inactive}(Currently {E:1,C:mult}^#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_kairyu_vulpixie = {
                name = "Kairyu + Vulpixie",
                text = {
                    "Unfreezes a random {C:attention}Joker{}",
                    "every time a {C:red}discard{} is used",
                },
            },
            celesta_bind_giwi_vulpixie = {
                name = "Giwi + Vulpixie",
                text = {
                    "Unfreezes a random {C:attention}Joker{}",
                    "when a {C:attention}Queen{} is scored",
                },
            },
            celesta_bind_jax_jowol = {
                name = "Jax + Jowol",
                text = {
                    "Retriggers {C:attention}Stone{}, {C:attention}Limestone{},",
                    "{C:attention}Sandstone{} and {C:attention}Scoria{} cards",
                    "{C:attention}#1#{} extra time",
                },
            },
            celesta_bind_quad_baulder_gang = {
                name = "The Baulder Gang",
                text = {
                    "All cards are considered the {C:attention}same suit{}",
                    "Retrigger each scored card {C:attention}#1#{} time,",
                    "or {C:attention}#2#{} times if {C:attention}enhanced{}",
                    "This Joker gains {C:chips}+#3#{} Chips when a card",
                    "scores and when a {C:attention}Joker{} triggers",
                    "{C:inactive}(Currently {C:chips}+#4#{C:inactive} Chips)",
                },
            },
            celesta_bind_quad_lab_brats = {
                name = "Lab Brats",
                text = {
                    "{C:attention}+1{} consumable slot per {C:money}$#1#{},",
                    "{C:attention}+1{} Joker slot per {C:money}$#2#{}, and earn",
                    "that many dollars at end of round",
                },
            },
            celesta_bind_zentreya_bluto = {
                name = "Zentreya + Bluto",
                text = {
                    "Retriggers each owned {C:attention}Blueprint{}",
                    "and {C:attention}Brainstorm{} once per {C:attention}Steel Card{}",
                    "held in hand when a hand is played",
                    "{C:inactive}(Currently {C:attention}#1#{C:inactive} retriggers)",
                },
            },
            celesta_bind_zentreya_kumi = {
                name = "Zentreya + Kumi",
                text = {
                    "{C:attention}Gold{} cards give {C:money}$#1#{} at the",
                    "end of the round instead of {C:money}$3{}",
                },
            },
            celesta_bind_quad_wildcard_club = {
                name = "The Wildcard Club",
                text = {
                    "Starts a {C:blue}Snowstorm{} at the start of the round",
                    "This Joker cannot be {C:blue}frozen{}, and during a",
                    "{C:blue}Snowstorm{} gains {X:mult,C:white}^#1#{} Mult per {C:chips}#2#{} Chips scored",
                    "{C:inactive}(Currently {X:mult,C:white}^#3#{C:inactive} Mult)",
                },
            },
            celesta_bind_quad_vchiban = {
                name = "VchiBan",
                text = {
                    "{C:attention}+#1#{} card selection limit, equal to",
                    "your {C:red}Discards{} remaining",
                    "Scored {V:1}#5#{} cards have a {C:green}#2# in #3#{} chance",
                    "to give {X:chips,C:white}X#4#{} Chips",
                },
            },
            celesta_bind_buffpup_ironmouse = {
                name = "Buffpup + Ironmouse",
                text = {
                    "Scored {V:1}#4#{} cards have a {C:green}#1# in #2#{}",
                    "chance to give {X:mult,C:white}^#3#{} Mult",
                },
            },
            celesta_bind_buffpup_aicandii = {
                name = "Buffpup + AiCandii",
                text = {
                    "This Joker gains {C:chips}+#1#{} Chips per {V:1}#2#{}",
                    "card held in hand at the end of the round",
                    "{C:inactive}(Currently {C:chips}+#3#{C:inactive} Chips)",
                },
            },
            celesta_bind_haruka_henya = {
                name = "Haruka Karibu + Henya",
                text = {
                    "Earn {C:money}$#1#{} every time a",
                    "{C:attention}Consumable{} card is used",
                },
            },
            celesta_bind_haruka_nyanners = {
                name = "Haruka Karibu + Nyanners",
                text = {
                    "{C:chips}+#1#{} Chips for each held",
                    "{C:attention}Consumable{} card",
                    "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
                },
            },
            celesta_bind_cdawg_ironmouse = {
                name = "CDawg + Ironmouse",
                text = {
                    "This Joker gains {X:mult,C:white}^#1#{} Mult for each",
                    "{C:attention}Common{} Joker sold this run",
                    "{C:inactive}(Currently {X:mult,C:white}^#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_quad_sloppy_sisters = {
                name = "Sloppy Sisters",
                text = {
                    "When the played hand finishes scoring,",
                    "each {C:attention}Limestone{} card held in hand",
                    "gives its {C:mult}Mult{} times the number",
                    "of cards played",
                },
            },
            celesta_bind_kairyu_piapiufo = {
                name = "Kairyu + PiaPiUFO",
                text = {
                    "Gain {C:attention}+#1#{} hand size for every",
                    "{C:attention}#2#{} {V:1}#3#{} cards discarded this round",
                    "{C:inactive}(Currently {C:attention}+#4#{C:inactive} hand size)",
                },
            },
            celesta_bind_kairyu_torioriane = {
                name = "Kairyu + Tori Oriane",
                text = {
                    "Gain {C:attention}+#1#{} hand size for every",
                    "{C:celesta_true_star}True Star{} card discarded this round",
                    "{C:inactive}(Currently {C:attention}+#2#{C:inactive} hand size)",
                },
            },
            celesta_bind_piapiufo_beribug = {
                name = "PiaPiUFO + BeriBug",
                text = {
                    "Scored {C:attention}8{}s give",
                    "{X:mult,C:white}X#1#{} Mult",
                },
            },
            celesta_bind_torioriane_beribug = {
                name = "Tori Oriane + BeriBug",
                text = {
                    "Retrigger all scored",
                    "{C:celesta_true_star}True Star{} cards",
                },
            },
            celesta_bind_piapiufo_torioriane = {
                name = "PiaPiUFO + Tori Oriane",
                text = {
                    "Scored {C:celesta_true_star}True Star{} cards give",
                    "{X:mult,C:white}X#1#{} Mult and {X:chips,C:white}X#2#{} Chips",
                },
            },
            celesta_bind_mooni_mother = {
                name = "Mooni + MOTHERv3",
                text = {
                    "Earn {C:money}$#1#{} for each",
                    "discarded {C:attention}Exo{} card",
                },
            },
            -- What the merge web shows when the pair has not been made.
            -- An entry rather than a string built in code, so it is the same
            -- shape as any other description and the popup needs no special
            -- case for it.
            celesta_bind_hidden = {
                name = "",
                text = {
                    "{C:inactive}Hidden until merged.",
                },
            },
            celesta_bind_ray_axial = {
                name = "Ray + AxialMatt",
                text = {
                    "Adds {C:attention}double{} the rank",
                    "of the {C:attention}highest{} and {C:attention}lowest{}",
                    "ranked cards held in hand",
                    "to {C:mult}Mult{}",
                },
            },
            celesta_bind_ellie_miniko = {
                name = "Ellie Minibot + Minikomew",
                text = {
                    "{C:mult}+#1#{} Mult for every {C:money}$1{}",
                    "your money is below {C:money}$0{}",
                    "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_ellie_shoomimi = {
                name = "Ellie Minibot + Shoomimi",
                text = {
                    "The first {C:attention}reroll{} in each shop",
                    "gives {C:dark_edition}+#1#{} Joker slot",
                },
            },
            celesta_bind_ellie_chrchie = {
                name = "Ellie Minibot + Chrchie",
                text = {
                    "Earn {C:money}$#1#{} at the end of the round",
                    "for each card {C:attention}played{} that round",
                    "{C:inactive}(Currently {C:attention}#2#{C:inactive} cards)",
                },
            },
            celesta_bind_shoomimi_miniko = {
                name = "Shoomimi + Minikomew",
                text = {
                    "{C:green}#1# in #2#{} chance for a",
                    "shop {C:attention}reroll{} to cost nothing",
                },
            },
            celesta_bind_chrchie_miniko = {
                name = "Chrchie + Minikomew",
                text = {
                    "At the end of the round, if your",
                    "money is below {C:money}$0{},",
                    "raise it to {C:money}$0{}",
                },
            },
            celesta_bind_ironmouse_melody = {
                name = "Ironmouse + Projekt Melody",
                text = {
                    "This Joker gains {X:mult,C:white}^#1#{} Mult",
                    "after each round, or {X:mult,C:white}^#2#{} Mult",
                    "after skipping a Blind",
                    "{C:inactive}(Currently {X:mult,C:white}^#3#{C:inactive} Mult)",
                },
            },
            celesta_bind_ironmouse_silver = {
                name = "Ironmouse + Silvervale",
                text = {
                    "This Joker gains {X:mult,C:white}^#1#{} Mult",
                    "for each {C:rare}Rare{} Joker sold this run",
                    "{C:inactive}(Currently {X:mult,C:white}^#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_melody_silver = {
                name = "Projekt Melody + Silvervale",
                text = {
                    "Earn {C:money}$#1#{} at end of round",
                    "Payout increases by {C:money}$#2#{} for each",
                    "{C:rare}Rare{} Joker sold this run",
                },
            },
            celesta_bind_moo_yomi = {
                name = "Moo Merrily + Yomi Quinnely",
                text = {
                    "At the start of each round,",
                    "creates a {C:spectral}Burgundy Brew{}",
                    "{C:inactive}(Must have room)",
                },
            },
            celesta_bind_ray_layna = {
                name = "Ray + LaynaLazar",
                text = {
                    "Retrigger played {C:attention}Mult{}",
                    "cards {C:attention}#1#{} time",
                },
            },
            celesta_bind_arielle_froggy = {
                name = "Arielle + FroggyLoch",
                text = {
                    "{C:green}#1# in #2#{} chance to retrigger",
                    "played cards {C:attention}#3#{} times",
                },
            },
            celesta_bind_arielle_haruka = {
                name = "Arielle + Haruka Karibu",
                text = {
                    "{C:green}#1# in #2#{} chance to add a random",
                    "{C:dark_edition}edition{} to cards or Jokers",
                    "a {C:tarot}Tarot{} card is used on",
                },
            },
            celesta_bind_aquwa_megalodon = {
                name = "Aquwa + Megalodon",
                text = {
                    "This Joker gains {C:mult}+#1#{} Mult",
                    "for each card in played hand",
                    "{X:mult,C:white}X#2#{} as much during a {C:blue}Downpour{}",
                    "{C:inactive}Resets at end of round{}",
                    "{C:inactive}(Currently {C:mult}+#3#{C:inactive} Mult)",
                },
            },
            celesta_bind_aquwa_yuy = {
                name = "Aquwa + Yuy",
                text = {
                    "Starts a {C:blue}Downpour{} at the",
                    "start of each round",
                    "On the {C:attention}final hand{} of the round,",
                    "each scoring card gives",
                    "{X:mult,C:white}X#1#{} Mult",
                },
            },
            celesta_bind_cottontail_layna = {
                name = "CottontailVA + LaynaLazar",
                text = {
                    "Adds a {C:attention}Star Seal{} to a scored",
                    "{C:attention}Mult Card{} with no seal",
                },
            },
            celesta_bind_aquwa_nekrolina = {
                name = "Aquwa + Nekrolina",
                text = {
                    "Starts a {C:blue}Downpour{} at the",
                    "start of each round",
                    "Earn {C:money}$#1#{} for each {C:dark_edition}Negative{}",
                    "consumable obtained",
                },
            },
            celesta_bind_berry_chrchie = {
                name = "BerryCrepe + Chrchie",
                text = {
                    "Scored cards permanently",
                    "gain {C:money}$#1#{}",
                },
            },
            celesta_bind_berry_shoomimi = {
                name = "BerryCrepe + Shoomimi",
                text = {
                    "Scored cards permanently",
                    "gain {C:mult}+#1#{} Mult",
                    "{C:inactive}(Equal to your consumable slots)",
                },
            },
            celesta_bind_shoomimi_chrchie = {
                name = "Shoomimi + Chrchie",
                text = {
                    "Earn {C:money}$#1#{} at end of round",
                    "for each consumable slot",
                    "{C:inactive}(Currently {C:money}$#2#{C:inactive})",
                },
            },
            celesta_bind_jaws_liffeh = {
                name = "Jaws + Liffeh",
                text = {
                    "{C:green}#1# in #2#{} chance to gain a",
                    "{C:tarot}Tarot{} card when a card",
                    "is {C:attention}destroyed{}",
                    "{C:inactive}(Must have room)",
                },
            },
            celesta_bind_cottontail_kumi = {
                name = "CottontailVA + Kumi",
                text = {
                    "{C:green}#1# in #2#{} chance for {C:attention}unscored{}",
                    "cards with a {C:attention}Star Seal{}",
                    "to give {C:money}$#3#{}",
                },
            },
            celesta_bind_arielle_nagzz = {
                name = "Arielle + Nagzz",
                text = {
                    "All {C:green}chances{} on cards are {X:green,C:white}X#1#{}",
                    "{C:attention}Lucky Card{} chances are {X:green,C:white}X#2#{}",
                },
            },
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
            celesta_bind_yharon_yharon = {
                name = "Yharon, Dragon of Rebirth + Yharon, Dragon of Rebirth",
                text = {
                    "The {C:mult}Mult{}-modifying Joker to",
                    "the {C:attention}left{} of this Joker uses the",
                    "next highest {C:attention}operator{} for scoring",
                    "{C:inactive}(Caps at tetration)",
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
                name = "Rosedoodle + Buffpup",
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
                name = "Laimu + Ray",
                text = {
                    "Retriggers {C:attention}Bloodstone{}, {C:attention}Rough Gem{},",
                    "{C:attention}Onyx Agate{}, {C:attention}Arrowhead{}, {C:attention}Vienna{}",
                    "and {C:attention}Maple Chicken{} #1# additional time",
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
            celesta_bind_drunkard_juggler = {
                name = "Drunkard + Juggler",
                text = {
                    "{C:attention}+#1#{} hand size",
                    "{C:attention}+#2#{} discards",
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
            celesta_bind_deme_lucypyre = {
                name = "Deme + LucyPyre",
                text = {
                    "This Joker gains {C:attention}+#1#%{} {C:attention}Blind{}",
                    "size reduction per consecutive",
                    "hand played with exactly {C:attention}one{} card",
                    "{C:inactive}(Currently {C:attention}#2#%{C:inactive} Blind Size Reduction)",
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
            celesta_bind_fefe_melody = {
                name = "FeFe + Projekt Melody",
                text = {
                    "Earn {C:money}$#1#{} for every {C:attention}#2#{}",
                    "{C:hearts}Heart{} cards discarded",
                },
            },
            celesta_bind_vexoria_melody = {
                name = "Vexoria + Projekt Melody",
                text = {
                    "Earn {C:money}$#1#{} for every {C:attention}#2#{}",
                    "{C:spades}Spade{} cards discarded",
                },
            },
            celesta_bind_fefe_ironmouse = {
                name = "FeFe + Ironmouse",
                text = {
                    "This Joker gains {E:1,C:mult}^#1#{} Mult for",
                    "each {C:hearts}Heart{} card destroyed",
                    "{C:inactive}(Currently {E:1,C:mult}^#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_fefe_silvervale = {
                name = "FeFe + Silvervale",
                text = {
                    "This Joker gains {X:mult,C:white}X#1#{} Mult for",
                    "each {C:hearts}Heart{} card destroyed",
                    "{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
                },
            },
            celesta_bind_fefe_zentreya = {
                name = "FeFe + Zentreya",
                text = {
                    "Scored {C:hearts}Heart{} cards have a",
                    "{C:green}#1# in #2#{} chance to give",
                    "{X:mult,C:white}X#3#{} Mult",
                },
            },
            celesta_bind_fefe_vexoria = {
                name = "FeFe + Vexoria",
                text = {
                    "{C:hearts}Hearts{} and {C:spades}Spades{} are",
                    "considered the same suit",
                },
            },
            celesta_bind_fefe_momo = {
                name = "FeFe + Momo",
                text = {
                    "{C:hearts}Heart{} cards count as any suit",
                    "in any type of {C:attention}Flush{}",
                },
            },
            celesta_bind_vexoria_vexoria = {
                name = "Vexoria + Vexoria",
                text = {
                    "All cards are considered {C:spades}Spades{}",
                    "Earn {C:money}$#1#{} when a {C:spades}Spade{} card is",
                    "destroyed, increasing by {C:money}$#2#{}",
                },
            },
            celesta_bind_shenpai_vulpixie = {
                name = "Shenpai + Vulpixie",
                text = {
                    "{C:attention}Gold Seal{} cards retrigger {C:attention}#1#{}",
                    "times during a {C:blue}Snowstorm{}",
                    "This Joker cannot be {C:blue}Frozen{}",
                },
            },
            celesta_bind_neuro_evil = {
                name = "Neuro + Evil Neuro",
                text = {
                    "{C:attention}+#1#{} hand size, card selection,",
                    "hands, discards, and every slot",
                    "{X:mult,C:white}X#1#{} Chips and Mult, {C:money}$#1#{} at end of round",
                    "{C:attention}X#1#{} of every {C:attention}Skip Tag{} taken",
                    "{C:attention}-#2#%{} Blind size and shop prices",
                    "All {C:attention}Boss Blinds{} are disabled",
                    "{S:1.1}#1#{} rises at the end of the shop, the",
                    "start of the round, and the end of it",
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
            celesta_gene_seal = {
                name = "Gene Seal",
                text = {
                    "This card is always",
                    "{C:attention}dealt first",
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

            -- The Stamp Pack. A pack is described under its FULL key in
            -- Other (p_*), which is not where any other centre in this
            -- file lives, and the undiscovered line belongs to the
            -- consumable type rather than to any one card.
            -- "of", not vanilla's "of up to". That hedge is for a pack
            -- that comes up short of its own count, and a Stamp Pack never
            -- does: every card in it is made from a forced key rather than
            -- drawn from a pool that can run dry. It also lets one line read
            -- properly in both places, since the Collection has no pack to
            -- have rolled a size and shows the range instead - "Choose 1 of 4
            -- Stamp cards" in the shop, "Choose 1 of 2-5" in the Collection.
            p_celesta_stamp_pack = {
                name = "Stamp Pack",
                text = {
                    "Choose {C:attention}#1#{} of",
                    "{C:attention}#2#{} Stamp cards",
                },
            },
            undiscovered_celesta_stamp = {
                name = "Not Discovered",
                text = {
                    "Purchase or use",
                    "this card in an",
                    "unseen run to",
                    "learn what it does",
                },
            },
            -- What a stamp costs, printed under its effect: the header,
            -- the costs themselves, and the line a card that has not been
            -- rolled yet shows in place of one.
            celesta_stamp_downside = {
                text = {
                    "{C:inactive}Downside:",
                },
            },
            celesta_stamp_downside_tier = {
                text = {
                    "{C:inactive}Comes with a {C:attention}#1#{C:inactive} downside",
                },
            },
            celesta_stamp_down_levels = {
                text = {
                    "{C:red}-#1#{} level to your",
                    "{C:attention}most played{} poker hand",
                },
            },
            celesta_stamp_down_hand_size = {
                text = {
                    "{C:red}-#1#{} hand size for",
                    "the {C:attention}next round{}",
                },
            },
            celesta_stamp_down_hands = {
                text = {
                    "{C:red}-#1#{} hand for",
                    "the {C:attention}next round{}",
                },
            },
            celesta_stamp_down_discards = {
                text = {
                    "{C:red}-#1#{} discard for",
                    "the {C:attention}next round{}",
                },
            },
            celesta_stamp_down_money = {
                text = {
                    "Lose {C:money}$#1#{}",
                    "{C:inactive}(ignores your debt limit)",
                },
            },
            celesta_stamp_down_face_down = {
                text = {
                    "The {C:attention}first hand{} of the next",
                    "round is dealt {C:attention}face down{}",
                },
            },
            celesta_stamp_down_blind_pct = {
                text = {
                    "{C:red}+#1#%{} Blind size for",
                    "the {C:attention}next round{}",
                },
            },
            celesta_stamp_down_blind_mult = {
                text = {
                    "{C:red}X#1#{} Blind size for",
                    "the {C:attention}next round{}",
                },
            },
            celesta_stamp_down_hand_size_perm = {
                text = {
                    "{C:red}-#1#{} hand size,",
                    "{C:attention}permanently{}",
                },
            },
            celesta_stamp_down_hands_perm = {
                text = {
                    "{C:red}-#1#{} hand, {C:attention}permanently{}",
                },
            },
            celesta_stamp_down_discards_perm = {
                text = {
                    "{C:red}-#1#{} discard, {C:attention}permanently{}",
                },
            },
            celesta_stamp_down_blind_pct_perm = {
                text = {
                    "{C:red}+#1#%{} Blind size,",
                    "{C:attention}permanently{}",
                },
            },
            celesta_stamp_down_destroy = {
                text = {
                    "Destroy {C:red}#1#%{} of all cards",
                    "in your {C:attention}full deck{}",
                },
            },
            -- The line a stamped Joker carries. The mark says which stamp
            -- it is wearing and this says what it is worth, which the art
            -- cannot: a X1.1 and a X2 are the same drawing.
            celesta_stamp_mark_mult = {
                text = {
                    "{C:attention}Stamp:{} {C:mult}+#1#{} Mult per trigger",
                },
            },
            celesta_stamp_mark_chips = {
                text = {
                    "{C:attention}Stamp:{} {C:chips}+#1#{} Chips per trigger",
                },
            },
            celesta_stamp_mark_x_mult = {
                text = {
                    "{C:attention}Stamp:{} {X:mult,C:white}X#1#{} Mult per trigger",
                },
            },
            celesta_stamp_mark_x_chips = {
                text = {
                    "{C:attention}Stamp:{} {X:chips,C:white}X#1#{} Chips per trigger",
                },
            },
            celesta_stamp_mark_e_mult = {
                text = {
                    "{C:attention}Stamp:{} {E:1,C:mult}^#1#{} Mult per trigger",
                },
            },
            celesta_stamp_mark_e_chips = {
                text = {
                    "{C:attention}Stamp:{} {E:1,C:chips}^#1#{} Chips per trigger",
                },
            },
            celesta_stamp_mark_dollars = {
                text = {
                    "{C:attention}Stamp:{} {C:money}$#1#{} per trigger",
                },
            },
            celesta_stamp_mark_retrigger = {
                text = {
                    "{C:attention}Stamp:{} retrigger {C:attention}#1#{} #2#",
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
            b_celesta_blizzard = {
                name = "Blizzard Deck",
                text = {
                    "It is always a {C:attention}Snowstorm",
                    "Jokers that care about a",
                    "{C:attention}Snowstorm{} are {C:attention}#1#X{} as likely",
                    "to appear",
                },
            },
            b_celesta_rain = {
                name = "Rain Deck",
                text = {
                    "It is always a {C:attention}Downpour",
                    "Jokers that care about a",
                    "{C:attention}Downpour{} are {C:attention}#1#X{} as likely",
                    "to appear",
                },
            },
            b_celesta_hell = {
                name = "Hell Deck",
                text = {
                    "{C:attention}#1#{} hand",
                    "{C:red}-#2#{} Joker slot, {C:red}-#3#{} consumable slot",
                    "Earn no {C:attention}interest{}",
                },
            },
            b_celesta_sins = {
                name = "Deck of Sins",
                text = {
                    "Start with {C:attention}Overstock{}",
                    "and {C:attention}Overstock Plus{}",
                    "The first shop holds all four",
                    "{C:attention}suit Jokers{}: buying one",
                    "removes the rest for the run",
                },
            },
            b_celesta_rock = {
                name = "Rock Deck",
                text = {
                    "{C:spades}Spades{} and {C:clubs}Clubs{} start as",
                    "{C:attention}Stone Cards{}, {C:hearts}Hearts{} and",
                    "{C:diamonds}Diamonds{} as {C:attention}Limestone Cards{}",
                },
            },
            b_celesta_verdant = {
                name = "Verdant Deck",
                text = {
                    "{C:common}Common{} Jokers no",
                    "longer appear",
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
                name = "Admin Deck",
                text = {
                    "Every card is a {C:attention}Steel King of Hearts{}",
                    "with a {C:red}Red Seal{}",
                    "Start with {C:attention}#1#{} Jokers and consumables",
                    "{C:attention}+1{} consumable slot",
                },
            },
            b_celesta_fusion = {
                name = "Fusion Deck",
                text = {
                    "Every {C:attention}Joker{} offered arrives",
                    "already {C:attention}merged{} with another random {C:attention}Joker{}",
                    "Start with a {C:spectral}Swap{}",
                },
            },
        },

        -- Card Sleeves (items/sleeves.lua). Each sleeve says what its deck
        -- says; `_alt` is what it says on its own deck, where it adds nothing.
        Sleeve = {
            sleeve_celesta_founders = {
                name = "Admin Sleeve",
                text = {
                    "Every card is a {C:attention}Steel King of Hearts{}",
                    "with a {C:red}Red Seal{}",
                    "Start with {C:attention}#1#{} Jokers and consumables",
                    "{C:attention}+1{} consumable slot",
                },
            },
            sleeve_celesta_founders_alt = {
                name = "Admin Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Admin Deck{}",
                },
            },
            sleeve_celesta_plaid = {
                name = "Plaid Sleeve",
                text = {
                    "Start with a full set of",
                    "all {C:attention}#1#{} suits",
                    "{C:attention}+#3#{} hand size",
                    "{C:inactive}(#2# cards)",
                },
            },
            sleeve_celesta_plaid_alt = {
                name = "Plaid Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Plaid Deck{}",
                },
            },
            sleeve_celesta_ecstasy = {
                name = "Ecstasy Sleeve",
                text = {
                    "Only {C:attention}Celesta's Mod{} Jokers appear",
                    "Start with a {C:spectral}Bind{}",
                    "{C:green}1 in #1#{} chance for a {C:spectral}Bind{} and",
                    "{C:green}1 in #2#{} for {C:spectral}The Soul{} in the shop",
                },
            },
            sleeve_celesta_ecstasy_alt = {
                name = "Ecstasy Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Ecstasy Deck{}",
                },
            },
            sleeve_celesta_hell = {
                name = "Hell Sleeve",
                text = {
                    "{C:attention}#1#{} hand",
                    "{C:red}-#2#{} Joker slot, {C:red}-#3#{} consumable slot",
                    "Earn no {C:attention}interest{}",
                },
            },
            sleeve_celesta_hell_alt = {
                name = "Hell Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Hell Deck{}",
                },
            },
            sleeve_celesta_blizzard = {
                name = "Blizzard Sleeve",
                text = {
                    "It is always a {C:attention}Snowstorm",
                    "Jokers that care about a",
                    "{C:attention}Snowstorm{} are {C:attention}#1#X{} as likely",
                    "to appear",
                },
            },
            sleeve_celesta_blizzard_alt = {
                name = "Blizzard Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Blizzard Deck{}",
                },
            },
            sleeve_celesta_rain = {
                name = "Rain Sleeve",
                text = {
                    "It is always a {C:attention}Downpour",
                    "Jokers that care about a",
                    "{C:attention}Downpour{} are {C:attention}#1#X{} as likely",
                    "to appear",
                },
            },
            sleeve_celesta_rain_alt = {
                name = "Rain Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Rain Deck{}",
                },
            },
            sleeve_celesta_verdant = {
                name = "Verdant Sleeve",
                text = {
                    "{C:common}Common{} Jokers no",
                    "longer appear",
                },
            },
            sleeve_celesta_verdant_alt = {
                name = "Verdant Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Verdant Deck{}",
                },
            },
            sleeve_celesta_rock = {
                name = "Rock Sleeve",
                text = {
                    "{C:spades}Spades{} and {C:clubs}Clubs{} start as",
                    "{C:attention}Stone Cards{}, {C:hearts}Hearts{} and",
                    "{C:diamonds}Diamonds{} as {C:attention}Limestone Cards{}",
                },
            },
            sleeve_celesta_rock_alt = {
                name = "Rock Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Rock Deck{}",
                },
            },
            sleeve_celesta_sins = {
                name = "Sins Sleeve",
                text = {
                    "Start with {C:attention}Overstock{}",
                    "and {C:attention}Overstock Plus{}",
                    "The first shop holds all four",
                    "{C:attention}suit Jokers{}: buying one",
                    "removes the rest for the run",
                },
            },
            sleeve_celesta_sins_alt = {
                name = "Sins Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Deck of Sins{}",
                },
            },
            sleeve_celesta_fusion = {
                name = "Fusion Sleeve",
                text = {
                    "Every {C:attention}Joker{} offered arrives",
                    "already {C:attention}merged{} with another random {C:attention}Joker{}",
                    "Start with a {C:spectral}Swap{}",
                },
            },
            sleeve_celesta_fusion_alt = {
                name = "Fusion Sleeve",
                text = {
                    "No extra effect with",
                    "the {C:attention}Fusion Deck{}",
                },
            },
        },

        Mod = {
            -- What the Mods menu shows. Steamodded reads this in preference to
            -- the manifest's `description` string and only falls back to it
            -- when this entry is missing (smods src/ui.lua:252), so this is
            -- the one players actually see - one row per line, colour tags and
            -- all, where the manifest string is a single wrapped paragraph.
            CelestasMod = {
                name = "Celesta's Mod",
                text = {
                    "{C:attention}216{} VTuber Jokers, and two",
                    "{C:spectral}Spectrals{} to do things with them:",
                    " ",
                    "- {C:spectral}Bind{} merges {C:attention}2{} Jokers into one,",
                    "  with {C:attention}300{} unique combinations",
                    "- {C:spectral}Swap{} trades the second Joker of",
                    "  {C:attention}2{} merged ones",
                    "- {C:spectral}Lost Soul{} turns a Joker into its",
                    "  harder, worse-tempered {C:attention}Lost{} version",
                    "- {C:attention}3{} suits, {C:attention}8{} enhancements, {C:attention}5{} seals",
                    "- {C:attention}10{} decks, {C:attention}12{} Boss Blinds, {C:attention}2{} challenges",
                    "- {C:attention}17{} consumables, plus {C:attention}13{} {C:attention}Stamps{}",
                },
            },
        },
    },

    misc = {
        -- Custom challenge rules, rendered from ch_c_<id>.
        --
        -- ONE line each, and that is not a style choice: localize with
        -- type = 'text' returns after the first line it builds
        -- (`if args.type == 'text' then return final_line end`,
        -- misc_functions.lua:2052), so a second line is simply dropped. Every
        -- one of vanilla's own is a single line for the same reason.
        v_text = {
            ch_c_celesta_printer_stake = {
                "Blind base sizes are {C:attention}Gold Stake{}'s",
            },
            ch_c_celesta_printer_quota = {
                "Blind requirement {C:attention}X1{}, {C:attention}X3{}, {C:attention}X6{}, {C:attention}X10{} ... by Ante",
            },
        },
        challenge_names = {
            c_celesta_dairy_farm = "Dairy Farm",
            c_celesta_joker_printer = "Joker Printer",
        },
        labels = {
            m_celesta_exo = "Exo Card",
            m_celesta_eutrophic = "Eutrophic Card",
            m_celesta_limestone = "Limestone Card",
            m_celesta_driftwood = "Driftwood Card",
            m_celesta_gash = "Gash Card",
            m_celesta_scoria = "Scoria Card",
            m_celesta_foliage = "Foliage Card",
            celesta_tattered = "Tattered",
            celesta_cracked = "Cracked",
            celesta_chipped = "Chipped",
            -- The rarity a Corrupt Joker is drawn at, named for what is
            -- left of the card it used to be. Read back through
            -- localize("k_"..rarity:lower()) (SMODS.Rarity:get_rarity_badge),
            -- so it is wanted in labels and in the dictionary both.
            k_celesta_lost = "...",
            celesta_ectoplast_seal = "Ectoplast Seal",
            celesta_foppy_seal = "Foppy Seal",
            celesta_gene_seal = "Gene Seal",
            celesta_rose_seal = "Rose Seal",
            celesta_star_seal = "Star Seal",
        },
        dictionary = {
            k_celesta_lost = "...",
            celesta_cfg_animation = "Arena weather animation (off = tint only)",
            celesta_cfg_verbose = "Verbose logging",
            celesta_cfg_downpour = "Force Downpour (debug)",
            celesta_cfg_unlock_all = "Unlock All Jokers",
            celesta_cfg_discover_all = "Discover All Jokers",
            celesta_cfg_unlock_merges = "Unlock All Merges",
            celesta_cfg_notice = "Show the speed notice at startup",
            -- The startup speed notice (main.lua). One key per line because a
            -- text node holds a line and nothing in the UI wraps, so the
            -- breaks are chosen rather than found.
            celesta_notice_title = "Important:",
            celesta_notice_1 = "It is HIGHLY encouraged that you play the game at the fastest",
            celesta_notice_2 = "speed, as some scoring animations may take a while to score if",
            celesta_notice_3 = "the game speed is set to slow. You can do this by going into the",
            celesta_notice_4 = "game's settings menu and dragging the game speed slider all the",
            celesta_notice_5 = "way to the right.",
            celesta_notice_6 = "Additionally, if the scoring starts to take extremely long, then",
            celesta_notice_7 = "you may want to toggle the \\"Disable Scoring Animations\\" checkbox",
            celesta_notice_8 = "in the Talisman's Mod Config (found by clicking \\"Mods\\" in either",
            celesta_notice_9 = "the main menu or pause menu during a run)",
            celesta_notice_hide = "Do not show this again",
            celesta_notice_ok = "Ok",
            -- The Credits tab. Art this mod did not draw itself; the names
            -- are as the artists give them.
            celesta_credits_tab = "Credits",
            celesta_credit_calamitas = "Calamitas art - u/The_Overseer_Pal",
            celesta_credit_thanatos = "XM-05 Thanatos art - Dezixus on Pinterest",
            celesta_credit_eidolonwyrm = "Eidolon Wyrm art - Nyrallia on DeviantArt",
            celesta_credit_astrum = "Astrum Aureus art - Total Calamity Wiki",
            celesta_credit_urschleim = "Urschleim - Core Keeper wiki",
            celesta_credit_rest_1 = "Other art credits can (probably) be found",
            celesta_credit_rest_2 = "through each person's Twitter/BlueSky pages.",
            -- Floating message text. Vanilla has no generic "+card" key
            -- (k_plus_stone is Marble Joker's own), so this mod supplies one.
            -- The button on the Blessed Phoenix Egg, which is pulled into the
            -- Joker row rather than used.
            celesta_b_pull = "Pull",
            celesta_upgraded = "Upgraded!",
            celesta_gashed = "Gashed!",
            celesta_spread = "Spread!",
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
            celesta_undebuffed = "Undebuffed!",
            celesta_spent = "Spent!",
            celesta_quiet_shop = "Quiet shop!",
            celesta_hearts = "All Hearts!",
            celesta_starred = "All Stars!",
            celesta_spades = "All Spades!",
            celesta_diamonds = "All Diamonds!",
            celesta_clubs = "All Clubs!",
            celesta_plus_seven = "+7 of Spades",
            celesta_downpour = "Downpour!",
            celesta_swapped = "Swapped!",
            celesta_no_upgrade = "Nothing to upgrade!",
            celesta_downgrade = "Downgrade!",
            -- The Special Merges collection tab.
            celesta_special_merges = "Special Merges",
            -- The Deck of Sins' stat sidebar.
            -- The Deck of Sins' stat sidebar, and the upgrade list a stat
            -- opens when it is clicked. These are read through
            -- localize{type="variable"}, so they carry #1# but no colour
            -- markup - the sidebar colours each line by whether it is
            -- unlocked.
            celesta_sin_to_next = "To next level:",
            celesta_sin_level_short = "Lv",
            celesta_unholy_used = "Unbound!",
            celesta_sin_greed = "Greed",
            celesta_sin_lust = "Lust",
            celesta_sin_wrath = "Wrath",
            celesta_sin_gluttony = "Gluttony",
            celesta_sin_pride = "Pride",
            celesta_sin_envy = "Envy",
            celesta_sin_sloth = "Sloth",
            celesta_merge_unknown = "Undiscovered",
            celesta_any_joker = "Any",
            celesta_aces = "All Aces!",
            celesta_stored = "Stored!",
            celesta_useless = "Useless!",
            celesta_plus_consumable = "+Consumable",
            celesta_plus_enhancement = "+Enhancement",
            -- The Stamp consumable type: its name, the button into its page of
            -- the Collection, and the banner over an open Stamp Pack.
            -- Steamodded builds the first two keys itself out of the type's
            -- key, lowercased (game_object.lua:1077).
            k_celesta_stamp = "Stamp",
            b_celesta_stamp_cards = "Stamp Cards",
            k_celesta_stamp_pack = "Stamp Pack",
        },
        -- Substituted messages. localize hands back the literal 'ERROR' for a
        -- key no loaded dictionary has (misc_functions.lua:1726), and that
        -- goes straight into the floating text over the Joker, so anything
        -- this mod says has to be a key this mod ships.
        --
        -- ^Mult is Talisman's arithmetic but not Talisman's text - the entry
        -- that spells it lives in Cryptid, which is not a dependency, so
        -- borrowing a_powmult from it meant the message read ERROR for anyone
        -- without Cryptid installed.
        v_dictionary = {
            celesta_powmult = "^#1# Mult",
            -- Deme + LucyPyre's running total, floated as it climbs.
            celesta_blind_percent = "-#1#% Blind",
            -- The Deck of Sins' upgrade lines. These are read through
            -- localize{type="variable"}, which looks in v_dictionary and
            -- NOT in dictionary - so they belong here, next to the only
            -- other one this mod has.
            celesta_sin_tier_chips = "+#1# Chips when scored",
            celesta_sin_tier_mult = "+#1# Mult when scored",
            celesta_sin_tier_dollars = "$#1# when scored",
            celesta_sin_tier_retriggers = "Retriggered #1# more time(s)",
            celesta_sin_tier_pride_base = "+#1# base Chips per hand level",
            celesta_sin_tier_pride_x = "X#1# Chips after scoring",
            celesta_sin_tier_pride_retrigger = "Bonus cards retriggered #1# times",
            celesta_sin_tier_envy_base = "+#1# base Mult per hand level",
            celesta_sin_tier_envy_x = "X#1# Mult after scoring",
            celesta_sin_tier_envy_retrigger = "Mult cards retriggered #1# times",
            celesta_sin_tier_sloth_dollars = "$#1# at end of round",
            celesta_sin_tier_sloth_discount = "Shop prices #1#% off",
            celesta_sin_tier_sloth_interest = "X#1# interest",
            celesta_sin_tier_sloth_rares = "Rare Jokers appear more often",
            celesta_sin_tier_sloth_legendary = "Legendary Jokers appear in the shop",
        },
    },
}
'''


def main():
    # Card art is masked to Balatro's silhouette FIRST, every run, before
    # anything else looks at it.
    #
    # Art does not always arrive shaped - Evil Neuro's came with the bottom
    # corners cut and the top two square - and a card with square shoulders
    # sitting next to a row of rounded ones is obvious the moment it is in a
    # hand. Doing it here rather than remembering to run the other tool means
    # no sprite can reach the game unshaped: the mask is binary and idempotent,
    # so re-running it on already-masked art changes nothing, and
    # round_corners keeps its own list of the sheets that are not card faces.
    shaped = round_corners.main(quiet=True)
    if shaped:
        print("corners: %d image(s) masked" % shaped)

    stems = collect()
    done = implemented_keys()
    placeholders = [s for s in stems if s not in done]

    # Atlases cover every image, implemented or not.
    write("jokers/atlases.lua",
          BANNER + "\n".join(ATLAS_TMPL % (s, s) for s in stems))

    roster = "".join('    { key = "%s", rarity = 1, cost = 4, mult = 4 },\n' % s
                     for s in placeholders)
    write("jokers/zz_vtubers.lua",
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
    artless = [k for k in ARTLESS_KEYS
               if k[len("j_celesta_"):] not in stems]
    for key in EXAMPLE_KEYS + ["j_celesta_" + s for s in stems] + artless:
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

        # ...and the True Star twin, built from whichever block that was.
        if key in TRUE_STAR_JOKERS or key == TRUE_STAR_WYRM:
            parts.append(true_star_block(key, parts[-1]))
            added += 1

    write("localization/en-us.lua", LOC_HEAD + "".join(parts) + LOC_TAIL)

    print("%d images | %d implemented by hand | %d placeholder jokers"
          % (len(stems), len(done), len(placeholders)))
    print("localization: %d entries preserved, %d added" % (kept, added))
    if done:
        print("implemented:", ", ".join(sorted(done)))


if __name__ == "__main__":
    main()
