-- LoadingScreen v3.3 (LocalScript in ReplicatedFirst) - BREAKLINE place only.
-- v5.15 FIX (owner: "the loading screen never goes away, it stays there even after the 15 seconds have passed and everyone has loaded in, the game
--        goes on without you"): the wait loop at the end used `os.clock() - t0`, but `t0` only existed as a local inside the logo fade task, so here it
--        was an undefined global (nil). While the phase was Waiting the check was skipped; the moment the server moved on to Pregame it ran
--        `os.clock() - nil`, the script errored and stopped, finish() never ran and the screen (DisplayOrder 1000) stayed on top of the whole match.
--        Now: (1) `shownAt` is set when the screen appears and the loop uses it; (2) the wait loop runs inside pcall, so any error still closes the
--        screen; (3) a WATCHDOG closes the screen at the latest FAILSAFE seconds after the phase has left Waiting (and MIN_SHOW has passed), whatever
--        happens; (4) waiting for the ClientReady remote has a time limit.
-- v5.13 (owner: "the camera zooms in ever so slightly, it looks weird"): the map picture is now a STILL image. No slow drift / zoom while loading
--        and no push-in when the screen leaves (it just fades). It is shown as zoomed OUT as it can be while still filling the whole screen with no
--        empty space: Size 1 x 1 + ScaleType Crop (before: 106 % and growing, so the edges were always cut off a bit more than needed).
-- v5.10: (1) the picture is loaded with UIKit.LoadImage, which checks that it REALLY loaded and falls back to a thumbnail link of the same asset id (the black picture bug);
--        the link that worked is saved as the Player attribute MapImageSrc so the Warp reuses it. (2) the screen stays at least MIN_SHOW = 15 s, and once everybody has loaded
--        it counts down the server's hold (MatchConfig.LOAD_HOLD) as MATCH STARTS IN n.
-- LoadingScreen v3 (LocalScript in ReplicatedFirst) - BREAKLINE place only.
-- v5.8: MAP LOADING SCREEN. Instead of the black logo screen, the picked map's own picture fills the whole screen (a watercolour +
--       pencil sketch per map), slowly drifting / zooming. Bottom right: the mode line (BREAKLINE // 3V3 or 1V1 // DUEL) and the MAP NAME
--       in big letters with a red slash drawing in under it. Bottom left: what is happening (LOADING MAP / WAITING FOR PLAYERS 3 / 6 ...) +
--       a percentage. The very bottom edge of the screen is the progress line. Small BREAKLINE logo top left.
--       The picture + name come from MatchState attributes MapImage / MapName (MatchServer, from MatchConfig.MAPS.Info or the map
--       folder's LoadingImage / DisplayName attributes). No picture yet (MapImage "") = the same layout on a dark background.
-- (v3.7 logo screen replaced.) When this client has finished loading it tells the server (MatchRemotes.ClientReady). The server starts the
-- pre-game screen once everyone is ready; this screen then fades out and MatchFlow takes over.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RF = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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
local shownAt = os.clock() -- v5.15: when the screen appeared (MIN_SHOW counts from here; this was the missing `t0`)
local MIN_SHOW = 15 -- v5.10: at least 15 s on screen (was 3.5)
local FAILSAFE = 3 -- v5.15: the screen is closed at the latest this many seconds after the phase left Waiting (once MIN_SHOW has passed)

local root = Instance.new("CanvasGroup") -- everything lives in here so the whole screen can fade as one
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(6, 7, 10)
root.BorderSizePixel = 0
root.Parent = gui

local UI = require(RS:WaitForChild("UIKit"))
local C, F, new = UI.C, UI.F, UI.new
local function tw(inst, t, goal, style, dir)
	local x = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), goal)
	x:Play()
	return x
end

-- sizes from the real screen height (everything below is in "vh" so it looks the same on a phone and a 1440p monitor)
local vh = 1080
for _ = 1, 30 do
	if root.AbsoluteSize.Y > 0 then vh = root.AbsoluteSize.Y break end
	task.wait()
