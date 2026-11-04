-- GunModels v2 (v4.7: DETAIL PASSES - every gun got rails, vents, ribs, levers, rings, grain and better material tones; sizes, proportions and all hand / mag / muzzle points are unchanged)
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
	-- ===== v4.7 detail helpers (used by the DETAIL passes below) =====
	function k.find(name)
		for _, d in ipairs(k.parts) do if d.Name == name then return d end end
	end
	function k.recolor(name, color, mat)
		for _, d in ipairs(k.parts) do
			if d.Name == name then d.Color = color if mat then d.Material = mat end end
		end
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
	-- n evenly spaced slots / vents on both sides: z0 = first centre, step along Z (use a negative step to go toward the muzzle)
	function k.slots(name, x, y, z0, step, n, w, h, color)
		for i = 0, n - 1 do k.pair(name, V(0.014, h, w), x, y, z0 + i * step, color or C.Black) end
	end
	-- a barrel / tube that gets narrower: n stacked cylinders from (z0, d0) to (z1, d1)
	function k.taper(name, z0, z1, d0, d1, y, n, color, mat, x)
		local len = math.abs(z1 - z0) / n
		for i = 0, n - 1 do
			local t = (i + 0.5) / n
			k.cylZ(name, len + 0.004, d0 + (d1 - d0) * t, CF(x or 0, y, z0 + (z1 - z0) * t), color, mat)
		end
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

local function stdGrip(k, color, z, tilt)
	z, tilt = z or 0.04, tilt or -16
	local g = P(0, -0.02, z, tilt)
	k.box("Grip", V(0.2, 0.52, 0.32), g, color or C.Polymer)
	k.box("GripPanel", V(0.215, 0.3, 0.2), g * CF(0, -0.04, 0.02), C.Dark)
	k.box("TriggerGuard", V(0.04, 0.035, 0.36), CF(0, 0.08, z - 0.26), C.Dark)
	k.box("Trigger", V(0.035, 0.12, 0.045), P(0, 0.14, z - 0.2, -12), C.Metal)
	k.grip(g)
	-- v4.7: finger grooves, backstrap, base cap, front post of the trigger guard
	for i = 0, 2 do k.box("GripGroove", V(0.206, 0.024, 0.035), g * CF(0, -0.12 + i * 0.09, -0.15), C.Dark) end
	k.box("GripBackstrap", V(0.17, 0.4, 0.04), g * CF(0, -0.02, 0.17), C.Dark)
	k.box("GripCap", V(0.215, 0.03, 0.34), g * CF(0, -0.27, 0), C.Dark)
	k.box("GuardFront", V(0.04, 0.16, 0.035), CF(0, 0.14, z - 0.425), C.Dark)
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
	k.box("ChargingHandle", V(0.1, 0.04, 0.12), CF(0, 0.61, 0.19), C.Dark)
	k.glow("SideStripeR", V(0.02, 0.03, 0.6), CF(0.112, 0.34, -0.3))
	k.glow("SideStripeL", V(0.02, 0.03, 0.6), CF(-0.112, 0.34, -0.3))
	k.cylZ("Handguard", 1.0, 0.2, CF(0, 0.5, -1.55), C.Polymer)
	for i = 0, 3 do k.box("MLok", V(0.215, 0.03, 0.1), CF(0, 0.5, -1.2 - i * 0.22), C.Dark) end
	k.glow("HandguardStripe", V(0.1, 0.02, 0.5), CF(0, 0.395, -1.6))
	k.fore(CF(0, 0.38, -1.45))
	k.cylZ("Barrel", 0.5, 0.08, CF(0, 0.5, -2.3), C.Metal, METAL)
	k.cylZ("MuzzleDevice", 0.24, 0.12, CF(0, 0.5, -2.62), C.Dark)
	k.muzzle(V(0, 0.5, -2.76))
	k.cylZ("BufferTube", 0.62, 0.1, CF(0, 0.5, 0.52), C.Dark)
	k.box("Stock", V(0.16, 0.28, 0.45), CF(0, 0.42, 0.88), C.Polymer)
	k.box("ButtPad", V(0.18, 0.36, 0.06), CF(0, 0.4, 1.12), C.Dark)
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
	k.box("Receiver", V(0.2, 0.26, 1.2), CF(0, 0.34, -0.3), C.Body)
	k.box("DustCover", V(0.19, 0.1, 1.0), CF(0, 0.52, -0.3), C.Metal)
	k.box("Rail", V(0.1, 0.03, 0.4), CF(0, 0.59, -0.3), C.Dark)
	k.box("Selector", V(0.02, 0.05, 0.45), CF(0.105, 0.4, -0.25), C.Metal)
	k.box("EjectionPort", V(0.02, 0.08, 0.26), CF(0.102, 0.48, -0.4), C.Dark)
	k.group = "cycle"
	k.box("ChargingHandle", V(0.1, 0.04, 0.05), CF(0.13, 0.5, -0.6), C.Steel, METAL)
	k.group = "gun"
	k.box("LowerGuard", V(0.22, 0.2, 0.75), CF(0, 0.36, -1.27), C.Wood, WOOD)
	k.box("UpperGuard", V(0.16, 0.09, 0.7), CF(0, 0.5, -1.27), C.Wood, WOOD)
	k.glow("GuardStripeR", V(0.01, 0.025, 0.45), CF(0.112, 0.36, -1.3))
	k.glow("GuardStripeL", V(0.01, 0.025, 0.45), CF(-0.112, 0.36, -1.3))
	k.fore(CF(0, 0.28, -1.3))
	k.cylZ("Barrel", 1.0, 0.08, CF(0, 0.45, -2.2), C.Metal, METAL)
	k.cylZ("GasTube", 0.6, 0.07, CF(0, 0.57, -1.9), C.Metal, METAL)
	k.box("GasBlock", V(0.1, 0.2, 0.08), CF(0, 0.52, -2.2), C.Dark)
	k.box("FrontSightBlock", V(0.08, 0.2, 0.06), CF(0, 0.56, -2.62), C.Dark)
	k.cylZ("MuzzleBrake", 0.18, 0.12, CF(0, 0.45, -2.8), C.Dark)
	k.muzzle(V(0, 0.45, -2.9))
	k.box("Stock", V(0.17, 0.28, 0.8), P(0, 0.28, 0.67, 6), C.Wood, WOOD)
	k.box("ButtPad", V(0.18, 0.36, 0.06), P(0, 0.24, 1.08, 6), C.Dark)
	k.tag = "Iron"
	k.box("RearLeaf", V(0.1, 0.08, 0.12), CF(0, 0.61, -0.85), C.Dark)
	for _, sx in ipairs({ -1, 1 }) do k.box("RearEar", V(0.03, 0.07, 0.04), CF(sx * 0.04, 0.675, -0.85), C.Dark) end
	k.box("FrontPost", V(0.02, 0.1, 0.02), CF(0, 0.66, -2.62), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.71, -0.85), 0.6)
	k.mount(CF(0, 0.605, -0.3))
	k.eject(V(0.12, 0.48, -0.4))
	k.group = "mag"
	k.box("Mag", V(0.14, 0.36, 0.26), P(0, 0.06, -0.62, 8), C.Dark)
	k.box("MagLow", V(0.14, 0.32, 0.24), P(0, -0.22, -0.72, 24), C.Dark)
	k.glow("MagBase", V(0.16, 0.04, 0.27), P(0, -0.38, -0.79, 24))
	k.magwell(CF(0, 0.14, -0.6))
