-- Skins (ModuleScript in ReplicatedStorage) - used by BOTH games (Lobby + Breakline). Keep the two copies identical.
-- Every skin a player can wear. The equipped skin is saved in the shared profile as "Skin" (ProfileStore DEFAULTS = "OPERATOR",
-- so a brand-new player always has the default skin on).
--   Skins.Order / Skins.ById / Skins.Default / Skins.Get(id) / Skins.Is(id)
--   Skins.Dress(character, skinId, accentColor)  -> server: dresses a real Roblox character (lobby + match)
--   Skins.NewFigure(parent, skinId, opts)       -> client: a posed showcase figure built from parts (lobby menus / ViewportFrames)
--       opts = { weapon = "VX9" (optional, real gun model from GunModels), camPos = Vector3 (so the figure can glance at the camera) }
--       figure:SetRoot(cframe), figure:Update(t, dt), figure:Destroy(), figure.HeadTop (studs above the root)
-- Adding a skin: add an entry to Skins.List (colors + `card` color), then add its extra gear in DRESS[id] and FIGURE[id].
local RS = game:GetService("ReplicatedStorage")

local S = {}
local rgb = Color3.fromRGB

S.List = {
	{
		id = "OPERATOR", name = "OPERATOR", sub = "Standard issue", card = rgb(214, 128, 34),
		desc = "Steel plates, amber visor. What every new recruit gets.",
		colors = { Suit = rgb(40, 42, 48), Under = rgb(26, 27, 31), Armor = rgb(78, 82, 90), Trim = rgb(18, 18, 21), Accent = rgb(255, 140, 30) },
	},
	{
		id = "VANDAL", name = "VANDAL", sub = "Street crew", card = rgb(200, 30, 36),
		desc = "Black hood, white mask with a red slash through it.",
		colors = { Suit = rgb(26, 26, 28), Under = rgb(14, 14, 15), Armor = rgb(232, 230, 224), Trim = rgb(10, 10, 11), Accent = rgb(226, 38, 43) },
	},
	{
		id = "SALVAGER", name = "SALVAGER", sub = "Scrapyard scavenger", card = rgb(58, 120, 112),
		desc = "Patched canvas, round goggles and a pack full of junk.",
		colors = { Suit = rgb(86, 88, 64), Under = rgb(56, 50, 40), Armor = rgb(170, 146, 104), Trim = rgb(40, 34, 28), Accent = rgb(70, 210, 196) },
	},
}
S.Default = "OPERATOR"
S.Order, S.ById = {}, {}
for _, s in S.List do
	table.insert(S.Order, s.id)
	S.ById[s.id] = s
end
function S.Is(id) return type(id) == "string" and S.ById[id] ~= nil end
function S.Get(id) return S.ById[id] or S.ById[S.Default] end

-- =====================================================================================
-- REAL CHARACTERS (server): weld gear parts onto the body parts. Front of a Roblox character = -Z.
-- Parts tagged TeamAccent get recolored to the team color in a match (AvatarService does that).
-- =====================================================================================
local NEON, SP = Enum.Material.Neon, Enum.Material.SmoothPlastic

