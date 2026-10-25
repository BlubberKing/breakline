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

-- VX-9: M4-style carbine (the original rifle)
function Models.VX9(k)
	stdGrip(k)
	k.box("LowerReceiver", V(0.27, 0.3, 1.0), CF(0, 0.33, -0.25))
	k.box("Magwell", V(0.25, 0.2, 0.38), CF(0, 0.12, -0.62))
	k.box("UpperReceiver", V(0.3, 0.26, 1.35), CF(0, 0.6, -0.32))
	k.box("TopCover", V(0.24, 0.06, 1.2), CF(0, 0.755, -0.32), C.Metal)
	k.box("Rail", V(0.18, 0.05, 1.15), CF(0, 0.81, -0.35), C.Dark)
	for i = 0, 8 do k.box("RailTooth", V(0.2, 0.025, 0.05), CF(0, 0.845, -0.85 + i * 0.125), C.Dark) end
	k.box("EjectionPort", V(0.02, 0.12, 0.34), CF(0.152, 0.6, -0.2), C.Dark)
	k.box("ChargingHandle", V(0.14, 0.06, 0.14), CF(0, 0.75, 0.4), C.Dark)
	k.glow("SideStripeR", V(0.02, 0.035, 0.8), CF(0.155, 0.5, -0.45))
	k.glow("SideStripeL", V(0.02, 0.035, 0.8), CF(-0.155, 0.5, -0.45))
	k.box("Handguard", V(0.32, 0.32, 1.05), CF(0, 0.56, -1.5), C.Polymer)
	k.box("HandguardRail", V(0.16, 0.04, 0.9), CF(0, 0.74, -1.5), C.Dark)
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 2 do k.box("Vent", V(0.02, 0.09, 0.2), CF(sx * 0.162, 0.6, -1.2 - i * 0.3), C.Dark) end
	end
	k.glow("HandguardStripe", V(0.12, 0.02, 0.6), CF(0, 0.395, -1.62))
	local fore = P(0, 0.25, -1.2, -8)
	k.box("Foregrip", V(0.13, 0.32, 0.15), fore, C.Dark)
	k.fore(fore)
	k.box("GasBlock", V(0.16, 0.15, 0.1), CF(0, 0.6, -2.08), C.Dark)
	k.cylZ("Barrel", 0.75, 0.12, CF(0, 0.58, -2.4), C.Metal)
	k.cylZ("MuzzleDevice", 0.28, 0.2, CF(0, 0.58, -2.85), C.Dark)
	k.muzzle(V(0, 0.58, -3.0))
	k.cylZ("BufferTube", 0.55, 0.13, CF(0, 0.58, 0.6), C.Dark)
	k.box("Stock", V(0.22, 0.36, 0.6), CF(0, 0.47, 0.95), C.Polymer)
	k.box("CheekRest", V(0.2, 0.08, 0.42), CF(0, 0.68, 0.92))
	k.box("ButtPad", V(0.24, 0.48, 0.1), CF(0, 0.43, 1.3), C.Dark)
	k.tag = "Iron"
	k.box("RearSightBase", V(0.14, 0.08, 0.1), CF(0, 0.89, 0.12), C.Dark)
	k.ring("RearAperture", CF(0, 0.97, 0.12), 0.035, 0.025, 0.04, C.Dark)
	k.box("FrontSightBase", V(0.1, 0.32, 0.07), CF(0, 0.8, -2.08), C.Dark)
	k.box("FrontPost", V(0.025, 0.06, 0.025), CF(0, 0.94, -2.08), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.97, 0.12), 0.42)
	k.mount(CF(0, 0.87, -0.45))
	k.eject(V(0.17, 0.6, -0.2))
	k.group = "mag"
	local m = P(0, -0.15, -0.68, 12)
	k.box("Mag", V(0.19, 0.6, 0.34), m, C.Polymer)
	k.glow("MagBase", V(0.21, 0.05, 0.37), m * CF(0, -0.3, 0))
	k.magwell(CF(0, -0.15, -0.68))
end

