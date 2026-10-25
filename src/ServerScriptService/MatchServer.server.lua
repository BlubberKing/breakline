-- MatchServer v1: Wall Push main mode (GDD 2.1). Server-authoritative.
--  * builds a gray-box map: floor, transparent middle wall with 3 box holes per side, finish lines + spawn pads, cover, lobby
--  * 3v3 teams, rounds (waiting -> intermission -> playing -> result), respawns
--  * boxes: spawn every minute (one per side), pick up / carry / throw / catch / plug, extract enemy boxes, health, 2 min lifetime
--  * wall moves toward the team with FEWER plugged boxes' finish line (more boxes = push); tie = stands still
-- All numbers live in MatchConfig. Carrying sets the Player attribute "Carrying" (guns + gadgets must check it).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local C = require(RS:WaitForChild("MatchConfig"))
local M, BOX = C.MAP, C.BOX
local rnd = Random.new()

local TEAM_A, TEAM_B = C.Teams[1].Name, C.Teams[2].Name -- A defends -Z and pushes toward +Z
local SIGN = { [TEAM_A] = -1, [TEAM_B] = 1 }              -- which side of the wall (Z sign) each team owns
local TEAM_COLOR = { [TEAM_A] = C.Teams[1].Color.Color, [TEAM_B] = C.Teams[2].Color.Color }
local LINE_Z = M.Length / 2 - M.FinishInset               -- the wall must reach +-LINE_Z to win
local CARRY_OFFSET = CFrame.new(0, -0.3, -2.4)            -- carried box, relative to HumanoidRootPart

-- ===================== shared objects =====================
local remotes = Instance.new("Folder")
remotes.Name = "MatchRemotes"
local function remote(name)
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = remotes; return r
end
local ThrowRemote, DropRemote, NotifyRemote = remote("Throw"), remote("Drop"), remote("Notify")
remotes.Parent = RS

local stateFolder = Instance.new("Folder")
stateFolder.Name = "MatchState"
stateFolder:SetAttribute("Phase", "Waiting")
stateFolder:SetAttribute("PhaseEnds", 0)
stateFolder:SetAttribute("Winner", "")
stateFolder:SetAttribute("WallFrac", 0)
stateFolder:SetAttribute("WallZ", 0)
stateFolder:SetAttribute("BoxesA", 0)
stateFolder:SetAttribute("BoxesB", 0)
stateFolder.Parent = RS

-- gun damage on plugged boxes comes in through this event (fired by GunServer)
local BoxDamage = ServerStorage:FindFirstChild("BoxDamage")
if not BoxDamage then
	BoxDamage = Instance.new("BindableEvent")
	BoxDamage.Name = "BoxDamage"
	BoxDamage.Parent = ServerStorage
end

-- boxes pass through players (so they never push or trap anyone) but still hit the floor + cover
pcall(function() PhysicsService:RegisterCollisionGroup("WPBox") end)
pcall(function() PhysicsService:RegisterCollisionGroup("WPPlayer") end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("WPBox", "WPPlayer", false) end)

-- ===================== teams =====================
local teamObjs = {}
for _, t in C.Teams do
	local team = Teams:FindFirstChild(t.Name) or Instance.new("Team")
	team.Name = t.Name
	team.TeamColor = t.Color
	team.AutoAssignable = false
	team.Parent = Teams
	teamObjs[t.Name] = team
end
local lobbyColor = BrickColor.new("Medium stone grey")
local lobbyTeam = Teams:FindFirstChild("Lobby") or Instance.new("Team")
lobbyTeam.Name = "Lobby"
lobbyTeam.TeamColor = lobbyColor
lobbyTeam.AutoAssignable = false
lobbyTeam.Parent = Teams

Players.RespawnTime = C.RESPAWN_TIME

-- ===================== map =====================
local mapFolder = workspace:FindFirstChild("WallPush")
if mapFolder then mapFolder:Destroy() end
mapFolder = Instance.new("Folder")
mapFolder.Name = "WallPush"
mapFolder.Parent = workspace
local boxFolder = Instance.new("Folder")
boxFolder.Name = "Boxes"
boxFolder.Parent = mapFolder
local coverFolder = Instance.new("Folder")
coverFolder.Name = "Cover"
coverFolder.Parent = mapFolder

