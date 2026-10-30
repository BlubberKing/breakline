-- AbilityClient v1 (LocalScript in StarterPlayer > StarterCharacterScripts) - BOTH games (v3.8). Keep the two copies identical.
-- The 4 movement abilities. You can wear ONE (loadout slot MOVE, saved as Loadout.Move; read from the Player attribute "LoadoutJson"):
--   DJUMP  Double Jump  - press SPACE again in the air. Cooldown after use.
--   MJUMP  Mega Jump    - HOLD SPACE on the ground: a charge bar fills (bottom middle), release = launch, higher the longer you held.
--                         A quick tap is a normal jump. Cooldown after the launch.
--   WRUN   Wall Run     - jump at a wall and keep holding a move key: you run along the wall (any direction, camera-relative, so look up
--                         = run up). Walls only (never ceilings). A STAMINA bar drains while you run and refills on the ground.
--                         SPACE on the wall = wall jump. You CAN shoot while wall-running.
--   WCLIMB Wall Climb   - press SPACE next to a wall or under a ceiling: you stick to it (spider-man) as long as you want, move with
--                         WASD (camera-relative), over edges and onto ceilings. SPACE = jump off, C / Ctrl = let go. Letting go starts a
--                         COOLDOWN. You CANNOT shoot while climbing (GunClient / GunServer check AbilityMode == "climb").
-- Wall modes set the character attribute "AbilityMode" ("wallrun" / "climb"); Movement.client stands down while it is set, and
-- AbilityServer relays it to the server. The ability HUD (icon + cooldown + bar) is bottom middle.
-- All numbers are in CFG. Works with or without Movement.client (the Lobby has no Movement script).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera
local UI = require(RS:WaitForChild("UIKit"))
local K, F = UI.C, UI.F
local abilityRemotes = RS:WaitForChild("AbilityRemotes", 10)
local StateR = abilityRemotes and abilityRemotes:FindFirstChild("State")

local CFG = {
	-- double jump
	DJ_HEIGHT = 6.8,        -- studs of the second jump
	DJ_COOLDOWN = 3.5,
	-- mega jump
	MJ_MIN_HEIGHT = 16,     -- studs at the shortest charge
	MJ_MAX_HEIGHT = 54,     -- studs at a full charge
	MJ_CHARGE_TIME = 1.3,   -- seconds to a full charge
	MJ_TAP_TIME = 0.16,     -- released sooner than this = a normal jump
	MJ_COOLDOWN = 6,
	MJ_CHARGE_SLOW = 0.5,   -- walk speed multiplier while charging
	-- wall run
	WR_SPEED = 30,
	WR_SECONDS = 3.2,       -- stamina: seconds of running from full
	WR_REGEN = 2.6,         -- seconds to refill from empty (on the ground; 15% as fast in the air)
	WR_MIN_START = 0.25,    -- after running dry you need this much stamina back to start again
	WR_REACH = 2.5,
	WR_JUMP_OUT = 26, WR_JUMP_UP = 34,
	-- wall climb
	WC_SPEED = 17,
	WC_REACH = 3.0,
	WC_COOLDOWN = 3.5,
	-- shared
	HOLD_DIST = 1.6,        -- how far the root floats off the surface
	ATTACH_LOCK = 0.4,      -- seconds you cannot re-attach after leaving a surface
}

local NAMES = { DJUMP = "DOUBLE JUMP", MJUMP = "MEGA JUMP", WRUN = "WALL RUN", WCLIMB = "WALL CLIMB" }
local HINTS = { DJUMP = "SPACE IN AIR", MJUMP = "HOLD SPACE", WRUN = "JUMP AT A WALL", WCLIMB = "SPACE AT A WALL" }
local ICON_COL = { DJUMP = Color3.fromRGB(90, 210, 255), MJUMP = Color3.fromRGB(255, 200, 60), WRUN = Color3.fromRGB(255, 120, 90), WCLIMB = Color3.fromRGB(120, 230, 150) }
local clamp = math.clamp

