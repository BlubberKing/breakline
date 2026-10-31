-- AbilityClient v2 (LocalScript in StarterPlayer > StarterCharacterScripts) - BOTH games. Keep the two copies identical.
-- v4.0: wall run + wall climb rebuilt. They now START BY THEMSELVES (no SPACE needed), look like a person running / climbing
-- (upright body, lean, camera roll, ledge vault, dust; the limb animation lives in AbilityPose) and feel better.
-- The 4 movement abilities. You can wear ONE (loadout slot MOVE, saved as Loadout.Move; read from the Player attribute "LoadoutJson"):
--   DJUMP  Double Jump  - press SPACE again in the air. Cooldown after use.
--   MJUMP  Mega Jump    - HOLD SPACE on the ground: a charge bar fills (bottom middle), release = launch, higher the longer you held.
--                         A quick tap is a normal jump. Cooldown after the launch.
--   WRUN   Wall Run     - SPRINT INTO A WALL and you run UP it (fast at first, the push runs out after ~1.1s, then you vault over the
--                         top if there is a ledge, or kick off). Jump / sprint-jump NEXT TO a wall and you run ALONG it (any direction,
--                         camera-relative). Walls only (never ceilings). A STAMINA bar drains while you run and refills on the ground.
--                         SPACE on the wall = wall jump (flies off in the direction you look). You CAN shoot while wall-running.
--   WCLIMB Wall Climb   - WALK INTO A WALL (hold the move key at it for a split second) and you grab on and climb, as long as you want.
--                         WASD moves you (camera-relative, over the top = automatic vault, onto ceilings with SPACE under one).
--                         SPACE = jump off, C / Ctrl = let go. Letting go starts a COOLDOWN. You CANNOT shoot while climbing
--                         (GunClient / GunServer check AbilityMode == "climb").
-- Wall modes set the character attribute "AbilityMode" ("wallrun" / "climb") + "WallNormal"; Movement.client stands down while it is set;
-- AbilityServer relays both to the server (so every client can pose you: AbilityPose). The ability HUD (icon + cooldown + bar) is bottom middle.
-- All numbers are in CFG. Works in the Lobby too (Lobby has Movement.client + LobbyMotion since v4.0).
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
local Sfx
pcall(function() Sfx = require(RS:WaitForChild("Sfx", 3)) end)
local function playSound(name) -- silent until the SoundBank has a slot with this name ("WallStart", "WallJump", "Vault")
	if Sfx then pcall(Sfx.Play, name, root) end
end

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
	WR_SPEED = 32,          -- speed along a wall
	WR_UP_SPEED = 27,       -- speed when running UP a wall (fades out over WR_UP_TIME)
	WR_UP_TIME = 1.15,      -- seconds of up-run push
	WR_SECONDS = 3.4,       -- stamina: seconds of running from full (up-run costs 1.4x)
	WR_REGEN = 2.6,         -- seconds to refill from empty (on the ground; 15% as fast in the air)
	WR_MIN_START = 0.25,    -- after running dry you need this much stamina back to start again
	WR_MIN_SPEED = 18,      -- you need this much flat speed to start a wall run (sprint = 30, walk = 16)
	WR_REACH = 2.9,         -- how far ahead / beside you a wall counts
	WR_WALL_H = 5.5,        -- the wall must still be there this high above your feet (lower = a ledge: jump / mantle it)
	WR_HEAD_ON = 0.6,       -- from the ground you must run at the wall this straight on (1 = perpendicular)
	WR_JUMP_OUT = 24, WR_JUMP_UP = 40,
	WR_LEAN_SIDE = 15, WR_LEAN_UP = 12, -- degrees the body leans into the wall
	WR_IDLE_EXIT = 0.3,     -- seconds with no move key before you drop off
	-- wall climb
	WC_SPEED = 17,
	WC_REACH = 3.0,         -- SPACE grab reach (walls, overhangs, ceilings)
	WC_AUTO_REACH = 1.9,    -- walk-into-wall grab reach
	WC_AUTO_HOLD = 0.14,    -- seconds you must push into the wall before you grab it
	WC_COOLDOWN = 3.5,
	-- shared
	HOLD_SIDE = 1.45,       -- how far the root floats off the wall (running along it)
	HOLD_FACE = 1.75,       -- ... when facing the wall (up-run / climb)
	ATTACH_LOCK = 0.4,      -- seconds you cannot re-attach after leaving a surface
	SAME_WALL_LOCK = 0.9,   -- seconds you cannot re-attach to the wall you just left
	ROLL_DEG = 6,           -- camera roll while running along a wall
}

