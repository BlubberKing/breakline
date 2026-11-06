-- ============================================================================================================
-- SOUND BANK v2 (v5.7)  -  every sound in the game lives here. Paste audio asset IDs (numbers only). "" = silent / use fallback.
--
-- HOW IT WORKS
--   * Each entry is   Name = { Id = "123456", Volume = 0.5, PitchMin = 0.95, PitchMax = 1.05, MaxDistance = 200 }
--     Only Id is needed. Everything else is optional.
--   * Want several variations picked at random?   Name = { Ids = { "111", "222", "333" }, Volume = 0.5 }
--     (do this for anything that repeats fast: footsteps, SMG shots, hit sounds - it kills the "machine" feel)
--   * PER-GUN SOUNDS: put them in the Guns section under that gun's internal ID (VX9, KR47, ...). A gun entry only needs an Id; if you leave out
--     Volume / Pitch / MaxDistance it uses the ones from the section with the same name (Global / Combat ...). If a gun has no sound for a slot, the game
--     uses the Global sound with that name, and if there is none either, it uses the Fallbacks table at the bottom.
--     EVERY GUN BELOW HAS ITS OWN BLOCK that only lists the slots that gun really plays, in the order they happen, with a comment saying what
--     the moment is and what kind of sound fits. (The engine also pitches / loudens each gun's Fire with WeaponConfig FirePitch / FireVolume, so a
--     sound you paste for a heavy gun gets pitched down on top: pick one that is already punchy, then fine-tune with Volume here.)
--   * The sections (Global, Combat, Body, Movement, Abilities, Gadgets, Boxes, Death, Match, UI, Cards) are only for tidiness. Names must be unique
--     across them, but you can move an entry to another section without touching any code.
--   * Every slot that has a code hook is marked [LIVE]. A slot marked [NEEDS CODE] has a name reserved but nothing plays it yet.
--
-- WHO HEARS IT
--   2D = only you hear it (no position).  3D = played from a Part / position, everybody close hears it (MaxDistance = how far).
--
-- ADDING A BRAND NEW SOUND SLOT
--   1) Add a line in any section, e.g.   BoxSplash = { Id = "123", Volume = 0.6 },
--   2) Play it from any script:   Sfx.Play("BoxSplash")                     -- 2D (only you hear it)
--                                 Sfx.Play("BoxSplash", somePart)           -- 3D from a Part / Attachment
--                                 Sfx.Play("BoxSplash", Vector3.new(0,5,0)) -- 3D from a position
--                                 Sfx.Play("Fire", nil, nil, nil, "VX9")    -- use the M4A1's own version of a slot
--      (full signature: Sfx.Play(name, parent, pitchMultiplier, volumeMultiplier, gunId))
-- ============================================================================================================
local GADGET_IDS = { "FRAG", "SMOKE", "FLASH", "SENTRY", "SHIELD", "MINE" } -- per-gadget variants (see Gadgets): GadEquip_FRAG, GadThrow_SMOKE, GadPlace_MINE ...

