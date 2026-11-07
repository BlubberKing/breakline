-- GunModels v3.1 (v5.10: optional gun SKIN - Describe / BuildViewmodel / BuildWorld take a GunSkins id as their last argument and repaint the gun with it) (v3: v4.8: FULL REMODEL - every gun rebuilt with real foregrips / hand rests, no glowing team parts, nothing floating, fingered gloves)
-- GunModels: procedural gun models + attachable sights. Replaces GunModelBuilder + RifleModel.
-- Gun space: origin = top of the pistol grip, -Z = downrange, +Y = up. Unit scale ~ one Roblox rifle.
-- Adding a gun: write Models.<ID> = function(k) ... end using the kit below. It MUST call
--   k.grip(cf), k.foreAt(x, palmY, z), k.magwell(cf), k.muzzle(pos), k.eject(pos), k.mount(cf), k.irons(aimPos, eye)
-- (v4.8: k.foreAt replaces k.fore. It says WHERE the left palm sits - the model must have a hand rest / foregrip right there.)
-- Parts after k.tag = "Iron" are folding iron sights (hidden when an optic is mounted). Iron front post top
-- must line up with the irons() aim height. Optional: k.view = { X, Y, Z, SprintRot } first-person hip tweak.
-- k.group = "mag" (reload anim), "cycle" (bolt/pump/slide anim), "cover" (ANVIL feed cover), "aux" (loose rounds for reloads), "gun" (default).
-- Sights: Iron (built into the gun) or an optic in Sights (mounted at k.mount, Iron-tagged parts get hidden).
-- v4.8: nothing glows any more (the old team-coloured Neon stripes are gone). SetAccent / TeamAccent are kept as harmless no-ops.
local GunModels = {}

-- v5.10: gun skins (ReplicatedStorage.GunSkins, optional - without it every gun just stays stock)
local GunSkins
do
	local holder = script.Parent
	local mod = holder and holder:FindFirstChild("GunSkins")
	if mod then
		local ok, res = pcall(require, mod)
		if ok then GunSkins = res end
	end
end

local V, CF = Vector3.new, CFrame.new
local rad = math.rad
local function ang(p, y, r) return CFrame.Angles(rad(p or 0), rad(y or 0), rad(r or 0)) end
local function P(x, y, z, rx, ry, rz) return CF(x, y, z) * ang(rx, ry, rz) end

local SP, NEON, METAL, GLASS, WOOD = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Metal, Enum.Material.Glass, Enum.Material.Wood
local CYL = Enum.PartType.Cylinder

local C = {
	Body    = Color3.fromRGB(34, 36, 41),   -- anodised receivers
	Polymer = Color3.fromRGB(46, 48, 53),
	Metal   = Color3.fromRGB(70, 74, 82),
	Steel   = Color3.fromRGB(120, 124, 132),
	Dark    = Color3.fromRGB(18, 18, 21),
	Wood    = Color3.fromRGB(112, 66, 36),
	Olive   = Color3.fromRGB(64, 72, 52),
	Tan     = Color3.fromRGB(150, 128, 96),
	Lens    = Color3.fromRGB(150, 200, 255),
	Reticle = Color3.fromRGB(255, 45, 45),
	Accent  = Color3.fromRGB(255, 140, 30), -- kept for other scripts (nothing on a gun uses it any more)
	Flash   = Color3.fromRGB(255, 200, 110),
	Glove   = Color3.fromRGB(30, 30, 34),
	GlovePad = Color3.fromRGB(52, 54, 60),
	Sleeve  = Color3.fromRGB(58, 70, 98),
	Gun       = Color3.fromRGB(56, 60, 68),
	GunLight  = Color3.fromRGB(96, 102, 112),
	Chrome    = Color3.fromRGB(172, 176, 184),
	Black     = Color3.fromRGB(9, 9, 11),
	WoodLight = Color3.fromRGB(142, 90, 52),
	WoodDark  = Color3.fromRGB(86, 50, 28),
	Brass     = Color3.fromRGB(205, 165, 72),
	Rubber    = Color3.fromRGB(26, 26, 29),
	Stipple   = Color3.fromRGB(38, 39, 44),
	FDE       = Color3.fromRGB(158, 136, 104),
	OliveDrab = Color3.fromRGB(78, 84, 62),
}
GunModels.Colors = C

-- first-person left hand drop used by GunClient (0.4 studs at the 0.78 viewmodel scale, in gun units). Every hand rest is built around this.
local DROP = 0.513

-- ================= KIT =================
local function newKit()
	local k = { parts = {}, pts = {}, group = "gun", tag = nil, view = {} }
	function k.box(name, size, cf, color, mat, extra)
		local d = { Name = name, Size = size, CF = cf, Color = color or C.Body, Material = mat or SP,
			Group = k.group, Tag = k.tag, Transparency = 0 }
		if extra then for key, v in pairs(extra) do d[key] = v end end
		table.insert(k.parts, d)
		return d
	end
	function k.cylZ(name, len, dia, cf, color, mat, extra)
		local e = { Shape = CYL }
		if extra then for key, v in pairs(extra) do e[key] = v end end
		return k.box(name, V(len, dia, dia), cf * ang(0, 90, 0), color, mat, e)
	end
	function k.cylX(name, len, dia, cf, color, mat)
		return k.box(name, V(len, dia, dia), cf, color, mat, { Shape = CYL })
	end
	function k.cylY(name, len, dia, cf, color, mat)
		return k.box(name, V(len, dia, dia), cf * ang(0, 0, 90), color, mat, { Shape = CYL })
	end
	-- v4.8: a flat inlay in the gun's own tones (this used to be a glowing team-colour stripe)
	function k.inlay(name, size, cf, color, mat)
		return k.box(name, size, cf, color or C.GunLight, mat or METAL)
	end
	-- 8-sided tube along Z (see-through middle)
	function k.ring(name, center, innerR, thick, depth, color)
		local R = innerR + thick / 2
		local len = 2 * R * math.tan(math.pi / 8) + 0.01
		for i = 0, 7 do
			k.box(name, V(len, thick, depth), center * CFrame.Angles(0, 0, i * math.pi / 4) * CF(0, R, 0), color or C.Body)
		end
	end
	function k.grip(cf) k.pts.Grip = cf; k.pts.RightGrip = cf * CF(0.2, 0.05, 0) end
	-- v4.8: where the LEFT PALM sits (first person: x, palmY, z in gun units; the model must have a hand rest there).
	-- tpx = how far to the left of that point the third-person hand sits.
	function k.foreAt(x, palmY, z, tpx)
		k.pts.Fore = CF(x, palmY + DROP, z)
		k.pts.Palm = CF(x, palmY, z)
		k.pts.LeftForegrip = CF(x + (tpx or -0.2), palmY + 0.03, z)
	end
	function k.magwell(cf) k.pts.MagPivot = cf; k.pts.LeftMagwell = cf * CF(-0.25, 0.08, 0) end
	function k.muzzle(pos) k.pts.Muzzle = CF(pos) end
	function k.eject(pos) k.pts.Eject = CF(pos) end
	function k.mount(cf) k.pts.Mount = cf end
	function k.irons(aimPos, eye) k.pts.IronAim = CF(aimPos); k.ironEye = eye end
	-- ===== detail helpers =====
	function k.find(name)
		for _, d in ipairs(k.parts) do if d.Name == name then return d end end
	end
	-- the same box on both sides of the gun (x > 0 = distance from the middle)
	function k.pair(name, size, x, y, z, color, mat, extra)
		k.box(name, size, CF(-x, y, z), color, mat, extra)
		k.box(name, size, CF(x, y, z), color, mat, extra)
	end
	-- a round band / ring around something that runs along Z
	function k.band(name, z, dia, len, y, color, mat, x)
		return k.cylZ(name, len, dia, CF(x or 0, y, z), color, mat)
	end
	-- screw / pin heads on both sides of the gun
	function k.pins(name, x, y, z, dia, color)
		k.cylX(name, 0.014, dia, CF(x, y, z), color or C.Chrome, METAL)
		k.cylX(name, 0.014, dia, CF(-x, y, z), color or C.Chrome, METAL)
	end
	-- n evenly spaced slots / vents on both sides
	function k.slots(name, x, y, z0, step, n, w, h, color)
		for i = 0, n - 1 do k.pair(name, V(0.014, h, w), x, y, z0 + i * step, color or C.Black) end
	end
	-- a tube that gets narrower: n stacked cylinders from (z0, d0) to (z1, d1)
	function k.taper(name, z0, z1, d0, d1, y, n, color, mat, x)
		local len = math.abs(z1 - z0) / n
		for i = 0, n - 1 do
			local t = (i + 0.5) / n
			k.cylZ(name, len + 0.004, d0 + (d1 - d0) * t, CF(x or 0, y, z0 + (z1 - z0) * t), color, mat)
		end
	end
	-- picatinny-style teeth along the top of a rail (z0 = first tooth, step may be negative)
	function k.teeth(name, y, z0, step, n, w, color)
		for i = 0, n - 1 do k.box(name, V(w, 0.02, 0.05), CF(0, y, z0 + i * step), color or C.Black) end
	end
	function k.remove(name)
		local kept = {}
		for _, d in ipairs(k.parts) do if d.Name ~= name then table.insert(kept, d) end end
		k.parts = kept
	end
	return k
end

-- aux parts: loose rounds / shells / casings used only by reload animations (hidden otherwise, not on the world gun)
local BRASS, SHELLRED = Color3.fromRGB(214, 168, 72), Color3.fromRGB(190, 52, 44)
local function addAux(k, firstId, n, len, dia, color)
	local g = k.group
	k.group = "aux"
	for i = 0, n - 1 do k.cylZ("Round", len, dia, CF(), color, METAL, { Aux = firstId + i }) end
	k.group = g
end

-- ===== shared pieces =====
local function stdGrip(k, color, z, tilt, big)
	z, tilt = z or 0.04, tilt or -16
	color = color or C.Polymer
	local g = P(0, -0.02, z, tilt)
	k.box("Grip", V(0.2, 0.52, 0.32), g, color)
	k.box("GripPanelR", V(0.012, 0.36, 0.2), g * CF(0.1, -0.03, 0.01), C.Rubber)
	k.box("GripPanelL", V(0.012, 0.36, 0.2), g * CF(-0.1, -0.03, 0.01), C.Rubber)
	for i = 0, 3 do k.box("GripGroove", V(0.196, 0.02, 0.014), g * CF(0, -0.15 + i * 0.1, -0.162), C.Black) end
	for r = 0, 2 do
		for c = 0, 1 do
			k.box("GripDot", V(0.014, 0.022, 0.022), g * CF(0.1, -0.12 + r * 0.1, -0.03 + c * 0.07), C.Black)
			k.box("GripDot", V(0.014, 0.022, 0.022), g * CF(-0.1, -0.12 + r * 0.1, -0.03 + c * 0.07), C.Black)
		end
	end
	k.box("GripBackstrap", V(0.17, 0.42, 0.034), g * CF(0, -0.02, 0.17), C.Black)
	k.box("Beavertail", V(0.17, 0.05, 0.2), P(0, 0.235, z + 0.15, -10), C.Black)
	k.box("GripCap", V(0.215, 0.032, 0.34), g * CF(0, -0.27, 0), C.Black)
	k.box("TriggerGuard", V(0.04, 0.035, 0.36), CF(0, 0.08, z - 0.26), C.Black)
	k.box("GuardFront", V(0.04, 0.16, 0.035), CF(0, 0.14, z - 0.425), C.Black)
	k.box("Trigger", V(0.03, 0.12, 0.045), P(0, 0.14, z - 0.2, -12), C.Chrome, METAL)
	k.grip(g)
