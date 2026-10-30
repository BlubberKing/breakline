-- LobbyClient v5 "CLEAN" (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only.
-- v5 look: the POP style is gone. Flat, sharp, dark, on-brand (black / white / Breakline red), built like a big-shooter front end.
-- No drifting shapes, no bouncing, no springy hovers, no rounded pills. Hovers are quick color shifts only.
-- Layout (1920x1080 canvas, scaled to the screen, 56 px outer margin):
--   * home HUD (walking around the lobby): static BREAKLINE logo top left, souls top right, PLAY block + square "+" (invite) bottom right
--   * PLAY screen: black starry space, your squad on three stone pillars (you on the middle one, red edge light), names = plain text
--       top bar   : logo | souls, TAB SKINS, ESC BACK | thin rule
--       right     : LOADOUT column (primary, movement, gadgets 2-4, reserve, outfit/skin). Click a slot = picker over the stage.
--       bottom    : GAME MODE card | 3 party slots (leader always leftmost) | START block
--   * Skins are picked from the OUTFIT slot (or TAB). The separate slide-in panel and the top nav tabs are removed.
-- Same game logic / remotes as v3 / v4. Needs in ReplicatedStorage: LobbyCatalog, Skins, GunModels (copy of Breakline's), LobbyRemotes.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = RS:WaitForChild("LobbyRemotes")
local QueueR, InviteR, RespondR, LeaveR, KickR, NoticeR =
	remotes:WaitForChild("Queue"), remotes:WaitForChild("Invite"), remotes:WaitForChild("Respond"),
	remotes:WaitForChild("Leave"), remotes:WaitForChild("Kick"), remotes:WaitForChild("Notice")
local PromoteR, SetLoadoutR, SetSkinR = remotes:WaitForChild("Promote"), remotes:WaitForChild("SetLoadout"), remotes:WaitForChild("SetSkin")
local Catalog = require(RS:WaitForChild("LobbyCatalog"))
local Skins = require(RS:WaitForChild("Skins"))
local GunModels = RS:FindFirstChild("GunModels") and require(RS.GunModels) or nil

-- ================= theme =================
local rgb = Color3.fromRGB
local C = {
	void = rgb(4, 5, 7),          -- space / deepest black
	bg = rgb(9, 10, 13),          -- overlays
	panel = rgb(14, 15, 19),      -- slots, cards
	panel2 = rgb(22, 24, 29),     -- hover
	panel3 = rgb(31, 34, 41),     -- pressed / icon wells
	line = rgb(40, 43, 51),       -- 1 px borders
	line2 = rgb(78, 82, 94),      -- hover borders
	text = rgb(238, 239, 242),
	dim = rgb(148, 153, 164),
	mute = rgb(90, 95, 106),
	red = rgb(226, 38, 48),       -- Breakline red (the only loud color)
	redHi = rgb(255, 64, 74),
	redDeep = rgb(116, 20, 28),
	soul = rgb(112, 208, 255),
	soulPale = rgb(220, 246, 255),
	blue = rgb(48, 116, 226),
}
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local function fam(name, weight) return Font.new("rbxasset://fonts/families/" .. name .. ".json", weight or Enum.FontWeight.Regular) end
local FONTS = {
	H = fam("Oswald", Enum.FontWeight.Bold),          -- headings, names, numbers
	HM = fam("Oswald", Enum.FontWeight.Medium),       -- secondary headings
	B = fam("GothamSSm", Enum.FontWeight.Medium),     -- body copy
	BB = fam("GothamSSm", Enum.FontWeight.Bold),
	M = fam("RobotoMono", Enum.FontWeight.Medium),    -- small tactical labels
	MB = fam("RobotoMono", Enum.FontWeight.Bold),
}

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function border(o, color, thick, transp)
	return new("UIStroke", { Color = color or C.line, Thickness = thick or 1, Transparency = transp or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter }, o)
end
local function grad(o, c0, c1, rot)
	return new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 90 }, o)
end
-- transparency ramp on a solid frame (rot 90 = top -> bottom)
local function fade(o, rot, t0, t1)
	return new("UIGradient", { Rotation = rot or 90, Transparency = NumberSequence.new(t0, t1) }, o)
end
local function frame(parent, x, y, w, h, color, transp)
	return new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.panel, BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
end
local function lbl(parent, text, size, x, y, w, h, color, font, align)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = FONTS[font or "B"],
		TextColor3 = color or C.text, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		TextXAlignment = align or Enum.TextXAlignment.Left, TextWrapped = false }, parent)
end
local function tween(o, info, goal) TweenService:Create(o, info, goal):Play() end

-- hover = color shift only (no scaling, no tilting). st = optional UIStroke to light up.
local function hoverable(b, bg, bgHot, st, stCol, stHot)
	b.MouseEnter:Connect(function()
		tween(b, FAST, { BackgroundColor3 = bgHot })
		if st then tween(st, FAST, { Color = stHot }) end
	end)
	b.MouseLeave:Connect(function()
		tween(b, FAST, { BackgroundColor3 = bg })
		if st then tween(st, FAST, { Color = stCol }) end
	end)
end

-- flat button. kind: "primary" (red), "ghost" (dark + 1 px line), "danger" (ghost with red text)
local function button(parent, text, x, y, w, h, kind, size)
	kind = kind or "ghost"
	local primary = kind == "primary"
	local bg, bgHot = primary and C.red or C.panel2, primary and C.redHi or C.panel3
	local b = new("TextButton", { Text = text, TextSize = size or 16, FontFace = FONTS.H, TextColor3 = (kind == "danger") and C.redHi or C.text,
		BackgroundColor3 = bg, AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	local st
	if not primary then st = border(b, kind == "danger" and C.redDeep or C.line, 1) end
	hoverable(b, bg, bgHot, st, kind == "danger" and C.redDeep or C.line, kind == "danger" and C.red or C.line2)
	return b
end

-- keyboard cap + label ("ESC  BACK"). Returns the label.
local function keyHint(parent, key, text, x, y)
	local kw = math.max(30, #key * 8 + 16)
	local k = frame(parent, x, y, kw, 24, C.panel2, 0)
	border(k, C.line2, 1)
	lbl(k, key, 12, 0, 0, kw, 24, C.text, "MB", Enum.TextXAlignment.Center)
	return lbl(parent, text, 16, x + kw + 8, y, 160, 24, C.dim, "HM")
end

-- small mono label with a hairline running to the right ("PRIMARY ———————")
local function sectionLabel(parent, text, x, y, w)
	lbl(parent, text, 12, x, y, w, 16, C.dim, "M")
	local tw = math.floor(#text * 7.2) + 10
	frame(parent, x + tw, y + 8, math.max(0, w - tw), 1, C.line, 0)
end

local function thumb(id) return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(id) end
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return out
end

-- chevron ">" from two thin bars
local function chevron(parent, x, y, size, color, thick)
	local h = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size * 2) }, parent)
	local len = size * 1.42
	for i, rot in { -45, 45 } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(size / 2, (i == 1) and size * 0.5 or size * 1.5),
			Size = UDim2.fromOffset(thick or 2, len), Rotation = rot, BackgroundColor3 = color, BorderSizePixel = 0 }, h)
	end
	return h
end

-- ================= logo: BREAK / LINE, static =================
-- Hard condensed type, a slim red slash between the words. Nothing moves.
local function makeLogo(parent, x, y, size)
	local h = math.floor(size * 1.15)
	local holder = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1 }, parent)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, math.floor(size * 0.05)) }, holder)
	local function word(text, order)
		return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = FONTS.H, TextColor3 = C.text,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), LayoutOrder = order }, holder)
	end
	word("BREAK", 1)
	local gap = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(math.floor(size * 0.34), h), LayoutOrder = 2 }, holder)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(math.max(3, math.floor(size * 0.1)), math.floor(size * 0.98)),
		Rotation = 20, BackgroundColor3 = C.red, BorderSizePixel = 0 }, gap)
	word("LINE", 3)
	return holder
end

-- ================= soul icon: faceted crystal (outlined diamond + bright core) =================
local function soulIcon(parent, size)
	local h = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	local d = math.floor(size * 0.68)
	local outer = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(d, d),
		Rotation = 45, BackgroundColor3 = C.soul, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, h)
	border(outer, C.soul, math.max(1.5, size * 0.07))
	local inner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.floor(d * 0.46), math.floor(d * 0.46)),
		Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0 }, h)
	grad(inner, C.soulPale, C.soul, 90)
	return h
end

