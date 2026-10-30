-- LoadingScreen v1 (LocalScript in ReplicatedFirst) - BREAKLINE place only.
-- Minimal black screen: the big BREAKLINE logo in the middle (its slash explodes at both ends) and one line of text under it that
-- tells the player what is happening ("LOADING", "LOADING MAP", "WAITING FOR PLAYERS  3 / 6", "ALL PLAYERS LOADED").
-- When this client has finished loading it tells the server (MatchRemotes.ClientReady). The server starts the pre-game screen once everyone
-- is ready; this screen then fades out and MatchFlow takes over.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RF = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

pcall(function() RF:RemoveDefaultLoadingScreen() end)

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local root = Instance.new("CanvasGroup") -- everything lives in here so the whole screen can fade as one
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(6, 7, 10)
root.BorderSizePixel = 0
root.Parent = gui

local UI = require(RS:WaitForChild("UIKit"))
local C, F = UI.C, UI.F

-- sizes from the real screen height
local vh = 1080
for _ = 1, 30 do
	if root.AbsoluteSize.Y > 0 then vh = root.AbsoluteSize.Y break end
	task.wait()
end
local logoSize = math.clamp(math.floor(vh * 0.2), 64, 230)

local fx = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, root) -- explosion sparks are drawn here
local logo, stopLogo = UI.Logo(root, logoSize, fx, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -math.floor(logoSize * 0.2)) })

local label = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, math.floor(logoSize * 0.78)),
	Size = UDim2.fromOffset(900, 36), BackgroundTransparency = 1, Text = "LOADING", TextSize = 22, FontFace = F.M, TextColor3 = C.dim }, root)
local barW = math.clamp(math.floor(vh * 0.4), 200, 460)
local bar = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, math.floor(logoSize * 0.78) + 46),
	Size = UDim2.fromOffset(barW, 2), BackgroundColor3 = C.line, BorderSizePixel = 0 }, root)
local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.red, BorderSizePixel = 0 }, bar)

local status, dots, progress = "LOADING", true, 0
local shown = 0
task.spawn(function() -- animated dots + smooth progress bar
	local n = 0
	local acc = 0
	while gui.Parent do
		local dt = task.wait()
		acc += dt
		if acc >= 0.35 then acc = 0; n = (n + 1) % 4 end
		label.Text = status .. (dots and string.rep(".", n) or "")
		shown += (progress - shown) * math.min(1, dt * 6)
		fill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
	end
end)

local function setStatus(text, withDots)
	if status == text then return end
	status, dots = text, withDots ~= false
	label.TextTransparency = 1
	TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
end

local function finish()
	stopLogo()
	TweenService:Create(root, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 }):Play()
	task.wait(0.9)
	gui:Destroy()
end

-- ===== 1) wait for the game, then for the match objects =====
if not game:IsLoaded() then game.Loaded:Wait() end
setStatus("CONNECTING")
progress = 0.1
local State = RS:WaitForChild("MatchState", 60)
local Remotes = RS:WaitForChild("MatchRemotes", 60)
if not State or not Remotes then
	setStatus("COULD NOT CONNECT TO THE MATCH", false)
	task.wait(4)
	finish()
	return
end

-- ===== 2) preload the map (max 10 s) =====
setStatus("LOADING MAP")
progress = 0.3
do
	local done = false
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ workspace }) end)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 10 do
		progress = 0.3 + 0.4 * math.clamp((os.clock() - t0) / 10, 0, 1)
		task.wait(0.1)
	end
end

-- ===== 3) wait for our character (max 8 s), then tell the server we are ready =====
setStatus("LOADING PLAYER")
progress = 0.75
do
	local t0 = os.clock()
	while not player.Character and os.clock() - t0 < 8 do task.wait(0.1) end
end
Remotes:WaitForChild("ClientReady"):FireServer()
progress = 0.85

-- ===== 4) show what the server is waiting for until the match starts =====
local startedAt = os.clock()
while true do
	local phase = State:GetAttribute("Phase")
	if phase ~= "Waiting" then break end
	local expected = State:GetAttribute("Expected") or 0
	local ready = State:GetAttribute("Ready") or 0
	if State:GetAttribute("AllReady") then
		setStatus("ALL PLAYERS LOADED", false)
		progress = 1
	elseif expected > 0 then
		setStatus(("WAITING FOR PLAYERS   %d / %d"):format(math.min(ready, expected), expected), false)
		progress = 0.85 + 0.15 * math.clamp(ready / expected, 0, 1)
	else
		setStatus("WAITING FOR PLAYERS")
	end
	task.wait(0.1)
end
if State:GetAttribute("Phase") == "Pregame" then
	setStatus("ALL PLAYERS LOADED", false)
	progress = 1
	task.wait(0.35)
end
finish()
