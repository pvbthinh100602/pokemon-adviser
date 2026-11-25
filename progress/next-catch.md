# Next catch plan — after Brock, before Mt. Moon

Date: 25 Nov 2026 (Asia/Saigon)

This is a time-boxed plan to catch **one** fourth team member before Super Nerd Miguel and Rocket Admin Archer. Do not catch whatever appears in the grass.

## Current team and constraints

- Sprigatito Lv15, Jolly, Overgrow — Quick Attack / Tail Whip / Razor Leaf / Bite
- Numel Lv14, Modest, Simple — Growl / Magnitude / Ember / Focus Energy
- Phanpy Lv13, Adamant, Pickup — Rapid Spin / Ice Shard / Defense Curl / Rollout
- Mode: Normal, Minimal Grinding (IVs already maxed). Natures can be changed for free.
- Auto difficulty: bag items cannot be used in trainer battles. Heal at a Pokémon Center before bosses.
- Keep Phanpy's item slot empty so Pickup can recycle Berry Juice mid-battle.
- Level caps: Mt. Moon bosses 22, Cerulean / Bugsy / Misty 27.

## Why this catch (team gaps)

The party already has Grass plus two Ground types. The holes that matter for the next fights are:

- **Fighting**, for Archer's Mightyena and Houndour, Miguel's Simple + Curse Bibarel, and the Cerulean rival's Pawniard (Dark/Steel, 4× Fighting).
- **Fairy**, the only super-effective type into Miguel's stall Sableye (Will-O-Wisp / Recover / Protect / Foul Play).
- **A switch-in that can take Ice**, because Misty's first three Pokémon all carry Ice coverage (Ice Punch, Icy Wind, Aurora Beam). Sprigatito and Numel do not want to eat those.

Electric is useful later against Misty's Water types, but it is **not** the next catch: the Electric encounters on this path are on Route 4, after Mt. Moon, and Misty's fourth Pokémon is Clodsire (Poison/Ground, Water Absorb), which is immune to Electric. Sprigatito already hits Clodsire 4× with Razor Leaf.

## Upcoming bosses (from the Normal Minimal Grinding dump)

Verify in `data/trainers_4_1_normal_mingrind.txt` before the fight. After the fight, compare logged abilities and items.

### Super Nerd Miguel — Mt. Moon B2F, cap 22 (id `0xaa`)

All four are `Max Level - 3` (treat as 19 if the cap is 22; dump "Max Level" checks are not 100% accurate).

| Pokémon | Ability | Item | Nature | Moves |
| --- | --- | --- | --- | --- |
| Thwackey | Overgrow | Eviolite | Adamant | Fake Out, Razor Leaf, Knock Off, U-turn |
| Voltorb-Hisui | Reckless | Focus Sash | Naive | Magical Leaf, Self-Destruct, Shock Wave, Hidden Power Ice |
| Bibarel | Simple | Grassy Seed | Careful | Quick Attack, Aqua Jet, Curse, Rock Smash |
| Sableye | Frisk | Sitrus Berry | Careful | Will-O-Wisp, Recover, Protect, Foul Play |

Bibarel is the sweep risk: Simple doubles Curse, then priority Aqua Jet / Quick Attack. Knock it out or phaze it before it sets up. Sableye walls most Fighting moves; Numel's Ember still chips it (special, so a burn does not cut the damage, and Foul Play is weak against Modest Numel's low Attack).

### Rocket Admin Archer — Mt. Moon B2F, cap 22 (id `0x2e`)

This is the Mt. Moon fight (fixed levels 18–21). Do **not** use Archer id `0x2a` (Lv85 late-game team) or the later Archer ids.

| Pokémon | Ability | Item | Nature | Moves |
| --- | --- | --- | --- | --- |
| Glimmet Lv18 | Toxic Debris | Shuca Berry | Timid | Ancient Power, Venoshock, Mud Shot, Protect |
| Houndour Lv19 | Unnerve | Wise Glasses | Timid | Incinerate, Snarl, Protect, Hidden Power Grass |
| Mightyena Lv21 | Strong Jaw | Berry Juice | Jolly | Bite, Ice Fang, Howl, Fire Fang |