-- souls counter, right-aligned at (right, y): [crystal] 12,400
local function soulsWidget(parent, right, y)
	local w = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(right, y), Size = UDim2.fromOffset(300, 40),
		BackgroundTransparency = 1 }, parent)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, w)
	soulIcon(w, 28).LayoutOrder = 1
	local n = new("TextLabel", { BackgroundTransparency = 1, Text = "0", TextSize = 30, FontFace = FONTS.H, TextColor3 = C.text,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), LayoutOrder = 2 }, w)
	local function upd() n.Text = commas(player:GetAttribute("Souls") or 0) end
	player:GetAttributeChangedSignal("Souls"):Connect(upd)
	upd()
	return w
end

-- ================= gun pictures (real GunModels in a ViewportFrame, side view) =================
local function gunPicture(parent, weaponId)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 158),
		LightColor = rgb(255, 252, 246), LightDirection = Vector3.new(-0.5, -1, -0.3) }, parent)
	if not GunModels then return vp end
	local ok, desc = pcall(GunModels.Describe, weaponId, "Iron")
	if not ok or not desc then return vp end
	local model = new("Model", {}, vp)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in desc.Parts do
		if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
			local p = new("Part", { Anchored = true, Size = d.Size, CFrame = d.CF, Color = (d.Glow and C.red) or d.Color,
				Material = d.Material or Enum.Material.SmoothPlastic, Transparency = d.Transparency or 0 }, model)
			if d.Shape then p.Shape = d.Shape end
			local half = d.Size / 2
			minV, maxV = minV:Min(d.CF.Position - half), maxV:Max(d.CF.Position + half)
		end
	end
	local center = (minV + maxV) / 2
	local len = math.max(maxV.Z - minV.Z, (maxV.Y - minV.Y) * 2.2)
	local cam = new("Camera", { FieldOfView = 16 }, vp)
	local dist = (len / 2) / math.tan(math.rad(8)) / 2.2 + 1
	cam.CFrame = CFrame.lookAt(center + Vector3.new(dist, dist * 0.08, 0), center)
	vp.CurrentCamera = cam
	return vp
end

-- placeholder icon for gadgets / movement: dark well, thin tinted edge, glyph
local function itemPicture(parent, item, glyphSize)
	if item.kind == "weapon" and GunModels then
		gunPicture(parent, item.id)
		return
	end
	local tone = item.color:Lerp(rgb(150, 150, 150), 0.4)
	local t = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(glyphSize * 2.4, glyphSize * 2.4),
		BackgroundColor3 = C.panel3, BorderSizePixel = 0 }, parent)
	border(t, tone, 1, 0.35)
	frame(t, 0, glyphSize * 2.4 - 2, glyphSize * 2.4, 2, tone, 0)
	new("TextLabel", { BackgroundTransparency = 1, Text = item.glyph, TextSize = glyphSize, FontFace = FONTS.H,
		TextColor3 = C.text, Size = UDim2.fromScale(1, 1) }, t)
end

-- ================= data =================
local MODES = {
	{
		id = "breakline", name = "BREAKLINE", tag = "3V3  //  WALL PUSH",
		desc = "Two teams, one moving wall. Carry boxes to your side's holes and plug them in: the team with more plugged boxes pushes the wall toward the enemy. Shoot enemy boxes to break them. Push the wall onto their finish line to win.",
		facts = { "Red vs Blue, 3 players per team", "Carry boxes: hold E, plug them into your holes", "Break the other team's boxes with your gun", "Wall reaches a finish line = round over", "Win +100 souls, loss +40 souls" },
	},
}
local selectedMode = "breakline"

local loadout = { Weapon = Catalog.DefaultWeapon, Move = "", Gadgets = { "", "", "" }, Reserve = { "", "", "" } }
local localEdited = false
local function readLoadout()
	local raw = player:GetAttribute("LoadoutJson")
	if type(raw) ~= "string" or localEdited then return false end
	local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok or type(t) ~= "table" then return false end
	loadout.Weapon = Catalog.Is(t.Weapon, "weapon") and t.Weapon or Catalog.DefaultWeapon
	loadout.Move = type(t.Move) == "string" and t.Move or ""
	for i = 1, 3 do
		loadout.Gadgets[i] = type(t.Gadgets) == "table" and type(t.Gadgets[i]) == "string" and t.Gadgets[i] or ""
		loadout.Reserve[i] = type(t.Reserve) == "table" and type(t.Reserve[i]) == "string" and t.Reserve[i] or ""
	end
	return true
end
readLoadout()

local mySkin = Skins.Is(player:GetAttribute("Skin")) and player:GetAttribute("Skin") or Skins.Default

local function partyInfo()
	local raw = player:GetAttribute("PartyMembers")
	local list = {}
	if type(raw) == "string" then
		local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and type(t) == "table" then list = t end
	end
	local leader = player:GetAttribute("PartyLeader")
	if #list == 0 then
		list = { { id = player.UserId, name = player.Name } }
		leader = player.UserId
	end
	return list, leader
end

local function memberLook(m)
	local p = Players:GetPlayerByUserId(m.id)
	local skin = (p and p:GetAttribute("Skin")) or m.skin
	local weapon = Catalog.DefaultWeapon
	if p and type(p:GetAttribute("LoadoutJson")) == "string" then
		local ok, t = pcall(function() return HttpService:JSONDecode(p:GetAttribute("LoadoutJson")) end)
		if ok and type(t) == "table" and Catalog.Is(t.Weapon, "weapon") then weapon = t.Weapon end
	end
	return Skins.Is(skin) and skin or Skins.Default, weapon, p and p.DisplayName or m.name
end

-- ================= root gui =================
local gui = new("ScreenGui", { Name = "LobbyUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

local scalers = {}
local function canvas(parent, z)
	local c = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1, ZIndex = z or 1 }, parent)
	table.insert(scalers, new("UIScale", {}, c))
	return c
end
local function rescale()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local s = math.max(0.3, math.min(vs.X / 1920, vs.Y / 1080))
	for _, sc in scalers do sc.Scale = s end
end

local openScreen
local RIGHT = 1864 -- right margin line (1920 - 56)

-- ---------- big action block (home PLAY + START) ----------
-- returns button, main label, sub label, paint(state)
local BLOCK = {
	go = { bg = C.red, hot = C.redHi, text = C.text, chev = C.text },
	cancel = { bg = C.text, hot = WHITE, text = C.void, chev = C.red },
	wait = { bg = C.panel2, hot = C.panel2, text = C.dim, chev = C.mute },
}
local function actionBlock(parent, x, y, w, h, mainText, subText)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.red, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	local top = frame(b, 0, 0, w, 2, WHITE, 0.75)
	local main = lbl(b, mainText, math.floor(h * 0.44), 28, math.floor(h * 0.1), w - 110, math.floor(h * 0.54), C.text, "H")
	local sub = lbl(b, subText, 13, 30, math.floor(h * 0.66), w - 110, 18, C.text, "M")
	sub.TextTransparency = 0.15
	local chev = chevron(b, w - 56, h / 2 - 14, 14, C.text, 3)
	local cur = BLOCK.go
	local hot = false
	local function apply()
		b.BackgroundColor3 = hot and cur.hot or cur.bg
		main.TextColor3, sub.TextColor3 = cur.text, cur.text
		top.BackgroundTransparency = (cur == BLOCK.go) and 0.75 or 1
		for _, bar in chev:GetChildren() do bar.BackgroundColor3 = cur.chev end
	end
	b.MouseEnter:Connect(function()
		hot = true
		tween(b, FAST, { BackgroundColor3 = cur.hot })
		tween(chev, FAST, { Position = UDim2.fromOffset(w - 50, h / 2 - 14) })
	end)
	b.MouseLeave:Connect(function()
		hot = false
		tween(b, FAST, { BackgroundColor3 = cur.bg })
		tween(chev, FAST, { Position = UDim2.fromOffset(w - 56, h / 2 - 14) })
	end)
	local function paint(state)
		cur = BLOCK[state] or BLOCK.go
		apply()
	end
	apply()
	return b, main, sub, paint
end

-- square "+" button (invite)
local function plusButton(parent, x, y, w, h)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BackgroundTransparency = 0.1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	local st = border(b, C.line2, 1)
	frame(b, (w - 22) / 2, (h - 2) / 2, 22, 2, C.text, 0)
	frame(b, (w - 2) / 2, (h - 22) / 2, 2, 22, C.text, 0)
	hoverable(b, C.panel, C.panel3, st, C.line2, C.red)
	return b
