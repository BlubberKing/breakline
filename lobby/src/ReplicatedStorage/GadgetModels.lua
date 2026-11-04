-- GadgetModels v2 (ModuleScript in ReplicatedStorage) - BOTH games (Breakline + Lobby), keep the two copies IDENTICAL. NEW in v4.1, v4.8: full remodel.
-- One place that knows what every gadget LOOKS like, so the same model is used for:
--   * the thing you hold in first person / others see in your hand        GM.Build(id, accent, opts)
--   * the grenade that flies through the air (GadgetServer welds it to the physics ball)
--   * the sentry / mine / shield device on the ground (GadgetServer builds them from GM.Describe)
--   * the blue / red placement preview                                      GM.Build(id, nil, { ghost = Color3 })
--   * the picture in the lobby + pre-game loadout screens                  GM.Picture(parent, id)  (ViewportFrame, like the gun pictures)
--   * v4.8: the gloved first-person hand that holds them                     GM.BuildHand(parent)
-- It also owns the placement rules (GM.Place + GM.Check) that BOTH the client preview and the server use, so "red" on your screen
-- means the server would refuse it too.
-- Every model is authored with its origin at the item's centre (grenades) or at the ground contact point (sentry / shield / mine),
-- Y up, front = -Z. No dependency on GadgetConfig, so the lobby can use this file on its own.
-- v4.8: names other scripts rely on are unchanged (sentry: "BaseDisc", "Eye", groups "base" / "head", HeadPivot, Muzzle; mine: "Body", "Eye").
local GM = {}

local rgb = Color3.fromRGB
local SP, METAL, NEON = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Neon
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local rad = math.rad

local STEEL, STEEL_HI = rgb(96, 102, 116), rgb(158, 164, 176)
local DARK, DARK2 = rgb(26, 28, 34), rgb(44, 48, 58)
local GOLD, BRASS = rgb(226, 182, 80), rgb(196, 156, 70)
local BLACK = rgb(12, 12, 14)
local RUBBER = rgb(22, 22, 25)
local YELLOW = rgb(236, 208, 70)

GM.Ids = { "FRAG", "SMOKE", "FLASH", "SENTRY", "SHIELD", "MINE" }

-- ============================================================ part lists
local function new()
	local list = {}
	local function add(name, size, cf, color, material, extra)
		local d = { Name = name, Size = size, CF = cf, Color = color, Material = material or SP }
		if extra then for k, v in extra do d[k] = v end end
		table.insert(list, d)
		return d
	end
	-- upright cylinder (axis = Y): diameter, length, centre
	local function cyl(name, diameter, length, cf, color, material, extra)
		local e = { Shape = CYL }
		if extra then for k, v in extra do e[k] = v end end
		return add(name, Vector3.new(length, diameter, diameter), cf * CFrame.Angles(0, 0, rad(90)), color, material, e)
	end
	-- cylinder along Z (front / back): length, diameter, centre
	local function cylZ(name, length, diameter, cf, color, material, extra)
		local e = { Shape = CYL }
		if extra then for k, v in extra do e[k] = v end end
		return add(name, Vector3.new(length, diameter, diameter), cf * CFrame.Angles(0, rad(90), 0), color, material, e)
	end
	local function ball(name, size, cf, color, material, extra)
		local e = { Shape = BALL }
		if extra then for k, v in extra do e[k] = v end end
		return add(name, size, cf, color, material, e)
	end
	-- a flat ring (8 boxes) around the local Z axis of `cf`: radius to the middle of the ring, thickness, depth
	local function ring(name, cf, R, thick, depth, color, material, extra)
		local len = 2 * R * math.tan(math.pi / 8) + thick * 0.6
		for i = 0, 7 do
			add(name, Vector3.new(len, thick, depth), cf * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, R, 0), color, material, extra)
		end
	end
	-- a flat strip in the XY plane from point a to point b (thickness = how thick, width = how wide along Z)
	local function strip(name, a, b, thick, width, z, color, material, extra)
		local d = b - a
		local len = math.sqrt(d.X * d.X + d.Y * d.Y)
		local phi = math.atan2(-d.X, d.Y)
		local mid = (a + b) / 2
		return add(name, Vector3.new(thick, len, width), CFrame.new(mid.X, mid.Y, z or 0) * CFrame.Angles(0, 0, phi), color, material, extra)
	end
	return list, add, cyl, ball, cylZ, ring, strip
end

