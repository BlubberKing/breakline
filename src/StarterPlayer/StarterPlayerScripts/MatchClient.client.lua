-- MatchClient v2: Wall Push HUD + box controls + box visuals.
--  * top bar: phase / countdown, box counts per team, wall progress bar (finish line to finish line)
--  * carrying a box: LEFT CLICK (or the Throw button on mobile) = throw, Q = drop. Guns are locked by GunClient/GunServer.
--  * hides pick-up prompts you can't use (your own plugged boxes, anything while you carry)
--  * animates the faces of every box (BoxModel) and shows YOUR carried box as a small two-handed first-person model
--  * cleans up any leftover first-person gun model when you respawn / get teleported
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local BoxModel = require(RS:WaitForChild("BoxModel"))
local BoxFX = require(RS:WaitForChild("BoxFX"))
local DeathFX = require(RS:WaitForChild("DeathFX"))
local Sfx = require(RS:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local C = require(RS:WaitForChild("MatchConfig"))
local State = RS:WaitForChild("MatchState")
local Remotes = RS:WaitForChild("MatchRemotes")
local ThrowRemote, DropRemote, NotifyRemote = Remotes:WaitForChild("Throw"), Remotes:WaitForChild("Drop"), Remotes:WaitForChild("Notify")

local ACCENT = Color3.fromRGB(255, 140, 30)
local COL_A, COL_B = C.Teams[1].Color.Color, C.Teams[2].Color.Color
local TEAM_COLORS = { [C.Teams[1].Name] = COL_A, [C.Teams[2].Name] = COL_B }
local NAME_A, NAME_B = C.Teams[1].Name, C.Teams[2].Name

-- ================= GUI =================
local gui = Instance.new("ScreenGui")
gui.Name = "MatchHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, size, pos, text, ts, color)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size, l.Position = size, pos
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextSize = ts
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	local st = Instance.new("UIStroke")
	st.Thickness = 2; st.Transparency = 0.3
	st.Parent = l
	l.Parent = parent
	return l
end

local top = Instance.new("Frame")
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 10)
top.Size = UDim2.fromOffset(460, 76)
top.BackgroundTransparency = 1
top.Parent = gui

local scoreA = label(top, UDim2.fromOffset(110, 36), UDim2.fromOffset(60, 20), "0", 30, COL_A)
local scoreB = label(top, UDim2.fromOffset(110, 36), UDim2.fromOffset(400, 20), "0", 30, COL_B)
local timerLabel = label(top, UDim2.fromOffset(200, 36), UDim2.fromOffset(230, 20), "", 22)
local nameA = label(top, UDim2.fromOffset(110, 16), UDim2.fromOffset(60, 44), NAME_A:upper() .. " BOXES", 11, COL_A)
local nameB = label(top, UDim2.fromOffset(110, 16), UDim2.fromOffset(400, 44), NAME_B:upper() .. " BOXES", 11, COL_B)

-- wall progress: bar spans finish line (team A end, left) to finish line (team B end, right); the marker is the wall
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.fromOffset(230, 58)
bar.Size = UDim2.fromOffset(440, 10)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
bar.BackgroundTransparency = 0.2
bar.BorderSizePixel = 0
bar.Parent = top
local halfA = Instance.new("Frame")
halfA.Size = UDim2.fromScale(0.5, 1)
halfA.BackgroundColor3 = COL_A
halfA.BackgroundTransparency = 0.45
halfA.BorderSizePixel = 0
halfA.Parent = bar
local halfB = halfA:Clone()
halfB.Position = UDim2.fromScale(0.5, 0)
halfB.BackgroundColor3 = COL_B
halfB.Parent = bar
local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Size = UDim2.new(0, 6, 1, 10)
marker.Position = UDim2.fromScale(0.5, 0.5)
marker.BackgroundColor3 = Color3.new(1, 1, 1)
marker.BorderSizePixel = 0
marker.Parent = bar

