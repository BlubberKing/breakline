-- LobbyClient v2 (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only.
-- Builds the whole lobby UI in code:
--   * home HUD: BREAKLINE title, souls (blue ball) top right, big green PLAY button at the bottom
--   * PLAY screen: gamemode list (left), middle panel (character showcase / item picker / invite / gamemode info),
--     loadout bar (movement | weapon | gadgets x3 | reserve x3), party row (invite box, you, 2 more) and START
-- Needs ReplicatedStorage.LobbyCatalog (ModuleScript) and the LobbyRemotes made by PartyService.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = RS:WaitForChild("LobbyRemotes")
local QueueR, InviteR, RespondR, LeaveR, KickR, NoticeR =
	remotes:WaitForChild("Queue"), remotes:WaitForChild("Invite"), remotes:WaitForChild("Respond"),
	remotes:WaitForChild("Leave"), remotes:WaitForChild("Kick"), remotes:WaitForChild("Notice")
local PromoteR, SetLoadoutR = remotes:WaitForChild("Promote"), remotes:WaitForChild("SetLoadout")
local Catalog = require(RS:WaitForChild("LobbyCatalog"))

-- ================= theme + helpers =================
local C = {
	bg = Color3.fromRGB(9, 11, 19), panel = Color3.fromRGB(19, 23, 35), panel2 = Color3.fromRGB(27, 32, 48),
	line = Color3.fromRGB(52, 60, 86), text = Color3.fromRGB(236, 241, 255), dim = Color3.fromRGB(139, 150, 180),
	green = Color3.fromRGB(52, 208, 112), greenDark = Color3.fromRGB(26, 140, 74),
	blue = Color3.fromRGB(80, 170, 255), ice = Color3.fromRGB(190, 230, 255),
	red = Color3.fromRGB(232, 72, 80), amber = Color3.fromRGB(255, 176, 50), gray = Color3.fromRGB(78, 86, 110),
}
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o) end
local function circle(o) return new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, o) end
local function stroke(o, color, thick, transp)
	return new("UIStroke", { Color = color, Thickness = thick or 1.5, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function grad(o, c0, c1, rot)
	o.BackgroundColor3 = WHITE
	return new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 90 }, o)
end
local function frame(parent, x, y, w, h, color, transp)
	return new("Frame", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.panel, BackgroundTransparency = transp or 0, BorderSizePixel = 0,
	}, parent)
end
local function lbl(parent, text, size, x, y, w, h, color, font, align)
	return new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size, Font = font or Enum.Font.GothamBold,
		TextColor3 = color or C.text, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		TextXAlignment = align or Enum.TextXAlignment.Left, TextWrapped = false,
	}, parent)
end
local function pop(b, amt)
	local s = new("UIScale", {}, b)
	b.MouseEnter:Connect(function() TweenService:Create(s, TweenInfo.new(0.12), { Scale = amt or 1.04 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	return s
end
local function btn(parent, text, x, y, w, h, color, size, textColor)
	local b = new("TextButton", {
		Text = text, TextSize = size or 16, Font = Enum.Font.GothamBlack, TextColor3 = textColor or WHITE,
		BackgroundColor3 = color, AutoButtonColor = false, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
	}, parent)
	corner(b, 10)
	pop(b, 1.04)
	return b
end
local function thumb(id, kind)
	return ("rbxthumb://type=%s&id=%d&w=150&h=150"):format(kind or "AvatarHeadShot", id)
end
local function dark(c, a) return c:Lerp(BLACK, a) end

-- a glowing blue soul ball
local function soulBall(parent, x, y, size)
	local holder = frame(parent, x, y, size, size, WHITE, 1)
	local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.7, 1.7),
		BackgroundColor3 = C.blue, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, holder)
	circle(glow)
	local ball = new("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, holder)
	circle(ball)
	grad(ball, C.ice, Color3.fromRGB(40, 120, 240), 60)
	stroke(ball, C.ice, 1.5, 0.45)
	local hi = new("Frame", { Position = UDim2.fromScale(0.2, 0.16), Size = UDim2.fromScale(0.28, 0.2), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, Rotation = -30 }, ball)
	circle(hi)
	TweenService:Create(glow, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.93, Size = UDim2.fromScale(2.1, 2.1) }):Play()
	return holder
end

-- souls + W/L pill; returns a function that refreshes it
local function soulsPill(parent, x, y)
	local p = frame(parent, x, y, 250, 56, C.panel, 0.15)
	circle(p)
	stroke(p, C.blue, 1.5, 0.5)
	soulBall(p, 12, 12, 32)
	local n = lbl(p, "0", 26, 58, 2, 180, 32, C.ice, Enum.Font.GothamBlack)
	local sub = lbl(p, "SOULS", 12, 58, 32, 180, 18, C.dim)
	local function upd()
		n.Text = tostring(player:GetAttribute("Souls") or 0)
		sub.Text = ("SOULS   -   %d W   %d L"):format(player:GetAttribute("Wins") or 0, player:GetAttribute("Losses") or 0)
	end
	for _, k in { "Souls", "Wins", "Losses" } do player:GetAttributeChangedSignal(k):Connect(upd) end
	upd()
	return upd
end

-- ================= data =================
local MODES = {
	{
		id = "breakline", name = "BREAKLINE", tag = "3v3  -  WALL PUSH",
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

-- ================= root gui =================
local gui = new("ScreenGui", { Name = "LobbyUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- ---------- home HUD ----------
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, gui)
local title = new("TextLabel", { BackgroundTransparency = 1, Text = "BREAKLINE", TextSize = 64, Font = Enum.Font.GothamBlack,
	TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(520, 76) }, hud)
new("UIStroke", { Color = dark(C.blue, 0.4), Thickness = 3, Transparency = 0.2 }, title)
new("UIGradient", { Color = ColorSequence.new(WHITE, C.ice), Rotation = 90 }, title)
local hudPill = frame(hud, 0, 0, 250, 56, WHITE, 1)
hudPill.AnchorPoint, hudPill.Position = Vector2.new(1, 0), UDim2.new(1, -24, 0, 22)
soulsPill(hudPill, 0, 0)

local playBtn = new("TextButton", {
	Text = "PLAY", TextSize = 46, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, AutoButtonColor = false, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(340, 88),
}, hud)
corner(playBtn, 18)
grad(playBtn, Color3.fromRGB(86, 236, 140), C.greenDark, 90)
local playStroke = stroke(playBtn, Color3.fromRGB(170, 255, 205), 3, 0.35)
new("UIStroke", { Color = dark(C.greenDark, 0.5), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Transparency = 0.2 }, playBtn)
pop(playBtn, 1.06)
TweenService:Create(playStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.85 }):Play()
local hudStatus = new("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = C.ice,
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -164), Size = UDim2.fromOffset(500, 26) }, hud)

-- ---------- play screen ----------
local screen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
	ClipsDescendants = true, ZIndex = 10, Active = true }, gui)