-- KR-47: AK-pattern, wood furniture, curved mag
function Models.KR47(k)
	stdGrip(k, C.Dark, 0.04, -20)
	k.box("Receiver", V(0.26, 0.32, 1.35), CF(0, 0.38, -0.35), C.Body)
	k.box("DustCover", V(0.24, 0.12, 1.15), CF(0, 0.6, -0.28), C.Metal)
	k.box("Rail", V(0.14, 0.04, 0.55), CF(0, 0.68, -0.25), C.Dark)
	k.box("Selector", V(0.02, 0.06, 0.5), CF(0.135, 0.45, -0.25), C.Metal)
	k.box("EjectionPort", V(0.02, 0.1, 0.3), CF(0.132, 0.55, -0.4), C.Dark)
	k.box("ChargingHandle", V(0.14, 0.05, 0.05), CF(0.15, 0.55, -0.62), C.Steel, METAL)
	k.box("LowerGuard", V(0.28, 0.26, 0.85), CF(0, 0.42, -1.45), C.Wood, WOOD)
	k.box("UpperGuard", V(0.2, 0.12, 0.72), CF(0, 0.6, -1.4), C.Wood, WOOD)
	k.glow("GuardStripeR", V(0.01, 0.03, 0.5), CF(0.142, 0.42, -1.45))
	k.glow("GuardStripeL", V(0.01, 0.03, 0.5), CF(-0.142, 0.42, -1.45))
	k.fore(CF(0, 0.32, -1.35))
	k.cylZ("Barrel", 1.15, 0.1, CF(0, 0.45, -2.42), C.Metal, METAL)
	k.cylZ("GasTube", 0.5, 0.09, CF(0, 0.62, -2.05), C.Metal, METAL)
	k.box("GasBlock", V(0.12, 0.24, 0.1), CF(0, 0.53, -2.3), C.Dark)
	k.box("FrontSightBlock", V(0.1, 0.22, 0.1), CF(0, 0.58, -2.62), C.Dark)
	k.cylZ("MuzzleBrake", 0.2, 0.15, CF(0, 0.45, -3.05), C.Dark)
	k.muzzle(V(0, 0.45, -3.17))
	k.box("Stock", V(0.2, 0.34, 0.9), P(0, 0.3, 0.75, 6), C.Wood, WOOD)
	k.box("ButtPad", V(0.22, 0.42, 0.08), P(0, 0.26, 1.2, 6), C.Dark)
	k.tag = "Iron"
	k.box("RearLeaf", V(0.15, 0.06, 0.12), CF(0, 0.69, -0.95), C.Dark)
	for _, sx in ipairs({ -1, 1 }) do k.box("RearEar", V(0.04, 0.07, 0.04), CF(sx * 0.045, 0.755, -0.95), C.Dark) end
	k.box("FrontPost", V(0.025, 0.12, 0.025), CF(0, 0.73, -2.62), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.785, -0.95), 0.62)
	k.mount(CF(0, 0.7, -0.25))
	k.eject(V(0.15, 0.55, -0.4))
	k.group = "mag"
	k.box("Mag", V(0.18, 0.4, 0.3), P(0, 0.05, -0.72, 10), C.Dark)
	k.box("MagLow", V(0.18, 0.38, 0.28), P(0, -0.28, -0.86, 26), C.Dark)
	k.glow("MagBase", V(0.2, 0.04, 0.31), P(0, -0.46, -0.96, 26))
	k.magwell(CF(0, 0.1, -0.72))
end

