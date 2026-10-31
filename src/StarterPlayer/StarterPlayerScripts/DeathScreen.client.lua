-- DeathScreen v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. NEW in v4.1.
-- What you see while you are dead (DeathServer sets the Player attributes IsDead, DeathEnds, DeathTotal, DeathMode):
--   * you SPECTATE a living teammate (first person through their eyes). LEFT / RIGHT click, or A / D, or the arrow keys switch teammate.
--     In a 1v1 there are no teammates, so you watch your opponent.
--   * TEAM WIPE (DeathMode = "roam": nobody is left to spectate; every dead player on the team is set to 10 s): you FREE ROAM the map.
--     W A S D to fly in the direction you look, SPACE up, C / Ctrl down, SHIFT faster. You cannot fly through walls: the camera is a small sphere
--     that slides along anything solid, and it is kept inside MapBounds (the invisible boundary walls cannot be hit by a ray, so MapBounds is used).
--     If you are spectating and your LAST teammate dies, you drop straight into free roam (the timer is already reset to 10 s by the server).
--   * the BAR along the bottom of the screen: one solid colour (your team's, darkened), not tall:
--         LEFT   a big countdown number (seconds until you respawn)
--         MIDDLE the name of who you are spectating, or FREE ROAM (or "REVIVED BY <name>  54%" while a teammate revives you)
--         BOTTOM EDGE a thin line that shrinks from full width to nothing as the timer runs out
-- The camera is released when the death ends: RespawnReveal takes over for the respawn animation.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CS = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local C = require(RS:WaitForChild("MatchConfig"))
local MatchState = RS:WaitForChild("MatchState")

local rad, clamp, sin = math.rad, math.clamp, math.sin
local BIND = "BreaklineDeathCam"
local TEAM_COLORS = { [C.Teams[1].Name] = C.Teams[1].Color.Color, [C.Teams[2].Name] = C.Teams[2].Color.Color }

------------------------------------------------------------------ GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DeathScreen"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 60
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local BAR_H = 78
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0, 1)
bar.Position = UDim2.fromScale(0, 1)
bar.Size = UDim2.new(1, 0, 0, BAR_H)
bar.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
bar.BorderSizePixel = 0
bar.Parent = gui

local FONT = Enum.Font.GothamBlack
local timerLbl = Instance.new("TextLabel")
timerLbl.BackgroundTransparency = 1
timerLbl.Position = UDim2.fromOffset(34, 0)
timerLbl.Size = UDim2.fromOffset(150, BAR_H - 6)
timerLbl.Font = FONT
timerLbl.TextSize = 62
timerLbl.TextXAlignment = Enum.TextXAlignment.Left
timerLbl.TextColor3 = Color3.new(1, 1, 1)
timerLbl.Text = "15"
timerLbl.Parent = bar
local timerCap = Instance.new("TextLabel")
timerCap.BackgroundTransparency = 1
timerCap.Position = UDim2.fromOffset(112, 16)
timerCap.Size = UDim2.fromOffset(120, 20)
timerCap.Font = Enum.Font.GothamBold
timerCap.TextSize = 13
timerCap.TextXAlignment = Enum.TextXAlignment.Left
timerCap.TextColor3 = Color3.fromRGB(255, 255, 255)
timerCap.TextTransparency = 0.25
timerCap.Text = "RESPAWN IN"
timerCap.Parent = bar