-- backdrop: soft gradient + big diagonal beams
local backdrop = new("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 1 }, screen)
grad(backdrop, Color3.fromRGB(12, 16, 32), Color3.fromRGB(7, 8, 16), 120)
for i, bx in { 0.12, 0.38, 0.66, 0.9 } do
	local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(bx, 0.5), Size = UDim2.new(0, 70 + i * 26, 1.8, 0),
		Rotation = 18, BackgroundColor3 = C.blue, BackgroundTransparency = 0.95, BorderSizePixel = 0, ZIndex = 1 }, screen)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, b)
end

local stage = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1, ZIndex = 2 }, screen)
local stageScale = new("UIScale", {}, stage)
local function rescale()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	stageScale.Scale = math.max(0.3, math.min(vs.X / 1920, vs.Y / 1080))
end
rescale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

-- top bar
lbl(stage, "PLAY", 46, 40, 14, 400, 56, WHITE, Enum.Font.GothamBlack)
lbl(stage, "Pick a mode, set your loadout, gather your party.", 16, 42, 64, 700, 22, C.dim, Enum.Font.GothamMedium)
soulsPill(stage, 1500, 20)
local closeBtn = btn(stage, "X", 1782, 20, 56, 56, C.panel2, 22, C.text)
stroke(closeBtn, C.line, 1.5)

-- toast
local toast = frame(stage, 660, 22, 600, 44, C.panel2, 0.05)
corner(toast, 22)
stroke(toast, C.amber, 1.5, 0.3)
local toastText = lbl(toast, "", 17, 0, 0, 600, 44, C.text, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
toast.Visible = false
local toastToken = 0
local function say(text)
	toastToken += 1
	local my = toastToken
	toastText.Text = text
	toast.Visible = true
	task.delay(4, function() if my == toastToken then toast.Visible = false end end)
end

-- ---------- gamemode list (left) ----------
lbl(stage, "GAMEMODES", 14, 44, 100, 240, 20, C.dim)
local modeScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(40, 126), Size = UDim2.fromOffset(244, 914), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, stage)
new("UIListLayout", { Padding = UDim.new(0, 12) }, modeScroll)
new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }, modeScroll)

-- the little "graphic" for a gamemode (red end, blue end, glowing wall, crates)
local function modeGraphic(parent)
	local g = new("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1 }, parent)
	grad(g, Color3.fromRGB(26, 34, 66), Color3.fromRGB(12, 14, 30), 90)
	local red = new("Frame", { Size = UDim2.fromScale(0.34, 1), BackgroundColor3 = C.red, BackgroundTransparency = 0.55, BorderSizePixel = 0 }, g)
	new("UIGradient", { Transparency = NumberSequence.new(0.2, 1) }, red)
	local blue = new("Frame", { Position = UDim2.fromScale(0.66, 0), Size = UDim2.fromScale(0.34, 1), BackgroundColor3 = C.blue, BackgroundTransparency = 0.55, BorderSizePixel = 0 }, g)
	new("UIGradient", { Transparency = NumberSequence.new(1, 0.2) }, blue)
	local wall = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.06, 0, 1.3, 0),
		Rotation = 14, BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, BorderSizePixel = 0 }, g)
	new("UIGradient", { Color = ColorSequence.new(C.ice, C.blue), Rotation = 90 }, wall)
	local wallGlow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.2, 0, 1.3, 0),
		Rotation = 14, BackgroundColor3 = C.blue, BackgroundTransparency = 0.85, BorderSizePixel = 0 }, g)
	for _, cr in { { 0.18, 0.62, C.red }, { 0.27, 0.74, C.red }, { 0.78, 0.3, C.blue }, { 0.86, 0.46, C.blue } } do
		local s = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cr[1], cr[2]), Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = C.amber, BorderSizePixel = 0, Rotation = 8 }, g)
		corner(s, 4)
		stroke(s, cr[3], 2, 0.1)
	end
	return g
end

local modeCards = {}
local function refreshModes()
	for id, c in modeCards do
		local on = (id == selectedMode)
		TweenService:Create(c.stroke, TweenInfo.new(0.15), { Color = on and C.green or C.line, Thickness = on and 4 or 1.5 }):Play()
		c.tint.BackgroundTransparency = on and 0.7 or 1
		c.tag.Visible = on
	end
end

-- ---------- middle panel ----------
local mid = frame(stage, 304, 100, 1576, 616, C.panel, 0)
mid.ClipsDescendants = true
corner(mid, 18)
stroke(mid, C.line, 1.5, 0.3)
local views = {}
for _, name in { "home", "pick", "invite", "mode" } do
	views[name] = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = (name == "home") }, mid)
end
local view = "home"
local screenOpen = false

-- ----- home: character showcase -----
local home = views.home
local showBg = new("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 1 }, home)
new("UIGradient", { Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 22, 52)), ColorSequenceKeypoint.new(0.55, Color3.fromRGB(26, 16, 58)), ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 34, 64)),
}), Rotation = 35 }, showBg)
showBg.BackgroundColor3 = WHITE
for i, bx in { 0.22, 0.5, 0.78 } do
	local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(bx, 0.5), Size = UDim2.fromOffset(60 + i * 30, 1000),
		Rotation = 16, BackgroundColor3 = WHITE, BackgroundTransparency = 0.95, BorderSizePixel = 0, ZIndex = 1 }, home)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, b)
