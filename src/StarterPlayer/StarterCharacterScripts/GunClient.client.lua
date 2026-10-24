local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

local Config = require(RS:WaitForChild("WeaponConfig"))
local GunMath = require(RS:WaitForChild("GunMath"))
local Spring = require(RS:WaitForChild("Spring"))
local Builder = require(RS:WaitForChild("GunModelBuilder"))
local Sfx = require(RS:WaitForChild("Sfx"))
local HitFX = require(RS:WaitForChild("HitFX"))
local Remotes = RS:WaitForChild("GunRemotes")
local FireRemote, ReloadRemote = Remotes:WaitForChild("Fire"), Remotes:WaitForChild("Reload")
local HitConfirm, ShotFX, DamagedRemote = Remotes:WaitForChild("HitConfirm"), Remotes:WaitForChild("ShotFX"), Remotes:WaitForChild("Damaged")

local WEAPON = "AR"
local RETICLE = "Dot" -- "Dot", "Holo", "Chevron"
local cfg = Config[WEAPON]
local INTERVAL = 60 / cfg.RPM
local BASE_FOV, SPRINT_FOV, SLIDE_FOV_ADD = 75, 80, 6
local WALK_SPEED, SPRINT_SPEED = 16, 24
local BIND = "GunUpdate"
local ACCENT = Builder.Colors.Accent

local HIP = CFrame.new(0.62, -0.62, -1.45) * CFrame.Angles(0, math.rad(2.5), 0)
local SPRINT = CFrame.new(0.4, -0.78, -1.2) * CFrame.Angles(math.rad(-18), math.rad(48), math.rad(18))

player.CameraMode = Enum.CameraMode.LockFirstPerson
UIS.MouseIconEnabled = false

-- ================= HUD =================
local gui = Instance.new("ScreenGui")
gui.Name = "GunHUD"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = true
gui.Parent = player:WaitForChild("PlayerGui")

local vignettes = {}
for _, rot in { 0, 90 } do
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(210, 20, 20)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	local g = Instance.new("UIGradient")
	g.Rotation = rot
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.28, 1),
		NumberSequenceKeypoint.new(0.72, 1), NumberSequenceKeypoint.new(1, 0),
	})
	g.Parent = f
	f.Parent = gui
	table.insert(vignettes, f)
end

local cross = Instance.new("CanvasGroup")
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.Size = UDim2.fromOffset(240, 240)
cross.BackgroundTransparency = 1
cross.Parent = gui
local function line(w, h)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	local s = Instance.new("UIStroke"); s.Transparency = 0.55; s.Parent = f
	f.Parent = cross
	return f
end
local crossLines = {
	{ f = line(2, 8), d = Vector2.new(0, -1) }, { f = line(2, 8), d = Vector2.new(0, 1) },
	{ f = line(8, 2), d = Vector2.new(-1, 0) }, { f = line(8, 2), d = Vector2.new(1, 0) },
}
line(2, 2).Position = UDim2.fromScale(0.5, 0.5)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -36, 1, -32)
panel.Size = UDim2.fromOffset(230, 84)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
panel.BackgroundTransparency = 0.35
panel.BorderSizePixel = 0
panel.Parent = gui
local stripe = Instance.new("Frame")
stripe.Size = UDim2.new(0, 4, 1, 0); stripe.BackgroundColor3 = ACCENT; stripe.BorderSizePixel = 0; stripe.Parent = panel
local function label(pos, size, font, textSize, color, xAlign)
	local l = Instance.new("TextLabel")
	l.Position, l.Size = pos, size
	l.BackgroundTransparency = 1
	l.Font, l.TextSize, l.TextColor3 = font, textSize, color
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	l.Parent = panel
	return l
end
local nameL = label(UDim2.fromOffset(16, 8), UDim2.new(1, -24, 0, 16), Enum.Font.GothamBold, 13, Color3.fromRGB(200, 200, 210))
nameL.Text = cfg.Name
local ammoL = label(UDim2.fromOffset(16, 22), UDim2.fromOffset(90, 46), Enum.Font.GothamBlack, 44, Color3.new(1, 1, 1), Enum.TextXAlignment.Right)
local magL = label(UDim2.fromOffset(112, 38), UDim2.fromOffset(80, 24), Enum.Font.GothamBold, 18, Color3.fromRGB(150, 150, 160))
magL.Text = "/ " .. cfg.MagSize
local barBG = Instance.new("Frame")
barBG.Position = UDim2.new(0, 16, 1, -12); barBG.Size = UDim2.new(1, -28, 0, 4)
barBG.BackgroundColor3 = Color3.new(1, 1, 1); barBG.BackgroundTransparency = 0.85; barBG.BorderSizePixel = 0
barBG.Parent = panel
local barFill = Instance.new("Frame")
barFill.BorderSizePixel = 0; barFill.Size = UDim2.fromScale(1, 1); barFill.Parent = barBG