end

-- ================= home HUD =================
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, gui)
do
	local topShade = new("Frame", { Size = UDim2.new(1, 0, 0, 170), BackgroundColor3 = C.void, BorderSizePixel = 0 }, hud)
	fade(topShade, 90, 0.35, 1)
	local botShade = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 300),
		BackgroundColor3 = C.void, BorderSizePixel = 0 }, hud)
	fade(botShade, 90, 1, 0.2)
end
local hudC = canvas(hud, 2)
makeLogo(hudC, 56, 36, 56)
soulsWidget(hudC, RIGHT, 46)
keyHint(hudC, "TAB", "SKINS", 56, 1004)
local homePlay, _, _, homePaint = actionBlock(hudC, 1444, 912, 340, 112, "PLAY", "BREAKLINE  //  3V3")
homePaint("go")
local homePlus = plusButton(hudC, 1796, 912, 68, 112)
local hudStatus = lbl(hudC, "", 16, 1064, 872, 800, 24, C.text, "HM", Enum.TextXAlignment.Right)

-- ================= play screen =================
local screen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.void, BorderSizePixel = 0, Visible = false,
	ClipsDescendants = true, ZIndex = 10, Active = true }, gui)

-- static starfield (scale positions so it fills any screen); a few of the brightest stars breathe very slowly
local space = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, screen)
local twinkles = {}
do
	local rng = Random.new(7)
	local tints = { WHITE, WHITE, WHITE, rgb(206, 222, 255), rgb(255, 236, 222) }
	for _ = 1, 280 do
		local r = rng:NextNumber()
		local s = (r < 0.06) and 3 or ((r < 0.32) and 2 or 1)
		local f = new("Frame", { Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber() * 0.9), Size = UDim2.fromOffset(s, s),
			BackgroundColor3 = tints[rng:NextInteger(1, #tints)], BackgroundTransparency = (s == 3) and 0.1 or rng:NextNumber(0.25, 0.8),
			BorderSizePixel = 0 }, space)
		if s == 3 or rng:NextNumber() < 0.05 then
			table.insert(twinkles, { f = f, base = f.BackgroundTransparency, ph = rng:NextNumber(0, 6.28), spd = rng:NextNumber(0.35, 0.8) })
		end
	end
	-- faint cold haze low on the horizon, gives the void some depth behind the pillars
	local haze = new("Frame", { Position = UDim2.fromScale(0, 0.42), Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = rgb(26, 30, 40), BorderSizePixel = 0 }, space)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.72), NumberSequenceKeypoint.new(1, 1) }) }, haze)
end

local stage = canvas(screen, 2)

-- ----- the stage: three pillars in space -----
local VPW, VPH = 1860, 1080 -- viewport is shifted so the squad is centred between the left edge and the loadout column
local CAM_POS, CAM_LOOK, CAM_FOV = Vector3.new(0, 4.4, 28), Vector3.new(0, 3.5, 0), 34
local PILLARS = {
	{ x = 0, z = 1.0, top = 0, edge = C.red },                       -- you
	{ x = -5.6, z = -0.8, top = -0.4, edge = rgb(150, 155, 166) },    -- teammate (left)
	{ x = 5.6, z = -0.8, top = -0.4, edge = rgb(150, 155, 166) },     -- teammate (right)
}
local SLOTS = {
	{ pos = Vector3.new(PILLARS[1].x, PILLARS[1].top, PILLARS[1].z), yaw = 30 },
	{ pos = Vector3.new(PILLARS[2].x, PILLARS[2].top, PILLARS[2].z), yaw = 20 },
	{ pos = Vector3.new(PILLARS[3].x, PILLARS[3].top, PILLARS[3].z), yaw = 42 },
}
local stageCam = new("Camera", { FieldOfView = CAM_FOV, CFrame = CFrame.lookAt(CAM_POS, CAM_LOOK) })
local function project(world)
	local p = stageCam.CFrame:PointToObjectSpace(world)
	if p.Z >= 0 then return nil end
	local t = math.tan(math.rad(CAM_FOV / 2))
	local x = p.X / (-p.Z * t * (VPW / VPH))
	local y = p.Y / (-p.Z * t)
	return Vector2.new((x + 1) / 2 * VPW, (1 - y) / 2 * VPH)
end

-- soft light shafts from above, one per pillar (2D, behind the 3D view)
local shaftLayer = new("Frame", { Size = UDim2.fromOffset(VPW, VPH), BackgroundTransparency = 1, ZIndex = 1 }, stage)
for i, pl in PILLARS do
	local top = project(Vector3.new(pl.x, pl.top, pl.z))
	local l = project(Vector3.new(pl.x - 3.2, pl.top, pl.z))
	local r = project(Vector3.new(pl.x + 3.2, pl.top, pl.z))
	if top and l and r then
		local w = r.X - l.X
		local cg = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(top.X, 0), Size = UDim2.fromOffset(w, top.Y + 30),
			BackgroundTransparency = 1, GroupTransparency = (i == 1) and 0.84 or 0.9 }, shaftLayer)
		fade(cg, 90, 1, 0)
		local beam = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = (i == 1) and rgb(255, 238, 236) or rgb(220, 228, 245), BorderSizePixel = 0 }, cg)
		new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, beam)
	end
end

local vp = new("ViewportFrame", { Size = UDim2.fromOffset(VPW, VPH), BackgroundTransparency = 1, ZIndex = 2,
	Ambient = rgb(118, 120, 128), LightColor = rgb(255, 250, 244), LightDirection = Vector3.new(-0.4, -0.85, -0.6) }, stage)
stageCam.Parent = vp
vp.CurrentCamera = stageCam

do -- pillars: dark stone columns that fall away into the void, a lighter cap, one thin edge light on the front
	local env = new("Model", { Name = "Pillars" }, vp)
	local function P(size, cf, color, neon)
		return new("Part", { Anchored = true, Size = size, CFrame = cf, Color = color,
			Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth, CastShadow = false }, env)
	end
	local W, DEPTH = 3.9, 46
	for _, pl in PILLARS do
		local base = Vector3.new(pl.x, pl.top, pl.z)
		P(Vector3.new(W, DEPTH, W), CFrame.new(base + Vector3.new(0, -0.36 - DEPTH / 2, 0)), rgb(25, 27, 32))
		P(Vector3.new(W + 0.36, 0.36, W + 0.36), CFrame.new(base + Vector3.new(0, -0.18, 0)), rgb(60, 63, 72))
		P(Vector3.new(W + 0.06, 0.1, W + 0.06), CFrame.new(base + Vector3.new(0, -0.62, 0)), rgb(14, 15, 18))
		-- chamfered vertical edges catch a sliver of light
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			P(Vector3.new(0.3, DEPTH, 0.3), CFrame.new(base + Vector3.new(c[1] * W / 2, -0.36 - DEPTH / 2, c[2] * W / 2)) * CFrame.Angles(0, math.rad(45), 0), rgb(44, 47, 55))
		end
		-- seams every few studs
		for k = 1, 6 do
			P(Vector3.new(W + 0.04, 0.06, W + 0.04), CFrame.new(base + Vector3.new(0, -0.36 - k * 4.2, 0)), rgb(15, 16, 19))
		end
		-- edge light along the front of the cap
		P(Vector3.new(W + 0.38, 0.07, 0.07), CFrame.new(base + Vector3.new(0, -0.05, (W + 0.36) / 2 + 0.01)), pl.edge, true)
	end
end

-- pillars dissolve into black toward the bottom of the screen
do
	local f = frame(stage, -1600, 690, 5120, 400, C.void, 0)
	f.ZIndex = 3
	fade(f, 90, 1, 0)
end

local squad = {} -- { fig, root, tag, top }
local squadKey = ""
local nameLayer = new("Frame", { Size = UDim2.fromOffset(VPW, VPH), BackgroundTransparency = 1, ZIndex = 4 }, stage)

-- names above heads: just text
local function nameTag(text, isLeader)
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(320, 54), BackgroundTransparency = 1 }, nameLayer)
	local n = lbl(holder, text, 26, 0, 20, 320, 34, C.text, "HM", Enum.TextXAlignment.Center)
	n.TextTruncate = Enum.TextTruncate.AtEnd
	new("UIStroke", { Color = BLACK, Thickness = 1.5, Transparency = 0.45 }, n)
	if isLeader then lbl(holder, "PARTY LEADER", 12, 0, 4, 320, 16, C.redHi, "MB", Enum.TextXAlignment.Center) end
	return holder