-- ================= state =================
local move = ""               -- equipped ability id
local mode = nil              -- nil | "wallrun" | "climb"
local normal = Vector3.yAxis  -- surface normal while attached
local lastLook = Vector3.zAxis
local surfDist, missT = CFG.HOLD_DIST, 0
local stamina, exhausted = 1, false
local usedDJ, airTime = false, 0
local cdEnd, cdTotal = 0, 1
local attachLock, uprightUntil = 0, 0
local charging, chargeStart = false, 0
local canClimb, climbProbeT = false, 0
local lastPress = 0
local filterT = 0
local alive = true

-- ================= loadout =================
local function readMove()
	local raw = player:GetAttribute("LoadoutJson")
	if type(raw) ~= "string" then return "" end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	local m = ok and type(t) == "table" and type(t.Move) == "string" and t.Move or ""
	return NAMES[m] and m or ""
end

-- ================= helpers =================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true -- passable parts (the middle wall) are ignored
local function refreshFilter()
	local ignore = { camera }
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(ignore, p.Character) end
	end
	rayParams.FilterDescendantsInstances = ignore
end
refreshFilter()
local function cast(origin, vec) return workspace:Raycast(origin, vec, rayParams) end

local controls
task.spawn(function()
	local ps = player:WaitForChild("PlayerScripts", 10)
	local mod = ps and ps:WaitForChild("PlayerModule", 10)
	if mod then
		local ok, c = pcall(function() return require(mod):GetControls() end)
		if ok then controls = c end
	end
end)
-- (x = right, y = forward), -1..1
local function moveInput()
	if controls then
		local ok, v = pcall(function() return controls:GetMoveVector() end)
		if ok and typeof(v) == "Vector3" then return Vector2.new(v.X, -v.Z) end
	end
	local x = (UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
	local y = (UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
	return Vector2.new(x, y)
end

local function onPlane(v, n) return v - n * v:Dot(n) end
-- camera-relative input turned into a direction ON the surface (look up the wall = run up)
local function surfaceDir(n, input)
	if input.Magnitude < 0.1 then return Vector3.zero end
	local cf = camera.CFrame
	local f = onPlane(cf.LookVector, n)
	local u = onPlane(cf.UpVector, n)
	f = f + u * (1 - clamp(f.Magnitude * 1.6, 0, 1)) -- looking straight into the wall: "forward" = up the wall
	local r = onPlane(cf.RightVector, n)
	local want = (f.Magnitude > 0.05 and f.Unit * input.Y or Vector3.zero) + (r.Magnitude > 0.05 and r.Unit * input.X or Vector3.zero)
	if want.Magnitude < 0.05 then return Vector3.zero end
	return want.Unit * math.min(1, input.Magnitude)
end

local function makeCF(pos, up, look)
	look = look - up * look:Dot(up)
	if look.Magnitude < 0.05 then look = up:Cross(Vector3.xAxis) end
	look = look.Unit
	local back = -look
	return CFrame.fromMatrix(pos, up:Cross(back), up, back)
end

local function blocked()
	return hum.Health <= 0 or player:GetAttribute("GunMenuOpen") == true or player:GetAttribute("LobbyMenuOpen") == true
		or char:GetAttribute("Revealing") == true or player:GetAttribute("Carrying") == true or root.Anchored
end

local function startCooldown(sec) cdEnd, cdTotal = os.clock() + sec, sec end
local function onCooldown() return os.clock() < cdEnd end

-- ================= physics rig (wall modes) =================
local att = Instance.new("Attachment")
att.Name = "AbilityAttach"
att.Parent = root
local driver = Instance.new("LinearVelocity")
driver.Name = "AbilityDriver"
driver.Attachment0 = att
driver.RelativeTo = Enum.ActuatorRelativeTo.World
driver.ForceLimitMode = Enum.ForceLimitMode.Magnitude
driver.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
driver.MaxForce = root.AssemblyMass * 700
driver.VectorVelocity = Vector3.zero
driver.Enabled = false
driver.Parent = root
local align = Instance.new("AlignOrientation")
align.Name = "AbilityAlign"
align.Attachment0 = att
align.Mode = Enum.OrientationAlignmentMode.OneAttachment
align.RigidityEnabled = false
align.MaxTorque = 1e9
align.MaxAngularVelocity = math.huge
align.Responsiveness = 35
align.Enabled = false
align.Parent = root

-- ================= effects =================
local function ring(pos, radius, color, flat)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.2
	p.Size = Vector3.new(0.18, 1.5, 1.5)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.12, radius, radius), Transparency = 1 }):Play()
	Debris:AddItem(p, 0.5)
