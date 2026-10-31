-- AbilityPose v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BOTH games. NEW in v4.0. Keep the two copies identical.
-- Makes the wall run and the wall climb LOOK right on every character (you see your own body in no first person, but everybody else does):
--   WALL RUN along a wall : legs run in a real stride (one foot on the wall), the arm next to the wall reaches out and touches it, the
--                           other arm pumps, shoulders turn a little, a dust trail kicks up off the wall.
--   WALL RUN up a wall    : fast stepping, both arms pumping, head up.
--   WALL CLIMB            : hand-over-hand (arms reach up alternately), legs push, body presses to the wall, dust when moving.
-- It only drives the joint Transforms AFTER the Animator (PreSimulation / Stepped), so the default animations are simply blended away.
-- Reads the character attributes "AbilityMode" ("wallrun" / "climb") and "WallNormal" (set by AbilityClient / AbilityServer).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local rad, sin, cos, abs, clamp, exp = math.rad, math.sin, math.cos, math.abs, math.clamp, math.exp
local CF = CFrame.Angles
local function approach(a, b, speed, dt) return a + (b - a) * (1 - exp(-speed * dt)) end

-- Joint conventions (R15, Motor6D C0/C1 are pure translations): a positive X rotation swings a hanging limb FORWARD (hip/shoulder) or
-- bends the shin BACK (knee, negative) / the forearm FORWARD (elbow, positive); a positive Z rotation moves a hanging limb to the character's RIGHT.
-- If a limb ever bends the wrong way after a rig change, flip the matching number below.
local states = {}

local function joint(char, part, name)
	local p = char:FindFirstChild(part)
	return p and p:FindFirstChild(name) or nil
end

local function setup(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local lt = char:FindFirstChild("LowerTorso")
	local ut = char:FindFirstChild("UpperTorso")
	if not (hum and root and lt and ut) then return nil end
	local st = {
		char = char, hum = hum, root = root, w = 0, phase = 0, side = 0, up = 0, climbMove = 0, wasMode = nil,
		rSh = joint(char, "RightUpperArm", "RightShoulder"), lSh = joint(char, "LeftUpperArm", "LeftShoulder"),
		rEl = joint(char, "RightLowerArm", "RightElbow"), lEl = joint(char, "LeftLowerArm", "LeftElbow"),
		rHip = joint(char, "RightUpperLeg", "RightHip"), lHip = joint(char, "LeftUpperLeg", "LeftHip"),
		rKnee = joint(char, "RightLowerLeg", "RightKnee"), lKnee = joint(char, "LeftLowerLeg", "LeftKnee"),
		waist = joint(char, "UpperTorso", "Waist"), neck = joint(char, "Head", "Neck"),
	}
	if not (st.rSh and st.lSh and st.rHip and st.lHip and st.rKnee and st.lKnee and st.waist) then return nil end
	-- dust trail (local, per character)
	local att = Instance.new("Attachment")
	att.Name = "AbilityDustAtt"
	att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "AbilityDust"
	pe.Enabled = false
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.35, 0.7)
	pe.Speed = NumberRange.new(2, 6)
	pe.SpreadAngle = Vector2.new(35, 35)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.7) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 196, 188))
	pe.LightEmission = 0.1
	pe.Drag = 3
	pe.Parent = att
	st.att, st.dust = att, pe
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
	if j then j.Transform = j.Transform:Lerp(pose, w) end
end