end

-- a hand rest under the handguard. style: "afg" angled polymer grip | "vfg" slim vertical | "wood" wooden slab | "tube" rounded tactical
-- topY = where it clamps onto the gun, botY = bottom end, z = centre. The left palm should sit inside [botY, topY].
local function handRest(k, z, topY, botY, style, color, w)
	w = w or 0.17
	local h = topY - botY
	local cy = (topY + botY) / 2
	color = color or C.Polymer
	if style == "wood" then
		k.box("HandRest", V(w, h, 0.3), CF(0, cy, z), C.WoodLight, WOOD)
		k.box("HandRestCap", V(w + 0.01, 0.03, 0.31), CF(0, botY + 0.01, z), C.WoodDark, WOOD)
		for i = 0, 3 do k.box("HandRestGroove", V(w + 0.008, 0.016, 0.02), CF(0, botY + 0.1 + i * 0.07, z - 0.152), C.WoodDark, WOOD) end
		k.box("HandRestMount", V(w + 0.04, 0.05, 0.34), CF(0, topY - 0.01, z), C.Gun, METAL)
		return
	end
	local tilt = style == "afg" and -14 or 0
	local body = P(0, cy, z, tilt)
	if style == "tube" then
		k.cylY("HandRest", h, w, CF(0, cy, z), color)
		k.cylY("HandRestBand", 0.03, w + 0.02, CF(0, botY + 0.08, z), C.Black)
		k.cylY("HandRestBand", 0.03, w + 0.02, CF(0, cy, z), C.Black)
	else
		k.box("HandRest", V(w, h, style == "afg" and 0.22 or 0.18), body, color)
		for i = 0, 3 do k.box("HandRestGroove", V(w - 0.01, 0.02, 0.012), body * CF(0, -h * 0.5 + 0.1 + i * 0.1, -(style == "afg" and 0.112 or 0.092)), C.Black) end
		k.box("HandRestPanelR", V(0.012, h * 0.7, 0.14), body * CF(w * 0.5, -0.02, 0.0), C.Rubber)
		k.box("HandRestPanelL", V(0.012, h * 0.7, 0.14), body * CF(-w * 0.5, -0.02, 0.0), C.Rubber)
	end
	k.box("HandRestToe", V(w + 0.03, 0.03, style == "afg" and 0.26 or 0.22), P(0, botY + 0.01, z + (style == "afg" and 0.02 or 0), tilt), C.Black)
	k.box("HandRestMount", V(0.15, 0.07, 0.32), CF(0, topY - 0.02, z), C.Gun, METAL)
	k.box("HandRestLug", V(0.05, 0.09, 0.05), CF(0, topY - 0.06, z), C.GunLight, METAL)
end

-- ================= GUNS =================
local Models = {}

-- M4A1: carbine with a quad-rail handguard, angled foregrip, birdcage flash hider
function Models.VX9(k)
	stdGrip(k)
	-- receivers
	k.box("LowerReceiver", V(0.2, 0.22, 0.85), CF(0, 0.3, -0.2), C.Body, METAL)
	k.box("Magwell", V(0.19, 0.15, 0.3), CF(0, 0.16, -0.58), C.Body, METAL)
	k.box("MagwellFlare", V(0.215, 0.05, 0.34), CF(0, 0.205, -0.58), C.Body, METAL)
	k.box("UpperReceiver", V(0.22, 0.2, 1.05), CF(0, 0.5, -0.3), C.Gun, METAL)
	k.pair("UpperEdge", V(0.012, 0.012, 1.0), 0.104, 0.597, -0.3, C.GunLight, METAL)
	k.box("Rail", V(0.12, 0.04, 1.55), CF(0, 0.62, -0.6), C.Black, METAL)
	k.teeth("RailTooth", 0.65, -1.3, 0.16, 10, 0.14)
	k.box("EjectionPort", V(0.02, 0.09, 0.28), CF(0.112, 0.5, -0.2), C.Black)
	k.box("PortCover", V(0.01, 0.075, 0.2), CF(0.12, 0.515, -0.21), C.Gun, METAL)
	k.box("BrassDeflector", V(0.03, 0.06, 0.08), CF(0.12, 0.52, 0.0), C.Gun, METAL)
	k.box("ForwardAssist", V(0.04, 0.07, 0.07), CF(0.128, 0.47, 0.03), C.Gun, METAL)
	k.box("ChargingHandle", V(0.1, 0.04, 0.12), CF(0, 0.61, 0.19), C.Black)
	for _, sx in { -1, 1 } do k.box("ChargingLatch", V(0.03, 0.045, 0.07), CF(sx * 0.065, 0.61, 0.24), C.Black, METAL) end
	k.box("MagRelease", V(0.035, 0.06, 0.07), CF(0.117, 0.27, -0.5), C.Chrome, METAL)
	k.box("BoltCatch", V(0.025, 0.08, 0.045), CF(-0.115, 0.36, -0.18), C.Chrome, METAL)
	k.box("SelectorLever", V(0.016, 0.03, 0.11), CF(-0.119, 0.33, 0.09), C.Chrome, METAL)
	k.cylX("SelectorPivot", 0.016, 0.055, CF(-0.119, 0.33, 0.14), C.Chrome, METAL)
	k.pins("TakedownPin", 0.112, 0.4, -0.62, 0.045)
	k.pins("TakedownPin", 0.112, 0.38, 0.17, 0.045)
	-- barrel nut, delta ring, quad-rail handguard
	k.cylZ("BarrelNut", 0.3, 0.17, CF(0, 0.5, -0.95), C.Gun, METAL)
	k.band("DeltaRing", -1.07, 0.23, 0.05, 0.5, C.Gun, METAL)
	k.cylZ("Handguard", 1.0, 0.2, CF(0, 0.5, -1.55), C.Polymer)
	k.box("QuadBottom", V(0.09, 0.03, 0.92), CF(0, 0.39, -1.55), C.Black, METAL)
	k.pair("QuadSide", V(0.03, 0.09, 0.9), 0.103, 0.5, -1.55, C.Black, METAL)
	for i = 0, 5 do k.band("HandguardGroove", -1.22 - i * 0.16, 0.206, 0.014, 0.5, C.Black) end
	for i = 0, 3 do k.box("MLok", V(0.215, 0.03, 0.1), CF(0, 0.5, -1.2 - i * 0.22), C.Black) end
	k.band("HandguardCap", -2.04, 0.21, 0.05, 0.5, C.Black)
	-- barrel, gas block, flash hider
	k.cylZ("Barrel", 0.5, 0.08, CF(0, 0.5, -2.3), C.GunLight, METAL)
	k.band("GasBlock", -2.12, 0.12, 0.12, 0.5, C.Black)
	k.band("BarrelBand", -2.3, 0.1, 0.035, 0.5, C.Gun, METAL)
	k.band("BarrelBand", -2.42, 0.1, 0.035, 0.5, C.Gun, METAL)
	k.cylZ("MuzzleDevice", 0.24, 0.12, CF(0, 0.5, -2.62), C.Gun, METAL)
	k.band("MuzzleRing", -2.53, 0.13, 0.04, 0.5, C.Black)
	k.box("MuzzleSlotH", V(0.13, 0.016, 0.11), CF(0, 0.5, -2.67), C.Black)
	k.box("MuzzleSlotV", V(0.016, 0.13, 0.11), CF(0, 0.5, -2.67), C.Black)
	k.muzzle(V(0, 0.5, -2.76))
	-- stock
	k.cylZ("BufferTube", 0.62, 0.1, CF(0, 0.5, 0.52), C.Black)
	k.band("CastleNut", 0.23, 0.135, 0.05, 0.5, C.Gun, METAL)
	for i = 0, 2 do k.band("BufferRing", 0.38 + i * 0.12, 0.112, 0.025, 0.5, C.Black) end
	k.box("Stock", V(0.16, 0.28, 0.45), CF(0, 0.42, 0.88), C.Polymer)
	k.box("StockCheek", V(0.12, 0.03, 0.3), CF(0, 0.575, 0.88), C.Gun)
	k.box("StockRail", V(0.09, 0.04, 0.38), CF(0, 0.255, 0.9), C.Black)
	k.box("StockLever", V(0.04, 0.05, 0.1), CF(0, 0.3, 0.7), C.Black)
	k.box("ButtPad", V(0.18, 0.36, 0.06), CF(0, 0.4, 1.12), C.Rubber)
	for i = 0, 4 do k.box("PadRidge", V(0.19, 0.012, 0.075), CF(0, 0.27 + i * 0.07, 1.12), C.Black) end
	k.box("SlingLoop", V(0.05, 0.07, 0.04), CF(0, 0.3, 1.06), C.Black)
	-- hand rest + the palm point
	handRest(k, -1.45, 0.38, -0.2, "afg")
	k.foreAt(0, 0.05, -1.45)
	-- irons
	k.tag = "Iron"
	k.box("RearSightBase", V(0.08, 0.1, 0.08), CF(0, 0.69, 0.12), C.Black)
	k.ring("RearAperture", CF(0, 0.78, 0.12), 0.035, 0.025, 0.04, C.Black)
	k.box("FrontSightBase", V(0.07, 0.16, 0.06), CF(0, 0.61, -2.0), C.Black)
	k.box("FrontPost", V(0.02, 0.06, 0.02), CF(0, 0.72, -2.0), C.Black)
	k.tag = nil
	k.irons(V(0, 0.78, 0.12), 0.42)
	k.mount(CF(0, 0.66, -0.5))
	k.eject(V(0.13, 0.5, -0.2))
	-- magazine (STANAG)
	k.group = "mag"
	local m = P(0, -0.05, -0.58, 10)
	k.box("Mag", V(0.15, 0.5, 0.26), m, C.Polymer)
	k.box("MagBase", V(0.17, 0.04, 0.28), m * CF(0, -0.25, 0), C.Rubber)
	for i = 0, 4 do k.box("MagRib", V(0.156, 0.016, 0.2), m * CF(0, -0.17 + i * 0.075, 0), C.Black) end
	k.box("MagLip", V(0.13, 0.03, 0.24), m * CF(0, 0.25, 0), C.Metal, METAL)
	k.magwell(CF(0, -0.05, -0.58))
	k.group = "gun"
end