-- HX-3: FAMAS-style bullpup burst rifle with carry handle
function Models.HX3(k)
	stdGrip(k, C.Dark, -0.3, -12)
	k.box("Body", V(0.3, 0.48, 1.9), CF(0, 0.38, -0.2), C.Polymer)
	k.box("BodyTop", V(0.26, 0.1, 1.7), CF(0, 0.66, -0.25), C.Body)
	k.box("Cheek", V(0.24, 0.1, 0.5), CF(0, 0.66, 0.55), C.Dark)
	k.box("ButtPad", V(0.3, 0.52, 0.08), CF(0, 0.34, 0.79), C.Dark)
	k.box("Lower", V(0.28, 0.2, 0.7), CF(0, 0.08, -0.85), C.Polymer)
	k.glow("SideStripeR", V(0.01, 0.04, 1.2), CF(0.152, 0.4, -0.3))
	k.glow("SideStripeL", V(0.01, 0.04, 1.2), CF(-0.152, 0.4, -0.3))
	for _, sx in ipairs({ -1, 1 }) do -- split posts so you can see between them
		k.box("HandlePostR", V(0.03, 0.26, 0.12), CF(sx * 0.07, 0.82, 0.5), C.Body)
		k.box("HandlePostF", V(0.03, 0.26, 0.12), CF(sx * 0.07, 0.82, -1.05), C.Body)
	end
	k.box("HandleTop", V(0.17, 0.06, 1.7), CF(0, 0.96, -0.28), C.Body)
	k.box("HandleRail", V(0.14, 0.03, 0.6), CF(0, 1.005, -0.3), C.Dark)
	k.fore(CF(0, 0.12, -0.95))
	k.cylZ("Barrel", 0.55, 0.11, CF(0, 0.45, -1.42), C.Metal, METAL)
	k.cylZ("FlashHider", 0.22, 0.16, CF(0, 0.45, -1.78), C.Dark)
	k.muzzle(V(0, 0.45, -1.92))
	k.tag = "Iron"
	k.box("RearSight", V(0.03, 0.06, 0.04), CF(0, 0.875, 0.35), C.Dark)
	k.box("FrontPost", V(0.025, 0.05, 0.025), CF(0, 0.875, -0.95), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.9, 0.35), 0.4)
	k.mount(CF(0, 1.02, -0.3))
	k.eject(V(0.17, 0.5, 0.3))
	k.group = "mag"
	k.box("Mag", V(0.18, 0.5, 0.3), P(0, 0.0, 0.42, 8), C.Dark)
	k.glow("MagBase", V(0.2, 0.04, 0.32), P(0, -0.25, 0.46, 8))
	k.magwell(CF(0, 0.1, 0.42))
end

-- WASP: compact Vector/MP7-style SMG
function Models.WASP(k)
	stdGrip(k, C.Dark, 0.04, -12)
	k.box("Upper", V(0.26, 0.3, 1.3), CF(0, 0.48, -0.35), C.Polymer)
	k.box("Lower", V(0.24, 0.5, 0.42), P(0, 0.16, -0.95, 22), C.Polymer)
	k.box("LowerBack", V(0.24, 0.2, 0.5), CF(0, 0.22, -0.35), C.Body)
	k.box("Rail", V(0.16, 0.04, 1.05), CF(0, 0.65, -0.4), C.Dark)
	k.glow("SideStripeR", V(0.01, 0.03, 0.9), CF(0.132, 0.5, -0.4))
	k.glow("SideStripeL", V(0.01, 0.03, 0.9), CF(-0.132, 0.5, -0.4))
	k.cylZ("Barrel", 0.35, 0.1, CF(0, 0.5, -1.15), C.Metal, METAL)
	k.cylZ("Suppressor", 0.3, 0.16, CF(0, 0.5, -1.42), C.Dark)
	k.muzzle(V(0, 0.5, -1.6))
	k.fore(CF(0, 0.12, -1.02))
	k.box("StockArmR", V(0.03, 0.08, 0.7), CF(0.08, 0.5, 0.62), C.Dark)
	k.box("StockArmL", V(0.03, 0.08, 0.7), CF(-0.08, 0.5, 0.62), C.Dark)
	k.box("ButtPlate", V(0.2, 0.32, 0.06), CF(0, 0.45, 0.98), C.Dark)
	k.tag = "Iron"
	k.box("RearSight", V(0.1, 0.07, 0.05), CF(0, 0.705, 0.12), C.Dark)
	k.box("FrontSight", V(0.03, 0.08, 0.03), CF(0, 0.71, -0.86), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.75, 0.12), 0.42)
	k.mount(CF(0, 0.67, -0.35))
	k.eject(V(0.15, 0.5, -0.3))
	k.group = "mag"
	k.box("Mag", V(0.15, 0.55, 0.22), P(0, -0.2, -0.55, 6), C.Dark)
	k.glow("MagBase", V(0.17, 0.04, 0.24), P(0, -0.47, -0.58, 6))
	k.magwell(CF(0, -0.1, -0.55))
end