local NAMES = { DJUMP = "DOUBLE JUMP", MJUMP = "MEGA JUMP", WRUN = "WALL RUN", WCLIMB = "WALL CLIMB" }
local HINTS = { DJUMP = "SPACE IN AIR", MJUMP = "HOLD SPACE", WRUN = "SPRINT INTO A WALL", WCLIMB = "WALK INTO A WALL" }
local ICON_COL = { DJUMP = Color3.fromRGB(90, 210, 255), MJUMP = Color3.fromRGB(255, 200, 60), WRUN = Color3.fromRGB(255, 120, 90), WCLIMB = Color3.fromRGB(120, 230, 150) }
local clamp, rad, cos, sin = math.clamp, math.rad, math.cos, math.sin
local function approach(a, b, speed, dt) return a + (b - a) * (1 - math.exp(-speed * dt)) end

-- ================= state =================
local move = ""               -- equipped ability id
local mode = nil              -- nil | "wallrun" | "climb"
local normal = Vector3.yAxis  -- surface normal while attached
local lastLook = Vector3.zAxis
local lookNow, upNow = Vector3.zAxis, Vector3.yAxis
local runDir, climbV, speedNow = Vector3.zero, Vector3.zero, 0
local surfDist, missT = CFG.HOLD_FACE, 0
local modeT, upT, idleT, sendT = 0, 0, 0, 0
local wallPart, lastWall, lastWallUntil = nil, nil, 0
local stamina, exhausted = 1, false
local usedDJ, airTime = false, 0
local cdEnd, cdTotal = 0, 1
local attachLock, uprightUntil = 0, 0
local charging, chargeStart = false, 0
local canClimb, climbProbeT, autoT = false, 0, 0
local lastPress = 0
local filterT = 0
local alive = true
local rollNow = 0

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
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
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
local function busy() -- sliding / crouching / mantling: the base kit owns the character
	return char:GetAttribute("Sliding") == true or char:GetAttribute("Crouching") == true or char:GetAttribute("Mantling") == true
end

local function startCooldown(sec) cdEnd, cdTotal = os.clock() + sec, sec end
local function onCooldown() return os.clock() < cdEnd end
local function feetY() return root.Position.Y - hum.HipHeight - root.Size.Y / 2 end

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
local function ring(pos, radius, color)
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
-- a ring lying ON the wall (the ring part is a flat disc, so it is turned to face along the wall normal)
local function wallRing(pos, n, radius, color)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.25
	p.Size = Vector3.new(0.12, 1, 1)
	p.CFrame = CFrame.lookAt(pos + n * 0.08, pos + n) * CFrame.Angles(0, math.rad(90), 0)
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.1, radius, radius), Transparency = 1 }):Play()
	Debris:AddItem(p, 0.45)
end

-- ================= mode control =================
local function setMode(m, n)
	mode = m
	char:SetAttribute("AbilityMode", m)
	char:SetAttribute("WallNormal", m and n or nil)
	if StateR then StateR:FireServer(m or "", n) end
	sendT = 0
end

local function enterMode(m, hit, initDir, initSpeed)
	setMode(m, hit.Normal)
	normal = hit.Normal
	surfDist, missT = hit.Distance, 0
	wallPart = hit.Instance
	modeT, upT, idleT = 0, 0, 0
	runDir = initDir or Vector3.zero
	climbV = Vector3.zero
	speedNow = initSpeed or 0
	local l = flat(root.CFrame.LookVector)
	lookNow = l.Magnitude > 0.05 and l.Unit or lastLook
	upNow = Vector3.yAxis
	hum.PlatformStand = true
	hum.AutoRotate = false
	driver.MaxForce = root.AssemblyMass * 700
	driver.VectorVelocity = Vector3.zero
	driver.Enabled = true
	align.Enabled = true
	wallRing(root.Position - normal * (surfDist - 0.1), normal, 5, ICON_COL[move] or K.soul)
	playSound("WallStart")
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
	lastWall, lastWallUntil = wallPart, os.clock() + CFG.SAME_WALL_LOCK
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

local function probeClimb(reach) -- SPACE grab: walls, overhangs and the ceiling above (never floors)
	local best
	local dirs = horizontalDirs()
	table.insert(dirs, Vector3.yAxis)
	for _, d in dirs do
		local r = cast(root.Position, d * (d.Y > 0.5 and reach + 0.6 or reach))
		if r and r.Normal.Y < 0.45 and (not best or r.Distance < best.Distance) then best = r end
	end
	return best