end
local function feetPos() return root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2 - 0.1, 0) end

-- ================= mode control =================
local function setMode(m)
	mode = m
	char:SetAttribute("AbilityMode", m)
	if StateR then StateR:FireServer(m or "") end
end

local function enterMode(m, hit)
	setMode(m)
	normal = hit.Normal
	surfDist, missT = hit.Distance, 0
	local flatLook = onPlane(root.CFrame.LookVector, normal)
	lastLook = flatLook.Magnitude > 0.05 and flatLook.Unit or lastLook
	hum.PlatformStand = true
	hum.AutoRotate = false
	driver.MaxForce = root.AssemblyMass * 700
	driver.VectorVelocity = Vector3.zero
	driver.Enabled = true
	align.Enabled = true
	ring(root.Position - normal * (surfDist - 0.1), 4, ICON_COL[move] or K.soul)
end

local function exitMode(launch)
	if not mode then return end
	local was = mode
	setMode(nil)
	driver.Enabled = false
	hum.PlatformStand = false
	hum.AutoRotate = true
	uprightUntil = os.clock() + 0.28 -- stand back up smoothly instead of snapping
	attachLock = os.clock() + CFG.ATTACH_LOCK
	if was == "climb" then startCooldown(CFG.WC_COOLDOWN) end
	if launch then root.AssemblyLinearVelocity = launch end
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
end