local function mk(name, size, cf, color, material, transparency, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or mapFolder
	return p
end

local function invisibleBounds(name, cx, cz, w, l, h)
	local function wall(n, size, pos)
		local p = mk(name .. n, size, CFrame.new(pos), Color3.new(), nil, 1)
		p.CanQuery = false
		p.CanTouch = false
	end
	wall("N", Vector3.new(w + 4, h, 2), Vector3.new(cx, h / 2, cz - l / 2 - 1))
	wall("S", Vector3.new(w + 4, h, 2), Vector3.new(cx, h / 2, cz + l / 2 + 1))
	wall("W", Vector3.new(2, h, l + 4), Vector3.new(cx - w / 2 - 1, h / 2, cz))
	wall("E", Vector3.new(2, h, l + 4), Vector3.new(cx + w / 2 + 1, h / 2, cz))
end

-- floor + outer bounds
mk("Floor", Vector3.new(M.Width, 2, M.Length), CFrame.new(0, -1, 0), Color3.fromRGB(58, 61, 68), Enum.Material.Concrete)
invisibleBounds("Bounds", 0, 0, M.Width, M.Length, 120)

-- finish lines + spawn pads (the pads sit ON the finish line)
for idx, t in C.Teams do
	local z = (idx == 1 and -1 or 1) * LINE_Z
	local line = mk(t.Name .. "FinishLine", Vector3.new(M.Width, 0.2, 3), CFrame.new(0, 0.1, z), t.Color.Color, Enum.Material.Neon)
	line.CanCollide, line.CanQuery, line.CanTouch = false, false, false
	for _, x in { -20, 0, 20 } do
		local s = Instance.new("SpawnLocation")
		s.Name = t.Name .. "Spawn"
		s.Anchored = true
		s.Size = Vector3.new(8, 1, 8)
		s.CFrame = CFrame.lookAt(Vector3.new(x, 0.5, z), Vector3.new(x, 0.5, 0))
		s.Neutral = false
		s.TeamColor = t.Color
		s.AllowTeamChangeOnTouch = false
		s.Duration = 0
		s.Color = t.Color.Color
		s.Material = Enum.Material.SmoothPlastic
		s.Transparency = 0.15
		s.TopSurface, s.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		s.Parent = mapFolder
	end
end

-- cover (mirrored on both halves): { x, z, width, height }
for _, sign in { -1, 1 } do
	for _, c in { { -45, 55, 14, 5 }, { 40, 60, 10, 7 }, { 0, 85, 16, 4 }, { -40, 100, 10, 6 }, { 50, 92, 8, 5 } } do
		mk("Cover", Vector3.new(c[3], c[4], 6), CFrame.new(c[1] * sign, c[4] / 2, c[2] * sign), Color3.fromRGB(96, 101, 112), Enum.Material.Concrete, 0, coverFolder)
	end
end

-- lobby (between rounds + anyone who is not in the 3v3)
do
	local lx = M.Width / 2 + 90
	mk("LobbyFloor", Vector3.new(50, 2, 50), CFrame.new(lx, -1, 0), Color3.fromRGB(80, 84, 92), Enum.Material.Concrete)
	invisibleBounds("LobbyBounds", lx, 0, 50, 50, 60)
	local s = Instance.new("SpawnLocation")
	s.Name = "LobbySpawn"
	s.Anchored = true
	s.Size = Vector3.new(24, 1, 24)
	s.CFrame = CFrame.new(lx, 0.5, 0)
	s.Neutral = false
	s.TeamColor = lobbyColor
	s.AllowTeamChangeOnTouch = false
	s.Duration = 0
	s.Color = Color3.fromRGB(150, 150, 155)
	s.Transparency = 0.4
	s.Parent = mapFolder
end

-- the wall: one transparent slab, a neon top edge, and 3 "indents" (frame + dark back plate) per side
local wallParts, wallBase = {}, {}
do
	local function wp(part)
		part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false -- players + bullets pass through
		table.insert(wallParts, part)
		table.insert(wallBase, part.CFrame)
	end
	local H, T = M.WallHeight, M.WallThickness
	wp(mk("Wall", Vector3.new(M.Width, H, T), CFrame.new(0, H / 2, 0), Color3.fromRGB(140, 210, 255), Enum.Material.Glass, 0.8))
	wp(mk("WallTop", Vector3.new(M.Width, 0.8, T + 0.4), CFrame.new(0, H, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon))
	local o = BOX.Size + 0.6
	for idx, t in C.Teams do
		local sign = idx == 1 and -1 or 1
		local zf = sign * (T / 2 + 0.05)
		for _, x in M.HoleX do
			local y = M.HoleY
			local col = t.Color.Color
			wp(mk("HoleFrame", Vector3.new(o + 1, 0.5, 0.3), CFrame.new(x, y + o / 2 + 0.25, zf), col, Enum.Material.Neon))
			wp(mk("HoleFrame", Vector3.new(o + 1, 0.5, 0.3), CFrame.new(x, y - o / 2 - 0.25, zf), col, Enum.Material.Neon))
			wp(mk("HoleFrame", Vector3.new(0.5, o, 0.3), CFrame.new(x - o / 2 - 0.25, y, zf), col, Enum.Material.Neon))
			wp(mk("HoleFrame", Vector3.new(0.5, o, 0.3), CFrame.new(x + o / 2 + 0.25, y, zf), col, Enum.Material.Neon))
			wp(mk("HolePlate", Vector3.new(o - 0.1, o - 0.1, 0.2), CFrame.new(x, y, sign * (T / 2 - BOX.Size - 0.1)),
				Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, 0.1))
		end
	end
end

-- ===================== match state =====================
local phase = "Waiting"
local wallZ = 0
local holes = { [TEAM_A] = {}, [TEAM_B] = {} } -- team -> hole index -> box record
local boxes = {}    -- set of box records
local byPart = {}   -- part -> record
local carrying = {} -- player -> record
local nextSpawnAt = 0

local function setPhase(name, duration)
	phase = name
	stateFolder:SetAttribute("PhaseEnds", workspace:GetServerTimeNow() + (duration or 0))
	stateFolder:SetAttribute("Phase", name)
end

local function notify(text, color)
	NotifyRemote:FireAllClients(text, color or Color3.new(1, 1, 1))
end

local function holeCF(team, i)
	return CFrame.new(M.HoleX[i], M.HoleY, wallZ + SIGN[team] * (M.WallThickness / 2 - BOX.Size / 2))
end

local function countPlugged(team)
	local n = 0
	for i = 1, #M.HoleX do if holes[team][i] then n += 1 end end
	return n
end

-- nearest EMPTY hole of this team's side within PLUG_RADIUS of pos (index or nil)
local function nearestHoleFor(team, pos)
	if not team or not holes[team] then return nil end
	local best, bestD = nil, C.PLUG_RADIUS
	for i = 1, #M.HoleX do
		if not holes[team][i] then
			local d = (holeCF(team, i).Position - pos).Magnitude
			if d <= bestD then best, bestD = i, d end
		end
	end
	return best
end

local function moveWall()
	local off = CFrame.new(0, 0, wallZ)
	local cfs = table.create(#wallParts)
	for i = 1, #wallParts do cfs[i] = off * wallBase[i] end
	workspace:BulkMoveTo(wallParts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	for team, list in holes do
		for i, rec in list do rec.part.CFrame = holeCF(team, i) end
	end
	stateFolder:SetAttribute("WallZ", wallZ)
end

-- ===================== boxes =====================
local function setGunHidden(char, hidden) -- hides the third-person world gun while carrying
	local gun = char and char:FindFirstChild("TPGun")
	if not gun then return end
	for _, d in gun:GetDescendants() do
		if d:IsA("BasePart") then
			if hidden then
				if d:GetAttribute("WPT") == nil then d:SetAttribute("WPT", d.Transparency) end
				d.Transparency = 1
			else
				local t = d:GetAttribute("WPT")
				if t ~= nil then d.Transparency = t; d:SetAttribute("WPT", nil) end
			end
		end
	end
end

local function setState(rec, st)
	rec.state = st
	local p, pr, hl = rec.part, rec.prompt, rec.hl
	p:SetAttribute("State", st)
	if st == "Plugged" then
		p.Anchored, p.CanCollide, p.CanQuery, p.Massless = true, false, true, false
		pr.ActionText, pr.HoldDuration, pr.Enabled = "Extract", C.EXTRACT_TIME, true
		hl.Enabled = false
	elseif st == "Carried" then
		p.Anchored, p.CanCollide, p.CanQuery, p.Massless = false, false, false, true
		pr.Enabled, hl.Enabled = false, false
	else -- Loose / Thrown
		p.Anchored, p.CanCollide, p.CanQuery, p.Massless = false, true, false, false
		pr.ActionText, pr.HoldDuration, pr.Enabled = "Pick up", C.PICKUP_TIME, st == "Loose"
		hl.Enabled = true
	end
	p.CollisionGroup = "WPBox"
end

local function breakFX(pos)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Size = Vector3.one
	a.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80))
	e.LightEmission = 0.6
	e.Speed = NumberRange.new(15, 35)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Size = NumberSequence.new(0.8, 0)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.Rate = 0
	e.Parent = a
	a.Parent = workspace
	e:Emit(30)
	Debris:AddItem(a, 1.5)
end

local onPrompt -- defined below (forward declared so boxes can call it)

local function createBox(pos)
	local p = Instance.new("Part")
	p.Name = "Box"
	p.Size = Vector3.one * BOX.Size
	p.Color = Color3.fromRGB(214, 150, 70)
	p.Material = Enum.Material.DiamondPlate
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.6, 0.15)
	p.CanTouch = false
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, rnd:NextNumber(0, math.pi * 2), 0)
	p:SetAttribute("WPBox", true)
	CollectionService:AddTag(p, "WPBox")

	local hl = Instance.new("Highlight") -- so loose boxes are easy to find
	hl.FillColor = Color3.fromRGB(255, 220, 80)
	hl.FillTransparency = 0.85
	hl.OutlineColor = Color3.fromRGB(255, 230, 90)
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = p

	local pr = Instance.new("ProximityPrompt")
	pr.Name = "Prompt"
	pr.ObjectText = "Box"
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.Parent = p
	CollectionService:AddTag(pr, "WPPrompt")

	local rec = { part = p, prompt = pr, hl = hl, state = "Loose" }
	byPart[p] = rec
	boxes[rec] = true
	p.Parent = boxFolder
	setState(rec, "Loose")
	pcall(p.SetNetworkOwner, p, nil) -- server runs the physics (no client can fling it)
	pr.Triggered:Connect(function(player) onPrompt(rec, player) end)
	return rec