Numel / Phanpy hit Glimmet 4× Ground (Shuca Berry halves the first Ground hit). Hidden Power Grass is aimed at Ground types. Mightyena's Ice Fang + Fire Fang threatens the current three: Sprigatito is weak to all three STABs, Phanpy is weak to Ice and Fire, Numel resists Fire but is weak to Ice. Fighting or Fairy is the clean answer. Unnerve stops berry consumption (including Berry Juice on Mightyena's side, and any berry on ours). Pickup can still recycle a consumed Berry Juice after Mightyena drinks it — keep Phanpy's item slot empty.

### Cerulean rival — doubles, cap 27 (Rival Terry ids `0x14c` / `0x14d` / `0x14e`)

Shared core: Kirlia @ Sitrus (Trace; Psybeam / Drain Kiss / Magical Leaf), Staravia @ Muscle Band (Intimidate; Pluck / Quick Attack / U-turn / Sleep Talk), Pawniard @ Chople Berry (Defiant; Knock Off / Sucker Punch / Cut / Low Sweep). The fourth mon depends on the rival's starter: Wartortle, Ivysaur, or Charmeleon, all @ Eviolite. Which starter the rival has in this run was not verified. Pawniard is 4× Fighting; Chople Berry halves the first Fighting hit.

### Bugsy — Route 25, optional, cap 27 (id `0x2f`)

Lokix @ SilverPowder (Tinted Lens; First Impression, Knock Off, U-turn, Leech Life), Ledian @ Focus Sash (Iron Fist; Drain Punch, Mach Punch, Ice Punch, Thunder Punch), Scyther @ Charti Berry (Technician; Bug Bite, Swords Dance, Rock Smash, Aerial Ace), Scizor @ Sitrus (Technician; Bullet Punch, U-turn, Rock Smash, Aerial Ace). Levels are `Max Level - 2`. Tracker documents this fight as **permanent rain**; the dump does not list field effects. Numel is 4× weak to Water, and rain makes that worse. This fight can wait until after a plan is written.

### Misty — Cerulean Gym, cap 27 (id `0x19f`)

**Not** the Lanturn set that older notes assumed. The Normal Minimal Grinding dump is:

| Pokémon | Ability | Item | Nature | Moves |
| --- | --- | --- | --- | --- |
| Frogadier Lv25 | Torrent | Eviolite | Lonely | Ice Punch, Rock Tomb, Flip Turn, Grass Knot |
| Floatzel Lv25 | Water Veil | Mystic Water | Timid | Water Pulse, Flip Turn, Icy Wind, Hidden Power Grass |
| Starmie Lv27 | Analytic | Sitrus Berry | Timid | Psyshock, Water Pulse, Recover, Aurora Beam |
| Clodsire Lv26 | Water Absorb | Iapapa Berry | Bold | Poison Jab, Bulldoze, Rock Tomb, Recover |

Grass hits all four (Clodsire 4×). Electric hits the three Water types and does nothing to Clodsire (Ground). Ice coverage is on Frogadier, Floatzel, and Starmie — not on Clodsire. radicalredtracker lists Frogadier as Protean and Floatzel as Technician; the dump says Torrent and Water Veil. Use the dump until the logger confirms otherwise. Ignore Misty ids `0x20` and `0x30` (rematch / postgame teams).

## The pick

| Rank | Target | Where | Rate | When |
| --- | --- | --- | --- | --- |
| **Primary** | **Timburr** | Mt. Moon 1F | **10%**, Lv12–14 | **Day only** (4:00–20:00 in-game) |
| Backup 1 | Makuhita | Mt. Moon 1F | **10%** (two 5% slots), Lv12–14 | **Day only** (same floor) |
| Backup 2 | Tinkatink | Mt. Moon B1F | **6%**, Lv12–14 | Day or night |

Do not spend dedicated hunt time on Route 3. Walk it for the Dynamax Band, trainers, and items, then go into the cave.

### Primary — Timburr (Fighting)

Best immediate attacker for the two cap-22 bosses. Base 80 Attack and 75 HP already as a first stage, so it contributes at cap 22, then becomes Gurdurr at **level 25** (before Misty). Conkeldurr needs a Link Cable later; do not wait for that.

