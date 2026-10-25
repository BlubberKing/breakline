# BREAKLINE — Game Design Document
*Working title. Roblox competitive arcade FPS. Last updated: Oct 24, 2026 (momentum jump + mobile sprint update).*

> **Note to any AI reading this:** This file plus the `src/` folder is the source of truth.
> Items marked **PROPOSAL** are ideas, not approved — ask the owner before building on them.
> Items marked **TBD** are intentionally undecided and will be hashed out during development.
>
> **RULE — ALWAYS SEND A NEW GDD:** Every time you change *anything* (code, design, tuning, decisions),
> update this file (including section 11 Current Status + the date at the top) and send the owner the
> **complete new GDD.md** in your reply, so they can replace the file in the repo. No exceptions.
>
> **Owner is new to GitHub** — give very simple click-by-click steps when they need to add/replace files.
> Catch-up phrase for a new chat: *"Clone github.com/BlubberKing/breakline, read GDD.md and the src folder, then continue."*

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
Abilities that not everyone owns — bought/unlocked. Everyone keeps the base kit (sprint, crouch, slide, slide-jump, mantle).
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
- Existing groundwork: sights are already modular attachments (see 7.3) — each gun lists which sights it accepts,
  optics mount on the gun's rail and hide the folding iron sights. The temporary Armory picker already toggles them.

## 7. Weapons

### 7.1 System (data-driven)
- **`WeaponConfig`** (ReplicatedStorage) — every gun's stats. Shared defaults in `W.Defaults`; each gun only lists what differs.
  Supports `FireMode` = Auto / Semi / Burst, `Pellets` (shotguns), `Cycle` = Bolt / Pump / Slide (animated + blocks firing),
  per-gun recoil pattern, spread, ADS speed/zoom, move-speed multiplier, equip time, shell look, fire-sound pitch/volume.
  Helpers: `W.Get(id)`, `W.TTK(cfg, head)`, `W.AvgInterval(cfg)`.
- **`GunModels`** (ReplicatedStorage) — every gun's model is built from parts in code, plus the **sights**. One description
  builds both the first-person viewmodel and the third-person world gun. *(Replaces the old GunModelBuilder + RifleModel.)*
- **`GunClient`** — one script runs every gun (fire modes, pellets, bolt/pump anims, optics, sniper scope overlay). Rebuilds instantly on swap.
- **`GunServer`** — validates every shot per weapon (fire rate incl. bursts, ammo, pellets, range, line of sight). Shotgun pellets
  are summed into **one** damage number per target. Owns the equipped gun as Player attributes `Weapon` + `Sight` (remote `SetLoadout`).
- **`ThirdPersonServer/Client`** — world gun rebuilds when the player swaps; IK hands follow the new grip points.
- Health = 100. Hitscan for all guns (for now).

### 7.2 Adding a new gun (checklist)
1. `WeaponConfig`: add `W.Weapons.MYGUN = { Name, Class, Inspiration, Sights, DefaultSight, ...stats }` and add `"MYGUN"` to `W.Order`.
2. `GunModels`: add `Models.MYGUN = function(k) ... end` using the kit (`k.box`, `k.cylZ`, `k.ring`, `k.glow`…). It **must** call
   `k.grip`, `k.fore`, `k.magwell`, `k.muzzle`, `k.eject`, `k.mount`, `k.irons`. Iron-sight parts go after `k.tag = "Iron"`.
   Mag parts after `k.group = "mag"`, bolt/pump/slide after `k.group = "cycle"`. Or reuse a model: `Model = "VX9"` in the config.
3. Done — it shows up in the Armory picker automatically with its stats and TTK.

