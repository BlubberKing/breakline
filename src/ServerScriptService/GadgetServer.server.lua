-- GadgetServer v1 (Script in ServerScriptService) - BREAKLINE place only. NEW in v4.0.
-- Server-authoritative gadgets: FRAG, SMOKE, FLASH, SENTRY, SHIELD (bubble), MINE. Numbers: ReplicatedStorage.GadgetConfig.
--   Client -> server : ReplicatedStorage.GadgetRemotes.Use (slot 1-3, aim direction)
--   Server -> clients: ReplicatedStorage.GadgetRemotes.FX  ("Boom" / "Flash" / "ShieldBreak", ...) = purely visual
--   Player attributes (read by MatchHUD): GadId{i}, GadCount{i}, GadMax{i}, GadReady{i}, GadNext{i}  (i = loadout gadget slot 1-3, times = server time)
--   ServerStorage.GadgetDamage (BindableEvent): GunServer fires (part, damage, shooter) when a bullet hits a bubble shield.
-- Rules: only while MatchState.Phase == "Playing", never while carrying a box / revealing / wall-climbing. Thrown things are real physics parts
-- owned by the server. Friendly fire is off (your own frag / mine only hurts you at selfMult, your own shield / sentry never block or hurt you).
-- Bubble shield: a big transparent ball (CanQuery, no CanCollide). Bullets from OUTSIDE hit it (it takes the damage), bullets fired from INSIDE leave
-- freely (a ray that starts inside a part does not hit that part). Explosions are blocked by it too.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Cfg = require(RS:WaitForChild("GadgetConfig"))
local MatchState = RS:WaitForChild("MatchState", 30)
local BoxDamage = SS:WaitForChild("BoxDamage", 30)

local remotes = Instance.new("Folder")
remotes.Name = "GadgetRemotes"
local UseR = Instance.new("RemoteEvent"); UseR.Name = "Use"; UseR.Parent = remotes
local FxR = Instance.new("RemoteEvent"); FxR.Name = "FX"; FxR.Parent = remotes
remotes.Parent = RS
local DamageEvent = Instance.new("BindableEvent")
DamageEvent.Name = "GadgetDamage"
DamageEvent.Parent = SS
local fxFolder = Instance.new("Folder")
fxFolder.Name = "GadgetFX"
fxFolder.Parent = workspace

local rnd = Random.new()
local shields, sentries, mines = {}, {}, {} -- [part] = rec / array / array

------------------------------------------------------------------ helpers
local function nowT() return workspace:GetServerTimeNow() end
local function teamName(p) return p and p.Team and not p.Neutral and p.Team.Name or nil end
local function isEnemy(owner, p) -- is player p an enemy of the owner (or the owner themself = false)
	if owner == p then return false end
	local a, b = teamName(owner), teamName(p)
	if not a or not b then return true end
	return a ~= b
end
local function aliveChar(p)
	local c = p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if h and r and h.Health > 0 then return c, h, r end
	return nil
end
local function teamColor(p)
	if p and p.Team and not p.Neutral then return p.TeamColor.Color end
	return Color3.fromRGB(110, 220, 255)
end
local function charList()
	local t = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(t, p.Character) end end
	return t
end
local function newParams(extra)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ig = charList()
	if extra then for _, e in extra do table.insert(ig, e) end end
	rp.FilterDescendantsInstances = ig
	return rp
end
local function cfFromUp(pos, up)
	local r = up:Cross(Vector3.zAxis)
	if r.Magnitude < 0.1 then r = up:Cross(Vector3.xAxis) end
	r = r.Unit
	return CFrame.fromMatrix(pos, r, up, r:Cross(up))