-- ANVIL: M249-style LMG with box mag
function Models.ANVIL(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.34, 0.42, 1.4), CF(0, 0.42, -0.3), C.Body)
	k.box("FeedCover", V(0.32, 0.1, 0.85), CF(0, 0.68, -0.2), C.Metal)
	k.box("Rail", V(0.16, 0.04, 0.7), CF(0, 0.75, -0.2), C.Dark)
	k.box("Handguard", V(0.32, 0.3, 0.65), CF(0, 0.44, -1.32), C.Polymer)
	k.box("HeatShield", V(0.22, 0.06, 0.9), CF(0, 0.62, -1.75), C.Metal)
	k.glow("SideStripeR", V(0.01, 0.04, 1.0), CF(0.172, 0.35, -0.3))
	k.glow("SideStripeL", V(0.01, 0.04, 1.0), CF(-0.172, 0.35, -0.3))
	k.cylZ("Barrel", 1.3, 0.16, CF(0, 0.47, -2.2), C.Metal, METAL)
	k.box("CarryHandle", V(0.05, 0.05, 0.45), CF(0.14, 0.72, -1.5), C.Dark)
	k.cylZ("BipodLegR", 0.9, 0.05, CF(0.06, 0.32, -2.0), C.Dark)
	k.cylZ("BipodLegL", 0.9, 0.05, CF(-0.06, 0.32, -2.0), C.Dark)
	k.cylZ("FlashHider", 0.25, 0.2, CF(0, 0.47, -2.95), C.Dark)
	k.muzzle(V(0, 0.47, -3.1))
	k.fore(CF(0, 0.26, -1.25))
	k.box("Stock", V(0.24, 0.4, 0.8), CF(0, 0.37, 0.8), C.Polymer)
	k.box("ButtPad", V(0.26, 0.46, 0.08), CF(0, 0.35, 1.22), C.Dark)
	k.tag = "Iron"
	k.box("RearSight", V(0.12, 0.08, 0.06), CF(0, 0.81, 0.15), C.Dark)
	k.box("FrontBase", V(0.07, 0.3, 0.07), CF(0, 0.68, -2.55), C.Dark)
	k.box("FrontPost", V(0.025, 0.05, 0.025), CF(0, 0.855, -2.55), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.875, 0.15), 0.45)
	k.mount(CF(0, 0.77, -0.2))
	k.eject(V(0.18, 0.5, -0.2))
	k.group = "mag"
	k.box("Mag", V(0.42, 0.45, 0.5), CF(-0.04, -0.02, -0.62), C.Olive)
	k.glow("MagBase", V(0.44, 0.04, 0.52), CF(-0.04, -0.25, -0.62))
	k.magwell(CF(0, 0.1, -0.62))
end

-- LONGSHOT: M14 EBR-style marksman rifle
function Models.LONGSHOT(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.28, 0.36, 1.4), CF(0, 0.38, -0.35), C.Tan)
	k.box("Rail", V(0.18, 0.05, 1.7), CF(0, 0.6, -0.55), C.Dark)
	for i = 0, 11 do k.box("RailTooth", V(0.2, 0.025, 0.05), CF(0, 0.635, -1.3 + i * 0.13), C.Dark) end
	k.box("Handguard", V(0.3, 0.3, 1.05), CF(0, 0.42, -1.55), C.Tan)
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 3 do k.box("Vent", V(0.02, 0.1, 0.16), CF(sx * 0.152, 0.42, -1.2 - i * 0.24), C.Dark) end
	end
	k.glow("Stripe", V(0.12, 0.02, 0.7), CF(0, 0.265, -1.55))
	k.cylZ("Barrel", 1.0, 0.12, CF(0, 0.42, -2.55), C.Metal, METAL)
	k.box("MuzzleBrake", V(0.18, 0.16, 0.3), CF(0, 0.42, -3.15), C.Dark)
	k.muzzle(V(0, 0.42, -3.32))
	k.fore(CF(0, 0.25, -1.45))
	k.box("Stock", V(0.2, 0.36, 0.75), CF(0, 0.33, 0.85), C.Dark)
	k.box("CheekRiser", V(0.18, 0.1, 0.42), CF(0, 0.56, 0.8), C.Tan)
	k.box("ButtPad", V(0.22, 0.44, 0.08), CF(0, 0.3, 1.25), C.Dark)
	k.tag = "Iron"
	k.ring("RearAperture", CF(0, 0.72, 0.2), 0.035, 0.025, 0.04, C.Dark)
	k.box("RearBase", V(0.12, 0.06, 0.08), CF(0, 0.66, 0.2), C.Dark)
	k.box("FrontBase", V(0.08, 0.1, 0.06), CF(0, 0.66, -2.0), C.Dark)
	k.box("FrontPost", V(0.025, 0.05, 0.025), CF(0, 0.695, -2.0), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.72, 0.2), 0.42)
	k.mount(CF(0, 0.66, -0.4))
	k.eject(V(0.16, 0.45, -0.3))
	k.group = "mag"
	k.box("Mag", V(0.18, 0.45, 0.32), P(0, 0.0, -0.68, 5), C.Dark)
	k.glow("MagBase", V(0.2, 0.04, 0.34), P(0, -0.22, -0.7, 5))
	k.magwell(CF(0, 0.1, -0.68))