### 7.3 Sights
| Sight | Zoom | Notes |
|---|---|---|
| Iron | gun's ADS FOV | Built into each gun (unique per gun) |
| Red Dot | gun's ADS FOV | Small tube, dot reticle |
| Holo | gun's ADS FOV | Open window, ring + dot reticle |
| 3x (Ranger) | 3x | Short scope, chevron reticle; aim sensitivity scales with zoom |
| 8x (Sniper) | 8x | Full-screen black scope overlay; gun model hides while scoped |
- Aiming fully hides the hip crosshair (it is gone by ~1/3 of the way into ADS).

### 7.4 Roster v1 (all tuning is a first pass — to be balanced in playtests)
Each gun is inspired by a real gun + its counterparts in **The Finals** and **Rivals** (researched Oct 24, 2026).
Reference points: Finals AKM 21 dmg/617 RPM, FCAR ~530 RPM, XP-54 16 dmg/880 RPM, LH1 44 dmg semi, SR-84 118/236 dmg,
M26 Matter 11 pellets, V9S 38 dmg; Rivals AR, Burst Rifle (3-round), Uzi, Shotgun (10 pellets), Sniper (3x headshot), Revolver.

| ID | Name | Class | Real / Finals / Rivals | Dmg | Rate | Mag | Reload | TTK body / head | Sights |
|---|---|---|---|---|---|---|---|---|---|
| VX9 | VX-9 Rifle | AR (auto) | M4 / FCAR, ARN-220 / Assault Rifle | 18 (1.6x) | 650 | 30 | 1.9s | 0.46s / 0.28s | Iron, Red Dot, Holo, 3x |
| KR47 | KR-47 Bruiser | AR (auto) | AKM / AKM / AR (heavier) | 22 (1.5x) | 540 | 30 | 2.3s | 0.44s / 0.33s | Iron, Red Dot, Holo |
| HX3 | HX-3 Burst | Burst rifle | FAMAS / FAMAS / Burst Rifle | 22 (1.55x) | 3-burst | 24 | 2.0s | 0.50s / 0.13s | Iron, Red Dot, Holo, 3x |
| WASP | Wasp SMG | SMG (auto) | MP7, Vector / XP-54, M11 / Uzi | 14 (1.4x) | 900 | 40 | 1.8s | 0.47s / 0.33s | Iron, Red Dot, Holo |
| ANVIL | Anvil LMG | LMG (auto) | M249, M60 / M60, Lewis / Minigun role | 17 (1.4x) | 620 | 80 | 3.8s | 0.48s / 0.39s | Iron, Red Dot, Holo, 3x |
| LONGSHOT | Longshot DMR | Marksman (semi) | M14 EBR / LH1 / — | 38 (1.75x) | 260 | 15 | 2.4s | 0.46s / 0.23s | Iron, Red Dot, 3x |
| HALO50 | Halo-50 Sniper | Sniper (bolt) | AWM / SR-84 / Sniper | 85 (2x) | 48 | 5 | 3.0s | 1.25s / one-shot head | 8x, 3x, Iron |
| BREACHER | Breacher Pump | Shotgun (pump) | Remington 870 / M26 Matter / Shotgun | 9x10 | 80 | 6 | 2.6s | one-shot point blank | Iron, Red Dot |
| V9 | V9 Sidearm | Pistol (semi) | Glock 17 / V9S / Handgun | 24 (1.6x) | 420 | 15 | 1.3s | 0.57s / 0.29s | Iron, Red Dot |
| MAGNUM | Magnum .44 | Revolver (semi) | S&W M29 / R.357 / Revolver | 45 (1.6x) | 140 | 6 | 2.4s | 0.86s / 0.43s | Iron, Red Dot |

Balance notes: autos cluster around **~0.45s body TTK** (matches the ~0.5s TTK proposal); trade-offs come from range falloff,
mobility, handling, mag size and recoil. Damage falloff makes SMG/shotgun weak at range; DMR/sniper/burst reward headshots.
Weapon move-speed: SMG 1.06, pistols ~1.05, LMG/sniper 0.9.

