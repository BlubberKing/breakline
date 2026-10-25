-- GunClient v3: first-person gun for ANY weapon in WeaponConfig (models from GunModels).
-- Live weapon/sight switching via Player attributes "Weapon" / "Sight" (set by the server, see GunServer).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CAS = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

local Weapons = require(RS:WaitForChild("WeaponConfig"))
local GunMath = require(RS:WaitForChild("GunMath"))
local Spring = require(RS:WaitForChild("Spring"))
local GunModels = require(RS:WaitForChild("GunModels"))
local Sfx = require(RS:WaitForChild("Sfx"))
local HitFX = require(RS:WaitForChild("HitFX"))
local Remotes = RS:WaitForChild("GunRemotes")
local FireRemote, ReloadRemote = Remotes:WaitForChild("Fire"), Remotes:WaitForChild("Reload")
local HitConfirm, ShotFX, DamagedRemote = Remotes:WaitForChild("HitConfirm"), Remotes:WaitForChild("ShotFX"), Remotes:WaitForChild("Damaged")

local VM_SCALE = 0.85 -- viewmodel gun size
local BASE_FOV, SPRINT_FOV, SLIDE_FOV_ADD = 75, 82, 7
local WALK_SPEED, SPRINT_SPEED, CROUCH_SPEED = 16, 30, 9
local MatchCfg = require(RS:WaitForChild("MatchConfig"))
local function isCarrying() return player:GetAttribute("Carrying") == true end -- holding a Wall Push box: no guns/gadgets
-- speed feel (all subtle on purpose)
local SPEEDFX = {
	FOV_FROM = 30, FOV_TO = 55, FOV_ADD = 6,      -- extra FOV when going faster than a sprint (slides, downhill)
	LINES_FROM = 17, LINES_TO = 38,               -- speed lines fade in between these speeds (sprint = ~60% strength)
	LINES_MAX_ALPHA = 0.55,                       -- 0 = invisible, 1 = solid white
	LINE_COUNT = 30,
	EDGE_MAX_ALPHA = 0.22,                        -- soft dark screen-edge vignette at speed (0 = off)
	SHAKE_DEG = 0.22,                             -- camera rumble while sliding (degrees at full speed)
	SLIDE_FOV_PUNCH = 40,                         -- quick FOV kick when a slide starts
	WIND_FROM = 22, WIND_TO = 50, WIND_VOL = 0.5, -- looping wind (SoundBank "Wind", silent until an ID is pasted)
}
local BIND = "GunUpdate"
local ACCENT = GunModels.Colors.Accent
local rad = math.rad

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

-- speed lines: thin soft streaks around the screen edge that drift outward when moving fast
local speedLayer = Instance.new("Frame")
speedLayer.Name = "SpeedLines"
speedLayer.Size = UDim2.fromScale(1, 1)
speedLayer.BackgroundTransparency = 1
speedLayer.Visible = false
speedLayer.Parent = gui
local speedLines = {}
for i = 1, SPEEDFX.LINE_COUNT do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	f.Parent = speedLayer
	speedLines[i] = {
		f = f,
		angle = (i / SPEEDFX.LINE_COUNT) * math.pi * 2 + (math.random() - 0.5) * 0.25,
		r = 0.7 + math.random() * 0.45,
		speed = 0.5 + math.random() * 0.6,
		len = 60 + math.random() * 90,
		w = math.random() < 0.35 and 3 or 2,
	}
end
-- soft dark edges that close in a little at high speed (makes the speed lines pop)
local speedEdges = {}
for _, rot in { 0, 90 } do
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	local g = Instance.new("UIGradient")
	g.Rotation = rot
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 1),
		NumberSequenceKeypoint.new(0.8, 1), NumberSequenceKeypoint.new(1, 0),
	})
	g.Parent = f
	f.Parent = speedLayer
	table.insert(speedEdges, f)
end

-- full-screen sniper scope (black outside a circle, thin crosshair)
local scope = Instance.new("Frame")
scope.Name = "ScopeOverlay"
scope.AnchorPoint = Vector2.new(0.5, 0.5)
scope.Position = UDim2.fromScale(0.5, 0.5)
scope.Size = UDim2.fromScale(0.86, 0.86)
scope.BackgroundTransparency = 1
scope.Visible = false
scope.Parent = gui
do
	local ar = Instance.new("UIAspectRatioConstraint"); ar.Parent = scope
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = scope
	local s = Instance.new("UIStroke"); s.Thickness = 3000; s.Color = Color3.new(0, 0, 0); s.Parent = scope
	local edge = Instance.new("Frame")
	edge.Size = UDim2.fromScale(1, 1); edge.BackgroundTransparency = 1; edge.Parent = scope
	local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0.5, 0); ec.Parent = edge
	local es = Instance.new("UIStroke"); es.Thickness = 40; es.Color = Color3.new(0, 0, 0); es.Transparency = 0.5; es.Parent = edge
	local function ln(size, pos)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size, f.Position = size, pos
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Parent = scope
	end
	ln(UDim2.new(1, 0, 0, 2), UDim2.fromScale(0.5, 0.5))
	ln(UDim2.new(0, 2, 1, 0), UDim2.fromScale(0.5, 0.5))
	ln(UDim2.new(0.3, 0, 0, 6), UDim2.fromScale(0.15, 0.5))
	ln(UDim2.new(0.3, 0, 0, 6), UDim2.fromScale(0.85, 0.5))
	ln(UDim2.new(0, 6, 0.3, 0), UDim2.fromScale(0.5, 0.85))
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(5, 5)
	dot.BackgroundColor3 = Color3.fromRGB(255, 45, 45)
	dot.BorderSizePixel = 0
	local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0.5, 0); dc.Parent = dot
	dot.Parent = scope
