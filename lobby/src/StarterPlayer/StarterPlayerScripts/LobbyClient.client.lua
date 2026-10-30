-- LobbyClient v4 "POP" (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only.
-- v4 look: fun + flowy instead of the stiff ARC-style panels. Rounded everything, chunky Fredoka type, warm plum background with
-- drifting shapes, springy (Back easing) hovers and slide-ins, a glowing podium stage, a floating loadout dock, a vertical squad list.
-- Brand stays red / black / white, with sunny yellow as the friendly second color. Layout (1920x1080 canvas, scaled to the screen):
--   * home HUD: BREAKLINE logo (bobbing, exploding slash), souls pill top right, PLAY pill + round "+" (opens invite) bottom right
--   * PLAY screen: top = logo + sliding nav pill (PLAY / LOADOUT / SKINS) + souls + back; left column = gamemode card, squad list
--     (leader always on top), stats card; middle = the stage (you in the center on a glowing podium, party at your sides, names above);
--     below = loadout dock (slots show real gun pictures) + big START pill + round invite "+"
--   * SKINS tab on the right edge (TAB key): 3 skins, the equipped one is what you wear in the lobby, on the stage and in the match
-- Same game logic / remotes as v3. Needs in ReplicatedStorage: LobbyCatalog, Skins, GunModels (copy of Breakline's), LobbyRemotes (PartyService).
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
	ink = rgb(22, 16, 34),         -- deepest background
	panel = rgb(40, 31, 62),       -- cards
	panel2 = rgb(58, 46, 88),      -- raised / hover
	edge = rgb(96, 78, 136),       -- soft borders
	cream = rgb(255, 244, 226),
	text = rgb(255, 250, 243),
	dim = rgb(184, 172, 208),
	dark = rgb(34, 22, 44),        -- text on bright buttons
	red = rgb(255, 70, 78),
	redDark = rgb(196, 38, 56),
	yellow = rgb(255, 206, 64),
	yellowDark = rgb(240, 160, 30),
	soul = rgb(130, 228, 255),
	ok = rgb(110, 226, 150),
	pink = rgb(255, 120, 178),
}
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local FONTS = {
	H = Font.fromEnum(Enum.Font.FredokaOne), HM = Font.fromEnum(Enum.Font.FredokaOne), HL = Font.fromEnum(Enum.Font.FredokaOne),
	B = Font.fromEnum(Enum.Font.GothamMedium), BM = Font.fromEnum(Enum.Font.GothamMedium), BB = Font.fromEnum(Enum.Font.GothamBold),
	M = Font.fromEnum(Enum.Font.GothamBold), MB = Font.fromEnum(Enum.Font.GothamBold),
}

local SPRING = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SOFT = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = (r and r <= 1 and UDim.new(r, 0)) or UDim.new(0, r or 16) }, o) end
local function stroke(o, color, thick, transp)
	return new("UIStroke", { Color = color, Thickness = thick or 2, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function gradient(o, c0, c1, rot)
	return new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 90 }, o)
end
local function frame(parent, x, y, w, h, color, transp, r)
	local f = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.panel, BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
	if r then corner(f, r) end
	return f
end
local function lbl(parent, text, size, x, y, w, h, color, font, align)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = FONTS[font or "BM"],
		TextColor3 = color or C.text, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		TextXAlignment = align or Enum.TextXAlignment.Left, TextWrapped = false }, parent)
end
local function hoverColor(b, normal, hover)
	b.MouseEnter:Connect(function() TweenService:Create(b, QUICK, { BackgroundColor3 = hover }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, QUICK, { BackgroundColor3 = normal }):Play() end)
end
-- springy hover: grows a little and tilts, squishes on press. Adds one UIScale to the button.
local function pop(b, grow, tilt)
	grow = grow or 1.06
	local sc = new("UIScale", { Scale = 1 }, b)
	local base = b.Rotation
	b.MouseEnter:Connect(function()
		TweenService:Create(sc, SPRING, { Scale = grow }):Play()
		if tilt then TweenService:Create(b, SPRING, { Rotation = base + tilt }):Play() end
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(sc, SOFT, { Scale = 1 }):Play()
		if tilt then TweenService:Create(b, SOFT, { Rotation = base }):Play() end
	end)
	b.MouseButton1Down:Connect(function() TweenService:Create(sc, QUICK, { Scale = grow * 0.93 }):Play() end)
	b.MouseButton1Up:Connect(function() TweenService:Create(sc, SPRING, { Scale = grow }):Play() end)
	return sc
end
-- rounded pill button (yellow = primary, red = danger, purple = secondary)
local function btn(parent, text, x, y, w, h, kind, size)
	local primary, danger = kind == "primary", kind == "danger"
	local bg = primary and C.yellow or (danger and C.redDark or C.panel2)
	local b = new("TextButton", { Text = text, TextSize = size or 16, FontFace = FONTS.H, TextColor3 = primary and C.dark or C.text,
		BackgroundColor3 = bg, AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	corner(b, 0.5)
	if not primary then stroke(b, danger and C.red or C.edge, 2, 0.2) end
	hoverColor(b, bg, primary and C.cream or (danger and C.red or rgb(76, 62, 112)))
	pop(b, 1.05)
	return b
end
-- keyboard cap ("TAB", "ESC") + label
local function keyHint(parent, key, text, x, y)
	local k = frame(parent, x, y, math.max(34, #key * 11 + 18), 26, C.cream, 0, 8)
	lbl(k, key, 13, 0, 0, k.Size.X.Offset, 26, C.dark, "MB", Enum.TextXAlignment.Center)
	return lbl(parent, text, 15, x + k.Size.X.Offset + 8, y, 200, 26, C.text, "HM")
end
-- small rounded title tag with a colored dot
local function header(parent, text, x, y, w, color)
	local hs = frame(parent, x, y, w, 32, C.panel, 0.1, 16)
	stroke(hs, C.edge, 1.5, 0.3)
	frame(hs, 12, 10, 12, 12, color or C.yellow, 0, 6)
	lbl(hs, text, 16, 32, 0, w - 40, 32, C.text, "H")
	return hs
end
local function thumb(id) return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(id) end
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return out
end

-- ================= logo: BREAK [exploding red slash] LINE =================
local function makeLogo(parent, x, y, scale)
	local s = scale or 1
	local holder = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(420 * s, 92 * s), BackgroundTransparency = 1, Rotation = -3 }, parent)
	local function word(text, px, align)
		local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = 76 * s, FontFace = FONTS.H, TextColor3 = WHITE,
			Position = UDim2.fromOffset(px, 0), Size = UDim2.fromOffset(190 * s, 92 * s), TextXAlignment = align, ZIndex = 3 }, holder)
		new("UIStroke", { Color = C.dark, Thickness = 4.5 * s, Transparency = 0, LineJoinMode = Enum.LineJoinMode.Round }, l)
		return l
	end
	word("BREAK", 0, Enum.TextXAlignment.Right)
	word("LINE", 230 * s, Enum.TextXAlignment.Left)
	local cx, cy = 210 * s, 46 * s
	local function blade(w, h, color, z)
		local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(w, h),
			Rotation = 22, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z }, holder)
		corner(b, 0.5)
		return b
	end
	blade(17 * s, 98 * s, C.dark, 2)
	blade(11 * s, 92 * s, C.red, 4)
	local core = blade(4 * s, 72 * s, WHITE, 5)
	local ends = {}
	local rad = math.rad(22)
	for _, sign in { -1, 1 } do
		table.insert(ends, Vector2.new(cx + math.sin(rad) * 45 * s * sign, cy - math.cos(rad) * 45 * s * sign))
	end
	local shards, rng = {}, Random.new(4)
	for i = 1, 22 do
		local e = ends[(i % 2) + 1]
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 6,
			BackgroundColor3 = (i % 3 == 0) and WHITE or ((i % 3 == 1) and C.red or C.yellow) }, holder)
		corner(f, 0.5)
		table.insert(shards, { f = f, e = e, out = (e.Y < cy) and -1 or 1, t = rng:NextNumber(0, 1), spd = rng:NextNumber(0.9, 1.6),
			ang = rng:NextNumber(-80, 80), len = rng:NextNumber(10, 26) * s })
	end
	local flashes = {}
	for _, e in ends do
		local fl = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(e.X, e.Y), Size = UDim2.fromOffset(16 * s, 16 * s),
			Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 6 }, holder)
		corner(fl, 0.3)
		table.insert(flashes, fl)
	end
	local function step(t, dt)
		holder.Rotation = -3 + math.sin(t * 1.3) * 1.4 -- the whole logo sways
		for _, sh in shards do
			sh.t += dt * sh.spd
			if sh.t > 1 then sh.t -= 1; sh.ang = rng:NextNumber(-80, 80); sh.len = rng:NextNumber(10, 26) * s end
			local a = math.rad(sh.ang + (sh.out < 0 and 0 or 180) + 22)
			local d = sh.t * 36 * s
			local dir = Vector2.new(math.sin(a), -math.cos(a))
			local p = sh.e + dir * d
			sh.f.Position = UDim2.fromOffset(p.X, p.Y)
			sh.f.Rotation = sh.ang + 22
			sh.f.Size = UDim2.fromOffset(math.max(2, 4 * s * (1 - sh.t)), sh.len * (1 - sh.t * 0.6))
			sh.f.BackgroundTransparency = sh.t ^ 1.5
		end
		for i, fl in flashes do
			local k = 0.5 + 0.5 * math.sin(t * 9 + i * 2)
			fl.Size = UDim2.fromOffset((10 + 11 * k) * s, (10 + 11 * k) * s)
			fl.BackgroundTransparency = 0.15 + 0.5 * (1 - k)
		end
		core.BackgroundTransparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(t * 14))
	end
	return holder, step