local banner = label(gui, UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0.22, 0), "", 40)
banner.TextTransparency = 1
local bannerStroke = banner:FindFirstChildOfClass("UIStroke")
bannerStroke.Transparency = 1
local bannerToken = 0
local function showBanner(text, color, hold)
	bannerToken += 1
	local t = bannerToken
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency, bannerStroke.Transparency = 0, 0.3
	task.delay(hold or 1.8, function()
		if bannerToken ~= t then return end
		TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(bannerStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
end

local hint = label(gui, UDim2.fromOffset(600, 30), UDim2.new(0.5, 0, 0.78, 0), "", 18)
hint.Visible = false

-- ================= HUD update =================
local lastPhase, lastTick
local function teamColor()
	return player.Team and player.Team.TeamColor.Color or ACCENT
end

local function refresh()
	local phase = State:GetAttribute("Phase")
	local ends = State:GetAttribute("PhaseEnds") or 0
	scoreA.Text = tostring(State:GetAttribute("BoxesA") or 0)
	scoreB.Text = tostring(State:GetAttribute("BoxesB") or 0)
	marker.Position = UDim2.fromScale(0.5 + 0.5 * (State:GetAttribute("WallFrac") or 0), 0.5)

	if phase == "Waiting" then
		timerLabel.Text = "WAITING FOR PLAYERS"
	elseif phase == "Intermission" then
		timerLabel.Text = ("STARTING IN %d"):format(math.max(0, math.ceil(ends - workspace:GetServerTimeNow())))
	elseif phase == "Playing" then
		local t = player.Team and player.Team.Name
		timerLabel.Text = t and t:upper() or "SPECTATING"
		timerLabel.TextColor3 = t and teamColor() or Color3.new(1, 1, 1)
	elseif phase == "Result" then
		local w = State:GetAttribute("Winner")
		timerLabel.Text = (w and w ~= "") and (w:upper() .. " WINS") or "ROUND OVER"
		timerLabel.TextColor3 = (w == NAME_A and COL_A) or (w == NAME_B and COL_B) or Color3.new(1, 1, 1)
	end
	if phase ~= "Playing" and phase ~= "Result" then timerLabel.TextColor3 = Color3.new(1, 1, 1) end

	-- countdown ticks (last 5 seconds of the intermission)
	if phase == "Intermission" then
		local left = math.ceil(ends - workspace:GetServerTimeNow())
		if left ~= lastTick and left >= 1 and left <= 5 then lastTick = left; Sfx.Play("Countdown") end
	end

	if phase ~= lastPhase then
		lastPhase = phase
		if phase == "Playing" then Sfx.Play("RoundStart")
		elseif phase == "Result" then
			local w, t = State:GetAttribute("Winner"), player.Team and player.Team.Name
			Sfx.Play((w == nil or w == "") and "RoundOver" or (w == t and "RoundWin" or "RoundLose"))
		end
		if phase == "Playing" then
			local t = player.Team
			showBanner(t and ("YOU ARE " .. t.Name:upper()) or "ROUND STARTED", t and t.TeamColor.Color or ACCENT, 2.5)
		end
	end
end

-- ================= box controls =================
local carrying = false
local throwKick = 0 -- first-person carry model thrusts forward when you throw
local function throw()
	if not carrying then return end
	throwKick = 1
	ThrowRemote:FireServer(camera.CFrame.LookVector)
end
local function drop()
	if carrying then DropRemote:FireServer() end
end

local THROW_ACTION = "WPThrow"
local function setCarrying(on)
	if on == carrying then return end
	carrying = on
	hint.Visible = on
	hint.Text = "LEFT CLICK  throw      Q  drop      walk into a hole on your side to plug it"
	if on then
		-- sink the click so Roblox/other scripts do not also use it
		CAS:BindActionAtPriority(THROW_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then throw() end
			return Enum.ContextActionResult.Sink
		end, true, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
		CAS:SetTitle(THROW_ACTION, "Throw")
		CAS:SetPosition(THROW_ACTION, UDim2.new(1, -95, 1, -245))
	else
		CAS:UnbindAction(THROW_ACTION)
	end
end
player:GetAttributeChangedSignal("Carrying"):Connect(function() setCarrying(player:GetAttribute("Carrying") == true) end)
setCarrying(player:GetAttribute("Carrying") == true)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1 then drop() end
end)

Remotes:WaitForChild("BoxBreak").OnClientEvent:Connect(function(pos, color)
	pcall(BoxFX.Break, pos, color)
end)
Remotes:WaitForChild("SoulFX").OnClientEvent:Connect(function(pos)
	pcall(DeathFX.Play, pos)
end)

NotifyRemote.OnClientEvent:Connect(function(text, color)
	Sfx.Play("Notify")
	showBanner(text, color or Color3.new(1, 1, 1), 1.6)
end)

-- ================= prompt filtering + box outlines =================
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	refresh()
	acc += dt
	if acc < 0.15 then return end
	acc = 0
	local myTeam = player.Team and player.Team.Name
	for _, pr in CollectionService:GetTagged("WPPrompt") do
		local box = pr.Parent
		if box then
			local st = box:GetAttribute("State")
			local usable
			if carrying or not myTeam then
				usable = false
			elseif st == "Plugged" then
				usable = box:GetAttribute("PlugTeam") ~= myTeam -- extract ENEMY boxes only
			else
				usable = st == "Loose"
			end
			if pr.Enabled ~= usable then pr.Enabled = usable end
		end
	end
end)

-- ================= box visuals =================
-- 1) every box: animated face (blink, scared when hurt/drained, happy when plugging, ...)
-- 2) YOUR carried box: the real one is hidden for you and replaced by a small two-handed first-person model
local CV = C.CARRY_VM
local SLEEVE, GLOVE = Color3.fromRGB(58, 70, 98), Color3.fromRGB(30, 33, 40)

