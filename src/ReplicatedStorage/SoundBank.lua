-- ============================================================================================================
-- SOUND BANK  -  every sound in the game lives here. Paste audio asset IDs (numbers only). "" = silent / use fallback.
--
-- HOW IT WORKS
--   * Each entry is   Name = { Id = "123456", Volume = 0.5, PitchMin = 0.95, PitchMax = 1.05, MaxDistance = 200 }
--     Only Id is needed. Everything else is optional.
--   * Want several variations picked at random?   Name = { Ids = { "111", "222", "333" }, Volume = 0.5 }
--   * PER-GUN SOUNDS: put them in the Guns section under that gun's internal ID (VX9, KR47, ...). A gun entry only
--     needs an Id; if you leave out Volume / Pitch / MaxDistance it uses the ones from Global with the same name.
--     If a gun has no sound for a slot, the game uses the Global sound with that name, and if there is none either,
--     it uses the Fallbacks table at the bottom (the old generic sounds).
--   * Sections below (Global, Combat, Movement, Boxes, Death, Match) are only for tidiness. Names must be unique
--     across them, but you can move an entry to another section without touching any code.
--
-- ADDING A BRAND NEW SOUND SLOT
--   1) Add a line in any section, e.g.   BoxSplash = { Id = "123", Volume = 0.6 },
--   2) Play it from any script:   Sfx.Play("BoxSplash")                     -- 2D (only you hear it)
--                                 Sfx.Play("BoxSplash", somePart)           -- 3D from a Part / Attachment
--                                 Sfx.Play("BoxSplash", Vector3.new(0,5,0)) -- 3D from a position
--                                 Sfx.Play("Fire", nil, nil, nil, "VX9")    -- use the M4A1's own version of a slot
--      (full signature: Sfx.Play(name, parent, pitchMultiplier, volumeMultiplier, gunId))
-- ============================================================================================================
return {

-- ================= GLOBAL: default gun sounds (used by every gun that has no sound of its own) =================
Global = {
	Fire        = { Id = "6862108495", Volume = 0.65, PitchMin = 0.96, PitchMax = 1.04 },
	FireTail    = { Id = "136262396813451", Volume = 0.30, PitchMin = 0.95, PitchMax = 1.05 },
	Equip       = { Id = "6042054037", Volume = 0.50 },
	ReloadStart = { Id = "6455642389", Volume = 0.40 },
	MagOut      = { Id = "6052548458", Volume = 0.55 },
	MagIn       = { Id = "6052548458", Volume = 0.60 },
	Bolt        = { Id = "6042054037", Volume = 0.60 },
	LowAmmo     = { Id = "135088937686823", Volume = 0.25, PitchMin = 1.1, PitchMax = 1.2 },
	-- special reload sounds: leave empty to use the Fallbacks (old generic sounds); fill in to change them for ALL guns
	Cycle         = { Id = "" },
	CoverOpen     = { Id = "" },
	CoverClose    = { Id = "" },
	BeltIn        = { Id = "" },
	BoltOpen      = { Id = "" },
	BoltClose     = { Id = "" },
	RoundIn       = { Id = "" },
	ShellIn       = { Id = "" },
	PumpBack      = { Id = "" },
	PumpForward   = { Id = "" },
	CylinderOpen  = { Id = "" },
	CasingOut     = { Id = "" },
	CylinderClose = { Id = "" },
},

-- ================= COMBAT =================
Combat = {
	Hit      = { Id = "130797915", Volume = 2.00, PitchMin = 0.97, PitchMax = 1.03 },  -- hitmarker (body)
	Headshot = { Id = "7269900245", Volume = 2.00, PitchMin = 1.00, PitchMax = 1.04 }, -- hitmarker (head)
	Kill     = { Id = "9123334926", Volume = 2.00, PitchMin = 1.00, PitchMax = 1.00 }, -- you killed someone
	Damaged  = { Id = "5718786992", Volume = 0.60 },                                   -- you got hit
	Impact   = { Id = "6700004586", Volume = 0.40, PitchMin = 0.9, PitchMax = 1.1, MaxDistance = 120 }, -- bullet hits a surface
},

-- ================= MOVEMENT =================
Movement = {
	Slide  = { Id = "138269837525273", Volume = 0.50 },
	Mantle = { Id = "120034381418358", Volume = 0.50 },
	Wind   = { Id = "93035214379043", Volume = 0.50 }, -- LOOPING wind rush at high speed (use a loopable sound)
},

-- ================= ROBOT BOXES (3D, played from the box) =================
-- All empty = silent (BoxBreak falls back to the old layered crunch).
Boxes = {
	BoxSpawn     = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- a new box appears
	BoxPickup    = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- someone picks up a loose box
	BoxExtract   = { Id = "", Volume = 0.7, MaxDistance = 150 }, -- someone rips a plugged box out of a hole
	BoxDrop      = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- dropped (Q)
	BoxThrow     = { Id = "", Volume = 0.7, MaxDistance = 150 }, -- thrown
	BoxLand      = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- a thrown box settles on the ground
	BoxPlugStart = { Id = "", Volume = 0.6, MaxDistance = 150 }, -- box starts floating into a hole
	BoxPlugged   = { Id = "", Volume = 0.8, MaxDistance = 200 }, -- box locks into the hole
	BoxHit       = { Id = "", Volume = 0.5, MaxDistance = 150, PitchMin = 0.92, PitchMax = 1.08 }, -- a plugged box takes a bullet (angry face)
	BoxCritical  = { Id = "", Volume = 0.7, MaxDistance = 150 }, -- box drops under 25% health
	BoxBreak     = { Id = "", Volume = 1.0, MaxDistance = 300 }, -- box destroyed (empty = old layered crunch)
},

-- ================= DEATH / SOULS =================
Death = {
	PlayerDeath     = { Id = "", Volume = 0.8, MaxDistance = 200 }, -- someone dies (3D, everyone near hears it)
	PlayerDeathSelf = { Id = "", Volume = 0.8 },                    -- YOU die (2D, only you)
	SoulBurst       = { Id = "", Volume = 0.6, MaxDistance = 200 }, -- souls burst out of the body
	SoulMeet        = { Id = "", Volume = 0.6, MaxDistance = 250 }, -- souls meet above the body (flash)
	SoulRocket      = { Id = "", Volume = 0.6, MaxDistance = 400 }, -- orb rockets into the sky (empty = Wind sound pitched up)
	SoulStar        = { Id = "", Volume = 0.6, MaxDistance = 1500 },-- the star glint in the sky
	SoulAbsorb      = { Id = "", Volume = 0.5, MaxDistance = 100 }, -- a soul flies into YOU when someone else dies nearby
	SoulAbsorbSelf  = { Id = "", Volume = 0.6 },                    -- souls rush into your screen on your own death
},

-- ================= MATCH / UI (2D) =================
Match = {
	RoundStart = { Id = "", Volume = 0.7 }, -- round begins
	RoundWin   = { Id = "", Volume = 0.8 }, -- your team won
	RoundLose  = { Id = "", Volume = 0.8 }, -- your team lost
	RoundOver  = { Id = "", Volume = 0.8 }, -- draw / no winner
	Countdown  = { Id = "", Volume = 0.6 }, -- ticks for the last 5 seconds before the round
	Notify     = { Id = "", Volume = 0.4 }, -- top banner messages ("RED took a box from BLUE", ...)
},

-- ================= PER-GUN SOUNDS =================
-- Keys = internal gun IDs. Fill in only what you want; empty = the Global sound (or Fallback) is used.
-- Optional per entry: Volume, PitchMin, PitchMax (otherwise copied from the Global entry of the same name).
Guns = {

	VX9 = { -- M4A1
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
	},

	KR47 = { -- AK-47
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
	},

	HX3 = { -- FAMAS
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
	},

	WASP = { -- WASP
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
	},

	ANVIL = { -- ANVIL
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
	},

	LONGSHOT = { -- LONGSHOT
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
	},

	HALO50 = { -- HALO-50
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
	},

	BREACHER = { -- BREACHER
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
	},

	V9 = { -- V9
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
	},

	MAGNUM = { -- .44 Magnum
		Fire          = { Id = "" }, -- one shot (your own gun is 2D, other players' guns play 3D from their head)
		FireTail      = { Id = "" }, -- tail / echo layered under every shot
		Cycle         = { Id = "" }, -- bolt / pump / slide cycling after a shot (bolt-action, shotgun, pistol)
		Equip         = { Id = "" }, -- pulling the gun out
		LowAmmo       = { Id = "" }, -- clicks when the mag is nearly empty
		ReloadStart   = { Id = "" }, -- reload begins
		MagOut        = { Id = "" }, -- mag leaves the gun (also used by M4A1, AK, FAMAS, WASP, LONGSHOT, V9, ANVIL)
		MagIn         = { Id = "" }, -- new mag goes in
		Bolt          = { Id = "" }, -- charging handle / racking the slide at the end of a reload
		CoverOpen     = { Id = "" }, -- ANVIL: feed cover opens
		CoverClose    = { Id = "" }, -- ANVIL: feed cover slams shut
		BeltIn        = { Id = "" }, -- ANVIL: belt links laid in
		BoltOpen      = { Id = "" }, -- HALO-50: bolt opens
		BoltClose     = { Id = "" }, -- HALO-50: bolt closes
		RoundIn       = { Id = "" }, -- HALO-50: each loose round pushed in (plays 5x)
		ShellIn       = { Id = "" }, -- BREACHER: each shell pushed in (plays 6x)
		PumpBack      = { Id = "" }, -- BREACHER: pump back
		PumpForward   = { Id = "" }, -- BREACHER: pump forward
		CylinderOpen  = { Id = "" }, -- .44 Magnum: cylinder swings out
		CasingOut     = { Id = "" }, -- .44 Magnum: spent casings dump out
		CylinderClose = { Id = "" }, -- .44 Magnum: cylinder flicks shut
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
},
}
