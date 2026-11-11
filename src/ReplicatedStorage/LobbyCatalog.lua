-- LobbyCatalog v2 (ModuleScript in ReplicatedStorage) - BOTH places, keep the two copies identical. v4.7: SHOP data (prices, descriptions, starter choices, ownership helpers) + the DASH movement ability.
-- (v1:) LobbyCatalog - LOBBY place only. Used by LobbyClient (UI) and LobbyServer (validation).
-- Every item you can put in a loadout slot. Weapon ids match WeaponConfig in Breakline (VX9 = M4A1, KR47 = AK-47, ...).
-- Gadgets (v4.0) and movement abilities (v3.8) are real. (MEDKIT + SCANNER placeholders were removed in v4.0.)
-- The icons are placeholder tiles (color + short glyph); swap drawItem in LobbyClient for real images later.
local K = {}

K.Weapons, K.Gadgets, K.Moves, K.ById = {}, {}, {}, {}

local function add(list, kind, id, name, sub, glyph, color)
	local item = { id = id, kind = kind, name = name, sub = sub, glyph = glyph, color = color }
	table.insert(list, item)
	K.ById[id] = item
end

local W = Color3.fromRGB
-- weapons (real ones from WeaponConfig)
add(K.Weapons, "weapon", "VX9", "M4A1", "Assault Rifle", "M4", W(255, 170, 40))
add(K.Weapons, "weapon", "KR47", "AK-47", "Assault Rifle", "AK", W(255, 140, 50))
add(K.Weapons, "weapon", "HX3", "FAMAS", "Burst Rifle", "FA", W(250, 190, 60))
add(K.Weapons, "weapon", "WASP", "WASP", "SMG", "WS", W(255, 205, 70))
add(K.Weapons, "weapon", "ANVIL", "ANVIL", "LMG", "AN", W(235, 110, 60))
add(K.Weapons, "weapon", "LONGSHOT", "LONGSHOT", "Marksman", "LS", W(120, 200, 255))
add(K.Weapons, "weapon", "HALO50", "HALO-50", "Sniper", "H5", W(90, 160, 255))
add(K.Weapons, "weapon", "BREACHER", "BREACHER", "Shotgun", "BR", W(240, 90, 80))
add(K.Weapons, "weapon", "V9", "V9", "Pistol", "V9", W(170, 180, 205))
add(K.Weapons, "weapon", "MAGNUM", ".44 Magnum", "Revolver", ".44", W(200, 160, 120))

-- gadgets (v4.0: REAL, built in Breakline: GadgetServer / GadgetClient, numbers in GadgetConfig; keys 2 / 3 / 4 in a match)
add(K.Gadgets, "gadget", "FRAG", "Frag Grenade", "Explosive, 2 charges", "FG", W(235, 90, 70))
add(K.Gadgets, "gadget", "SMOKE", "Smoke Grenade", "Blocks sight, 2 charges", "SM", W(150, 165, 190))
add(K.Gadgets, "gadget", "FLASH", "Flashbang", "Blinds who looks, 2 charges", "FL", W(250, 235, 140))
add(K.Gadgets, "gadget", "SENTRY", "Sentry", "Auto turret, 1 charge", "SN", W(90, 190, 255))
add(K.Gadgets, "gadget", "SHIELD", "Bubble Shield", "Throw: grows a dome, 1 charge", "SH", W(100, 220, 230))
add(K.Gadgets, "gadget", "MINE", "Prox. Mine", "Sticks + blows up, 2 charges", "PM", W(255, 130, 60))

-- special movement abilities (v3.8: REAL, built in AbilityClient). `icon` = UIKit.AbilityIcon id (small drawn graphic).
add(K.Moves, "move", "DASH", "Dash", "3 dashes, 10 s each", "DS", W(150, 235, 255))
add(K.Moves, "move", "DJUMP", "Double Jump", "Air jump", "DJ", W(90, 210, 255))
add(K.Moves, "move", "MJUMP", "Mega Jump", "Charge jump", "MJ", W(255, 200, 60))
add(K.Moves, "move", "WRUN", "Wall Run", "Run on walls", "WR", W(255, 120, 90))
add(K.Moves, "move", "WCLIMB", "Wall Climb", "Walls + ceilings", "WC", W(120, 230, 150))
for _, m in K.Moves do m.icon = m.id end

K.DefaultWeapon = "VX9"

