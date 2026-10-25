-- MatchServer v2: Wall Push main mode (GDD 2.1). Server-authoritative.
-- It builds ONLY the gameplay pieces and fits them inside YOUR part named "MapBounds" (Workspace):
--   * invisible boundary walls + ceiling   * the 2 finish lines   * 6 invisible team spawn pads
--   * the middle wall with 3 box holes per side   * the boxes
-- Everything else (floor, decoration, cover) is yours. See MatchConfig.MAP for the fitting options.
--   * 3v3 teams, rounds (waiting -> intermission -> playing -> result), respawns
--   * boxes: spawn every minute (one per side), pick up / carry / throw / catch / float into a hole, extract enemy boxes, health
--   * the wall moves toward the team with FEWER plugged boxes' finish line; tie = stands still
--   * the team that is currently PUSHING the wall has all its plugged boxes slowly worn down (PushDrainPerSec)
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
local BoxModel = require(RS:WaitForChild("BoxModel"))
local M, BOX = C.MAP, C.BOX
local rnd = Random.new()

local TEAM_A, TEAM_B = C.Teams[1].Name, C.Teams[2].Name -- A pushes toward B's end and vice versa
local SIGN = { [TEAM_A] = M.SwapEnds and 1 or -1 }       -- which end (sign of local Z) each team owns
SIGN[TEAM_B] = -SIGN[TEAM_A]
local TEAM_COLOR = { [TEAM_A] = C.Teams[1].Color.Color, [TEAM_B] = C.Teams[2].Color.Color }
local CARRY_OFFSET = CFrame.new(0, 0.25, -(0.5 + BOX.Size / 2 + 0.1)) -- carried box, relative to HumanoidRootPart

-- ===================== MapBounds =====================
local bounds = workspace:FindFirstChild("MapBounds") or workspace:WaitForChild("MapBounds", 8)
local bCF, bSize
if bounds and bounds:IsA("BasePart") then
	bCF, bSize = bounds.CFrame, bounds.Size
	bounds.Transparency = 1
	bounds.CanCollide, bounds.CanQuery, bounds.CanTouch = false, false, false -- never blocks players or bullets
elseif bounds and bounds:IsA("Model") then
	bCF, bSize = bounds:GetBoundingBox()
else
	warn("[MatchServer] No part named MapBounds in Workspace - using a default 140 x 60 x 260 area at the origin. "
		.. "Add an anchored, transparent Part named MapBounds around your map (see GDD section 9).")
	local p = Instance.new("Part")
	p.Name = "MapBounds"
	p.Anchored = true
	p.Size = Vector3.new(140, 60, 260)
	p.Position = Vector3.new(0, 30, 0)
	p.Transparency = 1
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Parent = workspace
	bCF, bSize = p.CFrame, p.Size
end
local MAP_W, MAP_H, MAP_L = bSize.X, bSize.Y, bSize.Z -- width (X), height (Y), length (Z)
local _, yaw = bCF:ToOrientation()
-- "origin": ground level at the center of MapBounds. Everything below is built in this local space (X across, Y up, Z = length).
local origin = CFrame.new(bCF.Position.X, bCF.Position.Y - MAP_H / 2 + M.GroundOffset, bCF.Position.Z) * CFrame.Angles(0, yaw, 0)
local LINE_Z = math.max(10, MAP_L / 2 - M.FinishInset) -- the wall must reach +-LINE_Z (local) to win
local function toLocal(pos) return origin:PointToObjectSpace(pos) end
local holeX, spawnX = {}, {}
for i, f in M.HoleXFrac do holeX[i] = f * MAP_W end
for i, f in M.SpawnXFrac do spawnX[i] = f * MAP_W end

-- ===================== shared objects =====================
local remotes = Instance.new("Folder")
remotes.Name = "MatchRemotes"
local function remote(name)
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = remotes; return r
end
local ThrowRemote, DropRemote, NotifyRemote = remote("Throw"), remote("Drop"), remote("Notify")
local BoxBreakRemote, SoulRemote = remote("BoxBreak"), remote("SoulFX") -- client-side effects: box destroyed / player died
remotes.Parent = RS

local stateFolder = Instance.new("Folder")
stateFolder.Name = "MatchState"
stateFolder:SetAttribute("Phase", "Waiting")
stateFolder:SetAttribute("PhaseEnds", 0)
stateFolder:SetAttribute("Winner", "")
stateFolder:SetAttribute("WallFrac", 0) -- -1 .. 1, positive = toward team B's finish line
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