-- fuze, safety lever (spoon) and pull ring shared by the three grenades.
-- R = body radius at the shoulder, topY = top of the body, path = list of Vector2 (x, y) the lever follows, hx = height of the fuze
local function grenadeTop(h, R, topY, path, fuzeW)
	local add, cyl, cylZ, ring, strip = h.add, h.cyl, h.cylZ, h.ring, h.strip
	local fw = fuzeW or 0.3
	cyl("FuzeSeat", fw * 1.3, 0.1, CFrame.new(0, topY + 0.02, 0), DARK2, METAL)
	cyl("FuzeBody", fw, 0.26, CFrame.new(0, topY + 0.17, 0), rgb(70, 74, 82), METAL)
	cyl("FuzeBand", fw * 1.1, 0.04, CFrame.new(0, topY + 0.11, 0), STEEL_HI, METAL)
	cyl("FuzeCap", fw * 0.72, 0.08, CFrame.new(0, topY + 0.33, 0), DARK2, METAL)
	-- lever: a plate over the fuze and a strip that hugs the body
	add("LeverHead", Vector3.new(fw * 1.8, 0.055, fw * 0.85), CFrame.new(fw * 0.35, topY + 0.38, 0), STEEL_HI, METAL)
	local prev = Vector3.new(fw * 0.35 + fw * 0.9, topY + 0.38, 0)
	for i, p in path do
		local pt = Vector3.new(p.X, p.Y, 0)
		strip("Lever", prev, pt, 0.05, fw * 0.8, 0, STEEL_HI, METAL)
		prev = pt
	end
	cylZ("LeverHinge", fw * 0.95, 0.07, CFrame.new(fw * 0.9, topY + 0.34, 0), STEEL, METAL)
	-- safety pin through the fuze + pull ring
	cylZ("Pin", fw * 1.5, 0.04, CFrame.new(0, topY + 0.2, 0), GOLD, METAL)
	ring("PinRing", CFrame.new(0, topY + 0.2, fw * 0.75 + 0.14) * CFrame.Angles(0, rad(90), 0), 0.12, 0.028, 0.03, GOLD, METAL)
end

local BUILDERS = {}

-- M67-style fragmentation grenade
BUILDERS.FRAG = function()
	local list, add, cyl, ball, cylZ, ring, strip = new()
	local OD, SEAM = rgb(72, 90, 58), rgb(40, 52, 36)
	ball("Body", Vector3.new(0.95, 1.15, 0.95), CFrame.new(), OD, METAL)
	cyl("Seam", 0.96, 0.03, CFrame.new(0, 0, 0), SEAM, METAL)
	cyl("SeamHi", 0.79, 0.03, CFrame.new(0, 0.33, 0), SEAM, METAL)
	cyl("SeamLo", 0.79, 0.03, CFrame.new(0, -0.33, 0), SEAM, METAL)
	-- stencilled markings on the front
	add("Stencil", Vector3.new(0.36, 0.1, 0.02), CFrame.new(0, 0.14, -0.463), YELLOW, SP)
	add("StencilBar", Vector3.new(0.22, 0.045, 0.02), CFrame.new(0, 0.0, -0.472), YELLOW, SP)
	add("StencilBar", Vector3.new(0.14, 0.045, 0.02), CFrame.new(0, -0.1, -0.468), YELLOW, SP)
	cyl("Neck", 0.42, 0.14, CFrame.new(0, 0.58, 0), rgb(54, 68, 46), METAL)
	cyl("BasePlug", 0.3, 0.06, CFrame.new(0, -0.57, 0), DARK2, METAL)
	local h = { add = add, cyl = cyl, cylZ = cylZ, ring = ring, strip = strip }
	grenadeTop(h, 0.5, 0.64, {
		Vector2.new(0.4, 0.82), Vector2.new(0.46, 0.6), Vector2.new(0.5, 0.36), Vector2.new(0.525, 0.1), Vector2.new(0.52, -0.16),
	}, 0.3)
	return { Parts = list }
end