- **Why it fits:** Low Kick / Wake-Up Slap hit Bibarel, Mightyena, Houndour, and Glimmet (Fighting 2× Rock). Rock Throw at Lv16 is a non-Fighting move that can actually damage Sableye. Same typing also 4×s the rival's Pawniard (after Chople Berry).
- **Nature:** Adamant (change it for free if needed).
- **Ability:** Guts or Sheer Force are both fine. Iron Fist is the hidden ability (Radical Red Atlas); take it if DexNav shows it, but do not hunt it for long. romhackdex lists the three abilities in a different order; treat Iron Fist as the HA unless the logger later says otherwise.
- **Moves by cap 22 / 27:** Low Kick (Lv12), Rock Throw (Lv16), Wake-Up Slap (Lv20), Chip Away (Lv24). TM78 Low Sweep is on Mt. Moon B2F; Muscle Band is on 1F (top-right, from an NPC). Egg moves include Mach Punch and Drain Punch — if DexNav previews either one, take that Timburr immediately. Later TMs (Ice Punch, Thunder Punch, Drain Punch as a TM) may not be in hand yet; do not plan the Mt. Moon fights around them.
- **DexNav:** Register Timburr after the first random encounter (10% in day grass, usually not long). Hidden ability is optional. Prefer Iron Fist or an egg move if it appears in the preview; otherwise take Guts or Sheer Force and stop.

### Backup 1 — Makuhita (Fighting)

Same floor and time of day as Timburr, so this is the first fallback with no travel. Weaker and frailer than Timburr until it evolves, but the utility is unique.

- **Why it fits:** Fake Out (Lv10), Whirlwind (Lv16) to phaze Curse Bibarel, Knock Off (Lv19), Force Palm (Lv13). Evolves into **Hariyama at level 24**. **Thick Fat** (regular ability) cuts Fire and Ice, which helps vs Mightyena's fangs and Misty's Ice coverage. Guts is the other regular ability; Sheer Force is the HA (skip a long HA hunt).
- **Nature:** Adamant.
- **Ability priority:** Thick Fat > Guts. Do not spend extra time on Sheer Force.
- **Rate note:** Atlas lists two Day 5% slots on Mt. Moon 1F; that matches the 10% total on radicalredtracker and romhackguides.

### Backup 2 — Tinkatink (Fairy / Steel)

The Sableye answer and a later Misty pivot. Go here if day hunting on 1F fails, or if it is night and you do not want to wait for Timburr.

- **Why it fits:** Fairy is super-effective on Sableye and Mightyena. The typing resists almost all of Miguel's kit (Grass, Dark, Bug, Ice, Normal Self-Destruct); Will-O-Wisp is the danger (Fire 2× Steel). After Mt. Moon, it evolves into **Tinkatuff at level 23** (Radical Red Atlas; vanilla is 24). Tinkatuff resists both Ice and Water, so it can switch into Misty even though it does not hit Water super-effectively. Tinkaton is at 36, after this cap window. Early offenses are modest (base 45 Attack): Covet, Metal Claw, Drain Kiss, Fairy Wind. Play Rough is not until Lv35.
- **Nature:** Adamant (or Jolly if you prefer speed; change later for free).
- **Ability:** Mold Breaker > Own Tempo. Radical Red removed Pickpocket; there is **no hidden ability to hunt**.
- **Rate:** 6% on B1F, day and night.

## Time-boxed steps

In-game day is **4:00–20:00**, night is **20:00–4:00** (romhackguides). mGBA follows the system clock. Timburr and Makuhita are **day-only**. If it is night, either wait until 4:00, or use the Night path at the bottom.

### Prep (Route 3, no hunt timer)

1. Heal at the Pewter Pokémon Center and save.
2. Cross Route 3: take the Dynamax Band, fight the trainers for EXP, pick up useful items (Thunder Stone is in the grass; TM34 Teleport is here). DexNav: you can register new species as you walk so they are available later, but **do not start a catch hunt here**.
3. Enter Mt. Moon 1F. Optional pickups when convenient: TM09 Bullet Seed, Muscle Band (top-right NPC), Moon Stone (top-left, near the Hiker), Rare Candy.