end

-- FAMAS: bullpup burst rifle, low flat top (no carry handle). v3.7: slimmer body (was chunky), shorter, every part touches
function Models.HX3(k)
	stdGrip(k, C.Dark, -0.3, -12)
	k.box("Body", V(0.18, 0.27, 1.55), CF(0, 0.375, -0.18), C.Polymer)
	k.box("Spine", V(0.14, 0.06, 1.35), CF(0, 0.535, -0.2), C.Body)
	k.box("Rail", V(0.09, 0.03, 0.9), CF(0, 0.575, -0.3), C.Dark)
	k.box("Cheek", V(0.14, 0.06, 0.36), CF(0, 0.555, 0.38), C.Dark)
	k.box("ButtPad", V(0.19, 0.32, 0.07), CF(0, 0.36, 0.6), C.Dark)
	k.box("Lower", V(0.15, 0.11, 0.5), CF(0, 0.19, -0.78), C.Polymer)
	k.glow("SideStripeR", V(0.01, 0.03, 1.0), CF(0.0905, 0.38, -0.28))
	k.glow("SideStripeL", V(0.01, 0.03, 1.0), CF(-0.0905, 0.38, -0.28))
	k.fore(CF(0, 0.13, -0.78))
	k.cylZ("Barrel", 0.4, 0.07, CF(0, 0.42, -1.12), C.Metal, METAL)
	k.cylZ("FlashHider", 0.18, 0.1, CF(0, 0.42, -1.4), C.Dark)
	k.muzzle(V(0, 0.42, -1.5))
	k.tag = "Iron"
	k.box("RearSight", V(0.03, 0.07, 0.04), CF(0, 0.615, 0.3), C.Dark)
	k.box("FrontBase", V(0.05, 0.12, 0.05), CF(0, 0.565, -0.86), C.Dark)
	k.box("FrontPost", V(0.02, 0.04, 0.02), CF(0, 0.63, -0.86), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.65, 0.3), 0.4)
	k.mount(CF(0, 0.59, -0.3))
	k.eject(V(0.11, 0.45, 0.3))
	k.group = "mag"
	k.box("Mag", V(0.13, 0.42, 0.24), P(0, 0.05, 0.4, 8), C.Dark)
	k.glow("MagBase", V(0.15, 0.04, 0.26), P(0, -0.165, 0.43, 8))
	k.magwell(CF(0, 0.15, 0.4))
end

