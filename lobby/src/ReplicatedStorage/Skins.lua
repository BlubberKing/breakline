-- Skins v11.2 (v5.18: Skins.ViewArms(skinId) = glove / cuff / sleeve colours for the first-person arms) (v11.1 v5.16: figures can hold a POSE - opts.pose / figure.pose, see the Poses module) (ModuleScript in ReplicatedStorage) - used by BOTH games (Lobby + Breakline). Keep the two copies identical.
-- v11 (Nov 7): ALL THREE OUTFITS REBUILT with real detail (OPERATOR ~160 parts, SOULBOUND ~154, CHASSIS ~118), new kit pieces (K.pouch / K.sidePouch, B.cyl for robots),
--   colourway EDITIONS for the cosmetics shop (S.List entries with `base` + `price`; S.Price / S.IsFree), figure option opts.gunSkin (shows the equipped gun skin).
-- v9 (Nov 4): slim glove hands, showcase gun hold across the chest (gun visible in menus), chamfered body blocks, OPERATOR + SOULBOUND polish, see GDD 5.4 + 5.4d SKIN QUALITY STANDARD.
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
--       opts = { weapon = "VX9", gunSkin = "VX9_GILT", camPos = Vector3, idle = true, still = true, static = true } (v11: gunSkin = a GunSkins id painted on the held gun)
--       figure:SetRoot(cframe), figure:Update(t, dt), figure:Destroy(), figure.HeadTop, figure.run / runPhase / sit, figure.stance (v11: "aim" / "low" / "inspect" = hold that gun pose; opts.stance sets it at creation)
--       v5.16: figure.pose / opts.pose = a Poses id (an empty-handed figure holds that pose, solved forward from its joint angles); opts.poseT / figure.poseT = the moment of an animated pose (nil = it plays)
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

-- =====================================================================================
-- v11 EDITIONS: the same three outfits in new colourways, sold in the lobby's cosmetics shop (price = { souls = n } or { essence = n }).
-- An edition is a normal S.List entry with `base` = the outfit that builds it (DRESS[base]) + the colours it changes. The three base outfits are free.
--   S.Price(id) -> { souls = n } / { essence = n } / nil (free)      S.IsFree(id)
-- =====================================================================================
local function baseEntry(id) for _, s in S.List do if s.id == id then return s end end end
local function edition(baseId, id, name, sub, desc, card, price, over)
	local b = baseEntry(baseId)
	local colors = table.clone(b.colors)
	for k, v in over do colors[k] = v end
	-- keep the legacy keys (menus read them) in step with the new palette
	if over.Top then colors.Suit, colors.Cloth = over.Top, over.Top end
	if over.Carrier then colors.Armor, colors.Plate = over.Carrier, over.Carrier end
	if over.Bone then colors.Armor, colors.Plate, colors.Glove = over.Bone, over.Bone, over.Bone end
	if over.Steel then colors.Suit, colors.Metal = over.Steel, over.Steel end
	if over.Orange then colors.Plate, colors.Brand = over.Orange, over.Orange end
	if over.Soul then colors.Accent, colors.Brand = over.Soul, over.Soul end
	if over.Glow then colors.Accent = over.Glow end
	table.insert(S.List, { id = id, base = baseId, name = name, sub = sub, desc = desc, card = card, price = price, colors = colors, edition = true })
end
edition("OPERATOR", "OPERATOR_ARCTIC", "ARCTIC", "Operator // winter kit", "The standard kit in snow whites and slate. Reads clearly on dark maps.", rgb(196, 206, 222), { souls = 1400 }, {
	Top = rgb(176, 184, 196), TopDark = rgb(132, 142, 158), Pants = rgb(164, 172, 184), PantsDark = rgb(128, 138, 152),
	Helmet = rgb(228, 232, 238), HelmetDark = rgb(170, 178, 192), Carrier = rgb(214, 218, 226), CarrierDark = rgb(150, 160, 176),
	Gaiter = rgb(96, 110, 132), GaiterDark = rgb(70, 82, 102), Shoe = rgb(58, 64, 78), Pad = rgb(58, 64, 78), Glove = rgb(52, 58, 70), Tape = rgb(236, 236, 232) })
edition("OPERATOR", "OPERATOR_NIGHTFALL", "NIGHTFALL", "Operator // night kit", "Gunmetal and steel-blue with a sharper red. Quiet, but never hard to see.", rgb(96, 108, 136), { essence = 300 }, {
	Top = rgb(40, 44, 54), TopDark = rgb(26, 29, 36), Pants = rgb(46, 50, 62), PantsDark = rgb(32, 35, 44),
	Helmet = rgb(66, 74, 92), HelmetDark = rgb(44, 50, 64), Carrier = rgb(74, 82, 100), CarrierDark = rgb(48, 54, 68),
	Gaiter = rgb(34, 38, 48), GaiterDark = rgb(24, 27, 34), Accent = rgb(255, 64, 74), Brand = rgb(255, 64, 74), Tape = rgb(150, 160, 180) })
edition("SOULBOUND", "SOULBOUND_ASHEN", "ASHEN", "Soulbound // cold ash", "The pallbearer's coat burnt to charcoal. Bone stays bone, the souls stay blue.", rgb(150, 156, 168), { souls = 1600 }, {
	Top = rgb(66, 68, 76), TopDark = rgb(42, 44, 52), Pants = rgb(36, 38, 46), PantsDark = rgb(24, 25, 32), Bone = rgb(216, 212, 202), BoneShade = rgb(172, 168, 158), Wrap = rgb(216, 212, 202) })
edition("SOULBOUND", "SOULBOUND_EMBERBOUND", "EMBERBOUND", "Soulbound // burning dead", "An oxblood coat and embers where the souls were. The lantern burns orange.", rgb(240, 130, 70), { essence = 450 }, {
	Top = rgb(78, 34, 34), TopDark = rgb(50, 22, 22), Pants = rgb(40, 24, 24), PantsDark = rgb(26, 16, 16), Soul = rgb(255, 156, 76), Bone = rgb(234, 224, 206), Shirt = rgb(214, 196, 170) })
edition("SOULBOUND", "SOULBOUND_GILDED", "GILDED", "Soulbound // royal dead", "Violet-black cloth with the bone replaced by hammered gold. A king's pallbearer.", rgb(236, 196, 92), { essence = 650 }, {
	Top = rgb(40, 34, 60), TopDark = rgb(26, 22, 40), Pants = rgb(26, 22, 40), PantsDark = rgb(18, 15, 28), Bone = rgb(236, 198, 96), BoneShade = rgb(186, 146, 62), Wrap = rgb(214, 178, 88),
	Soul = rgb(255, 228, 150), Shirt = rgb(232, 214, 160) })
edition("CHASSIS", "CHASSIS_RUSTBUCKET", "RUSTBUCKET", "Chassis // salvage frame", "Sun-bleached steel gone to rust, mustard panels. It should have been scrapped years ago.", rgb(196, 150, 56), { souls = 1100 }, {
	Steel = rgb(160, 132, 106), SteelDark = rgb(112, 90, 72), Graphite = rgb(66, 56, 48), GraphiteDark = rgb(42, 36, 32), Orange = rgb(212, 162, 52), OrangeDark = rgb(160, 120, 36), Glow = rgb(255, 190, 110),
	Skin = rgb(160, 132, 106), SkinShade = rgb(112, 90, 72) })
