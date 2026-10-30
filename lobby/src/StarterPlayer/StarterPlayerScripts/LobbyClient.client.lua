-- LobbyClient v3 (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only.
-- Look: ARC Raiders-style menus - near-black panels, cream/off-white header strips with dark text, condensed type (Oswald),
-- square corners, red as the one accent color (Breakline brand: red / black / white). No bouncy hover scaling, no glows.
--   * home HUD: BREAKLINE logo (exploding slash), souls counter top right, PLAY block + round "+" (opens the invite tab) bottom right
--   * PLAY screen: gamemodes (left), the stage (middle: you in the center, party members left/right with names above them,
--     standing in a warehouse bay), loadout bar (gun slots show a picture of the real gun model), party row (leader always in the
--     leftmost box), START block + "+" invite circle
--   * SKINS tab on the right edge of the screen (home + play screen): 3 skins, the equipped one is what you wear in the lobby,
--     on the stage and in the match
-- Needs in ReplicatedStorage: LobbyCatalog, Skins, GunModels (copy of Breakline's) and the LobbyRemotes made by PartyService.
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
local C = {
	ink = Color3.fromRGB(12, 12, 12),        -- screen background
	panel = Color3.fromRGB(22, 21, 20),      -- dark panels
	panel2 = Color3.fromRGB(33, 32, 30),     -- raised / hover
	edge = Color3.fromRGB(58, 56, 52),       -- thin borders
	cream = Color3.fromRGB(236, 232, 221),   -- header strips, primary buttons
	cream2 = Color3.fromRGB(205, 200, 188),
	text = Color3.fromRGB(240, 237, 230),
	dim = Color3.fromRGB(150, 146, 137),
	dark = Color3.fromRGB(20, 19, 18),       -- text on cream
	red = Color3.fromRGB(218, 36, 42),
	redDark = Color3.fromRGB(150, 22, 28),
	soul = Color3.fromRGB(158, 226, 255),
	ok = Color3.fromRGB(120, 200, 120),
}
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local FAM_H = Font.fromEnum(Enum.Font.Oswald).Family      -- condensed headings (ARC-like)
local FAM_B = Font.fromEnum(Enum.Font.Roboto).Family      -- body
local FAM_M = Font.fromEnum(Enum.Font.RobotoMono).Family  -- numbers, key hints
local FONTS = {
	H = Font.new(FAM_H, Enum.FontWeight.Bold), HM = Font.new(FAM_H, Enum.FontWeight.Medium), HL = Font.new(FAM_H, Enum.FontWeight.Regular),
	B = Font.new(FAM_B, Enum.FontWeight.Regular), BM = Font.new(FAM_B, Enum.FontWeight.Medium), BB = Font.new(FAM_B, Enum.FontWeight.Bold),
	M = Font.new(FAM_M, Enum.FontWeight.Medium), MB = Font.new(FAM_M, Enum.FontWeight.Bold),
}

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function stroke(o, color, thick, transp)
	return new("UIStroke", { Color = color, Thickness = thick or 1, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function frame(parent, x, y, w, h, color, transp)
	return new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.panel, BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
end
local function lbl(parent, text, size, x, y, w, h, color, font, align)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = FONTS[font or "BM"],
		TextColor3 = color or C.text, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		TextXAlignment = align or Enum.TextXAlignment.Left, TextWrapped = false }, parent)
end
local function hoverColor(b, normal, hover)
	b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.08), { BackgroundColor3 = hover }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = normal }):Play() end)
end
-- flat rectangular button (cream = primary, dark = secondary)
local function btn(parent, text, x, y, w, h, kind, size)
	local primary = kind == "primary"
	local danger = kind == "danger"
	local bg = primary and C.cream or (danger and C.redDark or C.panel2)
	local b = new("TextButton", { Text = text, TextSize = size or 16, FontFace = FONTS.H, TextColor3 = primary and C.dark or C.text,
		BackgroundColor3 = bg, AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	if not primary then stroke(b, danger and C.red or C.edge, 1, 0) end
	hoverColor(b, bg, primary and WHITE or (danger and C.red or Color3.fromRGB(48, 46, 43)))
	return b
end
-- keyboard key pill ("ESC", "TAB") + label, like ARC's bottom hints
local function keyHint(parent, key, text, x, y)
	local k = frame(parent, x, y, math.max(30, #key * 10 + 16), 24, C.cream, 0)
	lbl(k, key, 13, 0, 0, k.Size.X.Offset, 24, C.dark, "MB", Enum.TextXAlignment.Center)
	return lbl(parent, text, 15, x + k.Size.X.Offset + 8, y, 200, 24, C.text, "HM")
end
-- cream header strip with a small dark square marker, ARC panel style
local function header(parent, text, x, y, w, h)
	local hs = frame(parent, x, y, w, h or 30, C.cream, 0)
	frame(hs, 8, (hs.Size.Y.Offset - 12) / 2, 12, 12, C.dark, 0)
	lbl(hs, text, 15, 28, 0, w - 36, hs.Size.Y.Offset, C.dark, "H")
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
-- returns the holder frame and a step(t) function that animates the sparks
local function makeLogo(parent, x, y, scale)
	local s = scale or 1
	local holder = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(420 * s, 92 * s), BackgroundTransparency = 1 }, parent)
	local function word(text, px, align)
		local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = 74 * s, FontFace = FONTS.H, TextColor3 = WHITE,
			Position = UDim2.fromOffset(px, 0), Size = UDim2.fromOffset(190 * s, 92 * s), TextXAlignment = align, ZIndex = 3 }, holder)
		new("UIStroke", { Color = BLACK, Thickness = 3 * s, Transparency = 0 }, l)
		return l
	end
	word("BREAK", 0, Enum.TextXAlignment.Right)
	word("LINE", 230 * s, Enum.TextXAlignment.Left)
	-- the slash: black outline + red blade + white-hot core, leaning right
	local cx, cy = 210 * s, 46 * s
	local function blade(w, h, color, z)
		return new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(w, h),
			Rotation = 22, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z }, holder)
	end
	blade(15 * s, 96 * s, BLACK, 2)
	blade(9 * s, 90 * s, C.red, 4)
	local core = blade(3 * s, 70 * s, WHITE, 5)
	-- explosions at both ends: shards that fly out, fade and respawn
	local ends = {}
	local rad = math.rad(22)
	for _, sign in { -1, 1 } do
		table.insert(ends, Vector2.new(cx + math.sin(rad) * 45 * s * sign, cy - math.cos(rad) * 45 * s * sign))
	end
	local shards, rng = {}, Random.new(4)
	for i = 1, 22 do
		local e = ends[(i % 2) + 1]
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 6,
			BackgroundColor3 = (i % 3 == 0) and WHITE or C.red }, holder)
		table.insert(shards, { f = f, e = e, out = (e.Y < cy) and -1 or 1, t = rng:NextNumber(0, 1), spd = rng:NextNumber(0.9, 1.6),
			ang = rng:NextNumber(-80, 80), len = rng:NextNumber(10, 26) * s })
	end
	local flashes = {}
	for _, e in ends do
		local fl = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(e.X, e.Y), Size = UDim2.fromOffset(16 * s, 16 * s),
			Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 6 }, holder)
		table.insert(flashes, fl)
	end
	local function step(t, dt)
		for _, sh in shards do
			sh.t += dt * sh.spd
			if sh.t > 1 then sh.t -= 1; sh.ang = rng:NextNumber(-80, 80); sh.len = rng:NextNumber(10, 26) * s end
			local a = math.rad(sh.ang + (sh.out < 0 and 0 or 180) + 22)
			local d = sh.t * 34 * s
			local dir = Vector2.new(math.sin(a), -math.cos(a))
			local p = sh.e + dir * d
			sh.f.Position = UDim2.fromOffset(p.X, p.Y)
			sh.f.Rotation = sh.ang + 22
			sh.f.Size = UDim2.fromOffset(math.max(1, 3 * s * (1 - sh.t)), sh.len * (1 - sh.t * 0.6))
			sh.f.BackgroundTransparency = sh.t ^ 1.5
		end
		for i, fl in flashes do
			local k = 0.5 + 0.5 * math.sin(t * 9 + i * 2)
			fl.Size = UDim2.fromOffset((10 + 10 * k) * s, (10 + 10 * k) * s)
			fl.BackgroundTransparency = 0.15 + 0.5 * (1 - k)
		end
		core.BackgroundTransparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(t * 14))
	end
	return holder, step