-- boxes pass through players (so they never push or trap anyone) but still hit the floor + your decoration
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

-- ===================== generated pieces (all fitted to MapBounds) =====================
local mapFolder = workspace:FindFirstChild("WallPush")
if mapFolder then mapFolder:Destroy() end
mapFolder = Instance.new("Folder")
mapFolder.Name = "WallPush"
mapFolder.Parent = workspace
local boxFolder = Instance.new("Folder")
boxFolder.Name = "Boxes"
boxFolder.Parent = mapFolder

-- lcf = CFrame in map space (origin = ground at the center of MapBounds)
local function mk(name, size, lcf, color, material, transparency, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = origin * lcf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or mapFolder
	return p
end

-- invisible boundary: 4 walls + a ceiling along the edges of MapBounds
do
	local hb = MAP_H + 40
	local function w(n, size, pos)
		local p = mk(n, size, CFrame.new(pos), Color3.new(), nil, 1)
		p.CanQuery, p.CanTouch = false, false
	end
	w("BoundFront", Vector3.new(MAP_W + 8, hb, 4), Vector3.new(0, hb / 2 - 10, -MAP_L / 2 - 2))
	w("BoundBack", Vector3.new(MAP_W + 8, hb, 4), Vector3.new(0, hb / 2 - 10, MAP_L / 2 + 2))
	w("BoundLeft", Vector3.new(4, hb, MAP_L + 8), Vector3.new(-MAP_W / 2 - 2, hb / 2 - 10, 0))
	w("BoundRight", Vector3.new(4, hb, MAP_L + 8), Vector3.new(MAP_W / 2 + 2, hb / 2 - 10, 0))
	w("BoundCeiling", Vector3.new(MAP_W + 8, 2, MAP_L + 8), Vector3.new(0, MAP_H + 1, 0))
end

local function noPhysics(p)
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
end

-- finish lines + invisible team spawn pads (the pads sit ON the finish line)
for _, t in C.Teams do
	local z = SIGN[t.Name] * LINE_Z
	local line = mk(t.Name .. "FinishLine", Vector3.new(MAP_W, 0.2, 3), CFrame.new(0, 0.1, z), t.Color.Color, Enum.Material.Neon,
		M.ShowFinishLines and 0 or 1)
	noPhysics(line)
	for _, x in spawnX do
		local s = Instance.new("SpawnLocation")
		s.Name = t.Name .. "Spawn"
		s.Anchored = true
		s.Size = Vector3.new(8, 0.2, 8)
		s.CFrame = origin * CFrame.lookAt(Vector3.new(x, 0.1, z), Vector3.new(x, 0.1, 0))
		s.Neutral = false
		s.TeamColor = t.Color
		s.AllowTeamChangeOnTouch = false
		s.Duration = 0
		s.Transparency = 1
		s.CanCollide, s.CanQuery = false, false
		for _, d in s:GetChildren() do if d:IsA("Decal") or d:IsA("Texture") then d:Destroy() end end
		s.Parent = mapFolder
	end
end

-- lobby spawn (between rounds + anyone who is not in the 3v3). Use your own: a SpawnLocation named "LobbySpawn" in Workspace.
do
	local s = workspace:FindFirstChild("LobbySpawn")
	if not (s and s:IsA("SpawnLocation")) then
		s = Instance.new("SpawnLocation")
		s.Name = "LobbySpawn"
		s.Anchored = true
		s.Size = Vector3.new(12, 0.2, 12)
		s.CFrame = origin * CFrame.new(MAP_W / 2 - 10, 0.1, 0)
		s.Transparency = 1
		s.CanCollide, s.CanQuery = false, false
		for _, d in s:GetChildren() do if d:IsA("Decal") or d:IsA("Texture") then d:Destroy() end end
		s.Parent = mapFolder
	end
	s.Neutral = false
	s.TeamColor = lobbyColor
	s.AllowTeamChangeOnTouch = false
	s.Duration = 0
end

-- the wall: one transparent slab, a neon top edge, and 3 "indents" (frame + dark back plate) per side
local wallParts, wallBase = {}, {}
local WALL_H = math.min(MAP_H, M.WallHeightMax)
do
	local function wp(part)
		noPhysics(part) -- players + bullets pass through
		table.insert(wallParts, part)
		table.insert(wallBase, origin:ToObjectSpace(part.CFrame)) -- local to map space, moved along Z later
	end
	local H, T = WALL_H, M.WallThickness
	wp(mk("Wall", Vector3.new(MAP_W, H, T), CFrame.new(0, H / 2, 0), Color3.fromRGB(140, 210, 255), Enum.Material.SmoothPlastic, 0.8))
	wp(mk("WallTop", Vector3.new(MAP_W, 0.8, T + 0.4), CFrame.new(0, H, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon))
	local o = BOX.Size + 0.6
	for _, t in C.Teams do
		local sign = SIGN[t.Name]
		local zf = sign * (T / 2 + 0.05)
		for _, x in holeX do
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
local wallZ = 0 -- local Z of the wall (map space)
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

-- world CFrame of a hole's box position
local function holeCF(team, i)
	return origin * CFrame.new(holeX[i], M.HoleY, wallZ + SIGN[team] * (M.WallThickness / 2 - BOX.Size / 2))
end

local function countPlugged(team)
	local n = 0
	for i = 1, #holeX do if holes[team][i] then n += 1 end end
	return n
end

-- nearest EMPTY hole of this team's side within PLUG_RADIUS of pos (index or nil)
local function nearestHoleFor(team, pos)
	if not team or not holes[team] then return nil end
	local best, bestD = nil, C.PLUG_RADIUS
	for i = 1, #holeX do
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
	for i = 1, #wallParts do cfs[i] = origin * off * wallBase[i] end
	workspace:BulkMoveTo(wallParts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	for team, list in holes do
		for i, rec in list do
			if rec.state == "Plugged" then rec.part.CFrame = holeCF(team, i) end
		end
	end
	stateFolder:SetAttribute("WallZ", wallZ)
end

-- ===================== boxes =====================
local function setState(rec, st)
	rec.state = st
	local p, pr, hl = rec.part, rec.prompt, rec.hl
	p:SetAttribute("State", st)
	if st == "Plugged" then
		p.Anchored, p.CanCollide, p.CanQuery, p.Massless = true, false, true, false
		pr.ActionText, pr.HoldDuration, pr.Enabled = "Extract", C.EXTRACT_TIME, true
		hl.Enabled = false
	elseif st == "Plugging" then -- floating into the hole (physics-driven so every client sees it smoothly)
		p.Anchored, p.CanCollide, p.CanQuery, p.Massless = false, false, false, false
		pr.Enabled, hl.Enabled = false, false
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

local function burstFX(pos, color, count, spread)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Size = Vector3.one
	a.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.6
	e.Speed = NumberRange.new(spread * 0.4, spread)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Size = NumberSequence.new(0.8, 0)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.Rate = 0
	e.Parent = a
	a.Parent = workspace
	e:Emit(count)
	Debris:AddItem(a, 1.5)
end

local onPrompt -- defined below (forward declared so boxes can call it)

local function createBox(pos)
	local p, accents, decor = BoxModel.Build(BOX.Size, { Accent = BoxModel.Amber })
	p.Name = "Box"
	p.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.6, 0.15)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, rnd:NextNumber(0, math.pi * 2), 0)
	for _, e in decor do e.Part.CFrame = p.CFrame * e.Offset end
	p:SetAttribute("WPBox", true)
	p:SetAttribute("MaxHealth", BOX.Health)
	p:SetAttribute("Health", BOX.Health)
	p:SetAttribute("Seed", rnd:NextNumber())
	p:SetAttribute("Draining", false)
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

	local att = Instance.new("Attachment")
	att.Name = "AlignAtt"
	att.Parent = p

	local rec = { part = p, prompt = pr, hl = hl, accents = accents, att = att, state = "Loose" }
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
	gui.Size = UDim2.new(6, 0, 1.5, 0) -- scale = studs
	gui.StudsOffset = Vector3.new(0, BOX.Size / 2 + 2.4, 0)
	gui.MaxDistance = 600
	gui.AlwaysOnTop = true -- readable from BOTH sides of the wall (and through it)
	gui.LightInfluence = 0
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.2, 0); bc.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"; stroke.Thickness = 2; stroke.Color = Color3.new(1, 1, 1); stroke.Transparency = 0.5
	stroke.Parent = bg
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromScale(0.04, 0.12)
	track.Size = UDim2.fromScale(0.92, 0.4)
	track.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	track.BorderSizePixel = 0
	track.Parent = bg
	local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0.3, 0); tc.Parent = track
	local hp = Instance.new("Frame")
	hp.Name = "Hp"
	hp.Size = UDim2.fromScale(1, 1)
	hp.BorderSizePixel = 0
	hp.Parent = track
	local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0.3, 0); hc.Parent = hp
	local txt = Instance.new("TextLabel")
	txt.Name = "Txt"
	txt.Position = UDim2.fromScale(0, 0.56)
	txt.Size = UDim2.fromScale(1, 0.38)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBlack
	txt.TextScaled = true
	txt.TextColor3 = Color3.new(1, 1, 1)
	txt.Text = ""
	txt.Parent = bg
	gui.Parent = rec.part