edition("CHASSIS", "CHASSIS_COBALT", "COBALT", "Chassis // deep-sea unit", "Blue steel, white panels and a cold cyan screen. Built for the tide walls.", rgb(110, 140, 200), { souls = 1800 }, {
	Steel = rgb(118, 142, 184), SteelDark = rgb(82, 104, 142), Graphite = rgb(38, 46, 66), GraphiteDark = rgb(24, 30, 44), Orange = rgb(238, 240, 246), OrangeDark = rgb(184, 188, 200), Glow = rgb(140, 230, 255),
	Skin = rgb(118, 142, 184), SkinShade = rgb(82, 104, 142) })
edition("CHASSIS", "CHASSIS_CHROME", "CHROME", "Chassis // showroom unit", "A polished chrome frame with gold panels. Never seen a wall, never will.", rgb(224, 230, 240), { essence = 500 }, {
	Steel = rgb(218, 224, 234), SteelDark = rgb(154, 162, 176), Graphite = rgb(64, 68, 78), GraphiteDark = rgb(36, 39, 46), Orange = rgb(255, 198, 66), OrangeDark = rgb(196, 146, 40), Glow = rgb(255, 255, 255),
	Skin = rgb(218, 224, 234), SkinShade = rgb(154, 162, 176) })
S.Default = "OPERATOR"
S.Order, S.ById = {}, {}
for _, s in S.List do
	table.insert(S.Order, s.id)
	S.ById[s.id] = s
end

-- v5.18: the colours of the FIRST-PERSON arms (GunModels viewmodel + the GadgetClient hand) so they match the costume you wear:
--   Skins.ViewArms(skinId) -> { glove = Color3, cuff = Color3, sleeve = Color3, mat = Enum.Material }
-- (the same keys the outfit uses for its glove, its cuff band and its forearm, colourways included)
local VIEW_ARMS = {
	OPERATOR = { glove = "Glove", cuff = "TopDark", sleeve = "Top", mat = Enum.Material.Fabric },
	SOULBOUND = { glove = "Wrap", cuff = "TopDark", sleeve = "Top", mat = Enum.Material.Fabric },
	CHASSIS = { glove = "Graphite", cuff = "Graphite", sleeve = "SteelDark", mat = Enum.Material.Metal },
}
function S.ViewArms(skinId)
	local skin = S.ById[skinId] or S.ById[S.Default]
	local map = VIEW_ARMS[skin.base or skin.id] or VIEW_ARMS.OPERATOR
	local c = skin.colors
	return {
		glove = c[map.glove] or c.Glove or rgb(26, 26, 30),
		cuff = c[map.cuff] or c.TopDark or rgb(34, 36, 42),
		sleeve = c[map.sleeve] or c.Top or rgb(52, 55, 62),
		mat = map.mat,
	}
end
function S.Is(id) return type(id) == "string" and S.ById[id] ~= nil end
function S.Price(id) local s = S.ById[id]; return s and s.price or nil end
function S.IsFree(id) local s = S.ById[id]; return s ~= nil and s.price == nil end
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
	function B.cyl(base, size, pos, col, mat, r) emit(base, "cyl", size, rotCF(pos, r), col, mat) end -- v11: cylinder (axis = X, size = length, diameter, diameter); robots + hero props only
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
-- the sleeve to the glove. v10: JUST a plain block hand (no knuckle plate, no thumb). Same on the character + the figure.
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

-- v11 KIT ADDITIONS: real gear is built from a few repeatable pieces, so the outfits read like designed kit instead of loose blocks.
--   K.pouch(B, base, cx, cy, fz, w, h, d, col, flapCol, snapCol, mat)       a pouch on a FRONT (-Z) face: fz = the z of that face, centre (cx, cy);
--                                                                         body + a flap over the top + a snap. Sizes in studs.
--   K.sidePouch(B, base, sg, fx, cy, cz, h, w, d, col, flapCol, snapCol, mat) the same on a SIDE face: sg = +1 / -1 (right / left), fx = x of that face,
--                                                                         w = length along Z.
function K.pouch(B, base, cx, cy, fz, w, h, d, col, flap, snap, mat)
	mat = mat or FABRIC
	B.blk(base, V3(w, h, d), V3(cx, cy, fz - d * 0.5), col, mat)
	local fh = h * 0.34
	B.blk(base, V3(w * 1.05, fh, d * 1.14), V3(cx, cy + h * 0.5 - fh * 0.5, fz - d * 0.57), flap or col, mat)
	if snap then local st = math.max(0.034, d * 0.22); B.blk(base, V3(math.max(0.06, w * 0.14), math.max(0.045, h * 0.1), st), V3(cx, cy + h * 0.5 - fh, fz - d * 1.14 - st * 0.4), snap, METAL) end
end
function K.sidePouch(B, base, sg, fx, cy, cz, h, w, d, col, flap, snap, mat)
	mat = mat or FABRIC
	B.blk(base, V3(d, h, w), V3(sg * (fx + d * 0.5), cy, cz), col, mat)
	local fh = h * 0.34
	B.blk(base, V3(d * 1.14, fh, w * 1.05), V3(sg * (fx + d * 0.57), cy + h * 0.5 - fh * 0.5, cz), flap or col, mat)
	if snap then local st = math.max(0.034, d * 0.22); B.blk(base, V3(st, math.max(0.045, h * 0.1), math.max(0.06, w * 0.14)), V3(sg * (fx + d * 1.14 + st * 0.4), cy + h * 0.5 - fh, cz), snap, METAL) end
end

-- =====================================================================================
-- OUTFITS. DRESS[id](B, Z, C, opt) - Z = part sizes (+ Z.u, Z.h), C = the skin colours, opt.noHands = the figure builds no hands.
-- =====================================================================================
local DRESS = {}