end
local function px(v) return math.max(1, math.floor(v * vh / 1080 + 0.5)) end
local MARGIN = px(64)

-- ===== the map picture (full screen, Crop keeps it filling any aspect ratio) =====
local artHolder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 1 }, root)
local art = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), -- v5.13: exactly the screen
	BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.995, Image = "", ZIndex = 1 }, artHolder) -- (0.995, not 1: a fully transparent label may skip loading its picture)
-- shade so the white text reads on a light watercolour: soft dark wash from the bottom + a little from the right
local shadeB = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.52),
	BackgroundColor3 = Color3.fromRGB(8, 9, 13), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 2 }, root)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.55), NumberSequenceKeypoint.new(1, 0.08) }) }, shadeB)
local shadeR = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.55, 1),
	BackgroundColor3 = Color3.fromRGB(8, 9, 13), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 2 }, root)
new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.45) }) }, shadeR)
local shadeT = new("Frame", { Size = UDim2.fromScale(1, 0.2), BackgroundColor3 = Color3.fromRGB(8, 9, 13), BorderSizePixel = 0,
	BackgroundTransparency = 1, ZIndex = 2 }, root)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.35, 1) }, shadeT)

-- ===== small logo, top left =====
local logoSize = math.clamp(px(30), 18, 44)
local logo, logoApi = UI.Logo(root, logoSize, { Position = UDim2.fromOffset(MARGIN, MARGIN - px(10)), ZIndex = 5 }, "left")
logoApi.setTransparency(1)
task.spawn(function()
	local t0 = os.clock()
	while gui.Parent and os.clock() - t0 < 0.6 do
		logoApi.setTransparency(1 - math.clamp((os.clock() - t0) / 0.6, 0, 1))
		task.wait()
	end
	if gui.Parent then logoApi.setTransparency(0) end
end)

-- ===== bottom right: mode line + MAP NAME + red slash =====
local nameBox = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -MARGIN, 1, -px(70)), Size = UDim2.fromOffset(px(1100), px(200)),
	BackgroundTransparency = 1, ZIndex = 5 }, root)
local nameShift = new("UIPadding", {}, nameBox) -- slides the block in / out
local nameLbl = new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -px(18)), Size = UDim2.new(1, 0, 0, px(138)),
	BackgroundTransparency = 1, Text = "", TextScaled = true, FontFace = F.H, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Right,
	TextYAlignment = Enum.TextYAlignment.Bottom, TextTransparency = 1, ZIndex = 6 }, nameBox)
new("UITextSizeConstraint", { MaxTextSize = px(138), MinTextSize = 14 }, nameLbl)
local nameStroke = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = px(2), Transparency = 1 }, nameLbl)
local slash = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(0, px(4)),
	BackgroundColor3 = C.red, BorderSizePixel = 0, ZIndex = 6 }, nameBox)
local modeLbl = new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -px(160)), Size = UDim2.new(1, 0, 0, px(24)),
	BackgroundTransparency = 1, Text = "", TextSize = px(20), FontFace = F.MB, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Right,
	TextTransparency = 1, ZIndex = 6 }, nameBox)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.6 }, modeLbl)
local modeTick = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 1, -px(172)), Size = UDim2.fromOffset(px(26), px(3)),
	BackgroundColor3 = C.red, BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 6 }, nameBox)

-- ===== bottom: status + percent (left), progress line along the bottom edge =====
local statusLbl = new("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, MARGIN, 1, -px(70)), Size = UDim2.fromOffset(px(760), px(30)),
	BackgroundTransparency = 1, Text = "LOADING", TextSize = px(22), FontFace = F.M, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6 }, root)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.6 }, statusLbl)
local pctLbl = new("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, MARGIN, 1, -px(104)), Size = UDim2.fromOffset(px(300), px(44)),
	BackgroundTransparency = 1, Text = "0%", TextSize = px(40), FontFace = F.HM, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6 }, root)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.55 }, pctLbl)