local Bank = {

-- ================= GLOBAL: default gun sounds (used by every gun that has no sound of its own) =================
Global = {
	Fire           = { Id = "6862108495", Volume = 0.65, PitchMin = 0.96, PitchMax = 1.04 }, -- [LIVE] one shot, 2D for you / 3D from the shooter's head for others. DEFAULT for all guns that have no own Fire.
	FireTail       = { Id = "136262396813451", Volume = 0.30, PitchMin = 0.95, PitchMax = 1.05 }, -- [LIVE] tail / echo layered under EVERY shot
	Equip          = { Id = "6042054037", Volume = 0.50 }, -- [LIVE] pulling the gun out
	ReloadStart    = { Id = "6455642389", Volume = 0.40 }, -- [LIVE] reload begins (hand goes for the mag)
	MagOut         = { Id = "6052548458", Volume = 0.55 }, -- [LIVE] mag leaves the gun
	MagIn          = { Id = "6052548458", Volume = 0.60 }, -- [LIVE] new mag goes in
	Bolt           = { Id = "6042054037", Volume = 0.60 }, -- [LIVE] charging handle / slide racked at the end of a reload (also the fallback of Cycle / BoltOpen / BoltClose / Pump...)
	LowAmmo        = { Id = "135088937686823", Volume = 0.25, PitchMin = 1.1, PitchMax = 1.2 }, -- [LIVE] soft tick on EVERY shot while the mag is at 25% or less
	DryFire       = { Id = "" }, -- [LIVE v5.7] empty-mag click when you hold the trigger while the reload is still running (max every 0.4 s)
	AimIn         = { Id = "" }, -- [LIVE v5.7] you go into the sights (tiny cloth / rail tick). Optional, per gun is better
	AimOut        = { Id = "" }, -- [LIVE v5.7] you leave the sights
	-- special reload sounds: leave empty to use the Fallbacks (old generic sounds); fill in to change them for ALL guns
	Cycle         = { Id = "" }, -- [LIVE] bolt / pump cycling after EVERY shot (only HALO-50 + BREACHER do this)
	CoverOpen     = { Id = "" }, -- [LIVE] ANVIL feed cover opens
	CoverClose    = { Id = "" }, -- [LIVE] ANVIL feed cover shuts
	BeltIn        = { Id = "" }, -- [LIVE] ANVIL belt laid in
	BoltOpen      = { Id = "" }, -- [LIVE] HALO-50 bolt opens (reload)
	BoltClose     = { Id = "" }, -- [LIVE] HALO-50 bolt closes (reload)
	RoundIn       = { Id = "" }, -- [LIVE] one loose round pushed in (HALO-50 / .44 Magnum), plays once per missing round
	ShellIn       = { Id = "" }, -- [LIVE] one shell pushed in (BREACHER), plays once per missing shell
	PumpBack      = { Id = "" }, -- [LIVE] BREACHER pump back (reload)
	PumpForward   = { Id = "" }, -- [LIVE] BREACHER pump forward (reload)
	CylinderOpen  = { Id = "" }, -- [LIVE] .44 Magnum cylinder swings out
	CasingOut     = { Id = "" }, -- [LIVE] .44 Magnum spent brass dumps out
	CylinderClose = { Id = "" }, -- [LIVE] .44 Magnum cylinder flicks shut
},

-- ================= COMBAT (what you hit / what hits you) =================
Combat = {
	Hit            = { Id = "130797915", Volume = 2.00, PitchMin = 0.97, PitchMax = 1.03 }, -- [LIVE] 2D hitmarker tick when your bullet hits a body (give it 3-4 Ids variants, it plays a lot)
	Headshot       = { Id = "7269900245", Volume = 2.00, PitchMin = 1.00, PitchMax = 1.04 }, -- [LIVE] 2D hitmarker when your bullet hits a head (higher, sharper than Hit)
	Kill           = { Id = "9123334926", Volume = 2.00, PitchMin = 1.00, PitchMax = 1.00 }, -- [LIVE] 2D you killed someone (also used, quieter, when a plugged box breaks)
	Damaged        = { Id = "5718786992", Volume = 0.60 }, -- [LIVE] 2D you got hit by a bullet (a dull thud / grunt)
	Impact         = { Id = "6700004586", Volume = 0.40, PitchMin = 0.9, PitchMax = 1.1, MaxDistance = 120 }, -- [LIVE] 3D a bullet hits a surface (wall / floor). Short 'tk-pff'
	HitShield     = { Id = "", Volume = 0.6 }, -- [NEEDS CODE] your bullet hits a bubble shield (energy 'bzzt')
},

-- ================= BODY (your own character) =================
Body = {
	Respawn       = { Id = "", Volume = 0.7 },  -- [LIVE v5.7] 2D you came back to life (revive / respawn), a soft rising whoosh
	SoulPickup    = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D you pick a soul up (hold E)
	SoulDrop      = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D you put the soul down / throw it
	ReviveStart   = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D you kneel and start reviving a teammate (a gentle rising hum)
	ReviveStop    = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D you stop reviving (cancel / done)
	ReserveOpen   = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D the RESERVE screen opens (J while dead): a menu 'whoosh'
	ReserveClose  = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D the RESERVE screen closes
	ReserveSwap   = { Id = "", Volume = 0.7 },  -- [LIVE v5.7] 2D you swapped a gun / gadget with your reserve: gear 'clack-shff'
},

-- ================= MOVEMENT (base kit, everyone) =================
Movement = {
	Slide          = { Id = "138269837525273", Volume = 0.50 }, -- [LIVE] 3D slide start: a scrape / whoosh on the ground (also played for other players)
	Mantle         = { Id = "120034381418358", Volume = 0.50 }, -- [LIVE] 2D you mantle (pull up onto a ledge): cloth + a grunt-less 'hup'
	Wind           = { Id = "93035214379043", Volume = 0.50 }, -- [LIVE] LOOPING 2D wind rush at high speed (use a loopable sound)
	Footstep      = { Id = "", Volume = 0.5, MaxDistance = 90, PitchMin = 0.94, PitchMax = 1.06 }, -- [LIVE v5.7] 3D every stride of every player. USE 4-6 Ids (Ids = { ... }) so it never repeats
	Jump          = { Id = "", Volume = 0.5, MaxDistance = 90 },   -- [LIVE v5.7] 3D leaving the ground by jumping (a small cloth / effort 'hup', no voice needed)
	Land          = { Id = "", Volume = 0.6, MaxDistance = 90 },   -- [LIVE v5.7] 3D a normal landing (a short boot thud)
	LandHard      = { Id = "", Volume = 0.9, MaxDistance = 120 },  -- [LIVE v5.7] 3D a long fall: bigger thud + a rattle of gear
},

-- ================= MOVEMENT ABILITIES (the MOVE slot) =================
Abilities = {
	Dash          = { Id = "", Volume = 0.7 },  -- [LIVE] 2D dash (F): a quick air 'FWOOSH' with a little thrust, ~0.3 s
	DoubleJump    = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D the second jump in the air: a light 'puff' / airy flap
	MegaCharge    = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D you start charging a mega jump (hold SPACE): a rising energy wind-up
	MegaLaunch    = { Id = "", Volume = 0.9 },  -- [LIVE v5.7] 2D the mega jump launches: a big 'BOOOF' + whoosh
	WallStart     = { Id = "", Volume = 0.6 },  -- [LIVE] 2D you latch onto a wall (wall run start): a shoe-scuff / slap on the wall
	WallJump      = { Id = "", Volume = 0.7 },  -- [LIVE] 2D you kick off the wall (SPACE)
	Vault         = { Id = "", Volume = 0.7 },  -- [LIVE] 2D you hop over the top edge of a wall
	ClimbGrab     = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D your hands grab a wall to climb (falls back to WallStart): a gloved 'grip'
	ClimbRelease  = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D you let go of the climb (falls off / jumps off)
	WallExhausted = { Id = "", Volume = 0.7 },  -- [LIVE v5.7] 2D wall-run stamina ran dry and you drop: a breathy 'fff' / tired slip
},

-- ================= GADGETS (keys 2 / 3 / 4) =================
-- Per-gadget slots use the pattern <Slot>_<ID> with ID = FRAG, SMOKE, FLASH, SENTRY, SHIELD, MINE. If you only fill the generic slot
-- (GadEquip / GadThrow / GadPlace) every gadget uses it; fill GadEquip_FRAG etc. to give one gadget its own.
Gadgets = {
	GadEquip      = { Id = "", Volume = 0.5 },  -- [LIVE v5.7] 2D you take a gadget in your hand (generic). Per gadget: GadEquip_FRAG ... below
	GadPutAway    = { Id = "", Volume = 0.4 },  -- [LIVE v5.7] 2D you put the gadget away (key again / Q / 1)
	GadThrow      = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] 2D you throw (generic). Underhand toss plays it at 85% pitch. FRAG: pin 'ting' + whoosh fits
	GadPlaceTry   = { Id = "", Volume = 0.4 },  -- [LIVE v5.7] 2D the click when you press PLACE (sentry / shield / mine), before the object lands
	GadPlace      = { Id = "", Volume = 0.7, MaxDistance = 120 }, -- [LIVE v5.7] 3D a placeable is set down (generic). Per gadget: GadPlace_SENTRY ...
	SmokePop      = { Id = "", Volume = 0.9, MaxDistance = 150 }, -- [LIVE v5.7] 3D the smoke canister pops: 'POP-fsssss'
	Explosion     = { Id = "", Volume = 1.0 },  -- [LIVE] 3D frag grenade / mine / sentry explosion (GadgetClient plays it at the blast)
	FlashBang     = { Id = "", Volume = 1.0 },  -- [LIVE] 3D flashbang: a sharp 'BANG' + ringing; the ring-out makes it feel blinding
	ShieldBreak   = { Id = "", Volume = 0.9 },  -- [LIVE] 3D the bubble shield shatters (glassy crack + energy collapse)
	SentryDeploy  = { Id = "", Volume = 0.8, MaxDistance = 120 }, -- [LIVE v5.7] 3D the sentry unfolds and powers up (servo + 'whirr-click')
	SentryShot    = { Id = "", Volume = 0.5, MaxDistance = 140, PitchMin = 0.95, PitchMax = 1.05 }, -- [LIVE v5.7] 3D EVERY sentry shot (8 per second): short, low-ish 'tak', use 2-3 Ids
	MineArm       = { Id = "", Volume = 0.6, MaxDistance = 60 },  -- [LIVE v5.7] 3D the mine finishes arming (a 'beep-beep' lock)
	MineBeep      = { Id = "", Volume = 0.3, MaxDistance = 40 },  -- [LIVE v5.7] 3D the armed mine blinks (about every 0.7 s): a very small, high 'bip'
	MineTrigger   = { Id = "", Volume = 0.9, MaxDistance = 80 },  -- [LIVE v5.7] 3D an enemy is close: the mine hops (a 'CLICK-boing' right before the blast)
},