end
new("TextLabel", { BackgroundTransparency = 1, Text = "BREAKLINE", TextSize = 190, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, TextTransparency = 0.94,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(1500, 220), Rotation = -5, ZIndex = 1 }, home)
local ringOuter = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.fromOffset(560, 84),
	BackgroundColor3 = C.blue, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 1 }, home)
circle(ringOuter)
stroke(ringOuter, C.ice, 2, 0.45)
local ringInner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.fromOffset(380, 54),
	BackgroundColor3 = C.blue, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 1 }, home)
circle(ringInner)
-- floating soul sparks
local sparks = {}
local sparkRng = Random.new(7)
for i = 1, 16 do
	local s = sparkRng:NextInteger(6, 20)
	local f = new("Frame", { Size = UDim2.fromOffset(s, s), BackgroundColor3 = (i % 2 == 0) and C.blue or C.ice, BackgroundTransparency = sparkRng:NextNumber(0.45, 0.85),
		BorderSizePixel = 0, ZIndex = 1 }, home)
	circle(f)
	table.insert(sparks, { f = f, x = sparkRng:NextNumber(0, 1576), y = sparkRng:NextNumber(0, 616), v = sparkRng:NextNumber(14, 40), ph = sparkRng:NextNumber(0, 6) })
end

local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, home)

-- the basic robot skin, built from parts: holding a rifle, looking around every so often
local robot = {}
do
	vp.Ambient = Color3.fromRGB(120, 130, 165)
	vp.LightColor = Color3.fromRGB(255, 244, 226)
	vp.LightDirection = Vector3.new(-0.6, -0.8, -0.55)
	local cam = new("Camera", { FieldOfView = 32, CFrame = CFrame.lookAt(Vector3.new(0, 4.3, 17), Vector3.new(0, 3.5, 0)) }, vp)
	vp.CurrentCamera = cam
	local model = new("Model", {}, vp)
	local list, accents = {}, {}
	local SUIT, ARMOR, TRIM, AMBER = Color3.fromRGB(40, 45, 58), Color3.fromRGB(78, 85, 102), Color3.fromRGB(20, 22, 29), Color3.fromRGB(255, 150, 40)
	local function P(r, y, f) return Vector3.new(-r, y, f) end -- r = to the character's right, f = forward (character faces +Z)
	local function add(group, size, cf, color, neon)
		local p = new("Part", { Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Size = size, Color = color,
			Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic }, model)
		table.insert(list, { part = p, rel = cf, group = group })
		if neon then table.insert(accents, p) end
		return p
	end
	local function bar(a, b, t, color)
		local len = (b - a).Magnitude
		add("body", Vector3.new(t, t, len), CFrame.lookAt((a + b) / 2, b), color)
	end
	-- legs + feet
	for _, s in { -1, 1 } do
		add("body", Vector3.new(0.95, 2.7, 1.0), CFrame.new(P(0.65 * s, 1.35, s == 1 and 0.4 or -0.25)), SUIT)
		add("body", Vector3.new(1.0, 0.4, 1.5), CFrame.new(P(0.65 * s, 0.2, s == 1 and 0.65 or 0)), TRIM)
	end
	add("body", Vector3.new(2.2, 0.6, 1.2), CFrame.new(0, 2.85, 0), TRIM)
	add("body", Vector3.new(2.3, 2.0, 1.3), CFrame.new(0, 4.05, 0), SUIT)
	add("body", Vector3.new(2.0, 1.3, 0.3), CFrame.new(0, 4.3, 0.72), ARMOR)
	add("body", Vector3.new(0.18, 1.0, 0.06), CFrame.new(P(0.55, 4.3, 0.89)), AMBER, true)
	add("body", Vector3.new(0.18, 1.0, 0.06), CFrame.new(P(-0.55, 4.3, 0.89)), AMBER, true)
	add("body", Vector3.new(2.34, 0.25, 1.36), CFrame.new(0, 3.1, 0), TRIM)
	add("body", Vector3.new(0.9, 0.55, 1.1), CFrame.new(P(1.55, 5.0, 0)), ARMOR)
	add("body", Vector3.new(0.9, 0.55, 1.1), CFrame.new(P(-1.55, 5.0, 0)), ARMOR)
	add("body", Vector3.new(0.5, 0.3, 0.5), CFrame.new(0, 5.2, 0), TRIM)
	-- head (pivot at the neck)
	add("head", Vector3.new(1.35, 1.25, 1.3), CFrame.new(0, 0.75, 0), ARMOR)
	add("head", Vector3.new(1.05, 0.38, 0.08), CFrame.new(0, 0.8, 0.67), AMBER, true)
	add("head", Vector3.new(0.2, 0.5, 0.5), CFrame.new(0.72, 0.75, 0), TRIM)
	add("head", Vector3.new(0.2, 0.5, 0.5), CFrame.new(-0.72, 0.75, 0), TRIM)
	add("head", Vector3.new(0.08, 0.5, 0.08), CFrame.new(P(0.45, 1.65, -0.1)), TRIM)
	add("head", Vector3.new(0.2, 0.2, 0.2), CFrame.new(P(0.45, 1.95, -0.1)), AMBER, true)
	-- rifle held across the chest, pointing forward-left and slightly down
	local A, B = P(0.7, 4.5, 0.55), P(-0.5, 3.9, 3.6)
	local rf = CFrame.lookAt(A, B) * CFrame.Angles(0, math.pi, 0) -- local +Z = toward the muzzle
	local function rp(size, cf, color, neon) add("body", size, rf * cf, color, neon) end
	rp(Vector3.new(0.34, 0.5, 1.7), CFrame.new(0, 0, 0.95), Color3.fromRGB(36, 40, 52))
	rp(Vector3.new(0.3, 0.12, 1.5), CFrame.new(0, 0.31, 0.95), ARMOR)
	rp(Vector3.new(0.28, 0.55, 0.9), CFrame.new(0, -0.02, -0.4), TRIM)
	rp(Vector3.new(0.3, 0.62, 0.12), CFrame.new(0, -0.02, -0.9), ARMOR)
	rp(Vector3.new(0.3, 0.36, 1.15), CFrame.new(0, -0.02, 2.35), ARMOR)
	rp(Vector3.new(0.14, 0.14, 0.8), CFrame.new(0, 0.02, 3.3), TRIM)
	rp(Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.02, 3.75), TRIM)
	rp(Vector3.new(0.24, 0.85, 0.34), CFrame.new(0, -0.62, 1.15) * CFrame.Angles(math.rad(-10), 0, 0), TRIM)
	rp(Vector3.new(0.22, 0.55, 0.24), CFrame.new(0, -0.5, 0.35) * CFrame.Angles(math.rad(15), 0, 0), TRIM)
	rp(Vector3.new(0.3, 0.12, 0.6), CFrame.new(0, 0.43, 1.2), TRIM)
	rp(Vector3.new(0.34, 0.34, 0.36), CFrame.new(0, 0.65, 1.2), TRIM)
	rp(Vector3.new(0.2, 0.16, 0.03), CFrame.new(0, 0.66, 1.4), AMBER, true)
	rp(Vector3.new(0.38, 0.06, 1.2), CFrame.new(0, 0.08, 1.0), AMBER, true)
	local rHand, lHand = (rf * CFrame.new(0, -0.5, 0.4)).Position, (rf * CFrame.new(0, -0.25, 2.0)).Position
	local SR, SL = P(1.55, 5.0, 0), P(-1.55, 5.0, 0)
	local ER = (SR + rHand) / 2 + P(0.6, -0.5, -0.3)
	local EL = (SL + lHand) / 2 + P(-0.7, -0.6, -0.1)
	bar(SR, ER, 0.75, SUIT); bar(ER, rHand, 0.7, SUIT)
	bar(SL, EL, 0.75, SUIT); bar(EL, lHand, 0.7, SUIT)
	add("body", Vector3.new(0.6, 0.6, 0.6), CFrame.new(rHand), TRIM)
	add("body", Vector3.new(0.6, 0.6, 0.6), CFrame.new(lHand), TRIM)
	-- a little orbiting soul
	local orb = new("Part", { Anchored = true, CanCollide = false, Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, Color = C.ice, Material = Enum.Material.Neon }, model)
	local orbHalo = new("Part", { Anchored = true, CanCollide = false, Shape = Enum.PartType.Ball, Size = Vector3.one * 0.95, Color = C.blue, Material = Enum.Material.Neon, Transparency = 0.7 }, model)

	local baseYaw, curYaw, curPitch, goYaw, goPitch, nextLook = math.rad(38), 0, 0, 0, 0, 1.5
	local rng = Random.new()
	function robot.update(t, dt)
		local root = CFrame.new(0, math.sin(t * 1.7) * 0.05, 0) * CFrame.Angles(0, baseYaw + math.sin(t * 0.5) * 0.05, 0)
		if t >= nextLook then
			goYaw = math.rad(rng:NextNumber(-48, 48))
			goPitch = math.rad(rng:NextNumber(-6, 10))
			if rng:NextInteger(1, 3) == 1 then goYaw, goPitch = math.rad(-baseYaw * 57), 0 end -- sometimes looks straight at you
			nextLook = t + rng:NextNumber(2.2, 4.6)
		end
		local k = 1 - math.exp(-4 * dt)
		curYaw += (goYaw - curYaw) * k
		curPitch += (goPitch - curPitch) * k
		local headCF = root * CFrame.new(0, 5.25, 0) * CFrame.Angles(curPitch, curYaw, 0)
		for _, e in list do
			e.part.CFrame = (e.group == "head" and headCF or root) * e.rel
		end
		local op = root * CFrame.new(math.cos(t * 1.2) * 2.9, 6.8 + math.sin(t * 2.1) * 0.3, math.sin(t * 1.2) * 2.9)
		orb.CFrame, orbHalo.CFrame = op, op
	end
	function robot.recolor(c)
		for _, p in accents do p.Color = c end
	end
	robot.update(0, 0)
