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
timerLbl.Text = "25"
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
hintLbl.Size = UDim2.fromOffset(760, 40)
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
local reserveOpen = false -- v5.7: the RESERVE screen (J) is open: the mouse is free, look / roam keys are ignored
local closeReserve -- forward (set below)
local target -- spectated Player (or nil = free roam)
local roam = { pos = Vector3.zero, yaw = 0, pitch = 0, fresh = true }
local lastTargetPos
local camPos, camYaw, camPitch = nil, 0, 0
local switchCooldown = 0
local deathChar -- the body we died in (for the starting camera)
local hiddenParts, shownChar = {}, nil -- v4.2: parts of the spectated body we hid for ourselves
local function restoreBody()
	for d in hiddenParts do
		if d.Parent then d.LocalTransparencyModifier = 0 end
	end
	table.clear(hiddenParts)
	shownChar = nil
end

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
	local b = workspace:FindFirstChild("MapBounds", true) -- v5: it now lives inside the loaded <name>_map folder
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
	if reserveOpen then
		UIS.MouseBehavior = Enum.MouseBehavior.Default -- v5.7: RESERVE screen open, the cursor is free
		UIS.MouseIconEnabled = true
	else
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		UIS.MouseIconEnabled = false
		local md = UIS:GetMouseDelta()
		roam.yaw -= md.X * 0.0034
		roam.pitch = clamp(roam.pitch - md.Y * 0.0034, rad(-85), rad(85))
	end

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
			-- v4.2: we sit INSIDE their body, so hide all of it (head, torso, arms, legs, hair, hats...) and only leave the gun they hold,
			-- like a real first-person view. Done every frame so newly added parts (accessories, a reloaded gun) are hidden too.
			if shownChar ~= char then restoreBody(); shownChar = char end
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") and not d:FindFirstAncestor("TPGun") then
					d.LocalTransparencyModifier = 1
					hiddenParts[d] = true
				end
			end
		end
	else
		if shownChar then restoreBody() end
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
		if d.Magnitude > 0.01 and not reserveOpen then roam.pos = moveRoam(roam.pos, d.Unit * speed * dt) end
		camPos = roam.pos
		camera.CFrame = CFrame.lookAt(roam.pos, roam.pos + look)
		camera.FieldOfView = 75
	end
end

------------------------------------------------------------------ v5.7: RESERVE screen (press J while dead)
-- Opens the loadout dock again. Only your ACTIVE gun / gadgets are clickable: GUN or a GADGET slot opens the small horizontal scroll that
-- lists ONLY what sits in your reserve for that slot. Pick one = it is equipped, and what it replaces goes into that reserve slot (the server
-- does the swap: MatchRemotes.ReserveSwap). The screen closes by itself when you come back to life (revive, personal or team respawn).
local HttpService = game:GetService("HttpService")
local Catalog = require(RS:WaitForChild("LobbyCatalog"))
local LoadoutPicker = require(RS:WaitForChild("LoadoutPicker"))
local UI = require(RS:WaitForChild("UIKit"))
local ReserveSwapR = RS:WaitForChild("MatchRemotes"):WaitForChild("ReserveSwap")
local Sfx = require(RS:WaitForChild("Sfx"))
local function snd(name) pcall(Sfx.Play, name) end -- SoundBank slots ReserveOpen / ReserveClose / ReserveSwap

local rgui = Instance.new("ScreenGui")
rgui.Name = "ReserveScreen"
rgui.ResetOnSpawn = false
rgui.IgnoreGuiInset = true
rgui.DisplayOrder = 62
rgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
rgui.Enabled = false
rgui.Parent = player:WaitForChild("PlayerGui")
local rmodal = Instance.new("TextButton") -- Modal = true frees the mouse while this is visible
rmodal.Name = "ModalCursor"
rmodal.Text = ""
rmodal.Modal = true
rmodal.BackgroundTransparency = 1
rmodal.Size = UDim2.fromOffset(1, 1)
rmodal.Parent = rgui
local rdim = Instance.new("Frame") -- dims the picture but leaves the death bar at the bottom alone
rdim.Size = UDim2.new(1, 0, 1, -BAR_H)
rdim.BackgroundColor3 = Color3.new(0, 0, 0)
rdim.BackgroundTransparency = 0.45
rdim.BorderSizePixel = 0
rdim.Parent = rgui
local rcv = Instance.new("Frame") -- 1920 x 1080 canvas scaled to fit the screen
rcv.AnchorPoint = Vector2.new(0.5, 0.5)
rcv.Position = UDim2.fromScale(0.5, 0.5)
rcv.Size = UDim2.fromOffset(1920, 1080)
rcv.BackgroundTransparency = 1
rcv.Parent = rgui
local rscale = Instance.new("UIScale")
rscale.Parent = rcv
local function fitReserve()
	local v = camera.ViewportSize
	rscale.Scale = math.max(0.3, math.min(v.X / 1920, v.Y / 1080))
end
fitReserve()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitReserve)