end

-- ================= soul icon: glowing blue drop with a sparkle =================
local function soulIcon(parent, x, y, size)
	local h = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.soul, BackgroundTransparency = 0.78, BorderSizePixel = 0 }, h)
	corner(glow, 0.5)
	local core = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = C.soul, BorderSizePixel = 0 }, h)
	corner(core, 0.5)
	gradient(core, WHITE, C.soul, 90)
	local tip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(0.22, 0.3),
		BackgroundColor3 = C.soul, BorderSizePixel = 0, Rotation = 0 }, h)
	corner(tip, 0.5)
	local shine = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.4, 0.46), Size = UDim2.fromScale(0.16, 0.16),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, BorderSizePixel = 0 }, h)
	corner(shine, 0.5)
	return h, glow
end

local soulGlows = {}
local function soulsWidget(parent, x, y)
	local w = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(300, 56), BackgroundColor3 = C.ink, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, parent)
	corner(w, 0.5)
	stroke(w, C.edge, 2, 0.15)
	local _, glow = soulIcon(w, 8, 6, 44)
	table.insert(soulGlows, glow)
	local n = lbl(w, "0", 30, 62, 0, 150, 56, C.text, "H")
	local sub = lbl(w, "SOULS", 12, 62, 36, 220, 16, C.dim, "M")
	n.Size = UDim2.fromOffset(220, 36)
	local function upd()
		n.Text = commas(player:GetAttribute("Souls") or 0)
		sub.Text = ("SOULS   %dW / %dL"):format(player:GetAttribute("Wins") or 0, player:GetAttribute("Losses") or 0)
	end
	for _, k in { "Souls", "Wins", "Losses" } do player:GetAttributeChangedSignal(k):Connect(upd) end
	upd()
	return w
end

-- ================= gun pictures (real GunModels in a ViewportFrame, side view) =================
local function gunPicture(parent, weaponId, accent)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(170, 160, 170),
		LightColor = rgb(255, 246, 232), LightDirection = Vector3.new(-0.5, -1, -0.3) }, parent)
	if not GunModels then return vp end
	local ok, desc = pcall(GunModels.Describe, weaponId, "Iron")
	if not ok or not desc then return vp end
	local model = new("Model", {}, vp)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in desc.Parts do
		if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
			local p = new("Part", { Anchored = true, Size = d.Size, CFrame = d.CF, Color = (d.Glow and accent) or d.Color,
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

local function itemPicture(parent, item, glyphSize)
	if item.kind == "weapon" and GunModels then
		gunPicture(parent, item.id, C.red)
		return
	end
	local t = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = item.color:Lerp(C.ink, 0.65), BorderSizePixel = 0 }, parent)
	corner(t, 0.28)
	stroke(t, item.color, 2, 0.2)
	new("TextLabel", { BackgroundTransparency = 1, Text = item.glyph, TextSize = glyphSize, FontFace = FONTS.H,
		TextColor3 = item.color:Lerp(WHITE, 0.3), Size = UDim2.fromScale(1, 1) }, t)
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

local logoSteps = {}
local openScreen

-- ---------- the big play pill (home PLAY + START) ----------
-- returns holder-less button b, main label, sub label, paint(c1, c2, textColor), bob(t)
local function playBlock(parent, x, y, w, h)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	corner(b, 0.3)
	local grad = gradient(b, C.red, C.redDark, 90)
	local rim = stroke(b, WHITE, 3, 0.55)
	-- glossy highlight on the top half
	local gloss = frame(b, 14, 8, w - 28, h * 0.32, WHITE, 0.82, h * 0.16)
	gradient(gloss, WHITE, WHITE, 90).Transparency = NumberSequence.new(0.2, 1)
	local main = lbl(b, "PLAY", math.floor(h * 0.46), 30, math.floor(h * 0.1), w - 120, math.floor(h * 0.5), WHITE, "H")
	local sub = lbl(b, "BREAKLINE  //  3V3", 15, 32, math.floor(h * 0.64), w - 120, 22, WHITE, "M")
	sub.TextTransparency = 0.15
	local arrowBox = frame(b, w - 30 - h * 0.46, h * 0.27, h * 0.46, h * 0.46, WHITE, 0.15, 1)
	corner(arrowBox, 0.5)
	local arrow = lbl(arrowBox, ">", math.floor(h * 0.3), 0, -2, h * 0.46, h * 0.46, C.redDark, "H", Enum.TextXAlignment.Center)
	local sc = pop(b, 1.04, nil)
	b.MouseEnter:Connect(function() TweenService:Create(arrow, SPRING, { Position = UDim2.fromOffset(4, -2) }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(arrow, SOFT, { Position = UDim2.fromOffset(0, -2) }):Play() end)
	local baseY = y
	local function paint(c1, c2, textColor)
		grad.Color = ColorSequence.new(c1, c2)
		main.TextColor3, sub.TextColor3 = textColor, textColor
		arrow.TextColor3 = c2
	end
	local function bob(t)
		b.Position = UDim2.fromOffset(x, baseY + math.sin(t * 2.2) * 4)
	end
	return b, main, sub, paint, bob
end
local function plusCircle(parent, x, y, d)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BackgroundTransparency = 0.05, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(d, d) }, parent)
	corner(b, 0.5)
	local st = stroke(b, C.yellow, 3, 0)
	local bar1 = frame(b, (d - 24) / 2, (d - 5) / 2, 24, 5, C.yellow, 0, 3)
	local bar2 = frame(b, (d - 5) / 2, (d - 24) / 2, 5, 24, C.yellow, 0, 3)
	pop(b, 1.12, 0)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, QUICK, { BackgroundColor3 = C.yellow }):Play()
		bar1.BackgroundColor3, bar2.BackgroundColor3 = C.dark, C.dark
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, QUICK, { BackgroundColor3 = C.panel }):Play()
		bar1.BackgroundColor3, bar2.BackgroundColor3 = C.yellow, C.yellow
	end)
	local spin = 0
	b.MouseEnter:Connect(function() spin += 90 TweenService:Create(b, SPRING, { Rotation = spin }):Play() end)
	return b