-- ================= ROBOT BOXES (3D, played from the box) =================
-- All empty = silent (BoxBreak falls back to the old layered crunch).
Boxes = {
	BoxSpawn     = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- [LIVE] a new box appears
	BoxPickup    = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- [LIVE] someone picks up a loose box
	BoxExtract   = { Id = "", Volume = 0.7, MaxDistance = 150 }, -- [LIVE] someone rips a plugged box out of a hole
	BoxDrop      = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- [LIVE] dropped (Q)
	BoxThrow     = { Id = "", Volume = 0.7, MaxDistance = 150 }, -- [LIVE] thrown
	BoxLand      = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- [LIVE] a thrown box settles on the ground
	BoxPlugStart = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- [LIVE] box starts floating into a hole
	BoxPlugged   = { Id = "", Volume = 0.8, MaxDistance = 150 }, -- [LIVE] box locks into the hole (a heavy mechanical clunk)
	BoxHit       = { Id = "", Volume = 0.5, MaxDistance = 150, PitchMin = 0.92, PitchMax = 1.08 }, -- [LIVE] a plugged box takes a bullet (angry face, metal 'tonk')
	BoxCritical  = { Id = "", Volume = 0.7, MaxDistance = 150 }, -- [LIVE] box drops under 25% health (alarm 'bwomp')
	BoxBreak     = { Id = "", Volume = 1.0, MaxDistance = 300 }, -- [LIVE] box destroyed (empty = old layered crunch)
},