-- MP7: short body, folding stock, suppressor
function Models.WASP(k)
	stdGrip(k, C.Dark, 0.04, -12)
	k.box("Upper", V(0.2, 0.26, 1.1), CF(0, 0.44, -0.35), C.Polymer)
	-- v3.7: lower frame ties the grip and the magwell to the upper (they used to float under it)
	k.box("Lower", V(0.17, 0.14, 0.92), CF(0, 0.25, -0.38), C.Polymer)
	k.box("Magwell", V(0.16, 0.1, 0.24), CF(0, 0.16, -0.6), C.Dark)
	k.box("Shroud", V(0.18, 0.2, 0.5), P(0, 0.38, -1.05, -6), C.Body)
	k.box("Rail", V(0.1, 0.03, 0.8), CF(0, 0.59, -0.35), C.Dark)
	k.glow("SideStripeR", V(0.01, 0.03, 0.8), CF(0.102, 0.44, -0.35))
	k.glow("SideStripeL", V(0.01, 0.03, 0.8), CF(-0.102, 0.44, -0.35))
	k.group = "cycle"
	k.box("ChargingKnob", V(0.07, 0.06, 0.12), CF(0.125, 0.5, -0.1), C.Steel, METAL)
	k.group = "gun"
	k.cylZ("Suppressor", 0.55, 0.12, CF(0, 0.4, -1.55), C.Dark)
	k.muzzle(V(0, 0.4, -1.84))
	k.fore(CF(0, 0.16, -1.0))
	k.box("ForeGrip", V(0.1, 0.22, 0.12), P(0, 0.2, -1.0, -8), C.Dark)
	k.box("StockArmR", V(0.025, 0.06, 0.66), CF(0.08, 0.46, 0.5), C.Dark)
	k.box("StockArmL", V(0.025, 0.06, 0.66), CF(-0.08, 0.46, 0.5), C.Dark)
	k.box("ButtPlate", V(0.18, 0.28, 0.05), CF(0, 0.42, 0.84), C.Dark)
	k.tag = "Iron"
	k.box("RearBase", V(0.09, 0.07, 0.04), CF(0, 0.605, 0.12), C.Dark)
	for _, sx in ipairs({ -1, 1 }) do k.box("RearEar", V(0.024, 0.07, 0.04), CF(sx * 0.04, 0.665, 0.12), C.Dark) end
	k.box("FrontBase", V(0.04, 0.12, 0.04), CF(0, 0.54, -1.1), C.Dark)
	k.box("FrontSight", V(0.024, 0.07, 0.024), CF(0, 0.635, -1.1), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.67, 0.12), 0.42)
	k.mount(CF(0, 0.605, -0.35))
	k.eject(V(0.11, 0.46, -0.3))
	k.group = "mag"
	k.box("Mag", V(0.13, 0.46, 0.2), P(0, -0.08, -0.6, 4), C.Dark)
	k.glow("MagBase", V(0.15, 0.04, 0.22), P(0, -0.31, -0.62, 4))
	k.magwell(CF(0, 0.05, -0.6))
end

-- M249 SAW: belt-fed LMG, box mag + bipod, low feed cover
function Models.ANVIL(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.24, 0.3, 1.36), CF(0, 0.38, -0.32), C.Body)
	k.group = "cover"
	k.box("FeedCover", V(0.24, 0.08, 0.7), CF(0, 0.57, -0.25), C.Metal)
	k.box("Rail", V(0.12, 0.03, 0.6), CF(0, 0.625, -0.25), C.Dark)
	k.group = "gun"
	k.box("Handguard", V(0.22, 0.2, 0.6), CF(0, 0.36, -1.28), C.Polymer)
	k.box("BipodMount", V(0.16, 0.1, 0.1), CF(0, 0.31, -1.62), C.Dark)
	k.box("HeatShield", V(0.18, 0.05, 0.7), CF(0, 0.5, -1.6), C.Metal)
	k.glow("SideStripeR", V(0.01, 0.035, 0.9), CF(0.122, 0.34, -0.3))
	k.glow("SideStripeL", V(0.01, 0.035, 0.9), CF(-0.122, 0.34, -0.3))
	k.cylZ("Barrel", 1.1, 0.12, CF(0, 0.42, -2.15), C.Metal, METAL)
	k.box("BarrelHandle", V(0.04, 0.1, 0.3), CF(0, 0.53, -1.95), C.Dark)
	k.cylZ("BipodLegR", 0.7, 0.035, CF(0.07, 0.25, -1.9), C.Dark)
	k.cylZ("BipodLegL", 0.7, 0.035, CF(-0.07, 0.25, -1.9), C.Dark)
	k.cylZ("FlashHider", 0.22, 0.15, CF(0, 0.42, -2.8), C.Dark)
	k.muzzle(V(0, 0.42, -2.93))
	k.fore(CF(0, 0.22, -1.3))
	k.box("Stock", V(0.18, 0.3, 0.76), CF(0, 0.32, 0.72), C.Polymer)
	k.box("ButtPad", V(0.2, 0.38, 0.07), CF(0, 0.3, 1.12), C.Dark)
	k.box("RearSightBase", V(0.1, 0.1, 0.06), CF(0, 0.58, 0.2), C.Dark)
	k.tag = "Iron"
	k.box("RearSight", V(0.1, 0.08, 0.04), CF(0, 0.66, 0.2), C.Dark)
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
	k.box("Receiver", V(0.2, 0.28, 1.3), CF(0, 0.34, -0.3), C.Tan)
	k.box("Rail", V(0.12, 0.04, 1.4), CF(0, 0.5, -0.5), C.Dark)
	for i = 0, 7 do k.box("RailTooth", V(0.14, 0.02, 0.05), CF(0, 0.53, -1.1 + i * 0.16), C.Dark) end
	k.box("Handguard", V(0.2, 0.2, 0.9), CF(0, 0.38, -1.38), C.Tan)
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 3 do k.box("Vent", V(0.02, 0.08, 0.13), CF(sx * 0.102, 0.38, -1.1 - i * 0.2), C.Dark) end
	end
	k.glow("Stripe", V(0.1, 0.02, 0.6), CF(0, 0.275, -1.4))
	k.group = "cycle"
	k.box("OpRodHandle", V(0.07, 0.07, 0.16), CF(0.13, 0.42, -0.3), C.Steel, METAL)
	k.group = "gun"
	k.cylZ("Barrel", 1.0, 0.09, CF(0, 0.4, -2.3), C.Metal, METAL)
	k.box("MuzzleBrake", V(0.12, 0.12, 0.25), CF(0, 0.4, -2.85), C.Dark)
	k.muzzle(V(0, 0.4, -2.98))
	k.fore(CF(0, 0.25, -1.4))
	k.box("Stock", V(0.17, 0.3, 0.8), CF(0, 0.3, 0.75), C.Dark)
	k.box("CheekRiser", V(0.14, 0.08, 0.35), CF(0, 0.48, 0.75), C.Tan)
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
	k.box("Mag", V(0.15, 0.4, 0.26), P(0, 0.02, -0.62, 4), C.Dark)
	k.glow("MagBase", V(0.17, 0.04, 0.28), P(0, -0.19, -0.63, 4))
	k.magwell(CF(0, 0.12, -0.62))
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
	k.box("ThumbholePost", V(0.15, 0.2, 0.1), CF(0, 0.43, 0.62), C.Olive)
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
	k.box("Stock", V(0.18, 0.3, 0.85), P(0, 0.31, 0.55, 6), C.Polymer)
	k.box("ButtPad", V(0.2, 0.36, 0.08), P(0, 0.28, 0.99, 6), C.Dark)
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
	k.tag = "Iron"
	k.box("RearBase", V(0.11, 0.025, 0.05), CF(0, 0.4925, 0.15), C.Dark)
	for _, sx in ipairs({ -1, 1 }) do k.box("RearEar", V(0.03, 0.06, 0.05), CF(sx * 0.04, 0.535, 0.15), C.Dark) end
	k.box("FrontSight", V(0.026, 0.05, 0.03), CF(0, 0.505, -0.66), C.Dark)
	k.tag = nil
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
	k.tag = "Iron"
	k.box("FrontRamp", V(0.026, 0.06, 0.1), CF(0, 0.53, -1.22), C.Dark)
	k.box("RearBase", V(0.1, 0.025, 0.05), CF(0, 0.5375, 0.02), C.Dark)
	for _, sx in ipairs({ -1, 1 }) do k.box("RearEar", V(0.03, 0.055, 0.05), CF(sx * 0.04, 0.5775, 0.02), C.Dark) end
	k.tag = nil
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


