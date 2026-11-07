-- GunSkins v1 (ModuleScript in ReplicatedStorage) - used by BOTH games (Lobby + Breakline). Keep the two copies identical. NEW in v5.10.
-- Gun skins repaint a gun: every part of a gun uses a small shared palette (GunModels.Colors: Body, Polymer, Metal, Steel, Wood ...), so a skin is a
-- THEME (new colours + materials for those palette roles) that works on all 10 guns without per-gun work. A skin belongs to ONE gun.
--   GunSkins.List / GunSkins.ById[id]      { id = "VX9_GILT", gun = "VX9", gunName = "M4A1", theme = "GILT", name = "GILT", sub = "M4A1", price = { souls = n } | { essence = n } }
--   GunSkins.ForGun(gunId)                 -> list of skins for that gun
--   GunSkins.Price(id)                     -> { souls = n } / { essence = n }
--   GunSkins.Apply(parts, skinId, palette) -> repaints a GunModels part list in place (GunModels.Describe calls this when you pass a skin id)
--   GunSkins.Equipped(player, gunId)       -> the skin id this player has equipped on that gun (Player attribute GunSkinsJson, set by the lobby), or nil
--   GunSkins.Owned(player, skinId)         -> bool (Player attribute GunSkinsOwnedJson)
-- Adding a skin: add a THEME below (if it is a new look) and put its id in GUN_THEMES for the gun. Prices come from the theme.
local HttpService = game:GetService("HttpService")

local M = {}
local rgb = Color3.fromRGB
local SP, METAL, NEON = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Neon

-- display names of the 10 guns (ids = WeaponConfig / LobbyCatalog ids)
M.GunNames = {
	VX9 = "M4A1", KR47 = "AK-47", HX3 = "FAMAS", WASP = "WASP", ANVIL = "ANVIL",
	LONGSHOT = "LONGSHOT", HALO50 = "HALO-50", BREACHER = "BREACHER", V9 = "V9", MAGNUM = ".44 Magnum",
}
M.GunOrder = { "VX9", "KR47", "HX3", "WASP", "ANVIL", "LONGSHOT", "HALO50", "BREACHER", "V9", "MAGNUM" }

-- ===== themes: colours for the palette roles + optional material / reflectance for the metal roles =====
--   body  = receivers / polymer      metal = barrel, slides, rails      steel = bright metal (pins, irons, chrome)      wood = stocks + handguards
--   steelMat / steelRefl / metalMat / metalRefl = material + shine of those parts      glow = true: the steel parts are Neon (lit accents)
M.Themes = {
	EMBER    = { name = "EMBER",    body = rgb(46, 34, 32),   metal = rgb(176, 84, 36),   steel = rgb(222, 128, 58),  wood = rgb(110, 36, 28),  steelMat = METAL, steelRefl = 0.12, price = { souls = 800 } },
	GLACIER  = { name = "GLACIER",  body = rgb(190, 202, 216), metal = rgb(120, 156, 196), steel = rgb(232, 240, 248), wood = rgb(96, 132, 176),  steelMat = METAL, steelRefl = 0.2,  price = { souls = 800 } },
	VERDANT  = { name = "VERDANT",  body = rgb(44, 62, 46),   metal = rgb(120, 112, 64),  steel = rgb(200, 176, 96),  wood = rgb(92, 60, 36),   steelMat = METAL, steelRefl = 0.1,  price = { souls = 900 } },
	BONEYARD = { name = "BONEYARD", body = rgb(222, 216, 198), metal = rgb(176, 168, 146), steel = rgb(240, 236, 224), wood = rgb(34, 42, 62),   steelMat = SP,    steelRefl = 0,    price = { souls = 1000 } },
	CRIMSON  = { name = "CRIMSON",  body = rgb(138, 22, 32),  metal = rgb(30, 30, 34),    steel = rgb(210, 214, 222), wood = rgb(24, 24, 28),   steelMat = METAL, steelRefl = 0.3,  metalMat = METAL, metalRefl = 0.12, price = { essence = 200 } },
	ABYSS    = { name = "ABYSS",    body = rgb(14, 28, 52),   metal = rgb(18, 80, 104),   steel = rgb(70, 232, 255),  wood = rgb(10, 40, 60),   glow = true, price = { essence = 250 } },
	GILT     = { name = "GILT",     body = rgb(24, 22, 24),   metal = rgb(196, 152, 58),  steel = rgb(255, 216, 108), wood = rgb(46, 22, 20),   steelMat = METAL, steelRefl = 0.35, metalMat = METAL, metalRefl = 0.22, price = { essence = 400 } },
	VOIDLIGHT = { name = "VOIDLIGHT", body = rgb(16, 12, 28), metal = rgb(70, 40, 120),   steel = rgb(190, 110, 255), wood = rgb(28, 16, 48),   glow = true, price = { essence = 450 } },
}

