-- Movement: slide (sprint + C / LeftCtrl / ButtonB / mobile button) and mantle (jump into a ledge)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

local CFG = {
	SLIDE_MIN_SPEED   = 17,   -- need to be sprinting (sprint = 24)
	SLIDE_BOOST       = 9,
	SLIDE_MAX_START   = 38,
	SLIDE_FRICTION    = 19,   -- studs/s^2 lost on flat ground
	SLIDE_SLOPE_ACCEL = 60,   -- gain on downhill
	SLIDE_END_SPEED   = 12,
	SLIDE_MAX_TIME    = 1.2,
	SLIDE_STEER       = 1.8,  -- rad/s
	SLIDE_COOLDOWN    = 0.5,
	SLIDE_HIP_FACTOR  = 0.4,  -- lower = lower camera + hitbox
	SLIDE_BUFFER      = 0.2,  -- press slide just before landing
	SLIDE_JUMP_KEEP   = 0.9,  -- momentum kept on slide-jump
	SLIDE_JUMP_CARRY  = 0.45,
	CAM_SLIDE_DROP    = -0.35,

	MANTLE_MIN_H      = 1.4,  -- ledge height above feet (in air)
	MANTLE_GROUND_MIN = 2.4,  -- from ground, lower ledges just use a normal jump
	MANTLE_MAX_H      = 7.5,
	MANTLE_REACH      = 2.4,
	MANTLE_FWD_TIME   = 0.15,
	MANTLE_EXIT_SPEED = 12,
	MANTLE_COOLDOWN   = 0.25,
	MANTLE_JUMP_HOLD  = 0.25,
}

local clamp = math.clamp
local function approach(a, b, speed, dt) return a + (b - a) * (1 - math.exp(-speed * dt)) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local Sfx
pcall(function() Sfx = require(RS:WaitForChild("Sfx", 3)) end)
local function playSound(key)
	if Sfx then Sfx.Play(key, root) end
end

------------------------------------------------------------------ physics driver
local att = Instance.new("Attachment")
att.Name = "MoveAttach"
att.Parent = root
local lv = Instance.new("LinearVelocity")
lv.Name = "MoveDriver"
lv.Attachment0 = att
lv.RelativeTo = Enum.ActuatorRelativeTo.World
lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
lv.MaxForce = 0
lv.Enabled = false
lv.Parent = root

local function drivePlanar(v)
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(v.X, v.Z)
	lv.MaxForce = root.AssemblyMass * 400
	lv.Enabled = true
end
local function driveVector(v)
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = v
	lv.MaxForce = root.AssemblyMass * 900
	lv.Enabled = true
end
local function release()
	lv.Enabled = false
	lv.MaxForce = 0
end

------------------------------------------------------------------ queries
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true -- passable things (like the middle wall) are ignored
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.RespectCanCollide = true
local function refreshFilters()
	local ignore = { workspace.CurrentCamera }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(ignore, p.Character) end
	end
	rayParams.FilterDescendantsInstances = ignore
	overlapParams.FilterDescendantsInstances = ignore
end
refreshFilters()

local baseHip, lastWrittenHip = hum.HipHeight, -1
local function setHip(v)
	lastWrittenHip = v
	hum.HipHeight = v
end
hum:GetPropertyChangedSignal("HipHeight"):Connect(function()
	if math.abs(hum.HipHeight - lastWrittenHip) > 1e-4 then baseHip = hum.HipHeight end
end)

local function rootHalf() return root.Size.Y / 2 end
local function feetY() return root.Position.Y - hum.HipHeight - rootHalf() end
local function grounded() return hum.FloorMaterial ~= Enum.Material.Air end
local function hvel() return flat(root.AssemblyLinearVelocity) end
local function flatLook()
	local l = flat(root.CFrame.LookVector)
	return l.Magnitude > 0.01 and l.Unit or Vector3.new(0, 0, -1)
end
local function charHeight() return baseHip + root.Size.Y + 1.3 end