end

-- HALO-50: AWM-style bolt-action sniper
function Models.HALO50(k)
	stdGrip(k, C.Olive, 0.04, -20)
	k.box("Chassis", V(0.3, 0.3, 1.25), CF(0, 0.27, -0.55), C.Olive)
	k.cylZ("Receiver", 1.05, 0.26, CF(0, 0.47, -0.35), C.Body)
	k.box("Rail", V(0.16, 0.05, 1.0), CF(0, 0.6, -0.35), C.Dark)
	k.box("Forend", V(0.3, 0.3, 1.0), CF(0, 0.36, -1.55), C.Olive)
	k.glow("StripeR", V(0.01, 0.03, 0.8), CF(0.152, 0.3, -1.5))
	k.glow("StripeL", V(0.01, 0.03, 0.8), CF(-0.152, 0.3, -1.5))
	k.cylZ("Barrel", 1.7, 0.13, CF(0, 0.47, -2.65), C.Metal, METAL)
	k.box("MuzzleBrake", V(0.22, 0.18, 0.32), CF(0, 0.47, -3.62), C.Dark)
	k.muzzle(V(0, 0.47, -3.8))
	k.fore(CF(0, 0.22, -1.4))
	k.box("Stock", V(0.24, 0.42, 1.0), CF(0, 0.32, 0.85), C.Olive)
	k.box("CheekRest", V(0.2, 0.1, 0.5), CF(0, 0.58, 0.75), C.Dark)
	k.box("ButtPad", V(0.26, 0.5, 0.08), CF(0, 0.3, 1.38), C.Dark)
	k.box("Monopod", V(0.06, 0.24, 0.06), CF(0, 0.02, 1.15), C.Dark)
	k.tag = "Iron"
	k.ring("RearAperture", CF(0, 0.7, 0.08), 0.035, 0.025, 0.04, C.Dark)
	k.box("FrontPost", V(0.025, 0.1, 0.025), CF(0, 0.65, -1.55), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.7, 0.08), 0.42)
	k.mount(CF(0, 0.625, -0.3))
	k.eject(V(0.18, 0.5, -0.1))
	k.group = "cycle" -- bolt
	k.cylZ("Bolt", 0.3, 0.14, CF(0, 0.47, 0.3), C.Steel, METAL)
	k.cylX("BoltHandle", 0.26, 0.05, CF(0.18, 0.45, 0.1), C.Steel, METAL)
	k.box("BoltKnob", V(0.1, 0.1, 0.1), CF(0.32, 0.43, 0.1), C.Dark)
	k.group = "mag"
	k.box("Mag", V(0.18, 0.28, 0.4), CF(0, 0.06, -0.45), C.Dark)
	k.glow("MagBase", V(0.2, 0.04, 0.42), CF(0, -0.08, -0.45))
	k.magwell(CF(0, 0.12, -0.45))
end