local barH = math.max(3, px(5))
local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, barH),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 7 }, root)
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.red, BorderSizePixel = 0, ZIndex = 8 }, bar)
local glint = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, px(60), 1, px(2)),
	BackgroundColor3 = C.redHi, BorderSizePixel = 0, ZIndex = 9 }, fill)
new("UIGradient", { Transparency = NumberSequence.new(1, 0) }, glint)

local status, dots, progress = "LOADING", true, 0
local shown = 0
-- v5.13: no drift / zoom any more - the picture stands still (Crop already keeps it filling any screen shape with no empty space)
task.spawn(function() -- animated dots + smooth progress
	local n, acc = 0, 0
	while gui.Parent do
		local dt = task.wait()
		acc += dt
		if acc >= 0.35 then acc = 0; n = (n + 1) % 4 end
		statusLbl.Text = status .. (dots and string.rep(".", n) or "")
		shown += (progress - shown) * math.min(1, dt * 5)
		local s = math.clamp(shown, 0, 1)
		fill.Size = UDim2.fromScale(s, 1)
		pctLbl.Text = tostring(math.floor(s * 100 + 0.5)) .. "%"
	end
end)

local function setStatus(text, withDots, quiet)
	if status == text then return end
	status, dots = text, withDots ~= false
	if quiet then return end -- a ticking countdown: no fade each second
	statusLbl.TextTransparency = 1
	tw(statusLbl, 0.25, { TextTransparency = 0 })
end

-- ===== map name + picture (as soon as MatchState is here) =====
local mapShown, artShown = false, false
local function showMap(State)
	local mode = tostring(State:GetAttribute("Mode") or "")
	local name = string.upper(tostring(State:GetAttribute("MapName") or ""))
	if not mapShown and name ~= "" then
		mapShown = true
		nameLbl.Text = name
		modeLbl.Text = (mode == "1v1" and "1V1  //  DUEL" or "BREAKLINE  //  3V3") .. "      "
		nameShift.PaddingRight = UDim.new(0, -px(60))
		tw(nameShift, 0.9, { PaddingRight = UDim.new(0, 0) })
		tw(nameLbl, 0.7, { TextTransparency = 0 })
		tw(nameStroke, 0.7, { Transparency = 0.55 })
		task.delay(0.25, function()
			tw(modeLbl, 0.5, { TextTransparency = 0.1 })
			tw(modeTick, 0.5, { BackgroundTransparency = 0 })
			tw(slash, 0.8, { Size = UDim2.fromOffset(math.min(px(1100), math.max(px(260), nameLbl.TextBounds.X * 0.9)), px(4)) })
		end)
	end
	local img = tostring(State:GetAttribute("MapImage") or "")
	if not artShown and img ~= "" then
		artShown = true
		task.spawn(function()
			-- v5.10: load it for real (direct asset first, then the thumbnail link) instead of trusting that setting .Image is enough
			local src = UI.LoadImage(art, img, 5)
			if not gui.Parent then return end
			if not src then
				warn("[Breakline] the map loading picture (" .. img .. ") could not be loaded. Check the id is an IMAGE id (not a Decal id) and that this experience may use it.")
				return
			end
			player:SetAttribute("MapImageSrc", src) -- the Warp reuses the link that worked
			tw(art, 1.2, { ImageTransparency = 0 }, Enum.EasingStyle.Quad)
			tw(shadeB, 1.2, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
			tw(shadeR, 1.2, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
			tw(shadeT, 1.2, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
		end)
	end
end

local finishing = false
local function finish()
	if finishing then return end
	finishing = true
	if not gui.Parent then return end
	tw(statusLbl, 0.3, { TextTransparency = 1 })
	tw(pctLbl, 0.3, { TextTransparency = 1 })
	tw(nameShift, 0.6, { PaddingRight = UDim.new(0, -px(80)) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	tw(nameLbl, 0.5, { TextTransparency = 1 })
	tw(modeLbl, 0.4, { TextTransparency = 1 })
	task.wait(0.25)
	tw(root, 0.55, { GroupTransparency = 1 }, Enum.EasingStyle.Quad)
	task.wait(0.6)
	pcall(function() logoApi.stop() end)
	gui:Destroy()
end

-- v5.15 WATCHDOG: whatever happens below (an error, a remote that never shows up), the screen can never stay over a running match.
-- It closes the screen FAILSAFE seconds after the phase has left Waiting, once the screen has been up MIN_SHOW seconds.
task.spawn(function()
	local State = RS:WaitForChild("MatchState", 60)
	local leftAt = nil
	while gui.Parent and not finishing do
		local phase = State and State:GetAttribute("Phase")
		if State == nil or (phase ~= nil and phase ~= "Waiting") then
			leftAt = leftAt or os.clock()
			if os.clock() - leftAt >= FAILSAFE and os.clock() - shownAt >= MIN_SHOW then
				warn("[Breakline] LoadingScreen watchdog closed the loading screen (phase: " .. tostring(phase) .. ")")
				finish()
				return
			end
		else
			leftAt = nil
		end
		task.wait(0.25)
	end
end)

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
showMap(State)
local c1 = State:GetAttributeChangedSignal("MapName"):Connect(function() showMap(State) end)
local c2 = State:GetAttributeChangedSignal("MapImage"):Connect(function() showMap(State) end)
gui.Destroying:Connect(function() c1:Disconnect() c2:Disconnect() end)

-- ===== 2) preload the map (max 10 s) =====
setStatus("LOADING MAP")
progress = 0.3
do
	local done = false
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ workspace }) end)
		done = true
	end)
	local w0 = os.clock()
	while not done and os.clock() - w0 < 10 do
		progress = 0.3 + 0.4 * math.clamp((os.clock() - w0) / 10, 0, 1)
		task.wait(0.1)
	end
