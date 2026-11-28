# Battle lessons

## Falkner (Pewter Museum 2F), Nov 23, 2026: lost once, then won

Falkner's team: Rufflet Lv12 (Hustle, Berry Juice, Aerial Ace / Rock Tomb / Rock Smash / Roost), Wattrel Lv14 (Volt Absorb, Berry Juice), Flittle Lv14 (Speed Boost, Eviolite, Calm Mind).

**Attempt 1 (loss)**
- Phanpy Lv11 mixed Ice Shard (13 dmg) and Rollout, so Rollout never ramped. Rufflet's Aerial Ace did ~20 per hit and Berry Juice healed 20.
- Numel Lv13 took 24 before it could Growl, then fainted after one Ember (12 dmg).
- Sprigatito's Bite did 12–13 per hit; Rufflet Roosted (+21) and won with Rufflet at 8/42.
- Root cause: too little damage per turn (~12) vs ~83 effective HP on Rufflet (42 + Berry Juice + Roost).

**Attempt 2 (win)**
- Phanpy soloed the team after Numel fell. Rollout ramped 11 → 18 → 37 and OHKO'd Flittle right after its Calm Mind.
- Phanpy's **Pickup** grabbed Rufflet's and Wattrel's consumed Berry Juice mid-battle and drank them (+20 HP twice).

**Takeaways**
- Rollout is a win condition: once it starts, keep it rolling; don't switch or interrupt it.
- Pickup recycles opponents' consumed items (Berry Juice etc.) in battle.
- Numel at this level is too slow and frail to set up Growl against a fast physical attacker.
- Lead with the Pokémon that has a ramping or priority answer, not the setup mon.

## General rules for this save
- Bag items apparently cannot be used in trainer battles (auto difficulty). Healing must come from held items, Pickup, Roost-style moves, or switching.

## Brock (Pewter Gym) - won on first attempt, Nov 23, 2026 (+1920 money, Boulder Badge)

Team: Sprigatito Lv15, Numel Lv13 (Lv14 mid-fight), Phanpy Lv12 (Lv13 after). No bag items used.

Timeline:
- Sprigatito vs Geodude-Alola: Razor Leaf 23 (37 -> 14), took Bulldoze 5, second hit 14 KO. Sturdy never mattered because the first hit did not start from a OHKO; Custap was not seen triggering.
- Numel vs Varoom: Varoom opened with Toxic. Ember 22, Numel took 18 + 13 (Bulldoze etc.), Numel KO'd Varoom, then Toxic finished Numel. Varoom's ability read as Solid Rock (not Filter as our pre-fight notes said).
- Sprigatito vs Onix: 41 damage left Onix at 1 (Sturdy), Berry Juice to 21, Onix's Rock Tomb + Bulldoze took Sprigatito to 9 and dropped her Speed; Razor Leaf finished Onix.
- Archen then outsped the slowed Sprigatito and KO'd her with Pluck.
- Phanpy vs Archen: Ice Shard 16 / 15 / 16 / 11. Archen drank Berry Juice, Pickup grabbed it, Phanpy healed 20 and won at 29/50.

Takeaways:
- Rock Tomb and Bulldoze speed drops erase speed advantages. After eating one, assume the next enemy outspeeds; switch to priority (Ice Shard, Quick Attack) or a fresh mon.
- Toxic is a clock. A poisoned mon should hit hard immediately and expect to die; don't plan long setups on it.
- Pickup recycling Berry Juice worked again: it is a reliable sustain tool against Berry Juice holders.
- Check the enemy's actual ability in the log; pre-fight doc data can differ (Varoom: Solid Rock).
- Phanpy's Ice Shard is a strong closer versus Rock/Flying and Rock/Ground.

- Data check: the trainer dump lists Varoom as Overcoat @ Air Balloon; the logger read ability id 100 as Solid Rock. Neither matches the 'Filter' used in the pre-fight plan. The dump is now the source for boss sets; treat logger ability names for enemies as a cross-check.

## Super Nerd Miguel (Mt. Moon B2F) - loss, Nov 29, 2026

- **It is a double battle.** The dump does not flag it; plans assumed singles. Check `battle_flags` / `double` in the log and plan for doubles when unsure.
- **Data mismatches vs the dump:** Thwackey has **Grassy Surge** (dump: Overgrow), Sableye has **Prankster** (dump: Frisk). Levels were 17, not 19.
- Grassy Surge sets Grassy Terrain on entry: it activates Bibarel's Grassy Seed (+Def), heals every grounded mon each turn, and **halves Magnitude** (Numel's Magnitude did 4 damage).
- Prankster Will-O-Wisp is priority: it burned our physical attackers (Meowth, Phanpy, Floragato) before they moved.
- Lead Numel + Lunatone worked: Thwackey and Voltorb-Hisui went down quickly.
- The loss came in the back half: Bibarel (Simple Curse) was left alive while we hit Sableye, then swept with Aqua Jet / Quick Attack.
- Rematch plan: keep Lunatone and Floragato healthy for the back half; the moment Bibarel appears, put **both** attacks on Bibarel (Floragato Seed Bomb, Lunatone Psybeam, Numel Lava Plume - special moves ignore burn). Do not use Magnitude while terrain is up. Ignore Sableye until Bibarel is down; never Psybeam Sableye (Dark is immune).

## Rocket Admin Archer (Mt. Moon B2F) - loss, Nov 29, 2026

- Walked in right after Miguel without healing; Meowth and Lunatone were already fainted, Floragato started at 15/65.
- Singles. Team, abilities and items matched the dump (Glimmet Lv18 Toxic Debris / Shuca Berry, Houndour Lv19, Mightyena Lv21).
- Toxic Debris: hitting Glimmet with physical moves (Phanpy Rollout) laid Toxic Spikes, poison chip on every grounded switch-in.
- Rematch plan: heal first. Lead Lunatone (Levitate: immune to Mud Shot and Toxic Spikes) and Psybeam Glimmet (special, does not trigger Toxic Debris). Numel Magnitude into Houndour (Numel resists Incinerate). Mightyena: Numel / Meowth Metal Claw (resists Ice Fang) / Phanpy Rollout. Keep Floragato and Lunatone away from Mightyena and Houndour.