end

local function rebuildSquad()
	local list, leader = partyInfo()
	local members = { { id = player.UserId, name = player.Name, me = true } }
	for _, m in list do
		if m.id ~= player.UserId then table.insert(members, m) end
	end
	local key, looks = {}, {}
	for i = 1, math.min(3, #members) do
		local m = members[i]
		local skin, weapon, name
		if m.me then skin, weapon, name = mySkin, loadout.Weapon, player.DisplayName else skin, weapon, name = memberLook(m) end
		looks[i] = { skin = skin, weapon = weapon, name = name, leader = (m.id == leader) and #members > 1, me = m.me }
		table.insert(key, ("%d:%s:%s:%s"):format(m.id, skin, weapon, tostring(looks[i].leader)))
	end
	local k = table.concat(key, "|")
	if k == squadKey then return end
	squadKey = k
	for _, s in squad do s.fig:Destroy(); s.tag:Destroy() end
	table.clear(squad)
	for i, look in looks do
		local slot = SLOTS[i]
		local fig = Skins.NewFigure(vp, look.skin, { weapon = look.weapon, camPos = CAM_POS })
		local root = CFrame.new(slot.pos) * CFrame.Angles(0, math.rad(slot.yaw), 0)
		fig:SetRoot(root)
		local tag = nameTag(string.upper(look.name), look.leader)
		table.insert(squad, { fig = fig, root = root, tag = tag, top = fig.HeadTop })
	end
end

-- ----- top bar -----
makeLogo(stage, 56, 34, 44).ZIndex = 5
soulsWidget(stage, 1572, 38).ZIndex = 5
local skinsKey = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(1600, 40),
	Size = UDim2.fromOffset(124, 36), ZIndex = 5 }, stage)
local skinsKeyLbl = keyHint(skinsKey, "TAB", "SKINS", 0, 6)
local closeBtn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(1744, 40),
	Size = UDim2.fromOffset(120, 36), ZIndex = 5 }, stage)
local closeLbl = keyHint(closeBtn, "ESC", "BACK", 0, 6)
for b, l in { [skinsKey] = skinsKeyLbl, [closeBtn] = closeLbl } do
	b.MouseEnter:Connect(function() tween(l, FAST, { TextColor3 = C.text }) end)
	b.MouseLeave:Connect(function() tween(l, FAST, { TextColor3 = C.dim }) end)
end
do
	local rule = frame(stage, 56, 98, RIGHT - 56, 1, C.line, 0)
	rule.ZIndex = 5
end

-- toast (top centre, under the rule)
local toast = frame(stage, 680, 112, 560, 40, C.bg, 0.05)
toast.ZIndex, toast.Visible = 20, false
border(toast, C.line, 1)
frame(toast, 0, 0, 3, 40, C.red, 0)
local toastText = lbl(toast, "", 16, 18, 0, 528, 40, C.text, "HM", Enum.TextXAlignment.Center)
local toastToken = 0
local function say(text)
	toastToken += 1
	local my = toastToken
	toastText.Text = string.upper(text)
	toast.Visible = true
	task.delay(4, function() if my == toastToken then toast.Visible = false end end)
end

-- ================= loadout column (right, over the stage) =================
local LX, LW = 1444, 420
local loadCol = new("Frame", { Position = UDim2.fromOffset(LX, 112), Size = UDim2.fromOffset(LW, 760), BackgroundTransparency = 1, ZIndex = 5 }, stage)
lbl(loadCol, "LOADOUT", 28, 0, 0, 240, 40, C.text, "H")
lbl(loadCol, "SELECT A SLOT TO CHANGE", 11, LW - 220, 14, 220, 16, C.mute, "M", Enum.TextXAlignment.Right)

local slots = {}
local view = "home"
local screenOpen = false
local pickKind, pickIdx = nil, nil

local function slotItemId(kind, idx)
	if kind == "move" then return loadout.Move end
	if kind == "weapon" then return loadout.Weapon end
	if kind == "gadget" then return loadout.Gadgets[idx] end
	if kind == "skin" then return mySkin end
	return loadout.Reserve[idx]
end

local function emptyMark(parent, w, h)
	frame(parent, (w - 18) / 2, h / 2 - 1, 18, 2, C.mute, 0)
	frame(parent, (w - 2) / 2, h / 2 - 9, 2, 18, C.mute, 0)
end

-- small skin preview: head + shoulders of the real figure
local function skinPreview(parent, skinId)
	local fv = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(130, 132, 140),
		LightColor = rgb(255, 250, 244), LightDirection = Vector3.new(-0.5, -0.8, -0.6) }, parent)
	local cam = new("Camera", { FieldOfView = 30 }, fv)
	cam.CFrame = CFrame.lookAt(Vector3.new(1.4, 5.7, 7.5), Vector3.new(0, 4.9, 0))
	fv.CurrentCamera = cam
	local fig = Skins.NewFigure(fv, skinId, { camPos = cam.CFrame.Position })
	fig:SetRoot(CFrame.Angles(0, math.rad(12), 0))
	fig:Update(0, 0)
	return fv
end

local function drawSlot(s)
	local selected = (view == "pick" and pickKind == s.kind and pickIdx == s.idx)
	s.stroke.Color = selected and C.red or C.line
	s.stroke.Thickness = selected and 2 or 1
	s.mark.Visible = selected
	local id = slotItemId(s.kind, s.idx)
	if s.key == id then return end -- content unchanged: keep the built picture
	s.key = id
	local old = s.frame:FindFirstChild("Content")
	if old then old:Destroy() end
	local sw, sh = s.frame.Size.X.Offset, s.frame.Size.Y.Offset
	local box = new("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, s.frame)
	if s.num then lbl(box, s.num, 11, 8, 6, 30, 14, C.mute, "MB") end

	if s.kind == "skin" then
		local sk = Skins.Get(id)
		local well = frame(box, 8, 8, sh - 16, sh - 16, C.panel3, 0)
		grad(well, sk.card:Lerp(BLACK, 0.55), C.void, 90)
		skinPreview(well, sk.id)
		lbl(box, sk.name, 22, sh + 6, 12, sw - sh - 40, 28, C.text, "H")
		lbl(box, string.upper(sk.sub), 11, sh + 6, sh - 30, sw - sh - 40, 16, C.dim, "M")
		chevron(box, sw - 26, sh / 2 - 8, 8, C.mute, 2)
		return
	end

	local item = Catalog.ById[id]
	if s.style == "wide" then
		if item then
			local pic = new("Frame", { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 1, -64), BackgroundTransparency = 1 }, box)
			itemPicture(pic, item, 30)
			lbl(box, string.upper(item.name), 28, 16, sh - 58, sw - 32, 34, C.text, "H")
			lbl(box, string.upper(item.sub), 11, 17, sh - 24, sw - 32, 14, C.dim, "M")
		else
			emptyMark(box, sw, sh)
		end
	elseif s.style == "row" then
		if item then
			local well = frame(box, 8, 8, sh - 16, sh - 16, C.panel3, 0)
			itemPicture(well, item, 14)
			lbl(box, string.upper(item.name), 20, sh + 6, 10, sw - sh - 40, 26, C.text, "H")
			lbl(box, string.upper(item.sub), 11, sh + 6, sh - 26, sw - sh - 40, 14, C.dim, "M")
		else
			local well = frame(box, 8, 8, sh - 16, sh - 16, C.void, 0.4)
			border(well, C.line, 1)
			emptyMark(well, sh - 16, sh - 16)
			lbl(box, "NONE", 20, sh + 6, 10, 200, 26, C.mute, "H")
			lbl(box, "NO ABILITY EQUIPPED", 11, sh + 6, sh - 26, 240, 14, C.mute, "M")
		end
		chevron(box, sw - 26, sh / 2 - 8, 8, C.mute, 2)
	else -- tile
		if item then
			local pic = new("Frame", { Position = UDim2.fromOffset(6, 16), Size = UDim2.new(1, -12, 1, -44), BackgroundTransparency = 1 }, box)
			itemPicture(pic, item, 14)
			local nm = lbl(box, string.upper(item.name), 13, 6, sh - 24, sw - 12, 18, C.text, "HM", Enum.TextXAlignment.Center)
			nm.TextTruncate = Enum.TextTruncate.AtEnd
		else
			emptyMark(box, sw, sh - 14)
			lbl(box, "EMPTY", 11, 0, sh - 24, sw, 16, C.mute, "M", Enum.TextXAlignment.Center)
		end
	end