-- M18-style smoke canister
BUILDERS.SMOKE = function()
	local list, add, cyl, ball, cylZ, ring, strip = new()
	local BODY = rgb(132, 140, 126)
	cyl("Body", 0.85, 1.45, CFrame.new(), BODY, METAL)
	cyl("SeamHi", 0.89, 0.04, CFrame.new(0, 0.6, 0), DARK2, METAL)
	cyl("SeamLo", 0.89, 0.04, CFrame.new(0, -0.6, 0), DARK2, METAL)
	-- colour band (white = the cloud colour) and a hazard stripe ring
	cyl("ColourBand", 0.87, 0.2, CFrame.new(0, 0.45, 0), rgb(236, 238, 240), SP)
	cyl("StripeBand", 0.87, 0.12, CFrame.new(0, -0.15, 0), YELLOW, SP)
	for i = 0, 7 do
		local a = i * math.pi / 4
		add("Stripe", Vector3.new(0.03, 0.12, 0.09), CFrame.new(math.cos(a) * 0.435, -0.15, math.sin(a) * 0.435) * CFrame.Angles(0, -a, 0), BLACK, SP)
	end
	add("Label", Vector3.new(0.34, 0.26, 0.02), CFrame.new(0, 0.12, -0.43), rgb(214, 216, 210), SP)
	add("LabelBar", Vector3.new(0.26, 0.04, 0.025), CFrame.new(0, 0.16, -0.435), rgb(70, 78, 70), SP)
	add("LabelBar", Vector3.new(0.2, 0.04, 0.025), CFrame.new(0, 0.08, -0.435), rgb(70, 78, 70), SP)
	-- top shoulder with the smoke vents, bottom plate with vents
	cyl("Shoulder", 0.8, 0.1, CFrame.new(0, 0.77, 0), DARK2, METAL)
	cyl("TopPlate", 0.62, 0.06, CFrame.new(0, 0.83, 0), rgb(60, 64, 72), METAL)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		add("Vent", Vector3.new(0.09, 0.05, 0.09), CFrame.new(math.cos(a) * 0.23, 0.862, math.sin(a) * 0.23) * CFrame.Angles(0, -a, 0), BLACK, SP)
	end
	cyl("BottomPlate", 0.8, 0.08, CFrame.new(0, -0.76, 0), DARK2, METAL)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		add("Vent", Vector3.new(0.09, 0.05, 0.09), CFrame.new(math.cos(a) * 0.23, -0.805, math.sin(a) * 0.23), BLACK, SP)
	end
	local h = { add = add, cyl = cyl, cylZ = cylZ, ring = ring, strip = strip }
	grenadeTop(h, 0.42, 0.86, {
		Vector2.new(0.42, 1.03), Vector2.new(0.465, 0.9), Vector2.new(0.465, 0.4), Vector2.new(0.465, -0.15), Vector2.new(0.46, -0.5),
	}, 0.26)
	return { Parts = list }
end

-- M84-style flashbang: aluminium body full of vent slots, black end caps
BUILDERS.FLASH = function()
	local list, add, cyl, ball, cylZ, ring, strip = new()
	cyl("Body", 0.7, 1.15, CFrame.new(), rgb(172, 176, 186), METAL)
	cyl("CapTop", 0.74, 0.18, CFrame.new(0, 0.665, 0), rgb(30, 32, 38), METAL)
	cyl("CapLow", 0.74, 0.16, CFrame.new(0, -0.655, 0), rgb(30, 32, 38), METAL)
	cyl("SeamTop", 0.72, 0.03, CFrame.new(0, 0.55, 0), DARK2, METAL)
	cyl("SeamLow", 0.72, 0.03, CFrame.new(0, -0.55, 0), DARK2, METAL)
	cyl("Band", 0.72, 0.17, CFrame.new(0, 0.0, 0), YELLOW, SP)
	for _, y in { 0.3, -0.3 } do
		for i = 0, 7 do
			local a = i * math.pi / 4
			add("Vent", Vector3.new(0.03, 0.09, 0.1), CFrame.new(math.cos(a) * 0.35, y, math.sin(a) * 0.35) * CFrame.Angles(0, -a, 0), BLACK, SP)
		end
	end
	for i = 0, 5 do
		local a = i * math.pi / 3
		add("TopVent", Vector3.new(0.09, 0.04, 0.09), CFrame.new(math.cos(a) * 0.27, 0.76, math.sin(a) * 0.27) * CFrame.Angles(0, -a, 0), BLACK, SP)
	end
	local h = { add = add, cyl = cyl, cylZ = cylZ, ring = ring, strip = strip }
	grenadeTop(h, 0.36, 0.755, {
		Vector2.new(0.36, 0.9), Vector2.new(0.395, 0.78), Vector2.new(0.4, 0.4), Vector2.new(0.4, 0.0), Vector2.new(0.395, -0.35),
	}, 0.24)
	return { Parts = list }
end