end

-- ================= soul icon (new): white diamond outline, pale-blue core, small flame tip =================
local function soulIcon(parent, x, y, size)
	local h = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	local outer = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.62, 0.62),
		Rotation = 45, BackgroundTransparency = 1, BorderSizePixel = 0 }, h)
	stroke(outer, C.text, math.max(1.5, size / 14), 0)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = C.soul, BorderSizePixel = 0 }, outer)
	-- flame tip above the diamond
	new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(0.08, 0.2),
		BackgroundColor3 = C.soul, BorderSizePixel = 0 }, h)
	return h
end

-- souls counter, ARC style: icon + number, label underneath, no pill
local function soulsWidget(parent, x, y)
	local w = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(250, 46), BackgroundTransparency = 1 }, parent)
	soulIcon(w, 0, 4, 34)
	local n = lbl(w, "0", 28, 44, -2, 200, 34, C.text, "H")
	local sub = lbl(w, "SOULS", 12, 45, 30, 200, 14, C.dim, "M")
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
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 150, 150),
		LightColor = Color3.fromRGB(255, 246, 232), LightDirection = Vector3.new(-0.5, -1, -0.3) }, parent)
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

-- an item picture tile: real gun for weapons, flat glyph tile for placeholders (gadgets / movement)
local function itemPicture(parent, item, glyphSize)
	if item.kind == "weapon" and GunModels then
		gunPicture(parent, item.id, C.red)
		return
	end
	local t = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = C.panel2, BorderSizePixel = 0 }, parent)
	stroke(t, item.color, 1, 0.3)
	new("TextLabel", { BackgroundTransparency = 1, Text = item.glyph, TextSize = glyphSize, FontFace = FONTS.H,
		TextColor3 = item.color:Lerp(WHITE, 0.35), Size = UDim2.fromScale(1, 1) }, t)
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

-- skin + weapon of another party member (same server: read their attributes; other server: the party record, else defaults)
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

-- every layer is a 1920x1080 canvas scaled to the screen
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
local openScreen -- forward (opens the play screen; optional view name)

-- ---------- home HUD ----------
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, gui)
local hudC = canvas(hud, 1)
-- top + bottom shade so text reads over the 3D lobby
local topShade = frame(hudC, 0, 0, 1920, 130, BLACK, 0.35)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }, topShade)
local botShade = frame(hudC, 0, 860, 1920, 220, BLACK, 0.3)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, botShade)
do
	local _, step = makeLogo(hudC, 36, 18, 0.72)
	table.insert(logoSteps, step)
end
soulsWidget(hudC, 1640, 30)
keyHint(hudC, "TAB", "SKINS", 40, 1020)

-- PLAY block (bottom right) + round invite "+"
local function playBlock(parent, x, y, w, h)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.cream, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ClipsDescendants = true }, parent)
	-- red notch on the left edge + diagonal hazard cut on the right
	local notch = frame(b, 0, 0, 10, h, C.red, 0)
	local cut = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(14, h * 1.6),
		Rotation = 18, BackgroundColor3 = C.dark, BackgroundTransparency = 0.88, BorderSizePixel = 0 }, b)
	local main = lbl(b, "PLAY", math.floor(h * 0.5), 34, math.floor(h * 0.08), w - 60, math.floor(h * 0.6), C.dark, "H")
	local sub = lbl(b, "BREAKLINE  //  3V3", 14, 36, math.floor(h * 0.66), w - 60, 20, C.dark, "M")
	sub.TextTransparency = 0.25
	local arrow = lbl(b, ">", math.floor(h * 0.42), w - 74, 0, 40, h, C.dark, "H", Enum.TextXAlignment.Center)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.08), { BackgroundColor3 = WHITE }):Play()
		TweenService:Create(notch, TweenInfo.new(0.12), { Size = UDim2.fromOffset(18, h) }):Play()
		TweenService:Create(arrow, TweenInfo.new(0.12), { Position = UDim2.fromOffset(w - 66, 0) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = C.cream }):Play()
		TweenService:Create(notch, TweenInfo.new(0.12), { Size = UDim2.fromOffset(10, h) }):Play()
		TweenService:Create(arrow, TweenInfo.new(0.12), { Position = UDim2.fromOffset(w - 74, 0) }):Play()
	end)
	return b, main, sub, notch, cut
end
local function plusCircle(parent, x, y, d)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BackgroundTransparency = 0.05, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(d, d) }, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
	local st = stroke(b, C.cream, 2, 0)
	-- a drawn plus (two bars), not a text "+"
	frame(b, (d - 22) / 2, (d - 3) / 2, 22, 3, C.cream, 0)
	frame(b, (d - 3) / 2, (d - 22) / 2, 3, 22, C.cream, 0)
	b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.08), { BackgroundColor3 = C.panel2 }):Play() st.Color = WHITE end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = C.panel }):Play() st.Color = C.cream end)
	return b
end

local homePlay = playBlock(hudC, 1440, 924, 340, 104)
local homePlus = plusCircle(hudC, 1796, 944, 64)
local hudStatus = lbl(hudC, "", 16, 1100, 890, 680, 24, C.text, "HM", Enum.TextXAlignment.Right)