-- ================= DEATH / SOULS =================
Death = {
	PlayerDeath     = { Id = "", Volume = 0.8, MaxDistance = 200 }, -- [LIVE] someone dies (3D, everyone near hears it)
	PlayerDeathSelf = { Id = "", Volume = 0.8 }, -- [LIVE] YOU die (2D, only you)
	SoulBurst       = { Id = "", Volume = 0.6, MaxDistance = 200 }, -- [LIVE] souls burst out of the body (3D)
	SoulMeet        = { Id = "", Volume = 0.6, MaxDistance = 250 }, -- [LIVE] souls meet above the body (flash) (3D)
	SoulRocket      = { Id = "", Volume = 0.6, MaxDistance = 400 }, -- [LIVE] orb rockets into the sky (3D; empty = Wind sound pitched up)
	SoulStar        = { Id = "", Volume = 0.6, MaxDistance = 1500 }, -- [LIVE] the star glint in the sky (3D)
	SoulAbsorb      = { Id = "", Volume = 0.5, MaxDistance = 100 }, -- [LIVE] a soul flies into YOU when someone else dies nearby (3D)
	SoulAbsorbSelf  = { Id = "", Volume = 0.6 }, -- [LIVE] souls rush into your screen on your own death (2D)
},

-- ================= MATCH FLOW (2D) =================
Match = {
	RoundStart     = { Id = "", Volume = 0.7 }, -- [LIVE] round begins ('GO')
	RoundWin       = { Id = "", Volume = 0.8 }, -- [LIVE] your team won
	RoundLose      = { Id = "", Volume = 0.8 }, -- [LIVE] your team lost
	RoundOver      = { Id = "", Volume = 0.8 }, -- [LIVE] draw / no winner
	Countdown      = { Id = "", Volume = 0.6 }, -- [LIVE] one tick per second in the last 5 seconds (loadout screen + 3-2-1)
	Notify         = { Id = "", Volume = 0.4 }, -- [LIVE] top banner messages ("RED took a box from BLUE", ...)
},

-- ================= UI (2D, menus) =================
UI = {
	MenuOpen      = { Id = "", Volume = 0.5 },  -- [LIVE v5.7] you open a loadout picker (pre-game big menu). Empty = plays Notify
	LoadoutPick   = { Id = "", Volume = 0.6 },  -- [LIVE v5.7] you choose an item in the pre-game picker. Empty = plays Notify
	UIHover       = { Id = "", Volume = 0.25 }, -- [LIVE v5.7] mouse over a card in a picker (tiny tick)
	UIClick       = { Id = "", Volume = 0.45 }, -- [LIVE v5.7] click on a tile / card in the pickers
},

-- ================= POWER-UP CARDS (2D) =================
-- Empty slots fall back in code: CardTick -> nothing, CardLand -> Equip, CardPick -> Notify / Equip
Cards = {
	CardTick      = { Id = "", Volume = 0.4 },  -- [LIVE] the slot-machine reels ticking while they spin (short 'tk', pitch rises with the speed)
	CardLand      = { Id = "", Volume = 0.6 },  -- [LIVE] a reel lands on its card ('thunk')
	CardRare      = { Id = "", Volume = 0.8 },  -- [LIVE] a Legendary / Divine card lands: a sparkle / chime on top of CardLand
	CardPick      = { Id = "", Volume = 0.7 },  -- [LIVE] you pick a card (confirm 'ding-shff')
},

