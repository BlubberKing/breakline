-- Movement v3.1 (v3.8: stands down while AbilityMode is set): crouch (C / LeftCtrl / ButtonB while NOT sprinting), slide (same keys while sprinting),
-- momentum slide (keeps speed on flat, gains downhill, loses a little uphill), slide-out blend, mantle,
-- momentum jumps (low + snappy, keep your run speed in the air, limited air steering).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TimeScale = require(RS:WaitForChild("TimeScale"))

local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

local CFG = {
	-- slide (walk = 16, sprint = 30, both set in GunClient)
	SLIDE_MIN_SPEED     = 20,   -- need to be sprinting to slide; slower than this = crouch instead
	SLIDE_BOOST         = 6,    -- extra speed when the slide starts
	SLIDE_MAX_START     = 40,
	SLIDE_MAX_SPEED     = 58,   -- cap when gaining speed downhill
	SLIDE_FLAT_TOL      = 0.06, -- slopes gentler than ~3.5 degrees count as flat
	SLIDE_FLAT_FRICTION = 0,    -- studs/s^2 lost on flat ground (0 = keep all momentum)
	SLIDE_DOWNHILL_ACCEL= 70,   -- gain per second on downhill (scaled by steepness)
	SLIDE_UPHILL_BASE   = 4,    -- loss per second when sliding up any slope
	SLIDE_UPHILL_ACCEL  = 28,   -- extra loss per second (scaled by steepness)
	SLIDE_FLAT_TIME     = 0.95, -- slide length on flat/uphill; the timer pauses while going downhill
	SLIDE_MAX_TIME      = 4,    -- hard safety cap
	SLIDE_END_SPEED     = 14,
	SLIDE_STEER         = 1.8,  -- rad/s
	SLIDE_COOLDOWN      = 0.5,
	SLIDE_HIP_FACTOR    = 0.4,  -- lower = lower camera + hitbox
	SLIDE_BUFFER        = 0.2,  -- press slide just before landing
	SLIDE_JUMP_KEEP     = 0.95, -- momentum kept on slide-jump
	SLIDE_EXIT_BLEND    = 0.28, -- seconds to blend from slide speed back to run/crouch speed
	CAM_SLIDE_DROP      = -0.35,

	-- jump + air (Roblox default jump height is 7.2 = tall and floaty)
	JUMP_HEIGHT         = 4.6,  -- studs; ledges higher than this are reached with mantle
	FALL_GRAVITY_MULT   = 1.4,  -- extra gravity on the way down only = snappy, not springy
	SPRINT_JUMP_BOOST   = 2.5,  -- extra forward speed when jumping at sprint speed
	SPRINT_JUMP_FROM    = 24,   -- need at least this speed for the boost
	AIR_MAX_SPEED       = 62,
	AIR_ACCEL           = 40,   -- speed gained per second when slower than your run speed
	AIR_DRAG            = 3,    -- speed lost per second when faster than your run speed (low = keeps momentum)
	AIR_TURN            = 3.2,  -- how fast you can steer in the air (rad/s)
	AIR_BRAKE           = 45,   -- pressing backwards in the air slows you down this fast

	-- crouch
	CROUCH_TOGGLE       = false, -- false = hold C, true = tap C to toggle
	CROUCH_HIP_FACTOR   = 0.6,
	CAM_CROUCH_DROP     = -0.2,

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

-- extra gravity while falling (only affects this character)
local fallForce = Instance.new("VectorForce")
fallForce.Name = "FallGravity"
fallForce.Attachment0 = att
fallForce.RelativeTo = Enum.ActuatorRelativeTo.World
fallForce.ApplyAtCenterOfMass = true
fallForce.Force = Vector3.zero
fallForce.Enabled = false
fallForce.Parent = root

hum.UseJumpPower = false
hum.JumpHeight = CFG.JUMP_HEIGHT

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
local mode = "none" -- none | slide | slideout | air | mantle
local slideDir, slideSpeed, slideTime, slideAir, slideStuck = Vector3.zero, 0, 0, 0, 0
local slideReadyAt, slideQueuedAt = 0, -1
local slideFlatTime = 0
local airV, airT, airStuck = Vector3.zero, 0, 0
local mantleData, mantleReadyAt = nil, 0
local lastJumpReq, lastLedgeCheck = -1, 0
local wasGrounded = true
local camKick, camOffsetY = 0, 0
local crouchHeld, crouching = false, false
local exitV, exitT = Vector3.zero, 0

local function sprintKeyDown() -- Shift, or the mobile / gamepad sprint toggle (set by GunClient)
	return UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) or char:GetAttribute("SprintToggle") == true