end

local function refreshLoadoutBar()
	for _, s in slots do drawSlot(s) end
end

local function makeSlot(kind, idx, x, y, w, h, style, num)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BackgroundTransparency = 0.12, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, loadCol)
	local st = border(f, C.line, 1)
	local mark = frame(f, 0, 0, 3, h, C.red, 0)
	mark.Visible = false
	f.MouseEnter:Connect(function()
		tween(f, FAST, { BackgroundColor3 = C.panel2 })
		if st.Color ~= C.red then tween(st, FAST, { Color = C.line2 }) end
	end)
	f.MouseLeave:Connect(function()
		tween(f, FAST, { BackgroundColor3 = C.panel })
		if st.Color ~= C.red then tween(st, FAST, { Color = C.line }) end
	end)
	local s = { kind = kind, idx = idx, frame = f, stroke = st, mark = mark, style = style, num = num }
	table.insert(slots, s)
	return s
end

sectionLabel(loadCol, "PRIMARY", 0, 50, LW)
makeSlot("weapon", 1, 0, 70, LW, 170, "wide", "1")
sectionLabel(loadCol, "MOVEMENT", 0, 256, LW)
makeSlot("move", 1, 0, 276, LW, 66, "row")
sectionLabel(loadCol, "GADGETS", 0, 358, LW)
for i = 1, 3 do makeSlot("gadget", i, (i - 1) * 144, 378, 132, 104, "tile", tostring(i + 1)) end
sectionLabel(loadCol, "RESERVE", 0, 498, LW)
for i = 1, 3 do makeSlot("reserve", i, (i - 1) * 144, 518, 132, 104, "tile", "R" .. i) end
sectionLabel(loadCol, "OUTFIT", 0, 638, LW)
makeSlot("skin", 1, 0, 658, LW, 80, "row")

-- ================= overlay (picker / invite / mode) over the stage =================
local OX, OY, OW, OH = 56, 116, 1364, 776
local overlay = frame(stage, OX, OY, OW, OH, C.bg, 0.04)
overlay.ZIndex, overlay.Visible, overlay.Active = 8, false, true
border(overlay, C.line, 1)
local views = {}
for _, name in { "pick", "invite", "mode" } do
	views[name] = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, overlay)
end

local setView -- forward
local function viewHeader(v, title, sub)
	local t = lbl(v, title, 40, 32, 18, 900, 50, C.text, "H")
	local s = lbl(v, sub, 12, 34, 70, 900, 16, C.dim, "M")
	local close = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(OW - 160, 28),
		Size = UDim2.fromOffset(130, 30) }, v)
	local cl = keyHint(close, "ESC", "CLOSE", 0, 3)
	close.MouseEnter:Connect(function() tween(cl, FAST, { TextColor3 = C.text }) end)
	close.MouseLeave:Connect(function() tween(cl, FAST, { TextColor3 = C.dim }) end)
	close.MouseButton1Click:Connect(function() setView("home") end)
	frame(v, 32, 100, OW - 64, 1, C.line, 0)
	return t, s
end

-- ----- pick view -----
local pick = views.pick
local pickTitle, pickSub = viewHeader(pick, "", "")
local pickScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 112), Size = UDim2.fromOffset(OW - 48, OH - 128), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, pick)
local pickGrid = new("UIGridLayout", { CellSize = UDim2.fromOffset(312, 208), CellPadding = UDim2.fromOffset(16, 16), SortOrder = Enum.SortOrder.LayoutOrder }, pickScroll)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingBottom = UDim.new(0, 16) }, pickScroll)

local PICK_TITLES = { move = "MOVEMENT", weapon = "PRIMARY", gadget = "GADGET", reserve = "RESERVE", skin = "OUTFIT" }
local PICK_SUBS = {
	move = "SPECIAL MOVEMENT ABILITY  //  EVERYONE KEEPS SPRINT, SLIDE AND MANTLE",
	weapon = "THE GUN YOU DEPLOY WITH",
	gadget = "GADGETS SIT ON KEYS 2 - 4 IN THE MATCH",
	reserve = "SWAP WITH YOUR ACTIVE LOADOUT WHILE DEAD",
	skin = "WORN IN THE LOBBY, ON THE STAGE AND IN THE MATCH",
}
local function itemsFor(kind)
	if kind == "move" then return Catalog.Moves end
	if kind == "weapon" then return Catalog.Weapons end
	if kind == "gadget" then return Catalog.Gadgets end
	local l = {}
	for _, i in Catalog.Weapons do table.insert(l, i) end
	for _, i in Catalog.Gadgets do table.insert(l, i) end
	return l
end

local rebuildSquadSoon
local function pushLoadout()
	localEdited = true
	SetLoadoutR:FireServer(loadout)
end
local function setSlot(kind, idx, id)
	if kind == "weapon" then
		if id == "" then return end
		loadout.Weapon = id
	elseif kind == "move" then
		loadout.Move = id
	else
		local arr = (kind == "gadget") and loadout.Gadgets or loadout.Reserve
		if id ~= "" then
			for j = 1, 3 do
				if j ~= idx and arr[j] == id then arr[j] = arr[idx] break end
			end
		end
		arr[idx] = id
	end
	pushLoadout()
end

-- shared card shell for the pickers
local function pickCard(order, equipped)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = order }, pickScroll)
	local st = border(b, equipped and C.red or C.line, equipped and 2 or 1)
	b.MouseEnter:Connect(function()
		tween(b, FAST, { BackgroundColor3 = C.panel2 })
		if not equipped then tween(st, FAST, { Color = C.line2 }) end
	end)
	b.MouseLeave:Connect(function()
		tween(b, FAST, { BackgroundColor3 = C.panel })
		if not equipped then tween(st, FAST, { Color = C.line }) end
	end)
	if equipped then
		local tag = frame(b, 0, 0, 86, 20, C.red, 0)
		tag.ZIndex = 3
		lbl(tag, "EQUIPPED", 11, 0, 0, 86, 20, C.text, "MB", Enum.TextXAlignment.Center)
	end
	return b
end