-- ================= STATE =================
local ammo, reloading, reloadStart, reloadEvents = cfg.MagSize, false, 0, {}
local triggerDown, aimHeld, shiftHeld = false, false, false
local nextFireTime, bloom, sprayIndex, lastShotTime = 0, 0, 0, 0
local aimAlpha, sprintAlpha, equipStart = 0, 0, os.clock()
local slideAlpha, mantleAlpha = 0, 0
local bobT, bobAmt, strafeRoll = 0, 0, 0
local wasGrounded, airVelY = true, 0
local flashUntil, flashRoll, flashVisible = 0, 0, false
local dmgAlpha = 0
local gunCF = camera.CFrame

local recoilPos = Spring.new(400, 28)
local recoilRot = Spring.new(380, 24)
local camPunch = Spring.new(300, 26)
local fovPunch = Spring.new(350, 28)
local swaySpring = Spring.new(180, 18)
local landSpring = Spring.new(220, 16)

local climbTarget, climbOffset, applied = Vector2.zero, Vector2.zero, Vector2.zero
local lastPitch = nil

local fx = HitFX.new(gui)
local built = Builder.Build({ Reticle = RETICLE })
built.Model.Parent = camera
local partsList, cfList = {}, {}
for _, g in { "gun", "mag", "left", "flash" } do
	for _, e in built.Groups[g] do
		e.BaseSize = e.Part.Size
		table.insert(partsList, e.Part)
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { character, camera }

-- ================= HELPERS =================
local function approach(a, target, dt, time)
	return a + (target - a) * (1 - math.exp(-dt * 4 / time))
end
local function seg(u, a, b) return math.clamp((u - a) / (b - a), 0, 1) end
local function smooth(x) return x * x * (3 - 2 * x) end
local function rnd() return math.random() * 2 - 1 end

local function updateHUD()
	ammoL.Text = tostring(ammo)
	ammoL.TextColor3 = (ammo <= cfg.MagSize * 0.25) and Color3.fromRGB(255, 80, 80) or Color3.new(1, 1, 1)
	nameL.Text = reloading and "RELOADING" or cfg.Name
	if not reloading then
		barFill.BackgroundColor3 = Color3.new(1, 1, 1)
		barFill.Size = UDim2.fromScale(ammo / cfg.MagSize, 1)
	end
end
updateHUD()

local function enemyHumanoid(model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or model == character then return nil end
	local p = Players:GetPlayerFromCharacter(model)
	if p and not player.Neutral and p.Team == player.Team then return nil end
	return hum
end

local function currentSpread()
	local s = cfg.SpreadHip + (cfg.SpreadADS - cfg.SpreadHip) * aimAlpha
	if humanoid.FloorMaterial == Enum.Material.Air then s += cfg.SpreadAir
	elseif humanoid.MoveDirection.Magnitude > 0.1 then s += cfg.SpreadMove * (1 - aimAlpha * 0.5) end
	return s + bloom
end

local function spreadDirection(dir, deg)
	if deg <= 0 then return dir end
	local r = math.rad(deg) * math.sqrt(math.random())
	local theta = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, 0, theta) * CFrame.Angles(r, 0, 0)).LookVector
end

local function rotateCamera(dPitch, dYaw)
	local cf = camera.CFrame
	if (cf.LookVector.Y > 0.97 and dPitch > 0) or (cf.LookVector.Y < -0.97 and dPitch < 0) then dPitch = 0 end
	local pos = cf.Position
	camera.CFrame = CFrame.Angles(0, math.rad(dYaw), 0) * (cf - pos) * CFrame.Angles(math.rad(dPitch), 0, 0) + pos
end

local function ejectShell()
	local s = Instance.new("Part")
	s.Size = Vector3.new(0.035, 0.035, 0.11)
	s.Color = Color3.fromRGB(214, 168, 72)
	s.Material = Enum.Material.Metal
	s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = false, false, false, false
	s.CFrame = gunCF * built.EjectOffset * CFrame.Angles(0, math.rad(90), 0)
	s.Parent = workspace
	local c = camera.CFrame
	s.AssemblyLinearVelocity = root.AssemblyLinearVelocity + c.RightVector * (7 + math.random() * 3)
		+ c.UpVector * (5 + math.random() * 3) - c.LookVector
	s.AssemblyAngularVelocity = Vector3.new(rnd(), rnd(), rnd()) * 30
	Debris:AddItem(s, 0.6)
