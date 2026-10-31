-- DeathServer v1 (Script in ServerScriptService) - BREAKLINE place only. NEW in v4.1.
-- Owns everything about being dead in a match:
--   * DEATH TIMER: you are dead MatchConfig.DEAD_TIME (15 s) and spectate a living teammate. If NO teammate is left alive it is a TEAM WIPE: every dead
--     player on that team gets WIPE_TIME (10 s) (the timer RESETS to 10 for all of them, even if you were at 3) and free-roams the map.
--     (1v1: no teammates, no souls: you are out for V1.RespawnTime and spectate your opponent.)
--   * Roblox auto-respawn is OFF (MatchServer sets Players.RespawnTime huge): THIS script calls LoadCharacter when the timer ends.
--   * SOULS: when you die in Breakline a soul drops on your body. Teammates can pick it up (hold E) and carry / throw / drop it (like a box), or REVIVE you
--     by holding F on it for REZ_TIME (8 s) and staying next to it. The soul disappears the moment you respawn (timer or revive).
--       - while it is being revived the soul has attributes RezBy / RezStart / RezTime so every client can play the slow "body being built" animation
--       - if the reviver lets go / walks away / dies the revive is cancelled and the animation disappears
--       - a finished revive loads your character AT the soul with a very short reveal (the body was already built while they worked)
-- Player attributes (read by the clients): IsDead, DeathEnds (server time), DeathTotal (s), DeathMode ("spectate" / "roam"), CarryingSoul.
-- Character attribute: Reviving (the reviver). Soul part attributes: OwnerId, OwnerName, TeamName, State (Loose / Carried / Thrown), RezBy, RezStart, RezTime.
-- Handoff to MatchServer.onCharacter through Player attributes RezCF (CFrame to spawn at) + RevealBuild (seconds of the reveal).
-- Remotes: ReplicatedStorage.SoulRemotes.Throw (direction) / .Drop
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local C = require(RS:WaitForChild("MatchConfig"))
local MatchState = RS:WaitForChild("MatchState", 30)
local SOUL = C.SOUL

local remotes = Instance.new("Folder")
remotes.Name = "SoulRemotes"
local ThrowR = Instance.new("RemoteEvent"); ThrowR.Name = "Throw"; ThrowR.Parent = remotes
local DropR = Instance.new("RemoteEvent"); DropR.Name = "Drop"; DropR.Parent = remotes
remotes.Parent = RS

local soulFolder = Instance.new("Folder")
soulFolder.Name = "Souls"
soulFolder.Parent = workspace

local dead = {}         -- player -> { endsAt, total, mode }
local souls = {}        -- owner player -> rec
local carryingSoul = {} -- carrier player -> rec

------------------------------------------------------------------ helpers
local function nowT() return workspace:GetServerTimeNow() end
local function phase() return MatchState and MatchState:GetAttribute("Phase") or "Waiting" end
local function modeName() return MatchState and MatchState:GetAttribute("Mode") or "Breakline" end
local function teamName(p) return p and p.Team and not p.Neutral and p.Team.Name or nil end
local function aliveChar(p)
	local c = p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if h and r and h.Health > 0 then return c, h, r end
	return nil
end
-- (a player whose character is still loading after a respawn counts as ALIVE, otherwise a respawning teammate would trigger a false team wipe)
local function isAliveForTeam(p) return dead[p] == nil and (p.Character == nil or aliveChar(p) ~= nil) end

local function groundBelow(pos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ig = { soulFolder }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ig, p.Character) end end
	local wp = workspace:FindFirstChild("WallPush")
	if wp then table.insert(ig, wp) end
	rp.FilterDescendantsInstances = ig
	rp.RespectCanCollide = true
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), rp)
	return hit and hit.Position.Y or (pos.Y - 3)
end

local function publishDead(p, d)
	p:SetAttribute("IsDead", true)
	p:SetAttribute("DeathEnds", d.endsAt)
	p:SetAttribute("DeathTotal", d.total)
	p:SetAttribute("DeathMode", d.mode)