end
local function mkPart(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do p[k] = v end
	p.Parent = parent or fxFolder
	return p
end

local gunRemotes
local function gunRemote(name)
	gunRemotes = gunRemotes or RS:FindFirstChild("GunRemotes")
	return gunRemotes and gunRemotes:FindFirstChild(name)
end

-- damage a humanoid on behalf of `owner` (stats for the souls screen + hit confirm + damage indicator)
local function hurt(owner, targetPlayer, hum, dmg, hitPos)
	if hum.Health <= 0 or dmg <= 0 then return end
	local before = hum.Health
	hum:TakeDamage(dmg)
	local killed = hum.Health <= 0
	if owner and targetPlayer and targetPlayer ~= owner then
		owner:SetAttribute("StatDamage", (owner:GetAttribute("StatDamage") or 0) + math.min(dmg, before))
		if killed then owner:SetAttribute("StatKills", (owner:GetAttribute("StatKills") or 0) + 1) end
	end
	if owner and owner.Parent and targetPlayer ~= owner then
		local hc = gunRemote("HitConfirm")
		if hc and hum.Parent then hc:FireClient(owner, hum.Parent, false, killed, math.floor(dmg + 0.5), hitPos or hum.Parent:GetPivot().Position) end
	end
	if targetPlayer then
		local dm = gunRemote("Damaged")
		if dm then dm:FireClient(targetPlayer, dmg, hitPos or Vector3.zero) end
	end
end

------------------------------------------------------------------ bubble shield
local function breakShield(part, quiet)
	local rec = shields[part]
	if not rec then return end
	shields[part] = nil
	if not quiet then FxR:FireAllClients("ShieldBreak", part.Position, rec.radius, part.Color) end
	if rec.ring then rec.ring:Destroy() end
	TweenService:Create(part, TweenInfo.new(quiet and 0.6 or 0.15), { Transparency = 1 }):Play()
	Debris:AddItem(part, quiet and 0.7 or 0.2)
end

local function damageShield(part, dmg)
	local rec = shields[part]
	if not rec then return end
	rec.hp -= dmg
	part:SetAttribute("HP", math.max(rec.hp, 0))
	if rec.hp <= 0 then breakShield(part, false) return end
	part.Transparency = 0.35 + 0.4 * (1 - math.clamp(rec.hp / rec.max, 0, 1))
end

DamageEvent.Event:Connect(function(part, dmg)
	if typeof(part) == "Instance" and shields[part] and type(dmg) == "number" and dmg > 0 then damageShield(part, dmg) end
end)

local function buildShield(owner, pos)
	local cfg = Cfg.Items.SHIELD
	local R = cfg.radius
	local col = teamColor(owner)
	local dome = mkPart({
		Name = "BubbleShield", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.5, Position = pos + Vector3.new(0, R * 0.45, 0),
		Material = Enum.Material.ForceField, Color = col, Transparency = 0.35, CanQuery = true,
	})
	dome:SetAttribute("ShieldTeam", teamName(owner) or "none")
	dome:SetAttribute("HP", cfg.hp)
	dome:SetAttribute("MaxHP", cfg.hp)
	local ringD = 2 * R * math.sqrt(1 - 0.45 ^ 2)
	local ring = mkPart({
		Name = "ShieldRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1, 1), Material = Enum.Material.Neon, Color = col, Transparency = 0.25,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	TweenService:Create(dome, TweenInfo.new(cfg.expand, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.one * R * 2 }):Play()
	TweenService:Create(ring, TweenInfo.new(cfg.expand, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, ringD, ringD), Transparency = 0.5 }):Play()
	shields[dome] = { hp = cfg.hp, max = cfg.hp, radius = R, owner = owner, ring = ring }
	CS:AddTag(dome, "GadgetShield")
	task.delay(cfg.life, function() if shields[dome] then breakShield(dome, true) end end)
end

------------------------------------------------------------------ explosions
local function detonateMine(rec) end -- forward declaration (assigned below)

local function explode(pos, owner, radius, dmg, boxDmg, selfMult, shieldDmg)
	FxR:FireAllClients("Boom", pos, radius)
	local params = newParams()
	local origin = pos + Vector3.new(0, 0.4, 0)
	for _, p in Players:GetPlayers() do
		local char, hum, root = aliveChar(p)
		if char and (p == owner or isEnemy(owner, p)) then
			local d = (root.Position - pos).Magnitude
			if d <= radius then
				local head = char:FindFirstChild("Head")
				local visible = false
				for _, tp in { root.Position, head and head.Position or root.Position } do
					if not workspace:Raycast(origin, tp - origin, params) then visible = true break end
				end
				if visible then
					local dealt = dmg * (0.25 + 0.75 * math.clamp(1 - d / radius, 0, 1))
					if p == owner then dealt *= selfMult end
					hurt(owner, p, hum, dealt, root.Position)
				end
			end
		end
	end
	-- plugged boxes of the enemy team
	local ot = teamName(owner)
	for _, b in CS:GetTagged("WPBox") do
		if b:IsA("BasePart") and b:GetAttribute("State") == "Plugged" then
			local plugTeam = b:GetAttribute("PlugTeam")
			if plugTeam and ot and plugTeam ~= ot and (b.Position - pos).Magnitude <= radius + b.Size.Magnitude / 2 then
				BoxDamage:Fire(b, boxDmg * (0.3 + 0.7 * math.clamp(1 - (b.Position - pos).Magnitude / (radius + 4), 0, 1)), owner)
			end
		end
	end
	-- enemy shields, sentries and mines in range
	for part, rec in shields do
		if rec.owner ~= owner and (teamName(rec.owner) ~= ot or not ot) and (part.Position - pos).Magnitude < radius + rec.radius then
			damageShield(part, shieldDmg or dmg)
		end
	end
	for _, s in sentries do
		if s.alive and s.owner ~= owner and (teamName(s.owner) ~= ot or not ot) and (s.headPos - pos).Magnitude < radius then
			s.hum:TakeDamage(dmg * 0.8)
		end
	end
	for _, m in table.clone(mines) do
		if m.alive and m.owner ~= owner and (teamName(m.owner) ~= ot or not ot) and (m.pos - pos).Magnitude < radius then
			task.delay(0.12, function() detonateMine(m) end)
		end
	end
end

------------------------------------------------------------------ smoke / flash
local function smokeBlocks(a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	for _, c in CS:GetTagged("SmokeCloud") do
		local R = c:GetAttribute("Radius") or 10
		local t = len2 > 0 and math.clamp((c.Position - a):Dot(ab) / len2, 0, 1) or 0
		if (a + ab * t - c.Position).Magnitude < R * 0.75 then return true end
	end
	return false
end

local function buildSmoke(owner, pos)
	local cfg = Cfg.Items.SMOKE
	local R = cfg.radius
	local center = mkPart({ Name = "SmokeCloud", Transparency = 1, Size = Vector3.one * R * 0.9, Position = pos + Vector3.new(0, 2, 0) })
	center:SetAttribute("Radius", R)
	center:SetAttribute("ExpireAt", nowT() + cfg.duration)
	CS:AddTag(center, "SmokeCloud")
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Rate = 70
	pe.Lifetime = NumberRange.new(5, 8)
	pe.Speed = NumberRange.new(1, 4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-20, 20)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, R * 0.35), NumberSequenceKeypoint.new(1, R * 0.8) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(Color3.fromRGB(205, 208, 214))
	pe.Drag = 2
	pe.Parent = center
	local blobs = {}
	for i = 1, 7 do
		local off = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-0.3, 0.8), rnd:NextNumber(-1, 1)) * R * 0.45
		local b = mkPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Position = pos + Vector3.new(0, 2, 0) + off, Color = Color3.fromRGB(200, 203, 210), Transparency = 0.3 })
		TweenService:Create(b, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * R * rnd:NextNumber(1.0, 1.5) }):Play()
		table.insert(blobs, b)
	end
	task.delay(cfg.duration - 2.5, function()
		pe.Enabled = false
		for _, b in blobs do TweenService:Create(b, TweenInfo.new(2.4), { Transparency = 1 }):Play() end
	end)
	task.delay(cfg.duration, function()
		center:Destroy()
		for _, b in blobs do b:Destroy() end
	end)
