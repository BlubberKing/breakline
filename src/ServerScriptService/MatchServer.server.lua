-- MatchServer v3 (v4.1: 1v1 mode, death screen hand-off, revive spawns). Wall Push main mode (GDD 2.1). Server-authoritative.
-- v4.1 MODES: the MapBounds part has a CHILD that says which mode this map is: a child NAMED "Breakline" or "1v1" (any instance type), or a
--   StringValue / TextLabel inside it whose Value / Text is "Breakline" / "1v1", or the attribute Mode on MapBounds. No child = Breakline.
--   1v1 = one player per team (Red vs Blue), no wall, no boxes, first to MatchConfig.V1.KillsToWin (5) kills wins the round.
--   MatchState attributes: Mode, KillsA, KillsB, KillsToWin.
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
local PC = require(RS:WaitForChild("PlaceConfig"))                         -- shared with the Lobby place
local Roster = require(script.Parent:WaitForChild("MatchRoster"))          -- who plays on which team (from the lobby matchmaker)
local Profiles = require(script.Parent:WaitForChild("ProfileStore"))       -- shared coins / wins
local Catalog = require(RS:WaitForChild("LobbyCatalog"))                    -- valid loadout items (pre-game loadout changes)
local HttpService = game:GetService("HttpService")
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

-- v4.1: which mode is this map? (see the header)
local MODE = "Breakline"
do
	local function parse(v)
		local n = string.lower(tostring(v or "")):gsub("[%s_%-]", "")
		if n == "1v1" or n == "onevone" or n == "oneonone" or n == "1on1" or n == "duel" then return "1v1" end
		if n == "breakline" or n == "wallpush" then return "Breakline" end
		return nil
	end
	local m
	if bounds then
		m = parse(bounds:GetAttribute("Mode"))
		if not m then
			for _, ch in bounds:GetDescendants() do
				m = parse(ch.Name)
				if not m and ch:IsA("StringValue") then m = parse(ch.Value) end
				if not m and (ch:IsA("TextLabel") or ch:IsA("TextButton") or ch:IsA("TextBox")) then m = parse(ch.Text) end
				if m then break end
			end
		end
	end
	MODE = m or "Breakline"
	print("[MatchServer] mode: " .. MODE)
end
local ONE_V_ONE = MODE == "1v1"
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
local ClientReadyRemote, PregameLoadoutRemote = remote("ClientReady"), remote("PregameLoadout") -- client -> server: finished loading / loadout change
local ResultRemote, ContinueRemote = remote("MatchResult"), remote("Continue")                  -- server -> client: souls breakdown / client -> server: back to lobby
remotes.Parent = RS

local stateFolder = Instance.new("Folder")
stateFolder.Name = "MatchState"
stateFolder:SetAttribute("Mode", MODE)
stateFolder:SetAttribute("KillsA", 0)
stateFolder:SetAttribute("KillsB", 0)
stateFolder:SetAttribute("KillsToWin", C.V1.KillsToWin)
stateFolder:SetAttribute("Phase", "Waiting")
stateFolder:SetAttribute("PhaseEnds", 0)
stateFolder:SetAttribute("Winner", "")
stateFolder:SetAttribute("WallFrac", 0) -- -1 .. 1, positive = toward team B's finish line
stateFolder:SetAttribute("WallZ", 0)
stateFolder:SetAttribute("BoxesA", 0)
stateFolder:SetAttribute("BoxesB", 0)
stateFolder:SetAttribute("Expected", 0) -- loading screen: players we wait for / players here / players finished loading
stateFolder:SetAttribute("Present", 0)
stateFolder:SetAttribute("Ready", 0)
stateFolder:SetAttribute("AllReady", false)
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

Players.RespawnTime = 600 -- v4.1: automatic respawn is effectively OFF, DeathServer calls LoadCharacter when the death timer ends

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
if not ONE_V_ONE then
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

-- slow motion: gravity scales with the square of the time scale, so jumps and falls take 1/scale as long (clients slow walking + shooting)
do
	local TimeScale = require(RS:WaitForChild("TimeScale"))
	local baseGravity = workspace.Gravity
	game:GetService("RunService").Heartbeat:Connect(function()
		if phase == "SlowMo" then
			local s = TimeScale.Get()
			workspace.Gravity = baseGravity * s * s
		elseif workspace.Gravity ~= baseGravity then
			workspace.Gravity = baseGravity
		end
	end)