end
-- something above our head would block standing back up from the current (lowered) height
local function ceilingBlocked()
	local need = math.max(baseHip - hum.HipHeight, 0) + rootHalf() + 1.4
	return workspace:Raycast(root.Position, Vector3.new(0, need, 0), rayParams) ~= nil
end

local function canSlide()
	return (mode == "none" or mode == "slideout" or mode == "air") and hum.Health > 0 and grounded() and os.clock() >= slideReadyAt
		and hvel().Magnitude >= CFG.SLIDE_MIN_SPEED
end

local function startSlide()
	refreshFilters()
	local v = hvel()
	slideDir = v.Magnitude > 0.1 and v.Unit or flatLook()
	slideSpeed = math.min(v.Magnitude + CFG.SLIDE_BOOST, CFG.SLIDE_MAX_START)
	slideTime, slideAir, slideStuck = 0, 0, 0
	slideFlatTime, slideQueuedAt = 0, -1
	mode = "slide"
	crouching = false
	char:SetAttribute("Crouching", false)
	char:SetAttribute("Sliding", true)
	playSound("Slide")
	drivePlanar(slideDir * slideSpeed)
end

-- blend = true: ease from slide speed back into run/crouch speed instead of snapping
local function endSlide(blend)
	char:SetAttribute("Sliding", false)
	slideReadyAt = os.clock() + CFG.SLIDE_COOLDOWN
	if blend then
		exitV, exitT = slideDir * math.max(slideSpeed, 0), 0
		mode = "slideout"
	else
		mode = "none"
		release()
	end
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
	if mode == "slide" then endSlide(false) end
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

-- airborne: keep the takeoff momentum, steer a little
local function startAir(v)
	airV, airT, airStuck = flat(v), 0, 0
	if airV.Magnitude > CFG.AIR_MAX_SPEED then airV = airV.Unit * CFG.AIR_MAX_SPEED end
	mode = "air"
	drivePlanar(airV)
end

------------------------------------------------------------------ updates
local function updateSlide(dt)
	slideTime += dt
	local r = workspace:Raycast(root.Position, Vector3.new(0, -(hum.HipHeight + rootHalf() + 1.5), 0), rayParams)
	local slope = 0 -- > 0 = sliding downhill, < 0 = uphill (sine of the slope angle along the slide)
	if r then
		slideAir = 0
		slope = flat(r.Normal):Dot(slideDir)
	else
		slideAir += dt
	end

	if slope > CFG.SLIDE_FLAT_TOL then -- downhill: gain speed, timer paused
		slideSpeed = math.min(slideSpeed + slope * CFG.SLIDE_DOWNHILL_ACCEL * dt, math.max(slideSpeed, CFG.SLIDE_MAX_SPEED))
	elseif slope < -CFG.SLIDE_FLAT_TOL then -- uphill: lose a little
		slideSpeed -= (CFG.SLIDE_UPHILL_BASE - slope * CFG.SLIDE_UPHILL_ACCEL) * dt
		slideFlatTime += dt
	else -- flat: keep momentum
		slideSpeed -= CFG.SLIDE_FLAT_FRICTION * dt
		slideFlatTime += dt
	end
	if slideAir > 0 then slideFlatTime += dt end

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
	if slideStuck > 0.1 then
		endSlide(false) -- ran into something
	elseif slideAir > 0.25 then
		-- slid off a ledge: keep the momentum into the air
		local keep = slideDir * math.max(slideSpeed, 0)
		endSlide(false)
		startAir(keep)
	elseif slideSpeed <= CFG.SLIDE_END_SPEED or slideFlatTime >= CFG.SLIDE_FLAT_TIME or slideTime >= CFG.SLIDE_MAX_TIME then
		endSlide(true)
	end
end