end

------------------------------------------------------------------ sentry
local function buildSentry(owner, pos)
	local cfg = Cfg.Items.SENTRY
	local col = teamColor(owner)
	local model = Instance.new("Model")
	model.Name = "Sentry"
	local DARK = Color3.fromRGB(32, 36, 44)
	local function sp(name, size, cf, color, mat, collide)
		local p = mkPart({ Name = name, Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Metal, CanQuery = true, CanCollide = collide or false }, model)
		return p
	end
	local base = sp("Base", Vector3.new(2.6, 0.4, 2.6), CFrame.new(pos + Vector3.new(0, 0.2, 0)), DARK, nil, true)
	sp("Column", Vector3.new(0.9, 1.4, 0.9), CFrame.new(pos + Vector3.new(0, 1.1, 0)), Color3.fromRGB(52, 58, 70), nil, true)
	sp("Foot1", Vector3.new(0.5, 0.35, 2.9), CFrame.new(pos + Vector3.new(0, 0.18, 0)), Color3.fromRGB(52, 58, 70))
	local headPos = pos + Vector3.new(0, 2.2, 0)
	local parts = {} -- { part, local offset }
	local function hp(name, size, off, color, mat)
		local p = sp(name, size, CFrame.new(headPos) * off, color, mat)
		table.insert(parts, { p, off })
		return p
	end
	local body = hp("Body", Vector3.new(1.8, 1.1, 2.0), CFrame.new(), Color3.fromRGB(58, 64, 78))
	hp("Barrel", Vector3.new(0.34, 0.34, 2.2), CFrame.new(0, 0.05, -1.9), DARK)
	hp("BarrelRing", Vector3.new(0.5, 0.5, 0.25), CFrame.new(0, 0.05, -2.8), Color3.fromRGB(80, 86, 100))
	hp("Cap", Vector3.new(1.0, 0.14, 1.2), CFrame.new(0, 0.62, 0.1), col, Enum.Material.Neon)
	hp("SideL", Vector3.new(0.18, 0.7, 1.4), CFrame.new(-1.0, 0, 0.1), DARK)
	hp("SideR", Vector3.new(0.18, 0.7, 1.4), CFrame.new(1.0, 0, 0.1), DARK)
	local eye = hp("Eye", Vector3.new(0.5, 0.18, 0.12), CFrame.new(0, 0.2, -1.02), Color3.fromRGB(255, 70, 70), Enum.Material.Neon)
	local muzzleOff = CFrame.new(0, 0.05, -3.1)
	local hum = Instance.new("Humanoid")
	hum.MaxHealth, hum.Health = cfg.health, cfg.health
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	pcall(function() hum.EvaluateStateMachine = false end)
	hum.Parent = model
	model.PrimaryPart = base
	model:SetAttribute("OwnerTeam", teamName(owner) or "none")
	model:SetAttribute("OwnerId", owner.UserId)
	CS:AddTag(model, "Sentry")
	model.Parent = fxFolder
	local look = Vector3.new(0, 0, -1)
	local ol = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
	if ol then look = Vector3.new(ol.CFrame.LookVector.X, 0, ol.CFrame.LookVector.Z).Unit end
	local rec = {
		model = model, hum = hum, owner = owner, headPos = headPos, parts = parts, eye = eye, muzzleOff = muzzleOff, alive = true,
		aim = look, base = look, scan = 0, nextFire = 0, nextScan = 0, armAt = os.clock() + cfg.armTime, dieAt = os.clock() + cfg.life, target = nil,
	}
	-- one sentry per player
	for _, s in table.clone(sentries) do
		if s.owner == owner then s.dieNow = true end
	end
	table.insert(sentries, rec)
	hum.Died:Connect(function() rec.dieNow, rec.killed = true, true end)
	return rec