end

local function updateBars(rec)
	local gui = rec.part:FindFirstChild("Bars")
	if not gui then return end
	local bg = gui:FindFirstChild("Bg")
	if not bg then return end
	local frac = math.clamp(rec.hp / BOX.Health, 0, 1)
	bg.Track.Hp.Size = UDim2.fromScale(frac, 1)
	bg.Track.Hp.BackgroundColor3 = TEAM_COLOR[rec.holeTeam]:Lerp(Color3.fromRGB(255, 60, 60), 1 - frac)
	bg.Txt.Text = tostring(math.ceil(math.max(rec.hp, 0)))
	bg.Stroke.Color = rec.draining and Color3.fromRGB(255, 130, 60) or Color3.new(1, 1, 1)
	bg.Stroke.Transparency = rec.draining and 0.1 or 0.5
	rec.part:SetAttribute("Health", math.max(rec.hp, 0))
end

local function clearAlign(rec)
	if rec.alignP then rec.alignP:Destroy(); rec.alignP = nil end
	if rec.alignO then rec.alignO:Destroy(); rec.alignO = nil end
end

local function leaveHole(rec)
	clearAlign(rec)
	if rec.hole then
		holes[rec.holeTeam][rec.hole] = nil
		rec.hole, rec.holeTeam = nil, nil
		rec.part:SetAttribute("PlugTeam", nil)
		local bars = rec.part:FindFirstChild("Bars")
		if bars then bars:Destroy() end
	end
	rec.draining = false
	rec.part:SetAttribute("Draining", false)
	BoxModel.Recolor(rec.accents, BoxModel.Amber)
	rec.part:FindFirstChild("Glow").Color = BoxModel.Amber