end

-- ---------- home HUD ----------
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, gui)
local hudC = canvas(hud, 1)
local topShade = frame(hudC, 0, 0, 1920, 150, C.ink, 0.3)
gradient(topShade, C.ink, C.ink, 90).Transparency = NumberSequence.new(0, 1)
local botShade = frame(hudC, 0, 840, 1920, 240, C.ink, 0.25)
gradient(botShade, C.ink, C.ink, 90).Transparency = NumberSequence.new(1, 0)
do
	local _, step = makeLogo(hudC, 40, 22, 0.78)
	table.insert(logoSteps, step)
end
soulsWidget(hudC, 1580, 30)
keyHint(hudC, "TAB", "SKINS", 44, 1020)

local homePlay, _, _, homePaint, homeBob = playBlock(hudC, 1420, 900, 372, 120)
homePaint(C.red, C.redDark, WHITE)
local homePlus = plusCircle(hudC, 1810, 928, 66)
local hudStatus = lbl(hudC, "", 18, 1100, 862, 780, 26, C.text, "H", Enum.TextXAlignment.Right)

-- ---------- play screen ----------
local screen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
	ClipsDescendants = true, ZIndex = 10, Active = true }, gui)
gradient(screen, rgb(54, 32, 86), rgb(20, 13, 32), 70)

-- drifting background shapes (scale positions, so they fill any screen)
local bgLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, screen)
local bgShapes = {}
do
	local rng = Random.new(11)
	local cols = { C.red, C.yellow, C.pink, C.soul, WHITE }
	for i = 1, 22 do
		local kind = i % 3
		local size = rng:NextInteger(26, 96)
		local col = cols[(i % #cols) + 1]
		local o
		if kind == 0 then -- ring
			o = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 1 }, bgLayer)
			corner(o, 0.5)
			stroke(o, col, 4, 0.82)
		elseif kind == 1 then -- soft blob
			o = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = col, BackgroundTransparency = 0.9, ZIndex = 1 }, bgLayer)
			corner(o, rng:NextNumber(0.25, 0.5))
		else -- plus
			o = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size * 0.7, size * 0.7), BackgroundTransparency = 1, ZIndex = 1 }, bgLayer)
			local a = frame(o, 0, 0, 0, 0, col, 0.84, 4)
			a.AnchorPoint, a.Position, a.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(1, 0, 0.26, 0)
			local b = frame(o, 0, 0, 0, 0, col, 0.84, 4)
			b.AnchorPoint, b.Position, b.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(0.26, 0, 1, 0)
		end
		table.insert(bgShapes, { o = o, x = rng:NextNumber(0, 1), y = rng:NextNumber(0, 1.2), spd = rng:NextNumber(0.006, 0.02), sway = rng:NextNumber(0.01, 0.035),
			ph = rng:NextNumber(0, 6), spin = rng:NextNumber(-25, 25) })
	end
end

local stage = canvas(screen, 2)

-- top: logo, sliding nav pill, souls, back
do
	local _, step = makeLogo(stage, 22, 6, 0.62)
	table.insert(logoSteps, step)
end
local navPill = frame(stage, 690, 20, 540, 58, C.ink, 0.2, 29)
stroke(navPill, C.edge, 2, 0.2)
local navHi = frame(navPill, 5, 5, 168, 48, C.yellow, 0, 24)
local navBtns = {}
for i, name in { "PLAY", "LOADOUT", "SKINS" } do
	local b = new("TextButton", { Text = name, TextSize = 20, FontFace = FONTS.H, TextColor3 = (i == 1) and C.dark or C.text, BackgroundTransparency = 1,
		AutoButtonColor = false, Position = UDim2.fromOffset(5 + (i - 1) * 176, 5), Size = UDim2.fromOffset(168, 48), ZIndex = 3 }, navPill)
	navBtns[name] = { b = b, x = 5 + (i - 1) * 176 }
end
local function setNav(name)
	for n, d in navBtns do
		d.b.TextColor3 = (n == name) and C.dark or C.text
		if n == name then TweenService:Create(navHi, SPRING, { Position = UDim2.fromOffset(d.x, 5) }):Play() end
	end
end
soulsWidget(stage, 1280, 18)
local closeBtn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, Position = UDim2.fromOffset(1740, 22), Size = UDim2.fromOffset(140, 54) }, stage)
corner(closeBtn, 0.5)
stroke(closeBtn, C.edge, 2, 0.2)
pop(closeBtn, 1.06, 2)
keyHint(closeBtn, "ESC", "BACK", 14, 14)

-- toast (top center, yellow pill)
local toast = frame(stage, 660, 92, 600, 42, C.yellow, 0, 21)
local toastText = lbl(toast, "", 17, 20, 0, 560, 42, C.dark, "H", Enum.TextXAlignment.Center)
toast.Visible, toast.ZIndex = false, 20
toastText.ZIndex = 21
local toastToken = 0
local function say(text)
	toastToken += 1
	local my = toastToken
	toastText.Text = text
	toast.Position = UDim2.fromOffset(660, 70)
	toast.Visible = true
	TweenService:Create(toast, SPRING, { Position = UDim2.fromOffset(660, 92) }):Play()
	task.delay(4, function() if my == toastToken then toast.Visible = false end end)
end

-- left column title
local pageTitle = lbl(stage, "LET'S GO!", 46, 44, 84, 300, 54, C.text, "H")
lbl(stage, "Squad up, set your loadout, deploy.", 14, 46, 128, 280, 18, C.dim, "B")

-- ---------- gamemode card (left) ----------
local function modeGraphic(parent)
	local g = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(70, 40, 110), BorderSizePixel = 0 }, parent)
	corner(g, 20)
	gradient(g, rgb(96, 58, 150), rgb(44, 26, 74), 60)
	-- two team zones, the wall, a few crates: all kept inside the rounded corners
	local red = frame(g, 0, 0, 0, 0, C.red, 0.15, 12)
	red.Position, red.Size = UDim2.fromScale(0.06, 0.2), UDim2.fromScale(0.2, 0.6)
	local blue = frame(g, 0, 0, 0, 0, rgb(70, 130, 255), 0.15, 12)
	blue.Position, blue.Size = UDim2.fromScale(0.74, 0.2), UDim2.fromScale(0.2, 0.6)
	local wall = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.56, 0.5), Size = UDim2.new(0, 8, 0.78, 0),
		BackgroundColor3 = C.cream, BorderSizePixel = 0 }, g)
	corner(wall, 0.5)
	for _, cr in { { 0.36, 0.34 }, { 0.4, 0.66 }, { 0.68, 0.4 }, { 0.8, 0.68 } } do
		local s = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cr[1], cr[2]), Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = C.yellow, BorderSizePixel = 0, Rotation = (cr[1] * 100) % 20 - 10 }, g)
		corner(s, 5)
		frame(s, 4, 6, 3, 3, C.dark, 0, 2)
		frame(s, 11, 6, 3, 3, C.dark, 0, 2)
	end
	return g, wall
end

local modeHolder = new("Frame", { Position = UDim2.fromOffset(40, 156), Size = UDim2.fromOffset(270, 170), BackgroundTransparency = 1 }, stage)
local modeCards = {}
local function refreshModes()
	for id, c in modeCards do
		local on = (id == selectedMode)
		c.stroke.Color = on and C.yellow or C.edge
		c.stroke.Thickness = on and 4 or 2
		c.tag.Visible = on
	end
end

-- ---------- middle panel (the stage) ----------
local MIDX, MIDY, MIDW, MIDH = 340, 108, 1540, 692
local mid = frame(stage, MIDX, MIDY, MIDW, MIDH, C.panel, 0, 40)
stroke(mid, C.edge, 3, 0.1)
local views = {}
for _, name in { "home", "pick", "invite", "mode" } do
	views[name] = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = (name == "home") }, mid)