-- push the vertical speed for a few frames (the Humanoid's own jump impulse would otherwise override it)
local function boost(vy)
	task.spawn(function()
		local t0 = os.clock()
		for _ = 1, 4 do
			local v = root.AssemblyLinearVelocity
			local want = vy - workspace.Gravity * (os.clock() - t0)
			if v.Y < want then root.AssemblyLinearVelocity = Vector3.new(v.X, want, v.Z) end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- ================= probes =================
local function horizontalDirs()
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or -Vector3.zAxis
	local right = look:Cross(Vector3.yAxis)
	local dirs = { look, right, -right, -look, (look + right).Unit, (look - right).Unit }
	local v = root.AssemblyLinearVelocity
	local hv = Vector3.new(v.X, 0, v.Z)
	if hv.Magnitude > 4 then table.insert(dirs, 1, hv.Unit) end
	return dirs
end

local function probeWall(reach) -- nearest vertical wall around you
	local best
	for _, d in horizontalDirs() do
		local r = cast(root.Position, d * reach)
		if r and math.abs(r.Normal.Y) <= 0.3 and (not best or r.Distance < best.Distance) then best = r end
	end
	return best
end

local function probeClimb(reach) -- walls, overhangs and the ceiling above (never floors)
	local best
	local dirs = horizontalDirs()
	table.insert(dirs, Vector3.yAxis)
	for _, d in dirs do
		local r = cast(root.Position, d * (d.Y > 0.5 and reach + 0.6 or reach))
		if r and r.Normal.Y < 0.45 and (not best or r.Distance < best.Distance) then best = r end
	end
	return best
end

-- ================= abilities =================
local function doubleJump()
	usedDJ = true
	startCooldown(CFG.DJ_COOLDOWN)
	ring(feetPos(), 9, ICON_COL.DJUMP)
	local vy = math.sqrt(2 * workspace.Gravity * CFG.DJ_HEIGHT)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	boost(vy)
end

local function startCharge()
	charging, chargeStart = true, os.clock()
	char:SetAttribute("AbilitySlow", CFG.MJ_CHARGE_SLOW)
end
local function endCharge()
	charging = false
	char:SetAttribute("AbilitySlow", nil)
end
local function releaseCharge()
	if not charging then return end
	local held = os.clock() - chargeStart
	endCharge()
	if held < CFG.MJ_TAP_TIME then
		hum:ChangeState(Enum.HumanoidStateType.Jumping) -- a tap is just a jump
		return
	end
	local frac = clamp(held / CFG.MJ_CHARGE_TIME, 0, 1)
	local h = CFG.MJ_MIN_HEIGHT + (CFG.MJ_MAX_HEIGHT - CFG.MJ_MIN_HEIGHT) * frac ^ 0.85
	local vy = math.sqrt(2 * workspace.Gravity * h)
	startCooldown(CFG.MJ_COOLDOWN)
	ring(feetPos(), 8 + 10 * frac, ICON_COL.MJUMP)
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
	boost(vy)
end

local function wallJump()
	local look = lastLook
	local launch = normal * CFG.WR_JUMP_OUT + Vector3.new(0, CFG.WR_JUMP_UP, 0) + look * 6
	ring(root.Position - normal * (surfDist - 0.1), 6, ICON_COL.WRUN)
	exitMode(launch)
end

local function climbJumpOff()
	local up = normal.Y < -0.5 and 0 or 14
	exitMode(normal * 18 + Vector3.new(0, up, 0))
end

local function tryAttachClimb()
	if mode or blocked() or onCooldown() or os.clock() < attachLock then return false end
	local hit = probeClimb(CFG.WC_REACH)
	if not hit then return false end
	enterMode("climb", hit)
	return true
end

-- SPACE pressed (keyboard / gamepad via InputBegan, touch via JumpRequest)
local function onJumpPress()
	local now = os.clock()
	if now - lastPress < 0.1 then return end
	lastPress = now
	if blocked() then return end
	if mode == "wallrun" then wallJump() return end
	if mode == "climb" then climbJumpOff() return end
	local g = hum.FloorMaterial ~= Enum.Material.Air
	if move == "WCLIMB" then
		if tryAttachClimb() then return end
	elseif move == "DJUMP" then
		if not g and airTime > 0.1 and not usedDJ and not onCooldown() then doubleJump() end
	end
end
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		if move ~= "MJUMP" then onJumpPress() end
	end
end)
UIS.JumpRequest:Connect(function()
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then onJumpPress() end
end)

-- Mega jump: SPACE is taken (sunk) only while you can start a charge; everything else behaves normally
CAS:BindActionAtPriority("AbilityMegaJump", function(_, state)
	if move ~= "MJUMP" then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		if blocked() or mode or hum.FloorMaterial == Enum.Material.Air or onCooldown() then return Enum.ContextActionResult.Pass end
		startCharge()
		return Enum.ContextActionResult.Sink
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if charging then releaseCharge() return Enum.ContextActionResult.Sink end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

-- ================= per-frame =================
local function alignTo(dir)
	if dir.Magnitude > 0.1 then lastLook = dir.Unit end
	align.CFrame = makeCF(root.Position, normal, lastLook)
end

local function updateWallRun(dt)
	stamina -= dt / CFG.WR_SECONDS
	if stamina <= 0 then
		stamina, exhausted = 0, true
		exitMode(nil)
		return
	end
	local hit = cast(root.Position, -normal * (CFG.WR_REACH + 0.8))
	if hit and math.abs(hit.Normal.Y) <= 0.35 then
		normal = normal:Lerp(hit.Normal, 0.5).Unit
		surfDist, missT = hit.Distance, 0
	else
		missT += dt
		if missT > 0.14 then exitMode(nil) return end
	end
	local dir = surfaceDir(normal, moveInput())
	if dir.Y < -0.15 then -- running down onto the floor ends the run
		local fl = cast(root.Position, Vector3.new(0, -3.6, 0))
		if fl and fl.Normal.Y > 0.5 then exitMode(nil) return end
	end
	local pull = clamp((surfDist - CFG.HOLD_DIST) * 10, -8, 8)
	driver.VectorVelocity = dir * CFG.WR_SPEED - normal * pull
	alignTo(dir)
end

local function climbHit(dir)
	local pos = root.Position
	local r = cast(pos, -normal * (CFG.WC_REACH + 0.8))
	if r and r.Normal.Y < 0.5 then return r end
	if dir.Magnitude > 0.1 then
		local d = dir.Unit
		-- inside corner (wall into ceiling): the surface is ahead of you
		r = cast(pos, d * (CFG.WC_REACH))
		if r and r.Normal.Y < 0.5 and r.Normal:Dot(normal) < 0.95 then return r end
		-- outside corner (over an edge): the new surface is the side face just past the edge
		r = cast(pos + d * 2.4 - normal * (surfDist + 0.8), -d * 3.2)
		if r and r.Normal.Y < 0.5 and r.Normal:Dot(d) > 0.5 then return r end
	end
	return nil
end

local function updateClimb(dt)
	if UIS:IsKeyDown(Enum.KeyCode.C) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then -- let go
		exitMode(normal * 6)
		return
	end
	local dir = surfaceDir(normal, moveInput())
	local hit = climbHit(dir)
	if hit then
		normal = normal:Lerp(hit.Normal, 0.6).Unit
		surfDist, missT = hit.Distance, 0
	else
		missT += dt
		if missT > 0.2 then exitMode(nil) return end
	end
	if dir.Y < -0.15 then -- climbed down to the floor: you are back on the ground
		local fl = cast(root.Position, Vector3.new(0, -3.4, 0))
		if fl and fl.Normal.Y > 0.5 then exitMode(nil) return end
	end
	local pull = clamp((surfDist - CFG.HOLD_DIST) * 10, -8, 8)
	driver.VectorVelocity = dir * CFG.WC_SPEED - normal * pull
	alignTo(dir)
end

local function update(dt)
	if hum.Health <= 0 or not alive then return end
	local now = os.clock()
	filterT += dt
	if filterT > 0.5 then filterT = 0 refreshFilter() end

	if mode == nil then
		local g = hum.FloorMaterial ~= Enum.Material.Air
		if g then
			airTime, usedDJ = 0, false
		else
			airTime += dt
		end
		if move == "WRUN" then
			stamina = math.min(1, stamina + dt / CFG.WR_REGEN * (g and 1 or 0.15))
			if exhausted and stamina >= CFG.WR_MIN_START then exhausted = false end
			if not g and airTime > 0.08 and now >= attachLock and not exhausted and not blocked() and moveInput().Magnitude > 0.1 then
				local hit = probeWall(CFG.WR_REACH)
				if hit then enterMode("wallrun", hit) end
			end
		elseif move == "WCLIMB" then
			climbProbeT += dt
			if climbProbeT > 0.12 then
				climbProbeT = 0
				canClimb = not blocked() and not onCooldown() and now >= attachLock and probeClimb(CFG.WC_REACH) ~= nil
			end
		elseif move == "MJUMP" and charging then
			if blocked() or not g and airTime > 0.15 then endCharge() end
		end
		-- smooth stand-up after leaving a wall
		if now < uprightUntil then
			align.Enabled = true
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			align.CFrame = makeCF(root.Position, Vector3.yAxis, look.Magnitude > 0.05 and look or lastLook)
		elseif align.Enabled then
			align.Enabled = false
		end
	else
		airTime = 0
		if blocked() and not root.Anchored then
			-- menu opened / revealing: just drop
		end
		if mode == "wallrun" then updateWallRun(dt) elseif mode == "climb" then updateClimb(dt) end
	end
end
local stepConn = RunService.Stepped:Connect(function(_, dt) update(dt) end)

-- ================= HUD =================
local gui = Instance.new("ScreenGui")
gui.Name = "AbilityHUD"
gui.ResetOnSpawn = true
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local holder = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(420, 150),
	BackgroundTransparency = 1, Visible = false }, gui)