-- sentry turret. Origin = ground. group "base" stays put, group "head" turns (pivot = (0, 2.2, 0)). Parts with Collide = true block movement.
BUILDERS.SENTRY = function(accent)
	local list, add, cyl, ball, cylZ, ring, strip = new()
	local ACC = accent or rgb(90, 190, 255)
	local ARMOR, ARMOR2 = rgb(60, 66, 80), rgb(46, 50, 62)
	local B, H = { Group = "base" }, { Group = "head" }
	local function withGroup(g, extra)
		local e = { Group = g.Group }
		if extra then for k, v in extra do e[k] = v end end
		return e
	end
	-- ground plate with bolts
	cyl("BaseDisc", 2.8, 0.28, CFrame.new(0, 0.14, 0), DARK, METAL, withGroup(B, { Collide = true }))
	cyl("BaseRing", 2.5, 0.06, CFrame.new(0, 0.3, 0), ACC, NEON, B)
	cyl("BasePlate", 1.9, 0.1, CFrame.new(0, 0.33, 0), rgb(34, 38, 46), METAL, B)
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.2
		cyl("Bolt", 0.16, 0.1, CFrame.new(math.cos(a) * 1.18, 0.35, math.sin(a) * 1.18), STEEL_HI, METAL, B)
	end
	-- column with corner plates, hydraulic rods, cable
	add("Column", Vector3.new(0.9, 1.5, 0.9), CFrame.new(0, 1.05, 0), rgb(52, 58, 70), METAL, withGroup(B, { Collide = true }))
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add("ColumnCorner", Vector3.new(0.16, 1.5, 0.16), CFrame.new(sx * 0.45, 1.05, sz * 0.45) * CFrame.Angles(0, rad(45), 0), ARMOR2, METAL, B)
		end
	end
	for _, sx in { -1, 1 } do
		cyl("Rod", 0.1, 0.9, CFrame.new(sx * 0.52, 1.2, -0.1), STEEL_HI, METAL, B)
		cyl("RodSleeve", 0.18, 0.5, CFrame.new(sx * 0.52, 0.85, -0.1), DARK2, METAL, B)
	end
	cyl("Cable", 0.1, 1.3, CFrame.new(0.2, 1.1, 0.52), BLACK, SP, B)
	add("ColumnLight", Vector3.new(0.2, 0.08, 0.04), CFrame.new(0, 0.7, -0.465), ACC, NEON, B)
	-- tripod legs, knees and feet
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		local base = CFrame.new(0, 0.85, 0) * CFrame.Angles(0, a, 0)
		add("Leg", Vector3.new(0.28, 1.5, 0.28), base * CFrame.new(0, 0, -0.78) * CFrame.Angles(rad(30), 0, 0), rgb(70, 76, 90), METAL, B)
		add("LegCover", Vector3.new(0.2, 0.7, 0.34), base * CFrame.new(0, 0.12, -0.52) * CFrame.Angles(rad(30), 0, 0), ARMOR2, METAL, B)
		ball("Knee", Vector3.one * 0.34, base * CFrame.new(0, 0.55, -0.45), STEEL, METAL, B)
		add("FootPad", Vector3.new(0.52, 0.1, 0.52), CFrame.new(0, 0.33, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.2), RUBBER, SP, B)
	end
	-- slew ring the head turns on
	cyl("SlewRing", 1.5, 0.14, CFrame.new(0, 1.84, 0), STEEL, METAL, B)
	cyl("SlewRingDark", 1.3, 0.1, CFrame.new(0, 1.94, 0), BLACK, METAL, B)
	for i = 0, 11 do
		local a = i * math.pi / 6
		add("SlewTooth", Vector3.new(0.1, 0.08, 0.06), CFrame.new(math.cos(a) * 0.75, 1.84, math.sin(a) * 0.75) * CFrame.Angles(0, -a, 0), STEEL_HI, METAL, B)
	end

	-- ===== head (turns) =====
	add("Body", Vector3.new(1.8, 1.1, 2.0), CFrame.new(0, 2.2, 0), rgb(58, 64, 78), METAL, H)
	add("Plate", Vector3.new(1.5, 0.18, 1.7), CFrame.new(0, 2.82, 0.1), rgb(40, 44, 54), METAL, H)
	add("Cap", Vector3.new(1.0, 0.1, 1.2), CFrame.new(0, 2.94, 0.1), ACC, NEON, H)
	add("CapFrame", Vector3.new(1.1, 0.08, 1.3), CFrame.new(0, 2.915, 0.1), BLACK, METAL, H)
	add("Glacis", Vector3.new(1.6, 0.16, 0.8), CFrame.new(0, 2.62, -0.92) * CFrame.Angles(rad(-28), 0, 0), ARMOR, METAL, H)
	for _, s in { -1, 1 } do
		add("Side", Vector3.new(0.2, 0.8, 1.5), CFrame.new(s * 1.0, 2.2, 0.1), DARK, METAL, H)
		add("SideLight", Vector3.new(0.05, 0.12, 1.2), CFrame.new(s * 1.12, 2.38, 0.1), ACC, NEON, H)
		add("Cheek", Vector3.new(0.14, 0.9, 1.1), CFrame.new(s * 1.03, 2.2, -0.55) * CFrame.Angles(0, rad(-s * 12), 0), ARMOR, METAL, H)
		add("SideBolt", Vector3.new(0.05, 0.12, 0.12), CFrame.new(s * 1.13, 2.0, 0.55), STEEL_HI, METAL, H)
		add("SideBolt", Vector3.new(0.05, 0.12, 0.12), CFrame.new(s * 1.13, 2.0, -0.2), STEEL_HI, METAL, H)
		for i = 0, 3 do add("Louvre", Vector3.new(0.06, 0.05, 0.5), CFrame.new(s * 1.05, 2.45 + i * 0.1 - 0.15, 0.55), BLACK, SP, H) end
	end
	cyl("Hatch", 0.7, 0.08, CFrame.new(0.35, 2.93, 0.55), DARK2, METAL, H)
	cyl("HatchHandle", 0.28, 0.08, CFrame.new(0.35, 2.99, 0.55), STEEL_HI, METAL, H)
	-- gun: receiver, shroud with vents, barrel with cooling rings, muzzle brake
	add("Receiver", Vector3.new(0.62, 0.6, 1.1), CFrame.new(0, 2.25, -1.0), rgb(48, 52, 62), METAL, H)
	add("FeedTray", Vector3.new(0.5, 0.1, 0.5), CFrame.new(0, 2.58, -0.95), STEEL, METAL, H)
	add("Shroud", Vector3.new(0.58, 0.58, 1.1), CFrame.new(0, 2.25, -1.4), STEEL, METAL, H)
	for i = 0, 4 do
		for _, s in { -1, 1 } do add("ShroudVent", Vector3.new(0.04, 0.3, 0.07), CFrame.new(s * 0.295, 2.25, -1.0 - i * 0.18), BLACK, SP, H) end
	end
	add("Barrel", Vector3.new(0.34, 0.34, 2.0), CFrame.new(0, 2.25, -1.95), DARK, METAL, H)
	for i = 0, 3 do cylZ("BarrelRing", 0.05, 0.42, CFrame.new(0, 2.25, -2.0 - i * 0.25), STEEL, METAL, H) end
	add("Muzzle", Vector3.new(0.5, 0.5, 0.22), CFrame.new(0, 2.25, -2.9), STEEL_HI, METAL, H)
	add("MuzzleSlot", Vector3.new(0.52, 0.06, 0.12), CFrame.new(0, 2.25, -2.9), BLACK, SP, H)
	add("MuzzleSlot", Vector3.new(0.06, 0.52, 0.12), CFrame.new(0, 2.25, -2.9), BLACK, SP, H)
	-- sensor eye + housing, side sensors
	add("EyeHousing", Vector3.new(0.78, 0.34, 0.16), CFrame.new(0, 2.4, -1.0), BLACK, METAL, H)
	add("Eye", Vector3.new(0.5, 0.18, 0.12), CFrame.new(0, 2.4, -1.02), rgb(255, 70, 70), NEON, H)
	ball("Sensor", Vector3.one * 0.26, CFrame.new(0.55, 2.46, -1.03), ACC, NEON, H)
	ball("Sensor", Vector3.one * 0.26, CFrame.new(-0.55, 2.46, -1.03), ACC, NEON, H)
	-- rear ammo box with lid + handle, exhaust slits, antenna, camera dome
	add("Ammo", Vector3.new(0.9, 0.7, 0.6), CFrame.new(0, 2.1, 1.25), rgb(72, 80, 62), METAL, H)
	add("AmmoLid", Vector3.new(0.94, 0.08, 0.64), CFrame.new(0, 2.47, 1.25), rgb(60, 68, 52), METAL, H)
	add("AmmoHandle", Vector3.new(0.4, 0.06, 0.06), CFrame.new(0, 2.54, 1.25), STEEL_HI, METAL, H)
	add("AmmoLatch", Vector3.new(0.14, 0.12, 0.04), CFrame.new(0, 2.3, 1.57), STEEL, METAL, H)
	for i = 0, 3 do add("Exhaust", Vector3.new(0.5, 0.05, 0.04), CFrame.new(0, 1.9 + i * 0.12, 1.02), BLACK, SP, H) end
	add("Antenna", Vector3.new(0.06, 0.9, 0.06), CFrame.new(-0.6, 3.35, 0.5), STEEL, METAL, H)
	ball("AntennaTip", Vector3.one * 0.15, CFrame.new(-0.6, 3.82, 0.5), rgb(255, 80, 80), NEON, H)
	ball("Dome", Vector3.new(0.5, 0.36, 0.5), CFrame.new(-0.55, 2.98, -0.2), rgb(30, 34, 40), METAL, H)
	return { Parts = list, HeadPivot = Vector3.new(0, 2.2, 0), Muzzle = Vector3.new(0, 2.25, -3.1) }