end
local view = "home"
local screenOpen = false

-- ----- home: podium stage -----
local home = views.home
-- gradient sky behind the (transparent) 3D view
local sky = frame(home, 0, 0, MIDW, MIDH, WHITE, 0, 40)
gradient(sky, rgb(104, 58, 150), rgb(26, 16, 44), 90)
do -- big soft sun + rings behind the squad (flat 2D, cheap)
	local sun = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(620, 620),
		BackgroundColor3 = C.red, BackgroundTransparency = 0.72, BorderSizePixel = 0 }, sky)
	corner(sun, 0.5)
	gradient(sun, C.yellow, C.red, 90)
	local sun2 = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(860, 860),
		BackgroundTransparency = 1 }, sky)
	corner(sun2, 0.5)
	stroke(sun2, C.pink, 3, 0.8)
end
local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2,
	Ambient = rgb(150, 132, 160), LightColor = rgb(255, 232, 206), LightDirection = Vector3.new(-0.35, -1, -0.55) }, home)
corner(vp, 40)
local CAM_POS, CAM_LOOK, CAM_FOV = Vector3.new(0, 5.0, 25), Vector3.new(0, 3.7, 0), 34
local stageCam = new("Camera", { FieldOfView = CAM_FOV, CFrame = CFrame.lookAt(CAM_POS, CAM_LOOK) }, vp)
vp.CurrentCamera = stageCam

-- 3D scene: dark floor, glowing podium discs, floating cubes
local floaters = {}
do
	local env = new("Model", { Name = "Bay" }, vp)
	local function P(size, cf, color, mat, shape)
		local p = new("Part", { Anchored = true, Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.SmoothPlastic,
			TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth, CastShadow = false }, env)
		if shape then p.Shape = shape end
		return p
	end
	local NEON = Enum.Material.Neon
	local flat = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis = X, so this lays a disc flat
	-- floor (big dark disc) + concentric neon rings
	P(Vector3.new(0.4, 90, 90), CFrame.new(0, -0.2, -4) * flat, rgb(34, 22, 52), nil, Enum.PartType.Cylinder)
	for i, r in { 20, 30, 40 } do
		P(Vector3.new(0.05, r * 2, r * 2), CFrame.new(0, 0.02 + i * 0.001, -4) * flat, (i == 2) and rgb(255, 120, 178) or rgb(70, 50, 110), NEON, Enum.PartType.Cylinder).Transparency = 0.65
	end
	-- podium for each slot: dark disc, bright rim, glowing top ring
	local podCols = { C.yellow, C.red, C.soul }
	local podPos = { Vector3.new(0, 0, 1.2), Vector3.new(-7.2, 0, -0.4), Vector3.new(7.2, 0, -0.4) }
	for i, pos in podPos do
		P(Vector3.new(0.5, 6.6, 6.6), CFrame.new(pos + Vector3.new(0, 0.25, 0)) * flat, rgb(30, 20, 46), nil, Enum.PartType.Cylinder)
		P(Vector3.new(0.12, 6.9, 6.9), CFrame.new(pos + Vector3.new(0, 0.05, 0)) * flat, podCols[i], NEON, Enum.PartType.Cylinder)
		P(Vector3.new(0.06, 5.2, 5.2), CFrame.new(pos + Vector3.new(0, 0.53, 0)) * flat, podCols[i], NEON, Enum.PartType.Cylinder).Transparency = 0.55
	end
	-- floating cubes (animated in the render loop)
	local cubeCols = { C.red, C.yellow, WHITE, C.pink, C.soul, C.yellow, C.red }
	local rng = Random.new(21)
	for i = 1, 9 do
		local s = rng:NextNumber(0.7, 1.7)
		local p = P(Vector3.new(s, s, s), CFrame.new(), cubeCols[(i % #cubeCols) + 1], (i % 2 == 0) and NEON or nil)
		p.Transparency = (i % 2 == 0) and 0.2 or 0
		table.insert(floaters, { p = p, x = rng:NextNumber(-17, 17), y = rng:NextNumber(5, 12), z = rng:NextNumber(-12, -3), ph = rng:NextNumber(0, 6),
			rot = Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8)) })
	end
end

-- soft vignette on top of the 3D view
do
	local bottom = frame(home, 0, MIDH - 150, MIDW, 150, C.ink, 0.2, 40)
	bottom.ZIndex = 3
	gradient(bottom, C.ink, C.ink, 90).Transparency = NumberSequence.new(1, 0.1)
end

local squad = {}   -- { fig, root, tag, top }
local squadKey = ""
local nameLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, home)

local function project(world)
	local p = stageCam.CFrame:PointToObjectSpace(world)
	if p.Z >= 0 then return nil end
	local t = math.tan(math.rad(CAM_FOV / 2))
	local aspect = MIDW / MIDH
	local x = p.X / (-p.Z * t * aspect)
	local y = p.Y / (-p.Z * t)
	return Vector2.new((x + 1) / 2 * MIDW, (1 - y) / 2 * MIDH)
end

-- slot positions on the stage. Slot 1 = you (always the middle). Screen-left = -X.
local SLOTS = {
	{ pos = Vector3.new(0, 0.6, 1.2), yaw = 32 },
	{ pos = Vector3.new(-7.2, 0.6, -0.4), yaw = 20 },
	{ pos = Vector3.new(7.2, 0.6, -0.4), yaw = 46 },
}