-- ---------------------------------------------------------------- OPERATOR (v11): "a tactical operator, built like real kit". Ballistic helmet with a headset,
-- goggles + rear counterweight, gaiter, a plate carrier with PALS webbing, three mag pouches, admin panel + drag handle, battle belt with
-- two belt pouches, cargo trousers, drop-leg holster (right) + mag pouch (left), hard-shell knee pads, laced boots. Every strap runs to
-- something, every pouch is a body + flap + snap, pairs are symmetric, only the holster / patch / watch / mic boom are asymmetric.
-- Palette: charcoal (shirt, boots) + coyote (helmet, carrier, pads) + olive (gaiter, trousers) + one darker shade each; red = arm patch + goggle clip.
DRESS.OPERATOR = function(B, Z, C, opt)
	local u = Z.u
	-- ===== HEAD =====
	local h = K.head(B, Z, C.Skin, { eye = C.Eye, white = C.White, brow = C.Hair, nose = C.SkinShade, ear = C.SkinShade, eyeY = 0 })
	local hd = "Head"
	B.blk(hd, V3(h * 1.03, h * 0.34, h * 1.03), V3(0, -h * 0.33, 0), C.Gaiter, FABRIC)                   -- gaiter over nose + mouth
	B.blk(hd, V3(h * 1.06, h * 0.04, h * 1.06), V3(0, -h * 0.17, 0), C.GaiterDark, FABRIC)               -- its folded top edge
	B.blk(hd, V3(h * 1.06, h * 0.07, h * 1.06), V3(0, -h * 0.46, 0), C.Strap, SP)                        -- cinch band at the chin
	B.blk(hd, V3(h * 1.1, h * 0.4, h * 1.12), V3(0, h * 0.36, h * 0.01), C.Helmet, SP)                   -- shell
	B.blk(hd, V3(h * 0.96, h * 0.1, h * 0.98), V3(0, h * 0.58, h * 0.01), C.Helmet, SP)                  -- crown
	B.blk(hd, V3(h * 1.13, h * 0.06, h * 1.15), V3(0, h * 0.2, h * 0.01), C.HelmetDark, SP)              -- brim band
	B.blk(hd, V3(h * 0.5, h * 0.2, h * 0.16), V3(0, h * 0.32, h * 0.66), C.HelmetDark, FABRIC)           -- rear counterweight pouch
	B.blk(hd, V3(h * 1.13, h * 0.05, h * 1.17), V3(0, h * 0.4, h * 0.01), C.HelmetDark, FABRIC)          -- elastic band round the shell
	for _, sg in { -1, 1 } do
		B.blk(hd, V3(h * 0.04, h * 0.06, h * 0.5), V3(sg * h * 0.57, h * 0.36, 0), C.HelmetDark, SP)     -- side rail
		B.blk(hd, V3(h * 0.14, h * 0.3, h * 0.34), V3(sg * h * 0.57, -h * 0.02, h * 0.06), C.Strap, SP)  -- headset ear cup
		B.blk(hd, V3(h * 0.06, h * 0.12, h * 0.12), V3(sg * h * 0.56, h * 0.17, h * 0.06), C.Strap, SP)  -- headset arm up to the helmet
		B.blk(hd, V3(h * 0.05, h * 0.66, h * 0.1), V3(sg * h * 0.53, -h * 0.13, -h * 0.22), C.Strap, SP) -- chin strap
		B.blk(hd, V3(h * 0.34, h * 0.13, h * 0.04), V3(sg * h * 0.2, h * 0.31, -h * 0.66), C.Lens, GLASS) -- goggle lens
	end
	B.blk(hd, V3(h * 0.04, h * 0.04, h * 0.34), V3(-h * 0.58, -h * 0.1, -h * 0.28), C.Strap, SP)         -- mic boom (left)
	B.blk(hd, V3(h * 0.07, h * 0.07, h * 0.05), V3(-h * 0.58, -h * 0.1, -h * 0.47), C.Strap, SP)
	B.blk(hd, V3(h * 1.14, h * 0.07, h * 1.16), V3(0, h * 0.3, h * 0.01), C.Strap, SP)                    -- goggle strap round the shell
	B.blk(hd, V3(h * 0.86, h * 0.2, h * 0.1), V3(0, h * 0.31, -h * 0.6), C.Strap, SP)                     -- goggle frame
	B.blk(hd, V3(h * 0.1, h * 0.1, h * 0.05), V3(0, h * 0.31, -h * 0.67), C.Accent, SP)                   -- red clip

	-- ===== UPPER TORSO =====
	local T = Z.UpperTorso
	local W, H, D = T.X, T.Y, T.Z
	local ut = "UpperTorso"
	K.core(B, Z, ut, C.Top, FABRIC)
	B.blk(ut, V3(W * 0.34, 0.14 * u, D * 0.62), V3(0, H * 0.5 + 0.04 * u, 0), C.TopDark, FABRIC)           -- collar
	local fz = -D * 0.5 - 0.14 * u                                                                         -- front face of the carrier
	B.blk(ut, V3(W * 0.82, H * 0.64, 0.14 * u), V3(0, H * 0.04, -D * 0.5 - 0.07 * u), C.Carrier, FABRIC)   -- front plate bag
	B.blk(ut, V3(W * 0.84, 0.06 * u, 0.16 * u), V3(0, H * 0.36 - 0.03 * u, -D * 0.5 - 0.08 * u), C.CarrierDark, FABRIC) -- top piping
	B.blk(ut, V3(W * 0.84, 0.06 * u, 0.16 * u), V3(0, -H * 0.28 + 0.03 * u, -D * 0.5 - 0.08 * u), C.CarrierDark, FABRIC) -- bottom piping
	B.blk(ut, V3(W * 0.5, H * 0.15, 0.05 * u), V3(0, H * 0.22, fz - 0.025 * u), C.CarrierDark, FABRIC)     -- admin panel
	B.blk(ut, V3(W * 0.36, 0.04 * u, 0.07 * u), V3(0, H * 0.22, fz - 0.06 * u), C.Tape, FABRIC)            -- name tape
	for i = -1, 1 do
		K.pouch(B, ut, i * W * 0.26, -H * 0.1, fz, W * 0.22, H * 0.25, 0.16 * u, C.CarrierDark, C.Carrier, C.Metal, FABRIC)
	end
	for _, sg in { -1, 1 } do
		B.blk(ut, V3(W * 0.2, 0.1 * u, D + 0.28 * u), V3(sg * W * 0.27, H * 0.5 + 0.05 * u, 0), C.Carrier, FABRIC) -- shoulder strap
		B.blk(ut, V3(W * 0.2, 0.04 * u, 0.06 * u), V3(sg * W * 0.27, H * 0.5 + 0.1 * u, -D * 0.5 - 0.14 * u), C.CarrierDark, FABRIC) -- strap keeper
		for _, dy in { 0.035, -0.035 } do                                                                 -- PALS webbing on the cummerbund side
			B.blk(ut, V3(0.04 * u, 0.045 * u, D * 0.62), V3(sg * (W * 0.51 + 0.06 * u), -H * 0.36 + dy * H, 0), C.Strap, FABRIC)
		end
	end
	B.blk(ut, V3(W * 1.02, H * 0.2, D * 1.04 + 0.12 * u), V3(0, -H * 0.36, 0), C.CarrierDark, FABRIC)      -- cummerbund
	B.blk(ut, V3(W * 0.84, H * 0.66, 0.14 * u), V3(0, H * 0.04, D * 0.5 + 0.07 * u), C.Carrier, FABRIC)    -- back plate bag
	B.blk(ut, V3(W * 0.84, 0.06 * u, 0.16 * u), V3(0, H * 0.36 - 0.03 * u, D * 0.5 + 0.08 * u), C.CarrierDark, FABRIC)
	for _, sg in { -1, 1 } do
		B.blk(ut, V3(0.06 * u, 0.12 * u, 0.06 * u), V3(sg * W * 0.12, H * 0.32, D * 0.5 + 0.17 * u), C.CarrierDark, FABRIC) -- drag handle posts
		B.blk(ut, V3(W * 0.08, H * 0.5, 0.04 * u), V3(sg * W * 0.3, H * 0.04, D * 0.5 + 0.16 * u), C.CarrierDark, FABRIC)   -- vertical back straps
	end
	B.blk(ut, V3(W * 0.3, 0.06 * u, 0.06 * u), V3(0, H * 0.32 + 0.06 * u, D * 0.5 + 0.17 * u), C.CarrierDark, FABRIC)       -- drag handle

	-- ===== LOWER TORSO: trousers, battle belt, buckle, two belt pouches =====
	local LT = Z.LowerTorso
	local lt = "LowerTorso"
	K.core(B, Z, lt, C.Pants, FABRIC, 1.02)
	B.blk(lt, V3(LT.X * 1.05, 0.2 * u, LT.Z * 1.07), V3(0, LT.Y * 0.1, 0), C.Strap, LEATHER)
	B.blk(lt, V3(0.28 * u, 0.17 * u, 0.05 * u), V3(0, LT.Y * 0.1, -LT.Z * 0.535 - 0.025 * u), C.Metal, METAL)
	B.blk(lt, V3(0.1 * u, 0.1 * u, 0.06 * u), V3(0, LT.Y * 0.1, -LT.Z * 0.535 - 0.05 * u), C.Strap, SP)
	K.pouch(B, lt, -LT.X * 0.3, LT.Y * 0.04, -LT.Z * 0.535 - 0.0 * u, 0.3 * u, 0.34 * u, 0.15 * u, C.PantsDark, C.Pants, C.Metal, FABRIC)
	K.pouch(B, lt, LT.X * 0.3, LT.Y * 0.04, -LT.Z * 0.535 - 0.0 * u, 0.3 * u, 0.34 * u, 0.15 * u, C.CarrierDark, C.Carrier, C.Metal, FABRIC)

	-- ===== ARMS: sleeves with a seam, elbow pad + cap, velcro strap, cuff, plain glove. Patch on the LEFT upper arm, watch on the LEFT wrist =====
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local ua, la = side .. "UpperArm", side .. "LowerArm"
		local A, L = Z[ua], Z[la]
		K.core(B, Z, ua, C.Top, FABRIC)
		K.core(B, Z, la, C.Top, FABRIC)
		B.blk(ua, V3(0.03 * u, A.Y * 0.86, 0.05 * u), V3(sg * (A.X * 0.5 + 0.015 * u), 0, 0), C.TopDark, FABRIC)             -- outer sleeve seam
		K.band(B, Z, la, L.Y * 0.5 - 0.2 * u, 0.4 * u, C.Carrier, FABRIC, 1.08)                                               -- elbow pad
		B.blk(la, V3(L.X * 0.7, 0.3 * u, 0.06 * u), V3(0, L.Y * 0.5 - 0.2 * u, L.Z * 0.5 + 0.07 * u), C.CarrierDark, SP)       -- pad cap (elbow point)
		K.band(B, Z, la, L.Y * 0.5 - 0.62 * u, 0.1 * u, C.TopDark, FABRIC, 1.07)                                              -- velcro strap
		K.band(B, Z, la, -L.Y * 0.5 + 0.16 * u, 0.2 * u, C.TopDark, FABRIC, 1.07)                                             -- cuff
		if side == "Left" then
			local px = sg * (A.X * 0.5 + 0.008 * u)
			B.blk(ua, V3(0.03 * u, A.Y * 0.26, A.Z * 0.5), V3(px, A.Y * 0.14, 0), C.Accent, SP)
			B.blk(ua, V3(0.04 * u, A.Y * 0.045, A.Z * 0.2), V3(px - 0.006 * u, A.Y * 0.17, -A.Z * 0.11), C.White, SP)   -- the "break line" mark:
			B.blk(ua, V3(0.04 * u, A.Y * 0.045, A.Z * 0.2), V3(px - 0.006 * u, A.Y * 0.11, A.Z * 0.11), C.White, SP)    -- two offset bars
			K.band(B, Z, la, -L.Y * 0.5 + 0.42 * u, 0.1 * u, C.Strap, LEATHER, 1.05)                                       -- watch strap
			B.blk(la, V3(0.22 * u, 0.2 * u, 0.06 * u), V3(0, -L.Y * 0.5 + 0.42 * u, -L.Z * 0.5 - 0.06 * u), C.Metal, METAL) -- watch face
		end
		if not opt.noHands then K.hand(B, Z, side, C.Glove, C.Pad, C.Pad) end
	end

	-- ===== LEGS: cargo pocket (left) / drop-leg holster (right), hard-shell knee pads, calf bands, laced boots =====
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local ul, ll = side .. "UpperLeg", side .. "LowerLeg"
		local U, L = Z[ul], Z[ll]
		K.core(B, Z, ul, C.Pants, FABRIC)
		K.core(B, Z, ll, C.Pants, FABRIC)
		local outX = U.X * 0.5
		if side == "Left" then
			K.sidePouch(B, ul, sg, outX, -U.Y * 0.06, 0, U.Y * 0.38, U.Z * 0.64, 0.14 * u, C.PantsDark, C.Pants, C.Metal, FABRIC) -- cargo pocket
		else
			B.blk(ul, V3(0.1 * u, U.Y * 0.62, U.Z * 0.2), V3(outX + 0.05 * u, U.Y * 0.04, -U.Z * 0.2), C.Strap, LEATHER)         -- hip strap down to the platform
			B.blk(ul, V3(0.1 * u, U.Y * 0.4, U.Z * 0.64), V3(outX + 0.05 * u, -U.Y * 0.12, 0), C.Strap, LEATHER)                  -- holster platform
			B.blk(ul, V3(0.14 * u, U.Y * 0.34, U.Z * 0.46), V3(outX + 0.17 * u, -U.Y * 0.14, 0), C.Gun, SP)                        -- pistol in the holster
			B.blk(ul, V3(0.16 * u, 0.24 * u, 0.2 * u), V3(outX + 0.18 * u, -U.Y * 0.14 + U.Y * 0.2, U.Z * 0.2), C.Gun, SP)         -- grip
			B.blk(ul, V3(0.18 * u, 0.06 * u, U.Z * 0.5), V3(outX + 0.17 * u, -U.Y * 0.14 + U.Y * 0.16, 0), C.Strap, LEATHER)       -- retention strap
		end
		K.band(B, Z, ul, -U.Y * 0.3, 0.07 * u, C.Strap, LEATHER, 1.06)                                                         -- thigh strap
		local kn = J.ll(L).kn
		B.blk(ll, V3(L.X * 0.9, 0.5 * u, 0.06 * u), kn + V3(0, 0, -L.Z * 0.5 - 0.03 * u), C.CarrierDark, FABRIC)               -- pad under-layer
		B.blk(ll, V3(L.X * 0.78, 0.42 * u, 0.12 * u), kn + V3(0, 0, -L.Z * 0.5 - 0.1 * u), C.Carrier, SP)                       -- hard shell
		K.band(B, Z, ll, kn.Y + 0.3 * u, 0.06 * u, C.Strap, FABRIC, 1.06)                                                      -- upper knee strap
		K.band(B, Z, ll, kn.Y - 0.3 * u, 0.06 * u, C.Strap, FABRIC, 1.06)                                                      -- lower knee strap
		K.band(B, Z, ll, -L.Y * 0.5 + 0.56 * u, 0.1 * u, C.PantsDark, FABRIC, 1.07)                                            -- blousing band over the boot
		K.boot(B, Z, side, C.Shoe, C.Sole, C.Lace, { collar = C.Pad, heel = C.Shoe, toeCap = C.Sole, laceX = C.Lace })
	end
	K.fillers(B, Z, C.Top, FABRIC, C.Pants, FABRIC)