local skinFigs = {} -- figures in the skin picker (animated while visible)
local equipSkin -- forward
local buildPick
function buildPick()
	for _, c in pickScroll:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	for _, f in skinFigs do f:Destroy() end
	table.clear(skinFigs)
	local kind, idx = pickKind, pickIdx
	pickTitle.Text = PICK_TITLES[kind] .. ((kind == "gadget" or kind == "reserve") and ("  /  SLOT " .. idx) or "")
	pickSub.Text = PICK_SUBS[kind] or ""
	local current = slotItemId(kind, idx)

	if kind == "skin" then
		pickGrid.CellSize = UDim2.fromOffset(410, 610)
		for i, sk in Skins.List do
			local on = sk.id == mySkin
			local b = pickCard(i, on)
			local well = frame(b, 1, 1, 408, 478, C.void, 0)
			grad(well, sk.card:Lerp(BLACK, 0.72), C.void, 90)
			lbl(well, ("%02d"):format(i), 13, 16, 30, 60, 16, C.mute, "MB")
			local fv = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(130, 132, 140),
				LightColor = rgb(255, 250, 244), LightDirection = Vector3.new(-0.5, -0.85, -0.6) }, well)
			local cam = new("Camera", { FieldOfView = 30 }, fv)
			cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.3, 19), Vector3.new(0, 3.8, 0))
			fv.CurrentCamera = cam
			local fig = Skins.NewFigure(fv, sk.id, { weapon = loadout.Weapon, camPos = Vector3.new(0, 4.3, 19) })
			fig:SetRoot(CFrame.Angles(0, math.rad(28), 0))
			table.insert(skinFigs, fig)
			lbl(b, sk.name, 30, 18, 490, 380, 38, C.text, "H")
			lbl(b, string.upper(sk.sub), 11, 19, 528, 380, 14, on and C.redHi or C.dim, "M")
			local ds = lbl(b, sk.desc, 13, 18, 550, 372, 40, C.dim, "B")
			ds.TextWrapped, ds.TextYAlignment = true, Enum.TextYAlignment.Top
			b.MouseButton1Click:Connect(function() equipSkin(sk.id) end)
		end
		return
	end

	local wide = (kind == "weapon" or kind == "reserve")
	pickGrid.CellSize = wide and UDim2.fromOffset(312, 208) or UDim2.fromOffset(246, 208)
	local cw = pickGrid.CellSize.X.Offset
	local function card(item, order)
		local equipped = (item and item.id == current) or (not item and current == "")
		local b = pickCard(order, equipped)
		if item then
			local well = frame(b, 1, 1, cw - 2, 140, C.void, 0.2)
			local pic = new("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -20), BackgroundTransparency = 1 }, well)
			itemPicture(pic, item, 26)
			lbl(b, string.upper(item.name), 22, 16, 148, cw - 32, 30, C.text, "H")
			lbl(b, string.upper(item.sub), 11, 17, 180, cw - 32, 14, C.dim, "M")
		else
			emptyMark(b, cw, 150)
			lbl(b, "NONE", 22, 16, 148, cw - 32, 30, C.dim, "H")
			lbl(b, "LEAVE THIS SLOT EMPTY", 11, 17, 180, cw - 32, 14, C.mute, "M")
		end
		b.MouseButton1Click:Connect(function()
			setSlot(kind, idx, item and item.id or "")
			refreshLoadoutBar()
			buildPick()
			if kind == "weapon" then rebuildSquadSoon() end
		end)
	end
	if kind ~= "weapon" then card(nil, 0) end
	for i, item in itemsFor(kind) do card(item, i) end
end

local function openPick(kind, idx)
	pickKind, pickIdx = kind, idx
	buildPick()
	setView("pick")
end
for _, s in slots do
	s.frame.MouseButton1Click:Connect(function()
		if view == "pick" and pickKind == s.kind and pickIdx == s.idx then setView("home") else openPick(s.kind, s.idx) end
	end)
end

-- ----- invite view -----
local inviteV = views.invite
viewHeader(inviteV, "INVITE", "SQUADS ARE UP TO 3 PLAYERS  //  ONLY THE LEADER CAN INVITE")
local inviteTab = "lobby"
local tabs = {}
for i, name in { "lobby", "friends" } do
	local b = new("TextButton", { Text = string.upper(name), TextSize = 18, FontFace = FONTS.H, TextColor3 = C.dim, BackgroundTransparency = 1,
		AutoButtonColor = false, Position = UDim2.fromOffset(32 + (i - 1) * 112, 116), Size = UDim2.fromOffset(100, 40) }, inviteV)
	local u = frame(b, 0, 38, 100, 2, C.red, 0)
	tabs[name] = { b = b, u = u }
end
local search = new("TextBox", { PlaceholderText = "Search players...", Text = "", TextSize = 16, FontFace = FONTS.B, TextColor3 = C.text,
	PlaceholderColor3 = C.mute, BackgroundColor3 = C.panel, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(276, 116), Size = UDim2.fromOffset(520, 40), BorderSizePixel = 0 }, inviteV)
local searchStroke = border(search, C.line, 1)
search.Focused:Connect(function() searchStroke.Color = C.line2 end)
search.FocusLost:Connect(function() searchStroke.Color = C.line end)
new("UIPadding", { PaddingLeft = UDim.new(0, 14) }, search)
local inviteHint = lbl(inviteV, "", 12, 820, 116, 500, 40, C.redHi, "M")
local inviteScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 172), Size = UDim2.fromOffset(OW - 48, OH - 188), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, inviteV)
new("UIListLayout", { Padding = UDim.new(0, 8) }, inviteScroll)
new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 4) }, inviteScroll)

local friendsCache, friendsLoading = nil, false
local sentAt = {}
local rebuildInvite

local function loadFriends()
	if friendsLoading then return end
	friendsLoading = true
	task.spawn(function()
		local ok, res = pcall(function() return player:GetFriendsOnline(200) end)
		friendsCache = (ok and type(res) == "table") and res or {}
		friendsLoading = false
		if view == "invite" then rebuildInvite() end
	end)
end

function rebuildInvite()
	for _, c in inviteScroll:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	for name, t in tabs do
		t.b.TextColor3 = (name == inviteTab) and C.text or C.dim
		t.u.Visible = name == inviteTab
	end

	local list, leader = partyInfo()
	local inParty = {}
	for _, m in list do inParty[m.id] = true end
	local full = #list >= 3
	local canInvite = (leader == player.UserId) and not full
	inviteHint.Text = (leader ~= player.UserId) and "ONLY THE PARTY LEADER CAN INVITE." or (full and "YOUR PARTY IS FULL." or "")

	local entries = {}
	if inviteTab == "lobby" then
		for _, p in Players:GetPlayers() do
			if p ~= player and not inParty[p.UserId] then
				table.insert(entries, { id = p.UserId, name = p.Name, display = p.DisplayName, ok = true, note = "IN THIS LOBBY" })
			end
		end
	else
		if not friendsCache then
			loadFriends()
		else
			for _, f in friendsCache do
				local inLobby = f.PlaceId == game.PlaceId
				if not inParty[f.VisitorId] then
					table.insert(entries, { id = f.VisitorId, name = f.UserName, display = f.DisplayName or f.UserName, ok = inLobby,
						note = inLobby and "IN THE LOBBY" or "ONLINE  //  ANOTHER GAME" })
				end
			end
		end
	end
	local q = string.lower(search.Text)
	local shown = {}
	for _, e in entries do
		if q == "" or string.find(string.lower(e.name), q, 1, true) or string.find(string.lower(e.display), q, 1, true) then table.insert(shown, e) end
	end
	table.sort(shown, function(a, b)
		if a.ok ~= b.ok then return a.ok end
		return string.lower(a.name) < string.lower(b.name)
	end)

	if #shown == 0 then
		local msg = (inviteTab == "friends" and not friendsCache) and "Loading friends..."
			or (q ~= "" and #q >= 3) and ("No match. Press Enter to invite \"" .. search.Text .. "\" by exact username.")
			or (inviteTab == "lobby" and "Nobody else is in this lobby. Try Friends, or search a username.")
			or "No friends online."
		new("TextLabel", { BackgroundTransparency = 1, Text = msg, TextSize = 16, FontFace = FONTS.B, TextColor3 = C.dim,
			Size = UDim2.new(1, 0, 0, 80), TextWrapped = true }, inviteScroll)
		return
	end
	for i, e in shown do
		local row = new("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = i }, inviteScroll)
		border(row, C.line, 1)
		local av = new("ImageLabel", { BackgroundColor3 = C.panel3, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(48, 48), Image = thumb(e.id) }, row)
		av.ImageTransparency = e.ok and 0 or 0.5
		lbl(row, string.upper(e.display), 22, 72, 6, 600, 30, e.ok and C.text or C.dim, "H")
		lbl(row, "@" .. e.name .. "   //   " .. e.note, 11, 73, 38, 700, 16, e.ok and C.dim or C.mute, "M")
		local sent = sentAt[e.id] and os.clock() - sentAt[e.id] < 8
		local usable = canInvite and e.ok and not sent
		local plus = button(row, sent and "SENT" or "INVITE", 0, 14, 120, 36, usable and "primary" or "ghost", 16)
		plus.Position = UDim2.new(1, -134, 0, 14)
		if not usable then plus.TextColor3 = C.mute end
		plus.MouseButton1Click:Connect(function()
			if not canInvite or not e.ok or sentAt[e.id] and os.clock() - sentAt[e.id] < 8 then return end
			sentAt[e.id] = os.clock()
			InviteR:FireServer(e.id)
			rebuildInvite()
			task.delay(8.1, function() if view == "invite" then rebuildInvite() end end)
		end)
	end
end
tabs.lobby.b.MouseButton1Click:Connect(function() inviteTab = "lobby" rebuildInvite() end)
tabs.friends.b.MouseButton1Click:Connect(function() inviteTab = "friends" rebuildInvite() end)
search:GetPropertyChangedSignal("Text"):Connect(function() if view == "invite" then rebuildInvite() end end)
search.FocusLost:Connect(function(enter)
	if enter and #search.Text >= 3 then
		local list, leader = partyInfo()
		if leader == player.UserId and #list < 3 then
			InviteR:FireServer(search.Text)
			search.Text = ""
		end
	end
end)
Players.PlayerAdded:Connect(function() if view == "invite" then rebuildInvite() end end)
Players.PlayerRemoving:Connect(function() if view == "invite" then task.defer(rebuildInvite) end end)

-- ----- game mode graphic: flat top-down map (red end, wall with holes, blue end) -----
local function modeGraphic(parent)
	local g = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(12, 13, 17), BorderSizePixel = 0, ClipsDescendants = true }, parent)
	for i = 1, 7 do -- faint grid
		new("Frame", { Position = UDim2.fromScale(i / 8, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.line, BackgroundTransparency = 0.5, BorderSizePixel = 0 }, g)
		new("Frame", { Position = UDim2.fromScale(0, i / 8), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.line, BackgroundTransparency = 0.5, BorderSizePixel = 0 }, g)
	end
	local function zone(xs, col, edgeRight)
		new("Frame", { Position = UDim2.fromScale(xs, 0), Size = UDim2.fromScale(0.14, 1), BackgroundColor3 = col, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, g)
		new("Frame", { Position = UDim2.new(xs + (edgeRight and 0.14 or 0), edgeRight and -2 or 0, 0, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0 }, g)
	end
	zone(0, C.red, true)
	zone(0.86, C.blue, false)
	-- the wall (slightly toward blue = red is pushing) with 3 holes per side
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.58, 0.06), Size = UDim2.new(0, 3, 0.88, 0), BackgroundColor3 = C.text, BorderSizePixel = 0 }, g)
	for i = 1, 3 do
		for _, side in { -1, 1 } do
			local plugged = side == -1 and i ~= 3
			local h = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.58, side * 9, i / 4, 0), Size = UDim2.fromOffset(9, 9),
				BackgroundColor3 = plugged and C.red or C.panel3, BorderSizePixel = 0 }, g)
			border(h, side == -1 and C.red or C.blue, 1, 0.3)
		end
	end
	-- loose boxes
	for _, b in { { 0.3, 0.3 }, { 0.38, 0.7 }, { 0.74, 0.44 } } do
		local s = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(b[1], b[2]), Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = C.dim, BorderSizePixel = 0 }, g)
		border(s, C.text, 1, 0.6)
	end
	-- push arrow
	local a = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.68, 0.9), Size = UDim2.fromOffset(28, 2), BackgroundColor3 = C.red, BorderSizePixel = 0 }, g)
	chevron(a, 22, -6, 6, C.red, 2)
	return g
