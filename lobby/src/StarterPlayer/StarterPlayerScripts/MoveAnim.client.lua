-- MoveAnim v3.4 (v5.18: calmer run arms - the arms follow a slower, smoothed swing with a smaller arc while the legs keep the pace, longer strides at a sprint;
--   new athletic JUMP pose - both knees gently tucked, slight lean, arms low and out for balance, no more fist thrown over the head) (both games, identical)
-- MoveAnim v3.3 (v5.16: stands down while a character holds a POSE - PoseClient animates it) (v3.2 v4.9: new grenade-ready hold pose + a real 3-beat throw - cock, whip, follow-through - and an underhand toss, timed to the release) (was v3.1 v4.7: crouch + slide GROUND CLEARANCE - the lowest part of the body is measured every frame and the body is lifted until nothing sinks into the floor; slide wobble removed (no more shaking right hand / swaying body)) (v3: v4.6: sprint-leap AIR POSE so jumps keep their momentum look, tactical half-kneel CROUCH fitted to the real leg lengths + hip height so the feet never sink into the floor)
-- (v2 header:) MoveAnim v2 (v4.5: smooth distance-driven stride, big arm swing, new slide + dust) - was v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BOTH games. NEW in v4.1. Keep the two copies identical.
-- Real animations for WALKING, RUNNING (sprint), CROUCHING (idle + crouch-walk) and SLIDING, for EVERY player (what you see on other people; in the
-- Lobby you also see your own). It drives the R15 joint Transforms procedurally AFTER the Animator (RunService.Stepped), blending from whatever the
-- default animation did, so nothing needs animation assets. AbilityPose (wall run / climb) wins while AbilityMode is set; arms are left to
-- ThirdPersonClient's IK whenever the character holds a gun (Breakline) and animated here when it does not (Lobby, or a gadget in hand).
--   WALK    small stride, counter-swinging arms, a little torso twist
--   RUN     (speed > ~20) big stride with high knees, forward lean, pumping bent arms, head steady
--   CROUCH  half-kneel (one foot planted forward, back knee dropped, hunched torso, front arm on the knee); moving = a low stagger
--   AIR     lead leg driven forward with a bent knee, trailing leg back, torso leaning into the jump, arms pumping; the legs reach down on the way down
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
local THROW_LEN, throwSwing = 0.79, nil -- v4.9 (set in the THROW section below)

local rayP = RaycastParams.new()
rayP.FilterType = Enum.RaycastFilterType.Exclude
rayP.RespectCanCollide = true
local function groundGap(st) -- distance from the root centre straight down to the floor (nil when there is none under it)
	local ig = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ig, p.Character) end end
	rayP.FilterDescendantsInstances = ig
	local r = workspace:Raycast(st.root.Position, Vector3.new(0, -12, 0), rayP)
	return r and r.Distance or nil
end

-- v4.7: ground clearance. The lowest point of the (posed) body is compared with the floor under the root; whatever sinks in is lifted back out.
-- Measured on the previous frame, applied as an integrator, so it settles on "just touching the floor" without ever jittering.
local function lowestPartY(char)
	local low = math.huge
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			local cf, sz = p.CFrame, p.Size
			local ext = (abs(cf.RightVector.Y) * sz.X + abs(cf.UpVector.Y) * sz.Y + abs(cf.LookVector.Y) * sz.Z) * 0.5 * 0.9
			low = math.min(low, cf.Position.Y - ext)
		end
	end
	return low
end
local function updateLift(st, dt)
	if st.crouch > 0.01 or st.slide > 0.01 then
		local gap = groundGap(st)
		if gap then
			local floorY = st.root.Position.Y - gap
			local pen = (floorY + 0.05) - lowestPartY(st.char) -- > 0: part of the body is inside the floor
			st.lift = clamp((st.lift or 0) + pen * math.min(1, dt * 14), 0, 1.6)
		end
	else
		st.lift = approach(st.lift or 0, 0, 12, dt)
	end