end

-- hip crosshair (plain Frame, faded per line, hidden completely while aiming)
local cross = Instance.new("Frame")
cross.Name = "Crosshair"
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.Size = UDim2.fromOffset(240, 240)
cross.BackgroundTransparency = 1
cross.Parent = gui
local crossAll = {}
local function line(w, h)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	local s = Instance.new("UIStroke"); s.Transparency = 0.55; s.Parent = f
	f.Parent = cross
	table.insert(crossAll, { f = f, s = s })
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
panel.Size = UDim2.fromOffset(250, 84)
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
local ammoL = label(UDim2.fromOffset(16, 22), UDim2.fromOffset(90, 46), Enum.Font.GothamBlack, 44, Color3.new(1, 1, 1), Enum.TextXAlignment.Right)
local magL = label(UDim2.fromOffset(112, 38), UDim2.fromOffset(60, 24), Enum.Font.GothamBold, 18, Color3.fromRGB(150, 150, 160))
local modeL = label(UDim2.new(1, -78, 0, 42), UDim2.fromOffset(66, 16), Enum.Font.GothamBold, 11, ACCENT, Enum.TextXAlignment.Right)
local barBG = Instance.new("Frame")
barBG.Position = UDim2.new(0, 16, 1, -12); barBG.Size = UDim2.new(1, -28, 0, 4)
barBG.BackgroundColor3 = Color3.new(1, 1, 1); barBG.BackgroundTransparency = 0.85; barBG.BorderSizePixel = 0
barBG.Parent = panel
local barFill = Instance.new("Frame")
barFill.BorderSizePixel = 0; barFill.Size = UDim2.fromScale(1, 1); barFill.Parent = barBG

-- ================= STATE =================
local WEAPON, cfg, INTERVAL, sight
local built, partsList, cfList = nil, {}, {}
local IDENT = CFrame.identity
local ReloadAnims = require(RS:WaitForChild("ReloadAnims"))
local reloadAnim -- per-gun reload (ReloadAnims.lua), rebuilt on equip
local OFFSCREEN = CFrame.new(0, -500, 0)
local NEUTRAL_POSE
local HIP, SPRINT, AIM = CFrame.identity, CFrame.identity, CFrame.identity
local adsFov, adsSens = 58, 0.7

local ammo, reloading, reloadStart, reloadEvents = 0, false, 0, {}
local triggerDown, aimHeld, shiftHeld = false, false, false
local sprintToggle, stillTime = false, 0 -- mobile button / gamepad L3 sprint (tap to toggle)
local speedFov, speedLineAlpha, wasSliding, shakeRoll = 0, 0, false, 0
local windSound = Sfx.Loop and Sfx.Loop("Wind") or nil
local nextFireTime, bloom, sprayIndex, lastShotTime = 0, 0, 0, 0
local burstQueue, semiPending = 0, nil
local cycleStart = -10
local aimAlpha, sprintAlpha, equipStart = 0, 0, os.clock()
local slideAlpha, mantleAlpha, crouchAlpha = 0, 0, 0
local bobT, bobAmt, strafeRoll = 0, 0, 0
local wasGrounded, airVelY = true, 0
local flashUntil, flashRoll, flashVisible = 0, 0, false
local dmgAlpha = 0
local gunCF = camera.CFrame
local shotShift = CFrame.identity -- rotation from the camera center to where the sight/reticle really points (slides, crouch, mantle)
local scoped = false
local cleaned = false
local cleanup -- defined at the bottom

local recoilPos = Spring.new(400, 28)
local recoilRot = Spring.new(380, 24)
local camPunch = Spring.new(300, 26)
local fovPunch = Spring.new(350, 28)
local swaySpring = Spring.new(180, 18)
local landSpring = Spring.new(220, 16)

local climbTarget, climbOffset, applied = Vector2.zero, Vector2.zero, Vector2.zero
local lastPitch = nil

local fx = HitFX.new(gui)

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
local function magFov(mag) -- zoomed FOV for a magnified optic
	return math.deg(2 * math.atan(math.tan(rad(BASE_FOV / 2)) / mag))
end

local function modeText()
	if cfg.FireMode == "Burst" then return cfg.BurstCount .. "-BURST" end
	if cfg.Pellets > 1 then return "PUMP" end
	return string.upper(cfg.FireMode)
