-- ThirdPersonClient v3: IK hands on the gun, aim-driven gun joint, poses, recoil, reload, slide/crouch/mantle poses
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remotes = RS:WaitForChild("TPRemotes")
local Look = remotes:WaitForChild("TPLook")
local Shot = remotes:WaitForChild("TPShot")

local rad, exp, sin, cos, abs, clamp = math.rad, math.exp, math.sin, math.cos, math.abs, math.clamp
local V3 = Vector3.new

local CFG = {
	SEND_RATE = 20,
	ADS_FOV_BELOW = 66,
	SPRINT_SPEED_ABOVE = 20,
	TORSO_SHARE = 0.45, -- share of aim pitch taken by the upper torso (rest goes to the gun)
	NECK_SHARE = 0.5,
	SHOULDER = V3(0.45, 0.55, -0.3), -- gun pitch pivot (UpperTorso space)
	-- Gun poses in UpperTorso space: grip position, rotation in degrees (pitch, yaw, roll)
	POSES = {
		Hip    = { V3(0.42, 0.05, -1.2),   V3(0, 5, 0) },
		ADS    = { V3(0.2, 0.8, -1.0),     V3(0, 1, 0) },
		Sprint = { V3(0.25, -0.15, -0.95), V3(-38, 35, 25) },
		Reload = { V3(0.28, 0.0, -1.05),   V3(15, 20, -35) },
		Slide  = { V3(0.4, 0.15, -1.1),    V3(2, 6, -8) },
		Mantle = { V3(0.3, -0.25, -0.8),   V3(-55, 40, 30) },
	},
	RIGHT_POLE = V3(1.8, -1.2, 0.2),
	LEFT_POLE  = V3(-1.2, -1.8, -0.6),
	POUCH      = V3(-0.6, -0.05, -0.55), -- LowerTorso space
	KICK_BACK = 0.14, KICK_UP_DEG = 4, KICK_TORSO_DEG = 1.2,
	BOB = 0.035,
	TURN_LAG_DEG = 1.2, TURN_LAG_MAX = 7,
	SLIDE_LEAN = 25,
	CROUCH_LEAN = 10,
}

local Weapons = require(RS:WaitForChild("WeaponConfig"))
local Sfx
pcall(function() Sfx = require(RS:WaitForChild("Sfx", 3)) end)

local function approach(a, b, speed, dt) return a + (b - a) * (1 - exp(-speed * dt)) end
local function poseCF(p, k)
	return CFrame.new(p[1] * k) * CFrame.fromEulerAnglesYXZ(rad(p[2].X), rad(p[2].Y), rad(p[2].Z))
end
local function playAt(part, key, volume)
	if Sfx then Sfx.Play(key, part, 1, volume) end
end

------------------------------------------------------------------ setup per character
local states, retryAt = {}, {}