-- ---------- play screen ----------
local screen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
	ClipsDescendants = true, ZIndex = 10, Active = true }, gui)
local stage = canvas(screen, 2)

-- top bar
local topBar = frame(stage, 0, 0, 1920, 76, Color3.fromRGB(8, 8, 8), 0)
frame(topBar, 0, 75, 1920, 1, C.edge, 0)
do
	local _, step = makeLogo(topBar, 18, 6, 0.6)
	table.insert(logoSteps, step)
end
-- nav (ARC style: plain labels, the active one boxed)
local navX = 330
for i, name in { "PLAY", "LOADOUT", "SKINS" } do
	local active = i == 1
	local w = #name * 12 + 34
	local b = new("TextButton", { Text = name, TextSize = 18, FontFace = FONTS.H, TextColor3 = active and C.text or C.dim, BackgroundTransparency = 1,
		AutoButtonColor = false, Position = UDim2.fromOffset(navX, 20), Size = UDim2.fromOffset(w, 36) }, topBar)
	if active then stroke(b, C.text, 1.5, 0) end
	b:SetAttribute("Nav", name)
	navX += w + 14
end
soulsWidget(topBar, 1500, 16)
local closeBtn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(1790, 20), Size = UDim2.fromOffset(110, 36) }, topBar)
keyHint(closeBtn, "ESC", "BACK", 0, 6)

-- toast (top center, cream strip)
local toast = frame(stage, 660, 88, 600, 38, C.cream, 0)
frame(toast, 0, 0, 6, 38, C.red, 0)
local toastText = lbl(toast, "", 16, 18, 0, 576, 38, C.dark, "HM", Enum.TextXAlignment.Left)
toast.Visible, toast.ZIndex = false, 20
local toastToken = 0
local function say(text)
	toastToken += 1
	local my = toastToken
	toastText.Text = text
	toast.Visible = true
	task.delay(4, function() if my == toastToken then toast.Visible = false end end)
end

-- page title
lbl(stage, "PLAY //", 40, 40, 92, 400, 48, C.text, "H")
lbl(stage, "SQUAD UP, SET YOUR LOADOUT, DEPLOY.", 14, 42, 138, 600, 18, C.dim, "M")

-- ---------- gamemode list (left) ----------
header(stage, "GAMEMODES", 40, 172, 250, 30)
local modeScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(40, 210), Size = UDim2.fromOffset(250, 640), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = C.edge, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, stage)
new("UIListLayout", { Padding = UDim.new(0, 8) }, modeScroll)

-- small flat illustration of a mode (red end, blue end, wall line, crates)
local function modeGraphic(parent)
	local g = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 29, 27), BorderSizePixel = 0, ClipsDescendants = true }, parent)
	frame(g, 0, 0, 0, 0, C.red, 0).Size = UDim2.fromScale(0.08, 1)
	local blue = frame(g, 0, 0, 0, 0, Color3.fromRGB(60, 110, 200), 0)
	blue.Position, blue.Size = UDim2.fromScale(0.92, 0), UDim2.fromScale(0.08, 1)
	for i = 1, 10 do
		local l = frame(g, 0, 0, 0, 0, C.edge, 0.4)
		l.Position, l.Size = UDim2.fromScale(i / 11, 0), UDim2.new(0, 1, 1, 0)
	end
	local wall = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.56, 0.5), Size = UDim2.new(0, 4, 1.4, 0),
		Rotation = 0, BackgroundColor3 = C.cream, BorderSizePixel = 0 }, g)
	for _, cr in { { 0.22, 0.3 }, { 0.3, 0.68 }, { 0.75, 0.42 }, { 0.82, 0.74 } } do
		local s = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cr[1], cr[2]), Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Color3.fromRGB(214, 150, 50), BorderSizePixel = 0 }, g)
		stroke(s, C.dark, 1, 0)
	end
	return g, wall
end

local modeCards = {}
local function refreshModes()
	for id, c in modeCards do
		local on = (id == selectedMode)
		c.stroke.Color = on and C.cream or C.edge
		c.stroke.Thickness = on and 2 or 1
		c.tag.Visible = on
	end
end

-- ---------- middle panel ----------
local MIDW, MIDH = 1560, 576
local mid = frame(stage, 320, 172, MIDW, MIDH, Color3.fromRGB(18, 17, 16), 0)
mid.ClipsDescendants = true
stroke(mid, C.edge, 1, 0)
local views = {}
for _, name in { "home", "pick", "invite", "mode" } do
	views[name] = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = (name == "home") }, mid)
end
local view = "home"
local screenOpen = false

-- ----- home: the stage (warehouse bay, you in the middle, party at your sides) -----
local home = views.home
local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 14, 12), BackgroundTransparency = 0, ZIndex = 1,
	Ambient = Color3.fromRGB(128, 112, 96), LightColor = Color3.fromRGB(255, 222, 186), LightDirection = Vector3.new(-0.35, -1, -0.55) }, home)
local CAM_POS, CAM_LOOK, CAM_FOV = Vector3.new(0, 5.2, 30), Vector3.new(0, 3.6, 0), 30
local stageCam = new("Camera", { FieldOfView = CAM_FOV, CFrame = CFrame.lookAt(CAM_POS, CAM_LOOK) }, vp)
vp.CurrentCamera = stageCam

