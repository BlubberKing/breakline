-- GunModels: procedural gun models + attachable sights. Replaces GunModelBuilder + RifleModel.
-- Gun space: origin = top of the pistol grip, -Z = downrange, +Y = up. Unit scale ~ one Roblox rifle.
-- Adding a gun: write Models.<ID> = function(k) ... end using the kit below. It MUST call
--   k.grip(cf), k.fore(cf), k.magwell(cf), k.muzzle(pos), k.eject(pos), k.mount(cf), k.irons(aimPos, eye)
-- Parts after k.tag = "Iron" are folding iron sights (hidden when an optic is mounted). Iron front post top
-- must line up with the irons() aim height. Optional: k.view = { X, Y, Z, SprintRot } first-person hip tweak.
-- k.group = "mag" (reload anim), "cycle" (bolt/pump/slide anim), "gun" (default).
-- Sights: Iron (built into the gun) or an optic in Sights (mounted at k.mount, Iron-tagged parts get hidden).
local GunModels = {}

local V, CF = Vector3.new, CFrame.new
local rad = math.rad
local function ang(p, y, r) return CFrame.Angles(rad(p or 0), rad(y or 0), rad(r or 0)) end
local function P(x, y, z, rx, ry, rz) return CF(x, y, z) * ang(rx, ry, rz) end

local SP, NEON, METAL, GLASS, WOOD = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Metal, Enum.Material.Glass, Enum.Material.Wood
local CYL = Enum.PartType.Cylinder

local C = {
	Body    = Color3.fromRGB(36, 38, 44),
	Polymer = Color3.fromRGB(50, 52, 58),
	Metal   = Color3.fromRGB(70, 74, 82),
	Steel   = Color3.fromRGB(120, 124, 132),
	Dark    = Color3.fromRGB(16, 16, 19),
	Wood    = Color3.fromRGB(112, 66, 36),
	Olive   = Color3.fromRGB(64, 72, 52),
	Tan     = Color3.fromRGB(150, 128, 96),
	Lens    = Color3.fromRGB(150, 200, 255),
	Reticle = Color3.fromRGB(255, 45, 45),
	Accent  = Color3.fromRGB(255, 140, 30),
	Flash   = Color3.fromRGB(255, 200, 110),
	Glove   = Color3.fromRGB(28, 28, 32),
	Sleeve  = Color3.fromRGB(58, 70, 98),
}
GunModels.Colors = C

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
	function k.glow(name, size, cf)
		return k.box(name, size, cf, C.Accent, NEON, { Glow = true })
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
	function k.fore(cf) k.pts.Fore = cf; k.pts.LeftForegrip = cf * CF(-0.2, 0.02, 0) end
	function k.magwell(cf) k.pts.MagPivot = cf; k.pts.LeftMagwell = cf * CF(-0.25, 0.08, 0) end
	function k.muzzle(pos) k.pts.Muzzle = CF(pos) end
	function k.eject(pos) k.pts.Eject = CF(pos) end
	function k.mount(cf) k.pts.Mount = cf end
	function k.irons(aimPos, eye) k.pts.IronAim = CF(aimPos); k.ironEye = eye end
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

local function stdGrip(k, color, z, tilt)
	z, tilt = z or 0.04, tilt or -16
	local g = P(0, -0.02, z, tilt)
	k.box("Grip", V(0.2, 0.52, 0.32), g, color or C.Polymer)
	k.box("GripPanel", V(0.215, 0.3, 0.2), g * CF(0, -0.04, 0.02), C.Dark)
	k.box("TriggerGuard", V(0.04, 0.035, 0.36), CF(0, 0.08, z - 0.26), C.Dark)
	k.box("Trigger", V(0.035, 0.12, 0.045), P(0, 0.14, z - 0.2, -12), C.Metal)
	k.grip(g)
end

-- ================= GUNS =================
local Models = {}

-- Slim redesign (Oct 25): every receiver is low and narrow, optics sit on a flat rail (no tall carry handles / risers).
-- Each gun has one signature shape: M4 = round quad handguard + STANAG mag, AK = wood + banana mag + slanted gas tube,
-- FAMAS = bullpup with mag behind the grip, MP7 = short body + folding stock + suppressor, M249 = box mag + bipod,
-- M14 = tan chassis + vented guard, AWP = thumbhole stock + bolt, 870 = tube mag + pump, Glock = slide, .44 = fluted cylinder.