end

local function makeBars(rec)
	local old = rec.part:FindFirstChild("Bars")
	if old then old:Destroy() end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bars"
	gui.Adornee = rec.part
	gui.Size = UDim2.new(4, 0, 0.8, 0) -- scale = studs
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local hp = Instance.new("Frame")
	hp.Name = "Hp"
	hp.Size = UDim2.fromScale(1, 0.6)
	hp.BorderSizePixel = 0
	hp.Parent = bg
	local tm = Instance.new("Frame")
	tm.Name = "Time"
	tm.Position = UDim2.fromScale(0, 0.68)
	tm.Size = UDim2.fromScale(1, 0.3)
	tm.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	tm.BorderSizePixel = 0
	tm.Parent = bg
	gui.Parent = rec.part
end

local function updateBars(rec, now)
	local gui = rec.part:FindFirstChild("Bars")
	if not gui then return end
	local bg = gui:FindFirstChildOfClass("Frame")
	local frac = math.clamp(rec.hp / BOX.Health, 0, 1)
	bg.Hp.Size = UDim2.fromScale(frac, 0.6)
	bg.Hp.BackgroundColor3 = TEAM_COLOR[rec.holeTeam]:Lerp(Color3.fromRGB(255, 60, 60), 1 - frac)
	bg.Time.Size = UDim2.fromScale(math.clamp(1 - (now - rec.plugAt) / BOX.Lifetime, 0, 1), 0.3)