local function addPart(parent, base, name, size, offset, color, material, isAccent, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.Color = color
	p.Material = material or SP
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CFrame = base.CFrame * offset
	if isAccent then
		p:SetAttribute("TeamAccent", true)
		p.CastShadow = false
	end
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = base, p, offset
	w.Parent = p
	p.Parent = parent
	return p
end

local function visualHeadSize(head)
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		local s = math.min(head.Size.Y, head.Size.Z) * (mesh.Scale.Y / 1.25) * 1.2
		return Vector3.new(s, s, s)
	end
	return head.Size
end

local DRESS = {}

DRESS.OPERATOR = function(gear, head, torso, h, t, L, A)
	addPart(gear, head, "Helmet", Vector3.new(h.X * 1.14, h.Y * 0.5, h.Z * 1.14), CFrame.new(0, h.Y * 0.3, 0.02), L.Armor)
	addPart(gear, head, "HelmetRidge", Vector3.new(h.X * 0.22, h.Y * 0.12, h.Z * 1.18), CFrame.new(0, h.Y * 0.58, 0), L.Trim)
	addPart(gear, head, "VisorFrame", Vector3.new(h.X * 1.1, h.Y * 0.28, 0.12), CFrame.new(0, h.Y * 0.02, -h.Z * 0.5 - 0.04), L.Trim)
	addPart(gear, head, "Visor", Vector3.new(h.X * 0.94, h.Y * 0.13, 0.06), CFrame.new(0, h.Y * 0.02, -h.Z * 0.5 - 0.11), A, NEON, true)
	for _, s in { -1, 1 } do
		addPart(gear, head, "EarCup", Vector3.new(0.16, h.Y * 0.4, h.Z * 0.5), CFrame.new(s * (h.X * 0.5 + 0.06), -h.Y * 0.02, 0.05), L.Trim)
	end
	addPart(gear, head, "Antenna", Vector3.new(0.05, h.Y * 0.7, 0.05), CFrame.new(-(h.X * 0.5 + 0.1), h.Y * 0.45, 0.15), L.Trim)
	addPart(gear, head, "AntennaTip", Vector3.new(0.09, 0.09, 0.09), CFrame.new(-(h.X * 0.5 + 0.1), h.Y * 0.82, 0.15), A, NEON, true)
	addPart(gear, torso, "ChestPlate", Vector3.new(t.X * 0.86, t.Y * 0.62, 0.22), CFrame.new(0, t.Y * 0.12, -t.Z * 0.5 - 0.1), L.Armor)
	addPart(gear, torso, "ChestStripe", Vector3.new(t.X * 0.5, 0.08, 0.05), CFrame.new(0, t.Y * 0.28, -t.Z * 0.5 - 0.23), A, NEON, true)
	for _, s in { -1, 1 } do
		addPart(gear, torso, "Pouch", Vector3.new(t.X * 0.24, t.Y * 0.22, 0.2), CFrame.new(s * t.X * 0.22, -t.Y * 0.22, -t.Z * 0.5 - 0.2), L.Trim)
	end
	addPart(gear, torso, "PowerCell", Vector3.new(t.X * 0.56, t.Y * 0.66, 0.42), CFrame.new(0, t.Y * 0.05, t.Z * 0.5 + 0.2), L.Trim)
	addPart(gear, torso, "CellCore", Vector3.new(t.X * 0.14, t.Y * 0.46, 0.06), CFrame.new(0, t.Y * 0.05, t.Z * 0.5 + 0.43), A, NEON, true)
end

DRESS.VANDAL = function(gear, head, torso, h, t, L, A)
	-- hood (black, open at the front) + white mask with a red slash
	addPart(gear, head, "Hood", Vector3.new(h.X * 1.22, h.Y * 1.12, h.Z * 1.0), CFrame.new(0, h.Y * 0.08, h.Z * 0.16), L.Suit)
	addPart(gear, head, "HoodPeak", Vector3.new(h.X * 1.16, h.Y * 0.18, h.Z * 0.3), CFrame.new(0, h.Y * 0.5, -h.Z * 0.38), L.Suit)
	addPart(gear, head, "Mask", Vector3.new(h.X * 0.92, h.Y * 0.8, 0.1), CFrame.new(0, -h.Y * 0.04, -h.Z * 0.5 - 0.05), L.Armor)
	addPart(gear, head, "EyeSlit", Vector3.new(h.X * 0.74, h.Y * 0.1, 0.04), CFrame.new(0, h.Y * 0.1, -h.Z * 0.5 - 0.11), L.Trim)
	addPart(gear, head, "MaskSlash", Vector3.new(0.09, h.Y * 0.95, 0.04), CFrame.new(h.X * 0.05, -h.Y * 0.04, -h.Z * 0.5 - 0.12) * CFrame.Angles(0, 0, math.rad(-28)), A, NEON, true)
	-- jacket + white plate
	addPart(gear, torso, "Jacket", Vector3.new(t.X * 1.06, t.Y * 1.02, t.Z * 1.12), CFrame.new(0, -t.Y * 0.02, 0), L.Suit)
	addPart(gear, torso, "Collar", Vector3.new(t.X * 0.7, t.Y * 0.16, t.Z * 1.18), CFrame.new(0, t.Y * 0.5, 0), L.Trim)
	addPart(gear, torso, "ChestPlate", Vector3.new(t.X * 0.62, t.Y * 0.44, 0.14), CFrame.new(0, t.Y * 0.12, -t.Z * 0.56 - 0.07), L.Armor)
	addPart(gear, torso, "PlateSlash", Vector3.new(0.08, t.Y * 0.5, 0.04), CFrame.new(0, t.Y * 0.12, -t.Z * 0.56 - 0.16) * CFrame.Angles(0, 0, math.rad(-28)), A, NEON, true)
	addPart(gear, torso, "BackTag", Vector3.new(t.X * 0.5, t.Y * 0.08, 0.04), CFrame.new(0, t.Y * 0.25, t.Z * 0.56 + 0.03), A, NEON, true)
end

DRESS.SALVAGER = function(gear, head, torso, h, t, L, A)
	-- canvas cap, round goggles, scarf, big scrap backpack with a lamp
	addPart(gear, head, "Cap", Vector3.new(h.X * 1.1, h.Y * 0.38, h.Z * 1.1), CFrame.new(0, h.Y * 0.38, 0), L.Under)
	addPart(gear, head, "CapBrim", Vector3.new(h.X * 1.0, h.Y * 0.07, h.Z * 0.4), CFrame.new(0, h.Y * 0.2, -h.Z * 0.62), L.Under)
	addPart(gear, head, "GoggleStrap", Vector3.new(h.X * 1.08, h.Y * 0.12, h.Z * 1.08), CFrame.new(0, h.Y * 0.08, 0), L.Trim)
	for _, s in { -1, 1 } do
		addPart(gear, head, "GoggleRim", Vector3.new(0.14, h.Y * 0.34, h.Y * 0.34), CFrame.new(s * h.X * 0.22, h.Y * 0.08, -h.Z * 0.5 - 0.05) * CFrame.Angles(0, math.rad(90), 0), L.Armor, SP, false, Enum.PartType.Cylinder)
		addPart(gear, head, "GoggleLens", Vector3.new(0.06, h.Y * 0.24, h.Y * 0.24), CFrame.new(s * h.X * 0.22, h.Y * 0.08, -h.Z * 0.5 - 0.12) * CFrame.Angles(0, math.rad(90), 0), A, NEON, true, Enum.PartType.Cylinder)
	end
	addPart(gear, head, "Scarf", Vector3.new(h.X * 1.05, h.Y * 0.4, h.Z * 1.05), CFrame.new(0, -h.Y * 0.38, 0), rgb(140, 70, 44))
	addPart(gear, torso, "Vest", Vector3.new(t.X * 0.9, t.Y * 0.7, 0.18), CFrame.new(0, t.Y * 0.08, -t.Z * 0.5 - 0.08), L.Armor)
	addPart(gear, torso, "Strap", Vector3.new(0.14, t.Y * 1.0, 0.06), CFrame.new(t.X * 0.25, 0, -t.Z * 0.5 - 0.18) * CFrame.Angles(0, 0, math.rad(20)), L.Trim)
	addPart(gear, torso, "Pack", Vector3.new(t.X * 0.9, t.Y * 0.95, 0.75), CFrame.new(0, t.Y * 0.05, t.Z * 0.5 + 0.38), L.Armor)
	addPart(gear, torso, "PackFlap", Vector3.new(t.X * 0.92, t.Y * 0.22, 0.8), CFrame.new(0, t.Y * 0.45, t.Z * 0.5 + 0.38), L.Under)
	addPart(gear, torso, "PackPipe", Vector3.new(t.Y * 1.3, 0.16, 0.16), CFrame.new(-t.X * 0.3, t.Y * 0.4, t.Z * 0.5 + 0.7) * CFrame.Angles(0, 0, math.rad(90)), L.Trim, SP, false, Enum.PartType.Cylinder)
	addPart(gear, torso, "PackLamp", Vector3.new(0.18, 0.18, 0.08), CFrame.new(t.X * 0.25, t.Y * 0.2, t.Z * 0.5 + 0.78), A, NEON, true)
	addPart(gear, torso, "ShoulderLamp", Vector3.new(0.2, 0.16, 0.12), CFrame.new(t.X * 0.42, t.Y * 0.42, -t.Z * 0.5 - 0.12), A, NEON, true)
end

local BODY_PARTS = {
	Head = "Under", Torso = "Suit", UpperTorso = "Suit", LowerTorso = "Under",
	LeftUpperArm = "Suit", RightUpperArm = "Suit", LeftLowerArm = "Suit", RightLowerArm = "Suit",
	LeftHand = "Trim", RightHand = "Trim", ["Left Arm"] = "Suit", ["Right Arm"] = "Suit",
	LeftUpperLeg = "Under", RightUpperLeg = "Under", LeftLowerLeg = "Under", RightLowerLeg = "Under",
	LeftFoot = "Trim", RightFoot = "Trim", ["Left Leg"] = "Under", ["Right Leg"] = "Under",
}

-- dress a real character in a skin. accent = team color in a match (nil = the skin's own accent)
function S.Dress(char, skinId, accent)
	local skin = S.Get(skinId)
	local L = skin.colors
	local head = char:WaitForChild("Head", 10)
	local torso = char:FindFirstChild("UpperTorso") or char:WaitForChild("UpperTorso", 3) or char:FindFirstChild("Torso")
	if not head or not torso or not char.Parent then return end

	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then bc:Destroy() end
	for _, d in char:GetChildren() do
		if d:IsA("BasePart") and BODY_PARTS[d.Name] then d.Color = L[BODY_PARTS[d.Name]] end
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Accessory") then d:Destroy() end
	end
	local face = head:FindFirstChild("face")
	if face then face:Destroy() end

	local old = char:FindFirstChild("Gear")
	if old then old:Destroy() end
	local gear = Instance.new("Model")
	gear.Name = "Gear"
	gear:SetAttribute("Skin", skin.id)
	gear.Parent = char

	local A = accent or L.Accent
	local h, t = visualHeadSize(head), torso.Size
	DRESS[skin.id](gear, head, torso, h, t, L, A)

	local lt = char:FindFirstChild("LowerTorso")
	if lt then
		local l = lt.Size
		addPart(gear, lt, "Belt", Vector3.new(l.X * 1.05, l.Y * 0.35, l.Z * 1.1), CFrame.new(0, l.Y * 0.15, 0), L.Trim)
	end
	for _, side in { "Left", "Right" } do
		local arm = char:FindFirstChild(side .. "UpperArm") or char:FindFirstChild(side .. " Arm")
		if arm then
			local a, upper = arm.Size, arm.Name:find("Upper") ~= nil
			addPart(gear, arm, side .. "Pad", Vector3.new(a.X * 1.18, a.Y * (upper and 0.32 or 0.18), a.Z * 1.18),
				CFrame.new(0, a.Y * (upper and 0.3 or 0.38), 0), skin.id == "VANDAL" and L.Suit or L.Armor)
		end
		local leg = char:FindFirstChild(side .. "LowerLeg") or char:FindFirstChild(side .. " Leg")
		if leg then
			local l = leg.Size
			local y = leg.Name:find("Lower") and l.Y * 0.3 or -l.Y * 0.05
			addPart(gear, leg, side .. "Knee", Vector3.new(l.X * 0.8, math.min(l.Y * 0.3, 0.55), 0.16), CFrame.new(0, y, -l.Z * 0.5 - 0.06), L.Armor)
		end
	end
end

-- =====================================================================================
-- SHOWCASE FIGURE (client, ViewportFrames): blocky posed operator holding a gun. Figure faces +Z, feet at y = 0.
-- =====================================================================================
local FIGURE = {}
-- add(group, size, cframe, color, neon, shape). P(r, y, f): r = to the figure's right, f = forward.

FIGURE.OPERATOR = function(add, P, c)
	add("body", Vector3.new(2.0, 1.3, 0.3), CFrame.new(0, 4.3, 0.72), c.Armor)
	add("body", Vector3.new(0.18, 1.0, 0.06), CFrame.new(P(0.55, 4.3, 0.89)), c.Accent, true)
	add("body", Vector3.new(0.18, 1.0, 0.06), CFrame.new(P(-0.55, 4.3, 0.89)), c.Accent, true)
	add("body", Vector3.new(1.3, 1.5, 0.6), CFrame.new(0, 4.1, -0.9), c.Trim)
	add("body", Vector3.new(0.3, 1.1, 0.06), CFrame.new(0, 4.1, -1.22), c.Accent, true)
	add("head", Vector3.new(1.35, 1.25, 1.3), CFrame.new(0, 0.75, 0), c.Armor)
	add("head", Vector3.new(1.45, 0.5, 1.4), CFrame.new(0, 1.2, -0.02), c.Armor)
	add("head", Vector3.new(0.3, 0.16, 1.44), CFrame.new(0, 1.5, 0), c.Trim)
	add("head", Vector3.new(1.2, 0.42, 0.1), CFrame.new(0, 0.8, 0.66), c.Trim)
	add("head", Vector3.new(1.05, 0.2, 0.08), CFrame.new(0, 0.8, 0.72), c.Accent, true)
	add("head", Vector3.new(0.2, 0.5, 0.6), CFrame.new(0.76, 0.72, 0), c.Trim)
	add("head", Vector3.new(0.2, 0.5, 0.6), CFrame.new(-0.76, 0.72, 0), c.Trim)
	add("head", Vector3.new(0.07, 0.8, 0.07), CFrame.new(P(-0.85, 1.6, -0.15)), c.Trim)
	add("head", Vector3.new(0.14, 0.14, 0.14), CFrame.new(P(-0.85, 2.0, -0.15)), c.Accent, true)
end

FIGURE.VANDAL = function(add, P, c)
	add("body", Vector3.new(2.5, 2.4, 1.5), CFrame.new(0, 3.9, 0), c.Suit) -- jacket
	add("body", Vector3.new(2.36, 0.5, 1.4), CFrame.new(0, 2.6, 0), c.Suit)
	add("body", Vector3.new(1.4, 1.0, 0.2), CFrame.new(0, 4.35, 0.8), c.Armor)
	add("body", Vector3.new(0.14, 1.25, 0.05), CFrame.new(0, 4.35, 0.92) * CFrame.Angles(0, 0, math.rad(-28)), c.Accent, true)
	add("body", Vector3.new(1.6, 0.12, 0.05), CFrame.new(0, 4.7, -0.77), c.Accent, true)
	add("head", Vector3.new(1.35, 1.25, 1.3), CFrame.new(0, 0.75, 0), c.Under)
	add("head", Vector3.new(1.6, 1.5, 1.4), CFrame.new(0, 0.85, -0.12), c.Suit) -- hood
	add("head", Vector3.new(1.5, 0.22, 0.4), CFrame.new(0, 1.5, 0.45), c.Suit)
	add("head", Vector3.new(1.14, 1.0, 0.1), CFrame.new(0, 0.7, 0.66), c.Armor) -- mask
	add("head", Vector3.new(0.9, 0.12, 0.05), CFrame.new(0, 0.95, 0.72), c.Trim)
	add("head", Vector3.new(0.12, 1.15, 0.05), CFrame.new(0.05, 0.7, 0.73) * CFrame.Angles(0, 0, math.rad(-28)), c.Accent, true)
end

FIGURE.SALVAGER = function(add, P, c)
	add("body", Vector3.new(2.1, 1.4, 0.26), CFrame.new(0, 4.2, 0.72), c.Armor)
	add("body", Vector3.new(0.2, 2.4, 0.08), CFrame.new(P(0.5, 4.0, 0.88)) * CFrame.Angles(0, 0, math.rad(22)), c.Trim)
	add("body", Vector3.new(2.0, 2.2, 1.3), CFrame.new(0, 4.0, -1.2), c.Armor) -- pack
	add("body", Vector3.new(2.06, 0.5, 1.36), CFrame.new(0, 5.0, -1.2), c.Under)
	add("body", Vector3.new(0.3, 3.0, 0.3), CFrame.new(P(-0.7, 5.3, -1.6)), c.Trim)
	add("body", Vector3.new(0.3, 0.3, 0.12), CFrame.new(P(0.5, 4.4, -1.9)), c.Accent, true)
	add("body", Vector3.new(0.34, 0.26, 0.2), CFrame.new(P(1.2, 5.25, 0.5)), c.Accent, true)
	add("head", Vector3.new(1.35, 1.25, 1.3), CFrame.new(0, 0.75, 0), c.Under)
	add("head", Vector3.new(1.5, 0.5, 1.5), CFrame.new(0, 1.3, 0), c.Under) -- cap
	add("head", Vector3.new(1.3, 0.1, 0.6), CFrame.new(0, 1.08, 0.9), c.Under)
	add("head", Vector3.new(1.42, 0.2, 1.42), CFrame.new(0, 0.85, 0), c.Trim)
	for _, s in { -1, 1 } do
		add("head", Vector3.new(0.16, 0.48, 0.48), CFrame.new(P(0.3 * s, 0.85, 0.7)) * CFrame.Angles(0, math.rad(90), 0), c.Armor, false, Enum.PartType.Cylinder)
		add("head", Vector3.new(0.06, 0.34, 0.34), CFrame.new(P(0.3 * s, 0.85, 0.78)) * CFrame.Angles(0, math.rad(90), 0), c.Accent, true, Enum.PartType.Cylinder)
	end
	add("head", Vector3.new(1.5, 0.5, 1.45), CFrame.new(0, 0.12, 0), rgb(140, 70, 44)) -- scarf
end

local function getGunModels()
	local m = RS:FindFirstChild("GunModels")
	if not m then return nil end
	local ok, res = pcall(require, m)
	return ok and res or nil
end

function S.NewFigure(parent, skinId, opts)
	opts = opts or {}
	local skin = S.Get(skinId)
	local c = skin.colors
	local model = Instance.new("Model")
	model.Name = "Figure_" .. skin.id
	model.Parent = parent
	local list = {}
	local function P(r, y, f) return Vector3.new(-r, y, f) end
	local function add(group, size, cf, color, neon, shape)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		if shape then p.Shape = shape end
		p.Size, p.Color = size, color
		p.Material = neon and NEON or SP
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		table.insert(list, { part = p, rel = cf, group = group })
		return p
	end
	local function bar(a, b, t, color)
		add("body", Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color)
	end

	-- legs, hips, torso, shoulders (shared by every skin)
	for _, s in { -1, 1 } do
		add("body", Vector3.new(0.95, 2.7, 1.0), CFrame.new(P(0.65 * s, 1.35, s == 1 and 0.4 or -0.25)), c.Under)
		add("body", Vector3.new(0.9, 0.7, 0.2), CFrame.new(P(0.65 * s, 1.6, s == 1 and 0.95 or 0.3)), c.Armor)
		add("body", Vector3.new(1.0, 0.4, 1.5), CFrame.new(P(0.65 * s, 0.2, s == 1 and 0.65 or 0)), c.Trim)
	end
	add("body", Vector3.new(2.2, 0.6, 1.2), CFrame.new(0, 2.85, 0), c.Trim)
	add("body", Vector3.new(2.3, 2.0, 1.3), CFrame.new(0, 4.05, 0), c.Suit)
	add("body", Vector3.new(2.34, 0.25, 1.36), CFrame.new(0, 3.1, 0), c.Trim)
	add("body", Vector3.new(0.9, 0.55, 1.1), CFrame.new(P(1.55, 5.0, 0)), skin.id == "VANDAL" and c.Suit or c.Armor)
	add("body", Vector3.new(0.9, 0.55, 1.1), CFrame.new(P(-1.55, 5.0, 0)), skin.id == "VANDAL" and c.Suit or c.Armor)
	add("body", Vector3.new(0.5, 0.3, 0.5), CFrame.new(0, 5.2, 0), c.Trim)
	FIGURE[skin.id](add, P, c)

	-- the gun, held across the chest pointing forward-left and a little down
	local A, B = P(0.7, 4.5, 0.55), P(-0.5, 3.9, 3.6)
	local rf = CFrame.lookAt(A, B) * CFrame.Angles(0, math.pi, 0) -- local +Z = toward the muzzle
	local rHand = (rf * CFrame.new(0, -0.5, 0.4)).Position
	local lHand = (rf * CFrame.new(0, -0.25, 2.0)).Position
	local GM = opts.weapon and getGunModels()
	local desc
	if GM then
		local ok, d = pcall(GM.Describe, opts.weapon, "Iron")
		desc = ok and d or nil
	end
	if desc and desc.Points and desc.Points.Grip and desc.Points.Fore then
		local s = 1.45
		local rot = CFrame.lookAt(Vector3.zero, (B - A).Unit) -- gun -Z (downrange) along the aim line
		local gunCF = CFrame.new(rHand) * rot * CFrame.new(-desc.Points.Grip.Position * s)
		for _, d in desc.Parts do
			if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
				add("body", d.Size * s, gunCF * (CFrame.new(d.CF.Position * s) * d.CF.Rotation), d.Glow and c.Accent or d.Color, d.Glow or d.Material == NEON, d.Shape)
			end
		end
		lHand = gunCF * (desc.Points.Fore.Position * s)
		if (lHand - rHand).Magnitude < 0.9 then lHand = rHand + (lHand - rHand).Unit * 0.9 + Vector3.new(0, -0.15, 0) end -- pistols: hands together
	else
		local function rp(size, cf, color, neon) add("body", size, rf * cf, color, neon) end
		rp(Vector3.new(0.34, 0.5, 1.7), CFrame.new(0, 0, 0.95), rgb(36, 40, 52))
		rp(Vector3.new(0.28, 0.55, 0.9), CFrame.new(0, -0.02, -0.4), c.Trim)
		rp(Vector3.new(0.3, 0.36, 1.15), CFrame.new(0, -0.02, 2.35), c.Armor)
		rp(Vector3.new(0.14, 0.14, 0.8), CFrame.new(0, 0.02, 3.3), c.Trim)
		rp(Vector3.new(0.24, 0.85, 0.34), CFrame.new(0, -0.62, 1.15) * CFrame.Angles(math.rad(-10), 0, 0), c.Trim)
		rp(Vector3.new(0.38, 0.06, 1.2), CFrame.new(0, 0.08, 1.0), c.Accent, true)
	end
	local SR, SL = P(1.55, 5.0, 0), P(-1.55, 5.0, 0)
	local ER = (SR + rHand) / 2 + P(0.6, -0.5, -0.3)
	local EL = (SL + lHand) / 2 + P(-0.7, -0.6, -0.1)
	bar(SR, ER, 0.75, c.Suit); bar(ER, rHand, 0.7, c.Suit)
	bar(SL, EL, 0.75, c.Suit); bar(EL, lHand, 0.7, c.Suit)
	add("body", Vector3.new(0.6, 0.6, 0.6), CFrame.new(rHand), c.Trim)
	add("body", Vector3.new(0.6, 0.6, 0.6), CFrame.new(lHand), c.Trim)

	local fig = { Model = model, HeadTop = 7.4, root = CFrame.new() }
	local curYaw, curPitch, goYaw, goPitch, nextLook = 0, 0, 0, 0, 0
	local rng = Random.new()
	local phase = rng:NextNumber(0, 6)
	function fig:SetRoot(cf) self.root = cf end
	function fig:Update(t, dt)
		local root = self.root * CFrame.new(0, math.sin(t * 1.7 + phase) * 0.04, 0) * CFrame.Angles(0, math.sin(t * 0.5 + phase) * 0.04, 0)
		if t >= nextLook then
			goYaw = math.rad(rng:NextNumber(-45, 45))
			goPitch = math.rad(rng:NextNumber(-6, 10))
			if opts.camPos and rng:NextInteger(1, 3) == 1 then -- sometimes looks at the camera
				local v = root:PointToObjectSpace(opts.camPos)
				goYaw = math.clamp(math.atan2(v.X, v.Z), math.rad(-60), math.rad(60))
				goPitch = 0
			end
			nextLook = t + rng:NextNumber(2.2, 4.8)
		end
		local k = 1 - math.exp(-4 * (dt or 0))
		curYaw += (goYaw - curYaw) * k
		curPitch += (goPitch - curPitch) * k
		local headCF = root * CFrame.new(0, 5.25, 0) * CFrame.Angles(curPitch, curYaw, 0)
		for _, e in list do
			e.part.CFrame = (e.group == "head" and headCF or root) * e.rel
		end
	end
	function fig:Destroy() model:Destroy() end
	fig:Update(0, 0)
	return fig
end

return S