-- M4A1: slim carbine with a round handguard
function Models.VX9(k)
	stdGrip(k)
	k.box("LowerReceiver", V(0.2, 0.22, 0.85), CF(0, 0.3, -0.2))
	k.box("Magwell", V(0.19, 0.14, 0.3), CF(0, 0.16, -0.58), C.Polymer)
	k.box("UpperReceiver", V(0.22, 0.2, 1.05), CF(0, 0.5, -0.3), C.Body)
	k.box("Rail", V(0.12, 0.04, 1.55), CF(0, 0.62, -0.6), C.Dark)
	for i = 0, 9 do k.box("RailTooth", V(0.14, 0.02, 0.05), CF(0, 0.65, -1.25 + i * 0.15), C.Dark) end
	k.box("EjectionPort", V(0.02, 0.09, 0.28), CF(0.112, 0.5, -0.2), C.Dark)
	k.box("ChargingHandle", V(0.1, 0.04, 0.12), CF(0, 0.6, 0.3), C.Dark)
	k.glow("SideStripeR", V(0.02, 0.03, 0.6), CF(0.112, 0.34, -0.3))
	k.glow("SideStripeL", V(0.02, 0.03, 0.6), CF(-0.112, 0.34, -0.3))
	k.cylZ("Handguard", 1.0, 0.2, CF(0, 0.5, -1.55), C.Polymer)
	for i = 0, 3 do k.box("MLok", V(0.215, 0.03, 0.1), CF(0, 0.5, -1.2 - i * 0.22), C.Dark) end
	k.glow("HandguardStripe", V(0.1, 0.02, 0.5), CF(0, 0.395, -1.6))
	k.fore(CF(0, 0.38, -1.45))
	k.cylZ("Barrel", 0.5, 0.08, CF(0, 0.5, -2.3), C.Metal, METAL)
	k.cylZ("MuzzleDevice", 0.24, 0.12, CF(0, 0.5, -2.62), C.Dark)
	k.muzzle(V(0, 0.5, -2.76))
	k.cylZ("BufferTube", 0.5, 0.1, CF(0, 0.5, 0.55), C.Dark)
	k.box("Stock", V(0.16, 0.28, 0.45), CF(0, 0.42, 0.9), C.Polymer)
	k.box("ButtPad", V(0.18, 0.36, 0.06), CF(0, 0.4, 1.15), C.Dark)
	k.tag = "Iron"
	k.box("RearSightBase", V(0.08, 0.1, 0.08), CF(0, 0.69, 0.12), C.Dark)
	k.ring("RearAperture", CF(0, 0.78, 0.12), 0.035, 0.025, 0.04, C.Dark)
	k.box("FrontSightBase", V(0.07, 0.16, 0.06), CF(0, 0.61, -2.0), C.Dark)
	k.box("FrontPost", V(0.02, 0.06, 0.02), CF(0, 0.72, -2.0), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.78, 0.12), 0.42)
	k.mount(CF(0, 0.66, -0.5))
	k.eject(V(0.13, 0.5, -0.2))
	k.group = "mag"
	local m = P(0, -0.05, -0.58, 10)
	k.box("Mag", V(0.15, 0.5, 0.26), m, C.Polymer)
	k.glow("MagBase", V(0.17, 0.04, 0.28), m * CF(0, -0.25, 0))
	k.magwell(CF(0, -0.05, -0.58))
end

-- AK-47: wood furniture, slanted gas tube, banana mag
function Models.KR47(k)
	stdGrip(k, C.Dark, 0.04, -20)
	k.box("Receiver", V(0.2, 0.26, 1.1), CF(0, 0.34, -0.3), C.Body)
	k.box("DustCover", V(0.19, 0.1, 1.0), CF(0, 0.52, -0.3), C.Metal)
	k.box("Rail", V(0.1, 0.03, 0.4), CF(0, 0.59, -0.3), C.Dark)
	k.box("Selector", V(0.02, 0.05, 0.45), CF(0.105, 0.4, -0.25), C.Metal)
	k.box("EjectionPort", V(0.02, 0.08, 0.26), CF(0.102, 0.48, -0.4), C.Dark)
	k.group = "cycle"
	k.box("ChargingHandle", V(0.1, 0.04, 0.05), CF(0.13, 0.5, -0.6), C.Steel, METAL)
	k.group = "gun"
	k.box("LowerGuard", V(0.22, 0.2, 0.75), CF(0, 0.36, -1.3), C.Wood, WOOD)
	k.box("UpperGuard", V(0.16, 0.09, 0.7), CF(0, 0.5, -1.28), C.Wood, WOOD)
	k.glow("GuardStripeR", V(0.01, 0.025, 0.45), CF(0.112, 0.36, -1.3))
	k.glow("GuardStripeL", V(0.01, 0.025, 0.45), CF(-0.112, 0.36, -1.3))
	k.fore(CF(0, 0.28, -1.3))
	k.cylZ("Barrel", 1.0, 0.08, CF(0, 0.45, -2.2), C.Metal, METAL)
	k.cylZ("GasTube", 0.6, 0.07, CF(0, 0.57, -1.9), C.Metal, METAL)
	k.box("GasBlock", V(0.1, 0.2, 0.08), CF(0, 0.52, -2.2), C.Dark)
	k.box("FrontSightBlock", V(0.08, 0.2, 0.06), CF(0, 0.56, -2.62), C.Dark)
	k.cylZ("MuzzleBrake", 0.18, 0.12, CF(0, 0.45, -2.8), C.Dark)
	k.muzzle(V(0, 0.45, -2.9))
	k.box("Stock", V(0.17, 0.28, 0.8), P(0, 0.28, 0.75, 6), C.Wood, WOOD)
	k.box("ButtPad", V(0.18, 0.36, 0.06), P(0, 0.24, 1.16, 6), C.Dark)
	k.tag = "Iron"
	k.box("RearLeaf", V(0.1, 0.04, 0.12), CF(0, 0.62, -0.85), C.Dark)
	for _, sx in ipairs({ -1, 1 }) do k.box("RearEar", V(0.03, 0.07, 0.04), CF(sx * 0.04, 0.675, -0.85), C.Dark) end
	k.box("FrontPost", V(0.02, 0.1, 0.02), CF(0, 0.66, -2.62), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.71, -0.85), 0.6)
	k.mount(CF(0, 0.605, -0.3))
	k.eject(V(0.12, 0.48, -0.4))
	k.group = "mag"
	k.box("Mag", V(0.14, 0.34, 0.26), P(0, 0.0, -0.62, 8), C.Dark)
	k.box("MagLow", V(0.14, 0.32, 0.24), P(0, -0.3, -0.74, 24), C.Dark)
	k.glow("MagBase", V(0.16, 0.04, 0.27), P(0, -0.47, -0.84, 24))
	k.magwell(CF(0, 0.08, -0.6))