local nameCap = Instance.new("TextLabel")
nameCap.AnchorPoint = Vector2.new(0.5, 0)
nameCap.BackgroundTransparency = 1
nameCap.Position = UDim2.new(0.5, 0, 0, 10)
nameCap.Size = UDim2.fromOffset(700, 16)
nameCap.Font = Enum.Font.GothamBold
nameCap.TextSize = 13
nameCap.TextColor3 = Color3.new(1, 1, 1)
nameCap.TextTransparency = 0.25
nameCap.Text = "SPECTATING"
nameCap.Parent = bar
local nameLbl = Instance.new("TextLabel")
nameLbl.AnchorPoint = Vector2.new(0.5, 0)
nameLbl.BackgroundTransparency = 1
nameLbl.Position = UDim2.new(0.5, 0, 0, 24)
nameLbl.Size = UDim2.fromOffset(700, 40)
nameLbl.Font = FONT
nameLbl.TextSize = 32
nameLbl.TextColor3 = Color3.new(1, 1, 1)
nameLbl.Text = ""
nameLbl.Parent = bar
local hintLbl = Instance.new("TextLabel")
hintLbl.AnchorPoint = Vector2.new(1, 0)
hintLbl.BackgroundTransparency = 1
hintLbl.Position = UDim2.new(1, -34, 0, 14)
hintLbl.Size = UDim2.fromOffset(420, 40)
hintLbl.Font = Enum.Font.GothamBold
hintLbl.TextSize = 13
hintLbl.TextXAlignment = Enum.TextXAlignment.Right
hintLbl.TextColor3 = Color3.new(1, 1, 1)
hintLbl.TextTransparency = 0.2
hintLbl.Text = ""
hintLbl.Parent = bar

-- the descending line at the very bottom
local lineBack = Instance.new("Frame")
lineBack.AnchorPoint = Vector2.new(0, 1)
lineBack.Position = UDim2.fromScale(0, 1)
lineBack.Size = UDim2.new(1, 0, 0, 6)
lineBack.BackgroundColor3 = Color3.new(0, 0, 0)
lineBack.BackgroundTransparency = 0.6
lineBack.BorderSizePixel = 0
lineBack.Parent = bar
local line = Instance.new("Frame")
line.Size = UDim2.fromScale(1, 1)
line.BackgroundColor3 = Color3.new(1, 1, 1)
line.BorderSizePixel = 0
line.Parent = lineBack

-- thin dark top / bottom shading so the bar sits on the picture
local shade = Instance.new("Frame")
shade.AnchorPoint = Vector2.new(0, 1)
shade.Position = UDim2.new(0, 0, 1, -BAR_H)
shade.Size = UDim2.new(1, 0, 0, 90)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.5
shade.BorderSizePixel = 0
shade.Parent = gui
do
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	g.Parent = shade
end

------------------------------------------------------------------ state
local active = false
local target -- spectated Player (or nil = free roam)
local roam = { pos = Vector3.zero, yaw = 0, pitch = 0, fresh = true }
local lastTargetPos
local camPos, camYaw, camPitch = nil, 0, 0
local switchCooldown = 0
local deathChar -- the body we died in (for the starting camera)

local function myTeamName() return player.Team and player.Team.Name or nil end
local function isAlivePlayer(p)
	if p == player or p:GetAttribute("IsDead") == true then return false end
	local c = p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and c:FindFirstChild("Head") ~= nil
end

local function candidates()
	local list = {}
	local mode = MatchState:GetAttribute("Mode")
	local mine = myTeamName()
	for _, p in Players:GetPlayers() do
		if isAlivePlayer(p) then
			local same = p.Team ~= nil and p.Team.Name == mine
			if same or (mode == "1v1" and p.Team ~= nil and p.Team.Name ~= "Lobby") then table.insert(list, p) end
		end
	end
	table.sort(list, function(a, b) return a.UserId < b.UserId end)
	return list
end

local function cycle(dir)
	local list = candidates()
	if #list == 0 then target = nil return end
	local i = target and table.find(list, target) or 0
	i = ((i - 1 + dir) % #list) + 1
	target = list[i]
end

local function bounds()
	local b = workspace:FindFirstChild("MapBounds")
	if b and b:IsA("BasePart") then return b.CFrame, b.Size end
	return nil
end

------------------------------------------------------------------ free roam
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
local function refreshFilter()
	local ig = { camera }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ig, p.Character) end end
	for _, n in { "ClientFX", "RevealFX", "SoulFX", "GadgetFX", "Souls", "WarpFX" } do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ig, f) end
	end
	rayParams.FilterDescendantsInstances = ig
end