local function setup(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local ut, lt, head = char:FindFirstChild("UpperTorso"), char:FindFirstChild("LowerTorso"), char:FindFirstChild("Head")
	local gun = char:FindFirstChild("TPGun")
	if not (hum and root and ut and lt and head and gun and gun.PrimaryPart) then return nil end
	local waist, neck, rootJ = ut:FindFirstChild("Waist"), head:FindFirstChild("Neck"), lt:FindFirstChild("Root")
	local joint = ut:FindFirstChild("GunJoint")
	local rua, rh = char:FindFirstChild("RightUpperArm"), char:FindFirstChild("RightHand")
	local lua, lh = char:FindFirstChild("LeftUpperArm"), char:FindFirstChild("LeftHand")
	local rGrip, lFore, lMag = gun:FindFirstChild("RightGrip", true), gun:FindFirstChild("LeftForegrip", true), gun:FindFirstChild("LeftMagwell", true)
	if not (waist and neck and rootJ and joint and rua and rh and lua and lh and rGrip and lFore and lMag) then return nil end

	local k = ut.Size.Y / 1.6
	local created = {}
	local function att(parent, name, pos)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = pos * k
		a.Parent = parent
		table.insert(created, a)
		return a
	end
	local function ik(name, chainRoot, eff, target, pole)
		local c = Instance.new("IKControl")
		c.Name = name
		c.Type = Enum.IKControlType.Transform
		c.ChainRoot, c.EndEffector, c.Target, c.Pole = chainRoot, eff, target, pole
		c.Weight = 1
		c.SmoothTime = 0
		c.Parent = hum
		table.insert(created, c)
		return c
	end

	local st = {
		char = char, hum = hum, root = root, k = k, created = created,
		waist = waist, neck = neck, rootJ = rootJ, joint = joint,
		waistC0 = waist.C0, neckC0 = neck.C0, rootC0 = rootJ.C0,
		rHip = (char:FindFirstChild("RightUpperLeg") or {}).RightHip,
		lHip = (char:FindFirstChild("LeftUpperLeg") or {}).LeftHip,
		rKnee = (char:FindFirstChild("RightLowerLeg") or {}).RightKnee,
		lKnee = (char:FindFirstChild("LeftLowerLeg") or {}).LeftKnee,
		lFore = lFore, lMag = lMag, gun = gun,
		reloadTime = Weapons.Get(gun:GetAttribute("Weapon")).ReloadTime,
		shoulder = CFG.SHOULDER * k, poses = {},
		pitch = 0, ads = 0, sprint = 0, reload = 0, reloadT = 0, slide = 0, mantle = 0, crouch = 0,
		kick = 0, bobT = 0, turnLag = 0, flashToken = 0, wasSlide = false, restored = true,
	}
	for name, p in pairs(CFG.POSES) do st.poses[name] = poseCF(p, k) end

	st.pouch = att(lt, "TP_Pouch", CFG.POUCH)
	st.ikR = ik("TP_IK_Right", rua, rh, rGrip, att(ut, "TP_RightPole", CFG.RIGHT_POLE))
	st.ikL = ik("TP_IK_Left", lua, lh, lFore, att(ut, "TP_LeftPole", CFG.LEFT_POLE))

	st.magParts = {}
	for _, d in ipairs(gun:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("IsMag") then table.insert(st.magParts, d) end
	end
	local mag = gun:FindFirstChild("Mag")
	if mag then
		local hm = mag:Clone()
		hm:ClearAllChildren()
		hm.Name = "TP_HandMag"
		hm.Transparency = 1
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = lh, hm, CFrame.new(0.12, -0.1, 0)
		w.Parent = hm
		hm.Parent = char
		st.handMag = hm
		table.insert(created, hm)
	end

	char.AncestryChanged:Connect(function(_, parent)
		if not parent then states[char] = nil end
	end)
	states[char] = st
	return st
end

local function getState(char)
	local st = states[char]
	if st then
		if st.gun.Parent then return st end
		-- gun was swapped: reset the joints, remove the old IK rig so it can be rebuilt on the new gun
		st.waist.C0, st.neck.C0, st.rootJ.C0 = st.waistC0, st.neckC0, st.rootC0
		for _, inst in ipairs(st.created) do inst:Destroy() end
		states[char] = nil
	end
	if (retryAt[char] or 0) > os.clock() then return nil end
	st = setup(char)
	if not st then retryAt[char] = os.clock() + 0.5 end
	return st
end

local function restore(st)
	if st.restored then return end
	st.restored = true
	st.waist.C0, st.neck.C0, st.rootJ.C0 = st.waistC0, st.neckC0, st.rootC0
	st.ikR.Weight, st.ikL.Weight = 0, 0
end

------------------------------------------------------------------ per-frame pose
local function update(st, dt, t, isLocal)
	if st.hum.Health <= 0 then restore(st) return end
	st.restored = false
	st.ikR.Weight = 1

	st.pitch  = approach(st.pitch, t.pitch, 18, dt)
	st.ads    = approach(st.ads, (t.ads and not t.mantle) and 1 or 0, 15, dt)
	st.sprint = approach(st.sprint, (t.sprint and not t.ads and not t.slide) and 1 or 0, 9, dt)
	st.slide  = approach(st.slide, t.slide and 1 or 0, 14, dt)
	st.mantle = approach(st.mantle, t.mantle and 1 or 0, 18, dt)
	st.crouch = approach(st.crouch, (t.crouch and not t.slide) and 1 or 0, 12, dt)
	st.reload = approach(st.reload, t.reloading and 1 or 0, 12, dt)
	st.reloadT = t.reloading and (st.reloadT + dt) or 0
	st.kick = st.kick * exp(-dt * 16)

	if t.slide and not st.wasSlide and not isLocal then playAt(st.root, "Slide", 0.7) end
	st.wasSlide = t.slide

	local k = st.k
	-- gun lags slightly behind body turns
	local lv = st.root.CFrame.LookVector
	local yaw = math.atan2(-lv.X, -lv.Z)
	local d = yaw - (st.lastYaw or yaw)
	if d > math.pi then d -= 2 * math.pi elseif d < -math.pi then d += 2 * math.pi end
	st.lastYaw = yaw
	local lagTarget = clamp(-(d / math.max(dt, 1 / 240)) * CFG.TURN_LAG_DEG, -CFG.TURN_LAG_MAX, CFG.TURN_LAG_MAX)
	st.turnLag = approach(st.turnLag, lagTarget, 10, dt)

	-- walk bob
	local vel = st.root.AssemblyLinearVelocity
	local hs = V3(vel.X, 0, vel.Z).Magnitude
	local onGround = st.hum.FloorMaterial ~= Enum.Material.Air
	st.bobT += dt * hs * 0.55
	local amp = clamp(hs / 16, 0, 1.5) * (1 - 0.75 * st.ads) * (1 - st.slide) * (onGround and 1 or 0.25)
	local bob = CFrame.new(sin(st.bobT) * CFG.BOB * amp, -abs(cos(st.bobT)) * CFG.BOB * amp, 0)
		* CFrame.Angles(0, 0, sin(st.bobT) * rad(2.5) * amp)

	-- blended pose
	local P = st.poses
	local pose = P.Hip:Lerp(P.ADS, st.ads):Lerp(P.Slide, st.slide):Lerp(P.Sprint, st.sprint)
		:Lerp(P.Reload, st.reload):Lerp(P.Mantle, st.mantle)
	local lowered = math.max(st.sprint, st.mantle)
	local gunPitch = st.pitch * (1 - CFG.TORSO_SHARE) * (1 - 0.75 * lowered)
	local S = st.shoulder
	local aimCF = CFrame.new(S) * CFrame.Angles(gunPitch, rad(st.turnLag), 0) * CFrame.new(-S)
	local kick = CFrame.new(0, 0, CFG.KICK_BACK * st.kick * k) * CFrame.Angles(rad(CFG.KICK_UP_DEG * st.kick), 0, 0)
	st.joint.C0 = aimCF * pose * bob * kick

	-- body
	local torsoPitch = st.pitch * CFG.TORSO_SHARE * (1 - 0.5 * lowered) + rad(CFG.KICK_TORSO_DEG * st.kick) - rad(12) * st.slide
	st.waist.C0 = st.waistC0 * CFrame.Angles(torsoPitch, 0, 0)
	st.neck.C0 = st.neckC0 * CFrame.Angles(st.pitch * CFG.NECK_SHARE - rad(14) * st.slide, 0, 0)
	st.rootJ.C0 = st.rootC0 * CFrame.Angles(rad(CFG.SLIDE_LEAN) * st.slide - rad(CFG.CROUCH_LEAN) * st.crouch, 0, 0)

	-- left hand: foregrip, or reload sequence (mag -> pouch -> mag -> foregrip)
	local target, smooth = st.lFore, 0
	local phase = st.reloadT / st.reloadTime
	if t.reloading then
		smooth = 0.09
		if phase < 0.1 then target = st.lFore
		elseif phase < 0.38 then target = st.lMag
		elseif phase < 0.62 then target = st.pouch
		elseif phase < 0.86 then target = st.lMag
		end
	end
	if st.ikL.Target ~= target then st.ikL.Target = target end
	st.ikL.SmoothTime = smooth
	st.ikL.Weight = 1 - 0.9 * st.mantle

	local magOffGun = t.reloading and phase >= 0.36 and phase < 0.7
	for _, p in ipairs(st.magParts) do p.Transparency = magOffGun and 1 or 0 end
	if st.handMag then st.handMag.Transparency = (t.reloading and phase >= 0.5 and phase < 0.7) and 0 or 1 end
end

------------------------------------------------------------------ local player state + sending
local localT = { pitch = 0, ads = false, sprint = false, slide = false, mantle = false, crouch = false, reloading = false }
local lastSend, sent = 0, {}

local function isFirstPerson(char)
	local head = char and char:FindFirstChild("Head")
	return head and (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude < 1.5
end

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local cam = workspace.CurrentCamera
	localT.pitch = math.asin(clamp(cam.CFrame.LookVector.Y, -1, 1))
	localT.slide = char:GetAttribute("Sliding") == true
	localT.mantle = char:GetAttribute("Mantling") == true
	localT.crouch = char:GetAttribute("Crouching") == true
	localT.ads = cam.FieldOfView < CFG.ADS_FOV_BELOW and not localT.mantle
	localT.sprint = not localT.ads and hum.MoveDirection.Magnitude > 0.1 and hum.WalkSpeed >= CFG.SPRINT_SPEED_ABOVE
	localT.reloading = char:GetAttribute("Reloading") == true

	local now = os.clock()
	if now - lastSend < 1 / CFG.SEND_RATE then return end
	local changed = abs(localT.pitch - (sent.pitch or 0)) > 0.012 or localT.ads ~= sent.ads or localT.sprint ~= sent.sprint
		or localT.slide ~= sent.slide or localT.mantle ~= sent.mantle or localT.crouch ~= sent.crouch
	if changed or now - lastSend > 0.5 then
		Look:FireServer(localT.pitch, localT.ads, localT.sprint, localT.slide, localT.mantle, localT.crouch)
		sent = { pitch = localT.pitch, ads = localT.ads, sprint = localT.sprint, slide = localT.slide, mantle = localT.mantle, crouch = localT.crouch }
		lastSend = now
	end
end)

local function remoteTarget(char)
	return {
		pitch = char:GetAttribute("AimPitch") or 0,
		ads = char:GetAttribute("ADS") == true,
		sprint = char:GetAttribute("Sprint") == true,
		slide = char:GetAttribute("Sliding") == true,
		mantle = char:GetAttribute("Mantling") == true,
		crouch = char:GetAttribute("Crouching") == true,
		reloading = char:GetAttribute("Reloading") == true,
	}
end

------------------------------------------------------------------ main loops
local ok, preAnim = pcall(function() return RunService.PreAnimation end)
local poseSignal = (ok and preAnim) or RunService.Stepped

-- Runs before animation + IK, so the IK solves against the new gun/torso pose
poseSignal:Connect(function(a, b)
	local dt = (typeof(b) == "number") and b or a
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			local st = getState(char)
			if st then
				if plr == player then
					if isFirstPerson(char) then restore(st) else update(st, dt, localT, true) end
				else
					update(st, dt, remoteTarget(char), false)
				end
			end
		end
	end
end)

-- Leg pose for sliding / crouching (after the Animator so it overrides walk/run)
RunService.Stepped:Connect(function()
	for _, st in pairs(states) do
		if st.crouch > 0.01 and not st.restored and st.rHip and st.lHip and st.rKnee and st.lKnee then
			-- mostly crouch pose, a bit of the walk cycle still shows through so crouch-walking reads
			local c = st.crouch * 0.8
			st.rHip.Transform = st.rHip.Transform:Lerp(CFrame.Angles(rad(40), 0, 0), c)
			st.lHip.Transform = st.lHip.Transform:Lerp(CFrame.Angles(rad(40), 0, 0), c)
			st.rKnee.Transform = st.rKnee.Transform:Lerp(CFrame.Angles(rad(-65), 0, 0), c)
			st.lKnee.Transform = st.lKnee.Transform:Lerp(CFrame.Angles(rad(-65), 0, 0), c)
		end
		if st.slide > 0.01 and not st.restored and st.rHip and st.lHip and st.rKnee and st.lKnee then
			local a = st.slide
			st.rHip.Transform = st.rHip.Transform:Lerp(CFrame.Angles(rad(60), 0, 0), a)
			st.rKnee.Transform = st.rKnee.Transform:Lerp(CFrame.Angles(rad(-12), 0, 0), a)
			st.lHip.Transform = st.lHip.Transform:Lerp(CFrame.Angles(rad(18), 0, rad(-8)), a)
			st.lKnee.Transform = st.lKnee.Transform:Lerp(CFrame.Angles(rad(-100), 0, 0), a)
		end
	end
end)

------------------------------------------------------------------ shots from other players
Shot.OnClientEvent:Connect(function(char)
	if typeof(char) ~= "Instance" or char == player.Character or not char.Parent then return end
	local st = getState(char)
	if st then st.kick = math.min(st.kick + 1, 2.5) end

	local gun = char:FindFirstChild("TPGun")
	if not gun then return end
	local flash = gun:FindFirstChild("Flash")
	local muzzle = gun:FindFirstChild("Muzzle")
	local light = muzzle and muzzle:FindFirstChild("FlashLight")
	local token = (st and st.flashToken or 0) + 1
	if st then st.flashToken = token end
	local sc = gun:GetAttribute("Scale") or 1
	if flash then
		flash.Transparency = 0.1
		local s = (0.3 + math.random() * 0.15) * sc * 1.6
		flash.Size = V3(s, s, (0.5 + math.random() * 0.35) * sc * 1.6)
	end
	if light then light.Enabled = true end
	task.delay(0.045, function()
		if st and st.flashToken ~= token then return end
		if flash then flash.Transparency = 1 end
		if light then light.Enabled = false end
	end)
end)

------------------------------------------------------------------ hide own gear/gun in first person
RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then return end
	local ltm = isFirstPerson(char) and 1 or 0
	for _, name in ipairs({ "Gear", "TPGun" }) do
		local f = char:FindFirstChild(name)
		if f then
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("BasePart") then d.LocalTransparencyModifier = ltm end
			end
		end
	end
	local hm = char:FindFirstChild("TP_HandMag")
	if hm then hm.LocalTransparencyModifier = ltm end
end)