end

local function updateHUD()
	ammoL.Text = tostring(ammo)
	ammoL.TextColor3 = (ammo <= cfg.MagSize * 0.25) and Color3.fromRGB(255, 80, 80) or Color3.new(1, 1, 1)
	nameL.Text = reloading and "RELOADING" or cfg.Name
	magL.Text = "/ " .. cfg.MagSize
	modeL.Text = modeText() .. " · " .. (sight.Display or "Iron")
	if not reloading then
		barFill.BackgroundColor3 = Color3.new(1, 1, 1)
		barFill.Size = UDim2.fromScale(ammo / cfg.MagSize, 1)
	end
end

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
	elseif humanoid.MoveDirection.Magnitude > 0.1 then
		if cfg.SpreadMoveADS then s += cfg.SpreadMove + (cfg.SpreadMoveADS - cfg.SpreadMove) * aimAlpha
		else s += cfg.SpreadMove * (1 - aimAlpha * 0.5) end
	end
	return s + bloom
end

local function spreadDirection(dir, deg)
	if deg <= 0 then return dir end
	local r = rad(deg) * math.sqrt(math.random())
	local theta = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, 0, theta) * CFrame.Angles(r, 0, 0)).LookVector
end

-- own body is always invisible in first person (Roblox's own fade check fails at high fall speeds)
local bodyParts = {}
local function trackBody(d)
	if d:IsA("BasePart") or d:IsA("Decal") then bodyParts[d] = true end
end
for _, d in character:GetDescendants() do trackBody(d) end
local function hideBody()
	for d in bodyParts do
		if d.Parent and d:IsDescendantOf(character) then d.LocalTransparencyModifier = 1 else bodyParts[d] = nil end
	end
end

local function rotateCamera(dPitch, dYaw)
	local cf = camera.CFrame
	if (cf.LookVector.Y > 0.97 and dPitch > 0) or (cf.LookVector.Y < -0.97 and dPitch < 0) then dPitch = 0 end
	local pos = cf.Position
	camera.CFrame = CFrame.Angles(0, rad(dYaw), 0) * (cf - pos) * CFrame.Angles(rad(dPitch), 0, 0) + pos
end

local function ejectShell()
	if not cfg.Shell then return end
	local s = Instance.new("Part")
	s.Size = cfg.Shell.Size
	s.Color = cfg.Shell.Color
	s.Material = Enum.Material.Metal
	s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = false, false, false, false
	s.CFrame = gunCF * built.Points.Eject * CFrame.Angles(0, rad(90), 0)
	s.Parent = workspace
	local c = camera.CFrame
	s.AssemblyLinearVelocity = root.AssemblyLinearVelocity + c.RightVector * (7 + math.random() * 3)
		+ c.UpVector * (5 + math.random() * 3) - c.LookVector
	s.AssemblyAngularVelocity = Vector3.new(rnd(), rnd(), rnd()) * 30
	Debris:AddItem(s, 0.6)
end

-- ================= EQUIP (build viewmodel for the current weapon + sight) =================
local function equip(id, sightId)
	if cleaned then return end -- this character is gone: never build a new viewmodel
	if built then built.Model:Destroy() end
	WEAPON = Weapons.Weapons[id] and id or Weapons.Default
	cfg = Weapons.Get(WEAPON)
	if not Weapons.HasSight(cfg, sightId) then sightId = cfg.DefaultSight end
	INTERVAL = 60 / cfg.RPM

	built = GunModels.BuildViewmodel(cfg.Model, sightId, VM_SCALE)
	sight = built.Sight
	local ownerTag = Instance.new("ObjectValue") -- lets MatchClient tell whose viewmodel this is (and remove leftovers after a respawn)
	ownerTag.Name = "Owner"
	ownerTag.Value = character
	ownerTag.Parent = built.Model
	built.Model.Parent = camera
	partsList, cfList = {}, {}
	for _, g in { "gun", "cycle", "mag", "cover", "aux", "left", "flash" } do
		for _, e in built.Groups[g] do
			e.BaseSize = e.Part.Size
			table.insert(partsList, e.Part)
		end
	end

	reloadAnim = ReloadAnims.Make(cfg.Model, built.Points, VM_SCALE)
	NEUTRAL_POSE = { tilt = IDENT, mag = IDENT, hand = built.Points.Fore.Position, grab = 0, fall = false }
	local v = built.View or {}
	HIP = CFrame.new(v.X or 0.6, v.Y or -1.0, v.Z or -1.15) * CFrame.Angles(0, rad(2.5), 0)
	local sr = v.SprintRot or Vector3.new(-18, 48, 18)
	SPRINT = CFrame.new((v.X or 0.6) - 0.2, (v.Y or -1.0) - 0.15, (v.Z or -1.15) + 0.25) * CFrame.Angles(rad(sr.X), rad(sr.Y), rad(sr.Z))
	-- puts the sight's aim point exactly at screen center, Eye studs in front of the camera
	AIM = CFrame.new(0, 0, -built.Eye) * built.Points.Aim:Inverse()

	adsFov = sight.Mag and magFov(sight.Mag) or cfg.ADSFov
	adsSens = cfg.ADSSensitivity * (sight.Mag and math.tan(rad(adsFov / 2)) / math.tan(rad(cfg.ADSFov / 2)) or 1)

	ammo, reloading, reloadEvents = cfg.MagSize, false, {}
	nextFireTime, bloom, sprayIndex, burstQueue, semiPending = 0, 0, 0, 0, nil
	cycleStart = -10
	climbTarget = Vector2.zero
	equipStart = os.clock()
	flashVisible = true -- forces the flash refresh next frame
	Sfx.Play("Equip", nil, nil, nil, WEAPON)
	updateHUD()
end

-- ================= RELOAD =================

local function reloadPose(u)
	if u <= 0 or u >= 1 then return NEUTRAL_POSE end
	return reloadAnim.Pose(u)
end

local function startReload()
	if reloading or ammo == cfg.MagSize or humanoid.Health <= 0 or isCarrying() then return end
	reloading = true
	burstQueue, semiPending = 0, nil
	reloadStart = os.clock()
	reloadEvents = {}
	for _, e in reloadAnim.Events do
		table.insert(reloadEvents, { at = e.at, fn = function()
			Sfx.Play(e.snd, nil, e.pitch, e.vol, WEAPON)
			if e.kick then recoilPos:Impulse(e.kick[1]); recoilRot:Impulse(e.kick[2]) end
		end })
	end
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
	local baseDir = spreadDirection(shotShift:VectorToWorldSpace(camera.CFrame.LookVector), currentSpread())
	local pelletSpread = cfg.PelletSpread * (1 + (cfg.ADSPelletMult - 1) * aimAlpha)
	local muzzlePos = (gunCF * built.Points.Muzzle).Position
	local shots, hitModels = {}, {}

	for i = 1, cfg.Pellets do
		local dir = cfg.Pellets > 1 and spreadDirection(baseDir, pelletSpread) or baseDir
		local result = workspace:Raycast(origin, dir * cfg.Range, rayParams)
		local hitPos = result and result.Position or origin + dir * cfg.Range
		local hitPart = result and result.Instance
		shots[i] = { dir, hitPart, hitPos }
		if i <= 4 or i % 2 == 0 then fx:Tracer(muzzlePos, hitPos) end
		if hitPart then
			local model = hitPart:FindFirstAncestorOfClass("Model")
			if enemyHumanoid(model) then
				local h = hitModels[model] or { pos = hitPos, dir = dir, head = false }
				h.head = h.head or GunMath.IsHeadshot(hitPart)
				hitModels[model] = h
			elseif not (model and model:FindFirstChildOfClass("Humanoid")) then
				fx:Impact(hitPos, result.Normal, hitPart)
			end
		end
	end
	for model, h in hitModels do fx:Hit(model, h.pos, -h.dir, 0, h.head) end

	flashUntil = now + 0.035
	flashRoll = math.random() * math.pi * 2
	local fs = (0.8 + math.random() * 0.5) * (cfg.Pellets > 1 and 1.5 or 1)
	for _, e in built.Groups.flash do e.Part.Size = e.BaseSize * fs end
	if sprayIndex % 2 == 0 or cfg.FireMode ~= "Auto" then built.Smoke:Emit(1) end
	if cfg.Cycle then
		cycleStart = now
		if cfg.Cycle ~= "Slide" then task.delay(cfg.CycleDelay, function() Sfx.Play("Cycle", nil, nil, nil, WEAPON) end) end
	end
	if cfg.Cycle ~= "Bolt" and cfg.Cycle ~= "Pump" then ejectShell()
	else task.delay(cfg.CycleDelay + cfg.CycleTime * 0.4, function() if built then ejectShell() end end) end
	Sfx.Play("Fire", nil, cfg.FirePitch, cfg.FireVolume, WEAPON)
	Sfx.Play("FireTail", nil, cfg.FirePitch, cfg.FireVolume, WEAPON)
	if ammo <= cfg.MagSize * 0.25 then Sfx.Play("LowAmmo", nil, nil, nil, WEAPON) end

	FireRemote:FireServer(WEAPON, origin, shots)

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
local conns = {}
table.insert(conns, character.DescendantAdded:Connect(trackBody))

-- sprint button: shows on mobile (next to jump), gamepad = click left stick. Tap to toggle, turns off when you stop.
local SPRINT_ACTION = "SprintToggle"
local function paintSprintButton()
	local b = CAS:GetButton(SPRINT_ACTION)
	if b then b.ImageColor3 = sprintToggle and ACCENT or Color3.new(1, 1, 1) end
end
local function setSprintToggle(on)
	if sprintToggle == on then return end
	sprintToggle = on
	character:SetAttribute("SprintToggle", on)
	paintSprintButton()
end
CAS:BindAction(SPRINT_ACTION, function(_, state)
	if state == Enum.UserInputState.Begin then
		setSprintToggle(not sprintToggle)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.ButtonL3)
CAS:SetTitle(SPRINT_ACTION, "Sprint")
CAS:SetPosition(SPRINT_ACTION, UDim2.new(1, -95, 1, -175)) -- above the jump button
table.insert(conns, HitConfirm.OnClientEvent:Connect(function(model, head, killed, dmg, hitPos)
	if model and dmg and hitPos then fx:Number(model, hitPos, dmg, head) end
	if killed and model then
		local p = Players:GetPlayerFromCharacter(model)
		fx:Kill(model, p and p.DisplayName or model.Name)
	end
end))

table.insert(conns, ShotFX.OnClientEvent:Connect(function(shooter, origin, ends)
	if shooter == player then return end
	local char = shooter.Character
	local head = char and char:FindFirstChild("Head")
	local tpGun = char and char:FindFirstChild("TPGun", true)
	local muzzle = tpGun and tpGun:FindFirstChild("MuzzlePoint", true)
	local start = (muzzle and muzzle:IsA("Attachment") and muzzle.WorldPosition)
		or (head and head.Position + head.CFrame.LookVector) or origin
	if typeof(ends) == "Vector3" then ends = { ends } end
	if type(ends) ~= "table" then return end
	for i, e in ends do
		if typeof(e) == "Vector3" and i <= 6 then fx:Tracer(start, e) end
	end
	local wcfg = Weapons.Get(shooter:GetAttribute("Weapon"))
	if head then
		local wid = shooter:GetAttribute("Weapon")
		Sfx.Play("Fire", head, wcfg.FirePitch, wcfg.FireVolume, wid)
		Sfx.Play("FireTail", head, wcfg.FirePitch, wcfg.FireVolume, wid)
	end
end))

table.insert(conns, DamagedRemote.OnClientEvent:Connect(function(dmg)
	dmgAlpha = math.min(1, dmgAlpha + dmg / 35)
	camPunch:Impulse(Vector3.new(-8, rnd() * 10, rnd() * 40))
	Sfx.Play("Damaged")
end))

local function menuOpen() return player:GetAttribute("GunMenuOpen") == true end

table.insert(conns, UIS.InputBegan:Connect(function(input, gpe)
	if gpe or menuOpen() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		triggerDown = true
		semiPending = os.clock()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = true
	elseif input.KeyCode == Enum.KeyCode.R then startReload()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then shiftHeld = true end
end))
table.insert(conns, UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then triggerDown = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then shiftHeld = false end
end))