local function frame(st, dt)
	local char = st.char
	local mode = char:GetAttribute("AbilityMode")
	local n = char:GetAttribute("WallNormal")
	local active = (mode == "wallrun" or mode == "climb") and typeof(n) == "Vector3" and st.hum.Health > 0
	st.w = approach(st.w, active and 1 or 0, active and 14 or 10, dt)
	if st.w < 0.01 then
		if st.dust.Enabled then st.dust.Enabled = false end
		return
	end
	if active then st.wasMode = mode end
	mode = st.wasMode
	n = n or st.lastN or Vector3.zAxis
	st.lastN = n

	local root = st.root
	local vel = root.AssemblyLinearVelocity
	local speed = vel.Magnitude
	local cf = root.CFrame
	-- where is the wall relative to the body? side > 0: wall on the RIGHT, < 0: on the LEFT (flat part of the normal)
	local into = -n
	local sideRaw = into:Dot(cf.RightVector)
	st.side = approach(st.side, clamp(sideRaw * 1.6, -1, 1), 12, dt)
	-- up vs along: the body's velocity along the world up axis
	local upAmt = clamp(vel.Y / 22, 0, 1)
	st.up = approach(st.up, (mode == "wallrun" and upAmt > 0.55) and 1 or 0, 10, dt)
	local moving = clamp(speed / 14, 0, 1)
	st.climbMove = approach(st.climbMove, mode == "climb" and moving or 0, 10, dt)

	local w = st.w
	if mode == "wallrun" then
		-- stride frequency follows the speed
		st.phase += dt * clamp(speed, 8, 40) * 0.42
		local p = st.phase
		local s1, s2 = sin(p), sin(p + math.pi)
		local along = 1 - st.up
		-- legs: big running stride; the leg near the wall plants flat against it
		local rHipPitch = s1 * rad(62)
		local lHipPitch = s2 * rad(62)
		local rKneeB = -rad(18) - math.max(0, -s1) * rad(95)
		local lKneeB = -rad(18) - math.max(0, -s2) * rad(95)
		-- up-run: shorter, quicker, knees high
		rHipPitch = rHipPitch * (1 - 0.15 * st.up) - st.up * rad(10)
		lHipPitch = lHipPitch * (1 - 0.15 * st.up) - st.up * rad(10)
		-- feet reach to the wall side
		local reach = rad(12) * along
		blend(st.rHip, CF(rHipPitch, 0, reach * st.side), w)
		blend(st.lHip, CF(lHipPitch, 0, reach * st.side), w)
		blend(st.rKnee, CF(rKneeB, 0, 0), w)
		blend(st.lKnee, CF(lKneeB, 0, 0), w)
		-- arms
		local wallArm = st.side -- > 0: right arm is the wall arm
		local armPump = sin(p) * rad(55)
		local function arm(sh, el, isRight, dir)
			-- dir: +1 for the right arm, -1 for the left arm. Wall arm: out to the side, hand on the wall. Other arm: pump.
			local nearWall = (isRight and wallArm > 0.25) or ((not isRight) and wallArm < -0.25)
			local t = nearWall and 1 or 0
			if st.up > 0.5 then t = 0 end
			local swing = (isRight and armPump or -armPump)
			-- hand on the wall: raise the arm ~75deg to the side with a small forward tilt
			local wallPose = CF(rad(20) + sin(p * 0.5) * rad(8), 0, dir * rad(75))
			local pumpPose = CF(swing * (1 - 0.3 * st.up) + st.up * rad(50), 0, dir * rad(8))
			local pose = pumpPose:Lerp(wallPose, t)
			blend(sh, pose, w)
			blend(el, CF(rad(35) + math.max(0, swing) * rad(40) * (1 - t) + (t * rad(10)), 0, 0), w)
		end
		arm(st.rSh, st.rEl, true, 1)
		arm(st.lSh, st.lEl, false, -1)
		-- torso: counter-twist of the shoulders + lean the head up the wall in an up-run
		local twist = sin(p) * rad(9) * (1 - 0.5 * st.up)
		blend(st.waist, CF(-st.up * rad(8), twist, 0), w)
		blend(st.neck, CF(st.up * rad(24), -twist * 0.7, 0), w)
		-- dust trail off the wall
		st.att.WorldPosition = root.Position + into * 1.5 - Vector3.new(0, 1.4, 0)
		st.dust.Rate = clamp(speed, 0, 40) * 1.6
		st.dust.Enabled = speed > 8
	else
		-- climb: hand over hand. Phase only advances while you move.
		st.phase += dt * (3.2 + speed * 0.18) * st.climbMove
		local p = st.phase
		local a1, a2 = sin(p), sin(p + math.pi)
		-- arms reach up high (hands above the head), alternate pulling down
		local function arm(sh, el, a, dir)
			local up = rad(150) - (1 - a) * rad(34)
			blend(sh, CF(up, 0, dir * rad(14)), w)
			blend(el, CF(rad(24) + math.max(0, -a) * rad(55), 0, 0), w)
		end
		arm(st.rSh, st.rEl, a1, 1)
		arm(st.lSh, st.lEl, a2, -1)
		-- legs: knees bent against the wall, alternate pushes
		local function leg(hip, kn, a, dir)
			blend(hip, CF(rad(24) + a * rad(34) * st.climbMove, 0, dir * rad(10)), w)
			blend(kn, CF(-rad(52) - math.max(0, -a) * rad(34) * st.climbMove, 0, 0), w)
		end
		leg(st.rHip, st.rKnee, a2, 1)
		leg(st.lHip, st.lKnee, a1, -1)
		blend(st.waist, CF(rad(5), sin(p) * rad(7) * st.climbMove, 0), w)
		blend(st.neck, CF(rad(18), 0, 0), w)
		st.att.WorldPosition = root.Position + into * 1.3
		st.dust.Rate = 8 + 16 * st.climbMove
		st.dust.Enabled = st.climbMove > 0.25
	end
end

RunService.Stepped:Connect(function(_, dt)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char and (char:GetAttribute("AbilityMode") ~= nil or states[char]) then
			local st = getState(char)
			if st then frame(st, dt) end
		end
	end
end)