end

-- bubble shield projector (the dome itself is built by the server). Origin = ground.
BUILDERS.SHIELD = function(accent)
	local list, add, cyl, ball, cylZ, ring, strip = new()
	local ACC = accent or rgb(100, 220, 230)
	cyl("Puck", 2.2, 0.3, CFrame.new(0, 0.15, 0), DARK2, METAL)
	cyl("PuckRim", 2.28, 0.08, CFrame.new(0, 0.06, 0), BLACK, METAL)
	cyl("PuckRing", 1.9, 0.07, CFrame.new(0, 0.33, 0), ACC, NEON)
	cyl("PuckDeck", 1.5, 0.08, CFrame.new(0, 0.34, 0), rgb(36, 40, 48), METAL)
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.3
		cyl("Bolt", 0.14, 0.08, CFrame.new(math.cos(a) * 1.02, 0.34, math.sin(a) * 1.02), STEEL_HI, METAL)
	end
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.78
		add("Vent", Vector3.new(0.3, 0.04, 0.08), CFrame.new(math.cos(a) * 0.62, 0.395, math.sin(a) * 0.62) * CFrame.Angles(0, -a, 0), BLACK, SP)
	end
	-- pylons: angled struts with emitter heads and status lights
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3 + 0.5
		local base = CFrame.new(math.cos(a) * 0.8, 0, math.sin(a) * 0.8) * CFrame.Angles(0, -a, 0)
		add("Pylon", Vector3.new(0.22, 0.85, 0.22), base * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, rad(-8)), STEEL, METAL)
		add("PylonFoot", Vector3.new(0.4, 0.14, 0.4), base * CFrame.new(0.0, 0.4, 0), DARK2, METAL)
		cyl("Emitter", 0.28, 0.2, base * CFrame.new(-0.06, 1.18, 0), STEEL_HI, METAL)
		ball("EmitterTip", Vector3.one * 0.18, base * CFrame.new(-0.06, 1.3, 0), ACC, NEON)
		add("PylonLight", Vector3.new(0.05, 0.16, 0.05), base * CFrame.new(-0.12, 0.75, 0), ACC, NEON)
	end
	-- core inside a ring cage
	ball("Core", Vector3.one * 0.95, CFrame.new(0, 0.95, 0), ACC, NEON, { Transparency = 0.3 })
	ball("CoreHi", Vector3.one * 0.45, CFrame.new(0, 0.95, 0), rgb(240, 255, 255), NEON)
	ring("CageRing", CFrame.new(0, 0.95, 0) * CFrame.Angles(rad(90), 0, 0), 0.55, 0.05, 0.08, STEEL, METAL)
	ring("CageRing", CFrame.new(0, 0.95, 0), 0.55, 0.05, 0.08, STEEL, METAL)
	cyl("CoreSeat", 0.5, 0.12, CFrame.new(0, 0.42, 0), DARK2, METAL)
	cyl("Cap", 0.55, 0.12, CFrame.new(0, 1.55, 0), STEEL_HI, METAL)
	cyl("CapFin", 0.3, 0.1, CFrame.new(0, 1.65, 0), DARK2, METAL)
	return { Parts = list }
