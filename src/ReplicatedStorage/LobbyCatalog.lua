-- LobbyCatalog (ModuleScript in ReplicatedStorage) - LOBBY place only. Used by LobbyClient (UI) and LobbyServer (validation).
-- Every item you can put in a loadout slot. Weapon ids match WeaponConfig in Breakline (VX9 = M4A1, KR47 = AK-47, ...).
-- Gadgets are PLACEHOLDERS until they exist in Breakline. Movement abilities (v3.8) are real: AbilityClient.
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

-- gadgets (placeholders)
add(K.Gadgets, "gadget", "FRAG", "Frag Grenade", "Gadget", "FG", W(235, 90, 70))
add(K.Gadgets, "gadget", "SMOKE", "Smoke", "Gadget", "SM", W(150, 165, 190))
add(K.Gadgets, "gadget", "FLASH", "Flashbang", "Gadget", "FL", W(250, 235, 140))
add(K.Gadgets, "gadget", "SENTRY", "Sentry", "Gadget", "SN", W(90, 190, 255))
add(K.Gadgets, "gadget", "MEDKIT", "Medkit", "Gadget", "MK", W(80, 210, 130))
add(K.Gadgets, "gadget", "SCANNER", "Scanner", "Gadget", "SC", W(120, 120, 255))
add(K.Gadgets, "gadget", "MINE", "Prox. Mine", "Gadget", "PM", W(255, 130, 60))
add(K.Gadgets, "gadget", "SHIELD", "Shield", "Gadget", "SH", W(100, 220, 230))

-- special movement abilities (v3.8: REAL, built in AbilityClient). `icon` = UIKit.AbilityIcon id (small drawn graphic).
add(K.Moves, "move", "DJUMP", "Double Jump", "Air jump", "DJ", W(90, 210, 255))
add(K.Moves, "move", "MJUMP", "Mega Jump", "Charge jump", "MJ", W(255, 200, 60))
add(K.Moves, "move", "WRUN", "Wall Run", "Run on walls", "WR", W(255, 120, 90))
add(K.Moves, "move", "WCLIMB", "Wall Climb", "Walls + ceilings", "WC", W(120, 230, 150))
for _, m in K.Moves do m.icon = m.id end

K.DefaultWeapon = "VX9"

-- is `id` a real item (of this kind, or of any kind when kind is nil)?
function K.Is(id, kind)
	local it = type(id) == "string" and K.ById[id]
	if not it then return false end
	return kind == nil or it.kind == kind
end

return K