end
local function clearDeadAttrs(p)
	p:SetAttribute("IsDead", false)
	p:SetAttribute("DeathEnds", nil)
	p:SetAttribute("DeathTotal", nil)
	p:SetAttribute("DeathMode", nil)
end

local function loadChar(p)
	task.spawn(function() pcall(function() p:LoadCharacter() end) end)
end

------------------------------------------------------------------ souls
local destroySoul, cancelRez

local function setSoulState(rec, st)
	rec.state = st
	rec.part:SetAttribute("State", st)
end

local function hoverSettle(rec)
	local part = rec.part
	local g = groundBelow(part.Position)
	part.AssemblyLinearVelocity, part.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(part.Position.X, g + 2.5, part.Position.Z)
	rec.ground = g
	setSoulState(rec, "Loose")
	rec.part:SetAttribute("Ground", g)
end

local function release(p, vel)
	local rec = carryingSoul[p]
	if not rec then return end
	carryingSoul[p] = nil
	rec.carrier = nil
	local w = rec.part:FindFirstChild("CarryWeld")
	if w then w:Destroy() end
	p:SetAttribute("CarryingSoul", false)
	rec.part.Anchored = false
	rec.part.Massless = false
	rec.part.CanCollide = true
	rec.part.AssemblyLinearVelocity = vel
	rec.part:SetAttribute("Carrier", nil)
	rec.thrownAt = os.clock()
	setSoulState(rec, "Thrown")
	pcall(function() rec.part:SetNetworkOwner(nil) end)
end

local function canHelp(p, rec, needLoose)
	if phase() ~= "Playing" then return false end
	local c, _, r = aliveChar(p)
	if not c or dead[p] then return false end
	if p == rec.owner or teamName(p) ~= rec.team then return false end
	if p:GetAttribute("Carrying") == true or carryingSoul[p] or c:GetAttribute("Reviving") == true or c:GetAttribute("Revealing") == true then return false end
	if needLoose and rec.state ~= "Loose" then return false end
	if (r.Position - rec.part.Position).Magnitude > SOUL.Reach + 6 then return false end
	return true, c, r
end

local function pickUp(p, rec)
	local ok, c, r = canHelp(p, rec, true)
	if not ok then return end
	if rec.rez then return end -- somebody is already reviving it
	c:SetAttribute("HeldGadget", nil)
	c:SetAttribute("HeldSlot", nil)
	local part = rec.part
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.AssemblyLinearVelocity = Vector3.zero
	local off = CFrame.new(0, 0.7, -2.5)
	part.CFrame = r.CFrame * off
	local w = Instance.new("Weld")
	w.Name = "CarryWeld"
	w.Part0, w.Part1, w.C0 = r, part, off
	w.Parent = part
	rec.carrier = p
	carryingSoul[p] = rec
	p:SetAttribute("CarryingSoul", true)
	part:SetAttribute("Carrier", p.UserId)
	setSoulState(rec, "Carried")
end

cancelRez = function(rec)
	local z = rec.rez
	if not z then return end
	rec.rez = nil
	local c = z.by and z.by.Character
	if c then c:SetAttribute("Reviving", nil) end
	rec.part:SetAttribute("RezBy", nil)
	rec.part:SetAttribute("RezStart", nil)
end

local function startRez(p, rec)
	if rec.rez then return end
	local ok, c, r = canHelp(p, rec, true)
	if not ok then return end
	c:SetAttribute("HeldGadget", nil)
	c:SetAttribute("HeldSlot", nil)
	rec.rez = { by = p, start = os.clock(), startPos = r.Position }
	c:SetAttribute("Reviving", true)
	rec.part:SetAttribute("RezBy", p.UserId)
	rec.part:SetAttribute("RezTime", SOUL.RezTime or C.REZ_TIME)
	rec.part:SetAttribute("RezStart", nowT())
end

