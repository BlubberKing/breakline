-- PlayerCards v1 (ModuleScript in ReplicatedStorage, named "PlayerCards") - LOBBY place only. NEW in v5.11.
-- The PLAYER CARD every player shows in the lobby play screen (yours on top, your party under it):
--   left  = a background picture (a BANNER), your avatar picture, name, level, PARTY LEADER / READY tags
--   right = 3 SHOWCASE slots, each holds a tiny version of something you own (a player skin, a gun skin or a power-up card) to flex.
-- Everything is drawn from GUI frames in code (no image uploads). Some banners move a little (tweens that loop, no per-frame code).
-- Saved in the profile as PlayerCard = { bg = <banner id>, show = { "skin:OPERATOR_NIGHTFALL", "gun:VX9_GILT", "card:SUN_EATER" } }, mirrored to the
-- Player attribute PlayerCardJson (everybody's client reads it). Bought banners: profile BannersOwned (attribute BannersOwnedJson).
--   PC.Banners / PC.ById[id] / PC.Order          banner list: { id, name, price = nil | { souls = n } | { essence = n }, anim }
--   PC.IsFree(id)                                 free banners belong to everybody
--   PC.Read(player) -> { bg, show = {3} }         the card a player shows (defaults filled in)
--   PC.Parse(value) -> kind, id                   "skin:ID" -> "skin", "ID"  (kinds: skin / gun / card)
--   PC.DrawBanner(parent, id, animate)            fills `parent` (any size) with the banner
--   PC.Render(parent, data, width)                a whole card. data = { userId, name, username, level, leader, ready, card = {bg, show}, empty }
--                                                 returns the card holder (its native size is 840 x 236, scaled to `width`)
--   PC.ShowcaseItem(slot, value, w, h)            draws one showcase item into a frame (w / h = the slot size in its own, unscaled pixels)
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
function PC.Read(player)
	local out = { bg = PC.Default, show = { "", "", "" } }
	local raw = player and player:GetAttribute("PlayerCardJson")
	if type(raw) == "string" and raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" then
			if PC.Is(t.bg) then out.bg = t.bg end
			if type(t.show) == "table" then
				for i = 1, 3 do if PC.Parse(t.show[i]) then out.show[i] = t.show[i] end end
			end
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

function PC.ShowcaseItem(slot, v, sw, sh)
	mods()
	local kind, id = PC.Parse(v)
	if not kind then return nil end
	if kind == "card" then
		if not CardArt then return nil end
		local w = sw or slot.AbsoluteSize.X
		local hgt = sh or slot.AbsoluteSize.Y
		-- the card is 250 x 350: fit it inside the slot with a small margin
		local cw = math.floor(math.min(w * 0.82, hgt * 0.86 * 250 / 350))
		local ok, holder = pcall(CardArt.Build, slot, id, { width = math.max(40, cw), anim = false })
		if ok and holder then
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position = UDim2.fromScale(0.5, 0.5)
		end
		return holder
	end
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 160), LightColor = rgb(255, 250, 244),
		LightDirection = Vector3.new(-0.5, -0.9, -0.4) }, slot)
	local cam = new("Camera", { FieldOfView = 20 }, vp)
	local model = new("Model", {}, vp)
	if kind == "skin" and Skins.Is(id) then
		local ok, fig = pcall(Skins.NewFigure, model, id, { static = true })
		if ok and fig then pcall(fig.Update, fig, 0, 0) end
		UI.FitViewport(vp, cam, model, Vector3.new(0.28, 0.1, 1), { pad = 0.06, fov = 22 })
	elseif kind == "gun" and GunSkins.ById[id] then
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
		-- a gun is long and the slot is tall: look at it from the side, turned 60 degrees so it fills the slot
		UI.FitViewport(vp, cam, model, Vector3.new(1, 0.25, 0.55), { pad = 0.08, fov = 18 })
	end
	return vp
end

-- ================= the whole card =================
local function chipLbl(parent, x, y, text, bg, fg)
	local w = #text * 8 + 22
	local c = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 22), BackgroundColor3 = bg, BorderSizePixel = 0 }, parent)
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = text, TextSize = 12, FontFace = F.MB, TextColor3 = fg }, c)
	return c, w
end

