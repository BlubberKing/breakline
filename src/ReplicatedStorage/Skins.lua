-- Skins (ModuleScript in ReplicatedStorage) - used by BOTH games (Lobby + Breakline). Keep the two copies identical.
-- v4.8: the three old skins are gone. There are now TWO skins:
--   OPERATOR  = the BASE skin of the game (cover art, loading screen, what every new player starts with): charcoal suit, light steel plates, ballistic helmet,
--               dark visor, the Breakline red slash across the chest and helmet.
--   SOULBOUND = the soul skin: hooded cloak, bone mask with glowing soul-eyes, ribcage plates, tattered cloth and a soul lantern on the belt.
-- Old saves that still say VANDAL / SALVAGER simply fall back to OPERATOR (Skins.Is says no, Skins.Get returns the default).
-- Every skin is a ROUNDED body (cylinders, balls and real gloved hands with fingers) laid over the Roblox rig. The original blocky limbs stay in the
-- rig (hit boxes, animations, IK) but are made invisible; the shells are welded to them, so every animation (MoveAnim, AbilityPose, gun IK) still drives them.
-- The equipped skin is saved in the shared profile as "Skin" (ProfileStore DEFAULTS = "OPERATOR", so a brand-new player always has the default skin on).
--   Skins.Order / Skins.ById / Skins.Default / Skins.Get(id) / Skins.Is(id)
--   Skins.Dress(character, skinId, accentColor)  -> server: dresses a real Roblox character (lobby + match)
--   Skins.NewFigure(parent, skinId, opts)       -> client: a posed showcase figure built from parts (lobby menus / ViewportFrames / cutscenes)
--       opts = { weapon = "VX9" (optional, real gun model from GunModels), camPos = Vector3 (so the figure can glance at the camera),
--                idle = true (random idle moves - aim in, inspect, low ready, scan, turn, shift. OFF unless asked for: only the
--                lobby squad stage turns it on), still = true (head fixed forward, smaller breathing: cutscenes),
--                static = true (no movement at all, just holding the gun: skin picker) }
--       figure:SetRoot(cframe), figure:Update(t, dt), figure:Destroy(), figure.HeadTop (studs above the root)
--   Skins.Proportions / Skins.ApplyProportions(character) -> every player is a bit TALLER and a lot SKINNIER than the stock rig (unchanged in v4.8)
-- Parts tagged TeamAccent are recoloured to the team colour in a match by AvatarService (visor line, shoulder bands, soul fire).
-- Adding a skin: add an entry to Skins.List (colors + `card` color), then its gear in DRESS[id] and FIGURE[id].
local RS = game:GetService("ReplicatedStorage")

local S = {}
local rgb = Color3.fromRGB

local BREAKLINE_RED = rgb(226, 38, 43)