-- ================= DETAIL PASSES (v4.7) =================
-- The base models above fix every size, proportion and hand / mag / muzzle point. These passes only ADD small parts on top (rails, vents, ribs, pins,
-- levers, rings, grain) and re-tone a few materials, so the guns read like a modeller made them. Nothing here moves a point or changes a base
-- dimension; mag details are in the "mag" group (they move with the magazine on reload), slide / bolt / pump / cover details are in "cycle" / "cover".
-- A gun without a pass here simply keeps its base model.
local Detail = {}
local Cx = C
Cx.Gun = Color3.fromRGB(58, 62, 70)
Cx.GunLight = Color3.fromRGB(98, 104, 114)
Cx.Chrome = Color3.fromRGB(172, 176, 184)
Cx.Black = Color3.fromRGB(9, 9, 11)
Cx.Brass = Color3.fromRGB(205, 165, 72)
Cx.WoodLight = Color3.fromRGB(142, 90, 52)
Cx.WoodDark = Color3.fromRGB(88, 52, 30)
Cx.Rubber = Color3.fromRGB(26, 26, 29)
Cx.Stipple = Color3.fromRGB(38, 39, 44)

local function magRibs(k, frame, n, y0, dy, w, d)
	k.group = "mag"
	for i = 0, n - 1 do k.box("MagRib", V(w, 0.016, d), frame * CF(0, y0 + i * dy, 0), C.Black) end
	k.group = "gun"
end
local function padRidges(k, z, y0, dy, n, w, tilt)
	for i = 0, n - 1 do k.box("PadRidge", V(w, 0.012, 0.075), P(0, y0 + i * dy, z, tilt or 0), C.Black) end
end
local function muzzleSlots(k, y, z, w)
	k.box("MuzzleSlotH", V(w, 0.016, 0.11), CF(0, y, z), C.Black)
	k.box("MuzzleSlotV", V(0.016, w, 0.11), CF(0, y, z), C.Black)
end

