-- BotServer v1 (Script in ServerScriptService, named "BotServer") - BREAKLINE place only. NEW in v5.7 (AI BOTS FOR THE QUEUE).
-- The lobby matchmaker puts bots into the empty slots when somebody waited PlaceConfig.BOT_WAIT seconds with nobody to play against.
-- The roster carries Bots = { Red = n, Blue = n } (MatchRoster.Bots). This script spawns them and runs a SIMPLE brain for each one:
--   * every bot is a normal R15 character (the default skin, a world gun on the chest) with a Humanoid, tagged Attribute IsBot = true
--     and OwnerTeam = "Red" / "Blue" (GunServer already refuses friendly fire for any model that has OwnerTeam, and players shoot bots like sentries)
--   * they spawn on their team's finish line at the Cards / Countdown phase, are frozen until Playing, and are removed when the round is decided
--   * brain: look for the nearest enemy (player or enemy bot) it can SEE, strafe + shoot in bursts (hitscan with aim error, reaction time, slower fire rate,
--     reduced damage: all numbers in MatchConfig.BOTS); with nobody in sight it walks (PathfindingService) to the last place it saw an enemy / hunts (1v1) / roams.
--   * Breakline: BuilderPerTeam bots per team fetch loose boxes and carry them to their own empty holes (MatchServer plugs them like a player's box).
--   * a dead bot respawns after BOTS.RespawnTime (1v1: the round reset brings everybody back)
-- Studio test: set MatchConfig.BOTS.StudioRed / StudioBlue (number of bots per team) and press Play. Live: the roster decides.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")

local C = require(RS:WaitForChild("MatchConfig"))
local B = C.BOTS
local Roster = require(script.Parent:WaitForChild("MatchRoster"))

local counts = Roster.Bots
if not counts and RunService:IsStudio() then counts = { Red = B.StudioRed or 0, Blue = B.StudioBlue or 0 } end
if not counts or ((counts.Red or 0) + (counts.Blue or 0)) <= 0 then return end -- no bots in this match: nothing to do

local API = require(script.Parent:WaitForChild("BotAPI"))
local Weapons = require(RS:WaitForChild("WeaponConfig"))
local GunModels = require(RS:WaitForChild("GunModels"))
local GunMath = require(RS:WaitForChild("GunMath"))
local Skins = require(RS:WaitForChild("Skins"))
local Bank = require(RS:WaitForChild("SoundBank"))
local Vitals = require(script.Parent:WaitForChild("Vitals"))
local State = RS:WaitForChild("MatchState")
local SoulFX = RS:WaitForChild("MatchRemotes"):WaitForChild("SoulFX")
local Damaged = RS:WaitForChild("GunRemotes"):WaitForChild("Damaged")
while not API.Phase do task.wait(0.2) end -- MatchServer fills the API a moment after it starts

local rnd = Random.new()
local ONE = API.Mode == "1v1"
local GUN_SCALE = 0.8
local bots = {}          -- list of bot records
local spawned = false
local filter = {}        -- every character (players + bots): line-of-sight rays ignore them
local filterT = 0

-- ===================== helpers =====================
local function realCount(team)
	local n = 0
	for _, p in Players:GetPlayers() do
		if p.Team and p.Team.Name == team then n += 1 end
	end
	return n
end

local function refreshFilter()
	table.clear(filter)
	for _, p in Players:GetPlayers() do if p.Character then table.insert(filter, p.Character) end end
	for _, b in bots do if b.model then table.insert(filter, b.model) end end
end

local function flatDist(a, b) return (Vector3.new(a.X - b.X, 0, a.Z - b.Z)).Magnitude end

-- enemies of bot b that can be shot right now: { model, root, hum, player?, bot? }
local function enemyTargets(b)
	local list = {}
	for _, p in Players:GetPlayers() do
		local t = p.Team and p.Team.Name
		local ch = p.Character
		if t and t ~= b.team and (t == API.Teams[1] or t == API.Teams[2]) and ch and p:GetAttribute("IsDead") ~= true then
			local hum = ch:FindFirstChildOfClass("Humanoid")
			local r = ch:FindFirstChild("HumanoidRootPart")
			if hum and r and hum.Health > 0 and ch:GetAttribute("Revealing") ~= true then
				table.insert(list, { model = ch, root = r, hum = hum, player = p })
			end
		end
	end
	for _, o in bots do
		if o.team ~= b.team and o.alive and o.model and o.model.Parent and o.hum.Health > 0 and not o.spawnShield then
			table.insert(list, { model = o.model, root = o.root, hum = o.hum, bot = o })
		end
	end
	return list
end

local function canSee(b, t)
	local from = b.head.Position
	local to = t.root.Position + Vector3.new(0, 0.8, 0)
	local d = to - from
	if d.Magnitude > B.Sight then return false end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = filter
	return workspace:Raycast(from, d, rp) == nil
end

-- ===================== building a bot =====================
local function buildModel(name)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then return nil end
	model.Name = name
	return model
end

local function attachGun(b)
	local torso = b.model:FindFirstChild("UpperTorso")
	if not torso then return end
	local cfg = b.cfg
	local gun = GunModels.BuildWorld(cfg.Model or cfg.Id, cfg.DefaultSight, GUN_SCALE, nil, "TPGun")
	gun:SetAttribute("Weapon", cfg.Id)
	local k = torso.Size.Y / 1.6
	local c0 = CFrame.new(0.42 * k, 0.05 * k, -1.2 * k)
	gun:PivotTo(torso.CFrame * c0)
	gun.Parent = b.model
	local joint = Instance.new("Motor6D")
	joint.Name = "GunJoint"
	joint.Part0 = torso
	joint.Part1 = gun.PrimaryPart
	joint.C0 = c0
	joint.Parent = torso
	b.muzzle = gun:FindFirstChild("MuzzlePoint", true)
	b.flash = gun:FindFirstChild("Flash", true)
	b.light = gun:FindFirstChild("FlashLight", true)
end

local function dropBox(b)
	if b.model then pcall(API.DropBox, b.model) end
end

local function removeModel(b)
	dropBox(b)
	b.alive = false
	if b.model then
		local m = b.model
		b.model = nil
		m:Destroy()
	end
end

local function playFire(b)
	local id = b.cfg.Id
	local g = Bank.Guns and Bank.Guns[id]
	local def = (g and g.Fire and g.Fire.Id and g.Fire.Id ~= "" and g.Fire) or (Bank.Global and Bank.Global.Fire)
	if not def then return end
	local sid = def.Id
	if def.Ids then sid = def.Ids[rnd:NextInteger(1, #def.Ids)] end
	if not sid or sid == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = string.find(sid, "://") and sid or ("rbxassetid://" .. sid)
	s.Volume = (def.Volume or 0.6) * (b.cfg.FireVolume or 1)
	s.PlaybackSpeed = (def.PitchMin or 1) + rnd:NextNumber() * ((def.PitchMax or 1) - (def.PitchMin or 1))
	s.PlaybackSpeed *= (b.cfg.FirePitch or 1)
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 350
	s.Parent = b.root
	s:Play()
	Debris:AddItem(s, 4)
end

local spawnBot -- forward

local function onDied(b)
	if not b.alive then return end
	b.alive = false
	local root = b.root
	if root then SoulFX:FireAllClients(root.Position) end
	dropBox(b)
	local m = b.model
	if m then Debris:AddItem(m, 2.4) end
	b.token += 1
	if not ONE then -- 1v1: the round reset (Round attribute) brings every bot back
		local token = b.token
		task.delay(B.RespawnTime, function()
			if b.token ~= token or not spawned then return end
			local ph = API.Phase()
			if ph == "Playing" or ph == "Countdown" then spawnBot(b) end
		end)
	end
end

function spawnBot(b, freezeFor)
	if b.model then removeModel(b) end
	b.token += 1
	local token = b.token
	-- v5.8 DAMAGE BUG FIX: the protection + freeze end times are fixed NOW, before Skins.Dress yields. Before, the ForceField was only
	-- added after dressing (up to ~1.5 s later) and lasted 1.6 s + the freeze on top of that, so in a 1v1 round reset the bot stayed
	-- unkillable for ~3 s after the player could already move and shoot (hundreds of damage that never came off).
	local startedAt = os.clock()
	local freezeEnd = startedAt + (freezeFor or 0)
	local shieldEnd = freezeFor and math.min(freezeEnd, startedAt + (C.REVEAL_TIME or 2)) -- same moment the player's reveal protection ends
		or (startedAt + (B.SpawnShield or 1))
	local model = buildModel("BOT " .. b.team .. " " .. b.index)
	if not model then return end
	local cf = API.SpawnCF(b.team, b.slot)
	model:SetAttribute("IsBot", true)
	model:SetAttribute("OwnerTeam", b.team)
	model:PivotTo(cf)
	model.Parent = workspace
	local hum = model:WaitForChild("Humanoid", 5)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not hum or not root then model:Destroy() return end
	root.Anchored = true
	pcall(function() Skins.Dress(model, B.Skin, nil) end) -- yields while the slim body scale is applied
	if b.token ~= token or not model.Parent then model:Destroy() return end
	hum.MaxHealth = B.Health
	hum.Health = B.Health
	hum.WalkSpeed = B.WalkSpeed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	model:PivotTo(cf)
	local id = B.Weapons[rnd:NextInteger(1, #B.Weapons)]
	b.cfg = Weapons.Get(id)
	b.model, b.hum, b.root, b.head = model, hum, root, model:FindFirstChild("Head") or root
	attachGun(b)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then pcall(function() d.CollisionGroup = "WPPlayer" end) end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then pcall(function() d.CollisionGroup = "WPPlayer" end) end
	end)
	local shieldLeft = shieldEnd - os.clock()
	if shieldLeft > 0.05 then -- a short grace period after (re)spawning, ends together with the freeze (1v1 reset) or B.SpawnShield later
		local ff = Instance.new("ForceField")
		ff.Visible = false
		ff.Parent = model
		b.spawnShield = true
		Debris:AddItem(ff, shieldLeft)
		task.delay(shieldLeft, function() if b.token == token then b.spawnShield = nil end end)
	else
		b.spawnShield = nil
	end
	b.ammo, b.reloadUntil, b.nextShot, b.burstUntil, b.pauseUntil = b.cfg.MagSize, 0, 0, 0, 0
	b.target, b.visible, b.lastSeen, b.lastSeenPos, b.seenAt = nil, false, 0, nil, 0
	b.wps, b.wpi, b.goal, b.planAt, b.stuckAt, b.stuckPos = nil, 1, nil, 0, os.clock(), root.Position
	b.alive = true
	b.frozenUntil = freezeEnd
	hum.Died:Connect(function() onDied(b) end)
	local ph = API.Phase()
	local freezeLeft = freezeEnd - os.clock()
	if ph == "Playing" and (not freezeFor or freezeLeft <= 0) then
		root.Anchored = false
	elseif freezeFor then
		task.delay(freezeLeft, function() if b.token == token and root.Parent and API.Phase() == "Playing" then root.Anchored = false end end)
	end
	pcall(function() root:SetNetworkOwner(nil) end) -- the server drives the bot (no client can claim it)
end

-- ===================== shooting =====================
local function fireAt(b, t)
	local cfg = b.cfg
	local origin = b.head.Position
	local aim = t.root.Position + Vector3.new(0, rnd:NextNumber(0.2, 1.5), 0)
	local dir = (aim - origin).Unit
	local err = math.rad(B.Spread)
	dir = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(rnd:NextNumber(-1, 1) * err, rnd:NextNumber(-1, 1) * err, 0)).LookVector
	local range = math.min(cfg.Range, B.MaxFireRange)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { b.model }
	local hit = workspace:Raycast(origin, dir * range, rp)
	local endPos = hit and hit.Position or origin + dir * range
	-- muzzle flash + sound + tracer
	playFire(b)
	if b.flash then
		b.flash.Transparency = 0.2
		if b.light then b.light.Enabled = true end
		task.delay(0.04, function()
			if b.flash and b.flash.Parent then b.flash.Transparency = 1 end
			if b.light and b.light.Parent then b.light.Enabled = false end
		end)
	end
	local from = b.muzzle and b.muzzle:IsA("Attachment") and b.muzzle.WorldPosition or origin
	local len = (endPos - from).Magnitude
	if len > 1 then
		local tr = Instance.new("Part")
		tr.Anchored = true
		tr.CanCollide, tr.CanQuery, tr.CanTouch, tr.CastShadow = false, false, false, false
		tr.Material = Enum.Material.Neon
		tr.Color = Color3.fromRGB(255, 214, 150)
		local l = math.min(len, 9)
		tr.Size = Vector3.new(0.05, 0.05, l)
		tr.CFrame = CFrame.lookAt(from + (endPos - from).Unit * l * 0.5, endPos)
		tr.Parent = workspace
		Debris:AddItem(tr, 0.07)
	end
	-- damage
	if not hit then return end
	local m = hit.Instance:FindFirstAncestorOfClass("Model")
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local victim = Players:GetPlayerFromCharacter(m)
	local team = victim and victim.Team and victim.Team.Name or m:GetAttribute("OwnerTeam")
	if not team or team == b.team then return end
	if victim and (victim:GetAttribute("IsDead") == true or m:GetAttribute("Revealing") == true) then return end
	local head = hit.Instance.Name == "Head"
	local dmg = GunMath.Damage(cfg, hit.Distance, head) * B.DamageMult
	local before = hum.Health
	Vitals.Damage(hum, dmg)
	if victim then Damaged:FireClient(victim, dmg, origin) end
	if before > 0 and hum.Health <= 0 then API.AddBotKill(b.team) end
end

-- ===================== movement =====================
local function plan(b, goal)
	if b.planning or not b.alive then return end
	b.planning = true
	b.goal = goal
	b.planAt = os.clock()
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 6 })
		local ok = pcall(function() path:ComputeAsync(b.root.Position, goal) end)
		if b.alive and b.goal == goal then
			if ok and path.Status == Enum.PathStatus.Success then
				b.wps, b.wpi = path:GetWaypoints(), 2
			else
				b.wps, b.wpi = { { Position = b.root.Position }, { Position = goal, Action = Enum.PathWaypointAction.Walk } }, 2
			end
		end
		b.planning = false
	end)