-- ================= SHOP (v4.7) =================
-- Price = SOULS. Change any number here and the shop, the server check and the receipts all follow (prices are only ever read from this table).
K.Price = {
	-- guns
	V9 = 500, WASP = 800, VX9 = 900, KR47 = 1000, HX3 = 1100, MAGNUM = 1200, BREACHER = 1300, LONGSHOT = 1500, ANVIL = 1600, HALO50 = 2200,
	-- gadgets
	FRAG = 300, SMOKE = 300, FLASH = 300, MINE = 500, SHIELD = 700, SENTRY = 800,
	-- movement
	DJUMP = 700, DASH = 900, MJUMP = 900, WRUN = 1100, WCLIMB = 1100,
}

-- what a new player picks from on first join (weapon + movement) and what they always start with (gadgets: no choice)
K.Starter = {
	Weapons = { "VX9", "V9", "KR47" },
	Moves = { "DJUMP", "WCLIMB", "DASH" },
	Gadgets = { "FRAG", "FLASH", "SENTRY" },
}

-- text for the shop's detail panel. Guns show their real stats (WeaponConfig), gadgets their numbers (GadgetConfig); movement uses MoveStats below.
K.Desc = {
	FRAG = "Press 2 / 3 / 4 to equip it. Pressing the click pulls the pin and starts the fuse (cook it), hold to see the throw line, release to throw. Hold it too long and it goes off in your hand. Hurts everything in the blast, boxes and shields too.",
	SMOKE = "Throw it to drop a thick smoke cloud that blocks sight for everybody. Use it to cross open ground or to cover a box carry.",
	FLASH = "Blinds every enemy who is looking at the blast and deafens them for a moment. You are blinded too if you look at it.",
	SENTRY = "Place a small turret that tracks and shoots enemies on its own. It has health and a short lifetime, and enemies can destroy it.",
	SHIELD = "Place a projector that grows a bubble dome. Bullets from outside are stopped by the dome, shots from inside go through.",
	MINE = "Sticks where you place it, arms after a moment and blows up when an enemy walks close. You can have a few out at once.",
	DASH = "Press F to dash forward fast in the direction you are moving (or looking, when standing still). You carry 3 dashes and every dash you use takes 10 seconds to come back.",
	DJUMP = "Press SPACE a second time in the air for an extra jump. Short cooldown.",
	MJUMP = "Hold SPACE on the ground to charge, let go to launch. The longer you hold, the higher you fly. A quick tap is a normal jump.",
	WRUN = "Sprint into a wall to run up it, or jump next to a wall to run along it. A stamina bar drains while you run. SPACE on the wall = wall jump. You can still shoot.",
	WCLIMB = "Walk into a wall and hold on: you climb walls and even ceilings for as long as you like. SPACE jumps off, C lets go. You cannot shoot while climbing.",
}
K.MoveStats = {
	DASH = { { "Key", "F" }, { "Charges", "3" }, { "Recharge", "10 s per dash" }, { "Distance", "about 14 studs" }, { "Direction", "moving / looking" } },
	DJUMP = { { "Key", "SPACE in the air" }, { "Extra jump", "6.8 studs" }, { "Cooldown", "3.5 s" } },
	MJUMP = { { "Key", "hold SPACE" }, { "Jump height", "16 - 54 studs" }, { "Full charge", "1.3 s" }, { "Cooldown", "6 s" } },
	WRUN = { { "Key", "sprint into a wall" }, { "Run speed", "32" }, { "Stamina", "3.4 s of running" }, { "Can shoot", "yes" } },
	WCLIMB = { { "Key", "walk into a wall" }, { "Climb speed", "17" }, { "Cooldown", "3.5 s after letting go" }, { "Can shoot", "no" } },
}

-- Is this item in the player's collection? Ownership is saved in the profile (ProfileStore mirrors it to the Player attributes OwnedJson / StarterDone).
-- Until a player has made the starter pick (StarterDone) everything counts as owned (old saves, Studio tests); the server enforces the same rule.
local ownedCache = { raw = nil, set = {} }
function K.OwnedSet(player)
	local raw = player:GetAttribute("OwnedJson")
	if raw ~= ownedCache.raw then
		local set = {}
		local ok, t = pcall(function() return game:GetService("HttpService"):JSONDecode(raw or "[]") end)
		if ok and type(t) == "table" then for _, id in t do set[id] = true end end
		ownedCache.raw, ownedCache.set = raw, set
	end
	return ownedCache.set
end
function K.Owns(player, id)
	if player:GetAttribute("StarterDone") ~= true then return true end
	return K.OwnedSet(player)[id] == true
end

-- is `id` a real item (of this kind, or of any kind when kind is nil)?
function K.Is(id, kind)
	local it = type(id) == "string" and K.ById[id]
	if not it then return false end
	return kind == nil or it.kind == kind
end

return K