end

local function leaveHole(rec)
	if rec.hole then
		holes[rec.holeTeam][rec.hole] = nil
		rec.hole, rec.holeTeam = nil, nil
		rec.part:SetAttribute("PlugTeam", nil)
		local bars = rec.part:FindFirstChild("Bars")
		if bars then bars:Destroy() end
	end
end

local function plug(rec, team, i)
	local p = rec.part
	p.AssemblyLinearVelocity, p.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	holes[team][i] = rec
	rec.hole, rec.holeTeam, rec.plugAt, rec.hp, rec.thrower = i, team, os.clock(), BOX.Health, nil
	p:SetAttribute("PlugTeam", team)
	p:SetAttribute("Health", rec.hp)
	setState(rec, "Plugged")
	p.CFrame = holeCF(team, i)
	makeBars(rec)
end

-- detaches the box the player is carrying; newState = "Loose" | "Thrown"
local function release(player, velocity, newState, atPos)
	local rec = carrying[player]
	if not rec then return end
	carrying[player] = nil
	local p = rec.part
	local w = p:FindFirstChild("CarryWeld")
	if w then w:Destroy() end
	rec.carrier = nil
	p:SetAttribute("Carrier", nil)
	player:SetAttribute("Carrying", false)
	setGunHidden(player.Character, false)
	setState(rec, newState)
	if atPos then p.CFrame = CFrame.new(atPos) * p.CFrame.Rotation end
	p.AssemblyLinearVelocity = velocity
	p.AssemblyAngularVelocity = Vector3.new(rnd:NextNumber(-4, 4), rnd:NextNumber(-4, 4), rnd:NextNumber(-4, 4))
	pcall(p.SetNetworkOwner, p, nil)
	return rec
