-- GadgetModels (ModuleScript in ReplicatedStorage) - BOTH games (Breakline + Lobby), keep the two copies IDENTICAL. NEW in v4.1.
-- One place that knows what every gadget LOOKS like, so the same model is used for:
--   * the thing you hold in first person / others see in your hand        GM.Build(id, accent, opts)
--   * the grenade that flies through the air (GadgetServer welds it to the physics ball)
--   * the sentry / mine / shield device on the ground (GadgetServer builds them from GM.Describe)
--   * the blue / red placement preview                                      GM.Build(id, nil, { ghost = Color3 })
--   * the picture in the lobby + pre-game loadout screens                  GM.Picture(parent, id)  (ViewportFrame, like the gun pictures)
-- It also owns the placement rules (GM.Place + GM.Check) that BOTH the client preview and the server use, so "red" on your screen
-- means the server would refuse it too.
-- Every model is authored with its origin at the item's centre (grenades) or at the ground contact point (sentry / shield / mine),
-- Y up, front = -Z. No dependency on GadgetConfig, so the lobby can use this file on its own.
local GM = {}

local rgb = Color3.fromRGB
local SP, METAL, NEON = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Neon
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local rad = math.rad

local STEEL, STEEL_HI = rgb(96, 102, 116), rgb(158, 164, 176)
local DARK, DARK2 = rgb(30, 33, 40), rgb(46, 50, 60)
local GOLD = rgb(236, 188, 80)

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
	local function ball(name, size, cf, color, material, extra)
		local e = { Shape = BALL }
		if extra then for k, v in extra do e[k] = v end end
		return add(name, size, cf, color, material, e)
	end
	return list, add, cyl, ball
end

local function grenadeLever(add, cyl, x, h, tall)
	add("Lever", Vector3.new(0.12, h, 0.26), CFrame.new(x, 0.2, 0) * CFrame.Angles(0, 0, rad(-5)), STEEL_HI, METAL)
	add("LeverTop", Vector3.new(0.5, 0.12, 0.26), CFrame.new(x - 0.22, tall, 0), STEEL_HI, METAL)
	cyl("Pin", 0.34, 0.05, CFrame.new(-0.12, tall + 0.1, 0) * CFrame.Angles(0, 0, rad(90)), GOLD, METAL)
end

local BUILDERS = {}

BUILDERS.FRAG = function()
	local list, add, cyl, ball = new()
	ball("Body", Vector3.new(0.95, 1.15, 0.95), CFrame.new(), rgb(74, 98, 62), METAL)
	cyl("Band", 0.99, 0.07, CFrame.new(0, 0, 0), rgb(38, 50, 34), METAL)
	cyl("BandHi", 0.84, 0.07, CFrame.new(0, 0.3, 0), rgb(38, 50, 34), METAL)
	cyl("BandLo", 0.84, 0.07, CFrame.new(0, -0.3, 0), rgb(38, 50, 34), METAL)
	cyl("Neck", 0.38, 0.22, CFrame.new(0, 0.6, 0), DARK2, METAL)
	cyl("Fuse", 0.28, 0.2, CFrame.new(0, 0.76, 0), DARK, METAL)
	grenadeLever(add, cyl, 0.46, 0.95, 0.74)
	return { Parts = list }
end

BUILDERS.SMOKE = function()
	local list, add, cyl = new()
	cyl("Body", 0.85, 1.45, CFrame.new(), rgb(140, 150, 166), METAL)
	cyl("Band", 0.89, 0.28, CFrame.new(0, 0.14, 0), rgb(232, 236, 246), SP)
	cyl("Stripe", 0.9, 0.07, CFrame.new(0, -0.28, 0), rgb(110, 200, 255), NEON)
	cyl("CapTop", 0.62, 0.2, CFrame.new(0, 0.82, 0), DARK2, METAL)
	cyl("Nozzle", 0.28, 0.25, CFrame.new(0, 1.0, 0), STEEL, METAL)
	cyl("CapLow", 0.8, 0.1, CFrame.new(0, -0.76, 0), DARK, METAL)
	grenadeLever(add, cyl, 0.48, 1.2, 0.9)
	return { Parts = list }
end

BUILDERS.FLASH = function()
	local list, add, cyl = new()
	cyl("Body", 0.7, 1.15, CFrame.new(), rgb(84, 88, 98), METAL)
	cyl("Band", 0.74, 0.22, CFrame.new(0, 0.08, 0), rgb(252, 226, 92), SP)
	for i = 0, 5 do
		local a = i * math.pi / 3
		add("Vent", Vector3.new(0.12, 0.2, 0.12), CFrame.new(math.cos(a) * 0.35, -0.32, math.sin(a) * 0.35) * CFrame.Angles(0, -a, 0), DARK, SP)
	end
	cyl("CapTop", 0.52, 0.18, CFrame.new(0, 0.66, 0), DARK2, METAL)
	cyl("Fuse", 0.26, 0.18, CFrame.new(0, 0.8, 0), STEEL, METAL)
	cyl("CapLow", 0.66, 0.1, CFrame.new(0, -0.62, 0), DARK, METAL)
	grenadeLever(add, cyl, 0.4, 0.95, 0.72)
	return { Parts = list }
end