-- move the roaming camera by `delta`, sliding along walls (a sphere cast, so you cannot squeeze through a wall) and staying inside MapBounds
local RADIUS = 1.4
local function moveRoam(from, delta)
	local pos = from
	for _ = 1, 3 do
		if delta.Magnitude < 1e-3 then break end
		local hit = workspace:Spherecast(pos, RADIUS, delta, rayParams)
		if not hit then pos += delta delta = Vector3.zero break end
		local travel = math.max(hit.Distance - 0.05, 0)
		pos += delta.Unit * travel
		local rest = delta - delta.Unit * travel
		delta = rest - hit.Normal * rest:Dot(hit.Normal) -- slide along the surface
	end
	pos += delta
	local bcf, bsize = bounds()
	if bcf then
		local lp = bcf:PointToObjectSpace(pos)
		local half = bsize / 2 - Vector3.one * 2
		lp = Vector3.new(clamp(lp.X, -half.X, half.X), clamp(lp.Y, -half.Y + 1, half.Y), clamp(lp.Z, -half.Z, half.Z))
		pos = bcf:PointToWorldSpace(lp)
	end
	return pos
end

local function lookVec(yaw, pitch)
	return (CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)).LookVector
end

------------------------------------------------------------------ camera
local function camStep(dt)
	if not active then return end
	dt = math.min(dt, 0.1)
	local mode = player:GetAttribute("DeathMode")
	-- mouse look
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
	UIS.MouseIconEnabled = false
	local md = UIS:GetMouseDelta()
	roam.yaw -= md.X * 0.0034
	roam.pitch = clamp(roam.pitch - md.Y * 0.0034, rad(-85), rad(85))

	if mode == "roam" then target = nil end
	if target and not isAlivePlayer(target) then
		target = nil
		cycle(1)
		if not target then roam.fresh = true end
	end
	if not target and mode ~= "roam" then cycle(1) end

	if target then
		local char = target.Character
		local head = char and char:FindFirstChild("Head")
		if head then
			-- first person through their eyes: their head carries the aim pitch (neck joint), so its look vector is where they are looking
			local lv = head.CFrame.LookVector
			local pos = head.Position + Vector3.new(0, 0.1, 0) + lv * 0.5
			camPos = camPos and camPos:Lerp(pos, 1 - math.exp(-dt * 30)) or pos
			local want = CFrame.lookAt(camPos, camPos + lv)
			camera.CFrame = camera.CFrame:Lerp(want, 1 - math.exp(-dt * 24))
			camera.FieldOfView = 78
			lastTargetPos = head.Position
			roam.pos = camPos
			local px, py = camera.CFrame:ToEulerAnglesYXZ()
			roam.yaw, roam.pitch = py, px
			-- their head would fill the screen: hide it (and anything worn on it) for us
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") and (d.Name == "Head" or d:FindFirstAncestorOfClass("Accessory")) then d.LocalTransparencyModifier = 1 end
			end
		end
	else
		if roam.fresh then
			roam.fresh = false
			local startPos = (lastTargetPos and lastTargetPos + Vector3.new(0, 3, 0)) or camera.CFrame.Position
			roam.pos = camPos or startPos
			local px, py = camera.CFrame:ToEulerAnglesYXZ()
			roam.yaw, roam.pitch = py, px
		end
		local look = lookVec(roam.yaw, roam.pitch)
		local right = look:Cross(Vector3.yAxis)
		if right.Magnitude < 0.01 then right = Vector3.xAxis end
		right = right.Unit
		local d = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then d += look end
		if UIS:IsKeyDown(Enum.KeyCode.S) then d -= look end
		if UIS:IsKeyDown(Enum.KeyCode.D) then d += right end
		if UIS:IsKeyDown(Enum.KeyCode.A) then d -= right end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.C) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d -= Vector3.yAxis end
		local speed = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 90 or 38
		if d.Magnitude > 0.01 then roam.pos = moveRoam(roam.pos, d.Unit * speed * dt) end
		camPos = roam.pos
		camera.CFrame = CFrame.lookAt(roam.pos, roam.pos + look)
		camera.FieldOfView = 75
	end
end

------------------------------------------------------------------ switching with the mouse / keys
UIS.InputBegan:Connect(function(input, gpe)
	if not active or gpe then return end
	if os.clock() < switchCooldown then return end
	local mode = player:GetAttribute("DeathMode")
	if mode == "roam" then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		switchCooldown = os.clock() + 0.15
		cycle(1)
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		switchCooldown = os.clock() + 0.15
		cycle(-1)
	end
end)