local function completeRez(rec)
	local z = rec.rez
	if not z then return end
	local owner = rec.owner
	local by = z.by
	local _, _, rootBy = aliveChar(by)
	local pos = rec.part.Position
	local g = rec.ground or groundBelow(pos)
	local face = Vector3.new(0, 0, -1)
	if rootBy then
		local lv = rootBy.CFrame.LookVector
		local f = Vector3.new(lv.X, 0, lv.Z)
		if f.Magnitude > 0.1 then face = f.Unit end
	end
	local spawn = Vector3.new(pos.X, g + 4.4, pos.Z)
	owner:SetAttribute("RezCF", CFrame.lookAt(spawn, spawn + face))
	owner:SetAttribute("RevealBuild", C.REZ_FINISH)
	owner:SetAttribute("RevealFrom", 0.86)
	cancelRez(rec)
	destroySoul(rec)
	dead[owner] = nil
	clearDeadAttrs(owner)
	loadChar(owner)
end

destroySoul = function(rec)
	if not rec then return end
	cancelRez(rec)
	if rec.carrier then release(rec.carrier, Vector3.zero) end
	if souls[rec.owner] == rec then souls[rec.owner] = nil end
	if rec.part then rec.part:Destroy() end
end

local function createSoul(owner, pos)
	local old = souls[owner]
	if old then destroySoul(old) end
	local g = groundBelow(pos)
	local part = Instance.new("Part")
	part.Name = "Soul"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 2.4
	part.Transparency = 1 -- SoulClient draws the stylised soul around it
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	part.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.5, 0.35, 1, 1)
	part.CFrame = CFrame.new(pos.X, g + 2.5, pos.Z)
	pcall(function() part.CollisionGroup = "WPBox" end) -- passes through players like boxes do
	part:SetAttribute("OwnerId", owner.UserId)
	part:SetAttribute("OwnerName", owner.DisplayName ~= "" and owner.DisplayName or owner.Name)
	part:SetAttribute("TeamName", teamName(owner) or "")
	part:SetAttribute("State", "Loose")
	part:SetAttribute("Ground", g)
	part:SetAttribute("RezTime", SOUL.RezTime or C.REZ_TIME)
	CS:AddTag(part, "Soul")
	local rec = { owner = owner, part = part, team = teamName(owner), state = "Loose", ground = g, origin = Vector3.new(pos.X, g + 2.5, pos.Z) }

	local pick = Instance.new("ProximityPrompt")
	pick.Name = "PickPrompt"
	pick.ObjectText = part:GetAttribute("OwnerName") .. "'s soul"
	pick.ActionText = "Carry"
	pick.KeyboardKeyCode = Enum.KeyCode.E
	pick.HoldDuration = SOUL.CarryTime
	pick.MaxActivationDistance = SOUL.Reach
	pick.RequiresLineOfSight = false
	pick.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	pick.UIOffset = Vector2.new(-70, 0)
	pick:SetAttribute("Kind", "Pick")
	pick.Parent = part
	CS:AddTag(pick, "SoulPrompt")
	pick.Triggered:Connect(function(p) pickUp(p, rec) end)

	local rez = Instance.new("ProximityPrompt")
	rez.Name = "RezPrompt"
	rez.ObjectText = part:GetAttribute("OwnerName") .. "'s soul"
	rez.ActionText = "Revive"
	rez.KeyboardKeyCode = Enum.KeyCode.F
	rez.HoldDuration = SOUL.RezTime or C.REZ_TIME
	rez.MaxActivationDistance = SOUL.Reach
	rez.RequiresLineOfSight = false
	rez.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	rez.UIOffset = Vector2.new(70, 0)
	rez:SetAttribute("Kind", "Rez")
	rez.Parent = part
	CS:AddTag(rez, "SoulPrompt")
	rez.PromptButtonHoldBegan:Connect(function(p) startRez(p, rec) end)
	rez.PromptButtonHoldEnded:Connect(function(p)
		-- (ignore the "hold ended" that can arrive together with a finished hold: the main loop completes the revive itself)
		if rec.rez and rec.rez.by == p and os.clock() - rec.rez.start < (SOUL.RezTime or C.REZ_TIME) - 0.6 then cancelRez(rec) end
	end)
	rez.Triggered:Connect(function(p)
		if rec.rez and rec.rez.by == p and os.clock() - rec.rez.start >= (SOUL.RezTime or C.REZ_TIME) - 0.4 then completeRez(rec) end
	end)

	part.Parent = soulFolder
	souls[owner] = rec
	return rec
