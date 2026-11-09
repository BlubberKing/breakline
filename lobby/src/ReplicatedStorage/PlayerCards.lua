-- PlayerCards v4 (ModuleScript in ReplicatedStorage, named "PlayerCards") - LOBBY place only. NEW in v5.11, v2 in v5.12, v3 in v5.13, v4 in v5.16.
-- v5.16: (1) a COSTUME in a showcase slot can hold a POSE (PlayerCard.poses = { 3 x pose id / "" }, set with ADD POSE in the cosmetics locker); the
--   item pictures are cached per item + pose (PC.MakeView / ViewCam / BuildItem / ShowcaseItem take the pose as their last argument). (2) the TITLE
--   the player wears (data.title, Titles module) sits above the name when PlayerCard.showTitle is on (default on). PC.Read returns poses + showTitle.
-- v5.13 (owner Nov 7): (1) every showcase item also keeps the ANGLE the player gave it in the REPOSITION view: placement fields yaw / pitch (degrees).
--   A skin / gun skin is turned any way (yaw all round, pitch up to PC.PITCH_MAX), exactly like the drag-to-turn in the cosmetics shop, and re-fitted
--   into its box at that angle. A power-up card can only lean a little (PC.CARD_TILT degrees left / right / up / down): it is drawn as a real
--   perspective picture cut from the baked card sheet (PC.TiltCard, an 8 x 8 grid of image pieces + the live text placed on top), no image upload.
--   Old saves have no yaw / pitch = 0 = the old look. (2) the LV and the level number next to the name are a bit bigger (LV 14 -> 17 px, number 20 -> 25 px).
-- v5.12 (owner Nov 7): the card layout changed and the 3 showcase items are FREE: the player moves, resizes and turns each one on the card
--   (cosmetics locker, PLAYER CARD tab). No more dark boxes behind the items. The INFO always sits on top of the items:
--     top right  = a small avatar picture (half the old size)
--     left of it = DISPLAY NAME with a small LV n right next to it, the real Roblox @username right under the name
--     top left   = PARTY LEADER / READY tags
--   Each item has a placement { x, y, s, r }: x / y = its centre on the 840 x 236 card, s = size (1 = the old slot size 112 x 196), r = turn in degrees
--   (clockwise). Default = the three old slot spots. Saved inside PlayerCard.pos (3 entries), checked + clamped by CosmeticsServer.
--   Item pictures are built ONCE per item and cloned after that (PC.MakeView), so re-drawing a card never makes the models blink.
-- The PLAYER CARD every player shows in the lobby play screen (yours on top, your party under it).
-- Everything is drawn from GUI frames in code (no image uploads). Some banners move a little (tweens that loop, no per-frame code).
-- Saved in the profile as PlayerCard = { bg = <banner id>, show = { 3 x "skin:ID" / "gun:ID" / "card:ID" / "" }, pos = { 3 x { x, y, s, r } } }, mirrored to the
-- Player attribute PlayerCardJson (everybody's client reads it). Bought banners: profile BannersOwned (attribute BannersOwnedJson).
--   PC.Banners / PC.ById[id] / PC.Order          banner list: { id, name, price = nil | { souls = n } | { essence = n }, anim }
--   PC.IsFree(id)                                 free banners belong to everybody
--   PC.Read(player) -> { bg, show = {3}, pos = {3} }  the card a player shows (defaults filled in)
--   PC.Parse(value) -> kind, id                   "skin:ID" -> "skin", "ID"  (kinds: skin / gun / card)
--   PC.DefaultPlace(i) / PC.CleanPlace(t, i, kind) placement of showcase item i (defaults / a checked copy). v5.13: { x, y, s, r, yaw, pitch }
--   PC.MakeView(value, boxW, boxH, vpW, vpH, yaw, pitch) / PC.ViewCam(...)   3D picture of a skin / gun skin (v5.13: at any angle)
--   PC.TiltCard(parent, cardId, width) -> { holder, set(yaw, pitch) }        v5.13: a power-up card leaning in 3D (baked cards only, else nil)
--   PC.DrawBanner(parent, id, animate)            fills `parent` (any size) with the banner
--   PC.Render(parent, data, width) -> holder, card, items
--                                                 a whole card. data = { userId, name, username, level, leader, ready, card = {bg, show, pos}, empty }
--                                                 holder = native 840 x 236 scaled to `width`; items[i] = { holder, apply(place), kind } for the editor
--   PC.BuildItem(parent, value, place, z)         one free showcase item on a card (native coordinates)
--   PC.ShowcaseItem(slot, value, w, h)            draws one showcase item fitted into a frame (w / h = the frame size in its own, unscaled pixels)
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local UI = require(RS:WaitForChild("UIKit"))
local K, F, new = UI.C, UI.F, UI.new

local PC = {}
PC.W, PC.H = 840, 236 -- native card size (the lobby uses it 1:1, the editor scales it)
local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

-- ================= small drawing helpers =================
local function fill(parent, color, transp, z)
	return new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = transp or 0, BorderSizePixel = 0, ZIndex = z or 1 }, parent)
end
local function vgrad(o, c0, c1, rot)
	return new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 90 }, o)
end
local function dot(parent, sx, sy, d, color, transp)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(sx, sy), Size = UDim2.fromOffset(d, d),
		BackgroundColor3 = color, BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	return f