end

local function killSentry(rec)
	if not rec.alive then return end
	rec.alive = false
	FxR:FireAllClients("Boom", rec.headPos, 6)
	rec.model:Destroy()
	local i = table.find(sentries, rec)
	if i then table.remove(sentries, i) end
end

local function sentryFindTarget(rec, cfg)
	local best, bestD
	local head = rec.headPos
	local params = newParams({ rec.model })
	for _, p in Players:GetPlayers() do
		if isEnemy(rec.owner, p) then
			local char, _, root = aliveChar(p)
			if char then
				local d = (root.Position - head).Magnitude
				if d <= cfg.range and (not bestD or d < bestD) then
					local h = char:FindFirstChild("Head")
					local tp = (h and h.Position) or root.Position
					local origin = head + Vector3.new(0, 0.2, 0)
					if not workspace:Raycast(origin, tp - origin, params) and not smokeBlocks(origin, tp) then
						best, bestD = { player = p, char = char, root = root, point = tp }, d
					end
				end
			end
		end
	end
	return best
end

local function sentryShoot(rec, cfg, target)
	local muzzle = (CFrame.lookAt(rec.headPos, rec.headPos + rec.aim) * rec.muzzleOff).Position
	local dir = (target.point - muzzle)
	if dir.Magnitude < 0.5 then return end
	dir = dir.Unit
	local sp = math.rad(cfg.spread)
	local a, r = rnd:NextNumber(0, math.pi * 2), sp * math.sqrt(rnd:NextNumber())
	dir = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, 0, a) * CFrame.Angles(r, 0, 0)).LookVector
	local ex = { rec.model }
	for _, p in Players:GetPlayers() do
		if p.Character and not isEnemy(rec.owner, p) then table.insert(ex, p.Character) end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ex
	local res = workspace:Raycast(muzzle, dir * (cfg.range + 12), rp)
	local endPos = res and res.Position or muzzle + dir * (cfg.range + 12)
	if res then
		local model = res.Instance:FindFirstAncestorOfClass("Model")
		local h = model and model:FindFirstChildOfClass("Humanoid")
		if h and model ~= rec.model then
			local tp = Players:GetPlayerFromCharacter(model)
			if tp or not model:GetAttribute("OwnerTeam") or model:GetAttribute("OwnerTeam") ~= teamName(rec.owner) then
				hurt(rec.owner, tp, h, cfg.damage, endPos)
			end
		elseif shields[res.Instance] and shields[res.Instance].owner ~= rec.owner then
			damageShield(res.Instance, cfg.damage)
		end
	end
	local len = (endPos - muzzle).Magnitude
	local tr = mkPart({ Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt(muzzle, endPos) * CFrame.new(0, 0, -len / 2),
		Material = Enum.Material.Neon, Color = teamColor(rec.owner), Transparency = 0.15 })
	Debris:AddItem(tr, 0.06)