end

ThrowR.OnServerEvent:Connect(function(p, dir)
	local rec = carryingSoul[p]
	if not rec or typeof(dir) ~= "Vector3" then return end
	local m = dir.Magnitude
	if not (m > 0.9 and m < 1.1) then return end
	local _, _, root = aliveChar(p)
	if not root then return end
	dir = dir.Unit
	local aim = (dir + Vector3.new(0, 0.3, 0)).Unit
	local start = root.Position + Vector3.new(0, 1.2, 0) + dir * 2.6
	local vel = aim * SOUL.ThrowSpeed + root.AssemblyLinearVelocity * 0.5
	release(p, vel)
	rec.part.CFrame = CFrame.new(start)
	rec.part.AssemblyLinearVelocity = vel
end)
DropR.OnServerEvent:Connect(function(p)
	local rec = carryingSoul[p]
	local _, _, root = aliveChar(p)
	if not rec or not root then return end
	local look = root.CFrame.LookVector
	release(p, look * 5 + Vector3.new(0, 3, 0))
end)

------------------------------------------------------------------ dying
local function wipeTeam(tn, now)
	for _, p in Players:GetPlayers() do
		if teamName(p) == tn and dead[p] then
			local d = dead[p]
			d.endsAt, d.total, d.mode = now + C.WIPE_TIME, C.WIPE_TIME, "roam"
			publishDead(p, d)
			local s = souls[p]
			if s then destroySoul(s) end -- nobody is left to carry or revive anybody
		end
	end
end

local function onDied(player, char)
	local ph, mode, tn = phase(), modeName(), teamName(player)
	local root = char:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position or Vector3.zero
	local now = nowT()
	-- a box carrier drops the box (MatchServer); a soul carrier drops the soul
	if carryingSoul[player] then release(player, Vector3.zero) end
	local z = char:GetAttribute("Reviving") == true
	if z then
		for _, rec in souls do if rec.rez and rec.rez.by == player then cancelRez(rec) end end
	end
	if ph ~= "Playing" or not tn or tn == "Lobby" then
		-- outside a live round nobody uses the death screen: just bring the player back (auto-respawn is off)
		task.delay(3, function()
			if player.Parent and player.Character == char then loadChar(player) end
		end)
		return
	end
	if mode == "1v1" then
		local d = { endsAt = now + C.V1.RespawnTime, total = C.V1.RespawnTime, mode = "spectate" }
		dead[player] = d
		publishDead(player, d)
		return
	end
	local d = { endsAt = now + C.DEAD_TIME, total = C.DEAD_TIME, mode = "spectate" }
	dead[player] = d
	local mates = 0
	for _, p in Players:GetPlayers() do
		if p ~= player and teamName(p) == tn and isAliveForTeam(p) then mates += 1 end
	end
	if mates == 0 then
		wipeTeam(tn, now) -- includes this player
		if not dead[player] or dead[player].mode ~= "roam" then
			d.endsAt, d.total, d.mode = now + C.WIPE_TIME, C.WIPE_TIME, "roam"
		end
		publishDead(player, d)
	else
		publishDead(player, d)
		createSoul(player, pos)
	end
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.Died:Connect(function() onDied(player, char) end)
end