end

-- showcase info
local nameTag = frame(home, 28, 548, 360, 48, C.panel, 0.25)
corner(nameTag, 12)
stroke(nameTag, C.line, 1.2, 0.4)
new("ImageLabel", { BackgroundColor3 = C.panel2, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(36, 36), Image = thumb(player.UserId), ZIndex = 3 }, nameTag).ZIndex = 3
circle(nameTag:FindFirstChildOfClass("ImageLabel"))
lbl(nameTag, player.DisplayName, 18, 54, 4, 296, 22, C.text, Enum.Font.GothamBlack).ZIndex = 3
lbl(nameTag, "OPERATOR  -  BASIC ROBOT", 12, 54, 26, 296, 16, C.dim, Enum.Font.GothamMedium).ZIndex = 3
local statCards = {}
for i, name in { "WINS", "LOSSES", "WIN RATE" } do
	local f = frame(home, 28, 28 + (i - 1) * 74, 150, 62, C.panel, 0.25)
	corner(f, 12)
	stroke(f, C.line, 1.2, 0.4)
	f.ZIndex = 3
	local v = lbl(f, "0", 26, 14, 4, 130, 32, i == 1 and C.green or (i == 2 and C.red or C.ice), Enum.Font.GothamBlack)
	v.ZIndex = 3
	lbl(f, name, 12, 14, 38, 130, 16, C.dim).ZIndex = 3
	statCards[i] = v