end
local function blob(parent, sx, sy, sw, sh, color, transp, rot)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(sx, sy), Size = UDim2.fromScale(sw, sh), Rotation = rot or 0,
		BackgroundColor3 = color, BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	return f
end
local function band(parent, sx, sy, sw, sh, color, transp, rot)
	return new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(sx, sy), Size = UDim2.fromScale(sw, sh), Rotation = rot or 0,
		BackgroundColor3 = color, BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
end
-- soft edges: a frame faded left + right (or top + bottom)
local function soft(o, rot)
	new("UIGradient", { Rotation = rot or 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1) }) }, o)
end
local function loop(o, t, goal, style, reverse, delay)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, reverse ~= false, delay or 0), goal)
	tw:Play()
	return tw
end

-- ================= the banners =================
local B = {}
PC.Banners = {
	{ id = "SLATE", name = "SLATE" },
	{ id = "BREAKLINE", name = "BREAKLINE" },
	{ id = "STARFIELD", name = "STARFIELD", anim = true },
	{ id = "WALLPUSH", name = "WALL PUSH", price = { souls = 600 } },
	{ id = "WATERCOLOUR", name = "WATERCOLOUR", price = { souls = 800 } },
	{ id = "GALAXY", name = "GALAXY", price = { souls = 900 }, anim = true },
	{ id = "SOULFIRE", name = "SOULFIRE", price = { souls = 1200 }, anim = true },
	{ id = "EMBER", name = "EMBER", price = { essence = 150 }, anim = true },
	{ id = "GILDED", name = "GILDED", price = { essence = 250 }, anim = true },
	{ id = "VOIDRIFT", name = "VOID RIFT", price = { essence = 350 }, anim = true },
}
PC.ById, PC.Order = {}, {}
for _, b in PC.Banners do PC.ById[b.id] = b table.insert(PC.Order, b.id) end
PC.Default = "SLATE"
function PC.Is(id) return type(id) == "string" and PC.ById[id] ~= nil end
function PC.IsFree(id) local b = PC.ById[id]; return b ~= nil and b.price == nil end

B.SLATE = function(h)
	vgrad(fill(h, WHITE), rgb(34, 37, 45), rgb(14, 15, 19), 20)
	for i = 0, 9 do band(h, 0.55 + i * 0.06, 0.5, 0.004, 2.2, WHITE, 0.93, 28) end
	band(h, 0.03, 0.9, 0.06, 0.02, K.red, 0)
end
B.BREAKLINE = function(h, anim)
	vgrad(fill(h, WHITE), rgb(18, 18, 22), rgb(6, 6, 8), 0)
	local glow = band(h, 0.62, 0.5, 0.14, 2.4, K.red, 0.7, 24)
	soft(glow)
	band(h, 0.62, 0.5, 0.012, 2.4, rgb(255, 90, 96), 0, 24)
	if anim then loop(glow, 2.4, { BackgroundTransparency = 0.5 }) end
	for i = 1, 5 do band(h, 0.08 * i, 0.08, 0.04, 0.012, WHITE, 0.85) end
end
B.STARFIELD = function(h, anim)
	vgrad(fill(h, WHITE), rgb(14, 20, 44), rgb(4, 5, 12), 90)
	local haze = band(h, 0.7, 0.6, 0.9, 0.8, rgb(60, 80, 160), 0.85)
	soft(haze, 0)
	local rng = Random.new(11)
	for i = 1, 46 do
		local big = rng:NextNumber() < 0.15
		local d = dot(h, rng:NextNumber(), rng:NextNumber(), big and 3 or 2, i % 7 == 0 and rgb(255, 230, 210) or WHITE, rng:NextNumber(0.1, 0.6))
		if anim and (big or i % 4 == 0) then loop(d, rng:NextNumber(1.2, 2.6), { BackgroundTransparency = 0.9 }, nil, true, rng:NextNumber(0, 2)) end
	end
end
B.WALLPUSH = function(h)
	vgrad(fill(h, WHITE), rgb(20, 22, 28), rgb(10, 11, 14), 90)
	local red = band(h, 0.25, 0.5, 0.5, 1, K.red, 0.86)
	local blue = band(h, 0.75, 0.5, 0.5, 1, rgb(48, 116, 226), 0.86)
	new("UIGradient", { Transparency = NumberSequence.new(0.4, 1) }, red)
	new("UIGradient", { Transparency = NumberSequence.new(1, 0.4) }, blue)
	for i = 1, 13 do band(h, i / 14, 0.5, 0.002, 1, WHITE, 0.9) end
	for i = 1, 4 do band(h, 0.5, i / 5, 1, 0.006, WHITE, 0.9) end
	band(h, 0.6, 0.5, 0.008, 0.9, WHITE, 0.1)
	for i = 1, 3 do
		band(h, 0.585, i / 4, 0.022, 0.08, K.red, 0.15)
		band(h, 0.615, i / 4, 0.022, 0.08, rgb(48, 116, 226), 0.5)
	end
end
B.WATERCOLOUR = function(h)
	fill(h, rgb(246, 240, 230))
	local cols = { rgb(255, 196, 206), rgb(255, 222, 186), rgb(255, 242, 178), rgb(196, 238, 210), rgb(186, 222, 255), rgb(222, 204, 255) }
	local rng = Random.new(5)
	for i = 1, 16 do
		blob(h, rng:NextNumber(-0.05, 1.05), rng:NextNumber(-0.1, 1.1), rng:NextNumber(0.18, 0.4), rng:NextNumber(0.5, 1.1), cols[(i - 1) % #cols + 1], rng:NextNumber(0.35, 0.6), rng:NextNumber(-30, 30))
	end
	local shade = fill(h, rgb(10, 10, 14), 0)
	new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.55, 0.85), NumberSequenceKeypoint.new(1, 1) }) }, shade)