-- M4A1
function Detail.VX9(k)
	k.recolor("UpperReceiver", C.Gun, METAL); k.recolor("Barrel", C.GunLight, METAL); k.recolor("MuzzleDevice", C.Gun, METAL); k.recolor("ButtPad", C.Rubber)
	k.pair("UpperEdge", V(0.012, 0.012, 1.0), 0.104, 0.597, -0.3, C.GunLight, METAL)
	k.box("PortCover", V(0.01, 0.075, 0.2), CF(0.12, 0.515, -0.21), C.Gun, METAL)
	k.box("ForwardAssist", V(0.04, 0.07, 0.07), CF(0.128, 0.47, 0.03), C.Gun, METAL)
	k.box("MagRelease", V(0.035, 0.06, 0.07), CF(0.117, 0.27, -0.5), C.Chrome, METAL)
	k.box("BoltCatch", V(0.025, 0.08, 0.045), CF(-0.115, 0.36, -0.18), C.Chrome, METAL)
	k.box("SelectorLever", V(0.016, 0.03, 0.11), CF(-0.119, 0.33, 0.09), C.Chrome, METAL)
	k.cylX("SelectorPivot", 0.016, 0.055, CF(-0.119, 0.33, 0.14), C.Chrome, METAL)
	k.pins("TakedownPin", 0.112, 0.4, -0.62, 0.045)
	k.pins("TakedownPin", 0.112, 0.38, 0.17, 0.045)
	k.band("DeltaRing", -1.07, 0.23, 0.05, 0.5, C.Gun, METAL)
	k.band("HandguardCap", -2.04, 0.21, 0.05, 0.5, C.Black)
	for i = 0, 5 do k.band("HandguardGroove", -1.22 - i * 0.16, 0.206, 0.014, 0.5, C.Black) end
	k.band("GasBlock", -2.12, 0.12, 0.12, 0.5, C.Black)
	k.band("BarrelBand", -2.3, 0.1, 0.035, 0.5, C.Gun, METAL)
	k.band("BarrelBand", -2.42, 0.1, 0.035, 0.5, C.Gun, METAL)
	k.band("MuzzleRing", -2.53, 0.13, 0.04, 0.5, C.Black)
	muzzleSlots(k, 0.5, -2.67, 0.13)
	k.band("CastleNut", 0.23, 0.135, 0.05, 0.5, C.Gun, METAL)
	for i = 0, 2 do k.band("BufferRing", 0.38 + i * 0.12, 0.112, 0.025, 0.5, C.Black) end
	k.box("StockRail", V(0.09, 0.04, 0.38), CF(0, 0.255, 0.9), C.Black)
	k.box("StockCheek", V(0.12, 0.03, 0.3), CF(0, 0.575, 0.88), C.Gun)
	padRidges(k, 1.12, 0.27, 0.07, 5, 0.19)
	magRibs(k, P(0, -0.05, -0.58, 10), 5, -0.17, 0.075, 0.156, 0.2)
end

-- AK-47
function Detail.KR47(k)
	k.recolor("LowerGuard", C.WoodLight, WOOD); k.recolor("UpperGuard", C.WoodDark, WOOD); k.recolor("Stock", C.WoodLight, WOOD)
	k.recolor("Receiver", C.Gun, METAL); k.recolor("DustCover", C.Body, METAL); k.recolor("Selector", C.Chrome, METAL); k.recolor("Mag", C.Stipple); k.recolor("MagLow", C.Stipple)
	for i = 0, 3 do
		k.pins("Rivet", 0.103, 0.28, -0.75 + i * 0.3, 0.03, C.GunLight)
		k.pins("Rivet", 0.103, 0.4, -0.7 + i * 0.3, 0.03, C.GunLight)
	end
	k.box("Trunnion", V(0.21, 0.27, 0.12), CF(0, 0.335, -0.88), C.Gun, METAL)
	k.box("RearTang", V(0.15, 0.09, 0.2), CF(0, 0.5, 0.26), C.Body)
	for i = 0, 4 do k.box("CoverRib", V(0.198, 0.106, 0.03), CF(0, 0.52, -0.66 + i * 0.2), C.Gun, METAL) end
	k.cylZ("GuideRod", 0.14, 0.032, CF(0, 0.505, 0.26), C.Chrome, METAL)
	k.box("SelectorTab", V(0.04, 0.03, 0.05), CF(0.12, 0.395, 0.0), C.Chrome, METAL)
	for i = 0, 2 do k.pair("WoodGrain", V(0.012, 0.012, 0.66), 0.11, 0.31 + i * 0.05, -1.27, C.WoodDark, WOOD) end
	k.box("FrontFerrule", V(0.23, 0.22, 0.035), CF(0, 0.36, -1.63), C.Gun, METAL)
	k.box("RearFerrule", V(0.225, 0.22, 0.03), CF(0, 0.36, -0.91), C.Gun, METAL)
	k.band("GasClamp", -1.72, 0.1, 0.04, 0.57, C.Black)
	k.band("GasClamp", -2.08, 0.1, 0.04, 0.57, C.Black)
	k.band("BarrelBand", -1.9, 0.09, 0.035, 0.45, C.Gun, METAL)
	k.band("BarrelBand", -2.4, 0.09, 0.035, 0.45, C.Gun, METAL)
	k.cylZ("CleaningRod", 0.95, 0.026, CF(0, 0.385, -2.05), C.Chrome, METAL)
	k.band("RodCap", -2.54, 0.045, 0.03, 0.385, C.Black)
	k.box("BayonetLug", V(0.05, 0.07, 0.09), CF(0, 0.4, -2.64), C.Black)
	k.band("BrakeBase", -2.72, 0.1, 0.03, 0.45, C.Gun, METAL)
	k.box("BrakeSlot", V(0.13, 0.016, 0.1), CF(0, 0.45, -2.8), C.Black)
	for i = 0, 2 do
		for _, sx in ipairs({ -1, 1 }) do k.box("StockGrain", V(0.012, 0.012, 0.66), P(sx * 0.087, 0.22 + i * 0.05, 0.67, 6), C.WoodDark, WOOD) end
	end
	-- magazine: smooth the banana + ribs
	k.group = "mag"
	k.box("MagMid", V(0.14, 0.14, 0.255), P(0, -0.09, -0.665, 16), C.Stipple)
	for _, yy in ipairs({ -0.1, 0, 0.1 }) do
		k.box("MagRib", V(0.146, 0.016, 0.2), P(0, 0.06, -0.62, 8) * CF(0, yy, 0), C.Black)
		k.box("MagRib", V(0.146, 0.016, 0.2), P(0, -0.22, -0.72, 24) * CF(0, yy, 0), C.Black)
	end
	k.group = "gun"
end

