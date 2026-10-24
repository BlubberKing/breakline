local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("WeaponConfig"))
local GunMath = require(RS:WaitForChild("GunMath"))

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
	state[player] = state[player] or {}
	local w = state[player][weapon]
	if not w then
		w = { ammo = Config[weapon].MagSize, lastFire = 0, reloadUntil = 0 }
		state[player][weapon] = w
	end
	return w
end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() state[p] = nil end) end)
Players.PlayerRemoving:Connect(function(p) state[p] = nil end)

ReloadRemote.OnServerEvent:Connect(function(player, weapon)
	local cfg = Config[weapon]; if not cfg then return end
	local w = getState(player, weapon)
	local now = os.clock()
	if now < w.reloadUntil then return end
	w.reloadUntil = now + cfg.ReloadTime * 0.9
	w.ammo = cfg.MagSize
end)

FireRemote.OnServerEvent:Connect(function(player, weapon, origin, dir, hitPart, hitPos)
	local cfg = Config[weapon]
	if not cfg or typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then return end
	local m = dir.Magnitude
	if not (m > 0.9 and m < 1.1) then return end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local myHum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not myHum or myHum.Health <= 0 then return end
	if (origin - root.Position).Magnitude > 10 then return end

	local w = getState(player, weapon)
	local now = os.clock()
	if now < w.reloadUntil or w.ammo <= 0 then return end
	-- rate limit that allows small bursts (lag bunches shots together); still caps at RPM
	local interval = 60 / cfg.RPM
	w.budget = math.min((w.budget or 3) + (now - w.lastFire) / interval, 3)
	if w.budget < 1 then return end
	w.budget -= 1
	w.ammo -= 1
	w.lastFire = now

	-- show this shot to everyone else
	local endPos = origin + dir.Unit * cfg.Range
	if typeof(hitPos) == "Vector3" and (hitPos - origin).Magnitude <= cfg.Range + 5 then endPos = hitPos end
	for _, p in Players:GetPlayers() do
		if p ~= player then ShotFX:FireClient(p, player, origin, endPos) end
	end

	if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") or typeof(hitPos) ~= "Vector3" then return end
	if not hitPart:IsDescendantOf(workspace) then return end

	local model = hitPart:FindFirstAncestorOfClass("Model")
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or model == char then return end

	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if targetPlayer and not player.Neutral and targetPlayer.Team == player.Team then return end

	local toHit = hitPos - origin
	local dist = toHit.Magnitude
	if dist > cfg.Range or dist < 0.01 then return end
	if toHit.Unit:Dot(dir.Unit) < 0.95 then return end
	if (hitPart.Position - hitPos).Magnitude > hitPart.Size.Magnitude / 2 + 7 then return end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	table.insert(ignore, model)
	params.FilterDescendantsInstances = ignore
	if workspace:Raycast(origin, toHit.Unit * math.max(dist - 0.5, 0), params) then return end

	local head = GunMath.IsHeadshot(hitPart)
	local dmg = GunMath.Damage(cfg, dist, head)
	hum:TakeDamage(dmg)
	HitConfirm:FireClient(player, model, head, hum.Health <= 0, math.floor(dmg + 0.5), hitPos)
	if targetPlayer then Damaged:FireClient(targetPlayer, dmg, origin) end
end)