-- AK-47: wood furniture, slanted gas tube, banana mag, slab foregrip
function Models.KR47(k)
	stdGrip(k, C.Dark, 0.04, -20)
	k.box("Receiver", V(0.2, 0.26, 1.2), CF(0, 0.34, -0.3), C.Gun, METAL)
	k.box("Trunnion", V(0.21, 0.27, 0.12), CF(0, 0.335, -0.88), C.Gun, METAL)
	k.box("DustCover", V(0.19, 0.1, 1.0), CF(0, 0.52, -0.3), C.Body, METAL)
	for i = 0, 4 do k.box("CoverRib", V(0.198, 0.106, 0.03), CF(0, 0.52, -0.66 + i * 0.2), C.Gun, METAL) end
	k.box("RearTang", V(0.15, 0.09, 0.2), CF(0, 0.5, 0.26), C.Body)
	k.cylZ("GuideRod", 0.14, 0.032, CF(0, 0.505, 0.26), C.Chrome, METAL)
	k.box("Rail", V(0.1, 0.03, 0.4), CF(0, 0.59, -0.3), C.Black)
	k.box("Selector", V(0.02, 0.05, 0.45), CF(0.105, 0.4, -0.25), C.Chrome, METAL)
	k.box("SelectorTab", V(0.04, 0.03, 0.05), CF(0.12, 0.395, 0.0), C.Chrome, METAL)
	k.box("EjectionPort", V(0.02, 0.08, 0.26), CF(0.102, 0.48, -0.4), C.Black)
	for i = 0, 3 do
		k.pins("Rivet", 0.103, 0.28, -0.75 + i * 0.3, 0.03, C.GunLight)
		k.pins("Rivet", 0.103, 0.4, -0.7 + i * 0.3, 0.03, C.GunLight)
	end
	k.group = "cycle"
	k.box("ChargingHandle", V(0.1, 0.04, 0.05), CF(0.13, 0.5, -0.6), C.Steel, METAL)
	k.box("ChargingStem", V(0.03, 0.04, 0.05), CF(0.1, 0.5, -0.6), C.Steel, METAL)
	k.group = "gun"
	-- wood
	k.box("LowerGuard", V(0.22, 0.2, 0.75), CF(0, 0.36, -1.27), C.WoodLight, WOOD)
	k.box("UpperGuard", V(0.16, 0.09, 0.7), CF(0, 0.5, -1.27), C.WoodDark, WOOD)
	for i = 0, 2 do k.pair("WoodGrain", V(0.012, 0.012, 0.66), 0.11, 0.31 + i * 0.05, -1.27, C.WoodDark, WOOD) end
	k.box("RearFerrule", V(0.225, 0.22, 0.03), CF(0, 0.36, -0.91), C.Gun, METAL)
	k.box("FrontFerrule", V(0.23, 0.22, 0.035), CF(0, 0.36, -1.63), C.Gun, METAL)
	-- barrel group
	k.cylZ("Barrel", 1.0, 0.08, CF(0, 0.45, -2.2), C.GunLight, METAL)
	k.cylZ("GasTube", 0.6, 0.07, CF(0, 0.57, -1.9), C.Metal, METAL)
	k.box("GasBlock", V(0.1, 0.2, 0.08), CF(0, 0.52, -2.2), C.Black)
	k.band("GasClamp", -1.72, 0.1, 0.04, 0.57, C.Black)
	k.band("GasClamp", -2.08, 0.1, 0.04, 0.57, C.Black)
	k.band("BarrelBand", -1.9, 0.09, 0.035, 0.45, C.Gun, METAL)
	k.band("BarrelBand", -2.4, 0.09, 0.035, 0.45, C.Gun, METAL)
	k.cylZ("CleaningRod", 0.95, 0.026, CF(0, 0.385, -2.05), C.Chrome, METAL)
	k.band("RodCap", -2.54, 0.045, 0.03, 0.385, C.Black)
	k.box("FrontSightBlock", V(0.08, 0.2, 0.06), CF(0, 0.56, -2.62), C.Black)
	k.box("BayonetLug", V(0.05, 0.07, 0.09), CF(0, 0.4, -2.64), C.Black)
	k.band("BrakeBase", -2.72, 0.1, 0.03, 0.45, C.Gun, METAL)
	k.cylZ("MuzzleBrake", 0.18, 0.12, CF(0, 0.45, -2.8), C.Gun, METAL)
	k.box("BrakeSlot", V(0.13, 0.016, 0.1), CF(0, 0.45, -2.8), C.Black)
	k.muzzle(V(0, 0.45, -2.9))
	-- stock
	k.box("Stock", V(0.17, 0.28, 0.8), P(0, 0.28, 0.67, 6), C.WoodLight, WOOD)
	for i = 0, 2 do
		for _, sx in { -1, 1 } do k.box("StockGrain", V(0.012, 0.012, 0.66), P(sx * 0.087, 0.22 + i * 0.05, 0.67, 6), C.WoodDark, WOOD) end
	end
	k.box("ButtPad", V(0.18, 0.36, 0.06), P(0, 0.24, 1.08, 6), C.Rubber)
	-- hand rest (wooden slab foregrip) + palm point
	handRest(k, -1.3, 0.27, -0.14, "wood", nil, 0.17)
	k.foreAt(0, 0.07, -1.3)
	k.tag = "Iron"
	k.box("RearLeaf", V(0.1, 0.08, 0.12), CF(0, 0.61, -0.85), C.Black)
	for _, sx in { -1, 1 } do k.box("RearEar", V(0.03, 0.07, 0.04), CF(sx * 0.04, 0.675, -0.85), C.Black) end
	k.box("FrontPost", V(0.02, 0.1, 0.02), CF(0, 0.66, -2.62), C.Black)
	k.tag = nil
	k.irons(V(0, 0.71, -0.85), 0.6)
	k.mount(CF(0, 0.605, -0.3))
	k.eject(V(0.12, 0.48, -0.4))
	k.group = "mag"
	k.box("Mag", V(0.14, 0.36, 0.26), P(0, 0.06, -0.62, 8), C.Stipple)
	k.box("MagMid", V(0.14, 0.14, 0.255), P(0, -0.09, -0.665, 16), C.Stipple)
	k.box("MagLow", V(0.14, 0.32, 0.24), P(0, -0.22, -0.72, 24), C.Stipple)
	for _, yy in { -0.1, 0, 0.1 } do
		k.box("MagRib", V(0.146, 0.016, 0.2), P(0, 0.06, -0.62, 8) * CF(0, yy, 0), C.Black)
		k.box("MagRib", V(0.146, 0.016, 0.2), P(0, -0.22, -0.72, 24) * CF(0, yy, 0), C.Black)
	end
	k.box("MagBase", V(0.16, 0.04, 0.27), P(0, -0.38, -0.79, 24), C.Rubber)
	k.magwell(CF(0, 0.14, -0.6))
	k.group = "gun"
end

-- FAMAS: bullpup, tall one-piece body with a carry-handle channel, forend with folded bipod, big finger guard
function Models.HX3(k)
	stdGrip(k, C.Dark, -0.3, -12)
	-- the one-piece polymer body (rear stock block, middle receiver block, forend)
	k.box("StockBlock", V(0.19, 0.33, 0.62), P(0, 0.4, 0.3, -2), C.OliveDrab)
	k.box("Body", V(0.2, 0.3, 0.78), CF(0, 0.39, -0.37), C.OliveDrab)
	k.box("Forend", V(0.17, 0.2, 0.62), CF(0, 0.36, -1.03), C.OliveDrab)
	k.box("ForendTaper", V(0.15, 0.16, 0.2), CF(0, 0.36, -1.4), C.OliveDrab)
	k.pair("SidePlate", V(0.012, 0.22, 0.9), 0.1, 0.39, -0.3, C.Gun, METAL)
	k.box("Spine", V(0.14, 0.06, 1.35), CF(0, 0.535, -0.2), C.Gun, METAL)
	k.box("Rail", V(0.09, 0.03, 0.9), CF(0, 0.575, -0.3), C.Black)
	k.teeth("RailTooth", 0.595, -0.7, 0.15, 6, 0.1)
	k.box("Cheek", V(0.14, 0.06, 0.36), CF(0, 0.555, 0.38), C.Black)
	k.box("CheekPad", V(0.12, 0.025, 0.3), CF(0, 0.58, 0.38), C.Rubber)
	k.box("ButtPad", V(0.19, 0.34, 0.07), P(0, 0.37, 0.62, -2), C.Rubber)
	for i = 0, 4 do k.box("PadRidge", V(0.195, 0.012, 0.075), P(0, 0.22 + i * 0.065, 0.62, -2), C.Black) end
	-- big FAMAS finger guard (oversized trigger guard ring)
	k.box("FingerGuardFront", V(0.05, 0.2, 0.04), CF(0, 0.14, -0.78), C.OliveDrab)
	k.box("FingerGuardBottom", V(0.05, 0.04, 0.5), CF(0, 0.04, -0.52), C.OliveDrab)
	for i = 0, 2 do k.pair("Vent", V(0.014, 0.15, 0.03), 0.101, 0.37, -0.8 - i * 0.055, C.Black) end
	k.box("ChargeSlot", V(0.03, 0.02, 0.5), CF(0, 0.565, -0.1), C.Black)
	k.box("Selector", V(0.016, 0.04, 0.12), CF(-0.105, 0.3, 0.2), C.Chrome, METAL)
	k.cylX("MagRelease", 0.02, 0.05, CF(0.105, 0.2, 0.2), C.Chrome, METAL)
	k.box("EjectionPort", V(0.014, 0.08, 0.14), CF(0.103, 0.45, 0.3), C.Black)
	k.pins("BodyPin", 0.103, 0.46, -0.55, 0.035)
	k.pins("BodyPin", 0.103, 0.3, 0.45, 0.035)
	-- folded bipod legs along the forend
	k.cylZ("BipodLegR", 0.6, 0.03, CF(0.098, 0.3, -1.05), C.Gun, METAL)
	k.cylZ("BipodLegL", 0.6, 0.03, CF(-0.098, 0.3, -1.05), C.Gun, METAL)
	k.box("BipodPivot", V(0.2, 0.05, 0.05), CF(0, 0.3, -0.76), C.Black)
	-- barrel + flash hider
	k.cylZ("Barrel", 0.4, 0.07, CF(0, 0.42, -1.5), C.GunLight, METAL)
	k.band("GasBlock", -1.38, 0.1, 0.1, 0.42, C.Black)
	k.band("BarrelBand", -1.58, 0.085, 0.03, 0.42, C.Gun, METAL)
	k.cylZ("FlashHider", 0.2, 0.1, CF(0, 0.42, -1.72), C.Gun, METAL)
	k.band("FlashRing", -1.65, 0.115, 0.03, 0.42, C.Gun, METAL)
	k.box("MuzzleSlotH", V(0.105, 0.016, 0.11), CF(0, 0.42, -1.76), C.Black)
	k.box("MuzzleSlotV", V(0.016, 0.105, 0.11), CF(0, 0.42, -1.76), C.Black)
	k.muzzle(V(0, 0.42, -1.84))
	-- hand rest: moulded finger-groove grip on the forend
	handRest(k, -0.98, 0.26, -0.1, "vfg", C.OliveDrab, 0.17)
	k.foreAt(0, 0.07, -0.98)
	-- carry-handle channel (hides with an optic)
	k.tag = "Iron"
	for _, sx in { -1, 1 } do k.box("HandleWall", V(0.03, 0.08, 1.0), CF(sx * 0.06, 0.605, -0.2), C.Gun, METAL) end
	k.box("HandleBridgeRear", V(0.15, 0.05, 0.1), CF(0, 0.65, 0.3), C.Gun, METAL)
	k.box("HandleBridgeFront", V(0.15, 0.05, 0.1), CF(0, 0.65, -0.86), C.Gun, METAL)
	k.box("RearSight", V(0.03, 0.07, 0.04), CF(0, 0.615, 0.3), C.Black)
	k.box("FrontBase", V(0.05, 0.12, 0.05), CF(0, 0.565, -0.86), C.Black)
	k.box("FrontPost", V(0.02, 0.04, 0.02), CF(0, 0.63, -0.86), C.Black)
	k.tag = nil
	k.irons(V(0, 0.65, 0.3), 0.4)
	k.mount(CF(0, 0.59, -0.3))
	k.eject(V(0.11, 0.45, 0.3))
	-- magazine behind the grip
	k.box("Magwell", V(0.16, 0.13, 0.3), CF(0, 0.2, 0.4), C.OliveDrab)
	k.group = "mag"
	local m = P(0, 0.05, 0.4, 8)
	k.box("Mag", V(0.13, 0.42, 0.24), m, C.Dark)
	k.box("MagBase", V(0.15, 0.04, 0.26), m * CF(0, -0.21, 0), C.Rubber)
	for i = 0, 3 do k.box("MagRib", V(0.136, 0.016, 0.2), m * CF(0, -0.14 + i * 0.09, 0), C.Black) end
	k.magwell(CF(0, 0.15, 0.4))
	k.group = "gun"