local function setBoxHidden(box, hidden)
	local m = hidden and 1 or 0
	box.LocalTransparencyModifier = m
	for _, d in box:GetDescendants() do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = m
		elseif d:IsA("SurfaceGui") or d:IsA("PointLight") then d.Enabled = not hidden end
	end
end

local function findMyBox()
	for _, b in CollectionService:GetTagged("WPBox") do
		if b:GetAttribute("Carrier") == player.UserId then return b end
	end
end

local vm -- { body, list, armParts, gloves, box, t0 }
local function destroyVM()
	if not vm then return end
	if vm.box and vm.box.Parent then setBoxHidden(vm.box, false) end
	vm.folder:Destroy()
	vm = nil
end

local function buildVM(box)
	local folder = Instance.new("Model")
	folder.Name = "CarryVM"
	local body, _, list = BoxModel.Build(CV.BoxSize, { Accent = BoxModel.Amber, Viewmodel = true })
	local team = box:GetAttribute("PlugTeam") -- (a carried box has no team colour: amber)
	body.Parent = folder
	local arms = {}
	for _, side in { -1, 1 } do
		local sleeve = Instance.new("Part")
		sleeve.Name = "Sleeve"
		sleeve.Color, sleeve.Material = SLEEVE, Enum.Material.SmoothPlastic
		local glove = Instance.new("Part")
		glove.Name = "Glove"
		glove.Size = Vector3.new(0.3, 0.3, 0.34)
		glove.Color, glove.Material = GLOVE, Enum.Material.SmoothPlastic
		for _, pt in { sleeve, glove } do
			pt.Anchored = true
			pt.CanCollide, pt.CanQuery, pt.CanTouch, pt.CastShadow = false, false, false, false
			pt.TopSurface, pt.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			pt.Parent = folder
		end
		table.insert(arms, { side = side, sleeve = sleeve, glove = glove })
	end
	folder.Parent = camera
	vm = { folder = folder, body = body, list = list, arms = arms, box = box, t0 = os.clock(), bob = 0 }
	setBoxHidden(box, true)
end

local function updateVM(dt, now)
	local box = findMyBox()
	if not box then destroyVM() return end
	if not vm or vm.box ~= box then
		destroyVM()
		buildVM(box)
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local speed = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
	vm.bob += dt * math.clamp(speed, 0, 20) * 0.45
	local amp = math.clamp(speed / 16, 0, 1.4)
	throwKick = math.max(0, throwKick - dt * 7)

	local a = math.clamp((now - vm.t0) / CV.RaiseTime, 0, 1)
	local raise = 1 - (1 - a) ^ 3
	local pos = CV.Pos
		+ Vector3.new(math.sin(vm.bob) * 0.04 * amp, -math.abs(math.cos(vm.bob)) * 0.05 * amp + math.sin(now * 1.7) * 0.006, 0)
		+ Vector3.new(0, -1.2 * (1 - raise), 0.6 * (1 - raise))
		+ Vector3.new(0, 0.15 * throwKick, -0.9 * throwKick)
	local boxCF = camera.CFrame * CFrame.new(pos) * CFrame.Angles(math.rad(-6) * raise + math.rad(10) * throwKick, math.rad(math.sin(vm.bob) * 1.2 * amp), 0)

	vm.body.CFrame = boxCF
	for _, e in vm.list do e.Part.CFrame = boxCF * e.Offset end

	local half = CV.BoxSize / 2
	for _, arm in vm.arms do
		local shoulder = (camera.CFrame * CFrame.new(arm.side * 1.0, -1.7, 0.4)).Position
		local hand = (boxCF * CFrame.new(arm.side * (half + 0.12), -CV.BoxSize * 0.05, CV.BoxSize * 0.12)).Position
		local len = (hand - shoulder).Magnitude
		arm.sleeve.Size = Vector3.new(0.34, 0.34, len)
		arm.sleeve.CFrame = CFrame.lookAt(shoulder, hand) * CFrame.new(0, 0, -len / 2)
		arm.glove.CFrame = CFrame.lookAt(hand, hand + boxCF.LookVector, boxCF.UpVector)
	end
	BoxModel.Animate(vm.body, box, now, TEAM_COLORS)