end

-- is the surface in `hit` a real wall (still there WR_WALL_H above your feet), not just a ledge you can jump or mantle?
local function wallTall(hit)
	local o = Vector3.new(root.Position.X, feetY() + CFG.WR_WALL_H, root.Position.Z)
	local r = cast(o, -hit.Normal * (CFG.WR_REACH + 1.5))
	return r ~= nil and math.abs(r.Normal.Y) < 0.5
end

-- wall run auto-start. From the ground only a (nearly) head-on sprint counts; in the air any wall in front / beside you does.
-- returns hit, initial run direction on the wall, initial speed
local function probeWallRun(grounded)
	local v = root.AssemblyLinearVelocity
	local hv = flat(v)
	if hv.Magnitude < CFG.WR_MIN_SPEED then return nil end
	local fwd = hv.Unit
	local right = fwd:Cross(Vector3.yAxis)
	local best, bestInto
	local function try(d, airOnly)
		if airOnly and grounded then return end
		local r = cast(root.Position, d * CFG.WR_REACH)
		if not r or math.abs(r.Normal.Y) > 0.3 then return end
		if r.Instance == lastWall and os.clock() < lastWallUntil then return end
		if not best or r.Distance < best.Distance then
			best, bestInto = r, -r.Normal:Dot(fwd)
		end
	end
	try(fwd, false)
	try((fwd + right).Unit, true)
	try((fwd - right).Unit, true)
	try(right, true)
	try(-right, true)
	if not best then return nil end
	if grounded and bestInto < CFG.WR_HEAD_ON then return nil end
	if not wallTall(best) then return nil end
	local dir
	if bestInto > 0.55 then
		dir = Vector3.yAxis -- running at it: up
	else
		dir = onPlane(fwd, best.Normal)
		dir = dir.Magnitude > 0.05 and dir.Unit or fwd
	end
	return best, dir, hv.Magnitude
end

-- wall climb auto-start: holding a move key at a (vertical) wall
local function probeAutoClimb()
	local md = flat(hum.MoveDirection)
	if md.Magnitude < 0.3 then return nil end
	md = md.Unit
	local r = cast(root.Position, md * CFG.WC_AUTO_REACH)
	if not r or math.abs(r.Normal.Y) > 0.35 then return nil end
	if -r.Normal:Dot(md) < 0.6 then return nil end
	if not wallTall(r) then return nil end
	return r
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

-- SPACE on a wall run: fly off the wall in the direction you LOOK (never back into it)
local function wallJump()
	local cf = camera.CFrame
	local camFlat = flat(cf.LookVector)
	camFlat = camFlat.Magnitude > 0.05 and camFlat.Unit or lastLook
	local away = flat(normal)
	away = away.Magnitude > 0.05 and away.Unit or camFlat
	local dir = away + camFlat * 0.9
	dir = dir.Magnitude > 0.05 and dir.Unit or away
	if dir:Dot(away) < 0.35 then dir = (dir + away * 0.8).Unit end
	wallRing(root.Position - normal * (surfDist - 0.1), normal, 7, ICON_COL.WRUN)
	playSound("WallJump")
	local vy = CFG.WR_JUMP_UP
	exitMode(dir * CFG.WR_JUMP_OUT + Vector3.new(0, vy, 0))
	boost(vy)
end

local function climbJumpOff()
	local up = normal.Y < -0.5 and 0 or 14
	exitMode(normal * 18 + Vector3.new(0, up, 0))
end

-- reached the top edge of a wall: hop over it onto the floor up there (true) or just let go (false)
local function tryVault()
	local fn = flat(normal)
	if fn.Magnitude < 0.3 then return false end
	local into = -fn.Unit
	for _, d in { 1.4, 2.4 } do
		local from = root.Position + into * (surfDist + d) + Vector3.new(0, 3.4, 0)
		local fl = cast(from, Vector3.new(0, -7.5, 0))
		if fl and fl.Normal.Y > 0.7 then
			local rise = fl.Position.Y - feetY() + 0.9
			if rise > 0.4 and rise < 8 then
				local vy = math.sqrt(2 * workspace.Gravity * rise) * 1.08
				wallRing(root.Position - normal * (surfDist - 0.1), normal, 6, ICON_COL[move] or K.soul)
				playSound("Vault")
				exitMode(into * 11 + Vector3.new(0, vy, 0))
				boost(vy)
				return true
			end
		end
	end
	return false
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