end

-- MP7: short PDW, fold-out vertical grip, suppressor, folding stock
function Models.WASP(k)
	stdGrip(k, C.Dark, 0.04, -12)
	k.box("Upper", V(0.2, 0.26, 1.1), CF(0, 0.44, -0.35), C.Polymer)
	k.box("Lower", V(0.17, 0.14, 0.92), CF(0, 0.25, -0.38), C.Polymer)
	k.box("Magwell", V(0.16, 0.1, 0.24), CF(0, 0.16, -0.6), C.Dark)
	k.box("Shroud", V(0.18, 0.2, 0.5), P(0, 0.38, -1.05, -6), C.Body)
	k.box("Rail", V(0.1, 0.03, 0.8), CF(0, 0.59, -0.35), C.Black)
	k.teeth("RailTooth", 0.61, -0.65, 0.15, 5, 0.12)
	k.pair("SidePlate", V(0.012, 0.18, 0.7), 0.101, 0.44, -0.35, C.Gun, METAL)
	k.box("EjectPort", V(0.014, 0.08, 0.18), CF(0.103, 0.46, -0.28), C.Black)
	k.pins("HingePin", 0.11, 0.44, 0.18, 0.05)
	k.pins("BodyPin", 0.102, 0.34, -0.5, 0.035)
	k.box("SelectorLever", V(0.016, 0.03, 0.1), CF(-0.102, 0.34, 0.0), C.Chrome, METAL)
	k.slots("Vent", 0.092, 0.38, -0.9, -0.08, 4, 0.04, 0.12)
	k.group = "cycle"
	k.box("ChargingKnob", V(0.07, 0.06, 0.12), CF(0.125, 0.5, -0.1), C.Steel, METAL)
	k.box("ChargingStem", V(0.03, 0.05, 0.08), CF(0.1, 0.5, -0.1), C.Steel, METAL)
	k.group = "gun"
	-- suppressor
	k.cylZ("Suppressor", 0.55, 0.12, CF(0, 0.4, -1.55), C.Gun, METAL)
	k.band("SuppMount", -1.27, 0.14, 0.05, 0.4, C.Gun, METAL)
	for i = 0, 3 do k.band("SuppBand", -1.36 - i * 0.14, 0.128, 0.03, 0.4, C.Black) end
	k.band("SuppCap", -1.8, 0.126, 0.05, 0.4, C.Black)
	k.muzzle(V(0, 0.4, -1.84))
	-- folding stock
	k.box("StockArmR", V(0.025, 0.06, 0.66), CF(0.08, 0.46, 0.5), C.Dark)
	k.box("StockArmL", V(0.025, 0.06, 0.66), CF(-0.08, 0.46, 0.5), C.Dark)
	k.box("ButtPlate", V(0.18, 0.28, 0.05), CF(0, 0.42, 0.84), C.Rubber)
	for i = 0, 3 do k.box("PadRidge", V(0.18, 0.012, 0.075), CF(0, 0.3 + i * 0.06, 0.84), C.Black) end
	-- fold-out vertical foregrip (palm point inside it)
	handRest(k, -1.0, 0.3, -0.16, "tube", C.Polymer, 0.14)
	k.foreAt(0, 0.07, -1.0)
	k.tag = "Iron"
	k.box("RearBase", V(0.09, 0.07, 0.04), CF(0, 0.605, 0.12), C.Black)
	for _, sx in { -1, 1 } do k.box("RearEar", V(0.024, 0.07, 0.04), CF(sx * 0.04, 0.665, 0.12), C.Black) end
	k.box("FrontBase", V(0.04, 0.12, 0.04), CF(0, 0.54, -1.1), C.Black)
	k.box("FrontSight", V(0.024, 0.07, 0.024), CF(0, 0.635, -1.1), C.Black)
	k.tag = nil
	k.irons(V(0, 0.67, 0.12), 0.42)
	k.mount(CF(0, 0.605, -0.35))
	k.eject(V(0.11, 0.46, -0.3))
	k.group = "mag"
	local m = P(0, -0.08, -0.6, 4)
	k.box("Mag", V(0.13, 0.46, 0.2), m, C.Dark)
	k.box("MagBase", V(0.15, 0.04, 0.22), m * CF(0, -0.23, 0), C.Rubber)
	for i = 0, 3 do k.box("MagRib", V(0.136, 0.016, 0.16), m * CF(0, -0.15 + i * 0.09, 0), C.Black) end
	k.magwell(CF(0, 0.05, -0.6))
	k.group = "gun"
end

-- M249 SAW: belt-fed LMG, box mag, bipod, heat shield, tubular vertical grip
function Models.ANVIL(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.24, 0.3, 1.36), CF(0, 0.38, -0.32), C.Gun, METAL)
	-- v7: the feed cover used to carry the sight rail with it and swung up THROUGH the scope. Now the rail + plate stay put and only the
	-- right-hand flap (hinged on the outer edge, opens sideways and flat) lifts, so nothing mounted on top is ever in its way.
	k.box("FeedCoverFixed", V(0.18, 0.08, 0.7), CF(-0.03, 0.57, -0.25), C.Metal, METAL)
	for i = 0, 3 do k.box("CoverRib", V(0.186, 0.085, 0.03), CF(-0.03, 0.57, -0.5 + i * 0.15), C.Gun, METAL) end
	k.box("CoverLatch", V(0.1, 0.05, 0.06), CF(0, 0.6, -0.6), C.Black)
	k.box("Rail", V(0.12, 0.03, 0.6), CF(0, 0.625, -0.25), C.Black)
	k.group = "cover"
	k.box("FeedFlap", V(0.06, 0.08, 0.7), CF(0.09, 0.57, -0.25), C.Metal, METAL)
	k.box("FlapRib", V(0.066, 0.085, 0.03), CF(0.09, 0.57, -0.35), C.Gun, METAL)
	k.box("FlapRib", V(0.066, 0.085, 0.03), CF(0.09, 0.57, -0.05), C.Gun, METAL)
	k.group = "gun"
	k.pair("Rivet", V(0.016, 0.035, 0.035), 0.123, 0.46, -0.85, C.GunLight, METAL)
	k.pair("Rivet", V(0.016, 0.035, 0.035), 0.123, 0.3, -0.85, C.GunLight, METAL)
	k.pair("Rivet", V(0.016, 0.035, 0.035), 0.123, 0.46, -0.45, C.GunLight, METAL)
	k.pair("Rivet", V(0.016, 0.035, 0.035), 0.123, 0.3, -0.45, C.GunLight, METAL)
	k.box("EjectPort", V(0.014, 0.1, 0.26), CF(0.122, 0.4, -0.1), C.Black)
	k.box("Handguard", V(0.22, 0.2, 0.6), CF(0, 0.36, -1.28), C.Polymer)
	k.slots("Vent", 0.112, 0.36, -1.1, -0.08, 5, 0.04, 0.12)
	k.box("BipodMount", V(0.16, 0.1, 0.1), CF(0, 0.31, -1.62), C.Black)
	k.box("HeatShield", V(0.18, 0.05, 0.7), CF(0, 0.5, -1.6), C.GunLight, METAL)
	for i = 0, 7 do k.box("ShieldVent", V(0.1, 0.012, 0.04), CF(0, 0.527, -1.3 - i * 0.08), C.Black) end
	k.cylZ("Barrel", 1.1, 0.12, CF(0, 0.42, -2.15), C.GunLight, METAL)
	for i = 0, 4 do k.band("BarrelFin", -2.0 - i * 0.1, 0.15, 0.025, 0.42, C.Gun, METAL) end
	k.box("BarrelHandle", V(0.04, 0.1, 0.3), CF(0, 0.53, -1.95), C.Black)
	k.cylZ("BipodLegR", 0.7, 0.035, CF(0.07, 0.25, -1.9), C.Black)
	k.cylZ("BipodLegL", 0.7, 0.035, CF(-0.07, 0.25, -1.9), C.Black)
	k.pair("BipodFoot", V(0.06, 0.05, 0.07), 0.07, 0.25, -2.27, C.Black)
	k.cylZ("FlashHider", 0.22, 0.15, CF(0, 0.42, -2.8), C.Gun, METAL)
	k.box("MuzzleSlotH", V(0.15, 0.016, 0.11), CF(0, 0.42, -2.82), C.Black)
	k.box("MuzzleSlotV", V(0.016, 0.15, 0.11), CF(0, 0.42, -2.82), C.Black)
	k.muzzle(V(0, 0.42, -2.93))
	k.box("Stock", V(0.18, 0.3, 0.76), CF(0, 0.32, 0.72), C.Polymer)
	k.box("StockGroove", V(0.186, 0.012, 0.5), CF(0, 0.25, 0.72), C.Black)
	k.box("StockGroove", V(0.186, 0.012, 0.5), CF(0, 0.39, 0.72), C.Black)
	k.box("ButtPad", V(0.2, 0.38, 0.07), CF(0, 0.3, 1.12), C.Rubber)
	for i = 0, 4 do k.box("PadRidge", V(0.2, 0.012, 0.075), CF(0, 0.16 + i * 0.07, 1.12), C.Black) end
	k.box("RearSightBase", V(0.1, 0.1, 0.06), CF(0, 0.58, 0.2), C.Black)
	handRest(k, -1.3, 0.26, -0.18, "tube", C.Polymer, 0.16)
	k.foreAt(0, 0.04, -1.3)
	k.tag = "Iron"
	k.box("RearSight", V(0.1, 0.08, 0.04), CF(0, 0.66, 0.2), C.Black)
	for _, sx in { -1, 1 } do k.box("RearEar", V(0.02, 0.06, 0.04), CF(sx * 0.04, 0.7, 0.2), C.Black) end
	k.box("FrontBase", V(0.05, 0.2, 0.05), CF(0, 0.58, -2.5), C.Black)
	k.box("FrontPost", V(0.02, 0.05, 0.02), CF(0, 0.705, -2.5), C.Black)
	k.tag = nil
	k.irons(V(0, 0.73, 0.2), 0.45)
	k.mount(CF(0, 0.64, -0.25))
	k.eject(V(0.14, 0.45, -0.2))
	k.group = "mag"
	k.box("Mag", V(0.34, 0.36, 0.4), CF(-0.03, 0.0, -0.55), C.OliveDrab)
	k.box("MagBase", V(0.36, 0.04, 0.42), CF(-0.03, -0.19, -0.55), C.Rubber)
	for i = 0, 3 do
		k.box("BoxRib", V(0.012, 0.3, 0.03), CF(-0.03 + 0.176, 0, -0.7 + i * 0.1), C.Black)
		k.box("BoxRib", V(0.012, 0.3, 0.03), CF(-0.03 - 0.176, 0, -0.7 + i * 0.1), C.Black)
	end
	k.box("BoxHandle", V(0.2, 0.03, 0.04), CF(-0.03, 0.195, -0.72), C.Black)
	k.box("BeltStub", V(0.06, 0.07, 0.3), CF(-0.03, 0.2, -0.55), C.Brass, METAL)
	k.magwell(CF(0, 0.1, -0.55))
	k.group = "aux"
	for i = 0, 3 do k.box("BeltLink", V(0.05, 0.05, 0.1), CF(), BRASS, METAL, { Aux = i + 1 }) end
	k.group = "gun"