-- static scene, built once
do
	local env = new("Model", { Name = "Bay" }, vp)
	local function P(size, cf, color, mat, shape)
		local p = new("Part", { Anchored = true, Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.SmoothPlastic,
			TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, env)
		if shape then p.Shape = shape end
		return p
	end
	local NEON = Enum.Material.Neon
	local rgb = Color3.fromRGB
	-- far back darkness + floor
	P(Vector3.new(160, 80, 1), CFrame.new(0, 20, -40), rgb(14, 13, 12))
	P(Vector3.new(120, 1, 90), CFrame.new(0, -0.5, -10), rgb(58, 55, 51))
	-- floor seams (concrete slabs)
	for i = -6, 6 do P(Vector3.new(0.08, 0.02, 90), CFrame.new(i * 8, 0.01, -10), rgb(44, 42, 39)) end
	for j = -5, 3 do P(Vector3.new(120, 0.02, 0.08), CFrame.new(0, 0.01, j * 8), rgb(44, 42, 39)) end
	-- painted lane: red line + white stencil dashes behind the squad
	P(Vector3.new(70, 0.03, 0.6), CFrame.new(0, 0.02, -5), rgb(176, 30, 34))
	for i = -8, 8 do P(Vector3.new(1.4, 0.03, 0.3), CFrame.new(i * 4, 0.02, -6.1), rgb(210, 205, 194)) end
	-- the deck the squad stands on: steel plate + hazard edge
	P(Vector3.new(26, 0.35, 9), CFrame.new(0, 0.17, 0.5), rgb(40, 39, 37), Enum.Material.SmoothPlastic)
	for i = 0, 25 do
		P(Vector3.new(0.5, 0.36, 0.5), CFrame.new(-12.75 + i, 0.18, 5.05) * CFrame.Angles(0, math.rad(45), 0), (i % 2 == 0) and rgb(214, 170, 40) or rgb(24, 23, 22))
	end
	-- back wall: two stacked shipping containers (corrugated) + a rusty one to the left
	local function container(x, y, z, len, color, color2)
		P(Vector3.new(len, 8.6, 0.6), CFrame.new(x, y, z), color2)
		local n = math.floor(len / 1.1)
		for i = 0, n - 1 do
			P(Vector3.new(0.55, 8.2, 0.3), CFrame.new(x - len / 2 + 0.55 + i * 1.1, y, z + 0.4), (i % 2 == 0) and color or color2)
		end
		P(Vector3.new(len, 0.5, 0.9), CFrame.new(x, y + 4.3, z + 0.3), color2)
		P(Vector3.new(len, 0.5, 0.9), CFrame.new(x, y - 4.3, z + 0.3), color2)
		for _, s in { -1, 1 } do P(Vector3.new(0.6, 9.2, 1.0), CFrame.new(x + s * len / 2, y, z + 0.3), rgb(30, 29, 27)) end
	end
	container(-6, 4.3, -16, 26, rgb(128, 42, 34), rgb(108, 34, 28))
	container(14, 4.3, -15, 20, rgb(46, 74, 78), rgb(36, 60, 64))
	container(2, 13.0, -16.5, 30, rgb(150, 140, 120), rgb(128, 118, 100))
	-- white hazard band painted on the red container
	for i = 0, 6 do
		P(Vector3.new(0.9, 3.0, 0.1), CFrame.new(-16 + i * 1.6, 5.2, -15.3) * CFrame.Angles(0, 0, math.rad(35)), rgb(222, 218, 208))
	end
	-- crates + pallet on the right, barrels on the left
	local WOOD = rgb(122, 94, 62)
	P(Vector3.new(5, 0.5, 4), CFrame.new(15, 0.25, -6), rgb(96, 74, 50))
	P(Vector3.new(3.6, 3.6, 3.6), CFrame.new(14.2, 2.3, -6.2) * CFrame.Angles(0, math.rad(8), 0), WOOD)
	P(Vector3.new(2.6, 2.6, 2.6), CFrame.new(16.9, 1.8, -5.0) * CFrame.Angles(0, math.rad(-12), 0), WOOD)
	P(Vector3.new(2.4, 2.4, 2.4), CFrame.new(14.6, 5.3, -6.4) * CFrame.Angles(0, math.rad(20), 0), rgb(70, 72, 60))
	for i, x in { -17, -15.2, -16.1 } do
		P(Vector3.new(3.2, 2.2, 2.2), CFrame.new(x, 1.6, -7 - (i == 3 and 2 or 0)) * CFrame.Angles(0, 0, math.rad(90)),
			(i == 2) and rgb(176, 30, 34) or rgb(52, 70, 92), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	-- ceiling beams + hanging work lights (warm)
	for _, x in { -16, 0, 16 } do
		P(Vector3.new(0.8, 0.8, 40), CFrame.new(x, 19, -10), rgb(26, 25, 23))
		P(Vector3.new(0.06, 6, 0.06), CFrame.new(x * 0.6, 16, -6), rgb(20, 20, 20))
		P(Vector3.new(4.4, 0.35, 0.8), CFrame.new(x * 0.6, 13, -6), rgb(30, 30, 30))
		P(Vector3.new(4.0, 0.12, 0.5), CFrame.new(x * 0.6, 12.8, -6), rgb(255, 214, 160), NEON)
	end
	-- a red light strip low on the far wall (brand color)
	P(Vector3.new(60, 0.2, 0.2), CFrame.new(0, 0.6, -14.9), rgb(200, 30, 36), NEON)
end

-- 2D light on top of the 3D scene: warm haze, dark top/bottom, side vignette
do
	local haze = frame(home, 0, 0, MIDW, MIDH, Color3.fromRGB(255, 160, 80), 0.9)
	haze.ZIndex = 2
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.4), NumberSequenceKeypoint.new(1, 1) }) }, haze)
	local top = frame(home, 0, 0, MIDW, 160, BLACK, 0.2)
	top.ZIndex = 2
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }, top)
	local bottom = frame(home, 0, MIDH - 120, MIDW, 120, BLACK, 0.3)
	bottom.ZIndex = 2
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, bottom)
	for _, side in { 0, 1 } do
		local v = frame(home, side == 0 and 0 or MIDW - 260, 0, 260, MIDH, BLACK, 0.25)
		v.ZIndex = 2
		new("UIGradient", { Transparency = side == 0 and NumberSequence.new(0, 1) or NumberSequence.new(1, 0) }, v)
	end
end

-- the squad on the stage
local squad = {}   -- { fig, root, tag }
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

-- slot positions on the deck. Slot 1 = you (always the middle). Screen-left = -X.
local SLOTS = {
	{ pos = Vector3.new(0, 0.35, 1.2), yaw = 36 },
	{ pos = Vector3.new(-6.4, 0.35, -0.4), yaw = 24 },  -- your left (screen left)
	{ pos = Vector3.new(6.4, 0.35, -0.4), yaw = 48 },   -- your right
}

