-- MoveAnim v2 (v4.5: smooth distance-driven stride, big arm swing, new slide + dust) - was v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BOTH games. NEW in v4.1. Keep the two copies identical.
-- Real animations for WALKING, RUNNING (sprint), CROUCHING (idle + crouch-walk) and SLIDING, for EVERY player (what you see on other people; in the
-- Lobby you also see your own). It drives the R15 joint Transforms procedurally AFTER the Animator (RunService.Stepped), blending from whatever the
-- default animation did, so nothing needs animation assets. AbilityPose (wall run / climb) wins while AbilityMode is set; arms are left to
-- ThirdPersonClient's IK whenever the character holds a gun (Breakline) and animated here when it does not (Lobby, or a gadget in hand).
--   WALK    small stride, counter-swinging arms, a little torso twist
--   RUN     (speed > ~20) big stride with high knees, forward lean, pumping bent arms, head steady
--   CROUCH  deep knee bend + hunched torso; moving = a low shuffle
--   SLIDE   leans back, front leg out straight, back leg folded under, arms out for balance, head up
-- Sender: your own crouch / slide / sprint state is sent to the server (AbilityRemotes.Move -> character attributes MvCrouch / MvSlide / MvSprint) so
-- everybody else can see it (Breakline also has the Sliding / Crouching attributes from ThirdPersonServer; either source works).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local rad, sin, cos, abs, clamp, exp, max = math.rad, math.sin, math.cos, math.abs, math.clamp, math.exp, math.max
local CF = CFrame.Angles
local function approach(a, b, speed, dt) return a + (b - a) * (1 - exp(-speed * dt)) end

local abilityRemotes = RS:WaitForChild("AbilityRemotes", 15)
local MoveR = abilityRemotes and abilityRemotes:WaitForChild("Move", 10)

------------------------------------------------------------------ sender (your own state -> everybody)
local sent = { false, false, false }
local lastSendAt = 0
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not MoveR or not hum or hum.Health <= 0 then return end
	local slide = char:GetAttribute("Sliding") == true
	local crouch = char:GetAttribute("Crouching") == true
	local sprint = hum.MoveDirection.Magnitude > 0.1 and hum.WalkSpeed >= 22 and not slide and not crouch
	local now = os.clock()
	if (crouch ~= sent[1] or slide ~= sent[2] or sprint ~= sent[3]) and now - lastSendAt > 0.08 then
		sent = { crouch, slide, sprint }
		lastSendAt = now
		MoveR:FireServer(crouch, slide, sprint)
	end
end)

------------------------------------------------------------------ per character state
local states = {}

local function joint(char, part, name)
	local p = char:FindFirstChild(part)
	return p and p:FindFirstChild(name) or nil
end

local function setup(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not (hum and root and char:FindFirstChild("UpperTorso")) then return nil end
	local st = {
		char = char, hum = hum, root = root, phase = 0, loco = 0, run = 0, crouch = 0, slide = 0, moveAmt = 0, speed = 0, air = 0,
		slideSway = 0, bobSmooth = 0,
		rSh = joint(char, "RightUpperArm", "RightShoulder"), lSh = joint(char, "LeftUpperArm", "LeftShoulder"),
		rEl = joint(char, "RightLowerArm", "RightElbow"), lEl = joint(char, "LeftLowerArm", "LeftElbow"),
		rWr = joint(char, "RightHand", "RightWrist"), lWr = joint(char, "LeftHand", "LeftWrist"),
		rHip = joint(char, "RightUpperLeg", "RightHip"), lHip = joint(char, "LeftUpperLeg", "LeftHip"),
		rKnee = joint(char, "RightLowerLeg", "RightKnee"), lKnee = joint(char, "LeftLowerLeg", "LeftKnee"),
		rAnk = joint(char, "RightFoot", "RightAnkle"), lAnk = joint(char, "LeftFoot", "LeftAnkle"),
		waist = joint(char, "UpperTorso", "Waist"), neck = joint(char, "Head", "Neck"), rootJ = joint(char, "LowerTorso", "Root"),
	}
	if not (st.rHip and st.lHip and st.rKnee and st.lKnee and st.waist) then return nil end
	-- v2: dust kicked up while sliding (client-only emitter on the lower torso)
	local lt = char:FindFirstChild("LowerTorso")
	if lt then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "MoveAnimSlideDust"
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(190, 190, 195))
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.2) })
		pe.Lifetime = NumberRange.new(0.35, 0.65)
		pe.Speed = NumberRange.new(2, 6)
		pe.SpreadAngle = Vector2.new(35, 10)
		pe.EmissionDirection = Enum.NormalId.Back
		pe.Rate = 0
		pe.Enabled = false
		pe.LightEmission = 0.05
		pe.Parent = lt
		st.dust = pe
	end
	char.AncestryChanged:Connect(function(_, parent) if not parent then states[char] = nil end end)
	states[char] = st
	return st