-- BREACHER: pump-action shotgun (Remington 870 style)
function Models.BREACHER(k)
	stdGrip(k, C.Dark)
	k.box("Receiver", V(0.26, 0.36, 1.0), CF(0, 0.42, -0.3), C.Body)
	k.box("Rail", V(0.14, 0.04, 0.5), CF(0, 0.62, -0.3), C.Dark)
	k.box("LoadingPort", V(0.16, 0.03, 0.4), CF(0, 0.235, -0.45), C.Dark)
	k.glow("SideStripeR", V(0.01, 0.03, 0.7), CF(0.132, 0.42, -0.3))
	k.glow("SideStripeL", V(0.01, 0.03, 0.7), CF(-0.132, 0.42, -0.3))
	k.cylZ("Barrel", 1.75, 0.14, CF(0, 0.53, -1.67), C.Metal, METAL)
	k.cylZ("TubeMag", 1.35, 0.13, CF(0, 0.35, -1.45), C.Dark)
	k.box("BarrelClamp", V(0.12, 0.3, 0.08), CF(0, 0.44, -2.2), C.Dark)
	k.box("Bead", V(0.04, 0.04, 0.04), CF(0, 0.64, -2.48), C.Steel, METAL)
	k.muzzle(V(0, 0.53, -2.56))
	k.box("Stock", V(0.22, 0.36, 0.9), P(0, 0.32, 0.72, 6), C.Polymer)
	k.box("ButtPad", V(0.24, 0.42, 0.1), P(0, 0.28, 1.18, 6), C.Dark)
	k.tag = "Iron"
	k.ring("GhostRing", CF(0, 0.66, -0.1), 0.04, 0.025, 0.04, C.Dark)
	k.box("RearBase", V(0.12, 0.06, 0.08), CF(0, 0.62, -0.1), C.Dark)
	k.tag = nil
	k.irons(V(0, 0.66, -0.1), 0.48)
	k.mount(CF(0, 0.64, -0.3))
	k.eject(V(0.15, 0.45, -0.3))
	k.group = "cycle" -- pump
	local pump = CF(0, 0.34, -1.25)
	k.box("Pump", V(0.26, 0.24, 0.6), pump, C.Polymer)
	for i = 0, 4 do k.box("PumpRidge", V(0.27, 0.25, 0.04), pump * CF(0, 0, -0.24 + i * 0.12), C.Dark) end
	k.fore(pump * CF(0, -0.05, 0))
	k.magwell(CF(0, 0.2, -0.45))
end

-- V9: Glock-style sidearm
function Models.V9(k)
	local g = P(0, -0.05, 0.04, -18)
	k.box("Grip", V(0.17, 0.55, 0.3), g, C.Polymer)
	k.box("GripTexture", V(0.18, 0.3, 0.2), g * CF(0, -0.05, 0.01), C.Dark)
	k.grip(g)
	k.box("Frame", V(0.16, 0.14, 0.82), CF(0, 0.25, -0.26), C.Polymer)
	k.box("TriggerGuard", V(0.04, 0.035, 0.26), CF(0, 0.12, -0.24), C.Polymer)
	k.box("Trigger", V(0.03, 0.1, 0.04), P(0, 0.16, -0.18, -12), C.Dark)
	k.glow("FrameStripe", V(0.165, 0.02, 0.45), CF(0, 0.2, -0.42))
	k.fore(g * CF(-0.02, -0.05, -0.02))
	k.muzzle(V(0, 0.41, -0.76))
	k.group = "cycle" -- slide
	k.box("Slide", V(0.18, 0.18, 0.92), CF(0, 0.41, -0.25), C.Body)
	k.box("Serrations", V(0.185, 0.12, 0.16), CF(0, 0.41, 0.1), C.Dark)
	k.box("EjectionPort", V(0.02, 0.07, 0.18), CF(0.092, 0.45, -0.2), C.Steel, METAL)
	k.box("RearSight", V(0.13, 0.05, 0.05), CF(0, 0.525, 0.15), C.Dark)
	k.box("FrontSight", V(0.03, 0.05, 0.03), CF(0, 0.525, -0.66), C.Dark)
	k.cylZ("BarrelTip", 0.03, 0.08, CF(0, 0.41, -0.72), C.Dark)
	k.group = "gun"
	k.irons(V(0, 0.55, 0.15), 0.62)
	k.mount(CF(0, 0.5, -0.05))
	k.eject(V(0.1, 0.46, -0.2))
	k.group = "mag"
	k.box("Mag", V(0.13, 0.42, 0.22), g * CF(0, -0.12, 0.01), C.Dark)
	k.glow("MagBase", V(0.18, 0.05, 0.31), g * CF(0, -0.3, 0))
	k.magwell(g * CF(0, -0.28, 0))
	k.view = { X = 0.45, Y = -0.8, Z = -1.3, SprintRot = V(-40, 20, 10) }
