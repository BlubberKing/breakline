-- CardEffectsClient (LOBBY copy, NEW in v5.17: the TRAINING ZONE) - the same file as Breakline's (SCOUT'S EYE works in the zone; GRAVE CANDLE needs souls, which only exist in a match).
-- CardEffectsClient v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. NEW in v5.14 (GDD 4.4).
-- The two power-up cards that only change what YOU see (numbers in ReplicatedStorage.CardEffects):
--   GRAVE CANDLE - every soul of a fallen TEAMMATE (workspace.Souls, parts with TeamName = your team) gets a warm candle-light glow that shows
--                  through walls (a small glowing ball + a Highlight drawn on top of everything) and a little flame + distance tag at any range.
--   SCOUT'S EYE  - an enemy you hit (GunRemotes.HitConfirm: guns, and gadgets through GadgetServer) is outlined in red through walls for 2 s;
--                  every new hit restarts the 2 s.
-- Only your own match card counts (Player attribute MatchCard). Nothing here is sent to the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local CardFx = require(RS:WaitForChild("CardEffects"))

-- ================= SCOUT'S EYE =================
local marked = {} -- model -> { hl, untilT }
local function markEnemy(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model:FindFirstChildOfClass("Humanoid") then return end
	local m = marked[model]
	if not m or not m.hl.Parent then
		local hl = Instance.new("Highlight")
		hl.Name = "ScoutsEyeMark"
		hl.Adornee = model
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillColor = CardFx.SCOUTS_EYE_COLOR
		hl.FillTransparency = 0.78
		hl.OutlineColor = CardFx.SCOUTS_EYE_COLOR
		hl.OutlineTransparency = 0
		hl.Parent = model
		m = { hl = hl }
		marked[model] = m
	end
	m.untilT = os.clock() + CardFx.SCOUTS_EYE_TIME
end

task.spawn(function()
	local remotes = RS:WaitForChild("GunRemotes", 60)
	local hc = remotes and remotes:WaitForChild("HitConfirm", 30)
	if not hc then return end
	hc.OnClientEvent:Connect(function(model)
		if not CardFx.Has(player, "scouts_eye") then return end
		markEnemy(model)
	end)
end)

-- ================= GRAVE CANDLE =================
local candles = {} -- soul part -> { ball, hl, bb, dist }
local function removeCandle(part)
	local c = candles[part]
	if not c then return end
	candles[part] = nil
	if c.ball then c.ball:Destroy() end
end
local function wantsCandle(part)
	if not CardFx.Has(player, "grave_candle") then return false end
	if not part:IsA("BasePart") or part.Name ~= "Soul" then return false end
	if part:GetAttribute("OwnerId") == player.UserId then return false end
	local team = player.Team
	return team ~= nil and part:GetAttribute("TeamName") == team.Name
end
local function addCandle(part)
	if candles[part] or not wantsCandle(part) then return end
	local col = CardFx.GRAVE_CANDLE_COLOR
	local ball = Instance.new("Part")
	ball.Name = "GraveCandle"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 1.1
	ball.Material = Enum.Material.Neon
	ball.Color = col
	ball.Transparency = 0.35
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = true, false, false, false, false
	ball.CFrame = part.CFrame
	local hl = Instance.new("Highlight")
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillColor, hl.FillTransparency = col, 0.25
	hl.OutlineColor, hl.OutlineTransparency = Color3.new(1, 1, 1), 0.2
	hl.Adornee = ball
	hl.Parent = ball
	local bb = Instance.new("BillboardGui")
	bb.Name = "CandleTag"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = math.huge
	bb.Size = UDim2.fromOffset(90, 54)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.Adornee = ball
	bb.Parent = ball
	-- a small flame: teardrop (rounded square turned 45 degrees) with a bright core
	local flame = Instance.new("Frame")
	flame.AnchorPoint = Vector2.new(0.5, 0.5)
	flame.Position = UDim2.fromOffset(45, 14)
	flame.Size = UDim2.fromOffset(14, 14)
	flame.Rotation = 45
	flame.BackgroundColor3 = col
	flame.BorderSizePixel = 0
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.5, 0)
	fc.Parent = flame
	flame.Parent = bb
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromOffset(6, 6)
	core.BackgroundColor3 = Color3.new(1, 1, 1)
	core.BorderSizePixel = 0
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = core
	core.Parent = flame
	local dist = Instance.new("TextLabel")
	dist.BackgroundTransparency = 1
	dist.Position = UDim2.fromOffset(0, 26)
	dist.Size = UDim2.fromOffset(90, 22)
	dist.Font = Enum.Font.GothamBlack
	dist.TextSize = 14
	dist.TextColor3 = col
	dist.TextStrokeTransparency = 0.3
	dist.Text = ""
	dist.Parent = bb
	ball.Parent = workspace.CurrentCamera -- local only, never in the server's world
	candles[part] = { ball = ball, dist = dist }
end
local function rescanCandles()
	local folder = workspace:FindFirstChild("Souls")
	for part in candles do
		if not part.Parent or not wantsCandle(part) then removeCandle(part) end
	end
	if folder then for _, p in folder:GetChildren() do addCandle(p) end end
end

task.spawn(function()
	local folder = workspace:WaitForChild("Souls", 120)
	if not folder then return end
	folder.ChildAdded:Connect(function(p)
		task.wait() -- let its attributes arrive
		addCandle(p)
	end)
	folder.ChildRemoved:Connect(removeCandle)
	rescanCandles()
end)
player:GetAttributeChangedSignal("MatchCard"):Connect(function()
	rescanCandles()
	if not CardFx.Has(player, "scouts_eye") then
		for model, m in marked do if m.hl then m.hl:Destroy() end marked[model] = nil end
	end
end)
player:GetPropertyChangedSignal("Team"):Connect(rescanCandles)

-- ================= per frame =================
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	-- candles follow their soul (it can be carried / thrown) and show the distance
	local cam = workspace.CurrentCamera
	local t = os.clock()
	for part, c in candles do
		if not part.Parent then
			removeCandle(part)
		else
			c.ball.CFrame = part.CFrame
			c.ball.Transparency = 0.35 + math.sin(t * 5) * 0.1 -- a soft candle flicker
		end
	end
	acc += dt
	if acc < 0.2 then return end
	acc = 0
	for part, c in candles do
		if cam and part.Parent then c.dist.Text = ("%dm"):format(math.floor((cam.CFrame.Position - part.Position).Magnitude / 3.57 + 0.5)) end
	end
	-- scout's eye timers
	for model, m in marked do
		if t > (m.untilT or 0) or not model.Parent then
			if m.hl then m.hl:Destroy() end
			marked[model] = nil
		end
	end
end)