end

-- ----- mode info view -----
local modeV = views.mode
viewHeader(modeV, "GAME MODE", "CHOOSE WHAT YOU QUEUE FOR")
local modeArt = frame(modeV, 32, 124, 600, 450, C.panel, 0)
border(modeArt, C.line, 1)
modeGraphic(modeArt)
local mTitle = lbl(modeV, "", 72, 668, 112, 640, 84, C.text, "H")
local mTag = lbl(modeV, "", 13, 671, 196, 640, 16, C.redHi, "MB")
local mDesc = lbl(modeV, "", 16, 670, 228, 640, 110, C.dim, "B")
mDesc.TextWrapped, mDesc.TextYAlignment = true, Enum.TextYAlignment.Top
local mFacts = new("Frame", { Position = UDim2.fromOffset(670, 350), Size = UDim2.fromOffset(640, 180), BackgroundTransparency = 1 }, modeV)
local mSelect = button(modeV, "SELECT", 670, 518, 260, 56, "primary", 24)
local modeShown = MODES[1]
local modeCardSel -- forward (bottom-left card refresh)
local function openMode(m)
	modeShown = m
	mTitle.Text, mTag.Text, mDesc.Text = m.name, m.tag, m.desc
	for _, c in mFacts:GetChildren() do c:Destroy() end
	for i, f in m.facts do
		local y = (i - 1) * 30
		frame(mFacts, 0, y + 9, 6, 6, C.red, 0)
		lbl(mFacts, f, 16, 20, y, 600, 24, C.text, "B")
	end
	mSelect.Text = (selectedMode == m.id) and "SELECTED" or "SELECT"
	setView("mode")
end
mSelect.MouseButton1Click:Connect(function()
	selectedMode = modeShown.id
	if modeCardSel then modeCardSel() end
	setView("home")
end)

function setView(name)
	view = name
	overlay.Visible = name ~= "home"
	for n, f in views do f.Visible = (n == name) end
	nameLayer.Visible = name == "home"
	for _, s in slots do drawSlot(s) end
	if name == "invite" then rebuildInvite() end
	if name ~= "pick" then
		for _, f in skinFigs do f:Destroy() end
		table.clear(skinFigs)
	end
end

-- ================= bottom row: game mode | party | start =================
local BY, BH = 916, 112

-- game mode card
local modeCard = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BackgroundTransparency = 0.12, BorderSizePixel = 0,
	Position = UDim2.fromOffset(56, BY), Size = UDim2.fromOffset(364, BH), ZIndex = 5 }, stage)
do
	local st = border(modeCard, C.line, 1)
	hoverable(modeCard, C.panel, C.panel2, st, C.line, C.line2)
	local th = frame(modeCard, 10, 10, 128, BH - 20, C.panel, 0)
	modeGraphic(th)
	lbl(modeCard, "GAME MODE", 11, 154, 14, 190, 14, C.mute, "M")
	local nm = lbl(modeCard, "", 30, 154, 28, 190, 40, C.text, "H")
	local tg = lbl(modeCard, "", 11, 155, 74, 190, 14, C.dim, "M")
	chevron(modeCard, 364 - 26, BH / 2 - 8, 8, C.mute, 2)
	function modeCardSel()
		for _, m in MODES do
			if m.id == selectedMode then nm.Text, tg.Text = m.name, m.tag end
		end
	end
	modeCardSel()
	modeCard.MouseButton1Click:Connect(function()
		for _, m in MODES do if m.id == selectedMode then openMode(m) end end
	end)
end

-- party: 3 slots, the leader is always the leftmost
local PX, PW, PGAP = 444, 316, 14
local partyHolder = new("Frame", { Position = UDim2.fromOffset(PX, BY), Size = UDim2.fromOffset(PW * 3 + PGAP * 2, BH), BackgroundTransparency = 1, ZIndex = 5 }, stage)
lbl(stage, "SQUAD", 11, PX, BY - 22, 200, 14, C.mute, "M").ZIndex = 5
local squadCount = lbl(stage, "", 11, PX + PW * 3 + PGAP * 2 - 200, BY - 22, 200, 14, C.mute, "M", Enum.TextXAlignment.Right)
squadCount.ZIndex = 5

local function smallBtn(parent, text, x, y, w, danger)
	local b = new("TextButton", { Text = text, TextSize = 11, FontFace = FONTS.MB, TextColor3 = danger and C.redHi or C.dim, BackgroundColor3 = C.panel2,
		AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 22) }, parent)
	local st = border(b, danger and C.redDeep or C.line, 1)
	hoverable(b, C.panel2, C.panel3, st, danger and C.redDeep or C.line, danger and C.red or C.line2)
	return b
end

local function renderParty()
	for _, c in partyHolder:GetChildren() do c:Destroy() end
	local list, leader = partyInfo()
	local iLead = (leader == player.UserId)
	local ordered = {}
	for _, m in list do if m.id == leader then table.insert(ordered, m) end end
	for _, m in list do if m.id ~= leader then table.insert(ordered, m) end end
	squadCount.Text = ("%d / 3"):format(#ordered)

	for i = 1, 3 do
		local m = ordered[i]
		local x = (i - 1) * (PW + PGAP)
		if m then
			local isMe = m.id == player.UserId
			local isLeader = m.id == leader
			local f = frame(partyHolder, x, 0, PW, BH, C.panel, 0.12)
			border(f, C.line, 1)
			if isLeader then frame(f, 0, 0, PW, 2, C.red, 0) end
			local av = new("ImageLabel", { BackgroundColor3 = C.panel3, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(BH - 20, BH - 20),
				Image = thumb(m.id) }, f)
			border(av, C.line, 1)
			local tx = BH + 4
			local role = isLeader and "LEADER" or (isMe and "YOU" or "MEMBER")
			lbl(f, role .. ((isLeader and isMe) and "  //  YOU" or ""), 11, tx, 12, PW - tx - 10, 14, isLeader and C.redHi or C.mute, "MB")
			local nm = lbl(f, string.upper(isMe and player.DisplayName or m.name), 24, tx, 26, PW - tx - 10, 32, C.text, "H")
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			lbl(f, "@" .. m.name, 11, tx, 58, PW - tx - 10, 14, C.dim, "M").TextTruncate = Enum.TextTruncate.AtEnd
			if iLead and not isMe then
				local prom = smallBtn(f, "PROMOTE", tx, BH - 32, 84)
				local kick = smallBtn(f, "KICK", tx + 92, BH - 32, 56, true)
				prom.MouseButton1Click:Connect(function() PromoteR:FireServer(m.id) end)
				kick.MouseButton1Click:Connect(function() KickR:FireServer(m.id) end)
			elseif isMe and #list > 1 then
				local lv = smallBtn(f, "LEAVE PARTY", tx, BH - 32, 110, true)
				lv.MouseButton1Click:Connect(function() LeaveR:FireServer() end)
			end
		else
			local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(PW, BH),
				BackgroundColor3 = C.void, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, partyHolder)
			local st = border(f, C.line, 1)
			hoverable(f, C.void, C.panel2, st, C.line, C.red)
			local well = frame(f, 10, 10, BH - 20, BH - 20, C.panel, 0.4)
			border(well, C.line, 1)
			emptyMark(well, BH - 20, BH - 20)
			lbl(f, "OPEN SLOT", 11, BH + 4, 30, 200, 14, C.mute, "MB")
			lbl(f, "INVITE", 24, BH + 4, 44, 200, 32, C.dim, "H")
			f.MouseButton1Click:Connect(function() setView("invite") end)
		end
	end
	if view == "invite" then rebuildInvite() end