end

-- MAGNUM .44: S&W Model 29-style revolver
function Models.MAGNUM(k)
	local g = P(0, -0.03, 0.08, -20)
	k.box("Grip", V(0.16, 0.5, 0.28), g, C.Wood, WOOD)
	k.grip(g)
	k.box("Frame", V(0.17, 0.3, 0.5), CF(0, 0.33, -0.18), C.Steel, METAL)
	k.box("TopStrap", V(0.12, 0.06, 0.55), CF(0, 0.52, -0.18), C.Steel, METAL)
	k.box("TriggerGuard", V(0.04, 0.035, 0.24), CF(0, 0.12, -0.12), C.Steel, METAL)
	k.box("Trigger", V(0.03, 0.1, 0.04), P(0, 0.16, -0.08, -12), C.Dark)
	k.box("Barrel", V(0.1, 0.13, 0.85), CF(0, 0.44, -0.84), C.Steel, METAL)
	k.box("Underlug", V(0.08, 0.1, 0.78), CF(0, 0.33, -0.82), C.Steel, METAL)
	k.glow("RibStripe", V(0.04, 0.012, 0.7), CF(0, 0.512, -0.84))
	k.box("FrontRamp", V(0.03, 0.07, 0.1), CF(0, 0.535, -1.18), C.Dark)
	k.box("RearNotch", V(0.1, 0.04, 0.05), CF(0, 0.56, 0.02), C.Dark)
	k.muzzle(V(0, 0.44, -1.3))
	k.fore(g * CF(-0.02, -0.05, -0.02))
	k.irons(V(0, 0.57, 0.02), 0.62)
	k.mount(CF(0, 0.555, -0.25))
	k.eject(V(0, 0.36, -0.2))
	k.group = "cycle" -- hammer
	k.box("Hammer", V(0.05, 0.12, 0.08), P(0, 0.48, 0.1, 20), C.Dark)
	k.group = "mag" -- cylinder
	k.cylZ("Mag", 0.36, 0.3, CF(0, 0.36, -0.2), C.Steel, METAL)
	for i = 0, 5 do
		local a = i * math.pi / 3
		k.cylZ("Flute", 0.3, 0.06, CF(math.cos(a) * 0.15, 0.36 + math.sin(a) * 0.15, -0.2), C.Dark)
	end
	k.magwell(CF(0, 0.36, -0.2))
	k.view = { X = 0.45, Y = -0.8, Z = -1.3, SprintRot = V(-40, 20, 10) }
end

GunModels.Models = Models