end

-- M14 EBR: tan chassis, vented guard with rail, adjustable stock, vertical grip
function Models.LONGSHOT(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.2, 0.28, 1.3), CF(0, 0.34, -0.3), C.FDE)
	k.pins("ReceiverPin", 0.103, 0.3, -0.7, 0.035)
	k.pins("ReceiverPin", 0.103, 0.3, 0.1, 0.035)
	k.box("OpRodChannel", V(0.012, 0.04, 0.6), CF(0.102, 0.43, -0.8), C.Black)
	k.box("Rail", V(0.12, 0.04, 1.4), CF(0, 0.5, -0.5), C.Black)
	k.teeth("RailTooth", 0.53, -1.1, 0.16, 8, 0.14)
	k.box("Handguard", V(0.2, 0.2, 0.9), CF(0, 0.38, -1.38), C.FDE)
	for _, sx in { -1, 1 } do
		for i = 0, 3 do k.box("Vent", V(0.02, 0.08, 0.13), CF(sx * 0.102, 0.38, -1.1 - i * 0.2), C.Black) end
	end
	k.box("HandguardRail", V(0.1, 0.03, 0.8), CF(0, 0.495, -1.38), C.Black)
	for i = 0, 5 do k.box("RailTooth", V(0.12, 0.016, 0.045), CF(0, 0.51, -1.05 - i * 0.12), C.Black) end
	for i = 0, 4 do k.box("Mlok", V(0.07, 0.012, 0.09), CF(0, 0.28, -1.0 - i * 0.17), C.Black) end
	k.group = "cycle"
	k.box("OpRodHandle", V(0.07, 0.07, 0.16), CF(0.13, 0.42, -0.3), C.Steel, METAL)
	k.box("OpRodStem", V(0.04, 0.05, 0.08), CF(0.1, 0.42, -0.3), C.Steel, METAL)
	k.group = "gun"
	k.cylZ("Barrel", 1.0, 0.09, CF(0, 0.4, -2.3), C.GunLight, METAL)
	k.band("GasBlock", -1.9, 0.11, 0.1, 0.4, C.Black)
	k.band("BarrelBand", -2.2, 0.1, 0.035, 0.4, C.Gun, METAL)
	k.band("BarrelBand", -2.5, 0.1, 0.035, 0.4, C.Gun, METAL)
	k.box("MuzzleBrake", V(0.12, 0.12, 0.25), CF(0, 0.4, -2.85), C.Gun, METAL)
	k.slots("BrakePort", 0.062, 0.4, -2.78, -0.07, 3, 0.03, 0.08)
	k.cylZ("BrakeNeck", 0.2, 0.09, CF(0, 0.4, -2.65), C.Gun, METAL)
	k.muzzle(V(0, 0.4, -2.98))
	k.box("Stock", V(0.17, 0.3, 0.8), CF(0, 0.3, 0.75), C.Dark)
	k.box("CheekRiser", V(0.14, 0.08, 0.35), CF(0, 0.48, 0.75), C.FDE)
	k.pins("CheekScrew", 0.072, 0.48, 0.62, 0.03, C.Chrome)
	k.box("ButtPad", V(0.2, 0.38, 0.07), CF(0, 0.28, 1.17), C.Rubber)
	for i = 0, 4 do k.box("PadRidge", V(0.2, 0.012, 0.075), CF(0, 0.12 + i * 0.07, 1.17), C.Black) end
	handRest(k, -1.4, 0.28, -0.14, "vfg", C.Dark, 0.16)
	k.foreAt(0, 0.07, -1.4)
	k.tag = "Iron"
	k.box("RearBase", V(0.08, 0.06, 0.06), CF(0, 0.55, 0.2), C.Black)
	k.ring("RearAperture", CF(0, 0.63, 0.2), 0.035, 0.025, 0.04, C.Black)
	k.box("FrontBase", V(0.06, 0.14, 0.05), CF(0, 0.515, -2.0), C.Black)
	k.box("FrontPost", V(0.02, 0.05, 0.02), CF(0, 0.605, -2.0), C.Black)
	k.tag = nil
	k.irons(V(0, 0.63, 0.2), 0.42)
	k.mount(CF(0, 0.52, -0.5))
	k.eject(V(0.12, 0.4, -0.3))
	k.group = "mag"
	local m = P(0, 0.02, -0.62, 4)
	k.box("Mag", V(0.15, 0.4, 0.26), m, C.Dark)
	k.box("MagBase", V(0.17, 0.04, 0.28), m * CF(0, -0.21, 0), C.Rubber)
	for i = 0, 3 do k.box("MagRib", V(0.156, 0.016, 0.2), m * CF(0, -0.13 + i * 0.085, 0), C.Black) end
	k.magwell(CF(0, 0.12, -0.62))
	k.group = "gun"
end

-- AWP: thumbhole stock, fluted barrel, bolt, big deep forend
function Models.HALO50(k)
	stdGrip(k, C.Olive, 0.04, -20)
	k.box("Chassis", V(0.2, 0.24, 1.1), CF(0, 0.25, -0.5), C.Olive)
	k.cylZ("Receiver", 0.95, 0.2, CF(0, 0.42, -0.35), C.Gun, METAL)
	k.box("EjectPort", V(0.02, 0.11, 0.34), CF(0.099, 0.44, -0.15), C.Black)
	k.box("LoadPort", V(0.075, 0.014, 0.34), CF(0.06, 0.508, -0.15), C.Black) -- v7: rounds drop in through here
	k.box("Rail", V(0.1, 0.04, 0.9), CF(0, 0.54, -0.35), C.Black)
	k.teeth("RailTooth", 0.565, -0.7, 0.14, 6, 0.12)
	-- deep forend with a flat bottom for the hand
	k.box("Forend", V(0.2, 0.5, 0.9), CF(0, 0.15, -1.5), C.Olive)
	k.box("ForendTop", V(0.15, 0.1, 0.9), CF(0, 0.42, -1.5), C.Olive)
	k.slots("Mlok", 0.102, 0.16, -1.15, -0.14, 5, 0.09, 0.05)
	k.box("ForendCap", V(0.21, 0.5, 0.03), CF(0, 0.15, -1.95), C.Black)
	for i = 0, 3 do k.box("ForendGroove", V(0.204, 0.016, 0.5), CF(0, -0.05 + i * 0.07, -1.5), C.Rubber) end
	k.cylZ("Barrel", 1.5, 0.1, CF(0, 0.42, -2.7), C.GunLight, METAL)
	for _, sx in { -1, 1 } do k.box("Flute", V(0.014, 0.02, 1.1), CF(sx * 0.05, 0.42, -2.7), C.Black) end
	k.box("Flute", V(0.02, 0.014, 1.1), CF(0, 0.47, -2.7), C.Black)
	k.band("BarrelBand", -2.2, 0.11, 0.04, 0.42, C.Gun, METAL)
	k.cylZ("BrakeNeck", 0.2, 0.1, CF(0, 0.42, -3.38), C.Gun, METAL)
	k.box("MuzzleBrake", V(0.16, 0.14, 0.28), CF(0, 0.42, -3.52), C.Gun, METAL)
	k.slots("BrakePort", 0.082, 0.42, -3.45, -0.07, 3, 0.04, 0.09)
	k.muzzle(V(0, 0.42, -3.68))
	k.box("Stock", V(0.17, 0.3, 0.9), CF(0, 0.3, 0.8), C.Olive)
	k.box("ThumbholeBar", V(0.15, 0.05, 0.4), CF(0, 0.52, 0.45), C.Olive)
	k.box("ThumbholePost", V(0.15, 0.2, 0.1), CF(0, 0.43, 0.62), C.Olive)
	k.box("CheekRest", V(0.14, 0.07, 0.45), CF(0, 0.5, 0.78), C.Dark)
	k.pins("CheekKnob", 0.09, 0.5, 0.62, 0.05)
	k.box("Spacer", V(0.19, 0.4, 0.016), CF(0, 0.28, 1.2), C.Black)
	k.box("Spacer", V(0.19, 0.4, 0.016), CF(0, 0.28, 1.226), C.WoodDark)
	k.box("ButtPad", V(0.2, 0.42, 0.07), CF(0, 0.28, 1.28), C.Rubber)
	k.box("Monopod", V(0.05, 0.2, 0.05), CF(0, 0.05, 1.1), C.Black)
	k.box("MonopodFoot", V(0.12, 0.03, 0.1), CF(0, -0.055, 1.1), C.Black)
	k.foreAt(0, 0.1, -1.5)
	k.tag = "Iron"
	k.box("RearBase", V(0.06, 0.08, 0.06), CF(0, 0.6, 0.08), C.Black)
	k.ring("RearAperture", CF(0, 0.68, 0.08), 0.035, 0.025, 0.04, C.Black)
	k.box("FrontBase", V(0.06, 0.12, 0.05), CF(0, 0.53, -1.9), C.Black)
	k.box("FrontPost", V(0.02, 0.1, 0.02), CF(0, 0.63, -1.9), C.Black)
	k.tag = nil
	k.irons(V(0, 0.68, 0.08), 0.42)
	k.mount(CF(0, 0.56, -0.3))
	k.eject(V(0.13, 0.45, -0.1))
	k.group = "cycle"
	k.cylZ("Bolt", 0.3, 0.12, CF(0, 0.42, 0.3), C.Steel, METAL)
	k.band("BoltShroud", 0.47, 0.105, 0.1, 0.42, C.Black)
	k.cylX("BoltHandle", 0.24, 0.04, CF(0.16, 0.4, 0.15), C.Steel, METAL)
	k.box("BoltKnob", V(0.08, 0.08, 0.08), CF(0.29, 0.38, 0.15), C.Dark)
	k.group = "mag"
	k.box("Mag", V(0.14, 0.22, 0.34), CF(0, 0.07, -0.45), C.Dark)
	k.box("MagBase", V(0.16, 0.04, 0.36), CF(0, -0.05, -0.45), C.Rubber)
	for i = 0, 2 do k.box("MagRib", V(0.146, 0.014, 0.3), CF(0, 0.02 + i * 0.06, -0.45), C.Black) end
	k.magwell(CF(0, 0.12, -0.45))
	addAux(k, 1, 5, 0.26, 0.07, BRASS)
	k.group = "gun"
end