end

-- ================= RELOAD =================
local AT_MAG = Vector3.new(0.08, -0.33, 0.75)
local MAG_LOW = Vector3.new(0.08, -0.58, 0.8)
local DOWN = Vector3.new(0.35, -2.2, 0.9)
local IDENT = CFrame.identity

local function reloadPose(u)
	if u <= 0 or u >= 1 then return IDENT, IDENT, IDENT end
	local tilt = smooth(seg(u, 0, 0.14)) * (1 - smooth(seg(u, 0.84, 1)))
	local tiltCF = CFrame.new(-0.12 * tilt, 0.08 * tilt, 0.05 * tilt)
		* CFrame.Angles(math.rad(14 * tilt), math.rad(-12 * tilt), math.rad(32 * tilt))
	local hand, grab
	if u < 0.24 then
		local a = smooth(seg(u, 0.06, 0.22)); hand = Vector3.zero:Lerp(AT_MAG, a); grab = a
	elseif u < 0.5 then
		hand = AT_MAG:Lerp(DOWN, smooth(seg(u, 0.26, 0.44))); grab = 1
	elseif u < 0.66 then
		hand = DOWN:Lerp(MAG_LOW, smooth(seg(u, 0.5, 0.64))); grab = 1
	elseif u < 0.76 then
		hand = MAG_LOW:Lerp(AT_MAG, smooth(seg(u, 0.66, 0.7))); grab = 1
	else
		local a = smooth(seg(u, 0.76, 0.9)); hand = AT_MAG:Lerp(Vector3.zero, a); grab = 1 - a
	end
	local leftCF = CFrame.new(hand) * CFrame.Angles(math.rad(-20 * grab), 0, math.rad(-35 * grab))
	local magCF = IDENT
	if u >= 0.24 and u < 0.72 then
		local d = hand - AT_MAG
		local out = math.clamp(d.Magnitude / 0.6, 0, 1)
		magCF = CFrame.new(d) * CFrame.Angles(math.rad(-20 * out), 0, math.rad(12 * out))
	end
	return tiltCF, magCF, leftCF
end

local function startReload()
	if reloading or ammo == cfg.MagSize or humanoid.Health <= 0 then return end
	reloading = true
	reloadStart = os.clock()
	reloadEvents = {
		{ at = 0.02, fn = function() Sfx.Play("ReloadStart") end },
		{ at = 0.26, fn = function() Sfx.Play("MagOut") end },
		{ at = 0.68, fn = function()
			Sfx.Play("MagIn")
			recoilPos:Impulse(Vector3.new(0, 1.5, 0))
			recoilRot:Impulse(Vector3.new(-40, 0, 30))
		end },
		{ at = 0.8, fn = function()
			Sfx.Play("Bolt")
			recoilPos:Impulse(Vector3.new(0, 0, 2.5))
		end },
	}
	ReloadRemote:FireServer(WEAPON)
	updateHUD()
end