end

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
		slideSway = 0, bobSmooth = 0, airW = 0, lead = 1, wasGrounded = true, nextBase = 0,
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
		or char:GetAttribute("Pose") ~= nil -- v5.16: PoseClient owns every joint while the character holds a pose

	-- weights (all eased, with a dead zone so they never flicker around a threshold)
	local moving = grounded and hs > 2 and not busy
	st.loco = approach(st.loco, (moving and not slide and not crouch) and 1 or 0, 10, dt)
	st.run = approach(st.run, smooth01((hs - 18) / 10), 6, dt)
	st.crouch = approach(st.crouch, (crouch and not busy) and 1 or 0, 11, dt)
	st.slide = approach(st.slide, (slide and not busy) and 1 or 0, 13, dt)
	st.moveAmt = approach(st.moveAmt, moving and clamp(hs / 14, 0, 1) or 0, 8, dt)
	if st.wasGrounded and not grounded then st.lead = (sin(st.phase) >= 0) and 1 or -1 end -- the leg that was forward at take-off leads the jump
	st.wasGrounded = grounded
	st.airW = approach(st.airW, (not grounded and not busy and not slide) and 1 or 0, 12, dt)
	st.arms = approach(st.arms or 0, (not hasGun and not busy and (held or soulCarry or reviving)) and 1 or 0, 14, dt)
	-- v4.9: the throw is a timed 3-beat swing (see armPoses), driven straight from the time since GadgetThrowAt
	st.sinceThrow = workspace:GetServerTimeNow() - (char:GetAttribute("GadgetThrowAt") or -10)
	st.throwUnder = char:GetAttribute("GadgetThrowUnder") == true
	st.throw = (st.sinceThrow >= 0 and st.sinceThrow < THROW_LEN) and 1 or 0

	-- v4.6: remember the real standing hip height (used by the crouch fit); measured, so it also holds for other players
	if st.crouch < 0.02 and st.slide < 0.02 and grounded and os.clock() >= st.nextBase then
		st.nextBase = os.clock() + 0.5
		local gap = groundGap(st)
		if gap then st.baseEff = gap - root.Size.Y / 2 end
	end

	-- dust while sliding
	if st.dust then
		local on = st.slide > 0.6 and hs > 8
		st.dust.Enabled = on
		st.dust.Rate = on and clamp(hs * 1.1, 10, 60) or 0
	end
	updateLift(st, dt)
	if st.loco < 0.01 and st.crouch < 0.01 and st.slide < 0.01 and st.arms < 0.01 and st.airW < 0.01 then return end

	-- stride clock follows DISTANCE travelled, so feet match the ground speed and never skate or stutter
	local run = st.run
	local radPerStud = 0.86 - 0.3 * run -- v5.18: longer, calmer strides at sprint speed (0.70 -> 0.56 rad per stud): legs + arms cycle slower, the speed stays
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
			-- arm swing, opposite to the legs. v5.18 (owner: "the hands move really really quick when running, slow the arm swinging, keep the character fast"):
			-- the arms have their OWN swing clock: walking it stays locked to the legs, sprinting it runs 40 % slower than the stride (ARM_SLOW), with a
			-- smaller arc and a calmer elbow pump, so the hands no longer flicker back and forth
			local ARM_SLOW = 0.4
			st.armPhase = st.armPhase or p
			local d = (p - st.armPhase + math.pi) % (2 * math.pi) - math.pi
			st.armPhase = (st.armPhase + dt * rate * (1 - ARM_SLOW * run) + d * math.min(1, dt * 6) * (1 - run)) % (2 * math.pi)
			local a1, a2 = sin(st.armPhase), sin(st.armPhase + math.pi)
			local sw = 0.5 + 0.45 * run
			local rS, lS = -a1 * sw, -a2 * sw
			local base = 0.35 + 0.45 * run
			local fwdR, fwdL = pos2(-a1), pos2(-a2)
			blend(st.rSh, CF(rS - 0.08 * run, 0, rad(5 + 5 * run)), w)
			blend(st.lSh, CF(lS - 0.08 * run, 0, -rad(5 + 5 * run)), w)
			blend(st.rEl, CF(base + (0.25 + 0.35 * run) * fwdR, 0, 0), w)
			blend(st.lEl, CF(base + (0.25 + 0.35 * run) * fwdL, 0, 0), w)
		end
	end

	------------------------------------------------ air: v5.18 ATHLETIC JUMP (owner: the old one looked like Mario punching up at a block - one knee up high and one fist
	-- thrown up over the head). Now: both legs gently tucked (the lead knee a little higher), a slight forward lean, arms low + a little out to the sides for
	-- balance (no arm goes above the shoulder); on the way down the legs open up and reach for the ground and the arms drift out.
	if st.airW > 0.01 then
		local w = st.airW
		local fwd = clamp(hs / 22, 0, 1)                                  -- how fast you are going
		local vy = root.AssemblyLinearVelocity.Y
		local fall = clamp(-vy / 45, 0, 1)                                -- coming down: legs reach for the ground
		local rise = clamp(vy / 30, 0, 1)
		local tuck = (1 - fall) * (0.55 + 0.45 * rise)                    -- how tucked the legs are (most at take-off / the top)
		local rightLeads = st.lead == 1
		local lHipJ, lKneeJ, lAnkJ = rightLeads and st.rHip or st.lHip, rightLeads and st.rKnee or st.lKnee, rightLeads and st.rAnk or st.lAnk
		local tHipJ, tKneeJ, tAnkJ = rightLeads and st.lHip or st.rHip, rightLeads and st.lKnee or st.rKnee, rightLeads and st.lAnk or st.rAnk
		-- lead leg: thigh a bit forward, knee bent; trail leg: thigh under / slightly back, knee bent more (heel up behind) - a calm, compact shape
		blend(lHipJ, CF(0.25 + 0.35 * fwd * tuck + 0.25 * tuck - 0.2 * fall, 0, rad(2)), w)
		blend(lKneeJ, CF(-(0.45 + 0.45 * tuck - 0.25 * fall), 0, 0), w)
		blend(lAnkJ, CF(0.1 + 0.15 * fall, 0, 0), w)
		blend(tHipJ, CF(-0.12 - 0.22 * fwd + 0.15 * tuck + 0.15 * fall, 0, -rad(2)), w)
		blend(tKneeJ, CF(-(0.6 + 0.4 * tuck + 0.15 * fwd - 0.3 * fall), 0, 0), w)
		blend(tAnkJ, CF(-0.15 - 0.15 * fwd, 0, 0), w)
		-- torso: a slight lean into the jump, head level
		if st.rootJ then blend(st.rootJ, CF(-rad(2 + 7 * fwd) * (1 - 0.5 * fall), 0, 0), w) end
		blend(st.waist, CF(-rad(2 + 3 * fwd), 0, 0), w)
		blend(st.neck, CF(rad(3 + 8 * fwd), 0, 0), w)
		if not hasGun then
			-- arms: low, slightly forward (the one opposite the lead leg a touch more), out to the sides for balance; they spread a bit more on the way down
			local out = rad(14 + 12 * fall)
			local fArm, bArm = 0.25 + 0.25 * fwd + 0.1 * rise, -0.1 - 0.2 * fwd
			local rS, lS = rightLeads and bArm or fArm, rightLeads and fArm or bArm
			blend(st.rSh, CF(rS, 0, out), w)
			blend(st.lSh, CF(lS, 0, -out), w)
			blend(st.rEl, CF(0.45 + 0.15 * rise, 0, 0), w)
			blend(st.lEl, CF(0.45 + 0.15 * rise, 0, 0), w)
		end
	end

	------------------------------------------------ crouch: tactical HALF-KNEEL when standing still (right foot planted forward, left knee dropped,
	-- back hunched, right hand resting on the knee), a low alternating stagger while moving.
	-- v4.6: the body height is FITTED to the pose. Movement lowers HipHeight by a fixed amount, but the legs only get shorter by what the pose
	-- needs, and the old pose was not long enough, so the feet sank into the floor. Now the leg reach of the pose is computed from the real
	-- UpperLeg / LowerLeg sizes (tall rigs included), compared with how far the root really dropped (measured with a ray, so it also works for
	-- other players), and the torso is moved up / down by the difference.
	if st.crouch > 0.01 then
		local w = st.crouch
		local mv = st.moveAmt
		local kneel = 1 - mv
		local breathe = sin(os.clock() * 1.7) * rad(1.2)
		local aR = kneel * 1.40 + mv * (0.95 + 0.38 * s1)          -- hip angles (+ = thigh forward)
		local bR = kneel * 1.75 + mv * (1.55 + 0.25 * pos2(c1))    -- knee bend (+)
		local aL = kneel * -0.12 + mv * (0.95 + 0.38 * s2)
		local bL = kneel * 1.35 + mv * (1.55 + 0.25 * pos2(c2))
		blend(st.rHip, CF(aR, 0, rad(3)), w)
		blend(st.lHip, CF(aL, 0, -rad(3)), w)
		blend(st.rKnee, CF(-bR, 0, 0), w)
		blend(st.lKnee, CF(-bL, 0, 0), w)
		blend(st.rAnk, CF(clamp(bR - aR, -0.2, 1.0), 0, 0), w)                              -- front foot flat on the floor
		blend(st.lAnk, CF(kneel * 0.15 + mv * clamp(bL - aL, -0.2, 1.0), 0, 0), w)         -- back foot tucked (instep down) while kneeling
		-- body height fitted to the pose
		if st.rootJ then
			local ul = char:FindFirstChild("RightUpperLeg")
			local ll = char:FindFirstChild("RightLowerLeg")
			local T = ul and ul.Size.Y or 1.2
			local S = ll and ll.Size.Y or 1.2
			local reach = math.max(T * cos(aR) + S * cos(aR - bR), T * cos(aL) + S * cos(aL - bL)) -- how far down the lowest part of the legs reaches
			local gap = groundGap(st)
			local base = st.baseEff or hum.HipHeight
			local eff = gap and (gap - root.Size.Y / 2) or base
			st.hEff = st.hEff and approach(st.hEff, eff, 20, dt) or eff
			local delta = clamp((reach - (T + S)) + (base - st.hEff), -0.7, 1.3)
			blend(st.rootJ, CFrame.new(0, delta + (st.lift or 0), 0) * CF(-rad(7) - rad(2) * mv, 0, s1 * rad(2) * mv), w)
		end
		blend(st.waist, CF(-rad(11) + breathe, s1 * rad(5) * mv, 0), w)
		blend(st.neck, CF(rad(20), -s1 * rad(3) * mv, 0), w)
		if not hasGun then
			blend(st.rSh, CF(0.95 * kneel + (0.3 - s1 * 0.3) * mv, 0, rad(8)), w)
			blend(st.lSh, CF(0.12 * kneel + (0.3 - s2 * 0.3) * mv, 0, -rad(10)), w)
			blend(st.rEl, CF(0.8 * kneel + (0.95 + 0.2 * pos2(-s1)) * mv, 0, 0), w)
			blend(st.lEl, CF(0.5 * kneel + (0.95 + 0.2 * pos2(-s2)) * mv, 0, 0), w)
		end
	end

	------------------------------------------------ slide: body down on the ground, reclined, front leg straight, back leg tucked, one hand dragging, one hand out
	if st.slide > 0.01 then
		local w = st.slide
		local sp = clamp(hs / 36, 0, 1.2)
		local shake, sway = 0, 0 -- v4.7: no wobble (the shaking right hand / swaying body is gone)
		-- whole body: reclined (lean back about the hip) and dropped so the back / hip skim the ground
		if st.rootJ then blend(st.rootJ, CFrame.new(0, -0.15 * k + (st.lift or 0), 0) * CF(rad(50), 0, sway), w) end
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
			blend(st.rSh, CF(1.75, 0, rad(32)), w)
			blend(st.rEl, CF(0.2, 0, 0), w)
			if st.lWr then blend(st.lWr, CF(-0.4, 0, 0), w) end
		end
	end