-- data = { userId, name, username, level, leader, ready (string/true), card = { bg, show }, empty, animate }
function PC.Render(parent, data, width)
	local W, H = PC.W, PC.H
	local holder = new("Frame", { Name = "PlayerCard", Size = UDim2.fromOffset(width or W, (width or W) * H / W), BackgroundTransparency = 1 }, parent)
	local card = new("Frame", { Name = "Card", Size = UDim2.fromOffset(W, H), BackgroundColor3 = K.panel, BorderSizePixel = 0, ClipsDescendants = true }, holder)
	new("UIScale", { Scale = (width or W) / W }, card)
	if data.empty then
		card.BackgroundTransparency = 0.45
		new("UIStroke", { Color = K.line2, Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
		for _, sz in { Vector2.new(30, 3), Vector2.new(3, 30) } do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, H / 2 - 20), Size = UDim2.fromOffset(sz.X, sz.Y), BackgroundColor3 = K.dim, BorderSizePixel = 0 }, card)
		end
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, H / 2 + 6), Size = UDim2.fromOffset(W, 34), Text = "INVITE", TextSize = 28,
			FontFace = F.H, TextColor3 = K.dim }, card)
		return holder, card
	end
	local cd = data.card or { bg = PC.Default, show = { "", "", "" } }
	PC.DrawBanner(card, cd.bg, data.animate ~= false)
	-- readability shade behind the text on the left
	local shade = new("Frame", { Size = UDim2.fromOffset(W * 0.62, H), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 2 }, card)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.75, 0.6), NumberSequenceKeypoint.new(1, 1) }) }, shade)
	new("UIStroke", { Color = data.leader and K.red or K.line2, Thickness = data.leader and 2 or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	-- avatar
	local av = new("ImageLabel", { Position = UDim2.fromOffset(22, 33), Size = UDim2.fromOffset(170, 170), BackgroundColor3 = K.panel3, BorderSizePixel = 0, ZIndex = 3,
		Image = data.userId and ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(data.userId) or "" }, card)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.6 }, av)
	-- name + username + level
	local nm = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(212, 58), Size = UDim2.fromOffset(250, 52), Text = string.upper(data.name or ""),
		TextSize = 44, FontFace = F.H, TextColor3 = K.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3 }, card)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.5 }, nm)
	if data.username then
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(214, 108), Size = UDim2.fromOffset(250, 18), Text = "@" .. data.username, TextSize = 13,
			FontFace = F.M, TextColor3 = K.dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3 }, card)
	end
	local lv = new("Frame", { Position = UDim2.fromOffset(214, 146), Size = UDim2.fromOffset(86, 40), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3 }, card)
	new("UIStroke", { Color = K.line2, Thickness = 1 }, lv)
	new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(26, 40), Text = "LV", TextSize = 13, FontFace = F.MB, TextColor3 = K.dim,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, lv)
	new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.fromOffset(50, 40), Text = data.level and tostring(data.level) or "-", TextSize = 26,
		FontFace = F.H, TextColor3 = K.text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, lv)
	-- tags: PARTY LEADER / READY
	local tx = 214
	if data.leader then
		local c, w = chipLbl(card, tx, 22, "PARTY LEADER", K.red, K.text)
		c.ZIndex = 4
		for _, ch in c:GetChildren() do ch.ZIndex = 5 end
		tx += w + 8
	end
	if data.ready then
		local c = chipLbl(card, tx, 22, "READY", rgb(24, 90, 52), K.green)
		c.ZIndex = 4
		for _, ch in c:GetChildren() do ch.ZIndex = 5 end
	end
	-- showcase slots on the right
	local SW, SH, SG = 112, 196, 10
	local x0 = W - 20 - 3 * SW - 2 * SG
	for i = 1, 3 do
		local v = cd.show and cd.show[i] or ""
		local slot = new("Frame", { Name = "Show" .. i, Position = UDim2.fromOffset(x0 + (i - 1) * (SW + SG), (H - SH) / 2), Size = UDim2.fromOffset(SW, SH),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = PC.Parse(v) and 0.45 or 0.75, BorderSizePixel = 0, ZIndex = 3 }, card)
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = PC.Parse(v) and 0.7 or 0.88 }, slot)
		if PC.Parse(v) then
			local inner = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, slot)
			task.defer(function() if inner.Parent then pcall(PC.ShowcaseItem, inner, v, SW, SH) end end)
		end
	end
	return holder, card
end

return PC
