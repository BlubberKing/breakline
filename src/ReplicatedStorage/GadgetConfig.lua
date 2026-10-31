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
--   speed     : throw speed in studs/s
local G = {}

G.Keys = { "Two", "Three", "Four" } -- loadout gadget slots 1 / 2 / 3 (matches the pre-game dock keys 2 / 3 / 4)

G.Items = {
	FRAG = {
		name = "Frag Grenade", kind = "throw", charges = 2, recharge = 24, cooldown = 0.9, speed = 72,
		fuse = 2.3, radius = 17, damage = 120, selfMult = 0.5, boxDamage = 260, shieldDamage = 220,
		projSize = 0.95, projColor = Color3.fromRGB(70, 92, 62),
	},
	SMOKE = {
		name = "Smoke", kind = "throw", charges = 2, recharge = 30, cooldown = 0.9, speed = 64,
		fuse = 1.0, radius = 15, duration = 13,
		projSize = 1.0, projColor = Color3.fromRGB(150, 160, 175),
	},
	FLASH = {
		name = "Flashbang", kind = "throw", charges = 2, recharge = 22, cooldown = 0.9, speed = 68,
		fuse = 1.25, range = 75, maxTime = 3.8,
		projSize = 0.9, projColor = Color3.fromRGB(250, 235, 140),
	},
	SENTRY = {
		name = "Sentry", kind = "place", charges = 1, recharge = 80, cooldown = 1.5, speed = 46,
		health = 170, life = 36, range = 62, rpm = 540, damage = 7, spread = 2.2, turn = 9, armTime = 0.9,
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
	Up = 0.16,        -- extra upward angle added to your aim (server + the preview line use the same number)
	EquipTime = 0.28, -- seconds the swap animation takes (you cannot throw before it is done)
	Windup = 0.12,    -- seconds between the click and the grenade leaving the hand
}

return G