end

-- v4.1 (1v1): kills per team. Counted from the players' StatKills attribute (GunServer + GadgetServer add to it), so no new hook is needed.
local function teamKills(team)
	local n = 0
	for _, p in Players:GetPlayers() do
		if p.Team and p.Team.Name == team then n += (p:GetAttribute("StatKills") or 0) end
	end
	return n
end

local function notify(text, color)
	NotifyRemote:FireAllClients(text, color or Color3.new(1, 1, 1))
end

-- per-round stats (read by the souls screen). GunServer adds kills + damage, this script adds boxes.
local function addStat(player, key, n)
	if player and player.Parent then player:SetAttribute(key, (player:GetAttribute(key) or 0) + n) end
end
local function resetStats()
	for _, p in Players:GetPlayers() do
		p:SetAttribute("StatKills", 0); p:SetAttribute("StatDamage", 0)
		p:SetAttribute("StatPlugged", 0); p:SetAttribute("StatDestroyed", 0)
	end
	stateFolder:SetAttribute("KillsA", 0)
	stateFolder:SetAttribute("KillsB", 0)
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
	if #wallParts == 0 then return end -- (1v1 maps have no wall)
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
local function beginPlug(rec, team, i, by)
	if by then addStat(by, "StatPlugged", 1) end
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
	if reason == "shot" and rec.holeTeam then addStat(rec.lastShooter, "StatDestroyed", 1) end
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
	rec.lastShooter = shooter
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
-- souls for one player: base x (win/loss) x kills x plugged x destroyed x damage. Every row's multiplier is rounded to 2 decimals
-- BEFORE it is multiplied in, so the numbers the player sees on the souls screen multiply to exactly the total.
local results = {} -- player -> result table (also sent to the client)
local function buildReward(p, outcome)
	local R = C.REWARD
	local kills = p:GetAttribute("StatKills") or 0
	local dmg = p:GetAttribute("StatDamage") or 0
	local plugged = p:GetAttribute("StatPlugged") or 0
	local destroyed = p:GetAttribute("StatDestroyed") or 0
	local rows, mult = {}, 1
	local function add(label, detail, m)
		m = math.floor(m * 100 + 0.5) / 100
		mult *= m
		table.insert(rows, { label = label, detail = detail, mult = m })
	end
	if outcome == "win" then add("VICTORY", nil, R.Win)
	elseif outcome == "loss" then add("DEFEAT", nil, R.Loss)
	else add("DRAW", nil, R.Draw) end
	add("KILLS", tostring(kills), 1 + kills * R.PerKill)
	if not ONE_V_ONE then -- (no boxes in a 1v1)
		add("BOXES PLUGGED", tostring(plugged), 1 + plugged * R.PerPlugged)
		add("BOXES DESTROYED", tostring(destroyed), 1 + destroyed * R.PerDestroyed)
	end
	add("DAMAGE", tostring(math.floor(dmg)), 1 + math.floor(dmg / 1000) * R.PerThousandDamage)
	-- v3.8: XP (player level). One number; the summary screen fills the XP bar with it while the stat rows are revealed.
	local X = C.XP
	local xp = X.Base + (outcome == "win" and X.Win or (outcome == "draw" and X.Draw or X.Loss))
		+ kills * X.PerKill + plugged * X.PerPlugged + destroyed * X.PerDestroyed + math.floor(dmg / 100) * X.PerHundredDamage
	return { outcome = outcome, base = R.Base, rows = rows, mult = math.floor(mult * 100 + 0.5) / 100, xp = xp,
		souls = math.floor(R.Base * mult + 0.5), kills = kills, plugged = plugged, destroyed = destroyed, damage = math.floor(dmg) }
end