end

local function walkTo(b, goal, replanEvery)
	if not b.goal or (b.goal - goal).Magnitude > 12 or os.clock() - b.planAt > (replanEvery or 3) then plan(b, goal) end
	local wps = b.wps
	if not wps then return false end
	local wp = wps[b.wpi]
	if not wp then return true end -- arrived
	b.hum.WalkSpeed = B.WalkSpeed
	b.hum:MoveTo(wp.Position)
	if wp.Action == Enum.PathWaypointAction.Jump then b.hum.Jump = true end
	if flatDist(b.root.Position, wp.Position) < 3.5 then b.wpi += 1 end
	return false
end

local function pickRoamGoal(b)
	local enemySide = (not ONE) and rnd:NextNumber() < 0.35
	return API.RandomSpot(b.team, enemySide)
end

local function think(b, dt)
	local root, hum = b.root, b.hum
	local now = os.clock()
	if now < b.frozenUntil or API.Phase() ~= "Playing" then hum:Move(Vector3.zero) b.faceTo = nil return end

	-- perception (4x per second)
	b.scanT = (b.scanT or 0) - dt
	if b.scanT <= 0 then
		b.scanT = 0.22 + rnd:NextNumber() * 0.08
		local best, bd = nil, math.huge
		for _, t in enemyTargets(b) do
			local d = (t.root.Position - root.Position).Magnitude
			if d < bd and canSee(b, t) then best, bd = t, d end
		end
		if best then
			if not b.target or b.target.model ~= best.model then b.seenAt = now end
			b.target, b.visible, b.lastSeen, b.lastSeenPos = best, true, now, best.root.Position
		else
			b.visible = false
			if b.target and now - b.lastSeen > 2.5 then b.target = nil end
		end
	end

	-- stuck check (jump, and plan a new path)
	if now - b.stuckAt > 0.8 then
		if (root.Position - b.stuckPos).Magnitude < 1.2 and hum.MoveDirection.Magnitude > 0.1 then
			hum.Jump = true
			b.goal = nil
		end
		b.stuckAt, b.stuckPos = now, root.Position
	end

	-- COMBAT: an enemy is in sight
	if b.visible and b.target and b.target.hum.Health > 0 then
		local t = b.target
		local tp = t.root.Position
		local to = tp - root.Position
		local dist = to.Magnitude
		b.faceTo = tp
		hum.AutoRotate = false
		hum.WalkSpeed = B.WalkSpeed * 0.8
		-- strafe, and keep a fighting distance
		b.strafeT = (b.strafeT or 0) - dt
		if b.strafeT <= 0 then b.strafeT = rnd:NextNumber(0.7, 1.6) b.strafeDir = rnd:NextNumber() < 0.5 and -1 or 1 end
		local flat = Vector3.new(to.X, 0, to.Z)
		local fwd = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
		local right = fwd:Cross(Vector3.yAxis)
		local move = right * b.strafeDir
		if dist > 55 then move += fwd * 1.2 elseif dist < 16 then move -= fwd * 1.0 end
		hum:Move(move.Magnitude > 0.05 and move.Unit or Vector3.zero)
		-- shoot in bursts after the reaction time
		local cfg = b.cfg
		if now - b.seenAt >= B.ReactTime and dist <= math.min(cfg.Range, B.MaxFireRange) then
			if b.ammo <= 0 then
				if b.reloadUntil == 0 then b.reloadUntil = now + cfg.ReloadTime end
				if now >= b.reloadUntil then b.ammo, b.reloadUntil = cfg.MagSize, 0 end
			elseif now >= b.pauseUntil then
				if b.burstUntil == 0 or now > b.burstUntil + 5 then b.burstUntil = now + rnd:NextNumber(B.BurstTime[1], B.BurstTime[2]) end
				if now < b.burstUntil then
					if now >= b.nextShot then
						local rpm = cfg.FireMode == "Burst" and cfg.BurstRPM or cfg.RPM
						b.nextShot = now + (60 / rpm) / B.FireRateMult
						b.ammo -= 1
						fireAt(b, t)
					end
				else
					b.burstUntil = 0
					b.pauseUntil = now + rnd:NextNumber(B.PauseTime[1], B.PauseTime[2])
				end
			end
		end
		return
	end

	-- NO ENEMY IN SIGHT
	b.faceTo = nil
	hum.AutoRotate = true
	-- remembered enemy: go where it was last seen
	if b.lastSeenPos and now - b.lastSeen < 6 then
		if walkTo(b, b.lastSeenPos, 1.5) then b.lastSeenPos = nil end
		return
	end
	-- Breakline box duty
	if not ONE and b.builder then
		local carrying = API.IsCarrying(b.model)
		local holesList = API.EmptyHoles(b.team)
		if carrying and #holesList == 0 then dropBox(b) carrying = false end
		if carrying then
			local best, bd = nil, math.huge
			for _, pos in holesList do
				local d = flatDist(root.Position, pos)
				if d < bd then best, bd = pos, d end
			end
			-- walk to a point beside the hole; MatchServer plugs the box by itself once the bot is close to it on its own side
			walkTo(b, best, 2)
			return
		end
		local bestBox, bd = nil, math.huge
		for _, part in API.LooseBoxes() do
			local d = flatDist(root.Position, part.Position)
			if d < bd then bestBox, bd = part, d end
		end
		if bestBox then
			if bd < 5.5 then
				API.GrabBox(b.model, bestBox)
			else
				walkTo(b, bestBox.Position, 2)
			end
			return
		end
	end
	-- 1v1: hunt the nearest enemy; otherwise roam
	if ONE then
		local best, bd = nil, math.huge
		for _, t in enemyTargets(b) do
			local d = (t.root.Position - root.Position).Magnitude
			if d < bd then best, bd = t, d end
		end
		if best then walkTo(b, best.root.Position, 1.2) return end
	end
	b.roamAt = b.roamAt or 0
	if not b.roamGoal or now > b.roamAt or (b.wps and not b.wps[b.wpi]) then
		b.roamGoal = pickRoamGoal(b)
		b.roamAt = now + rnd:NextNumber(8, 14)
	end
	walkTo(b, b.roamGoal, 4)