### 7.5 Temporary Armory picker
- **GUNS [G]** tab at the top of the screen (or press **G**). Shows every gun as a card with class, inspiration, damage/RPM/mag/reload,
  TTK, stat bars, and **sight toggles** under each gun. Click a card to equip; swapping is instant and also updates the third-person gun.
- **TEMPORARY** — will be replaced by the lobby loadout screen (section 3). Remove `GunPicker` + the open `SetLoadout` remote then.

## 8. Movement (base kit, everyone has it)
Goal: fast-paced and fluid. All speeds are multiplied by the gun's move-speed (7.4).
- **Walk 16 / sprint 30 / crouch 9** (sprint was 24). Speeds live at the top of `GunClient`.
- **Sprint:** hold Shift. **Mobile:** "Sprint" button above the jump button; **gamepad:** click the left stick. Both are tap-to-toggle
  (button turns accent-colored while on) and switch off when you stop moving. Sent to `Movement` as the `SprintToggle` attribute.
- **Jump (momentum):** low and snappy, not springy — jump height 4.6 (Roblox default 7.2) and 1.4× gravity on the way down only.
  You keep your run speed in the air, so a sprint-jump goes far and flat (+2.5 forward speed when jumping at ≥ 24 speed).
  Air control: steer slowly (turn rate 3.2 rad/s), pressing backwards brakes, no input = keep drifting. Hitting a wall drops the
  momentum into it. Walking off a ledge works the same way. All in `CFG` at the top of `Movement` (JUMP_HEIGHT, FALL_GRAVITY_MULT, AIR_*).
- **Crouch:** C / LeftCtrl / gamepad B / mobile button while **not** sprinting. Hold to crouch (`CROUCH_TOGGLE` in `Movement` switches
  to tap-toggle). Lowers hitbox + camera, can't sprint while crouched, pressing sprint stands you up. Stays crouched under low ceilings.
  Replicated as the `Crouching` character attribute (third person shows bent legs + lean).
- **Slide:** same key while sprinting (speed ≥ 20). Small start boost (+6), steering, lowered hitbox + camera, buffered input
  (press just before landing or while still speeding up). **Momentum rules:**
  - Flat ground (under ~3.5°): keeps **all** momentum for ~0.95s, then blends smoothly back into a run (or crouch if C is still held).
  - Downhill: **gains** speed (scaled by steepness, cap 58) and the slide timer pauses, so long ramps = long fast slides.
  - Uphill: **loses** speed slowly (scaled by steepness); ends early if it drops below 14.
  - Sliding off a ledge keeps the momentum into the air.
- **Slide-jump:** keeps 95% of momentum (also works in the short blend right after a slide ends).
- **Mantle:** jump into a ledge (1.4–7.5 studs). With the lower jump, mantle is how you get onto anything above ~4.5 studs.
- **First person:** your own body + gear are always hidden locally (fixes seeing your body while falling).
- **Speed feel (subtle, tunable in `SPEEDFX` at the top of `GunClient`):** sprint FOV 82 (was 80), slide FOV +7, extra FOV when going
  faster than a sprint (downhill slides); quick FOV kick + dip when a slide starts; light camera rumble while sliding; faint speed lines
  at the screen edges — start at ~17 speed, about 60% strength at a normal sprint, full at ~38 (slides) — plus a soft dark edge
  vignette at speed; all hidden while aiming. Optional looping wind sound (`Wind` in SoundBank — empty = silent).

## 9. Tech Principles
- **Data-driven:** stats in config modules (WeaponConfig, etc.).
- **Server-authoritative** for damage, ammo, fire rate; client does visuals and instant feedback.
- Damage numbers are shown from the **server-confirmed** value (HitConfirm).
- Parts players and bullets should pass through (e.g. the middle wall) need **CanCollide = false AND CanQuery = false**.