local function rlabel(text, size, y, col, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.fromOffset(960, y)
	l.Size = UDim2.fromOffset(1400, size + 10)
	l.Font = font or Enum.Font.GothamBlack
	l.TextSize = size
	l.TextColor3 = col or Color3.new(1, 1, 1)
	l.Text = text
	l.Parent = rcv
	return l
end
rlabel("RESERVE", 64, 250)
rlabel("SWAP YOUR ACTIVE GUN OR GADGETS WITH WHAT YOU KEEP IN RESERVE", 15, 330, Color3.fromRGB(190, 194, 204), Enum.Font.GothamBold)
rlabel("CLICK YOUR GUN OR A GADGET SLOT, THEN PICK FROM YOUR RESERVE  //  J OR ESC TO CLOSE", 13, 356, Color3.fromRGB(130, 135, 146), Enum.Font.GothamBold)

local function readLoadout()
	local l = { Weapon = Catalog.DefaultWeapon, Move = "", Gadgets = { "", "", "" }, Reserve = { "", "", "" } }
	local raw = player:GetAttribute("LoadoutJson")
	if type(raw) == "string" and raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" then
			if type(t.Weapon) == "string" and Catalog.Is(t.Weapon, "weapon") then l.Weapon = t.Weapon end
			if type(t.Move) == "string" then l.Move = t.Move end
			for i = 1, 3 do
				if type(t.Gadgets) == "table" and type(t.Gadgets[i]) == "string" then l.Gadgets[i] = t.Gadgets[i] end
				if type(t.Reserve) == "table" and type(t.Reserve[i]) == "string" then l.Reserve[i] = t.Reserve[i] end
			end
		end
	end
	return l
end

local rdock, rstrip, rconn
local function closeStrip()
	if rstrip then
		local s = rstrip
		rstrip = nil
		s:Destroy()
	end
	if rdock then rdock:Select(nil) end
end

local function openStrip(t)
	local same = rstrip ~= nil and rdock ~= nil and rdock.selectedTile == t
	closeStrip()
	if same then return end
	local l = readLoadout()
	local items, seen = {}, {}
	for j = 1, 3 do
		local id = l.Reserve[j]
		if id ~= "" and not seen[id] and Catalog.Is(id, t.kind) then
			local blocked = false
			if t.kind == "gadget" then -- a gadget you already carry in another slot cannot be equipped twice
				for k = 1, 3 do if k ~= t.idx and l.Gadgets[k] == id then blocked = true end end
			elseif l.Weapon == id then blocked = true end
			if not blocked then
				seen[id] = true
				table.insert(items, Catalog.ById[id])
			end
		end
	end
	rdock.selectedTile = t
	rdock:Select(t)
	rstrip = LoadoutPicker.Strip(rcv, {
		title = t.kind == "weapon" and "RESERVE  /  GUNS" or ("RESERVE  /  GADGETS  /  SLOT " .. t.idx),
		items = items,
		current = t.kind == "weapon" and l.Weapon or l.Gadgets[t.idx],
		allowNone = false,
		emptyText = t.kind == "weapon" and "NO OTHER GUN IN YOUR RESERVE" or "NO OTHER GADGET IN YOUR RESERVE",
		x = t.btn.Position.X.Offset + t.btn.Size.X.Offset / 2,
		bottomY = t.btn.Position.Y.Offset - 34,
		z = 20,
		onPick = function(id)
			if id ~= "" then snd("ReserveSwap") ReserveSwapR:FireServer(t.kind, t.idx, id) end
		end,
		onClose = function()
			rstrip = nil
			if rdock then rdock.selectedTile = nil; rdock:Select(nil) end
		end,
	})
end

function closeReserve()
	if not reserveOpen then return end
	reserveOpen = false
	snd("ReserveClose")
	closeStrip()
	if rdock then rdock:Destroy() rdock = nil end
	if rconn then rconn:Disconnect() rconn = nil end
	rgui.Enabled = false
	rmodal.Visible = false
	if player:GetAttribute("GunMenuOpen") == true then player:SetAttribute("GunMenuOpen", nil) end
end

local function openReserve()
	if reserveOpen or not active or MatchState:GetAttribute("Phase") ~= "Playing" then return end
	reserveOpen = true
	snd("ReserveOpen")
	rgui.Enabled = true
	rmodal.Visible = true
	player:SetAttribute("GunMenuOpen", true)
	rdock = LoadoutPicker.Dock(rcv, {
		y = 830, z = 8,
		itemAt = function(kind, idx)
			local l = readLoadout()
			if kind == "weapon" then return l.Weapon elseif kind == "move" then return l.Move
			elseif kind == "gadget" then return l.Gadgets[idx] else return l.Reserve[idx] end
		end,
		enabled = function(t) return t.kind == "weapon" or t.kind == "gadget" end, -- only the active gun + gadgets open the reserve scroll
		onClick = openStrip,
	})
	-- the server changed your loadout (a swap went through): repaint the dock and refresh the open scroll
	rconn = player:GetAttributeChangedSignal("LoadoutJson"):Connect(function()
		if not rdock then return end
		local keep = rdock.selectedTile
		closeStrip()
		rdock:Paint()
		if keep then rdock.selectedTile = nil end
	end)
end

UIS.InputBegan:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.J and not gpe then
		if reserveOpen then closeReserve() else openReserve() end
	elseif input.KeyCode == Enum.KeyCode.Escape and reserveOpen and not rstrip then
		closeReserve()
	end
end)

------------------------------------------------------------------ switching with the mouse / keys
UIS.InputBegan:Connect(function(input, gpe)
	if not active or gpe or reserveOpen then return end
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
		if closeReserve then closeReserve() end -- v5.7: revived / respawned (personal or team respawn): kick out of the reserve screen
		gui.Enabled = false
		pcall(function() RunService:UnbindFromRenderStep(BIND) end)
		target = nil
		restoreBody()
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
	local total = math.max(player:GetAttribute("DeathTotal") or 25, 0.1)
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
	hintLbl.Text = (hintLbl.Text ~= "" and (hintLbl.Text .. "      ") or "") .. "J  RESERVE" -- v5.7
	if MatchState:GetAttribute("Phase") ~= "Playing" and reserveOpen and closeReserve then closeReserve() end
end)
