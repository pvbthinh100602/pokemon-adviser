# rr_logger – let the adviser "watch" a Radical Red playthrough

This Lua script runs inside mGBA, reads game RAM roughly every half second, and writes what it sees to files. It only reads; it never modifies the game, so saves are safe.

## Setup (once)

1. Requires **mGBA 0.10 or newer** (Help > About shows the version).
2. Logs go to `D:/pokemon-adviser/rr-log/` by default. To change that, edit the `OUT_DIR` line at the top of the `.lua` file (use `/`). Set it to `""` to write logs next to the script.
   - If the folder doesn't exist the script creates it (a black cmd window may flash for a second). If that fails, it writes next to the script.

## Every session

1. Open mGBA and load the Radical Red ROM.
2. **Tools > Scripting...**
3. In the Scripting window: **File > Load script** and pick `rr_logger.lua`.
4. **Keep the Scripting window open** (minimizing is fine). Closing it stops logging.
5. Loading the script before or after starting the game both work. On first load it scans the ROM for about a second to find Pokémon, move, ability and item names.

The console shows `[rr] {...}` lines whenever something happens, which means the script is running.

## Output files

| File | What it is |
|---|---|
| `rr_events.jsonl` | Live log, one event per line with timestamp and frame number. Append-only; safe to delete anytime. |
| `rr_snapshot.json` | Current state: team (level, HP, moves + PP, ability, nature, item, IVs/EVs), badges, location, money, play time, current opponent, last 25 events. Overwritten every few seconds. |
| `rr_rom_tables.json` | Diagnostics: name tables, plus the decoded Max Raid encounter table for every map (species per star, abilities, drops, badge-to-star and level ranges). |

Logged events: map changes, battle start/end (wild, trainer, or **raid**; opponent species and level, win/lose/run/caught), HP changes and moves used in battle, switches, faints, catches, party additions/removals, level-ups, evolutions, learned/forgotten moves, held item changes, badges, whiteouts, money changes, save state loads, and **raid_den** (species, stars, level, ability, drops, and the den's possible species) when you interact with a Max Raid den.

## Test these first

1. Load the script, enter the game, walk a few steps, and open `rr_rom_tables.json` to check for any `NOT FOUND`. If `species`/`moves` are NOT FOUND, the log only has numeric IDs instead of names.
2. Open `rr_snapshot.json` and compare the team with the in-game Summary screen: level, HP, moves, nature, ability.
3. Fight one wild battle (run once, catch once) and one trainer battle, and check `rr_events.jsonl` for `battle_start` / `battle_end` with the correct outcome.
4. Change maps and check for `map_change`. Map names only exist for Kanto; unknown places show as numbers.

## Raid dens

The script can read which Pokémon is inside a Max Raid den.

1. After updating the script, reload it in mGBA: in the **Scripting** window choose **File > Reset** (or File > Load script again). Keep the Scripting window open.
2. Interact with the den again (press A on it). Opening the den is what writes the chosen species, star count and level to RAM, and that is when a `raid_den` event is written.
3. Check `rr_events.jsonl` for a `raid_den` event and `rr_snapshot.json` for a `raid` object (current species/stars/level, plus `possible` species for that route). Raid battles are tagged `kind: "raid"` on `battle_start` / `battle_end`.

`data/raid_encounters.json` in the repo is a full dump of every den in this Radical Red 4.1 ROM (you do not need a live log to look up what a route can spawn). To regenerate it from the ROM (do not commit the ROM):

```
python logger/dev-test/dump_raid_tables.py "C:\path\to\your.gba" --json data/raid_encounters.json
```

The dump script also verifies the Route 3 1-star signature (Meowth-Galar, Fletchling, Nidoran♂, Capsakid, Tandemaus). With 1 gym badge only 1-star raids appear, at level 20–25.

RAM used (CFRU, verified in this ROM): `gRaidBattleSpecies` 0x0203E04C, `gRaidBattleStars` 0x0203E04E, `gRaidBattleLevel` 0x0203E04F. `FLAG_RAID_BATTLE` (0x919) marks a raid battle.

## Notes

- Loading save states is fine: the script detects it (`state_jump` event) and re-baselines. Events right around the load may be missed.
- Some parts are still unverified against the real ROM (name-table scanning, natures after mints, badge flags, trainer names shown as IDs only). Report anything that looks wrong.
- To reduce noise (e.g. no per-hit HP logging), set `LOG_BATTLE_DETAIL = false` at the top of the file.