end

-- ---------------------------------------------------------------- SOULBOUND (v11): "a pallbearer who carries the dead". A deep hood with a stitched rim and a
-- bone mask lit by two souls, a high-collared navy coat with a layered mantle, a leather bandolier of three soul vials, a ragged split tail, a soul
-- lantern + key ring on the belt, a bone pauldron (left) and bandaged right arm, wrapped shins and tall buckled boots.
-- Palette: navy (coat) + bone (mask, collar, pauldron, trim, wraps) + near-black leather; the only glow = the mask eyes + the lantern core (vials are plain glass).
DRESS.SOULBOUND = function(B, Z, C, opt)
	local u = Z.u
	local hd = "Head"
	-- ===== HEAD: hood + mask =====
	local h = K.head(B, Z, C.Hair, { face = false })
	B.blk(hd, V3(h * 1.24, h * 0.14, h * 1.24), V3(0, h * 0.56, h * 0.02), C.Top, FABRIC)                  -- crown
	B.blk(hd, V3(h * 1.24, h * 1.16, h * 0.14), V3(0, 0, h * 0.58), C.Top, FABRIC)                          -- back
	B.blk(hd, V3(h * 1.24, h * 0.2, h * 0.24), V3(0, h * 0.48, -h * 0.6), C.Top, FABRIC)                    -- peak over the brow
	B.blk(hd, V3(h * 1.0, 0.04 * u, h * 0.05), V3(0, h * 0.375, -h * 0.74), C.BoneShade, FABRIC)            -- stitched rim under the peak
	B.blk(hd, V3(h * 0.04, h * 1.0, 0.04 * u), V3(0, -h * 0.02, h * 0.66), C.TopDark, FABRIC)               -- back seam
	B.blk(hd, V3(h * 1.3, h * 0.22, h * 1.3), V3(0, -h * 0.56, 0.0), C.TopDark, FABRIC)                     -- cowl round the neck
	for _, sg in { -1, 1 } do
		B.blk(hd, V3(h * 0.14, h * 1.1, h * 1.24), V3(sg * h * 0.55, -h * 0.02, h * 0.02), C.Top, FABRIC)   -- sides
		B.blk(hd, V3(h * 0.16, h * 0.96, 0.04 * u), V3(sg * h * 0.55, -h * 0.04, -h * 0.64), C.BoneShade, FABRIC) -- stitched front edge
	end
	local f = -h * 0.5
	B.blk(hd, V3(h * 0.74, h * 0.82, h * 0.08), V3(0, -h * 0.04, f - h * 0.02), C.Bone, SP)                -- mask plate
	B.blk(hd, V3(h * 0.62, h * 0.12, h * 0.08), V3(0, h * 0.3, f - h * 0.05), C.Bone, SP)                   -- brow ridge
	B.blk(hd, V3(h * 0.1, h * 0.3, h * 0.06), V3(0, h * 0.0, f - h * 0.065), C.Bone, SP)                    -- nose bridge
	B.blk(hd, V3(h * 0.08, h * 0.08, h * 0.03), V3(0, -h * 0.12, f - h * 0.08), C.Eye, SP)                  -- nose hole
	B.blk(hd, V3(h * 0.6, h * 0.1, h * 0.09), V3(0, -h * 0.45, f - h * 0.03), C.BoneShade, SP)              -- jaw plate
	for _, sg in { -1, 1 } do
		B.blk(hd, V3(h * 0.2, h * 0.14, h * 0.03), V3(sg * h * 0.17, h * 0.14, f - h * 0.065), C.Eye, SP)   -- eye socket
		B.blk(hd, V3(h * 0.08, h * 0.08, h * 0.03), V3(sg * h * 0.17, h * 0.14, f - h * 0.075), C.Soul, NEON) -- soul glow
		B.blk(hd, V3(h * 0.12, h * 0.3, h * 0.03), V3(sg * h * 0.3, -h * 0.14, f - h * 0.065), C.BoneShade, SP) -- cheek carving
	end
	B.blk(hd, V3(h * 0.4, h * 0.1, h * 0.03), V3(0, -h * 0.3, f - h * 0.065), C.Eye, SP)                    -- mouth slit
	for i = -2, 2 do
		B.blk(hd, V3(h * 0.04, h * 0.1, h * 0.04), V3(i * h * 0.085, -h * 0.3, f - h * 0.07), C.Bone, SP)   -- stitches
	end
	B.blk(hd, V3(h * 0.03, h * 0.14, h * 0.03), V3(-h * 0.17, h * 0.33, f - h * 0.095), C.Eye, SP)          -- crack over the left eye
	B.blk(hd, V3(h * 0.08, h * 0.03, h * 0.03), V3(-h * 0.2, h * 0.27, f - h * 0.095), C.Eye, SP)

	-- ===== UPPER TORSO: coat, bone shirt V, lapels, buttons, high collar, mantle, bandolier with three vials, back panel =====
	local T = Z.UpperTorso
	local W, H, D = T.X, T.Y, T.Z
	local ut = "UpperTorso"
	K.core(B, Z, ut, C.Top, FABRIC)
	B.blk(ut, V3(W * 0.3, H * 0.4, 0.03 * u), V3(0, H * 0.28, -D * 0.5 - 0.015 * u), C.Shirt, FABRIC)
	B.blk(ut, V3(W * 0.1, H * 0.94, 0.04 * u), V3(0, -H * 0.02, -D * 0.5 - 0.02 * u), C.TopDark, FABRIC)     -- front placket
	for _, sg in { -1, 1 } do
		B.blk(ut, V3(W * 0.12, H * 0.5, 0.07 * u), V3(sg * W * 0.21, H * 0.25, -D * 0.5 - 0.035 * u), C.TopDark, FABRIC) -- lapel
	end
	for i = 0, 3 do
		B.blk(ut, V3(0.09 * u, 0.09 * u, 0.05 * u), V3(0, -H * 0.05 - i * H * 0.14, -D * 0.5 - 0.065 * u), C.Bone, SP) -- coat buttons
	end
	B.blk(ut, V3(W * 0.4, 0.22 * u, D * 0.7), V3(0, H * 0.5 + 0.08 * u, 0), C.Top, FABRIC)                  -- high collar
	B.blk(ut, V3(W * 0.43, 0.05 * u, D * 0.73), V3(0, H * 0.5 + 0.19 * u, 0), C.Bone, SP)                    -- bone collar rim
	B.blk(ut, V3(W * 1.12, 0.2 * u, D * 1.2), V3(0, H * 0.5 - 0.02 * u, 0), C.TopDark, FABRIC)               -- mantle, top lame
	B.blk(ut, V3(W * 1.06, 0.18 * u, D * 1.14), V3(0, H * 0.5 - 0.21 * u, 0), C.Top, FABRIC)                 -- mantle, second lame
	B.blk(ut, V3(W * 1.14, 0.04 * u, D * 1.22), V3(0, H * 0.5 - 0.32 * u, 0), C.Bone, SP)                    -- bone trim on the mantle edge
	B.blk(ut, V3(0.16 * u, H * 1.18, 0.06 * u), V3(0, 0, -D * 0.5 - 0.1 * u), C.Strap, LEATHER, V3(0, 0, 45))     -- bandolier front
	B.blk(ut, V3(0.16 * u, H * 1.18, 0.06 * u), V3(0, 0, D * 0.5 + 0.1 * u), C.Strap, LEATHER, V3(0, 0, -45))     -- bandolier back
	for i = -1, 1 do
		local t = i * H * 0.27
		local px, py = -math.sin(rad(45)) * t, math.cos(rad(45)) * t
		B.blk(ut, V3(0.17 * u, 0.06 * u, 0.1 * u), V3(px, py - 0.02 * u, -D * 0.5 - 0.16 * u), C.Strap, LEATHER)                -- vial holder
		B.blk(ut, V3(0.1 * u, 0.28 * u, 0.1 * u), V3(px, py - 0.18 * u, -D * 0.5 - 0.17 * u), C.Soul, GLASS)                   -- vial (glass, lit by the lantern, not itself a light)
		B.blk(ut, V3(0.13 * u, 0.05 * u, 0.13 * u), V3(px, py - 0.04 * u, -D * 0.5 - 0.17 * u), C.Bone, SP)                     -- bone cap
	end
	B.blk(ut, V3(W * 0.9, H * 0.9, 0.05 * u), V3(0, -H * 0.04, D * 0.5 + 0.03 * u), C.TopDark, FABRIC)       -- short back cape
	B.blk(ut, V3(0.06 * u, H * 0.8, 0.03 * u), V3(0, -H * 0.04, D * 0.5 + 0.065 * u), C.BoneShade, FABRIC)   -- bone spine stitch

	-- ===== LOWER TORSO: belt, ragged split tail, soul lantern (right) + key ring (left) =====
	local LT = Z.LowerTorso
	local lt = "LowerTorso"
	K.core(B, Z, lt, C.Top, FABRIC, 1.02)
	B.blk(lt, V3(LT.X * 1.06, 0.18 * u, LT.Z * 1.08), V3(0, LT.Y * 0.12, 0), C.Strap, LEATHER)
	B.blk(lt, V3(0.2 * u, 0.16 * u, 0.05 * u), V3(-LT.X * 0.1, LT.Y * 0.12, -LT.Z * 0.54 - 0.025 * u), C.Metal, METAL)
	B.blk(lt, V3(0.08 * u, 0.08 * u, 0.05 * u), V3(-LT.X * 0.1, LT.Y * 0.12, -LT.Z * 0.54 - 0.05 * u), C.Eye, SP)
	local tailH = 1.25 * u
	local topY = -LT.Y * 0.5 + 0.06 * u
	for _, sg in { -1, 1 } do
		B.blk(lt, V3(LT.X * 0.44, tailH * 0.72, 0.07 * u), V3(sg * LT.X * 0.27, topY - tailH * 0.36, -LT.Z * 0.5 - 0.05 * u), C.Top, FABRIC)
		B.blk(lt, V3(LT.X * 0.2, tailH * 0.34, 0.07 * u), V3(sg * LT.X * 0.38, topY - tailH * 0.72 - tailH * 0.17 + 0.02 * u, -LT.Z * 0.5 - 0.05 * u), C.Top, FABRIC) -- ragged: outer strip
		B.blk(lt, V3(LT.X * 0.2, tailH * 0.2, 0.07 * u), V3(sg * LT.X * 0.16, topY - tailH * 0.72 - tailH * 0.1 + 0.02 * u, -LT.Z * 0.5 - 0.05 * u), C.Top, FABRIC) -- ragged: inner strip
		B.blk(lt, V3(LT.X * 0.44, 0.04 * u, 0.08 * u), V3(sg * LT.X * 0.27, topY - tailH * 0.72 + 0.02 * u, -LT.Z * 0.5 - 0.055 * u), C.BoneShade, FABRIC) -- bone hem line
	end
	B.blk(lt, V3(LT.X * 1.06, tailH * 0.74, 0.07 * u), V3(0, topY - tailH * 0.37, LT.Z * 0.5 + 0.05 * u), C.Top, FABRIC)
	for i = -1, 1 do
		B.blk(lt, V3(LT.X * 0.3, tailH * (0.3 - 0.08 * math.abs(i)), 0.07 * u), V3(i * LT.X * 0.34, topY - tailH * 0.74 - tailH * 0.13, LT.Z * 0.5 + 0.05 * u), C.Top, FABRIC)
	end
	local lp = V3(LT.X * 0.36, -0.45 * u, -LT.Z * 0.5 - 0.19 * u)
	B.blk(lt, V3(0.05 * u, 0.05 * u, 0.22 * u), V3(lp.X, LT.Y * 0.12, -LT.Z * 0.5 - 0.09 * u), C.Metal, METAL)  -- bracket off the belt
	B.blk(lt, V3(0.04 * u, 0.32 * u, 0.04 * u), V3(lp.X, LT.Y * 0.12 - 0.14 * u, lp.Z), C.Metal, METAL)         -- hanger
	B.blk(lt, V3(0.3 * u, 0.06 * u, 0.3 * u), lp + V3(0, 0.2 * u, 0), C.Metal, METAL)                          -- cap
	B.blk(lt, V3(0.3 * u, 0.06 * u, 0.3 * u), lp + V3(0, -0.2 * u, 0), C.Metal, METAL)                         -- base
	B.blk(lt, V3(0.22 * u, 0.34 * u, 0.22 * u), lp, C.Soul, GLASS)
	B.blk(lt, V3(0.09 * u, 0.15 * u, 0.09 * u), lp, C.Soul, NEON)                                              -- lantern core (the second glow)
	local kx = -LT.X * 0.34
	B.blk(lt, V3(0.04 * u, 0.2 * u, 0.04 * u), V3(kx, LT.Y * 0.12 - 0.1 * u, -LT.Z * 0.54 - 0.06 * u), C.Strap, LEATHER) -- key strap
	B.blk(lt, V3(0.15 * u, 0.15 * u, 0.04 * u), V3(kx, LT.Y * 0.12 - 0.27 * u, -LT.Z * 0.54 - 0.06 * u), C.Metal, METAL) -- ring
	for _, dx in { -0.06, 0.06 } do
		B.blk(lt, V3(0.05 * u, 0.22 * u, 0.03 * u), V3(kx + dx * u, LT.Y * 0.12 - 0.45 * u, -LT.Z * 0.54 - 0.06 * u), C.Metal, METAL) -- keys
	end

	-- ===== ARMS: coat sleeves with a bone cuff line; LEFT = layered bone pauldron, RIGHT = three bandage wraps; bone-wrapped hands =====
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local ua, la = side .. "UpperArm", side .. "LowerArm"
		local A, L = Z[ua], Z[la]
		K.core(B, Z, ua, C.Top, FABRIC)
		K.core(B, Z, la, C.Top, FABRIC)
		K.band(B, Z, la, -L.Y * 0.5 + 0.2 * u, 0.26 * u, C.TopDark, FABRIC, 1.1)
		K.band(B, Z, la, -L.Y * 0.5 + 0.38 * u, 0.04 * u, C.BoneShade, FABRIC, 1.12)
		if side == "Left" then
			B.blk(ua, V3(A.X * 1.24, 0.2 * u, A.Z * 1.24), V3(sg * 0.05 * u, A.Y * 0.5, 0), C.Bone, SP)
			B.blk(ua, V3(A.X * 1.16, 0.18 * u, A.Z * 1.16), V3(sg * 0.05 * u, A.Y * 0.5 - 0.2 * u, 0), C.BoneShade, SP)
			B.wdg(ua, V3(0.1 * u, 0.26 * u, 0.22 * u), V3(sg * A.X * 0.3, A.Y * 0.5 + 0.23 * u, 0), C.Bone, SP, V3(0, 90 * sg, 0))
			B.blk(ua, V3(A.X * 1.06, 0.07 * u, A.Z * 1.06), V3(0, A.Y * 0.5 - 0.5 * u, 0), C.Strap, LEATHER)              -- pauldron strap
		else
			for i = 0, 2 do
				K.band(B, Z, la, L.Y * 0.18 - i * 0.2 * u, 0.12 * u, C.Wrap, FABRIC, 1.09)
			end
		end
		if not opt.noHands then K.hand(B, Z, side, C.Wrap, C.BoneShade, C.TopDark, { mat = FABRIC }) end
	end

	-- ===== LEGS: trousers with a front crease, three bone shin wraps, bone knee plates, tall boots with two buckled straps =====
	for _, side in { "Left", "Right" } do
		local ul, ll = side .. "UpperLeg", side .. "LowerLeg"
		local U, L = Z[ul], Z[ll]
		K.core(B, Z, ul, C.Pants, FABRIC)
		K.core(B, Z, ll, C.Pants, FABRIC)
		B.blk(ul, V3(0.04 * u, U.Y * 0.84, 0.03 * u), V3(0, 0, -U.Z * 0.5 - 0.015 * u), C.PantsDark, FABRIC)
		B.blk(ll, V3(L.X * 0.7, 0.3 * u, 0.1 * u), J.ll(L).kn + V3(0, 0, -L.Z * 0.5 - 0.05 * u), C.Bone, SP)         -- knee plate
		for i = 0, 2 do
			B.blk(ll, V3(L.X * 1.06, 0.12 * u, L.Z * 1.06), V3(0, L.Y * 0.16 - i * 0.2 * u, 0), C.Wrap, FABRIC)
		end
		K.boot(B, Z, side, C.Shoe, C.Sole, nil, { shaft = 0.36, collar = C.Strap, collarMat = LEATHER, toeCap = C.Shoe, heel = C.Shoe, mat = LEATHER })
		for i = 0, 1 do
			local y = -L.Y * 0.5 + L.Y * 0.36 * (0.28 + i * 0.4)
			B.blk(ll, V3(L.X * 1.1, 0.06 * u, L.Z * 1.1), V3(0, y, 0), C.Strap, LEATHER)                                 -- strap
			B.blk(ll, V3(0.1 * u, 0.1 * u, 0.04 * u), V3(L.X * 0.28, y, -L.Z * 0.55 - 0.02 * u), C.Metal, METAL)          -- buckle
		end
	end
	K.fillers(B, Z, C.Top, FABRIC, C.Pants, FABRIC)