### Day path (preferred)

**Step A — Timburr, Mt. Moon 1F day, 15 minutes / about 30 encounters.**

1. Walk 1F day grass until Timburr appears once (10%). Run from or catch it just to register DexNav if you want a better preview on the next one; registering is the goal of this first sighting.
2. Open DexNav (Start, then Right to page 2), register Timburr, turn on Repel if you have one (Infinite Repel if available), go back to grass, press **R** to scan (default mGBA keyboard key for R is **S** unless remapped). Walk slowly into the rustling tile.
3. Catch the first Timburr with Guts or Sheer Force. If the DexNav preview shows Iron Fist or Mach Punch / Drain Punch, take that one immediately.
4. **Hidden-ability / egg-move extra time: 10 minutes max.** If you already have a Guts or Sheer Force Timburr and Iron Fist / Mach Punch has not shown, stop and keep it. IVs are already maxed in Minimal Grinding; do not hunt stars.

**Step B — if no Timburr after 15 minutes: Makuhita, same floor, 10 minutes.**

Register Makuhita (also 10% day on 1F), DexNav scan with Repel, prefer Thick Fat. Stop at 10 minutes or on the first Thick Fat / Guts Makuhita.

**Step C — if 1F day still failed: Tinkatink, Mt. Moon B1F, 15 minutes.**

Go down to B1F (day or night does not matter). Register Tinkatink (6%), DexNav with Repel, prefer Mold Breaker. No HA hunt. If it has not appeared after 15 minutes, take the next Tinkatink you see without filtering, or take a day 1F Fighting type if one appears on the way back (Timburr / Makuhita / even 4% Tyrogue or 1% Throh). Do not open Miguel with only three Pokémon if a Fighting or Fairy encounter is still available.

### Night path (if you do not wait for day)

**Step N1 — Tinkatink, Mt. Moon B1F, 15 minutes** (same as Step C). Mold Breaker, no HA hunt.

**Step N2 — if no Tinkatink: Machop, Mt. Moon 1F night, 10 minutes.** Night 1F has Machop at **10%** (Lv12–14) instead of Timburr / Makuhita. Nature Adamant. It does not evolve into Machoke until **level 28**, so it stays Machop through Misty (cap 27). This is worse evolution timing than Timburr or Makuhita, but it still gives Fighting STAB for Archer and Bibarel. After 10 minutes, take any Machop, or go back to B1F and keep scanning Tinkatink until one is caught.

Night 1F also has Sawk at 1% and Tyrogue at 4%; do not target those rates.

### After the catch

1. Change nature if needed (free in this run).
2. Train the new member toward cap 22 on Route 3 / Mt. Moon trainers and grass. Do not over-level past 22 before Miguel and Archer.
3. Heal at a Center (or with items **outside** battle), give Sprigatito a held berry if it still has none, leave Phanpy's item slot empty, then fight Miguel and Archer.
4. After Archer, the cap rises to 27. Evolve Timburr at 25 (Gurdurr), Makuhita at 24 (Hariyama), or Tinkatink at 23 (Tinkatuff) before Misty.
5. A fifth member is optional, not part of this hunt. If you want one on the way to Cerulean: Route 4 Day has Shinx 10% and Pachirisu 10%; Route 4 Night has Mareep 10% and Pachirisu 10% (Lv13–15). Flaaffy evolves at 15; Ampharos not until 30. Those Electric types help vs Frogadier, Floatzel, and Starmie, and do nothing to Clodsire. Route 24/25 (Elekid, Yamper, Tadbulb, and others) open around Nugget Bridge / Bill, generally after reaching Cerulean and before or around Misty; they are not required for this catch.

## DexNav reminder

1. A species must be seen at least once in the area before it can be registered.
2. Start → Right (menu page 2) → DexNav → register the target.
3. R scans for the registered species; it does not open the DexNav menu.
4. Turn Repel on so other species do not break the hunt.
5. Approach rustling grass slowly. If the preview is wrong (ability or egg move you are still filtering for), walk away and scan again with R.
6. Hidden abilities and egg moves matter more than IVs here (IVs are already maxed). Still cap any HA / egg-move hunt at the times above.