local swapQueued = false
local function onLoadoutChanged() -- deferred so Weapon + Sight changing together = one rebuild
	if swapQueued then return end
	swapQueued = true
	task.defer(function()
		swapQueued = false
		if cleaned then return end
		local id, s = player:GetAttribute("Weapon"), player:GetAttribute("Sight")
		if id ~= WEAPON or s ~= (built and built.SightId) then equip(id, s) end
	end)
end
table.insert(conns, player:GetAttributeChangedSignal("Weapon"):Connect(onLoadoutChanged))
table.insert(conns, player:GetAttributeChangedSignal("Sight"):Connect(onLoadoutChanged))
equip(player:GetAttribute("Weapon"), player:GetAttribute("Sight"))

-- ================= FIRE CONTROL =================
local function fireControl(now, canFire)
	if menuOpen() then triggerDown, aimHeld, semiPending, burstQueue = false, false, nil, 0 end
	-- a click slightly early (e.g. during a bolt/pump cycle) is buffered for 0.2s
	if semiPending and now - semiPending > 0.2 then semiPending = nil end
	if not canFire then
		if (triggerDown or semiPending) and ammo <= 0 and not reloading then startReload() end
		return
	end
	if cfg.FireMode == "Auto" then
		if triggerDown then
			if nextFireTime < now - INTERVAL then nextFireTime = now end
			while nextFireTime <= now and ammo > 0 do
				fire()
				nextFireTime += INTERVAL
			end
		end
	elseif cfg.FireMode == "Semi" then
		-- one shot per click
		if semiPending and now >= nextFireTime then
			semiPending = nil
			fire()
			nextFireTime = now + INTERVAL
		end
	else -- Burst (holding keeps bursting)
		if burstQueue == 0 and (triggerDown or semiPending) and now >= nextFireTime then
			burstQueue = math.min(cfg.BurstCount, ammo)
			semiPending = nil
			nextFireTime = now
		end
		while burstQueue > 0 and nextFireTime <= now and ammo > 0 do
			fire()
			burstQueue -= 1
			nextFireTime += burstQueue > 0 and 60 / cfg.BurstRPM or cfg.BurstDelay
		end
		if ammo <= 0 then burstQueue = 0 end
	end