-- sentry turret. Origin = ground. group "base" stays put, group "head" turns (pivot = (0, 2.2, 0)). Parts with Collide = true block movement.
BUILDERS.SENTRY = function(accent)
	local list, add, cyl, ball = new()
	local ACC = accent or rgb(90, 190, 255)
	cyl("BaseDisc", 2.8, 0.28, CFrame.new(0, 0.14, 0), DARK, METAL, { Group = "base", Collide = true })
	cyl("BaseRing", 2.5, 0.06, CFrame.new(0, 0.3, 0), ACC, NEON, { Group = "base" })
	add("Column", Vector3.new(0.9, 1.5, 0.9), CFrame.new(0, 1.05, 0), rgb(52, 58, 70), METAL, { Group = "base", Collide = true })
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		add("Leg", Vector3.new(0.28, 1.5, 0.28),
			CFrame.new(0, 0.85, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.78) * CFrame.Angles(rad(30), 0, 0), rgb(70, 76, 90), METAL, { Group = "base" })
	end
	add("Body", Vector3.new(1.8, 1.1, 2.0), CFrame.new(0, 2.2, 0), rgb(58, 64, 78), METAL, { Group = "head" })
	add("Plate", Vector3.new(1.5, 0.18, 1.7), CFrame.new(0, 2.82, 0.1), rgb(40, 44, 54), METAL, { Group = "head" })
	add("Cap", Vector3.new(1.0, 0.14, 1.2), CFrame.new(0, 2.93, 0.1), ACC, NEON, { Group = "head" })
	for _, s in { -1, 1 } do
		add("Side", Vector3.new(0.2, 0.8, 1.5), CFrame.new(s * 1.0, 2.2, 0.1), DARK, METAL, { Group = "head" })
		add("SideLight", Vector3.new(0.05, 0.12, 1.2), CFrame.new(s * 1.12, 2.38, 0.1), ACC, NEON, { Group = "head" })
	end
	add("Shroud", Vector3.new(0.58, 0.58, 1.1), CFrame.new(0, 2.25, -1.4), STEEL, METAL, { Group = "head" })
	add("Barrel", Vector3.new(0.34, 0.34, 2.0), CFrame.new(0, 2.25, -1.95), DARK, METAL, { Group = "head" })
	add("Muzzle", Vector3.new(0.5, 0.5, 0.22), CFrame.new(0, 2.25, -2.9), STEEL_HI, METAL, { Group = "head" })
	add("Eye", Vector3.new(0.5, 0.18, 0.12), CFrame.new(0, 2.4, -1.02), rgb(255, 70, 70), NEON, { Group = "head" })
	ball("Sensor", Vector3.one * 0.26, CFrame.new(0.55, 2.46, -1.03), ACC, NEON, { Group = "head" })
	ball("Sensor", Vector3.one * 0.26, CFrame.new(-0.55, 2.46, -1.03), ACC, NEON, { Group = "head" })
	add("Ammo", Vector3.new(0.9, 0.7, 0.6), CFrame.new(0, 2.1, 1.25), rgb(72, 80, 62), METAL, { Group = "head" })
	add("Antenna", Vector3.new(0.06, 0.9, 0.06), CFrame.new(-0.6, 3.35, 0.5), STEEL, METAL, { Group = "head" })
	ball("AntennaTip", Vector3.one * 0.15, CFrame.new(-0.6, 3.82, 0.5), rgb(255, 80, 80), NEON, { Group = "head" })
	return { Parts = list, HeadPivot = Vector3.new(0, 2.2, 0), Muzzle = Vector3.new(0, 2.25, -3.1) }
end

-- bubble shield projector (the dome itself is built by the server). Origin = ground.
BUILDERS.SHIELD = function(accent)
	local list, add, cyl, ball = new()
	local ACC = accent or rgb(100, 220, 230)
	cyl("Puck", 2.2, 0.3, CFrame.new(0, 0.15, 0), DARK2, METAL)
	cyl("PuckRing", 1.9, 0.07, CFrame.new(0, 0.33, 0), ACC, NEON)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3 + 0.5
		add("Pylon", Vector3.new(0.22, 0.85, 0.22), CFrame.new(math.cos(a) * 0.8, 0.7, math.sin(a) * 0.8) * CFrame.Angles(0, -a, rad(-8)), STEEL, METAL)
	end
	ball("Core", Vector3.one * 0.95, CFrame.new(0, 0.95, 0), ACC, NEON, { Transparency = 0.3 })
	ball("CoreHi", Vector3.one * 0.45, CFrame.new(0, 0.95, 0), rgb(240, 255, 255), NEON)
	cyl("Cap", 0.55, 0.12, CFrame.new(0, 1.55, 0), STEEL_HI, METAL)
	return { Parts = list }
end

-- proximity mine. Origin = the surface it sticks to (Y = away from the surface).
BUILDERS.MINE = function()
	local list, add, cyl, ball = new()
	cyl("Body", 1.5, 0.38, CFrame.new(0, 0.19, 0), rgb(48, 52, 62), METAL)
	cyl("Rim", 1.64, 0.1, CFrame.new(0, 0.07, 0), rgb(26, 28, 34), METAL)
	cyl("Ring", 1.05, 0.08, CFrame.new(0, 0.4, 0), rgb(255, 130, 60), NEON)
	cyl("Plate", 0.7, 0.1, CFrame.new(0, 0.45, 0), rgb(34, 36, 44), METAL)
	ball("Eye", Vector3.one * 0.38, CFrame.new(0, 0.5, 0), rgb(90, 20, 20), NEON)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3 + 0.4
		add("Sensor", Vector3.new(0.16, 0.24, 0.16), CFrame.new(math.cos(a) * 0.62, 0.42, math.sin(a) * 0.62), DARK, METAL)
		ball("SensorTip", Vector3.one * 0.13, CFrame.new(math.cos(a) * 0.62, 0.56, math.sin(a) * 0.62), rgb(255, 150, 80), NEON)
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