-- which themes each gun gets: 2 for souls (free currency) + 2 for essence (premium)
local GUN_THEMES = {
	VX9      = { "EMBER", "GLACIER", "CRIMSON", "GILT" },
	KR47     = { "VERDANT", "EMBER", "GILT", "VOIDLIGHT" },
	HX3      = { "GLACIER", "BONEYARD", "ABYSS", "CRIMSON" },
	WASP     = { "EMBER", "VERDANT", "VOIDLIGHT", "GILT" },
	ANVIL    = { "BONEYARD", "VERDANT", "CRIMSON", "ABYSS" },
	LONGSHOT = { "GLACIER", "BONEYARD", "ABYSS", "GILT" },
	HALO50   = { "BONEYARD", "EMBER", "VOIDLIGHT", "CRIMSON" },
	BREACHER = { "EMBER", "VERDANT", "CRIMSON", "GILT" },
	V9       = { "GLACIER", "EMBER", "VOIDLIGHT", "ABYSS" },
	MAGNUM   = { "VERDANT", "BONEYARD", "GILT", "CRIMSON" },
}

M.List, M.ById, M.ByGun = {}, {}, {}
for _, gun in M.GunOrder do
	M.ByGun[gun] = {}
	for _, tid in GUN_THEMES[gun] do
		local th = M.Themes[tid]
		local s = { id = gun .. "_" .. tid, gun = gun, gunName = M.GunNames[gun], theme = tid, name = th.name, sub = M.GunNames[gun], price = th.price, glow = th.glow == true }
		table.insert(M.List, s)
		table.insert(M.ByGun[gun], s)
		M.ById[s.id] = s
	end
end
function M.Is(id) return type(id) == "string" and M.ById[id] ~= nil end
function M.ForGun(gun) return M.ByGun[gun] or {} end
function M.Price(id) local s = M.ById[id]; return s and s.price or nil end

-- ===== painting =====
local function key(c) return ("%d,%d,%d"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)

local cache = {} -- theme id -> { [colour key] = { color, material, reflectance } }
local function themeMap(tid, pal)
	if cache[tid] then return cache[tid] end
	local th = M.Themes[tid]
	local map = {}
	local function put(name, color, mat, refl)
		local c = pal[name]
		if c then map[key(c)] = { color = color, mat = mat, refl = refl } end
	end
	local bm, br = th.bodyMat, th.bodyRefl
	put("Body", th.body:Lerp(BLACK, 0.14), bm, br)
	put("Polymer", th.body, bm, br)
	put("Gun", th.body:Lerp(WHITE, 0.08), bm, br)
	put("Stipple", th.body:Lerp(BLACK, 0.08), bm, br)
	-- most guns are mostly "Black" / "Dark" / "Rubber" (slides, receivers, slots, grips): those take a darker shade of the theme body colour
	put("Black", th.body:Lerp(BLACK, 0.38), bm, br)
	put("Dark", th.body:Lerp(BLACK, 0.52), bm, br)
	put("Rubber", th.body:Lerp(BLACK, 0.62), nil, nil)
	local mm, mr = th.metalMat, th.metalRefl
	put("Metal", th.metal, mm, mr)
	put("GunLight", th.metal:Lerp(WHITE, 0.22), mm, mr)
	local sm = th.glow and NEON or th.steelMat
	put("Steel", th.steel, sm, th.steelRefl)
	put("Chrome", th.steel:Lerp(WHITE, 0.22), sm, th.steelRefl)
	for _, n in { "Wood", "Olive", "Tan", "FDE", "OliveDrab" } do put(n, th.wood, nil, nil) end
	put("WoodLight", th.wood:Lerp(WHITE, 0.16), nil, nil)
	put("WoodDark", th.wood:Lerp(BLACK, 0.28), nil, nil)
	cache[tid] = map
	return map
end

-- parts = a GunModels part list ({ Color, Material, Reflectance, Tag, ... }); pal = GunModels.Colors
function M.Apply(parts, skinId, pal)
	local s = M.ById[skinId]
	if not s or not pal then return end
	local map = themeMap(s.theme, pal)
	for _, d in parts do
		if d.Tag ~= "Sight" and d.Color then
			local r = map[key(d.Color)]
			if r then
				d.Color = r.color
				if r.mat then d.Material = r.mat end
				if r.refl and r.refl > 0 then d.Reflectance = r.refl end
			end
		end
	end
end

-- ===== what a player has (set by the lobby, validated there) =====
local equippedCache = setmetatable({}, { __mode = "k" })
function M.Equipped(player, gunId)
	local raw = player:GetAttribute("GunSkinsJson")
	if type(raw) ~= "string" or raw == "" then return nil end
	local e = equippedCache[player]
	if not e or e.raw ~= raw then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		e = { raw = raw, map = (ok and type(t) == "table") and t or {} }
		equippedCache[player] = e
	end
	local id = e.map[gunId]
	if type(id) == "string" and M.ById[id] and M.ById[id].gun == gunId then return id end
	return nil
end

local ownedCache = setmetatable({}, { __mode = "k" })
function M.OwnedSet(player)
	local raw = player:GetAttribute("GunSkinsOwnedJson")
	local e = ownedCache[player]
	if not e or e.raw ~= raw then
		local set = {}
		local ok, t = pcall(HttpService.JSONDecode, HttpService, type(raw) == "string" and raw or "[]")
		if ok and type(t) == "table" then for _, id in t do set[id] = true end end
		e = { raw = raw, set = set }
		ownedCache[player] = e
	end
	return e.set
end
function M.Owned(player, skinId) return M.OwnedSet(player)[skinId] == true end

return M