end

-- ---------------------------------------------------------------- CHASSIS (v11): "a worn wall-crew robot". The box robots of Wall Push, grown up: a steel head
-- with a bezelled screen face and two warm eyes, ear modules, a vented cap and an antenna; a steel chest with a safety-orange panel in a graphite frame and a hazard
-- band under it; a back pack with two exhaust pipes; shoulder caps (orange left / steel-dark right) on hydraulic pistons; slatted forearms; thigh pistons,
-- knee joints and heavy toe-capped boots. Cylinders are allowed here (hero props: pistons, joints, pipes).
-- Palette: steel + graphite + safety orange (+ one darker shade each); the only glow = the screen eyes + one small status lamp.
DRESS.CHASSIS = function(B, Z, C, opt)
	local u = Z.u
	local hd = "Head"
	-- ===== HEAD =====
	local h = K.head(B, Z, C.Steel, { face = false, mat = METAL })
	B.blk(hd, V3(h * 0.9, h * 0.66, h * 0.05), V3(0, h * 0.02, -h * 0.51), C.Graphite, SP)                  -- bezel
	B.blk(hd, V3(h * 0.8, h * 0.56, h * 0.06), V3(0, h * 0.02, -h * 0.53), C.GraphiteDark, SP)               -- screen
	B.blk(hd, V3(h * 1.01, 0.04 * u, h * 1.01), V3(0, -h * 0.3, 0), C.GraphiteDark, SP)                      -- jaw seam
	for _, sg in { -1, 1 } do
		B.blk(hd, V3(h * 0.15, h * 0.2, h * 0.04), V3(sg * h * 0.2, h * 0.06, -h * 0.57), C.Glow, NEON)      -- eyes
		B.blk(hd, V3(h * 0.2, 0.04 * u, h * 0.04), V3(sg * h * 0.2, h * 0.2, -h * 0.57), C.Graphite, SP)     -- brow lids
		B.blk(hd, V3(h * 0.14, h * 0.34, h * 0.34), V3(sg * h * 0.57, 0, h * 0.05), C.Graphite, SP)         -- ear module
		B.cyl(hd, V3(h * 0.06, h * 0.24, h * 0.24), V3(sg * h * 0.67, 0, h * 0.05), C.SteelDark, METAL)      -- ear disc
	end
	for i = 0, 2 do
		B.blk(hd, V3(h * 0.3, 0.04 * u, 0.04 * u), V3(0, -h * 0.14 - i * h * 0.07, -h * 0.55), C.GraphiteDark, SP) -- speaker grille
	end
	B.blk(hd, V3(h * 0.9, h * 0.07, h * 0.9), V3(0, h * 0.52, 0), C.SteelDark, METAL)                         -- cap plate
	for i = -1, 1 do
		B.blk(hd, V3(h * 0.5, 0.04 * u, h * 0.06), V3(0, h * 0.56, i * h * 0.14), C.GraphiteDark, SP)       -- cap vents
	end
	B.blk(hd, V3(h * 0.12, h * 0.06, h * 0.12), V3(h * 0.28, h * 0.58, h * 0.1), C.Graphite, SP)              -- antenna base
	B.cyl(hd, V3(h * 0.2, h * 0.045, h * 0.045), V3(h * 0.28, h * 0.7, h * 0.1), C.Graphite, SP, V3(0, 0, 90)) -- antenna
	B.blk(hd, V3(h * 0.09, h * 0.08, h * 0.09), V3(h * 0.28, h * 0.83, h * 0.1), C.Orange, SP)                 -- antenna tip

	-- ===== UPPER TORSO =====
	local T = Z.UpperTorso
	local W, H, D = T.X, T.Y, T.Z
	local ut = "UpperTorso"
	K.core(B, Z, ut, C.Steel, METAL)
	B.blk(ut, V3(W * 0.34, 0.14 * u, D * 0.5), V3(0, H * 0.5 + 0.02 * u, 0), C.Graphite, SP)                  -- neck ring
	B.blk(ut, V3(W * 0.76, H * 0.5, 0.08 * u), V3(0, H * 0.1, -D * 0.5 - 0.04 * u), C.Graphite, SP)         -- panel frame
	B.blk(ut, V3(W * 0.68, H * 0.42, 0.1 * u), V3(0, H * 0.1, -D * 0.5 - 0.09 * u), C.Orange, SP)             -- orange panel
	B.blk(ut, V3(W * 0.76, H * 0.1, 0.08 * u), V3(0, -H * 0.24, -D * 0.5 - 0.04 * u), C.GraphiteDark, SP)    -- hazard band
	for i = -2, 2 do
		B.blk(ut, V3(0.07 * u, 0.15 * u, 0.1 * u), V3(i * W * 0.14, -H * 0.24, -D * 0.5 - 0.075 * u), C.Orange, SP, V3(0, 0, 45)) -- hazard chevrons
	end
	B.blk(ut, V3(W * 0.12, 0.05 * u, 0.04 * u), V3(-W * 0.24, H * 0.3, -D * 0.5 - 0.16 * u), C.Glow, NEON)    -- status lamp (second glow)
	B.blk(ut, V3(W * 0.62, H * 0.62, 0.22 * u), V3(0, H * 0.06, D * 0.5 + 0.11 * u), C.Graphite, SP)          -- back pack
	B.blk(ut, V3(W * 0.4, H * 0.08, 0.26 * u), V3(0, H * 0.2, D * 0.5 + 0.13 * u), C.Orange, SP)              -- pack stripe
	for _, sg in { -1, 1 } do
		B.cyl(ut, V3(0.5 * u, 0.17 * u, 0.17 * u), V3(sg * W * 0.2, H * 0.37 + 0.12 * u, D * 0.5 + 0.12 * u), C.SteelDark, METAL, V3(0, 0, 90)) -- exhaust pipe
	end

	-- ===== LOWER TORSO =====
	local LT = Z.LowerTorso
	local lt = "LowerTorso"
	K.core(B, Z, lt, C.Graphite, SP, 1.02)
	B.blk(lt, V3(LT.X * 1.06, 0.12 * u, LT.Z * 1.08), V3(0, LT.Y * 0.1, 0), C.SteelDark, METAL)
	B.blk(lt, V3(LT.X * 0.3, LT.Y * 0.8, 0.08 * u), V3(0, -LT.Y * 0.04, -LT.Z * 0.5 - 0.04 * u), C.SteelDark, METAL) -- groin plate
	for _, sg in { -1, 1 } do
		B.blk(lt, V3(0.16 * u, LT.Y * 0.9, LT.Z * 0.7), V3(sg * (LT.X * 0.5 + 0.08 * u), -LT.Y * 0.04, 0), C.Graphite, SP)  -- hip pod
		B.cyl(lt, V3(0.08 * u, 0.26 * u, 0.26 * u), V3(sg * (LT.X * 0.5 + 0.2 * u), -LT.Y * 0.04, 0), C.SteelDark, METAL)    -- pod cap
	end

	-- ===== ARMS =====
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local ua, la = side .. "UpperArm", side .. "LowerArm"
		local A, L = Z[ua], Z[la]
		K.core(B, Z, ua, C.Steel, METAL)
		B.blk(ua, V3(A.X * 1.2, 0.26 * u, A.Z * 1.2), V3(sg * 0.04 * u, A.Y * 0.5 - 0.02 * u, 0), side == "Left" and C.Orange or C.SteelDark, side == "Left" and SP or METAL) -- shoulder cap
		B.cyl(ua, V3(A.Y * 0.5, 0.16 * u, 0.16 * u), V3(sg * (A.X * 0.5 + 0.09 * u), A.Y * 0.04, 0), C.Graphite, METAL, V3(0, 0, 90))   -- shoulder piston
		K.band(B, Z, ua, -A.Y * 0.2, 0.2 * u, C.SteelDark, METAL, 1.1)
		K.core(B, Z, la, C.SteelDark, METAL)
		B.cyl(la, V3(L.X * 1.12, 0.32 * u, 0.32 * u), V3(0, L.Y * 0.5 - 0.04 * u, 0), C.Graphite, METAL)                                -- elbow joint
		for i = 0, 2 do
			B.blk(la, V3(L.X * 0.7, 0.04 * u, 0.04 * u), V3(0, L.Y * 0.1 - i * 0.14 * u, -L.Z * 0.5 - 0.02 * u), C.Graphite, SP)         -- forearm slats
		end
		K.band(B, Z, la, -L.Y * 0.5 + 0.2 * u, 0.28 * u, C.Graphite, SP, 1.1)
		if not opt.noHands then K.hand(B, Z, side, C.Graphite, C.Steel, C.SteelDark) end
	end

	-- ===== LEGS =====
	for _, side in { "Left", "Right" } do
		local sg = side == "Right" and 1 or -1
		local ul, ll = side .. "UpperLeg", side .. "LowerLeg"
		local U, L = Z[ul], Z[ll]
		K.core(B, Z, ul, C.Graphite, SP)
		B.blk(ul, V3(0.08 * u, U.Y * 0.5, U.Z * 0.6), V3(sg * (U.X * 0.5 + 0.04 * u), 0, 0), C.SteelDark, METAL)                          -- thigh side plate
		B.cyl(ul, V3(U.Y * 0.62, 0.16 * u, 0.16 * u), V3(0, 0, -U.Z * 0.5 - 0.09 * u), C.SteelDark, METAL, V3(0, 0, 90))                   -- thigh piston
		B.blk(ul, V3(0.24 * u, 0.08 * u, 0.12 * u), V3(0, U.Y * 0.33, -U.Z * 0.5 - 0.06 * u), C.Graphite, SP)                             -- piston mounts
		B.blk(ul, V3(0.24 * u, 0.08 * u, 0.12 * u), V3(0, -U.Y * 0.33, -U.Z * 0.5 - 0.06 * u), C.Graphite, SP)
		K.core(B, Z, ll, C.SteelDark, METAL)
		B.cyl(ll, V3(L.X * 1.1, 0.3 * u, 0.3 * u), J.ll(L).kn, C.Graphite, METAL)                                                          -- knee joint
		B.blk(ll, V3(L.X * 0.8, 0.3 * u, 0.1 * u), J.ll(L).kn + V3(0, 0, -L.Z * 0.5 - 0.05 * u), C.Steel, METAL)                            -- knee guard
		K.band(B, Z, ll, -L.Y * 0.08, 0.12 * u, C.Orange, SP, 1.06)                                                                        -- shin stripe
		K.band(B, Z, ll, -L.Y * 0.5 + 0.55 * u, 0.1 * u, C.Graphite, SP, 1.08)                                                             -- ankle ring
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
	DRESS[skin.base or skin.id](B, Z, C, {})
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