-- name bubble with a little tail pointing down at the head
local function nameTag(text, isLeader, isMe)
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(260, 56), BackgroundTransparency = 1, ZIndex = 4 }, nameLayer)
	local w = math.clamp(#text * 12 + 40, 110, 260)
	local plate = frame(holder, (260 - w) / 2, 0, w, 36, isMe and C.yellow or C.ink, isMe and 0 or 0.1, 18)
	plate.ZIndex = 4
	if not isMe then stroke(plate, C.edge, 2, 0.1) end
	local tail = frame(holder, 130 - 7, 28, 14, 14, isMe and C.yellow or C.ink, isMe and 0 or 0.1, 3)
	tail.Rotation, tail.ZIndex = 45, 3
	local l = lbl(plate, text, 19, 0, 0, w, 36, isMe and C.dark or C.text, "H", Enum.TextXAlignment.Center)
	l.ZIndex = 5
	if isLeader then
		local crown = frame(holder, 130 - 34, -14, 68, 20, C.red, 0, 10)
		crown.ZIndex = 6
		lbl(crown, "LEADER", 11, 0, 0, 68, 20, WHITE, "MB", Enum.TextXAlignment.Center).ZIndex = 7
	end
	return holder
end

local function rebuildSquad()
	local list, leader = partyInfo()
	local members = { { id = player.UserId, name = player.Name, me = true } }
	for _, m in list do
		if m.id ~= player.UserId then table.insert(members, m) end
	end
	local key = {}
	local looks = {}
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
		local tag = nameTag(look.me and (look.name .. "  (YOU)") or look.name, look.leader, look.me)
		table.insert(squad, { fig = fig, root = root, tag = tag, top = fig.HeadTop })
	end
end

-- stage info: equipped gun + skin, bottom right of the stage
local gearName = lbl(home, "", 34, MIDW - 560, MIDH - 86, 520, 40, C.text, "H", Enum.TextXAlignment.Right)
gearName.ZIndex = 5
local gearSub = lbl(home, "", 14, MIDW - 560, MIDH - 44, 520, 20, C.dim, "M", Enum.TextXAlignment.Right)
gearSub.ZIndex = 5

-- ----- stats card (bottom left) -----
local statCard = frame(stage, 40, 822, 270, 168, C.panel, 0.05, 28)
stroke(statCard, C.edge, 2, 0.2)
local statTitle = lbl(statCard, "YOUR RECORD", 14, 20, 14, 230, 20, C.dim, "M")
local statBig = lbl(statCard, "--", 52, 20, 36, 230, 60, C.yellow, "H")
local statSub = lbl(statCard, "WIN RATE", 13, 22, 94, 230, 18, C.dim, "M")
local statLine = lbl(statCard, "", 17, 20, 122, 240, 28, C.text, "H")
local function refreshStats()
	local w, l = player:GetAttribute("Wins") or 0, player:GetAttribute("Losses") or 0
	statBig.Text = (w + l > 0) and (math.floor(w / (w + l) * 100 + 0.5) .. "%") or "--"
	statLine.Text = ("%d WINS   %d LOSSES"):format(w, l)
end
for _, k in { "Wins", "Losses" } do player:GetAttributeChangedSignal(k):Connect(refreshStats) end
refreshStats()

-- ----- loadout dock (floating pill under the stage) -----
local DOCKX, DOCKY, DOCKW, DOCKH = 340, 822, 1110, 168
local bar = frame(stage, DOCKX, DOCKY, DOCKW, DOCKH, C.panel, 0.05, 40)
stroke(bar, C.edge, 2, 0.2)
local slots = {}
local pickKind, pickIdx = nil, nil

local function slotItemId(kind, idx)
	if kind == "move" then return loadout.Move end
	if kind == "weapon" then return loadout.Weapon end
	if kind == "gadget" then return loadout.Gadgets[idx] end
	return loadout.Reserve[idx]
end

local function drawSlot(s)
	local old = s.frame:FindFirstChild("Content")
	if old then old:Destroy() end
	local sw, sh = s.frame.Size.X.Offset, s.frame.Size.Y.Offset
	local box = new("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, s.frame)
	local item = Catalog.ById[slotItemId(s.kind, s.idx)]
	if item then
		local pic = new("Frame", { Size = UDim2.new(1, 0, 1, -24), BackgroundTransparency = 1 }, box)
		itemPicture(pic, item, 22)
		local nm = lbl(box, string.upper(item.name), 12, 6, sh - 24, sw - 12, 20, C.text, "H", Enum.TextXAlignment.Center)
		nm.TextTruncate = Enum.TextTruncate.AtEnd
	else
		frame(box, (sw - 22) / 2, 24, 22, 4, C.dim, 0.2, 2)
		frame(box, (sw - 4) / 2, 15, 4, 22, C.dim, 0.2, 2)
		lbl(box, "EMPTY", 12, 0, sh - 24, sw, 20, C.dim, "H", Enum.TextXAlignment.Center)
	end
	local selected = (view == "pick" and pickKind == s.kind and pickIdx == s.idx)
	s.stroke.Color = selected and C.yellow or C.edge
	s.stroke.Thickness = selected and 4 or 2
end

local function refreshLoadoutBar()
	for _, s in slots do drawSlot(s) end
	local w = Catalog.ById[loadout.Weapon]
	gearName.Text = w and string.upper(w.name) or ""
	gearSub.Text = (w and string.upper(w.sub) or "") .. "   //   SKIN: " .. Skins.Get(mySkin).name
end

local function makeSlot(kind, idx, x, w)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel2, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, 46), Size = UDim2.fromOffset(w or 92, 104) }, bar)
	corner(f, 22)
	local st = stroke(f, C.edge, 2, 0)
	hoverColor(f, C.panel2, rgb(78, 62, 116))
	pop(f, 1.07, (idx and idx % 2 == 0) and 1.5 or -1.5)
	local s = { kind = kind, idx = idx, frame = f, stroke = st }
	table.insert(slots, s)
	return s
end
local function groupLabel(text, x, w, color)
	local p = frame(bar, x, 12, w, 24, color or C.ink, 0.1, 12)
	lbl(p, text, 12, 0, 0, w, 24, C.text, "H", Enum.TextXAlignment.Center)
end

groupLabel("MOVE", 24, 92)
makeSlot("move", 1, 24)
groupLabel("WEAPON", 132, 216, C.red)
makeSlot("weapon", 1, 132, 216)
groupLabel("GADGETS", 364, 296)
for i = 1, 3 do makeSlot("gadget", i, 364 + (i - 1) * 102) end
frame(bar, 684, 28, 4, 120, C.edge, 0.4, 2)
groupLabel("RESERVE", 706, 296)
for i = 1, 3 do makeSlot("reserve", i, 706 + (i - 1) * 102) end
lbl(bar, "tap a slot to change it", 12, 1012 - 4, 14, 94, 40, C.dim, "B", Enum.TextXAlignment.Right).TextWrapped = true

-- ----- views -----
local setView -- forward
local function backButton(parent, x, y)
	local b = btn(parent, "<  BACK", x, y, 120, 38, nil, 16)
	b.MouseButton1Click:Connect(function() setView("home") end)
	return b
end
local function viewBg(v)
	local f = frame(v, 0, 0, MIDW, MIDH, WHITE, 0, 40)
	gradient(f, rgb(54, 42, 82), rgb(36, 28, 58), 90)
	-- a few soft dots instead of a rigid grid
	for i = 1, 14 do
		local d = frame(f, (i * 131) % (MIDW - 60) + 20, (i * 89) % (MIDH - 60) + 20, 10 + (i % 3) * 8, 10 + (i % 3) * 8, WHITE, 0.94, 99)
		d.ZIndex = 1
	end
	return f
end

-- ----- pick view (gun pictures) -----
local pick = views.pick
viewBg(pick)
backButton(pick, 28, 22)
local pickTitle = lbl(pick, "", 38, 176, 16, 900, 48, C.text, "H")
lbl(pick, "Click an item to equip it.", 14, 178, 62, 900, 18, C.dim, "B")
local pickScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 98), Size = UDim2.fromOffset(MIDW - 48, MIDH - 118), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, ScrollBarImageColor3 = C.edge, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, pick)
local pickGrid = new("UIGridLayout", { CellSize = UDim2.fromOffset(282, 206), CellPadding = UDim2.fromOffset(16, 16), SortOrder = Enum.SortOrder.LayoutOrder }, pickScroll)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingBottom = UDim.new(0, 16) }, pickScroll)

local PICK_TITLES = { move = "MOVEMENT", weapon = "WEAPONS", gadget = "GADGET", reserve = "RESERVE" }
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

local buildPick
function buildPick()
	for _, c in pickScroll:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local kind, idx = pickKind, pickIdx
	pickTitle.Text = PICK_TITLES[kind] .. ((kind == "gadget" or kind == "reserve") and ("  -  SLOT " .. idx) or "")
	local current = slotItemId(kind, idx)
	pickGrid.CellSize = (kind == "weapon" or kind == "reserve") and UDim2.fromOffset(282, 206) or UDim2.fromOffset(200, 206)
	local n = 0
	local function card(item, order)
		local equipped = item and item.id == current or (not item and current == "")
		local cw = pickGrid.CellSize.X.Offset
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = order,
			Rotation = ((order % 3) - 1) * 0.8 }, pickScroll)
		corner(b, 26)
		stroke(b, equipped and C.yellow or C.edge, equipped and 4 or 2, 0)
		hoverColor(b, C.panel, C.panel2)
		pop(b, 1.05, 0)
		if item then
			local pic = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(cw - 20, 132), BackgroundColor3 = rgb(30, 22, 48), BorderSizePixel = 0 }, b)
			corner(pic, 18)
			itemPicture(pic, item, 34)
			local strip = frame(b, 10, 148, cw - 20, 48, equipped and C.yellow or rgb(70, 56, 104), 0, 18)
			lbl(strip, string.upper(item.name), 20, 14, 2, cw - 44, 26, equipped and C.dark or C.text, "H")
			lbl(strip, string.upper(item.sub), 11, 14, 28, cw - 44, 16, equipped and C.dark or C.dim, "M")
			if equipped then
				local tag = frame(b, cw - 96, 14, 82, 22, C.dark, 0, 11)
				lbl(tag, "EQUIPPED", 11, 0, 0, 82, 22, C.yellow, "MB", Enum.TextXAlignment.Center)
			end
		else
			lbl(b, "NONE", 26, 0, 66, cw, 32, C.dim, "H", Enum.TextXAlignment.Center)
			lbl(b, "leave this slot empty", 12, 0, 104, cw, 16, C.dim, "B", Enum.TextXAlignment.Center)
		end
		b.MouseButton1Click:Connect(function()
			setSlot(kind, idx, item and item.id or "")
			refreshLoadoutBar()
			buildPick()
			if kind == "weapon" then rebuildSquadSoon() end
		end)
		n += 1
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
viewBg(inviteV)
backButton(inviteV, 28, 22)
lbl(inviteV, "INVITE", 38, 176, 16, 400, 48, C.text, "H")
local inviteTab = "lobby"
local tabLobby = btn(inviteV, "LOBBY", 28, 76, 130, 40, "primary", 17)
local tabFriends = btn(inviteV, "FRIENDS", 168, 76, 130, 40, nil, 17)
local search = new("TextBox", { PlaceholderText = "Search players...", Text = "", TextSize = 17, FontFace = FONTS.BM, TextColor3 = C.text,
	PlaceholderColor3 = C.dim, BackgroundColor3 = C.ink, BackgroundTransparency = 0.2, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(320, 76), Size = UDim2.fromOffset(560, 40), BorderSizePixel = 0 }, inviteV)