local function endRound(winner)
	if phase ~= "Playing" then return end
	stateFolder:SetAttribute("Winner", winner or "")
	setPhase("SlowMo", C.SLOWMO_TIME) -- the main loop moves on to "Result" when the slow motion is over
	if winner then notify(winner:upper() .. " WINS", TEAM_COLOR[winner]) end
	-- rewards go into the shared profile (saved when the player leaves / returns to the lobby)
	table.clear(results)
	for _, p in Players:GetPlayers() do
		local t = p.Team and p.Team.Name
		if t and teamObjs[t] and t ~= "Lobby" then
			local outcome = (not winner and "draw") or (t == winner and "win") or "loss"
			local r = buildReward(p, outcome)
			results[p] = r
			r.xpBefore = Profiles.Get(p, "XP") or 0 -- the summary screen needs the XP you had BEFORE this match
			Profiles.Increment(p, "Souls", r.souls)
			Profiles.Increment(p, "XP", r.xp)
			if outcome == "win" then Profiles.Increment(p, "Wins", 1) elseif outcome == "loss" then Profiles.Increment(p, "Losses", 1) end
			ResultRemote:FireClient(p, r)
		else
			ResultRemote:FireClient(p, { outcome = "none", base = 0, rows = {}, mult = 1, souls = 0 })
		end
	end
end

local function respawn(p)
	task.spawn(function() pcall(function() p:LoadCharacter() end) end)
end

local function assignTeams()
	if Roster.Reserved then -- teams come from the lobby matchmaker, never random
		local seated = {}
		for _, p in Players:GetPlayers() do
			local t = Roster.TeamOf(p.UserId)
			if t and teamObjs[t] and (not ONE_V_ONE or not seated[t]) then -- v4.1: a 1v1 map seats ONE player per team, the others spectate from the lobby team
				seated[t] = true
				p.Team = teamObjs[t]
			else
				p.Team = lobbyTeam
			end
		end
		return
	end
	local list = Players:GetPlayers()
	for i = #list, 2, -1 do
		local j = rnd:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	local cap = ONE_V_ONE and 2 or 6
	for i, p in list do
		if i <= cap then p.Team = teamObjs[i % 2 == 1 and TEAM_A or TEAM_B] else p.Team = lobbyTeam end
	end
end

-- Warp: teams are already set (Pregame). Everyone is respawned on their spawn pad and FROZEN (anchored) while the
-- cutscene plays on the clients (MatchFlow), then the 3-2-1 countdown, then beginPlay releases them.
local function setFrozen(on)
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then root.Anchored = on end
	end
end
local function beginWarp()
	clearBoxes()
	wallZ = 0
	moveWall()
	stateFolder:SetAttribute("Winner", "")
	resetStats()
	setPhase("Warp", C.WARP_TIME)
	for _, p in Players:GetPlayers() do respawn(p) end
end
local function beginPlay()
	setFrozen(false)
	setPhase("Playing", 0)
	if not ONE_V_ONE then
		for _ = 1, BOX.StartPerSide do spawnPair() end
		nextSpawnAt = os.clock() + BOX.SpawnInterval
	end
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