end

local function attach(player, rec)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 or carrying[player] then return false end
	local p = rec.part
	leaveHole(rec)
	rec.thrower = nil
	setState(rec, "Carried")
	p.AssemblyLinearVelocity, p.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	p.CFrame = root.CFrame * CARRY_OFFSET
	local w = Instance.new("Weld")
	w.Name = "CarryWeld"
	w.Part0, w.Part1, w.C0 = root, p, CARRY_OFFSET
	w.Parent = p
	rec.carrier, rec.carriedAt = player, os.clock()
	carrying[player] = rec
	p:SetAttribute("Carrier", player.UserId)
	player:SetAttribute("Carrying", true)
	setGunHidden(char, true)
	return true
end

local function destroyBox(rec, reason)
	if rec.carrier then release(rec.carrier, Vector3.zero, "Loose") end
	local team = rec.holeTeam
	local pos = rec.part.Position
	leaveHole(rec)
	boxes[rec] = nil
	byPart[rec.part] = nil
	if reason ~= "clear" then
		breakFX(pos)
		if team then
			notify(team:upper() .. " box " .. (reason == "expired" and "expired" or "destroyed"), TEAM_COLOR[team])
		end
	end
	rec.part:Destroy()
end

local function clearBoxes()
	local list = {}
	for rec in boxes do table.insert(list, rec) end
	for _, rec in list do destroyBox(rec, "clear") end
	table.clear(carrying)
	for _, p in Players:GetPlayers() do p:SetAttribute("Carrying", false) end
end

-- random free spot on one half of the map (sign: -1 = team A side, +1 = team B side)
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { coverFolder }
local function findSpot(sign)
	local edge = LINE_Z - 14
	local maxDz = math.max(10, edge - sign * wallZ)
	local x, z
	for _ = 1, 12 do
		x = rnd:NextNumber(-(M.Width / 2 - 15), M.Width / 2 - 15)
		z = wallZ + sign * rnd:NextNumber(math.min(18, maxDz), math.min(95, maxDz))
		if #workspace:GetPartBoundsInBox(CFrame.new(x, 5, z), Vector3.new(9, 9, 9), overlap) == 0 then break end
	end
	return Vector3.new(x, 9, z)
end

local function spawnPair()
	for _, sign in { -1, 1 } do createBox(findSpot(sign)) end
end

-- picking up a loose box, or extracting an ENEMY plugged box (hold the prompt)
onPrompt = function(rec, player)
	if phase ~= "Playing" or not byPart[rec.part] or carrying[player] then return end
	local team = player.Team and player.Team.Name
	if not team or not holes[team] then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - rec.part.Position).Magnitude > 16 then return end
	if rec.state == "Loose" then
		attach(player, rec)
	elseif rec.state == "Plugged" then
		local from = rec.holeTeam
		if from == team then return end -- your own boxes stay put
		if (root.Position.Z - wallZ) * SIGN[from] <= -1 then return end -- you have to be on THEIR side of the wall
		if attach(player, rec) then
			notify(team:upper() .. " took a box from " .. from:upper(), TEAM_COLOR[team])
		end
	end