## Sources

- Trainer sets: local dump `data/trainers_4_1_normal_mingrind.txt` (Rudo2204 Normal Minimal Grinding gist, based on luckytyphlosion's dump). Archer Mt. Moon = id `0x2e`. Miguel = `0xaa`. Misty Cerulean = `0x19f`. Bugsy Route 25 = `0x2f`. Rival Cerulean = `0x14c`–`0x14e`.
- Encounter tables and rates: [romhackguides Route 3](https://romhackguides.com/hacks/radical-red/routes/route-3/), [Mt. Moon 1F](https://romhackguides.com/hacks/radical-red/routes/mt-moon-1f/), [Mt. Moon B1F](https://romhackguides.com/hacks/radical-red/routes/mt-moon-b1f/); [radicalredtracker Route 3](https://radicalredtracker.com/routes/route-3), [Mt. Moon](https://radicalredtracker.com/routes/mt-moon), [Route 4](https://radicalredtracker.com/routes/route-4), [Route 24](https://radicalredtracker.com/routes/route-24), [Route 25](https://radicalredtracker.com/routes/route-25). These agreed with each other on the slots and percentages used above. romhackguides notes that official Radical Red docs do not always publish encounter percentages; the rates are FireRed slot percentages applied to this hack's species tables. radicalredtracker says its data comes from the official v4.1 location documents.
- Day / night window (4:00–20:00 / 20:00–4:00): romhackguides area pages.
- Pokémon abilities, learnsets, and RR evolution levels: [Radical Red Atlas](https://radical-red-atlas.pages.dev/) (Timburr, Makuhita, Tinkatink, Tinkatuff, Shroomish, Breloom, Clefairy, Clefable, Mareep). Timburr egg moves also checked on [romhackdex Timburr](https://romhackdex.net/radical-red/pokedex/timburr/).
- Cross-checks: [radicalredtracker Archer](https://radicalredtracker.com/bosses/archer), [Misty](https://radicalredtracker.com/bosses/misty), [Bugsy](https://radicalredtracker.com/bosses/bugsy), [Rival](https://radicalredtracker.com/bosses/rival). romhackguides Archer page disagrees on Houndour's ability (see below).

## Not verified / known disagreements

- **Houndour ability:** dump and radicalredtracker say **Unnerve**. romhackguides' Archer Mt. Moon page says Early Bird. Use Unnerve until the logger says otherwise.
- **Misty abilities:** dump says Frogadier **Torrent** and Floatzel **Water Veil**. radicalredtracker says Protean and Technician. Use the dump until the logger confirms.
- **Dump "Max Level" math:** the dump author warns that "Level: Max Level" checks are not 100% accurate, especially for bosses. Miguel is `Max Level - 3`; Bugsy and the rival use `Max Level` offsets. Fixed levels on Archer (18/19/21) and Misty (25/25/27/26) are more reliable.
- **Bugsy weather:** radicalredtracker lists Route 25 Bugsy as permanent rain. The dump has no field-effect line. Confirm in-game before that fight.
- **Rival's starter** in this run was not checked (Wartortle / Ivysaur / Charmeleon variants all exist).
- **Grassy Seed on Bibarel:** it only boosts Defense in Grassy Terrain. Miguel's listed team has no Grassy Surge / terrain setter. The seed may do nothing unless terrain is set some other way. Simple + Curse is still the threat.
- **Tinkatink evolution level:** Atlas (RR) says 23 / 36. Some general wikis still say 24 / 38. Use Atlas in this hack.
- **Timburr HA:** Atlas marks Iron Fist as hidden (same as vanilla). romhackdex's ability line is ambiguous. Confirm from the DexNav preview.
- No damage calculations were run. TM / tutor access for Drain Punch, Ice Punch, and similar was not fully mapped for this point in the story; only TM78 Low Sweep and the Muscle Band are confirmed inside Mt. Moon.
- Pickup's out-of-battle 10% item roll was not re-verified against RR-specific tables; the in-battle recycle effect has already shown up in this run's Falkner and Brock logs.