end

-- the box floats into the hole (physics-driven so it is interpolated smoothly on every client), then locks in
local function beginPlug(rec, team, i)
	local p = rec.part
	p.AssemblyLinearVelocity, p.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	holes[team][i] = rec -- the hole is reserved right away
	rec.hole, rec.holeTeam, rec.hp, rec.thrower = i, team, BOX.Health, nil
	rec.draining = false
	p:SetAttribute("PlugTeam", team)
	p:SetAttribute("Health", rec.hp)
	setState(rec, "Plugging")
	rec.plugStart = os.clock()
	local target = holeCF(team, i)
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = rec.att
	ap.Position = target.Position
	ap.MaxForce = 1e7
	ap.MaxVelocity = 90
	ap.Responsiveness = 4 / math.max(C.PLUG_ANIM, 0.1)
	ap.ApplyAtCenterOfMass = true
	ap.Parent = p
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = rec.att
	ao.CFrame = target.Rotation
	ao.MaxTorque = 1e7
	ao.MaxAngularVelocity = 14
	ao.Responsiveness = 4 / math.max(C.PLUG_ANIM, 0.1)
	ao.Parent = p
	rec.alignP, rec.alignO = ap, ao
	pcall(p.SetNetworkOwner, p, nil)
	local col = TEAM_COLOR[team]
	BoxModel.Recolor(rec.accents, col)
	p:FindFirstChild("Glow").Color = col
	makeBars(rec)
	updateBars(rec)
end

local function finishPlug(rec)
	local p = rec.part
	clearAlign(rec)
	p.AssemblyLinearVelocity, p.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	setState(rec, "Plugged")
	p.CFrame = holeCF(rec.holeTeam, rec.hole)
	burstFX(p.Position, TEAM_COLOR[rec.holeTeam], 14, 22)
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
		BoxBreakRemote:FireAllClients(pos, team and TEAM_COLOR[team] or nil)
		if team then
			notify(team:upper() .. " box " .. (reason == "drained" and "worn out" or "destroyed"), TEAM_COLOR[team])
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