end
BoxDamage.Event:Connect(function(part, dmg, shooter)
	local rec = byPart[part]
	if not rec or rec.state ~= "Plugged" or phase ~= "Playing" then return end
	if typeof(dmg) ~= "number" or dmg ~= dmg or dmg <= 0 then return end
	if not shooter or not shooter.Team or shooter.Team.Name == rec.holeTeam then return end
	rec.hp -= dmg
	part:SetAttribute("Health", math.max(rec.hp, 0))
	if rec.hp <= 0 then destroyBox(rec, "shot") end
end)

-- throw / drop
ThrowRemote.OnServerEvent:Connect(function(player, dir)
	local rec = carrying[player]
	if not rec or typeof(dir) ~= "Vector3" then return end
	local m = dir.Magnitude
	if not (m > 0.9 and m < 1.1) then return end
	if os.clock() - rec.carriedAt < 0.25 then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 or not player.Team then return end
	dir = dir.Unit
	local aim = (dir + Vector3.new(0, C.THROW_UP, 0)).Unit
	local start = root.Position + Vector3.new(0, 1.2, 0) + dir * 2.5
	local vel = aim * C.THROW_SPEED + root.AssemblyLinearVelocity * 0.5
	rec.thrower, rec.team, rec.thrownAt = player, player.Team.Name, os.clock()
	release(player, vel, "Thrown", start)
end)

DropRemote.OnServerEvent:Connect(function(player)
	local rec = carrying[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not rec or not root or os.clock() - rec.carriedAt < 0.25 then return end
	local look = root.CFrame.LookVector
	release(player, look * 6 + Vector3.new(0, 4, 0), "Loose", root.Position + look * 3)
end)

-- ===================== round flow =====================
local function endRound(winner)
	if phase ~= "Playing" then return end
	stateFolder:SetAttribute("Winner", winner or "")
	setPhase("Result", C.RESULT_TIME)
	if winner then notify(winner:upper() .. " WINS", TEAM_COLOR[winner]) end
end

local function respawn(p)
	task.spawn(function() pcall(function() p:LoadCharacter() end) end)
end

local function assignTeams()
	local list = Players:GetPlayers()
	for i = #list, 2, -1 do
		local j = rnd:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	for i, p in list do
		if i <= 6 then p.Team = teamObjs[i % 2 == 1 and TEAM_A or TEAM_B] else p.Team = lobbyTeam end
	end
end

local function startRound()
	clearBoxes()
	wallZ = 0
	moveWall()
	assignTeams()
	stateFolder:SetAttribute("Winner", "")
	setPhase("Playing", 0)
	for _, p in Players:GetPlayers() do respawn(p) end
	for _ = 1, BOX.StartPerSide do spawnPair() end
	nextSpawnAt = os.clock() + BOX.SpawnInterval
end

local function resetToLobby()
	clearBoxes()
	wallZ = 0
	moveWall()
	stateFolder:SetAttribute("Winner", "")
	for _, p in Players:GetPlayers() do
		p.Team = lobbyTeam
		respawn(p)
	end
end

-- ===================== players =====================
local function onCharacter(player, char)
	local function group(part)
		if part:IsA("BasePart") then part.CollisionGroup = "WPPlayer" end
	end
	for _, d in char:GetDescendants() do group(d) end
	char.DescendantAdded:Connect(group)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			local rec = carrying[player]
			local root = char:FindFirstChild("HumanoidRootPart")
			if rec then release(player, Vector3.zero, "Loose", root and root.Position + Vector3.new(0, 1, 0)) end
		end)
	end
end