end

------------------------------------------------------------------ mines
local function buildMine(owner, pos, normal)
	local cfg = Cfg.Items.MINE
	local cf = cfFromUp(pos + normal * 0.2, normal)
	local body = mkPart({ Name = "ProxMine", Size = Vector3.new(1.5, 0.4, 1.5), CFrame = cf, Color = Color3.fromRGB(46, 50, 60), Material = Enum.Material.Metal })
	local ringP = mkPart({ Name = "Ring", Size = Vector3.new(1.0, 0.12, 1.0), CFrame = cf * CFrame.new(0, 0.22, 0), Color = Color3.fromRGB(255, 130, 60), Material = Enum.Material.Neon })
	local eye = mkPart({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, CFrame = cf * CFrame.new(0, 0.34, 0), Color = Color3.fromRGB(90, 20, 20), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Enabled = Color3.fromRGB(255, 50, 50), 5, 2, false
	light.Parent = eye
	body:SetAttribute("MineTeam", teamName(owner) or "none")
	local rec = {
		owner = owner, pos = pos + normal * 0.3, normal = normal, parts = { body, ringP, eye }, eye = eye, light = light, alive = true,
		armAt = os.clock() + cfg.arm, armed = false, trig = nil, dieAt = os.clock() + cfg.life, nextCheck = 0, blink = 0,
	}
	-- keep at most `maxActive` per owner (oldest goes first, quietly)
	local mine = {}
	for _, m in mines do if m.owner == owner then table.insert(mine, m) end end
	while #mine >= cfg.maxActive do
		local old = table.remove(mine, 1)
		old.alive = false
		for _, p in old.parts do p:Destroy() end
		table.remove(mines, table.find(mines, old))
	end
	table.insert(mines, rec)
	return rec
end

local function removeMine(rec)
	if not rec.alive then return end
	rec.alive = false
	for _, p in rec.parts do p:Destroy() end
	local i = table.find(mines, rec)
	if i then table.remove(mines, i) end
end

detonateMine = function(rec)
	if not rec.alive then return end
	local cfg = Cfg.Items.MINE
	local pos, owner = rec.pos, rec.owner
	removeMine(rec)
	explode(pos + Vector3.new(0, 1, 0), owner, cfg.radius, cfg.damage, cfg.boxDamage, 0.4, 260)
end

------------------------------------------------------------------ per-frame logic (sentries + mines)
local lastBeat = os.clock()
game:GetService("RunService").Heartbeat:Connect(function()
	local now = os.clock()
	local dt = math.min(now - lastBeat, 0.1)
	lastBeat = now
	-- sentries
	local cfg = Cfg.Items.SENTRY
	for _, s in table.clone(sentries) do
		if not s.alive then continue end
		if s.dieNow or now >= s.dieAt or not s.owner.Parent then killSentry(s) continue end
		local armed = now >= s.armAt
		if armed and now >= s.nextScan then
			s.nextScan = now + 0.1
			s.target = sentryFindTarget(s, cfg)
		end
		local desired
		if s.target and s.target.char.Parent then
			desired = (s.target.point - s.headPos).Unit
			-- follow the moving target
			local h = s.target.char:FindFirstChild("Head")
			if h then s.target.point = h.Position end
		else
			s.target = nil
			s.scan += dt * 0.9
			desired = (CFrame.Angles(0, math.sin(s.scan) * 1.2, 0) * CFrame.lookAt(Vector3.zero, s.base)).LookVector
		end
		s.aim = s.aim:Lerp(desired, math.min(1, dt * cfg.turn)).Unit
		local cf = CFrame.lookAt(s.headPos, s.headPos + s.aim)
		for _, e in s.parts do e[1].CFrame = cf * e[2] end
		if s.target and armed and now >= s.nextFire and s.aim:Dot(desired) > 0.995 then
			s.nextFire = math.max(s.nextFire, now - 0.05) + 60 / cfg.rpm
			sentryShoot(s, cfg, s.target)
		end
	end
	-- mines
	local mc = Cfg.Items.MINE
	for _, m in table.clone(mines) do
		if not m.alive then continue end
		if now >= m.dieAt or not m.owner.Parent then removeMine(m) continue end
		if not m.armed and now >= m.armAt then
			m.armed = true
			m.eye.Color = Color3.fromRGB(255, 50, 50)
			m.light.Enabled = true
		end
		if m.armed then
			m.blink += dt
			local rate = m.trig and 0.06 or 0.7
			if m.blink >= rate then
				m.blink = 0
				m.light.Enabled = not m.light.Enabled
				m.eye.Transparency = m.light.Enabled and 0 or 0.6
			end
			if not m.trig and now >= m.nextCheck then
				m.nextCheck = now + 0.1
				for _, p in Players:GetPlayers() do
					if isEnemy(m.owner, p) then
						local char, _, root = aliveChar(p)
						if char then
							local d = root.Position - m.pos
							if Vector3.new(d.X, 0, d.Z).Magnitude <= mc.trigger and math.abs(d.Y) < 6 then
								m.trig = now + mc.delay
								break
							end
						end
					end
				end
			end
			if m.trig and now >= m.trig then
				-- hop up, then blow
				m.alive = false
				for _, p in m.parts do
					TweenService:Create(p, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = p.CFrame + m.normal * 3 }):Play()
				end
				task.delay(0.15, function()
					for _, p in m.parts do p:Destroy() end
					local i = table.find(mines, m)
					if i then table.remove(mines, i) end
					explode(m.pos + m.normal * 3, m.owner, mc.radius, mc.damage, mc.boxDamage, 0.4, 260)
				end)
			end
		end
	end
end)

------------------------------------------------------------------ throwing
local function onLand(part, minAge, cb)
	local born = os.clock()
	local done = false
	local conn
	local function finish()
		if done then return end
		done = true
		if conn then conn:Disconnect() end
		if part.Parent then cb() end
	end
	conn = part.Touched:Connect(function(o)
		if done or os.clock() - born < minAge then return end
		if not o.CanCollide or o.Parent and o.Parent:FindFirstChildOfClass("Humanoid") then return end
		if o.Name == "BubbleShield" or o:IsDescendantOf(fxFolder) then return end
		finish()
	end)
	task.delay(4, finish)
end

local state = {}
local function loadoutIds(p)
	local out = { "", "", "" }
	local raw = p:GetAttribute("LoadoutJson")
	if type(raw) == "string" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" and type(t.Gadgets) == "table" then
			for i = 1, 3 do
				local id = t.Gadgets[i]
				if type(id) == "string" and Cfg.Items[id] then out[i] = id end
			end
		end
	end
	return out
end

local function publish(p, s, i)
	p:SetAttribute("GadId" .. i, s.ids[i])
	p:SetAttribute("GadCount" .. i, s.count[i])
	p:SetAttribute("GadMax" .. i, s.max[i])
	p:SetAttribute("GadReady" .. i, s.ready[i])
	p:SetAttribute("GadNext" .. i, s.nextCharge[i] or 0)
end

local function resetState(p)
	local ids = loadoutIds(p)
	local s = { ids = ids, count = {}, max = {}, ready = {}, nextCharge = {} }
	for i = 1, 3 do
		local c = Cfg.Items[ids[i]]
		s.max[i] = c and c.charges or 0
		s.count[i] = s.max[i]
		s.ready[i] = 0
		publish(p, s, i)
	end
	state[p] = s
end

local function launch(player, slot, id, dir)
	local cfg = Cfg.Items[id]
	local char, _, root = aliveChar(player)
	if not char then return false end
	local head = char:FindFirstChild("Head")
	local from = head and head.Position or root.Position + Vector3.new(0, 1.5, 0)
	local origin = from + dir * 1.8
	local r = workspace:Raycast(from, dir * 1.8, newParams())
	if r then origin = r.Position - dir * 0.4 end
	local p = Instance.new("Part")
	p.Name = "Gadget_" .. id
	p.Shape = Enum.PartType.Ball
	if id == "MINE" or id == "SENTRY" then p.Shape = Enum.PartType.Block end
	p.Size = Vector3.one * cfg.projSize
	p.Color = cfg.projColor
	p.Material = Enum.Material.SmoothPlastic
	p.CanQuery, p.CanCollide, p.CanTouch, p.CastShadow = false, true, true, false
	p.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.6, 0.4, 1, 1)
	p.Position = origin
	p:SetAttribute("LaunchDir", dir)
	p.Parent = fxFolder
	pcall(function() p:SetNetworkOwner(nil) end)
	p.AssemblyLinearVelocity = dir * cfg.speed + root.AssemblyLinearVelocity * 0.35
	p.AssemblyAngularVelocity = Vector3.new(rnd:NextNumber(-12, 12), rnd:NextNumber(-12, 12), rnd:NextNumber(-12, 12))
	-- trail so people can see the arc
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, cfg.projSize / 2, 0), Vector3.new(0, -cfg.projSize / 2, 0)
	a0.Parent, a1.Parent = p, p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.35
	tr.Color = ColorSequence.new(cfg.projColor)
	tr.Transparency = NumberSequence.new(0.3, 1)
	tr.LightEmission = 0.4
	tr.Parent = p

	local function refund()
		local s = state[player]
		if s and s.ids[slot] == id then
			s.count[slot] = math.min(s.count[slot] + 1, s.max[slot])
			s.ready[slot] = 0
			publish(player, s, slot)
		end
	end

	if id == "FRAG" then
		task.delay(cfg.fuse, function()
			if not p.Parent then return end
			local pos = p.Position
			p:Destroy()
			explode(pos, player, cfg.radius, cfg.damage, cfg.boxDamage, cfg.selfMult, cfg.shieldDamage)
		end)
	elseif id == "SMOKE" then
		task.delay(cfg.fuse, function()
			if not p.Parent then return end
			local pos = p.Position
			p:Destroy()
			buildSmoke(player, pos)
		end)
	elseif id == "FLASH" then
		task.delay(cfg.fuse, function()
			if not p.Parent then return end
			local pos = p.Position
			p:Destroy()
			FxR:FireAllClients("Flash", pos, cfg.range, cfg.maxTime)
		end)
	elseif id == "SHIELD" then
		onLand(p, 0.1, function()
			local pos = p.Position
			p:Destroy()
			local g = workspace:Raycast(pos + Vector3.new(0, 1.5, 0), Vector3.new(0, -8, 0), newParams())
			buildShield(player, g and g.Position or pos)
		end)
	elseif id == "SENTRY" then
		onLand(p, 0.1, function()
			local pos = p.Position
			p:Destroy()
			local g = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -9, 0), newParams())
			if g and g.Normal.Y > 0.7 then
				buildSentry(player, g.Position)
			else
				refund()
			end
		end)
	elseif id == "MINE" then
		onLand(p, 0.05, function()
			local pos = p.Position
			p:Destroy()
			local d = (p:GetAttribute("LaunchDir") or Vector3.new(0, -1, 0))
			local res = workspace:Raycast(pos - d * 0.8, d * 2.4, newParams())
			if res then
				buildMine(player, res.Position, res.Normal)
			else
				local g = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -4, 0), newParams())
				if g then buildMine(player, g.Position, g.Normal) else refund() end
			end
		end)
	end
	return true