local function findLedge()
	refreshFilters()
	local dir = flatLook()
	local fy = feetY()
	local wall
	for _, h in ipairs({ 0.8, 1.8, 2.8, 3.8 }) do
		local r = workspace:Raycast(Vector3.new(root.Position.X, fy + h, root.Position.Z), dir * CFG.MANTLE_REACH, rayParams)
		if r and math.abs(r.Normal.Y) < 0.5 then wall = r break end
	end
	if not wall then return nil end
	local inward = flat(-wall.Normal)
	if inward.Magnitude < 0.1 then return nil end
	inward = inward.Unit

	local probe = wall.Position + inward * 0.7
	local start = Vector3.new(probe.X, fy + CFG.MANTLE_MAX_H + 0.6, probe.Z)
	if #workspace:GetPartBoundsInRadius(start, 0.2, overlapParams) > 0 then return nil end -- wall too tall
	local down = workspace:Raycast(start, Vector3.new(0, -(CFG.MANTLE_MAX_H + 0.6), 0), rayParams)
	if not down or down.Normal.Y < 0.7 then return nil end
	local h = down.Position.Y - fy
	if h < CFG.MANTLE_MIN_H or h > CFG.MANTLE_MAX_H then return nil end

	local standXZ = down.Position + inward * 0.5
	local height = charHeight()
	local box = CFrame.new(standXZ.X, down.Position.Y + 0.15 + height / 2, standXZ.Z)
	if #workspace:GetPartBoundsInBox(box, Vector3.new(1.8, height, 1.4), overlapParams) > 0 then return nil end

	local lipY = down.Position.Y + 0.6
	local from = Vector3.new(root.Position.X, lipY, root.Position.Z)
	if workspace:Raycast(from, Vector3.new(standXZ.X, lipY, standXZ.Z) - from, rayParams) then return nil end
	local upLen = math.max(down.Position.Y + height - root.Position.Y, 0.1)
	if workspace:Raycast(root.Position, Vector3.new(0, upLen, 0), rayParams) then return nil end

	return {
		top = down.Position.Y, inward = inward, height = h,
		stand = Vector3.new(standXZ.X, down.Position.Y + baseHip + rootHalf() + 0.05, standXZ.Z),
	}
end

------------------------------------------------------------------ state
local mode = "none" -- none | slide | carry | mantle
local slideDir, slideSpeed, slideTime, slideAir, slideStuck = Vector3.zero, 0, 0, 0, 0
local slideReadyAt, slideQueuedAt = 0, -1
local carryV, carryT = Vector3.zero, 0
local mantleData, mantleReadyAt = nil, 0
local lastJumpReq, lastLedgeCheck = -1, 0
local wasGrounded = true
local camKick, camOffsetY = 0, 0

local function canSlide()
	return mode == "none" and hum.Health > 0 and grounded() and os.clock() >= slideReadyAt
		and hvel().Magnitude >= CFG.SLIDE_MIN_SPEED
end

local function startSlide()
	refreshFilters()
	local v = hvel()
	slideDir = v.Magnitude > 0.1 and v.Unit or flatLook()
	slideSpeed = math.min(v.Magnitude + CFG.SLIDE_BOOST, CFG.SLIDE_MAX_START)
	slideTime, slideAir, slideStuck = 0, 0, 0
	mode = "slide"
	char:SetAttribute("Sliding", true)
	playSound("Slide", 0.7)
	drivePlanar(slideDir * slideSpeed)
end

local function endSlide()
	mode = "none"
	release()
	char:SetAttribute("Sliding", false)
	slideReadyAt = os.clock() + CFG.SLIDE_COOLDOWN
end

local function finishMantle()
	release()
	if mantleData then root.AssemblyLinearVelocity = mantleData.ledge.inward * CFG.MANTLE_EXIT_SPEED end
	mantleData = nil
	mode = "none"
	char:SetAttribute("Mantling", false)
	mantleReadyAt = os.clock() + CFG.MANTLE_COOLDOWN
end

local function startMantle(ledge)
	if mode == "slide" then endSlide() end
	release()
	local riseY = ledge.top + baseHip + rootHalf() + 0.25
	mantleData = {
		ledge = ledge, phase = 1, t = 0, total = 0, riseY = riseY,
		upTime = clamp(0.1 + math.max(riseY - root.Position.Y, 0) * 0.045, 0.12, 0.4),
	}
	mode = "mantle"
	char:SetAttribute("Mantling", true)
	camKick = -0.35
	playSound("Mantle", 0.6)
end

------------------------------------------------------------------ updates
local function updateSlide(dt)
	slideTime += dt
	local r = workspace:Raycast(root.Position, Vector3.new(0, -(hum.HipHeight + rootHalf() + 1.5), 0), rayParams)
	if r then
		slideAir = 0
		slideSpeed += flat(r.Normal):Dot(slideDir) * CFG.SLIDE_SLOPE_ACCEL * dt
	else
		slideAir += dt
	end
	slideSpeed -= CFG.SLIDE_FRICTION * dt

	local md = flat(hum.MoveDirection)
	if md.Magnitude > 0.1 then
		local target = md.Unit
		local angle = math.acos(clamp(slideDir:Dot(target), -1, 1))
		if angle > 1e-3 and angle < math.rad(120) then
			slideDir = slideDir:Lerp(target, math.min(1, CFG.SLIDE_STEER * dt / angle)).Unit
		end
	end
	drivePlanar(slideDir * math.max(slideSpeed, 0))

	if slideTime > 0.1 and hvel().Magnitude < slideSpeed * 0.4 then slideStuck += dt else slideStuck = 0 end
	if slideSpeed <= CFG.SLIDE_END_SPEED or slideTime >= CFG.SLIDE_MAX_TIME or slideAir > 0.25 or slideStuck > 0.1 then
		endSlide()
	end