local function onPlayer(player)
	player:SetAttribute("Carrying", false)
	player.Team = lobbyTeam
	if phase == "Playing" then -- late joiner: fill the smaller team if there is room
		local a, b = #teamObjs[TEAM_A]:GetPlayers(), #teamObjs[TEAM_B]:GetPlayers()
		local pick = a <= b and TEAM_A or TEAM_B
		if math.min(a, b) < 3 then player.Team = teamObjs[pick] end
	end
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	player.CharacterRemoving:Connect(function()
		if carrying[player] then release(player, Vector3.zero, "Loose") end
	end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
	respawn(p)
end
Players.PlayerRemoving:Connect(function(p)
	if carrying[p] then release(p, Vector3.zero, "Loose") end
end)

-- ===================== main simulation =====================
local barTimer, publishTimer = 0, 0
RunService.Heartbeat:Connect(function(dt)
	if phase ~= "Playing" then return end
	local now = os.clock()

	-- wall: moves toward the finish line of the team with FEWER plugged boxes
	local nA, nB = countPlugged(TEAM_A), countPlugged(TEAM_B)
	local diff = nA - nB
	if diff ~= 0 then
		wallZ = math.clamp(wallZ + diff * C.WALL_SPEED_PER_BOX * dt, -LINE_Z, LINE_Z)
		moveWall()
		if wallZ >= LINE_Z then endRound(TEAM_A) return end
		if wallZ <= -LINE_Z then endRound(TEAM_B) return end
	end

	local list = {}
	for rec in boxes do table.insert(list, rec) end
	for _, rec in list do
		if not boxes[rec] then continue end
		local st = rec.state
		local p = rec.part
		if st == "Plugged" then
			if now - rec.plugAt >= BOX.Lifetime then destroyBox(rec, "expired") end
		elseif st == "Thrown" or st == "Loose" then
			local pos = p.Position
			if pos.Y < -30 or math.abs(pos.X) > M.Width / 2 + 5 or math.abs(pos.Z) > M.Length / 2 + 5 then
				-- fell out of the map: put it back on the side it left from
				p.AssemblyLinearVelocity = Vector3.zero
				p.CFrame = CFrame.new(findSpot(pos.Z < 0 and -1 or 1))
				if st == "Thrown" then setState(rec, "Loose") end
			elseif st == "Thrown" then
				local idx = nearestHoleFor(rec.team, pos)
				if idx then
					plug(rec, rec.team, idx)
				else
					local caught = false
					for _, pl in Players:GetPlayers() do
						if pl ~= rec.thrower and pl.Team and pl.Team.Name == rec.team and not carrying[pl] then
							local ch = pl.Character
							local r = ch and ch:FindFirstChild("HumanoidRootPart")
							local h = ch and ch:FindFirstChildOfClass("Humanoid")
							if r and h and h.Health > 0 and (r.Position - pos).Magnitude <= C.CATCH_RADIUS then
								caught = attach(pl, rec)
								if caught then break end
							end
						end
					end
					if not caught then
						local age = now - rec.thrownAt
						if (age > 0.5 and p.AssemblyLinearVelocity.Magnitude < 6) or age > 5 then
							setState(rec, "Loose")
						end
					end
				end
			end
		end
	end

	-- carried boxes plug into your own side's empty holes when you walk up to them (you must be on your own side)
	local carriers = {}
	for pl, rec in carrying do table.insert(carriers, { pl, rec }) end
	for _, e in carriers do
		local pl, rec = e[1], e[2]
		local team = pl.Team and pl.Team.Name
		local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if team and holes[team] and root and now - rec.carriedAt > 0.5
			and (root.Position.Z - wallZ) * SIGN[team] > 0 then
			local idx = nearestHoleFor(team, (root.CFrame * CARRY_OFFSET).Position)
			if idx then
				release(pl, Vector3.zero, "Loose")
				plug(rec, team, idx)
			end
		end
	end

	-- a new box on EACH side every SpawnInterval
	if now >= nextSpawnAt then
		nextSpawnAt += BOX.SpawnInterval
		spawnPair()
	end

	barTimer += dt
	if barTimer >= 0.15 then
		barTimer = 0
		for rec in boxes do
			if rec.state == "Plugged" then updateBars(rec, now) end
		end
	end
	publishTimer += dt
	if publishTimer >= 0.1 then
		publishTimer = 0
		stateFolder:SetAttribute("BoxesA", nA)
		stateFolder:SetAttribute("BoxesB", nB)
		stateFolder:SetAttribute("WallFrac", wallZ / LINE_Z)
	end
end)

task.spawn(function()
	while true do
		setPhase("Waiting", 0)
		while #Players:GetPlayers() < C.MIN_PLAYERS do task.wait(0.5) end
		setPhase("Intermission", C.INTERMISSION)
		local aborted, t0 = false, os.clock()
		while os.clock() - t0 < C.INTERMISSION do
			task.wait(0.25)
			if #Players:GetPlayers() < C.MIN_PLAYERS then aborted = true break end
		end
		if not aborted then
			startRound()
			while phase == "Playing" do
				task.wait(0.25)
				if #Players:GetPlayers() < C.MIN_PLAYERS then endRound(nil) end
			end
			task.wait(C.RESULT_TIME)
		end
		resetToLobby()
	end
end)