-- ================= SIGHTS =================
-- Each optic: Display name, Mag (zoom, nil = use the gun's ADSFov), Eye (aim distance), Overlay (full-screen scope)
local Sights = {}
GunModels.Sights = Sights

Sights.Iron = { Display = "Iron" }

Sights.RedDot = { Display = "Red Dot", Reticle = "Dot", Eye = 0.45,
	Build = function(k, m)
		k.box("DotBase", V(0.2, 0.07, 0.34), m * CF(0, 0.035, 0), C.Body)
		local c = m * CF(0, 0.2, -0.02)
		k.ring("DotHood", c, 0.1, 0.03, 0.2, C.Body)
		k.ring("DotLip", c * CF(0, 0, -0.1), 0.105, 0.025, 0.03, C.Metal)
		k.box("DotBridge", V(0.12, 0.06, 0.18), c * CF(0, -0.14, 0), C.Body)
		k.cylX("DotKnob", 0.05, 0.08, c * CF(0.15, -0.03, 0.03), C.Metal)
		k.glow("DotStripe", V(0.04, 0.01, 0.12), c * CF(0, 0.135, 0))
		k.box("DotLens", V(0.008, 0.21, 0.21), c * CF(0, 0, -0.07) * ang(0, 90, 0), C.Lens, GLASS,
			{ Shape = CYL, Transparency = 0.8, NoShadow = true })
		k.box("DotReticle", V(0.2, 0.2, 0.002), c * CF(0, 0, -0.06), C.Dark, SP, { Transparency = 1, Reticle = "Dot" })
		return c * CF(0, 0, -0.06)
	end }

Sights.Holo = { Display = "Holo", Reticle = "Holo", Eye = 0.55,
	Build = function(k, m)
		k.box("HoloBase", V(0.26, 0.09, 0.52), m * CF(0, 0.045, 0), C.Body)
		k.box("HoloBattery", V(0.24, 0.07, 0.2), m * CF(0, 0.12, 0.14), C.Body)
		local c = m * CF(0, 0.25, -0.1)
		for _, sx in ipairs({ -1, 1 }) do k.box("HoloPost", V(0.035, 0.28, 0.12), c * CF(sx * 0.155, 0, 0), C.Body) end
		k.box("HoloTop", V(0.345, 0.04, 0.14), c * CF(0, 0.15, 0), C.Body)
		k.box("HoloLow", V(0.3, 0.05, 0.12), c * CF(0, -0.125, 0), C.Body)
		k.glow("HoloStripe", V(0.18, 0.01, 0.06), c * CF(0, 0.172, 0))
		k.box("HoloGlass", V(0.28, 0.2, 0.01), c * CF(0, 0.01, -0.05), C.Lens, GLASS, { Transparency = 0.82, NoShadow = true })
		k.box("HoloReticle", V(0.26, 0.2, 0.002), c * CF(0, 0.01, -0.04), C.Dark, SP, { Transparency = 1, Reticle = "Holo" })
		return c * CF(0, 0.01, -0.04)
	end }

Sights.Ranger3x = { Display = "3x", Reticle = "Chevron", Mag = 3, Eye = 0.16,
	Build = function(k, m)
		k.box("ScopeBase", V(0.2, 0.08, 0.42), m * CF(0, 0.04, 0), C.Body)
		local c = m * CF(0, 0.24, -0.05)
		k.ring("ScopeTube", c, 0.12, 0.035, 0.5, C.Body)
		k.ring("ScopeBell", c * CF(0, 0, -0.3), 0.13, 0.04, 0.1, C.Dark)
		k.ring("ScopeEye", c * CF(0, 0, 0.29), 0.12, 0.04, 0.08, C.Dark)
		k.box("ScopeTop", V(0.08, 0.06, 0.2), c * CF(0, 0.17, 0.02), C.Dark)
		k.glow("ScopeStripe", V(0.03, 0.01, 0.32), c * CF(0.11, 0.11, 0) * ang(0, 0, -45))
		k.box("ScopeLens", V(0.008, 0.25, 0.25), c * CF(0, 0, -0.3) * ang(0, 90, 0), C.Lens, GLASS,
			{ Shape = CYL, Transparency = 0.85, NoShadow = true })
		k.box("ScopeReticle", V(0.24, 0.24, 0.002), c * CF(0, 0, -0.29), C.Dark, SP, { Transparency = 1, Reticle = "Chevron" })
		return c * CF(0, 0, 0.33)
	end }

Sights.Sniper8x = { Display = "8x", Mag = 8, Eye = 0.2, Overlay = true,
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
		k.box("ScopeLens", V(0.008, 0.33, 0.33), c * CF(0, 0, -0.74) * ang(0, 90, 0), C.Lens, GLASS,
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
		aim = sight.Build(k, k.pts.Mount)
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
		frame(30, 30, 0.82, true)
		frame(10, 10, 0, true)
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
	local groups = { gun = {}, mag = {}, cycle = {}, left = {}, flash = {} }
	local magPivot = scaleCF(pts.MagPivot, s)
	for _, d in ipairs(desc.Parts) do
		local p = makePart(d, s)
		p.Anchored = true
		p.Parent = model
		local off = scaleCF(d.CF, s)
		if d.Group == "mag" then off = magPivot:Inverse() * off end
		table.insert(groups[d.Group], { Part = p, Offset = off })
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
		if not d.Reticle then
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