end
B.GALAXY = function(h, anim)
	vgrad(fill(h, WHITE), rgb(10, 10, 24), rgb(3, 3, 8), 90)
	local spin = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.7, 0.5), Size = UDim2.fromOffset(460, 460), BackgroundTransparency = 1 }, h)
	local disk = blob(spin, 0.5, 0.5, 1, 0.34, rgb(90, 110, 200), 0.75)
	soft(disk, 0)
	local core = blob(spin, 0.5, 0.5, 0.22, 0.12, rgb(255, 238, 220), 0.25)
	soft(core, 0)
	local rng = Random.new(3)
	for arm = 0, 1 do
		for i = 1, 26 do
			local u = i / 26
			local a = arm * math.pi + u * 3.4
			local r = 0.06 + u * 0.42
			dot(spin, 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r * 0.36, rng:NextNumber() < 0.2 and 3 or 2, u < 0.3 and rgb(255, 236, 220) or rgb(200, 214, 255), 0.15 + u * 0.5)
		end
	end
	if anim then
		TweenService:Create(spin, TweenInfo.new(90, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
		loop(core, 3, { BackgroundTransparency = 0.5 })
	end
end
B.SOULFIRE = function(h, anim)
	vgrad(fill(h, WHITE), rgb(10, 30, 50), rgb(4, 8, 16), 90)
	local glow = band(h, 0.7, 1, 0.9, 0.7, K.soul, 0.7)
	soft(glow, 0)
	local rng = Random.new(8)
	for i = 1, 9 do
		local s = rng:NextInteger(16, 30)
		local g = UI.SoulIcon(h, s)
		local x = 0.42 + rng:NextNumber() * 0.56
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.new(x, 0, 1.1, 0)
		if anim then
			local t = rng:NextNumber(4, 7)
			TweenService:Create(g, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false, rng:NextNumber(0, 4)),
				{ Position = UDim2.new(x + rng:NextNumber(-0.05, 0.05), 0, -0.15, 0) }):Play()
		else
			g.Position = UDim2.new(x, 0, rng:NextNumber(0.15, 0.9), 0)
		end
	end
	if anim then loop(glow, 2.2, { BackgroundTransparency = 0.82 }) end
end
B.EMBER = function(h, anim)
	vgrad(fill(h, WHITE), rgb(70, 16, 12), rgb(14, 4, 4), 90)
	local heat = band(h, 0.65, 1.05, 1.1, 0.8, rgb(255, 120, 40), 0.55)
	soft(heat, 0)
	if anim then loop(heat, 1.6, { BackgroundTransparency = 0.75 }) end
	local rng = Random.new(2)
	for _ = 1, 22 do
		local x = rng:NextNumber(0.3, 1)
		local e = dot(h, x, rng:NextNumber(0.2, 1.05), rng:NextInteger(2, 4), rng:NextNumber() < 0.5 and rgb(255, 170, 70) or rgb(255, 90, 40), 0.1)
		if anim then
			e.Position = UDim2.fromScale(x, 1.05)
			TweenService:Create(e, TweenInfo.new(rng:NextNumber(2.2, 4.5), Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, rng:NextNumber(0, 3)),
				{ Position = UDim2.fromScale(x + rng:NextNumber(-0.08, 0.08), -0.05), BackgroundTransparency = 1 }):Play()
		end
	end
end
B.GILDED = function(h, anim)
	vgrad(fill(h, WHITE), rgb(26, 22, 14), rgb(8, 7, 4), 0)
	for i = 0, 4 do band(h, 0.45 + i * 0.13, 0.5, 0.05, 2.4, rgb(236, 196, 92), 0.78 - i * 0.04, 32) end
	local frameIn = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -14, 1, -14), BackgroundTransparency = 1 }, h)
	new("UIStroke", { Color = rgb(236, 196, 92), Thickness = 1.5, Transparency = 0.2 }, frameIn)
	local shine = band(h, 0.5, 0.5, 0.18, 2.6, rgb(255, 240, 190), 0.6, 32)
	soft(shine)
	shine.Position = UDim2.fromScale(-0.2, 0.5)
	if anim then TweenService:Create(shine, TweenInfo.new(3.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 1.5), { Position = UDim2.fromScale(1.2, 0.5) }):Play() end
end
B.VOIDRIFT = function(h, anim)
	vgrad(fill(h, WHITE), rgb(30, 10, 54), rgb(6, 2, 12), 0)
	local rift = band(h, 0.7, 0.5, 0.2, 2.6, K.essence, 0.55, -18)
	soft(rift)
	band(h, 0.7, 0.5, 0.01, 2.6, K.essencePale, 0, -18)
	if anim then loop(rift, 1.8, { BackgroundTransparency = 0.8, Size = UDim2.fromScale(0.32, 2.6) }) end
	local rng = Random.new(9)
	for i = 1, 5 do
		local g = UI.EssenceIcon(h, rng:NextInteger(12, 22))
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(rng:NextNumber(0.45, 0.97), rng:NextNumber(0.12, 0.88))
		if anim then loop(g, rng:NextNumber(2, 3.5), { Position = g.Position + UDim2.fromScale(0, -0.06) }, nil, true, i * 0.3) end
	end