-- FAMAS
function Detail.HX3(k)
	k.recolor("Spine", C.Gun, METAL); k.recolor("ButtPad", C.Rubber)
	k.pair("SidePlate", V(0.012, 0.2, 1.0), 0.093, 0.375, -0.2, C.Gun, METAL)
	k.slots("Vent", 0.092, 0.37, -0.8, -0.055, 3, 0.03, 0.15)
	k.box("ChargeSlot", V(0.03, 0.02, 0.5), CF(0, 0.565, -0.1), C.Black)
	k.box("Selector", V(0.016, 0.04, 0.12), CF(-0.099, 0.3, 0.2), C.Chrome, METAL)
	k.cylX("MagRelease", 0.02, 0.05, CF(0.099, 0.2, 0.2), C.Chrome, METAL)
	k.pins("BodyPin", 0.095, 0.46, -0.55, 0.035)
	k.pins("BodyPin", 0.095, 0.3, 0.45, 0.035)
	k.band("GasBlock", -1.02, 0.1, 0.1, 0.42, C.Black)
	k.band("BarrelBand", -1.2, 0.085, 0.03, 0.42, C.Gun, METAL)
	k.band("FlashRing", -1.33, 0.115, 0.03, 0.42, C.Gun, METAL)
	muzzleSlots(k, 0.42, -1.41, 0.105)
	k.box("CheekPad", V(0.12, 0.025, 0.3), CF(0, 0.58, 0.38), C.Rubber)
	padRidges(k, 0.6, 0.24, 0.065, 5, 0.19)
	k.box("SlingLug", V(0.03, 0.05, 0.05), CF(0, 0.12, -0.95), C.Gun, METAL)
	magRibs(k, P(0, 0.05, 0.4, 8), 4, -0.14, 0.09, 0.136, 0.2)
end

-- MP7
function Detail.WASP(k)
	k.recolor("Suppressor", C.Gun, METAL); k.recolor("ButtPlate", C.Rubber)
	for i = 0, 3 do k.band("SuppBand", -1.36 - i * 0.14, 0.128, 0.03, 0.4, C.Black) end
	k.band("SuppMount", -1.27, 0.14, 0.05, 0.4, C.Gun, METAL)
	k.band("SuppCap", -1.8, 0.126, 0.05, 0.4, C.Black)
	k.slots("Vent", 0.092, 0.38, -0.9, -0.08, 4, 0.04, 0.12)
	k.box("EjectPort", V(0.014, 0.08, 0.18), CF(0.1, 0.46, -0.28), C.Black)
	k.pins("HingePin", 0.11, 0.44, 0.18, 0.05)
	k.pins("BodyPin", 0.102, 0.34, -0.5, 0.035)
	k.box("SelectorLever", V(0.016, 0.03, 0.1), CF(-0.102, 0.34, 0.0), C.Chrome, METAL)
	for i = 0, 3 do k.box("GripRidge", V(0.106, 0.016, 0.126), P(0, 0.2, -1.0, -8) * CF(0, -0.08 + i * 0.055, 0), C.Black) end
	padRidges(k, 0.84, 0.3, 0.06, 4, 0.18)
	magRibs(k, P(0, -0.08, -0.6, 4), 4, -0.15, 0.09, 0.136, 0.16)
end

-- M249
function Detail.ANVIL(k)
	k.recolor("Receiver", C.Gun, METAL); k.recolor("HeatShield", C.GunLight, METAL); k.recolor("ButtPad", C.Rubber)
	k.group = "cover"
	k.box("CoverLatch", V(0.1, 0.05, 0.06), CF(0, 0.6, -0.6), C.Black)
	for i = 0, 3 do k.box("CoverRib", V(0.246, 0.085, 0.03), CF(0, 0.57, -0.5 + i * 0.15), C.Gun, METAL) end
	k.group = "gun"
	for i = 0, 2 do
		k.pins("Rivet", 0.123, 0.46, -0.85 + i * 0.4, 0.035, C.GunLight)
		k.pins("Rivet", 0.123, 0.3, -0.85 + i * 0.4, 0.035, C.GunLight)
	end
	k.box("EjectPort", V(0.014, 0.1, 0.26), CF(0.122, 0.4, -0.1), C.Black)
	k.slots("Vent", 0.112, 0.36, -1.1, -0.08, 5, 0.04, 0.12)
	for i = 0, 7 do k.box("ShieldVent", V(0.1, 0.012, 0.04), CF(0, 0.527, -1.3 - i * 0.08), C.Black) end
	for i = 0, 4 do k.band("BarrelFin", -2.0 - i * 0.1, 0.15, 0.025, 0.42, C.Gun, METAL) end
	muzzleSlots(k, 0.42, -2.82, 0.15)
	k.pair("BipodFoot", V(0.06, 0.05, 0.07), 0.07, 0.25, -2.27, C.Black)
	k.box("StockGroove", V(0.186, 0.012, 0.5), CF(0, 0.25, 0.72), C.Black)
	k.box("StockGroove", V(0.186, 0.012, 0.5), CF(0, 0.39, 0.72), C.Black)
	padRidges(k, 1.12, 0.16, 0.07, 5, 0.2)
	k.group = "mag"
	for i = 0, 3 do
		k.box("BoxRib", V(0.012, 0.3, 0.03), CF(-0.03 + 0.176, 0, -0.7 + i * 0.1), C.Black)
		k.box("BoxRib", V(0.012, 0.3, 0.03), CF(-0.03 - 0.176, 0, -0.7 + i * 0.1), C.Black)
	end
	k.box("BoxHandle", V(0.2, 0.03, 0.04), CF(-0.03, 0.195, -0.72), C.Black)
	k.box("BeltStub", V(0.06, 0.07, 0.3), CF(-0.03, 0.2, -0.55), C.Brass, METAL)
	k.group = "gun"