end

local lastUse = {}
UseR.OnServerEvent:Connect(function(player, slot, dir)
	if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > 3 then return end
	if typeof(dir) ~= "Vector3" then return end
	local m = dir.Magnitude
	if not (m > 0.9 and m < 1.1) then return end
	local now = os.clock()
	if now - (lastUse[player] or 0) < 0.25 then return end
	local s = state[player]
	if not s then return end
	local id = s.ids[slot]
	local cfg = Cfg.Items[id]
	if not cfg then return end
	local ph = MatchState and MatchState:GetAttribute("Phase")
	if MatchState and ph ~= "Playing" then return end
	local char, _, _ = aliveChar(player)
	if not char then return end
	if player:GetAttribute("Carrying") or char:GetAttribute("Revealing") == true or char:GetAttribute("AbilityMode") == "climb" then return end
	local t = nowT()
	if s.count[slot] <= 0 or t < s.ready[slot] then return end
	dir = (dir.Unit + Vector3.new(0, 0.16, 0)).Unit
	if not launch(player, slot, id, dir) then return end
	lastUse[player] = now
	s.count[slot] -= 1
	s.ready[slot] = t + cfg.cooldown
	if not s.nextCharge[slot] then s.nextCharge[slot] = t + cfg.recharge end
	publish(player, s, slot)
end)

-- recharge loop
local acc = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then return end
	acc = 0
	local t = nowT()
	for p, s in state do
		for i = 1, 3 do
			local c = Cfg.Items[s.ids[i]]
			if c and s.count[i] < s.max[i] and s.nextCharge[i] and t >= s.nextCharge[i] then
				s.count[i] += 1
				s.nextCharge[i] = s.count[i] < s.max[i] and (t + c.recharge) or nil
				publish(p, s, i)
			end
		end
	end
end)

local function onPlayer(p)
	p:GetAttributeChangedSignal("LoadoutJson"):Connect(function() resetState(p) end)
	p.CharacterAdded:Connect(function() resetState(p) end)
	resetState(p)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
Players.PlayerRemoving:Connect(function(p)
	state[p], lastUse[p] = nil, nil
	for part, rec in shields do if rec.owner == p then breakShield(part, true) end end
end)