end

-- proximity mine. Origin = the surface it sticks to (Y = away from the surface).
BUILDERS.MINE = function()
	local list, add, cyl, ball, cylZ, ring, strip = new()
	cyl("Body", 1.5, 0.38, CFrame.new(0, 0.19, 0), rgb(48, 52, 62), METAL)
	cyl("Rim", 1.64, 0.1, CFrame.new(0, 0.07, 0), rgb(26, 28, 34), METAL)
	cyl("Shoulder", 1.3, 0.1, CFrame.new(0, 0.4, 0), rgb(38, 42, 50), METAL)
	cyl("Ring", 1.05, 0.08, CFrame.new(0, 0.42, 0), rgb(255, 130, 60), NEON)
	cyl("Plate", 0.7, 0.1, CFrame.new(0, 0.47, 0), rgb(34, 36, 44), METAL)
	ball("Eye", Vector3.one * 0.38, CFrame.new(0, 0.52, 0), rgb(90, 20, 20), NEON)
	for i = 0, 5 do
		local a = i * math.pi / 3
		cyl("Bolt", 0.12, 0.07, CFrame.new(math.cos(a) * 0.72, 0.17, math.sin(a) * 0.72), STEEL_HI, METAL)
	end
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		local c = CFrame.new(math.cos(a) * 0.6, 0.42, math.sin(a) * 0.6) * CFrame.Angles(0, -a, 0)
		add("Rib", Vector3.new(0.16, 0.06, 0.06), c, i % 2 == 0 and YELLOW or BLACK, SP)
	end
	add("Label", Vector3.new(0.3, 0.02, 0.18), CFrame.new(0.0, 0.405, 0.42), rgb(214, 216, 210), SP)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3 + 0.4
		add("Sensor", Vector3.new(0.16, 0.24, 0.16), CFrame.new(math.cos(a) * 0.62, 0.42, math.sin(a) * 0.62), DARK, METAL)
		cyl("SensorStem", 0.07, 0.2, CFrame.new(math.cos(a) * 0.62, 0.52, math.sin(a) * 0.62), STEEL, METAL)
		ball("SensorTip", Vector3.one * 0.13, CFrame.new(math.cos(a) * 0.62, 0.62, math.sin(a) * 0.62), rgb(255, 150, 80), NEON)
	end
	return { Parts = list }