end

local function getState(char)
	local st = states[char]
	if st and st.root.Parent then return st end
	states[char] = nil
	return setup(char)
end

local function blend(j, pose, w)
	if j and w > 0.001 then j.Transform = j.Transform:Lerp(pose, math.min(w, 1)) end
end

-- smooth helpers (no hard corners anywhere, so nothing snaps)
local function pos2(x) x = max(0, x) return x * x end            -- smooth "only the positive half"
local function smooth01(x) x = clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function frame(st, dt)
	local char, hum, root = st.char, st.hum, st.root
	dt = math.min(dt, 1 / 20)
	local dead = hum.Health <= 0
	local mode = char:GetAttribute("AbilityMode")
	local vel = root.AssemblyLinearVelocity
	local hsRaw = Vector3.new(vel.X, 0, vel.Z).Magnitude
	-- smoothed speed: remote players only update their velocity a few times a second, this hides the steps
	st.speed = approach(st.speed, hsRaw, hsRaw > st.speed and 9 or 6, dt)
	local hs = st.speed
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	local slide = (char:GetAttribute("MvSlide") == true or char:GetAttribute("Sliding") == true) and grounded
	local crouch = (char:GetAttribute("MvCrouch") == true or char:GetAttribute("Crouching") == true) and not slide
	local plr = Players:GetPlayerFromCharacter(char)
	local held = char:GetAttribute("HeldGadget") ~= nil
	local soulCarry = plr ~= nil and plr:GetAttribute("CarryingSoul") == true
	local reviving = char:GetAttribute("Reviving") == true
	local boxCarry = plr ~= nil and plr:GetAttribute("Carrying") == true
	-- arms belong to ThirdPersonClient's IK only while the gun is really in the hands
	local hasGun = char:FindFirstChild("TPGun") ~= nil and not held and not soulCarry and not reviving and not boxCarry
	local busy = dead or mode ~= nil or char:GetAttribute("Mantling") == true or hum.Sit

	-- weights (all eased, with a dead zone so they never flicker around a threshold)
	local moving = grounded and hs > 2 and not busy
	st.loco = approach(st.loco, (moving and not slide and not crouch) and 1 or 0, 10, dt)
	st.run = approach(st.run, smooth01((hs - 18) / 10), 6, dt)
	st.crouch = approach(st.crouch, (crouch and not busy) and 1 or 0, 11, dt)
	st.slide = approach(st.slide, (slide and not busy) and 1 or 0, 13, dt)
	st.moveAmt = approach(st.moveAmt, moving and clamp(hs / 14, 0, 1) or 0, 8, dt)
	st.arms = approach(st.arms or 0, (not hasGun and not busy and (held or soulCarry or reviving)) and 1 or 0, 14, dt)
	local sinceThrow = workspace:GetServerTimeNow() - (char:GetAttribute("GadgetThrowAt") or -10)
	st.throw = approach(st.throw or 0, (sinceThrow >= 0 and sinceThrow < 0.4) and 1 or 0, 22, dt)

	-- dust while sliding
	if st.dust then
		local on = st.slide > 0.6 and hs > 8
		st.dust.Enabled = on
		st.dust.Rate = on and clamp(hs * 1.1, 10, 60) or 0
	end
	if st.loco < 0.01 and st.crouch < 0.01 and st.slide < 0.01 and st.arms < 0.01 then return end

	-- stride clock follows DISTANCE travelled, so feet match the ground speed and never skate or stutter
	local run = st.run
	local radPerStud = 0.86 - 0.16 * run
	local rate = hs * radPerStud * (1 - 0.3 * st.crouch)
	st.phase = (st.phase + dt * rate) % (math.pi * 2)
	local p = st.phase
	local s1, s2 = sin(p), sin(p + math.pi)
	local c1, c2 = cos(p), cos(p + math.pi)
	local k = clamp(root.Size.Y / 2, 0.8, 1.4)

	------------------------------------------------ locomotion (walk -> run)
	if st.loco > 0.01 then
		local w = st.loco
		local amp = (0.5 + 0.5 * run) * clamp(hs / 11, 0.5, 1) -- hip swing (rad): ~29 deg walking, ~57 deg sprinting
		local kneeBase = 0.12 + 0.2 * run
		local kneeSwing = 0.4 + 1.1 * run
		blend(st.rHip, CF(s1 * amp, 0, 0), w)
		blend(st.lHip, CF(s2 * amp, 0, 0), w)
		blend(st.rKnee, CF(-(kneeBase + kneeSwing * pos2(c1) + 0.25 * run * pos2(-s1)), 0, 0), w)
		blend(st.lKnee, CF(-(kneeBase + kneeSwing * pos2(c2) + 0.25 * run * pos2(-s2)), 0, 0), w)
		blend(st.rAnk, CF(-0.3 * pos2(c1) * (0.5 + run) + 0.12 * pos2(-c1) * run, 0, 0), w)
		blend(st.lAnk, CF(-0.3 * pos2(c2) * (0.5 + run) + 0.12 * pos2(-c2) * run, 0, 0), w)
		-- body: forward lean, bounce on every foot strike, shoulders twist against the hips, little side sway
		local lean = rad(2 + 12 * run) * st.moveAmt
		local bob = -(0.5 + 0.5 * cos(2 * p)) * (0.05 + 0.13 * run) * k * st.moveAmt
		local twist = s1 * rad(7 + 15 * run) * st.moveAmt
		local roll = s1 * rad(1.5 + 3 * run) * st.moveAmt
		if st.rootJ then
			blend(st.rootJ, CFrame.new(0, bob, 0) * CF(-lean, -twist * 0.35, roll), w)
		end
		blend(st.waist, CF(-rad(1 + 2 * run), -twist * 0.65, -roll * 0.6), w)
		blend(st.neck, CF(rad(2 + 10 * run) * st.moveAmt, twist * 0.9, roll * 0.5), w) -- head stays level + forward while the body works
		if not hasGun then
			-- big arm swing, opposite to the legs; elbows fold up hard on the forward swing
			local sw = 0.55 + 0.85 * run
			local rS, lS = -s1 * sw, -s2 * sw
			local base = 0.3 + 0.55 * run
			local fwdR, fwdL = pos2(-s1), pos2(-s2)
			blend(st.rSh, CF(rS - 0.05, 0, rad(5 + 6 * run)), w)
			blend(st.lSh, CF(lS - 0.05, 0, -rad(5 + 6 * run)), w)
			blend(st.rEl, CF(base + (0.3 + 0.7 * run) * fwdR, 0, 0), w)
			blend(st.lEl, CF(base + (0.3 + 0.7 * run) * fwdL, 0, 0), w)
		end
	end

	------------------------------------------------ crouch (idle + shuffle)
	if st.crouch > 0.01 then
		local w = st.crouch
		local mv = st.moveAmt
		local shuf = 0.3 * mv
		local breathe = sin(os.clock() * 1.7) * rad(1.2)
		blend(st.rHip, CF(0.78 + s1 * shuf, 0, rad(3)), w)
		blend(st.lHip, CF(0.78 + s2 * shuf, 0, -rad(3)), w)
		blend(st.rKnee, CF(-1.25 - pos2(c1) * 0.4 * mv, 0, 0), w)
		blend(st.lKnee, CF(-1.25 - pos2(c2) * 0.4 * mv, 0, 0), w)
		blend(st.rAnk, CF(0.38 + 0.1 * pos2(c1) * mv, 0, 0), w)
		blend(st.lAnk, CF(0.38 + 0.1 * pos2(c2) * mv, 0, 0), w)
		if st.rootJ then blend(st.rootJ, CFrame.new(0, -0.1 * k, 0) * CF(-rad(8) - rad(2) * mv, 0, s1 * rad(2) * mv), w) end
		blend(st.waist, CF(-rad(8) + breathe, s1 * rad(5) * mv, 0), w)
		blend(st.neck, CF(rad(14), -s1 * rad(3) * mv, 0), w)
		if not hasGun then
			blend(st.rSh, CF(0.3 - s1 * 0.3 * mv, 0, rad(7)), w)
			blend(st.lSh, CF(0.3 - s2 * 0.3 * mv, 0, -rad(7)), w)
			blend(st.rEl, CF(0.95 + 0.2 * pos2(-s1) * mv, 0, 0), w)
			blend(st.lEl, CF(0.95 + 0.2 * pos2(-s2) * mv, 0, 0), w)
		end
	end

	------------------------------------------------ slide: body down on the ground, reclined, front leg straight, back leg tucked, one hand dragging, one hand out
	if st.slide > 0.01 then
		local w = st.slide
		local sp = clamp(hs / 36, 0, 1.2)
		st.slideSway = approach(st.slideSway, sin(os.clock() * 5.5) * 0.5 + 0.5, 6, dt)
		local shake = sin(os.clock() * 29) * 0.01 * sp
		local sway = (st.slideSway - 0.5) * rad(3)
		-- whole body: reclined (lean back about the hip) and dropped so the back / hip skim the ground
		if st.rootJ then blend(st.rootJ, CFrame.new(0, -0.15 * k, 0) * CF(rad(50), 0, sway), w) end
		blend(st.waist, CF(rad(8), -rad(6), 0), w)
		blend(st.neck, CF(-rad(52), rad(4), 0), w) -- keeps the face looking along the slide
		-- legs: right leg (front) stretched straight out, left leg folded under with the foot behind
		blend(st.rHip, CF(0.72 + shake, 0, -rad(5)), w)
		blend(st.rKnee, CF(-0.06, 0, 0), w)
		blend(st.rAnk, CF(0.55, 0, 0), w) -- toes up
		blend(st.lHip, CF(0.35 - shake, 0, rad(10)), w)
		blend(st.lKnee, CF(-1.95, 0, 0), w)
		blend(st.lAnk, CF(0.3, 0, 0), w)
		if not hasGun then
			-- left hand trails flat on the ground out to the side, right hand reaches forward / out for balance
			blend(st.lSh, CF(-0.55, 0, -rad(62)), w)
			blend(st.lEl, CF(0.12, 0, 0), w)
			blend(st.rSh, CF(1.75 + shake * 4, 0, rad(32)), w)
			blend(st.rEl, CF(0.2, 0, 0), w)
			if st.lWr then blend(st.lWr, CF(-0.4, 0, 0), w) end
		end
	end