end

-- M14 EBR
function Detail.LONGSHOT(k)
	k.recolor("Barrel", C.GunLight, METAL); k.recolor("ButtPad", C.Rubber)
	k.box("HandguardRail", V(0.1, 0.03, 0.8), CF(0, 0.495, -1.38), C.Black)
	for i = 0, 5 do k.box("RailTooth", V(0.12, 0.016, 0.045), CF(0, 0.51, -1.05 - i * 0.12), C.Black) end
	for i = 0, 4 do k.box("Mlok", V(0.07, 0.012, 0.09), CF(0, 0.28, -1.0 - i * 0.17), C.Black) end
	k.slots("BrakePort", 0.062, 0.4, -2.78, -0.07, 3, 0.03, 0.08)
	k.band("GasBlock", -1.9, 0.11, 0.1, 0.4, C.Black)
	k.band("BarrelBand", -2.2, 0.1, 0.035, 0.4, C.Gun, METAL)
	k.band("BarrelBand", -2.5, 0.1, 0.035, 0.4, C.Gun, METAL)
	k.box("OpRodChannel", V(0.012, 0.04, 0.6), CF(0.102, 0.43, -0.8), C.Black)
	k.pins("CheekScrew", 0.072, 0.48, 0.62, 0.03, C.Chrome)
	k.pins("ReceiverPin", 0.103, 0.3, -0.7, 0.035)
	k.pins("ReceiverPin", 0.103, 0.3, 0.1, 0.035)
	padRidges(k, 1.17, 0.12, 0.07, 5, 0.2)
	magRibs(k, P(0, 0.02, -0.62, 4), 4, -0.13, 0.085, 0.156, 0.2)
end

-- AWP
function Detail.HALO50(k)
	k.recolor("Receiver", C.Gun, METAL); k.recolor("Barrel", C.GunLight, METAL); k.recolor("ButtPad", C.Rubber)
	for _, sx in ipairs({ -1, 1 }) do k.box("Flute", V(0.014, 0.02, 1.1), CF(sx * 0.05, 0.42, -2.55), C.Black) end
	k.box("Flute", V(0.02, 0.014, 1.1), CF(0, 0.47, -2.55), C.Black)
	k.slots("BrakePort", 0.082, 0.42, -3.38, -0.07, 3, 0.04, 0.09)
	k.slots("Mlok", 0.102, 0.28, -1.15, -0.14, 5, 0.09, 0.05)
	k.box("EjectPort", V(0.014, 0.09, 0.3), CF(0.098, 0.43, -0.15), C.Black)
	k.box("Spacer", V(0.19, 0.4, 0.016), CF(0, 0.28, 1.2), C.Black)
	k.box("Spacer", V(0.19, 0.4, 0.016), CF(0, 0.28, 1.226), C.WoodDark)
	k.pins("CheekKnob", 0.09, 0.5, 0.62, 0.05)
	k.box("MonopodFoot", V(0.12, 0.03, 0.1), CF(0, -0.055, 1.1), C.Black)
	k.band("BarrelBand", -2.0, 0.11, 0.04, 0.42, C.Gun, METAL)
	k.group = "cycle"
	k.band("BoltShroud", 0.47, 0.105, 0.1, 0.42, C.Black)
	k.group = "mag"
	for i = 0, 2 do k.box("MagRib", V(0.146, 0.014, 0.3), CF(0, 0.02 + i * 0.06, -0.45), C.Black) end
	k.group = "gun"
end

-- Remington 870
function Detail.BREACHER(k)
	k.recolor("Receiver", C.Gun, METAL); k.recolor("Barrel", C.GunLight, METAL); k.recolor("ButtPad", C.Rubber)
	k.box("EjectPort", V(0.014, 0.09, 0.3), CF(0.1, 0.42, -0.15), C.Black)
	k.pins("Pin", 0.103, 0.45, -0.55, 0.035)
	k.pins("Pin", 0.103, 0.3, 0.05, 0.035)
	k.box("VentRib", V(0.04, 0.014, 1.5), CF(0, 0.53, -1.5), C.GunLight, METAL)
	k.band("MagCap", -1.97, 0.125, 0.06, 0.33, C.Chrome, METAL)
	k.box("TubeClamp", V(0.1, 0.22, 0.05), CF(0, 0.4, -1.3), C.Black)
	k.band("BarrelBand", -1.0, 0.11, 0.04, 0.47, C.Gun, METAL)
	padRidges(k, 0.99, 0.15, 0.07, 4, 0.2, 6)
	k.box("StockCheek", V(0.12, 0.03, 0.4), P(0, 0.475, 0.5, 6), C.Rubber)
	k.group = "cycle"
	k.cylZ("ActionBar", 0.45, 0.028, CF(0.07, 0.34, -0.98), C.Chrome, METAL)
	k.cylZ("ActionBar", 0.45, 0.028, CF(-0.07, 0.34, -0.98), C.Chrome, METAL)
	k.group = "gun"
end

