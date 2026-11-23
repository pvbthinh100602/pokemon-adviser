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
| `rr_rom_tables.json` | Diagnostics: whether the script found the name tables in the ROM. |

Logged events: map changes, battle start/end (wild or trainer, opponent species and level, win/lose/run/caught), HP changes and moves used in battle, switches, faints, catches, party additions/removals, level-ups, evolutions, learned/forgotten moves, held item changes, badges, whiteouts, money changes, save state loads.

## Test these first

1. Load the script, enter the game, walk a few steps, and open `rr_rom_tables.json` to check for any `NOT FOUND`. If `species`/`moves` are NOT FOUND, the log only has numeric IDs instead of names.
2. Open `rr_snapshot.json` and compare the team with the in-game Summary screen: level, HP, moves, nature, ability.
3. Fight one wild battle (run once, catch once) and one trainer battle, and check `rr_events.jsonl` for `battle_start` / `battle_end` with the correct outcome.
4. Change maps and check for `map_change`. Map names only exist for Kanto; unknown places show as numbers.

## Notes

- Loading save states is fine: the script detects it (`state_jump` event) and re-baselines. Events right around the load may be missed.
- Some parts are still unverified against the real ROM (name-table scanning, natures after mints, badge flags, trainer names shown as IDs only). Report anything that looks wrong.
- To reduce noise (e.g. no per-hit HP logging), set `LOG_BATTLE_DETAIL = false` at the top of the file.