-- ================= body orientation while attached =================
-- The body stays UPRIGHT and leans into the wall (a person running / climbing, not a spider lying on it).
-- Only on overhangs and ceilings does it turn over to stand on the surface.
local function bodyBasis()
	local fn = flat(normal)
	local toward = fn.Magnitude > 0.05 and -fn.Unit or lastLook
	if mode == "wallrun" then
		if runDir.Y > 0.55 then
			local a = rad(CFG.WR_LEAN_UP)
			return toward, Vector3.yAxis * cos(a) + toward * sin(a)
		end
		local rd = flat(runDir)
		local look = rd.Magnitude > 0.05 and rd.Unit or lastLook
		local a = rad(CFG.WR_LEAN_SIDE) -- feet toward the wall, head tilts AWAY from it (like running on a wall)
		return look, Vector3.yAxis * cos(a) - toward * sin(a)
	end
	-- climb
	local t = clamp(-normal.Y * 1.5, 0, 1)
	local up = Vector3.yAxis:Lerp(normal, t)
	if up.Magnitude < 0.1 then up = normal end
	local mv = flat(runDir)
	local moveLook = mv.Magnitude > 0.05 and mv.Unit or lastLook
	return toward:Lerp(moveLook, t), up
end

local function alignTo(dt)
	local look, up = bodyBasis()
	lookNow = lookNow:Lerp(look, math.min(1, dt * 12))
	if lookNow.Magnitude < 0.05 then lookNow = look end
	upNow = upNow:Lerp(up, math.min(1, dt * 12))
	if upNow.Magnitude < 0.05 then upNow = up end
	local lf = flat(lookNow)
	if lf.Magnitude > 0.05 then lastLook = lf.Unit end
	align.CFrame = makeCF(root.Position, upNow.Unit, lookNow)
end