end

function PC.DrawBanner(parent, id, animate)
	local b = PC.ById[id] or PC.ById[PC.Default]
	local h = new("Frame", { Name = "Banner", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, parent)
	local ok, err = pcall(B[b.id], h, animate and b.anim)
	if not ok then warn("[PlayerCards] banner", b.id, err) end
	return h
end

-- ================= saved card =================
function PC.Parse(v)
	if type(v) ~= "string" then return nil end
	local kind, id = string.match(v, "^(%a+):(.+)$")
	if kind == "skin" or kind == "gun" or kind == "card" then return kind, id end
	return nil
end

-- v5.12: free placement of the 3 showcase items. The default = the three old slot spots (right side of the card).
PC.SW, PC.SH = 112, 196                 -- the item box at size 1 (the old slot size)
PC.SCALE_MIN, PC.SCALE_MAX = 0.35, 2.5
PC.CARD_TILT = 15  -- v5.13: a power-up card leans at most this many degrees each way (REPOSITION view)
PC.PITCH_MAX = 72  -- v5.13: how far a skin / gun skin can be tipped toward / away from you (the same limit as the shop preview)
local SLOT_GAP = 10
function PC.DefaultPlace(i)
	local x0 = PC.W - 20 - 3 * PC.SW - 2 * SLOT_GAP
	return { x = x0 + (i - 1) * (PC.SW + SLOT_GAP) + PC.SW / 2, y = PC.H / 2, s = 1, r = 0, yaw = 0, pitch = 0 }
end
local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function wrap180(a)
	a = a % 360
	if a > 180 then a -= 360 end
	return a
end
-- a checked copy of a placement (anything odd falls back to the default spot). The server uses the same function.
-- v5.13: yaw / pitch (the REPOSITION angle) are optional (missing = 0, so old saves keep their look); kind = "card" limits them to PC.CARD_TILT.
function PC.CleanPlace(t, i, kind)
	if type(t) ~= "table" or not (num(t.x) and num(t.y) and num(t.s) and num(t.r)) then return PC.DefaultPlace(i) end
	local yaw = num(t.yaw) and wrap180(t.yaw) or 0
	local pitch = num(t.pitch) and t.pitch or 0
	if kind == "card" then
		yaw = math.clamp(yaw, -PC.CARD_TILT, PC.CARD_TILT)
		pitch = math.clamp(pitch, -PC.CARD_TILT, PC.CARD_TILT)
	else
		pitch = math.clamp(pitch, -PC.PITCH_MAX, PC.PITCH_MAX)
	end
	return {
		x = math.floor(math.clamp(t.x, 0, PC.W) * 10 + 0.5) / 10,
		y = math.floor(math.clamp(t.y, 0, PC.H) * 10 + 0.5) / 10,
		s = math.floor(math.clamp(t.s, PC.SCALE_MIN, PC.SCALE_MAX) * 100 + 0.5) / 100,
		r = math.floor(wrap180(t.r) * 10 + 0.5) / 10,
		yaw = math.floor(yaw * 10 + 0.5) / 10,
		pitch = math.floor(pitch * 10 + 0.5) / 10,
	}
end

function PC.Read(player)
	local out = { bg = PC.Default, show = { "", "", "" }, pos = { PC.DefaultPlace(1), PC.DefaultPlace(2), PC.DefaultPlace(3) },
		poses = { "", "", "" }, showTitle = true } -- v5.16: + the pose each showcase COSTUME holds, + the title switch
	local raw = player and player:GetAttribute("PlayerCardJson")
	if type(raw) == "string" and raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" then
			if PC.Is(t.bg) then out.bg = t.bg end
			if type(t.show) == "table" then
				for i = 1, 3 do if PC.Parse(t.show[i]) then out.show[i] = t.show[i] end end
			end
			if type(t.pos) == "table" then
				for i = 1, 3 do out.pos[i] = PC.CleanPlace(t.pos[i], i, (PC.Parse(out.show[i]))) end
			end
			if type(t.poses) == "table" then -- v5.16
				for i = 1, 3 do
					local pz = t.poses[i]
					if type(pz) == "string" and PC.Parse(out.show[i]) == "skin" then out.poses[i] = pz end
				end
			end
			if type(t.showTitle) == "boolean" then out.showTitle = t.showTitle end
		end
	end
	return out
end

-- ================= showcase items =================
local Skins, GunSkins, GunModels, CardArt
local function mods()
	if not Skins then
		Skins = require(RS:WaitForChild("Skins"))
		GunSkins = require(RS:WaitForChild("GunSkins"))
		GunModels = require(RS:WaitForChild("GunModels"))
		local ca = RS:FindFirstChild("CardArt")
		CardArt = ca and require(ca) or nil
	end
end

function PC.ItemName(v)
	mods()
	local kind, id = PC.Parse(v)
	if kind == "skin" and Skins.Is(id) then
		local s = Skins.Get(id)
		if s.base then return Skins.Get(s.base).name .. "  " .. s.name end
		return s.name
	elseif kind == "gun" and GunSkins.ById[id] then
		local g = GunSkins.ById[id]
		return g.gunName .. "  " .. g.name
	elseif kind == "card" then
		local Cards = require(RS:WaitForChild("Cards"))
		local c = Cards.ById[id]
		return c and string.upper(c.name) or ""
	end
	return ""
end

-- v5.12: 3D item pictures are built ONCE (a template ViewportFrame) and cloned after that: cloning is instant, so a card that is re-drawn
-- (a new background, an equip somewhere else, a party change) shows its models in the same frame - nothing blinks out and back in.
local TPL_MAX = 60
local tpl, tplOrder = {}, {}
local function buildTemplate(value, pose)
	mods()
	local kind, id = PC.Parse(value)
	if kind ~= "skin" and kind ~= "gun" then return nil end
	local vp = new("ViewportFrame", { BackgroundTransparency = 1, Ambient = rgb(150, 152, 160), LightColor = rgb(255, 250, 244),
		LightDirection = Vector3.new(-0.5, -0.9, -0.4) })
	local cam = new("Camera", { FieldOfView = 20 }, vp)
	vp.CurrentCamera = cam
	local model = new("Model", {}, vp)
	local dir, fov, pad
	if kind == "skin" then
		if not Skins.Is(id) then vp:Destroy() return nil end
		-- v5.16: a costume can hold a POSE on the card (an animated pose is shown at its picture moment, Poses.ById[pose].still)
		local P = (pose and pose ~= "") and RS:FindFirstChild("Poses") and require(RS.Poses) or nil
		local pd = P and P.ById[pose] or nil
		local ok, fig = pcall(Skins.NewFigure, model, id, { static = true, pose = pd and pose or nil, poseT = pd and (pd.still or 0) or nil })
		if ok and fig then pcall(fig.Update, fig, 0, 0) end
		dir, fov, pad = Vector3.new(0.28, 0.1, 1), 22, 0.06
	else
		if not GunSkins.ById[id] then vp:Destroy() return nil end
		local ok, desc = pcall(GunModels.Describe, GunSkins.ById[id].gun, "Iron", id)
		if ok and desc then
			for _, d in desc.Parts do
				if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
					local p = new("Part", { Anchored = true, Size = d.Size, CFrame = d.CF, Color = d.Color, Material = d.Material or Enum.Material.SmoothPlastic,
						Transparency = d.Transparency or 0, Reflectance = d.Reflectance or 0 }, model)
					if d.Shape then p.Shape = d.Shape end
				end
			end
		end
		-- a gun is long and the box is tall: seen from the side, turned so it fills the box
		dir, fov, pad = Vector3.new(1, 0.25, 0.55), 18, 0.08
	end
	local pts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local h, cf = p.Size / 2, p.CFrame
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				table.insert(pts, cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
			end end end
		end
	end
	if #pts == 0 then vp:Destroy() return nil end
	local center = Vector3.zero
	for _, q in pts do center += q end
	center /= #pts
	dir = dir.Unit
	local rot = CFrame.lookAt(Vector3.zero, -dir, Vector3.yAxis)
	local rel = {}
	for i, q in pts do rel[i] = q - center end
	return { vp = vp, rel = rel, center = center, rot = rot, fov = fov, pad = pad }
end
local function template(value, pose)
	local key = value .. "|" .. tostring(pose or "") -- v5.16: one template per item + pose
	local e = tpl[key]
	if e then
		local i = table.find(tplOrder, key)
		if i then table.remove(tplOrder, i) end
		table.insert(tplOrder, key)
		return e
	end
	e = buildTemplate(value, pose)
	if not e then return nil end
	tpl[key] = e
	table.insert(tplOrder, key)
	while #tplOrder > TPL_MAX do
		local k = table.remove(tplOrder, 1)
		local old = tpl[k]
		tpl[k] = nil
		if old then old.vp:Destroy() end
	end
	return e
end
-- v5.13: the camera turn for a REPOSITION angle. yaw = round the model (same sense as the shop preview), pitch = from above (+) / below (-).
local function viewRot(e, yaw, pitch)
	return CFrame.Angles(0, math.rad(yaw or 0), 0) * e.rot * CFrame.Angles(-math.rad(pitch or 0), 0, 0)
end
-- camera that fits the model into a boxW x boxH box in the middle of a vpW x vpH viewport (never cropped), looking along `rot`
local function fitCam(e, rot, boxW, boxH, vpW, vpH, pad)
	local loc = table.create(#e.rel)
	for i, q in e.rel do loc[i] = rot:PointToObjectSpace(q) end
	local tv = math.tan(math.rad(e.fov / 2))
	local tvb = tv * (boxH / vpH) * (1 - pad)
	local thb = tv * (vpW / vpH) * (boxW / vpW) * (1 - pad)
	local ox, oy, dist = 0, 0, 1
	for _ = 1, 3 do
		dist = 0
		for _, q in loc do
			local need = math.max(math.abs(q.X - ox) / thb, math.abs(q.Y - oy) / tvb) + q.Z
			if need > dist then dist = need end
		end
		dist += 0.05
		local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
		for _, q in loc do
			local d = dist - q.Z
			local sx, sy = (q.X - ox) / d, (q.Y - oy) / d
			minX, maxX, minY, maxY = math.min(minX, sx), math.max(maxX, sx), math.min(minY, sy), math.max(maxY, sy)
		end
		ox += (minX + maxX) / 2 * dist
		oy += (minY + maxY) / 2 * dist
	end
	return CFrame.new(e.center) * rot * CFrame.new(ox, oy, dist)
end
-- v5.13: just the camera for a skin / gun skin at a REPOSITION angle (the REPOSITION view calls it every frame while you turn the model)
function PC.ViewCam(value, boxW, boxH, vpW, vpH, yaw, pitch, pose)
	local e = template(value, pose)
	if not e then return nil end
	return fitCam(e, viewRot(e, yaw, pitch), boxW, boxH, vpW, vpH, e.pad)
end
-- a ViewportFrame (vpW x vpH) showing a skin / gun skin fitted into a boxW x boxH box in its middle. Returns vp, camera, base camera CFrame.
-- v5.13: yaw / pitch = the REPOSITION angle (0, 0 = the old default view)
function PC.MakeView(value, boxW, boxH, vpW, vpH, yaw, pitch, pose)
	local e = template(value, pose)
	if not e then return nil end
	local vp = e.vp:Clone()
	local cam = vp:FindFirstChildOfClass("Camera")
	vp.CurrentCamera = cam
	cam.FieldOfView = e.fov
	local base = fitCam(e, viewRot(e, yaw, pitch), boxW, boxH, vpW, vpH, e.pad)
	cam.CFrame = base
	vp.Size = UDim2.fromOffset(vpW, vpH)
	return vp, cam, base
end

-- one item fitted into a frame (shop / locker thumbnails)
function PC.ShowcaseItem(slot, v, sw, sh, pose)
	mods()
	local kind, id = PC.Parse(v)
	if not kind then return nil end
	local w = sw or slot.AbsoluteSize.X
	local hgt = sh or slot.AbsoluteSize.Y
	if kind == "card" then
		if not CardArt then return nil end
		-- the card is 250 x 350: fit it inside the slot with a small margin
		local cw = math.floor(math.min(w * 0.82, hgt * 0.86 * 250 / 350))
		local ok, holder = pcall(CardArt.Build, slot, id, { width = math.max(40, cw), anim = false })
		if ok and holder then
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position = UDim2.fromScale(0.5, 0.5)
		end
		return holder
	end
	local vp = PC.MakeView(v, w, hgt, w, hgt, nil, nil, pose)
	if not vp then return nil end
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	vp.Position = UDim2.fromScale(0.5, 0.5)
	vp.Parent = slot
	return vp
end

-- ================= v5.13: a power-up card leaning a little in 3D =================
-- A GUI frame cannot be tilted in 3D and a ViewportFrame cannot show SurfaceGuis (the card text), so the card is drawn from its BAKED sheet picture
-- (CardArt.SHEETS) cut into an 8 x 8 grid of ImageLabels: every piece is placed where a perspective camera would see it, the far side a touch darker.
-- The name / description / rarity text is the card's own live text, moved + scaled with the surface under it. Cards that are not baked return nil
-- (they simply stay flat). yaw > 0 = the right edge leans away, pitch > 0 = the top edge leans away. Both are limited to PC.CARD_TILT.
local TILT_N = 8      -- grid pieces per side
local TILT_D = 3.2    -- camera distance in card widths (smaller = stronger perspective)
local TILT_SHADE = rgb(150, 150, 164)
function PC.TiltCard(parent, id, width)
	mods()
	if not CardArt then return nil end
	local ok, src = pcall(CardArt.Build, nil, id, { width = 250, anim = false })
	if not ok or not src then return nil end
	local card = src:FindFirstChild("Card")
	local face = card and card:FindFirstChild("Face")
	if not (face and face:IsA("ImageLabel")) then src:Destroy() return nil end -- not a baked card: stays flat
	local W0, H0 = 250, 350
	local hgt = width * H0 / W0
	local holder = new("Frame", { Name = "TiltCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, hgt), BackgroundTransparency = 1 }, parent)
	local cw, ch = W0 / TILT_N, H0 / TILT_N
	local cells = {}
	for j = 0, TILT_N - 1 do
		for i = 0, TILT_N - 1 do
			local c = new("ImageLabel", { BackgroundTransparency = 1, BorderSizePixel = 0, Image = face.Image, ScaleType = Enum.ScaleType.Stretch,
				ImageRectOffset = face.ImageRectOffset + Vector2.new(i * cw, j * ch), ImageRectSize = Vector2.new(cw, ch), ZIndex = 1 }, holder)
			table.insert(cells, { c, i * cw, j * ch })
		end
	end
	local labels = {}
	for _, l in card:GetChildren() do
		if l:IsA("TextLabel") then
			local sz = Vector2.new(l.Size.X.Offset, l.Size.Y.Offset)
			local ap = l.AnchorPoint
			local cx = l.Position.X.Offset + sz.X * (0.5 - ap.X)
			local cy = l.Position.Y.Offset + sz.Y * (0.5 - ap.Y)
			local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(sz.X, sz.Y), BackgroundTransparency = 1, ZIndex = 2 }, holder)
			local us = new("UIScale", {}, box)
			local lc = l:Clone()
			lc.AnchorPoint, lc.Position, lc.Size, lc.ZIndex = Vector2.zero, UDim2.new(), UDim2.fromOffset(sz.X, sz.Y), 3
			lc.Parent = box
			table.insert(labels, { box, us, cx, cy })
		end
	end
	src:Destroy()
	local k = width / W0
	local o = { holder = holder }
	function o.set(yaw, pitch)
		local ya = math.rad(math.clamp(yaw or 0, -PC.CARD_TILT, PC.CARD_TILT))
		local pa = math.rad(math.clamp(pitch or 0, -PC.CARD_TILT, PC.CARD_TILT))
		local cyw, syw, cp, sp = math.cos(ya), math.sin(ya), math.cos(pa), math.sin(pa)
		local function proj(u, v)
			local x, y = (u - W0 / 2) / W0, (v - H0 / 2) / W0
			local z = x * syw - y * sp -- > 0 = further away
			local f = TILT_D / (TILT_D + z)
			return width / 2 + x * cyw * f * width, hgt / 2 + y * cp * f * width, f, z
		end
		for _, e in cells do
			local u0, v0 = e[2], e[3]
			local x1, y1 = proj(u0, v0)
			local x2, y2 = proj(u0 + cw, v0)
			local x3, y3 = proj(u0, v0 + ch)
			local x4, y4 = proj(u0 + cw, v0 + ch)
			local minX, maxX = math.min(x1, x2, x3, x4), math.max(x1, x2, x3, x4)
			local minY, maxY = math.min(y1, y2, y3, y4), math.max(y1, y2, y3, y4)
			e[1].Position = UDim2.fromOffset(minX - 0.4, minY - 0.4) -- a hair of overlap so no seams show between the pieces
			e[1].Size = UDim2.fromOffset(maxX - minX + 0.8, maxY - minY + 0.8)
			local _, _, _, z = proj(u0 + cw / 2, v0 + ch / 2)
			e[1].ImageColor3 = WHITE:Lerp(TILT_SHADE, math.clamp(z * 1.6, 0, 0.35))
		end
		for _, e in labels do
			local px, py, f = proj(e[3], e[4])
			e[1].Position = UDim2.fromOffset(px, py)
			e[2].Scale = k * f * (cyw + cp) / 2
		end
	end
	o.set(0, 0)
	return o
end

-- v5.12: one FREE showcase item on a card. parent = the card frame (native 840 x 236 pixels). place = { x, y, s, r }.
-- Cards turn with the GUI Rotation. A ViewportFrame cannot be rotated, so a 3D item sits in a square viewport big enough for any turn
-- (the diagonal of its box) and the CAMERA rolls instead - it looks exactly the same.
-- Returns { holder, kind, apply(place), place } or nil.
function PC.BuildItem(parent, v, place, z, pose)
	mods()
	local kind, id = PC.Parse(v)
	if not kind then return nil end
	local SW, SH = PC.SW, PC.SH
	local holder = new("Frame", { Name = "Item", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(SW, SH), BackgroundTransparency = 1, ZIndex = z or 3 }, parent)
	local scale = new("UIScale", { Scale = 1 }, holder)
	local it = { holder = holder, kind = kind }
	local cam, base, baseKey
	local flatCard, tilt, cw
	local D = math.ceil(math.sqrt(SW * SW + SH * SH)) + 4
	if kind == "card" then
		if not CardArt then holder:Destroy() return nil end
		cw = math.max(40, math.floor(math.min(SW * 0.96, SH * 0.98 * 250 / 350)))
		local ok, c = pcall(CardArt.Build, holder, id, { width = cw, anim = false })
		if ok and c then
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.fromScale(0.5, 0.5)
			flatCard = c
		end
	else
		local p0 = place or PC.DefaultPlace(1)
		local vp
		vp, cam, base = PC.MakeView(v, SW, SH, D, D, p0.yaw, p0.pitch, pose)
		if not vp then holder:Destroy() return nil end
		baseKey = tostring(p0.yaw or 0) .. ":" .. tostring(p0.pitch or 0)
		vp.AnchorPoint = Vector2.new(0.5, 0.5)
		vp.Position = UDim2.fromScale(0.5, 0.5)
		vp.Parent = holder
	end
	function it.apply(p)
		it.place = p
		holder.Position = UDim2.fromOffset(p.x, p.y)
		scale.Scale = p.s
		if cam then
			holder.Rotation = 0
			-- v5.13: a new REPOSITION angle = re-fit the model at that angle (only when it changed)
			local key = tostring(p.yaw or 0) .. ":" .. tostring(p.pitch or 0)
			if key ~= baseKey then
				base = PC.ViewCam(v, SW, SH, D, D, p.yaw, p.pitch, pose) or base
				baseKey = key
			end
			cam.CFrame = base * CFrame.Angles(0, 0, math.rad(p.r)) -- camera roll = the picture turns clockwise by r
		else
			holder.Rotation = p.r
			-- v5.13: a card that leans (REPOSITION) is drawn as a perspective picture; a straight card stays the cheap baked / drawn card
			local ty, tp = p.yaw or 0, p.pitch or 0
			if math.abs(ty) > 0.05 or math.abs(tp) > 0.05 then
				if tilt == nil then tilt = PC.TiltCard(holder, id, cw) or false end
			end
			local leaning = tilt and (math.abs(ty) > 0.05 or math.abs(tp) > 0.05)
			if tilt then
				tilt.holder.Visible = leaning and true or false
				if leaning then tilt.set(ty, tp) end
			end
			if flatCard then flatCard.Visible = not leaning end
		end
	end
	it.apply(place or PC.DefaultPlace(1))
	return it
end

-- ================= the whole card =================
local function chipLbl(parent, x, y, text, bg, fg)
	local w = #text * 8 + 22
	local c = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 22), BackgroundColor3 = bg, BorderSizePixel = 0 }, parent)
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = text, TextSize = 12, FontFace = F.MB, TextColor3 = fg }, c)
	return c, w
