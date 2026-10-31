-- GunServer v2: server-authoritative ammo, fire rate and damage for every weapon in WeaponConfig.
-- Also owns the equipped weapon: Player attributes "Weapon" + "Sight". v2.1: the weapon is ONLY the one picked in the lobby loadout
-- (the temporary G picker + its open SetLoadout remote are gone). The whole lobby loadout is published as "LoadoutJson" for MatchHUD.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Weapons = require(RS:WaitForChild("WeaponConfig"))
local GunMath = require(RS:WaitForChild("GunMath"))
local ServerStorage = game:GetService("ServerStorage")
local MatchCfg = require(RS:WaitForChild("MatchConfig"))
local BoxDamage = ServerStorage:WaitForChild("BoxDamage", 30) -- BindableEvent made by MatchServer
local GadgetDamage = ServerStorage:WaitForChild("GadgetDamage", 30) -- BindableEvent made by GadgetServer (v4.0: bubble shields)
local Profiles = require(script.Parent:WaitForChild("ProfileStore"))
local MatchState = RS:WaitForChild("MatchState", 30) -- made by MatchServer; guns only work while the match is live

local remotes = Instance.new("Folder")
remotes.Name = "GunRemotes"
local function remote(name)
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = remotes; return r
end
local FireRemote, ReloadRemote = remote("Fire"), remote("Reload")
local HitConfirm, ShotFX, Damaged = remote("HitConfirm"), remote("ShotFX"), remote("Damaged")
remotes.Parent = RS

local state = {}
local function getState(player, weapon)
	local s = state[player]
	if not s or s.weapon ~= weapon then
		s = { weapon = weapon, ammo = Weapons.Get(weapon).MagSize, lastFire = 0, reloadUntil = 0 }
		state[player] = s
	end
	return s
end