-- Remington 870: pump shotgun, tube mag under the barrel, big wrapped pump forend
function Models.BREACHER(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.2, 0.28, 0.9), CF(0, 0.38, -0.3), C.Gun, METAL)
	k.box("Rail", V(0.1, 0.03, 0.4), CF(0, 0.535, -0.3), C.Black)
	k.teeth("RailTooth", 0.555, -0.45, 0.1, 4, 0.1)
	k.box("LoadingPort", V(0.14, 0.03, 0.34), CF(0, 0.235, -0.45), C.Black)
	k.box("EjectPort", V(0.014, 0.09, 0.3), CF(0.1, 0.42, -0.15), C.Black)
	k.pins("Pin", 0.103, 0.45, -0.55, 0.035)
	k.pins("Pin", 0.103, 0.3, 0.05, 0.035)
	k.box("ShellLatch", V(0.03, 0.06, 0.05), CF(0.105, 0.26, -0.6), C.Chrome, METAL)
	k.cylZ("Barrel", 1.6, 0.1, CF(0, 0.47, -1.55), C.GunLight, METAL)
	k.box("VentRib", V(0.04, 0.014, 1.5), CF(0, 0.53, -1.5), C.GunLight, METAL)
	k.cylZ("TubeMag", 1.2, 0.1, CF(0, 0.33, -1.35), C.Dark)
	k.box("TubeClamp", V(0.1, 0.22, 0.05), CF(0, 0.4, -1.3), C.Black)
	k.box("BarrelClamp", V(0.1, 0.22, 0.07), CF(0, 0.4, -2.1), C.Black)
	k.band("MagCap", -1.97, 0.125, 0.06, 0.33, C.Chrome, METAL)
	k.band("BarrelBand", -1.0, 0.11, 0.04, 0.47, C.Gun, METAL)
	k.box("Bead", V(0.03, 0.04, 0.03), CF(0, 0.545, -2.3), C.Steel, METAL)
	k.muzzle(V(0, 0.47, -2.36))
	k.box("Stock", V(0.18, 0.3, 0.85), P(0, 0.31, 0.55, 6), C.Polymer)
	k.box("StockCheek", V(0.12, 0.03, 0.4), P(0, 0.475, 0.5, 6), C.Rubber)
	k.box("ButtPad", V(0.2, 0.36, 0.08), P(0, 0.28, 0.99, 6), C.Rubber)
	for i = 0, 3 do k.box("PadRidge", V(0.2, 0.012, 0.075), P(0, 0.15 + i * 0.07, 0.99, 6), C.Black) end
	k.tag = "Iron"
	k.box("RearBase", V(0.08, 0.06, 0.06), CF(0, 0.55, -0.1), C.Black)
	k.ring("GhostRing", CF(0, 0.63, -0.1), 0.04, 0.025, 0.04, C.Black)
	k.tag = nil
	k.irons(V(0, 0.63, -0.1), 0.48)
	k.mount(CF(0, 0.55, -0.3))
	k.eject(V(0.12, 0.42, -0.3))
	-- the pump: a big forend that wraps the tube, rides back and forth (cycle group)
	k.group = "cycle"
	local pump = CF(0, 0.12, -1.2)
	-- v7: the pump forend was a comically big slab (0.5 tall x 0.5 long): now a slim wrapped sleeve round the tube
	k.box("PumpGrip", V(0.17, 0.26, 0.4), pump * CF(0, 0.12, 0), C.Polymer)
	for i = 0, 3 do k.box("PumpRidge", V(0.178, 0.22, 0.03), pump * CF(0, 0.12, -0.14 + i * 0.09), C.Black) end
	k.box("PumpCap", V(0.18, 0.26, 0.03), pump * CF(0, 0.12, -0.215), C.Rubber)
	k.cylZ("ActionBar", 0.55, 0.028, CF(0.07, 0.34, -0.98), C.Chrome, METAL)
	k.cylZ("ActionBar", 0.55, 0.028, CF(-0.07, 0.34, -0.98), C.Chrome, METAL)
	k.foreAt(0, 0.12, -1.2)
	k.group = "gun"
	k.magwell(CF(0, 0.2, -0.45))
	addAux(k, 1, 6, 0.3, 0.1, SHELLRED)
	k.group = "gun"
end

-- Glock 17: slim slide + frame, support hand wraps the lower grip
function Models.V9(k)
	local g = P(0, -0.05, 0.04, -18)
	k.box("Grip", V(0.15, 0.52, 0.28), g, C.Polymer)
	k.box("GripTexture", V(0.16, 0.28, 0.18), g * CF(0, -0.05, 0.01), C.Rubber)
	for r = 0, 3 do
		for c = 0, 2 do
			for _, sx in { -1, 1 } do k.box("GripDot", V(0.012, 0.026, 0.026), g * CF(sx * 0.077, -0.16 + r * 0.08, -0.07 + c * 0.07), C.Black) end
		end
	end
	k.box("Backstrap", V(0.1, 0.4, 0.03), g * CF(0, -0.03, 0.15), C.Black)
	k.box("MagFlare", V(0.17, 0.03, 0.3), g * CF(0, -0.255, 0.0), C.Black)
	for i = 0, 3 do k.box("GripGroove", V(0.146, 0.02, 0.012), g * CF(0, -0.14 + i * 0.09, -0.142), C.Black) end
	k.grip(g)
	k.box("Frame", V(0.14, 0.15, 0.82), CF(0, 0.245, -0.25), C.Polymer)
	k.box("DustCover", V(0.14, 0.1, 0.2), CF(0, 0.22, -0.62), C.Polymer)
	for i = 0, 1 do k.box("RailSlot", V(0.146, 0.014, 0.03), CF(0, 0.188, -0.5 - i * 0.07), C.Black) end
	k.box("TriggerGuard", V(0.04, 0.035, 0.26), CF(0, 0.12, -0.24), C.Polymer)
	k.box("GuardFront", V(0.04, 0.1, 0.035), CF(0, 0.16, -0.36), C.Polymer)
	k.box("Trigger", V(0.03, 0.1, 0.04), P(0, 0.17, -0.18, -12), C.Chrome, METAL)
	k.box("SlideStop", V(0.02, 0.03, 0.12), CF(-0.08, 0.29, -0.12), C.Chrome, METAL)
	k.box("TakedownLever", V(0.02, 0.035, 0.07), CF(-0.08, 0.26, -0.28), C.Chrome, METAL)
	k.box("MagRelease", V(0.02, 0.04, 0.045), CF(0.078, 0.19, 0.0), C.Black)
	k.muzzle(V(0, 0.4, -0.76))
	k.group = "cycle"
	k.box("Slide", V(0.16, 0.16, 0.9), CF(0, 0.39, -0.25), C.Gun, METAL)
	k.box("SlideTop", V(0.12, 0.02, 0.88), CF(0, 0.475, -0.25), C.Gun, METAL)
	for i = 0, 4 do k.box("SlideSerr", V(0.168, 0.11, 0.014), CF(0, 0.39, 0.04 + i * 0.035), C.Black) end
	for i = 0, 2 do k.box("SlideSerr", V(0.168, 0.11, 0.014), CF(0, 0.39, -0.46 - i * 0.04), C.Black) end
	k.box("EjectionPort", V(0.02, 0.06, 0.16), CF(0.082, 0.43, -0.2), C.Steel, METAL)
	k.cylZ("BarrelTip", 0.04, 0.07, CF(0, 0.39, -0.71), C.Black)
	k.tag = "Iron"
	k.box("RearBase", V(0.11, 0.025, 0.05), CF(0, 0.4925 + 0.0, 0.15), C.Black)
	for _, sx in { -1, 1 } do k.box("RearEar", V(0.03, 0.06, 0.05), CF(sx * 0.04, 0.535, 0.15), C.Black) end
	k.box("FrontSight", V(0.026, 0.05, 0.03), CF(0, 0.505, -0.66), C.Black)
	k.tag = nil
	k.group = "gun"
	-- support hand rest: the flared lower grip + a rail-mounted finger shelf, palm sits low on the grip
	k.box("SupportShelf", V(0.17, 0.035, 0.2), CF(0, -0.31, -0.06), C.Black)
	k.foreAt(-0.1, -0.2, -0.06, -0.13)
	k.irons(V(0, 0.53, 0.15), 0.62)
	k.mount(CF(0, 0.46, -0.05))
	k.eject(V(0.09, 0.45, -0.2))
	k.group = "mag"
	k.box("Mag", V(0.12, 0.4, 0.2), g * CF(0, -0.12, 0.01), C.Dark)
	for i = 0, 2 do k.box("MagRib", V(0.126, 0.016, 0.16), g * CF(0, -0.12 + i * 0.08 - 0.08, 0.01), C.Black) end
	k.box("MagBase", V(0.16, 0.05, 0.28), g * CF(0, -0.3, 0), C.Rubber)
	k.magwell(g * CF(0, -0.28, 0))
	k.group = "gun"
	k.view = { X = 0.45, Y = -0.8, Z = -1.3, SprintRot = V(-40, 20, 10), AdsEyeMult = 1.3, AdsDrop = 0.07 } -- hip pose unchanged; ADS: gun further out + lower on screen
end

