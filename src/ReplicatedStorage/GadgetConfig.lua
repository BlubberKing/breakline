-- GadgetConfig (v5.18: FRAG can be COOKED - cook = true, fuse 3.0 counted from the press; minFuse)
-- GadgetConfig (ModuleScript in ReplicatedStorage) - BREAKLINE place only. NEW in v4.0.
-- Every number of the 6 gadgets lives here. Ids match LobbyCatalog (FRAG, SMOKE, FLASH, SENTRY, SHIELD, MINE).
-- Used by GadgetServer (rules, damage) and GadgetClient (keys, effects).
-- v4.1: every gadget has a `kind`:
--   "throw" (frag / smoke / flash): press the key to EQUIP it (your gun is swapped for the grenade), CLICK to throw it, HOLD the click to see the
--                                   throw line. Press the key again / 1 / Q to put it away.
--   "place" (sentry / shield / mine): press the key to EQUIP it (a blue see-through copy follows your aim and can be dragged around, red = cannot
--                                   go there), CLICK to place it exactly there. Press the key again / 1 / Q to put it away.
--   charges   : how many you carry (full again after every respawn)
--   recharge  : seconds until ONE used charge comes back
--   cooldown  : seconds before you can throw the next one
--   speed     : throw speed in studs/s (v4.9: throwables ~115, see G.Throw for gravity / inherit / underhand)
local G = {}

G.Keys = { "Two", "Three", "Four" } -- loadout gadget slots 1 / 2 / 3 (matches the pre-game dock keys 2 / 3 / 4)

G.Items = {
	FRAG = {
		name = "Frag Grenade", kind = "throw", charges = 2, recharge = 24, cooldown = 0.9, speed = 118,
		fuse = 3.0, radius = 17, damage = 120, selfMult = 0.5, boxDamage = 260, shieldDamage = 220,
		projSize = 0.95, projColor = Color3.fromRGB(70, 92, 62),
		-- v5.18 COOK (owner): the fuse starts the moment you PRESS the click (the pin comes out), not when it leaves your hand. Release = throw
		-- (same throw as before) with whatever fuse is left. Hold it for the whole `fuse` and it goes off in your hand (selfMult still applies).
		-- fuse 2.3 -> 3.0 so a normal hold-aim-release throw still has about the old time in the air.
		cook = true, minFuse = 0.15, -- the shortest fuse a thrown (cooked) frag can get
	},
	SMOKE = {
		name = "Smoke Grenade", kind = "throw", charges = 2, recharge = 30, cooldown = 0.9, speed = 110,
		fuse = 1.0, radius = 15, duration = 13,
		projSize = 1.0, projColor = Color3.fromRGB(150, 160, 175),
	},
	FLASH = {
		name = "Flashbang", kind = "throw", charges = 2, recharge = 22, cooldown = 0.9, speed = 114,
		fuse = 1.25, range = 75, maxTime = 3.8,
		projSize = 0.9, projColor = Color3.fromRGB(250, 235, 140),
	},
	SENTRY = {
		name = "Sentry", kind = "place", charges = 1, recharge = 80, cooldown = 1.5, speed = 46,
		health = 170, life = 36, range = 62, rpm = 480, damage = 3.5, spread = 2.4, turn = 9, armTime = 0.9,
		projSize = 1.3, projColor = Color3.fromRGB(90, 190, 255),
	},
	SHIELD = {
		name = "Bubble Shield", kind = "place", charges = 1, recharge = 50, cooldown = 1.2, speed = 54,
		radius = 9.5, hp = 750, life = 16, expand = 0.45,
		projSize = 1.1, projColor = Color3.fromRGB(100, 220, 230),
	},
	MINE = {
		name = "Prox. Mine", kind = "place", charges = 2, recharge = 34, cooldown = 1.0, speed = 52,
		arm = 1.3, trigger = 8.5, delay = 0.35, radius = 13, damage = 100, boxDamage = 200, maxActive = 3, life = 75,
		projSize = 0.9, projColor = Color3.fromRGB(255, 130, 60),
	},
}

-- v4.1 throwing
G.Throw = {
	Up = 0.1,          -- extra upward angle added to your aim (server + the preview line use the same number). v4.9: 0.16 -> 0.1 (flatter, stronger)
	EquipTime = 0.28,  -- seconds the swap animation takes (you cannot throw before it is done)
	Windup = 0.12,     -- seconds between the release and the grenade leaving the hand (the arm whips forward meanwhile, for everybody)
	-- v4.9 stronger throws: before, ~70 studs/s against full Roblox gravity (196) only carried ~13 studs - it plopped out of your hand.
	Gravity = 78,      -- gravity on a thrown item while it FLIES (studs/s^2). After its first bounce it gets normal gravity again.
	Inherit = 0.6,     -- share of your own run velocity added to the throw (sprint-throws go further). Was 0.35.
	Side = 0.45,       -- studs to the right of your head the item starts (it leaves your throwing hand, not your eyes)
	Start = 1.6,       -- studs in front of your head it starts
	Bounce = 0.36,     -- speed kept on a bounce (preview line; the part uses Elasticity below)
	Elasticity = 0.3,
	UnderMult = 0.42,  -- RIGHT CLICK (when you are not aiming a throw) = short underhand toss: this share of the speed ...
	UnderUp = 0.3,     -- ... and this much extra upward angle
}

return G