-- ================= PER-GUN SOUNDS =================
-- Keys = internal gun IDs. Fill in only what you want; empty = the Global sound (or Fallback) is used.
-- Optional per entry: Volume, PitchMin, PitchMax (otherwise copied from the Global entry of the same name).
-- Reading guide: "at 0.7 s" = how long after the reload started the sound plays (a rough number, the animation is tuned by percentages).
Guns = {

	-- ------------------------------------------------------------------------------------------------
	-- VX9 = M4A1  (assault rifle, auto 650 rpm, the all-rounder)
	-- CHARACTER: clean, mid-weight 5.56 "tak". Controlled, not boomy, not sci-fi. Think a good game M4: short crack, tiny body.
	-- FIRE RATE: 11 shots per second, so every Fire sound must be under ~0.1 s or a spray turns to mush. Use 2-3 variations: Fire = { Ids = { "..", ".." } }.
	-- ------------------------------------------------------------------------------------------------
	VX9 = {
		Fire        = { Id = "" }, -- ONE shot (2D for you, 3D from the shooter for others). Crisp transient + a little low thump, under 0.1 s
		FireTail    = { Id = "" }, -- tail / echo layered under EVERY shot; keep it quiet (30%) and 0.3-0.5 s, it stacks at 11 per second
		Equip       = { Id = "" }, -- raising the rifle: "shff-clack", about 0.25 s (EquipTime 0.3)
		AimIn       = { Id = "" }, -- into the sights: tiny rail / cloth tick, 0.1 s (ADS takes 0.14 s). Optional
		AimOut      = { Id = "" }, -- out of the sights: the same tick, softer. Optional
		DryFire     = { Id = "" }, -- hammer "click" on an empty mag
		LowAmmo     = { Id = "" }, -- plays on EVERY shot once you are at 7 of 30 rounds or less: a very soft metallic tick, 0.05 s
		ReloadStart = { Id = "" }, -- at 0.06 s: hand slap on the mag release / a short rustle
		MagOut      = { Id = "" }, -- at 0.7 s: mag release + the mag sliding out "click-shk"
		MagIn       = { Id = "" }, -- at 1.9 s: new mag slid in and seated, firm "clk"
		Bolt        = { Id = "" }, -- at 2.4 s: charging handle pulled and released "ch-chk" (the last beat before you can shoot)
	},

	-- ------------------------------------------------------------------------------------------------
	-- KR47 = AK-47  (assault rifle, auto 540 rpm, the ONE gun with real recoil)
	-- CHARACTER: heavier, angrier, woody 7.62 "BARK". Deeper than the M4A1 and a bit rougher, with more mid than top.
	-- ENGINE NOTE: Fire is pitched down 12% and +10% louder by WeaponConfig (FirePitch 0.88, FireVolume 1.1). Choose a sound that is already punchy, not sub-bassy.
	-- FIRE RATE: 9 shots per second. Keep each shot under 0.12 s. Variations help the spray pattern feel alive.
	-- ------------------------------------------------------------------------------------------------
	KR47 = {
		Fire        = { Id = "" }, -- ONE shot. Mid-heavy crack with a ragged edge, under 0.12 s
		FireTail    = { Id = "" }, -- echo layered under every shot; 0.4 s, quiet (it stacks)
		Equip       = { Id = "" }, -- drawing the AK: wood + metal "tk-shak", about 0.3 s
		AimIn       = { Id = "" }, -- sights: a small wooden / metal tick. Optional
		AimOut      = { Id = "" }, -- sights out. Optional
		DryFire     = { Id = "" }, -- heavy hammer "clack" on empty
		LowAmmo     = { Id = "" }, -- soft tick on EVERY shot at 7 of 30 rounds or less
		ReloadStart = { Id = "" }, -- at 0.07 s: hand grabbing the fresh mag
		MagOut      = { Id = "" }, -- at 1.0 s: thumb release + heavy mag scraping out "clack-shhk"
		MagIn       = { Id = "" }, -- at 2.3 s: the AK "rock-in": two beats, "tk-CLK", louder than the M4A1
		Bolt        = { Id = "" }, -- at 2.8 s: big charging handle slap "shkLAK" (the last beat)
	},

	-- ------------------------------------------------------------------------------------------------
	-- HX3 = FAMAS  (burst rifle: 3 rounds per trigger pull at 900 rpm, then a 0.3 s gap)
	-- CHARACTER: sharp, tight, a touch higher than the M4A1 (FirePitch 1.05). A bullpup "brrt": snappy and plasticky.
	-- BURST NOTE: Fire AND FireTail play for EACH of the 3 rounds, 0.067 s apart. Use a hard transient with a very short tail (under 0.12 s),
	-- otherwise the three rounds smear into one blob. Short + crisp makes the burst read as "brrp".
	-- ------------------------------------------------------------------------------------------------
	HX3 = {
		Fire        = { Id = "" }, -- ONE round of the burst. Hard transient, under 0.08 s
		FireTail    = { Id = "" }, -- tail under every round: tiny (under 0.12 s), or leave empty
		Equip       = { Id = "" }, -- raising the bullpup: "shff-tk", 0.25 s
		AimIn       = { Id = "" }, -- sights tick. Optional
		AimOut      = { Id = "" }, -- sights out. Optional
		DryFire     = { Id = "" }, -- light plasticky "click"
		LowAmmo     = { Id = "" }, -- soft tick on EVERY round at 6 of 24 rounds or less
		ReloadStart = { Id = "" }, -- at 0.06 s: hand to the mag
		MagOut      = { Id = "" }, -- at 0.8 s: mag drops out of the bullpup (behind the grip) "clk-shk"
		MagIn       = { Id = "" }, -- at 2.0 s: mag seated "clunk"
		Bolt        = { Id = "" }, -- at 2.5 s: top charging handle "chk-chk"
	},

	-- ------------------------------------------------------------------------------------------------
	-- WASP = SMG  (auto 900 rpm, 40 rounds, the fast light one)
	-- CHARACTER: snappy, light, a little "sewing machine". FirePitch 1.18 and FireVolume 0.8 already make it high and quiet. Think a suppressed-ish "pt-pt-pt".
	-- FIRE RATE: 15 shots per second! Each Fire sound must be 0.06 s or shorter and you really want 3+ variations (Fire = { Ids = { "..", "..", ".." } })
	-- or it sounds like a buzzing loop. Leave FireTail empty (or a tiny tick): it would pile up 15 times a second.
	-- ------------------------------------------------------------------------------------------------
	WASP = {
		Fire        = { Id = "" }, -- ONE shot, 0.06 s max, 3+ variations
		FireTail    = { Id = "" }, -- leave EMPTY (or a tiny 0.1 s tick at 20% volume)
		Equip       = { Id = "" }, -- quick flip-up (EquipStyle Flip): "fwip-tk", 0.2 s
		AimIn       = { Id = "" }, -- tiny tick. Optional
		AimOut      = { Id = "" }, -- tiny tick. Optional
		DryFire     = { Id = "" }, -- light "tik"
		LowAmmo     = { Id = "" }, -- on EVERY shot at 10 of 40 rounds or less (that is 15 per second): make it near silent or skip it
		ReloadStart = { Id = "" }, -- at 0.05 s: quick hand slap
		MagOut      = { Id = "" }, -- at 0.5 s: light plastic mag pops out "pk-sh"
		MagIn       = { Id = "" }, -- at 1.3 s: quick "tk-clk"
		Bolt        = { Id = "" }, -- at 1.8 s: small cocking "chk"
	},

	-- ------------------------------------------------------------------------------------------------
	-- ANVIL = LMG  (auto 620 rpm, 80 rounds, 5.6 s reload, slow to draw)
	-- CHARACTER: heavy belt-fed machine gun. FirePitch 0.82 and FireVolume 1.15: deep, chunky, a hammer. The reload is the star: 5 big mechanical beats.
	-- FIRE RATE: 10 shots per second. Each shot under 0.12 s, deep and thick. FireTail can be a longer rumble (0.5 s) because the rhythm is slower.
	-- ------------------------------------------------------------------------------------------------
	ANVIL = {
		Fire        = { Id = "" }, -- ONE shot: deep thick "DOOM-chk", under 0.12 s
		FireTail    = { Id = "" }, -- low rumble tail, 0.5 s, quiet
		Equip       = { Id = "" }, -- HEAVY draw (EquipTime 0.6 s, EquipStyle Heavy): metal "clunk-shhhk" with weight, 0.5 s
		AimIn       = { Id = "" }, -- bipod-less heavy lift: low "thm". Optional
		AimOut      = { Id = "" }, -- low "thm". Optional
		DryFire     = { Id = "" }, -- heavy dull "clunk" on empty
		LowAmmo     = { Id = "" }, -- on EVERY shot at 20 of 80 rounds or less: very subtle, or skip
		ReloadStart = { Id = "" }, -- at 0.1 s: hand to the feed cover
		CoverOpen   = { Id = "" }, -- at 1.2 s: feed tray cover lifts: "CLANK-creeak"
		MagOut      = { Id = "" }, -- at 2.4 s: the old ammo box unclips / drops "ka-THUNK"
		MagIn       = { Id = "" }, -- at 4.2 s: new ammo box slammed on "THUNK"
		BeltIn      = { Id = "" }, -- at 4.7 s: belt links laid on the tray "chk-chk-chk" (short, 0.3 s)
		CoverClose  = { Id = "" }, -- at 5.15 s: the cover SLAMS shut "CLANG", the biggest sound of the gun
	},

	-- ------------------------------------------------------------------------------------------------
	-- LONGSHOT = marksman rifle  (semi 260 rpm, 15 rounds, hits hard)
	-- CHARACTER: a single hard 7.62 battle-rifle "CRACK-thump" you can hear across the map. FirePitch 0.8, FireVolume 1.2.
	-- SEMI-AUTO: about 4 shots per second at most, so Fire can be 0.2 s and FireTail can be a real outdoor echo (up to 1 s).
	-- The reload uses lower pitch / louder variants of the same slots on purpose (the gun is heavier than the M4A1): paste bigger sounds.
	-- ------------------------------------------------------------------------------------------------
	LONGSHOT = {
		Fire        = { Id = "" }, -- ONE shot: loud "CRACK" with weight, 0.2 s
		FireTail    = { Id = "" }, -- echo 0.8-1 s, 40% volume (it only plays 4 times a second)
		Equip       = { Id = "" }, -- raising the marksman rifle: weighty "shak-tk", 0.3 s
		AimIn       = { Id = "" }, -- scope up: small tick. Optional
		AimOut      = { Id = "" }, -- scope down. Optional
		DryFire     = { Id = "" }, -- firm "clack"
		LowAmmo     = { Id = "" }, -- on EVERY shot at 3 of 15 rounds or less: a clear single tick works here (few shots)
		ReloadStart = { Id = "" }, -- at 0.07 s: hand to the mag
		MagOut      = { Id = "" }, -- at 1.0 s: engine plays this at 90% pitch: a heavy mag sliding out "chk-shhk"
		MagIn       = { Id = "" }, -- at 2.55 s: engine plays this at 85% pitch and 120% volume: a heavy mag "THK-clk"
		Bolt        = { Id = "" }, -- at 3.1 s: engine plays this at 85% pitch: the bolt carrier slapped forward "SHK-LAK"
	},

	-- ------------------------------------------------------------------------------------------------
	-- HALO50 = HALO-50 sniper  (bolt action 48 rpm, 5 rounds, ONE shot per 1.25 s)
	-- CHARACTER: the loudest thing in the game. Huge supersonic "BOOM-CRACK", deep. FirePitch 0.62, FireVolume 1.4 (the engine pitches it way down).
	-- SLOW GUN: one shot every 1.25 s, so Fire and FireTail can be long. Every shot is followed by a bolt cycle (Cycle) 0.2 s later, lasting 0.8 s.
	-- RELOAD: it loads ONE round at a time (only the missing rounds): BoltOpen, then RoundIn once per missing round, then BoltClose. No mag sounds.
	-- ------------------------------------------------------------------------------------------------
	HALO50 = {
		Fire        = { Id = "" }, -- ONE shot: massive "BOOOM-CRACK", 0.4 s
		FireTail    = { Id = "" }, -- long canyon echo 1.5-2.5 s, 50% volume
		Cycle       = { Id = "" }, -- plays 0.2 s after EVERY shot: bolt lifted, pulled back, pushed forward, locked: "cha-chk", 0.6 s. Empty = uses Bolt
		Equip       = { Id = "" }, -- HEAVY draw (EquipTime 0.7 s): rifle lifted, strap + metal, 0.6 s
		AimIn       = { Id = "" }, -- scope up: soft tick. Optional
		AimOut      = { Id = "" }, -- scope down. Optional
		DryFire     = { Id = "" }, -- heavy "clunk" on empty
		LowAmmo     = { Id = "" }, -- on EVERY shot at 1 round: use a clear tick
		ReloadStart = { Id = "" }, -- at 0.05 s: hand to the bolt
		BoltOpen    = { Id = "" }, -- at 0.5 s: bolt handle lifted + pulled back "klk-SHK"
		RoundIn     = { Id = "" }, -- plays ONCE PER MISSING ROUND, 0.55 s apart (up to 5): one big round pushed into the port "tk"
		BoltClose   = { Id = "" }, -- after the last round: bolt pushed forward and locked "SHK-clk"
	},

	-- ------------------------------------------------------------------------------------------------
	-- BREACHER = shotgun  (semi 80 rpm, 6 shells, 10 pellets per shot)
	-- CHARACTER: a deep 12-gauge "BOOOM": wide, crunchy, short punch. FirePitch 0.6, FireVolume 1.4. Think pump-action: heavy, physical.
	-- SLOW GUN (1.3 shots per second): long Fire / FireTail are fine. After EVERY shot the pump is racked (Cycle, 0.08 s after the shot, 0.5 s long).
	-- RELOAD: shells go in ONE AT A TIME (only the missing ones) then the pump is worked: PumpBack + PumpForward at the end. No mag sounds.
	-- ------------------------------------------------------------------------------------------------
	BREACHER = {
		Fire        = { Id = "" }, -- ONE shot: deep "BOOOM" with a gravelly spread, 0.3 s
		FireTail    = { Id = "" }, -- room echo / rolling boom 1 s
		Cycle       = { Id = "" }, -- plays 0.08 s after EVERY shot: the pump racked in one motion "ch-CHK", 0.5 s. Empty = uses Bolt
		Equip       = { Id = "" }, -- HEAVY draw: "shk-clunk" + a pump tap, 0.4 s
		AimIn       = { Id = "" }, -- tiny tick. Optional
		AimOut      = { Id = "" }, -- tiny tick. Optional
		DryFire     = { Id = "" }, -- hollow "click"
		LowAmmo     = { Id = "" }, -- on EVERY shot at 1 shell: a clear tick
		ReloadStart = { Id = "" }, -- at 0.05 s: hand to the ammo
		ShellIn     = { Id = "" }, -- plays ONCE PER MISSING SHELL, 0.5 s apart (up to 6): a shell pushed into the tube "tk-clk"
		PumpBack    = { Id = "" }, -- end of the reload: pump pulled back "ch"
		PumpForward = { Id = "" }, -- end of the reload: pump pushed forward "CHK" (about 0.25 s after PumpBack)
	},

	-- ------------------------------------------------------------------------------------------------
	-- V9 = pistol  (semi 420 rpm, 15 rounds, fast to draw)
	-- CHARACTER: a light, snappy 9 mm "pap". FirePitch 1.12 and FireVolume 0.8: short and a bit high. No slide-cycle sound plays after a shot
	-- (the slide is part of the shot), so the Fire sound itself should include a tiny slide "tk".
	-- ------------------------------------------------------------------------------------------------
	V9 = {
		Fire        = { Id = "" }, -- ONE shot: snappy 9 mm "pap" + a hint of slide, 0.1 s
		FireTail    = { Id = "" }, -- small room tail 0.3 s, quiet
		Equip       = { Id = "" }, -- quick draw (EquipStyle Flip): holster "shk-tk", 0.2 s
		AimIn       = { Id = "" }, -- tiny tick. Optional
		AimOut      = { Id = "" }, -- tiny tick. Optional
		DryFire     = { Id = "" }, -- a hollow slide-less "click"
		LowAmmo     = { Id = "" }, -- on EVERY shot at 3 of 15 rounds or less: soft tick
		ReloadStart = { Id = "" }, -- at 0.05 s: hand slap on the grip
		MagOut      = { Id = "" }, -- at 0.5 s: the mag drops free "clk-thud"
		MagIn       = { Id = "" }, -- at 1.3 s: new mag slapped in "click"
		Bolt        = { Id = "" }, -- at 1.7 s: slide released and snapped forward "SHK-CLK"
	},

	-- ------------------------------------------------------------------------------------------------
	-- MAGNUM = .44 Magnum  (revolver, semi 140 rpm, 6 rounds, hits very hard)
	-- CHARACTER: a huge handgun "BOOM" with a mid-range bark and a rolling echo, the hand-cannon. FirePitch 0.72, FireVolume 1.3.
	-- SLOW GUN (2.3 shots per second): a long tail (up to 1 s) works. No cycling sound. The draw is a twirl (EquipStyle Twirl): give the Equip a spin.
	-- RELOAD: cylinder swings out, the brass dumps, ONE round at a time goes in (only the missing ones), the cylinder flicks shut.
	-- ------------------------------------------------------------------------------------------------
	MAGNUM = {
		Fire          = { Id = "" }, -- ONE shot: huge handgun "BOOM" with a metallic bark, 0.3 s
		FireTail      = { Id = "" }, -- wide rolling echo 1 s, 40% volume
		Equip         = { Id = "" }, -- revolver twirl: "whirr-clatter-tk" (cylinder spinning), 0.35 s
		AimIn         = { Id = "" }, -- tiny tick. Optional
		AimOut        = { Id = "" }, -- tiny tick. Optional
		DryFire       = { Id = "" }, -- a revolver hammer "click-click"
		LowAmmo       = { Id = "" }, -- on EVERY shot at 1 round: a clear tick
		ReloadStart   = { Id = "" }, -- at 0.05 s: thumb on the cylinder latch
		CylinderOpen  = { Id = "" }, -- at 1.4 s: cylinder swings out "clk-SHK"
		CasingOut     = { Id = "" }, -- at 3.0 s: all spent brass rattles onto the floor "tinkle-tinkle", 0.4 s
		RoundIn       = { Id = "" }, -- plays ONCE PER MISSING ROUND, 0.42 s apart (up to 6): one round into a chamber "tk"
		CylinderClose = { Id = "" }, -- last beat: cylinder flicked shut "flick-CLACK"
	},

},