corner(search, 0.5)
stroke(search, C.edge, 2, 0.2)
new("UIPadding", { PaddingLeft = UDim.new(0, 20) }, search)
local inviteHint = lbl(inviteV, "", 15, 900, 76, 620, 40, C.pink, "H")
local inviteScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 134), Size = UDim2.fromOffset(MIDW - 48, MIDH - 154), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, ScrollBarImageColor3 = C.edge, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, inviteV)
new("UIListLayout", { Padding = UDim.new(0, 10) }, inviteScroll)
new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4) }, inviteScroll)

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

local function styleTab(b, on)
	b.BackgroundColor3 = on and C.yellow or C.panel2
	b.TextColor3 = on and C.dark or C.text
end

function rebuildInvite()
	for _, c in inviteScroll:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	styleTab(tabLobby, inviteTab == "lobby")
	styleTab(tabFriends, inviteTab == "friends")

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
				table.insert(entries, { id = p.UserId, name = p.Name, display = p.DisplayName, ok = true, note = "in this lobby" })
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
						note = inLobby and "in the lobby" or "online - another game" })
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
		new("TextLabel", { BackgroundTransparency = 1, Text = msg, TextSize = 19, FontFace = FONTS.H, TextColor3 = C.dim,
			Size = UDim2.new(1, 0, 0, 90), TextWrapped = true }, inviteScroll)
		return
	end
	for i, e in shown do
		local row = new("Frame", { Size = UDim2.new(1, -8, 0, 68), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = i }, inviteScroll)
		corner(row, 34)
		stroke(row, C.edge, 2, 0.2)
		local av = new("ImageLabel", { BackgroundColor3 = C.panel2, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(52, 52), Image = thumb(e.id) }, row)
		corner(av, 0.5)
		lbl(row, string.upper(e.display), 22, 76, 8, 600, 28, C.text, "H")
		lbl(row, "@" .. e.name .. "   -   " .. e.note, 13, 76, 38, 700, 18, e.ok and C.dim or C.edge, "M")
		local sent = sentAt[e.id] and os.clock() - sentAt[e.id] < 8
		local usable = canInvite and e.ok and not sent
		local plus = btn(row, sent and "SENT" or "INVITE", 0, 14, 120, 40, usable and "primary" or nil, 16)
		plus.Position = UDim2.new(1, -140, 0, 14)
		if not usable then plus.TextColor3 = C.dim end
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
viewBg(modeV)
backButton(modeV, 28, 22)
local modeArt = frame(modeV, 40, 80, 600, 470, C.panel, 0, 32)
stroke(modeArt, C.edge, 3, 0.1)
modeGraphic(modeArt)
local mTitle = lbl(modeV, "", 72, 690, 70, 800, 84, C.text, "H")
local mTag = lbl(modeV, "", 17, 696, 150, 800, 22, C.yellow, "H")
local mDesc = lbl(modeV, "", 18, 696, 186, 780, 110, C.dim, "B")
mDesc.TextWrapped, mDesc.TextYAlignment = true, Enum.TextYAlignment.Top
local mFacts = lbl(modeV, "", 18, 696, 306, 780, 150, C.text, "BM")
mFacts.TextWrapped, mFacts.TextYAlignment = true, Enum.TextYAlignment.Top
local mSelect = btn(modeV, "SELECT", 696, 484, 280, 62, "primary", 26)
local modeShown = MODES[1]
local function openMode(m)
	modeShown = m
	mTitle.Text, mTag.Text, mDesc.Text = m.name, m.tag, m.desc
	mFacts.Text = "*  " .. table.concat(m.facts, "\n*  ")
	mSelect.Text = (selectedMode == m.id) and "SELECTED" or "SELECT"
	setView("mode")
end
mSelect.MouseButton1Click:Connect(function()
	selectedMode = modeShown.id
	refreshModes()
	setView("home")
end)

for i, m in MODES do
	local card = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(270, 170), BackgroundColor3 = C.panel, BorderSizePixel = 0,
		LayoutOrder = i, Rotation = -2 }, modeHolder)
	corner(card, 28)
	local st = stroke(card, C.edge, 2, 0)
	local g = modeGraphic(card)
	g.Position, g.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -72)
	local strip = frame(card, 8, 108, 254, 54, rgb(70, 56, 104), 0, 20)
	lbl(strip, m.name, 24, 14, 2, 230, 28, C.text, "H")
	lbl(strip, m.tag, 11, 14, 30, 230, 16, C.dim, "M")
	local tag = frame(card, 18, 18, 84, 22, C.yellow, 0, 11)
	lbl(tag, "SELECTED", 11, 0, 0, 84, 22, C.dark, "MB", Enum.TextXAlignment.Center)
	tag.Visible = false
	pop(card, 1.05, 2)
	card.MouseButton1Click:Connect(function() openMode(m) end)
	modeCards[m.id] = { stroke = st, tag = tag }
end
refreshModes()

function setView(name)
	view = name
	for n, f in views do f.Visible = (n == name) end
	for _, s in slots do drawSlot(s) end
	if name == "invite" then rebuildInvite() end
	setNav((name == "pick") and "LOADOUT" or "PLAY")
	-- a little bounce so view changes feel alive
	local v = views[name]
	if v and name ~= "home" then
		v.Position = UDim2.fromOffset(0, 26)
		TweenService:Create(v, SPRING, { Position = UDim2.fromOffset(0, 0) }):Play()
	end
end

