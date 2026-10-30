-- LobbyLoading v1 (LocalScript in ReplicatedFirst) - LOBBY place only. NEW in GDD v3.7.
-- Loading screen shown when you join the lobby (first join or coming back from a match):
--   * black screen; BREAK flies in from the left, LINE from the right, they meet in the middle and the red slash draws in
--     between them with light flowing down it (UIKit.Logo, same logo as Breakline's loading screen + the lobby top-left logo)
--   * one line under it says what is loading right now (CONNECTING, LOADING PROFILE, LOADING LOADOUT, SUITING UP, LOADING LOBBY,
--     BUILDING MENUS, RESTORING YOUR SQUAD, READY) + a thin red progress line
--   * exit: the slash stretches into a seam across the whole screen, the words fly apart, and the black splits along the seam
--     like two doors sliding open (left half to the lower left, right half to the upper right), revealing the lobby.
-- Every wait has a time limit, so the screen can never get stuck. Needs ReplicatedStorage.UIKit (copy of Breakline's).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RF = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

pcall(function() RF:RemoveDefaultLoadingScreen() end)

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local BG = Color3.fromRGB(6, 7, 10)
local MIN_TIME = 2.6 -- the screen stays at least this long so the intro can finish

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyLoading"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

-- plain black cover right away (UIKit may need a moment to replicate); replaced by the two door halves once it is here
local cover = Instance.new("Frame")
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = BG
cover.BorderSizePixel = 0
cover.ZIndex = 1
cover.Parent = root

local t0 = os.clock()
local UIKitModule = RS:WaitForChild("UIKit", 20)
if not UIKitModule then
	-- no UIKit in the lobby yet: just fade the black away once the game has loaded
	if not game:IsLoaded() then game.Loaded:Wait() end
	TweenService:Create(cover, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	task.wait(0.7)
	gui:Destroy()
	return
end
local UI = require(UIKitModule)
local C, F = UI.C, UI.F

-- screen size (the layout is sized from the real screen height)
local vs = Vector2.new(1920, 1080)
for _ = 1, 30 do
	if root.AbsoluteSize.Y > 0 then vs = root.AbsoluteSize break end
	task.wait()
end
local vh = vs.Y
local logoSize = math.clamp(math.floor(vh * 0.16), 56, 190)
local logoY = -math.floor(logoSize * 0.25)

-- ===== the two door halves (rotated like the slash; their shared edge is the seam through the slash) =====
local ANG = math.rad(UI.LOGO_ANGLE)
local N = Vector2.new(math.cos(ANG), math.sin(ANG)) -- unit normal of the seam, pointing to the right half
local diag = vs.Magnitude
local PW, PH = math.ceil(diag * 1.6), math.ceil(diag * 2.4)
local function door(side) -- side = -1 left half, 1 right half
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(PW, PH)
	f.Rotation = UI.LOGO_ANGLE
	f.BackgroundColor3 = BG
	f.BorderSizePixel = 0
	f.ZIndex = 2
	f.Parent = root
	-- faint top-light so the halves read as panels when they slide
	local g = Instance.new("UIGradient")
	g.Rotation = side == -1 and 0 or 180
	g.Color = ColorSequence.new(Color3.fromRGB(16, 17, 22), BG)
	g.Parent = f
	return f
end
local doorL, doorR = door(-1), door(1)
local seam = Vector2.new(0, logoY) -- seam centre, offset from the screen centre (moved onto the slash once the logo has a layout)
local function placeDoors(extra)
	extra = extra or 0
	local cL = seam - N * (PW / 2 + extra)
	local cR = seam + N * (PW / 2 + extra)
	doorL.Position = UDim2.new(0.5, cL.X, 0.5, cL.Y)
	doorR.Position = UDim2.new(0.5, cR.X, 0.5, cR.Y)
end
placeDoors(0)
cover:Destroy()

-- ===== logo + status line + progress =====
local logo, logoApi = UI.Logo(root, logoSize, { Position = UDim2.new(0.5, 0, 0.5, logoY), ZIndex = 5 }, "center")
local label = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, logoY + math.floor(logoSize * 0.95)),
	Size = UDim2.fromOffset(900, 30), BackgroundTransparency = 1, Text = "", TextSize = math.clamp(math.floor(vh * 0.018), 13, 20),
	FontFace = F.M, TextColor3 = C.dim, TextTransparency = 1, ZIndex = 6 }, root)
local barW = math.clamp(math.floor(vh * 0.32), 180, 380)
local bar = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, logoY + math.floor(logoSize * 0.95) + 40),
	Size = UDim2.fromOffset(barW, 2), BackgroundColor3 = C.line, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6 }, root)