-- .44 Magnum: fluted cylinder, long barrel with ribbed top, wood grips
function Models.MAGNUM(k)
	local g = P(0, -0.03, 0.08, -20)
	k.box("Grip", V(0.15, 0.48, 0.26), g, C.Wood, WOOD)
	k.box("GripPanel", V(0.156, 0.3, 0.18), g * CF(0, -0.02, -0.02), C.WoodDark, WOOD)
	k.cylX("Medallion", 0.012, 0.07, g * CF(0.078, 0.1, 0), C.Brass, METAL)
	k.cylX("Medallion", 0.012, 0.07, g * CF(-0.078, 0.1, 0), C.Brass, METAL)
	k.box("GripCap", V(0.16, 0.03, 0.28), g * CF(0, -0.255, 0), C.Steel, METAL)
	k.grip(g)
	k.box("Frame", V(0.15, 0.28, 0.46), CF(0, 0.33, -0.18), C.Steel, METAL)
	k.pins("FrameScrew", 0.078, 0.38, -0.08, 0.035, C.Black)
	k.pins("FrameScrew", 0.078, 0.28, -0.33, 0.035, C.Black)
	k.box("TopStrap", V(0.1, 0.05, 0.5), CF(0, 0.5, -0.18), C.Steel, METAL)
	k.box("RearSightLeaf", V(0.1, 0.04, 0.05), CF(0, 0.525, 0.02), C.Black)
	k.box("CylRelease", V(0.03, 0.05, 0.07), CF(-0.09, 0.36, 0.03), C.Chrome, METAL)
	k.box("TriggerGuard", V(0.04, 0.035, 0.24), CF(0, 0.12, -0.12), C.Steel, METAL)
	k.box("GuardFront", V(0.04, 0.08, 0.035), CF(0, 0.16, -0.24), C.Steel, METAL)
	k.box("Trigger", V(0.03, 0.1, 0.04), P(0, 0.16, -0.08, -12), C.Black)
	k.box("Barrel", V(0.09, 0.11, 0.9), CF(0, 0.43, -0.85), C.Chrome, METAL)
	k.box("RibTop", V(0.035, 0.012, 0.7), CF(0, 0.492, -0.85), C.GunLight, METAL)
	k.box("Underlug", V(0.07, 0.09, 0.75), CF(0, 0.33, -0.8), C.Steel, METAL)
	k.cylZ("RodTip", 0.03, 0.06, CF(0, 0.33, -1.19), C.Chrome, METAL)
	k.box("Crown", V(0.11, 0.13, 0.025), CF(0, 0.43, -1.305), C.Black)
	k.muzzle(V(0, 0.43, -1.32))
	k.tag = "Iron"
	k.box("FrontRamp", V(0.026, 0.06, 0.1), CF(0, 0.53, -1.22), C.Black)
	k.box("RearBase", V(0.1, 0.025, 0.05), CF(0, 0.5375, 0.02), C.Black)
	for _, sx in { -1, 1 } do k.box("RearEar", V(0.03, 0.055, 0.05), CF(sx * 0.04, 0.5775, 0.02), C.Black) end
	k.tag = nil
	k.box("CraneYoke", V(0.05, 0.07, 0.16), CF(-0.095, 0.26, -0.2), C.Steel, METAL)
	k.box("SupportShelf", V(0.17, 0.035, 0.2), CF(0, -0.3, 0.05), C.Steel, METAL)
	k.foreAt(-0.1, -0.2, 0.0, -0.13)
	k.irons(V(0, 0.56, 0.02), 0.62)
	k.mount(CF(0, 0.51, -0.25))
	k.eject(V(0, 0.36, -0.2))
	k.group = "cycle"
	k.box("Hammer", V(0.05, 0.12, 0.08), P(0, 0.48, 0.1, 20), C.Black)
	k.group = "mag"
	k.cylZ("Mag", 0.34, 0.28, CF(0, 0.36, -0.2), C.Steel, METAL)
	for i = 0, 5 do
		local a = i * math.pi / 3
		k.cylZ("Flute", 0.28, 0.06, CF(math.cos(a) * 0.14, 0.36 + math.sin(a) * 0.14, -0.2), C.Black)
	end
	k.cylZ("CylRing", 0.02, 0.3, CF(0, 0.36, -0.04), C.Steel, METAL)
	k.cylZ("CylRing", 0.02, 0.3, CF(0, 0.36, -0.36), C.Steel, METAL)
	k.box("CraneArm", V(0.17, 0.05, 0.1), CF(-0.05, 0.31, -0.2) * CFrame.Angles(0, 0, math.rad(45)), C.Steel, METAL) -- swings with the cylinder on its crane
	k.magwell(CF(0, 0.36, -0.2))
	addAux(k, 1, 6, 0.2, 0.06, BRASS)
	addAux(k, 7, 6, 0.22, 0.055, BRASS)
	k.group = "gun"
	k.view = { X = 0.45, Y = -0.8, Z = -1.3, SprintRot = V(-40, 20, 10), AdsEyeMult = 1.3, AdsDrop = 0.07 } -- hip pose unchanged; ADS: gun further out + lower on screen
end

GunModels.Models = Models
GunModels.Detail = {} -- (v4.8: the old v4.7 detail passes are folded into the models above)

