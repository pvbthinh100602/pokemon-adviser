#!/usr/bin/env python3
"""Decode CFRU/Radical Red raid partner tables from a FireRed-based ROM.

Usage:
    python dump_raid_partners.py "C:\\path\\to\\radical-red.gba"
    python dump_raid_partners.py "C:\\path\\to\\radical-red.gba" --json out.json

Reads the ROM only. Do not commit or share the ROM itself.
Verifies the RR 4.1 signature: gNumRaidPartners == 8, first partner is Mahina,
and her 1-star lead is Foongus.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

HINT_PARTNERS = 0x1134178
HINT_NUM = 0x1134176  # u8 gNumRaidPartners, immediately before the table
PARTNER_SIZE = 60
SPREAD_SIZE = 28
RAID_STAR_COUNT = 7
SPECIES_OFF, SPECIES_STRIDE, SPECIES_MAX = 0x14042CC, 11, 1375
MOVES_OFF, MOVES_STRIDE, MOVES_MAX = 0x10F3188, 13, 2046
ITEMS_OFF, ITEMS_STRIDE, ITEMS_MAX = 0x13C0000, 44, 749
ABIL_OFF, ABIL_STRIDE, ABIL_MAX = 0x10E32C0, 17, 1022
BASESTATS_OFF, BASESTATS_STRIDE = 0x17B98EC, 28

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
NATURES = [
    "Hardy", "Lonely", "Brave", "Adamant", "Naughty", "Bold", "Docile",
    "Relaxed", "Impish", "Lax", "Timid", "Hasty", "Serious", "Jolly",
    "Naive", "Modest", "Mild", "Quiet", "Bashful", "Rash", "Calm",
    "Gentle", "Sassy", "Careful", "Quirky",
]
ABILITY_SLOT = {0: "hidden", 1: "ability_1", 2: "ability_2", 3: "random_1_2"}
# Move names that are useful vs a Steel target, used only for tagging.
STEEL_WEAK_MOVE_HINTS = (
    "fire", "flame", "flare", "overheat", "heat", "blast burn", "erupt",
    "brick", "close combat", "aura", "focus punch", "low kick", "low sweep",
    "double kick", "karate", "cross chop", "superpower", "drain punch",
    "earthquake", "earth power", "bulldoze", "stomping", "high horse",
    "mud bomb", "mud shot", "magnitude", "drill run", "scorch", "will-o-wisp",
    "will o", "sacred fire", "blue flare", "v-create", "searing",
    "bad tantrum",  # RR name in this ROM (Onix 1-star); treat as a Ground-like option
)


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


def rom_off(ptr: int, size: int) -> int | None:
    if 0x08000000 <= ptr < 0x08000000 + size:
        return ptr - 0x08000000
    return None


def mon_info(data: bytes, sid: int, abil: dict[int, str]):
    base = BASESTATS_OFF + sid * BASESTATS_STRIDE
    t1, t2 = data[base + 6], data[base + 7]
    a1, a2, ah = data[base + 0x16], data[base + 0x17], data[base + 0x1A]
    types = [TYPES.get(t1, str(t1))]
    if t2 != t1:
        types.append(TYPES.get(t2, str(t2)))
    return types, {
        "ability_1": abil.get(a1),
        "ability_2": abil.get(a2) if a2 else None,
        "hidden": abil.get(ah) if ah else None,
        "ids": [a1, a2, ah],
    }


def resolve_ability(slot: int, slots: dict) -> str | None:
    if slot == 0:
        return slots["hidden"] or slots["ability_1"]
    if slot == 1:
        return slots["ability_1"]
    if slot == 2:
        return slots["ability_2"] or slots["ability_1"]
    return None


def parse_spread(data: bytes, off: int, names) -> dict:
    species, moves, items, abil = names
    sid, nature, ball = struct.unpack_from("<HBB", data, off)
    item = struct.unpack_from("<H", data, off + 14)[0]
    mv = list(struct.unpack_from("<4H", data, off + 16))
    flags = data[off + 25]
    slot = (flags >> 4) & 3
    types, slots = mon_info(data, sid, abil)
    ability_name = resolve_ability(slot, slots)
    move_names = [moves.get(m, "#%d" % m) for m in mv if m]
    return {
        "species_id": sid,
        "species": species.get(sid, "#%d" % sid),
        "types": types,
        "nature": NATURES[nature] if nature < len(NATURES) else str(nature),
        "item_id": item or None,
        "item": items.get(item) if item else None,
        "ability": ability_name,
        "ability_slot": ABILITY_SLOT.get(slot, str(slot)),
        "ability_code": slot,
        "moves": [{"id": m, "name": moves.get(m, "#%d" % m)} for m in mv if m],
        "good_vs_steel": is_good_vs_steel(types, move_names),
    }


def is_good_vs_steel(types: list[str], move_names: list[str]) -> list[str]:
    reasons = []
    for t in types:
        if t in ("Fire", "Fighting", "Ground"):
            reasons.append("stab_%s" % t.lower())
    for n in move_names:
        low = n.lower()
        if any(h in low for h in STEEL_WEAK_MOVE_HINTS):
            reasons.append("move:%s" % n)
    return reasons


def decode_rom(data: bytes) -> dict:
    species = load_names(data, SPECIES_OFF, SPECIES_STRIDE, 11, SPECIES_MAX)
    moves = load_names(data, MOVES_OFF, MOVES_STRIDE, 13, MOVES_MAX)
    items = load_names(data, ITEMS_OFF, ITEMS_STRIDE, 20, ITEMS_MAX)
    abil = load_names(data, ABIL_OFF, ABIL_STRIDE, 17, ABIL_MAX)
    names = (species, moves, items, abil)

    n = data[HINT_NUM]
    partners = []
    for i in range(n):
        off = HINT_PARTNERS + i * PARTNER_SIZE
        ow, tclass, back, gender = struct.unpack_from("<HBBB", data, off)
        otid = struct.unpack_from("<I", data, off + 8)[0]
        namep = struct.unpack_from("<I", data, off + 12)[0]
        noff = rom_off(namep, len(data))
        name = decode_text(data[noff:noff + 16]) if noff else None
        sizes = list(struct.unpack_from("<7H", data, off + 44))
        stars = {}
        for star in range(1, RAID_STAR_COUNT):
            sp = struct.unpack_from("<I", data, off + 16 + star * 4)[0]
            soff = rom_off(sp, len(data)) if sp else None
            sz = sizes[star]
            if not soff or sz == 0:
                continue
            team = [parse_spread(data, soff + k * SPREAD_SIZE, names) for k in range(sz)]
            stars[str(star)] = team
        partners.append({
            "id": i,
            "name": name,
            "trainer_class": tclass,
            "gender": "female" if gender == 1 else "male",
            "ow_num": ow,
            "back_sprite": back,
            "stars": stars,
        })
    return {
        "source": (
            "Decoded from a Radical Red v4.1 CFRU ROM (gRaidPartners at 0x1134178, "
            "gNumRaidPartners = 8 at 0x1134176). The ROM itself is not in this repository."
        ),
        "rom_offsets": {
            "gRaidPartners": "0x%X" % HINT_PARTNERS,
            "gNumRaidPartners": "0x%X" % HINT_NUM,
            "sRaidBattleIntroPtr_ram": "0x0203E038",
        },
        "struct_sizes": {"MultiRaidTrainer": PARTNER_SIZE, "BattleTowerSpread": SPREAD_SIZE},
        "notes": [
            "The raid intro screen shows 3 partners chosen at random from those who have a spread for the current star level. Live candidates live in the RaidBattleIntro struct pointed to by 0x0203E038 while that screen is open.",
            "Partner Pokemon are built at GetRandomRaidLevel() (the star's level range; 20-25 for 1-star in this ROM).",
            "Ability slot 0 = hidden, 1 = first ability, 2 = second ability (same encoding as raid dens).",
        ],
        "count": n,
        "partners": partners,
    }


def verify(decoded: dict) -> list[str]:
    err = []
    if decoded["count"] != 8:
        err.append("expected 8 partners, got %s" % decoded["count"])
    p0 = decoded["partners"][0] if decoded["partners"] else None
    if not p0 or p0["name"] != "Mahina":
        err.append("first partner is %s, expected Mahina" % (p0 and p0["name"]))
    else:
        team = p0["stars"].get("1") or []
        if not team or team[0]["species"] != "Foongus":
            err.append("Mahina 1-star lead is %s, expected Foongus" % (team[0]["species"] if team else None))
    names = [p["name"] for p in decoded["partners"]]
    for need in ("Xan", "Alford", "Jax", "Gold", "May", "Lance"):
        if need not in names:
            err.append("missing partner %s" % need)
    return err


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("rom")
    p.add_argument("--json")
    args = p.parse_args(argv)
    data = Path(args.rom).read_bytes()
    decoded = decode_rom(data)
    errors = verify(decoded)
    print("gRaidPartners: %s  count=%s" % (decoded["rom_offsets"]["gRaidPartners"], decoded["count"]))
    for partner in decoded["partners"]:
        one = partner["stars"].get("1")
        if not one:
            print("  %s: no 1-star team (available stars: %s)" % (partner["name"], ",".join(partner["stars"])))
            continue
        bits = []
        for mon in one:
            tag = " *" if mon["good_vs_steel"] else ""
            bits.append("%s (%s, %s, %s)%s" % (
                mon["species"], "/".join(mon["types"]), mon["ability"] or "?", mon["item"] or "no item", tag))
        print("  %s 1-star: %s" % (partner["name"], "; ".join(bits)))
    print("\n* = Fire/Fighting/Ground STAB or a move that looks super-effective vs Steel")
    if errors:
        print("VALIDATION FAILED:")
        for e in errors:
            print(" -", e)
        return 1
    print("VALIDATION OK")
    if args.json:
        Path(args.json).write_text(json.dumps(decoded, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("Wrote", args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())