end

-- turn the body toward the target every frame (a smooth aim, even while strafing)
RunService.Heartbeat:Connect(function()
	for _, b in bots do
		if b.alive and b.faceTo and b.root and b.root.Parent and not b.root.Anchored then
			local p = b.root.Position
			local goal = CFrame.lookAt(p, Vector3.new(b.faceTo.X, p.Y, b.faceTo.Z))
			b.root.CFrame = b.root.CFrame:Lerp(goal, 0.3)
		end
	end
end)

-- ===================== lifecycle =====================
local function spawnAll()
	if spawned then return end
	spawned = true
	for _, team in API.Teams do
		local n = counts[team] or 0
		local first = realCount(team)
		for i = 1, n do
			local b = {
				team = team, index = i, slot = first + i - 1, token = 0, alive = false, frozenUntil = 0,
				builder = (not ONE) and i <= (B.BuilderPerTeam or 0),
			}
			table.insert(bots, b)
		end
	end
	for _, b in bots do task.spawn(spawnBot, b) end
end

local function clearAll()
	if not spawned then return end
	spawned = false
	for _, b in bots do b.token += 1 removeModel(b) end
	table.clear(bots)
	API.ResetBotKills()
end

-- unfreeze at the start of play
local unfrozen = false
local function releaseAll()
	if unfrozen then return end
	unfrozen = true
	for _, b in bots do
		if b.alive and b.root then b.root.Anchored = false end
	end
