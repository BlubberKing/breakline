-- Skins v9 (ModuleScript in ReplicatedStorage) - used by BOTH games (Lobby + Breakline). Keep the two copies identical. v9 (Nov 4): slim glove hands, showcase gun hold across the chest (gun visible in menus), chamfered body blocks, OPERATOR + SOULBOUND polish, see GDD 5.4 + 5.4d SKIN QUALITY STANDARD.
-- v8 BACK TO BLOCKY (owner, Nov 4: "back to the total blocky skins, with the blocky hands as well, but refined, the best it can look for blocky").
--   * The mesh-skin loader of v7 (ReplicatedStorage.SkinModels) is REMOVED. Skins are pure Studio code again, nothing to import.
--   * Every body part is ONE clean block the size of the real R15 part (the classic blocky avatar silhouette), outfit detail is built on top
--     from bigger, readable blocks + a few wedges: plates, pouches, straps, pads, cuffs, laces, helmet, hood, mask.
--   * BLOCK HANDS (mitten block, wrist cuff, knuckle plate, thumb block) on the character, the lobby figure AND in first person
--     (GunModels.HandParts / GadgetModels.BuildHand v8).
--   * Joint fillers (a 45 degree turned block on every elbow + knee pivot) so bent blocky limbs never open a gap.
--   * Layers never share a face with a different colour (each layer is a few % bigger than the one below), so nothing flickers.
--   * NO team-coloured / glowing parts (owner). Teammates + party members get an OUTLINE (TeamOutline). Only SOULBOUND's soul eyes + lantern glow.
-- The equipped skin is saved in the shared profile as "Skin" (ProfileStore DEFAULTS = "OPERATOR").
--   Skins.Order / Skins.ById / Skins.Default / Skins.Get(id) / Skins.Is(id)
--   Skins.Dress(character, skinId)               -> server: dresses a real Roblox character (lobby + match). (3rd argument = old team accent, ignored)
--   Skins.NewFigure(parent, skinId, opts)        -> client: a posed showcase figure (lobby menus / ViewportFrames / cutscenes)
--       opts = { weapon = "VX9", camPos = Vector3, idle = true, still = true, static = true } (unchanged)
--       figure:SetRoot(cframe), figure:Update(t, dt), figure:Destroy(), figure.HeadTop, figure.run / runPhase / sit
--   Skins.Proportions / Skins.ApplyProportions(character) / Skins.Prepare(character) (unchanged)
-- Adding a skin: entry in Skins.List (colors) + DRESS[id](B, Z, C, opt) built from the block kit K (see "THE BLOCK KIT" + "OUTFITS" below).
local RS = game:GetService("ReplicatedStorage")

local S = {}
local rgb = Color3.fromRGB

local BREAKLINE_RED = rgb(226, 38, 48)