-- Glock 17
function Detail.V9(k)
	local g = P(0, -0.05, 0.04, -18)
	k.recolor("Slide", C.Gun, METAL); k.recolor("Frame", C.Polymer)
	k.remove("Serrations")
	k.group = "cycle"
	for i = 0, 4 do k.box("SlideSerr", V(0.168, 0.11, 0.014), CF(0, 0.4, 0.04 + i * 0.035), C.Black) end
	for i = 0, 2 do k.box("SlideSerr", V(0.168, 0.11, 0.014), CF(0, 0.4, -0.46 - i * 0.04), C.Black) end
	k.group = "gun"
	k.box("SlideStop", V(0.02, 0.03, 0.12), CF(-0.08, 0.29, -0.12), C.Chrome, METAL)
	k.box("TakedownLever", V(0.02, 0.035, 0.07), CF(-0.08, 0.26, -0.28), C.Chrome, METAL)
	k.box("MagRelease", V(0.02, 0.04, 0.045), CF(0.078, 0.19, 0.0), C.Black)
	for i = 0, 1 do k.box("RailSlot", V(0.146, 0.014, 0.03), CF(0, 0.188, -0.5 - i * 0.07), C.Black) end
	for r = 0, 3 do
		for c = 0, 2 do
			for _, sx in ipairs({ -1, 1 }) do k.box("GripDot", V(0.012, 0.026, 0.026), g * CF(sx * 0.077, -0.16 + r * 0.08, -0.07 + c * 0.07), C.Black) end
		end
	end
	k.box("Backstrap", V(0.1, 0.4, 0.03), g * CF(0, -0.03, 0.15), C.Dark)
	k.box("MagFlare", V(0.17, 0.03, 0.3), g * CF(0, -0.255, 0.0), C.Black)
	magRibs(k, g * CF(0, -0.12, 0.01), 3, -0.12, 0.08, 0.126, 0.16)
end

-- .44 Magnum
function Detail.MAGNUM(k)
	local g = P(0, -0.03, 0.08, -20)
	k.recolor("Barrel", C.Chrome, METAL)
	k.pins("FrameScrew", 0.078, 0.38, -0.08, 0.035, C.Black)
	k.pins("FrameScrew", 0.078, 0.28, -0.33, 0.035, C.Black)
	k.box("CylRelease", V(0.03, 0.05, 0.07), CF(-0.09, 0.36, 0.03), C.Chrome, METAL)
	k.box("Crown", V(0.11, 0.13, 0.025), CF(0, 0.43, -1.305), C.Black)
	k.cylZ("RodTip", 0.03, 0.06, CF(0, 0.33, -1.19), C.Chrome, METAL)
	k.box("GripPanel", V(0.156, 0.3, 0.18), g * CF(0, -0.02, -0.02), C.WoodDark, WOOD)
	k.cylX("Medallion", 0.012, 0.07, g * CF(0.078, 0.1, 0), C.Brass, METAL)
	k.cylX("Medallion", 0.012, 0.07, g * CF(-0.078, 0.1, 0), C.Brass, METAL)
	k.box("GripCap", V(0.16, 0.03, 0.28), g * CF(0, -0.255, 0), C.Steel, METAL)
	k.group = "mag"
	k.cylZ("CylRing", 0.02, 0.3, CF(0, 0.36, -0.04), C.Steel, METAL)
	k.cylZ("CylRing", 0.02, 0.3, CF(0, 0.36, -0.36), C.Steel, METAL)
	k.group = "gun"
end

GunModels.Models = Models
GunModels.Detail = Detail

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
			k.box("ScopeRingBase", V(0.16, 0.18, 0.1), m * CF(0, 0.09, z - 0.05), C.Dark)
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
	local pass = Models[modelId] and Detail[modelId] -- v4.7 detail pass (adds parts on top of the base model)
	if pass then k.group, k.tag = "gun", nil pass(k) k.group, k.tag = "gun", nil end
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

	local SLEEVE_LEN = 3.6
	-- arms (camera-sized, not gun-scaled). Right arm rides the grip, left arm is animated for reloads.
	local function arm(group, size, offset, color)
		local p = makePart({ Name = "Arm", Size = size, Color = color, Material = SP }, 1)
		p.Anchored = true
		p.Parent = model
		local entry = { Part = p, Offset = offset }
		table.insert(groups[group], entry)
		return entry
	end
	local rHand = scaled.Grip.Position
	local rDir = V(0.45, -0.5, 1).Unit
	arm("gun", V(0.24, 0.26, 0.34), CF(rHand) * scaled.Grip.Rotation, C.Glove)
	arm("gun", V(0.34, 0.34, 1.7), CFrame.lookAt(rHand + rDir * 1.0, rHand + rDir * 2), C.Sleeve)
	arm("gun", V(0.36, 0.36, 0.16), CFrame.lookAt(rHand + rDir * 0.2, rHand + rDir), C.Dark)
	local lDir = V(-0.6, -0.55, 1).Unit
	arm("left", V(0.24, 0.24, 0.36), ang(0, 0, -25), C.Glove)
	-- the left sleeve + cuff are re-aimed every frame by GunClient (Dyn) so the arm always runs down toward a shoulder below the
	-- screen, no matter how high / far back the hand goes. Long on purpose so its far end stays off screen.
	arm("left", V(0.34, 0.34, SLEEVE_LEN), CFrame.lookAt(lDir * 1.1, lDir * 2), C.Sleeve).Dyn = "sleeve"
	arm("left", V(0.36, 0.36, 0.16), CFrame.lookAt(lDir * 0.2, lDir), C.Dark).Dyn = "cuff"

	return {
		Model = model, Groups = groups, Points = scaled,
		SleeveLen = SLEEVE_LEN, Eye = desc.Eye, Sight = desc.Sight, SightId = desc.SightId, View = desc.View,
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
