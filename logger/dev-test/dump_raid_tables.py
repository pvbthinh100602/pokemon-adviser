#!/usr/bin/env python3
"""Decode CFRU/Radical Red raid encounter tables from a FireRed-based ROM.

Usage:
    python dump_raid_tables.py "C:\\path\\to\\radical-red.gba"
    python dump_raid_tables.py "C:\\path\\to\\radical-red.gba" --json out.json

This script only reads the ROM. Do not commit or share the ROM itself.
It verifies the Route 3 1-star den against a known Radical Red v4.1 signature.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

# Confirmed in the player's Radical Red v4.1 ROM by matching Route 3 species
# and drops against radredb, and by finding the table pointer next to
# gRaidBattleSpecies (0x0203E04C) in DetermineRaidSpecies's literal pool.
HINT_TABLE = 0x1134C34
HINT_STARS_BY_BADGES = 0x1147640
HINT_LEVEL_RANGES = 0x1147654  # includes [0] = {0,0}
SPECIES_OFF, SPECIES_STRIDE, SPECIES_MAX = 0x14042CC, 11, 1375
ITEMS_OFF, ITEMS_STRIDE, ITEMS_MAX = 0x13C0000, 44, 749
BASESTATS_OFF, BASESTATS_STRIDE = 0x17B98EC, 28

MAPSEC_DYNAMIC = 0x57
MAPSEC_CELADON_DEPT = 0xC4
KANTO_MAPSEC_COUNT = MAPSEC_CELADON_DEPT - MAPSEC_DYNAMIC
RAID_STAR_COUNT = 7
RAID_STRUCT_SIZE = 30
ROW_SIZE = RAID_STAR_COUNT * 8
MAPSEC_ROUTE_3 = 0x67

# GBA / FireRed international charset
CHARS = {0x00: " "}
for i in range(10):
    CHARS[0xA1 + i] = str(i)
for i in range(26):
    CHARS[0xBB + i] = chr(65 + i)
    CHARS[0xD5 + i] = chr(97 + i)
CHARS.update({
    0xAB: "!", 0xAC: "?", 0xAD: ".", 0xAE: "-", 0xAF: "·", 0xB0: "…",
    0xB1: '"', 0xB2: '"', 0xB3: "'", 0xB4: "'", 0xB5: "♂", 0xB6: "♀",
    0xB7: "$", 0xB8: ",", 0xB9: "x", 0xBA: "/", 0xF0: ":", 0x1B: "é",
    0x2D: "&", 0x5C: "(", 0x5D: ")", 0x35: "=", 0x36: ";", 0x2E: "+",
    0x34: "Lv",
})

TYPES = {
    0: "Normal", 1: "Fighting", 2: "Flying", 3: "Poison", 4: "Ground",
    5: "Rock", 6: "Bug", 7: "Ghost", 8: "Steel", 10: "Fire", 11: "Water",
    12: "Grass", 13: "Electric", 14: "Psychic", 15: "Ice", 16: "Dragon",
    17: "Dark", 0x17: "Fairy",
}
ABILITY = {
    0: "hidden", 1: "ability_1", 2: "ability_2",
    3: "random_1_2", 4: "random_all",
}
DROP_RATES = [100, 80, 80, 50, 50, 30, 30, 25, 25, 5, 4, 1]
STAR_NAMES = ["none", "1", "2", "3", "4", "5", "6"]

# Types used to qualify regional forms whose 11-char ROM name is truncated
# to the base species name (e.g. all Meowth forms are stored as "Meowth").
FORM_BY_NAME_TYPES = {
    ("Meowth", "Dark"): "Meowth-Alola",
    ("Meowth", "Steel"): "Meowth-Galar",
    ("Persian", "Dark"): "Persian-Alola",
    ("Rattata", "Dark"): "Rattata-Alola",
    ("Raticate", "Dark"): "Raticate-Alola",
    ("Raichu", "Electric"): "Raichu-Alola",  # Electric/Psychic; see qualifier
    ("Sandshrew", "Ice"): "Sandshrew-Alola",
    ("Sandslash", "Ice"): "Sandslash-Alola",
    ("Vulpix", "Ice"): "Vulpix-Alola",
    ("Ninetales", "Ice"): "Ninetales-Alola",
    ("Geodude", "Electric"): "Geodude-Alola",
    ("Graveler", "Electric"): "Graveler-Alola",
    ("Golem", "Electric"): "Golem-Alola",
    ("Grimer", "Poison"): "Grimer-Alola",  # Poison/Dark
    ("Muk", "Poison"): "Muk-Alola",
    ("Exeggutor", "Grass"): "Exeggutor-Alola",  # Grass/Dragon
    ("Marowak", "Fire"): "Marowak-Alola",
    ("Ponyta", "Psychic"): "Ponyta-Galar",
    ("Rapidash", "Psychic"): "Rapidash-Galar",
    ("Slowpoke", "Psychic"): "Slowpoke-Galar",
    ("Farfetch'd", "Fighting"): "Farfetch'd-Galar",
    ("Weezing", "Poison"): "Weezing-Galar",  # Poison/Fairy
    ("Zigzagoon", "Dark"): "Zigzagoon-Galar",
    ("Linoone", "Dark"): "Linoone-Galar",
    ("Growlithe", "Fire"): "Growlithe-Hisui",  # Fire/Rock
    ("Arcanine", "Fire"): "Arcanine-Hisui",
    ("Voltorb", "Electric"): "Voltorb-Hisui",  # Electric/Grass
    ("Typhlosion", "Fire"): "Typhlosion-Hisui",  # Fire/Ghost
    ("Qwilfish", "Dark"): "Qwilfish-Hisui",
    ("Sneasel", "Fighting"): "Sneasel-Hisui",
    ("Zorua", "Normal"): "Zorua-Hisui",
    ("Zoroark", "Normal"): "Zoroark-Hisui",
}

MAPSEC_NAMES = {
    0x58: "Pallet Town", 0x59: "Viridian City", 0x5A: "Pewter City",
    0x5B: "Cerulean City", 0x5C: "Lavender Town", 0x5D: "Vermilion City",
    0x5E: "Celadon City", 0x5F: "Fuchsia City", 0x60: "Cinnabar Island",
    0x61: "Indigo Plateau", 0x62: "Saffron City", 0x63: "Route 4",
    0x64: "Route 10", 0x7E: "Viridian Forest", 0x7F: "Mt. Moon",
    0x80: "S.S. Anne", 0x81: "Underground Path", 0x82: "Underground Path",
    0x83: "Diglett's Cave", 0x84: "Victory Road", 0x85: "Rocket Hideout",
    0x86: "Silph Co.", 0x87: "Pokemon Mansion", 0x88: "Safari Zone",
    0x89: "Pokemon League", 0x8A: "Rock Tunnel", 0x8B: "Seafoam Islands",
    0x8C: "Pokemon Tower", 0x8D: "Cerulean Cave", 0x8E: "Power Plant",
    0xC4: "Celadon Dept.",
}
for i in range(1, 26):
    MAPSEC_NAMES[0x64 + i] = "Route %d" % i

# Route 3 1-star: Galarian Meowth, Fletchling, Nidoran-M, Capsakid, Tandemaus
# (matches radredb and this ROM's drop lists, including Tandemaus's empty 50% slot).
EXPECTED_ROUTE3_1STAR_IDS = [1208, 769, 32, 1327, 1330]


def decode_text(raw: bytes) -> str | None:
    out = []
    for b in raw:
        if b == 0xFF:
            break
        c = CHARS.get(b)
        if c is None:
            return None
        out.append(c)
    s = "".join(out).strip()
    return s or None


def load_names(data: bytes, off: int, stride: int, name_len: int, max_id: int) -> dict[int, str]:
    names = {}
    for i in range(max_id + 1):
        start = off + i * stride
        if start + name_len > len(data):
            break
        n = decode_text(data[start:start + name_len])
        if n:
            names[i] = n
    return names


def mon_types(data: bytes, sid: int) -> tuple[str | None, str | None]:
    base = BASESTATS_OFF + sid * BASESTATS_STRIDE
    if base + 8 > len(data):
        return None, None
    t1, t2 = data[base + 6], data[base + 7]
    return TYPES.get(t1, str(t1)), TYPES.get(t2, str(t2))


def qualify_name(raw_name: str, sid: int, data: bytes, first_id_for_name: dict[str, int]) -> str:
    t1, t2 = mon_types(data, sid)
    key = (raw_name, t1)
    if sid != first_id_for_name.get(raw_name, sid):
        alias = FORM_BY_NAME_TYPES.get(key)
        if alias:
            # Raichu-Alola is Electric/Psychic (vanilla Raichu is Electric).
            if raw_name == "Raichu" and t2 != "Psychic":
                alias = None
            # Grimer/Muk-Alola are Poison/Dark.
            if raw_name in ("Grimer", "Muk") and t2 != "Dark":
                alias = None
            # Exeggutor-Alola is Grass/Dragon.
            if raw_name == "Exeggutor" and t2 != "Dragon":
                alias = None
            # Growlithe/Arcanine-Hisui are Fire/Rock.
            if raw_name in ("Growlithe", "Arcanine") and t2 != "Rock":
                alias = None
            # Voltorb-Hisui is Electric/Grass.
            if raw_name == "Voltorb" and t2 != "Grass":
                alias = None
            # Weezing-Galar is Poison/Fairy.
            if raw_name == "Weezing" and t2 != "Fairy":
                alias = None
        if alias:
            return alias
        typ = t1 if (not t2 or t2 == t1) else f"{t1}/{t2}"
        return f"{raw_name} ({typ})" if typ else raw_name
    return raw_name


def rom_offset(ptr: int, rom_size: int) -> int | None:
    if 0x08000000 <= ptr < 0x08000000 + rom_size:
        return ptr - 0x08000000
    return None


def parse_raid(data: bytes, off: int):
    sid, item, ability = struct.unpack_from("<HHB", data, off)
    drops = [struct.unpack_from("<H", data, off + 6 + i * 2)[0] for i in range(12)]
    return sid, item, ability, drops


def find_table_base(data: bytes) -> int:
    """Prefer the hinted offset; fall back to finding the Route 3 pointer."""
    # Signature: five 30-byte records starting with the known species ids.
    sig = b"".join(struct.pack("<H", sid) + b"\x00" * 28 for sid in EXPECTED_ROUTE3_1STAR_IDS)
    # That's too strict (item/ability/drops fill the 28 bytes). Just find first species
    # and check the stride.
    first = struct.pack("<H", EXPECTED_ROUTE3_1STAR_IDS[0])
    start = 0
    array_off = None
    while True:
        p = data.find(first, start)
        if p < 0:
            break
        ok = True
        for i, sid in enumerate(EXPECTED_ROUTE3_1STAR_IDS):
            got = struct.unpack_from("<H", data, p + i * RAID_STRUCT_SIZE)[0]
            if got != sid:
                ok = False
                break
        if ok:
            array_off = p
            break
        start = p + 1
    if array_off is None:
        raise SystemExit("Could not find the Route 3 1-star raid array in this ROM.")

    ptr = struct.pack("<I", 0x08000000 + array_off)
    # The Route 3 1-star RaidData slot is at table + (0x10 * 56) + 8
    route3_index = MAPSEC_ROUTE_3 - MAPSEC_DYNAMIC
    slot_rel = route3_index * ROW_SIZE + 8
    hits = []
    s = 0
    while True:
        h = data.find(ptr, s)
        if h < 0:
            break
        amount = struct.unpack_from("<H", data, h + 4)[0]
        if amount == 5:
            hits.append(h)
        s = h + 1
    if not hits:
        raise SystemExit("Found the Route 3 array but no gRaidsByMapSection pointer to it.")
    # The first 1-star slot (not later star copies) is the one whose offset
    # minus slot_rel is aligned and looks like a table of pointers.
    for h in hits:
        base = h - slot_rel
        if base >= 0 and (base % 4 == 0):
            # star 0 should be empty for Route 3
            p0, a0 = struct.unpack_from("<IH", data, base + route3_index * ROW_SIZE)
            if p0 == 0 and a0 == 0:
                return base
    return hits[0] - slot_rel


def decode_rom(data: bytes, table_base: int | None = None) -> dict:
    species = load_names(data, SPECIES_OFF, SPECIES_STRIDE, 11, SPECIES_MAX)
    items = load_names(data, ITEMS_OFF, ITEMS_STRIDE, 20, ITEMS_MAX)
    first_id = {}
    for sid, name in species.items():
        first_id.setdefault(name, sid)

    if table_base is None:
        table_base = find_table_base(data)

    # Stars-by-badges / level ranges: verify the known RR 4.1 pattern, else search.
    stars_off = HINT_STARS_BY_BADGES
    expected_stars = bytes([0, 0, 1, 1, 1, 2, 2, 2, 2, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6])
    if data[stars_off:stars_off + 20] != expected_stars:
        p = data.find(expected_stars)
        stars_off = p if p >= 0 else None
    level_off = (stars_off + 20) if stars_off is not None else None
    # RR 4.1: {0,0},{20,25},{28,32},{44,50},{59,68},{75,80},{80,90}
    expected_levels = bytes([0, 0, 20, 25, 28, 32, 44, 50, 59, 68, 75, 80, 80, 90])
    if level_off is None or data[level_off:level_off + 14] != expected_levels:
        p = data.find(expected_levels)
        level_off = p if p >= 0 else None

    stars_by_badges = {}
    if stars_off is not None:
        for b in range(10):
            lo, hi = data[stars_off + b * 2], data[stars_off + b * 2 + 1]
            stars_by_badges[str(b)] = [lo, hi]
    level_ranges = {}
    if level_off is not None:
        for s in range(7):
            lo, hi = data[level_off + s * 2], data[level_off + s * 2 + 1]
            if s == 0:
                continue
            level_ranges[str(s)] = [lo, hi]

    dens = []
    for i in range(KANTO_MAPSEC_COUNT):
        mapsec = MAPSEC_DYNAMIC + i
        stars = {}
        pointers = {}
        for star in range(1, RAID_STAR_COUNT):
            eoff = table_base + i * ROW_SIZE + star * 8
            ptr, amount = struct.unpack_from("<IH", data, eoff)
            off = rom_offset(ptr, len(data))
            if not off or amount == 0 or amount > 40:
                continue
            pointers[str(star)] = off
            raids = []
            for n in range(amount):
                sid, item, ability, drops = parse_raid(data, off + n * RAID_STRUCT_SIZE)
                if sid == 0 or sid > SPECIES_MAX:
                    break
                raw = species.get(sid, "#%d" % sid)
                t1, t2 = mon_types(data, sid)
                types = [t1] if t1 else []
                if t2 and t2 != t1:
                    types.append(t2)
                raids.append({
                    "species_id": sid,
                    "species": qualify_name(raw, sid, data, first_id),
                    "types": types,
                    "held_item_id": item or None,
                    "held_item": items.get(item) if item else None,
                    "ability": ABILITY.get(ability, "ability_%d" % ability),
                    "ability_code": ability,
                    "drops": [
                        {"item_id": d, "item": items.get(d), "rate_percent": DROP_RATES[j]}
                        for j, d in enumerate(drops) if d
                    ],
                })
            if raids:
                stars[str(star)] = raids
        if stars:
            dens.append({
                "mapsec": mapsec,
                "mapsec_hex": "0x%02X" % mapsec,
                "name": MAPSEC_NAMES.get(mapsec, "mapsec_%d" % mapsec),
                "stars": stars,
                "shared_pool_across_stars": len(set(pointers.values())) == 1,
            })

    return {
        "source": (
            "Decoded from a Radical Red v4.1 CFRU ROM (gRaidsByMapSection). "
            "Verified against the Route 3 1-star den (species and drops). "
            "The ROM itself is not included in this repository."
        ),
        "rom_offsets": {
            "gRaidsByMapSection": "0x%X" % table_base,
            "gRaidBattleStarsByBadges": ("0x%X" % stars_off) if stars_off is not None else None,
            "gRaidBattleLevelRanges": ("0x%X" % level_off) if level_off is not None else None,
            "gRaidBattleSpecies_ram": "0x0203E04C",
            "gRaidBattleStars_ram": "0x0203E04E",
            "gRaidBattleLevel_ram": "0x0203E04F",
        },
        "raid_struct_size": RAID_STRUCT_SIZE,
        "stars_by_badge_count": stars_by_badges,
        "level_ranges_by_stars": level_ranges,
        "egg_move_chance_by_stars": {"1": 0, "2": 10, "3": 30, "4": 50, "5": 70, "6": 70},
        "raid_ability": ABILITY,
        "drop_rates_percent": DROP_RATES,
        "notes": [
            "Some dens reuse the same species list for every star tier; the battle level still follows level_ranges_by_stars.",
            "ROM species names are at most 10 characters, so regional forms share the base name. This dump adds a form label when types identify the form (e.g. Meowth-Galar is Steel).",
            "After the player interacts with a den, the chosen species, stars and level are written to the RAM addresses above.",
            "With 1 gym badge only 1-star raids can appear (level 20-25 in this ROM).",
        ],
        "dens": dens,
    }


def verify_route3(decoded: dict) -> list[str]:
    errors = []
    route3 = next((d for d in decoded["dens"] if d["mapsec"] == MAPSEC_ROUTE_3), None)
    if not route3:
        return ["Route 3 den not found in the table"]
    one = route3["stars"].get("1") or []
    ids = [r["species_id"] for r in one]
    if ids != EXPECTED_ROUTE3_1STAR_IDS:
        errors.append("Route 3 1-star species ids %s != expected %s" % (ids, EXPECTED_ROUTE3_1STAR_IDS))
    names = [r["species"] for r in one]
    if "Meowth-Galar" not in names:
        errors.append("Route 3 1-star did not qualify species 1208 as Meowth-Galar (got %s)" % names)
    if one and one[0]["drops"]:
        first_items = [d["item"] for d in one[0]["drops"][:3]]
        if first_items != ["Oran Berry", "Stardust", "Muscle Wing"]:
            errors.append("Route 3 first drops were %s" % first_items)
    # Tandemaus 4th drop is empty, 6th is Sitrus Berry
    tan = next((r for r in one if r["species_id"] == 1330), None)
    if tan:
        items = [d["item"] for d in tan["drops"]]
        if "Berry Juice" in items:
            errors.append("Tandemaus should not have Berry Juice (that's the other four)")
        if "Sitrus Berry" not in items:
            errors.append("Tandemaus missing Sitrus Berry drop")
    return errors


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("rom", help="Path to the Radical Red / FireRed-based .gba (not committed)")
    p.add_argument("--json", help="Write the full decoded table as JSON")
    p.add_argument("--table-offset", type=lambda s: int(s, 0), default=None,
                   help="Override gRaidsByMapSection file offset")
    args = p.parse_args(argv)

    rom_path = Path(args.rom)
    data = rom_path.read_bytes()
    table_base = args.table_offset
    if table_base is None:
        # Try the hint first, then discover.
        try:
            # Quick hint check: Route 3 star 1 amount == 5 and first id matches
            eoff = HINT_TABLE + (MAPSEC_ROUTE_3 - MAPSEC_DYNAMIC) * ROW_SIZE + 8
            ptr, amount = struct.unpack_from("<IH", data, eoff)
            off = rom_offset(ptr, len(data))
            first = struct.unpack_from("<H", data, off)[0] if off else None
            if amount == 5 and first == EXPECTED_ROUTE3_1STAR_IDS[0]:
                table_base = HINT_TABLE
        except Exception:
            table_base = None
        if table_base is None:
            table_base = find_table_base(data)

    decoded = decode_rom(data, table_base)
    errors = verify_route3(decoded)
    route3 = next((d for d in decoded["dens"] if d["mapsec"] == MAPSEC_ROUTE_3), None)

    print("ROM size: %d" % len(data))
    print("gRaidsByMapSection: %s" % decoded["rom_offsets"]["gRaidsByMapSection"])
    print("Stars by badges: %s" % decoded["stars_by_badge_count"])
    print("Level ranges: %s" % decoded["level_ranges_by_stars"])
    print("Dens found: %d" % len(decoded["dens"]))
    if route3:
        print("Route 3 (mapsec 0x67) shared_pool=%s" % route3["shared_pool_across_stars"])
        for star, raids in route3["stars"].items():
            label = ", ".join("%s (#%d, %s)" % (r["species"], r["species_id"], "/".join(r["types"])) for r in raids)
            print("  %s-star: %s" % (star, label))
    if errors:
        print("VALIDATION FAILED:")
        for e in errors:
            print("  -", e)
        return 1
    print("VALIDATION OK: Route 3 1-star species and drops match the RR 4.1 signature.")

    if args.json:
        Path(args.json).write_text(json.dumps(decoded, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("Wrote", args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())