-- random free spot on one end's half of the map (sign: which end, +-1)
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { mapFolder }
local function findSpot(sign)
	local zMax = (LINE_Z - 8) - sign * wallZ -- farthest distance from the wall toward this end
	local zMin = math.min(14, zMax)
	zMax = math.max(zMin, math.min(zMax, MAP_L * 0.35))
	local x, z
	for _ = 1, 20 do
		x = rnd:NextNumber(-(MAP_W / 2 - 10), MAP_W / 2 - 10)
		z = wallZ + sign * rnd:NextNumber(zMin, zMax)
		local lcf = origin * CFrame.new(x, 6, z)
		if #workspace:GetPartBoundsInBox(lcf, Vector3.new(6, 6, 6), overlap) == 0 then break end
	end
	return (origin * CFrame.new(x, 6, z)).Position
end

local function spawnPair()
	for _, team in { TEAM_A, TEAM_B } do createBox(findSpot(SIGN[team])) end
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
		if (toLocal(root.Position).Z - wallZ) * SIGN[from] <= -1 then return end -- you have to be on THEIR side of the wall
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
	part:SetAttribute("LastHit", workspace:GetServerTimeNow()) -- makes the face look angry (BoxModel)
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
			if root then SoulRemote:FireAllClients(root.Position) end -- blue soul death effect (DeathFX)
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
		local speed = C.WALL_SPEED[math.min(math.abs(diff), #C.WALL_SPEED)]
		wallZ = math.clamp(wallZ + math.sign(diff) * speed * dt * SIGN[TEAM_B], -LINE_Z, LINE_Z)
		moveWall()
		if wallZ * SIGN[TEAM_B] >= LINE_Z then endRound(TEAM_A) return end
		if wallZ * SIGN[TEAM_A] >= LINE_Z then endRound(TEAM_B) return end
	end
	local pushing = (diff > 0 and TEAM_A) or (diff < 0 and TEAM_B) or nil -- the team currently winning the push

	local list = {}
	for rec in boxes do table.insert(list, rec) end
	for _, rec in list do
		if not boxes[rec] then continue end
		local st = rec.state
		local p = rec.part
		if st == "Plugged" then
			-- the pushing team's boxes are slowly worn down
			local drain = pushing ~= nil and rec.holeTeam == pushing
			if rec.draining ~= drain then
				rec.draining = drain
				p:SetAttribute("Draining", drain)
			end
			if drain then
				rec.hp -= BOX.PushDrainPerSec * dt
				if rec.hp <= 0 then destroyBox(rec, "drained") end
			end
		elseif st == "Plugging" then
			local target = holeCF(rec.holeTeam, rec.hole)
			if rec.alignP then rec.alignP.Position = target.Position end
			if rec.alignO then rec.alignO.CFrame = target.Rotation end
			local age = now - rec.plugStart
			if (age > 0.15 and (p.Position - target.Position).Magnitude < 0.4) or age > 1.5 then finishPlug(rec) end
		elseif st == "Thrown" or st == "Loose" then
			local pos = p.Position
			local lp = toLocal(pos)
			if lp.Y < -25 or math.abs(lp.X) > MAP_W / 2 + 5 or math.abs(lp.Z) > MAP_L / 2 + 5 then
				-- fell out of the map: put it back on the side it left from
				p.AssemblyLinearVelocity = Vector3.zero
				p.CFrame = CFrame.new(findSpot(lp.Z < 0 and -1 or 1))
				if st == "Thrown" then setState(rec, "Loose") end
			elseif st == "Thrown" then
				local idx = nearestHoleFor(rec.team, pos)
				if idx then
					beginPlug(rec, rec.team, idx)
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

	-- carried boxes float into your own side's empty holes when you walk up to them (you must be on your own side)
	local carriers = {}
	for pl, rec in carrying do table.insert(carriers, { pl, rec }) end
	for _, e in carriers do
		local pl, rec = e[1], e[2]
		local team = pl.Team and pl.Team.Name
		local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if team and holes[team] and root and now - rec.carriedAt > 0.5
			and (toLocal(root.Position).Z - wallZ) * SIGN[team] > 0 then
			local idx = nearestHoleFor(team, (root.CFrame * CARRY_OFFSET).Position)
			if idx then
				release(pl, Vector3.zero, "Loose")
				beginPlug(rec, team, idx)
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
			if rec.state == "Plugged" or rec.state == "Plugging" then updateBars(rec) end
		end
	end
	publishTimer += dt
	if publishTimer >= 0.1 then
		publishTimer = 0
		stateFolder:SetAttribute("BoxesA", nA)
		stateFolder:SetAttribute("BoxesB", nB)
		stateFolder:SetAttribute("WallFrac", wallZ * SIGN[TEAM_B] / LINE_Z)
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