end

-- start / queue
local startBtn, startMain, startSub, startPaint = actionBlock(stage, LX, BY, LW, BH, "START", "")
startBtn.ZIndex = 5

local function fmtTime(s) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
local function refreshQueue()
	local q, tp = player:GetAttribute("Queued"), player:GetAttribute("Teleporting")
	local list, leader = partyInfo()
	local iLead = (leader == player.UserId)
	local mode = MODES[1]
	if tp then
		startMain.Text, startSub.Text = "DEPLOYING", "JOINING MATCH..."
		startPaint("wait")
	elseif q then
		local qa = player:GetAttribute("QueuedAt")
		startMain.Text, startSub.Text = "CANCEL", "SEARCHING  " .. fmtTime(math.max(0, os.time() - (qa or os.time())))
		startPaint("cancel")
	elseif not iLead then
		startMain.Text, startSub.Text = "WAITING", "ONLY THE LEADER CAN START"
		startPaint("wait")
	else
		startMain.Text, startSub.Text = "START", mode.name .. (#list > 1 and ("  //  PARTY OF " .. #list) or "  //  3V3")
		startPaint("go")
	end
	hudStatus.Text = tp and "JOINING MATCH..." or (q and ("SEARCHING FOR PLAYERS  " .. fmtTime(math.max(0, os.time() - (player:GetAttribute("QueuedAt") or os.time())))) or "")
end
startBtn.MouseButton1Click:Connect(function()
	if player:GetAttribute("Teleporting") then return end
	local _, leader = partyInfo()
	if leader ~= player.UserId and not player:GetAttribute("Queued") then say("Only the party leader can start the search.") return end
	QueueR:FireServer(not player:GetAttribute("Queued"))
end)

local squadQueued = false
function rebuildSquadSoon()
	if squadQueued then return end
	squadQueued = true
	task.defer(function()
		squadQueued = false
		rebuildSquad()
	end)
end

for _, k in { "Queued", "Teleporting", "QueuedAt" } do player:GetAttributeChangedSignal(k):Connect(refreshQueue) end
for _, k in { "PartyId", "PartyLeader", "PartyMembers" } do
	player:GetAttributeChangedSignal(k):Connect(function() renderParty() refreshQueue() rebuildSquadSoon() end)
end
local function watchOther(p)
	p:GetAttributeChangedSignal("Skin"):Connect(function() rebuildSquadSoon() if screenOpen then renderParty() end end)
	p:GetAttributeChangedSignal("LoadoutJson"):Connect(rebuildSquadSoon)
end
for _, p in Players:GetPlayers() do if p ~= player then watchOther(p) end end
Players.PlayerAdded:Connect(watchOther)
task.spawn(function()
	while true do
		task.wait(1)
		if player:GetAttribute("Queued") then refreshQueue() end
	end
end)

-- ================= skins =================
function equipSkin(id)
	if not Skins.Is(id) or id == mySkin then return end
	mySkin = id
	SetSkinR:FireServer(id)
	refreshLoadoutBar()
	if view == "pick" and pickKind == "skin" then buildPick() end
	rebuildSquadSoon()
end
player:GetAttributeChangedSignal("Skin"):Connect(function()
	local s = player:GetAttribute("Skin")
	if Skins.Is(s) and s ~= mySkin then
		mySkin = s
		refreshLoadoutBar()
		if view == "pick" and pickKind == "skin" then buildPick() end
		rebuildSquadSoon()
	end
end)

-- ================= open / close =================
local cover = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.void, BorderSizePixel = 0, ZIndex = 50, Visible = false }, screen)

function openScreen(startView)
	if not screenOpen then
		screenOpen = true
		screen.Visible = true
		hud.Visible = false
		-- cut in from black
		cover.Visible, cover.BackgroundTransparency = true, 0
		tween(cover, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		task.delay(0.36, function() cover.Visible = false end)
	end
	setView(startView or "home")
	renderParty()
	refreshQueue()
	rebuildSquad()
end
local function closeScreen()
	if not screenOpen then return end
	screenOpen = false
	setView("home")
	screen.Visible = false
	hud.Visible = true
end
local function openSkins()
	if not screenOpen then openScreen("home") end
	openPick("skin", 1)
end
homePlay.MouseButton1Click:Connect(function() openScreen("home") end)
homePlus.MouseButton1Click:Connect(function() openScreen("invite") end)
closeBtn.MouseButton1Click:Connect(closeScreen)
skinsKey.MouseButton1Click:Connect(function()
	if view == "pick" and pickKind == "skin" then setView("home") else openSkins() end
end)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe or UIS:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Tab then
		if screenOpen and view == "pick" and pickKind == "skin" then setView("home") else openSkins() end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if screenOpen and view ~= "home" then setView("home")
		elseif screenOpen then closeScreen() end
	end
end)

-- ================= render loop (idle figures + name positions + slow star breathing) =================
local t0 = os.clock()
RunService.RenderStepped:Connect(function(dt)
	if not screenOpen then return end
	dt = math.min(dt, 0.1)
	local t = os.clock() - t0
	for _, s in twinkles do
		s.f.BackgroundTransparency = math.clamp(s.base + 0.35 * (0.5 + 0.5 * math.sin(t * s.spd + s.ph)), 0, 0.95)
	end
	if view == "home" then
		for _, s in squad do
			s.fig:Update(t, dt)
			local p = project((s.root * CFrame.new(0, s.top + 0.55, 0)).Position)
			if p then s.tag.Position = UDim2.fromOffset(p.X, p.Y) end
		end
	elseif view == "pick" then
		for _, f in skinFigs do f:Update(t, dt) end
	end
end)

-- ================= invite popup + notices =================
local popC = canvas(gui, 60)
local popW = 460
local pop_ = frame(popC, (1920 - popW) / 2, -150, popW, 128, C.bg, 0)
border(pop_, C.line2, 1)
frame(pop_, 0, 0, popW, 3, C.red, 0)
lbl(pop_, "PARTY INVITE", 11, 22, 14, 300, 14, C.redHi, "MB")
local popText = lbl(pop_, "", 24, 22, 30, popW - 44, 32, C.text, "H")
popText.TextTruncate = Enum.TextTruncate.AtEnd
local yes = button(pop_, "ACCEPT", 22, 72, 202, 40, "primary", 17)
local no = button(pop_, "DECLINE", 236, 72, 202, 40, "ghost", 17)
local current
local function showPop(on)
	tween(pop_, EASE, { Position = UDim2.fromOffset((1920 - popW) / 2, on and 24 or -150) })
end
yes.MouseButton1Click:Connect(function() if current then RespondR:FireServer(current, true) current = nil showPop(false) end end)
no.MouseButton1Click:Connect(function() if current then RespondR:FireServer(current, false) current = nil showPop(false) end end)

NoticeR.OnClientEvent:Connect(function(d)
	if type(d) ~= "table" then return end
	if d.kind == "msg" then
		if screenOpen then say(tostring(d.text)) else hudStatus.Text = string.upper(tostring(d.text)) task.delay(4, refreshQueue) end
	elseif d.kind == "invite" then
		current = d.id
		popText.Text = string.upper(tostring(d.fromName)) .. " INVITED YOU"
		showPop(true)
		task.delay(30, function() if current == d.id then current = nil showPop(false) end end)
	end
end)

-- ================= start-up =================
rescale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end
player:GetAttributeChangedSignal("LoadoutJson"):Connect(function()
	if readLoadout() then refreshLoadoutBar() rebuildSquadSoon() end
end)
refreshLoadoutBar()
renderParty()
refreshQueue()