end

function GM.Describe(id, accent)
	local b = BUILDERS[id]
	return b and b(accent) or nil
end

-- ============================================================ building real parts
-- opts: anchored (default true) | scale | ghost = Color3 (everything becomes one see-through colour, for the placement preview)
-- Returns a Model (PrimaryPart = nil, its pivot is the item origin, so model:PivotTo(cf) puts the origin at cf).
function GM.Build(id, accent, opts)
	opts = opts or {}
	local desc = GM.Describe(id, accent)
	if not desc then return nil end
	local scale = opts.scale or 1
	local model = Instance.new("Model")
	model.Name = "Gadget_" .. id
	for _, d in desc.Parts do
		local p = Instance.new("Part")
		p.Name = d.Name
		if d.Shape then p.Shape = d.Shape end
		p.Size = d.Size * scale
		p.CFrame = CFrame.new(d.CF.Position * scale) * d.CF.Rotation
		p.Color, p.Material, p.Transparency = d.Color, d.Material, d.Transparency or 0
		p.Anchored = opts.anchored ~= false
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if opts.ghost then
			p.Color, p.Material, p.Transparency = opts.ghost, SP, 0.55
		end
		if not p.Anchored then p.Massless = true end
		p:SetAttribute("Group", d.Group)
		p.Parent = model
	end
	model.WorldPivot = CFrame.identity
	return model, desc
end

-- welds every part of an UNANCHORED model to `to` (keeping where they are right now)
function GM.WeldTo(model, to)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= to then
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = to, d
			w.Parent = d
		end
	end
end

-- ============================================================ the gloved first-person hand (v4.8)
-- Origin = the middle of the palm, +Y up toward the item, -Z forward. The item is held about 0.2 studs above the palm: four fingers
-- curl up the front of it, the thumb wraps the left side. Everything is anchored; move it with model:PivotTo(cf).
function GM.BuildHand(parent)
	local model = Instance.new("Model")
	model.Name = "GadgetHand"
	local GLOVE, PAD = rgb(30, 30, 34), rgb(56, 58, 64)
	local function part(name, size, cf, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		if shape then p.Shape = shape end
		p.Size = size
		p.CFrame = cf
		p.Color, p.Material = color, SP
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
	end
	local function seg(a, b, d, color)
		local len = (b - a).Magnitude
		if len < 0.002 then return end
		part("Finger", Vector3.new(len, d, d), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0), color, CYL)
	end
	local function chain(points, d)
		for i = 1, #points - 1 do seg(points[i], points[i + 1], d, GLOVE) end
		for i = 2, #points do part("Knuckle", Vector3.one * d * 1.06, CFrame.new(points[i]), i == #points and GLOVE or PAD, BALL) end
	end
	part("Palm", Vector3.new(0.3, 0.09, 0.3), CFrame.new(0, -0.01, 0.04), GLOVE)
	part("PalmPad", Vector3.new(0.18, 0.03, 0.14), CFrame.new(0, 0.04, 0.0), PAD)
	part("Wrist", Vector3.new(0.3, 0.2, 0.2), CFrame.new(0, -0.03, 0.27) * CFrame.Angles(0, rad(90), 0), GLOVE, CYL)
	for i, x in { -0.105, -0.035, 0.035, 0.105 } do
		chain({
			Vector3.new(x, 0.01, -0.1),
			Vector3.new(x, 0.03, -0.18),
			Vector3.new(x, 0.14, -0.215),
			Vector3.new(x, 0.25, -0.17),
		}, i == 4 and 0.058 or 0.068)
	end
	chain({
		Vector3.new(-0.17, 0.04, 0.06),
		Vector3.new(-0.21, 0.14, -0.03),
		Vector3.new(-0.19, 0.24, -0.12),
		Vector3.new(-0.12, 0.3, -0.16),
	}, 0.072)
	model.WorldPivot = CFrame.identity
	model.Parent = parent
	return model