local function nameTag(text, isLeader, isMe)
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(240, 44), BackgroundTransparency = 1, ZIndex = 4 }, nameLayer)
	local w = math.clamp(#text * 11 + 36, 90, 240)
	local plate = frame(holder, (240 - w) / 2, 0, w, 26, isMe and C.cream or Color3.fromRGB(14, 14, 14), isMe and 0 or 0.15)
	plate.ZIndex = 4
	if not isMe then stroke(plate, C.edge, 1, 0) end
	local l = lbl(plate, text, 16, 0, 0, w, 26, isMe and C.dark or C.text, "H", Enum.TextXAlignment.Center)
	l.ZIndex = 5
	if isLeader then -- small red tab = party leader
		local lead = frame(holder, (240 - w) / 2, 26, 64, 16, C.red, 0)
		lead.ZIndex = 4
		lbl(lead, "LEADER", 11, 0, 0, 64, 16, WHITE, "MB", Enum.TextXAlignment.Center).ZIndex = 5
	end
	-- tick down to the head
	local tick = frame(holder, 119, 26 + (isLeader and 16 or 0), 2, 10, isMe and C.cream or C.edge, 0)
	tick.ZIndex = 4
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

-- stage info: stats top-left, equipped gun + skin bottom-right
local statText = lbl(home, "", 14, 28, 22, 500, 18, C.dim, "M")
statText.ZIndex = 5
local gearName = lbl(home, "", 26, MIDW - 528, MIDH - 72, 500, 32, C.text, "H", Enum.TextXAlignment.Right)
gearName.ZIndex = 5
local gearSub = lbl(home, "", 13, MIDW - 528, MIDH - 40, 500, 18, C.dim, "M", Enum.TextXAlignment.Right)
gearSub.ZIndex = 5
local function refreshStats()
	local w, l = player:GetAttribute("Wins") or 0, player:GetAttribute("Losses") or 0
	local rate = (w + l > 0) and (math.floor(w / (w + l) * 100 + 0.5) .. "%") or "--"
	statText.Text = ("WINS %d   LOSSES %d   WIN RATE %s"):format(w, l, rate)
end
for _, k in { "Wins", "Losses" } do player:GetAttributeChangedSignal(k):Connect(refreshStats) end
refreshStats()

-- ----- loadout bar -----
local bar = frame(stage, 320, 760, MIDW, 116, Color3.fromRGB(18, 17, 16), 0)
stroke(bar, C.edge, 1, 0)
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
	local box = new("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, s.frame)
	local item = Catalog.ById[slotItemId(s.kind, s.idx)]
	if item then
		local pic = new("Frame", { Size = UDim2.new(1, 0, 1, -20), BackgroundTransparency = 1 }, box)
		itemPicture(pic, item, 22)
		local nm = lbl(box, string.upper(item.name), 12, 6, s.frame.Size.Y.Offset - 20, s.frame.Size.X.Offset - 12, 16, C.text, "HM")
		nm.TextTruncate = Enum.TextTruncate.AtEnd
	else
		frame(box, (s.frame.Size.X.Offset - 18) / 2, 26, 18, 2, C.dim, 0)
		frame(box, (s.frame.Size.X.Offset - 2) / 2, 18, 2, 18, C.dim, 0)
		lbl(box, "EMPTY", 12, 6, s.frame.Size.Y.Offset - 20, 80, 16, C.dim, "HM")
	end
	local selected = (view == "pick" and pickKind == s.kind and pickIdx == s.idx)
	s.stroke.Color = selected and C.cream or C.edge
	s.stroke.Thickness = selected and 2 or 1
end

local function refreshLoadoutBar()
	for _, s in slots do drawSlot(s) end
	local w = Catalog.ById[loadout.Weapon]
	gearName.Text = w and string.upper(w.name) or ""
	gearSub.Text = (w and string.upper(w.sub) or "") .. "   //   SKIN: " .. Skins.Get(mySkin).name
end

local function makeSlot(kind, idx, x, w)
	local f = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, 30), Size = UDim2.fromOffset(w or 84, 78) }, bar)
	local st = stroke(f, C.edge, 1, 0)
	hoverColor(f, C.panel, C.panel2)
	local s = { kind = kind, idx = idx, frame = f, stroke = st }
	table.insert(slots, s)
	return s
end
local function groupLabel(text, x, w) lbl(bar, text, 13, x, 6, w, 20, C.dim, "H") end

groupLabel("MOVEMENT", 24, 120)
makeSlot("move", 1, 24)
groupLabel("WEAPON", 128, 200)
makeSlot("weapon", 1, 128, 190) -- wider so the gun picture reads
groupLabel("GADGETS", 340, 200)
for i = 1, 3 do makeSlot("gadget", i, 340 + (i - 1) * 92) end
frame(bar, 630, 30, 1, 78, C.edge, 0)
groupLabel("RESERVE", 652, 200)
for i = 1, 3 do makeSlot("reserve", i, 652 + (i - 1) * 92) end
lbl(bar, "CLICK A SLOT TO CHANGE IT", 12, 1100, 40, 436, 16, C.dim, "M", Enum.TextXAlignment.Right)
lbl(bar, "RESERVE SWAPS IN WHILE YOU ARE DEAD", 12, 1100, 60, 436, 16, C.dim, "M", Enum.TextXAlignment.Right)

-- ----- views -----
local setView -- forward
local function backButton(parent, x, y)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(120, 30) }, parent)
	keyHint(b, "<", "BACK", 0, 3)
	b.MouseButton1Click:Connect(function() setView("home") end)
	return b
end
local function viewBg(v)
	local f = frame(v, 0, 0, MIDW, MIDH, Color3.fromRGB(18, 17, 16), 0)
	-- faint grid like a workshop mat
	for i = 1, 25 do
		local l = frame(f, i * 64, 0, 1, MIDH, C.edge, 0.75)
		l.ZIndex = 1
	end
	return f
end

-- ----- pick view (gun pictures) -----
local pick = views.pick
viewBg(pick)
backButton(pick, 24, 18)
local pickTitle = lbl(pick, "", 30, 160, 10, 900, 40, C.text, "H")
lbl(pick, "CLICK AN ITEM TO EQUIP IT", 12, 162, 48, 900, 16, C.dim, "M")
local pickScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 78), Size = UDim2.fromOffset(MIDW - 48, MIDH - 96), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = C.edge, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, pick)
local pickGrid = new("UIGridLayout", { CellSize = UDim2.fromOffset(282, 206), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, pickScroll)
new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 12) }, pickScroll)

local PICK_TITLES = { move = "MOVEMENT //", weapon = "WEAPONS //", gadget = "GADGET //", reserve = "RESERVE //" }
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
	pickTitle.Text = PICK_TITLES[kind] .. ((kind == "gadget" or kind == "reserve") and ("  SLOT " .. idx) or "")
	local current = slotItemId(kind, idx)
	pickGrid.CellSize = (kind == "weapon" or kind == "reserve") and UDim2.fromOffset(282, 206) or UDim2.fromOffset(200, 206)
	local function card(item, order)
		local equipped = item and item.id == current or (not item and current == "")
		local cw = pickGrid.CellSize.X.Offset
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = order }, pickScroll)
		stroke(b, equipped and C.cream or C.edge, equipped and 2 or 1, 0)
		hoverColor(b, C.panel, C.panel2)
		if item then
			local pic = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(cw - 16, 136), BackgroundColor3 = Color3.fromRGB(28, 27, 25), BorderSizePixel = 0 }, b)
			itemPicture(pic, item, 34)
			-- cream name strip, ARC card style
			local strip = frame(b, 0, 150, cw, 56, equipped and C.cream or Color3.fromRGB(40, 38, 35), 0)
			lbl(strip, string.upper(item.name), 20, 12, 4, cw - 24, 26, equipped and C.dark or C.text, "H")
			lbl(strip, string.upper(item.sub), 12, 12, 30, cw - 24, 16, equipped and C.dark or C.dim, "M")
			if equipped then
				local tag = frame(b, cw - 92, 8, 84, 20, C.dark, 0)
				lbl(tag, "EQUIPPED", 11, 0, 0, 84, 20, C.cream, "MB", Enum.TextXAlignment.Center)
			end
		else
			lbl(b, "NONE", 22, 0, 70, cw, 28, C.dim, "H", Enum.TextXAlignment.Center)
			lbl(b, "LEAVE THIS SLOT EMPTY", 11, 0, 100, cw, 16, C.dim, "M", Enum.TextXAlignment.Center)
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
viewBg(inviteV)
backButton(inviteV, 24, 18)
lbl(inviteV, "INVITE //", 30, 160, 10, 400, 40, C.text, "H")
local inviteTab = "lobby"
local tabLobby = btn(inviteV, "LOBBY", 24, 66, 130, 36, "primary", 16)
local tabFriends = btn(inviteV, "FRIENDS", 162, 66, 130, 36, nil, 16)
local search = new("TextBox", { PlaceholderText = "SEARCH PLAYERS", Text = "", TextSize = 16, FontFace = FONTS.HM, TextColor3 = C.text,
	PlaceholderColor3 = C.dim, BackgroundColor3 = C.panel, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(312, 66), Size = UDim2.fromOffset(560, 36), BorderSizePixel = 0 }, inviteV)