end

-- ===== 3) wait for our character (max 8 s), then tell the server we are ready =====
setStatus("LOADING PLAYER")
progress = 0.75
do
	local w0 = os.clock()
	while not player.Character and os.clock() - w0 < 8 do task.wait(0.1) end
end
do
	local readyRemote = Remotes:WaitForChild("ClientReady", 30) -- v5.15: time limit (it used to wait forever)
	if readyRemote then readyRemote:FireServer() else warn("[Breakline] MatchRemotes.ClientReady not found - the server will start after its READY_TIMEOUT") end
end
progress = 0.85

-- ===== 4) show what the server is waiting for until the match starts =====
-- v5.8: the picture stays up at least MIN_SHOW seconds, so a fast load still shows the map instead of flashing it
-- (MIN_SHOW + shownAt are set at the top of the script.) v5.15: the loop runs in pcall, so an error can no longer leave the screen up.
local okLoop, loopErr = pcall(function()
while true do
	local phase = State:GetAttribute("Phase")
	if phase ~= "Waiting" and os.clock() - shownAt >= MIN_SHOW then break end
	local expected = State:GetAttribute("Expected") or 0
	local ready = State:GetAttribute("Ready") or 0
	local holdEnds = State:GetAttribute("LoadHoldEnds") or 0
	if holdEnds > 0 and phase == "Waiting" then
		setStatus(("ALL PLAYERS LOADED   //   MATCH STARTS IN %d"):format(math.max(0, math.ceil(holdEnds - workspace:GetServerTimeNow()))), false, true)
		progress = 1
	elseif State:GetAttribute("AllReady") or phase ~= "Waiting" then
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
end)
if not okLoop then
	warn("[Breakline] LoadingScreen wait loop error: " .. tostring(loopErr))
	-- keep the picture up (no live status) until the match really moves on, then close as normal
	while gui.Parent and not finishing and (State:GetAttribute("Phase") == "Waiting" or os.clock() - shownAt < MIN_SHOW) do task.wait(0.1) end
end
setStatus("ALL PLAYERS LOADED", false)
progress = 1
task.wait(0.35)
finish()