end

-- FAMAS: bullpup burst rifle, low flat top (no carry handle)
function Models.HX3(k)
	stdGrip(k, C.Dark, -0.3, -12)
	k.box("Body", V(0.2, 0.34, 1.7), CF(0, 0.36, -0.2), C.Polymer)
	k.box("Spine", V(0.16, 0.07, 1.5), CF(0, 0.565, -0.2), C.Body)
	k.box("Rail", V(0.1, 0.03, 1.0), CF(0, 0.615, -0.3), C.Dark)
	k.box("Cheek", V(0.16, 0.08, 0.4), CF(0, 0.6, 0.4), C.Dark)
	k.box("ButtPad", V(0.2, 0.4, 0.08), CF(0, 0.33, 0.68), C.Dark)
	k.box("Lower", V(0.18, 0.14, 0.6), CF(0, 0.12, -0.85), C.Polymer)
	k.glow("SideStripeR", V(0.01, 0.035, 1.1), CF(0.102, 0.36, -0.3))
	k.glow("SideStripeL", V(0.01, 0.035, 1.1), CF(-0.102, 0.36, -0.3))
	k.fore(CF(0, 0.08, -0.85))
	k.cylZ("Barrel", 0.4, 0.08, CF(0, 0.42, -1.25), C.Metal, METAL)
	k.cylZ("FlashHider", 0.2, 0.12, CF(0, 0.42, -1.55), C.Dark)
	k.muzzle(V(0, 0.42, -1.66))
	k.tag = "Iron"
	k.box("RearSight", V(0.03, 0.08, 0.04), CF(0, 0.67, 0.3), C.Dark)
	k.box("FrontBase", V(0.06, 0.08, 0.06), CF(0, 0.64, -0.98), C.Dark)
	k.box("FrontPost", V(0.02, 0.05, 0.02), CF(0, 0.695, -0.98), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.72, 0.3), 0.4)
	k.mount(CF(0, 0.63, -0.3))
	k.eject(V(0.12, 0.45, 0.3))
	k.group = "mag"
	k.box("Mag", V(0.15, 0.45, 0.26), P(0, 0.0, 0.42, 8), C.Dark)
	k.glow("MagBase", V(0.17, 0.04, 0.28), P(0, -0.23, 0.46, 8))
	k.magwell(CF(0, 0.1, 0.42))
end

-- MP7: short body, folding stock, suppressor
function Models.WASP(k)
	stdGrip(k, C.Dark, 0.04, -12)
	k.box("Upper", V(0.2, 0.26, 1.1), CF(0, 0.44, -0.35), C.Polymer)
	k.box("Shroud", V(0.18, 0.2, 0.4), P(0, 0.38, -1.05, -6), C.Body)
	k.box("Rail", V(0.1, 0.03, 0.8), CF(0, 0.59, -0.35), C.Dark)
	k.glow("SideStripeR", V(0.01, 0.03, 0.8), CF(0.102, 0.44, -0.35))
	k.glow("SideStripeL", V(0.01, 0.03, 0.8), CF(-0.102, 0.44, -0.35))
	k.group = "cycle"
	k.box("ChargingKnob", V(0.07, 0.06, 0.12), CF(0.125, 0.5, -0.1), C.Steel, METAL)
	k.group = "gun"
	k.cylZ("Suppressor", 0.55, 0.12, CF(0, 0.4, -1.55), C.Dark)
	k.muzzle(V(0, 0.4, -1.84))
	k.fore(CF(0, 0.16, -1.0))
	k.box("ForeGrip", V(0.1, 0.22, 0.12), P(0, 0.17, -1.0, -8), C.Dark)
	k.box("StockArmR", V(0.025, 0.06, 0.6), CF(0.08, 0.46, 0.55), C.Dark)
	k.box("StockArmL", V(0.025, 0.06, 0.6), CF(-0.08, 0.46, 0.55), C.Dark)
	k.box("ButtPlate", V(0.18, 0.28, 0.05), CF(0, 0.42, 0.88), C.Dark)
	k.tag = "Iron"
	k.box("RearSight", V(0.08, 0.07, 0.04), CF(0, 0.635, 0.12), C.Dark)
	k.box("FrontBase", V(0.04, 0.12, 0.04), CF(0, 0.54, -1.1), C.Dark)
	k.box("FrontSight", V(0.02, 0.06, 0.02), CF(0, 0.63, -1.1), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.67, 0.12), 0.42)
	k.mount(CF(0, 0.605, -0.35))
	k.eject(V(0.11, 0.46, -0.3))
	k.group = "mag"
	k.box("Mag", V(0.13, 0.5, 0.2), P(0, -0.15, -0.6, 4), C.Dark)
	k.glow("MagBase", V(0.15, 0.04, 0.22), P(0, -0.4, -0.62, 4))
	k.magwell(CF(0, -0.05, -0.6))