-- ================= squad list (left column): leader always on top =================
local partyHolder = frame(stage, 40, 380, 270, 420, WHITE, 1)
local squadCount = lbl(stage, "", 13, 190, 342, 120, 18, C.dim, "M", Enum.TextXAlignment.Right)
header(stage, "SQUAD", 40, 336, 140, C.red)
keyHint(stage, "TAB", "SKINS", 44, 1030)
local BOXW, BOXH, BOXGAP = 270, 128, 12

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
		local y = (i - 1) * (BOXH + BOXGAP)
		if m then
			local isMe = m.id == player.UserId
			local isLeader = m.id == leader
			local f = frame(partyHolder, 0, y, BOXW, BOXH, C.panel, 0, 26)
			stroke(f, isLeader and C.yellow or (isMe and C.cream or C.edge), isLeader and 3 or 2, isMe and 0 or 0.1)
			local av = new("ImageLabel", { BackgroundColor3 = C.panel2, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(62, 62), Image = thumb(m.id) }, f)
			corner(av, 0.5)
			stroke(av, isLeader and C.yellow or C.edge, 3, 0)
			local nm = lbl(f, string.upper(isMe and player.DisplayName or m.name), 21, 88, 14, BOXW - 100, 26, C.text, "H")
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			lbl(f, "@" .. m.name, 12, 88, 40, BOXW - 100, 16, C.dim, "M").TextTruncate = Enum.TextTruncate.AtEnd
			local skin = isMe and mySkin or memberLook(m)
			lbl(f, Skins.Get(skin).name, 12, 88, 58, BOXW - 100, 16, C.dim, "M")
			if isLeader then
				local t = frame(f, BOXW - 86, -10, 74, 22, C.yellow, 0, 11)
				lbl(t, "LEADER", 12, 0, 0, 74, 22, C.dark, "H", Enum.TextXAlignment.Center)
			elseif isMe then
				local t = frame(f, BOXW - 56, -10, 44, 22, C.cream, 0, 11)
				lbl(t, "YOU", 12, 0, 0, 44, 22, C.dark, "H", Enum.TextXAlignment.Center)
			end
			if iLead and not isMe then
				local kick = btn(f, "KICK", 14, 90, 100, 28, "danger", 14)
				local prom = btn(f, "PROMOTE", 122, 90, 134, 28, nil, 14)
				kick.MouseButton1Click:Connect(function() KickR:FireServer(m.id) end)
				prom.MouseButton1Click:Connect(function() PromoteR:FireServer(m.id) end)
			elseif isMe and #list > 1 then
				local lv = btn(f, "LEAVE PARTY", 14, 90, BOXW - 28, 28, nil, 14)
				lv.MouseButton1Click:Connect(function() LeaveR:FireServer() end)
			end
		else
			local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(BOXW, BOXH),
				BackgroundColor3 = C.ink, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, partyHolder)
			corner(f, 26)
			stroke(f, C.edge, 2, 0.3)
			hoverColor(f, C.ink, C.panel)
			pop(f, 1.04, 0)
			local pc = frame(f, 18, (BOXH - 54) / 2, 54, 54, C.panel2, 0, 27)
			frame(pc, 15, 25, 24, 4, C.yellow, 0, 2)
			frame(pc, 25, 15, 4, 24, C.yellow, 0, 2)
			lbl(f, "OPEN SLOT", 20, 88, 36, 170, 26, C.dim, "H")
			lbl(f, "click to invite", 13, 88, 64, 170, 18, C.edge, "B")
			f.MouseButton1Click:Connect(function() setView("invite") end)
		end
	end
	if view == "invite" then rebuildInvite() end
end

-- ================= start / queue =================
local startBtn, startMain, startSub, startPaint, startBob = playBlock(stage, 1476, 822, 330, 168)
startMain.Text = "START"
local startPlus = plusCircle(stage, 1816, 874, 64)

local function fmtTime(s) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
local STATE_COLORS = {
	go = { C.red, C.redDark, WHITE },
	cancel = { C.yellow, C.yellowDark, C.dark },
	wait = { rgb(120, 104, 156), rgb(84, 70, 118), WHITE },
}
local function setBlock(main, sub, state)
	startMain.Text, startSub.Text = main, sub
	local c = STATE_COLORS[state]
	startPaint(c[1], c[2], c[3])
end
local function refreshQueue()
	local q, tp = player:GetAttribute("Queued"), player:GetAttribute("Teleporting")
	local list, leader = partyInfo()
	local iLead = (leader == player.UserId)
	local mode = MODES[1]
	if tp then
		setBlock("DEPLOYING", "joining match...", "wait")
	elseif q then
		local qa = player:GetAttribute("QueuedAt")
		setBlock("CANCEL", "searching  " .. fmtTime(math.max(0, os.time() - (qa or os.time()))), "cancel")
	elseif not iLead then
		setBlock("WAITING", "only the leader can start", "wait")
	else
		setBlock("START", mode.name .. (#list > 1 and ("  //  party of " .. #list) or "  //  3v3"), "go")
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

-- ================= SKINS tab (right edge of the screen) =================
local skinLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 30 }, gui)
local skinC = canvas(skinLayer, 30)
local PANELW = 960
local skinsOpen = false
local skinPanel = frame(skinC, 1920, 20, PANELW, 1040, rgb(30, 20, 46), 0.02, 44)
skinPanel.ZIndex = 30
stroke(skinPanel, C.edge, 3, 0.1)
gradient(skinPanel, rgb(56, 36, 88), rgb(28, 18, 44), 90)
-- the handle: a rounded tab stuck to the panel's left edge
local handle = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.yellow, BorderSizePixel = 0,
	Position = UDim2.fromOffset(-52, 400), Size = UDim2.fromOffset(56, 210), ZIndex = 31 }, skinPanel)
corner(handle, 24)
local handleText = new("TextLabel", { BackgroundTransparency = 1, Text = "SKINS", TextSize = 24, FontFace = FONTS.H, TextColor3 = C.dark,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.5), Size = UDim2.fromOffset(180, 34), Rotation = -90, ZIndex = 32 }, handle)
hoverColor(handle, C.yellow, C.cream)
pop(handle, 1.05, 0)

local sTitle = lbl(skinPanel, "SKINS", 56, 52, 30, 500, 64, C.text, "H")
sTitle.ZIndex = 31
local sSub = lbl(skinPanel, "What you wear in the lobby, on the stage and in the match.", 15, 56, 96, 800, 20, C.dim, "B")
sSub.ZIndex = 31
local sClose = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(PANELW - 160, 44), Size = UDim2.fromOffset(130, 34), ZIndex = 31 }, skinPanel)
keyHint(sClose, "TAB", "CLOSE", 0, 4)
for _, d in sClose:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 32 end end

local skinCards = {}
local CARDW, CARDH = 280, 700
local function drawSkinCards()
	for _, c in skinCards do
		local on = c.id == mySkin
		c.strip.BackgroundColor3 = on and C.yellow or rgb(70, 56, 104)
		c.name.TextColor3 = on and C.dark or C.text
		c.sub.TextColor3 = on and C.dark or C.dim
		c.desc.TextColor3 = on and C.dark or C.dim
		c.tag.Visible = on
		c.stroke.Color = on and C.yellow or C.edge
		c.stroke.Thickness = on and 5 or 2
		c.equip.Text = on and "EQUIPPED" or "TAP TO EQUIP"
		c.equip.TextColor3 = on and C.dark or C.text
	end
