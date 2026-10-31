-- MoveAnim v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BOTH games. NEW in v4.1. Keep the two copies identical.
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
		char = char, hum = hum, root = root, phase = 0, loco = 0, run = 0, crouch = 0, slide = 0, moveAmt = 0, lastY = 0, air = 0,
		rSh = joint(char, "RightUpperArm", "RightShoulder"), lSh = joint(char, "LeftUpperArm", "LeftShoulder"),
		rEl = joint(char, "RightLowerArm", "RightElbow"), lEl = joint(char, "LeftLowerArm", "LeftElbow"),
		rHip = joint(char, "RightUpperLeg", "RightHip"), lHip = joint(char, "LeftUpperLeg", "LeftHip"),
		rKnee = joint(char, "RightLowerLeg", "RightKnee"), lKnee = joint(char, "LeftLowerLeg", "LeftKnee"),
		rAnk = joint(char, "RightFoot", "RightAnkle"), lAnk = joint(char, "LeftFoot", "LeftAnkle"),
		waist = joint(char, "UpperTorso", "Waist"), neck = joint(char, "Head", "Neck"),
	}
	if not (st.rHip and st.lHip and st.rKnee and st.lKnee and st.waist) then return nil end
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
	if j and w > 0.001 then j.Transform = j.Transform:Lerp(pose, w) end
end