end

local faceAcc = 0
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local ok = pcall(updateVM, dt, now)
	if not ok then destroyVM() end
	faceAcc += dt
	if faceAcc >= 1 / 30 then
		faceAcc = 0
		for _, b in CollectionService:GetTagged("WPBox") do
			if b:IsDescendantOf(workspace) and not (vm and vm.box == b) then
				BoxModel.Animate(b, b, now, TEAM_COLORS)
			end
		end
	end
end)
player.CharacterRemoving:Connect(destroyVM)

-- ================= leftover first-person gun cleanup =================
-- Respawning (the round-start teleport) destroys the character while GunClient is still running, so GunClient never gets to
-- clean up and its first-person arms + gun stay in the camera. Anything named "Viewmodel" that does not belong to the CURRENT
-- character's GunClient gets removed here.
local function sweepViewmodels()
	local char = player.Character
	for _, m in camera:GetChildren() do
		if m.Name == "Viewmodel" and m:IsA("Model") then
			local owner = m:FindFirstChild("Owner")
			local who = owner and owner.Value
			if not who or who ~= char or not who:IsDescendantOf(workspace) then m:Destroy() end
		end
	end
end
camera.ChildAdded:Connect(function(m)
	if m.Name == "Viewmodel" then task.defer(sweepViewmodels) end
end)
player.CharacterAdded:Connect(function() task.delay(0.1, sweepViewmodels) end)
task.spawn(function()
	while true do
		task.wait(0.5)
		sweepViewmodels()
	end
end)

-- ================= box sounds (3D, played from the box; driven by the attributes the server already sets) =================
-- Slots live in SoundBank "Boxes": BoxSpawn, BoxPickup, BoxExtract, BoxDrop, BoxThrow, BoxLand, BoxPlugStart, BoxPlugged, BoxHit, BoxCritical
do
	local clientStart = os.clock()
	local function watchBox(b)
		if not b:IsA("BasePart") then return end
		local prev = b:GetAttribute("State")
		local lastHitSnd, critical = 0, false
		if os.clock() - clientStart > 3 then Sfx.Play("BoxSpawn", b) end -- not for boxes that already existed when you joined
		b:GetAttributeChangedSignal("State"):Connect(function()
			local st = b:GetAttribute("State")
			local was = prev
			prev = st
			if st == "Carried" then
				Sfx.Play(was == "Plugged" and "BoxExtract" or "BoxPickup", b)
			elseif st == "Thrown" then Sfx.Play("BoxThrow", b)
			elseif st == "Loose" then
				if was == "Thrown" then Sfx.Play("BoxLand", b)
				elseif was == "Carried" then Sfx.Play("BoxDrop", b) end
			elseif st == "Plugging" then Sfx.Play("BoxPlugStart", b)
			elseif st == "Plugged" then critical = false; Sfx.Play("BoxPlugged", b) end
		end)
		b:GetAttributeChangedSignal("LastHit"):Connect(function()
			local now = os.clock()
			if now - lastHitSnd < 0.08 then return end -- automatic fire: do not stack a sound per bullet
			lastHitSnd = now
			Sfx.Play("BoxHit", b)
		end)
		b:GetAttributeChangedSignal("Health"):Connect(function()
			local hp, max = b:GetAttribute("Health"), b:GetAttribute("MaxHealth")
			if hp and max and max > 0 and hp > 0 and hp / max < 0.25 and not critical then
				critical = true
				Sfx.Play("BoxCritical", b)
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal("WPBox"):Connect(watchBox)
	for _, b in CollectionService:GetTagged("WPBox") do watchBox(b) end
end