stroke(search, C.edge, 1, 0)
new("UIPadding", { PaddingLeft = UDim.new(0, 14) }, search)
local inviteHint = lbl(inviteV, "", 14, 892, 66, 640, 36, C.red, "HM")
local inviteScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 116), Size = UDim2.fromOffset(MIDW - 48, MIDH - 134), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = C.edge, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, inviteV)
new("UIListLayout", { Padding = UDim.new(0, 6) }, inviteScroll)
new("UIPadding", { PaddingRight = UDim.new(0, 8) }, inviteScroll)

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
	b.BackgroundColor3 = on and C.cream or C.panel2
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
						note = inLobby and "IN THE LOBBY" or "ONLINE - ANOTHER GAME" })
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
		local msg = (inviteTab == "friends" and not friendsCache) and "LOADING FRIENDS..."
			or (q ~= "" and #q >= 3) and ("NO MATCH. PRESS ENTER TO INVITE \"" .. search.Text .. "\" BY EXACT USERNAME.")
			or (inviteTab == "lobby" and "NOBODY ELSE IS IN THIS LOBBY. TRY FRIENDS, OR SEARCH A USERNAME.")
			or "NO FRIENDS ONLINE."
		new("TextLabel", { BackgroundTransparency = 1, Text = msg, TextSize = 16, FontFace = FONTS.HM, TextColor3 = C.dim,
			Size = UDim2.new(1, 0, 0, 80), TextWrapped = true }, inviteScroll)
		return
	end
	for i, e in shown do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = i }, inviteScroll)
		stroke(row, C.edge, 1, 0)
		new("ImageLabel", { BackgroundColor3 = C.panel2, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(44, 44), Image = thumb(e.id) }, row)
		lbl(row, string.upper(e.display), 19, 66, 6, 600, 26, C.text, "H")
		lbl(row, "@" .. e.name .. "   //   " .. e.note, 12, 66, 34, 700, 18, e.ok and C.dim or C.edge, "M")
		local sent = sentAt[e.id] and os.clock() - sentAt[e.id] < 8
		local usable = canInvite and e.ok and not sent
		local rw = inviteScroll.AbsoluteSize.X > 0 and 0 or 0
		local plus = btn(row, sent and "SENT" or "INVITE", 0, 12, 110, 36, usable and "primary" or nil, 15)
		plus.Position = UDim2.new(1, -122 + rw, 0, 12)
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
backButton(modeV, 24, 18)
local modeArt = frame(modeV, 40, 70, 600, 460, C.panel, 0)
modeArt.ClipsDescendants = true
stroke(modeArt, C.edge, 1, 0)
modeGraphic(modeArt)
local mTitle = lbl(modeV, "", 64, 690, 60, 800, 76, C.text, "H")
local mTag = lbl(modeV, "", 15, 694, 136, 800, 20, C.red, "MB")
local mDesc = lbl(modeV, "", 17, 694, 172, 800, 110, C.dim, "B")
mDesc.TextWrapped, mDesc.TextYAlignment = true, Enum.TextYAlignment.Top
local mFacts = lbl(modeV, "", 16, 694, 292, 800, 140, C.text, "BM")
mFacts.TextWrapped, mFacts.TextYAlignment = true, Enum.TextYAlignment.Top
local mSelect = btn(modeV, "SELECT", 694, 466, 260, 56, "primary", 24)
local modeShown = MODES[1]
local function openMode(m)
	modeShown = m
	mTitle.Text, mTag.Text, mDesc.Text = m.name, m.tag, m.desc
	mFacts.Text = "/  " .. table.concat(m.facts, "\n/  ")
	mSelect.Text = (selectedMode == m.id) and "SELECTED" or "SELECT"
	setView("mode")
end
mSelect.MouseButton1Click:Connect(function()
	selectedMode = modeShown.id
	refreshModes()
	setView("home")
end)

for i, m in MODES do
	local card = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(250, 150), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = i, ClipsDescendants = true }, modeScroll)
	local st = stroke(card, C.edge, 1, 0)
	local g = modeGraphic(card)
	g.Size = UDim2.new(1, 0, 1, -44)
	local strip = frame(card, 0, 106, 250, 44, Color3.fromRGB(40, 38, 35), 0)
	lbl(strip, m.name, 20, 10, 2, 230, 24, C.text, "H")
	lbl(strip, m.tag, 11, 10, 25, 230, 14, C.dim, "M")
	local tag = frame(card, 8, 8, 74, 18, C.cream, 0)
	lbl(tag, "SELECTED", 10, 0, 0, 74, 18, C.dark, "MB", Enum.TextXAlignment.Center)
	tag.Visible = false
	card.MouseButton1Click:Connect(function() openMode(m) end)
	modeCards[m.id] = { stroke = st, tag = tag }
end
refreshModes()

function setView(name)
	view = name
	for n, f in views do f.Visible = (n == name) end
	for _, s in slots do drawSlot(s) end
	if name == "invite" then rebuildInvite() end
end

-- ================= party row: 3 boxes, PARTY LEADER ALWAYS IN THE LEFTMOST BOX =================
local partyHolder = frame(stage, 320, 892, 760, 156, WHITE, 1)
header(stage, "SQUAD", 40, 892, 250, 30)
local squadCount = lbl(stage, "", 13, 48, 930, 240, 18, C.dim, "M")
keyHint(stage, "TAB", "SKINS", 40, 1020)
local BOXW, BOXH, BOXGAP = 244, 156, 14

