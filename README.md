# pokemon-adviser

A repo for an AI agent that acts as an "adviser" while I play Pokémon. Current game: **Pokémon Radical Red v4.1** (a FireRed ROM hack), played on **mGBA 0.10.5** (Windows), Normal mode, Minimal Grinding, starter Sprigatito.

## Idea

1. `logger/rr_logger.lua` runs inside mGBA and logs the playthrough live to files (map changes, battles, catches, level-ups, evolutions, badges, team changes, ...).
2. The agent reads the log and snapshot to know where I am and what my team looks like, then gives advice: team building, type matchups, boss strategies, where to catch Pokémon or find items.
3. `progress/` keeps a summary of progress so the agent remembers across sessions.

## Layout

| Path | Contents |
|---|---|
| `AGENTS.md` | Instructions for the adviser agent (role, references, rules) |
| `logger/` | Lua script for mGBA + setup guide |
| `progress/` | Playthrough progress (badges, team, where I'm stuck) |
| `docs/references.md` | Reference sources |

## Quick logger setup

mGBA > Tools > Scripting > File > Load script > pick `logger/rr_logger.lua`. Keep the Scripting window open. Logs go to `D:/pokemon-adviser/rr-log/` by default (see `logger/README.md`).

> This repo does not contain, and will never link to, any ROM file.
