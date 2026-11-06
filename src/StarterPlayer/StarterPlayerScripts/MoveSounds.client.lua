-- MoveSounds v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BOTH games (Breakline + Lobby), keep the two copies identical. NEW in v5.7.
-- Plays the everyday movement + body sounds through the SoundBank (every one is silent until you paste an Id into the matching slot):
--   Footstep   every stride of every player (3D, only close players are heard). Walk / run / crouch change the stride length + volume.
--   Jump       a character leaves the ground by jumping
--   Land       a normal landing,  LandHard  a long fall (fall speed above HARD_FALL)
--   SoulPickup / SoulDrop   you start / stop carrying a soul (Player attribute CarryingSoul)
--   ReviveStart / ReviveStop   you start / stop reviving a teammate (Character attribute Reviving)
--   Respawn    you come back to life (Player attribute IsDead goes false)
-- Roblox's own default footstep sound (the "Running" sound of the built-in character sounds) is NOT touched: if you hear a double footstep, delete
-- the default one with a LocalScript named RbxCharacterSounds in StarterPlayerScripts (or set its Running sound volume to 0).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Sfx = require(RS:WaitForChild("Sfx"))

local WALK_STRIDE, RUN_STRIDE = 4.4, 6.0   -- studs between two footsteps while walking / sprinting
local RUN_SPEED = 22                       -- above this flat speed the stride is a run
local HEAR_DIST = 90                       -- other players' footsteps are only played inside this distance
local HARD_FALL = 42                       -- fall speed (studs/s) from which the landing is LandHard
local MIN_FALL = 14                        -- below this fall speed there is no landing sound

local state = {} -- character -> { dist, foot, minVy }

local function setup(char)
	if state[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then return end
	local st = { dist = 0, foot = 1, minVy = 0, hum = hum, root = root }
	state[char] = st
	local isMe = char == player.Character
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			Sfx.Play("Jump", root, nil, isMe and 1 or 0.7)
		elseif new == Enum.HumanoidStateType.Landed then
			local fall = -st.minVy
			st.minVy = 0
			if fall >= HARD_FALL then
				Sfx.Play("LandHard", root, nil, isMe and 1 or 0.8)
			elseif fall >= MIN_FALL then
				Sfx.Play("Land", root, nil, (isMe and 1 or 0.7) * math.clamp(fall / 30, 0.6, 1.2))
			end
		end
	end)
	char.AncestryChanged:Connect(function(_, parent) if not parent then state[char] = nil end end)
end

local function watch(p)
	p.CharacterAdded:Connect(setup)
	if p.Character then task.spawn(setup, p.Character) end
end
Players.PlayerAdded:Connect(watch)
for _, p in Players:GetPlayers() do watch(p) end

RunService.Heartbeat:Connect(function(dt)
	local camPos = camera.CFrame.Position
	for char, st in state do
		local root, hum = st.root, st.hum
		if not root.Parent or hum.Health <= 0 then continue end
		local v = root.AssemblyLinearVelocity
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		if not grounded then
			if v.Y < st.minVy then st.minVy = v.Y end
		end
		local mode = char:GetAttribute("AbilityMode")
		local flat = Vector3.new(v.X, 0, v.Z).Magnitude
		local silent = char:GetAttribute("Sliding") == true or char:GetAttribute("Mantling") == true or char:GetAttribute("Dashing") == true or mode ~= nil
		if grounded and flat > 4 and not silent and not root.Anchored then
			st.dist += flat * dt
			local crouch = char:GetAttribute("Crouching") == true
			local run = flat >= RUN_SPEED
			local stride = run and RUN_STRIDE or WALK_STRIDE
			if st.dist >= stride then
				st.dist -= stride
				st.foot = -st.foot
				if char == player.Character or (root.Position - camPos).Magnitude <= HEAR_DIST then
					local vol = crouch and 0.35 or (run and 1 or 0.65)
					if char ~= player.Character then vol *= 0.8 end
					Sfx.Play("Footstep", root, 1 + st.foot * 0.04, vol)
				end
			end
		elseif not grounded then
			st.dist = 0
		end
	end
end)

-- soul carry / revive / respawn
player:GetAttributeChangedSignal("CarryingSoul"):Connect(function()
	Sfx.Play(player:GetAttribute("CarryingSoul") == true and "SoulPickup" or "SoulDrop")
end)
local wasDead = player:GetAttribute("IsDead") == true
player:GetAttributeChangedSignal("IsDead"):Connect(function()
	local dead = player:GetAttribute("IsDead") == true
	if wasDead and not dead then Sfx.Play("Respawn") end
	wasDead = dead
end)
local function watchRevive(char)
	local last = false
	char:GetAttributeChangedSignal("Reviving"):Connect(function()
		local now = char:GetAttribute("Reviving") == true
		if now ~= last then
			last = now
			Sfx.Play(now and "ReviveStart" or "ReviveStop")
		end
	end)
end
player.CharacterAdded:Connect(watchRevive)
if player.Character then watchRevive(player.Character) end