S.List = {
	{
		id = "OPERATOR", name = "OPERATOR", sub = "Standard issue", card = rgb(214, 40, 46),
		desc = "Ballistic helmet, plate carrier, drop-leg holster and high-tops. What every recruit starts with.",
		colors = {
			-- v10 palette: 3 main colours (charcoal, coyote, olive) + one darker shade each, red only on the arm patch + the goggle clip
			Skin = rgb(196, 146, 112), SkinShade = rgb(168, 118, 88), Hair = rgb(36, 28, 24), Lip = rgb(150, 96, 80), Eye = rgb(52, 38, 30),
			Top = rgb(52, 55, 62), TopDark = rgb(34, 36, 42), Shirt = rgb(150, 152, 156), Pants = rgb(86, 92, 72), PantsDark = rgb(64, 69, 54),
			Shoe = rgb(34, 36, 42), Sole = rgb(232, 230, 222), Strap = rgb(20, 20, 24), Metal = rgb(176, 180, 186), Pad = rgb(34, 36, 42),
			Helmet = rgb(140, 120, 90), HelmetDark = rgb(108, 92, 68), Carrier = rgb(140, 120, 90), CarrierDark = rgb(108, 92, 68),
			Gaiter = rgb(86, 92, 72), GaiterDark = rgb(64, 69, 54), Lens = rgb(26, 28, 34), Tape = rgb(206, 200, 184),
			PadLight = rgb(70, 72, 80), Lace = rgb(46, 46, 52), Gun = rgb(30, 31, 34),
			-- old keys (menus / GunModels hands still read some of these)
			Suit = rgb(52, 55, 62), Under = rgb(86, 92, 72), Armor = rgb(140, 120, 90), Trim = rgb(20, 20, 24), Accent = BREAKLINE_RED,
			Plate = rgb(140, 120, 90), Cloth = rgb(52, 55, 62), Glove = rgb(26, 26, 30), Brand = BREAKLINE_RED, White = rgb(232, 232, 228),
		},
	},
	{
		id = "SOULBOUND", name = "SOULBOUND", sub = "Carries the dead", card = rgb(96, 170, 230),
		desc = "A long hooded coat, a bone mask and a lantern that burns with every soul you take.",
		colors = {
			-- v10 palette: navy coat + bone + near-black leather; the soul glow is the only accent (mask eyes + lantern)
			Skin = rgb(150, 140, 136), SkinShade = rgb(120, 110, 108), Hair = rgb(20, 22, 30), Lip = rgb(90, 80, 80), Eye = rgb(18, 18, 22),
			Top = rgb(32, 40, 58), TopDark = rgb(20, 25, 38), Shirt = rgb(186, 178, 156), Pants = rgb(20, 25, 38), PantsDark = rgb(14, 17, 26),
			Shoe = rgb(26, 24, 26), Sole = rgb(26, 24, 26), Strap = rgb(26, 24, 26), Metal = rgb(150, 156, 170), Pad = rgb(32, 40, 58),
			Bone = rgb(228, 222, 204), BoneShade = rgb(186, 178, 156), Wrap = rgb(228, 222, 204), Soul = rgb(120, 205, 255),
			Suit = rgb(32, 40, 58), Under = rgb(20, 25, 38), Armor = rgb(228, 222, 204), Trim = rgb(26, 24, 26), Accent = rgb(120, 205, 255),
			Plate = rgb(228, 222, 204), Cloth = rgb(32, 40, 58), Glove = rgb(228, 222, 204), Brand = rgb(120, 205, 255), White = rgb(236, 232, 218),
		},
	},
	{
		id = "CHASSIS", name = "CHASSIS", sub = "Wall crew unit", card = rgb(224, 116, 40),
		desc = "A scuffed steel work-frame with a screen face, built to push walls. Still running.",
		colors = {
			-- palette: steel + graphite + safety orange (+ one darker shade each), warm screen glow as the only accent
			Skin = rgb(158, 166, 176), SkinShade = rgb(110, 117, 128), Hair = rgb(48, 52, 60), Lip = rgb(48, 52, 60), Eye = rgb(30, 33, 39),
			Top = rgb(158, 166, 176), TopDark = rgb(110, 117, 128), Shirt = rgb(48, 52, 60), Pants = rgb(48, 52, 60), PantsDark = rgb(30, 33, 39),
			Shoe = rgb(48, 52, 60), Sole = rgb(110, 117, 128), Strap = rgb(30, 33, 39), Metal = rgb(158, 166, 176), Pad = rgb(48, 52, 60),
			Steel = rgb(158, 166, 176), SteelDark = rgb(110, 117, 128), Graphite = rgb(48, 52, 60), GraphiteDark = rgb(30, 33, 39),
			Orange = rgb(224, 116, 40), OrangeDark = rgb(170, 82, 26), Glow = rgb(255, 224, 140),
			Suit = rgb(158, 166, 176), Under = rgb(48, 52, 60), Armor = rgb(110, 117, 128), Trim = rgb(30, 33, 39), Accent = rgb(255, 224, 140),
			Plate = rgb(224, 116, 40), Cloth = rgb(48, 52, 60), Glove = rgb(48, 52, 60), Brand = rgb(224, 116, 40), White = rgb(236, 236, 232),
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
-- BUILDER (v8 BLOCKY). Every piece is a block (or a wedge) described relative to the CENTRE of an R15 body part ("base").
-- Front of a Roblox character = -Z, right = +X, up = +Y (the same for both sides: on the LEFT arm +X still points to the character's right).
--   B.blk(base, size, pos, col, mat, rotDeg)   plain block at `pos` (Vector3), optional rotation in DEGREES (Vector3, X then Y then Z)
--   B.wdg(base, size, pos, col, mat, rotDeg)   wedge (Roblox WedgePart: full height at +Z, slope falls to the front, -Z)
--   B.box(base, size, cf, col, mat)            block with a full CFrame (old API, still used by the plumbing)
-- The emitter decides what happens with it: weld to the real rig (Dress) or record for the figure (NewFigure).
-- =====================================================================================
local SP, METAL, NEON, FABRIC, GLASS = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Neon, Enum.Material.Fabric, Enum.Material.Glass
local LEATHER = Enum.Material.Leather
local CFn, V3 = CFrame.new, Vector3.new
local rad = math.rad

local function rotCF(pos, r)
	if r then return CFn(pos) * CFrame.Angles(rad(r.X), rad(r.Y), rad(r.Z)) end
	return CFn(pos)
end

local function newBuilder(emit)
	local B = {}
	function B.box(base, size, cf, col, mat) emit(base, "box", size, cf, col, mat) end
	function B.ell(base, size, cf, col, mat) emit(base, "ell", size, cf, col, mat) end
	function B.blk(base, size, pos, col, mat, r) emit(base, "box", size, rotCF(pos, r), col, mat) end
	function B.wdg(base, size, pos, col, mat, r) emit(base, "wedge", size, rotCF(pos, r), col, mat) end
	return B
end

-- joint positions inside each R15 part (fractions of the part size, from the stock R15 rig attachments)
local J = {}
function J.ua(a) return { sh = V3(0, a.Y * 0.335, 0), el = V3(0, -a.Y * 0.286, 0) } end
function J.la(l) return { el = V3(0, l.Y * 0.246, 0), wr = V3(0, -l.Y * 0.476, 0) } end
function J.ul(u) return { hip = V3(0, u.Y * 0.345, 0), kn = V3(0, -u.Y * 0.329, 0) } end
function J.ll(l) return { kn = V3(0, l.Y * 0.334, 0), an = V3(0, -l.Y * 0.459, 0) } end

-- =====================================================================================
-- THE BLOCK KIT (K). v8 = back to the classic blocky Roblox body, done properly:
--   * every body part is ONE clean block the size of the real R15 part (so the silhouette is the classic blocky avatar), layers on top of it
--     are a little bigger than the layer below (no two different colours ever share a face = no flicker), detail is big, readable blocks
--     (plates, pouches, straps, pads, cuffs, laces) in 2-4 tones per material, never tiny noise.
--   * BLOCK HANDS: a mitten block per hand (wrist cuff, knuckle plate, thumb block), the same in first person (GunModels.HandParts).
--   * JOINT FILLERS: a 45 degree turned block on every elbow + knee pivot, so a bent blocky limb never shows a gap or a hollow corner.
--   * HEAD: a slightly rounded-off cube (bevel blocks on the vertical edges) with a block face (brows, eyes with a highlight, nose).
-- Sizes are fractions of the real part sizes (Z[part]) or studs * Z.u, so the lobby figure (FIG_SCALE) matches the player exactly.
-- =====================================================================================
local K = {}

-- the head cube edge (the R15 head part is 2 x 1 x 1; the visible stock head is 1.2 x its depth)
local function headCube(Z) return Z.h * 0.94 end

function K.head(B, Z, skinCol, o)
	o = o or {}
	local h = headCube(Z)
	local hm = o.mat or SP -- v10: a skin may build its head from another material (CHASSIS = Metal)
	B.blk("Head", V3(h * 0.92, h, h * 0.92), V3(0, 0, 0), skinCol, hm)
	-- bevelled vertical edges: the cube reads as a head, not a crate
	B.blk("Head", V3(h, h * 0.94, h * 0.84), V3(0, -h * 0.01, 0), skinCol, hm)
	B.blk("Head", V3(h * 0.84, h * 0.94, h), V3(0, -h * 0.01, 0), skinCol, hm)
	if o.face ~= false then
		local f = -h * 0.5 -- front face
		local eyeY = o.eyeY or h * 0.05
		for _, sg in { -1, 1 } do
			B.blk("Head", V3(h * 0.13, h * 0.16, h * 0.03), V3(sg * h * 0.19, eyeY, f - h * 0.005), o.eye, SP)
			B.blk("Head", V3(h * 0.045, h * 0.05, h * 0.03), V3(sg * h * 0.19 + h * 0.035, eyeY + h * 0.04, f - h * 0.012), o.white, SP)
			if o.brow then
				B.blk("Head", V3(h * 0.22, h * 0.055, h * 0.035), V3(sg * h * 0.2, eyeY + h * 0.13, f - h * 0.008), o.brow, SP, V3(0, 0, -sg * 6))
			end
			if o.ear then
				B.blk("Head", V3(h * 0.06, h * 0.2, h * 0.16), V3(sg * h * 0.52, -h * 0.02, h * 0.04), o.ear, SP)
			end
		end
		if o.nose then B.blk("Head", V3(h * 0.11, h * 0.15, h * 0.07), V3(0, -h * 0.07, f - h * 0.03), o.nose, SP) end
		if o.mouth then B.blk("Head", V3(h * 0.22, h * 0.04, h * 0.03), V3(0, -h * 0.25, f - h * 0.005), o.mouth, SP) end
	end
	return h
end

-- one body part as a block with CHAMFERED vertical edges (two crossing blocks, the same 7% bevel on every body part and the head, so
-- the whole figure shares one edge language). grow > 1 for outer garment layers.
K.BEVEL = 0.07
function K.core(B, Z, base, col, mat, grow, gy)
	local s = Z[base]
	if not s then return end
	grow = grow or 1
	local x, y, z = s.X * grow, s.Y * (gy or 1), s.Z * grow
	local c = math.min(x, z) * K.BEVEL
	B.blk(base, V3(x, y, z - c * 2), V3(0, 0, 0), col, mat)
	B.blk(base, V3(x - c * 2, y, z), V3(0, 0, 0), col, mat)
end

-- band round a part (cuffs, belts, straps): y = centre height inside the part
function K.band(B, Z, base, y, h, col, mat, grow)
	local s = Z[base]
	grow = grow or 1.06
	B.blk(base, V3(s.X * grow, h, s.Z * grow), V3(0, y, 0), col, mat)
end

-- 45 degree turned block on the elbow / knee pivot (rides on the upper segment)
function K.fillers(B, Z, col, mat, legCol, legMat)
	for _, side in { "Left", "Right" } do
		local ua = Z[side .. "UpperArm"]
		if ua then
			local d = ua.Z * 0.66
			B.blk(side .. "UpperArm", V3(ua.X * 0.96, d, d), J.ua(ua).el, col, mat, V3(45, 0, 0))
		end
		local ul = Z[side .. "UpperLeg"]
		if ul then
			local d = ul.Z * 0.66
			B.blk(side .. "UpperLeg", V3(ul.X * 0.96, d, d), J.ul(ul).kn, legCol or col, legMat or mat, V3(45, 0, 0))
		end
	end
end

-- BLOCK HAND v9: a SLIM glove block (narrower + shallower than the sleeve, so a held gun stays visible), a wrist cuff that bridges
-- the sleeve to the glove, a knuckle plate on the back of the hand and a thumb block on the front. Same on the character + the figure.
K.HAND = { w = 0.66, d = 0.62, len = 1.4 } -- glove block = hand part X * w, Z * d, Y * len (the old v8 mitten was 1.02 x 0.94 x 1.7)
function K.hand(B, Z, side, glove, pad, cuff, o)
	o = o or {}
	local base = side .. "Hand"
	local s = Z[base]
	if not s then return end
	local u = Z.u
	local sg = side == "Right" and 1 or -1
	local gw, gd, gl = s.X * K.HAND.w, s.Z * K.HAND.d, s.Y * K.HAND.len
	local top = s.Y * 0.5
	B.blk(base, V3(s.X * 0.8, 0.12 * u, s.Z * 0.8), V3(0, top - 0.02 * u, 0), cuff or pad, o.cuffMat or SP)                 -- cuff
	local gy = top - 0.08 * u - gl * 0.5
	B.blk(base, V3(gw, gl, gd), V3(0, gy, 0), glove, o.mat or SP)                                                            -- glove
	B.blk(base, V3(0.04 * u, gl * 0.42, gd * 0.8), V3(sg * (gw * 0.5 + 0.02 * u), gy - gl * 0.12, 0), pad, SP)              -- knuckle plate
	B.blk(base, V3(gw * 0.34, gl * 0.5, 0.09 * u), V3(-sg * gw * 0.24, gy + gl * 0.06, -gd * 0.5 - 0.045 * u), glove, o.mat or SP) -- thumb
end

-- BOOT: shaft on the lower leg, foot block with a toe that sticks out, sole, toe slope, heel, laces
function K.boot(B, Z, side, shoe, sole, lace, o)
	o = o or {}
	local u = Z.u
	local ll, ft = side .. "LowerLeg", side .. "Foot"
	local L, F = Z[ll], Z[ft]
	if not L or not F then return end
	local shaftH = L.Y * (o.shaft or 0.4)
	B.blk(ll, V3(L.X * 1.07, shaftH, L.Z * 1.07), V3(0, -L.Y * 0.5 + shaftH * 0.5, 0), shoe, o.mat or SP)
	B.blk(ll, V3(L.X * 1.12, 0.09 * u, L.Z * 1.12), V3(0, -L.Y * 0.5 + shaftH, 0), o.collar or shoe, o.collarMat or SP)
	if lace then
		B.blk(ll, V3(L.X * 0.34, shaftH * 0.8, 0.03 * u), V3(0, -L.Y * 0.5 + shaftH * 0.48, -L.Z * 0.535 - 0.015 * u), lace, SP)
		for i = 0, 2 do
			B.blk(ll, V3(L.X * 0.44, 0.035 * u, 0.04 * u), V3(0, -L.Y * 0.5 + shaftH * (0.2 + i * 0.25), -L.Z * 0.55 - 0.02 * u), o.laceX or shoe, SP)
		end
	end
	local toe = F.Z * 0.22
	B.blk(ft, V3(F.X * 1.07, F.Y * 1.02, F.Z * 1.07 + toe), V3(0, 0, -toe * 0.5), shoe, o.mat or SP)
	B.wdg(ft, V3(F.X * 1.07, F.Y * 0.55, F.Z * 0.3), V3(0, F.Y * 0.775, -F.Z * 0.385 - toe * 0.5), shoe, o.mat or SP)
	B.blk(ft, V3(F.X * 1.12, 0.1 * u, F.Z * 1.12 + toe + 0.04 * u), V3(0, -F.Y * 0.5 + 0.05 * u, -toe * 0.5), sole, o.soleMat or SP)
	B.blk(ft, V3(F.X * 1.1, F.Y * 0.5, 0.12 * u), V3(0, -F.Y * 0.2, -F.Z * 0.535 - toe - 0.02 * u), o.toeCap or sole, o.soleMat or SP)
	B.blk(ft, V3(F.X * 1.09, F.Y * 0.6, 0.06 * u), V3(0, -F.Y * 0.1, F.Z * 0.535 + 0.03 * u), o.heel or sole, o.soleMat or SP)
end

-- =====================================================================================
-- OUTFITS. DRESS[id](B, Z, C, opt) - Z = part sizes (+ Z.u, Z.h), C = the skin colours, opt.noHands = the figure builds no hands.
-- =====================================================================================
local DRESS = {}

-- ---------------------------------------------------------------- OPERATOR (v10): helmet + goggles, gaiter, coyote plate carrier over a charcoal
-- jacket, olive cargos, drop-leg holster (right), knee pads, white-soled boots. Simple on purpose: ~90 parts, no tiny gear bits.
-- Palette: charcoal (jacket, boots) + coyote (helmet, carrier, pads) + olive (gaiter, trousers) + one darker shade each. Red = arm patch + goggle clip.
DRESS.OPERATOR = function(B, Z, C, opt)
	local u = Z.u
	-- HEAD
	local h = K.head(B, Z, C.Skin, { eye = C.Eye, white = C.White, brow = C.Hair, nose = C.SkinShade, eyeY = 0 })
	local hd = "Head"
	B.blk(hd, V3(h * 1.02, h * 0.36, h * 1.02), V3(0, -h * 0.33, 0), C.Gaiter, FABRIC)                  -- gaiter up to the nose
	B.blk(hd, V3(h * 1.1, h * 0.36, h * 1.12), V3(0, h * 0.36, h * 0.01), C.Helmet, SP)                  -- shell
	B.blk(hd, V3(h * 0.96, h * 0.1, h * 0.98), V3(0, h * 0.58, h * 0.01), C.Helmet, SP)                  -- crown
	B.blk(hd, V3(h * 1.13, h * 0.06, h * 1.15), V3(0, h * 0.2, h * 0.01), C.HelmetDark, SP)              -- brim band
	for _, sg in { -1, 1 } do
		B.blk(hd, V3(h * 0.08, h * 0.36, h * 0.56), V3(sg * h * 0.55, h * 0.06, h * 0.2), C.Helmet, SP)  -- side skirt over the ear
		B.blk(hd, V3(h * 0.34, h * 0.13, h * 0.04), V3(sg * h * 0.2, h * 0.31, -h * 0.66), C.Lens, GLASS) -- goggle lens
	end
	B.blk(hd, V3(h * 1.14, h * 0.07, h * 1.16), V3(0, h * 0.3, h * 0.01), C.Strap, SP)                    -- goggle strap round the shell
	B.blk(hd, V3(h * 0.86, h * 0.2, h * 0.1), V3(0, h * 0.31, -h * 0.6), C.Strap, SP)                     -- goggle frame
	B.blk(hd, V3(h * 0.1, h * 0.1, h * 0.05), V3(0, h * 0.31, -h * 0.67), C.Accent, SP)                   -- red clip

	-- TORSO: charcoal jacket, plate carrier (front + back bag, cummerbund, shoulder straps), 3 mag pouches under one flap
	local T = Z.UpperTorso
	local W, H, D = T.X, T.Y, T.Z
	K.core(B, Z, "UpperTorso", C.Top, FABRIC)
	local pz = D * 0.5 + 0.06 * u
	B.blk("UpperTorso", V3(W * 0.8, H * 0.6, 0.12 * u), V3(0, H * 0.06, -pz), C.Carrier, FABRIC)
	B.blk("UpperTorso", V3(W * 0.82, H * 0.62, 0.12 * u), V3(0, H * 0.08, pz), C.Carrier, FABRIC)
	B.blk("UpperTorso", V3(W * 1.02, H * 0.2, D * 1.04 + 0.12 * u), V3(0, -H * 0.18, 0), C.CarrierDark, FABRIC)
	for _, sg in { -1, 1 } do
		B.blk("UpperTorso", V3(W * 0.2, 0.08 * u, D + 0.26 * u), V3(sg * W * 0.27, H * 0.5 + 0.03 * u, 0), C.Carrier, FABRIC)
	end
	local my = -H * 0.06
	for i = -1, 1 do
		B.blk("UpperTorso", V3(W * 0.22, H * 0.24, 0.16 * u), V3(i * W * 0.25, my, -pz - 0.14 * u), C.Carrier, FABRIC)
	end
	B.blk("UpperTorso", V3(W * 0.74, H * 0.07, 0.18 * u), V3(0, my + H * 0.1, -pz - 0.15 * u), C.CarrierDark, FABRIC)

	-- LOWER TORSO: olive trousers, belt + buckle
	local LT = Z.LowerTorso
	K.core(B, Z, "LowerTorso", C.Pants, FABRIC, 1.02)
	B.blk("LowerTorso", V3(LT.X * 1.04, 0.17 * u, LT.Z * 1.06), V3(0, LT.Y * 0.18, 0), C.Strap, LEATHER)
	B.blk("LowerTorso", V3(0.24 * u, 0.13 * u, 0.04 * u), V3(0, LT.Y * 0.18, -LT.Z * 0.53 - 0.02 * u), C.Metal, METAL)

	-- ARMS: jacket sleeves, coyote elbow pad, charcoal cuff; the Breakline patch on the LEFT arm only
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local ua, la = side .. "UpperArm", side .. "LowerArm"
		local A, L = Z[ua], Z[la]
		K.core(B, Z, ua, C.Top, FABRIC)
		K.core(B, Z, la, C.Top, FABRIC)
		K.band(B, Z, la, L.Y * 0.5 - 0.17 * u, 0.34 * u, C.Carrier, FABRIC, 1.07)
		K.band(B, Z, la, -L.Y * 0.5 + 0.16 * u, 0.2 * u, C.TopDark, FABRIC, 1.07)
		if side == "Left" then
			local px = sg * (A.X * 0.5 + 0.008 * u)
			B.blk(ua, V3(0.03 * u, A.Y * 0.26, A.Z * 0.5), V3(px, A.Y * 0.14, 0), C.Accent, SP)
			B.blk(ua, V3(0.04 * u, A.Y * 0.045, A.Z * 0.2), V3(px - 0.006 * u, A.Y * 0.17, -A.Z * 0.11), C.White, SP)  -- the "break line" mark:
			B.blk(ua, V3(0.04 * u, A.Y * 0.045, A.Z * 0.2), V3(px - 0.006 * u, A.Y * 0.11, A.Z * 0.11), C.White, SP)   -- two offset bars
		end
		if not opt.noHands then K.hand(B, Z, side, C.Glove, C.Pad, C.Pad) end
	end

	-- LEGS: olive cargos, cargo pocket (left), drop-leg holster (right), coyote knee pads, boots with white soles
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local ul, ll = side .. "UpperLeg", side .. "LowerLeg"
		local U, L = Z[ul], Z[ll]
		K.core(B, Z, ul, C.Pants, FABRIC)
		K.core(B, Z, ll, C.Pants, FABRIC)
		local ox = sg * (U.X * 0.5 + 0.06 * u)
		if side == "Left" then
			B.blk(ul, V3(0.12 * u, U.Y * 0.34, U.Z * 0.56), V3(ox, -U.Y * 0.08, 0), C.PantsDark, FABRIC)
		else
			B.blk(ul, V3(0.12 * u, U.Y * 0.46, U.Z * 0.5), V3(ox, -U.Y * 0.06, U.Z * 0.04), C.Strap, LEATHER)                       -- holster
			B.blk(ul, V3(0.12 * u, 0.3 * u, 0.2 * u), V3(ox + 0.04 * u, U.Y * 0.17 + 0.15 * u, U.Z * 0.12), C.Gun, SP)             -- pistol grip
			K.band(B, Z, ul, -U.Y * 0.2, 0.07 * u, C.Strap, LEATHER, 1.05)                                                         -- leg strap
		end
		B.blk(ll, V3(L.X * 0.78, 0.4 * u, 0.12 * u), J.ll(L).kn + V3(0, 0, -L.Z * 0.5 - 0.06 * u), C.Carrier, FABRIC)            -- knee pad
		K.boot(B, Z, side, C.Shoe, C.Sole, nil, { collar = C.Pad, heel = C.Shoe })
	end
	K.fillers(B, Z, C.Top, FABRIC, C.Pants, FABRIC)
end

-- ---------------------------------------------------------------- SOULBOUND (v10): "a pallbearer". Deep hood, bone mask with soul-lit eyes, long navy
-- coat with a split tail, one bone bandolier, a bone pauldron (left) and a soul lantern (right). ~100 parts.
-- Palette: navy (coat) + bone (mask, pauldron, charms, wraps) + near-black leather; the soul glow (mask eyes + lantern) is the only accent.
DRESS.SOULBOUND = function(B, Z, C, opt)
	local u = Z.u
	local hd = "Head"
	-- HEAD: the face is the hood's shadow; the mask sits in it
	local h = K.head(B, Z, C.Hair, { face = false })
	B.blk(hd, V3(h * 1.24, h * 0.14, h * 1.24), V3(0, h * 0.56, h * 0.02), C.Top, FABRIC)                  -- crown
	for _, sg in { -1, 1 } do
		B.blk(hd, V3(h * 0.14, h * 1.1, h * 1.24), V3(sg * h * 0.55, -h * 0.02, h * 0.02), C.Top, FABRIC)  -- sides
	end
	B.blk(hd, V3(h * 1.24, h * 1.16, h * 0.14), V3(0, 0, h * 0.58), C.Top, FABRIC)                         -- back
	B.blk(hd, V3(h * 1.24, h * 0.2, h * 0.24), V3(0, h * 0.48, -h * 0.6), C.Top, FABRIC)                   -- peak
	-- mask
	local f = -h * 0.5
	B.blk(hd, V3(h * 0.74, h * 0.82, h * 0.08), V3(0, -h * 0.04, f - h * 0.02), C.Bone, SP)                 -- plate
	B.blk(hd, V3(h * 0.62, h * 0.12, h * 0.08), V3(0, h * 0.3, f - h * 0.05), C.Bone, SP)                   -- brow ridge
	for _, sg in { -1, 1 } do
		B.blk(hd, V3(h * 0.2, h * 0.14, h * 0.03), V3(sg * h * 0.17, h * 0.14, f - h * 0.065), C.Eye, SP)   -- socket
		B.blk(hd, V3(h * 0.08, h * 0.08, h * 0.03), V3(sg * h * 0.17, h * 0.14, f - h * 0.075), C.Soul, NEON) -- soul glow
	end
	B.blk(hd, V3(h * 0.4, h * 0.12, h * 0.03), V3(0, -h * 0.3, f - h * 0.065), C.Eye, SP)                   -- mouth
	for i = -1, 1 do
		B.blk(hd, V3(h * 0.04, h * 0.13, h * 0.04), V3(i * h * 0.1, -h * 0.3, f - h * 0.07), C.Bone, SP)    -- three stitches
	end
	B.blk(hd, V3(h * 0.03, h * 0.14, h * 0.03), V3(-h * 0.17, h * 0.33, f - h * 0.095), C.Eye, SP)          -- crack over the left eye
	B.blk(hd, V3(h * 0.08, h * 0.03, h * 0.03), V3(-h * 0.2, h * 0.27, f - h * 0.095), C.Eye, SP)

	-- TORSO: navy coat, bone collar V, two lapels, mantle, ONE bandolier (front + back) with three bone charms
	local T = Z.UpperTorso
	local W, H, D = T.X, T.Y, T.Z
	K.core(B, Z, "UpperTorso", C.Top, FABRIC)
	B.blk("UpperTorso", V3(W * 0.3, H * 0.4, 0.03 * u), V3(0, H * 0.28, -D * 0.5 - 0.015 * u), C.Shirt, FABRIC)
	for _, sg in { -1, 1 } do
		B.blk("UpperTorso", V3(W * 0.12, H * 0.5, 0.07 * u), V3(sg * W * 0.21, H * 0.25, -D * 0.5 - 0.035 * u), C.TopDark, FABRIC)
	end
	B.blk("UpperTorso", V3(W * 1.08, 0.24 * u, D * 1.12), V3(0, H * 0.5 - 0.06 * u, 0), C.TopDark, FABRIC)
	B.blk("UpperTorso", V3(0.16 * u, H * 1.18, 0.06 * u), V3(0, 0, -D * 0.5 - 0.1 * u), C.Strap, LEATHER, V3(0, 0, 45))
	B.blk("UpperTorso", V3(0.16 * u, H * 1.18, 0.06 * u), V3(0, 0, D * 0.5 + 0.1 * u), C.Strap, LEATHER, V3(0, 0, -45))
	for i = -1, 1 do
		local t = i * H * 0.28
		B.blk("UpperTorso", V3(0.11 * u, 0.15 * u, 0.06 * u), V3(-math.sin(rad(45)) * t, math.cos(rad(45)) * t, -D * 0.5 - 0.15 * u), C.Bone, SP, V3(0, 0, 45))
	end

	-- LOWER TORSO: coat skirt top, belt, split coat tail (front pair + back), lantern on the front-right of the belt
	local LT = Z.LowerTorso
	K.core(B, Z, "LowerTorso", C.Top, FABRIC, 1.02)
	B.blk("LowerTorso", V3(LT.X * 1.05, 0.15 * u, LT.Z * 1.07), V3(0, LT.Y * 0.12, 0), C.Strap, LEATHER)
	B.blk("LowerTorso", V3(0.2 * u, 0.14 * u, 0.04 * u), V3(-LT.X * 0.12, LT.Y * 0.12, -LT.Z * 0.535 - 0.02 * u), C.Metal, METAL)
	local tailH = 1.25 * u
	local ty = -LT.Y * 0.5 - tailH * 0.5 + 0.06 * u
	for _, sg in { -1, 1 } do
		B.blk("LowerTorso", V3(LT.X * 0.44, tailH, 0.07 * u), V3(sg * LT.X * 0.27, ty, -LT.Z * 0.5 - 0.05 * u), C.Top, FABRIC)
	end
	B.blk("LowerTorso", V3(LT.X * 1.06, tailH + 0.08 * u, 0.07 * u), V3(0, ty - 0.04 * u, LT.Z * 0.5 + 0.05 * u), C.Top, FABRIC)
	local lp = V3(LT.X * 0.36, -0.45 * u, -LT.Z * 0.5 - 0.19 * u)
	B.blk("LowerTorso", V3(0.05 * u, 0.05 * u, 0.22 * u), V3(lp.X, LT.Y * 0.12, -LT.Z * 0.5 - 0.09 * u), C.Metal, METAL) -- bracket off the belt
	B.blk("LowerTorso", V3(0.04 * u, 0.32 * u, 0.04 * u), V3(lp.X, LT.Y * 0.12 - 0.14 * u, lp.Z), C.Metal, METAL)       -- hanger
	B.blk("LowerTorso", V3(0.3 * u, 0.06 * u, 0.3 * u), lp + V3(0, 0.2 * u, 0), C.Metal, METAL)                          -- cap
	B.blk("LowerTorso", V3(0.3 * u, 0.06 * u, 0.3 * u), lp + V3(0, -0.2 * u, 0), C.Metal, METAL)                         -- base
	B.blk("LowerTorso", V3(0.22 * u, 0.34 * u, 0.22 * u), lp, C.Soul, GLASS)
	B.blk("LowerTorso", V3(0.09 * u, 0.15 * u, 0.09 * u), lp, C.Soul, NEON)

	-- ARMS: coat sleeves, dark cuffs, bone pauldron on the LEFT shoulder, bandage-wrapped hands
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local ua, la = side .. "UpperArm", side .. "LowerArm"
		local A, L = Z[ua], Z[la]
		K.core(B, Z, ua, C.Top, FABRIC)
		K.core(B, Z, la, C.Top, FABRIC)
		K.band(B, Z, la, -L.Y * 0.5 + 0.2 * u, 0.26 * u, C.TopDark, FABRIC, 1.1)
		if side == "Left" then
			B.blk(ua, V3(A.X * 1.24, 0.2 * u, A.Z * 1.24), V3(sg * 0.05 * u, A.Y * 0.5, 0), C.Bone, SP)
			B.blk(ua, V3(A.X * 1.16, 0.18 * u, A.Z * 1.16), V3(sg * 0.05 * u, A.Y * 0.5 - 0.2 * u, 0), C.BoneShade, SP)
			B.wdg(ua, V3(0.1 * u, 0.26 * u, 0.22 * u), V3(sg * A.X * 0.3, A.Y * 0.5 + 0.23 * u, 0), C.Bone, SP, V3(0, 90 * sg, 0))
		end
		if not opt.noHands then K.hand(B, Z, side, C.Wrap, C.BoneShade, C.TopDark, { mat = FABRIC }) end
	end

	-- LEGS: dark trousers, two bone shin wraps, tall leather boots
	for _, side in { "Left", "Right" } do
		local ul, ll = side .. "UpperLeg", side .. "LowerLeg"
		local L = Z[ll]
		K.core(B, Z, ul, C.Pants, FABRIC)
		K.core(B, Z, ll, C.Pants, FABRIC)
		for i = 0, 1 do
			B.blk(ll, V3(L.X * 1.06, 0.12 * u, L.Z * 1.06), V3(0, L.Y * 0.28 - i * 0.22 * u, 0), C.Wrap, FABRIC)
		end
		K.boot(B, Z, side, C.Shoe, C.Sole, nil, { shaft = 0.36, collar = C.Strap, collarMat = LEATHER, toeCap = C.Shoe, heel = C.Shoe, mat = LEATHER })
	end
	K.fillers(B, Z, C.Top, FABRIC, C.Pants, FABRIC)
end

-- ---------------------------------------------------------------- CHASSIS (v10, NEW): "a worn wall-crew robot". A boxy steel head with a dark screen face and
-- two warm glowing eyes (the box robots of Wall Push, grown up), graphite joints, one safety-orange chest panel + left shoulder cap, a back pack
-- with an orange stripe, an antenna on the right. Palette: steel + graphite + orange, each with one darker shade; the screen glow is the only accent.
DRESS.CHASSIS = function(B, Z, C, opt)
	local u = Z.u
	local hd = "Head"
	-- HEAD
	local h = K.head(B, Z, C.Steel, { face = false, mat = METAL })
	B.blk(hd, V3(h * 0.8, h * 0.56, h * 0.06), V3(0, h * 0.02, -h * 0.515), C.GraphiteDark, SP)               -- screen
	for _, sg in { -1, 1 } do
		B.blk(hd, V3(h * 0.15, h * 0.2, h * 0.04), V3(sg * h * 0.2, h * 0.06, -h * 0.555), C.Glow, NEON)       -- eyes
		B.blk(hd, V3(h * 0.14, h * 0.34, h * 0.34), V3(sg * (h * 0.5 + h * 0.06), 0, h * 0.05), C.Graphite, SP) -- ear module
	end
	B.blk(hd, V3(h * 0.9, h * 0.07, h * 0.9), V3(0, h * 0.5 + h * 0.02, 0), C.SteelDark, METAL)               -- cap plate
	B.blk(hd, V3(h * 0.06, h * 0.16, h * 0.06), V3(h * 0.28, h * 0.5 + h * 0.1, h * 0.1), C.Graphite, SP)     -- antenna (right)
	B.blk(hd, V3(h * 0.1, h * 0.08, h * 0.1), V3(h * 0.28, h * 0.5 + h * 0.22, h * 0.1), C.Orange, SP)

	-- TORSO: steel chest, orange panel, graphite grille, back pack with an orange stripe
	local T = Z.UpperTorso
	local W, H, D = T.X, T.Y, T.Z
	K.core(B, Z, "UpperTorso", C.Steel, METAL)
	B.blk("UpperTorso", V3(W * 0.34, 0.14 * u, D * 0.5), V3(0, H * 0.5 + 0.02 * u, 0), C.Graphite, SP)         -- neck ring
	B.blk("UpperTorso", V3(W * 0.72, H * 0.46, 0.1 * u), V3(0, H * 0.12, -D * 0.5 - 0.05 * u), C.Orange, SP)   -- chest panel
	B.blk("UpperTorso", V3(W * 0.44, H * 0.14, 0.06 * u), V3(0, -H * 0.22, -D * 0.5 - 0.03 * u), C.Graphite, SP) -- grille
	B.blk("UpperTorso", V3(W * 0.62, H * 0.62, 0.22 * u), V3(0, H * 0.06, D * 0.5 + 0.11 * u), C.Graphite, SP)  -- pack
	B.blk("UpperTorso", V3(W * 0.4, H * 0.08, 0.26 * u), V3(0, H * 0.2, D * 0.5 + 0.13 * u), C.Orange, SP)      -- stripe

	-- LOWER TORSO: graphite waist, steel-dark hip band, hip pods
	local LT = Z.LowerTorso
	K.core(B, Z, "LowerTorso", C.Graphite, SP, 1.02)
	B.blk("LowerTorso", V3(LT.X * 1.06, 0.12 * u, LT.Z * 1.08), V3(0, LT.Y * 0.1, 0), C.SteelDark, METAL)
	for _, sg in { -1, 1 } do
		B.blk("LowerTorso", V3(0.16 * u, LT.Y * 0.9, LT.Z * 0.7), V3(sg * (LT.X * 0.5 + 0.08 * u), -LT.Y * 0.04, 0), C.Graphite, SP)
	end

	-- ARMS: steel upper arm + shoulder cap (ORANGE on the left, steel-dark on the right), steel-dark forearm, graphite wrist band + glove
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local ua, la = side .. "UpperArm", side .. "LowerArm"
		local A, L = Z[ua], Z[la]
		K.core(B, Z, ua, C.Steel, METAL)
		B.blk(ua, V3(A.X * 1.2, 0.26 * u, A.Z * 1.2), V3(sg * 0.04 * u, A.Y * 0.5 - 0.02 * u, 0), side == "Left" and C.Orange or C.SteelDark, side == "Left" and SP or METAL)
		K.core(B, Z, la, C.SteelDark, METAL)
		K.band(B, Z, la, -L.Y * 0.5 + 0.2 * u, 0.28 * u, C.Graphite, SP, 1.1)
		if not opt.noHands then K.hand(B, Z, side, C.Graphite, C.Steel, C.SteelDark) end
	end

	-- LEGS: graphite thighs, steel-dark shins with an orange stripe + knee guard, graphite boots
	for _, side in { "Left", "Right" } do
		local ul, ll = side .. "UpperLeg", side .. "LowerLeg"
		local L = Z[ll]
		K.core(B, Z, ul, C.Graphite, SP)
		K.core(B, Z, ll, C.SteelDark, METAL)
		B.blk(ll, V3(L.X * 0.8, 0.3 * u, 0.1 * u), J.ll(L).kn + V3(0, 0, -L.Z * 0.5 - 0.05 * u), C.Steel, METAL)   -- knee guard
		K.band(B, Z, ll, -L.Y * 0.08, 0.12 * u, C.Orange, SP, 1.06)                                               -- shin stripe
		K.boot(B, Z, side, C.Graphite, C.SteelDark, nil, { collar = C.SteelDark, toeCap = C.SteelDark, heel = C.Graphite })
	end
	K.fillers(B, Z, C.Graphite, SP, C.Graphite, SP)
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
S._K = K

local function makeShell(kind, size, color, mat)
	local p = Instance.new(kind == "wedge" and "WedgePart" or "Part")
	p.Name = "Shell"
	if kind == "cyl" then p.Shape = Enum.PartType.Cylinder end
	p.Size = V3(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.Color = color
	p.Material = mat or SP
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = size.Magnitude > 0.6 and mat ~= NEON and mat ~= GLASS
	if mat == GLASS then p.Transparency = 0.15 end
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
S._scaledStock = scaledStock

S.GunPose = {
	base = Vector3.new(-0.15, 0, 0.6),
	aim = { rot = Vector3.new(-0.15, -0.75, 0), pos = Vector3.new(0.6, 0.5, -0.3) },
	inspect = { rot = Vector3.new(-0.35, 0.35, 0.9), pos = Vector3.new(0, 0.7, 0.3) },
	low = { rot = Vector3.new(0.5, 0.2, 0.1), pos = Vector3.new(-0.2, -0.25, 0.2) },
}

-- figure gun hold v9 ("showcase ready"): the gun is held ACROSS the chest, muzzle forward-left and a little down, so the camera sees the
-- side of the gun instead of looking down the barrel. Gloves sit just under the gun (dropR / dropL). Gun at 0.8 = the in-game world gun size.
-- Tuned offline against all 10 guns + every idle pose: both hands reach, nothing is buried in the body, ~60% of a rifle is visible
-- from the front (v8 was ~13%: the big mitten hands + a muzzle-to-camera pose hid it).
S.FigureTune = { gunScale = 0.8, gripX = -0.4, gripY = -0.05, gripZ = 0.6, dirX = 1.3, dirY = -0.5, blade = -0.25, dropR = 0.2, dropL = 0.18 }

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
	-- v8: holding a gun the shoulders sit a little closer than in-game (both block hands reach every gun); empty-handed = the real rig width
	local Z = { u = (sz.UpperTorso.Y / 1.792), h = math.min(sz.Head.Y, sz.Head.Z) * 1.2,
		shX = sz.UpperTorso.X * 0.5 + sz.RightUpperArm.X * (opts.weapon and 0.15 or 0.5) }
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
	DRESS[skin.id](B, Z, c, {}) -- v8: the block hands are part of the outfit (they ride on the forearm, see Update)

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
	-- wrist -> glove centre along the forearm (hand part sits 0.417 * Y below the wrist, the glove block hangs below that, see K.hand)
	local hs = sz.RightHand
	local GLOVE_REACH = hs.Y * 0.417 + (K.HAND.len * hs.Y * 0.5 + 0.08 * Z.u - hs.Y * 0.5)

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
		-- v9: the glove centres sit just UNDER the gun (fist round the pistol grip, palm cupping the handguard), not on top of it
		local up = rot * Vector3.yAxis
		rHand = rHand - up * FT.dropR * k
		lHand = lHand - up * FT.dropL * k
	else
		-- no weapon: arms hang straight down at the sides (the block hands sit on the forearms)
		rHand = Vector3.new(-Z.shX, rest.RightHand.Y - 0.1 * k, 0)
		lHand = Vector3.new(Z.shX, rest.LeftHand.Y - 0.1 * k, 0)
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
			local wrist = hRig + (sh - hRig).Unit * (hasGun and GLOVE_REACH or 0)
			local pole = V3(sg * 0.8, -1, 0.35)
			local elbow, wr = ik(sh, wrist, pole)
			if fig._debug then fig._debug[side] = (wr - wrist).Magnitude end
			local side3 = V3(sg, 0, 0)
			base[side .. "UpperArm"] = placeAlong(sh, elbow, UA_SH(sg), UA_EL, side3)
			base[side .. "LowerArm"] = placeAlong(elbow, wr, LA_EL, LA_WR, side3)
			base[side .. "Hand"] = base[side .. "LowerArm"] * CFrame.new(LA_WR) * CFrame.new(0, -sz.RightHand.Y * 0.417, 0)
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
	fig._pose, fig._list, fig._gun = pose, list, gunList
	fig:Update(0, 0)
	return fig
end

return S