end

-- M249 SAW: belt-fed LMG, box mag + bipod, low feed cover
function Models.ANVIL(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.24, 0.3, 1.3), CF(0, 0.38, -0.3), C.Body)
	k.group = "cover"
	k.box("FeedCover", V(0.24, 0.08, 0.7), CF(0, 0.57, -0.25), C.Metal)
	k.box("Rail", V(0.12, 0.03, 0.6), CF(0, 0.625, -0.25), C.Dark)
	k.group = "gun"
	k.box("Handguard", V(0.22, 0.2, 0.6), CF(0, 0.36, -1.3), C.Polymer)
	k.box("HeatShield", V(0.18, 0.05, 0.7), CF(0, 0.5, -1.6), C.Metal)
	k.glow("SideStripeR", V(0.01, 0.035, 0.9), CF(0.122, 0.34, -0.3))
	k.glow("SideStripeL", V(0.01, 0.035, 0.9), CF(-0.122, 0.34, -0.3))
	k.cylZ("Barrel", 1.1, 0.12, CF(0, 0.42, -2.15), C.Metal, METAL)
	k.box("BarrelHandle", V(0.04, 0.1, 0.3), CF(0, 0.53, -1.95), C.Dark)
	k.cylZ("BipodLegR", 0.7, 0.035, CF(0.07, 0.22, -1.9), C.Dark)
	k.cylZ("BipodLegL", 0.7, 0.035, CF(-0.07, 0.22, -1.9), C.Dark)
	k.cylZ("FlashHider", 0.22, 0.15, CF(0, 0.42, -2.8), C.Dark)
	k.muzzle(V(0, 0.42, -2.93))
	k.fore(CF(0, 0.22, -1.3))
	k.box("Stock", V(0.18, 0.3, 0.7), CF(0, 0.32, 0.75), C.Polymer)
	k.box("ButtPad", V(0.2, 0.38, 0.07), CF(0, 0.3, 1.13), C.Dark)
	k.tag = "Iron"
	k.box("RearSight", V(0.1, 0.06, 0.04), CF(0, 0.67, 0.2), C.Dark)
	for _, sx in ipairs({ -1, 1 }) do k.box("RearEar", V(0.02, 0.06, 0.04), CF(sx * 0.04, 0.7, 0.2), C.Dark) end
	k.box("FrontBase", V(0.05, 0.2, 0.05), CF(0, 0.58, -2.5), C.Dark)
	k.box("FrontPost", V(0.02, 0.05, 0.02), CF(0, 0.705, -2.5), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.73, 0.2), 0.45)
	k.mount(CF(0, 0.64, -0.25))
	k.eject(V(0.14, 0.45, -0.2))
	k.group = "mag"
	k.box("Mag", V(0.34, 0.36, 0.4), CF(-0.03, 0.0, -0.55), C.Olive)
	k.glow("MagBase", V(0.36, 0.04, 0.42), CF(-0.03, -0.19, -0.55))
	k.magwell(CF(0, 0.1, -0.55))
	k.group = "aux"
	for i = 0, 3 do k.box("BeltLink", V(0.05, 0.05, 0.1), CF(), BRASS, METAL, { Aux = i + 1 }) end
	k.group = "gun"
end

-- M14 EBR: tan chassis, vented guard
function Models.LONGSHOT(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.2, 0.28, 1.2), CF(0, 0.34, -0.3), C.Tan)
	k.box("Rail", V(0.12, 0.04, 1.4), CF(0, 0.5, -0.5), C.Dark)
	for i = 0, 7 do k.box("RailTooth", V(0.14, 0.02, 0.05), CF(0, 0.53, -1.1 + i * 0.16), C.Dark) end
	k.box("Handguard", V(0.2, 0.2, 0.9), CF(0, 0.38, -1.4), C.Tan)
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 3 do k.box("Vent", V(0.02, 0.08, 0.13), CF(sx * 0.102, 0.38, -1.1 - i * 0.2), C.Dark) end
	end
	k.glow("Stripe", V(0.1, 0.02, 0.6), CF(0, 0.275, -1.4))
	k.group = "cycle"
	k.box("OpRodHandle", V(0.07, 0.07, 0.16), CF(0.13, 0.42, -0.3), C.Steel, METAL)
	k.group = "gun"
	k.cylZ("Barrel", 0.9, 0.09, CF(0, 0.4, -2.3), C.Metal, METAL)
	k.box("MuzzleBrake", V(0.12, 0.12, 0.25), CF(0, 0.4, -2.85), C.Dark)
	k.muzzle(V(0, 0.4, -2.98))
	k.fore(CF(0, 0.25, -1.4))
	k.box("Stock", V(0.17, 0.3, 0.7), CF(0, 0.3, 0.8), C.Dark)
	k.box("CheekRiser", V(0.14, 0.08, 0.35), CF(0, 0.5, 0.75), C.Tan)
	k.box("ButtPad", V(0.2, 0.38, 0.07), CF(0, 0.28, 1.17), C.Dark)
	k.tag = "Iron"
	k.box("RearBase", V(0.08, 0.06, 0.06), CF(0, 0.55, 0.2), C.Dark)
	k.ring("RearAperture", CF(0, 0.63, 0.2), 0.035, 0.025, 0.04, C.Dark)
	k.box("FrontBase", V(0.06, 0.14, 0.05), CF(0, 0.515, -2.0), C.Dark)
	k.box("FrontPost", V(0.02, 0.05, 0.02), CF(0, 0.605, -2.0), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.63, 0.2), 0.42)
	k.mount(CF(0, 0.52, -0.5))
	k.eject(V(0.12, 0.4, -0.3))
	k.group = "mag"
	k.box("Mag", V(0.15, 0.4, 0.26), P(0, -0.05, -0.62, 4), C.Dark)
	k.glow("MagBase", V(0.17, 0.04, 0.28), P(0, -0.26, -0.63, 4))
	k.magwell(CF(0, 0.05, -0.62))