local function renderParty()
	for _, c in partyHolder:GetChildren() do c:Destroy() end
	local list, leader = partyInfo()
	local iLead = (leader == player.UserId)
	-- leader first, then everyone else in join order
	local ordered = {}
	for _, m in list do if m.id == leader then table.insert(ordered, m) end end
	for _, m in list do if m.id ~= leader then table.insert(ordered, m) end end
	squadCount.Text = ("%d / 3 PLAYERS"):format(#ordered)

	for i = 1, 3 do
		local m = ordered[i]
		local x = (i - 1) * (BOXW + BOXGAP)
		if m then
			local isMe = m.id == player.UserId
			local isLeader = m.id == leader
			local f = frame(partyHolder, x, 0, BOXW, BOXH, C.panel, 0)
			stroke(f, isMe and C.cream or C.edge, isMe and 2 or 1, 0)
			-- top strip: cream for the leader box, dark for the others
			local strip = frame(f, 0, 0, BOXW, 26, isLeader and C.cream or Color3.fromRGB(40, 38, 35), 0)
			lbl(strip, isLeader and "PARTY LEADER" or ("SLOT " .. i), 13, 10, 0, 160, 26, isLeader and C.dark or C.dim, "H")
			if isMe then lbl(strip, "YOU", 13, BOXW - 50, 0, 40, 26, isLeader and C.red or C.cream, "H", Enum.TextXAlignment.Right) end
			if isLeader then frame(f, 0, 26, 4, BOXH - 26, C.red, 0) end
			new("ImageLabel", { BackgroundColor3 = C.panel2, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 38), Size = UDim2.fromOffset(64, 64), Image = thumb(m.id) }, f)
			local nm = lbl(f, string.upper(isMe and player.DisplayName or m.name), 20, 90, 40, BOXW - 100, 26, C.text, "H")
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			local skin = isMe and mySkin or memberLook(m)
			lbl(f, "@" .. m.name, 12, 90, 66, BOXW - 100, 16, C.dim, "M").TextTruncate = Enum.TextTruncate.AtEnd
			lbl(f, Skins.Get(skin).name, 12, 90, 84, BOXW - 100, 16, C.dim, "M")
			if iLead and not isMe then
				local kick = btn(f, "KICK", 14, 116, 100, 28, "danger", 14)
				local prom = btn(f, "PROMOTE", 122, 116, 108, 28, nil, 14)
				kick.MouseButton1Click:Connect(function() KickR:FireServer(m.id) end)
				prom.MouseButton1Click:Connect(function() PromoteR:FireServer(m.id) end)
			elseif isMe and #list > 1 then
				local lv = btn(f, "LEAVE PARTY", 14, 116, BOXW - 28, 28, nil, 14)
				lv.MouseButton1Click:Connect(function() LeaveR:FireServer() end)
			end
		else
			local f = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(BOXW, BOXH),
				BackgroundColor3 = Color3.fromRGB(16, 15, 14), BorderSizePixel = 0 }, partyHolder)
			stroke(f, C.edge, 1, 0.3)
			hoverColor(f, Color3.fromRGB(16, 15, 14), C.panel)
			frame(f, (BOXW - 24) / 2, 54, 24, 2, C.dim, 0)
			frame(f, (BOXW - 2) / 2, 43, 2, 24, C.dim, 0)
			lbl(f, "OPEN SLOT", 16, 0, 84, BOXW, 22, C.dim, "H", Enum.TextXAlignment.Center)
			lbl(f, "CLICK TO INVITE", 11, 0, 106, BOXW, 16, C.edge, "M", Enum.TextXAlignment.Center)
			f.MouseButton1Click:Connect(function() setView("invite") end)
		end
	end
	if view == "invite" then rebuildInvite() end
end

-- ================= start / queue =================
local startBtn, startMain, startSub, startNotch = playBlock(stage, 1116, 892, 664, 156)
startMain.Text = "START"
local startPlus = plusCircle(stage, 1800, 938, 64)

local function fmtTime(s) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
local function setBlock(main, sub, bg, notch)
	startMain.Text, startSub.Text = main, sub
	startBtn.BackgroundColor3 = bg
	startNotch.BackgroundColor3 = notch
end
local function refreshQueue()
	local q, tp = player:GetAttribute("Queued"), player:GetAttribute("Teleporting")
	local list, leader = partyInfo()
	local iLead = (leader == player.UserId)
	local mode = MODES[1]
	if tp then
		setBlock("DEPLOYING", "JOINING MATCH...", C.cream2, C.dim)
	elseif q then
		local qa = player:GetAttribute("QueuedAt")
		setBlock("CANCEL", "SEARCHING  " .. fmtTime(math.max(0, os.time() - (qa or os.time()))), C.cream, C.red)
	elseif not iLead then
		setBlock("WAITING", "ONLY THE PARTY LEADER CAN START", C.cream2, C.dim)
	else
		setBlock("START", mode.name .. "  //  " .. mode.tag .. (#list > 1 and ("  //  PARTY OF " .. #list) or ""), C.cream, C.red)
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
-- party members on this server changing skin / gun
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
local PANELW = 940
local skinsOpen = false
local skinPanel = frame(skinC, 1920, 0, PANELW, 1080, Color3.fromRGB(10, 10, 10), 0.04)
skinPanel.ZIndex = 30
frame(skinPanel, 0, 0, 1, 1080, C.edge, 0).ZIndex = 30
-- the handle: a vertical cream tab stuck to the panel's left edge
local handle = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.cream, BorderSizePixel = 0,
	Position = UDim2.fromOffset(-44, 430), Size = UDim2.fromOffset(44, 200), ZIndex = 31 }, skinPanel)
frame(handle, 0, 0, 44, 6, C.red, 0).ZIndex = 32
local handleText = new("TextLabel", { BackgroundTransparency = 1, Text = "SKINS", TextSize = 20, FontFace = FONTS.H, TextColor3 = C.dark,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(160, 30), Rotation = -90, ZIndex = 32 }, handle)
hoverColor(handle, C.cream, WHITE)

local sTitle = lbl(skinPanel, "SKINS //", 44, 48, 34, 500, 56, C.text, "H")
sTitle.ZIndex = 31
local sSub = lbl(skinPanel, "WHAT YOU WEAR IN THE LOBBY, ON THE STAGE AND IN THE MATCH.", 13, 50, 90, 800, 18, C.dim, "M")
sSub.ZIndex = 31
local sClose = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(PANELW - 140, 44), Size = UDim2.fromOffset(110, 30), ZIndex = 31 }, skinPanel)
keyHint(sClose, "TAB", "CLOSE", 0, 3)
for _, d in sClose:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 32 end end

local skinCards = {}
local CARDW, CARDH = 272, 620
local function drawSkinCards()
	for _, c in skinCards do
		local on = c.id == mySkin
		c.strip.BackgroundColor3 = on and C.cream or Color3.fromRGB(40, 38, 35)
		c.name.TextColor3 = on and C.dark or C.text
		c.sub.TextColor3 = on and C.dark or C.dim
		c.tag.Visible = on
		c.stroke.Color = on and C.cream or C.edge
		c.stroke.Thickness = on and 2 or 1
		c.equip.Text = on and "EQUIPPED" or "EQUIP"
		c.equip.TextColor3 = on and C.dim or C.text
	end