-- ================= per-frame =================
local function updateWallRun(dt)
	modeT += dt
	local upRun = runDir.Y > 0.55
	stamina -= dt / CFG.WR_SECONDS * (upRun and 1.4 or 1)
	if stamina <= 0 then
		stamina, exhausted = 0, true
		exitMode(normal * 5)
		return
	end
	local hit = cast(root.Position, -normal * (CFG.WR_REACH + 0.8))
	if hit and math.abs(hit.Normal.Y) <= 0.35 then
		normal = normal:Lerp(hit.Normal, 0.5).Unit
		surfDist, missT = hit.Distance, 0
		wallPart = hit.Instance
	else
		missT += dt
		if missT > 0.1 then
			if runDir.Y > 0.3 and tryVault() then return end -- ran off the top: vault over it
			exitMode(nil)
			return
		end
	end
	local want = surfaceDir(normal, moveInput())
	if want.Magnitude < 0.1 then
		idleT += dt
		if idleT > CFG.WR_IDLE_EXIT then exitMode(normal * 4) return end
		want = runDir.Magnitude > 0.05 and runDir.Unit or Vector3.yAxis -- keep going for a moment when you let go of the keys
	else
		idleT = 0
	end
	runDir = runDir.Magnitude > 0.05 and runDir:Lerp(want, math.min(1, dt * 9)) or want
	if runDir.Magnitude < 0.05 then runDir = want end
	runDir = runDir.Unit
	upRun = runDir.Y > 0.55
	-- up-run: the push fades out; when it is spent you vault over the top or kick off
	local target = CFG.WR_SPEED
	if upRun then
		upT += dt
		local k = clamp(upT / CFG.WR_UP_TIME, 0, 1)
		k = k * k * (3 - 2 * k)
		target = CFG.WR_UP_SPEED * (1 - k)
		if k >= 0.97 then
			if tryVault() then return end
			exitMode(normal * 9 + Vector3.new(0, 8, 0))
			return
		end
	else
		upT = math.max(0, upT - dt * 0.5)
	end
	speedNow = approach(speedNow, target, 7, dt)
	if runDir.Y < -0.15 then -- running down onto the floor ends the run
		local fl = cast(root.Position, Vector3.new(0, -3.6, 0))
		if fl and fl.Normal.Y > 0.5 then exitMode(nil) return end
	end
	local hold = upRun and CFG.HOLD_FACE or CFG.HOLD_SIDE
	local pull = clamp((surfDist - hold) * 12, -10, 10)
	driver.VectorVelocity = runDir * speedNow - normal * pull
	alignTo(dt)
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
	modeT += dt
	if UIS:IsKeyDown(Enum.KeyCode.C) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then -- let go
		exitMode(normal * 6)
		return
	end
	local dir = surfaceDir(normal, moveInput())
	local hit = climbHit(dir)
	if hit then
		normal = normal:Lerp(hit.Normal, 0.6).Unit
		surfDist, missT = hit.Distance, 0
		wallPart = hit.Instance
	else
		missT += dt
		if missT > 0.12 then
			if climbV.Y > 2 and tryVault() then return end -- climbed over the top
			exitMode(nil)
			return
		end
	end
	if dir.Y < -0.15 then -- climbed down to the floor: you are back on the ground
		local fl = cast(root.Position, Vector3.new(0, -3.4, 0))
		if fl and fl.Normal.Y > 0.5 then exitMode(nil) return end
	end
	climbV = climbV:Lerp(dir * CFG.WC_SPEED, math.min(1, dt * 10))
	if dir.Magnitude > 0.1 then
		runDir = runDir.Magnitude > 0.05 and runDir:Lerp(dir, math.min(1, dt * 10)) or dir
		if runDir.Magnitude < 0.05 then runDir = dir end
		runDir = runDir.Unit
	end
	local pull = clamp((surfDist - CFG.HOLD_FACE) * 12, -10, 10)
	driver.VectorVelocity = climbV - normal * pull
	alignTo(dt)
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
			if not exhausted and now >= attachLock and not blocked() and not busy() and moveInput().Magnitude > 0.1 then
				local hit, dir, spd = probeWallRun(g)
				if hit then enterMode("wallrun", hit, dir, spd) end
			end
		elseif move == "WCLIMB" then
			climbProbeT += dt
			local can = not blocked() and not busy() and not onCooldown() and now >= attachLock
			local hit = can and probeAutoClimb() or nil
			if hit then
				autoT += dt
				if autoT >= CFG.WC_AUTO_HOLD then
					autoT = 0
					enterMode("climb", hit)
				end
			else
				autoT = 0
			end
			if climbProbeT > 0.12 then
				climbProbeT = 0
				canClimb = can and (hit ~= nil or probeClimb(CFG.WC_REACH) ~= nil)
			end
		elseif move == "MJUMP" and charging then
			if blocked() or not g and airTime > 0.15 then endCharge() end
		end
		-- smooth stand-up after leaving a wall
		if now < uprightUntil then
			align.Enabled = true
			local look = flat(root.CFrame.LookVector)
			align.CFrame = makeCF(root.Position, Vector3.yAxis, look.Magnitude > 0.05 and look or lastLook)
		elseif align.Enabled then
			align.Enabled = false
		end
	else
		airTime = 0
		if mode == "wallrun" then updateWallRun(dt) elseif mode == "climb" then updateClimb(dt) end
		if mode then -- keep everyone's copy of the wall normal fresh (AbilityPose poses you from it)
			sendT += dt
			if sendT > 0.15 then
				sendT = 0
				char:SetAttribute("WallNormal", normal)
				if StateR then StateR:FireServer(mode, normal) end
			end
		end
	end
end
local stepConn = RunService.Stepped:Connect(function(_, dt) update(dt) end)

-- camera roll while running along a wall (leans into the wall like the body does)
local ROLL_BIND = "AbilityRoll"
pcall(function() RunService:UnbindFromRenderStep(ROLL_BIND) end)
RunService:BindToRenderStep(ROLL_BIND, Enum.RenderPriority.Camera.Value + 2, function(dt)
	local target = 0
	if alive and mode == "wallrun" and runDir.Y <= 0.55 then
		local rd = flat(runDir)
		if rd.Magnitude > 0.1 then
			local right = rd.Unit:Cross(Vector3.yAxis)
			local side = (-flat(normal)):Dot(right) -- > 0: wall on your right
			target = clamp(side, -1, 1) * rad(CFG.ROLL_DEG) -- the horizon tilts away from the wall
		end
	end
	rollNow = approach(rollNow, target, 8, dt)
	if math.abs(rollNow) > 1e-3 then camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, rollNow) end
end)

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
		if mode == "climb" then h = "SPACE: JUMP OFF   C: LET GO" elseif canClimb then h = "HOLD FORWARD AT THE WALL  /  [ SPACE ]" end
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
	pcall(function() RunService:UnbindFromRenderStep(ROLL_BIND) end)
	pcall(function() stepConn:Disconnect() end)
	pcall(function() driver:Destroy() align:Destroy() att:Destroy() end)
	pcall(function() gui:Destroy() end)
	pcall(function() char:SetAttribute("AbilitySlow", nil) end)
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