end

-- AWP: thumbhole stock, long barrel, bolt
function Models.HALO50(k)
	stdGrip(k, C.Olive, 0.04, -20)
	k.box("Chassis", V(0.2, 0.24, 1.1), CF(0, 0.25, -0.5), C.Olive)
	k.cylZ("Receiver", 0.95, 0.2, CF(0, 0.42, -0.35), C.Body)
	k.box("Rail", V(0.1, 0.04, 0.9), CF(0, 0.54, -0.35), C.Dark)
	k.box("Forend", V(0.2, 0.22, 0.9), CF(0, 0.3, -1.5), C.Olive)
	k.glow("StripeR", V(0.01, 0.025, 0.7), CF(0.102, 0.28, -1.5))
	k.glow("StripeL", V(0.01, 0.025, 0.7), CF(-0.102, 0.28, -1.5))
	k.cylZ("Barrel", 1.5, 0.1, CF(0, 0.42, -2.55), C.Metal, METAL)
	k.box("MuzzleBrake", V(0.16, 0.14, 0.28), CF(0, 0.42, -3.45), C.Dark)
	k.muzzle(V(0, 0.42, -3.62))
	k.fore(CF(0, 0.2, -1.4))
	k.box("Stock", V(0.17, 0.3, 0.9), CF(0, 0.3, 0.8), C.Olive)
	k.box("ThumbholeBar", V(0.15, 0.05, 0.4), CF(0, 0.52, 0.45), C.Olive)
	k.box("CheekRest", V(0.14, 0.07, 0.45), CF(0, 0.5, 0.78), C.Dark)
	k.box("ButtPad", V(0.2, 0.42, 0.07), CF(0, 0.28, 1.28), C.Dark)
	k.box("Monopod", V(0.05, 0.2, 0.05), CF(0, 0.05, 1.1), C.Dark)
	k.tag = "Iron"
	k.box("RearBase", V(0.06, 0.08, 0.06), CF(0, 0.6, 0.08), C.Dark)
	k.ring("RearAperture", CF(0, 0.68, 0.08), 0.035, 0.025, 0.04, C.Dark)
	k.box("FrontBase", V(0.06, 0.12, 0.05), CF(0, 0.53, -1.9), C.Dark)
	k.box("FrontPost", V(0.02, 0.1, 0.02), CF(0, 0.63, -1.9), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.68, 0.08), 0.42)
	k.mount(CF(0, 0.56, -0.3))
	k.eject(V(0.13, 0.45, -0.1))
	k.group = "cycle"
	k.cylZ("Bolt", 0.3, 0.12, CF(0, 0.42, 0.3), C.Steel, METAL)
	k.cylX("BoltHandle", 0.24, 0.04, CF(0.16, 0.4, 0.15), C.Steel, METAL)
	k.box("BoltKnob", V(0.08, 0.08, 0.08), CF(0.29, 0.38, 0.15), C.Dark)
	k.group = "mag"
	k.box("Mag", V(0.14, 0.22, 0.34), CF(0, 0.07, -0.45), C.Dark)
	k.glow("MagBase", V(0.16, 0.04, 0.36), CF(0, -0.05, -0.45))
	k.magwell(CF(0, 0.12, -0.45))
	addAux(k, 1, 5, 0.26, 0.07, BRASS)
	k.group = "gun"
end