-- v5.16: the Poses module (optional: a place without it simply has no posed figures)
local PosesMod = nil
local function getPoses()
	if PosesMod == nil then
		local m = game:GetService("ReplicatedStorage"):FindFirstChild("Poses")
		local ok, r = false, nil
		if m then ok, r = pcall(require, m) end
		PosesMod = (ok and r) or false
	end
	return PosesMod or nil
end

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
	DRESS[skin.base or skin.id](B, Z, c, {}) -- v8: the block hands are part of the outfit (they ride on the forearm, see Update)

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
		local ok, d = pcall(GM.Describe, opts.weapon, "Iron", opts.gunSkin)
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

	local fig = { Model = model, HeadTop = NECK_Y + Z.h * 1.05, root = CFrame.new(), stance = opts.stance, pose = opts.pose, poseT = opts.poseT, -- v5.16: + a POSE
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
		if self.stance and goal[self.stance] ~= nil then goal[self.stance] = 1 end -- v11: a held stance (win lineup)
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
		-- v5.16 POSES: a posed figure (fig.pose = a Poses id) is solved FORWARD from the pose's joint angles instead (same joint space as the
		-- real character's Motor6D.Transform, see the Poses module). fig.poseT fixes the moment of an animated pose (pictures), else it plays.
		if self.pose and not hasGun then
			local Poses = getPoses()
			local J = Poses and Poses.Sample(self.pose, self.poseT or t)
			if J then
				local function ang(j) return j and CFrame.Angles(j[1] or 0, j[2] or 0, j[3] or 0) or CFrame.identity end
				local rj = J.Root or { 0, 0, 0, 0 }
				local hipC = V3(0, HIP_Y, 0)
				local rootCF = CFrame.new(0, (rj[4] or 0) * k * PR.Height, 0) * CFrame.new(hipC) * ang(rj) * CFrame.new(-hipC)
				base.LowerTorso = rootCF * CFrame.new(rest.LowerTorso)
				local waistP = V3(0, rest.LowerTorso.Y + sz.LowerTorso.Y * 0.5, 0)
				local waistCF = rootCF * CFrame.new(waistP) * ang(J.Waist) * CFrame.new(-waistP)
				base.UpperTorso = waistCF * CFrame.new(rest.UpperTorso)
				base.Head = waistCF * CFrame.new(0, NECK_Y, 0) * ang(J.Neck) * CFrame.new(0, rest.Head.Y - NECK_Y, 0)
				for _, side in { "Left", "Right" } do
					local sg = side == "Right" and 1 or -1
					local s1 = side == "Right" and "R" or "L"
					local shP = V3(sg * Z.shX, rest.UpperTorso.Y + sz.UpperTorso.Y * 0.352, 0)
					base[side .. "UpperArm"] = waistCF * CFrame.new(shP) * ang(J[s1 .. "Shoulder"]) * CFrame.new(-UA_SH(sg))
					base[side .. "LowerArm"] = base[side .. "UpperArm"] * CFrame.new(UA_EL) * ang(J[s1 .. "Elbow"]) * CFrame.new(-LA_EL)
					base[side .. "Hand"] = base[side .. "LowerArm"] * CFrame.new(LA_WR) * ang(J[s1 .. "Wrist"]) * CFrame.new(0, -sz.RightHand.Y * 0.417, 0)
					local hip = V3(rest[side .. "UpperLeg"].X, HIP_Y, 0)
					base[side .. "UpperLeg"] = rootCF * CFrame.new(hip) * ang(J[s1 .. "Hip"]) * CFrame.new(rest[side .. "UpperLeg"] - hip)
					base[side .. "LowerLeg"] = base[side .. "UpperLeg"] * CFrame.new(0, -sz[side .. "UpperLeg"].Y * 0.329, 0) * ang(J[s1 .. "Knee"])
						* CFrame.new(0, -sz[side .. "LowerLeg"].Y * 0.334, 0)
					base[side .. "Foot"] = base[side .. "LowerLeg"] * CFrame.new(0, -sz[side .. "LowerLeg"].Y * 0.459, 0) * ang(J[s1 .. "Ankle"])
						* CFrame.new(0, -sz[side .. "Foot"].Y * 0.333, 0)
				end
			end
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