### Code layout (Rojo-style)
- `src/ReplicatedStorage/` — shared modules: WeaponConfig, GunModels, GunMath, Spring, Sfx, SoundBank, HitFX
- `src/ServerScriptService/` — GunServer, ThirdPersonServer, AvatarService
- `src/StarterPlayer/StarterPlayerScripts/` — ThirdPersonClient, GunPicker (temp)
- `src/StarterPlayer/StarterCharacterScripts/` — GunClient, Movement
- File endings: `.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript

## 10. Roadmap
1. **Gun feel + weapon system** — built (10 guns, sights, test picker), not playtested
2. **Movement** — built (incl. crouch + momentum slide + speed effects), not playtested
3. Gray-box map + wall/box server logic *(needs tuning approval, section 2.1)*
4. Teams, rounds, respawn, match HUD
5. Polish, mobile, playtests
6. **Meta systems:** loadout + reserve, card deck + slot roll, coins/missions, shop, gunsmith, special movement abilities
   *(order within this phase TBD; 1v1/2v2 modes can come with phase 4)*

## 11. Current Status
**Built (not playtested):** 10-gun roster with models, fire modes, sights (7.4); Armory test picker; HitFX (hitmarkers,
damage numbers, combo counter, kill banner, impacts); crouch / momentum slide / slide-jump / momentum jump / mantle + speed effects + mobile sprint button (section 8); third-person world gun with IK hands;
custom blocky "operator" avatar with team-colored accents; SoundBank filled in.

**Changelog**
- **Oct 24 (d):** Momentum jump: lower, snappier jump (height 4.6, 1.4× fall gravity) that keeps your run speed in the air, small
  sprint-jump boost, limited air steering. **Fix:** own body showed in first person while falling. Speed lines now visible at a
  normal sprint (stronger, thicker, plus a soft edge vignette). New **mobile sprint button** (+ gamepad L3), tap-to-toggle.
  Files: Movement, GunClient, ThirdPersonClient.
- **Oct 24 (c):** Movement speed pass. Sprint 24 → 30. New **crouch** (C when not sprinting, crouch speed 9, third-person pose).
  Slide reworked: keeps momentum on flat, gains downhill, loses a little uphill, smooth blend out, keeps momentum off ledges.
  Speed effects: higher sprint/slide FOV, speed-based FOV, slide FOV kick + dip, slide camera rumble, edge speed lines,
  optional wind loop (`Sfx.Loop`). Files: Movement, GunClient, ThirdPersonClient, ThirdPersonServer, Sfx, SoundBank.
- **Oct 24 (b):** Gun system rebuilt to be data-driven: WeaponConfig v2, new GunModels (replaces GunModelBuilder + RifleModel —
  delete those two), GunClient v3, GunServer v2 (`SetLoadout` remote, pellets, burst-aware rate limit), ThirdPersonServer/Client
  rebuild the world gun on swap, Sfx.Play pitch/volume args, new GunPicker. **Fix:** hip crosshair now fully disappears when aiming.
- **Oct 24 (a):** slide/mantle sounds; damage numbers come from the server; server fire-rate check no longer drops shots during lag.

**To do / known:**
- Playtest the new movement numbers: sprint 30, jump height 4.6 + air momentum, slide flat time 0.95s, downhill gain, speed lines
  strength — tell the AI what feels off. Check the map: ledges you used to jump onto (4.6–7.2 studs) now need a mantle.
- Find a loopable wind sound ID for `Wind` in SoundBank (optional).
- Mobile: test the Sprint + Crouch buttons on a phone (or Studio's device emulator); move the Sprint button if it overlaps anything.
- Playtest everything; tune each gun (iron sight alignment, hip positions, recoil) — tell the AI what feels off per gun.
- Guns share the same fire/reload sounds (pitched per gun) — find unique sound IDs per class later (SoundBank).
- Reload animation is shared (mag swap) — shotgun shell-by-shell / revolver speedloader anims later.
- Middle wall parts need CanQuery = false when built.
- Everything in sections 2.1 (proposals), 2.2, 3–6 is not built yet.
