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
SHARED = {"jokers", "consumables", "decks", "icon", "seals", "driftwood_fronts", "frozen"}   # not per-joker art

# Auto title-casing cannot know how a creator styles their own name.
# Add corrections here; anything absent falls back to the mechanical rule.
DISPLAY_NAMES = {
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
    """Keys defined by hand in jokers/implemented.lua.

    Two sources, unioned:
      * `SMODS.Joker {` followed by `key = "..."` - which is why that file
        keeps `key` as the first field of every literal definition.
      * `--- IMPLEMENTED: a, b, c` comment lines, for jokers registered from a
        loop where the key is a variable and cannot be read statically.

    Missing a key here is not silent: it stays in the generated roster and
    registers a second time, which the load test catches as a duplicate.
    """
    p = os.path.join(ROOT, "jokers", "implemented.lua")
    if not os.path.exists(p):
        return set()
    src = open(p, encoding="utf-8").read()
    keys = set(re.findall(r'SMODS\.Joker\s*\{\s*key\s*=\s*["\']([^"\']+)["\']', src))
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
            c_celesta_reforge = {
                name = "Reforge",
                text = {
                    "Enhances up to {C:attention}#1#{}",
                    "selected cards to",
                    "{C:attention}Mult Cards",
                },
            },
        },

        Blind = {
            bl_celesta_clover = {
                name = "The Clover",
                text = {
                    "All listed {C:green}probabilities{}",
                    "are {C:attention}halved{}",
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
            celesta_cracked = "Cracked!",
            celesta_chipped = "Chipped!",
            celesta_stripped = "Stripped!",
            celesta_melted = "Melted!",
            celesta_snowstorm = "Snowstorm!",
            celesta_frozen = "Frozen!",
            celesta_failed = "Failed!",
            celesta_cleared = "Cleared!",
            celesta_plus_limestone = "+Limestone",
            celesta_plus_slot = "+1 Consumable Slot",
            celesta_plus_tag = "+1 Tag",
            celesta_sealed = "Sealed!",
            celesta_hearts = "All Hearts!",
            celesta_plus_seven = "+7 of Spades",
            celesta_downpour = "Downpour!",
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