local function updateSlideOut(dt)
	exitT += dt
	local f = clamp(exitT / CFG.SLIDE_EXIT_BLEND, 0, 1)
	f = f * f * (3 - 2 * f)
	local target = flat(hum.MoveDirection) * hum.WalkSpeed
	drivePlanar(exitV:Lerp(target, f))
	if exitT >= CFG.SLIDE_EXIT_BLEND or not grounded() then
		release()
		mode = "none"
	end
end

local function updateAir(dt)
	airT += dt
	if grounded() and airT > 0.12 then -- landed: hand control back (momentum carries into a buffered slide)
		release()
		mode = "none"
		return
	end
	-- hit a wall: lose the momentum into it instead of sticking to it
	local actual = hvel()
	if airT > 0.08 and airV.Magnitude > 4 and actual.Magnitude < airV.Magnitude * 0.5 then airStuck += dt else airStuck = 0 end
	if airStuck > 0.05 then airV, airStuck = actual, 0 end

	local speed = airV.Magnitude
	local dir = speed > 0.5 and airV / speed or nil
	local md = flat(hum.MoveDirection)
	local runSpeed = hum.WalkSpeed
	if md.Magnitude > 0.1 then
		local target = md.Unit
		if not dir then
			dir = target
		else
			local angle = math.acos(clamp(dir:Dot(target), -1, 1))
			if angle > math.rad(135) then -- pressing backwards: brake
				speed = math.max(speed - CFG.AIR_BRAKE * dt, 0)
			elseif angle > 1e-3 then
				dir = dir:Lerp(target, math.min(1, CFG.AIR_TURN * dt / angle)).Unit
			end
		end
		if speed < runSpeed then speed = math.min(speed + CFG.AIR_ACCEL * dt, runSpeed)
		else speed = math.max(speed - CFG.AIR_DRAG * dt, runSpeed) end
	else
		speed = math.max(speed - CFG.AIR_DRAG * dt, 0) -- no input: keep drifting with your momentum
	end
	airV = dir and dir * speed or Vector3.zero
	drivePlanar(airV)
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
-- one button: slide when sprinting fast enough, otherwise crouch
local function onCrouchSlide(_, state)
	if state == Enum.UserInputState.Begin then
		if canSlide() then
			startSlide()
		elseif not grounded() or (sprintKeyDown() and flat(hum.MoveDirection).Magnitude > 0.1) then
			slideQueuedAt = os.clock() -- landing / reaching sprint speed within the buffer = slide
		end
		if mode ~= "slide" then
			if CFG.CROUCH_TOGGLE then crouchHeld = not crouchHeld else crouchHeld = true end
		elseif not CFG.CROUCH_TOGGLE then
			crouchHeld = true -- keep holding after the slide = stay crouched
		end
		return Enum.ContextActionResult.Sink
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if not CFG.CROUCH_TOGGLE then crouchHeld = false end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end
CAS:BindAction("CrouchSlide", onCrouchSlide, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
CAS:SetTitle("CrouchSlide", "Crouch")

local jumpConn = UIS.JumpRequest:Connect(function()
	lastJumpReq = os.clock()
	if hum.Health <= 0 then return end
	local fromSlideOut = mode == "slideout"
	if fromSlideOut then release(); mode = "none" end
	if mode == "slide" or (mode == "none" and grounded()) then
		if os.clock() >= mantleReadyAt then
			local ledge = findLedge()
			if ledge and ledge.height >= CFG.MANTLE_GROUND_MIN then startMantle(ledge) return end
		end
		if mode == "slide" then -- slide-jump keeps momentum
			local keep = slideDir * math.max(slideSpeed, 0) * CFG.SLIDE_JUMP_KEEP
			endSlide(false)
			startAir(keep)
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		elseif fromSlideOut then -- jump right after a slide still keeps the momentum
			startAir(hvel())
		end
	end
end)

-- normal jumps and walking off ledges: switch to momentum air control
local stateConn = hum.StateChanged:Connect(function(_, new)
	if mode ~= "none" or hum.Health <= 0 then return end
	if new == Enum.HumanoidStateType.Jumping then
		local v = hvel()
		if v.Magnitude >= CFG.SPRINT_JUMP_FROM then v += v.Unit * CFG.SPRINT_JUMP_BOOST end
		startAir(v)
	elseif new == Enum.HumanoidStateType.Freefall then
		startAir(hvel())
	end
end)

------------------------------------------------------------------ main loop
local stepConn = RunService.Stepped:Connect(function(_, dt)
	if hum.Health <= 0 then return end
	-- v3.8: AbilityClient owns the character while it wall-runs / wall-climbs: let go of everything and stand down
	if char:GetAttribute("AbilityMode") ~= nil then
		if mode ~= "none" then
			if mode == "slide" then endSlide(false) end
			release()
			mode = "none"
			char:SetAttribute("Mantling", false)
		end
		fallForce.Enabled = false
		crouchHeld = false
		return
	end
	local now = os.clock()
	local g = grounded()
	if now - slideQueuedAt < CFG.SLIDE_BUFFER and canSlide() then startSlide() end
	wasGrounded = g

	if mode == "slide" then updateSlide(dt)
	elseif mode == "slideout" then updateSlideOut(dt)
	elseif mode == "air" then updateAir(dt)
	elseif mode == "mantle" then updateMantle(dt) end

	-- mantle while airborne: holding jump and moving toward a ledge
	if (mode == "none" or mode == "air") and not g and now >= mantleReadyAt and now - lastLedgeCheck > 0.05 then
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

	-- crouch: hold the key (or stay down under a low ceiling). Sprinting stands you back up.
	local low = hum.HipHeight < baseHip - 0.05
	local blocked = low and ceilingBlocked()
	if crouchHeld and UIS:IsKeyDown(Enum.KeyCode.LeftShift) and flat(hum.MoveDirection).Magnitude > 0.1 and not blocked then
		crouchHeld = false -- pressing sprint cancels crouch (also cancels toggle-crouch)
	end
	local wantCrouch = (mode == "none" or mode == "slideout") and g and (crouchHeld or blocked or char:GetAttribute("Reviving") == true) -- v4.1: kneeling to revive a teammate
	if wantCrouch ~= crouching then
		crouching = wantCrouch
		char:SetAttribute("Crouching", crouching)
	end

	-- hip height (slide / crouch), stays low under ceilings
	local targetHip = baseHip
	if mode == "slide" then targetHip = baseHip * CFG.SLIDE_HIP_FACTOR
	elseif crouching then targetHip = baseHip * CFG.CROUCH_HIP_FACTOR end
	if targetHip > hum.HipHeight + 0.01 then
		local need = (targetHip - hum.HipHeight) + rootHalf() + 1.4
		if workspace:Raycast(root.Position, Vector3.new(0, need, 0), rayParams) then targetHip = hum.HipHeight end
	end
	if math.abs(targetHip - hum.HipHeight) > 0.005 then setHip(approach(hum.HipHeight, targetHip, 20, dt)) end

	-- snappier fall: extra gravity only while coming down
	local vy = root.AssemblyLinearVelocity.Y
	local wantFall = not g and vy < 0 and mode ~= "mantle"
	fallForce.Enabled = wantFall
	if wantFall then fallForce.Force = Vector3.new(0, -root.AssemblyMass * workspace.Gravity * (CFG.FALL_GRAVITY_MULT - 1), 0) end

	-- slow motion (end of a round): cap how fast anything can go, so slides, jumps and falls slow down with the walking
	local ts = TimeScale.Get()
	if ts < 1 then
		local v = root.AssemblyLinearVelocity
		local hv = Vector3.new(v.X, 0, v.Z)
		local cap = 34 * ts + 1
		if hv.Magnitude > cap then hv = hv.Unit * cap end
		local vyCap = 80 * ts + 2
		root.AssemblyLinearVelocity = Vector3.new(hv.X, math.clamp(v.Y, -vyCap, vyCap), hv.Z)
	end

	-- camera
	camKick = approach(camKick, 0, 10, dt)
	local drop = (mode == "slide" and CFG.CAM_SLIDE_DROP) or (crouching and CFG.CAM_CROUCH_DROP) or 0
	camOffsetY = approach(camOffsetY, drop + camKick, 14, dt)
	hum.CameraOffset = Vector3.new(0, camOffsetY, 0)
end)

hum.Died:Connect(function()
	release()
	fallForce.Enabled = false
	char:SetAttribute("Sliding", false)
	char:SetAttribute("Mantling", false)
	char:SetAttribute("Crouching", false)
	CAS:UnbindAction("CrouchSlide")
	jumpConn:Disconnect()
	stateConn:Disconnect()
	stepConn:Disconnect()
end)