end

-- data = { userId, name, username, level, leader, ready (string/true), card = { bg, show, pos }, empty, animate }
-- returns holder, card, items ({ [slot] = item from PC.BuildItem })
function PC.Render(parent, data, width)
	local W, H = PC.W, PC.H
	local holder = new("Frame", { Name = "PlayerCard", Size = UDim2.fromOffset(width or W, (width or W) * H / W), BackgroundTransparency = 1 }, parent)
	local card = new("Frame", { Name = "Card", Size = UDim2.fromOffset(W, H), BackgroundColor3 = K.panel, BorderSizePixel = 0, ClipsDescendants = true }, holder)
	new("UIScale", { Scale = (width or W) / W }, card)
	local items = {}
	if data.empty then
		card.BackgroundTransparency = 0.45
		new("UIStroke", { Color = K.line2, Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
		for _, sz in { Vector2.new(30, 3), Vector2.new(3, 30) } do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, H / 2 - 20), Size = UDim2.fromOffset(sz.X, sz.Y), BackgroundColor3 = K.dim, BorderSizePixel = 0 }, card)
		end
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, H / 2 + 6), Size = UDim2.fromOffset(W, 34), Text = "INVITE", TextSize = 28,
			FontFace = F.H, TextColor3 = K.dim }, card)
		return holder, card, items
	end
	local cd = data.card or { bg = PC.Default, show = { "", "", "" } }
	PC.DrawBanner(card, cd.bg, data.animate ~= false).ZIndex = 1
	-- a soft shade in the top right corner, BEHIND the items, so the name reads on bright backgrounds
	local shade = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(W, 0), Size = UDim2.fromOffset(W * 0.62, H * 0.6),
		BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 2 }, card)
	new("UIGradient", { Rotation = 200, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 1) }) }, shade)
	new("UIStroke", { Color = data.leader and K.red or K.line2, Thickness = data.leader and 2 or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)

	-- the 3 showcase items: free on the card, UNDER the info (slot 3 on top of slot 2 on top of slot 1)
	for i = 1, 3 do
		local v = cd.show and cd.show[i] or ""
		if PC.Parse(v) then
			local place = (cd.pos and cd.pos[i]) or PC.DefaultPlace(i)
			local ok, it = pcall(PC.BuildItem, card, v, place, 2 + i, cd.poses and cd.poses[i] or nil) -- v5.16: + the pose of a costume
			if ok and it then items[i] = it elseif not ok then warn("[PlayerCards] item", v, it) end
		end
	end

	-- INFO (always on top of the items): small avatar top right, NAME + LV left of it, @username under the name
	local AV = 85
	local avX = W - 20 - AV
	local av = new("ImageLabel", { Position = UDim2.fromOffset(avX, 20), Size = UDim2.fromOffset(AV, AV), BackgroundColor3 = K.panel3, BorderSizePixel = 0, ZIndex = 10,
		Image = data.userId and ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(data.userId) or "" }, card)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.55 }, av)
	local right = avX - 14
	-- v5.16 TITLE above the name (data.title = the Titles id the player wears; shown when the card's showTitle switch is on)
	local Tm = RS:FindFirstChild("Titles") and require(RS.Titles) or nil
	local tdef = Tm and data.title and Tm.ById[data.title] or nil
	local showT = tdef ~= nil and cd.showTitle ~= false
	local TY = showT and 16 or 0
	if showT then
		local tl = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(right, 12), Size = UDim2.fromOffset(460, 20),
			Text = tdef.text, TextSize = 17, FontFace = F.H, TextColor3 = tdef.color, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 11 }, card)
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.2, Transparency = 0.35 }, tl)
	end
	local row = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(right, 20 + TY), Size = UDim2.fromOffset(460, 46), BackgroundTransparency = 1, ZIndex = 10 }, card)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, row)
	local nm = new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 46), Text = string.upper(data.name or ""),
		TextSize = 38, FontFace = F.H, TextColor3 = K.text, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 11, LayoutOrder = 1 }, row)
	new("UISizeConstraint", { MaxSize = Vector2.new(360, 46) }, nm)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.35 }, nm)
	-- v5.13: LV + the level number a bit bigger (LV 14 -> 17 px, number 20 -> 25 px)
	local lvT = new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36), RichText = true,
		Text = ('<font color="#9499A4" size="17">LV</font> %s'):format(data.level and tostring(data.level) or "-"),
		TextSize = 25, FontFace = F.H, TextColor3 = K.text, ZIndex = 11, LayoutOrder = 2 }, row)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.2, Transparency = 0.4 }, lvT)
	if data.username then
		local un = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(right, 66 + TY), Size = UDim2.fromOffset(460, 20),
			Text = "@" .. data.username, TextSize = 15, FontFace = F.MB, TextColor3 = K.dim, TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 11 }, card)
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.45 }, un)
	end
	-- tags: PARTY LEADER / READY (top left)
	local tx = 20
	if data.leader then
		local c, w = chipLbl(card, tx, 20, "PARTY LEADER", K.red, K.text)
		c.ZIndex = 12
		for _, ch in c:GetChildren() do ch.ZIndex = 13 end
		tx += w + 8
	end
	if data.ready then
		local c = chipLbl(card, tx, 20, "READY", rgb(24, 90, 52), K.green)
		c.ZIndex = 12
		for _, ch in c:GetChildren() do ch.ZIndex = 13 end
	end
	return holder, card, items
end

return PC