local function onPlayer(p)
	p:SetAttribute("Weapon", Weapons.Default)
	p:SetAttribute("Sight", Weapons.Get(Weapons.Default).DefaultSight)
	p.CharacterAdded:Connect(function() state[p] = nil end)
	-- safety net: the Weapon attribute can never be empty / unknown (the server rejects shots that do not match it)
	p:GetAttributeChangedSignal("Weapon"):Connect(function()
		local w = p:GetAttribute("Weapon")
		if type(w) ~= "string" or not Weapons.Weapons[w] then
			p:SetAttribute("Weapon", Weapons.Default)
			p:SetAttribute("Sight", Weapons.Get(Weapons.Default).DefaultSight)
		end
	end)
	-- the gun picked in the lobby loadout
	task.spawn(function()
		local d = Profiles.WaitFor(p)
		if d and type(d.Loadout) == "table" then
			pcall(function() p:SetAttribute("LoadoutJson", game:GetService("HttpService"):JSONEncode(d.Loadout)) end)
		end
		local w = d and d.Weapon
		if type(w) == "string" and Weapons.Weapons[w] then
			state[p] = nil
			p:SetAttribute("Sight", Weapons.Get(w).DefaultSight)
			p:SetAttribute("Weapon", w)
		end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
Players.PlayerRemoving:Connect(function(p) state[p] = nil end)

ReloadRemote.OnServerEvent:Connect(function(player, weapon)
	if weapon ~= player:GetAttribute("Weapon") or player:GetAttribute("Carrying") then return end
	local cfg = Weapons.Get(weapon)
	local w = getState(player, weapon)
	local now = os.clock()
	if now < w.reloadUntil then return end
	w.reloadUntil = now + cfg.ReloadTime * 0.9
	w.ammo = cfg.MagSize
end)

local function maxBudget(cfg)
	if cfg.FireMode == "Burst" then return cfg.BurstCount + 0.5 end
	return math.clamp(0.25 / (60 / cfg.RPM), 1.2, 3)
end

-- validates one pellet; returns model, humanoid, damage, head, hitPos or nil
local function checkHit(player, char, cfg, origin, dir, hitPart, hitPos)
	if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") or typeof(hitPos) ~= "Vector3" then return end
	if not hitPart:IsDescendantOf(workspace) then return end
	local model = hitPart:FindFirstAncestorOfClass("Model")
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or model == char then return end
	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if targetPlayer and not player.Neutral and targetPlayer.Team == player.Team then return end
	local sentryTeam = model:GetAttribute("OwnerTeam") -- v4.0: a gadget Sentry (has a Humanoid, no player); never shoot your own team's
	if sentryTeam and player.Team and sentryTeam == player.Team.Name then return end

	local toHit = hitPos - origin
	local dist = toHit.Magnitude
	if dist > cfg.Range or dist < 0.01 then return end
	if toHit.Unit:Dot(dir) < 0.95 then return end
	if (hitPart.Position - hitPos).Magnitude > hitPart.Size.Magnitude / 2 + 7 then return end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	table.insert(ignore, model)
	params.FilterDescendantsInstances = ignore
	if workspace:Raycast(origin, toHit.Unit * math.max(dist - 0.5, 0), params) then return end

	local head = GunMath.IsHeadshot(hitPart)
	return model, hum, GunMath.Damage(cfg, dist, head), head, hitPos, targetPlayer
end

-- shots = { { dir, hitPart, hitPos }, ... } one entry per pellet
-- validates a shot at a plugged wall box (enemy team's boxes only); returns box part, damage, hitPos or nil
local function checkBoxHit(player, cfg, origin, dir, hitPart, hitPos)
	if not hitPart:GetAttribute("WPBox") or hitPart:GetAttribute("State") ~= "Plugged" then return end
	local plugTeam = hitPart:GetAttribute("PlugTeam")
	if not plugTeam or not player.Team or player.Team.Name == plugTeam then return end
	local toHit = hitPos - origin
	local dist = toHit.Magnitude
	if dist > cfg.Range or dist < 0.01 or toHit.Unit:Dot(dir) < 0.95 then return end
	if (hitPart.Position - hitPos).Magnitude > hitPart.Size.Magnitude / 2 + 4 then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	params.FilterDescendantsInstances = ignore
	local r = workspace:Raycast(origin, toHit.Unit * (dist + 1), params)
	if r and r.Instance ~= hitPart then return end -- something solid is in the way
	return hitPart, GunMath.Damage(cfg, dist, false) * MatchCfg.BOX.DamageMult, hitPos
end

-- v4.0: validates a shot at a bubble shield (GadgetServer); returns the shield part, damage or nil. Friendly shields soak the bullet but take no damage.
local function checkShieldHit(player, cfg, origin, dir, hitPart, hitPos)
	if hitPart.Name ~= "BubbleShield" or not hitPart:HasTag("GadgetShield") then return end
	local toHit = hitPos - origin
	local dist = toHit.Magnitude
	if dist > cfg.Range or dist < 0.01 or toHit.Unit:Dot(dir) < 0.95 then return end
	if (hitPart.Position - hitPos).Magnitude > hitPart.Size.X / 2 + 3 then return end
	local team = hitPart:GetAttribute("ShieldTeam")
	if team and player.Team and team == player.Team.Name then return end
	return hitPart, GunMath.Damage(cfg, dist, false)
end

FireRemote.OnServerEvent:Connect(function(player, weapon, origin, shots)
	if weapon ~= player:GetAttribute("Weapon") or player:GetAttribute("Carrying") then return end
	do -- v3.8: no shooting while your body is being revealed after a respawn, or while wall-climbing
		local ch = player.Character
		if ch and (ch:GetAttribute("Revealing") == true or ch:GetAttribute("AbilityMode") == "climb") then return end
	end
	local ph = MatchState and MatchState:GetAttribute("Phase")
	if ph == "Waiting" or ph == "Pregame" or ph == "Warp" or ph == "Countdown" or ph == "Summary" then return end
	local cfg = Weapons.Get(weapon)
	if typeof(origin) ~= "Vector3" or type(shots) ~= "table" then return end
	if #shots < 1 or #shots > cfg.Pellets then return end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local myHum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not myHum or myHum.Health <= 0 then return end
	if (origin - root.Position).Magnitude > 10 then return end

	local w = getState(player, weapon)
	local now = os.clock()
	if now < w.reloadUntil or w.ammo <= 0 then return end
	-- rate limit that allows small bursts (lag bunches shots together); still caps at the weapon's rate
	local cap = maxBudget(cfg)
	w.budget = math.min((w.budget or cap) + (now - w.lastFire) / Weapons.AvgInterval(cfg), cap)
	if w.budget < 1 then return end
	w.budget -= 1
	w.ammo -= 1
	w.lastFire = now

	local first, maxCone = nil, math.cos(math.rad(cfg.PelletSpread * 2.2 + 1))
	local ends, hits, boxHits = {}, {}, {}
	for i, shot in shots do
		if type(shot) ~= "table" then return end
		local dir, hitPart, hitPos = shot[1], shot[2], shot[3]
		if typeof(dir) ~= "Vector3" then return end
		local m = dir.Magnitude
		if not (m > 0.9 and m < 1.1) then return end
		dir = dir.Unit
		first = first or dir
		if dir:Dot(first) < maxCone then continue end

		local endPos = origin + dir * cfg.Range
		if typeof(hitPos) == "Vector3" and (hitPos - origin).Magnitude <= cfg.Range + 5 then endPos = hitPos end
		ends[i] = endPos

		local boxPart, boxDmg, boxPos
		if typeof(hitPart) == "Instance" and hitPart:IsA("BasePart") and typeof(hitPos) == "Vector3" and BoxDamage then
			boxPart, boxDmg, boxPos = checkBoxHit(player, cfg, origin, dir, hitPart, hitPos)
		end
		if boxPart then
			local b = boxHits[boxPart] or { dmg = 0, pos = boxPos }
			b.dmg += boxDmg
			boxHits[boxPart] = b
		end
		if typeof(hitPart) == "Instance" and hitPart:IsA("BasePart") and typeof(hitPos) == "Vector3" and GadgetDamage then
			local sp, sd = checkShieldHit(player, cfg, origin, dir, hitPart, hitPos)
			if sp then GadgetDamage:Fire(sp, sd) end
		end
		local model, hum, dmg, head, pos, targetPlayer = checkHit(player, char, cfg, origin, dir, hitPart, hitPos)
		if model then
			local h = hits[model] or { hum = hum, dmg = 0, head = false, pos = pos, player = targetPlayer }
			h.dmg += dmg
			h.head = h.head or head
			hits[model] = h
		end
	end

	-- show this shot to everyone else
	for _, p in Players:GetPlayers() do
		if p ~= player then ShotFX:FireClient(p, player, origin, ends) end
	end

	-- plugged boxes: damage goes to MatchServer, the shooter gets a body hitmarker + number
	for part, b in boxHits do
		BoxDamage:Fire(part, b.dmg, player)
		HitConfirm:FireClient(player, part, false, false, math.floor(b.dmg + 0.5), b.pos)
	end

	-- one damage number per target per shot (shotgun pellets are added together)
	for model, h in hits do
		if h.hum.Health > 0 then
			local before = h.hum.Health
			h.hum:TakeDamage(h.dmg)
			local killed = h.hum.Health <= 0
			if h.player then -- match stats for the souls screen (MatchServer resets them every round)
				player:SetAttribute("StatDamage", (player:GetAttribute("StatDamage") or 0) + math.min(h.dmg, before))
				if killed then player:SetAttribute("StatKills", (player:GetAttribute("StatKills") or 0) + 1) end
			end
			HitConfirm:FireClient(player, model, h.head, killed, math.floor(h.dmg + 0.5), h.pos)
			if h.player then Damaged:FireClient(h.player, h.dmg, origin) end
		end
	end
end)
