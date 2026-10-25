# BREAKLINE — Game Design Document
*Working title. Roblox competitive arcade FPS. Last updated: Oct 24, 2026.*

> **Note to any AI reading this:** This file plus the `src/` folder is the source of truth.
> Items marked **PROPOSAL** are ideas, not approved — ask the owner before building on them.
> Items marked **TBD** are intentionally undecided and will be hashed out during development.

---

## 1. Vision
- Arcade "supreme" gunplay in the spirit of **The Finals** and **Rivals** — fast, readable, not realistic.
- Hits must *feel* great: damage numbers popping to the side, hitmarkers, kill confirms, elimination banner.
- High polish bar on gun feel, movement and UI.
- **Roles:** AI = coder + UI designer. Owner = Studio work, map building, playtesting, publishing.

## 2. Game Modes

### 2.1 Main mode — Wall Push (locked design)
- **3v3.**
- A **middle wall** splits the map. Players can walk **and** shoot through it.
- Each team has a **spawn + finish line** at its end of the map.
- **3 holes per side** (6 total).
- **Boxes** spawn on the map. Players carry boxes and plug them into **their own side's** holes.
- The team with **more plugged boxes pushes the wall toward the enemy**. **Tie = wall stays still.**
- Enemies can **shoot plugged boxes to break them**.
- A team **loses when the wall reaches its finish line**.

**Tuning PROPOSALS (not approved):**
- Wall speed scales with the box difference.
- Plugged boxes drain/expire after ~45s.
- ~8 min match + overtime.
- 5–7s respawn, fixed spawn pads.
- Carrier is slowed, pistol only, can throw the box.
- 1.5s channel to plug a box.
- A plugged box breaks after 2–3s of sustained fire.
- The moving wall smashes cover it passes through.
- ~0.5s time-to-kill.
- Name ideas: Breakline, Pushwall, Overload, Shift Line.

### 2.2 Standard modes
- **1v1** and **2v2** (rules TBD — e.g. elimination rounds / deathmatch).

## 3. Loadout

### 3.1 Active loadout (chosen before the match)
- **1 gun**
- **3 gadgets**
- **1 special movement ability**

### 3.2 Reserve
- Stores **1 extra gun + 3 extra gadgets**.
- Players can **swap between the active loadout and the reserve while dead** (respawn screen).
- Movement ability is not in the reserve (TBD whether it can be swapped mid-match).

### 3.3 Special movement abilities
Abilities that not everyone owns — bought/unlocked. Everyone keeps the base kit (sprint, slide, slide-jump, mantle).
Initial ideas (details TBD, balanced during development):
- Phase Shift
- Double Jump
- Mega Jump
- Wall Runner
- Wall Crawler
- Glider
- Wall Peek

### 3.4 Gadgets
List TBD.

## 4. Power-Up Cards

### 4.1 Card reserve (deck)
- Set up in the **lobby**.
- Exactly **36 cards — no more, no less**. A deck must be full to queue.
- Duplicates allowed? **TBD.**

### 4.2 Match-start roll
- At the start of every match, each player sees a **slot-machine screen**: **three reels spin at once** and land on **three cards in a row**, drawn from that player's 36-card reserve.
- The player **picks one** card; that is their **power-up for the whole match**.
- Pick timer and what happens if nobody picks (auto-pick?) **TBD.**
- Card list and rarities **TBD.**

## 5. Economy & Shop

### 5.1 Currencies
- **Coins** — earned by playing: missions, kills, wins, etc.
- **Second currency** — name TBD (likely premium / Robux-purchased — TBD).

### 5.2 Earning coins
- Completing **missions** (daily/weekly — TBD)
- **Kills**
- **Winning** a match
- Other sources TBD (match completion, objectives like plugging/breaking boxes, etc.)

### 5.3 Shop sells
- **Skins**
- **Guns**
- **Gadgets**
- **Movement abilities**
- **Cards:** roll **crates** (random cards) or buy **individual cards on sale** — for coins **or** the second currency.

## 6. Weapon Modification (Gunsmith)
- A lobby area to modify guns with **attachments** — scopes/sights and similar (full attachment list TBD).
- **No weapon skins or charms yet** (later).
- Existing groundwork: the reticle option (Dot / Holo / Chevron) in GunClient, sight tuning in GunModelBuilder.

## 7. Weapons
Data-driven via `WeaponConfig`. Current gun:

**VX-9 RIFLE (AR)**
- 18 damage, 1.6x headshot multiplier
- 650 RPM, 30-round mag, 1.9s reload, 700 stud range
- Falloff: from 40 to 100 studs, down to 70%
- Arcade accuracy: accurate hipfire, light movement penalty, small readable recoil pattern
- ADS FOV 58 · base FOV 75 · sprint FOV 80

## 8. Movement (base kit, everyone has it)
- Walk 16 / sprint 24
- **Slide:** sprint + C / LeftCtrl / gamepad B / mobile button. Slope boost, steering, lowered hitbox + camera, buffered input.
- **Slide-jump:** keeps momentum.
- **Mantle:** jump into a ledge (1.4–7.5 studs).

## 9. Tech Principles
- **Data-driven:** stats in config modules (WeaponConfig, etc.).
- **Server-authoritative** for damage, ammo, fire rate; client does visuals and instant feedback.
- Damage numbers are shown from the **server-confirmed** value (HitConfirm).
- Parts players and bullets should pass through (e.g. the middle wall) need **CanCollide = false AND CanQuery = false**.

### Code layout (Rojo-style)
- `src/ReplicatedStorage/` — shared modules (WeaponConfig, GunMath, Spring, Sfx, SoundBank, HitFX, GunModelBuilder, RifleModel)
- `src/ServerScriptService/` — GunServer, ThirdPersonServer, AvatarService
- `src/StarterPlayer/StarterPlayerScripts/` — ThirdPersonClient
- `src/StarterPlayer/StarterCharacterScripts/` — GunClient, Movement
- File endings: `.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript

## 10. Roadmap
1. **Gun feel** — built, not playtested
2. **Movement** — built, not playtested
3. Gray-box map + wall/box server logic *(needs tuning approval, section 2.1)*
4. Teams, rounds, respawn, match HUD
5. Polish, mobile, playtests
6. **Meta systems:** loadout + reserve, card deck + slot roll, coins/missions, shop, gunsmith, special movement abilities
   *(order within this phase TBD; 1v1/2v2 modes can come with phase 4)*

## 11. Current Status
**Built (not playtested):** VX-9 rifle with full gun feel, HUD and reticle options; HitFX (hitmarkers, damage numbers, combo counter, kill banner, impacts); slide / slide-jump / mantle; third-person world gun with IK hands; custom blocky "operator" avatar with team-colored accents; SoundBank filled in.

**Fixed Oct 24:** slide/mantle sounds; damage numbers now come from the server; server fire-rate check no longer drops shots during lag.

**To do / known:**
- Playtest gun + movement.
- Middle wall parts need CanQuery = false when built.
- Everything in sections 2.1 (proposals), 2.2, 3–6 is not built yet.