end
local gearTag = lbl(home, "", 20, 1100, 540, 450, 28, C.text, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
gearTag.ZIndex = 3
local gearSub = lbl(home, "EQUIPPED WEAPON", 12, 1100, 520, 450, 18, C.dim, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
gearSub.ZIndex = 3
local function refreshStats()
	local w, l = player:GetAttribute("Wins") or 0, player:GetAttribute("Losses") or 0
	statCards[1].Text, statCards[2].Text = tostring(w), tostring(l)
	statCards[3].Text = (w + l > 0) and (math.floor(w / (w + l) * 100 + 0.5) .. "%") or "-"
end
for _, k in { "Wins", "Losses" } do player:GetAttributeChangedSignal(k):Connect(refreshStats) end
refreshStats()

-- ----- loadout bar -----
local bar = frame(stage, 304, 728, 1576, 132, C.panel, 0.2)
corner(bar, 16)
stroke(bar, C.line, 1.2, 0.4)
local slots = {}
local pickKind, pickIdx = nil, nil

local function slotItemId(kind, idx)
	if kind == "move" then return loadout.Move end
	if kind == "weapon" then return loadout.Weapon end
	if kind == "gadget" then return loadout.Gadgets[idx] end
	return loadout.Reserve[idx]
end

-- an item tile (colored square, glyph, optional name)
local function itemTile(parent, item, w, h, glyphSize, nameSize)
	local t = new("Frame", { Size = UDim2.fromOffset(w, h), BorderSizePixel = 0 }, parent)
	corner(t, 12)
	grad(t, item.color:Lerp(BLACK, 0.3), item.color:Lerp(BLACK, 0.72), 90)
	stroke(t, item.color, 1.5, 0.4)
	new("TextLabel", { BackgroundTransparency = 1, Text = item.glyph, TextSize = glyphSize, Font = Enum.Font.GothamBlack, TextColor3 = item.color:Lerp(WHITE, 0.5),
		Position = UDim2.fromOffset(0, nameSize and h * 0.12 or 0), Size = UDim2.new(1, 0, nameSize and 0.55 or 1, 0) }, t)
	if nameSize then
		new("TextLabel", { BackgroundTransparency = 1, Text = item.name, TextSize = nameSize, Font = Enum.Font.GothamBold, TextColor3 = C.text,
			Position = UDim2.new(0, 2, 1, -nameSize - 8), Size = UDim2.new(1, -4, 0, nameSize + 4), TextTruncate = Enum.TextTruncate.AtEnd }, t)
	end
	return t
end

local function drawSlot(s)
	local old = s.frame:FindFirstChild("Content")
	if old then old:Destroy() end
	local box = new("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, s.frame)
	local item = Catalog.ById[slotItemId(s.kind, s.idx)]
	if item then
		itemTile(box, item, 92, 92, 26, 11)
	else
		new("TextLabel", { BackgroundTransparency = 1, Text = "+", TextSize = 34, Font = Enum.Font.GothamBold, TextColor3 = C.dim, Size = UDim2.new(1, 0, 0.7, 0) }, box)
		new("TextLabel", { BackgroundTransparency = 1, Text = "EMPTY", TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.dim, Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 16) }, box)
	end
	local selected = (view == "pick" and pickKind == s.kind and pickIdx == s.idx)
	s.stroke.Color = selected and C.green or C.line
	s.stroke.Thickness = selected and 3 or 1.5
end

local function refreshLoadoutBar()
	for _, s in slots do drawSlot(s) end
	local w = Catalog.ById[loadout.Weapon]
	if w then
		gearTag.Text = w.name
		robot.recolor(w.color)
	end
end

local function makeSlot(kind, idx, x)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel2, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, 30), Size = UDim2.fromOffset(92, 92) }, bar)
	corner(f, 12)
	local st = stroke(f, C.line, 1.5, 0)
	pop(f, 1.06)
	local s = { kind = kind, idx = idx, frame = f, stroke = st }
	table.insert(slots, s)
	return s
end
local function groupLabel(text, x, w) lbl(bar, text, 12, x, 8, w, 18, C.dim, Enum.Font.GothamBlack) end

groupLabel("MOVEMENT", 28, 120)
local slotMove = makeSlot("move", 1, 28)
groupLabel("WEAPON", 200, 120)
local slotWeapon = makeSlot("weapon", 1, 200)
groupLabel("GADGETS", 372, 200)
for i = 1, 3 do makeSlot("gadget", i, 372 + (i - 1) * 102) end
frame(bar, 718, 24, 2, 92, C.line, 0.2)
groupLabel("RESERVE", 768, 200)
for i = 1, 3 do makeSlot("reserve", i, 768 + (i - 1) * 102) end
lbl(bar, "Click a slot to change it", 14, 1180, 8, 370, 18, C.dim, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
lbl(bar, "Reserve swaps in while you are dead", 14, 1180, 28, 370, 18, C.dim, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)

-- ----- views -----
local setView -- forward

local function backButton(parent, x, y)
	local b = btn(parent, "< BACK", x, y, 120, 44, C.panel2, 16, C.text)
	stroke(b, C.line, 1.5)
	b.MouseButton1Click:Connect(function() setView("home") end)
	return b
end

-- ----- pick view -----
local pick = views.pick
frame(pick, 0, 0, 1576, 616, C.panel2, 0.3)
backButton(pick, 24, 20)
local pickTitle = lbl(pick, "", 28, 168, 14, 900, 36, C.text, Enum.Font.GothamBlack)
local pickSub = lbl(pick, "Click an item to equip it", 15, 170, 48, 900, 20, C.dim, Enum.Font.GothamMedium)
local pickScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 84), Size = UDim2.fromOffset(1528, 512), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, pick)
new("UIGridLayout", { CellSize = UDim2.fromOffset(176, 190), CellPadding = UDim2.fromOffset(14, 14) }, pickScroll)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 12) }, pickScroll)

local PICK_TITLES = { move = "MOVEMENT ABILITY", weapon = "WEAPON", gadget = "GADGET", reserve = "RESERVE" }
local function itemsFor(kind)
	if kind == "move" then return Catalog.Moves end
	if kind == "weapon" then return Catalog.Weapons end
	if kind == "gadget" then return Catalog.Gadgets end
	local l = {}
	for _, i in Catalog.Weapons do table.insert(l, i) end
	for _, i in Catalog.Gadgets do table.insert(l, i) end
	return l
end

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
			for j = 1, 3 do -- already in another slot of this row: swap
				if j ~= idx and arr[j] == id then arr[j] = arr[idx] break end
			end
		end
		arr[idx] = id
	end
	pushLoadout()
end