local hint = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(420, 18), Text = "",
	TextSize = 13, FontFace = F.MB, TextColor3 = K.dim, TextStrokeTransparency = 0.6 }, holder)
local box = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(210, 22), Size = UDim2.fromOffset(64, 64),
	BackgroundColor3 = K.void, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, holder)
local boxStroke = UI.new("UIStroke", { Color = K.line2, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
local iconHolder = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, box)
local cdOverlay = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3 }, box)
local cdText = UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", TextSize = 24, FontFace = F.H,
	TextColor3 = K.text, ZIndex = 4 }, box)
local nameLbl = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 88), Size = UDim2.fromOffset(420, 16), Text = "",
	TextSize = 12, FontFace = F.M, TextColor3 = K.dim, TextStrokeTransparency = 0.6 }, holder)
local barBack = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(210, 112), Size = UDim2.fromOffset(340, 14),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false }, holder)
UI.new("UIStroke", { Color = K.line2, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, barBack)
local barFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = K.soul, BorderSizePixel = 0, ZIndex = 2 }, barBack)
local barGrad = UI.new("UIGradient", { Color = ColorSequence.new(K.soul, K.soulPale) }, barFill)
local barLbl = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 128), Size = UDim2.fromOffset(420, 16), Text = "",
	TextSize = 12, FontFace = F.MB, TextColor3 = K.text, TextStrokeTransparency = 0.5 }, holder)

