-- ThirdPersonServer v3: world gun (any weapon, rebuilt on swap) on a torso joint, aim/state replication, shot + reload broadcast
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GunModels = require(RS:WaitForChild("GunModels"))
local Weapons = require(RS:WaitForChild("WeaponConfig"))

local GUN_SCALE = 0.55 -- world rifle size relative to the character

local folder = RS:FindFirstChild("TPRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TPRemotes"
	folder.Parent = RS
end
local function remote(name)
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("UnreliableRemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r
end
local Look, Shot = remote("TPLook"), remote("TPShot")


local function accentFor(player)
	if player.Team and not player.Neutral then return player.TeamColor.Color end
	return Color3.fromRGB(255, 140, 30)
end

local function attachGun(player, char)
	local torso = char:WaitForChild("UpperTorso", 10)
	if not torso or not char.Parent then return end
	local old = char:FindFirstChild("TPGun")
	if old then old:Destroy() end
	local oldJoint = torso:FindFirstChild("GunJoint")
	if oldJoint then oldJoint:Destroy() end

	local cfg = Weapons.Get(player:GetAttribute("Weapon"))
	local sight = player:GetAttribute("Sight")
	if not Weapons.HasSight(cfg, sight) then sight = cfg.DefaultSight end
	local gun = GunModels.BuildWorld(cfg.Model, sight, GUN_SCALE, accentFor(player), "TPGun")
	gun:SetAttribute("Weapon", cfg.Id)
	local k = torso.Size.Y / 1.6
	local c0 = CFrame.new(0.42 * k, 0.05 * k, -1.2 * k)
	gun:PivotTo(torso.CFrame * c0)
	gun.Parent = char

	local joint = Instance.new("Motor6D")
	joint.Name = "GunJoint"
	joint.Part0 = torso
	joint.Part1 = gun.PrimaryPart
	joint.C0 = c0
	joint.Parent = torso

	if char:GetAttribute("AimPitch") ~= nil then return end -- weapon swap: keep the live state
	char:SetAttribute("AimPitch", 0)
	char:SetAttribute("ADS", false)
	char:SetAttribute("Sprint", false)
	char:SetAttribute("Sliding", false)
	char:SetAttribute("Crouching", false)
	char:SetAttribute("Mantling", false)
	char:SetAttribute("Reloading", false)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char) attachGun(player, char) end)
	local function recolor()
		local gun = player.Character and player.Character:FindFirstChild("TPGun")
		if gun then GunModels.SetAccent(gun, accentFor(player)) end
	end
	local queued = false
	local function rebuild() -- deferred so Weapon + Sight changing together = one rebuild
		if queued then return end
		queued = true
		task.wait()
		queued = false
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			char:SetAttribute("Reloading", false)
			attachGun(player, char)
		end
	end
	player:GetAttributeChangedSignal("Weapon"):Connect(function() task.spawn(rebuild) end)
	player:GetAttributeChangedSignal("Sight"):Connect(function() task.spawn(rebuild) end)
	player:GetPropertyChangedSignal("Team"):Connect(recolor)
	player:GetPropertyChangedSignal("TeamColor"):Connect(recolor)
	if player.Character then task.spawn(attachGun, player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

local function alive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return (hum and hum.Health > 0) and char or nil
end

local lastLook = {}
Look.OnServerEvent:Connect(function(player, pitch, ads, sprint, slide, mantle, crouch)
	if type(pitch) ~= "number" or pitch ~= pitch then return end
	local now = os.clock()
	if now - (lastLook[player] or 0) < 1 / 40 then return end
	lastLook[player] = now
	local char = alive(player)
	if not char then return end
	pitch = math.clamp(pitch, -math.rad(80), math.rad(80))
	ads, slide, mantle, crouch = ads == true, slide == true, mantle == true, crouch == true
	char:SetAttribute("AimPitch", math.floor(pitch * 100 + 0.5) / 100)
	char:SetAttribute("ADS", ads and not mantle)
	char:SetAttribute("Sprint", sprint == true and not ads and not slide)
	char:SetAttribute("Sliding", slide)
	char:SetAttribute("Mantling", mantle)
	char:SetAttribute("Crouching", crouch and not slide and not mantle)
end)

local function findRemote(name)
	local deadline = os.clock() + 20
	repeat
		for _, d in ipairs(RS:GetDescendants()) do
			if d.Name == name and d:IsA("RemoteEvent") and not d:IsDescendantOf(folder) then return d end
		end
		task.wait(0.25)
	until os.clock() > deadline
	warn("[ThirdPersonServer] Could not find RemoteEvent '" .. name .. "'")
end

local lastShot = {}
task.spawn(function()
	local fire = findRemote("Fire")
	if not fire then return end
	fire.OnServerEvent:Connect(function(player)
		local char = alive(player)
		if not char then return end
		local now = os.clock()
		if now - (lastShot[player] or 0) < 0.045 then return end
		lastShot[player] = now
		Shot:FireAllClients(char)
	end)
end)

local reloadToken = {}
task.spawn(function()
	local reload = findRemote("Reload")
	if not reload then return end
	reload.OnServerEvent:Connect(function(player)
		local char = alive(player)
		if not char or char:GetAttribute("Reloading") then return end
		local token = {}
		reloadToken[player] = token
		char:SetAttribute("Reloading", true)
		task.delay(Weapons.Get(player:GetAttribute("Weapon")).ReloadTime, function()
			if reloadToken[player] == token and char.Parent then char:SetAttribute("Reloading", false) end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	lastLook[p], lastShot[p], reloadToken[p] = nil, nil, nil
end)