end
local equipSkin -- forward
for i, sk in Skins.List do
	local x = 52 + (i - 1) * (CARDW + 14)
	local card = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, 150), Size = UDim2.fromOffset(CARDW, CARDH), ZIndex = 31, Rotation = (i - 2) * 1.6 }, skinPanel)
	-- poster (the skin's color, a big circle behind the figure)
	local poster = frame(card, 0, 0, CARDW, CARDH - 150, sk.card, 0, 30)
	poster.ZIndex = 31
	local st = stroke(poster, C.edge, 2, 0)
	gradient(poster, sk.card:Lerp(WHITE, 0.2), sk.card:Lerp(BLACK, 0.45), 90)
	local blob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(CARDW - 50, CARDW - 50),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 31 }, poster)
	corner(blob, 0.5)
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(CARDW - 18, CARDW - 18),
		BackgroundTransparency = 1, ZIndex = 31 }, poster)
	corner(ring, 0.5)
	stroke(ring, WHITE, 3, 0.7)
	local num = lbl(poster, ("%02d"):format(i), 56, 20, 8, 120, 62, WHITE, "H")
	num.ZIndex, num.TextTransparency = 31, 0.35
	local fv = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 32, Ambient = rgb(160, 148, 150),
		LightColor = rgb(255, 240, 220), LightDirection = Vector3.new(-0.5, -0.9, -0.6) }, poster)
	local cam = new("Camera", { FieldOfView = 30 }, fv)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.4, 19), Vector3.new(0, 3.9, 0))
	fv.CurrentCamera = cam
	local strip = frame(card, 0, CARDH - 138, CARDW, 138, rgb(70, 56, 104), 0, 26)
	strip.ZIndex = 31
	local nm = lbl(strip, sk.name, 30, 18, 8, CARDW - 36, 36, C.text, "H")
	nm.ZIndex = 32
	local sb = lbl(strip, string.upper(sk.sub), 12, 18, 44, CARDW - 36, 16, C.dim, "M")
	sb.ZIndex = 32
	local ds = lbl(strip, sk.desc, 13, 18, 62, CARDW - 36, 40, C.dim, "B")
	ds.ZIndex, ds.TextWrapped, ds.TextYAlignment = 32, true, Enum.TextYAlignment.Top
	local eq = lbl(strip, "TAP TO EQUIP", 14, 18, 110, CARDW - 36, 20, C.text, "H")
	eq.ZIndex = 32
	local tag = frame(card, CARDW - 104, 12, 92, 26, C.dark, 0, 13)
	tag.ZIndex = 33
	lbl(tag, "EQUIPPED", 12, 0, 0, 92, 26, C.yellow, "MB", Enum.TextXAlignment.Center).ZIndex = 34
	pop(card, 1.04, 0)
	card.MouseButton1Click:Connect(function() equipSkin(sk.id) end)
	skinCards[i] = { id = sk.id, strip = strip, name = nm, sub = sb, desc = ds, tag = tag, stroke = st, equip = eq, vp = fv, fig = nil }
end
local skinHint = lbl(skinPanel, "More skins come with the shop.", 14, 56, 880, 800, 20, C.dim, "B")
skinHint.ZIndex = 31

local function buildSkinFigures()
	for _, c in skinCards do
		if c.fig then c.fig:Destroy() end
		c.fig = Skins.NewFigure(c.vp, c.id, { weapon = loadout.Weapon, camPos = Vector3.new(0, 4.4, 19) })
		c.fig:SetRoot(CFrame.Angles(0, math.rad(28), 0))
	end
end

function equipSkin(id)
	if not Skins.Is(id) or id == mySkin then return end
	mySkin = id
	SetSkinR:FireServer(id)
	drawSkinCards()
	refreshLoadoutBar()
	rebuildSquadSoon()
	if screenOpen then renderParty() end
end
player:GetAttributeChangedSignal("Skin"):Connect(function()
	local s = player:GetAttribute("Skin")
	if Skins.Is(s) and s ~= mySkin then
		mySkin = s
		drawSkinCards()
		refreshLoadoutBar()
		rebuildSquadSoon()
	end
end)

local function setSkins(on)
	if on == skinsOpen then return end
	skinsOpen = on
	if on then buildSkinFigures() end
	TweenService:Create(skinPanel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(on and 1920 - PANELW - 20 or 1920, 20) }):Play()
	handleText.Text = on and "CLOSE" or "SKINS"
	if screenOpen then setNav(on and "SKINS" or ((view == "pick") and "LOADOUT" or "PLAY")) end
end
handle.MouseButton1Click:Connect(function() setSkins(not skinsOpen) end)
sClose.MouseButton1Click:Connect(function() setSkins(false) end)
drawSkinCards()

-- nav buttons in the top pill
for name, d in navBtns do
	d.b.MouseButton1Click:Connect(function()
		if name == "SKINS" then setSkins(true)
		elseif name == "LOADOUT" then openPick("weapon", 1)
		else setView("home") end
	end)
end

-- ================= open / close =================
-- staggered slide-in so the screen "flows" open
local flowItems = {}
local function flow(obj, dx, dy, delay)
	table.insert(flowItems, { obj = obj, final = obj.Position, dx = dx, dy = dy, delay = delay })
end
flow(modeHolder, -60, 0, 0.02)
flow(partyHolder, -60, 0, 0.08)
flow(statCard, -60, 0, 0.14)
flow(mid, 0, 40, 0.05)
flow(bar, 0, 60, 0.12)
flow(startPlus, 60, 0, 0.24)
flow(navPill, 0, -30, 0)

function openScreen(startView)
	if not screenOpen then
		screenOpen = true
		screen.Visible = true
		screen.BackgroundTransparency = 1
		TweenService:Create(screen, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
		hud.Visible = false
		for _, f in flowItems do
			local fx, fy = f.final.X.Offset, f.final.Y.Offset
			f.obj.Position = UDim2.new(f.final.X.Scale, fx + f.dx, f.final.Y.Scale, fy + f.dy)
			task.delay(f.delay, function()
				if screenOpen then TweenService:Create(f.obj, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = f.final }):Play() end
			end)
		end
	end
	setView(startView or "home")
	renderParty()
	refreshQueue()
	rebuildSquad()
end
local function closeScreen()
	if not screenOpen then return end
	screenOpen = false
	hud.Visible = true
	TweenService:Create(screen, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	task.delay(0.18, function() if not screenOpen then screen.Visible = false end end)
end
homePlay.MouseButton1Click:Connect(function() openScreen("home") end)
homePlus.MouseButton1Click:Connect(function() openScreen("invite") end)
startPlus.MouseButton1Click:Connect(function() setView("invite") end)
closeBtn.MouseButton1Click:Connect(closeScreen)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe or UIS:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Tab then
		setSkins(not skinsOpen)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if skinsOpen then setSkins(false)
		elseif screenOpen and view ~= "home" then setView("home")
		elseif screenOpen then closeScreen() end
	end
end)

-- ================= animation loop =================
local t0 = os.clock()
RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local t = os.clock() - t0
	if hud.Visible then
		logoSteps[1](t, dt)
		homeBob(t)
	end
	if screenOpen then
		logoSteps[2](t, dt)
		startBob(t + 1)
		for _, s in bgShapes do
			local y = 1.1 - ((t * s.spd + s.y) % 1.2)
			s.o.Position = UDim2.fromScale(s.x + math.sin(t * 0.4 + s.ph) * s.sway, y)
			s.o.Rotation = (t * s.spin) % 360
		end
		for i, g in soulGlows do g.BackgroundTransparency = 0.7 + 0.12 * math.sin(t * 3 + i) end
		if view == "home" then
			for _, s in squad do
				s.fig:Update(t, dt)
				local p = project((s.root * CFrame.new(0, s.top + 0.5, 0)).Position)
				if p then s.tag.Position = UDim2.fromOffset(p.X, p.Y) end
			end
			for _, f in floaters do
				f.p.CFrame = CFrame.new(f.x, f.y + math.sin(t * 0.9 + f.ph) * 0.7, f.z) * CFrame.fromEulerAnglesYXZ(t * f.rot.X, t * f.rot.Y, t * f.rot.Z)
			end
		end
	end
	if skinsOpen then
		for _, c in skinCards do if c.fig then c.fig:Update(t, dt) end end
	end
end)

-- ================= invite popup + notices =================
local popC = canvas(gui, 50)
local pop_ = frame(popC, 740, -160, 440, 130, C.panel, 0, 32)
pop_.ZIndex = 50
stroke(pop_, C.yellow, 3, 0)
local popHead = lbl(pop_, "PARTY INVITE", 14, 24, 10, 300, 20, C.yellow, "H")
popHead.ZIndex = 51
local popText = lbl(pop_, "", 22, 24, 30, 392, 32, C.text, "H")
popText.ZIndex = 51
local yes = btn(pop_, "ACCEPT", 20, 76, 196, 40, "primary", 17)
local no = btn(pop_, "DECLINE", 224, 76, 196, 40, nil, 17)
yes.ZIndex, no.ZIndex = 51, 51
local current
local function showPop(on)
	TweenService:Create(pop_, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(740, on and 24 or -160) }):Play()
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