local builtFor = nil
local function buildIcon()
	for _, c in iconHolder:GetChildren() do c:Destroy() end
	if move == "" then return end
	local ic = UI.AbilityIcon(iconHolder, move, 40, ICON_COL[move])
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	nameLbl.Text = NAMES[move]
	builtFor = move
end

local barVisibleUntil = 0
RunService.RenderStepped:Connect(function()
	if not alive then return end
	if move == "" or hum.Health <= 0 or player:GetAttribute("LobbyMenuOpen") == true or player:GetAttribute("GunMenuOpen") == true then
		holder.Visible = false
		return
	end
	holder.Visible = true
	if builtFor ~= move then buildIcon() end
	local now = os.clock()
	-- cooldown
	local left = cdEnd - now
	if left > 0 then
		cdOverlay.Size = UDim2.fromScale(1, clamp(left / cdTotal, 0, 1))
		cdText.Text = left >= 1 and tostring(math.ceil(left)) or ("%.1f"):format(left)
		boxStroke.Color = K.line2
	else
		cdOverlay.Size = UDim2.fromScale(1, 0)
		cdText.Text = ""
		boxStroke.Color = ICON_COL[move]
	end
	-- hint line
	local h = HINTS[move]
	if move == "WCLIMB" then
		if mode == "climb" then h = "SPACE: JUMP OFF   C: LET GO" elseif canClimb then h = "[ SPACE ]  CLIMB" end
	elseif move == "WRUN" and mode == "wallrun" then h = "SPACE: WALL JUMP"
	end
	hint.Text = h
	hint.TextColor3 = ((move == "WCLIMB" and (canClimb or mode == "climb")) or mode == "wallrun") and K.text or K.dim
	-- bar: mega jump charge or wall run stamina
	local showBar, fill, label, color = false, 0, "", K.soul
	if charging then
		local frac = clamp((now - chargeStart) / CFG.MJ_CHARGE_TIME, 0, 1)
		showBar, fill, color = true, frac, K.soul:Lerp(K.gold, frac)
		label = frac >= 1 and "MAX  -  RELEASE" or "CHARGING"
	elseif move == "WRUN" then
		if mode == "wallrun" or stamina < 0.999 then barVisibleUntil = now + 1.2 end
		showBar = now < barVisibleUntil
		fill = stamina
		color = exhausted and K.redHi or K.green:Lerp(K.redHi, 1 - clamp(stamina * 2, 0, 1))
		label = exhausted and "OUT OF STAMINA" or "STAMINA"
	end
	barBack.Visible = showBar
	barLbl.Text = showBar and label or ""
	if showBar then
		barFill.Size = UDim2.fromScale(clamp(fill, 0, 1), 1)
		barFill.BackgroundColor3 = color
		barGrad.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.35))
	end
end)

-- ================= start / stop =================
move = readMove()
player:GetAttributeChangedSignal("LoadoutJson"):Connect(function()
	local m = readMove()
	if m == move then return end
	if mode then exitMode(nil) end
	if charging then endCharge() end
	move, cdEnd, usedDJ, stamina, exhausted = m, 0, false, 1, false
end)

local function cleanup()
	if not alive then return end
	alive = false
	if mode then pcall(setMode, nil) end
	pcall(function() CAS:UnbindAction("AbilityMegaJump") end)
	pcall(function() stepConn:Disconnect() end)
	pcall(function() driver:Destroy() align:Destroy() att:Destroy() end)
	pcall(function() gui:Destroy() end)
	pcall(function() char:SetAttribute("AbilitySlow", nil) end)
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