local buildPick
function buildPick()
	for _, c in pickScroll:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local kind, idx = pickKind, pickIdx
	pickTitle.Text = PICK_TITLES[kind] .. ((kind == "gadget" or kind == "reserve") and ("   -   SLOT " .. idx) or "")
	local current = slotItemId(kind, idx)
	local function card(item, order)
		local equipped = item and item.id == current or (not item and current == "")
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = order }, pickScroll)
		corner(b, 14)
		stroke(b, equipped and C.green or C.line, equipped and 3 or 1.5, equipped and 0 or 0.2)
		pop(b, 1.04)
		if item then
			local t = itemTile(b, item, 100, 100, 36)
			t.Position = UDim2.fromOffset(38, 12)
			lbl(b, item.name, 17, 6, 120, 164, 22, C.text, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
			lbl(b, item.sub, 12, 6, 142, 164, 16, C.dim, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
		else
			lbl(b, "NONE", 20, 6, 70, 164, 28, C.dim, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
			lbl(b, "Leave this slot empty", 12, 6, 100, 164, 16, C.dim, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
		end
		if equipped then
			local tag = frame(b, 48, 164, 80, 20, C.green, 0)
			corner(tag, 10)
			lbl(tag, "EQUIPPED", 11, 0, 0, 80, 20, BLACK, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
		end
		b.MouseButton1Click:Connect(function()
			setSlot(kind, idx, item and item.id or "")
			refreshLoadoutBar()
			buildPick()
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
frame(inviteV, 0, 0, 1576, 616, C.panel2, 0.3)
local inviteTab = "lobby"
local tabLobby = btn(inviteV, "LOBBY", 24, 20, 150, 46, C.green, 17, BLACK)
local tabFriends = btn(inviteV, "FRIENDS", 186, 20, 150, 46, C.panel, 17, C.text)
local search = new("TextBox", { PlaceholderText = "Search players...", Text = "", TextSize = 18, Font = Enum.Font.GothamMedium, TextColor3 = C.text,
	PlaceholderColor3 = C.dim, BackgroundColor3 = C.panel, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(356, 20), Size = UDim2.fromOffset(620, 46), BorderSizePixel = 0 }, inviteV)
corner(search, 23)
stroke(search, C.line, 1.5)
new("UIPadding", { PaddingLeft = UDim.new(0, 20) }, search)
backButton(inviteV, 1432, 20)
local inviteHint = lbl(inviteV, "", 15, 996, 20, 420, 46, C.amber, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
inviteHint.TextWrapped = true
local inviteScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 86), Size = UDim2.fromOffset(1528, 508), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, inviteV)
new("UIListLayout", { Padding = UDim.new(0, 8) }, inviteScroll)
new("UIPadding", { PaddingRight = UDim.new(0, 10) }, inviteScroll)

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
	tabLobby.BackgroundColor3 = inviteTab == "lobby" and C.green or C.panel
	tabLobby.TextColor3 = inviteTab == "lobby" and BLACK or C.text
	tabFriends.BackgroundColor3 = inviteTab == "friends" and C.green or C.panel
	tabFriends.TextColor3 = inviteTab == "friends" and BLACK or C.text

	local list, leader = partyInfo()
	local inParty = {}
	for _, m in list do inParty[m.id] = true end
	local full = #list >= 3
	local canInvite = (leader == player.UserId) and not full
	inviteHint.Text = (leader ~= player.UserId) and "Only the party leader can invite." or (full and "Your party is full." or "")

	local entries = {}
	if inviteTab == "lobby" then
		for _, p in Players:GetPlayers() do
			if p ~= player and not inParty[p.UserId] then
				table.insert(entries, { id = p.UserId, name = p.Name, display = p.DisplayName, ok = true, note = "In this lobby" })
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
						note = inLobby and "In the lobby" or "Online - playing another game" })
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
			or (inviteTab == "lobby" and "Nobody else is in this lobby right now. Try the Friends tab or search a username.")
			or "No friends online."
		new("TextLabel", { BackgroundTransparency = 1, Text = msg, TextSize = 18, Font = Enum.Font.GothamMedium, TextColor3 = C.dim,
			Size = UDim2.new(1, 0, 0, 80), TextWrapped = true }, inviteScroll)
		return
	end
	for i, e in shown do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = i }, inviteScroll)
		corner(row, 14)
		stroke(row, C.line, 1.2, 0.4)
		local av = new("ImageLabel", { BackgroundColor3 = C.panel2, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(48, 48), Image = thumb(e.id) }, row)
		circle(av)
		lbl(row, e.display, 19, 74, 8, 600, 26, C.text, Enum.Font.GothamBlack)
		lbl(row, "@" .. e.name .. "   -   " .. e.note, 13, 74, 36, 700, 20, e.ok and C.dim or C.gray, Enum.Font.GothamMedium)
		local sent = sentAt[e.id] and os.clock() - sentAt[e.id] < 8
		local plus = btn(row, sent and "SENT" or "+", 1528 - 10 - (sent and 90 or 48) - 10, 12, sent and 90 or 48, 44, (canInvite and e.ok and not sent) and C.green or C.gray, sent and 14 or 28, BLACK)
		if sent then plus.TextColor3 = C.text end
		plus.MouseButton1Click:Connect(function()
			if not canInvite or not e.ok or sentAt[e.id] and os.clock() - sentAt[e.id] < 8 then return end
			sentAt[e.id] = os.clock()
			InviteR:FireServer(e.id)
			rebuildInvite()
			task.delay(8.1, function() if view == "invite" then rebuildInvite() end end)
		end)
	end
end
tabLobby.MouseButton1Click:Connect(function() inviteTab = "lobby" rebuildInvite() end)
tabFriends.MouseButton1Click:Connect(function() inviteTab = "friends" rebuildInvite() end)
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

-- ----- mode info view -----
local modeV = views.mode
frame(modeV, 0, 0, 1576, 616, C.panel2, 0.3)
backButton(modeV, 24, 20)
local modeArt = frame(modeV, 60, 90, 620, 440, C.panel, 0)
modeArt.ClipsDescendants = true
corner(modeArt, 20)
stroke(modeArt, C.line, 2, 0.2)
modeGraphic(modeArt)
local mTitle = lbl(modeV, "", 54, 730, 90, 800, 66, WHITE, Enum.Font.GothamBlack)
local mTag = lbl(modeV, "", 18, 734, 156, 800, 24, C.blue, Enum.Font.GothamBold)
local mDesc = lbl(modeV, "", 18, 734, 196, 780, 110, C.dim, Enum.Font.GothamMedium)
mDesc.TextWrapped, mDesc.TextYAlignment = true, Enum.TextYAlignment.Top
local mFacts = lbl(modeV, "", 17, 734, 318, 780, 130, C.text, Enum.Font.GothamMedium)
mFacts.TextWrapped, mFacts.TextYAlignment = true, Enum.TextYAlignment.Top
local mSelect = btn(modeV, "SELECT", 734, 470, 300, 64, C.green, 26, BLACK)
local mSelected = lbl(modeV, "", 16, 1050, 470, 400, 64, C.green, Enum.Font.GothamBold)
local modeShown = MODES[1]
local function openMode(m)
	modeShown = m
	mTitle.Text, mTag.Text, mDesc.Text = m.name, m.tag, m.desc
	mFacts.Text = "- " .. table.concat(m.facts, "\n- ")
	mSelect.Text = (selectedMode == m.id) and "SELECTED" or "SELECT"
	mSelected.Text = ""
	setView("mode")
end
mSelect.MouseButton1Click:Connect(function()
	selectedMode = modeShown.id
	refreshModes()
	setView("home")
end)

for i, m in MODES do
	local card = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(224, 150), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = i, ClipsDescendants = true }, modeScroll)
	corner(card, 16)
	local st = stroke(card, C.line, 1.5, 0)
	modeGraphic(card)
	local tint = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.green, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2 }, card)
	local shade = new("Frame", { Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(1, 0.4), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 3 }, card)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, shade)
	local nm = new("TextLabel", { BackgroundTransparency = 1, Text = m.name, TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, card)
	new("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.4 }, nm)
	local sub = new("TextLabel", { BackgroundTransparency = 1, Text = m.tag, TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.ice, Position = UDim2.new(0, 0, 0.5, 20), Size = UDim2.new(1, 0, 0, 16), ZIndex = 4 }, card)
	local tag = new("TextLabel", { BackgroundColor3 = C.green, Text = "SELECTED", TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = BLACK, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(78, 20), ZIndex = 5, Visible = false }, card)
	corner(tag, 10)
	pop(card, 1.03)
	card.MouseButton1Click:Connect(function() openMode(m) end)
	modeCards[m.id] = { stroke = st, tint = tint, tag = tag }
end
refreshModes()

-- view switching
function setView(name)
	view = name
	for n, f in views do f.Visible = (n == name) end
	for _, s in slots do drawSlot(s) end
	if name == "invite" then rebuildInvite() end
end

-- ================= party row =================
local partyHolder = frame(stage, 304, 874, 1000, 166, WHITE, 1)
local BOXW, BOXH, BOXGAP = 220, 166, 14

local function boxFrame(i)
	local f = frame(partyHolder, (i - 1) * (BOXW + BOXGAP), 0, BOXW, BOXH, C.panel, 0)
	corner(f, 16)
	return f
end

local function renderParty()
	for _, c in partyHolder:GetChildren() do c:Destroy() end
	local list, leader = partyInfo()
	local iLead = (leader == player.UserId)
	local others = {}
	for _, m in list do
		if m.id ~= player.UserId then table.insert(others, m) end
	end

	-- 1: invite
	do
		local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(BOXW, BOXH), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, partyHolder)
		corner(f, 16)
		stroke(f, C.green, 2, 0.35)
		pop(f, 1.03)
		local plus = new("TextLabel", { Position = UDim2.fromOffset(70, 22), Size = UDim2.fromOffset(80, 80), BackgroundColor3 = C.green, BackgroundTransparency = 0.8, Text = "+", TextSize = 56,
			Font = Enum.Font.GothamBold, TextColor3 = C.green }, f)
		circle(plus)
		stroke(plus, C.green, 2, 0.3)
		lbl(f, "INVITE", 20, 0, 114, BOXW, 26, C.text, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
		lbl(f, "friends or lobby", 12, 0, 138, BOXW, 16, C.dim, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
		f.MouseButton1Click:Connect(function() setView("invite") end)
	end

	local function memberBox(i, m, isMe)
		local f = boxFrame(i)
		stroke(f, isMe and C.blue or C.line, isMe and 2.5 or 1.5, isMe and 0.2 or 0)
		local av = new("ImageLabel", { BackgroundColor3 = C.panel2, Position = UDim2.fromOffset((BOXW - 76) / 2, 10), Size = UDim2.fromOffset(76, 76), Image = thumb(m.id) }, f)
		circle(av)
		stroke(av, m.id == leader and C.amber or C.line, 2.5, 0)
		lbl(f, isMe and player.DisplayName or m.name, 18, 6, 90, BOXW - 12, 22, C.text, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
		local role = (isMe and "YOU" or "MEMBER")
		if m.id == leader then role = isMe and "YOU  -  LEADER" or "PARTY LEADER" end
		lbl(f, role, 12, 0, 111, BOXW, 16, m.id == leader and C.amber or C.dim, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
		if iLead and not isMe then
			local kick = btn(f, "KICK", 12, 134, 94, 24, C.red, 13, WHITE)
			local prom = btn(f, "PROMOTE", 114, 134, 94, 24, C.amber, 13, BLACK)
			kick.MouseButton1Click:Connect(function() KickR:FireServer(m.id) end)
			prom.MouseButton1Click:Connect(function() PromoteR:FireServer(m.id) end)
		elseif isMe and #list > 1 then
			local lv = btn(f, "LEAVE PARTY", 12, 134, BOXW - 24, 24, C.gray, 13, WHITE)
			lv.MouseButton1Click:Connect(function() LeaveR:FireServer() end)
		end
	end
	memberBox(2, { id = player.UserId, name = player.Name }, true)
	for i = 1, 2 do
		if others[i] then
			memberBox(2 + i, others[i], false)
		else
			local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset((1 + i) * (BOXW + BOXGAP), 0), Size = UDim2.fromOffset(BOXW, BOXH),
				BackgroundColor3 = C.panel, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, partyHolder)
			corner(f, 16)
			stroke(f, C.line, 1.5, 0.4)
			local ph = new("Frame", { Position = UDim2.fromOffset((BOXW - 76) / 2, 20), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = C.panel2, BackgroundTransparency = 0.4, BorderSizePixel = 0 }, f)
			circle(ph)
			lbl(f, "EMPTY SLOT", 15, 0, 108, BOXW, 22, C.dim, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
			lbl(f, "click to invite", 12, 0, 130, BOXW, 16, C.gray, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
			f.MouseButton1Click:Connect(function() setView("invite") end)
		end
	end
	if view == "invite" then rebuildInvite() end
end

-- ================= start / queue =================
local startBtn = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(1330, 874), Size = UDim2.fromOffset(550, 166), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, stage)
corner(startBtn, 20)
local startGrad = grad(startBtn, Color3.fromRGB(86, 236, 140), C.greenDark, 90)
local startStroke = stroke(startBtn, Color3.fromRGB(170, 255, 205), 3, 0.4)
pop(startBtn, 1.025)
local startMain = new("TextLabel", { BackgroundTransparency = 1, Text = "START", TextSize = 56, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 70) }, startBtn)
new("UIStroke", { Color = dark(C.greenDark, 0.6), Thickness = 2.5, Transparency = 0.2 }, startMain)
local startSub = new("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(225, 255, 236), Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 26) }, startBtn)
TweenService:Create(startStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.9 }):Play()

local function fmtTime(s) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
local function refreshQueue()
	local q, tp = player:GetAttribute("Queued"), player:GetAttribute("Teleporting")
	local list, leader = partyInfo()
	local iLead = (leader == player.UserId)
	local mode = MODES[1]
	if tp then
		startMain.Text, startSub.Text = "JOINING MATCH...", "Hold tight"
		startGrad.Color = ColorSequence.new(C.gray, dark(C.gray, 0.4))
	elseif q then
		local qa = player:GetAttribute("QueuedAt")
		startMain.Text = "CANCEL"
		startSub.Text = "Searching for players...  " .. fmtTime(math.max(0, os.time() - (qa or os.time())))
		startGrad.Color = ColorSequence.new(Color3.fromRGB(240, 100, 100), dark(C.red, 0.35))
	elseif not iLead then
		startMain.Text, startSub.Text = "WAITING", "Only the party leader can start"
		startGrad.Color = ColorSequence.new(C.gray, dark(C.gray, 0.4))
	else
		startMain.Text = "START"
		startSub.Text = mode.name .. "   -   " .. mode.tag .. (#list > 1 and ("   -   party of " .. #list) or "")
		startGrad.Color = ColorSequence.new(Color3.fromRGB(86, 236, 140), C.greenDark)
	end
	hudStatus.Text = tp and "Joining match..." or (q and ("Searching for players...  " .. fmtTime(math.max(0, os.time() - (player:GetAttribute("QueuedAt") or os.time())))) or "")
end
startBtn.MouseButton1Click:Connect(function()
	if player:GetAttribute("Teleporting") then return end
	local _, leader = partyInfo()
	if leader ~= player.UserId and not player:GetAttribute("Queued") then say("Only the party leader can start the search.") return end
	QueueR:FireServer(not player:GetAttribute("Queued"))
end)
for _, k in { "Queued", "Teleporting", "QueuedAt" } do player:GetAttributeChangedSignal(k):Connect(refreshQueue) end
for _, k in { "PartyId", "PartyLeader", "PartyMembers" } do
	player:GetAttributeChangedSignal(k):Connect(function() renderParty() refreshQueue() end)
end
task.spawn(function()
	while true do
		task.wait(1)
		if player:GetAttribute("Queued") then refreshQueue() end
	end
end)

-- ================= open / close =================
local function openScreen()
	if screenOpen then return end
	screenOpen = true
	screen.Visible = true
	screen.BackgroundTransparency = 1
	stage.Position = UDim2.new(0.5, 0, 0.5, 36)
	TweenService:Create(screen, TweenInfo.new(0.25), { BackgroundTransparency = 0.02 }):Play()
	TweenService:Create(stage, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	setView("home")
	renderParty()
	refreshQueue()
end
local function closeScreen()
	if not screenOpen then return end
	screenOpen = false
	TweenService:Create(screen, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	task.delay(0.18, function() if not screenOpen then screen.Visible = false end end)
end
playBtn.MouseButton1Click:Connect(openScreen)
closeBtn.MouseButton1Click:Connect(closeScreen)

-- ================= animation loop (showcase + sparks) =================
local t0 = os.clock()
RunService.RenderStepped:Connect(function(dt)
	if not (screenOpen and view == "home") then return end
	dt = math.min(dt, 0.1)
	local t = os.clock() - t0
	robot.update(t, dt)
	for _, s in sparks do
		s.y -= s.v * dt
		if s.y < -30 then s.y, s.x = 640, sparkRng:NextNumber(0, 1576) end
		s.f.Position = UDim2.fromOffset(s.x + math.sin(t * 0.8 + s.ph) * 14, s.y)
	end
end)

-- ================= invite popup + notices =================
local pop_ = new("Frame", { BackgroundColor3 = C.panel2, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140), Size = UDim2.fromOffset(380, 112), ZIndex = 50, BorderSizePixel = 0 }, gui)
corner(pop_, 16)
stroke(pop_, C.green, 2, 0.2)
local popText = new("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = C.text, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(356, 44), TextWrapped = true, ZIndex = 51 }, pop_)
local yes = btn(pop_, "ACCEPT", 20, 62, 160, 38, C.green, 16, BLACK)
local no = btn(pop_, "DECLINE", 200, 62, 160, 38, C.red, 16, WHITE)
yes.ZIndex, no.ZIndex = 51, 51
local current
local function showPop(on)
	TweenService:Create(pop_, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 0, on and 20 or -140) }):Play()
end
yes.MouseButton1Click:Connect(function() if current then RespondR:FireServer(current, true) current = nil showPop(false) end end)
no.MouseButton1Click:Connect(function() if current then RespondR:FireServer(current, false) current = nil showPop(false) end end)

NoticeR.OnClientEvent:Connect(function(d)
	if type(d) ~= "table" then return end
	if d.kind == "msg" then
		if screenOpen then say(tostring(d.text)) else hudStatus.Text = tostring(d.text) task.delay(4, refreshQueue) end
	elseif d.kind == "invite" then
		current = d.id
		popText.Text = tostring(d.fromName) .. " invited you to a party"
		showPop(true)
		task.delay(30, function() if current == d.id then current = nil showPop(false) end end)
	end
end)

-- ================= start-up =================
player:GetAttributeChangedSignal("LoadoutJson"):Connect(function()
	if readLoadout() then refreshLoadoutBar() end
end)
refreshLoadoutBar()
renderParty()
refreshQueue()