local function onPlayer(p)
	p.CharacterAdded:Connect(function(char) onCharacter(p, char) end)
	if p.Character then task.spawn(onCharacter, p, p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end

Players.PlayerRemoving:Connect(function(p)
	dead[p] = nil
	if carryingSoul[p] then release(p, Vector3.zero) end
	local s = souls[p]
	if s then destroySoul(s) end
	for _, rec in souls do if rec.rez and rec.rez.by == p then cancelRez(rec) end end
end)

-- a team member leaving can turn "spectating" into a wipe
local function checkWipes()
	if modeName() == "1v1" then return end
	local teams = {}
	for _, p in Players:GetPlayers() do
		local tn = teamName(p)
		if tn and tn ~= "Lobby" then
			teams[tn] = teams[tn] or { alive = 0, dead = 0 }
			if isAliveForTeam(p) then teams[tn].alive += 1 elseif dead[p] then teams[tn].dead += 1 end
		end
	end
	local now = nowT()
	for tn, t in teams do
		if t.alive == 0 and t.dead > 0 then
			local needs = false
			for _, p in Players:GetPlayers() do
				if teamName(p) == tn and dead[p] and dead[p].mode ~= "roam" then needs = true end
			end
			if needs then wipeTeam(tn, now) end
		end
	end
end

-- everything resets when the round is not "Playing" any more
if MatchState then
	MatchState:GetAttributeChangedSignal("Phase"):Connect(function()
		if phase() == "Playing" then return end
		for p in table.clone(dead) do
			dead[p] = nil
			if p.Parent then clearDeadAttrs(p) end
		end
		for _, rec in table.clone(souls) do destroySoul(rec) end
		-- auto-respawn is off: anybody who is still dead when the round is over comes back for the result / summary screens
		if phase() == "Result" or phase() == "Summary" then
			for _, p in Players:GetPlayers() do
				local c = p.Character
				local h = c and c:FindFirstChildOfClass("Humanoid")
				if not h or h.Health <= 0 then loadChar(p) end
			end
		end
	end)
end

------------------------------------------------------------------ main loop
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then return end
	acc = 0
	local now = nowT()
	-- respawn timers
	for p, d in table.clone(dead) do
		if not p.Parent then dead[p] = nil
		elseif now >= d.endsAt then
			dead[p] = nil
			local s = souls[p]
			if s then destroySoul(s) end
			clearDeadAttrs(p)
			p:SetAttribute("RezCF", nil)
			p:SetAttribute("RevealBuild", nil)
			loadChar(p)
		end
	end
	checkWipes()
	-- souls
	for owner, rec in table.clone(souls) do
		local part = rec.part
		if not part.Parent then souls[owner] = nil continue end
		if not dead[owner] then destroySoul(rec) continue end
		if rec.state == "Thrown" then
			local age = os.clock() - (rec.thrownAt or 0)
			local lowY = rec.origin.Y - 120
			if part.Position.Y < lowY then
				part.AssemblyLinearVelocity = Vector3.zero
				part.CFrame = CFrame.new(rec.origin)
				hoverSettle(rec)
			elseif (age > 0.35 and part.AssemblyLinearVelocity.Magnitude < 5) or age > 5 then
				hoverSettle(rec)
			end
		elseif rec.state == "Carried" then
			local c = rec.carrier
			if not c or not aliveChar(c) then if c then release(c, Vector3.zero) end end
		end
		local z = rec.rez
		if z then
			local by = z.by
			local c, _, r = aliveChar(by)
			local ok = c ~= nil and c:GetAttribute("Reviving") == true and phase() == "Playing" and rec.state == "Loose"
			if ok then
				local flat = Vector3.new(r.Position.X - z.startPos.X, 0, r.Position.Z - z.startPos.Z)
				if flat.Magnitude > SOUL.HoldRange or math.abs(r.Position.Y - z.startPos.Y) > 3.2 then ok = false end
				if (r.Position - part.Position).Magnitude > SOUL.Reach + 5 then ok = false end
			end
			if not ok then
				cancelRez(rec)
			elseif os.clock() - z.start >= (SOUL.RezTime or C.REZ_TIME) then
				completeRez(rec)
			end
		end
	end
end)