local function frame(st, dt)
	local char, hum, root = st.char, st.hum, st.root
	local dead = hum.Health <= 0
	local mode = char:GetAttribute("AbilityMode")
	local vel = root.AssemblyLinearVelocity
	local hs = Vector3.new(vel.X, 0, vel.Z).Magnitude
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

	-- weights
	local moving = grounded and hs > 1.2 and not busy
	st.loco = approach(st.loco, (moving and not slide and not crouch) and 1 or 0, moving and 14 or 9, dt)
	st.run = approach(st.run, clamp((hs - 17) / 10, 0, 1), 8, dt)
	st.crouch = approach(st.crouch, (crouch and not busy) and 1 or 0, 12, dt)
	st.slide = approach(st.slide, (slide and not busy) and 1 or 0, 16, dt)
	st.moveAmt = approach(st.moveAmt, moving and clamp(hs / 14, 0, 1) or 0, 10, dt)
	st.arms = approach(st.arms or 0, (not hasGun and not busy and (held or soulCarry or reviving)) and 1 or 0, 14, dt)
	local sinceThrow = workspace:GetServerTimeNow() - (char:GetAttribute("GadgetThrowAt") or -10)
	st.throw = approach(st.throw or 0, (sinceThrow >= 0 and sinceThrow < 0.4) and 1 or 0, 22, dt)
	if st.loco < 0.01 and st.crouch < 0.01 and st.slide < 0.01 and st.arms < 0.01 then return end

	-- stride clock: faster when you go faster; slower while crouch-walking
	local rate = (3.2 + hs * 0.22) * (1 - 0.35 * st.crouch)
	st.phase += dt * rate * (moving and 1 or 0.4)
	local p = st.phase
	local s1, s2 = sin(p), sin(p + math.pi)
	local c1, c2 = cos(p), cos(p + math.pi)
	local run = st.run

	------------------------------------------------ locomotion (walk -> run)
	if st.loco > 0.01 then
		local w = st.loco
		local amp = 0.5 + 0.45 * run -- hip swing in radians (~29 deg walking, ~54 deg running)
		local hipR, hipL = s1 * amp, s2 * amp
		local kneeBase = 0.1 + 0.15 * run
		local kneeSwing = 0.35 + 0.95 * run
		local kneeR = -(kneeBase + kneeSwing * max(0, c1))
		local kneeL = -(kneeBase + kneeSwing * max(0, c2))
		blend(st.rHip, CF(hipR, 0, 0), w)
		blend(st.lHip, CF(hipL, 0, 0), w)
		blend(st.rKnee, CF(kneeR, 0, 0), w)
		blend(st.lKnee, CF(kneeL, 0, 0), w)
		-- toes point down a bit when the foot leaves the ground
		blend(st.rAnk, CF(-0.25 * max(0, c1) * (0.5 + run), 0, 0), w)
		blend(st.lAnk, CF(-0.25 * max(0, c2) * (0.5 + run), 0, 0), w)
		-- torso: forward lean when running, a little shoulder / hip counter-twist
		local twist = s1 * rad(5 + 6 * run) * st.moveAmt
		blend(st.waist, CF(-rad(2 + 9 * run), -twist, 0), w)
		blend(st.neck, CF(rad(1 + 7 * run), twist * 0.8, 0), w) -- head stays level / forward while the body leans
		if not hasGun then
			local sw = (0.45 + 0.65 * run) -- arm swing
			local elb = 0.22 + 0.9 * run
			blend(st.rSh, CF(s2 * sw, 0, rad(4)), w)
			blend(st.lSh, CF(s1 * sw, 0, -rad(4)), w)
			blend(st.rEl, CF(elb + max(0, -s2) * 0.25 * run, 0, 0), w)
			blend(st.lEl, CF(elb + max(0, -s1) * 0.25 * run, 0, 0), w)
		end
	end

	------------------------------------------------ crouch (idle + shuffle)
	if st.crouch > 0.01 then
		local w = st.crouch
		local mv = st.moveAmt
		local shuf = 0.28 * mv
		blend(st.rHip, CF(0.72 + s1 * shuf, 0, rad(3)), w)
		blend(st.lHip, CF(0.72 + s2 * shuf, 0, -rad(3)), w)
		blend(st.rKnee, CF(-1.15 - max(0, c1) * 0.3 * mv, 0, 0), w)
		blend(st.lKnee, CF(-1.15 - max(0, c2) * 0.3 * mv, 0, 0), w)
		blend(st.rAnk, CF(0.35, 0, 0), w)
		blend(st.lAnk, CF(0.35, 0, 0), w)
		blend(st.waist, CF(-rad(10) + sin(os.clock() * 1.6) * rad(1), s1 * rad(3) * mv, 0), w)
		blend(st.neck, CF(rad(8), 0, 0), w)
		if not hasGun then
			blend(st.rSh, CF(0.25 + s2 * 0.18 * mv, 0, rad(5)), w)
			blend(st.lSh, CF(0.25 + s1 * 0.18 * mv, 0, -rad(5)), w)
			blend(st.rEl, CF(0.9, 0, 0), w)
			blend(st.lEl, CF(0.9, 0, 0), w)
		end
	end

	------------------------------------------------ slide
	if st.slide > 0.01 then
		local w = st.slide
		-- front (right) leg stretched out ahead, back (left) leg folded under, body leaning back, a slight vibration from speed
		local shake = sin(os.clock() * 31) * 0.012 * clamp(hs / 30, 0, 1.2)
		blend(st.rHip, CF(1.22 + shake, 0, rad(-4)), w)
		blend(st.rKnee, CF(-0.12, 0, 0), w)
		blend(st.rAnk, CF(0.35, 0, 0), w)
		blend(st.lHip, CF(0.55 - shake, 0, rad(6)), w)
		blend(st.lKnee, CF(-1.75, 0, 0), w)
		blend(st.lAnk, CF(0.2, 0, 0), w)
		blend(st.waist, CF(rad(14), 0, 0), w)
		blend(st.neck, CF(-rad(10), 0, 0), w) -- keep looking forward instead of at the sky
		if not hasGun then
			blend(st.rSh, CF(0.5, 0, rad(38)), w)
			blend(st.lSh, CF(0.2, 0, -rad(48)), w)
			blend(st.rEl, CF(0.5, 0, 0), w)
			blend(st.lEl, CF(0.5, 0, 0), w)
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