-- ================= FALLBACKS =================
-- When a slot has no sound anywhere, play another slot instead:  Slot = { "OtherSlot", pitchMultiplier, volumeMultiplier }
-- (this keeps the old generic reload sounds working until you add your own). Delete a line to make that slot silent.
Fallbacks = {
	Cycle         = { "Bolt", 1, 1 },
	CoverOpen     = { "Bolt", 0.75, 0.8 },
	CoverClose    = { "Bolt", 0.7, 1 },
	BeltIn        = { "MagIn", 1.8, 0.4 },
	BoltOpen      = { "Bolt", 0.9, 1 },
	BoltClose     = { "Bolt", 1, 1 },
	RoundIn       = { "MagIn", 1.5, 0.45 },
	ShellIn       = { "MagIn", 1.3, 0.5 },
	PumpBack      = { "Bolt", 1, 1 },
	PumpForward   = { "Bolt", 1, 1 },
	CylinderOpen  = { "MagOut", 1.2, 1 },
	CasingOut     = { "MagOut", 1.9, 0.8 },
	CylinderClose = { "MagIn", 1.1, 0.9 },
	-- v5.7
	MenuOpen      = { "Notify", 1.2, 0.8 },   -- loadout picker opens: the old Notify blip until you add your own
	LoadoutPick   = { "Notify", 1.5, 0.9 },
	ClimbGrab     = { "WallStart", 1, 1 },
	ClimbRelease  = { "WallJump", 0.8, 0.6 },
	LandHard      = { "Land", 0.7, 1.4 },
	GadPlace      = { "GadEquip", 0.8, 1 },
	GadThrow      = { "GadEquip", 1.3, 1 },
	GadPlaceTry   = { "GadEquip", 1.5, 0.5 },
	ReserveClose  = { "ReserveOpen", 0.85, 1 },
	ReserveSwap   = { "ReserveOpen", 1.2, 1 },
	ReviveStop    = { "ReviveStart", 0.8, 0.8 },
	SoulDrop      = { "SoulPickup", 0.85, 1 },
},
}
-- every gadget can have its own Equip / Throw / Place sound (GadEquip_FRAG ...); without one it uses the generic GadEquip / GadThrow / GadPlace
for _, id in GADGET_IDS do
	Bank.Fallbacks["GadEquip_" .. id] = { "GadEquip", 1, 1 }
	Bank.Fallbacks["GadThrow_" .. id] = { "GadThrow", 1, 1 }
	Bank.Fallbacks["GadPlace_" .. id] = { "GadPlace", 1, 1 }
end
-- (a few gadget slots live here so you can find them next to the others: per-gadget examples. Add more the same way.)
Bank.Gadgets.GadEquip_FRAG = { Id = "" }   -- the frag grenade in hand: a metal pin 'ting'
Bank.Gadgets.GadThrow_FRAG = { Id = "" }   -- frag thrown: lever 'ping' + arm whoosh
Bank.Gadgets.GadEquip_SENTRY = { Id = "" } -- sentry in hand: heavy gear clunk
Bank.Gadgets.GadPlace_SENTRY = { Id = "" } -- sentry set down: a heavy tripod 'CHUNK'
Bank.Gadgets.GadPlace_SHIELD = { Id = "" } -- shield projector set down: 'bonk' + rising hum
Bank.Gadgets.GadPlace_MINE = { Id = "" }   -- mine stuck on a surface: a magnetic 'clamp'

return Bank