end

-- ================= FRAME =================
local function onRender(dt)
	if cleaned then return end
	if not character:IsDescendantOf(workspace) then cleanup() return end -- respawned/teleported: this character is gone
	dt = math.min(dt, 0.1)
	local now = os.clock()
	local alive = humanoid.Health > 0
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local vel = root.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sliding = character:GetAttribute("Sliding") == true
	local mantling = character:GetAttribute("Mantling") == true
	local crouching = character:GetAttribute("Crouching") == true
	if menuOpen() then shiftHeld = false; setSprintToggle(false) end
	if sprintToggle then -- auto-off after standing still for a moment
		stillTime = moving and 0 or stillTime + dt
		if stillTime > 0.3 or not alive then setSprintToggle(false) end
	end
	if alive then hideBody() end

	-- states
	local carryingBox = isCarrying()
	if carryingBox then triggerDown, aimHeld, semiPending, burstQueue = false, false, nil, 0 end
	local aiming = aimHeld and not reloading and alive and not mantling and not carryingBox
	local wantsSprint = (shiftHeld or sprintToggle) and moving and not aiming and not triggerDown and not crouching
	local sprinting = wantsSprint and not sliding and not mantling
	local baseSpeed = (crouching and CROUCH_SPEED) or (wantsSprint and SPRINT_SPEED) or WALK_SPEED
	humanoid.WalkSpeed = baseSpeed * (carryingBox and MatchCfg.CARRY_SPEED_MULT or cfg.MoveSpeed)
	aimAlpha = approach(aimAlpha, aiming and 1 or 0, dt, cfg.ADSTime)
	sprintAlpha = approach(sprintAlpha, sprinting and 1 or 0, dt, 0.18)
	slideAlpha = approach(slideAlpha, sliding and 1 or 0, dt, 0.12)
	mantleAlpha = approach(mantleAlpha, mantling and 1 or 0, dt, 0.1)
	UIS.MouseDeltaSensitivity = 1 + (adsSens - 1) * aimAlpha

	-- firing
	local cycling = cfg.Cycle and cfg.Cycle ~= "Slide" and (now - cycleStart) < (cfg.CycleDelay + cfg.CycleTime)
	local canFire = alive and not carryingBox and not reloading and ammo > 0 and sprintAlpha < 0.3 and mantleAlpha < 0.4
		and (now - equipStart) > cfg.EquipTime and not cycling
	fireControl(now, canFire)
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
	-- slide rumble: tiny low-frequency noise, scales with speed, mostly gone while aiming
	local shakeAmt = SPEEDFX.SHAKE_DEG * slideAlpha * math.clamp(flatSpeed / 40, 0, 1.3) * (1 - aimAlpha * 0.85)
	local shakeP = math.noise(now * 9, 0.3) * shakeAmt
	local shakeY = math.noise(0.7, now * 9) * shakeAmt * 0.6
	shakeRoll = math.noise(now * 7, 5.1) * shakeAmt * 1.5
	local desired = climbOffset + Vector2.new(cp.X + shakeP, cp.Y + shakeY)
	local d = desired - applied
	applied = desired
	rotateCamera(d.X, d.Y)
	lastPitch = math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)))
	local slideRoll = -3 * slideAlpha * (1 - aimAlpha * 0.6)
	camera.CFrame *= CFrame.Angles(0, 0, rad(cp.Z + slideRoll + shakeRoll))

	-- slide start: short FOV kick + small dip
	if sliding and not wasSliding then
		fovPunch:Impulse(Vector3.new(SPEEDFX.SLIDE_FOV_PUNCH * (1 - aimAlpha * 0.8), 0, 0))
		landSpring:Impulse(Vector3.new(0, -1.6, 0))
	end
	wasSliding = sliding

	local fp = fovPunch:Update(dt)
	local fast = math.clamp((flatSpeed - SPEEDFX.FOV_FROM) / (SPEEDFX.FOV_TO - SPEEDFX.FOV_FROM), 0, 1)
	speedFov = approach(speedFov, fast * SPEEDFX.FOV_ADD, dt, 0.35)
	local fov = BASE_FOV + (SPRINT_FOV - BASE_FOV) * sprintAlpha + SLIDE_FOV_ADD * slideAlpha + speedFov
	local zoomFp = sight.Mag and fp.X / sight.Mag or fp.X
	camera.FieldOfView = fov + (adsFov - fov) * aimAlpha + zoomFp

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
		* CFrame.Angles(rad(math.abs(math.cos(bobT)) * 0.8 * b), 0, rad(math.sin(bobT) * 1.4 * b))
	local br = 1 - aimAlpha * 0.8
	local breathe = CFrame.new(0, math.sin(now * 1.7) * 0.01 * br, 0) * CFrame.Angles(rad(math.sin(now * 1.7) * 0.3 * br), 0, 0)

	local e = math.clamp((now - equipStart) / math.max(cfg.EquipTime + 0.15, 0.3), 0, 1)
	local ie = (1 - e) ^ 3
	local equipCF = CFrame.new(0.1 * ie, -0.9 * ie, 0.2 * ie) * CFrame.Angles(rad(-35 * ie), rad(-15 * ie), rad(20 * ie))

	local sk = smooth(slideAlpha)
	local skPos = sk * (1 - aimAlpha * 0.9)
	local skRoll = sk * (1 - aimAlpha * 0.75)
	local slideCF = CFrame.new(-0.1 * skPos, -0.05 * skPos, 0.12 * skPos)
		* CFrame.Angles(rad(3 * skPos), rad(4 * skPos), rad(-16 * skRoll))

	crouchAlpha = approach(crouchAlpha, crouching and 1 or 0, dt, 0.15)
	local ck = smooth(crouchAlpha) * (1 - aimAlpha)
	local crouchCF = CFrame.new(-0.04 * ck, -0.04 * ck, 0.03 * ck) * CFrame.Angles(0, 0, rad(-4 * ck))

	local mk = smooth(mantleAlpha)
	local mantleCF = CFrame.new(0.15 * mk, -0.75 * mk, 0.3 * mk)
		* CFrame.Angles(rad(-38 * mk), rad(22 * mk), rad(32 * mk))

	local rpose = reloadPose(reloading and reloadU or 0)
	local tiltCF, handPos, grab = rpose.tilt, rpose.hand, rpose.grab

	local rp, rr = recoilPos:Update(dt), recoilRot:Update(dt)
	local kp, kr = 1 - aimAlpha * 0.45, 1 - aimAlpha * 0.6
	local recoilCF = CFrame.new(rp.X * kp, rp.Y * kp, rp.Z * kp) * CFrame.Angles(rad(rr.X * kr), rad(rr.Y * kr), rad(rr.Z * kr))

	local ea = smooth(aimAlpha)
	local base = HIP:Lerp(AIM, ea):Lerp(SPRINT, sprintAlpha * (1 - aimAlpha))

	do -- bullets follow the sight: if a slide/crouch/mantle pushes the reticle off screen center, shoot through the reticle
		local aimLocal = CFrame.new(built.Points.Aim.Position)
		local vN = (camCF * base * aimLocal).Position - camCF.Position
		local vF = (camCF * base * mantleCF * slideCF * crouchCF * aimLocal).Position - camCF.Position
		local a, b = vN.Unit, vF.Unit
		local axis = a:Cross(b)
		local angle = math.min(math.acos(math.clamp(a:Dot(b), -1, 1)), rad(25)) * aimAlpha
		shotShift = axis.Magnitude > 1e-5 and CFrame.fromAxisAngle(axis.Unit, angle) or CFrame.identity
	end
	gunCF = camCF * base * mantleCF * slideCF * crouchCF * equipCF * CFrame.new(0, lp.Y, 0) * CFrame.Angles(rad(-lp.Y * 20), 0, 0)
		* breathe * bob * CFrame.Angles(rad(sw.X), rad(sw.Y), rad(sw.Z + strafeRoll))
		* tiltCF * recoilCF

	-- bolt / pump / slide travel
	local cycleZ = 0
	if cfg.Cycle then
		local u = (now - cycleStart - cfg.CycleDelay) / cfg.CycleTime
		if u > 0 and u < 1 then cycleZ = math.sin(math.pi * u) * cfg.CycleDist * VM_SCALE end
	end

	-- sniper scope: hide the gun and show the full-screen scope when fully aimed
	local wantScope = sight.Overlay == true and aimAlpha > 0.9
	if wantScope ~= scoped then
		scoped = wantScope
		scope.Visible = scoped
	end
	local vmParent = (not scoped and not carryingBox) and camera or nil -- gun is put away while carrying a box
	if built.Model.Parent ~= vmParent then built.Model.Parent = vmParent end

	if not scoped then
		local i = 0
		for _, g in built.Groups.gun do i += 1; cfList[i] = gunCF * g.Offset end
		local rz = rpose.cycleZ or cycleZ
		local cycleCF = gunCF * CFrame.new(0, 0, rz)
		for _, g in built.Groups.cycle do i += 1; cfList[i] = cycleCF * g.Offset end
		local magCF = gunCF * built.Points.MagPivot * rpose.mag
		for _, g in built.Groups.mag do i += 1; cfList[i] = rpose.fall and OFFSCREEN or (magCF * g.Offset) end
		local coverCF = gunCF * (rpose.cover or CFrame.identity)
		for _, g in built.Groups.cover do i += 1; cfList[i] = coverCF * g.Offset end
		for _, g in built.Groups.aux do
			i += 1
			local ac = rpose.aux and rpose.aux[g.Aux]
			cfList[i] = ac and (gunCF * ac * g.Offset.Rotation) or OFFSCREEN
		end
		if cfg.Cycle == "Pump" and grab == 0 then handPos += Vector3.new(0, 0, cycleZ) end
		local leftCF = gunCF * CFrame.new(handPos) * CFrame.Angles(rad(-20 * grab), 0, rad(-35 * grab))
		for _, g in built.Groups.left do i += 1; cfList[i] = leftCF * g.Offset end
		local flashCF = gunCF * built.Points.Muzzle * CFrame.Angles(0, 0, flashRoll)
		for _, g in built.Groups.flash do i += 1; cfList[i] = flashCF * g.Offset end
		workspace:BulkMoveTo(partsList, cfList, Enum.BulkMoveMode.FireCFrameChanged)
	end

	local flashOn = now < flashUntil
	if flashOn ~= flashVisible then
		flashVisible = flashOn
		for _, g in built.Groups.flash do g.Part.Transparency = flashOn and 0 or 1 end
		built.Light.Brightness = flashOn and 4 or 0
	end

	-- crosshair: spread gap, fades out fast and is fully hidden while aiming down sights
	local spread = currentSpread() + (cfg.Pellets > 1 and cfg.PelletSpread or 0)
	local gap = math.tan(rad(spread)) / math.tan(rad(camera.FieldOfView / 2)) * (camera.ViewportSize.Y / 2) + 5
	gap = math.min(gap, 110)
	for _, c in crossLines do
		c.f.Position = UDim2.new(0.5, c.d.X * (gap + 4), 0.5, c.d.Y * (gap + 4))
	end
	local hide = math.clamp(math.max(aimAlpha * 3, sprintAlpha * 1.3, mantleAlpha * 1.3), 0, 1)
	cross.Visible = hide < 0.99 and alive and not menuOpen() and not carryingBox
	for _, c in crossAll do
		c.f.BackgroundTransparency = hide
		c.s.Transparency = 0.55 + 0.45 * hide
	end
	if not menuOpen() and UIS.MouseIconEnabled then UIS.MouseIconEnabled = false end

	-- speed lines + wind
	local fwdSpeed = math.max(-localVel.Z, 0) * 0.6 + flatSpeed * 0.4 -- mostly forward motion
	local lineTarget = math.clamp((fwdSpeed - SPEEDFX.LINES_FROM) / (SPEEDFX.LINES_TO - SPEEDFX.LINES_FROM), 0, 1)
	lineTarget *= (1 - aimAlpha) * (alive and 1 or 0) * (scoped and 0 or 1)
	speedLineAlpha = approach(speedLineAlpha, lineTarget, dt, lineTarget > speedLineAlpha and 0.25 or 0.15)
	speedLayer.Visible = speedLineAlpha > 0.01
	for _, f in speedEdges do f.BackgroundTransparency = 1 - SPEEDFX.EDGE_MAX_ALPHA * speedLineAlpha end
	if speedLayer.Visible then
		local vp = camera.ViewportSize
		local half = vp * 0.5
		local reach = math.sqrt(half.X * half.X + half.Y * half.Y)
		for _, L in speedLines do
			L.r += dt * L.speed * (0.6 + speedLineAlpha * 0.9)
			if L.r > 1.15 then
				L.r = 0.68 + math.random() * 0.1
				L.angle += (math.random() - 0.5) * 0.4
				L.len = 60 + math.random() * 90
			end
			local dx, dy = math.cos(L.angle), math.sin(L.angle)
			local px, py = half.X + dx * reach * L.r, half.Y + dy * reach * L.r
			L.f.Position = UDim2.fromOffset(px, py)
			L.f.Size = UDim2.fromOffset(L.len * (0.6 + 0.4 * speedLineAlpha), L.w)
			L.f.Rotation = math.deg(math.atan2(dy, dx))
			local edgeFade = math.clamp((L.r - 0.68) / 0.12, 0, 1) * math.clamp((1.15 - L.r) / 0.15, 0, 1)
			L.f.BackgroundTransparency = 1 - SPEEDFX.LINES_MAX_ALPHA * speedLineAlpha * edgeFade
		end
	end
	if windSound then
		local w = math.clamp((flatSpeed - SPEEDFX.WIND_FROM) / (SPEEDFX.WIND_TO - SPEEDFX.WIND_FROM), 0, 1)
		windSound.Volume = approach(windSound.Volume, w * SPEEDFX.WIND_VOL * (alive and 1 or 0), dt, 0.3)
		windSound.PlaybackSpeed = 0.85 + w * 0.35
	end

	-- damage vignette
	dmgAlpha = math.max(0, dmgAlpha - dt * 2.2)
	local low = humanoid.Health < 50 and (1 - humanoid.Health / 50) * 0.5 or 0
	local va = math.max(dmgAlpha, low)
	for _, f in vignettes do f.BackgroundTransparency = 1 - va * 0.6 end
end

pcall(function() RunService:UnbindFromRenderStep(BIND) end)
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, onRender)

cleanup = function()
	if cleaned then return end
	cleaned = true
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	for _, c in conns do c:Disconnect() end
	fx:Destroy()
	if built then built.Model:Destroy() end
	UIS.MouseDeltaSensitivity = 1
	camera.FieldOfView = BASE_FOV
	if windSound then windSound:Destroy() end
	pcall(function() CAS:UnbindAction(SPRINT_ACTION) end)
end
humanoid.Died:Connect(cleanup)
character.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
script.Destroying:Connect(function() cleanup() end)