-- Remington 870: pump shotgun, tube mag under the barrel
function Models.BREACHER(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.2, 0.28, 0.9), CF(0, 0.38, -0.3), C.Body)
	k.box("Rail", V(0.1, 0.03, 0.4), CF(0, 0.535, -0.3), C.Dark)
	k.box("LoadingPort", V(0.14, 0.03, 0.34), CF(0, 0.235, -0.45), C.Dark)
	k.glow("SideStripeR", V(0.01, 0.03, 0.6), CF(0.102, 0.38, -0.3))
	k.glow("SideStripeL", V(0.01, 0.03, 0.6), CF(-0.102, 0.38, -0.3))
	k.cylZ("Barrel", 1.6, 0.1, CF(0, 0.47, -1.55), C.Metal, METAL)
	k.cylZ("TubeMag", 1.2, 0.1, CF(0, 0.33, -1.35), C.Dark)
	k.box("BarrelClamp", V(0.1, 0.22, 0.07), CF(0, 0.4, -2.1), C.Dark)
	k.box("Bead", V(0.03, 0.04, 0.03), CF(0, 0.545, -2.3), C.Steel, METAL)
	k.muzzle(V(0, 0.47, -2.36))
	k.box("Stock", V(0.18, 0.3, 0.85), P(0, 0.3, 0.7, 6), C.Polymer)
	k.box("ButtPad", V(0.2, 0.36, 0.08), P(0, 0.26, 1.13, 6), C.Dark)
	k.tag = "Iron"
	k.box("RearBase", V(0.08, 0.06, 0.06), CF(0, 0.55, -0.1), C.Dark)
	k.ring("GhostRing", CF(0, 0.63, -0.1), 0.04, 0.025, 0.04, C.Dark)
	k.tag = nil
	k.irons(V(0, 0.63, -0.1), 0.48)
	k.mount(CF(0, 0.55, -0.3))
	k.eject(V(0.12, 0.42, -0.3))
	k.group = "cycle"
	local pump = CF(0, 0.32, -1.2)
	k.box("Pump", V(0.2, 0.18, 0.5), pump, C.Polymer)
	for i = 0, 3 do k.box("PumpRidge", V(0.21, 0.19, 0.04), pump * CF(0, 0, -0.18 + i * 0.12), C.Dark) end
	k.fore(pump * CF(0, -0.05, 0))
	k.magwell(CF(0, 0.2, -0.45))
	addAux(k, 1, 6, 0.3, 0.1, SHELLRED)
	k.group = "gun"
end

-- Glock 17: slim slide + frame
function Models.V9(k)
	local g = P(0, -0.05, 0.04, -18)
	k.box("Grip", V(0.15, 0.52, 0.28), g, C.Polymer)
	k.box("GripTexture", V(0.16, 0.28, 0.18), g * CF(0, -0.05, 0.01), C.Dark)
	k.grip(g)
	k.box("Frame", V(0.14, 0.12, 0.8), CF(0, 0.25, -0.25), C.Polymer)
	k.box("TriggerGuard", V(0.04, 0.035, 0.26), CF(0, 0.12, -0.24), C.Polymer)
	k.box("Trigger", V(0.03, 0.1, 0.04), P(0, 0.16, -0.18, -12), C.Dark)
	k.glow("FrameStripe", V(0.145, 0.02, 0.4), CF(0, 0.2, -0.42))
	k.fore(g * CF(-0.02, -0.05, -0.02))
	k.muzzle(V(0, 0.4, -0.76))
	k.group = "cycle"
	k.box("Slide", V(0.16, 0.16, 0.9), CF(0, 0.4, -0.25), C.Body)
	k.box("Serrations", V(0.165, 0.11, 0.14), CF(0, 0.4, 0.1), C.Dark)
	k.box("EjectionPort", V(0.02, 0.06, 0.16), CF(0.082, 0.44, -0.2), C.Steel, METAL)
	k.box("RearSight", V(0.11, 0.05, 0.05), CF(0, 0.505, 0.15), C.Dark)
	k.box("FrontSight", V(0.03, 0.05, 0.03), CF(0, 0.505, -0.66), C.Dark)
	k.cylZ("BarrelTip", 0.03, 0.07, CF(0, 0.4, -0.71), C.Dark)
	k.group = "gun"
	k.irons(V(0, 0.53, 0.15), 0.62)
	k.mount(CF(0, 0.49, -0.05))
	k.eject(V(0.09, 0.45, -0.2))
	k.group = "mag"
	k.box("Mag", V(0.12, 0.4, 0.2), g * CF(0, -0.12, 0.01), C.Dark)
	k.glow("MagBase", V(0.16, 0.05, 0.28), g * CF(0, -0.3, 0))
	k.magwell(g * CF(0, -0.28, 0))
	k.view = { X = 0.45, Y = -0.8, Z = -1.3, SprintRot = V(-40, 20, 10) }
end

-- .44 Magnum: fluted cylinder, long barrel with ribbed top
function Models.MAGNUM(k)
	local g = P(0, -0.03, 0.08, -20)
	k.box("Grip", V(0.15, 0.48, 0.26), g, C.Wood, WOOD)
	k.grip(g)
	k.box("Frame", V(0.15, 0.28, 0.46), CF(0, 0.33, -0.18), C.Steel, METAL)
	k.box("TopStrap", V(0.1, 0.05, 0.5), CF(0, 0.5, -0.18), C.Steel, METAL)
	k.box("TriggerGuard", V(0.04, 0.035, 0.24), CF(0, 0.12, -0.12), C.Steel, METAL)
	k.box("Trigger", V(0.03, 0.1, 0.04), P(0, 0.16, -0.08, -12), C.Dark)
	k.box("Barrel", V(0.09, 0.11, 0.9), CF(0, 0.43, -0.85), C.Steel, METAL)
	k.box("Underlug", V(0.07, 0.09, 0.75), CF(0, 0.33, -0.8), C.Steel, METAL)
	k.glow("RibStripe", V(0.035, 0.012, 0.7), CF(0, 0.492, -0.85))
	k.box("FrontRamp", V(0.03, 0.06, 0.1), CF(0, 0.52, -1.22), C.Dark)
	k.box("RearNotch", V(0.1, 0.04, 0.05), CF(0, 0.54, 0.02), C.Dark)
	k.muzzle(V(0, 0.43, -1.32))
	k.fore(g * CF(-0.02, -0.05, -0.02))
	k.irons(V(0, 0.56, 0.02), 0.62)
	k.mount(CF(0, 0.53, -0.25))
	k.eject(V(0, 0.36, -0.2))
	k.group = "cycle"
	k.box("Hammer", V(0.05, 0.12, 0.08), P(0, 0.48, 0.1, 20), C.Dark)
	k.group = "mag"
	k.cylZ("Mag", 0.34, 0.28, CF(0, 0.36, -0.2), C.Steel, METAL)
	for i = 0, 5 do
		local a = i * math.pi / 3
		k.cylZ("Flute", 0.28, 0.06, CF(math.cos(a) * 0.14, 0.36 + math.sin(a) * 0.14, -0.2), C.Dark)
	end
	k.magwell(CF(0, 0.36, -0.2))
	addAux(k, 1, 6, 0.2, 0.06, BRASS)  -- 1-6: spent casings
	addAux(k, 7, 6, 0.22, 0.055, BRASS) -- 7-12: fresh rounds
	k.group = "gun"
	k.view = { X = 0.45, Y = -0.8, Z = -1.3, SprintRot = V(-40, 20, 10) }
