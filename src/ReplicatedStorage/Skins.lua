-- Skins v6 (ModuleScript in ReplicatedStorage) - used by BOTH games (Lobby + Breakline). Keep the two copies identical.
-- v6 ANATOMY-KIT REWRITE of the player models (owner: "it looks thrown together, the arms do not even connect to the body").
--   WHY v5 LOOKED ASSEMBLED: every body part was its own blob, the elbow / knee balls were narrower than the limb they joined (pinched joints),
--   and the shoulder was built on the wrong point (the real R15 shoulder pivot is on the arm's CENTRE LINE, not its inner edge), so the arms leaned
--   away from the torso and detached when they raised.
--   v6 FIX: ONE shared anatomy kit (K.*) builds every skin: continuous lofted TUBES (B.tube) for torso, arms and legs with a V-taper; a ball at every
--   real rig pivot that is at least as wide as the limb; a shoulder yoke that makes the arms grow out of the torso; chunky gloves; shoes that sit on
--   an ankle ball. A skin is then only an OUTFIT: a palette, ONE silhouette idea, ONE hero prop, a handful of big shapes (see GDD 5.4 "Skin Style Bible").
--   * NO team-coloured / glowing parts on skins (owner). Teammates + party members are shown with an OUTLINE (TeamOutline LocalScript).
--   * ONE outfit code path for the real character AND the menu figure (virtual R15 rig scaled by FIG_SCALE, dressed by the same DRESS code).
-- The equipped skin is saved in the shared profile as "Skin" (ProfileStore DEFAULTS = "OPERATOR").
--   Skins.Order / Skins.ById / Skins.Default / Skins.Get(id) / Skins.Is(id)
--   Skins.Dress(character, skinId)               -> server: dresses a real Roblox character (lobby + match). (3rd argument = old team accent, ignored)
--   Skins.NewFigure(parent, skinId, opts)        -> client: a posed showcase figure (lobby menus / ViewportFrames / cutscenes)
--       opts = { weapon = "VX9", camPos = Vector3, idle = true, still = true, static = true } (unchanged)
--       figure:SetRoot(cframe), figure:Update(t, dt), figure:Destroy(), figure.HeadTop, figure.run / runPhase / sit
--   Skins.Proportions / Skins.ApplyProportions(character) / Skins.Prepare(character) (unchanged)
-- Adding a skin: entry in Skins.List (colors) + DRESS[id](B, Z, C, opt) built from the kit K (see "THE ANATOMY KIT" + "OUTFITS" below).
local RS = game:GetService("ReplicatedStorage")

local S = {}
local rgb = Color3.fromRGB

local BREAKLINE_RED = rgb(226, 38, 48)

S.List = {
	{
		id = "OPERATOR", name = "OPERATOR", sub = "Standard issue", card = rgb(214, 40, 46),
		desc = "Fitted field jacket, sling, drop-leg holster and high-tops. What every recruit starts with.",
		colors = {
			-- v5 keys
			Skin = rgb(196, 146, 112), SkinShade = rgb(168, 118, 88), Hair = rgb(36, 28, 24), Lip = rgb(150, 96, 80), Eye = rgb(52, 38, 30),
			Top = rgb(34, 36, 42), TopDark = rgb(22, 23, 28), Shirt = rgb(150, 152, 156), Pants = rgb(78, 81, 88), PantsDark = rgb(56, 58, 64),
			Shoe = rgb(28, 28, 32), Sole = rgb(232, 230, 222), Strap = rgb(20, 20, 24), Metal = rgb(176, 180, 186), Pad = rgb(44, 46, 52),
			-- old keys (menus / GunModels hands still read some of these)
			Suit = rgb(34, 36, 42), Under = rgb(78, 81, 88), Armor = rgb(112, 118, 128), Trim = rgb(20, 20, 24), Accent = BREAKLINE_RED,
			Plate = rgb(150, 156, 166), Cloth = rgb(48, 50, 56), Glove = rgb(24, 24, 28), Brand = BREAKLINE_RED, White = rgb(232, 232, 228),
		},
	},
	{
		id = "SOULBOUND", name = "SOULBOUND", sub = "Carries the dead", card = rgb(96, 170, 230),
		desc = "A long hooded coat, a bone mask and a lantern that burns with every soul you take.",
		colors = {
			Skin = rgb(150, 140, 136), SkinShade = rgb(120, 110, 108), Hair = rgb(20, 22, 30), Lip = rgb(90, 80, 80), Eye = rgb(10, 12, 18),
			Top = rgb(30, 36, 52), TopDark = rgb(19, 23, 34), Shirt = rgb(64, 96, 140), Pants = rgb(26, 29, 38), PantsDark = rgb(17, 19, 26),
			Shoe = rgb(22, 22, 28), Sole = rgb(40, 40, 46), Strap = rgb(118, 96, 70), Metal = rgb(150, 156, 170), Pad = rgb(36, 40, 54),
			Bone = rgb(228, 222, 204), BoneShade = rgb(186, 178, 156), Wrap = rgb(204, 196, 174), Soul = rgb(120, 205, 255),
			Suit = rgb(30, 36, 52), Under = rgb(26, 29, 38), Armor = rgb(228, 222, 204), Trim = rgb(14, 16, 22), Accent = rgb(120, 205, 255),
			Plate = rgb(232, 226, 208), Cloth = rgb(40, 52, 72), Glove = rgb(20, 22, 30), Brand = rgb(120, 205, 255), White = rgb(236, 232, 218),
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
-- BODY PROPORTIONS (unchanged): taller + skinnier than the stock blocky R15 rig, head a touch smaller.
-- =====================================================================================
S.Proportions = { Height = 1.12, Width = 0.84, Depth = 0.88, Head = 0.95 }

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
-- BUILDER. Every shell is described relative to the CENTRE of an R15 body part ("base"). Front of a Roblox character = -Z, right = +X.
--   B.ell(base, size, cf, color, mat)              stretched sphere (ellipsoid) filling `size`
--   B.box(base, size, cf, color, mat)              plain block
--   B.rod(base, a, b, d, color, mat)               thin cylinder between two points
--   B.ball(base, p, r, color, mat)                 sphere (joint caps, knuckles, studs)
--   B.tube(base, stations, color, mat)             ONE continuous lofted tube. stations = { {p=Vector3, rx=, rz=}, ... }: radius in X / Z at each
--                                                  station, linearly blended, drawn as overlapping ellipsoids (no seams, no steps). THE tool for limbs,
--                                                  torso, sleeves, coat panels, straps, hair strands, anything long.
--   B.ring(base, y, wx, wz, h, color, mat, cf)     flat band round a limb (cuffs, wraps)
-- The emitter decides what happens with it: weld to the real rig (Dress) or record for the figure (NewFigure).
-- =====================================================================================
local SP, METAL, NEON, FABRIC = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Neon, Enum.Material.Fabric
local CFn, V3 = CFrame.new, Vector3.new
local rad = math.rad

local function frameAlong(a, b)
	local up = b - a
	local len = up.Magnitude
	if len < 1e-4 then return CFn((a + b) / 2), 0 end
	up = up / len
	local right = Vector3.xAxis - up * up.X
	if right.Magnitude < 0.2 then right = Vector3.zAxis - up * up.Z end
	right = right.Unit
	return CFrame.fromMatrix((a + b) / 2, right, up), len
end

local TUBE_LEN = 2.6 -- bead length in steps (bigger = smoother outline, fewer parts)

local function newBuilder(emit)
	local B = {}
	function B.ell(base, size, cf, col, mat) emit(base, "ell", size, cf, col, mat) end
	function B.box(base, size, cf, col, mat) emit(base, "box", size, cf, col, mat) end
	function B.ball(base, p, r, col, mat) emit(base, "ell", V3(2 * r, 2 * r, 2 * r), CFn(p), col, mat) end
	function B.rod(base, a, b, d, col, mat)
		local cf, len = frameAlong(a, b)
		if len < 1e-3 then return end
		emit(base, "cyl", V3(len, d, d), cf * CFrame.Angles(0, 0, rad(90)), col, mat)
	end
	function B.ring(base, y, wx, wz, h, col, mat, cf)
		emit(base, "ell", V3(wx, h, wz), (cf or CFrame.identity) * CFn(0, y, 0), col, mat)
	end
	function B.tube(base, st, col, mat)
		for i = 1, #st - 1 do
			local a, b = st[i], st[i + 1]
			local d = b.p - a.p
			local len = d.Magnitude
			if len > 1e-4 then
				local rmax = math.max(a.rx, a.rz, b.rx, b.rz)
				local n = math.max(1, math.ceil(len / (1.0 * rmax)))
				local rot = frameAlong(a.p, b.p).Rotation
				local step = len / n
				for k = 0, n - 1 do
					local t = (k + 0.5) / n
					emit(base, "ell", V3(2 * (a.rx + (b.rx - a.rx) * t), step * TUBE_LEN, 2 * (a.rz + (b.rz - a.rz) * t)), CFn(a.p + d * t) * rot, col, mat)
				end
			end
		end
	end
	return B
end

-- joint positions inside each R15 part (fractions of the part size, from the stock R15 attachments)
local J = {}
function J.ut(t) return { neck = V3(0, t.Y * 0.5, 0), sh = t.Y * 0.352, waist = V3(0, -t.Y * 0.5, 0) } end
-- (v6) the REAL R15 shoulder pivot is on the arm's centre line (checked against the stock rig attachments), not on its inner edge
function J.ua(a, s) return { sh = V3(0, a.Y * 0.335, 0), el = V3(0, -a.Y * 0.286, 0) } end
function J.la(l) return { el = V3(0, l.Y * 0.246, 0), wr = V3(0, -l.Y * 0.476, 0) } end
function J.hd(h) return { wr = V3(0, h.Y * 0.417, 0) } end
function J.ul(u) return { hip = V3(0, u.Y * 0.345, 0), kn = V3(0, -u.Y * 0.329, 0) } end
function J.ll(l) return { kn = V3(0, l.Y * 0.334, 0), an = V3(0, -l.Y * 0.459, 0) } end
function J.ft(f) return { an = V3(0, f.Y * 0.333, 0) } end
function J.lt(l) return { waist = V3(0, l.Y * 0.5, 0), hipY = -l.Y * 0.5 } end

-- front surface of the head (union of ellipsoids) at (x, y): returns z (negative = front)
local function headFront(E, x, y)
	local best = 0
	for _, e in E do
		local c, r = e[1], e[2]
		local k = ((x - c.X) / (r.X / 2)) ^ 2 + ((y - c.Y) / (r.Y / 2)) ^ 2
		if k < 1 then
			local z = c.Z - (r.Z / 2) * math.sqrt(1 - k)
			if z < best then best = z end
		end
	end
	return best
end

-- radius (rx, rz) of a station list at height y (stations ascend in Y)
local function radiiAt(st, y)
	if y <= st[1].p.Y then return st[1].rx, st[1].rz end
	for i = 1, #st - 1 do
		local a, b = st[i], st[i + 1]
		if y <= b.p.Y then
			local t = (y - a.p.Y) / math.max(1e-6, b.p.Y - a.p.Y)
			return a.rx + (b.rx - a.rx) * t, a.rz + (b.rz - a.rz) * t
		end
	end
	return st[#st].rx, st[#st].rz
end

-- =====================================================================================
-- THE ANATOMY KIT (K). Every skin is built from the SAME anatomy so every character has the same proportions and the same joints:
--   * ONE continuous tube per limb segment, thick at the top, thinning to the bottom (never a stack of separate blobs).
--   * A BALL at every real rig pivot (shoulder, elbow, hip, knee, ankle) at least as wide as the tubes it joins: the surface stays closed when the limb bends.
--   * The torso is one tube with a V taper: broad chest + shoulders, narrow waist, hips narrower than the chest.
--   * Garment thickness comes from `pad` (a skin is built from its OUTERMOST layer only, nothing hidden underneath).
-- Numbers are for a real player (u = 1); everything is multiplied by Z.u so the lobby figure matches exactly.
-- =====================================================================================
local K = {}

-- torso stations (UpperTorso frame). o.pad = garment thickness, o.chest = chest width multiplier
function K.torsoSt(Z, o)
	local u = Z.u
	local ny = J.ut(Z.UpperTorso).neck.Y
	local pad, ch = (o.pad or 0) * u, o.chest or 1
	local function s(f, rx, rz) return { p = V3(0, f * ny, 0), rx = rx * u * (f > -0.2 and ch or 1) + pad, rz = rz * u + pad } end
	return {
		s(-1.0, 0.52, 0.37), s(-0.5, 0.57, 0.40), s(0.0, 0.64, 0.43), s(0.42, 0.70, 0.44), s(0.76, 0.66, 0.39), s(1.0, 0.34, 0.29),
	}
end

-- neck (skin) + torso garment + shoulder + pelvis. Returns torso stations for surface placement.
function K.torso(B, Z, col, mat, o)
	o = o or {}
	local u = Z.u
	local A = {}
	if Z.UpperTorso then
		local jt = J.ut(Z.UpperTorso)
		local ny = jt.neck.Y
		local st = K.torsoSt(Z, o)
		B.tube("UpperTorso", st, col, mat)
		-- shoulder yoke: one bar across the shoulder line from arm pivot to arm pivot, so the arms grow out of the torso (trapezius + deltoid line)
		local ua = Z.RightUpperArm
		if ua then
			local xe = (Z.shX or (Z.UpperTorso.X * 0.5 + ua.X * 0.5)) * 0.92
			local ys = jt.sh
			local pad = (o.pad or 0) * u
			B.tube("UpperTorso", {
				{ p = V3(-xe, ys + 0.01 * u, 0), rx = 0.34 * u + pad, rz = 0.29 * u + pad },
				{ p = V3(0, ys + 0.03 * u, 0.01 * u), rx = 0.38 * u + pad, rz = 0.27 * u + pad },
				{ p = V3(xe, ys + 0.01 * u, 0), rx = 0.34 * u + pad, rz = 0.29 * u + pad },
			}, col, mat)
		end
		A.st, A.ny = st, ny
		A.chest = function(x, y, dz) -- point on the torso front surface at (x, y)
			local rx, rz = radiiAt(st, y)
			local k = math.clamp(x / rx, -0.98, 0.98)
			return V3(x, y, -rz * math.sqrt(1 - k * k) + (dz or 0))
		end
		A.back = function(x, y, dz)
			local rx, rz = radiiAt(st, y)
			local k = math.clamp(x / rx, -0.98, 0.98)
			return V3(x, y, rz * math.sqrt(1 - k * k) + (dz or 0))
		end
	end
	if Z.LowerTorso then
		local jl = J.lt(Z.LowerTorso)
		local top, bot = jl.waist.Y, -Z.LowerTorso.Y * 0.5
		local pad = (o.pad or 0) * u
		B.tube("LowerTorso", {
			{ p = V3(0, top + 0.02 * u, 0), rx = 0.58 * u + pad, rz = 0.39 * u + pad },
			{ p = V3(0, bot - 0.1 * u, 0.0), rx = 0.62 * u + pad, rz = 0.42 * u + pad },
		}, o.pelvisCol or col, o.pelvisMat or mat)
		B.ell("LowerTorso", V3(1.12, 0.62, 0.72) * u, CFn(0, bot - 0.12 * u, 0.03 * u), o.pelvisCol or col, o.pelvisMat or mat) -- seat: closes the crotch
		A.waistY, A.hipY = top, bot
	end
	return A
end

-- one arm: sleeve tube + shoulder cap + elbow ball. The arm hangs on the rig bone (pivot on the centre line), so it follows every animation exactly.
function K.arm(B, Z, side, col, mat, o)
	o = o or {}
	local u, sg = Z.u, side == "Right" and 1 or -1
	local ua, la = Z[side .. "UpperArm"], Z[side .. "LowerArm"]
	local pad = (o.pad or 0) * u
	local info = { lax = 0 }
	if ua then
		local j = J.ua(ua, sg)
		local shY = j.sh.Y
		local R1, R2 = o.upper or 0.30, o.lower or 0.22
		B.ball(side .. "UpperArm", j.sh + V3(0, 0.01 * u, 0), (R1 + 0.035) * u * (o.shoulder or 1) + pad, col, mat) -- shoulder cap on the REAL pivot
		B.tube(side .. "UpperArm", {
			{ p = V3(0, shY, 0), rx = R1 * u + pad, rz = (R1 + 0.01) * u + pad },
			{ p = V3(0, shY * 0.2, 0), rx = (R1 - 0.03) * u + pad, rz = (R1 - 0.01) * u + pad },
			{ p = V3(0, j.el.Y, 0), rx = R2 * u + pad, rz = (R2 + 0.01) * u + pad },
		}, col, mat)
		B.ball(side .. "UpperArm", j.el, (R2 + 0.01) * u + pad, col, mat) -- elbow ball (the bend pivots here)
		info.shY, info.elY = shY, j.el.Y
	end
	if la then
		local j = J.la(la)
		local R2, R3 = o.lower or 0.22, o.wrist or 0.155
		B.tube(side .. "LowerArm", {
			{ p = V3(0, j.el.Y, 0), rx = R2 * u + pad, rz = (R2 + 0.01) * u + pad },
			{ p = V3(0, j.el.Y * 0.2, 0), rx = (R2 + 0.012) * u + pad, rz = (R2 + 0.025) * u + pad },
			{ p = V3(0, j.wr.Y, 0), rx = R3 * u + pad, rz = (R3 + 0.01) * u + pad },
		}, col, mat)
		info.wrY, info.lelY = j.wr.Y, j.el.Y
	end
	return info
end

-- the hand: chunky glove (palm + curled finger block + thumb). fingerCol lets fingerless gloves show skin.
function K.hand(B, Z, side, glove, fingerCol, armInfo)
	local u, sg = Z.u, side == "Right" and 1 or -1
	local hd = Z[side .. "Hand"]
	if not hd then return end
	local j = J.hd(hd)
	local w = j.wr
	local ax = armInfo and armInfo.lax or 0
	local gl, fg = glove, fingerCol or glove
	B.ball(side .. "Hand", w + V3(ax, 0.02 * u, 0), 0.17 * u, gl, SP)                                                -- wrist ball (hand turns here)
	B.ell(side .. "Hand", V3(0.3, 0.32, 0.27) * u, CFn(w + V3(ax, -0.15 * u, 0)), gl, SP)                          -- palm / back of hand
	B.ell(side .. "Hand", V3(0.28, 0.26, 0.3) * u, CFn(w + V3(ax - sg * 0.02 * u, -0.34 * u, -0.01 * u)), fg, SP)  -- finger block
	B.ell(side .. "Hand", V3(0.1, 0.22, 0.1) * u, CFn(w + V3(ax - sg * 0.12 * u, -0.2 * u, -0.12 * u)) * CFrame.Angles(rad(-20), 0, rad(sg * 20)), fg, SP) -- thumb
end

-- one leg: thigh tube, calf tube, hip / knee / ankle balls. col = trouser colour.
function K.leg(B, Z, side, col, mat, o)
	o = o or {}
	local u = Z.u
	local ul, ll = Z[side .. "UpperLeg"], Z[side .. "LowerLeg"]
	local pad = (o.pad or 0) * u
	local info = {}
	if ul then
		local j = J.ul(ul)
		local T = o.thigh or 0.30
		B.ball(side .. "UpperLeg", j.hip, (T + 0.01) * u + pad, col, mat)
		B.tube(side .. "UpperLeg", {
			{ p = V3(0, j.hip.Y, 0), rx = T * u + pad, rz = (T + 0.02) * u + pad },
			{ p = V3(0, 0.0, 0), rx = (T - 0.02) * u + pad, rz = (T + 0.01) * u + pad },
			{ p = V3(0, j.kn.Y, 0), rx = 0.235 * u + pad, rz = 0.255 * u + pad },
		}, col, mat)
		B.ball(side .. "UpperLeg", j.kn, 0.25 * u + pad, col, mat)
		info.hipY, info.knY = j.hip.Y, j.kn.Y
	end
	if ll then
		local j = J.ll(ll)
		B.tube(side .. "LowerLeg", {
			{ p = V3(0, j.kn.Y, 0), rx = 0.235 * u + pad, rz = 0.255 * u + pad },
			{ p = V3(0, j.kn.Y * 0.35, 0.02 * u), rx = 0.25 * u + pad, rz = 0.275 * u + pad },
			{ p = V3(0, j.an.Y, 0), rx = (o.ankle or 0.16) * u + pad, rz = ((o.ankle or 0.16) + 0.02) * u + pad },
		}, col, mat)
		info.lknY, info.anY = j.kn.Y, j.an.Y
	end
	return info
end

-- the shoe: heel + foot + toe box + sole + ankle ball. o.collar = high-top shaft colour height, shoeCol / soleCol
function K.shoe(B, Z, side, shoe, sole, o)
	o = o or {}
	local u = Z.u
	local ft = Z[side .. "Foot"]
	if not ft then return end
	local j = J.ft(ft)
	local fb = -ft.Y * 0.5
	local up = o.up or 0
	B.ball(side .. "Foot", V3(0, j.an.Y, 0.02 * u), 0.2 * u, shoe, SP)                                                     -- ankle ball
	B.tube(side .. "Foot", { { p = V3(0, j.an.Y, 0.04 * u), rx = 0.2 * u, rz = 0.22 * u }, { p = V3(0, fb + 0.2 * u, 0.1 * u), rx = 0.22 * u, rz = 0.26 * u } }, shoe, SP)
	B.ell(side .. "Foot", V3(0.43, 0.32, 0.9) * u, CFn(0, fb + 0.19 * u, -0.14 * u), shoe, SP)                                -- foot body
	B.ell(side .. "Foot", V3(0.41, 0.24, 0.44) * u, CFn(0, fb + 0.15 * u, -0.43 * u), shoe, SP)                               -- toe box
	B.box(side .. "Foot", V3(0.45, 0.07, 0.98) * u, CFn(0, fb + 0.035 * u, -0.16 * u), sole, Enum.Material.Rubber)             -- sole
	B.ell(side .. "Foot", V3(0.45, 0.1, 0.34) * u, CFn(0, fb + 0.05 * u, -0.6 * u), sole, Enum.Material.Rubber)                -- sole toe
	return { footBottom = fb, an = j.an.Y }
end

-- neck + head + face. face=false for masked skins. Returns the head ellipsoids + a surface helper.
function K.head(B, Z, C, o)
	o = o or {}
	local u = Z.u
	local A = {}
	if Z.UpperTorso then
		local ny = J.ut(Z.UpperTorso).neck.Y
		B.tube("UpperTorso", { { p = V3(0, ny * 0.8, 0.01 * u), rx = 0.24 * u, rz = 0.25 * u }, { p = V3(0, ny + 0.2 * u, 0.0), rx = 0.19 * u, rz = 0.2 * u } }, C.Skin, SP)
	end
	if Z.Head then
		local h = Z.h
		local E = {
			{ V3(0, 0.1 * h, 0.03 * h), V3(0.7, 0.8, 0.8) * h },      -- cranium
			{ V3(0, -0.1 * h, -0.07 * h), V3(0.58, 0.62, 0.62) * h },  -- face
			{ V3(0, -0.29 * h, -0.08 * h), V3(0.5, 0.3, 0.46) * h },   -- jaw
			{ V3(0, -0.37 * h, -0.19 * h), V3(0.26, 0.2, 0.24) * h },  -- chin
		}
		for _, e in E do B.ell("Head", e[2], CFn(e[1]), C.Skin, SP) end
		A.headE = E
		A.at = function(x, y, dz) return V3(x, y, headFront(E, x, y) + (dz or 0)) end
		if o.face ~= false then
			local at = A.at
			for _, s in { -1, 1 } do
				B.ell("Head", V3(0.08, 0.22, 0.16) * h, CFn(s * 0.345 * h, -0.02 * h, 0.04 * h) * CFrame.Angles(0, s * rad(-14), 0), C.SkinShade, SP)
				local e = at(s * 0.13 * h, 0.0, 0.012 * h)
				B.ell("Head", V3(0.12, 0.062, 0.04) * h, CFn(e) * CFrame.Angles(0, s * rad(-16), 0), rgb(236, 232, 226), SP)
				B.ell("Head", V3(0.056, 0.056, 0.03) * h, CFn(e + V3(0, 0, -0.012 * h)) * CFrame.Angles(0, s * rad(-16), 0), C.Eye, SP)
				local b = at(s * 0.13 * h, 0.08 * h, -0.004 * h)
				B.box("Head", V3(0.15, 0.032, 0.045) * h, CFn(b) * CFrame.Angles(0, s * rad(-16), s * rad(-7)), C.Hair, SP)
			end
			local n = at(0, -0.08 * h, 0)
			B.ell("Head", V3(0.09, 0.2, 0.13) * h, CFn(n + V3(0, 0, -0.025 * h)) * CFrame.Angles(rad(-12), 0, 0), C.Skin, SP)
			B.ell("Head", V3(0.12, 0.06, 0.08) * h, CFn(at(0, -0.17 * h, -0.02 * h)), C.SkinShade, SP)
			B.box("Head", V3(0.15, 0.022, 0.03) * h, CFn(at(0, -0.24 * h, -0.002 * h)), C.Lip, SP)
		end
	end
	return A
end

-- =====================================================================================
-- OUTFITS. Each skin = an `identity sentence`, a palette (60 % base / 30 % second / 10 % accent), ONE silhouette idea, ONE hero prop.
-- Build order: K.head -> K.torso -> arms + hands -> legs + shoes -> the few signature shapes. Nothing floats: every shape sits ON a garment.
-- =====================================================================================
local DRESS = {}

-- ---------------------------------------------------------------- OPERATOR (base skin = the game itself)
-- "A clean, fast arcade operator": charcoal jacket + ONE bold red slash (the Breakline mark) + light cargo trousers + white-soled high-tops.
DRESS.OPERATOR = function(B, Z, C, opt)
	local u = Z.u
	local RED, JACKET, RIB = C.Brand, C.Top, C.TopDark
	local AH = K.head(B, Z, C, {})
	-- hair: short textured crop, side-swept top
	if Z.Head then
		local h = Z.h
		B.ell("Head", V3(0.74, 0.56, 0.84) * h, CFn(0, 0.25 * h, 0.06 * h), C.Hair, SP)
		B.ell("Head", V3(0.56, 0.26, 0.62) * h, CFn(0.04 * h, 0.44 * h, -0.04 * h) * CFrame.Angles(0, 0, rad(-6)), C.Hair, SP)
		B.ell("Head", V3(0.42, 0.18, 0.3) * h, CFn(0.1 * h, 0.36 * h, -0.28 * h) * CFrame.Angles(rad(18), 0, rad(-10)), C.Hair, SP)
		B.ell("Head", V3(0.62, 0.4, 0.5) * h, CFn(0, 0.06 * h, 0.22 * h), C.Hair, SP)
		for _, s in { -1, 1 } do B.box("Head", V3(0.04, 0.14, 0.08) * h, CFn(s * 0.34 * h, 0.06 * h, -0.02 * h), C.Hair, SP) end
		-- headset: ear cup + boom mic (left)
		B.ell("Head", V3(0.1, 0.2, 0.18) * h, CFn(-0.39 * h, -0.02 * h, 0.04 * h), C.Strap, SP)
		B.rod("Head", V3(-0.41 * h, -0.08 * h, 0.0), V3(-0.3 * h, -0.24 * h, -0.3 * h), 0.03 * h, C.Strap, SP)
		B.ball("Head", V3(-0.29 * h, -0.245 * h, -0.31 * h), 0.032 * h, C.Strap, SP)
	end
	-- ---- jacket: torso + collar + rib hem + slash + zip
	local T = K.torso(B, Z, JACKET, FABRIC, { pad = 0.03, pelvisCol = C.Pants, pelvisMat = FABRIC })
	if T.st then
		local ny = T.ny
		-- stand collar (tube around the neck base) + darker rim
		B.tube("UpperTorso", { { p = V3(0, ny * 0.82, 0.0), rx = 0.36 * u, rz = 0.31 * u }, { p = V3(0, ny + 0.1 * u, 0.0), rx = 0.31 * u, rz = 0.27 * u } }, JACKET, FABRIC)
		B.tube("UpperTorso", { { p = V3(0, ny + 0.08 * u, 0.0), rx = 0.315 * u, rz = 0.275 * u }, { p = V3(0, ny + 0.17 * u, 0.0), rx = 0.3 * u, rz = 0.26 * u } }, RIB, FABRIC)
		-- rib-knit hem band (bomber): slightly wider, darker
		B.tube("UpperTorso", { { p = V3(0, -ny - 0.0 * u, 0), rx = 0.625 * u, rz = 0.43 * u }, { p = V3(0, -ny * 0.78, 0), rx = 0.635 * u, rz = 0.44 * u } }, RIB, FABRIC)
		-- THE SLASH: one bold red diagonal across the chest, from the left shoulder to the right hip, lying on the jacket surface
		local pts = {}
		for i = 0, 6 do
			local t = i / 6
			local y = ny * (0.66 - 1.62 * t)
			local x = (-0.5 + 1.0 * t) * u
			local p = T.chest(x, y, -0.004 * u)
			pts[#pts + 1] = { p = p, rx = 0.085 * u, rz = 0.018 * u }
		end
		B.tube("UpperTorso", pts, RED, SP)
		-- zip: thin metal line down the front centre + a pull
		local zp = {}
		for i = 0, 4 do
			local y = ny * (0.92 - 1.8 * i / 4)
			zp[#zp + 1] = { p = T.chest(0.0, y, -0.004 * u), rx = 0.016 * u, rz = 0.012 * u }
		end
		B.tube("UpperTorso", zp, C.Metal, METAL)
		B.box("UpperTorso", V3(0.04, 0.12, 0.025) * u, CFn(T.chest(0.0, ny * 0.86, -0.02 * u)), RED, SP)
	end
	-- ---- sleeves (same jacket colour, one tube each) + dark rib cuffs + gloves with skin fingers
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local info = K.arm(B, Z, side, JACKET, FABRIC, { pad = 0.03 })
		if Z[side .. "LowerArm"] and info.wrY then
			B.tube(side .. "LowerArm", { { p = V3(info.lax, info.wrY + 0.2 * u, 0), rx = 0.2 * u, rz = 0.21 * u }, { p = V3(info.lax, info.wrY - 0.02 * u, 0), rx = 0.19 * u, rz = 0.2 * u } }, RIB, FABRIC)
		end
		if not opt.noHands then K.hand(B, Z, side, C.Glove, C.Skin, info) end
	end
	-- ---- belt + buckle, and trousers
	local l = Z.LowerTorso
	if l then
		local jl = J.lt(l)
		B.tube("LowerTorso", { { p = V3(0, jl.waist.Y - 0.1 * u, 0), rx = 0.615 * u, rz = 0.425 * u }, { p = V3(0, jl.waist.Y - 0.02 * u, 0), rx = 0.615 * u, rz = 0.425 * u } }, C.Strap, FABRIC)
		B.box("LowerTorso", V3(0.2, 0.14, 0.05) * u, CFn(0, jl.waist.Y - 0.06 * u, -0.45 * u), C.Metal, METAL)
	end
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local li = K.leg(B, Z, side, C.Pants, FABRIC, { pad = 0.025 })
		-- trouser cuff: dark band at the ankle
		if li.anY then B.ring(side .. "LowerLeg", li.anY + 0.14 * u, 0.4 * u, 0.44 * u, 0.12 * u, C.PantsDark, FABRIC) end
		-- right thigh: drop-leg holster (the one hero prop); left thigh: cargo pocket
		if li.hipY then
			if side == "Right" then
				B.ring(side .. "UpperLeg", li.hipY - 0.3 * u, 0.7 * u, 0.74 * u, 0.07 * u, C.Strap, FABRIC)
				B.ring(side .. "UpperLeg", li.hipY - 0.62 * u, 0.62 * u, 0.68 * u, 0.07 * u, C.Strap, FABRIC)
				B.ell(side .. "UpperLeg", V3(0.2, 0.62, 0.36) * u, CFn(sg * 0.31 * u, li.hipY - 0.48 * u, 0.0), C.Strap, SP)
				B.ell(side .. "UpperLeg", V3(0.16, 0.24, 0.2) * u, CFn(sg * 0.33 * u, li.hipY - 0.12 * u, 0.06 * u) * CFrame.Angles(rad(14), 0, 0), C.Pad, SP)
			else
				B.ell(side .. "UpperLeg", V3(0.2, 0.46, 0.4) * u, CFn(sg * 0.31 * u, li.hipY - 0.52 * u, 0.0), C.PantsDark, FABRIC)
			end
		end
		-- knee pads (both): a hard shell over the front of each knee
		if li.lknY then
			B.ell(side .. "LowerLeg", V3(0.46, 0.4, 0.22) * u, CFn(0, li.lknY - 0.04 * u, -0.28 * u), C.Pad, SP)
			B.box(side .. "LowerLeg", V3(0.3, 0.05, 0.05) * u, CFn(0, li.lknY - 0.04 * u, -0.38 * u), RED, SP)
		end
		-- high-top sneaker: white sole, red heel tab
		local sh = K.shoe(B, Z, side, C.Shoe, C.Sole, {})
		if sh then
			local fb = sh.footBottom
			B.box(side .. "Foot", V3(0.4, 0.1, 0.2) * u, CFn(0, fb + 0.2 * u, 0.3 * u), RED, SP)
			B.ell(side .. "Foot", V3(0.2, 0.04, 0.4) * u, CFn(0, fb + 0.33 * u, -0.28 * u) * CFrame.Angles(rad(-20), 0, 0), C.Sole, SP) -- tongue / laces
		end
	end
end

-- ---------------------------------------------------------------- SOULBOUND (soul skin = the "carries the dead" half of the game)
-- "A pallbearer": ONE long navy hooded coat (the silhouette), a bone mask (the face), a bone pauldron (the shoulder), a soul lantern (the only glow).
DRESS.SOULBOUND = function(B, Z, C, opt)
	local u = Z.u
	local BONE, SOUL, COAT, COATD = C.Bone, C.Soul, C.Top, C.TopDark
	local AH = K.head(B, Z, C, { face = false })
	-- ---- bone mask + hood
	if Z.Head then
		local h = Z.h
		local E = AH.headE
		local mz = headFront(E, 0, -0.04 * h)
		B.ell("Head", V3(0.6, 0.74, 0.3) * h, CFn(0, -0.04 * h, mz + 0.06 * h), BONE, SP)
		B.ell("Head", V3(0.34, 0.3, 0.2) * h, CFn(0, -0.3 * h, mz + 0.04 * h), BONE, SP)
		for _, s in { -1, 1 } do
			local e = V3(s * 0.13 * h, 0.02 * h, mz - 0.075 * h)
			B.ell("Head", V3(0.17, 0.1, 0.06) * h, CFn(e) * CFrame.Angles(0, s * rad(-14), s * rad(12)), rgb(12, 14, 20), SP)
			B.ball("Head", e + V3(0, 0, -0.03 * h), 0.022 * h, SOUL, NEON)
			B.box("Head", V3(0.16, 0.03, 0.04) * h, CFn(s * 0.15 * h, -0.13 * h, mz - 0.06 * h) * CFrame.Angles(0, s * rad(-18), s * rad(-20)), C.BoneShade, SP)
		end
		B.box("Head", V3(0.03, 0.2, 0.04) * h, CFn(0, 0.2 * h, mz - 0.07 * h), C.BoneShade, SP)
		for i = -2, 2 do B.box("Head", V3(0.03, 0.07, 0.03) * h, CFn(i * 0.045 * h, -0.3 * h, mz - 0.1 * h + math.abs(i) * 0.012 * h), rgb(40, 40, 46), SP) end
		-- hood: shell over the back + top of the head, rim round the face (one tube on an arc), pointed back
		B.ell("Head", V3(0.98, 1.04, 1.04) * h, CFn(0, 0.08 * h, 0.14 * h), COAT, FABRIC)
		local arc = {}
		for i = 0, 8 do
			local a = rad(-180 + i * 22.5)
			arc[#arc + 1] = { p = V3(math.cos(a) * 0.43 * h, 0.07 * h - math.sin(a) * 0.52 * h, -0.34 * h + math.abs(math.cos(a)) * 0.08 * h), rx = 0.11 * h, rz = 0.11 * h }
		end
		B.tube("Head", arc, COATD, FABRIC)
		B.tube("Head", { { p = V3(0, 0.1 * h, 0.4 * h), rx = 0.3 * h, rz = 0.3 * h }, { p = V3(0, 0.0 * h, 0.78 * h), rx = 0.07 * h, rz = 0.07 * h } }, COAT, FABRIC) -- back point
	end
	-- ---- coat: torso tube with a wide stand collar + hood drape (cowl) on the shoulders
	local T = K.torso(B, Z, COAT, FABRIC, { pad = 0.05, chest = 1.04, pelvisCol = COAT, pelvisMat = FABRIC })
	if T.st then
		local ny = T.ny
		B.tube("UpperTorso", { { p = V3(0, ny * 0.7, 0), rx = 0.56 * u, rz = 0.44 * u }, { p = V3(0, ny + 0.12 * u, 0.04 * u), rx = 0.4 * u, rz = 0.36 * u } }, COATD, FABRIC)
		-- front: centre seam piped in soul blue, 3 bone toggles
		local sp = {}
		for i = 0, 5 do sp[#sp + 1] = { p = T.chest(0, ny * (0.7 - i * 0.3), -0.004 * u), rx = 0.018 * u, rz = 0.012 * u } end
		B.tube("UpperTorso", sp, C.Shirt, SP)
		for i = 0, 2 do
			local p = T.chest(0, ny * (0.5 - i * 0.42), -0.02 * u)
			B.ell("UpperTorso", V3(0.26, 0.07, 0.06) * u, CFn(p), BONE, SP)
			B.ball("UpperTorso", p + V3(0, 0, -0.01 * u), 0.04 * u, C.BoneShade, SP)
		end
		-- spine beads on the back (small, readable from behind)
		for i = 0, 3 do B.ball("UpperTorso", T.back(0, ny * (0.55 - i * 0.34), 0.0), 0.05 * u, C.BoneShade, SP) end
	end
	-- ---- sleeves + bone-wrap forearms + dark gloves; left shoulder bone pauldron
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local info = K.arm(B, Z, side, COAT, FABRIC, { pad = 0.045, shoulder = 1.08 })
		if Z[side .. "LowerArm"] and info.wrY then
			for i = 0, 2 do
				B.ring(side .. "LowerArm", info.wrY + (0.08 + i * 0.15) * u, (0.43 + i * 0.01) * u, (0.45 + i * 0.01) * u, 0.1 * u, C.Wrap, FABRIC, CFn(info.lax, 0, 0) * CFrame.Angles(rad(i % 2 == 0 and 7 or -7), 0, 0))
			end
		end
		if not opt.noHands then K.hand(B, Z, side, C.Glove, C.Glove, info) end
		local ua = Z[side .. "UpperArm"]
		if ua and side == "Left" then
			local j = J.ua(ua, sg)
			for i = 0, 2 do
				B.ell(side .. "UpperArm", V3(0.78 - i * 0.1, 0.2, 0.74 - i * 0.08) * u, CFn(j.sh + V3(sg * (0.1 + i * 0.03) * u, (0.1 - i * 0.14) * u, 0)) * CFrame.Angles(0, 0, sg * rad(22 + i * 8)), i == 1 and C.BoneShade or BONE, SP)
			end
			B.tube(side .. "UpperArm", { { p = j.sh + V3(sg * 0.26 * u, 0.22 * u, 0), rx = 0.07 * u, rz = 0.07 * u }, { p = j.sh + V3(sg * 0.38 * u, 0.5 * u, 0.04 * u), rx = 0.015 * u, rz = 0.015 * u } }, BONE, SP)
		end
	end
	-- ---- rope belt + skull buckle + soul lantern (right hip)
	local l = Z.LowerTorso
	if l then
		local jl = J.lt(l)
		B.tube("LowerTorso", { { p = V3(0, jl.waist.Y - 0.05 * u, 0), rx = 0.645 * u, rz = 0.45 * u }, { p = V3(0, jl.waist.Y - 0.0 * u, 0), rx = 0.645 * u, rz = 0.45 * u } }, C.Strap, FABRIC)
		B.ell("LowerTorso", V3(0.2, 0.2, 0.12) * u, CFn(0, jl.waist.Y - 0.04 * u, -0.5 * u), BONE, SP)
		for _, s in { -1, 1 } do B.ball("LowerTorso", V3(s * 0.045 * u, jl.waist.Y - 0.04 * u, -0.565 * u), 0.026 * u, rgb(14, 14, 18), SP) end
		local hip = V3(0.74 * u, jl.waist.Y - 0.5 * u, -0.04 * u)
		B.rod("LowerTorso", V3(0.62 * u, jl.waist.Y - 0.04 * u, -0.04 * u), hip + V3(0, 0.24 * u, 0), 0.03 * u, C.Metal, METAL)
		B.ell("LowerTorso", V3(0.22, 0.06, 0.22) * u, CFn(hip + V3(0, 0.17 * u, 0)), C.Metal, METAL)
		B.ell("LowerTorso", V3(0.22, 0.06, 0.22) * u, CFn(hip + V3(0, -0.17 * u, 0)), C.Metal, METAL)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			B.box("LowerTorso", V3(0.025, 0.34, 0.025) * u, CFn(hip + V3(math.cos(a) * 0.09 * u, 0, math.sin(a) * 0.09 * u)), C.Metal, METAL)
		end
		B.ball("LowerTorso", hip, 0.075 * u, SOUL, NEON)
	end
	-- ---- legs: dark trousers, the coat tails (flat tapered panels hanging from each thigh), tall wrapped boots
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local li = K.leg(B, Z, side, C.Pants, FABRIC, { pad = 0.03, thigh = 0.32 })
		if li.hipY then
			local top, bot = li.hipY + 0.05 * u, li.hipY - 1.25 * u
			-- front + back + outer panels: widen towards the hem, so the coat flares
			B.tube(side .. "UpperLeg", { { p = V3(sg * 0.03 * u, top, -0.34 * u), rx = 0.36 * u, rz = 0.04 * u }, { p = V3(sg * 0.05 * u, bot, -0.46 * u), rx = 0.38 * u, rz = 0.045 * u } }, COAT, FABRIC)
			B.tube(side .. "UpperLeg", { { p = V3(sg * 0.03 * u, top, 0.34 * u), rx = 0.36 * u, rz = 0.04 * u }, { p = V3(sg * 0.05 * u, bot - 0.08 * u, 0.48 * u), rx = 0.38 * u, rz = 0.045 * u } }, COAT, FABRIC)
			B.tube(side .. "UpperLeg", { { p = V3(sg * 0.36 * u, top, 0.0), rx = 0.04 * u, rz = 0.34 * u }, { p = V3(sg * 0.5 * u, bot, 0.0), rx = 0.045 * u, rz = 0.38 * u } }, COATD, FABRIC)
			B.tube(side .. "UpperLeg", { { p = V3(sg * 0.05 * u, bot - 0.02 * u, -0.46 * u), rx = 0.39 * u, rz = 0.05 * u }, { p = V3(sg * 0.05 * u, bot + 0.1 * u, -0.46 * u), rx = 0.385 * u, rz = 0.05 * u } }, C.Shirt, FABRIC) -- soul-blue hem piping
		end
		-- boots: tall shaft over the calf, rope straps
		if Z[side .. "LowerLeg"] then
			local j = J.ll(Z[side .. "LowerLeg"])
			B.tube(side .. "LowerLeg", { { p = V3(0, j.kn.Y * 0.4, 0.02 * u), rx = 0.31 * u, rz = 0.33 * u }, { p = V3(0, j.an.Y, 0), rx = 0.235 * u, rz = 0.25 * u } }, C.Shoe, SP)
			for i = 0, 2 do
				B.ring(side .. "LowerLeg", j.an.Y + (0.2 + i * 0.22) * u, 0.5 * u - i * 0.012 * u, 0.52 * u - i * 0.012 * u, 0.07 * u, C.Strap, FABRIC, CFrame.Angles(rad(8), 0, 0))
			end
		end
		K.shoe(B, Z, side, C.Shoe, C.Sole, {})
	end
end


-- =====================================================================================
-- REAL CHARACTERS (server)
-- =====================================================================================
local RIG_PARTS = {
	"Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

S._DRESS = DRESS -- test hooks (tools/skintest)
S._newBuilder = newBuilder

local function makeShell(kind, size, color, mat)
	local p = Instance.new("Part")
	p.Name = "Shell"
	if kind == "cyl" then p.Shape = Enum.PartType.Cylinder end
	p.Size = V3(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.Color = color
	p.Material = mat or SP
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = size.Magnitude > 1.0 and mat ~= NEON
	if kind == "ell" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	return p
end

local function headSizeOf(head)
	local s = math.min(head.Size.Y, head.Size.Z) * 1.2
	return s
end

function S.Dress(char, skinId, _accentIgnored)
	local skin = S.Get(skinId)
	local C = skin.colors
	local head = char:WaitForChild("Head", 10)
	local torso = char:FindFirstChild("UpperTorso") or char:WaitForChild("UpperTorso", 3) or char:FindFirstChild("Torso")
	if not head or not torso or not char.Parent then return end
	S.Prepare(char)
	if not char.Parent then return end

	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then bc:Destroy() end
	for _, d in char:GetChildren() do
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
	if not char:FindFirstChild("UpperTorso") then return end -- R6 / unknown rigs: nothing to build on

	local P, Z = {}, {}
	for _, n in RIG_PARTS do
		local part = char:FindFirstChild(n)
		P[n] = part
		if part then
			part.Transparency = 1
			part.CastShadow = false
			Z[n] = part.Size
		end
	end
	Z.u = (Z.UpperTorso and Z.UpperTorso.Y or 1.79) / 1.792
	Z.h = headSizeOf(head)
	local B = newBuilder(function(base, kind, size, cf, color, mat)
		local bp = P[base]
		if not bp then return end
		local p = makeShell(kind, size, color, mat)
		p.CFrame = bp.CFrame * cf
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = bp, p, cf
		w.Parent = p
		p.Parent = gear
	end)
	DRESS[skin.id](B, Z, C, {})
end

-- =====================================================================================
-- SHOWCASE FIGURE (client). A virtual R15 rig (same joints as the real one) scaled by FIG_SCALE, dressed by the same DRESS code.
-- Figure space: faces +Z, +X = the figure's LEFT, feet at y = 0 (unchanged for every caller). Hips sit 2.7 * Height up (MatchFlow's throne relies on it).
-- =====================================================================================
local PR = S.Proportions
local STOCK = { -- stock R15 part sizes + centres (feet at y = 0), right side; the left side mirrors X
	Head = { V3(2, 1, 1), V3(0, 4.516, 0) },
	UpperTorso = { V3(2, 1.6, 1), V3(0, 3.216, 0) }, LowerTorso = { V3(2, 0.4, 1), V3(0, 2.216, 0) },
	UpperArm = { V3(1, 1.169, 1), V3(1.5, 3.387, 0) }, LowerArm = { V3(1, 1.052, 1), V3(1.5, 2.794, 0) }, Hand = { V3(1, 0.3, 1), V3(1.5, 2.168, 0) },
	UpperLeg = { V3(1, 1.217, 1), V3(0.5, 1.596, 0) }, LowerLeg = { V3(1, 1.193, 1), V3(0.5, 0.797, 0) }, Foot = { V3(1, 0.3, 1), V3(0.5, 0.15, 0) },
}
local function scaledStock(k)
	local sz, pos = {}, {}
	local function sc(v, head) if head then return v * PR.Head * k end return V3(v.X * PR.Width, v.Y * PR.Height, v.Z * PR.Depth) * k end
	for name, d in STOCK do
		if name == "Head" or name == "UpperTorso" or name == "LowerTorso" then
			sz[name] = sc(d[1], name == "Head")
			pos[name] = V3(0, d[2].Y * PR.Height * k, 0)
		else
			for _, side in { "Left", "Right" } do
				local sg = side == "Right" and 1 or -1
				sz[side .. name] = sc(d[1])
				pos[side .. name] = V3(sg * d[2].X * PR.Width * k, d[2].Y * PR.Height * k, 0)
			end
		end
	end
	-- the head sits on the neck: centre = neck + half the (scaled) head
	pos.Head = V3(0, (4.016 * PR.Height) * k + sz.Head.Y * 0.5, 0)
	return sz, pos
end

-- 2.7 * Height (old figure hip height) / stock hip height 2.016 * Height -> the figure is this much bigger than a real player
local FIG_SCALE = 2.7 / 2.016
S.FigureScale = FIG_SCALE

S.GunPose = {
	base = Vector3.new(-0.15, 0, 0.6),
	aim = { rot = Vector3.new(-0.17, -0.35, 0), pos = Vector3.new(0.3, 0.8, 0.6) },
	inspect = { rot = Vector3.new(-0.35, 0.35, 0.9), pos = Vector3.new(0, 0.7, 0.3) },
	low = { rot = Vector3.new(0.5, 0.2, 0.1), pos = Vector3.new(-0.2, -0.25, 0.2) },
}

-- figure gun hold: grip pulled in to the right shoulder, muzzle forward-left, upper body bladed (left shoulder forward) so the left hand reaches
-- the handguard of every gun (tuned offline against all 10 guns + every idle pose)
S.FigureTune = { gunScale = 0.7, gripX = -0.5, gripY = 0.1, gripZ = 0.15, dirX = 0.5, dirY = -0.2, blade = -0.7 }

local FLIP = CFrame.Angles(0, math.pi, 0) -- rig space (faces -Z, +X right) -> figure space (faces +Z, +X = left)

function S.NewFigure(parent, skinId, opts)
	opts = opts or {}
	local skin = S.Get(skinId)
	local c = skin.colors
	local k = FIG_SCALE
	local model = Instance.new("Model")
	model.Name = "Figure_" .. skin.id
	model.Parent = parent
	local sz, rest = scaledStock(k)
	local Z = { u = (sz.UpperTorso.Y / 1.792), h = math.min(sz.Head.Y, sz.Head.Z) * 1.2, shX = sz.UpperTorso.X * 0.5 + sz.RightUpperArm.X * 0.15 } -- lobby shoulders sit a little closer than in-game so both hands reach every gun
	for n, v in sz do Z[n] = v end
	local list = {}   -- { part, base, rel }
	local gunList = {} -- { part, rel }
	local function newPart(kind, size, color, mat)
		local p = makeShell(kind, size, color, mat)
		p.Anchored = true
		p.CastShadow = false
		p.Parent = model
		return p
	end
	local B = newBuilder(function(base, kind, size, cf, color, mat)
		table.insert(list, { part = newPart(kind, size, color, mat), base = base, rel = cf })
	end)
	DRESS[skin.id](B, Z, c, { noHands = true })

	-- ---- rig joints in rig space (y up, -Z forward, +X right)
	local HIP_Y = rest.LeftUpperLeg.Y + sz.LeftUpperLeg.Y * 0.345
	local NECK_Y = 4.016 * PR.Height * k
	local FT = S.FigureTune
	local BLADE = (opts.weapon and FT.blade or 0) -- rig-space yaw of the chest (negative = left shoulder forward)
	local chestCF = CFrame.new(rest.UpperTorso) * CFrame.Angles(0, BLADE, 0)
	local SH = {}
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		SH[side] = chestCF * V3(sg * Z.shX, sz.UpperTorso.Y * 0.352, 0)
	end
	local UA_SH = function(sg) return V3(0, sz.RightUpperArm.Y * 0.335, 0) end
	local UA_EL = V3(0, -sz.RightUpperArm.Y * 0.286, 0)
	local LA_EL, LA_WR = V3(0, sz.RightLowerArm.Y * 0.246, 0), V3(0, -sz.RightLowerArm.Y * 0.476, 0)
	local L1 = (UA_SH(1) - UA_EL).Magnitude
	local L2 = (LA_EL - LA_WR).Magnitude

	-- ---- the gun (figure space), the same placement as before but at chest height of the new body
	local GUN_S = FT.gunScale * k
	local chestY = rest.UpperTorso.Y + FT.gripY * k
	local A = Vector3.new(FT.gripX * k, chestY, FT.gripZ * k)
	local dir = Vector3.new(FT.dirX, FT.dirY, 1).Unit
	local Bp = A + dir * 4
	local rHand = A
	local lHand = A + dir * 1.3 * k + Vector3.new(0, -0.08, 0)
	local GM = opts.weapon and getGunModels()
	local desc
	if GM then
		local ok, d = pcall(GM.Describe, opts.weapon, "Iron")
		desc = ok and d or nil
	end
	local function addGun(size, cf, color, mat, shape)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		if shape then p.Shape = shape end
		p.Size = size
		p.Color = color
		p.Material = mat or SP
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		table.insert(gunList, { part = p, rel = cf })
	end
	if desc and desc.Points and desc.Points.Grip and desc.Points.Fore then
		local s = GUN_S
		local rot = CFrame.lookAt(Vector3.zero, (Bp - A).Unit)
		local gunCF = CFrame.new(rHand) * rot * CFrame.new(-desc.Points.Grip.Position * s)
		for _, d in desc.Parts do
			if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
				addGun(d.Size * s, gunCF * (CFrame.new(d.CF.Position * s) * d.CF.Rotation), d.Color, d.Material, d.Shape)
			end
		end
		local palm = desc.Points.Palm or desc.Points.Fore
		lHand = gunCF * (palm.Position * s)
		if (lHand - rHand).Magnitude < 0.9 then lHand = rHand + (lHand - rHand).Unit * 0.9 + Vector3.new(0, -0.15, 0) end
		if GM.HandParts then
			local hands = GM.HandParts(desc, c.Glove, c.Pad or c.Trim)
			for _, h in hands.right do addGun(h.Size * s, gunCF * (CFrame.new(h.CF.Position * s) * h.CF.Rotation), h.Color, SP, h.Shape) end
			local palmCF = gunCF * CFrame.new(palm.Position * s)
			for _, h in hands.left do addGun(h.Size * s, palmCF * (CFrame.new(h.CF.Position * s) * h.CF.Rotation), h.Color, SP, h.Shape) end
		end
	else
		-- no weapon: relaxed hands (simple gloved fists hanging at the sides) are part of the arm IK below
		rHand = Vector3.new(-Z.shX * 0.98, rest.RightHand.Y + 0.1 * k, 0.15 * k)
		lHand = Vector3.new(Z.shX * 0.98, rest.LeftHand.Y + 0.1 * k, 0.15 * k)
		for _, hp in { rHand, lHand } do
			local p = newPart("ell", V3(0.24, 0.4, 0.34) * Z.u, c.Glove, SP)
			table.insert(gunList, { part = p, rel = CFrame.new(hp), noGun = true })
		end
	end
	local hasGun = desc ~= nil

	local fig = { Model = model, HeadTop = NECK_Y + Z.h * 1.05, root = CFrame.new(),
		still = opts.still == true or opts.static == true, static = opts.static == true, idle = opts.idle == true,
		run = 0, runPhase = 0, sit = 0 }
	local rng = Random.new()
	local phase = rng:NextNumber(0, 6)
	local curYaw, curPitch, goYaw, goPitch, nextLook = 0, 0, 0, 0, 0
	local pose = { aim = 0, inspect = 0, low = 0, shift = 0, turn = 0 }
	local goal = { aim = 0, inspect = 0, low = 0, shift = 0, turn = 0 }
	local evt, evtStart, evtEnd = nil, 0, 0
	local IDLE_FIRST, IDLE_GAP = { 5, 9 }, { 9, 16 }
	local nextEvt = rng:NextNumber(IDLE_FIRST[1], IDLE_FIRST[2])
	local EVENTS = {
		{ name = "aim", w = 3, dur = { 2.4, 3.6 } }, { name = "inspect", w = 2, dur = { 2.8, 3.6 } }, { name = "low", w = 2, dur = { 3.0, 4.5 } },
		{ name = "scan", w = 3, dur = { 3.0, 4.2 } }, { name = "turn", w = 2, dur = { 3.0, 4.0 } }, { name = "shift", w = 2, dur = { 2.4, 3.4 } },
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
	local PIV = Vector3.new(0, chestY + 0.3 * k, 0.4 * k)

	function fig:SetRoot(cf) self.root = cf end

	-- part placement helpers (rig space)
	-- basis whose Y = dir and X = hint made perpendicular (columns X, Y, Z, right-handed)
	local function basis(dir, hint)
		local y = dir.Magnitude > 1e-5 and dir.Unit or Vector3.yAxis
		local x = hint - y * y:Dot(hint)
		if x.Magnitude < 1e-3 then x = Vector3.zAxis - y * y.Z end
		x = x.Unit
		return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
	end
	-- place a part so that its joint attachA lands on world point a and attachB lands on the line towards b (part X kept near sideHint)
	local function placeAlong(a, b, attachA, attachB, sideHint)
		local Mp = basis(attachA - attachB, Vector3.xAxis)
		local Mw = basis(a - b, sideHint)
		local R = Mw * Mp:Inverse()
		return CFrame.new(a) * R * CFrame.new(-attachA)
	end
	local function ik(Sv, T, pole)
		local d = T - Sv
		local dist = math.clamp(d.Magnitude, math.abs(L1 - L2) + 0.01, (L1 + L2) * 0.999)
		local dn = d.Magnitude > 1e-4 and d.Unit or -Vector3.yAxis
		local a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
		local hgt = math.sqrt(math.max(0, L1 * L1 - a * a))
		local perp = pole - dn * pole:Dot(dn)
		perp = perp.Magnitude > 1e-3 and perp.Unit or Vector3.new(0, -1, 0)
		return Sv + dn * a + perp * hgt, Sv + dn * dist
	end

	function fig:Update(t, dt)
		dt = dt or 0
		local still = self.still
		if self.idle and not still then
			if evt and t >= evtEnd then
				for kk in goal do goal[kk] = 0 end
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
		if evt and not (self.idle and not still) then
			for kk in goal do goal[kk] = 0 end
			lastEvt, evt = evt.name, nil
		end
		local pk = 1 - math.exp(-3.2 * dt)
		for kk, v in pose do pose[kk] = v + (goal[kk] - v) * pk end

		local br = math.sin(t * 1.7 + phase)
		local deep = 0.5 + 0.5 * math.sin(t * 0.37 + phase * 1.7)
		local still0 = self.static and 0 or (still and 0.5 or 1)
		local root = self.root
			* CFrame.new(0, (br * (0.03 + 0.016 * deep) + pose.aim * math.sin(t * 6) * 0.004) * still0, 0)
			* CFrame.Angles(0, math.sin(t * 0.5 + phase) * 0.05 * still0 + pose.turn * 0.55 + pose.shift * 0.12,
				math.sin(t * 0.9 + phase) * 0.012 * (self.static and 0 or 1) + pose.shift * 0.045)
			* CFrame.Angles(pose.aim * 0.04 + pose.inspect * 0.05, 0, 0)

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
			goYaw, goPitch = -evtSign * 0.5, 0.02
		elseif t >= nextLook then
			goYaw = math.rad(rng:NextNumber(-45, 45))
			goPitch = math.rad(rng:NextNumber(-6, 10))
			if opts.camPos and rng:NextInteger(1, 3) == 1 then
				local v = root:PointToObjectSpace(opts.camPos)
				goYaw = math.clamp(math.atan2(v.X, v.Z), math.rad(-60), math.rad(60))
				goPitch = 0
			end
			nextLook = t + rng:NextNumber(2.2, 4.8)
		end
		local kh = 1 - math.exp(-4 * dt)
		curYaw += (goYaw - curYaw) * kh
		curPitch += (goPitch - curPitch) * kh

		-- gun transform (figure space)
		local aim, ins, low = pose.aim, pose.inspect, pose.low
		local GP = S.GunPose
		local r = GP.aim.rot * aim + GP.inspect.rot * ins + GP.low.rot * low
		local rot = CFrame.Angles(r.X, r.Y, r.Z)
		local trn = GP.base + GP.aim.pos * aim + GP.inspect.pos * ins + GP.low.pos * low
		local gT = hasGun and (CFrame.new(trn) * CFrame.new(PIV) * rot * CFrame.new(-PIV)) or CFrame.identity

		-- ---- solve the rig (rig space)
		local base = {}
		base.UpperTorso = chestCF
		base.LowerTorso = CFrame.new(rest.LowerTorso)
		-- head: yaw / pitch about the neck (figure pitch +X = rig -X after the flip)
		base.Head = CFrame.new(0, NECK_Y, 0) * CFrame.Angles(-curPitch, curYaw + BLADE * 0.15, 0) * CFrame.new(0, rest.Head.Y - NECK_Y, 0)
		-- legs: swing at the hip, bend at the knee (sitting: thighs forward, shins down; running: knee folds on the back swing)
		local sitA, runA, rp = self.sit, self.run, self.runPhase
		for _, side in { "Left", "Right" } do
			local sg = side == "Right" and 1 or -1
			local swing = runA * math.sin(rp + (side == "Right" and 0 or math.pi))
			local hipAng = sitA * 1.45 + swing * 0.8 + (1 - sitA) * (1 - runA) * (sg * 0.06) -- + = thigh forward (rig: rotate about +X)
			local kneeAng = -sitA * 1.45 - runA * math.max(0, -math.cos(rp + (side == "Right" and 0 or math.pi))) * 1.1
			local hip = V3(rest[side .. "UpperLeg"].X, HIP_Y, 0)
			local hipCF = CFrame.new(hip) * CFrame.Angles(hipAng, 0, 0)
			local ulRel = rest[side .. "UpperLeg"] - hip
			base[side .. "UpperLeg"] = hipCF * CFrame.new(ulRel)
			local kneeLocal = V3(0, -sz[side .. "UpperLeg"].Y * 0.329, 0)
			local kneeCF = base[side .. "UpperLeg"] * CFrame.new(kneeLocal) * CFrame.Angles(kneeAng, 0, 0)
			base[side .. "LowerLeg"] = kneeCF * CFrame.new(0, -sz[side .. "LowerLeg"].Y * 0.334, 0)
			local ank = base[side .. "LowerLeg"] * CFrame.new(0, -sz[side .. "LowerLeg"].Y * 0.459, 0)
			base[side .. "Foot"] = ank * CFrame.Angles(-kneeAng - hipAng, 0, 0) * CFrame.new(0, -sz[side .. "Foot"].Y * 0.333, 0) -- feet stay level
		end
		-- arms: IK from the shoulder to the hand on the gun (hands come from the gun group)
		for _, side in { "Left", "Right" } do
			local sg = side == "Right" and 1 or -1
			local handFig = side == "Right" and rHand or lHand
			local hFig = gT:PointToWorldSpace(handFig)
			local hRig = FLIP:PointToWorldSpace(hFig) -- rig = flip(figure)
			local sh = SH[side]
			local wrist = hRig + (sh - hRig).Unit * 0.16 * k
			local pole = V3(sg * 0.8, -1, 0.35)
			local elbow, wr = ik(sh, wrist, pole)
			if fig._debug then fig._debug[side] = (wr - wrist).Magnitude end
			local side3 = V3(sg, 0, 0)
			base[side .. "UpperArm"] = placeAlong(sh, elbow, UA_SH(sg), UA_EL, side3)
			base[side .. "LowerArm"] = placeAlong(elbow, wr, LA_EL, LA_WR, side3)
		end
		-- ---- write every part (figure space = root * FLIP * rig)
		local RF = root * FLIP
		for _, e in list do
			local b = base[e.base]
			if b then e.part.CFrame = RF * b * e.rel end
		end
		for _, g in gunList do
			g.part.CFrame = root * gT * g.rel
		end
		if fig._debug then fig._debug.chest = RF * base.UpperTorso fig._debug.gun = gunList fig._debug.u = Z.u end
	end
	function fig:Destroy() model:Destroy() end
	fig._pose, fig._list = pose, list
	fig:Update(0, 0)
	return fig
end

return S