S.List = {
	{
		id = "OPERATOR", name = "OPERATOR", sub = "Standard issue", card = rgb(214, 40, 46),
		desc = "Charcoal suit, steel plates, dark visor and the red slash. What every recruit starts with.",
		colors = {
			Suit = rgb(36, 38, 44), Under = rgb(24, 25, 30), Armor = rgb(112, 118, 128), Trim = rgb(14, 14, 17), Accent = BREAKLINE_RED,
			Plate = rgb(150, 156, 166), Cloth = rgb(48, 50, 56), Glove = rgb(26, 27, 31), Brand = BREAKLINE_RED, White = rgb(232, 232, 228),
		},
	},
	{
		id = "SOULBOUND", name = "SOULBOUND", sub = "Carries the dead", card = rgb(96, 170, 230),
		desc = "A hooded shroud, a bone mask and a lantern that burns with every soul you take.",
		colors = {
			Suit = rgb(28, 33, 44), Under = rgb(18, 21, 29), Armor = rgb(214, 208, 190), Trim = rgb(11, 13, 19), Accent = rgb(110, 200, 255),
			Plate = rgb(232, 226, 208), Cloth = rgb(40, 52, 72), Glove = rgb(20, 24, 33), Brand = rgb(110, 200, 255), White = rgb(236, 232, 218),
		},
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
-- BODY PROPORTIONS (unchanged since v3.2): taller + skinnier than the stock blocky R15 rig, head a touch smaller.
-- Tune these four numbers (1 = stock). They scale the real character (Humanoid scale values) AND the lobby showcase figure.
-- =====================================================================================
S.Proportions = { Height = 1.12, Width = 0.84, Depth = 0.88, Head = 0.95 }

-- S.Prepare(char): applies the proportions and WAITS until the rig has actually resized (server). Safe to call from several scripts:
-- the first caller does the work, the others wait for the "Proportioned" attribute. Anything sized from body parts must call this first.
function S.Prepare(char)
	if char:GetAttribute("Proportioned") then return end
	if char:GetAttribute("Proportioning") then
		local t0 = os.clock()
		while char.Parent and not char:GetAttribute("Proportioned") and os.clock() - t0 < 2.5 do task.wait() end
		return
	end
	char:SetAttribute("Proportioning", true)
	local torso = char:FindFirstChild("UpperTorso") or char:WaitForChild("UpperTorso", 5)
	if torso and S.ApplyProportions(char) then
		local before = torso.Size
		local t0 = os.clock()
		while char.Parent and os.clock() - t0 < 1.2 and (torso.Size - before).Magnitude < 0.01 do task.wait() end
		task.wait(); task.wait()
	end
	char:SetAttribute("Proportioned", true)
end

-- adds / updates the Humanoid scale NumberValues. Returns true when something changed (the rig then needs a moment to resize).
function S.ApplyProportions(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then return false end
	hum.AutomaticScalingEnabled = true
	local P = S.Proportions
	local changed = false
	local function setScale(name, value)
		local v = hum:FindFirstChild(name)
		if not v then
			v = Instance.new("NumberValue")
			v.Name = name
			v.Value = value
			v.Parent = hum
			changed = true
		elseif math.abs(v.Value - value) > 1e-4 then
			v.Value = value
			changed = true
		end
	end
	setScale("BodyHeightScale", P.Height)
	setScale("BodyWidthScale", P.Width)
	setScale("BodyDepthScale", P.Depth)
	setScale("HeadScale", P.Head)
	setScale("BodyProportionScale", 0)
	setScale("BodyTypeScale", 0)
	return changed
end

local function getGunModels()
	local m = RS:FindFirstChild("GunModels")
	if not m then return nil end
	local ok, res = pcall(require, m)
	return ok and res or nil
end

-- =====================================================================================
-- REAL CHARACTERS (server): rounded shells welded onto the R15 body parts. Front of a Roblox character = -Z.
-- Parts tagged TeamAccent get recolored to the team color in a match (AvatarService does that).
-- =====================================================================================
local NEON, SP, METAL = Enum.Material.Neon, Enum.Material.SmoothPlastic, Enum.Material.Metal
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local rad = math.rad
local CFn, V3 = CFrame.new, Vector3.new

local function weldPart(parent, base, name, size, offset, color, material, isAccent, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.Color = color
	p.Material = material or SP
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = size.Magnitude > 0.9 and not isAccent
	p.CFrame = base.CFrame * offset
	if isAccent then p:SetAttribute("TeamAccent", true) end
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = base, p, offset
	w.Parent = p
	p.Parent = parent
	return p
end

-- shape helpers. "off" is a CFrame relative to the centre of the rig part `base`.
local function box(g, base, name, size, off, col, mat, acc) return weldPart(g, base, name, size, off, col, mat, acc) end
-- upright cylinder (axis = the limb's Y). dx / dz are the two diameters (so it can be oval), len is the height
local function ycyl(g, base, name, dx, len, dz, off, col, mat, acc)
	return weldPart(g, base, name, V3(len, dx, dz), off * CFrame.Angles(0, 0, rad(90)), col, mat, acc, CYL)
end
-- cylinder lying along Z (front to back)
local function zcyl(g, base, name, len, d, off, col, mat, acc)
	return weldPart(g, base, name, V3(len, d, d), off * CFrame.Angles(0, rad(90), 0), col, mat, acc, CYL)
end
-- cylinder lying along X (side to side)
local function xcyl(g, base, name, len, d, off, col, mat, acc)
	return weldPart(g, base, name, V3(len, d, d), off, col, mat, acc, CYL)
end
local function ball(g, base, name, d, off, col, mat, acc)
	return weldPart(g, base, name, V3(d, d, d), off, col, mat, acc, BALL)
end
-- a thin cylinder between two points in the space of `base` (cords, spikes, wisps)
local function rod(g, base, name, a, b, d, col, mat, acc)
	local len = (b - a).Magnitude
	if len < 0.001 then return nil end
	return weldPart(g, base, name, V3(len, d, d), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0), col, mat, acc, CYL)
end

local function visualHeadSize(head)
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		local s = math.min(head.Size.Y, head.Size.Z) * (mesh.Scale.Y / 1.25) * 1.2
		return Vector3.new(s, s, s)
	end
	return head.Size
end

local RIG_PARTS = {
	"Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

-- gloved hand with real fingers. side = 1 for the right hand (palm faces -X), -1 for the left hand (palm faces +X).
-- Built in the hand part's own space: Y runs along the forearm (fingers hang toward -Y), thumb points forward (-Z), fingers curl toward the palm.
local function buildHand(g, hand, side, col, padCol)
	local H = hand.Size
	local s = side
	local hz = H.Z
	local palmY = -0.1
	ycyl(g, hand, "Wrist", H.X * 0.92, 0.2, H.Z * 0.92, CFn(0, H.Y * 0.5 + 0.02, 0), col)
	box(g, hand, "Palm", V3(H.X * 0.46, 0.62, hz * 0.82), CFn(s * H.X * 0.1, palmY, 0), col)
	zcyl(g, hand, "Knuckles", hz * 0.84, 0.19, CFn(-s * H.X * 0.06, -0.4, 0), padCol or col)
	for i, zf in { -0.3, -0.1, 0.1, 0.3 } do
		local z = hz * zf
		local d = i == 4 and 0.12 or 0.145
		local p0 = V3(-s * H.X * 0.08, -0.42, z)
		local p1 = p0 + V3(-s * 0.03, -0.22, 0)
		local p2 = p1 + V3(-s * 0.19, -0.12, 0)
		rod(g, hand, "Finger", p0, p1, d, col)
		rod(g, hand, "Finger", p1, p2, d * 0.94, col)
		ball(g, hand, "Fingertip", d * 0.98, CFn(p2), col)
	end
	local t0 = V3(-s * H.X * 0.18, -0.1, -hz * 0.38)
	local t1 = t0 + V3(-s * 0.07, -0.13, -0.2)
	local t2 = t1 + V3(-s * 0.15, -0.07, -0.1)
	rod(g, hand, "Thumb", t0, t1, 0.16, col)
	rod(g, hand, "Thumb", t1, t2, 0.15, col)
	ball(g, hand, "ThumbTip", 0.15, CFn(t2), col)
end

-- the round body shared by both skins. Returns a table of the rig parts (and what the skin functions need).
local function buildBody(g, char, L, skinId)
	local P = {}
	for _, n in RIG_PARTS do P[n] = char:FindFirstChild(n) end
	for _, n in RIG_PARTS do
		local part = P[n]
		if part then part.Transparency = 1; part.CastShadow = false end
	end
	local ut, lt = P.UpperTorso, P.LowerTorso
	if ut then
		local t = ut.Size
		ycyl(g, ut, "Chest", t.X * 0.95, t.Y * 0.98, t.Z * 1.0, CFn(0, 0, 0), L.Suit)
		ycyl(g, ut, "Yoke", t.X * 1.02, t.Y * 0.3, t.Z * 0.96, CFn(0, t.Y * 0.3, 0), L.Suit)
		ycyl(g, ut, "Waist", t.X * 0.84, t.Y * 0.3, t.Z * 0.92, CFn(0, -t.Y * 0.42, 0), L.Under)
		ycyl(g, ut, "NeckBase", t.X * 0.34, t.Y * 0.26, t.Z * 0.46, CFn(0, t.Y * 0.5, 0), L.Under)
	end
	if lt then
		local l = lt.Size
		ycyl(g, lt, "Pelvis", l.X * 0.94, l.Y * 1.9, l.Z * 1.02, CFn(0, -l.Y * 0.2, 0), L.Under)
		ycyl(g, lt, "Belt", l.X * 1.0, 0.17, l.Z * 1.08, CFn(0, l.Y * 0.28, 0), L.Trim)
		box(g, lt, "BeltBuckle", V3(0.22, 0.15, 0.06), CFn(0, l.Y * 0.28, -l.Z * 0.54), L.Plate, METAL)
	end
	for _, side in { "Left", "Right" } do
		local sgn = side == "Right" and 1 or -1
		local ua, la, hd = P[side .. "UpperArm"], P[side .. "LowerArm"], P[side .. "Hand"]
		local ul, ll, ft = P[side .. "UpperLeg"], P[side .. "LowerLeg"], P[side .. "Foot"]
		if ua then
			local a = ua.Size
			ycyl(g, ua, "Sleeve", a.X * 0.98, a.Y * 0.94, a.Z * 0.98, CFn(0, -a.Y * 0.02, 0), L.Suit)
			ball(g, ua, "Shoulder", a.X * 1.06, CFn(0, a.Y * 0.42, 0), L.Suit)
			ball(g, ua, "Elbow", a.X * 0.93, CFn(0, -a.Y * 0.47, 0), L.Suit)
		end
		if la then
			local l = la.Size
			ycyl(g, la, "Forearm", l.X * 0.92, l.Y * 0.56, l.Z * 0.92, CFn(0, l.Y * 0.2, 0), L.Suit)
			ycyl(g, la, "ForearmLow", l.X * 0.8, l.Y * 0.5, l.Z * 0.8, CFn(0, -l.Y * 0.22, 0), L.Suit)
			ycyl(g, la, "Cuff", l.X * 0.9, 0.2, l.Z * 0.9, CFn(0, -l.Y * 0.46, 0), L.Glove)
		end
		if hd then buildHand(g, hd, sgn, L.Glove, L.Trim) end
		if ul then
			local u = ul.Size
			ycyl(g, ul, "Thigh", u.X * 1.0, u.Y * 0.56, u.Z * 1.02, CFn(0, u.Y * 0.2, 0), L.Under)
			ycyl(g, ul, "ThighLow", u.X * 0.88, u.Y * 0.5, u.Z * 0.9, CFn(0, -u.Y * 0.25, 0), L.Under)
			ball(g, ul, "KneeJoint", u.X * 0.9, CFn(0, -u.Y * 0.5, 0), L.Under)
		end
		if ll then
			local l = ll.Size
			ycyl(g, ll, "Calf", l.X * 0.86, l.Y * 0.5, l.Z * 0.9, CFn(0, l.Y * 0.2, 0), L.Under)
			ycyl(g, ll, "Shin", l.X * 0.7, l.Y * 0.55, l.Z * 0.72, CFn(0, -l.Y * 0.22, 0), L.Under)
			ycyl(g, ll, "BootShaft", l.X * 0.9, l.Y * 0.28, l.Z * 0.95, CFn(0, -l.Y * 0.38, 0), L.Trim)
		end
		if ft then
			local f = ft.Size
			box(g, ft, "BootBody", V3(f.X * 0.9, f.Y * 1.3, f.Z * 0.66), CFn(0, f.Y * 0.1, f.Z * 0.12), L.Trim)
			xcyl(g, ft, "BootToe", f.X * 0.9, f.Y * 1.3, CFn(0, f.Y * 0.1, -f.Z * 0.22), L.Trim)
			box(g, ft, "BootSole", V3(f.X * 0.98, 0.08, f.Z * 1.0), CFn(0, -f.Y * 0.52, 0), L.Under, SP)
			box(g, ft, "BootHeel", V3(f.X * 0.92, 0.2, f.Z * 0.22), CFn(0, -f.Y * 0.42, f.Z * 0.38), L.Under, SP)
		end
	end
	return P
end

-- ---------------------------------------------------------------- OPERATOR: the base skin
local DRESS = {}

DRESS.OPERATOR = function(g, P, L, A, h)
	local head, ut, lt = P.Head, P.UpperTorso, P.LowerTorso
	local RED = L.Brand
	if head then
		-- skull + ballistic helmet
		ball(g, head, "Skull", h.X * 0.98, CFn(0, 0, 0), L.Under)
		ball(g, head, "Helmet", h.X * 1.2, CFn(0, h.Y * 0.1, h.Z * 0.05), L.Armor, METAL)
		ycyl(g, head, "HelmetRim", h.X * 1.16, h.Y * 0.12, h.Z * 1.2, CFn(0, h.Y * 0.16, h.Z * 0.04), L.Suit)
		box(g, head, "HelmetRidge", V3(h.X * 0.16, h.Y * 0.1, h.Z * 0.95), CFn(0, h.Y * 0.68, h.Z * 0.04), L.Suit)
		box(g, head, "HelmetMount", V3(h.X * 0.3, h.Y * 0.2, 0.1), CFn(0, h.Y * 0.4, -h.Z * 0.58), L.Trim, METAL)
		for _, s in { -1, 1 } do
			box(g, head, "HelmetRail", V3(0.07, h.Y * 0.2, h.Z * 0.5), CFn(s * h.X * 0.6, h.Y * 0.18, -h.Z * 0.05), L.Trim, METAL)
			-- headset cups + wrap-around visor wings
			xcyl(g, head, "EarCup", 0.2, h.Y * 0.5, CFn(s * (h.X * 0.55 + 0.04), -h.Y * 0.04, h.Z * 0.06), L.Trim)
			box(g, head, "VisorWing", V3(h.X * 0.34, h.Y * 0.3, 0.06), CFn(s * h.X * 0.4, h.Y * 0.04, -h.Z * 0.4) * CFrame.Angles(0, rad(s * -38), 0), rgb(22, 28, 40))
			zcyl(g, head, "MaskFilter", 0.18, h.Y * 0.26, CFn(s * h.X * 0.34, -h.Y * 0.3, -h.Z * 0.52), L.Trim, METAL)
		end
		-- the red slash on the helmet's right side
		box(g, head, "HelmetSlash", V3(0.07, h.Y * 0.62, 0.02), CFn(h.X * 0.575, h.Y * 0.3, -h.Z * 0.05) * CFrame.Angles(0, rad(90), 0) * CFrame.Angles(0, 0, rad(-30)), RED)
		-- visor, team line over it, lower-face mask, chin strap
		box(g, head, "Visor", V3(h.X * 0.86, h.Y * 0.3, 0.07), CFn(0, h.Y * 0.04, -h.Z * 0.5 - 0.02), rgb(22, 28, 40), SP)
		box(g, head, "VisorFrame", V3(h.X * 0.94, h.Y * 0.06, 0.09), CFn(0, h.Y * 0.2, -h.Z * 0.5 - 0.02), L.Trim, METAL)
		box(g, head, "VisorLine", V3(h.X * 0.8, 0.035, 0.04), CFn(0, h.Y * 0.2, -h.Z * 0.5 - 0.075), A, NEON, true)
		box(g, head, "Mask", V3(h.X * 0.76, h.Y * 0.3, 0.16), CFn(0, -h.Y * 0.26, -h.Z * 0.46), L.Trim, SP)
		box(g, head, "MaskGrille", V3(h.X * 0.34, h.Y * 0.14, 0.05), CFn(0, -h.Y * 0.26, -h.Z * 0.56), rgb(46, 48, 54), METAL)
		ycyl(g, head, "ChinStrap", h.X * 0.9, 0.06, h.Z * 0.9, CFn(0, -h.Y * 0.46, 0.04), L.Trim)
	end
	if ut then
		local t = ut.Size
		-- plate carrier: soft carrier, steel front plate, the Breakline slash, pouches, straps, pack
		ycyl(g, ut, "Carrier", t.X * 1.0, t.Y * 0.72, t.Z * 1.1, CFn(0, t.Y * 0.04, 0.02), L.Cloth)
		box(g, ut, "FrontPlate", V3(t.X * 0.74, t.Y * 0.62, 0.17), CFn(0, t.Y * 0.1, -t.Z * 0.56), L.Plate, METAL)
		box(g, ut, "PlateEdge", V3(t.X * 0.8, t.Y * 0.68, 0.1), CFn(0, t.Y * 0.1, -t.Z * 0.5), L.Trim, METAL)
		box(g, ut, "PlateBevel", V3(t.X * 0.54, 0.09, 0.19), CFn(0, t.Y * 0.38, -t.Z * 0.57), L.Armor, METAL)
		box(g, ut, "ChestSlash", V3(0.09, t.Y * 0.74, 0.03), CFn(t.X * 0.02, t.Y * 0.1, -t.Z * 0.56 - 0.1) * CFrame.Angles(0, 0, rad(-28)), RED)
		box(g, ut, "ChestSlashEdge", V3(0.03, t.Y * 0.74, 0.02), CFn(t.X * 0.02 + 0.07, t.Y * 0.1, -t.Z * 0.56 - 0.11) * CFrame.Angles(0, 0, rad(-28)), L.White)
		for i = -1, 1 do
			box(g, ut, "MagPouch", V3(t.X * 0.22, t.Y * 0.2, 0.17), CFn(i * t.X * 0.27, -t.Y * 0.33, -t.Z * 0.54), L.Cloth)
			box(g, ut, "PouchFlap", V3(t.X * 0.22, t.Y * 0.07, 0.19), CFn(i * t.X * 0.27, -t.Y * 0.26, -t.Z * 0.55), L.Trim)
		end
		for _, s in { -1, 1 } do
			box(g, ut, "Strap", V3(t.X * 0.16, t.Y * 0.2, t.Z * 0.28), CFn(s * t.X * 0.34, t.Y * 0.45, -t.Z * 0.22), L.Cloth)
			box(g, ut, "StrapBack", V3(t.X * 0.16, t.Y * 0.2, t.Z * 0.28), CFn(s * t.X * 0.34, t.Y * 0.45, t.Z * 0.22), L.Cloth)
		end
		ycyl(g, ut, "Collar", t.X * 0.5, 0.22, t.Z * 0.6, CFn(0, t.Y * 0.56, 0), L.Armor, METAL)
		box(g, ut, "BackPlate", V3(t.X * 0.72, t.Y * 0.6, 0.15), CFn(0, t.Y * 0.1, t.Z * 0.55), L.Plate, METAL)
		box(g, ut, "Pack", V3(t.X * 0.6, t.Y * 0.56, 0.32), CFn(0, -t.Y * 0.02, t.Z * 0.5 + 0.22), L.Cloth)
		box(g, ut, "PackFlap", V3(t.X * 0.62, t.Y * 0.14, 0.34), CFn(0, t.Y * 0.26, t.Z * 0.5 + 0.22), L.Trim)
		box(g, ut, "PackLine", V3(0.05, t.Y * 0.4, 0.02), CFn(t.X * 0.18, -t.Y * 0.04, t.Z * 0.5 + 0.395), RED)
	end
	if lt then
		local l = lt.Size
		box(g, lt, "RadioPouch", V3(0.28, 0.34, 0.2), CFn(-l.X * 0.46, -l.Y * 0.2, 0.04), L.Cloth)
		box(g, lt, "BeltPouch", V3(0.26, 0.3, 0.18), CFn(l.X * 0.28, -l.Y * 0.1, l.Z * 0.5 + 0.04), L.Cloth)
	end
	for _, side in { "Left", "Right" } do
		local sgn = side == "Right" and 1 or -1
		local ua, la, ul, ll = P[side .. "UpperArm"], P[side .. "LowerArm"], P[side .. "UpperLeg"], P[side .. "LowerLeg"]
		if ua then
			local a = ua.Size
			ball(g, ua, "Pauldron", a.X * 1.36, CFn(sgn * a.X * 0.04, a.Y * 0.36, 0), L.Armor, METAL)
			ycyl(g, ua, "PauldronRim", a.X * 1.3, 0.1, a.Z * 1.3, CFn(sgn * a.X * 0.04, a.Y * 0.2, 0), L.Trim, METAL)
			-- team-colour armband (matte cloth, not glowing)
			ycyl(g, ua, "Armband", a.X * 1.06, 0.26, a.Z * 1.06, CFn(0, -a.Y * 0.02, 0), A, SP, true)
		end
		if la then
			local l = la.Size
			ball(g, la, "ElbowPad", l.X * 1.0, CFn(0, l.Y * 0.46, 0.0), L.Armor, METAL)
			box(g, la, "ForearmGuard", V3(l.X * 0.5, l.Y * 0.4, 0.16), CFn(0, l.Y * 0.02, -l.Z * 0.46), L.Trim, METAL)
		end
		if ul then
			local u = ul.Size
			box(g, ul, "ThighPlate", V3(u.X * 0.56, u.Y * 0.4, 0.14), CFn(sgn * u.X * 0.18, u.Y * 0.2, -u.Z * 0.52), L.Cloth)
			if side == "Right" then
				box(g, ul, "Holster", V3(0.2, u.Y * 0.4, u.Z * 0.5), CFn(u.X * 0.52, u.Y * 0.14, 0.02), L.Trim)
				box(g, ul, "HolsterGrip", V3(0.14, 0.2, 0.18), CFn(u.X * 0.52, u.Y * 0.4, 0.06), L.Plate, METAL)
			else
				box(g, ul, "DumpPouch", V3(0.22, u.Y * 0.34, u.Z * 0.5), CFn(-u.X * 0.54, u.Y * 0.12, 0.02), L.Cloth)
			end
		end
		if ll then
			local l = ll.Size
			ycyl(g, ll, "KneePad", l.X * 0.98, 0.44, l.Z * 0.42, CFn(0, l.Y * 0.4, -l.Z * 0.34), L.Armor, METAL)
			box(g, ll, "KneePadCap", V3(l.X * 0.62, 0.3, 0.12), CFn(0, l.Y * 0.4, -l.Z * 0.5), L.Plate, METAL)
			ycyl(g, ll, "BootCuff", l.X * 0.98, 0.1, l.Z * 1.02, CFn(0, -l.Y * 0.3, 0), L.Armor, METAL)
		end
	end
end

-- ---------------------------------------------------------------- SOULBOUND: the soul skin
DRESS.SOULBOUND = function(g, P, L, A, h)
	local head, ut, lt = P.Head, P.UpperTorso, P.LowerTorso
	local BONE = L.Armor
	if head then
		ball(g, head, "Skull", h.X * 0.98, CFn(0, 0, 0), L.Trim)
		-- hood: round cowl, pointed peak, drape down the back
		ball(g, head, "Hood", h.X * 1.34, CFn(0, h.Y * 0.1, h.Z * 0.1), L.Suit)
		ycyl(g, head, "HoodDrape", h.X * 1.12, h.Y * 0.62, h.Z * 1.16, CFn(0, -h.Y * 0.18, h.Z * 0.2), L.Suit)
		box(g, head, "HoodPeak", V3(h.X * 0.9, 0.16, h.Z * 0.8), CFn(0, h.Y * 0.5, -h.Z * 0.34) * CFrame.Angles(rad(-24), 0, 0), L.Suit)
		ycyl(g, head, "HoodHem", h.X * 1.12, 0.12, h.Z * 1.0, CFn(0, h.Y * 0.28, -h.Z * 0.14), L.Cloth)
		for _, s in { -1, 1 } do
			-- two bone antlers curving out of the hood
			local base = V3(s * h.X * 0.3, h.Y * 0.62, h.Z * 0.04)
			local mid = base + V3(s * 0.22, 0.32, 0.0)
			local tip = mid + V3(s * 0.24, 0.3, -0.1)
			rod(g, head, "Antler", base, mid, 0.09, BONE, SP)
			rod(g, head, "Antler", mid, tip, 0.06, BONE, SP)
			rod(g, head, "AntlerTine", mid, mid + V3(s * 0.02, 0.3, 0.14), 0.045, BONE, SP)
		end
		-- the bone mask: brow, cheek bones, nose slit, teeth, glowing soul eyes
		box(g, head, "Mask", V3(h.X * 0.8, h.Y * 0.8, 0.13), CFn(0, -h.Y * 0.02, -h.Z * 0.5 - 0.01), BONE, SP)
		box(g, head, "MaskBrow", V3(h.X * 0.9, h.Y * 0.1, 0.17), CFn(0, h.Y * 0.28, -h.Z * 0.5 - 0.03), L.White, SP)
		for _, s in { -1, 1 } do
			box(g, head, "EyeSocket", V3(h.X * 0.26, h.Y * 0.2, 0.06), CFn(s * h.X * 0.21, h.Y * 0.1, -h.Z * 0.5 - 0.075), L.Trim, SP)
			box(g, head, "SoulEye", V3(h.X * 0.17, h.Y * 0.1, 0.05), CFn(s * h.X * 0.21, h.Y * 0.1, -h.Z * 0.5 - 0.1), A, NEON, true)
			box(g, head, "CheekBone", V3(h.X * 0.18, h.Y * 0.1, 0.12), CFn(s * h.X * 0.3, -h.Y * 0.1, -h.Z * 0.5 - 0.04), L.White, SP)
			box(g, head, "MaskCrack", V3(0.025, h.Y * 0.2, 0.04), CFn(s * h.X * 0.08, h.Y * 0.28, -h.Z * 0.5 - 0.09) * CFrame.Angles(0, 0, rad(s * 18)), L.Trim)
		end
		box(g, head, "NoseSlit", V3(h.X * 0.07, h.Y * 0.2, 0.05), CFn(0, -h.Y * 0.08, -h.Z * 0.5 - 0.075), L.Trim, SP)
		box(g, head, "Jaw", V3(h.X * 0.62, h.Y * 0.18, 0.12), CFn(0, -h.Y * 0.36, -h.Z * 0.46), BONE, SP)
		for i = -2, 2 do
			box(g, head, "Tooth", V3(h.X * 0.075, h.Y * 0.14, 0.04), CFn(i * h.X * 0.11, -h.Y * 0.36, -h.Z * 0.5 - 0.075), i % 2 == 0 and L.White or BONE, SP)
		end
	end
	if ut then
		local t = ut.Size
		-- shroud over the torso: mantle (capelet), ribcage plates, spine, tattered back cloth
		ycyl(g, ut, "Shroud", t.X * 1.06, t.Y * 0.86, t.Z * 1.16, CFn(0, t.Y * 0.02, 0.0), L.Suit)
		ycyl(g, ut, "Mantle", t.X * 1.36, t.Y * 0.3, t.Z * 1.42, CFn(0, t.Y * 0.36, 0.02), L.Cloth)
		ycyl(g, ut, "MantleHem", t.X * 1.4, 0.08, t.Z * 1.46, CFn(0, t.Y * 0.22, 0.02), L.Trim)
		box(g, ut, "Sternum", V3(0.1, t.Y * 0.56, 0.07), CFn(0, t.Y * 0.06, -t.Z * 0.52 - 0.04), BONE, SP)
		for i = 0, 3 do
			local y = t.Y * (0.22 - i * 0.14)
			local w = t.X * (0.5 - i * 0.04)
			xcyl(g, ut, "Rib", w, 0.09, CFn(0, y, -t.Z * 0.52 - 0.04), BONE, SP)
			for _, s in { -1, 1 } do
				box(g, ut, "RibSide", V3(t.X * 0.2, 0.09, 0.09), CFn(s * (w / 2 + 0.06), y - 0.03, -t.Z * 0.42) * CFrame.Angles(0, rad(s * 52), rad(s * -8)), BONE, SP)
			end
		end
		for i = 0, 4 do ball(g, ut, "Vertebra", 0.15 - i * 0.008, CFn(0, t.Y * (0.34 - i * 0.14), t.Z * 0.54), BONE, SP) end
		-- rope sash + collar of bone beads
		ycyl(g, ut, "Sash", t.X * 1.0, 0.16, t.Z * 1.1, CFn(0, -t.Y * 0.36, 0), L.Cloth)
		for i = 0, 6 do
			local a = i * math.pi / 6 + math.pi / 12
			ball(g, ut, "Bead", 0.11, CFn(math.cos(a) * t.X * 0.3 - t.X * 0.0, t.Y * 0.54, -math.sin(a) * t.Z * 0.34), BONE, SP)
		end
		-- tattered cloth hanging down the back (different lengths)
		for i, spec in { { -0.34, 1.7, 0.1 }, { -0.12, 2.2, -0.05 }, { 0.12, 1.9, 0.06 }, { 0.34, 1.5, -0.08 } } do
			local x, len, tilt = spec[1], spec[2], spec[3]
			box(g, ut, "Tatter", V3(t.X * 0.22, len, 0.05), CFn(x * t.X, -t.Y * 0.1 - len * 0.4 + t.Y * 0.4, t.Z * 0.56 + 0.06 + i * 0.012) * CFrame.Angles(rad(4), 0, rad(tilt * 40)), i % 2 == 0 and L.Cloth or L.Suit)
		end
	end
	if lt then
		local l = lt.Size
		-- tattered front cloth + the soul lantern on the right hip
		for i, x in { -0.3, 0.0, 0.3 } do
			box(g, lt, "Loin", V3(l.X * 0.28, 1.1 - math.abs(x) * 0.8, 0.05), CFn(x * l.X, -0.55 + 0.1, -l.Z * 0.56), i == 2 and L.Cloth or L.Suit)
		end
		ycyl(g, lt, "RopeBelt", l.X * 1.02, 0.14, l.Z * 1.1, CFn(0, l.Y * 0.28, 0), L.Cloth)
		box(g, lt, "SkullBuckle", V3(0.26, 0.2, 0.06), CFn(0, l.Y * 0.28, -l.Z * 0.56), BONE, SP)
		box(g, lt, "SkullEyeL", V3(0.07, 0.07, 0.03), CFn(-0.06, l.Y * 0.3, -l.Z * 0.56 - 0.03), L.Trim)
		box(g, lt, "SkullEyeR", V3(0.07, 0.07, 0.03), CFn(0.06, l.Y * 0.3, -l.Z * 0.56 - 0.03), L.Trim)
		local hip = CFn(l.X * 0.56, -0.7, -0.08)
		rod(g, lt, "LanternCord", V3(l.X * 0.5, l.Y * 0.3, -0.08), V3(l.X * 0.56, -0.3, -0.08), 0.04, BONE, SP)
		ycyl(g, lt, "LanternTop", 0.34, 0.07, 0.34, hip * CFn(0, 0.3, 0), L.Trim, METAL)
		ycyl(g, lt, "LanternBase", 0.34, 0.07, 0.34, hip * CFn(0, -0.28, 0), L.Trim, METAL)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			box(g, lt, "LanternBar", V3(0.04, 0.56, 0.04), hip * CFn(math.cos(a) * 0.15, 0, math.sin(a) * 0.15), L.Trim, METAL)
		end
		ball(g, lt, "SoulFlame", 0.24, hip * CFn(0, -0.02, 0), A, NEON, true)
		ball(g, lt, "SoulFlameCore", 0.13, hip * CFn(0, 0.0, 0), L.White, NEON)
		ball(g, lt, "SoulWisp", 0.07, hip * CFn(0.2, 0.42, 0.05), A, NEON, true)
		ball(g, lt, "SoulWisp", 0.05, hip * CFn(-0.14, 0.58, -0.06), A, NEON, true)
	end
	for _, side in { "Left", "Right" } do
		local sgn = side == "Right" and 1 or -1
		local ua, la, ul, ll, hd = P[side .. "UpperArm"], P[side .. "LowerArm"], P[side .. "UpperLeg"], P[side .. "LowerLeg"], P[side .. "Hand"]
		if ua then
			local a = ua.Size
			if side == "Left" then
				ball(g, ua, "BonePauldron", a.X * 1.4, CFn(-a.X * 0.04, a.Y * 0.34, 0), BONE, SP)
				rod(g, ua, "ShoulderSpike", V3(-a.X * 0.3, a.Y * 0.5, 0), V3(-a.X * 0.55, a.Y * 0.95, 0.02), 0.1, BONE, SP)
				rod(g, ua, "ShoulderSpike", V3(-a.X * 0.1, a.Y * 0.58, 0.12), V3(-a.X * 0.2, a.Y * 1.0, 0.2), 0.07, BONE, SP)
			else
				ball(g, ua, "ClothPauldron", a.X * 1.4, CFn(a.X * 0.04, a.Y * 0.34, 0), L.Cloth)
			end
			-- team-colour armband (matte cloth)
			ycyl(g, ua, "Armband", a.X * 1.05, 0.24, a.Z * 1.05, CFn(0, -a.Y * 0.04, 0), A, SP, true)
		end
		if la then
			local l = la.Size
			for i = 0, 2 do ycyl(g, la, "Wrap", l.X * 0.94, 0.09, l.Z * 0.94, CFn(0, l.Y * (0.22 - i * 0.18), 0), i % 2 == 0 and BONE or L.White, SP) end
		end
		if hd then
			local H = hd.Size
			box(g, hd, "KnuckleBone", V3(H.X * 0.2, 0.1, H.Z * 0.7), CFn(sgn * H.X * 0.34, -0.38, 0), BONE, SP)
		end
		if ul then
			local u = ul.Size
			ycyl(g, ul, "Raggedy", u.X * 1.1, u.Y * 0.34, u.Z * 1.12, CFn(0, -u.Y * 0.12, 0), L.Suit)
			for i = 0, 2 do box(g, ul, "TrouserTatter", V3(u.X * 0.22, 0.4 + i * 0.1, 0.04), CFn((i - 1) * u.X * 0.3, -u.Y * 0.4, -u.Z * 0.52) * CFrame.Angles(0, 0, rad((i - 1) * 6)), L.Suit) end
		end
		if ll then
			local l = ll.Size
			ycyl(g, ll, "AnkleWrap", l.X * 0.9, 0.22, l.Z * 0.94, CFn(0, -l.Y * 0.28, 0), BONE, SP)
			box(g, ll, "BootBuckle", V3(0.18, 0.1, 0.05), CFn(0, -l.Y * 0.4, -l.Z * 0.5), L.White, METAL)
		end
	end
end

local BODY_PARTS = {
	Head = "Under", Torso = "Suit", UpperTorso = "Suit", LowerTorso = "Under",
	LeftUpperArm = "Suit", RightUpperArm = "Suit", LeftLowerArm = "Suit", RightLowerArm = "Suit",
	LeftHand = "Glove", RightHand = "Glove", ["Left Arm"] = "Suit", ["Right Arm"] = "Suit",
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

	-- taller + skinnier body first, then build the gear on the resized parts (gear is sized from the body parts)
	S.Prepare(char)
	if not char.Parent then return end

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

	-- R6 / unknown rigs only get the colours (the game uses R15)
	if not char:FindFirstChild("UpperTorso") then return end

	local A = accent or L.Accent
	local P = buildBody(gear, char, L, skin.id)
	local h = visualHeadSize(head)
	DRESS[skin.id](gear, P, L, A, h)
end

-- =====================================================================================
-- SHOWCASE FIGURE (client, ViewportFrames): a rounded posed operator holding a gun. Figure faces +Z, feet at y = 0.
-- v4.8: cylinders + balls instead of blocks, real fingered gloves (the same GunModels.HandParts the first-person view uses).
-- =====================================================================================
local FIGURE = {}
-- Each skin gets: add(group, size, cframe, color, neon, shape, raw) for plain parts and the shape helpers cyl / ball / rod, in the OLD chunky units.
-- "head" parts are in head space (origin = the neck), "body" parts in body space. P(r, y, f): r = to the figure's right, f = forward.

FIGURE.OPERATOR = function(F, P, c)
	local add, cyl, ball, rod = F.add, F.cyl, F.ball, F.rod
	local RED = c.Brand
	-- ----- head (head space: centre of the head is (0, 0.75, 0), about 1.3 wide)
	ball("head", 1.28, Vector3.new(0, 0.75, 0), c.Under)
	ball("head", 1.46, Vector3.new(0, 0.86, 0.07), c.Armor)
	cyl("head", 1.4, 0.16, 1.4, Vector3.new(0, 0.98, 0.07), c.Suit)
	add("head", Vector3.new(0.22, 0.12, 1.2), CFrame.new(0, 1.55, 0.05), c.Suit)
	add("head", Vector3.new(0.5, 0.26, 0.12), CFrame.new(0, 1.2, 0.72), c.Trim)
	for _, s in { -1, 1 } do
		add("head", Vector3.new(0.24, 0.62, 0.62), CFrame.new(s * 0.8, 0.72, 0.06), c.Trim) -- ear cups
		add("head", Vector3.new(0.4, 0.4, 0.07), CFrame.new(s * 0.5, 0.82, 0.58) * CFrame.Angles(0, math.rad(s * 38), 0), rgb(22, 28, 40))
		add("head", Vector3.new(0.12, 0.36, 0.34), CFrame.new(s * 0.36, 0.42, 0.78), c.Trim, false, Enum.PartType.Cylinder)
	end
	add("head", Vector3.new(0.02, 0.9, 0.08), CFrame.new(0.66, 1.1, 0.0) * CFrame.Angles(0, 0, math.rad(-30)), RED)
	add("head", Vector3.new(1.1, 0.4, 0.08), CFrame.new(0, 0.88, 0.72), rgb(22, 28, 40))
	add("head", Vector3.new(1.18, 0.08, 0.1), CFrame.new(0, 1.08, 0.72), c.Trim)
	add("head", Vector3.new(1.0, 0.045, 0.05), CFrame.new(0, 1.08, 0.78), c.Accent, true)
	add("head", Vector3.new(0.95, 0.4, 0.2), CFrame.new(0, 0.46, 0.64), c.Trim)
	add("head", Vector3.new(0.4, 0.18, 0.06), CFrame.new(0, 0.46, 0.76), rgb(46, 48, 54))
	-- ----- torso (body space)
	cyl("body", 2.5, 1.9, 1.5, Vector3.new(0, 4.2, 0), c.Cloth)
	add("body", Vector3.new(1.75, 1.5, 0.25), CFrame.new(0, 4.3, 0.8), c.Plate)
	add("body", Vector3.new(1.9, 1.65, 0.14), CFrame.new(0, 4.3, 0.7), c.Trim)
	add("body", Vector3.new(0.18, 1.7, 0.05), CFrame.new(0.08, 4.3, 0.96) * CFrame.Angles(0, 0, math.rad(-28)), RED)
	for i = -1, 1 do
		add("body", Vector3.new(0.56, 0.5, 0.26), CFrame.new(i * 0.66, 3.55, 0.78), c.Cloth)
		add("body", Vector3.new(0.56, 0.16, 0.28), CFrame.new(i * 0.66, 3.78, 0.79), c.Trim)
	end
	cyl("body", 1.0, 0.42, 1.2, Vector3.new(0, 5.12, 0), c.Armor)
	add("body", Vector3.new(1.7, 1.4, 0.24), CFrame.new(0, 4.3, -0.8), c.Plate)
	add("body", Vector3.new(1.4, 1.4, 0.7), CFrame.new(0, 4.1, -1.2), c.Cloth)
	add("body", Vector3.new(1.45, 0.34, 0.74), CFrame.new(0, 4.7, -1.2), c.Trim)
	add("body", Vector3.new(0.12, 1.0, 0.04), CFrame.new(P(-0.5, 4.1, -1.58)), RED)
	cyl("body", 2.4, 0.36, 1.35, Vector3.new(0, 3.0, 0), c.Trim)
	add("body", Vector3.new(0.5, 0.34, 0.1), CFrame.new(0, 3.0, 0.7), c.Plate)
	for _, s in { -1, 1 } do
		ball("body", 1.55, P(1.58 * s, 5.0, 0), c.Armor) -- pauldrons
		cyl("body", 1.4, 0.2, 1.4, P(1.58 * s, 4.82, 0), c.Trim)
	end
	-- legs: knee pads, thigh pouches, holster (legs swing as one piece, so these ride along)
	for _, s in { -1, 1 } do
		local lg = s == 1 and "legA" or "legB"
		add(lg, Vector3.new(0.7, 0.9, 0.2), CFrame.new(P(0.65 * s, 1.62, (s == 1 and 0.95 or 0.3) + 0.0)), c.Armor)
		add(lg, Vector3.new(0.78, 0.5, 0.26), CFrame.new(P(0.65 * s, 1.62, (s == 1 and 1.02 or 0.37))), c.Plate)
		add(lg, Vector3.new(0.4, 1.0, 0.8), CFrame.new(P(1.28 * s, 2.2, s == 1 and 0.4 or -0.25)), s == 1 and c.Trim or c.Cloth)
	end
end

FIGURE.SOULBOUND = function(F, P, c)
	local add, cyl, ball, rod = F.add, F.cyl, F.ball, F.rod
	local BONE = c.Armor
	-- ----- head
	ball("head", 1.28, Vector3.new(0, 0.75, 0), c.Trim)
	ball("head", 1.8, Vector3.new(0, 0.84, 0.12), c.Suit) -- hood
	cyl("head", 1.55, 0.9, 1.6, Vector3.new(0, 0.5, -0.3), c.Suit)
	add("head", Vector3.new(1.4, 0.2, 1.1), CFrame.new(0, 1.45, 0.45) * CFrame.Angles(math.rad(-24), 0, 0), c.Suit)
	cyl("head", 1.55, 0.14, 1.5, Vector3.new(0, 1.12, 0.3), c.Cloth)
	for _, s in { -1, 1 } do
		local base = Vector3.new(s * 0.45, 1.5, 0.0)
		local mid = base + Vector3.new(s * 0.34, 0.5, 0)
		rod("head", base, mid, 0.14, BONE)
		rod("head", mid, mid + Vector3.new(s * 0.34, 0.45, -0.1), 0.09, BONE)
		rod("head", mid, mid + Vector3.new(s * 0.04, 0.5, 0.2), 0.07, BONE)
		add("head", Vector3.new(0.36, 0.3, 0.08), CFrame.new(s * 0.3, 0.84, 0.74), c.Trim)
		add("head", Vector3.new(0.26, 0.14, 0.06), CFrame.new(s * 0.3, 0.84, 0.79), c.Accent, true)
		add("head", Vector3.new(0.28, 0.14, 0.16), CFrame.new(s * 0.44, 0.58, 0.72), c.White)
	end
	add("head", Vector3.new(1.1, 1.0, 0.16), CFrame.new(0, 0.75, 0.68), BONE)
	add("head", Vector3.new(1.2, 0.15, 0.2), CFrame.new(0, 1.2, 0.7), c.White)
	add("head", Vector3.new(0.1, 0.3, 0.07), CFrame.new(0, 0.66, 0.78), c.Trim)
	add("head", Vector3.new(0.84, 0.2, 0.16), CFrame.new(0, 0.3, 0.64), BONE)
	for i = -2, 2 do add("head", Vector3.new(0.1, 0.18, 0.05), CFrame.new(i * 0.15, 0.3, 0.76), i % 2 == 0 and c.White or BONE) end
	-- ----- torso
	cyl("body", 2.45, 2.0, 1.65, Vector3.new(0, 4.1, 0), c.Suit)
	cyl("body", 3.0, 0.62, 1.9, Vector3.new(0, 4.85, 0), c.Cloth)
	cyl("body", 3.1, 0.12, 1.95, Vector3.new(0, 4.5, 0), c.Trim)
	add("body", Vector3.new(0.14, 1.2, 0.1), CFrame.new(0, 4.3, 0.84), BONE)
	for i = 0, 3 do
		local y = 4.65 - i * 0.3
		local w = 1.5 - i * 0.12
		add("body", Vector3.new(w, 0.12, 0.12), CFrame.new(0, y, 0.84), BONE, false, Enum.PartType.Cylinder)
		for _, s in { -1, 1 } do
			add("body", Vector3.new(0.5, 0.12, 0.12), CFrame.new(s * (w / 2 + 0.12), y - 0.04, 0.62) * CFrame.Angles(0, math.rad(s * 52), 0), BONE)
		end
	end
	for i = 0, 4 do ball("body", 0.3 - i * 0.02, Vector3.new(0, 4.8 - i * 0.3, -0.84), BONE) end
	cyl("body", 2.3, 0.34, 1.3, Vector3.new(0, 3.3, 0), c.Cloth)
	cyl("body", 2.4, 0.3, 1.35, Vector3.new(0, 3.0, 0), c.Cloth)
	add("body", Vector3.new(0.55, 0.42, 0.1), CFrame.new(0, 3.0, 0.7), BONE)
	for i, spec in { { -0.72, 3.2 }, { -0.24, 4.2 }, { 0.24, 3.6 }, { 0.72, 2.8 } } do
		add("body", Vector3.new(0.6, spec[2], 0.1), CFrame.new(spec[1], 3.7 - spec[2] * 0.4 + 1.4, -0.86 - i * 0.02) * CFrame.Angles(math.rad(4), 0, math.rad(i * 3 - 5)), i % 2 == 0 and c.Cloth or c.Suit)
	end
	for i, x in { -0.62, 0.0, 0.62 } do
		add("body", Vector3.new(0.58, 2.2 - math.abs(x) * 1.2, 0.1), CFrame.new(x, 1.9, 0.68), i == 2 and c.Cloth or c.Suit)
	end
	-- lantern on the right hip
	local hip = P(1.3, 2.35, 0.05)
	rod("body", P(0.9, 3.0, 0.05), P(1.2, 2.8, 0.05), 0.08, BONE)
	cyl("body", 0.62, 0.12, 0.62, hip + Vector3.new(0, 0.55, 0), c.Trim)
	cyl("body", 0.62, 0.12, 0.62, hip + Vector3.new(0, -0.5, 0), c.Trim)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		add("body", Vector3.new(0.07, 1.0, 0.07), CFrame.new(hip + Vector3.new(math.cos(a) * 0.28, 0, math.sin(a) * 0.28)), c.Trim)
	end
	ball("body", 0.46, hip, c.Accent, true)
	ball("body", 0.24, hip, c.White, true)
	for _, s in { -1, 1 } do
		if s == 1 then
			ball("body", 1.6, P(1.58, 5.0, 0), BONE) -- bone pauldron (the figure's left shoulder is x > 0)
			rod("body", P(1.3, 5.3, 0), P(1.8, 6.1, 0.05), 0.18, BONE)
			rod("body", P(1.0, 5.5, 0.2), P(1.2, 6.2, 0.3), 0.12, BONE)
		else
			ball("body", 1.6, P(-1.58, 5.0, 0), c.Cloth)
		end
	end
	for _, s in { -1, 1 } do
		local lg = s == 1 and "legA" or "legB"
		cyl(lg, 1.15, 0.9, 1.15, P(0.65 * s, 2.2, s == 1 and 0.4 or -0.25), c.Suit)
		add(lg, Vector3.new(1.0, 0.36, 1.1), CFrame.new(P(0.65 * s, 0.75, s == 1 and 0.4 or -0.25)), BONE, false, Enum.PartType.Cylinder)
		add(lg, Vector3.new(0.32, 0.2, 0.1), CFrame.new(P(0.65 * s, 0.5, (s == 1 and 0.95 or 0.3))), c.White)
	end
end

-- gun poses of the showcase figure (figure space: +X = the figure's LEFT, +Y up, +Z forward; rot = radians pitch / yaw / roll
-- about the chest pivot, pos = studs). Tuned offline so the gun stays out of the torso in every pose.
S.GunPose = {
	base = Vector3.new(-0.15, 0, 0.6),                                                -- resting carry: held a bit out in front of the chest
	aim = { rot = Vector3.new(-0.17, -0.35, 0), pos = Vector3.new(0.3, 0.8, 0.6) },     -- up by the face, pushed out to the shoulder
	inspect = { rot = Vector3.new(-0.35, 0.35, 0.9), pos = Vector3.new(0, 0.7, 0.3) }, -- lifted in front, canted so the side faces the eyes
	low = { rot = Vector3.new(0.5, 0.2, 0.1), pos = Vector3.new(-0.2, -0.25, 0.2) },   -- muzzle down, away from the legs
}

function S.NewFigure(parent, skinId, opts)
	opts = opts or {}
	local skin = S.Get(skinId)
	local c = skin.colors
	local PR = S.Proportions
	local sx, sy, sz, hs = PR.Width, PR.Height, PR.Depth, PR.Head
	local model = Instance.new("Model")
	model.Name = "Figure_" .. skin.id
	model.Parent = parent
	local list = {}
	local function P(r, y, f) return Vector3.new(-r, y, f) end
	local function Q(v) return Vector3.new(v.X * sx, v.Y * sy, v.Z * sz) end -- body-space point -> taller / skinnier
	local function newPart(shape, color, neon)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		if shape then p.Shape = shape end
		p.Color = color
		p.Material = neon and NEON or SP
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	-- add(group, size, cframe, color, neon, shape, raw). Everything is authored in the old chunky units and squeezed here
	-- (body parts by width/height/depth, head parts uniformly). raw = true skips that (gun, hands, arms).
	local function add(group, size, cf, color, neon, shape, raw)
		local p = newPart(shape, color, neon)
		local rel = cf
		if raw then
			p.Size = size
		elseif group == "head" then
			p.Size = size * hs
			rel = CFrame.new(cf.Position * hs) * cf.Rotation
		else
			p.Size = Vector3.new(size.X * sx, size.Y * sy, size.Z * sz)
			rel = CFrame.new(Q(cf.Position)) * cf.Rotation
		end
		table.insert(list, { part = p, rel = rel, group = group })
		return p
	end
	-- upright cylinder (oval allowed): diameters dx / dz, height len, centre pos. Balls stay round (average of the squeeze).
	local function cyl(group, dx, len, dz, pos, color, neon)
		local p = newPart(CYL, color, neon)
		local rel
		if group == "head" then
			p.Size = Vector3.new(len * hs, dx * hs, dz * hs)
			rel = CFrame.new(pos * hs) * CFrame.Angles(0, 0, math.rad(90))
		else
			p.Size = Vector3.new(len * sy, dx * sx, dz * sz)
			rel = CFrame.new(Q(pos)) * CFrame.Angles(0, 0, math.rad(90))
		end
		table.insert(list, { part = p, rel = rel, group = group })
		return p
	end
	local function ball(group, d, pos, color, neon)
		local p = newPart(BALL, color, neon)
		local rel
		if group == "head" then
			p.Size = Vector3.one * d * hs
			rel = CFrame.new(pos * hs)
		else
			p.Size = Vector3.one * d * (sx + sz) / 2
			rel = CFrame.new(Q(pos))
		end
		table.insert(list, { part = p, rel = rel, group = group })
		return p
	end
	-- a thin cylinder between two points (units as above)
	local function rod(group, a, b, d, color, neon)
		local pa, pb = a, b
		if group == "head" then pa, pb = a * hs, b * hs else pa, pb = Q(a), Q(b) end
		local len = (pb - pa).Magnitude
		if len < 0.001 then return end
		local p = newPart(CYL, color, neon)
		p.Size = Vector3.new(len, d * (group == "head" and hs or (sx + sz) / 2), d * (group == "head" and hs or (sx + sz) / 2))
		table.insert(list, { part = p, rel = CFrame.lookAt((pa + pb) / 2, pb) * CFrame.Angles(0, math.rad(90), 0), group = group })
	end
	local F = { add = add, cyl = cyl, ball = ball, rod = rod }

	-- arms: round limbs + joints, rebuilt every frame from the shoulder to wherever the gun hand is
	local function limbPart(thick, color)
		local p = newPart(CYL, color)
		p.Size = Vector3.new(1, thick, thick)
		return p
	end

	-- legs, hips, torso, shoulders (shared by every skin)
	local hips = {} -- leg group -> hip pivot (legs swing from here when running / sitting)
	for _, s in { -1, 1 } do
		local lg = s == 1 and "legA" or "legB"
		local fz = s == 1 and 0.4 or -0.25 -- one leg a bit forward, the other back (stance)
		hips[lg] = CFrame.new(Q(P(0.65 * s, 2.7, 0)))
		cyl(lg, 1.0, 1.5, 1.05, P(0.65 * s, 2.0, fz), c.Under)
		cyl(lg, 0.88, 1.3, 0.92, P(0.65 * s, 0.95, fz), c.Under)
		ball(lg, 0.92, P(0.65 * s, 1.45, fz), c.Under)
		cyl(lg, 0.95, 0.5, 0.98, P(0.65 * s, 0.62, fz), c.Trim)
		add(lg, Vector3.new(1.0, 0.5, 1.2), CFrame.new(P(0.65 * s, 0.25, fz + 0.15)), c.Trim)
		add(lg, Vector3.new(1.0, 0.5, 0.2), CFrame.new(P(0.65 * s, 0.3, fz + 0.75)), c.Trim, false, CYL)
		add(lg, Vector3.new(1.04, 0.1, 1.7), CFrame.new(P(0.65 * s, 0.05, fz + 0.2)), c.Under)
	end
	cyl("body", 2.2, 0.9, 1.2, Vector3.new(0, 2.95, 0), c.Under)
	cyl("body", 2.1, 0.8, 1.1, Vector3.new(0, 3.35, 0), c.Under)
	cyl("body", 2.34, 2.0, 1.34, Vector3.new(0, 4.1, 0), c.Suit)
	cyl("body", 2.4, 0.6, 1.3, Vector3.new(0, 4.8, 0), c.Suit)
	cyl("body", 0.7, 0.5, 0.8, Vector3.new(0, 5.2, 0), c.Under)
	for _, s in { -1, 1 } do ball("body", 1.0, P(1.55 * s, 5.0, 0), c.Suit) end
	FIGURE[skin.id](F, P, c)

	-- the gun, held across the chest pointing forward-left and a little down
	local GUN_S = 1.25
	local A, Bp = Q(P(0.7, 4.5, 0.55)), Q(P(-0.5, 3.9, 3.9))
	local rf = CFrame.lookAt(A, Bp) * CFrame.Angles(0, math.pi, 0) -- local +Z = toward the muzzle
	local rHand = (rf * CFrame.new(0, -0.5, 0.4)).Position
	local lHand = (rf * CFrame.new(0, -0.25, 2.0)).Position
	local GM = opts.weapon and getGunModels()
	local desc
	if GM then
		local ok, d = pcall(GM.Describe, opts.weapon, "Iron")
		desc = ok and d or nil
	end
	if desc and desc.Points and desc.Points.Grip and desc.Points.Fore then
		local s = GUN_S
		local rot = CFrame.lookAt(Vector3.zero, (Bp - A).Unit) -- gun -Z (downrange) along the aim line
		local gunCF = CFrame.new(rHand) * rot * CFrame.new(-desc.Points.Grip.Position * s)
		for _, d in desc.Parts do
			if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
				add("gun", d.Size * s, gunCF * (CFrame.new(d.CF.Position * s) * d.CF.Rotation), d.Color, d.Material == NEON, d.Shape, true)
			end
		end
		local palm = desc.Points.Palm or desc.Points.Fore
		lHand = gunCF * (palm.Position * s)
		if (lHand - rHand).Magnitude < 0.9 then lHand = rHand + (lHand - rHand).Unit * 0.9 + Vector3.new(0, -0.15, 0) end
		-- real gloved hands (the same fingers as the first-person view), they ride with the gun
		if GM.HandParts then
			local hands = GM.HandParts(desc, c.Glove, c.Trim)
			for _, h in hands.right do
				add("gun", h.Size * s, gunCF * (CFrame.new(h.CF.Position * s) * h.CF.Rotation), h.Color, false, h.Shape, true)
			end
			local palmCF = gunCF * CFrame.new(palm.Position * s)
			for _, h in hands.left do
				add("gun", h.Size * s, palmCF * (CFrame.new(h.CF.Position * s) * h.CF.Rotation), h.Color, false, h.Shape, true)
			end
		end
	else
		local function rp(size, cf, color, neon, shape) add("gun", size, rf * cf, color, neon, shape, true) end
		rp(Vector3.new(0.34, 0.5, 1.7), CFrame.new(0, 0, 0.95), rgb(36, 40, 52))
		rp(Vector3.new(0.28, 0.55, 0.9), CFrame.new(0, -0.02, -0.4), c.Trim)
		rp(Vector3.new(0.3, 0.36, 1.15), CFrame.new(0, -0.02, 2.35), c.Armor)
		rp(Vector3.new(0.14, 0.14, 0.8), CFrame.new(0, 0.02, 3.3), c.Trim)
		rp(Vector3.new(0.24, 0.85, 0.34), CFrame.new(0, -0.62, 1.15) * CFrame.Angles(math.rad(-10), 0, 0), c.Trim)
		-- simple mitts
		rp(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -0.5, 0.4), c.Glove, false, BALL)
		rp(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -0.25, 2.0), c.Glove, false, BALL)
		rp(Vector3.new(0.44, 0.2, 0.34), CFrame.new(0, -0.7, 0.2), c.Glove)
		rp(Vector3.new(0.44, 0.2, 0.34), CFrame.new(0, -0.45, 1.8), c.Glove)
	end
	local SR, SL = Q(P(1.55, 5.0, 0)), Q(P(-1.55, 5.0, 0))
	local offR, offL = Q(P(0.6, -0.5, -0.3)), Q(P(-0.7, -0.6, -0.1))
	local ER = (SR + rHand) / 2 + offR
	local EL = (SL + lHand) / 2 + offL
	-- arms are rebuilt every frame from the shoulder to wherever the gun hand is, so the gun can move (aim, inspect, lower)
	local arms = {
		{ sr = SR, hand = rHand, off = offR, up = limbPart(0.64, c.Suit), lo = limbPart(0.58, c.Suit), eb = newPart(BALL, c.Suit), wr = newPart(CYL, c.Glove) },
		{ sr = SL, hand = lHand, off = offL, up = limbPart(0.64, c.Suit), lo = limbPart(0.58, c.Suit), eb = newPart(BALL, c.Suit), wr = newPart(CYL, c.Glove) },
	}
	for _, a in arms do
		a.eb.Size = Vector3.one * 0.64
		a.wr.Size = Vector3.new(0.3, 0.6, 0.6)
	end

	local NECK = 5.25 * sy
	local fig = { Model = model, HeadTop = NECK + 1.9 * hs, root = CFrame.new(),
		still = opts.still == true or opts.static == true, -- true: no idle events, head fixed forward (cutscenes)
		static = opts.static == true, -- true: no breathing / sway at all, a plain pose holding the gun (skin picker)
		idle = opts.idle == true,   -- true: random idle moves (lobby squad stage only)
		run = 0,       -- 0..1 leg swing while running
		runPhase = 0,  -- radians, advance it while running
		sit = 0 }      -- 0..1 legs forward (sitting on a throne)
	local rng = Random.new()
	local phase = rng:NextNumber(0, 6)
	local curYaw, curPitch, goYaw, goPitch, nextLook = 0, 0, 0, 0, 0

	-- ===== idle director: every few seconds the figure does something (aims in, checks the gun, lowers it, scans around, turns, shifts weight)
	local pose = { aim = 0, inspect = 0, low = 0, shift = 0, turn = 0 }
	local goal = { aim = 0, inspect = 0, low = 0, shift = 0, turn = 0 }
	local evt, evtStart, evtEnd = nil, 0, 0
	-- rarer: First move after IDLE_FIRST s, then a quiet gap of IDLE_GAP s between moves.
	local IDLE_FIRST, IDLE_GAP = { 5, 9 }, { 9, 16 }
	local nextEvt = rng:NextNumber(IDLE_FIRST[1], IDLE_FIRST[2])
	local EVENTS = {
		{ name = "aim", w = 3, dur = { 2.4, 3.6 } },
		{ name = "inspect", w = 2, dur = { 2.8, 3.6 } },
		{ name = "low", w = 2, dur = { 3.0, 4.5 } },
		{ name = "scan", w = 3, dur = { 3.0, 4.2 } },
		{ name = "turn", w = 2, dur = { 3.0, 4.0 } },
		{ name = "shift", w = 2, dur = { 2.4, 3.4 } },
	}
	local function pickEvent(last)
		local total = 0
		for _, e in EVENTS do if e.name ~= last then total += e.w end end
		local r = rng:NextNumber(0, total)
		for _, e in EVENTS do
			if e.name ~= last then
				r -= e.w
				if r <= 0 then return e end
			end
		end
		return EVENTS[1]
	end
	local evtSign, lastEvt = 1, nil
	local PIV = Q(Vector3.new(0, 4.6, 0.4)) -- the gun swings about the chest

	function fig:SetRoot(cf) self.root = cf end
	-- a round limb between two points: cylinder along its length
	local function setLimb(part, a, b, base)
		part.Size = Vector3.new(math.max((b - a).Magnitude, 0.05), part.Size.Y, part.Size.Z)
		part.CFrame = base * CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	end
	function fig:Update(t, dt)
		dt = dt or 0
		local still = self.still
		-- ---- director (only figures created with opts.idle = true)
		if self.idle and not still then
			if evt and t >= evtEnd then
				for k in goal do goal[k] = 0 end
				lastEvt, evt = evt.name, nil
				nextEvt = t + rng:NextNumber(IDLE_GAP[1], IDLE_GAP[2])
			elseif not evt and t >= nextEvt then
				evt = pickEvent(lastEvt)
				evtStart = t
				evtEnd = t + rng:NextNumber(evt.dur[1], evt.dur[2])
				evtSign = rng:NextInteger(0, 1) == 0 and -1 or 1
				if evt.name == "aim" then goal.aim = 1
				elseif evt.name == "inspect" then goal.inspect = 1
				elseif evt.name == "low" then goal.low = 1
				elseif evt.name == "turn" then goal.turn = evtSign
				elseif evt.name == "shift" then goal.shift = evtSign end
			end
		end
		if evt and not (self.idle and not still) then -- idle switched off mid-move: settle back to neutral
			for k in goal do goal[k] = 0 end
			lastEvt, evt = evt.name, nil
		end
		local pk = 1 - math.exp(-3.2 * dt)
		for k, v in pose do pose[k] = v + (goal[k] - v) * pk end

		-- ---- body: slow breathing (deeper now and then), sway, weight shift, turning
		local br = math.sin(t * 1.7 + phase)
		local deep = 0.5 + 0.5 * math.sin(t * 0.37 + phase * 1.7)
		local still0 = self.static and 0 or (still and 0.5 or 1)
		local root = self.root
			* CFrame.new(0, (br * (0.034 + 0.019 * deep) + pose.aim * math.sin(t * 6) * 0.004) * still0, 0)
			* CFrame.Angles(0, math.sin(t * 0.5 + phase) * 0.05 * still0 + pose.turn * 0.55 + pose.shift * 0.12,
				math.sin(t * 0.9 + phase) * 0.012 * (self.static and 0 or 1) + pose.shift * 0.045)
			* CFrame.Angles(pose.aim * 0.04 + pose.inspect * 0.05, 0, 0)

		-- ---- head
		if still then
			goYaw, goPitch = 0, 0
		elseif evt and evt.name == "aim" then
			goYaw, goPitch = -pose.turn * 0.5, 0.05
		elseif evt and evt.name == "inspect" then
			goYaw, goPitch = 0.12 * evtSign, 0.28
		elseif evt and evt.name == "scan" then
			goYaw = math.sin((t - evtStart) * 1.25) * math.rad(70)
			goPitch = math.rad(2) + math.sin((t - evtStart) * 0.8) * 0.05
		elseif evt and evt.name == "turn" then
			goYaw, goPitch = -evtSign * 0.5, 0.02 -- the head leads, the body follows
		elseif t >= nextLook then
			goYaw = math.rad(rng:NextNumber(-45, 45))
			goPitch = math.rad(rng:NextNumber(-6, 10))
			if opts.camPos and rng:NextInteger(1, 3) == 1 then -- sometimes looks at the camera
				local v = root:PointToObjectSpace(opts.camPos)
				goYaw = math.clamp(math.atan2(v.X, v.Z), math.rad(-60), math.rad(60))
				goPitch = 0
			end
			nextLook = t + rng:NextNumber(2.2, 4.8)
		end
		local k = 1 - math.exp(-4 * dt)
		curYaw += (goYaw - curYaw) * k
		curPitch += (goPitch - curPitch) * k
		local headCF = root * CFrame.new(0, NECK, 0) * CFrame.Angles(curPitch, curYaw, 0)

		-- ---- gun pose: aim in (level, up by the face), inspect (lifted + canted), low ready (muzzle down)
		local aim, ins, low = pose.aim, pose.inspect, pose.low
		local GP = S.GunPose
		local r = GP.aim.rot * aim + GP.inspect.rot * ins + GP.low.rot * low
		local rot = CFrame.Angles(r.X, r.Y, r.Z)
		local trn = GP.base + GP.aim.pos * aim + GP.inspect.pos * ins + GP.low.pos * low
		local gT = CFrame.new(trn) * CFrame.new(PIV) * rot * CFrame.new(-PIV)

		-- ---- legs
		local sitA, runA, rp = self.sit, self.run, self.runPhase

		for _, e in list do
			local g = e.group
			if g == "head" then
				e.part.CFrame = headCF * e.rel
			elseif g == "gun" then
				e.part.CFrame = root * gT * e.rel
			elseif g == "legA" or g == "legB" then
				local ang = -sitA * 1.45 + runA * math.sin(rp + (g == "legA" and 0 or math.pi)) * 0.85
				local hp = hips[g]
				e.part.CFrame = root * (hp * CFrame.Angles(ang, 0, 0) * hp:Inverse()) * e.rel
			elseif g == "body" then
				e.part.CFrame = root * e.rel
			end
		end
		for _, a in arms do
			local hand = gT:PointToWorldSpace(a.hand)
			local el = (a.sr + hand) / 2 + a.off
			setLimb(a.up, a.sr, el, root)
			setLimb(a.lo, el, hand, root)
			a.eb.CFrame = root * CFrame.new(el)
			a.wr.CFrame = root * CFrame.lookAt(hand + (el - hand).Unit * 0.3, hand) * CFrame.Angles(0, math.rad(90), 0)
		end
	end
	function fig:Destroy() model:Destroy() end
	fig._pose, fig._list = pose, list -- debug / offline pose checks
	fig:Update(0, 0)
	return fig
end

return S