end

GunModels.Models = Models

-- ================= SIGHTS =================
-- Each optic: Display name, Mag (zoom, nil = use the gun's ADSFov), Eye (aim distance), Overlay (full-screen scope)
local Sights = {}
GunModels.Sights = Sights

Sights.Iron = { Display = "Iron" }

Sights.RedDot = { Display = "Compact Reflector", Reticle = "Dot", Eye = 0.45, Scale = 0.75,
	Build = function(k, m)
		-- enclosed housing with two screws on the rear face, open arched window above it (like The Finals' Compact Reflector)
		k.box("DotBase", V(0.2, 0.05, 0.3), m * CF(0, 0.025, 0), C.Body)
		k.box("DotHousing", V(0.22, 0.1, 0.24), m * CF(0, 0.1, -0.02), C.Body)
		for _, sx in ipairs({ -1, 1 }) do
			k.cylZ("DotScrew", 0.02, 0.045, m * CF(sx * 0.06, 0.1, 0.108), C.Metal, METAL)
		end
		local c = m * CF(0, 0.26, -0.04)
		for _, sx in ipairs({ -1, 1 }) do
			k.box("DotPost", V(0.03, 0.2, 0.14), c * CF(sx * 0.1, 0, 0), C.Body)
			k.box("DotCorner", V(0.055, 0.03, 0.14), c * CF(sx * 0.082, 0.082, 0) * ang(0, 0, -sx * 45), C.Body)
		end
		k.box("DotTop", V(0.12, 0.03, 0.14), c * CF(0, 0.104, 0), C.Body)
		k.glow("DotStripe", V(0.04, 0.01, 0.1), m * CF(0, 0.152, -0.02))
		k.box("DotLens", V(0.17, 0.19, 0.008), c * CF(0, 0, -0.03), C.Lens, SP, { Transparency = 0.85, NoShadow = true })
		k.box("DotReticle", V(0.2, 0.2, 0.002), c * CF(0, 0, -0.02), C.Dark, SP, { Transparency = 1, Reticle = "Dot" })
		return c * CF(0, 0, -0.02)
	end }

Sights.Holo = { Display = "Holographic", Reticle = "Holo", Eye = 0.55, Scale = 0.75,
	Build = function(k, m)
		-- chunky rectangular frame, big open window, rear buttons (like The Finals' Holographic)
		k.box("HoloBase", V(0.3, 0.13, 0.4), m * CF(0, 0.065, 0), C.Body)
		k.cylZ("HoloBtnMid", 0.02, 0.07, m * CF(0, 0.07, 0.205), C.Dark)
		for _, sx in ipairs({ -1, 1 }) do
			k.box("HoloBtn", V(0.07, 0.05, 0.02), m * CF(sx * 0.1, 0.07, 0.205), C.Dark)
		end
		local c = m * CF(0, 0.25, -0.08)
		for _, sx in ipairs({ -1, 1 }) do k.box("HoloPost", V(0.045, 0.24, 0.16), c * CF(sx * 0.135, 0, 0), C.Body) end
		k.box("HoloTop", V(0.315, 0.045, 0.16), c * CF(0, 0.1425, 0), C.Body)
		k.glow("HoloStripe", V(0.18, 0.01, 0.06), c * CF(0, 0.168, 0))
		k.box("HoloGlass", V(0.23, 0.2, 0.008), c * CF(0, -0.01, -0.04), C.Lens, SP, { Transparency = 0.85, NoShadow = true })
		k.box("HoloReticle", V(0.26, 0.2, 0.002), c * CF(0, -0.01, -0.03), C.Dark, SP, { Transparency = 1, Reticle = "Holo" })
		return c * CF(0, -0.01, -0.03)
	end }

Sights.Ranger3x = { Display = "3x", Reticle = "Chevron", Mag = 3, Eye = 0.16, Scale = 0.8,
	Build = function(k, m)
		k.box("ScopeBase", V(0.2, 0.08, 0.42), m * CF(0, 0.04, 0), C.Body)
		local c = m * CF(0, 0.24, -0.05)
		k.ring("ScopeTube", c, 0.12, 0.035, 0.5, C.Body)
		k.ring("ScopeBell", c * CF(0, 0, -0.3), 0.13, 0.04, 0.1, C.Dark)
		k.ring("ScopeEye", c * CF(0, 0, 0.29), 0.12, 0.04, 0.08, C.Dark)
		k.box("ScopeTop", V(0.08, 0.06, 0.2), c * CF(0, 0.17, 0.02), C.Dark)
		k.glow("ScopeStripe", V(0.03, 0.01, 0.32), c * CF(0.11, 0.11, 0) * ang(0, 0, -45))
		k.box("ScopeLens", V(0.008, 0.25, 0.25), c * CF(0, 0, -0.3) * ang(0, 90, 0), C.Lens, SP,
			{ Shape = CYL, Transparency = 0.85, NoShadow = true })
		k.box("ScopeReticle", V(0.24, 0.24, 0.002), c * CF(0, 0, -0.29), C.Dark, SP, { Transparency = 1, Reticle = "Chevron" })
		return c * CF(0, 0, 0.33)
	end }

Sights.Sniper8x = { Display = "8x", Mag = 8, Eye = 0.2, Overlay = true, Scale = 0.85,
	Build = function(k, m)
		local c = m * CF(0, 0.3, -0.05)
		for _, z in ipairs({ -0.25, 0.2 }) do
			k.box("ScopeRingBase", V(0.16, 0.12, 0.1), m * CF(0, 0.06, z - 0.05), C.Dark)
			k.ring("ScopeRing", c * CF(0, 0, z), 0.12, 0.03, 0.08, C.Dark)
		end
		k.ring("ScopeTube", c, 0.1, 0.035, 1.0, C.Body)
		k.ring("ScopeBell", c * CF(0, 0, -0.62), 0.15, 0.04, 0.26, C.Body)
		k.ring("ScopeEye", c * CF(0, 0, 0.55), 0.12, 0.04, 0.18, C.Dark)
		k.cylY("TurretTop", 0.1, 0.12, c * CF(0, 0.17, -0.02), C.Dark)
		k.cylX("TurretSide", 0.1, 0.12, c * CF(0.17, 0, -0.02), C.Dark)
		k.glow("ScopeStripe", V(0.03, 0.01, 0.6), c * CF(0, 0.137, -0.05))
		k.box("ScopeLens", V(0.008, 0.33, 0.33), c * CF(0, 0, -0.74) * ang(0, 90, 0), C.Lens, SP,
			{ Shape = CYL, Transparency = 0.7, Reflectance = 0.3, NoShadow = true })
		return c * CF(0, 0, 0.64)
	end }

-- ================= ASSEMBLY =================
-- Returns the part list + points (gun space, unscaled) for a gun and sight.
function GunModels.Describe(modelId, sightId)
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
	if d.Glow then p:SetAttribute("TeamAccent", true) end
	if d.Group == "mag" then p:SetAttribute("IsMag", true) end
	return p
end

-- First-person viewmodel: anchored parts moved every frame by GunClient with BulkMoveTo.
-- Groups: gun, mag, cycle (bolt/pump/slide), left (left arm, relative to Points.Fore position), flash. Each entry = { Part, Offset } in gun space (scaled).
function GunModels.BuildViewmodel(modelId, sightId, s, reticleColor)
	local desc = GunModels.Describe(modelId, sightId)
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

	-- arms (camera-sized, not gun-scaled). Right arm rides the grip, left arm is animated for reloads.
	local function arm(group, size, offset, color)
		local p = makePart({ Name = "Arm", Size = size, Color = color, Material = SP }, 1)
		p.Anchored = true
		p.Parent = model
		table.insert(groups[group], { Part = p, Offset = offset })
	end
	local rHand = scaled.Grip.Position
	local rDir = V(0.45, -0.5, 1).Unit
	arm("gun", V(0.24, 0.26, 0.34), CF(rHand) * scaled.Grip.Rotation, C.Glove)
	arm("gun", V(0.34, 0.34, 1.7), CFrame.lookAt(rHand + rDir * 1.0, rHand + rDir * 2), C.Sleeve)
	arm("gun", V(0.36, 0.36, 0.16), CFrame.lookAt(rHand + rDir * 0.2, rHand + rDir), C.Dark)
	local lDir = V(-0.6, -0.55, 1).Unit
	arm("left", V(0.24, 0.24, 0.36), ang(0, 0, -25), C.Glove)
	arm("left", V(0.34, 0.34, 1.9), CFrame.lookAt(lDir * 1.1, lDir * 2), C.Sleeve)
	arm("left", V(0.36, 0.36, 0.16), CFrame.lookAt(lDir * 0.2, lDir), C.Dark)

	return {
		Model = model, Groups = groups, Points = scaled,
		Eye = desc.Eye, Sight = desc.Sight, SightId = desc.SightId, View = desc.View,
		Light = light, Smoke = smoke,
	}
end

-- Third-person world gun: welded, unanchored Model (PrimaryPart = Root) with attachments
-- RightGrip, LeftForegrip, LeftMagwell, MuzzlePoint, AimPoint and parts Muzzle/Flash/Mag (used by ThirdPersonClient).
function GunModels.BuildWorld(modelId, sightId, s, accent, name)
	local desc = GunModels.Describe(modelId, sightId)
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
			if d.Glow and accent then p.Color = accent end
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

function GunModels.SetAccent(model, color)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("TeamAccent") then d.Color = color end
	end
end

return GunModels