-- ================= SIGHTS =================
-- Each optic: Display name, Mag (zoom, nil = use the gun's ADSFov), Eye (aim distance), Overlay (full-screen scope)
local Sights = {}
GunModels.Sights = Sights

Sights.Iron = { Display = "Iron" }

Sights.RedDot = { Display = "Compact Reflector", Reticle = "Dot", Eye = 0.45, Scale = 0.75,
	Build = function(k, m)
		-- enclosed housing with two screws on the rear face, open arched window above it (like The Finals' Compact Reflector)
		k.box("DotBase", V(0.2, 0.05, 0.3), m * CF(0, 0.025, 0), C.Body, METAL)
		k.box("DotHousing", V(0.22, 0.1, 0.24), m * CF(0, 0.1, -0.02), C.Body, METAL)
		for _, sx in ipairs({ -1, 1 }) do
			k.cylZ("DotScrew", 0.02, 0.045, m * CF(sx * 0.06, 0.1, 0.108), C.Metal, METAL)
		end
		local c = m * CF(0, 0.26, -0.04)
		for _, sx in ipairs({ -1, 1 }) do
			k.box("DotPost", V(0.03, 0.2, 0.14), c * CF(sx * 0.1, 0, 0), C.Body, METAL)
			k.box("DotCorner", V(0.055, 0.03, 0.14), c * CF(sx * 0.082, 0.082, 0) * ang(0, 0, -sx * 45), C.Body, METAL)
		end
		k.box("DotTop", V(0.12, 0.03, 0.14), c * CF(0, 0.104, 0), C.Body, METAL)
		k.box("DotLens", V(0.17, 0.19, 0.008), c * CF(0, 0, -0.03), C.Lens, SP, { Transparency = 0.85, NoShadow = true })
		k.box("DotReticle", V(0.2, 0.2, 0.002), c * CF(0, 0, -0.02), C.Dark, SP, { Transparency = 1, Reticle = "Dot" })
		return c * CF(0, 0, -0.02)
	end }

Sights.Holo = { Display = "Holographic", Reticle = "Holo", Eye = 0.55, Scale = 0.75,
	Build = function(k, m)
		-- chunky rectangular frame, big open window, rear buttons (like The Finals' Holographic)
		k.box("HoloBase", V(0.3, 0.13, 0.4), m * CF(0, 0.065, 0), C.Body, METAL)
		k.cylZ("HoloBtnMid", 0.02, 0.07, m * CF(0, 0.07, 0.205), C.Dark)
		for _, sx in ipairs({ -1, 1 }) do
			k.box("HoloBtn", V(0.07, 0.05, 0.02), m * CF(sx * 0.1, 0.07, 0.205), C.Dark)
		end
		local c = m * CF(0, 0.25, -0.08)
		for _, sx in ipairs({ -1, 1 }) do k.box("HoloPost", V(0.045, 0.24, 0.16), c * CF(sx * 0.135, 0, 0), C.Body, METAL) end
		k.box("HoloTop", V(0.315, 0.045, 0.16), c * CF(0, 0.1425, 0), C.Body, METAL)
		k.box("HoloGlass", V(0.23, 0.2, 0.008), c * CF(0, -0.01, -0.04), C.Lens, SP, { Transparency = 0.85, NoShadow = true })
		k.box("HoloReticle", V(0.26, 0.2, 0.002), c * CF(0, -0.01, -0.03), C.Dark, SP, { Transparency = 1, Reticle = "Holo" })
		return c * CF(0, -0.01, -0.03)
	end }

Sights.Ranger3x = { Display = "3x", Reticle = "Chevron", Mag = 3, Eye = 0.16, Scale = 0.8,
	Build = function(k, m)
		k.box("ScopeBase", V(0.2, 0.08, 0.42), m * CF(0, 0.04, 0), C.Body, METAL)
		local c = m * CF(0, 0.24, -0.05)
		k.box("ScopeMount", V(0.12, 0.14, 0.3), m * CF(0, 0.11, -0.05), C.Dark, METAL)
		k.ring("ScopeTube", c, 0.12, 0.035, 0.5, C.Body)
		k.ring("ScopeBell", c * CF(0, 0, -0.3), 0.13, 0.04, 0.1, C.Dark)
		k.ring("ScopeEye", c * CF(0, 0, 0.29), 0.12, 0.04, 0.08, C.Dark)
		k.box("ScopeTop", V(0.08, 0.06, 0.2), c * CF(0, 0.17, 0.02), C.Dark)
		k.box("ScopeLens", V(0.008, 0.25, 0.25), c * CF(0, 0, -0.3) * ang(0, 90, 0), C.Lens, SP,
			{ Shape = CYL, Transparency = 0.85, NoShadow = true })
		k.box("ScopeReticle", V(0.24, 0.24, 0.002), c * CF(0, 0, -0.29), C.Dark, SP, { Transparency = 1, Reticle = "Chevron" })
		return c * CF(0, 0, 0.33)
	end }

Sights.Sniper8x = { Display = "8x", Mag = 8, Eye = 0.2, Overlay = true, Scale = 0.85,
	Build = function(k, m)
		local c = m * CF(0, 0.3, -0.05)
		for _, z in ipairs({ -0.25, 0.2 }) do
			k.box("ScopeRingBase", V(0.16, 0.18, 0.1), m * CF(0, 0.09, z - 0.05), C.Dark, METAL)
			k.ring("ScopeRing", c * CF(0, 0, z), 0.12, 0.03, 0.08, C.Dark)
		end
		k.ring("ScopeTube", c, 0.1, 0.035, 1.0, C.Body)
		-- objective bell: flange from the tube out to the wider bell so nothing floats
		k.ring("ScopeFlange", c * CF(0, 0, -0.52), 0.1, 0.05, 0.06, C.Dark)
		k.ring("ScopeBell", c * CF(0, 0, -0.62), 0.13, 0.04, 0.26, C.Body)
		k.ring("ScopeEye", c * CF(0, 0, 0.55), 0.12, 0.04, 0.18, C.Dark)
		k.cylY("TurretTop", 0.1, 0.12, c * CF(0, 0.17, -0.02), C.Dark)
		k.cylX("TurretSide", 0.1, 0.12, c * CF(0.17, 0, -0.02), C.Dark)
		k.box("ScopeLens", V(0.008, 0.33, 0.33), c * CF(0, 0, -0.74) * ang(0, 90, 0), C.Lens, SP,
			{ Shape = CYL, Transparency = 0.7, Reflectance = 0.3, NoShadow = true })
		return c * CF(0, 0, 0.64)
	end }

-- ================= ASSEMBLY =================
-- Returns the part list + points (gun space, unscaled) for a gun and sight.
function GunModels.Describe(modelId, sightId, skinId)
	local fn = Models[modelId] or Models.VX9
	local k = newKit()
	fn(k)
	local sight = Sights[sightId] or Sights.Iron
	local aim, eye = k.pts.IronAim, k.ironEye or 0.45
	if sight.Build then
		-- optic: hide folding iron sights, mount the optic
		local kept = {}
		for _, d in ipairs(k.parts) do if d.Tag ~= "Iron" then table.insert(kept, d) end end
		k.parts = kept
		k.group, k.tag = "gun", "Sight"
		local first, mount = #k.parts + 1, k.pts.Mount
		aim = sight.Build(k, mount)
		local sc = sight.Scale or 1 -- optics are shrunk toward their mount point (smaller on screen)
		if sc ~= 1 then
			for i = first, #k.parts do
				local d = k.parts[i]
				local rel = mount:ToObjectSpace(d.CF)
				d.Size = d.Size * sc
				d.CF = mount * (CF(rel.Position * sc) * rel.Rotation)
			end
			local rel = mount:ToObjectSpace(aim)
			aim = mount * (CF(rel.Position * sc) * rel.Rotation)
		end
		eye = sight.Eye
	end
	k.pts.Aim = aim
	if skinId and GunSkins then pcall(GunSkins.Apply, k.parts, skinId, C) end -- v5.10: repaint
	return { Parts = k.parts, Points = k.pts, Eye = eye, Sight = sight, SightId = sight.Build and sightId or "Iron", View = k.view }
end

local function scaleCF(cf, s) return CF(cf.Position * s) * cf.Rotation end

local function buildReticle(part, style, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Reticle"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 1000 / math.max(part.Size.X / 0.2, 0.2)
	gui.LightInfluence = 0
	gui.Brightness = 4
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = true
	gui.Parent = part
	local function frame(w, h, transp, round, rot, x, y)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(0.5, x or 0, 0.5, y or 0)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transp
		f.BorderSizePixel = 0
		f.Rotation = rot or 0
		if round then local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = f end
		f.Parent = gui
		return f
	end
	if style == "Holo" then
		local r = frame(120, 120, 1, true)
		local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = 4; s.Parent = r
		frame(22, 22, 0.85, true)
		frame(8, 8, 0, true)
	elseif style == "Chevron" then
		frame(5, 26, 0, false, 35, -7.5, 10.6)
		frame(5, 26, 0, false, -35, 7.5, 10.6)
		frame(2, 60, 0.3, false, 0, 0, 52)
	else
		frame(8, 8, 0, true)
	end
	return gui
end

local function makePart(d, s)
	local p = Instance.new("Part")
	p.Name = d.Name
	if d.Shape then p.Shape = d.Shape end
	p.Size = d.Size * s
	p.Color = d.Color
	p.Material = d.Material
	p.Transparency = d.Transparency or 0
	if d.Reflectance then p.Reflectance = d.Reflectance end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	if d.Group == "mag" then p:SetAttribute("IsMag", true) end
	return p
end

-- ================= FIRST-PERSON HANDS (v4.8) =================
-- Real gloved hands built from rounded fingers (cylinders + knuckle balls). Both are authored in gun units.
--   right hand: frame = the pistol grip (X right, Y up the grip, Z back). Back of the hand on the rear / right side, three fingers wrap the front,
--               the index finger lies along the receiver toward the trigger, the thumb rests on the left side.
--   left hand : frame = the palm point (gun axes). Back of the hand on the left, four fingers wrap round the front of the hand rest, thumb along the left.
local _BALL = Enum.PartType.Ball

local function gripSize(desc)
	for _, d in ipairs(desc.Parts) do
		if d.Name == "Grip" then return d.Size end
	end
	return V(0.2, 0.52, 0.32)
end

-- GunModels.HandParts(desc, glove, pad) -> { right = { {Name, Size, CF, Color, Shape}, ... }, left = { ... } }, all in gun units.
--   right: CF is in GUN space (the hand is built round the pistol grip)
--   left : CF is relative to the palm point (gun axes), so the caller places it at Points.Palm (+ any animation)
-- The first-person viewmodel and the lobby / cutscene figures (Skins.NewFigure) both use this, so every hand looks the same.
function GunModels.HandParts(desc, glove, pad)
	-- v8 BLOCK HANDS (owner: back to blocky): every hand is a few clean blocks (back plate, knuckle plate, a finger block that wraps the
	-- grip with two pad lines for the finger splits, finger tips on the far side, thumb block, index finger block, wrist block).
	glove, pad = glove or C.Glove, pad or C.GlovePad
	local pts = desc.Points
	local gs = gripSize(desc)
	local gw, gd = gs.X, gs.Z
	local out = { right = {}, left = {} }
	local function put(side, name, size, cf, color)
		table.insert(out[side], { Name = name, Size = size, CF = cf, Color = color })
	end

	-- ---------- right hand (frame = pistol grip: X right, Y up the grip, Z back) ----------
	-- v9 PLAIN BLOCK HANDS: one mitten block per hand (+ a wrist block). No finger blocks, no thumb, no pad lines, no web.
	local G = pts.Grip
	put("right", "Hand", V(gw + 0.22, 0.4, gd + 0.12), G * CF(0, 0.0, 0.04), glove)
	put("right", "WristR", V(0.22, 0.22, 0.22), G * CF(gw / 2 + 0.03, 0.0, 0.3), glove)

	-- ---------- left hand (frame = palm point, gun axes) ----------
	local L = CFrame.identity
	put("left", "LHand", V(0.3, 0.28, 0.34), L * CF(-0.03, 0.0, 0.02), glove)
	put("left", "LWrist", V(0.22, 0.22, 0.22), L * CF(-0.12, -0.02, 0.26), glove)
	return out
end

local function addHands(model, groups, desc, scaled, s)
	local hands = GunModels.HandParts(desc)
	for side, list in pairs(hands) do
		local group = side == "right" and "gun" or "left"
		for _, h in ipairs(list) do
			local p = makePart({ Name = h.Name, Size = h.Size, Color = h.Color, Material = SP, Shape = h.Shape }, s)
			p.Anchored = true
			p.Parent = model
			table.insert(groups[group], { Part = p, Offset = scaleCF(h.CF, s) })
		end
	end
end

-- First-person viewmodel: anchored parts moved every frame by GunClient with BulkMoveTo.
-- Groups: gun, mag, cycle (bolt/pump/slide), left (left arm, relative to the palm point), flash. Each entry = { Part, Offset } in gun space (scaled).
function GunModels.BuildViewmodel(modelId, sightId, s, reticleColor, skinId)
	local desc = GunModels.Describe(modelId, sightId, skinId)
	local pts = desc.Points
	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	local groups = { gun = {}, mag = {}, cycle = {}, cover = {}, aux = {}, left = {}, flash = {} }
	local magPivot = scaleCF(pts.MagPivot, s)
	for _, d in ipairs(desc.Parts) do
		local p = makePart(d, s)
		p.Anchored = true
		p.Parent = model
		local off = scaleCF(d.CF, s)
		if d.Group == "mag" then off = magPivot:Inverse() * off end
		table.insert(groups[d.Group], { Part = p, Offset = off, Aux = d.Aux })
		if d.Reticle then buildReticle(p, d.Reticle, reticleColor or C.Reticle) end
	end
	local muzzle = scaleCF(pts.Muzzle, s)
	local mp = Instance.new("Part")
	mp.Name = "Muzzle"
	mp.Size = V(0.05, 0.05, 0.05)
	mp.Transparency = 1
	mp.Anchored = true
	mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow = false, false, false, false
	mp.Parent = model
	table.insert(groups.gun, { Part = mp, Offset = muzzle })
	local function flash(size, z)
		local p = makePart({ Name = "Flash", Size = size, Color = C.Flash, Material = NEON, Transparency = 1 }, s)
		p.Anchored = true
		p.Parent = model
		table.insert(groups.flash, { Part = p, Offset = CF(0, 0, z * s) })
	end
	flash(V(0.6, 0.07, 0.02), -0.05)
	flash(V(0.07, 0.6, 0.02), -0.05)
	flash(V(0.18, 0.18, 0.5), -0.25)

	local light = Instance.new("PointLight")
	light.Color = C.Flash; light.Range = 12; light.Brightness = 0; light.Shadows = false
	light.Parent = mp
	local smoke = Instance.new("ParticleEmitter")
	smoke.Enabled = false
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	smoke.LightEmission = 0
	smoke.Size = NumberSequence.new(0.12, 0.6)
	smoke.Transparency = NumberSequence.new(0.75, 1)
	smoke.Lifetime = NumberRange.new(0.4, 0.7)
	smoke.Speed = NumberRange.new(1, 2.5)
	smoke.Acceleration = V(0, 1.5, 0)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Parent = mp

	local scaled = {}
	for name, cf in pairs(pts) do scaled[name] = scaleCF(cf, s) end

	local SLEEVE_LEN = 3.6
	-- sleeves are rounded (cylinders). Cyl = true tells GunClient to add the 90 degree turn a cylinder needs when it re-aims the left sleeve each frame.
	local function arm(group, size, offset, color, shape)
		local p = makePart({ Name = "Arm", Size = size, Color = color, Material = SP, Shape = shape }, 1)
		p.Anchored = true
		p.Parent = model
		local entry = { Part = p, Offset = offset, Cyl = shape == CYL }
		table.insert(groups[group], entry)
		return entry
	end
	local rHand = scaled.Grip.Position
	local rDir = V(0.45, -0.5, 1).Unit
	local turn = ang(0, 90, 0)
	-- v8: sleeves + cuffs are BLOCKS again (long axis = Z, so no cylinder turn; Cyl = false tells GunClient not to add it)
	local _ = turn
	arm("gun", V(0.32, 0.32, 1.7), CFrame.lookAt(rHand + rDir * 1.0, rHand + rDir * 2), C.Sleeve)
	arm("gun", V(0.36, 0.36, 0.16), CFrame.lookAt(rHand + rDir * 0.2, rHand + rDir), C.Dark)
	local lDir = V(-0.6, -0.55, 1).Unit
	arm("left", V(0.32, 0.32, SLEEVE_LEN), CFrame.lookAt(lDir * 1.1, lDir * 2), C.Sleeve).Dyn = "sleeve"
	arm("left", V(0.36, 0.36, 0.16), CFrame.lookAt(lDir * 0.2, lDir), C.Dark).Dyn = "cuff"

	addHands(model, groups, desc, scaled, s)

	return {
		Model = model, Groups = groups, Points = scaled,
		SleeveLen = SLEEVE_LEN, Eye = desc.Eye, Sight = desc.Sight, SightId = desc.SightId, View = desc.View,
		Light = light, Smoke = smoke,
	}
end

-- Third-person world gun: welded, unanchored Model (PrimaryPart = Root) with attachments
-- RightGrip, LeftForegrip, LeftMagwell, MuzzlePoint, AimPoint and parts Muzzle/Flash/Mag (used by ThirdPersonClient).
function GunModels.BuildWorld(modelId, sightId, s, accent, name, skinId)
	local desc = GunModels.Describe(modelId, sightId, skinId)
	local pts = desc.Points
	local model = Instance.new("Model")
	model.Name = name or "Gun"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(0.1, 0.1, 0.1) * s
	root.Transparency = 1
	root.CanCollide, root.CanQuery, root.CanTouch, root.Massless = false, false, false, true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local function weld(p, cf)
		p.Massless = true
		p.CFrame = cf
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = root, p, cf
		w.Parent = p
		p.Parent = model
	end
	for _, d in ipairs(desc.Parts) do
		if not d.Reticle and d.Group ~= "aux" then
			local p = makePart(d, s)
			p.CastShadow = not d.NoShadow and d.Size.Magnitude * s > 0.3
			weld(p, scaleCF(d.CF, s))
		end
	end
	local muzzle = makePart({ Name = "Muzzle", Size = V(0.12, 0.12, 0.12), Color = C.Dark, Material = SP, Transparency = 1 }, s)
	weld(muzzle, scaleCF(pts.Muzzle, s))
	local light = Instance.new("PointLight")
	light.Name = "FlashLight"
	light.Color = Color3.fromRGB(255, 190, 90)
	light.Range = 12
	light.Brightness = 5
	light.Enabled = false
	light.Parent = muzzle
	local flash = makePart({ Name = "Flash", Size = V(0.4, 0.4, 0.7), Color = Color3.fromRGB(255, 200, 90), Material = NEON, Transparency = 1 }, s)
	weld(flash, scaleCF(pts.Muzzle * CF(0, 0, -0.3), s))
	for attName, key in pairs({ RightGrip = "RightGrip", LeftForegrip = "LeftForegrip", LeftMagwell = "LeftMagwell", MuzzlePoint = "Muzzle", AimPoint = "Aim" }) do
		local a = Instance.new("Attachment")
		a.Name = attName
		a.CFrame = scaleCF(pts[key], s)
		a.Parent = root
	end
	model:SetAttribute("Scale", s)
	model:SetAttribute("Weapon", modelId)
	return model
end

-- v4.8: guns no longer carry team-coloured glowing parts, so there is nothing to recolour. Kept so older scripts can still call it.
function GunModels.SetAccent(model, color) end

return GunModels