end

-- 1v1: a new round (everybody back on their side)
State:GetAttributeChangedSignal("Round"):Connect(function()
	if not spawned or not ONE or API.Phase() ~= "Playing" then return end
	local freeze = (C.REVEAL_TIME or 2) + 0.6
	for _, b in bots do task.spawn(spawnBot, b, freeze) end
end)

task.spawn(function()
	while true do
		task.wait(0.25)
		local ph = API.Phase()
		if ph == "Cards" or ph == "Countdown" or ph == "Playing" then
			spawnAll()
			if ph == "Playing" then releaseAll() else unfrozen = false end
		elseif ph == "SlowMo" then
			for _, b in bots do if b.alive and b.hum then b.hum:Move(Vector3.zero) end end
		else
			clearAll()
			unfrozen = false
		end
	end
end)

local lastT = os.clock()
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local dt = math.min(now - lastT, 0.2)
	lastT = now
	if not spawned then return end
	filterT += dt
	if filterT > 0.5 then filterT = 0 refreshFilter() end
	for _, b in bots do
		if b.alive and b.model and b.hum and b.hum.Health > 0 then
			b.thinkT = (b.thinkT or 0) - dt
			if b.thinkT <= 0 then
				b.thinkT = 0.1
				local ok, err = pcall(think, b, 0.1)
				if not ok then warn("[BotServer] think error:", err) end
			end
		end
	end
end)

print("[BotServer] bots this match:", counts.Red or 0, "Red /", counts.Blue or 0, "Blue")