end
local equipSkin -- forward
for i, sk in Skins.List do
	local x = 48 + (i - 1) * (CARDW + 14)
	local card = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, ClipsDescendants = true,
		Position = UDim2.fromOffset(x, 140), Size = UDim2.fromOffset(CARDW, CARDH), ZIndex = 31 }, skinPanel)
	local st = stroke(card, C.edge, 1, 0)
	-- poster background: the skin's color with bold diagonal bands (ARC store cards)
	local poster = frame(card, 0, 0, CARDW, CARDH - 120, sk.card, 0)
	poster.ZIndex = 31
	poster.ClipsDescendants = true
	for b = 0, 3 do
		local band = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(40 + b * 70, 250), Size = UDim2.fromOffset(26, 900),
			Rotation = 24, BackgroundColor3 = sk.card:Lerp(BLACK, 0.25), BorderSizePixel = 0, ZIndex = 31 }, poster)
		band.BackgroundTransparency = 0.2
	end
	local floorShade = frame(poster, 0, CARDH - 260, CARDW, 140, BLACK, 0.35)
	floorShade.ZIndex = 31
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, floorShade)
	local num = lbl(poster, ("%02d"):format(i), 64, 14, 4, 120, 70, sk.card:Lerp(WHITE, 0.25), "H")
	num.ZIndex, num.TextTransparency = 31, 0.2
	local fv = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 32, Ambient = Color3.fromRGB(150, 140, 130),
		LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-0.5, -0.9, -0.6) }, poster)
	local cam = new("Camera", { FieldOfView = 30 }, fv)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.4, 17.5), Vector3.new(0, 3.7, 0))
	fv.CurrentCamera = cam
	local strip = frame(card, 0, CARDH - 120, CARDW, 120, Color3.fromRGB(40, 38, 35), 0)
	strip.ZIndex = 31
	local nm = lbl(strip, sk.name, 26, 14, 8, CARDW - 28, 32, C.text, "H")
	nm.ZIndex = 32
	local sb = lbl(strip, string.upper(sk.sub), 12, 14, 40, CARDW - 28, 16, C.dim, "M")
	sb.ZIndex = 32
	local ds = lbl(strip, sk.desc, 12, 14, 58, CARDW - 28, 30, C.dim, "B")
	ds.ZIndex, ds.TextWrapped, ds.TextYAlignment = 32, true, Enum.TextYAlignment.Top
	local eq = lbl(strip, "EQUIP", 13, 14, 94, CARDW - 28, 18, C.text, "MB")
	eq.ZIndex = 32
	local tag = frame(card, CARDW - 96, 10, 86, 22, C.dark, 0)
	tag.ZIndex = 33
	lbl(tag, "EQUIPPED", 11, 0, 0, 86, 22, C.cream, "MB", Enum.TextXAlignment.Center).ZIndex = 34
	card.MouseButton1Click:Connect(function() equipSkin(sk.id) end)
	card.MouseEnter:Connect(function() if sk.id ~= mySkin then st.Color = C.cream2 end end)
	card.MouseLeave:Connect(function() drawSkinCards() end)
	skinCards[i] = { id = sk.id, strip = strip, name = nm, sub = sb, tag = tag, stroke = st, equip = eq, vp = fv, fig = nil }
end
local skinHint = lbl(skinPanel, "MORE SKINS COME WITH THE SHOP.", 13, 50, 780, 800, 18, C.dim, "M")
skinHint.ZIndex = 31

local function buildSkinFigures()
	for _, c in skinCards do
		if c.fig then c.fig:Destroy() end
		c.fig = Skins.NewFigure(c.vp, c.id, { weapon = loadout.Weapon, camPos = Vector3.new(0, 4.4, 17.5) })
		c.fig:SetRoot(CFrame.Angles(0, math.rad(30), 0))
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
	TweenService:Create(skinPanel, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(on and 1920 - PANELW or 1920, 0) }):Play()
	handleText.Text = on and "CLOSE" or "SKINS"
end
handle.MouseButton1Click:Connect(function() setSkins(not skinsOpen) end)
sClose.MouseButton1Click:Connect(function() setSkins(false) end)
drawSkinCards()

-- nav buttons in the top bar
for _, b in topBar:GetChildren() do
	if b:IsA("TextButton") and b:GetAttribute("Nav") then
		b.MouseButton1Click:Connect(function()
			local n = b:GetAttribute("Nav")
			if n == "SKINS" then setSkins(true)
			elseif n == "LOADOUT" then openPick("weapon", 1)
			else setView("home") end
		end)
	end
end

-- ================= open / close =================
function openScreen(startView)
	if not screenOpen then
		screenOpen = true
		screen.Visible = true
		screen.BackgroundTransparency = 1
		stage.Position = UDim2.new(0.5, 0, 0.5, 24)
		TweenService:Create(screen, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(stage, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		hud.Visible = false
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
	TweenService:Create(screen, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	task.delay(0.15, function() if not screenOpen then screen.Visible = false end end)
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
	if hud.Visible then logoSteps[1](t, dt) end
	if screenOpen then logoSteps[2](t, dt) end
	if screenOpen and view == "home" then
		for _, s in squad do
			s.fig:Update(t, dt)
			local p = project((s.root * CFrame.new(0, s.top + 0.6, 0)).Position)
			if p then s.tag.Position = UDim2.fromOffset(p.X, p.Y) end
		end
	end
	if skinsOpen then
		for _, c in skinCards do if c.fig then c.fig:Update(t, dt) end end
	end
end)

-- ================= invite popup + notices =================
local popC = canvas(gui, 50)
local pop_ = frame(popC, 760, -140, 400, 116, Color3.fromRGB(14, 14, 14), 0)
pop_.ZIndex = 50
stroke(pop_, C.edge, 1, 0)
local popHead = frame(pop_, 0, 0, 400, 28, C.cream, 0)
popHead.ZIndex = 51
lbl(popHead, "PARTY INVITE", 14, 12, 0, 300, 28, C.dark, "H").ZIndex = 52
local popText = lbl(pop_, "", 18, 14, 34, 372, 30, C.text, "H")
popText.ZIndex = 51
local yes = btn(pop_, "ACCEPT", 14, 70, 180, 34, "primary", 15)
local no = btn(pop_, "DECLINE", 206, 70, 180, 34, nil, 15)
yes.ZIndex, no.ZIndex = 51, 51
local current
local function showPop(on)
	TweenService:Create(pop_, TweenInfo.new(0.22, Enum.EasingStyle.Quart), { Position = UDim2.fromOffset(760, on and 20 or -140) }):Play()
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