-- ===================== guaranteed team spawn =====================
-- Roblox's own SpawnLocation matching is not reliable for both teams (a pad can end up under your floor, or a team can fall back
-- to a random spawn). So after every character loads we place it ourselves on its team's finish line: slot = its place in the team,
-- height = a raycast down onto the real floor (ignores the generated pieces + players).
local function teamSpawnCF(player, teamName)
	local mates = teamObjs[teamName]:GetPlayers()
	table.sort(mates, function(a, b) return a.UserId < b.UserId end)
	local slot = (table.find(mates, player) or 1) - 1
	local x = spawnX[(slot % #spawnX) + 1]
	local z = SIGN[teamName] * LINE_Z
	local from = origin * Vector3.new(x, 20, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { mapFolder }
	for _, pl in Players:GetPlayers() do if pl.Character then table.insert(ignore, pl.Character) end end
	rp.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(from, Vector3.new(0, -(MAP_H + 60), 0), rp)
	local pos = hit and (hit.Position + Vector3.new(0, 4.4, 0)) or (origin * Vector3.new(x, 4, z))
	return CFrame.lookAt(pos, Vector3.new(origin:PointToWorldSpace(Vector3.new(x, 0, 0)).X, pos.Y, origin:PointToWorldSpace(Vector3.new(x, 0, 0)).Z))
end

-- ===================== players =====================
local function onCharacter(player, char)
	do -- put Red / Blue players on their own finish line
		local root = char:WaitForChild("HumanoidRootPart", 10)
		local tn = player.Team and player.Team.Name
		local rezCF = player:GetAttribute("RezCF") -- v4.1: revived by a teammate: appear where your soul was
		if root and tn and teamObjs[tn] and tn ~= "Lobby" and char.Parent then
			if typeof(rezCF) == "CFrame" and phase == "Playing" then
				char:PivotTo(rezCF)
			else
				char:PivotTo(teamSpawnCF(player, tn))
			end
		end
		if rezCF ~= nil then player:SetAttribute("RezCF", nil) end
		if root and (phase == "Warp" or phase == "Countdown") then root.Anchored = true end -- frozen until the countdown ends
		-- v3.8: respawning in the middle of a round: you are frozen + untouchable while souls reveal your body bottom-up (RespawnReveal client)
		if root and char.Parent and phase == "Playing" then
			local ff = Instance.new("ForceField")
			ff.Visible = false
			ff.Parent = char
			root.Anchored = true
			local build = player:GetAttribute("RevealBuild") or C.REVEAL_BUILD
			player:SetAttribute("RevealBuild", nil)
			char:SetAttribute("RevealStart", workspace:GetServerTimeNow())
			char:SetAttribute("RevealBuild", build)
			char:SetAttribute("RevealFrom", player:GetAttribute("RevealFrom") or 0) -- a revive starts the reveal already mostly built
			player:SetAttribute("RevealFrom", nil)
			char:SetAttribute("Revealing", true)
			task.delay(build + C.REVEAL_DIVE, function()
				if ff.Parent then ff:Destroy() end
				if not char.Parent then return end
				char:SetAttribute("Revealing", false)
				local still = phase == "Warp" or phase == "Countdown" or phase == "Pregame" -- a new round started meanwhile: the round code owns the freeze
				if root.Parent and not still then root.Anchored = false end
			end)
		end
	end
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
	if Roster.Reserved then -- rejoin: back on the roster team
		local t = Roster.TeamOf(player.UserId)
		if (phase == "Playing" or phase == "Pregame" or phase == "Warp" or phase == "Countdown") and t and teamObjs[t] then player.Team = teamObjs[t] end
	elseif phase == "Playing" then -- late joiner: fill the smaller team if there is room
		local a, b = #teamObjs[TEAM_A]:GetPlayers(), #teamObjs[TEAM_B]:GetPlayers()
		local pick = a <= b and TEAM_A or TEAM_B
		if math.min(a, b) < (ONE_V_ONE and 1 or 3) then player.Team = teamObjs[pick] end
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
local killTimer = 0
RunService.Heartbeat:Connect(function(dt)
	if phase ~= "Playing" then return end
	local now = os.clock()

	if ONE_V_ONE then -- v4.1: first to KillsToWin kills wins; no wall, no boxes
		killTimer += dt
		if killTimer >= 0.1 then
			killTimer = 0
			local ka, kb = teamKills(TEAM_A), teamKills(TEAM_B)
			stateFolder:SetAttribute("KillsA", ka)
			stateFolder:SetAttribute("KillsB", kb)
			if ka >= C.V1.KillsToWin then endRound(TEAM_A) elseif kb >= C.V1.KillsToWin then endRound(TEAM_B) end
		end
		return
	end

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
					beginPlug(rec, rec.team, idx, rec.thrower)
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
				beginPlug(rec, team, idx, pl)
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

local function enough()
	if Roster.Reserved then return Roster.Ready() end
	return #Players:GetPlayers() >= (ONE_V_ONE and C.V1.MinPlayers or C.MIN_PLAYERS)
end

-- ===================== loading + pre-game + summary handlers =====================
local readyPlayers, continued = {}, {}
ClientReadyRemote.OnServerEvent:Connect(function(player) readyPlayers[player] = true end)
Players.PlayerRemoving:Connect(function(p) readyPlayers[p], continued[p], results[p] = nil, nil, nil end)

local function readyCount()
	local n = 0
	for _, p in Players:GetPlayers() do if readyPlayers[p] then n += 1 end end
	return n
end

-- same rules as the lobby's SetLoadout (LobbyServer.cleanLoadout)
local function cleanLoadout(l)
	l = type(l) == "table" and l or {}
	local out = { Gadgets = {}, Reserve = {} }
	out.Weapon = Catalog.Is(l.Weapon, "weapon") and l.Weapon or Catalog.DefaultWeapon
	out.Move = Catalog.Is(l.Move, "move") and l.Move or ""
	for i = 1, 3 do
		out.Gadgets[i] = Catalog.Is(type(l.Gadgets) == "table" and l.Gadgets[i], "gadget") and l.Gadgets[i] or ""
		local r = type(l.Reserve) == "table" and l.Reserve[i]
		out.Reserve[i] = (Catalog.Is(r, "gadget") or Catalog.Is(r, "weapon")) and r or ""
	end
	return out
end
local lastLoadoutAt = {}
PregameLoadoutRemote.OnServerEvent:Connect(function(player, l)
	if phase ~= "Pregame" then return end -- loadout is locked once the cutscene starts
	if os.clock() - (lastLoadoutAt[player] or 0) < 0.12 then return end
	lastLoadoutAt[player] = os.clock()
	if type(l) ~= "table" or not Profiles.Get(player, "Loadout") then return end
	local clean = cleanLoadout(l)
	Profiles.Set(player, "Loadout", clean)
	Profiles.Set(player, "Weapon", clean.Weapon)
	player:SetAttribute("LoadoutJson", HttpService:JSONEncode(clean))
	-- GunServer reads the Weapon attribute: switch the equipped gun
	local WeaponCfg = require(RS:WaitForChild("WeaponConfig"))
	if WeaponCfg.Weapons[clean.Weapon] then
		player:SetAttribute("Sight", WeaponCfg.Get(clean.Weapon).DefaultSight)
		player:SetAttribute("Weapon", clean.Weapon)
	end
end)

ContinueRemote.OnServerEvent:Connect(function(player)
	if phase ~= "Summary" or continued[player] then return end
	continued[player] = true
	Profiles.Save(player) -- souls earned are written before the teleport
	Roster.SendOne(player)
end)

local function publishLoad()
	stateFolder:SetAttribute("Present", #Players:GetPlayers())
	stateFolder:SetAttribute("Ready", readyCount())
	stateFolder:SetAttribute("Expected", Roster.Reserved and math.max(Roster.Total, #Players:GetPlayers()) or math.max(ONE_V_ONE and C.V1.MinPlayers or C.MIN_PLAYERS, #Players:GetPlayers()))
end

task.spawn(function()
	while true do
		-- ===== Waiting: the loading screen =====
		stateFolder:SetAttribute("AllReady", false)
		setPhase("Waiting", 0)
		local waitStart = os.clock()
		while true do
			publishLoad()
			if enough() then
				local all = readyCount() >= #Players:GetPlayers()
				if all or os.clock() - waitStart > C.READY_TIMEOUT + (Roster.Reserved and PC.ROSTER_WAIT or 0) then break end
			end
			task.wait(0.25)
		end
		publishLoad()
		stateFolder:SetAttribute("AllReady", true)
		task.wait(1.2) -- the loading screen says "ALL PLAYERS LOADED" for a moment

		-- ===== Pregame: teams are set, everybody can change their loadout =====
		assignTeams()
		resetStats()
		table.clear(continued)
		setPhase("Pregame", C.PREGAME_TIME)
		local aborted, t0 = false, os.clock()
		while os.clock() - t0 < C.PREGAME_TIME do
			task.wait(0.25)
			if not enough() then aborted = true break end
		end
		if not aborted then
			-- ===== Warp cutscene (everyone respawned + frozen) =====
			beginWarp()
			task.wait(C.WARP_TIME)
			setPhase("Countdown", C.COUNTDOWN_TIME)
			task.wait(C.COUNTDOWN_TIME)
			beginPlay()
			while phase == "Playing" do
				task.wait(0.25)
				if not enough() then endRound(nil) end
			end
			task.wait(C.SLOWMO_TIME) -- everything slows down...
			setPhase("Result", C.RESULT_TIME)
			task.wait(C.RESULT_TIME) -- ...then the winner cutscene
			-- ===== Summary: souls screen, wait for CONTINUE (or the time limit) =====
			setPhase("Summary", C.SUMMARY_MAX)
			local s0 = os.clock()
			while os.clock() - s0 < C.SUMMARY_MAX do
				task.wait(0.5)
				local waiting = false
				for _, p in Players:GetPlayers() do if not continued[p] then waiting = true break end end
				if not waiting then break end
			end
		end
		if Roster.Reserved then -- one match per reserved server: send everyone back to the lobby
			Roster.ReturnAll()
			return
		end
		resetToLobby()
	end
end)