------------------------------------------------------------------ bar update
local function whoRevivesMe()
	for _, part in CS:GetTagged("Soul") do
		if part:GetAttribute("OwnerId") == player.UserId and part:GetAttribute("RezBy") then
			local by = Players:GetPlayerByUserId(part:GetAttribute("RezBy"))
			local start = part:GetAttribute("RezStart") or 0
			local total = part:GetAttribute("RezTime") or C.REZ_TIME
			return by, clamp((workspace:GetServerTimeNow() - start) / total, 0, 1)
		end
	end
end

local lastSec
RunService.RenderStepped:Connect(function(dt)
	local dead = player:GetAttribute("IsDead") == true
	if dead and not active then
		active = true
		target, camPos, lastTargetPos = nil, nil, nil
		roam.fresh = true
		refreshFilter()
		camera.CameraType = Enum.CameraType.Scriptable
		gui.Enabled = true
		pcall(function() RunService:UnbindFromRenderStep(BIND) end)
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 4, camStep)
		-- start from where you died, looking where you were looking
		roam.pos = camera.CFrame.Position
		lastSec = nil
	elseif not dead and active then
		active = false
		gui.Enabled = false
		pcall(function() RunService:UnbindFromRenderStep(BIND) end)
		target = nil
		-- RespawnReveal takes the camera when the new body appears. If that never happens (round ended), hand it back.
		task.delay(3, function()
			if active or player:GetAttribute("IsDead") == true then return end
			local c = player.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if camera.CameraType == Enum.CameraType.Scriptable and h and h.Health > 0 and c:GetAttribute("Revealing") ~= true
				and MatchState:GetAttribute("Phase") ~= "Warp" and MatchState:GetAttribute("Phase") ~= "Result" and MatchState:GetAttribute("Phase") ~= "Summary" then
				camera.CameraType = Enum.CameraType.Custom
				camera.CameraSubject = h
			end
		end)
	end
	if not active then return end
	if os.clock() % 0.5 < dt then refreshFilter() end

	local now = workspace:GetServerTimeNow()
	local ends = player:GetAttribute("DeathEnds") or now
	local total = math.max(player:GetAttribute("DeathTotal") or 15, 0.1)
	local left = math.max(ends - now, 0)
	local sec = math.ceil(left)
	if sec ~= lastSec then
		lastSec = sec
		timerLbl.Text = tostring(sec)
		TweenService:Create(timerLbl, TweenInfo.new(0.0), { TextSize = 70 }):Play()
		TweenService:Create(timerLbl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextSize = 62 }):Play()
	end
	line.Size = UDim2.fromScale(clamp(left / total, 0, 1), 1)
	-- team colour, darkened so white text stays readable
	local col = TEAM_COLORS[myTeamName() or ""] or Color3.fromRGB(70, 74, 86)
	local barCol = col:Lerp(Color3.new(0, 0, 0), 0.5)
	bar.BackgroundColor3 = barCol
	line.BackgroundColor3 = col:Lerp(Color3.new(1, 1, 1), 0.55)

	local mode = player:GetAttribute("DeathMode")
	local by, f = whoRevivesMe()
	if by then
		nameCap.Text = "BEING REVIVED BY"
		nameLbl.Text = ("%s   %d%%"):format(string.upper(by.DisplayName ~= "" and by.DisplayName or by.Name), math.floor(f * 100))
		hintLbl.Text = ""
	elseif mode == "roam" or not target then
		nameCap.Text = (MatchState:GetAttribute("Mode") == "1v1") and "NOBODY TO WATCH" or "YOUR TEAM IS DOWN"
		nameLbl.Text = "FREE ROAM"
		hintLbl.Text = "WASD  MOVE      SPACE / C  UP / DOWN      SHIFT  FAST"
	else
		nameCap.Text = "SPECTATING"
		nameLbl.Text = string.upper(target.DisplayName ~= "" and target.DisplayName or target.Name)
		local n = #candidates()
		hintLbl.Text = n > 1 and "CLICK  /  A D   SWITCH PLAYER" or ""
	end
	timerCap.Text = mode == "roam" and "TEAM WIPE" or "RESPAWN IN"
end)