end

local function updateCarry(dt)
	carryT += dt
	local f = 1 - clamp(carryT / CFG.SLIDE_JUMP_CARRY, 0, 1)
	local steer = flat(hum.MoveDirection) * hum.WalkSpeed
	drivePlanar(carryV * f + steer * (1 - f))
	if carryT >= CFG.SLIDE_JUMP_CARRY or (grounded() and carryT > 0.15) then
		release()
		mode = "none"
	end
end

local function updateMantle(dt)
	local m = mantleData
	m.t += dt
	m.total += dt
	if m.phase == 1 then
		local remain = math.max(m.upTime - m.t, dt)
		local vy = math.max((m.riseY - root.Position.Y) / remain, 4)
		driveVector(Vector3.new(0, vy, 0) + m.ledge.inward * 1.5)
		if root.Position.Y >= m.riseY - 0.08 or m.t > m.upTime + 0.15 then
			m.phase, m.t = 2, 0
		end
	else
		local remain = math.max(CFG.MANTLE_FWD_TIME - m.t, dt)
		driveVector((m.ledge.stand - root.Position) / remain)
		if m.t >= CFG.MANTLE_FWD_TIME then finishMantle() return end
	end
	if m.total > 1 then finishMantle() end
end

------------------------------------------------------------------ input
local function onSlide(_, state)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if canSlide() then startSlide() else slideQueuedAt = os.clock() end
	return Enum.ContextActionResult.Sink
end
CAS:BindAction("Slide", onSlide, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
CAS:SetTitle("Slide", "Slide")

local jumpConn = UIS.JumpRequest:Connect(function()
	lastJumpReq = os.clock()
	if hum.Health <= 0 then return end
	if mode == "slide" or (mode == "none" and grounded()) then
		if os.clock() >= mantleReadyAt then
			local ledge = findLedge()
			if ledge and ledge.height >= CFG.MANTLE_GROUND_MIN then startMantle(ledge) return end
		end
		if mode == "slide" then -- slide-jump keeps momentum
			local keep = slideDir * math.max(slideSpeed, 0) * CFG.SLIDE_JUMP_KEEP
			endSlide()
			carryV, carryT = keep, 0
			mode = "carry"
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			drivePlanar(carryV)
		end
	end
end)

------------------------------------------------------------------ main loop
local stepConn = RunService.Stepped:Connect(function(_, dt)
	if hum.Health <= 0 then return end
	local now = os.clock()
	local g = grounded()
	if g and not wasGrounded and now - slideQueuedAt < CFG.SLIDE_BUFFER and canSlide() then startSlide() end
	wasGrounded = g

	if mode == "slide" then updateSlide(dt)
	elseif mode == "carry" then updateCarry(dt)
	elseif mode == "mantle" then updateMantle(dt) end

	-- mantle while airborne: holding jump and moving toward a ledge
	if (mode == "none" or mode == "carry") and not g and now >= mantleReadyAt and now - lastLedgeCheck > 0.05 then
		local jumpHeld = UIS:IsKeyDown(Enum.KeyCode.Space)
			or UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
			or now - lastJumpReq < CFG.MANTLE_JUMP_HOLD
		local md = flat(hum.MoveDirection)
		if jumpHeld and md.Magnitude > 0.1 and md.Unit:Dot(flatLook()) > 0.3 then
			lastLedgeCheck = now
			local ledge = findLedge()
			if ledge then startMantle(ledge) end
		end
	end

	-- hip height (slide crouch), stays low under ceilings
	local targetHip = (mode == "slide") and baseHip * CFG.SLIDE_HIP_FACTOR or baseHip
	if targetHip > hum.HipHeight + 0.01 then
		local need = (targetHip - hum.HipHeight) + rootHalf() + 1.4
		if workspace:Raycast(root.Position, Vector3.new(0, need, 0), rayParams) then targetHip = hum.HipHeight end
	end
	if math.abs(targetHip - hum.HipHeight) > 0.005 then setHip(approach(hum.HipHeight, targetHip, 20, dt)) end

	-- camera
	camKick = approach(camKick, 0, 10, dt)
	camOffsetY = approach(camOffsetY, (mode == "slide" and CFG.CAM_SLIDE_DROP or 0) + camKick, 14, dt)
	hum.CameraOffset = Vector3.new(0, camOffsetY, 0)
end)

hum.Died:Connect(function()
	release()
	char:SetAttribute("Sliding", false)
	char:SetAttribute("Mantling", false)
	CAS:UnbindAction("Slide")
	jumpConn:Disconnect()
	stepConn:Disconnect()
end)