end

-- v4.9 THROW: 3 beats keyed to the server's GadgetThrowAt (the item leaves the hand at WINDUP, exactly when GadgetServer launches it)
--   cock (0 .. WINDUP)          throwing arm up + back behind the head, elbow bent, torso turned away, left arm points at the target
--   whip (.. + 0.12)            the arm snaps over the top, the torso turns through, weight onto the front
--   follow-through (.. + 0.25)  the arm finishes low across the body, then everything eases back over the last 0.3 s
-- Underhand (right click): arm low behind the hip, swings forward and up, the body dips a little.
local THROWABLE = { FRAG = true, SMOKE = true, FLASH = true }
local WINDUP = 0.12 -- = GadgetConfig.Throw.Windup (that module only exists in Breakline, so the number is copied here)
THROW_LEN = WINDUP + 0.37 + 0.3
local function lerpN(a, b, t) return a + (b - a) * t end
local function ease(t) t = clamp(t, 0, 1) return t * t * (3 - 2 * t) end
-- key poses: rSh pitch / roll, rEl, lSh pitch / roll, lEl, waist yaw, waist pitch (radians; + pitch = arm forward / up)
local OVER = {
	{ 0.0, 0.3, 1.0, 0.4, -0.3, 1.0, 0.0, 0.0 },        -- start (blends from the hold)
	{ 2.75, 0.55, 1.9, 1.45, -0.25, 0.25, -0.45, -0.08 }, -- cocked
	{ 1.55, 0.2, 0.25, 0.6, -0.45, 1.5, 0.4, 0.12 },     -- whip (release)
	{ 0.2, -0.45, 0.45, 0.25, -0.2, 1.1, 0.35, 0.16 },   -- follow-through
}
local UNDER = {
	{ 0.0, 0.3, 1.0, 0.4, -0.3, 1.0, 0.0, 0.0 },
	{ -0.75, 0.25, 0.35, 0.7, -0.3, 0.9, -0.25, 0.1 },
	{ 1.35, 0.1, 0.2, 0.45, -0.3, 1.1, 0.2, 0.05 },
	{ 1.6, 0.0, 0.3, 0.35, -0.25, 1.0, 0.15, 0.0 },
}
function throwSwing(st)
	local tt = st.sinceThrow or 99
	local K = st.throwUnder and UNDER or OVER
	local a, b, u
	if tt < WINDUP then a, b, u = K[1], K[2], ease(tt / WINDUP)
	elseif tt < WINDUP + 0.12 then a, b, u = K[2], K[3], ease((tt - WINDUP) / 0.12)
	elseif tt < WINDUP + 0.37 then a, b, u = K[3], K[4], ease((tt - WINDUP - 0.12) / 0.25)
	else a, b, u = K[4], K[4], 0 end
	local w = 1 - ease((tt - WINDUP - 0.37) / 0.3) -- fade back to the normal pose at the end
	local function v(i) return lerpN(a[i], b[i], u) end
	blend(st.rSh, CF(v(1), 0, v(2)), w)
	blend(st.rEl, CF(v(3), 0, 0), w)
	blend(st.lSh, CF(v(4), 0, v(5)), w)
	blend(st.lEl, CF(v(6), 0, 0), w)
	blend(st.waist, CF(v(8), v(7), 0), w * 0.9)
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
		elseif THROWABLE[char:GetAttribute("HeldGadget")] then
			-- v4.9 grenade ready: held at chest height in the right hand, elbow down and tucked, forearm up; the left hand rests beside it
			-- (on the pin) so both arms frame the grenade like a real throw-ready stance
			local br = sin(os.clock() * 1.6) * 0.03
			blend(st.rSh, CF(0.55 + br, 0, rad(18)), w)
			blend(st.rEl, CF(1.75, 0, 0), w)
			if st.rWr then blend(st.rWr, CF(-0.25, 0, 0), w) end
			blend(st.lSh, CF(0.7 + br, 0, -rad(28)), w)
			blend(st.lEl, CF(1.35, 0, 0), w)
		else
			-- turret / projector / mine: carried in front at the waist with both hands
			blend(st.rSh, CF(0.65, 0, -rad(12)), w)
			blend(st.rEl, CF(0.95, 0, 0), w)
			blend(st.lSh, CF(0.65, 0, rad(12)), w)
			blend(st.lEl, CF(0.95, 0, 0), w)
		end
	end
	if st.throw and st.throw > 0 then
		throwSwing(st)
	end
end

RunService.Stepped:Connect(function(_, dt)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char then
			local st = getState(char)
			if st then
				frame(st, dt)
				if char:GetAttribute("Pose") == nil then armPoses(st) end -- v5.16: not over a pose
			end
		end
	end
end)