end

-- (arm poses for an item in hand, a carried soul, a revive, and the throwing swing) are applied LAST so they win over the stride arms
local function armPoses(st)
	local w = st.arms or 0
	local char = st.char
	local reviving = char:GetAttribute("Reviving") == true
	local plr = Players:GetPlayerFromCharacter(char)
	local soulCarry = plr ~= nil and plr:GetAttribute("CarryingSoul") == true
	if w > 0.01 then
		if reviving then
			-- kneeling, both hands pressed down toward the soul, trembling a little with the effort
			local tremble = sin(os.clock() * 17) * 0.02
			blend(st.rSh, CF(1.05 + tremble, 0, rad(8)), w)
			blend(st.lSh, CF(1.05 - tremble, 0, -rad(8)), w)
			blend(st.rEl, CF(0.5, 0, 0), w)
			blend(st.lEl, CF(0.5, 0, 0), w)
		elseif soulCarry then
			-- both arms out in front, holding the soul
			blend(st.rSh, CF(1.2, 0, rad(10)), w)
			blend(st.lSh, CF(1.2, 0, -rad(10)), w)
			blend(st.rEl, CF(0.55, 0, 0), w)
			blend(st.lEl, CF(0.55, 0, 0), w)
		else
			-- item in the right hand (grenade / turret / projector), left arm relaxed, a little forward
			blend(st.rSh, CF(0.85, 0, rad(6)), w)
			blend(st.rEl, CF(1.15, 0, 0), w)
			blend(st.lSh, CF(0.35, 0, -rad(6)), w)
			blend(st.lEl, CF(0.5, 0, 0), w)
		end
	end
	if st.throw and st.throw > 0.01 then
		local t = st.throw
		blend(st.rSh, CF(-0.4 + 2.5 * (1 - t), 0, rad(14)), t) -- arm swings from back to front
		blend(st.rEl, CF(0.35, 0, 0), t)
		blend(st.waist, CF(0, rad(-12) * t, 0), t * 0.8)
	end
end

RunService.Stepped:Connect(function(_, dt)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char then
			local st = getState(char)
			if st then frame(st, dt) armPoses(st) end
		end
	end
end)