end


-- ============================================================ lobby / HUD picture (side by side with the gun pictures)
GM.PicDir = { SENTRY = Vector3.new(0.95, 0.5, -1.1), SHIELD = Vector3.new(0.9, 0.7, 1.1), MINE = Vector3.new(0.9, 0.85, 1.1) }
function GM.Picture(parent, id, opts)
	opts = opts or {}
	local vp = Instance.new("ViewportFrame")
	vp.Name = "GadgetPicture"
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = rgb(150, 152, 160)
	vp.LightColor = rgb(255, 250, 244)
	vp.LightDirection = Vector3.new(-0.5, -1, -0.4)
	vp.Parent = parent
	local model = GM.Build(id, opts.accent or rgb(110, 200, 255), { anchored = true })
	if not model then return vp end
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 26
	cam.Parent = vp
	vp.CurrentCamera = cam
	local dir = (GM.PicDir[id] or Vector3.new(0.85, 0.45, 1.15)).Unit
	local dist = (size.Magnitude * 0.5) / math.tan(math.rad(13)) * 1.08
	cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
	return vp
end

-- ============================================================ placement rules (client preview AND server)
-- range: how far from your head the spot may be | ground: needs a floor-ish surface (not a wall) | box: clearance box | foot: half-size of the
-- footprint that must all rest on the surface (no hanging over an edge)
GM.Place = {
	SENTRY = { range = 15, ground = true, box = Vector3.new(3.4, 3.2, 3.4), foot = 1.2 },
	SHIELD = { range = 15, ground = true, box = Vector3.new(2.6, 2.2, 2.6), foot = 1.0 },
	MINE   = { range = 13, ground = false, box = Vector3.new(1.5, 0.9, 1.5), foot = 0 },
}

-- a CFrame sitting ON a surface (up = normal) turned to face `facing`
function GM.CFOnSurface(pos, normal, facing)
	local up = normal.Unit
	local look = facing - up * facing:Dot(up)
	if look.Magnitude < 0.05 then
		look = up:Cross(Vector3.xAxis)
		if look.Magnitude < 0.05 then look = up:Cross(Vector3.zAxis) end
	end
	look = look.Unit
	local back = -look
	return CFrame.fromMatrix(pos, up:Cross(back), up, back)
end

-- ignore = list of instances to skip (characters etc). Returns ok, reason.
function GM.Check(id, pos, normal, ignore)
	local pl = GM.Place[id]
	if not pl then return false, "bad item" end
	normal = normal.Unit
	if pl.ground and normal.Y < 0.72 then return false, "too steep" end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore or {}
	rp.RespectCanCollide = true
	if pl.foot > 0 then
		local base = GM.CFOnSurface(pos, normal, Vector3.zAxis)
		for _, o in { Vector2.new(1, 1), Vector2.new(-1, 1), Vector2.new(1, -1), Vector2.new(-1, -1) } do
			local from = (base * CFrame.new(o.X * pl.foot, 0.7, o.Y * pl.foot)).Position
			local hit = workspace:Raycast(from, -normal * 1.5, rp)
			if not hit or hit.Normal:Dot(normal) < 0.6 then return false, "uneven ground" end
		end
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = ignore or {}
	op.RespectCanCollide = true
	local c = GM.CFOnSurface(pos + normal * (pl.box.Y / 2 + 0.18), normal, Vector3.zAxis)
	if #workspace:GetPartBoundsInBox(c, pl.box, op) > 0 then return false, "something is in the way" end
	return true
end

return GM