local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.red, BorderSizePixel = 0, ZIndex = 7 }, bar)
local step = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, logoY + math.floor(logoSize * 0.95) + 50),
	Size = UDim2.fromOffset(400, 18), BackgroundTransparency = 1, Text = "", TextSize = math.clamp(math.floor(vh * 0.012), 10, 14),
	FontFace = F.M, TextColor3 = C.mute, TextTransparency = 1, ZIndex = 6 }, root)

task.spawn(function()
	logoApi.intro(1.3)
	TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	TweenService:Create(bar, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(step, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
end)
-- keep the door seam on the slash (the logo is laid out a frame after it is created)
task.delay(0.1, function()
	local s = logoApi.slash
	if s and s.Parent then
		local c = s.AbsolutePosition + s.AbsoluteSize / 2 - root.AbsolutePosition - root.AbsoluteSize / 2
		seam = Vector2.new(c.X, c.Y)
		placeDoors(0)
	end
end)

-- status text with animated dots + smooth progress
local STEPS = 8
local status, dots, progress, stepN = "CONNECTING", true, 0, 1
local shown = 0
task.spawn(function()
	local n, acc = 0, 0
	while gui.Parent do
		local dt = task.wait()
		acc += dt
		if acc >= 0.35 then acc = 0; n = (n + 1) % 4 end
		label.Text = status .. (dots and string.rep(".", n) or "")
		step.Text = ("%d / %d"):format(math.min(stepN, STEPS), STEPS)
		shown += (progress - shown) * math.min(1, dt * 6)
		fill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
	end
end)
local function setStatus(text, p, n, withDots)
	status, dots = text, withDots ~= false
	if p then progress = p end
	if n then stepN = n end
end
local function waitFor(check, maxTime)
	local s = os.clock()
	while not check() and os.clock() - s < maxTime do task.wait(0.1) end
	return check()
end

-- ===== 1) connect =====
setStatus("CONNECTING TO THE LOBBY", 0.05, 1)
if not game:IsLoaded() then game.Loaded:Wait() end

-- ===== 2) profile (souls, skin, wins) - the server sets ProfileLoaded when your save is in =====
setStatus("LOADING PROFILE", 0.18, 2)
waitFor(function() return player:GetAttribute("ProfileLoaded") == true end, 12)

-- ===== 3) loadout =====
setStatus("LOADING LOADOUT", 0.32, 3)
waitFor(function() return player:GetAttribute("LoadoutJson") ~= nil end, 5)

-- ===== 4) your character in its skin =====
setStatus("SUITING UP", 0.45, 4)
waitFor(function() return player.Character ~= nil end, 10)
waitFor(function() return player.Character ~= nil and player.Character:FindFirstChild("Gear") ~= nil end, 6)

-- ===== 5) the lobby map =====
setStatus("LOADING LOBBY", 0.58, 5)
do
	local done = false
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ workspace }) end)
		done = true
	end)
	local s = os.clock()
	while not done and os.clock() - s < 8 do
		progress = 0.58 + 0.17 * math.clamp((os.clock() - s) / 8, 0, 1)
		task.wait(0.1)
	end
end

-- ===== 6) menus (LobbyClient builds its ScreenGui) =====
setStatus("BUILDING MENUS", 0.8, 6)
waitFor(function() return pg:FindFirstChild("LobbyUI") ~= nil end, 8)

-- ===== 7) party (coming back from a match with your squad) =====
setStatus("RESTORING YOUR SQUAD", 0.9, 7)
waitFor(function() return player:GetAttribute("PartyId") ~= nil end, 1.2)

-- ===== 8) done =====
setStatus("READY", 1, 8, false)
while os.clock() - t0 < MIN_TIME do task.wait() end
task.wait(0.35)

-- ===== exit: seam + words apart + doors open =====
for _, o in { label, step } do TweenService:Create(o, TweenInfo.new(0.2), { TextTransparency = 1 }):Play() end
TweenService:Create(bar, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
local scale = math.max(logo.AbsoluteSize.Y / math.floor(logoSize * 1.2), 1e-3)
task.spawn(logoApi.outro, 0.55, diag * 1.3 / scale) -- the slash stretches into a full-screen seam
task.wait(0.4)
-- doors slide apart along the seam's normal
local OPEN = TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
local extra = diag * 0.75
local cL = seam - N * (PW / 2 + extra)
local cR = seam + N * (PW / 2 + extra)
TweenService:Create(doorL, OPEN, { Position = UDim2.new(0.5, cL.X, 0.5, cL.Y) }):Play()
TweenService:Create(doorR, OPEN, { Position = UDim2.new(0.5, cR.X, 0.5, cR.Y) }):Play()
-- the seam light fades as the doors open
task.delay(0.15, function()
	local s = os.clock()
	while gui.Parent and os.clock() - s < 0.45 do
		logoApi.setTransparency(math.clamp((os.clock() - s) / 0.45, 0, 1))
		task.wait()
	end
	if gui.Parent then logoApi.setTransparency(1) end
end)
task.wait(0.9)
logoApi.stop()
gui:Destroy()