-- ================= FIRE =================
local function fire()
	ammo -= 1
	local now = os.clock()
	if now - lastShotTime > cfg.SprayResetTime then sprayIndex = 0 end
	sprayIndex += 1
	lastShotTime = now

	local origin = camera.CFrame.Position
	local dir = spreadDirection(camera.CFrame.LookVector, currentSpread())
	local result = workspace:Raycast(origin, dir * cfg.Range, rayParams)
	local hitPos = result and result.Position or origin + dir * cfg.Range
	local hitPart = result and result.Instance

	fx:Tracer((gunCF * built.MuzzleOffset).Position, hitPos)
	flashUntil = now + 0.035
	flashRoll = math.random() * math.pi * 2
	local fs = 0.8 + math.random() * 0.5
	for _, e in built.Groups.flash do e.Part.Size = e.BaseSize * fs end
	if sprayIndex % 2 == 0 then built.Smoke:Emit(1) end
	ejectShell()
	Sfx.Play("Fire")
	Sfx.Play("FireTail")
	if ammo <= cfg.MagSize * 0.25 then Sfx.Play("LowAmmo") end

	if hitPart then
		local model = hitPart:FindFirstAncestorOfClass("Model")
		if enemyHumanoid(model) then
			local head = GunMath.IsHeadshot(hitPart)
			local dmg = GunMath.Damage(cfg, (hitPos - origin).Magnitude, head)
			fx:Hit(model, hitPos, -dir, math.floor(dmg + 0.5), head)
		elseif not (model and model:FindFirstChildOfClass("Humanoid")) then
			fx:Impact(hitPos, result.Normal, hitPart)
		end
	end

	FireRemote:FireServer(WEAPON, origin, dir, hitPart, hitPos)

	local pat = cfg.RecoilPattern[math.min(sprayIndex, #cfg.RecoilPattern)]
	local m = 1 + (cfg.ADSRecoilMult - 1) * aimAlpha
	climbTarget += Vector2.new(pat.X, pat.Y + rnd() * cfg.RecoilJitter) * m
	camPunch:Impulse(Vector3.new(cfg.CamPunch, rnd() * cfg.CamPunch * 0.35, rnd() * cfg.CamRoll) * m)
	fovPunch:Impulse(Vector3.new(cfg.FovPunch, 0, 0))
	recoilPos:Impulse(Vector3.new(rnd() * 0.4, 0.3, cfg.KickBack))
	recoilRot:Impulse(Vector3.new(cfg.KickUp * (0.85 + math.random() * 0.3), rnd() * cfg.KickYaw, rnd() * cfg.KickRoll))
	bloom = math.min(bloom + cfg.BloomPerShot, cfg.BloomMax)

	updateHUD()
	if ammo <= 0 then startReload() end
end

-- ================= EVENTS =================
HitConfirm.OnClientEvent:Connect(function(model, head, killed, dmg, hitPos)
	if model and dmg and hitPos then fx:Number(model, hitPos, dmg, head) end
	if killed and model then
		local p = Players:GetPlayerFromCharacter(model)
		fx:Kill(model, p and p.DisplayName or model.Name)
	end
end)

ShotFX.OnClientEvent:Connect(function(shooter, origin, endPos)
	if shooter == player then return end
	local char = shooter.Character
	local head = char and char:FindFirstChild("Head")
	local tpGun = char and char:FindFirstChild("TPGun", true)
	local muzzle = tpGun and tpGun:FindFirstChild("MuzzlePoint", true)
	local start = (muzzle and muzzle:IsA("Attachment") and muzzle.WorldPosition)
		or (head and head.Position + head.CFrame.LookVector) or origin
	fx:Tracer(start, endPos)
	if head then Sfx.Play("Fire", head) end
end)

DamagedRemote.OnClientEvent:Connect(function(dmg)
	dmgAlpha = math.min(1, dmgAlpha + dmg / 35)
	camPunch:Impulse(Vector3.new(-8, rnd() * 10, rnd() * 40))
	Sfx.Play("Damaged")
end)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then triggerDown = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = true
	elseif input.KeyCode == Enum.KeyCode.R then startReload()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then shiftHeld = true end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then triggerDown = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then shiftHeld = false end
end)

Sfx.Play("Equip")

-- ================= FRAME =================
local function onRender(dt)
	dt = math.min(dt, 0.1)
	local now = os.clock()
	local alive = humanoid.Health > 0
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local vel = root.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sliding = character:GetAttribute("Sliding") == true
	local mantling = character:GetAttribute("Mantling") == true

	-- states
	local aiming = aimHeld and not reloading and alive and not mantling
	local wantsSprint = shiftHeld and moving and not aiming and not triggerDown
	local sprinting = wantsSprint and not sliding and not mantling
	humanoid.WalkSpeed = wantsSprint and SPRINT_SPEED or WALK_SPEED
	aimAlpha = approach(aimAlpha, aiming and 1 or 0, dt, cfg.ADSTime)
	sprintAlpha = approach(sprintAlpha, sprinting and 1 or 0, dt, 0.18)
	slideAlpha = approach(slideAlpha, sliding and 1 or 0, dt, 0.12)
	mantleAlpha = approach(mantleAlpha, mantling and 1 or 0, dt, 0.1)
	UIS.MouseDeltaSensitivity = 1 + (cfg.ADSSensitivity - 1) * aimAlpha

	-- firing
	local canFire = alive and not reloading and ammo > 0 and sprintAlpha < 0.3 and mantleAlpha < 0.4 and (now - equipStart) > 0.3
	if triggerDown and canFire then
		if nextFireTime < now - INTERVAL then nextFireTime = now end
		while nextFireTime <= now and ammo > 0 do
			fire()
			nextFireTime += INTERVAL
		end
	elseif triggerDown and ammo <= 0 and not reloading then
		startReload()
	end
	bloom = math.max(0, bloom - cfg.BloomRecovery * dt * (triggerDown and 0.25 or 1))

	-- reload progress
	local reloadU = 0
	if reloading then
		local t = now - reloadStart
		reloadU = t / cfg.ReloadTime
		for _, ev in reloadEvents do
			if not ev.done and reloadU >= ev.at then ev.done = true; ev.fn() end
		end
		barFill.BackgroundColor3 = ACCENT
		barFill.Size = UDim2.fromScale(math.clamp(reloadU, 0, 1), 1)
		if t >= cfg.ReloadTime then
			reloading = false
			ammo = cfg.MagSize
			updateHUD()
		end
	end

	-- camera: real climb + visual punch
	local pitch = math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)))
	if lastPitch then
		local userDelta = pitch - lastPitch
		if userDelta < 0 and climbTarget.X > 0 then
			local c = math.min(-userDelta, climbTarget.X)
			climbTarget -= Vector2.new(c, 0)
			climbOffset -= Vector2.new(c, 0)
			applied -= Vector2.new(c, 0)
		end
	end
	if now - lastShotTime > cfg.RecoverDelay then
		climbTarget = climbTarget:Lerp(Vector2.zero, 1 - math.exp(-cfg.RecoverSpeed * dt))
	end
	climbOffset = climbOffset:Lerp(climbTarget, 1 - math.exp(-cfg.ClimbSnap * dt))
	local cp = camPunch:Update(dt)
	local desired = climbOffset + Vector2.new(cp.X, cp.Y)
	local d = desired - applied
	applied = desired
	rotateCamera(d.X, d.Y)
	lastPitch = math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)))
	local slideRoll = -3 * slideAlpha * (1 - aimAlpha * 0.6)
	camera.CFrame *= CFrame.Angles(0, 0, math.rad(cp.Z + slideRoll))

	local fp = fovPunch:Update(dt)
	local fov = BASE_FOV + (SPRINT_FOV - BASE_FOV) * sprintAlpha + SLIDE_FOV_ADD * slideAlpha
	camera.FieldOfView = fov + (cfg.ADSFov - fov) * aimAlpha + fp.X

	-- ===== viewmodel =====
	local camCF = camera.CFrame
	local md = UIS:GetMouseDelta()
	local swayMult = 1 - aimAlpha * 0.7
	swaySpring.Target = Vector3.new(
		math.clamp(md.Y * 0.35, -5, 5), math.clamp(md.X * 0.35, -5, 5), math.clamp(md.X * 0.25, -4, 4)
	) * swayMult
	local sw = swaySpring:Update(dt)

	local localVel = camCF:VectorToObjectSpace(vel)
	strafeRoll = approach(strafeRoll, -localVel.X * 0.22 * swayMult * (1 - slideAlpha), dt, 0.2)

	if not grounded then airVelY = vel.Y end
	if grounded and not wasGrounded then
		landSpring:Impulse(Vector3.new(0, -math.clamp(-airVelY * 0.1, 0.6, 4), 0))
	elseif not grounded and wasGrounded then
		landSpring:Impulse(Vector3.new(0, -1, 0))
	end
	wasGrounded = grounded
	local lp = landSpring:Update(dt)

	local bobTarget = (grounded and math.clamp(flatSpeed / 16, 0, 1.6) or 0) * (1 - aimAlpha * 0.85) * (1 - slideAlpha) * (1 - mantleAlpha)
	bobAmt = approach(bobAmt, bobTarget, dt, 0.15)
	bobT += dt * flatSpeed * 0.62
	local b = bobAmt
	local bob = CFrame.new(math.sin(bobT) * 0.035 * b, -math.abs(math.cos(bobT)) * 0.04 * b + 0.02 * b, 0)
		* CFrame.Angles(math.rad(math.abs(math.cos(bobT)) * 0.8 * b), 0, math.rad(math.sin(bobT) * 1.4 * b))
	local br = 1 - aimAlpha * 0.8
	local breathe = CFrame.new(0, math.sin(now * 1.7) * 0.01 * br, 0) * CFrame.Angles(math.rad(math.sin(now * 1.7) * 0.3 * br), 0, 0)

	local e = math.clamp((now - equipStart) / 0.45, 0, 1)
	local ie = (1 - e) ^ 3
	local equipCF = CFrame.new(0.1 * ie, -0.9 * ie, 0.2 * ie) * CFrame.Angles(math.rad(-35 * ie), math.rad(-15 * ie), math.rad(20 * ie))

	-- slide: cant left and tuck in (mostly straightened when aiming)
	local sk = smooth(slideAlpha)
	local skPos = sk * (1 - aimAlpha * 0.9)
	local skRoll = sk * (1 - aimAlpha * 0.75)
	local slideCF = CFrame.new(-0.1 * skPos, -0.05 * skPos, 0.12 * skPos)
		* CFrame.Angles(math.rad(3 * skPos), math.rad(4 * skPos), math.rad(-16 * skRoll))

	-- mantle: drop the gun down and to the side
	local mk = smooth(mantleAlpha)
	local mantleCF = CFrame.new(0.15 * mk, -0.75 * mk, 0.3 * mk)
		* CFrame.Angles(math.rad(-38 * mk), math.rad(22 * mk), math.rad(32 * mk))

	local tiltCF, magAnim, leftAnim = reloadPose(reloading and reloadU or 0)

	local rp, rr = recoilPos:Update(dt), recoilRot:Update(dt)
	local kp, kr = 1 - aimAlpha * 0.45, 1 - aimAlpha * 0.6
	local recoilCF = CFrame.new(rp.X * kp, rp.Y * kp, rp.Z * kp) * CFrame.Angles(math.rad(rr.X * kr), math.rad(rr.Y * kr), math.rad(rr.Z * kr))

	local ea = smooth(aimAlpha)
	local base = HIP:Lerp(built.AimOffset, ea):Lerp(SPRINT, sprintAlpha * (1 - aimAlpha))

	gunCF = camCF * base * mantleCF * slideCF * equipCF * CFrame.new(0, lp.Y, 0) * CFrame.Angles(math.rad(-lp.Y * 20), 0, 0)
		* breathe * bob * CFrame.Angles(math.rad(sw.X), math.rad(sw.Y), math.rad(sw.Z + strafeRoll))
		* tiltCF * recoilCF

	local i = 0
	for _, g in built.Groups.gun do i += 1; cfList[i] = gunCF * g.Offset end
	local magCF = gunCF * built.MagPivot * magAnim
	for _, g in built.Groups.mag do i += 1; cfList[i] = magCF * g.Offset end
	local leftCF = gunCF * built.LeftPivot * leftAnim
	for _, g in built.Groups.left do i += 1; cfList[i] = leftCF * g.Offset end
	local flashCF = gunCF * built.MuzzleOffset * CFrame.Angles(0, 0, flashRoll)
	for _, g in built.Groups.flash do i += 1; cfList[i] = flashCF * g.Offset end
	workspace:BulkMoveTo(partsList, cfList, Enum.BulkMoveMode.FireCFrameChanged)

	local flashOn = now < flashUntil
	if flashOn ~= flashVisible then
		flashVisible = flashOn
		for _, g in built.Groups.flash do g.Part.Transparency = flashOn and 0 or 1 end
		built.Light.Brightness = flashOn and 4 or 0
	end

	-- crosshair
	local spread = currentSpread()
	local gap = math.tan(math.rad(spread)) / math.tan(math.rad(camera.FieldOfView / 2)) * (camera.ViewportSize.Y / 2) + 5
	gap = math.min(gap, 110)
	for _, c in crossLines do
		c.f.Position = UDim2.new(0.5, c.d.X * (gap + 4), 0.5, c.d.Y * (gap + 4))
	end
	cross.GroupTransparency = math.clamp(math.max(aimAlpha, sprintAlpha, mantleAlpha) * 1.3, 0, 1)

	-- damage vignette
	dmgAlpha = math.max(0, dmgAlpha - dt * 2.2)
	local low = humanoid.Health < 50 and (1 - humanoid.Health / 50) * 0.5 or 0
	local va = math.max(dmgAlpha, low)
	for _, f in vignettes do f.BackgroundTransparency = 1 - va * 0.6 end
end

pcall(function() RunService:UnbindFromRenderStep(BIND) end)
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, onRender)

local cleaned = false
local function cleanup()
	if cleaned then return end
	cleaned = true
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	fx:Destroy()
	built.Model:Destroy()
	UIS.MouseDeltaSensitivity = 1
	camera.FieldOfView = BASE_FOV
end
humanoid.Died:Connect(cleanup)
character.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
